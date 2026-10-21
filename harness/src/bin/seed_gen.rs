//! seed_gen (this repo's): the seed corpus generator. Deterministic from its
//! seed; writes `<out>/seed.jsonl` and `<out>/manifest.json` in the format of
//! `docs/DESIGN.md` §6, every entry carrying bsv-rs's verdict under the recorded
//! engine configuration. Families and mix: `corpus/INDEX.md`.
//!
//! With `--family F` (arith, nonmin, size, depth, num2bin or mutation) the stream is that family's alone under the
//! seed, the same generators and the same version-1 twins; a mutation stream draws its bases from the mix and emits
//! only the mutants. The fuzz campaign runs one stream per family under a salted seed (tools/fuzz_campaign.sh), so a
//! family's cases never move when another family is added or re-weighted; without `--family` the stream is the mix,
//! byte for byte as before the flag.
//!
//! Run: cargo run --release --bin seed_gen -- [--out DIR] [--seed HEX] [--count N] [--family F]

use bsv_script_harness::cases::{
    arg, prevout_of, spend_tx, synthetic_txid, Corpus, Label, Quiet, Text,
};
use bsv_script_harness::corpus::RefJson;
use bsv_script_harness::engine::{EngineConfig, Prevout};
use bsv_script_harness::gen::{self, GenCase, Rng};
use bsv_script_harness::txraw::RawTx;

const GENERATOR: &str = "bsv-script-harness seed_gen 0.0.2 (adapted from a predecessor harness of the owner's, its fuzz binary's pattern @ 0fc5ced, mechanism-free; format of DESIGN v1 §6)";
const DEFAULT_SEED: u64 = 0x5EED_5C71_9700_0001;

/// The spending transaction of a case: one input carrying the unlock, one
/// 1-satoshi OP_TRUE output, sequence final, lock time 0; its outpoint
/// synthetic (sha256 of the entry's id), so it cannot be a real transaction's.
fn build_tx(id: &str, case: &GenCase, version: i32) -> (RawTx, Vec<Prevout>) {
    let txid = synthetic_txid("seed", id);
    (
        spend_tx(txid, version, case.unlock.clone()),
        prevout_of(txid, &case.lock),
    )
}

/// The families `--family` takes, in the mix's order.
const FAMILIES: [&str; 6] = ["arith", "nonmin", "size", "depth", "num2bin", "mutation"];

/// The five base families by name.
fn base(rng: &mut Rng, family: &str) -> Vec<GenCase> {
    match family {
        "nonmin" => gen::gen_nonmin(rng),
        "size" => gen::gen_size(rng),
        "depth" => gen::gen_depth(rng),
        "num2bin" => gen::gen_num2bin(rng),
        _ => gen::gen_arith(rng),
    }
}

/// One draw of the stream: the mix (the seed corpus's, `corpus/INDEX.md`), or one family alone.
fn draw(rng: &mut Rng, pool: &mut Vec<GenCase>, family: Option<&str>) -> Vec<GenCase> {
    match family {
        None => match rng.below(100) {
            0..=54 => gen::gen_arith(rng),
            55..=64 => gen::gen_nonmin(rng),
            65..=72 => gen::gen_size(rng),
            73..=78 => gen::gen_depth(rng),
            79..=84 => gen::gen_num2bin(rng),
            _ => {
                if pool.is_empty() {
                    gen::gen_arith(rng)
                } else {
                    let base = &pool[rng.below(pool.len())];
                    vec![gen::gen_mutation(rng, base)]
                }
            }
        },
        Some("mutation") => {
            // the bases: one draw of the five base families at the mix's weights, pooled and never emitted
            let f = match rng.below(85) {
                0..=54 => "arith",
                55..=64 => "nonmin",
                65..=72 => "size",
                73..=78 => "depth",
                _ => "num2bin",
            };
            pool.extend(base(rng, f));
            if pool.is_empty() {
                return Vec::new();
            }
            let b = &pool[rng.below(pool.len())];
            vec![gen::gen_mutation(rng, b)]
        }
        Some(f) => base(rng, f),
    }
}

#[allow(
    clippy::expect_used,
    clippy::unwrap_used,
    reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
)]
fn main() {
    let args: Vec<String> = std::env::args().collect();
    let out_dir = arg(&args, "--out").unwrap_or_else(|| "../corpus/seed".into());
    let seed: u64 = arg(&args, "--seed")
        .map(|s| u64::from_str_radix(s.trim_start_matches("0x"), 16).expect("--seed is hex"))
        .unwrap_or(DEFAULT_SEED);
    let count: usize = arg(&args, "--count")
        .map(|s| s.parse().expect("--count"))
        .unwrap_or(10_000);
    let family = arg(&args, "--family");
    if let Some(f) = &family {
        assert!(
            FAMILIES.contains(&f.as_str()),
            "--family is one of {}",
            FAMILIES.join(", ")
        );
    }
    let mut rng = Rng(seed);
    let t0 = std::time::Instant::now();

    // silence expected panic backtraces (verdicts capture them)
    let mut quiet = Quiet::new();

    let mut pool: Vec<GenCase> = Vec::new();
    let mut corpus = Corpus::new(EngineConfig::default());
    let mut panics = 0u64;
    let mut nondet = 0u64;

    let mut emit = |case: &GenCase, version: i32, corpus: &mut Corpus| {
        let id = format!("seed-{:06}", corpus.entries.len() + 1);
        let (tx, prevouts) = build_tx(&id, case, version);
        let judged = corpus.run(&tx, &prevouts);
        let (v2, _) = corpus.run(&tx, &prevouts);
        let v1 = &judged.0;
        if *v1 != v2 {
            nondet += 1;
            eprintln!("NONDETERMINISM {id}: {v1:?} vs {v2:?}");
        }
        if matches!(v1, bsv_script_harness::engine::Verdict::Panic(_)) {
            panics += 1;
            eprintln!("PANIC {id} ({}): {:?}", case.family, v1);
        }
        let mut label = if version == 1 {
            Label::new(
                id,
                format!("{}/v1", case.family),
                "flags.version-gate",
                format!(
                    "version-1 twin of a {} case ({}): the version gate selects the strict branch",
                    case.rule, case.note
                ),
            )
        } else {
            Label::new(id, case.family.clone(), case.rule, case.note.clone())
        };
        if version != 1 {
            label.reference = case.reference.as_str().map(|e| RefJson {
                model: "i128 + independent minimal encoder (gen.rs)".into(),
                expect: e.into(),
            });
        }
        corpus.record(label, &tx, &prevouts, &judged);
    };

    while corpus.entries.len() < count {
        let cases: Vec<GenCase> = draw(&mut rng, &mut pool, family.as_deref());
        for case in cases {
            if corpus.entries.len() >= count {
                break;
            }
            emit(&case, 2, &mut corpus);
            // a version-1 twin for a fifth of the non-mutation cases: the branch corner
            if case.rule != "mutation" && rng.below(5) == 0 && corpus.entries.len() < count {
                emit(&case, 1, &mut corpus);
            }
            if case.rule != "mutation" {
                pool.push(case);
            }
        }
        if corpus.entries.len().is_multiple_of(2000) {
            eprintln!(
                "[seed_gen] {} entries, {} engine execs, {:.1}s",
                corpus.entries.len(),
                corpus.execs,
                t0.elapsed().as_secs_f64()
            );
        }
    }
    quiet.restore();

    let (path, sha, manifest) = corpus.write(
        &out_dir,
        Text {
            corpus: "seed",
            file: "seed.jsonl",
            manifest: "manifest.json",
            generator: GENERATOR.into(),
            seed: format!("0x{seed:016X}"),
            generated: std::env::var("SOURCE_DATE").unwrap_or_else(|_| "2026-09-22".into()),
            provenance: "docs/PROVENANCE.md §1 (bsv-rs), §4 (what crosses); synthetic outpoints = sha256 of the entry id; no transaction of any private program".into(),
        },
    );
    println!(
        "seed_gen: {} entries → {path} (sha256 {sha})",
        corpus.entries.len()
    );
    println!(
        "  engine executions {}, wall {:.1}s, nondeterminism {nondet}, panics {panics}",
        corpus.execs,
        t0.elapsed().as_secs_f64()
    );
    println!("  verdicts {:?}", manifest.verdicts);
    println!("  families:");
    for (f, n) in &manifest.families {
        println!("    {n:>6}  {f}");
    }
    if nondet > 0 || panics > 0 {
        eprintln!(
            "seed_gen: nondeterminism or panics seen; the corpus is written but the run is RED"
        );
        std::process::exit(1);
    }
}
