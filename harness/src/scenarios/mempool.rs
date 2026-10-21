//! Family-owned realization recipes. Sources and observation boundaries are retained in receipts.
use super::core::*;

fn mempool_more(root: &Path, rows: &[Value]) -> Result<Vec<Value>> {
    let mut results = vec![];
    for row in rows {
        let name = text(&row["id"])?;
        if !matches!(
            name,
            "baseline-valid"
                | "standard-output-disabled"
                | "standard-output-enabled"
                | "standard-version"
                | "nonfinal-held-height-equality"
                | "nonfinal-pre-genesis"
                | "script-eval-false"
        ) {
            continue;
        }
        let genesis = if name == "nonfinal-pre-genesis" {
            10000
        } else {
            1
        };
        let require = if name == "nonfinal-pre-genesis" { 1 } else { 0 };
        let accept = if name == "standard-output-disabled" {
            0
        } else {
            1
        };
        let extra=format!("genesisactivationheight={genesis}\nchronicleactivationheight=1000000\nacceptnonstdtxn={require}\nacceptnonstdoutputs={accept}\n");
        let mut n = start_boundary(root.join(format!("mempool-{name}")), &extra)?;
        let hashes = n.mine(100, 1_699_990_000)?;
        let body = n.call("getblock", json!([hashes[0], 1]))?;
        let coin = n.raw_tx(&body["tx"][0])?;
        let lock = if name == "script-eval-false" {
            vec![0x00]
        } else {
            vec![0x51]
        };
        let f = spend_to(&coin, 1000, 1, lock);
        let (_, receipt) = n.submit(&[cb(101, name), f.clone()], 1_699_995_000)?;
        if block_judgment(&receipt) != json!({"status":"ok"}) {
            return Err(format!("mempool funding refused: {receipt}"));
        }
        n.mine(99, 1_699_999_000)?;
        let mut tx = RawTx::decode(&hex::decode(text(&row["tx"])?).map_err(|e| e.to_string())?)?;
        tx.inputs[0].txid = f.txid_internal();
        let reply = n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
        let pool = n.call("getrawmempool", json!([]))?;
        let held = n.call("getrawnonfinalmempool", json!([]))?;
        let orphan = n.call("getorphaninfo", json!([]))?;
        let observed = if let Some(reject) = node_reject(&reply) {
            reject
        } else if held.as_array().is_some_and(|a| a.contains(&json!(id(&tx)))) {
            json!({"status":"heldNonFinal"})
        } else if pool.as_array().is_some_and(|a| a.contains(&json!(id(&tx)))) {
            json!({"status":"accepted"})
        } else {
            return Err("successful admission absent from both pools".into());
        };
        let e = &row["expected"];
        let expected = if e["status"] == "rejected" {
            json!({"status":"rejected","namespace":"node","code":e["code"],"reason":e["reason"]})
        } else {
            json!({"status":e["status"]})
        };
        let expected_pool = if expected["status"] == "accepted" {
            json!([id(&tx)])
        } else {
            json!([])
        };
        let expected_held = if expected["status"] == "heldNonFinal" {
            json!([id(&tx)])
        } else {
            json!([])
        };
        let actual =
            json!({"judgment":observed,"accepted":pool,"held":held,"orphans":orphan["size"]});
        let expectation =
            json!({"judgment":expected,"accepted":expected_pool,"held":expected_held,"orphans":0});
        n.stop()?;
        results.push(measured(row,actual,expectation,"Create a signed funding transaction with the row's 1000-satoshi locking script at height 101, mine to tip 200, remap only the prevout in the row frame. Preserve version, output bytes, lock time and sequence. Genesis 1 replaces unlaunchable 0 while preserving all consumed era branches; Chronicle stays 1000000. Exact pools and rejection namespace/code/reason are compared; internal stage trace is not RPC output.",std::mem::take(&mut n.calls),json!({"funding":material(&f),"transaction":material(&tx),"conf":n.conf})));
    }
    Ok(results)
}
pub(super) fn run(root: &Path) -> Result<Vec<Value>> {
    let rows = row_read("mempool")?;
    // [D] 2026-10-13, lane reclass-66b: replay only the limited P2P rows.
    if std::env::args().any(|a| a == "--reclass-only") {
        return rows
            .iter()
            .filter(|row| limited(row))
            .map(|row| limited_row(root, row))
            .collect();
    }
    // [D] 2026-10-14, lane attr-o2: replay only the nine rows whose setup
    // checks the disk counter (open item O-2), each on a fresh datadir.
    if std::env::args().any(|a| a == "--attr-o2-only") {
        return rows
            .iter()
            .filter(|row| {
                let name = row["id"].as_str().unwrap_or("");
                name == "trim-empty-retains-rolling-rate"
                    || name.starts_with("rolling-")
                    || name.starts_with("consolidation-")
            })
            .map(|row| {
                if row["id"] == "trim-empty-retains-rolling-rate" {
                    round3_empty(root, row)
                } else {
                    rolling_boundary(root, row)
                }
            })
            .collect();
    }
    // [D] 2026-10-14 (#121, lane wallet-rows-b): replay only the fee rows that
    // select the wallet build, each on its own fresh instance of that build.
    if std::env::args().any(|a| a == "--wallet-only") {
        let wallet: Vec<Value> = rows
            .iter()
            .filter(|row| Build::of(row).is_ok_and(|b| b == Build::Wallet))
            .cloned()
            .collect();
        return boundary_stage(root, &wallet, "fee");
    }
    let mut result = vec![];
    let mut n = start_boundary(root.join("mempool"), "")?;
    let (f, _, _) = seed(&mut n)?;
    // Realize all supplied prevouts before a structural rejection. The stage
    // precedes script and era checks, which stay outside this projection.
    for row in &rows {
        let name = text(&row["id"])?;
        if !matches!(
            name,
            "regular-empty-inputs" | "regular-empty-outputs" | "regular-duplicate-input"
        ) {
            continue;
        }
        let offset = n.calls.len();
        let mut tx = RawTx::decode(&hex::decode(text(&row["tx"])?).map_err(|e| e.to_string())?)?;
        for input in &mut tx.inputs {
            input.txid = f.txid_internal();
            input.vout = 0;
            input.script = vec![1, 0x51];
        }
        let receipt = n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
        let observed = node_reject(&receipt).unwrap_or(json!({"status":"accepted"}));
        let e = &row["expected"];
        let expected =
            json!({"status":e["status"],"namespace":"node","code":e["code"],"reason":e["reason"]});
        n.call("getrawmempool", json!([]))?;
        n.call("getrawnonfinalmempool", json!([]))?;
        n.call("getorphaninfo", json!([]))?;
        result.push(measured(row,observed,expected,"Materialize F on the live chain, remap input outpoints to F, retain the empty/duplicate structure. Compare exact node code and reason in the RPC envelope; trace remains spec-only.",n.calls[offset..].to_vec(),json!({"F":material(&f),"transaction":material(&tx),"conf":n.conf})));
    }
    n.stop()?;
    result.extend(mempool_more(root, &rows)?);
    result.extend(commit_stage(root, &rows)?);
    for kind in BOUNDARY_KINDS {
        result.extend(boundary_stage(root, &rows, kind)?);
    }
    for kind in ["commit", "eviction", "decay", "fee", "detector"] {
        result.extend(
            round2_stage(root, &rows, kind)?
                .into_iter()
                .filter(|r| r.get("pending").is_none()),
        );
    }
    for kind in ["eviction", "detector"] {
        result.extend(
            round3_stage(root, &rows, kind)?
                .into_iter()
                .filter(|r| r.get("pending").is_none()),
        );
    }
    // [D] 2026-10-13: realize the P2P-origin rows with the pinned framework.
    for row in rows
        .iter()
        .filter(|row| super::peer::selected("mempool", row))
    {
        result.push(super::peer::row(root, "mempool", row)?);
    }
    Ok(result)
}
pub(super) fn peer_recipe_reason(row: &Value) -> Option<&'static str> {
    match row["id"].as_str()? {
        "missing-input-orphan-retained" | "orphan-expiry-equality" | "orphan-hysteresis-skips-expiry" |
        "orphan-parent-only-enqueues" | "orphan-revalidation-accepts" | "orphan-revalidation-can-refuse" |
        "orphan-admission-aggregate-134" | "orphan-admission-aggregate-135" | "orphan-p2p-size-60" |
        "orphan-p2p-size-61" | "orphan-selected-arrival-revalidation" =>
            Some("persistent orphan storage/expiry/retry requires a withheld-parent loopback P2P witness; RPC does not retain this pool; [SRC] src/txn_validator.cpp:163-177,244-248; src/validation.cpp:1873-1915 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        "reject-parent-prevents-orphan-retention" | "reject-filter-p2p-silence" | "reject-filter-rpc-retries" =>
            Some("recent-reject membership is not exposed by RPC; establish the cache and observe inventory/request behavior with the loopback peer; [SRC] src/validation.cpp:1896-1931; src/net/net_processing.cpp:930-952 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        "absurd-fee-p2p-no-rpc-ceiling" =>
            Some("the row specifically selects P2P-origin admission without the RPC fee ceiling; an RPC allowhighfees call is not that origin; [SRC] src/net/net_processing.cpp:3379-3393; src/rpc/rawtransaction.cpp:1571-1594 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        // [D] 2026-10-13, lane reclass-66b (H6 road (c)).
        name if LIMITED_ROWS.contains(&name) =>
            Some("the limited request (fUseLimits, its priority, its pending queue) exists only in the asynchronous validator, which a P2P transaction enters at high priority; synchronous RPC validation passes fUseLimits=false; [SRC] src/net/net_processing.cpp:3379-3393; src/txn_validator.cpp:169-188,359-538,567-645 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        _ => None,
    }
}

// [D] 2026-10-13: the peer instrument covers every formerly deferred row.
fn needs_peer(_row: &Value) -> Option<&'static str> {
    None
}

// Commit boundary pass. Every selected frame retains its bytes except the
// materialized outpoints. Unselected boundaries remain pending.
fn commit_stage(root: &Path, rows: &[Value]) -> Result<Vec<Value>> {
    let mut results = vec![];
    for row in rows.iter().filter(|row| row["boundary"] == "commit") {
        let name = text(&row["id"])?;
        let unavailable = match name {
            "regular-census-size-equal-10000" | "regular-census-size-equal-0" =>
                Some("this row overrides a compiled transaction-size consensus getter to 61 bytes; the pinned getters return compiled constants with no launch or RPC override (src/configscriptpolicy.cpp:397-412)"),
            "outer-block-failure-mandatory-success" =>
                Some("the row selects skipScriptFlags=640; sendrawtransaction accepts only the transaction and fee booleans, with no script-flag override selector (src/rpc/rawtransaction.cpp:1560-1594); the exact request is unavailable on this cut-1 RPC"),
            _ => None,
        };
        if let Some(reason) = unavailable {
            results.push(
                json!({"id":row["id"],"unrealizable":reason,"label":"[X]","boundary":"commit"}),
            );
            continue;
        }
        if !matches!(
            name,
            "sequence-disabled-after-genesis"
                | "inputs-budget-observation-ignored-without-limits"
                | "sigops-at-cap"
                | "absurd-fee-zero-disables"
                | "ancestor-below-limit"
                | "root-zero-ancestor-limit"
                | "held-valid-update"
                | "held-update-rate-at"
                | "held-repeat-not-update"
        ) {
            continue;
        }
        let mut extra = "genesisactivationheight=1\nchronicleactivationheight=1000000\nacceptnonstdtxn=0\nacceptnonstdoutputs=1\n".to_owned();
        // [SRC] src/init.cpp:3211-3218,2536-2551; src/wallet/wallet.cpp:4406-4425;
        // src/time_locked_mempool.cpp:394-408 at the receipt's pin.
        match name {
            "sigops-at-cap" => extra.push_str("maxtxsigopscountspolicy=1\n"),
            "absurd-fee-zero-disables" => extra.push_str("maxtxfee=0.00000001\n"),
            "ancestor-below-limit" => extra.push_str("limitancestorcount=2\n"),
            "root-zero-ancestor-limit" => {
                extra.push_str("limitancestorcount=0\nlimitcpfpgroupmemberscount=0\n")
            }
            "held-update-rate-at" => extra.push_str("mempoolnonfinalmaxreplacementrate=1\n"),
            _ => (),
        }
        let dir = root.join(format!("mempool-commit-{name}"));
        let mut n = match start_boundary(dir.clone(), &extra) {
            Ok(node) => node,
            Err(error)
                if name == "root-zero-ancestor-limit"
                    && error.contains(
                        "The maximal number of the in-mempool ancestors must be greater than 0",
                    ) =>
            {
                results.push(json!({"id":row["id"],"label":"[X]","boundary":"commit",
                    "unrealizable":"the pinned launch setter rejects the row's zero ancestor cap; no running instance can select that configuration through this launch/RPC surface; [SRC] src/config.cpp:411-421 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
                    "launch_error":error,"conf":fs::read_to_string(dir.with_extension("attempt-0").join("bitcoin.conf")).map_err(|e|e.to_string())?}));
                continue;
            }
            Err(error) => return Err(error),
        };
        let hashes = n.mine(100, 1_699_990_000)?;
        let body = n.call("getblock", json!([hashes[0], 1]))?;
        let coin = n.raw_tx(&body["tx"][0])?;
        let us = row["utxo"].as_array().ok_or("commit UTXO array")?;
        if us.len() != 1 || us[0]["index"] != 0 {
            return Err("commit funding shape not implemented".into());
        }
        let u = &us[0];
        let lock = hex::decode(u["script"].as_str().unwrap_or("51")).map_err(|e| e.to_string())?;
        let f = spend_to(&coin, u["value"].as_u64().unwrap_or(1000), 1, lock);
        let (_, funded) = n.submit(&[cb(101, name), f.clone()], 1_699_995_000)?;
        if block_judgment(&funded) != json!({"status":"ok"}) {
            return Err(format!("commit funding refused: {funded}"));
        }
        n.mine(99, 1_699_999_000)?;
        let mut points: BTreeMap<([u8; 32], u32), ([u8; 32], u32)> = BTreeMap::new();
        let original_hash: [u8; 32] = hex::decode(text(&u["hash"])?)
            .map_err(|e| e.to_string())?
            .try_into()
            .map_err(|_| "UTXO hash length")?;
        points.insert((original_hash, 0), (f.txid_internal(), 0));
        let decode =
            |value: &Value| RawTx::decode(&hex::decode(text(value)?).map_err(|e| e.to_string())?);
        // an outpoint (txid internal, vout) of the fixture and its live replacement
        type Points = BTreeMap<([u8; 32], u32), ([u8; 32], u32)>;
        let remap = |tx: &mut RawTx, points: &Points| -> Result<()> {
            for input in &mut tx.inputs {
                let (hash, index) = points
                    .get(&(input.txid, input.vout))
                    .ok_or("unmaterialized commit input")?;
                input.txid = *hash;
                input.vout = *index;
            }
            Ok(())
        };
        let mut symbol_ids = BTreeMap::new();
        let mut setup_txs = vec![];
        let mut before_accepted = vec![];
        let mut before_held = vec![];
        for (field, expected_pool) in [
            ("accepted", &mut before_accepted),
            ("nonFinal", &mut before_held),
        ] {
            for entry in row["pool"][field].as_array().into_iter().flatten() {
                let old = decode(&entry["tx"])?;
                let mut tx = old.clone();
                remap(&mut tx, &points)?;
                let reply = n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
                if reply.get("error").is_some() {
                    return Err(format!("commit pool setup refused: {reply}"));
                }
                for index in 0..tx.outputs.len() {
                    points.insert(
                        (old.txid_internal(), index as u32),
                        (tx.txid_internal(), index as u32),
                    );
                }
                symbol_ids.insert(hex::encode(old.txid_internal()), id(&tx));
                expected_pool.push(id(&tx));
                setup_txs.push(material(&tx));
            }
        }
        let sort_pool = |pool: Value| -> Result<Value> {
            let mut ids: Vec<String> = pool
                .as_array()
                .ok_or("pool array")?
                .iter()
                .map(|id| text(id).map(str::to_owned))
                .collect::<Result<_>>()?;
            ids.sort();
            Ok(json!(ids))
        };
        before_accepted.sort();
        before_held.sort();
        let pre_accepted = sort_pool(n.call("getrawmempool", json!([]))?)?;
        let pre_held = sort_pool(n.call("getrawnonfinalmempool", json!([]))?)?;
        let pre_orphan = n.call("getorphaninfo", json!([]))?;
        if pre_accepted != json!(before_accepted)
            || pre_held != json!(before_held)
            || pre_orphan["size"] != 0
        {
            return Err("commit initial pool state differs from materialized row".into());
        }
        let old = decode(&row["tx"])?;
        let mut tx = old.clone();
        remap(&mut tx, &points)?;
        symbol_ids.insert(hex::encode(old.txid_internal()), id(&tx));
        let reply = n.receipt(
            "sendrawtransaction",
            json!([hex::encode(tx.encode()), name == "absurd-fee-zero-disables"]),
        )?;
        let accepted = sort_pool(n.call("getrawmempool", json!([]))?)?;
        let held = sort_pool(n.call("getrawnonfinalmempool", json!([]))?)?;
        let orphan = n.call("getorphaninfo", json!([]))?;
        if name == "held-repeat-not-update" {
            if reply["error"]["code"] != -27
                || reply["error"]["message"] != "Transaction already in the mempool"
                || accepted != pre_accepted
                || held != pre_held
            {
                return Err(format!("repeated-held RPC prefilter observation differed: reply={reply}; accepted={accepted}; pre_accepted={pre_accepted}; held={held}; pre_held={pre_held}"));
            }
            n.stop()?;
            results.push(json!({"id":row["id"],"label":"[X]","boundary":"commit",
                "verdict":"rpc-precheck","recipe":"Materialize the held row, resubmit the identical frame and read both pools; the RPC prefilter refuses it without reaching commit. The stage rejection remains unobserved.",
                "rpc_precheck":{"code":-27,"message":"Transaction already in the mempool","handler":"src/rpc/rawtransaction.cpp:1598-1664"},
                "expected":row["expected"],"expected_label":"[D]","observed":{"submission":reply,"accepted":accepted,"held":held,"orphans":orphan},
                "fixtures":{"funding":material(&f),"setup_transactions":setup_txs,"transaction":material(&tx),"conf":n.conf},"rpc":std::mem::take(&mut n.calls)}));
            continue;
        }
        let judgment = if let Some(rejection) = node_reject(&reply) {
            rejection
        } else if held
            .as_array()
            .or_err("held.as_array()")?
            .contains(&json!(id(&tx)))
        {
            json!({"status":"heldNonFinal"})
        } else if accepted
            .as_array()
            .or_err("accepted.as_array()")?
            .contains(&json!(id(&tx)))
        {
            json!({"status":"accepted"})
        } else {
            return Err("commit RPC success without settled membership".into());
        };
        let e = &row["expected"];
        let expected_judgment = if e["status"] == "rejected" {
            json!({"status":"rejected","namespace":"node","code":e["code"],"reason":e["reason"]})
        } else {
            json!({"status":e["status"]})
        };
        let project_ids = |field: &str, fallback: Vec<String>| -> Result<Value> {
            let mut ids = if let Some(values) = e[field].as_array() {
                values
                    .iter()
                    .map(|v| {
                        symbol_ids
                            .get(text(v)?)
                            .cloned()
                            .ok_or("unmapped expected id".into())
                    })
                    .collect::<Result<Vec<_>>>()?
            } else {
                fallback
            };
            ids.sort();
            Ok(json!(ids))
        };
        let expected_accepted = if e["status"] == "accepted" {
            let mut ids = before_accepted.clone();
            ids.push(id(&tx));
            ids
        } else {
            before_accepted.clone()
        };
        let expected_held = if e["status"] == "heldNonFinal" {
            vec![id(&tx)]
        } else {
            before_held.clone()
        };
        let expected = json!({"judgment":expected_judgment,"accepted":project_ids("accepted",expected_accepted)?,"held":project_ids("held",expected_held)?,"orphans":0});
        let observed =
            json!({"judgment":judgment,"accepted":accepted,"held":held,"orphans":orphan["size"]});
        n.stop()?;
        results.push(measured(row,observed,expected,
            "Commit boundary: fund the row UTXO as a real 1000-satoshi OP_TRUE output at 101, mine to tip 200, then materialize any declared accepted/held parent using its exact frame except remapped outpoints. Verify initial pools before submitting the exact row frame with only its outpoints remapped. Genesis 1 preserves the consumed post-Genesis branches of unlaunchable Genesis 0. Preserve byte size, scripts, version, locktime and sequences. Select the row sigop, fee, ancestor or held-update setting; zero absurd fee uses allowhighfees. Compare exact RPC judgment and settled accepted/held/orphan sets. Internal stage trace and inactive budget observations are not RPC fields. The zero-budget-observation row uses the synchronous unlimited path, so that unused observation is not inferred as an event.",
            std::mem::take(&mut n.calls),json!({"funding":material(&f),"setup_transactions":setup_txs,"transaction":material(&tx),"original_transaction":row["tx"],"initial_pools":{"accepted":pre_accepted,"held":pre_held,"orphan":pre_orphan},"submission":reply,"conf":n.conf})));
    }
    Ok(results)
}

// S3, lane s6-66-mem. Pinned admission boundaries, separate from the
// spec-only trace. No limited synchronous request is fabricated.
fn unavailable_boundary(row: &Value) -> Option<&'static str> {
    match row["id"].as_str()? {
        "regular-census-sigop-cap" => Some("the row selects a sigop cap of 1; the pinned getter returns the compiled pre-Genesis cap 20000 with no launch or RPC selector (src/config.cpp:2417-2420)"),
        "regular-census-size-over-10000" => Some("the row selects a pre-Genesis size cap of 60 bytes; the pinned getter returns the compiled constant with no launch or RPC selector (src/configscriptpolicy.cpp:397-405)"),
        "regular-census-size-over-0" => Some("the row selects a post-Genesis size cap of 60 bytes; the pinned getter returns the compiled constant with no launch or RPC selector (src/configscriptpolicy.cpp:408-412)"),
        "held-rate-zero-elapsed" => Some("the row requires a preset full replacement bucket and exactly zero elapsed system_clock time; setmocktime only sets GetTime, and RPC exposes neither the bucket fill/last-drain setters nor that clock (src/leaky_bucket.h:65-102; src/utiltime.cpp:22-33)"),
        "promotion-visit-cap-0" => Some("the row sets maxPrimaryPromotionVisits to 0; the pinned private constexpr is 1000 with no launch or RPC setter (src/txmempool.h:423; src/txmempool.cpp:481-565)"),
        "promotion-visit-cap-1" => Some("the row sets maxPrimaryPromotionVisits to 1; the pinned private constexpr is 1000 with no launch or RPC setter (src/txmempool.h:423; src/txmempool.cpp:481-565)"),
        // [D] 2026-10-14 (lane det-wallet): re-cut for both builds after #121;
        // the ceiling is reachable on the wallet build, the detector state is not.
        "earlier-fee-overrides-detector" => Some("the row's distinct condition is a competitor holding the row's outpoint in the double-spend detector while the row is at the absurd-fee check; the detector holds an entry only from that competitor's insertion after its script checks to its removal after its commit, inside one validation task, no RPC reads it, and a row rejected at the fee check never reaches its own detector step (src/validation.cpp:1249-1254,1484-1494,1866-1870; src/txn_double_spend_detector.cpp:11-58). The 99-satoshi ceiling itself is selected on the wallet build with -maxtxfee=0.00000099 and judged by absurd-fee-above, the same transaction and request (src/init.cpp:3190-3192; src/wallet/wallet.cpp:4406-4418; src/rpc/rawtransaction.cpp:1571-1574,2014-2023); the build without the wallet keeps the default ceiling (src/validation.h:79). On neither build is the detector state producible as a witnessed condition, so the ordering is not judged (2026-10-14, at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        _ => None,
    }
}

// Binding is an exclusive kernel probe in Node::start. Retry the handoff race
// after the probe sockets close; failed Node values stop/reap only their child.
fn start_boundary(dir: PathBuf, extra: &str) -> Result<Node> {
    start_boundary_on(dir, extra, Build::Record)
}
fn start_boundary_on(dir: PathBuf, extra: &str, build: Build) -> Result<Node> {
    for attempt in 0..20 {
        let path = dir.with_extension(format!("attempt-{attempt}"));
        match Node::start_on(path, 1_000_001, extra, build) {
            Ok(node) => return Ok(node),
            Err(e)
                if e.contains("no free RPC/P2P pair")
                    || e.contains("Unable to bind")
                    || e.contains("Unable to start HTTP server") =>
            {
                thread::sleep(Duration::from_millis(200));
            }
            Err(e) => return Err(e),
        }
    }
    Err("exclusive port probe retries exhausted".into())
}

const BOUNDARY_KINDS: &[&str] = &[
    "heldMaintenance",
    "fee",
    "sequence",
    "alreadyKnown",
    "promotion",
    "sigops",
    "inputStandard",
    "conflict",
    "scripts",
    "ancestors",
    "inputs",
    "finality",
    "regular",
    "expiry",
];

fn boundary_stage(root: &Path, rows: &[Value], kind: &str) -> Result<Vec<Value>> {
    if kind == "heldMaintenance" {
        return held_maintenance(root, rows);
    }
    if !BOUNDARY_KINDS.contains(&kind) {
        return Err(format!("unimplemented boundary recipe: {kind}"));
    }
    let mut results = vec![];
    for row in rows.iter().filter(|r| {
        (r["boundary"] == kind || (kind == "fee" && r["id"] == "absurd-fee-equality"))
            && needs_peer(r).is_none()
            && !super::peer::selected("mempool", r)
            && !matches!(
                r["id"].as_str(),
                Some(
                    "script-eval-false"
                        | "nonfinal-pre-genesis"
                        | "regular-empty-inputs"
                        | "regular-empty-outputs"
                        | "regular-duplicate-input"
                )
            )
    }) {
        if kind == "fee"
            && !matches!(
                row["id"].as_str(),
                Some(
                    "absurd-fee-above"
                        | "absurd-fee-default-rpc"
                        | "absurd-fee-equality"
                        | "debug-fee-floor"
                        | "earlier-fee-overrides-detector"
                )
            )
        {
            continue;
        }
        if let Some(absent) = Build::of(row)?.absent_row(row)? {
            results.push(absent);
            continue;
        }
        if let Some(reason) = unavailable_boundary(row) {
            results
                .push(json!({"id":row["id"],"boundary":kind,"unrealizable":reason,"label":"[X]"}));
            continue;
        }
        let name = text(&row["id"])?;
        let genesis = row["context"]["genesisHeight"].as_u64().unwrap_or(0).max(1);
        let chronicle = row["context"]["chronicleHeight"]
            .as_u64()
            .unwrap_or(1_000_000);
        let tip = row["context"]["tipHeight"].as_u64().unwrap_or(200)
            + if kind == "sequence" { 100 } else { 0 };
        let require = !row["cfg"]["requireStandard"].as_bool().unwrap_or(true);
        let outputs = row["cfg"]["acceptNonStdOutputs"].as_bool().unwrap_or(true);
        let mut extra = format!("genesisactivationheight={genesis}\nchronicleactivationheight={chronicle}\nacceptnonstdtxn={}\nacceptnonstdoutputs={}\n", u8::from(require), u8::from(outputs));
        if let Some(grace) = row["cfg"]["chronicleGracefulPeriod"].as_u64() {
            extra.push_str(&format!("maxchroniclegracefulperiod={grace}\n"));
        }
        if kind == "expiry" {
            extra.push_str("mempoolexpiry=1\n");
        }
        if name == "nonfinal-disabled-pool" {
            extra.push_str("maxmempoolnonfinal=0\n");
        }
        if name == "held-update-rate-over" {
            extra.push_str("mempoolnonfinalmaxreplacementrate=1\n");
        }
        if name == "ancestor-at-limit" {
            extra.push_str("limitancestorcount=1\n");
        }
        if name == "secondary-ancestor-at-limit" {
            extra.push_str("limitcpfpgroupmemberscount=1\n");
        }
        if let Some(cap) = row["cfg"]["maxTxSigOpsCountPolicy"].as_u64() {
            extra.push_str(&format!("maxtxsigopscountspolicy={cap}\n"));
        }
        if matches!(name, "absurd-fee-above" | "absurd-fee-default-rpc") {
            extra.push_str("maxtxfee=0.00000099\n");
        }
        if name == "debug-fee-floor" {
            extra.push_str("mindebugrejectionfee=0.00000001\n");
        }
        if name == "absurd-fee-equality" {
            extra.push_str("maxtxfee=0.00000100\n");
        }
        let directory = root.join(format!("mempool-{kind}-{name}"));
        let mut n = match start_boundary_on(directory.clone(), &extra, Build::of(row)?) {
            Ok(n) => n,
            Err(e)
                if name == "secondary-ancestor-at-limit"
                    && e.contains("CPFP group members must be greater than 1") =>
            {
                results.push(json!({"id":row["id"],"boundary":kind,"label":"[X]","unrealizable":"the row selects secondary ancestor cap 1; the pinned launch setter requires a value greater than 1 (src/config.cpp:429-440), and the exact owned launch is refused","launch_error":e,"conf":fs::read_to_string(directory.with_extension("attempt-0").join("bitcoin.conf")).map_err(|e|e.to_string())?}));
                continue;
            }
            Err(e) => return Err(e),
        };
        let hashes = n.mine(100, 1_699_990_000)?;
        let body = n.call("getblock", json!([hashes[0], 1]))?;
        let coin = n.raw_tx(&body["tx"][0])?;
        let u = &row["utxo"][0];
        let lock = hex::decode(u["script"].as_str().unwrap_or("51")).map_err(|e| e.to_string())?;
        let f = spend_to(&coin, u["value"].as_u64().unwrap_or(1000), 1, lock);
        let (_, funding) = n.submit(&[cb(101, name), f.clone()], 1_699_995_000)?;
        if block_judgment(&funding) != json!({"status":"ok"}) {
            return Err(format!("funding {name}: {funding}"));
        }
        n.mine(tip - 101, 1_699_999_000)?;
        let decode = |v: &Value| RawTx::decode(&hex::decode(text(v)?).map_err(|e| e.to_string())?);
        let mut points = BTreeMap::new();
        let original = decode(&row["tx"])?;
        let symbolic = match u["hash"].as_str() {
            Some(hash) => hex::decode(hash).map_err(|e| e.to_string())?,
            None => vec![1u8; 32],
        };
        let symbolic: [u8; 32] = symbolic.try_into().map_err(|_| "symbolic hash")?;
        points.insert(symbolic, f.txid_internal());
        let remap = |tx: &mut RawTx, points: &BTreeMap<[u8; 32], [u8; 32]>| -> Result<()> {
            for input in &mut tx.inputs {
                input.txid = *points.get(&input.txid).ok_or("unknown symbolic input")?;
            }
            Ok(())
        };
        let mut setup = vec![];
        let mut pre_accepted = vec![];
        let mut pre_held = vec![];
        for (field, pool) in [("accepted", &mut pre_accepted), ("nonFinal", &mut pre_held)] {
            for entry in row["pool"][field].as_array().into_iter().flatten() {
                let old = decode(&entry["tx"])?;
                let mut parent = old.clone();
                remap(&mut parent, &points)?;
                if name == "held-update-rate-over" {
                    // Materialize the declared nonzero fill with an actual update.
                    let mut earlier = parent.clone();
                    earlier.inputs[0].sequence -= 1;
                    n.call("sendrawtransaction", json!([hex::encode(earlier.encode())]))?;
                    setup.push(material(&earlier));
                }
                if kind == "expiry" {
                    n.call(
                        "setmocktime",
                        json!([1_700_000_000u64 + if entry["time"] == 1000 { 100 } else { 0 }]),
                    )?;
                }
                n.call("sendrawtransaction", json!([hex::encode(parent.encode())]))?;
                points.insert(old.txid_internal(), parent.txid_internal());
                pool.push(json!(id(&parent)));
                setup.push(material(&parent));
            }
        }
        let mut actual_pre_accepted = n.call("getrawmempool", json!([]))?;
        let mut actual_pre_held = n.call("getrawnonfinalmempool", json!([]))?;
        let sort = |v: &mut Value| -> Result<()> {
            v.as_array_mut()
                .or_err("a pool listing as an array")?
                .sort_by_key(|x| x.as_str().unwrap_or_default().to_owned());
            Ok(())
        };
        sort(&mut actual_pre_accepted)?;
        sort(&mut actual_pre_held)?;
        pre_accepted.sort_by_key(|x| x.as_str().unwrap_or_default().to_owned());
        pre_held.sort_by_key(|x| x.as_str().unwrap_or_default().to_owned());
        if actual_pre_accepted != json!(pre_accepted) || actual_pre_held != json!(pre_held) {
            return Err("initial pool mismatch".into());
        }
        let mut tx = original.clone();
        if name == "missing-input-known-output" {
            for input in &mut tx.inputs {
                input.txid = f.txid_internal();
            }
            let (_, confirmed) =
                n.submit(&[cb((tip + 1) as u32, name), tx.clone()], 1_699_999_100)?;
            if block_judgment(&confirmed) != json!({"status":"ok"}) {
                return Err(format!("known-output confirmation: {confirmed}"));
            }
            let output = n.call("gettxout", json!([id(&tx), 0, false]))?;
            if output.is_null() {
                return Err("known output missing".into());
            }
        } else if name == "missing-input-rpc-no-handler" {
            let missing = n.call(
                "gettxout",
                json!([
                    txid_display_hex(&tx.inputs[0].txid),
                    tx.inputs[0].vout,
                    false
                ]),
            )?;
            if !missing.is_null() {
                return Err("missing fixture prevout exists".into());
            }
        } else {
            remap(&mut tx, &points)?;
        }

        if kind == "sequence" && 101 + u64::from(tx.inputs[0].sequence & 0xffff) - 1 != tip + 1 {
            return Err("relative-height equality was not rematerialized".into());
        }
        if name == "script-frozen-admission-list" {
            let params = json!([{"funds":[{"txOut":{"txId":id(&f),"vout":0}}]}]);
            let answer = n
                .rpc
                .as_mut()
                .ok_or("RPC unavailable")?
                .call("addToPolicyBlacklist", params.clone())?;
            n.calls.push(json!({"method":"addToPolicyBlacklist","params":params,"reply":{"result":answer},"source":format!("[SRC] src/rpc/frozentxo_rpc.cpp:320-344 at {PIN}")}));
            if answer["notProcessed"] != json!([]) {
                return Err(format!("freeze not applied: {answer}"));
            }
        }
        if kind == "expiry" {
            let log_before = fs::read_to_string(n.dir.join("console.log"))
                .map_err(|e| e.to_string())?
                .len();
            let now = 1_700_003_600u64 + u64::from(name != "expiry-equality-kept");
            n.call("setmocktime", json!([now]))?;
            let mut a = tx.clone();
            a.inputs.clear();
            let mut b = a.clone();
            b.lock_time = 1;
            let trigger = n.receipt(
                "sendrawtransactions",
                json!([[{"hex":hex::encode(a.encode())},{"hex":hex::encode(b.encode())}]]),
            )?;
            if trigger["result"]["invalid"].as_array().is_none_or(|v| {
                v.len() != 2
                    || v.iter().any(|r| {
                        r["reject_code"] != 16 || r["reject_reason"] != "bad-txns-vin-empty"
                    })
            }) {
                return Err(format!("expiry sweep trigger: {trigger}"));
            }
            let start = Instant::now();
            let removed = if name == "expiry-equality-kept" {
                0
            } else {
                setup.len()
            };
            let needle = format!("Expired {removed} transactions from the memory pool");
            let completion = loop {
                let log =
                    fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
                let fresh = log.get(log_before..).ok_or("log truncated")?;
                if removed == 0 || fresh.contains(&needle) {
                    break fresh.to_owned();
                }
                if start.elapsed() > Duration::from_secs(5) {
                    return Err("missing expiry completion log".into());
                }
                thread::sleep(Duration::from_millis(10));
            };
            let accepted = n.call("getrawmempool", json!([]))?;
            let held = n.call("getrawnonfinalmempool", json!([]))?;
            let orphan = n.call("getorphaninfo", json!([]))?;
            let expected_accepted = if removed == 0 {
                json!(pre_accepted)
            } else {
                json!([])
            };
            let observed = json!({"accepted":accepted,"held":held,"orphans":orphan["size"]});
            let expected = json!({"accepted":expected_accepted,"held":[],"orphans":0});
            n.stop()?;
            let mut r=measured(row,observed,expected,"Rematerialize the expiry comparison at the launchable one-hour interval: root age 3600 or 3601 seconds, with the declared younger descendant still below the threshold. Preserve every transaction frame except outpoints. Complete a two-item rejected RPC batch, observe its rejection envelopes and a fresh expiry log when roots expire, then compare settled pools. Equality uses completed synchronous sweep plus retained membership, never sleep as completion.",std::mem::take(&mut n.calls),json!({"funding":material(&f),"setup_transactions":setup,"initial_pools":{"accepted":actual_pre_accepted,"held":actual_pre_held},"trigger":trigger,"completion_log":completion,"conf":n.conf}));
            r["boundary"] = json!(kind);
            results.push(r);
            continue;
        }
        if row["expected"]["status"] == "maintenance" {
            return Err("maintenance recipe missing".into());
        }
        let reply = n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
        let accepted = n.call("getrawmempool", json!([]))?;
        let held = n.call("getrawnonfinalmempool", json!([]))?;
        let orphans = n.call("getorphaninfo", json!([]))?;
        if kind == "alreadyKnown" {
            if reply["error"]["code"] != -27
                || reply["error"]["message"] != "Transaction already in the mempool"
                || accepted != actual_pre_accepted
                || held != actual_pre_held
            {
                return Err(format!("repeat precheck differed: {reply}"));
            }
            n.stop()?;
            results.push(json!({"id":row["id"],"boundary":kind,"label":"[X]","verdict":"rpc-precheck","rpc_precheck":{"code":-27,"message":"Transaction already in the mempool","handler":"src/rpc/rawtransaction.cpp:1598-1664"},"observed":{"submission":reply,"accepted":accepted,"held":held,"orphans":orphans},"expected":row["expected"],"expected_label":"[D]","fixtures":{"funding":material(&f),"transaction":material(&tx),"conf":n.conf,"setup_transactions":setup},"rpc":std::mem::take(&mut n.calls)}));
            continue;
        }
        if matches!(
            name,
            "absurd-fee-above" | "absurd-fee-default-rpc" | "absurd-fee-equality"
        ) && reply.get("error").is_none()
        {
            let wallet = n
                .rpc
                .as_mut()
                .ok_or("RPC unavailable")?
                .call("getwalletinfo", json!([]));
            let envelope = match wallet {
                Ok(v) => json!({"result":v}),
                Err(e) => {
                    json!({"error":e.strip_prefix("rpc error: ").and_then(|v|serde_json::from_str::<Value>(v).ok()).ok_or(e)?})
                }
            };
            n.calls.push(json!({"method":"getwalletinfo","params":[],"reply":envelope,"source":format!("[SRC] src/rpc/server.cpp:568-570; src/wallet/rpcwallet.cpp:2798-2876 at {PIN}")}));
            if envelope["error"]["code"] == -32601
                && envelope["error"]["message"] == "Method not found"
            {
                n.stop()?;
                results.push(json!({"id":row["id"],"boundary":row["boundary"],"label":"[X]","unrealizable":"the selected pinned build lacks the wallet RPC registration and ignores the requested maxtxfee ceiling; loading that selector is guarded by ENABLE_WALLET (src/init.cpp:3190-3192; src/wallet/wallet.cpp:4406-4425), while RPC consumes the unchanged global maxTxFee (src/rpc/rawtransaction.cpp:1571-1574). The configured-limit boundary was not reached","observed":{"submission":reply,"accepted":accepted,"held":held,"orphans":orphans,"wallet_probe":envelope},"fixtures":{"funding":material(&f),"transaction":material(&tx),"conf":n.conf},"rpc":std::mem::take(&mut n.calls)}));
                continue;
            }
        }
        let judgment = if name == "missing-input-rpc-no-handler" {
            if reply["error"]["code"] != -25 || reply["error"]["message"] != "Missing inputs" {
                return Err(format!("missing-input envelope: {reply}"));
            }
            json!({"status":"orphan"})
        } else {
            node_reject(&reply).unwrap_or(json!({"status":"accepted"}))
        };
        let e = &row["expected"];
        let expected_judgment = if e["status"] == "rejected" {
            json!({"status":e["status"],"namespace":"node","code":e["code"],"reason":e["reason"]})
        } else {
            json!({"status":e["status"]})
        };
        let mut expected = json!({"judgment":expected_judgment,"accepted":pre_accepted,"held":pre_held,"orphans":0});
        // [D] 2026-10-14 (#121, lane wallet-rows-b): an accepted row's settled
        // pool is the initial pool plus the submitted transaction, as
        // `mempool_more` projects it. Before the wallet build every row reaching
        // this projection was rejected (run 20261014-050643 found the omission).
        if e["status"] == "accepted" {
            let mut pool = pre_accepted.clone();
            pool.push(json!(id(&tx)));
            pool.sort_by_key(|x| x.as_str().unwrap_or("").to_owned());
            expected["accepted"] = json!(pool);
        }
        if name == "missing-input-rpc-no-handler" {
            expected["judgment"] = json!({"status":"orphan"});
        }
        let observed =
            json!({"judgment":judgment,"accepted":accepted,"held":held,"orphans":orphans["size"]});
        n.stop()?;
        let mut result=measured(row,observed,expected,
            "Materialize the row UTXO with its value and script in a live height-101 block; mine to the declared tip, retain the consumed coin era and activation/grace settings. Remap only input outpoints in the row frame. For frozen admission install the exact outpoint through the policy blacklist RPC. Compare exact rejection namespace/code/reason and settled pool sets; internal trace is outside the RPC projection.",
            std::mem::take(&mut n.calls),json!({"funding":material(&f),"transaction":material(&tx),"conf":n.conf,"submission":reply,"setup_transactions":setup,"initial_pools":{"accepted":actual_pre_accepted,"held":actual_pre_held}}));
        result["boundary"] = json!(kind);
        if kind == "sequence" {
            result["recipe"]=json!("Preserve the relative-height equality by translating the symbolic coin height 1 and tip 200 to live coin height 101 and tip 300. Keep sequence 201 and all frame bytes except the funded outpoint. Assert 101+201-1 equals the successor height 301 before submission. Both coin and tip stay pre-Genesis; compare exact non-BIP68-final rejection and empty pools.");
        }
        if kind == "inputs" {
            result["recipe"]=json!("For absent inputs retain the absent outpoint, check gettxout=null, and require the exact -25 Missing inputs envelope plus empty pools. This is the stage orphan outcome without retained orphan storage, not an RPC prefilter. For the known-output row confirm the remapped row transaction on the live tip, check its unspent output, then resubmit it with its input spent and output present. Compare exact node code/reason; only output presence is consumed by this branch. Funding unrelated to the absent-input row is setup, not a fixture coin.");
        }
        results.push(result);
    }
    Ok(results)
}

#[cfg(test)]
mod lane_tests {
    use super::*;
    #[test]
    fn unavailable_recipe_cannot_fall_through_to_admission() {
        assert!(boundary_stage(Path::new("unused"), &[], "eviction").is_err());
    }
    // Explicit live replay, isolated from ordinary cargo test. Run the compiled
    // test binary from the repository root with these environment inputs.
    #[test]
    #[ignore]
    fn lane_replay() {
        signals();
        let record = std::env::var("MEM_RECORD").unwrap();
        assert!(
            record.starts_with("docs/records/")
                && (record.ends_with("-s6-66-mem-regtest-s3.md")
                    || record.ends_with("-s6-66-mem2-regtest-s3.md")
                    || record.ends_with("-s6-66-mem3-regtest-s3.md"))
        );
        let kind = std::env::var("MEM_KIND").unwrap();
        let run_id = std::env::var("MEM_RUN_ID").unwrap();
        assert!(
            (run_id.starts_with("s6-66-mem-")
                || run_id.starts_with("s6-66-mem2-")
                || run_id.starts_with("s6-66-mem3-"))
                && run_id
                    .bytes()
                    .all(|c| c.is_ascii_alphanumeric() || c == b'-')
        );
        let binary = Build::Record.located();
        let version = Command::new(binary).arg("-version").output().unwrap();
        let version = String::from_utf8_lossy(&version.stdout)
            .lines()
            .next()
            .unwrap()
            .to_owned();
        assert_eq!(version, format!("Bitcoin SV version {VERSION}"));
        let root = PathBuf::from(std::env::var("HOME").unwrap())
            .join("bsv/targets/spec-oracle-scenarios")
            .join(&run_id);
        fs::create_dir(&root).unwrap();
        let started = Command::new("date")
            .args(["-u", "+%Y-%m-%dT%H:%M:%SZ"])
            .output()
            .unwrap();
        let start = Instant::now();
        let rows = if let Some(boundary) = kind.strip_prefix("round3-") {
            round3_stage(&root, &row_read("mempool").unwrap(), boundary)
        } else if let Some(boundary) = kind.strip_prefix("round2-") {
            round2_stage(&root, &row_read("mempool").unwrap(), boundary)
        } else if kind == "regression" {
            run(&root)
        } else {
            boundary_stage(&root, &row_read("mempool").unwrap(), &kind)
        }
        .unwrap();
        if kind == "regression" {
            let current = row_read("mempool").unwrap();
            let mut ids = BTreeSet::new();
            for row in &rows {
                assert!(
                    ids.insert(text(&row["id"]).unwrap().to_owned()),
                    "duplicate recipe row"
                );
                let cell = current.iter().find(|r| r["id"] == row["id"]).unwrap()["node"]
                    .as_str()
                    .unwrap()
                    .to_owned();
                let matches = if row.get("unrealizable").is_some() {
                    cell.starts_with("unrealizable:")
                } else if row["verdict"] == "rpc-precheck" {
                    cell.starts_with("rpc-precheck:")
                } else {
                    cell.starts_with(&format!("measured {}", text(&row["verdict"]).unwrap()))
                };
                assert!(
                    matches,
                    "regression differs from recorded column for {}: {}",
                    row["id"], cell
                );
            }
            let expected = current
                .iter()
                .filter(|r| {
                    let n = r["node"].as_str().unwrap();
                    !n.starts_with("pending") && !n.starts_with("needs-peer")
                })
                .count();
            assert_eq!(
                ids.len(),
                expected,
                "recipe coverage differs from judged column"
            );
            println!(
                "mempool recipe regression: GREEN [X] ([M] {} unique judged rows)",
                ids.len()
            );
        }
        assert!(!rows.is_empty());
        let receipt = json!({"label":"[M]","pin":PIN,"version":version,"run_id":run_id,"started":String::from_utf8_lossy(&started.stdout).trim(),"wall_seconds":start.elapsed().as_secs_f64(),"kind":kind,"module_sha256":hex::encode(bsv_rs::primitives::hash::sha256(&fs::read("harness/src/scenarios/mempool.rs").unwrap())),"rows":rows});
        write_json(
            &PathBuf::from(std::env::var("MEM_RECEIPT").unwrap()),
            &receipt,
        )
        .unwrap();
        for r in receipt["rows"].as_array().unwrap() {
            println!(
                "{}: {} [X]",
                r["id"],
                r.get("verdict")
                    .or_else(|| r.get("unrealizable"))
                    .unwrap_or(&r["pending"])
            );
        }
    }
}

// [SRC] src/time_locked_mempool.cpp:611-660: finality is checked before
// inclusive expiry. A separate expired canary witnesses the scheduled sweep.
fn held_maintenance(root: &Path, rows: &[Value]) -> Result<Vec<Value>> {
    let mut results = vec![];
    for row in rows.iter().filter(|r| r["boundary"] == "heldMaintenance") {
        let name = text(&row["id"])?;
        if name == "held-height-final-queues-before-expiry" {
            results.push(json!({"id":name,"boundary":"heldMaintenance","label":"[X]","unrealizable":"the row judges the intermediate pending revalidation queue after periodic finalisation; the scheduler enqueues the request and validation consumes it, while RPC exposes accepted/held membership but no pending request-id snapshot (src/time_locked_mempool.cpp:634-653; src/rpc/blockchain.cpp:440-550). Settled admission cannot establish that exact intermediate queue"}));
            continue;
        }
        let extra="genesisactivationheight=1\nchronicleactivationheight=1000000\nacceptnonstdtxn=0\nacceptnonstdoutputs=1\nmempoolexpirynonfinal=1\nchecknonfinalfreq=10\n";
        let mut n = start_boundary(root.join(format!("mempool-heldMaintenance-{name}")), extra)?;
        let hashes = n.mine(100, 1_699_990_000)?;
        let block = n.call("getblock", json!([hashes[0], 1]))?;
        let coin = n.raw_tx(&block["tx"][0])?;
        let f = spend_to(&coin, 2000, 1, vec![0x51]);
        let (_, funding) = n.submit(&[cb(101, name), f.clone()], 1_699_995_000)?;
        if block_judgment(&funding) != json!({"status":"ok"}) {
            return Err(format!("held funding: {funding}"));
        }
        let split = RawTx {
            version: 2,
            inputs: vec![RawInput {
                txid: f.txid_internal(),
                vout: 0,
                script: vec![],
                sequence: u32::MAX,
            }],
            outputs: vec![
                RawOutput {
                    satoshis: 1000,
                    script: vec![0x51]
                };
                2
            ],
            lock_time: 0,
        };
        let (_, split_reply) = n.submit(&[cb(102, name), split.clone()], 1_699_995_001)?;
        if block_judgment(&split_reply) != json!({"status":"ok"}) {
            return Err(format!("held split: {split_reply}"));
        }
        n.mine(98, 1_699_999_000)?;
        let mut tx = RawTx::decode(
            &hex::decode(text(&row["pool"]["nonFinal"][0]["tx"])?).map_err(|e| e.to_string())?,
        )?;
        tx.inputs[0].txid = split.txid_internal();
        let mut canary = tx.clone();
        canary.inputs[0].vout = 1;
        n.call("setmocktime", json!([1_700_000_000u64]))?;
        n.call("sendrawtransaction", json!([hex::encode(canary.encode())]))?;
        let before = name == "held-expiry-before";
        n.call("setmocktime", json!([1_700_000_000u64 + u64::from(before)]))?;
        n.call("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
        let initial = n.call("getrawnonfinalmempool", json!([]))?;
        let set = initial.as_array().ok_or("held array")?;
        if set.len() != 2 || !set.contains(&json!(id(&tx))) || !set.contains(&json!(id(&canary))) {
            return Err("held initial state mismatch".into());
        }
        let log_before = fs::read_to_string(n.dir.join("console.log"))
            .map_err(|e| e.to_string())?
            .len();
        n.call("setmocktime", json!([1_700_003_600u64]))?;
        let start = Instant::now();
        let canary_line = format!("Purging expired non-final transaction: {}", id(&canary));
        let fixture_line = format!("Purging expired non-final transaction: {}", id(&tx));
        let completion = loop {
            let log = fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
            let fresh = log.get(log_before..).ok_or("held log truncated")?;
            if fresh.contains(&canary_line) && (before || fresh.contains(&fixture_line)) {
                break fresh.to_owned();
            }
            if start.elapsed() > Duration::from_secs(10) {
                return Err("held periodic completion not witnessed".into());
            }
            thread::sleep(Duration::from_millis(10));
        };
        // These calls acquire the pool lock after periodicChecks' exclusive
        // iteration, so the canary log is not mistaken for a half-run sweep.
        let held = n.call("getrawnonfinalmempool", json!([]))?;
        let accepted = n.call("getrawmempool", json!([]))?;
        let orphans = n.call("getorphaninfo", json!([]))?;
        let observed = json!({"accepted":accepted,"held":held,"orphans":orphans["size"]});
        let expected =
            json!({"accepted":[],"held":if before {json!([id(&tx)])} else {json!([])},"orphans":0});
        n.stop()?;
        let mut r=measured(row,observed,expected,"Rematerialize the inclusive held-expiry boundary at the launchable one-hour interval: fixture age 3600 or 3599 seconds. Keep its held frame except the funded outpoint. Add an independent canary of age 3600 on another real output. After setmocktime, require a fresh canary purge line (and fixture purge at equality), then take lock-protected settled pool reads. Both requests remain height-nonfinal throughout. Internal pending queue is not an RPC observation; the separate finalising-queue row is individually unavailable.",std::mem::take(&mut n.calls),json!({"funding":material(&f),"split":material(&split),"fixture":material(&tx),"canary":material(&canary),"initial_held":initial,"completion_log":completion,"conf":n.conf}));
        r["boundary"] = json!("heldMaintenance");
        results.push(r);
    }
    Ok(results)
}

// S3, lane s6-66-mem2. Each recipe retains its own calibration receipts.
// [SRC] src/rpc/blockchain.cpp:2613-2673 at PIN; family-local extension
// leaves the shared RPC dispatch table untouched.
fn pool_info(n: &mut Node) -> Result<Value> {
    let params = json!([]);
    let result = n
        .rpc
        .as_mut()
        .ok_or("RPC not ready")?
        .call("getmempoolinfo", params.clone())?;
    n.calls.push(json!({"method":"getmempoolinfo","params":params,
        "source":format!("[SRC] src/rpc/blockchain.cpp:2613-2673 at {PIN}"),"reply":{"result":result}}));
    Ok(result)
}

const ROUND2_CONF: &str = "genesisactivationheight=1\nchronicleactivationheight=1000000\nacceptnonstdtxn=0\nacceptnonstdoutputs=1\n";

fn round2_fund(n: &mut Node, row: &Value) -> Result<(RawTx, RawTx)> {
    let hashes = n.mine(100, 1_699_990_000)?;
    let body = n.call("getblock", json!([hashes[0], 1]))?;
    let coin = n.raw_tx(&body["tx"][0])?;
    let funding = spend_to(&coin, 1000, 1, vec![0x51]);
    let (_, reply) = n.submit(
        &[cb(101, text(&row["id"])?), funding.clone()],
        1_699_995_000,
    )?;
    if block_judgment(&reply) != json!({"status":"ok"}) {
        return Err(format!("funding: {reply}"));
    }
    n.mine(99, 1_699_999_000)?;
    let mut tx = RawTx::decode(&hex::decode(text(&row["tx"])?).map_err(|e| e.to_string())?)?;
    tx.inputs[0].txid = funding.txid_internal();
    Ok((funding, tx))
}

fn round2_stage(root: &Path, rows: &[Value], kind: &str) -> Result<Vec<Value>> {
    let mut results = vec![];
    // The rows this stage owns, fixed by id (S3, lane pend-66, [M] 2026-10-13):
    // they were the pending or mem2-marked rows of these kinds, and a later
    // record's tokens must not change the selection.
    const ROUND2_ROWS: &[&str] = &[
        "rolling-fee-equality",
        "rolling-fee-below",
        "consolidation-fee-delta",
        "consolidation-disabled",
        "detector-final-insertion",
        "detector-newly-committed",
        "commit-size-equality",
        "commit-size-over-cap",
        "held-size-equality",
        "held-size-over-cap",
        "trim-at-limit",
        "trim-below-limit-raises-next-rate",
        "trim-secondary-mining-cap",
        "trim-leaf-before-low-fee-parent",
        "rolling-decay-no-block-gate",
        "rolling-decay-interval-equality",
        "rolling-decay-low-usage-half-life",
        "held-rate-fractional-half-second",
        "rolling-block-resets-timestamp",
        "limit-secondary-unsigned-underflow",
    ];
    for row in rows.iter().filter(|r| {
        r["boundary"] == kind && r["id"].as_str().is_some_and(|id| ROUND2_ROWS.contains(&id))
    }) {
        let name = text(&row["id"])?;
        if name == "held-rate-fractional-half-second" {
            results.push(json!({"id":name,"label":"[X]","unrealizable":
                "the selected bucket sample requires preset fill 7200 and exactly 500000000 elapsed nanoseconds; the pinned bucket reads system_clock directly and exposes no sample/setter, while setmocktime only controls GetTime (src/leaky_bucket.h:65-102; src/utiltime.cpp:22-33). A delayed RPC cannot establish this exact sample"}));
        } else if matches!(
            name,
            "commit-size-equality" | "commit-size-over-cap" | "limit-secondary-unsigned-underflow"
        ) {
            let cap = row["cfg"]["maxMempool"].as_u64().ok_or("maxMempool")?;
            let extra = format!("{ROUND2_CONF}maxmempool={cap}B\nmaxmempoolsizedisk=0\n");
            let dir = root.join(name);
            match start_boundary(dir.clone(), &extra) {
                Ok(mut n) => { n.stop()?; return Err("tiny resident cap unexpectedly launched".into()); }
                Err(e) if e.contains("must be at least") => results.push(json!({"id":name,"label":"[X]",
                    "unrealizable":format!("the row selects resident maxMempool={cap} bytes and zero disk; the pinned launch rejects nonzero resident limits below 300 MB (src/config.cpp:2440-2456; src/init.cpp:2384-2398). Raising the cap or adding disk changes the selected configuration and byte-only accounting boundary"),
                    "launch_error":e,"conf":fs::read_to_string(dir.with_extension("attempt-0").join("bitcoin.conf")).map_err(|e|e.to_string())?})),
                Err(e) => return Err(e),
            }
        } else if kind == "detector" && row["id"] == "detector-newly-committed" {
            // The race recipe in round3_stage realizes this row.
        } else if kind == "detector" {
            results.push(detector_boundary(root, row)?);
        } else if matches!(
            name,
            "trim-at-limit"
                | "trim-below-limit-raises-next-rate"
                | "trim-leaf-before-low-fee-parent"
        ) {
            results.push(eviction_boundary(root, row)?);
        } else if name.starts_with("rolling-") || name.starts_with("consolidation-") {
            results.push(rolling_boundary(root, row)?);
        } else if matches!(name, "held-size-equality" | "held-size-over-cap") {
            results.push(held_size(root, row)?);
        } else {
            results.push(json!({"id":name,"label":"[X]","pending":"boundary recipe requires additional live history or instrumentation; no comparison made"}));
        }
    }
    Ok(results)
}

// [SRC] src/time_locked_mempool.cpp:447-478,592-607. Calibrate the actual
// estimator, then rematerialize equality/one byte over on a fresh chain.
fn held_size(root: &Path, row: &Value) -> Result<Value> {
    let name = text(&row["id"])?;
    let mut calibration = start_boundary(root.join(format!("{name}-calibration")), ROUND2_CONF)?;
    let (funding, tx) = round2_fund(&mut calibration, row)?;
    calibration.call("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
    let info = pool_info(&mut calibration)?;
    let usage = info["nonfinalusage"].as_u64().ok_or("nonfinal usage")?;
    if calibration.call("getrawnonfinalmempool", json!([]))? != json!([id(&tx)]) {
        return Err("calibration held membership".into());
    }
    calibration.stop()?;
    let calibration = json!({"funding":material(&funding),"transaction":material(&tx),"info":info,"conf":calibration.conf,"rpc":calibration.calls});
    let cap = usage - u64::from(name == "held-size-over-cap");
    let extra = format!("{ROUND2_CONF}maxmempoolnonfinal={cap}B\n");
    let mut n = start_boundary(root.join(name), &extra)?;
    let (funding, tx) = round2_fund(&mut n, row)?;
    let reply = n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
    let held = n.call("getrawnonfinalmempool", json!([]))?;
    let info = pool_info(&mut n)?;
    let judgment = node_reject(&reply).unwrap_or(json!({"status":"heldNonFinal"}));
    let expected_judgment = if name == "held-size-equality" {
        json!({"status":"heldNonFinal"})
    } else {
        json!({"status":"rejected","namespace":"node","code":259,"reason":"non-final-pool-full"})
    };
    let expected_held = if name == "held-size-equality" {
        json!([id(&tx)])
    } else {
        json!([])
    };
    let log = fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
    let evidence: Vec<_> = log
        .lines()
        .filter(|l| {
            l.contains(&id(&tx)) && (l.contains("Added non-final") || l.contains("mempool is full"))
        })
        .map(str::to_owned)
        .collect();
    if evidence.is_empty() {
        return Err("missing held insertion completion log".into());
    }
    n.stop()?;
    Ok(measured(row, json!({"judgment":judgment,"held":held}), json!({"judgment":expected_judgment,"held":expected_held}),
        "Calibrate this exact held frame's nonfinalusage on an isolated node. Relaunch a fresh chain with the byte-unit cap equal to measured usage, or usage minus one. Remap only the funding outpoint. Preserve size, locktime and sequence. The allocator coordinate replaces byte-only usage, preserving the strict > relation. Require insertion/drop log and settled held membership.",
        std::mem::take(&mut n.calls), json!({"calibration":calibration,"usage":usage,"cap":cap,"funding":material(&funding),"transaction":material(&tx),"submission":reply,"info":info,"completion":evidence,"conf":n.conf})))
}

fn rolling_setup(n: &mut Node, row: &Value, fee: u64) -> Result<(RawTx, Vec<RawTx>, RawTx)> {
    let hashes = n.mine(100, 1_699_990_000)?;
    let body = n.call("getblock", json!([hashes[0], 1]))?;
    let coin = n.raw_tx(&body["tx"][0])?;
    let funding = spend_to(&coin, 10000, 1, vec![0x51]);
    let mut split = RawTx {
        version: 2,
        inputs: vec![RawInput {
            txid: funding.txid_internal(),
            vout: 0,
            script: vec![],
            sequence: u32::MAX,
        }],
        outputs: vec![
            RawOutput {
                satoshis: 1000,
                script: vec![0x51]
            };
            9
        ],
        lock_time: 0,
    };
    // Both funding transactions are included in the same valid live block.
    let (_, reply) = n.submit(
        &[cb(101, "rolling"), funding.clone(), split.clone()],
        1_699_995_000,
    )?;
    if block_judgment(&reply) != json!({"status":"ok"}) {
        return Err(format!("rolling funding {reply}"));
    }
    n.mine(99, 1_699_999_000)?;
    let mut tx = RawTx::decode(&hex::decode(text(&row["tx"])?).map_err(|e| e.to_string())?)?;
    tx.inputs[0].txid = split.txid_internal();
    tx.inputs[0].vout = 2;
    let history = (0..2)
        .map(|index| RawTx {
            version: 2,
            inputs: vec![RawInput {
                txid: split.txid_internal(),
                vout: index,
                script: vec![],
                sequence: u32::MAX,
            }],
            outputs: vec![RawOutput {
                satoshis: 1000 - fee,
                script: vec![0x00, 0x6a],
            }],
            lock_time: 0,
        })
        .collect();
    // Funding frame is returned alongside all materialized outputs in the receipt.
    split.inputs.shrink_to_fit();
    Ok((split, history, tx))
}

fn rate(info: &Value) -> Result<u64> {
    Ok((info["mempoolminfee"].as_f64().ok_or("fee rate")? * 100_000_000.0).round() as u64)
}

// [SRC] src/validation.cpp:847-889; src/txmempool.cpp:1365-1383,
// 2624-2647,2704-2798. Zero resident memory is supported by the launch setter;
// a measured disk allowance makes a small real eviction history possible.
const ROLLING_RECIPE: &str = "Create real funded history transactions, calibrate their memory usage, and relaunch with zero resident allowance plus a disk cap one byte below their combined usage. Verify the eviction completion log and exact rolling fee. Mine the survivor when the boundary requires a block (judged only when the observed body is the whole pool, #72); translate the clock epoch and preserve elapsed seconds. getmempoolinfo invokes GetMinFee, completing decay. Admission rows preserve transaction bytes except the funded outpoint. Only the exposed fee and admission projection is judged; internal timestamp and gate fields are not RPC observables.";
fn rolling_boundary(root: &Path, row: &Value) -> Result<Value> {
    let name = text(&row["id"])?;
    let decay = row["boundary"] == "decay";
    let consolidation = name.starts_with("consolidation-");
    let fee = 434; // 434/62 * 1000 + increment = 8000.
    let mut extra =
        format!("{ROUND2_CONF}minminingtxfee=0.00000500\ncheckmempool=0\nmaxmempool=0\nmaxmempoolsizedisk=1000000B\n");
    if consolidation {
        extra.push_str(&format!(
            "minconsolidationfactor={}\nacceptnonstdconsolidationinput=1\n",
            if name == "consolidation-disabled" {
                0
            } else {
                1
            }
        ));
    }
    let mut c = start_boundary(root.join(format!("{name}-calibration")), &extra)?;
    let (split, history, _) = rolling_setup(&mut c, row, fee)?;
    for t in &history {
        c.call("sendrawtransaction", json!([hex::encode(t.encode())]))?;
        settle_disk(&mut c)?;
    }
    let ci = pool_info(&mut c)?;
    let usage = ci["usage"].as_u64().ok_or("usage")?;
    c.stop()?;
    let calibration = json!({"split":material(&split),"transactions":history.iter().map(material).collect::<Vec<_>>(),"info":ci,"conf":c.conf,"rpc":c.calls});
    let cap = usage - 1;
    extra = extra.replace(
        "maxmempoolsizedisk=1000000B",
        &format!("maxmempoolsizedisk={cap}B"),
    );
    // (S3, lane pend-66, [M] 2026-10-13) Three full runs saw an evicted entry's
    // disk bytes stay counted (usagedisk 124 against bytes 62, unchanged after
    // 30 s) on one of these rows each time: the declared history was not
    // reached. Such an attempt is retained and the setup repeats on a fresh
    // datadir; any other error still ends the run.
    let mut unsettled = vec![];
    let (mut n, split, history, tx, history_replies) = loop {
        let dir = if unsettled.is_empty() {
            root.join(name)
        } else {
            root.join(format!("{name}-retry-{}", unsettled.len()))
        };
        let mut n = start_boundary(dir, &extra)?;
        let (split, history, tx) = rolling_setup(&mut n, row, fee)?;
        let mut history_replies = vec![];
        let mut failure = None;
        for t in &history {
            history_replies
                .push(n.receipt("sendrawtransaction", json!([hex::encode(t.encode())]))?);
            if let Err(e) = settle_disk(&mut n) {
                failure = Some(e);
                break;
            }
        }
        match failure {
            None => break (n, split, history, tx, history_replies),
            Some(e) if e.contains("did not settle") && unsettled.len() < 4 => {
                n.stop()?;
                unsettled.push(json!({"error":e,"history_replies":history_replies,"conf":n.conf,"rpc":std::mem::take(&mut n.calls)}));
            }
            Some(e) => return Err(e),
        }
    };
    let bump = pool_info(&mut n)?;
    let target = 8000;
    if rate(&bump)? != target {
        return Err(format!(
            "rolling bump not reached for {name}: {bump}; history={history_replies:?}"
        ));
    }
    let log = fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
    let completion: Vec<_> = log
        .lines()
        .filter(|l| l.contains("rolling minimum fee bumped"))
        .map(str::to_owned)
        .collect();
    if completion.is_empty() {
        return Err("eviction log absent".into());
    }
    let epoch = if name == "rolling-block-resets-timestamp" {
        1_699_999_000u64 + 43200
    } else {
        1_700_000_000u64
    };
    let mut blocks = vec![];
    // A block at the epoch both removes the survivor and resets the decay clock.
    // The no-block row retains the survivor and advances only GetTime.
    if name != "rolling-decay-no-block-gate" {
        // [D] 2026-10-13 (#72): the boundary needs the block to carry the
        // whole pool; the body is observed, and another body is not judged.
        let pool = n.call("getrawmempool", json!([]))?;
        blocks = n.mine(1, epoch)?;
        let mut required: Vec<String> = serde_json::from_value(pool).map_err(|e| e.to_string())?;
        let mut body = n.body(&blocks[0])?;
        required.sort();
        body.sort();
        if let Some(r) = assembly_differs(
            row,
            &body,
            &required,
            ROLLING_RECIPE,
            n.calls.clone(),
            json!({"blocks":blocks,"conf":n.conf}),
        ) {
            n.stop()?;
            return Ok(r);
        }
        if n.call("getrawmempool", json!([]))? != json!([]) {
            return Err("history survivor not mined".into());
        }
    }
    let elapsed = match name {
        "rolling-decay-no-block-gate" => 43200,
        "rolling-decay-interval-equality" => 10,
        "rolling-decay-low-usage-half-life" => 10800,
        "rolling-block-resets-timestamp" => 0,
        _ if consolidation => 43200,
        _ => 32400,
    };
    n.call("setmocktime", json!([epoch + elapsed]))?;
    let before = pool_info(&mut n)?;
    let expected_rate = if consolidation {
        500
    } else if name == "rolling-decay-low-usage-half-life" {
        4000
    } else if !decay {
        1000
    } else {
        target
    };
    if rate(&before)? != expected_rate {
        return Err(format!("history rate not reached: {name}: {before}"));
    }
    let mut fixtures = json!({"calibration":calibration,"cap":cap,"split":material(&split),"history":history.iter().map(material).collect::<Vec<_>>(),"history_replies":history_replies,"unsettled_attempts":unsettled,"bump":bump,"completion":completion,"blocks":blocks,"before":before,"transaction":material(&tx),"conf":n.conf});
    let (observed, expected) = if decay {
        (
            json!({"rollingRate":rate(&before)?}),
            json!({"rollingRate":row["expected"]["rollingRate"]}),
        )
    } else {
        let reply = n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
        let accepted = n.call("getrawmempool", json!([]))?;
        let judgment = node_reject(&reply).unwrap_or(json!({"status":"accepted"}));
        fixtures["submission"] = reply;
        fixtures["after"] = pool_info(&mut n)?;
        let e = &row["expected"];
        let ej = if e["status"] == "rejected" {
            json!({"status":"rejected","namespace":"node","code":e["code"],"reason":e["reason"]})
        } else {
            json!({"status":e["status"]})
        };
        let ea = if e["status"] == "accepted" {
            json!([id(&tx)])
        } else {
            json!([])
        };
        (
            json!({"judgment":judgment,"accepted":accepted}),
            json!({"judgment":ej,"accepted":ea}),
        )
    };
    if name == "rolling-block-resets-timestamp" {
        n.call("setmocktime", json!([epoch + 10800]))?;
        let probe = pool_info(&mut n)?;
        if rate(&probe)? != 4000 {
            return Err("block reset follow-up half-life failed".into());
        }
        fixtures["block_gate_timestamp_probe"] = probe;
    }
    n.stop()?;
    let retries = unsettled.len();
    let mut result = measured(
        row,
        observed,
        expected,
        ROLLING_RECIPE,
        std::mem::take(&mut n.calls),
        fixtures,
    );
    if retries > 0 {
        result["qualifier"] = json!(stale_counter_qualifier(retries));
    }
    Ok(result)
}

// Observe asynchronous TxDB write completion before submitting the next frame.
fn settle_disk(n: &mut Node) -> Result<()> {
    let start = Instant::now();
    loop {
        let info = pool_info(n)?;
        if info["usagedisk"] == info["bytes"] {
            return Ok(());
        }
        if start.elapsed() > Duration::from_secs(5) {
            return Err(format!("disk accounting did not settle: {info}"));
        }
        thread::sleep(Duration::from_millis(20));
    }
}

fn eviction_setup(
    n: &mut Node,
    row: &Value,
) -> Result<(RawTx, Vec<RawTx>, BTreeMap<String, String>)> {
    let hashes = n.mine(100, 1_699_990_000)?;
    let body = n.call("getblock", json!([hashes[0], 1]))?;
    let coin = n.raw_tx(&body["tx"][0])?;
    let f = spend_to(&coin, 10000, 1, vec![0x51]);
    let entries = row["pool"]["accepted"].as_array().ok_or("entries")?;
    let originals = entries
        .iter()
        .map(|e| RawTx::decode(&hex::decode(text(&e["tx"])?).map_err(|e| e.to_string())?))
        .collect::<Result<Vec<_>>>()?;
    let mut split = RawTx {
        version: 2,
        inputs: vec![RawInput {
            txid: f.txid_internal(),
            vout: 0,
            script: vec![],
            sequence: u32::MAX,
        }],
        outputs: vec![],
        lock_time: 0,
    };
    let mut roots = BTreeMap::new();
    for (old, e) in originals.iter().zip(entries) {
        let input = &old.inputs[0];
        if !originals.iter().any(|t| t.txid_internal() == input.txid) {
            roots.insert(input.txid, split.outputs.len() as u32);
            split.outputs.push(RawOutput {
                satoshis: old.outputs.iter().map(|o| o.satoshis).sum::<u64>()
                    + e["fee"].as_u64().unwrap_or(100),
                script: vec![0x51],
            });
        }
    }
    let (_, reply) = n.submit(&[cb(101, "eviction"), f, split.clone()], 1_699_995_000)?;
    if block_judgment(&reply) != json!({"status":"ok"}) {
        return Err(format!("eviction funding {reply}"));
    }
    n.mine(99, 1_699_999_000)?;
    let mut mapped = BTreeMap::new();
    let mut ids = BTreeMap::new();
    let mut transactions = vec![];
    for old in originals {
        let mut tx = old.clone();
        for input in &mut tx.inputs {
            if let Some(index) = roots.get(&input.txid) {
                input.txid = split.txid_internal();
                input.vout = *index;
            } else {
                input.txid = *mapped.get(&input.txid).ok_or("parent mapping")?;
            }
        }
        mapped.insert(old.txid_internal(), tx.txid_internal());
        ids.insert(hex::encode(old.txid_internal()), id(&tx));
        transactions.push(tx);
    }
    Ok((split, transactions, ids))
}

fn eviction_boundary(root: &Path, row: &Value) -> Result<Value> {
    let name = text(&row["id"])?;
    // The declared entries are primary. The zero mining floor preserves that
    // classification for the one-satoshi parent; no secondary cap is consumed.
    let base = format!("{ROUND2_CONF}minminingtxfee=0\ncheckmempool=0\n");
    let mut c = start_boundary(root.join(format!("{name}-calibration")), &base)?;
    let (split, txs, _) = eviction_setup(&mut c, row)?;
    let batch: Vec<_> = txs
        .iter()
        .map(|t| json!({"hex":hex::encode(t.encode())}))
        .collect();
    let reply = c.receipt("sendrawtransactions", json!([batch]))?;
    let info = pool_info(&mut c)?;
    if info["size"] != txs.len() {
        return Err(format!("calibration batch did not settle {reply} {info}"));
    }
    let usage = info["usage"].as_u64().ok_or("usage")?;
    c.stop()?;
    let calibration = json!({"split":material(&split),"transactions":txs.iter().map(material).collect::<Vec<_>>(),"reply":reply,"info":info,"conf":c.conf,"rpc":c.calls});
    let cap = usage - u64::from(name != "trim-at-limit");
    let extra = format!("{base}maxmempool=0\nmaxmempoolsizedisk={cap}B\n");
    let mut n = start_boundary(root.join(name), &extra)?;
    let (split, txs, ids) = eviction_setup(&mut n, row)?;
    let batch: Vec<_> = txs
        .iter()
        .map(|t| json!({"hex":hex::encode(t.encode())}))
        .collect();
    let reply = n.receipt("sendrawtransactions", json!([batch]))?;
    let mut accepted = n.call("getrawmempool", json!([]))?;
    accepted
        .as_array_mut()
        .ok_or("accepted array")?
        .sort_by_key(|v| v.to_string());
    let info = pool_info(&mut n)?;
    let mut expected_ids = row["expected"]["accepted"]
        .as_array()
        .ok_or("expected ids")?
        .iter()
        .map(|v| {
            ids.get(text(v)?)
                .cloned()
                .ok_or("expected id mapping".into())
        })
        .collect::<Result<Vec<_>>>()?;
    expected_ids.sort();
    let log = fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
    let completion: Vec<_> = log
        .lines()
        .filter(|l| l.contains("rolling minimum fee bumped") || l.contains("accepted (poolsz"))
        .map(str::to_owned)
        .collect();
    n.stop()?;
    Ok(measured(row,json!({"accepted":accepted,"rollingRate":rate(&info)?}),json!({"accepted":expected_ids,"rollingRate":row["expected"]["rollingRate"]}),
        "Materialize each declared accepted entry with its exact stored fee and graph. Calibrate resident usage with no disk spill. A fresh node batches all entries; the synchronous batch commits without per-transaction limiting and performs the completed size sweep at its end. Select total disk allowance equal to calibrated usage, or one byte below. Primary classification and leaf order are preserved. Compare exact survivors and rolling fee; serialized byte-only usage is translated to the measured allocator coordinate.",
        std::mem::take(&mut n.calls),json!({"calibration":calibration,"cap":cap,"split":material(&split),"transactions":txs.iter().map(material).collect::<Vec<_>>(),"submission":reply,"info":info,"completion":completion,"conf":n.conf})))
}

// Batch envelopes can uniquely witness DUPLICATE at the detector. A CONFLICT
// envelope alone cannot distinguish the earlier pool check from final insertion.
fn detector_boundary(root: &Path, row: &Value) -> Result<Value> {
    let name = text(&row["id"])?;
    let mut probes = vec![];
    for attempt in 0..if name == "detector-final-insertion" {
        32
    } else {
        8
    } {
        let mut n = start_boundary(root.join(format!("{name}-{attempt}")), ROUND2_CONF)?;
        let (funding, tx) = round2_fund(&mut n, row)?;
        let mut competitor = tx.clone();
        competitor.outputs[0].satoshis -= 1;
        let frames = if attempt % 2 == 0 {
            vec![&competitor, &tx]
        } else {
            vec![&tx, &competitor]
        };
        let batch: Vec<_> = frames
            .iter()
            .map(|t| json!({"hex":hex::encode(t.encode())}))
            .collect();
        let reply = n.receipt("sendrawtransactions", json!([batch]))?;
        let accepted = n.call("getrawmempool", json!([]))?;
        let rejected = reply["result"]["invalid"]
            .as_array()
            .and_then(|a| a.iter().find(|r| r["txid"] == id(&tx)))
            .cloned();
        n.stop()?;
        let probe = json!({"attempt":attempt,"funding":material(&funding),"transaction":material(&tx),"competitor":material(&competitor),"submission":reply,"accepted":accepted,"conf":n.conf,"rpc":n.calls});
        probes.push(probe);
        if name == "detector-final-insertion"
            && rejected.as_ref().is_some_and(|r| {
                r["reject_code"] == 18 && r["reject_reason"] == "txn-double-spend-detected"
            })
        {
            let observed = json!({"judgment":{"status":"rejected","namespace":"node","code":18,"reason":"txn-double-spend-detected"},"accepted":accepted});
            let expected = json!({"judgment":{"status":"rejected","namespace":"node","code":row["expected"]["code"],"reason":row["expected"]["reason"]},"accepted":[id(&competitor)]});
            return Ok(measured(row,observed,expected,
                "Fund one outpoint and submit two distinct valid spends together through sendrawtransactions. Alternate batch order in bounded fresh-node trials. Only the target row's exact DUPLICATE envelope uniquely reaches the final detector; retain all attempts and the sole accepted competitor. CONFLICT alone is not a detector-stage witness.",vec![],json!({"probes":probes})));
        }
    }
    Ok(
        json!({"id":name,"label":"[X]","pending":"batch probes did not supply a uniquely attributable target detector-stage envelope; exact controlled insertion/commit scheduling remains required (src/validation.cpp:1147-1152,1484-1494; src/txn_double_spend_detector.cpp:26-55)","probes":probes}),
    )
}

// (S3, lane s6-66-mem3, Codex GPT-6, [M] 2026-10-13T07:58:14Z)
// [SRC] src/validation.cpp:847-889;
// src/txmempool.cpp:370-435,1365-1383,2118-2127,2704-2798 at PIN.
fn round3_stage(root: &Path, rows: &[Value], kind: &str) -> Result<Vec<Value>> {
    let mut results = vec![];
    for row in rows.iter().filter(|r| r["boundary"] == kind) {
        match row["id"].as_str().unwrap_or("") {
            "trim-group-demotes-parent" => {
                results.push(round3_eviction(root, row)?);
            }
            "trim-secondary-mining-cap" => results.push(secondary_cap_eviction(root, row)?),
            "trim-empty-retains-rolling-rate" => results.push(round3_empty(root, row)?),
            "detector-newly-committed" => results.push(detector_newly_committed(root, row)?),
            _ => (),
        }
    }
    Ok(results)
}

fn round3_eviction(root: &Path, row: &Value) -> Result<Value> {
    let name = text(&row["id"])?;
    let grouped = name == "trim-group-demotes-parent";
    // Preserve the declared 500-satoshi mining floor and stored fees. Disable
    // consolidation so a zero-fee OP_TRUE parent cannot receive a fee delta.
    // [SRC] src/init.cpp:2563-2607,3115-3121 at PIN.
    let base = format!(
        "{ROUND2_CONF}minminingtxfee=0.00000500\nminconsolidationfactor=0\ncheckmempool=0\n"
    );
    let mut c = start_boundary(root.join(format!("{name}-calibration")), &base)?;
    let (split, txs, _) = eviction_setup(&mut c, row)?;
    let batch: Vec<_> = txs
        .iter()
        .map(|t| json!({"hex":hex::encode(t.encode())}))
        .collect();
    let reply = c.receipt("sendrawtransactions", json!([batch]))?;
    let info = pool_info(&mut c)?;
    let entries = c.call("getrawmempool", json!([true]))?;
    if info["size"] != 2 || info["journalsize"] != if grouped { 2 } else { 0 } {
        return Err(format!("round3 classification not reached: {reply} {info}"));
    }
    for (tx, entry) in txs.iter().zip(
        row["pool"]["accepted"]
            .as_array()
            .or_err("row['pool']['accepted'].as_array()")?,
    ) {
        let actual = &entries[id(tx)];
        let fee = entry["fee"].as_u64().or_err("entry['fee'].as_u64()")?;
        if (actual["fee"].as_f64().ok_or("fee")? * 100_000_000.0).round() as u64 != fee
            || actual["fee"] != actual["modifiedfee"]
        {
            return Err("stored fee or consolidation delta differs".into());
        }
    }
    let usage = info["usage"].as_u64().ok_or("usage")?;
    let secondary = info["usagecpfp"].as_u64().ok_or("secondary usage")?;
    c.stop()?;
    let calibration = json!({"split":material(&split),"transactions":txs.iter().map(material).collect::<Vec<_>>(),"submission":reply,"info":info,"entries":entries,"conf":c.conf,"rpc":c.calls});
    let cap = usage - 1;
    let extra = format!("{base}maxmempool=0\nmaxmempoolsizedisk={cap}B\n");
    let mut n = start_boundary(root.join(name), &extra)?;
    let (split, txs, ids) = eviction_setup(&mut n, row)?;
    let batch: Vec<_> = txs
        .iter()
        .map(|t| json!({"hex":hex::encode(t.encode())}))
        .collect();
    let reply = n.receipt("sendrawtransactions", json!([batch]))?;
    let accepted = n.call("getrawmempool", json!([]))?;
    let info = pool_info(&mut n)?;
    let log = fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
    let completion: Vec<_> = log
        .lines()
        .filter(|l| l.contains("rolling minimum fee bumped") || l.contains("Limit mempool size:"))
        .map(str::to_owned)
        .collect();
    n.stop()?;
    let fixtures = json!({"calibration":calibration,"cap":cap,"secondary_usage_before":secondary,"split":material(&split),"transactions":txs.iter().map(material).collect::<Vec<_>>(),"submission":reply,"info":info,"completion":completion,"conf":n.conf});
    if !grouped {
        return Ok(
            json!({"id":name,"label":"[X]","pending":"The zero-resident launch couples the total trim to a zero secondary allowance. This measured probe does not establish the declared one-secondary-survivor trim. A positive resident allowance with calibrated pressure, or an independently controlled trim target, is still required.","fixtures":fixtures,"rpc":n.calls}),
        );
    }
    if completion.is_empty() {
        return Err("missing completed group eviction log".into());
    }
    let expected_ids: Vec<_> = row["expected"]["accepted"]
        .as_array()
        .ok_or("expected ids")?
        .iter()
        .map(|v| ids.get(text(v)?).cloned().ok_or("id mapping".into()))
        .collect::<Result<_>>()?;
    Ok(measured(row,json!({"accepted":accepted,"primary_count":info["journalsize"],"rollingRate":rate(&info)?}),
        json!({"accepted":expected_ids,"primary_count":0,"rollingRate":row["expected"]["rollingRate"]}),
        "Materialize the exact parent/child frames and stored fees. Calibrate both primary journal entries at the declared mining floor, with zero parent fee and no fee delta; its promotion therefore requires the child group. Relaunch with total allowance one byte below measured group usage and zero resident allowance. The synchronous batch commits the group before its completed size sweep. Initially secondary usage is zero, so that sweep selects the total cap. Require eviction completion, exact parent survivor, empty primary journal and the exposed rolling fee. Allocator usage replaces byte-only usage while preserving the removal boundary; later sweeps are outside this observation.",std::mem::take(&mut n.calls),fixtures))
}

// [SRC] src/rpc/mining.cpp:312-344 at PIN. The raw RPC transcript keeps
// every fee-delta allocation; no setter of the rolling rate is invented.
fn prioritise(n: &mut Node, txid: &str, delta: i64) -> Result<()> {
    let params = json!([txid, 0, delta]);
    let result = n
        .rpc
        .as_mut()
        .ok_or("RPC not ready")?
        .call("prioritisetransaction", params.clone())?;
    n.calls.push(json!({"method":"prioritisetransaction","params":params,"reply":{"result":result},"source":format!("[SRC] src/rpc/mining.cpp:312-344 at {PIN}")}));
    if result != true {
        return Err("prioritisation refused".into());
    }
    Ok(())
}

const EMPTY_RECIPE: &str = "Build an eviction history at 5000 satoshis/kB, mine its survivor without advancing the decay clock (judged only when the observed body is the whole pool, #72), temporarily prioritise the row for admission and restore its exact stored/modified fee. Add only zero fee deltas for absent transaction ids until retained allocator overhead exceeds the fixed cap. Complete a two-rejection batch to trigger a separate trim; require the singleton's removal log, empty membership, unchanged rolling fee and retained usage above the cap. This rematerializes the empty-stop branch: byte-only zero usage is observed as zero transaction bytes, not zero allocator RAM. Retained fee-delta allocations are explicit calibration ballast, not accepted entries.";
fn round3_empty(root: &Path, row: &Value) -> Result<Value> {
    let name = text(&row["id"])?;
    let base = format!("{ROUND2_CONF}minminingtxfee=0.00000500\nminconsolidationfactor=0\ncheckmempool=0\nmaxmempool=0\nmaxmempoolsizedisk=1000000B\n");
    let mut c = start_boundary(root.join(format!("{name}-calibration")), &base)?;
    let (split, history, _) = rolling_setup(&mut c, row, 248)?;
    for tx in &history {
        c.call("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
        settle_disk(&mut c)?;
    }
    let info = pool_info(&mut c)?;
    let cap = info["usage"].as_u64().ok_or("usage")? - 1;
    c.stop()?;
    let calibration = json!({"split":material(&split),"history":history.iter().map(material).collect::<Vec<_>>(),"info":info,"conf":c.conf,"rpc":c.calls});
    let extra = base.replace(
        "maxmempoolsizedisk=1000000B",
        &format!("maxmempoolsizedisk={cap}B"),
    );
    // (S3, lane pend-66, [M] 2026-10-13) As rolling_boundary: an attempt whose
    // evicted entry's disk bytes stay counted did not reach the declared
    // history; it is retained and the setup repeats on a fresh datadir.
    let mut unsettled = vec![];
    let (mut n, split, history, tx) = loop {
        let dir = if unsettled.is_empty() {
            root.join(name)
        } else {
            root.join(format!("{name}-retry-{}", unsettled.len()))
        };
        let mut n = start_boundary(dir, &extra)?;
        let (split, history, tx) = rolling_setup(&mut n, row, 248)?;
        let mut failure = None;
        for h in &history {
            n.call("sendrawtransaction", json!([hex::encode(h.encode())]))?;
            if let Err(e) = settle_disk(&mut n) {
                failure = Some(e);
                break;
            }
        }
        match failure {
            None => break (n, split, history, tx),
            Some(e) if e.contains("did not settle") && unsettled.len() < 4 => {
                n.stop()?;
                unsettled.push(json!({"error":e,"conf":n.conf,"rpc":std::mem::take(&mut n.calls)}));
            }
            Some(e) => return Err(e),
        }
    };
    let bump = pool_info(&mut n)?;
    if rate(&bump)? != 5000 {
        return Err(format!("empty-trim history rate: {bump}"));
    }
    // [D] 2026-10-13 (#72): the block must carry the whole history pool; its
    // body is observed, and another body is recorded, never judged.
    let pool = n.call("getrawmempool", json!([]))?;
    let blocks = n.mine(1, 1_699_999_000)?;
    let mut required: Vec<String> = serde_json::from_value(pool).map_err(|e| e.to_string())?;
    let mut body = n.body(&blocks[0])?;
    required.sort();
    body.sort();
    if let Some(r) = assembly_differs(
        row,
        &body,
        &required,
        EMPTY_RECIPE,
        n.calls.clone(),
        json!({"blocks":blocks,"conf":n.conf}),
    ) {
        n.stop()?;
        return Ok(r);
    }
    if n.call("getrawmempool", json!([]))? != json!([]) {
        return Err("history not mined".into());
    }
    prioritise(&mut n, &id(&tx), 1000)?;
    n.call("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
    prioritise(&mut n, &id(&tx), -1000)?;
    let before = pool_info(&mut n)?;
    let entries = n.call("getrawmempool", json!([true]))?;
    if before["size"] != 1
        || rate(&before)? != 5000
        || entries[id(&tx)]["fee"] != entries[id(&tx)]["modifiedfee"]
    {
        return Err(format!(
            "empty-trim initial singleton/rate/fee: {before} {entries}"
        ));
    }
    // Retained mapDeltas are allocator ballast outside transaction membership.
    // Force the empty-stop branch even if every accepted entry is removed.
    // [SRC] src/txmempool.cpp:2097-2127,2739-2791 at PIN.
    let mut padding = vec![];
    for i in 0..40 {
        let txid = hex::encode(bsv_rs::primitives::hash::sha256(
            format!("s6-66-mem3-empty-ballast-{i}").as_bytes(),
        ));
        prioritise(&mut n, &txid, 0)?;
        padding.push(txid);
    }
    let pressure = pool_info(&mut n)?;
    if pressure["usage"].as_u64().ok_or("pressure usage")? <= cap {
        return Err("emptying pressure absent".into());
    }
    let offset = fs::read_to_string(n.dir.join("console.log"))
        .map_err(|e| e.to_string())?
        .len();
    let mut invalid = tx.clone();
    invalid.inputs.clear();
    let mut other = invalid.clone();
    other.lock_time += 1;
    let trigger = n.receipt(
        "sendrawtransactions",
        json!([[{"hex":hex::encode(invalid.encode())},{"hex":hex::encode(other.encode())}]]),
    )?;
    let rejected = trigger["result"]["invalid"]
        .as_array()
        .ok_or("trim trigger rejections")?;
    if rejected.len() != 2
        || rejected
            .iter()
            .any(|r| r["reject_code"] != 16 || r["reject_reason"] != "bad-txns-vin-empty")
    {
        return Err("trim trigger admitted or other rejection".into());
    }
    let accepted = n.call("getrawmempool", json!([]))?;
    let after = pool_info(&mut n)?;
    let log = fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
    let completion: Vec<_> = log[offset..]
        .lines()
        .filter(|l| l.contains("rolling minimum fee bumped") || l.contains("Limit mempool size:"))
        .map(str::to_owned)
        .collect();
    if completion.is_empty() || after["usage"].as_u64().ok_or("retained usage")? <= cap {
        return Err("empty-stop branch not witnessed".into());
    }
    n.stop()?;
    let retries = unsettled.len();
    let mut result = measured(
        row,
        json!({"accepted":accepted,"rollingRate":rate(&after)?,"transaction_bytes":after["bytes"]}),
        json!({"accepted":[],"rollingRate":row["expected"]["rollingRate"],"transaction_bytes":row["expected"]["usage"]}),
        EMPTY_RECIPE,
        std::mem::take(&mut n.calls),
        json!({"calibration":calibration,"cap":cap,"split":material(&split),"history":history.iter().map(material).collect::<Vec<_>>(),"unsettled_attempts":unsettled,"bump":bump,"blocks":blocks,"transaction":material(&tx),"before":before,"entries":entries,"padding_ids":padding,"pressure":pressure,"trigger":trigger,"after":after,"completion":completion,"conf":n.conf}),
    );
    // The row named by the 15:3xZ lens carries the open item whatever this
    // run's retry count; the rolling rows carry it when they retried.
    result["qualifier"] = json!(stale_counter_qualifier(retries));
    Ok(result)
}

// (S3, lane fix-pend2, Claude Opus 5.5, [M] 2026-10-13) An attempt whose
// evicted entry's disk bytes stay counted is a setup that did not reach its
// precondition; it is retained in the receipt and the setup repeats on a fresh
// datadir, the precondition checked again before anything is judged.
// Open item O-2: attribution in the record of 2026-10-14,
// docs/records/20261014-012252-s6-attr-o2-regtest-s3.md.
// Source locations: src/mempooltxdb.cpp:169,186,193-199,476-485;
// src/tx_mempool_info.cpp:102-111,116-120; src/txmempool.cpp:852-877.
fn stale_counter_qualifier(retries: usize) -> String {
    format!("open item O-2, record of 2026-10-14: the setup checks the disk counter before the judged attempt; setup retries before the judged attempt in this run: {retries}")
}

// O-2 probe: two arms on fresh datadirs under round3_empty's conf compare
// back-to-back spends with a restart between spends, followed by a load
// observation. Restart source locations: src/init.cpp:237-240;
// src/txmempool.cpp:3296-3302; src/mempooltxdb.cpp:303-322,343-347,381-391.
// Load source locations: src/txmempool.cpp:1620-1658,3253-3256,3264-3268.
// Mock time is carried across restarts (src/init.cpp:3199;
// src/txmempool.cpp:3172,3209).
pub(super) fn o2_witness(root: &Path) -> Result<Value> {
    let rows = row_read("mempool")?;
    let row = rows
        .iter()
        .find(|r| r["id"] == "trim-empty-retains-rolling-rate")
        .ok_or("O-2 row absent")?;
    let base = format!("{ROUND2_CONF}minminingtxfee=0.00000500\nminconsolidationfactor=0\ncheckmempool=0\nmaxmempool=0\nmaxmempoolsizedisk=1000000B\n");
    let mut c = start_boundary(root.join("o2-calibration"), &base)?;
    let (_, history, _) = rolling_setup(&mut c, row, 248)?;
    for tx in &history {
        c.call("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
        settle_disk(&mut c)?;
    }
    let calibration = pool_info(&mut c)?;
    let cap = calibration["usage"].as_u64().ok_or("usage")? - 1;
    c.stop()?;
    let extra = base.replace(
        "maxmempoolsizedisk=1000000B",
        &format!("maxmempoolsizedisk={cap}B"),
    );
    let lines = |n: &Node, offset: usize, keys: &[&str]| -> Result<(usize, Vec<String>)> {
        let log = fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
        let found = log[offset.min(log.len())..]
            .lines()
            .filter(|l| keys.iter().any(|k| l.contains(k)))
            .map(str::to_owned)
            .collect();
        Ok((log.len(), found))
    };
    let mut trials = vec![];
    for arm in ["back-to-back", "restart-between-spends"] {
        for i in 0..4 {
            let mut n = start_boundary(root.join(format!("o2-{arm}-{i}")), &extra)?;
            let (_, history, _) = rolling_setup(&mut n, row, 248)?;
            let ids: Vec<_> = history.iter().map(id).collect();
            n.call(
                "sendrawtransaction",
                json!([hex::encode(history[0].encode())]),
            )?;
            let mut first_reload = Value::Null;
            if arm == "restart-between-spends" {
                settle_disk(&mut n)?;
                n.restart_edited("mocktime=1699999000", |_| {
                    Ok(json!({"edit":"none","reason":"restart between spends"}))
                })?;
                first_reload = pool_info(&mut n)?;
            }
            n.call(
                "sendrawtransaction",
                json!([hex::encode(history[1].encode())]),
            )?;
            thread::sleep(Duration::from_secs(2));
            let settled = pool_info(&mut n)?;
            let pool = n.call("getrawmempool", json!([]))?;
            let (offset, evicted) = lines(&n, 0, &["Limit mempool size: txn="])?;
            if arm == "back-to-back" {
                n.restart_edited("mocktime=1699999000", |_| {
                    Ok(json!({"edit":"none","reason":"the load check"}))
                })?;
            } else {
                n.restart()?;
            }
            let reloaded = pool_info(&mut n)?;
            let reloaded_pool = n.call("getrawmempool", json!([]))?;
            let (_, check) = lines(
                &n,
                offset,
                &[
                    "Checking mempool TxDB",
                    "Failed to deserialize mempool",
                    "Imported mempool transactions",
                    "Mempool file and transaction database",
                ],
            )?;
            n.stop()?;
            trials.push(json!({"arm":arm,"trial":i,"history":ids,"first_reload":first_reload,"settled":settled,"pool":pool,"evicted_log":evicted,"reloaded":reloaded,"reloaded_pool":reloaded_pool,"load_check_log":check,"stale":settled["usagedisk"] != settled["bytes"],"conf":n.conf,"rpc":std::mem::take(&mut n.calls)}));
        }
    }
    let count = |arm: &str| {
        trials
            .iter()
            .filter(|t| t["arm"] == arm && t["stale"] == true)
            .count()
    };
    Ok(
        json!({"label":"[M]","cap":cap,"calibration":calibration,"stale":{"back-to-back":count("back-to-back"),"restart-between-spends":count("restart-between-spends")},"trials":trials}),
    )
}

// (S3, lane pend-66, Claude Opus 5.5, [M] 2026-10-13) A synchronous batch
// validates its transactions in parallel tasks, each committing on its own
// completion (src/txn_validator.cpp:217-302; src/validation.cpp:1539-1611,
// 1759-1830). The target meets the earlier pool check (src/validation.cpp:
// 1147-1153) at its start and the final detector (1481-1494;
// src/txn_double_spend_detector.cpp:11-58) only after its scripts; a cheap
// competitor on the same outpoint commits in between. Both sites return 258
// txn-mempool-conflict, so neither the code nor the batch time attributes the
// stage. (S3, lane fix-pend2, Claude Opus 5.5, [M] 2026-10-13) The stage is
// read from the pin's own record of it: SetScriptsChecked (1481-1482) is set
// only on the path that reaches the detector; a rejection carrying collided
// transactions is published (1733-1757,1799-1803; src/net/net.cpp:2653-2658)
// to the double-spend handler, which under -dsnotifylevel above 0 queues it
// with that flag and logs it under -debug=doublespend as "Processing
// double-spend txn <txid> (checked <flag>)" (src/double_spend/
// dsattempt_handler.cpp:89-146,357-362). With no notification-enabled output
// nothing further is sent (383-394). checked 1: the detector; checked 0: the
// earlier check.
fn costly_lock(heavy: usize, light: usize) -> Vec<u8> {
    let branch = |hashes: usize| {
        let mut b = vec![0x40];
        b.extend([0x5a; 64]);
        for _ in 0..18 {
            b.extend([0x76, 0x7e]);
        }
        for _ in 0..hashes {
            b.extend([0x76, 0xa8, 0x75]);
        }
        b.push(0x75);
        b
    };
    [
        vec![0x63],
        branch(heavy),
        vec![0x67],
        branch(light),
        vec![0x68, 0x51],
    ]
    .concat()
}

fn detector_newly_committed(root: &Path, row: &Value) -> Result<Value> {
    let name = text(&row["id"])?;
    let conf = format!("{ROUND2_CONF}minminingtxfee=0.00000500\ncheckmempool=0\nlogtimemicros=1\ndebug=mempool\ndebug=txnval\ndsnotifylevel=1\ndebug=doublespend\n");
    let mut attempts = vec![];
    for attempt in 0..4 {
        let mut n = start_boundary(root.join(format!("{name}-race-{attempt}")), &conf)?;
        let hashes = n.mine(100, 1_699_990_000)?;
        let body = n.call("getblock", json!([hashes[0], 1]))?;
        let coin = n.raw_tx(&body["tx"][0])?;
        let lock = costly_lock(60, 4);
        let mut funding = spend_to(&coin, 3000, 1, lock.clone());
        for _ in 0..2 {
            funding.outputs.push(RawOutput {
                satoshis: 1000,
                script: lock.clone(),
            });
        }
        funding.outputs[0].satoshis = 1000;
        let funding = resign_first(funding, &coin)?;
        let (_, reply) = n.submit(&[cb(101, name), funding.clone()], 1_699_995_000)?;
        if block_judgment(&reply) != json!({"status":"ok"}) {
            return Err(format!("detector funding: {reply}"));
        }
        n.mine(99, 1_699_999_000)?;
        let spend_of = |vout: u32, unlock: u8, value: u64| -> Result<RawTx> {
            let mut tx =
                RawTx::decode(&hex::decode(text(&row["tx"])?).map_err(|e| e.to_string())?)?;
            tx.inputs[0].txid = funding.txid_internal();
            tx.inputs[0].vout = vout;
            tx.inputs[0].script = vec![unlock];
            tx.outputs[0].satoshis = value;
            Ok(tx)
        };
        let target = spend_of(0, 0x51, 900)?;
        let competitor = spend_of(0, 0x00, 899)?;
        let timed = |n: &mut Node, method: &str, params: Value| -> Result<(Value, f64)> {
            let start = Instant::now();
            let reply = n.receipt(method, params)?;
            Ok((reply, start.elapsed().as_secs_f64()))
        };
        let (heavy_reply, heavy) = timed(
            &mut n,
            "sendrawtransaction",
            json!([hex::encode(spend_of(1, 0x51, 900)?.encode())]),
        )?;
        let (light_reply, light) = timed(
            &mut n,
            "sendrawtransaction",
            json!([hex::encode(spend_of(2, 0x00, 900)?.encode())]),
        )?;
        if heavy_reply.get("error").is_some()
            || light_reply.get("error").is_some()
            || heavy < 5.0 * light
        {
            return Err(format!(
                "detector calibration: {heavy_reply} {light_reply} heavy {heavy} light {light}"
            ));
        }
        let offset = fs::read_to_string(n.dir.join("console.log"))
            .map_err(|e| e.to_string())?
            .len();
        let batch = json!([[{"hex":hex::encode(target.encode())},{"hex":hex::encode(competitor.encode())}]]);
        let (reply, race) = timed(&mut n, "sendrawtransactions", batch)?;
        let pool = n.call("getrawmempool", json!([]))?;
        // The handler runs on its own task; wait up to 10 s for its line.
        let marker = format!("Processing double-spend txn {} (checked ", id(&target));
        let started = Instant::now();
        let mut log = String::new();
        while started.elapsed() < Duration::from_secs(10) {
            log = fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
            if log[offset..].contains(&marker) {
                break;
            }
            thread::sleep(Duration::from_millis(100));
        }
        let lines: Vec<_> = log[offset..]
            .lines()
            .filter(|l| l.contains(&id(&target)) || l.contains(&id(&competitor)))
            .map(str::to_owned)
            .collect();
        let checked = log[offset..].lines().find_map(|l| {
            l.split_once(&marker)
                .and_then(|(_, rest)| rest.chars().next())
        });
        n.stop()?;
        let rejected = reply["result"]["invalid"]
            .as_array()
            .and_then(|a| a.iter().find(|r| r["txid"] == id(&target)))
            .cloned();
        let judgment = match &rejected {
            Some(r) => {
                json!({"status":"rejected","namespace":"node","code":r["reject_code"],"reason":r["reject_reason"]})
            }
            None => json!({"status":"accepted"}),
        };
        let stage = match checked {
            Some('1') => "detector",
            Some('0') => "earlier-check",
            _ => "unattributed",
        };
        let committed: Vec<Value> = if pool
            .as_array()
            .ok_or("pool")?
            .contains(&json!(id(&competitor)))
        {
            vec![json!({"hash":id(&funding),"index":0})]
        } else {
            vec![]
        };
        let probe = json!({"attempt":attempt,"funding":material(&funding),"target":material(&target),"competitor":material(&competitor),
            "calibration":{"heavy_seconds":heavy,"light_seconds":light,"heavy_reply":heavy_reply,"light_reply":light_reply},
            "race_seconds":race,"submission":reply,"pool":pool,"log":lines,"stage_witness":{"marker":marker,"checked":checked.map(String::from),"stage":stage},"conf":n.conf,"rpc":std::mem::take(&mut n.calls)});
        attempts.push(probe);
        // Only an attempt whose target reached the detector produced the
        // declared condition; the others are retained, not judged.
        if stage != "detector" {
            continue;
        }
        let observed = json!({"judgment":judgment,"stage":stage,"committed":committed});
        let expected = json!({"judgment":{"status":row["expected"]["status"],"namespace":"node","code":row["expected"]["code"],"reason":row["expected"]["reason"]},
            "stage":row["expected"]["stage"],"committed":[{"hash":id(&funding),"index":0}]});
        let mut result = measured(row, observed, expected,
            "With -dsnotifylevel=1 and -debug=doublespend, fund three outputs under one locking script whose OP_IF branch costs about 60 hashes of a 16 MiB element (target) or 4 (competitor). Calibrate both costs with single submissions on two of the outputs. Submit target then competitor on the third in one sendrawtransactions batch. The stage is read from the pin's own flag: the double-spend handler logs the rejected target with checked 1 only when its rejection came after SetScriptsChecked, at the detector. An attempt is judged only when that line reads checked 1 (the target passed the earlier check and its scripts); attempts reading checked 0 (the conflict met at the earlier check) or no line are retained, not judged. Judged: the target's code and reason, and the competitor committed in the pool.",
            vec![], json!({"attempts":attempts}));
        result["declared_expected"] = row["expected"].clone();
        result["observation_basis"] = json!("Stage from the pin's scriptsChecked flag as logged by the double-spend handler for the rejected target (src/validation.cpp:1481-1482; src/double_spend/dsattempt_handler.cpp:138,361-362); batch and calibration times are retained as data, not as the stage witness. Trace stages before the detector remain spec-only.");
        return Ok(result);
    }
    Err(format!(
        "detector-newly-committed: no attempt produced the declared condition: {}",
        serde_json::to_string(&attempts)
            .unwrap_or_default()
            .chars()
            .take(2000)
            .collect::<String>()
    ))
}

// spend_to signs one output; re-sign after the outputs change.
fn resign_first(mut tx: RawTx, parent: &RawTx) -> Result<RawTx> {
    use bsv_rs::primitives::bsv::sighash::{
        compute_sighash_for_signing, SighashParams, TxInput, TxOutput,
    };
    let inputs = vec![TxInput {
        txid: parent.txid_internal(),
        output_index: 0,
        script: vec![],
        sequence: u32::MAX,
    }];
    let outputs: Vec<TxOutput> = tx
        .outputs
        .iter()
        .map(|o| TxOutput {
            satoshis: o.satoshis,
            script: o.script.clone(),
        })
        .collect();
    let digest = compute_sighash_for_signing(&SighashParams {
        version: tx.version,
        inputs: &inputs,
        outputs: &outputs,
        locktime: tx.lock_time,
        input_index: 0,
        subscript: &parent.outputs[0].script,
        satoshis: parent.outputs[0].satoshis,
        scope: 0x41,
    });
    let signature = key().sign(&digest).map_err(|e| format!("{e:?}"))?;
    let integer = |x: &[u8; 32]| -> Vec<u8> {
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
    let mut der = vec![0x30, payload.len() as u8];
    der.extend(payload);
    der.push(0x41);
    tx.inputs[0].script.clear();
    bsv_script_harness::gen::push_min(&mut tx.inputs[0].script, &der);
    bsv_script_harness::gen::push_min(
        &mut tx.inputs[0].script,
        &key().public_key().to_compressed(),
    );
    Ok(tx)
}

// [SRC] src/validation.cpp:834-879 (secondary limit = mempoolmaxpercentcpfp
// percent of -maxmempool; the excess lowers the trim target);
// src/txmempool.cpp:2650-2668 (secondary entries ahead of primary, then by fee rate),
// 2704-2798, 1365-1384 (a secondary survivor caps the rolling rate at the
// mining floor); src/config.cpp:2440-2460,2481-2499; src/init.cpp:2385-2403;
// src/policy/policy.h:87,91,95 at 6504a3af. The smallest positive secondary
// allowance is one percent of the 300 MB floor, so calibrated ballast of
// about 3 MB at a fee rate between the row's entries and the floor carries
// the declared two-entry pressure; maxmempool is chosen in bytes so the
// allowance sits one byte below the calibrated secondary usage.
fn secondary_cap_eviction(root: &Path, row: &Value) -> Result<Value> {
    let name = text(&row["id"])?;
    let base = format!("{ROUND2_CONF}minminingtxfee=0.00000500\nminconsolidationfactor=0\ncheckmempool=0\nmempoolmaxpercentcpfp=1\n");
    let mut c = start_boundary(
        root.join(format!("{name}-calibration")),
        &format!("{base}maxmempool=1000\n"),
    )?;
    let (setup, txs, _) = secondary_setup(&mut c, row)?;
    let batch: Vec<_> = txs
        .iter()
        .map(|t| json!({"hex":hex::encode(t.encode())}))
        .collect();
    let reply = c.receipt("sendrawtransactions", json!([batch]))?;
    let info = pool_info(&mut c)?;
    c.stop()?;
    if info["size"] != 3 || info["journalsize"] != 0 || reply["result"].get("invalid").is_some() {
        return Err(format!("secondary calibration: {reply} {info}"));
    }
    let usage = info["usagecpfp"].as_u64().ok_or("secondary usage")?;
    if usage <= 3_000_001 {
        return Err(format!(
            "secondary calibration below the one-percent floor: {usage}"
        ));
    }
    let maxmempool = 100 * (usage - 1) + 50;
    let calibration = json!({"setup":setup,"transactions":txs.iter().map(material).collect::<Vec<_>>(),"submission":reply,"info":info,"conf":c.conf,"rpc":std::mem::take(&mut c.calls)});
    let mut n = start_boundary(
        root.join(name),
        &format!("{base}maxmempool={maxmempool}B\n"),
    )?;
    let (setup, txs, ids) = secondary_setup(&mut n, row)?;
    let batch: Vec<_> = txs
        .iter()
        .map(|t| json!({"hex":hex::encode(t.encode())}))
        .collect();
    let offset = fs::read_to_string(n.dir.join("console.log"))
        .map_err(|e| e.to_string())?
        .len();
    let reply = n.receipt("sendrawtransactions", json!([batch]))?;
    let pool = n.call("getrawmempool", json!([]))?;
    let after = pool_info(&mut n)?;
    let log = fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
    let completion: Vec<_> = log[offset..]
        .lines()
        .filter(|l| l.contains("rolling minimum fee bumped") || l.contains("Limit mempool size:"))
        .map(str::to_owned)
        .collect();
    n.stop()?;
    if completion.is_empty() || !pool.as_array().ok_or("pool")?.contains(&json!(id(&txs[0]))) {
        return Err(format!(
            "secondary trim not witnessed or ballast evicted: {pool} {completion:?}"
        ));
    }
    let row_ids: Vec<String> = txs[1..].iter().map(id).collect();
    let mut accepted: Vec<Value> = pool
        .as_array()
        .or_err("pool.as_array()")?
        .iter()
        .filter(|h| row_ids.iter().any(|r| json!(r) == **h))
        .cloned()
        .collect();
    accepted.sort_by_key(|v| v.to_string());
    let mut expected_ids = row["expected"]["accepted"]
        .as_array()
        .ok_or("expected ids")?
        .iter()
        .map(|v| {
            ids.get(text(v)?)
                .cloned()
                .map(Value::String)
                .ok_or_else(|| "expected id mapping".to_owned())
        })
        .collect::<Result<Vec<_>>>()?;
    expected_ids.sort_by_key(|v| v.to_string());
    Ok(measured(row, json!({"accepted":accepted,"rollingRate":rate(&after)?}),
        json!({"accepted":expected_ids,"rollingRate":row["expected"]["rollingRate"]}),
        "Materialize the row's two secondary entries (stored fees 0 and 1, primary false) and one ballast transaction of eight 400 kB null-data outputs at about 100 sat/kB, below the 500 sat/kB mining floor and above both entries. Calibrate their secondary usage in one batch on a fresh node with a large allowance. Relaunch with mempoolmaxpercentcpfp=1 and maxmempool in bytes so the secondary allowance is one byte below calibrated usage; the batch's completed size sweep removes the most worthless secondary entry. Compare the row entries that survive and the exposed rolling fee; the ballast survives and is excluded from the row projection. Allocator usage replaces byte-only usage while preserving the removal boundary.",
        std::mem::take(&mut n.calls), json!({"calibration":calibration,"maxmempool_bytes":maxmempool,"secondary_usage":usage,"setup":setup,"transactions":txs.iter().map(material).collect::<Vec<_>>(),"submission":reply,"pool":pool,"info":after,"completion":completion,"conf":n.conf})))
}

// The row's entries rematerialized on a split output, plus one ballast
// transaction; returns [ballast, entries...] and the id map.
fn secondary_setup(
    n: &mut Node,
    row: &Value,
) -> Result<(Value, Vec<RawTx>, BTreeMap<String, String>)> {
    let hashes = n.mine(100, 1_699_990_000)?;
    let body = n.call("getblock", json!([hashes[0], 1]))?;
    let coin = n.raw_tx(&body["tx"][0])?;
    let f = spend_to(&coin, 2_000_000, 1, vec![0x51]);
    let entries = row["pool"]["accepted"].as_array().ok_or("entries")?;
    let originals = entries
        .iter()
        .map(|e| RawTx::decode(&hex::decode(text(&e["tx"])?).map_err(|e| e.to_string())?))
        .collect::<Result<Vec<_>>>()?;
    let mut split = RawTx {
        version: 2,
        inputs: vec![RawInput {
            txid: f.txid_internal(),
            vout: 0,
            script: vec![],
            sequence: u32::MAX,
        }],
        outputs: vec![],
        lock_time: 0,
    };
    for (old, e) in originals.iter().zip(entries) {
        split.outputs.push(RawOutput {
            satoshis: old.outputs.iter().map(|o| o.satoshis).sum::<u64>()
                + e["fee"].as_u64().ok_or("entry fee")?,
            script: vec![0x51],
        });
    }
    split.outputs.push(RawOutput {
        satoshis: 1_000_000,
        script: vec![0x51],
    });
    let (_, reply) = n.submit(&[cb(101, "secondary-cap"), f, split.clone()], 1_699_995_000)?;
    if block_judgment(&reply) != json!({"status":"ok"}) {
        return Err(format!("secondary funding {reply}"));
    }
    n.mine(99, 1_699_999_000)?;
    let mut ids = BTreeMap::new();
    let mut txs = vec![];
    let mut ballast = RawTx {
        version: 2,
        inputs: vec![RawInput {
            txid: split.txid_internal(),
            vout: originals.len() as u32,
            script: vec![],
            sequence: u32::MAX,
        }],
        outputs: vec![],
        lock_time: 0,
    };
    for _ in 0..8 {
        let mut script = vec![0x00, 0x6a, 0x4e];
        script.extend(400_000u32.to_le_bytes());
        script.extend(vec![0x42; 400_000]);
        ballast.outputs.push(RawOutput {
            satoshis: 0,
            script,
        });
    }
    ballast.outputs.push(RawOutput {
        satoshis: 0,
        script: vec![0x51],
    });
    let size = ballast.encode().len() as u64;
    let fee = size * 100 / 1000;
    ballast
        .outputs
        .last_mut()
        .or_err("ballast.outputs.last_mut()")?
        .satoshis = 1_000_000 - fee;
    txs.push(ballast);
    for (index, old) in originals.into_iter().enumerate() {
        let mut tx = old.clone();
        tx.inputs[0].txid = split.txid_internal();
        tx.inputs[0].vout = index as u32;
        ids.insert(hex::encode(old.txid_internal()), id(&tx));
        txs.push(tx);
    }
    Ok((
        json!({"split":material(&split),"ballast_fee":fee,"ballast_size":size}),
        txs,
        ids,
    ))
}

#[cfg(test)]
mod pend66 {
    use super::*;

    // Development probe: one row on fresh owned instances, printed, nothing
    // written to the repository. Ordinary cargo test never launches a node.
    #[test]
    #[ignore = "explicit owned probe; requires S6_PEND_ID"]
    fn probe_mempool_row() {
        std::env::set_current_dir(Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap()).unwrap();
        signals();
        let wanted = std::env::var("S6_PEND_ID").unwrap();
        let stamp = String::from_utf8(
            Command::new("date")
                .args(["-u", "+%Y%m%d-%H%M%S"])
                .output()
                .unwrap()
                .stdout,
        )
        .unwrap();
        let root = PathBuf::from(std::env::var("HOME").unwrap())
            .join("bsv/targets/spec-oracle-scenarios")
            .join(format!("s6-fix-pend2-probe-{}", stamp.trim()));
        fs::create_dir_all(&root).unwrap();
        let rows = row_read("mempool").unwrap();
        let row = rows
            .iter()
            .find(|r| r["id"] == wanted.as_str())
            .expect("row id");
        let started = Instant::now();
        let result = if wanted == "detector-newly-committed" {
            detector_newly_committed(&root, row)
        } else {
            secondary_cap_eviction(&root, row)
        };
        match result {
            Ok(r) => println!(
                "PROBE {} wall {:.1}s verdict {} observed {} expected {}\nFIXTURES {}",
                wanted,
                started.elapsed().as_secs_f64(),
                r["verdict"],
                r["observed"],
                r["expected"],
                serde_json::to_string(&r["fixtures"])
                    .unwrap()
                    .chars()
                    .take(20000)
                    .collect::<String>()
            ),
            Err(e) => panic!(
                "PROBE {wanted} ERROR {} (root {})",
                e.chars().take(3000).collect::<String>(),
                root.display()
            ),
        }
    }
}

// [D] 2026-10-13, lane reclass-66b (the owner's H6, road (c)): limited
// admission over the loopback peer. A P2P transaction enters the asynchronous
// validator at high priority with fUseLimits ([SRC] src/net/net_processing.cpp:
// 3379-3393; src/txn_validator.cpp:415-435). A timeout state on a high request
// moves it to the low queue; on a low request it is invalid
// (txn_validator.cpp:459-471,633-641). The nonstandard-input disjunct of the
// input-standardness guard sets that same state without a clock
// (src/validation.cpp:1225-1233). Those cells observe time-budget expiry under
// the default CPU validation clock ([SRC] src/txn_validation_config.h:36-37;
// src/init.cpp:2890-2895; src/validation.cpp:990-1006) and are recorded and
// marked non-judging, never judged (#71).
const LIMITED_ROWS: [&str; 11] = [
    "coins-cache-equality",
    "coins-cache-below",
    "coins-cache-zero-unlimited",
    "inputs-budget-downgrade",
    "inputs-low-skips-standardness",
    "held-finalising-update-queues",
    "held-unchanged-nonfinal-sequence-queues",
    "script-budget-high-relay",
    "script-budget-high-block",
    "script-budget-low-invalid",
    "outer-mandatory-budget-low-invalid",
];
const LIMITED_NOW: u64 = 1_700_000_000;
pub(super) fn limited(row: &Value) -> bool {
    row["id"]
        .as_str()
        .is_some_and(|name| LIMITED_ROWS.contains(&name))
}
// One funding transaction per output list, each spending a mature coinbase.
fn limited_fund(n: &mut Node, outputs: &[Vec<RawOutput>]) -> Result<Vec<RawTx>> {
    let hashes = n.mine(103, LIMITED_NOW - 10000)?;
    let mut funds = vec![];
    for (hash, outs) in hashes.iter().zip(outputs) {
        let body = n.call("getblock", json!([hash, 1]))?;
        let coin = n.raw_tx(&body["tx"][0])?;
        let mut f = spend_to(&coin, outs[0].satoshis, 1, outs[0].script.clone());
        if outs.len() > 1 {
            f.outputs = outs.clone();
            f = resign_first(f, &coin)?;
        }
        funds.push(f);
    }
    let block = [vec![cb(104, "reclass-66b")], funds.clone()].concat();
    let (_, receipt) = n.submit(&block, (LIMITED_NOW - 1000) as u32)?;
    if block_judgment(&receipt) != json!({"status":"ok"}) {
        return Err(format!("limited funding refused: {receipt}"));
    }
    n.call("setmocktime", json!([LIMITED_NOW]))?;
    Ok(funds)
}
// SIGHASH_ALL|FORKID on every input; each input spends script() for `value`.
fn sign_all(mut tx: RawTx, value: u64) -> Result<RawTx> {
    use bsv_rs::primitives::bsv::sighash::{
        compute_sighash_for_signing, SighashParams, TxInput, TxOutput,
    };
    let inputs: Vec<TxInput> = tx
        .inputs
        .iter()
        .map(|i| TxInput {
            txid: i.txid,
            output_index: i.vout,
            script: vec![],
            sequence: i.sequence,
        })
        .collect();
    let outputs: Vec<TxOutput> = tx
        .outputs
        .iter()
        .map(|o| TxOutput {
            satoshis: o.satoshis,
            script: o.script.clone(),
        })
        .collect();
    let lock = script();
    let integer = |x: &[u8; 32]| -> Vec<u8> {
        let mut b: Vec<u8> = x.iter().copied().skip_while(|v| *v == 0).collect();
        if b.is_empty() {
            b.push(0);
        }
        if b[0] & 128 != 0 {
            b.insert(0, 0);
        }
        [vec![2, b.len() as u8], b].concat()
    };
    for index in 0..tx.inputs.len() {
        let digest = compute_sighash_for_signing(&SighashParams {
            version: tx.version,
            inputs: &inputs,
            outputs: &outputs,
            locktime: tx.lock_time,
            input_index: index,
            subscript: &lock,
            satoshis: value,
            scope: 0x41,
        });
        let signature = key().sign(&digest).map_err(|e| format!("{e:?}"))?;
        let payload = [integer(signature.r()), integer(signature.s())].concat();
        let mut der = vec![0x30, payload.len() as u8];
        der.extend(payload);
        der.push(0x41);
        tx.inputs[index].script.clear();
        bsv_script_harness::gen::push_min(&mut tx.inputs[index].script, &der);
        bsv_script_harness::gen::push_min(
            &mut tx.inputs[index].script,
            &key().public_key().to_compressed(),
        );
    }
    Ok(tx)
}
// A nonstandard lock whose cost is hashing a 16 MiB element `hashes` times;
// it needs no unlocking data, so the row's empty unlocking script is kept.
fn hashing_lock(hashes: usize) -> Vec<u8> {
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
// Wait for log markers in order, each after the previous one.
fn limited_markers(n: &Node, markers: &[String], seconds: u64) -> Result<bool> {
    let start = Instant::now();
    while start.elapsed() < Duration::from_secs(seconds) {
        let log = fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
        let mut at = 0;
        let found = markers.iter().all(|m| match log[at..].find(m.as_str()) {
            Some(i) => {
                at += i + m.len();
                true
            }
            None => false,
        });
        if found {
            return Ok(true);
        }
        thread::sleep(Duration::from_millis(50));
    }
    Ok(false)
}
// Read between validator cycles: the queue count brackets the pool reads.
fn limited_window(n: &mut Node) -> Result<Value> {
    let before = n.call("getblockchainactivity", json!([]))?;
    let accepted = n.call("getrawmempool", json!([]))?;
    let held = n.call("getrawnonfinalmempool", json!([]))?;
    let after = n.call("getblockchainactivity", json!([]))?;
    Ok(
        json!({"queued_before":before["transactions"],"accepted":accepted,"held":held,"queued_after":after["transactions"]}),
    )
}
pub(super) fn limited_row(root: &Path, row: &Value) -> Result<Value> {
    let name = text(&row["id"])?;
    let outer = name == "outer-mandatory-budget-low-invalid";
    let high_script = name.starts_with("script-budget-high-");
    let low_script = name == "script-budget-low-invalid";
    let held_row = name.starts_with("held-");
    let window_row = high_script || held_row || name == "inputs-budget-downgrade";
    let low = row["request"]["lowPriority"].as_bool().unwrap_or(false);
    let mut conf = format!(
        "listen=1\nbind=127.0.0.1:{{P2P_PORT}}\ngenesisactivationheight={}\nchronicleactivationheight=1000000\nacceptnonstdtxn={}\nacceptnonstdoutputs=1\nbanscore=100000\ndebug=mempool\ndebug=txnval\ndebug=netmsg\nlogtimemicros=1\n",
        if outer { 10000 } else { 1 },
        u8::from(!row["cfg"]["requireStandard"].as_bool().unwrap_or(true))
    );
    // [SRC] src/init.cpp:2850-2917; src/config.cpp:688-755,872-882 and
    // src/txn_validator.cpp:24-29 at the pin: each value is at or above its floor.
    if let Some(cap) = row["cfg"]["maxCoinsViewCacheSize"].as_u64() {
        conf.push_str(&format!("maxcoinsviewcachesize={cap}B\n"));
    }
    if window_row {
        conf.push_str("txnvalidationasynchrunfreq=5000\n");
    }
    if high_script {
        conf.push_str("maxstdtxvalidationduration=1\nmaxtxchainvalidationbudget=0\n");
    }
    if low_script {
        conf.push_str("maxnonstdtxvalidationduration=10\nmaxtxchainvalidationbudget=0\n");
    }
    let mut n = start_retry(root, name, &conf)?;
    let decode = |v: &Value| -> Result<RawTx> {
        RawTx::decode(&hex::decode(text(v)?).map_err(|e| e.to_string())?)
    };
    let original = decode(&row["tx"])?;
    let mut setup = vec![];
    let tx = if high_script {
        // The row's P2SH(OP_TRUE) coin validates in microseconds; the fixture
        // substitutes 200 standard P2PKH inputs and keeps the row's output.
        let outs = vec![
            RawOutput {
                satoshis: 10_000,
                script: script()
            };
            200
        ];
        let f = limited_fund(&mut n, &[outs])?.remove(0);
        setup.push(material(&f));
        let tx = RawTx {
            version: original.version,
            inputs: (0..200)
                .map(|vout| RawInput {
                    txid: f.txid_internal(),
                    vout,
                    script: vec![],
                    sequence: u32::MAX,
                })
                .collect(),
            outputs: original.outputs.clone(),
            lock_time: original.lock_time,
        };
        sign_all(tx, 10_000)?
    } else {
        let us = row["utxo"].as_array().ok_or("limited UTXO array")?;
        let outs: Vec<Vec<RawOutput>> = us
            .iter()
            .map(|u| -> Result<Vec<RawOutput>> {
                let lock = if low_script {
                    hashing_lock(8)
                } else {
                    hex::decode(u["script"].as_str().unwrap_or("51")).map_err(|e| e.to_string())?
                };
                Ok(vec![RawOutput {
                    satoshis: u["value"].as_u64().unwrap_or(1000),
                    script: lock,
                }])
            })
            .collect::<Result<_>>()?;
        let funds = limited_fund(&mut n, &outs)?;
        if outer {
            n.mine(1500 - 104, LIMITED_NOW - 500)?;
            n.call("setmocktime", json!([LIMITED_NOW]))?;
        }
        let mut points = BTreeMap::new();
        for (u, f) in us.iter().zip(&funds) {
            let hash: [u8; 32] = hex::decode(text(&u["hash"])?)
                .map_err(|e| e.to_string())?
                .try_into()
                .map_err(|_| "UTXO hash length")?;
            points.insert(
                (hash, u["index"].as_u64().unwrap_or(0) as u32),
                f.txid_internal(),
            );
            setup.push(material(f));
        }
        let remap = |mut t: RawTx| -> Result<RawTx> {
            for input in &mut t.inputs {
                input.txid = *points
                    .get(&(input.txid, input.vout))
                    .ok_or("unmaterialized limited input")?;
                input.vout = 0;
            }
            Ok(t)
        };
        for entry in row["pool"]["nonFinal"].as_array().into_iter().flatten() {
            let held = remap(decode(&entry["tx"])?)?;
            let reply = n.receipt("sendrawtransaction", json!([hex::encode(held.encode())]))?;
            let listed = n.call("getrawnonfinalmempool", json!([]))?;
            if reply.get("error").is_some() || listed != json!([id(&held)]) {
                return Err(format!("limited held setup: {reply} {listed}"));
            }
            setup.push(json!({"held":material(&held),"reply":reply}));
        }
        remap(original.clone())?
    };
    let txid = id(&tx);
    let mut p = super::peer::Peer::start(&mut n)?;
    let initial = super::peer::pools(&mut n)?;
    let cursor = p.next;
    let delivered = Instant::now();
    p.tx(&tx)?;
    let markers: Vec<String> = if held_row {
        vec![
            format!("Finalising non-final tx: {txid}"),
            "re-submitted txns that need to be reprocessed is 1".into(),
        ]
    } else {
        vec![
            format!("txn= {txid} rejected too-long-validation-time"),
            "forwarding them to the Non-standard queue".into(),
        ]
    };
    let (seen, window) = if window_row {
        let seen = limited_markers(&n, &markers, 25)?;
        // The forwarding line precedes its enqueue; the next cycle is 5 s away.
        thread::sleep(Duration::from_millis(100));
        (seen, limited_window(&mut n)?)
    } else {
        (false, Value::Null)
    };
    let window_seconds = delivered.elapsed().as_secs_f64();
    let after = super::peer::pools(&mut n)?;
    let reject = p.expect(
        "reject",
        &txid,
        cursor,
        if row["expected"]["status"] == "rejected" {
            5.0
        } else {
            0.5
        },
    )?;
    let log = fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
    let lines: Vec<String> = log
        .lines()
        .filter(|l| {
            l.contains(&txid)
                || l.contains("Txnval-asynch: Validation timeout")
                || l.contains("re-submitted txns")
        })
        .map(str::to_owned)
        .collect();
    let forwarded = log.contains(&format!("txn= {txid} rejected too-long-validation-time"))
        && log.contains("forwarding them to the Non-standard queue");
    let judgment = match reject["observations"]
        .as_array()
        .and_then(|o| o.iter().find(|e| e["command"] == "reject"))
    {
        Some(e) => {
            json!({"status":"rejected","namespace":"node","code":e["code"],"reason":e["reason"]})
        }
        None if after["accepted"]
            .as_array()
            .is_some_and(|a| a.contains(&json!(txid))) =>
        {
            json!({"status":"accepted"})
        }
        None if after["held"]
            .as_array()
            .is_some_and(|a| a.contains(&json!(txid))) =>
        {
            json!({"status":"heldNonFinal"})
        }
        None => json!({"status":"absent"}),
    };
    // Each row's declared ids name its own frame (internal byte order);
    // check the projection's shape before mapping it to the live id.
    let e = &row["expected"];
    let own = json!([hex::encode(original.txid_internal())]);
    let none = json!([]);
    let in_window = |field: &str| {
        window[field]
            .as_array()
            .is_some_and(|a| a.contains(&json!(txid)))
    };
    let queued = window_row
        && seen
        && window["queued_before"] == 1
        && window["queued_after"] == 1
        && !in_window("accepted")
        && !in_window("held");
    let (observed, expected) = if window_row {
        if e["status"] != "deferred" || e["pending"] != own || e["accepted"] != none {
            return Err(format!("{name}: declared projection shape differs"));
        }
        let mut o = json!({"status":if queued {"deferred"} else {"completed"},"accepted":window["accepted"],"pending":if queued {json!([txid])} else {json!([])}});
        let mut x = json!({"status":"deferred","accepted":[],"pending":[txid]});
        if held_row {
            o["held"] = window["held"].clone();
            x["held"] = json!([]);
        } else {
            o["pendingLow"] = json!(queued && forwarded);
            x["pendingLow"] = e["pendingLow"].clone();
        }
        (o, x)
    } else if low_script || outer {
        if e["pending"] != none || e["accepted"] != none {
            return Err(format!("{name}: declared projection shape differs"));
        }
        // pools() returns only after the validator's queue count reads zero.
        (
            json!({"judgment":judgment,"accepted":after["accepted"],"pending":[]}),
            json!({"judgment":{"status":"rejected","namespace":"node","code":e["code"],"reason":e["reason"]},"accepted":[],"pending":[]}),
        )
    } else {
        let x = if e["status"] == "rejected" {
            json!({"status":"rejected","namespace":"node","code":e["code"],"reason":e["reason"]})
        } else {
            json!({"status":e["status"]})
        };
        (
            json!({"judgment":judgment,"accepted":after["accepted"],"held":after["held"],"orphans":after["orphans"],"validatedAt":if forwarded {"low"} else {"high"}}),
            json!({"judgment":x,"accepted":if e["status"] == "accepted" {json!([txid])} else {json!([])},"held":[],"orphans":0,"validatedAt":if low {"low"} else {"high"}}),
        )
    };
    let recipe = format!("[D] 2026-10-13: fund the row's coins at 104 (outpoints remapped; mocktime {LIMITED_NOW}); {}deliver the frame once from the pinned loopback peer, so it enters the asynchronous validator at high priority with fUseLimits; {}then wait for validator completion and read the pools and any reject message. Launch: {}.",
        if held_row { "submit the row's held frame by RPC and verify it held; " } else { "" },
        if window_row { "with a 5 s validator period, wait for the pin's log markers in order and read the queue count, accepted and held pools before the next cycle; " } else { "" },
        conf.lines().filter(|l| !l.starts_with("bind=") && !l.starts_with("debug=") && *l != "listen=1" && *l != "banscore=100000" && *l != "logtimemicros=1").collect::<Vec<_>>().join(", "));
    let fixtures = json!({"setup":setup,"transaction":material(&tx),"original_transaction":row["tx"],"conf":n.conf,"initial":initial,"markers":markers,"markers_seen":seen,"window":window,"window_seconds_after_delivery":window_seconds,"after":after,"reject":reject,"forwarded_to_low":forwarded,"log":lines});
    p.close()?;
    n.stop()?;
    let peer = p.receipt(&n);
    let mut r = measured(
        row,
        observed,
        expected,
        &recipe,
        std::mem::take(&mut n.calls),
        fixtures,
    );
    r["date"] = json!("2026-10-13");
    r["peer"] = peer;
    r["declared_expected"] = row["expected"].clone();
    let expired = if low_script {
        r["observed"]["judgment"]["reason"] == "too-long-validation-time"
    } else {
        queued
    };
    let run_note = if expired {
        "expiry observed in this run"
    } else {
        "no expiry in this run"
    };
    match name {
        "coins-cache-equality" => r["qualifier"] = json!("P2P: high priority with limits, maxcoinsviewcachesize=1B (src/validation.cpp:1171-1177)"),
        "coins-cache-below" | "coins-cache-zero-unlimited" | "inputs-low-skips-standardness" => r["qualifier"] = json!("P2P: the pin moved the high request to low priority at the nonstandard-input guard (src/validation.cpp:1225-1233; src/txn_validator.cpp:633-641); the row's low request then validated with limits"),
        "inputs-budget-downgrade" => r["qualifier"] = json!("P2P: deferred by the nonstandard-input disjunct of the guard the row's inputs budget names (src/validation.cpp:1225-1233), without a clock; the budget cell was not the cause (#71); queue read between validator cycles"),
        "held-finalising-update-queues" | "held-unchanged-nonfinal-sequence-queues" => r["qualifier"] = json!("P2P: after one low-priority move at the nonstandard-input guard, the finalising commit queued revalidation (src/time_locked_mempool.cpp:61-81; src/txn_validator.cpp:472-479); the row's RPC request revalidates inline (src/txn_validator.cpp:178-188); queue read between validator cycles"),
        _ => {}
    }
    if high_script || low_script {
        r["projection_verdict"] = r["verdict"].clone();
        r["verdict"] = json!("non-judging");
        r["qualifier"] = json!(if low_script {
            format!("non-judging (#71): the low-priority outcome is a time-budget expiry under the default CPU validation clock ([SRC] src/txn_validation_config.h:36-37; src/init.cpp:2890-2895; src/validation.cpp:990-1006) against maxnonstdtxvalidationduration=10 ms, its floor (src/config.cpp:733-750; src/validation.cpp:1349-1356; src/txn_validator.cpp:633-641); fixture: a hashing lock replaces the row's OP_TRUE coin; {run_note}")
        } else {
            format!("non-judging (#71): the scripts-stage outcome is a time-budget expiry under the default CPU validation clock ([SRC] src/txn_validation_config.h:36-37; src/init.cpp:2890-2895; src/validation.cpp:990-1006) against maxstdtxvalidationduration=1 ms, its floor (src/config.cpp:688-705); which check expired, relay or block word, is not observable: both set one reason with empty detail (src/validation.cpp:1349-1356,1424-1431); fixture: 200 P2PKH inputs replace the row's P2SH(OP_TRUE) coin; {run_note}")
        });
    }
    if outer {
        r.as_object_mut()
            .or_err("r.as_object_mut()")?
            .remove("verdict");
        r["unrealizable"] = json!(format!("the P2P surface was tried: a P2P request carries no skip flags (src/net/net_processing.cpp:3384-3393), and the relay word answered {} at the relay check; the one per-request skipscriptflags selector is sendrawtransactions' configuration (src/rpc/rawtransaction.cpp:1282-1292,1467), whose batch validation passes fUseLimits=false (src/txn_validator.cpp:261-266); -promiscuousmempoolflags replaces the node-wide relay word (src/verify_script_flags.cpp:11-28), not the row's request mask. The masked limited request has no surface at 6504a3af", r["observed"]["judgment"]));
    }
    Ok(r)
}
