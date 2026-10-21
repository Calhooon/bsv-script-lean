//! THE SIGNER CHAIN (#152 step 1, lane chain-152, 2026-10-17; S3): every signature shape the signer corpus signs, as a
//! REAL spend on a private regtest chain of the reference, judged by the node's ADMISSION (`sendrawtransaction`, then a
//! mined block) beside the column's `verifyscript` judgment of the same bytes, and emitted in a form a second node can
//! be asked the same question (#152 step 2).
//!
//! The instance: the wallet build of the pin (`reference.binary_wallet`, banner `v1.2.3.0-g6504a3aff-dev`,
//! docs/PROVENANCE.md §1a) with `harness/oracle/bitcoin.conf`'s lines, the two activation heights replaced by
//! Teranode's regtest ones (Genesis 100, Chronicle 200: go-chaincfg v1.6.2 `params.go:450,463,475-476`, the pin
//! Teranode's go.mod requires; the reference's regtest defaults are 10,000 and 15,000, `chainparams.cpp:21, 26` at
//! `6504a3af`), both grace periods 0 (`init.cpp:3244-3263`, as `tools/xsig_witness.py` sets them) and `txindex=1`
//! (`init.cpp:617-619`, so a mined spend is read back by `getrawtransaction`). `acceptnonstdtxn=1` is the oracle
//! conf's own line. Its own datadir under $TMPDIR, the lowest free RPC/P2P pair in 18571..18590, `listen=0`, no
//! peer (CLAUDE.md rule 10); stopped and its datadir removed before the record is written.
//!
//! The road: mine 300 blocks to a wallet address (past Chronicle 200 and coinbase maturity 100,
//! `consensus.h:75`); for every row of `corpus/signer/*.jsonl` and every post-Chronicle row of
//! `corpus/xsig-144/xsig-144.jsonl` whose spend is post-Chronicle, of either version (`--version-1` asks only the
//! version-1 rows: the flag word carries no version, the machine's gate reads the transaction's), TEN slots (the hand signer's
//! control, and go-sdk, ts-sdk and bsv-rs by each of the three methods), each with its own coins: one wallet funding
//! transaction per (row, slot) whose outputs 0..n-1 are the row's prevouts (locking script, satoshis), change last
//! (`fundrawtransaction` `changePosition`, `rpcwallet.cpp:3218-3305`), signed by the wallet and mined. The row is
//! REBOUND to those coins (its prevouts and its unsigned transaction's outpoints rewritten, the prevouts' heights the
//! funding block's; `params` stay the row's, since `Entry::check` binds the era label to mainnet heights) and written
//! to a scratch corpus directory; the hand signer signs the control slot's rebound row, each adapter its slot's. Every
//! signed transaction is judged by `verifyscript` under the block and the relay words (`eval/bsvs --config sv-regtest`
//! with the instance's two heights, the spend at tip + 1, the coin at its funding height), then submitted; one block
//! is mined; an accepted spend is confirmed by `getrawtransaction` carrying a block hash. CHAIN AGREES WITH COLUMN:
//! accepted and mined exactly when the relay word judges every input valid; a time-locked spend the node holds in its
//! non-final pool (`validation.cpp:1100-1120`) is a finality decision outside the script column, predicted here by the
//! lock time rule (`LOCKTIME_THRESHOLD`, `script.h:36`) and counted apart. Nothing a node replied is kept beyond the
//! verdict, the reject reason's token and the script error's `SCRIPT_ERR_*` name (`svnode_codes`).
//!
//! The xsig-144 rows carry signed transactions, not signing objects: each post-Chronicle row is converted to the
//! signer row of its shape (A, B, C of `tools/xsig_witness.py`'s docstring), its keys `sha256("xsig-144/" + label)`
//! (`key()` there), its unlocking script turned into a template by replacing the signature, key and preimage pushes
//! with tokens; shape C (lock OP_1, no CHECKSIG in the lock) rides the `checksig-in-unlock-a` template name, the closed
//! vocabulary's in-unlock CHECKSIG with an API-only signing path.

use std::collections::BTreeMap;
use std::fs::File;
use std::io::{BufWriter, Write};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{Duration, Instant};

use bsv_rs::primitives::ec::PrivateKey;
use bsv_rs::primitives::hash::{hash160, sha256};
use bsv_script_harness::block::try_p2pkh_spend;
use bsv_script_harness::corpus::{Entry, RefJson};
use bsv_script_harness::flags_oracle::FlagsOracle;
use bsv_script_harness::rpc::Rpc;
use bsv_script_harness::signer::{
    ops, render, scriptcodes, sign_input, Piece, Row, SignInput, Signing,
};
use bsv_script_harness::signer_node::{
    adapter, decode, file_hash, output, read, write_json, Node, NodeSpec, RunDir, Verdict, ENGINES,
    METHODS,
};
use bsv_script_harness::svnode_codes::{mempool_reason, tx_reason_code};
use bsv_script_harness::teranode_contract::{
    BlockRef, Instance41, SubmitRoad, TeranodeObservation,
};
use bsv_script_harness::txraw::{txid_display_hex, txid_from_display_hex, RawOutput, RawTx};
use serde::Serialize;
use serde_json::{json, Value};

type Result<T> = std::result::Result<T, String>;

const GENESIS_HEIGHT: u32 = 100;
const CHRONICLE_HEIGHT: u32 = 200;
const MINE_TO: u32 = 300;
/// Funding transactions between two mined blocks (the wallet's unconfirmed change chain stays short).
const FUND_BATCH: usize = 25;
const LOCKTIME_THRESHOLD: u32 = 500_000_000;
const CONTROL: (&str, &str) = ("control", "hand");

fn txid(tx: &RawTx) -> String {
    txid_display_hex(&tx.txid_internal())
}

/// The ten slots: the control, then every engine by every method.
fn slots() -> Vec<(&'static str, &'static str)> {
    let mut out = vec![CONTROL];
    for (engine, _) in ENGINES {
        for method in METHODS {
            out.push((engine, method));
        }
    }
    out
}

#[derive(Clone, Debug, Serialize)]
struct Excluded {
    id: String,
    reason: String,
}

/// Why an era is not on this chain, or `None` for post-Chronicle.
fn era_exclusion(era: &str) -> Option<String> {
    match era {
        "post-chronicle" => None,
        "pre-genesis" => Some("pre-Genesis: impossible at these heights (no coin is spendable before height 101, coinbase maturity 100, consensus.h:75, and Genesis is 100)".into()),
        _ => Some("post-Genesis, pre-Chronicle: possible at heights 101 to 199; not funded in this run (one spend phase past Chronicle)".into()),
    }
}

/// Why a row is not on this chain, or `None` when it is (post-Chronicle, either version: the flag word does not carry
/// the version, the machine's gate reads the transaction's, `lean/BsvScript/Flags.lean`'s header and
/// `interpreter.cpp:40-44` at `6504a3af`, so a version-1 row is judged under the same words as the column judges it).
fn exclusion(row: &Row) -> Option<String> {
    era_exclusion(&row.entry.params.era)
}

/// Whether a row is a version-1 spend (the `--version-1` selection).
fn version_one(row: &Row) -> bool {
    row.signing.version == 1 || row.entry.params.tx_version == 1
}

/// The signer corpus, its files checked against the manifest's sums and counts.
fn signer_rows(root: &Path) -> Result<Vec<Row>> {
    let dir = root.join("corpus/signer");
    let manifest: Value =
        serde_json::from_str(&read(&dir.join("manifest.json"))?).map_err(|e| e.to_string())?;
    let listed = manifest["files"]
        .as_array()
        .ok_or("signer manifest files absent")?;
    let mut rows = Vec::new();
    for meta in listed {
        let name = meta["file"].as_str().ok_or("manifest file name")?;
        let text = read(&dir.join(name))?;
        if meta["sha256"] != hex::encode(sha256(text.as_bytes())) {
            return Err(format!("signer corpus hash differs: {name}"));
        }
        let before = rows.len();
        for line in text.lines().filter(|l| !l.trim().is_empty()) {
            let row: Row = serde_json::from_str(line).map_err(|e| format!("{name}: {e}"))?;
            row.entry.check()?;
            rows.push(row);
        }
        if meta["count"].as_u64() != Some((rows.len() - before) as u64) {
            return Err(format!("signer corpus row count differs: {name}"));
        }
    }
    Ok(rows)
}

/// An xsig-144 throwaway key (`tools/xsig_witness.py` `key()`: sha256 of `xsig-144/<label>`, refused at or above n).
fn xsig_key(label: &str) -> Result<(String, Vec<u8>)> {
    let h = sha256(format!("xsig-144/{label}").as_bytes());
    let sk = PrivateKey::from_bytes(&h).map_err(|e| format!("xsig key {label}: {e}"))?;
    Ok((hex::encode(h), sk.public_key().to_compressed().to_vec()))
}

/// The data of a push opcode at `script[s..e]`, or `None` for any other opcode.
fn push_data(script: &[u8], s: usize, e: usize) -> Option<&[u8]> {
    let hdr = match script[s] {
        0x01..=0x4b => 1,
        0x4c => 2,
        0x4d => 3,
        0x4e => 5,
        _ => return None,
    };
    script.get(s + hdr..e)
}

/// A shape's key labels, its (op index, token) pairs, each key's site and its template name.
type Shape = (
    &'static [&'static str],
    Vec<(usize, Piece)>,
    Vec<usize>,
    &'static str,
);

/// The signer row of an xsig-144 row's shape (the module header): the template from the signed unlocking script, the
/// scriptCodes by the signer's walker under Chronicle, the transaction with its unlocking script emptied.
fn xsig_row(e: &Entry) -> Result<Row> {
    let note = e.note.as_deref().unwrap_or("");
    let shape = note
        .strip_prefix("#144 shape ")
        .and_then(|s| s.chars().next())
        .ok_or_else(|| format!("{}: no shape in the note", e.id))?;
    let (labels, tokens, sites, template): Shape = match shape {
        'A' => (
            &["secret0", "utxo"],
            vec![(0, Piece::Sig(1)), (1, Piece::Sig(0)), (3, Piece::Pub(0))],
            vec![0, 1],
            "checksig-in-unlock-a",
        ),
        'B' => (
            &["utxo"],
            vec![
                (0, Piece::Sig(0)),
                (1, Piece::Pub(0)),
                (2, Piece::Preimage(0)),
            ],
            vec![1],
            "checksig-in-unlock-b",
        ),
        'C' => (
            &["shape-c"],
            vec![(0, Piece::Sig(0)), (1, Piece::Pub(0))],
            vec![0],
            "checksig-in-unlock-a",
        ),
        s => return Err(format!("{}: unknown shape {s}", e.id)),
    };
    let mut tx = decode(&e.tx)?;
    if tx.inputs.len() != 1 || e.prevouts.len() != 1 {
        return Err(format!("{}: an xsig-144 row spends one coin", e.id));
    }
    let unlock = std::mem::take(&mut tx.inputs[0].script);
    let lock = hex::decode(&e.prevouts[0].script).map_err(|x| x.to_string())?;
    let keys: Vec<(String, Vec<u8>)> = labels.iter().map(|l| xsig_key(l)).collect::<Result<_>>()?;
    let pubkeys: Vec<Vec<u8>> = keys.iter().map(|k| k.1.clone()).collect();
    let mut pieces = Vec::new();
    let mut scope = None;
    for (n, (s, end, _)) in ops(&unlock).into_iter().enumerate() {
        let Some((_, token)) = tokens.iter().find(|(at, _)| *at == n) else {
            pieces.push(Piece::Bytes(unlock[s..end].to_vec()));
            continue;
        };
        let data =
            push_data(&unlock, s, end).ok_or_else(|| format!("{}: op {n} is not a push", e.id))?;
        match token {
            Piece::Pub(k) if data != pubkeys[*k].as_slice() => {
                return Err(format!("{}: op {n} is not the key {}", e.id, labels[*k]))
            }
            Piece::Sig(_) => {
                if data.first() != Some(&0x30) {
                    return Err(format!("{}: op {n} is not a DER signature", e.id));
                }
                let t = u32::from(*data.last().unwrap_or(&0));
                if scope.is_some_and(|x| x != t) {
                    return Err(format!("{}: two hash types in one input", e.id));
                }
                scope = Some(t);
            }
            _ => {}
        }
        pieces.push(token.clone());
    }
    if pieces
        .iter()
        .filter(|p| !matches!(p, Piece::Bytes(_)))
        .count()
        != tokens.len()
    {
        return Err(format!(
            "{}: the unlocking script lacks a token's push",
            e.id
        ));
    }
    let codes = scriptcodes(&pieces, &pubkeys, &lock, true)?;
    if sites.iter().any(|s| *s >= codes.len()) {
        return Err(format!("{}: a key's site has no CHECKSIG", e.id));
    }
    let signing = Signing {
        version: tx.version,
        locktime: tx.lock_time,
        inputs: vec![SignInput {
            index: 0,
            template: template.into(),
            privkeys: keys.iter().map(|k| k.0.clone()).collect(),
            pubkeys: pubkeys.iter().map(hex::encode).collect(),
            sighash_type: scope.ok_or_else(|| format!("{}: no signature", e.id))?,
            sequence: tx.inputs[0].sequence,
            scriptcode_hex: codes.iter().map(hex::encode).collect(),
            sig_sites: sites,
            unlock_template: render(&pieces),
        }],
    };
    let mut entry = e.clone();
    entry.tx = hex::encode(tx.encode());
    entry.expect = BTreeMap::new();
    entry.divergence = None;
    entry.reference = Some(RefJson {
        model: "run_signer_chain: the xsig-144 shape re-signed over the reference's scriptCode (bitcoin-sv v1.2.3 6504a3af interpreter.cpp:1471-1481, 2112-2124), by construction".into(),
        expect: "valid".into(),
    });
    entry.note = Some(format!(
        "#144 shape {shape} converted from {} by run_signer_chain (#152): keys sha256('xsig-144/' + label) for {}",
        e.id,
        labels.join(", ")
    ));
    Ok(Row { entry, signing })
}

/// The row rebound to its funded coins: input i spends `funding:i`, whose locking script and satoshis are the row's
/// prevout i; the prevouts' heights become the funding block's. Nothing else moves.
fn rebind(row: &Row, funding: &str, height: u32) -> Result<Row> {
    let mut out = row.clone();
    let mut tx = decode(&row.entry.tx)?;
    if tx.inputs.len() != row.entry.prevouts.len() {
        return Err(format!(
            "{}: inputs and prevouts differ in count",
            row.entry.id
        ));
    }
    let internal = txid_from_display_hex(funding)?;
    for (i, (input, prevout)) in tx
        .inputs
        .iter_mut()
        .zip(&mut out.entry.prevouts)
        .enumerate()
    {
        input.txid = internal;
        input.vout = i as u32;
        prevout.txid = funding.to_string();
        prevout.vout = i as u32;
        prevout.height = height;
    }
    out.entry.tx = hex::encode(tx.encode());
    Ok(out)
}

/// The unfunded funding transaction: the row's prevouts as outputs 0..n-1.
fn funding_template(row: &Row) -> RawTx {
    RawTx {
        version: 2,
        inputs: Vec::new(),
        outputs: row
            .entry
            .prevouts
            .iter()
            .map(|p| RawOutput {
                satoshis: p.satoshis,
                script: hex::decode(&p.script).unwrap_or_default(),
            })
            .collect(),
        lock_time: 0,
    }
}

/// The hand signer over every input of a (rebound) row.
fn control(row: &Row) -> Result<String> {
    let raw = decode(&row.entry.tx)?;
    let mut signed = raw.clone();
    for (i, si) in row.signing.inputs.iter().enumerate() {
        signed.inputs[i].script = sign_input(&raw, row.entry.prevouts[i].satoshis, si, None)?.0;
    }
    Ok(hex::encode(signed.encode()))
}

/// `IsFinalTx` at the next block (`LOCKTIME_THRESHOLD`, `script.h:36`; the time half against the tip's median time).
fn is_final(tx: &RawTx, height: u32, median_time: u64) -> bool {
    let lt = tx.lock_time;
    lt == 0
        || u64::from(lt)
            < if lt < LOCKTIME_THRESHOLD {
                u64::from(height)
            } else {
                median_time
            }
        || tx.inputs.iter().all(|i| i.sequence == u32::MAX)
}

#[derive(Clone, Debug, Serialize)]
struct Submit {
    verdict: String,
    reject_token: Option<String>,
    reject_code: Option<String>,
}

/// `sendrawtransaction`, reduced to the verdict and the cited token (the reason before its parenthesis; the
/// `SCRIPT_ERR_*` name a script-carrying reason wraps). An unmapped reason is an error.
fn submit(node: &mut Node, tx: &str) -> Result<Submit> {
    match node.call_raw("sendrawtransaction", json!([tx])) {
        Ok(_) => Ok(Submit {
            verdict: "accepted".into(),
            reject_token: None,
            reject_code: None,
        }),
        Err(e) => {
            let message =
                Rpc::error_message(&e).ok_or("sendrawtransaction failed without a node error")?;
            let reason = mempool_reason(&message).trim();
            let token = reason
                .split('(')
                .next()
                .unwrap_or(reason)
                .trim_end()
                .to_string();
            let code = tx_reason_code(reason)
                .ok_or("sendrawtransaction reason outside the cited token tables")?;
            Ok(Submit {
                verdict: "rejected".into(),
                reject_code: (code != token).then_some(code),
                reject_token: Some(token),
            })
        }
    }
}

#[derive(Clone, Debug, Serialize)]
struct Outcome {
    id: String,
    engine: String,
    method: String,
    family: String,
    unsigned: Option<String>,
    tx_hex: Option<String>,
    txid: Option<String>,
    funding_txid: String,
    funding_tx_hex: String,
    funding_height: u32,
    prevouts: Vec<Value>,
    block: Vec<Verdict>,
    relay: Vec<Verdict>,
    words: Vec<[u32; 2]>,
    predicted_final: bool,
    submit: Option<Submit>,
    mined: Option<bool>,
    in_nonfinal_pool: Option<bool>,
    spend_height: u32,
    class: String,
}

/// The comparison's class: `agree` (accepted and mined iff the relay word judges every input valid), `finality`
/// (a valid script held in the non-final pool, predicted non-final) or `RED: <why>`.
fn compare(o: &Outcome) -> String {
    let Some(s) = &o.submit else {
        return "unsigned".into();
    };
    let relay_valid = o.relay.iter().all(|v| v.verdict == "valid");
    let accepted = s.verdict == "accepted";
    match (accepted, o.mined, o.predicted_final) {
        (true, Some(true), true) if relay_valid => "agree".into(),
        (true, Some(false), false) if relay_valid && o.in_nonfinal_pool == Some(true) => {
            "finality".into()
        }
        (false, _, _) if !relay_valid => {
            let column = o
                .relay
                .iter()
                .find(|v| v.verdict != "valid")
                .and_then(|v| v.code.clone());
            if s.reject_code != column {
                "RED: the reject code differs from the column's (or the rejection wraps no script error)".into()
            } else {
                "agree".into()
            }
        }
        _ => format!(
            "RED: chain {}{} beside column {}",
            s.verdict,
            match o.mined {
                Some(true) => " and mined",
                Some(false) => " not mined",
                None => "",
            },
            if relay_valid { "valid" } else { "invalid" }
        ),
    }
}

fn instance_conf(root: &Path) -> Result<(String, Vec<String>)> {
    let base = read(&root.join("harness/oracle/bitcoin.conf"))?;
    let mut lines = Vec::new();
    let mut conf = String::new();
    let mut replaced = 0;
    for line in base.lines() {
        let line = match line {
            "genesisactivationheight=620538" => {
                replaced += 1;
                format!("genesisactivationheight={GENESIS_HEIGHT}")
            }
            "chronicleactivationheight=943816" => {
                replaced += 1;
                format!("chronicleactivationheight={CHRONICLE_HEIGHT}")
            }
            l => l.to_string(),
        };
        if line.contains("activationheight=") {
            lines.push(line.clone());
        }
        conf += &line;
        conf.push('\n');
    }
    if replaced != 2 {
        return Err(
            "harness/oracle/bitcoin.conf no longer carries the two activation lines".into(),
        );
    }
    for extra in [
        "maxgenesisgracefulperiod=0",
        "maxchroniclegracefulperiod=0",
        "txindex=1",
    ] {
        conf += extra;
        conf.push('\n');
        lines.push(extra.to_string());
    }
    Ok((conf, lines))
}

/// Mine until the mempool is empty: [X] observed in this lane's runs, a block mined at once after the submissions
/// carried part of the mempool (the reference's block assembler reads it through its journal). Returns the blocks mined.
fn mine_all(node: &mut Node, addr: &Value) -> Result<u32> {
    for mined in 0..200 {
        let size = node.call("getmempoolinfo", json!([]))?["size"]
            .as_u64()
            .ok_or("mempool size")?;
        if size == 0 && mined > 0 {
            return Ok(mined);
        }
        if size == 0 {
            std::thread::sleep(std::time::Duration::from_millis(200));
        }
        node.call("generatetoaddress", json!([1, addr]))?;
        std::thread::sleep(std::time::Duration::from_millis(100));
    }
    Err("the mempool did not drain in 200 blocks".into())
}

fn height_of(node: &mut Node, txid: &str) -> Result<Option<u32>> {
    // -5 (RPC_INVALID_ADDRESS_OR_KEY, `rawtransaction.cpp:196-203`): neither in the mempool nor in a block
    let info = match node.call_raw("getrawtransaction", json!([txid, true])) {
        Ok(info) => info,
        Err(e) => {
            let code = e
                .strip_prefix("rpc error: ")
                .and_then(|j| serde_json::from_str::<Value>(j).ok())
                .and_then(|v| v["code"].as_i64());
            return match code {
                Some(-5) => Ok(None),
                _ => Err("getrawtransaction refused (reply suppressed)".into()),
            };
        }
    };
    let Some(hash) = info["blockhash"].as_str() else {
        return Ok(None);
    };
    let header = node.call("getblockheader", json!([hash]))?;
    Ok(Some(
        header["height"].as_u64().ok_or("block header height")? as u32,
    ))
}

#[derive(Default, Serialize)]
struct SlotCounts {
    funded: usize,
    signed: usize,
    unsigned: BTreeMap<String, usize>,
    accepted: usize,
    mined: usize,
    rejected: BTreeMap<String, usize>,
    nonfinal_pool: usize,
    agree: usize,
    finality: usize,
    red: usize,
}

/// A flag's value (the token after `name`).
fn arg(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|s| s == name)
        .and_then(|i| args.get(i + 1))
        .cloned()
}

/// Every value given after an occurrence of `name` (a repeatable flag). The Teranode oracle takes
/// one `--reference-set` per set step 1 emitted (the default run and the version-1 run each wrote
/// one), and merges them; the sets are disjoint by (id, engine, method) and an overlap is an error.
fn args_all(args: &[String], name: &str) -> Vec<String> {
    args.iter()
        .enumerate()
        .filter(|(_, s)| s.as_str() == name)
        .filter_map(|(i, _)| args.get(i + 1).cloned())
        .collect()
}

/// The reference chain (#152 step 1, the default) or the Teranode submission oracle (#152 step 2,
/// `--oracle teranode`). The reference path is unchanged.
fn run() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    match arg(&args, "--oracle").as_deref() {
        None | Some("reference") => {
            let (only_v1, rest) = match args.get(1).map(String::as_str) {
                Some("--version-1") => (true, &args[2..]),
                _ => (false, &args[1..]),
            };
            let emit = match rest {
                [] => None,
                [flag, path] if flag == "--emit" => Some(PathBuf::from(path)),
                _ => return Err("usage: run_signer_chain [--version-1] [--emit <file>]".into()),
            };
            run_reference(only_v1, emit)
        }
        Some("teranode") => run_teranode_oracle(&args),
        Some(other) => Err(format!(
            "unknown --oracle {other}; use reference or teranode"
        )),
    }
}

fn run_reference(only_v1: bool, emit: Option<PathBuf>) -> Result<()> {
    let root = Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .ok_or("repository root")?;
    let stamp = output(
        Command::new("date").args(["-u", "+%Y%m%d-%H%M%S"]),
        "UTC stamp",
    )?
    .trim()
    .to_string();
    let base = PathBuf::from(std::env::var("TMPDIR").map_err(|_| "TMPDIR required")?);
    let run_path = base.join(format!("chain-152-{stamp}-{}", std::process::id()));
    std::fs::create_dir(&run_path).map_err(|e| e.to_string())?;
    let run = RunDir(run_path);
    let rebound_dir = std::env::var_os("CHAIN_REBOUND_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| base.join(format!("chain-152-rebound-{stamp}")));
    if rebound_dir.starts_with(root) {
        return Err("the rebound corpus must be written outside the checkout".into());
    }
    std::fs::create_dir_all(&rebound_dir).map_err(|e| e.to_string())?;
    let evaluator = PathBuf::from(
        std::env::var_os("SIGNER_BSVS").ok_or("SIGNER_BSVS (a prebuilt bsvs) required")?,
    );
    let mut oracle = FlagsOracle::new(root, "sv-regtest")
        .with_executable(&evaluator)
        .with_heights(GENESIS_HEIGHT, CHRONICLE_HEIGHT);

    // the rows on this chain and the rows not
    let mut rows = Vec::new();
    let mut excluded = Vec::new();
    for row in signer_rows(root)? {
        match exclusion(&row) {
            Some(reason) => excluded.push(Excluded {
                id: row.entry.id.clone(),
                reason,
            }),
            None if !only_v1 || version_one(&row) => rows.push(row),
            None => {}
        }
    }
    let mut xsig_converted = Vec::new();
    // the xsig-144 rows are all version 2: a --version-1 run asks none of them
    for line in read(&root.join("corpus/xsig-144/xsig-144.jsonl"))?
        .lines()
        .filter(|l| !l.trim().is_empty() && !only_v1)
    {
        let e: Entry = serde_json::from_str(line).map_err(|e| e.to_string())?;
        if let Some(reason) = era_exclusion(&e.params.era) {
            excluded.push(Excluded {
                id: e.id.clone(),
                reason,
            });
            continue;
        }
        let row = xsig_row(&e)?;
        // the conversion's check: the hand signer on the row's own coin reproduces the xsig-144 transaction that was
        // signed over the correct scriptCode (RFC 6979 nonces, low S on both sides)
        let same = control(&row)? == e.tx;
        xsig_converted.push(
            json!({"id": e.id, "template": row.signing.inputs[0].template,
            "unlock_template_bytes": row.signing.inputs[0].unlock_template.len() / 2,
            "reproduces_the_signed_row": same}),
        );
        rows.push(row);
    }

    let (conf, conf_lines) = instance_conf(root)?;
    let binary = PathBuf::from(std::env::var("HOME").map_err(|_| "HOME absent")?)
        .join("bsv/targets/sv-v1.2.3-wallet/bin/bitcoind");
    let mut node = Node::start_with(&run.0, NodeSpec { binary, conf })?;
    let addr = node.call("getnewaddress", json!([]))?;
    node.call("generatetoaddress", json!([MINE_TO, addr]))?;

    // fund: one wallet transaction per (row, slot), mined in batches
    let slots = slots();
    let mut funding: BTreeMap<(usize, usize), (String, String)> = BTreeMap::new();
    let mut pending = 0usize;
    for (r, row) in rows.iter().enumerate() {
        for s in 0..slots.len() {
            let template = funding_template(row);
            let n = template.outputs.len();
            let funded = node.call(
                "fundrawtransaction",
                json!([hex::encode(template.encode()), {"changePosition": n}]),
            )?;
            let signed = node.call(
                "signrawtransaction",
                json!([funded["hex"].as_str().ok_or("fundrawtransaction hex")?]),
            )?;
            if signed["complete"] != true {
                return Err("the wallet did not sign a funding transaction".into());
            }
            let hex_tx = signed["hex"]
                .as_str()
                .ok_or("signrawtransaction hex")?
                .to_string();
            let tx = decode(&hex_tx)?;
            if tx.outputs[..n] != template.outputs[..] {
                return Err("the wallet moved a funding output".into());
            }
            node.call("sendrawtransaction", json!([hex_tx]))?;
            funding.insert((r, s), (txid(&tx), hex_tx));
            pending += 1;
            if pending == FUND_BATCH {
                mine_all(&mut node, &addr)?;
                pending = 0;
            }
        }
    }
    mine_all(&mut node, &addr)?;
    let mut funded_height = BTreeMap::new();
    for (key, (id, _)) in &funding {
        let h = height_of(&mut node, id)?.ok_or("a funding transaction was not mined")?;
        if h <= CHRONICLE_HEIGHT {
            return Err("a funding coin is not post-Chronicle".into());
        }
        funded_height.insert(*key, h);
    }
    let chain = node.call("getblockchaininfo", json!([]))?;
    let tip = chain["blocks"].as_u64().ok_or("tip height")? as u32;
    let median_time = chain["mediantime"].as_u64().ok_or("median time")?;
    let spend_height = tip + 1;

    // sign, judge, submit
    let mut outcomes = Vec::new();
    for (s, (engine, method)) in slots.iter().enumerate() {
        let rebound: Vec<Row> = rows
            .iter()
            .enumerate()
            .map(|(r, row)| rebind(row, &funding[&(r, s)].0, funded_height[&(r, s)]))
            .collect::<Result<_>>()?;
        let stem = format!("{engine}-{method}");
        let text = rebound
            .iter()
            .map(|r| serde_json::to_string(r).map(|l| l + "\n"))
            .collect::<std::result::Result<String, _>>()
            .map_err(|e| e.to_string())?;
        std::fs::write(rebound_dir.join(format!("{stem}.jsonl")), text)
            .map_err(|e| e.to_string())?;
        let signed: Vec<(Option<String>, String)> = if *engine == CONTROL.0 {
            rebound
                .iter()
                .map(|r| control(r).map(|t| (Some(t), String::new())))
                .collect::<Result<_>>()?
        } else {
            let lines = adapter(root, &run.0, engine, &rebound, &stem)?;
            rebound
                .iter()
                .map(|r| {
                    let l = lines
                        .iter()
                        .find(|l| l.id == r.entry.id && l.method == *method && l.engine == *engine)
                        .ok_or_else(|| {
                            format!("{engine} wrote no {method} line for {}", r.entry.id)
                        })?;
                    if let Some(t) = &l.tx_hex {
                        let mut raw = decode(t)?;
                        raw.inputs.iter_mut().for_each(|i| i.script.clear());
                        if raw != decode(&r.entry.tx)? {
                            return Err(format!(
                                "{engine} changed the unsigned transaction of {}",
                                r.entry.id
                            ));
                        }
                    } else if l.note.trim().is_empty() {
                        return Err(format!(
                            "{engine} left {} unsigned without a reason",
                            r.entry.id
                        ));
                    }
                    Ok((l.tx_hex.clone(), l.note.clone()))
                })
                .collect::<Result<_>>()?
        };
        for (r, (row, (tx_hex, note))) in rebound.iter().zip(signed).enumerate() {
            let (fid, fhex) = &funding[&(r, s)];
            let fh = funded_height[&(r, s)];
            let mut words = Vec::new();
            for p in &row.entry.prevouts {
                words.push([
                    oracle.word(spend_height, p.height, true)?,
                    oracle.word(spend_height, p.height, false)?,
                ]);
            }
            let mut o = Outcome {
                id: row.entry.id.clone(),
                engine: engine.to_string(),
                method: method.to_string(),
                family: row.entry.family.clone(),
                unsigned: tx_hex.is_none().then_some(note),
                tx_hex: tx_hex.clone(),
                txid: None,
                funding_txid: fid.clone(),
                funding_tx_hex: fhex.clone(),
                funding_height: fh,
                prevouts: row
                    .entry
                    .prevouts
                    .iter()
                    .map(|p| json!({"outpoint": format!("{}:{}", p.txid, p.vout), "script": p.script, "satoshis": p.satoshis}))
                    .collect(),
                block: Vec::new(),
                relay: Vec::new(),
                words: words.clone(),
                predicted_final: is_final(&decode(&row.entry.tx)?, spend_height, median_time),
                submit: None,
                mined: None,
                in_nonfinal_pool: None,
                spend_height,
                class: String::new(),
            };
            if let Some(t) = &tx_hex {
                let block: Vec<u32> = words.iter().map(|w| w[0]).collect();
                let relay: Vec<u32> = words.iter().map(|w| w[1]).collect();
                o.block = node.judge(row, t, &block)?;
                o.relay = node.judge(row, t, &relay)?;
                o.txid = Some(txid(&decode(t)?));
                o.submit = Some(submit(&mut node, t)?);
            }
            outcomes.push(o);
        }
    }
    let nonfinal: Vec<String> = node
        .call("getrawnonfinalmempool", json!([]))?
        .as_array()
        .ok_or("getrawnonfinalmempool")?
        .iter()
        .filter_map(|v| v.as_str().map(str::to_string))
        .collect();
    let spend_blocks = mine_all(&mut node, &addr)?;
    for o in &mut outcomes {
        if let (Some(s), Some(id)) = (&o.submit, &o.txid) {
            if s.verdict == "accepted" {
                let h = height_of(&mut node, id)?;
                if let Some(h) = h {
                    // the words hold for any height past Chronicle; the line carries the block's
                    o.spend_height = h;
                }
                o.mined = Some(h.is_some());
                o.in_nonfinal_pool = Some(nonfinal.contains(id));
            }
        }
        o.class = compare(o);
    }
    let words_table = json!(oracle
        .table()
        .iter()
        .map(|((sh, uh, c), w)| json!({"spend_height": sh, "utxo_height": uh, "consensus": c, "word": w}))
        .collect::<Vec<_>>());
    let node_sha256 = node.binary_sha256.clone();
    let port = node.port;
    node.stop()?;
    drop(node);
    std::fs::remove_dir_all(&run.0).map_err(|e| format!("remove run directory: {e}"))?;

    // counts, the emitted set, the record
    let mut counts: BTreeMap<String, SlotCounts> = BTreeMap::new();
    let mut red = Vec::new();
    for o in &outcomes {
        let c = counts
            .entry(format!("{} {}", o.engine, o.method))
            .or_default();
        c.funded += 1;
        match &o.submit {
            None => {
                *c.unsigned
                    .entry(o.unsigned.clone().unwrap_or_default())
                    .or_default() += 1
            }
            Some(s) => {
                c.signed += 1;
                if s.verdict == "accepted" {
                    c.accepted += 1;
                } else {
                    let key = match &s.reject_code {
                        Some(code) => {
                            format!("{} ({code})", s.reject_token.as_deref().unwrap_or(""))
                        }
                        None => s.reject_token.clone().unwrap_or_default(),
                    };
                    *c.rejected.entry(key).or_default() += 1;
                }
            }
        }
        if o.mined == Some(true) {
            c.mined += 1;
        }
        if o.in_nonfinal_pool == Some(true) {
            c.nonfinal_pool += 1;
        }
        match o.class.as_str() {
            "agree" => c.agree += 1,
            "finality" => c.finality += 1,
            "unsigned" => {}
            why => {
                c.red += 1;
                red.push(json!({"id": o.id, "engine": o.engine, "method": o.method, "why": why}));
            }
        }
    }
    let mut emitted = None;
    if let Some(path) = &emit {
        let mut text = String::new();
        for o in &outcomes {
            let line = json!({
                "id": o.id, "engine": o.engine, "method": o.method, "tx_hex": o.tx_hex,
                "prevouts": o.prevouts, "funding_tx_hex": o.funding_tx_hex,
                "reference_verdict": o.submit.as_ref().map(|s| s.verdict.clone()),
                "reject_token": o.submit.as_ref().and_then(|s| s.reject_token.clone()),
                "reject_code": o.submit.as_ref().and_then(|s| s.reject_code.clone()),
                "mined": o.mined, "spend_height": o.spend_height, "funding_height": o.funding_height,
                "unsigned": o.unsigned,
            });
            text += &serde_json::to_string(&line).map_err(|e| e.to_string())?;
            text.push('\n');
        }
        std::fs::write(path, &text).map_err(|e| format!("write {}: {e}", path.display()))?;
        emitted = Some(
            json!({"path": path.display().to_string(), "lines": outcomes.len(),
            "bytes": text.len(), "sha256": hex::encode(sha256(text.as_bytes()))}),
        );
    }
    let agree: usize = counts.values().map(|c| c.agree).sum();
    let finality: usize = counts.values().map(|c| c.finality).sum();
    let signed: usize = counts.values().map(|c| c.signed).sum();
    let verdict_line = format!(
        "signer chain: {} [M] ({} rows on the chain, {} slots, {} funded, {} signed, CHAIN AGREES WITH COLUMN on {}, finality apart {}, RED {})",
        if red.is_empty() { "GREEN" } else { "RED" },
        rows.len(),
        slots.len(),
        outcomes.len(),
        signed,
        agree,
        finality,
        red.len()
    );
    println!("{verdict_line}");
    let source_sha256: BTreeMap<String, String> = [
        "harness/src/bin/run_signer_chain.rs",
        "harness/src/signer_node.rs",
        "harness/src/signer.rs",
        "harness/src/bin/signer_bsvrs.rs",
        "harness/src/flags_oracle.rs",
        "harness/src/svnode_codes.rs",
        "harness/Cargo.lock",
        "harness/oracle/bitcoin.conf",
        "corpus/signer/manifest.json",
        "corpus/xsig-144/xsig-144.jsonl",
        "harness/engines/go/signer/main.go",
        "harness/engines/go/go.sum",
        "harness/engines/ts/signer.mjs",
        "harness/engines/ts/package-lock.json",
    ]
    .into_iter()
    .map(|p| Ok((p.to_string(), file_hash(&root.join(p))?)))
    .collect::<Result<_>>()?;
    let record = json!({
        "label": "[M]", "stamp": stamp, "verdict_line": verdict_line,
        "source_commit": output(Command::new("git").args(["rev-parse", "HEAD"]).current_dir(root), "source commit")?.trim(),
        "source_sha256": source_sha256,
        "runner_sha256": file_hash(&std::env::current_exe().map_err(|e| e.to_string())?)?,
        "evaluator_sha256": file_hash(&evaluator)?,
        "instance": {"binary": "~/bsv/targets/sv-v1.2.3-wallet/bin/bitcoind", "binary_sha256": node_sha256,
            "rpc_port": port, "conf_lines_changed": conf_lines, "genesis_height": GENESIS_HEIGHT,
            "chronicle_height": CHRONICLE_HEIGHT, "mined_to_before_funding": MINE_TO,
            "tip_before_spends": tip, "spend_height_asked": spend_height, "spend_blocks_mined": spend_blocks, "median_time_past": median_time,
            "stopped_and_removed": true},
        "rows_selected": if only_v1 { "version-1 (--version-1)" } else { "all" },
        "rows_on_chain": rows.len(), "slots": slots.iter().map(|(e, m)| format!("{e} {m}")).collect::<Vec<_>>(),
        "funding_transactions": funding.len(),
        "xsig_converted": xsig_converted,
        "excluded": excluded,
        "counts": counts, "agree": agree, "finality": finality, "red": red,
        "words": words_table, "rebound_dir": rebound_dir.display().to_string(), "emitted": emitted,
        "outcomes": outcomes.iter().map(|o| json!({"id": o.id, "engine": o.engine, "method": o.method,
            "txid": o.txid, "funding_txid": o.funding_txid, "funding_height": o.funding_height,
            "block": o.block, "relay": o.relay, "words": o.words, "predicted_final": o.predicted_final,
            "submit": o.submit, "mined": o.mined, "in_nonfinal_pool": o.in_nonfinal_pool,
            "unsigned": o.unsigned, "class": o.class})).collect::<Vec<_>>(),
    });
    let record_dir = std::env::var_os("SIGNER_RECORD_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| root.join("docs/records"));
    std::fs::create_dir_all(&record_dir).map_err(|e| e.to_string())?;
    let suffix = if only_v1 { "-v1" } else { "" };
    let path = record_dir.join(format!("{stamp}-s3-152-signer-chain{suffix}-s3.json"));
    write_json(&path, &record)?;
    println!("record: {}", path.display());
    println!(
        "signer chain cleanup: GREEN [X] (owned node stopped and reaped; run directory removed)"
    );
    if !red.is_empty() {
        return Err(format!(
            "{} differences between the chain and the column",
            red.len()
        ));
    }
    Ok(())
}

// ===================== #152 step 2: the Teranode submission oracle (the hazard rung) =====================
//
// The same rows as step 1 (the post-Chronicle signer rows and the 10 xsig-144 rows, the same exclusions by id),
// funded on a Teranode regtest chain past height 200, re-signed by the hand signer and the three adapters, every
// signed transaction submitted through the observation contract's mempool road (`sendrawtransaction`, the same road
// step 1's `reference_verdict` recorded), its verdict kept to the contract's enumerated words. The verdict class per
// (row, engine, method) is then compared with the reference's from step 1's emitted set. A chain of `funding ->
// prevouts` is built from a reservoir of P2PKH outputs funded by the deterministic well, because Teranode has no
// wallet (`run_teranode.rs`'s road). All node I/O goes through `Instance41` (the contract); the instance itself is
// started and stopped by its recipe (`instance.py`) outside this binary.

/// The funding transaction's fee (reservoir output value over the row's prevout sum).
const FUNDING_FEE: u64 = 5_000;
/// The reservoir transaction's fee.
const RESERVOIR_FEE: u64 = 100_000;
/// Reservoir outputs per reservoir transaction (keeps each reservoir transaction a standard size).
const RES_CHUNK: usize = 400;
/// Funding transactions mined per block (block assembly takes them asynchronously).
const TERA_FUND_BATCH: usize = 200;

/// The deterministic P2PKH well the funding road spends from (the same label and derivation as `run_teranode.rs`'s
/// `well()`): its key, its locking script and its regtest base58check address.
fn well() -> Result<(PrivateKey, Vec<u8>, String)> {
    let key = PrivateKey::from_bytes(&sha256(b"bsv-script-lean/instance41/well"))
        .map_err(|e| format!("well key: {e}"))?;
    let h = hash160(&key.public_key().to_compressed());
    let script = [vec![0x76, 0xa9, 0x14], h.to_vec(), vec![0x88, 0xac]].concat();
    let mut data = vec![0x6f];
    data.extend(h);
    data.extend(&sha256(&sha256(&data))[..4]);
    let mut digits = vec![0u8];
    for byte in data {
        let mut carry = u32::from(byte);
        for d in &mut digits {
            carry += u32::from(*d) << 8;
            *d = (carry % 58) as u8;
            carry /= 58;
        }
        while carry != 0 {
            digits.push((carry % 58) as u8);
            carry /= 58;
        }
    }
    const ABC: &[u8] = b"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
    let address = digits
        .iter()
        .rev()
        .map(|d| ABC[*d as usize] as char)
        .collect();
    Ok((key, script, address))
}

/// The running instance of #41, read and written only through the observation contract, with a journal of every
/// call (surface, request, the node's whole answer, the handler) kept under the quarantine. Nothing a node replied
/// enters the record; the journal file is the audit trail, outside the checkout.
struct Tera {
    node: Instance41,
    journal: BufWriter<File>,
}

impl Tera {
    fn drain(&mut self) -> Result<()> {
        for entry in self.node.take_journal() {
            serde_json::to_writer(&mut self.journal, &entry).map_err(|e| e.to_string())?;
            self.journal.write_all(b"\n").map_err(|e| e.to_string())?;
        }
        self.journal.flush().map_err(|e| e.to_string())
    }

    /// The tip's height and the candidate's parent median time (`tip_mtp`), through gRPC.
    fn tip(&mut self) -> Result<(u32, u32)> {
        let t = self.node.tip().map_err(|t| t.to_string());
        self.drain()?;
        let t = t?;
        Ok((t.height, t.tip_mtp))
    }

    fn mine(&mut self, n: u32, addr: &str) -> Result<()> {
        let r = self.node.mine(n, addr).map_err(|t| t.to_string());
        self.drain()?;
        r.map(|_| ())
    }

    /// Mine one block after block assembly's mining candidate counts at least `pending` transactions
    /// (assembly is asynchronous; a block generated earlier is empty).
    fn mine_pending(&mut self, pending: u64, addr: &str) -> Result<()> {
        let start = Instant::now();
        loop {
            let c = self.node.candidate_count().map_err(|t| t.to_string());
            self.drain()?;
            let (n, _) = c?;
            if n >= pending {
                break;
            }
            if start.elapsed() >= Duration::from_secs(300) {
                return Err(format!(
                    "block assembly did not count {pending} transactions within 300 seconds"
                ));
            }
            std::thread::sleep(Duration::from_millis(250));
        }
        self.mine(1, addr)
    }

    /// Submit through `sendrawtransaction` (the mempool road, the road step 1's reference verdict recorded):
    /// the verdict word (`accepted`/`rejected`), the innermost enumerated node code of a refusal and the RPC code.
    fn submit_rpc(&mut self, raw: &[u8]) -> Result<(String, Option<String>, Option<i64>)> {
        let r = self
            .node
            .submit(raw, SubmitRoad::Rpc)
            .map_err(|t| t.to_string());
        self.drain()?;
        let submitted = r?;
        Ok(match submitted.verdict {
            Ok(_) => ("accepted".into(), None, None),
            Err(refusal) => ("rejected".into(), refusal.innermost, refusal.rpc_code),
        })
    }
}

/// The reference's verdict for one (row, engine, method), read from step 1's emitted set.
struct RefVerdict {
    verdict: Option<String>,
    reject_token: Option<String>,
}

#[derive(Clone, Debug, Serialize)]
struct TeraOutcome {
    id: String,
    engine: String,
    method: String,
    family: String,
    unsigned: Option<String>,
    txid: Option<String>,
    funding_txid: String,
    funding_height: u32,
    spend_height: u32,
    predicted_final: bool,
    verdict: Option<String>,
    reject_token: Option<String>,
    rpc_code: Option<i64>,
    reference_verdict: Option<String>,
    reference_reject_token: Option<String>,
    comparison: String,
}

#[derive(Default, Serialize)]
struct TeraCounts {
    funded: usize,
    signed: usize,
    unsigned: usize,
    accepted: usize,
    rejected: usize,
    agree: usize,
    finality: usize,
    differ: usize,
    finding: usize,
    red: usize,
}

/// The ids any classifier (`harness/rules/gobdk.json`, `second-oracle-scenarios.json`) names, to the class name.
fn classifier_ids(root: &Path) -> Result<BTreeMap<String, String>> {
    let mut map = BTreeMap::new();
    for file in [
        "harness/rules/gobdk.json",
        "harness/rules/second-oracle-scenarios.json",
    ] {
        let v: Value = serde_json::from_str(&read(&root.join(file))?).map_err(|e| e.to_string())?;
        for row in v["rows"].as_array().into_iter().flatten() {
            let class = row["class"].as_str().unwrap_or("").to_string();
            for id in row["when"]["id_in"]
                .as_array()
                .into_iter()
                .flatten()
                .filter_map(Value::as_str)
            {
                map.insert(id.to_string(), class.clone());
            }
        }
    }
    Ok(map)
}

/// The comparison class of one (row, engine, method): `agree` (same verdict class), `finality` (the reference
/// admitted a non-final spend to its non-final pool where Teranode's mempool refuses it by the lock-time rule, a
/// known mempool difference counted apart), `classified: <class>` (a classifier names the row), `FINDING` (an
/// unexplained accepted/rejected difference), `unsigned` (both left it unsigned), or `RED: ...` (a signing or
/// bookkeeping inconsistency between the two runs).
fn tera_compare(o: &TeraOutcome, classifiers: &BTreeMap<String, String>) -> String {
    match (&o.verdict, &o.reference_verdict) {
        (None, None) => "unsigned".into(),
        (None, Some(_)) => "RED: the reference signed this slot; here it is unsigned".into(),
        (Some(_), None) => "RED: the reference left this slot unsigned; here it is signed".into(),
        (Some(tv), Some(rv)) => {
            if tv == rv {
                "agree".into()
            } else if !o.predicted_final
                && rv == "accepted"
                && tv == "rejected"
                && matches!(
                    o.reject_token.as_deref(),
                    Some("TX_LOCK_TIME" | "UTXO_NON_FINAL")
                )
            {
                "finality".into()
            } else {
                match classifiers.get(&o.id) {
                    Some(c) => format!("classified: {c}"),
                    None => "FINDING".into(),
                }
            }
        }
    }
}

fn run_teranode_oracle(args: &[String]) -> Result<()> {
    let root = Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .ok_or("repository root")?;
    let reference_set_paths: Vec<PathBuf> = args_all(args, "--reference-set")
        .into_iter()
        .map(PathBuf::from)
        .collect();
    if reference_set_paths.is_empty() {
        return Err("--reference-set <step-1 set.jsonl> is required for --oracle teranode (repeatable: step 1 emitted the default set and the version-1 set; pass each)".into());
    }
    let out_dir =
        PathBuf::from(arg(args, "--out").ok_or("--out <quarantine run directory> is required")?);
    let limit: usize = arg(args, "--limit")
        .map(|s| s.parse().map_err(|_| "--limit".to_string()))
        .transpose()?
        .unwrap_or(usize::MAX);
    std::fs::create_dir_all(&out_dir).map_err(|e| e.to_string())?;
    let stamp = output(
        Command::new("date").args(["-u", "+%Y%m%d-%H%M%S"]),
        "UTC stamp",
    )?
    .trim()
    .to_string();

    // The rows on this chain (the same selection as step 1) and the rows not.
    let mut rows = Vec::new();
    let mut excluded = Vec::new();
    for row in signer_rows(root)? {
        match exclusion(&row) {
            Some(reason) => excluded.push(Excluded {
                id: row.entry.id.clone(),
                reason,
            }),
            None => rows.push(row),
        }
    }
    let mut xsig_ids = Vec::new();
    for line in read(&root.join("corpus/xsig-144/xsig-144.jsonl"))?
        .lines()
        .filter(|l| !l.trim().is_empty())
    {
        let e: Entry = serde_json::from_str(line).map_err(|e| e.to_string())?;
        if let Some(reason) = era_exclusion(&e.params.era) {
            excluded.push(Excluded {
                id: e.id.clone(),
                reason,
            });
            continue;
        }
        let row = xsig_row(&e)?;
        xsig_ids.push(row.entry.id.clone());
        rows.push(row);
    }
    if rows.len() > limit {
        rows.truncate(limit);
    }
    let slots = slots();

    // The reference's verdicts from step 1's emitted set(s), keyed by (id, engine, method). Step 1 emitted
    // one set per run (the default and the version-1); the sets are disjoint by this key and an overlap is an error.
    let mut reference: BTreeMap<(String, String, String), RefVerdict> = BTreeMap::new();
    for path in &reference_set_paths {
        for line in read(path)?.lines().filter(|l| !l.trim().is_empty()) {
            let v: Value = serde_json::from_str(line).map_err(|e| e.to_string())?;
            let key = (
                v["id"].as_str().ok_or("reference set id")?.to_string(),
                v["engine"]
                    .as_str()
                    .ok_or("reference set engine")?
                    .to_string(),
                v["method"]
                    .as_str()
                    .ok_or("reference set method")?
                    .to_string(),
            );
            if reference
                .insert(
                    key.clone(),
                    RefVerdict {
                        verdict: v["reference_verdict"].as_str().map(str::to_string),
                        reject_token: v["reject_token"].as_str().map(str::to_string),
                    },
                )
                .is_some()
            {
                return Err(format!(
                    "the reference sets overlap at ({}, {}, {}); step 1's sets must be disjoint",
                    key.0, key.1, key.2
                ));
            }
        }
    }

    // The running instance, read only through the contract.
    let node = Instance41::new(&out_dir.join("rpc.cookie"))?;
    let mut tera = Tera {
        node,
        journal: BufWriter::new(
            File::create(out_dir.join("rpc.jsonl")).map_err(|e| e.to_string())?,
        ),
    };
    let chain = tera.node.chain().map_err(|t| t.to_string());
    tera.drain()?;
    if chain? != "regtest" {
        return Err("the instance is not a regtest chain".into());
    }

    // Fund: bake past Chronicle with mature coinbases to the well, build a reservoir of one output per (row, slot),
    // then one funding transaction per (row, slot) whose outputs are the row's prevouts (locking script, satoshis).
    let (key, script, address) = well()?;
    let (tip0, _) = tera.tip()?;
    let bake_to = (CHRONICLE_HEIGHT + 10).max(tip0 + 101);
    {
        let mut h = tip0;
        while h < bake_to {
            let n = (bake_to - h).min(100);
            tera.mine(n, &address)?;
            let (nh, _) = tera.tip()?;
            if nh != h + n {
                return Err(format!("mined to {nh}, expected {}", h + n));
            }
            h = nh;
        }
    }
    let (tip_now, _) = tera.tip()?;
    let n_total = rows.len() * slots.len();
    let value_at = |gi: usize| -> Result<u64> {
        rows[gi / slots.len()]
            .entry
            .prevouts
            .iter()
            .try_fold(0u64, |s, p| s.checked_add(p.satoshis))
            .and_then(|v| v.checked_add(FUNDING_FEE))
            .ok_or_else(|| "prevout value overflow".to_string())
    };
    let mut reservoirs: Vec<RawTx> = Vec::new();
    let mut cb_cursor = tip0 + 1;
    let mut gi = 0usize;
    while gi < n_total {
        let count = RES_CHUNK.min(n_total - gi);
        let mut outs = Vec::with_capacity(count + 1);
        let mut need = RESERVOIR_FEE;
        for k in 0..count {
            let v = value_at(gi + k)?;
            need = need.checked_add(v).ok_or("reservoir need overflow")?;
            outs.push(RawOutput {
                satoshis: v,
                script: script.clone(),
            });
        }
        let mut cb_inputs = Vec::new();
        let mut gathered = 0u64;
        while gathered < need {
            if cb_cursor + 100 > tip_now {
                return Err(format!(
                    "not enough mature coinbase value (gathered {gathered}, need {need})"
                ));
            }
            let blk = tera
                .node
                .block(BlockRef::Height(cb_cursor))
                .map_err(|t| t.to_string());
            tera.drain()?;
            let blk = blk?.ok_or_else(|| format!("no block at height {cb_cursor}"))?;
            let coinbase = decode(blk.coinbase_tx.as_deref().ok_or("coinbase hex")?)?;
            let (vout, out) = coinbase
                .outputs
                .iter()
                .enumerate()
                .find(|(_, o)| o.script == script)
                .ok_or("the coinbase does not pay the well")?;
            cb_inputs.push((coinbase.txid_internal(), vout as u32, out.satoshis));
            gathered = gathered
                .checked_add(out.satoshis)
                .ok_or("coinbase sum overflow")?;
            cb_cursor += 1;
        }
        outs.push(RawOutput {
            satoshis: gathered - need,
            script: script.clone(),
        });
        let res = try_p2pkh_spend(&cb_inputs, outs, &key, &script)?;
        let (v, tok, _) = tera.submit_rpc(&res.encode())?;
        if v != "accepted" {
            return Err(format!("reservoir chunk at {gi} {v}: {tok:?}"));
        }
        reservoirs.push(res);
        gi += count;
    }
    tera.mine_pending(reservoirs.len() as u64, &address)?;

    let mut funding: BTreeMap<(usize, usize), (String, RawTx)> = BTreeMap::new();
    let mut pending = 0usize;
    for (r, row) in rows.iter().enumerate() {
        for s in 0..slots.len() {
            let gi = r * slots.len() + s;
            let res = &reservoirs[gi / RES_CHUNK];
            let lv = gi % RES_CHUNK;
            let template = funding_template(row);
            let funding_tx = try_p2pkh_spend(
                &[(res.txid_internal(), lv as u32, res.outputs[lv].satoshis)],
                template.outputs,
                &key,
                &script,
            )?;
            let (v, tok, _) = tera.submit_rpc(&funding_tx.encode())?;
            if v != "accepted" {
                return Err(format!("funding (row {r}, slot {s}) {v}: {tok:?}"));
            }
            let fid = txid(&funding_tx);
            funding.insert((r, s), (fid, funding_tx));
            pending += 1;
            if pending >= TERA_FUND_BATCH {
                tera.mine_pending(pending as u64, &address)?;
                pending = 0;
            }
        }
    }
    if pending > 0 {
        tera.mine_pending(pending as u64, &address)?;
    }
    let mut funded_height = BTreeMap::new();
    for ((r, s), (txid_disp, _)) in &funding {
        let rec = tera.node.tx_record(txid_disp).map_err(|t| t.to_string());
        tera.drain()?;
        let h = rec?
            .and_then(|r| r.block_heights.into_iter().min())
            .ok_or_else(|| format!("funding (row {r}, slot {s}) {txid_disp} was not mined"))?;
        if h <= CHRONICLE_HEIGHT {
            return Err("a funding coin is not post-Chronicle".into());
        }
        funded_height.insert((*r, *s), h);
    }
    let (tip, mtp) = tera.tip()?;
    let spend_height = tip + 1;

    // Sign (the hand signer and the three adapters, exactly as step 1) and submit each spend through the mempool.
    let scratch = out_dir.join("adapters");
    std::fs::create_dir_all(&scratch).map_err(|e| e.to_string())?;
    let mut outcomes = Vec::new();
    for (s, (engine, method)) in slots.iter().enumerate() {
        let rebound: Vec<Row> = rows
            .iter()
            .enumerate()
            .map(|(r, row)| rebind(row, &funding[&(r, s)].0, funded_height[&(r, s)]))
            .collect::<Result<_>>()?;
        let stem = format!("{engine}-{method}");
        let signed: Vec<(Option<String>, String)> = if *engine == CONTROL.0 {
            rebound
                .iter()
                .map(|r| control(r).map(|t| (Some(t), String::new())))
                .collect::<Result<_>>()?
        } else {
            let lines = adapter(root, &scratch, engine, &rebound, &stem)?;
            rebound
                .iter()
                .map(|r| {
                    let l = lines
                        .iter()
                        .find(|l| l.id == r.entry.id && l.method == *method && l.engine == *engine)
                        .ok_or_else(|| {
                            format!("{engine} wrote no {method} line for {}", r.entry.id)
                        })?;
                    if let Some(t) = &l.tx_hex {
                        let mut raw = decode(t)?;
                        raw.inputs.iter_mut().for_each(|i| i.script.clear());
                        if raw != decode(&r.entry.tx)? {
                            return Err(format!(
                                "{engine} changed the unsigned transaction of {}",
                                r.entry.id
                            ));
                        }
                    } else if l.note.trim().is_empty() {
                        return Err(format!(
                            "{engine} left {} unsigned without a reason",
                            r.entry.id
                        ));
                    }
                    Ok((l.tx_hex.clone(), l.note.clone()))
                })
                .collect::<Result<_>>()?
        };
        for (r, (row, (tx_hex, note))) in rebound.iter().zip(signed).enumerate() {
            let key3 = (row.entry.id.clone(), engine.to_string(), method.to_string());
            let refv = reference.get(&key3);
            let mut o = TeraOutcome {
                id: row.entry.id.clone(),
                engine: engine.to_string(),
                method: method.to_string(),
                family: row.entry.family.clone(),
                unsigned: tx_hex.is_none().then_some(note),
                txid: None,
                funding_txid: funding[&(r, s)].0.clone(),
                funding_height: funded_height[&(r, s)],
                spend_height,
                predicted_final: is_final(&decode(&row.entry.tx)?, spend_height, u64::from(mtp)),
                verdict: None,
                reject_token: None,
                rpc_code: None,
                reference_verdict: refv.and_then(|r| r.verdict.clone()),
                reference_reject_token: refv.and_then(|r| r.reject_token.clone()),
                comparison: String::new(),
            };
            if let Some(t) = &tx_hex {
                let raw = decode(t)?;
                o.txid = Some(txid(&raw));
                let (verdict, token, rpc_code) = tera.submit_rpc(&raw.encode())?;
                o.verdict = Some(verdict);
                o.reject_token = token;
                o.rpc_code = rpc_code;
            }
            outcomes.push(o);
        }
    }

    // Compare per (row, engine, method).
    let classifiers = classifier_ids(root)?;
    for o in &mut outcomes {
        o.comparison = tera_compare(o, &classifiers);
    }

    // Counts and the record.
    let mut counts: BTreeMap<String, TeraCounts> = BTreeMap::new();
    let mut reject_tokens: BTreeMap<String, usize> = BTreeMap::new();
    let mut findings = Vec::new();
    let mut reds = Vec::new();
    for o in &outcomes {
        let c = counts
            .entry(format!("{} {}", o.engine, o.method))
            .or_default();
        c.funded += 1;
        match &o.verdict {
            None => {
                c.unsigned += 1;
            }
            Some(v) => {
                c.signed += 1;
                if v == "accepted" {
                    c.accepted += 1;
                } else {
                    c.rejected += 1;
                    *reject_tokens
                        .entry(o.reject_token.clone().unwrap_or_else(|| "none".into()))
                        .or_default() += 1;
                }
            }
        }
        match o.comparison.as_str() {
            "agree" => c.agree += 1,
            "finality" => c.finality += 1,
            "unsigned" => {}
            "FINDING" => {
                c.finding += 1;
                findings.push(o.clone());
            }
            s if s.starts_with("classified:") => c.differ += 1,
            _ => {
                c.red += 1;
                reds.push(o.clone());
            }
        }
    }
    let funded: usize = counts.values().map(|c| c.funded).sum();
    let signed: usize = counts.values().map(|c| c.signed).sum();
    let unsigned: usize = counts.values().map(|c| c.unsigned).sum();
    let agree: usize = counts.values().map(|c| c.agree).sum();
    let finality: usize = counts.values().map(|c| c.finality).sum();
    let differ: usize = counts.values().map(|c| c.differ).sum();
    let finding: usize = counts.values().map(|c| c.finding).sum();
    let red: usize = counts.values().map(|c| c.red).sum();
    let verdict = if finding == 0 && differ == 0 && red == 0 {
        "agree"
    } else {
        "differ"
    };
    let verdict_line = format!(
        "teranode signer chain: {verdict} [M] ({} rows, {} slots, {funded} funded, {signed} signed, agree {agree}, finality {finality}, differ {differ}, finding {finding}, red {red}, unsigned {unsigned})",
        rows.len(),
        slots.len(),
    );
    println!("{verdict_line}");

    let record_dir = std::env::var_os("SIGNER_RECORD_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| root.join("docs/records"));
    std::fs::create_dir_all(&record_dir).map_err(|e| e.to_string())?;

    // The set: per (row, engine, method), the enumerated verdict words only (never a reply string).
    let set_path = record_dir.join(format!("{stamp}-s4b-152-teranode-signer-chain-set.jsonl"));
    let mut set_text = String::new();
    for o in &outcomes {
        set_text += &serde_json::to_string(&json!({
            "id": o.id, "engine": o.engine, "method": o.method,
            "teranode_verdict": o.verdict, "teranode_reject_token": o.reject_token, "teranode_rpc_code": o.rpc_code,
            "reference_verdict": o.reference_verdict, "reference_reject_token": o.reference_reject_token,
            "spend_height": o.spend_height, "funding_height": o.funding_height, "comparison": o.comparison,
        }))
        .map_err(|e| e.to_string())?;
        set_text.push('\n');
    }
    std::fs::write(&set_path, &set_text).map_err(|e| e.to_string())?;
    let set_sha = hex::encode(sha256(set_text.as_bytes()));

    // The reference set(s) as a list with each file's sha256; a prose list of the same for the record.
    let mut reference_sets_json = Vec::new();
    let mut ref_desc = String::new();
    for p in &reference_set_paths {
        let sha = file_hash(p)?;
        reference_sets_json.push(json!({"path": p.display().to_string(), "sha256": sha}));
        ref_desc += &format!(
            "{}`{}` sha256 `{}`",
            if ref_desc.is_empty() { "" } else { "; " },
            p.display(),
            sha
        );
    }
    let signer_rows_count = rows.len() - xsig_ids.len();

    let record = json!({
        "label": "[M]", "stamp": stamp, "verdict_line": verdict_line,
        "issue": "152 step 2 (the hazard rung): the signer chain submitted to Teranode, verdict classes compared with the reference's",
        "source_commit": output(Command::new("git").args(["rev-parse", "HEAD"]).current_dir(root), "source commit")?.trim(),
        "runner_sha256": file_hash(&std::env::current_exe().map_err(|e| e.to_string())?)?,
        "instance": {"tag": bsv_script_harness::teranode_contract::TAG, "pin": bsv_script_harness::teranode_contract::PIN,
            "genesis_height": GENESIS_HEIGHT, "chronicle_height": CHRONICLE_HEIGHT,
            "baked_to": bake_to, "spend_height": spend_height, "median_time_past": mtp,
            "reservoir_transactions": reservoirs.len(), "funding_transactions": funding.len()},
        "reference_sets": &reference_sets_json,
        "rows_on_chain": rows.len(), "xsig_rows": xsig_ids, "slots": slots.iter().map(|(e, m)| format!("{e} {m}")).collect::<Vec<_>>(),
        "excluded": excluded,
        "counts": &counts, "totals": {"funded": funded, "signed": signed, "unsigned": unsigned,
            "agree": agree, "finality": finality, "differ": differ, "finding": finding, "red": red},
        "reject_tokens": reject_tokens,
        "findings": findings.iter().map(|o| json!({"id": o.id, "engine": o.engine, "method": o.method,
            "teranode_verdict": o.verdict, "teranode_reject_token": o.reject_token,
            "reference_verdict": o.reference_verdict, "reference_reject_token": o.reference_reject_token})).collect::<Vec<_>>(),
        "red": reds.iter().map(|o| json!({"id": o.id, "engine": o.engine, "method": o.method, "why": o.comparison})).collect::<Vec<_>>(),
        "set": {"path": set_path.display().to_string(), "lines": outcomes.len(), "sha256": set_sha},
        "outcomes": outcomes.iter().map(|o| json!({"id": o.id, "engine": o.engine, "method": o.method,
            "family": o.family, "txid": o.txid, "funding_txid": o.funding_txid, "funding_height": o.funding_height,
            "unsigned": o.unsigned,
            "teranode_verdict": o.verdict, "teranode_reject_token": o.reject_token, "teranode_rpc_code": o.rpc_code,
            "reference_verdict": o.reference_verdict, "reference_reject_token": o.reference_reject_token,
            "predicted_final": o.predicted_final, "comparison": o.comparison})).collect::<Vec<_>>(),
    });
    let json_path = record_dir.join(format!("{stamp}-s4b-152-teranode-signer-chain-s4b.json"));
    write_json(&json_path, &record)?;

    // The prose record: counts, then a Finding paragraph per unexplained difference (its row id, both verdicts as
    // enumerated words, and the two pins' source files; line numbers only, no node reply).
    let mut md = String::new();
    md += &format!("# #152 step 2: the signer chain on Teranode (the hazard rung; withheld)\n\n{verdict_line}\n\n");
    md += &format!("[M] S4b with S3's commits, lane hz-152 on the box. The same rows as step 1 ({signer_rows_count} post-Chronicle signer rows and {} xsig-144 rows, the same exclusions by id), funded and re-signed on a Teranode regtest chain (Genesis 100, Chronicle 200; go-chaincfg v1.6.2) past height 200, every signed transaction submitted through the observation contract's mempool road (`sendrawtransaction`, the road step 1's reference verdict recorded, `services/rpc/handlers.go:830-935` at the pin). The verdict class per (row, engine, method) is compared with the reference's (bitcoin-sv v1.2.3 `6504a3af`) from step 1's emitted sets (step 1 ran the default selection and the version-1 selection, one set each, disjoint by row id; this run reads both). The reject-code vocabularies do not transfer between the columns (the observation contract's F4), so the comparison is on the accepted/rejected class; the enumerated tokens of both columns are tabled per row in the set beside this record.\n\n", xsig_ids.len());
    md += &format!("Instance {} `{}`; reference sets {ref_desc}; the Teranode set `{}` sha256 `{}`; the call journal under the quarantine.\n\n",
        bsv_script_harness::teranode_contract::TAG, bsv_script_harness::teranode_contract::PIN,
        set_path.display(), set_sha);
    md += &format!("Totals: {funded} funded, {signed} signed, {unsigned} unsigned; agree {agree}, finality apart {finality}, classified {differ}, FINDING {finding}, RED {red}.\n\n");
    md += "| engine method | funded | signed | accepted | rejected | agree | finality | differ | finding | red |\n|---|---|---|---|---|---|---|---|---|---|\n";
    for (slot, c) in &counts {
        md += &format!(
            "| {slot} | {} | {} | {} | {} | {} | {} | {} | {} | {} |\n",
            c.funded,
            c.signed,
            c.accepted,
            c.rejected,
            c.agree,
            c.finality,
            c.differ,
            c.finding,
            c.red
        );
    }
    md.push('\n');
    if finding == 0 && red == 0 {
        md += &format!("Every signed (row, engine, method) agrees with the reference on the accepted/rejected class (agree {agree}, finality apart {finality}, classified {differ}); no Finding.\n");
    } else {
        for o in findings.iter().chain(reds.iter()) {
            md += &format!(
                "**Finding.** Row `{}`, engine `{}`, method `{}`: Teranode's mempool verdict is `{}` (reject token `{}`) where the reference's is `{}` (reject token `{}`); comparison `{}`. The flag word and UTXO heights Teranode hands its engine for this height are set in `services/validator/Validator.go` and `services/validator/ScriptVerifierGoBDK.go` at Teranode v0.16.0 `{}`; the reference's are set in `src/script/interpreter.cpp` at bitcoin-sv v1.2.3 `6504a3af`. Line numbers are owed on this row from source; the submitted bytes and both node answers are in the quarantine journal.\n\n",
                o.id, o.engine, o.method,
                o.verdict.as_deref().unwrap_or("unsigned"), o.reject_token.as_deref().unwrap_or("none"),
                o.reference_verdict.as_deref().unwrap_or("unsigned"), o.reference_reject_token.as_deref().unwrap_or("none"),
                o.comparison, bsv_script_harness::teranode_contract::PIN
            );
        }
    }
    let md_path = record_dir.join(format!("{stamp}-s4b-152-teranode-signer-chain-s4b.md"));
    std::fs::write(&md_path, &md).map_err(|e| e.to_string())?;

    tera.journal.flush().map_err(|e| e.to_string())?;
    println!("record: {}", json_path.display());
    println!("record: {}", md_path.display());
    println!(
        "set: {} ({} lines, sha256 {set_sha})",
        set_path.display(),
        outcomes.len()
    );
    println!(
        "COUNTS: {funded} rows, {} slots signed, {agree} agree, {}, {unsigned} unsigned",
        slots.len(),
        finding + differ + red
    );
    if red > 0 {
        return Err(format!(
            "{red} rows are RED (a signing or bookkeeping inconsistency between the two runs)"
        ));
    }
    Ok(())
}

fn main() -> std::process::ExitCode {
    match run() {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("signer chain: RED [X] ({e})");
            std::process::ExitCode::FAILURE
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn root() -> &'static Path {
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .unwrap_or(Path::new("."))
    }

    #[test]
    fn args_all_collects_every_repeated_flag_value() {
        let a: Vec<String> = [
            "prog",
            "--oracle",
            "teranode",
            "--reference-set",
            "a.jsonl",
            "--out",
            "o",
            "--reference-set",
            "b.jsonl",
        ]
        .iter()
        .map(|s| s.to_string())
        .collect();
        assert_eq!(args_all(&a, "--reference-set"), vec!["a.jsonl", "b.jsonl"]);
        assert_eq!(arg(&a, "--reference-set").as_deref(), Some("a.jsonl"));
        assert!(args_all(&a, "--missing").is_empty());
    }

    #[test]
    fn rebinding_moves_only_the_outpoints_and_the_coin_heights() -> Result<()> {
        let row: Row = serde_json::from_str(
            include_str!("../../../corpus/signer/p2pk.jsonl")
                .lines()
                .find(|l| l.contains("\"signer-p2pk-00022\""))
                .ok_or("fixture row")?,
        )
        .map_err(|e| e.to_string())?;
        let funding = "ab".repeat(32);
        let out = rebind(&row, &funding, 301)?;
        let (a, b) = (decode(&row.entry.tx)?, decode(&out.entry.tx)?);
        assert_eq!(a.inputs.len(), 3);
        assert_eq!(
            (a.version, a.lock_time, &a.outputs),
            (b.version, b.lock_time, &b.outputs)
        );
        for (i, (x, y)) in a.inputs.iter().zip(&b.inputs).enumerate() {
            assert_eq!((x.sequence, &x.script), (y.sequence, &y.script));
            assert_eq!(y.txid, txid_from_display_hex(&funding)?);
            assert_eq!(y.vout, i as u32);
            let (p, q) = (&row.entry.prevouts[i], &out.entry.prevouts[i]);
            assert_eq!((&p.script, p.satoshis), (&q.script, q.satoshis));
            assert_eq!(
                (q.txid.as_str(), q.vout, q.height),
                (funding.as_str(), i as u32, 301)
            );
        }
        assert_eq!(
            (&out.signing, &out.entry.params, &out.entry.reference),
            (&row.signing, &row.entry.params, &row.entry.reference)
        );
        out.entry.check()?;
        // the hand signer over the rebound row signs other digests: the outpoints are in every preimage
        assert_ne!(control(&out)?, control(&row)?);
        // the funding template pays the row's coins, in order
        let f = funding_template(&row);
        assert!(f.inputs.is_empty());
        for (o, p) in f.outputs.iter().zip(&row.entry.prevouts) {
            assert_eq!(
                (hex::encode(&o.script), o.satoshis),
                (p.script.clone(), p.satoshis)
            );
        }
        Ok(())
    }

    #[test]
    fn xsig_rows_convert_and_the_correct_ones_reproduce() -> Result<()> {
        let mut seen = 0;
        for line in read(&root().join("corpus/xsig-144/xsig-144.jsonl"))?.lines() {
            let e: Entry = serde_json::from_str(line).map_err(|e| e.to_string())?;
            if e.params.era != "post-chronicle" {
                continue;
            }
            let row = xsig_row(&e)?;
            seen += 1;
            let note = e.note.as_deref().unwrap_or("");
            if note.contains("signed c:correct-scriptcode") || note.contains("signed c1:") {
                assert_eq!(control(&row)?, e.tx, "{}", e.id);
            } else if ["signed a:", "signed b:", "signed c2:"]
                .iter()
                .any(|v| note.contains(v))
            {
                assert_ne!(control(&row)?, e.tx, "{}", e.id);
            }
        }
        assert_eq!(seen, 10);
        Ok(())
    }

    #[test]
    fn exclusions_name_the_era_only() -> Result<()> {
        let rows = signer_rows(root())?;
        let ex: Vec<_> = rows.iter().filter_map(exclusion).collect();
        assert_eq!(rows.len(), 241);
        assert!(ex
            .iter()
            .all(|r| r.starts_with("pre-Genesis") || r.starts_with("post-Genesis")));
        assert_eq!(rows.len() - ex.len(), 230);
        let v1 = rows
            .iter()
            .filter(|r| exclusion(r).is_none() && version_one(r))
            .count();
        assert_eq!(v1, 59);
        Ok(())
    }

    #[test]
    fn finality_follows_the_lock_time_rule() {
        let tx = |lt: u32, seq: u32| RawTx {
            version: 2,
            inputs: vec![bsv_script_harness::txraw::RawInput {
                txid: [0; 32],
                vout: 0,
                script: vec![],
                sequence: seq,
            }],
            outputs: vec![],
            lock_time: lt,
        };
        assert!(is_final(&tx(0, 0), 301, 0));
        assert!(is_final(&tx(100, 0xffff_fffe), 301, 0));
        assert!(!is_final(&tx(499_999_999, 0xffff_fffe), 301, 0));
        assert!(is_final(&tx(499_999_999, u32::MAX), 301, 0));
        assert!(is_final(&tx(500_000_001, 0xffff_fffe), 301, 1_800_000_000));
    }

    #[test]
    fn a_column_refusal_beside_a_chain_acceptance_is_red() {
        let v = |ok: bool| Verdict {
            verdict: if ok { "valid" } else { "invalid" }.into(),
            code: (!ok).then(|| "SCRIPT_ERR_EVAL_FALSE".to_string()),
        };
        let mut o = Outcome {
            id: "x".into(),
            engine: "go-sdk".into(),
            method: "api-default".into(),
            family: "f".into(),
            unsigned: None,
            tx_hex: Some(String::new()),
            txid: None,
            funding_txid: String::new(),
            funding_tx_hex: String::new(),
            funding_height: 301,
            prevouts: vec![],
            block: vec![v(true)],
            relay: vec![v(true)],
            words: vec![],
            predicted_final: true,
            submit: Some(Submit {
                verdict: "accepted".into(),
                reject_token: None,
                reject_code: None,
            }),
            mined: Some(true),
            in_nonfinal_pool: Some(false),
            spend_height: 302,
            class: String::new(),
        };
        assert_eq!(compare(&o), "agree");
        o.relay = vec![v(false)];
        assert!(compare(&o).starts_with("RED"));
        o.submit = Some(Submit {
            verdict: "rejected".into(),
            reject_token: Some("mandatory-script-verify-flag-failed".into()),
            reject_code: Some("SCRIPT_ERR_EVAL_FALSE".into()),
        });
        o.mined = None;
        assert_eq!(compare(&o), "agree");
        if let Some(s) = o.submit.as_mut() {
            s.reject_code = Some("SCRIPT_ERR_NULLFAIL".into());
        }
        assert!(compare(&o).starts_with("RED"));
        o.relay = vec![v(true)];
        o.predicted_final = false;
        o.submit = Some(Submit {
            verdict: "accepted".into(),
            reject_token: None,
            reject_code: None,
        });
        o.mined = Some(false);
        o.in_nonfinal_pool = Some(true);
        assert_eq!(compare(&o), "finality");
        o.mined = Some(true);
        assert!(compare(&o).starts_with("RED"));
    }

    #[test]
    fn a_rejection_wrapping_no_script_error_beside_an_invalid_column_is_red() {
        let o = Outcome {
            id: "x".into(),
            engine: "go-sdk".into(),
            method: "api-default".into(),
            family: "f".into(),
            unsigned: None,
            tx_hex: Some(String::new()),
            txid: None,
            funding_txid: String::new(),
            funding_tx_hex: String::new(),
            funding_height: 301,
            prevouts: vec![],
            block: vec![],
            relay: vec![Verdict {
                verdict: "invalid".into(),
                code: Some("SCRIPT_ERR_EVAL_FALSE".into()),
            }],
            words: vec![],
            predicted_final: true,
            submit: Some(Submit {
                verdict: "rejected".into(),
                reject_token: Some("txn-mempool-conflict".into()),
                reject_code: None,
            }),
            mined: None,
            in_nonfinal_pool: None,
            spend_height: 302,
            class: String::new(),
        };
        assert_eq!(
            compare(&o),
            "RED: the reject code differs from the column's (or the rejection wraps no script error)"
        );
    }

    #[test]
    fn the_well_is_a_deterministic_regtest_p2pkh() -> Result<()> {
        let (_, script, address) = well()?;
        // OP_DUP OP_HASH160 <20> ... OP_EQUALVERIFY OP_CHECKSIG
        assert_eq!(script.len(), 25);
        assert_eq!(&script[..3], &[0x76, 0xa9, 0x14]);
        assert_eq!(&script[23..], &[0x88, 0xac]);
        // regtest/testnet P2PKH addresses begin with m or n.
        assert!(
            address.starts_with('m') || address.starts_with('n'),
            "{address}"
        );
        let (_, script2, address2) = well()?;
        assert_eq!((script, address), (script2, address2));
        Ok(())
    }

    #[test]
    fn tera_compare_buckets_agreement_finality_findings_and_classified() {
        let o = |tv: Option<&str>, tok: Option<&str>, rv: Option<&str>, fin: bool, id: &str| {
            TeraOutcome {
                id: id.into(),
                engine: "go-sdk".into(),
                method: "api-default".into(),
                family: "f".into(),
                unsigned: None,
                txid: None,
                funding_txid: String::new(),
                funding_height: 201,
                spend_height: 202,
                predicted_final: fin,
                verdict: tv.map(str::to_string),
                reject_token: tok.map(str::to_string),
                rpc_code: None,
                reference_verdict: rv.map(str::to_string),
                reference_reject_token: None,
                comparison: String::new(),
            }
        };
        let mut cls = BTreeMap::new();
        cls.insert("known-row".to_string(), "some.class".to_string());

        // both accepted, both rejected: agree (the reject vocabularies need not match, the observation
        // contract's F4, so a rejected/rejected pair is one class).
        assert_eq!(
            tera_compare(
                &o(Some("accepted"), None, Some("accepted"), true, "x"),
                &cls
            ),
            "agree"
        );
        assert_eq!(
            tera_compare(
                &o(
                    Some("rejected"),
                    Some("TX_INVALID"),
                    Some("rejected"),
                    true,
                    "x"
                ),
                &cls
            ),
            "agree"
        );
        // both unsigned: skipped.
        assert_eq!(
            tera_compare(&o(None, None, None, true, "x"), &cls),
            "unsigned"
        );
        // a non-final spend the reference admitted to its non-final pool, Teranode's mempool refuses by lock time.
        assert_eq!(
            tera_compare(
                &o(
                    Some("rejected"),
                    Some("TX_LOCK_TIME"),
                    Some("accepted"),
                    false,
                    "x"
                ),
                &cls
            ),
            "finality"
        );
        // an unexplained accepted/rejected difference the classifiers do not name: a Finding.
        assert_eq!(
            tera_compare(
                &o(Some("accepted"), None, Some("rejected"), true, "x"),
                &cls
            ),
            "FINDING"
        );
        assert_eq!(
            tera_compare(
                &o(
                    Some("rejected"),
                    Some("TX_POLICY"),
                    Some("accepted"),
                    true,
                    "x"
                ),
                &cls
            ),
            "FINDING"
        );
        // a classified row.
        assert_eq!(
            tera_compare(
                &o(Some("accepted"), None, Some("rejected"), true, "known-row"),
                &cls
            ),
            "classified: some.class"
        );
        // a signing inconsistency between the two runs.
        assert!(tera_compare(&o(None, None, Some("accepted"), true, "x"), &cls).starts_with("RED"));
        assert!(tera_compare(&o(Some("accepted"), None, None, true, "x"), &cls).starts_with("RED"));
    }
}
