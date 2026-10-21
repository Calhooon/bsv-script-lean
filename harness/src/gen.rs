//! VENDORED (adapted from a predecessor harness of the owner's, mechanism-free)
//! from its fuzz binary @ 0fc5ced on 2026-09-22
//! (bsv-script-lean #4): the splitmix64 PRNG (lines 50–68), the opcode bytes,
//! the independent minimal number encoder `enc_num`, `push_min`/`push_nonmin`,
//! the boundary operands and `pick_operand`, the arithmetic specs and the i128
//! reference model `reference_eval` (519–720), the byte-level mutation
//! operators `mutate` (722–787), `bucket` (817–820), and the five generated
//! families of its phase 4 (1010–1290: arithmetic against the reference model
//! with a reject twin and the by-zero case; non-minimal encodings; element-size
//! boundaries; stack-depth extremes; NUM2BIN/BIN2NUM round trips).
//! Mechanism check: the covenant corpora of that file (its `corpus_*` builders,
//! phases 0–3 on the mainnet-shipped cases, every import of the predecessor crate) did NOT
//! cross; no transaction, txid, block, key or script of any private program is
//! here; every script below is synthesized from the operands the PRNG draws.
//! Modifications below are this repo's: the families return `GenCase` records
//! carrying a family, a rule id (`corpus/INDEX.md`) and the reference model's
//! expectation instead of running the engine inline; the mutation campaign is a
//! family over previously generated cases.

/// splitmix64: no entropy source, the seed is the whole state, fully reproducible.
pub struct Rng(pub u64);

impl Rng {
    #[allow(
        clippy::should_implement_trait,
        reason = "splitmix64's step, not an Iterator: every seed generator calls it by this name"
    )]
    pub fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }
    pub fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }
}

// opcode bytes used by the generator
pub const OP_0: u8 = 0x00;
pub const OP_PUSHDATA1: u8 = 0x4c;
pub const OP_PUSHDATA2: u8 = 0x4d;
pub const OP_1NEGATE: u8 = 0x4f;
pub const OP_1: u8 = 0x51;
pub const OP_DROP: u8 = 0x75;
pub const OP_DEPTH: u8 = 0x74;
pub const OP_SIZE: u8 = 0x82;
pub const OP_EQUAL: u8 = 0x87;
pub const OP_EQUALVERIFY: u8 = 0x88;
pub const OP_1ADD: u8 = 0x8b;
pub const OP_1SUB: u8 = 0x8c;
pub const OP_NEGATE: u8 = 0x8f;
pub const OP_ABS: u8 = 0x90;
pub const OP_ADD: u8 = 0x93;
pub const OP_SUB: u8 = 0x94;
pub const OP_MUL: u8 = 0x95;
pub const OP_DIV: u8 = 0x96;
pub const OP_MOD: u8 = 0x97;
pub const OP_NUMEQUAL: u8 = 0x9c;
pub const OP_NUMNOTEQUAL: u8 = 0x9e;
pub const OP_LESSTHAN: u8 = 0x9f;
pub const OP_GREATERTHAN: u8 = 0xa0;
pub const OP_MIN: u8 = 0xa3;
pub const OP_MAX: u8 = 0xa4;
pub const OP_NUM2BIN: u8 = 0x80;
pub const OP_BIN2NUM: u8 = 0x81;

/// Minimal script-number encoding (LE magnitude, 0x80 sign bit, empty = 0),
/// written independently of every implementation so it is a genuine reference
/// model. (The spec's own `Numbers.encode` will be checked against it at #7.)
pub fn enc_num(v: i128) -> Vec<u8> {
    if v == 0 {
        return vec![];
    }
    let neg = v < 0;
    let mut mag = v.unsigned_abs();
    let mut out = Vec::new();
    while mag > 0 {
        out.push((mag & 0xff) as u8);
        mag >>= 8;
    }
    if out.last().is_some_and(|b| b & 0x80 != 0) {
        out.push(if neg { 0x80 } else { 0x00 });
    } else if neg {
        let last = out.len() - 1;
        out[last] |= 0x80;
    }
    out
}

/// Canonical minimal push of `data` (OP_0 / OP_1..16 / OP_1NEGATE / direct /
/// PUSHDATA1/2).
pub fn push_min(out: &mut Vec<u8>, data: &[u8]) {
    if data.is_empty() {
        out.push(OP_0);
    } else if data.len() == 1 && (1..=16).contains(&data[0]) {
        out.push(OP_1 - 1 + data[0]);
    } else if data.len() == 1 && data[0] == 0x81 {
        out.push(OP_1NEGATE);
    } else if data.len() < 0x4c {
        out.push(data.len() as u8);
        out.extend_from_slice(data);
    } else if data.len() <= 0xff {
        out.push(OP_PUSHDATA1);
        out.push(data.len() as u8);
        out.extend_from_slice(data);
    } else {
        out.push(OP_PUSHDATA2);
        out.extend_from_slice(&(data.len() as u16).to_le_bytes());
        out.extend_from_slice(data);
    }
}

/// Deliberately NON-canonical push (PUSHDATA1 where a direct push would do):
/// probes the version-1 minimal-push rule.
pub fn push_nonmin(out: &mut Vec<u8>, data: &[u8]) {
    out.push(OP_PUSHDATA1);
    out.push(data.len() as u8);
    out.extend_from_slice(data);
}

pub const BOUNDARY_OPERANDS: &[i128] = &[
    0,
    1,
    -1,
    2,
    16,
    17,
    127,
    128,
    -127,
    -128,
    255,
    256,
    32767,
    32768,
    -32768,
    (1_i128 << 31) - 1,
    1_i128 << 31,
    (1_i128 << 31) + 1,
    -(1_i128 << 31),
    -((1_i128 << 31) + 1),
    1_i128 << 32,
    (1_i128 << 32) + 1,
    -(1_i128 << 32),
    1_i128 << 62,
    i64::MAX as i128,
    i64::MIN as i128 + 1,
    i64::MIN as i128,
];

pub fn pick_operand(rng: &mut Rng) -> i128 {
    match rng.below(4) {
        0 => BOUNDARY_OPERANDS[rng.below(BOUNDARY_OPERANDS.len())],
        1 => BOUNDARY_OPERANDS[rng.below(BOUNDARY_OPERANDS.len())]
            .wrapping_add(rng.below(5) as i128 - 2),
        2 => (rng.next() as i64 % 1_000_000) as i128,
        _ => rng.next() as i64 as i128,
    }
}

pub struct ArithSpec {
    pub op: u8,
    pub name: &'static str,
    pub binary: bool,
}

pub const ARITH_OPS: &[ArithSpec] = &[
    ArithSpec {
        op: OP_ADD,
        name: "ADD",
        binary: true,
    },
    ArithSpec {
        op: OP_SUB,
        name: "SUB",
        binary: true,
    },
    ArithSpec {
        op: OP_MUL,
        name: "MUL",
        binary: true,
    },
    ArithSpec {
        op: OP_DIV,
        name: "DIV",
        binary: true,
    },
    ArithSpec {
        op: OP_MOD,
        name: "MOD",
        binary: true,
    },
    ArithSpec {
        op: OP_MIN,
        name: "MIN",
        binary: true,
    },
    ArithSpec {
        op: OP_MAX,
        name: "MAX",
        binary: true,
    },
    ArithSpec {
        op: OP_LESSTHAN,
        name: "LESSTHAN",
        binary: true,
    },
    ArithSpec {
        op: OP_GREATERTHAN,
        name: "GREATERTHAN",
        binary: true,
    },
    ArithSpec {
        op: OP_NUMEQUAL,
        name: "NUMEQUAL",
        binary: true,
    },
    ArithSpec {
        op: OP_NUMNOTEQUAL,
        name: "NUMNOTEQUAL",
        binary: true,
    },
    ArithSpec {
        op: OP_1ADD,
        name: "1ADD",
        binary: false,
    },
    ArithSpec {
        op: OP_1SUB,
        name: "1SUB",
        binary: false,
    },
    ArithSpec {
        op: OP_NEGATE,
        name: "NEGATE",
        binary: false,
    },
    ArithSpec {
        op: OP_ABS,
        name: "ABS",
        binary: false,
    },
];

/// i128 reference semantics. Returns None for div/mod by zero (an engine must
/// error). OP_DIV/OP_MOD truncate toward zero with the sign following the
/// dividend, which is Rust `/` and `%` on integers. (Cited against the
/// reference at #9; until then this is the predecessor's model, `[LIT]`.)
pub fn reference_eval(op: u8, a: i128, b: i128) -> Option<i128> {
    Some(match op {
        OP_ADD => a + b,
        OP_SUB => a - b,
        OP_MUL => a * b,
        OP_DIV => {
            if b == 0 {
                return None;
            }
            a / b
        }
        OP_MOD => {
            if b == 0 {
                return None;
            }
            a % b
        }
        OP_MIN => a.min(b),
        OP_MAX => a.max(b),
        OP_LESSTHAN => (a < b) as i128,
        OP_GREATERTHAN => (a > b) as i128,
        OP_NUMEQUAL => (a == b) as i128,
        OP_NUMNOTEQUAL => (a != b) as i128,
        OP_1ADD => a + 1,
        OP_1SUB => a - 1,
        OP_NEGATE => -a,
        OP_ABS => a.abs(),
        _ => unreachable!(),
    })
}

/// Byte-level, deterministic mutation operators.
pub fn mutate(bytes: &mut Vec<u8>, rng: &mut Rng) -> &'static str {
    if bytes.is_empty() {
        bytes.push((rng.next() & 0xff) as u8);
        return "insert-into-empty";
    }
    match rng.below(9) {
        0 => {
            let i = rng.below(bytes.len());
            bytes[i] ^= 1 << rng.below(8);
            "bit-flip"
        }
        1 => {
            let i = rng.below(bytes.len());
            bytes[i] = (rng.next() & 0xff) as u8;
            "byte-set"
        }
        2 => {
            let i = rng.below(bytes.len());
            bytes.truncate(i);
            "truncate"
        }
        3 => {
            let i = rng.below(bytes.len() + 1);
            bytes.insert(i, (rng.next() & 0xff) as u8);
            "insert"
        }
        4 => {
            let i = rng.below(bytes.len());
            bytes.remove(i);
            "remove"
        }
        5 => {
            let i = rng.below(bytes.len());
            let len = 1 + rng.below(16.min(bytes.len() - i));
            let slice: Vec<u8> = bytes[i..i + len].to_vec();
            let j = rng.below(bytes.len() + 1);
            for (k, b) in slice.into_iter().enumerate() {
                bytes.insert(j + k, b);
            }
            "dup-slice"
        }
        6 => {
            let i = rng.below(bytes.len());
            for k in i..bytes.len().min(i + 4) {
                bytes[k] = 0;
            }
            "zero-window"
        }
        7 => {
            const INTERESTING: &[u8] = &[0x00, 0xff, 0x80, 0x4c, 0x4e, 0x63, 0x67, 0x6a, 0x51];
            let i = rng.below(bytes.len());
            bytes[i] = INTERESTING[rng.below(INTERESTING.len())];
            "interesting-byte"
        }
        _ => {
            let i = rng.below(bytes.len());
            let j = rng.below(bytes.len());
            bytes.swap(i, j);
            "swap-bytes"
        }
    }
}

/// The head of an error message, for histograms.
pub fn bucket(err: &str) -> String {
    let cut = err.find(['(', '{', '\n']).unwrap_or(err.len().min(48));
    err[..cut].trim().to_string()
}

// ---------------------------------------------------------------------------
// this repo's: the generated families as records
// ---------------------------------------------------------------------------

/// What the reference model expects of a case, before any engine runs.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RefExpect {
    /// The model says the spend is valid (the arithmetic identity holds, the
    /// round trip closes, the size/depth matches).
    Valid,
    /// The model says the spend is invalid (the reject twin: wrong result).
    Invalid,
    /// The model says the engine must stop with an error (division by zero,
    /// an impossible NUM2BIN width).
    Error,
    /// The model says nothing (mutations, the version-1 twins).
    None,
}

impl RefExpect {
    pub fn as_str(&self) -> Option<&'static str> {
        match self {
            RefExpect::Valid => Some("valid"),
            RefExpect::Invalid => Some("invalid"),
            RefExpect::Error => Some("invalid"),
            RefExpect::None => None,
        }
    }
}

/// One generated case: a lock, an unlock, and what it exercises.
#[derive(Clone, Debug)]
pub struct GenCase {
    pub family: String,
    pub rule: &'static str,
    pub lock: Vec<u8>,
    pub unlock: Vec<u8>,
    pub reference: RefExpect,
    pub note: String,
}

/// Arithmetic against the reference model: the accept case, its reject twin
/// (expected + 1), and, for a zero divisor, the must-error case.
pub fn gen_arith(rng: &mut Rng) -> Vec<GenCase> {
    let spec = &ARITH_OPS[rng.below(ARITH_OPS.len())];
    let a = pick_operand(rng);
    let b = if spec.binary { pick_operand(rng) } else { 0 };
    let expect = if spec.binary {
        reference_eval(spec.op, a, b)
    } else {
        reference_eval(spec.op, a, 0)
    };
    let mut unlock = Vec::new();
    push_min(&mut unlock, &enc_num(a));
    if spec.binary {
        push_min(&mut unlock, &enc_num(b));
    }
    let args = if spec.binary {
        format!("({a}, {b})")
    } else {
        format!("({a})")
    };
    let rule: &'static str = match spec.name {
        "ADD" => "num.arith.add",
        "SUB" => "num.arith.sub",
        "MUL" => "num.arith.mul",
        "DIV" => "num.arith.div",
        "MOD" => "num.arith.mod",
        "MIN" => "num.arith.min",
        "MAX" => "num.arith.max",
        "LESSTHAN" => "num.cmp.lessthan",
        "GREATERTHAN" => "num.cmp.greaterthan",
        "NUMEQUAL" => "num.cmp.numequal",
        "NUMNOTEQUAL" => "num.cmp.numnotequal",
        "1ADD" => "num.arith.1add",
        "1SUB" => "num.arith.1sub",
        "NEGATE" => "num.arith.negate",
        "ABS" => "num.arith.abs",
        _ => unreachable!(),
    };
    match expect {
        Some(e) => {
            let mut lock = vec![spec.op];
            push_min(&mut lock, &enc_num(e));
            lock.push(OP_EQUAL);
            let mut twin = vec![spec.op];
            push_min(&mut twin, &enc_num(e + 1));
            twin.push(OP_EQUAL);
            vec![
                GenCase {
                    family: format!("arith/{}", spec.name),
                    rule,
                    lock,
                    unlock: unlock.clone(),
                    reference: RefExpect::Valid,
                    note: format!("{}{} = {}", spec.name, args, e),
                },
                GenCase {
                    family: format!("arith/{}/twin", spec.name),
                    rule,
                    lock: twin,
                    unlock,
                    reference: RefExpect::Invalid,
                    note: format!("{}{} = {} (the twin asserts {})", spec.name, args, e, e + 1),
                },
            ]
        }
        None => {
            let lock = vec![spec.op, OP_DROP, OP_1];
            let rule0: &'static str = if spec.op == OP_DIV {
                "num.arith.div0"
            } else {
                "num.arith.mod0"
            };
            vec![GenCase {
                family: format!("arith/{}/by0", spec.name),
                rule: rule0,
                lock,
                unlock,
                reference: RefExpect::Error,
                note: format!("{}{} must error (division by zero)", spec.name, args),
            }]
        }
    }
}

/// A non-minimal number encoding (a 0x00 pad, or the sign moved to an appended
/// 0x80 byte) fed to OP_1ADD: relaxed mode must accept, MINIMALDATA must reject.
pub fn gen_nonmin(rng: &mut Rng) -> Vec<GenCase> {
    let a = pick_operand(rng);
    let mut padded = enc_num(a);
    if a >= 0 {
        padded.push(0x00);
    } else {
        let last = padded.len() - 1;
        padded[last] &= 0x7f;
        padded.push(0x80);
    }
    let mut unlock = Vec::new();
    push_min(&mut unlock, &padded);
    let mut lock = vec![OP_1ADD];
    push_min(&mut lock, &enc_num(a + 1));
    lock.push(OP_EQUAL);
    vec![GenCase {
        family: "num/nonminimal".into(),
        rule: "num.encoding.nonminimal",
        lock,
        unlock,
        reference: RefExpect::None,
        note: format!(
            "1ADD of a non-minimal encoding of {a} (padded to {} bytes)",
            padded.len()
        ),
    }]
}

/// Element-size boundaries (0/1/2/75/76/255/256/519/520/521/4096/65535 bytes):
/// post-Genesis there is no 520-byte element limit, only the stack memory limit.
pub fn gen_size(rng: &mut Rng) -> Vec<GenCase> {
    const SIZES: &[usize] = &[0, 1, 2, 75, 76, 255, 256, 519, 520, 521, 4096, 65_535];
    let len = SIZES[rng.below(SIZES.len())];
    let blob = vec![0xAB_u8; len];
    let mut unlock = Vec::new();
    let nonmin = rng.below(2) == 1 && len != 0;
    if nonmin {
        push_nonmin(&mut unlock, &blob[..len.min(255)]);
    } else {
        push_min(&mut unlock, &blob);
    }
    let actual_len = if nonmin { len.min(255) } else { len };
    let mut lock = vec![OP_SIZE];
    push_min(&mut lock, &enc_num(actual_len as i128));
    lock.push(OP_EQUALVERIFY);
    lock.push(OP_DROP);
    lock.push(OP_1);
    vec![GenCase {
        family: "elem/size".into(),
        rule: "elem.size",
        lock,
        unlock,
        reference: RefExpect::Valid,
        note: format!(
            "an element of {actual_len} bytes{}",
            if nonmin {
                " pushed non-minimally (PUSHDATA1)"
            } else {
                ""
            }
        ),
    }]
}

/// Stack-depth extremes (1/10/100/1,000/5,000 elements): post-Genesis there is
/// no 1,000-element stack limit; version 1's CLEANSTACK rejects any depth > 1.
pub fn gen_depth(rng: &mut Rng) -> Vec<GenCase> {
    const DEPTHS: &[usize] = &[1, 10, 100, 1_000, 5_000];
    let d = DEPTHS[rng.below(DEPTHS.len())];
    let unlock = vec![OP_1; d];
    let mut lock = vec![OP_DEPTH];
    push_min(&mut lock, &enc_num(d as i128));
    lock.push(OP_NUMEQUAL);
    vec![GenCase {
        family: "stack/depth".into(),
        rule: "stack.depth",
        lock,
        unlock,
        reference: RefExpect::Valid,
        note: format!("{d} elements on the stack at the end of the unlocking script"),
    }]
}

/// NUM2BIN to a fixed width then BIN2NUM must round-trip when the width holds
/// the minimal encoding, and must error when it does not.
pub fn gen_num2bin(rng: &mut Rng) -> Vec<GenCase> {
    let a = pick_operand(rng);
    let min_len = enc_num(a).len();
    const WIDTHS: &[usize] = &[1, 2, 4, 5, 8, 9, 16];
    let w = WIDTHS[rng.below(WIDTHS.len())];
    let mut unlock = Vec::new();
    push_min(&mut unlock, &enc_num(a));
    let mut lock = Vec::new();
    push_min(&mut lock, &enc_num(w as i128));
    lock.push(OP_NUM2BIN);
    lock.push(OP_BIN2NUM);
    push_min(&mut lock, &enc_num(a));
    lock.push(OP_NUMEQUAL);
    let fits = w >= min_len.max(1);
    vec![GenCase {
        family: if fits {
            "splice/num2bin/fits".into()
        } else {
            "splice/num2bin/toonarrow".into()
        },
        rule: "splice.num2bin.width",
        lock,
        unlock,
        reference: if fits {
            RefExpect::Valid
        } else {
            RefExpect::Error
        },
        note: format!("NUM2BIN({a}, {w}) then BIN2NUM; the minimal encoding is {min_len} bytes"),
    }]
}

/// A mutation of a previously generated case: 1–4 byte-level operators on the
/// lock (30 %) or the unlock (70 %). The reference model says nothing; the
/// implementations' verdicts are the record.
pub fn gen_mutation(rng: &mut Rng, base: &GenCase) -> GenCase {
    let mut lock = base.lock.clone();
    let mut unlock = base.unlock.clone();
    let target_lock = rng.below(10) < 3;
    let n_muts = 1 + rng.below(4);
    let mut names = Vec::new();
    for _ in 0..n_muts {
        names.push(if target_lock {
            mutate(&mut lock, rng)
        } else {
            mutate(&mut unlock, rng)
        });
    }
    GenCase {
        family: format!("mutation/{}", if target_lock { "lock" } else { "unlock" }),
        rule: "mutation",
        lock,
        unlock,
        reference: RefExpect::None,
        note: format!(
            "{} of {} ({}): {}",
            if target_lock { "lock" } else { "unlock" },
            base.family,
            base.note,
            names.join(", ")
        ),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The reference encoder against known consensus vectors (the predecessor's
    /// sanity block, kept verbatim).
    #[test]
    fn enc_num_vectors() {
        assert_eq!(enc_num(0), Vec::<u8>::new());
        assert_eq!(enc_num(1), vec![0x01]);
        assert_eq!(enc_num(-1), vec![0x81]);
        assert_eq!(enc_num(127), vec![0x7f]);
        assert_eq!(enc_num(128), vec![0x80, 0x00]);
        assert_eq!(enc_num(-128), vec![0x80, 0x80]);
        assert_eq!(enc_num(255), vec![0xff, 0x00]);
        assert_eq!(enc_num(256), vec![0x00, 0x01]);
        assert_eq!(enc_num(-255), vec![0xff, 0x80]);
    }

    #[test]
    fn rng_is_reproducible() {
        let mut a = Rng(1);
        let mut b = Rng(1);
        for _ in 0..1000 {
            assert_eq!(a.next(), b.next());
        }
    }
}
