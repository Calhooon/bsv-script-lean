//! sighash_vectors (this repo's; #12): the pinned bsv-rs's BIP143-style signature (0.4.4 since 2026-10-12, 0.3.33 from 2026-10-07, bsv-rs#41 (0.3.30 from 2026-09-27, 0.3.28 from 2026-09-24, 0.3.27 on 2026-09-23); byte-identical to 0.3.24's)
//! hash on random transactions, as JSON lines for `lean/Test/SighashCheck.lean`.
//! This generator selects the crate's BIP143 serializer for every scope it draws
//! (`build_sighash_preimage` and `compute_sighash_for_signing`, `sighash.rs:857–860`
//! at 0.4.4), the non-FORKID scopes included, so these vectors cover
//! `SignatureHashBIP143`'s serializer only. 0.4.4 also implements the original
//! digest (`compute_sighash_original_for_signing`, `sighash.rs:891–900`, and the
//! reference's dispatch, `compute_sighash_dispatched_for_signing`, `:878–884`);
//! this generator does not call them, and the original digest's vectors are the
//! reference's own `src/test/data/sighash.json` at the pin. Deterministic from
//! the seed. Each line: the transaction hex, the prevouts, the input index, the
//! scriptCode (subscript) hex, the amount, the hash type, bsv-rs's preimage and
//! digest (the raw SHA-256d bytes in natural order, hex: `compute_sighash_for_signing`;
//! bsv-rs's `compute_sighash` returns the bytes reversed for display).
//!
//! Run: cargo run --release --bin sighash_vectors -- [--count N] [--seed HEX] > vectors.jsonl

use bsv_rs::primitives::bsv::sighash::{
    build_sighash_preimage, compute_sighash_for_signing, SighashParams, TxInput, TxOutput,
};
use bsv_script_harness::gen::Rng;
use bsv_script_harness::txraw::{RawInput, RawOutput, RawTx};

fn arg(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1).cloned())
}

fn rand_bytes(rng: &mut Rng, max: usize) -> Vec<u8> {
    let n = rng.below(max + 1);
    (0..n).map(|_| (rng.next() & 0xff) as u8).collect()
}

#[allow(
    clippy::expect_used,
    reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
)]
fn main() {
    let args: Vec<String> = std::env::args().collect();
    let count: usize = arg(&args, "--count")
        .map(|s| s.parse().expect("--count"))
        .unwrap_or(500);
    let seed: u64 = arg(&args, "--seed")
        .map(|s| u64::from_str_radix(s.trim_start_matches("0x"), 16).expect("--seed is hex"))
        .unwrap_or(0x5163_4A54_0012_0001);
    let mut rng = Rng(seed);
    let scopes: [u32; 12] = [
        0x41,
        0x42,
        0x43,
        0xc1,
        0xc2,
        0xc3,
        0x40,
        0x44,
        0x01,
        0x61,
        0xe3,
        0x0001_0041,
    ];
    let mut emitted = 0;
    while emitted < count {
        let n_in = 1 + rng.below(4);
        let n_out = rng.below(4); // zero outputs happen: SINGLE/NONE corners
        let version: i32 = match rng.below(4) {
            0 => 1,
            1 => 2,
            2 => -1,
            _ => 0x7fff_ffff,
        };
        let inputs: Vec<RawInput> = (0..n_in)
            .map(|_| {
                let mut txid = [0u8; 32];
                for b in txid.iter_mut() {
                    *b = (rng.next() & 0xff) as u8;
                }
                RawInput {
                    txid,
                    vout: (rng.next() % 5) as u32,
                    script: rand_bytes(&mut rng, 40),
                    sequence: match rng.below(3) {
                        0 => 0xffff_ffff,
                        1 => 0,
                        _ => rng.next() as u32,
                    },
                }
            })
            .collect();
        let outputs: Vec<RawOutput> = (0..n_out)
            .map(|_| RawOutput {
                satoshis: match rng.below(3) {
                    0 => 0,
                    1 => rng.next() % 100_000,
                    _ => rng.next() % 2_100_000_000_000_000,
                },
                script: rand_bytes(&mut rng, 60),
            })
            .collect();
        let lock_time: u32 = match rng.below(3) {
            0 => 0,
            1 => rng.next() as u32 % 500_000_000,
            _ => rng.next() as u32,
        };
        let tx = RawTx {
            version,
            inputs: inputs.clone(),
            outputs: outputs.clone(),
            lock_time,
        };
        let prevout_scripts: Vec<Vec<u8>> = (0..n_in).map(|_| rand_bytes(&mut rng, 50)).collect();
        let prevout_sats: Vec<u64> = (0..n_in).map(|_| rng.next() % 5_000_000_000).collect();
        let sig_inputs: Vec<TxInput> = inputs
            .iter()
            .map(|i| TxInput {
                txid: i.txid,
                output_index: i.vout,
                script: i.script.clone(),
                sequence: i.sequence,
            })
            .collect();
        let sig_outputs: Vec<TxOutput> = outputs
            .iter()
            .map(|o| TxOutput {
                satoshis: o.satoshis,
                script: o.script.clone(),
            })
            .collect();
        for input_index in 0..n_in {
            let subscript = if rng.below(2) == 0 {
                prevout_scripts[input_index].clone()
            } else {
                rand_bytes(&mut rng, 80)
            };
            let scope = scopes[rng.below(scopes.len())];
            let params = SighashParams {
                version,
                inputs: &sig_inputs,
                outputs: &sig_outputs,
                locktime: lock_time,
                input_index,
                subscript: &subscript,
                satoshis: prevout_sats[input_index],
                scope,
            };
            let preimage = build_sighash_preimage(&params);
            let digest = compute_sighash_for_signing(&params); // natural order (`compute_sighash` reverses for display, sighash.rs:837–843 at 0.4.4)
            let line = serde_json::json!({
                "tx": hex::encode(tx.encode()),
                "prevouts": prevout_scripts.iter().zip(prevout_sats.iter()).map(|(s, v)| serde_json::json!({"script": hex::encode(s), "satoshis": v})).collect::<Vec<_>>(),
                "input_index": input_index,
                "subscript": hex::encode(&subscript),
                "satoshis": prevout_sats[input_index],
                "scope": scope,
                "preimage": hex::encode(&preimage),
                "digest": hex::encode(digest),
            });
            println!("{line}");
            emitted += 1;
            if emitted >= count {
                break;
            }
        }
    }
}
