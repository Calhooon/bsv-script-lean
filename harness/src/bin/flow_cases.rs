//! flow_cases (this repo's; #8): the hand-written flow corpus. Every case is a
//! (lock, unlock) pair written by hand in the table below (with a few families
//! enumerated over sizes), emitted in the corpus format with the pinned bsv-rs's (0.4.4 since 2026-10-12, 0.3.33 from 2026-10-07, bsv-rs#41; 0.3.30 from 2026-09-27, 0.3.28 from 2026-09-24; 0.3.24 at birth)
//! verdict, for `lean/Test/FlowCheck.lean` (`make flowcheck`). Only pushes and
//! the flow opcodes appear, so the machine of #8 can decide every case.
//!
//! Families: `flow/…`, `push/…`, `stack/…`, `flags/…` are COMPARABLE with bsv-rs
//! under the node's standard word (`docs/DESIGN.md` §5.2; `EngineConfig::default`,
//! the test states it). Until bsv-rs 0.3.27 (the pin of 2026-09-23; 0.3.28 from 2026-09-24, 0.3.30 from 2026-09-27, 0.4.4 since 2026-10-12, 0.3.33 from 2026-10-07) the families
//! `flow-candidate/…` (a truncated push, an undefined opcode, a second `OP_ELSE`,
//! `OP_RETURN` in a conditional, the Chronicle version opcodes, a non-push
//! unlocking script at version 2) and `flow-policy/…` (the upgradable NOPs under
//! the policy flag bsv-rs did not model) were recorded, never counted: #15's
//! witnesses, each fixed upstream (bsv-rs#10, #12) and comparable since.
//!
//! Run: cargo run --release --bin flow_cases -- [--out DIR]

use bsv_script_harness::cases::{self, arg, Case, Corpus, Quiet, Text};
use bsv_script_harness::engine::EngineConfig;
use bsv_script_harness::gen::{
    push_min, push_nonmin, OP_0, OP_1, OP_1NEGATE, OP_PUSHDATA1, OP_PUSHDATA2,
};

const OP_PUSHDATA4: u8 = 0x4e;
const OP_RESERVED: u8 = 0x50;
const OP_16: u8 = 0x60;
const OP_NOP: u8 = 0x61;
const OP_VER: u8 = 0x62;
const OP_IF: u8 = 0x63;
const OP_NOTIF: u8 = 0x64;
const OP_VERIF: u8 = 0x65;
const OP_VERNOTIF: u8 = 0x66;
const OP_ELSE: u8 = 0x67;
const OP_ENDIF: u8 = 0x68;
const OP_VERIFY: u8 = 0x69;
const OP_RETURN: u8 = 0x6a;
const OP_NOP1: u8 = 0xb0;
const OP_NOP4: u8 = 0xb3;
const OP_NOP9: u8 = 0xb8;
const OP_NOP10: u8 = 0xb9;
const OP_TOALTSTACK: u8 = 0x6b;

/// A flow case: no positive check (the generator records bsv-rs's verdict on every one).
fn c(family: &str, rule: &'static str, lock: Vec<u8>, unlock: Vec<u8>, note: &str) -> Case {
    cases::c(family, rule, lock, unlock, note, false)
}

/// `OP_IF OP_1 OP_ELSE OP_1 OP_ENDIF`: consumes the top element whatever its
/// truthiness and leaves a single true element (the only way to drop an
/// element with flow opcodes alone).
fn consume() -> Vec<u8> {
    vec![OP_IF, OP_1, OP_ELSE, OP_1, OP_ENDIF]
}

fn pushdata4(out: &mut Vec<u8>, data: &[u8]) {
    out.push(OP_PUSHDATA4);
    out.extend_from_slice(&(data.len() as u32).to_le_bytes());
    out.extend_from_slice(data);
}

fn pushdata2(out: &mut Vec<u8>, data: &[u8]) {
    out.push(OP_PUSHDATA2);
    out.extend_from_slice(&(data.len() as u16).to_le_bytes());
    out.extend_from_slice(data);
}

fn direct(out: &mut Vec<u8>, data: &[u8]) {
    out.push(data.len() as u8);
    out.extend_from_slice(data);
}

fn cases() -> Vec<Case> {
    let mut v = Vec::new();

    // ---- pushes: every direct size 0..80, minimal and non-minimal forms ----
    for len in 0..=80usize {
        let data: Vec<u8> = (0..len).map(|i| (0x20 + i as u8) | 1).collect(); // never a small integer, never 0x81
        let mut u = Vec::new();
        push_min(&mut u, &data);
        v.push(c(
            "push/minimal",
            "push.minimal",
            consume(),
            u,
            &format!("minimal push of {len} bytes"),
        ));
        if len <= 75 && len > 0 {
            let mut u1 = Vec::new();
            push_nonmin(&mut u1, &data);
            v.push(c(
                "push/pushdata1-nonminimal",
                "push.minimal",
                consume(),
                u1,
                &format!("PUSHDATA1 for {len} bytes (a direct push would do)"),
            ));
        }
        if len > 0 {
            let mut u2 = Vec::new();
            pushdata2(&mut u2, &data);
            v.push(c(
                "push/pushdata2-nonminimal",
                "push.minimal",
                consume(),
                u2,
                &format!("PUSHDATA2 for {len} bytes"),
            ));
            let mut u4 = Vec::new();
            pushdata4(&mut u4, &data);
            v.push(c(
                "push/pushdata4-nonminimal",
                "push.minimal",
                consume(),
                u4,
                &format!("PUSHDATA4 for {len} bytes"),
            ));
        }
    }
    // the small-integer and negative-one forms
    for b in 1u8..=16 {
        let mut u = Vec::new();
        direct(&mut u, &[b]);
        v.push(c(
            "push/direct-for-small-int",
            "push.minimal",
            consume(),
            u,
            &format!("direct push of [{b}] (OP_{b} would do)"),
        ));
        v.push(c(
            "push/constant",
            "push.constant",
            consume(),
            vec![OP_1 - 1 + b],
            &format!("OP_{b}"),
        ));
    }
    {
        let mut u = Vec::new();
        direct(&mut u, &[0x81]);
        v.push(c(
            "push/direct-for-1negate",
            "push.minimal",
            consume(),
            u,
            "direct push of [0x81] (OP_1NEGATE would do)",
        ));
        v.push(c(
            "push/constant",
            "push.constant",
            consume(),
            vec![OP_1NEGATE],
            "OP_1NEGATE",
        ));
        let mut u0 = Vec::new();
        direct(&mut u0, &[]);
        // `0x00` is OP_0 itself; a direct empty push is OP_0: covered by len 0 above
        v.push(c(
            "push/empty-op0",
            "push.minimal",
            consume(),
            vec![OP_0],
            "OP_0",
        ));
        let _ = u0;
    }
    // PUSHDATA1/2 at their natural sizes (minimal)
    for len in [76usize, 100, 255, 256, 300, 520, 521, 1000, 5000] {
        let data: Vec<u8> = (0..len).map(|i| (i % 251) as u8 + 2).collect();
        let mut u = Vec::new();
        push_min(&mut u, &data);
        v.push(c(
            "push/minimal-large",
            "push.minimal",
            consume(),
            u,
            &format!("minimal push of {len} bytes"),
        ));
        if len <= 255 {
            let mut u2 = Vec::new();
            pushdata2(&mut u2, &data);
            v.push(c(
                "push/pushdata2-nonminimal",
                "push.minimal",
                consume(),
                u2,
                &format!("PUSHDATA2 for {len} bytes"),
            ));
        }
        let mut u4 = Vec::new();
        pushdata4(&mut u4, &data);
        v.push(c(
            "push/pushdata4-nonminimal",
            "push.minimal",
            consume(),
            u4,
            &format!("PUSHDATA4 for {len} bytes"),
        ));
    }

    // ---- truncated pushes (both scripts): the reference fails the parse (`script.h:190–191`,
    // `GetOp` false → SCRIPT_ERR_BAD_OPCODE, `interpreter.cpp:450–451`); bsv-rs 0.3.24's parser is
    // lenient (it takes the bytes that remain), so these are recorded, not counted (#15) ----
    v.push(c(
        "flow/truncated-push",
        "push.truncated",
        vec![OP_1],
        vec![0x02, 0x01],
        "unlock says 2 bytes, has 1",
    ));
    v.push(c(
        "flow/truncated-push",
        "push.truncated",
        vec![OP_1],
        vec![OP_PUSHDATA1],
        "unlock: PUSHDATA1 without a length",
    ));
    v.push(c(
        "flow/truncated-push",
        "push.truncated",
        vec![OP_1],
        vec![OP_PUSHDATA1, 0x05, 0x01],
        "unlock: PUSHDATA1 says 5, has 1",
    ));
    v.push(c(
        "flow/truncated-push",
        "push.truncated",
        vec![OP_1],
        vec![OP_PUSHDATA2, 0x01],
        "unlock: PUSHDATA2 with one length byte",
    ));
    v.push(c(
        "flow/truncated-push",
        "push.truncated",
        vec![OP_1],
        vec![OP_PUSHDATA4, 0x01, 0x00, 0x00],
        "unlock: PUSHDATA4 with three length bytes",
    ));
    v.push(c(
        "flow/truncated-push",
        "push.truncated",
        vec![OP_1, 0x03, 0x01],
        vec![],
        "lock: says 3 bytes, has 1, after OP_1",
    ));
    v.push(c(
        "flow/truncated-push",
        "push.truncated",
        vec![0x4b],
        vec![],
        "lock: a 75-byte push with nothing after",
    ));
    v.push(c(
        "flow/truncated-push",
        "push.truncated",
        vec![OP_0, OP_IF, 0x05, 0x01, OP_ENDIF, OP_1],
        vec![],
        "a truncated push in a dead branch still fails the parse",
    ));

    // ---- IF / NOTIF conditions ----
    let conds: Vec<(Vec<u8>, &str)> = vec![
        (vec![], "empty"),
        (vec![1], "[1]"),
        (vec![2], "[2]"),
        (vec![0x80], "[0x80] negative zero"),
        (vec![0x00], "[0x00]"),
        (vec![0, 0, 0x80], "[0,0,0x80] negative zero"),
        (vec![1, 0], "[1,0]"),
        (vec![0x81], "[0x81]"),
        (vec![0, 1], "[0,1]"),
        (vec![0, 0, 0], "[0,0,0]"),
        (vec![0xff, 0xff], "[0xff,0xff]"),
        (vec![0, 0x80, 0], "[0,0x80,0]"),
    ];
    for (data, name) in &conds {
        let mut u = Vec::new();
        push_min(&mut u, data);
        v.push(c(
            "flow/if",
            "flow.if",
            vec![OP_IF, OP_1, OP_ELSE, OP_0, OP_ENDIF],
            u.clone(),
            &format!("IF on {name}"),
        ));
        v.push(c(
            "flow/notif",
            "flow.notif",
            vec![OP_NOTIF, OP_1, OP_ELSE, OP_0, OP_ENDIF],
            u.clone(),
            &format!("NOTIF on {name}"),
        ));
        v.push(c(
            "flow/if-no-else",
            "flow.if",
            vec![OP_IF, OP_1, OP_ENDIF],
            u.clone(),
            &format!("IF without ELSE on {name}"),
        ));
        v.push(c(
            "flow/verify",
            "flow.verify",
            vec![OP_VERIFY, OP_1],
            u.clone(),
            &format!("VERIFY on {name}"),
        ));
    }

    // ---- nesting: depth 1..3, every combination of conditions and leaves ----
    for depth in 1..=3usize {
        for mask in 0..(1u32 << depth) {
            for leaf in 0..2u8 {
                let mut lock = Vec::new();
                // cond_i is pushed by the unlock (outermost first on the stack: push in reverse)
                let mut unlock = Vec::new();
                for i in (0..depth).rev() {
                    unlock.push(if (mask >> i) & 1 == 1 { OP_1 } else { OP_0 });
                }
                lock.extend(std::iter::repeat_n(OP_IF, depth));
                lock.push(if leaf == 1 { OP_1 } else { OP_0 });
                for _ in 0..depth {
                    lock.push(OP_ELSE);
                    lock.push(OP_1);
                    lock.push(OP_ENDIF);
                }
                v.push(c(
                    "flow/nesting",
                    "flow.nesting",
                    lock,
                    unlock,
                    &format!("depth {depth}, conditions mask {mask:b}, innermost leaf {leaf}"),
                ));
            }
        }
    }
    // if-else-if chains
    for i in 0..4u8 {
        let mut unlock = Vec::new();
        for j in (0..3u8).rev() {
            unlock.push(if i == j { OP_1 } else { OP_0 });
        }
        let lock = vec![
            OP_IF, OP_1, OP_ELSE, OP_IF, OP_1, OP_ELSE, OP_IF, OP_1, OP_ELSE, OP_0, OP_ENDIF,
            OP_ENDIF, OP_ENDIF,
        ];
        v.push(c(
            "flow/else-if-chain",
            "flow.nesting",
            lock,
            unlock,
            &format!("chain selecting branch {i}"),
        ));
    }

    // ---- unbalanced ----
    v.push(c(
        "flow/unbalanced",
        "flow.unbalanced",
        vec![OP_IF, OP_1],
        vec![OP_1],
        "IF without ENDIF, true",
    ));
    v.push(c(
        "flow/unbalanced",
        "flow.unbalanced",
        vec![OP_IF, OP_1],
        vec![OP_0],
        "IF without ENDIF, false",
    ));
    v.push(c(
        "flow/unbalanced",
        "flow.unbalanced",
        vec![OP_1, OP_ELSE, OP_1],
        vec![],
        "ELSE without IF",
    ));
    v.push(c(
        "flow/unbalanced",
        "flow.unbalanced",
        vec![OP_1, OP_ENDIF],
        vec![],
        "ENDIF without IF",
    ));
    v.push(c(
        "flow/unbalanced",
        "flow.unbalanced",
        vec![OP_ENDIF],
        vec![OP_1, OP_IF],
        "IF in the unlocking script, ENDIF in the locking: each script balances on its own",
    ));
    v.push(c(
        "flow/unbalanced",
        "flow.unbalanced",
        vec![OP_IF, OP_1, OP_ENDIF],
        vec![],
        "IF on an empty stack",
    ));
    v.push(c(
        "flow/unbalanced",
        "flow.unbalanced",
        vec![OP_IF, OP_IF, OP_1, OP_ENDIF],
        vec![OP_1, OP_1],
        "two IFs, one ENDIF",
    ));
    v.push(c(
        "flow/unbalanced",
        "flow.unbalanced",
        vec![OP_0, OP_IF, OP_ELSE, OP_ELSE],
        vec![],
        "dead IF, two ELSEs, no ENDIF",
    ));

    // ---- VERIFY ----
    v.push(c(
        "flow/verify",
        "flow.verify",
        vec![OP_VERIFY],
        vec![],
        "VERIFY on an empty stack",
    ));
    v.push(c(
        "flow/verify",
        "flow.verify",
        vec![OP_1, OP_VERIFY, OP_1],
        vec![],
        "VERIFY consumes the true element",
    ));
    v.push(c(
        "flow/verify",
        "flow.verify",
        vec![OP_1, OP_VERIFY],
        vec![],
        "VERIFY leaves an empty stack",
    ));
    v.push(c(
        "flow/verify",
        "flow.verify",
        vec![OP_0, OP_VERIFY, OP_1],
        vec![],
        "VERIFY on false",
    ));

    // ---- RETURN ----
    v.push(c(
        "flow/return",
        "flow.return",
        vec![OP_1, OP_RETURN],
        vec![],
        "top-level RETURN with a true stack",
    ));
    v.push(c(
        "flow/return",
        "flow.return",
        vec![OP_0, OP_RETURN],
        vec![],
        "top-level RETURN with a false stack",
    ));
    v.push(c(
        "flow/return",
        "flow.return",
        vec![OP_RETURN],
        vec![],
        "RETURN on an empty stack",
    ));
    v.push(c(
        "flow/return",
        "flow.return",
        vec![OP_1, OP_RETURN, OP_VERIFY, OP_VERIFY, OP_VERIFY],
        vec![],
        "parseable code after a top-level RETURN never runs",
    ));
    v.push(c(
        "flow/return",
        "flow.return",
        vec![OP_1, OP_RETURN, OP_0],
        vec![],
        "a push after a top-level RETURN never runs",
    ));
    v.push(c(
        "flow/return",
        "flow.return",
        vec![OP_1, OP_IF, OP_RETURN, OP_ENDIF],
        vec![],
        "RETURN inside a terminated IF",
    ));
    v.push(c(
        "flow/return",
        "flow.return",
        vec![OP_1, OP_IF, OP_RETURN, OP_ENDIF, OP_0],
        vec![],
        "after a RETURN inside an IF, a later push does not run",
    ));
    v.push(c(
        "flow/return",
        "flow.return",
        vec![OP_0, OP_IF, OP_RETURN, OP_ENDIF, OP_1],
        vec![],
        "a RETURN in a dead branch",
    ));
    // RETURN in the unlocking script: a non-push opcode there, which bsv-rs refuses regardless of
    // the version (`spend.rs:186`, `237` at 0.3.24) while the reference allows it for version 2 post-Chronicle
    // (`interpreter.cpp:2321–2334`): recorded, not counted (#15)
    v.push(c(
        "flow/nonpush-unlock",
        "flow.return",
        vec![OP_1],
        vec![OP_1, OP_RETURN],
        "RETURN in the unlocking script ends it successfully",
    ));
    v.push(c(
        "flow/nonpush-unlock",
        "flow.return",
        vec![OP_1],
        vec![OP_0, OP_RETURN, OP_1],
        "RETURN in the unlocking script: the later push never runs, the lock decides",
    ));
    v.push(c(
        "flow/return",
        "flow.return",
        vec![OP_1, OP_IF, OP_RETURN, OP_ELSE, OP_0, OP_ENDIF],
        vec![],
        "RETURN in the then-branch; ELSE/ENDIF still balance",
    ));

    // ---- NOPs (consensus flags: no-ops) ----
    v.push(c(
        "flow/nop",
        "flow.nop",
        vec![OP_NOP, OP_1],
        vec![],
        "OP_NOP",
    ));
    v.push(c(
        "flow/nop",
        "flow.nop",
        vec![OP_NOP, OP_NOP, OP_NOP, OP_1, OP_NOP],
        vec![],
        "several OP_NOP",
    ));
    for op in [OP_NOP1, OP_NOP9, OP_NOP10] {
        v.push(c(
            "flow/nop-upgradable",
            "flow.nop",
            vec![op, OP_1],
            vec![],
            &format!(
                "OP_NOP{} (a no-op at consensus; DISCOURAGE_UPGRADABLE_NOPS is policy)",
                op - 0xaf
            ),
        ));
    }
    // OP_NOP4..8 are the Chronicle-restored opcodes (SUBSTR/LEFT/RIGHT/LSHIFTNUM/RSHIFTNUM): #10/#9, not flow
    let _ = OP_NOP4;

    // ---- reserved and unknown opcodes ----
    v.push(c(
        "flow/reserved",
        "flow.reserved",
        vec![OP_RESERVED, OP_1],
        vec![],
        "OP_RESERVED executed",
    ));
    v.push(c(
        "flow/reserved",
        "flow.reserved",
        vec![OP_0, OP_IF, OP_RESERVED, OP_ENDIF, OP_1],
        vec![],
        "OP_RESERVED in a dead branch",
    ));
    v.push(c(
        "flow/reserved",
        "flow.reserved",
        vec![OP_0, OP_IF, 0x89, 0x8a, OP_ENDIF, OP_1],
        vec![],
        "OP_RESERVED1/2 in a dead branch",
    ));
    v.push(c(
        "flow/reserved",
        "flow.reserved",
        vec![0x89, OP_1],
        vec![],
        "OP_RESERVED1 executed",
    ));
    // an undefined opcode (0xba–0xff) executed is the reference's `default:` → SCRIPT_ERR_BAD_OPCODE
    // (`interpreter.cpp:1795`); bsv-rs 0.3.24 treats the bytes above OP_NOP10 as further NOPs
    // (`op.rs`: OP_NOP11 … ), so the executed variants are recorded, not counted (#15)
    for op in [0xbau8, 0xc0, 0xf0, 0xfe, 0xff] {
        v.push(c(
            "flow/undefined-opcode-executed",
            "flow.unknown-opcode",
            vec![op, OP_1],
            vec![],
            &format!("undefined opcode 0x{op:02x} executed"),
        ));
        v.push(c(
            "flow/unknown-opcode-dead",
            "flow.unknown-opcode",
            vec![OP_0, OP_IF, op, OP_ENDIF, OP_1],
            vec![],
            &format!("undefined opcode 0x{op:02x} in a dead branch"),
        ));
    }

    // ---- final stack ----
    v.push(c(
        "stack/final",
        "stack.final",
        vec![OP_1, OP_1],
        vec![],
        "two true elements (CLEANSTACK is the version-1 twin's question)",
    ));
    v.push(c(
        "stack/final",
        "stack.final",
        vec![OP_1, OP_0],
        vec![],
        "false on top",
    ));
    v.push(c(
        "stack/final",
        "stack.final",
        vec![],
        vec![OP_1],
        "empty lock, true from the unlock",
    ));
    v.push(c(
        "stack/final",
        "stack.final",
        vec![],
        vec![],
        "both empty",
    ));
    v.push(c(
        "stack/final",
        "stack.final",
        vec![OP_1],
        vec![OP_0, OP_0, OP_0],
        "extra elements below a true top",
    ));
    v.push(c(
        "stack/final",
        "stack.final",
        vec![
            OP_0, OP_1, OP_0, OP_1, OP_0, OP_1, OP_0, OP_1, OP_0, OP_1, OP_0, OP_1,
        ],
        vec![],
        "twelve elements, true on top",
    ));
    v.push(c(
        "stack/final",
        "stack.final",
        vec![OP_1, OP_0],
        vec![OP_1],
        "false on top with true below",
    ));
    v.push(c(
        "stack/final",
        "stack.final",
        vec![OP_16],
        vec![],
        "OP_16 on top",
    ));
    v.push(c(
        "stack/final",
        "stack.final",
        vec![OP_1NEGATE],
        vec![],
        "OP_1NEGATE on top (truthy)",
    ));

    // ---- the version gate corners: non-minimal pushes are the v1 twins' rule ----
    for len in [1usize, 2, 10, 75] {
        let data: Vec<u8> = (0..len).map(|i| (0x41 + i as u8) | 1).collect();
        let mut u = Vec::new();
        push_nonmin(&mut u, &data);
        v.push(c(
            "flags/version-gate/minimaldata",
            "flags.version-gate",
            consume(),
            u,
            &format!("PUSHDATA1 for {len} bytes: MINIMALDATA under the gate"),
        ));
    }

    // ---- #19, the version-1 branch at its sites (`lean/BsvScript/Properties/VersionGate.lean`) ----
    // MINIMALDATA on the push form: the locking script has its own `requireMinimal` (433, once per
    // EvalScript call); a push in a dead branch is never checked (473, fExec); nothing after a
    // top-level OP_RETURN is parsed (858–861); the forms of CheckMinimalPush (331–358)
    {
        let mut l = Vec::new();
        push_nonmin(&mut l, &[0x21]);
        l.extend(consume());
        v.push(c("flags/v1/minimaldata/push-in-lock", "flags.v1.minimaldata.push", l, vec![], "PUSHDATA1 for one byte in the locking script: MINIMALDATA under the gate (433 per EvalScript call)"));
        let mut l = vec![OP_0, OP_IF];
        push_nonmin(&mut l, &[0x21]);
        l.extend([OP_ENDIF, OP_1]);
        v.push(c(
            "flags/v1/minimaldata/push-dead-branch",
            "flags.v1.minimaldata.push",
            l,
            vec![],
            "a non-minimal push in a dead branch is never checked (473: fExec)",
        ));
        let mut l = vec![OP_1, OP_RETURN];
        push_nonmin(&mut l, &[0x21]);
        v.push(c(
            "flags/v1/minimaldata/push-after-return",
            "flags.v1.minimaldata.push",
            l,
            vec![],
            "a non-minimal push after a top-level OP_RETURN is never parsed (858–861)",
        ));
        let mut l = vec![0x01, 0x05];
        l.extend(consume());
        v.push(c(
            "flags/v1/minimaldata/direct-for-op5",
            "flags.v1.minimaldata.push",
            l,
            vec![],
            "a direct push of [5] where OP_5 would do (336–339)",
        ));
        let mut l = vec![0x01, 0x81];
        l.extend(consume());
        v.push(c(
            "flags/v1/minimaldata/direct-for-1negate",
            "flags.v1.minimaldata.push",
            l,
            vec![],
            "a direct push of [0x81] where OP_1NEGATE would do (340–343)",
        ));
        let mut l = vec![0x01, 0x00];
        l.extend(consume());
        v.push(c(
            "flags/v1/minimaldata/direct-zero-byte",
            "flags.v1.minimaldata.push",
            l,
            vec![],
            "a direct push of [0x00] is minimal (344–348)",
        ));
        let mut l = vec![OP_PUSHDATA1, 0x00];
        l.extend(consume());
        v.push(c(
            "flags/v1/minimaldata/pushdata1-empty",
            "flags.v1.minimaldata.push",
            l,
            vec![],
            "PUSHDATA1 of zero bytes where OP_0 would do (332–335)",
        ));
        let data76: Vec<u8> = (0..76).map(|i| 0x20 + i as u8).collect();
        let mut l = Vec::new();
        pushdata2(&mut l, &data76);
        l.extend(consume());
        v.push(c(
            "flags/v1/minimaldata/pushdata2-for-76",
            "flags.v1.minimaldata.push",
            l,
            vec![],
            "PUSHDATA2 for 76 bytes where PUSHDATA1 would do (349–352)",
        ));
        let mut l = Vec::new();
        push_min(&mut l, &data76);
        l.extend(consume());
        v.push(c(
            "flags/v1/minimaldata/pushdata1-76",
            "flags.v1.minimaldata.push",
            l,
            vec![],
            "PUSHDATA1 for 76 bytes is minimal (349–352)",
        ));
        let data256: Vec<u8> = (0..256).map(|i| (0x21 + i) as u8).collect();
        let mut l = Vec::new();
        pushdata4(&mut l, &data256);
        l.extend(consume());
        v.push(c(
            "flags/v1/minimaldata/pushdata4-for-256",
            "flags.v1.minimaldata.push",
            l,
            vec![],
            "PUSHDATA4 for 256 bytes where PUSHDATA2 would do (353–356)",
        ));
        let mut l = Vec::new();
        pushdata2(&mut l, &data256);
        l.extend(consume());
        v.push(c(
            "flags/v1/minimaldata/pushdata2-256",
            "flags.v1.minimaldata.push",
            l,
            vec![],
            "PUSHDATA2 for 256 bytes is minimal (353–356)",
        ));
    }
    // CLEANSTACK: the main stack only (2441–2445; the alt stack dies with EvalScript, 1993–2005);
    // elements left by the unlocking script count
    v.push(c(
        "flags/v1/cleanstack/alt-stack",
        "flags.v1.cleanstack",
        vec![OP_1, OP_TOALTSTACK, OP_1],
        vec![],
        "an element left on the alt stack is not counted by CLEANSTACK",
    ));
    v.push(c("flags/v1/cleanstack/unlock-leftover", "flags.v1.cleanstack", vec![], vec![OP_1, OP_1], "two elements left by the unlocking script, an empty locking script: CLEANSTACK under the gate"));
    v.push(c(
        "flags/v1/cleanstack/three",
        "flags.v1.cleanstack",
        vec![OP_1, OP_1, OP_1],
        vec![],
        "three elements: CLEANSTACK under the gate",
    ));
    // SIGPUSHONLY (2321–2334; IsPushOnly script.cpp:205–218): OP_RESERVED counts as a push and then fails
    // when executed (211–215, 1795); OP_16 is the last push-type opcode (215)
    v.push(c("flags/v1/sigpushonly/reserved-in-unlock", "flags.sigpushonly", vec![OP_1], vec![OP_1, OP_RESERVED], "OP_RESERVED in the unlocking script passes IsPushOnly and fails when executed: BAD_OPCODE under both versions"));
    v.push(c(
        "flags/v1/sigpushonly/op16",
        "flags.sigpushonly",
        consume(),
        vec![OP_16],
        "OP_16 is the last push-type opcode",
    ));
    v.push(c("flow/nonpush-unlock", "flags.sigpushonly", vec![OP_1], vec![OP_0, OP_IF, OP_NOP, OP_ENDIF], "a non-push opcode in a dead branch of the unlocking script: IsPushOnly is syntactic (SIG_PUSHONLY under version 1; bsv-rs refuses under both)"));
    v.push(c("flow/nonpush-unlock", "flags.sigpushonly", vec![OP_1], vec![OP_1, OP_IF, OP_ENDIF], "flow opcodes in the unlocking script (SIG_PUSHONLY under version 1; bsv-rs refuses under both)"));

    // ---- divergence candidates (bsv-rs's model vs the reference; #15's witnesses) ----
    v.push(c(
        "flow/chronicle-ver",
        "flow.ver",
        vec![OP_VER, consume()[0], OP_1, OP_ELSE, OP_1, OP_ENDIF],
        vec![],
        "OP_VER pushes the version post-Chronicle",
    ));
    v.push(c(
        "flow/chronicle-verif",
        "flow.verif",
        vec![OP_VERIF, OP_1, OP_ELSE, OP_0, OP_ENDIF],
        vec![0x04, 0x02, 0x00, 0x00, 0x00],
        "OP_VERIF on the 4-byte version",
    ));
    v.push(c(
        "flow/chronicle-vernotif",
        "flow.verif",
        vec![OP_VERNOTIF, OP_1, OP_ELSE, OP_0, OP_ENDIF],
        vec![0x04, 0x01, 0x00, 0x00, 0x00],
        "OP_VERNOTIF on a different 4-byte value",
    ));
    v.push(c(
        "flow/chronicle-verif-size",
        "flow.verif",
        vec![OP_VERIF, OP_1, OP_ELSE, OP_0, OP_ENDIF],
        vec![OP_1],
        "OP_VERIF on a 1-byte element: false, no error",
    ));
    v.push(c(
        "flow/chronicle-ver-dead",
        "flow.ver",
        vec![OP_0, OP_IF, OP_VER, OP_ENDIF, OP_1],
        vec![],
        "OP_VER in a dead branch",
    ));
    v.push(c(
        "flow/second-else",
        "flow.else",
        vec![OP_IF, OP_1, OP_ELSE, OP_1, OP_ELSE, OP_1, OP_ENDIF],
        vec![OP_1],
        "a second ELSE for one IF (post-Genesis: unbalanced)",
    ));
    v.push(c(
        "flow/second-else",
        "flow.else",
        vec![OP_IF, OP_1, OP_ELSE, OP_0, OP_ELSE, OP_1, OP_ENDIF],
        vec![OP_0],
        "a second ELSE, dead IF",
    ));
    v.push(c(
        "flow/return-open-if",
        "flow.return",
        vec![OP_1, OP_IF, OP_RETURN],
        vec![],
        "RETURN inside an unterminated IF (the reference still requires balance)",
    ));
    v.push(c(
        "flow/return-open-if",
        "flow.return",
        vec![OP_1, OP_IF, OP_RETURN, OP_ELSE],
        vec![],
        "RETURN then a dangling ELSE",
    ));
    v.push(c(
        "flow/return-junk",
        "flow.return",
        vec![OP_1, OP_RETURN, 0x4c],
        vec![],
        "a truncated push after a top-level RETURN (never parsed by the reference)",
    ));
    v.push(c(
        "flow/return-junk",
        "flow.return",
        vec![OP_1, OP_RETURN, 0x05, 0x01],
        vec![],
        "a truncated push after a top-level RETURN",
    ));
    v.push(c(
        "flow/return-junk",
        "flow.return",
        vec![OP_1, OP_RETURN, 0xff, 0xba, OP_ENDIF, OP_ELSE],
        vec![],
        "undefined opcodes and unbalanced flow after a top-level RETURN",
    ));
    v.push(c("flow/nonpush-unlock", "flags.sigpushonly", vec![OP_1], vec![OP_1, OP_NOP], "a non-push opcode in the unlocking script (the reference allows it for version 2 post-Chronicle)"));
    v.push(c(
        "flow/nonpush-unlock",
        "flags.sigpushonly",
        vec![OP_ENDIF, OP_1],
        vec![OP_1, OP_IF, OP_1],
        "flow across the two scripts (each must balance on its own)",
    ));
    v
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let out_dir = arg(&args, "--out").unwrap_or_else(|| "../corpus/flow".into());
    let mut quiet = Quiet::new();
    let mut corpus = Corpus::new(EngineConfig::default());
    corpus.twins(&mut quiet, "flow", cases());
    quiet.restore();
    let comparable = corpus.comparable();
    let (path, sha, _) = corpus.write(&out_dir, Text {
        corpus: "flow",
        file: "flow.jsonl",
        manifest: "manifest.json",
        generator: "bsv-script-harness flow_cases 0.0.1 (a hand-written table; #8)".into(),
        seed: "none (hand-written)".into(),
        generated: "2026-09-23".into(),
        provenance: format!("hand-written flow cases with bsv-rs {}'s verdicts under the node's standard word; {comparable} comparable (every family since 0.3.27: the former flow-candidate/ and flow-policy/ families are comparable); synthetic outpoints = sha256 of the entry id", bsv_script_harness::BSV_RS_VERSION),
    });
    corpus.report("flow_cases", comparable, &path, &sha);
}
