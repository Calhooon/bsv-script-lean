//! run_bsvrs (this repo's): the bsv-rs runner over a corpus directory. Checks the
//! manifest's sha256, runs every entry through the pinned engine under the
//! manifest's recorded configuration (the flag word since 0.3.27), and compares
//! with the entry's recorded bsv-rs verdict. `--smoke` exits 1 on any disagreement, any panic (recorded or
//! not: a panic that recurs on every run is still a panic), any nondeterminism, and any entry with no recorded
//! bsv-rs verdict (never compared): the tripwire's harness leg. Its GREEN line counts only the entries compared.
//! `--smoke` with `--force-version` or `--record` is refused (exit 2): neither mode compares an entry.
//! The undecided runs are counted by cause: a resource wall, not applicable (a pre-Genesis input), a panic. `--record` writes bsv-rs's verdict into every
//! entry as `bsv-rs@<version>` (a hand-built corpus, #20: the eras corpus, whose manifest
//! says `words: per-input`; since the pin's move to 0.3.30, #47 (again at 0.3.32, R1, 0.3.33, bsv-rs#41, and 0.4.4), every corpus's bsv-rs key is re-recorded
//! this way, in place, every other engine's key and implementation row kept) and re-stamps the manifest
//! (the sha256, the verdict histogram, the bsv-rs configuration, the executions, and the provenance's
//! "bsv-rs X.Y.Z's verdicts"). `--manifest NAME` reads and writes `DIR/NAME` (default `manifest.json`;
//! the hand-written case corpora keep theirs as `cases-manifest.json`).
//!
//! Run: cargo run --release --bin run_bsvrs -- --corpus DIR [--manifest NAME] [--smoke] [--record] [--limit N] [--force-version V]

use std::collections::BTreeMap;
use std::io::BufRead;

use bsv_rs::primitives::hash::sha256;
use bsv_script_harness::corpus::{Entry, ExpectJson, ImplConfigJson, Manifest};
use bsv_script_harness::engine::{run_tx, run_tx_words, words_of, EngineConfig, Mode, Verdict};
use bsv_script_harness::fail::OrErr;
use bsv_script_harness::txraw::RawTx;
use bsv_script_harness::{BSV_RS_KEY, BSV_RS_VERSION};

fn arg(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1).cloned())
}

/// The provenance's "bsv-rs X.Y.Z's verdicts" re-stamped to the linked version on `--record` (a
/// provenance that names no such clause is left as it is).
fn restamp_provenance(p: &str) -> String {
    let needle = "'s verdicts";
    if let Some(end) = p.find(needle) {
        if let Some(start) = p[..end].rfind("bsv-rs ") {
            let v = &p[start + 7..end];
            if !v.is_empty() && v.chars().all(|c| c.is_ascii_digit() || c == '.') {
                return format!("{}bsv-rs {}{}", &p[..start], BSV_RS_VERSION, &p[end..]);
            }
        }
    }
    p.to_string()
}

/// The exit code of `run` (#132): an error that stood as an unwrap, expect or panic is reported with its words and exits 1.
fn main() -> std::process::ExitCode {
    match run() {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("run_bsvrs: {e}");
            std::process::ExitCode::from(1)
        }
    }
}

fn run() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();
    let dir = arg(&args, "--corpus").unwrap_or_else(|| "../corpus/seed".into());
    let mname = arg(&args, "--manifest").unwrap_or_else(|| "manifest.json".into());
    let smoke = args.iter().any(|a| a == "--smoke");
    let record = args.iter().any(|a| a == "--record");
    let limit: usize = arg(&args, "--limit")
        .map(|s| s.parse().or_err("--limit"))
        .transpose()?
        .unwrap_or(usize::MAX);
    let force_version: Option<i32> = arg(&args, "--force-version")
        .map(|s| s.parse().or_err("--force-version"))
        .transpose()?;
    // the smoke guard compares every entry with its recorded verdict; a forced version is an experiment and a recording
    // run writes the verdicts it would compare, so neither compares anything: --smoke with either is refused (#32 A-B3, the
    // lens of lane fix32-rust: the guard had skipped silently under both modes)
    if smoke && (force_version.is_some() || record) {
        eprintln!("run_bsvrs: --smoke compares with the recorded verdicts; it is refused with --force-version or --record");
        std::process::exit(2);
    }

    let mut manifest: Manifest = serde_json::from_str(
        &std::fs::read_to_string(format!("{dir}/{mname}")).or_err("the manifest")?,
    )
    .or_err("manifest")?;
    let path = format!("{dir}/{}", manifest.file);
    let bytes = std::fs::read(&path).or_err("corpus file")?;
    let sha = hex::encode(sha256(&bytes));
    if sha != manifest.sha256 {
        eprintln!(
            "run_bsvrs: {path} sha256 {sha} != manifest {}",
            manifest.sha256
        );
        std::process::exit(1);
    }
    // the configuration the corpus was recorded under (`EngineConfig::to_json`): since the
    // pin moved to 0.3.27 the flag word is in it; a manifest without one is the default mode
    let mut cfg = EngineConfig::default();
    if let Some(imp) = manifest.implementations.iter().find(|i| i.name == "bsv-rs") {
        if imp.version != bsv_script_harness::BSV_RS_VERSION {
            eprintln!(
                "run_bsvrs: the corpus records bsv-rs {} but this runner links {}",
                imp.version,
                bsv_script_harness::BSV_RS_VERSION
            );
            if smoke {
                std::process::exit(1);
            }
        }
        cfg = EngineConfig::try_from_json(&imp.config)?;
    }
    let prev_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(|_| {}));
    let t0 = std::time::Instant::now();
    let (mut n, mut agree, mut disagree, mut no_expect, mut nondet) =
        (0u64, 0u64, 0u64, 0u64, 0u64);
    let (mut resource, mut not_applicable, mut panics) = (0u64, 0u64, 0u64);
    let mut first_disagreements: Vec<String> = Vec::new();
    let mut recorded: Vec<Entry> = Vec::new();
    let mut verdicts: BTreeMap<String, u64> = BTreeMap::new();
    for line in std::io::BufReader::new(&bytes[..]).lines() {
        if n as usize >= limit {
            break;
        }
        let line = line.or_err("line")?;
        if line.trim().is_empty() {
            continue;
        }
        let mut e: Entry = serde_json::from_str(&line).or_err("entry")?;
        e.check().or_err("a corpus entry must be well-formed")?;
        n += 1;
        let mut tx = RawTx::decode(&hex::decode(&e.tx).or_err("tx hex")?).or_err("tx frame")?;
        if let Some(v) = force_version {
            tx.version = v;
        }
        let prevouts: Vec<_> = e
            .prevouts
            .iter()
            .map(|p| p.to_prevout().or_err("prevout"))
            .collect::<Result<_, _>>()?;
        // under the manifest's word, or (the eras corpus, #20) the word derived per input from
        // the entry's spend height and each coin's height (engine::word_for; the block word when
        // the entry's params say consensus)
        let heights: Vec<u32> = e.prevouts.iter().map(|p| p.height).collect();
        let words = words_of(e.params.spend_height, &heights, e.params.consensus);
        let run = |tx: &RawTx| -> (Verdict, Option<usize>) {
            if cfg.per_input_words {
                run_tx_words(tx, &prevouts, Mode::Native, &cfg, &words)
            } else {
                run_tx(tx, &prevouts, Mode::Native, &cfg)
            }
        };
        let (v, i) = run(&tx);
        let (v2, _) = run(&tx);
        if v != v2 {
            nondet += 1;
            first_disagreements.push(format!("NONDETERMINISM {}: {v:?} vs {v2:?}", e.id));
        }
        match v {
            Verdict::Panic(_) => panics += 1,
            Verdict::Resource(_) => resource += 1,
            Verdict::NotApplicable(_) => not_applicable += 1,
            _ => {}
        }
        if force_version.is_some() {
            continue; // an experiment, not a comparison
        }
        if record {
            *verdicts.entry(v.kind().to_string()).or_insert(0) += 1;
            let stale: Vec<String> = e
                .expect
                .keys()
                .filter(|k| k.starts_with("bsv-rs@"))
                .cloned()
                .collect();
            for k in stale {
                e.expect.remove(&k);
            }
            e.expect.insert(
                BSV_RS_KEY.to_string(),
                ExpectJson {
                    verdict: v.kind().to_string(),
                    code: None,
                    reason: v.reason(),
                    input: i,
                },
            );
            recorded.push(e.clone());
            continue;
        }
        match e.expect.get(BSV_RS_KEY) {
            None => no_expect += 1,
            Some(x) => {
                if x.verdict == v.kind() && x.reason == v.reason() && x.input == i {
                    agree += 1;
                } else {
                    disagree += 1;
                    if first_disagreements.len() < 10 {
                        first_disagreements.push(format!(
                            "DISAGREE {} ({}): recorded {:?}/{:?} got {}/{:?}",
                            e.id,
                            e.family,
                            x.verdict,
                            x.reason,
                            v.kind(),
                            v.reason()
                        ));
                    }
                }
            }
        }
    }
    std::panic::set_hook(prev_hook);
    println!(
        "run_bsvrs: corpus {} ({} entries, sha256 ok) vs bsv-rs {} under {:?}: agree={agree} disagree={disagree} no-recorded-verdict={no_expect} undecided: resource={resource} not-applicable={not_applicable} panic={panics} nondeterminism={nondet}, {:.1}s",
        manifest.corpus, n, bsv_script_harness::BSV_RS_VERSION, cfg, t0.elapsed().as_secs_f64()
    );
    for d in &first_disagreements {
        println!("  {d}");
    }
    if record {
        let text: String = recorded
            .iter()
            .map(|e| serde_json::to_string(e).map(|l| l + "\n"))
            .collect::<Result<String, _>>()
            .or_err("corpus json")?;
        std::fs::write(&path, &text).or_err("rewrite corpus")?;
        let sha = hex::encode(sha256(text.as_bytes()));
        manifest.sha256 = sha.clone();
        manifest.count = recorded.len() as u64;
        manifest.verdicts = verdicts;
        manifest.implementations.retain(|i| i.name != "bsv-rs");
        manifest.implementations.insert(
            0,
            ImplConfigJson {
                name: "bsv-rs".into(),
                version: BSV_RS_VERSION.into(),
                config: cfg.to_json(),
            },
        );
        manifest.engine_executions += 2 * n;
        manifest.provenance = restamp_provenance(&manifest.provenance);
        std::fs::write(
            format!("{dir}/{mname}"),
            serde_json::to_string_pretty(&manifest)
                .or_err("serde_json::to_string_pretty(&manifest)")?
                + "\n",
        )
        .or_err("manifest")?;
        println!("run_bsvrs --record: {} entries recorded as {BSV_RS_KEY} into {path}; new sha256 {sha} in {dir}/{mname}; undecided: a resource wall {resource}, not applicable {not_applicable}, a panic {panics}", recorded.len());
        return Ok(());
    }
    // a resource wall or a not-applicable input that the corpus recorded as such agrees (docs/DESIGN.md §6: undecided
    // is a property of the run); a disagreement, a panic, nondeterminism or an entry never compared is RED
    if smoke && (disagree > 0 || nondet > 0 || panics > 0 || no_expect > 0 || n == 0) {
        println!("run_bsvrs --smoke: RED");
        std::process::exit(1);
    }
    if smoke {
        println!("run_bsvrs --smoke: GREEN ({agree} of {n} entries compared, every one agreeing with its recorded bsv-rs verdict; no panic, no nondeterminism)");
    }
    Ok(())
}
