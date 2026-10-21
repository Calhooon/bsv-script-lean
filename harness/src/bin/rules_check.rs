//! rules_check (this repo's; D83c, #31; S3, set 4, 2026-09-26): THE OFFLINE GATE OF THE CLASSIFIER TABLES.
//!
//! The corpora carry every engine's recorded verdicts (`expect`, keyed `<engine>@<version>`) and the witness
//! manifests carry, per corpus × column × class, the count of divergent entries and the smallest one. So the
//! data classifier (`harness/rules/*.json`, read through `harness/src/rules.rs`) can be checked with NO engine
//! run: every entry is replayed from its recorded verdicts through the same column loop the drivers use
//! (`run_engine.rs` for the SDK engines; `run_diff.rs` for bsv-rs, whose two columns are two words the crate
//! runs live in-process, seconds for the whole corpus), and the per-class counts and the smallest witness are
//! compared with `corpus/witnesses/<engine>/manifest.json` (the SDKs) and `corpus/witnesses/manifest.json`
//! (bsv-rs), with each manifest row's `ruling` against its class's in the table (`decided_by` is not compared: the
//! tables' citations are re-cut after a record, the manifest keeps the record's text). Equal on every corpus of
//! those manifests, or RED naming the corpus, the column, the class and the two counts. A divergence the tables
//! leave unexplained is RED too. It joins `make check`'s harness leg. Since #57 the sv-node manifest also replays
//! offline, including the tx road's recorded combined gate/script verdicts and its separate BIP34-qualified
//! agreements. The policy-defaults manifest carries no classes. This is a regression check of the tables against
//! what they recorded (`harness/src/rules.rs`), not an independent ruling on their source interpretations.
//!
//! Run: cargo run --release --locked --bin rules_check [-- --root <repo root>] [--engine bsv-rs|go-sdk|ts-sdk|gobdk|sv-node]
//! (gobdk, the GoBDK shim's column, since 2026-09-27: replayed like the SDKs from its recorded verdicts once
//! `corpus/witnesses/gobdk/manifest.json` exists; skipped by name before that)

use std::collections::BTreeMap;
use std::io::BufRead;
use std::path::{Path, PathBuf};

use bsv_rs::script::ScriptFlags;
use bsv_script_harness::corpus::{Entry, Manifest};
use bsv_script_harness::engine::{run_tx_words, words_of, EngineConfig, Mode, Verdict};
use bsv_script_harness::rules::{self, RuleSet, UNEXPLAINED};
use bsv_script_harness::txraw::RawTx;
use bsv_script_harness::{bsvrs_codes, gosdk_codes, BSV_RS_KEY};

fn arg(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1).cloned())
}

#[derive(Default)]
struct Tally {
    n: u64,
    smallest: Option<(usize, String)>,
}

struct Replay {
    counts: BTreeMap<(String, String), Tally>,
    agree: BTreeMap<String, u64>,
    entries: u64,
}

fn note(
    counts: &mut BTreeMap<(String, String), Tally>,
    column: &str,
    class: &str,
    size: usize,
    id: &str,
) {
    let t = counts
        .entry((column.to_string(), class.to_string()))
        .or_default();
    t.n += 1;
    let better = match &t.smallest {
        None => true,
        Some((sz, _)) => size < *sz,
    };
    if better {
        t.smallest = Some((size, id.to_string()));
    }
}

/// A corpus file's bytes; a corpus committed gzipped (`<file>.gz` beside the path a manifest names, #49's
/// `corpus/cpp/replay`: the drivers ran on the plain file, the repository keeps it compressed) is read through
/// `gzip -dc`, no crate added.
#[allow(
    clippy::panic,
    reason = "a tripwire checker that writes nothing: a failure is its leg RED with the message"
)]
fn corpus_bytes(path: &Path) -> Vec<u8> {
    if path.exists() {
        return std::fs::read(path).unwrap_or_else(|e| panic!("{}: {e}", path.display()));
    }
    let gz = PathBuf::from(format!("{}.gz", path.display()));
    let out = std::process::Command::new("gzip")
        .arg("-dc")
        .arg(&gz)
        .output()
        .unwrap_or_else(|e| panic!("gzip -dc {}: {e}", gz.display()));
    if !out.status.success() {
        panic!(
            "{}: neither the file nor {} reads",
            path.display(),
            gz.display()
        );
    }
    out.stdout
}

#[allow(
    clippy::expect_used,
    clippy::unwrap_used,
    reason = "a tripwire checker that writes nothing: a failure is its leg RED with the message"
)]
fn read_entries(path: &Path) -> Vec<Entry> {
    let bytes = corpus_bytes(path);
    let mut out = Vec::new();
    for line in std::io::BufReader::new(&bytes[..]).lines() {
        let line = line.unwrap();
        if line.trim().is_empty() {
            continue;
        }
        let e: Entry = serde_json::from_str(&line).expect("entry");
        out.push(e);
    }
    out
}

/// The spec's two verdicts per entry: the recorded keys when the corpus carries them (`run_diff --record` writes
/// them into seven corpora), else the evaluator's own output (`eval/bsvs corpus`, exactly what the drivers read
/// through `--spec`; the bytes corpus is judged by the tripwire's `bytes` leg and carries no spec key).
#[allow(
    clippy::expect_used,
    clippy::panic,
    reason = "a tripwire checker that writes nothing: a failure is its leg RED with the message"
)]
fn spec_map(
    root: &Path,
    corpus_path: &Path,
    entries: &[Entry],
    spec_key: &str,
    mempool_key: &str,
) -> BTreeMap<
    String,
    (
        bsv_script_harness::corpus::ExpectJson,
        bsv_script_harness::corpus::ExpectJson,
    ),
> {
    let mut out = BTreeMap::new();
    for e in entries {
        if let (Some(a), Some(b)) = (e.expect.get(spec_key), e.expect.get(mempool_key)) {
            out.insert(e.id.clone(), (a.clone(), b.clone()));
        }
    }
    if !out.is_empty() {
        return out;
    }
    let tmp = std::env::temp_dir().join(format!("rules-check-spec-{}.jsonl", std::process::id()));
    let status = std::process::Command::new(root.join("eval").join("bsvs"))
        .arg("corpus")
        .arg(corpus_path)
        .arg("--out")
        .arg(&tmp)
        .current_dir(root)
        .stdout(std::process::Stdio::null())
        .status()
        .unwrap_or_else(|e| panic!("eval/bsvs corpus {}: {e}", corpus_path.display()));
    if !status.success() {
        panic!(
            "eval/bsvs corpus {} failed ({status})",
            corpus_path.display()
        );
    }
    let text = std::fs::read_to_string(&tmp).expect("the evaluator's output");
    let _ = std::fs::remove_file(&tmp);
    for line in text.lines() {
        if line.trim().is_empty() {
            continue;
        }
        let v: serde_json::Value = serde_json::from_str(line).expect("spec line");
        let id = v["id"].as_str().unwrap_or("").to_string();
        let mk = |x: &serde_json::Value| bsv_script_harness::corpus::ExpectJson {
            verdict: x["verdict"].as_str().unwrap_or("").to_string(),
            code: x["code"].as_str().map(|c| c.to_string()),
            reason: None,
            input: x["input"].as_u64().map(|i| i as usize),
        };
        out.insert(id, (mk(&v["spec"]), mk(&v["spec-mempool"])));
    }
    out
}

/// The SDK engines, offline: the recorded verdicts of `<engine>@v`, `<engine>-mempool@v` and (ts-sdk)
/// `<engine>-default@v` against the spec's, through the column loop of `run_engine.rs`.
#[allow(
    clippy::expect_used,
    reason = "a tripwire checker that writes nothing: a failure is its leg RED with the message"
)]
fn replay_sdk(
    rs: &RuleSet,
    entries: &[Entry],
    spec: &BTreeMap<
        String,
        (
            bsv_script_harness::corpus::ExpectJson,
            bsv_script_harness::corpus::ExpectJson,
        ),
    >,
    engine_key: &str,
    has_default: bool,
) -> Replay {
    let name = engine_key.split('@').next().unwrap_or("");
    let version = engine_key.split('@').nth(1).unwrap_or("");
    let engine_mempool_key = format!("{name}-mempool@{version}");
    let engine_default_key = format!("{name}-default@{version}");
    let mut counts: BTreeMap<(String, String), Tally> = BTreeMap::new();
    let mut agree: BTreeMap<String, u64> = BTreeMap::new();
    let mut n = 0u64;
    for e in entries {
        n += 1;
        let tx = RawTx::decode(&hex::decode(&e.tx).expect("tx hex")).expect("tx frame");
        let Some((sv_spec, sv_mp)) = spec.get(&e.id) else {
            continue;
        };
        let mut columns: Vec<(&str, &bsv_script_harness::corpus::ExpectJson, &str)> = vec![
            ("spec", sv_spec, engine_key),
            ("spec-mempool", sv_mp, engine_mempool_key.as_str()),
        ];
        if has_default {
            columns.push(("default/spec-mempool", sv_mp, engine_default_key.as_str()));
            columns.push(("default/spec", sv_spec, engine_default_key.as_str()));
        }
        for (column, sv, run_key) in columns {
            let Some(side) = e.expect.get(run_key) else {
                continue;
            };
            let native = side.reason.clone().unwrap_or_default();
            if sv.verdict == "unimplemented" {
                continue;
            }
            // the adapter's own failure is an undecided run, never classified; an SDK's decode refusal is not one: it is an
            // engine abort under D15 when the spec decides the entry (R3 on #32), classified as run_engine.rs classifies it
            if side.verdict == "undecided" && gosdk_codes::is_adapter_failure(name, &native) {
                continue;
            }
            // the reference's undecided run (a timeout; on the block road a coinbase's mempool column) is counted apart by
            // run_svnode and txroad and never classified (txroad.rs, the `side.kind == "undecided"` skip): the replay does the same
            if name == "sv-node" && side.verdict == "undecided" {
                continue;
            }
            if sv.verdict == "undefined-in-reference" {
                continue;
            }
            if sv.verdict == side.verdict {
                *agree.entry(column.to_string()).or_insert(0) += 1;
                continue;
            }
            let o = rules::observe(
                e,
                &tx,
                column,
                &sv.verdict,
                sv.code.as_deref(),
                &side.verdict,
                side.code.as_deref(),
                &native,
            )
            .with_spec_consensus(&sv_spec.verdict);
            let class = rs
                .explain(&o)
                .map(|x| x.rule)
                .unwrap_or_else(|| UNEXPLAINED.to_string());
            list_class(engine_key, column, &e.tx, &class, &e.id);
            note(&mut counts, column, &class, e.tx.len(), &e.id);
        }
    }
    Replay {
        counts,
        agree,
        entries: n,
    }
}

/// `RULES_CHECK_LIST=<file>` (#146): every classified divergent run appended as one tab-separated line, the engine key,
/// the column, the spend's txid, the class and the entry id, for the fixture export's loader proofs
/// (`harness/engines/go/fixtures`, `harness/engines/ts/fixtures.mjs`) to name a divergent row's class by the
/// classifier's own reading; unset, nothing is written.
#[allow(
    clippy::expect_used,
    reason = "a tripwire checker: a list file that cannot be written ends the run with the message"
)]
fn list_class(engine_key: &str, column: &str, tx_hex: &str, class: &str, id: &str) {
    use std::io::Write;
    let Ok(path) = std::env::var("RULES_CHECK_LIST") else {
        return;
    };
    let mut txid = bsv_script_harness::txraw::sha256d(&hex::decode(tx_hex).expect("tx hex"));
    txid.reverse();
    let mut f = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
        .expect("the RULES_CHECK_LIST file");
    writeln!(
        f,
        "{engine_key}\t{column}\t{}\t{class}\t{id}",
        hex::encode(txid)
    )
    .expect("a RULES_CHECK_LIST line");
}

/// The class of the crate's abort on an entry the spec decides, as `run_diff.rs`'s `abort_class` files it (D15 as
/// written, #42; #32's A-B2): a panic `engine.exception`, a resource wall `engine.resource-abort`, each before any row;
/// `None` when the run is no abort or the spec does not decide the entry. A class the table does not carry is the
/// open record (`RuleSet::record`): UNEXPLAINED and RED (`engine.exception` is not in `bsv-rs.json` today, and no
/// recorded bsv-rs verdict is a panic, so a panic on a decided entry turns the leg RED until its class is written).
fn abort_class(v: &Verdict, spec_verdict: &str) -> Option<&'static str> {
    if spec_verdict != "valid" && spec_verdict != "invalid" {
        return None;
    }
    match v {
        Verdict::Panic(_) => Some("engine.exception"),
        Verdict::Resource(_) => Some("engine.resource-abort"),
        _ => None,
    }
}

/// bsv-rs, live in-process (the crate is a library; the corpus takes seconds): the two words per input as
/// `run_diff.rs` derives them, the recorded spec keys, the column loop of `run_diff.rs` with its D15 abort branch
/// (`abort_class`: a resource wall or a panic on an entry the spec decides is a witness, never undecided).
#[allow(
    clippy::expect_used,
    clippy::panic,
    reason = "a tripwire checker that writes nothing: a failure is its leg RED with the message"
)]
fn replay_bsvrs(
    rs: &RuleSet,
    entries: &[Entry],
    spec_key: &str,
    mempool_key: &str,
    cfg: &EngineConfig,
) -> Replay {
    let mut counts: BTreeMap<(String, String), Tally> = BTreeMap::new();
    let mut agree: BTreeMap<String, u64> = BTreeMap::new();
    let mut n = 0u64;
    let prev_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(|_| {}));
    for e in entries {
        n += 1;
        let tx = RawTx::decode(&hex::decode(&e.tx).expect("tx hex")).expect("tx frame");
        let prevouts: Vec<_> = e
            .prevouts
            .iter()
            .map(|p| p.to_prevout().expect("prevout"))
            .collect();
        let heights: Vec<u32> = e.prevouts.iter().map(|p| p.height).collect();
        let words_block = words_of(e.params.spend_height, &heights, true);
        let words_std = words_of(e.params.spend_height, &heights, false);
        // the spec column's words as `run_diff.rs` takes them (`spec_words`): the entry's explicit `flags` when it
        // carries them (#49's `corpus/cpp/replay`), else the derived word of its `params.consensus`
        let words_spec: Vec<Option<ScriptFlags>> = match &e.flags {
            Some(f) => f
                .iter()
                .map(|&bits| {
                    Some(
                        ScriptFlags::from_bits(bits)
                            .unwrap_or_else(|err| panic!("{}: flags word 0x{bits:X}: {err}", e.id)),
                    )
                })
                .collect(),
            None => {
                if e.params.consensus {
                    words_block.clone()
                } else {
                    words_std.clone()
                }
            }
        };
        let (v_block, _) = run_tx_words(&tx, &prevouts, Mode::Native, cfg, &words_spec);
        let (v_std, _) = run_tx_words(&tx, &prevouts, Mode::Native, cfg, &words_std);
        let code_of = |v: &Verdict| -> Option<&'static str> {
            match v {
                Verdict::ErrorV(m) => bsvrs_codes::code_of(m).map(|r| r.code),
                Verdict::RejectFalse => Some("SCRIPT_ERR_EVAL_FALSE"),
                Verdict::Unparseable(_) => Some("SCRIPT_ERR_BAD_OPCODE"),
                _ => None,
            }
        };
        let (Some(sv_spec), Some(sv_mp)) = (e.expect.get(spec_key), e.expect.get(mempool_key))
        else {
            continue;
        };
        for (column, sv, v) in [("spec-mempool", sv_mp, &v_std), ("spec", sv_spec, &v_block)] {
            let abort = abort_class(v, &sv.verdict);
            if (v.kind() == "undecided" && abort.is_none()) || sv.verdict == "unimplemented" {
                continue;
            }
            if sv.verdict == "undefined-in-reference" {
                continue;
            }
            if sv.verdict == v.kind() {
                *agree.entry(column.to_string()).or_insert(0) += 1;
                continue;
            }
            let class = if let Some(c) = abort {
                rs.record(c).rule
            } else {
                let native = v.reason().unwrap_or_default();
                let o = rules::observe(
                    e,
                    &tx,
                    column,
                    &sv.verdict,
                    sv.code.as_deref(),
                    v.kind(),
                    code_of(v),
                    &native,
                );
                rs.explain(&o)
                    .map(|x| x.rule)
                    .unwrap_or_else(|| UNEXPLAINED.to_string())
            };
            note(&mut counts, column, &class, e.tx.len(), &e.id);
        }
    }
    std::panic::set_hook(prev_hook);
    Replay {
        counts,
        agree,
        entries: n,
    }
}

/// Compare a replay with the manifest's `rules` rows (column, rule, entries, from, ruling) and its agree counts.
fn compare(
    label: &str,
    rs: &RuleSet,
    r: &Replay,
    man_rules: &[serde_json::Value],
    man_agree: &BTreeMap<String, u64>,
) -> u64 {
    let mut red = 0u64;
    for row in man_rules {
        let rule = row["rule"].as_str().unwrap_or("");
        if rule == UNEXPLAINED {
            continue;
        }
        let recorded = row["ruling"].as_str().unwrap_or("");
        let table = rs
            .classes
            .get(rule)
            .map(|c| c.ruling.as_str())
            .unwrap_or("(no such class)");
        if recorded != table {
            red += 1;
            println!("  RED {label}: {} × `{rule}`: the manifest's ruling {recorded:?}, the table's {table:?}", row["column"].as_str().unwrap_or(""));
        }
    }
    let mut expected: BTreeMap<(String, String), (u64, String)> = BTreeMap::new();
    for row in man_rules {
        let k = (
            row["column"].as_str().unwrap_or("").to_string(),
            row["rule"].as_str().unwrap_or("").to_string(),
        );
        expected.insert(
            k,
            (
                row["entries"].as_u64().unwrap_or(0),
                row["from"].as_str().unwrap_or("").to_string(),
            ),
        );
    }
    for (k, t) in &r.counts {
        match expected.get(k) {
            Some((n, from)) => {
                if *n != t.n || t.smallest.as_ref().map(|s| s.1.as_str()) != Some(from.as_str()) {
                    red += 1;
                    println!("  RED {label}: {} × `{}`: the tables give {} (smallest {}), the manifest {} (smallest {from})", k.0, k.1, t.n, t.smallest.as_ref().map(|s| s.1.as_str()).unwrap_or("-"), n);
                }
            }
            None => {
                red += 1;
                println!("  RED {label}: {} × `{}`: the tables give {} (smallest {}), the manifest has no such row", k.0, k.1, t.n, t.smallest.as_ref().map(|s| s.1.as_str()).unwrap_or("-"));
            }
        }
        if k.1 == UNEXPLAINED {
            red += 1;
            println!(
                "  RED {label}: {} unexplained divergences in the {} column (smallest {})",
                t.n,
                k.0,
                t.smallest.as_ref().map(|s| s.1.as_str()).unwrap_or("-")
            );
        }
    }
    for (k, (n, _)) in &expected {
        if !r.counts.contains_key(k) {
            red += 1;
            println!(
                "  RED {label}: {} × `{}`: the manifest has {n}, the tables give none",
                k.0, k.1
            );
        }
    }
    for (col, n) in man_agree {
        let got = r.agree.get(col).copied().unwrap_or(0);
        if got != *n {
            red += 1;
            println!(
                "  RED {label}: agree in the {col} column: the replay {got}, the manifest {n}"
            );
        }
    }
    red
}

#[allow(
    clippy::expect_used,
    clippy::unwrap_used,
    reason = "a tripwire checker that writes nothing: a failure is its leg RED with the message"
)]
fn main() {
    let args: Vec<String> = std::env::args().collect();
    let root: PathBuf = arg(&args, "--root")
        .map(PathBuf::from)
        .or_else(|| {
            std::env::var("BSV_SCRIPT_LEAN_ROOT")
                .ok()
                .map(PathBuf::from)
        })
        .unwrap_or_else(|| {
            let here = std::env::current_dir().expect("cwd");
            if here.join("Cargo.toml").exists() && here.join("..").join("corpus").exists() {
                here.join("..").canonicalize().unwrap()
            } else {
                here
            }
        });
    // #145 is a separate on-demand signer column, not a verifier manifest replay.
    if args.iter().any(|a| a == "--signer") {
        use bsv_script_harness::engines::{GO_SDK_VERSION, TS_SDK_VERSION};
        for (engine, pin) in [
            ("go-sdk", GO_SDK_VERSION),
            ("ts-sdk", TS_SDK_VERSION),
            ("bsv-rs", bsv_script_harness::BSV_RS_VERSION),
        ] {
            if let Err(error) = bsv_script_harness::signer::load_rules(&root, engine, pin) {
                eprintln!("rules_check: RED [X] ({error})");
                std::process::exit(1);
            }
        }
        println!("rules_check: GREEN [X] (3 signer tables; pins, predicates, citations and named classes)");
        return;
    }
    let only = arg(&args, "--engine");
    let t0 = std::time::Instant::now();
    let mut red = 0u64;
    let mut corpora = 0u64;
    let mut entries_total = 0u64;
    let mut witnesses_total = 0u64;
    // the SDK engines, and the GoBDK shim (#28, D14; its driver is run_engine's too, 2026-09-27): an engine whose
    // manifest does not exist yet has recorded nothing, so it is skipped BY NAME (printed and never a pass)
    for engine in ["go-sdk", "ts-sdk", "gobdk"] {
        if only.as_deref().map(|o| o != engine).unwrap_or(false) {
            continue;
        }
        let man_path = root
            .join("corpus")
            .join("witnesses")
            .join(engine)
            .join("manifest.json");
        if !man_path.exists() {
            println!(
                "rules_check: {engine}: no manifest at {} yet (skipped by name, never a pass)",
                man_path.display()
            );
            continue;
        }
        let rs = RuleSet::load(&root, engine).unwrap_or_else(|e| {
            println!("rules_check: {e}");
            std::process::exit(1)
        });
        let man: serde_json::Value =
            serde_json::from_str(&std::fs::read_to_string(&man_path).expect("engine manifest"))
                .expect("manifest json");
        let has_default = engine == "ts-sdk";
        for (corpus, m) in man.as_object().expect("manifest object") {
            let corpus_path = root
                .join("harness")
                .join(m["corpus"].as_str().expect("corpus path"));
            let spec_key = m["spec"].as_str().expect("spec key").to_string();
            let mempool_key = spec_key.replacen("spec@", "spec-mempool@", 1);
            let engine_key = m["engine"].as_str().expect("engine key").to_string();
            let entries = read_entries(&corpus_path);
            let spec = spec_map(&root, &corpus_path, &entries, &spec_key, &mempool_key);
            let r = replay_sdk(&rs, &entries, &spec, &engine_key, has_default);
            let man_agree: BTreeMap<String, u64> = m["agree"]
                .as_object()
                .map(|o| {
                    o.iter()
                        .map(|(k, v)| (k.clone(), v.as_u64().unwrap_or(0)))
                        .collect()
                })
                .unwrap_or_default();
            let rows: Vec<serde_json::Value> = m["rules"].as_array().cloned().unwrap_or_default();
            let n_classes: u64 = rows
                .iter()
                .map(|x| x["entries"].as_u64().unwrap_or(0))
                .sum();
            let label = format!("{engine} on {corpus}");
            let bad = compare(&label, &rs, &r, &rows, &man_agree);
            let recorded = entries.iter().any(|e| e.expect.contains_key(&spec_key));
            println!("rules_check: {label}: {} entries replayed from {} (spec {spec_key}{}); {} divergent runs in {} classes; {}", r.entries, engine_key, if recorded { " recorded in the corpus" } else { " from eval/bsvs corpus, the corpus carrying no spec key" }, n_classes, rows.len(), if bad == 0 { "EQUAL to the manifest" } else { "RED" });
            red += bad;
            corpora += 1;
            entries_total += r.entries;
            witnesses_total += n_classes;
        }
    }
    // The reference, offline. #57 records the live comparison in its own keys, retaining the
    // ordinary spec keys used by the other engines' historical manifests. The tx road stores
    // the combined gate/script verdict and separates instance-qualified BIP34 agreements.
    if only.as_deref().map(|o| o == "sv-node").unwrap_or(true) {
        let rs = RuleSet::load(&root, "sv-node").unwrap_or_else(|err| {
            eprintln!("rules_check: {err}");
            std::process::exit(1);
        });
        let man_path = root.join("corpus/witnesses/sv-node/manifest.json");
        let man: serde_json::Value =
            serde_json::from_str(&std::fs::read_to_string(&man_path).expect("node manifest"))
                .expect("manifest json");
        for (corpus, m) in man.as_object().expect("node manifest object") {
            let corpus_path = root
                .join("harness")
                .join(m["corpus"].as_str().expect("corpus path"));
            let mut entries = read_entries(&corpus_path);
            // the block road runs its entries by spend-height group, ascending, file order inside a group (txroad.rs `groups`),
            // and keeps the earliest of equal size as a class's smallest witness: the replay walks them in the same order
            if m["mode"]
                .as_str()
                .map(|s| s.starts_with("block-connect"))
                .unwrap_or(false)
            {
                entries.sort_by_key(|e| e.params.spend_height);
            }
            let spec_key = m["spec_recorded_keys"]["spec"]
                .as_str()
                .unwrap_or_else(|| m["spec"].as_str().expect("spec key"));
            let fallback_mp = spec_key.replacen("spec@", "spec-mempool@", 1);
            let mp_key = m["spec_recorded_keys"]["spec-mempool"]
                .as_str()
                .unwrap_or(&fallback_mp);
            let engine_key = m["node"].as_str().expect("node key");
            let spec = spec_map(&root, &corpus_path, &entries, spec_key, mp_key);
            let mut r = replay_sdk(&rs, &entries, &spec, engine_key, false);
            let label = format!("sv-node on {corpus}");
            let mut bad = 0;
            if m["spec_recorded_keys"].is_object()
                && (spec.len() != entries.len()
                    || entries.iter().any(|e| {
                        !e.expect.contains_key(engine_key)
                            || !e.expect.contains_key(&engine_key.replacen(
                                "sv-node@",
                                "sv-node-mempool@",
                                1,
                            ))
                    }))
            {
                bad += 1;
                println!("  RED {label}: the recording does not cover every entry and both node/spec columns");
            }
            if m["mode"]
                .as_str()
                .map(|s| s.starts_with("block-connect"))
                .unwrap_or(false)
            {
                let mut qualified = Vec::new();
                for e in &entries {
                    let tx = RawTx::decode(&hex::decode(&e.tx).expect("tx hex")).expect("tx frame");
                    if let (Some((sv, _)), Some(node)) = (spec.get(&e.id), e.expect.get(engine_key))
                    {
                        if sv.verdict == node.verdict
                            && bsv_script_harness::txroad::bip34_qualified(
                                &tx,
                                e.params.spend_height,
                                &node.verdict,
                            )
                        {
                            *r.agree.entry("spec".into()).or_insert(0) -= 1;
                            qualified.push(serde_json::json!({"id": e.id, "column": "spec", "verdict": node.verdict, "rule": "bip34"}));
                        }
                    }
                }
                let recorded = m["instance_qualified"]
                    .as_array()
                    .cloned()
                    .unwrap_or_default();
                let recorded_count = m["agree_instance_qualified"]["spec"].as_u64().unwrap_or(0);
                if qualified != recorded || qualified.len() as u64 != recorded_count {
                    bad += 1;
                    println!("  RED {label}: BIP34 instance-qualified agreements differ from the manifest");
                }
            }
            let man_agree: BTreeMap<String, u64> = m["agree"]
                .as_object()
                .map(|o| {
                    o.iter()
                        .map(|(k, v)| (k.clone(), v.as_u64().unwrap_or(0)))
                        .collect()
                })
                .unwrap_or_default();
            let rows = m["rules"].as_array().cloned().unwrap_or_default();
            let n_classes: u64 = rows
                .iter()
                .map(|x| x["entries"].as_u64().unwrap_or(0))
                .sum();
            bad += compare(&label, &rs, &r, &rows, &man_agree);
            if r.entries != m["entries"].as_u64().unwrap_or(0) {
                bad += 1;
                println!("  RED {label}: entry count differs from the manifest");
            }
            println!("rules_check: {label}: {} entries replayed from {engine_key} against {spec_key}; {n_classes} divergent runs in {} classes; {}", r.entries, rows.len(), if bad == 0 { "EQUAL to the manifest" } else { "RED" });
            red += bad;
            corpora += 1;
            entries_total += r.entries;
            witnesses_total += n_classes;
        }
    }
    // bsv-rs, live
    if only.as_deref().map(|o| o == "bsv-rs").unwrap_or(true) {
        let rs = RuleSet::load(&root, "bsv-rs").unwrap_or_else(|e| {
            println!("rules_check: {e}");
            std::process::exit(1)
        });
        let man_path = root.join("corpus").join("witnesses").join("manifest.json");
        let man: serde_json::Value =
            serde_json::from_str(&std::fs::read_to_string(&man_path).expect("bsv-rs manifest"))
                .expect("manifest json");
        for (corpus, m) in man.as_object().expect("manifest object") {
            let corpus_path = root
                .join("harness")
                .join(m["corpus"].as_str().expect("corpus path"));
            let spec_key = m["spec"].as_str().expect("spec key").to_string();
            let mempool_key = spec_key.replacen("spec@", "spec-mempool@", 1);
            let dir = corpus_path.parent().unwrap().to_path_buf();
            let file_name = corpus_path
                .file_name()
                .unwrap()
                .to_string_lossy()
                .to_string();
            let mp = [dir.join("manifest.json"), dir.join("cases-manifest.json")]
                .into_iter()
                .find(|p| {
                    p.exists()
                        && std::fs::read_to_string(p)
                            .map(|s| s.contains(&format!("\"{file_name}\"")))
                            .unwrap_or(false)
                })
                .expect("corpus manifest");
            let cm: Manifest =
                serde_json::from_str(&std::fs::read_to_string(&mp).expect("manifest"))
                    .expect("manifest json");
            let cfg = cm
                .implementations
                .iter()
                .find(|i| i.name == "bsv-rs")
                .map(|i| EngineConfig::from_json(&i.config))
                .unwrap_or_default();
            let entries = read_entries(&corpus_path);
            let r = replay_bsvrs(&rs, &entries, &spec_key, &mempool_key, &cfg);
            let mut man_agree: BTreeMap<String, u64> = BTreeMap::new();
            man_agree.insert("spec".into(), m["agree_block"].as_u64().unwrap_or(0));
            man_agree.insert(
                "spec-mempool".into(),
                m["agree_mempool"].as_u64().unwrap_or(0),
            );
            let rows: Vec<serde_json::Value> = m["rules"].as_array().cloned().unwrap_or_default();
            let n_classes: u64 = rows
                .iter()
                .map(|x| x["entries"].as_u64().unwrap_or(0))
                .sum();
            let label = format!("bsv-rs on {corpus}");
            let bad = compare(&label, &rs, &r, &rows, &man_agree);
            println!("rules_check: {label}: {} entries run live under the two words ({BSV_RS_KEY}; spec {spec_key}); {} divergent runs in {} classes; {}", r.entries, n_classes, rows.len(), if bad == 0 { "EQUAL to the manifest" } else { "RED" });
            red += bad;
            corpora += 1;
            entries_total += r.entries;
            witnesses_total += n_classes;
        }
    }
    println!(
        "rules_check: {} ({corpora} corpus × engine manifests, {entries_total} entries replayed, {witnesses_total} divergent runs classified; {} s)",
        if red == 0 { "GREEN (the tables reproduce the classes, counts, smallest witnesses and rulings of the go-sdk, ts-sdk, gobdk, sv-node and bsv-rs manifests; policy-defaults has no classifier rows)" } else { "RED" },
        t0.elapsed().as_secs()
    );
    if red > 0 {
        std::process::exit(1);
    }
}
