//! run_engine (this repo's; #29): the differential of the spec's evaluator against an SDK engine
//! (go-sdk, ts-sdk) on a corpus, every divergence a witness with its rule.
//!
//! Inputs: a corpus file (`docs/DESIGN.md` §6) and the spec's verdicts for it (`eval/bsvs corpus <file>
//! --out <spec.jsonl>`: per entry `spec` = under the entry's own `params`, `spec-mempool` = under the
//! mempool word of the same configuration). The engine runs out of process (`engines.rs`: the adapters
//! `harness/engines/go/main.go`, `harness/engines/ts/runner.mjs`) at the release pinned in
//! `docs/PROVENANCE.md` §1a, checked at spawn.
//!
//! The words: every input's flag word is asked of the spec's own executable (`flags_oracle.rs`:
//! `Params.derive` echoed by `eval/bsvs eval`, cached per `(spend_height, utxo_height, consensus)`), never
//! derived here; an entry's explicit `flags` are honoured for the `spec` column as the CLI honours them.
//! The engine then runs under the SAME word the spec judged the same input under, so both columns are
//! like-for-like on the parameters: `spec` (the block word: what a mining node decides) and
//! `spec-mempool` (the relay word). ts-sdk has a third run, `default`: no explicit word, the SDK's own
//! derivation from the transaction version (what an application gets out of the box); it is compared
//! with `spec-mempool` (the closest node word) and, as a note, with `spec`.
//!
//! Tier 1 (validity) is compared per column; every divergence is classified by a rule (an engine's cited
//! divergence class from the reference at the pin, `corpus/INDEX.md` §2) from the entry's own
//! `rule`/`family`, the shapes of its scripts and the two codes: THE CLASSIFIER IS DATA since 2026-09-26
//! (D83c, #31): `harness/rules/<engine>.json` read through `harness/src/rules.rs`, this driver's one touch; a
//! divergence no row explains is UNEXPLAINED and the run is RED. The engine's code or message is mapped to the reference's
//! `SCRIPT_ERR_*` through the cited tables (`gosdk_codes.rs`, `tssdk_codes.rs`); a code outside them is
//! RED. Tier 2 (the code) is compared as a note per column (counted, printed, never RED). An `undecided`
//! engine run is an adapter or API error (the harness's business, reported and never counted) or a run
//! without a spec verdict; an engine's ABORT on an entry the spec decides (an exception, a death, a
//! timeout that survives the D15a re-run at ten times the wall) is a WITNESS under a class naming the
//! engine's mechanism, never an undecided run (D15/D15a, ruled 2026-09-24 on #42: an entry is a witness
//! or an undecided run, never both). An SDK's own decoder refusing a transaction the spec decides is such an abort
//! (the owner's ruling R3 on #32, 2026-10-05; `gosdk_codes::DECODE_REFUSALS`): the engine's script status stays
//! `undecided`, the class carries the disposition, and the run is counted once, as a witness (`decode_refusals` in the
//! manifest, inside `aborts_as_witnesses`); the script verdict says nothing of the transaction's validity.
//!
//! Outputs: `<witnesses>/<engine>/<corpus>.jsonl` (one witness per corpus × column × rule: the smallest
//! divergent entry, its `expect` carrying the spec's key and the engine's, a `divergence` record),
//! `<witnesses>/<engine>/manifest.json` (the counts, the words, the notes), the report table on stdout.
//! With `--record` the engine's verdicts are written into the corpus entries (`<engine>@<version>` under the
//! entry's own params, `<engine>-mempool@<version>`, and for ts-sdk `<engine>-default@<version>`; older
//! keys of the same names removed), the manifest's `implementations` rows added and its sha256
//! re-stamped. `--limit N` runs the first N entries (a smoke run; never with `--record`).
//!
//! THE LEAN-FREE RUN (#31, 2026-09-29): `--words-from <manifest.json>` serves the words a witness manifest recorded for
//! this corpus (`FlagsOracle::recorded`: its `[<corpus>].words`, nothing asked of `eval/bsvs`); with a spec file written
//! from the corpus's recorded `spec@` keys (`spec_recorded`), a machine without the Lean build runs the differential.
//! `harness/run` is the one command over both modes.
//!
//! Run: cargo run --release --locked --bin run_engine -- --engine gosdk|tssdk --corpus ../corpus/seed/seed.jsonl
//!      --spec <spec.jsonl> [--witnesses ../corpus/witnesses] [--words-from <manifest.json>] [--record] [--limit N]

use std::collections::BTreeMap;
use std::io::BufRead;
use std::path::PathBuf;

use bsv_rs::primitives::hash::sha256;
use bsv_script_harness::corpus::{Divergence, Entry, ExpectJson, ImplConfigJson};
use bsv_script_harness::differential::{
    read_spec, spec_json as spec_json_of, CorpusInput, SpecVerdict,
};
use bsv_script_harness::engines::{Adapter, EngineKind, PrevoutReq, Request, RunReq, RunVerdict};
use bsv_script_harness::fail::OrErr;
use bsv_script_harness::flags_oracle::FlagsOracle;
use bsv_script_harness::rules::{self, Explanation, RuleSet};
use bsv_script_harness::txraw::RawTx;
use bsv_script_harness::{gosdk_codes, svnode_codes, tssdk_codes};

fn arg(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1).cloned())
}

/// What the harness knows of one engine run of an entry, in the spec's vocabulary.
struct EngineSide {
    kind: String,
    input: Option<usize>,
    /// the reference's `SCRIPT_ERR_*` name through the cited table, when the engine reported an error
    code: Option<&'static str>,
    /// the engine's own vocabulary, one line
    native: String,
    /// the cited table's row note (kept for the report; unread since the classifier moved to data, D83c)
    _table_note: &'static str,
    unknown_code: bool,
}

fn side_of(engine: EngineKind, v: &RunVerdict) -> EngineSide {
    let native = v.native();
    let msg = v.message.as_deref().unwrap_or("");
    let code_name = v.code.as_deref().unwrap_or("");
    let mut kind = v.verdict.clone();
    let mut code = None;
    let mut note = "";
    let mut unknown = false;
    if kind == "invalid" {
        match engine {
            EngineKind::GoSdk => {
                if gosdk_codes::is_adapter_code(code_name) {
                    kind = "undecided".into();
                } else if let Some(r) = gosdk_codes::code_of(code_name, msg) {
                    code = Some(r.script_err);
                    note = r.note;
                } else {
                    unknown = true;
                }
            }
            EngineKind::GoBdk => {
                // the shim reports the reference's SCRIPT_ERR_* name through its cited table (harness/engines/gobdk/codes.go:
                // GoBDK's code is the reference's ScriptError ordinal) and the linked library's own ScriptErrorString text;
                // the name must be the reference's and the text its description (svnode_codes.rs, script_error.cpp at the
                // pin), else the code is outside the table (RED, the table grows)
                match svnode_codes::TABLE.iter().find(|r| r.code == code_name) {
                    Some(r) if msg.ends_with(r.description) => {
                        code = Some(r.code);
                        note = "GoBDK's code is the reference's ScriptError ordinal (harness/engines/gobdk/codes.go)";
                    }
                    _ => unknown = true,
                }
            }
            EngineKind::TsSdk => {
                if code_name == "validate-false" {
                    code = Some("SCRIPT_ERR_EVAL_FALSE");
                } else if let Some(r) = tssdk_codes::code_of(msg) {
                    code = Some(r.code);
                    note = r.note;
                } else {
                    unknown = true;
                }
            }
        }
    }
    EngineSide {
        kind,
        input: v.input,
        code,
        native,
        _table_note: note,
        unknown_code: unknown,
    }
}

fn verdict_json_of(side: &EngineSide) -> ExpectJson {
    ExpectJson {
        verdict: side.kind.clone(),
        code: side.code.map(|c| c.to_string()),
        reason: if side.native.is_empty() {
            None
        } else {
            Some(side.native.clone())
        },
        input: side.input,
    }
}

struct Count {
    n: u64,
    smallest: Option<(usize, Entry, ExpectJson, ExpectJson)>,
    explanation: Explanation,
}

/// The exit code of `run` (#132): an error that stood as an unwrap, expect or panic is reported with its words and exits 1.
fn main() -> std::process::ExitCode {
    match run() {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("run_engine: {e}");
            std::process::ExitCode::from(1)
        }
    }
}

fn run() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();
    let engine = EngineKind::parse(&arg(&args, "--engine").or_err("--engine gosdk|tssdk|gobdk")?)
        .or_err("--engine gosdk|tssdk|gobdk")?;
    let corpus_path = arg(&args, "--corpus").or_err("--corpus <file.jsonl>")?;
    let spec_path = arg(&args, "--spec").or_err("--spec <spec.jsonl> (from `eval/bsvs corpus`)")?;
    let witnesses_dir = arg(&args, "--witnesses").unwrap_or_else(|| "../corpus/witnesses".into());
    let record = args.iter().any(|a| a == "--record");
    let limit: Option<usize> = arg(&args, "--limit")
        .map(|s| s.parse().or_err("--limit N"))
        .transpose()?;
    let dump = arg(&args, "--dump");
    let words_from = arg(&args, "--words-from");
    let mut dump_lines: Vec<String> = Vec::new();
    if record && limit.is_some() {
        eprintln!("run_engine: --record with --limit would record a partial run; refused");
        std::process::exit(2);
    }
    // the repository root: the harness crate's parent
    let root: PathBuf = match std::env::var("BSV_SCRIPT_LEAN_ROOT") {
        Ok(r) => PathBuf::from(r),
        Err(_) => {
            let here = std::env::current_dir().or_err("cwd")?;
            if here.join("Cargo.toml").exists()
                && here.join("..").join("eval").join("bsvs").exists()
            {
                here.join("..")
                    .canonicalize()
                    .or_err("here.join('..').canonicalize()")?
            } else {
                here
            }
        }
    };
    // lean #32, B-4: no spec stamp without a commit reaches the corpus (`bsv_script_harness::stamp`)
    bsv_script_harness::stamp::refuse_unnamed_stamp(
        "run_engine",
        &spec_path,
        record,
        &witnesses_dir,
        &root,
    );

    let CorpusInput {
        file_name,
        corpus_name,
        bytes,
        manifest_path,
        manifest,
    } = CorpusInput::load(std::path::Path::new(&corpus_path)).unwrap_or_else(|e| {
        eprintln!("run_engine: {e}");
        std::process::exit(1);
    });
    let spec = read_spec(std::path::Path::new(&spec_path)).unwrap_or_else(|e| {
        eprintln!("run_engine: {e}");
        std::process::exit(2);
    });
    let commit = spec
        .values()
        .next()
        .map(|s| s.commit.clone())
        .unwrap_or_else(|| "unknown".into());
    let config = spec
        .values()
        .next()
        .map(|s| s.config.clone())
        .unwrap_or_else(|| "unknown".into());
    let spec_key = format!("spec@{commit}");
    let mempool_key = format!("spec-mempool@{commit}");
    let oracle_config = if config.starts_with("teranode") {
        "teranode"
    } else {
        "sv"
    };
    let mut oracle = match &words_from {
        Some(m) => {
            FlagsOracle::recorded(std::path::Path::new(m), &corpus_name).unwrap_or_else(|e| {
                eprintln!("run_engine: {e}");
                std::process::exit(2);
            })
        }
        None => FlagsOracle::new(&root, oracle_config),
    };
    // THE CLASSIFIER AS DATA (D83c): the engine's table under harness/rules/, the one touch of this driver
    let rules_table = match RuleSet::load(&root, engine.name()) {
        Ok(r) => r,
        Err(e) => {
            eprintln!("run_engine: {e}");
            std::process::exit(1);
        }
    };

    let mut adapter = match Adapter::spawn(engine, &root) {
        Ok(a) => a,
        Err(e) => {
            eprintln!("run_engine: {e}");
            std::process::exit(1);
        }
    };
    let engine_key = engine.key();
    let engine_mempool_key = engine.mempool_key();
    let engine_default_key = engine.default_key();

    let t0 = std::time::Instant::now();
    let mut entries: Vec<Entry> = Vec::new();
    let (mut n, mut no_spec, mut undecided, mut unknown_codes) = (0u64, 0u64, 0u64, 0u64);
    let mut unknown_messages: BTreeMap<String, u64> = BTreeMap::new();
    let mut undecided_messages: BTreeMap<String, u64> = BTreeMap::new();
    let mut counts: BTreeMap<(String, String), Count> = BTreeMap::new(); // (column, rule)
    let mut agree: BTreeMap<String, u64> = BTreeMap::new();
    let mut code_notes: BTreeMap<(String, String, String), u64> = BTreeMap::new(); // (column, spec code, engine code) both invalid, codes differ
    let mut unexplained: Vec<String> = Vec::new();
    let mut unexplained_hist: BTreeMap<String, u64> = BTreeMap::new();
    let mut undefined_in_reference: u64 = 0;
    let mut unmapped_bits: BTreeMap<String, u64> = BTreeMap::new();
    let mut adapter_errors: u64 = 0;
    let mut adapter_deaths: u64 = 0;
    let mut recovered_deaths: u64 = 0;
    // D15/D15a (2026-09-24, #42): an engine's abort on an input the spec decides is a WITNESS, never an undecided run;
    // a timeout at the adapter wall is re-run once at ten times the wall in a fresh adapter
    let mut timeouts: u64 = 0;
    let mut timeouts_rerun_decided: u64 = 0;
    let mut aborts_as_witnesses: u64 = 0;
    // R3 on #32: of those, the runs on which the SDK's own decoder refused the transaction
    let mut decode_refusals: u64 = 0;
    let mut abort_messages: BTreeMap<String, u64> = BTreeMap::new();
    for line in std::io::BufReader::new(&bytes[..]).lines() {
        if let Some(l) = limit {
            if n as usize >= l {
                break;
            }
        }
        let line = line.or_err("line")?;
        if line.trim().is_empty() {
            continue;
        }
        let mut e: Entry = serde_json::from_str(&line).or_err("entry")?;
        e.check().or_err("a corpus entry must be well-formed")?;
        n += 1;
        let tx = RawTx::decode(&hex::decode(&e.tx).or_err("tx hex")?).or_err("tx frame")?;
        let Some(s) = spec.get(&e.id) else {
            no_spec += 1;
            continue;
        };
        // the words per input: the block column honours an explicit word; the mempool column never does (as the CLI)
        let mut block_words = Vec::with_capacity(e.prevouts.len());
        let mut mempool_words = Vec::with_capacity(e.prevouts.len());
        for (i, p) in e.prevouts.iter().enumerate() {
            let bw = match &e.flags {
                Some(f) => f[i],
                None => oracle
                    .word(e.params.spend_height, p.height, e.params.consensus)
                    .or_err("the flag word")?,
            };
            block_words.push(bw);
            mempool_words.push(
                oracle
                    .word(e.params.spend_height, p.height, false)
                    .or_err("the flag word")?,
            );
        }
        // the GoBDK shim (#28) also takes the `consensus` boolean per run and the heights: the block column passes the
        // entry's own `consensus` with the block word, the mempool column `false` with the mempool word (as the node
        // runner's two instances); the SDK adapters are sent neither
        let bdk = engine == EngineKind::GoBdk;
        let mut runs = vec![
            RunReq {
                key: "block".into(),
                mode: Some("flags"),
                flags: Some(block_words.clone()),
                consensus: bdk.then_some(e.params.consensus),
            },
            RunReq {
                key: "mempool".into(),
                mode: Some("flags"),
                flags: Some(mempool_words.clone()),
                consensus: bdk.then_some(false),
            },
        ];
        if engine.has_default_mode() {
            runs.push(RunReq {
                key: "default".into(),
                mode: Some("default"),
                flags: None,
                consensus: None,
            });
        }
        let req = Request {
            id: e.id.clone(),
            tx: e.tx.clone(),
            prevouts: e
                .prevouts
                .iter()
                .map(|p| PrevoutReq {
                    txid: p.txid.clone(),
                    vout: p.vout,
                    script: p.script.clone(),
                    satoshis: p.satoshis,
                    height: bdk.then_some(p.height),
                })
                .collect(),
            runs,
            spend_height: bdk.then_some(e.params.spend_height),
        };
        let resp = match adapter.call(&req) {
            Ok(r) => r,
            Err(err) if err.contains("adapter-timeout") => {
                // the adapter gave no answer within the per-entry wall (engines.rs: ENGINE_ADAPTER_TIMEOUT_S, 120 s by
                // default; the adapter was killed). D15a (ruled 2026-09-24 on #42): the entry is re-run ONCE in a fresh
                // adapter at TEN times the wall; decided within it, the verdict is the engine's and no witness is filed
                // for time alone; not decided, every run of the entry is an abort by D15 (`engine.timeout`, both walls
                // named): a witness, never an undecided run. A fresh adapter at the normal wall serves the next entry.
                let wall = adapter.timeout;
                let rerun_wall = wall * 10;
                timeouts += 1;
                eprintln!("run_engine: {}: {err}; the D15a re-run: once more in a fresh adapter at 10× the wall ({} s)", e.id, rerun_wall.as_secs());
                let mut fresh = match Adapter::spawn_with_timeout(engine, &root, rerun_wall) {
                    Ok(a) => a,
                    Err(e2) => {
                        eprintln!("run_engine: respawn failed: {e2}");
                        std::process::exit(1);
                    }
                };
                let resp = match fresh.call(&req) {
                    Ok(r) => {
                        timeouts_rerun_decided += 1;
                        eprintln!("run_engine: {}: decided on the 10× re-run ({} s wall): the engine's verdict, no witness for time alone", e.id, rerun_wall.as_secs());
                        r
                    }
                    Err(err2) => {
                        eprintln!("run_engine: {}: no answer within {} s on the re-run either ({err2}): an abort by D15, the class engine.timeout", e.id, rerun_wall.as_secs());
                        let mut runs = BTreeMap::new();
                        for r in &req.runs {
                            runs.insert(r.key.clone(), RunVerdict {
                                verdict: "undecided".into(), input: None, code: Some("adapter-timeout".into()),
                                message: Some(format!("adapter-timeout: no answer within {} s, nor within {} s on the D15a re-run in a fresh adapter (the adapter killed both times; ENGINE_ADAPTER_TIMEOUT_S): {err}", wall.as_secs(), rerun_wall.as_secs())),
                                engine_flags: serde_json::Value::Null, unmapped_bits: None, unconsulted: None,
                            });
                        }
                        bsv_script_harness::engines::Response {
                            id: e.id.clone(),
                            runs,
                            error: None,
                        }
                    }
                };
                fresh.close();
                adapter = match Adapter::spawn(engine, &root) {
                    Ok(a) => a,
                    Err(e2) => {
                        eprintln!("run_engine: respawn failed: {e2}");
                        std::process::exit(1);
                    }
                };
                resp
            }
            Err(err) => {
                // the adapter died on this entry (an abort, a signal). The death may be the engine's wall
                // on the entry or the process's age (the harness batches every entry through one process),
                // so the entry is retried ONCE in a fresh process: a verdict there is the engine's verdict
                // and the death is counted as recovered; a second death is the engine's wall and every run
                // of the entry is undecided with the cause. The driver never fabricates a verdict and never
                // skips the entry silently.
                eprintln!("run_engine: {}: the adapter died: {err}; retrying the entry in a fresh process", e.id);
                adapter_deaths += 1;
                adapter = match Adapter::spawn(engine, &root) {
                    Ok(a) => a,
                    Err(e2) => {
                        eprintln!("run_engine: respawn failed: {e2}");
                        std::process::exit(1);
                    }
                };
                match adapter.call(&req) {
                    Ok(r) => {
                        recovered_deaths += 1;
                        r
                    }
                    Err(err2) => {
                        eprintln!("run_engine: {}: the adapter died again in a fresh process: {err2}; the entry is undecided", e.id);
                        let mut runs = BTreeMap::new();
                        for r in &req.runs {
                            runs.insert(r.key.clone(), RunVerdict {
                                verdict: "undecided".into(), input: None, code: Some("adapter-died".into()),
                                message: Some(format!("the adapter process died on this entry twice (once in a fresh process): {err2}")),
                                engine_flags: serde_json::Value::Null, unmapped_bits: None, unconsulted: None,
                            });
                        }
                        adapter = match Adapter::spawn(engine, &root) {
                            Ok(a) => a,
                            Err(e2) => {
                                eprintln!("run_engine: respawn failed: {e2}");
                                std::process::exit(1);
                            }
                        };
                        bsv_script_harness::engines::Response {
                            id: e.id.clone(),
                            runs,
                            error: None,
                        }
                    }
                }
            }
        };
        if let Some(err) = &resp.error {
            adapter_errors += 1;
            eprintln!("run_engine: {}: adapter error: {err}", e.id);
        }
        let mut sides: BTreeMap<String, EngineSide> = BTreeMap::new();
        for (k, v) in &resp.runs {
            for u in v
                .unmapped_bits
                .iter()
                .flatten()
                .chain(v.unconsulted.iter().flatten())
            {
                *unmapped_bits.entry(u.clone()).or_insert(0) += 1;
            }
            let side = side_of(engine, v);
            if side.unknown_code {
                unknown_codes += 1;
                *unknown_messages.entry(side.native.clone()).or_insert(0) += 1;
            }
            sides.insert(k.clone(), side);
        }
        if record {
            let stale: Vec<String> = e
                .expect
                .keys()
                .filter(|k| {
                    k.starts_with(&format!("{}@", engine.name()))
                        || k.starts_with(&format!("{}-mempool@", engine.name()))
                        || k.starts_with(&format!("{}-default@", engine.name()))
                })
                .cloned()
                .collect();
            for k in stale {
                e.expect.remove(&k);
            }
            if let Some(b) = sides.get("block") {
                e.expect.insert(engine_key.clone(), verdict_json_of(b));
            }
            if let Some(m) = sides.get("mempool") {
                e.expect
                    .insert(engine_mempool_key.clone(), verdict_json_of(m));
            }
            if let Some(d) = sides.get("default") {
                e.expect
                    .insert(engine_default_key.clone(), verdict_json_of(d));
            }
        }
        // the columns: (label, the spec's verdict, the engine's run)
        let mut columns: Vec<(&str, &SpecVerdict, &str)> = vec![
            ("spec", &s.spec, "block"),
            ("spec-mempool", &s.spec_mempool, "mempool"),
        ];
        if engine.has_default_mode() {
            columns.push(("default/spec-mempool", &s.spec_mempool, "default"));
            columns.push(("default/spec", &s.spec, "default"));
        }
        // D15 (2026-09-24, #42): a run the engine could not decide is a WITNESS when the spec decides the entry (an
        // abort: an exception, a death, a timeout after the D15a re-run) and an undecided run otherwise (the adapter's
        // own codes, no spec verdict); never both. The runs a witness absorbs are collected here and counted below.
        let mut witnessed_runs: std::collections::BTreeSet<String> =
            std::collections::BTreeSet::new();
        for (column, sv, run) in columns {
            let Some(side) = sides.get(run) else { continue };
            if sv.verdict == "unimplemented" {
                continue;
            }
            if side.kind == "undecided" {
                // an adapter or API code is the harness's business: an undecided run, reported below, never a witness; an
                // SDK's refusal to decode the transaction is the engine's, not the adapter's (the owner's ruling R3 on #32,
                // 2026-10-05: D15 as written): it goes on to the classifier like any other abort
                if gosdk_codes::is_adapter_failure(engine.name(), &side.native) {
                    continue;
                }
            }
            if sv.verdict == "undefined-in-reference" {
                undefined_in_reference += 1;
                continue;
            }
            if sv.verdict == side.kind {
                *agree.entry(column.to_string()).or_insert(0) += 1;
                if side.kind == "invalid" {
                    let sc = sv.code.clone().unwrap_or_default();
                    let ec = side.code.unwrap_or("(no row)").to_string();
                    if sc != ec {
                        *code_notes.entry((column.to_string(), sc, ec)).or_insert(0) += 1;
                    }
                }
                continue;
            }
            let ex = rules_table
                .explain(
                    &rules::observe(
                        &e,
                        &tx,
                        column,
                        &sv.verdict,
                        sv.code.as_deref(),
                        &side.kind,
                        side.code,
                        &side.native,
                    )
                    .with_spec_consensus(&s.spec.verdict),
                )
                .unwrap_or_else(|| rules_table.record(rules::UNEXPLAINED));
            if side.kind == "undecided" && ex.rule != "unexplained" {
                witnessed_runs.insert(run.to_string());
            }
            if dump.is_some() {
                dump_lines.push(serde_json::json!({
                    "column": column, "id": e.id, "family": e.family, "rule": e.rule, "version": tx.version,
                    "spec": sv.verdict, "spec_code": sv.code, "engine": side.kind, "engine_code": side.code, "native": side.native,
                    "classified": ex.rule, "lock": e.prevouts.first().map(|p| p.script.clone()).unwrap_or_default(),
                    "unlock": hex::encode(tx.inputs.first().map(|i| i.script.clone()).unwrap_or_default()),
                }).to_string());
            }
            if ex.rule == "unexplained" {
                let key = format!(
                    "{column} | version {} | {} | {} | spec {}{} | engine {}{}",
                    tx.version,
                    e.family,
                    e.rule,
                    sv.verdict,
                    sv.code
                        .as_ref()
                        .map(|c| format!(" {c}"))
                        .unwrap_or_default(),
                    side.kind,
                    if side.native.is_empty() {
                        String::new()
                    } else {
                        format!(" [{}]", side.native.chars().take(90).collect::<String>())
                    }
                );
                *unexplained_hist.entry(key).or_insert(0) += 1;
                if unexplained.len() < 40 {
                    unexplained.push(format!(
                        "{column} {} ({}, rule {}, version {}): spec {}{} vs {} {} {}",
                        e.id,
                        e.family,
                        e.rule,
                        tx.version,
                        sv.verdict,
                        sv.code
                            .as_ref()
                            .map(|c| format!(" {c}"))
                            .unwrap_or_default(),
                        engine.name(),
                        side.kind,
                        side.native
                    ));
                }
            }
            let key = (column.to_string(), ex.rule.to_string());
            let size = e.tx.len();
            let a_v = spec_json_of(sv);
            let b_v = verdict_json_of(side);
            let c = counts.entry(key).or_insert_with(|| Count {
                n: 0,
                smallest: None,
                explanation: ex,
            });
            c.n += 1;
            let better = match &c.smallest {
                None => true,
                Some((sz, _, _, _)) => size < *sz,
            };
            if better {
                c.smallest = Some((size, e.clone(), a_v, b_v));
            }
        }
        for (k, side) in &sides {
            if side.kind == "undecided" {
                if witnessed_runs.contains(k) {
                    aborts_as_witnesses += 1;
                    if gosdk_codes::is_decode_refusal(engine.name(), &side.native) {
                        decode_refusals += 1;
                    }
                    *abort_messages.entry(side.native.clone()).or_insert(0) += 1;
                } else {
                    undecided += 1;
                    *undecided_messages.entry(side.native.clone()).or_insert(0) += 1;
                }
            }
        }
        entries.push(e);
    }
    let banner = adapter.banner.clone();
    adapter.close();
    if let Some(d) = &dump {
        std::fs::write(
            d,
            dump_lines.join("\n") + if dump_lines.is_empty() { "" } else { "\n" },
        )
        .or_err("dump file")?;
    }

    // the witnesses
    let out_dir = format!("{witnesses_dir}/{}", engine.name());
    std::fs::create_dir_all(&out_dir).or_err("witnesses dir")?;
    let mut witness_lines: Vec<String> = Vec::new();
    let mut summary: Vec<serde_json::Value> = Vec::new();
    println!(
        "run_engine: {corpus_name}/{file_name} ({n} entries) vs {} ({}); the spec at {spec_key} ({config}); {} ({} CLI calls, {} distinct parameter triples); {:.1}s",
        engine_key, banner, oracle.source(), oracle.calls, oracle.table().len(), t0.elapsed().as_secs_f64()
    );
    for ((sh, uh, cons), w) in oracle.table() {
        println!("  word: spend {sh}, utxo {uh}, consensus {cons} -> 0x{w:X}");
    }
    let mut agree_line: Vec<String> = agree.iter().map(|(c, k)| format!("{c} {k}")).collect();
    if agree_line.is_empty() {
        agree_line.push("(none)".into());
    }
    println!(
        "  agree: {}; engine aborts filed as witnesses (D15) {aborts_as_witnesses} (decode refusals {decode_refusals}, R3; timeouts {timeouts}, of which {timeouts_rerun_decided} decided on the 10× re-run, D15a; process deaths {adapter_deaths}, of which {recovered_deaths} recovered in a fresh process); undecided runs (the adapter's own codes or no spec verdict, never a witness) {undecided}; the spec undefined-in-reference (Q7, reported, never counted) {undefined_in_reference}; without a spec verdict {no_spec}; engine codes/messages outside the tables {unknown_codes}; adapter errors {adapter_errors}",
        agree_line.join(", ")
    );
    if !unmapped_bits.is_empty() {
        println!(
            "  reference bits the engine has no flag for (reported per run, {} runs): {}",
            n,
            unmapped_bits
                .iter()
                .map(|(b, c)| format!("{b} ×{c}"))
                .collect::<Vec<_>>()
                .join(", ")
        );
    }
    println!("| column | rule | entries | ruling | witness | decided by |");
    println!("|---|---|---|---|---|---|");
    for ((column, rule), c) in &counts {
        let (_, we, a_v, b_v) = c.smallest.as_ref().or_err("c.smallest.as_ref()")?;
        let mut w = we.clone();
        w.id = format!(
            "witness-{}-{corpus_name}-{}-{rule}-{}",
            engine.name(),
            column.replace('/', "-"),
            we.id
        );
        let a_key = if column.ends_with("spec-mempool") || column == "spec-mempool" {
            mempool_key.clone()
        } else {
            spec_key.clone()
        };
        let b_key = if column.starts_with("default") {
            engine_default_key.clone()
        } else if column == "spec-mempool" {
            engine_mempool_key.clone()
        } else {
            engine_key.clone()
        };
        w.divergence = Some(Divergence {
            rule: rule.clone(),
            a: a_key.clone(),
            b: b_key.clone(),
            a_verdict: a_v.clone(),
            b_verdict: b_v.clone(),
            decided_by: c.explanation.decided_by.to_string(),
            ruling: c.explanation.ruling.to_string(),
            minimized: None,
            minimized_prevouts: None,
            note: format!("{} entries of {corpus_name} diverge under this rule in the {column} column against {}; this is the smallest (from {}). {}", c.n, engine.name(), we.id, c.explanation.note),
        });
        w.expect.insert(b_key.clone(), b_v.clone());
        w.expect.insert(a_key.clone(), a_v.clone());
        witness_lines.push(serde_json::to_string(&w).or_err("serde_json::to_string(&w)")?);
        println!(
            "| {column} | `{rule}` | {} | {} | `{}` | {} |",
            c.n, c.explanation.ruling, w.id, c.explanation.decided_by
        );
        summary.push(serde_json::json!({"column": column, "rule": rule, "entries": c.n, "ruling": c.explanation.ruling, "witness": w.id, "from": we.id, "decided_by": c.explanation.decided_by}));
    }
    if !code_notes.is_empty() {
        println!("  tier-2 notes (both invalid, the codes differ; never a divergence):");
        for ((column, sc, ec), k) in &code_notes {
            println!("    {column}: spec {sc} vs {} {ec}: {k}", engine.name());
        }
    }
    let out_path = format!("{out_dir}/{corpus_name}.jsonl");
    std::fs::write(
        &out_path,
        witness_lines.join("\n") + if witness_lines.is_empty() { "" } else { "\n" },
    )
    .or_err("witness file")?;
    let wsha = hex::encode(sha256(
        &std::fs::read(&out_path).or_err("std::fs::read(&out_path)")?,
    ));
    let man_path = format!("{out_dir}/manifest.json");
    let mut man: serde_json::Value = std::fs::read_to_string(&man_path)
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_else(|| serde_json::json!({}));
    let code_notes_json: Vec<serde_json::Value> = code_notes
        .iter()
        .map(
            |((c, s, e), k)| serde_json::json!({"column": c, "spec": s, "engine": e, "entries": k}),
        )
        .collect();
    man[&corpus_name] = serde_json::json!({
        "file": format!("{corpus_name}.jsonl"), "sha256": wsha, "witnesses": witness_lines.len(),
        "corpus": corpus_path, "spec": spec_key, "spec_config": config, "engine": engine_key, "adapter": banner, "adapter_timeout_s": bsv_script_harness::engines::adapter_timeout().as_secs(),
        "words": oracle.table().iter().map(|((sh, uh, c), w)| serde_json::json!({"spend_height": sh, "utxo_height": uh, "consensus": c, "word": w})).collect::<Vec<_>>(),
        "entries": n, "agree": agree, "undecided_runs": undecided, "aborts_as_witnesses": aborts_as_witnesses, "decode_refusals": decode_refusals, "abort_messages": abort_messages, "timeouts": timeouts, "timeouts_decided_on_the_10x_rerun": timeouts_rerun_decided, "adapter_timeout_rerun_s": bsv_script_harness::engines::adapter_timeout().as_secs() * 10, "adapter_deaths": adapter_deaths, "adapter_deaths_recovered_in_a_fresh_process": recovered_deaths, "undecided_messages": undecided_messages, "unknown_messages": unknown_messages,
        "unmapped_bits": unmapped_bits, "rules": summary, "code_notes": code_notes_json,
        "generated": std::env::var("SOURCE_DATE").unwrap_or_else(|_| "2026-09-23".into()),
    });
    std::fs::write(
        &man_path,
        serde_json::to_string_pretty(&man).or_err("serde_json::to_string_pretty(&man)")? + "\n",
    )
    .or_err("witness manifest")?;
    println!(
        "  witnesses: {} written to {out_path} (sha256 {wsha}); manifest {man_path}",
        witness_lines.len()
    );
    if !unknown_messages.is_empty() {
        println!(
            "  {} codes/messages outside the cited table (the table must grow, never guess):",
            engine.name()
        );
        for (m, c) in &unknown_messages {
            println!("    {c} × {m}");
        }
    }
    if !abort_messages.is_empty() {
        println!("  engine aborts filed as witnesses (D15: the spec decides the entry, the engine returned no verdict; never counted as undecided runs):");
        for (m, c) in &abort_messages {
            println!("    {c} × {m}");
        }
    }
    if !undecided_messages.is_empty() {
        println!("  undecided runs (the adapter's own codes or no spec verdict; never a witness):");
        for (m, c) in &undecided_messages {
            println!("    {c} × {m}");
        }
    }
    // record the engine's verdicts into the corpus
    if record {
        let text: String = entries
            .iter()
            .map(|e| serde_json::to_string(e).map(|l| l + "\n"))
            .collect::<Result<String, _>>()
            .or_err("corpus json")?;
        std::fs::write(&corpus_path, &text).or_err("rewrite corpus")?;
        let sha = hex::encode(sha256(text.as_bytes()));
        if let (Some(mp), Some(mut m)) = (manifest_path, manifest) {
            m.sha256 = sha.clone();
            m.implementations.retain(|i| {
                i.name != engine.name()
                    && i.name != format!("{}-mempool", engine.name())
                    && i.name != format!("{}-default", engine.name())
            });
            let mut cfg = BTreeMap::new();
            cfg.insert("mode".to_string(), serde_json::json!("under the reference's flag word of the entry's own params (the block word unless the entry gives one), the word asked of eval/bsvs (Params.derive), one run per input"));
            cfg.insert("adapter".to_string(), serde_json::json!(banner));
            m.implementations.push(ImplConfigJson {
                name: engine.name().into(),
                version: engine.version().into(),
                config: cfg.clone(),
            });
            cfg.insert("mode".to_string(), serde_json::json!("under the mempool word of the same configuration (Params.derive with consensus = false)"));
            m.implementations.push(ImplConfigJson {
                name: format!("{}-mempool", engine.name()),
                version: engine.version().into(),
                config: cfg.clone(),
            });
            if engine.has_default_mode() {
                cfg.insert("mode".to_string(), serde_json::json!("the SDK's default mode: no explicit word, its own derivation from the transaction version (Spend.ts #isRelaxed = version > 1)"));
                m.implementations.push(ImplConfigJson {
                    name: format!("{}-default", engine.name()),
                    version: engine.version().into(),
                    config: cfg,
                });
            }
            std::fs::write(
                &mp,
                serde_json::to_string_pretty(&m).or_err("serde_json::to_string_pretty(&m)")? + "\n",
            )
            .or_err("manifest")?;
            println!("  recorded {engine_key}, {engine_mempool_key}{} into {corpus_path}; new sha256 {sha} in {}", if engine.has_default_mode() { format!(", {engine_default_key}") } else { String::new() }, mp.display());
        } else {
            println!("  recorded into {corpus_path}; new sha256 {sha} (no manifest beside it)");
        }
    }
    let n_unexplained: u64 = counts
        .iter()
        .filter(|((_, r), _)| r == "unexplained")
        .map(|(_, c)| c.n)
        .sum();
    if n_unexplained > 0 || unknown_codes > 0 || adapter_errors > 0 || n == 0 {
        println!("run_engine: RED ({n_unexplained} unexplained divergences, {unknown_codes} codes outside the table, {adapter_errors} adapter errors)");
        println!(
            "  the unexplained classes (column | version | family | rule | spec | engine): count"
        );
        let mut hist: Vec<_> = unexplained_hist.iter().collect();
        hist.sort_by(|a, b| b.1.cmp(a.1));
        for (k, c) in hist.iter().take(60) {
            println!("    {c:6}  {k}");
        }
        for u in &unexplained {
            println!("  UNEXPLAINED {u}");
        }
        std::process::exit(1);
    }
    println!("run_engine: GREEN (every divergence explained by a rule with its citation)");
    Ok(())
}
