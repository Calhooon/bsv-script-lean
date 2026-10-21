//! The loader proof of bsv-script-lean's bsv-rs fixtures (#146's follow-up; S3; generated files beside this one by
//! tools/fixtures_export.py, the record docs/records/20261018-000137-s3-146-fixtures-bsvrs-s3.md).
//!
//! Where it runs: in bsv-rs's own tree, never here. Copy this file to `tests/bsl_sighash_tests.rs` and the two files
//! `sighash.json` and `findings.json` to `tests/vectors/bsv-script-lean/`, then `cargo test --test bsl_sighash_tests`.
//! The run of record was a detached scratch worktree of bsv-rs at v0.7.0 (5841f98c), offline, CARGO_BUILD_JOBS=4.
//!
//! `SighashVector`, the parse and the digest are bsv-rs v0.7.0's own `tests/sighash_tests.rs:9-22` and `:35-116`
//! (`load_sighash_vectors`, `test_sighash_vectors`: the same struct, `serde_json::from_str`, `parse_transaction`
//! and `compute_sighash` with satoshis 0 and `hash_type as u32`); the loop is regrouped to list every failure, not
//! five of them. serde skips the provenance fields of findings.json (`SighashVector` has no deny_unknown_fields).
//! In sighash.json every expected_hash is the node's: the regular digest of bitcoin-sv v1.2.3's own
//! src/test/data/sighash.json row (the BIP143 rows). In findings.json it is the BIP143 digest at amount 0 over the
//! scriptCode the node selects at a CHECKSIG site where an SDK signer used another one, computed by
//! tools/fixtures_export.py, whose digest at the row's own amount equals the node-accepted control (class
//! sighash.scriptcode.in-unlock.lock-only, the caller supplying the scriptCode by design: bsv-rs v0.7.0
//! src/script/template.rs:103, :114-117, :142).
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic)]

use bsv_rs::primitives::bsv::sighash::{compute_sighash, parse_transaction, SighashParams};
use serde::Deserialize;

/// Test vector for sighash computation (bsv-rs v0.7.0 tests/sighash_tests.rs:9-17).
#[derive(Deserialize, Debug)]
struct SighashVector {
    raw_tx: String,
    script: String,
    input_index: usize,
    hash_type: i32,
    expected_hash: String,
}

/// The scriptCode an SDK's default path hashed at a finding's site and that digest (findings.json only).
#[derive(Deserialize, Debug)]
struct FindingVector {
    raw_tx: String,
    input_index: usize,
    hash_type: i32,
    expected_hash: String,
    id: String,
    class: String,
    sdk_script: String,
    sdk_hash: String,
}

fn digest(
    raw_tx: &str,
    script: &str,
    input_index: usize,
    hash_type: i32,
) -> Result<String, String> {
    let raw_tx = hex::decode(raw_tx).map_err(|e| format!("Failed to decode raw_tx: {}", e))?;
    let tx = parse_transaction(&raw_tx).map_err(|e| format!("Failed to parse tx: {}", e))?;
    let subscript = hex::decode(script).map_err(|e| format!("Failed to decode script: {}", e))?;
    if input_index >= tx.inputs.len() {
        return Err(format!(
            "Input index {} out of range (tx has {} inputs)",
            input_index,
            tx.inputs.len()
        ));
    }
    Ok(hex::encode(compute_sighash(&SighashParams {
        version: tx.version,
        inputs: &tx.inputs,
        outputs: &tx.outputs,
        locktime: tx.locktime,
        input_index,
        subscript: &subscript,
        satoshis: 0, // Test vectors use 0
        scope: hash_type as u32,
    })))
}

/// bsv-rs v0.7.0 tests/sighash_tests.rs:35-116 over one file: every vector recomputed, every failure listed.
fn check(name: &str, data: &str) -> usize {
    let vectors: Vec<SighashVector> =
        serde_json::from_str(data).expect("Failed to parse sighash vectors");
    let total = vectors.len();
    let mut passed = 0;
    let mut failures: Vec<String> = Vec::new();
    for (i, v) in vectors.iter().enumerate() {
        match digest(&v.raw_tx, &v.script, v.input_index, v.hash_type) {
            Ok(computed_hex) if computed_hex == v.expected_hash.to_lowercase() => passed += 1,
            Ok(computed_hex) => failures.push(format!(
                "Vector {}: hash_type=0x{:08x}, computed={}, expected={}",
                i, v.hash_type as u32, computed_hex, v.expected_hash
            )),
            Err(e) => failures.push(format!("Vector {}: {}", i, e)),
        }
    }
    println!(
        "bsl {}: {} passed, {} failed out of {}",
        name,
        passed,
        failures.len(),
        total
    );
    for failure in &failures {
        println!("  {}", failure);
    }
    assert!(
        failures.is_empty(),
        "{}: {} out of {} vectors failed",
        name,
        failures.len(),
        total
    );
    assert!(total > 0, "{}: no vectors", name);
    total
}

#[test]
fn bsl_node_sighash_vectors() {
    check(
        "sighash.json",
        include_str!("vectors/bsv-script-lean/sighash.json"),
    );
}

#[test]
fn bsl_signer_findings() {
    check(
        "findings.json",
        include_str!("vectors/bsv-script-lean/findings.json"),
    );
}

/// The class itself: over the scriptCode the SDK's default path used, bsv-rs computes sdk_hash (the generator's
/// digest at amount 0 over that scriptCode), and it is not expected_hash (the one over the node's scriptCode).
#[test]
fn bsl_signer_findings_default_scriptcode() {
    let data = include_str!("vectors/bsv-script-lean/findings.json");
    let vectors: Vec<FindingVector> = serde_json::from_str(data).expect("Failed to parse findings");
    let mut checked = 0;
    for v in &vectors {
        assert_eq!(
            v.class, "sighash.scriptcode.in-unlock.lock-only",
            "{}",
            v.id
        );
        let computed = digest(&v.raw_tx, &v.sdk_script, v.input_index, v.hash_type).unwrap();
        assert_eq!(
            computed, v.sdk_hash,
            "{}: the default scriptCode's digest",
            v.id
        );
        assert_ne!(
            computed, v.expected_hash,
            "{}: the default scriptCode gave expected_hash",
            v.id
        );
        checked += 1;
    }
    println!(
        "bsl findings.json default scriptCode: {} checked, each digest differs from expected_hash",
        checked
    );
    assert!(checked > 0);
}
