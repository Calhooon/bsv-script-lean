//! The arithmetic vectors (#9): the pinned bsv-rs's number arithmetic (0.4.4 since 2026-10-12, 0.3.33 from 2026-10-07, bsv-rs#41 (0.3.30 from 2026-09-27, 0.3.28 from 2026-09-24, 0.3.27 on 2026-09-23); byte-identical to 0.3.24's) on random
//! operand pairs and the width boundaries, value by value, for
//! `lean/Test/ArithCheck.lean`. The operands go through `ScriptNum::from_bytes`
//! (no minimality requirement; minimality is `num_vectors`'s business), the
//! results through `ScriptNum::to_bytes` (`bsv-rs/src/script/script_num.rs`),
//! the operations through `BigNumber` (`src/primitives/bignum.rs`: `add`, `sub`,
//! `mul`, `div`, `mod_floor`, `neg`, `abs`, the ordering), exactly what
//! `spend.rs:960–1080` (at 0.3.24) calls for the opcodes.
//!
//! One line per operand pair: `{"a": hex, "b": hex, "bin": {op: result-hex |
//! "div0"}, "un": {op: result-hex}, "within": {"lo": hex, "hi": hex, "r": hex}}`.
//! Deterministic from the seed. Run: cargo run --release --bin arith_vectors -- [--count N] > out.jsonl
use bsv_rs::primitives::bignum::BigNumber;
use bsv_rs::script::script_num::ScriptNum;
use bsv_script_harness::gen::Rng;

fn arg(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1).cloned())
}

/// The boundary operands: every power-of-two edge of the 4-, 8- and 9-byte widths, both signs, negative zero, the pads.
fn boundaries() -> Vec<Vec<u8>> {
    let mut v: Vec<Vec<u8>> = vec![
        vec![],
        vec![0x80],
        vec![0x00],
        vec![0x00, 0x80],
        vec![0x01],
        vec![0x81],
        vec![0x7f],
        vec![0xff],
    ];
    for bits in [
        7u32, 8, 15, 16, 23, 24, 31, 32, 39, 40, 47, 48, 55, 56, 63, 64, 71, 72, 79, 80, 127, 128,
        255, 256,
    ] {
        let mut le = vec![0u8; (bits as usize) / 8 + 1];
        le[(bits as usize) / 8] = 1u8 << (bits % 8);
        let p = BigNumber::from_bytes_le(&le);
        for x in [
            p.sub(&BigNumber::one()),
            p.clone(),
            p.add(&BigNumber::one()),
        ] {
            v.push(ScriptNum::to_bytes(&x));
            v.push(ScriptNum::to_bytes(&x.neg()));
        }
    }
    v
}

fn random_operand(rng: &mut Rng) -> Vec<u8> {
    // widths: mostly small, sometimes wide (to 100 bytes), sometimes non-minimal
    let w = match rng.below(10) {
        0 => 0,
        1..=5 => 1 + rng.below(4),
        6..=7 => 5 + rng.below(5),
        8 => 10 + rng.below(23),
        _ => 33 + rng.below(68),
    };
    let mut b: Vec<u8> = (0..w).map(|_| rng.below(256) as u8).collect();
    if w > 0 && rng.below(6) == 0 {
        // a non-minimal pad: a trailing 0x00 or 0x80 sign byte with a clear top bit before it
        if let Some(l) = b.last_mut() {
            *l &= 0x7f;
        }
        b.push(if rng.below(2) == 0 { 0x00 } else { 0x80 });
    }
    b
}

#[allow(
    clippy::expect_used,
    reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
)]
fn main() {
    let args: Vec<String> = std::env::args().collect();
    let count: usize = arg(&args, "--count")
        .map(|s| s.parse().expect("--count"))
        .unwrap_or(10_000);
    let seed: u64 = arg(&args, "--seed")
        .map(|s| u64::from_str_radix(s.trim_start_matches("0x"), 16).expect("--seed"))
        .unwrap_or(0x0009_0009_0009_0009);
    let mut rng = Rng(seed);
    let bounds = boundaries();
    let bin_ops = [
        "ADD",
        "SUB",
        "MUL",
        "DIV",
        "MOD",
        "BOOLAND",
        "BOOLOR",
        "NUMEQUAL",
        "NUMNOTEQUAL",
        "LESSTHAN",
        "GREATERTHAN",
        "LESSTHANOREQUAL",
        "GREATERTHANOREQUAL",
        "MIN",
        "MAX",
    ];
    let un_ops = [
        "1ADD",
        "1SUB",
        "2MUL",
        "2DIV",
        "NEGATE",
        "ABS",
        "NOT",
        "0NOTEQUAL",
    ];
    let one = BigNumber::one();
    let two = one.add(&one);
    let zero = BigNumber::zero();
    let bool_bn = |b: bool| if b { one.clone() } else { zero.clone() };
    for i in 0..count {
        // the first pairs walk the boundary list against itself, then random
        let (a, b) = if i < bounds.len() * 4 {
            (
                bounds[i % bounds.len()].clone(),
                bounds[(i / 4 + i * 7) % bounds.len()].clone(),
            )
        } else if rng.below(4) == 0 {
            (
                bounds[rng.below(bounds.len())].clone(),
                random_operand(&mut rng),
            )
        } else {
            (random_operand(&mut rng), random_operand(&mut rng))
        };
        let x = ScriptNum::from_bytes(&a, false).expect("a");
        let y = ScriptNum::from_bytes(&b, false).expect("b");
        let mut bin = serde_json::Map::new();
        for op in bin_ops {
            let r: Option<BigNumber> = match op {
                "ADD" => Some(x.add(&y)),
                "SUB" => Some(x.sub(&y)),
                "MUL" => Some(x.mul(&y)),
                "DIV" => {
                    if y.is_zero() {
                        None
                    } else {
                        Some(x.div(&y))
                    }
                }
                "MOD" => {
                    if y.is_zero() {
                        None
                    } else {
                        Some(x.mod_floor(&y))
                    }
                }
                "BOOLAND" => Some(bool_bn(!x.is_zero() && !y.is_zero())),
                "BOOLOR" => Some(bool_bn(!x.is_zero() || !y.is_zero())),
                "NUMEQUAL" => Some(bool_bn(x == y)),
                "NUMNOTEQUAL" => Some(bool_bn(x != y)),
                "LESSTHAN" => Some(bool_bn(x < y)),
                "GREATERTHAN" => Some(bool_bn(x > y)),
                "LESSTHANOREQUAL" => Some(bool_bn(x <= y)),
                "GREATERTHANOREQUAL" => Some(bool_bn(x >= y)),
                "MIN" => Some(if x < y { x.clone() } else { y.clone() }),
                "MAX" => Some(if x > y { x.clone() } else { y.clone() }),
                _ => unreachable!(),
            };
            bin.insert(
                op.to_string(),
                match r {
                    Some(v) => serde_json::Value::String(hex::encode(ScriptNum::to_bytes(&v))),
                    None => serde_json::Value::String("div0".into()),
                },
            );
        }
        let mut un = serde_json::Map::new();
        for op in un_ops {
            let r: BigNumber = match op {
                "1ADD" => x.add(&one),
                "1SUB" => x.sub(&one),
                "2MUL" => x.add(&x),
                "2DIV" => x.div(&two),
                "NEGATE" => x.neg(),
                "ABS" => x.abs(),
                "NOT" => bool_bn(x.is_zero()),
                "0NOTEQUAL" => bool_bn(!x.is_zero()),
                _ => unreachable!(),
            };
            un.insert(
                op.to_string(),
                serde_json::Value::String(hex::encode(ScriptNum::to_bytes(&r))),
            );
        }
        // WITHIN: x within [lo, hi) with lo = min(a,b) - r1, hi = max(a,b) + r2 for small random r1, r2 (sometimes equal bounds)
        let lo_v = if x < y { x.clone() } else { y.clone() };
        let hi_v = if x > y { x.clone() } else { y.clone() };
        let d1 = BigNumber::from_i64(rng.below(3) as i64 - 1);
        let d2 = BigNumber::from_i64(rng.below(3) as i64 - 1);
        let lo = lo_v.add(&d1);
        let hi = hi_v.add(&d2);
        let within = bool_bn(lo <= x && x < hi);
        let line = serde_json::json!({
            "a": hex::encode(&a), "b": hex::encode(&b), "bin": bin, "un": un,
            "within": {"lo": hex::encode(ScriptNum::to_bytes(&lo)), "hi": hex::encode(ScriptNum::to_bytes(&hi)), "r": hex::encode(ScriptNum::to_bytes(&within))}
        });
        println!("{}", line);
    }
}
