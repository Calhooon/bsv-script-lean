//! arith_cases (#9): the hand-written and enumerated bitwise and arithmetic
//! corpus, emitted in the corpus format with the pinned bsv-rs's verdict (0.4.4 since 2026-10-12, 0.3.33 from 2026-10-07, bsv-rs#41; 0.3.30 from 2026-09-27, 0.3.28 from 2026-09-24; 0.3.24 at birth), for
//! `lean/Test/ArithCheck.lean` (`make arithcheck`). The value-level vectors are
//! `arith_vectors`; this file exercises the opcodes THROUGH the engine: the
//! bitwise family on byte vectors (`OP_AND`/`OP_OR`/`OP_XOR`, `OP_INVERT`,
//! `OP_LSHIFT`/`OP_RSHIFT`, `OP_EQUAL`/`OP_EQUALVERIFY`), the arithmetic error
//! paths (a zero divisor, `OP_NUMEQUALVERIFY`, `OP_WITHIN` at its bounds), wide
//! operands, and the version-1 twins (`MINIMALDATA` bites on a non-minimal
//! operand). A positive case's expected value comes from a model written here
//! (the reference's byte loops, `interpreter.cpp:65–117`, transcribed); bsv-rs
//! judges the model (a positive case bsv-rs rejects aborts the generator), and
//! the Lean check must reproduce bsv-rs's verdict.
//!
//! Families: `bitwise/…`, `arith/…` are COMPARABLE with bsv-rs under the node's
//! standard word. Until bsv-rs 0.3.27 (the pin of 2026-09-23; 0.3.28 from 2026-09-24, 0.3.30 from 2026-09-27, 0.4.4 since 2026-10-12, 0.3.33 from 2026-10-07) `arith-candidate/…`
//! held `OP_2MUL`/`OP_2DIV`, which 0.3.24 disabled always where the reference
//! executes them for a post-Chronicle UTXO (`interpreter.cpp:360–375`): #15's
//! witnesses, fixed upstream (bsv-rs#12) and comparable since.
//!
//! Run: cargo run --release --bin arith_cases -- [--out DIR]

use bsv_script_harness::cases::{arg, c, num, pm, Case, Corpus, Quiet, Text};
use bsv_script_harness::engine::EngineConfig;
use bsv_script_harness::gen::{OP_0, OP_1, OP_EQUAL, OP_EQUALVERIFY};

const OP_INVERT: u8 = 0x83;
const OP_AND: u8 = 0x84;
const OP_OR: u8 = 0x85;
const OP_XOR: u8 = 0x86;
const OP_2MUL: u8 = 0x8d;
const OP_2DIV: u8 = 0x8e;
const OP_ADD: u8 = 0x93;
const OP_DIV: u8 = 0x96;
const OP_MOD: u8 = 0x97;
const OP_LSHIFT: u8 = 0x98;
const OP_RSHIFT: u8 = 0x99;
const OP_NUMEQUALVERIFY: u8 = 0x9d;
const OP_WITHIN: u8 = 0xa5;

/// `RShift` (`interpreter.cpp:65–88`), transcribed.
fn rshift(x: &[u8], n: usize) -> Vec<u8> {
    let (bit_shift, byte_shift) = (n % 8, n / 8);
    let mask: u8 = [0xFF, 0xFE, 0xFC, 0xF8, 0xF0, 0xE0, 0xC0, 0x80][bit_shift];
    let overflow: u8 = !mask;
    let mut r = vec![0u8; x.len()];
    for i in 0..x.len() {
        let k = i + byte_shift;
        if k < x.len() {
            r[k] |= (x[i] & mask) >> bit_shift;
        }
        if k + 1 < x.len() {
            r[k + 1] |= ((x[i] & overflow) as u16 as u32)
                .checked_shl((8 - bit_shift) as u32)
                .unwrap_or(0) as u8;
        }
    }
    r
}

/// `LShift` (`interpreter.cpp:91–117`), transcribed.
fn lshift(x: &[u8], n: usize) -> Vec<u8> {
    let (bit_shift, byte_shift) = (n % 8, n / 8);
    let mask: u8 = [0xFF, 0x7F, 0x3F, 0x1F, 0x0F, 0x07, 0x03, 0x01][bit_shift];
    let overflow: u8 = !mask;
    let mut r = vec![0u8; x.len()];
    for index in (1..=x.len()).rev() {
        let i = index - 1;
        if byte_shift <= i {
            let k = i - byte_shift;
            r[k] |= ((x[i] & mask) as u32)
                .checked_shl(bit_shift as u32)
                .unwrap_or(0) as u8;
            if k >= 1 {
                r[k - 1] |= (x[i] & overflow) >> (8 - bit_shift);
            }
        }
    }
    r
}

fn splitmix(state: &mut u64) -> u64 {
    *state = state.wrapping_add(0x9E37_79B9_7F4A_7C15);
    let mut z = *state;
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
    z ^ (z >> 31)
}

fn rand_bytes(state: &mut u64, n: usize) -> Vec<u8> {
    (0..n).map(|_| (splitmix(state) & 0xff) as u8).collect()
}

#[allow(
    clippy::unwrap_used,
    reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
)]
fn cases() -> Vec<Case> {
    let mut v = Vec::new();
    let mut rs = 0x0009_0009_0009_0009u64;
    // AND / OR / XOR on equal sizes, sizes 0, 1, 2, 8, 33, 80, 520
    for &(op, name) in &[(OP_AND, "and"), (OP_OR, "or"), (OP_XOR, "xor")] {
        for &w in &[0usize, 1, 2, 8, 33, 80, 520] {
            let a = rand_bytes(&mut rs, w);
            let b = rand_bytes(&mut rs, w);
            let r: Vec<u8> = a
                .iter()
                .zip(b.iter())
                .map(|(x, y)| match op {
                    OP_AND => x & y,
                    OP_OR => x | y,
                    _ => x ^ y,
                })
                .collect();
            let mut lock = pm(&b);
            lock.push(op);
            lock.extend(pm(&r));
            lock.push(OP_EQUAL);
            v.push(c(
                &format!("bitwise/{name}"),
                "bitwise.andorxor",
                lock,
                pm(&a),
                &format!("{name} on {w}-byte operands"),
                true,
            ));
        }
        // unequal sizes: SCRIPT_ERR_INVALID_OPERAND_SIZE (1080–1081)
        for &(w1, w2) in &[(1usize, 2usize), (0, 1), (8, 7), (32, 33)] {
            let a = rand_bytes(&mut rs, w1);
            let b = rand_bytes(&mut rs, w2);
            let mut lock = pm(&b);
            lock.push(op);
            lock.push(OP_1);
            v.push(c(
                &format!("bitwise/{name}/operand-size"),
                "bitwise.operand-size",
                lock,
                pm(&a),
                &format!("{name} on {w1} vs {w2} bytes: OPERAND_SIZE"),
                false,
            ));
        }
        // fewer than two elements
        v.push(c(
            &format!("bitwise/{name}/underflow"),
            "bitwise.andorxor",
            vec![op, OP_1],
            pm(&[1]),
            "one element: INVALID_STACK_OPERATION",
            false,
        ));
    }
    // INVERT
    for &w in &[0usize, 1, 2, 8, 33, 520] {
        let a = rand_bytes(&mut rs, w);
        let r: Vec<u8> = a.iter().map(|x| !x).collect();
        let mut lock = vec![OP_INVERT];
        lock.extend(pm(&r));
        lock.push(OP_EQUAL);
        v.push(c(
            "bitwise/invert",
            "bitwise.invert",
            lock,
            pm(&a),
            &format!("invert {w} bytes"),
            true,
        ));
    }
    v.push(c(
        "bitwise/invert/underflow",
        "bitwise.invert",
        vec![OP_INVERT],
        vec![],
        "empty stack: INVALID_STACK_OPERATION",
        false,
    ));
    // LSHIFT / RSHIFT: widths × counts, including counts at and past the width and the INT32 edge of the count
    for &(op, name) in &[(OP_LSHIFT, "lshift"), (OP_RSHIFT, "rshift")] {
        for &w in &[0usize, 1, 2, 3, 8, 20] {
            let a = rand_bytes(&mut rs, w);
            let mut counts: Vec<i64> = vec![
                0, 1, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63, 64, 65, 1000, 65535, 65536, 2147483647,
                2147483648, 4294967296,
            ];
            if w > 0 {
                counts.extend([8 * w as i64 - 1, 8 * w as i64, 8 * w as i64 + 1]);
            }
            counts.sort();
            counts.dedup();
            for n in counts {
                let r = if n as u128 >= (w as u128) * 8 {
                    vec![0u8; w]
                } else if op == OP_LSHIFT {
                    lshift(&a, n as usize)
                } else {
                    rshift(&a, n as usize)
                };
                let mut lock = pm(&num(n));
                lock.push(op);
                lock.extend(pm(&r));
                lock.push(OP_EQUAL);
                v.push(c(
                    &format!("bitwise/{name}"),
                    "bitwise.shift",
                    lock,
                    pm(&a),
                    &format!("{name} {w} bytes by {n}"),
                    true,
                ));
            }
            // a negative count: SCRIPT_ERR_INVALID_NUMBER_RANGE (1130–1131)
            let mut lock = pm(&num(-1));
            lock.push(op);
            lock.push(OP_1);
            v.push(c(
                &format!("bitwise/{name}/negative"),
                "bitwise.shift",
                lock,
                pm(&a),
                &format!("{name} by -1: INVALID_NUMBER_RANGE"),
                false,
            ));
        }
        // a non-minimal count: the version gate (MINIMALDATA under version 1 only)
        let mut lock = pm(&[0x01, 0x00]);
        lock.push(op);
        lock.extend(pm(&(if op == OP_LSHIFT {
            lshift(&[0x81], 1)
        } else {
            rshift(&[0x81], 1)
        })));
        lock.push(OP_EQUAL);
        v.push(c(&format!("bitwise/{name}/nonminimal-count"), "flags.version-gate", lock, pm(&[0x81]), &format!("{name} by the non-minimal 0x0100: valid under version 2, SCRIPTNUM_MINENCODE under version 1"), true));
    }
    // EQUAL / EQUALVERIFY
    for &w in &[0usize, 1, 33, 600] {
        let a = rand_bytes(&mut rs, w);
        let mut b = a.clone();
        if w > 0 {
            b[w / 2] ^= 1;
        } else {
            b = vec![0];
        }
        let mut lock = pm(&a);
        lock.push(OP_EQUAL);
        v.push(c(
            "bitwise/equal",
            "bitwise.equal",
            lock,
            pm(&a),
            &format!("equal {w} bytes"),
            true,
        ));
        let mut lock = pm(&b);
        lock.push(OP_EQUAL);
        lock.push(0x91); // OP_NOT: the false result becomes true
        v.push(c(
            "bitwise/equal/unequal",
            "bitwise.equal",
            lock,
            pm(&a),
            &format!("unequal {w} bytes, negated"),
            true,
        ));
        let mut lock = pm(&a);
        lock.push(OP_EQUALVERIFY);
        lock.push(OP_1);
        v.push(c(
            "bitwise/equalverify",
            "bitwise.equal",
            lock,
            pm(&a),
            &format!("equalverify {w} bytes"),
            true,
        ));
        let mut lock = pm(&b);
        lock.push(OP_EQUALVERIFY);
        lock.push(OP_1);
        v.push(c(
            "bitwise/equalverify/fail",
            "bitwise.equal",
            lock,
            pm(&a),
            "equalverify unequal: EQUALVERIFY",
            false,
        ));
    }
    v.push(c(
        "bitwise/equal/underflow",
        "bitwise.equal",
        vec![OP_EQUAL],
        pm(&[1]),
        "one element: INVALID_STACK_OPERATION",
        false,
    ));
    // arithmetic error paths
    v.push(c(
        "arith/div0",
        "num.arith.div0",
        vec![OP_0, OP_DIV, OP_1],
        pm(&[7]),
        "7 / 0: DIV_BY_ZERO",
        false,
    ));
    v.push(c(
        "arith/mod0",
        "num.arith.mod0",
        vec![OP_0, OP_MOD, OP_1],
        pm(&[7]),
        "7 % 0: MOD_BY_ZERO",
        false,
    ));
    v.push(c(
        "arith/numequalverify",
        "num.cmp.numequalverify",
        {
            let mut l = pm(&num(300));
            l.push(OP_NUMEQUALVERIFY);
            l.push(OP_1);
            l
        },
        pm(&num(300)),
        "300 == 300 verify",
        true,
    ));
    v.push(c(
        "arith/numequalverify/fail",
        "num.cmp.numequalverify",
        {
            let mut l = pm(&num(301));
            l.push(OP_NUMEQUALVERIFY);
            l.push(OP_1);
            l
        },
        pm(&num(300)),
        "300 == 301 verify: NUMEQUALVERIFY",
        false,
    ));
    v.push(c(
        "arith/numequalverify/nonminimal-equal",
        "num.cmp.numequalverify",
        {
            let mut l = pm(&[0x01, 0x00]);
            l.push(OP_NUMEQUALVERIFY);
            l.push(OP_1);
            l
        },
        pm(&[1]),
        "1 == 0x0100 numerically: the version gate (valid under 2, SCRIPTNUM_MINENCODE under 1)",
        true,
    ));
    for &(x, lo, hi, ok) in &[
        (5i64, 5i64, 10i64, true),
        (10, 5, 10, false),
        (4, 5, 10, false),
        (-3, -3, -2, true),
        (0, 0, 0, false),
        (7, 10, 5, false),
    ] {
        let mut l = pm(&num(lo));
        l.extend(pm(&num(hi)));
        l.push(OP_WITHIN);
        if !ok {
            l.push(0x91);
        }
        v.push(c(
            "arith/within",
            "num.cmp.within",
            l,
            pm(&num(x)),
            &format!("within {x} in [{lo},{hi}) = {ok}"),
            true,
        ));
    }
    v.push(c(
        "arith/within/underflow",
        "num.cmp.within",
        vec![OP_WITHIN],
        {
            let mut u = pm(&[1]);
            u.extend(pm(&[2]));
            u
        },
        "two elements: INVALID_STACK_OPERATION",
        false,
    ));
    // #19: MINIMALDATA on the number reads of this family (1235 the unary read, 1300–1301 the binary
    // reads, 1386–1390 OP_WITHIN): a padded operand is SCRIPTNUM_MINENCODE under version 1
    v.push(c("arith/1add/nonminimal", "flags.v1.minimaldata.number", { let mut l = vec![0x8b]; l.extend(pm(&num(2))); l.push(OP_EQUAL); l }, pm(&[0x01, 0x00]), "OP_1ADD of the padded 0x0100 = 1 (1235): valid under version 2, SCRIPTNUM_MINENCODE under version 1", true));
    v.push(c(
        "arith/add/nonminimal-top",
        "flags.v1.minimaldata.number",
        {
            let mut l = pm(&[0x01, 0x00]);
            l.push(OP_ADD);
            l.extend(pm(&num(2)));
            l.push(OP_EQUAL);
            l
        },
        pm(&[1]),
        "OP_ADD with the top operand padded (1301)",
        true,
    ));
    v.push(c(
        "arith/add/nonminimal-second",
        "flags.v1.minimaldata.number",
        {
            let mut l = pm(&[1]);
            l.push(OP_ADD);
            l.extend(pm(&num(2)));
            l.push(OP_EQUAL);
            l
        },
        pm(&[0x01, 0x00]),
        "OP_ADD with the second operand padded (1300)",
        true,
    ));
    v.push(c(
        "arith/within/nonminimal-max",
        "flags.v1.minimaldata.number",
        {
            let mut l = vec![OP_0];
            l.extend(pm(&[0x02, 0x00]));
            l.push(OP_WITHIN);
            l
        },
        pm(&[1]),
        "OP_WITHIN with the max padded (1390)",
        true,
    ));
    v.push(c(
        "arith/within/nonminimal-x",
        "flags.v1.minimaldata.number",
        {
            let mut l = vec![OP_0];
            l.extend(pm(&num(2)));
            l.push(OP_WITHIN);
            l
        },
        pm(&[0x01, 0x00]),
        "OP_WITHIN with x padded (1386)",
        true,
    ));
    // wide operands (100 bytes): exact arithmetic, the result minimal
    let a = {
        let mut b = rand_bytes(&mut rs, 100);
        b[99] &= 0x7f;
        b
    };
    let b = {
        let mut b = rand_bytes(&mut rs, 100);
        b[99] &= 0x7f;
        b
    };
    let sum = {
        // little-endian add of two non-negative magnitudes
        let mut r = Vec::new();
        let mut carry = 0u16;
        for i in 0..100 {
            let s = a[i] as u16 + b[i] as u16 + carry;
            r.push((s & 0xff) as u8);
            carry = s >> 8;
        }
        if carry > 0 {
            r.push(carry as u8);
        }
        while r.len() > 1 && *r.last().unwrap() == 0 && r[r.len() - 2] & 0x80 == 0 {
            r.pop();
        }
        if r.last().unwrap() & 0x80 != 0 {
            r.push(0);
        }
        r
    };
    let mut lock = pm(&b);
    lock.push(OP_ADD);
    lock.extend(pm(&sum));
    lock.push(OP_EQUAL);
    v.push(c(
        "arith/wide",
        "num.arith.add",
        lock,
        pm(&a),
        "100-byte + 100-byte",
        true,
    ));
    // OP_2MUL / OP_2DIV: executed for a post-Chronicle UTXO by the reference; bsv-rs disables them always (spend.rs:1699–1701 at 0.3.24)
    v.push(c("arith/2mul", "num.arith.2mul", { let mut l = vec![OP_2MUL]; l.extend(pm(&num(14))); l.push(OP_EQUAL); l }, pm(&num(7)), "7 2MUL = 14 post-Chronicle (bsv-rs 0.3.24 disabled it; 0.3.27 executes it under UTXO_AFTER_CHRONICLE)", false));
    v.push(c(
        "arith/2div",
        "num.arith.2div",
        {
            let mut l = vec![OP_2DIV];
            l.extend(pm(&num(-3)));
            l.push(OP_EQUAL);
            l
        },
        pm(&num(-7)),
        "-7 2DIV = -3 (toward zero) post-Chronicle (bsv-rs 0.3.24 disabled it; 0.3.27 executes it)",
        false,
    ));
    v
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let out_dir = arg(&args, "--out").unwrap_or_else(|| "../corpus/arith".into());
    let mut quiet = Quiet::new();
    let mut corpus = Corpus::new(EngineConfig::default());
    corpus.twins(&mut quiet, "arith", cases());
    quiet.restore();
    let comparable = corpus.comparable();
    let (path, sha, _) = corpus.write(&out_dir, Text {
        corpus: "arith-cases",
        file: "cases.jsonl",
        manifest: "cases-manifest.json",
        generator: "bsv-script-harness arith_cases 0.0.1 (a hand-written and enumerated table; #9)".into(),
        seed: "0x0009000900090009 (the operand bytes)".into(),
        generated: "2026-09-23".into(),
        provenance: format!("bitwise and arithmetic cases with bsv-rs {}'s verdicts; {comparable} comparable (bitwise/, arith/), the rest arith-candidate/ (recorded, #15's witnesses); synthetic outpoints = sha256 of the entry id", bsv_script_harness::BSV_RS_VERSION),
    });
    corpus.report("arith_cases", comparable, &path, &sha);
}
