//! #70 frozen outputs and the confiscation whitelist: operator lists installed
//! through the freeze RPCs on fresh regtest instances, every row policy
//! (operator data). Sources: bitcoin-sv 6504a3aff65ba97c0f6c80962b033e35ecbfed4b;
//! src/frozentxo.cpp:27-171, src/frozentxo_db.h:179-377,
//! src/rpc/frozentxo_rpc.cpp:320-910, src/validation.cpp:1320-1482,2552-2665,
//! 3376-3411,3529-3555,3720-3740; docs/DESIGN-S6.md section 1.5.
use super::core::*;

// The freeze RPCs have their own handlers; the shared table stays untouched.
// These recipes call five of the eight handlers registered at
// src/rpc/frozentxo_rpc.cpp:903-910; removeFromPolicyBlacklist, clearBlacklists
// and clearConfiscationWhitelist are not called by any row.
fn operator(n: &mut Node, method: &str, params: Value) -> Result<Value> {
    let source = match method {
        "addToPolicyBlacklist" => "src/rpc/frozentxo_rpc.cpp:320-344",
        "addToConsensusBlacklist" => "src/rpc/frozentxo_rpc.cpp:346-378",
        "queryBlacklist" => "src/rpc/frozentxo_rpc.cpp:404-499",
        "addToConfiscationTxidWhitelist" => "src/rpc/frozentxo_rpc.cpp:632-764",
        "queryConfiscationTxidWhitelist" => "src/rpc/frozentxo_rpc.cpp:799-894",
        "getblockheader" => "src/rpc/blockchain.cpp:884-1038",
        _ => return Err(format!("unsupported frozen-family RPC {method}")),
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
    n.calls.push(json!({"method":method,"params":params,"source":format!("[SRC] {source} at {PIN}"),"reply":raw,"instance_id":instance_pointer(&n.dir)}));
    answer
}

fn listed(n: &mut Node, method: &str, params: Value) -> Result<()> {
    let reply = operator(n, method, params)?;
    if reply["notProcessed"] != json!([]) {
        return Err(format!("{method}: {reply}"));
    }
    Ok(())
}

// The core probe binds loopback sockets exclusively; a raced launch retries in a
// fresh directory.
fn start_owned(root: &Path, tag: &str) -> Result<Node> {
    for attempt in 0..20 {
        match Node::start(
            root.join(format!("frozen-{tag}-{attempt}")),
            1_000_001,
            "genesisactivationheight=10\nchronicleactivationheight=20\n",
        ) {
            Ok(n) => return Ok(n),
            Err(e) if e.contains("bind") || e.contains("no free RPC/P2P pair") => {
                thread::sleep(Duration::from_millis(100));
            }
            Err(e) => return Err(e),
        }
    }
    Err("exclusive loopback probe exhausted after launch retries".into())
}

// Tip 102: block 102 holds F (from block 1's coinbase) and F2 (from block 2's),
// each 100000 satoshis to the harness key.
struct Base {
    f: RawTx,
    f2: RawTx,
    clock: u32,
}
fn base(n: &mut Node, tag: &str) -> Result<Base> {
    let hashes = n.mine(101, 1_699_990_000)?;
    let b1 = n.call("getblock", json!([hashes[0], 1]))?;
    let b2 = n.call("getblock", json!([hashes[1], 1]))?;
    let c1 = n.raw_tx(&b1["tx"][0])?;
    let c2 = n.raw_tx(&b2["tx"][0])?;
    let f = spend(&c1, 100_000, 1);
    let f2 = spend(&c2, 100_000, 1);
    let (_, reply) = n.submit(&[cb(102, tag), f.clone(), f2.clone()], 1_699_995_000)?;
    if block_judgment(&reply)["status"] != "ok" {
        return Err(format!("{tag} funding: {reply}"));
    }
    Ok(Base {
        f,
        f2,
        clock: 1_699_995_000,
    })
}

fn name_of(names: &[(String, &str)], txid: &Value) -> String {
    names
        .iter()
        .find(|(id, _)| Some(id.as_str()) == txid.as_str())
        .map(|(_, name)| (*name).to_owned())
        .unwrap_or_else(|| format!("unnamed {txid}"))
}

// queryBlacklist projected to the row's names, sorted by name.
fn blacklist_view(n: &mut Node, names: &[(String, &str)]) -> Result<Value> {
    let raw = operator(n, "queryBlacklist", json!([]))?;
    let mut funds = vec![];
    for fund in raw["funds"].as_array().ok_or("queryBlacklist funds")? {
        let mut view = json!({"txOut":format!("{}:{}", name_of(names, &fund["txOut"]["txId"]), fund["txOut"]["vout"]),
            "blacklist":fund["blacklist"]});
        if fund.get("enforceAtHeight").is_some() {
            view["enforceAtHeight"] = fund["enforceAtHeight"].clone();
            view["policyExpiresWithConsensus"] = fund["policyExpiresWithConsensus"].clone();
        }
        funds.push(view);
    }
    funds.sort_by_key(|f| f["txOut"].as_str().unwrap_or("").to_owned());
    Ok(json!({"funds":funds}))
}

// queryConfiscationTxidWhitelist (verbose) projected to the row's names.
fn whitelist_view(n: &mut Node, names: &[(String, &str)]) -> Result<Value> {
    let raw = operator(n, "queryConfiscationTxidWhitelist", json!([true]))?;
    let mut txs = vec![];
    for entry in raw["confiscationTxs"]
        .as_array()
        .ok_or("whitelist entries")?
    {
        let tx = &entry["confiscationTx"];
        let inputs: Vec<String> = tx["inputs"]
            .as_array()
            .ok_or("whitelist inputs")?
            .iter()
            .map(|i| {
                format!(
                    "{}:{}",
                    name_of(names, &i["txOut"]["txId"]),
                    i["txOut"]["vout"]
                )
            })
            .collect();
        txs.push(json!({"txId":name_of(names, &tx["txId"]),"enforceAtHeight":tx["enforceAtHeight"],"inputs":inputs}));
    }
    Ok(json!({"confiscationTxs":txs}))
}

// Admission through sendrawtransaction: accepted, or the node's verdict.
// [SRC] src/rpc/rawtransaction.cpp:1530-1672 at PIN.
fn admit(n: &mut Node, tx: &RawTx) -> Result<Value> {
    let reply = n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
    if reply["result"] == json!(id(tx)) {
        return Ok(json!({"status":"ok"}));
    }
    let reject = node_reject(&reply).ok_or("admission receipt")?;
    if reject["namespace"] == "node" {
        Ok(json!({"status":"rejected","reason":reject["reason"],"code":reject["code"]}))
    } else {
        Ok(json!({"status":"rpc-error","error":reply["error"]}))
    }
}

// A block on the active tip: connected as the new tip, or refused with the
// header's soft consensus freeze mark. [SRC] src/rpc/mining.cpp:916-952;
// src/validation.cpp:2460-2471,3402-3407 at PIN.
fn connect(n: &mut Node, txs: &[RawTx], time: u32) -> Result<(String, Value)> {
    let (hash, reply) = n.submit(txs, time)?;
    if reply.get("error").is_some() {
        return Ok((hash, json!({"status":"rpc-error","error":reply["error"]})));
    }
    if reply["result"].is_null() && n.call("getbestblockhash", json!([]))? == json!(hash) {
        return Ok((hash, json!({"status":"ok"})));
    }
    let header = operator(n, "getblockheader", json!([hash, true]))?;
    Ok((
        hash,
        json!({"status":"rejected","reason":reply["result"],
        "softFreeze":header["status"]["soft consensus frozen"] == true}),
    ))
}

// The confiscation transaction of the rows: output 0 the protocol marker
// (OP_FALSE OP_RETURN 'cftx', version 1, a 20-byte order hash), output 1 to the
// harness key; its input F carries no unlock script.
// [SRC] src/frozentxo_db.cpp:614-717 at PIN.
fn confiscation(f: &RawTx) -> RawTx {
    let mut marker = vec![0x00, 0x6a, 0x04, 0x63, 0x66, 0x74, 0x78, 21, 1];
    marker.extend([0xab; 20]);
    RawTx {
        version: 1,
        inputs: vec![RawInput {
            txid: f.txid_internal(),
            vout: 0,
            script: vec![],
            sequence: u32::MAX,
        }],
        outputs: vec![
            RawOutput {
                satoshis: 0,
                script: marker,
            },
            RawOutput {
                satoshis: 99_000,
                script: script(),
            },
        ],
        lock_time: 0,
    }
}

fn row<'a>(rows: &'a [Value], id: &str) -> Result<&'a Value> {
    rows.iter()
        .find(|r| r["id"] == id)
        .ok_or_else(|| format!("frozen row {id} absent"))
}

fn record(
    out: &mut Vec<Value>,
    rows: &[Value],
    id: &str,
    observed: Value,
    recipe: &str,
    n: &mut Node,
    fixtures: Value,
) -> Result<()> {
    let r = row(rows, id)?;
    out.push(measured(
        r,
        observed,
        r["expected"].clone(),
        recipe,
        std::mem::take(&mut n.calls),
        fixtures,
    ));
    Ok(())
}

const POLICY: &str = "Fresh regtest instance, tip 102 holding F. addToPolicyBlacklist lists F. sendrawtransaction offers T (F to the harness key, 1000-satoshi fee) at mempool height 103; a block at 103 then carries T. Admission reports the node's verdict and code; the block reports connection as the new tip. Every list is operator data (policy). [SRC] src/frozentxo.cpp:52-75; src/validation.cpp:1320-1348,2594-2607 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.";
const RANGED: &str = "Fresh regtest instance, tip 102 holding F and F2. addToConsensusBlacklist lists F and F2 with enforceAtHeight [103, 105), F's policy freeze expiring with it and F2's not. T spends F, T2 spends F2. Inside: admission at height 103 and a block at 103 carrying T. Two blocks are mined (tip 104). Outside: admission of T and T2 at height 105, then blocks at 105 (T) and 106 (T2). A refused block reports the header's soft consensus freeze mark. Every list is operator data (policy). [SRC] src/frozentxo_db.h:323-377; src/frozentxo.cpp:52-75; src/validation.cpp:2594-2607,3402-3407 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.";
const RELEASE: &str = "Fresh regtest instance, tip 102 holding F; the default soft consensus freeze duration (3). addToConsensusBlacklist lists F from height 0 with no stop. Block A at 103 carries T and is refused into a soft consensus freeze; coinbase-only blocks B, C, D, E at 104 to 107 are built on A. E's arrival leaves the tip outside the freeze and the chain through A activates: A's second connection runs with the explicit freeze, the frozen check a no-op. Observed: E the best block, A connected (confirmations), F spent. Operator data (policy). [SRC] src/frozentxo.cpp:39-42; src/block_index.h:542-580; src/validation.cpp:3402-3407,3720-3740 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.";
const WHITELIST: &str = "Fresh regtest instance, tip 102 holding F. addToConsensusBlacklist lists F from height 0 with no stop; CTX is a valid confiscation transaction spending F (protocol marker output 0, 99000 satoshis to the harness key). Unlisted: admission at 103 and a block at 103 carrying CTX. addToConfiscationTxidWhitelist lists CTX at enforceAtHeight 105 (F moves to the confiscation list). Below 105: admission and a block at 103. An ordinary spend T of F: admission and a block at 103. Two blocks are mined (tip 104). At 105: admission of CTX, then a block at 105 carrying it. Every list is operator data (policy). [SRC] src/frozentxo.cpp:133-171; src/frozentxo_db.cpp:720-800; src/validation.cpp:2562-2611 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.";

fn policy(root: &Path, rows: &[Value], out: &mut Vec<Value>) -> Result<()> {
    let mut n = start_owned(root, "policy")?;
    let b = base(&mut n, "frozen-policy")?;
    let t = spend(&b.f, 99_000, 1);
    let names = vec![(id(&b.f), "F"), (id(&b.f2), "F2")];
    listed(
        &mut n,
        "addToPolicyBlacklist",
        json!([{"funds":[{"txOut":{"txId":id(&b.f),"vout":0}}]}]),
    )?;
    let view = blacklist_view(&mut n, &names)?;
    record(
        out,
        rows,
        "frozen/policy-query",
        view,
        POLICY,
        &mut n,
        json!({"F":material(&b.f)}),
    )?;
    let observed = admit(&mut n, &t)?;
    record(
        out,
        rows,
        "frozen/policy-admission",
        observed,
        POLICY,
        &mut n,
        json!({"T":material(&t)}),
    )?;
    let (hash, observed) = connect(
        &mut n,
        &[cb(103, "frozen-policy"), t.clone()],
        b.clock + 100,
    )?;
    record(
        out,
        rows,
        "frozen/policy-block",
        observed,
        POLICY,
        &mut n,
        json!({"T":material(&t),"block":hash}),
    )?;
    n.stop()
}

fn ranged(root: &Path, rows: &[Value], out: &mut Vec<Value>) -> Result<()> {
    let mut n = start_owned(root, "ranged")?;
    let b = base(&mut n, "frozen-ranged")?;
    let t = spend(&b.f, 99_000, 1);
    let t2 = spend(&b.f2, 99_000, 1);
    let names = vec![(id(&b.f), "F"), (id(&b.f2), "F2")];
    listed(
        &mut n,
        "addToConsensusBlacklist",
        json!([{"funds":[
        {"txOut":{"txId":id(&b.f),"vout":0},"enforceAtHeight":[{"start":103,"stop":105}],"policyExpiresWithConsensus":true},
        {"txOut":{"txId":id(&b.f2),"vout":0},"enforceAtHeight":[{"start":103,"stop":105}],"policyExpiresWithConsensus":false}]}]),
    )?;
    let view = blacklist_view(&mut n, &names)?;
    record(
        out,
        rows,
        "frozen/ranged-query",
        view,
        RANGED,
        &mut n,
        json!({"F":material(&b.f),"F2":material(&b.f2)}),
    )?;
    let observed = admit(&mut n, &t)?;
    record(
        out,
        rows,
        "frozen/ranged-admission-inside",
        observed,
        RANGED,
        &mut n,
        json!({"T":material(&t)}),
    )?;
    let (hash, observed) = connect(
        &mut n,
        &[cb(103, "frozen-ranged"), t.clone()],
        b.clock + 100,
    )?;
    record(
        out,
        rows,
        "frozen/ranged-block-inside",
        observed,
        RANGED,
        &mut n,
        json!({"T":material(&t),"block":hash}),
    )?;
    n.mine(2, (b.clock + 200) as u64)?;
    let observed = admit(&mut n, &t)?;
    record(
        out,
        rows,
        "frozen/ranged-admission-outside",
        observed,
        RANGED,
        &mut n,
        json!({"T":material(&t)}),
    )?;
    let observed = admit(&mut n, &t2)?;
    record(
        out,
        rows,
        "frozen/ranged-noexpiry-admission-outside",
        observed,
        RANGED,
        &mut n,
        json!({"T2":material(&t2)}),
    )?;
    let (hash, observed) = connect(
        &mut n,
        &[cb(105, "frozen-ranged"), t.clone()],
        b.clock + 1000,
    )?;
    record(
        out,
        rows,
        "frozen/ranged-block-outside",
        observed,
        RANGED,
        &mut n,
        json!({"T":material(&t),"block":hash}),
    )?;
    let (hash, observed) = connect(
        &mut n,
        &[cb(106, "frozen-ranged"), t2.clone()],
        b.clock + 1100,
    )?;
    record(
        out,
        rows,
        "frozen/ranged-noexpiry-block-outside",
        observed,
        RANGED,
        &mut n,
        json!({"T2":material(&t2),"block":hash}),
    )?;
    n.stop()
}

fn release(root: &Path, rows: &[Value], out: &mut Vec<Value>) -> Result<()> {
    let mut n = start_owned(root, "release")?;
    let b = base(&mut n, "frozen-release")?;
    let t = spend(&b.f, 99_000, 1);
    listed(
        &mut n,
        "addToConsensusBlacklist",
        json!([{"funds":[
        {"txOut":{"txId":id(&b.f),"vout":0},"enforceAtHeight":[{"start":0}],"policyExpiresWithConsensus":false}]}]),
    )?;
    let tip = n.tip()?;
    let base_hash = text(&tip["hash"])?.to_owned();
    let bits = u32::from_str_radix(text(&tip["bits"])?, 16).map_err(|e| e.to_string())?;
    let mut prev = txid_from_display_hex(&base_hash)?;
    let mut hashes = vec![];
    let mut replies = vec![];
    for (k, height) in (103u32..=107).enumerate() {
        let time = b.clock + 100 * (k as u32 + 1);
        let txs = if height == 103 {
            vec![cb(height, "frozen-release"), t.clone()]
        } else {
            vec![cb(height, "frozen-release")]
        };
        let (header, bytes) = block_codec::assemble(4, prev, time, bits, &txs);
        n.call("setmocktime", json!([time]))?;
        replies.push(n.receipt("submitblock", json!([hex::encode(&bytes)]))?);
        prev = header.hash();
        hashes.push(txid_display_hex(&prev));
    }
    let a = operator(&mut n, "getblockheader", json!([hashes[0], true]))?;
    let best = n.call("getbestblockhash", json!([]))?;
    let spent = n.call("gettxout", json!([id(&b.f), 0, false]))?;
    let connected = best == json!(hashes[4])
        && a["confirmations"].as_i64().unwrap_or(-1) > 0
        && a["status"]["soft consensus frozen"] == true
        && spent.is_null();
    let observed = if connected {
        json!({"status":"ok"})
    } else {
        json!({"status":"not-connected","best":best,"A":a,"F":spent})
    };
    record(
        out,
        rows,
        "frozen/explicit-freeze-noop",
        observed,
        RELEASE,
        &mut n,
        json!({"T":material(&t),"blocks":hashes,"submit_replies":replies,"A_header":a}),
    )?;
    n.stop()
}

fn whitelist(root: &Path, rows: &[Value], out: &mut Vec<Value>) -> Result<()> {
    let mut n = start_owned(root, "whitelist")?;
    let b = base(&mut n, "frozen-whitelist")?;
    let t = spend(&b.f, 99_000, 1);
    let ctx = confiscation(&b.f);
    let names = vec![(id(&b.f), "F"), (id(&b.f2), "F2"), (id(&ctx), "CTX")];
    listed(
        &mut n,
        "addToConsensusBlacklist",
        json!([{"funds":[
        {"txOut":{"txId":id(&b.f),"vout":0},"enforceAtHeight":[{"start":0}],"policyExpiresWithConsensus":false}]}]),
    )?;
    let observed = admit(&mut n, &ctx)?;
    record(
        out,
        rows,
        "whitelist/unlisted-admission",
        observed,
        WHITELIST,
        &mut n,
        json!({"F":material(&b.f),"CTX":material(&ctx)}),
    )?;
    let (hash, observed) = connect(
        &mut n,
        &[cb(103, "whitelist-unlisted"), ctx.clone()],
        b.clock + 100,
    )?;
    record(
        out,
        rows,
        "whitelist/unlisted-block",
        observed,
        WHITELIST,
        &mut n,
        json!({"CTX":material(&ctx),"block":hash}),
    )?;
    listed(
        &mut n,
        "addToConfiscationTxidWhitelist",
        json!([{"confiscationTxs":[{"confiscationTx":{"enforceAtHeight":105,"hex":hex::encode(ctx.encode())}}]}]),
    )?;
    let mut view = whitelist_view(&mut n, &names)?;
    view["blacklist"] = blacklist_view(&mut n, &names)?["funds"].clone();
    record(
        out,
        rows,
        "whitelist/query",
        view,
        WHITELIST,
        &mut n,
        json!({"CTX":material(&ctx)}),
    )?;
    let observed = admit(&mut n, &ctx)?;
    record(
        out,
        rows,
        "whitelist/below-enforce-admission",
        observed,
        WHITELIST,
        &mut n,
        json!({"CTX":material(&ctx)}),
    )?;
    let (hash, observed) = connect(
        &mut n,
        &[cb(103, "whitelist-below"), ctx.clone()],
        b.clock + 200,
    )?;
    record(
        out,
        rows,
        "whitelist/below-enforce-block",
        observed,
        WHITELIST,
        &mut n,
        json!({"CTX":material(&ctx),"block":hash}),
    )?;
    let observed = admit(&mut n, &t)?;
    record(
        out,
        rows,
        "whitelist/confiscated-ordinary-admission",
        observed,
        WHITELIST,
        &mut n,
        json!({"T":material(&t)}),
    )?;
    let (hash, observed) = connect(
        &mut n,
        &[cb(103, "whitelist-ordinary"), t.clone()],
        b.clock + 300,
    )?;
    record(
        out,
        rows,
        "whitelist/confiscated-ordinary-block",
        observed,
        WHITELIST,
        &mut n,
        json!({"T":material(&t),"block":hash}),
    )?;
    n.mine(2, (b.clock + 400) as u64)?;
    let observed = admit(&mut n, &ctx)?;
    record(
        out,
        rows,
        "whitelist/at-enforce-admission",
        observed,
        WHITELIST,
        &mut n,
        json!({"CTX":material(&ctx)}),
    )?;
    let (hash, mut observed) = connect(
        &mut n,
        &[cb(105, "whitelist-at"), ctx.clone()],
        b.clock + 1000,
    )?;
    if observed["status"] == "ok" {
        let coin = n.call("gettxout", json!([id(&ctx), 1, false]))?;
        if coin["confiscation"] != true {
            observed = json!({"status":"ok-without-confiscation-bit","coin":coin});
        }
    }
    record(
        out,
        rows,
        "whitelist/at-enforce-block",
        observed,
        WHITELIST,
        &mut n,
        json!({"CTX":material(&ctx),"block":hash}),
    )?;
    n.stop()
}

pub(super) fn run(root: &Path) -> Result<Vec<Value>> {
    let rows = row_read("frozen")?;
    let mut out = vec![];
    policy(root, &rows, &mut out)?;
    ranged(root, &rows, &mut out)?;
    release(root, &rows, &mut out)?;
    whitelist(root, &rows, &mut out)?;
    Ok(out)
}
