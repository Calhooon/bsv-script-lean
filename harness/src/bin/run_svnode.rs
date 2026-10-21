//! run_svnode (this repo's; #27, `docs/DESIGN.md` §7): the differential of the spec's evaluator against the
//! REFERENCE, bitcoin-sv v1.2.3 (`docs/PROVENANCE.md` §1a), through its `verifyscript` RPC
//! (`src/rpc/misc.cpp:506–914`) on the spec's own node instances (`harness/oracle/`, the same pinned binary): the
//! recorded runs used the two local instances below (the consensus instance and the policy instance); the always-on
//! host's instance (`spec-node.sh mini`) has no policy instance. A disagreement with the node is the spec's bug until
//! a human proves otherwise from source (CLAUDE.md rule 4). Both modes load `harness/rules/sv-node.json`: #57
//! records the reference's changed operand rule under one cited class; every unmatched divergence is RED. Its one exemption is an entry the spec marks `undefined-in-reference` (none
//! since D72), which the run reports with the node's verdict beside the spec's; no other family is exempt. The tx
//! mode (`--mode tx`, `harness/src/txroad.rs`) is different: it loads `harness/rules/sv-node.json` and files a
//! divergence under the named classes of that table.
//!
//! Per entry, TWO calls, one per column (the block word to the consensus instance, the mempool word to the policy
//! instance when `--rpc-mempool` names it): `verifyscript([{tx, n, flags, reportflags: true, txo: {lock, value, height}}, …],
//! stopOnFirstInvalid, totalTimeout)`, one element per input (`:657–833`): the flag word per input is the
//! spec's own (`flags_oracle.rs`: `Params.derive` echoed by `eval/bsvs eval`), so the node judges the input under
//! exactly the word the spec judged it under; `txo.height` is the prevout's height, which the node maps to the
//! UTXO-era bits under ITS activation heights (`:813–822`; the instance's `bitcoin.conf` carries mainnet's, so
//! the bits agree) and `reportflags` echoes the word the node applied (`:909–912`): the runner refuses a run
//! where it differs from the spec's (a configuration drift, never a verdict). `stopOnFirstInvalid` is passed
//! explicitly (its help says the default is true, `:565`; the code makes it false, `:606–612`: rule 15,
//! recorded); `totalTimeout` is pinned (`--total-timeout`, default 60,000 ms; the node's own per-script wall is
//! `maxstdtxvalidationduration`, `:867–873`, five minutes in `harness/oracle/bitcoin.conf`). A `timeout` or
//! `skipped` result is `undecided` (`:843–851`, `:877–882`), never a verdict. The node's `description` is
//! mapped back to `SCRIPT_ERR_*` through the cited table `svnode_codes.rs` (the text of `ScriptErrorString`).
//!
//! The consensus path (DESIGN Q6, answered from source): `verifyscript` hard-codes `consensus = false`
//! (`:855–856`), which the interpreter reads only in `make_eval_script_params`/`make_verify_script_params`
//! (`interpreter.cpp:2282–2302`, the five limit getters `configscriptpolicy.cpp:65–154`; no other read at the
//! pin). With every policy setting zeroed the getters return the consensus numbers: the ops, script-size,
//! multisig-keys and stack-memory setters store the post-Genesis maximum for a 0 (`configscriptpolicy.cpp:182`,
//! `:232`, `:259`, `:291`; the consensus stack memory `:282`), while the number-length setter stores the 0 itself
//! (`:211`) and its getter resolves a 0 to the era's consensus width (`:97–106`): the RPC evaluates under the
//! consensus LIMITS on the policy PATH, and the two differ in nothing the interpreter reads. The standardness
//! gate never runs here (it is the mempool's, `validation.cpp`, outside `CScriptCheck`).
//!
//! Two columns as for the SDK engines: `spec` (the node under the block word of the entry's own params against
//! the spec under the same) and `spec-mempool` (both under the relay word). The verdicts are recorded with
//! `--record` as `sv-node@v1.2.3` and `sv-node-mempool@v1.2.3`.
//!
//! TWO INSTANCES, ONE PER COLUMN (2026-09-24, the eras corpus's first record run): the spec's `spec` column is the
//! consensus limits (`Params.derive` with `consensus = true`), which the zeroed-policy instance applies on the policy
//! path (Q6 above); the spec's `spec-mempool` column is SV-node's mainnet DEFAULT policy (`consensus = false`:
//! `maxscriptnumlengthpolicy` 10,000, `policy.h:156`, and the other caps of `docs/PARAMETERS.md` §1), which only an
//! instance left at its defaults applies. `--rpc-mempool` names that second instance (`harness/oracle/bitcoin-policy.conf`,
//! `spec-node.sh policy start`, RPC 18565): its version string is checked, its activation heights probed and its
//! policy read back like the first's; the mempool column's calls go to it. Without it the mempool column runs on the
//! consensus instance and the run says so: an entry that reaches a policy LIMIT (eras-00042, a 1,048,577-byte number
//! on a post-Chronicle coin: 32,000,000 at consensus, 10,000 at the policy width) then diverges by configuration, not
//! by semantics, and the run is RED on it.
//!
//! THE BLOCK ROAD (2026-09-26, D97): `--mode tx` hands the run to `harness/src/txroad.rs` (the tx.* families: a block the
//! harness assembles on the block instance, and the policy instance's mempool; the spec's gate and script verdict together).
//!
//! THE LEAN-FREE RUN (#31, 2026-09-29): `--words-from <manifest.json>` serves the words a witness manifest recorded for
//! this corpus (`FlagsOracle::recorded`), nothing asked of `eval/bsvs`; with a spec file from the corpus's recorded
//! `spec@` keys (`spec_recorded`) the run needs no Lean build. `harness/run` is the one command over both modes.
//!
//! THE TEST'S OWN CHAIN (2026-10-06, lane cpp-era-49: #49's `txvalidationcache` rows judged at their own era). Three options,
//! for instances started on the oracle's confs with `-genesisactivationheight`/`-chronicleactivationheight` on the command
//! line and A CHAIN of the test's shape (`tools/cpp_era_run.sh`, `tools/cpp_era_chain.py`): `--genesis-height G
//! --chronicle-height C` (both) name the instances' activation heights, so the era probe expects the bits those heights give
//! (`misc.cpp:813–822` under them) and the mempool word is asked of the spec on the same chain (`FlagsOracle::with_heights`,
//! the CLI's `--genesis-height`/`--chronicle-height`); `--spec-config <name>` is the CLI's `--config` the spec file was
//! computed under (`sv-regtest` for the fixture's chain), and the spec file's `config` must read `<name>(genesis=G,chronicle=C)`
//! or the run is refused (exit 2: a spec column of another chain never meets this node); `--txo-from-chain` omits `txo`, so the
//! node reads each coin's lock, value and HEIGHT from its own UTXO set (`misc.cpp:795–803`, the coins view of the tip and the
//! mempool, `:658–660`) exactly as `CheckInputs` reads `tipView`, the coin's coinbase flag and height the chain's own; a
//! coin the chain lacks is the RPC's error, never a verdict. `reportflags` still checks the applied word against the given.
//!
//! Run: cargo run --release --locked --bin run_svnode -- --corpus ../corpus/seed/seed.jsonl --spec <spec.jsonl> [--words-from <manifest.json>]
//!      [--rpc http://127.0.0.1:18563] [--cookie <path>] [--rpc-mempool http://127.0.0.1:18565] [--cookie-mempool <path>]
//!      [--witnesses ../corpus/witnesses] [--record] [--limit N] [--total-timeout 60000] [--dump <file>]
//!      [--spec-config sv-regtest --genesis-height G --chronicle-height C] [--txo-from-chain] [--cells <file>]
//!
//! `--cells <file>` (lane fuzz-cut3, 2026-10-16): one JSON line per cell run, agreeing or not (`column`, `id`, the node's
//! `node` verdict and `node_code`, the reason `svnode_codes.rs` maps its description to), never the node's description
//! itself; the fuzz campaign's signature reads it (tools/fuzz_batch.py).

use std::collections::BTreeMap;
use std::io::BufRead;
use std::path::PathBuf;
use std::time::Duration;

use bsv_rs::primitives::hash::sha256;
use bsv_script_harness::corpus::{Divergence, Entry, ExpectJson, ImplConfigJson};
use bsv_script_harness::differential::{read_spec, spec_json, CorpusInput};
use bsv_script_harness::fail::OrErr;
use bsv_script_harness::flags_oracle::FlagsOracle;
use bsv_script_harness::rpc::Rpc;
use bsv_script_harness::rules::{self, RuleSet, UNEXPLAINED};
use bsv_script_harness::svnode_codes;
use bsv_script_harness::txraw::RawTx;
use bsv_script_harness::SV_NODE_TAG;

pub const SV_NODE_KEY: &str = "sv-node@v1.2.3";
pub const SV_NODE_MEMPOOL_KEY: &str = "sv-node-mempool@v1.2.3";
/// The version string the pinned build reports (`docs/PROVENANCE.md` §1a `reference.version_string`).
pub const SV_NODE_VERSION_STRING: &str = "v1.2.3.0-g6504a3aff-dev";

fn arg(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1).cloned())
}

/// The node's verdict on one run of an entry, in the spec's vocabulary.
struct NodeSide {
    kind: String,
    input: Option<usize>,
    code: Option<&'static str>,
    native: String,
    unknown_description: bool,
    /// the flag word the node reports it applied, per input, when it differs from the word given
    flag_drift: Vec<(usize, u32, u32)>,
}

fn side_of(results: &[serde_json::Value], words: &[u32]) -> NodeSide {
    let mut drift = Vec::new();
    for (i, r) in results.iter().enumerate() {
        if let Some(f) = r["flags"].as_i64() {
            let applied = f as u32;
            if i < words.len() && applied != words[i] {
                drift.push((i, words[i], applied));
            }
        }
    }
    for (i, r) in results.iter().enumerate() {
        let res = r["result"].as_str().unwrap_or("");
        let desc = r["description"].as_str().unwrap_or("").to_string();
        match res {
            "ok" => continue,
            "error" => {
                let row = svnode_codes::code_of(&desc);
                return NodeSide {
                    kind: "invalid".into(),
                    input: Some(i),
                    code: row.map(|r| r.code),
                    native: format!("error: {desc}"),
                    unknown_description: row.is_none(),
                    flag_drift: drift,
                };
            }
            "timeout" | "skipped" => {
                return NodeSide {
                    kind: "undecided".into(),
                    input: Some(i),
                    code: None,
                    native: format!("{res}: {desc}"),
                    unknown_description: false,
                    flag_drift: drift,
                };
            }
            other => {
                return NodeSide {
                    kind: "undecided".into(),
                    input: Some(i),
                    code: None,
                    native: format!("unknown result {other}: {desc}"),
                    unknown_description: true,
                    flag_drift: drift,
                };
            }
        }
    }
    NodeSide {
        kind: "valid".into(),
        input: None,
        code: None,
        native: String::new(),
        unknown_description: false,
        flag_drift: drift,
    }
}

fn side_json(s: &NodeSide) -> ExpectJson {
    ExpectJson {
        verdict: s.kind.clone(),
        code: s.code.map(|c| c.to_string()),
        reason: if s.native.is_empty() {
            None
        } else {
            Some(s.native.clone())
        },
        input: s.input,
    }
}

struct Count {
    n: u64,
    smallest: Option<(usize, Entry, ExpectJson, ExpectJson)>,
}

/// Which of the two instances a node is: the consensus instance (every policy cap zeroed, so the policy path applies
/// the consensus limits: the `spec` column) or the policy instance (the node's defaults: the `spec-mempool` column).
#[derive(Clone, Copy, PartialEq, Eq)]
enum Instance {
    Consensus,
    Policy,
}

/// The node under test is the pinned build and its configuration is the column's: the version string checked, the
/// policy read back through `getsettings` (zeroed for the consensus instance, `maxscriptnumlengthpolicy` at the
/// default 10,000 and nothing zeroed for the policy instance), the activation heights PROBED through `verifyscript`
/// itself (getsettings does not expose them: `reportflags` echoes the era bits the node derives from `txo.height`
/// at 620,537 / 620,538 / 943,815 / 943,816; misc.cpp:813–822, chainparams.cpp:18, 23; with `--genesis-height G
/// --chronicle-height C` the probe heights are G−1, G, C−1 and C and the bits expected are those heights' under G and C,
/// `protocol_era.cpp:21–35`). Exits on any drift.
fn check_instance(
    rpc: &mut Rpc,
    rpc_url: &str,
    which: Instance,
    heights: Option<(u32, u32)>,
) -> (String, serde_json::Value) {
    let label = match which {
        Instance::Consensus => "the consensus instance (harness/oracle/bitcoin.conf)",
        Instance::Policy => "the policy instance (harness/oracle/bitcoin-policy.conf)",
    };
    let info = match rpc.call("getnetworkinfo", serde_json::json!([])) {
        Ok(v) => v,
        Err(e) => {
            eprintln!("run_svnode: {label} at {rpc_url} does not answer: {e} (harness/oracle/spec-node.sh local|policy start)");
            std::process::exit(1);
        }
    };
    let subversion = info["subversion"].as_str().unwrap_or("").to_string();
    let settings = rpc
        .call("getsettings", serde_json::json!([]))
        .unwrap_or(serde_json::Value::Null);
    let node_version = format!("subversion {subversion}; version {}", info["version"]);
    if subversion != format!("/Bitcoin SV:{}/", &SV_NODE_TAG[1..]) {
        eprintln!("run_svnode: {label} reports {subversion}, the pin is bitcoin-sv {SV_NODE_TAG} ({SV_NODE_VERSION_STRING})");
        std::process::exit(1);
    }
    let mut config_drift = Vec::new();
    match which {
        Instance::Consensus => {
            for k in [
                "maxscriptsizepolicy",
                "maxopsperscriptpolicy",
                "maxpubkeyspermultisigpolicy",
            ] {
                let got = settings[k].as_i64().unwrap_or(-1);
                if got != 4_294_967_295 {
                    config_drift.push(format!(
                        "{k} = {got}, the zeroed policy reads back as 4294967295"
                    ));
                }
            }
            if let Some(got) = settings["maxstackmemoryusagepolicy"].as_i64() {
                if got != i64::MAX {
                    config_drift.push(format!("maxstackmemoryusagepolicy = {got}, the zeroed policy reads back as INT64_MAX"));
                }
            }
        }
        Instance::Policy => {
            // the node's defaults (docs/PARAMETERS.md §1): the two caps whose default differs from the consensus
            // maximum are read back (maxscriptsizepolicy 500,000 policy.h:93; maxstackmemoryusagepolicy 100,000,000);
            // the ops, sigops and pubkey caps default to UINT32_MAX and cannot be told from a zeroed cap here, and
            // getsettings evaluates maxscriptnumlengthpolicy at the era of the instance's chain tip, not the configured
            // post-Genesis value (4 at a pre-Genesis tip; the adopted policy instance prints 10,000), so the number
            // width is PROBED through verifyscript below
            for (k, want) in [
                ("maxscriptsizepolicy", 500_000i64),
                ("maxstackmemoryusagepolicy", 100_000_000),
            ] {
                let got = settings[k].as_i64().unwrap_or(-1);
                if got != want {
                    config_drift.push(format!("{k} = {got}, the node's default is {want} (the policy instance must run the defaults)"));
                }
            }
        }
    }
    {
        // the number-length width in force on the policy path, probed: a minimal 10,000-byte number and a minimal
        // 10,001-byte number read by OP_1ADD in the lock, a post-Chronicle coin (txo.height 943,816: the consensus
        // width 32,000,000, consensus.h:66) under the post-Chronicle mempool word 0x3D47FF. The policy instance
        // must refuse the second with SCRIPT_ERR_SCRIPTNUM_OVERFLOW (the default 10,000, policy.h:156, script_num.cpp:62)
        // and accept the first; the consensus instance (every cap zeroed) accepts both.
        let probe_tx = bsv_script_harness::flags_oracle::probe_tx_hex();
        let word: u32 = 0x003D_47FF;
        // a post-Chronicle coin under the configured heights too (943,816 is mainnet's; a later Chronicle height moves it)
        let probe_height: u32 = heights.map(|(_, c)| c.max(943_816)).unwrap_or(943_816);
        for (len, expect_ok) in [(10_000usize, true), (10_001, which == Instance::Consensus)] {
            let mut lock = vec![0x4d, (len & 0xff) as u8, (len >> 8) as u8];
            lock.extend(std::iter::repeat_n(0u8, len - 1));
            lock.push(0x01);
            lock.extend([0x8b, 0x75, 0x51]); // OP_1ADD OP_DROP OP_1
            let scripts = serde_json::json!([{"tx": probe_tx, "n": 0, "flags": word, "reportflags": true, "txo": {"lock": hex::encode(&lock), "value": 1, "height": probe_height}}]);
            match rpc.call("verifyscript", serde_json::json!([scripts, true, 5000])) {
                Ok(v) => {
                    let result = v[0]["result"].as_str().unwrap_or("").to_string();
                    let desc = v[0]["description"].as_str().unwrap_or("").to_string();
                    let ok = result == "ok";
                    if ok != expect_ok || (!expect_ok && !desc.contains("Script number overflow")) {
                        config_drift.push(format!("a minimal {len}-byte number under the mempool word on a post-Chronicle coin: the node says {result} {desc:?}; {label} must say {}", if expect_ok { "ok (within its number width)" } else { "error: Script number overflow (the policy default 10,000)" }));
                    }
                }
                Err(e) => {
                    config_drift.push(format!("the number-width probe ({len} bytes) failed: {e}"))
                }
            }
        }
    }
    {
        const UTXO_AFTER_GENESIS: u32 = 1 << 19;
        const UTXO_AFTER_CHRONICLE: u32 = 1 << 21;
        let word: u32 = 0x003D_462F; // the post-Chronicle block word: both era bits set
        let probe_tx = bsv_script_harness::flags_oracle::probe_tx_hex();
        // the heights expected: mainnet's (chainparams.cpp:18, 23) unless the run names the instances' own
        let (gh, ch) = heights.unwrap_or((620_538, 943_816));
        let whose = if heights.is_some() {
            "the configured heights"
        } else {
            "mainnet's heights"
        };
        let mut probe_heights = vec![gh.saturating_sub(1), gh, ch.saturating_sub(1), ch];
        probe_heights.sort_unstable();
        probe_heights.dedup();
        for height in probe_heights {
            // protocol_era.cpp:21–35: below genesis PreGenesis, below chronicle PostGenesis, else PostChronicle
            let (want_genesis, want_chronicle) = if height < gh {
                (false, false)
            } else if height < ch {
                (true, false)
            } else {
                (true, true)
            };
            let scripts = serde_json::json!([{"tx": probe_tx, "n": 0, "flags": word, "reportflags": true, "txo": {"lock": "51", "value": 1, "height": height}}]);
            match rpc.call("verifyscript", serde_json::json!([scripts, true, 1000])) {
                Ok(v) => {
                    let applied = v[0]["flags"].as_i64().unwrap_or(-1) as u32;
                    let g = applied & UTXO_AFTER_GENESIS != 0;
                    let c = applied & UTXO_AFTER_CHRONICLE != 0;
                    if g != want_genesis || c != want_chronicle {
                        config_drift.push(format!("txo.height {height}: the node derives UTXO_AFTER_GENESIS={g}, UTXO_AFTER_CHRONICLE={c}; {whose} ({gh}, {ch}) give {want_genesis}, {want_chronicle}"));
                    }
                }
                Err(e) => {
                    config_drift.push(format!("the era probe at height {height} failed: {e}"))
                }
            }
        }
    }
    if !config_drift.is_empty() {
        eprintln!("run_svnode: the configuration of {label} at {rpc_url} is not the column's:");
        for d in &config_drift {
            eprintln!("  {d}");
        }
        std::process::exit(1);
    }
    (node_version, settings)
}

/// The exit code of `run` (#132): an error that stood as an unwrap, expect or panic is reported with its words and exits 1.
fn main() -> std::process::ExitCode {
    match run() {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("run_svnode: {e}");
            std::process::ExitCode::from(1)
        }
    }
}

fn run() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();
    // THE BLOCK ROAD (D97, 2026-09-26): the tx.* families' two columns through a block and through the policy instance's mempool
    if arg(&args, "--mode").as_deref() == Some("tx") {
        std::process::exit(bsv_script_harness::txroad::main(args));
    }
    let corpus_path = arg(&args, "--corpus").or_err("--corpus <file.jsonl>")?;
    let spec_path = arg(&args, "--spec").or_err("--spec <spec.jsonl> (from `eval/bsvs corpus`)")?;
    let record = args.iter().any(|a| a == "--record");
    let limit: Option<usize> = arg(&args, "--limit")
        .map(|s| s.parse().or_err("--limit N"))
        .transpose()?;
    let total_timeout_ms: u64 = arg(&args, "--total-timeout")
        .map(|s| s.parse().or_err("--total-timeout ms"))
        .transpose()?
        .unwrap_or(60_000);
    let dump = arg(&args, "--dump");
    let cells = arg(&args, "--cells");
    let words_from = arg(&args, "--words-from");
    // the test's own chain (the header): the instances' activation heights, the spec's CLI configuration, the coins from the chain
    let heights: Option<(u32, u32)> = match (
        arg(&args, "--genesis-height"),
        arg(&args, "--chronicle-height"),
    ) {
        (Some(g), Some(c)) => Some((
            g.parse().or_err("--genesis-height N")?,
            c.parse().or_err("--chronicle-height N")?,
        )),
        (None, None) => None,
        _ => {
            eprintln!("run_svnode: --genesis-height and --chronicle-height go together (a node sets both activation heights); refused");
            std::process::exit(2);
        }
    };
    let spec_config_arg = arg(&args, "--spec-config");
    let txo_from_chain = args.iter().any(|a| a == "--txo-from-chain");
    if heights.is_some() && words_from.is_some() {
        eprintln!("run_svnode: --genesis-height/--chronicle-height ask the spec's CLI for the words of that chain; a recorded table (--words-from) cannot be asked; refused");
        std::process::exit(2);
    }
    if record && limit.is_some() {
        eprintln!("run_svnode: --record with --limit would record a partial run; refused");
        std::process::exit(2);
    }
    let root: PathBuf = match std::env::var("BSV_SCRIPT_LEAN_ROOT") {
        Ok(r) => PathBuf::from(r),
        Err(_) => {
            let here = std::env::current_dir().or_err("cwd")?;
            if here.join("Cargo.toml").exists()
                && here.join("..").join("eval").join("bsvs").exists()
            {
                here.join("..")
                    .canonicalize()
                    .or_err("here.join('..').canonicalize()")?
            } else {
                here
            }
        }
    };
    let witnesses_dir =
        bsv_script_harness::txroad::witnesses_dir_of(&args, limit, &root, "run_svnode")
            .unwrap_or_else(|e| {
                eprintln!("{e}");
                std::process::exit(2);
            });
    // lean #32, B-4: no spec stamp without a commit reaches the corpus, checked before the node is touched
    bsv_script_harness::stamp::refuse_unnamed_stamp(
        "run_svnode",
        &spec_path,
        record,
        &witnesses_dir,
        &root,
    );
    let rpc_url = arg(&args, "--rpc")
        .or_else(|| std::env::var("SVNODE_RPC_URL").ok())
        .unwrap_or_else(|| "http://127.0.0.1:18563".into());
    let cookie = arg(&args, "--cookie")
        .or_else(|| std::env::var("SVNODE_COOKIE").ok())
        .unwrap_or_else(|| {
            format!(
                "{}/bsv/targets/spec-oracle-data/regtest/.cookie",
                std::env::var("HOME").unwrap_or_default()
            )
        });
    let mut rpc = match Rpc::new(
        &rpc_url,
        &cookie,
        Duration::from_millis(total_timeout_ms + 30_000),
    ) {
        Ok(r) => r,
        Err(e) => {
            eprintln!("run_svnode: {e}");
            std::process::exit(1);
        }
    };
    let (node_version, settings) = check_instance(&mut rpc, &rpc_url, Instance::Consensus, heights);
    // the second instance for the mempool column (the node's default policy), when given
    let rpc_mp_url =
        arg(&args, "--rpc-mempool").or_else(|| std::env::var("SVNODE_RPC_URL_MEMPOOL").ok());
    let mut rpc_mp: Option<Rpc> = None;
    let mut node_mp_version = String::new();
    let mut settings_mp = serde_json::Value::Null;
    if let Some(url) = &rpc_mp_url {
        let cookie_mp = arg(&args, "--cookie-mempool")
            .or_else(|| std::env::var("SVNODE_COOKIE_MEMPOOL").ok())
            .unwrap_or_else(|| {
                format!(
                    "{}/bsv/targets/spec-oracle-policy-data/regtest/.cookie",
                    std::env::var("HOME").unwrap_or_default()
                )
            });
        let mut r = match Rpc::new(
            url,
            &cookie_mp,
            Duration::from_millis(total_timeout_ms + 30_000),
        ) {
            Ok(r) => r,
            Err(e) => {
                eprintln!("run_svnode: the mempool instance: {e}");
                std::process::exit(1);
            }
        };
        let (v, st) = check_instance(&mut r, url, Instance::Policy, heights);
        node_mp_version = v;
        settings_mp = st;
        rpc_mp = Some(r);
    }

    let CorpusInput {
        file_name,
        corpus_name,
        bytes,
        manifest_path,
        manifest,
    } = CorpusInput::load(std::path::Path::new(&corpus_path)).unwrap_or_else(|e| {
        eprintln!("run_svnode: {e}");
        std::process::exit(1);
    });
    let spec = read_spec(std::path::Path::new(&spec_path)).unwrap_or_else(|e| {
        eprintln!("run_svnode: {e}");
        std::process::exit(2);
    });
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
    let rules_table = RuleSet::load(&root, "sv-node").unwrap_or_else(|err| {
        eprintln!("run_svnode: {err}");
        std::process::exit(2);
    });
    let mempool_key = format!("spec-mempool@{commit}");
    // the CLI configuration the words are asked under: `--spec-config` when given (the spec file's `config` must then be
    // that name with the heights, `lean/Bsvs/Main.lean` `withHeights`), else inferred from the spec file's name as before
    let cli_config: String = spec_config_arg.clone().unwrap_or_else(|| {
        if config.starts_with("teranode") {
            "teranode".into()
        } else {
            "sv".into()
        }
    });
    if spec_config_arg.is_some() || heights.is_some() {
        let expected = match heights {
            Some((g, c)) => format!("{cli_config}(genesis={g},chronicle={c})"),
            None => cli_config.clone(),
        };
        if config != expected {
            eprintln!("run_svnode: the spec file {spec_path} was computed under the configuration {config:?}, this run asks for {expected:?} (--spec-config, --genesis-height, --chronicle-height): a spec column of another chain never meets this node; refused");
            std::process::exit(2);
        }
    }
    let mut oracle = match &words_from {
        Some(m) => {
            FlagsOracle::recorded(std::path::Path::new(m), &corpus_name).unwrap_or_else(|e| {
                eprintln!("run_svnode: {e}");
                std::process::exit(2);
            })
        }
        None => {
            let o = FlagsOracle::new(&root, &cli_config);
            match heights {
                Some((g, c)) => o.with_heights(g, c),
                None => o,
            }
        }
    };

    let mempool_note = match &rpc_mp_url {
        Some(u) => format!("; the mempool column at {u} ({node_mp_version}; the node's default policy; getsettings' maxscriptnumlengthpolicy at its tip's era {})", settings_mp["maxscriptnumlengthpolicy"]),
        None => "; the mempool column on the SAME instance (its zeroed policy = the consensus limits: an entry reaching a policy LIMIT diverges by configuration; give --rpc-mempool)".to_string(),
    };
    let t0 = std::time::Instant::now();
    let mut entries: Vec<Entry> = Vec::new();
    let (mut n, mut no_spec, mut undecided, mut unknown_desc) = (0u64, 0u64, 0u64, 0u64);
    let mut unknown_descriptions: BTreeMap<String, u64> = BTreeMap::new();
    let mut undecided_messages: BTreeMap<String, u64> = BTreeMap::new();
    let mut counts: BTreeMap<(String, String), Count> = BTreeMap::new();
    let mut agree: BTreeMap<String, u64> = BTreeMap::new();
    let mut code_notes: BTreeMap<(String, String, String), u64> = BTreeMap::new();
    let mut divergences: Vec<String> = Vec::new();
    let mut est_families: BTreeMap<String, Vec<String>> = BTreeMap::new();
    let mut flag_drifts: u64 = 0;
    let mut dump_lines: Vec<String> = Vec::new();
    let mut cell_lines: Vec<String> = Vec::new();
    for line in std::io::BufReader::new(&bytes[..]).lines() {
        if let Some(l) = limit {
            if n as usize >= l {
                break;
            }
        }
        let line = line.or_err("line")?;
        if line.trim().is_empty() {
            continue;
        }
        let mut e: Entry = serde_json::from_str(&line).or_err("entry")?;
        e.check().or_err("a corpus entry must be well-formed")?;
        n += 1;
        let tx = RawTx::decode(&hex::decode(&e.tx).or_err("tx hex")?).or_err("tx frame")?;
        let Some(s) = spec.get(&e.id) else {
            no_spec += 1;
            continue;
        };
        let mut block_words = Vec::with_capacity(e.prevouts.len());
        let mut mempool_words = Vec::with_capacity(e.prevouts.len());
        for (i, p) in e.prevouts.iter().enumerate() {
            let bw = match &e.flags {
                Some(f) => f[i],
                None => oracle
                    .word(e.params.spend_height, p.height, e.params.consensus)
                    .or_err("the flag word")?,
            };
            block_words.push(bw);
            mempool_words.push(
                oracle
                    .word(e.params.spend_height, p.height, false)
                    .or_err("the flag word")?,
            );
        }
        let mut sides: BTreeMap<&str, NodeSide> = BTreeMap::new();
        for (run, words) in [("block", &block_words), ("mempool", &mempool_words)] {
            let scripts: Vec<serde_json::Value> = e
                .prevouts
                .iter()
                .enumerate()
                .map(|(i, p)| {
                    if txo_from_chain {
                        // the coin from the node's own chain (misc.cpp:795–803): its lock, value and height, the coinbase flag the chain's
                        serde_json::json!({"tx": e.tx, "n": i, "flags": words[i], "reportflags": true})
                    } else {
                        serde_json::json!({
                            "tx": e.tx, "n": i, "flags": words[i], "reportflags": true,
                            "txo": {"lock": p.script, "value": p.satoshis, "height": p.height}
                        })
                    }
                })
                .collect();
            let params = serde_json::json!([scripts, true, total_timeout_ms]);
            let call = if run == "mempool" {
                match rpc_mp.as_mut() {
                    Some(r) => r.call("verifyscript", params),
                    None => rpc.call("verifyscript", params),
                }
            } else {
                rpc.call("verifyscript", params)
            };
            let res = match call {
                Ok(v) => v,
                Err(err) => {
                    eprintln!("run_svnode: {}: {err}", e.id);
                    std::process::exit(1);
                }
            };
            let results = res.as_array().cloned().unwrap_or_default();
            let side = side_of(&results, words);
            if !side.flag_drift.is_empty() {
                flag_drifts += 1;
                eprintln!("run_svnode: {}: the node applied another word than the spec's: {:?} (given, applied): the instance's activation heights are not the run's ({})?", e.id, side.flag_drift, match heights { Some((g, c)) => format!("{g}, {c}"), None => "mainnet's 620538, 943816".to_string() });
            }
            if side.unknown_description {
                unknown_desc += 1;
                *unknown_descriptions.entry(side.native.clone()).or_insert(0) += 1;
            }
            if side.kind == "undecided" {
                undecided += 1;
                *undecided_messages.entry(side.native.clone()).or_insert(0) += 1;
            }
            sides.insert(run, side);
        }
        if record {
            // #57: retain earlier node keys as measurements of their own release.
            e.expect.insert(comparison_key.clone(), spec_json(&s.spec));
            e.expect
                .insert(comparison_mp_key.clone(), spec_json(&s.spec_mempool));
            e.expect
                .insert(SV_NODE_KEY.into(), side_json(&sides["block"]));
            e.expect
                .insert(SV_NODE_MEMPOOL_KEY.into(), side_json(&sides["mempool"]));
        }
        for (column, sv, run) in [
            ("spec", &s.spec, "block"),
            ("spec-mempool", &s.spec_mempool, "mempool"),
        ] {
            let side = &sides[run];
            if cells.is_some() {
                cell_lines.push(serde_json::json!({"column": column, "id": e.id, "node": side.kind, "node_code": side.code}).to_string());
            }
            if sv.verdict == "unimplemented" || side.kind == "undecided" {
                continue;
            }
            if sv.verdict == "undefined-in-reference" {
                // an undecided region of the spec (none since D72, 2026-09-24): the node's verdict is the measurement
                est_families
                    .entry(e.rule.clone())
                    .or_default()
                    .push(format!(
                        "{} ({column}): the node says {} {}",
                        e.id, side.kind, side.native
                    ));
                continue;
            }
            if sv.verdict == side.kind {
                *agree.entry(column.to_string()).or_insert(0) += 1;
                if side.kind == "invalid" {
                    let sc = sv.code.clone().unwrap_or_default();
                    let ec = side.code.unwrap_or("(no row)").to_string();
                    if sc != ec {
                        *code_notes.entry((column.to_string(), sc, ec)).or_insert(0) += 1;
                    }
                }
                continue;
            }
            let observation = rules::observe(
                &e,
                &tx,
                column,
                &sv.verdict,
                sv.code.as_deref(),
                &side.kind,
                side.code,
                &side.native,
            );
            let class = rules_table
                .explain(&observation)
                .map(|x| x.rule)
                .unwrap_or_else(|| UNEXPLAINED.into());
            let key = (column.to_string(), class.clone());
            let size = e.tx.len();
            let c = counts.entry(key).or_insert_with(|| Count {
                n: 0,
                smallest: None,
            });
            c.n += 1;
            let better = match &c.smallest {
                None => true,
                Some((sz, _, _, _)) => size < *sz,
            };
            if better {
                c.smallest = Some((size, e.clone(), spec_json(sv), side_json(side)));
            }
            if class == UNEXPLAINED && divergences.len() < 60 {
                divergences.push(format!(
                    "{column} {} ({}, rule {}, version {}): spec {}{} vs the node {} {}",
                    e.id,
                    e.family,
                    e.rule,
                    tx.version,
                    sv.verdict,
                    sv.code
                        .as_ref()
                        .map(|c| format!(" {c}"))
                        .unwrap_or_default(),
                    side.kind,
                    side.native
                ));
            }
            if dump.is_some() {
                dump_lines.push(serde_json::json!({"column": column, "id": e.id, "family": e.family, "rule": e.rule, "version": tx.version, "spec": sv.verdict, "spec_code": sv.code, "node": side.kind, "node_code": side.code, "native": side.native, "class": &class}).to_string());
            }
        }
        entries.push(e);
    }
    if let Some(d) = &dump {
        std::fs::write(
            d,
            dump_lines.join("\n") + if dump_lines.is_empty() { "" } else { "\n" },
        )
        .or_err("dump file")?;
    }
    if let Some(c) = &cells {
        std::fs::write(
            c,
            cell_lines.join("\n") + if cell_lines.is_empty() { "" } else { "\n" },
        )
        .or_err("cells file")?;
    }

    let out_dir = format!("{witnesses_dir}/sv-node");
    std::fs::create_dir_all(&out_dir).or_err("witnesses dir")?;
    println!(
        "run_svnode: {corpus_name}/{file_name} ({n} entries) vs {SV_NODE_KEY} ({node_version}) at {rpc_url}{}; the spec at {spec_key} ({config}); {} RPC calls; {} ({} CLI calls); totalTimeout {total_timeout_ms} ms, stopOnFirstInvalid true; {:.1}s",
        mempool_note, rpc.calls + rpc_mp.as_ref().map(|r| r.calls).unwrap_or(0), oracle.source(), oracle.calls, t0.elapsed().as_secs_f64()
    );
    for ((sh, uh, cons), w) in oracle.table() {
        println!("  word: spend {sh}, utxo {uh}, consensus {cons} -> 0x{w:X}");
    }
    println!(

        "  agree: {}; node undecided runs (timeout/skipped) {undecided}; without a spec verdict {no_spec}; descriptions outside the table {unknown_desc}; flag-word drifts {flag_drifts}",
        agree.iter().map(|(c, k)| format!("{c} {k}")).collect::<Vec<_>>().join(", ")
    );
    let mut witness_lines: Vec<String> = Vec::new();
    let mut summary: Vec<serde_json::Value> = Vec::new();
    println!("| column | rule | entries | ruling | witness |");
    println!("|---|---|---|---|---|");
    for ((column, rule), c) in &counts {
        let (_, we, a_v, b_v) = c.smallest.as_ref().or_err("c.smallest.as_ref()")?;
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
        let explanation = rules_table.record(rule);
        w.divergence = Some(Divergence {
            rule: rule.clone(), a: a_key.clone(), b: b_key.clone(), a_verdict: a_v.clone(), b_verdict: b_v.clone(),
            decided_by: explanation.decided_by.clone(),
            ruling: explanation.ruling.clone(), minimized: None, minimized_prevouts: None,
            note: format!("{} entries of {corpus_name} diverge from the node in the {column} column; this is the smallest (from {}). {}", c.n, we.id, explanation.note),
        });
        w.expect.insert(b_key, b_v.clone());
        w.expect.insert(a_key, a_v.clone());
        witness_lines.push(serde_json::to_string(&w).or_err("serde_json::to_string(&w)")?);
        println!(
            "| {column} | `{rule}` | {} | {} | `{}` |",
            c.n, explanation.ruling, w.id
        );
        summary.push(serde_json::json!({"column": column, "rule": rule, "entries": c.n, "ruling": explanation.ruling, "witness": w.id, "from": we.id}));
    }
    if !code_notes.is_empty() {
        println!("  tier-2 notes (both invalid, the codes differ; never a divergence):");
        for ((column, sc, ec), k) in &code_notes {
            println!("    {column}: spec {sc} vs the node {ec}: {k}");
        }
    }
    if !est_families.is_empty() {
        println!("  the undecided regions measured (the spec says undefined-in-reference, none since D72; the node's verdict is the record):");
        for (r, v) in &est_families {
            println!(
                "    {r}: {} entries; e.g. {}",
                v.len(),
                v.iter().take(3).cloned().collect::<Vec<_>>().join("; ")
            );
        }
    }
    let out_path = format!("{out_dir}/{corpus_name}.jsonl");
    std::fs::write(
        &out_path,
        witness_lines.join("\n") + if witness_lines.is_empty() { "" } else { "\n" },
    )
    .or_err("witness file")?;
    let wsha = hex::encode(sha256(
        &std::fs::read(&out_path).or_err("std::fs::read(&out_path)")?,
    ));
    let man_path = format!("{out_dir}/manifest.json");
    let mut man: serde_json::Value = std::fs::read_to_string(&man_path)
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_else(|| serde_json::json!({}));
    man[&corpus_name] = serde_json::json!({
        "file": format!("{corpus_name}.jsonl"), "sha256": wsha, "witnesses": witness_lines.len(), "corpus": corpus_path, "spec": spec_key, "spec_config": config,
        "spec_recorded_keys": {"spec": comparison_key, "spec-mempool": comparison_mp_key},
        "node": SV_NODE_KEY, "node_reported": node_version, "rpc": rpc_url, "rpc_mempool": rpc_mp_url, "node_mempool_reported": node_mp_version, "total_timeout_ms": total_timeout_ms, "stop_on_first_invalid": true,
        "settings": {"maxscriptsizepolicy": settings["maxscriptsizepolicy"], "maxopsperscriptpolicy": settings["maxopsperscriptpolicy"], "maxscriptnumlengthpolicy": settings["maxscriptnumlengthpolicy"], "maxstackmemoryusagepolicy": settings["maxstackmemoryusagepolicy"], "maxstdtxvalidationduration": settings["maxstdtxvalidationduration"]},
        "words": oracle.table().iter().map(|((sh, uh, c), w)| serde_json::json!({"spend_height": sh, "utxo_height": uh, "consensus": c, "word": w})).collect::<Vec<_>>(),
        "entries": n, "agree": agree, "undecided_runs": undecided, "undecided_messages": undecided_messages, "unknown_descriptions": unknown_descriptions, "flag_drifts": flag_drifts,
        "rules": summary, "code_notes": code_notes.iter().map(|((c, s, e), k)| serde_json::json!({"column": c, "spec": s, "node": e, "entries": k})).collect::<Vec<_>>(),
        "est_families": est_families, "generated": std::env::var("SOURCE_DATE").unwrap_or_else(|_| "2026-09-23".into()),
    });
    std::fs::write(
        &man_path,
        serde_json::to_string_pretty(&man).or_err("serde_json::to_string_pretty(&man)")? + "\n",
    )
    .or_err("witness manifest")?;
    println!(
        "  witnesses: {} written to {out_path} (sha256 {wsha}); manifest {man_path}",
        witness_lines.len()
    );
    if !unknown_descriptions.is_empty() {
        println!("  node descriptions outside the cited table (the table must grow, never guess):");
        for (m, c) in &unknown_descriptions {
            println!("    {c} × {m}");
        }
    }
    if record {
        let text: String = entries
            .iter()
            .map(|e| serde_json::to_string(e).map(|l| l + "\n"))
            .collect::<Result<String, _>>()
            .or_err("corpus json")?;
        std::fs::write(&corpus_path, &text).or_err("rewrite corpus")?;
        let sha = hex::encode(sha256(text.as_bytes()));
        if let (Some(mp), Some(mut m)) = (manifest_path, manifest) {
            m.sha256 = sha.clone();
            m.implementations.retain(|i| {
                i.version != SV_NODE_TAG || (i.name != "sv-node" && i.name != "sv-node-mempool")
            });
            let mut cfg = BTreeMap::new();
            let txo_text = if txo_from_chain {
                "txo omitted: the coin's lock, value and height read by the node from its own chain's UTXO set (misc.cpp:795–803), the coinbase flag the chain's"
            } else {
                "txo.height = the prevout's"
            };
            let heights_text = match heights {
                Some((g, c)) => format!("-genesisactivationheight={g} -chronicleactivationheight={c} on the command line (the test's chain, lane cpp-era-49)"),
                None => "mainnet activation heights".to_string(),
            };
            cfg.insert("mode".to_string(), serde_json::json!(format!("the verifyscript RPC under the reference's flag word of the entry's own params (the block word unless the entry gives one), the word asked of eval/bsvs (Params.derive; {}); {txo_text}; stopOnFirstInvalid true", oracle.source())));
            cfg.insert("node".to_string(), serde_json::json!(node_version));
            cfg.insert(
                "total_timeout_ms".to_string(),
                serde_json::json!(total_timeout_ms),
            );
            cfg.insert("rpc".to_string(), serde_json::json!(rpc_url));
            cfg.insert("configuration".to_string(), serde_json::json!(format!("harness/oracle/bitcoin.conf: {heights_text}, every policy setting zeroed (the consensus limits on the policy path, Q6)")));
            if let Some((g, c)) = heights {
                cfg.insert(
                    "activation_heights".to_string(),
                    serde_json::json!({"genesis": g, "chronicle": c}),
                );
            }
            if txo_from_chain {
                cfg.insert("txo_from_chain".to_string(), serde_json::json!(true));
            }
            m.implementations.push(ImplConfigJson {
                name: "sv-node".into(),
                version: SV_NODE_TAG.into(),
                config: cfg.clone(),
            });
            match &rpc_mp_url {
                Some(u) => {
                    cfg.insert("mode".to_string(), serde_json::json!("the same under the mempool word (Params.derive with consensus = false) on the POLICY instance: the node's default policy, the limits the spec's spec-mempool column models"));
                    cfg.insert("node".to_string(), serde_json::json!(node_mp_version));
                    cfg.insert("rpc".to_string(), serde_json::json!(u));
                    cfg.insert("configuration".to_string(), serde_json::json!(format!("harness/oracle/bitcoin-policy.conf: {heights_text}, the policy caps at the node's defaults (docs/PARAMETERS.md §1)")));
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
                }
                None => {
                    cfg.insert("mode".to_string(), serde_json::json!("the same under the mempool word of the SAME zeroed configuration (Params.derive with consensus = false): like-for-like on the flags, not on the policy limits"));
                }
            }
            m.implementations.push(ImplConfigJson {
                name: "sv-node-mempool".into(),
                version: SV_NODE_TAG.into(),
                config: cfg,
            });
            std::fs::write(
                &mp,
                serde_json::to_string_pretty(&m).or_err("serde_json::to_string_pretty(&m)")? + "\n",
            )
            .or_err("manifest")?;
            println!("  recorded {SV_NODE_KEY}, {SV_NODE_MEMPOOL_KEY} into {corpus_path}; new sha256 {sha} in {}", mp.display());
        }
    }
    let n_div: u64 = counts
        .iter()
        .filter(|((_, class), _)| class == UNEXPLAINED)
        .map(|(_, c)| c.n)
        .sum();
    let n_classified: u64 = counts
        .iter()
        .filter(|((_, class), _)| class != UNEXPLAINED)
        .map(|(_, c)| c.n)
        .sum();
    if n_div > 0 || unknown_desc > 0 || flag_drifts > 0 || n == 0 {
        println!("run_svnode: RED ({n_div} divergences from the reference, {unknown_desc} descriptions outside the table, {flag_drifts} flag-word drifts)");
        for d in &divergences {
            println!("  DIVERGENCE {d}");
        }
        std::process::exit(1);
    }
    println!("run_svnode: GREEN ({n_classified} divergent runs filed under cited classes; every other decided entry agrees in both columns)");
    Ok(())
}
