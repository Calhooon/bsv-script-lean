//! #80 (S7, lane s7-80): double-spend notifications on two fresh regtest
//! instances, one link between them (B dials A), the reference's loopback test
//! peer on each (PA on A, PB on B) and a local HTTP receiver in this runner on
//! the lanes' band. The scenario (corpus/scenarios/2026-10-15-double-spend-notify.md)
//! drives three callback attempts at A (a proof delivered, an endpoint that
//! answers without the protocol's header and is blacklisted, a later attempt the
//! blacklist stops) and one `dsdetected` message from PB relayed by B to A and
//! by A to PA, posted to both nodes' webhooks, then the same message again. The
//! receipt is observations only; the judging is the Lean's (`chaincheck --dsnt`,
//! lean/Test/DsntCheck.lean) over lean/BsvChain/Wire/DoubleSpend.lean. A
//! notification is never a verdict. Sources: bitcoin-sv 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
use super::core::*;
use super::peer::Peer;
use super::relay::{
    console_len, console_since, counters, identity, p2p_port, pool, ports, received, wait_pool,
};
use std::io::{Read, Write};
use std::net::TcpStream;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

const SCENARIO: &str = "corpus/scenarios/2026-10-15-double-spend-notify.md";

// [D] 2026-10-15: #78's link settings, the handler at the standard level (1:
// standard inputs only, src/init.cpp:1577-1581), the endpoint port the
// receiver holds (`-dsendpointport`, src/init.cpp:1597-1600,2978-2981; the port
// is not in the callback message, src/rpc/client_config.cpp:95-96), each node's
// own webhook path, and the double-spend and HTTP log categories
// (src/logging.cpp:54,79) at PIN.
fn conf(port: u16, tag: &str) -> String {
    format!(
        "{}debug=doublespend\ndebug=http\ndsnotifylevel=1\ndsendpointport={port}\ndsdetectedwebhookurl=http://127.0.0.1:{port}/dsdetected/{tag}\n",
        super::relay::CONF
    )
}

// [D] 2026-10-15: what the receiver answers a query for a transaction id.
#[derive(Clone, Copy)]
enum Answer {
    // 200 with `x-bsv-dsnt: 1`: the endpoint wants the proof
    Want,
    // 200 without the header: the handler blacklists the endpoint
    // (src/double_spend/dsattempt_handler.cpp:482-489 at PIN)
    NoHeader,
}

// The local HTTP receiver: one listener on the lanes' band, every request
// recorded with its arrival time (the system clock the blacklist reads,
// src/double_spend/time_limited_blacklist.h:20-23 at PIN) and its answer.
struct Receiver {
    port: u16,
    stop: Arc<AtomicBool>,
    log: Arc<Mutex<Vec<Value>>>,
    answers: Arc<Mutex<BTreeMap<String, Answer>>>,
    worker: Option<thread::JoinHandle<()>>,
}

fn epoch() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

impl Receiver {
    fn start() -> Result<Self> {
        let (port, listener) = (18571..=18590)
            .find_map(|p| TcpListener::bind(("127.0.0.1", p)).ok().map(|l| (p, l)))
            .ok_or("no free receiver port in 18571..18590")?;
        listener.set_nonblocking(true).map_err(|e| e.to_string())?;
        let stop = Arc::new(AtomicBool::new(false));
        let log = Arc::new(Mutex::new(vec![]));
        let answers = Arc::new(Mutex::new(BTreeMap::new()));
        let (s, l, a) = (stop.clone(), log.clone(), answers.clone());
        let worker = thread::spawn(move || {
            while !s.load(Ordering::Relaxed) {
                match listener.accept() {
                    Ok((stream, _)) => {
                        let entry = serve(stream, &a);
                        if let Ok(mut g) = l.lock() {
                            g.push(entry);
                        }
                    }
                    Err(_) => thread::sleep(Duration::from_millis(20)),
                }
            }
        });
        Ok(Self {
            port,
            stop,
            log,
            answers,
            worker: Some(worker),
        })
    }
    fn answer(&self, txid: &str, a: Answer) -> Result<()> {
        self.answers
            .lock()
            .map_err(|e| e.to_string())?
            .insert(txid.to_owned(), a);
        Ok(())
    }
    fn len(&self) -> Result<usize> {
        Ok(self.log.lock().map_err(|e| e.to_string())?.len())
    }
    fn since(&self, from: usize) -> Result<Vec<Value>> {
        Ok(self
            .log
            .lock()
            .map_err(|e| e.to_string())?
            .iter()
            .skip(from)
            .cloned()
            .collect())
    }
    // Poll until `pred` holds over the entries since `from`, or the deadline.
    fn wait(&self, from: usize, secs: u64, pred: impl Fn(&[Value]) -> bool) -> Result<bool> {
        let start = Instant::now();
        while start.elapsed() < Duration::from_secs(secs) {
            if pred(&self.since(from)?) {
                return Ok(true);
            }
            thread::sleep(Duration::from_millis(100));
        }
        Ok(false)
    }
}

impl Drop for Receiver {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(w) = self.worker.take() {
            let _ = w.join();
        }
    }
}

// One request read whole (headers, then the body by Content-Length), answered
// and closed. The answer: a query by the transaction's rule (Want by default),
// a proof with `x-bsv-dsnt: 1`, a webhook post with 200 and no header.
fn serve(mut s: TcpStream, answers: &Mutex<BTreeMap<String, Answer>>) -> Value {
    let arrived = epoch();
    let _ = s.set_nonblocking(false);
    let _ = s.set_read_timeout(Some(Duration::from_secs(5)));
    let mut buf = vec![];
    let mut chunk = [0u8; 4096];
    let head_end = loop {
        if let Some(i) = buf.windows(4).position(|w| w == b"\r\n\r\n") {
            break Some(i + 4);
        }
        match s.read(&mut chunk) {
            Ok(0) | Err(_) => break None,
            Ok(n) => buf.extend_from_slice(&chunk[..n]),
        }
    };
    let Some(head_end) = head_end else {
        return json!({"epoch":arrived,"error":"no complete request head","bytes":hex::encode(&buf)});
    };
    let head = String::from_utf8_lossy(&buf[..head_end]).to_string();
    let mut lines = head.split("\r\n");
    let request_line = lines.next().unwrap_or("").to_owned();
    let mut parts = request_line.split(' ');
    let method = parts.next().unwrap_or("").to_owned();
    let path = parts.next().unwrap_or("").to_owned();
    let headers: Vec<(String, String)> = lines
        .filter_map(|l| {
            l.split_once(':')
                .map(|(k, v)| (k.trim().to_ascii_lowercase(), v.trim().to_owned()))
        })
        .collect();
    let length = headers
        .iter()
        .find(|(k, _)| k == "content-length")
        .and_then(|(_, v)| v.parse::<usize>().ok())
        .unwrap_or(0);
    let mut body = buf[head_end..].to_vec();
    while body.len() < length {
        match s.read(&mut chunk) {
            Ok(0) | Err(_) => break,
            Ok(n) => body.extend_from_slice(&chunk[..n]),
        }
    }
    let (status, dsnt) = if path.starts_with("/dsnt/") && path.contains("/query/") {
        let txid = path.rsplit('/').next().unwrap_or("").to_owned();
        match answers.lock().ok().and_then(|g| g.get(&txid).copied()) {
            Some(Answer::NoHeader) => (200, None),
            _ => (200, Some("1")),
        }
    } else if path.starts_with("/dsnt/") && path.contains("/submit") {
        (200, Some("1"))
    } else if path.starts_with("/dsdetected/") {
        (200, None)
    } else {
        (404, None)
    };
    let reason = if status == 200 { "OK" } else { "Not Found" };
    let mut reply = format!("HTTP/1.1 {status} {reason}\r\n");
    if let Some(v) = dsnt {
        reply.push_str(&format!("x-bsv-dsnt: {v}\r\n"));
    }
    reply.push_str("Content-Length: 0\r\nConnection: close\r\n\r\n");
    let _ = s.write_all(reply.as_bytes());
    let _ = s.flush();
    json!({"epoch":arrived,"label":"[X]","method":method,"path":path,"request_line":request_line,
        "headers":headers.iter().map(|(k, v)| json!([k, v])).collect::<Vec<_>>(),
        "body_hex":hex::encode(&body),"body_bytes":body.len(),
        "answer":{"status":status,"dsnt":dsnt}})
}

// [SRC] the notification output (src/script/script.cpp:174-179) with the
// callback message (src/double_spend/dscallback_msg.h:52-127) as one push
// (src/script/script.h:104-133): version byte 0x01 (IPv4, protocol 1), one
// address 127.0.0.1, no inputs listed (every input watched) at PIN.
fn dsnt_script() -> Vec<u8> {
    let msg = [0x01u8, 0x01, 127, 0, 0, 1, 0x00];
    let mut s = vec![0x00, 0x6a, 0x04, b'd', b's', b'n', b't', msg.len() as u8];
    s.extend_from_slice(&msg);
    s
}

fn spend(inputs: &[([u8; 32], u32, u64)], outputs: Vec<RawOutput>) -> Result<RawTx> {
    block_codec::try_p2pkh_spend(inputs, outputs, &key(), &script())
}

fn out(satoshis: u64, script: Vec<u8>) -> RawOutput {
    RawOutput { satoshis, script }
}

// [SRC] a `dsdetected` payload (src/double_spend/dsdetected_message.h:29-98,
// src/merkleproof.h:100-137 at PIN): version 1; per fork one header on the tip
// (its time above the tip's, regtest bits, the nonce ground), a proof of the
// fork's transaction at index 1 beside its coinbase: flags 5 (a transaction, a
// merkle-root target), the length field, the transaction, the root, one node of
// type 0 (the coinbase's id).
fn ds_payload(
    tip: [u8; 32],
    time: u32,
    bits: u32,
    forks: &[(RawTx, RawTx)],
) -> (Vec<u8>, Vec<String>) {
    let mut p = 1u16.to_le_bytes().to_vec();
    p.extend(block_codec::varint(forks.len() as u64));
    let mut headers = vec![];
    for (k, (cb, x)) in forks.iter().enumerate() {
        let ids = [cb.txid_internal(), x.txid_internal()];
        let root = block_codec::merkle_root(&ids);
        let mut h = block_codec::Header {
            version: 0x2000_0000,
            prev: tip,
            merkle: root,
            time: time + 1 + k as u32,
            bits,
            nonce: 0,
        };
        block_codec::grind(&mut h);
        headers.push(hex::encode(h.encode()));
        p.extend(block_codec::varint(1));
        p.extend(h.encode());
        p.push(5);
        p.extend(block_codec::varint(1));
        let raw = x.encode();
        p.extend(block_codec::varint(raw.len() as u64));
        p.extend(&raw);
        p.extend(root);
        p.extend(block_codec::varint(1));
        p.push(0);
        p.extend(ids[0]);
    }
    (p, headers)
}

const LOG_KEYS: [&str; 9] = [
    "double-spend",
    "Double-spend",
    "DS notification",
    "endpoint",
    "blacklist",
    "dsdetected",
    "webhook",
    "txn-mempool-conflict",
    "Misbehaving",
];

fn wait_for<F: FnMut() -> Result<bool>>(secs: u64, mut f: F) -> Result<bool> {
    let start = Instant::now();
    while start.elapsed() < Duration::from_secs(secs) {
        if f()? {
            return Ok(true);
        }
        thread::sleep(Duration::from_millis(200));
    }
    Ok(false)
}

fn has(entries: &[Value], method: &str, needle: &str) -> bool {
    entries
        .iter()
        .any(|e| e["method"] == method && text(&e["path"]).is_ok_and(|p| p.contains(needle)))
}

pub(super) fn run(root: &Path) -> Result<Value> {
    let (binary, test_peer) = identity()?;
    let rx = Receiver::start()?;
    let mut a = start_retry_build(
        root,
        "dsnt-a",
        1_000_001,
        &conf(rx.port, "a"),
        Build::Record,
    )?;
    let (f, _t, funding) = seed(&mut a)?;
    // The fan-out G: F's output into four of 24000 (fee 4000), mined in block 102.
    let g = spend(
        &[(f.txid_internal(), 0, 100_000)],
        (0..4).map(|_| out(24_000, script())).collect(),
    )?;
    let (g_block, g_receipt) = a.submit(&[cb(102, "dsnt-g"), g.clone()], 1_700_000_100)?;
    if block_judgment(&g_receipt) != json!({"status":"ok"}) {
        return Err(format!("fan-out block: {g_receipt}"));
    }
    let gid = g.txid_internal();
    // E1..E3 carry the notification output; C1..C3 spend the same outputs of G
    // without one; X1 and X2 spend G's fourth output, for the dsdetected forks only.
    let mut e = vec![];
    let mut c = vec![];
    for i in 0..3u32 {
        e.push(spend(
            &[(gid, i, 24_000)],
            vec![out(23_000, script()), out(0, dsnt_script())],
        )?);
        c.push(spend(&[(gid, i, 24_000)], vec![out(22_000, script())])?);
    }
    let x1 = spend(&[(gid, 3, 24_000)], vec![out(22_500, script())])?;
    let x2 = spend(&[(gid, 3, 24_000)], vec![out(22_000, script())])?;
    let cb1 = block_codec::coinbase_tx(103, 0, script(), b"dsd-fork-1");
    let cb2 = block_codec::coinbase_tx(103, 0, script(), b"dsd-fork-2");
    let mut names = BTreeMap::new();
    for (k, tx) in [
        ("F", &f),
        ("G", &g),
        ("E1", &e[0]),
        ("E2", &e[1]),
        ("E3", &e[2]),
        ("C1", &c[0]),
        ("C2", &c[1]),
        ("C3", &c[2]),
        ("X1", &x1),
        ("X2", &x2),
        ("CB1", &cb1),
        ("CB2", &cb2),
    ] {
        names.insert(
            k.to_owned(),
            json!({"txid":id(tx),"hex":hex::encode(tx.encode())}),
        );
    }
    // A holds E1..E3 before B is linked, so B never hears of them.
    let mut accepted = vec![];
    for tx in &e {
        accepted.push(a.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?);
    }
    let mut b = start_retry_build(
        root,
        "dsnt-b",
        1_000_001,
        &conf(rx.port, "b"),
        Build::Record,
    )?;
    b.clock_receipt(a.clock)?;
    let a_port = p2p_port(&a)?;
    b.call("addnode", json!([format!("127.0.0.1:{a_port}"), "onetry"]))?;
    let target = a.call("getbestblockhash", json!([]))?;
    if !wait_for(90, || Ok(b.call("getbestblockhash", json!([]))? == target))? {
        return Err("B did not reach A's tip".into());
    }
    let mut pa = Peer::start(&mut a)?;
    let mut pb = Peer::start(&mut b)?;
    thread::sleep(Duration::from_millis(500));
    let mut steps = vec![
        json!({"id":"s0-setup","funding_block":funding,"g_block":g_block,
        "a_accepts":accepted,"a_pool":pool(&mut a)?,"b_pool":pool(&mut b)?,
        "a_tip":a.tip()?,"b_tip":b.tip()?}),
    ];

    // s1..s3: C_i at B, relayed to A, refused there against E_i.
    for (i, (answer, label)) in [
        (Answer::Want, "s1-proof-delivered"),
        (Answer::NoHeader, "s2-no-header-blacklisted"),
        (Answer::Want, "s3-blacklisted-skip"),
    ]
    .into_iter()
    .enumerate()
    {
        let eid = id(&e[i]);
        rx.answer(&eid, answer)?;
        let (r0, la, lb) = (rx.len()?, console_len(&a)?, console_len(&b)?);
        let (pa0, pb0) = (pa.next as usize, pb.next as usize);
        let started = epoch();
        let sent = b.receipt("sendrawtransaction", json!([hex::encode(c[i].encode())]))?;
        let b_has = wait_pool(&mut b, &[id(&c[i])], 15)?;
        let settled = match i {
            0 => rx.wait(r0, 30, |es| has(es, "POST", &format!("txid={eid}")))?,
            1 => rx.wait(r0, 30, |es| has(es, "GET", &eid))?,
            _ => {
                thread::sleep(Duration::from_secs(8));
                true
            }
        };
        thread::sleep(Duration::from_secs(2));
        steps.push(json!({"id":label,"epoch_sent":started,"b_rpc":sent,"b_pool_has_c":b_has,"settled":settled,
            "receiver":rx.since(r0)?,"a_pool":pool(&mut a)?,"b_pool":pool(&mut b)?,
            "a_console":console_since(&a, la, &LOG_KEYS)?,"b_console":console_since(&b, lb, &LOG_KEYS)?,
            "pa_received":received(&a, "peer", pa0)?,"pb_received":received(&b, "peer", pb0)?,
            "counters":{"a":counters(&mut a)?,"b":counters(&mut b)?}}));
    }

    // s4: PB sends a dsdetected message about two forks on A's tip, each with a
    // transaction spending G's fourth output; B relays it to A, A to PA; both post.
    let tip = a.tip()?;
    let tip_hash = txid_from_display_hex(text(&tip["hash"])?)?;
    let tip_time = tip["time"].as_u64().ok_or("tip time")? as u32;
    let bits = u32::from_str_radix(text(&tip["bits"])?, 16).map_err(|e| e.to_string())?;
    let (payload, headers) = ds_payload(
        tip_hash,
        tip_time,
        bits,
        &[(cb1.clone(), x1.clone()), (cb2.clone(), x2.clone())],
    );
    let (r0, la, lb) = (rx.len()?, console_len(&a)?, console_len(&b)?);
    let (pa0, pb0) = (pa.next as usize, pb.next as usize);
    let (ca, cbn) = (counters(&mut a)?, counters(&mut b)?);
    let sent = pb.dsdetected(&payload)?;
    let posted = rx.wait(r0, 20, |es| {
        has(es, "POST", "/dsdetected/a") && has(es, "POST", "/dsdetected/b")
    })?;
    let pa_got = pa.expect("dsdetected", "", pa0 as u64, 10.0)?;
    thread::sleep(Duration::from_secs(1));
    let safe_a = a
        .call("getsafemodeinfo", json!([]))
        .unwrap_or_else(|e| json!({"error":e}));
    steps.push(json!({"id":"s4-dsdetected-relayed","payload_hex":hex::encode(&payload),"headers":headers,
        "tip":{"hash":tip["hash"],"height":tip["height"],"time":tip["time"],"bits":tip["bits"]},
        "pb_sent":sent,"posted":posted,"pa_expect_dsdetected":pa_got["matched"],"receiver":rx.since(r0)?,
        "pa_received":received(&a, "peer", pa0)?,"pb_received":received(&b, "peer", pb0)?,
        "counters_before":{"a":ca,"b":cbn},"counters_after":{"a":counters(&mut a)?,"b":counters(&mut b)?},
        "a_console":console_since(&a, la, &LOG_KEYS)?,"b_console":console_since(&b, lb, &LOG_KEYS)?,
        "chaintips":{"a":a.call("getchaintips", json!([]))?,"b":b.call("getchaintips", json!([]))?},
        "a_safemode":safe_a}));

    // s5: the same message again from PB: the duplicate cache answers nothing.
    let (r0, la, lb) = (rx.len()?, console_len(&a)?, console_len(&b)?);
    let (pa0, pb0) = (pa.next as usize, pb.next as usize);
    let sent = pb.dsdetected(&payload)?;
    thread::sleep(Duration::from_secs(4));
    steps.push(json!({"id":"s5-dsdetected-duplicate","pb_sent":sent,"receiver":rx.since(r0)?,
        "pa_received":received(&a, "peer", pa0)?,"pb_received":received(&b, "peer", pb0)?,
        "a_console":console_since(&a, la, &LOG_KEYS)?,"b_console":console_since(&b, lb, &LOG_KEYS)?}));

    let mut frames = vec![];
    for (n, source) in [(&a, "A>PA"), (&b, "B>PB")] {
        for ev in received(n, "peer", 0)? {
            frames.push(json!({"source":source,"command":ev["command"],"hex":ev["frame"]}));
        }
    }
    let all = rx.since(0)?;
    let ports = json!({"a":ports(&a)?,"b":ports(&b)?,"receiver":rx.port});
    drop(pa);
    drop(pb);
    a.stop()?;
    b.stop()?;
    drop(rx);
    let rpc = json!({"a":a.calls,"b":b.calls});
    Ok(
        json!({"scenario":SCENARIO,"source_pin":PIN,"binary":binary,"test_peer":test_peer,"ports":ports,
        "settings":{"dsnotifylevel":1,"dsendpointport":ports["receiver"],
            "dsdetectedwebhookurl":{"a":"/dsdetected/a","b":"/dsdetected/b"}},
        "dsnt_script":hex::encode(dsnt_script()),"names":{"transactions":names},
        "instances":{"a":instance_pointer(&a.dir),"b":instance_pointer(&b.dir)},
        "steps":steps,"receiver_log":all,"frames":frames,"rpc":rpc}),
    )
}

// The record's projection without RPC bodies; the full receipt stays in the run.
pub(super) fn main(record: &str, run_id: Option<String>) -> Result<()> {
    let stem = record
        .strip_prefix("docs/records/")
        .and_then(|r| r.strip_suffix("-s7-80-double-spend-s1.md"));
    if !stem.is_some_and(|s| !s.is_empty() && s.bytes().all(|c| c.is_ascii_digit() || c == b'-')) {
        return Err("record must be docs/records/<stamp>-s7-80-double-spend-s1.md".into());
    }
    let run_id = run_id.unwrap_or_else(|| format!("dsnt-80-{}", stem.unwrap_or("run")));
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
    println!(
        "double-spend notifications: observed [X] ({} steps, {} receiver requests; wall [M] {:.3}s); judged by chaincheck --dsnt",
        out["steps"].as_array().map_or(0, Vec::len),
        out["receiver_log"].as_array().map_or(0, Vec::len),
        start.elapsed().as_secs_f64()
    );
    Ok(())
}
