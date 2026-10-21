//! #79 (S7, lane s7-79): compact blocks between two fresh regtest instances,
//! on #78's machine and harness (B dials A, `addnode onetry`). A takes four
//! blocks by `submitblock`: the coinbase alone, two transactions both pools
//! hold, one held and one never relayed, two never relayed. B, out of its
//! initial download, hears each by `headers`, asks for it as a compact block
//! (`getdata` MSG_CMPCT_BLOCK) and reconstructs it from its pool, asking with
//! `getblocktxn` for what it lacks. The reference's test peer PA on A asks for
//! each block the same way and logs the frames byte for byte (`cmpctblock`,
//! `blocktxn`, and A's `sendcmpct`). The receipt is observations only; the
//! judging is the Lean function's (`chaincheck --compact`,
//! lean/Test/CompactCheck.lean), which reads the frames back, rebuilds the
//! message from the block, runs the reconstruction on B's pool and compares
//! with B's log and byte counters. Sources: bitcoin-sv 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
use super::core::*;
use super::peer::Peer;
use super::relay::{
    console_len, console_since, counters, identity, p2p_port, pool, ports, received, record_run,
    wait_pool,
};

const SCENARIO: &str = "corpus/scenarios/2026-10-15-compact-blocks-two-node.md";
// [D] 2026-10-15: the P2P port bound to the loopback range; the logging
// categories of the net layer and of compact blocks (`cmpctblock`,
// BCLog::CMPCTBLOCK). [SRC] src/logging.cpp:62,75-78 at PIN.
const CONF: &str =
    "listen=1\nbind=127.0.0.1:{P2P_PORT}\ndebug=net\ndebug=netmsg\ndebug=cmpctblock\n";

// [SRC] the reconstruction's log lines (src/blockencodings.cpp:236-239,
// 301-313) and the net layer's per-message lines for the three commands at PIN.
const LOG_KEYS: [&str; 6] = [
    "PartiallyDownloadedBlock",
    "Successfully reconstructed",
    "Reconstructed block",
    "cmpctblock",
    "getblocktxn",
    "blocktxn",
];

// B's pool, each transaction's id and bytes, in getrawmempool's order.
fn pool_view(n: &mut Node) -> Result<Vec<Value>> {
    let ids = n.call("getrawmempool", json!([]))?;
    let mut out = vec![];
    for id in ids.as_array().ok_or("getrawmempool")? {
        let hex = n.call("getrawtransaction", json!([id, 0]))?;
        out.push(json!({"txid":id,"hex":hex}));
    }
    Ok(out)
}

fn wait_tip(n: &mut Node, hash: &str, secs: u64) -> Result<bool> {
    let start = Instant::now();
    while start.elapsed() < Duration::from_secs(secs) {
        if n.call("getbestblockhash", json!([]))? == hash {
            return Ok(true);
        }
        thread::sleep(Duration::from_millis(200));
    }
    Ok(false)
}

struct Case<'a> {
    id: &'a str,
    txs: Vec<&'a RawTx>,
    relayed: Vec<&'a RawTx>,
    ask: Vec<usize>,
}

pub(super) fn run(root: &Path) -> Result<Value> {
    let (binary, test_peer) = identity()?;
    let mut a = start_retry_build(root, "compact-a", 1_000_001, CONF, Build::Record)?;
    let (f, t1, funding) = seed(&mut a)?;
    let mut b = start_retry_build(root, "compact-b", 1_000_001, CONF, Build::Record)?;
    b.clock_receipt(a.clock)?;
    let a_port = p2p_port(&a)?;
    b.call("addnode", json!([format!("127.0.0.1:{a_port}"), "onetry"]))?;
    let target = a.call("getbestblockhash", json!([]))?;
    let start = Instant::now();
    while b.call("getbestblockhash", json!([]))? != target {
        if start.elapsed() > Duration::from_secs(90) {
            return Err("B did not reach A's tip".into());
        }
        thread::sleep(Duration::from_millis(250));
    }
    let mut pa = Peer::start(&mut a)?;
    let t2 = spend(&t1, 98000, 1);
    let t3 = spend(&t2, 97000, 1);
    let t4 = spend(&t3, 96000, 1);
    let t5 = spend(&t4, 95000, 1);
    let t6 = spend(&t5, 94000, 1);
    let mut names = BTreeMap::new();
    for (k, tx) in [
        ("F", &f),
        ("T1", &t1),
        ("T2", &t2),
        ("T3", &t3),
        ("T4", &t4),
        ("T5", &t5),
        ("T6", &t6),
    ] {
        names.insert(
            k.to_owned(),
            json!({"txid":id(tx),"hex":hex::encode(tx.encode())}),
        );
    }
    let cases = [
        Case {
            id: "k0-coinbase-only",
            txs: vec![],
            relayed: vec![],
            ask: vec![],
        },
        Case {
            id: "k1-has-all",
            txs: vec![&t1, &t2],
            relayed: vec![&t1, &t2],
            ask: vec![1],
        },
        Case {
            id: "k2-has-part",
            txs: vec![&t3, &t4],
            relayed: vec![&t3],
            ask: vec![2],
        },
        Case {
            id: "k3-lacks-all",
            txs: vec![&t5, &t6],
            relayed: vec![],
            ask: vec![1, 2],
        },
    ];
    let mut steps = vec![];
    let mut time = a.clock;
    let mut height = b
        .call("getblockcount", json!([]))?
        .as_u64()
        .ok_or("height")? as u32;
    for case in &cases {
        // The relayed transactions reach both pools; the others never leave the runner.
        for tx in &case.relayed {
            a.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
        }
        let relayed: Vec<String> = case.relayed.iter().map(|tx| id(tx)).collect();
        let b_has = wait_pool(&mut b, &relayed, 20)?;
        thread::sleep(Duration::from_secs(1));
        let b_pool = pool_view(&mut b)?;
        let (cb_before, lb) = (counters(&mut b)?, console_len(&b)?);
        time += 1;
        height += 1;
        b.call("setmocktime", json!([time]))?;
        let mut body = vec![cb(height, case.id)];
        body.extend(case.txs.iter().map(|tx| (*tx).clone()));
        let (hash, submitted) = a.submit(&body, time as u32)?;
        let b_tip = wait_tip(&mut b, &hash, 30)?;
        thread::sleep(Duration::from_secs(1));
        let block = a.call("getblock", json!([hash, 0]))?;
        // PA asks A for the same block as a compact block, then for some of its transactions.
        let c0 = pa.getdata_cmpct(&hash)?;
        let got = pa.expect("cmpctblock", &hash, c0, 15.0)?;
        let mut txn = json!(null);
        if !case.ask.is_empty() {
            let c1 = pa.getblocktxn(&hash, &case.ask)?;
            txn = pa.expect("blocktxn", &hash, c1, 15.0)?["matched"].clone();
        }
        steps.push(json!({"id":case.id,"height":height,"time":time,"block":{"hash":hash,"hex":block},
            "submitted":block_judgment(&submitted),"relayed":relayed,"b_pool_has_relayed":b_has,"b_pool":b_pool,
            "b_tip_reached":b_tip,"pa_ask":case.ask,"pa_expect_cmpctblock":got["matched"],"pa_expect_blocktxn":txn,
            "counters_before":{"b":cb_before},"counters_after":{"b":counters(&mut b)?},
            "b_console":console_since(&b, lb, &LOG_KEYS)?,"pool_after":{"a":pool(&mut a)?,"b":pool(&mut b)?}}));
    }
    let frames: Vec<Value> = received(&a, "peer", 0)?
        .into_iter()
        .map(|e| json!({"source":"A>PA","command":e["command"],"hash":e["hash"],"hex":e["frame"]}))
        .collect();
    let ports = json!({"a":ports(&a)?,"b":ports(&b)?});
    drop(pa);
    a.stop()?;
    b.stop()?;
    let rpc = json!({"a":a.calls,"b":b.calls});
    Ok(
        json!({"scenario":SCENARIO,"source_pin":PIN,"binary":binary,"test_peer":test_peer,"ports":ports,
        "settings":{"excessiveblocksize":1_000_001,"maxblocktxnpercent":"default 99","blockreconstructionextratxn":"default 100"},
        "funding_block":funding,"names":names,"steps":steps,"frames":frames,"rpc":rpc}),
    )
}

pub(super) fn main(record: &str, run_id: Option<String>) -> Result<()> {
    let start = Instant::now();
    let out = record_run(
        record,
        "-s7-79-compact-blocks-s1.md",
        "compact-79",
        run_id,
        run,
    )?;
    println!(
        "compact node: observed [X] ({} blocks; wall [M] {:.3}s); judged by chaincheck --compact",
        out["steps"].as_array().map_or(0, Vec::len),
        start.elapsed().as_secs_f64()
    );
    Ok(())
}
