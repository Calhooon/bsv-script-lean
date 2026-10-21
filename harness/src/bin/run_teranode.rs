//! Instance adapter for issue 41. The corpus and its recorded verdicts stay
//! unchanged. Synthetic outpoints are rebound to outputs created on the private
//! chain, with identical locking scripts and values. Signature-dependent and
//! absolute-height/time entries are undecided by name, before any submission.
//!
//! [SRC] Teranode v0.16.0 @ 4edb60a40c6628ff0ef60231c2628efd7103fde5:
//! services/rpc/handlers.go:830-935,2983-3026 (funding, submission, mining);
//! services/validator/Validator.go:1002,1105,1346 in 868-1547 (parents, spending, assembly);
//! services/validator/Server.go:606-777 (native block-context API);
//! services/subtreevalidation/check_block_subtrees.go:1278-1291 (block options).
//! Since #97 (lane trait-97, 2026-10-15) every read and submission goes through the
//! observation contract (harness/engines/teranode/contract.rs, the trait of
//! docs/CONFORMANCE-TERANODE-OBSERVATION.md section 6); road.py keeps the recipe's
//! attestation and the disk headroom, and reads nothing of the node.
//! [SRC] go-chaincfg v1.6.2 params.go:450,463,475-476 (regtest: maturity 100,
//! Genesis 100, Chronicle 200), required by the instance's go.mod:15.
//! Era mapping and absolute-row exclusion: tracker comment 5853443740.
//!
//! cargo run --release --locked --bin run_teranode -- --corpus ../corpus/seed
//!   --out ../harness/engines/instance41/runs/STAMP-seed [--limit N] [--plan-only]
//! Start instance.py with --validator under the box leg lock, build the native
//! client with native/build.py, then run this adapter. Stop the instance afterward.
//! `--witness OUT.json` instead runs the contract's finding witnesses (section 7 of the
//! page) on the running instance and writes their receipts; it judges no corpus.

use bsv_script_harness::fail::OrErr;
use std::collections::BTreeMap;
use std::fs::{self, File};
use std::io::{BufRead, BufReader, BufWriter, Write};
use std::path::{Path, PathBuf};
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};
use std::time::{Duration, Instant};

use bsv_script_harness::teranode_contract::{
    self, BlockRef, Instance41, SubmitRoad, TeranodeObservation, Transport, PIN, TAG,
};

use bsv_rs::primitives::ec::PrivateKey;
use bsv_rs::primitives::hash::{hash160, sha256};
use bsv_script_harness::block::try_p2pkh_spend;
use bsv_script_harness::corpus::{Divergence, Entry, ExpectJson, Manifest, PrevoutJson};
use bsv_script_harness::txraw::{txid_display_hex, txid_from_display_hex, RawOutput, RawTx};
use serde::Serialize;
use serde_json::{json, Value};

const PATHS: [&str; 2] = ["block", "mempool"];

fn arg(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|s| s == name)
        .and_then(|i| args.get(i + 1))
        .cloned()
}

fn sha_file(path: &Path) -> Result<String, String> {
    Ok(hex::encode(sha256(
        &fs::read(path).map_err(|e| e.to_string())?,
    )))
}

fn line<T: Serialize>(out: &mut impl Write, value: &T) -> Result<(), String> {
    serde_json::to_writer(&mut *out, value).map_err(|e| e.to_string())?;
    out.write_all(b"\n").map_err(|e| e.to_string())?;
    out.flush().map_err(|e| e.to_string())
}

struct Worker {
    child: Child,
    input: ChildStdin,
    output: BufReader<ChildStdout>,
}

impl Worker {
    fn new(cmd: &mut Command) -> Result<Self, String> {
        let mut child = cmd
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .map_err(|e| e.to_string())?;
        Ok(Self {
            input: child.stdin.take().or_err("child.stdin.take()")?,
            output: BufReader::new(child.stdout.take().or_err("child.stdout.take()")?),
            child,
        })
    }

    fn call(&mut self, request: &Value) -> Result<Value, String> {
        line(&mut self.input, request)?;
        let mut response = String::new();
        if self
            .output
            .read_line(&mut response)
            .map_err(|e| e.to_string())?
            == 0
        {
            return Err("instance worker ended without an answer".into());
        }
        serde_json::from_str(&response).map_err(|e| format!("worker protocol: {e}: {response}"))
    }
}

impl Drop for Worker {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

struct Road {
    node: Instance41,
    recipe: Worker,
    journal: BufWriter<File>,
    calls: u64,
}

/// The funding road's two ends (#132): a wall the run records (the node's answer, the manifest's `funding_wall`), or a
/// stop of the run (a malformed node answer where an unwrap stood: `run` returns the words and exits 1, as the panic
/// stopped it before).
enum Halt {
    Wall(Value),
    Stop(String),
}

impl From<Value> for Halt {
    fn from(w: Value) -> Self {
        Halt::Wall(w)
    }
}

impl From<String> for Halt {
    fn from(e: String) -> Self {
        Halt::Stop(e)
    }
}

impl Halt {
    /// The wall for the record, or the stop as the run's `Err`.
    fn wall(self) -> Result<Value, String> {
        match self {
            Halt::Wall(w) => Ok(w),
            Halt::Stop(e) => Err(e),
        }
    }
}

// A contract read that did not reach the node, as the wall the record carries.
fn wall(call: &str, t: Transport) -> Value {
    json!({"call": call, "surface": t.surface, "answer": {"transport_error": t.message}})
}

// A submission's envelope as the rows read it; a transport failure is `transport_error`.
fn envelope(answer: Result<Value, Transport>) -> Value {
    answer.unwrap_or_else(|t| json!({"transport_error": t.to_string()}))
}

impl Road {
    /// One line of the road's journal: a call of the contract (its surface, request, reply and
    /// handler) or of the recipe's worker.
    #[allow(
        clippy::expect_used,
        reason = "a journal write failure stops the road rather than losing an answer (the comment above); the message names it"
    )]
    fn call(&mut self, entry: Value) {
        self.calls += 1;
        // A journal write failure stops the road, rather than losing an answer.
        line(
            &mut self.journal,
            &json!({"call": self.calls, "entry": entry}),
        )
        .expect("RPC journal");
    }

    /// One operation of the contract, its journal written.
    fn node<T>(
        &mut self,
        op: impl FnOnce(&mut Instance41) -> Result<T, Transport>,
    ) -> Result<T, Transport> {
        let answer = op(&mut self.node);
        for entry in self.node.take_journal() {
            self.call(entry);
        }
        answer
    }

    /// The recipe's worker (road.py): `attest` or `headroom`, never a read of the node.
    fn recipe(&mut self, method: &str) -> Value {
        let request = json!({"method": method, "params": []});
        let response = self
            .recipe
            .call(&request)
            .unwrap_or_else(|e| json!({"transport_error": e}));
        self.call(json!({"surface": "recipe", "request": request, "reply": response}));
        response
    }

    // The tip through the contract (gRPC GetBestBlockHeader and GetBestHeightAndTime): `mediantime` is
    // the median of the tip's last 11 timestamps, the tip included, the candidate's parent median time
    // (the value getblockbyheight's `mediantime` gave before #97, services/rpc/handlers.go:1590-1622).
    fn tip(&mut self) -> Result<Value, Value> {
        let t = self.node(|c| c.tip()).map_err(|t| wall("tip", t))?;
        Ok(
            json!({"blocks": t.height, "mediantime": t.tip_mtp, "time": t.time, "bestblockhash": t.hash,
                  "chain_work": t.chain_work, "header_median_time_past": t.median_time_past}),
        )
    }

    // Block assembly takes submitted transactions into subtrees asynchronously;
    // a block generated before they arrive is empty. Wait until the mining
    // candidate counts at least `pending` transactions, then mine one block.
    // [SRC] services/rpc/handlers.go:1104-1172 (getminingcandidate) at the pin.
    fn mine_pending(&mut self, pending: u64, address: &str) -> Result<(), Value> {
        let start = Instant::now();
        loop {
            let (n, candidate) = self
                .node(|c| c.candidate_count())
                .map_err(|t| wall("getminingcandidate", t))?;
            if n >= pending {
                break;
            }
            if start.elapsed() >= Duration::from_secs(300) {
                return Err(
                    json!({"call": "getminingcandidate", "pending": pending, "answer": candidate,
                                  "reason": "block assembly did not take the submitted transactions within 300 seconds"}),
                );
            }
            std::thread::sleep(Duration::from_millis(250));
        }
        self.mine(1, address)
    }

    fn mine(&mut self, n: u32, address: &str) -> Result<(), Value> {
        if n == 0 {
            return Ok(());
        }
        self.node(|c| c.mine(n, address))
            .map_err(|t| wall("generatetoaddress", t))?;
        Ok(())
    }

    fn bake(&mut self, to: u32, address: &str) -> Result<(), Halt> {
        let mut height = self.tip()?["blocks"]
            .as_u64()
            .or_err("self.tip()?['blocks'].as_u64()")? as u32;
        if height > to {
            return Err(Halt::Wall(
                json!({"call": "bake", "tip": height, "requested": to,
                              "reason": "the chain cannot be lowered through this adapter"}),
            ));
        }
        while height < to {
            let n = (to - height).min(100);
            self.mine(n, address)?;
            let actual = self.tip()?["blocks"]
                .as_u64()
                .or_err("self.tip()?['blocks'].as_u64()")? as u32;
            if actual != height + n {
                return Err(Halt::Wall(
                    json!({"call": "generatetoaddress", "expected_height": height + n, "actual_height": actual}),
                ));
            }
            height = actual;
            if height % 1000 < 100 || height == to {
                println!("run_teranode: baked height {height}/{to}");
            }
        }
        Ok(())
    }

    // The funding's record through the contract's tx_record (/txmeta/:hash/json): mined at `height`,
    // with the submitted scripts and values. [SRC] services/asset/httpimpl/GetTransactionMeta.go:94-238.
    fn confirm(&mut self, tx: &RawTx, height: u32) -> Result<Value, Value> {
        let txid = txid_display_hex(&tx.txid_internal());
        let start = Instant::now();
        loop {
            let record = self
                .node(|c| c.tx_record(&txid))
                .map_err(|t| wall("confirm funding height", t))?;
            if let Some(r) = record
                .as_ref()
                .filter(|r| r.block_heights.contains(&height))
            {
                let meta = &r.raw;
                let outputs = meta["tx"]["outputs"].as_array();
                let matches = outputs.is_some_and(|outputs| {
                    outputs.len() == tx.outputs.len()
                        && outputs.iter().zip(&tx.outputs).all(|(actual, expected)| {
                            actual["satoshis"].as_u64() == Some(expected.satoshis)
                                && actual["lockingScript"].as_str()
                                    == Some(hex::encode(&expected.script).as_str())
                        })
                });
                if matches {
                    return Ok(meta.clone());
                }
                return Err(
                    json!({"call": "confirm funding outputs", "txid": txid, "height": height,
                    "answer": {"result": meta}, "reason": "the node's reported funding outputs do not match the submitted scripts and values",
                    "source": "[SRC] services/asset/httpimpl/GetTransactionMeta.go:94-238 at the instance pin"}),
                );
            }
            if start.elapsed() >= Duration::from_secs(15) {
                let answer = record.map_or(json!({"http": 404}), |r| json!({"result": r.raw}));
                return Err(
                    json!({"call": "confirm funding height", "txid": txid, "height": height,
                    "answer": answer, "reason": "the node did not report the required funding height within 15 seconds",
                    "source": "[SRC] services/asset/httpimpl/GetTransactionMeta.go:94-238 at the instance pin"}),
                );
            }
            std::thread::sleep(Duration::from_millis(100));
        }
    }
}

fn has_error(response: &Value) -> bool {
    !response["error"].is_null() || !response["transport_error"].is_null()
}

fn era(height: u32) -> u8 {
    if height >= 943_816 {
        2
    } else if height >= 620_538 {
        1
    } else {
        0
    }
}

// Regtest heights at go-chaincfg v1.6.2 (params.go:463,475-476): Genesis 100,
// Chronicle 200, coinbase maturity 100. The funding and the spend both lie in
// [lo, hi]. Pre-Genesis has no range: the earliest spendable coinbase output
// enters a block at height 101, past Genesis, so no pre-Genesis output can be
// funded on this chain and those rows are undecided.
const REGTEST_GENESIS: u32 = 100;
const REGTEST_CHRONICLE: u32 = 200;

fn range(era: u8) -> Option<(u32, u32)> {
    match era {
        0 => None,
        1 => Some((REGTEST_GENESIS, REGTEST_CHRONICLE - 1)),
        _ => Some((REGTEST_CHRONICLE, u32::MAX)),
    }
}

// Inspect opcode boundaries, so a CHECKSIG byte inside pushed data does not
// exclude an outpoint-independent seed entry.
fn contains_opcode(script: &[u8], needles: &[u8]) -> bool {
    let mut p = 0usize;
    while p < script.len() {
        let op = script[p];
        p += 1;
        if needles.contains(&op) {
            return true;
        }
        let n = match op {
            1..=75 => op as usize,
            0x4c => {
                if p >= script.len() {
                    return false;
                }
                let n = script[p] as usize;
                p += 1;
                n
            }
            0x4d => {
                if p + 2 > script.len() {
                    return false;
                }
                let n = u16::from_le_bytes([script[p], script[p + 1]]) as usize;
                p += 2;
                n
            }
            0x4e => {
                if p + 4 > script.len() {
                    return false;
                }
                let n = u32::from_le_bytes([script[p], script[p + 1], script[p + 2], script[p + 3]])
                    as usize;
                p += 4;
                n
            }
            _ => 0,
        };
        p = match p.checked_add(n) {
            Some(p) => p,
            None => return false,
        };
    }
    false
}

fn is_null(p: &PrevoutJson) -> bool {
    p.vout == u32::MAX && p.txid.bytes().all(|b| b == b'0')
}

// Each input's funded slot: equal outpoints share one slot (a duplicate-input
// entry keeps its duplicate), a null outpoint has none and is submitted as the
// entry has it. `distinct` lists, per slot, the prevout index that funds it.
fn outpoint_slots(e: &Entry) -> (Vec<Option<usize>>, Vec<usize>) {
    let mut distinct: Vec<usize> = Vec::new();
    let slots = e
        .prevouts
        .iter()
        .enumerate()
        .map(|(k, p)| {
            if is_null(p) {
                return None;
            }
            let found = distinct
                .iter()
                .position(|&j| e.prevouts[j].txid == p.txid && e.prevouts[j].vout == p.vout);
            Some(found.unwrap_or_else(|| {
                distinct.push(k);
                distinct.len() - 1
            }))
        })
        .collect();
    (slots, distinct)
}

fn exclusion(e: &Entry, tx: &RawTx) -> Result<Option<String>, String> {
    if tx.inputs.len() == 1 && e.prevouts.first().is_some_and(is_null) {
        return Ok(Some("a coinbase-shaped entry is judged as a block's coinbase; the instance's block path validates a transaction, and submitblock is unimplemented at the pin (services/rpc/Server.go:211)".into()));
    }
    if tx.lock_time != 0
        || tx.inputs.iter().any(|i| i.sequence != u32::MAX)
        || e.rule.starts_with("tx.locktime.")
        || e.rule.starts_with("tx.sequence.")
    {
        return Ok(Some("absolute locktime or sequence cannot be rebased without changing the witness (comment 5853443740)".into()));
    }
    let mut scripts: Vec<Vec<u8>> = Vec::new();
    for p in &e.prevouts {
        scripts.push(hex::decode(&p.script).or_err("a prevout script")?);
    }
    scripts.extend(tx.inputs.iter().map(|i| i.script.clone()));
    if scripts.iter().any(|s| contains_opcode(s, &[0xb1, 0xb2])) {
        return Ok(Some("CLTV/CSV absolute-height/time row is undecided under the era mapping (comment 5853443740)".into()));
    }
    if scripts
        .iter()
        .any(|s| contains_opcode(s, &[0xac, 0xad, 0xae, 0xaf]))
    {
        return Ok(Some("outpoint rebinding can change a signature digest; this adapter does not re-sign, because no entry carries its keys".into()));
    }
    if e.flags.is_some() {
        return Ok(Some(
            "the instance derives flags from its chain and cannot accept an explicit corpus word"
                .into(),
        ));
    }
    if e.prevouts
        .iter()
        .any(|p| era(p.height) != era(e.params.spend_height))
    {
        return Ok(Some("mixed prevout/spend eras need funding blocks in multiple era ranges; not implemented in this seed road".into()));
    }
    Ok(None)
}

#[allow(
    clippy::expect_used,
    reason = "sha256 of the well's fixed label is a valid secp256k1 scalar"
)]
fn well() -> (PrivateKey, Vec<u8>, String) {
    let key = PrivateKey::from_bytes(&sha256(b"bsv-script-lean/instance41/well"))
        .expect("PrivateKey::from_bytes(&sha256(b'bsv-script-lean/instance41/well'))");
    let h = hash160(&key.public_key().to_compressed());
    let script = [vec![0x76, 0xa9, 0x14], h.to_vec(), vec![0x88, 0xac]].concat();
    let mut data = vec![0x6f];
    data.extend(h);
    data.extend(&sha256(&sha256(&data))[..4]);
    let mut digits = vec![0u8];
    for byte in data {
        let mut carry = byte as u32;
        for d in &mut digits {
            carry += (*d as u32) << 8;
            *d = (carry % 58) as u8;
            carry /= 58;
        }
        while carry != 0 {
            digits.push((carry % 58) as u8);
            carry /= 58;
        }
    }
    const ABC: &[u8] = b"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
    let address = digits
        .iter()
        .rev()
        .map(|d| ABC[*d as usize] as char)
        .collect();
    (key, script, address)
}

#[derive(Default, Serialize)]
struct Counts {
    entries: u64,
    judged: u64,
    agreeing: u64,
    disagreeing: u64,
    no_reference: u64,
    unfundable: u64,
    undecided: u64,
}

struct Outputs {
    answers: BufWriter<File>,
    funding: BufWriter<File>,
    witnesses: BufWriter<File>,
    counts: BTreeMap<String, Counts>,
    undecided: Vec<Value>,
    unfundable: Vec<Value>,
}

fn reason(response: &Value) -> String {
    if let Some(s) = response["transport_error"]
        .as_str()
        .or_else(|| response["error"]["message"].as_str())
    {
        return s.to_string();
    }
    // A `valid:false` result with no error keeps the node's own text.
    match response["result"]["reason"].as_str() {
        Some(s) if !s.is_empty() => s.to_string(),
        _ if response["result"].is_object() => response["result"].to_string(),
        _ => "the instance returned no verdict".to_string(),
    }
}

// The codes that carry the node's verdict on a transaction, errors/error.proto:54-63
// at the pin. Any other innermost code (UNKNOWN (0), PROCESSING (4), an engine
// exception) is a node fault, never a verdict.
const VERDICT_CODES: [&str; 4] = ["TX_INVALID", "TX_CONSENSUS", "TX_POLICY", "TX_LOCK_TIME"];

// Operational status, not the divergence classifier. The node's error codes
// are named in errors/error.proto:17-109 at the pin; the text is retained intact.
fn outcome(response: &Value) -> &'static str {
    if !response["transport_error"].is_null() {
        return "undecided";
    }
    if response["error"].is_null() {
        if response["result"].is_null() {
            return "undecided";
        }
        return if response["result"]["valid"] == false {
            "invalid"
        } else {
            "valid"
        };
    }
    if let Some(code) = response["error"]["code"].as_i64() {
        if ![-25, -26, -22].contains(&code) {
            return "undecided";
        }
    }
    let s = reason(response);
    if ["TX_MISSING_PARENT", "UTXO_NOT_FOUND", "NOT_FOUND (3)"]
        .iter()
        .any(|code| s.contains(code))
    {
        return "unfundable";
    }
    match teranode_contract::innermost(&s).as_deref() {
        Some(code) if VERDICT_CODES.contains(&code) => "invalid",
        _ => "undecided",
    }
}

impl Outputs {
    fn row(
        &mut self,
        entry: &Entry,
        path: &str,
        verdict: &str,
        native: Value,
        bound: Option<Value>,
    ) -> Result<(), String> {
        let reference_key = if path == "block" {
            "sv-node@v1.2.2"
        } else {
            "sv-node-mempool@v1.2.2"
        };
        let node_key = format!("teranode-{path}@{TAG}");
        let node = ExpectJson {
            verdict: verdict.into(),
            code: None,
            reason: if verdict == "valid" {
                None
            } else {
                Some(reason(&native))
            },
            input: None,
        };
        let reference = entry.expect.get(reference_key);
        let count = self.counts.entry(path.into()).or_default();
        count.entries += 1;
        let comparison = match verdict {
            "unfundable" => {
                count.unfundable += 1;
                self.unfundable
                    .push(json!({"id": entry.id, "path": path, "reason": node.reason}));
                "not-judged"
            }
            "undecided" => {
                count.undecided += 1;
                self.undecided
                    .push(json!({"id": entry.id, "path": path, "reason": node.reason}));
                "not-judged"
            }
            _ => {
                count.judged += 1;
                match reference {
                    Some(r) if r.verdict == verdict => {
                        count.agreeing += 1;
                        "agree"
                    }
                    Some(r) if r.verdict == "valid" || r.verdict == "invalid" => {
                        count.disagreeing += 1;
                        let mut w = entry.clone();
                        w.expect.insert(node_key.clone(), node.clone());
                        w.divergence = Some(Divergence {
                            rule: entry.rule.clone(), a: reference_key.into(), b: node_key.clone(),
                            a_verdict: r.clone(), b_verdict: node.clone(),
                            decided_by: "unclassified finding; source ruling belongs to the parent".into(),
                            ruling: "open".into(), minimized: None, minimized_prevouts: None,
                            note: format!("Instance {PIN}, {path} path, same-era funded outputs; original entry id {}. Submitted bytes and node answer are attached.", entry.id),
                        });
                        let mut witness =
                            serde_json::to_value(&w).or_err("serde_json::to_value(&w)")?;
                        witness["instance_submission"] = bound.clone().unwrap_or(Value::Null);
                        witness["node_answer"] = native.clone();
                        line(&mut self.witnesses, &witness)?;
                        "disagree"
                    }
                    _ => {
                        count.no_reference += 1;
                        "no-recorded-reference"
                    }
                }
            }
        };
        line(
            &mut self.answers,
            &json!({"id": entry.id, "path": path, "reference_key": reference_key,
            "reference": reference, "node_key": node_key, "node": node, "comparison": comparison,
            "submission": bound, "node_answer": native}),
        )
    }
}

// A funding answer stops the road only when it is a transport failure, a missing
// parent (the reservoir itself) or a non-rejection RPC code; any other node answer
// is the entry's `unfundable` row, its text kept (flow-00927 at v0.16.0).
fn funding_stops_road(response: &Value) -> bool {
    !response["transport_error"].is_null()
        || outcome(response) == "unfundable"
        || response["error"]["code"]
            .as_i64()
            .is_some_and(|c| ![-25, -26, -22].contains(&c))
}

fn rejected(message: impl Into<String>) -> Value {
    json!({"transport_error": message.into()})
}

fn setup(
    road: &mut Road,
    entries: &[Entry],
    eligible: &[usize],
    base: &Path,
) -> Result<(RawTx, String), Halt> {
    let (key, script, address) = well();
    // The well lives with its chain: instance.py's INSTANCE41_DATA, else base/data.
    let data = std::env::var_os("INSTANCE41_DATA")
        .map(PathBuf::from)
        .unwrap_or_else(|| base.join("data"));
    let wallet_path = data.join("instance41-well.json");
    let wallet: Value = if wallet_path.exists() {
        serde_json::from_slice(
            &fs::read(&wallet_path)
                .map_err(|e| json!({"call": "read well state", "reason": e.to_string()}))?,
        )
        .map_err(|e| json!({"call": "parse well state", "reason": e.to_string()}))?
    } else {
        let h = road.tip()?["blocks"]
            .as_u64()
            .or_err("road.tip()?['blocks'].as_u64()")? as u32
            + 1;
        road.mine(101, &address)?;
        // The block at h by the contract's `block` (gRPC GetBlockByHeight, its coinbase's bytes).
        let block = road
            .node(|c| c.block(BlockRef::Height(h)))
            .map_err(|t| wall("block by height", t))?
            .ok_or_else(|| json!({"call": "block by height", "height": h, "reason": "the store has no block at the mined height"}))?;
        let decoded = json!({"block": block.raw});
        let tx = RawTx::decode(
            &hex::decode(
                block
                    .coinbase_tx
                    .as_deref()
                    .or_err("the block's coinbase_tx")?,
            )
            .or_err("the coinbase transaction hex")?,
        )
        .map_err(|e| json!({"call": "decode coinbase transaction", "reason": e}))?;
        let (vout, out) = tx.outputs.iter().enumerate().find(|(_, o)| o.script == script)
            .ok_or_else(|| json!({"call": "generatetoaddress", "reason": "the node's coinbase does not pay the requested well", "coinbase": decoded}))?;
        json!({"txid": txid_display_hex(&tx.txid_internal()), "vout": vout, "satoshis": out.satoshis,
               "script": hex::encode(&script), "created_height": h, "instance_commit": PIN})
    };
    let mut pool = Vec::new();
    let mut total = 100_000u64; // reservoir fee, below the RPC's absurd-fee ceiling
    for i in eligible {
        let value = entries[*i].prevouts.iter().try_fold(0u64, |s, p| s.checked_add(p.satoshis))
            .and_then(|v| v.checked_mul(2)).and_then(|v| v.checked_add(2000))
            .ok_or_else(|| json!({"call": "build reservoir", "id": entries[*i].id, "reason": "value overflow"}))?;
        total = total
            .checked_add(value)
            .ok_or_else(|| json!({"call": "build reservoir", "reason": "total value overflow"}))?;
        pool.push(RawOutput {
            satoshis: value,
            script: script.clone(),
        });
    }
    let available = wallet["satoshis"]
        .as_u64()
        .or_err("wallet['satoshis'].as_u64()")?;
    if total > available {
        return Err(Halt::Wall(
            json!({"call": "build reservoir", "reason": "the mined well cannot fund these values", "required": total, "node_coinbase_or_change": wallet}),
        ));
    }
    pool.push(RawOutput {
        satoshis: available - total,
        script: script.clone(),
    });
    let input = (
        txid_from_display_hex(wallet["txid"].as_str().or_err("wallet['txid'].as_str()")?)
            .or_err("the well state's txid")?,
        wallet["vout"].as_u64().or_err("wallet['vout'].as_u64()")? as u32,
        available,
    );
    let tx = try_p2pkh_spend(&[input], pool, &key, &script)?;
    let hex_tx = hex::encode(tx.encode());
    let reservoir = road
        .node(|c| c.submit(&tx.encode(), SubmitRoad::Rpc))
        .map_err(|t| wall("sendrawtransaction", t))?;
    if reservoir.verdict.is_err() {
        return Err(Halt::Wall(
            json!({"call": "sendrawtransaction", "params": [hex_tx], "answer": reservoir.answer,
                   "source": "[SRC] services/rpc/handlers.go:830-935 at the instance pin; reservoir submission"}),
        ));
    }
    road.mine_pending(1, &address)?;
    let height = road.tip()?["blocks"]
        .as_u64()
        .or_err("road.tip()?['blocks'].as_u64()")? as u32;
    road.confirm(&tx, height)?;
    fs::write(wallet_path, serde_json::to_vec_pretty(&json!({"txid": txid_display_hex(&tx.txid_internal()),
        "vout": eligible.len(), "satoshis": available - total, "script": hex::encode(&script), "instance_commit": PIN})).or_err("the well state as JSON")?)
        .map_err(|e| json!({"call": "write well state", "reason": e.to_string()}))?;
    Ok((tx, address))
}

fn run() -> Result<(), String> {
    let start = Instant::now();
    let args: Vec<String> = std::env::args().collect();
    if args.iter().any(|a| a == "--help") {
        println!(
            "run_teranode --corpus DIR --out NEW-DIR [--manifest NAME] [--from N] [--limit N] [--plan-only] [--witness OUT.json]"
        );
        return Ok(());
    }
    let dir = PathBuf::from(arg(&args, "--corpus").unwrap_or_else(|| "../corpus/seed".into()));
    let mname = arg(&args, "--manifest").unwrap_or_else(|| "manifest.json".into());
    let manifest: Manifest =
        serde_json::from_slice(&fs::read(dir.join(mname)).map_err(|e| e.to_string())?)
            .map_err(|e| e.to_string())?;
    let input = dir.join(&manifest.file);
    if sha_file(&input)? != manifest.sha256 {
        return Err("corpus sha256 differs from its manifest".into());
    }
    let bytes = fs::read(&input).map_err(|e| e.to_string())?;
    let all: Vec<Entry> = BufReader::new(&bytes[..])
        .lines()
        .filter_map(|l| match l {
            Ok(l) if l.trim().is_empty() => None,
            Ok(l) => Some(serde_json::from_str::<Entry>(&l).or_err("entry JSON")),
            Err(err) => Some(Err(format!("corpus line: {err}"))),
        })
        .collect::<Result<_, _>>()?;
    if all.len() as u64 != manifest.count {
        return Err("corpus count differs from its manifest".into());
    }
    let limit: usize = arg(&args, "--limit")
        .map(|s| s.parse().or_err("--limit"))
        .transpose()?
        .unwrap_or(usize::MAX);
    // --from skips that many corpus lines, so a long run goes in chunks that each
    // fit one sitting's foreground command; each chunk is its own run directory.
    let from: usize = arg(&args, "--from")
        .map(|s| s.parse().or_err("--from"))
        .transpose()?
        .unwrap_or(0);
    let entries: Vec<Entry> = all.into_iter().skip(from).take(limit).collect();
    if entries.is_empty() {
        return Err("empty run".into());
    }
    let mut excluded = BTreeMap::new();
    let mut eligible = Vec::new();
    for (i, e) in entries.iter().enumerate() {
        e.check()?;
        let tx = RawTx::decode(&hex::decode(&e.tx).or_err("hex::decode(&e.tx)")?)?;
        if let Some(reason) = exclusion(e, &tx)? {
            excluded.insert(i, reason);
        } else {
            eligible.push(i);
        }
    }
    eligible.sort_by_key(|i| era(entries[*i].params.spend_height));
    let mapping = json!({"basis": "tracker comment 5853443740; go-chaincfg v1.6.2 params.go:276-277 (mainnet), 463,475-476 (regtest)",
        "mainnet": {"genesis": 620538, "chronicle": 943816}, "regtest": {"genesis": REGTEST_GENESIS, "chronicle": REGTEST_CHRONICLE, "coinbase_maturity": 100},
        "funding_targets": {"pre-genesis": "none: no coinbase output matures below height 100; undecided", "post-genesis": "next available height, 100 through 198", "post-chronicle": "200 or a later tip of the same era"},
        "spend_height": "confirmed funding height + 1; actual chain tip + 1",
        "outpoints": "rebound, locking scripts and values preserved; signature and absolute-height/time rows excluded"});
    if args.iter().any(|a| a == "--plan-only") {
        println!(
            "{}",
            json!({"corpus": manifest.corpus, "entries": entries.len(), "eligible": eligible.len(),
            "undecided": excluded.iter().map(|(i, r)| json!({"id": entries[*i].id, "reason": r})).collect::<Vec<_>>(), "mapping": mapping})
        );
        return Ok(());
    }
    let out_dir = PathBuf::from(arg(&args, "--out").ok_or("--out is required")?);
    if let Some(parent) = out_dir.parent() {
        fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    fs::create_dir(&out_dir).map_err(|e| format!("create fresh output directory: {e}"))?;
    let home = PathBuf::from(std::env::var("HOME").map_err(|e| e.to_string())?);
    let base = home.join("bsv/targets/spec-teranode");
    let engine = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("engines/instance41");
    let mut road = Road {
        node: Instance41::new(&out_dir.join("rpc.cookie"))?,
        recipe: Worker::new(Command::new("python3").arg(engine.join("road.py")))?,
        calls: 0,
        journal: BufWriter::new(
            File::create(out_dir.join("rpc.jsonl")).map_err(|e| e.to_string())?,
        ),
    };
    if let Some(out) = arg(&args, "--witness") {
        return witnesses(&mut road, &PathBuf::from(out));
    }
    let attestation = road.recipe("attest");
    if has_error(&attestation) {
        return Err(format!("attestation: {}", reason(&attestation)));
    }
    let mut identity = attestation["result"].clone();
    identity["native_client_sha256"] = json!(sha_file(road.node.native_path())?);
    let mut outputs = Outputs {
        answers: BufWriter::new(
            File::create(out_dir.join("answers.jsonl"))
                .or_err("File::create(out_dir.join('answers.jsonl'))")?,
        ),
        funding: BufWriter::new(
            File::create(out_dir.join("funding.jsonl"))
                .or_err("File::create(out_dir.join('funding.jsonl'))")?,
        ),
        witnesses: BufWriter::new(
            File::create(out_dir.join("witnesses.jsonl"))
                .or_err("File::create(out_dir.join('witnesses.jsonl'))")?,
        ),
        counts: PATHS
            .iter()
            .map(|p| (p.to_string(), Counts::default()))
            .collect(),
        undecided: vec![],
        unfundable: vec![],
    };
    let mut finished = vec![false; entries.len()];
    for (i, why) in excluded {
        for path in PATHS {
            outputs.row(&entries[i], path, "undecided", rejected(&why), None)?;
        }
        finished[i] = true;
    }
    let initial_tip = road.tip().map_err(|w| w.to_string())?;
    let chain = road.node(|c| c.chain()).map_err(String::from)?;
    if chain != "regtest" {
        return Err(format!("instance is not regtest: {chain}"));
    }
    let mut wall = None;
    if !eligible.is_empty() {
        match setup(&mut road, &entries, &eligible, &base) {
            Err(h) => wall = Some(h.wall()?),
            Ok((pool, address)) => {
                let (key, script, _) = well();
                let mut cursor = 0;
                while cursor < eligible.len() && wall.is_none() {
                    let era_id = era(entries[eligible[cursor]].params.spend_height);
                    let end = eligible[cursor..]
                        .iter()
                        .position(|i| era(entries[*i].params.spend_height) != era_id)
                        .map(|n| cursor + n)
                        .unwrap_or(eligible.len());
                    let Some((lo, hi)) = range(era_id) else {
                        for i in &eligible[cursor..end] {
                            for path in PATHS {
                                outputs.row(&entries[*i], path, "undecided", rejected(format!("era {era_id}: no coinbase output matures below regtest Genesis height {REGTEST_GENESIS} (go-chaincfg v1.6.2 params.go:463,475)")), None)?;
                            }
                            finished[*i] = true;
                        }
                        cursor = end;
                        continue;
                    };
                    let tip = match road.tip() {
                        Ok(t) => t,
                        Err(w) => {
                            wall = Some(w);
                            break;
                        }
                    };
                    let fund_height =
                        lo.max(tip["blocks"].as_u64().or_err("tip['blocks'].as_u64()")? as u32 + 1);
                    if fund_height >= hi {
                        for i in &eligible[cursor..end] {
                            for path in PATHS {
                                outputs.row(&entries[*i], path, "undecided", rejected(format!("current chain cannot place funding and spend in era {era_id} at or below height {hi}")), None)?;
                            }
                            finished[*i] = true;
                        }
                        cursor = end;
                        continue;
                    }
                    if let Err(h) = road.bake(fund_height - 1, &address) {
                        wall = Some(h.wall()?);
                        break;
                    }
                    let mut funded = Vec::new();
                    for (offset, i) in eligible[cursor..end].iter().enumerate() {
                        let pool_vout = cursor + offset;
                        let e = &entries[*i];
                        let (_, distinct) = outpoint_slots(e);
                        let locks: Vec<RawOutput> = distinct
                            .iter()
                            .map(|k| -> Result<RawOutput, String> {
                                Ok(RawOutput {
                                    satoshis: e.prevouts[*k].satoshis,
                                    script: hex::decode(&e.prevouts[*k].script)
                                        .or_err("a prevout script")?,
                                })
                            })
                            .collect::<Result<_, _>>()?;
                        let funding = try_p2pkh_spend(
                            &[(
                                pool.txid_internal(),
                                pool_vout as u32,
                                pool.outputs[pool_vout].satoshis,
                            )],
                            locks.iter().chain(locks.iter()).cloned().collect(),
                            &key,
                            &script,
                        )?;
                        let response = envelope(
                            road.node(|c| c.submit(&funding.encode(), SubmitRoad::Rpc))
                                .map(|s| s.answer),
                        );
                        line(
                            &mut outputs.funding,
                            &json!({"id": e.id, "tx": hex::encode(funding.encode()), "planned_height": fund_height, "node_answer": response}),
                        )?;
                        if has_error(&response) {
                            // A transport failure, or a missing parent (the reservoir
                            // itself), stops the road. Any other answer of the node,
                            // an engine fault included, is the node declining to carry
                            // this entry's prevouts: `unfundable`, its text kept, the
                            // road going on (flow-00927 at v0.16.0: OP_1 OP_ENDIF).
                            if funding_stops_road(&response) {
                                wall = Some(
                                    json!({"call": "sendrawtransaction", "stage": "funding", "id": e.id, "tx": hex::encode(funding.encode()),
                                    "answer": response, "source": "[SRC] services/rpc/handlers.go:880-935; services/validator/Validator.go:1002,1584-1609 at the instance pin"}),
                                );
                                break;
                            }
                            for path in PATHS {
                                outputs.row(e, path, "unfundable", response.clone(), None)?;
                            }
                            finished[*i] = true;
                        } else {
                            funded.push((*i, funding));
                        }
                        if (offset + 1) % 1000 == 0 {
                            println!(
                                "run_teranode: funding {}/{}, era {era_id}",
                                offset + 1,
                                end - cursor
                            );
                        }
                    }
                    if wall.is_some() {
                        break;
                    }
                    if !funded.is_empty() {
                        if let Err(w) = road.mine_pending(funded.len() as u64, &address) {
                            wall = Some(w);
                            break;
                        }
                        let tip = match road.tip() {
                            Ok(t) => t,
                            Err(w) => {
                                wall = Some(w);
                                break;
                            }
                        };
                        let candidate =
                            tip["blocks"].as_u64().or_err("tip['blocks'].as_u64()")? as u32 + 1;
                        if candidate != fund_height + 1 {
                            wall = Some(
                                json!({"call": "confirm funding", "planned_height": fund_height, "actual_tip": tip}),
                            );
                            break;
                        }
                        let mtp = tip["mediantime"]
                            .as_u64()
                            .or_err("tip['mediantime'].as_u64()")?
                            as u32;
                        let candidate_time = mtp.saturating_add(1);
                        'submissions: for (offset, (i, funding)) in funded.iter().enumerate() {
                            let headroom = road.recipe("headroom");
                            if has_error(&headroom) {
                                wall = Some(json!({"call": "headroom", "answer": headroom}));
                                break;
                            }
                            let e = &entries[*i];
                            let confirmation = match road.confirm(funding, fund_height) {
                                Ok(meta) => meta,
                                Err(w) => {
                                    wall = Some(w);
                                    break;
                                }
                            };
                            for (path_index, path) in PATHS.iter().enumerate() {
                                let mut tx = RawTx::decode(
                                    &hex::decode(&e.tx).or_err("hex::decode(&e.tx)")?,
                                )?;
                                let mut prevouts: Vec<PrevoutJson> = e.prevouts.clone();
                                let (slots, distinct) = outpoint_slots(e);
                                for (k, input) in tx.inputs.iter_mut().enumerate() {
                                    // A null outpoint stays as the entry has it; equal
                                    // outpoints stay equal (one funded output each).
                                    let Some(slot) = slots[k] else { continue };
                                    input.txid = funding.txid_internal();
                                    input.vout = (path_index * distinct.len() + slot) as u32;
                                    prevouts[k].txid = txid_display_hex(&input.txid);
                                    prevouts[k].vout = input.vout;
                                    prevouts[k].height = fund_height;
                                }
                                let bound = json!({"tx": hex::encode(tx.encode()), "prevouts": prevouts, "spend_height": candidate,
                                    "funding_txid": txid_display_hex(&funding.txid_internal()), "funding_height": fund_height,
                                    "original_tx": e.tx, "original_spend_height": e.params.spend_height,
                                    "era": e.params.era, "candidate_parent_median_time": mtp, "candidate_block_time": candidate_time,
                                    "funding_metadata": confirmation});
                                let raw = tx.encode();
                                let submit_road = if *path == "block" {
                                    SubmitRoad::ValidatorBlockContext {
                                        height: candidate,
                                        time: candidate_time,
                                        mtp,
                                    }
                                } else {
                                    SubmitRoad::Rpc
                                };
                                let response = envelope(
                                    road.node(|c| c.submit(&raw, submit_road)).map(|s| s.answer),
                                );
                                let transport_failure = !response["transport_error"].is_null();
                                outputs.row(
                                    e,
                                    path,
                                    outcome(&response),
                                    response.clone(),
                                    Some(bound),
                                )?;
                                if transport_failure {
                                    if *path == "block" {
                                        outputs.row(e, "mempool", "undecided", rejected("submission road stopped after a block-context transport failure"), None)?;
                                    }
                                    finished[*i] = true;
                                    wall =
                                        Some(json!({"call": path, "id": e.id, "answer": response}));
                                    break 'submissions;
                                }
                            }
                            finished[*i] = true;
                            if (offset + 1) % 1000 == 0 {
                                println!(
                                    "run_teranode: judged {}/{}, era {era_id}",
                                    offset + 1,
                                    funded.len()
                                );
                            }
                        }
                        // Mine accepted submissions. An RPC mining answer is recorded
                        // separately; it never replaces a block-context rejection.
                        if wall.is_some() {
                            break;
                        }
                        if let Err(w) = road.mine(1, &address) {
                            wall = Some(w);
                            break;
                        }
                    }
                    cursor = end;
                }
            }
        }
    }
    for (i, done) in finished.iter().enumerate() {
        if !done {
            let w = wall.as_ref().unwrap_or(&Value::Null);
            let why = w["reason"]
                .as_str()
                .map(str::to_string)
                .unwrap_or_else(|| reason(&w["answer"]));
            for path in PATHS {
                outputs.row(
                    &entries[i],
                    path,
                    "undecided",
                    rejected(format!(
                        "funding road stopped at {}: {why}; see manifest funding_wall",
                        w["call"]
                    )),
                    None,
                )?;
            }
        }
    }
    let final_tip = road.tip().unwrap_or_else(|w| json!({"unavailable": w}));
    outputs.answers.flush().map_err(|e| e.to_string())?;
    outputs.funding.flush().map_err(|e| e.to_string())?;
    outputs.witnesses.flush().map_err(|e| e.to_string())?;
    road.journal.flush().map_err(|e| e.to_string())?;
    let mut artifacts = BTreeMap::new();
    for name in [
        "answers.jsonl",
        "funding.jsonl",
        "witnesses.jsonl",
        "rpc.jsonl",
    ] {
        artifacts.insert(name, sha_file(&out_dir.join(name))?);
    }
    let header = json!({"instance": identity, "corpus": {"name": manifest.corpus, "path": input, "sha256": manifest.sha256,
        "manifest_count": manifest.count, "run_from": from, "run_count": entries.len()}, "mapping": mapping,
        "paths": {"block": "node ValidatorAPI.ValidateTransaction, SkipPolicyChecks=true, InBlock=true, parents read from its store; full block-wrapper acceptance is not inferred",
                  "mempool": "node sendrawtransaction under its recorded test settings"},
        "initial_tip": initial_tip, "final_tip": final_tip, "counts": outputs.counts,
        "undecided": outputs.undecided, "unfundable": outputs.unfundable,
        "artifacts_sha256": artifacts, "rpc_calls": road.calls, "wall_seconds": start.elapsed().as_secs_f64(), "funding_wall": wall,
        "provenance": "synthetic seed corpus; node at the tagged pin on the local private chain; witnesses are unclassified findings"});
    fs::write(
        out_dir.join("manifest.json"),
        serde_json::to_string_pretty(&header).or_err("serde_json::to_string_pretty(&header)")?
            + "\n",
    )
    .map_err(|e| e.to_string())?;
    println!(
        "run_teranode: {} entries, counts {}; {:.3}s; manifest {} sha256 {}",
        entries.len(),
        header["counts"],
        start.elapsed().as_secs_f64(),
        out_dir.join("manifest.json").display(),
        sha_file(&out_dir.join("manifest.json"))?
    );
    if !header["funding_wall"].is_null() {
        return Err(format!("funding wall: {}", header["funding_wall"]));
    }
    Ok(())
}

// One spend of `funding`'s output `vout` (locked by OP_1 OP_EQUAL) with `unlock`, paying the well.
fn probe_spend(funding: &RawTx, vout: u32, unlock: &[u8], pay: &[u8]) -> RawTx {
    RawTx {
        version: 1,
        inputs: vec![bsv_script_harness::txraw::RawInput {
            txid: funding.txid_internal(),
            vout,
            script: unlock.to_vec(),
            sequence: u32::MAX,
        }],
        outputs: vec![RawOutput {
            satoshis: 9_000,
            script: pay.to_vec(),
        }],
        lock_time: 0,
    }
}

// The settings rows whose key names a Kafka topic setting of the rejection topics (F9), from the
// `/settings` answer's `settings` list of `{key, currentValue, defaultValue, ...}` rows
// ([SRC] services/asset/httpimpl/settings_handler.go:57 at the pin); the whole answer stays in the run directory.
fn kafka_settings(v: &Value) -> Value {
    let rows = v["settings"].as_array().cloned().unwrap_or_default();
    Value::Array(
        rows.into_iter()
            .filter(|r| {
                let k = r["key"].as_str().unwrap_or("").to_ascii_lowercase();
                k.contains("kafka") && k.contains("rejected")
            })
            .map(|r| json!({"key": r["key"], "currentValue": r["currentValue"], "defaultValue": r["defaultValue"], "category": r["category"]}))
            .collect(),
    )
}

/// The witness runs of the contract's findings (docs/CONFORMANCE-TERANODE-OBSERVATION.md section 7) on
/// the running instance, every read through the contract; the receipts go to `out`, the journal to the
/// run's rpc.jsonl. F2 and F8 need a broker and F10 a repeated id: none of them runs here.
fn witnesses(road: &mut Road, out: &Path) -> Result<(), String> {
    let start = Instant::now();
    let attestation = road.recipe("attest");
    if has_error(&attestation) {
        return Err(format!("attestation: {}", reason(&attestation)));
    }
    let chain = road.node(|c| c.chain())?;
    if chain != "regtest" {
        return Err(format!("instance is not regtest: {chain}"));
    }
    let fsm = road.node(|c| c.fsm())?;
    let (key, script, address) = well();
    let t0 = road.node(|c| c.tip())?;
    road.node(|c| c.mine(101, &address))?;
    let tip = road.node(|c| c.tip())?;
    // F1: the two rpcs whose server methods carry a Request suffix.
    let f1 = road.node(|c| c.witness_unimplemented(&tip.hash))?;
    // The funding: block t0+1's coinbase (mature at t0+101) into six OP_1 OP_EQUAL outputs.
    let b = road
        .node(|c| c.block(BlockRef::Height(t0.height + 1)))?
        .ok_or("no block above the start tip")?;
    let coinbase = RawTx::decode(
        &hex::decode(b.coinbase_tx.as_deref().unwrap_or("")).or_err("the coinbase hex")?,
    )?;
    let (vout, value) = coinbase
        .outputs
        .iter()
        .enumerate()
        .find(|(_, o)| o.script == script)
        .map(|(i, o)| (i as u32, o.satoshis))
        .ok_or("the coinbase does not pay the well")?;
    let lock = vec![0x51, 0x87];
    let mut outs: Vec<RawOutput> = (0..6)
        .map(|_| RawOutput {
            satoshis: 10_000,
            script: lock.clone(),
        })
        .collect();
    outs.push(RawOutput {
        satoshis: value - 60_000 - 100_000,
        script: script.clone(),
    });
    let funding = try_p2pkh_spend(
        &[(coinbase.txid_internal(), vout, value)],
        outs,
        &key,
        &script,
    )?;
    let funded = road.node(|c| c.submit(&funding.encode(), SubmitRoad::Rpc))?;
    if funded.verdict.is_err() {
        return Err(format!("funding refused: {}", funded.answer));
    }
    road.mine_pending(1, &address).map_err(|w| w.to_string())?;
    let tip = road.node(|c| c.tip())?;
    road.confirm(&funding, tip.height)
        .map_err(|w| w.to_string())?;
    let ctx = SubmitRoad::ValidatorBlockContext {
        height: tip.height + 1,
        time: tip.tip_mtp.saturating_add(1),
        mtp: tip.tip_mtp,
    };
    // F3: the validator road's refusal (OP_2 against OP_1 OP_EQUAL) and its acceptance (OP_1).
    let f3_refused = probe_spend(&funding, 0, &[0x52], &script);
    let f3_accepted = probe_spend(&funding, 1, &[0x51], &script);
    let f3 = json!({
        "refusal": {"tx": hex::encode(f3_refused.encode()), "answer": road.node(|c| c.submit(&f3_refused.encode(), ctx))?.answer},
        "acceptance": {"tx": hex::encode(f3_accepted.encode()), "answer": road.node(|c| c.submit(&f3_accepted.encode(), ctx))?.answer},
    });
    // F4: the RPC road's codes: a script refusal, a missing input, and the reference's own refused
    // bytes of docs/records/20261013-024612-s6-66-regtest-s3.json (-26 "16: bad-txns-vin-empty" there).
    let f4_script = probe_spend(&funding, 2, &[0x52], &script);
    let mut missing = probe_spend(&funding, 2, &[0x51], &script);
    missing.inputs[0].txid = [0x11; 32];
    let vin_empty =
        hex::decode("0200000000018403000000000000015100000000").or_err("the reference's bytes")?;
    let mut f4 = vec![];
    for (name, raw) in [
        ("script refusal", f4_script.encode()),
        ("missing input", missing.encode()),
        ("the reference's vin-empty bytes", vin_empty),
    ] {
        let s = road.node(|c| c.submit(&raw, SubmitRoad::Rpc))?;
        f4.push(json!({"case": name, "tx": hex::encode(&raw), "answer": s.answer,
            "rpc_code": s.verdict.as_ref().err().and_then(|r| r.rpc_code), "innermost": s.verdict.as_ref().err().and_then(|r| r.innermost.clone())}));
    }
    // F7: an accepted RPC submission in block assembly, then the verbose getrawmempool.
    let f7_tx = probe_spend(&funding, 3, &[0x51], &script);
    let f7_id = txid_display_hex(&f7_tx.txid_internal());
    let f7_submit = road
        .node(|c| c.submit(&f7_tx.encode(), SubmitRoad::Rpc))?
        .answer;
    let mut listed = false;
    for _ in 0..40 {
        if road.node(|c| c.assembly_contents())?.contains(&f7_id) {
            listed = true;
            break;
        }
        std::thread::sleep(Duration::from_millis(250));
    }
    let f7 = json!({"tx": hex::encode(f7_tx.encode()), "txid": f7_id, "submit": f7_submit, "listed_by_assembly": listed,
        "verbose": road.node(|c| c.witness_verbose_pool())?});
    let funding_id = txid_display_hex(&funding.txid_internal());
    // F9: the settings, with the tag's test credentials; the whole answer stays in the run directory.
    let f9 = match road.node(|c| c.witness_asset("settings", true)) {
        Ok((status, body)) => {
            fs::write(
                out.with_extension("settings.json"),
                serde_json::to_vec_pretty(&body).or_err("the settings answer")?,
            )
            .map_err(|e| e.to_string())?;
            json!({"http": status, "kafka_settings": kafka_settings(&body),
                   "full_answer": out.with_extension("settings.json").display().to_string()})
        }
        Err(t) => json!({"transport_error": t.to_string()}),
    };
    // F5 and F11: block A (with F7's transaction), A invalidated, block B at the same height, A reconsidered;
    // at each step the tip, the tips, and F7's txmeta mainChainIndex against per-block membership.
    let pending = road.node(|c| c.assembly_contents())?.len() as u64;
    road.mine_pending(pending.max(1), &address)
        .map_err(|w| w.to_string())?;
    let a = road.node(|c| c.tip())?;
    let mut steps = vec![];
    let mut observe = |road: &mut Road, step: &str| -> Result<(), String> {
        let tip = road.node(|c| c.tip())?;
        let tips = road.node(|c| c.chain_tips())?;
        let record = road.node(|c| c.tx_record(&f7_id))?;
        let mut membership = vec![];
        if let Some(r) = &record {
            for h in &r.block_hashes {
                if let Some(b) = road.node(|c| c.block(BlockRef::Hash(h.clone())))? {
                    let on = road.node(|c| c.on_active(&[b.id]))?;
                    membership.push(json!({"hash": h, "id": b.id, "height": b.height, "invalid": b.invalid, "on_active": on}));
                }
            }
        }
        steps.push(json!({"step": step, "at_ms": start.elapsed().as_millis() as u64,
            "tip": {"hash": tip.hash, "height": tip.height, "chain_work": tip.chain_work},
            "chain_tips": tips.iter().map(|t| json!({"hash": t.hash, "height": t.height, "branchlen": t.branchlen, "status": t.status})).collect::<Vec<_>>(),
            "f7_txmeta": record.map(|r| json!({"blockIDs": r.block_ids, "blockHashes": r.block_hashes, "blockHeights": r.block_heights, "mainChainIndex": r.main_chain_index})),
            "f7_membership": membership}));
        Ok(())
    };
    observe(road, "A mined")?;
    let invalidated = road.node(|c| c.invalidate(&a.hash))?;
    observe(road, "A invalidated, read at once")?;
    std::thread::sleep(Duration::from_secs(2));
    observe(road, "A invalidated, read after 2 s")?;
    let pending = road.node(|c| c.assembly_contents())?.len() as u64;
    let mine_b = match road.mine_pending(pending, &address) {
        Ok(()) => json!({"hash": road.node(|c| c.tip())?.hash, "error": null}),
        Err(w) => json!({"hash": null, "error": w.to_string()}),
    };
    observe(road, "B mined")?;
    let reconsidered = road.node(|c| c.reconsider(&a.hash))?;
    observe(road, "A reconsidered, read at once")?;
    std::thread::sleep(Duration::from_secs(2));
    observe(road, "A reconsidered, read after 2 s")?;
    let block_a = road
        .node(|c| c.block(BlockRef::Hash(a.hash.clone())))?
        .map(|b| b.raw);
    // F6, last (its answer may never come, which ends nothing else): the UTXO record's raw marks for a
    // known transaction (the funding, mined) on the SQL store, and the record the JSON route gives.
    let f6_record = road.node(|c| c.tx_record(&funding_id))?.map(|r| r.raw);
    let f6 = match road.node(|c| c.witness_asset(&format!("txmeta_raw/{funding_id}/json"), false)) {
        Ok((status, body)) => json!({"http": status, "body": body, "txmeta_json": f6_record}),
        Err(t) => {
            json!({"transport_error": t.to_string(), "read_timeout_seconds": 30, "txmeta_json": f6_record})
        }
    };
    let receipts = json!({
        "label": "[M]", "tag": TAG, "pin": PIN, "attestation": attestation["result"], "chain": chain, "fsm": fsm,
        "native_client_sha256": sha_file(road.node.native_path())?,
        "start_tip": {"hash": t0.hash, "height": t0.height},
        "funding": {"txid": funding_id, "tx": hex::encode(funding.encode())},
        "F1": f1, "F3": f3, "F4": f4, "F6": f6, "F7": f7, "F9": f9,
        "F5_F11": {"block_a": block_a, "invalidate": invalidated, "mine_b": mine_b, "reconsider": reconsidered, "steps": steps},
        "rpc_calls": road.calls, "wall_seconds": start.elapsed().as_secs_f64(),
    });
    fs::write(
        out,
        serde_json::to_string_pretty(&receipts).or_err("the receipts")? + "\n",
    )
    .map_err(|e| e.to_string())?;
    road.journal.flush().map_err(|e| e.to_string())?;
    println!(
        "run_teranode --witness: {} sha256 {}; {:.1}s",
        out.display(),
        sha_file(out)?,
        start.elapsed().as_secs_f64()
    );
    Ok(())
}

fn main() {
    if let Err(e) = run() {
        eprintln!("run_teranode: {e}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn error_envelopes_do_not_turn_operational_failures_into_verdicts() {
        assert_eq!(
            outcome(&json!({"transport_error": "timed out"})),
            "undecided"
        );
        assert_eq!(
            outcome(&json!({"result": null, "error": null})),
            "undecided"
        );
        assert_eq!(
            outcome(&json!({"error": {"message": "TX_MISSING_PARENT (34): absent"}})),
            "unfundable"
        );
        assert_eq!(
            outcome(&json!({"error": {"message": "SERVICE_ERROR (59): stopped"}})),
            "undecided"
        );
        assert_eq!(
            outcome(&json!({"error": {"code": -32603, "message": "internal RPC failure"}})),
            "undecided"
        );
        assert_eq!(
            outcome(&json!({"error": {"message": "SCRIPT_ERR_EVAL_FALSE"}})),
            "undecided"
        );
        // seed-001961, mempool path at v0.16.0: an engine exception is not a verdict.
        let thrown = json!({"error": {"code": -25, "message": "TX rejected: PROCESSING (4): [Validate][29] error validating transaction -> PROCESSING (4): GoBDK fail to ValidateTransaction -> UNKNOWN (0): Exception thrown from C++ code"}});
        assert_eq!(outcome(&thrown), "undecided");
        assert!(reason(&thrown).contains("UNKNOWN (0): Exception thrown from C++ code"));
        assert_eq!(
            outcome(
                &json!({"error": {"code": -25, "message": "TX rejected: PROCESSING (4): [Validate][29] error validating transaction -> TX_INVALID (31): GoBDK fail to ValidateTransaction -> TX_INVALID (31): Invalid OP_IF construction"}})
            ),
            "invalid"
        );
        assert_eq!(
            outcome(
                &json!({"error": {"message": "PROCESSING (4): x -> TX_INVALID (31): y -> TX_POLICY (39): z"}})
            ),
            "invalid"
        );
    }

    #[test]
    fn an_engine_exception_at_funding_is_unfundable_with_its_text() {
        // flow-00927's funding answer at v0.16.0: the road goes on, the entry is `unfundable`.
        let message = "TX rejected: PROCESSING (4): [Validate][29] error validating transaction -> PROCESSING (4): GoBDK fail to ValidateTransaction -> UNKNOWN (0): Exception thrown from C++ code";
        let thrown = json!({"error": {"code": -26, "message": message}});
        assert!(!funding_stops_road(&thrown));
        assert!(funding_stops_road(&json!({"transport_error": "timed out"})));
        assert!(funding_stops_road(
            &json!({"error": {"code": -25, "message": "TX_MISSING_PARENT (34): absent"}})
        ));
        assert!(funding_stops_road(
            &json!({"error": {"code": -32603, "message": "internal RPC failure"}})
        ));
        let dir = std::env::temp_dir().join(format!("run_teranode-test-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let file = |n: &str| BufWriter::new(File::create(dir.join(n)).unwrap());
        let mut outputs = Outputs {
            answers: file("answers.jsonl"),
            funding: file("funding.jsonl"),
            witnesses: file("witnesses.jsonl"),
            counts: BTreeMap::new(),
            undecided: vec![],
            unfundable: vec![],
        };
        let e: Entry = serde_json::from_str(r#"{"id":"flow-00927","family":"f","rule":"r","tx":"00","prevouts":[],"params":{"spend_height":700000,"era":"post-genesis","consensus":true,"tx_version":1},"expect":{"sv-node@v1.2.2":{"verdict":"invalid"}}}"#).unwrap();
        for path in PATHS {
            outputs
                .row(&e, path, "unfundable", thrown.clone(), None)
                .unwrap();
        }
        assert_eq!(outputs.unfundable.len(), PATHS.len());
        for (row, path) in outputs.unfundable.iter().zip(PATHS) {
            assert_eq!(row["path"], path);
            assert_eq!(row["reason"], message);
        }
        assert!(outputs
            .counts
            .values()
            .all(|c| c.unfundable == 1 && c.judged == 0 && c.undecided == 0));
        drop(outputs);
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn a_false_result_without_an_error_keeps_the_node_text() {
        let r = json!({"result": {"valid": false, "reason": "script failed", "txid": "00"}});
        assert_eq!(outcome(&r), "invalid");
        assert_eq!(reason(&r), "script failed");
        let bare = json!({"result": {"valid": false}});
        assert_eq!(reason(&bare), "{\"valid\":false}");
    }

    #[test]
    fn rebinding_keeps_duplicate_and_null_outpoints() {
        let line = |prevouts: &str| -> Entry {
            serde_json::from_str(&format!(r#"{{"id":"t","family":"f","rule":"r","tx":"00","prevouts":{prevouts},"params":{{"spend_height":700000,"era":"post-genesis","consensus":true,"tx_version":1}},"expect":{{}}}}"#)).unwrap()
        };
        let a = "ab".repeat(32);
        let z = "00".repeat(32);
        let p = |t: &str, v: u32| {
            format!(r#"{{"txid":"{t}","vout":{v},"script":"51","satoshis":1,"height":700000}}"#)
        };
        let dup = line(&format!("[{},{}]", p(&a, 0), p(&a, 0)));
        assert_eq!(outpoint_slots(&dup), (vec![Some(0), Some(0)], vec![0]));
        let null = line(&format!("[{},{}]", p(&a, 0), p(&z, u32::MAX)));
        assert_eq!(outpoint_slots(&null), (vec![Some(0), None], vec![0]));
    }

    #[test]
    fn pushed_opcode_bytes_do_not_exclude_independent_witnesses() {
        assert!(!contains_opcode(&[2, 0xac, 0xb1, 0x51], &[0xac, 0xb1]));
        assert!(contains_opcode(&[1, 0xac, 0xb1], &[0xb1]));
        assert!(!contains_opcode(&[0x4c, 3, 0xac], &[0xac]));
    }

    #[test]
    fn era_ranges_leave_the_spend_in_the_same_era() {
        assert_eq!(
            [era(620537), era(620538), era(943815), era(943816)],
            [0, 1, 1, 2]
        );
        assert_eq!(range(0), None);
        assert_eq!(range(1), Some((100, 199)));
        assert_eq!(range(2).unwrap().0, 200);
    }
}
