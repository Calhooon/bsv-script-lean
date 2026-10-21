//! bytes_cases (#18): every byte 0x00–0xff as an opcode, through the pinned bsv-rs
//! (0.4.4 since 2026-10-12, 0.3.33 from 2026-10-07, bsv-rs#41 (0.3.30 from 2026-09-27, 0.3.28 from 2026-09-24, 0.3.27 on 2026-09-23)) under the node's standard word, under both version
//! branches, for `lean/Test/BytesCheck.lean`. Each case: the unlock pushes six
//! small numbers (`1 2 3 4 5 6`, bottom first, so every arity is served), the
//! lock is the byte (a push opcode with the data it needs: `b` bytes of `0x01`
//! for `0x01`–`0x4b`, one byte for the PUSHDATAs). The verdict is whatever the
//! byte makes of that stack; bsv-rs's is recorded, the spec's must agree. The
//! families `bytes/<class>/<byte>` name what bsv-rs 0.3.24 got wrong (recorded
//! then as `bytes-candidate/`, never counted: `0xba`–`0xff` as NOPs, the version
//! opcodes and `OP_2MUL`/`OP_2DIV` disabled, `0xb3`–`0xb7` as NOPs) and the bytes
//! that hang on the relay word's policy flag (`bytes-policy/` then); every one is
//! comparable since 0.3.27 (bsv-rs#12; the standard word carries the flag).
//! Run: cargo run --release --bin bytes_cases -- [--out DIR]

use bsv_script_harness::cases::{
    self, arg, prevout_of, spend_tx, synthetic_txid, Corpus, Label, Quiet, Text,
};
use bsv_script_harness::engine::EngineConfig;

/// The classes bsv-rs 0.3.24 diverged on, by byte (the citations in BytesCheck.lean); comparable
/// since 0.3.27, the family keeps the class name.
fn candidate(b: u8) -> Option<&'static str> {
    match b {
        0xba..=0xff => Some("undefined-opcode-as-nop"),
        0x62 | 0x65 | 0x66 => Some("ver-disabled"),
        0x8d | 0x8e => Some("2mul-2div-disabled"),
        0xb3..=0xb7 => Some("expansion-as-nop"),
        _ => None,
    }
}

/// The bytes whose verdict hangs on a POLICY flag of the relay word (`SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_NOPS`,
/// `policy.h:209–223`): the reference's mempool rejects them, its block validation treats them as NOPs;
/// bsv-rs 0.3.24 had no such flag (recorded under `bytes-policy/`, never counted); under the standard word
/// (0.3.26+) it carries the flag and the family is comparable.
fn policy(b: u8) -> Option<&'static str> {
    match b {
        0xb0 | 0xb1 | 0xb2 | 0xb8 | 0xb9 => Some("nop-upgradable"),
        _ => None,
    }
}

fn lock_of(b: u8) -> Vec<u8> {
    match b {
        0x01..=0x4b => {
            let mut v = vec![b];
            v.extend(vec![1u8; b as usize]);
            v
        }
        0x4c => vec![0x4c, 0x01, 0x01],
        0x4d => vec![0x4d, 0x01, 0x00, 0x01],
        0x4e => vec![0x4e, 0x01, 0x00, 0x00, 0x00, 0x01],
        _ => vec![b],
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let out_dir = arg(&args, "--out").unwrap_or_else(|| "../corpus/bytes".into());
    let mut quiet = Quiet::new();
    let mut corpus = Corpus::new(EngineConfig::default());
    let unlock: Vec<u8> = vec![0x51, 0x52, 0x53, 0x54, 0x55, 0x56];
    for version in [2i32, 1] {
        for b in 0u8..=255 {
            let id = corpus.next_id("bytes");
            let txid = synthetic_txid("bytes", &id);
            let prevouts = prevout_of(txid, &lock_of(b));
            let tx = spend_tx(txid, version, unlock.clone());
            let judged = corpus.run(&tx, &prevouts);
            let base = match (candidate(b), policy(b)) {
                (Some(c), _) => format!("bytes/{c}/{b:02x}"),
                (None, Some(p)) => format!("bytes/{p}/{b:02x}"),
                (None, None) => format!("bytes/{b:02x}"),
            };
            let note = format!(
                "byte 0x{b:02x} as the locking script on the stack 1 2 3 4 5 6, version {version}"
            );
            let label = Label::new(id, cases::twin_family(&base, version), "bytes.every", note);
            corpus.record(label, &tx, &prevouts, &judged);
        }
    }
    quiet.restore();
    let comparable = corpus.comparable();
    let (path, sha, _) = corpus.write(&out_dir, Text {
        corpus: "bytes",
        file: "cases.jsonl",
        manifest: "cases-manifest.json",
        generator: "bsv-script-harness bytes_cases 0.0.1 (every byte, both versions; #18)".into(),
        seed: "none (enumerated)".into(),
        generated: "2026-09-23".into(),
        provenance: format!("every byte 0x00–0xff as the locking script on a six-element stack under both versions, bsv-rs {}'s verdicts under the node's standard word; {comparable} comparable (every byte since 0.3.27; the class names of the former bytes-candidate/ and bytes-policy/ families kept); synthetic outpoints = sha256 of the entry id", bsv_script_harness::BSV_RS_VERSION),
    });
    corpus.report("bytes_cases", comparable, &path, &sha);
}
