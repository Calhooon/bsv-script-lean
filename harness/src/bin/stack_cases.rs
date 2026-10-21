//! stack_cases (#10): the hand-written stack and splice corpus, emitted in the
//! corpus format with the pinned bsv-rs's verdict (0.4.4 since 2026-10-12, 0.3.33 from 2026-10-07, bsv-rs#41 (0.3.30 from 2026-09-27, 0.3.28 from 2026-09-24, 0.3.27 on 2026-09-23), under the node's standard word), for `lean/Test/StackCheck.lean`
//! (`make stackcheck`). Every stack opcode on a small stack with the exact
//! expected stack verified in the lock (`<t0> OP_EQUALVERIFY … OP_DEPTH OP_0
//! OP_EQUAL`, top first, so a wrong element or a wrong depth fails under both
//! versions), the alt stack, `OP_PICK`/`OP_ROLL` at every index and outside,
//! `OP_DEPTH`/`OP_SIZE` values, `OP_CAT`, `OP_SPLIT` at positions 0, 1, 5, 9 and 10 of a
//! 10-byte element, at 0 of the empty element, and outside (11, -1, 1,000), `OP_NUM2BIN` over a value × width table (the sign-bit boundaries,
//! the impossible encodings, a negative and an oversized width, a wide pad),
//! `OP_BIN2NUM` over a table, the underflows; each with its version-1 twin
//! (`MINIMALDATA` bites on a non-minimal index or width under version 1).
//! Families `stack/…`, `splice/…` are COMPARABLE with bsv-rs; the code emits no
//! `stack-candidate/…` family (relabelled 2026-09-28, #26): `splice/num2bin/memory`
//! takes `OP_NUM2BIN` to 40,000,000 bytes, above bsv-rs's old LOCAL budget of
//! 32,000,000 bytes (a budget of the crate, not a policy default) and within the
//! reference's: its consensus budget is the operator's mandatory
//! `-maxstackmemoryusageconsensus` (0 resolving to INT64_MAX, as the spec's
//! instances set it), its policy default 100,000,000 (`docs/PARAMETERS.md` §1).
//!
//! Run: cargo run --release --bin stack_cases -- [--out DIR]

use bsv_script_harness::cases::{arg, c, num, pm, Case, Corpus, Quiet, Text};
use bsv_script_harness::engine::EngineConfig;
use bsv_script_harness::gen::{OP_0, OP_1, OP_DEPTH, OP_DROP, OP_EQUAL, OP_EQUALVERIFY, OP_SIZE};

const OP_TOALTSTACK: u8 = 0x6b;
const OP_FROMALTSTACK: u8 = 0x6c;
const OP_2DROP: u8 = 0x6d;
const OP_2DUP: u8 = 0x6e;
const OP_3DUP: u8 = 0x6f;
const OP_2OVER: u8 = 0x70;
const OP_2ROT: u8 = 0x71;
const OP_2SWAP: u8 = 0x72;
const OP_IFDUP: u8 = 0x73;
const OP_DUP: u8 = 0x76;
const OP_NIP: u8 = 0x77;
const OP_OVER: u8 = 0x78;
const OP_PICK: u8 = 0x79;
const OP_ROLL: u8 = 0x7a;
const OP_ROT: u8 = 0x7b;
const OP_SWAP: u8 = 0x7c;
const OP_TUCK: u8 = 0x7d;
const OP_CAT: u8 = 0x7e;
const OP_SPLIT: u8 = 0x7f;
const OP_NUM2BIN: u8 = 0x80;
const OP_BIN2NUM: u8 = 0x81;

/// The unlock that pushes `elems` bottom first.
fn pushes(elems: &[Vec<u8>]) -> Vec<u8> {
    let mut u = Vec::new();
    for e in elems {
        u.extend(pm(e));
    }
    u
}

/// The lock tail that verifies the stack is exactly `top_first` (top first) and nothing else.
fn expect_stack(top_first: &[Vec<u8>]) -> Vec<u8> {
    let mut l = Vec::new();
    for e in top_first {
        l.extend(pm(e));
        l.push(OP_EQUALVERIFY);
    }
    l.extend([OP_DEPTH, OP_0, OP_EQUAL]);
    l
}

fn el(n: u8) -> Vec<u8> {
    vec![n]
}

/// A positive stack case: the unlock pushes `stack` (bottom first), the lock is `ops` then the expected stack (top first).
fn pos(
    v: &mut Vec<Case>,
    family: &str,
    rule: &'static str,
    stack: &[Vec<u8>],
    ops: &[u8],
    expect_top_first: &[Vec<u8>],
    note: &str,
) {
    let mut lock = ops.to_vec();
    lock.extend(expect_stack(expect_top_first));
    v.push(c(family, rule, lock, pushes(stack), note, true));
}

fn cases() -> Vec<Case> {
    let mut v = Vec::new();
    let (a, b, cc, d, e, f) = (el(0x0a), el(0x0b), el(0x0c), el(0x0d), el(0x0e), el(0x0f));
    // alt stack
    pos(
        &mut v,
        "stack/alt",
        "stack.alt",
        &[a.clone(), b.clone(), cc.clone()],
        &[OP_TOALTSTACK, OP_TOALTSTACK, OP_FROMALTSTACK],
        &[b.clone(), a.clone()],
        "TOALTSTACK twice then FROMALTSTACK: c stays on the alt stack, b returns",
    );
    pos(
        &mut v,
        "stack/alt",
        "stack.alt",
        &[a.clone(), b.clone()],
        &[OP_TOALTSTACK, OP_FROMALTSTACK],
        &[b.clone(), a.clone()],
        "round trip",
    );
    // 2DROP 2DUP 3DUP 2OVER 2ROT 2SWAP
    pos(
        &mut v,
        "stack/2drop",
        "stack.ops",
        &[a.clone(), b.clone(), cc.clone()],
        &[OP_2DROP],
        std::slice::from_ref(&a),
        "2DROP",
    );
    pos(
        &mut v,
        "stack/2dup",
        "stack.ops",
        &[a.clone(), b.clone()],
        &[OP_2DUP],
        &[b.clone(), a.clone(), b.clone(), a.clone()],
        "2DUP",
    );
    pos(
        &mut v,
        "stack/3dup",
        "stack.ops",
        &[a.clone(), b.clone(), cc.clone()],
        &[OP_3DUP],
        &[
            cc.clone(),
            b.clone(),
            a.clone(),
            cc.clone(),
            b.clone(),
            a.clone(),
        ],
        "3DUP",
    );
    pos(
        &mut v,
        "stack/2over",
        "stack.ops",
        &[a.clone(), b.clone(), cc.clone(), d.clone()],
        &[OP_2OVER],
        &[
            b.clone(),
            a.clone(),
            d.clone(),
            cc.clone(),
            b.clone(),
            a.clone(),
        ],
        "2OVER",
    );
    pos(
        &mut v,
        "stack/2rot",
        "stack.ops",
        &[
            a.clone(),
            b.clone(),
            cc.clone(),
            d.clone(),
            e.clone(),
            f.clone(),
        ],
        &[OP_2ROT],
        &[
            b.clone(),
            a.clone(),
            f.clone(),
            e.clone(),
            d.clone(),
            cc.clone(),
        ],
        "2ROT: x1 x2 x3 x4 x5 x6 -> x3 x4 x5 x6 x1 x2",
    );
    pos(
        &mut v,
        "stack/2swap",
        "stack.ops",
        &[a.clone(), b.clone(), cc.clone(), d.clone()],
        &[OP_2SWAP],
        &[b.clone(), a.clone(), d.clone(), cc.clone()],
        "2SWAP",
    );
    pos(
        &mut v,
        "stack/ifdup",
        "stack.ops",
        &[a.clone(), b.clone()],
        &[OP_IFDUP],
        &[b.clone(), b.clone(), a.clone()],
        "IFDUP on true",
    );
    pos(
        &mut v,
        "stack/ifdup",
        "stack.ops",
        &[a.clone(), vec![]],
        &[OP_IFDUP],
        &[vec![], a.clone()],
        "IFDUP on false (empty)",
    );
    pos(
        &mut v,
        "stack/ifdup",
        "stack.ops",
        &[a.clone(), vec![0x80]],
        &[OP_IFDUP],
        &[vec![0x80], a.clone()],
        "IFDUP on negative zero (false)",
    );
    // DEPTH
    pos(
        &mut v,
        "stack/depth",
        "stack.depth",
        &[],
        &[OP_DEPTH],
        &[vec![]],
        "DEPTH 0",
    );
    pos(
        &mut v,
        "stack/depth",
        "stack.depth",
        &[a.clone(), b.clone(), cc.clone()],
        &[OP_DEPTH],
        &[num(3), cc.clone(), b.clone(), a.clone()],
        "DEPTH 3",
    );
    let many: Vec<Vec<u8>> = (0..300).map(|_| a.clone()).collect();
    let mut exp = vec![num(300)];
    exp.extend(many.iter().cloned());
    pos(
        &mut v,
        "stack/depth",
        "stack.depth",
        &many,
        &[OP_DEPTH],
        &exp,
        "DEPTH 300 (a two-byte number)",
    );
    // DROP DUP NIP OVER ROT SWAP TUCK
    pos(
        &mut v,
        "stack/drop",
        "stack.ops",
        &[a.clone(), b.clone()],
        &[OP_DROP],
        std::slice::from_ref(&a),
        "DROP",
    );
    pos(
        &mut v,
        "stack/dup",
        "stack.ops",
        &[a.clone(), b.clone()],
        &[OP_DUP],
        &[b.clone(), b.clone(), a.clone()],
        "DUP",
    );
    pos(
        &mut v,
        "stack/nip",
        "stack.ops",
        &[a.clone(), b.clone(), cc.clone()],
        &[OP_NIP],
        &[cc.clone(), a.clone()],
        "NIP",
    );
    pos(
        &mut v,
        "stack/over",
        "stack.ops",
        &[a.clone(), b.clone()],
        &[OP_OVER],
        &[a.clone(), b.clone(), a.clone()],
        "OVER",
    );
    pos(
        &mut v,
        "stack/rot",
        "stack.ops",
        &[a.clone(), b.clone(), cc.clone()],
        &[OP_ROT],
        &[a.clone(), cc.clone(), b.clone()],
        "ROT: x1 x2 x3 -> x2 x3 x1",
    );
    pos(
        &mut v,
        "stack/swap",
        "stack.ops",
        &[a.clone(), b.clone(), cc.clone()],
        &[OP_SWAP],
        &[b.clone(), cc.clone(), a.clone()],
        "SWAP",
    );
    pos(
        &mut v,
        "stack/tuck",
        "stack.ops",
        &[a.clone(), b.clone(), cc.clone()],
        &[OP_TUCK],
        &[cc.clone(), b.clone(), cc.clone(), a.clone()],
        "TUCK: x1 x2 -> x2 x1 x2",
    );
    // PICK / ROLL at every index of a 4-deep stack
    let four = [a.clone(), b.clone(), cc.clone(), d.clone()];
    for n in 0..4u8 {
        let picked = four[3 - n as usize].clone();
        let mut exp = vec![picked.clone()];
        exp.extend(four.iter().rev().cloned());
        let mut ops = pm(&num(n as i64));
        ops.push(OP_PICK);
        pos(
            &mut v,
            "stack/pick",
            "stack.pick",
            &four,
            &ops,
            &exp,
            &format!("PICK {n}"),
        );
        let mut rest: Vec<Vec<u8>> = four.iter().rev().cloned().collect();
        rest.remove(n as usize);
        let mut exp = vec![picked];
        exp.extend(rest);
        let mut ops = pm(&num(n as i64));
        ops.push(OP_ROLL);
        pos(
            &mut v,
            "stack/roll",
            "stack.roll",
            &four,
            &ops,
            &exp,
            &format!("ROLL {n}"),
        );
    }
    for (op, name) in [(OP_PICK, "pick"), (OP_ROLL, "roll")] {
        let mut l = pm(&num(4));
        l.push(op);
        l.push(OP_1);
        v.push(c(
            &format!("stack/{name}/range"),
            "stack.pick",
            l,
            pushes(&four),
            &format!("{name} 4 on a 4-deep stack: INVALID_STACK_OPERATION"),
            false,
        ));
        let mut l = pm(&num(-1));
        l.push(op);
        l.push(OP_1);
        v.push(c(
            &format!("stack/{name}/negative"),
            "stack.pick",
            l,
            pushes(&four),
            &format!("{name} -1: INVALID_STACK_OPERATION"),
            false,
        ));
        v.push(c(
            &format!("stack/{name}/underflow"),
            "stack.pick",
            vec![op, OP_1],
            pushes(std::slice::from_ref(&a)),
            &format!("{name} with one element: INVALID_STACK_OPERATION"),
            false,
        ));
        // a non-minimal index: the version gate
        let mut l = pm(&[0x01, 0x00]);
        l.push(op);
        l.extend(expect_stack(&[
            cc.clone(),
            d.clone(),
            cc.clone(),
            b.clone(),
            a.clone(),
        ]));
        if op == OP_ROLL {
            l = pm(&[0x01, 0x00]);
            l.push(op);
            l.extend(expect_stack(&[cc.clone(), d.clone(), b.clone(), a.clone()]));
        }
        v.push(c(&format!("stack/{name}/nonminimal"), "flags.version-gate", l, pushes(&four), &format!("{name} by the non-minimal 0x0100 = 1: valid under version 2, SCRIPTNUM_MINENCODE under version 1"), true));
    }
    // SIZE
    for &w in &[0usize, 1, 127, 128, 255, 256, 300, 600] {
        let x: Vec<u8> = (0..w).map(|i| (i * 7 + 3) as u8).collect();
        pos(
            &mut v,
            "stack/size",
            "elem.size",
            std::slice::from_ref(&x),
            &[OP_SIZE],
            &[num(w as i64), x.clone()],
            &format!("SIZE of {w} bytes"),
        );
    }
    v.push(c(
        "stack/size/underflow",
        "elem.size",
        vec![OP_SIZE],
        vec![],
        "SIZE on the empty stack: INVALID_STACK_OPERATION",
        false,
    ));
    // underflows of the plain ops
    for (op, n, name) in [
        (OP_2DROP, 1, "2drop"),
        (OP_2DUP, 1, "2dup"),
        (OP_3DUP, 2, "3dup"),
        (OP_2OVER, 3, "2over"),
        (OP_2ROT, 5, "2rot"),
        (OP_2SWAP, 3, "2swap"),
        (OP_NIP, 1, "nip"),
        (OP_OVER, 1, "over"),
        (OP_ROT, 2, "rot"),
        (OP_SWAP, 1, "swap"),
        (OP_TUCK, 1, "tuck"),
        (OP_DROP, 0, "drop"),
        (OP_DUP, 0, "dup"),
        (OP_IFDUP, 0, "ifdup"),
        (OP_TOALTSTACK, 0, "toaltstack"),
    ] {
        let stack: Vec<Vec<u8>> = (0..n).map(|_| a.clone()).collect();
        v.push(c(
            &format!("stack/{name}/underflow"),
            "stack.ops",
            vec![op, OP_1],
            pushes(&stack),
            &format!("{name} with {n} element(s): INVALID_STACK_OPERATION"),
            false,
        ));
    }
    v.push(c(
        "stack/fromaltstack/underflow",
        "stack.alt",
        vec![OP_FROMALTSTACK, OP_1],
        pushes(std::slice::from_ref(&a)),
        "FROMALTSTACK with an empty alt stack: INVALID_ALTSTACK_OPERATION",
        false,
    ));
    // CAT
    for &(w1, w2) in &[
        (0usize, 0usize),
        (0, 1),
        (1, 0),
        (1, 1),
        (300, 300),
        (520, 1),
        (1000, 1000),
    ] {
        let x: Vec<u8> = (0..w1).map(|i| (i * 3 + 1) as u8).collect();
        let y: Vec<u8> = (0..w2).map(|i| (i * 5 + 2) as u8).collect();
        let mut xy = x.clone();
        xy.extend(y.iter());
        pos(
            &mut v,
            "splice/cat",
            "splice.cat",
            &[x.clone(), y.clone()],
            &[OP_CAT],
            &[xy],
            &format!("CAT {w1} + {w2} bytes"),
        );
    }
    v.push(c(
        "splice/cat/underflow",
        "splice.cat",
        vec![OP_CAT, OP_1],
        pushes(std::slice::from_ref(&a)),
        "CAT with one element: INVALID_STACK_OPERATION",
        false,
    ));
    // SPLIT
    let data: Vec<u8> = (0..10).map(|i| i as u8 + 0x20).collect();
    for p in [0i64, 1, 5, 9, 10] {
        let mut ops = pm(&num(p));
        ops.push(OP_SPLIT);
        pos(
            &mut v,
            "splice/split",
            "splice.split",
            std::slice::from_ref(&data),
            &ops,
            &[data[p as usize..].to_vec(), data[..p as usize].to_vec()],
            &format!("SPLIT at {p} of 10"),
        );
    }
    pos(
        &mut v,
        "splice/split",
        "splice.split",
        &[vec![]],
        &[OP_0, OP_SPLIT],
        &[vec![], vec![]],
        "SPLIT the empty element at 0",
    );
    for p in [11i64, -1, 1000] {
        let mut l = pm(&num(p));
        l.push(OP_SPLIT);
        l.push(OP_1);
        v.push(c(
            "splice/split/range",
            "splice.split",
            l,
            pushes(std::slice::from_ref(&data)),
            &format!("SPLIT at {p} of 10: INVALID_SPLIT_RANGE"),
            false,
        ));
    }
    let mut l = pm(&[0x05, 0x00]);
    l.push(OP_SPLIT);
    l.extend(expect_stack(&[data[5..].to_vec(), data[..5].to_vec()]));
    v.push(c("splice/split/nonminimal", "flags.version-gate", l, pushes(std::slice::from_ref(&data)), "SPLIT at the non-minimal 0x0500 = 5: valid under version 2, SCRIPTNUM_MINENCODE under version 1", true));
    v.push(c(
        "splice/split/underflow",
        "splice.split",
        vec![OP_SPLIT, OP_1],
        pushes(std::slice::from_ref(&a)),
        "SPLIT with one element: INVALID_STACK_OPERATION",
        false,
    ));
    // NUM2BIN: value × width
    let table: Vec<(Vec<u8>, i64, Option<Vec<u8>>)> = vec![
        (vec![], 0, Some(vec![])),
        (vec![], 1, Some(vec![0])),
        (vec![], 4, Some(vec![0, 0, 0, 0])),
        (vec![0x01], 1, Some(vec![0x01])),
        (vec![0x01], 2, Some(vec![0x01, 0x00])),
        (vec![0x01], 8, Some(vec![1, 0, 0, 0, 0, 0, 0, 0])),
        (vec![0x7f], 1, Some(vec![0x7f])),
        (vec![0x80, 0x00], 1, None),
        (vec![0x80, 0x00], 2, Some(vec![0x80, 0x00])),
        (vec![0x80, 0x00], 3, Some(vec![0x80, 0x00, 0x00])),
        (vec![0x81], 1, Some(vec![0x81])),
        (vec![0x81], 2, Some(vec![0x01, 0x80])),
        (vec![0x81], 3, Some(vec![0x01, 0x00, 0x80])),
        (vec![0x80, 0x80], 2, Some(vec![0x80, 0x80])),
        (vec![0x80, 0x80], 3, Some(vec![0x80, 0x00, 0x80])),
        (vec![0x80, 0x80], 1, None),
        (vec![0xff, 0xff, 0xff, 0xff, 0x00], 4, None),
        (
            vec![0xff, 0xff, 0xff, 0xff, 0x00],
            5,
            Some(vec![0xff, 0xff, 0xff, 0xff, 0x00]),
        ),
        (
            vec![0xff, 0xff, 0xff, 0xff, 0x00],
            6,
            Some(vec![0xff, 0xff, 0xff, 0xff, 0x00, 0x00]),
        ),
        (vec![0x01, 0x00], 1, Some(vec![0x01])),
        (vec![0x01, 0x00, 0x00], 2, Some(vec![0x01, 0x00])),
        (vec![0x80], 0, Some(vec![])),
        (vec![0x80], 2, Some(vec![0x00, 0x00])),
        (vec![0x00, 0x80], 1, Some(vec![0x00])),
        (vec![0x02], 0, None),
        (vec![0x01, 0x02], 1, None),
    ];
    for (val, width, out) in table {
        let mut ops = pm(&num(width));
        ops.push(OP_NUM2BIN);
        match out {
            Some(o) => pos(
                &mut v,
                "splice/num2bin",
                "splice.num2bin.width",
                std::slice::from_ref(&val),
                &ops,
                &[o],
                &format!("NUM2BIN {} to {width}", hex::encode(&val)),
            ),
            None => {
                ops.push(OP_1);
                v.push(c(
                    "splice/num2bin/impossible",
                    "splice.num2bin.width",
                    ops,
                    pushes(std::slice::from_ref(&val)),
                    &format!(
                        "NUM2BIN {} to {width}: IMPOSSIBLE_ENCODING",
                        hex::encode(&val)
                    ),
                    false,
                ));
            }
        }
    }
    for width in [-1i64, 2147483648, -2147483648] {
        let mut l = pm(&num(width));
        l.push(OP_NUM2BIN);
        l.push(OP_1);
        v.push(c(
            "splice/num2bin/width-range",
            "splice.num2bin.width",
            l,
            pushes(&[el(1)]),
            &format!("NUM2BIN to width {width}: PUSH_SIZE"),
            false,
        ));
    }
    // NUM2BIN 1 to 100,000 bytes: the size and the value checked (the element itself is too wide for a minimal push in the lock)
    let mut l = pm(&num(100_000));
    l.push(OP_NUM2BIN);
    l.push(OP_SIZE);
    l.extend(pm(&num(100_000)));
    l.push(OP_EQUALVERIFY);
    l.push(OP_BIN2NUM);
    l.push(OP_1);
    l.push(OP_EQUAL);
    v.push(c(
        "splice/num2bin/wide",
        "splice.num2bin.width",
        l,
        pushes(&[el(1)]),
        "NUM2BIN 1 to 100,000 bytes: SIZE = 100,000 and BIN2NUM = 1",
        true,
    ));
    let mut l = pm(&[0x02, 0x00]);
    l.push(OP_NUM2BIN);
    l.extend(expect_stack(&[vec![0x01, 0x00]]));
    v.push(c("splice/num2bin/nonminimal-width", "flags.version-gate", l, pushes(&[el(1)]), "NUM2BIN to the non-minimal width 0x0200 = 2: valid under version 2, SCRIPTNUM_MINENCODE under version 1", true));
    v.push(c(
        "splice/num2bin/underflow",
        "splice.num2bin.width",
        vec![OP_NUM2BIN, OP_1],
        pushes(&[el(1)]),
        "NUM2BIN with one element: INVALID_STACK_OPERATION",
        false,
    ));
    // `splice.num2bin.memory` (#26, relabelled 2026-09-28 from `stack-candidate/num2bin-memory` and `splice.num2bin.width`):
    // a width within the reference's budgets (consensus: the operator's mandatory -maxstackmemoryusageconsensus, bitcoind.cpp:140–157,
    // 0 resolving to INT64_MAX, configscriptpolicy.cpp:280–283 and consensus.h:82; policy 100,000,000, policy.h:153) and
    // above bsv-rs's old local one (32,000,000, which aborted it through 0.3.29; bsv-rs#30); `false`: no model check here
    let mut l = pm(&num(40_000_000));
    l.push(OP_NUM2BIN);
    l.push(OP_SIZE);
    l.extend(pm(&num(40_000_000)));
    l.push(OP_EQUAL);
    l.push(OP_NIP);
    v.push(c("splice/num2bin/memory", "splice.num2bin.memory", l, pushes(&[el(1)]), "NUM2BIN 1 to 40,000,000 bytes: within the reference's consensus memory budget (the operator's mandatory -maxstackmemoryusageconsensus, 0 resolving to INT64_MAX as the spec's instances set it) and its policy default (100,000,000), valid on both paths; bsv-rs's local 32,000,000-byte budget aborted it through 0.3.29 (bsv-rs#30)", false));
    // BIN2NUM
    let table2: Vec<(Vec<u8>, Vec<u8>)> = vec![
        (vec![], vec![]),
        (vec![0x00], vec![]),
        (vec![0x80], vec![]),
        (vec![0x00, 0x80], vec![]),
        (vec![0x00, 0x00, 0x00], vec![]),
        (vec![0x01], vec![0x01]),
        (vec![0x01, 0x00], vec![0x01]),
        (vec![0x01, 0x00, 0x00, 0x00], vec![0x01]),
        (vec![0x01, 0x80], vec![0x81]),
        (vec![0x01, 0x00, 0x80], vec![0x81]),
        (vec![0x80, 0x00], vec![0x80, 0x00]),
        (vec![0x80, 0x00, 0x00], vec![0x80, 0x00]),
        (vec![0x80, 0x80], vec![0x80, 0x80]),
        (vec![0x80, 0x00, 0x80], vec![0x80, 0x80]),
        (vec![0xff, 0x7f], vec![0xff, 0x7f]),
        (
            vec![0xff, 0xff, 0xff, 0xff, 0x00],
            vec![0xff, 0xff, 0xff, 0xff, 0x00],
        ),
    ];
    for (input, out) in table2 {
        pos(
            &mut v,
            "splice/bin2num",
            "splice.bin2num",
            std::slice::from_ref(&input),
            &[OP_BIN2NUM],
            &[out],
            &format!("BIN2NUM {}", hex::encode(&input)),
        );
    }
    v.push(c(
        "splice/bin2num/underflow",
        "splice.bin2num",
        vec![OP_BIN2NUM],
        vec![],
        "BIN2NUM on the empty stack: INVALID_STACK_OPERATION",
        false,
    ));
    v
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let out_dir = arg(&args, "--out").unwrap_or_else(|| "../corpus/stack".into());
    let mut quiet = Quiet::new();
    let mut corpus = Corpus::new(EngineConfig::default());
    corpus.twins(&mut quiet, "stack", cases());
    quiet.restore();
    let comparable = corpus.comparable();
    let (path, sha, _) = corpus.write(&out_dir, Text {
        corpus: "stack-cases",
        file: "cases.jsonl",
        manifest: "cases-manifest.json",
        generator: "bsv-script-harness stack_cases 0.0.1 (a hand-written table; #10)".into(),
        seed: "none (hand-written)".into(),
        generated: "2026-09-23".into(),
        provenance: format!("stack and splice cases with bsv-rs {}'s verdicts under the node's standard word; {comparable} comparable (stack/, splice/), the rest stack-candidate/ (recorded, #15's witnesses); synthetic outpoints = sha256 of the entry id", bsv_script_harness::BSV_RS_VERSION),
    });
    corpus.report("stack_cases", comparable, &path, &sha);
}
