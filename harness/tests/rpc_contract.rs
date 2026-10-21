//! #85 (lane rpc-85, 2026-10-15): the generated RPC contract interface, harness/src/scenarios/rpc_contract.rs, replayed
//! against the reference node's recorded replies (corpus/rpc/replies.json, written by tools/rpc_probe.py on fresh regtest
//! instances of the node of record and its wallet build). Every recorded success reply passes through its handler's typed
//! method (`call_typed`) over a transport that answers that one reply, and must re-serialize to the same JSON value: a
//! field the node writes that the contract does not list, a field it lists and the node omits, or a misnamed type fails
//! here. The runner does not call the interface yet; this test is what compiles it. No node is reached.

#[path = "../src/scenarios/rpc_contract.rs"]
mod rpc_contract;

use rpc_contract::{call_typed, RpcContract, HANDLERS};
use serde_json::Value;
use std::collections::{BTreeMap, BTreeSet};
use std::path::Path;

/// One recorded call: the transport answers its result for its method and positional arguments, and nothing else.
struct Recorded<'a> {
    method: &'a str,
    params: &'a Value,
    result: &'a Value,
}

/// JSON equality with numbers compared as f64: a typed f64 argument or field re-serializes `0` as `0.0`.
fn same(a: &Value, b: &Value) -> bool {
    match (a, b) {
        (Value::Number(x), Value::Number(y)) => x.as_f64() == y.as_f64(),
        (Value::Array(x), Value::Array(y)) => {
            x.len() == y.len() && x.iter().zip(y).all(|(p, q)| same(p, q))
        }
        (Value::Object(x), Value::Object(y)) => {
            x.len() == y.len() && x.iter().all(|(k, v)| y.get(k).is_some_and(|w| same(v, w)))
        }
        _ => a == b,
    }
}

impl RpcContract for Recorded<'_> {
    fn call_raw(&mut self, method: &str, params: Value) -> rpc_contract::Result<Value> {
        if method == self.method && same(&params, self.params) {
            Ok(self.result.clone())
        } else {
            Err(format!(
                "{method} {params}: the recorded call was {} {}",
                self.method, self.params
            ))
        }
    }
}

#[test]
fn every_recorded_reply_fits_its_handler() {
    let path = Path::new(env!("CARGO_MANIFEST_DIR")).join("../corpus/rpc/replies.json");
    let replies: BTreeMap<String, Vec<Value>> =
        serde_json::from_str(&std::fs::read_to_string(path).unwrap()).unwrap();
    let mut methods = BTreeSet::new();
    let mut refused_in_safe_mode = 0;
    for row in HANDLERS.iter() {
        assert!(row.source.starts_with("src/") && row.registration.starts_with("src/"));
        assert!(
            row.build == "record" || row.build == "wallet",
            "{}",
            row.method
        );
        assert!(row.errors.iter().all(|code| *code < 0), "{}", row.method);
        assert!(!row.second_oracle.is_empty(), "{}", row.method);
        refused_in_safe_mode += usize::from(!row.ok_safe_mode);
        methods.insert(row.method);
    }
    let mut checked = 0;
    for (method, rows) in &replies {
        assert!(
            methods.contains(method.as_str()),
            "{method}: not in the contract"
        );
        for row in rows {
            let mut node = Recorded {
                method,
                params: &row["params"],
                result: &row["result"],
            };
            let typed = call_typed(&mut node, method, &row["params"])
                .unwrap_or_else(|e| panic!("{} {}: {e}", row["phase"], row["params"]));
            assert!(
                same(&typed, &row["result"]),
                "{method} {}: the typed result re-serializes to {typed}, the node wrote {}",
                row["params"],
                row["result"]
            );
            checked += 1;
        }
    }
    let covered = replies.len();
    println!(
        "rpc_contract replay: {checked} recorded replies over {covered} of {} handlers fit their types \
         ({refused_in_safe_mode} handlers refused in safe mode)",
        HANDLERS.len()
    );
    assert!(checked > 0);
}
