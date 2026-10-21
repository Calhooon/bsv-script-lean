//! The observation contract of #97 as Rust (S4b, lane trait-97, [D] 2026-10-15): the trait of
//! docs/CONFORMANCE-TERANODE-OBSERVATION.md section 6, its one implementation over the surfaces that
//! page cites, and the writes of a scenario step beside it. The Teranode runner
//! (`harness/src/bin/run_teranode.rs`) and the scenario client (`harness/engines/teranode/client.rs`)
//! read the node through this file and nothing else: the JSON-RPC, the asset HTTP and the gRPC
//! transport (`harness/engines/instance41/native/main.go`, a JSON-lines child) are private here.
//! Every call is journaled with its surface and its handler at Teranode v0.16.0
//! (`4edb60a40c6628ff0ef60231c2628efd7103fde5`) [SRC]; every answer keeps the node's own object.
//! **The second oracle's defaults are never the rule** (DESIGN-S6 section 5.2).

use crate::rpc::Rpc;
use serde_json::{json, Value};
use std::collections::{BTreeMap, BTreeSet};
use std::fmt;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::TcpStream;
use std::path::{Path, PathBuf};
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};
use std::time::Duration;

pub const TAG: &str = "v0.16.0";
pub const PIN: &str = "4edb60a40c6628ff0ef60231c2628efd7103fde5";
// [SRC] settings.conf:138,1273-1280 at PIN: the RPC listener (TERANODE_RPC_PORT 9292) and its test credentials.
// pub since lane cut2-66q2 (#66 cut 2, the stacked landing land-w2l): a second connection submits #90's concurrent pair.
pub const RPC_URL: &str = "http://127.0.0.1:9292";
// [SRC] settings.conf:90 at PIN (ASSET_HTTP_PORT 8090); services/asset/httpimpl/http.go:323 (apiPrefix /api/v1).
const ASSET: (&str, u16) = ("127.0.0.1", 8090);
/// Block assembly's subtree starts with the coinbase placeholder node, which getrawmempool lists with
/// the transactions ([M] 2026-10-14 21:26Z: an empty instance answers [ff..ff]);
/// [SRC] services/blockassembly/subtreeprocessor/SubtreeProcessor.go:1416,1559-1565 at PIN.
pub const PLACEHOLDER: &str = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";

/// A read that did not reach the node, or whose answer was not the surface's shape.
#[derive(Clone, Debug)]
pub struct Transport {
    pub surface: &'static str,
    pub message: String,
}

impl fmt::Display for Transport {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.surface, self.message)
    }
}

impl From<Transport> for String {
    fn from(t: Transport) -> String {
        t.to_string()
    }
}

fn transport(surface: &'static str, message: impl Into<String>) -> Transport {
    Transport {
        surface,
        message: message.into(),
    }
}

/// The road of a submission (section 6): the RPC's mempool road, or the validator's block context.
#[derive(Clone, Copy, Debug)]
pub enum SubmitRoad {
    Rpc,
    ValidatorBlockContext { height: u32, time: u32, mtp: u32 },
}

/// The refusal keeps the node's text and its innermost code (errors/error.proto:17-109 at PIN); the RPC
/// code is kept apart from the node code, as DESIGN-S6 section 3's RejectCode keeps `rpc` apart from `node`.
#[derive(Clone, Debug, PartialEq)]
pub struct Refusal {
    pub rpc_code: Option<i64>,
    pub innermost: Option<String>,
    pub text: String,
}

/// A submission's verdict and the node's whole envelope (`{"result":..}` or `{"error":..}`), as received.
#[derive(Clone, Debug)]
pub struct Submitted {
    pub verdict: Result<String, Refusal>,
    pub answer: Value,
}

/// The tip. `median_time_past` is the header's own field, the median of the 11 blocks before it
/// ([SRC] stores/blockchain/sql/StoreBlock.go:739-740,1133-1160 at PIN); `tip_mtp` is the median of the
/// tip's last 11 timestamps, the tip included (GetBestHeightAndTime, services/blockchain/Server.go:3210-3240),
/// the parent median time of a candidate block and the RPC's `mediantime` (services/rpc/handlers.go:1590-1622).
#[derive(Clone, Debug)]
pub struct Tip {
    pub hash: String,
    pub height: u32,
    pub chain_work: String,
    pub median_time_past: u32,
    pub time: u32,
    pub tip_mtp: u32,
    pub raw: Value,
}

#[derive(Clone, Debug, PartialEq)]
pub struct ChainTip {
    pub height: u32,
    pub hash: String,
    pub branchlen: u32,
    pub status: String,
}

#[derive(Clone, Debug)]
pub enum BlockRef {
    Hash(String),
    Height(u32),
    Id(u32),
}

/// A block of the header tree. By hash the answer is GetBlockHeader's (the store id, the invalid and
/// mined marks, no body); by height or id it is GetBlock*'s (the coinbase and the subtree hashes).
#[derive(Clone, Debug)]
pub struct BlockSummary {
    pub hash: String,
    pub height: u32,
    pub id: u32,
    pub merkle_root: String,
    pub time: u32,
    pub invalid: Option<bool>,
    pub mined_set: Option<bool>,
    pub coinbase_tx: Option<String>,
    pub subtrees: Vec<String>,
    pub raw: Value,
}

/// The UTXO store's record of a transaction through `/txmeta/:hash/json` (GetTransactionMeta.go:214-228).
#[derive(Clone, Debug)]
pub struct TxRecord {
    pub block_ids: Vec<u32>,
    pub block_hashes: Vec<String>,
    pub block_heights: Vec<u32>,
    pub main_chain_index: Option<i64>,
    pub raw: Value,
}

/// An outpoint's spend through `/utxo/:hash?vout=n` (stores/utxo/spendresponse.go:13-22, status.proto:8-25).
#[derive(Clone, Debug)]
pub struct SpendState {
    pub status: String,
    pub spender: Option<String>,
    pub raw: Value,
}

/// A rejection after the fact: the `rejectedtx` topic's message (kafka_messages.proto:46-50).
#[derive(Clone, Debug)]
pub struct RejectedTx {
    pub tx_hash: String,
    pub reason: String,
}

/// DESIGN-S6 section 3 as Teranode can answer it (the page's section 4).
#[derive(Clone, Debug, PartialEq)]
pub enum TeranodeStatus {
    Unknown,
    MinedActive {
        height: u32,
    },
    OnStaleBranch,
    ConflictedByMinedSpend {
        spender: String,
    },
    /// Clause 2's nearest: in block assembly's set, or a record with no block; the conflict marks unread (F6).
    KnownUnmined,
    Rejected(Refusal),
    /// Clauses 3 and 4: no Teranode surface (section 4).
    Absent(&'static str),
}

/// The harness's own journal the status function reads besides the node: the refusals it received,
/// the blocks each watched transaction was seen in, and each one's spent outpoints.
#[derive(Clone, Debug, Default)]
pub struct Journal {
    pub rejected: BTreeMap<String, Refusal>,
    pub seen_in: BTreeMap<String, BTreeSet<String>>,
    pub inputs: BTreeMap<String, Vec<(String, u32)>>,
}

/// The Teranode column's reads (docs/CONFORMANCE-TERANODE-OBSERVATION.md section 6). Every method is a
/// read except `submit`; every answer keeps the node's own object.
pub trait TeranodeObservation {
    /// receiveTx (DESIGN-S6 section 2.1): RPC `sendrawtransaction` or the validator's `ValidateTransaction`.
    fn submit(&mut self, raw: &[u8], road: SubmitRoad) -> Result<Submitted, Transport>;
    /// The tip: gRPC `GetBestBlockHeader` with `GetBestHeightAndTime`.
    fn tip(&mut self) -> Result<Tip, Transport>;
    /// The tips of the tree with their status: gRPC `GetChainTips`.
    fn chain_tips(&mut self) -> Result<Vec<ChainTip>, Transport>;
    /// Active-chain membership of store ids, true when ANY is on it: gRPC `CheckBlockIsInCurrentChain`.
    fn on_active(&mut self, block_ids: &[u32]) -> Result<bool, Transport>;
    /// A block by hash (gRPC `GetBlockHeader`), height (`GetBlockByHeight`) or store id (`GetBlockByID`).
    fn block(&mut self, at: BlockRef) -> Result<Option<BlockSummary>, Transport>;
    /// A block's member txids through its subtrees, the coinbase placeholder left out:
    /// `/block/:hash/subtrees/json` and `/subtree/:hash/txs/json`.
    fn block_members(&mut self, block: &str) -> Result<Vec<String>, Transport>;
    /// The nearest "mempool contents": RPC `getrawmempool`, block assembly's hashes, the placeholder left out.
    fn assembly_contents(&mut self) -> Result<Vec<String>, Transport>;
    /// A transaction's record: `/txmeta/:hash/json`; None on 404.
    fn tx_record(&mut self, id: &str) -> Result<Option<TxRecord>, Transport>;
    /// A transaction's bytes, the standard serialization: `/tx/:hash/hex`, which answers the extended
    /// format, stripped (`standard`); None on 404. Presence says nothing of status.
    fn tx_bytes(&mut self, id: &str) -> Result<Option<Vec<u8>>, Transport>;
    /// An outpoint's spend: `/utxo/:hash/json?vout=n`; None on 404.
    fn outpoint(&mut self, txid: &str, vout: u32) -> Result<Option<SpendState>, Transport>;
    /// Every output of a transaction with its spend: `/utxos/:hash/json`; None on 404.
    fn outputs(&mut self, txid: &str) -> Result<Option<Vec<SpendState>>, Transport>;
    /// The service state machine: gRPC `GetFSMCurrentState`; the RUNNING precondition.
    fn fsm(&mut self) -> Result<String, Transport>;
    /// The median time past by height: gRPC `GetMedianTimePastByHeights`.
    fn mtp(&mut self, heights: &[u32]) -> Result<Vec<u32>, Transport>;
    /// After-the-fact rejections: the `rejectedtx` topic, only where a broker is configured (section 3.2).
    fn rejections(&mut self) -> Option<Vec<RejectedTx>>;

    /// DESIGN-S6 section 3 assembled from the reads above (the page's section 4), clause by clause in its
    /// order; clauses 3 and 4 have no surface. A block counts for clause 1 only when the store holds it
    /// on the active chain, read per block (CheckBlockIsInCurrentChain answers ANY of its ids).
    fn status(&mut self, id: &str, journal: &Journal) -> Result<TeranodeStatus, Transport> {
        let record = self.tx_record(id)?;
        let mut blocks: BTreeSet<String> = record
            .as_ref()
            .map(|r| r.block_hashes.iter().cloned().collect())
            .unwrap_or_default();
        blocks.extend(journal.seen_in.get(id).cloned().unwrap_or_default());
        let (mut active, mut stale) = (vec![], false);
        for h in &blocks {
            if let Some(b) = self.block(BlockRef::Hash(h.clone()))? {
                if self.on_active(&[b.id])? {
                    active.push(b.height);
                } else {
                    stale = true;
                }
            }
        }
        if let Some(height) = active.iter().max() {
            return Ok(TeranodeStatus::MinedActive { height: *height });
        }
        if self.assembly_contents()?.iter().any(|x| x == id) {
            return Ok(TeranodeStatus::KnownUnmined);
        }
        if stale {
            return Ok(TeranodeStatus::OnStaleBranch);
        }
        for (parent, vout) in journal.inputs.get(id).into_iter().flatten() {
            let spender = self.outpoint(parent, *vout)?.and_then(|s| s.spender);
            if let Some(s) = spender.filter(|s| s != id) {
                for h in self
                    .tx_record(&s)?
                    .map(|r| r.block_hashes)
                    .unwrap_or_default()
                {
                    if let Some(b) = self.block(BlockRef::Hash(h))? {
                        if self.on_active(&[b.id])? {
                            return Ok(TeranodeStatus::ConflictedByMinedSpend { spender: s });
                        }
                    }
                }
            }
        }
        if let Some(r) = journal.rejected.get(id) {
            return Ok(TeranodeStatus::Rejected(r.clone()));
        }
        if record.is_some() {
            return Ok(TeranodeStatus::KnownUnmined);
        }
        Ok(TeranodeStatus::Unknown)
    }
}

/// The node's words in a rejection: every `NAME (code)` of the message, outermost to innermost
/// ([SRC] errors/error.proto:17-109 at PIN names the codes).
pub fn words(message: &str) -> Vec<(String, u64)> {
    let mut found = vec![];
    for (i, _) in message.match_indices(" (") {
        let start = message[..i]
            .rfind(|c: char| !(c.is_ascii_uppercase() || c == '_'))
            .map_or(0, |j| j + 1);
        let rest = &message[i + 2..];
        let digits = rest.chars().take_while(char::is_ascii_digit).count();
        if start < i && digits > 0 && rest[digits..].starts_with(')') {
            found.push((
                message[start..i].to_owned(),
                rest[..digits].parse::<u64>().unwrap_or(0),
            ));
        }
    }
    found
}

/// The innermost `NAME` of the message's chain.
pub fn innermost(message: &str) -> Option<String> {
    words(message).pop().map(|(name, _)| name)
}

/// The Teranode instance of #41, read through the contract's surfaces.
pub struct Instance41 {
    rpc: Rpc,
    native_path: PathBuf,
    native: Option<Worker>,
    journal: Vec<Value>,
}

struct Worker {
    child: Child,
    input: ChildStdin,
    output: BufReader<ChildStdout>,
}

impl Worker {
    fn spawn(path: &Path) -> Result<Self, String> {
        let mut child = Command::new(path)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .map_err(|e| {
                format!(
                    "{}: {e} (build it: harness/engines/instance41/native/build.py)",
                    path.display()
                )
            })?;
        let input = child.stdin.take().ok_or("the native client's stdin")?;
        let output = BufReader::new(child.stdout.take().ok_or("the native client's stdout")?);
        Ok(Self {
            child,
            input,
            output,
        })
    }

    fn call(&mut self, request: &Value) -> Result<Value, String> {
        serde_json::to_writer(&mut self.input, request).map_err(|e| e.to_string())?;
        self.input
            .write_all(b"\n")
            .and_then(|_| self.input.flush())
            .map_err(|e| e.to_string())?;
        let mut response = String::new();
        if self
            .output
            .read_line(&mut response)
            .map_err(|e| e.to_string())?
            == 0
        {
            return Err("the native client ended without an answer".into());
        }
        serde_json::from_str(&response).map_err(|e| format!("native protocol: {e}: {response}"))
    }
}

impl Drop for Worker {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

/// The native client's path: `INSTANCE41_NATIVE_DIR/client`, else the recipe's build directory.
pub fn native_client() -> Result<PathBuf, String> {
    match std::env::var_os("INSTANCE41_NATIVE_DIR") {
        Some(d) => Ok(PathBuf::from(d).join("client")),
        None => Ok(
            PathBuf::from(std::env::var("HOME").map_err(|e| e.to_string())?)
                .join("bsv/targets/spec-teranode/native-client/client"),
        ),
    }
}

// The handler of each RPC method, for the journal ([SRC] at PIN).
fn rpc_handler(method: &str) -> &'static str {
    match method {
        "sendrawtransaction" => "services/rpc/handlers.go:830-935 (Validate at 925; every rejection is -25 'TX rejected: ' at 926-930)",
        "generatetoaddress" => "services/rpc/handlers.go:1031-1071,2983-3026",
        "getminingcandidate" => "services/rpc/handlers.go:1104-1172",
        "getblockchaininfo" => "services/rpc/Server.go:174 (handleGetblockchaininfo; a 10 s cache at handlers.go:70-79)",
        "getrawmempool" => "services/rpc/handlers.go:1353-1392 (block assembly's transactions)",
        "getblock" => "services/rpc/handlers.go:101-152 (handleGetBlock; off the active chain the verbose form answers confirmations -1, 127-149); Server.go:172",
        "invalidateblock" => "services/rpc/handlers.go:1862-1886; Server.go:201",
        "getchaintips" => "services/rpc/handlers.go:2928-2968 (GetChainTips at 2946; a 300 s cache when the RPC cache is on, 2963-2965); Server.go:181 (the handler; the stale rpcUnimplemented entry at 279 is shadowed, 973-976)",
        "freeze" => "services/rpc/handlers.go:2708-2730 (handleFreeze: the UTXO store's FreezeUTXOs at 2725, stores/utxo/Interface.go:520-522; on the recipe's SQL store stores/utxo/sql/alert_system.go:54-103); Server.go:223",
        "reconsiderblock" => "services/rpc/handlers.go:1919-1990",
        _ => "services/rpc/Server.go:160-224,277-285,972-990 (the handler table, the unimplemented list, the dispatch)",
    }
}

// The gRPC server method of each native read ([SRC] services/blockchain/Server.go at PIN).
fn grpc_handler(method: &str) -> &'static str {
    match method {
        "validate" => "services/validator/Server.go:606-777 (ValidateTransaction)",
        "best_header" => "services/blockchain/Server.go:1679-1701 (GetBestBlockHeader), :3210-3240 (GetBestHeightAndTime)",
        "chain_tips" => "services/blockchain/Server.go:1747-1763 (GetChainTips)",
        "in_current_chain" => "services/blockchain/Server.go:1705-1721 (CheckBlockIsInCurrentChain)",
        "header" => "services/blockchain/Server.go:1765-1806 (GetBlockHeader)",
        "block_by_height" => "services/blockchain/Server.go:1332-1366 (GetBlockByHeight)",
        "block_by_id" => "services/blockchain/Server.go:1368-1402 (GetBlockByID)",
        "fsm_state" => "services/blockchain/Server.go:2814 (GetFSMCurrentState)",
        "mtp" => "services/blockchain/Server.go:1993-2006 (GetMedianTimePastByHeights)",
        "unimplemented_probe" => "services/blockchain/blockchain_api/blockchain_api.proto:67,70; services/blockchain/Server.go:1576,1616",
        _ => "harness/engines/instance41/native/main.go",
    }
}

fn u32_of(v: &Value, surface: &'static str, field: &str) -> Result<u32, Transport> {
    v[field]
        .as_u64()
        .and_then(|n| u32::try_from(n).ok())
        .ok_or_else(|| transport(surface, format!("no {field} in {v}")))
}

fn str_of(v: &Value, surface: &'static str, field: &str) -> Result<String, Transport> {
    v[field]
        .as_str()
        .map(str::to_owned)
        .ok_or_else(|| transport(surface, format!("no {field} in {v}")))
}

fn strings(v: &Value) -> Vec<String> {
    v.as_array()
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .map(str::to_owned)
        .collect()
}

fn u32s(v: &Value) -> Vec<u32> {
    v.as_array()
        .into_iter()
        .flatten()
        .filter_map(Value::as_u64)
        .filter_map(|n| u32::try_from(n).ok())
        .collect()
}

// A Bitcoin varint at `at`, which it advances.
fn varint(b: &[u8], at: &mut usize) -> Result<usize, String> {
    let width = match b.get(*at) {
        Some(0xfd) => 2,
        Some(0xfe) => 4,
        Some(0xff) => 8,
        Some(&n) => {
            *at += 1;
            return Ok(usize::from(n));
        }
        None => return Err("varint past the end".into()),
    };
    let bytes = b
        .get(*at + 1..*at + 1 + width)
        .ok_or("varint past the end")?;
    let n = bytes
        .iter()
        .rev()
        .fold(0u64, |n, &x| (n << 8) | u64::from(x));
    *at += 1 + width;
    usize::try_from(n).map_err(|e| e.to_string())
}

/// lane tera-97c (#66 cut 2): the standard serialization of a transaction the asset service answers in
/// the extended format. `/tx/:hash/hex` serves the UTXO store's `Tx.ExtendedBytes()` ([SRC]
/// services/asset/repository/repository.go:316-326 at PIN): after the version the marker
/// `00 00 00 00 00 EF`, and after each input its previous output's satoshis (8 bytes) and locking script
/// (go-bt v2.7.1, `tx.go:573-613`, `input.go:333-357`, the module `go.mod:14` at PIN requires). The RPC
/// `getrawtransaction` answers `tx.String()`, the standard bytes (services/rpc/handlers.go:559-603;
/// go-bt `tx.go:385-400`): the marker and the two input fields are dropped, every other byte kept in
/// order. Bytes without the marker are returned as they are.
pub fn standard(raw: Vec<u8>) -> Result<Vec<u8>, String> {
    const MARKER: [u8; 6] = [0, 0, 0, 0, 0, 0xEF];
    if raw.get(4..10) != Some(&MARKER[..]) {
        return Ok(raw);
    }
    // The lengths are the node's answer: a sum that overflows is a malformed answer, never a panic.
    let past = |at: usize, n: usize| -> Result<usize, String> {
        at.checked_add(n)
            .filter(|&end| end <= raw.len())
            .ok_or_else(|| "extended transaction past the end".to_owned())
    };
    let mut out = raw[..4].to_vec();
    let mut at = 10;
    let inputs = varint(&raw, &mut at)?;
    out.extend_from_slice(&raw[10..at]);
    for _ in 0..inputs {
        let from = at;
        at = past(at, 36)?;
        let script = varint(&raw, &mut at)?;
        at = past(past(at, script)?, 4)?;
        out.extend_from_slice(&raw[from..at]);
        at = past(at, 8)?;
        let previous = varint(&raw, &mut at)?;
        at = past(at, previous)?;
    }
    out.extend_from_slice(&raw[at..]);
    Ok(out)
}

fn spend_state(v: &Value) -> SpendState {
    SpendState {
        status: v["status"]
            .as_str()
            .map(str::to_owned)
            .unwrap_or_else(|| v["status"].to_string()),
        spender: v["spendingData"]["txId"].as_str().map(str::to_owned),
        raw: v.clone(),
    }
}

fn summary(v: &Value, surface: &'static str) -> Result<BlockSummary, Transport> {
    Ok(BlockSummary {
        hash: str_of(v, surface, "hash")?,
        height: u32_of(v, surface, "height")?,
        id: v["id"]
            .as_u64()
            .and_then(|n| u32::try_from(n).ok())
            .unwrap_or(0),
        merkle_root: str_of(v, surface, "merkleroot")?,
        time: u32_of(v, surface, "time")?,
        invalid: v["invalid"].as_bool(),
        mined_set: v["mined_set"].as_bool(),
        coinbase_tx: v["coinbase_tx"].as_str().map(str::to_owned),
        subtrees: strings(&v["subtrees"]),
        raw: v.clone(),
    })
}

impl Instance41 {
    /// The instance's surfaces on the loopback. `cookie` is a file holding the tag's public test
    /// credentials (`bitcoin:bitcoin`, [SRC] settings.conf:1273-1280 at PIN), written by the caller.
    pub fn new(cookie: &Path) -> Result<Self, String> {
        std::fs::write(cookie, "bitcoin:bitcoin").map_err(|e| e.to_string())?;
        Ok(Self {
            rpc: Rpc::new(RPC_URL, &cookie.to_string_lossy(), Duration::from_secs(120))?,
            native_path: native_client()?,
            native: None,
            journal: vec![],
        })
    }

    /// The calls since the last take, each with its surface, request, answer and handler.
    pub fn take_journal(&mut self) -> Vec<Value> {
        std::mem::take(&mut self.journal)
    }

    /// The native client's path (its hash goes in a run's identity).
    pub fn native_path(&self) -> &Path {
        &self.native_path
    }

    // One JSON-RPC call: the envelope `{"result":..}` or `{"error":..}`; a transport failure is an `Err`.
    fn rpc_envelope(&mut self, method: &str, params: Value) -> Result<Value, Transport> {
        let reply = self.rpc.call(method, params.clone());
        let envelope = match &reply {
            Ok(v) => Ok(json!({"result": v})),
            Err(e) => match e
                .strip_prefix("rpc error: ")
                .and_then(|s| serde_json::from_str::<Value>(s).ok())
            {
                Some(error) => Ok(json!({"error": error})),
                None => Err(transport("rpc", e.clone())),
            },
        };
        let answer = match &envelope {
            Ok(v) => v.clone(),
            Err(t) => json!({"transport_error": t.message}),
        };
        self.journal.push(
            json!({"surface": "rpc", "method": method, "params": params, "reply": answer,
            "source": format!("[SRC] {} at {PIN}", rpc_handler(method))}),
        );
        envelope
    }

    fn rpc_result(&mut self, method: &str, params: Value) -> Result<Value, Transport> {
        let envelope = self.rpc_envelope(method, params)?;
        if envelope.get("error").is_some() {
            return Err(transport("rpc", format!("{method}: {}", envelope["error"])));
        }
        Ok(envelope["result"].clone())
    }

    // One GET on the asset service: (status, body as JSON or text). `auth` sends the tag's public test
    // credentials as Basic auth, which the settings routes require ([SRC] services/asset/httpimpl/http.go:536-540,
    // ui/dashboard/authHandler.go:109-150,500-515 at PIN).
    fn asset(&mut self, path: &str) -> Result<(u64, Value), Transport> {
        self.asset_with(path, false)
    }

    fn asset_with(&mut self, path: &str, auth: bool) -> Result<(u64, Value), Transport> {
        let answer = (|| -> Result<(u64, Value), String> {
            let mut s = TcpStream::connect(ASSET).map_err(|e| format!("asset connect: {e}"))?;
            s.set_read_timeout(Some(Duration::from_secs(30))).ok();
            let authorization = if auth {
                format!(
                    "Authorization: Basic {}\r\n",
                    crate::rpc::base64(b"bitcoin:bitcoin")
                )
            } else {
                String::new()
            };
            let req = format!(
                "GET /api/v1/{path} HTTP/1.1\r\nHost: {}:{}\r\n{authorization}Connection: close\r\n\r\n",
                ASSET.0, ASSET.1
            );
            s.write_all(req.as_bytes())
                .map_err(|e| format!("asset write: {e}"))?;
            let mut raw = vec![];
            s.read_to_end(&mut raw)
                .map_err(|e| format!("asset read: {e}"))?;
            let text = String::from_utf8_lossy(&raw);
            let (head, body) = text
                .split_once("\r\n\r\n")
                .ok_or("asset: no header/body split")?;
            let status: u64 = head
                .split_whitespace()
                .nth(1)
                .and_then(|s| s.parse().ok())
                .ok_or("asset status")?;
            let chunked = head
                .to_ascii_lowercase()
                .contains("transfer-encoding: chunked");
            let body = if chunked {
                crate::rpc::dechunk(body)
            } else {
                body.to_owned()
            };
            let body = serde_json::from_str::<Value>(body.trim()).unwrap_or(json!(body.trim()));
            Ok((status, body))
        })();
        let reply = match &answer {
            Ok((status, body)) => json!({"http": status, "body": body}),
            Err(e) => json!({"transport_error": e}),
        };
        self.journal.push(
            json!({"surface": "asset", "asset": path, "auth": auth, "reply": reply,
            "source": format!("[SRC] services/asset/httpimpl/http.go:305-540 at {PIN}")}),
        );
        answer.map_err(|e| transport("asset", e))
    }

    // One call of the native client: the envelope `{"result":..}` or `{"error":..}`; a transport failure is an `Err`.
    fn native(&mut self, request: Value) -> Result<Value, Transport> {
        if self.native.is_none() {
            self.native = Some(Worker::spawn(&self.native_path).map_err(|e| transport("grpc", e))?);
        }
        let reply = match self.native.as_mut() {
            Some(w) => w.call(&request),
            None => Err("the native client did not start".into()),
        };
        let answer = match &reply {
            Ok(v) => v.clone(),
            Err(e) => json!({"transport_error": e}),
        };
        let method = request["method"].as_str().unwrap_or("").to_owned();
        self.journal.push(
            json!({"surface": "grpc", "request": request, "reply": answer,
            "source": format!("[SRC] {} at {PIN}", grpc_handler(&method))}),
        );
        let v = reply.map_err(|e| transport("grpc", e))?;
        if let Some(t) = v["transport_error"].as_str() {
            return Err(transport("grpc", t));
        }
        Ok(v)
    }

    fn native_result(&mut self, request: Value) -> Result<Value, Transport> {
        let v = self.native(request)?;
        if !v["error"].is_null() {
            return Err(transport("grpc", v["error"].to_string()));
        }
        Ok(v["result"].clone())
    }

    // A 404 is None; any other non-200 a transport failure naming the node's answer.
    fn asset_found(&mut self, path: &str) -> Result<Option<Value>, Transport> {
        match self.asset(path)? {
            (200, body) => Ok(Some(body)),
            (404, _) => Ok(None),
            (status, body) => Err(transport("asset", format!("{path}: http {status}: {body}"))),
        }
    }

    /// WRITE outside the trait (a scenario step): mine `n` blocks to `address`; their hashes.
    pub fn mine(&mut self, n: u32, address: &str) -> Result<Vec<String>, Transport> {
        let hashes = self.rpc_result("generatetoaddress", json!([n, address]))?;
        Ok(strings(&hashes))
    }

    /// The mining candidate's transaction count (block assembly's, before a block is mined).
    pub fn candidate_count(&mut self) -> Result<(u64, Value), Transport> {
        let c = self.rpc_result("getminingcandidate", json!([]))?;
        Ok((c["num_tx"].as_u64().unwrap_or(0), c))
    }

    /// The instance's readiness, never an observation (the page's section 2.1): `getblockchaininfo`'s
    /// `chain`, which must be `regtest`.
    pub fn chain(&mut self) -> Result<String, Transport> {
        let info = self.rpc_result("getblockchaininfo", json!([]))?;
        str_of(&info, "rpc", "chain")
    }

    /// WRITE outside the trait (a scenario step): `invalidateblock`, the envelope as received.
    pub fn invalidate(&mut self, hash: &str) -> Result<Value, Transport> {
        self.rpc_envelope("invalidateblock", json!([hash]))
    }

    /// WRITE outside the trait (a scenario step): `reconsiderblock`, the envelope as received.
    pub fn reconsider(&mut self, hash: &str) -> Result<Value, Transport> {
        self.rpc_envelope("reconsiderblock", json!([hash]))
    }

    /// A scenario road's read outside the trait (lane tera-97c, #66 cut 2): RPC `getblock` at
    /// `verbosity`, the envelope as received; the verbose form carries the RPC's `chainwork` and
    /// `confirmations` (-1 off the active chain). The trait's `block` reads gRPC.
    pub fn block_rpc(&mut self, hash: &str, verbosity: u64) -> Result<Value, Transport> {
        self.rpc_envelope("getblock", json!([hash, verbosity]))
    }

    /// WRITE outside the trait (a scenario step, lane tera-97c, #66 cut 2): `freeze` of one outpoint
    /// through the UTXO store's `FreezeUTXOs`, the envelope as received (`{"result":null}` on success).
    /// Lane ns-140 (#140, 2026-10-16): three parameters. The command's struct has three required fields
    /// (`TxID`, `Vout`, `UTXOHash`, services/rpc/bsvjson/chainsvrcmds.go:703-707), and the parser refuses
    /// fewer (checkNumParams, services/rpc/bsvjson/cmdparse.go:91-105, called at :148-149), which answered
    /// the two-parameter call -32602 on cut 2's road; the handler reads `TxID` and `Vout` and sets the
    /// store's `UTXOHash` to the txid itself (services/rpc/handlers.go:2725), so the third is the txid.
    /// The docs at the tag list two (docs/references/services/rpc_reference.md:1468-1469).
    pub fn freeze(&mut self, txid: &str, vout: u32) -> Result<Value, Transport> {
        self.rpc_envelope("freeze", json!([txid, vout, txid]))
    }

    /// A scenario road's fixture read (lane tera-97c, #66 cut 2): RPC `getchaintips`, the envelope as
    /// received, as the client answered before #97. The handler calls the same `GetChainTips` under the
    /// RPC's own `rpc_timeout` (30 s by default, services/rpc/Server.go:994, settings/settings.go:774), and
    /// answers from a 300 s cache when it holds one (services/rpc/handlers.go:2936-2938, 2963-2965;
    /// `rpc_cache_enabled` defaults true, settings/settings.go:773): road.rs:828's earlier read fills it,
    /// so the column's closing read is the cached tips when a `ttor` row read them within 300 s;
    /// otherwise it meets the same 30 s deadline (the record's key `chaintips_cached_300s` is a name,
    /// not a measurement); the trait's `chain_tips` stays the judging read.
    pub fn chain_tips_rpc(&mut self) -> Result<Value, Transport> {
        self.rpc_envelope("getchaintips", json!([]))
    }

    /// A finding's witness read (section 7), never a judging read: the native client's probe of F1's
    /// two rpcs, each one's gRPC status.
    pub fn witness_unimplemented(&mut self, hash: &str) -> Result<Value, Transport> {
        self.native_result(json!({"method": "unimplemented_probe", "hash": hash}))
    }

    /// A finding's witness read (section 7): one asset route as answered (F6's `/txmeta_raw`, F9's `/settings`
    /// with `auth`).
    pub fn witness_asset(&mut self, path: &str, auth: bool) -> Result<(u64, Value), Transport> {
        self.asset_with(path, auth)
    }

    /// A finding's witness read (section 7): F7's verbose `getrawmempool`, the envelope as received.
    pub fn witness_verbose_pool(&mut self) -> Result<Value, Transport> {
        self.rpc_envelope("getrawmempool", json!([true]))
    }
}

impl TeranodeObservation for Instance41 {
    fn submit(&mut self, raw: &[u8], road: SubmitRoad) -> Result<Submitted, Transport> {
        match road {
            SubmitRoad::Rpc => {
                let answer = self.rpc_envelope("sendrawtransaction", json!([hex::encode(raw)]))?;
                let verdict = match answer.get("error") {
                    Some(e) => {
                        let text = e["message"].as_str().unwrap_or("").to_owned();
                        Err(Refusal {
                            rpc_code: e["code"].as_i64(),
                            innermost: innermost(&text),
                            text,
                        })
                    }
                    None => Ok(answer["result"].as_str().unwrap_or("").to_owned()),
                };
                Ok(Submitted { verdict, answer })
            }
            SubmitRoad::ValidatorBlockContext { height, time, mtp } => {
                let answer = self.native(json!({"method": "validate", "hex": hex::encode(raw),
                    "height": height, "time": time, "mtp": mtp}))?;
                let verdict = if !answer["error"].is_null() {
                    let text = answer["error"]["message"].as_str().unwrap_or("").to_owned();
                    Err(Refusal {
                        rpc_code: None,
                        innermost: innermost(&text),
                        text,
                    })
                } else if answer["result"]["valid"] == false {
                    let text = answer["result"].to_string();
                    Err(Refusal {
                        rpc_code: None,
                        innermost: innermost(&text),
                        text,
                    })
                } else {
                    Ok(answer["result"]["txid"].as_str().unwrap_or("").to_owned())
                };
                Ok(Submitted { verdict, answer })
            }
        }
    }

    // Both handlers read the store's best header (services/blockchain/Server.go:1686,3211 at PIN), so
    // the heights differ only when a block lands between the two calls: lane tera-97c (#66 cut 2, whose
    // bridge delivers blocks to the end of the road) reads again, up to five times 200 ms apart.
    fn tip(&mut self) -> Result<Tip, Transport> {
        let mut reads = 0;
        let v = loop {
            let v = self.native_result(json!({"method": "best_header"}))?;
            reads += 1;
            if u32_of(&v["best_height_and_time"], "grpc", "height")?
                == u32_of(&v, "grpc", "height")?
            {
                break v;
            }
            if reads == 5 {
                return Err(transport(
                    "grpc",
                    format!("the tip moved between GetBestBlockHeader and GetBestHeightAndTime in {reads} reads: {v}"),
                ));
            }
            std::thread::sleep(Duration::from_millis(200));
        };
        let both = &v["best_height_and_time"];
        let height = u32_of(&v, "grpc", "height")?;
        Ok(Tip {
            hash: str_of(&v, "grpc", "hash")?,
            height,
            chain_work: str_of(&v, "grpc", "chain_work")?,
            median_time_past: u32_of(&v, "grpc", "median_time_past")?,
            time: u32_of(&v, "grpc", "time")?,
            tip_mtp: u32_of(both, "grpc", "time")?,
            raw: v,
        })
    }

    fn chain_tips(&mut self) -> Result<Vec<ChainTip>, Transport> {
        let v = self.native_result(json!({"method": "chain_tips"}))?;
        v.as_array()
            .into_iter()
            .flatten()
            .map(|t| {
                Ok(ChainTip {
                    height: u32_of(t, "grpc", "height")?,
                    hash: str_of(t, "grpc", "hash")?,
                    branchlen: u32_of(t, "grpc", "branchlen")?,
                    status: str_of(t, "grpc", "status")?,
                })
            })
            .collect()
    }

    fn on_active(&mut self, block_ids: &[u32]) -> Result<bool, Transport> {
        let v = self.native_result(json!({"method": "in_current_chain", "ids": block_ids}))?;
        v.as_bool()
            .ok_or_else(|| transport("grpc", format!("CheckBlockIsInCurrentChain: {v}")))
    }

    fn block(&mut self, at: BlockRef) -> Result<Option<BlockSummary>, Transport> {
        let request = match &at {
            BlockRef::Hash(h) => json!({"method": "header", "hash": h}),
            BlockRef::Height(n) => json!({"method": "block_by_height", "height": n}),
            BlockRef::Id(n) => json!({"method": "block_by_id", "id": n}),
        };
        let v = self.native(request)?;
        if !v["error"].is_null() {
            let text = v["error"]["message"].as_str().unwrap_or("");
            // [SRC] errors/error.proto:34 at PIN: BLOCK_NOT_FOUND (10); the store's sql.ErrNoRows reads as NOT_FOUND (3).
            if matches!(
                innermost(text).as_deref(),
                Some("BLOCK_NOT_FOUND" | "NOT_FOUND")
            ) {
                return Ok(None);
            }
            return Err(transport("grpc", v["error"].to_string()));
        }
        summary(&v["result"], "grpc").map(Some)
    }

    fn block_members(&mut self, block: &str) -> Result<Vec<String>, Transport> {
        let mut subtrees = vec![];
        let mut offset = 0u64;
        loop {
            let Some(page) = self.asset_found(&format!(
                "block/{block}/subtrees/json?offset={offset}&limit=100"
            ))?
            else {
                return Ok(vec![]);
            };
            let data = page["data"].as_array().cloned().unwrap_or_default();
            subtrees.extend(
                data.iter()
                    .filter_map(|s| s["hash"].as_str().map(str::to_owned)),
            );
            offset += data.len() as u64;
            if data.is_empty()
                || offset >= page["pagination"]["total_records"].as_u64().unwrap_or(0)
            {
                break;
            }
        }
        let mut members = vec![];
        for s in subtrees {
            let mut offset = 0u64;
            while let Some(page) =
                self.asset_found(&format!("subtree/{s}/txs/json?offset={offset}&limit=100"))?
            {
                let data = page["data"].as_array().cloned().unwrap_or_default();
                members.extend(
                    data.iter()
                        .filter_map(|t| t["txid"].as_str())
                        .filter(|t| *t != PLACEHOLDER)
                        .map(str::to_owned),
                );
                offset += data.len() as u64;
                if data.is_empty()
                    || offset >= page["pagination"]["total_records"].as_u64().unwrap_or(0)
                {
                    break;
                }
            }
        }
        Ok(members)
    }

    fn assembly_contents(&mut self) -> Result<Vec<String>, Transport> {
        let ids = self.rpc_result("getrawmempool", json!([]))?;
        let mut ids: Vec<String> = strings(&ids)
            .into_iter()
            .filter(|v| v != PLACEHOLDER)
            .collect();
        ids.sort();
        Ok(ids)
    }

    fn tx_record(&mut self, id: &str) -> Result<Option<TxRecord>, Transport> {
        Ok(self
            .asset_found(&format!("txmeta/{id}/json"))?
            .map(|body| TxRecord {
                block_ids: u32s(&body["blockIDs"]),
                block_hashes: strings(&body["blockHashes"]),
                block_heights: u32s(&body["blockHeights"]),
                main_chain_index: body["mainChainIndex"].as_i64(),
                raw: body,
            }))
    }

    fn tx_bytes(&mut self, id: &str) -> Result<Option<Vec<u8>>, Transport> {
        match self.asset_found(&format!("tx/{id}/hex"))? {
            None => Ok(None),
            Some(body) => {
                let text = body.as_str().unwrap_or("");
                hex::decode(text)
                    .map_err(|e| e.to_string())
                    .and_then(standard)
                    .map(Some)
                    .map_err(|e| transport("asset", format!("tx/{id}/hex: {e}")))
            }
        }
    }

    fn outpoint(&mut self, txid: &str, vout: u32) -> Result<Option<SpendState>, Transport> {
        Ok(self
            .asset_found(&format!("utxo/{txid}/json?vout={vout}"))?
            .map(|body| spend_state(&body)))
    }

    fn outputs(&mut self, txid: &str) -> Result<Option<Vec<SpendState>>, Transport> {
        Ok(self
            .asset_found(&format!("utxos/{txid}/json"))?
            .map(|body| {
                body.as_array()
                    .into_iter()
                    .flatten()
                    .map(spend_state)
                    .collect()
            }))
    }

    fn fsm(&mut self) -> Result<String, Transport> {
        let v = self.native_result(json!({"method": "fsm_state"}))?;
        v.as_str()
            .map(str::to_owned)
            .ok_or_else(|| transport("grpc", format!("GetFSMCurrentState: {v}")))
    }

    fn mtp(&mut self, heights: &[u32]) -> Result<Vec<u32>, Transport> {
        let v = self.native_result(json!({"method": "mtp", "heights": heights}))?;
        Ok(u32s(&v))
    }

    // The instance of #41 runs the in-process `memory` broker (settings.conf:57 at PIN; the page's 3.2):
    // no topic is readable from outside, so there is no after-the-fact rejection to read.
    fn rejections(&mut self) -> Option<Vec<RejectedTx>> {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn words_read_innermost() {
        let m = "TX rejected: PROCESSING (4): error validating transaction -> UTXO_NON_FINAL (71): lock time -> TX_LOCK_TIME (35): not final";
        assert_eq!(words(m).len(), 3);
        assert_eq!(innermost(m).as_deref(), Some("TX_LOCK_TIME"));
        assert_eq!(innermost("no codes here"), None);
    }

    #[test]
    fn a_header_answer_is_a_summary_without_a_body() {
        let v = json!({"hash": "ab", "height": 7, "id": 9, "merkleroot": "cd", "time": 1, "invalid": false, "mined_set": true});
        let s = summary(&v, "grpc").unwrap();
        assert_eq!(
            (s.id, s.height, s.invalid, s.coinbase_tx),
            (9, 7, Some(false), None)
        );
        assert!(summary(&json!({"height": 1}), "grpc").is_err());
    }

    #[test]
    fn the_extended_form_is_stripped_to_the_standard_bytes() {
        let input = [vec![0x11; 32], vec![0, 0, 0, 0, 1, 0x51], vec![0xff; 4]].concat();
        let rest = [
            vec![1],
            1000u64.to_le_bytes().to_vec(),
            vec![1, 0x51, 0, 0, 0, 0],
        ]
        .concat();
        let plain = [vec![1, 0, 0, 0, 1], input.clone(), rest.clone()].concat();
        let previous = [5000u64.to_le_bytes().to_vec(), vec![3, 0x76, 0xa9, 0x14]].concat();
        let extended = [
            vec![1, 0, 0, 0, 0, 0, 0, 0, 0, 0xef, 1],
            input,
            previous,
            rest,
        ]
        .concat();
        assert_eq!(standard(extended.clone()).unwrap(), plain);
        assert_eq!(standard(plain.clone()).unwrap(), plain);
        // An input cut short is an error; the outputs and the lock time are copied as they are.
        assert!(standard(extended[..50].to_vec()).is_err());
    }

    #[test]
    fn an_overflowing_varint_is_an_error_not_a_panic() {
        // The 0xff width read as 2^64-1: the script's length, then the previous output's script length.
        let huge = [vec![0xff], vec![0xff; 8]].concat();
        let head = [vec![1, 0, 0, 0, 0, 0, 0, 0, 0, 0xef, 1], vec![0x11; 36]].concat();
        let script = [head.clone(), huge.clone(), vec![0; 16]].concat();
        assert!(standard(script).is_err());
        let previous = [head, vec![0, 0, 0, 0, 0], vec![0; 8], huge, vec![0; 16]].concat();
        assert!(standard(previous).is_err());
    }

    #[test]
    fn a_spend_names_its_spender() {
        let s = spend_state(&json!({"status": "SPENT", "spendingData": {"txId": "ee", "vin": 0}}));
        assert_eq!(
            (s.status.as_str(), s.spender.as_deref()),
            ("SPENT", Some("ee"))
        );
        assert_eq!(spend_state(&json!({"status": "OK"})).spender, None);
    }
}
