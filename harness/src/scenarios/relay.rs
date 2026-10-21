//! #78 (S7, lane s7-78): two fresh regtest instances, one connection between
//! them (B dials A, `addnode onetry`), and the reference's loopback test peer
//! on each (PA on A, PB on B) logging every message it receives. The scenario
//! (corpus/scenarios/2026-10-15-p2p-relay-two-node.md) drives the initial
//! block download gate, a relay A to B, an orphan's parent fetched, an
//! internal reject code kept off the wire, a reject with a misbehavior score
//! that disconnects a local peer, and a ban with no increment. The receipt is
//! observations only; the judging is the Lean machine's (`chaincheck --p2p`,
//! lean/Test/P2PCheck.lean), which runs lean/BsvChain/Wire/Relay.lean over the
//! declared stimuli and compares. Sources: bitcoin-sv 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
use super::core::*;
use super::peer::Peer;
use std::io::{Read, Write};
use std::net::TcpStream;

const SCENARIO: &str = "corpus/scenarios/2026-10-15-p2p-relay-two-node.md";
// [D] 2026-10-15: the default ban score (100) on both instances; the P2P port
// bound to the loopback range; the logging categories of the net layer.
// [SRC] src/init.cpp:646-650 (-banscore), src/logging.cpp:75-78 at PIN.
pub(super) const CONF: &str =
    "listen=1\nbind=127.0.0.1:{P2P_PORT}\ndebug=net\ndebug=netmsg\ndebug=txnval\n";

pub(super) fn p2p_port(n: &Node) -> Result<u16> {
    n.conf
        .lines()
        .find_map(|l| l.strip_prefix("port="))
        .ok_or("P2P port")?
        .parse()
        .map_err(|e: std::num::ParseIntError| e.to_string())
}

// [SRC] getpeerinfo's fields (src/rpc/net.cpp:69-280 at PIN): the identity,
// the flags the relay machine reads and the per-command byte counters.
pub(super) fn peers(n: &mut Node) -> Result<Vec<Value>> {
    Ok(n.call("getpeerinfo", json!([]))?
        .as_array()
        .ok_or("getpeerinfo")?
        .iter()
        .map(|p| {
            json!({"id":p["id"],"addr":p["addr"],"inbound":p["inbound"],"addnode":p["addnode"],
                "whitelisted":p["whitelisted"],"relaytxes":p["relaytxes"],"banscore":p["banscore"],
                "subver":p["subver"],"bytessent_per_msg":p["bytessent_per_msg"],
                "bytesrecv_per_msg":p["bytesrecv_per_msg"]})
        })
        .collect())
}

// The modelled node's entry: the bitcoin-sv user agent, never the test peer's.
fn node_entry(list: &[Value]) -> Option<Value> {
    list.iter()
        .find(|p| text(&p["subver"]).is_ok_and(|s| s.contains("Bitcoin SV")))
        .cloned()
}

pub(super) fn counters(n: &mut Node) -> Result<Value> {
    let list = peers(n)?;
    Ok(node_entry(&list).map_or(
        Value::Null,
        |p| json!({"sent":p["bytessent_per_msg"],"recv":p["bytesrecv_per_msg"]}),
    ))
}

pub(super) fn pool(n: &mut Node) -> Result<Vec<String>> {
    super::peer::settled(n)?;
    let mut v: Vec<String> = n
        .call("getrawmempool", json!([]))?
        .as_array()
        .ok_or("getrawmempool")?
        .iter()
        .filter_map(|x| x.as_str().map(str::to_owned))
        .collect();
    v.sort();
    Ok(v)
}

pub(super) fn wait_pool(n: &mut Node, ids: &[String], secs: u64) -> Result<bool> {
    let start = Instant::now();
    while start.elapsed() < Duration::from_secs(secs) {
        let p = pool(n)?;
        if ids.iter().all(|i| p.contains(i)) {
            return Ok(true);
        }
        thread::sleep(Duration::from_millis(200));
    }
    Ok(false)
}

// The test peer's receive log since an index, read from its receipt file
// (written and flushed per event by harness/peer/peer.py), so a peer the node
// has disconnected is still read.
pub(super) fn received(n: &Node, name: &str, since: usize) -> Result<Vec<Value>> {
    let raw = fs::read_to_string(n.dir.join(format!("{name}.jsonl"))).map_err(|e| e.to_string())?;
    let mut out = vec![];
    for line in raw.lines() {
        let e: Value = serde_json::from_str(line).map_err(|e| e.to_string())?;
        if e["index"].as_u64().unwrap_or(0) as usize >= since && e["direction"] == "receive" {
            out.push(
                json!({"index":e["index"],"command":e["command"],"frame":e["hex"],
                "inventory":e["inventory"],"code":e["code"],"reason":e["reason"],"hash":e["hash"]}),
            );
        }
    }
    Ok(out)
}

fn label_hash(label: &str) -> String {
    hex::encode(bsv_rs::primitives::hash::sha256(label.as_bytes()))
}

// [SRC] CheckRegularTransaction refuses a repeated input with DoS 100,
// "bad-txns-inputs-duplicate", REJECT_INVALID (src/validation.cpp:594-639, the
// refusal at :632-634, at PIN, through src/validation.cpp:2030-2095). The
// inputs need no signature: the structural check runs before any script.
fn duplicate_inputs(parent: &RawTx) -> RawTx {
    let input = RawInput {
        txid: parent.txid_internal(),
        vout: 0,
        script: vec![0x51],
        sequence: u32::MAX,
    };
    RawTx {
        version: 1,
        inputs: vec![input.clone(), input],
        outputs: vec![RawOutput {
            satoshis: 1000,
            script: script(),
        }],
        lock_time: 0,
    }
}

// [SRC] a header over its command's cap: the regtest magic
// (src/chainparams.cpp:1504-1507), `ping`, a payload length of 2 MiB + 1
// (src/protocol.h:33; src/protocol.cpp:88-93), a zero checksum. The reader
// throws BanPeer at the complete header (src/net/net_message.cpp:22-26), the
// association bans the address (src/net/association.cpp:396-401) at PIN.
fn oversized_header() -> Vec<u8> {
    let mut h = vec![0xda, 0xb5, 0xbf, 0xfa];
    let mut cmd = b"ping".to_vec();
    cmd.resize(12, 0);
    h.extend(cmd);
    h.extend((2 * 1024 * 1024 + 1u32).to_le_bytes());
    h.extend([0, 0, 0, 0]);
    h
}

fn raw_send(port: u16, bytes: &[u8]) -> Result<Value> {
    let mut s = TcpStream::connect(("127.0.0.1", port)).map_err(|e| e.to_string())?;
    s.set_read_timeout(Some(Duration::from_secs(10)))
        .map_err(|e| e.to_string())?;
    s.write_all(bytes).map_err(|e| e.to_string())?;
    let mut back = vec![];
    let ending = match s.read_to_end(&mut back) {
        Ok(_) => "closed by the node".to_owned(),
        Err(e) => format!("read: {e}"),
    };
    Ok(json!({"sent":hex::encode(bytes),"received_bytes":back.len(),"ending":ending}))
}

pub(super) fn console_since(n: &Node, from: usize, needles: &[&str]) -> Result<Vec<String>> {
    let raw = fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
    Ok(raw
        .lines()
        .skip(from)
        .filter(|l| needles.iter().any(|k| l.contains(k)))
        .map(|l| l.chars().take(300).collect())
        .collect())
}

pub(super) fn console_len(n: &Node) -> Result<usize> {
    Ok(fs::read_to_string(n.dir.join("console.log"))
        .map_err(|e| e.to_string())?
        .lines()
        .count())
}

fn banned(n: &mut Node) -> Result<Value> {
    n.call("listbanned", json!([]))
}

// [X] 2026-10-15 (lane fix-s7-78): what ran. The node of record both
// instances started on (docs/PROVENANCE.md 1a `reference.binary`): its path,
// sha256 and banner; the test peer and the pinned `mininode.py` it imports
// (harness/peer/peer.py checks that file against PIN before it opens a socket).
pub(super) fn identity() -> Result<(Value, Value)> {
    let home = PathBuf::from(std::env::var("HOME").map_err(|e| e.to_string())?);
    let shown = |p: &Path| {
        p.strip_prefix(&home).map_or_else(
            |_| p.display().to_string(),
            |r| format!("~/{}", r.display()),
        )
    };
    let digest = |p: &Path| -> Result<String> {
        Ok(hex::encode(bsv_rs::primitives::hash::sha256(
            &fs::read(p).map_err(|e| format!("{}: {e}", p.display()))?,
        )))
    };
    let bin = Build::Record.path()?;
    let banner = Build::Record
        .version_at(&bin)?
        .ok_or("node of record absent")?;
    // the pinned framework: the reference clone's (`$BSV_SPEC_REFERENCE_CLONE`, #177) unless named
    let framework = std::env::var("BSV_PEER_FRAMEWORK").map_or_else(
        |_| host::need(host::REFERENCE_CLONE).join("test/functional"),
        PathBuf::from,
    );
    let mininode = framework.join("test_framework/mininode.py");
    let peer = PathBuf::from("harness/peer/peer.py");
    Ok((
        json!({"path":shown(&bin),"sha256":digest(&bin)?,"banner":banner,
            "source":"docs/PROVENANCE.md 1a reference.binary"}),
        json!({"path":peer.display().to_string(),"sha256":digest(&peer)?,
            "mininode":{"path":shown(&mininode),"sha256":digest(&mininode)?,"pin":PIN}}),
    ))
}

// [X] 2026-10-15 (lane fix-s7-78): an instance's ports, read from the
// bitcoin.conf it started on.
pub(super) fn ports(n: &Node) -> Result<Value> {
    let read = |key: &str| -> Result<u16> {
        n.conf
            .lines()
            .find_map(|l| l.strip_prefix(key))
            .ok_or(format!("{key} in bitcoin.conf"))?
            .parse()
            .map_err(|e: std::num::ParseIntError| e.to_string())
    };
    Ok(json!({"rpc":read("rpcport=")?,"p2p":read("port=")?}))
}

const LOG_KEYS: [&str; 4] = [
    "Misbehaving",
    "not banning local peer",
    "banning peer",
    "BAN THRESHOLD",
];

pub(super) fn run(root: &Path) -> Result<Value> {
    let (binary, test_peer) = identity()?;
    let mut a = start_retry_build(root, "relay-a", 1_000_001, CONF, Build::Record)?;
    let (f, t, funding) = seed(&mut a)?;
    let mut b = start_retry_build(root, "relay-b", 1_000_001, CONF, Build::Record)?;
    // The IBD probe is its own peer, closed before B dials A: the node starts
    // its header sync with one peer at a time (nSyncStarted,
    // src/net/net_processing.cpp:5252-5262) and the probe never answers
    // headers; closing it returns the slot (:233-238).
    let mut p0 = Peer::start_named(&mut b, "probe")?;
    let names = |m: &mut BTreeMap<String, Value>, k: &str, tx: &RawTx| {
        m.insert(
            k.into(),
            json!({"txid":id(tx),"bytes":tx.encode().len(),"hex":hex::encode(tx.encode())}),
        );
    };
    let mut txs = BTreeMap::new();
    let p = spend(&t, 98000, 1);
    let c = spend(&p, 97000, 1);
    let k = spend(&f, 98500, 1);
    let d = duplicate_inputs(&t);
    for (name, tx) in [
        ("F", &f),
        ("T", &t),
        ("P", &p),
        ("C", &c),
        ("K", &k),
        ("D", &d),
    ] {
        names(&mut txs, name, tx);
    }
    let x = label_hash("bsv-script-lean/s7-78/ibd-probe-x");
    let y = label_hash("bsv-script-lean/s7-78/ibd-probe-y");
    let mut steps = vec![];

    // s1: B in its initial block download (tip: genesis) asks for nothing.
    let tip_b = b.call("getbestblockhash", json!([]))?;
    let cur = p0.next as usize;
    p0.inv_hash(&x)?;
    let none = p0.expect("none", &x, cur as u64, 3.0)?;
    let b_peers = peers(&mut b)?;
    p0.close()?;
    steps.push(json!({"id":"s1-ibd-gate","b_tip":tip_b,"b_height":b.call("getblockcount",json!([]))?,
        "probe_expect_none":none["matched"],"probe_received":received(&b, "probe", cur)?,"b_peers":b_peers}));

    // s2: B dials A once and catches up; its clock is A's.
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
    let mut pb = Peer::start(&mut b)?;
    steps.push(
        json!({"id":"s2-connect-sync","a_tip":target,"b_height":b.call("getblockcount",json!([]))?,
        "funding_block":funding,"a_peers":peers(&mut a)?,"b_peers":peers(&mut b)?}),
    );

    // s3: out of the initial download, an announced transaction is requested.
    let cur = pb.next as usize;
    pb.inv_hash(&y)?;
    let got = pb.expect("getdata", &y, cur as u64, 10.0)?;
    steps.push(json!({"id":"s3-ibd-lifted","pb_expect_getdata":got["matched"],"pb_received":received(&b, "peer", cur)?}));

    // s4: T accepted by A's RPC is announced to PA and B; B fetches it and
    // announces it to PB, never back to A.
    let mut pa = Peer::start(&mut a)?;
    thread::sleep(Duration::from_millis(500));
    let (ca, cb) = (counters(&mut a)?, counters(&mut b)?);
    let (pa0, pb0) = (pa.next as usize, pb.next as usize);
    let sent = a.receipt("sendrawtransaction", json!([hex::encode(t.encode())]))?;
    let pa_inv = pa.expect("inv", &id(&t), pa0 as u64, 15.0)?;
    let pb_inv = pb.expect("inv", &id(&t), pb0 as u64, 15.0)?;
    let b_has = wait_pool(&mut b, &[id(&t)], 15)?;
    thread::sleep(Duration::from_secs(2));
    steps.push(json!({"id":"s4-relay","rpc":sent,"pa_expect_inv":pa_inv["matched"],"pb_expect_inv":pb_inv["matched"],
        "b_pool_has_t":b_has,"counters_before":{"a":ca,"b":cb},"counters_after":{"a":counters(&mut a)?,"b":counters(&mut b)?},
        "pa_received":received(&a, "peer", pa0)?,"pb_received":received(&b, "peer", pb0)?,"pool":{"a":pool(&mut a)?,"b":pool(&mut b)?}}));

    // s5: PB sends the child C before its parent P: B keeps C as an orphan and
    // asks PB for P; P arrives, C is retried; both reach A through B.
    let (ca, cb) = (counters(&mut a)?, counters(&mut b)?);
    let (pa0, pb0) = (pa.next as usize, pb.next as usize);
    pb.tx(&c)?;
    let asked = pb.expect("getdata", &id(&p), pb0 as u64, 10.0)?;
    pb.tx(&p)?;
    let a_has = wait_pool(&mut a, &[id(&p), id(&c)], 20)?;
    thread::sleep(Duration::from_secs(2));
    steps.push(json!({"id":"s5-orphan-fetch","pb_expect_getdata_parent":asked["matched"],"a_pool_has_p_c":a_has,
        "counters_before":{"a":ca,"b":cb},"counters_after":{"a":counters(&mut a)?,"b":counters(&mut b)?},
        "pa_received":received(&a, "peer", pa0)?,"pb_received":received(&b, "peer", pb0)?,"pool":{"a":pool(&mut a)?,"b":pool(&mut b)?}}));

    // s6: K double-spends T's input: refused with an internal code (0x102),
    // which never reaches the wire, and no score.
    let pb0 = pb.next as usize;
    let lb = console_len(&b)?;
    pb.tx(&k)?;
    let quiet = pb.expect("none", &id(&k), pb0 as u64, 3.0)?;
    steps.push(json!({"id":"s6-internal-code-silent","pb_expect_none":quiet["matched"],"pb_received":received(&b, "peer", pb0)?,
        "b_console":console_since(&b, lb, &LOG_KEYS)?,"b_pb_banscore":peers(&mut b)?.iter().find(|q| !text(&q["subver"]).is_ok_and(|s| s.contains("Bitcoin SV"))).map(|q| q["banscore"].clone())}));

    // s7: D repeats an input: reject 0x10 to PB and a score of 100 against it,
    // the threshold: PB is local, so it is disconnected and never banned.
    let pb0 = pb.next as usize;
    let lb = console_len(&b)?;
    let sent_d = pb
        .tx(&d)
        .map_or_else(|e| json!({"peer_step_error":e}), |_| json!({"ok":true}));
    thread::sleep(Duration::from_secs(3));
    let b_after = peers(&mut b)?;
    steps.push(json!({"id":"s7-reject-score","send":sent_d,"pb_received":received(&b, "peer", pb0)?,
        "b_console":console_since(&b, lb, &LOG_KEYS)?,"b_peers":b_after,"b_banned":banned(&mut b)?}));
    drop(pb);

    // s8: a header over its cap at A from a fresh loopback socket: the address
    // is banned with no increment, and every loopback peer of A is dropped.
    let la = console_len(&a)?;
    let before = peers(&mut a)?;
    let raw = raw_send(a_port, &oversized_header())?;
    thread::sleep(Duration::from_secs(2));
    steps.push(json!({"id":"s8-direct-ban","raw":raw,"a_peers_before":before,"a_peers_after":peers(&mut a)?,
        "a_banned":banned(&mut a)?,"a_console":console_since(&a, la, &LOG_KEYS)?,"b_peers":peers(&mut b)?}));
    drop(pa);

    // Every frame the test peers received, the codec corpus of the run.
    let mut frames = vec![];
    for (n, name, source) in [
        (&b, "probe", "B>probe"),
        (&b, "peer", "B>PB"),
        (&a, "peer", "A>PA"),
    ] {
        for e in received(n, name, 0)? {
            frames.push(json!({"source":source,"command":e["command"],"hex":e["frame"]}));
        }
    }
    let ports = json!({"a":ports(&a)?,"b":ports(&b)?});
    a.stop()?;
    b.stop()?;
    let rpc = json!({"a":a.calls,"b":b.calls});
    Ok(
        json!({"scenario":SCENARIO,"source_pin":PIN,"binary":binary,"test_peer":test_peer,"ports":ports,
        "names":{"transactions":txs,"x":x,"y":y},
        "instances":{"a":instance_pointer(&a.dir),"b":instance_pointer(&b.dir)},"steps":steps,"frames":frames,"rpc":rpc}),
    )
}

// The record's projection without RPC bodies; the full receipt stays in the run.
pub(super) fn main(record: &str, run_id: Option<String>) -> Result<()> {
    let start = Instant::now();
    let out = record_run(record, "-s7-78-p2p-machine-s1.md", "relay-78", run_id, run)?;
    println!(
        "relay node: observed [X] ({} steps; wall [M] {:.3}s); judged by chaincheck --p2p",
        out["steps"].as_array().map_or(0, Vec::len),
        start.elapsed().as_secs_f64()
    );
    Ok(())
}

// [D] 2026-10-15 (#79, lane s7-79): the run's receipt written in full under
// the scenario root and, without its RPC bodies, beside the record; shared by
// #78's relay run and #79's compact-block run.
pub(super) fn record_run(
    record: &str,
    suffix: &str,
    prefix: &str,
    run_id: Option<String>,
    run: fn(&Path) -> Result<Value>,
) -> Result<Value> {
    let stem = record
        .strip_prefix("docs/records/")
        .and_then(|r| r.strip_suffix(suffix));
    if !stem.is_some_and(|s| !s.is_empty() && s.bytes().all(|c| c.is_ascii_digit() || c == b'-')) {
        return Err(format!("record must be docs/records/<stamp>{suffix}"));
    }
    let run_id = run_id.unwrap_or_else(|| format!("{prefix}-{}", stem.unwrap_or("run")));
    if !run_id
        .bytes()
        .all(|c| c.is_ascii_alphanumeric() || c == b'-')
    {
        return Err("unsafe run id".into());
    }
    let home = PathBuf::from(std::env::var("HOME").map_err(|e| e.to_string())?);
    let root = home.join("bsv/targets/spec-oracle-scenarios").join(&run_id);
    fs::create_dir_all(&root).map_err(|e| e.to_string())?;
    let head = Command::new("git")
        .args(["rev-parse", "HEAD"])
        .output()
        .map_err(|e| e.to_string())?;
    let started = Command::new("date")
        .args(["-u", "+%Y-%m-%dT%H:%M:%SZ"])
        .output()
        .map_err(|e| e.to_string())?;
    let start = Instant::now();
    let mut out = run(&root)?;
    out["record"] = json!(record);
    out["run_id"] = json!(run_id);
    out["base_commit"] = json!(String::from_utf8_lossy(&head.stdout).trim());
    out["started_utc"] = json!(String::from_utf8_lossy(&started.stdout).trim());
    out["wall_seconds"] = json!({"label":"[M]","value":start.elapsed().as_secs_f64()});
    let full = root.join("receipt.json");
    write_json(&full, &out)?;
    let bytes = fs::read(&full).map_err(|e| e.to_string())?;
    out["full_receipt"] = json!({"label":"[M]","path":instance_pointer(&full),"bytes":bytes.len(),
        "sha256":hex::encode(bsv_rs::primitives::hash::sha256(&bytes))});
    out.as_object_mut().ok_or("receipt")?.remove("rpc");
    write_json(&PathBuf::from(record.replace(".md", ".json")), &out)?;
    Ok(out)
}
