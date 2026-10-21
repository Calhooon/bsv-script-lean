//! spec_recorded (this repo's; #31, 2026-09-29): the spec's verdicts for a corpus AS RECORDED in its entries,
//! written in the format of `eval/bsvs corpus <file> --out <spec.jsonl>` (one line per entry,
//! `{commit, config, id, spec, spec-mempool}`), so the differentials (`run_diff`, `run_engine`, `run_svnode`) run
//! on a machine without the Lean build. `harness/run --spec recorded` uses it.
//!
//! The source: each entry's `spec@<commit>` and `spec-mempool@<commit>` keys, the verdicts `run_diff --record`
//! wrote at that commit (`docs/DESIGN.md` §6). They are the spec's verdicts at the commit the keys name, never
//! re-derived here, and every driver prints that commit (`the spec at spec@<commit>`). The live evaluator's line
//! also carries the standardness gate's verdict (`gate`); a recorded key has none, so a run that reads the gate
//! (the block road, `run_svnode --mode tx`) runs on the live spec alone.
//!
//! Refused (exit 2), never guessed: an entry carrying one of the two keys without the other, a key twice with two
//! commits, a corpus whose entries name two commits, and a corpus carrying no recorded spec verdict at all
//! (`corpus/bytes` records none: its spec column is the live evaluator's). Partial coverage, duplicate entry IDs
//! and a commit stamp in no form `eval/bsvs` emits for a record (`bsv_script_harness::stamp`) are refused before
//! writing output.
//!
//! Run: cargo run --release --locked --bin spec_recorded -- --corpus ../corpus/seed/seed.jsonl --out <spec.jsonl>
//!      [--config sv-mainnet-default]

use std::collections::BTreeSet;
use std::io::BufRead;

use bsv_script_harness::corpus::{Entry, ExpectJson};
use bsv_script_harness::stamp::{stamp_form, Stamp};

fn arg(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1).cloned())
}

fn refuse(msg: String) -> ! {
    eprintln!("spec_recorded: {msg}");
    std::process::exit(2);
}

/// The one key of `e.expect` named `<prefix>@<commit>`, with its commit.
fn recorded<'a>(e: &'a Entry, prefix: &str) -> Option<(String, &'a ExpectJson)> {
    let mut found: Option<(String, &ExpectJson)> = None;
    for (k, v) in &e.expect {
        if let Some(commit) = k.strip_prefix(prefix).and_then(|r| r.strip_prefix('@')) {
            // a recorded key names a commit, in the form the wrapper emits (`bsv_script_harness::stamp`): an empty,
            // spaced or arbitrary stamp, `+dirty` or `unknown` is refused with the key named
            match stamp_form(commit) {
                Ok(Stamp::Commit) => {}
                Ok(_) => refuse(format!(
                    "{}: {k} names no commit (a +dirty or unknown stamp never enters the corpus)",
                    e.id
                )),
                Err(why) => refuse(format!("{}: {k}: {why}", e.id)),
            }
            if let Some((c, _)) = &found {
                refuse(format!(
                    "{}: two recorded `{prefix}` keys ({prefix}@{c}, {k})",
                    e.id
                ));
            }
            found = Some((commit.to_string(), v));
        }
    }
    found
}

fn verdict_json(v: &ExpectJson) -> serde_json::Value {
    serde_json::json!({"verdict": v.verdict, "code": v.code, "input": v.input})
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let corpus = arg(&args, "--corpus")
        .unwrap_or_else(|| refuse("--corpus <file.jsonl> is required".into()));
    let out =
        arg(&args, "--out").unwrap_or_else(|| refuse("--out <spec.jsonl> is required".into()));
    let config = arg(&args, "--config").unwrap_or_else(|| "sv-mainnet-default".into());
    let file = std::fs::File::open(&corpus).unwrap_or_else(|e| refuse(format!("{corpus}: {e}")));
    let (mut n, mut without) = (0u64, 0u64);
    let mut commit: Option<String> = None;
    let mut lines: Vec<String> = Vec::new();
    let mut ids = BTreeSet::new();
    for line in std::io::BufReader::new(file).lines() {
        let line = line.unwrap_or_else(|e| refuse(format!("{corpus}: {e}")));
        if line.trim().is_empty() {
            continue;
        }
        let e: Entry = serde_json::from_str(&line)
            .unwrap_or_else(|err| refuse(format!("{corpus}: an entry: {err}")));
        if !ids.insert(e.id.clone()) {
            refuse(format!("{corpus}: duplicate entry id {}", e.id));
        }
        n += 1;
        // `spec@` never matches a `spec-mempool@` key: the `@` must follow the prefix
        let own = recorded(&e, "spec");
        let mempool = recorded(&e, "spec-mempool");
        let ((c1, own), (c2, mempool)) = match (own, mempool) {
            (None, None) => {
                without += 1;
                continue;
            }
            (Some(o), Some(m)) => (o, m),
            _ => refuse(format!(
                "{}: one of `spec@` and `spec-mempool@` is recorded without the other",
                e.id
            )),
        };
        if c1 != c2 {
            refuse(format!("{}: spec@{c1} beside spec-mempool@{c2}", e.id));
        }
        match &commit {
            None => commit = Some(c1.clone()),
            Some(c) if *c != c1 => refuse(format!(
                "{}: spec@{c1}, where the corpus's earlier entries carry spec@{c}",
                e.id
            )),
            _ => {}
        }
        let j = serde_json::json!({
            "commit": c1, "config": config, "id": e.id,
            "spec": verdict_json(own), "spec-mempool": verdict_json(mempool),
        });
        lines.push(j.to_string());
    }
    let Some(commit) = commit else {
        refuse(format!("{corpus}: {n} entries, none carrying a recorded spec verdict (run the live spec: eval/bsvs corpus)"))
    };
    if without != 0 {
        refuse(format!("{corpus}: {without} of {n} entries lack both recorded spec verdicts; run with the live spec or re-record the corpus"));
    }
    std::fs::write(&out, lines.join("\n") + "\n").unwrap_or_else(|e| refuse(format!("{out}: {e}")));
    println!(
        "spec_recorded: {corpus}: {} of {n} entries carry spec@{commit} and spec-mempool@{commit} ({without} carry neither); written to {out} (config {config})",
        lines.len()
    );
}
