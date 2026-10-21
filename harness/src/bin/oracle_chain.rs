//! oracle_chain (this repo's; #27, D97; S3, set 4, 2026-09-26): THE BLOCK INSTANCE'S CHAIN, built by the harness.
//!
//! The `tx.*` rules need a chain (a UTXO set, a block height, a median time) and `verifyscript` never touches one;
//! the block instance (`harness/oracle/bitcoin-block.conf`, `spec-node.sh block`) carries a private regtest chain
//! that is MAINNET-SHAPED: its activation heights are mainnet's, so an entry's `params.spend_height` is the height of
//! the block that carries its spend and a pre-Genesis coin is created below 620,538. This tool bakes that chain:
//!
//!   oracle_chain address                          the harness's WELL key (sha256 of a fixed label, as the generators
//!                                                 derive keys) as a regtest P2PKH address and its locking script
//!   oracle_chain bake --to <height> [--t0 <unix>] `generatetoaddress` to the well in batches (`--batch`, 1,000 by
//!                                                 default) under `setmocktime` (`src/rpc/misc.cpp:1342`), set ONCE per
//!                                                 batch to T0 plus the height of the batch's last block; the node's
//!                                                 miner times each block max(mocktime, MTP + 1), so the times depend
//!                                                 on the batch size and run ahead of T0 + height (minutes ahead at
//!                                                 thousands of blocks, measured); resumable
//!   oracle_chain well [--from <h>] [--to <h>]     the well's coinbase outputs (height, txid, value) still unspent
//!
//! The subsidy on regtest halves every 150 blocks (`chainparams.cpp:1460`), so the coins live in the first ≈ 5,000
//! coinbases (≈ 15,000 BSV, mature after 100 blocks, `consensus.h:75`); the funding of a family's prevouts spends
//! them (`run_svnode --mode tx`, the funding step). Measured 2026-09-26 on the Studio `[M]`: 2.0 ms per block,
//! 5,000 blocks in 10 s, 20 MB on disk. The RPC: `--rpc http://127.0.0.1:18567`, the cookie of the block datadir.

use std::time::Duration;

use bsv_rs::primitives::ec::PrivateKey;
use bsv_rs::primitives::hash::{hash160, sha256};
use bsv_script_harness::fail::OrErr;
use bsv_script_harness::rpc::Rpc;

/// The well key's label: fixed, so the address is the same on every bake and in every record.
pub const WELL_LABEL: &str = "bsv-script-lean/oracle/well";
/// The bake's base stamp, shared with the generator (the time-based lock-time rows are built against the median times
/// this stamp determines): 2023-11-14 22:13:20 UTC.
pub const T0: u64 = 1_700_000_000;

fn arg(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1).cloned())
}

#[allow(
    clippy::expect_used,
    reason = "sha256 of the well's fixed label is a valid secp256k1 scalar"
)]
pub fn well_key() -> PrivateKey {
    let h = sha256(WELL_LABEL.as_bytes());
    PrivateKey::from_bytes(&h).expect("key")
}

/// `OP_DUP OP_HASH160 <20> OP_EQUALVERIFY OP_CHECKSIG` for the well's compressed key.
pub fn well_script() -> Vec<u8> {
    let pk = well_key().public_key().to_compressed().to_vec();
    let h = hash160(&pk);
    let mut s = vec![0x76, 0xa9, 0x14];
    s.extend_from_slice(&h);
    s.extend_from_slice(&[0x88, 0xac]);
    s
}

fn base58check(version: u8, payload: &[u8]) -> String {
    const ALPHABET: &[u8; 58] = b"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
    let mut data = vec![version];
    data.extend_from_slice(payload);
    let check = sha256(&sha256(&data));
    data.extend_from_slice(&check[..4]);
    // big-number base conversion over bytes
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
    for &b in data.iter().take_while(|&&b| b == 0) {
        let _ = b;
        out.push('1');
    }
    for &d in digits.iter().rev() {
        out.push(ALPHABET[d as usize] as char);
    }
    out
}

/// The regtest P2PKH address of the well (version byte 0x6f, `chainparams.cpp` regtest `PUBKEY_ADDRESS`).
pub fn well_address() -> String {
    let pk = well_key().public_key().to_compressed().to_vec();
    base58check(0x6f, &hash160(&pk))
}

fn rpc_from(args: &[String]) -> Rpc {
    let url = arg(args, "--rpc").unwrap_or_else(|| "http://127.0.0.1:18567".into());
    let cookie = arg(args, "--cookie").unwrap_or_else(|| {
        format!(
            "{}/bsv/targets/spec-oracle-block-data/regtest/.cookie",
            std::env::var("HOME").unwrap_or_default()
        )
    });
    match Rpc::new(&url, &cookie, Duration::from_secs(600)) {
        Ok(r) => r,
        Err(e) => {
            eprintln!("oracle_chain: {e}");
            std::process::exit(1);
        }
    }
}

/// The exit code of `run` (#132): an error that stood as an unwrap, expect or panic is reported with its words and exits 1.
fn main() -> std::process::ExitCode {
    match run() {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("oracle_chain: {e}");
            std::process::ExitCode::from(1)
        }
    }
}

fn run() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();
    match args.get(1).map(|s| s.as_str()) {
        Some("address") => {
            println!("well address: {}", well_address());
            println!("well script:  {}", hex::encode(well_script()));
            println!("label:        {WELL_LABEL} (sha256 of the label is the private key, as the generators derive theirs)");
        }
        Some("bake") => {
            let to: u64 = arg(&args, "--to")
                .or_err("--to <height>")?
                .parse()
                .or_err("--to height")?;
            let t0: u64 = arg(&args, "--t0")
                .map(|s| s.parse().or_err("--t0 unix"))
                .transpose()?
                .unwrap_or(T0);
            let batch: u64 = arg(&args, "--batch")
                .map(|s| s.parse().or_err("--batch n"))
                .transpose()?
                .unwrap_or(1000);
            let mut rpc = rpc_from(&args);
            let addr = well_address();
            let start = rpc
                .call("getblockcount", serde_json::json!([]))
                .or_err("getblockcount")?
                .as_u64()
                .unwrap_or(0);
            let started = std::time::Instant::now();
            let mut h = start;
            let mut last_report = std::time::Instant::now();
            println!("oracle_chain bake: from height {start} to {to} paying the well {addr}; T0 {t0}; batches of {batch}");
            while h < to {
                let n = std::cmp::min(batch, to - h);
                // the clock ahead of the batch's last block: each block's time is max(mocktime, MTP + 1) in the node's miner
                rpc.call("setmocktime", serde_json::json!([t0 + h + n]))
                    .or_err("setmocktime")?;
                match rpc.call("generatetoaddress", serde_json::json!([n, addr])) {
                    Ok(_) => {}
                    Err(e) => {
                        eprintln!("oracle_chain bake: generatetoaddress at height {h}: {e}");
                        std::process::exit(1);
                    }
                }
                h += n;
                if last_report.elapsed().as_secs() >= 60 || h >= to {
                    let el = started.elapsed().as_secs_f64();
                    let rate = (h - start) as f64 / el.max(0.001);
                    println!(
                        "  height {h} ({:.1} min elapsed, {:.0} blocks/s; ≈ {:.1} min to go)",
                        el / 60.0,
                        rate,
                        (to - h) as f64 / rate.max(0.001) / 60.0
                    );
                    last_report = std::time::Instant::now();
                }
            }
            let tip = rpc
                .call("getbestblockhash", serde_json::json!([]))
                .or_err("tip")?;
            let hdr = rpc
                .call("getblockheader", serde_json::json!([tip]))
                .or_err("header")?;
            println!("oracle_chain bake: DONE at height {} in {:.1} min; tip time {} mediantime {} (T0 {t0}); {} RPC calls", hdr["height"], started.elapsed().as_secs_f64() / 60.0, hdr["time"], hdr["mediantime"], rpc.calls);
        }
        Some("well") => {
            let from: u64 = arg(&args, "--from")
                .map(|s| s.parse().or_err("--from"))
                .transpose()?
                .unwrap_or(1);
            let to: u64 = arg(&args, "--to")
                .map(|s| s.parse().or_err("--to"))
                .transpose()?
                .unwrap_or(5000);
            let mut rpc = rpc_from(&args);
            let script = hex::encode(well_script());
            let mut total: u64 = 0;
            let mut n = 0u64;
            for h in from..=to {
                let hash = rpc
                    .call("getblockhash", serde_json::json!([h]))
                    .or_err("getblockhash")?;
                let block = rpc
                    .call("getblock", serde_json::json!([hash, 2]))
                    .or_err("getblock")?;
                let cb = &block["tx"][0];
                let out0 = &cb["vout"][0];
                if out0["scriptPubKey"]["hex"].as_str() != Some(script.as_str()) {
                    continue;
                }
                let sats = (out0["value"].as_f64().unwrap_or(0.0) * 1e8).round() as u64;
                if sats == 0 {
                    break;
                }
                let txid = cb["txid"].as_str().unwrap_or("");
                let unspent = !rpc
                    .call("gettxout", serde_json::json!([txid, 0]))
                    .map(|v| v.is_null())
                    .unwrap_or(true);
                if unspent {
                    println!("{h} {txid} {sats}");
                    total += sats;
                    n += 1;
                }
            }
            println!("well: {n} unspent coinbases from height {from}, {total} satoshis");
        }
        _ => {
            eprintln!("oracle_chain address | bake --to <height> [--t0 <unix>] [--batch <n>] [--rpc <url>] [--cookie <path>] | well [--from <h>] [--to <h>]");
            std::process::exit(2);
        }
    }
    Ok(())
}
