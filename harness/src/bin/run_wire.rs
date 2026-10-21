//! The bsv-rs column of the wire views (#86, lane wire-86, 2026-10-15): every row of
//! `corpus/wire/<format>.jsonl` through the pinned bsv-rs's own codecs (0.7.0 since #148, 2026-10-17; 0.5.0
//! at #86), one JSON line per row on stdout.
//!
//! The fields are the spec column's (`lean/Test/WireCheck.lean`): `parse` (the engine's reader took the
//! bytes), `valid` (the engine's own structural check: the BUMP constructor's root check, `Beef::is_valid`
//! with txid-only entries allowed; `null` where the engine has none), `reencode` (the engine's writer on
//! what it read), and the objects (txids in display order, roots, heights, spent outputs, entries).
//! The comparison is `tools/wire_compare.py`'s. The calls, [SRC] bsv-rs 0.7.0 (crates.io checksum of
//! Cargo.lock): `Transaction::from_ef` and `to_ef` (src/transaction/transaction.rs:221-322,1214-1279),
//! `MerklePath::from_binary`, `to_hex` and `compute_root` (src/transaction/merkle_path.rs:245-328,370,396),
//! `Beef::from_binary`, `to_binary`, `to_binary_atomic` and `is_valid` (src/transaction/beef.rs:653,
//! 983-1082,1085,1116). No network; the corpus is read only.

use bsv_rs::transaction::{Beef, MerklePath, Transaction};
use serde_json::{json, Map, Value};
use std::io::{BufRead, BufReader, Write};
use std::process::ExitCode;

fn ef_fields(bytes: &[u8]) -> Map<String, Value> {
    let mut m = Map::new();
    let Ok(tx) = Transaction::from_ef(bytes) else {
        m.insert("parse".into(), json!(false));
        return m;
    };
    m.insert("parse".into(), json!(true));
    m.insert("valid".into(), Value::Null);
    m.insert(
        "reencode".into(),
        tx.to_ef().map(hex::encode).map_or(Value::Null, Value::from),
    );
    m.insert("txid".into(), json!(tx.id()));
    m.insert("tx".into(), json!(tx.to_hex()));
    let spent: Vec<Value> = tx
        .inputs
        .iter()
        .map(|i| {
            let out = i
                .source_transaction
                .as_ref()
                .and_then(|s| s.outputs.get(i.source_output_index as usize));
            match out {
                Some(o) => json!([o.satoshis, o.locking_script.to_hex()]),
                None => Value::Null,
            }
        })
        .collect();
    m.insert("spent".into(), json!(spent));
    m
}

fn bump_objects(mp: &MerklePath) -> Map<String, Value> {
    let mut m = Map::new();
    m.insert("height".into(), json!(mp.block_height));
    m.insert(
        "root".into(),
        mp.compute_root(None).map_or(Value::Null, Value::from),
    );
    let txids: Vec<Value> = mp
        .path
        .first()
        .map(|lv| {
            lv.iter()
                .filter(|l| l.txid)
                .map(|l| {
                    let root = l
                        .hash
                        .as_deref()
                        .and_then(|h| mp.compute_root(Some(h)).ok());
                    json!({"offset": l.offset, "txid": l.hash, "root": root})
                })
                .collect()
        })
        .unwrap_or_default();
    m.insert("txids".into(), json!(txids));
    m
}

fn bump_fields(bytes: &[u8]) -> Map<String, Value> {
    match MerklePath::from_binary(bytes) {
        Ok(mp) => {
            let mut m = bump_objects(&mp);
            m.insert("parse".into(), json!(true));
            m.insert("valid".into(), json!(true));
            m.insert("reencode".into(), json!(mp.to_hex()));
            m
        }
        Err(_) => {
            let mut m = Map::new();
            m.insert("parse".into(), json!(false));
            m
        }
    }
}

fn beef_objects(b: &Beef) -> Map<String, Value> {
    let mut m = Map::new();
    m.insert(
        "version".into(),
        json!(if b.version == bsv_rs::transaction::BEEF_V1 {
            1
        } else {
            2
        }),
    );
    let bumps: Vec<Value> = b
        .bumps
        .iter()
        .map(|x| json!({"height": x.block_height, "root": x.compute_root(None).ok()}))
        .collect();
    m.insert("bumps".into(), json!(bumps));
    let txs: Vec<Value> = b
        .txs
        .iter()
        .map(|t| {
            let txid = t.txid();
            let kind = if t.is_txid_only() {
                "txid"
            } else if t.bump_index().is_some() {
                "raw+bump"
            } else {
                "raw"
            };
            let mined = t.bump_index().map(|i| match b.bumps.get(i) {
                None => json!("unresolved"),
                Some(x) => {
                    let index = x.path.first().and_then(|lv| {
                        lv.iter().find(|l| l.hash.as_deref() == Some(txid.as_str()))
                    });
                    match index {
                        Some(l) => json!({"height": x.block_height, "index": l.offset,
                                      "root": x.compute_root(Some(txid.as_str())).ok()}),
                        None => json!("unresolved"),
                    }
                }
            });
            json!({"txid": txid, "kind": kind, "bump": t.bump_index(), "mined": mined})
        })
        .collect();
    m.insert("txs".into(), json!(txs));
    m
}

fn beef_fields(bytes: &[u8], atomic: bool) -> Map<String, Value> {
    let parsed = Beef::from_binary(bytes);
    let mut b = match parsed {
        Ok(b) if b.is_atomic() == atomic => b,
        _ => {
            let mut m = Map::new();
            m.insert("parse".into(), json!(false));
            return m;
        }
    };
    let mut m = beef_objects(&b);
    m.insert("parse".into(), json!(true));
    m.insert("valid".into(), json!(b.is_valid(true)));
    let reencode = match b.atomic_txid.clone() {
        Some(t) => {
            m.insert("subject".into(), json!(t));
            b.to_binary_atomic(&t).ok().map(hex::encode)
        }
        None => Some(hex::encode(b.to_binary())),
    };
    m.insert("reencode".into(), json!(reencode));
    m
}

/// The TSC rows: no bsv-rs codec reads the TSC binary form; the engine reads the BUMP WhatsOnChain
/// serves for the same transaction and computes the subject's root, which the comparison sets
/// against the root the spec computes from the TSC proof.
fn tsc_fields(row: &Value) -> Map<String, Value> {
    let mut m = Map::new();
    m.insert("parse".into(), Value::Null);
    let root = row
        .get("bump_hex")
        .and_then(Value::as_str)
        .and_then(|h| MerklePath::from_hex(h).ok())
        .and_then(|mp| {
            let subject = row.get("subject").and_then(Value::as_str)?;
            mp.compute_root(Some(subject)).ok()
        });
    m.insert("read_bump_root".into(), json!(root));
    m
}

fn line(row: &Value) -> Result<Value, String> {
    let id = row
        .get("id")
        .and_then(Value::as_str)
        .ok_or("a row without an id")?;
    let format = row
        .get("format")
        .and_then(Value::as_str)
        .ok_or("a row without a format")?;
    let bytes = hex::decode(row.get("hex").and_then(Value::as_str).unwrap_or_default())
        .map_err(|e| format!("{id}: {e}"))?;
    let mut m = match format {
        "ef" => ef_fields(&bytes),
        "bump" => bump_fields(&bytes),
        "beef" => beef_fields(&bytes, false),
        "atomic-beef" => beef_fields(&bytes, true),
        "tsc" => tsc_fields(row),
        other => return Err(format!("{id}: unknown format {other}")),
    };
    m.insert("id".into(), json!(id));
    m.insert("format".into(), json!(format));
    m.insert("impl".into(), json!(bsv_script_harness::BSV_RS_KEY));
    Ok(Value::Object(m))
}

fn main() -> ExitCode {
    let paths: Vec<String> = std::env::args().skip(1).collect();
    if paths.is_empty() {
        eprintln!("usage: run_wire corpus/wire/<format>.jsonl ...");
        return ExitCode::from(2);
    }
    let stdout = std::io::stdout();
    let mut out = stdout.lock();
    let (mut rows, mut bad) = (0usize, 0usize);
    for path in &paths {
        let file = match std::fs::File::open(path) {
            Ok(f) => f,
            Err(e) => {
                eprintln!("run_wire: {path}: {e}");
                return ExitCode::from(2);
            }
        };
        for text in BufReader::new(file).lines().map_while(Result::ok) {
            if text.trim().is_empty() {
                continue;
            }
            let result = serde_json::from_str::<Value>(&text)
                .map_err(|e| e.to_string())
                .and_then(|r| line(&r));
            match result {
                Ok(v) => {
                    rows += 1;
                    if writeln!(out, "{v}").is_err() {
                        return ExitCode::from(2);
                    }
                }
                Err(e) => {
                    bad += 1;
                    eprintln!("run_wire: {e}");
                }
            }
        }
    }
    eprintln!(
        "run_wire: {rows} rows, {bad} unreadable ({})",
        bsv_script_harness::BSV_RS_KEY
    );
    if bad == 0 {
        ExitCode::SUCCESS
    } else {
        ExitCode::from(1)
    }
}
