//! Recorded-mode coverage and provenance contracts for [LIT] #31.
//! Uses this repository's public seed format and local temporary files; no adapter, evaluator or network call.

use std::path::{Path, PathBuf};
use std::process::{Command, Output};
use std::sync::atomic::{AtomicU64, Ordering};

use bsv_script_harness::differential::{read_spec, CorpusInput};
use bsv_script_harness::flags_oracle::FlagsOracle;
use serde_json::{json, Value};

static NEXT: AtomicU64 = AtomicU64::new(0);

struct Files(PathBuf);

impl Files {
    #[allow(
        clippy::unwrap_used,
        reason = "an integration test's helper: a failure is the test's failure"
    )]
    fn new() -> Self {
        let p = std::env::temp_dir().join(format!(
            "spec-recorded-test-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir(&p).unwrap();
        Self(p)
    }

    fn path(&self, name: &str) -> PathBuf {
        self.0.join(name)
    }

    #[allow(
        clippy::unwrap_used,
        reason = "an integration test's helper: a failure is the test's failure"
    )]
    fn write(&self, name: &str, text: &str) -> PathBuf {
        let p = self.path(name);
        std::fs::write(&p, text).unwrap();
        p
    }

    #[allow(
        clippy::unwrap_used,
        reason = "an integration test's helper: a failure is the test's failure"
    )]
    fn export(&self, entries: &[Value]) -> Output {
        let text = entries
            .iter()
            .map(Value::to_string)
            .collect::<Vec<_>>()
            .join("\n");
        let corpus = self.write("cases.jsonl", &(text + "\n"));
        Command::new(env!("CARGO_BIN_EXE_spec_recorded"))
            .args([
                "--corpus",
                corpus.to_str().unwrap(),
                "--out",
                self.path("spec.jsonl").to_str().unwrap(),
            ])
            .output()
            .unwrap()
    }
}

impl Drop for Files {
    #[allow(
        clippy::unwrap_used,
        reason = "an integration test's helper: a failure is the test's failure"
    )]
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}

fn seed_path(name: &str) -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../corpus/seed")
        .join(name)
}

#[allow(
    clippy::unwrap_used,
    reason = "an integration test's helper: a failure is the test's failure"
)]
fn entry(id: &str, stamp: &str) -> Value {
    let seed = std::fs::read_to_string(seed_path("seed.jsonl")).unwrap();
    let mut e: Value = serde_json::from_str(seed.lines().next().unwrap()).unwrap();
    e["id"] = id.into();
    e["expect"] = json!({});
    e["expect"][format!("spec@{stamp}")] = json!({"verdict": "valid"});
    e["expect"][format!("spec-mempool@{stamp}")] =
        json!({"verdict": "invalid", "code": "EVAL_FALSE", "input": 0});
    e
}

#[test]
fn exported_columns_retain_ids_stamps_codes_and_input_indexes() {
    let files = Files::new();
    let output = files.export(&[entry("record-a", "abc1234"), entry("record-b", "abc1234")]);
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    let rows = read_spec(&files.path("spec.jsonl")).unwrap();
    assert_eq!(rows.len(), 2);
    for id in ["record-a", "record-b"] {
        let row = &rows[id];
        assert_eq!(row.commit, "abc1234");
        assert_eq!(row.spec.verdict, "valid");
        assert_eq!(row.spec_mempool.verdict, "invalid");
        assert_eq!(row.spec_mempool.code.as_deref(), Some("EVAL_FALSE"));
        assert_eq!(row.spec_mempool.input, Some(0));
    }
}

#[test]
fn incomplete_or_ambiguous_records_never_write_partial_output() {
    let good = entry("record-a", "abc1234");
    let mut missing = entry("record-b", "abc1234");
    missing["expect"] = json!({});
    let mut one_column = good.clone();
    one_column["expect"]
        .as_object_mut()
        .unwrap()
        .remove("spec-mempool@abc1234");
    let mut extra_stamp = good.clone();
    extra_stamp["expect"]["spec@def4567"] = json!({"verdict": "valid"});
    let mut mismatched_columns = good.clone();
    let v = mismatched_columns["expect"]
        .as_object_mut()
        .unwrap()
        .remove("spec-mempool@abc1234")
        .unwrap();
    mismatched_columns["expect"]["spec-mempool@def4567"] = v;
    for (entries, diagnostic) in [
        (
            vec![good.clone(), missing.clone()],
            "lack both recorded spec verdicts",
        ),
        (vec![missing], "none carrying a recorded spec verdict"),
        (vec![one_column], "without the other"),
        (vec![extra_stamp], "two recorded"),
        (vec![mismatched_columns], "beside"),
        (
            vec![good.clone(), entry("record-b", "def4567")],
            "earlier entries",
        ),
        (vec![good.clone(), good], "duplicate entry id"),
        (
            vec![entry("record-a", "")],
            "none of the forms eval/bsvs emits",
        ),
        (
            vec![entry("record-a", "abc 1234")],
            "\"abc 1234\" is none of the forms",
        ),
        (vec![entry("record-a", "abc1234+dirty")], "names no commit"),
        (vec![entry("record-a", "unknown")], "names no commit"),
    ] {
        let files = Files::new();
        let output = files.export(&entries);
        assert_eq!(output.status.code(), Some(2));
        assert!(String::from_utf8_lossy(&output.stderr).contains(diagnostic));
        assert!(!files.path("spec.jsonl").exists());
    }
}

#[test]
fn corpus_checksum_is_checked_on_raw_bytes_before_parsing() {
    let files = Files::new();
    let corpus = files.write(
        "seed.jsonl",
        &std::fs::read_to_string(seed_path("seed.jsonl")).unwrap(),
    );
    files.write(
        "manifest.json",
        &std::fs::read_to_string(seed_path("manifest.json")).unwrap(),
    );
    assert!(CorpusInput::load(&corpus).is_ok());
    let mut bytes = std::fs::read(&corpus).unwrap();
    bytes.push(b'\n');
    std::fs::write(&corpus, bytes).unwrap();
    let error = CorpusInput::load(&corpus)
        .err()
        .expect("raw-byte drift must fail");
    assert!(error.contains("sha256"));
}

#[test]
fn recorded_words_require_coverage_and_do_not_call_the_live_evaluator() {
    let files = Files::new();
    let word =
        json!({"spend_height": 967896, "utxo_height": 967895, "consensus": true, "word": 123});
    let manifest = files.write(
        "words.json",
        &json!({"seed": {"words": [word.clone()]}}).to_string(),
    );
    let mut oracle = FlagsOracle::recorded(&manifest, "seed").unwrap();
    assert!(oracle.table().is_empty());
    assert_eq!(oracle.word(967896, 967895, true).unwrap(), 123);
    assert!(oracle.word(967896, 967895, false).is_err());
    assert_eq!(oracle.calls, 0);
    assert_eq!(oracle.table().len(), 1);
    let mut conflict = word;
    conflict["word"] = json!(456);
    files.write("words.json", &json!({"seed": {"words": [
        {"spend_height": 967896, "utxo_height": 967895, "consensus": true, "word": 123}, conflict
    ]}}).to_string());
    assert!(FlagsOracle::recorded(&manifest, "seed").is_err());
    assert!(FlagsOracle::recorded(&manifest, "absent").is_err());
}
