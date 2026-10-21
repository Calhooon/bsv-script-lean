//! #66 cut 1: isolated regtest receipts and explicitly bounded realizations.
//! Sources: bitcoin-sv 6504a3aff65ba97c0f6c80962b033e35ecbfed4b;
//! docs/DESIGN-S6.md sections 3 and 5.1. Every RPC receipt names its handler.
pub(super) use bsv_rs::primitives::hash::hash160;
pub(super) use bsv_script_harness::{
    block as block_codec,
    fail::OrErr,
    host,
    rpc::Rpc,
    txraw::{txid_display_hex, txid_from_display_hex, RawInput, RawOutput, RawTx},
};
pub(super) use serde_json::{json, Value};
pub(super) use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    net::TcpListener,
    path::{Path, PathBuf},
    process::{Child, Command},
    thread,
    time::{Duration, Instant},
};
pub(super) type Result<T> = std::result::Result<T, String>;
static INTERRUPTED: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);
extern "C" fn interrupt(_: i32) {
    INTERRUPTED.store(true, std::sync::atomic::Ordering::Relaxed);
}
#[cfg(unix)]
pub(super) fn signals() {
    unsafe extern "C" {
        fn signal(number: i32, handler: extern "C" fn(i32)) -> usize;
    }
    unsafe {
        signal(2, interrupt);
        signal(15, interrupt);
        signal(1, interrupt);
    }
}
#[cfg(not(unix))]
pub(super) fn signals() {}
pub(super) const PIN: &str = "6504a3aff65ba97c0f6c80962b033e35ecbfed4b";
pub(super) const VERSION: &str = "v1.2.3.0-g6504a3aff-dev";
// [D] 2026-10-13 (#72): the scenario's one clock at instance start. Every
// fresh instance is put on it before any step, so no judged value reads
// the host's clock; GetTime returns the mock value once set ([SRC]
// src/utiltime.cpp:23-33; src/rpc/misc.cpp:1002-1005 at PIN). It is the
// earliest clock the common prefix (`seed`) mines at.
pub(super) const START_CLOCK: u64 = 1_699_990_000;
// [D] 2026-10-14 (#121, H6 road (b)): the binary a row runs on. A row with no
// `binary` field runs on the node of record (`reference.binary`); a row with
// `"binary":"wallet"` runs on the second binary of the same pin configured
// with the wallet (`reference.binary_wallet`, docs/PROVENANCE.md 1a, not the
// node of record). Both start on the same scenarios.conf settings.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum Build {
    Record,
    Wallet,
    // [D] 2026-10-15 (#84, lane events-84): a third binary of the same pin with
    // BUILD_BITCOIN_ZMQ=ON (src/CMakeLists.txt:13 at PIN); the other two are
    // configured OFF, so they create no notifier. Selected by the events recipe only.
    Zmq,
}
impl Build {
    pub(super) fn of(row: &Value) -> Result<Self> {
        match row.get("binary") {
            None => Ok(Self::Record),
            Some(v) if v == "wallet" => Ok(Self::Wallet),
            Some(v) => Err(format!(
                "row binary {v}: the selector names only \"wallet\""
            )),
        }
    }
    // [D] 2026-10-21 (#177 b): the pins block writes each build as `$NAME`, a
    // maintainers' host value (harness/src/host.rs); unresolved, one line and exit 2.
    pub(super) fn var(self) -> &'static str {
        match self {
            Self::Record => host::REFERENCE_BINARY,
            Self::Wallet => host::REFERENCE_BINARY_WALLET,
            Self::Zmq => host::REFERENCE_BINARY_ZMQ,
        }
    }
    // The build's path on this host. The zmq build may sit elsewhere (a lane
    // builds inside its own worktree): SV_ZMQ_BITCOIND names it, and its version
    // is checked at launch.
    pub(super) fn located(self) -> PathBuf {
        match (self, std::env::var("SV_ZMQ_BITCOIND")) {
            (Self::Zmq, Ok(named)) => PathBuf::from(named),
            _ => host::need(self.var()),
        }
    }
    pub(super) fn name(self) -> &'static str {
        match self {
            Self::Record => "node of record",
            Self::Wallet => "wallet build",
            Self::Zmq => "zmq build",
        }
    }
    pub(super) fn pin_key(self) -> &'static str {
        match self {
            Self::Record => "reference.binary",
            Self::Wallet => "reference.binary_wallet",
            Self::Zmq => "reference.binary_zmq",
        }
    }
    // [D] 2026-10-14, lane fix-121: absence is a row result, before any launch.
    pub(super) fn absent_row_at(self, row: &Value, path: &Path) -> Option<Value> {
        (!path.is_file()).then(|| json!({
            "id":row["id"], "build":self.name(), "label":"[X]",
            "unrealizable":format!("the {} is absent on this host: {}", self.name(), path.display())
        }))
    }
    pub(super) fn absent_row(self, row: &Value) -> Result<Option<Value>> {
        Ok(self.absent_row_at(row, &self.located()))
    }
    pub(super) fn version_at(self, path: &Path) -> Result<Option<String>> {
        if !path.is_file() {
            return Ok(None);
        }
        let out = Command::new(path)
            .arg("-version")
            .output()
            .map_err(|e| e.to_string())?;
        let line = String::from_utf8_lossy(&out.stdout)
            .lines()
            .next()
            .unwrap_or("")
            .to_owned();
        if !out.status.success() || line != format!("Bitcoin SV version {VERSION}") {
            return Err(format!("{} version mismatch: {line}", self.name()));
        }
        Ok(Some(line))
    }
    // An absent binary stops the row; it never falls back to the other build.
    pub(super) fn path(self) -> Result<PathBuf> {
        let path = self.located();
        if !path.is_file() {
            return Err(format!(
                "the {} is absent on this host: {}",
                self.name(),
                path.display()
            ));
        }
        Ok(path)
    }
}
pub(super) const FAMILIES: [&str; 6] = ["mempool", "finality", "block", "utxo", "chain", "oracle"];
pub(super) fn handler(method: &str) -> Result<&'static str> {
    Ok(match method {
        "generatetoaddress" => "src/rpc/mining.cpp:227-268",
        "submitblock" => "src/rpc/mining.cpp:916-952",
        "sendrawtransactions" => "src/rpc/rawtransaction.cpp:1798-2239",
        "sendrawtransaction" => "src/rpc/rawtransaction.cpp:1530-1672",
        "getrawtransaction" => "src/rpc/rawtransaction.cpp:53-194",
        "verifyscript" => "src/rpc/misc.cpp:506-914",
        "getmerkleproof" => "src/rpc/rawtransaction.cpp:2242-2340",
        // [SRC] 2026-10-13, lane s6-75: the second proof RPC and the node's own verifier, at PIN.
        "getmerkleproof2" => "src/rpc/rawtransaction.cpp:2342-2525",
        "verifymerkleproof" => "src/rpc/rawtransaction.cpp:2527-2612",
        "setmocktime" => "src/rpc/misc.cpp:980-1007",
        // [SRC] 2026-10-13 (#72): the assembly window and the clock offset at PIN.
        "getchaintxstats" => "src/rpc/blockchain.cpp:3054-3155",
        "getnetworkinfo" => "src/rpc/net.cpp:543-667",
        "getpeerinfo" => "src/rpc/net.cpp:69-280",
        // [SRC] 2026-10-15 (#78, lane s7-78): the connection and ban handlers at PIN.
        "addnode" => "src/rpc/net.cpp:282-327",
        "listbanned" => "src/rpc/net.cpp:759-789",
        "getblockcount" => "src/rpc/blockchain.cpp:205-218",
        // [SRC] 2026-10-13: active-height lookup for #65, at PIN.
        "getblockhash" => "src/rpc/blockchain.cpp:801-828",
        "getbestblockhash" => "src/rpc/blockchain.cpp:220-236",
        "getrawmempool" => "src/rpc/blockchain.cpp:440-500",
        "getrawnonfinalmempool" => "src/rpc/blockchain.cpp:502-550",
        "getblock" => "src/rpc/blockchain.cpp:1108-1242",
        "gettxout" => "src/rpc/blockchain.cpp:1923-2029",
        "getchaintips" => "src/rpc/blockchain.cpp:2497-2632",
        "getorphaninfo" => "src/rpc/blockchain.cpp:2675-2693",
        "invalidateblock" => "src/rpc/blockchain.cpp:2732-2768",
        "reconsiderblock" => "src/rpc/blockchain.cpp:2770-2818",
        // [SRC] 2026-10-13: peer observation handlers at PIN.
        "waitforptvcompletion" => "src/rpc/blockchain.cpp:3769-3786",
        "getmempoolinfo" => "src/rpc/blockchain.cpp:2634-2673",
        "getblockheader" => "src/rpc/blockchain.cpp:884-1038",
        // [SRC] 2026-10-15, lane s7-82: #82 the prune RPC and the chain summary's prune fields, at PIN.
        "pruneblockchain" => "src/rpc/blockchain.cpp:1810-1875",
        "getblockchaininfo" => "src/rpc/blockchain.cpp:2394-2482",
        "getblockchainactivity" => "src/rpc/blockchain.cpp:3649-3688",
        "prioritisetransaction" => "src/rpc/mining.cpp:312-351",
        "stop" => "src/rpc/server.cpp:265-287",
        // [SRC] 2026-10-14 (#121, lane wallet-rows-b): the wallet build's handlers at PIN.
        "getwalletinfo" => "src/wallet/rpcwallet.cpp:2798-2878",
        "getnewaddress" => "src/wallet/rpcwallet.cpp:119-172",
        "getreceivedbyaddress" => "src/wallet/rpcwallet.cpp:680-764",
        "gettransaction" => "src/wallet/rpcwallet.cpp:2061-2187",
        "validateaddress" => "src/rpc/misc.cpp:206-300",
        _ => return Err(format!("RPC without pinned handler: {method}")),
    })
}
// Export instance pointers relative to the scenario storage root.
#[allow(
    clippy::expect_used,
    reason = "every run root is made under $HOME/bsv/targets/spec-oracle-scenarios by scenarios/mod.rs (create_dir of the run id); a path outside it is a driver bug the message names"
)]
pub(super) fn instance_pointer(path: &Path) -> String {
    let parts: Vec<_> = path.components().collect();
    let start = parts
        .iter()
        .position(|p| p.as_os_str() == "spec-oracle-scenarios")
        .expect("owned scenario path")
        + 1;
    parts[start..]
        .iter()
        .collect::<PathBuf>()
        .to_string_lossy()
        .into_owned()
}
// The probe-to-launch handoff can lose a port; only port failures are retried.
fn launch_retry<T>(
    root: &Path,
    name: &str,
    size: u64,
    extra: &str,
    mut launch: impl FnMut(PathBuf, u64, &str) -> Result<T>,
    mut pause: impl FnMut(),
) -> Result<(T, Vec<String>)> {
    let mut errors = Vec::new();
    for attempt in 0..20 {
        match launch(root.join(format!("{name}-{attempt}")), size, extra) {
            Ok(node) => return Ok((node, errors)),
            Err(error) => {
                let retry = [
                    "Unable to bind",
                    "Address already in use",
                    "Failed to listen",
                    "no free RPC/P2P pair",
                    "Unable to start HTTP server",
                ]
                .iter()
                .any(|message| error.contains(message));
                if !retry {
                    return Err(error);
                }
                errors.push(error);
                if attempt < 19 {
                    pause();
                }
            }
        }
    }
    Err(format!("startup retries exhausted: {errors:?}"))
}
pub(super) fn start_retry_size(root: &Path, name: &str, size: u64, extra: &str) -> Result<Node> {
    start_retry_build(root, name, size, extra, Build::Record)
}
pub(super) fn start_retry_build(
    root: &Path,
    name: &str,
    size: u64,
    extra: &str,
    build: Build,
) -> Result<Node> {
    let launch = |dir, size, extra: &str| Node::start_on(dir, size, extra, build);
    let (mut node, errors) = launch_retry(root, name, size, extra, launch, || {
        thread::sleep(Duration::from_millis(100))
    })?;
    node.calls
        .push(json!({"startup_attempts":errors.len()+1,"earlier_launch_errors":errors}));
    Ok(node)
}
pub(super) fn start_retry(root: &Path, name: &str, extra: &str) -> Result<Node> {
    start_retry_size(root, name, 1_000_001, extra)
}
pub(super) fn write_json(path: &Path, v: &Value) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    let temp = path.with_extension("json.tmp");
    fs::write(
        &temp,
        format!(
            "{}\n",
            serde_json::to_string_pretty(v).or_err("serde_json::to_string_pretty(v)")?
        ),
    )
    .map_err(|e| e.to_string())?;
    fs::rename(temp, path).map_err(|e| e.to_string())
}
pub(super) fn text(v: &Value) -> Result<&str> {
    v.as_str().ok_or_else(|| format!("expected string: {v}"))
}
pub(super) fn id(tx: &RawTx) -> String {
    txid_display_hex(&tx.txid_internal())
}
#[allow(
    clippy::expect_used,
    reason = "sha256 of a fixed label is a valid secp256k1 scalar, checked by every scenario run's signature"
)]
pub(super) fn key() -> bsv_rs::primitives::ec::PrivateKey {
    bsv_rs::primitives::ec::PrivateKey::from_bytes(&bsv_rs::primitives::hash::sha256(
        b"bsv-script-lean/s6-66/mining",
    ))
    .expect("the scenario key from sha256 of its fixed label")
}
pub(super) fn script() -> Vec<u8> {
    [
        vec![0x76, 0xa9, 0x14],
        hash160(&key().public_key().to_compressed()).to_vec(),
        vec![0x88, 0xac],
    ]
    .concat()
}
pub(super) fn base58(version: u8, payload: &[u8]) -> String {
    let mut bytes = [vec![version], payload.to_vec()].concat();
    let check = bsv_script_harness::txraw::sha256d(&bytes);
    bytes.extend_from_slice(&check[..4]);
    let mut digits = vec![0u32];
    for byte in bytes {
        let mut carry = byte as u32;
        for d in &mut digits {
            carry += *d * 256;
            *d = carry % 58;
            carry /= 58;
        }
        while carry > 0 {
            digits.push(carry % 58);
            carry /= 58;
        }
    }
    digits
        .iter()
        .rev()
        .map(|d| b"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"[*d as usize] as char)
        .collect()
}
pub(super) fn address() -> String {
    base58(0x6f, &hash160(&key().public_key().to_compressed()))
}
pub(super) fn spend(parent: &RawTx, value: u64, version: i32) -> RawTx {
    spend_to(parent, value, version, script())
}
pub(super) fn spend_to(parent: &RawTx, value: u64, version: i32, lock: Vec<u8>) -> RawTx {
    spend_locked(parent, value, version, lock, 0, u32::MAX)
}
// [D] 2026-10-15 (#81, lane s7-81): the spend of output 0 with a chosen lock
// time and input sequence, signed over both (SIGHASH_ALL|FORKID); `spend_to`
// is its final, unlocked case. The signer's allow moved here with it.
#[allow(
    clippy::expect_used,
    reason = "the scenario key is a fixed valid scalar; the signer refuses only a zero or out-of-range digest scalar"
)]
pub(super) fn spend_locked(
    parent: &RawTx,
    value: u64,
    version: i32,
    lock: Vec<u8>,
    lock_time: u32,
    sequence: u32,
) -> RawTx {
    use bsv_rs::primitives::bsv::sighash::{
        compute_sighash_for_signing, SighashParams, TxInput, TxOutput,
    };
    let mut tx = RawTx {
        version,
        inputs: vec![RawInput {
            txid: parent.txid_internal(),
            vout: 0,
            script: vec![],
            sequence,
        }],
        outputs: vec![RawOutput {
            satoshis: value,
            script: lock.clone(),
        }],
        lock_time,
    };
    let inputs = vec![TxInput {
        txid: parent.txid_internal(),
        output_index: 0,
        script: vec![],
        sequence,
    }];
    let outputs = vec![TxOutput {
        satoshis: value,
        script: lock.clone(),
    }];
    let digest = compute_sighash_for_signing(&SighashParams {
        version,
        inputs: &inputs,
        outputs: &outputs,
        locktime: lock_time,
        input_index: 0,
        subscript: &parent.outputs[0].script,
        satoshis: parent.outputs[0].satoshis,
        scope: 0x41,
    });
    let signature = key().sign(&digest).expect("key().sign(&digest)");
    pub(super) fn integer(x: &[u8; 32]) -> Vec<u8> {
        let mut b: Vec<u8> = x.iter().copied().skip_while(|v| *v == 0).collect();
        if b.is_empty() {
            b.push(0);
        }
        if b[0] & 128 != 0 {
            b.insert(0, 0);
        }
        let mut v = vec![2, b.len() as u8];
        v.extend(b);
        v
    }
    let payload = [integer(signature.r()), integer(signature.s())].concat();
    let mut der = vec![0x30, payload.len() as u8];
    der.extend(payload);
    der.push(0x41);
    bsv_script_harness::gen::push_min(&mut tx.inputs[0].script, &der);
    bsv_script_harness::gen::push_min(
        &mut tx.inputs[0].script,
        &key().public_key().to_compressed(),
    );
    tx
}
// Injectable child control exercises cleanup faults without starting a process.
pub(super) trait ChildControl {
    fn try_wait(&mut self) -> std::io::Result<Option<std::process::ExitStatus>>;
    fn kill(&mut self) -> std::io::Result<()>;
    fn wait(&mut self) -> std::io::Result<std::process::ExitStatus>;
}
impl ChildControl for Child {
    fn try_wait(&mut self) -> std::io::Result<Option<std::process::ExitStatus>> {
        Child::try_wait(self)
    }
    fn kill(&mut self) -> std::io::Result<()> {
        Child::kill(self)
    }
    fn wait(&mut self) -> std::io::Result<std::process::ExitStatus> {
        Child::wait(self)
    }
}
// Each child belongs to this invocation. Drop cannot address any other instance.
pub(super) struct Node<C: ChildControl = Child> {
    pub(super) child: C,
    pub(super) rpc: Option<Rpc>,
    pub(super) dir: PathBuf,
    pub(super) calls: Vec<Value>,
    pub(super) conf: String,
    pub(super) stopped: bool,
    pub(super) seen: BTreeSet<String>,
    // [D] 2026-10-13 (#72): the last mock time this instance was set to.
    pub(super) clock: u64,
    // [D] 2026-10-14 (#121): the binary this instance was started on; a restart keeps it.
    pub(super) build: Build,
}
impl Node {
    pub(super) fn start(dir: PathBuf, size: u64, extra: &str) -> Result<Self> {
        Self::start_on(dir, size, extra, Build::Record)
    }
    pub(super) fn start_on(dir: PathBuf, size: u64, extra: &str, build: Build) -> Result<Self> {
        let binary = build.path()?;
        // [D] 2026-10-13: sample the Studio load before every fresh instance.
        let load_sample = loop {
            let sample = Command::new("python3")
                .args(["-c", "import os; print(os.getloadavg()[0])"])
                .output()
                .map_err(|e| e.to_string())?;
            let value = String::from_utf8_lossy(&sample.stdout)
                .trim()
                .parse::<f64>()
                .map_err(|e| e.to_string())?;
            if value < 20.0 {
                break value;
            }
            println!("node-scenarios: waiting for load below 20; sampled [M] {value}");
            if INTERRUPTED.load(std::sync::atomic::Ordering::Relaxed) {
                return Err("interrupted before launch".into());
            }
            thread::sleep(Duration::from_secs(5));
        };
        fs::create_dir(&dir)
            .map_err(|e| format!("fresh datadir {}: {e}", instance_pointer(&dir)))?;
        let mut selected = None;
        for port in 18571..=18589 {
            if let (Ok(a), Ok(b)) = (
                TcpListener::bind(("127.0.0.1", port)),
                TcpListener::bind(("127.0.0.1", port + 1)),
            ) {
                selected = Some((port, a, b));
                break;
            }
        }
        let (port, a, b) = selected.ok_or("no free RPC/P2P pair in 18571..18590")?;
        // [D] 2026-10-13: bind the peer to this reserved instance port.
        let extra = extra.replace("{P2P_PORT}", &(port + 1).to_string());
        // [D] 2026-10-15 (#84): a third loopback port in the same range for the
        // notifiers' PUB socket, held with the pair until the launch.
        let zmq = if extra.contains("{ZMQ_PORT}") {
            let (zmq_port, held) = (18571..=18590)
                .filter(|p| *p != port && *p != port + 1)
                .find_map(|p| TcpListener::bind(("127.0.0.1", p)).ok().map(|l| (p, l)))
                .ok_or("no free ZMQ port in 18571..18590")?;
            Some((zmq_port, held))
        } else {
            None
        };
        let extra = match &zmq {
            Some((zmq_port, _)) => extra.replace("{ZMQ_PORT}", &zmq_port.to_string()),
            None => extra,
        };
        let override_keys: BTreeSet<&str> = extra
            .lines()
            .filter_map(|line| line.split_once('=').map(|(key, _)| key))
            .collect();
        let base = include_str!("../../oracle/scenarios.conf")
            .lines()
            .filter(|line| {
                !line
                    .split_once('=')
                    .is_some_and(|(key, _)| override_keys.contains(key))
            })
            .collect::<Vec<_>>()
            .join("\n");
        let conf = format!(
            "{}\nrpcport={port}\nport={}\nexcessiveblocksize={size}\n{extra}",
            base,
            port + 1
        );
        fs::write(dir.join("bitcoin.conf"), &conf).map_err(|e| e.to_string())?;
        drop((a, b, zmq));
        let child = Command::new(&binary)
            .arg(format!("-datadir={}", dir.display()))
            .arg(format!("-conf={}", dir.join("bitcoin.conf").display()))
            .stdout(fs::File::create(dir.join("console.log")).map_err(|e| e.to_string())?)
            .stderr(fs::File::create(dir.join("bitcoind.err")).map_err(|e| e.to_string())?)
            .spawn()
            .map_err(|e| e.to_string())?;
        let mut n = Self {
            child,
            rpc: None,
            dir,
            calls: vec![json!({"date":"2026-10-13","label":"[M]","studio_load_1m":load_sample})],
            conf,
            stopped: false,
            seen: BTreeSet::new(),
            clock: START_CLOCK,
            build,
        };
        if build != Build::Record {
            let home = PathBuf::from(std::env::var("HOME").map_err(|e| e.to_string())?);
            let shown = binary.strip_prefix(&home).map_or_else(
                |_| binary.display().to_string(),
                |p| format!("~/{}", p.display()),
            );
            n.calls.push(json!({"lifecycle":"binary","build":build.name(),"binary":shown,"source":format!("docs/PROVENANCE.md 1a {}", build.pin_key())}));
        }
        let start = Instant::now();
        while start.elapsed() < Duration::from_secs(30) {
            if INTERRUPTED.load(std::sync::atomic::Ordering::Relaxed) {
                return Err("interrupted during startup".into());
            }
            if let Some(status) = n.child.try_wait().map_err(|e| e.to_string())? {
                return Err(format!(
                    "launch exit {status}: {}",
                    fs::read_to_string(n.dir.join("bitcoind.err")).unwrap_or_default()
                ));
            }
            if let Ok(mut rpc) = Rpc::new(
                &format!("http://127.0.0.1:{port}"),
                &n.dir.join("regtest/.cookie").to_string_lossy(),
                Duration::from_secs(30),
            ) {
                if rpc.call("getbestblockhash", json!([])).is_ok() {
                    n.rpc = Some(rpc);
                    n.clock_receipt(START_CLOCK)?;
                    return Ok(n);
                }
            }
            thread::sleep(Duration::from_millis(100));
        }
        Err("node startup timeout".into())
    }
    // Stop this instance and start it again on its own datadir, as the
    // reference's suite does between steps (test/functional/
    // soft_consensus_freeze_base.py `restart_node`; bsv-missing-parent-block-
    // data-on-restart.py) at PIN. A fresh loopback port pair is written before
    // the relaunch; the console and error logs are appended, never truncated.
    pub(super) fn restart(&mut self) -> Result<()> {
        self.stop()?;
        self.relaunch()
    }
    // (S3, lane fix-pend2, Claude Opus 5.5, [M] 2026-10-13) Stop, edit this
    // instance's own data directory while it is down, and relaunch with the
    // extra settings appended. The reference's suite edits a stopped node's
    // datadir the same way (test/functional/walletbackup.py:165-167,190-191
    // delete chainstate between stop and start) at PIN. The edit's receipt is
    // kept in the lifecycle entry.
    pub(super) fn restart_edited(
        &mut self,
        extra: &str,
        edit: impl FnOnce(&Path) -> Result<Value>,
    ) -> Result<Value> {
        self.stop()?;
        let receipt = edit(&self.dir)?;
        self.calls.push(json!({"lifecycle":"datadir-edit","edit":receipt,"extra":extra,"source":format!("[SRC] test/functional/walletbackup.py:165-167,190-191 at {PIN}")}));
        if !extra.is_empty() {
            self.conf = format!("{}\n{}", self.conf.trim_end(), extra.trim_end());
        }
        self.relaunch()?;
        Ok(receipt)
    }
    fn relaunch(&mut self) -> Result<()> {
        let mut selected = None;
        for port in 18571..=18589 {
            if let (Ok(a), Ok(b)) = (
                TcpListener::bind(("127.0.0.1", port)),
                TcpListener::bind(("127.0.0.1", port + 1)),
            ) {
                selected = Some((port, a, b));
                break;
            }
        }
        let (port, a, b) = selected.ok_or("no free RPC/P2P pair in 18571..18590")?;
        let conf = self
            .conf
            .lines()
            .map(|line| {
                if line.starts_with("rpcport=") {
                    format!("rpcport={port}")
                } else if line.starts_with("port=") {
                    format!("port={}", port + 1)
                } else {
                    line.to_owned()
                }
            })
            .collect::<Vec<_>>()
            .join("\n");
        fs::write(self.dir.join("bitcoin.conf"), &conf).map_err(|e| e.to_string())?;
        let append = |name: &str| {
            fs::OpenOptions::new()
                .append(true)
                .open(self.dir.join(name))
                .map_err(|e| e.to_string())
        };
        let (out, err) = (append("console.log")?, append("bitcoind.err")?);
        let binary = self.build.path()?;
        drop((a, b));
        self.child = Command::new(binary)
            .arg(format!("-datadir={}", self.dir.display()))
            .arg(format!("-conf={}", self.dir.join("bitcoin.conf").display()))
            .stdout(out)
            .stderr(err)
            .spawn()
            .map_err(|e| e.to_string())?;
        self.stopped = false;
        self.rpc = None;
        self.conf = conf;
        self.calls.push(json!({"lifecycle":"restart","rpcport":port,"source":"[SRC] test/functional/soft_consensus_freeze_base.py restart_node at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"}));
        let start = Instant::now();
        while start.elapsed() < Duration::from_secs(60) {
            if INTERRUPTED.load(std::sync::atomic::Ordering::Relaxed) {
                return Err("interrupted during restart".into());
            }
            if let Some(status) = self.child.try_wait().map_err(|e| e.to_string())? {
                self.stopped = true;
                return Err(format!("restart exit {status}"));
            }
            if let Ok(mut rpc) = Rpc::new(
                &format!("http://127.0.0.1:{port}"),
                &self.dir.join("regtest/.cookie").to_string_lossy(),
                Duration::from_secs(30),
            ) {
                if rpc.call("getbestblockhash", json!([])).is_ok() {
                    self.rpc = Some(rpc);
                    // [D] 2026-10-13 (#72): a relaunch resets nMockTime to
                    // zero, so the scenario's clock is set again before any step.
                    return self.clock_receipt(self.clock);
                }
            }
            thread::sleep(Duration::from_millis(100));
        }
        Err("node restart timeout".into())
    }
}
impl<C: ChildControl> Node<C> {
    pub(super) fn call(&mut self, method: &str, params: Value) -> Result<Value> {
        if method != "stop" && INTERRUPTED.load(std::sync::atomic::Ordering::Relaxed) {
            return Err("interrupted; stopping owned instance".into());
        }
        let reply = self
            .rpc
            .as_mut()
            .ok_or("RPC not ready")?
            .call(method, params.clone());
        let raw = match &reply {
            Ok(v) => json!({"result":v}),
            Err(e) => {
                json!({"error":e.strip_prefix("rpc error: ").and_then(|s| serde_json::from_str::<Value>(s).ok()).unwrap_or(json!({"transport":e}))})
            }
        };
        self.calls.push(json!({"method":method,"params":params,"source":format!("[SRC] {} at {PIN}",handler(method)?),"reply":raw,"instance_id":instance_pointer(&self.dir)}));
        if method == "setmocktime" && reply.is_ok() {
            self.clock = params[0].as_u64().unwrap_or(self.clock);
        }
        reply
    }
    // [X] 2026-10-13 (#72): set the scenario clock and observe the adjusted
    // time's offset. GetAdjustedTime is GetTime plus nTimeOffset
    // (src/timedata.cpp:28-35); getnetworkinfo reports that offset
    // (src/rpc/net.cpp:626). The offset moves only after five peer samples
    // (src/timedata.cpp:74-82); a value other than zero makes every
    // adjusted-time observation of the instance non-judging.
    pub(super) fn clock_receipt(&mut self, clock: u64) -> Result<()> {
        self.call("setmocktime", json!([clock]))?;
        let offset = self.time_offset()?;
        self.calls.push(json!({"event":"clock","label":"[X]","mock_time":clock,"timeoffset":offset,
            "source":format!("[SRC] src/utiltime.cpp:23-33; src/timedata.cpp:28-35; src/rpc/net.cpp:626 at {PIN}")}));
        Ok(())
    }
    pub(super) fn time_offset(&mut self) -> Result<i64> {
        self.call("getnetworkinfo", json!([]))?["timeoffset"]
            .as_i64()
            .ok_or_else(|| "getnetworkinfo timeoffset absent".into())
    }
    pub(super) fn receipt(&mut self, method: &str, params: Value) -> Result<Value> {
        match self.call(method, params) {
            Ok(v) => Ok(json!({"result":v})),
            Err(e) => match e
                .strip_prefix("rpc error: ")
                .and_then(|s| serde_json::from_str::<Value>(s).ok())
            {
                Some(error) => Ok(json!({"error":error})),
                None => Err(e),
            },
        }
    }
    pub(super) fn stop(&mut self) -> Result<()> {
        if self.stopped {
            return Ok(());
        }
        if self.rpc.is_some() {
            let _ = self.call("stop", json!([]));
        }
        let start = Instant::now();
        let mut failure = "owned child needed forced termination".to_owned();
        while start.elapsed() < Duration::from_secs(30) {
            match self.child.try_wait() {
                Ok(Some(_)) => {
                    self.stopped = true;
                    return Ok(());
                }
                Ok(None) => thread::sleep(Duration::from_millis(100)),
                Err(error) => {
                    failure = format!("owned child try_wait: {error}");
                    break;
                }
            }
        }
        // A failed kill must never skip wait. A successful reap is remembered
        // even when the earlier control operation failed.
        let killed = self.child.kill();
        let waited = self.child.wait();
        self.stopped = waited.is_ok();
        if let Err(error) = killed {
            failure.push_str(&format!("; kill: {error}"));
        }
        if let Err(error) = waited {
            failure.push_str(&format!("; wait: {error}"));
        }
        Err(failure)
    }
    pub(super) fn tip(&mut self) -> Result<Value> {
        let hash = self.call("getbestblockhash", json!([]))?;
        self.call("getblock", json!([hash, 1]))
    }
    // [X] 2026-10-13 (#72): the block is the node's choice, observed, never
    // predicted. generatetoaddress returns hashes only (src/rpc/mining.cpp:
    // 161-224); the assembler copies its journal's transactions
    // (src/mining/journaling_block_assembler.cpp:80-97). The chain's
    // transaction count before and after (getchaintxstats `txcount`,
    // src/rpc/blockchain.cpp:3117,3144) observes how many transactions the
    // node put in the new blocks; when that is more than one coinbase per
    // block, every body is read. The `assembly` event carries the bodies.
    pub(super) fn mine(&mut self, count: u64, time: u64) -> Result<Vec<Value>> {
        self.call("setmocktime", json!([time]))?;
        let before = self.call("getchaintxstats", json!([0]))?["txcount"]
            .as_u64()
            .ok_or("chain txcount before mining")?;
        let hashes = self.call("generatetoaddress", json!([count, address()]))?;
        let hashes = hashes.as_array().ok_or("bad generated hashes")?.clone();
        if hashes.len() != count as usize {
            return Err("incomplete mining".into());
        }
        let Some(last) = hashes.last().cloned() else {
            return Ok(hashes);
        };
        let after = self.call("getchaintxstats", json!([0, last]))?["txcount"]
            .as_u64()
            .ok_or("chain txcount after mining")?;
        let transactions = after.checked_sub(before).ok_or("chain txcount fell")?;
        let mut bodies = vec![];
        if transactions != count {
            for hash in &hashes {
                let txids = self.body(hash)?;
                if !txids.is_empty() {
                    bodies.push(json!({"hash":hash,"transactions":txids}));
                }
            }
        }
        self.calls.push(json!({"event":"assembly","label":"[X]","blocks":count,"transactions":transactions,
            "coinbase_only":transactions == count,"observed_bodies":bodies,
            "source":format!("[SRC] src/rpc/mining.cpp:161-224; src/mining/journaling_block_assembler.cpp:80-97; src/rpc/blockchain.cpp:3054-3155 at {PIN}")}));
        Ok(hashes)
    }
    // [X] 2026-10-13 (#72): the observed body of a block, coinbase excluded,
    // in the node's order (getblock verbosity 1, src/rpc/blockchain.cpp:1108-1242).
    pub(super) fn body(&mut self, hash: &Value) -> Result<Vec<String>> {
        let block = self.call("getblock", json!([hash, 1]))?;
        let txs = block["tx"].as_array().ok_or("block transactions")?;
        txs.iter()
            .skip(1)
            .map(|t| text(t).map(str::to_owned))
            .collect()
    }
    pub(super) fn raw_tx(&mut self, txid: &Value) -> Result<RawTx> {
        let raw = self.call("getrawtransaction", json!([txid, 0]))?;
        RawTx::decode(&hex::decode(text(&raw)?).map_err(|e| e.to_string())?)
    }
    pub(super) fn block_bytes(&mut self, txs: &[RawTx], time: u32) -> Result<(String, Vec<u8>)> {
        let tip = self.tip()?;
        let (h, b) = block_codec::assemble(
            4,
            txid_from_display_hex(text(&tip["hash"])?)?,
            time,
            u32::from_str_radix(text(&tip["bits"])?, 16).map_err(|e| e.to_string())?,
            txs,
        );
        Ok((txid_display_hex(&h.hash()), b))
    }
    pub(super) fn submit(&mut self, txs: &[RawTx], time: u32) -> Result<(String, Value)> {
        self.call("setmocktime", json!([time]))?;
        let (hash, bytes) = self.block_bytes(txs, time)?;
        let receipt = self.receipt("submitblock", json!([hex::encode(bytes)]))?;
        Ok((hash, receipt))
    }
}
impl<C: ChildControl> Drop for Node<C> {
    fn drop(&mut self) {
        if !self.stopped && self.stop().is_err() {
            let _ = self.child.kill();
            let _ = self.child.wait();
        }
    }
}
// [D] 2026-10-15 (#84, lane events-84): a subscriber for the reference's ZMQ
// notifiers, recording every message an instance publishes. It speaks the
// ZMTP 3.0 NULL mechanism's SUB half over the loopback (rfc.zeromq.org/spec/23:
// the 64-byte greeting, a READY command naming Socket-Type SUB, then the
// subscription message 0x01 with the empty prefix, which matches every topic).
// The node's PUB socket binds the address of each `-zmqpub<topic>` option and
// shares it among them ([SRC] src/zmq/zmqpublishnotifier.cpp:38-72 at PIN); a
// message is three frames: the topic, the body and a 4-byte little-endian
// sequence number per notifier (zmqpublishnotifier.h:20-25,
// zmqpublishnotifier.cpp:109-112; the little-endian write src/zmq/zmq_publisher.cpp:124-127).
#[derive(Clone, Debug)]
pub(super) struct ZmqMessage {
    pub(super) index: usize,
    pub(super) topic: String,
    pub(super) body: Vec<u8>,
    pub(super) sequence: Option<u32>,
    pub(super) frames: usize,
}
pub(super) struct Subscriber {
    stream: std::net::TcpStream,
    log: std::sync::Arc<std::sync::Mutex<Vec<ZmqMessage>>>,
    reader: Option<thread::JoinHandle<String>>,
    pub(super) handshake: Value,
}
fn zmtp_greeting() -> [u8; 64] {
    let mut g = [0u8; 64];
    g[0] = 0xff;
    g[9] = 0x7f;
    g[10] = 3;
    g[12..16].copy_from_slice(b"NULL");
    g
}
fn zmtp_frame(flags: u8, body: &[u8]) -> Vec<u8> {
    let mut out = vec![flags];
    out.push(body.len() as u8);
    out.extend(body);
    out
}
fn zmtp_read_frame(s: &mut impl std::io::Read) -> std::io::Result<(u8, Vec<u8>)> {
    let mut flags = [0u8; 1];
    s.read_exact(&mut flags)?;
    let size = if flags[0] & 0x02 != 0 {
        let mut b = [0u8; 8];
        s.read_exact(&mut b)?;
        u64::from_be_bytes(b) as usize
    } else {
        let mut b = [0u8; 1];
        s.read_exact(&mut b)?;
        b[0] as usize
    };
    let mut body = vec![0u8; size];
    s.read_exact(&mut body)?;
    Ok((flags[0], body))
}
// One multipart message: frames until one without the MORE flag. A command
// frame (flag 0x04) outside the handshake is returned as its own message.
fn zmtp_read_message(s: &mut impl std::io::Read) -> std::io::Result<Vec<Vec<u8>>> {
    let mut frames = vec![];
    loop {
        let (flags, body) = zmtp_read_frame(s)?;
        frames.push(body);
        if flags & 0x01 == 0 {
            return Ok(frames);
        }
    }
}
impl Subscriber {
    pub(super) fn connect(port: u16) -> Result<Self> {
        use std::io::{Read, Write};
        let mut stream =
            std::net::TcpStream::connect(("127.0.0.1", port)).map_err(|e| e.to_string())?;
        stream
            .set_read_timeout(Some(Duration::from_secs(10)))
            .map_err(|e| e.to_string())?;
        stream
            .write_all(&zmtp_greeting())
            .map_err(|e| e.to_string())?;
        let mut peer = [0u8; 64];
        stream.read_exact(&mut peer).map_err(|e| e.to_string())?;
        if peer[0] != 0xff || peer[9] != 0x7f || &peer[12..16] != b"NULL" {
            return Err(format!("zmtp greeting: {}", hex::encode(peer)));
        }
        let mut ready = vec![5];
        ready.extend(b"READY");
        ready.push(11);
        ready.extend(b"Socket-Type");
        ready.extend(3u32.to_be_bytes());
        ready.extend(b"SUB");
        stream
            .write_all(&zmtp_frame(0x04, &ready))
            .map_err(|e| e.to_string())?;
        let (flags, command) = zmtp_read_frame(&mut stream).map_err(|e| e.to_string())?;
        if flags & 0x04 == 0 || !command.starts_with(b"\x05READY") {
            return Err(format!("zmtp ready: {}", hex::encode(&command)));
        }
        stream
            .write_all(&zmtp_frame(0x00, &[0x01]))
            .map_err(|e| e.to_string())?;
        stream.set_read_timeout(None).map_err(|e| e.to_string())?;
        let handshake = json!({"label":"[X]","peer_version":[peer[10],peer[11]],"peer_mechanism":String::from_utf8_lossy(&peer[12..32]).trim_end_matches('\0'),
            "peer_ready":hex::encode(&command),"subscription":"01 (the empty prefix)","port":port});
        let log = std::sync::Arc::new(std::sync::Mutex::new(Vec::new()));
        let (mut reading, sink) = (
            stream.try_clone().map_err(|e| e.to_string())?,
            std::sync::Arc::clone(&log),
        );
        let reader = thread::spawn(move || loop {
            match zmtp_read_message(&mut reading) {
                Ok(mut frames) => {
                    let Ok(mut log) = sink.lock() else {
                        return "subscriber log poisoned".to_owned();
                    };
                    let count = frames.len();
                    let sequence = frames
                        .get(2)
                        .and_then(|s| <[u8; 4]>::try_from(s.as_slice()).ok())
                        .map(u32::from_le_bytes);
                    let body = if count > 1 {
                        frames.swap_remove(1)
                    } else {
                        vec![]
                    };
                    let topic =
                        String::from_utf8_lossy(frames.first().map_or(&[][..], |t| t)).into_owned();
                    let index = log.len();
                    log.push(ZmqMessage {
                        index,
                        topic,
                        body,
                        sequence,
                        frames: count,
                    });
                }
                Err(e) => return e.to_string(),
            }
        });
        Ok(Self {
            stream,
            log,
            reader: Some(reader),
            handshake,
        })
    }
    // The count once no message has arrived for `quiet`; publication is
    // asynchronous (src/zmq/zmq_publisher.cpp; the invalid-transaction
    // publisher's own thread, src/invalid_txn_publisher.cpp:214-235 at PIN).
    pub(super) fn settle(&self, quiet: Duration, limit: Duration) -> Result<usize> {
        let start = Instant::now();
        let mut last = (self.count()?, Instant::now());
        while start.elapsed() < limit {
            thread::sleep(Duration::from_millis(100));
            let now = self.count()?;
            if now != last.0 {
                last = (now, Instant::now());
            } else if last.1.elapsed() >= quiet {
                return Ok(now);
            }
        }
        Err(format!("subscriber did not settle within {limit:?}"))
    }
    pub(super) fn count(&self) -> Result<usize> {
        Ok(self.log.lock().map_err(|e| e.to_string())?.len())
    }
    pub(super) fn since(&self, start: usize) -> Result<Vec<ZmqMessage>> {
        Ok(self.log.lock().map_err(|e| e.to_string())?[start..].to_vec())
    }
    // Close the socket and return the reader's ending.
    pub(super) fn close(mut self) -> Result<String> {
        let _ = self.stream.shutdown(std::net::Shutdown::Both);
        match self.reader.take().map(thread::JoinHandle::join) {
            Some(Ok(ending)) => Ok(ending),
            Some(Err(_)) => Err("subscriber reader panicked".into()),
            None => Ok(String::new()),
        }
    }
}
#[derive(Default, Debug)]
pub(super) struct Evidence {
    pub(super) active_heights: Vec<u64>,
    pub(super) accepted: bool,
    pub(super) held: bool,
    pub(super) isolated_orphan: bool,
    pub(super) stale: bool,
    pub(super) exact_active_conflict: bool,
    pub(super) rejection: Option<Value>,
}
#[allow(
    clippy::expect_used,
    reason = "a rejection is always recorded as a JSON object by the scenario's own projection"
)]
pub(super) fn status(e: &Evidence) -> Value {
    if let Some(h) = e.active_heights.iter().max() {
        json!({"value":"minedActive","height":h})
    } else if e.accepted {
        json!({"value":"inMempool"})
    } else if e.held {
        json!({"value":"heldNonFinal"})
    } else if e.isolated_orphan {
        json!({"value":"orphan"})
    } else if e.stale {
        json!({"value":"onStaleBranch"})
    } else if e.exact_active_conflict {
        json!({"value":"conflictedByMinedSpend"})
    } else if let Some(r) = &e.rejection {
        let mut result = r.clone();
        result
            .as_object_mut()
            .expect("result.as_object_mut()")
            .remove("status");
        result["value"] = json!("rejected");
        result
    } else {
        json!({"value":"unknown"})
    }
}
pub(super) fn node_reject(receipt: &Value) -> Option<Value> {
    let err = receipt.get("error")?;
    let message = err["message"].as_str()?;
    if err["code"] == -26 {
        if let Some((code, reason)) = message.split_once(": ") {
            if let Ok(code) = code.parse::<u64>() {
                return Some(
                    json!({"status":"rejected","namespace":"node","code":code,"reason":reason}),
                );
            }
        }
    }
    Some(json!({"status":"rejected","namespace":"rpc","code":err["code"],"reason":message}))
}
pub(super) fn compare(expected: &Value, observed: &Value) -> bool {
    expected == observed
}
// R6: submitblock omits parallel script-error detail, but preserves the reason
// code. [SRC] src/validation.cpp:3690-3715 at 6504a3af. All other fields stay exact.
fn block_reason_detail(expected: &Value, observed: &Value) -> Option<String> {
    if expected["status"] != "rejected" || observed["status"] != "rejected" {
        return None;
    }
    let (code, detail) = expected["reason"].as_str()?.split_once(" (")?;
    if code.is_empty() || !detail.ends_with(')') || observed["reason"] != code {
        return None;
    }
    let mut projected = expected.clone();
    projected["reason"] = json!(code);
    compare(&projected, observed).then(|| detail[..detail.len() - 1].to_string())
}

#[allow(
    clippy::expect_used,
    reason = "the measurement's UTC date comes from date(1), present on every host that runs a node; its absence stops the run with the message"
)]
pub(super) fn measured_token(row: &Value, record: &str) -> String {
    let date = Command::new("date")
        .args(["-u", "+%Y-%m-%d"])
        .output()
        .expect("measurement UTC date");
    assert!(date.status.success(), "measurement UTC date failed");
    measured_token_dated(row, record, String::from_utf8_lossy(&date.stdout).trim())
}

#[allow(
    clippy::expect_used,
    reason = "a measured token is cut only from a row its family already projected with these fields; a missing one is a fixture bug the message names"
)]
pub(super) fn measured_token_dated(row: &Value, record: &str, date: &str) -> String {
    // [D] 2026-10-14 (#121): a row measured on a binary other than the node of
    // record names that binary in its token, e.g. `measured agree (wallet build): `.
    let build = row["build"]
        .as_str()
        .map(|b| format!(" ({b})"))
        .unwrap_or_default();
    if row["classification"] == "observation limit (reason detail)" {
        format!("measured agree{build}: rejected {} (detail not surfaced by submitblock: src/validation.cpp:3690-3715) [M] {date} [X] {record}", row["observed"]["reason"].as_str().expect("row['observed']['reason'].as_str()"))
    } else if row["classification"] == "scope limit" {
        format!("measured agree{build}: rejected 259 non-final-pool-full (scope: full admission; the isolated stage says heldNonFinal) [M] {date} [X] {record}")
    } else {
        // A recipe's dated qualifier (its instrument, or an open item of its
        // record) rides inside the measured token, before the record pointer.
        let qualifier = row["qualifier"]
            .as_str()
            .map(|q| format!(" [{q}]"))
            .unwrap_or_default();
        format!(
            "measured {}{build}: {}{qualifier} [M] {date} [X] {record}",
            row["verdict"].as_str().expect("row['verdict'].as_str()"),
            row["observed"]
        )
    }
}
pub(super) fn block_judgment(receipt: &Value) -> Value {
    if receipt.get("error").is_some() {
        return json!({"status":"rpc-error","error":receipt["error"]});
    }
    if receipt["result"].is_null() {
        json!({"status":"ok"})
    } else {
        json!({"status":"rejected","reason":receipt["result"]})
    }
}
pub(super) fn block_expect(row: &Value) -> Value {
    let e = &row["expected"];
    if e["status"] == "ok" {
        json!({"status":"ok"})
    } else {
        json!({"status":e["status"],"reason":e["reason"]})
    }
}
pub(super) fn row_read(family: &str) -> Result<Vec<Value>> {
    fs::read_to_string(format!("corpus/chain/{family}/{family}.jsonl"))
        .map_err(|e| e.to_string())?
        .lines()
        .map(|s| serde_json::from_str(s).map_err(|e| e.to_string()))
        .collect()
}
pub(super) fn material(tx: &RawTx) -> Value {
    json!({"txid":id(tx),"hex":hex::encode(tx.encode())})
}
pub(super) fn cb(height: u32, tag: &str) -> RawTx {
    block_codec::coinbase_tx(height, 0, script(), tag.as_bytes())
}
pub(super) fn seed(n: &mut Node) -> Result<(RawTx, RawTx, String)> {
    let mut hashes = vec![];
    for h in 1..=100 {
        hashes.extend(n.mine(1, 1_699_990_000 + h)?);
    }
    for hash in &hashes {
        n.call("getblock", json!([hash, 0]))?;
    }
    let b = n.call("getblock", json!([hashes[0], 1]))?;
    let coin = n.raw_tx(&b["tx"][0])?;
    let f = spend(&coin, 100000, 1);
    let (hash, receipt) = n.submit(&[cb(101, "base"), f.clone()], 1_699_999_999)?;
    if block_judgment(&receipt) != json!({"status":"ok"}) {
        return Err(format!("funding block: {receipt}"));
    }
    let t = spend(&f, 99000, 1);
    Ok((f, t, hash))
}
pub(super) fn mark_rows(family: &str, marks: &BTreeMap<String, String>) -> Result<()> {
    let path = format!("corpus/chain/{family}/{family}.jsonl");
    let raw = fs::read_to_string(&path).map_err(|e| e.to_string())?;
    let mut out = String::new();
    for line in raw.split_inclusive('\n') {
        let row: Value = serde_json::from_str(line).map_err(|e| e.to_string())?;
        if let Some(mark) = marks.get(text(&row["id"])?) {
            if let Some(old) = row["node"].as_str() {
                out.push_str(&replace_node(line, old, mark)?);
            } else {
                let end = line.rfind('}').ok_or("row object end absent")?;
                out.push_str(&format!(
                    "{},\"node\":{}{}",
                    &line[..end],
                    serde_json::to_string(mark).or_err("serde_json::to_string(mark)")?,
                    &line[end..]
                ));
            }
        } else {
            out.push_str(line);
        }
    }
    fs::write(path, out).map_err(|e| e.to_string())
}
// Change only the value token, retaining every unrelated byte of a row.
pub(super) fn replace_node(raw: &str, old: &str, new: &str) -> Result<String> {
    let start = raw.find("\"node\"").ok_or("node key absent")? + 6;
    let colon = raw[start..].find(':').ok_or("node colon absent")? + start + 1;
    let value = raw[colon..].find('"').ok_or("node value absent")? + colon;
    let token = serde_json::to_string(old).or_err("serde_json::to_string(old)")?;
    if !raw[value..].starts_with(&token) {
        return Err("node value mismatch".into());
    }
    Ok(format!(
        "{}{}{}",
        &raw[..value],
        serde_json::to_string(new).or_err("serde_json::to_string(new)")?,
        &raw[value + token.len()..]
    ))
}
pub(super) fn measured(
    row: &Value,
    observed: Value,
    expected: Value,
    recipe: &str,
    calls: Vec<Value>,
    fixtures: Value,
) -> Value {
    let submission = calls
        .iter()
        .rev()
        .find_map(|call| match call["method"].as_str() {
            Some(
                method @ ("submitblock"
                | "sendrawtransaction"
                | "sendrawtransactions"
                | "verifyscript"),
            ) => Some(method),
            _ => None,
        });
    let detail = if submission == Some("submitblock") {
        block_reason_detail(&expected, &observed)
    } else {
        None
    };
    let agree = compare(&expected, &observed) || detail.is_some();
    let build = calls
        .iter()
        .find(|call| call["lifecycle"] == "binary")
        .map(|call| call["build"].clone());
    let mut result = json!({"id":row["id"],"label":"[X]","verdict":if agree{"agree"}else{"diverge"},"recipe":recipe,"expected":expected,"expected_label":"[D]","observed":observed,"fixtures":fixtures,"rpc":calls});
    if let Some(build) = build {
        result["build"] = build;
    }
    if let Some(detail) = detail {
        result["classification"] = json!("observation limit (reason detail)");
        result["unobservable_reason_detail"] = json!(detail);
        result["comparison_scope"] =
            json!("status and reason code; submitblock omits parenthetical detail");
    }
    result
}
// [D] 2026-10-13 (#72): true when a receipt names an adjusted-time offset or a
// peer offset sample other than zero (the `clock` and `peer-clock` events).
pub(super) fn offset_uncontrolled(v: &Value) -> bool {
    match v {
        Value::Object(o) => {
            (matches!(
                o.get("event").and_then(Value::as_str),
                Some("clock" | "peer-clock")
            ) && (o.get("timeoffset") != Some(&json!(0))
                || o.get("peer_timeoffsets")
                    .and_then(Value::as_array)
                    .is_some_and(|a| a.iter().any(|x| x != &json!(0)))))
                || o.values().any(offset_uncontrolled)
        }
        Value::Array(a) => a.iter().any(offset_uncontrolled),
        _ => false,
    }
}
// [D] 2026-10-13 (#72): a row whose projection was computed on a named block
// body is judged only when the node's observed body is that body. Otherwise the
// row is recorded, never judged: the assembler's choice is not a rule
// (src/mining/journaling_block_assembler.cpp:80-97 at PIN), and a predicted
// body is not an expectation.
pub(super) fn assembly_differs(
    row: &Value,
    observed: &[String],
    required: &[String],
    recipe: &str,
    calls: Vec<Value>,
    fixtures: Value,
) -> Option<Value> {
    (observed != required).then(|| {
        json!({"id":row["id"],"label":"[X]","verdict":"non-judging","recipe":recipe,
            "expected":row["expected"],"expected_label":"[D]",
            "observed":{"assembly":"differs","observed_body":observed,"required_body":required},
            "qualifier":"#72: the node assembled another body; the row's projection is for the required body",
            "rpc":calls,"fixtures":fixtures})
    })
}
fn witness_data(family: &str, row: &Value, record: &str, full_receipt: &Path) -> Result<Value> {
    // [D] 2026-10-13: retain P2P steps, rather than an unrelated RPC precheck.
    if row.get("peer").is_some() {
        let name = format!("s6-peer-66-{}-{}", family, text(&row["id"])?);
        let steps: Vec<_> = row["peer"]["events"]
            .as_array()
            .ok_or("peer events")?
            .iter()
            .filter(|e| e["direction"] == "step-in")
            .map(|e| e["step"].clone())
            .collect();
        return Ok(
            json!({"id":name,"date":"2026-10-13","label":"[X]","class":"node observation differs from declared projection","classification":"open","source_pin":PIN,"input_label":"[D]",
            "witness":{"family":family,"row":row["id"],"fixtures":row["fixtures"],"peer":row["peer"]},
            "initial_chain":{"recipe":row["recipe"],"complete_rpc_history":full_receipt,"rpc":row["rpc"]},
            "steps":[{"id":"reference-peer-replay","action":{"type":"reference-framework-steps","steps":steps},"kind":"recorded P2P and RPC observations","rules":[format!("[SRC] src/orphan_txns.cpp:175-241 at {PIN}")],"label":"[D]","expected_observations":row["expected"],"actual_observations":row["observed"],"node":format!("measured diverge [M] 2026-10-13 [X] {record}")}],
            "replay":{"record":record,"command":"tools/node_scenarios.sh --peer-only --peer-row <row> --record <new-record> --run-id <fresh-id>"}}),
        );
    }
    let name = format!("s6-66-{}-{}", family, text(&row["id"])?.replace('/', "-"));
    let submitted = row["rpc"].as_array().and_then(|calls| {
        calls.iter().rev().find(|call| {
            matches!(
                call["method"].as_str(),
                Some("submitblock" | "sendrawtransaction" | "verifyscript")
            )
        })
    });
    let submitted = submitted.ok_or("witness has no recorded submission")?;
    let witness = json!({
        "id":name,"class":"node observation differs from declared projection",
        "classification":"open","source_pin":PIN,"input_label":"[D]",
        "witness":{"family":family,"row":row["id"],"receipt":record.replace(".md",".json"),"fixtures":row["fixtures"]},
        "initial_chain":{"recipe":row["recipe"],"complete_rpc_history":full_receipt,"family":family,"row":row["id"]},
        "steps":[{"id":"submit","action":{"type":submitted["method"],"params":submitted["params"]},
            "kind":"recorded node observation","rules":[submitted["source"]],"label":"[D]",
            "expected_observations":row["expected"],"actual_observations":row["observed"],
            "status_basis":"Only the recorded projection is judged; the complete receipt supplies the chain and pool evidence.",
            "node":format!("measured diverge [X] {record}")}],
        "replay":{"record":record,"rpc_handler":submitted["source"]}});
    Ok(witness)
}
pub(super) fn write_witness(
    family: &str,
    row: &Value,
    record: &str,
    full_receipt: &Path,
) -> Result<()> {
    let witness = witness_data(family, row, record, full_receipt)?;
    let name = text(&witness["id"])?;
    let path = PathBuf::from(format!("corpus/scenarios/witnesses/{name}.md"));
    fs::create_dir_all(path.parent().or_err("path.parent()")?).map_err(|e| e.to_string())?;
    fs::write(path,format!("# {}\n\n[X] Row `{}`. Classification is `open` as data. The recorded live prefix, materialized inputs and exact RPC receipt form this witness.\n\n```json\n{}\n```\n",name,row["id"].as_str().or_err("row['id'].as_str()")?,serde_json::to_string_pretty(&witness).or_err("serde_json::to_string_pretty(&witness)")?)).map_err(|e|e.to_string())
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn absent_selected_binary_returns_a_row_without_launching() {
        let directory = std::env::temp_dir().join(format!("fix-121-{}", std::process::id()));
        fs::create_dir(&directory).unwrap();
        let path = directory.join("absent-bitcoind");
        let row = json!({"id":"absurd-fee-above", "binary":"wallet"});
        let build = Build::of(&row).unwrap();
        // The wallet-only preflight must leave the absent path for row handling.
        assert_eq!(build.version_at(&path).unwrap(), None);
        let result = build.absent_row_at(&row, &path).unwrap();
        assert_eq!(result["id"], row["id"]);
        assert_eq!(result["build"], "wallet build");
        assert_eq!(
            result["unrealizable"],
            format!(
                "the wallet build is absent on this host: {}",
                path.display()
            )
        );
        assert!(!path.exists());
        assert_eq!(fs::read_dir(&directory).unwrap().count(), 0);
        fs::remove_dir(directory).unwrap();
    }

    #[test]
    fn measurement_token_dates_the_run() {
        let row = json!({"verdict":"agree","observed":{"status":"ok"}});
        assert!(
            measured_token_dated(&row, "docs/records/run.md", "2026-10-14")
                .ends_with(" [M] 2026-10-14 [X] docs/records/run.md")
        );
    }
    // [D] 2026-10-14 (#121): a result whose instance ran on the wallet build
    // carries the build, and its token names it after the verdict.
    #[test]
    fn wallet_build_is_named_in_the_result_and_the_token() {
        let calls = vec![
            json!({"lifecycle":"binary","build":Build::Wallet.name()}),
            json!({"method":"sendrawtransaction","params":["00"]}),
        ];
        let ok = json!({"status":"accepted"});
        let result = measured(
            &json!({"id":"r"}),
            ok.clone(),
            ok.clone(),
            "r",
            calls,
            json!({}),
        );
        assert_eq!(result["build"], "wallet build");
        assert!(
            measured_token_dated(&result, "docs/records/run.md", "2026-10-14")
                .starts_with("measured agree (wallet build): ")
        );
        let record = measured(&json!({"id":"r"}), ok.clone(), ok, "r", vec![], json!({}));
        assert!(record.get("build").is_none());
        assert!(
            measured_token_dated(&record, "docs/records/run.md", "2026-10-14")
                .starts_with("measured agree: ")
        );
    }

    #[test]
    fn retry_port_handoff_preserves_inputs_and_bounds_attempts() {
        let mut paths = vec![];
        let mut pauses = 0;
        let (value, errors) = launch_retry(
            Path::new("run"),
            "intake",
            1234567,
            "debug=mempool\n",
            |path, size, extra| {
                assert_eq!(size, 1234567);
                assert_eq!(extra, "debug=mempool\n");
                paths.push(path);
                if paths.len() == 1 {
                    Err("Unable to bind: Address already in use".into())
                } else {
                    Ok(42)
                }
            },
            || pauses += 1,
        )
        .unwrap();
        assert_eq!((value, errors.len(), pauses), (42, 1, 1));
        assert_eq!(
            paths,
            [PathBuf::from("run/intake-0"), PathBuf::from("run/intake-1")]
        );
        let mut attempts = 0;
        let result: Result<((), Vec<String>)> = launch_retry(
            Path::new("run"),
            "bind",
            7,
            "",
            |_, _, _| {
                attempts += 1;
                Err("Unable to bind".into())
            },
            || {},
        );
        assert!(result.unwrap_err().contains("exhausted"));
        assert_eq!(attempts, 20);
        for error in [
            "invalid configuration",
            "interrupted during startup",
            "node startup timeout",
        ] {
            let mut attempts = 0;
            let result: Result<((), Vec<String>)> = launch_retry(
                Path::new("run"),
                "invalid",
                7,
                "",
                |_, _, _| {
                    attempts += 1;
                    Err(error.into())
                },
                || panic!("unrelated error retried"),
            );
            assert_eq!(result.unwrap_err(), error);
            assert_eq!(attempts, 1);
        }
        let pointer = Path::new("host").join("spec-oracle-scenarios/run/intake-1");
        assert_eq!(instance_pointer(&pointer), "run/intake-1");
    }
    #[test]
    fn ordered_status_and_greatest_height() {
        let mut e = Evidence {
            active_heights: vec![3, 8, 5],
            accepted: true,
            held: true,
            isolated_orphan: true,
            stale: true,
            exact_active_conflict: true,
            rejection: Some(json!({"value":"rejected"})),
        };
        assert_eq!(status(&e), json!({"value":"minedActive","height":8}));
        e.active_heights.clear();
        for (expected, field) in [
            ("inMempool", 0),
            ("heldNonFinal", 1),
            ("orphan", 2),
            ("onStaleBranch", 3),
            ("conflictedByMinedSpend", 4),
        ] {
            assert_eq!(status(&e)["value"], expected);
            match field {
                0 => e.accepted = false,
                1 => e.held = false,
                2 => e.isolated_orphan = false,
                3 => e.stale = false,
                _ => e.exact_active_conflict = false,
            }
        }
        assert_eq!(status(&e)["value"], "rejected");
        e.rejection = None;
        assert_eq!(status(&e)["value"], "unknown");
    }
    #[test]
    fn submitblock_reason_detail_is_unobservable_only_on_matching_rejection() {
        let expected = json!({"status":"rejected","reason":"blk-bad-inputs (false stack)"});
        let observed = json!({"status":"rejected","reason":"blk-bad-inputs"});
        for (method, actual, agrees) in [
            ("submitblock", observed.clone(), true),
            ("sendrawtransaction", observed.clone(), false),
            ("submitblock", json!({"status":"ok"}), false),
            (
                "submitblock",
                json!({"status":"rejected","reason":"other"}),
                false,
            ),
            (
                "submitblock",
                json!({"status":"rejected","reason":"blk-bad-inputs (other detail)"}),
                false,
            ),
            (
                "submitblock",
                json!({"status":"rejected","reason":"blk-bad-inputs","code":16}),
                false,
            ),
        ] {
            let result = measured(
                &json!({"id":"test"}),
                actual,
                expected.clone(),
                "test",
                vec![json!({"method":method})],
                json!({}),
            );
            assert_eq!(result["verdict"] == "agree", agrees);
            if agrees {
                assert_eq!(result["unobservable_reason_detail"], "false stack");
                assert!(
                    measured_token(&result, "docs/records/test.md").contains("detail not surfaced")
                );
            }
        }
        assert!(block_reason_detail(
            &json!({"status":"rejected","reason":"bad-version(0x1)"}),
            &json!({"status":"rejected","reason":"bad-version"})
        )
        .is_none());
    }
    #[test]
    fn exact_comparator_and_code_namespaces() {
        assert!(!compare(
            &json!({"reason":"bad"}),
            &json!({"reason":"bad "})
        ));
        assert!(!compare(&json!(["T"]), &json!([])));
        let r =
            node_reject(&json!({"error":{"code":-26,"message":"16: bad-txns-vin-empty"}})).unwrap();
        assert_eq!(r["namespace"], "node");
        assert_eq!(r["code"], 16);
        assert_eq!(
            node_reject(&json!({"error":{"code":-25,"message":"Missing inputs"}})).unwrap()
                ["namespace"],
            "rpc"
        );
    }
    #[test]
    fn only_node_token_changes() {
        let raw = "{ \"id\":\"x\", \"node\" : \"pending #66\", \"tx\":\"aA\" }\n";
        let updated = replace_node(raw, "pending #66", "ok [X] docs/records/a.md").unwrap();
        assert_eq!(
            updated.replace("ok [X] docs/records/a.md", "pending #66"),
            raw
        );
    }
    #[test]
    fn no_orphan_inference_from_absence() {
        assert_eq!(status(&Evidence::default())["value"], "unknown");
    }
    #[cfg(unix)]
    struct FailingChild {
        calls: std::rc::Rc<std::cell::RefCell<Vec<&'static str>>>,
        wait_fails: usize,
    }
    #[cfg(unix)]
    impl ChildControl for FailingChild {
        fn try_wait(&mut self) -> std::io::Result<Option<std::process::ExitStatus>> {
            self.calls.borrow_mut().push("try_wait");
            Err(std::io::Error::other("injected try_wait failure"))
        }
        fn kill(&mut self) -> std::io::Result<()> {
            self.calls.borrow_mut().push("kill");
            Err(std::io::Error::other("injected kill failure"))
        }
        fn wait(&mut self) -> std::io::Result<std::process::ExitStatus> {
            use std::os::unix::process::ExitStatusExt;
            self.calls.borrow_mut().push("wait");
            if self.wait_fails > 0 {
                self.wait_fails -= 1;
                Err(std::io::Error::other("injected wait failure"))
            } else {
                Ok(std::process::ExitStatus::from_raw(0))
            }
        }
    }
    #[test]
    #[cfg(unix)]
    fn cleanup_waits_after_failed_kill_and_drop_retries_failed_wait() {
        for wait_fails in [0, 1, 2] {
            let calls = std::rc::Rc::new(std::cell::RefCell::new(vec![]));
            let node = Node {
                child: FailingChild {
                    calls: calls.clone(),
                    wait_fails,
                },
                rpc: None,
                dir: PathBuf::new(),
                calls: vec![],
                conf: String::new(),
                stopped: false,
                seen: BTreeSet::new(),
                clock: START_CLOCK,
                build: Build::Record,
            };
            drop(node);
            assert_eq!(
                *calls.borrow(),
                ["try_wait", "kill", "wait", "kill", "wait"]
            );
        }
    }
    // [D] 2026-10-14 (#121): a row without `binary` runs on the node of record;
    // only "wallet" selects the second binary; the three paths are PROVENANCE 1a's pins.
    #[test]
    fn build_selector_reads_the_row_and_the_pins() {
        assert_eq!(Build::of(&json!({"id":"r"})).unwrap(), Build::Record);
        assert_eq!(
            Build::of(&json!({"binary":"wallet"})).unwrap(),
            Build::Wallet
        );
        for bad in [json!("record"), json!(""), json!(1), json!(null)] {
            assert!(Build::of(&json!({"binary":bad})).is_err());
        }
        let pins = include_str!("../../../docs/PROVENANCE.md");
        for (key, build) in [
            ("reference.binary ", Build::Record),
            ("reference.binary_wallet ", Build::Wallet),
            ("reference.binary_zmq ", Build::Zmq),
        ] {
            let line = pins.lines().find(|l| l.starts_with(key)).unwrap();
            assert_eq!(
                line.split_once('=').unwrap().1.trim(),
                format!("${}", build.var())
            );
        }
    }
    #[test]
    #[cfg(unix)]
    fn stop_remembers_successful_wait_despite_kill_error() {
        let calls = std::rc::Rc::new(std::cell::RefCell::new(vec![]));
        let mut node = Node {
            child: FailingChild {
                calls: calls.clone(),
                wait_fails: 0,
            },
            rpc: None,
            dir: PathBuf::new(),
            calls: vec![],
            conf: String::new(),
            stopped: false,
            seen: BTreeSet::new(),
            clock: START_CLOCK,
            build: Build::Record,
        };
        assert!(node.stop().unwrap_err().contains("kill"));
        assert!(node.stopped);
        drop(node);
        assert_eq!(*calls.borrow(), ["try_wait", "kill", "wait"]);
    }
    #[test]
    fn offset_receipts_gate_judging() {
        let zero = json!({"rpc":[{"event":"clock","timeoffset":0},{"event":"peer-clock","timeoffset":0,"peer_timeoffsets":[0]}]});
        assert!(!offset_uncontrolled(&zero));
        assert!(offset_uncontrolled(
            &json!([{"event":"clock","timeoffset":3}])
        ));
        assert!(offset_uncontrolled(
            &json!({"f":{"event":"peer-clock","timeoffset":0,"peer_timeoffsets":[0,-1]}})
        ));
        assert!(!offset_uncontrolled(&json!({"timeoffset":5})));
    }
    #[test]
    fn assembly_gate_judges_only_the_required_body() {
        let row = json!({"id":"r","expected":{"x":1}});
        let t = vec!["aa".to_owned()];
        assert!(assembly_differs(&row, &t, &t, "r", vec![], json!({})).is_none());
        let other = assembly_differs(&row, &[], &t, "r", vec![], json!({})).unwrap();
        assert_eq!(other["verdict"], "non-judging");
        assert_eq!(other["observed"]["required_body"], json!(t));
        assert!(measured_token(&other, "docs/records/x.md").starts_with("measured non-judging: "));
    }
    #[test]
    fn generated_witness_has_declared_schema_and_exact_submission() {
        let call = json!({"method":"sendrawtransaction","params":["abcd"],"source":"[SRC] src/rpc/rawtransaction.cpp:1530-1672"});
        let row = json!({"id":"probe","recipe":"fund then submit","fixtures":{"transaction":{"hex":"abcd"}},"expected":{"status":"accepted"},"observed":{"status":"rejected"},"rpc":[call]});
        let witness = witness_data(
            "mempool",
            &row,
            "docs/records/run.md",
            Path::new("run/receipt.json"),
        )
        .unwrap();
        for key in ["id", "class", "witness", "initial_chain", "steps", "replay"] {
            assert!(witness.get(key).is_some());
        }
        let step = &witness["steps"][0];
        for key in [
            "id",
            "action",
            "kind",
            "rules",
            "expected_observations",
            "label",
            "node",
        ] {
            assert!(step.get(key).is_some());
        }
        assert_eq!(step["action"]["params"], call["params"]);
        assert_eq!(step["label"], "[D]");
        assert_eq!(witness["input_label"], "[D]");
        assert_eq!(
            witness["initial_chain"]["complete_rpc_history"],
            "run/receipt.json"
        );
    }
}
