//! Family-owned realization recipes. Sources and observation boundaries are retained in receipts.
use super::core::*;

fn chain_snapshot(n: &mut Node, f: &RawTx, t: &RawTx) -> Result<Value> {
    let tip = n.tip()?;
    let pool = n.call("getrawmempool", json!([]))?;
    let held = n.call("getrawnonfinalmempool", json!([]))?;
    let mut coins = vec![];
    for (name, tx) in [("F", f), ("T", t)] {
        if !n.call("gettxout", json!([id(tx), 0, false]))?.is_null() {
            coins.push(name);
        }
    }
    let names = |list: &Value| -> Result<Vec<String>> {
        list.as_array()
            .ok_or("invalid pool")?
            .iter()
            .map(|h| {
                if h == &json!(id(t)) {
                    Ok("T".into())
                } else {
                    Err(format!("unexpected pool entry: {h}"))
                }
            })
            .collect()
    };
    n.call("getchaintips", json!([]))?;
    Ok(json!({"height":tip["height"],"coins":coins,"pool":names(&pool)?,"held":names(&held)?}))
}
pub(super) fn run(root: &Path) -> Result<Vec<Value>> {
    let rows = row_read("chain")?;
    let mut result = vec![];
    // [D] 2026-10-13: replay the two header recipes on fresh owned instances.
    let one_peer_only = std::env::args().any(|a| a == "--one-peer-only");
    for row in rows.iter().filter(|row| {
        !one_peer_only || matches!(row["case"].as_str(), Some("precious" | "receipt-order"))
    }) {
        if let Some(reason) = chain_unrealizable(row) {
            result.push(json!({"id":row["id"],"label":"[X]","unrealizable":reason,"expected_label":"[D]","expected":row["expected"],"rpc":[]}));
            continue;
        }
        if let Some(reason) = peer_reason(row) {
            // [D] 2026-10-13: execute the pinned framework instrument.
            let _ = reason;
            result.push(super::peer::row(root, "chain", row)?);
            continue;
        }
        if row["case"] == "reversed-inputs" {
            result.push(reversed_inputs_recipe(root, row)?);
            continue;
        }
        if row["case"] == "queued-script" {
            result.push(queued_script_recipe(root, row)?);
            continue;
        }
        if row["case"] == "reward-before-script" {
            result.push(reward_before_script_recipe(root, row)?);
            continue;
        }
        if row["case"] == "retained-nonfinal-before-genesis" {
            result.push(retained_nonfinal_recipe(root, row)?);
            continue;
        }
        if row["case"] == "retained-nonfinal-after-genesis" {
            result.push(retained_nonfinal_recipe(root, row)?);
            continue;
        }
        if row["case"] == "batching" {
            result.push(batching_recipe(root, row)?);
            continue;
        }
        if row["case"] == "undo" {
            result.push(undo_recipe(root, row)?);
            continue;
        }
        if row["case"] == "overwrite" {
            result.push(undo_recipe(root, row)?);
            continue;
        }
        if row["case"] == "precious" {
            result.push(precious_recipe(root, row)?);
            continue;
        }
        match row["case"].as_str() {
            Some("sequence") => {
                result.push(equal_work_sequence_recipe(root, row)?);
                continue;
            }
            Some("completion") => {
                result.push(equal_work_completion_recipe(root, row)?);
                continue;
            }
            Some("receipt-order") => {
                result.push(receipt_order_recipe(root, row)?);
                continue;
            }
            Some("missing-body" | "body-return") => {
                result.push(missing_body_recipe(root, row)?);
                continue;
            }
            Some("missing-output") => {
                result.push(missing_output_recipe(root, row)?);
                continue;
            }
            Some("undo-count") => {
                result.push(undo_count_recipe(root, row)?);
                continue;
            }
            Some("output-metadata") => {
                result.push(output_metadata_recipe(root, row)?);
                continue;
            }
            Some(
                "partial-disconnect-auto"
                | "partial-disconnect-invalidate"
                | "partial-disconnect-freeze",
            ) => {
                result.push(partial_disconnect_recipe(root, row)?);
                continue;
            }
            _ => (),
        }
        if row["case"] == "invalid-retry" {
            result.push(invalid_retry_recipe(root, row)?);
            continue;
        }
        if row["case"] == "mined-secondary" {
            result.push(mined_secondary_recipe(root, row)?);
            continue;
        }
        if row["case"] == "soft-rejection" {
            result.push(soft_rejection_recipe(root, row)?);
            continue;
        }
        if row["case"] == "sequential-inputs" {
            result.push(sequential_inputs_recipe(root, row)?);
            continue;
        }
        if row["case"] == "reorg" {
            result.push(reorg_recipe(root, row)?);
            continue;
        }
        if row["case"] == "reward" {
            result.push(reward_recipe(root, row)?);
            continue;
        }
        if row["case"] == "missing-input" {
            result.push(missing_input_recipe(root, row)?);
            continue;
        }
        if row["case"] == "immature" {
            result.push(rollback_recipe(root, row)?);
            continue;
        }
        if row["case"] == "nonfinal" {
            result.push(rollback_recipe(root, row)?);
            continue;
        }
        if !matches!(text(&row["case"])?, "readmit" | "invalidate-reconsider") {
            continue;
        }
        let mut n = start_owned(root, text(&row["id"])?, "")?;
        let (f, t, base) = seed(&mut n)?;
        let mut snapshots = vec![];
        n.call("sendrawtransaction", json!([hex::encode(t.encode())]))?;
        let hash = n.mine(1, 1_700_000_001)?[0].clone();
        // [D] 2026-10-13 (#72): the row's projection is for the body [T];
        // the node's body is observed and the row judged only on that body.
        let body = n.body(&hash)?;
        if let Some(r) = assembly_differs(
            row,
            &body,
            &[id(&t)],
            READMIT_RECIPE,
            n.calls.clone(),
            json!({"F":material(&f),"T":material(&t),"base":base,"block":hash,"conf":n.conf}),
        ) {
            n.stop()?;
            result.push(r);
            continue;
        }
        snapshots.push(chain_snapshot(&mut n, &f, &t)?);
        n.call("invalidateblock", json!([hash]))?;
        snapshots.push(chain_snapshot(&mut n, &f, &t)?);
        let observed = if row["case"] == "readmit" {
            snapshots[1].clone()
        } else {
            n.call("reconsiderblock", json!([hash]))?;
            snapshots.push(chain_snapshot(&mut n, &f, &t)?);
            json!(snapshots)
        };
        n.stop()?;
        result.push(measured(
            row,
            observed,
            row["expected"].clone(),
            READMIT_RECIPE,
            std::mem::take(&mut n.calls),
            json!({"F":material(&f),"T":material(&t),"base":base,"block":hash,"conf":n.conf}),
        ));
    }
    Ok(result)
}

// [SRC] The socket probes in core are exclusive while held. A competing lane
// can win after their release; retry only a refused bind with a fresh datadir.
const READMIT_RECIPE: &str = "Mine a signed P2PKH funding prefix to 101, admit T, observe its assembled block at 102 (judged only when the observed body is [T], #72), invalidate and optionally reconsider; read chain-only F/T outputs and exact pools.";
fn start_owned(root: &Path, name: &str, extra: &str) -> Result<Node> {
    for attempt in 0..20 {
        let dir = root.join(format!("{name}-{attempt}"));
        match Node::start(dir.clone(), 1_000_001, extra) {
            Ok(node) => return Ok(node),
            Err(error)
                if error.contains("Unable to bind")
                    || error.contains("Address already in use")
                    || error.contains("no free RPC/P2P pair")
                    || (error.contains("Unable to start HTTP server")
                        && fs::read_to_string(dir.join("console.log"))
                            .unwrap_or_default()
                            .contains("Unable to bind any endpoint for RPC server")) =>
            {
                thread::sleep(Duration::from_millis(100 + attempt * 37));
            }
            Err(error) => return Err(error),
        }
    }
    Err("chain port allocation retries exhausted".into())
}

fn peer_reason(row: &Value) -> Option<&'static str> {
    match row["case"].as_str()? {
        "unrequested-equal-work" => Some("The boundary requires an unrequested body. submitblock forces ProcessNewBlock's requested argument to true, bypassing this gate; an isolated loopback P2P peer is needed. [SRC] src/rpc/mining.cpp:916-952; src/validation.cpp:6296-6335 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        "era-clear" => Some("The row requires a retained orphan across its named era boundary. RPC synchronous validation supplies no persistent orphan handler; an isolated loopback P2P peer is needed. [SRC] src/txn_validator.cpp:150-174,244-248; src/validation.cpp:4036-4053; src/txmempool.cpp:1345-1363 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        _ => None,
    }
}

#[cfg(test)]
mod lane {
    use super::*;

    // An explicitly invoked family entry point avoids the predecessor driver's
    // all-family writes. Ordinary cargo test never launches a node.
    #[test]
    #[ignore = "explicit owned chain replay; requires S6_CHAIN_RECORD and S6_CHAIN_KIND"]
    fn replay_chain_lane() {
        replay().unwrap();
    }

    fn replay() -> Result<()> {
        std::env::set_current_dir(Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap())
            .map_err(|e| e.to_string())?;
        signals();
        let record = std::env::var("S6_CHAIN_RECORD").map_err(|e| e.to_string())?;
        if !record.starts_with("docs/records/") || !record.ends_with("-s6-66-chn3-regtest-s3.md") {
            return Err("record must belong to s6-66-chn3".into());
        }
        let kind = std::env::var("S6_CHAIN_KIND").map_err(|e| e.to_string())?;
        let clock = Command::new("date")
            .args(["-u", "+%Y%m%d-%H%M%S"])
            .output()
            .map_err(|e| e.to_string())?;
        let stamp = String::from_utf8_lossy(&clock.stdout).trim().to_owned();
        let run_id = format!("s6-66-chn3-{stamp}-{kind}");
        let binary =
            PathBuf::from(std::env::var("HOME").map_err(|e| e.to_string())?).join(format!(
                "bsv/targets/sv-{}/bin/bitcoind",
                bsv_script_harness::SV_NODE_TAG
            ));
        let output = Command::new(binary)
            .arg("-version")
            .output()
            .map_err(|e| e.to_string())?;
        let version = String::from_utf8_lossy(&output.stdout)
            .lines()
            .next()
            .unwrap_or("")
            .to_owned();
        if version != format!("Bitcoin SV version {VERSION}") {
            return Err("version mismatch".into());
        }
        let root = PathBuf::from(std::env::var("HOME").unwrap())
            .join("bsv/targets/spec-oracle-scenarios")
            .join(&run_id);
        fs::create_dir(&root).map_err(|e| e.to_string())?;
        let started = Instant::now();
        let rows = row_read("chain")?;
        let mut results = vec![];
        for row in rows.iter().filter(|r| r["case"] == kind) {
            if let Some(reason) = peer_reason(row) {
                results.push(json!({"id":row["id"],"case":row["case"],"label":"[X]","needs_peer":reason,"expected_label":"[D]","expected":row["expected"],"rpc":[]}));
            } else if let Some(reason) = chain_unrealizable(row) {
                results.push(json!({"id":row["id"],"label":"[X]","unrealizable":reason,"expected_label":"[D]","expected":row["expected"],"rpc":[]}));
            } else if kind == "reversed-inputs" {
                results.push(reversed_inputs_recipe(&root, row)?);
            } else if kind == "queued-script" {
                results.push(queued_script_recipe(&root, row)?);
            } else if kind == "reward-before-script" {
                results.push(reward_before_script_recipe(&root, row)?);
            } else if kind == "retained-nonfinal-before-genesis"
                || kind == "retained-nonfinal-after-genesis"
            {
                results.push(retained_nonfinal_recipe(&root, row)?);
            } else if kind == "batching" {
                results.push(batching_recipe(&root, row)?);
            } else if kind == "undo" || kind == "overwrite" {
                results.push(undo_recipe(&root, row)?);
            } else if kind == "precious" {
                results.push(precious_recipe(&root, row)?);
            } else if kind == "invalid-retry" {
                results.push(invalid_retry_recipe(&root, row)?);
            } else if kind == "mined-secondary" {
                results.push(mined_secondary_recipe(&root, row)?);
            } else if kind == "soft-rejection" {
                results.push(soft_rejection_recipe(&root, row)?);
            } else if kind == "sequential-inputs" {
                results.push(sequential_inputs_recipe(&root, row)?);
            } else if kind == "reorg" {
                results.push(reorg_recipe(&root, row)?);
            } else if kind == "reward" {
                results.push(reward_recipe(&root, row)?);
            } else if kind == "missing-input" {
                results.push(missing_input_recipe(&root, row)?);
            } else if kind == "immature" || kind == "nonfinal" {
                results.push(rollback_recipe(&root, row)?);
            } else {
                return Err(format!("unsupported chain kind {kind}"));
            }
        }
        if results.is_empty() {
            return Err("no selected rows".into());
        }
        let mut marks = BTreeMap::new();
        for r in &results {
            let token = if r["needs_peer"].is_string() {
                format!("needs-peer #71 [X] {record}")
            } else if let Some(reason) = r["unrealizable"].as_str() {
                format!("unrealizable: {reason} [X] {record}")
            } else {
                format!(
                    "measured {}: {} [X] {record}",
                    text(&r["verdict"])?,
                    r["observed"]
                )
            };
            marks.insert(text(&r["id"])?.to_owned(), token);
        }
        let source = fs::read("harness/src/scenarios/chain.rs").map_err(|e| e.to_string())?;
        let receipt_path = PathBuf::from(record.replace(".md", ".json"));
        let mut receipt: Value = if receipt_path.exists() {
            serde_json::from_slice(&fs::read(&receipt_path).map_err(|e| e.to_string())?)
                .map_err(|e| e.to_string())?
        } else {
            json!({"source_pin":PIN,"version":version,"base_commit":"5864eb626833e58ff32f2150216f60d6860d4f7a","record":record,"runs":[]})
        };
        receipt["runs"].as_array_mut().ok_or("receipt runs")?.push(json!({
            "run_id":run_id,"kind":kind,"datadir":instance_pointer(&root),"version":version,
            "chain_source_sha256":hex::encode(bsv_rs::primitives::hash::sha256(&source)),
            "wall_seconds":{"label":"[M]","value":started.elapsed().as_secs_f64()},"results":results
        }));
        // Summarize the entire column, including inherited node tokens, using
        // the planned byte-preserving replacements. Classifications are not
        // counted as realized stage comparisons.
        let mut counts = json!({"label":"[M]","rows":rows.len(),"realized":0,
            "agree":0,"diverge":0,"rpc-precheck":0,"unrealizable":0,"needs-peer":0,"pending":0});
        let mut pending: BTreeMap<String, Vec<String>> = BTreeMap::new();
        for row in &rows {
            let row_id = text(&row["id"])?;
            let token = marks
                .get(row_id)
                .map(String::as_str)
                .unwrap_or(text(&row["node"])?);
            let category = if token.starts_with("measured agree: ") {
                "agree"
            } else if token.starts_with("measured diverge: ") {
                "diverge"
            } else if token.starts_with("rpc-precheck:") {
                "rpc-precheck"
            } else if token.starts_with("unrealizable:") {
                "unrealizable"
            } else if token.starts_with("needs-peer #71") {
                "needs-peer"
            } else if token == "pending #66" {
                "pending"
            } else {
                return Err(format!("unrecognized chain node token for {row_id}"));
            };
            counts[category] = json!(counts[category].as_u64().unwrap() + 1);
            if matches!(category, "agree" | "diverge") {
                counts["realized"] = json!(counts["realized"].as_u64().unwrap() + 1);
            }
            if category == "pending" {
                pending
                    .entry(text(&row["case"])?.to_owned())
                    .or_default()
                    .push(row_id.to_owned());
            }
        }
        receipt["counts"] = counts;
        receipt["pending_rows"] = json!(pending);
        write_json(&receipt_path, &receipt)?;
        for row in &results {
            if row["verdict"] == "diverge" {
                lane_witness(row, &record)?;
            }
        }
        mark_rows("chain", &marks)?;
        println!("chain lane {kind}: recorded [X] {} rows [M]", results.len());
        Ok(())
    }
}

// [SRC] src/validation.cpp:4065-4133,4640-4770 at PIN. RPC invalidation
// settles its pool before returning. Intermediate comparisons are chain-only;
// the pre-settlement pool and internal undo vectors remain spec-only.
fn reorg_view(
    n: &mut Node,
    watched: &[(String, RawTx)],
    coins: &[(String, RawTx)],
) -> Result<Value> {
    let tip = n.tip()?;
    let height = tip["height"].as_u64().ok_or("tip height")?;
    let mut live = vec![];
    let mut utxo = vec![];
    for (name, tx) in watched.iter().chain(coins) {
        let output = n.call("gettxout", json!([id(tx), 0, false]))?;
        if output.is_null() {
            continue;
        }
        if watched.iter().any(|(w, _)| w == name) {
            live.push(name.clone());
        }
        if output["bestblock"] != tip["hash"] {
            return Err("output/tip snapshot race".into());
        }
        let value = output["value"].as_f64().ok_or("coin amount")? * 100_000_000.0;
        if (value - value.round()).abs() > 0.0001 {
            return Err("fractional satoshi".into());
        }
        utxo.push(json!({"outpoint":name,"value":value.round() as u64,
            "script":output["scriptPubKey"]["hex"],
            "height":height + 1 - output["confirmations"].as_u64().ok_or("coin depth")?,
            "coinbase":output["coinbase"],"confiscation":output["confiscation"]}));
    }
    let mut pool = vec![];
    let mut held = vec![];
    for (method, names) in [
        ("getrawmempool", &mut pool),
        ("getrawnonfinalmempool", &mut held),
    ] {
        let ids = n.call(method, json!([]))?;
        for hash in ids.as_array().ok_or("pool ids")? {
            let name = watched
                .iter()
                .find(|(_, tx)| json!(id(tx)) == *hash)
                .ok_or("unexpected pool transaction")?
                .0
                .clone();
            names.push(name);
        }
        names.sort();
    }
    Ok(json!({"view":{"height":height,"coins":live,"pool":pool,"held":held},"utxo":utxo}))
}

fn reorg_expected(row: &Value) -> Result<Value> {
    let mut views = row["expected"]["views"]
        .as_array()
        .ok_or("reorg views")?
        .clone();
    for view in &mut views {
        view.as_object_mut()
            .or_err("view.as_object_mut()")?
            .remove("complete");
        view["view"]
            .as_object_mut()
            .or_err("view['view'].as_object_mut()")?
            .remove("pool");
        view["view"]
            .as_object_mut()
            .or_err("view['view'].as_object_mut()")?
            .remove("held");
        for coin in view["utxo"].as_array_mut().ok_or("expected coins")? {
            coin["script"] = json!(hex::encode(script()));
        }
    }
    Ok(
        json!({"views":views,"automaticAgrees":row["expected"]["automaticAgrees"],
        "disconnects":row["expected"]["disconnects"],"final":row["expected"]["final"]}),
    )
}

fn reorg_recipe(root: &Path, row: &Value) -> Result<Value> {
    let depth = row["depth"].as_u64().ok_or("reorg depth")?;
    let mut all_calls = vec![];
    let mut materials = vec![];
    let mut auto = Value::Null;
    let mut manual = Value::Null;
    let mut manual_views = vec![];
    let mut disconnected = 0;
    for mode in ["automatic", "operator"] {
        let mut n = start_owned(root, &format!("{}-{mode}", text(&row["id"])?), "")?;
        let (f, _, base) = seed(&mut n)?;
        let k = spend(&f, 98000, 2);
        let mut watched = vec![("F".to_owned(), f.clone())];
        let mut coinbases = vec![];
        let mut active = vec![];
        let mut branch_bytes = vec![];
        let mut parent_tx = f.clone();
        for i in 0..depth {
            let t = spend(&parent_tx, 99000 - i * 1000, 1);
            let coinbase = block_codec::coinbase_tx(
                102 + i as u32,
                5_000_000_000,
                script(),
                format!("A{i}").as_bytes(),
            );
            let (hash, reply) =
                n.submit(&[coinbase.clone(), t.clone()], 1_700_000_001 + i as u32)?;
            if block_judgment(&reply) != json!({"status":"ok"}) {
                return Err(format!("A branch refused {reply}"));
            }
            active.push(hash);
            watched.push((format!("T{}", i + 1), t.clone()));
            coinbases.push((format!("A{}:coinbase", i + 1), coinbase));
            parent_tx = t;
        }
        watched.push(("K".to_owned(), k.clone()));
        let mut parent_hash = txid_from_display_hex(&base)?;
        let bits = u32::from_str_radix(text(&n.tip()?["bits"])?, 16).map_err(|e| e.to_string())?;
        for i in 0..=depth {
            let coinbase = block_codec::coinbase_tx(
                102 + i as u32,
                5_000_000_000,
                script(),
                format!("B{i}").as_bytes(),
            );
            let mut txs = vec![coinbase.clone()];
            if i == 0 {
                txs.push(k.clone());
            }
            let (header, bytes) =
                block_codec::assemble(4, parent_hash, 1_700_000_100 + i as u32, bits, &txs);
            parent_hash = header.hash();
            branch_bytes.push((txid_display_hex(&parent_hash), hex::encode(bytes)));
            coinbases.push((format!("B{}:coinbase", i + 1), coinbase));
        }
        if mode == "operator" {
            manual_views.push(reorg_view(&mut n, &watched, &coinbases)?);
            for hash in active.iter().rev() {
                n.call("invalidateblock", json!([hash]))?;
                manual_views.push(reorg_view(&mut n, &watched, &coinbases)?);
            }
        }
        n.call("setmocktime", json!([1_700_000_200]))?;
        for (hash, bytes) in &branch_bytes {
            let reply = n.receipt("submitblock", json!([bytes]))?;
            // A stored side branch may not have reached validation yet.
            // [SRC] src/rpc/mining.cpp:853-877 at PIN. This is only a
            // storage acknowledgement; active ancestry is checked below.
            if block_judgment(&reply) != json!({"status":"ok"})
                && !(mode == "automatic" && reply["result"] == "inconclusive")
            {
                return Err(format!("B branch refused {reply}"));
            }
            if n.call("getblock", json!([hash, 0]))? != json!(bytes) {
                return Err("stored rival bytes differ".into());
            }
            if mode == "operator" {
                manual_views.push(reorg_view(&mut n, &watched, &coinbases)?);
            }
        }
        if n.call("getbestblockhash", json!([]))?
            != json!(branch_bytes.last().or_err("branch_bytes.last()")?.0)
        {
            return Err("longer rival not selected".into());
        }
        for (offset, (hash, _)) in branch_bytes.iter().enumerate() {
            let body = n.call("getblock", json!([hash, 1]))?;
            if body["confirmations"] != json!(depth + 1 - offset as u64) {
                return Err("rival ancestry not fully active".into());
            }
        }
        let final_view = reorg_view(&mut n, &watched, &coinbases)?;
        for hash in &active {
            let block = n.call("getblock", json!([hash, 1]))?;
            if block["confirmations"] != -1 {
                return Err("old branch remains active".into());
            }
            if mode == "automatic" {
                disconnected += 1;
            }
        }
        n.call("getchaintips", json!([]))?;
        if mode == "automatic" {
            auto = final_view;
        } else {
            manual = final_view;
        }
        n.stop()?;
        materials.push(json!({"mode":mode,"conf":n.conf,"base":base,"active":active,
            "rival":branch_bytes,"transactions":watched.iter().map(|(name,tx)|json!({"name":name,"material":material(tx)})).collect::<Vec<_>>(),
            "coinbases":coinbases.iter().map(|(name,tx)|json!({"name":name,"material":material(tx)})).collect::<Vec<_>>()}));
        all_calls.extend(std::mem::take(&mut n.calls));
    }
    let raw_views = manual_views.clone();
    for view in &mut manual_views {
        view["view"]
            .as_object_mut()
            .or_err("view['view'].as_object_mut()")?
            .remove("pool");
        view["view"]
            .as_object_mut()
            .or_err("view['view'].as_object_mut()")?
            .remove("held");
    }
    let observed = json!({"views":manual_views,"automaticAgrees":auto == manual,
        "disconnects":disconnected,"final":auto["view"]});
    let mut result = measured(row, observed, reorg_expected(row)?,
        "Two independent funded prefixes. Automatic depth-N fork loses to a depth-(N+1) rival spending the same F. Operator replay invalidates each A tip and submits each B block. Compare every chain-only intermediate watched UTXO (amount, script, height, flags), removed old blocks, exact final pools and both final projections. Scripts rematerialize to signed P2PKH. Internal pre-settlement pools, full-prefix completeness and undo-vector representation remain spec-only; raw operator pools are retained separately.",all_calls,
        json!({"runs":materials,"operator_views_with_settled_pools":raw_views,"automatic_final":auto,"operator_final":manual}));
    result["declared_expected"] = row["expected"].clone();
    result["spec_only"] = json!([
        "views.complete: the model's full map excludes the live funding prefix",
        "views.view.pool and views.view.held: RPC invalidation has already settled its pool"
    ]);
    result["rematerialized"] = json!([
        "P2SH fixture scripts become signed P2PKH",
        "symbolic txids become actual funded transaction ids"
    ]);
    Ok(result)
}

// [M] 2026-10-14 (#132): called only by the test module's explicit replay, so built with it.
#[cfg(test)]
fn lane_witness(row: &Value, record: &str) -> Result<()> {
    let name = format!("s6-66-chn3-{}", text(&row["id"])?);
    let submission = row["rpc"]
        .as_array()
        .ok_or("witness calls")?
        .iter()
        .rev()
        .find(|c| {
            matches!(
                c["method"].as_str(),
                Some("submitblock" | "softrejectblock" | "acceptblock")
            )
        })
        .ok_or("witness submission")?;
    let data = json!({"id":name,"class":"node observation differs from declared projection",
        "classification":"open","source_pin":PIN,"input_label":"[D]",
        "witness":{"family":"chain","row":row["id"],"receipt":record.replace(".md",".json"),"fixtures":row["fixtures"]},
        "initial_chain":{"recipe":row["recipe"],"complete_rpc_history":record.replace(".md",".json"),"family":"chain","row":row["id"]},
        "steps":[{"id":"observe","action":{"type":submission["method"],"params":submission["params"]},
            "kind":"recorded chain projection","rules":[submission["source"]],"label":"[D]",
            "expected_observations":row["expected"],"actual_observations":row["observed"],
            "status_basis":"Only the named recorded projection is judged; the receipt retains all chain and pool evidence.",
            "node":format!("measured diverge [X] {record}")}],
        "replay":{"record":record,"rpc_handler":submission["source"]}});
    fs::write(format!("corpus/scenarios/witnesses/{name}.md"),format!(
        "# {name}\n\n[X] Classification `open` as data. The recipe, actual inputs and RPC receipt bind the observation.\n\n```json\n{}\n```\n",
        serde_json::to_string_pretty(&data).or_err("serde_json::to_string_pretty(&data)")?)).map_err(|e|e.to_string())
}

// [SRC] src/validation.cpp:3620-3662 at PIN: aggregate the fees before
// comparing the coinbase reward, then wait for queued script results.
fn reward_recipe(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_owned(root, text(&row["id"])?, "")?;
    let (f, t, base) = seed(&mut n)?;
    let coinbase = block_codec::coinbase_tx(102, 5_000_001_001, script(), b"reward-plus-one");
    let (hash, receipt) = n.submit(&[coinbase.clone(), t.clone()], 1_700_000_001)?;
    let observed = if receipt.get("error").is_some() {
        return Err(format!(
            "reward RPC precheck needs separate classification: {receipt}"
        ));
    } else if receipt["result"].is_null() {
        json!("accepted")
    } else {
        receipt["result"].clone()
    };
    let snapshot = chain_snapshot(&mut n, &f, &t)?;
    if n.call("getbestblockhash", json!([]))? != json!(base) {
        return Err("rejected reward changed active tip".into());
    }
    n.stop()?;
    Ok(measured(row,observed,row["expected"].clone(),
        "Fund F at height 101, sign T with fee 1000, and submit a solved live-tip block at 102 paying 5000001001 to its coinbase: one satoshi above subsidy plus the actual fee. Check unchanged active tip and chain-only F/T outputs.",std::mem::take(&mut n.calls),
        json!({"F":material(&f),"T":material(&t),"coinbase":material(&coinbase),"block":hash,"base":base,"snapshot":snapshot,"conf":n.conf})))
}

// [SRC] src/validation.cpp:3324-3385 at PIN. The missing input is read
// before script validation; retain the intentionally absent outpoint.
fn missing_input_recipe(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_owned(root, text(&row["id"])?, "")?;
    let (f, mut t, base) = seed(&mut n)?;
    t.inputs[0].txid = [9; 32];
    t.inputs[0].script = vec![1, 0x51];
    let coinbase = block_codec::coinbase_tx(102, 5_000_000_000, script(), b"missing-input");
    let (hash, receipt) = n.submit(&[coinbase.clone(), t.clone()], 1_700_000_001)?;
    if receipt.get("error").is_some() {
        return Err(format!("unexpected RPC precheck: {receipt}"));
    }
    let observed = if receipt["result"].is_null() {
        json!("accepted")
    } else {
        receipt["result"].clone()
    };
    let snapshot = chain_snapshot(&mut n, &f, &t)?;
    if n.call("getbestblockhash", json!([]))? != json!(base) {
        return Err("missing-input block changed tip".into());
    }
    n.stop()?;
    Ok(measured(row,observed,row["expected"].clone(),
        "Fund the live prefix to 101, retain the declared absent 32-byte 0x09 prevout, and submit a solved block at 102. Check exact rejection and unchanged tip and watched outputs.",std::mem::take(&mut n.calls),json!({"F":material(&f),"T":material(&t),"coinbase":material(&coinbase),"base":base,"block":hash,"snapshot":snapshot,"conf":n.conf})))
}

#[allow(
    clippy::expect_used,
    reason = "the scenario key is a fixed valid scalar; the signer refuses only a zero or out-of-range digest scalar"
)]
fn locked_spend(parent: &RawTx) -> RawTx {
    use bsv_rs::primitives::bsv::sighash::{
        compute_sighash_for_signing, SighashParams, TxInput, TxOutput,
    };
    let mut tx = spend(parent, 99000, 1);
    tx.lock_time = 102;
    tx.inputs[0].sequence = 0xfffffffe;
    let inputs = vec![TxInput {
        txid: parent.txid_internal(),
        output_index: 0,
        script: vec![],
        sequence: 0xfffffffe,
    }];
    let outputs = vec![TxOutput {
        satoshis: 99000,
        script: script(),
    }];
    let digest = compute_sighash_for_signing(&SighashParams {
        version: 1,
        inputs: &inputs,
        outputs: &outputs,
        locktime: 102,
        input_index: 0,
        subscript: &parent.outputs[0].script,
        satoshis: parent.outputs[0].satoshis,
        scope: 0x41,
    });
    let signature = key().sign(&digest).expect("key().sign(&digest)");
    let integer = |x: &[u8; 32]| {
        let mut bytes: Vec<u8> = x.iter().copied().skip_while(|v| *v == 0).collect();
        if bytes.is_empty() {
            bytes.push(0);
        }
        if bytes[0] & 128 != 0 {
            bytes.insert(0, 0);
        }
        [vec![2, bytes.len() as u8], bytes].concat()
    };
    let payload = [integer(signature.r()), integer(signature.s())].concat();
    let der = [vec![0x30, payload.len() as u8], payload, vec![0x41]].concat();
    tx.inputs[0].script.clear();
    bsv_script_harness::gen::push_min(&mut tx.inputs[0].script, &der);
    bsv_script_harness::gen::push_min(
        &mut tx.inputs[0].script,
        &key().public_key().to_compressed(),
    );
    tx
}

// [SRC] src/txmempool.cpp:947-1023 at PIN: finality and coinbase maturity
// are rechecked against the successor of the restored tip.
fn rollback_recipe(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_owned(root, text(&row["id"])?, "")?;
    let immature = row["case"] == "immature";
    let (f, t, base) = if immature {
        n.mine(1, 1_699_990_001)?;
        n.mine(1, 1_699_990_002)?;
        let f = block_codec::coinbase_tx(3, 100000, script(), b"watched-funding");
        let (_, reply) = n.submit(std::slice::from_ref(&f), 1_699_990_003)?;
        if block_judgment(&reply) != json!({"status":"ok"}) {
            return Err(format!("funding coinbase: {reply}"));
        }
        for height in 4..=101 {
            n.mine(1, 1_699_990_000 + height)?;
        }
        let base = text(&n.call("getbestblockhash", json!([]))?)?.to_owned();
        let t = spend(&f, 99000, 1);
        (f, t, base)
    } else {
        let (f, _, base) = seed(&mut n)?;
        let t = locked_spend(&f);
        (f, t, base)
    };
    let (a, reply) = n.submit(&[cb(102, "rollback-a")], 1_700_000_001)?;
    if block_judgment(&reply) != json!({"status":"ok"}) {
        return Err(format!("rollback A: {reply}"));
    }
    let (b, reply) = n.submit(&[cb(103, "rollback-b"), t.clone()], 1_700_000_002)?;
    if block_judgment(&reply) != json!({"status":"ok"}) {
        return Err(format!("rollback spend: {reply}"));
    }
    let before = chain_snapshot(&mut n, &f, &t)?;
    if before != json!({"height":103,"coins":["T"],"pool":[],"held":[]}) {
        return Err("rollback setup snapshot".into());
    }
    n.call("invalidateblock", json!([a]))?;
    let observed = chain_snapshot(&mut n, &f, &t)?;
    if n.call("getbestblockhash", json!([]))? != json!(base) {
        return Err("rollback base mismatch".into());
    }
    n.stop()?;
    Ok(measured(row,observed,row["expected"].clone(),
        "Arrange the row at live tip 101: F is a coinbase at 3 for maturity, or a regular funding output with a correctly re-signed height-lock-102 spend. Mine empty 102 and spend in 103, verify inclusion, invalidate 102 and read exact restored coins and both pools at 101.",std::mem::take(&mut n.calls),json!({"F":material(&f),"T":material(&t),"base":base,"A":a,"B":b,"before":before,"conf":n.conf})))
}

fn chain_unrealizable(row: &Value) -> Option<&'static str> {
    if row["case"] == "parent-tip" {
        Some("The declared mismatched coins best pointer is an internal assertion, not a submitblock rejection. ConnectTip constructs its coins view on the selected active parent; no RPC or launch setting supplies the synthetic pointer. [SRC] src/validation.cpp:3034-3038,4204-4349 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b")
    } else if row["case"] == "genesis" {
        Some("The row replaces hashGenesisBlock with a synthetic excessive-reward block hash. The pinned regtest constructor fixes and asserts its genesis hash; there is no RPC or launch override for that hash. [SRC] src/chainparams.cpp:1508-1519; src/validation.cpp:3034-3052 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b")
    } else {
        pend66_unrealizable(row)
    }
}

// (S3, lane pend-66, Claude Opus 5.5, [M] 2026-10-13) Rows whose declared
// condition the implemented instruments do not produce at the pin; each
// reason is cited. [D] 2026-10-13, lane fix-pend3: candidate stopped-datadir
// instruments below remain unmeasured. (S3, lane fix-pend2, Claude Opus 5.5, [M] 2026-10-13) The pinned
// suites, searched: the functional suite deletes whole chainstate and blocks
// directories of a stopped node (test/functional/walletbackup.py:165-167,
// 190-191; wallet-hd.py:77-78); the unit suite builds synthetic in-memory
// coins views and undo (src/test/coins_tests.cpp:690-739; src/test/
// undo_tests.cpp:22-33,54-82,97-135); neither rewrites a stored coin or an
// undo record in place. The harness rewrites its own undo records (rev files)
// for chain-undo-count, chain-output-metadata and the partial-disconnect rows.
fn pend66_unrealizable(row: &Value) -> Option<&'static str> {
    match row["case"].as_str()? {
        "rank" => Some("The row's tie is the final pointer comparison: equal work, equal validation completion and equal sequence id leave CBlockIndexWorkComparator to compare CBlockIndex heap addresses, which the source says happens only with blocks loaded from disk. A restart can produce the tie, but the allocator sets which address is lower; no RPC, setting or lifecycle step controls it, so a declared winner cannot be realized (DESIGN-S6 2.4 records such a tie as non-judging). [SRC] src/block_index.h:373-375,1239-1270; src/validation.cpp:6670-6688 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        "undo-collision" => Some("The row needs a restored prevout already present in the coins view at undo time. Disconnection runs from the tip down and, within a block, in reverse transaction order; for an unmodified body an undo entry restores the spending input's own prevout. The implemented rev-record edits change restored data, not that prevout or pre-existing coins. This harness has no chainstate writer or block-body corruption instrument. The stopped-datadir surface could in principle support either: disk reads check header proof of work and the indexed header hash without recomputing the body's merkle root, and checklevel=0 skips block validity checks. A body-prevout replacement is an unmeasured candidate; its changed transaction id can also cause an output-removal mismatch, which must be controlled before an isolated collision is counted. [SRC] src/processing_block_index.cpp:21-71; src/validation.cpp:2941-2952,4065-4090,6802,6844-6859; src/block_file_access.cpp:247-275; src/block_index.cpp:245-260; src/init.cpp:3960-3966 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        "soft-freeze" => Some("The row sets an effective freeze of zero descendants on an already-active block and later clears it, restoring that block at height 102. At the pin a block's freeze is assigned when its own connection spends a consensus-frozen output. The duration setter rejects negatives but has no upper bound: literal zero maps to INT32_MAX, while nonzero int64 values narrow into an int32 field. On the pinned build's ordinary conversion, 4294967296 narrows to zero; the block is frozen but its child receives -1 and is not effectively frozen. This source-derived boundary is unmeasured. It does not supply the row's explicit set/clear route on an already-active block: no supported RPC clears the persisted block mark; clearing blacklist entries is a different operation. The declaration remains unchanged pending the captain's re-cut decision. [SRC] src/init.cpp:3340-3347; src/config.cpp:2602-2612; src/config.h:984; src/validation.cpp:3402-3407,3720-3740; src/block_index.h:548-557,576-580,1135-1140; src/disk_block_index.h:100-116; src/rpc/frozentxo_rpc.cpp:501-528 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        "disconnect-pool-cap" => Some("The row caps the disconnect pool at the coinbase's serialized size under byte-only accounting and reads the queued and filtered sets. At the pin the cap is -maxmempool, which accepts 0 or at least 30 percent of the 1000 MB default; the pool's usage is malloc-based DynamicMemoryUsage, not serialized bytes; and the queue lives only inside one reorganization with no RPC reader. [SRC] src/config.cpp:2440-2460; src/init.cpp:2385-2389; src/policy/policy.h:87; src/validation.cpp:4109-4114; src/txmempool.cpp:2529-2559; src/txmempool.h:1455-1505 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        _ => None,
    }
}

// [SRC] src/validation.cpp:3324-3385,3404-3443,3620-3655 at PIN.
// Transaction order supplies a child input from the immediately prior spend.
fn sequential_inputs_recipe(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_owned(root, text(&row["id"])?, "")?;
    let (f, t, base) = seed(&mut n)?;
    let u = spend(&t, 98000, 1);
    let before = n.call("gettxout", json!([id(&f), 0, false]))?;
    let coinbase = block_codec::coinbase_tx(102, 5_000_000_000, script(), b"sequential");
    let (hash, reply) = n.submit(&[coinbase.clone(), t.clone(), u.clone()], 1_700_000_001)?;
    if block_judgment(&reply) != json!({"status":"ok"}) {
        return Err(format!("sequential connection failed: {reply}"));
    }
    let body = n.call("getblock", json!([hash, 1]))?;
    if body["tx"] != json!([id(&coinbase), id(&t), id(&u)])
        || body["confirmations"] != 1
        || body["height"] != 102
        || n.call("getbestblockhash", json!([]))? != json!(hash)
    {
        return Err("sequential active body mismatch".into());
    }
    let actual_t = n.raw_tx(&json!(id(&t)))?;
    let actual_u = n.raw_tx(&json!(id(&u)))?;
    if actual_t.encode() != t.encode() || actual_u.encode() != u.encode() {
        return Err("sequential stored transaction mismatch".into());
    }
    let parent = n.call("gettxout", json!([id(&t), 0, false]))?;
    let child = n.call("gettxout", json!([id(&u), 0, false]))?;
    let funding = n.call("gettxout", json!([id(&f), 0, false]))?;
    if !funding.is_null()
        || before["value"] != json!(0.001)
        || child["value"] != json!(0.00098)
        || child["scriptPubKey"]["hex"] != hex::encode(script())
    {
        return Err("sequential funding/child output mismatch".into());
    }
    let fees = f.outputs[0].satoshis - actual_t.outputs[0].satoshis + actual_t.outputs[0].satoshis
        - actual_u.outputs[0].satoshis;
    let observed = json!({"parentSpent":parent.is_null(),"childLive":!child.is_null(),"fees":fees});
    let pool = n.call("getrawmempool", json!([]))?;
    let held = n.call("getrawnonfinalmempool", json!([]))?;
    n.call("getchaintips", json!([]))?;
    n.stop()?;
    Ok(measured(row, observed, row["expected"].clone(),
        "Mine funded F at 101, sign T spending F and U spending T with fee 1000 each, submit the ordered body at 102, verify its active membership and exact stored transaction bytes, and read chain-only F/T/U outputs. Fees are summed from the funded input and stored transaction amounts.",
        std::mem::take(&mut n.calls), json!({"F":material(&f),"T":material(&t),"U":material(&u),"coinbase":material(&coinbase),"base":base,"block":hash,"before":before,"child":child,"pool":pool,"held":held,"conf":n.conf})))
}

// [SRC] src/txn_grouper.cpp:10-43; src/validation.cpp:3324-3338 at PIN.
// The dependent group retains body order; a child before its parent has no input.
fn reversed_inputs_recipe(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_owned(root, text(&row["id"])?, "")?;
    let (f, t, base) = seed(&mut n)?;
    let u = spend(&t, 98000, 1);
    let before = n.call("gettxout", json!([id(&f), 0, false]))?;
    let coinbase = block_codec::coinbase_tx(102, 5_000_000_000, script(), b"reversed");
    let (hash, reply) = n.submit(&[coinbase.clone(), u.clone(), t.clone()], 1_700_000_001)?;
    if reply.get("error").is_some() {
        return Err(format!("reversed-input RPC precheck: {reply}"));
    }
    let observed = if reply["result"].is_null() {
        json!("accepted")
    } else {
        reply["result"].clone()
    };
    let after = n.call("gettxout", json!([id(&f), 0, false]))?;
    let parent = n.call("gettxout", json!([id(&t), 0, false]))?;
    let child = n.call("gettxout", json!([id(&u), 0, false]))?;
    if n.call("getbestblockhash", json!([]))? != json!(base)
        || before != after
        || !parent.is_null()
        || !child.is_null()
    {
        return Err("reversed-input rejection changed chain view".into());
    }
    let pool = n.call("getrawmempool", json!([]))?;
    let held = n.call("getrawnonfinalmempool", json!([]))?;
    n.call("getchaintips", json!([]))?;
    n.stop()?;
    Ok(measured(row, observed, row["expected"].clone(),
        "Mine funded F at 101, sign T spending F and U spending T, submit a solved block with U before T, and record the exact submitblock result. Verify the unchanged selected tip and funding coin and absence of T/U chain outputs.",
        std::mem::take(&mut n.calls), json!({"F":material(&f),"T":material(&t),"U":material(&u),"coinbase":material(&coinbase),"base":base,"block":hash,"before":before,"after":after,"pool":pool,"held":held,"conf":n.conf})))
}

// [SRC] src/validation.cpp:3304-3319,3415-3420,3564-3573,3679-3713;
// src/validation.h:108 at PIN. This small body has one validation group.
fn queued_script_recipe(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_owned(root, text(&row["id"])?, "")?;
    let (f, t, base) = seed(&mut n)?;
    let mut bad = t.clone();
    bad.inputs[0].script.clear();
    bsv_script_harness::gen::push_min(&mut bad.inputs[0].script, &[]);
    bsv_script_harness::gen::push_min(
        &mut bad.inputs[0].script,
        &key().public_key().to_compressed(),
    );
    let coinbase = block_codec::coinbase_tx(102, 5_000_000_000, script(), b"queued-script");
    let before = n.call("gettxout", json!([id(&f), 0, false]))?;
    let (hash, reply) = n.submit(&[coinbase.clone(), bad.clone()], 1_700_000_001)?;
    if reply.get("error").is_some() {
        return Err(format!("queued-script RPC precheck: {reply}"));
    }
    let observed = if reply["result"].is_null() {
        json!("accepted")
    } else {
        reply["result"].clone()
    };
    let after = n.call("gettxout", json!([id(&f), 0, false]))?;
    if before != after
        || n.call("getbestblockhash", json!([]))? != json!(base)
        || !n.call("gettxout", json!([id(&bad), 0, false]))?.is_null()
    {
        return Err("queued-script rejection changed chain view".into());
    }
    let pool = n.call("getrawmempool", json!([]))?;
    let held = n.call("getrawnonfinalmempool", json!([]))?;
    // A signed control changes only scriptSig and its derived identifiers.
    let (control, good) = n.submit(&[coinbase.clone(), t.clone()], 1_700_000_001)?;
    if block_judgment(&good) != json!({"status":"ok"})
        || n.call("getbestblockhash", json!([]))? != json!(control)
    {
        return Err(format!("signed control failed: {good}"));
    }
    let body = n.call("getblock", json!([control, 1]))?;
    if body["tx"] != json!([id(&coinbase), id(&t)]) || body["confirmations"] != 1 {
        return Err("signed control active body mismatch".into());
    }
    n.call("getchaintips", json!([]))?;
    n.stop()?;
    Ok(measured(row, observed, row["expected"].clone(),
        "Fund F at 101 and replace the signed spend's signature with an empty signature while retaining its compressed public key, amounts and input. Submit a solved two-transaction body at 102, observe exact rejection and unchanged chain-only funding. Submit the correctly signed control and verify its active body. The small body selects one validation group at the pinned default, hence the queued script-result path; no internal queue contents are claimed.",
        std::mem::take(&mut n.calls), json!({"F":material(&f),"T":material(&t),"bad":material(&bad),"coinbase":material(&coinbase),"base":base,"block":hash,"control":control,"before":before,"after":after,"pool":pool,"held":held,"conf":n.conf})))
}

// [SRC] src/validation.cpp:3304-3319,3415-3420,3564-3573,3648-3713;
// src/validation.h:108 at PIN. This small body has one validation group.
fn reward_before_script_recipe(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_owned(root, text(&row["id"])?, "")?;
    let (f, t, base) = seed(&mut n)?;
    let mut bad = t.clone();
    bad.inputs[0].script.clear();
    bsv_script_harness::gen::push_min(&mut bad.inputs[0].script, &[]);
    bsv_script_harness::gen::push_min(
        &mut bad.inputs[0].script,
        &key().public_key().to_compressed(),
    );
    let overpay = block_codec::coinbase_tx(102, 5_000_001_001, script(), b"reward-before-script");
    let before = n.call("gettxout", json!([id(&f), 0, false]))?;
    let (hash, reply) = n.submit(&[overpay.clone(), bad.clone()], 1_700_000_001)?;
    if reply.get("error").is_some() {
        return Err(format!("queued-script RPC precheck: {reply}"));
    }
    let observed = if reply["result"].is_null() {
        json!("accepted")
    } else {
        reply["result"].clone()
    };
    let after = n.call("gettxout", json!([id(&f), 0, false]))?;
    if before != after
        || n.call("getbestblockhash", json!([]))? != json!(base)
        || !n.call("gettxout", json!([id(&bad), 0, false]))?.is_null()
    {
        return Err("queued-script rejection changed chain view".into());
    }
    let pool = n.call("getrawmempool", json!([]))?;
    let held = n.call("getrawnonfinalmempool", json!([]))?;
    // The same failing script with a permitted reward reaches script rejection.
    let coinbase = block_codec::coinbase_tx(102, 5_000_000_000, script(), b"reward-before-script");
    let (script_control, script_reply) =
        n.submit(&[coinbase.clone(), bad.clone()], 1_700_000_001)?;
    if script_reply != json!({"result":"blk-bad-inputs"})
        || n.call("getbestblockhash", json!([]))? != json!(base)
    {
        return Err(format!("script rejection control failed: {script_reply}"));
    }
    // A signed control changes only scriptSig and its derived identifiers.
    let (control, good) = n.submit(&[coinbase.clone(), t.clone()], 1_700_000_001)?;
    if block_judgment(&good) != json!({"status":"ok"})
        || n.call("getbestblockhash", json!([]))? != json!(control)
    {
        return Err(format!("signed control failed: {good}"));
    }
    let body = n.call("getblock", json!([control, 1]))?;
    if body["tx"] != json!([id(&coinbase), id(&t)]) || body["confirmations"] != 1 {
        return Err("signed control active body mismatch".into());
    }
    n.call("getchaintips", json!([]))?;
    n.stop()?;
    Ok(measured(row, observed, row["expected"].clone(),
        "Fund F at 101; combine an empty-signature spend with a coinbase exceeding subsidy plus its fee by one satoshi. Record the reward rejection and unchanged funding/tip. Lower only the reward to obtain blk-bad-inputs, then restore the signature and verify the accepted active body. All submissions have one validation group; compare the exact reward-before-script rejection without claiming internal queue contents.",
        std::mem::take(&mut n.calls), json!({"F":material(&f),"T":material(&t),"bad":material(&bad),"coinbase":material(&coinbase),"overpay":material(&overpay),"script_control":script_control,"base":base,"block":hash,"control":control,"before":before,"after":after,"pool":pool,"held":held,"conf":n.conf})))
}

// [SRC] src/txmempool.cpp:947-1023; src/validation.cpp:5978-6037 at PIN.
// Keep T out of all block bodies so removal judges a retained accepted entry.
fn retained_nonfinal_recipe(root: &Path, row: &Value) -> Result<Value> {
    let post_genesis = row["case"] == "retained-nonfinal-after-genesis";
    let extra = if post_genesis {
        "genesisactivationheight=1\n"
    } else {
        ""
    };
    let mut n = start_owned(root, text(&row["id"])?, extra)?;
    let (f, _, base) = seed(&mut n)?;
    let t = locked_spend(&f);
    let (a, reply) = n.submit(&[cb(102, "retained-a")], 1_700_000_001)?;
    if block_judgment(&reply) != json!({"status":"ok"}) {
        return Err(format!("retained A: {reply}"));
    }
    let (b, reply) = n.submit(&[cb(103, "retained-b")], 1_700_000_002)?;
    if block_judgment(&reply) != json!({"status":"ok"}) {
        return Err(format!("retained B: {reply}"));
    }
    n.call("sendrawtransaction", json!([hex::encode(t.encode())]))?;
    let before = chain_snapshot(&mut n, &f, &t)?;
    if before != json!({"height":103,"coins":["F"],"pool":["T"],"held":[]}) {
        return Err(format!("retained setup differs: {before}"));
    }
    n.call("invalidateblock", json!([a]))?;
    let after = chain_snapshot(&mut n, &f, &t)?;
    if n.call("getbestblockhash", json!([]))? != json!(base)
        || after["height"] != 101
        || after["coins"] != json!(["F"])
    {
        return Err("retained cleanup tip/coins mismatch".into());
    }
    let observed = json!(after["pool"]
        .as_array()
        .ok_or("retained pool")?
        .contains(&json!("T")));
    n.stop()?;
    Ok(measured(row, observed, row["expected"].clone(),
        "Fund F at 101, mine empty blocks 102 and 103, and admit the correctly signed lock-height-102 non-final-sequence spend only at tip 103. Verify it is accepted and absent from block bodies, invalidate 102, then read its retained accepted-pool membership at tip 101. The post-Genesis variant sets activation to 1 because the pinned launcher refuses 0; all observed heights preserve the row's post-Genesis era.",
        std::mem::take(&mut n.calls), json!({"F":material(&f),"T":material(&t),"base":base,"A":a,"B":b,"before":before,"after":after,"conf":n.conf})))
}

// [SRC] src/validation.cpp:2252-2262,4640-4770; src/chainparams.cpp:1460 at PIN.
fn batching_recipe(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_owned(root, text(&row["id"])?, "")?;
    for h in 1..50 {
        n.mine(1, 1_699_990_000 + h)?;
    }
    let f = block_codec::coinbase_tx(50, 100000, script(), b"batch-funding");
    let (_, reply) = n.submit(std::slice::from_ref(&f), 1_699_990_050)?;
    if block_judgment(&reply) != json!({"status":"ok"}) {
        return Err(format!("batch funding: {reply}"));
    }
    for h in 51..=101 {
        n.mine(1, 1_699_990_000 + h)?;
    }
    let base = text(&n.call("getbestblockhash", json!([]))?)?.to_owned();
    let bits = u32::from_str_radix(text(&n.tip()?["bits"])?, 16).map_err(|e| e.to_string())?;
    let t = spend(&f, 99000, 1);
    let mut old = vec![];
    for h in 102..=151 {
        let coinbase =
            block_codec::coinbase_tx(h, 5_000_000_000 >> (h / 150), script(), b"batch-old");
        let mut txs = vec![coinbase];
        if h == 150 {
            txs.push(t.clone());
        }
        let (hash, reply) = n.submit(&txs, 1_700_000_000 + h)?;
        if block_judgment(&reply) != json!({"status":"ok"}) {
            return Err(format!("old branch {h}: {reply}"));
        }
        old.push(hash);
    }
    let before = chain_snapshot(&mut n, &f, &t)?;
    if before != json!({"height":151,"coins":["T"],"pool":[],"held":[]}) {
        return Err("batch setup projection".into());
    }
    let inclusion = n.call("getblock", json!([old[48], 1]))?;
    if !inclusion["tx"]
        .as_array()
        .ok_or("batch spend body")?
        .contains(&json!(id(&t)))
    {
        return Err("batch old spend missing".into());
    }
    let mut parent = txid_from_display_hex(&base)?;
    let mut rival = vec![];
    n.call("setmocktime", json!([1_700_000_500]))?;
    for h in 102..=152 {
        let coinbase =
            block_codec::coinbase_tx(h, 5_000_000_000 >> (h / 150), script(), b"batch-rival");
        let (header, bytes) =
            block_codec::assemble(4, parent, 1_700_000_200 + h, bits, &[coinbase]);
        parent = header.hash();
        let hash = txid_display_hex(&parent);
        let bytes = hex::encode(bytes);
        let reply = n.receipt("submitblock", json!([bytes]))?;
        if block_judgment(&reply) != json!({"status":"ok"}) && reply["result"] != "inconclusive" {
            return Err(format!("batch rival {h}: {reply}"));
        }
        if n.call("getblock", json!([hash, 0]))? != json!(bytes) {
            return Err("batch rival storage".into());
        }
        rival.push(hash);
    }
    let after = chain_snapshot(&mut n, &f, &t)?;
    if n.call("getbestblockhash", json!([]))? != json!(rival.last().ok_or("batch rival")?) {
        return Err("batch final tip not rival".into());
    }
    for hash in &old {
        if n.call("getblock", json!([hash, 1]))?["confirmations"] != -1 {
            return Err("batch old block active".into());
        }
    }
    for (offset, hash) in rival.iter().enumerate() {
        if n.call("getblock", json!([hash, 1]))?["confirmations"] != json!(51 - offset) {
            return Err("batch rival ancestry".into());
        }
    }
    let funding = n.call("gettxout", json!([id(&f), 0, false]))?;
    if funding["coinbase"] != true || funding["value"] != json!(0.001) || after["held"] != json!([])
    {
        return Err("batch final funding/held projection".into());
    }
    let observed = json!({"height":after["height"],"readmitted":after["pool"] == json!(["T"]),"fundingLive":!funding.is_null()});
    let mut expected = row["expected"].clone();
    expected
        .as_object_mut()
        .ok_or("batch expected")?
        .remove("queueEmpty");
    n.stop()?;
    let mut result = measured(row, observed, expected,
        "Mine F as a height-50 coinbase, retain base 101, build old branch 102..151 with its mature spend at 150, then submit rival 102..152. Derive each reward across the height-150 subsidy halving. Verify every old block is stale, every rival block is active, exact final accepted/held pools and restored funding coin. The internal disconnect queue is not exposed by RPC and queueEmpty remains spec-only.",
        std::mem::take(&mut n.calls), json!({"F":material(&f),"T":material(&t),"base":base,"old":old,"rival":rival,"before":before,"after":after,"funding":funding,"conf":n.conf}));
    result["declared_expected"] = row["expected"].clone();
    result["spec_only_fields"] = json!(["queueEmpty"]);
    Ok(result)
}

// [SRC] src/processing_block_index.cpp:9-96; src/validation.cpp:4065-4133;
// src/rpc/blockchain.cpp:1923-2029,2732-2768 at PIN.
fn undo_recipe(root: &Path, row: &Value) -> Result<Value> {
    let overwrite = row["case"] == "overwrite";
    let mut n = start_owned(
        root,
        text(&row["id"])?,
        if overwrite {
            "disablebip30checks=1\n"
        } else {
            ""
        },
    )?;
    let (f, t, base) = seed(&mut n)?;
    let mut points = BTreeSet::new();
    let mut current = base.clone();
    let mut repeated = None;
    // Enumerate every output of this generated prefix. The fixed genesis
    // coinbase is unspendable; no outside transaction or peer exists.
    loop {
        let body = n.call("getblock", json!([current, 1]))?;
        if body["height"] == 0 {
            break;
        }
        for txid in body["tx"].as_array().ok_or("undo prefix body")? {
            let tx = n.raw_tx(txid)?;
            for vout in 0..tx.outputs.len() {
                points.insert((id(&tx), vout));
            }
            if body["height"] == 2 {
                repeated = Some(tx);
            }
        }
        current = text(&body["previousblockhash"])?.to_owned();
    }
    let coinbase = if overwrite {
        repeated.ok_or("repeat coinbase")?
    } else {
        block_codec::coinbase_tx(102, 5_000_000_000, script(), b"undo-clean")
    };
    points.insert((id(&coinbase), 0));
    points.insert((id(&t), 0));
    let mut before = vec![];
    for (txid, vout) in &points {
        before.push(
            json!({"txid":txid,"vout":vout,"coin":n.call("gettxout", json!([txid,vout,false]))?}),
        );
    }
    let original_coinbase = n.call("gettxout", json!([id(&coinbase), 0, false]))?;
    if overwrite && original_coinbase.is_null() {
        return Err("overwrite target not live".into());
    }
    let (hash, reply) = n.submit(&[coinbase.clone(), t.clone()], 1_700_000_001)?;
    if block_judgment(&reply) != json!({"status":"ok"}) {
        return Err(format!("undo connect: {reply}"));
    }
    let connected = n.call("gettxout", json!([id(&coinbase), 0, false]))?;
    if connected["confirmations"] != 1
        || connected["bestblock"] != json!(hash)
        || !n.call("gettxout", json!([id(&f), 0, false]))?.is_null()
        || n.call("gettxout", json!([id(&t), 0, false]))?.is_null()
    {
        return Err("undo connected coins mismatch".into());
    }
    let body = n.call("getblock", json!([hash, 1]))?;
    if body["tx"] != json!([id(&coinbase), id(&t)]) || body["confirmations"] != 1 {
        return Err("undo active body mismatch".into());
    }
    let invalidation = n.call("invalidateblock", json!([hash]))?;
    let tip_restored = n.call("getbestblockhash", json!([]))? == json!(base);
    let mut after = vec![];
    for (txid, vout) in &points {
        after.push(
            json!({"txid":txid,"vout":vout,"coin":n.call("gettxout", json!([txid,vout,false]))?}),
        );
    }
    let residue = n.call("gettxout", json!([id(&coinbase), 0, false]))?;
    let observed = json!({"disconnected":invalidation.is_null() && tip_restored,
        "restored":before == after,"overwrittenCoinPresent":!residue.is_null()});
    let expected = json!({"disconnected":row["expected"]["status"] == "BsvChain.DisconnectResult.ok",
        "restored":row["expected"]["restored"],"overwrittenCoinPresent":row["expected"]["overwrittenCoinPresent"]});
    let final_view = chain_snapshot(&mut n, &f, &t)?;
    n.stop()?;
    let mut result = measured(row, observed, expected,
        "Enumerate all outputs in the owned generated prefix, connect the funded spend, invalidate its block, and compare every enumerated chain-only coin object at the restored base. For overwrite, explicitly disable BIP30 and repeat the byte-identical unspent height-2 coinbase in block 102, observing its creation height change and subsequent loss. This remaps the symbolic overwritten coin's amount to a realizable equal-txid amount. Successful invalidation and restored tip project the disconnect status; retained undo vector and coin counts remain spec-only.",
        std::mem::take(&mut n.calls), json!({"F":material(&f),"T":material(&t),"coinbase":material(&coinbase),"base":base,"block":hash,"before":before,"after":after,"original_coinbase":original_coinbase,"connected_coinbase":connected,"final_view":final_view,"conf":n.conf}));
    result["declared_expected"] = row["expected"].clone();
    result["spec_only_fields"] = json!(["undoVectors", "undoCoins"]);
    Ok(result)
}

// Family-local RPC extension keeps core.rs unchanged. Each call retains its
// raw result/error and its pinned handler, including failed operator attempts.
fn chain_operator_call(n: &mut Node, method: &str, params: Value) -> Result<Value> {
    let source = match method {
        "preciousblock" => "src/rpc/blockchain.cpp:2695-2731",
        "getblockheader" => "src/rpc/blockchain.cpp:884-1063",
        "getmempoolinfo" => "src/rpc/blockchain.cpp:2617-2673",
        "softrejectblock" => "src/rpc/blockchain.cpp:2820-2892",
        "acceptblock" => "src/rpc/blockchain.cpp:2894-2991",
        "pruneblockchain" => "src/rpc/blockchain.cpp:1810-1875",
        "addToConsensusBlacklist" => "src/rpc/frozentxo_rpc.cpp:346-378",
        "verifychain" => "src/rpc/blockchain.cpp:2321-2354",
        "gettxoutsetinfo" => "src/rpc/blockchain.cpp:1877-1921",
        _ => return Err("unsupported chain operator RPC".into()),
    };
    let reply = n
        .rpc
        .as_mut()
        .ok_or("operator RPC not ready")?
        .call(method, params.clone());
    let raw = match &reply {
        Ok(v) => json!({"result":v}),
        Err(e) => {
            json!({"error":e.strip_prefix("rpc error: ").and_then(|s|serde_json::from_str::<Value>(s).ok()).unwrap_or(json!({"transport":e}))})
        }
    };
    n.calls.push(json!({"method":method,"params":params,"source":format!("[SRC] {source} at {PIN}"),"reply":raw}));
    reply
}

fn soft_rejection_recipe(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_owned(root, text(&row["id"])?, "")?;
    let (f, t, base) = seed(&mut n)?;
    let coinbase = cb(102, "soft-rejection");
    let (hash, reply) = n.submit(&[coinbase.clone(), t.clone()], 1_700_000_001)?;
    if block_judgment(&reply) != json!({"status":"ok"}) {
        return Err(format!("soft-rejection setup: {reply}"));
    }
    let initial = n.call("getblock", json!([hash, 1]))?;
    if initial["tx"] != json!([id(&coinbase), id(&t)]) || initial["confirmations"] != 1 {
        return Err("soft-rejection active body mismatch".into());
    }
    let rejected = chain_operator_call(&mut n, "softrejectblock", json!([hash, 0]))?;
    let removed = chain_snapshot(&mut n, &f, &t)?;
    let stale = n.call("getblock", json!([hash, 1]))?;
    if n.call("getbestblockhash", json!([]))? != json!(base) || stale["confirmations"] != -1 {
        return Err("soft-rejection failed to remove active block".into());
    }
    let accepted = chain_operator_call(&mut n, "acceptblock", json!([hash]))?;
    let restored = chain_snapshot(&mut n, &f, &t)?;
    let active = n.call("getblock", json!([hash, 1]))?;
    if n.call("getbestblockhash", json!([]))? != json!(hash) || active["confirmations"] != 1 {
        return Err("acceptblock failed to restore active block".into());
    }
    let observed = json!({"removed":removed,"restored":restored,"operatorReceipts":rejected.is_null() && accepted.is_null()});
    let expected = json!({"removed":row["expected"]["removed"],"restored":row["expected"]["restored"],"operatorReceipts":true});
    n.stop()?;
    let mut result = measured(row, observed, expected,
        "Mine signed T in block 102, call softrejectblock with descendant span zero, observe stale body, base 101 and re-admitted T; call acceptblock with no span to clear the mark, then verify active block 102 and exact final coins/pools. Successful operator receipts are measured; the spec's internal causeRecorded event is not exposed and is retained separately.",
        std::mem::take(&mut n.calls), json!({"F":material(&f),"T":material(&t),"coinbase":material(&coinbase),"base":base,"block":hash,"initial":initial,"stale":stale,"active":active,"conf":n.conf}));
    result["declared_expected"] = row["expected"].clone();
    result["spec_only_fields"] = json!(["causeRecorded"]);
    Ok(result)
}

// [SRC] src/txmempool.cpp:1082-1084,1155-1168;
// src/rpc/blockchain.cpp:2617-2673; src/amount.cpp:28-42 at PIN.
fn mined_secondary_recipe(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_owned(root, text(&row["id"])?, "")?;
    let (f, _, base) = seed(&mut n)?;
    let t = spend(&f, 100000, 1);
    let u = spend(&t, 99900, 1);
    let fee = t.outputs[0].satoshis - u.outputs[0].satoshis;
    let parent_size = t.encode().len() as u64;
    let child_size = u.encode().len() as u64;
    if fee >= 500 * (parent_size + child_size) / 1000 || fee < 500 * child_size / 1000 {
        return Err("signed sizes do not realize the package/mining fee boundary".into());
    }
    n.call("sendrawtransaction", json!([hex::encode(t.encode())]))?;
    n.call("sendrawtransaction", json!([hex::encode(u.encode())]))?;
    let before_pool = n.call("getrawmempool", json!([true]))?;
    if before_pool.as_object().ok_or("pool object")?.len() != 2
        || before_pool[&id(&u)]["depends"] != json!([id(&t)])
        || before_pool[&id(&t)]["depends"] != json!([])
    {
        return Err("secondary setup pool/dependencies differ".into());
    }
    let before_info = chain_operator_call(&mut n, "getmempoolinfo", json!([]))?;
    let coinbase = cb(102, "mined-secondary");
    let (hash, reply) = n.submit(&[coinbase.clone(), t.clone()], 1_700_000_001)?;
    if block_judgment(&reply) != json!({"status":"ok"}) {
        return Err(format!("secondary parent block: {reply}"));
    }
    let body = n.call("getblock", json!([hash, 1]))?;
    if body["tx"] != json!([id(&coinbase), id(&t)])
        || body["confirmations"] != 1
        || n.call("getbestblockhash", json!([]))? != json!(hash)
    {
        return Err("secondary parent active body differs".into());
    }
    let after_pool = n.call("getrawmempool", json!([true]))?;
    let after_info = chain_operator_call(&mut n, "getmempoolinfo", json!([]))?;
    let only_child =
        after_pool.as_object().ok_or("pool object")?.len() == 1 && after_pool.get(id(&u)).is_some();
    let child_primary =
        only_child && after_info["journalsize"] == 1 && after_info["usagecpfp"] == 0;
    let depends = after_pool[&id(&u)]["depends"]
        .as_array()
        .ok_or("child dependencies")?;
    let observed = json!({"bothSecondaryBefore":before_info["size"] == 2
            && before_info["journalsize"] == 0 && before_info["usagecpfp"].as_u64().unwrap_or(0) > 0,
        "onlyChild":only_child,"childPrimary":child_primary,
        "ancestorCount":depends.len(),"secondaryAncestorCount":if depends.is_empty(){json!(0)}else{Value::Null}});
    let funding = n.call("gettxout", json!([id(&t), 0, false]))?;
    if funding.is_null()
        || !n.call("gettxout", json!([id(&u), 0, false]))?.is_null()
        || n.call("getrawnonfinalmempool", json!([]))? != json!([])
    {
        return Err("secondary final chain coins/held differ".into());
    }
    n.stop()?;
    let mut result = measured(row, observed, row["expected"].clone(),
        "Mine F at 101. Admit a zero-fee signed parent and its 100-satoshi-fee signed child. Actual serialized sizes satisfy package fee below 500 sat/kB and child fee at least 500 sat/kB. The exact two-entry pool, zero journal count and positive secondary usage witness both entries secondary. Mine only the parent in a verified active body; exact child-only pool, journal count one and zero secondary usage witness promotion. Empty direct dependencies in the complete one-entry pool derive zero ancestors and zero secondary ancestors. Symbolic transaction sizes are rematerialized while preserving both fee inequalities.",
        std::mem::take(&mut n.calls), json!({"F":material(&f),"T":material(&t),"U":material(&u),"coinbase":material(&coinbase),"base":base,"block":hash,"parent_size":parent_size,"child_size":child_size,"fee":fee,"before_pool":before_pool,"before_info":before_info,"after_pool":after_pool,"after_info":after_info,"funding":funding,"conf":n.conf}));
    result["observation_basis"] = json!("Exact isolated pool and journal counts determine membership; empty dependencies determine ancestor counts, not an unexposed internal counter read.");
    Ok(result)
}

// [SRC] src/validation.cpp:4413-4490,5578-5632;
// src/rpc/blockchain.cpp:93-156 at PIN. Failure flags are public header fields.
fn invalid_retry_recipe(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_owned(root, text(&row["id"])?, "")?;
    let (f, t, base) = seed(&mut n)?;
    let tip = n.tip()?;
    let bits = u32::from_str_radix(text(&tip["bits"])?, 16).map_err(|e| e.to_string())?;
    let mut holding = vec![];
    for h in 102..=104 {
        let (hash, reply) = n.submit(&[cb(h, "retry-holding")], 1_700_000_000 + h)?;
        if block_judgment(&reply) != json!({"status":"ok"}) {
            return Err(format!("holding branch: {reply}"));
        }
        holding.push(hash);
    }
    let mut bad_tx = t.clone();
    bad_tx.inputs[0].txid = [9; 32];
    bad_tx.inputs[0].vout = 0;
    let bad_cb = cb(102, "retry-bad");
    let (bad_header, bad_bytes) = block_codec::assemble(
        4,
        txid_from_display_hex(&base)?,
        1_700_000_001,
        bits,
        &[bad_cb.clone(), bad_tx.clone()],
    );
    let bad = txid_display_hex(&bad_header.hash());
    let child_cb = cb(103, "retry-child");
    let (child_header, child_bytes) = block_codec::assemble(
        4,
        bad_header.hash(),
        1_700_000_002,
        bits,
        std::slice::from_ref(&child_cb),
    );
    let child = txid_display_hex(&child_header.hash());
    let good_cb = cb(102, "retry-good");
    let (good_header, good_bytes) = block_codec::assemble(
        4,
        txid_from_display_hex(&base)?,
        1_700_000_003,
        bits,
        &[good_cb.clone(), t.clone()],
    );
    let good = txid_display_hex(&good_header.hash());
    let mut before = vec![];
    for (hash, bytes) in [
        (&bad, &bad_bytes),
        (&child, &child_bytes),
        (&good, &good_bytes),
    ] {
        let reply = n.receipt("submitblock", json!([hex::encode(bytes)]))?;
        if reply != json!({"result":"inconclusive"}) {
            return Err(format!("retry stored candidate: {reply}"));
        }
        if n.call("getblock", json!([hash, 0]))? != json!(hex::encode(bytes)) {
            return Err("retry candidate bytes differ".into());
        }
        let body = n.call("getblock", json!([hash, 1]))?;
        if body["status"]["failed"] != false
            || body["status"]["parent failed"] != false
            || body["confirmations"] != -1
        {
            return Err("candidate was already rejected or active".into());
        }
        before.push(body);
    }
    if n.call("getbestblockhash", json!([]))? != json!(holding[2]) {
        return Err("holding tip changed before retry".into());
    }
    n.call("invalidateblock", json!([holding[0]]))?;
    let bad_after = n.call("getblock", json!([bad, 1]))?;
    let child_after = n.call("getblock", json!([child, 1]))?;
    let good_after = n.call("getblock", json!([good, 1]))?;
    if good_after["tx"] != json!([id(&good_cb), id(&t)])
        || good_after["confirmations"] != 1
        || bad_after["confirmations"] != -1
        || child_after["confirmations"] != -1
    {
        return Err("retry final bodies differ".into());
    }
    let view = chain_snapshot(&mut n, &f, &t)?;
    let observed = json!({"selectedGood":n.call("getbestblockhash",json!([]))? == json!(good),
        "badFailed":bad_after["status"]["failed"],"childFailedParent":child_after["status"]["parent failed"],
        "childNotFailedSelf":child_after["status"]["failed"] == false,"view":view});
    n.stop()?;
    Ok(measured(row,observed,row["expected"].clone(),
        "Retain a height-104 holding branch above the common funded base 101. Store a missing-input candidate at 102, its child at 103, and signed valid competitor at 102, checking exact bodies and no failure flags while all are inactive. Invalidate holding block 102; selection tries the higher-work invalid ancestry then retries the valid candidate. Read the exposed failed and parent-failed header status fields independently, selected active body, coins and exact pools.",
        std::mem::take(&mut n.calls),json!({"F":material(&f),"T":material(&t),"bad_tx":material(&bad_tx),"base":base,"holding":holding,"bad":bad,"child":child,"good":good,"before":before,"bad_after":bad_after,"child_after":child_after,"good_after":good_after,"conf":n.conf})))
}

// [SRC] src/validation.cpp:5156-5190; src/rpc/blockchain.cpp:2695-2731 at PIN.
fn precious_recipe(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_owned(
        root,
        text(&row["id"])?,
        "listen=1\nbind=127.0.0.1:{P2P_PORT}\n",
    )?;
    let (f, t, base) = seed(&mut n)?;
    let k = spend(&f, 98000, 2);
    let bits = u32::from_str_radix(text(&n.tip()?["bits"])?, 16).map_err(|e| e.to_string())?;
    let a_cb = cb(102, "precious-a");
    let (a, reply) = n.submit(&[a_cb.clone(), t.clone()], 1_700_000_001)?;
    if block_judgment(&reply) != json!({"status":"ok"}) {
        return Err(format!("precious A: {reply}"));
    }
    let b_cb = cb(102, "precious-b");
    let (b_header, b_bytes) = block_codec::assemble(
        4,
        txid_from_display_hex(&base)?,
        1_700_000_002,
        bits,
        &[b_cb.clone(), k.clone()],
    );
    let b = txid_display_hex(&b_header.hash());
    let mut peer = super::peer::Peer::start(&mut n)?;
    let header_only = peer.header(&mut n, &b_bytes, &b)?;
    let header_receipt = chain_operator_call(&mut n, "preciousblock", json!([b]))?;
    let header_stayed_inactive = n.call("getbestblockhash", json!([]))? == json!(a);
    let header_view = chain_snapshot(&mut n, &f, &t)?;
    if header_view != json!({"height":102,"coins":["T"],"pool":[],"held":[]}) {
        return Err("precious header changed coins/pools".into());
    }
    let body_reply = n.receipt("submitblock", json!([hex::encode(&b_bytes)]))?;
    if body_reply.get("error").is_some() {
        return Err(format!("precious body: {body_reply}"));
    }
    let body_receipt = chain_operator_call(&mut n, "preciousblock", json!([b]))?;
    let selected_b = n.call("getbestblockhash", json!([]))? == json!(b);
    let active = n.call("getblock", json!([b, 1]))?;
    let stale = n.call("getblock", json!([a, 1]))?;
    if n.call("getblock", json!([b, 0]))? != json!(hex::encode(&b_bytes))
        || active["tx"] != json!([id(&b_cb), id(&k)])
        || active["confirmations"] != 1
        || stale["confirmations"] != -1
        || active["chainwork"] != stale["chainwork"]
        || !n.call("gettxout", json!([id(&f), 0, false]))?.is_null()
        || !n.call("gettxout", json!([id(&t), 0, false]))?.is_null()
        || n.call("gettxout", json!([id(&k), 0, false]))?.is_null()
        || n.call("getrawmempool", json!([]))? != json!([])
        || n.call("getrawnonfinalmempool", json!([]))? != json!([])
    {
        return Err("precious final active/stale coin/pool evidence differs".into());
    }
    let observed = json!({"headerStayedInactive":header_stayed_inactive,"selectedB":selected_b,
        "operatorReceipts":header_receipt.is_null() && body_receipt.is_null()});
    let expected = json!({"headerStayedInactive":row["expected"]["headerExcluded"],"selectedB":row["expected"]["selectedB"],"operatorReceipts":true});
    peer.close()?;
    let peer_receipt = peer.receipt(&n);
    n.stop()?;
    let mut result=measured(row,observed,expected,
        "Mine A spending F at 102, deliver only rival B's header over the pinned reference loopback peer and prove its data flag false. preciousblock on that header leaves A, its coins and empty pools unchanged. Submit B's signed conflicting body, call preciousblock again, then verify B active, A stale, equal chainwork and exact coins/pools. Candidate-set membership and the internal activation result are not exposed; the projection compares non-activation of the header, final selection and synchronous operator receipts.",
        std::mem::take(&mut n.calls),json!({"F":material(&f),"T":material(&t),"K":material(&k),"base":base,"A":a,"B":b,"header_only":header_only,"header_view":header_view,"active":active,"stale":stale,"conf":n.conf}));
    result["declared_expected"] = row["expected"].clone();
    result["spec_only_fields"] = json!([
        "headerExcluded (internal candidate membership)",
        "complete (internal activation result)"
    ]);
    result["peer"] = peer_receipt;
    Ok(result)
}

// (S3, lane pend-66, Claude Opus 5.5, [M] 2026-10-13) The pending rows that
// the instance realizes through RPC, startup settings, its own lifecycle and
// the pinned reference peer. Each recipe names its pinned sources.
fn chain_bits(n: &mut Node) -> Result<u32> {
    u32::from_str_radix(text(&n.tip()?["bits"])?, 16).map_err(|e| e.to_string())
}

fn header_status(n: &mut Node, hash: &str) -> Result<Value> {
    chain_operator_call(n, "getblockheader", json!([hash, true]))
}

fn console_from(n: &Node, offset: usize) -> Result<String> {
    let log = fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
    Ok(log.get(offset..).unwrap_or("").to_owned())
}

fn console_len(n: &Node) -> Result<usize> {
    Ok(fs::read_to_string(n.dir.join("console.log"))
        .map_err(|e| e.to_string())?
        .len())
}

// [SRC] src/validation.cpp:4087-4090 (DisconnectTip refuses any result but
// DISCONNECT_OK); src/processing_block_index.cpp:16-18,57-60,85-88 and
// src/block_index.cpp:181-191 log the four DISCONNECT_FAILED paths; an
// unclean result logs none of them at 6504a3af.
fn disconnect_status(log: &str) -> &'static str {
    let failed = [
        "block and undo data inconsistent",
        "transaction and undo data inconsistent",
        "no undo data available",
        "failure reading undo data",
    ];
    if !log.contains("DisconnectTip(): DisconnectBlock") {
        "BsvChain.DisconnectResult.ok"
    } else if failed.iter().any(|line| log.contains(line)) {
        "BsvChain.DisconnectResult.failed"
    } else {
        "BsvChain.DisconnectResult.unclean"
    }
}

fn failure_lines(log: &str) -> Vec<String> {
    log.lines()
        .filter(|l| {
            l.contains("DisconnectBlock") || l.contains("undo data") || l.contains("frozen")
        })
        .map(str::to_owned)
        .collect()
}

// seed() with the generated block hashes retained.
fn seed_kept(n: &mut Node) -> Result<(RawTx, RawTx, String, Vec<String>)> {
    let mut hashes = vec![];
    for h in 1..=100 {
        for hash in n.mine(1, 1_699_990_000 + h)? {
            hashes.push(text(&hash)?.to_owned());
        }
    }
    let b = n.call("getblock", json!([hashes[0], 1]))?;
    let coin = n.raw_tx(&b["tx"][0])?;
    let f = spend(&coin, 100000, 1);
    let (hash, receipt) = n.submit(&[cb(101, "base"), f.clone()], 1_699_999_999)?;
    if block_judgment(&receipt) != json!({"status":"ok"}) {
        return Err(format!("funding block: {receipt}"));
    }
    let t = spend(&f, 99000, 1);
    Ok((f, t, hash, hashes))
}

fn stored(n: &mut Node, bytes: &[u8], hash: &str) -> Result<Value> {
    let reply = n.receipt("submitblock", json!([hex::encode(bytes)]))?;
    if reply.get("error").is_some() {
        return Err(format!("store {hash}: {reply}"));
    }
    if n.call("getblock", json!([hash, 0]))? != json!(hex::encode(bytes)) {
        return Err(format!("stored bytes differ for {hash}"));
    }
    Ok(reply)
}

// [SRC] src/block_index.h:1225-1261 (work, then validation completion, then
// sequence id); src/validation.cpp:5692-5717 (sequence ids in body receipt
// order), 5230-5303 (invalidation re-adds candidates) at 6504a3af.
// Neither candidate is validated before selection, so both completion times
// are SteadyClockTimePoint::max (src/block_index.h:954) and equal.
fn equal_work_sequence_recipe(root: &Path, row: &Value) -> Result<Value> {
    let (observed, fixtures, calls) = equal_work_sequence_run(root, text(&row["id"])?, true)?;
    let (control, control_fixtures, control_calls) =
        equal_work_sequence_run(root, &format!("{}-control", text(&row["id"])?), false)?;
    if control["selected"] != "A" {
        return Err(format!(
            "sequence control: storing A before B did not select A: {control}"
        ));
    }
    let mut fixtures = fixtures;
    fixtures["control"] = json!({"order":"A then B","observed":control,"fixtures":control_fixtures,"rpc":control_calls});
    let mut result = measured(row, observed, row["expected"].clone(),
        "Mine base 101 and a holding branch to 103. Store equal-work rival bodies B then A on base by submitblock, so B's sequence id is lower; neither is validated (validity below scripts, completion unset and equal). Invalidate holding block 102; the re-added candidates tie on work and completion and the comparator falls to sequence. Read the selected tip and both chainworks. A control instance stores A then B and selects A.",
        calls, fixtures);
    result["declared_expected"] = row["expected"].clone();
    result["observation_basis"] = json!("Completion times and sequence ids are not exposed by RPC; they are fixed by construction (receipt order and the validity field) and cited; the flipped-order control shows the selection follows receipt order.");
    Ok(result)
}

fn equal_work_sequence_run(
    root: &Path,
    name: &str,
    b_before: bool,
) -> Result<(Value, Value, Vec<Value>)> {
    let mut n = start_owned(root, name, "")?;
    n.mine(101, 1_699_990_000)?;
    let base = text(&n.call("getbestblockhash", json!([]))?)?.to_owned();
    let mut holding = vec![];
    for h in 102..=103 {
        let (hash, reply) = n.submit(&[cb(h, "sequence-holding")], 1_700_000_000 + h)?;
        if block_judgment(&reply) != json!({"status":"ok"}) {
            return Err(format!("sequence holding: {reply}"));
        }
        holding.push(hash);
    }
    let bits = chain_bits(&mut n)?;
    let parent = txid_from_display_hex(&base)?;
    let (bh, b_bytes) =
        block_codec::assemble(4, parent, 1_700_000_010, bits, &[cb(102, "sequence-b")]);
    let (ah, a_bytes) =
        block_codec::assemble(4, parent, 1_700_000_011, bits, &[cb(102, "sequence-a")]);
    let (a, b) = (txid_display_hex(&ah.hash()), txid_display_hex(&bh.hash()));
    let replies = if b_before {
        [stored(&mut n, &b_bytes, &b)?, stored(&mut n, &a_bytes, &a)?]
    } else {
        [stored(&mut n, &a_bytes, &a)?, stored(&mut n, &b_bytes, &b)?]
    };
    let before = [header_status(&mut n, &a)?, header_status(&mut n, &b)?];
    for h in &before {
        if h["confirmations"] != -1
            || h["status"]["validity"] == "scripts"
            || h["status"]["failed"] != false
        {
            return Err(format!(
                "sequence candidate validated or active before selection: {h}"
            ));
        }
    }
    let invalidation = n.call("invalidateblock", json!([holding[0]]))?;
    let tip = n.call("getbestblockhash", json!([]))?;
    let after = [header_status(&mut n, &a)?, header_status(&mut n, &b)?];
    let selected = if tip == json!(b) {
        "B"
    } else if tip == json!(a) {
        "A"
    } else {
        "other"
    };
    let observed =
        json!({"selected":selected,"equalWork":after[0]["chainwork"] == after[1]["chainwork"]});
    n.call("getchaintips", json!([]))?;
    n.stop()?;
    let fixtures = json!({"base":base,"holding":holding,"A":a,"B":b,"store_replies":replies,"before":before,"after":after,"invalidation":invalidation,"conf":n.conf});
    Ok((observed, fixtures, std::mem::take(&mut n.calls)))
}

// [SRC] src/disk_block_index.h:44-48 (a block loaded at SCRIPTS validity has
// completion SteadyClockTimePoint::min); src/validation.cpp:6670-6688 (the
// load assigns no sequence id) with src/block_index.h:373-375 (the memory-only
// sequence id initialized to 0); src/block_index.h:1072-1077 (completion set when
// a block reaches SCRIPTS), 1225-1261; src/validation.cpp:5228-5330,
// 5528-5562 at 6504a3af. Restart precedent: test/functional/
// soft_consensus_freeze_base.py restart_node at the pin.
fn equal_work_completion_recipe(root: &Path, row: &Value) -> Result<Value> {
    let (observed, fixtures, calls) = equal_work_completion_run(root, text(&row["id"])?, true)?;
    let (control, control_fixtures, control_calls) =
        equal_work_completion_run(root, &format!("{}-control", text(&row["id"])?), false)?;
    if control["selected"] != "A" {
        return Err(format!(
            "completion control: A completing before the restart did not select A: {control}"
        ));
    }
    let mut fixtures = fixtures;
    fixtures["control"] =
        json!({"earlier":"A","observed":control,"fixtures":control_fixtures,"rpc":control_calls});
    let mut result = measured(row, observed, row["expected"].clone(),
        "Mine base 101; B connects at 102 and equal-work A is stored. Restart the instance on its own datadir: both load with sequence id 0, B (validity scripts) with completion min, A unvalidated. Invalidate B so A connects and completes now; reconsider B. Both are completed, B earlier, sequences equal. Read the selected tip and both chainworks. A control instance with the roles swapped selects A.",
        calls, fixtures);
    result["declared_expected"] = row["expected"].clone();
    result["observation_basis"] = json!("Completion times and sequence ids are not exposed by RPC; the restart sets both sequence ids to 0 and the earlier block's completion to min, the later block's completion is set at its connection after the restart (validity field read before and after), all cited; the swapped control shows the selection follows completion.");
    Ok(result)
}

fn equal_work_completion_run(
    root: &Path,
    name: &str,
    b_earlier: bool,
) -> Result<(Value, Value, Vec<Value>)> {
    let mut n = start_owned(root, name, "")?;
    n.mine(101, 1_699_990_000)?;
    let base = text(&n.call("getbestblockhash", json!([]))?)?.to_owned();
    let bits = chain_bits(&mut n)?;
    let parent = txid_from_display_hex(&base)?;
    let (bh, b_bytes) =
        block_codec::assemble(4, parent, 1_700_000_010, bits, &[cb(102, "completion-b")]);
    let (ah, a_bytes) =
        block_codec::assemble(4, parent, 1_700_000_011, bits, &[cb(102, "completion-a")]);
    let (a, b) = (txid_display_hex(&ah.hash()), txid_display_hex(&bh.hash()));
    let (earlier, later) = if b_earlier {
        (b.clone(), a.clone())
    } else {
        (a.clone(), b.clone())
    };
    n.call("setmocktime", json!([1_700_000_100]))?;
    let replies = if b_earlier {
        [stored(&mut n, &b_bytes, &b)?, stored(&mut n, &a_bytes, &a)?]
    } else {
        [stored(&mut n, &a_bytes, &a)?, stored(&mut n, &b_bytes, &b)?]
    };
    if n.call("getbestblockhash", json!([]))? != json!(earlier) {
        return Err("completion: the earlier block did not connect before the later one".into());
    }
    n.restart()?;
    n.call("setmocktime", json!([1_700_000_100]))?;
    let loaded = [
        header_status(&mut n, &earlier)?,
        header_status(&mut n, &later)?,
    ];
    if n.call("getbestblockhash", json!([]))? != json!(earlier)
        || loaded[0]["status"]["validity"] != "scripts"
        || loaded[1]["status"]["validity"] == "scripts"
    {
        return Err(format!("completion: loaded state differs: {loaded:?}"));
    }
    n.call("invalidateblock", json!([earlier]))?;
    let later_connected = header_status(&mut n, &later)?;
    if n.call("getbestblockhash", json!([]))? != json!(later)
        || later_connected["status"]["validity"] != "scripts"
    {
        return Err(format!(
            "completion: the later block did not connect after the restart: {later_connected}"
        ));
    }
    let reconsider = n.call("reconsiderblock", json!([earlier]))?;
    let tip = n.call("getbestblockhash", json!([]))?;
    let after = [header_status(&mut n, &a)?, header_status(&mut n, &b)?];
    let selected = if tip == json!(b) {
        "B"
    } else if tip == json!(a) {
        "A"
    } else {
        "other"
    };
    let observed =
        json!({"selected":selected,"equalWork":after[0]["chainwork"] == after[1]["chainwork"]});
    n.call("getchaintips", json!([]))?;
    n.stop()?;
    let fixtures = json!({"base":base,"A":a,"B":b,"earlier":earlier,"store_replies":replies,"loaded":loaded,"later_connected":later_connected,"reconsider":reconsider,"after":after,"conf":n.conf});
    Ok((observed, fixtures, std::mem::take(&mut n.calls)))
}

// [SRC] src/validation.cpp:5692-5723 (a body whose parent lacks data waits in
// mapBlocksUnlinked; the parent's body links its queued children in insertion
// order, assigning sequence ids), src/block_index.h:1225-1261 at 6504a3af.
fn receipt_order_recipe(root: &Path, row: &Value) -> Result<Value> {
    let (observed, fixtures, calls) = receipt_order_run(root, text(&row["id"])?, true)?;
    let (control, control_fixtures, control_calls) =
        receipt_order_run(root, &format!("{}-control", text(&row["id"])?), false)?;
    if control["selectedB"] != false || control["equalWork"] != true {
        return Err(format!(
            "receipt-order control: bodies A then B did not select A: {control}"
        ));
    }
    let mut fixtures = fixtures;
    fixtures["control"] = json!({"bodies":"A then B","observed":control,"fixtures":control_fixtures,"rpc":control_calls});
    let expected =
        json!({"selectedB":row["expected"]["selectedB"],"equalWork":row["expected"]["equalWork"]});
    let mut result = measured(row, observed, expected,
        "Mine base 101. Over the pinned reference loopback peer deliver headers P, A then B (A and B equal-work children of P), each proved stored without data. Submit bodies B then A; both wait behind body-less P with the tip unchanged. Submit P's body; linkage assigns sequence ids in body order (B before A). Read the selected tip and both chainworks. A control instance with the same headers and bodies A then B selects A.",
        calls, fixtures);
    result["declared_expected"] = row["expected"].clone();
    result["spec_only_fields"] = json!(["bodyOrderWins (internal sequence ids)"]);
    result["peer"] = result["fixtures"]["peer"].clone();
    Ok(result)
}

fn receipt_order_run(
    root: &Path,
    name: &str,
    b_before: bool,
) -> Result<(Value, Value, Vec<Value>)> {
    let mut n = start_owned(root, name, "listen=1\nbind=127.0.0.1:{P2P_PORT}\n")?;
    n.mine(101, 1_699_990_000)?;
    let base = text(&n.call("getbestblockhash", json!([]))?)?.to_owned();
    let bits = chain_bits(&mut n)?;
    let (ph, p_bytes) = block_codec::assemble(
        4,
        txid_from_display_hex(&base)?,
        1_700_000_010,
        bits,
        &[cb(102, "receipt-p")],
    );
    let (ah, a_bytes) =
        block_codec::assemble(4, ph.hash(), 1_700_000_011, bits, &[cb(103, "receipt-a")]);
    let (bh, b_bytes) =
        block_codec::assemble(4, ph.hash(), 1_700_000_012, bits, &[cb(103, "receipt-b")]);
    let (p, a, b) = (
        txid_display_hex(&ph.hash()),
        txid_display_hex(&ah.hash()),
        txid_display_hex(&bh.hash()),
    );
    n.call("setmocktime", json!([1_700_000_100]))?;
    let mut peer = super::peer::Peer::start(&mut n)?;
    let headers = [
        peer.header(&mut n, &p_bytes, &p)?,
        peer.header(&mut n, &a_bytes, &a)?,
        peer.header(&mut n, &b_bytes, &b)?,
    ];
    let order: [(&str, &[u8]); 2] = if b_before {
        [("B", &b_bytes), ("A", &a_bytes)]
    } else {
        [("A", &a_bytes), ("B", &b_bytes)]
    };
    let mut replies = BTreeMap::new();
    for (label, bytes) in order {
        replies.insert(
            label.to_owned(),
            n.receipt("submitblock", json!([hex::encode(bytes)]))?,
        );
    }
    let waiting = [
        header_status(&mut n, &a)?,
        header_status(&mut n, &b)?,
        header_status(&mut n, &p)?,
    ];
    if n.call("getbestblockhash", json!([]))? != json!(base)
        || waiting[0]["status"]["data"] != true
        || waiting[1]["status"]["data"] != true
        || waiting[2]["status"]["data"] != false
    {
        return Err(format!(
            "receipt-order: bodies did not wait behind P: {waiting:?}"
        ));
    }
    replies.insert(
        "P".to_owned(),
        n.receipt("submitblock", json!([hex::encode(&p_bytes)]))?,
    );
    let tip = n.call("getbestblockhash", json!([]))?;
    let after = [header_status(&mut n, &a)?, header_status(&mut n, &b)?];
    peer.close()?;
    let peer_receipt = peer.receipt(&n);
    let observed = json!({"selectedB":tip == json!(b),"equalWork":after[0]["chainwork"] == after[1]["chainwork"]});
    n.call("getchaintips", json!([]))?;
    n.stop()?;
    let fixtures = json!({"base":base,"P":p,"A":a,"B":b,"headers":headers,"replies":replies,"waiting":waiting,"after":after,"peer":peer_receipt,"conf":n.conf});
    Ok((observed, fixtures, std::mem::take(&mut n.calls)))
}

// [SRC] src/validation.cpp:4413-4494 (a candidate whose path crosses a block
// without data is removed with its chain and queued in mapBlocksUnlinked),
// 5228-5330, 5662-5725 (re-receipt links queued descendants);
// src/rpc/blockchain.cpp:1810-1875 (pruneblockchain);
// src/blockfileinfostore.cpp:21-39,177-206 (an empty file always takes the
// next block; manual pruning removes files whose last height is at most the
// prune height); src/init.cpp:2143-2148,2473-2475,2815-2826,2841 (prune=1 with
// txindex warns only; preferredblockfilesize; pruneminblockstokeep);
// src/chainparams.cpp:1509 (regtest prunes after height 1000) at 6504a3af.
fn missing_body_recipe(root: &Path, row: &Value) -> Result<Value> {
    let returning = row["case"] == "body-return";
    let mut n = start_owned(
        root,
        text(&row["id"])?,
        "prune=1\npruneminblockstokeep=6\npreferredblockfilesize=524288\n",
    )?;
    for k in 0..10 {
        n.mine(100, 1_699_000_000 + k * 1_000)?;
    }
    let base = text(&n.call("getbestblockhash", json!([]))?)?.to_owned();
    let base_header = header_status(&mut n, &base)?;
    if base_header["height"] != 1000 {
        return Err("missing-body: base height differs".into());
    }
    let mut main = vec![];
    for hash in n.mine(3, 1_699_010_000)? {
        main.push(text(&hash)?.to_owned());
    }
    let bits = chain_bits(&mut n)?;
    let time = base_header["time"].as_u64().ok_or("base time")? as u32 + 1;
    let filler = [vec![0x6a], vec![0u8; 530_000]].concat();
    let a_cb = block_codec::coinbase_tx(1001, 0, filler, b"missing-body-a");
    let (ah, a_bytes) =
        block_codec::assemble(4, txid_from_display_hex(&base)?, time, bits, &[a_cb]);
    let (bh, b_bytes) =
        block_codec::assemble(4, ah.hash(), time + 1, bits, &[cb(1002, "missing-body-b")]);
    let (a, b) = (txid_display_hex(&ah.hash()), txid_display_hex(&bh.hash()));
    let a_reply = stored(&mut n, &a_bytes, &a)?;
    let b_reply = stored(&mut n, &b_bytes, &b)?;
    for hash in n.mine(7, 1_699_011_000)? {
        main.push(text(&hash)?.to_owned());
    }
    let files_before = block_files(&n)?;
    let pruned = chain_operator_call(&mut n, "pruneblockchain", json!([1001]))?;
    let files_after = block_files(&n)?;
    let pruned_view = [
        header_status(&mut n, &a)?,
        header_status(&mut n, &b)?,
        header_status(&mut n, &main[0])?,
    ];
    if pruned_view[0]["status"]["data"] != false
        || pruned_view[1]["status"]["data"] != true
        || pruned_view[2]["status"]["data"] != true
    {
        return Err(format!(
            "missing-body: pruning did not isolate A's body: {pruned_view:?}"
        ));
    }
    n.call("invalidateblock", json!([main[0]]))?;
    let tip = n.call("getbestblockhash", json!([]))?;
    let missing = [
        header_status(&mut n, &a)?,
        header_status(&mut n, &b)?,
        header_status(&mut n, &base)?,
    ];
    if missing[1]["status"]["failed"] != false
        || missing[1]["status"]["parent failed"] != false
        || missing[0]["status"]["failed"] != false
    {
        return Err(format!("missing-body: rival marked invalid: {missing:?}"));
    }
    let tips = n.call("getchaintips", json!([]))?;
    let mut fixtures = json!({"base":base,"main":main,"A":a,"B":b,"A_size":a_bytes.len(),"store_replies":[a_reply,b_reply],
        "files_before":files_before,"pruned_height":pruned,"files_after":files_after,"pruned_view":pruned_view,"missing":missing,"tips":tips,"conf":n.conf});
    let (observed, expected, spec_only, recipe) = if !returning {
        (json!({"selectedBase":tip == json!(base)}),
         json!({"selectedBase":row["expected"]["selectedBase"]}),
         json!(["removedA","removedB","unlinkedB (internal candidate and unlinked sets)"]),
         "Mine base 1000 and main 1001..1003 into one block file. Store rival A (a 530 kB coinbase filler, so it occupies its own file under preferredblockfilesize 524288) and its child B on base, then main to 1010. pruneblockchain(1001) removes only A's file: A data false, B and main data true. Invalidate main 1001; the re-added rival B (more work than base, valid, with its body) crosses body-less A. Read the selected tip.")
    } else {
        let a_again = n.receipt("submitblock", json!([hex::encode(&a_bytes)]))?;
        let tip = n.call("getbestblockhash", json!([]))?;
        let restored = [header_status(&mut n, &a)?, header_status(&mut n, &b)?];
        fixtures["resubmitted_A"] = a_again;
        fixtures["restored"] = json!(restored);
        (json!({"selectedB":tip == json!(b)}),
         json!({"selectedB":row["expected"]["selectedB"]}),
         json!(["restoredA","restoredB","unlinkedEmpty (internal candidate and unlinked sets)"]),
         "As chain-missing-body-ancestry: rival B waits behind pruned A after main 1001 is invalidated. Resubmit only A's body; its positive chain-transaction count survived pruning, its receipt links the queued B. Read the selected tip; B was never resubmitted.")
    };
    n.stop()?;
    let mut result = measured(
        row,
        observed,
        expected,
        recipe,
        std::mem::take(&mut n.calls),
        fixtures,
    );
    result["declared_expected"] = row["expected"].clone();
    result["spec_only_fields"] = spec_only;
    Ok(result)
}

fn block_files(n: &Node) -> Result<Value> {
    let mut files = BTreeMap::new();
    for entry in fs::read_dir(n.dir.join("regtest/blocks")).map_err(|e| e.to_string())? {
        let entry = entry.map_err(|e| e.to_string())?;
        let name = entry.file_name().to_string_lossy().into_owned();
        if name.ends_with(".dat") {
            files.insert(name, entry.metadata().map_err(|e| e.to_string())?.len());
        }
    }
    Ok(json!(files))
}

// A duplicate coinbase (BIP30 checks disabled, network-permitted on regtest)
// leaves a connected output absent when its earlier block disconnects:
// [SRC] src/validation.cpp:3097-3100 (-disablebip30checks; the historical
// exceptions at 3070-3078 are a different switch), 4087-4090;
// src/config.cpp:2051-2067 (permitted only where the network allows it);
// src/coins.cpp:560-565 (a coinbase's outputs are always added with
// possible_overwrite, so B's copy replaces A's coin); src/undo.h:109-112 (undo
// is kept for all but the coinbase) and src/processing_block_index.cpp:50-53
// (the coinbase's inputs are skipped), so no undo restores A's overwritten
// output; src/processing_block_index.cpp:36-48,76 at 6504a3af.
fn duplicate_pair(n: &mut Node, t: &RawTx, tag: &str) -> Result<(RawTx, String, String)> {
    let c = cb(102, tag);
    let (a, a_reply) = n.submit(std::slice::from_ref(&c), 1_700_000_001)?;
    let (b, b_reply) = n.submit(&[c.clone(), t.clone()], 1_700_000_002)?;
    if block_judgment(&a_reply) != json!({"status":"ok"})
        || block_judgment(&b_reply) != json!({"status":"ok"})
    {
        return Err(format!("duplicate pair: {a_reply} {b_reply}"));
    }
    let coin = n.call("gettxout", json!([id(&c), 0, false]))?;
    if coin["confirmations"] != 1 || n.call("getbestblockhash", json!([]))? != json!(b) {
        return Err(format!("duplicate coinbase did not overwrite: {coin}"));
    }
    Ok((c, a, b))
}

fn missing_output_recipe(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_owned(root, text(&row["id"])?, "disablebip30checks=1\n")?;
    let (f, t, base) = seed(&mut n)?;
    let (c, a, b) = duplicate_pair(&mut n, &t, "missing-output")?;
    n.call("invalidateblock", json!([b]))?;
    let between = n.call("gettxout", json!([id(&c), 0, false]))?;
    if n.call("getbestblockhash", json!([]))? != json!(a) || !between.is_null() {
        return Err(format!(
            "missing-output: B's disconnect did not remove the shared output: {between}"
        ));
    }
    let offset = console_len(&n)?;
    let invalidation = n.receipt("invalidateblock", json!([a]))?;
    let tip = n.call("getbestblockhash", json!([]))?;
    let funding = n.call("gettxout", json!([id(&f), 0, false]))?;
    let log = console_from(&n, offset)?;
    let observed = json!({"status":disconnect_status(&log),"published":tip != json!(a)});
    let expected =
        json!({"status":row["expected"]["status"],"published":row["expected"]["published"]});
    let view = chain_snapshot(&mut n, &f, &t)?;
    n.stop()?;
    let mut result = measured(row, observed, expected,
        "With -disablebip30checks, block A at 102 holds coinbase C and block B at 103 repeats C byte for byte with T, overwriting C's output. Invalidate B (clean: C's output removed). Invalidate A: C's output is now absent from the view before A's undo, ApplyBlockUndo returns unclean and DisconnectTip refuses it. Status is read from the failure log (no DISCONNECT_FAILED path line); publication from the unmoved tip. The symbolic missing T output is rematerialized as the duplicate coinbase's output.",
        std::mem::take(&mut n.calls), json!({"F":material(&f),"T":material(&t),"C":material(&c),"base":base,"A":a,"B":b,"invalidation":invalidation,"funding":funding,"failure_log":failure_lines(&log),"view":view,"conf":n.conf}));
    result["declared_expected"] = row["expected"].clone();
    result["spec_only_fields"] = json!(["restoresInitial (the discarded disconnect result view)"]);
    Ok(result)
}

// (S3, lane fix-pend2, Claude Opus 5.5, [M] 2026-10-13) The instance's own
// undo records, read and edited only while it is stopped. Layout at the pin:
// each record is the network's disk magic, a 4-byte size (0xffffffff then an
// 8-byte size above 32 bits), the serialized CBlockUndo, then the double
// SHA-256 of the parent hash followed by the record (src/block_file_access.cpp:
// 104-120,207-245); the index keeps the record's payload offset and
// GetBlockUndo reads it back under that checksum, returning no undo on an
// unopenable file, a short read or a mismatch (src/block_index.cpp:174-194;
// src/block_file_access.cpp:300-335). A record is located by its checksum
// against the block's parent, never by a guessed offset.
struct UndoRecord {
    file: PathBuf,
    header: usize,
    payload_at: usize,
    payload: Vec<u8>,
    end: usize,
}

fn undo_checksum(parent: &[u8; 32], payload: &[u8]) -> [u8; 32] {
    bsv_rs::primitives::hash::sha256d(&[&parent[..], payload].concat())
}

fn undo_record_at(bytes: &[u8], file: &Path, header: usize) -> Option<(UndoRecord, [u8; 32])> {
    if header + 8 > bytes.len() || bytes[header..header + 4] == [0; 4] {
        return None;
    }
    let mut size = u32::from_le_bytes(bytes[header + 4..header + 8].try_into().ok()?) as u64;
    let mut payload_at = header + 8;
    if size == u32::MAX as u64 {
        size = u64::from_le_bytes(bytes.get(payload_at..payload_at + 8)?.try_into().ok()?);
        payload_at += 8;
    }
    let end = payload_at.checked_add(size as usize)?.checked_add(32)?;
    let payload = bytes.get(payload_at..end - 32)?.to_vec();
    let checksum: [u8; 32] = bytes[end - 32..end].try_into().ok()?;
    Some((
        UndoRecord {
            file: file.to_owned(),
            header,
            payload_at,
            payload,
            end,
        },
        checksum,
    ))
}

// Every record of every rev file, with its checksum.
fn undo_records(dir: &Path) -> Result<Vec<(UndoRecord, [u8; 32])>> {
    let blocks = dir.join("regtest/blocks");
    let mut names: Vec<_> = fs::read_dir(&blocks)
        .map_err(|e| e.to_string())?
        .filter_map(|e| e.ok().map(|e| e.file_name().to_string_lossy().into_owned()))
        .filter(|n| n.starts_with("rev") && n.ends_with(".dat"))
        .collect();
    names.sort();
    let mut out = vec![];
    for name in names {
        let file = blocks.join(&name);
        let bytes = fs::read(&file).map_err(|e| e.to_string())?;
        let mut at = 0;
        while let Some((record, checksum)) = undo_record_at(&bytes, &file, at) {
            at = record.end;
            out.push((record, checksum));
        }
    }
    Ok(out)
}

// The one record whose checksum holds against `parent` (display hex).
fn undo_record_of(dir: &Path, parent: &str) -> Result<(UndoRecord, bool)> {
    let parent = txid_from_display_hex(parent)?;
    let records = undo_records(dir)?;
    let mut found: Vec<_> = records
        .into_iter()
        .enumerate()
        .filter(|(_, (r, sum))| undo_checksum(&parent, &r.payload) == *sum)
        .collect();
    if found.len() != 1 {
        return Err(format!("undo record by parent: {} matches", found.len()));
    }
    let (index, (record, _)) = found.remove(0);
    let last_in_file = undo_records(dir)?
        .iter()
        .skip(index + 1)
        .all(|(r, _)| r.file != record.file);
    Ok((record, last_in_file))
}

fn write_undo_record(record: &UndoRecord, parent: &str, payload: &[u8]) -> Result<Value> {
    let parent_hash = txid_from_display_hex(parent)?;
    let mut bytes = fs::read(&record.file).map_err(|e| e.to_string())?;
    let size = payload.len();
    if size >= u32::MAX as usize || record.payload_at != record.header + 8 {
        return Err("undo rewrite: large-record header".into());
    }
    let end = record.payload_at + size + 32;
    if end > bytes.len() || bytes[record.end.min(end)..end].iter().any(|b| *b != 0) {
        return Err("undo rewrite would overwrite a later record".into());
    }
    let checksum = undo_checksum(&parent_hash, payload);
    bytes[record.header + 4..record.header + 8].copy_from_slice(&(size as u32).to_le_bytes());
    bytes[record.payload_at..record.payload_at + size].copy_from_slice(payload);
    bytes[record.payload_at + size..end].copy_from_slice(&checksum);
    for b in &mut bytes[end..record.end.max(end)] {
        *b = 0;
    }
    fs::write(&record.file, &bytes).map_err(|e| e.to_string())?;
    Ok(
        json!({"file":record.file.file_name().map(|n| n.to_string_lossy().into_owned()),"header_offset":record.header,"payload_offset":record.payload_at,
        "old_payload":hex::encode(&record.payload),"new_payload":hex::encode(payload),"new_checksum":hex::encode(checksum)}),
    )
}

// Bitcoin's VARINT (src/serialize.h WriteVarInt/ReadVarInt at the pin).
fn varint_read(bytes: &[u8]) -> Result<(u64, usize)> {
    let mut n = 0u64;
    for (i, b) in bytes.iter().enumerate() {
        n = (n << 7) | (b & 0x7f) as u64;
        if b & 0x80 == 0 {
            return Ok((n, i + 1));
        }
        n += 1;
    }
    Err("varint runs past the record".into())
}

fn varint_write(mut n: u64) -> Vec<u8> {
    let mut out = vec![];
    loop {
        out.push((n & 0x7f) as u8 | if out.is_empty() { 0 } else { 0x80 });
        if n <= 0x7f {
            break;
        }
        n = (n >> 7) - 1;
    }
    out.reverse();
    out
}

// The pin's default start re-reads the last six blocks' undo at level 3
// (src/validation.h:282-283; src/init.cpp:3960-3968; src/validation.cpp:
// 6869-6902) and refuses a datadir whose undo it cannot read, so the relaunch
// sets checklevel=1 (block checks only) and the recipe asks verifychain
// itself (src/rpc/blockchain.cpp:2321-2354). verifychain(level, d) checks the
// tip and the d blocks below it (src/validation.cpp:6793-6800,6814-6832).
const UNDO_RELAUNCH: &str = "checklevel=1\n";

fn verify_undo(n: &mut Node, depth: u32) -> Result<Value> {
    chain_operator_call(n, "verifychain", json!([2, depth]))
}

// A's undo record removed in place: its index header, record and checksum
// zeroed in the instance's own rev file. A child's record follows A's in the
// same file, so truncation would remove the child's undo too; the child's
// record is left byte-identical and re-verified against its checksum.
fn remove_undo(dir: &Path, a_parent: &str, a: &str) -> Result<Value> {
    let (record, _) = undo_record_of(dir, a_parent)?;
    let mut bytes = fs::read(&record.file).map_err(|e| e.to_string())?;
    let next =
        undo_record_at(&bytes, &record.file, record.end).map(|(r, sum)| (r.header, r.payload, sum));
    let removed = hex::encode(&bytes[record.header..record.end]);
    for b in &mut bytes[record.header..record.end] {
        *b = 0;
    }
    fs::write(&record.file, &bytes).map_err(|e| e.to_string())?;
    let after = fs::read(&record.file).map_err(|e| e.to_string())?;
    let mut child = json!(null);
    if let Some((header, payload, sum)) = next {
        let (r, again) =
            undo_record_at(&after, &record.file, header).ok_or("child undo record lost")?;
        let child_holds = r.payload == payload
            && again == sum
            && undo_checksum(&txid_from_display_hex(a)?, &r.payload) == sum;
        if !child_holds {
            return Err("remove-undo: the following record is not A's child's, or changed".into());
        }
        child = json!({"header_offset":header,"checksum_holds_against_A":true});
    }
    Ok(
        json!({"edit":"remove A's undo record","file":record.file.file_name().map(|n| n.to_string_lossy().into_owned()),
        "header_offset":record.header,"payload_offset":record.payload_at,"zeroed_bytes":record.end - record.header,"removed":removed,"child_record":child}),
    )
}

// [SRC] src/processing_block_index.cpp:79-96 (no undo: DISCONNECT_FAILED
// before anything is applied); src/block_index.cpp:174-194 (an unreadable
// record is no undo); src/validation.cpp:4085-4090 (DisconnectTip refuses
// it), 4603-4668 (automatic: RAII re-admission after a failed disconnect),
// 5241-5256 (invalidation: remove-only), 4526-4553, 5259-5281 (freeze walk
// after invalidation: remove-only), 3402-3407, 3720-3740; src/frozentxo.cpp:
// 37-42; src/rpc/frozentxo_rpc.cpp:346-378; src/txmempool.cpp:2330-2485 at
// 6504a3af. The fault is the declared one: A's undo is absent when its
// disconnect reads it.
fn partial_disconnect_recipe(root: &Path, row: &Value) -> Result<Value> {
    let caller = text(&row["case"])?
        .trim_start_matches("partial-disconnect-")
        .to_owned();
    let extra = if caller == "freeze" {
        "softconsensusfreezeduration=2\n"
    } else {
        ""
    };
    let mut n = start_owned(root, text(&row["id"])?, extra)?;
    let (f, t, base, hashes) = seed_kept(&mut n)?;
    let mut fixtures = json!({"F":material(&f),"T":material(&t),"base":base});
    let a;
    let depth;
    if caller == "freeze" {
        let g_block = n.call("getblock", json!([hashes[1], 1]))?;
        let g = n.raw_tx(&g_block["tx"][0])?;
        let u = spend(&g, g.outputs[0].satoshis - 1000, 1);
        let listed = chain_operator_call(
            &mut n,
            "addToConsensusBlacklist",
            json!([{"funds":[{"txOut":{"txId":id(&g),"vout":0},"enforceAtHeight":[{"start":0}],"policyExpiresWithConsensus":false}]}]),
        )?;
        if listed["notProcessed"] != json!([]) {
            return Err(format!("freeze listing: {listed}"));
        }
        let bits = chain_bits(&mut n)?;
        let (ah, a_bytes) = block_codec::assemble(
            4,
            txid_from_display_hex(&base)?,
            1_700_000_001,
            bits,
            &[cb(102, "partial-freeze"), u.clone()],
        );
        let (bh, b_bytes) = block_codec::assemble(
            4,
            ah.hash(),
            1_700_000_002,
            bits,
            &[cb(103, "partial-freeze"), t.clone()],
        );
        let (h3, c3_bytes) = block_codec::assemble(
            4,
            bh.hash(),
            1_700_000_003,
            bits,
            &[cb(104, "partial-freeze-3")],
        );
        let (h4, c4_bytes) = block_codec::assemble(
            4,
            h3.hash(),
            1_700_000_004,
            bits,
            &[cb(105, "partial-freeze-4")],
        );
        n.call("setmocktime", json!([1_700_000_100]))?;
        let mut replies = vec![];
        for bytes in [&a_bytes, &b_bytes, &c3_bytes] {
            replies.push(n.receipt("submitblock", json!([hex::encode(bytes)]))?);
            if n.call("getbestblockhash", json!([]))? != json!(base) {
                return Err("freeze: a frozen block became the tip".into());
            }
        }
        a = txid_display_hex(&ah.hash());
        let frozen = header_status(&mut n, &a)?;
        if frozen["status"]["soft consensus frozen"] != true || frozen["status"]["failed"] != false
        {
            return Err(format!("freeze: A not soft-consensus frozen: {frozen}"));
        }
        replies.push(n.receipt("submitblock", json!([hex::encode(&c4_bytes)]))?);
        let c4 = txid_display_hex(&h4.hash());
        if n.call("getbestblockhash", json!([]))? != json!(c4) {
            return Err(
                "freeze: the releasing descendant did not activate the frozen chain".into(),
            );
        }
        fixtures["U"] = material(&u);
        fixtures["listing"] = listed;
        fixtures["frozen_A"] = frozen;
        fixtures["blocks"] = json!({"A":a,"B":txid_display_hex(&bh.hash()),"C3":txid_display_hex(&h3.hash()),"C4":c4});
        fixtures["submit_replies"] = json!(replies);
        depth = 3;
    } else {
        let (pa, a_reply) = n.submit(&[cb(102, &format!("partial-{caller}"))], 1_700_000_001)?;
        let (pb, b_reply) = n.submit(
            &[cb(103, &format!("partial-{caller}")), t.clone()],
            1_700_000_002,
        )?;
        if block_judgment(&a_reply) != json!({"status":"ok"})
            || block_judgment(&b_reply) != json!({"status":"ok"})
            || n.call("getbestblockhash", json!([]))? != json!(pb)
        {
            return Err(format!(
                "partial-disconnect: A and B did not connect: {a_reply} {b_reply}"
            ));
        }
        a = pa;
        fixtures["blocks"] = json!({"A":a,"B":pb});
        depth = 1;
    }
    // depth: the blocks above A; verifychain(2, depth) reaches A.
    let intact = verify_undo(&mut n, depth)?;
    if intact != true {
        return Err(format!(
            "partial-disconnect: undo not intact before the edit: {intact}"
        ));
    }
    let edit = n.restart_edited(UNDO_RELAUNCH, |dir| remove_undo(dir, &base, &a))?;
    let mut witness =
        json!({"before_edit_through_A":intact,"after_through_A":verify_undo(&mut n, depth)?});
    if depth > 1 {
        witness["after_above_A"] = verify_undo(&mut n, depth - 1)?;
    }
    if witness["after_through_A"] != false || (depth > 1 && witness["after_above_A"] != true) {
        return Err(format!(
            "partial-disconnect: the pin does not see A's undo absent: {witness}"
        ));
    }
    if caller == "freeze" {
        let frozen = header_status(&mut n, &a)?;
        if frozen["status"]["soft consensus frozen"] != true {
            return Err(format!(
                "freeze: A's mark did not survive the restart: {frozen}"
            ));
        }
        fixtures["frozen_A_after_restart"] = frozen;
    }
    let offset = console_len(&n)?;
    let trigger = if caller == "freeze" {
        n.receipt("invalidateblock", json!([fixtures["blocks"]["C4"]]))?
    } else if caller == "invalidate" {
        n.receipt("invalidateblock", json!([a]))?
    } else {
        let bits = chain_bits(&mut n)?;
        let mut parent = txid_from_display_hex(&base)?;
        let mut replies = vec![];
        for h in 102..=104u32 {
            let (header, bytes) = block_codec::assemble(
                4,
                parent,
                1_700_000_010 + h,
                bits,
                &[cb(h, "partial-rival")],
            );
            parent = header.hash();
            replies.push(n.receipt("submitblock", json!([hex::encode(bytes)]))?);
        }
        fixtures["rival_tip"] = json!(txid_display_hex(&parent));
        json!(replies)
    };
    let tip = n.tip()?;
    let pool = n.call("getrawmempool", json!([]))?;
    let log = console_from(&n, offset)?;
    let status = disconnect_status(&log);
    let failed_on_a = log.contains(&format!("DisconnectTip(): DisconnectBlock {a} failed"));
    let observed = json!({"failed":status == "BsvChain.DisconnectResult.failed" && failed_on_a,"height":tip["height"],
        "readmitted":pool.as_array().ok_or("pool")?.contains(&json!(id(&t)))});
    let mut expected = row["expected"].clone();
    expected
        .as_object_mut()
        .ok_or("partial expected")?
        .remove("queueEmpty");
    if tip["hash"] != json!(a) {
        return Err(format!(
            "partial-disconnect: the tip is not A after the failure: {}",
            tip["hash"]
        ));
    }
    fixtures["undo_edit"] = edit;
    fixtures["undo_witness"] = witness;
    fixtures["trigger"] = trigger;
    fixtures["failure_log"] = json!(failure_lines(&log));
    fixtures["disconnect_status"] = json!(status);
    fixtures["pool"] = pool;
    fixtures["conf"] = json!(n.conf);
    n.call("getchaintips", json!([]))?;
    n.stop()?;
    let recipe = match caller.as_str() {
        "auto" => "A at 102 holds only its coinbase, B at 103 spends F with T. Stop the instance, remove A's undo record in its own rev file (zeroed in place, located by its checksum against base; B's record after it is untouched and re-verified), relaunch with checklevel=1: verifychain(2,1), which held before the edit, now fails on A's undo. Submit a rival 102..104 on base; activation disconnects B (clean, T queued) and then fails on A (failure reading undo data, DISCONNECT_FAILED), and the activation scope re-admits T. Read the tip, the pool and the failure log.",
        "invalidate" => "A at 102 holds only its coinbase, B at 103 spends F with T. Stop, remove A's undo record in place in the instance's rev file (B's record untouched and re-verified), relaunch with checklevel=1; verifychain(2,1), which held before the edit, now fails on A's undo. invalidateblock(A) disconnects B (clean, T queued) and then fails on A (failure reading undo data, DISCONNECT_FAILED), taking the remove-only cleanup. Read the tip, the pool and the failure log.",
        _ => "With -softconsensusfreezeduration=2, list G (block 2's coinbase output) on the consensus blacklist. A at 102 spends G (soft-consensus frozen at its connection, read from its header status), B at 103 spends F with T, C3 at 104 and C4 at 105 release the freeze and activate the chain. Stop, remove A's undo record in place in the instance's rev file (the later records untouched and re-verified), relaunch with checklevel=1; verifychain(2,2) holds above A, verifychain(2,3), which held before the edit, now fails on A's undo, and A's freeze mark persists. invalidateblock(C4) leaves frozen C3 at the tip; the freeze walk disconnects C3 and B (clean) and fails on A (failure reading undo data, DISCONNECT_FAILED), taking the remove-only cleanup. Read the tip, the pool and the failure log.",
    };
    let mut result = measured(
        row,
        observed,
        expected,
        recipe,
        std::mem::take(&mut n.calls),
        fixtures,
    );
    result["declared_expected"] = row["expected"].clone();
    result["spec_only_fields"] = json!(["queueEmpty (internal disconnect pool)"]);
    if caller == "freeze" {
        result["remap"] = json!("The declared freeze of active A (setSoftFreeze) is realized by the pin's own freeze route: A is frozen at its connection by a consensus-blacklisted spend, activated through its releasing descendant, and the freeze walk runs after invalidating that descendant (src/validation.cpp:3402-3407,4526-4545). The fault, A's absent undo, is the declared one.");
    }
    Ok(result)
}

// [SRC] src/processing_block_index.cpp:9-19 (a retained record whose entry
// count disagrees with the block's non-coinbase transactions: DISCONNECT_FAILED,
// "block and undo data inconsistent"); src/undo.h:108-120; src/validation.cpp:
// 4085-4090 at 6504a3af. The record is rewritten in the instance's own rev file
// with a valid checksum, so it is retained and read; only its count disagrees.
fn undo_count_recipe(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_owned(root, text(&row["id"])?, "")?;
    let (f, t, base) = seed(&mut n)?;
    let (x, reply) = n.submit(&[cb(102, "undo-count"), t.clone()], 1_700_000_001)?;
    if block_judgment(&reply) != json!({"status":"ok"})
        || n.call("getbestblockhash", json!([]))? != json!(x)
    {
        return Err(format!("undo-count: X did not connect: {reply}"));
    }
    let intact = verify_undo(&mut n, 1)?;
    let edit = n.restart_edited(UNDO_RELAUNCH, |dir| {
        let (record, last) = undo_record_of(dir, &base)?;
        if !last || record.payload.first() != Some(&1) {
            return Err(format!(
                "undo-count: X's record is not the last single-entry record: {}",
                hex::encode(&record.payload)
            ));
        }
        let mut receipt = write_undo_record(&record, &base, &[0x00])?;
        receipt["edit"] =
            json!("X's undo record rewritten with zero entries and a recomputed checksum");
        Ok(receipt)
    })?;
    let witness = json!({"before_edit":intact,"after_level2":verify_undo(&mut n, 1)?,"after_level3":chain_operator_call(&mut n, "verifychain", json!([3, 1]))?});
    if witness["before_edit"] != true
        || witness["after_level2"] != true
        || witness["after_level3"] != false
    {
        return Err(format!(
            "undo-count: the retained record is not read, or its count passes: {witness}"
        ));
    }
    let offset = console_len(&n)?;
    let invalidation = n.receipt("invalidateblock", json!([x]))?;
    let tip = n.call("getbestblockhash", json!([]))?;
    let log = console_from(&n, offset)?;
    let observed = json!({"status":disconnect_status(&log),"published":tip != json!(x)});
    let expected =
        json!({"status":row["expected"]["status"],"published":row["expected"]["published"]});
    let view = chain_snapshot(&mut n, &f, &t)?;
    n.stop()?;
    let mut result = measured(row, observed, expected,
        "X at 102 holds T spending F (one undo entry). Stop the instance and rewrite X's undo record in its own rev file with zero entries and a recomputed checksum over base and the record; relaunch with checklevel=1. verifychain(2,1) holds (the record is retained and its checksum verifies) and verifychain(3,1) fails (the count check). invalidateblock(X): ApplyBlockUndo returns DISCONNECT_FAILED on the count and DisconnectTip refuses it. Status from the failure log, publication from the unmoved tip.",
        std::mem::take(&mut n.calls), json!({"F":material(&f),"T":material(&t),"base":base,"X":x,"undo_edit":edit,"undo_witness":witness,"invalidation":invalidation,"failure_log":failure_lines(&log),"view":view,"conf":n.conf}));
    result["declared_expected"] = row["expected"].clone();
    result["spec_only_fields"] = json!(["restoresInitial (the discarded disconnect result view)"]);
    Ok(result)
}

// [SRC] src/processing_block_index.cpp:36-48 (only the TxOut is compared when
// an output is removed); src/undo.h:29-73 (an undo entry carries the restored
// coin's height, coinbase and confiscation flags); src/validation.cpp:
// 2936-2953 (the restored coin is added as recorded); src/rpc/blockchain.cpp:
// 1750-1769,1877-1921,1994-2006 (gettxout and gettxoutsetinfo read the
// metadata) at 6504a3af. A spend's undo record, rewritten in the instance's
// own rev file, restores T's output with changed metadata; X then disconnects.
fn output_metadata_recipe(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_owned(root, text(&row["id"])?, "")?;
    let (f, t, base) = seed(&mut n)?;
    let initial = chain_operator_call(&mut n, "gettxoutsetinfo", json!([]))?;
    let (x, x_reply) = n.submit(&[cb(102, "output-metadata"), t.clone()], 1_700_000_001)?;
    let u = spend(&t, 98000, 1);
    let (y, y_reply) = n.submit(&[cb(103, "output-metadata"), u.clone()], 1_700_000_002)?;
    if block_judgment(&x_reply) != json!({"status":"ok"})
        || block_judgment(&y_reply) != json!({"status":"ok"})
        || n.call("getbestblockhash", json!([]))? != json!(y)
    {
        return Err(format!(
            "output-metadata: X and Y did not connect: {x_reply} {y_reply}"
        ));
    }
    let intact = verify_undo(&mut n, 2)?;
    let declared = (1u64 << 32) + 999 * 2 + 1;
    let edit = n.restart_edited(UNDO_RELAUNCH, |dir| {
        let (record, last) = undo_record_of(dir, &x)?;
        let p = &record.payload;
        if !last || p.len() < 3 || p[0] != 1 || p[1] != 1 {
            return Err(format!("output-metadata: Y's record is not the last one-entry record: {}", hex::encode(p)));
        }
        let (code, used) = varint_read(&p[2..])?;
        if code != 102 * 2 {
            return Err(format!("output-metadata: T's recorded metadata code {code}, not height 102 regular"));
        }
        let payload = [&p[..2], &varint_write(declared)[..], &p[2 + used..]].concat();
        let mut receipt = write_undo_record(&record, &x, &payload)?;
        receipt["edit"] = json!("Y's undo entry for T:0 rewritten from height 102, regular, to height 999, coinbase, confiscation; amount and script bytes kept; checksum recomputed");
        receipt["metadata_code"] = json!({"old":code,"new":declared});
        Ok(receipt)
    })?;
    let witness = json!({"before_edit":intact,"after_level2":verify_undo(&mut n, 1)?});
    if witness["before_edit"] != true || witness["after_level2"] != true {
        return Err(format!(
            "output-metadata: the rewritten record is not read: {witness}"
        ));
    }
    n.call("invalidateblock", json!([y]))?;
    let restored = n.call("gettxout", json!([id(&t), 0, false]))?;
    if n.call("getbestblockhash", json!([]))? != json!(x)
        || restored["coinbase"] != true
        || restored["confiscation"] != true
        || restored["confirmations"] != json!(102 - 999 + 1)
        || restored["value"] != json!(0.00099)
    {
        return Err(format!(
            "output-metadata: T's output not restored with the changed metadata: {restored}"
        ));
    }
    let offset = console_len(&n)?;
    let invalidation = n.receipt("invalidateblock", json!([x]))?;
    let tip = n.call("getbestblockhash", json!([]))?;
    let log = console_from(&n, offset)?;
    let after = chain_operator_call(&mut n, "gettxoutsetinfo", json!([]))?;
    let observed = json!({"status":disconnect_status(&log),"published":tip != json!(x),
        "restoresInitial":after["hash_serialized"] == initial["hash_serialized"] && after["txouts"] == initial["txouts"]});
    let expected = json!({"status":row["expected"]["status"],"published":row["expected"]["published"],"restoresInitial":row["expected"]["restoresInitial"]});
    let view = chain_snapshot(&mut n, &f, &t)?;
    n.stop()?;
    let mut result = measured(row, observed, expected,
        "X at 102 holds T spending F; Y at 103 holds U spending T:0. Stop the instance and rewrite Y's undo entry for T:0 in its own rev file: height 102, regular becomes height 999, coinbase, confiscation, amount and script bytes kept, checksum recomputed; relaunch with checklevel=1 (verifychain(2,1) holds). invalidateblock(Y) restores T:0 with the changed metadata (gettxout: coinbase, confiscation, confirmations -896). invalidateblock(X): the pin compares only T:0's TxOut, so the disconnect is clean and the tip moves to base. Status from the absence of a failure line, publication from the moved tip, restoration from gettxoutsetinfo's serialized hash against its reading at base before X.",
        std::mem::take(&mut n.calls), json!({"F":material(&f),"T":material(&t),"U":material(&u),"base":base,"X":x,"Y":y,"initial_utxo":initial,"undo_edit":edit,"undo_witness":witness,"restored_T":restored,"invalidation":invalidation,"failure_log":failure_lines(&log),"after_utxo":after,"view":view,"conf":n.conf}));
    result["declared_expected"] = row["expected"].clone();
    result["remap"] = json!("The declared view holds T:0 with changed metadata before X's disconnect; on the instance that view is reached by Y's rewritten undo entry restoring T:0, then X disconnects. The condition at X's disconnect is the declared one.");
    Ok(result)
}

#[cfg(test)]
mod pend66 {
    use super::*;

    // Development probe: one row on fresh owned instances, printed, nothing
    // written to the repository. Ordinary cargo test never launches a node.
    #[test]
    #[ignore = "explicit owned probe; requires S6_PEND_ID"]
    fn probe_row() {
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
        let rows = row_read("chain").unwrap();
        let row = rows
            .iter()
            .find(|r| r["id"] == wanted.as_str())
            .expect("row id");
        let started = Instant::now();
        let result = match row["case"].as_str().unwrap() {
            "sequence" => equal_work_sequence_recipe(&root, row),
            "completion" => equal_work_completion_recipe(&root, row),
            "receipt-order" => receipt_order_recipe(&root, row),
            "missing-body" | "body-return" => missing_body_recipe(&root, row),
            "missing-output" => missing_output_recipe(&root, row),
            "undo-count" => undo_count_recipe(&root, row),
            "output-metadata" => output_metadata_recipe(&root, row),
            _ => partial_disconnect_recipe(&root, row),
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
                    .take(4000)
                    .collect::<String>()
            ),
            Err(e) => panic!("PROBE {wanted} ERROR {e} (root {})", root.display()),
        }
    }
}
