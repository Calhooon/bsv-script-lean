//! ecdsa_vectors (#11): signatures made by the pinned bsv-rs (0.4.4 since 2026-10-12; 0.3.33 from bsv-rs#41, 2026-10-07; 0.3.32 from R1, 2026-10-06; 0.3.30 from #47, 0.3.29 from 2026-09-27, 0.3.28 from 2026-09-24, 0.3.27 on 2026-09-23;
//! the output at 0.3.32 byte-identical to the 0.3.30 file, renamed `corpus/crypto/ecdsa-bsv-rs-0.3.32.jsonl` (`cmp`, the bump record of 0.3.32);
//! at 0.3.30 to the committed file, regenerated 2026-10-05, `docs/records/20261005-225025-ecdsa-identity-0.3.30-s3.md`; at the earlier pins to 0.3.24's by their own `cmp`s;
//! RustCrypto's `k256`, not libsecp256k1: the lock file carries no `secp256k1` crate) on random keys and digests, their
//! expectations set here by construction, no library's verdict (lean #32's second lens, D-3), for
//! `lean/Test/CryptoCheck.lean`: the spec's executable ECDSA equation must
//! accept every genuine signature (compressed and uncompressed keys, low-S and
//! its high-S twin, which the reference normalizes) and reject every mutation
//! (a flipped digest bit, a flipped signature byte, another key, r = 0,
//! s = 0, r ≥ n, s ≥ n). One line per case: `{"pubkey": hex, "sig": DER hex
//! (no hash-type byte), "hash": hex, "expect": bool, "what": …}`.
//! Run: cargo run --release --bin ecdsa_vectors -- [--count N] > out.jsonl
use bsv_rs::primitives::ec::{PrivateKey, PublicKey, Signature};
use bsv_script_harness::cases::{arg, der, sub_from_n, N_HEX};
use bsv_script_harness::gen::Rng;

#[allow(
    clippy::expect_used,
    clippy::unwrap_used,
    reason = "an offline corpus generator: it drives no node and writes no record or report; a failure stops the generation with its message"
)]
fn main() {
    let args: Vec<String> = std::env::args().collect();
    let count: usize = arg(&args, "--count")
        .map(|s| s.parse().expect("--count"))
        .unwrap_or(200);
    let mut rng = Rng(0x0011_0011_0011_0011);
    let n_bytes = hex::decode(N_HEX).unwrap();
    let emit = |pk: &[u8], sig: &[u8], hash: &[u8; 32], expect: bool, what: &str| {
        println!(
            "{}",
            serde_json::json!({"pubkey": hex::encode(pk), "sig": hex::encode(sig), "hash": hex::encode(hash), "expect": expect, "what": what})
        );
    };
    for i in 0..count {
        let key_bytes: Vec<u8> = (0..32).map(|_| (rng.below(256)) as u8).collect();
        let Ok(sk) = PrivateKey::from_bytes(&key_bytes) else {
            continue;
        };
        let pk = sk.public_key();
        let hash: [u8; 32] = {
            let mut h = [0u8; 32];
            for b in h.iter_mut() {
                *b = rng.below(256) as u8;
            }
            h
        };
        let sig = sk.sign(&hash).expect("sign");
        let (r, s) = (*sig.r(), *sig.s());
        let low = der(&r, &s);
        let pkc = pk.to_compressed().to_vec();
        let pku = pk.to_uncompressed().to_vec();
        emit(&pkc, &low, &hash, true, "genuine, compressed key");
        emit(&pku, &low, &hash, true, "genuine, uncompressed key");
        // the high-S twin: the reference normalizes before verifying
        let high = der(&r, &sub_from_n(&s));
        emit(
            &pkc,
            &high,
            &hash,
            true,
            "genuine, high-S twin (normalized by the reference)",
        );
        // mutations
        let mut h2 = hash;
        h2[i % 32] ^= 1;
        emit(&pkc, &low, &h2, false, "a flipped digest bit");
        let mut bad = low.clone();
        let j = 4 + (i % 30);
        bad[j] ^= 1;
        emit(&pkc, &bad, &hash, false, "a flipped signature byte");
        let other_bytes: Vec<u8> = (0..32).map(|_| (rng.below(256)) as u8).collect();
        if let Ok(other) = PrivateKey::from_bytes(&other_bytes) {
            emit(
                &other.public_key().to_compressed(),
                &low,
                &hash,
                false,
                "another key",
            );
        }
        if i % 10 == 0 {
            emit(&pkc, &der(&[0u8; 32], &s), &hash, false, "r = 0");
            emit(&pkc, &der(&r, &[0u8; 32]), &hash, false, "s = 0");
            let mut nn = [0u8; 32];
            nn.copy_from_slice(&n_bytes);
            emit(
                &pkc,
                &der(&nn, &s),
                &hash,
                false,
                "r = n (overflow: the zero signature)",
            );
            emit(
                &pkc,
                &der(&r, &nn),
                &hash,
                false,
                "s = n (overflow: the zero signature)",
            );
            // a hybrid tag: the point decodes when the parity matches
            let mut hyb = pku.clone();
            hyb[0] = if pku[64] & 1 == 1 { 0x07 } else { 0x06 };
            emit(
                &hyb,
                &low,
                &hash,
                true,
                "genuine, hybrid tag with the matching parity",
            );
            let mut hybw = pku.clone();
            hybw[0] = if pku[64] & 1 == 1 { 0x06 } else { 0x07 };
            emit(
                &hybw,
                &low,
                &hash,
                false,
                "hybrid tag with the wrong parity",
            );
            let mut pkoff = pku.clone();
            pkoff[64] ^= 1;
            emit(
                &pkoff,
                &low,
                &hash,
                false,
                "an uncompressed key off the curve",
            );
        }
        let _ = PublicKey::from_bytes(&pkc);
        let _ = Signature::from_der(&low);
    }
}
