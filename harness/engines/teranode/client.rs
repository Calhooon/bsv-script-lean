//! The Teranode client of #74 (S4b, lane tera-74, [M] 2026-10-14): the instance of
//! #41 started and stopped by its own recipe (`harness/engines/instance41/instance.py`,
//! a fresh `INSTANCE41_DATA` per run). Since lane trait-97 (2026-10-15, #97) it reads the
//! node only through the observation contract (`harness/engines/teranode/contract.rs`, the
//! trait of docs/CONFORMANCE-TERANODE-OBSERVATION.md section 6, every call journaled with its
//! surface and handler at Teranode v0.16.0, `4edb60a40c6628ff0ef60231c2628efd7103fde5` [SRC]);
//! this file keeps the scenario road's names over it. The observation set is
//! `docs/CONFORMANCE-TERANODE-MACHINE.md` section 5.
//! **The second oracle's defaults are never the rule** (DESIGN-S6 section 5.2).

use bsv_script_harness::teranode_contract::{
    words as chain_words, BlockRef, Instance41, SubmitRoad, TeranodeObservation,
};
// RPC_URL since lane cut2-66q2: a second connection submits #90's concurrent pair.
pub(crate) use bsv_script_harness::teranode_contract::{PIN, RPC_URL, TAG};
use serde_json::{json, Value};
use std::{
    path::{Path, PathBuf},
    process::Command,
    thread,
    time::{Duration, Instant},
};

pub(crate) type Result<T> = std::result::Result<T, String>;
pub(crate) const BINARY_SHA256: &str =
    "dedd0003386ac5ee7969ab1beaab9db91b0291baf70e066717a3c8e85b3f9ee8";

pub(crate) struct Tera {
    pub(crate) data: PathBuf,
    node: Option<Instance41>,
    pub(crate) calls: Vec<Value>,
    pub(crate) running: bool,
    // lane tera-97f: inside `call` or `receipt`, whose own fault line (with the method's name) stands
    // for every failure of the call, the contract's and the client's own refusals alike.
    placing: bool,
}

fn instance(data: &Path, action: &str) -> Result<Value> {
    let out = Command::new("python3")
        .arg("harness/engines/instance41/instance.py")
        .arg(action)
        .env("INSTANCE41_DATA", data)
        .output()
        .map_err(|e| e.to_string())?;
    if !out.status.success() {
        return Err(format!(
            "instance.py {action}: {}{}",
            String::from_utf8_lossy(&out.stdout),
            String::from_utf8_lossy(&out.stderr)
        ));
    }
    serde_json::from_slice(&out.stdout).map_err(|e| format!("instance.py {action} answer: {e}"))
}

impl Tera {
    /// Start the recorded binary on a fresh data directory by the recipe; the
    /// recipe checks the source HEAD, the binary's SHA-256, the load, the disk
    /// and every listener on 127.0.0.1 before it answers.
    pub(crate) fn start(data: PathBuf) -> Result<Self> {
        if data.exists() {
            return Err(format!(
                "the data directory {} is not fresh",
                data.display()
            ));
        }
        let answer = instance(&data, "start")?;
        if answer["running"] != true || answer["sha256"] != BINARY_SHA256 {
            return Err(format!("instance.py start: {answer}"));
        }
        let node = Instance41::new(&data.join("rpc.cookie"))?;
        let mut t = Self {
            data,
            node: Some(node),
            calls: vec![],
            running: true,
            placing: false,
        };
        t.calls.push(json!({"lifecycle":"start","label":"[M]","tag":TAG,"pin":PIN,"binary_sha256":BINARY_SHA256,
            "listeners":answer["listeners"],"source":"harness/engines/instance41/README.md; instance.py start"}));
        Ok(t)
    }

    /// lane cut2-66q4 (#66 cut 2, the settings restarts): start the recipe again on this
    /// instance's own data after `stop`, its stores kept; instance.py reads the data
    /// directory's overlay.conf, if the caller wrote one, after the recipe's settings.
    pub(crate) fn restart(&mut self) -> Result<()> {
        if self.running {
            return Err("restart of a running instance".into());
        }
        let answer = instance(&self.data, "start")?;
        if answer["running"] != true || answer["sha256"] != BINARY_SHA256 {
            return Err(format!("instance.py start: {answer}"));
        }
        self.node = Some(Instance41::new(&self.data.join("rpc.cookie"))?);
        self.running = true;
        self.calls.push(json!({"lifecycle":"restart","label":"[M]","binary_sha256":BINARY_SHA256,
            "listeners":answer["listeners"],"settings_local_sha256":answer["settings_local_sha256"],"source":"instance.py start on the same data"}));
        Ok(())
    }

    #[track_caller]
    pub(crate) fn stop(&mut self) -> Result<()> {
        if !self.running {
            return Ok(());
        }
        let at = std::panic::Location::caller();
        let answer = instance(&self.data, "stop").inspect_err(|_| fault(at, "stop"))?;
        self.running = false;
        if let Some(mut node) = self.node.take() {
            self.calls.extend(node.take_journal());
        }
        self.calls.push(json!({"lifecycle":"stop","answer":answer}));
        Ok(())
    }

    // One operation on the contract, its journal appended to `calls`.
    #[track_caller]
    fn with<T>(
        &mut self,
        op: impl FnOnce(&mut Instance41) -> std::result::Result<T, String>,
    ) -> Result<T> {
        let at = std::panic::Location::caller();
        let node = self.node.as_mut().ok_or("the instance is stopped")?;
        let answer = op(node);
        self.calls.extend(node.take_journal());
        if answer.is_err() && !self.placing {
            fault(at, "");
        }
        answer
    }

    // lane tera-97f: `call` and `receipt` placed whole: one fault line for any `Err` of the outermost
    // of them, the scenario's source location and the RPC name it asked for (a refusal before the
    // contract, an argument the client cannot read, or the contract's own failure).
    #[track_caller]
    fn placed(
        &mut self,
        method: &str,
        op: impl FnOnce(&mut Self) -> Result<Value>,
    ) -> Result<Value> {
        let at = std::panic::Location::caller();
        let outer = !self.placing;
        self.placing = true;
        let answer = op(self);
        if outer {
            self.placing = false;
            if answer.is_err() {
                fault(at, method);
            }
        }
        answer
    }

    /// The scenario road's calls by their RPC names, each answered through the contract: the writes
    /// of a scenario step (`generatetoaddress`, `getminingcandidate`, and since lane tera-97c for #66
    /// cut 2 `invalidateblock`, `reconsiderblock` and `freeze`) and the reads `getblockbyheight` (the
    /// trait's `block`), `getrawtransaction` (its `tx_bytes`) and `getblock` (the contract's `block_rpc`).
    /// An RPC error is an `Err`, as the pre-#97 client answered; any other name is refused.
    #[track_caller]
    pub(crate) fn call(&mut self, method: &str, params: Value) -> Result<Value> {
        self.placed(method, |t| t.call_road(method, params))
    }

    #[track_caller]
    fn call_road(&mut self, method: &str, params: Value) -> Result<Value> {
        match method {
            "getblock" | "invalidateblock" | "reconsiderblock" | "freeze" => {
                let envelope = self.receipt(method, params)?;
                match envelope.get("error") {
                    Some(e) => Err(format!("rpc error: {e}")),
                    None => Ok(envelope["result"].clone()),
                }
            }
            "generatetoaddress" => {
                let n = params[0].as_u64().and_then(|n| u32::try_from(n).ok()).ok_or("generatetoaddress count")?;
                let address = params[1].as_str().ok_or("generatetoaddress address")?.to_owned();
                self.with(|c| Ok(json!(c.mine(n, &address)?)))
            }
            "getminingcandidate" => self.with(|c| Ok(c.candidate_count()?.1)),
            "getblockbyheight" => {
                let h = params[0].as_u64().and_then(|n| u32::try_from(n).ok()).ok_or("getblockbyheight height")?;
                self.with(|c| match c.block(BlockRef::Height(h))? {
                    Some(b) => Ok(with_bits(b.raw)),
                    None => Err(format!("no block at height {h}")),
                })
            }
            "getrawtransaction" => {
                let id = params[0].as_str().ok_or("getrawtransaction id")?.to_owned();
                self.with(|c| match c.tx_bytes(&id)? {
                    Some(b) => Ok(json!(hex::encode(b))),
                    None => Err(format!("no transaction {id}")),
                })
            }
            _ => Err(format!("{method} is not a surface of the observation contract (docs/CONFORMANCE-TERANODE-OBSERVATION.md section 6): add it to harness/engines/teranode/contract.rs")),
        }
    }

    /// lane cut2-66q2's asset read (#66 cut 2), through the contract since the stacked landing land-w2l
    /// (#97 moved the asset service behind it): one GET as answered, `{"http":status,"body":..}`, journaled.
    #[track_caller]
    pub(crate) fn asset(&mut self, path: &str) -> Result<Value> {
        self.with(|c| {
            let (status, body) = c.witness_asset(path, false)?;
            Ok(json!({"http":status,"body":body}))
        })
    }

    /// The call's whole envelope: `{"result":..}` or `{"error":..}`; a transport failure is an `Err`.
    #[track_caller]
    pub(crate) fn receipt(&mut self, method: &str, params: Value) -> Result<Value> {
        self.placed(method, |t| t.receipt_road(method, params))
    }

    #[track_caller]
    fn receipt_road(&mut self, method: &str, params: Value) -> Result<Value> {
        match method {
            "sendrawtransaction" => {
                let raw = hex::decode(params[0].as_str().ok_or("sendrawtransaction hex")?)
                    .map_err(|e| e.to_string())?;
                self.with(|c| Ok(c.submit(&raw, SubmitRoad::Rpc)?.answer))
            }
            "invalidateblock" | "reconsiderblock" => {
                let hash = params[0].as_str().ok_or("block hash")?.to_owned();
                self.with(|c| {
                    Ok(if method == "invalidateblock" {
                        c.invalidate(&hash)?
                    } else {
                        c.reconsider(&hash)?
                    })
                })
            }
            "getblock" => {
                let hash = params[0].as_str().ok_or("getblock hash")?.to_owned();
                let verbosity = params.get(1).and_then(Value::as_u64).unwrap_or(1);
                self.with(|c| Ok(c.block_rpc(&hash, verbosity)?))
            }
            "freeze" => {
                let txid = params[0].as_str().ok_or("freeze txid")?.to_owned();
                let vout = params[1]
                    .as_u64()
                    .and_then(|n| u32::try_from(n).ok())
                    .ok_or("freeze vout")?;
                self.with(|c| Ok(c.freeze(&txid, vout)?))
            }
            // lane tera-97c: the RPC's envelope, as before #97 (the contract's `chain_tips_rpc`).
            "getchaintips" => self.with(|c| Ok(c.chain_tips_rpc()?)),
            _ => Ok(json!({"result": self.call(method, params)?})),
        }
    }

    /// The tip's height and hash: gRPC `GetBestBlockHeader` (the contract's `tip`).
    #[track_caller]
    pub(crate) fn tip(&mut self) -> Result<(u64, String)> {
        self.with(|c| {
            let t = c.tip()?;
            Ok((u64::from(t.height), t.hash))
        })
    }

    /// Block assembly's transactions, the placeholder node removed (the contract's `assembly_contents`).
    #[track_caller]
    pub(crate) fn pool(&mut self) -> Result<Vec<String>> {
        self.with(|c| Ok(c.assembly_contents()?))
    }

    /// Wait until block assembly lists `id` (it takes a validated transaction
    /// asynchronously, [SRC] services/validator/Validator.go:2200 at PIN), up to 10 s.
    #[track_caller]
    pub(crate) fn settle_in_pool(&mut self, id: &str) -> Result<bool> {
        let start = Instant::now();
        loop {
            if self.pool()?.iter().any(|x| x == id) {
                return Ok(true);
            }
            if start.elapsed() > Duration::from_secs(10) {
                return Ok(false);
            }
            thread::sleep(Duration::from_millis(250));
        }
    }

    /// Mine one block after the mining candidate counts `pending` transactions
    /// (assembly is asynchronous; a block generated earlier is empty), and return its hash.
    #[track_caller]
    pub(crate) fn mine_pending(&mut self, pending: u64, address: &str) -> Result<String> {
        let start = Instant::now();
        loop {
            let (n, c) = self.with(|c| Ok(c.candidate_count()?))?;
            if n >= pending {
                break;
            }
            if start.elapsed() > Duration::from_secs(120) {
                return Err(format!(
                    "block assembly did not count {pending} transactions within 120 s: {c}"
                ));
            }
            thread::sleep(Duration::from_millis(250));
        }
        let hashes = self.with(|c| Ok(c.mine(1, address)?))?;
        hashes
            .into_iter()
            .next()
            .ok_or_else(|| "generated hash".into())
    }

    /// The UTXO store's record of `id` (the contract's `tx_record`, `/txmeta/:hash/json`) as
    /// `{"http":200,"body":..}`, or `{"http":404}` when the store has none.
    #[track_caller]
    pub(crate) fn txmeta(&mut self, id: &str) -> Result<Value> {
        self.with(|c| {
            Ok(match c.tx_record(id)? {
                Some(r) => json!({"http": 200, "body": r.raw}),
                None => json!({"http": 404, "body": Value::Null}),
            })
        })
    }

    /// Every output of `id` with its status and spender (the contract's `outputs`, `/utxos/:hash/json`).
    #[track_caller]
    pub(crate) fn utxos(&mut self, id: &str) -> Result<Value> {
        self.with(|c| {
            Ok(match c.outputs(id)? {
                Some(outs) => json!({"http": 200, "body": outs.into_iter().map(|o| o.raw).collect::<Vec<_>>()}),
                None => json!({"http": 404, "body": Value::Null}),
            })
        })
    }

    /// Whether `hash` is on the current chain, and its height: the contract's `block` by hash for the
    /// store id, then `on_active` of that one id. None when the store has no such block.
    #[track_caller]
    pub(crate) fn on_active(&mut self, hash: &str) -> Result<Option<(bool, u64)>> {
        self.with(|c| match c.block(BlockRef::Hash(hash.to_owned()))? {
            Some(b) => Ok(Some((c.on_active(&[b.id])?, u64::from(b.height)))),
            None => Ok(None),
        })
    }
}

impl Drop for Tera {
    fn drop(&mut self) {
        if self.running {
            let _ = self.stop();
        }
    }
}

/// lane tera-97c (#66 cut 2, the quarantine rule): where a contract operation failed, placed without its
/// text. With `TERA_FAULT_LOG` set, one line per failure, the harness's own source location of the
/// scenario's call (`#[track_caller]` through the client's methods), the RPC name the scenario asked
/// for (lane tera-97f; empty for the client's other methods, which the location names) and the time:
/// never the error, which may carry the node's words. The name is the harness's own argument, kept
/// only if it is a short `[a-z_]` word, so no other text reaches the line.
fn fault(at: &std::panic::Location<'_>, op: &str) {
    use std::io::Write;
    let Some(path) = std::env::var_os("TERA_FAULT_LOG") else {
        return;
    };
    let unix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let op = if op.len() <= 32 && op.bytes().all(|c| c.is_ascii_lowercase() || c == b'_') {
        op
    } else {
        "?"
    };
    if let Ok(mut f) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)
    {
        let _ = writeln!(
            f,
            "{}",
            json!({"at": format!("{}:{}", at.file(), at.line()), "op": op, "unix": unix})
        );
    }
}

/// lane tera-97c (#66 cut 2): the road reads `bits` from `getblockbyheight` (road.rs `tip`, the median
/// row), which the RPC answer carried and the gRPC `GetBlockByHeight` answer of the native client does
/// not; both read the store's `GetBlockByHeight` ([SRC] services/rpc/handlers.go:177-194, services/blockchain/Server.go:1332-1366 at PIN). The
/// field is the header's own bytes 72-75, written as the RPC writes it: `NBit.String`, the four bytes
/// reversed and hex-encoded ([SRC] model/NBit.go:34-36, services/rpc/handlers.go:467 at PIN).
fn with_bits(mut raw: Value) -> Value {
    let header = raw["header"].as_str().and_then(|h| hex::decode(h).ok());
    if let Some(&[a, b, c, d]) = header.as_deref().and_then(|h| h.get(72..76)) {
        raw["bits"] = json!(format!("{:08x}", u32::from_le_bytes([a, b, c, d])));
    }
    raw
}

/// The node's words in a rejection: every `NAME (code)` of the message, from the outermost
/// to innermost ([SRC] errors/error.proto:17-109 at PIN names the codes).
pub(crate) fn words(message: &str) -> Vec<Value> {
    chain_words(message)
        .into_iter()
        .map(|(name, code)| json!({"name": name, "code": code}))
        .collect()
}

/// The verdict word: the innermost code that names a transaction or UTXO class
/// (the PROCESSING and generic wrappers skipped).
pub(crate) fn verdict_word(message: &str) -> Option<String> {
    words(message)
        .iter()
        .rev()
        .filter_map(|w| w["name"].as_str())
        .find(|n| {
            !matches!(
                *n,
                "PROCESSING"
                    | "ERROR"
                    | "UNKNOWN"
                    | "SERVICE_ERROR"
                    | "TX_ERROR"
                    | "UTXO_ERROR"
                    | "CONTEXT_CANCELED"
            )
        })
        .map(str::to_owned)
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    #[test]
    fn bits_read_from_the_header() {
        let mut header = vec![0u8; 80];
        header[72..76].copy_from_slice(&[0xff, 0xff, 0x7f, 0x20]);
        let b = super::with_bits(json!({"header": hex::encode(&header), "hash": "ab"}));
        assert_eq!(b["bits"], "207fffff");
        let none = super::with_bits(json!({"hash": "ab"}));
        assert!(none.get("bits").is_none());
    }

    // TERA_FAULT_LOG is process-wide while the tests run in parallel: no other test may
    // reach `fault`, or its line lands in this file and breaks the count.
    #[test]
    fn fault_line_carries_only_the_place_and_the_name() {
        let path = std::env::temp_dir().join(format!("fault-line-{}.jsonl", std::process::id()));
        let _ = std::fs::remove_file(&path);
        std::env::set_var("TERA_FAULT_LOG", &path);
        let at = std::panic::Location::caller();
        super::fault(at, "getrawtransaction");
        super::fault(at, "rpc error: some reply");
        std::env::remove_var("TERA_FAULT_LOG");
        let lines: Vec<serde_json::Value> = std::fs::read_to_string(&path)
            .unwrap()
            .lines()
            .map(|l| serde_json::from_str(l).unwrap())
            .collect();
        let _ = std::fs::remove_file(&path);
        assert_eq!(lines.len(), 2);
        assert_eq!(lines[0]["op"], "getrawtransaction");
        assert_eq!(lines[1]["op"], "?");
        for l in &lines {
            let keys: Vec<&str> = l.as_object().unwrap().keys().map(String::as_str).collect();
            assert_eq!(keys, ["at", "op", "unix"]);
            assert!(l["at"].as_str().unwrap().contains("client.rs:"));
        }
    }

    #[test]
    fn words_read_innermost() {
        let m = "TX rejected: PROCESSING (4): error validating transaction -> UTXO_NON_FINAL (71): lock time -> TX_LOCK_TIME (35): not final";
        assert_eq!(super::words(m).len(), 3);
        assert_eq!(super::verdict_word(m).as_deref(), Some("TX_LOCK_TIME"));
        assert_eq!(super::verdict_word("no codes here"), None);
        assert_eq!(
            bsv_script_harness::teranode_contract::innermost(m).as_deref(),
            Some("TX_LOCK_TIME")
        );
    }
}
