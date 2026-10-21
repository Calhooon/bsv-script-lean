//! #66 cut 2 (S3, lane cut2-66q2, [D] 2026-10-15): the chain rows that build or rearrange
//! branches, on the second oracle's road (the legacy bridge on, road.rs). chain.rs's recipes
//! are rebuilt on the instance's tip: every block is assembled by the harness and delivered
//! from the loopback peer through the bridge (docs/CONFORMANCE-TERANODE-BRIDGE.md row 13), a
//! side block read from the store (`side`), the operator calls through the instance's RPC
//! (invalidateblock and reconsiderblock, services/rpc/Server.go:201,205 at the Teranode pin).
//! Heights are remapped to the reference's base 101 (`snapshot`'s rule), the coins and
//! coinbases rebuilt at the instance's heights. A row whose recipe fails on the instance is
//! `no-verdict` with the failure kept in the receipt; nothing here stops the run.
use super::road::{frame, snapshot, Road};
use super::*;

/// The chain cases this module realizes.
const BRANCH_CASES: [&str; 7] = [
    "reorg",
    "nonfinal",
    "immature",
    "sequence",
    "completion",
    "invalid-retry",
    "unrequested-equal-work",
];

pub(super) fn handles(row: &Value) -> bool {
    row["case"]
        .as_str()
        .is_some_and(|c| BRANCH_CASES.contains(&c))
}

/// The reason a branch case of the chain family stays unrealizable on the road, or `None`.
pub(super) fn reason(row: &Value) -> Option<String> {
    let node = row["node"].as_str().unwrap_or("");
    let s = match row["case"].as_str()? {
        _ if !node.starts_with("measured") => format!("the reference realized no measurement of the row (its token is {}, the reason in it), so no measurement of the row stands beside the second oracle's", node.split(':').next().unwrap_or("")),
        "precious" => "the row calls preciousblock; the instance lists it among its unimplemented commands (services/rpc/Server.go:284, the list :277-285)".to_owned(),
        "missing-body" | "body-return" => "the row removes one stored block's body by pruneblockchain; the instance has no pruneblockchain handler (services/rpc/Server.go:160-226, the unimplemented list :277-285: no entry), so a stored block whose body alone is absent cannot be arranged".to_owned(),
        "receipt-order" => "the row stores headers without their bodies from the peer and then bodies whose parent has no body; the bridge disconnects a peer whose headers it did not request outside the headers mode of its sync (services/legacy/netsync/manager.go:2491-2498) and keeps no body whose parent it lacks, answering it with a getblocks (:1988-2003), so the waiting bodies cannot be arranged".to_owned(),
        _ => return None,
    };
    Some(format!("{s} [SRC] at Teranode v0.16.0 (4edb60a4)"))
}

/// The regtest subsidy at a height (go-chaincfg v1.6.2 params.go:478: halving every 150 blocks).
fn subsidy(h: u64) -> u64 {
    5_000_000_000u64 >> (h / 150).min(63)
}

/// A block of `txs` on `parent` at `time`, ground to the regtest target.
fn build(parent: &str, txs: &[RawTx], time: u32, bits: u32) -> Result<(String, Vec<u8>)> {
    let (h, bytes) = block_codec::assemble(4, txid_from_display_hex(parent)?, time, bits, txs);
    Ok((txid_display_hex(&h.hash()), bytes))
}

/// Deliver a block that should not become active (a side branch): `stored` once the store
/// holds it unrefused for 2 s, `rejected` on a reject or the invalid flag, `active` if it became
/// the tip, `no-verdict` after 30 s.
fn side(road: &mut Road, bytes: &[u8], hash: &str) -> Result<Value> {
    let mark = road.b.mark()?;
    let sent = road.b.send_block(bytes)?;
    let start = Instant::now();
    loop {
        if let Some((true, _)) = road.t.on_active(hash)? {
            return Ok(json!({"status":"active","send":sent["ok"]}));
        }
        if road.poll_reject(hash, mark, 0.5)?.is_some() {
            return Ok(json!({"status":"rejected","wire":"reject","send":sent["ok"]}));
        }
        let (stored, invalid) = road.header_flags(hash)?;
        if invalid == Some(true) {
            return Ok(json!({"status":"rejected","wire":"invalid","send":sent["ok"]}));
        }
        if stored && start.elapsed() > Duration::from_secs(2) {
            return Ok(json!({"status":"stored","send":sent["ok"]}));
        }
        if start.elapsed() > Duration::from_secs(30) {
            return Ok(json!({"status":"no-verdict","stored":stored,"send":sent["ok"]}));
        }
        thread::sleep(Duration::from_millis(250));
    }
}

/// Wait up to `secs` for the tip to satisfy `done`; the tip's hash either way.
fn wait_tip(road: &mut Road, secs: u64, done: impl Fn(&str) -> bool) -> Result<String> {
    let start = Instant::now();
    loop {
        let (_, hash) = road.t.tip()?;
        if done(&hash) || start.elapsed() > Duration::from_secs(secs) {
            return Ok(hash);
        }
        thread::sleep(Duration::from_millis(250));
    }
}

/// F: one output of `value` satoshis on `lock`, funded by a block on the tip from a road coin
/// (fee 0; a block's transactions are validated with the policy checks skipped,
/// services/legacy/netsync/handle_block.go:1612). `None` when the block was not accepted.
fn fund(road: &mut Road, value: u64, lock: Vec<u8>, tag: &str) -> Result<Option<RawTx>> {
    let (coin, k) = road.coin();
    let mut f = frame(&coin, k, value);
    f.version = 1;
    f.outputs[0].script = lock;
    let (h, _, _, _) = road.tip()?;
    let time = road.time()?;
    let (observed, _) = road.block(&[cb(h as u32 + 1, tag), f.clone()], time)?;
    Ok((observed["status"] == "ok").then_some(f))
}

/// The height of the active block that carries `txid` (txmeta's block hashes, getblock's
/// confirmations; services/asset/httpimpl/GetTransactionMeta.go:94-238 at the Teranode pin).
fn active_height(road: &mut Road, txid: &str) -> Result<Option<u64>> {
    let meta = road.t.txmeta(txid)?;
    let hashes: Vec<String> = meta["body"]["blockHashes"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .map(str::to_owned)
        .collect();
    for h in hashes {
        if let Some((true, height)) = road.t.on_active(&h)? {
            return Ok(Some(height));
        }
    }
    Ok(None)
}

/// One reorg view on the instance (chain.rs `reorg_view`'s fields): the tip's height and the
/// watched coins live on the active chain, and every live coin's value, script, height and
/// coinbase flag from the store's output record (services/asset/httpimpl/GetUTXOsByTXID.go:24-50
/// at the Teranode pin) and its meta. A coin is live when its transaction is in an active block
/// and its spender in none. Heights are remapped to the reference's base 101; a coinbase paying
/// the instance's subsidy at its height reads as the reference's 5,000,000,000 at its remapped
/// height below 150 (the rematerialization of the coin, as chain.rs rematerializes scripts);
/// the reference's `confiscation` flag has no Teranode field and is left out of both sides.
fn reorg_view(
    road: &mut Road,
    watched: &[(String, RawTx)],
    coins: &[(String, RawTx)],
    base: u64,
) -> Result<Value> {
    let (height, _) = road.t.tip()?;
    let mut live = vec![];
    let mut utxo = vec![];
    for (name, tx) in watched.iter().chain(coins) {
        let txid = id(tx);
        let Some(at) = active_height(road, &txid)? else {
            continue;
        };
        let outs = road.t.utxos(&txid)?;
        let out = outs["body"]
            .as_array()
            .into_iter()
            .flatten()
            .find(|o| o["vout"] == 0)
            .cloned()
            .unwrap_or(Value::Null);
        if let Some(s) = out["spendingData"]["txId"].as_str().map(str::to_owned) {
            if active_height(road, &s)?.is_some() {
                continue;
            }
        }
        if watched.iter().any(|(w, _)| w == name) {
            live.push(name.clone());
        }
        let coinbase = road.t.txmeta(&txid)?["body"]["isCoinbase"].clone();
        let mut value = out["satoshis"].clone();
        if coinbase == true && value.as_u64() == Some(subsidy(at)) {
            value = json!(5_000_000_000u64);
        }
        utxo.push(
            json!({"outpoint":name,"value":value,"script":out["lockingScript"],
            "height":(101 + at).checked_sub(base),"coinbase":coinbase}),
        );
    }
    let pool = road.t.pool()?;
    let mut in_pool: Vec<String> = watched
        .iter()
        .filter(|(_, t)| pool.contains(&id(t)))
        .map(|(n, _)| n.clone())
        .collect();
    in_pool.sort();
    Ok(
        json!({"view":{"height":(101 + height).checked_sub(base),"coins":live,"pool":in_pool,"held":[]},"utxo":utxo}),
    )
}

/// The row's expectation as chain.rs's `reorg_expected` reads it, the confiscation flag left
/// out (`reorg_view`).
fn reorg_expected(row: &Value) -> Value {
    let mut views = row["expected"]["views"].clone();
    for view in views.as_array_mut().into_iter().flatten() {
        if let Some(o) = view.as_object_mut() {
            o.remove("complete");
        }
        if let Some(o) = view["view"].as_object_mut() {
            o.remove("pool");
            o.remove("held");
        }
        for coin in view["utxo"].as_array_mut().into_iter().flatten() {
            coin["script"] = json!(hex::encode(script()));
            if let Some(o) = coin.as_object_mut() {
                o.remove("confiscation");
            }
        }
    }
    json!({"views":views,"automaticAgrees":row["expected"]["automaticAgrees"],
        "disconnects":row["expected"]["disconnects"],"final":row["expected"]["final"]})
}

fn reorg_row(road: &mut Road, row: &Value, offset: usize) -> Result<Value> {
    let depth = row["depth"].as_u64().ok_or("reorg depth")?;
    let mut runs = vec![];
    let (mut auto, mut manual) = (Value::Null, Value::Null);
    let mut manual_views = vec![];
    let mut disconnected = 0u64;
    let mut setup: Option<&str> = None;
    for mode in ["automatic", "operator"] {
        let Some(f) = fund(road, 100_000, script(), &format!("reorg-F-{mode}"))? else {
            setup = Some("funding");
            break;
        };
        let (base, base_hash, bits, _) = road.tip()?;
        let k = spend(&f, 98_000, 2);
        let mut watched = vec![("F".to_owned(), f.clone())];
        let mut coinbases = vec![];
        let mut active = vec![];
        let mut parent_tx = f.clone();
        for i in 0..depth {
            let t = spend(&parent_tx, 99_000 - i * 1000, 1);
            let h = base + 1 + i;
            let coinbase = block_codec::coinbase_tx(
                h as u32,
                subsidy(h),
                script(),
                format!("A{i}-{mode}").as_bytes(),
            );
            let time = road.time()?;
            let (observed, fixtures) = road.block(&[coinbase.clone(), t.clone()], time)?;
            if observed["status"] != "ok" {
                setup = Some("a-branch");
                break;
            }
            active.push(fixtures["hash"].as_str().unwrap_or("").to_owned());
            watched.push((format!("T{}", i + 1), t.clone()));
            coinbases.push((format!("A{}:coinbase", i + 1), coinbase));
            parent_tx = t;
        }
        if setup.is_some() {
            break;
        }
        watched.push(("K".to_owned(), k.clone()));
        let mut parent = base_hash.clone();
        let mut rival = vec![];
        let t0 = road.time()?;
        for i in 0..=depth {
            let h = base + 1 + i;
            let coinbase = block_codec::coinbase_tx(
                h as u32,
                subsidy(h),
                script(),
                format!("B{i}-{mode}").as_bytes(),
            );
            let mut txs = vec![coinbase.clone()];
            if i == 0 {
                txs.push(k.clone());
            }
            let (hash, bytes) = build(&parent, &txs, t0 + i as u32, bits)?;
            coinbases.push((format!("B{}:coinbase", i + 1), coinbase));
            rival.push((hash.clone(), bytes));
            parent = hash;
        }
        let mut invalidations = vec![];
        if mode == "operator" {
            manual_views.push(reorg_view(road, &watched, &coinbases, base)?);
            for hash in active.iter().rev() {
                invalidations.push(road.t.receipt("invalidateblock", json!([hash]))?);
                let h = hash.clone();
                wait_tip(road, 20, |tip| tip != h)?;
                thread::sleep(Duration::from_secs(2));
                manual_views.push(reorg_view(road, &watched, &coinbases, base)?);
            }
        }
        let mut deliveries = vec![];
        for (i, (hash, bytes)) in rival.iter().enumerate() {
            let last = i == rival.len() - 1;
            let observed = if mode == "operator" || last {
                road.deliver(bytes, hash)?
            } else {
                side(road, bytes, hash)?
            };
            deliveries.push(json!({"hash":hash,"observed":observed}));
            if mode == "operator" {
                thread::sleep(Duration::from_secs(2));
                manual_views.push(reorg_view(road, &watched, &coinbases, base)?);
            }
        }
        let want = rival.last().map(|(h, _)| h.clone()).unwrap_or_default();
        let tip = wait_tip(road, 20, |tip| tip == want)?;
        thread::sleep(Duration::from_secs(2));
        let final_view = reorg_view(road, &watched, &coinbases, base)?;
        let mut old_active = 0;
        for hash in &active {
            if matches!(road.t.on_active(hash)?, Some((true, _))) {
                old_active += 1;
            } else if mode == "automatic" {
                disconnected += 1;
            }
        }
        runs.push(json!({"mode":mode,"base":base,"base_hash":base_hash,"active":active,"rival_selected":tip == want,"old_branch_active":old_active,
            "rival":rival.iter().map(|(h, b)| json!({"hash":h,"block":hex::encode(b)})).collect::<Vec<_>>(),"deliveries":deliveries,"invalidations":invalidations,
            "transactions":watched.iter().map(|(n, t)| json!({"name":n,"material":material(t)})).collect::<Vec<_>>(),
            "coinbases":coinbases.iter().map(|(n, t)| json!({"name":n,"material":material(t)})).collect::<Vec<_>>()}));
        if mode == "automatic" {
            auto = final_view;
        } else {
            manual = final_view;
        }
    }
    if let Some(stage) = setup {
        return Ok(no_verdict(road, row, stage, json!({"runs":runs}), offset));
    }
    let views: Vec<Value> = manual_views
        .iter()
        .map(|v| {
            let mut v = v.clone();
            if let Some(o) = v["view"].as_object_mut() {
                o.remove("pool");
                o.remove("held");
            }
            v
        })
        .collect();
    let observed = json!({"views":views,"automaticAgrees":auto == manual,"disconnects":disconnected,"final":auto["view"]});
    Ok(judged(road, row, observed, reorg_expected(row),
        "Two runs on the instance's tip, each from a fresh coin F (100,000 satoshis to the harness key, funded in a block): an A branch of depth N, each block spending the previous T (a signed P2PKH spend, fee 1000), and a rival B branch of depth N+1 on the same base whose lowest block carries K, a second spend of F. Automatic: deliver A, then B through the bridge (the shorter B blocks as side blocks); operator: invalidateblock each A tip from the top, then deliver each B block. Read every intermediate view of the operator run and both final views from the store (chain.rs reorg_recipe's projection: the chain-only watched coins with their value, script, remapped height and coinbase flag)",
        json!({"runs":runs,"automatic_final":auto,"operator_final":manual,"operator_views_with_pools":manual_views}),
        &["views.view.pool and views.view.held, as chain.rs leaves them out", "the coins' confiscation flag: the instance has no confiscation transaction (stores/utxo/sql/alert_system.go:147-177 reassigns a frozen output instead)"],
        offset))
}

/// chain.rs `rollback_recipe` on the instance: F (an OP_TRUE coin funded in a block, or a
/// coinbase at the depth that makes T mature in B only), A an empty block, B carrying T (a
/// height lock at A's height for `nonfinal`; F's spend at depth 100 for `immature`, the
/// regtest maturity, go-chaincfg v1.6.2 params.go:463), then invalidateblock A: T is final or
/// mature only at B's height, and the snapshot reads the restored coins and block assembly.
fn rollback_row(road: &mut Road, row: &Value, offset: usize) -> Result<Value> {
    let immature = row["case"] == "immature";
    let f = if immature {
        let (h, _, _, _) = road.tip()?;
        let coinbase =
            block_codec::coinbase_tx(h as u32 + 1, 100_000, vec![0x51], b"watched-funding");
        let time = road.time()?;
        let (observed, _) = road.block(std::slice::from_ref(&coinbase), time)?;
        if observed["status"] != "ok" {
            return Ok(no_verdict(
                road,
                row,
                "funding",
                json!({"F":material(&coinbase)}),
                offset,
            ));
        }
        road.mine_to(h + 99)?;
        coinbase
    } else {
        match fund(road, 100_000, vec![0x51], "rollback-F")? {
            Some(f) => f,
            None => return Ok(no_verdict(road, row, "funding", Value::Null, offset)),
        }
    };
    let (base, base_hash, _, _) = road.tip()?;
    let t = if immature {
        op_true_spend(&f, 0, 99_000, 0, u32::MAX)
    } else {
        op_true_spend(&f, 0, 99_000, base as u32 + 1, 0xffff_fffe)
    };
    let time = road.time()?;
    let (a, a_fixtures) = road.block(&[cb(base as u32 + 1, "rollback-a")], time)?;
    let time = road.time()?;
    let (b, b_fixtures) = road.block(&[cb(base as u32 + 2, "rollback-b"), t.clone()], time)?;
    if a["status"] != "ok" || b["status"] != "ok" {
        return Ok(no_verdict(
            road,
            row,
            "a-b-blocks",
            json!({"A":a_fixtures,"B":b_fixtures}),
            offset,
        ));
    }
    let fc = (f.clone(), 0);
    let before = snapshot(road, &fc, &t, base)?;
    let a_hash = a_fixtures["hash"].as_str().unwrap_or("").to_owned();
    let invalidation = road.t.receipt("invalidateblock", json!([a_hash]))?;
    let back = wait_tip(road, 20, |tip| tip == base_hash)?;
    thread::sleep(Duration::from_secs(3));
    let after = snapshot(road, &fc, &t, base)?;
    Ok(judged(road, row, strip(&after), row["expected"].clone(),
        "On the instance's tip: F (immature: a coinbase of 100,000 satoshis on OP_TRUE, the chain then mined 98 blocks so its spend is mature at depth 100 only in B; nonfinal: a funded OP_TRUE coin), A an empty block, B carrying T (immature: F's spend; nonfinal: lock time A's height, sequence 0xfffffffe), delivered through the bridge; invalidateblock A; after 3 s read the chain-only coins F and T, block assembly and the tip (snapshot, the height remapped to the reference's base 101)",
        json!({"F":material(&f),"T":material(&t),"base":base,"base_hash":base_hash,"A":a_fixtures,"B":b_fixtures,"before":before,"invalidation":invalidation,"tip_after":back,"back_to_base":back == base_hash}),
        &["held: the instance has no non-final pool (services/validator/Validator.go:976-983); the list is empty by construction"],
        offset))
}

/// The snapshot's fields judged against the row (the instance's own height left out).
fn strip(v: &Value) -> Value {
    let mut v = v.clone();
    if let Some(o) = v.as_object_mut() {
        o.remove("instance_height");
    }
    v
}

/// chain.rs `equal_work_sequence_run` on the instance: a holding branch of two blocks; two
/// coinbase-only rivals of equal work on its base stored in the given order; invalidateblock
/// of the holding branch's base block. The instance's tie among equal work is its store's
/// order (chain work, then the peer, then the stored id: stores/blockchain/sql/GetBestBlockHeader.go:135).
fn sequence_run(road: &mut Road, b_before: bool) -> Result<(Value, Value)> {
    let (base, base_hash, bits, _) = road.tip()?;
    let mut holding = vec![];
    for k in 1..=2u64 {
        let time = road.time()?;
        let (o, fx) = road.block(&[cb((base + k) as u32, "sequence-holding")], time)?;
        if o["status"] != "ok" {
            return Ok((json!({"setup":"holding"}), json!({"holding":fx})));
        }
        holding.push(fx["hash"].as_str().unwrap_or("").to_owned());
    }
    let t0 = road.time()?;
    let tag = if b_before { "" } else { "-control" };
    let (b, b_bytes) = build(
        &base_hash,
        &[cb(base as u32 + 1, &format!("sequence-b{tag}"))],
        t0,
        bits,
    )?;
    let (a, a_bytes) = build(
        &base_hash,
        &[cb(base as u32 + 1, &format!("sequence-a{tag}"))],
        t0 + 1,
        bits,
    )?;
    let stored = if b_before {
        [side(road, &b_bytes, &b)?, side(road, &a_bytes, &a)?]
    } else {
        [side(road, &a_bytes, &a)?, side(road, &b_bytes, &b)?]
    };
    let invalidation = road.t.receipt("invalidateblock", json!([holding[0]]))?;
    let (a2, b2) = (a.clone(), b.clone());
    let tip = wait_tip(road, 20, |t| t == a2 || t == b2)?;
    let work = |road: &mut Road, h: &str| -> Result<Value> {
        Ok(road.t.receipt("getblock", json!([h, 1]))?["result"]["chainwork"].clone())
    };
    let (wa, wb) = (work(road, &a)?, work(road, &b)?);
    let selected = if tip == b {
        "B"
    } else if tip == a {
        "A"
    } else {
        "other"
    };
    Ok((
        json!({"selected":selected,"equalWork":!wa.is_null() && wa == wb}),
        json!({"base":base,"base_hash":base_hash,"holding":holding,"A":a,"B":b,"A_block":hex::encode(&a_bytes),"B_block":hex::encode(&b_bytes),"stored":stored,"invalidation":invalidation,"tip":tip}),
    ))
}

fn sequence_row(road: &mut Road, row: &Value, offset: usize) -> Result<Value> {
    let (observed, mut fixtures) = sequence_run(road, true)?;
    if observed.get("setup").is_some() {
        return Ok(no_verdict(road, row, "holding", fixtures, offset));
    }
    let (control, control_fixtures) = sequence_run(road, false)?;
    fixtures["control"] =
        json!({"order":"A then B","observed":control,"fixtures":control_fixtures});
    Ok(judged(road, row, observed, row["expected"].clone(),
        "On the instance's tip, a holding branch of two blocks; two coinbase-only rivals B and A of equal work on its base, stored as side blocks B then A through the bridge; invalidateblock the holding branch's base block; read the selected tip and both chain works. A control on the next tip stores A then B",
        fixtures,
        &["the reference's sequence id and validity field (not exposed by either RPC); the instance's tie is its store's order (stores/blockchain/sql/GetBestBlockHeader.go:135 at the Teranode pin)"],
        offset))
}

/// chain.rs `equal_work_completion_run` on the instance: the earlier block connected, its
/// equal-work rival stored, invalidateblock the earlier, then reconsiderblock it. The
/// reference's restart (both sequence ids reset, completion fixed) has no counterpart: the
/// instance's tie reads no completion time and its stored ids persist
/// (stores/blockchain/sql/GetBestBlockHeader.go:135), so the cell runs without it.
fn completion_run(road: &mut Road, b_earlier: bool) -> Result<(Value, Value)> {
    let (base, base_hash, bits, _) = road.tip()?;
    let t0 = road.time()?;
    let tag = if b_earlier { "" } else { "-control" };
    let (b, b_bytes) = build(
        &base_hash,
        &[cb(base as u32 + 1, &format!("completion-b{tag}"))],
        t0,
        bits,
    )?;
    let (a, a_bytes) = build(
        &base_hash,
        &[cb(base as u32 + 1, &format!("completion-a{tag}"))],
        t0 + 1,
        bits,
    )?;
    let ((earlier, e_bytes), (later, l_bytes)) = if b_earlier {
        ((b.clone(), b_bytes), (a.clone(), a_bytes))
    } else {
        ((a.clone(), a_bytes), (b.clone(), b_bytes))
    };
    let connected = road.deliver(&e_bytes, &earlier)?;
    let stored = side(road, &l_bytes, &later)?;
    let invalidation = road.t.receipt("invalidateblock", json!([earlier]))?;
    let l2 = later.clone();
    let later_tip = wait_tip(road, 20, |t| t == l2)?;
    let reconsider = road.t.receipt("reconsiderblock", json!([earlier]))?;
    let e2 = earlier.clone();
    let tip = wait_tip(road, 20, |t| t == e2)?;
    let work = |road: &mut Road, h: &str| -> Result<Value> {
        Ok(road.t.receipt("getblock", json!([h, 1]))?["result"]["chainwork"].clone())
    };
    let (wa, wb) = (work(road, &a)?, work(road, &b)?);
    let selected = if tip == b {
        "B"
    } else if tip == a {
        "A"
    } else {
        "other"
    };
    let mut fixtures = json!({"base":base,"base_hash":base_hash,"A":a,"B":b,"earlier":earlier,"connected":connected,"stored":stored,
        "invalidation":invalidation,"later_connected":later_tip == later,"reconsider":reconsider,"tip":tip});
    if let Some(e) = reconsider.get("error") {
        fixtures["reconsider_stage"] = json!(super::road::revalidation_stage(e));
    }
    Ok((
        json!({"selected":selected,"equalWork":!wa.is_null() && wa == wb}),
        fixtures,
    ))
}

fn completion_row(road: &mut Road, row: &Value, offset: usize) -> Result<Value> {
    let (observed, mut fixtures) = completion_run(road, true)?;
    let stage = fixtures["reconsider_stage"].as_str().map(str::to_owned);
    let (control, control_fixtures) = completion_run(road, false)?;
    fixtures["control"] = json!({"earlier":"A","observed":control,"fixtures":control_fixtures});
    let mut r = judged(road, row, observed, row["expected"].clone(),
        "On the instance's tip, B (coinbase-only) connected through the bridge, then its equal-work rival A stored as a side block; invalidateblock B so A connects; reconsiderblock B; read the selected tip and both chain works. A control on the next tip swaps the roles. The reference's restart is not run: the instance's tie reads no completion time and its stored ids persist (stores/blockchain/sql/GetBestBlockHeader.go:135 at the Teranode pin)",
        fixtures,
        &["the reference's completion time and sequence id after its restart (not exposed by either RPC)"],
        offset);
    if let Some(stage) = stage {
        r["stage"] = json!(stage);
    }
    Ok(r)
}

/// chain.rs `invalid_retry_recipe` on the instance: a holding branch of three blocks; on its
/// base a block spending a missing input (bad), its child, and a valid competitor (good)
/// carrying T; invalidateblock the holding branch's base block. The reference's two failure
/// flags (failed, parent failed) are one invalid flag on the instance (model/BlockHeaderMeta.go:23),
/// so the child's own flag is not judged.
fn invalid_retry_row(road: &mut Road, row: &Value, offset: usize) -> Result<Value> {
    let Some(f) = fund(road, 100_000, vec![0x51], "retry-F")? else {
        return Ok(no_verdict(road, row, "funding", Value::Null, offset));
    };
    let (base, base_hash, bits, _) = road.tip()?;
    let t = op_true_spend(&f, 0, 99_000, 0, u32::MAX);
    let mut holding = vec![];
    for k in 1..=3u64 {
        let time = road.time()?;
        let (o, fx) = road.block(&[cb((base + k) as u32, "retry-holding")], time)?;
        if o["status"] != "ok" {
            return Ok(no_verdict(
                road,
                row,
                "holding",
                json!({"holding":fx}),
                offset,
            ));
        }
        holding.push(fx["hash"].as_str().unwrap_or("").to_owned());
    }
    let mut bad_tx = t.clone();
    bad_tx.inputs[0].txid = [9; 32];
    let t0 = road.time()?;
    let (bad, bad_bytes) = build(
        &base_hash,
        &[cb(base as u32 + 1, "retry-bad"), bad_tx.clone()],
        t0,
        bits,
    )?;
    let (child, child_bytes) = build(&bad, &[cb(base as u32 + 2, "retry-child")], t0 + 1, bits)?;
    let (good, good_bytes) = build(
        &base_hash,
        &[cb(base as u32 + 1, "retry-good"), t.clone()],
        t0 + 2,
        bits,
    )?;
    let before = [
        side(road, &bad_bytes, &bad)?,
        side(road, &child_bytes, &child)?,
        side(road, &good_bytes, &good)?,
    ];
    let invalidation = road.t.receipt("invalidateblock", json!([holding[0]]))?;
    let g2 = good.clone();
    let tip = wait_tip(road, 30, |t| t == g2)?;
    thread::sleep(Duration::from_secs(3));
    let (bad_stored, bad_invalid) = road.header_flags(&bad)?;
    let (child_stored, child_invalid) = road.header_flags(&child)?;
    let child_active = matches!(road.t.on_active(&child)?, Some((true, _)));
    let bad_refused = bad_invalid == Some(true) || before[0]["status"] == "rejected";
    let view = snapshot(road, &(f.clone(), 0), &t, base)?;
    let observed = json!({"selectedGood":tip == good,"badFailed":bad_refused,
        "childFailedParent":!child_active && (child_invalid == Some(true) || !child_stored || bad_refused),"view":strip(&view)});
    let mut expected = row["expected"].clone();
    if let Some(o) = expected.as_object_mut() {
        o.remove("childNotFailedSelf");
    }
    Ok(judged(road, row, observed, expected,
        "On the instance's tip: F (an OP_TRUE coin funded in a block), a holding branch of three blocks; on its base, as side blocks through the bridge, bad (a spend of the absent 0x09 outpoint), its child, and good carrying T (F's spend); invalidateblock the holding branch's base block; read the selected tip, the store's invalid flags (bad refused: its flag or its reject; the child failed through its parent: not active and flagged, unstored, or under a refused parent) and the snapshot of F and T",
        json!({"F":material(&f),"T":material(&t),"bad_tx":material(&bad_tx),"base":base,"holding":holding,"bad":bad,"child":child,"good":good,"before":before,
            "invalidation":invalidation,"tip":tip,"flags":{"bad":{"stored":bad_stored,"invalid":bad_invalid},"child":{"stored":child_stored,"invalid":child_invalid,"active":child_active}}}),
        &["childNotFailedSelf: the instance keeps one invalid flag per block (model/BlockHeaderMeta.go:23 at the Teranode pin), not the reference's failed and parent-failed pair"],
        offset))
}

/// The unrequested-body row (peer.rs's recipe): A connected on the tip, then B, its rival of
/// equal work on the same parent, sent as a body with no announcement and no request. The
/// bridge on regtest processes an unrequested block (services/legacy/netsync/manager.go:1789-1801;
/// BlockRequested answers true on regtest, :3156-3159); the reference ignores it
/// (src/validation.cpp:6296-6335 at 6504a3af).
fn unrequested_row(road: &mut Road, row: &Value, offset: usize) -> Result<Value> {
    let (base, base_hash, bits, _) = road.tip()?;
    let time = road.time()?;
    let (a_obs, a_fx) = road.block(&[cb(base as u32 + 1, "active-A")], time)?;
    if a_obs["status"] != "ok" {
        return Ok(no_verdict(road, row, "active-A", json!({"A":a_fx}), offset));
    }
    let a = a_fx["hash"].as_str().unwrap_or("").to_owned();
    let (b, bytes) = build(
        &base_hash,
        &[cb(base as u32 + 1, "unrequested-B")],
        time + 1,
        bits,
    )?;
    let mark = road.b.mark()?;
    let sent = road.b.send_block(&bytes)?;
    let quiet = road.b.expect("none", &b, mark, 2.0)?;
    thread::sleep(Duration::from_secs(3));
    let (_, tip) = road.t.tip()?;
    let (stored, invalid) = road.header_flags(&b)?;
    let work = |road: &mut Road, h: &str| -> Result<Value> {
        Ok(road.t.receipt("getblock", json!([h, 1]))?["result"]["chainwork"].clone())
    };
    let (wa, wb) = (work(road, &a)?, work(road, &b)?);
    // Unstored, B's work is its header's: the same bits on the same parent as A.
    let equal = if stored {
        !wa.is_null() && wa == wb
    } else {
        true
    };
    let observed = json!({"ignored":tip == a && !stored,"bodyAbsent":!stored,"equalWork":equal,"notFailed":invalid != Some(true)});
    Ok(judged(road, row, observed, row["expected"].clone(),
        "On the instance's tip, A (coinbase-only) connected through the bridge; B, A's rival on the same parent with the same bits, sent as a body with no inv and no request; after 5 s read the tip, the store's record of B (the asset header route) and both chain works",
        json!({"A":a,"B":b,"B_block":hex::encode(&bytes),"send":sent["ok"],"quiet":quiet,"tip":tip,"stored":stored,"invalid":invalid,"equal_work_from":if stored {"the store's chain works"} else {"the header: same bits on the same parent"}}),
        &["the reference's header-only chain tip status: the instance has no getchaintips answer of that kind (cached and computed from stored blocks, services/rpc/handlers.go:2963-2964)"],
        offset))
}

/// A measured row: the observation against the expectation, every field compared.
#[allow(
    clippy::too_many_arguments,
    reason = "one comparison's eight parts, each named at the call site"
)]
fn judged(
    road: &mut Road,
    row: &Value,
    observed: Value,
    expected: Value,
    recipe: &str,
    fixtures: Value,
    unobserved: &[&str],
    offset: usize,
) -> Value {
    let verdict = if observed == expected {
        "agree"
    } else {
        "diverge"
    };
    let mut differs = vec![];
    if let (Some(e), Some(o)) = (expected.as_object(), observed.as_object()) {
        for (k, v) in e {
            if o.get(k) != Some(v) {
                differs.push(k.clone());
            }
        }
    }
    let mut r = json!({"id":row["id"],"label":"[X]","verdict":verdict,"expected":expected,"expected_label":"[D]","observed":observed,"road":"branch",
        "recipe":recipe,"fixtures":fixtures,"unobserved":unobserved,"reference_token":row["node"],
        "comparison_scope":"the row's projection as chain.rs compares it on the reference, each field read from the instance's RPC and store; the fields the instance does not expose are listed as unobserved and left out of both sides",
        "rpc":road.t.calls[offset..].to_vec()});
    if verdict == "diverge" {
        r["diverging_fields"] = json!(differs);
    }
    r
}

/// A row whose recipe could not be arranged on the instance: no verdict, the stage named.
fn no_verdict(road: &mut Road, row: &Value, stage: &str, fixtures: Value, offset: usize) -> Value {
    json!({"id":row["id"],"label":"[X]","verdict":"no-verdict","observed":{"status":"no-verdict","setup":stage},"expected":row["expected"],"expected_label":"[D]",
        "road":"branch","fixtures":fixtures,"reference_token":row["node"],"rpc":road.t.calls[offset..].to_vec()})
}

/// Every branch row of the chain family, in the corpus's order.
pub(super) fn rows(road: &mut Road, rows: &[Value]) -> Vec<Value> {
    let mut out = vec![];
    for row in rows.iter().filter(|r| handles(r)) {
        let id_ = row["id"].as_str().unwrap_or("").to_owned();
        let offset = road.t.calls.len();
        let result = match row["case"].as_str().unwrap_or("") {
            "reorg" => reorg_row(road, row, offset),
            "nonfinal" | "immature" => rollback_row(road, row, offset),
            "sequence" => sequence_row(road, row, offset),
            "completion" => completion_row(road, row, offset),
            "invalid-retry" => invalid_retry_row(road, row, offset),
            _ => unrequested_row(road, row, offset),
        };
        let r = match result {
            Ok(r) => r,
            Err(e) => {
                let mut r = no_verdict(road, row, "error", Value::Null, offset);
                r["error"] = json!(e);
                r
            }
        };
        road.progress(&id_, &r);
        out.push(r);
    }
    out
}
