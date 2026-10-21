//! The mainnet sighash verifier (#12). Reads `corpus/sighash/mainnet.jsonl`
//! (public P2PKH spends read from mainnet, `tools/mainnet_read.py`; the reads
//! are on the record in `docs/PROVENANCE.md` §6) and, on stdin, the digests the
//! Lean check printed for them (`MAINNET <txid> <input> <digest hex>`, from
//! `lean/Test/SighashCheck.lean`). For every entry the transaction's own
//! signature must verify against its public key and the LEAN digest: ECDSA on
//! secp256k1 through the pinned bsv-rs (0.4.4 since 2026-10-12, 0.3.33 from 2026-10-07, bsv-rs#41 (0.3.30 from 2026-09-27, 0.3.28 from 2026-09-24, 0.3.27 on 2026-09-23); `Signature::from_der`, `Signature::verify`,
//! which normalizes a high S: `primitives/ec/ecdsa.rs:90`; the pre-2016
//! signatures may be high-S). A negative control flips one digest bit per
//! entry and must fail to verify, so that the leg is known to bite.
//! Exit 1 on any failure or on a missing digest.
use bsv_rs::primitives::ec::{PublicKey, Signature};
use std::collections::HashMap;
use std::io::{self, BufRead};

#[allow(
    clippy::expect_used,
    clippy::unwrap_used,
    reason = "a tripwire checker that writes nothing: a failure is its leg RED with the message"
)]
fn main() {
    let path = std::env::args()
        .nth(1)
        .expect("usage: sighash_verify <mainnet.jsonl> < digests");
    let entries: Vec<serde_json::Value> = std::fs::read_to_string(&path)
        .expect("read corpus")
        .lines()
        .filter(|l| !l.trim().is_empty())
        .map(|l| serde_json::from_str(l).expect("json"))
        .collect();
    let mut digests: HashMap<(String, u64), [u8; 32]> = HashMap::new();
    for line in io::stdin().lock().lines() {
        let line = line.expect("stdin");
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() == 4 && parts[0] == "MAINNET" {
            let mut d = [0u8; 32];
            d.copy_from_slice(&hex::decode(parts[3]).expect("digest hex"));
            digests.insert((parts[1].to_string(), parts[2].parse().expect("input")), d);
        }
    }
    let (mut ok, mut bad, mut control_held) = (0usize, 0usize, 0usize);
    for e in &entries {
        let txid = e["txid"].as_str().unwrap().to_string();
        let input = e["input"].as_u64().unwrap();
        let sig = hex::decode(e["sig"].as_str().unwrap()).unwrap();
        let pk = hex::decode(e["pubkey"].as_str().unwrap()).unwrap();
        let Some(digest) = digests.get(&(txid.clone(), input)) else {
            println!("  {txid}:{input}: NO DIGEST from the Lean check");
            bad += 1;
            continue;
        };
        let der = &sig[..sig.len() - 1];
        let signature = Signature::from_der(der).expect("DER");
        let public_key = PublicKey::from_bytes(&pk).expect("pubkey");
        let verified = signature.verify(digest, &public_key);
        let mut flipped = *digest;
        flipped[31] ^= 1;
        let control = signature.verify(&flipped, &public_key);
        if !control {
            control_held += 1;
        }
        if verified && !control {
            ok += 1;
        } else {
            bad += 1;
            println!("  {txid}:{input}: verify={verified} control(flipped)={control} height={} type=0x{:02x}", e["height"], e["sighash_type"].as_u64().unwrap());
        }
    }
    println!("sighash_verify: {ok} / {} mainnet signatures verify against the Lean digest (bsv-rs {} ECDSA); {bad} failures; the negative control (a bit-flipped digest) fails to verify on {control_held} of {} entries", entries.len(), bsv_script_harness::BSV_RS_VERSION, entries.len());
    if bad != 0 || entries.is_empty() {
        std::process::exit(1);
    }
}
