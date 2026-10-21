//! bsv-rs signer adapter for #147, measured at bsv-rs v0.7.0 = 5841f98c (#148 d-bis).
//! The node column judges the output. Public templates use SigningContext,
//! which dispatches by hash type at 0.7.0 (template.rs:133-154); the explicit
//! scriptCode path uses compute_sighash_dispatched_for_signing, like the hand
//! control; api-context-scriptcode passes the corpus scriptCode through the
//! 0.7.0 public override SigningContext::with_script_code (template.rs:114-117).

use std::io::{BufRead, Write};
use std::path::Path;

use bsv_rs::primitives::bsv::sighash::{
    build_sighash_preimage, build_sighash_preimage_original,
    compute_sighash_dispatched_for_signing, parse_transaction, SighashParams,
};
use bsv_rs::primitives::bsv::TransactionSignature;
use bsv_rs::primitives::ec::PrivateKey;
use bsv_rs::script::template::{compute_sighash_scope, SignOutputs, SigningContext};
use bsv_rs::script::templates::{Multisig, P2PK, P2PKH};
use bsv_rs::script::Script;
use bsv_script_harness::signer::{parse, Piece, Row, SignInput};
use bsv_script_harness::txraw::RawTx;
use bsv_script_harness::BSV_RS_VERSION;
use serde::Serialize;
use serde_json::Value;

type Result<T> = std::result::Result<T, String>;
const METHODS: [&str; 4] = [
    "template",
    "api-default",
    "api-scriptcode",
    "api-context-scriptcode",
];

#[derive(Serialize)]
struct Trace {
    index: usize,
    site: usize,
    preimage_hex: String,
    digest_hex: String,
    scriptcode_used_hex: String,
}

#[derive(Serialize)]
struct Signed {
    id: String,
    engine: &'static str,
    method: &'static str,
    tx_hex: Option<String>,
    inputs: Vec<Trace>,
    note: String,
}

fn unhex(s: &str) -> Result<Vec<u8>> {
    hex::decode(s).map_err(|e| e.to_string())
}

fn known_template(name: &str) -> bool {
    if matches!(
        name,
        "p2pkh" | "p2pk" | "checksig-in-unlock-a" | "checksig-in-unlock-b"
    ) {
        return true;
    }
    name.strip_prefix("multisig-")
        .and_then(|s| s.split_once("-of-"))
        .is_some_and(|(m, n)| {
            [m, n].iter().all(|s| {
                !s.starts_with('0')
                    && s.bytes().all(|b| b.is_ascii_digit())
                    && s.parse::<usize>().is_ok_and(|v| v > 0)
            })
        })
}

fn check(row: &Row, tx: &RawTx) -> Result<()> {
    row.entry.check()?;
    if tx.inputs.is_empty()
        || tx.inputs.len() != row.signing.inputs.len()
        || tx.inputs.len() != row.entry.prevouts.len()
        || tx.inputs.iter().any(|i| !i.script.is_empty())
        || tx.version != row.signing.version
        || tx.lock_time != row.signing.locktime
    {
        return Err("signing metadata differs from unsigned transaction".into());
    }
    let mut seen = std::collections::BTreeSet::new();
    for si in &row.signing.inputs {
        if si.index >= tx.inputs.len() || !seen.insert(si.index) {
            return Err("input index duplicated or out of range".into());
        }
        if !known_template(&si.template) {
            return Err(format!("unknown template {}", si.template));
        }
        if si.pubkeys.is_empty() || si.unlock_template.is_empty() {
            return Err("pubkeys and unlock_template are required".into());
        }
        if si.sequence != tx.inputs[si.index].sequence
            || si.sighash_type > 255
            || si.scriptcode_hex.is_empty()
            || si.privkeys.is_empty()
            || si.privkeys.len() != si.pubkeys.len()
            || si.privkeys.len() != si.sig_sites.len()
            || si.sig_sites.iter().any(|s| *s >= si.scriptcode_hex.len())
        {
            return Err("invalid signing input sequence, scope, keys or sites".into());
        }
    }
    Ok(())
}

fn template_options(si: &SignInput) -> Result<(SignOutputs, bool)> {
    if si.template.starts_with("checksig-in-unlock-") {
        return Err(format!(
            "bsv-rs has no public {} unlocking template",
            si.template
        ));
    }
    let outputs = match si.sighash_type & 0x1f {
        1 => SignOutputs::All,
        2 => SignOutputs::None,
        3 => SignOutputs::Single,
        _ => return Err("template requires ALL, NONE or SINGLE".into()),
    };
    let anyone = si.sighash_type & 0x80 != 0;
    // template.rs:209-217 cannot express Chronicle or omit FORKID. Never
    // silently change the requested scope or substitute a precomputed digest.
    if compute_sighash_scope(outputs, anyone) != si.sighash_type {
        return Err(format!("bsv-rs {} unlock options cannot express scope 0x{:02x} (template.rs:209-217: FORKID always set, no CHRONICLE bit)", si.template, si.sighash_type));
    }
    if si.scriptcode_hex.len() != 1 || si.sig_sites.iter().any(|s| *s != 0) {
        return Err("public template requires one signature site".into());
    }
    Ok((outputs, anyone))
}

fn sign(row: &Row, method: &str, traces: &mut Vec<Trace>) -> Result<String> {
    let raw = unhex(&row.entry.tx)?;
    let mut signed = RawTx::decode(&raw)?;
    check(row, &signed)?;
    let tx = parse_transaction(&raw).map_err(|e| e.to_string())?;
    for si in &row.signing.inputs {
        let options = (method == "template")
            .then(|| template_options(si))
            .transpose()?;
        let keys = si
            .privkeys
            .iter()
            .map(|h| PrivateKey::from_bytes(&unhex(h)?).map_err(|e| e.to_string()))
            .collect::<Result<Vec<_>>>()?;
        let prevout = &row.entry.prevouts[si.index];
        let lock = Script::from_binary(&unhex(&prevout.script)?).map_err(|e| e.to_string())?;
        let context = SigningContext::new(&raw, si.index, prevout.satoshis, &lock);
        let mut digests = Vec::new();
        let mut preimages = Vec::new();
        for (site, h) in si.scriptcode_hex.iter().enumerate() {
            let site_code = if method == "api-context-scriptcode" {
                Some(Script::from_binary(&unhex(h)?).map_err(|e| e.to_string())?)
            } else {
                None
            };
            let code = match (&site_code, method) {
                (Some(script), _) => script.to_binary(),
                (None, "api-scriptcode") => unhex(h)?,
                _ => lock.to_binary(),
            };
            let params = SighashParams {
                version: tx.version,
                inputs: &tx.inputs,
                outputs: &tx.outputs,
                locktime: tx.locktime,
                input_index: si.index,
                subscript: &code,
                satoshis: prevout.satoshis,
                scope: si.sighash_type,
            };
            // The preimage follows the digest's dispatch (template.rs:122-128).
            let preimage = if si.sighash_type & 0x40 != 0 && si.sighash_type & 0x20 == 0 {
                build_sighash_preimage(&params)
            } else if si.sighash_type & 0x1f == 3 && si.index >= tx.outputs.len() {
                Vec::new() // Constant one is a digest, not a serialized preimage.
            } else {
                build_sighash_preimage_original(&params)
            };
            let digest = match (&site_code, method) {
                (Some(script), _) => SigningContext::new(&raw, si.index, prevout.satoshis, &lock)
                    .with_script_code(script)
                    .compute_sighash(si.sighash_type)
                    .map_err(|e| e.to_string())?,
                (None, "api-scriptcode") => compute_sighash_dispatched_for_signing(&params),
                // The library selects the lock; 0.7.0 dispatches by hash type.
                _ => context
                    .compute_sighash(si.sighash_type)
                    .map_err(|e| e.to_string())?,
            };
            traces.push(Trace {
                index: si.index,
                site,
                preimage_hex: hex::encode(&preimage),
                digest_hex: hex::encode(digest),
                scriptcode_used_hex: hex::encode(code),
            });
            digests.push(digest);
            preimages.push(preimage);
        }
        let unlock = if let Some((outputs, anyone)) = options {
            let template = match si.template.as_str() {
                "p2pkh" if keys.len() == 1 => P2PKH::unlock(&keys[0], outputs, anyone),
                "p2pk" if keys.len() == 1 => P2PK::unlock(&keys[0], outputs, anyone),
                name if name.starts_with("multisig-") => Multisig::unlock(&keys, outputs, anyone),
                _ => return Err("public template key count is invalid".into()),
            };
            template
                .sign(&context)
                .map_err(|e| e.to_string())?
                .to_binary()
        } else {
            let sigs = keys
                .iter()
                .zip(&si.sig_sites)
                .map(|(key, site)| {
                    let sig = key.sign(&digests[*site]).map_err(|e| e.to_string())?;
                    Ok(TransactionSignature::new(sig, si.sighash_type).to_checksig_format())
                })
                .collect::<Result<Vec<_>>>()?;
            let mut bytes = Vec::new();
            for piece in parse(&si.unlock_template)? {
                let value = match piece {
                    Piece::Bytes(b) => {
                        bytes.extend(b);
                        continue;
                    }
                    Piece::Sig(k) => sigs.get(k).ok_or("signature token has no key")?.clone(),
                    Piece::Pub(k) => {
                        unhex(si.pubkeys.get(k).ok_or("public key token has no key")?)?
                    }
                    Piece::Preimage(s) => {
                        let p = preimages.get(s).ok_or("preimage token has no site")?;
                        if p.is_empty() {
                            return Err("constant-one digest has no preimage".into());
                        }
                        p.clone()
                    }
                };
                let mut push = Script::new();
                push.write_bin(&value);
                bytes.extend(push.to_binary());
            }
            bytes
        };
        signed.inputs[si.index].script = unlock;
    }
    Ok(hex::encode(signed.encode()))
}

fn row_result(value: &Value, method: &'static str) -> Signed {
    let mut result = Signed {
        id: value["id"].as_str().unwrap_or("").into(),
        engine: "bsv-rs",
        method,
        tx_hex: None,
        inputs: Vec::new(),
        note: String::new(),
    };
    let attempt = serde_json::from_value::<Row>(value.clone())
        .map_err(|e| e.to_string())
        .and_then(|row| sign(&row, method, &mut result.inputs));
    match attempt {
        Ok(tx) => {
            result.tx_hex = Some(tx);
            result.note = match method {
                "api-scriptcode" => "bsv-rs dispatched digest and supplied scriptCode; empty preimage_hex denotes constant one.",
                "api-context-scriptcode" => "bsv-rs SigningContext::with_script_code over the supplied scriptCode; empty preimage_hex denotes constant one.",
                _ => "bsv-rs SigningContext selects the source lock and dispatches by hash type; template mode uses the public unlock output.",
            }.into();
        }
        Err(e) => result.note = e,
    }
    result
}

fn run() -> Result<()> {
    let args: Vec<_> = std::env::args().skip(1).collect();
    if args == ["--version"] {
        println!("bsvrs-signer (bsv-script-lean #147) bsv-rs {BSV_RS_VERSION}");
        return Ok(());
    }
    if args.len() != 4 || args[0] != "--corpus" || args[2] != "--out" {
        return Err("usage: signer_bsvrs --corpus <file> --out <file> | --version".into());
    }
    let input = Path::new(&args[1]);
    let dest = Path::new(&args[3]);
    if dest.exists()
        && input.canonicalize().map_err(|e| e.to_string())?
            == dest.canonicalize().map_err(|e| e.to_string())?
    {
        return Err("output must not overwrite the input corpus".into());
    }
    let reader = std::io::BufReader::new(std::fs::File::open(input).map_err(|e| e.to_string())?);
    let mut writer =
        std::io::BufWriter::new(std::fs::File::create(dest).map_err(|e| e.to_string())?);
    for line in reader.lines() {
        let line = line.map_err(|e| e.to_string())?;
        if line.trim().is_empty() {
            continue;
        }
        let value = serde_json::from_str::<Value>(&line);
        for method in METHODS {
            let result = match &value {
                Ok(value) => row_result(value, method),
                Err(e) => Signed {
                    id: String::new(),
                    engine: "bsv-rs",
                    method,
                    tx_hex: None,
                    inputs: Vec::new(),
                    note: format!("invalid corpus JSON: {e}"),
                },
            };
            serde_json::to_writer(&mut writer, &result).map_err(|e| e.to_string())?;
            writeln!(writer).map_err(|e| e.to_string())?;
        }
    }
    writer.flush().map_err(|e| e.to_string())
}

fn main() -> std::process::ExitCode {
    match run() {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("bsvrs-signer: {e}");
            std::process::ExitCode::FAILURE
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> Result<Value> {
        serde_json::from_str(
            include_str!("../../../corpus/signer/p2pkh.jsonl")
                .lines()
                .next()
                .ok_or("empty corpus")?,
        )
        .map_err(|e| e.to_string())
    }

    #[test]
    fn unsupported_scopes_are_unsigned_and_required_fields_are_enforced() -> Result<()> {
        let mut value = sample()?;
        for scope in [0x03, 0x61, 0xe3] {
            value["signing"]["inputs"][0]["sighash_type"] = scope.into();
            let result = row_result(&value, "template");
            assert!(result.tx_hex.is_none());
            assert!(result.note.contains("cannot express"));
            assert!(result.note.contains("p2pkh unlock options"));
            assert!(result.note.contains(&format!("scope 0x{scope:02x}")));
        }
        value["signing"]["inputs"][0]["template"] = "unknown".into();
        for method in METHODS {
            let result = row_result(&value, method);
            assert!(result.tx_hex.is_none());
            assert!(result.note.contains("unknown template"));
        }
        let mut value = sample()?;
        value["signing"]["inputs"][0]
            .as_object_mut()
            .ok_or("input object")?
            .remove("pubkeys");
        for method in METHODS {
            let result = row_result(&value, method);
            assert!(result.tx_hex.is_none());
            assert!(result.note.contains("pubkeys"));
        }
        Ok(())
    }
}
