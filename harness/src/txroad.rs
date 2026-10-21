//! txroad: THE BLOCK ROAD (this repo's; #27, D97; S3, set 4, 2026-09-26): `run_svnode --mode tx`.
//!
//! The `tx.*` rules (lock time, sequence, the transaction-level gate) need a chain; `verifyscript` decides scripts
//! alone. D97 (C3, 2026-09-25) rules BOTH columns the corpus records, by two roads on the spec's own instances:
//!
//! * THE CONSENSUS COLUMN (`sv-node@v1.2.3`, mode `block-connect`): the entry's transaction in a BLOCK the harness
//!   assembles (`block.rs`) and `submitblock`s on the BLOCK instance (`harness/oracle/bitcoin-block.conf`, a
//!   mainnet-shaped private regtest chain baked by `oracle_chain`); the verdict is the block's acceptance (`null`)
//!   or its reject reason (`BIP22ValidationResult`, `rpc/mining.cpp:348–354`); an accepted block is
//!   `invalidateblock`ed so the next entry's block sits at the same height.
//! * THE POLICY COLUMN (`sv-node-mempool@v1.2.3`, mode `sendrawtransaction`): the same transaction through
//!   `sendrawtransaction <hex> false true` (allowhighfees false, dontcheckfee true: the fee policy is outside the
//!   script semantics and outside `tx.rules`; `rpc/rawtransaction.cpp:1535–1544`) on the POLICY instance, whose
//!   datadir is a COPY of the block instance's at `spend_height − 1` (`spec-node.sh block adopt-into-policy`), so
//!   both roads start from the same tip; the verdict is the txid or the refusal's reason (`"<code>: <reason>"`,
//!   `:1642–1644`). The txid means acceptance into the MEMPOOL, not finality in the next block: after Genesis the
//!   mempool accepts a non-final transaction that the block still refuses. The pin has NO `testmempoolaccept`: D97 named it, the RPC list decides.
//!
//! THE FUNDING CONTRACT: every input's prevout (`prevouts[i]`: the script, the satoshis, the HEIGHT) becomes a real
//! output of a funding transaction the road puts in a block it ASSEMBLES and submits (since 2026-09-28: the block
//! instance's mempool refuses a funding transaction whose outputs' sigops it cannot count) at EXACTLY `prevouts[i].height` (the spec reads that
//! height as the coin's era; BIP68's relative locks, enforced before Genesis only (policy.h:247–255), read it as the coin's age); a funding height must lie above the
//! chain's height at the start of the entry's group (the base snapshot's for the first group; for a later group the
//! previous group's spend height minus one) and below the entry's `spend_height`; two inputs on one synthetic outpoint (a duplicate) share
//! one funding output; an input whose outpoint is null keeps it (a coinbase entry, or the `prevout-null` rule). The
//! entries' inputs are rewritten to the funding outpoints at run time (their locks are unsigned by construction); the
//! corpus keeps its synthetic outpoints and the manifest says so. Every entry of a group shares one `spend_height`
//! (the block's height), as every corpus does today at 967,896; a second `spend_height` is a second group, baked in
//! order. The spec's verdict compared on both roads is the GATE and the SCRIPT verdict together (`Bsvs.Run.txGate`:
//! `CheckRegularTransaction`/`CheckCoinbase` under the spend's era, then the scripts).
//!
//! The chain's geometry the road relies on: mainnet's Genesis and Chronicle heights; regtest's other activations
//! (`uahfHeight` 0, `daaHeight` 0, BIP66 1,251, BIP65 1,351, CSV 576: `chainparams.cpp` regtest); the mocktime one
//! second per block from `oracle_chain::T0` as a LOWER bound: the node's miner gives a block the median time past plus
//! one when the mocktime lags, so the chain's times run ahead of `T0 + height` (+166 s by 5,000 blocks, measured), and
//! the spend block is timed from the tip's median (the manifest records the tip's time and median per group).

use std::collections::BTreeMap;
use std::io::BufRead;
use std::path::{Path, PathBuf};
use std::time::Duration;

use bsv_rs::primitives::hash::sha256;

use crate::block::{assemble, coinbase_tx, try_p2pkh_spend};
use crate::corpus::{Divergence, Entry, ExpectJson, ImplConfigJson, Manifest};
use crate::fail::OrErr;
use crate::rpc::Rpc;
use crate::rules::{self, RuleSet};
use crate::svnode_codes;
use crate::txraw::{txid_display_hex, txid_from_display_hex, RawOutput, RawTx};
use crate::SV_NODE_TAG;

pub const SV_NODE_KEY: &str = "sv-node@v1.2.3";
pub const SV_NODE_MEMPOOL_KEY: &str = "sv-node-mempool@v1.2.3";
/// The base snapshot's height (`oracle_chain bake --to 600000`, `spec-node.sh block snapshot base`): below Genesis,
/// above every coin a family needs before it.
pub const BASE_HEIGHT: u32 = 600_000;
/// The bake's base stamp (`oracle_chain::T0`; one second per block).
pub const T0: u64 = 1_700_000_000;
pub const WELL_LABEL: &str = "bsv-script-lean/oracle/well";
/// THE GATE'S BOUNDARY (the owner's ruling R2 on #32, 2026-10-05, `docs/records/20261005-221333-owner-rulings-32.md`):
/// the coinbase height requirement (BIP34: a coinbase's script opens with the serialized height from `BIP34Height`
/// on, `validation.cpp:6085–6093` `bad-cb-height`) is BLOCK context, outside the spec's transaction gate. Mainnet's
/// height is 227,931 (`chainparams.cpp:1038`); the block instance is regtest and keeps regtest's compiled
/// 100,000,000 (`chainparams.cpp:1463`; `harness/oracle/bitcoin-block.conf` sets the Genesis and Chronicle heights
/// and no BIP34 height), so no block of the road is held to the rule. A block-road agreement whose verdict turns on
/// it is the INSTANCE's result, counted apart from the ordinary agreements (`agree_instance_qualified`), never in them.
pub const MAINNET_BIP34_HEIGHT: u32 = 227_931;
pub const INSTANCE_BIP34_HEIGHT: u32 = 100_000_000;

/// The block instance's activation context, emitted beside the road's accounting (R2.2, R2.3).
pub fn activation_context() -> serde_json::Value {
    serde_json::json!({
        "instance": "the block instance (harness/oracle/bitcoin-block.conf, regtest, bitcoin-sv v1.2.3 6504a3a)",
        "bip34_height": INSTANCE_BIP34_HEIGHT,
        "bip34_source": "regtest's compiled consensus.BIP34Height, chainparams.cpp:1463 at 6504a3a; the instance's configuration sets no BIP34 height [SRC]",
        "mainnet_bip34_height": MAINNET_BIP34_HEIGHT,
        "mainnet_bip34_source": "chainparams.cpp:1038 at 6504a3a [SRC]",
        "genesis_height": 620_538, "chronicle_height": 943_816,
        "excluded_rule": "the coinbase height requirement (BIP34), validation.cpp:6085–6093 bad-cb-height: block context, outside the transaction gate by the owner's ruling R2 on #32; recorded from source, never executed by the road",
    })
}

/// The block road's accounting (R2.2, R2.3): the ordinary agreements per column (the mempool's among them), the
/// instance-qualified ones apart with their ids, and the activation context. ONE builder for both the witness manifest
/// and the corpus manifest's `sv-node` config, so their numbers cannot drift (`manifests_agree_on_the_split`).
pub fn road_accounting(
    agree: &BTreeMap<String, u64>,
    agree_qualified: &BTreeMap<String, u64>,
    qualified: &[serde_json::Value],
) -> serde_json::Map<String, serde_json::Value> {
    let mut m = serde_json::Map::new();
    m.insert("agree".into(), serde_json::json!(agree));
    m.insert(
        "agree_instance_qualified".into(),
        serde_json::json!(agree_qualified),
    );
    m.insert("instance_qualified".into(), serde_json::json!(qualified));
    m.insert("activation_context".into(), activation_context());
    m
}

/// Whether a coinbase script opens with the push `CScript() << height` (the BIP34 form; the harness's own
/// coinbases are built so, `block::coinbase_tx`).
pub fn opens_with_height(script: &[u8], height: u32) -> bool {
    let mut want = Vec::new();
    crate::gen::push_min(&mut want, &crate::gen::enc_num(height as i128));
    script.starts_with(&want)
}

/// R2: a block-road verdict is INSTANCE-QUALIFIED when it would move were the instance at mainnet's BIP34 height: the
/// entry is a coinbase the node ACCEPTED at a spend height where mainnet enforces the rule and the instance does not,
/// and its script does not open with that height. A refused coinbase stays refused at any BIP34 height (the rule only
/// adds a refusal), and a coinbase opening with its height passes the rule; neither is qualified.
pub fn bip34_qualified(tx: &RawTx, spend_height: u32, node_kind: &str) -> bool {
    let is_coinbase =
        tx.inputs.len() == 1 && is_null_outpoint(&tx.inputs[0].txid, tx.inputs[0].vout);
    is_coinbase
        && node_kind == "valid"
        && (MAINNET_BIP34_HEIGHT..INSTANCE_BIP34_HEIGHT).contains(&spend_height)
        && !opens_with_height(&tx.inputs[0].script, spend_height)
}

fn arg(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1).cloned())
}

#[derive(Clone, Debug, serde::Deserialize)]
struct SpecVerdict {
    verdict: String,
    #[serde(default)]
    code: Option<String>,
    #[serde(default)]
    input: Option<usize>,
    #[serde(default)]
    gate: Option<GateJson>,
}

#[derive(Clone, Debug, serde::Deserialize)]
struct GateJson {
    verdict: String,
    #[serde(default)]
    code: Option<String>,
}

#[derive(Clone, Debug, serde::Deserialize)]
struct SpecLine {
    id: String,
    spec: SpecVerdict,
    #[serde(rename = "spec-mempool")]
    spec_mempool: SpecVerdict,
    config: String,
    commit: String,
}

/// The gate and the script verdict together: the transaction's verdict as the block and the mempool roads judge it.
fn combined(s: &SpecVerdict) -> (String, Option<String>) {
    match &s.gate {
        Some(g) if g.verdict == "invalid" => ("invalid".into(), g.code.clone()),
        _ => (s.verdict.clone(), s.code.clone()),
    }
}

fn combined_json(s: &SpecVerdict) -> ExpectJson {
    let (v, c) = combined(s);
    ExpectJson {
        verdict: v,
        code: c,
        reason: None,
        input: s.input,
    }
}

struct NodeSide {
    kind: String,
    code: Option<String>,
    native: String,
    unknown: bool,
}

fn side_json(s: &NodeSide) -> ExpectJson {
    ExpectJson {
        verdict: s.kind.clone(),
        code: s.code.clone(),
        reason: if s.native.is_empty() {
            None
        } else {
            Some(s.native.clone())
        },
        input: None,
    }
}

fn well_key() -> Result<bsv_rs::primitives::ec::PrivateKey, String> {
    bsv_rs::primitives::ec::PrivateKey::from_bytes(&sha256(WELL_LABEL.as_bytes()))
        .or_err("the well's key")
}

fn well_script() -> Result<Vec<u8>, String> {
    let pk = well_key()?.public_key().to_compressed().to_vec();
    let h = bsv_rs::primitives::hash::hash160(&pk);
    let mut s = vec![0x76, 0xa9, 0x14];
    s.extend_from_slice(&h);
    s.extend_from_slice(&[0x88, 0xac]);
    Ok(s)
}

fn well_address() -> Result<String, String> {
    // base58check(0x6f ‖ hash160(pk)) as oracle_chain prints it
    const ALPHABET: &[u8; 58] = b"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
    let pk = well_key()?.public_key().to_compressed().to_vec();
    let mut data = vec![0x6f];
    data.extend_from_slice(&bsv_rs::primitives::hash::hash160(&pk));
    let check = sha256(&sha256(&data));
    data.extend_from_slice(&check[..4]);
    let mut digits: Vec<u8> = vec![0];
    for &byte in &data {
        let mut carry = byte as u32;
        for d in digits.iter_mut() {
            carry += (*d as u32) << 8;
            *d = (carry % 58) as u8;
            carry /= 58;
        }
        while carry > 0 {
            digits.push((carry % 58) as u8);
            carry /= 58;
        }
    }
    let mut out = String::new();
    for _ in data.iter().take_while(|&&b| b == 0) {
        out.push('1');
    }
    for &d in digits.iter().rev() {
        out.push(ALPHABET[d as usize] as char);
    }
    Ok(out)
}

struct Node {
    rpc: Rpc,
    url: String,
    cookie: String,
}

impl Node {
    fn connect(url: &str, cookie: &str) -> Node {
        let rpc = Rpc::new(url, cookie, Duration::from_secs(600)).unwrap_or_else(|e| {
            eprintln!("run_svnode --mode tx: {e}");
            std::process::exit(1)
        });
        Node {
            rpc,
            url: url.to_string(),
            cookie: cookie.to_string(),
        }
    }
    fn reconnect(&mut self) {
        // the cookie changes on every start
        for _ in 0..60 {
            if let Ok(r) = Rpc::new(&self.url, &self.cookie, Duration::from_secs(600)) {
                let mut r = r;
                if r.call("getblockcount", serde_json::json!([])).is_ok() {
                    self.rpc = r;
                    return;
                }
            }
            std::thread::sleep(Duration::from_secs(1));
        }
        eprintln!("run_svnode --mode tx: {} did not come back", self.url);
        std::process::exit(1);
    }
    fn height(&mut self) -> Result<u32, String> {
        Ok(self
            .rpc
            .call("getblockcount", serde_json::json!([]))
            .or_err("getblockcount")?
            .as_u64()
            .unwrap_or(0) as u32)
    }
    fn version(&mut self) -> String {
        self.rpc
            .call("getnetworkinfo", serde_json::json!([]))
            .map(|v| v["subversion"].as_str().unwrap_or("").to_string())
            .unwrap_or_default()
    }
    /// Mine empty blocks to `to` (the well paid; the mocktime one second per block from T0).
    fn mine_to(&mut self, to: u32, addr: &str) -> Result<(), String> {
        let mut h = self.height()?;
        while h < to {
            let n = std::cmp::min(1000, to - h);
            self.rpc
                .call("setmocktime", serde_json::json!([T0 + (h + n) as u64]))
                .or_err("setmocktime")?;
            self.rpc
                .call("generatetoaddress", serde_json::json!([n, addr]))
                .or_err(&format!("generatetoaddress at {h}"))?;
            h += n;
        }
        let now = self.height()?;
        if now != to {
            return Err(format!("the chain is at {now}, not at {to}"));
        }
        Ok(())
    }
    /// The tip: its hash (internal order), the chain's version and bits, its time and median time past.
    fn tip(&mut self) -> Result<([u8; 32], i32, u32, u64, u64), String> {
        let hash = self
            .rpc
            .call("getbestblockhash", serde_json::json!([]))
            .or_err("tip")?
            .as_str()
            .or_err("tip: the hash as a string")?
            .to_string();
        let hdr = self
            .rpc
            .call("getblockheader", serde_json::json!([hash]))
            .or_err("header")?;
        let bits = u32::from_str_radix(hdr["bits"].as_str().unwrap_or("207fffff"), 16)
            .unwrap_or(0x207f_ffff);
        let version = hdr["version"].as_i64().unwrap_or(0x2000_0000) as i32;
        Ok((
            txid_from_display_hex(&hash).or_err("tip hash")?,
            version,
            bits,
            hdr["time"].as_u64().unwrap_or(0),
            hdr["mediantime"].as_u64().unwrap_or(0),
        ))
    }
}

/// The well's unspent, mature coinbases below `height`: (txid internal, vout, satoshis).
fn well_coins(node: &mut Node, height: u32) -> Result<Vec<([u8; 32], u32, u64)>, String> {
    let script = hex::encode(well_script()?);
    let mut out = Vec::new();
    let top = std::cmp::min(height.saturating_sub(100), 6000);
    for h in 1..=top {
        let hash = node
            .rpc
            .call("getblockhash", serde_json::json!([h]))
            .or_err("getblockhash")?;
        let block = node
            .rpc
            .call("getblock", serde_json::json!([hash, 2]))
            .or_err("getblock")?;
        let cb = &block["tx"][0];
        if cb["vout"][0]["scriptPubKey"]["hex"].as_str() != Some(script.as_str()) {
            continue;
        }
        let sats = (cb["vout"][0]["value"].as_f64().unwrap_or(0.0) * 1e8).round() as u64;
        if sats == 0 {
            break;
        }
        let txid = cb["txid"].as_str().unwrap_or("");
        let unspent = !node
            .rpc
            .call("gettxout", serde_json::json!([txid, 0]))
            .map(|v| v.is_null())
            .unwrap_or(true);
        if unspent {
            out.push((txid_from_display_hex(txid).or_err("txid")?, 0, sats));
        }
    }
    Ok(out)
}

/// The witnesses directory a run writes (#32 P13): `--witnesses`, else the committed `../corpus/witnesses`. A run
/// under `--limit` is partial, so it never writes the committed directory (its witness file and its manifest row
/// would be overwritten by the partial run's): without `--witnesses` it writes a scratch directory under the system's
/// temporary directory (printed), and with a `--witnesses` that is the committed directory it is refused. The
/// comparison fails closed (the lens of lane fix32-rust): a `--witnesses` that does not exist yet is resolved by its
/// nearest existing ancestor and the rest of its path, and a limited run is refused when the committed directory or
/// the given path cannot be resolved at all. Both modes of `run_svnode` call this before a node is touched.
pub fn witnesses_dir_of(
    args: &[String],
    limit: Option<usize>,
    root: &Path,
    who: &str,
) -> Result<String, String> {
    let committed = root.join("corpus").join("witnesses");
    match (arg(args, "--witnesses"), limit) {
        (Some(d), Some(_)) => {
            let (a, b) = match (resolve_lexically(Path::new(&d)), std::fs::canonicalize(&committed)) {
                (Some(a), Ok(b)) => (a, b),
                _ => return Err(format!("{who}: --limit with --witnesses {d}: the path or the committed directory {} does not resolve, so the run cannot show it is not the committed directory; refused", committed.display())),
            };
            if a == b || a.starts_with(&b) {
                Err(format!("{who}: --limit with --witnesses {d} (the committed witnesses directory) would overwrite its witness file and manifest row with a partial run; refused (omit --witnesses for a scratch directory)"))
            } else {
                Ok(d)
            }
        }
        (Some(d), None) => Ok(d),
        (None, Some(_)) => {
            let d = std::env::temp_dir().join(format!("run_svnode-limited-{}", std::process::id()));
            println!("{who}: a limited run writes its witnesses to the scratch directory {} (never the committed corpus/witnesses)", d.display());
            Ok(d.to_string_lossy().to_string())
        }
        (None, None) => Ok("../corpus/witnesses".into()),
    }
}

/// A path resolved through its nearest existing ancestor (canonicalized: symbolic links and `..` resolved there) and
/// the rest of its components appended; `None` when a remaining component is `..` or no ancestor exists.
fn resolve_lexically(p: &Path) -> Option<PathBuf> {
    let abs = if p.is_absolute() {
        p.to_path_buf()
    } else {
        std::env::current_dir().ok()?.join(p)
    };
    let mut rest: Vec<std::ffi::OsString> = Vec::new();
    let mut cur = abs.as_path();
    loop {
        if let Ok(c) = std::fs::canonicalize(cur) {
            let mut out = c;
            for comp in rest.iter().rev() {
                out.push(comp);
            }
            return Some(out);
        }
        match cur.file_name() {
            Some(n) if cur.parent().is_some() => {
                rest.push(n.to_os_string());
                cur = cur.parent()?;
            }
            _ => return None,
        }
    }
}

/// A divergence class's count, its smallest member (size, entry, the spec's verdict, the node's) and its explanation.
type ClassCount = (
    u64,
    Option<(usize, Entry, ExpectJson, ExpectJson)>,
    Option<rules::Explanation>,
);
/// A funding output: the synthetic outpoint (txid internal, vout), its lock and its satoshis.
type FundingOut = ([u8; 32], u32, Vec<u8>, u64);

fn is_null_outpoint(txid: &[u8; 32], vout: u32) -> bool {
    txid.iter().all(|&b| b == 0) && vout == 0xffff_ffff
}

/// `run_svnode --mode tx`: the exit code of `run` (#132: a failed RPC call, file or frame is reported with its words and
/// exits 1, where an unwrap, expect or panic stood before; the usage errors exit 2 as they did).
pub fn main(args: Vec<String>) -> i32 {
    match run(args) {
        Ok(code) => code,
        Err(e) => {
            eprintln!("run_svnode --mode tx: {e}");
            if e.starts_with("usage: ") {
                2
            } else {
                1
            }
        }
    }
}

fn run(args: Vec<String>) -> Result<i32, String> {
    let corpus_path = arg(&args, "--corpus").ok_or("usage: --corpus <file.jsonl>")?;
    let spec_path = arg(&args, "--spec")
        .ok_or("usage: --spec <spec.jsonl> (from `eval/bsvs corpus`, with the gate)")?;
    let record = args.iter().any(|a| a == "--record");
    let limit: Option<usize> = match arg(&args, "--limit") {
        Some(s) => Some(s.parse().map_err(|e| format!("usage: --limit N: {e}"))?),
        None => None,
    };
    if record && limit.is_some() {
        eprintln!(
            "run_svnode --mode tx: --record with --limit would record a partial run; refused"
        );
        return Ok(2);
    }
    let root: PathBuf = match std::env::var("BSV_SCRIPT_LEAN_ROOT") {
        Ok(r) => PathBuf::from(r),
        Err(_) => {
            let here = std::env::current_dir().or_err("cwd")?;
            if here.join("Cargo.toml").exists() && here.join("..").join("corpus").exists() {
                here.join("..").canonicalize().or_err("the root")?
            } else {
                here
            }
        }
    };
    let witnesses_dir = match witnesses_dir_of(&args, limit, &root, "run_svnode --mode tx") {
        Ok(d) => d,
        Err(e) => {
            eprintln!("{e}");
            return Ok(2);
        }
    };
    // lean #32, B-4: no spec stamp without a commit reaches the corpus, checked before a node is touched
    crate::stamp::refuse_unnamed_stamp(
        "run_svnode --mode tx",
        &spec_path,
        record,
        &witnesses_dir,
        &root,
    );
    let home = std::env::var("HOME").unwrap_or_default();
    let rpc_block = arg(&args, "--rpc-block").unwrap_or_else(|| "http://127.0.0.1:18567".into());
    let cookie_block = arg(&args, "--cookie-block")
        .unwrap_or_else(|| format!("{home}/bsv/targets/spec-oracle-block-data/regtest/.cookie"));
    let rpc_mp = arg(&args, "--rpc-mempool").unwrap_or_else(|| "http://127.0.0.1:18565".into());
    let cookie_mp = arg(&args, "--cookie-mempool")
        .unwrap_or_else(|| format!("{home}/bsv/targets/spec-oracle-policy-data/regtest/.cookie"));
    let oracle_sh = root.join("harness").join("oracle").join("spec-node.sh");
    let dump = arg(&args, "--dump");

    let mut blk = Node::connect(&rpc_block, &cookie_block);
    let bv = blk.version();
    if bv != format!("/Bitcoin SV:{}/", &SV_NODE_TAG[1..]) {
        eprintln!("run_svnode --mode tx: the block instance reports {bv}, the pin is bitcoin-sv {SV_NODE_TAG}");
        return Ok(1);
    }
    // the activation heights PROBED through verifyscript (`getsettings` does not expose them; the set-3 gotcha), as the
    // verifyscript runner probes its instances: the era bits the node derives from `txo.height` at 620,537 / 620,538 /
    // 943,815 / 943,816 under the post-Chronicle block word (misc.cpp:813–822, chainparams.cpp:18, 23)
    {
        const UTXO_AFTER_GENESIS: u32 = 1 << 19;
        const UTXO_AFTER_CHRONICLE: u32 = 1 << 21;
        let probe_tx = crate::flags_oracle::probe_tx_hex();
        let mut drift: Vec<String> = Vec::new();
        for (height, wg, wc) in [
            (620_537u32, false, false),
            (620_538, true, false),
            (943_815, true, false),
            (943_816, true, true),
        ] {
            let scripts = serde_json::json!([{"tx": probe_tx, "n": 0, "flags": 0x003D_462F_u32, "reportflags": true, "txo": {"lock": "51", "value": 1, "height": height}}]);
            match blk
                .rpc
                .call("verifyscript", serde_json::json!([scripts, true, 1000]))
            {
                Ok(v) => {
                    let applied = v[0]["flags"].as_i64().unwrap_or(-1) as u32;
                    let g = applied & UTXO_AFTER_GENESIS != 0;
                    let c = applied & UTXO_AFTER_CHRONICLE != 0;
                    if g != wg || c != wc {
                        drift.push(format!("txo.height {height}: the node derives UTXO_AFTER_GENESIS={g}, UTXO_AFTER_CHRONICLE={c}; mainnet's heights (620538, 943816) give {wg}, {wc}"));
                    }
                }
                Err(e) => drift.push(format!("the era probe at height {height} failed: {e}")),
            }
        }
        if !drift.is_empty() {
            eprintln!("run_svnode --mode tx: the block instance's activation heights are not mainnet's (harness/oracle/bitcoin-block.conf):");
            for d in &drift {
                eprintln!("  {d}");
            }
            return Ok(1);
        }
    }
    let start_height = blk.height()?;
    let addr = well_address()?;
    println!("run_svnode --mode tx: the block instance {rpc_block} ({bv}) at height {start_height}; the well {addr}");

    // the corpus and the spec's verdicts
    let dir = Path::new(&corpus_path)
        .parent()
        .map(|p| p.to_path_buf())
        .unwrap_or_default();
    let file_name = Path::new(&corpus_path)
        .file_name()
        .or_err("the corpus path's file name")?
        .to_string_lossy()
        .to_string();
    let corpus_name = dir
        .file_name()
        .map(|s| s.to_string_lossy().to_string())
        .unwrap_or_else(|| "corpus".into());
    let manifest_path = [dir.join("manifest.json"), dir.join("cases-manifest.json")]
        .into_iter()
        .find(|p| {
            p.exists()
                && std::fs::read_to_string(p)
                    .map(|s| s.contains(&format!("\"{file_name}\"")))
                    .unwrap_or(false)
        });
    let bytes = std::fs::read(&corpus_path).or_err(&format!("corpus file {corpus_path}"))?;
    let mut manifest: Option<Manifest> = None;
    if let Some(mp) = &manifest_path {
        let m: Manifest = serde_json::from_str(&std::fs::read_to_string(mp).or_err("manifest")?)
            .or_err("manifest json")?;
        let sha = hex::encode(sha256(&bytes));
        if sha != m.sha256 {
            eprintln!(
                "run_svnode --mode tx: {corpus_path} sha256 {sha} != manifest {}",
                m.sha256
            );
            return Ok(1);
        }
        manifest = Some(m);
    }
    let mut spec: BTreeMap<String, SpecLine> = BTreeMap::new();
    for line in std::io::BufReader::new(
        std::fs::File::open(&spec_path).or_err(&format!("spec file {spec_path}"))?,
    )
    .lines()
    {
        let line = line.or_err("spec file line")?;
        if line.trim().is_empty() {
            continue;
        }
        let s: SpecLine = serde_json::from_str(&line).or_err("spec line")?;
        spec.insert(s.id.clone(), s);
    }
    let commit = spec
        .values()
        .next()
        .map(|s| s.commit.clone())
        .unwrap_or_else(|| "unknown".into());
    let config = spec
        .values()
        .next()
        .map(|s| s.config.clone())
        .unwrap_or_else(|| "unknown".into());
    let spec_key = format!("spec@{commit}");
    let comparison_key = format!("spec-sv-node@{commit}");
    let comparison_mp_key = format!("spec-sv-node-mempool@{commit}");
    let mempool_key = format!("spec-mempool@{commit}");
    let mut entries: Vec<Entry> = Vec::new();
    for line in std::io::BufReader::new(&bytes[..]).lines() {
        let line = line.or_err("corpus line")?;
        if line.trim().is_empty() {
            continue;
        }
        let e: Entry = serde_json::from_str(&line).or_err("entry")?;
        e.check().or_err("a corpus entry must be well-formed")?;
        entries.push(e);
    }
    if let Some(l) = limit {
        entries.truncate(l);
    }
    let n = entries.len() as u64;

    // THE PLAN: the entries by spend height (a group per height, baked in ascending order); every non-null input's
    // synthetic outpoint funded ONCE at its prevout's height (two inputs on one outpoint share the funding output)
    let mut groups: BTreeMap<u32, Vec<usize>> = BTreeMap::new();
    for (ix, e) in entries.iter().enumerate() {
        groups.entry(e.params.spend_height).or_default().push(ix);
    }
    println!(
        "  the plan: {n} entries in {} spend-height groups {:?}; the chain at {start_height}",
        groups.len(),
        groups.keys().collect::<Vec<_>>()
    );
    // THE CLASSIFIER (D83c): the reference's own table, when it exists; a divergence no row explains is unexplained
    let rules_table: Option<RuleSet> = if RuleSet::path(&root, "sv-node").exists() {
        Some(RuleSet::load(&root, "sv-node").unwrap_or_else(|e| {
            eprintln!("run_svnode --mode tx: {e}");
            std::process::exit(1)
        }))
    } else {
        None
    };

    let t0 = std::time::Instant::now();
    let mut coins = well_coins(&mut blk, start_height)?;
    coins.sort_by_key(|c| std::cmp::Reverse(c.2));
    let well = well_key()?;
    let wscript = well_script()?;
    let mut funded: BTreeMap<([u8; 32], u32), ([u8; 32], u32)> = BTreeMap::new();
    let mut funding_txids: Vec<(u32, String)> = Vec::new();
    let mut mp: Option<Node> = None;
    let mut mpv = String::new();
    let mut settings_mp = serde_json::Value::Null;
    let mut agree: BTreeMap<String, u64> = BTreeMap::new();
    // R2: the agreements whose verdict turns on the instance's BIP34 height, apart from `agree` (never folded into it)
    let mut agree_qualified: BTreeMap<String, u64> = BTreeMap::new();
    let mut qualified: Vec<serde_json::Value> = Vec::new();
    let mut counts: BTreeMap<(String, String), ClassCount> = BTreeMap::new();
    let mut code_notes: BTreeMap<(String, String, String), u64> = BTreeMap::new();
    let mut unknown_reasons: BTreeMap<String, u64> = BTreeMap::new();
    let mut undecided: u64 = 0;
    let mut divergences: Vec<String> = Vec::new();
    let mut dump_lines: Vec<String> = Vec::new();
    let mut accepted_blocks: u64 = 0;
    let mut rewritten: Vec<Option<Entry>> = vec![None; entries.len()];
    let mut n_fund_total = 0usize;
    let mut tip_times: Vec<(u32, u64, u64, u64)> = Vec::new();
    for (spend_height, members) in &groups {
        let spend_height = *spend_height;
        // the funding plan of this group
        let mut fund_at: BTreeMap<u32, Vec<FundingOut>> = BTreeMap::new();
        let chain_now = blk.height()?;
        for &ix in members {
            let e = &entries[ix];
            let tx = RawTx::decode(&hex::decode(&e.tx).or_err("tx hex")?).or_err("tx frame")?;
            for (k, i) in tx.inputs.iter().enumerate() {
                if is_null_outpoint(&i.txid, i.vout) || funded.contains_key(&(i.txid, i.vout)) {
                    continue;
                }
                let p = &e.prevouts[k];
                if fund_at
                    .values()
                    .any(|v| v.iter().any(|o| o.0 == i.txid && o.1 == i.vout))
                {
                    continue;
                }
                if p.height <= chain_now || p.height >= spend_height {
                    eprintln!("run_svnode --mode tx: {}: the funding height {} must lie above the chain's {chain_now} and below the spend height {spend_height}", e.id, p.height);
                    return Ok(1);
                }
                fund_at.entry(p.height).or_default().push((
                    i.txid,
                    i.vout,
                    hex::decode(&p.script).or_err("script")?,
                    p.satoshis,
                ));
            }
        }
        let n_fund: usize = fund_at.values().map(|v| v.len()).sum();
        n_fund_total += n_fund;
        // THE FUNDING: one transaction per height paying every prevout of that height, from the well's coinbases
        for (h, outs) in &fund_at {
            blk.mine_to(h - 1, &addr)?;
            let need: u64 = outs.iter().map(|o| o.3).sum::<u64>() + 10_000;
            let mut ins = Vec::new();
            let mut have = 0u64;
            while have < need {
                let c = coins.pop().ok_or_else(|| {
                    format!("the well is dry at height {h}: {have} of {need} satoshis")
                })?;
                have += c.2;
                ins.push(c);
            }
            let mut outputs: Vec<RawOutput> = outs
                .iter()
                .map(|o| RawOutput {
                    satoshis: o.3,
                    script: o.2.clone(),
                })
                .collect();
            let change = have - outs.iter().map(|o| o.3).sum::<u64>() - 1_000;
            outputs.push(RawOutput {
                satoshis: change,
                script: wscript.clone(),
            });
            let ftx = try_p2pkh_spend(&ins, outputs, &well, &wscript)?;
            let ftxid = ftx.txid_internal();
            // THE FUNDING BLOCK (2026-09-28, package B of the audit's (c)): assembled and submitted on the consensus path,
            // never through the block instance's mempool. The mempool counts the sigops of every output
            // (GetTransactionSigOpCount, validation.cpp:1235–1247) and refuses `bad-txns-too-many-sigops` on a COUNTING
            // ERROR whatever maxtxsigopscountspolicy says; one malformed lock among thousands of funded outputs raises it
            // (the 13,514-output funding transaction of 2026-09-27 23:40 UTC). After Genesis the block path counts none
            // (validation.cpp:559–566). The coinbase claims nothing and pays OP_1, as the spend blocks' does.
            let (prev, version, bits, _tip_time, tip_mtp) = blk.tip()?;
            let time = std::cmp::max(T0 + *h as u64, tip_mtp + 1) as u32;
            blk.rpc
                .call("setmocktime", serde_json::json!([time as u64]))
                .or_err("setmocktime")?;
            let cb = coinbase_tx(*h, 0, vec![0x51], format!("spec funding {h}").as_bytes());
            let (_fhdr, fblock) = assemble(version, prev, time, bits, &[cb, ftx.clone()]);
            match blk
                .rpc
                .call("submitblock", serde_json::json!([hex::encode(&fblock)]))
            {
                Ok(v) if v.is_null() => {}
                Ok(v) => return Err(format!("the funding block at height {h} was refused: {v}")),
                Err(e) => return Err(format!("the funding block at height {h} was refused: {e}")),
            }
            let at = blk.height()?;
            if at != *h {
                return Err(format!(
                    "the funding block is not at {h}: the chain is at {at}"
                ));
            }
            let confirmed = !blk
                .rpc
                .call("gettxout", serde_json::json!([txid_display_hex(&ftxid), 0]))
                .map(|v| v.is_null())
                .unwrap_or(true);
            if !confirmed {
                return Err(format!(
                    "the funding transaction at height {h} is not in the chain"
                ));
            }
            for (k, o) in outs.iter().enumerate() {
                funded.insert((o.0, o.1), (ftxid, k as u32));
            }
            coins.push((ftxid, outs.len() as u32, change));
            coins.sort_by_key(|c| std::cmp::Reverse(c.2));
            funding_txids.push((*h, txid_display_hex(&ftxid)));
        }
        blk.mine_to(spend_height - 1, &addr)?;
        println!("  group at {spend_height}: {} entries, {n_fund} outputs funded in {} transactions; the chain at {} ({:.1} s)", members.len(), fund_at.len(), blk.height()?, t0.elapsed().as_secs_f64());

        // the policy instance adopts the chain at spend_height − 1
        let st = std::process::Command::new(&oracle_sh)
            .args(["block", "adopt-into-policy"])
            .status()
            .or_err("spec-node.sh")?;
        if !st.success() {
            eprintln!("run_svnode --mode tx: adopt-into-policy failed");
            return Ok(1);
        }
        blk.reconnect();
        let mut mpn = Node::connect(&rpc_mp, &cookie_mp);
        mpn.reconnect();
        mpv = mpn.version();
        if mpv != format!("/Bitcoin SV:{}/", &SV_NODE_TAG[1..]) {
            eprintln!("run_svnode --mode tx: the policy instance reports {mpv}, the pin is bitcoin-sv {SV_NODE_TAG}");
            return Ok(1);
        }
        let mp_height = mpn.height()?;
        if mp_height != spend_height - 1 {
            eprintln!(
                "run_svnode --mode tx: the policy instance is at {mp_height}, not {}",
                spend_height - 1
            );
            return Ok(1);
        }
        settings_mp = mpn
            .rpc
            .call("getsettings", serde_json::json!([]))
            .unwrap_or(serde_json::Value::Null);
        println!("  the policy instance {rpc_mp} ({mpv}) adopted the chain at {mp_height}; maxscriptnumlengthpolicy {}", settings_mp["maxscriptnumlengthpolicy"]);

        // THE SPENDS: one block per entry at spend_height on the block instance; the mempool road on the policy instance
        // the spend block's time: above the tip's median time past (`ContextualCheckBlockHeader`: `time-too-old` at or below
        // it) and at or after the schedule's T0 + height; the node's miner sets a block's time to the median plus one when the
        // mocktime lags, so the chain's times run AHEAD of T0 + height (measured: +166 s by 5,000 blocks): the tip decides
        let (prev, version, bits, tip_time, tip_mtp) = blk.tip()?;
        let time = std::cmp::max(T0 + spend_height as u64, tip_mtp + 1) as u32;
        blk.rpc
            .call("setmocktime", serde_json::json!([time as u64]))
            .or_err("setmocktime")?;
        tip_times.push((spend_height, tip_time, tip_mtp, time as u64));
        println!("  the spend block at {spend_height}: time {time} (the tip's time {tip_time}, its median time past {tip_mtp}; T0 + height {})", T0 + spend_height as u64);
        for &ix in members {
            let mut e = entries[ix].clone();
            let Some(s) = spec.get(&e.id) else {
                undecided += 1;
                rewritten[ix] = Some(e);
                continue;
            };
            let mut tx = RawTx::decode(&hex::decode(&e.tx).or_err("tx hex")?).or_err("tx frame")?;
            for i in tx.inputs.iter_mut() {
                if is_null_outpoint(&i.txid, i.vout) {
                    continue;
                }
                let (ftxid, vout) = *funded
                    .get(&(i.txid, i.vout))
                    .or_err("a spent outpoint with no funding output")?;
                i.txid = ftxid;
                i.vout = vout;
            }
            let is_coinbase =
                tx.inputs.len() == 1 && is_null_outpoint(&tx.inputs[0].txid, tx.inputs[0].vout);
            // the road's own coinbase pays OP_1 (value 0, NO sigop): a P2PKH output's OP_CHECKSIG would add one sigop to the block
            // and tip a transaction at exactly the pre-Genesis limit over the BLOCK's (validation.cpp:3362–3365, 20,000 per MB)
            let txs: Vec<RawTx> = if is_coinbase {
                vec![tx.clone()]
            } else {
                vec![
                    coinbase_tx(
                        spend_height,
                        0,
                        vec![0x51],
                        format!("spec {}", e.id).as_bytes(),
                    ),
                    tx.clone(),
                ]
            };
            let (hdr, block_bytes) = assemble(version, prev, time, bits, &txs);
            let block_side = match blk.rpc.call(
                "submitblock",
                serde_json::json!([hex::encode(&block_bytes)]),
            ) {
                Ok(v) if v.is_null() => {
                    accepted_blocks += 1;
                    blk.rpc
                        .call(
                            "invalidateblock",
                            serde_json::json!([txid_display_hex(&hdr.hash())]),
                        )
                        .or_err("invalidateblock")?;
                    NodeSide {
                        kind: "valid".into(),
                        code: None,
                        native: String::new(),
                        unknown: false,
                    }
                }
                Ok(v) => {
                    let reason = v.as_str().unwrap_or("").to_string();
                    let code = svnode_codes::tx_reason_code(&reason);
                    if reason == "duplicate" || reason == "inconclusive" {
                        NodeSide {
                            kind: "undecided".into(),
                            code: None,
                            native: format!("submitblock: {reason}"),
                            unknown: false,
                        }
                    } else {
                        NodeSide {
                            kind: "invalid".into(),
                            code: code.clone(),
                            native: format!("submitblock: {reason}"),
                            unknown: code.is_none(),
                        }
                    }
                }
                Err(err) => NodeSide {
                    kind: "undecided".into(),
                    code: None,
                    native: format!("submitblock: {err}"),
                    unknown: true,
                },
            };
            let mp_side = if is_coinbase {
                NodeSide {
                    kind: "undecided".into(),
                    code: None,
                    native: "a coinbase never enters a mempool".into(),
                    unknown: false,
                }
            } else {
                match mpn.rpc.call(
                    "sendrawtransaction",
                    serde_json::json!([hex::encode(tx.encode()), false, true]),
                ) {
                    Ok(_) => NodeSide {
                        kind: "valid".into(),
                        code: None,
                        native: String::new(),
                        unknown: false,
                    },
                    Err(err) => {
                        let msg = Rpc::error_message(&err).unwrap_or_else(|| err.clone());
                        let reason = svnode_codes::mempool_reason(&msg).to_string();
                        let code = svnode_codes::tx_reason_code(&reason);
                        NodeSide {
                            kind: "invalid".into(),
                            code: code.clone(),
                            native: format!("sendrawtransaction: {msg}"),
                            unknown: code.is_none(),
                        }
                    }
                }
            };
            for side in [&block_side, &mp_side] {
                if side.unknown {
                    *unknown_reasons.entry(side.native.clone()).or_insert(0) += 1;
                }
                if side.kind == "undecided" {
                    undecided += 1;
                }
            }
            if record {
                // #57: retain earlier node keys as measurements of their own release.
                e.expect
                    .insert(comparison_key.clone(), combined_json(&s.spec));
                e.expect
                    .insert(comparison_mp_key.clone(), combined_json(&s.spec_mempool));
                e.expect.insert(SV_NODE_KEY.into(), side_json(&block_side));
                e.expect
                    .insert(SV_NODE_MEMPOOL_KEY.into(), side_json(&mp_side));
            }
            for (column, sv, side) in [
                ("spec", &s.spec, &block_side),
                ("spec-mempool", &s.spec_mempool, &mp_side),
            ] {
                if side.kind == "undecided"
                    || sv.verdict == "unimplemented"
                    || sv.verdict == "undefined-in-reference"
                {
                    continue;
                }
                let (cv, cc) = combined(sv);
                if cv == side.kind
                    && column == "spec"
                    && bip34_qualified(&tx, spend_height, &side.kind)
                {
                    *agree_qualified.entry(column.to_string()).or_insert(0) += 1;
                    qualified.push(serde_json::json!({"id": e.id, "column": column, "verdict": side.kind, "rule": "bip34"}));
                    continue;
                }
                if cv == side.kind {
                    *agree.entry(column.to_string()).or_insert(0) += 1;
                    if side.kind == "invalid" {
                        let sc = cc.clone().unwrap_or_default();
                        let ec = side.code.clone().unwrap_or_else(|| "(no row)".into());
                        if sc != ec {
                            *code_notes.entry((column.to_string(), sc, ec)).or_insert(0) += 1;
                        }
                    }
                    continue;
                }
                let ex = rules_table.as_ref().and_then(|rs| {
                    rs.explain(&rules::observe(
                        &e,
                        &tx,
                        column,
                        &cv,
                        cc.as_deref(),
                        &side.kind,
                        side.code.as_deref(),
                        &side.native,
                    ))
                });
                let class = ex
                    .as_ref()
                    .map(|x| x.rule.clone())
                    .unwrap_or_else(|| rules::UNEXPLAINED.to_string());
                let key = (column.to_string(), class.clone());
                let size = e.tx.len();
                let c = counts.entry(key).or_insert((0, None, ex));
                c.0 += 1;
                let better = match &c.1 {
                    None => true,
                    Some((sz, _, _, _)) => size < *sz,
                };
                if better {
                    c.1 = Some((size, e.clone(), combined_json(sv), side_json(side)));
                }
                if class == rules::UNEXPLAINED && divergences.len() < 60 {
                    divergences.push(format!(
                        "{column} {} ({}, rule {}, version {}): spec {cv}{} vs the node {} {}",
                        e.id,
                        e.family,
                        e.rule,
                        tx.version,
                        cc.as_ref().map(|c| format!(" {c}")).unwrap_or_default(),
                        side.kind,
                        side.native
                    ));
                }
            }
            if dump.is_some() {
                dump_lines.push(serde_json::json!({"id": e.id, "family": e.family, "rule": e.rule, "spec": combined_json(&s.spec), "spec-mempool": combined_json(&s.spec_mempool), "block": side_json(&block_side), "mempool": side_json(&mp_side)}).to_string());
            }
            rewritten[ix] = Some(e);
        }
        mp = Some(mpn);
    }
    let rewritten: Vec<Entry> = rewritten
        .into_iter()
        .map(|e| e.or_err("every entry rewritten"))
        .collect::<Result<_, _>>()?;
    let spend_height = *groups.keys().next_back().unwrap_or(&0);
    let mp_calls = mp.as_ref().map(|m| m.rpc.calls).unwrap_or(0);
    if let Some(d) = &dump {
        std::fs::write(
            d,
            dump_lines.join("\n") + if dump_lines.is_empty() { "" } else { "\n" },
        )
        .or_err("dump file")?;
    }
    println!(
        "run_svnode --mode tx: {corpus_name}/{file_name} ({n} entries) vs {SV_NODE_KEY} ({bv}) by BLOCK-CONNECT at height {spend_height} on {rpc_block} and by sendrawtransaction on the policy instance {rpc_mp} ({mpv}); the spec at {spec_key} ({config}), the gate and the scripts together; {accepted_blocks} blocks accepted then invalidated; {} RPC calls; {:.1} s",
        blk.rpc.calls + mp_calls, t0.elapsed().as_secs_f64()
    );
    println!(
        "  agree: {}; undecided runs {undecided}; reasons outside the table {}",
        agree
            .iter()
            .map(|(c, k)| format!("{c} {k}"))
            .collect::<Vec<_>>()
            .join(", "),
        unknown_reasons.values().sum::<u64>()
    );
    println!(
        "  agree at the instance's BIP34 height {INSTANCE_BIP34_HEIGHT} only (R2, apart from the above): {} [{}]",
        if agree_qualified.is_empty() { "none".to_string() } else { agree_qualified.iter().map(|(c, k)| format!("{c} {k}")).collect::<Vec<_>>().join(", ") },
        qualified.iter().filter_map(|q| q["id"].as_str()).collect::<Vec<_>>().join(", ")
    );
    let out_dir = format!("{witnesses_dir}/sv-node");
    std::fs::create_dir_all(&out_dir).or_err("witnesses dir")?;
    let mut witness_lines: Vec<String> = Vec::new();
    let mut summary: Vec<serde_json::Value> = Vec::new();
    for ((column, rule), (cnt, smallest, ex)) in &counts {
        let (_, we, a_v, b_v) = smallest
            .as_ref()
            .or_err("a divergence class without its smallest witness")?;
        let (decided_by, ruling, note) = match ex {
            Some(x) => (x.decided_by.clone(), x.ruling.clone(), x.note.clone()),
            None => (format!("the reference itself (bitcoin-sv {SV_NODE_TAG}, a block on the spec's own instance / its mempool): to be read from source before any ruling"), "open".to_string(), String::new()),
        };
        let mut w = we.clone();
        w.id = format!("witness-sv-node-{corpus_name}-{column}-{rule}-{}", we.id);
        let a_key = if column == "spec-mempool" {
            mempool_key.clone()
        } else {
            spec_key.clone()
        };
        let b_key = if column == "spec-mempool" {
            SV_NODE_MEMPOOL_KEY.to_string()
        } else {
            SV_NODE_KEY.to_string()
        };
        w.divergence = Some(Divergence {
            rule: rule.clone(), a: a_key.clone(), b: b_key.clone(), a_verdict: a_v.clone(), b_verdict: b_v.clone(),
            decided_by, ruling: ruling.clone(), minimized: None, minimized_prevouts: None,
            note: format!("{cnt} entries of {corpus_name} diverge from the node in the {column} column on the block road; this is the smallest (from {}). {}", we.id, if note.is_empty() { "A disagreement with the node is the spec's bug until a human proves otherwise from source (CLAUDE.md rule 4).".to_string() } else { note }),
        });
        w.expect.insert(b_key, b_v.clone());
        w.expect.insert(a_key, a_v.clone());
        witness_lines.push(serde_json::to_string(&w).or_err("witness json")?);
        summary.push(serde_json::json!({"column": column, "rule": rule, "entries": cnt, "ruling": ruling, "witness": w.id, "from": we.id}));
    }
    if !code_notes.is_empty() {
        println!("  tier-2 notes (both invalid, the codes differ; never a divergence):");
        for ((column, sc, ec), k) in &code_notes {
            println!("    {column}: spec {sc} vs the node {ec}: {k}");
        }
    }
    let out_path = format!("{out_dir}/{corpus_name}.jsonl");
    std::fs::write(
        &out_path,
        witness_lines.join("\n") + if witness_lines.is_empty() { "" } else { "\n" },
    )
    .or_err("witness file")?;
    let wsha = hex::encode(sha256(
        &std::fs::read(&out_path).or_err("witness file read back")?,
    ));
    let man_path = format!("{out_dir}/manifest.json");
    let mut man: serde_json::Value = std::fs::read_to_string(&man_path)
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_else(|| serde_json::json!({}));
    man[&corpus_name] = serde_json::json!({
        "file": format!("{corpus_name}.jsonl"), "sha256": wsha, "witnesses": witness_lines.len(), "corpus": corpus_path, "spec": spec_key, "spec_config": config,
        "spec_recorded_keys": {"spec": comparison_key, "spec-mempool": comparison_mp_key},
        "mode": "block-connect (the consensus column: a block the harness assembles, submitblock, invalidateblock) and sendrawtransaction with dontcheckfee (the policy column) on the policy instance's copy of the chain",
        "node": SV_NODE_KEY, "node_reported": bv, "node_mempool_reported": mpv, "rpc_block": rpc_block, "rpc_mempool": rpc_mp,
        "base_height": start_height, "spend_height": spend_height, "spend_heights": groups.keys().collect::<Vec<_>>(), "outputs_funded": n_fund_total, "t0": T0, "tips": tip_times.iter().map(|(h, t, m, b)| serde_json::json!({"spend_height": h, "tip_time": t, "tip_mediantime": m, "block_time": b})).collect::<Vec<_>>(), "funding": funding_txids.iter().map(|(h, t)| serde_json::json!({"height": h, "txid": t})).collect::<Vec<_>>(),
        "well": addr, "policy_settings": settings_mp, "entries": n, "undecided_runs": undecided, "unknown_reasons": unknown_reasons,
        "rules": summary, "code_notes": code_notes.iter().map(|((c, s, e), k)| serde_json::json!({"column": c, "spec": s, "node": e, "entries": k})).collect::<Vec<_>>(),
        "generated": std::env::var("SOURCE_DATE").unwrap_or_else(|_| "2026-09-26".into()),
    });
    for (k, v) in road_accounting(&agree, &agree_qualified, &qualified) {
        man[&corpus_name][k] = v;
    }
    std::fs::write(
        &man_path,
        serde_json::to_string_pretty(&man).or_err("witness manifest json")? + "\n",
    )
    .or_err("witness manifest")?;
    println!(
        "  witnesses: {} written to {out_path} (sha256 {wsha}); manifest {man_path}",
        witness_lines.len()
    );
    if !unknown_reasons.is_empty() {
        println!("  node reasons outside the cited tables (the table must grow, never guess):");
        for (m, c) in &unknown_reasons {
            println!("    {c} × {m}");
        }
    }
    if record {
        let text: String = rewritten
            .iter()
            .map(|e| serde_json::to_string(e).map(|l| l + "\n"))
            .collect::<Result<String, _>>()
            .or_err("corpus json")?;
        std::fs::write(&corpus_path, &text).or_err("rewrite corpus")?;
        let sha = hex::encode(sha256(text.as_bytes()));
        if let (Some(mp_path), Some(mut m)) = (manifest_path, manifest) {
            m.sha256 = sha.clone();
            m.implementations.retain(|i| {
                i.version != SV_NODE_TAG || (i.name != "sv-node" && i.name != "sv-node-mempool")
            });
            let mut cfg = BTreeMap::new();
            cfg.insert("mode".to_string(), serde_json::json!("block-connect: the entry's transaction (its inputs rewritten to the funding outpoints mined at prevouts[i].height) in a block the harness assembles at params.spend_height on the block instance (harness/oracle/bitcoin-block.conf: mainnet activation heights, every policy setting zeroed, a chain baked by oracle_chain), submitblock's verdict, the block invalidated after acceptance; compared with the spec's gate and script verdict together (D97)"));
            cfg.insert("node".to_string(), serde_json::json!(bv));
            cfg.insert("rpc".to_string(), serde_json::json!(rpc_block));
            cfg.insert("base_height".to_string(), serde_json::json!(start_height));
            cfg.insert("spend_height".to_string(), serde_json::json!(spend_height));
            cfg.insert("t0".to_string(), serde_json::json!(T0));
            let mut block_cfg = cfg.clone();
            block_cfg.extend(road_accounting(&agree, &agree_qualified, &qualified));
            m.implementations.push(ImplConfigJson {
                name: "sv-node".into(),
                version: SV_NODE_TAG.into(),
                config: block_cfg,
            });
            cfg.insert("mode".to_string(), serde_json::json!("sendrawtransaction <hex> false true (allowhighfees false, dontcheckfee true) on the POLICY instance holding a copy of the block instance's chain at spend_height − 1 (spec-node.sh block adopt-into-policy): the node's mempool verdict under its default policy, the fee check skipped; a coinbase entry is undecided here"));
            cfg.insert("node".to_string(), serde_json::json!(mpv));
            cfg.insert("rpc".to_string(), serde_json::json!(rpc_mp));
            let mut pol = BTreeMap::new();
            for k in [
                "maxscriptsizepolicy",
                "maxopsperscriptpolicy",
                "maxscriptnumlengthpolicy",
                "maxstackmemoryusagepolicy",
                "maxtxsizepolicy",
                "maxtxsigopscountspolicy",
                "maxpubkeyspermultisigpolicy",
            ] {
                pol.insert(k.to_string(), settings_mp[k].clone());
            }
            cfg.insert("policy_settings".to_string(), serde_json::json!(pol));
            m.implementations.push(ImplConfigJson {
                name: "sv-node-mempool".into(),
                version: SV_NODE_TAG.into(),
                config: cfg,
            });
            std::fs::write(
                &mp_path,
                serde_json::to_string_pretty(&m).or_err("manifest json")? + "\n",
            )
            .or_err("manifest")?;
            println!("  recorded {SV_NODE_KEY}, {SV_NODE_MEMPOOL_KEY} into {corpus_path}; new sha256 {sha} in {}", mp_path.display());
        }
    }
    let n_div: u64 = counts
        .iter()
        .filter(|((_, r), _)| r == rules::UNEXPLAINED)
        .map(|(_, c)| c.0)
        .sum();
    let n_classified: u64 = counts
        .iter()
        .filter(|((_, r), _)| r != rules::UNEXPLAINED)
        .map(|(_, c)| c.0)
        .sum();
    let n_unknown: u64 = unknown_reasons.values().sum();
    if n_div > 0 || n_unknown > 0 || n == 0 {
        println!("run_svnode --mode tx: RED ({n_div} unexplained divergences from the reference, {n_classified} classified, {n_unknown} reasons outside the tables)");
        for d in &divergences {
            println!("  DIVERGENCE {d}");
        }
        return Ok(1);
    }
    println!("run_svnode --mode tx: GREEN (every divergence from the reference explained by a cited row: {n_classified} classified, none unexplained)");
    Ok(0)
}

#[cfg(test)]
mod tests {
    #[test]
    fn limited_run_never_writes_the_committed_witnesses() {
        // #32 P13 and its lens: the committed directory by any spelling, a path below it, and a path that does not
        // resolve are refused under --limit; a fresh scratch path is accepted
        let root = std::env::temp_dir().join(format!("txroad-p13-{}", std::process::id()));
        let committed = root.join("corpus").join("witnesses");
        std::fs::create_dir_all(&committed).unwrap();
        let a = |w: &str| vec!["--witnesses".to_string(), w.to_string()];
        let c = committed.to_string_lossy().to_string();
        assert!(super::witnesses_dir_of(&a(&c), Some(1), &root, "t").is_err());
        assert!(
            super::witnesses_dir_of(&a(&format!("{c}/../witnesses")), Some(1), &root, "t").is_err()
        );
        assert!(super::witnesses_dir_of(&a(&format!("{c}/new/sub")), Some(1), &root, "t").is_err());
        assert!(super::witnesses_dir_of(
            &a(&format!("{}/nowhere/../x", root.display())),
            Some(1),
            &root,
            "t"
        )
        .is_err());
        assert!(super::witnesses_dir_of(&a(&c), Some(1), &root.join("absent"), "t").is_err());
        assert!(super::witnesses_dir_of(
            &a(&root.join("scratch-new").to_string_lossy()),
            Some(1),
            &root,
            "t"
        )
        .is_ok());
        assert!(super::witnesses_dir_of(&a(&c), None, &root, "t").is_ok());
        std::fs::remove_dir_all(&root).ok();
    }

    use super::*;
    use crate::txraw::RawInput;

    fn coinbase(script: Vec<u8>) -> RawTx {
        RawTx {
            version: 2,
            inputs: vec![RawInput {
                txid: [0u8; 32],
                vout: 0xffff_ffff,
                script,
                sequence: 0xffff_ffff,
            }],
            outputs: vec![RawOutput {
                satoshis: 0,
                script: vec![0x51],
            }],
            lock_time: 0,
        }
    }

    #[test]
    fn bip34_split_of_a_coinbase() {
        // a coinbase of two zero pushes at 620,600, accepted: qualified (mainnet would refuse it, bad-cb-height)
        assert!(bip34_qualified(
            &coinbase(vec![0x00, 0x00]),
            620_600,
            "valid"
        ));
        // refused at any BIP34 height (bad-cb-length): an ordinary agreement
        assert!(!bip34_qualified(&coinbase(vec![0x00]), 620_600, "invalid"));
        // opening with its height (the harness's own coinbase): passes the rule, ordinary
        assert!(!bip34_qualified(
            &crate::block::coinbase_tx(620_600, 0, vec![0x51], b"spec x"),
            620_600,
            "valid"
        ));
        assert!(opens_with_height(&[0x03, 0x38, 0x78, 0x09, 0x00], 620_600));
        // below mainnet's BIP34 height, or at the instance's: ordinary
        assert!(!bip34_qualified(
            &coinbase(vec![0x00, 0x00]),
            MAINNET_BIP34_HEIGHT - 1,
            "valid"
        ));
        assert!(!bip34_qualified(
            &coinbase(vec![0x00, 0x00]),
            INSTANCE_BIP34_HEIGHT,
            "valid"
        ));
        // a spend (a non-null outpoint) is never qualified
        let mut spend = coinbase(vec![0x00, 0x00]);
        spend.inputs[0].txid = [1u8; 32];
        spend.inputs[0].vout = 0;
        assert!(!bip34_qualified(&spend, 620_600, "valid"));
    }

    /// The recorded block road on corpus/tx: the split read from the recorded verdicts equals the witness manifest's
    /// (R2.3: the manifest re-cut from the record, no run): two qualified agreements (tx-00029, tx-00030), both valid.
    #[test]
    fn recorded_tx_corpus_splits_two() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("..");
        let text = std::fs::read_to_string(root.join("corpus/tx/tx.jsonl")).expect("corpus/tx");
        let man: serde_json::Value = serde_json::from_str(
            &std::fs::read_to_string(root.join("corpus/witnesses/sv-node/manifest.json")).unwrap(),
        )
        .unwrap();
        let t = &man["tx"];
        let node_key = t["node"]
            .as_str()
            .expect("the recording names its node key");
        let mut ids = Vec::new();
        for line in text.lines().filter(|l| !l.trim().is_empty()) {
            let e: Entry = serde_json::from_str(line).expect("entry");
            let tx = RawTx::decode(&hex::decode(&e.tx).unwrap()).unwrap();
            let node = e
                .expect
                .get(node_key)
                .map(|x| x.verdict.clone())
                .unwrap_or_default();
            if bip34_qualified(&tx, e.params.spend_height, &node) {
                ids.push((e.id.clone(), node));
            }
        }
        assert_eq!(
            ids,
            vec![
                ("tx-00029".to_string(), "valid".to_string()),
                ("tx-00030".to_string(), "valid".to_string())
            ]
        );
        assert_eq!(t["agree_instance_qualified"]["spec"], 2);
        assert_eq!(
            t["activation_context"]["bip34_height"],
            INSTANCE_BIP34_HEIGHT
        );
        let man_ids: Vec<&str> = t["instance_qualified"]
            .as_array()
            .unwrap()
            .iter()
            .map(|q| q["id"].as_str().unwrap())
            .collect();
        assert_eq!(man_ids, vec!["tx-00029", "tx-00030"]);
    }

    /// The corpus manifest's `sv-node` config and the witness manifest's `tx` entry carry the same accounting (both
    /// written by `road_accounting`): `agree` (the mempool column's among it), `agree_instance_qualified` with the ids,
    /// the activation context.
    #[test]
    fn manifests_agree_on_the_split() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("..");
        let wit: serde_json::Value = serde_json::from_str(
            &std::fs::read_to_string(root.join("corpus/witnesses/sv-node/manifest.json")).unwrap(),
        )
        .unwrap();
        let cor: serde_json::Value = serde_json::from_str(
            &std::fs::read_to_string(root.join("corpus/tx/manifest.json")).unwrap(),
        )
        .unwrap();
        let cfg = &cor["implementations"]
            .as_array()
            .unwrap()
            .iter()
            .find(|i| {
                i["name"] == "sv-node"
                    && format!("sv-node@{}", i["version"].as_str().unwrap_or(""))
                        == wit["tx"]["node"].as_str().unwrap_or("")
            })
            .expect("the recorded node in corpus/tx's manifest")["config"];
        for k in road_accounting(&BTreeMap::new(), &BTreeMap::new(), &[]).keys() {
            assert_eq!(cfg[k], wit["tx"][k], "{k}");
        }
        assert_eq!(cfg["agree"]["spec"], 36);
        assert_eq!(cfg["agree"]["spec-mempool"], 36);
        assert_eq!(cfg["agree_instance_qualified"]["spec"], 2);
    }
}
