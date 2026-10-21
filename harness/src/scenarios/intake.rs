//! Family-owned realization recipes. Sources and observation boundaries are retained in receipts.
use super::core::*;

pub(super) fn scenario_json(raw: &str) -> Result<Value> {
    serde_json::from_str(
        raw.split_once("```json\n")
            .ok_or("missing JSON fence")?
            .1
            .split_once("\n```")
            .ok_or("missing closing fence")?
            .0,
    )
    .map_err(|e| e.to_string())
}
pub(super) fn mark_scenario(path: &Path, result: &Value) -> Result<()> {
    let mut raw = fs::read_to_string(path).map_err(|e| e.to_string())?;
    for row in result["steps"].as_array().ok_or("scenario rows")? {
        if row.get("verdict").is_none() {
            continue;
        }
        let key = format!(
            "\"id\": {}",
            serde_json::to_string(&row["id"]).or_err("serde_json::to_string(&row['id'])")?
        );
        let position = raw.find(&key).ok_or("scenario step id absent")?;
        let start = raw[..position].rfind('{').ok_or("step object absent")?;
        let mut stream = serde_json::Deserializer::from_str(&raw[start..]).into_iter::<Value>();
        let step = stream
            .next()
            .ok_or("step absent")?
            .map_err(|e| e.to_string())?;
        let end = start + stream.byte_offset();
        // lane cut2-66q2: a step's `second_oracle` object carries the second oracle's own
        // marker (#90), never the reference's token: its subtree is skipped here, and the
        // replacement below runs on the segment outside it.
        fn node_values(v: &Value, values: &mut BTreeSet<String>) {
            if let Some(o) = v.as_object() {
                for (key, value) in o {
                    if key == "second_oracle" {
                        continue;
                    }
                    if key == "node" {
                        if let Some(s) = value.as_str() {
                            values.insert(s.into());
                        }
                    } else {
                        node_values(value, values);
                    }
                }
            } else if let Some(a) = v.as_array() {
                for value in a {
                    node_values(value, values);
                }
            }
        }
        let mut values = BTreeSet::new();
        node_values(&step, &mut values);
        let mut segment = raw[start..end].to_owned();
        // The second oracle's objects are cut out, the reference's markers replaced, and put back.
        let mut kept = vec![];
        while let Some(at) = segment.find("\"second_oracle\": {") {
            let open = at + 17;
            let mut stream =
                serde_json::Deserializer::from_str(&segment[open..]).into_iter::<Value>();
            stream
                .next()
                .ok_or("second oracle object absent")?
                .map_err(|e| e.to_string())?;
            let close = open + stream.byte_offset();
            kept.push(segment[at..close].to_owned());
            segment.replace_range(at..close, &format!("@@second-oracle-{}@@", kept.len() - 1));
        }
        for old in values {
            segment = segment.replace(
                &format!(
                    "\"node\": {}",
                    serde_json::to_string(&old).or_err("serde_json::to_string(&old)")?
                ),
                &format!(
                    "\"node\": {}",
                    serde_json::to_string(&row["node"])
                        .or_err("serde_json::to_string(&row['node'])")?
                ),
            );
        }
        for (k, object) in kept.iter().enumerate() {
            segment = segment.replace(&format!("@@second-oracle-{k}@@"), object);
        }
        if let Some(client) = segment.find("\"client_evidence\"") {
            let open = segment[client..]
                .find('{')
                .ok_or("client evidence object absent")?
                + client;
            let mut stream =
                serde_json::Deserializer::from_str(&segment[open..]).into_iter::<Value>();
            let value = stream
                .next()
                .ok_or("client evidence absent")?
                .map_err(|e| e.to_string())?;
            let close = open + stream.byte_offset();
            if let Some(old) = value["node"].as_str() {
                let client_segment = replace_node(&segment[open..close], old, "pending #66")?;
                segment.replace_range(open..close, &client_segment);
            }
        }
        if let Some(event) = row.get("assembly").filter(|e| e.is_object()) {
            segment = mark_assembly(&segment, event, text(&row["node"])?)?;
        }
        raw.replace_range(start..end, &segment);
    }
    fs::write(path, raw).map_err(|e| e.to_string())
}
// [D] 2026-10-13 (#72): write the node's observed body into the step's action
// (`transactions`, which the machine replays) and an `assembly` line naming it
// as an observation and its record. Every other byte of the step is kept.
fn mark_assembly(segment: &str, event: &Value, node: &str) -> Result<String> {
    let open = segment
        .find("\"action\": {")
        .ok_or("mine step action absent")?
        + 10;
    let mut stream = serde_json::Deserializer::from_str(&segment[open..]).into_iter::<Value>();
    stream
        .next()
        .ok_or("action absent")?
        .map_err(|e| e.to_string())?;
    let close = open + stream.byte_offset();
    let mut action = segment[open..close].to_owned();
    let record = node
        .rsplit_once("[X] ")
        .map(|(_, r)| r)
        .ok_or("node token record")?;
    let line = format!(
        "observed (#72): the node's generatetoaddress body; the machine replays it [X] {record}"
    );
    if let Some(at) = action.find("\"assembly\": ") {
        let value = at + 12;
        let mut stream = serde_json::Deserializer::from_str(&action[value..]).into_iter::<Value>();
        stream
            .next()
            .ok_or("assembly value")?
            .map_err(|e| e.to_string())?;
        let end = value + stream.byte_offset();
        action.replace_range(
            value..end,
            &serde_json::to_string(&line).or_err("serde_json::to_string(&line)")?,
        );
    }
    let key = action
        .find("\"transactions\": [")
        .ok_or("mine transactions absent")?;
    let indent = &action[action[..key].rfind('\n').ok_or("indent")? + 1..key];
    let indent = indent.to_owned();
    let array = key + 16;
    let end = array + action[array..].find(']').ok_or("transactions end")? + 1;
    let names: Vec<String> = serde_json::from_value(event["observed_transactions"].clone())
        .map_err(|e| e.to_string())?;
    let mut text = String::from("[");
    for (i, name) in names.iter().enumerate() {
        text.push_str(if i == 0 { "\n" } else { ",\n" });
        text.push_str(&format!(
            "{indent}  {}",
            serde_json::to_string(name).or_err("serde_json::to_string(name)")?
        ));
    }
    text.push_str(&if names.is_empty() {
        "]".to_owned()
    } else {
        format!("\n{indent}]")
    });
    if !action.contains("\"assembly\": ") {
        text.push_str(&format!(
            ",\n{indent}\"assembly\": {}",
            serde_json::to_string(&line).or_err("serde_json::to_string(&line)")?
        ));
    }
    action.replace_range(array..end, &text);
    Ok(format!(
        "{}{}{}",
        &segment[..open],
        action,
        &segment[close..]
    ))
}

fn expected_projection(step: &Value) -> Value {
    let e = &step["expected_observations"];
    let mut statuses = serde_json::Map::new();
    if let Some(txs) = e["transactions"].as_object() {
        for (name, t) in txs {
            let mut status = json!({"value":t["value"]});
            for k in ["height", "code", "namespace", "reason"] {
                if let Some(v) = t.get(k) {
                    status[k] = v.clone();
                }
            }
            statuses.insert(name.clone(), status);
        }
    }
    let mut tips = e["chain_tips"].as_array().cloned().unwrap_or_default();
    tips.sort_by_key(|v| v["block"].to_string());
    let mut pool = e["mempool"].as_array().cloned().unwrap_or_default();
    pool.sort_by_key(Value::to_string);
    let mut held = e["non_final_pool"].as_array().cloned().unwrap_or_default();
    held.sort_by_key(Value::to_string);
    json!({"mempool":pool,"non_final_pool":held,"chain_tips":tips,"tip":e["tip"],"transactions":statuses,"utxos":e["utxos"]})
}
fn actual_projection(
    raw: &Value,
    txs: &BTreeMap<String, RawTx>,
    blocks: &BTreeMap<String, String>,
    spenders: bool,
) -> Result<Value> {
    let tx_name = |hash: &Value| {
        txs.iter()
            .find(|(_, tx)| json!(id(tx)) == *hash)
            .map(|(n, _)| json!(n))
            .unwrap_or(hash.clone())
    };
    let block_name = |hash: &Value| {
        blocks
            .iter()
            .find(|(_, h)| json!(h) == *hash)
            .map(|(n, _)| json!(n))
            .unwrap_or(hash.clone())
    };
    let mut pool: Vec<Value> = raw["mempool"]
        .as_array()
        .ok_or("pool")?
        .iter()
        .map(tx_name)
        .collect();
    pool.sort_by_key(Value::to_string);
    let mut held: Vec<Value> = raw["non_final_pool"]
        .as_array()
        .ok_or("held")?
        .iter()
        .map(tx_name)
        .collect();
    held.sort_by_key(Value::to_string);
    let mut tips = vec![];
    let mut tip = Value::Null;
    for t in raw["chain_tips"].as_array().ok_or("chain tips")? {
        let name = block_name(&t["hash"]);
        if t["hash"] == raw["best"] {
            tip = json!({"block":name,"height":t["height"]});
        }
        tips.push(json!({"block":name,"status":t["status"]}));
    }
    tips.sort_by_key(|v| v["block"].to_string());
    let mut statuses = serde_json::Map::new();
    let mut utxos = serde_json::Map::new();
    for name in txs.keys() {
        statuses.insert(name.clone(), raw["transactions"][name]["status"].clone());
    }
    for (name, tx) in txs {
        // A funding transaction's output is `fund` (F; #90's F1 and F2), any other's `credit`.
        let fund = name.starts_with('F');
        let word = if spenders {
            spender_word(name, tx, raw, txs, &statuses, fund)
        } else if !raw["outputs"][name].is_null() {
            "unspent".to_owned()
        } else if fund {
            "spent".to_owned()
        } else {
            "absent".to_owned()
        };
        utxos.insert(
            format!("{name}:{}", if fund { "fund" } else { "credit" }),
            json!(word),
        );
    }
    Ok(
        json!({"mempool":pool,"non_final_pool":held,"chain_tips":tips,"tip":tip,"transactions":statuses,"utxos":utxos}),
    )
}
/// [D] 2026-10-15, lane cut2-66q2 (#90's vocabulary): the word of one output against the named
/// transactions. On the chain (gettxout without the pool): spent in the pool by the named
/// transaction whose input is the output, or unspent. Off the chain: a funding output spent by
/// the named transaction mined in an active block, `spent` when none is named, any other
/// output `absent`.
fn spender_word(
    name: &str,
    tx: &RawTx,
    raw: &Value,
    txs: &BTreeMap<String, RawTx>,
    statuses: &serde_json::Map<String, Value>,
    fund: bool,
) -> String {
    let outpoint = tx.txid_internal();
    let spends = |t: &RawTx| t.inputs.iter().any(|i| i.txid == outpoint && i.vout == 0);
    let pool: Vec<Value> = raw["mempool"].as_array().cloned().unwrap_or_default();
    if !raw["outputs"][name].is_null() {
        match txs
            .iter()
            .find(|(n, t)| *n != name && pool.contains(&json!(id(t))) && spends(t))
        {
            Some((n, _)) => format!("spent in pool by {n}"),
            None => "unspent".to_owned(),
        }
    } else if fund {
        match txs.iter().find(|(n, t)| {
            *n != name
                && statuses
                    .get(*n)
                    .is_some_and(|s| s["value"] == "minedActive")
                && spends(t)
        }) {
            Some((n, _)) => format!("spent by {n} (active)"),
            None => "spent".to_owned(),
        }
    } else {
        "absent".to_owned()
    }
}

/// [D] 2026-10-15, lane cut2-66q2: the observed state against a step's expectation. A
/// `*_one_of` key (#90's `mempool_one_of`) holds when the observed set is one of its sets; the
/// transactions and outputs compared are the ones the step names.
fn judge_projection(step: &Value, expected: &mut Value, actual: &mut Value) -> bool {
    let e = &step["expected_observations"];
    if let Some(sets) = e["mempool_one_of"].as_array() {
        let sets: Vec<Value> = sets
            .iter()
            .map(|set| {
                let mut v = set.as_array().cloned().unwrap_or_default();
                v.sort_by_key(Value::to_string);
                json!(v)
            })
            .collect();
        expected["mempool"] = if sets.contains(&actual["mempool"]) {
            actual["mempool"].clone()
        } else {
            json!({"one_of":sets})
        };
    }
    let named: BTreeSet<String> = expected["transactions"]
        .as_object()
        .map(|o| o.keys().cloned().collect())
        .unwrap_or_default();
    if let Some(o) = actual["transactions"].as_object_mut() {
        o.retain(|k, _| named.contains(k));
    }
    match expected["utxos"].as_object() {
        Some(u) => {
            let keys: BTreeSet<String> = u.keys().cloned().collect();
            if let Some(o) = actual["utxos"].as_object_mut() {
                o.retain(|k, _| keys.contains(k));
            }
        }
        None => actual["utxos"] = Value::Null,
    }
    expected == actual
}

/// [D] 2026-10-15, lane cut2-66q2 (#90's `submitConcurrent`): the named transactions sent
/// together, each on its own RPC connection from its own thread, released by one barrier, so
/// neither waits for the other's reply. The reference serializes the conflicting pair in its
/// validator: the double-spend detector admits one claim per outpoint
/// (src/txn_double_spend_detector.cpp:11-57) before the conflict stage
/// (src/validation.cpp:1147-1152) at PIN. Each reply is journaled; a refusal is recorded in
/// `rejected` as a submit's is.
fn submit_concurrent(
    n: &mut Node,
    names: &[String],
    txs: &BTreeMap<String, RawTx>,
    rejected: &mut BTreeMap<String, Value>,
) -> Result<()> {
    use std::sync::{Arc, Barrier};
    let port = n
        .conf
        .lines()
        .find_map(|l| l.strip_prefix("rpcport="))
        .ok_or("the instance's rpcport")?
        .to_owned();
    let cookie = n.dir.join("regtest/.cookie").to_string_lossy().into_owned();
    let barrier = Arc::new(Barrier::new(names.len()));
    let mut handles = vec![];
    for name in names {
        let tx = txs.get(name).ok_or("unknown concurrent transaction")?;
        n.seen.insert(id(tx));
        let hex = hex::encode(tx.encode());
        let (url, cookie, barrier) = (
            format!("http://127.0.0.1:{port}"),
            cookie.clone(),
            barrier.clone(),
        );
        handles.push(thread::spawn(move || -> Value {
            let rpc = Rpc::new(&url, &cookie, Duration::from_secs(30));
            barrier.wait();
            let sent = Instant::now();
            let reply = match rpc {
                Ok(mut rpc) => match rpc.call("sendrawtransaction", json!([hex])) {
                    Ok(v) => json!({"result":v}),
                    Err(e) => json!({"error":e.strip_prefix("rpc error: ").and_then(|s| serde_json::from_str::<Value>(s).ok()).unwrap_or(json!({"transport":e}))}),
                },
                Err(e) => json!({"error":{"transport":e}}),
            };
            json!({"reply":reply,"seconds":sent.elapsed().as_secs_f64()})
        }));
    }
    for (name, handle) in names.iter().zip(handles) {
        let answer = handle.join().map_err(|_| "concurrent submitter panicked")?;
        if answer["reply"].get("error").is_some() {
            if let Some(r) = node_reject(&answer["reply"]) {
                rejected.insert(name.clone(), r);
            }
        }
        n.calls.push(json!({"method":"sendrawtransaction","concurrent":true,"transaction":name,"reply":answer["reply"],"seconds":answer["seconds"],
            "source":format!("[SRC] {} at {PIN}; one connection per transaction, released together (src/txn_double_spend_detector.cpp:11-57)",handler("sendrawtransaction")?)}));
    }
    Ok(())
}

fn apply_step(
    n: &mut Node,
    step: &Value,
    txs: &BTreeMap<String, RawTx>,
    blocks: &mut BTreeMap<String, String>,
    rejected: &mut BTreeMap<String, Value>,
) -> Result<()> {
    let a = &step["action"];
    if let Some(now) = a.get("now") {
        n.call("setmocktime", json!([now]))?;
    }
    match text(&a["type"])? {
        "submit" => {
            let name = text(&a["transaction"])?;
            let tx = txs.get(name).ok_or("unknown transaction")?;
            n.seen.insert(id(tx));
            // lane cut2-66q2: a refusal is the node's answer (#90's s2), journaled, never a stop.
            let receipt = n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
            if receipt.get("error").is_some() {
                if let Some(r) = node_reject(&receipt) {
                    rejected.insert(name.to_owned(), r);
                }
            }
        }
        "submitConcurrent" => {
            let names: Vec<String> =
                serde_json::from_value(a["transactions"].clone()).map_err(|e| e.to_string())?;
            submit_concurrent(n, &names, txs, rejected)?;
        }
        "mine" => {
            let parent = blocks
                .get(text(&a["parent"])?)
                .ok_or("unknown block parent")?;
            if n.call("getbestblockhash", json!([]))? != *parent {
                return Err(
                    "named parent is not the selected tip; explicit branch switch required".into(),
                );
            }
            let hash = if a["method"] == "submitblock" {
                let height = n.tip()?["height"].as_u64().ok_or("tip height")? + 1;
                let mut body = vec![cb(height as u32, text(&a["block"])?)];
                for name in a["transactions"].as_array().ok_or("mined transactions")? {
                    body.push(
                        txs.get(text(name)?)
                            .ok_or("unknown mined transaction")?
                            .clone(),
                    );
                }
                let (hash, receipt) =
                    n.submit(&body, a["now"].as_u64().ok_or("block clock")? as u32)?;
                if block_judgment(&receipt) != json!({"status":"ok"}) {
                    return Err(format!("scenario block refused: {receipt}"));
                }
                hash
            } else {
                // [X] 2026-10-13 (#72): the node assembles; the runner reads the
                // body it chose (src/mining/journaling_block_assembler.cpp:80-97;
                // src/rpc/mining.cpp:161-224 at PIN) and names it. `transactions`
                // is the observed body the machine replays, never a prediction.
                let pool = n.call("getrawmempool", json!([]))?;
                let hash =
                    text(&n.mine(1, a["now"].as_u64().ok_or("mining clock")?)?[0])?.to_owned();
                let body = n.body(&json!(hash))?;
                let after = n.call("getrawmempool", json!([]))?;
                let observed: Vec<String> = body
                    .iter()
                    .map(|txid| {
                        txs.iter()
                            .find(|(_, tx)| id(tx) == *txid)
                            .map(|(name, _)| name.clone())
                            .unwrap_or_else(|| txid.clone())
                    })
                    .collect();
                let declared: Vec<String> =
                    serde_json::from_value(a["transactions"].clone()).map_err(|e| e.to_string())?;
                let set = |v: &Value| -> Result<BTreeSet<String>> {
                    serde_json::from_value(v.clone()).map_err(|e| e.to_string())
                };
                let (before_set, after_set) = (set(&pool)?, set(&after)?);
                let body_set: BTreeSet<String> = body.iter().cloned().collect();
                // Applied to the observed body, the pool loses exactly that body.
                let applied = body_set.is_subset(&before_set)
                    && after_set == before_set.difference(&body_set).cloned().collect();
                n.calls.push(json!({"event":"mined-body","label":"[X]","block":a["block"],"hash":hash,
                    "observed_transactions":observed,"declared_transactions":declared,
                    "body_equals_declared":observed == declared,"pool_before":pool,"pool_after":after,
                    "body_application_agrees":applied,
                    "source":format!("[SRC] src/mining/journaling_block_assembler.cpp:80-97; src/rpc/mining.cpp:161-224 at {PIN}")}));
                hash
            };
            n.call("getblock", json!([hash, 0]))?;
            blocks.insert(text(&a["block"])?.into(), hash);
        }
        "invalidateBlock" | "reconsiderBlock" => {
            let hash = blocks.get(text(&a["block"])?).ok_or("unknown block")?;
            n.call(
                if a["type"] == "invalidateBlock" {
                    "invalidateblock"
                } else {
                    "reconsiderblock"
                },
                json!([hash]),
            )?;
        }
        "advanceTime" => {
            if a["trigger"]["rpc"] != "sendrawtransactions" {
                return Err("unsupported maintenance trigger".into());
            }
            let log = n.dir.join("console.log");
            let before = fs::metadata(&log).map_err(|e| e.to_string())?.len() as usize;
            let mut probes = vec![];
            for lock_time in 0..2 {
                let probe = RawTx {
                    version: 1,
                    inputs: vec![],
                    outputs: vec![RawOutput {
                        satoshis: 1,
                        script: script(),
                    }],
                    lock_time,
                };
                probes.push(json!({"hex":hex::encode(probe.encode())}));
            }
            let reply = n.call("sendrawtransactions", json!([probes]))?;
            let rejected = reply["invalid"]
                .as_array()
                .ok_or("missing sweep rejection receipts")?;
            if rejected.len() != 2
                || rejected
                    .iter()
                    .any(|r| r["reject_reason"] != "bad-txns-vin-empty")
            {
                return Err(format!("unexpected sweep receipts: {reply}"));
            }
            let start = Instant::now();
            loop {
                let bytes = fs::read(&log).map_err(|e| e.to_string())?;
                let fresh = String::from_utf8_lossy(bytes.get(before..).unwrap_or_default());
                if let Some(line) = fresh
                    .lines()
                    .find(|l| l.contains("Expired 1 transactions from the memory pool"))
                {
                    n.calls.push(json!({"event":"maintenance-completion","source":format!("[SRC] src/validation.cpp:853-856; src/rawtxvalidator.cpp:64-91 at {PIN}"),"log":line,"rpc_completed":true,"auxiliary_rejections":reply}));
                    break;
                }
                if start.elapsed() > Duration::from_secs(10) {
                    return Err("expiry completion log not witnessed".into());
                }
                thread::sleep(Duration::from_millis(50));
            }
        }
        "checkPath" => {
            let tx = txs
                .get(text(&a["transaction"])?)
                .ok_or("unknown proof transaction")?;
            let block = blocks
                .get(text(&a["block"])?)
                .ok_or("unknown proof block")?;
            // [D] 2026-10-13: replay the identical stored proof after invalidation.
            let proof = if a["reuse"] == true {
                n.calls
                    .iter()
                    .rev()
                    .find(|event| event["event"] == "path-comparison" && event["leaf"] == id(tx))
                    .and_then(|event| event.get("proof"))
                    .cloned()
                    .ok_or("no stored proof")?
            } else {
                n.call("getmerkleproof", json!([id(tx), block]))?
            };
            let body = n.call("getblock", json!([block, 1]))?;
            let index = proof["index"].as_u64().ok_or("missing proof index")?;
            let mut hash = txid_from_display_hex(text(&proof["txOrId"])?)?;
            let leaf_ok = proof["txOrId"] == id(tx)
                && body["tx"].get(index as usize) == Some(&proof["txOrId"]);
            let mut position = index;
            for sibling in proof["nodes"].as_array().ok_or("missing proof branch")? {
                let other = if sibling == "*" {
                    hash
                } else {
                    txid_from_display_hex(text(sibling)?)?
                };
                let pair = if position & 1 == 0 {
                    [hash, other].concat()
                } else {
                    [other, hash].concat()
                };
                hash = bsv_script_harness::txraw::sha256d(&pair);
                position >>= 1;
            }
            let root_ok = txid_display_hex(&hash) == text(&body["merkleroot"])?;
            let active = body["confirmations"].as_i64().unwrap_or(0) > 0;
            let expected_active = a["active"].as_bool().unwrap_or(true);
            let nodes: Vec<Vec<u8>> = proof["nodes"]
                .as_array()
                .ok_or("branch")?
                .iter()
                .map(|node| {
                    if node == "*" {
                        Ok(vec![0; 32])
                    } else {
                        txid_from_display_hex(text(node)?).map(|h| h.to_vec())
                    }
                })
                .collect::<Result<_>>()?;
            let vector = json!({"leaf":txid_from_display_hex(text(&proof["txOrId"])?)?,
                "path":nodes,"index":index,"root":txid_from_display_hex(text(&proof["target"]["merkleroot"])?)?});
            let lean = Command::new("lean/.lake/build/bin/chaincheck")
                .args(["--verify-path", &vector.to_string()])
                .output()
                .map_err(|e| e.to_string())?;
            if !lean.status.success() || String::from_utf8_lossy(&lean.stdout).trim() != "true" {
                return Err(format!(
                    "Lean path check failed: {}",
                    String::from_utf8_lossy(&lean.stderr)
                ));
            }
            let mut active_absent = true;
            if !expected_active {
                let tip_height = n.tip()?["height"].as_u64().ok_or("tip height")?;
                for height in 0..=tip_height {
                    let hash = n.call("getblockhash", json!([height]))?;
                    let active_body = n.call("getblock", json!([hash, 1]))?;
                    if active_body["tx"]
                        .as_array()
                        .ok_or("active body")?
                        .contains(&json!(id(tx)))
                    {
                        active_absent = false;
                    }
                }
            }
            if !leaf_ok
                || !root_ok
                || active != expected_active
                || (!expected_active && !active_absent)
                || position != 0
                || proof["target"]["hash"] != *block
            {
                return Err(format!("proof validation failed: {proof}"));
            }
            n.calls.push(json!({"event":"path-comparison","leaf":id(tx),"index":index,"branch":proof["nodes"],"root":txid_display_hex(&hash),"leaf_in_body":leaf_ok,"root_equal":root_ok,"active":active,"label":"[X]","lean_verifyPath":true,"active_absent":if expected_active { Value::Null } else { json!(active_absent) },"proof":proof,"theorem":"BsvChain.Properties.active_path_inclusion; hypotheses explicit"}));
        }
        "observeClient" | "serveBeef" | "walletRoundTrip" => {}
        kind => return Err(format!("unsupported action {kind}")),
    }
    Ok(())
}
pub(super) fn scenario_run(path: &Path, root: &Path, record: &str) -> Result<Value> {
    let raw = fs::read_to_string(path).map_err(|e| e.to_string())?;
    let scenario = scenario_json(&raw)?;
    let name = text(&scenario["id"])?;
    let profile = fs::read_to_string("corpus/scenarios/README.md").map_err(|e| e.to_string())?;
    let size = if profile.contains("excessiveBlockSize = 1000001") {
        1_000_001
    } else if profile.contains("excessiveBlockSize = 1000000") {
        1_000_000
    } else {
        return Err("unrecognized intake block size".into());
    };
    let primary = scenario["steps"].as_array().ok_or("steps")?;
    let mut traces = vec![("primary".to_owned(), vec![], primary.clone(), String::new())];
    for variant in scenario["variants"].as_array().ok_or("variants")? {
        // lane cut2-66q2 (#90): `fork_after: "initial"` forks before any step of the trace.
        let prefix = if variant["fork_after"] == "initial" {
            vec![]
        } else {
            let checkpoint = primary
                .iter()
                .position(|s| s["id"] == variant["fork_after"])
                .ok_or("missing checkpoint")?;
            primary[..=checkpoint].to_vec()
        };
        // lane cut2-66q2 (#91): a variant's `config` lines start its instance (the promiscuous word).
        let config = variant["config"]
            .as_str()
            .map(|c| format!("{c}\n"))
            .unwrap_or_default();
        traces.push((
            text(&variant["id"])?.to_owned(),
            prefix,
            variant["steps"].as_array().ok_or("variant steps")?.clone(),
            config,
        ));
    }
    let mut rows = vec![];
    let mut launches = vec![];
    for (trace, prefix, steps, config) in traces {
        // Independent replay recreates the checkpoint, including journals. It
        // does not reuse the state left by another variant.
        let extra = format!("debug=mempool\n{config}");
        let mut n = match start_retry_size(root, &format!("{name}-{trace}"), size, &extra) {
            Ok(n) => n,
            Err(e) => {
                for step in steps {
                    rows.push(json!({"id":step["id"],"node":"pending #66","reason":e}));
                }
                launches.push(json!({"trace":trace,"status":"blocked","reason":e}));
                continue;
            }
        };
        // lane cut2-66q2 (#90): the conflicting-spends scenario funds F1 and F2 (`seed_pair`).
        let pair = name.contains("conflicting-spends");
        let (f, t, base, pair_txs) = if pair {
            let (f1, f2, base) = seed_pair(&mut n)?;
            let txs = pair_transactions(&f1, &f2)?;
            (f1.clone(), f2.clone(), base, Some(txs))
        } else {
            let (f, t, base) = seed(&mut n)?;
            (f, t, base, None)
        };
        // The prefix's height-one block contains only its coinbase: #75 boundary.
        let prefix_hash = n
            .calls
            .iter()
            .find(|c| c["method"] == "generatetoaddress")
            .and_then(|c| c["reply"]["result"][0].as_str())
            .map(str::to_owned);
        let single_transaction_proof = if let Some(hash) = prefix_hash {
            let body = n.call("getblock", json!([hash, 1]))?;
            let leaf = body["tx"][0].clone();
            let reply = n.receipt("getmerkleproof", json!([leaf, hash]))?;
            json!({"block":body,"leaf":leaf,"body_index":0,"body_branch":[],"rpc_receipt":reply,"note":"index and empty branch are derived from the single-entry body; retain exactly what the RPC returns"})
        } else {
            return Err("missing prefix mining receipt".into());
        };
        let other = if name.contains("proof") {
            ("U", spend(&t, 98000, 1))
        } else if name.contains("assembly") {
            // [D] 2026-10-13 (#72): L spends height 2's coinbase with a fee of
            // 50 satoshis, below -minminingtxfee's 500 satoshis/kB for its
            // size: admitted (the reject fee is the rolling minimum,
            // src/validation.cpp:1284-1295) and left secondary, outside the
            // assembler's journal (src/txmempool.cpp:411-414,574-600 at PIN).
            let hash = n.call("getblockhash", json!([2]))?;
            let block = n.call("getblock", json!([hash, 1]))?;
            let coin = n.raw_tx(&block["tx"][0])?;
            ("L", spend(&coin, coin.outputs[0].satoshis - 50, 1))
        } else {
            ("K", spend(&f, 98000, 2))
        };
        let txs = match pair_txs {
            Some(txs) => txs,
            // lane cut2-66q2 (#91): P (the seed's T) and its child Q; N to an empty locking
            // script and M, its spend by a non-minimal push of 0x01.
            None if name.contains("sentinel") => sentinel_transactions(&f, &t)?,
            None => BTreeMap::from([("F".into(), f), ("T".into(), t), (other.0.into(), other.1)]),
        };
        let mut blocks = BTreeMap::from([("base".into(), base)]);
        let mut blocked = None;
        let mut rejected = BTreeMap::new();
        for step in &prefix {
            if let Err(e) = apply_step(&mut n, step, &txs, &mut blocks, &mut rejected) {
                blocked = Some(e);
                break;
            }
        }
        let setup = n.calls.clone();
        // [D] 2026-10-13 (#72): once the node's body differs from the body a
        // step's expectation was computed on, that step and every later step
        // of the trace are recorded, never judged.
        let mut differs: Option<Value> = None;
        for step in steps {
            let offset = n.calls.len();
            if blocked.is_none() {
                if let Err(e) = apply_step(&mut n, &step, &txs, &mut blocks, &mut rejected) {
                    blocked = Some(e);
                }
            }
            if let Some(reason) = &blocked {
                rows.push(json!({"id":step["id"],"node":"pending #66","reason":reason,"rpc":n.calls[offset..]}));
                continue;
            }
            let assembly = n.calls[offset..]
                .iter()
                .find(|c| c["event"] == "mined-body")
                .cloned();
            if let Some(event) = &assembly {
                if event["body_equals_declared"] != true && differs.is_none() {
                    differs = Some(
                        json!({"step":step["id"],"observed_body":event["observed_transactions"],"declared_body":event["declared_transactions"]}),
                    );
                }
            }
            let raw = observe(&mut n, &txs, &blocks, &rejected)?;
            let mut actual = actual_projection(&raw, &txs, &blocks, pair)?;
            let mut expected = expected_projection(&step);
            let same = judge_projection(&step, &mut expected, &mut actual);
            let applied = assembly
                .as_ref()
                .is_none_or(|event| event["body_application_agrees"] == true);
            let verdict = if differs.is_some() {
                "non-judging"
            } else if same && applied {
                "agree"
            } else {
                "diverge"
            };
            let node = match &differs {
                Some(d) => format!("measured non-judging: {} [#72: the node assembled another body; the expectation is for the declared body] [X] {record}", serde_json::to_string(d).or_err("serde_json::to_string(d)")?),
                None => format!("measured {verdict} [X] {record}"),
            };
            rows.push(json!({"id":step["id"],"node":node,"assembly":assembly,"scope":"exposed node state and path; declared local client words are inputs, not RPC measurements; #65 theorem hypotheses remain explicit; #75 codec remains owed","verdict":verdict,"projection_verdict":format!("{verdict} [X]"),"declared_client_inputs":step["action"]["client_input"],"declared_client_views":step["expected_observations"]["client_views"],"declared_client_evidence":step["expected_observations"]["client_evidence"],"client_label":"[D] not an RPC measurement","expected":expected,"expected_label":"[D]","observed":actual,"raw":raw,"rpc":n.calls[offset..]}));
        }
        n.stop()?;
        launches.push(json!({"trace":trace,"status":"replayed node projection","single_transaction_proof":single_transaction_proof,"fixtures":txs.iter().map(|(name,tx)|(name.clone(),material(tx))).collect::<BTreeMap<_,_>>(),"setup":setup,"conf":n.conf}));
    }
    // [D] 2026-10-13 (#72): an instance whose adjusted-time offset is not
    // zero cannot judge a time-dependent step; the trace's steps are recorded.
    if launches.iter().chain(rows.iter()).any(offset_uncontrolled) {
        for row in rows
            .iter_mut()
            .filter(|r| matches!(r["verdict"].as_str(), Some("agree" | "diverge")))
        {
            row["verdict"] = json!("non-judging");
            row["node"] = json!(format!(
                "measured non-judging: adjusted-time offset not controlled (#72) [X] {record}"
            ));
        }
    }
    let judged = |r: &&Value| matches!(r["verdict"].as_str(), Some("agree" | "diverge"));
    let realized = rows.iter().filter(judged).count();
    let agree = rows.iter().filter(|r| r["verdict"] == "agree").count();
    let non_judging = rows
        .iter()
        .filter(|r| r["verdict"] == "non-judging")
        .count();
    Ok(
        json!({"scenario":name,"source_pin":PIN,"record":record,"launches":launches,"steps":rows,"counts":{"label":"[M]","rows":rows.len(),"realized":realized,"agree":agree,"diverge":realized-agree,"rpc-precheck":0,"unrealizable":0,"non-judging":non_judging,"needs-peer":0,"pending":rows.len()-realized-non_judging}}),
    )
}
/// [D] 2026-10-15, lane cut2-66q2: #90's prefix. Block 1 carries a coinbase of two outputs to
/// the harness key and 99 blocks follow, so F1 and F2 (100,000 satoshis each to the key) both
/// spend a coinbase output mature at 101 and are mined in `base` at 101. The scenario's declared
/// sources (the height-1 and height-2 coinbases) cannot both be: the height-2 coinbase is at depth
/// 99 at 101, below COINBASE_MATURITY 100 ([SRC] src/consensus/consensus.h:75;
/// src/validation.cpp:2617-2623 at PIN), and the scenario's page says so.
fn seed_pair(n: &mut Node) -> Result<(RawTx, RawTx, String)> {
    let mut coinbase = block_codec::coinbase_tx(1, 5_000_000_000, script(), b"pair");
    coinbase.outputs = vec![
        RawOutput {
            satoshis: 2_500_000_000,
            script: script(),
        },
        RawOutput {
            satoshis: 2_500_000_000,
            script: script(),
        },
    ];
    let (_, receipt) = n.submit(std::slice::from_ref(&coinbase), 1_699_990_001)?;
    if block_judgment(&receipt) != json!({"status":"ok"}) {
        return Err(format!("pair coinbase block: {receipt}"));
    }
    for h in 2..=100 {
        n.mine(1, 1_699_990_000 + h)?;
    }
    let f1 = signed(&[(&coinbase, 0)], vec![(100_000, script())], 1)?;
    let f2 = signed(&[(&coinbase, 1)], vec![(100_000, script())], 1)?;
    let (hash, receipt) = n.submit(&[cb(101, "base"), f1.clone(), f2.clone()], 1_699_999_999)?;
    if block_judgment(&receipt) != json!({"status":"ok"}) {
        return Err(format!("pair base block: {receipt}"));
    }
    Ok((f1, f2, hash))
}

/// #90's transactions (the scenario's declaration): A spends F1:fund then F2:fund, B spends
/// F2:fund then F1:fund, C and D each spend F1:fund alone; each pays the harness key with a fee
/// of at least 1000 satoshis.
pub(super) fn pair_transactions(f1: &RawTx, f2: &RawTx) -> Result<BTreeMap<String, RawTx>> {
    Ok(BTreeMap::from([
        ("F1".to_owned(), f1.clone()),
        ("F2".to_owned(), f2.clone()),
        (
            "A".to_owned(),
            signed(&[(f1, 0), (f2, 0)], vec![(198_000, script())], 1)?,
        ),
        (
            "B".to_owned(),
            signed(&[(f2, 0), (f1, 0)], vec![(197_000, script())], 1)?,
        ),
        (
            "C".to_owned(),
            signed(&[(f1, 0)], vec![(99_000, script())], 1)?,
        ),
        (
            "D".to_owned(),
            signed(&[(f1, 0)], vec![(98_000, script())], 1)?,
        ),
    ]))
}

/// #91's transactions (the scenario's declaration): P spends F (the seed's T), Q spends P; N
/// spends F to an empty locking script; M spends N's output with the unlocking script `01 01`.
pub(super) fn sentinel_transactions(f: &RawTx, p: &RawTx) -> Result<BTreeMap<String, RawTx>> {
    let n = signed(&[(f, 0)], vec![(99_000, vec![])], 1)?;
    let m = RawTx {
        version: 1,
        inputs: vec![RawInput {
            txid: n.txid_internal(),
            vout: 0,
            script: vec![0x01, 0x01],
            sequence: u32::MAX,
        }],
        outputs: vec![RawOutput {
            satoshis: 98_000,
            script: vec![0x51],
        }],
        lock_time: 0,
    };
    Ok(BTreeMap::from([
        ("F".to_owned(), f.clone()),
        ("P".to_owned(), p.clone()),
        ("Q".to_owned(), spend(p, 98_000, 1)),
        ("N".to_owned(), n),
        ("M".to_owned(), m),
    ]))
}

/// A transaction spending `inputs` (each an output locked to the harness key), paying
/// `outputs`, every input signed SIGHASH_ALL|FORKID by the key (core.rs `spend_to`'s
/// signature, one per input).
pub(super) fn signed(
    inputs: &[(&RawTx, u32)],
    outputs: Vec<(u64, Vec<u8>)>,
    version: i32,
) -> Result<RawTx> {
    use bsv_rs::primitives::bsv::sighash::{
        compute_sighash_for_signing, SighashParams, TxInput, TxOutput,
    };
    let mut tx = RawTx {
        version,
        inputs: inputs
            .iter()
            .map(|(p, v)| RawInput {
                txid: p.txid_internal(),
                vout: *v,
                script: vec![],
                sequence: u32::MAX,
            })
            .collect(),
        outputs: outputs
            .iter()
            .map(|(satoshis, script)| RawOutput {
                satoshis: *satoshis,
                script: script.clone(),
            })
            .collect(),
        lock_time: 0,
    };
    let sig_inputs: Vec<TxInput> = tx
        .inputs
        .iter()
        .map(|i| TxInput {
            txid: i.txid,
            output_index: i.vout,
            script: vec![],
            sequence: i.sequence,
        })
        .collect();
    let sig_outputs: Vec<TxOutput> = tx
        .outputs
        .iter()
        .map(|o| TxOutput {
            satoshis: o.satoshis,
            script: o.script.clone(),
        })
        .collect();
    for (k, (parent, vout)) in inputs.iter().enumerate() {
        let prev = parent
            .outputs
            .get(*vout as usize)
            .ok_or("signed: the spent output")?;
        let digest = compute_sighash_for_signing(&SighashParams {
            version,
            inputs: &sig_inputs,
            outputs: &sig_outputs,
            locktime: 0,
            input_index: k,
            subscript: &prev.script,
            satoshis: prev.satoshis,
            scope: 0x41,
        });
        let signature = key().sign(&digest).map_err(|e| e.to_string())?;
        let integer = |x: &[u8; 32]| {
            let mut b: Vec<u8> = x.iter().copied().skip_while(|v| *v == 0).collect();
            if b.is_empty() {
                b.push(0);
            }
            if b[0] & 128 != 0 {
                b.insert(0, 0);
            }
            [vec![2, b.len() as u8], b].concat()
        };
        let payload = [integer(signature.r()), integer(signature.s())].concat();
        let der = [vec![0x30, payload.len() as u8], payload, vec![0x41]].concat();
        let script = &mut tx.inputs[k].script;
        bsv_script_harness::gen::push_min(script, &der);
        bsv_script_harness::gen::push_min(script, &key().public_key().to_compressed());
    }
    Ok(tx)
}

fn observe(
    n: &mut Node,
    txs: &BTreeMap<String, RawTx>,
    blocks: &BTreeMap<String, String>,
    rejected: &BTreeMap<String, Value>,
) -> Result<Value> {
    let pool = n.call("getrawmempool", json!([]))?;
    let held = n.call("getrawnonfinalmempool", json!([]))?;
    let orphan = n.call("getorphaninfo", json!([]))?;
    if orphan["size"] != 0 {
        return Err("unexpected orphan in isolated RPC-only run".into());
    }
    let tips = n.call("getchaintips", json!([]))?;
    let best = n.call("getbestblockhash", json!([]))?;
    let mut bodies = vec![];
    for (name, hash) in blocks {
        bodies.push((name, n.call("getblock", json!([hash, 2]))?));
    }
    let mut statuses = BTreeMap::new();
    let mut outputs = BTreeMap::new();
    for (name, tx) in txs {
        let txid = id(tx);
        let mut ev = Evidence {
            accepted: pool.as_array().ok_or("pool")?.contains(&json!(txid)),
            held: held.as_array().ok_or("held")?.contains(&json!(txid)),
            rejection: rejected.get(name).cloned(),
            ..Default::default()
        };
        let raw = n.receipt("getrawtransaction", json!([txid, 1]))?;
        for (_, b) in &bodies {
            for t in b["tx"].as_array().ok_or("body tx list")? {
                if t["txid"] == txid {
                    if b["confirmations"].as_i64().unwrap_or(0) > 0 {
                        ev.active_heights
                            .push(b["height"].as_u64().ok_or("height")?);
                    } else {
                        ev.stale = true;
                    }
                }
            }
        }
        for input in &tx.inputs {
            if !n.seen.contains(&txid) {
                continue;
            }
            let prev = txid_display_hex(&input.txid);
            let coin = n.call("gettxout", json!([prev, input.vout, false]))?;
            if coin.is_null() {
                for (_, b) in &bodies {
                    if b["confirmations"].as_i64().unwrap_or(0) > 0 {
                        for t in b["tx"].as_array().or_err("b['tx'].as_array()")? {
                            if t["txid"] != txid
                                && t["vin"].as_array().is_some_and(|ins| {
                                    ins.iter()
                                        .any(|i| i["txid"] == prev && i["vout"] == input.vout)
                                })
                            {
                                ev.exact_active_conflict = true;
                            }
                        }
                    }
                }
            }
        }
        outputs.insert(name.clone(), n.call("gettxout", json!([txid, 0, false]))?);
        statuses.insert(
            name.clone(),
            json!({"status":status(&ev),"rawtransaction":raw}),
        );
    }
    Ok(
        json!({"mempool":pool,"non_final_pool":held,"orphans":orphan,"chain_tips":tips,"best":best,"transactions":statuses,"outputs":outputs}),
    )
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn assembly_write_back_keeps_other_bytes() {
        let step = "{\n  \"id\": \"b2\",\n  \"action\": {\n    \"type\": \"mine\",\n    \"transactions\": [\n      \"T\"\n    ],\n    \"now\": 1\n  },\n  \"expected_observations\": {\"transactions\": {}}\n}";
        let event = json!({"observed_transactions":["T"]});
        let once = mark_assembly(step, &event, "measured agree [X] docs/records/a.md").unwrap();
        let parsed: Value = serde_json::from_str(&once).unwrap();
        assert_eq!(parsed["action"]["transactions"], json!(["T"]));
        assert!(parsed["action"]["assembly"]
            .as_str()
            .unwrap()
            .ends_with("[X] docs/records/a.md"));
        assert_eq!(parsed["expected_observations"], json!({"transactions":{}}));
        let twice = mark_assembly(
            &once,
            &json!({"observed_transactions":[]}),
            "measured agree [X] docs/records/b.md",
        )
        .unwrap();
        let parsed: Value = serde_json::from_str(&twice).unwrap();
        assert_eq!(parsed["action"]["transactions"], json!([]));
        assert!(parsed["action"]["assembly"]
            .as_str()
            .unwrap()
            .ends_with("docs/records/b.md"));
        assert_eq!(twice.matches("assembly").count(), 1);
    }
}
