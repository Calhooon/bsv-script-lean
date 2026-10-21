//! crypto_cases (#11): the signature opcodes through the engine with REAL
//! signatures (the pinned bsv-rs, 0.4.4 since 2026-10-12, 0.3.33 from 2026-10-07, bsv-rs#41 (0.3.30 from 2026-09-27, 0.3.28 from 2026-09-24), signs with keys that are sha256 of fixed labels, `key` below, over the
//! digest it computes for the case's transaction), emitted in the corpus
//! format with bsv-rs's verdict for `lean/Test/CryptoCheck.lean`. P2PK and
//! P2PKH, `CHECKSIGVERIFY`, every hash type with FORKID and the ANYONECANPAY
//! twins, a signature without FORKID, a high-S twin, a non-DER signature, a
//! hybrid key, wrong and empty signatures with and without `OP_NOT` (the
//! NULLFAIL gate), `CHECKMULTISIG` 1-of-2 and 2-of-3 in and out of order, a
//! non-empty dummy (the NULLDUMMY gate), the count errors, 0-of-0,
//! `OP_CODESEPARATOR` before the check; each with its version-1 twin.
//! Every family is COMPARABLE with bsv-rs under the node's standard word since
//! bsv-rs 0.3.27 (the pin of 2026-09-23; 0.3.28 from 2026-09-24, 0.3.30 from 2026-09-27, 0.4.4 since 2026-10-12, 0.3.33 from 2026-10-07). Until then `crypto-candidate/…` was
//! recorded, never counted (#15's witnesses): a `CHECKSIG` executing in the
//! unlocking script (0.3.24 required push-only unlocks regardless of version), a
//! FORKID signature whose push appears in the scriptCode (0.3.24 deleted it before
//! hashing; the reference deletes only without FORKID, `interpreter.cpp:255–263`),
//! the NULLFAIL cases under version 1 (0.3.24 had no NULLFAIL rule) and the
//! NULLDUMMY case under version 2 (0.3.24 enforced it regardless of version); each
//! fixed upstream (bsv-rs#10, #12).
//!
//! Run: cargo run --release --bin crypto_cases -- [--out DIR]

use bsv_rs::primitives::ec::PrivateKey;
use bsv_rs::primitives::hash::{hash160, sha256};
use bsv_script_harness::cases::{
    arg, crate_digest, der, pm, prevout_of, spend_tx, sub_from_n, synthetic_txid, twin_family,
    Corpus, Label, Quiet, Text, N_HEX,
};
use bsv_script_harness::engine::EngineConfig;
use bsv_script_harness::gen::{OP_0, OP_1, OP_DROP, OP_EQUALVERIFY};
use bsv_script_harness::txraw::RawTx;
use bsv_script_harness::BSV_RS_KEY;

const OP_2: u8 = 0x52;
const OP_3: u8 = 0x53;
const OP_NOT: u8 = 0x91;
const OP_DUP: u8 = 0x76;
const OP_HASH160: u8 = 0xa9;
const OP_CODESEPARATOR: u8 = 0xab;
const OP_CHECKSIG: u8 = 0xac;
const OP_CHECKSIGVERIFY: u8 = 0xad;
const OP_CHECKMULTISIG: u8 = 0xae;
const OP_CHECKMULTISIGVERIFY: u8 = 0xaf;

struct Case {
    family: String,
    rule: &'static str,
    lock: Vec<u8>,
    #[allow(
        dead_code,
        reason = "the unlock as built, kept beside its case; the case's transaction carries it into the corpus"
    )]
    unlock: Vec<u8>,
    note: String,
    /// the version(s) under which bsv-rs is known to differ from the reference (recorded, not counted)
    candidate_v2: bool,
    candidate_v1: bool,
}

/// Big-endian helpers on 32-byte scalars (the boundary values of s for #19).
fn be_sub1(x: &[u8; 32]) -> [u8; 32] {
    let mut out = *x;
    for i in (0..32).rev() {
        if out[i] > 0 {
            out[i] -= 1;
            break;
        } else {
            out[i] = 0xff;
        }
    }
    out
}
fn be_add1(x: &[u8; 32]) -> [u8; 32] {
    let mut out = *x;
    for i in (0..32).rev() {
        if out[i] < 0xff {
            out[i] += 1;
            break;
        } else {
            out[i] = 0;
        }
    }
    out
}
fn be_half(x: &[u8; 32]) -> [u8; 32] {
    let mut out = [0u8; 32];
    let mut carry = 0u8;
    for i in 0..32 {
        out[i] = (x[i] >> 1) | (carry << 7);
        carry = x[i] & 1;
    }
    out
}

/// A deterministic key: sha256 of a label.
#[allow(
    clippy::expect_used,
    reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
)]
fn key(label: &str) -> PrivateKey {
    let h = sha256(format!("bsv-script-lean/corpus/crypto/key/{label}").as_bytes());
    PrivateKey::from_bytes(&h).expect("key")
}

/// The digest bsv-rs signs for input 0 of `tx` over `subscript` with `scope` (BIP143), the coin's 1000 satoshis.
fn digest(tx: &RawTx, subscript: &[u8], scope: u32) -> [u8; 32] {
    crate_digest(tx, subscript, scope, 0, 1000)
}

/// Sign the digest with `sk`; DER plus the scope byte; optionally the high-S twin.
#[allow(
    clippy::expect_used,
    reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
)]
fn sig(sk: &PrivateKey, d: &[u8; 32], scope: u32, high: bool) -> Vec<u8> {
    let s = sk.sign(d).expect("sign");
    let (r, sv) = (*s.r(), *s.s());
    let mut out = if high {
        der(&r, &sub_from_n(&sv))
    } else {
        der(&r, &sv)
    };
    out.push((scope & 0xff) as u8);
    out
}

/// The cases for one version. Every case is (family, rule, lock, unlock-builder, note); the
/// unlock is built after the lock and the transaction shape are known (the signature covers them).
#[allow(
    clippy::unwrap_used,
    reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
)]
fn build(version: i32, id_base: usize) -> Vec<(Case, RawTx)> {
    let mut out: Vec<(Case, RawTx)> = Vec::new();
    let a = key("a");
    let b = key("b");
    let c = key("c");
    let z = key("z");
    let (pa, pb, pc) = (
        a.public_key().to_compressed().to_vec(),
        b.public_key().to_compressed().to_vec(),
        c.public_key().to_compressed().to_vec(),
    );
    let pa_u = a.public_key().to_uncompressed().to_vec();
    let mut n = id_base;
    // a case whose unlock is `f(digest over lock)`; the scriptCode is the whole lock (no separator)
    let mut add = |family: &str,
                   rule: &'static str,
                   lock: Vec<u8>,
                   subscript: Vec<u8>,
                   mk_unlock: &dyn Fn(&RawTx, &[u8]) -> Vec<u8>,
                   note: &str| {
        n += 1;
        let txid = synthetic_txid("crypto", &format!("crypto-{:05}", n));
        let tx0 = spend_tx(txid, version, vec![]);
        let unlock = mk_unlock(&tx0, &subscript);
        let tx = spend_tx(txid, version, unlock.clone());
        let candidate_v1 = family.contains("nullfail"); // bsv-rs has no NULLFAIL rule
        let candidate_v2 = family.contains("nulldummy"); // bsv-rs enforces NULLDUMMY regardless of version
        out.push((
            Case {
                family: family.into(),
                rule,
                lock: lock.clone(),
                unlock,
                note: note.into(),
                candidate_v2,
                candidate_v1,
            },
            tx,
        ));
    };
    // P2PK
    let p2pk = |pk: &[u8]| {
        let mut l = pm(pk);
        l.push(OP_CHECKSIG);
        l
    };
    add(
        "crypto/p2pk",
        "crypto.checksig",
        p2pk(&pa),
        p2pk(&pa),
        &|tx, sc| pm(&sig(&a, &digest(tx, sc, 0x41), 0x41, false)),
        "P2PK compressed, ALL|FORKID",
    );
    add(
        "crypto/p2pk",
        "crypto.checksig",
        p2pk(&pa_u),
        p2pk(&pa_u),
        &|tx, sc| pm(&sig(&a, &digest(tx, sc, 0x41), 0x41, false)),
        "P2PK uncompressed key",
    );
    for scope in [0x42u32, 0x43, 0xc1, 0xc2, 0xc3] {
        add(
            "crypto/p2pk/hashtype",
            "crypto.checksig",
            p2pk(&pa),
            p2pk(&pa),
            &move |tx, sc| {
                let a = key("a");
                pm(&sig(&a, &digest(tx, sc, scope), scope, false))
            },
            &format!("P2PK with hash type 0x{scope:02x}"),
        );
    }
    add(
        "crypto/p2pk/no-forkid",
        "crypto.checksig.encoding",
        p2pk(&pa),
        p2pk(&pa),
        &|tx, sc| pm(&sig(&a, &digest(tx, sc, 0x01), 0x01, false)),
        "a signature without FORKID under FORKID-enabled flags: MISSING_FORKID (STRICTENC)",
    );
    add(
        "crypto/p2pk/high-s",
        "flags.version-gate",
        p2pk(&pa),
        p2pk(&pa),
        &|tx, sc| pm(&sig(&a, &digest(tx, sc, 0x41), 0x41, true)),
        "the high-S twin: valid under version 2 (LOW_S gated off), SIG_HIGH_S under version 1",
    );
    add(
        "crypto/p2pk/non-der",
        "crypto.checksig.encoding",
        p2pk(&pa),
        p2pk(&pa),
        &|tx, sc| {
            let mut s = sig(&a, &digest(tx, sc, 0x41), 0x41, false);
            s[0] = 0x31;
            pm(&s)
        },
        "a non-DER signature (a wrong sequence tag): SIG_DER",
    );
    add(
        "crypto/p2pk/wrong-key",
        "crypto.checksig",
        p2pk(&pa),
        p2pk(&pa),
        &|tx, sc| pm(&sig(&z, &digest(tx, sc, 0x41), 0x41, false)),
        "a signature by another key: false, the script fails",
    );
    let p2pk_not = |pk: &[u8]| {
        let mut l = pm(pk);
        l.push(OP_CHECKSIG);
        l.push(OP_NOT);
        l
    };
    add("crypto/p2pk/nullfail", "flags.version-gate", p2pk_not(&pa), p2pk(&pa), &|tx, sc| pm(&sig(&z, &digest(tx, sc, 0x41), 0x41, false)), "a wrong non-empty signature negated: valid under version 2 (NULLFAIL gated off), SIG_NULLFAIL under version 1");
    add(
        "crypto/p2pk/empty-sig",
        "crypto.checksig",
        p2pk_not(&pa),
        p2pk(&pa),
        &|_, _| vec![OP_0],
        "an empty signature negated: valid under both versions",
    );
    let hybrid = {
        let mut h = pa_u.clone();
        h[0] = if pa_u[64] & 1 == 1 { 0x07 } else { 0x06 };
        h
    };
    add(
        "crypto/p2pk/hybrid-key",
        "crypto.checksig.encoding",
        p2pk(&hybrid),
        p2pk(&hybrid),
        &|tx, sc| pm(&sig(&a, &digest(tx, sc, 0x41), 0x41, false)),
        "a hybrid key: PUBKEYTYPE under STRICTENC",
    );
    // P2PKH
    let h = hash160(&pa);
    let p2pkh = {
        let mut l = vec![OP_DUP, OP_HASH160];
        l.extend(pm(&h));
        l.push(OP_EQUALVERIFY);
        l.push(OP_CHECKSIG);
        l
    };
    add(
        "crypto/p2pkh",
        "crypto.checksig",
        p2pkh.clone(),
        p2pkh.clone(),
        &|tx, sc| {
            let mut u = pm(&sig(&a, &digest(tx, sc, 0x41), 0x41, false));
            u.extend(pm(&key("a").public_key().to_compressed()));
            u
        },
        "P2PKH",
    );
    add(
        "crypto/p2pkh/wrong-key",
        "crypto.checksig",
        p2pkh.clone(),
        p2pkh.clone(),
        &|tx, sc| {
            let mut u = pm(&sig(&z, &digest(tx, sc, 0x41), 0x41, false));
            u.extend(pm(&key("z").public_key().to_compressed()));
            u
        },
        "P2PKH with another key: EQUALVERIFY fails",
    );
    // CHECKSIGVERIFY
    let p2pkv = |pk: &[u8]| {
        let mut l = pm(pk);
        l.push(OP_CHECKSIGVERIFY);
        l.push(OP_1);
        l
    };
    add(
        "crypto/checksigverify",
        "crypto.checksig",
        p2pkv(&pa),
        p2pkv(&pa),
        &|tx, sc| pm(&sig(&a, &digest(tx, sc, 0x41), 0x41, false)),
        "CHECKSIGVERIFY",
    );
    add(
        "crypto/checksigverify/fail",
        "crypto.checksig",
        p2pkv(&pa),
        p2pkv(&pa),
        &|tx, sc| pm(&sig(&z, &digest(tx, sc, 0x41), 0x41, false)),
        "CHECKSIGVERIFY with a wrong signature: CHECKSIGVERIFY (or NULLFAIL under version 1)",
    );
    // CODESEPARATOR: the scriptCode is the part after the separator
    let sep_lock = {
        let mut l = pm(&pa);
        l.push(OP_CODESEPARATOR);
        l.push(OP_CHECKSIG);
        l
    };
    add(
        "crypto/codeseparator",
        "crypto.codeseparator",
        sep_lock.clone(),
        vec![OP_CHECKSIG],
        &|tx, sc| pm(&sig(&a, &digest(tx, sc, 0x41), 0x41, false)),
        "a signature over the scriptCode after the separator",
    );
    add(
        "crypto/codeseparator/whole",
        "crypto.codeseparator",
        sep_lock.clone(),
        sep_lock.clone(),
        &|tx, sc| pm(&sig(&a, &digest(tx, sc, 0x41), 0x41, false)),
        "a signature over the whole script instead: false",
    );
    // CHECKMULTISIG
    let ms = |m: u8, keys: &[Vec<u8>], verify: bool| {
        let mut l = vec![0x50 + m];
        for k in keys {
            l.extend(pm(k));
        }
        l.push(0x50 + keys.len() as u8);
        l.push(if verify {
            OP_CHECKMULTISIGVERIFY
        } else {
            OP_CHECKMULTISIG
        });
        if verify {
            l.push(OP_1);
        }
        l
    };
    let ms12 = ms(1, &[pa.clone(), pb.clone()], false);
    add(
        "crypto/multisig/1of2",
        "crypto.checkmultisig",
        ms12.clone(),
        ms12.clone(),
        &|tx, sc| {
            let mut u = vec![OP_0];
            u.extend(pm(&sig(&key("a"), &digest(tx, sc, 0x41), 0x41, false)));
            u
        },
        "1-of-2 with the first key",
    );
    add(
        "crypto/multisig/1of2",
        "crypto.checkmultisig",
        ms12.clone(),
        ms12.clone(),
        &|tx, sc| {
            let mut u = vec![OP_0];
            u.extend(pm(&sig(&key("b"), &digest(tx, sc, 0x41), 0x41, false)));
            u
        },
        "1-of-2 with the second key",
    );
    let ms23 = ms(2, &[pa.clone(), pb.clone(), pc.clone()], false);
    add(
        "crypto/multisig/2of3",
        "crypto.checkmultisig",
        ms23.clone(),
        ms23.clone(),
        &|tx, sc| {
            let d = digest(tx, sc, 0x41);
            let mut u = vec![OP_0];
            u.extend(pm(&sig(&key("a"), &d, 0x41, false)));
            u.extend(pm(&sig(&key("c"), &d, 0x41, false)));
            u
        },
        "2-of-3 with keys a and c in order",
    );
    add(
        "crypto/multisig/2of3/order",
        "crypto.checkmultisig",
        ms23.clone(),
        ms23.clone(),
        &|tx, sc| {
            let d = digest(tx, sc, 0x41);
            let mut u = vec![OP_0];
            u.extend(pm(&sig(&key("c"), &d, 0x41, false)));
            u.extend(pm(&sig(&key("a"), &d, 0x41, false)));
            u
        },
        "2-of-3 with the signatures out of order: false",
    );
    let ms23n = {
        let mut l = ms23.clone();
        l.push(OP_NOT);
        l
    };
    add(
        "crypto/multisig/nullfail",
        "flags.version-gate",
        ms23n.clone(),
        ms23.clone(),
        &|tx, sc| {
            let d = digest(tx, sc, 0x41);
            let mut u = vec![OP_0];
            u.extend(pm(&sig(&key("c"), &d, 0x41, false)));
            u.extend(pm(&sig(&key("a"), &d, 0x41, false)));
            u
        },
        "out of order, negated: valid under version 2, SIG_NULLFAIL under version 1",
    );
    add("crypto/multisig/nulldummy", "flags.version-gate", ms12.clone(), ms12.clone(), &|tx, sc| { let mut u = vec![OP_1]; u.extend(pm(&sig(&key("a"), &digest(tx, sc, 0x41), 0x41, false))); u }, "a non-empty dummy: valid under version 2 (NULLDUMMY gated off), SIG_NULLDUMMY under version 1");
    let ms23v = ms(2, &[pa.clone(), pb.clone(), pc.clone()], true);
    add(
        "crypto/multisig/verify",
        "crypto.checkmultisig",
        ms23v.clone(),
        ms23v.clone(),
        &|tx, sc| {
            let d = digest(tx, sc, 0x41);
            let mut u = vec![OP_0];
            u.extend(pm(&sig(&key("b"), &d, 0x41, false)));
            u.extend(pm(&sig(&key("c"), &d, 0x41, false)));
            u
        },
        "2-of-3 CHECKMULTISIGVERIFY with keys b and c",
    );
    add(
        "crypto/multisig/0of0",
        "crypto.checkmultisig",
        vec![OP_0, OP_CHECKMULTISIG],
        vec![],
        &|_, _| vec![OP_0, OP_0],
        "0-of-0 (the dummy, the signature count 0, the key count 0): true",
    );
    let ms32 = {
        let mut l = vec![OP_3];
        l.extend(pm(&pa));
        l.extend(pm(&pb));
        l.push(OP_2);
        l.push(OP_CHECKMULTISIG);
        l
    };
    add(
        "crypto/multisig/sig-count",
        "crypto.checkmultisig",
        ms32,
        vec![],
        &|_, _| vec![OP_0, OP_0, OP_0, OP_0],
        "3-of-2: SIG_COUNT",
    );
    let msneg = {
        let mut l = vec![OP_1];
        l.extend(pm(&pa));
        l.extend(pm(&[0x81]));
        l.push(OP_CHECKMULTISIG);
        l
    };
    add(
        "crypto/multisig/pubkey-count",
        "crypto.checkmultisig",
        msneg,
        vec![],
        &|_, _| vec![OP_0, OP_0],
        "a negative key count: PUBKEY_COUNT",
    );
    // #19: LOW_S at its boundaries (282–287; pubkey.cpp:353–363): invalid signatures with a chosen s over a
    // fixed r; under version 1 a high s is SIG_HIGH_S before the check, a low s fails the check (NULLFAIL);
    // an r or s at or above n overflows the lax parse into the zero signature, which is low (146–173)
    {
        let r_fixed: [u8; 32] = {
            let mut r = [0u8; 32];
            r.copy_from_slice(
                &hex::decode("79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798")
                    .unwrap(),
            );
            r
        };
        let n_bytes: [u8; 32] = {
            let mut r = [0u8; 32];
            r.copy_from_slice(&hex::decode(N_HEX).unwrap());
            r
        };
        let n_minus_1 = be_sub1(&n_bytes);
        let half_low = be_half(&n_minus_1); // (n − 1) / 2, the largest low s
        let half_high = be_add1(&half_low); // (n + 1) / 2, the smallest high s
        for (label, sv, note) in [
            ("s-half-low", half_low, "s = (n − 1)/2, the largest low s: the signature fails (NULLFAIL under version 1)"),
            ("s-half-high", half_high, "s = (n + 1)/2, the smallest high s: SIG_HIGH_S under version 1"),
            ("s-n-minus-1", n_minus_1, "s = n − 1: SIG_HIGH_S under version 1"),
            ("s-n", n_bytes, "s = n overflows the lax parse into the zero signature (low): the check passes, the signature fails"),
            ("s-zero", [0u8; 32], "s = 0 is low and never verifies"),
        ] {
            let sigb = { let mut o = der(&r_fixed, &sv); o.push(0x41); o };
            add(&format!("crypto/lows/{label}"), "flags.v1.lows", p2pk(&pa), p2pk(&pa), &move |_, _| pm(&sigb), note);
        }
        let sigb = {
            let mut o = der(&n_bytes, &[7u8; 32]);
            o.push(0x41);
            o
        };
        add(
            "crypto/lows/r-n",
            "flags.v1.lows",
            p2pk(&pa),
            p2pk(&pa),
            &move |_, _| pm(&sigb),
            "r = n overflows the lax parse the same way",
        );
        // the multisig site (1605) and the negated high-S (the encoding check precedes the signature check)
        let ms11 = ms(1, std::slice::from_ref(&pa), false);
        add(
            "crypto/lows/multisig-1of1-high-s",
            "flags.v1.lows",
            ms11.clone(),
            ms11.clone(),
            &|tx, sc| {
                let mut u = vec![OP_0];
                u.extend(pm(&sig(&key("a"), &digest(tx, sc, 0x41), 0x41, true)));
                u
            },
            "1-of-1 with the high-S twin: SIG_HIGH_S under version 1 (1605), valid under version 2",
        );
        add("crypto/lows/high-s-not", "flags.v1.lows", p2pk_not(&pa), p2pk(&pa), &|tx, sc| pm(&sig(&a, &digest(tx, sc, 0x41), 0x41, true)), "the high-S twin negated: SIG_HIGH_S under version 1 (1459 before 1486), the normalized signature verifies under version 2 so OP_NOT makes it false");
        // the counts of OP_CHECKMULTISIG are read with requireMinimal at width 4 (1523–1526, 1550–1553)
        let msk = {
            let mut l = pm(&pa);
            l.extend(pm(&[0x01, 0x00]));
            l.push(OP_CHECKMULTISIG);
            l
        };
        add("crypto/multisig/nkeys-nonminimal", "flags.v1.minimaldata.number", msk, vec![], &|_, _| vec![OP_0, OP_0], "the key count padded (0x0100 = 1) with no signature: valid under version 2, SCRIPTNUM_MINENCODE under version 1 (1523–1526)");
        let mss = {
            let mut l = pm(&pa);
            l.push(OP_1);
            l.push(OP_CHECKMULTISIG);
            l
        };
        add("crypto/multisig/nsigs-nonminimal", "flags.v1.minimaldata.number", mss, vec![], &|_, _| { let mut u = vec![OP_0]; u.extend(pm(&[0x00, 0x00])); u }, "the signature count padded (0x0000 = 0): valid under version 2, SCRIPTNUM_MINENCODE under version 1 (1550–1553)");
    }
    // candidates
    let lock1 = vec![OP_1];
    add("crypto/checksig-in-unlock", "crypto.checksig.unlock", lock1.clone(), { let mut sc = vec![OP_CHECKSIG]; sc.extend(lock1.clone()); sc }, &|tx, sc| { let mut u = pm(&sig(&key("a"), &digest(tx, sc, 0x41), 0x41, false)); u.extend(pm(&key("a").public_key().to_compressed())); u.push(OP_CHECKSIG); u }, "CHECKSIG executing in the unlocking script post-Chronicle over unlock-from-separator ++ lock; bsv-rs requires push-only unlocks");
    // FindAndDelete with FORKID: the signature's push appears in the scriptCode
    {
        n += 1;
        let txid = synthetic_txid("crypto", &format!("crypto-{:05}", n));
        let tx0 = spend_tx(txid, version, vec![]);
        let deleted = {
            let mut l = vec![OP_DROP];
            l.extend(pm(&pa));
            l.push(OP_CHECKSIG);
            l
        };
        let s = sig(&a, &digest(&tx0, &deleted, 0x41), 0x41, false);
        let lock = {
            let mut l = pm(&s);
            l.extend(deleted.clone());
            l
        };
        let unlock = pm(&s);
        let tx = spend_tx(txid, version, unlock.clone());
        out.push((Case { family: "crypto/findanddelete-forkid".into(), rule: "sighash.scriptcode.findanddelete", lock, unlock, note: "a FORKID signature whose push appears in the scriptCode: the reference hashes it in (no deletion with FORKID) so no signature can verify; bsv-rs deletes it and accepts the signature over the deleted scriptCode".into(), candidate_v2: false, candidate_v1: false }, tx));
    }
    out
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let out_dir = arg(&args, "--out").unwrap_or_else(|| "../corpus/crypto".into());
    let mut quiet = Quiet::new();
    let mut corpus = Corpus::new(EngineConfig::default());
    for version in [2i32, 1] {
        for (case, tx) in build(version, if version == 2 { 0 } else { 1000 }) {
            let id = corpus.next_id("crypto");
            let prevouts = prevout_of(tx.inputs[0].txid, &case.lock);
            let judged = corpus.run(&tx, &prevouts);
            // until 0.3.27 the NULLFAIL twins at version 1 and the NULLDUMMY twin at version 2 were
            // candidates (bsv-rs#10, fixed in 0.3.26): comparable since
            let _ = (case.candidate_v1, case.candidate_v2);
            let note = if version == 1 {
                format!("version-1 twin: {}", case.note)
            } else {
                case.note.clone()
            };
            let label = Label::new(id, twin_family(&case.family, version), case.rule, note);
            corpus.record(label, &tx, &prevouts, &judged);
        }
    }
    quiet.restore();
    let comparable = corpus.comparable();
    let (path, sha, _) = corpus.write(&out_dir, Text {
        corpus: "crypto-cases",
        file: "cases.jsonl",
        manifest: "cases-manifest.json",
        generator: "bsv-script-harness crypto_cases 0.0.1 (real signatures by bsv-rs; #11)".into(),
        seed: "the keys are sha256 of labels".into(),
        generated: "2026-09-23".into(),
        provenance: format!("signature-opcode cases with real bsv-rs signatures and bsv-rs {}'s verdicts under the node's standard word; {comparable} comparable (every family since 0.3.27); synthetic outpoints = sha256 of the entry id", bsv_script_harness::BSV_RS_VERSION),
    });
    corpus.report("crypto_cases", comparable, &path, &sha);
    for e in &corpus.entries {
        println!("  {} {} {}", e.id, e.family, e.expect[BSV_RS_KEY].verdict);
    }
}
