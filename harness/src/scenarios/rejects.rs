//! [D] 2026-10-14: #71 reject-cache and time-budget traces over the pinned
//! loopback peer. A row of `corpus/chain/mempool/mempool.jsonl` with
//! `action: p2pTrace` lists ordered steps; each step is driven on one fresh
//! instance and classified into the same answer word the spec's trace prints.
//! [SRC] src/net/net_processing.cpp:930-961,2479,2518-2519,3351-3408;
//! src/validation.cpp:1786-1836,2037-2048,2097-2136;
//! src/txn_validator.cpp:633-641; src/rpc/rawtransaction.cpp:1586-1594,
//! 1625-1626 at core::PIN.
use super::core::*;
use super::peer::{pools, settled, Peer};

const NOW: u64 = 1_700_000_000;
// The peer lane's launch profile, with microsecond log stamps. No whitelist;
// banscore keeps the peer connected after an invalid transaction
// ([SRC] src/init.cpp:2703-2705 at the pin).
const CONF: &str = "listen=1\nbind=127.0.0.1:{P2P_PORT}\ngenesisactivationheight=1\nchronicleactivationheight=1000000\nacceptnonstdtxn=1\nacceptnonstdoutputs=1\nbanscore=100000\ndebug=mempool\ndebug=txnval\ndebug=netmsg\nlogtimemicros=1\n";
// The census names of the three budget settings and their launch options
// ([SRC] src/init.cpp:2850-2885 at the pin).
const BUDGET_OPTIONS: [(&str, &str); 3] = [
    ("maxStdTxnValidationDuration", "maxstdtxvalidationduration"),
    (
        "maxNonStdTxnValidationDuration",
        "maxnonstdtxvalidationduration",
    ),
    ("maxTxnChainValidationBudget", "maxtxchainvalidationbudget"),
];

pub(super) fn selected(row: &Value) -> bool {
    row["action"] == "p2pTrace"
}
// Every trace row, each on its own fresh instance.
pub(super) fn rows(root: &Path) -> Result<Vec<Value>> {
    row_read("mempool")?
        .iter()
        .filter(|r| selected(r))
        .map(|r| row(root, r))
        .collect()
}
// A nonstandard lock whose cost is hashing a 16 MiB element `hashes` times;
// it needs no unlocking data (the reclass-66b fixture, mempool.rs).
pub(super) fn hashing_lock(hashes: usize) -> Vec<u8> {
    let mut b = vec![0x40];
    b.extend([0x5a; 64]);
    for _ in 0..18 {
        b.extend([0x76, 0x7e]);
    }
    for _ in 0..hashes {
        b.extend([0x76, 0xa8, 0x75]);
    }
    b.extend([0x75, 0x51]);
    b
}
// One funding transaction per declared coin, each spending a mature coinbase.
fn fund(n: &mut Node, coins: &[(u64, Vec<u8>)]) -> Result<Vec<RawTx>> {
    let hashes = n.mine(103, NOW - 10000)?;
    let mut funds = vec![];
    for (hash, (value, lock)) in hashes.iter().zip(coins) {
        let body = n.call("getblock", json!([hash, 1]))?;
        let coin = n.raw_tx(&body["tx"][0])?;
        funds.push(spend_to(&coin, *value, 1, lock.clone()));
    }
    let block = [vec![cb(104, "s6-71")], funds.clone()].concat();
    let (_, receipt) = n.submit(&block, (NOW - 1000) as u32)?;
    if block_judgment(&receipt) != json!({"status":"ok"}) {
        return Err(format!("trace funding refused: {receipt}"));
    }
    n.call("setmocktime", json!([NOW]))?;
    Ok(funds)
}
fn validations(n: &Node, txid: &str) -> Result<usize> {
    let log = fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
    Ok(log.matches(&format!("txn= {txid} rejected")).count())
}
fn pool_word(pools: &Value, txid: &str) -> Option<&'static str> {
    let has = |field: &str| {
        pools[field]
            .as_array()
            .is_some_and(|a| a.contains(&json!(txid)))
    };
    if has("accepted") {
        Some("accepted")
    } else if has("held") {
        Some("heldNonFinal")
    } else {
        None
    }
}
pub(super) fn row(root: &Path, row: &Value) -> Result<Value> {
    let name = text(&row["id"])?;
    let mut conf = CONF.to_string();
    for (field, option) in BUDGET_OPTIONS {
        if let Some(value) = row["cfg"][field].as_u64() {
            conf.push_str(&format!("{option}={value}\n"));
        }
    }
    let mut n = start_retry(root, name, &conf)?;
    let declared = row["utxo"].as_array().ok_or("trace UTXO array")?;
    let coins: Vec<(u64, Vec<u8>)> = declared
        .iter()
        .map(|u| -> Result<(u64, Vec<u8>)> {
            let lock = if u["heavy"] == true {
                hashing_lock(8)
            } else {
                hex::decode(u["script"].as_str().unwrap_or("51")).map_err(|e| e.to_string())?
            };
            Ok((u["value"].as_u64().unwrap_or(1000), lock))
        })
        .collect::<Result<_>>()?;
    let funds = fund(&mut n, &coins)?;
    let mut points = BTreeMap::new();
    for (u, f) in declared.iter().zip(&funds) {
        let hash: [u8; 32] = hex::decode(text(&u["hash"])?)
            .map_err(|e| e.to_string())?
            .try_into()
            .map_err(|_| "UTXO hash length")?;
        points.insert(
            (hash, u["index"].as_u64().unwrap_or(0) as u32),
            f.txid_internal(),
        );
    }
    // The row's frames keep every byte except the funded outpoints.
    let mut txs: BTreeMap<String, RawTx> = BTreeMap::new();
    for (label, raw) in row["txs"].as_object().ok_or("trace transactions")? {
        let mut tx = RawTx::decode(&hex::decode(text(raw)?).map_err(|e| e.to_string())?)?;
        for input in &mut tx.inputs {
            input.txid = *points
                .get(&(input.txid, input.vout))
                .ok_or("unmaterialized trace input")?;
            input.vout = 0;
        }
        txs.insert(label.clone(), tx);
    }
    let mut p = Peer::start(&mut n)?;
    // The peer never answers a getdata by itself: every delivery is a step.
    for tx in txs.values() {
        p.withhold(tx)?;
    }
    let initial = pools(&mut n)?;
    if initial != json!({"accepted":[],"held":[],"orphans":0}) {
        return Err(format!("nonempty isolated pool: {initial}"));
    }
    let steps = row["steps"].as_array().ok_or("trace steps")?;
    let expected_answers = row["expected"]["answers"]
        .as_array()
        .ok_or("trace answers")?;
    if steps.len() != expected_answers.len() {
        return Err(format!("{name}: one declared answer per step"));
    }
    // Tip labels are checked against the node's own best hash at every test.
    let mut tips: BTreeMap<String, Value> = BTreeMap::new();
    let mut branch: Vec<Value> = vec![];
    let mut height = 104u32;
    let mut clock = NOW;
    let mut answers = vec![];
    let mut details = vec![];
    for (index, (step, expected)) in steps.iter().zip(expected_answers).enumerate() {
        let op = text(&step["op"])?;
        let expected = text(expected)?;
        let best = n.call("getbestblockhash", json!([]))?;
        let (answer, detail) = match op {
            "mine" => {
                let label = text(&step["tip"])?;
                if tips.contains_key(label) {
                    return Err(format!("{name}: mined tip label {label} already used"));
                }
                clock += 600;
                height += 1;
                let (hash, receipt) =
                    n.submit(&[cb(height, &format!("s6-71-{index}"))], clock as u32)?;
                let after = n.call("getbestblockhash", json!([]))?;
                if block_judgment(&receipt) != json!({"status":"ok"})
                    || after != json!(hash)
                    || after == best
                {
                    return Err(format!("{name}: tip-changing block refused: {receipt}"));
                }
                tips.insert(label.into(), after.clone());
                branch.push(after.clone());
                (
                    "tip".to_string(),
                    json!({"before":best,"after":after,"height":height,"submitblock":receipt}),
                )
            }
            "invalidate" => {
                let label = text(&step["tip"])?;
                let top = branch.pop().ok_or("no mined tip to invalidate")?;
                n.call("invalidateblock", json!([top]))?;
                height -= 1;
                let after = n.call("getbestblockhash", json!([]))?;
                if tips.get(label) != Some(&after) || after == best {
                    return Err(format!("{name}: tip did not return to {label}"));
                }
                (
                    "tip".to_string(),
                    json!({"before":best,"after":after,"invalidated":top,"height":height}),
                )
            }
            "rpc" => {
                let tx = txs
                    .get(text(&step["tx"])?)
                    .ok_or("unknown trace transaction")?;
                let txid = id(tx);
                let receipt = n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
                let after = pools(&mut n)?;
                let answer = match node_reject(&receipt) {
                    Some(r) if r["namespace"] == "node" => {
                        format!("rejected {} {}", r["code"], text(&r["reason"])?)
                    }
                    Some(r) => format!("rpc-error {} {}", r["code"], text(&r["reason"])?),
                    None => pool_word(&after, &txid).unwrap_or("absent").to_string(),
                };
                (answer, json!({"txid":txid,"reply":receipt,"pools":after}))
            }
            "inv" | "tx" => {
                let label = text(&step["tip"])?;
                let known = tips.entry(label.into()).or_insert_with(|| best.clone());
                if *known != best {
                    return Err(format!(
                        "{name}: step {index} names tip {label}, the node is elsewhere"
                    ));
                }
                let tx = txs
                    .get(text(&step["tx"])?)
                    .ok_or("unknown trace transaction")?;
                let txid = id(tx);
                if op == "inv" {
                    let cursor = p.inv(tx)?;
                    // Silence means no matching getdata in the measured 2 s window. This is a
                    // bounded absence observation, not a measured guarantee of indefinite
                    // suppression; late delivery remains outside this observation, and the
                    // agreement of a silence step is with this projection (fix-71). It is a
                    // transport window, unrelated to the CPU validation-budget classification.
                    let window = if expected == "request" { 10.0 } else { 2.0 };
                    let asked = Instant::now();
                    let request = p.expect("getdata", &txid, cursor, window)?;
                    let waited = asked.elapsed().as_secs_f64();
                    let answer = if request["matched"] == true {
                        "request"
                    } else {
                        "silence"
                    };
                    (
                        answer.to_string(),
                        json!({"txid":txid,"tip":best,"window_seconds":window,"waited_seconds":{"label":"[M]","value":waited},"getdata":request}),
                    )
                } else {
                    let before = validations(&n, &txid)?;
                    let cursor = p.next;
                    p.tx(tx)?;
                    settled(&mut n)?;
                    let window = if expected.starts_with("rejected") {
                        5.0
                    } else {
                        1.5
                    };
                    let reject = p.expect("reject", &txid, cursor, window)?;
                    let after = pools(&mut n)?;
                    let validated = validations(&n, &txid)? - before;
                    let message = reject["observations"]
                        .as_array()
                        .and_then(|o| o.iter().find(|e| e["command"] == "reject"));
                    let answer = match (message, pool_word(&after, &txid)) {
                        (Some(e), _) => format!("rejected {} {}", e["code"], text(&e["reason"])?),
                        (None, Some(word)) => word.to_string(),
                        (None, None) if after["orphans"] != 0 => "orphan".to_string(),
                        (None, None) if validated > 0 => "rejected-unanswered".to_string(),
                        (None, None) => "suppressed".to_string(),
                    };
                    (
                        answer,
                        json!({"txid":txid,"tip":best,"window_seconds":window,"reject":reject,"pools":after,"validations_logged":validated}),
                    )
                }
            }
            other => return Err(format!("{name}: unknown trace step {other}")),
        };
        details.push(json!({"index":index,"step":step,"expected":expected,"expected_label":"[D]","observed":answer,"detail":detail}));
        answers.push(answer);
    }
    let log = fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
    let ids: Vec<String> = txs.values().map(id).collect();
    let relevant: Vec<String> = log
        .lines()
        .filter(|l| {
            ids.iter().any(|i| l.contains(i.as_str())) || l.contains("Validation timeout occurred")
        })
        .map(str::to_owned)
        .collect();
    let forwarded = log.contains("forwarding them to the Non-standard queue");
    p.close()?;
    n.stop()?;
    let peer = p.receipt(&n);
    let options: Vec<&str> = conf
        .lines()
        .filter(|l| BUDGET_OPTIONS.iter().any(|(_, o)| l.starts_with(o)))
        .collect();
    let recipe = format!(
        "[D] 2026-10-14: fund one coin per declared outpoint at height 104 (outpoints remapped; mocktime {NOW}); withhold every frame so the peer answers no getdata by itself; then run the row's steps in order on this one fresh instance: inv is one inventory announcement, read as request when a getdata for the txid arrives in the window and silence otherwise; tx is one delivery, read from the reject message, else the pools, else suppressed when the node logged no validation of it; rpc is sendrawtransaction; mine submits an empty block; invalidate returns to the named tip. Each inventory test's tip label is checked against getbestblockhash. Launch options beyond the peer profile: {}. No whitelist.",
        if options.is_empty() { "none".to_string() } else { options.join(", ") }
    );
    let fixtures = json!({
        "funding": funds.iter().map(material).collect::<Vec<_>>(),
        "transactions": txs.iter().map(|(k, v)| (k.clone(), material(v))).collect::<BTreeMap<_, _>>(),
        "declared_transactions": row["txs"],
        "tips": tips,
        "conf": n.conf,
        "initial": initial,
        "forwarded_to_low_queue": forwarded,
    });
    let mut r = measured(
        row,
        json!({"answers":answers}),
        json!({"answers":expected_answers}),
        &recipe,
        std::mem::take(&mut n.calls),
        fixtures,
    );
    r["date"] = json!("2026-10-14");
    r["steps"] = json!(details);
    r["peer"] = peer;
    r["node_log"] = json!(relevant);
    r["declared_expected"] = row["expected"].clone();
    classify_trace(row, &answers, &options, &mut r)?;
    Ok(r)
}

// [D] 2026-10-14: any non-judging step excludes the indivisible row from
// agreement/divergence; the full answer comparison remains a projection.
fn classify_trace(row: &Value, answers: &[String], options: &[&str], r: &mut Value) -> Result<()> {
    let steps = row["expected"]["nonJudging"].as_array();
    if steps.is_none_or(|steps| steps.is_empty()) {
        return Ok(());
    }
    let expired = answers
        .iter()
        .any(|a| a.contains("too-long-validation-time"));
    let reason = if row["budgetCell"] == true {
        format!(
            "the outcome of the heavy frame depends on the node's CPU validation clock ([SRC] src/txn_validation_config.h:36-37; src/init.cpp:2890-2895; src/validation.cpp:990-1006) against {}; {} in this run",
            if options.is_empty() { "the default durations".to_string() } else { options.join(", ") },
            if expired { "expiry observed" } else { "no expiry" }
        )
    } else {
        let reasons = steps
            .or_err("steps")?
            .iter()
            .map(|step| {
                let key = step.to_string();
                row["nonJudgingReasons"][&key]
                    .as_str()
                    .map(str::to_owned)
                    .ok_or_else(|| format!("missing non-judging reason for step {key}"))
            })
            .collect::<Result<Vec<_>>>()?;
        let observation = if expired {
            "expiry observed in this run".to_string()
        } else if answers
            .get(1)
            .is_some_and(|answer| answer == "rejected 16 bad-txn-update")
        {
            "no expiry in the completed validation that returned bad-txn-update".to_string()
        } else {
            "no expiry observed in this run".to_string()
        };
        format!("{}; {observation}", reasons.join("; "))
    };
    r["projection_verdict"] = r["verdict"].clone();
    r["verdict"] = json!("non-judging");
    r["qualifier"] = json!(format!(
        "non-judging (#71): {reason}; the projection {} the declared trace",
        if r["projection_verdict"] == "agree" {
            "matches"
        } else {
            "differs from"
        }
    ));
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn budget_marker_without_step_classification_is_judged() {
        let row = json!({"budgetCell": true, "expected": {"nonJudging": []}});
        let mut result = json!({"verdict": "agree"});
        classify_trace(&row, &[], &[], &mut result).unwrap();
        assert_eq!(result["verdict"], "agree");
    }

    #[test]
    fn step_classifications_control_row_verdict() {
        for line in include_str!("../../../corpus/chain/mempool/mempool.jsonl").lines() {
            let row: Value = serde_json::from_str(line).unwrap();
            if !selected(&row) {
                continue;
            }
            let answers = row["expected"]["answers"]
                .as_array()
                .unwrap()
                .iter()
                .map(|a| a.as_str().unwrap().to_string())
                .collect::<Vec<_>>();
            for verdict in ["agree", "diverge"] {
                let mut result = json!({"verdict": verdict});
                classify_trace(&row, &answers, &[], &mut result).unwrap();
                if row["expected"]["nonJudging"].as_array().unwrap().is_empty() {
                    assert_eq!(result["verdict"], verdict);
                    assert!(result.get("projection_verdict").is_none());
                } else {
                    assert_eq!(result["verdict"], "non-judging");
                    assert_eq!(result["projection_verdict"], verdict);
                    if row["id"] == "rejects-commit-refusal-not-remembered" && verdict == "agree" {
                        assert!(row["node"]
                            .as_str()
                            .unwrap()
                            .contains(result["qualifier"].as_str().unwrap()));
                    }
                }
            }
        }
    }
}
