//! policy_witnesses (#21): the witness transactions for the policy-default
//! differences between bitcoin-sv v1.2.2 and Teranode v0.15.9 that a
//! transaction can exhibit (`docs/PARAMETERS.md` §5 and §7). Each entry records
//! the pinned bsv-rs's script verdict (`BSV_RS_KEY`: 0.4.4 since 2026-10-12, 0.3.33 from 2026-10-07, bsv-rs#41; 0.3.32 from R1.6; 0.3.30 from #47's move, 0.3.28 from
//! 2026-09-24, 0.3.27 on 2026-09-23; under the node's standard word; the committed file keeps its 0.3.30 keys, and this
//! generator at 0.3.32 emits the same verdicts and reasons under the 0.3.32 keys, lane merge32-49's run). bsv-rs has no
//! transaction-level policy; at 0.3.32 (the model of 0.3.30: 0.3.31 changed docs only, 0.3.32 the `int64` reader only,
//! by the crate's CHANGELOG), under a flag word, it keeps ONE stack memory budget over both stacks at 32 bytes per
//! element (`spend.rs:452–473`, `flags.rs:70`), and on the mempool path its policy verdict at 100,000,000 bytes fires
//! whatever the local budget (`spend.rs:486–500`, `2406–2421`). Each entry also carries the `divergence` record with the two
//! nodes' mempool verdicts read from source (`[D]`, the citations in
//! `decided_by`), and for `lean/Test/WitnessCheck.lean` to decide on the
//! spec under both nodes' derived parameters, the one executed check of the
//! node columns (#27 and #30 closed without a node run of these witnesses;
//! #32 C-B3). Every outpoint is synthetic.
//! Run: cargo run --release --bin policy_witnesses -- [--out DIR]

use std::collections::BTreeMap;
use std::io::Write;

use bsv_rs::primitives::hash::sha256;
use bsv_script_harness::corpus::{
    Divergence, Entry, ExpectJson, ImplConfigJson, Manifest, ParamsJson, PrevoutJson,
    DEFAULT_SPEND_HEIGHT,
};
use bsv_script_harness::engine::{run_tx, EngineConfig, Mode, Prevout, Verdict};
use bsv_script_harness::txraw::{RawInput, RawOutput, RawTx};
use bsv_script_harness::BSV_RS_KEY;

const OP_1: u8 = 0x51;
const OP_DROP: u8 = 0x75;
const OP_DUP: u8 = 0x76;
const OP_CAT: u8 = 0x7e;
const OP_PUSHDATA4: u8 = 0x4e;

fn arg(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1).cloned())
}

fn synthetic_txid(id: &str, input: usize) -> [u8; 32] {
    let h = sha256(format!("bsv-script-lean/corpus/witnesses/{id}/{input}").as_bytes());
    let mut out = [0u8; 32];
    out.copy_from_slice(&h[..32]);
    out
}

/// A P2PKH locking script over a synthetic 20-byte hash (a standard output type,
/// `script/standard.cpp:353–374` `TX_PUBKEYHASH`).
fn p2pkh_output() -> Vec<u8> {
    let h = sha256(b"bsv-script-lean/corpus/witnesses/p2pkh");
    let mut s = vec![0x76, 0xa9, 0x14];
    s.extend_from_slice(&h[..20]);
    s.extend_from_slice(&[0x88, 0xac]);
    s
}

fn expect_of(v: &Verdict, i: Option<usize>) -> ExpectJson {
    ExpectJson {
        verdict: v.kind().to_string(),
        code: None,
        reason: v.reason(),
        input: i,
    }
}

struct Built {
    entry: Entry,
    execs: u64,
}

/// The stack-memory witness: a 3-byte element doubled 25 times by `OP_DUP OP_CAT`.
/// At the 25th `OP_DUP` the stack holds two elements of 50,331,648 bytes, each
/// charged size + 32 (`limitedstack.h:43`): 100,663,360 bytes, above bitcoin-sv's
/// default `maxstackmemoryusagepolicy` 100,000,000 (`policy.h:153`) and below
/// Teranode's 104,857,600 (`settings/settings.go:107`); the consensus budget is
/// INT64_MAX in both (`consensus.h:82`, `settings.go:108` → 0 → INT64_MAX).
fn stack_memory_witness() -> Built {
    let id = "witness-policy-00001".to_string();
    let unlock = vec![0x03, 0x01, 0x01, 0x01];
    let mut lock = Vec::new();
    for _ in 0..25 {
        lock.push(OP_DUP);
        lock.push(OP_CAT);
    }
    let txid = synthetic_txid(&id, 0);
    let prevouts = vec![Prevout {
        txid,
        vout: 0,
        script: lock.clone(),
        satoshis: 100_000,
    }];
    let tx = RawTx {
        version: 2,
        inputs: vec![RawInput {
            txid,
            vout: 0,
            script: unlock,
            sequence: 0xffff_ffff,
        }],
        outputs: vec![RawOutput {
            satoshis: 1_000,
            script: p2pkh_output(),
        }],
        lock_time: 0,
    };
    let mut expect = BTreeMap::new();
    let mut execs = 0u64;
    let (v, i) = run_tx(&tx, &prevouts, Mode::Native, &EngineConfig::default());
    execs += 1;
    expect.insert(BSV_RS_KEY.to_string(), expect_of(&v, i));
    for limit in [104_857_600usize, 100_000_000usize] {
        let cfg = EngineConfig {
            memory_limit: Some(limit),
            ..EngineConfig::default()
        };
        let (v, i) = run_tx(&tx, &prevouts, Mode::Native, &cfg);
        execs += 1;
        expect.insert(
            format!("{BSV_RS_KEY}/memory_limit={limit}"),
            expect_of(&v, i),
        );
    }
    let divergence = Divergence {
        rule: "params.policy.maxstackmemoryusagepolicy".into(),
        a: "bitcoin-sv@1.2.2 mempool, defaults".into(),
        b: "teranode@0.15.9 mempool, defaults".into(),
        a_verdict: ExpectJson { verdict: "invalid".into(), code: Some("SCRIPT_ERR_STACK_SIZE".into()), reason: Some("policy: the stack memory 100,663,360 bytes at the 25th OP_DUP exceeds maxstackmemoryusagepolicy 100,000,000".into()), input: Some(0) },
        b_verdict: ExpectJson { verdict: "valid".into(), code: None, reason: Some("the same 100,663,360 bytes are within maxstackmemoryusagepolicy 104,857,600".into()), input: None },
        decided_by: "[SRC] bitcoin-sv v1.2.2 policy.h:153 with consensus.h:15 (100,000,000), limitedstack.h:43 (+32 per element), limitedstack.cpp:194–207 (the combined budget), interpreter.cpp:1814–1817 (SCRIPT_ERR_STACK_SIZE), interpreter.cpp:2282–2302 (the policy limit selected when consensus = false); Teranode v0.15.9 settings/settings.go:107 (104,857,600), ScriptVerifierGoBDK.go:191 (SetMaxStackMemoryUsage), bdk core/txvalidator.cpp:308–311 → configscriptpolicy.cpp:269–308; a block carrying it is valid for both (the block path's consensus budget: consensus.h:82 and settings.go:108, 0 → INT64_MAX), while a default SV-node's mempool refuses it, so a default SV-node never mines it. [D] from source, never run on a node (#27 and #30 closed without measuring it); the executed check is make witnesscheck, the spec under both nodes' derived parameters.".into(),
        ruling: "open".into(),
        minimized: None,
        minimized_prevouts: None,
        note: "a policy-default difference, both consensus-valid: relayed by a default Teranode, refused by a default SV-node's mempool, valid in a block for both. bsv-rs at the pin, under the standard word: invalid under all three recorded keys (its default local budget, memory_limit 104,857,600 and memory_limit 100,000,000 alike), the crate's own mempool-path policy of 100,000,000 bytes refusing the 100,663,360-byte stack before any local budget is reached (the recorded reason); no key ran the crate under a 104,857,600-byte limit, so the cross-engine comparison at Teranode's figure is not measured here.".into(),
    };
    let entry = Entry {
        id,
        family: "witness-policy/stack-memory".into(),
        rule: "params.policy.maxstackmemoryusagepolicy".into(),
        tx: hex::encode(tx.encode()),
        prevouts: prevouts.iter().map(PrevoutJson::from_prevout).collect(),
        params: ParamsJson { spend_height: DEFAULT_SPEND_HEIGHT, era: ParamsJson::era_of(DEFAULT_SPEND_HEIGHT).into(), consensus: false, tx_version: 2 },
        flags: None,
        expect,
        reference: None,
        note: Some("unlock pushes 3 bytes; lock (OP_DUP OP_CAT)×25: the final element is 3·2^25 = 100,663,296 bytes; the peak stack memory 100,663,360 bytes at the last OP_DUP".into()),
        divergence: Some(divergence),
    };
    Built { entry, execs }
}

/// The dust witness: a standard P2PKH output of 0 satoshis. bitcoin-sv's
/// `IsStandardTx` calls it "dust" (`script/standard.cpp:482–484`; the threshold is
/// 1 satoshi for a spendable output, `primitives/transaction.h:203–213`) and the
/// mempool rejects a non-standard transaction under `requirestandard = true`
/// unless the reason is "scriptpubkey" (`validation.cpp:1074–1089`); Teranode's
/// default `requirestandard = false` (`settings.go:112`) passes it (bdk
/// `core/txvalidator.cpp:864–876`). Transaction-level: outside the script semantics.
fn dust_witness() -> Built {
    let id = "witness-policy-00002".to_string();
    let unlock = vec![OP_1];
    let lock = vec![OP_DROP, OP_1];
    let txid = synthetic_txid(&id, 0);
    let prevouts = vec![Prevout {
        txid,
        vout: 0,
        script: lock.clone(),
        satoshis: 1_000,
    }];
    let tx = RawTx {
        version: 2,
        inputs: vec![RawInput {
            txid,
            vout: 0,
            script: unlock,
            sequence: 0xffff_ffff,
        }],
        outputs: vec![RawOutput {
            satoshis: 0,
            script: p2pkh_output(),
        }],
        lock_time: 0,
    };
    let mut expect = BTreeMap::new();
    let (v, i) = run_tx(&tx, &prevouts, Mode::Native, &EngineConfig::default());
    expect.insert(BSV_RS_KEY.to_string(), expect_of(&v, i));
    let divergence = Divergence {
        rule: "params.policy.requirestandard.dust".into(),
        a: "bitcoin-sv@1.2.2 mempool, defaults".into(),
        b: "teranode@0.15.9 mempool, defaults".into(),
        a_verdict: ExpectJson { verdict: "invalid".into(), code: None, reason: Some("REJECT_NONSTANDARD dust (a 0-satoshi spendable output)".into()), input: None },
        b_verdict: ExpectJson { verdict: "valid".into(), code: None, reason: Some("requirestandard = false: the non-standard transaction is accepted".into()), input: None },
        decided_by: "[SRC] bitcoin-sv v1.2.2 script/standard.cpp:427–500 (IsStandardTx: dust at 482–484), primitives/transaction.h:203–213 (the 1-satoshi threshold), validation.cpp:1074–1089 (the mempool gate: requireStandard and reason != \"scriptpubkey\"), configscriptpolicy.cpp:61 (requireStandard true by default) with init.cpp:3001–3003 (RequireStandard from the chain, true on mainnet); Teranode v0.15.9 settings/settings.go:112 (requirestandard false), :111 (acceptnonstdoutputs true), ScriptVerifierGoBDK.go:203, bdk core/txvalidator.cpp:854–880 (the same gate with requireStandard false). Consensus: a 0-value output is valid (validation.cpp:438–640, TxRules.checkTransactionCommon). [D] from source, never run on a node (#27 and #30 closed without measuring it); the executed check is make witnesscheck, the spec under both nodes' derived parameters.".into(),
        ruling: "open".into(),
        minimized: None,
        minimized_prevouts: None,
        note: "transaction-level (DESIGN §5.5): the scripts are valid under every derived word; the difference is the standardness gate, which a default SV-node applies and a default Teranode does not.".into(),
    };
    let entry = Entry {
        id,
        family: "witness-policy/dust".into(),
        rule: "params.policy.requirestandard.dust".into(),
        tx: hex::encode(tx.encode()),
        prevouts: prevouts.iter().map(PrevoutJson::from_prevout).collect(),
        params: ParamsJson { spend_height: DEFAULT_SPEND_HEIGHT, era: ParamsJson::era_of(DEFAULT_SPEND_HEIGHT).into(), consensus: false, tx_version: 2 },
        flags: None,
        expect,
        reference: None,
        note: Some("one P2PKH output of 0 satoshis (dust for bitcoin-sv's standardness, not for consensus); the input's scripts are trivially valid".into()),
        divergence: Some(divergence),
    };
    Built { entry, execs: 1 }
}

/// The transaction-size witness: 21 inputs whose unlocking scripts each push
/// 490,000 bytes (a single PUSHDATA4, push-only) that the lock drops: a
/// transaction of about 10.29 MB, above bitcoin-sv's default
/// `maxtxsizepolicy` 10,000,000 (`policy.h:70`; `IsStandardTx` "tx-size",
/// `script/standard.cpp:445–449`) and below Teranode v0.16.0's 10,485,760
/// (`settings/settings.go:108`), within the consensus size 1 GB (`consensus.h:29`);
/// each script fits both script-size policy defaults, bitcoin-sv's 500,000
/// (`policy.h:93`) and Teranode v0.16.0's 100,000,000 (`settings/settings.go:113`).
/// Transaction-level.
fn tx_size_witness() -> Built {
    let id = "witness-policy-00003".to_string();
    let n_inputs = 21usize;
    let blob_len = 490_000usize;
    let mut unlock = vec![OP_PUSHDATA4];
    unlock.extend_from_slice(&(blob_len as u32).to_le_bytes());
    unlock.extend(std::iter::repeat_n(0u8, blob_len));
    let lock = vec![OP_DROP, OP_1];
    let mut prevouts = Vec::new();
    let mut inputs = Vec::new();
    for i in 0..n_inputs {
        let txid = synthetic_txid(&id, i);
        prevouts.push(Prevout {
            txid,
            vout: 0,
            script: lock.clone(),
            satoshis: 1_000_000,
        });
        inputs.push(RawInput {
            txid,
            vout: 0,
            script: unlock.clone(),
            sequence: 0xffff_ffff,
        });
    }
    let tx = RawTx {
        version: 2,
        inputs,
        outputs: vec![RawOutput {
            satoshis: 1_000,
            script: p2pkh_output(),
        }],
        lock_time: 0,
    };
    let bytes = tx.encode();
    let size = bytes.len();
    assert!(
        size > 10_000_000 && size <= 10_485_760,
        "the witness must sit between the two policies: {size}"
    );
    let mut expect = BTreeMap::new();
    let (v, i) = run_tx(&tx, &prevouts, Mode::Native, &EngineConfig::default());
    expect.insert(BSV_RS_KEY.to_string(), expect_of(&v, i));
    let divergence = Divergence {
        rule: "params.policy.maxtxsizepolicy".into(),
        a: "bitcoin-sv@1.2.2 mempool, defaults".into(),
        b: "teranode@0.15.9 mempool, defaults".into(),
        a_verdict: ExpectJson { verdict: "invalid".into(), code: None, reason: Some(format!("REJECT_NONSTANDARD tx-size ({size} bytes above maxtxsizepolicy 10,000,000)")), input: None },
        b_verdict: ExpectJson { verdict: "valid".into(), code: None, reason: Some(format!("{size} bytes within maxtxsizepolicy 10,485,760; requirestandard = false besides")), input: None },
        decided_by: "[SRC] bitcoin-sv v1.2.2 script/standard.cpp:445–449 (IsStandardTx \"tx-size\" against GetMaxTxSize(era, false)), configscriptpolicy.cpp:397–412 (the policy value post-Genesis), policy.h:70 (10 × ONE_MEGABYTE = 10,000,000), validation.cpp:1074–1089 (the mempool gate); Teranode v0.15.9 settings/settings.go:97 (10,485,760), ScriptVerifierGoBDK.go:171 (SetMaxTxSizePolicy), settings/settings.go:112 (requirestandard false), bdk core/txvalidator.cpp:854–880. Consensus: consensus.h:29 (MAX_TX_SIZE_CONSENSUS_AFTER_GENESIS = 1 GB) in both. [D] from source, never run on a node (#27 and #30 closed without measuring it); the executed check is make witnesscheck, the spec under both nodes' derived parameters.".into(),
        ruling: "open".into(),
        minimized: None,
        minimized_prevouts: None,
        note: "transaction-level (DESIGN §5.5): every script is valid under every derived word (21 × a 490,000-byte push dropped, within maxscriptsizepolicy 500,000 in both); the file is regenerated by `make policywitnesses`, its sha256 in the manifest and corpus/INDEX.md, and is not committed (about 20 MB of hex).".into(),
    };
    let entry = Entry {
        id,
        family: "witness-policy/tx-size".into(),
        rule: "params.policy.maxtxsizepolicy".into(),
        tx: hex::encode(bytes),
        prevouts: prevouts.iter().map(PrevoutJson::from_prevout).collect(),
        params: ParamsJson { spend_height: DEFAULT_SPEND_HEIGHT, era: ParamsJson::era_of(DEFAULT_SPEND_HEIGHT).into(), consensus: false, tx_version: 2 },
        flags: None,
        expect,
        reference: None,
        note: Some(format!("{n_inputs} inputs, each a {blob_len}-byte PUSHDATA4 dropped by the lock; {size} bytes in all")),
        divergence: Some(divergence),
    };
    Built { entry, execs: 1 }
}

#[allow(
    clippy::unwrap_used,
    reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
)]
fn write_jsonl(path: &str, entries: &[&Entry]) -> String {
    let mut bytes = Vec::new();
    for e in entries {
        bytes.extend_from_slice(serde_json::to_string(e).unwrap().as_bytes());
        bytes.push(b'\n');
    }
    std::fs::File::create(path)
        .unwrap()
        .write_all(&bytes)
        .unwrap();
    hex::encode(sha256(&bytes))
}

#[allow(
    clippy::expect_used,
    clippy::unwrap_used,
    reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
)]
fn main() {
    let args: Vec<String> = std::env::args().collect();
    let out_dir = arg(&args, "--out").unwrap_or_else(|| "../corpus/witnesses".into());
    let prev_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(|_| {}));
    let small = [stack_memory_witness(), dust_witness()];
    let large = tx_size_witness();
    std::panic::set_hook(prev_hook);
    for b in small.iter().chain(std::iter::once(&large)) {
        b.entry.check().expect("well-formed");
    }
    std::fs::create_dir_all(&out_dir).expect("out dir");
    let small_path = format!("{out_dir}/policy-defaults.jsonl");
    let large_path = format!("{out_dir}/policy-defaults-large.jsonl");
    let sha_small = write_jsonl(
        &small_path,
        &small.iter().map(|b| &b.entry).collect::<Vec<_>>(),
    );
    let sha_large = write_jsonl(&large_path, &[&large.entry]);
    let mut families: BTreeMap<String, u64> = BTreeMap::new();
    let mut rules: BTreeMap<String, u64> = BTreeMap::new();
    let mut verdicts: BTreeMap<String, u64> = BTreeMap::new();
    let mut execs = 0u64;
    for b in small.iter().chain(std::iter::once(&large)) {
        *families.entry(b.entry.family.clone()).or_default() += 1;
        *rules.entry(b.entry.rule.clone()).or_default() += 1;
        *verdicts
            .entry(b.entry.expect[BSV_RS_KEY].verdict.clone())
            .or_default() += 1;
        execs += b.execs;
    }
    let mut config = BTreeMap::new();
    for (k, v) in EngineConfig::default().to_json() {
        config.insert(k, v);
    }
    config.insert("also".into(), serde_json::json!("witness-policy-00001 under memory_limit 104,857,600 and 100,000,000 (the expect keys): invalid under every key, the crate's mempool-path policy of 100,000,000 bytes refusing first"));
    let manifest = Manifest {
        corpus: "witnesses/policy-defaults".into(),
        file: "policy-defaults.jsonl (+ policy-defaults-large.jsonl, regenerated, not committed)".into(),
        generator: "bsv-script-harness policy_witnesses 0.0.1 (#21: the policy-default witnesses)".into(),
        seed: "none (constructed)".into(),
        count: 3,
        sha256: format!("{sha_small} (policy-defaults.jsonl); {sha_large} (policy-defaults-large.jsonl, {} bytes)", std::fs::metadata(&large_path).map(|m| m.len()).unwrap_or(0)),
        families,
        rules,
        verdicts,
        implementations: vec![ImplConfigJson { name: "bsv-rs".into(), version: bsv_script_harness::BSV_RS_VERSION.into(), config }],
        engine_executions: execs,
        generated: "2026-09-23".into(),
        provenance: "constructed witnesses for docs/PARAMETERS.md §5/§7: the two nodes' expected mempool verdicts are read from source ([D]) and recorded in each entry's divergence record; bsv-rs's script verdicts are executed; every outpoint synthetic".into(),
    };
    std::fs::write(
        format!("{out_dir}/policy-defaults-manifest.json"),
        serde_json::to_string_pretty(&manifest).unwrap() + "\n",
    )
    .unwrap();
    println!("policy_witnesses: 2 → {small_path} (sha256 {sha_small}); 1 → {large_path} (sha256 {sha_large})");
    for b in small.iter().chain(std::iter::once(&large)) {
        println!(
            "  {} {}: bsv-rs {:?}",
            b.entry.id,
            b.entry.family,
            b.entry
                .expect
                .iter()
                .map(|(k, v)| format!("{k}={}", v.verdict))
                .collect::<Vec<_>>()
        );
    }
}
