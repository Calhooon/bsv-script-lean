//! [D] 2026-10-14, lane fix-73: #73 uses six dedicated assumevalid regtest
//! instances and two shared safe-mode instances, with ten safe-mode rows in
//! file order. Shared ignore/reconsider state is deliberate (see the recipe).
//! Sources: bitcoin-sv
//! 6504a3aff65ba97c0f6c80962b033e35ecbfed4b; src/validation.cpp:3482-3518 (the
//! script-check decision), src/safe_mode.cpp:58-115,324-405 (the fork predicates),
//! src/init.cpp:324-333 (the RPC refusal). The rows and their [D] expectations
//! are corpus/chain/depth/depth.jsonl; `chaincheck --depth` checks the same
//! expectations against lean/BsvChain/Depth.lean with no node.
//!
//! The skip is reached with RPC alone: every block is built here from the
//! regtest genesis block and handed over by `submitblock`. A side chain is
//! stored without its scripts being run until it has more work than the active
//! chain; the reorganization then connects its blocks with the side chain's tip
//! as the best header, which buries the block under test.
use super::core::*;

// [SRC] the regtest genesis block's hash, read from its corpus fixture (src/chainparams.cpp:1512-1515 at PIN;
// #107: a hash literal in harness/src is the mechanism check's to refuse, so the value lives in the corpus, cited).
const GENESIS_FIXTURE: &str = "corpus/chain/depth/regtest-genesis.json";
fn genesis() -> Result<[u8; 32]> {
    let text =
        fs::read_to_string(GENESIS_FIXTURE).map_err(|e| format!("{GENESIS_FIXTURE}: {e}"))?;
    let v: Value = serde_json::from_str(&text).map_err(|e| format!("{GENESIS_FIXTURE}: {e}"))?;
    txid_from_display_hex(v["hash"].as_str().ok_or("regtest genesis: no hash")?)
}
// [SRC] regtest's compact target: src/chainparams.cpp:1511 (the genesis block) at PIN.
const BITS: u32 = 0x207f_ffff;
// [D] the scenario clock: block times are T0 + height, the mock clock T0 + 4000.
const T0: u32 = 1_700_000_000;
// [D] the last common height of the two chains of an assumevalid row.
const FORK: u32 = 101;

fn source(method: &str) -> Result<&'static str> {
    Ok(match method {
        "submitblock" => "src/rpc/mining.cpp:916-952",
        "setmocktime" => "src/rpc/misc.cpp:980-1007",
        "getbestblockhash" => "src/rpc/blockchain.cpp:220-236",
        "getblockcount" => "src/rpc/blockchain.cpp:205-218",
        "getblockheader" => "src/rpc/blockchain.cpp:884-1038",
        "getchaintips" => "src/rpc/blockchain.cpp:2497-2632",
        "gettxout" => "src/rpc/blockchain.cpp:1923-2029",
        "sendrawtransaction" => "src/rpc/rawtransaction.cpp:1530-1672",
        "getsafemodeinfo" => "src/rpc/safe_mode.cpp:97-196",
        "ignoresafemodeforblock" => "src/rpc/safe_mode.cpp:12-51",
        "reconsidersafemodeforblock" => "src/rpc/safe_mode.cpp:53-95",
        _ => return Err(format!("depth RPC without pinned handler: {method}")),
    })
}
// One logged call: the result or the node's error object, never a panic.
fn rpc(n: &mut Node, method: &str, params: Value) -> Result<Value> {
    let reply = n
        .rpc
        .as_mut()
        .ok_or("RPC not ready")?
        .call(method, params.clone());
    let raw = match &reply {
        Ok(v) => json!({"result":v}),
        Err(e) => match e
            .strip_prefix("rpc error: ")
            .and_then(|s| serde_json::from_str::<Value>(s).ok())
        {
            Some(error) => json!({"error":error}),
            None => return Err(e.clone()),
        },
    };
    n.calls.push(json!({"method":method,"params":params,"source":format!("[SRC] {} at {PIN}",source(method)?),"reply":raw,"instance_id":instance_pointer(&n.dir)}));
    Ok(raw)
}
fn result(n: &mut Node, method: &str, params: Value) -> Result<Value> {
    let reply = rpc(n, method, params)?;
    match reply.get("error") {
        Some(error) => Err(format!("{method}: {error}")),
        None => Ok(reply["result"].clone()),
    }
}

#[derive(Clone)]
struct Built {
    hash: String,
    internal: [u8; 32],
    bytes: Vec<u8>,
    coinbase: RawTx,
}
// [SRC] regtest halves every 150 blocks: src/chainparams.cpp:1460 at PIN.
fn subsidy(height: u32) -> u64 {
    5_000_000_000u64 >> (height / 150)
}
// `count` blocks on `prev`, heights `start..`, the coinbase tagged so the two
// chains of a row never share a transaction; `extra` rides in the opening block.
fn chain(prev: [u8; 32], start: u32, count: u32, tag: &str, extra: &[RawTx]) -> Vec<Built> {
    let mut out: Vec<Built> = Vec::with_capacity(count as usize);
    let mut prev = prev;
    for height in start..start + count {
        let coinbase = block_codec::coinbase_tx(height, subsidy(height), script(), tag.as_bytes());
        let mut txs = vec![coinbase.clone()];
        if height == start {
            txs.extend(extra.iter().cloned());
        }
        let (header, bytes) = block_codec::assemble(4, prev, T0 + height, BITS, &txs);
        prev = header.hash();
        out.push(Built {
            hash: txid_display_hex(&prev),
            internal: prev,
            bytes,
            coinbase,
        });
    }
    out
}
// Hand over a run of blocks; the receipt keeps the count, the ends and the
// replies' tally, never 2,000 block bodies.
fn submit_all(n: &mut Node, label: &str, blocks: &[Built]) -> Result<()> {
    let mut tally: BTreeMap<String, u64> = BTreeMap::new();
    for b in blocks {
        let reply = n
            .rpc
            .as_mut()
            .ok_or("RPC not ready")?
            .call("submitblock", json!([hex::encode(&b.bytes)]));
        let key = match reply {
            Ok(v) => v.to_string(),
            Err(e) => e,
        };
        *tally.entry(key).or_default() += 1;
    }
    let digest = hex::encode(bsv_rs::primitives::hash::sha256(
        &blocks
            .iter()
            .flat_map(|b| b.bytes.clone())
            .collect::<Vec<u8>>(),
    ));
    n.calls.push(json!({"method":"submitblock","batch":label,"label":"[M]","count":blocks.len(),"from":blocks.first().map(|b|b.hash.clone()),"to":blocks.last().map(|b|b.hash.clone()),"bytes_sha256":digest,"replies":tally,"source":format!("[SRC] {} at {PIN}",source("submitblock")?),"instance_id":instance_pointer(&n.dir)}));
    Ok(())
}
// The node's own log lines about the decision and the failed connection.
fn console(n: &Node) -> Value {
    let log = fs::read_to_string(n.dir.join("console.log")).unwrap_or_default();
    let keep: Vec<String> = log
        .lines()
        .filter(|l| {
            l.contains("valid signatures")
                || l.contains("Validating signatures")
                || l.contains("nMinimumChainWork")
                || l.contains("ConnectBlock")
                || l.contains("InvalidChainFound: invalid block")
                || l.contains("Safe mode level changed")
        })
        .take(12)
        .map(|l| l.chars().take(400).collect())
        .collect();
    json!(keep)
}
struct Fixture {
    base: Vec<Built>,
    a: Vec<Built>,
    f: Vec<Built>,
    bad: RawTx,
}
// The two chains of the assumevalid rows. The side chain's opening block spends
// the height-1 coinbase with a signature that no longer covers its output: the
// script fails wherever it is run.
fn fixture(a_len: u32, f_len: u32) -> Result<Fixture> {
    let base = chain(genesis()?, 1, FORK, "s6-73 base", &[]);
    let tip = base.last().ok_or("empty base")?.internal;
    let mut bad = spend(&base[0].coinbase, subsidy(1) - 2000, 1);
    bad.outputs[0].satoshis -= 1;
    Ok(Fixture {
        a: chain(tip, FORK + 1, a_len, "s6-73 A", &[]),
        f: chain(tip, FORK + 1, f_len, "s6-73 F", &[bad.clone()]),
        base,
        bad,
    })
}
fn assumevalid_row(root: &Path, row: &Value, fx: &Fixture) -> Result<Value> {
    let setup = &row["setup"];
    let a_len = setup["a_blocks"].as_u64().ok_or("a_blocks")? as usize;
    let f_len = setup["f_blocks"].as_u64().ok_or("f_blocks")? as usize;
    if a_len > fx.a.len() || f_len > fx.f.len() || f_len != a_len + 1 {
        return Err("depth row outside the fixture".into());
    }
    let unknown = hex::encode(bsv_rs::primitives::hash::sha256(
        b"bsv-script-lean/s6-73/no such block",
    ));
    let assumed = match text(&setup["assumevalid"])? {
        "zero" => "0".to_owned(),
        "fork-tip" => fx.f[f_len - 1].hash.clone(),
        "active-tip" => fx.a[a_len - 1].hash.clone(),
        "unknown" => unknown,
        other => return Err(format!("assumevalid choice {other}")),
    };
    let mut extra = format!("assumevalid={assumed}\n");
    if let Some(work) = setup["minimumchainwork"].as_str() {
        extra.push_str(&format!("minimumchainwork={work}\n"));
    }
    let mut n = start_retry(root, text(&row["id"])?, &extra)?;
    result(&mut n, "setmocktime", json!([T0 + 4000]))?;
    submit_all(&mut n, "base", &fx.base)?;
    submit_all(&mut n, "active chain", &fx.a[..a_len])?;
    submit_all(&mut n, "side chain, stored", &fx.f[..f_len - 1])?;
    let before = result(&mut n, "getbestblockhash", json!([]))?;
    if before != json!(fx.a[a_len - 1].hash) {
        return Err(format!("side chain connected early: {before}"));
    }
    let overtaking = rpc(
        &mut n,
        "submitblock",
        json!([hex::encode(&fx.f[f_len - 1].bytes)]),
    )?;
    let best = result(&mut n, "getbestblockhash", json!([]))?;
    let height = result(&mut n, "getblockcount", json!([]))?;
    let tips = result(&mut n, "getchaintips", json!([]))?;
    let header = result(&mut n, "getblockheader", json!([fx.f[0].hash, true]))?;
    let coin = result(&mut n, "gettxout", json!([id(&fx.bad), 0]))?;
    let safe = result(&mut n, "getsafemodeinfo", json!([]))?;
    let name = |hash: &Value| {
        if *hash == json!(fx.a[a_len - 1].hash) {
            "A"
        } else if *hash == json!(fx.f[f_len - 1].hash) {
            "F"
        } else {
            "other"
        }
    };
    let side_status = tips
        .as_array()
        .ok_or("chain tips")?
        .iter()
        .find(|t| t["hash"] == json!(fx.f[f_len - 1].hash))
        .map(|t| t["status"].clone())
        .unwrap_or(Value::Null);
    let observed = json!({"tip":name(&best),"badBlockActive":header["confirmations"].as_i64().unwrap_or(-1)>0,"badOutputUnspent":!coin.is_null(),"sideTipStatus":side_status});
    let evidence = json!({"label":"[M]","height":height,"overtaking_submitblock":overtaking,"bad_block":fx.f[0].hash,"bad_tx":material(&fx.bad),"bad_block_height":FORK+1,"blocks_above_bad":f_len-1,"assumevalid":assumed,"safemodeenabled":safe["safemodeenabled"],"console":console(&n),"conf":n.conf});
    n.stop()?;
    Ok(measured(
        row,
        observed,
        row["expected"]["node"].clone(),
        "Every block built from the regtest genesis block and handed over by submitblock on a fresh instance launched with the row's -assumevalid (and -minimumchainwork where named): 101 common blocks, the active chain, then the side chain whose opening block spends the height-1 coinbase with a signature that does not cover its output. The side chain is stored unconnected until its last block gives it more work; the reorganization then connects the bad block with the side tip as best header. Compare the tip, the bad block's membership of the active chain, its output's presence and the side tip's status.",
        n.calls.clone(),
        evidence,
    ))
}
fn safe_view(reply: &Value, names: &BTreeMap<String, String>) -> Value {
    let name = |v: &Value| {
        v["hash"]
            .as_str()
            .and_then(|h| names.get(h))
            .cloned()
            .unwrap_or_else(|| "other".into())
    };
    let mut forks: Vec<Value> = reply["forks"]
        .as_array()
        .map(|forks| {
            forks
                .iter()
                .map(|f| {
                    let mut tips: Vec<String> = f["tips"]
                        .as_array()
                        .map(|t| t.iter().map(&name).collect())
                        .unwrap_or_default();
                    tips.sort();
                    json!({"base":name(&f["forkfirstblock"]),"tips":tips,"lastCommon":name(&f["lastcommonblock"])})
                })
                .collect()
        })
        .unwrap_or_default();
    forks.sort_by_key(|f| f.to_string());
    json!({"safemodeenabled":reply["safemodeenabled"],"forks":forks})
}
// A decodable transaction spending a coin that never existed: with safe mode
// off the node answers about the transaction, with it on the command is refused.
fn probe_tx() -> RawTx {
    RawTx {
        version: 1,
        inputs: vec![RawInput {
            txid: [0x73; 32],
            vout: 0,
            script: vec![],
            sequence: u32::MAX,
        }],
        outputs: vec![RawOutput {
            satoshis: 0,
            script: script(),
        }],
        lock_time: 0,
    }
}
fn refusal(n: &mut Node) -> Result<Value> {
    let reply = rpc(
        n,
        "sendrawtransaction",
        json!([hex::encode(probe_tx().encode())]),
    )?;
    let count = rpc(n, "getblockcount", json!([]))?;
    let error = reply.get("error").cloned().unwrap_or(Value::Null);
    let by_safe_mode = error["code"] == json!(-2);
    // The reply to the unsafe command when it is not refused stays in the call log.
    Ok(
        json!({"refused":by_safe_mode,"code":if by_safe_mode {error["code"].clone()} else {Value::Null},"message":if by_safe_mode {error["message"].clone()} else {Value::Null},"safeCommandAnswered":count.get("result").is_some()}),
    )
}
// One safe-mode instance: its steps are the rows that name it, in file order.
fn safemode_instance(root: &Path, instance: &str, rows: &[&Value]) -> Result<Vec<Value>> {
    let head = rows.first().ok_or("safe-mode instance without rows")?;
    let s = &head["setup"]["settings"];
    let extra = format!(
        "safemodemaxforkdistance={}\nsafemodeminforklength={}\nsafemodeminblockdifference={}\n",
        s["maxForkDistance"], s["minForkLength"], s["minPowDifference"]
    );
    let common = head["setup"]["common_height"]
        .as_u64()
        .ok_or("common_height")? as u32;
    let base = chain(genesis()?, 1, common, "s6-73 safe base", &[]);
    let tip = base.last().ok_or("empty base")?.internal;
    let a = chain(tip, common + 1, 40, "s6-73 safe A", &[]);
    let f = chain(tip, common + 1, 40, "s6-73 safe F", &[]);
    let mut names = BTreeMap::new();
    for (i, b) in base.iter().enumerate() {
        names.insert(b.hash.clone(), format!("C{}", i + 1));
    }
    for (i, b) in a.iter().enumerate() {
        names.insert(b.hash.clone(), format!("A{}", common as usize + 1 + i));
    }
    for (i, b) in f.iter().enumerate() {
        names.insert(b.hash.clone(), format!("F{}", common as usize + 1 + i));
    }
    let mut n = start_retry(root, instance, &extra)?;
    result(&mut n, "setmocktime", json!([T0 + 4000]))?;
    submit_all(&mut n, "base", &base)?;
    let (mut a_done, mut f_done) = (0usize, 0usize);
    let mut out = vec![];
    for row in rows {
        let offset = n.calls.len();
        let setup = &row["setup"];
        let a_want =
            (setup["active_height"].as_u64().ok_or("active_height")? as u32 - common) as usize;
        let f_want = setup["fork_blocks"].as_u64().ok_or("fork_blocks")? as usize;
        if a_want < a_done || f_want < f_done || a_want > a.len() || f_want > f.len() {
            return Err("safe-mode rows must only extend the chains".into());
        }
        submit_all(&mut n, "active chain", &a[a_done..a_want])?;
        submit_all(&mut n, "side chain", &f[f_done..f_want])?;
        (a_done, f_done) = (a_want, f_want);
        let block = |token: &Value| -> Result<String> {
            let token = text(token)?;
            names
                .iter()
                .find(|(_, name)| name.as_str() == token)
                .map(|(hash, _)| hash.clone())
                .ok_or_else(|| format!("unknown block name {token}"))
        };
        let mut operator = Value::Null;
        if let Some(target) = setup.get("ignore") {
            operator = rpc(&mut n, "ignoresafemodeforblock", json!([block(target)?]))?;
        }
        if let Some(target) = setup.get("reconsider") {
            operator = rpc(
                &mut n,
                "reconsidersafemodeforblock",
                json!([block(target)?]),
            )?;
        }
        let info = result(&mut n, "getsafemodeinfo", json!([]))?;
        let mut observed = safe_view(&info, &names);
        if row["case"] == "safemode-rpc" {
            observed = refusal(&mut n)?;
        }
        let best = result(&mut n, "getbestblockhash", json!([]))?;
        let tips = result(&mut n, "getchaintips", json!([]))?;
        let evidence = json!({"label":"[M]","active_tip":names.get(best.as_str().unwrap_or("")),"operator_reply":operator,"getsafemodeinfo":info,"chaintips":tips,"console":console(&n),"conf":n.conf});
        out.push(measured(
            row,
            observed,
            row["expected"]["node"].clone(),
            "A fresh instance launched with the row's three safe-mode settings; every block built from the regtest genesis block and handed over by submitblock: the common blocks, the active chain to the row's height, the side chain's stored blocks. The rows of one instance run in file order and only extend the chains. Read getsafemodeinfo (the forks by block name), or for an RPC row send a command registered as unsafe and one registered as safe.",
            n.calls[offset..].to_vec(),
            evidence,
        ));
    }
    n.stop()?;
    Ok(out)
}
// Rows the node cannot realize from outside at the pin, by name and source.
fn unrealizable(row: &Value) -> Option<&'static str> {
    match row["id"].as_str()? {
        "depth-checkpoint-mismatch" => Some("regtest's only checkpoint is its genesis block at height 0 and the table is compiled, with no launch input; no second header exists at height 0, since a header that is not the genesis block needs a known parent; src/chainparams.cpp:1530-1533; src/validation.cpp:5903-5930,6152-6177"),
        _ => None,
    }
}
pub(super) fn run(root: &Path, record: &str, write: bool) -> Result<Value> {
    let lean = Command::new("lean/.lake/build/bin/chaincheck")
        .args(["--depth", "corpus/chain/depth/depth.jsonl"])
        .output()
        .map_err(|e| e.to_string())?;
    if !lean.status.success() {
        return Err(format!(
            "Lean depth replay: {}{}",
            String::from_utf8_lossy(&lean.stdout),
            String::from_utf8_lossy(&lean.stderr)
        ));
    }
    let rows = row_read("depth")?;
    let start = Instant::now();
    let (mut a_max, mut f_max) = (0u32, 0u32);
    for row in rows.iter().filter(|r| r["case"] == "assumevalid") {
        a_max = a_max.max(row["setup"]["a_blocks"].as_u64().ok_or("a_blocks")? as u32);
        f_max = f_max.max(row["setup"]["f_blocks"].as_u64().ok_or("f_blocks")? as u32);
    }
    let fx = fixture(a_max, f_max)?;
    let mut results = vec![];
    for row in rows.iter().filter(|r| r["case"] == "assumevalid") {
        results.push(assumevalid_row(root, row, &fx)?);
        println!(
            "node-scenarios depth: {} done at [M] {:.1}s",
            row["id"],
            start.elapsed().as_secs_f64()
        );
    }
    let mut instances: Vec<&str> = vec![];
    for row in rows.iter().filter(|r| r["setup"].get("instance").is_some()) {
        let instance = text(&row["setup"]["instance"])?;
        if !instances.contains(&instance) {
            instances.push(instance);
        }
    }
    for instance in instances {
        let group: Vec<&Value> = rows
            .iter()
            .filter(|r| r["setup"]["instance"] == json!(instance))
            .collect();
        results.extend(safemode_instance(root, instance, &group)?);
        println!(
            "node-scenarios depth: {instance} done at [M] {:.1}s",
            start.elapsed().as_secs_f64()
        );
    }
    for row in &rows {
        if let Some(reason) = unrealizable(row) {
            results.push(json!({"id":row["id"],"unrealizable":reason,"label":"[X]"}));
        }
    }
    let mut marks = BTreeMap::new();
    for r in &results {
        let mark = match r["unrealizable"].as_str() {
            Some(reason) => format!("unrealizable: {reason} [X] {record}"),
            None => measured_token(r, record),
        };
        marks.insert(text(&r["id"])?.to_owned(), mark);
    }
    let count = |verdict: &str| results.iter().filter(|r| r["verdict"] == verdict).count();
    let counts = json!({"label":"[M]","rows":rows.len(),"realized":count("agree")+count("diverge"),"agree":count("agree"),"diverge":count("diverge"),"unrealizable":results.iter().filter(|r|r.get("unrealizable").is_some()).count(),"pending":rows.len()-results.len(),"lean_projection":String::from_utf8_lossy(&lean.stderr).trim(),"wall_seconds":start.elapsed().as_secs_f64()});
    println!("node-scenarios depth: {counts}");
    if write {
        mark_rows("depth", &marks)?;
    }
    Ok(json!({"counts":counts,"rows":results}))
}
