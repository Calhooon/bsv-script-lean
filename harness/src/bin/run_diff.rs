//! run_diff (this repo's; #15): the differential of the spec's evaluator against
//! bsv-rs on a corpus, every divergence a witness with its rule.
//!
//! Inputs: a corpus file (`docs/DESIGN.md` §6) and the spec's verdicts for it
//! (`eval/bsvs corpus <file> --out <spec.jsonl>`: per entry `spec` = the verdict
//! under the entry's own `params`, `spec-mempool` = under the mempool word of the
//! same node configuration; `lean/Bsvs/Main.lean` `entryVerdicts`). bsv-rs (the pinned
//! crate: `BSV_RS_VERSION` in `harness/src/lib.rs`, `docs/PROVENANCE.md` §1a; #24's engine leg)
//! is run LIVE on every entry THREE times: under the manifest's recorded
//! configuration (the recorded-verdict check), under the entry's OWN word for the
//! `spec` column (`spec_words`, #32's third lens: the entry's explicit `flags[i]` when it
//! carries `flags`, as `eval/bsvs corpus` and `run_engine` honour them, an unknown bit being
//! a hard error; else the reference's word of the entry's era for its `params.consensus`:
//! the BLOCK word, `ScriptFlags::block(era)`, `verify_script_flags.cpp:32–81` with
//! `policy.h:226–245`, transcribed in the crate, what a mining node decides, when
//! `consensus` is true, as on every entry of the corpora of `make diff`; the STANDARD word
//! otherwise) and under the reference's STANDARD word of that era
//! (`ScriptFlags::standard(era)`, `verify_script_flags.cpp:11–30`: the
//! `spec-mempool` column, the like-for-like comparison, which never reads `flags`, as the
//! CLI's mempool column never does); a word not given explicitly is derived PER
//! INPUT from the entry's `params.spend_height` and the prevout's `height`
//! (`engine::word_for`, #20: the spend's era selects the word, the coin's era its
//! Chronicle marker, `policy.h:235–242`; a pre-Genesis spend or coin has no word
//! in bsv-rs, which "implements the post-Genesis rule set only", `flags.rs`: such
//! an input is `NotApplicable`, the corpus's `undecided`, reported and never
//! counted). Its message is mapped to the reference's `SCRIPT_ERR_*` name through
//! the cited table (`bsvrs_codes.rs`).
//!
//! Every tier-1 divergence (validity) is classified by the rows of
//! `harness/rules/bsv-rs.json` (THE CLASSIFIER AS DATA since D83c, #31, 2026-09-26: read
//! through `harness/src/rules.rs`, this driver's one touch) from the entry's own
//! `rule`/`family`, the shapes of its scripts and the two codes; a divergence no row
//! explains is UNEXPLAINED and the run is RED.
//! A bsv-rs ABORT on an entry the spec decides (valid or invalid) is a WITNESS, filed
//! before any row (`abort_class`; D15 as written, ruled 2026-09-24 on #42: an engine's
//! abort on an input the reference decides is a witness, never an undecided run; DESIGN
//! §2.1): a RESOURCE abort (its local memory budget, `Verdict::Resource`) under
//! `engine.resource-abort`, a PANIC of the crate (`Verdict::Panic`, caught by
//! `engine::run_input`) under `engine.exception` (#32's third lens: a panic was skipped as
//! undecided until then); `undecided` remains for a pre-Genesis input (NotApplicable) and for
//! an abort on an entry the spec does not decide (no spec verdict, or one other than valid
//! or invalid); an entry's column is a witness or undecided, never
//! both. Before 0.3.26 bsv-rs had no flag word and the two columns
//! ran the same default mode (`spend.rs:190–192` at 0.3.24): the rules
//! `flags.policy-as-consensus`, `flags.version-gate.*`, `flags.sigpushonly` and
//! `flags.discourage-upgradable-nops` were that mode's; under the words they are
//! expected empty (the witnesses of #15, re-recorded here).
//!
//! Outputs: `<witnesses>/<corpus>.jsonl` (one witness per corpus × column ×
//! rule: the smallest divergent entry, its `expect` carrying the spec's keys and
//! a `divergence` record), `<witnesses>/manifest.json` (the counts), and the
//! report table on stdout (the state page quotes it). With `--record` the spec's
//! verdicts are written into the corpus entries (`spec@<commit>`,
//! `spec-mempool@<commit>`; older `spec@*` keys removed) and the manifest's
//! sha256 re-stamped. A stamp no commit names (`spec@<commit>+dirty`,
//! `spec@unknown`) is refused, exit 2, before anything is written, under
//! `--record` or with the witnesses under `corpus/` (lean #32, B-4). Every corpus
//! entry needs its spec line: an id the spec does not cover is RED, exit 1, before
//! anything is written (`uncovered`; #32's final lens on Lean B, NEW-1: until then
//! such an entry was skipped, the run could read GREEN, and `--record` rewrote the
//! corpus without it).
//!
//! Run: cargo run --release --bin run_diff -- --corpus ../corpus/seed/seed.jsonl --spec <spec.jsonl> [--witnesses ../corpus/witnesses] [--record]

use std::collections::BTreeMap;
use std::io::BufRead;

use bsv_rs::primitives::hash::sha256;
use bsv_rs::script::{ProtocolEra, ScriptFlags};
use bsv_script_harness::bsvrs_codes;
use bsv_script_harness::corpus::{Divergence, Entry, ExpectJson, ImplConfigJson};
use bsv_script_harness::differential::{
    read_spec, spec_json as spec_json_of, CorpusInput, SpecLine,
};
use bsv_script_harness::engine::{run_tx, run_tx_words, words_of, EngineConfig, Mode, Verdict};
use bsv_script_harness::fail::OrErr;
use bsv_script_harness::rules::{self, Explanation, RuleSet};
use bsv_script_harness::stamp::{stamp_form, Stamp};
use bsv_script_harness::txraw::RawTx;
use bsv_script_harness::BSV_RS_KEY;

fn arg(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1).cloned())
}

fn verdict_json_of(v: &Verdict, i: Option<usize>, code: Option<&str>) -> ExpectJson {
    ExpectJson {
        verdict: v.kind().to_string(),
        code: code.map(|c| c.to_string()),
        reason: v.reason(),
        input: i,
    }
}

/// The spec column's word per input (#32's third lens, A-P7): the column honours the entry, as `eval/bsvs corpus`
/// (`lean/Bsvs/Main.lean` `entryVerdicts`) and `run_engine` do. The entry's explicit word `flags[i]` when it carries
/// `flags` (`ScriptFlags::from_bits`: a bit the crate does not know is an error, never a silent skip), else the
/// derived word of its own `params.consensus`: the block word when true, the standard word otherwise. The
/// like-for-like column never reads `flags`.
fn spec_words(
    flags: Option<&[u32]>,
    consensus: bool,
    words_block: &[Option<ScriptFlags>],
    words_std: &[Option<ScriptFlags>],
) -> Result<Vec<Option<ScriptFlags>>, String> {
    match flags {
        Some(f) => f
            .iter()
            .map(|&bits| {
                ScriptFlags::from_bits(bits)
                    .map(Some)
                    .map_err(|err| format!("flags word 0x{bits:X}: {err}"))
            })
            .collect(),
        None => Ok(if consensus {
            words_block.to_vec()
        } else {
            words_std.to_vec()
        }),
    }
}

/// The class of the crate's abort on an entry the spec decides (D15 as written, #42; #32's third lens, A-B2): a
/// panic is `engine.exception`, a resource wall `engine.resource-abort`, each filed before any row of the table;
/// `None` when the run is no abort or the spec does not decide the entry (valid or invalid).
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

/// The column's stamps against the forms `eval/bsvs` emits (lean #32's applied lens, `bsv_script_harness::stamp`):
/// an empty, spaced or arbitrary commit names no commit, so the B-4 check below counts it with `+dirty` and `unknown`
/// and names it after its report (the owner's P5, 2026-10-05); `None` when every line's commit is in an emitted form.
fn stamp_form_error<'a>(commits: impl IntoIterator<Item = &'a str>) -> Option<String> {
    commits.into_iter().find_map(|c| stamp_form(c).err())
}

/// The corpus ids the spec's lines do not cover (#32's final lens on Lean B, NEW-1): every entry needs its spec
/// line, or a run without one would read GREEN on an entry it never compared and `--record` would rewrite the corpus
/// without it. A missing id is RED before anything is written (`main`); a line the corpus does not carry is no gap.
fn uncovered(corpus: &[u8], spec: &BTreeMap<String, SpecLine>) -> Result<Vec<String>, String> {
    #[derive(serde::Deserialize)]
    struct Id {
        id: String,
    }
    corpus
        .split(|&b| b == b'\n')
        .filter(|l| !l.iter().all(u8::is_ascii_whitespace))
        .map(|l| {
            serde_json::from_slice::<Id>(l)
                .map(|i| i.id)
                .or_err("entry")
        })
        .filter(|id| id.as_ref().map_or(true, |id| !spec.contains_key(id)))
        .collect()
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
            eprintln!("run_diff: {e}");
            std::process::ExitCode::from(1)
        }
    }
}

fn run() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();
    let corpus_path = arg(&args, "--corpus").or_err("--corpus <file.jsonl>")?;
    let spec_path = arg(&args, "--spec").or_err("--spec <spec.jsonl> (from `eval/bsvs corpus`)")?;
    let witnesses_dir = arg(&args, "--witnesses").unwrap_or_else(|| "../corpus/witnesses".into());
    let record = args.iter().any(|a| a == "--record");

    let CorpusInput {
        file_name,
        corpus_name,
        bytes,
        manifest_path,
        manifest,
    } = CorpusInput::load(std::path::Path::new(&corpus_path)).unwrap_or_else(|e| {
        eprintln!("run_diff: {e}");
        std::process::exit(1);
    });
    let mut cfg = EngineConfig::default();
    if let Some(m) = &manifest {
        if let Some(imp) = m.implementations.iter().find(|i| i.name == "bsv-rs") {
            cfg = EngineConfig::try_from_json(&imp.config)?;
        }
    }
    let spec = read_spec(std::path::Path::new(&spec_path)).unwrap_or_else(|e| {
        eprintln!("run_diff: {e}");
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
    // THE CLASSIFIER AS DATA (D83c, #31; 2026-09-26): bsv-rs's table under harness/rules/, this driver's one touch
    let root: std::path::PathBuf = match std::env::var("BSV_SCRIPT_LEAN_ROOT") {
        Ok(r) => std::path::PathBuf::from(r),
        Err(_) => {
            let here = std::env::current_dir().or_err("cwd")?;
            if here.join("Cargo.toml").exists() && here.join("..").join("corpus").exists() {
                here.join("..")
                    .canonicalize()
                    .or_err("here.join('..').canonicalize()")?
            } else {
                here
            }
        }
    };
    // lean #32's second lens, B-4, and its re-lens: a record names the sources its verdicts came from, so a stamp no
    // commit names (`+dirty`: `lean/` had uncommitted changes; `unknown`: no HEAD at the root, or the binary run
    // without the wrapper; `eval/bsvs`) never reaches the
    // corpus, neither its entries (`--record`) nor its witnesses (a directory under `corpus/`, read on the path
    // itself, component by component as the run would make it, so neither a directory not made yet nor a `..` after
    // one slips out; its re-lens 2, B-4, and 3, B3N-5)
    let into_corpus = {
        let p = std::path::Path::new(&witnesses_dir);
        let abs = if p.is_absolute() {
            p.to_path_buf()
        } else {
            std::env::current_dir()
                .map(|c| c.join(p))
                .unwrap_or_else(|_| p.to_path_buf())
        };
        // component by component, as the run would make the directory: an existing prefix resolved by the file system
        // (its symlinks and `..` physically), a part not made yet lexically (a `..` there pops a directory the run would
        // make), so neither a directory not made yet nor a `..` after one slips out (re-lens 3, B3N-5)
        let mut cur = std::path::PathBuf::new();
        for c in abs.components() {
            match c {
                std::path::Component::CurDir => {}
                std::path::Component::ParentDir if !cur.exists() => {
                    cur.pop();
                }
                c => {
                    cur.push(c.as_os_str());
                    if let Ok(real) = cur.canonicalize() {
                        cur = real;
                    }
                }
            }
        }
        root.join("corpus")
            .canonicalize()
            .map(|c| cur.starts_with(c))
            .unwrap_or(false)
    };
    // every line's commit, so a hand-merged column whose first entry is clean is refused too (its fourth re-lens, B4N-4)
    let commits: std::collections::BTreeSet<&str> =
        spec.values().map(|s| s.commit.as_str()).collect();
    if (commits.len() > 1 || stamp_form(&commit) != Ok(Stamp::Commit)) && (record || into_corpus) {
        let named = if commits.is_empty() {
            commit.clone()
        } else {
            commits.iter().cloned().collect::<Vec<_>>().join(", spec@")
        };
        let form = stamp_form_error(commits.iter().copied())
            .map(|e| format!("; {e}"))
            .unwrap_or_default();
        eprintln!("run_diff: refusing to write spec@{named} into the corpus (a stamp no commit names, or several: lean/ uncommitted, no HEAD at the root, the binary run without the wrapper, a merged column, or no readable spec line); commit the Lean sources, rebuild, and run again (lean #32, B-4){form}");
        std::process::exit(2);
    }
    let rules_table = match RuleSet::load(&root, "bsv-rs") {
        Ok(r) => r,
        Err(e) => {
            eprintln!("run_diff: {e}");
            std::process::exit(1);
        }
    };

    // coverage before anything is written (NEW-1): an entry without its spec line is compared by nobody
    let missing = uncovered(&bytes, &spec)?;
    if !missing.is_empty() {
        let shown: Vec<&str> = missing.iter().take(10).map(String::as_str).collect();
        println!("run_diff: RED ({} corpus entries without a spec line, e.g. {}; nothing written: run `eval/bsvs corpus` on this corpus file and pass its output)", missing.len(), shown.join(", "));
        std::process::exit(1);
    }

    let prev_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(|_| {}));
    let t0 = std::time::Instant::now();
    let mut entries: Vec<Entry> = Vec::new();
    let (
        mut n,
        mut no_spec,
        mut recorded_disagree,
        mut undecided,
        mut unknown_msg,
        mut not_applicable,
    ) = (0u64, 0u64, 0u64, 0u64, 0u64, 0u64);
    let mut aborts: u64 = 0; // D15: the crate's aborts (a resource wall, a panic) on an entry the spec decides, filed as witnesses (never undecided)
    let mut unknown_messages: BTreeMap<String, u64> = BTreeMap::new();
    let mut counts: BTreeMap<(String, String), Count> = BTreeMap::new(); // (column, rule)
    let mut agree: BTreeMap<String, u64> = BTreeMap::new();
    let mut unexplained: Vec<String> = Vec::new();
    let mut undefined_in_reference: u64 = 0;
    for line in std::io::BufReader::new(&bytes[..]).lines() {
        let line = line.or_err("line")?;
        if line.trim().is_empty() {
            continue;
        }
        let mut e: Entry = serde_json::from_str(&line).or_err("entry")?;
        e.check().or_err("a corpus entry must be well-formed")?;
        n += 1;
        let tx = RawTx::decode(&hex::decode(&e.tx).or_err("tx hex")?).or_err("tx frame")?;
        let prevouts: Vec<_> = e
            .prevouts
            .iter()
            .map(|p| p.to_prevout().or_err("prevout"))
            .collect::<Result<_, _>>()?;
        // the per-input words of the entry (engine::word_for, #20): the block word and the standard word of the
        // spend's era with the coin's Chronicle marker; a pre-Genesis spend or coin is NotApplicable. The spec column
        // runs the entry's own (`spec_words`: its explicit `flags` when given, else the word of its `params.consensus`),
        // the like-for-like column the standard word
        let heights: Vec<u32> = e.prevouts.iter().map(|p| p.height).collect();
        let words_block = words_of(e.params.spend_height, &heights, true);
        let words_std = words_of(e.params.spend_height, &heights, false);
        if words_block.iter().any(|w| w.is_none()) {
            not_applicable += 1;
        }
        let words_spec = match spec_words(
            e.flags.as_deref(),
            e.params.consensus,
            &words_block,
            &words_std,
        ) {
            Ok(w) => w,
            Err(err) => {
                eprintln!("run_diff: {}: {err}", e.id);
                std::process::exit(1);
            }
        };
        // the recorded-verdict check under the manifest's configuration
        let (v_rec, _) = if cfg.per_input_words {
            run_tx_words(
                &tx,
                &prevouts,
                Mode::Native,
                &cfg,
                if e.params.consensus {
                    &words_block
                } else {
                    &words_std
                },
            )
        } else {
            run_tx(&tx, &prevouts, Mode::Native, &cfg)
        };
        if let Some(x) = e.expect.get(BSV_RS_KEY) {
            if x.verdict != v_rec.kind() || x.reason != v_rec.reason() {
                recorded_disagree += 1;
            }
        }
        let (v_block, i_block) = run_tx_words(&tx, &prevouts, Mode::Native, &cfg, &words_spec);
        let (v_std, i_std) = run_tx_words(&tx, &prevouts, Mode::Native, &cfg, &words_std);
        let mut code_of = |v: &Verdict| -> Option<&'static str> {
            match v {
                Verdict::ErrorV(m) => match bsvrs_codes::code_of(m) {
                    Some(r) => Some(r.code),
                    None => {
                        unknown_msg += 1;
                        *unknown_messages.entry(m.clone()).or_insert(0) += 1;
                        None
                    }
                },
                Verdict::RejectFalse => Some("SCRIPT_ERR_EVAL_FALSE"),
                Verdict::Unparseable(_) => Some("SCRIPT_ERR_BAD_OPCODE"),
                _ => None,
            }
        };
        let code_block = code_of(&v_block);
        let code_std = code_of(&v_std);
        let Some(s) = spec.get(&e.id) else {
            if v_block.kind() == "undecided" || v_std.kind() == "undecided" {
                undecided += 1;
            }
            no_spec += 1;
            entries.push(e); // unreachable after the coverage gate; an entry is never dropped from a rewrite
            continue;
        };
        // D15 (2026-09-24, #42), as written: the crate's abort on an entry the spec decides (a resource wall or a panic,
        // `abort_class`) is a witness, never undecided
        let abort_block = abort_class(&v_block, &s.spec.verdict);
        let abort_std = abort_class(&v_std, &s.spec_mempool.verdict);
        if (v_block.kind() == "undecided" && abort_block.is_none())
            || (v_std.kind() == "undecided" && abort_std.is_none())
        {
            undecided += 1;
        }
        if record {
            let stale: Vec<String> = e
                .expect
                .keys()
                .filter(|k| k.starts_with("spec@") || k.starts_with("spec-mempool@"))
                .cloned()
                .collect();
            for k in stale {
                e.expect.remove(&k);
            }
            e.expect.insert(spec_key.clone(), spec_json_of(&s.spec));
            e.expect
                .insert(mempool_key.clone(), spec_json_of(&s.spec_mempool));
        }
        for (column, sv, v, i, bsv_code, abort) in [
            (
                "spec-mempool",
                &s.spec_mempool,
                &v_std,
                i_std,
                code_std,
                abort_std,
            ),
            ("spec", &s.spec, &v_block, i_block, code_block, abort_block),
        ] {
            if (v.kind() == "undecided" && abort.is_none()) || sv.verdict == "unimplemented" {
                continue;
            }
            if sv.verdict == "undefined-in-reference" {
                // A reserved verdict kind, reported here and never counted as agreement or divergence.
                // The earlier reading is withheld at the maintainers request, group d8-node-team-discretion.
                undefined_in_reference += 1;
                continue;
            }
            if sv.verdict == v.kind() {
                *agree.entry(column.to_string()).or_insert(0) += 1;
                continue;
            }
            let ex = if let Some(class) = abort {
                aborts += 1;
                // the class naming the abort's mechanism, before any row (`harness/rules/bsv-rs.json`; a class the table
                // lacks is the open record: UNEXPLAINED and RED)
                rules_table.record(class)
            } else {
                rules_table
                    .explain(&rules::observe(
                        &e,
                        &tx,
                        column,
                        &sv.verdict,
                        sv.code.as_deref(),
                        if matches!(v, Verdict::Resource(_)) {
                            "resource"
                        } else {
                            v.kind()
                        },
                        bsv_code,
                        &v.reason().unwrap_or_default(),
                    ))
                    .unwrap_or_else(|| rules_table.record(rules::UNEXPLAINED))
            };
            if ex.rule == "unexplained" && unexplained.len() < 20 {
                unexplained.push(format!(
                    "{column} {} ({}, rule {}, version {}): spec {}{} vs bsv-rs {} {:?}",
                    e.id,
                    e.family,
                    e.rule,
                    tx.version,
                    sv.verdict,
                    sv.code
                        .as_ref()
                        .map(|c| format!(" {c}"))
                        .unwrap_or_default(),
                    v.kind(),
                    v.reason()
                ));
            }
            let key = (column.to_string(), ex.rule.to_string());
            let size = e.tx.len();
            let a_v = spec_json_of(sv);
            let b_v = verdict_json_of(v, i, bsv_code);
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
        entries.push(e);
    }
    std::panic::set_hook(prev_hook);

    // the witnesses
    std::fs::create_dir_all(&witnesses_dir).or_err("witnesses dir")?;
    let mut witness_lines: Vec<String> = Vec::new();
    let mut summary: Vec<serde_json::Value> = Vec::new();
    println!("run_diff: {corpus_name}/{file_name} ({n} entries) vs bsv-rs {} (the recorded configuration {cfg:?}; the spec column under the entry's own word per input (its explicit flags when it carries them, else engine::word_for with its params.consensus: the block word when consensus), the spec-mempool column under the standard word per input (engine::word_for, never the entry's flags), from the entry's spend height and the coin's height; entries with a pre-Genesis spend or coin, not applicable to bsv-rs (undecided): {not_applicable}); the spec at {spec_key} ({config}); {:.1}s", bsv_script_harness::BSV_RS_VERSION, t0.elapsed().as_secs_f64());
    println!("  agree: spec-mempool {} (like-for-like, the standard word), spec {} (the entry's own params: the block word when consensus); bsv-rs undecided {undecided} (a pre-Genesis input, or an abort on an entry the spec does not decide); aborts filed as witnesses (D15: `engine.resource-abort`, `engine.exception`) {aborts}; the spec undefined-in-reference (Q7, reported, never counted) {undefined_in_reference}; without a spec verdict {no_spec}; recorded bsv-rs verdicts disagreeing with the live run {recorded_disagree}; bsv-rs messages outside the table {unknown_msg}",
        agree.get("spec-mempool").copied().unwrap_or(0), agree.get("spec").copied().unwrap_or(0));
    println!("| column | rule | entries | ruling | witness | decided by |");
    println!("|---|---|---|---|---|---|");
    for ((column, rule), c) in &counts {
        let (_, we, a_v, b_v) = c.smallest.as_ref().or_err("c.smallest.as_ref()")?;
        let mut w = we.clone();
        w.id = format!("witness-{corpus_name}-{column}-{rule}-{}", we.id);
        w.divergence = Some(Divergence {
            rule: rule.clone(),
            a: if column == "spec" { spec_key.clone() } else { mempool_key.clone() },
            b: BSV_RS_KEY.to_string(),
            a_verdict: a_v.clone(),
            b_verdict: b_v.clone(),
            decided_by: c.explanation.decided_by.to_string(),
            ruling: c.explanation.ruling.to_string(),
            minimized: None,
            minimized_prevouts: None,
            note: format!("{} entries of {corpus_name} diverge under this rule in the {column} column; this is the smallest (from {}). {}", c.n, we.id, c.explanation.note),
        });
        w.expect.insert(BSV_RS_KEY.to_string(), b_v.clone());
        w.expect.insert(
            if column == "spec" {
                spec_key.clone()
            } else {
                mempool_key.clone()
            },
            a_v.clone(),
        );
        witness_lines.push(serde_json::to_string(&w).or_err("serde_json::to_string(&w)")?);
        let label = if column == "spec" {
            "block path (`spec`)"
        } else {
            "like-for-like (`spec-mempool`)"
        };
        println!(
            "| {label} | `{rule}` | {} | {} | `{}` | {} |",
            c.n, c.explanation.ruling, w.id, c.explanation.decided_by
        );
        summary.push(serde_json::json!({"column": column, "rule": rule, "entries": c.n, "ruling": c.explanation.ruling, "witness": w.id, "from": we.id, "decided_by": c.explanation.decided_by}));
    }
    let out_path = format!("{witnesses_dir}/{corpus_name}.jsonl");
    std::fs::write(
        &out_path,
        witness_lines.join("\n") + if witness_lines.is_empty() { "" } else { "\n" },
    )
    .or_err("witness file")?;
    let wsha = hex::encode(sha256(
        &std::fs::read(&out_path).or_err("std::fs::read(&out_path)")?,
    ));
    // the witnesses manifest: one object per corpus, merged
    let man_path = format!("{witnesses_dir}/manifest.json");
    let mut man: serde_json::Value = std::fs::read_to_string(&man_path)
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_else(|| serde_json::json!({}));
    man[&corpus_name] = serde_json::json!({
        "file": format!("{corpus_name}.jsonl"), "sha256": wsha, "witnesses": witness_lines.len(),
        "corpus": corpus_path, "spec": spec_key, "spec_config": config, "bsv-rs": bsv_script_harness::BSV_RS_VERSION,
        "engine_config": {"recorded": cfg.to_json(), "spec_column": format!("the entry's own word per input (spec_words): its explicit flags[i] (ScriptFlags::from_bits) when it carries flags, else engine::word_for(spend, coin, params.consensus): ScriptFlags::block(era) with the coin's Chronicle marker when params.consensus (= 0x{:X} for a post-Chronicle spend of a post-Chronicle coin), ScriptFlags::standard(era) otherwise", ScriptFlags::block(ProtocolEra::PostChronicle).bits()), "spec_mempool_column": format!("engine::word_for(spend, coin, false): ScriptFlags::standard(era) with the coin's Chronicle marker = 0x{:X} for a post-Chronicle spend of a post-Chronicle coin", ScriptFlags::standard(ProtocolEra::PostChronicle).bits()), "not_applicable_entries": not_applicable},
        "entries": n, "agree_mempool": agree.get("spec-mempool").copied().unwrap_or(0), "agree_block": agree.get("spec").copied().unwrap_or(0),
        "undecided": undecided, "aborts_as_witnesses": aborts, "unknown_messages": unknown_messages, "rules": summary,
        "generated": chrono_stamp(),
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
        println!("  bsv-rs messages outside the cited table (the table must grow, never guess):");
        for (m, c) in &unknown_messages {
            println!("    {c} × {m}");
        }
    }
    // record the spec's verdicts into the corpus
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
            m.implementations
                .retain(|i| i.name != "spec" && i.name != "spec-mempool");
            let mut cfgmap = BTreeMap::new();
            cfgmap.insert("config".to_string(), serde_json::json!(config));
            cfgmap.insert(
                "path".to_string(),
                serde_json::json!("the entry's params (consensus = the block path)"),
            );
            m.implementations.push(ImplConfigJson {
                name: "spec".into(),
                version: commit.clone(),
                config: cfgmap.clone(),
            });
            cfgmap.insert(
                "path".to_string(),
                serde_json::json!("the mempool word of the same configuration"),
            );
            m.implementations.push(ImplConfigJson {
                name: "spec-mempool".into(),
                version: commit.clone(),
                config: cfgmap,
            });
            std::fs::write(
                &mp,
                serde_json::to_string_pretty(&m).or_err("serde_json::to_string_pretty(&m)")? + "\n",
            )
            .or_err("manifest")?;
            println!("  recorded {spec_key} and {mempool_key} into {corpus_path}; new sha256 {sha} in {}", mp.display());
        } else {
            println!("  recorded {spec_key} and {mempool_key} into {corpus_path}; new sha256 {sha} (no manifest beside it)");
        }
    }
    let n_unexplained: u64 = counts
        .iter()
        .filter(|((_, r), _)| r == "unexplained")
        .map(|(_, c)| c.n)
        .sum();
    if n_unexplained > 0 || unknown_msg > 0 || recorded_disagree > 0 || n == 0 {
        println!("run_diff: RED ({n_unexplained} unexplained divergences, {unknown_msg} messages outside the table, {recorded_disagree} recorded bsv-rs verdicts disagreeing)");
        for u in &unexplained {
            println!("  UNEXPLAINED {u}");
        }
        std::process::exit(1);
    }
    println!("run_diff: GREEN (every divergence explained by a rule with its citation)");
    Ok(())
}

/// The UTC date of the run for the manifest (`SOURCE_DATE` overrides it for a reproducible
/// record); no chrono dependency: the civil-from-days arithmetic on the system clock. Until
/// 2026-09-23 this returned a constant, so every manifest said `2026-09-22` (corrected at #20).
fn chrono_stamp() -> String {
    if let Ok(d) = std::env::var("SOURCE_DATE") {
        return d;
    }
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let z = (secs / 86400) as i64 + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = yoe + era * 400 + if m <= 2 { 1 } else { 0 };
    format!("{y:04}-{m:02}-{d:02}")
}

#[cfg(test)]
mod tests {
    use super::*;
    use bsv_script_harness::differential::SpecVerdict;

    /// A-P7: the spec column honours the entry's `params.consensus` and its explicit `flags`; an unknown bit is
    /// an error, never a silent skip.
    #[test]
    fn the_spec_column_honours_the_entry() {
        let block = vec![Some(ScriptFlags::block(ProtocolEra::PostChronicle))];
        let standard = vec![Some(ScriptFlags::standard(ProtocolEra::PostChronicle))];
        assert_eq!(spec_words(None, true, &block, &standard).unwrap(), block);
        assert_eq!(
            spec_words(None, false, &block, &standard).unwrap(),
            standard
        );
        let explicit = [ScriptFlags::standard(ProtocolEra::PostChronicle).bits()];
        assert_eq!(
            spec_words(Some(&explicit[..]), true, &block, &standard).unwrap(),
            standard
        );
        assert!(spec_words(Some(&[1u32 << 31][..]), true, &block, &standard).is_err());
    }

    /// A-B2: the crate's abort on an entry the spec decides is a witness class, a panic included; on an entry
    /// the spec does not decide it stays undecided.
    #[test]
    fn an_abort_on_a_decided_entry_is_a_witness() {
        assert_eq!(
            abort_class(&Verdict::Panic("boom".into()), "valid"),
            Some("engine.exception")
        );
        assert_eq!(
            abort_class(&Verdict::Panic("boom".into()), "invalid"),
            Some("engine.exception")
        );
        assert_eq!(
            abort_class(&Verdict::Resource("budget".into()), "invalid"),
            Some("engine.resource-abort")
        );
        assert_eq!(
            abort_class(&Verdict::Panic("boom".into()), "undecided"),
            None
        );
        assert_eq!(
            abort_class(&Verdict::Resource("budget".into()), "unimplemented"),
            None
        );
        assert_eq!(
            abort_class(&Verdict::NotApplicable("pre-Genesis".into()), "valid"),
            None
        );
        assert_eq!(abort_class(&Verdict::Accept, "valid"), None);
    }

    /// NEW-1 (#32's final lens on Lean B): a corpus id without a spec line is uncovered, so the run is RED before
    /// anything is written; a spec line the corpus does not carry is no gap; blank lines are skipped.
    #[test]
    fn an_entry_without_a_spec_line_is_uncovered() {
        let line = |id: &str| SpecLine {
            id: id.into(),
            spec: SpecVerdict {
                verdict: "valid".into(),
                code: None,
                input: None,
            },
            spec_mempool: SpecVerdict {
                verdict: "valid".into(),
                code: None,
                input: None,
            },
            config: "c".into(),
            commit: "8e449b5".into(),
        };
        let corpus = b"{\"id\":\"a\",\"x\":1}\n\n{\"id\":\"b\"}\n{\"id\":\"c\"}\n";
        let mut spec: BTreeMap<String, SpecLine> = ["a", "c", "z"]
            .iter()
            .map(|i| (i.to_string(), line(i)))
            .collect();
        assert_eq!(uncovered(corpus, &spec).unwrap(), vec!["b".to_string()]);
        spec.insert("b".into(), line("b"));
        assert!(uncovered(corpus, &spec).unwrap().is_empty());
        assert_eq!(
            uncovered(corpus, &BTreeMap::new()).unwrap(),
            vec!["a", "b", "c"]
        );
    }

    /// lean #32's applied lens: a stamp in no form `eval/bsvs` emits names no commit (so the B-4 check refuses it for
    /// the corpus) and its value is named, an empty one among a column's clean commits too; each emitted form has no
    /// form error (`+dirty` and `unknown` are refused for the corpus by the B-4 check alone).
    #[test]
    fn a_stamp_in_no_emitted_form_is_named() {
        for bad in ["", " ", "8e44 9b5", "8E449B5", "+dirty", "spec@8e449b5"] {
            assert_ne!(stamp_form(bad), Ok(Stamp::Commit), "{bad}");
            let why = stamp_form_error([bad]).expect(bad);
            assert!(why.contains(&format!("{bad:?}")), "{why}");
        }
        assert!(stamp_form_error(["8e449b5", ""]).is_some_and(|w| w.contains("\"\"")));
        for good in ["8e449b5", "8e449b5c0ffee", "8e449b5+dirty", "unknown"] {
            assert_eq!(stamp_form_error([good]), None, "{good}");
        }
        assert_eq!(stamp_form_error([] as [&str; 0]), None);
    }
}
