//! A raw transaction codec (this repo's). It parses the transaction FRAME only
//! (version, inputs with their outpoint / script bytes / sequence, outputs with
//! their satoshis / script bytes, lock time) and never interprets a script, so a
//! corpus entry whose scripts no implementation can parse still round-trips.
//! Layout: the Bitcoin transaction serialization (little-endian integers,
//! CompactSize counts and lengths); txids are kept in INTERNAL byte order and
//! rendered in display order at the JSON boundary (`corpus.rs`).

use bsv_rs::primitives::hash::sha256;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RawInput {
    /// The outpoint's txid in internal byte order (the order the bytes are hashed in).
    pub txid: [u8; 32],
    pub vout: u32,
    /// The unlocking script bytes, uninterpreted.
    pub script: Vec<u8>,
    pub sequence: u32,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RawOutput {
    pub satoshis: u64,
    /// The locking script bytes, uninterpreted.
    pub script: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RawTx {
    pub version: i32,
    pub inputs: Vec<RawInput>,
    pub outputs: Vec<RawOutput>,
    pub lock_time: u32,
}

fn put_varint(out: &mut Vec<u8>, n: u64) {
    if n < 0xfd {
        out.push(n as u8);
    } else if n <= 0xffff {
        out.push(0xfd);
        out.extend_from_slice(&(n as u16).to_le_bytes());
    } else if n <= 0xffff_ffff {
        out.push(0xfe);
        out.extend_from_slice(&(n as u32).to_le_bytes());
    } else {
        out.push(0xff);
        out.extend_from_slice(&n.to_le_bytes());
    }
}

struct Reader<'a> {
    b: &'a [u8],
    p: usize,
}

impl<'a> Reader<'a> {
    fn take(&mut self, n: usize) -> Result<&'a [u8], String> {
        // checked: a length read from the bytes never wraps the offset (lean #32's re-lens, BN-7)
        let end = self.p.checked_add(n).filter(|&e| e <= self.b.len());
        let Some(end) = end else {
            return Err(format!(
                "truncated: need {n} bytes at offset {}, have {}",
                self.p,
                self.b.len() - self.p
            ));
        };
        let s = &self.b[self.p..end];
        self.p = end;
        Ok(s)
    }
    fn u32(&mut self) -> Result<u32, String> {
        let b: [u8; 4] = self
            .take(4)?
            .try_into()
            .map_err(|_| "u32: take(4) gave other than four bytes".to_string())?;
        Ok(u32::from_le_bytes(b))
    }
    fn u64(&mut self) -> Result<u64, String> {
        let b: [u8; 8] = self
            .take(8)?
            .try_into()
            .map_err(|_| "u64: take(8) gave other than eight bytes".to_string())?;
        Ok(u64::from_le_bytes(b))
    }
    /// `ReadCompactSize` (bitcoin-sv v1.2.2, `serialize.h:315–340`): a non-canonical size is refused, a value below
    /// 253 after `0xfd`, below `0x10000` after `0xfe`, below `2^32` after `0xff` (lean #32's second lens, B-1), and a
    /// value above `MAX_SIZE`, `2^32 − 1` (`serialize.h:34`, `336–338`), so every `0xff` form is refused (its re-lens, BN-7).
    fn varint(&mut self) -> Result<u64, String> {
        let t = self.take(1)?[0];
        let (v, min) = match t {
            0xfd => (
                u16::from_le_bytes(
                    self.take(2)?
                        .try_into()
                        .map_err(|_| "varint: take(2) gave other than two bytes".to_string())?,
                ) as u64,
                253u64,
            ),
            0xfe => (self.u32()? as u64, 0x1_0000),
            0xff => (self.u64()?, 0x1_0000_0000),
            n => return Ok(n as u64),
        };
        if v < min {
            return Err(format!(
                "non-canonical CompactSize {t:#04x} {v} (serialize.h:320–335)"
            ));
        }
        if v > 0xffff_ffff {
            return Err(format!(
                "CompactSize {v} above MAX_SIZE 2^32 - 1 (serialize.h:34, 336–338)"
            ));
        }
        Ok(v)
    }
}

impl RawTx {
    pub fn encode(&self) -> Vec<u8> {
        let mut out = Vec::new();
        out.extend_from_slice(&self.version.to_le_bytes());
        put_varint(&mut out, self.inputs.len() as u64);
        for i in &self.inputs {
            out.extend_from_slice(&i.txid);
            out.extend_from_slice(&i.vout.to_le_bytes());
            put_varint(&mut out, i.script.len() as u64);
            out.extend_from_slice(&i.script);
            out.extend_from_slice(&i.sequence.to_le_bytes());
        }
        put_varint(&mut out, self.outputs.len() as u64);
        for o in &self.outputs {
            out.extend_from_slice(&o.satoshis.to_le_bytes());
            put_varint(&mut out, o.script.len() as u64);
            out.extend_from_slice(&o.script);
        }
        out.extend_from_slice(&self.lock_time.to_le_bytes());
        out
    }

    pub fn decode(bytes: &[u8]) -> Result<RawTx, String> {
        let mut r = Reader { b: bytes, p: 0 };
        let version = r.u32()? as i32;
        let n_in = r.varint()?;
        let mut inputs = Vec::with_capacity(n_in.min(1 << 16) as usize);
        for _ in 0..n_in {
            let mut txid = [0u8; 32];
            txid.copy_from_slice(r.take(32)?);
            let vout = r.u32()?;
            let len = r.varint()? as usize;
            let script = r.take(len)?.to_vec();
            let sequence = r.u32()?;
            inputs.push(RawInput {
                txid,
                vout,
                script,
                sequence,
            });
        }
        let n_out = r.varint()?;
        let mut outputs = Vec::with_capacity(n_out.min(1 << 16) as usize);
        for _ in 0..n_out {
            let satoshis = r.u64()?;
            let len = r.varint()? as usize;
            let script = r.take(len)?.to_vec();
            outputs.push(RawOutput { satoshis, script });
        }
        let lock_time = r.u32()?;
        if r.p != bytes.len() {
            return Err(format!(
                "{} trailing bytes after the transaction",
                bytes.len() - r.p
            ));
        }
        Ok(RawTx {
            version,
            inputs,
            outputs,
            lock_time,
        })
    }

    /// The txid in internal byte order: sha256d of the serialization.
    pub fn txid_internal(&self) -> [u8; 32] {
        sha256d(&self.encode())
    }
}

pub fn sha256d(b: &[u8]) -> [u8; 32] {
    let h1 = sha256(b);
    let h2 = sha256(&h1);
    let mut out = [0u8; 32];
    out.copy_from_slice(&h2[..32]);
    out
}

/// Display-order hex of an internal-order txid (what explorers and RPCs show).
pub fn txid_display_hex(internal: &[u8; 32]) -> String {
    let mut r = *internal;
    r.reverse();
    hex::encode(r)
}

/// Internal-order txid from display-order hex.
pub fn txid_from_display_hex(s: &str) -> Result<[u8; 32], String> {
    let v = hex::decode(s).map_err(|e| format!("txid hex: {e}"))?;
    if v.len() != 32 {
        return Err(format!("txid hex is {} bytes, not 32", v.len()));
    }
    let mut out = [0u8; 32];
    out.copy_from_slice(&v);
    out.reverse();
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trip() {
        let tx = RawTx {
            version: 2,
            inputs: vec![RawInput {
                txid: [7u8; 32],
                vout: 3,
                script: vec![0x4c, 0x00],
                sequence: 0xffff_fffe,
            }],
            outputs: vec![
                RawOutput {
                    satoshis: 1,
                    script: vec![0x51],
                },
                RawOutput {
                    satoshis: 0,
                    script: vec![],
                },
            ],
            lock_time: 500_000_000,
        };
        let b = tx.encode();
        assert_eq!(RawTx::decode(&b).unwrap(), tx);
        assert_eq!(
            txid_from_display_hex(&txid_display_hex(&tx.txid_internal())).unwrap(),
            tx.txid_internal()
        );
    }

    #[test]
    fn non_canonical_compact_size_refused() {
        let tx = RawTx {
            version: 2,
            inputs: vec![RawInput {
                txid: [7u8; 32],
                vout: 0,
                script: vec![],
                sequence: 0,
            }],
            outputs: vec![RawOutput {
                satoshis: 1,
                script: vec![0x51],
            }],
            lock_time: 0,
        };
        let b = tx.encode();
        assert_eq!(RawTx::decode(&b).unwrap(), tx);
        // the input count 01 re-encoded non-canonically (serialize.h:320–335)
        for marker in [
            &[0xfd, 1, 0][..],
            &[0xfe, 1, 0, 0, 0][..],
            &[0xff, 1, 0, 0, 0, 0, 0, 0, 0][..],
        ] {
            let mut nc = b[..4].to_vec();
            nc.extend_from_slice(marker);
            nc.extend_from_slice(&b[5..]);
            assert!(RawTx::decode(&nc).is_err(), "{marker:?} must be refused");
        }
        // a canonical 0xff form is above MAX_SIZE (serialize.h:336–338), and a length near 2^64 must not wrap `take`
        let mut big = b[..4].to_vec();
        big.extend_from_slice(&[0xff, 0, 0, 0, 0, 1, 0, 0, 0]);
        big.extend_from_slice(&b[5..]);
        assert!(RawTx::decode(&big).is_err(), "2^32 must be refused");
        let mut r = Reader { b: &b, p: 1 };
        assert!(
            r.take(usize::MAX).is_err(),
            "an offset plus a huge length must be refused, not wrapped"
        );
    }

    #[test]
    fn unparseable_scripts_still_frame() {
        // a truncated PUSHDATA1 in the unlocking script is fine for the FRAME
        let tx = RawTx {
            version: 1,
            inputs: vec![RawInput {
                txid: [0u8; 32],
                vout: 0,
                script: vec![0x4c, 0x10, 0xaa],
                sequence: 0,
            }],
            outputs: vec![],
            lock_time: 0,
        };
        assert_eq!(RawTx::decode(&tx.encode()).unwrap(), tx);
    }
}
