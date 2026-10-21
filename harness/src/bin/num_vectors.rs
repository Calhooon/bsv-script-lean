//! num_vectors (this repo's; #7): emits the pinned bsv-rs's number-type behaviour (0.4.4 since 2026-10-12, 0.3.33 from 2026-10-07, bsv-rs#41 (0.3.30 from 2026-09-27, 0.3.28 from 2026-09-24, 0.3.27 on 2026-09-23); byte-identical to 0.3.24's) on
//! boundary and random byte strings as JSON lines, for the Lean `Numbers` module's
//! property check (`lean/Test/NumbersCheck.lean`, `make numcheck`). Deterministic
//! from its seed. bsv-rs is the implementation under comparison here, not the
//! reference: a disagreement between the Lean (read from bitcoin-sv v1.2.2) and
//! bsv-rs is recorded, never resolved by bending either.
//!
//! Run: cargo run --release --bin num_vectors -- [--count N] [--seed HEX] > vectors.jsonl

use bsv_rs::primitives::BigNumber;
use bsv_rs::script::script_num::ScriptNum;
use bsv_script_harness::gen::{enc_num, Rng, BOUNDARY_OPERANDS};

fn arg(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1).cloned())
}

/// A decimal string of the BigNumber (its own Display/to_string).
fn dec(b: &BigNumber) -> String {
    b.to_string()
}

#[allow(
    clippy::expect_used,
    reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
)]
fn main() {
    let args: Vec<String> = std::env::args().collect();
    let count: usize = arg(&args, "--count")
        .map(|s| s.parse().expect("--count"))
        .unwrap_or(1000);
    let seed: u64 = arg(&args, "--seed")
        .map(|s| u64::from_str_radix(s.trim_start_matches("0x"), 16).expect("--seed is hex"))
        .unwrap_or(0x0007_0007_0007_0007);
    let mut rng = Rng(seed);
    let mut inputs: Vec<Vec<u8>> = Vec::new();
    // the corners first: every boundary operand's minimal encoding, its 0x00/0x80
    // pads, negative zero in three widths, empty, and the single bytes
    for &v in BOUNDARY_OPERANDS {
        let e = enc_num(v);
        inputs.push(e.clone());
        let mut p = e.clone();
        p.push(if v < 0 { 0x80 } else { 0x00 });
        if v < 0 {
            let l = p.len() - 2;
            p[l] &= 0x7f;
        }
        inputs.push(p);
    }
    inputs.push(vec![]);
    inputs.push(vec![0x80]);
    inputs.push(vec![0x00, 0x80]);
    inputs.push(vec![0x00, 0x00, 0x80]);
    inputs.push(vec![0x00]);
    inputs.push(vec![0x00, 0x00]);
    inputs.push(vec![0xff, 0x00, 0x00]);
    inputs.push(vec![0xff, 0x80, 0x00]);
    for b in 0u8..=255 {
        inputs.push(vec![b]);
    }
    while inputs.len() < count {
        let long = rng.below(4) == 0;
        let len = 1 + rng.below(if long { 40 } else { 9 });
        let mut v: Vec<u8> = (0..len).map(|_| (rng.next() & 0xff) as u8).collect();
        match rng.below(6) {
            0 => {
                let l = v.len() - 1;
                v[l] = 0x00;
            }
            1 => {
                let l = v.len() - 1;
                v[l] = 0x80;
            }
            2 => {
                let l = v.len() - 1;
                v[l] &= 0x7f;
            }
            _ => {}
        }
        inputs.push(v);
    }
    inputs.truncate(count.max(inputs.len().min(count)));
    for bytes in inputs.iter().take(count) {
        let strict = ScriptNum::from_bytes(bytes, true);
        let lax = ScriptNum::from_bytes(bytes, false).expect("lax decode never fails");
        let reencoded = ScriptNum::to_bytes(&lax);
        let line = serde_json::json!({
            "bytes": hex::encode(bytes),
            "value": dec(&lax),
            "strict_ok": strict.is_ok(),
            "minimal": ScriptNum::is_minimally_encoded(bytes),
            "minimally_encoded": hex::encode(ScriptNum::minimally_encode(bytes)),
            "encode_of_value": hex::encode(&reencoded),
            "bool": ScriptNum::cast_to_bool(bytes),
        });
        println!("{line}");
    }
}
