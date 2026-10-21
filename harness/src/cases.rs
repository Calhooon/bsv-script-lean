//! The corpus generators' one body (#138, lane dup-138, 2026-10-15): the pieces `seed_gen`, `flow_cases`, `arith_cases`,
//! `stack_cases`, `crypto_cases`, `bytes_cases`, `ecdsa_vectors` and `gen` each carried as a copy until the copy-paste
//! leg named them (docs/LINT.md §1a; the clone list of docs/records/20261014-215738-jscpd-baseline-stacked-138-s3.md).
//! Factored without a change of output: every corpus these generators write is byte-identical before and after (the
//! sums in docs/records/20261015-033629-jscpd-cut-138-s3.md).
//!
//! The shape every generator shares: a synthetic outpoint per entry (sha256 of the entry's id under the corpus's
//! name), a one-input spend of it to a 1-satoshi OP_1 output, bsv-rs's verdict on it, the entry with that verdict under
//! `BSV_RS_KEY`, the tallies, and the `.jsonl` plus its manifest written at the end.

use std::collections::BTreeMap;
use std::io::Write;

use bsv_rs::primitives::bsv::sighash::{
    compute_sighash_for_signing, SighashParams, TxInput, TxOutput,
};
use bsv_rs::primitives::hash::sha256;

use crate::corpus::{
    Entry, ExpectJson, ImplConfigJson, Manifest, ParamsJson, PrevoutJson, RefJson,
    DEFAULT_SPEND_HEIGHT,
};
use crate::engine::{run_tx, run_tx_words, EngineConfig, Mode, Prevout, Verdict};
use crate::gen::{push_min, OP_1};
use crate::txraw::{RawInput, RawOutput, RawTx};
use crate::{BSV_RS_KEY, BSV_RS_VERSION};

/// The value after `name` on the command line.
pub fn arg(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1).cloned())
}

/// The minimal push of `data` as a fresh vector (`gen::push_min` appends).
pub fn pm(data: &[u8]) -> Vec<u8> {
    let mut v = Vec::new();
    push_min(&mut v, data);
    v
}

/// The script-number encoding of a small integer (`bsv::serialize`).
#[allow(
    clippy::unwrap_used,
    reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
)]
pub fn num(n: i64) -> Vec<u8> {
    if n == 0 {
        return vec![];
    }
    let neg = n < 0;
    let mut m = n.unsigned_abs();
    let mut v = Vec::new();
    while m > 0 {
        v.push((m & 0xff) as u8);
        m >>= 8;
    }
    if v.last().unwrap() & 0x80 != 0 {
        v.push(if neg { 0x80 } else { 0 });
    } else if neg {
        *v.last_mut().unwrap() |= 0x80;
    }
    v
}

/// A synthetic, non-real outpoint per entry: the txid is the hash of the entry's own id under its corpus's name, so it
/// is unique, reproducible and cannot be a real transaction's.
pub fn synthetic_txid(corpus: &str, id: &str) -> [u8; 32] {
    let h = sha256(format!("bsv-script-lean/corpus/{corpus}/{id}").as_bytes());
    let mut out = [0u8; 32];
    out.copy_from_slice(&h[..32]);
    out
}

/// The spending transaction of a case: one input spending `txid:0` with `unlock`, one 1-satoshi OP_1 output,
/// sequence final, lock time 0.
pub fn spend_tx(txid: [u8; 32], version: i32, unlock: Vec<u8>) -> RawTx {
    RawTx {
        version,
        inputs: vec![RawInput {
            txid,
            vout: 0,
            script: unlock,
            sequence: 0xffff_ffff,
        }],
        outputs: vec![RawOutput {
            satoshis: 1,
            script: vec![OP_1],
        }],
        lock_time: 0,
    }
}

/// The one prevout `spend_tx` spends: `txid:0`, 1000 satoshis, locked by `lock`.
pub fn prevout_of(txid: [u8; 32], lock: &[u8]) -> Vec<Prevout> {
    vec![Prevout {
        txid,
        vout: 0,
        script: lock.to_vec(),
        satoshis: 1000,
    }]
}

/// The order n of secp256k1, big-endian hex.
pub const N_HEX: &str = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141";

/// The DER encoding of a signature (r, s), each a 32-byte big-endian scalar.
pub fn der(r: &[u8; 32], s: &[u8; 32]) -> Vec<u8> {
    fn int(x: &[u8; 32]) -> Vec<u8> {
        let mut b: Vec<u8> = x.iter().copied().skip_while(|&v| v == 0).collect();
        if b.is_empty() {
            b.push(0);
        }
        if b[0] & 0x80 != 0 {
            b.insert(0, 0);
        }
        let mut out = vec![0x02, b.len() as u8];
        out.extend(b);
        out
    }
    let body = [int(r), int(s)].concat();
    let mut out = vec![0x30, body.len() as u8];
    out.extend(body);
    out
}

/// n - s, big-endian (the high-S twin of a signature's s).
#[allow(
    clippy::unwrap_used,
    reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
)]
pub fn sub_from_n(s: &[u8; 32]) -> [u8; 32] {
    let n = hex::decode(N_HEX).unwrap();
    let mut out = [0u8; 32];
    let mut borrow = 0i32;
    for i in (0..32).rev() {
        let d = n[i] as i32 - s[i] as i32 - borrow;
        if d < 0 {
            out[i] = (d + 256) as u8;
            borrow = 1;
        } else {
            out[i] = d as u8;
            borrow = 0;
        }
    }
    out
}

/// bsv-rs's digest (`compute_sighash_for_signing`, BIP143 for every scope) of `tx`'s input `input` over `subscript`
/// with `amount` and `scope`.
pub fn crate_digest(
    tx: &RawTx,
    subscript: &[u8],
    scope: u32,
    input: usize,
    amount: u64,
) -> [u8; 32] {
    let (inputs, outputs) = sighash_parts(tx);
    compute_sighash_for_signing(&SighashParams {
        version: tx.version,
        inputs: &inputs,
        outputs: &outputs,
        locktime: tx.lock_time,
        input_index: input,
        subscript,
        satoshis: amount,
        scope,
    })
}

/// `tx`'s inputs and outputs as bsv-rs's sighash reads them.
pub fn sighash_parts(tx: &RawTx) -> (Vec<TxInput>, Vec<TxOutput>) {
    let inputs: Vec<TxInput> = tx
        .inputs
        .iter()
        .map(|i| TxInput {
            txid: i.txid,
            output_index: i.vout,
            script: i.script.clone(),
            sequence: i.sequence,
        })
        .collect();
    let outputs: Vec<TxOutput> = tx
        .outputs
        .iter()
        .map(|o| TxOutput {
            satoshis: o.satoshis,
            script: o.script.clone(),
        })
        .collect();
    (inputs, outputs)
}

/// A hand-written case: a lock, an unlock, the family and rule it exercises, and whether the model says bsv-rs must
/// accept it (a positive case, checked at generation under version 2).
pub struct Case {
    pub family: String,
    pub rule: &'static str,
    pub lock: Vec<u8>,
    pub unlock: Vec<u8>,
    pub note: String,
    pub positive: bool,
}

/// A `Case`.
pub fn c(
    family: &str,
    rule: &'static str,
    lock: Vec<u8>,
    unlock: Vec<u8>,
    note: &str,
    positive: bool,
) -> Case {
    Case {
        family: family.into(),
        rule,
        lock,
        unlock,
        note: note.into(),
        positive,
    }
}

/// The family of a case's twin: `<family>/v1` under version 1.
pub fn twin_family(family: &str, version: i32) -> String {
    if version == 1 {
        format!("{family}/v1")
    } else {
        family.to_string()
    }
}

type Hook = Box<dyn Fn(&std::panic::PanicHookInfo<'_>) + Sync + Send + 'static>;

/// The expected panics of a run silenced (the verdicts capture them), the previous hook kept to restore.
pub struct Quiet(Option<Hook>);

impl Quiet {
    pub fn new() -> Self {
        let prev = std::panic::take_hook();
        std::panic::set_hook(Box::new(|_| {}));
        Quiet(Some(prev))
    }
    pub fn restore(&mut self) {
        if let Some(h) = self.0.take() {
            std::panic::set_hook(h);
        }
    }
}

impl Default for Quiet {
    fn default() -> Self {
        Self::new()
    }
}

/// What an entry says besides its transaction and verdict.
pub struct Label {
    pub id: String,
    pub family: String,
    pub rule: String,
    pub spend_height: u32,
    /// the prevouts' heights in the entry (`PrevoutJson::from_prevout`'s when `None`)
    pub heights: Option<Vec<u32>>,
    pub reference: Option<RefJson>,
    pub note: String,
}

impl Label {
    /// A label at the default spend height, the prevouts' heights `from_prevout`'s, no reference.
    pub fn new(id: String, family: String, rule: &str, note: String) -> Self {
        Label {
            id,
            family,
            rule: rule.to_string(),
            spend_height: DEFAULT_SPEND_HEIGHT,
            heights: None,
            reference: None,
            note,
        }
    }
}

/// The manifest's own words.
pub struct Text<'a> {
    pub corpus: &'a str,
    pub file: &'a str,
    pub manifest: &'a str,
    pub generator: String,
    pub seed: String,
    pub generated: String,
    pub provenance: String,
}

/// A corpus as it is generated: its entries, the tallies and the engine's configuration.
pub struct Corpus {
    pub cfg: EngineConfig,
    pub entries: Vec<Entry>,
    pub families: BTreeMap<String, u64>,
    pub rules: BTreeMap<String, u64>,
    pub verdicts: BTreeMap<String, u64>,
    pub execs: u64,
}

impl Corpus {
    pub fn new(cfg: EngineConfig) -> Self {
        Corpus {
            cfg,
            entries: Vec::new(),
            families: BTreeMap::new(),
            rules: BTreeMap::new(),
            verdicts: BTreeMap::new(),
            execs: 0,
        }
    }

    /// The next entry's id, `<prefix>-<n>` with n five digits.
    pub fn next_id(&self, prefix: &str) -> String {
        format!("{prefix}-{:05}", self.entries.len() + 1)
    }

    /// bsv-rs's verdict on `tx` under the configuration's word (one execution counted).
    pub fn run(&mut self, tx: &RawTx, prevouts: &[Prevout]) -> (Verdict, Option<usize>) {
        self.execs += 1;
        run_tx(tx, prevouts, Mode::Native, &self.cfg)
    }

    /// bsv-rs's verdict on `tx` under the given word per input (one execution counted).
    pub fn run_words(
        &mut self,
        tx: &RawTx,
        prevouts: &[Prevout],
        words: &[Option<bsv_rs::script::ScriptFlags>],
    ) -> (Verdict, Option<usize>) {
        self.execs += 1;
        run_tx_words(tx, prevouts, Mode::Native, &self.cfg, words)
    }

    /// The entry of `tx` with bsv-rs's `judged` verdict, tallied and kept.
    #[allow(
        clippy::expect_used,
        reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
    )]
    pub fn record(
        &mut self,
        label: Label,
        tx: &RawTx,
        prevouts: &[Prevout],
        judged: &(Verdict, Option<usize>),
    ) {
        let (v, i) = judged;
        *self.families.entry(label.family.clone()).or_default() += 1;
        *self.rules.entry(label.rule.clone()).or_default() += 1;
        *self.verdicts.entry(v.kind().to_string()).or_default() += 1;
        let mut expect = BTreeMap::new();
        expect.insert(
            BSV_RS_KEY.to_string(),
            ExpectJson {
                verdict: v.kind().to_string(),
                code: None,
                reason: v.reason(),
                input: *i,
            },
        );
        let prevouts: Vec<PrevoutJson> = match &label.heights {
            None => prevouts.iter().map(PrevoutJson::from_prevout).collect(),
            Some(hs) => prevouts
                .iter()
                .zip(hs.iter())
                .map(|(p, h)| {
                    let mut pj = PrevoutJson::from_prevout(p);
                    pj.height = *h;
                    pj
                })
                .collect(),
        };
        let entry = Entry {
            id: label.id,
            family: label.family,
            rule: label.rule,
            tx: hex::encode(tx.encode()),
            prevouts,
            params: ParamsJson {
                spend_height: label.spend_height,
                era: ParamsJson::era_of(label.spend_height).into(),
                consensus: true,
                tx_version: tx.version,
            },
            flags: None,
            expect,
            reference: label.reference,
            note: Some(label.note),
            divergence: None,
        };
        entry.check().expect("well-formed");
        self.entries.push(entry);
    }

    /// Every case under version 2 and its version-1 twin, each spending its own synthetic outpoint under `corpus`'s
    /// name; a positive case bsv-rs rejects under version 2 stops the generator (the model disagrees).
    #[allow(
        clippy::panic,
        reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
    )]
    pub fn twins(&mut self, quiet: &mut Quiet, corpus: &str, cases: Vec<Case>) {
        for case in cases {
            for version in [2i32, 1] {
                let id = self.next_id(corpus);
                let txid = synthetic_txid(corpus, &id);
                let prevouts = prevout_of(txid, &case.lock);
                let tx = spend_tx(txid, version, case.unlock.clone());
                let judged = self.run(&tx, &prevouts);
                let v = &judged.0;
                if case.positive && version == 2 && !v.accepted() {
                    quiet.restore();
                    panic!(
                        "the model disagrees with bsv-rs on a positive case: {} ({}): {:?} {:?}",
                        case.family,
                        case.note,
                        v.kind(),
                        v.reason()
                    );
                }
                let note = if version == 1 {
                    format!("version-1 twin: {}", case.note)
                } else {
                    case.note.clone()
                };
                let label = Label::new(id, twin_family(&case.family, version), case.rule, note);
                self.record(label, &tx, &prevouts, &judged);
            }
        }
    }

    /// The entries that do not carry `-candidate/` in their family.
    pub fn comparable(&self) -> usize {
        self.entries
            .iter()
            .filter(|e| !e.family.contains("-candidate/"))
            .count()
    }

    /// Write the entries to `<out_dir>/<file>` (one JSON line each) and the manifest beside them; the path, the
    /// file's sha256 and the manifest returned.
    #[allow(
        clippy::expect_used,
        clippy::unwrap_used,
        reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
    )]
    pub fn write(&self, out_dir: &str, text: Text<'_>) -> (String, String, Manifest) {
        std::fs::create_dir_all(out_dir).expect("out dir");
        let path = format!("{out_dir}/{}", text.file);
        let mut bytes = Vec::new();
        for e in &self.entries {
            bytes.extend_from_slice(serde_json::to_string(e).unwrap().as_bytes());
            bytes.push(b'\n');
        }
        std::fs::File::create(&path)
            .unwrap()
            .write_all(&bytes)
            .unwrap();
        let sha = hex::encode(sha256(&bytes));
        let manifest = Manifest {
            corpus: text.corpus.into(),
            file: text.file.into(),
            generator: text.generator,
            seed: text.seed,
            count: self.entries.len() as u64,
            sha256: sha.clone(),
            families: self.families.clone(),
            rules: self.rules.clone(),
            verdicts: self.verdicts.clone(),
            implementations: vec![ImplConfigJson {
                name: "bsv-rs".into(),
                version: BSV_RS_VERSION.into(),
                config: self.cfg.to_json(),
            }],
            engine_executions: self.execs,
            generated: text.generated,
            provenance: text.provenance,
        };
        std::fs::write(
            format!("{out_dir}/{}", text.manifest),
            serde_json::to_string_pretty(&manifest).unwrap() + "\n",
        )
        .unwrap();
        (path, sha, manifest)
    }

    /// The generator's closing lines: the count, the comparable count, the path and sum, the verdicts.
    pub fn report(&self, name: &str, comparable: usize, path: &str, sha: &str) {
        println!(
            "{name}: {} entries ({comparable} comparable) → {path} (sha256 {sha})",
            self.entries.len()
        );
        println!("  verdicts {:?}", self.verdicts);
    }
}
