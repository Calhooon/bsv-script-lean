//! #66 cut 2 (S3, lane cut2-66q2, [D] 2026-10-15): #90's and #91's scenarios on the second
//! oracle's road. Each trace of the scenario file (the primary steps and every variant, each
//! forked from the initial chain) runs on the instance's tip from fresh funding coins in a block
//! of its own, the named transactions built by the reference column's builders
//! (intake.rs `pair_transactions`, `sentinel_transactions`, the same declarations), the steps
//! applied through the instance's RPC (sendrawtransaction, invalidateblock) and the bridge (a
//! `mine` step's block, docs/CONFORMANCE-TERANODE-BRIDGE.md row 13). Each step is judged against
//! its `second_oracle` object, the Teranode column's expectation read from source through the
//! Lean model: the block-assembly set of the watched names (`store_mempool`, or one of
//! `store_mempool_one_of`), the spender of each named funding output from the store's output
//! record (`spenders`; services/asset/httpimpl/GetUTXOsByTXID.go:24-50 at the Teranode pin), and
//! a step's accept or refuse (`verdict`); the `conflicting` set has no surface (the transaction
//! meta route carries no conflicting flag, GetTransactionMeta.go:216-230) and is left unobserved. A
//! step whose object names it non-judging (a node's setting) is recorded, never judged.
use super::client::RPC_URL;
use super::road::{frame, Road};
use super::*;

/// The scenario files this module drives on the second oracle.
const SCENARIOS: [&str; 2] = [
    "2026-10-14-conflicting-spends-order",
    "2026-10-15-sentinel-refusal-pair",
];

struct Trace {
    txs: BTreeMap<String, RawTx>,
    blocks: BTreeMap<String, String>,
}

/// Fresh funding on the tip: one block carrying `n` outputs of 100,000 satoshis to the harness
/// key, each from a road coin (fee 0, a block's policy skipped). `None` when it was not accepted.
fn funding(road: &mut Road, n: usize, tag: &str) -> Result<Option<(Vec<RawTx>, String)>> {
    let mut fs = vec![];
    for _ in 0..n {
        let (coin, k) = road.coin();
        let mut f = frame(&coin, k, 100_000);
        f.version = 1;
        f.outputs[0].script = script();
        fs.push(f);
    }
    let (h, _, _, _) = road.tip()?;
    let time = road.time()?;
    let mut txs = vec![cb(h as u32 + 1, tag)];
    txs.extend(fs.iter().cloned());
    let (observed, fixtures) = road.block(&txs, time)?;
    if observed["status"] != "ok" {
        return Ok(None);
    }
    Ok(Some((
        fs,
        fixtures["hash"].as_str().unwrap_or("").to_owned(),
    )))
}

/// One trace's named transactions on fresh funding.
fn trace_for(road: &mut Road, scenario: &str, tag: &str) -> Result<Option<Trace>> {
    let pair = scenario.contains("conflicting-spends");
    let Some((fs, base)) = funding(road, if pair { 2 } else { 1 }, tag)? else {
        return Ok(None);
    };
    let txs = if pair {
        super::super::intake::pair_transactions(&fs[0], &fs[1])?
    } else {
        let p = spend(&fs[0], 99_000, 1);
        super::super::intake::sentinel_transactions(&fs[0], &p)?
    };
    Ok(Some(Trace {
        txs,
        blocks: BTreeMap::from([("base".to_owned(), base)]),
    }))
}

/// The instance's answer to one step's action.
fn act(road: &mut Road, step: &Value, trace: &mut Trace) -> Result<Value> {
    let a = &step["action"];
    match text(&a["type"])? {
        "submit" => {
            let name = text(&a["transaction"])?;
            let tx = trace.txs.get(name).ok_or("unknown transaction")?.clone();
            let reply = road
                .t
                .receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
            let accepted = reply.get("error").is_none() && road.settle(&tx)?;
            Ok(json!({"accepted":accepted,"answered":reply.get("error").is_none()}))
        }
        "submitConcurrent" => {
            let names: Vec<String> =
                serde_json::from_value(a["transactions"].clone()).map_err(|e| e.to_string())?;
            concurrent(road, &names, trace)
        }
        "mine" => {
            let parent = trace
                .blocks
                .get(text(&a["parent"])?)
                .ok_or("unknown parent")?
                .clone();
            let (h, tip, _, _) = road.tip()?;
            if tip != parent {
                return Ok(json!({"accepted":false,"setup":"parent-not-tip"}));
            }
            let mut txs = vec![cb(h as u32 + 1, text(&a["block"])?)];
            for name in a["transactions"].as_array().into_iter().flatten() {
                txs.push(
                    trace
                        .txs
                        .get(text(name)?)
                        .ok_or("unknown mined transaction")?
                        .clone(),
                );
            }
            let time = road.time()?;
            let (observed, fixtures) = road.block(&txs, time)?;
            let hash = fixtures["hash"].as_str().unwrap_or("").to_owned();
            trace
                .blocks
                .insert(text(&a["block"])?.to_owned(), hash.clone());
            Ok(
                json!({"accepted":observed["status"] == "ok","status":observed["status"],"hash":hash}),
            )
        }
        "invalidateBlock" => {
            let hash = trace
                .blocks
                .get(text(&a["block"])?)
                .ok_or("unknown block")?
                .clone();
            let reply = road.t.receipt("invalidateblock", json!([hash]))?;
            let start = Instant::now();
            while road.t.tip()?.1 == hash && start.elapsed() < Duration::from_secs(20) {
                thread::sleep(Duration::from_millis(250));
            }
            thread::sleep(Duration::from_secs(3));
            Ok(json!({"answered":reply.get("error").is_none()}))
        }
        kind => Err(format!("no second-oracle recipe for the action {kind}")),
    }
}

/// #90's concurrent pair on the instance: each transaction on its own RPC connection from its
/// own thread, released by one barrier (the reference column's `submit_concurrent`).
fn concurrent(road: &mut Road, names: &[String], trace: &Trace) -> Result<Value> {
    use std::sync::{Arc, Barrier};
    let cookie = road
        .t
        .data
        .join("rpc.cookie")
        .to_string_lossy()
        .into_owned();
    let barrier = Arc::new(Barrier::new(names.len()));
    let mut handles = vec![];
    for name in names {
        let hex = hex::encode(
            trace
                .txs
                .get(name)
                .ok_or("unknown concurrent transaction")?
                .encode(),
        );
        let (cookie, barrier) = (cookie.clone(), barrier.clone());
        handles.push(thread::spawn(move || -> Value {
            let rpc = bsv_script_harness::rpc::Rpc::new(RPC_URL, &cookie, Duration::from_secs(60));
            barrier.wait();
            let sent = Instant::now();
            let answered = match rpc {
                Ok(mut rpc) => rpc.call("sendrawtransaction", json!([hex])).is_ok(),
                Err(_) => false,
            };
            json!({"answered":answered,"seconds":sent.elapsed().as_secs_f64()})
        }));
    }
    let mut answers = serde_json::Map::new();
    for (name, h) in names.iter().zip(handles) {
        answers.insert(
            name.clone(),
            h.join().map_err(|_| "concurrent submitter panicked")?,
        );
    }
    thread::sleep(Duration::from_secs(3));
    Ok(json!({"answers":answers}))
}

/// The observation a step's `second_oracle` object is judged on.
fn observe(road: &mut Road, so: &Value, trace: &Trace) -> Result<Value> {
    let pool = road.t.pool()?;
    let mut in_pool: Vec<String> = trace
        .txs
        .iter()
        .filter(|(_, t)| pool.contains(&id(t)))
        .map(|(n, _)| n.clone())
        .collect();
    in_pool.sort();
    let mut spenders = serde_json::Map::new();
    for key in so["spenders"]
        .as_object()
        .into_iter()
        .flatten()
        .map(|(k, _)| k)
    {
        let name = key.split(':').next().unwrap_or("");
        let Some(tx) = trace.txs.get(name) else {
            continue;
        };
        let outs = road.t.utxos(&id(tx))?;
        let spender = outs["body"]
            .as_array()
            .into_iter()
            .flatten()
            .find(|o| o["vout"] == 0)
            .and_then(|o| o["spendingData"]["txId"].as_str().map(str::to_owned));
        let word = match spender {
            Some(s) => trace
                .txs
                .iter()
                .find(|(_, t)| id(t) == s)
                .map(|(n, _)| n.clone())
                .unwrap_or_else(|| "other".to_owned()),
            None => "none".to_owned(),
        };
        spenders.insert(key.clone(), json!(word));
    }
    Ok(json!({"store_mempool":in_pool,"spenders":spenders}))
}

/// One step's verdict against its `second_oracle` object.
fn judge(so: &Value, observed: &Value, answer: &Value) -> (&'static str, Vec<String>) {
    let mut differs = vec![];
    if let Some(sets) = so["store_mempool_one_of"].as_array() {
        let sorted: Vec<Value> = sets
            .iter()
            .map(|s| {
                let mut v = s.as_array().cloned().unwrap_or_default();
                v.sort_by_key(Value::to_string);
                json!(v)
            })
            .collect();
        if !sorted.contains(&observed["store_mempool"]) {
            differs.push("store_mempool_one_of".to_owned());
        }
    } else if so.get("store_mempool").is_some() && so["store_mempool"] != observed["store_mempool"]
    {
        differs.push("store_mempool".to_owned());
    }
    if so.get("spenders").is_some() && so["spenders"] != observed["spenders"] {
        differs.push("spenders".to_owned());
    }
    if let Some(v) = so["verdict"].as_str() {
        let accepted = answer["accepted"] == true;
        if (v == "accepted") != accepted {
            differs.push("verdict".to_owned());
        }
    }
    let non_judging = so["judging"]
        .as_str()
        .is_some_and(|j| j.starts_with("non-judging"));
    let verdict = if non_judging {
        "non-judging"
    } else if differs.is_empty() {
        "agree"
    } else {
        "diverge"
    };
    (verdict, differs)
}

/// Every step of both scenarios on the instance; the steps by scenario and their counts.
pub(super) fn run(road: &mut Road) -> Value {
    let mut out = vec![];
    for name in SCENARIOS {
        // lane cut2-66q4: a run of selected rows names a scenario as `scenario:<name>`.
        if !scenario_selected(name) {
            continue;
        }
        let scenario = fs::read_to_string(format!("corpus/scenarios/{name}.md"))
            .map_err(|e| e.to_string())
            .and_then(|raw| super::super::intake::scenario_json(&raw));
        let scenario = match scenario {
            Ok(s) => s,
            Err(e) => {
                out.push(json!({"scenario":name,"error":e}));
                continue;
            }
        };
        let mut traces = vec![("primary".to_owned(), scenario["steps"].clone())];
        for v in scenario["variants"].as_array().into_iter().flatten() {
            if v["fork_after"] != "initial" {
                continue;
            }
            traces.push((
                v["id"].as_str().unwrap_or("").to_owned(),
                v["steps"].clone(),
            ));
        }
        let mut steps = vec![];
        for (trace_id, trace_steps) in traces {
            let offset = road.t.calls.len();
            let trace = trace_for(road, name, &format!("{trace_id}-{}", &name[11..]));
            let mut trace = match trace {
                Ok(Some(t)) => t,
                other => {
                    for step in trace_steps.as_array().into_iter().flatten() {
                        steps.push(json!({"id":step["id"],"trace":trace_id,"verdict":"no-verdict","setup":"funding",
                            "error":other.as_ref().err(),"rpc":road.t.calls[offset..].to_vec()}));
                    }
                    continue;
                }
            };
            for step in trace_steps.as_array().into_iter().flatten() {
                let offset = road.t.calls.len();
                let so = &step["expected_observations"]["second_oracle"];
                let r = act(road, step, &mut trace)
                    .and_then(|answer| observe(road, so, &trace).map(|o| (answer, o)));
                let row = match r {
                    Ok((answer, observed)) => {
                        let (verdict, differs) = judge(so, &observed, &answer);
                        json!({"id":step["id"],"trace":trace_id,"verdict":verdict,"diverging_fields":differs,"answer":answer,"observed":observed,
                            "expected":so,"expected_label":"[D]","rpc":road.t.calls[offset..].to_vec()})
                    }
                    Err(e) => {
                        json!({"id":step["id"],"trace":trace_id,"verdict":"no-verdict","error":e,"rpc":road.t.calls[offset..].to_vec()})
                    }
                };
                road.progress(
                    &format!("{name}/{}", step["id"].as_str().unwrap_or("")),
                    &row,
                );
                steps.push(row);
            }
            let named: BTreeMap<String, Value> = trace
                .txs
                .iter()
                .map(|(n, t)| (n.clone(), material(t)))
                .collect();
            steps.push(json!({"trace":trace_id,"fixtures":named,"blocks":trace.blocks}));
        }
        let of = |v: &str| steps.iter().filter(|s| s["verdict"] == v).count();
        let counts = json!({"label":"[M]","steps":steps.iter().filter(|s| s.get("verdict").is_some()).count(),
            "agree":of("agree"),"diverge":of("diverge"),"non-judging":of("non-judging"),"no-verdict":of("no-verdict")});
        out.push(json!({"scenario":name,"counts":counts,"steps":steps}));
    }
    json!(out)
}
