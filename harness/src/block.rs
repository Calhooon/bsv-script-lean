//! block: the block road's assembler (this repo's; #27, D97; S3, set 4, 2026-09-26).
//!
//! The consensus column of a `tx.*` entry is the reference's acceptance of a BLOCK carrying the entry's
//! transaction, never a mempool's opinion; so the harness assembles that block itself (the node's own assembly,
//! `getblocktemplate`, would route the transaction through the mempool's policy first) and `submitblock`s it on
//! the block instance. What a block needs at v1.2.2 on regtest: a coinbase first (`CheckCoinbase`,
//! `validation.cpp:572–593`: a script of 2 to 100 bytes; its value at most the subsidy plus the fees,
//! `ConnectBlock`), the merkle root over the transactions' ids (double SHA-256, the last id duplicated on an odd
//! level), a header of 80 bytes (version, the previous hash, the root, the time, `bits`, the nonce), the time
//! above the median of the last eleven blocks and at most two hours ahead of the node's clock (`block_index.h:31`;
//! the clock is the mocktime the bake set), `bits` the chain's (regtest never retargets, `chainparams.cpp:1477`)
//! and a hash at or below the target `bits` encodes (a nonce loop of a few tries at regtest's limit). BIP34 never
//! activates on regtest (`:1463`), yet the coinbase script carries the height as its first push so every coinbase
//! of a height is distinct from every other's.
//!
//! The funding transactions spend the well's coinbases (P2PKH to the harness's well key, `oracle_chain`): one
//! transaction per funding height paying every prevout of that height as an output, signed SIGHASH_ALL|FORKID over
//! the well's script (FORKID is in force from height 0 on regtest, `chainparams.cpp` `uahfHeight = 0`).

use bsv_rs::primitives::bsv::sighash::{
    compute_sighash_for_signing, SighashParams, TxInput, TxOutput,
};
use bsv_rs::primitives::ec::PrivateKey;

use crate::cases::der;
use crate::gen::{enc_num, push_min};
use crate::txraw::{sha256d, RawInput, RawOutput, RawTx};

/// The 80-byte header; `prev` and `merkle` in internal byte order (as hashed and serialized).
#[derive(Clone, Debug)]
pub struct Header {
    pub version: i32,
    pub prev: [u8; 32],
    pub merkle: [u8; 32],
    pub time: u32,
    pub bits: u32,
    pub nonce: u32,
}

impl Header {
    pub fn encode(&self) -> [u8; 80] {
        let mut h = [0u8; 80];
        h[0..4].copy_from_slice(&self.version.to_le_bytes());
        h[4..36].copy_from_slice(&self.prev);
        h[36..68].copy_from_slice(&self.merkle);
        h[68..72].copy_from_slice(&self.time.to_le_bytes());
        h[72..76].copy_from_slice(&self.bits.to_le_bytes());
        h[76..80].copy_from_slice(&self.nonce.to_le_bytes());
        h
    }
    /// The block hash in internal order (double SHA-256 of the header).
    pub fn hash(&self) -> [u8; 32] {
        sha256d(&self.encode())
    }
}

/// The target `bits` encodes, as 32 big-endian bytes (`arith_uint256::SetCompact`).
pub fn target_of(bits: u32) -> [u8; 32] {
    let exponent = (bits >> 24) as usize;
    let mantissa = bits & 0x00ff_ffff;
    let mut t = [0u8; 32];
    // mantissa × 256^(exponent − 3): the three mantissa bytes end at byte index 32 − (exponent − 3) − 1 from the left
    if exponent <= 3 {
        let m = mantissa >> (8 * (3 - exponent));
        t[29] = (m >> 16) as u8;
        t[30] = (m >> 8) as u8;
        t[31] = m as u8;
    } else if exponent <= 32 {
        let shift = exponent - 3;
        let end = 32 - shift; // exclusive end index of the mantissa's last byte
        if end >= 3 {
            t[end - 3] = (mantissa >> 16) as u8;
            t[end - 2] = (mantissa >> 8) as u8;
            t[end - 1] = mantissa as u8;
        }
    }
    t
}

/// A hash (internal order) at or below the target (big-endian): the header is a valid proof of work.
pub fn meets_target(hash_internal: &[u8; 32], target_be: &[u8; 32]) -> bool {
    let mut be = *hash_internal;
    be.reverse();
    be <= *target_be
}

/// Loop the nonce until the hash meets the target; the nonce found. Regtest's limit `0x207fffff` needs ≈ 2 tries.
pub fn grind(h: &mut Header) -> u32 {
    let target = target_of(h.bits);
    loop {
        if meets_target(&h.hash(), &target) {
            return h.nonce;
        }
        h.nonce = h.nonce.wrapping_add(1);
    }
}

pub fn varint(n: u64) -> Vec<u8> {
    if n < 0xfd {
        vec![n as u8]
    } else if n <= 0xffff {
        let mut v = vec![0xfd];
        v.extend_from_slice(&(n as u16).to_le_bytes());
        v
    } else if n <= 0xffff_ffff {
        let mut v = vec![0xfe];
        v.extend_from_slice(&(n as u32).to_le_bytes());
        v
    } else {
        let mut v = vec![0xff];
        v.extend_from_slice(&n.to_le_bytes());
        v
    }
}

/// The merkle root over the transactions' ids (internal order; `ComputeMerkleRoot`: pairs hashed with double
/// SHA-256, an odd level's last id duplicated).
pub fn merkle_root(txids: &[[u8; 32]]) -> [u8; 32] {
    if txids.is_empty() {
        return [0u8; 32];
    }
    let mut level: Vec<[u8; 32]> = txids.to_vec();
    while level.len() > 1 {
        let mut next = Vec::with_capacity(level.len().div_ceil(2));
        for pair in level.chunks(2) {
            let mut buf = Vec::with_capacity(64);
            buf.extend_from_slice(&pair[0]);
            buf.extend_from_slice(&pair[pair.len() - 1]);
            next.push(sha256d(&buf));
        }
        level = next;
    }
    level[0]
}

/// The coinbase of a block the harness assembles: one input with the null outpoint, the script `<height> <extra>`
/// (a script number then a push, 2 to 100 bytes), one output of `value` to `script_pubkey` (the subsidy is 0 past
/// the first ≈ 5,000 regtest blocks; the fees may be claimed or left).
pub fn coinbase_tx(height: u32, value: u64, script_pubkey: Vec<u8>, extra: &[u8]) -> RawTx {
    let mut sig = Vec::new();
    push_min(&mut sig, &enc_num(height as i128));
    push_min(&mut sig, extra);
    RawTx {
        version: 1,
        inputs: vec![RawInput {
            txid: [0u8; 32],
            vout: 0xffff_ffff,
            script: sig,
            sequence: 0xffff_ffff,
        }],
        outputs: vec![RawOutput {
            satoshis: value,
            script: script_pubkey,
        }],
        lock_time: 0,
    }
}

/// The serialized block: the header, the count, the transactions.
pub fn serialize_block(header: &Header, txs: &[RawTx]) -> Vec<u8> {
    let mut out = Vec::new();
    out.extend_from_slice(&header.encode());
    out.extend_from_slice(&varint(txs.len() as u64));
    for t in txs {
        out.extend_from_slice(&t.encode());
    }
    out
}

/// A block over `txs` (the coinbase first) on top of `prev` at `time` with the chain's `bits` and `version`; the nonce ground.
pub fn assemble(
    version: i32,
    prev: [u8; 32],
    time: u32,
    bits: u32,
    txs: &[RawTx],
) -> (Header, Vec<u8>) {
    let ids: Vec<[u8; 32]> = txs.iter().map(|t| t.txid_internal()).collect();
    let mut h = Header {
        version,
        prev,
        merkle: merkle_root(&ids),
        time,
        bits,
        nonce: 0,
    };
    grind(&mut h);
    let bytes = serialize_block(&h, txs);
    (h, bytes)
}

/// A spend of P2PKH outputs held by `key` (each `(txid internal, vout, satoshis)` locked by `script_pubkey`, the
/// well's script), paying `outputs`; every input signed SIGHASH_ALL|FORKID (0x41) over the well's script with the
/// crate's BIP143 digest (the road's chain enforces FORKID from height 0).
/// The signer's refusal is an `Err` (#132): the funding road reports it and stops, never a panic mid-bake.
pub fn try_p2pkh_spend(
    inputs: &[([u8; 32], u32, u64)],
    outputs: Vec<RawOutput>,
    key: &PrivateKey,
    script_pubkey: &[u8],
) -> Result<RawTx, String> {
    let mut tx = RawTx {
        version: 2,
        inputs: inputs
            .iter()
            .map(|(txid, vout, _)| RawInput {
                txid: *txid,
                vout: *vout,
                script: vec![],
                sequence: 0xffff_ffff,
            })
            .collect(),
        outputs,
        lock_time: 0,
    };
    let pk = key.public_key().to_compressed().to_vec();
    let sh_inputs: Vec<TxInput> = tx
        .inputs
        .iter()
        .map(|i| TxInput {
            txid: i.txid,
            output_index: i.vout,
            script: i.script.clone(),
            sequence: i.sequence,
        })
        .collect();
    let sh_outputs: Vec<TxOutput> = tx
        .outputs
        .iter()
        .map(|o| TxOutput {
            satoshis: o.satoshis,
            script: o.script.clone(),
        })
        .collect();
    let mut unlocks = Vec::with_capacity(inputs.len());
    for (k, (_, _, sats)) in inputs.iter().enumerate() {
        let digest = compute_sighash_for_signing(&SighashParams {
            version: tx.version,
            inputs: &sh_inputs,
            outputs: &sh_outputs,
            locktime: tx.lock_time,
            input_index: k,
            subscript: script_pubkey,
            satoshis: *sats,
            scope: 0x41,
        });
        let s = key
            .sign(&digest)
            .map_err(|e| format!("p2pkh_spend: the signer refused input {k}: {e}"))?;
        let mut sig = der(s.r(), s.s());
        sig.push(0x41);
        let mut unlock = Vec::new();
        push_min(&mut unlock, &sig);
        push_min(&mut unlock, &pk);
        unlocks.push(unlock);
    }
    for (k, u) in unlocks.into_iter().enumerate() {
        tx.inputs[k].script = u;
    }
    Ok(tx)
}

/// `try_p2pkh_spend` for the caller that takes a transaction: harness/src/bin/run_teranode.rs (S4b's seat) until S4b's
/// patch record moves its two calls to `try_p2pkh_spend` (docs/LINT.md section 1b); then nothing calls it.
#[allow(
    clippy::panic,
    reason = "run_teranode.rs (S4b's file) calls this signature until its patch record lands; the signer refuses only a zero or out-of-range digest scalar, and the panic names it"
)]
pub fn p2pkh_spend(
    inputs: &[([u8; 32], u32, u64)],
    outputs: Vec<RawOutput>,
    key: &PrivateKey,
    script_pubkey: &[u8],
) -> RawTx {
    try_p2pkh_spend(inputs, outputs, key, script_pubkey).unwrap_or_else(|e| panic!("{e}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn regtest_target_and_a_ground_header() {
        let t = target_of(0x207f_ffff);
        assert_eq!(&t[..4], &[0x7f, 0xff, 0xff, 0x00]);
        assert!(t[4..].iter().all(|&b| b == 0));
        let mut h = Header {
            version: 0x2000_0000,
            prev: [1u8; 32],
            merkle: [2u8; 32],
            time: 1_700_000_000,
            bits: 0x207f_ffff,
            nonce: 0,
        };
        let n = grind(&mut h);
        assert!(meets_target(&h.hash(), &t));
        assert!(n < 64, "regtest's limit needs a few tries, not {n}");
    }

    #[test]
    fn merkle_of_one_and_two() {
        let a = [3u8; 32];
        let b = [4u8; 32];
        assert_eq!(merkle_root(&[a]), a);
        let mut buf = Vec::new();
        buf.extend_from_slice(&a);
        buf.extend_from_slice(&b);
        assert_eq!(merkle_root(&[a, b]), sha256d(&buf));
        // an odd level duplicates its last id
        let mut buf2 = Vec::new();
        buf2.extend_from_slice(&b);
        buf2.extend_from_slice(&b);
        let ab = sha256d(&buf);
        let bb = sha256d(&buf2);
        let mut top = Vec::new();
        top.extend_from_slice(&ab);
        top.extend_from_slice(&bb);
        assert_eq!(merkle_root(&[a, b, b]), sha256d(&top));
    }

    #[test]
    fn a_coinbase_script_is_between_two_and_a_hundred_bytes() {
        let cb = coinbase_tx(600_001, 0, vec![0x51], b"spec");
        let n = cb.inputs[0].script.len();
        assert!((2..=100).contains(&n), "{n}");
        assert_eq!(cb.inputs[0].vout, 0xffff_ffff);
        assert!(cb.inputs[0].txid.iter().all(|&b| b == 0));
    }
}
