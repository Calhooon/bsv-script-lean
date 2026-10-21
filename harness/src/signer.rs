//! THE SIGNABLE CORPUS's row and its hand signer (#145 piece 1, lane sign-145a, 2026-10-16; S3). A row of
//! `corpus/signer/<family>.jsonl` is the corpus `Entry` (`docs/DESIGN.md` §6) whose `tx` is UNSIGNED (every unlocking
//! script empty) plus a `signing` object: per input the template, the throwaway keys, the hash type, the sequence, the
//! scriptCode of every CHECKSIG site as the reference computes it, and the unlocking script as a template with tokens.
//! The contract the signer adapters read is `corpus/signer/README.md`; this module is the generator's and the
//! self-check's half of it.
//!
//! The scriptCode rule `[SRC]` bitcoin-sv v1.2.3 `6504a3af`: a CHECKSIG site signs the current script from its last
//! executed OP_CODESEPARATOR to its end (`interpreter.cpp:1471-1473`, `1567-1569` for CHECKMULTISIG); when the site is
//! in the unlocking script and the word carries SCRIPT_CHRONICLE the locking script is appended (`1474-1481`,
//! `1570-1577`; `VerifyScript` passes it as `checksigData`, `2338-2342`); with the FORKID bit nothing is deleted
//! (`CleanupScriptCode`, `255-263`). The digest dispatch: BIP143 when the hash type carries FORKID and not CHRONICLE,
//! the original digest otherwise (`SignatureHash`, `2112-2124`; `sighashtype.h` for the bits).

use bsv_rs::primitives::bsv::sighash::{
    build_sighash_preimage, compute_sighash_dispatched_for_signing, SighashParams,
};
use bsv_rs::primitives::ec::PrivateKey;
use serde::{Deserialize, Serialize};

use crate::cases::{der, pm, sighash_parts};
use crate::corpus::Entry;
use crate::txraw::RawTx;

pub const OP_CODESEPARATOR: u8 = 0xab;
pub const OP_CHECKSIG: u8 = 0xac;
pub const OP_CHECKSIGVERIFY: u8 = 0xad;
pub const OP_CHECKMULTISIG: u8 = 0xae;
pub const OP_CHECKMULTISIGVERIFY: u8 = 0xaf;

/// The hash type bits (`sighashtype.h`, v1.2.3).
pub const SIGHASH_ALL: u32 = 1;
pub const SIGHASH_NONE: u32 = 2;
pub const SIGHASH_SINGLE: u32 = 3;
pub const SIGHASH_CHRONICLE: u32 = 0x20;
pub const SIGHASH_FORKID: u32 = 0x40;
pub const SIGHASH_ANYONECANPAY: u32 = 0x80;

/// One input's signing instructions.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct SignInput {
    pub index: usize,
    /// `p2pkh` · `p2pk` · `multisig-<m>-of-<n>` · `checksig-in-unlock-a` · `checksig-in-unlock-b`
    pub template: String,
    /// The throwaway keys, hex; key K signs at site `sig_sites[K]`.
    pub privkeys: Vec<String>,
    /// `pubkeys[K]` is the compressed public key of `privkeys[K]`, hex.
    pub pubkeys: Vec<String>,
    pub sighash_type: u32,
    pub sequence: u32,
    /// The scriptCode of every CHECKSIG site of the input, in execution order (the unlock's sites, then the lock's).
    pub scriptcode_hex: Vec<String>,
    /// The site (an index into `scriptcode_hex`) each key's signature is checked at.
    pub sig_sites: Vec<usize>,
    /// The unlocking script, hex, with the tokens `<sigK>`, `<pubK>` and `<preimageN>`, each standing for the minimal
    /// push of its bytes.
    pub unlock_template: String,
}

/// The transaction-level signing fields and the inputs.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Signing {
    pub version: i32,
    pub locktime: u32,
    pub inputs: Vec<SignInput>,
}

/// A row: the corpus entry with its `signing` object.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Row {
    #[serde(flatten)]
    pub entry: Entry,
    pub signing: Signing,
}

/// Validate the signer tables with the verifier classifier's strict schema.
/// The runner and `rules_check --signer` share this pin/citation gate.
pub fn load_rules(
    root: &std::path::Path,
    engine: &str,
    pin: &str,
) -> Result<crate::rules::RuleSet, String> {
    let table = crate::rules::RuleSet::load(root, &format!("{engine}-signer"))?;
    if table.engine != format!("{engine}-signer") || table.pin != pin {
        return Err("signer classifier pin or engine mismatch".into());
    }
    if !table
        .classes
        .contains_key("sighash.scriptcode.in-unlock.lock-only")
        || (matches!(engine, "ts-sdk" | "bsv-rs")
            && !table
                .classes
                .contains_key("sighash.single.out-of-range.one"))
        || (engine == "bsv-rs" && !table.classes.contains_key("sighash.chronicle.bip143"))
        || table.rows.is_empty()
        || table.classes.values().any(|c| {
            !c.decided_by.contains("[SRC]")
                || !c.decided_by.contains("6504a3af")
                || !c.decided_by.contains(pin)
                || c.note.trim().is_empty()
                || c.ruling.trim().is_empty()
        })
        || table.rows.iter().any(|r| r.why.trim().is_empty())
    {
        return Err("signer classifier lacks citations, notes or reasons".into());
    }
    Ok(table)
}

/// A piece of an unlocking-script template.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Piece {
    /// Literal script bytes.
    Bytes(Vec<u8>),
    /// `<sigK>`: the signature of `privkeys[K]` (DER plus the hash type's low byte).
    Sig(usize),
    /// `<pubK>`: `pubkeys[K]`.
    Pub(usize),
    /// `<preimageN>`: the BIP143 preimage of site N under the input's hash type (an OP_PUSH_TX unlock pushes it).
    Preimage(usize),
}

/// The template's text from its pieces.
pub fn render(pieces: &[Piece]) -> String {
    pieces
        .iter()
        .map(|p| match p {
            Piece::Bytes(b) => hex::encode(b),
            Piece::Sig(k) => format!("<sig{k}>"),
            Piece::Pub(k) => format!("<pub{k}>"),
            Piece::Preimage(s) => format!("<preimage{s}>"),
        })
        .collect()
}

/// The pieces of a template's text.
pub fn parse(template: &str) -> Result<Vec<Piece>, String> {
    let mut out = Vec::new();
    let mut rest = template;
    while !rest.is_empty() {
        if let Some(body) = rest.strip_prefix('<') {
            let end = body
                .find('>')
                .ok_or_else(|| format!("unclosed token in {template}"))?;
            let tok = &body[..end];
            let num = |p: &str| -> Result<usize, String> {
                tok[p.len()..]
                    .parse()
                    .map_err(|e| format!("token <{tok}>: {e}"))
            };
            out.push(if tok.starts_with("sig") {
                Piece::Sig(num("sig")?)
            } else if tok.starts_with("pub") {
                Piece::Pub(num("pub")?)
            } else if tok.starts_with("preimage") {
                Piece::Preimage(num("preimage")?)
            } else {
                return Err(format!("unknown token <{tok}>"));
            });
            rest = &body[end + 1..];
        } else {
            let end = rest.find('<').unwrap_or(rest.len());
            out.push(Piece::Bytes(
                hex::decode(&rest[..end]).map_err(|e| format!("template hex: {e}"))?,
            ));
            rest = &rest[end..];
        }
    }
    Ok(out)
}

/// The opcodes of a script as (start, end) byte ranges, pushes with their data; a truncated push ends the script.
pub fn ops(script: &[u8]) -> Vec<(usize, usize, u8)> {
    let mut out = Vec::new();
    let mut i = 0;
    while i < script.len() {
        let op = script[i];
        let (hdr, len) = match op {
            0x01..=0x4b => (1, op as usize),
            0x4c => (2, script.get(i + 1).map_or(0, |&b| b as usize)),
            0x4d => (
                3,
                script
                    .get(i + 1..i + 3)
                    .map_or(0, |b| u16::from_le_bytes([b[0], b[1]]) as usize),
            ),
            0x4e => (
                5,
                script
                    .get(i + 1..i + 5)
                    .map_or(0, |b| u32::from_le_bytes([b[0], b[1], b[2], b[3]]) as usize),
            ),
            _ => (1, 0),
        };
        let end = (i + hdr + len).min(script.len());
        out.push((i, end, op));
        i = end;
    }
    out
}

/// One element of a template walked in execution order: a token (one push) or one opcode of the literal bytes.
enum Item<'a> {
    Token(&'a Piece),
    Op(&'a [u8], u8),
}

fn items(pieces: &[Piece]) -> Vec<Item<'_>> {
    let mut out = Vec::new();
    for p in pieces {
        match p {
            Piece::Bytes(b) => {
                for (s, e, op) in ops(b) {
                    out.push(Item::Op(&b[s..e], op));
                }
            }
            t => out.push(Item::Token(t)),
        }
    }
    out
}

fn is_checksig(op: u8) -> bool {
    matches!(
        op,
        OP_CHECKSIG | OP_CHECKSIGVERIFY | OP_CHECKMULTISIG | OP_CHECKMULTISIGVERIFY
    )
}

/// The scriptCode of every CHECKSIG site of an input, in execution order, by the reference's rule (the module's
/// header): the unlock's sites from the unlock's last separator to its end, the lock appended when `chronicle`; then
/// the lock's sites from the lock's last separator. The templates are straight-line (an `OP_IF` they carry is always
/// taken), so the walk is linear. A `<pubK>` token in a scriptCode is written as its push; a `<sigK>` or
/// `<preimageN>` token there is refused (a signature cannot cover itself).
pub fn scriptcodes(
    unlock: &[Piece],
    pubkeys: &[Vec<u8>],
    lock: &[u8],
    chronicle: bool,
) -> Result<Vec<Vec<u8>>, String> {
    let mut out = Vec::new();
    let its = items(unlock);
    let mut sep = 0;
    for (i, it) in its.iter().enumerate() {
        match it {
            Item::Op(_, OP_CODESEPARATOR) => sep = i + 1,
            Item::Op(_, op) if is_checksig(*op) => {
                let mut code = Vec::new();
                for x in &its[sep..] {
                    match x {
                        Item::Op(b, _) => code.extend_from_slice(b),
                        Item::Token(Piece::Pub(k)) => code.extend(pm(pubkeys
                            .get(*k)
                            .ok_or_else(|| format!("<pub{k}> without a key"))?)),
                        Item::Token(t) => {
                            return Err(format!(
                                "a scriptCode would cover the token {}",
                                render(&[(*t).clone()])
                            ))
                        }
                    }
                }
                if chronicle {
                    code.extend_from_slice(lock);
                }
                out.push(code);
            }
            _ => {}
        }
    }
    let mut lsep = 0;
    for (_, e, op) in ops(lock) {
        if op == OP_CODESEPARATOR {
            lsep = e;
        } else if is_checksig(op) {
            out.push(lock[lsep..].to_vec());
        }
    }
    Ok(out)
}

/// What the hand signer computed for one site.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct SiteDigest {
    pub site: usize,
    pub scriptcode_hex: String,
    pub digest_hex: String,
}

/// bsv-rs's dispatched digest (`compute_sighash_dispatched_for_signing`: BIP143 under FORKID without CHRONICLE, the
/// original digest otherwise) of `tx`'s input `input` over `scriptcode`, and the BIP143 preimage when that is the
/// digest's.
pub fn digest(
    tx: &RawTx,
    input: usize,
    scriptcode: &[u8],
    scope: u32,
    amount: u64,
) -> ([u8; 32], Option<Vec<u8>>) {
    let (inputs, outputs) = sighash_parts(tx);
    let params = SighashParams {
        version: tx.version,
        inputs: &inputs,
        outputs: &outputs,
        locktime: tx.lock_time,
        input_index: input,
        subscript: scriptcode,
        satoshis: amount,
        scope,
    };
    let bip143 = scope & SIGHASH_FORKID != 0 && scope & SIGHASH_CHRONICLE == 0;
    (
        compute_sighash_dispatched_for_signing(&params),
        bip143.then(|| build_sighash_preimage(&params)),
    )
}

/// Sign one input BY HAND over the row's scriptCodes (or over `override_code` at every site, the self-check's control
/// of a signer that hashes the locking script alone) and fill its template: the unlocking script and the digests.
pub fn sign_input(
    tx: &RawTx,
    amount: u64,
    si: &SignInput,
    override_code: Option<&[u8]>,
) -> Result<(Vec<u8>, Vec<SiteDigest>), String> {
    let codes: Vec<Vec<u8>> = si
        .scriptcode_hex
        .iter()
        .map(|h| hex::decode(h).map_err(|e| format!("scriptcode hex: {e}")))
        .collect::<Result<_, _>>()?;
    let codes: Vec<Vec<u8>> = match override_code {
        Some(c) => codes.iter().map(|_| c.to_vec()).collect(),
        None => codes,
    };
    let mut sites = Vec::new();
    let mut preimages = Vec::new();
    for (s, code) in codes.iter().enumerate() {
        let (d, pre) = digest(tx, si.index, code, si.sighash_type, amount);
        sites.push(SiteDigest {
            site: s,
            scriptcode_hex: hex::encode(code),
            digest_hex: hex::encode(d),
        });
        preimages.push(pre);
    }
    let mut sigs = Vec::new();
    for (k, kh) in si.privkeys.iter().enumerate() {
        let site = *si
            .sig_sites
            .get(k)
            .ok_or_else(|| format!("key {k} has no site"))?;
        let d: [u8; 32] = hex::decode(
            &sites
                .get(site)
                .ok_or_else(|| format!("site {site} out of range"))?
                .digest_hex,
        )
        .map_err(|e| e.to_string())?
        .try_into()
        .map_err(|_| "digest length".to_string())?;
        let sk = PrivateKey::from_bytes(&hex::decode(kh).map_err(|e| e.to_string())?)
            .map_err(|e| format!("key {k}: {e}"))?;
        let sig = sk.sign(&d).map_err(|e| format!("sign: {e}"))?;
        let mut der_sig = der(sig.r(), sig.s());
        der_sig.push((si.sighash_type & 0xff) as u8);
        sigs.push(der_sig);
    }
    let mut unlock = Vec::new();
    for p in parse(&si.unlock_template)? {
        match p {
            Piece::Bytes(b) => unlock.extend(b),
            Piece::Sig(k) => unlock.extend(pm(sigs.get(k).ok_or("<sigK> without a key")?)),
            Piece::Pub(k) => unlock.extend(pm(&hex::decode(
                si.pubkeys.get(k).ok_or("<pubK> without a key")?,
            )
            .map_err(|e| e.to_string())?)),
            Piece::Preimage(s) => unlock.extend(pm(preimages
                .get(s)
                .and_then(|p| p.as_ref())
                .ok_or("<preimageN> on a site without a BIP143 preimage")?)),
        }
    }
    Ok((unlock, sites))
}
