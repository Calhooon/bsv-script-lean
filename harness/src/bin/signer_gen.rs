//! signer_gen (#145 piece 1, lane sign-145a, 2026-10-16; S3): THE SIGNABLE CORPUS. Writes `corpus/signer/<family>.jsonl`
//! and `corpus/signer/manifest.json`: unsigned spends with their throwaway keys, the hash type, the sequence and lock
//! time, the scriptCode of every CHECKSIG site as the reference computes it, and the unlocking script as a template
//! (`harness/src/signer.rs`; the contract the signer adapters read is `corpus/signer/README.md`). Deterministic from
//! its seed: one splitmix64 stream per family under the family's salted seed (the discipline of
//! `tools/fuzz_compose.py`'s header and `tools/fuzz_campaign.sh`'s `salted`: S xor the leading 16 hex digits of
//! sha256("spec-signer-corpus family F")), so a family's rows never move when another family is added or re-weighted;
//! every seed is in the manifest. The keys are sha256 of a label and a draw of the stream: regtest throwaway keys,
//! never a real key; the outpoints are synthetic (sha256 of the row's id and input), so no row can be a real
//! transaction's.
//!
//! The families and their counts [D] (corpus/INDEX.md, the signer rows): `p2pkh`, `p2pk`, `multisig`,
//! `checksig-in-unlock-a`, `checksig-in-unlock-b` (#144's two shapes) and `version`, about 40 rows each: every hash
//! type (ALL, NONE, SINGLE, each with and without ANYONECANPAY, with FORKID; the CHRONICLE-bit twin of each where the
//! row says so), SINGLE with the input index past the outputs, one and several inputs, lock time and sequence words,
//! the eras, and the version-1 twins the node must refuse under SIG_PUSHONLY.
//!
//! With `--sign DIR --out FILE` the self-check's half: every row of DIR signed BY HAND over its own scriptCodes
//! (bsv-rs's dispatched digest and its signer, `signer::sign_input`) and written as a plain corpus entry whose `tx` is
//! the signed spend, for `eval/bsvs corpus` to judge (`tools/signer_selfcheck.py`); `--lock-only` signs every site over
//! the locking script alone instead (the SDKs' default scriptCode, #144), the control that the corpus tells the two
//! apart; `--digests FILE` writes every site's scriptCode and digest beside it.
//!
//! Run: cargo run --release --bin signer_gen -- [--out DIR] [--seed HEX] [--count N]
//!      cargo run --release --bin signer_gen -- --sign DIR --out FILE [--lock-only] [--digests FILE]

use std::collections::BTreeMap;
use std::io::Write;

use bsv_rs::primitives::ec::PrivateKey;
use bsv_rs::primitives::hash::{hash160, sha256};
use bsv_script_harness::cases::{arg, pm, synthetic_txid, N_HEX};
use bsv_script_harness::corpus::{Entry, ParamsJson, PrevoutJson, RefJson, DEFAULT_SPEND_HEIGHT};
use bsv_script_harness::gen::{Rng, OP_0, OP_1};
use bsv_script_harness::signer::{
    parse, render, scriptcodes, sign_input, Piece, Row, SignInput, Signing, OP_CHECKMULTISIG,
    OP_CHECKSIG, OP_CHECKSIGVERIFY, OP_CODESEPARATOR, SIGHASH_ALL, SIGHASH_ANYONECANPAY,
    SIGHASH_CHRONICLE, SIGHASH_FORKID, SIGHASH_NONE, SIGHASH_SINGLE,
};
use bsv_script_harness::txraw::{RawInput, RawOutput, RawTx};

const GENERATOR: &str =
    "bsv-script-harness signer_gen 0.1.0 (#145 piece 1, lane sign-145a; harness/src/signer.rs)";
const DEFAULT_SEED: u64 = 0x5167_0145_0000_0001;
const FAMILIES: [&str; 6] = [
    "p2pkh",
    "p2pk",
    "multisig",
    "checksig-in-unlock-a",
    "checksig-in-unlock-b",
    "version",
];
/// The mainnet heights of the three eras the rows are placed in (`docs/PARAMETERS.md` §3; the coins at the same
/// height as the spend): post-Chronicle the spec's default spend height, post-Genesis and pre-Genesis as #144's rows.
const H_CHRONICLE: u32 = DEFAULT_SPEND_HEIGHT;
const H_GENESIS: u32 = 900_000;
const H_PRE: u32 = 600_000;
const MODEL: &str = "signer_gen: the reference's rule at bitcoin-sv v1.2.3 6504a3af (interpreter.cpp:1471-1481, 2112-2124, 2321-2334), by construction";

/// The six base types with FORKID (BIP143), and their CHRONICLE-bit twins (the original digest).
const FORKID_TYPES: [u32; 6] = [
    SIGHASH_ALL | SIGHASH_FORKID,
    SIGHASH_NONE | SIGHASH_FORKID,
    SIGHASH_SINGLE | SIGHASH_FORKID,
    SIGHASH_ALL | SIGHASH_FORKID | SIGHASH_ANYONECANPAY,
    SIGHASH_NONE | SIGHASH_FORKID | SIGHASH_ANYONECANPAY,
    SIGHASH_SINGLE | SIGHASH_FORKID | SIGHASH_ANYONECANPAY,
];
const ALL_F: u32 = SIGHASH_ALL | SIGHASH_FORKID;
const SEQ_FINAL: u32 = 0xffff_ffff;
/// Sequence words that bind nothing in any context: final, final-but-one (lock time on), zero (a relative lock of
/// zero blocks), the BIP68 disable bit with a value, the time-type flag with zero units (`validation.cpp:268-300`).
const SEQS: [u32; 5] = [SEQ_FINAL, 0xffff_fffe, 0, 0x8000_0010, 0x0040_0000];

fn chron(t: u32) -> u32 {
    t | SIGHASH_CHRONICLE
}

fn type_name(t: u32) -> String {
    let base = match t & 0x1f {
        1 => "ALL",
        2 => "NONE",
        3 => "SINGLE",
        _ => "UNDEFINED",
    };
    let mut s = base.to_string();
    if t & SIGHASH_ANYONECANPAY != 0 {
        s += "|ANYONECANPAY";
    }
    if t & SIGHASH_FORKID != 0 {
        s += "|FORKID";
    }
    if t & SIGHASH_CHRONICLE != 0 {
        s += "|CHRONICLE";
    }
    s
}

#[derive(Clone)]
enum Tpl {
    P2pkh,
    P2pk,
    /// m of n, the signers' indices ascending (CHECKMULTISIG's order)
    Multi(usize, usize, Vec<usize>),
    A,
    B,
}

impl Tpl {
    fn name(&self) -> String {
        match self {
            Tpl::P2pkh => "p2pkh".into(),
            Tpl::P2pk => "p2pk".into(),
            Tpl::Multi(m, n, _) => format!("multisig-{m}-of-{n}"),
            Tpl::A => "checksig-in-unlock-a".into(),
            Tpl::B => "checksig-in-unlock-b".into(),
        }
    }
}

struct InSpec {
    tpl: Tpl,
    scope: u32,
    sequence: u32,
}

fn inp(tpl: Tpl, scope: u32) -> InSpec {
    InSpec {
        tpl,
        scope,
        sequence: SEQ_FINAL,
    }
}

/// A row before its draws.
struct Spec {
    variant: String,
    rule: &'static str,
    locktime: u32,
    inputs: Vec<InSpec>,
    outputs: usize,
    height: u32,
    /// the reference's verdict by construction, and the code when it refuses
    expect: &'static str,
    code: Option<&'static str>,
    note: String,
}

fn spec(variant: impl Into<String>, rule: &'static str, inputs: Vec<InSpec>, note: &str) -> Spec {
    Spec {
        variant: variant.into(),
        rule,
        locktime: 0,
        inputs,
        outputs: 1,
        height: H_CHRONICLE,
        expect: "valid",
        code: None,
        note: note.into(),
    }
}

/// One input after its draws.
struct DIn {
    tpl: Tpl,
    scope: u32,
    sequence: u32,
    txid: [u8; 32],
    vout: u32,
    amount: u64,
    lock: Vec<u8>,
    pieces: Vec<Piece>,
    privkeys: Vec<Vec<u8>>,
    pubkeys: Vec<Vec<u8>>,
    sig_sites: Vec<usize>,
}

/// A throwaway key from the stream: sha256 of a label and a draw, retried until it is a scalar.
fn key(rng: &mut Rng) -> (Vec<u8>, Vec<u8>) {
    loop {
        let h = sha256(format!("bsv-script-lean/corpus/signer/key/{:016x}", rng.next()).as_bytes());
        if let Ok(sk) = PrivateKey::from_bytes(&h) {
            return (h.to_vec(), sk.public_key().to_compressed().to_vec());
        }
    }
}

fn p2pkh_lock(pubkey: &[u8]) -> Vec<u8> {
    let mut l = vec![0x76, 0xa9];
    l.extend(pm(&hash160(pubkey)));
    l.extend([0x88, OP_CHECKSIG]);
    l
}

/// The positive script number's minimal encoding, from its big-endian magnitude.
fn scriptnum_be(be: &[u8]) -> Vec<u8> {
    let mut v: Vec<u8> = be.iter().rev().copied().collect();
    while v.last() == Some(&0) {
        v.pop();
    }
    if v.last().is_some_and(|b| b & 0x80 != 0) {
        v.push(0);
    }
    v
}

/// Reverse the top element of exactly n bytes: n-1 one-byte splits, then n-1 swap-cats.
fn reverse(n: usize) -> Vec<u8> {
    let mut v = [OP_1, 0x7f].repeat(n - 1);
    v.extend([0x7c, 0x7e].repeat(n - 1));
    v
}

/// The secp256k1 generator's x coordinate, big-endian.
const GX: [u8; 32] = [
    0x79, 0xbe, 0x66, 0x7e, 0xf9, 0xdc, 0xbb, 0xac, 0x55, 0xa0, 0x62, 0x95, 0xce, 0x87, 0x0b, 0x07,
    0x02, 0x9b, 0xfc, 0xdb, 0x2d, 0xce, 0x28, 0xd9, 0x59, 0xf2, 0x81, 0x5b, 0x16, 0xf8, 0x17, 0x98,
];

/// #144's shape B signer (lane xsig-144, `tools/xsig_witness.py` `preimage_signer`, ported): P -> DER(r = Gx,
/// s = (z + Gx) mod n) ++ the hash type byte, z = hash256(P) read big-endian: the k = 1, d = 1 signature the OP_PUSH_TX
/// pattern computes in script, valid exactly when P is the preimage the node hashes. Its constant pushes are minimal.
#[allow(
    clippy::unwrap_used,
    reason = "an offline corpus generator: N_HEX is a constant; a failure stops the generation with its message"
)]
fn preimage_signer(hashtype: u8) -> Vec<u8> {
    let n = hex::decode(N_HEX).unwrap();
    let mut r = vec![0x02, 0x20];
    r.extend(GX);
    let mut v = vec![0xaa];
    v.extend(reverse(32));
    v.extend(pm(&[0]));
    v.extend([0x7e, 0x81]);
    v.extend(pm(&scriptnum_be(&GX)));
    v.push(0x93);
    v.extend(pm(&scriptnum_be(&n)));
    v.push(0x97);
    v.extend([0x82, 0x7c]);
    v.extend(pm(&[33]));
    v.push(0x80);
    v.extend(reverse(33));
    v.push(0x78);
    v.extend(pm(&[33]));
    v.extend([0x7c, 0x94, 0x7f, 0x77]);
    v.extend([0x78, 0x7c, 0x7e]);
    v.extend(pm(&[0x02]));
    v.extend([0x7c, 0x7e]);
    v.extend(pm(&r));
    v.extend([0x7c, 0x7e]);
    v.push(0x7c);
    v.extend(pm(&[36]));
    v.extend([0x93, 0x7c, 0x7e]);
    v.extend(pm(&[0x30]));
    v.extend([0x7c, 0x7e]);
    v.extend(pm(&[hashtype]));
    v.push(0x7e);
    v
}

struct Gen {
    family: &'static str,
    rng: Rng,
    rows: Vec<Row>,
}

impl Gen {
    fn draw_in(&mut self, s: &InSpec, txid: [u8; 32]) -> DIn {
        let vout = self.rng.below(4) as u32;
        let amount = 100_000 + self.rng.below(4_900_000) as u64;
        let (lock, pieces, privkeys, pubkeys, sig_sites) = match &s.tpl {
            Tpl::P2pkh => {
                let (sk, pk) = key(&mut self.rng);
                (
                    p2pkh_lock(&pk),
                    vec![Piece::Sig(0), Piece::Pub(0)],
                    vec![sk],
                    vec![pk],
                    vec![0],
                )
            }
            Tpl::P2pk => {
                let (sk, pk) = key(&mut self.rng);
                let mut l = pm(&pk);
                l.push(OP_CHECKSIG);
                (l, vec![Piece::Sig(0)], vec![sk], vec![pk], vec![0])
            }
            Tpl::Multi(m, n, signers) => {
                let keys: Vec<_> = (0..*n).map(|_| key(&mut self.rng)).collect();
                let mut l = vec![OP_1 - 1 + *m as u8];
                for (_, pk) in &keys {
                    l.extend(pm(pk));
                }
                l.extend([OP_1 - 1 + *n as u8, OP_CHECKMULTISIG]);
                let mut pieces = vec![Piece::Bytes(vec![OP_0])];
                pieces.extend((0..*m).map(Piece::Sig));
                (
                    l,
                    pieces,
                    signers.iter().map(|&i| keys[i].0.clone()).collect(),
                    signers.iter().map(|&i| keys[i].1.clone()).collect(),
                    vec![0; *m],
                )
            }
            Tpl::A => {
                // go-sdk v1.7.2's chronicle_scriptsig_checksig_test.go:26-50 (#144's shape A): lock `<pubU> CHECKSIG`,
                // unlock `<sigU> <sig0> CODESEPARATOR <pub0> CHECKSIGVERIFY`; key 0 at the unlock's site, key 1 (U) at the lock's
                let (s0, p0) = key(&mut self.rng);
                let (su, pu) = key(&mut self.rng);
                let mut l = pm(&pu);
                l.push(OP_CHECKSIG);
                (
                    l,
                    vec![
                        Piece::Sig(1),
                        Piece::Sig(0),
                        Piece::Bytes(vec![OP_CODESEPARATOR]),
                        Piece::Pub(0),
                        Piece::Bytes(vec![OP_CHECKSIGVERIFY]),
                    ],
                    vec![s0, su],
                    vec![p0, pu],
                    vec![0, 1],
                )
            }
            Tpl::B => {
                // #144's shape B (the test's :91-105 tail): lock P2PKH(U); unlock `<sigU> <pubU> <P> OP_1 OP_IF <signer>
                // <G> CODESEPARATOR CHECKSIGVERIFY ENDIF`; site 0 the unlock's (no key: its preimage), site 1 the lock's
                let (su, pu) = key(&mut self.rng);
                let mut tail = vec![OP_1, 0x63];
                tail.extend(preimage_signer((s.scope & 0xff) as u8));
                let mut g = vec![0x02];
                g.extend(GX);
                tail.extend(pm(&g));
                tail.extend([OP_CODESEPARATOR, OP_CHECKSIGVERIFY, 0x68]);
                (
                    p2pkh_lock(&pu),
                    vec![
                        Piece::Sig(0),
                        Piece::Pub(0),
                        Piece::Preimage(0),
                        Piece::Bytes(tail),
                    ],
                    vec![su],
                    vec![pu],
                    vec![1],
                )
            }
        };
        DIn {
            tpl: s.tpl.clone(),
            scope: s.scope,
            sequence: s.sequence,
            txid,
            vout,
            amount,
            lock,
            pieces,
            privkeys,
            pubkeys,
            sig_sites,
        }
    }

    /// Draw a spec's keys, coins and outputs once and emit it under each of `versions` (a version-1 twin is the same
    /// spend, keys and coins, under version 1).
    #[allow(
        clippy::expect_used,
        reason = "an offline corpus generator: a malformed row is a generator bug; a failure stops the generation with its message"
    )]
    fn emit(&mut self, s: Spec, versions: &[(i32, &'static str, Option<&'static str>)]) {
        let base_id = format!("signer-{}-{:05}", self.family, self.rows.len() + 1);
        let ins: Vec<DIn> = s
            .inputs
            .iter()
            .enumerate()
            .map(|(i, x)| self.draw_in(x, synthetic_txid("signer", &format!("{base_id}/{i}"))))
            .collect();
        let total: u64 = ins.iter().map(|d| d.amount).sum();
        let fee = 2_000 * ins.len() as u64 + 1_000;
        let each = (total - fee) / s.outputs as u64;
        let outputs: Vec<RawOutput> = (0..s.outputs)
            .map(|k| {
                let (_, pk) = key(&mut self.rng);
                RawOutput {
                    satoshis: if k + 1 == s.outputs {
                        total - fee - each * (s.outputs as u64 - 1)
                    } else {
                        each
                    },
                    script: p2pkh_lock(&pk),
                }
            })
            .collect();
        let chronicle = s.height >= 943_816;
        for (vi, (version, expect, code)) in versions.iter().enumerate() {
            let id = if vi == 0 {
                base_id.clone()
            } else {
                format!("signer-{}-{:05}", self.family, self.rows.len() + 1)
            };
            let tx = RawTx {
                version: *version,
                inputs: ins
                    .iter()
                    .map(|d| RawInput {
                        txid: d.txid,
                        vout: d.vout,
                        script: Vec::new(),
                        sequence: d.sequence,
                    })
                    .collect(),
                outputs: outputs.clone(),
                lock_time: s.locktime,
            };
            let signing = Signing {
                version: *version,
                locktime: s.locktime,
                inputs: ins
                    .iter()
                    .enumerate()
                    .map(|(i, d)| SignInput {
                        index: i,
                        template: d.tpl.name(),
                        privkeys: d.privkeys.iter().map(hex::encode).collect(),
                        pubkeys: d.pubkeys.iter().map(hex::encode).collect(),
                        sighash_type: d.scope,
                        sequence: d.sequence,
                        scriptcode_hex: scriptcodes(&d.pieces, &d.pubkeys, &d.lock, chronicle)
                            .expect("scriptcodes")
                            .iter()
                            .map(hex::encode)
                            .collect(),
                        sig_sites: d.sig_sites.clone(),
                        unlock_template: render(&d.pieces),
                    })
                    .collect(),
            };
            let types: Vec<String> = ins
                .iter()
                .map(|d| format!("{} {}", d.tpl.name(), type_name(d.scope)))
                .collect();
            let mut note = format!(
                "{}; version {version}, lock time {}, inputs [{}], {} output(s), {}",
                s.note,
                s.locktime,
                types.join(", "),
                s.outputs,
                ParamsJson::era_of(s.height)
            );
            if let Some(c) = code {
                note += &format!(" (expect SCRIPT_ERR_{c})");
            }
            let rule = if *version == 1 && s.rule == "crypto.checksig.unlock" {
                "flags.sigpushonly"
            } else {
                s.rule
            };
            let entry = Entry {
                id,
                family: format!("signer/{}/{}", self.family, s.variant)
                    + if *version == 1 { "/v1" } else { "" },
                rule: rule.into(),
                tx: hex::encode(tx.encode()),
                prevouts: ins
                    .iter()
                    .map(|d| PrevoutJson {
                        txid: bsv_script_harness::txraw::txid_display_hex(&d.txid),
                        vout: d.vout,
                        script: hex::encode(&d.lock),
                        satoshis: d.amount,
                        height: s.height,
                    })
                    .collect(),
                params: ParamsJson {
                    spend_height: s.height,
                    era: ParamsJson::era_of(s.height).into(),
                    consensus: true,
                    tx_version: *version,
                },
                flags: None,
                expect: BTreeMap::new(),
                reference: Some(RefJson {
                    model: MODEL.into(),
                    expect: (*expect).into(),
                }),
                note: Some(note),
                divergence: None,
            };
            entry.check().expect("well-formed");
            self.rows.push(Row { entry, signing });
        }
    }

    fn one(&mut self, s: Spec) {
        let (e, c) = (s.expect, s.code);
        self.emit(s, &[(2, e, c)]);
    }

    /// The spend under version 2 and its version-1 twin; the twin of an in-unlock CHECKSIG is refused under
    /// SIG_PUSHONLY (`interpreter.cpp:2321-2334`: post-Chronicle a version-1 spend is non-malleable), every other
    /// twin is valid (its pushes minimal, its signatures low-S, its stack clean, its dummy empty).
    fn twin(&mut self, s: Spec) {
        let v1 = match s.tpl_in_unlock() {
            true => ("invalid", Some("SIG_PUSHONLY")),
            false => ("valid", None),
        };
        let (e, c) = (s.expect, s.code);
        self.emit(s, &[(2, e, c), (1, v1.0, v1.1)]);
    }

    fn pick<T: Copy>(&mut self, xs: &[T]) -> T {
        xs[self.rng.below(xs.len())]
    }

    fn any_type(&mut self) -> u32 {
        let t = self.pick(&FORKID_TYPES);
        if self.rng.below(3) == 0 {
            chron(t)
        } else {
            t
        }
    }
}

impl Spec {
    fn tpl_in_unlock(&self) -> bool {
        self.inputs.iter().any(|i| matches!(i.tpl, Tpl::A | Tpl::B))
    }
    fn at(mut self, h: u32) -> Self {
        self.height = h;
        self
    }
    fn lt(mut self, l: u32) -> Self {
        self.locktime = l;
        self
    }
    fn outs(mut self, n: usize) -> Self {
        self.outputs = n;
        self
    }
    fn refused(mut self, code: &'static str) -> Self {
        self.expect = "invalid";
        self.code = Some(code);
        self
    }
}

fn seq(mut i: InSpec, s: u32) -> InSpec {
    i.sequence = s;
    i
}

/// The lock time and sequence rows of a one-template family (`tx.locktime`, `tx.sequence`): every one final at any
/// height past 100 but the last, NON-FINAL below height 499,999,999 (`IsFinalTx`, `validation.cpp:227-247`).
fn timing_rows(g: &mut Gen, mk: &dyn Fn() -> Tpl) -> Vec<Spec> {
    let t = g.any_type();
    vec![
        spec("locktime/height-past", "tx.locktime", vec![seq(inp(mk(), t), 0xffff_fffe)], "lock time a past height (100), sequence final-but-one").lt(100),
        spec("locktime/time-past", "tx.locktime", vec![seq(inp(mk(), ALL_F), 0xffff_fffe)], "lock time a past time (500,000,001), sequence final-but-one").lt(500_000_001),
        spec("locktime/future-seq-final", "tx.locktime", vec![inp(mk(), ALL_F)], "lock time a far height (499,999,999), every sequence final: final").lt(499_999_999),
        spec("sequence/zero", "tx.sequence", vec![seq(inp(mk(), ALL_F), 0)], "sequence 0 (a relative lock of zero blocks)"),
        spec("sequence/disable-bit", "tx.sequence", vec![seq(inp(mk(), SIGHASH_NONE | SIGHASH_FORKID), 0x8000_0010)], "sequence 0x80000010 (the BIP68 disable bit)"),
        spec("sequence/time-type", "tx.sequence", vec![seq(inp(mk(), ALL_F), 0x0040_0000)], "sequence 0x00400000 (the time-type flag, zero units)"),
        spec("sequence/mixed", "tx.sequence", vec![seq(inp(mk(), ALL_F), 0xffff_fffe), seq(inp(mk(), SIGHASH_SINGLE | SIGHASH_FORKID), 0)], "two inputs, sequences final-but-one and 0").outs(2),
        spec("locktime/non-final", "tx.locktime", vec![seq(inp(mk(), ALL_F), 0xffff_fffe)], "lock time a far height (499,999,999), sequence final-but-one: the script is valid, the transaction NON-FINAL below that height (IsFinalTx, validation.cpp:227-247; a node refuses it as non-final, not for its signature)").lt(499_999_999),
    ]
}

fn random_inputs(g: &mut Gen, mk: &dyn Fn(&mut Gen) -> Tpl, max: usize) -> (Vec<InSpec>, usize) {
    let n = 1 + g.rng.below(max);
    let ins = (0..n)
        .map(|_| {
            let t = g.any_type();
            let s = g.pick(&SEQS);
            seq(inp(mk(g), t), s)
        })
        .collect();
    (ins, 1 + g.rng.below(3))
}

fn random_multi(g: &mut Gen) -> Tpl {
    match g.rng.below(3) {
        0 => Tpl::Multi(1, 1, vec![0]),
        1 => {
            let skip = g.rng.below(3);
            Tpl::Multi(2, 3, (0..3).filter(|&i| i != skip).collect())
        }
        _ => Tpl::Multi(3, 3, vec![0, 1, 2]),
    }
}

/// The rows every one-template family shares: each type, its CHRONICLE twin, SINGLE past the outputs, several inputs.
fn type_rows(mk: &dyn Fn() -> Tpl, rule_b: &'static str, rule_o: &'static str) -> Vec<Spec> {
    let mut v = Vec::new();
    for t in FORKID_TYPES {
        v.push(spec(
            format!("type/{}", type_name(t)),
            rule_b,
            vec![inp(mk(), t)],
            "one input, the BIP143 digest",
        ));
    }
    for t in FORKID_TYPES {
        v.push(spec(
            format!("type/{}", type_name(chron(t))),
            rule_o,
            vec![inp(mk(), chron(t))],
            "one input, the CHRONICLE bit: the original digest (interpreter.cpp:2118-2124)",
        ));
    }
    for t in [
        SIGHASH_SINGLE | SIGHASH_FORKID,
        chron(SIGHASH_SINGLE | SIGHASH_FORKID | SIGHASH_ANYONECANPAY),
    ] {
        let rule = if t & SIGHASH_CHRONICLE != 0 {
            rule_o
        } else {
            rule_b
        };
        v.push(spec(format!("single-past-outputs/{}", type_name(t)), rule, vec![inp(mk(), ALL_F), inp(mk(), t)],
            "input 1 signs SINGLE with one output: BIP143 hashes a zero hashOutputs (interpreter.cpp:2054-2063), the original digest is the constant one (2096-2101)"));
    }
    v
}

fn family_rows(g: &mut Gen, target: usize) {
    match g.family {
        "p2pkh" | "p2pk" => {
            let p2pkh = g.family == "p2pkh";
            let mk = move || if p2pkh { Tpl::P2pkh } else { Tpl::P2pk };
            for s in type_rows(&mk, "sighash.bip143", "sighash.original") {
                g.one(s);
            }
            if p2pkh {
                g.one(
                    spec(
                        "single-past-outputs/SINGLE",
                        "sighash.original",
                        vec![inp(mk(), ALL_F), inp(mk(), SIGHASH_SINGLE)],
                        "input 1 signs SINGLE (0x03) with one output: the original digest is constant one; the derived flag word requires FORKID (interpreter.cpp:2096-2100, 305-306)",
                    )
                    .refused("MUST_USE_FORKID"),
                );
                for t in [
                    SIGHASH_SINGLE | SIGHASH_FORKID | SIGHASH_ANYONECANPAY,
                    chron(SIGHASH_SINGLE | SIGHASH_FORKID),
                ] {
                    let rule = if t & SIGHASH_CHRONICLE != 0 {
                        "sighash.original"
                    } else {
                        "sighash.bip143"
                    };
                    g.one(spec(
                        format!("single-past-outputs/{}", type_name(t)),
                        rule,
                        vec![inp(mk(), ALL_F), inp(mk(), t)],
                        "input 1 signs SINGLE with one output",
                    ));
                }
            }
            g.one(
                spec(
                    "inputs/2-all",
                    "sighash.bip143",
                    vec![inp(mk(), ALL_F), inp(mk(), ALL_F)],
                    "two inputs, ALL each",
                )
                .outs(2),
            );
            let ts: Vec<u32> = (0..3).map(|_| g.any_type()).collect();
            g.one(
                spec(
                    "inputs/3-mixed",
                    "sighash.dispatch",
                    ts.iter().map(|&t| inp(mk(), t)).collect(),
                    "three inputs, mixed types",
                )
                .outs(3),
            );
            if p2pkh {
                let ts: Vec<u32> = (0..5).map(|_| g.any_type()).collect();
                g.one(
                    spec(
                        "inputs/5-mixed",
                        "sighash.dispatch",
                        ts.iter().map(|&t| inp(mk(), t)).collect(),
                        "five inputs, mixed types",
                    )
                    .outs(2),
                );
                let acp = SIGHASH_ANYONECANPAY;
                g.one(
                    spec(
                        "inputs/3-anyonecanpay",
                        "sighash.bip143",
                        vec![
                            inp(mk(), ALL_F | acp),
                            inp(mk(), SIGHASH_NONE | SIGHASH_FORKID | acp),
                            inp(mk(), SIGHASH_SINGLE | SIGHASH_FORKID | acp),
                        ],
                        "three inputs, each ANYONECANPAY",
                    )
                    .outs(3),
                );
            }
            let timing = timing_rows(g, &mk);
            for s in timing.into_iter().take(if p2pkh { 8 } else { 3 }) {
                g.one(s);
            }
            g.one(
                spec(
                    "era/post-genesis",
                    "eras.spend.genesis",
                    vec![inp(mk(), ALL_F)],
                    "after Genesis, before Chronicle",
                )
                .at(H_GENESIS),
            );
            g.one(
                spec(
                    "era/pre-genesis",
                    "eras.spend.genesis",
                    vec![inp(mk(), ALL_F)],
                    "before Genesis, FORKID enabled",
                )
                .at(H_PRE),
            );
            if p2pkh {
                g.one(spec("era/post-genesis-chronicle-bit", "eras.spend.chronicle", vec![inp(mk(), chron(ALL_F))], "the CHRONICLE bit before Chronicle: refused under STRICTENC (interpreter.cpp:296-303)").at(H_GENESIS).refused("ILLEGAL_CHRONICLE"));
                g.one(spec("era/pre-genesis-chronicle-bit", "eras.spend.chronicle", vec![inp(mk(), chron(ALL_F))], "the CHRONICLE bit before Genesis: refused under STRICTENC (FORKID sets it, interpreter.cpp:2316-2319)").at(H_PRE).refused("ILLEGAL_CHRONICLE"));
            }
            while g.rows.len() < target {
                let (ins, outs) = random_inputs(g, &|_| mk(), 3);
                g.one(
                    spec(
                        "random",
                        "sighash.dispatch",
                        ins,
                        "a draw: inputs, types, sequences and outputs from the stream",
                    )
                    .outs(outs),
                );
            }
        }
        "multisig" => {
            let m = |a, b, s: &[usize]| Tpl::Multi(a, b, s.to_vec());
            for (t, note) in [
                (m(1, 1, &[0]), "1-of-1"),
                (m(2, 3, &[0, 1]), "2-of-3, keys 0 and 1"),
                (m(2, 3, &[0, 2]), "2-of-3, keys 0 and 2"),
                (m(2, 3, &[1, 2]), "2-of-3, keys 1 and 2"),
                (m(3, 3, &[0, 1, 2]), "3-of-3"),
            ] {
                g.one(spec(
                    format!("{}/ALL|FORKID", t.name()),
                    "crypto.checkmultisig",
                    vec![inp(t, ALL_F)],
                    &format!("{note}, the dummy OP_0"),
                ));
            }
            for &t in &FORKID_TYPES[1..] {
                let tpl = random_multi(g);
                g.one(spec(
                    format!("{}/{}", tpl.name(), type_name(t)),
                    "crypto.checkmultisig",
                    vec![inp(tpl, t)],
                    "the BIP143 digest, the dummy OP_0",
                ));
            }
            for t in FORKID_TYPES {
                g.one(spec(
                    format!("multisig-3-of-3/{}", type_name(chron(t))),
                    "sighash.original",
                    vec![inp(m(3, 3, &[0, 1, 2]), chron(t))],
                    "3-of-3, the CHRONICLE bit: the original digest",
                ));
            }
            g.one(spec(
                "single-past-outputs",
                "sighash.bip143",
                vec![
                    inp(m(1, 1, &[0]), ALL_F),
                    inp(m(2, 3, &[0, 2]), SIGHASH_SINGLE | SIGHASH_FORKID),
                ],
                "input 1 signs SINGLE with one output",
            ));
            g.one(
                spec(
                    "inputs/2",
                    "crypto.checkmultisig",
                    vec![
                        inp(m(2, 3, &[0, 1]), ALL_F),
                        inp(m(3, 3, &[0, 1, 2]), SIGHASH_NONE | SIGHASH_FORKID),
                    ],
                    "two multisig inputs",
                )
                .outs(2),
            );
            g.one(
                spec(
                    "era/post-genesis",
                    "eras.spend.genesis",
                    vec![inp(m(2, 3, &[1, 2]), ALL_F)],
                    "after Genesis, before Chronicle",
                )
                .at(H_GENESIS),
            );
            g.one(
                spec(
                    "era/pre-genesis",
                    "eras.spend.genesis",
                    vec![inp(m(2, 3, &[0, 1]), ALL_F)],
                    "before Genesis",
                )
                .at(H_PRE),
            );
            while g.rows.len() < target {
                let (ins, outs) = random_inputs(g, &random_multi, 2);
                g.one(
                    spec(
                        "random",
                        "crypto.checkmultisig",
                        ins,
                        "a draw: inputs, types, sequences and outputs from the stream",
                    )
                    .outs(outs),
                );
            }
        }
        "checksig-in-unlock-a" | "checksig-in-unlock-b" => {
            let a = g.family == "checksig-in-unlock-a";
            let mk = move || if a { Tpl::A } else { Tpl::B };
            let r = "crypto.checksig.unlock";
            let note = if a {
                "#144 shape A: CHECKSIGVERIFY in the unlock after a separator, over a P2PK lock"
            } else {
                "#144 shape B: the in-script k = 1 OP_PUSH_TX signer in the unlock, over a P2PKH lock"
            };
            for t in FORKID_TYPES {
                g.twin(spec(
                    format!("type/{}", type_name(t)),
                    r,
                    vec![inp(mk(), t)],
                    note,
                ));
            }
            if a {
                // shape B's preimage token is BIP143's alone, so the CHRONICLE-bit rows are shape A's
                for t in FORKID_TYPES {
                    g.twin(spec(
                        format!("type/{}", type_name(chron(t))),
                        r,
                        vec![inp(mk(), chron(t))],
                        note,
                    ));
                }
            }
            g.twin(spec(
                "single-past-outputs",
                r,
                vec![inp(mk(), ALL_F), inp(mk(), SIGHASH_SINGLE | SIGHASH_FORKID)],
                note,
            ));
            g.twin(
                spec(
                    "inputs/2",
                    r,
                    vec![
                        inp(mk(), ALL_F),
                        inp(mk(), SIGHASH_NONE | SIGHASH_FORKID | SIGHASH_ANYONECANPAY),
                    ],
                    note,
                )
                .outs(2),
            );
            if a {
                g.one(spec("era/pre-genesis", r, vec![inp(mk(), ALL_F)], "#144 shape A before Genesis: no push-only rule, no SCRIPT_CHRONICLE, so the scriptCode is the unlock from its separator alone").at(H_PRE));
            }
            g.one(spec("era/post-genesis", "flags.sigpushonly", vec![inp(mk(), ALL_F)], "after Genesis, before Chronicle: the non-push unlock refused before any signature is read (interpreter.cpp:2321-2334)").at(H_GENESIS).refused("SIG_PUSHONLY"));
            if !a {
                g.twin(
                    spec(
                        "locktime/height-past",
                        r,
                        vec![seq(inp(mk(), ALL_F), 0xffff_fffe)],
                        note,
                    )
                    .lt(100),
                );
                g.twin(spec(
                    "sequence/zero",
                    r,
                    vec![seq(
                        inp(mk(), SIGHASH_SINGLE | SIGHASH_FORKID | SIGHASH_ANYONECANPAY),
                        0,
                    )],
                    note,
                ));
            }
            while g.rows.len() < target {
                let n = 1 + g.rng.below(2);
                let ins = (0..n)
                    .map(|_| {
                        let t = if a {
                            g.any_type()
                        } else {
                            g.pick(&FORKID_TYPES)
                        };
                        let s = g.pick(&SEQS);
                        seq(inp(mk(), t), s)
                    })
                    .collect();
                let outs = 1 + g.rng.below(3);
                g.twin(spec("random", r, ins, note).outs(outs));
            }
        }
        _ => {
            // version: p2pkh and p2pk under version 2 and version 1 (#144's shapes carry their own twins)
            let rule = "flags.version-gate";
            let tw = "the version-1 twin must be valid: its pushes minimal, signatures low-S, stack clean, dummy empty (interpreter.cpp:2321-2334 binds only a non-push unlock)";
            for t in FORKID_TYPES {
                g.twin(spec(
                    format!("p2pkh/{}", type_name(t)),
                    rule,
                    vec![inp(Tpl::P2pkh, t)],
                    tw,
                ));
            }
            for t in [
                ALL_F,
                SIGHASH_NONE | SIGHASH_FORKID,
                SIGHASH_SINGLE | SIGHASH_FORKID | SIGHASH_ANYONECANPAY,
            ] {
                g.twin(spec(
                    format!("p2pk/{}", type_name(t)),
                    rule,
                    vec![inp(Tpl::P2pk, t)],
                    tw,
                ));
            }
            for t in [
                ALL_F,
                SIGHASH_NONE | SIGHASH_FORKID | SIGHASH_ANYONECANPAY,
                SIGHASH_SINGLE | SIGHASH_FORKID,
            ] {
                g.twin(spec(
                    format!("p2pk/{}", type_name(t)),
                    rule,
                    vec![inp(Tpl::P2pk, t)],
                    tw,
                ));
            }
            for t in [
                chron(ALL_F),
                chron(SIGHASH_NONE | SIGHASH_FORKID | SIGHASH_ANYONECANPAY),
            ] {
                g.twin(spec(
                    format!("p2pkh/{}", type_name(t)),
                    rule,
                    vec![inp(Tpl::P2pkh, t)],
                    tw,
                ));
            }
            g.twin(
                spec(
                    "mixed-templates",
                    rule,
                    vec![
                        inp(Tpl::P2pkh, ALL_F),
                        inp(Tpl::P2pk, SIGHASH_NONE | SIGHASH_FORKID),
                        inp(Tpl::P2pkh, SIGHASH_SINGLE | SIGHASH_FORKID),
                    ],
                    tw,
                )
                .outs(3),
            );
            while g.rows.len() < target {
                let (ins, outs) = random_inputs(
                    g,
                    &|g: &mut Gen| match g.rng.below(2) {
                        0 => Tpl::P2pkh,
                        _ => Tpl::P2pk,
                    },
                    3,
                );
                g.twin(spec("random", rule, ins, tw).outs(outs));
            }
        }
    }
}

fn salted(seed: u64, family: &str) -> u64 {
    let h = sha256(format!("spec-signer-corpus family {family}").as_bytes());
    let mut b = [0u8; 8];
    b.copy_from_slice(&h[..8]);
    seed ^ u64::from_be_bytes(b)
}

#[allow(
    clippy::expect_used,
    clippy::unwrap_used,
    reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
)]
fn generate(out_dir: &str, seed: u64, count: usize) {
    std::fs::create_dir_all(out_dir).expect("out dir");
    let mut files = Vec::new();
    for family in FAMILIES {
        let fseed = salted(seed, family);
        let mut g = Gen {
            family,
            rng: Rng(fseed),
            rows: Vec::new(),
        };
        family_rows(&mut g, count);
        let mut bytes = Vec::new();
        let mut rules: BTreeMap<String, u64> = BTreeMap::new();
        let mut expect: BTreeMap<String, u64> = BTreeMap::new();
        let mut templates: BTreeMap<String, u64> = BTreeMap::new();
        let mut types: BTreeMap<String, u64> = BTreeMap::new();
        for r in &g.rows {
            bytes.extend(serde_json::to_string(r).unwrap().as_bytes());
            bytes.push(b'\n');
            *rules.entry(r.entry.rule.clone()).or_default() += 1;
            *expect
                .entry(r.entry.reference.as_ref().unwrap().expect.clone())
                .or_default() += 1;
            for i in &r.signing.inputs {
                *templates.entry(i.template.clone()).or_default() += 1;
                *types.entry(type_name(i.sighash_type)).or_default() += 1;
            }
        }
        let file = format!("{family}.jsonl");
        std::fs::File::create(format!("{out_dir}/{file}"))
            .unwrap()
            .write_all(&bytes)
            .unwrap();
        let sha = hex::encode(sha256(&bytes));
        println!(
            "signer_gen: {family:<22} {:>3} rows  seed 0x{fseed:016X}  sha256 {sha}  expect {expect:?}",
            g.rows.len()
        );
        files.push(serde_json::json!({
            "family": family, "file": file, "seed": format!("0x{fseed:016X}"), "count": g.rows.len(), "sha256": sha,
            "rules": rules, "expect": expect, "templates": templates, "sighash_types": types,
        }));
    }
    let manifest = serde_json::json!({
        "corpus": "signer",
        "generator": GENERATOR,
        "seed": format!("0x{seed:016X}"),
        "salt": "each family's seed is the corpus seed xor the leading 16 hex digits of sha256(\"spec-signer-corpus family <F>\")",
        "count_per_family": count,
        "format": "corpus/signer/README.md",
        "generated": std::env::var("SOURCE_DATE").unwrap_or_else(|_| "2026-10-16".into()),
        "provenance": "docs/PROVENANCE.md §1a (bitcoin-sv v1.2.3 6504a3af, bsv-rs 0.5.0); throwaway keys sha256 of a label and a draw of the family's stream; synthetic outpoints sha256 of the row id and input; no transaction of any private program",
        "files": files,
    });
    std::fs::write(
        format!("{out_dir}/manifest.json"),
        serde_json::to_string_pretty(&manifest).unwrap() + "\n",
    )
    .unwrap();
}

/// The self-check's half: every row signed by hand and written as a plain corpus entry.
#[allow(
    clippy::expect_used,
    clippy::unwrap_used,
    reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
)]
fn sign_all(dir: &str, out: &str, lock_only: bool, digests: Option<String>) {
    let manifest: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(format!("{dir}/manifest.json")).expect("manifest"),
    )
    .expect("manifest json");
    let mut lines = Vec::new();
    let mut dlines = Vec::new();
    for f in manifest["files"].as_array().expect("files") {
        let path = format!("{dir}/{}", f["file"].as_str().expect("file"));
        for line in std::fs::read_to_string(&path).expect("row file").lines() {
            let row: Row = serde_json::from_str(line).expect("row");
            let mut tx = RawTx::decode(&hex::decode(&row.entry.tx).unwrap()).expect("tx");
            assert!(
                tx.inputs.iter().all(|i| i.script.is_empty()),
                "{}: the row's tx must be unsigned",
                row.entry.id
            );
            let unsigned = tx.clone();
            let mut dins = Vec::new();
            for si in &row.signing.inputs {
                let pv = &row.entry.prevouts[si.index];
                let lock = hex::decode(&pv.script).unwrap();
                parse(&si.unlock_template).expect("template");
                let (unlock, sites) = sign_input(
                    &unsigned,
                    pv.satoshis,
                    si,
                    lock_only.then_some(lock.as_slice()),
                )
                .expect("sign");
                tx.inputs[si.index].script = unlock;
                dins.push(serde_json::json!({"index": si.index, "sites": sites}));
            }
            let mut e: Entry = row.entry.clone();
            e.tx = hex::encode(tx.encode());
            e.check().expect("well-formed");
            lines.push(serde_json::to_string(&e).unwrap());
            dlines.push(serde_json::json!({"id": e.id, "inputs": dins}).to_string());
        }
    }
    std::fs::write(out, lines.join("\n") + "\n").expect("out");
    if let Some(d) = digests {
        std::fs::write(d, dlines.join("\n") + "\n").expect("digests");
    }
    println!(
        "signer_gen --sign: {} rows signed by hand over {} → {out}",
        lines.len(),
        if lock_only {
            "the locking script alone (the control)"
        } else {
            "each row's scriptcode_hex"
        }
    );
}

#[allow(
    clippy::expect_used,
    reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
)]
fn main() {
    let args: Vec<String> = std::env::args().collect();
    if let Some(dir) = arg(&args, "--sign") {
        let out = arg(&args, "--out").expect("--sign needs --out FILE");
        sign_all(
            &dir,
            &out,
            args.iter().any(|a| a == "--lock-only"),
            arg(&args, "--digests"),
        );
        return;
    }
    let out_dir = arg(&args, "--out").unwrap_or_else(|| "../corpus/signer".into());
    let seed: u64 = arg(&args, "--seed")
        .map(|s| u64::from_str_radix(s.trim_start_matches("0x"), 16).expect("--seed is hex"))
        .unwrap_or(DEFAULT_SEED);
    let count: usize = arg(&args, "--count")
        .map(|s| s.parse().expect("--count"))
        .unwrap_or(40);
    generate(&out_dir, seed, count);
}
