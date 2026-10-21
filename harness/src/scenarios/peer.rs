//! [D] 2026-10-13: #66 reference-framework instrument and bounded recipes.
//! [SRC] mininode.py:48,2118-2690; validation.cpp:1868-1932 at core::PIN.
use super::core::*;
use std::io::{BufRead, BufReader, Write};
use std::process::{ChildStdin, Stdio};
use std::sync::mpsc::{self, Receiver};

pub(super) struct Peer {
    child: Child,
    input: ChildStdin,
    output: Receiver<std::io::Result<String>>,
    events: Vec<Value>,
    pub(super) next: u64,
    closed: bool,
    // [X] 2026-10-13 (#72): the advertised time and both observed offsets.
    clock: Value,
}
impl Peer {
    pub(super) fn start(n: &mut Node) -> Result<Self> {
        Self::start_named(n, "peer")
    }
    // [D] 2026-10-15 (#78): a second test peer on one instance writes its own
    // receipt (`<name>.jsonl`, `<name>.err`); the instrument opens it exclusively.
    pub(super) fn start_named(n: &mut Node, name: &str) -> Result<Self> {
        let port = n
            .conf
            .lines()
            .find_map(|l| l.strip_prefix("port="))
            .ok_or("P2P port")?;
        let mut child = Command::new("python3")
            .args(["-u", "harness/peer/peer.py", "--receipt"])
            .arg(n.dir.join(format!("{name}.jsonl")))
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(fs::File::create(n.dir.join(format!("{name}.err"))).map_err(|e| e.to_string())?)
            .spawn()
            .map_err(|e| e.to_string())?;
        let input = child.stdin.take().ok_or("peer stdin")?;
        let stdout = child.stdout.take().ok_or("peer stdout")?;
        let (tx, output) = mpsc::channel();
        thread::spawn(move || {
            for line in BufReader::new(stdout).lines() {
                if tx.send(line).is_err() {
                    break;
                }
            }
        });
        let mut p = Self {
            child,
            input,
            output,
            events: vec![],
            next: 0,
            closed: false,
            clock: Value::Null,
        };
        let clock = n.clock;
        p.step(json!({"op":"connect","host":"127.0.0.1","port":port.parse::<u16>().map_err(|e|e.to_string())?,"time":clock}))?;
        p.clock = peer_clock(n, clock)?;
        Ok(p)
    }
    fn step(&mut self, request: Value) -> Result<Value> {
        writeln!(self.input, "{request}").map_err(|e| e.to_string())?;
        self.input.flush().map_err(|e| e.to_string())?;
        let raw = self
            .output
            .recv_timeout(Duration::from_secs(25))
            .map_err(|e| format!("peer response: {e}"))?
            .map_err(|e| e.to_string())?;
        let response: Value =
            serde_json::from_str(&raw).map_err(|e| format!("peer JSON {e}: {raw}"))?;
        if response["source_pin"] != PIN {
            return Err("peer pin receipt mismatch".into());
        }
        self.events
            .extend(response["events"].as_array().ok_or("peer events")?.clone());
        self.next = response["next_index"].as_u64().ok_or("peer cursor")?;
        if response["ok"] != true {
            return Err(format!("peer: {}", response["error"]));
        }
        Ok(response["result"].clone())
    }
    // [D] 2026-10-13: header recipes share this pinned process and step protocol.
    // [SRC] mininode.py:1746-1763,1616-1645 at PIN supplies headers and the fence.
    pub(super) fn header(&mut self, n: &mut Node, bytes: &[u8], hash: &str) -> Result<Value> {
        let header = bytes.get(..80).ok_or("missing header bytes")?;
        self.step(json!({"op":"send_headers","hex":[hex::encode(header)]}))?;
        let observed = n.call("getblockheader", json!([hash, true]))?;
        if observed["hash"] != hash
            || observed["status"]["data"] != false
            || observed["status"]["failed"] != false
            || observed["status"]["parent failed"] != false
        {
            return Err(format!("header-only observation differs: {observed}"));
        }
        Ok(observed)
    }
    pub(super) fn receipt(&self, n: &Node) -> Value {
        json!({"source_pin":PIN,"protocol_version":70016,"events":self.events,"clock":self.clock,
            "receipt":format!("{}/peer.jsonl",instance_pointer(&n.dir))})
    }
    pub(super) fn tx(&mut self, tx: &RawTx) -> Result<()> {
        self.step(json!({"op":"send_tx","hex":hex::encode(tx.encode())}))?;
        Ok(())
    }
    pub(super) fn expect(
        &mut self,
        kind: &str,
        hash: &str,
        since: u64,
        timeout: f64,
    ) -> Result<Value> {
        self.step(json!({"op":"expect","kind":kind,"hash":hash,"since":since,"timeout":timeout}))
    }
    pub(super) fn withhold(&mut self, tx: &RawTx) -> Result<()> {
        self.step(json!({"op":"withhold","hash":id(tx)}))?;
        Ok(())
    }
    fn release(&mut self, tx: &RawTx) -> Result<()> {
        self.step(json!({"op":"release","hash":id(tx)}))?;
        self.tx(tx)
    }
    pub(super) fn inv(&mut self, tx: &RawTx) -> Result<u64> {
        let cursor = self.next;
        self.step(json!({"op":"send_inv","kind":"tx","hash":id(tx)}))?;
        Ok(cursor)
    }
    // [D] 2026-10-15 (#78): announce a transaction id the peer does not hold.
    pub(super) fn inv_hash(&mut self, hash: &str) -> Result<u64> {
        let cursor = self.next;
        self.step(json!({"op":"send_inv","kind":"tx","hash":hash}))?;
        Ok(cursor)
    }
    // [D] 2026-10-15 (#79, lane s7-79): ask for a block as a compact block
    // (`getdata` MSG_CMPCT_BLOCK) and for some of its transactions
    // (`getblocktxn`, absolute indices); the cursor before the request.
    pub(super) fn getdata_cmpct(&mut self, hash: &str) -> Result<u64> {
        let cursor = self.next;
        self.step(json!({"op":"getdata","kind":"cmpct","hash":hash}))?;
        Ok(cursor)
    }
    pub(super) fn getblocktxn(&mut self, hash: &str, indices: &[usize]) -> Result<u64> {
        let cursor = self.next;
        self.step(json!({"op":"getblocktxn","hash":hash,"indices":indices}))?;
        Ok(cursor)
    }
    // [D] 2026-10-15 (#80): a `dsdetected` payload, sent through the pinned
    // framework's `msg_dsdetected` (mininode.py:2066-2093 at PIN); the result
    // carries the bytes the framework serialized back and whether they match.
    pub(super) fn dsdetected(&mut self, payload: &[u8]) -> Result<Value> {
        self.step(json!({"op":"send_dsdetected","hex":hex::encode(payload)}))
    }
    pub(super) fn close(&mut self) -> Result<()> {
        self.step(json!({"op":"close"}))?;
        self.child.wait().map_err(|e| e.to_string())?;
        self.closed = true;
        Ok(())
    }
}
impl Drop for Peer {
    fn drop(&mut self) {
        if !self.closed {
            let _ = self.child.kill();
            let _ = self.child.wait();
        }
    }
}
// [X] 2026-10-13 (#72): after the handshake, read this peer's offset sample
// (getpeerinfo `timeoffset`, src/rpc/net.cpp:229) and the node's adjusted-time
// offset (getnetworkinfo, src/rpc/net.cpp:626). The sample is nTime minus
// GetTime at the version's receipt (src/net/net_processing.cpp:1896-1898);
// the advertised time is the node's mock time, so both are zero when the
// clock is controlled. The receipt names them; mod.rs makes a row with
// another value non-judging.
pub(super) fn peer_clock(n: &mut Node, advertised: u64) -> Result<Value> {
    let peers = n.call("getpeerinfo", json!([]))?;
    let samples: Vec<Value> = peers
        .as_array()
        .ok_or("getpeerinfo")?
        .iter()
        .map(|p| p["timeoffset"].clone())
        .collect();
    let offset = n.time_offset()?;
    let receipt = json!({"event":"peer-clock","label":"[X]","advertised_time":advertised,"node_mock_time":n.clock,
        "peer_timeoffsets":samples,"timeoffset":offset,
        "source":format!("[SRC] src/net/net_processing.cpp:1896-1898; src/timedata.cpp:28-35,74-82; src/rpc/net.cpp:229,626 at {PIN}")});
    n.calls.push(receipt.clone());
    Ok(receipt)
}
const CONF:&str="listen=1\nbind=127.0.0.1:{P2P_PORT}\ngenesisactivationheight=1\nchronicleactivationheight=1000000\nacceptnonstdtxn=1\nacceptnonstdoutputs=1\nbanscore=100000\ndebug=mempool\ndebug=txnval\ndebug=netmsg\n";
const NOW: u64 = 1_700_000_000;
// [SRC] 2026-10-13: queue total excludes stored orphans, txn_validator.cpp:101-112.
pub(super) fn settled(n: &mut Node) -> Result<()> {
    let start = Instant::now();
    while start.elapsed() < Duration::from_secs(20) {
        let activity = n.call("getblockchainactivity", json!([]))?;
        if activity["transactions"] == 0 && activity["blocks"] == 0 {
            return Ok(());
        }
        thread::sleep(Duration::from_millis(50));
    }
    Err("PTV or block activity did not finish".into())
}
pub(super) fn pools(n: &mut Node) -> Result<Value> {
    settled(n)?;
    Ok(json!({"accepted":n.call("getrawmempool",json!([]))?,
        "held":n.call("getrawnonfinalmempool",json!([]))?,
        "orphans":n.call("getorphaninfo",json!([]))?["size"]}))
}
fn frame(parent: &RawTx, value: u64) -> RawTx {
    RawTx {
        version: 2,
        inputs: vec![RawInput {
            txid: parent.txid_internal(),
            vout: 0,
            script: vec![],
            sequence: u32::MAX,
        }],
        outputs: vec![RawOutput {
            satoshis: value,
            script: vec![0x51],
        }],
        lock_time: 0,
    }
}
fn funding(n: &mut Node, value: u64) -> Result<(RawTx, RawTx, RawTx, RawTx)> {
    let hashes = n.mine(103, NOW - 10000)?;
    let mut funds = vec![];
    for hash in &hashes[..4] {
        let b = n.call("getblock", json!([hash, 1]))?;
        let coin = n.raw_tx(&b["tx"][0])?;
        funds.push(spend_to(&coin, value, 1, vec![0x51]));
    }
    let (_, receipt) = n.submit(
        &[
            cb(104, "peer-funds"),
            funds[0].clone(),
            funds[1].clone(),
            funds[2].clone(),
            funds[3].clone(),
        ],
        (NOW - 1000) as u32,
    )?;
    if block_judgment(&receipt) != json!({"status":"ok"}) {
        return Err(format!("peer funding: {receipt}"));
    }
    n.call("setmocktime", json!([NOW]))?;
    Ok((
        funds.remove(0),
        funds.remove(0),
        funds.remove(0),
        funds.remove(0),
    ))
}
fn retain(n: &mut Node, p: &mut Peer, parent: &RawTx, child: &RawTx) -> Result<Value> {
    let empty = pools(n)?;
    if empty != json!({"accepted":[],"held":[],"orphans":0}) {
        return Err(format!("nonempty isolated pool: {empty}"));
    }
    let rpc_missing = n.receipt("sendrawtransaction", json!([hex::encode(child.encode())]))?;
    if rpc_missing["error"]["code"] != -25 || pools(n)?["orphans"] != 0 {
        return Err("RPC missing-input witness".into());
    }
    p.withhold(parent)?;
    let cursor = p.next;
    p.tx(child)?;
    settled(n)?;
    let request = p.expect("getdata", &id(parent), cursor, 10.0)?;
    let retained = pools(n)?;
    Ok(
        json!({"empty":empty,"rpc_missing_separate":rpc_missing,"request":request,"retained":retained}),
    )
}
fn named(list: &Value, names: &[(&str, &RawTx)]) -> Result<Value> {
    let mut found = vec![];
    for hash in list.as_array().ok_or("pool array")? {
        let name = names
            .iter()
            .find(|(_, tx)| *hash == json!(id(tx)))
            .ok_or_else(|| format!("unexpected pool id {hash}"))?
            .0;
        found.push(name);
    }
    found.sort();
    Ok(json!(found))
}
#[allow(
    clippy::too_many_arguments,
    reason = "one receipt's eight parts, each named at the call site"
)]
fn finish(
    n: &mut Node,
    p: &mut Peer,
    row: &Value,
    observed: Value,
    expected: Value,
    recipe: &str,
    mut fixtures: Value,
    wall: Option<String>,
) -> Result<Value> {
    p.close()?;
    n.stop()?;
    let log = fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
    let relevant: Vec<_> = log
        .lines()
        .filter(|l| {
            l.contains("orphan")
                || l.contains("recent")
                || l.contains("rolling minimum fee")
                || l.contains("Expired ")
                || l.contains("waitforptvcompletion: after")
        })
        .map(str::to_owned)
        .collect();
    // [X] 2026-10-13: each retained child was physically delivered exactly once.
    for key in ["C", "C2"] {
        if let Some(raw) = fixtures[key]["hex"].as_str() {
            let count = p
                .events
                .iter()
                .filter(|e| e["direction"] == "send" && e["command"] == "tx" && e["hex"] == raw)
                .count();
            if count != 1 {
                return Err(format!("{key} delivery count {count}, expected one"));
            }
            fixtures[format!("{key}_deliveries")] =
                json!({"date":"2026-10-13","label":"[M]","count":count});
        }
    }
    fixtures["conf"] = json!(n.conf);
    let mut r = measured(
        row,
        observed,
        expected,
        recipe,
        std::mem::take(&mut n.calls),
        fixtures,
    );
    r["date"] = json!("2026-10-13");
    r["peer"] = json!({"source_pin":PIN,"protocol_version":70016,"events":p.events,"receipt":format!("{}/peer.jsonl",instance_pointer(&n.dir)),"node_log":relevant});
    r["declared_expected"] = row["expected"].clone();
    if let Some(reason) = wall {
        r.as_object_mut()
            .or_err("r.as_object_mut()")?
            .remove("verdict");
        r["unrealizable"] = json!(reason);
    }
    Ok(r)
}
pub(super) fn selected(family: &str, row: &Value) -> bool {
    if family == "chain" {
        matches!(
            row["case"].as_str(),
            Some("era-clear" | "unrequested-equal-work")
        )
    } else {
        family == "mempool" && super::mempool::peer_recipe_reason(row).is_some()
    }
}
pub(super) fn row(root: &Path, family: &str, row: &Value) -> Result<Value> {
    if family == "chain" {
        return chain_row(root, row);
    }
    // [D] 2026-10-13, lane reclass-66b: limited asynchronous admission rows.
    if super::mempool::limited(row) {
        return super::mempool::limited_row(root, row);
    }
    let name = text(&row["id"])?;
    let mut extra = CONF.to_string();
    if name.contains("aggregate") {
        extra.push_str(&format!(
            "maxorphantxsize={}B\n",
            row["cfg"]["maxOrphanTxSize"]
        ));
    }
    if name.contains("expiry") {
        extra.push_str("maxorphantxsize=100B\n");
    }
    if name == "orphan-hysteresis-skips-expiry" {
        extra.push_str("maxtxsizepolicy=99999B\n");
    }
    // [SRC] 2026-10-13: txn_validator.cpp:24-28,359-538 scheduling frequency.
    if name == "orphan-parent-only-enqueues" {
        extra.push_str("txnvalidationasynchrunfreq=5000\n");
    }
    if name.contains("reject-filter") {
        extra.push_str("mempoolexpiry=1\n");
    }
    let mut launch_probe = Value::Null;
    if name.contains("p2p-size") {
        let cap = row["cfg"]["maxTxSizePolicy"]
            .as_u64()
            .or_err("row['cfg']['maxTxSizePolicy'].as_u64()")?;
        launch_probe = match start_retry(
            root,
            &format!("{name}-literal-cap"),
            &format!("{CONF}maxtxsizepolicy={cap}B\n"),
        ) {
            Ok(mut node) => {
                node.stop()?;
                json!({"unexpected_launch":true})
            }
            Err(error) => json!({"launch_error":error,"attempted_cap_bytes":cap}),
        };
    }
    let mut n = start_retry(root, name, &extra)?;
    let (f, f2, _f3, _f4) = funding(
        &mut n,
        if name == "absurd-fee-p2p-no-rpc-ceiling" {
            4_000_000_000
        } else {
            1000
        },
    )?;
    let parent = frame(&f, 900);
    let child = frame(
        &parent,
        if name == "orphan-revalidation-can-refuse" {
            901
        } else {
            800
        },
    );
    let mut p = Peer::start(&mut n)?;
    if name == "absurd-fee-p2p-no-rpc-ceiling" {
        let rpc = n.receipt("sendrawtransaction", json!([hex::encode(parent.encode())]))?;
        p.tx(&parent)?;
        let view = pools(&mut n)?;
        let observed = json!({"accepted":named(&view["accepted"],&[("P",&parent)])?,"orphans":view["orphans"],"rpc_ceiling_reject":rpc["error"]["message"].as_str().is_some_and(|s|s.contains("absurdly-high-fee"))});
        return finish(&mut n,&mut p,row,observed,json!({"accepted":["P"],"orphans":0,"rpc_ceiling_reject":true}),
            "[D] 2026-10-13: RPC ceiling probe separately; send the same high-fee body with P2P origin, then wait for validator completion and compare exact pools.",json!({"F":material(&f),"P":material(&parent),"rpc":rpc}),None);
    }
    if name.contains("reject-filter") || name == "reject-parent-prevents-orphan-retention" {
        return reject_row(n, p, row, f, parent, child);
    }
    let witness = retain(&mut n, &mut p, &parent, &child)?;
    if witness["request"]["matched"] != true || witness["retained"]["orphans"] != 1 {
        return Err(format!("orphan retention failed {name}: {witness}"));
    }
    if name == "orphan-parent-only-enqueues" {
        p.release(&parent)?;
        let started = Instant::now();
        let parent_pool = loop {
            let pool = n.call("getrawmempool", json!([]))?;
            if pool
                .as_array()
                .or_err("pool.as_array()")?
                .contains(&json!(id(&parent)))
            {
                break pool;
            }
            if started.elapsed() > Duration::from_secs(20) {
                return Err("parent scheduling did not finish".into());
            }
            thread::sleep(Duration::from_millis(50));
        };
        // A completed synchronous validation takes the validator's main mutex.
        // It fences the parent cycle's orphan scheduling and queue swap before
        // reading the sole pending child. No second child is submitted.
        // [SRC] 2026-10-13: txn_validator.cpp:155-177,478-529.
        let barrier = RawTx {
            version: 1,
            inputs: vec![],
            outputs: vec![RawOutput {
                satoshis: 1,
                script: vec![0x51],
            }],
            lock_time: 77,
        };
        let fence = n.receipt("sendrawtransaction", json!([hex::encode(barrier.encode())]))?;
        let queued = json!({"accepted":named(&n.call("getrawmempool",json!([]))?,&[("P",&parent),("C",&child)])?,"orphans":n.call("getorphaninfo",json!([]))?["size"],"pending":n.call("getblockchainactivity",json!([]))?["transactions"]});
        let after = pools(&mut n)?;
        let observed = json!({"queued":queued,"retried_without_resubmission":after["accepted"].as_array().or_err("after['accepted'].as_array()")?.contains(&json!(id(&child))),"orphans_final":after["orphans"],"fence_rejected":fence["error"]["code"]==-26});
        return finish(&mut n,&mut p,row,observed,json!({"queued":{"accepted":["P"],"orphans":1,"pending":1},"retried_without_resubmission":true,"orphans_final":0,"fence_rejected":true}),
            "[D] 2026-10-13: retain the sole child, use a five-second validator period, deliver its parent, then fence completed parent scheduling with synchronous rejection of an unrelated input-empty RPC frame. The main mutex fence distinguishes the pending child from the completed parent. Observe P accepted, C alone orphaned and one queued transaction before the next cycle, then automatic child admission without resubmission. The projection judges this intermediate state, not a configurable literal batchSize selector.",json!({"F":material(&f),"P":material(&parent),"C":material(&child),"witness":witness,"parent_pool":parent_pool,"barrier":material(&barrier),"fence":fence,"queued":queued,"after":after}),None);
    }
    if name.contains("aggregate") {
        // Exact bounded two-child pool. Deliver each distinct parent later to attribute retention.
        let parent2 = frame(&f2, 900);
        let child2 = frame(&parent2, 800);
        p.withhold(&parent2)?;
        let cursor = p.next;
        p.tx(&child2)?;
        settled(&mut n)?;
        let request2 = p.expect("getdata", &id(&parent2), cursor, 10.0)?;
        let count = pools(&mut n)?["orphans"].clone();
        p.release(&parent)?;
        let after1 = pools(&mut n)?;
        p.release(&parent2)?;
        let after2 = pools(&mut n)?;
        let accepted2 = after2["accepted"]
            .as_array()
            .or_err("the pool's accepted list")?;
        let retained: Vec<_> = [&child, &child2]
            .into_iter()
            .filter(|c| accepted2.contains(&json!(id(c))))
            .collect();
        let retained_bytes: usize = retained.iter().map(|c| c.encode().len()).sum();
        let observed = json!({"orphanCount":count,"orphanBytes":retained_bytes,"retainedSetSize":retained.len(),"orphans_final":after2["orphans"],"parent_requests":request2["matched"]==true});
        let both = name.ends_with("135");
        return finish(&mut n,&mut p,row,observed,json!({"orphanCount":if both{2}else{1},"orphanBytes":if both{122}else{61},"retainedSetSize":if both{2}else{1},"orphans_final":0,"parent_requests":true}),
            "[D] 2026-10-13: establish one isolated orphan; send a second 61-byte child at the literal byte cap; release each independent parent separately. Child admission without resubmission attributes which of the bounded pair survived. Salted eviction order is observed, not assumed.",json!({"witness":witness,"F":material(&f),"F2":material(&f2),"P":material(&parent),"C":material(&child),"P2":material(&parent2),"C2":material(&child2),"after_parent1":after1,"after_parent2":after2}),None);
    }
    if name == "orphan-hysteresis-skips-expiry" {
        n.call("setmocktime", json!([NOW + 1200]))?;
        let expired = pools(&mut n)?;
        // [SRC] 2026-10-13: validation.cpp:1904-1915 still calls the limiter
        // after orphan_txns.cpp:55-62 ignores this auxiliary oversized body.
        let auxiliary_parent = frame(&f2, 900);
        let mut auxiliary = frame(&auxiliary_parent, 800);
        auxiliary.outputs[0].script = [vec![0x00, 0x6a], vec![0u8; 100000]].concat();
        p.withhold(&auxiliary_parent)?;
        let cursor = p.next;
        p.tx(&auxiliary)?;
        let requested = p.expect("getdata", &id(&auxiliary_parent), cursor, 10.0)?;
        // A retained orphan makes waitforptvcompletion wait indefinitely.
        // [SRC] 2026-10-13: validation.cpp:1793,1805-1806 logs completion
        // after the missing-input handler and its limitTxnsSize call return.
        settled(&mut n)?;
        let after_trigger = pools(&mut n)?;
        let log = fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
        let ignored = log
            .lines()
            .any(|l| l.contains("ignoring large orphan tx") && l.contains(&id(&auxiliary)));
        let handled = log
            .lines()
            .any(|l| l.contains("detected orphan") && l.contains(&id(&auxiliary)));
        p.release(&parent)?;
        let retry = pools(&mut n)?;
        let observed = json!({"auxiliary_completed":handled,"expired_orphans":expired["orphans"],"auxiliary_requested":requested["matched"],"auxiliary_ignored":ignored,"orphans_after_trigger":after_trigger["orphans"],"accepted":named(&retry["accepted"],&[("P",&parent),("C",&child)])?,"orphans_final":retry["orphans"]});
        let expected = json!({"auxiliary_completed":true,"expired_orphans":1,"auxiliary_requested":true,"auxiliary_ignored":true,"orphans_after_trigger":1,"accepted":["C","P"],"orphans_final":0});
        let wall = if !ignored || !handled {
            Some("no-growth P2P trigger attempted with an auxiliary body above maxtxsizepolicy=99999B, but the log did not establish both the ignoring-large-orphan gate in src/orphan_txns.cpp:55-62 and completed missing-input handling in src/validation.cpp:1793,1805-1806; the missing-input route to limitTxnsSize in src/validation.cpp:1904-1915 remains unwitnessed at 6504a3af".into())
        } else {
            None
        };
        return finish(&mut n,&mut p,row,observed,expected,
            "[D] 2026-10-13: retain one 61-byte child at aggregate cap 100B (hysteresis 10B), advance to its expiry, then send one auxiliary missing-input body above the allowed individual cap 99999B. Require its parent request, ignored-large-orphan log and completed PTV; count stays one because zero untrimmed bytes skip the sweep. Independent parent release establishes the original child by automatic admission without resubmission. The auxiliary individual-size setting leaves the pure sweep projection unchanged.",
            json!({"F":material(&f),"P":material(&parent),"C":material(&child),"witness":witness,"expired":expired,"auxiliary":material(&auxiliary),"auxiliary_parent":material(&auxiliary_parent),"auxiliary_requested":requested,"after_trigger":after_trigger,"retry":retry}),wall);
    }
    let mut wall = None;
    let mut after_time = Value::Null;
    if name.contains("expiry") {
        n.call("setmocktime", json!([NOW + 1200]))?;
        settled(&mut n)?;
        after_time = pools(&mut n)?;
        wall=Some("peer retained the sole 61-byte child at maxorphantxsize=100B, advanced exactly 1200 seconds, observed zero PTV activity and then delivered its parent. This cannot realize the declared orphanSweep: admission already reset untrimmedBytes to zero; no periodic orphan sweep or RPC selects limitTxnsSize with the row's untrimmedBytes state. Waiting for PTV is not orphan maintenance completion. [SRC] src/orphan_txns.cpp:175-224; src/validation.cpp:1904-1915; src/txn_validator.cpp:359-538 at 6504a3af".into());
    }
    if name.contains("p2p-size") {
        wall=Some(format!("peer attempted the literal {}-byte maxtxsizepolicy launch, which was refused, then witnessed retention and retry of the 61-byte child at the allowed default. The launch getter refuses values below MAX_TX_SIZE_POLICY_BEFORE_GENESIS, so the named orphan cap cannot be selected. [SRC] src/configscriptpolicy.cpp:415-440; src/orphan_txns.cpp:51-58 at 6504a3af",row["cfg"]["maxTxSizePolicy"]));
    }
    let cursor = p.next;
    p.release(&parent)?;
    let view = pools(&mut n)?;
    let completed = n.call("getblockchainactivity", json!([]))?;
    n.call("waitforptvcompletion", json!([]))?;
    let reject = if name == "orphan-revalidation-can-refuse" {
        p.expect("reject", &id(&child), cursor, 5.0)?
    } else {
        Value::Null
    };
    let observed = json!({"missing_parent_request":witness["request"]["matched"],"orphan_retained":witness["retained"]["orphans"],"accepted":named(&view["accepted"],&[("P",&parent),("C",&child)])?,"orphans_final":view["orphans"],"child_reject":if reject.is_null(){Value::Null}else{reject["observations"].as_array().or_err("reject['observations'].as_array()")?.iter().find(|v|v["command"]=="reject").map(|v|json!({"code":v["code"],"reason":v["reason"]})).unwrap_or(Value::Null)}});
    let refuses = name == "orphan-revalidation-can-refuse";
    let expected = json!({"missing_parent_request":true,"orphan_retained":1,"accepted":if refuses{json!(["P"])}else{json!(["C","P"])},"orphans_final":0,"child_reject":if refuses{json!({"code":16,"reason":"bad-txns-in-belowout"})}else{Value::Null}});
    finish(&mut n,&mut p,row,observed,expected,
        "[D] 2026-10-13: empty pools; RPC missing inputs separately; withhold P; send exactly one C; record getdata(P) and count 0 to 1; release/send P once; wait for PTV completion; observe retry result without resending C.",json!({"F":material(&f),"P":material(&parent),"C":material(&child),"witness":witness,"after_time":after_time,"launch_probe":launch_probe,"completion":completed}),wall)
}
fn reject_row(
    mut n: Node,
    mut p: Peer,
    row: &Value,
    f: RawTx,
    parent: RawTx,
    child: RawTx,
) -> Result<Value> {
    let name = text(&row["id"])?;
    let mut target = parent.clone();
    let mut conflict = Value::Null;
    if name == "reject-parent-prevents-orphan-retention" {
        target.outputs[0].satoshis = 1001;
        p.withhold(&target)?;
    } else {
        let k = frame(&f, 850);
        conflict = n.receipt("sendrawtransaction", json!([hex::encode(k.encode())]))?;
        if conflict.get("error").is_some() {
            return Err(format!("reject cache conflict setup: {conflict}"));
        }
    }
    let cursor = p.inv(&target)?;
    let requested = p.expect("getdata", &id(&target), cursor, 10.0)?;
    p.tx(&target)?;
    settled(&mut n)?;
    let initial_reject = if name == "reject-parent-prevents-orphan-retention" {
        p.expect("reject", &id(&target), cursor, 5.0)?
    } else {
        Value::Null
    };
    let cursor = p.inv(&target)?;
    let cached = p.expect("none", &id(&target), cursor, 2.0)?;
    let mut child_witness = Value::Null;
    let mut expiry = Value::Null;
    let mut rpc_retry = Value::Null;
    if name == "reject-parent-prevents-orphan-retention" {
        let c = frame(&target, 800);
        p.tx(&c)?;
        child_witness = pools(&mut n)?;
    } else {
        // [SRC] 2026-10-13: batch postprocessing calls LimitMempoolSize, txn_validator.cpp:303-314.
        n.call("setmocktime", json!([NOW + 3601]))?;
        let invalid0 = RawTx {
            version: 1,
            inputs: vec![],
            outputs: vec![RawOutput {
                satoshis: 1,
                script: vec![0x51],
            }],
            lock_time: 0,
        };
        let mut invalid1 = invalid0.clone();
        invalid1.lock_time = 1;
        let sweep=n.receipt("sendrawtransactions",json!([[{"hex":hex::encode(invalid0.encode())},{"hex":hex::encode(invalid1.encode())}]]))?;
        expiry = json!({"trigger":sweep,"pools":pools(&mut n)?});
        if expiry["pools"]["accepted"] != json!([]) {
            return Err(format!("conflict expiry not complete: {expiry}"));
        }
        let cursor = p.inv(&target)?;
        let suppressed = p.expect("none", &id(&target), cursor, 2.0)?;
        expiry["cache_after_expiry"] = suppressed;
        if name == "reject-filter-rpc-retries" {
            rpc_retry = n.receipt("sendrawtransaction", json!([hex::encode(target.encode())]))?;
            expiry["after_rpc"] = pools(&mut n)?;
            // Remove the admitted retry without a tip change before the reset traffic probe.
            n.call("setmocktime", json!([NOW + 7202]))?;
            n.receipt("sendrawtransactions",json!([[{"hex":hex::encode(invalid0.encode())},{"hex":hex::encode(invalid1.encode())}]]))?;
        }
    }
    let before_tip = n.call("getbestblockhash", json!([]))?;
    let (_, tip_receipt) = n.submit(&[cb(105, "reject-reset")], (NOW + 7203) as u32)?;
    let after_tip = n.call("getbestblockhash", json!([]))?;
    let cursor = p.inv(&target)?;
    let reset = p.expect("getdata", &id(&target), cursor, 10.0)?;
    let mut observed = json!({"requested_before_rejection":requested["matched"],"cached_silence":cached["matched"],"tip_changed":before_tip!=after_tip,"requested_after_reset":reset["matched"]});
    let mut expected = json!({"requested_before_rejection":true,"cached_silence":true,"tip_changed":true,"requested_after_reset":true});
    if name == "reject-parent-prevents-orphan-retention" {
        observed["orphans"] = child_witness["orphans"].clone();
        expected["orphans"] = json!(0);
        observed["wire_rejected_parent"] = initial_reject["matched"].clone();
        expected["wire_rejected_parent"] = json!(true);
    } else {
        observed["silence_after_conflict_expiry"] = expiry["cache_after_expiry"]["matched"].clone();
        expected["silence_after_conflict_expiry"] = json!(true);
        if name == "reject-filter-rpc-retries" {
            observed["rpc_retry_admitted"] = json!(
                rpc_retry.get("error").is_none()
                    && expiry["after_rpc"]["accepted"] == json!([id(&target)])
            );
            expected["rpc_retry_admitted"] = json!(true);
        }
    }
    finish(&mut n,&mut p,row,observed,expected,
        "[D] 2026-10-13: inventory/getdata before rejection; reject an invalid parent or a valid conflict; inventory silence while cached; expire the competing spend through the completed RPC batch without changing tip; probe silence/RPC bypass separately; submit an empty tip-changing block and observe renewed getdata. No whitelist.",
        json!({"F":material(&f),"P":material(&target),"unused_original_child":material(&child),"conflict":conflict,"expiry":expiry,"child_pools":child_witness,"rpc_retry":rpc_retry,"tip_receipt":tip_receipt}),None)
}
fn chain_row(root: &Path, row: &Value) -> Result<Value> {
    let name = text(&row["id"])?;
    let mut conf = CONF
        .replace(
            "genesisactivationheight=1\n",
            "genesisactivationheight=10000\n",
        )
        .replace(
            "chronicleactivationheight=1000000",
            "chronicleactivationheight=15000",
        );
    if row["case"] == "era-clear" {
        conf.push_str(
            "maxmempool=0\nmaxmempoolsizedisk=10000B\nminconsolidationfactor=0\ncheckmempool=0\n",
        );
    }
    let mut n = start_retry(root, name, &conf)?;
    let (f, f2, f3, f4) = funding(&mut n, 1_000_000)?;
    let parent = frame(&f, 750_000);
    let child = frame(&parent, 1000);
    let mut p = Peer::start(&mut n)?;
    if row["case"] == "unrequested-equal-work" {
        let (b, bytes) = n.block_bytes(&[cb(105, "unrequested-B")], (NOW + 1) as u32)?;
        let (a, accepted) = n.submit(&[cb(105, "active-A")], NOW as u32)?;
        let cursor = p.next;
        // Body arrives without an announcement/request, as p2p-acceptblock.py:155-183.
        p.step(json!({"op":"send_block","hex":hex::encode(&bytes)}))?;
        let traffic = p.expect("none", &b, cursor, 2.0)?;
        let active = n.call("getbestblockhash", json!([]))?;
        let tips = n.call("getchaintips", json!([]))?;
        let header = n.call("getblockheader", json!([b, true]))?;
        let aheader = n.call("getblockheader", json!([a, true]))?;
        // [SRC] 2026-10-13: p2p-acceptblock.py:155-167 uses decoded getblock.
        let body = n.receipt("getblock", json!([b, 1]))?;
        let status = tips
            .as_array()
            .or_err("tips.as_array()")?
            .iter()
            .find(|v| v["hash"] == b)
            .map(|v| v["status"].clone())
            .unwrap_or(Value::Null);
        let observed = json!({"ignored":active==a,"bodyAbsent":body.get("error").is_some(),"equalWork":header["chainwork"]==aheader["chainwork"],"notFailed":status=="headers-only"});
        return finish(&mut n,&mut p,row,observed,row["expected"].clone(),
            "[D] 2026-10-13: construct rival B at the same predecessor as A; accept A by RPC; send B body without inv/header/request from the unwhitelisted peer; observe header-only status, unavailable body, equal chainwork and unchanged active tip.",json!({"A":a,"B":b,"block_hex":hex::encode(bytes),"active_receipt":accepted,"traffic":traffic,"header":header,"body":body,"tips":tips}),None);
    }
    let h = row["height"].as_u64().ok_or("era height")?;
    // [D] 2026-10-13: bounded mining batches stay within the RPC timeout.
    let mut remaining = h - 105;
    let mut mined = 0;
    while remaining > 0 {
        let batch = remaining.min(100);
        n.mine(batch, NOW + mined * 600)?;
        remaining -= batch;
        mined += batch;
    }
    let mut crossing_time = n.tip()?["time"].as_u64().ok_or("tip time")? + 1;
    n.call("setmocktime", json!([crossing_time]))?;
    // Before crossing h, preserve the sole orphan and attempt the declared held entry.
    let witness = retain(&mut n, &mut p, &parent, &child)?;
    let mut held = frame(&f2, 900);
    held.lock_time = (h + 100) as u32;
    held.inputs[0].sequence = 0;
    // [SRC] 2026-10-13: held storage survives clear and accepted-pool reorg
    // cleanup, txmempool.cpp:947-1023,1345-1363; time_locked_mempool.cpp:611-641.
    // Prepare the pre-Genesis held entry at a post-Genesis next-block tip,
    // then roll back the empty setup block with the sole orphan still retained.
    let mut held_setup = Value::Null;
    let held_receipt = if h == 9999 {
        let (hash, receipt) = n.submit(&[cb(h as u32, "held-era-setup")], crossing_time as u32)?;
        if block_judgment(&receipt) != json!({"status":"ok"}) {
            return Err(format!("held setup block: {receipt}"));
        }
        let reply = n.receipt("sendrawtransaction", json!([hex::encode(held.encode())]))?;
        let post_genesis = pools(&mut n)?;
        n.call("invalidateblock", json!([hash]))?;
        let rolled = pools(&mut n)?;
        let rollback_tip = n.tip()?;
        held_setup = json!({"block":hash,"receipt":receipt,"post_genesis_next_block":post_genesis,"rolled_back":rolled,"tip":rollback_tip});
        crossing_time += 1;
        reply
    } else {
        n.receipt("sendrawtransaction", json!([hex::encode(held.encode())]))?
    };
    // [SRC] 2026-10-13: zero resident allowance with a bounded disk pool,
    // config.cpp:2440-2475. Evict pressure while retaining a higher-fee entry.
    let accepted_tx = frame(&f3, 999700);
    let accepted_receipt = n.receipt(
        "sendrawtransaction",
        json!([hex::encode(accepted_tx.encode())]),
    )?;
    let mut pressure = frame(&f4, 980000);
    pressure.outputs[0].script = [vec![0x00, 0x6a], vec![0u8; 20000]].concat();
    let pressure_receipt = n.receipt(
        "sendrawtransaction",
        json!([hex::encode(pressure.encode())]),
    )?;
    let bump = n.call("getmempoolinfo", json!([]))?;
    let delta_id = id(&accepted_tx);
    n.call("prioritisetransaction", json!([delta_id, 0, 123]))?;
    let before = pools(&mut n)?;
    let fee_before = n.call("getmempoolinfo", json!([]))?;
    let (_, crossing) = n.submit(&[cb(h as u32, "era-crossing")], crossing_time as u32)?;
    let after = pools(&mut n)?;
    let fee_after = n.call("getmempoolinfo", json!([]))?;
    let after_verbose = n.call("getrawmempool", json!([true]))?;
    let delta_probe = n.receipt(
        "sendrawtransaction",
        json!([hex::encode(accepted_tx.encode())]),
    )?;
    let delta_verbose = n.call("getrawmempool", json!([true]))?;
    let entry = &delta_verbose[&delta_id];
    let delta_retained = entry["modifiedfee"]
        .as_f64()
        .zip(entry["fee"].as_f64())
        .is_some_and(|(modified, fee)| ((modified - fee) * 100_000_000.0 - 123.0).abs() < 0.1);
    p.release(&parent)?;
    let retry = pools(&mut n)?;
    let positive = fee_before["mempoolminfee"]
        .as_f64()
        .is_some_and(|v| v > 0.000005);
    let fee_reset = fee_after["mempoolminfee"]
        .as_f64()
        .is_some_and(|v| v <= 0.000005);
    let observed = json!({"accepted":after["accepted"].as_array().or_err("after['accepted'].as_array()")?.len(),"held":after["held"].as_array().or_err("after['held'].as_array()")?.len(),"orphans":after["orphans"],"deltas":if delta_retained{1}else{0},"feeReset":fee_reset,"retry":{"accepted":named(&json!(retry["accepted"].as_array().or_err("retry['accepted'].as_array()")?.iter().filter(|v| *v == &json!(id(&parent)) || *v == &json!(id(&child))).cloned().collect::<Vec<_>>()),&[("P",&parent),("C",&child)])?,"orphans":retry["orphans"]}});
    let wall = if held_receipt.get("error").is_some() {
        Some("peer retained the sole orphan and crossed the literal named height; the attempted non-final entry was refused before Genesis. The peer attempted post-Genesis holding followed by empty-block invalidation for the pre-Genesis predecessor; the required held setup was not established. Accepted/held/orphan pools, the named delta and fee snapshots are recorded separately. [SRC] src/validation.cpp:1101-1138,4036-4053 at 6504a3af".into())
    } else if !positive || accepted_receipt.get("error").is_some() {
        Some("peer retained the sole orphan across the literal named height, attempted pressure eviction and delta installation, and recorded pools and retry. The pressure probe did not establish a positive rolling fee with the declared accepted entry; feeReset remains unobservable from a floor-only or refused setup. [SRC] src/txmempool.cpp:2624-2647,2704-2800; src/validation.cpp:4036-4053 at 6504a3af".into())
    } else {
        None
    };
    let mut expected = row["expected"].clone();
    expected["retry"] = row["peer_retry"].clone();
    finish(&mut n,&mut p,row,observed,expected,
        "[D] 2026-10-13: mine to named predecessor with Genesis 10000 and Chronicle 15000; establish one isolated orphan and its getdata; prepare held/accepted entries and a fee delta at the auxiliary 10000B disk allowance with a 20002-byte primary pressure script paying 20000 sat; for 9999 hold at next-block Genesis and invalidate the empty setup block, verifying held/orphan retention at 9998; submit the empty crossing body; read pools and a positive rolling-fee reset. Observe the sole installed fee delta through verbose modifiedfee, re-admitting the cleared entry only after the crossing snapshot. Release the independent orphan parent (fee 250000 sat) and require P and C admission, zero orphans and one child delivery; C pays 749000 sat, sufficient for the pressure-induced rolling fee. No child resubmission.",
        json!({"F":material(&f),"F2":material(&f2),"P":material(&parent),"C":material(&child),"held":material(&held),"held_receipt":held_receipt,"held_setup":held_setup,"accepted_receipt":accepted_receipt,"witness":witness,"before":before,"after":after,"fee_before":fee_before,"fee_after":fee_after,"crossing":crossing,"retry":retry,"pressure":material(&pressure),"pressure_receipt":pressure_receipt,"bump":bump,"accepted":material(&accepted_tx),"delta_probe":delta_probe,"delta_verbose":delta_verbose,"after_verbose":after_verbose}),wall)
}
fn aggregate(marks: &BTreeMap<String, BTreeMap<String, String>>) -> Result<Value> {
    let mut counts = json!({"label":"[M]","date":"2026-10-13","rows":0,"measured":0,"agree":0,"diverge":0,"rpc-precheck":0,"unrealizable":0,"non-judging":0,"needs-peer":0,"pending":0});
    for family in FAMILIES {
        for row in row_read(family)? {
            let name = text(&row["id"])?;
            let token = marks
                .get(family)
                .and_then(|m| m.get(name))
                .map(String::as_str)
                .unwrap_or(row["node"].as_str().unwrap_or("pending #66"));
            let category = if token.starts_with("measured agree") {
                "agree"
            } else if token.starts_with("measured diverge") || token.starts_with("diverge ") {
                "diverge"
            } else if token.starts_with("rpc-precheck:") {
                "rpc-precheck"
            } else if token.starts_with("unrealizable:") {
                "unrealizable"
            } else if token.starts_with("measured non-judging") {
                "non-judging"
            } else if token.starts_with("needs-peer") {
                "needs-peer"
            } else {
                "pending"
            };
            counts["rows"] = json!(counts["rows"].as_u64().or_err("counts['rows'].as_u64()")? + 1);
            counts[category] = json!(
                counts[category]
                    .as_u64()
                    .or_err("counts[category].as_u64()")?
                    + 1
            );
            if matches!(category, "agree" | "diverge") {
                counts["measured"] = json!(
                    counts["measured"]
                        .as_u64()
                        .or_err("counts['measured'].as_u64()")?
                        + 1
                );
            }
        }
    }
    Ok(counts)
}
pub(super) fn suite(root: &Path, record: &str, run_id: &str, write: bool) -> Result<()> {
    let head = Command::new("git")
        .args(["rev-parse", "HEAD"])
        .output()
        .map_err(|e| e.to_string())?;
    let clock = Command::new("date")
        .args(["-u", "+%Y-%m-%dT%H:%M:%SZ"])
        .output()
        .map_err(|e| e.to_string())?;
    let args: Vec<_> = std::env::args().collect();
    let only = args
        .iter()
        .position(|a| a == "--peer-row")
        .and_then(|i| args.get(i + 1));
    let source_files = [
        "harness/peer/peer.py",
        "harness/src/scenarios/peer.rs",
        "harness/src/scenarios/core.rs",
        "harness/src/scenarios/mod.rs",
    ];
    let mut source = vec![];
    for path in source_files {
        source.extend(path.as_bytes());
        source.extend(fs::read(path).map_err(|e| e.to_string())?);
    }
    let runner_sha = hex::encode(bsv_rs::primitives::hash::sha256(&source));
    let dirty = Command::new("git")
        .args(["diff", "--quiet", "HEAD", "--"])
        .args(source_files)
        .status()
        .map_err(|e| e.to_string())?
        .code()
        != Some(0);
    let start = Instant::now();
    let mut results = vec![];
    let mut marks: BTreeMap<String, BTreeMap<String, String>> = BTreeMap::new();
    for family in ["mempool", "chain"] {
        for fixture in row_read(family)?
            .iter()
            .filter(|r| selected(family, r) && only.is_none_or(|name| r["id"] == name.as_str()))
        {
            let result = row(root, family, fixture)?;
            let token = if let Some(reason) = result["unrealizable"].as_str() {
                format!("unrealizable: {reason} [M] 2026-10-13 [X] {record}")
            } else {
                measured_token(&result, record)
            };
            println!(
                "peer row {}: {} [X]",
                fixture["id"],
                if result["unrealizable"].is_string() {
                    "unrealizable"
                } else {
                    text(&result["verdict"])?
                }
            );
            let mut result = result;
            result["family"] = json!(family);
            result["token"] = json!(token);
            marks
                .entry(family.into())
                .or_default()
                .insert(text(&fixture["id"])?.into(), token);
            results.push(result);
            // [D] 2026-10-13: preserve completed receipts even if a later row fails.
            write_json(
                &PathBuf::from(record.replace(".md", ".json")),
                &json!({"date":"2026-10-13","label":"[X]","source_pin":PIN,"framework_pin":PIN,"runner_sha256":runner_sha,"runner_dirty":dirty,"base_commit":String::from_utf8_lossy(&head.stdout).trim(),"started_utc":String::from_utf8_lossy(&clock.stdout).trim(),"run_id":run_id,"results":results,"aggregate":aggregate(&marks)?,"complete":false}),
            )?;
        }
    }
    if results.is_empty() {
        return Err("no selected peer rows".into());
    }
    let counts = aggregate(&marks)?;
    let agrees = results.iter().filter(|r| r["verdict"] == "agree").count();
    let diverges = results.iter().filter(|r| r["verdict"] == "diverge").count();
    let walls = results
        .iter()
        .filter(|r| r["unrealizable"].is_string())
        .count();
    let receipt = record.replace(".md", ".json");
    let mut md=format!("# [X] 2026-10-13: lane peer-66 regtest receipt\n\n[M] Commit measured: `{}`. UTC start: `{}`. Run `{run_id}`; fresh per-row instances under `~/bsv/targets/spec-oracle-scenarios/{run_id}/`. Wall [M] {:.3} seconds. Framework SHA [SRC] `{PIN}`. Runner SHA256 [M] `{runner_sha}`; runner dirty [M] `{dirty}`.\n\n[M] Peer rows {}, measured {}, agree {agrees}, diverge {diverges}, unrealizable {walls}, needs-peer 0, pending 0.\n\n[M] Re-cut chain/oracle aggregate: `{counts}`. Inherited rows retain their prior receipts; only the selected peer rows were replayed here. Intake remains its separate prior [M] 20 rows, measured 20, agree 20, diverge 0, rpc-precheck 0, unrealizable 0, needs-peer 0, pending 0.\n\n| row [D] | steps [D] | token [X] | receipt [X] |\n|---|---|---|---|\n",String::from_utf8_lossy(&head.stdout).trim(),String::from_utf8_lossy(&clock.stdout).trim(),start.elapsed().as_secs_f64(),results.len(),agrees+diverges);
    for r in &results {
        md.push_str(&format!(
            "| `{}/{}` | {} | {} | [{}]({}) |\n",
            text(&r["family"])?,
            text(&r["id"])?,
            text(&r["recipe"])?,
            text(&r["token"])?.replace('|', "/"),
            text(&r["id"])?,
            Path::new(&receipt)
                .file_name()
                .or_err("Path::new(&receipt).file_name()")?
                .to_string_lossy()
        ));
    }
    let events = results
        .iter()
        .map(|r| {
            r["peer"]["events"]
                .as_array()
                .or_err("a receipt's peer events")
        })
        .collect::<Result<Vec<_>>>()?;
    let commands: BTreeSet<String> = events
        .into_iter()
        .flatten()
        .filter_map(|e| e["command"].as_str().map(str::to_owned))
        .collect();
    md.push_str(&format!(
        "\n[M] 2026-10-13: observed protocol 70016 commands: {}.\n",
        commands.into_iter().collect::<Vec<_>>().join(", ")
    ));
    md.push_str("\n[D] 2026-10-13: instrument design in ten lines:\n\n");
    for line in [
        "Python imports the reference framework from its pinned clone; no framework bytes are copied.",
        "HEAD and the framework working files are checked before importing; every event carries the SHA.",
        "MY_VERSION is 70016 ([SRC] test/functional/test_framework/mininode.py:48 at the pin).",
        "Reference P2PHandler and P2PEventHandler frame messages and dispatch callbacks ([SRC] mininode.py:2118-2690).",
        "Reference message classes supply the tx/block/header/inventory steps and handshake traffic ([SRC] mininode.py:1177-1932).",
        "The reference regtest magic is da b5 bf fa ([SRC] mininode.py:2462-2467).",
        "JSON lines provide connect, send_tx, send_block, send_headers, send_inv, withhold, release, expect and close.",
        "The runner binds listen=1 to the reserved loopback P2P port; it never enables whitelist.",
        "Receipts retain UTC steps and full message serialization beside separate RPC receipts and node logs.",
        "This is an executable test instrument for S6 observations; S7's wire machine remains owed."
    ] {md.push_str(&format!("- [D] 2026-10-13: {line}\n"));}
    md.push_str("\n[X] 2026-10-13 walls: loopback only; discover/dnsseed/upnp disabled; standing RPC instances and mini untouched; private programs, forbidden records and tracker untouched. Per-id orphan evidence is confined to a known empty pool with one child or an explicitly bounded two-child eviction probe whose independent parent arrivals attribute retention. Scheduler completion is never inferred from setmocktime.\n");
    for r in &results {
        if let Some(reason) = r["unrealizable"].as_str() {
            md.push_str(&format!(
                "\n[X] 2026-10-13 `{}`: {reason}\n",
                text(&r["id"])?
            ));
        }
        if r["verdict"] == "diverge" {
            md.push_str(&format!("\n**Finding.** [X] 2026-10-13 `{}/{}` differs from the declared projection: expected `{}`, observed `{}`. The complete fresh prefix, materialized transaction bytes, protocol steps and exact node/RPC observations are in [{}]({}); classification is open for the captain to file. No tracker write was made.\n",text(&r["family"])?,text(&r["id"])?,r["expected"],r["observed"],text(&r["id"])?,Path::new(&receipt).file_name().or_err("Path::new(&receipt).file_name()")?.to_string_lossy()));
        }
    }
    fs::write(record, md).map_err(|e| e.to_string())?;
    write_json(
        &PathBuf::from(&receipt),
        &json!({"date":"2026-10-13","label":"[X]","source_pin":PIN,"framework_pin":PIN,"runner_sha256":runner_sha,"runner_dirty":dirty,"base_commit":String::from_utf8_lossy(&head.stdout).trim(),"started_utc":String::from_utf8_lossy(&clock.stdout).trim(),"run_id":run_id,"results":results,"aggregate":counts,"wall_seconds":start.elapsed().as_secs_f64(),"complete":only.is_none()}),
    )?;
    if write {
        for (family, marks) in &marks {
            let path = format!("corpus/chain/{family}/{family}.jsonl");
            let old = hex::encode(bsv_rs::primitives::hash::sha256(
                &fs::read(&path).map_err(|e| e.to_string())?,
            ));
            mark_rows(family, marks)?;
            let new = hex::encode(bsv_rs::primitives::hash::sha256(
                &fs::read(&path).map_err(|e| e.to_string())?,
            ));
            let index = fs::read_to_string("corpus/INDEX.md").map_err(|e| e.to_string())?;
            let mut indexed = false;
            let updated = index
                .split_inclusive('\n')
                .map(|line| {
                    if line.contains(&format!("`{path}`")) {
                        indexed = true;
                        line.replace(&old, &new)
                    } else {
                        line.to_owned()
                    }
                })
                .collect::<String>();
            if !indexed {
                return Err(format!("missing corpus index for {family}"));
            }
            fs::write("corpus/INDEX.md", updated).map_err(|e| e.to_string())?;
        }
    }
    println!("peer-scenarios: GREEN [X] receipts complete; rows [M] {}, agree {agrees}, diverge {diverges}, unrealizable {walls}",results.len());
    Ok(())
}
