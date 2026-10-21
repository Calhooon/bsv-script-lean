//! The spec stamp's gate at each runner (lean #32, B-4; the owner's P4 and P5, 2026-10-05,
//! `docs/records/20261005-224016-owner-rulings-32-p.md`): run against a corpus and a column that do not exist, or a
//! column stamped with no commit, every runner refuses with the gate's report and exit 2 before it loads the corpus,
//! touches a node or writes anything. Local temporary files only; no engine, node or network is reached.

use std::path::{Path, PathBuf};
use std::process::Command;

#[allow(
    clippy::unwrap_used,
    reason = "an integration test's helper: a failure is the test's failure"
)]
fn root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("..")
        .canonicalize()
        .unwrap()
}

#[allow(
    clippy::unwrap_used,
    reason = "an integration test's helper: a failure is the test's failure"
)]
fn tmp(tag: &str) -> PathBuf {
    let p = std::env::temp_dir().join(format!("stamp-gate-test-{}-{tag}", std::process::id()));
    let _ = std::fs::remove_dir_all(&p);
    std::fs::create_dir(&p).unwrap();
    p
}

/// (the tool's name in its report, the binary, the arguments before `--corpus`)
fn runners() -> Vec<(&'static str, &'static str, Vec<&'static str>)> {
    vec![
        (
            "run_engine",
            env!("CARGO_BIN_EXE_run_engine"),
            vec!["--engine", "gosdk"],
        ),
        ("run_svnode", env!("CARGO_BIN_EXE_run_svnode"), vec![]),
        (
            "run_svnode --mode tx",
            env!("CARGO_BIN_EXE_run_svnode"),
            vec!["--mode", "tx"],
        ),
    ]
}

#[allow(
    clippy::unwrap_used,
    reason = "an integration test's helper: a failure is the test's failure"
)]
fn refused(tool: &str, bin: &str, pre: &[&str], dir: &Path, spec: &Path) -> String {
    let out = Command::new(bin)
        .args(pre)
        .args([
            "--corpus",
            dir.join("no-corpus.jsonl").to_str().unwrap(),
            "--spec",
            spec.to_str().unwrap(),
            "--record",
        ])
        .args(["--witnesses", dir.join("witnesses").to_str().unwrap()])
        .env("BSV_SCRIPT_LEAN_ROOT", root())
        .output()
        .unwrap();
    let err = String::from_utf8_lossy(&out.stderr).to_string();
    assert_eq!(out.status.code(), Some(2), "{tool}: {err}");
    assert!(
        err.starts_with(&format!("{tool}: refusing to write spec@")),
        "{tool}: {err}"
    );
    err
}

#[test]
fn a_missing_column_gets_the_gates_report_before_the_corpus_is_read() {
    let dir = tmp("missing");
    for (tool, bin, pre) in runners() {
        let err = refused(tool, bin, &pre, &dir, &dir.join("no-spec.jsonl"));
        assert!(
            err.starts_with(&format!(
                "{tool}: refusing to write spec@unknown into the corpus"
            )) && err.trim_end().ends_with("(lean #32, B-4)"),
            "{err}"
        );
        // nothing written: the directory holds what the test put there, nothing else
        assert_eq!(std::fs::read_dir(&dir).unwrap().count(), 0, "{tool}");
    }
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn a_column_stamped_with_no_commit_is_refused_its_value_named() {
    let dir = tmp("blank");
    for stamp in ["", " ", "not-a-commit"] {
        let spec = dir.join("spec.jsonl");
        std::fs::write(
            &spec,
            format!("{{\"commit\": \"{stamp}\", \"id\": \"a\"}}\n"),
        )
        .unwrap();
        for (tool, bin, pre) in runners() {
            let err = refused(tool, bin, &pre, &dir, &spec);
            assert!(err.contains(&format!("(lean #32, B-4); the commit stamp {stamp:?} is none of the forms eval/bsvs emits")), "{err}");
            assert_eq!(std::fs::read_dir(&dir).unwrap().count(), 1, "{tool}");
        }
    }
    std::fs::remove_dir_all(&dir).unwrap();
}
