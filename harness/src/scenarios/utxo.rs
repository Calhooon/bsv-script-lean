//! Family-owned realization recipes. Sources and observation boundaries are retained in receipts.
use super::core::*;

pub(super) fn run(root: &Path) -> Result<Vec<Value>> {
    let rows = row_read("utxo")?;
    let mut result = vec![];
    for row in &rows {
        let name = text(&row["id"])?;
        if !matches!(
            name,
            "coinbase/depth-99" | "coinbase/depth-100" | "coinbase/depth-101"
        ) {
            continue;
        }
        let height = row["utxo"][0]["height"].as_u64().ok_or("coin height")?;
        let mut n = start_owned(
            root,
            &name.replace('/', "-"),
            "genesisactivationheight=10\nchronicleactivationheight=20\n",
        )?;
        // [D] 2026-10-13 (#72): through the observing miner, never a bare RPC.
        n.mine(height - 1, 1_699_990_000)?;
        let coin = block_codec::coinbase_tx(height as u32, 10, vec![0x51], name.as_bytes());
        let (_, funding) = n.submit(std::slice::from_ref(&coin), 1_699_995_000)?;
        if block_judgment(&funding) != json!({"status":"ok"}) {
            return Err(format!("coinbase setup: {funding}"));
        }
        n.mine(1199 - height, 1_699_999_000)?;
        let before = n.call("gettxout", json!([id(&coin), 0, false]))?;
        let mut tx = RawTx::decode(&hex::decode(text(&row["tx"])?).map_err(|e| e.to_string())?)?;
        tx.inputs[0].txid = coin.txid_internal();
        let reward = block_codec::coinbase_tx(1200, 0, vec![0x51], name.as_bytes());
        let (hash, receipt) = n.submit(&[reward, tx.clone()], 1_700_000_000)?;
        let observed = block_judgment(&receipt);
        let mut evidence = json!({"coin_before":before});
        if observed["status"] == "ok" {
            let spent = n.call("gettxout", json!([id(&coin), 0, false]))?;
            let output = n.call("gettxout", json!([id(&tx), 0, false]))?;
            n.call("invalidateblock", json!([hash]))?;
            let restored = n.call("gettxout", json!([id(&coin), 0, false]))?;
            let gone = n.call("gettxout", json!([id(&tx), 0, false]))?;
            let valid = spent.is_null()
                && !output.is_null()
                && gone.is_null()
                && restored["value"] == before["value"]
                && restored["scriptPubKey"] == before["scriptPubKey"]
                && restored["coinbase"] == before["coinbase"];
            if !valid {
                return Err("UTXO transition/undo observation differs".into());
            }
            evidence = json!({"coin_before":before,"coin_spent":spent,"output":output,"restored":restored,"output_after_undo":gone});
        }
        n.stop()?;
        result.push(measured(row,observed,block_expect(row),"Create the exact 10-satoshi OP_TRUE coinbase at the row's height, using its named Genesis/Chronicle overrides, mine to 1199 and submit its remapped 9-satoshi spend at 1200. Observe chain UTXOs and invalidate accepted blocks to verify restoration; extra prefix coinbases are outside the row's projected map.",std::mem::take(&mut n.calls),json!({"coin":material(&coin),"transaction":material(&tx),"evidence":evidence,"conf":n.conf})));
    }
    result.extend(simple_rows(root, &rows, "scripts")?);
    result.extend(output_rows(root, &rows)?);
    result.extend(coinbase_rows(root, &rows)?);
    result.extend(operator_rows(root, &rows, "confiscation-tx")?);
    result.extend(simple_rows(root, &rows, "structure")?);
    result.extend(operator_rows(root, &rows, "frozen")?);
    result.extend(simple_rows(root, &rows, "script-params")?);
    result.extend(simple_rows(root, &rows, "coin-era")?);
    result.extend(confiscation_rows(root, &rows)?);
    result.extend(operator_rows(root, &rows, "availability")?);
    result.extend(simple_rows(root, &rows, "fee-stage")?);
    result.extend(simple_rows(root, &rows, "value")?);
    Ok(result)
}
pub(super) fn unrealizable(row: &Value) -> Option<&'static str> {
    match row["id"].as_str()? {
        "coinbase/config-2-depth-1" | "coinbase/config-2-depth-2" | "coinbase/future-height" => {
            Some("row overrides compiled COINBASE_MATURITY 100; no regtest RPC or launch override; src/consensus/consensus.h:71-75 and src/validation.cpp:2616-2625 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b")
        }
        "value/input-2099999999999999" | "value/input-2100000000000000" | "value/aggregate-2100000000000000" | "value/aggregate-2100000000000001" | "value/equal-max-values" | "fee/policy-ceiling-ignored" | "fee-stage/max-minus-one" | "fee-stage/max" | "fee-stage/equal-max" => Some("required funded amount exceeds regtest total subsidy bound 15000 BSV; compiled halving interval 150 and 50 BSV initial subsidy have no launch override; src/chainparams.cpp:1460 and src/validation.cpp:2252-2265,3655-3664 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        "value/input-2100000000000001" | "value/input--2" | "order/frozen-before-maturity-value" | "order/coinbase-before-confiscation" | "order/earlier-value-before-later-frozen" => Some("row requires an out-of-MoneyRange stored coin; creating its output is rejected before AddCoins and no RPC injects UTXO cache entries; src/validation.cpp:542-558,3437-3444 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        "fee-stage/max-plus-one" => Some("fee stage requires valueIn above MAX_MONEY, but live CheckTxInputs rejects input or running value range before fee arithmetic; src/validation.cpp:2637-2662 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        "fee-stage/negative-input" => Some("negative valueIn cannot reach live fee arithmetic: spent sentinel fails availability and other negative coins fail MoneyRange; src/coins.cpp:116-128 and src/validation.cpp:2556-2560,2637-2662 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        "confiscation/config-2-depth-1" | "confiscation/config-2-depth-2" => Some("row overrides compiled CONFISCATION_MATURITY 1000; no regtest RPC or launch override; src/consensus/consensus.h:76-79 and src/validation.cpp:2628-2635 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        "scripts/return-coin-height-9" => Some("the required pre-Genesis OP_RETURN chain coin is pruned at creation, so a live chain cannot reach its script stage; src/script/script.h:260-277 and src/coins.cpp:45-64 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        "scripts/mempool-tip-before-genesis" => Some("row combines a pre-Genesis tip 8 and mempool coin with onBlock=true at height 1200; ConnectBlock uses its actual predecessor and assigns included parents their block height, so this mixed context is not a live block state; src/validation.cpp:2667-2674,2972-2981,3437-3444 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        "scripts/resource-selector-False" => Some("row requests policy resource selection inside an onBlock=true script check; live ConnectBlock passes consensus=true with no RPC or launch selector override; src/validation.cpp:3380-3396 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        "scripts/explicit-word-0" | "scripts/explicit-word-128" => Some("row replaces the complete block script flag word; live block flags are derived from chain state, with regtest UAHF and DAA active from zero and no block flag-word override; inline verifyscript would not realize the chain boundary; src/verify_script_flags.cpp:31-81 and src/chainparams.cpp:1487-1491 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        "scripts/real-p2pkh" | "scripts/real-p2pkh-bad-signature" => Some("row requires mainnet height-400000 pre-UAHF/pre-DAA script context and historical signed material; regtest enables UAHF and DAA from height zero with no launch override, so remapping would change the signature-rule boundary; src/chainparams.cpp:1487-1491 and src/verify_script_flags.cpp:52-66 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        "coinbase-add/overwrite-undo-loss" | "overwrite/regular-precondition" => Some("row preloads a different output value under the exact new transaction id/index; a live prefix cannot inject that cache entry without a transaction-id collision, and no RPC supplies arbitrary coin state; src/coins.cpp:386-401,548-565 and src/validation.cpp:3060-3115 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        _ => None,
    }
}

// The core probe binds loopback sockets exclusively. Retry a raced launch in a
// fresh directory; the failed Node is dropped and reaped before another probe.
fn start_owned(root: &Path, tag: &str, extra: &str) -> Result<Node> {
    for attempt in 0..20 {
        match Node::start(root.join(format!("{tag}-{attempt}")), 1_000_001, extra) {
            Ok(n) => return Ok(n),
            Err(e) if e.contains("bind") || e.contains("no free RPC/P2P pair") => {
                thread::sleep(Duration::from_millis(100));
            }
            Err(e) => return Err(e),
        }
    }
    Err("exclusive loopback probe exhausted after launch retries".into())
}

fn decode_row(row: &Value) -> Result<RawTx> {
    RawTx::decode(&hex::decode(text(&row["tx"])?).map_err(|e| e.to_string())?)
}

// Project small funded amounts back to satoshis. Heights use the live
// block and confirmation count. The internal undo-vector layout is not exposed.
#[allow(
    clippy::expect_used,
    reason = "gettxout's value is a JSON number in every reply of the pinned node; a non-number is a node bug the message names"
)]
fn coin_projection(coin: &Value) -> Value {
    if coin.is_null() {
        return Value::Null;
    }
    json!({"satoshis":(coin["value"].as_f64().expect("coin['value'].as_f64()") * 100_000_000.0).round() as u64,
        "script":coin["scriptPubKey"]["hex"],"coinbase":coin["coinbase"]})
}

fn output_rows(root: &Path, rows: &[Value]) -> Result<Vec<Value>> {
    let mut results = vec![];
    for row in rows.iter().filter(|r| r["family"] == "outputs") {
        let name = text(&row["id"])?;
        if name == "outputs/mempool-stored-height" {
            results.push(mempool_output(root, row)?);
            continue;
        }
        // Uniform +101 height mapping: funding 1 -> 102, Genesis 10 -> 111,
        // Chronicle 20 -> 121; creation preserves exact activation distance.
        let h = row["context"]["height"].as_u64().ok_or("height")? + 101;
        let mut n = start_owned(
            root,
            &name.replace('/', "-"),
            "genesisactivationheight=111\nchronicleactivationheight=121\n",
        )?;
        let hashes = n.mine(101, 1_699_990_000)?;
        let b = n.call("getblock", json!([hashes[0], 1]))?;
        let coin = n.raw_tx(&b["tx"][0])?;
        let f = spend_to(&coin, 10, 1, vec![0x51]);
        let (_, funding) = n.submit(&[cb(102, name), f.clone()], 1_699_995_000)?;
        if block_judgment(&funding) != json!({"status":"ok"}) {
            return Err(format!("{name} funding: {funding}"));
        }
        n.mine(h - 103, 1_699_999_000)?;
        let before = n.call("gettxout", json!([id(&f), 0, false]))?;
        let mut tx = decode_row(row)?;
        tx.inputs[0].txid = f.txid_internal();
        let (hash, reply) = n.submit(&[cb(h as u32, name), tx.clone()], 1_700_000_000)?;
        let mut observed = block_judgment(&reply);
        let mut evidence = json!({"before":before,"block":hash,"height":h});
        let eligible = !row["expected"]["state"]
            .as_array()
            .ok_or("state")?
            .is_empty();
        let expected_coin = if eligible {
            json!({"satoshis":tx.outputs[0].satoshis,"script":hex::encode(&tx.outputs[0].script),"coinbase":false})
        } else {
            Value::Null
        };
        let expected = json!({"status":"ok","spent":true,"created":expected_coin,"created_height_matches":true,"restored":true,"removed":true,"fee":1});
        if observed["status"] == "ok" {
            let spent = n.call("gettxout", json!([id(&f), 0, false]))?;
            let created = n.call("gettxout", json!([id(&tx), 0, false]))?;
            let tip = n.tip()?;
            n.call("invalidateblock", json!([hash]))?;
            let restored = n.call("gettxout", json!([id(&f), 0, false]))?;
            let gone = n.call("gettxout", json!([id(&tx), 0, false]))?;
            observed = json!({"status":"ok","spent":spent.is_null(),"created":coin_projection(&created),
                "created_height_matches":created.is_null() || (created["confirmations"]==1 && tip["height"]==h),
                "restored":coin_projection(&before)==coin_projection(&restored),"removed":gone.is_null(),
                "fee":f.outputs[0].satoshis-tx.outputs.iter().map(|o|o.satoshis).sum::<u64>()});
            evidence["spent"] = spent;
            evidence["created"] = created;
            evidence["tip"] = tip;
            evidence["restored"] = restored;
            evidence["after_undo"] = gone;
        }
        n.stop()?;
        results.push(measured(row,observed,expected,
            "Add 101 to symbolic funding, creation and activation heights. Mine a signed funding spend with the exact 10-satoshi OP_TRUE output at 102, then preserve the row output bytes and remap the input hash. Compare chain-only pruning, satoshis, script, coinbase metadata, creation height, spent input and restoration after invalidateblock. Internal undo layout remains spec-only. [SRC] src/coins.cpp:45-64,548-565; src/script/script.h:260-277 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.",
            std::mem::take(&mut n.calls),json!({"funding":material(&f),"transaction":material(&tx),"evidence":evidence,"conf":n.conf})));
    }
    Ok(results)
}

fn mempool_output(root: &Path, row: &Value) -> Result<Value> {
    let name = text(&row["id"])?;
    let mut n = start_owned(
        root,
        "outputs-mempool",
        "genesisactivationheight=111\nchronicleactivationheight=121\n",
    )?;
    let hashes = n.mine(101, 1_699_990_000)?;
    let b = n.call("getblock", json!([hashes[0], 1]))?;
    let coin = n.raw_tx(&b["tx"][0])?;
    let f = spend_to(&coin, 10, 1, vec![0x51]);
    let (_, funding) = n.submit(&[cb(102, name), f.clone()], 1_699_995_000)?;
    if block_judgment(&funding)["status"] != "ok" {
        return Err(format!("funding: {funding}"));
    }
    n.mine(7, 1_699_999_000)?;
    let mut tx = decode_row(row)?;
    tx.inputs[0].txid = f.txid_internal();
    let reply = n.receipt(
        "sendrawtransaction",
        json!([hex::encode(tx.encode()), true]),
    )?;
    let pool = n.call("getrawmempool", json!([]))?;
    let output = n.call("gettxout", json!([id(&tx), 0, true]))?;
    let chain = n.call("gettxout", json!([id(&tx), 0, false]))?;
    let spent = n.call("gettxout", json!([id(&f), 0, true]))?;
    let observed = json!({"accepted":reply["result"]==id(&tx),"pool":pool,"created":coin_projection(&output),"sentinel":output["confirmations"]==0,"chain_absent":chain.is_null(),"spent":spent.is_null()});
    let expected = json!({"accepted":true,"pool":[id(&tx)],"created":{"satoshis":9,"script":"6a","coinbase":false},"sentinel":true,"chain_absent":true,"spent":true});
    n.stop()?;
    Ok(measured(row,observed,expected,"Remap symbolic tip 8 to live tip 109, preserving pre-Genesis era at tip and successor. Admit the exact one-satoshi-fee OP_RETURN transaction against a real ten-satoshi coin. The mempool view retains full output bytes at MEMPOOL_HEIGHT even though a pre-Genesis chain addition would prune them; gettxout(include_mempool=true) reports confirmations zero. Compare exact accepted pool, spent overlay and absence from chain-only view. This observes the row output-storage boundary, not the internal UpdateCoins call or undo vector. [SRC] src/txmempool.cpp:2070-2088; src/rpc/blockchain.cpp:1923-2029 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.",std::mem::take(&mut n.calls),json!({"funding":material(&f),"transaction":material(&tx),"reply":reply,"output":output,"chain":chain,"spent":spent,"conf":n.conf})))
}

fn simple_rows(root: &Path, rows: &[Value], family: &str) -> Result<Vec<Value>> {
    let mut results = vec![];
    for row in rows
        .iter()
        .filter(|r| r["family"] == family && unrealizable(r).is_none())
    {
        let name = text(&row["id"])?;
        if name == "scripts/return-coin-height-2147483647" {
            results.push(mempool_coin_spend(root, row)?);
            continue;
        }
        let fee_stage = family == "fee-stage";
        let mut tx = decode_row(row)?;
        let input_value = if fee_stage {
            row["valueIn"].as_u64().ok_or("valueIn")?
        } else {
            row["utxo"][0]["value"].as_u64().ok_or("coin value")?
        };
        let lock = hex::decode(text(&row["utxo"][0]["script"])?).map_err(|e| e.to_string())?;
        let extra = if family == "script-params" {
            "genesisactivationheight=101\nchronicleactivationheight=111\nmaxscriptsizepolicy=1\n"
        } else {
            "genesisactivationheight=101\nchronicleactivationheight=111\n"
        };
        let mut n = start_owned(root, &name.replace('/', "-"), extra)?;
        let funding_height = if name == "scripts/return-coin-height-20" {
            111
        } else {
            101
        };
        let hashes = n.mine(funding_height - 1, 1_699_990_000)?;
        let b = n.call("getblock", json!([hashes[0], 1]))?;
        let coin = n.raw_tx(&b["tx"][0])?;
        let f = spend_to(&coin, input_value, 1, lock);
        let (_, funding) =
            n.submit(&[cb(funding_height as u32, name), f.clone()], 1_699_995_000)?;
        if block_judgment(&funding)["status"] != "ok" {
            return Err(format!("{name} funding: {funding}"));
        }
        n.mine(1199 - funding_height, 1_699_999_000)?;
        for input in &mut tx.inputs {
            input.txid = f.txid_internal();
        }
        if fee_stage {
            tx.outputs[0].satoshis = row["valueOut"].as_u64().ok_or("valueOut")?;
        }
        let before = n.call("gettxout", json!([id(&f), 0, false]))?;
        let (hash, reply) = n.submit(&[cb(1200, name), tx.clone()], 1_700_000_000)?;
        let mut observed = block_judgment(&reply);
        let mut expected = block_expect(row);
        let mut evidence = json!({"before":before});
        if expected["status"] == "ok" {
            expected["fee"] = row["expected"]["fee"].clone();
            expected["spent"] = json!(true);
            expected["created"] = json!({"satoshis":tx.outputs[0].satoshis,"script":hex::encode(&tx.outputs[0].script),"coinbase":false});
            expected["restored"] = json!(true);
            expected["removed"] = json!(true);
        }
        if observed["status"] == "ok" {
            let spent = n.call("gettxout", json!([id(&f), 0, false]))?;
            let created = n.call("gettxout", json!([id(&tx), 0, false]))?;
            n.call("invalidateblock", json!([hash]))?;
            let restored = n.call("gettxout", json!([id(&f), 0, false]))?;
            let gone = n.call("gettxout", json!([id(&tx), 0, false]))?;
            observed["fee"] =
                json!(input_value - tx.outputs.iter().map(|o| o.satoshis).sum::<u64>());
            observed["spent"] = json!(spent.is_null());
            observed["created"] = coin_projection(&created);
            observed["restored"] = json!(coin_projection(&before) == coin_projection(&restored));
            observed["removed"] = json!(gone.is_null());
            evidence = json!({"before":before,"spent":spent,"created":created,"restored":restored,"after_undo":gone});
        }
        n.stop()?;
        results.push(measured(row,observed,expected,"Fund the exact input amount and locking script on the live chain, remap transaction prevouts, and submit at height 1200. Genesis/Chronicle 101/111 preserve the selected script boundary; OP_TRUE value and structural rows do not depend on the original coin era. Fee-stage rows materialize valueIn/valueOut as funded amounts rather than using their inert transaction placeholder. Compare exact block reason or acceptance, fee, output metadata and invalidateblock restoration. [SRC] src/validation.cpp:542-558,625-637,2552-2665,3421-3444 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.",std::mem::take(&mut n.calls),json!({"funding":material(&f),"transaction":material(&tx),"evidence":evidence,"conf":n.conf})));
    }
    Ok(results)
}

fn mempool_coin_spend(root: &Path, row: &Value) -> Result<Value> {
    let name = text(&row["id"])?;
    let mut n = start_owned(
        root,
        &name.replace('/', "-"),
        "genesisactivationheight=101\nchronicleactivationheight=111\n",
    )?;
    let hashes = n.mine(100, 1_699_990_000)?;
    let b = n.call("getblock", json!([hashes[0], 1]))?;
    let coin = n.raw_tx(&b["tx"][0])?;
    let f = spend_to(&coin, 11, 1, vec![0x51]);
    let (_, funding) = n.submit(&[cb(101, name), f.clone()], 1_699_995_000)?;
    if block_judgment(&funding)["status"] != "ok" {
        return Err("funding refused".into());
    }
    n.mine(1098, 1_699_999_000)?;
    let mut parent = decode_row(row)?;
    parent.inputs[0].txid = f.txid_internal();
    parent.inputs[0].script = vec![];
    parent.outputs[0].satoshis = 10;
    parent.outputs[0].script = vec![0x6a];
    let p = n.receipt(
        "sendrawtransaction",
        json!([hex::encode(parent.encode()), true]),
    )?;
    if p["result"] != id(&parent) {
        return Err(format!("mempool parent: {p}"));
    }
    let before = n.call("gettxout", json!([id(&parent), 0, true]))?;
    let mut tx = decode_row(row)?;
    tx.inputs[0].txid = parent.txid_internal();
    let reply = n.receipt(
        "sendrawtransaction",
        json!([hex::encode(tx.encode()), true]),
    )?;
    let pool = n.call("getrawmempool", json!([]))?;
    let mut got: Vec<String> = pool
        .as_array()
        .ok_or("pool")?
        .iter()
        .map(|v| text(v).map(str::to_owned))
        .collect::<Result<_>>()?;
    got.sort();
    let mut want = vec![id(&parent), id(&tx)];
    want.sort();
    let output = n.call("gettxout", json!([id(&tx), 0, true]))?;
    let observed = json!({"accepted":reply["result"]==id(&tx),"pool":got,"parent_sentinel":before["confirmations"]==0,"output":coin_projection(&output)});
    let expected = json!({"accepted":true,"pool":want,"parent_sentinel":true,"output":{"satoshis":9,"script":"51","coinbase":false}});
    n.stop()?;
    Ok(measured(row,observed,expected,"Create an unmined ten-satoshi OP_RETURN parent at live tip 1199. Observe confirmations zero, then submit the row's remapped child with unchanged unlock script and outputs. The live mempool sentinel resolves to tip successor 1200, post-Genesis and post-Chronicle. Compare exact accepted parent/child set and output, retaining RPC envelopes. Internal UpdateCoins and undo are outside this mempool observation. [SRC] src/txmempool.cpp:2070-2088; src/validation.cpp:2667-2709 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.",std::mem::take(&mut n.calls),json!({"funding":material(&f),"parent":material(&parent),"transaction":material(&tx),"before":before,"reply":reply,"output":output,"conf":n.conf})))
}

// Family-owned operator RPCs. Keep their exact request/reply and source alongside
// ordinary core receipts without extending the shared handler table.
fn operator(n: &mut Node, method: &str, params: Value) -> Result<Value> {
    let source = match method {
        "addToPolicyBlacklist" => "src/rpc/frozentxo_rpc.cpp:320-344",
        "addToConsensusBlacklist" => "src/rpc/frozentxo_rpc.cpp:346-380",
        "addToConfiscationTxidWhitelist" => "src/rpc/frozentxo_rpc.cpp:632-762",
        _ => return Err("unsupported UTXO operator RPC".into()),
    };
    let answer = n
        .rpc
        .as_mut()
        .ok_or("RPC not ready")?
        .call(method, params.clone());
    let raw = match &answer {
        Ok(v) => json!({"result":v}),
        Err(e) => json!({"error":e}),
    };
    n.calls.push(json!({"method":method,"params":params,"source":format!("[SRC] {source} at {PIN}"),"reply":raw}));
    let reply = answer?;
    if reply["notProcessed"] != json!([]) {
        return Err(format!("{method}: {reply}"));
    }
    Ok(reply)
}
fn freeze(n: &mut Node, f: &RawTx, policy: bool) -> Result<()> {
    let mut fund = json!({"txOut":{"txId":id(f),"vout":0}});
    if !policy {
        fund["enforceAtHeight"] = json!([{"start":0}]);
        fund["policyExpiresWithConsensus"] = json!(false);
    }
    operator(
        n,
        if policy {
            "addToPolicyBlacklist"
        } else {
            "addToConsensusBlacklist"
        },
        json!([{"funds":[fund]}]),
    )?;
    Ok(())
}
fn whitelist(n: &mut Node, tx: &RawTx) -> Result<()> {
    operator(
        n,
        "addToConfiscationTxidWhitelist",
        json!([{"confiscationTxs":[{"confiscationTx":{"enforceAtHeight":0,"hex":hex::encode(tx.encode())}}]}]),
    )?;
    Ok(())
}

fn operator_rows(root: &Path, rows: &[Value], family: &str) -> Result<Vec<Value>> {
    let mut results = vec![];
    for row in rows
        .iter()
        .filter(|r| r["family"] == family && unrealizable(r).is_none())
    {
        let name = text(&row["id"])?;
        let mut n = start_owned(
            root,
            &name.replace('/', "-"),
            "genesisactivationheight=101\nchronicleactivationheight=111\n",
        )?;
        let hashes = n.mine(100, 1_699_990_000)?;
        let b = n.call("getblock", json!([hashes[0], 1]))?;
        let coin = n.raw_tx(&b["tx"][0])?;
        let lock = if family == "confiscation-tx" {
            vec![0]
        } else {
            vec![0x51]
        };
        let f = spend_to(&coin, 10, 1, lock);
        let (_, funding) = n.submit(&[cb(101, name), f.clone()], 1_699_995_000)?;
        if block_judgment(&funding)["status"] != "ok" {
            return Err(format!("{name} funding: {funding}"));
        }
        let mut tx = decode_row(row)?;
        if name != "availability/missing" && name != "availability/missing-raw" {
            tx.inputs[0].txid = f.txid_internal();
        }
        let mut conflict = None;
        if name.contains("spent") {
            let mut other = tx.clone();
            other.outputs[0].satoshis = 8;
            let (_, reply) = n.submit(&[cb(102, "spent-prefix"), other.clone()], 1_699_996_000)?;
            if block_judgment(&reply)["status"] != "ok" {
                return Err(format!("spent setup: {reply}"));
            }
            conflict = Some(material(&other));
            n.mine(1097, 1_699_999_000)?;
        } else {
            n.mine(1098, 1_699_999_000)?;
        }
        if family == "frozen"
            || family == "confiscation-tx"
            || name == "availability/precedes-frozen"
        {
            freeze(
                &mut n,
                &f,
                name == "frozen/admission" || name == "frozen/policy-only-block",
            )?;
        }
        if name == "confiscation-tx/whitelisted-bypass" {
            whitelist(&mut n, &tx)?;
        }
        let before = n.call("gettxout", json!([id(&f), 0, false]))?;
        let mut evidence = json!({"before":before,"conflict":conflict});
        let (mut observed, hash) = if name == "frozen/admission" || row["kind"] == "inputs" {
            let reply = n.receipt(
                "sendrawtransaction",
                json!([hex::encode(tx.encode()), true]),
            )?;
            if row["kind"] == "inputs" {
                if reply["error"]["code"] != -25 || reply["error"]["message"] != "Missing inputs" {
                    return Err(format!("unexpected missing-input envelope: {reply}"));
                }
                n.stop()?;
                results.push(json!({"id":row["id"],"label":"[X]","verdict":"rpc-precheck","rpc_precheck":{"code":reply["error"]["code"],"message":reply["error"]["message"],"source":"src/rpc/rawtransaction.cpp:1636-1638","handler":"src/rpc/rawtransaction.cpp:1636-1638"},"recipe":"Bind the spent case to a real previously mined conflicting spend; missing case names an unfunded prevout. The RPC caller returns Missing inputs before the isolated CheckTxInputs empty-reason result can be observed. [SRC] src/validation.cpp:2556-2560 and src/rpc/rawtransaction.cpp:1636-1638 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.","rpc":std::mem::take(&mut n.calls),"fixtures":{"funding":material(&f),"transaction":material(&tx),"evidence":evidence,"reply":reply,"conf":n.conf}}));
                continue;
            }
            let reject = node_reject(&reply).ok_or("admission expected rejection receipt")?;
            (
                json!({"status":reject["status"],"reason":reject["reason"]}),
                String::new(),
            )
        } else {
            let (hash, reply) = n.submit(&[cb(1200, name), tx.clone()], 1_700_000_000)?;
            (block_judgment(&reply), hash)
        };
        let mut expected = block_expect(row);
        if expected["status"] == "ok" {
            expected["spent"] = json!(true);
            expected["outputs_match"] = json!(true);
            expected["restored"] = json!(true);
            expected["removed"] = json!(true);
        }
        if observed["status"] == "ok" {
            let spent = n.call("gettxout", json!([id(&f), 0, false]))?;
            let mut output = vec![];
            let mut outputs_match = true;
            for (i, o) in tx.outputs.iter().enumerate() {
                let actual = n.call("gettxout", json!([id(&tx), i, false]))?;
                let pruned = o.script.starts_with(&[0, 0x6a]);
                outputs_match &= if pruned {
                    actual.is_null()
                } else {
                    coin_projection(&actual)
                        == json!({"satoshis":o.satoshis,"script":hex::encode(&o.script),"coinbase":false})
                        && actual["confiscation"] == (family == "confiscation-tx")
                };
                output.push(actual);
            }
            n.call("invalidateblock", json!([hash]))?;
            let restored = n.call("gettxout", json!([id(&f), 0, false]))?;
            let mut removed = true;
            for i in 0..tx.outputs.len() {
                removed &= n.call("gettxout", json!([id(&tx), i, false]))?.is_null();
            }
            observed["spent"] = json!(spent.is_null());
            observed["outputs_match"] = json!(outputs_match);
            observed["restored"] = json!(coin_projection(&before) == coin_projection(&restored));
            observed["removed"] = json!(removed);
            evidence["spent"] = spent;
            evidence["outputs"] = json!(output);
            evidence["restored"] = restored;
        }
        n.stop()?;
        results.push(measured(row,observed,expected,"Fund a real ten-satoshi output; remap the row prevout. Availability-spent rows mine a distinct conflicting spend; availability-precedes-frozen installs the actual frozen outpoint while retaining a separate missing input. Frozen and confiscation rows install the effective operator list through cited RPCs; whitelist binds the rematerialized transaction bytes. Submit at live height 1200, or through admission for the policy-only row. Accepted transitions verify pruning, output metadata including confiscation, and undo by invalidation. [SRC] src/validation.cpp:2552-2665,3326-3444 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.",std::mem::take(&mut n.calls),json!({"funding":material(&f),"transaction":material(&tx),"evidence":evidence,"conf":n.conf})));
    }
    Ok(results)
}

fn confiscation_rows(root: &Path, rows: &[Value]) -> Result<Vec<Value>> {
    let mut results = vec![];
    for row in rows
        .iter()
        .filter(|r| r["family"] == "confiscation-maturity" && unrealizable(r).is_none())
    {
        let name = text(&row["id"])?;
        let height = row["utxo"][0]["height"].as_u64().ok_or("height")?;
        let mut n = start_owned(
            root,
            &name.replace('/', "-"),
            "genesisactivationheight=10\nchronicleactivationheight=20\n",
        )?;
        let hashes = n.mine(100, 1_699_990_000)?;
        let b = n.call("getblock", json!([hashes[0], 1]))?;
        let coin = n.raw_tx(&b["tx"][0])?;
        let f = spend_to(&coin, 11, 1, vec![0]);
        let (_, funding) = n.submit(&[cb(101, name), f.clone()], 1_699_994_000)?;
        if block_judgment(&funding)["status"] != "ok" {
            return Err(format!("funding: {funding}"));
        }
        let template = rows
            .iter()
            .find(|r| r["id"] == "confiscation-tx/whitelisted-bypass")
            .ok_or("template")?;
        let mut ct = decode_row(template)?;
        ct.inputs[0].txid = f.txid_internal();
        ct.outputs[1].satoshis = 10;
        freeze(&mut n, &f, false)?;
        whitelist(&mut n, &ct)?;
        n.mine(height - 102, 1_699_995_000)?;
        let (_, reply) = n.submit(&[cb(height as u32, name), ct.clone()], 1_699_996_000)?;
        if block_judgment(&reply)["status"] != "ok" {
            return Err(format!("confiscation creation: {reply}"));
        }
        n.mine(1199 - height, 1_699_999_000)?;
        let before = n.call("gettxout", json!([id(&ct), 1, false]))?;
        if before["confiscation"] != true || before["confirmations"] != 1200 - height {
            return Err("confiscation boundary not materialized".into());
        }
        let mut tx = decode_row(row)?;
        tx.inputs[0].txid = ct.txid_internal();
        tx.inputs[0].vout = 1;
        let (hash, reply) = n.submit(&[cb(1200, name), tx.clone()], 1_700_000_000)?;
        let mut observed = block_judgment(&reply);
        let mut expected = block_expect(row);
        let mut evidence = json!({"before":before});
        if expected["status"] == "ok" {
            for key in ["spent", "created", "restored", "removed"] {
                expected[key] = json!(true);
            }
        }
        if observed["status"] == "ok" {
            let spent = n.call("gettxout", json!([id(&ct), 1, false]))?;
            let out = n.call("gettxout", json!([id(&tx), 0, false]))?;
            n.call("invalidateblock", json!([hash]))?;
            let restored = n.call("gettxout", json!([id(&ct), 1, false]))?;
            let gone = n.call("gettxout", json!([id(&tx), 0, false]))?;
            observed["spent"] = json!(spent.is_null());
            observed["created"] = json!(
                coin_projection(&out) == json!({"satoshis":9,"script":"51","coinbase":false})
                    && out["confiscation"] == false
            );
            observed["restored"] = json!(
                coin_projection(&before) == coin_projection(&restored)
                    && restored["confiscation"] == true
            );
            observed["removed"] = json!(gone.is_null());
            evidence = json!({"before":before,"spent":spent,"created":out,"restored":restored,"after_undo":gone});
        }
        n.stop()?;
        results.push(measured(row,observed,expected,"Fund eleven satoshis, freeze the real output and whitelist a valid rematerialized confiscation transaction. Mine its ten-satoshi OP_TRUE output at the exact row height; spend at 1200. The row's index zero maps to live output one because output zero carries the confiscation protocol marker. Compare the measured confiscation bit/depth, exact maturity reason or acceptance, created output and restoration. [SRC] src/consensus/consensus.h:76-79; src/validation.cpp:2628-2635; src/frozentxo_db.cpp:614-717 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.",std::mem::take(&mut n.calls),json!({"funding":material(&f),"confiscation":material(&ct),"transaction":material(&tx),"evidence":evidence,"conf":n.conf})));
    }
    Ok(results)
}

fn coinbase_rows(root: &Path, rows: &[Value]) -> Result<Vec<Value>> {
    let mut results = vec![];
    for row in rows.iter().filter(|r| r["family"] == "coinbase-add") {
        let name = text(&row["id"])?;
        let h = row["context"]["height"].as_u64().ok_or("height")? + 101;
        let mut n = start_owned(
            root,
            &name.replace('/', "-"),
            "genesisactivationheight=111\nchronicleactivationheight=121\n",
        )?;
        let hashes = n.mine(101, 1_699_990_000)?;
        let b = n.call("getblock", json!([hashes[0], 1]))?;
        let coin = n.raw_tx(&b["tx"][0])?;
        let f = spend_to(&coin, 10, 1, vec![0x51]);
        let (_, funding) = n.submit(&[cb(102, name), f.clone()], 1_699_995_000)?;
        if block_judgment(&funding)["status"] != "ok" {
            return Err("funding rejected".into());
        }
        n.mine(h - 103, 1_699_999_000)?;
        let before = n.call("gettxout", json!([id(&f), 0, false]))?;
        let tx = decode_row(row)?;
        let (hash, reply) = n.submit(std::slice::from_ref(&tx), 1_700_000_000)?;
        let mut observed = block_judgment(&reply);
        let mut outputs = vec![];
        let mut expected_outputs = vec![];
        for (i, o) in tx.outputs.iter().enumerate() {
            outputs.push(coin_projection(
                &n.call("gettxout", json!([id(&tx), i, false]))?,
            ));
            let present = row["expected"]["state"]
                .as_array()
                .or_err("row['expected']['state'].as_array()")?
                .iter()
                .any(|c| c["isCoinbase"] == true && c["index"] == i);
            expected_outputs.push(if present {
                json!({"satoshis":o.satoshis,"script":hex::encode(&o.script),"coinbase":true})
            } else {
                Value::Null
            });
        }
        let retained = n.call("gettxout", json!([id(&f), 0, false]))?;
        if observed["status"] == "ok" {
            n.call("invalidateblock", json!([hash]))?;
            let mut gone = true;
            for i in 0..tx.outputs.len() {
                gone &= n.call("gettxout", json!([id(&tx), i, false]))?.is_null();
            }
            let after = n.call("gettxout", json!([id(&f), 0, false]))?;
            observed["outputs"] = json!(outputs);
            observed["unrelated_retained"] = json!(
                coin_projection(&before) == coin_projection(&retained)
                    && coin_projection(&before) == coin_projection(&after)
            );
            observed["removed"] = json!(gone);
        }
        let expected = json!({"status":"ok","outputs":expected_outputs,"unrelated_retained":true,"removed":true});
        n.stop()?;
        results.push(measured(row,observed,expected,"Remap heights by +101, retain exact coinbase transaction bytes under regtest's inactive BIP34 height rule, and create the unrelated ten-satoshi output before the trial. Compare eligible coinbase outputs, retention of the unrelated input, and removal by invalidation. [SRC] src/chainparams.cpp:1460-1465; src/coins.cpp:45-64,548-565 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.",std::mem::take(&mut n.calls),json!({"funding":material(&f),"transaction":material(&tx),"before":before,"retained":retained,"conf":n.conf})));
    }
    Ok(results)
}

#[cfg(test)]
mod lane_tests {
    use super::*;

    #[test]
    fn coin_projection_preserves_observable_distinctions() {
        assert_eq!(coin_projection(&Value::Null), Value::Null);
        let coin = json!({"value":0.00000009,"scriptPubKey":{"hex":"6a"},"coinbase":false});
        assert_eq!(
            coin_projection(&coin),
            json!({"satoshis":9,"script":"6a","coinbase":false})
        );
        let mut changed = coin.clone();
        changed["value"] = json!(0.00000010);
        assert!(!compare(
            &coin_projection(&coin),
            &coin_projection(&changed)
        ));
        changed = coin.clone();
        changed["scriptPubKey"]["hex"] = json!("006a");
        assert!(!compare(
            &coin_projection(&coin),
            &coin_projection(&changed)
        ));
    }

    // Explicit opt-in, family-local entry point: the inherited aggregate driver
    // fixes another lane's record suffix and runs all families unconditionally.
    #[test]
    #[ignore = "owned loopback node measurement; requires S6_UTXO_RECORD and S6_UTXO_KIND"]
    fn capture_lane() {
        std::env::set_current_dir(Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap()).unwrap();
        signals();
        let record = std::env::var("S6_UTXO_RECORD").unwrap();
        assert!(
            record.starts_with("docs/records/") && record.ends_with("-s6-66-utx-regtest-s3.md")
        );
        let kind = std::env::var("S6_UTXO_KIND").unwrap();
        let stamp = String::from_utf8(
            Command::new("date")
                .args(["-u", "+%Y%m%d-%H%M%S"])
                .output()
                .unwrap()
                .stdout,
        )
        .unwrap()
        .trim()
        .to_owned();
        let run_id = format!("s6-66-utx-{kind}-{stamp}");
        let root = PathBuf::from(std::env::var("HOME").unwrap())
            .join("bsv/targets/spec-oracle-scenarios")
            .join(&run_id);
        fs::create_dir(&root).unwrap();
        let version = Command::new(Build::Record.located())
            .arg("-version")
            .output()
            .unwrap();
        let version = String::from_utf8(version.stdout)
            .unwrap()
            .lines()
            .next()
            .unwrap()
            .to_owned();
        assert_eq!(version, format!("Bitcoin SV version {VERSION}"));
        let rows = row_read("utxo").unwrap();
        let start = Instant::now();
        let mut results = match kind.as_str() {
            "all" => run(&root),
            "outputs" => output_rows(&root, &rows),
            "confiscation-maturity" => confiscation_rows(&root, &rows),
            "coinbase-add" => coinbase_rows(&root, &rows),
            "availability" | "frozen" | "confiscation-tx" => operator_rows(&root, &rows, &kind),
            "value" | "fee-stage" | "structure" | "scripts" | "coin-era" | "script-params" => {
                simple_rows(&root, &rows, &kind)
            }
            "ordering" | "overwrite" | "p2pkh" | "fee" => Ok(vec![]),
            _ => panic!("unsupported kind"),
        }
        .unwrap();
        for row in rows.iter().filter(|r| kind == "all" || r["family"] == kind) {
            if let Some(reason) = unrealizable(row) {
                results.push(json!({"id":row["id"],"label":"[X]","unrealizable":reason}));
            }
        }
        let expected_ids: BTreeSet<_> = rows
            .iter()
            .filter(|r| kind == "all" || r["family"] == kind)
            .map(|r| text(&r["id"]).unwrap())
            .collect();
        let actual_ids: BTreeSet<_> = results.iter().map(|r| text(&r["id"]).unwrap()).collect();
        assert_eq!(actual_ids.len(), results.len(), "duplicate row receipt");
        assert_eq!(expected_ids, actual_ids, "recipe omitted or added a row");
        let receipt_path = record.replace(".md", ".json");
        let mut receipt: Value = fs::read_to_string(&receipt_path)
            .ok()
            .map(|s| serde_json::from_str(&s).unwrap())
            .unwrap_or(json!({"pin":PIN,"version":version,"runs":[]}));
        let hash = hex::encode(bsv_rs::primitives::hash::sha256(
            &fs::read("harness/src/scenarios/utxo.rs").unwrap(),
        ));
        receipt["runs"].as_array_mut().unwrap().push(json!({"run_id":run_id,"kind":kind,"wall_seconds":start.elapsed().as_secs_f64(),"utxo_source_sha256":hash,"core_source_sha256":hex::encode(bsv_rs::primitives::hash::sha256(&fs::read("harness/src/scenarios/core.rs").unwrap())),"parent_commit":String::from_utf8(Command::new("git").args(["rev-parse","HEAD"]).output().unwrap().stdout).unwrap().trim(),"results":results}));
        write_json(Path::new(&receipt_path), &receipt).unwrap();
        let mut marks = BTreeMap::new();
        for r in &results {
            let mark = if let Some(rpc) = r.get("rpc_precheck") {
                format!(
                    "rpc-precheck: {} {} ({}) [X] {record}",
                    rpc["code"],
                    text(&rpc["message"]).unwrap(),
                    text(&rpc["source"]).unwrap()
                )
            } else if let Some(reason) = r["unrealizable"].as_str() {
                format!("unrealizable: {reason} [X] {record}")
            } else {
                measured_token(r, &record)
            };
            marks.insert(text(&r["id"]).unwrap().to_owned(), mark);
            println!(
                "{}: {} [X]",
                r["id"],
                r["verdict"]
                    .as_str()
                    .unwrap_or(if r.get("rpc_precheck").is_some() {
                        "rpc-precheck"
                    } else {
                        "unrealizable"
                    })
            );
        }
        mark_rows("utxo", &marks).unwrap();
    }
}
