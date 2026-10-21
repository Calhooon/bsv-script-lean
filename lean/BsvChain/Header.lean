import BsvScript.Sighash

/-!
# Block headers (#63)

The fixed frame and unsigned arithmetic of [SRC] bitcoin-sv v1.2.3,
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b`. Hash words use the integer
whose little-endian bytes are the internal hash, not the displayed hex order.
The version stores its wire bits; `signedVersion` supplies the signed reading.
-/

namespace BsvChain
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash

/-- Fixed-width little-endian bytes, truncating above the requested width.
[SRC] src/serialize.h:71–91 and src/arith_uint256.cpp:227–242 at 6504a3af.
This generalizes the interpreter's four-byte serializer to hash words. -/
def headerWordBytes : Nat → Nat → Bytes
  | 0, _ => []
  | n + 1, value => value % 256 :: headerWordBytes n (value / 256)

/-- The [D] 4 + 32 + 32 + 4 + 4 + 4 = 80 byte frame.
[SRC] src/primitives/block.h:23–45 at 6504a3af. Widths are part of the type. -/
structure BlockHeader where
  version : BitVec 32
  prevBlock : BitVec 256
  merkleRoot : BitVec 256
  time : BitVec 32
  bits : BitVec 32
  nonce : BitVec 32
  deriving DecidableEq, Repr, Inhabited

/-- Signed `int32_t` version, reusing the transaction decoder's reading.
[SRC] src/primitives/block.h:26 at 6504a3af. -/
def BlockHeader.signedVersion (h : BlockHeader) : Int := toInt32 h.version.toNat

/-- The header serialization in source field order.
[SRC] src/primitives/block.h:38–45 at 6504a3af. -/
def BlockHeader.encode (h : BlockHeader) : Bytes :=
  headerWordBytes 4 h.version.toNat ++ headerWordBytes 32 h.prevBlock.toNat ++
  headerWordBytes 32 h.merkleRoot.toNat ++ headerWordBytes 4 h.time.toNat ++
  headerWordBytes 4 h.bits.toNat ++ headerWordBytes 4 h.nonce.toNat

/-- Read a header and retain the following body bytes, using the existing
transaction reader. [SRC] src/primitives/block.h:38–45,103–107 at 6504a3af.
As with that reader, the input domain is byte-valued `Bytes`. -/
def BlockHeader.decodePrefix (bs : Bytes) : Option (BlockHeader × Bytes) := do
  let (version, bs) ← readLE 4 bs
  let (prevBlock, bs) ← readLE 32 bs
  let (merkleRoot, bs) ← readLE 32 bs
  let (time, bs) ← readLE 4 bs
  let (bits, bs) ← readLE 4 bs
  let (nonce, bs) ← readLE 4 bs
  return (⟨BitVec.ofNat 32 version, BitVec.ofNat 256 prevBlock,
    BitVec.ofNat 256 merkleRoot, BitVec.ofNat 32 time,
    BitVec.ofNat 32 bits, BitVec.ofNat 32 nonce⟩, bs)

/-- Exactly one header frame, rejecting trailing bytes.
[SRC] src/primitives/block.h:38–45 at 6504a3af; exact framing is this API's contract. -/
def BlockHeader.decode (bs : Bytes) : Option BlockHeader := do
  let (h, rest) ← BlockHeader.decodePrefix bs
  if rest.isEmpty then some h else none

/-- Header identifier: the existing SHA256d, interpreted in internal order.
[SRC] src/primitives/block.cpp:16–18 and src/arith_uint256.cpp:236–242 at 6504a3af. -/
def BlockHeader.hash (h : BlockHeader) : BitVec 256 :=
  BitVec.ofNat 256 (leNat (sha256d h.encode))

/-- Compact decoding retains the two independent error flags.
[SRC] src/arith_uint256.cpp:182–200 at 6504a3af. -/
structure CompactTarget where
  target : Nat
  negative : Bool
  overflow : Bool
  deriving DecidableEq, Repr

/-- `SetCompact`: the mantissa is shifted before the sign/overflow flags are
computed when the exponent is small; large shifts wrap to 256 bits.
[SRC] src/arith_uint256.cpp:182–200 at 6504a3af. -/
def compactTarget (bits : BitVec 32) : CompactTarget :=
  let size := bits.toNat / 2 ^ 24
  let word := bits.toNat % 2 ^ 23
  let word := if size ≤ 3 then word / 256 ^ (3 - size) else word
  let target := if size ≤ 3 then word else word * 256 ^ (size - 3) % 2 ^ 256
  ⟨target, word != 0 && bits.toNat &&& 0x00800000 != 0,
    word != 0 && (size > 34 || (word > 0xff && size > 33) || (word > 0xffff && size > 32))⟩

/-- `GetCompact` of a nonnegative 256-bit word, including its mantissa sign
bit adjustment. [SRC] src/arith_uint256.cpp:203–224 at 6504a3af. -/
def targetCompact (target : Nat) : BitVec 32 :=
  let target := target % 2 ^ 256
  let size := (target.log2 + 8) / 8
  let size := if target = 0 then 0 else size
  let word := if size ≤ 3 then target * 256 ^ (3 - size) else target / 256 ^ (size - 3)
  let (size, word) := if word &&& 0x00800000 != 0 then (size + 1, word / 256) else (size, word)
  BitVec.ofNat 32 (word + size * 2 ^ 24)

/-- Work credited to a header, zero for an invalid compact target. `powLimit`
is not consulted by this function. [SRC] src/block_index.cpp:114–127 at 6504a3af. -/
def blockProof (bits : BitVec 32) : Nat :=
  let t := compactTarget bits
  if t.negative || t.overflow || t.target == 0 then 0
  else (2 ^ 256 - 1 - t.target) / (t.target + 1) + 1

/-- Accumulated work has the reference's unsigned 256-bit width.
[SRC] src/block_index.h:349,663–664 and src/arith_uint256.h:124–142 at 6504a3af. -/
def addChainWork (parentWork : BitVec 256) (bits : BitVec 32) : BitVec 256 :=
  parentWork + BitVec.ofNat 256 (blockProof bits)

end BsvChain
