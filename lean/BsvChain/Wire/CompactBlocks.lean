import BsvChain.Block
import BsvChain.Wire.P2P

/-!
# Compact blocks (#79), 2026-10-15 [D]

Nothing in this module is a block-validity rule. A compact block is a relay
encoding: it decides how a node receives a block it may already partly hold,
never whether the block is valid. The reconstruction ends in the reference's
`CheckBlock` (#63's `checkBlock`), which is the validity judge here as
everywhere; the settings the procedure reads are the auxiliary
`CompactConfig` below (docs/PARAMETERS.md section 8.11), each policy with its
default and source (rule 1).

The short id: SipHash-2-4 of the transaction id, keyed by the leading two
little-endian 64-bit words of the single SHA-256 of the header followed by
the message's 64-bit nonce, cut to its low 48 bits. The message
(`cmpctblock`): the header, the nonce, the short ids (six bytes each) and the
prefilled transactions (a differentially encoded index and the transaction).
The receiver places the prefilled transactions, maps each short id to the
next empty position, fills what its pool and its extra transactions match,
and asks with `getblocktxn` for the positions still empty; `blocktxn` carries
them back and the block is filled and checked.

[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/blockencodings.h:36-141 (`BlockTransactionsRequest`, `BlockTransactions`,
`PrefilledTransaction`),:143-153 (`ReadStatus`),:155-225
(`CBlockHeaderAndShortTxIDs`),:227-248 (`PartiallyDownloadedBlock`);
src/blockencodings.cpp:18-32 (the sender's message),:65-82 (the keys and the
short id),:84-242 (`InitData`),:244-252 (`IsTxAvailable`),:254-316
(`FillBlock`); src/hash.cpp:104-121 (`SIPROUND`),:123-200 (`CSipHasher`),
:202-236 (`SipHashUint256`); src/uint256.h:118-125 (`GetUint64`);
src/net/net_processing.cpp:2428-2449 (`sendcmpct`),:3623-3700 (`blocktxn`),
:2734-2843 (`getblocktxn`),:3744-4030 (`cmpctblock`). BIP152
(the raw form, https://raw.githubusercontent.com/bitcoin/bips/master/bip-0152.mediawiki,
read 2026-10-15T16:01:41Z; `master` is mutable, the pin is the sha256
b710fa0a...cd85): lines 42 (the differential
encoding), 100-104 (the short id), 141-142 (the reconstruction and the
collisions).
-/

namespace BsvChain.Wire
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash BsvScript.Sighash

/-! ## 1. SipHash-2-4 -/

/-- [SRC] 2026-10-15: `ROTL`, src/hash.cpp:104 at 6504a3af. -/
def sipRotl (x b : UInt64) : UInt64 := (x <<< b) ||| (x >>> (64 - b))

/-- [SRC] 2026-10-15: the four state words of `CSipHasher` (src/hash.h's
`v[4]`; src/hash.cpp:123-128 at 6504a3af). -/
structure SipState where
  v0 : UInt64
  v1 : UInt64
  v2 : UInt64
  v3 : UInt64
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: `SIPROUND`, src/hash.cpp:106-121 at 6504a3af. -/
def SipState.round (s : SipState) : SipState :=
  let v0 := s.v0 + s.v1
  let v1 := sipRotl s.v1 13
  let v1 := v1 ^^^ v0
  let v0 := sipRotl v0 32
  let v2 := s.v2 + s.v3
  let v3 := sipRotl s.v3 16
  let v3 := v3 ^^^ v2
  let v0 := v0 + v3
  let v3 := sipRotl v3 21
  let v3 := v3 ^^^ v0
  let v2 := v2 + v1
  let v1 := sipRotl v1 17
  let v1 := v1 ^^^ v2
  let v2 := sipRotl v2 32
  ⟨v0, v1, v2, v3⟩

/-- [SRC] 2026-10-15: the keyed initial state, src/hash.cpp:123-128 at 6504a3af. -/
def SipState.init (k0 k1 : UInt64) : SipState :=
  ⟨0x736f6d6570736575 ^^^ k0, 0x646f72616e646f6d ^^^ k1,
   0x6c7967656e657261 ^^^ k0, 0x7465646279746573 ^^^ k1⟩

/-- [SRC] 2026-10-15: one 64-bit word absorbed with two rounds
(`CSipHasher::Write(uint64_t)`, src/hash.cpp:130-147 at 6504a3af). -/
def SipState.absorb (s : SipState) (m : UInt64) : SipState :=
  let t := ({ s with v3 := s.v3 ^^^ m } : SipState).round.round
  { t with v0 := t.v0 ^^^ m }

/-- [SRC] 2026-10-15: `Finalize`: the last word (the tail bytes and the
length's low byte at the top), then four rounds after `v2 ^= 0xFF`
(src/hash.cpp:184-200 at 6504a3af). -/
def SipState.finish (s : SipState) (t : UInt64) : UInt64 :=
  let u := s.absorb t
  let u := ({ u with v2 := u.v2 ^^^ 0xff } : SipState).round.round.round.round
  u.v0 ^^^ u.v1 ^^^ u.v2 ^^^ u.v3

/-- [SRC] 2026-10-15: up to eight bytes as a little-endian word (the byte
writer's `t |= byte << (8 * (c % 8))`, src/hash.cpp:149-182; `GetUint64`,
src/uint256.h:118-125 at 6504a3af). -/
def sipWord (bs : Bytes) : UInt64 := (leNat bs).toUInt64

/-- [SRC] 2026-10-15: every whole eight-byte word absorbed, the tail returned
(src/hash.cpp:149-182 at 6504a3af). -/
def sipAbsorbAll : SipState → Bytes → SipState × Bytes
  | s, b0 :: b1 :: b2 :: b3 :: b4 :: b5 :: b6 :: b7 :: rest =>
    sipAbsorbAll (s.absorb (sipWord [b0, b1, b2, b3, b4, b5, b6, b7])) rest
  | s, tail => (s, tail)

/-- [SRC] 2026-10-15: SipHash-2-4 of a byte string (`CSipHasher`,
src/hash.cpp:123-200 at 6504a3af); on 32 bytes it is `SipHashUint256`
(src/hash.cpp:202-236: the four words, then the length word `4 << 59` =
`32 << 56`), as the reference's own test checks (src/test/hash_tests.cpp:142-156). -/
def sipHash24 (k0 k1 : UInt64) (msg : Bytes) : UInt64 :=
  let (s, tail) := sipAbsorbAll (SipState.init k0 k1) msg
  s.finish (sipWord tail ||| ((msg.length % 256).toUInt64 <<< 56))

/-! ## 2. The short id -/

/-- [SRC] 2026-10-15: `FillShortTxIDSelector`: the single SHA-256 of the
header and the 64-bit nonce, its words 0 and 1 the keys
(src/blockencodings.cpp:65-76 at 6504a3af; BIP152 lines 102-103). -/
def shortIdKeys (header : BlockHeader) (nonce : Nat) : UInt64 × UInt64 :=
  let h := sha256 (header.encode ++ headerWordBytes 8 nonce)
  (sipWord (h.take 8), sipWord ((h.drop 8).take 8))

/-- [SRC] 2026-10-15: `SHORTTXIDS_LENGTH` = 6 (src/blockencodings.h:164 at 6504a3af). -/
def shortIdBytes : Nat := 6

/-- [SRC] 2026-10-15: `GetShortID`: SipHash of the transaction's hash (its
internal bytes, `GetHash`, which is the id: src/primitives/transaction.h:309-310)
masked to 48 bits (src/blockencodings.cpp:78-82 at 6504a3af; BIP152 line 104). -/
def shortIdOf (keys : UInt64 × UInt64) (txHash : Bytes) : Nat :=
  (sipHash24 keys.1 keys.2 txHash).toNat % 2 ^ 48

/-! ## 3. The messages -/

/-- [SRC] 2026-10-15: `PrefilledTransaction`: the index (differential in the
message) and the transaction (src/blockencodings.h:122-141 at 6504a3af; BIP152 lines 44-53). -/
structure PrefilledTx where
  index : Nat
  tx : Tx
  deriving Repr

/-- [SRC] 2026-10-15: the writer: a CompactSize index, then the transaction
(src/blockencodings.h:131-140 at 6504a3af). -/
def PrefilledTx.encode (p : PrefilledTx) : Bytes := compactSize p.index ++ serTx p.tx

/-- [SRC] 2026-10-15: the reader; an index above 32 bits is refused
("index overflowed 32-bits", src/blockencodings.h:133-138 at 6504a3af). -/
def PrefilledTx.read (bs : Bytes) : Option (PrefilledTx × Bytes) := do
  let (n, r1) ← readVarInt bs
  if n > 0xffffffff then none else
  let (tx, r2) ← decodeTxPrefix r1
  pure (⟨n, tx⟩, r2)

/-- [SRC] 2026-10-15: `CBlockHeaderAndShortTxIDs`, the payload of
`cmpctblock`: the header, the nonce, the short ids and the prefilled
transactions (src/blockencodings.h:155-225 at 6504a3af; BIP152 lines 55-72). -/
structure CompactBlock where
  header : BlockHeader
  nonce : Nat
  shortIds : List Nat
  prefilled : List PrefilledTx
  deriving Repr

/-- [SRC] 2026-10-15: the writer: the header, the nonce (eight bytes), a
CompactSize count and six little-endian bytes per short id (the low 32 bits
then the next 16), the prefilled vector (src/blockencodings.h:188-219 at 6504a3af). -/
def CompactBlock.encode (c : CompactBlock) : Bytes :=
  c.header.encode ++ headerWordBytes 8 c.nonce ++ compactSize c.shortIds.length ++
    (c.shortIds.map (headerWordBytes shortIdBytes)).flatten ++ compactSize c.prefilled.length ++
    (c.prefilled.map PrefilledTx.encode).flatten

/-- [SRC] 2026-10-15: the reader (src/blockencodings.h:188-223 at 6504a3af);
the whole payload is the message. [D] The node ignores bytes after the
payload (`vRecv >> cmpctblock`, src/net/net_processing.cpp:3752-3753); this
reader takes the payload whole. -/
def CompactBlock.decode (bs : Bytes) : Option CompactBlock := do
  let (header, r1) ← BlockHeader.decodePrefix bs
  let (nonce, r2) ← readLE 8 r1
  let (n, r3) ← readVarInt r2
  let (shortIds, r4) ← readMany (readLE shortIdBytes) n r3
  let (m, r5) ← readVarInt r4
  let (prefilled, r6) ← readMany PrefilledTx.read m r5
  if r6 = [] then pure { header, nonce, shortIds, prefilled } else none

/-- [SRC] 2026-10-15: `BlockTxCount` (src/blockencodings.h:181-183 at 6504a3af). -/
def CompactBlock.txCount (c : CompactBlock) : Nat := c.shortIds.length + c.prefilled.length

/-- [SRC] 2026-10-15: the sender's message for a block: the coinbase
prefilled at index 0, a short id for every other transaction, in order
(src/blockencodings.cpp:18-32 and the stream form :34-63 at 6504a3af). The
nonce is the sender's random draw (`GetRand`, :19), an input here. A block
with no transaction has no message at the pin (`block.vtx.size() - 1`); the
model returns the empty one. -/
def CompactBlock.ofBlock (b : Block) (nonce : Nat) : CompactBlock :=
  let keys := shortIdKeys b.header nonce
  match b.transactions with
  | [] => { header := b.header, nonce, shortIds := [], prefilled := [] }
  | cb :: rest =>
    { header := b.header, nonce, shortIds := rest.map (fun t => shortIdOf keys (txid t)),
      prefilled := [⟨0, cb⟩] }

/-- [SRC] 2026-10-15: the writer's differential indices: each index less the
previous one plus one, the sum taken in 32 bits as the source's `uint32_t`
(src/blockencodings.h:75-79 at 6504a3af; BIP152 line 42). -/
def diffIndices : Nat → List Nat → List Nat
  | _, [] => []
  | next, i :: is => (i - next) :: diffIndices ((i + 1) % 2 ^ 32) is

/-- [SRC] 2026-10-15: the reader's absolute indices: each difference plus the
offset, refused above 32 bits ("indices overflowed 32 bits"); the offset is
the index plus one in 32 bits, so it wraps to 0 after 0xffffffff
(src/blockencodings.h:65-73 at 6504a3af). -/
def undiffIndices : Nat → List Nat → Option (List Nat)
  | _, [] => some []
  | next, d :: ds =>
    if d + next > 0xffffffff then none
    else (undiffIndices ((d + next + 1) % 2 ^ 32) ds).map ((d + next) :: ·)

/-- [SRC] 2026-10-15: one differential index, refused above 32 bits ("index
overflowed 32 bits", src/blockencodings.h:55-61 at 6504a3af). -/
def readIndex (bs : Bytes) : Option (Nat × Bytes) := do
  let (n, r) ← readVarInt bs
  if n > 0xffffffff then none else pure (n, r)

/-- [SRC] 2026-10-15: `BlockTransactionsRequest`, the payload of
`getblocktxn`: the block hash and the absolute indices
(src/blockencodings.h:36-82 at 6504a3af; BIP152 lines 74-85). -/
structure BlockTxnRequest where
  blockHash : Bytes
  indices : List Nat
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: the writer (src/blockencodings.h:46-48,74-80 at 6504a3af). -/
def BlockTxnRequest.encode (r : BlockTxnRequest) : Bytes :=
  r.blockHash ++ compactSize r.indices.length ++ ((diffIndices 0 r.indices).map compactSize).flatten

/-- [SRC] 2026-10-15: the reader (src/blockencodings.h:46-73 at 6504a3af).
[D] The node ignores bytes after the payload (`vRecv >> req`,
src/net/net_processing.cpp:2797-2798); this reader takes the payload whole. -/
def BlockTxnRequest.decode (bs : Bytes) : Option BlockTxnRequest := do
  let (blockHash, r1) ← readBytes 32 bs
  let (n, r2) ← readVarInt r1
  let (ds, r3) ← readMany readIndex n r2
  let indices ← undiffIndices 0 ds
  if r3 = [] then pure { blockHash, indices } else none

/-- [SRC] 2026-10-15: `BlockTransactions`, the payload of `blocktxn`: the
block hash and the transactions (src/blockencodings.h:84-115 at 6504a3af;
BIP152 lines 87-98). -/
structure BlockTxns where
  blockHash : Bytes
  txs : List Tx
  deriving Repr

/-- [SRC] 2026-10-15: the writer (src/blockencodings.h:96-113 at 6504a3af). -/
def BlockTxns.encode (b : BlockTxns) : Bytes :=
  b.blockHash ++ compactSize b.txs.length ++ (b.txs.map serTx).flatten

/-- [SRC] 2026-10-15: the reader (src/blockencodings.h:96-108 at 6504a3af).
[D] The node ignores bytes after the payload (`vRecv >> resp`,
src/net/net_processing.cpp:3629-3630); this reader takes the payload whole. -/
def BlockTxns.decode (bs : Bytes) : Option BlockTxns := do
  let (blockHash, r1) ← readBytes 32 bs
  let (n, r2) ← readVarInt r1
  let (txs, r3) ← readMany decodeTxPrefix n r2
  if r3 = [] then pure { blockHash, txs } else none

/-- [SRC] 2026-10-15: the payload of `sendcmpct`: the announcement flag and
the version (src/net/net_processing.cpp:1971-1981 the writer, :2428-2449 the
reader; a `bool` is one byte, nonzero read as true, src/serialize.h:264-271
at 6504a3af). The node acts on version 1 only (:2433). -/
structure SendCmpct where
  announce : Bool
  version : Nat
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: the writer (src/net/net_processing.cpp:1978-1981 at 6504a3af). -/
def SendCmpct.encode (s : SendCmpct) : Bytes :=
  headerWordBytes 1 (if s.announce then 1 else 0) ++ headerWordBytes 8 s.version

/-- [SRC] 2026-10-15: the reader (src/net/net_processing.cpp:2430-2432 at
6504a3af). [D] The node ignores bytes after the two fields; this reader
takes the payload whole. -/
def SendCmpct.decode (bs : Bytes) : Option SendCmpct := do
  let (a, r1) ← readLE 1 bs
  let (v, r2) ← readLE 8 r1
  if r2 = [] then pure { announce := a != 0, version := v } else none

/-! ## 4. The settings -/

/-- [SRC] 2026-10-15: the auxiliary settings and constants the procedure
reads, outside `NodeConfig` (docs/PARAMETERS.md section 8.11; rule 1: every
one a policy setting or a relay constant, none a validity rule).
`maxBlockTxnPercent`: `-maxblocktxnpercent`, 99 (`DEFAULT_BLOCK_TXN_MAX_PERCENT`,
src/net/net.h:137; src/init.cpp:2706): a request for more of the block's
transactions is answered with the whole block (src/net/net_processing.cpp:2744-2757).
`extraTxnCap`: `-blockreconstructionextratxn`, 100
(`DEFAULT_BLOCK_RECONSTRUCTION_EXTRA_TXN`, src/orphan_txns.h:52;
src/txn_validator.cpp:32-33): the ring of extra transactions
(src/orphan_txns.cpp:406-417). `cmpctDepth` 5 and `blockTxnDepth` 10
(`MAX_CMPCTBLOCK_DEPTH`, `MAX_BLOCKTXN_DEPTH`, src/validation.h:132,136):
deeper blocks are answered whole (src/net/net_processing.cpp:1336-1340,2818-2830).
`bucketCap` 12: a short id's hash-table bucket above it fails the message
(src/blockencodings.cpp:157-160), a property of the C++ library's table,
an explicit input (`crowded`) here. [D] `extraTxnCap`, `cmpctDepth`,
`blockTxnDepth` and `bucketCap` are carried for the census and read by no
function here: the depth answers and the ring are outside the model, the
bucket bound an input. -/
structure CompactConfig where
  maxBlockTxnPercent : Nat := 99
  extraTxnCap : Nat := 100
  cmpctDepth : Nat := 5
  blockTxnDepth : Nat := 10
  bucketCap : Nat := 12
  deriving Repr

/-! ## 5. The reconstruction -/

/-- [SRC] 2026-10-15: `ReadStatus` (src/blockencodings.h:143-153 at 6504a3af). -/
inductive ReadStatus where
  | ok | invalid | failed | checkBlockFailed
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: `MIN_TRANSACTION_SIZE`, the size of an empty
transaction (src/validation.h:67-68 at 6504a3af), as `checkBlock` reads it. -/
def minTxSize : Nat := (serTx ⟨1, [], [], 0⟩).length

/-- [SRC] 2026-10-15: `CTransaction::IsNull` (src/primitives/transaction.h:307 at 6504a3af). -/
def txIsNull (tx : Tx) : Bool := tx.inputs.isEmpty && tx.outputs.isEmpty

/-- [SRC] 2026-10-15: `CBlockHeader::IsNull` (src/primitives/block.h:60 at 6504a3af). -/
def headerIsNull (h : BlockHeader) : Bool := h.bits == 0

/-- [SRC] 2026-10-15: `PartiallyDownloadedBlock`: the header and the
available transactions by position (src/blockencodings.h:227-248 at 6504a3af). -/
structure PartialBlock where
  header : BlockHeader
  avail : List (Option Tx)
  deriving Repr

/-- [SRC] 2026-10-15: the prefilled transactions placed: a null transaction
is invalid; the absolute index is the previous one plus the differential
index plus one, refused above 32 bits or beyond the short ids and the
prefilled so far (src/blockencodings.cpp:107-129 at 6504a3af). `next` is the
previous absolute index plus one. -/
def placePrefilled (nShort : Nat) : Nat → Nat → List PrefilledTx → List (Option Tx) →
    Except ReadStatus (List (Option Tx))
  | _, _, [], avail => .ok avail
  | i, next, p :: ps, avail =>
    if txIsNull p.tx then .error .invalid
    else
      let pos := next + p.index
      if pos > 0xffffffff then .error .invalid
      else if pos > nShort + i then .error .invalid
      else placePrefilled nShort (i + 1) (pos + 1) ps (avail.set pos (some p.tx))

/-- [D] 2026-10-15: the empty positions from `j` on, in order. -/
def emptySlotsFrom : Nat → List (Option Tx) → List Nat
  | _, [] => []
  | j, none :: r => j :: emptySlotsFrom (j + 1) r
  | j, some _ :: r => emptySlotsFrom (j + 1) r

/-- [SRC] 2026-10-15: the empty positions: the positions each short id takes
in turn (the `index_offset` walk, src/blockencodings.cpp:139-145) and the
indices of `getblocktxn` (`IsTxAvailable`, :244-252;
src/net/net_processing.cpp:3919-3924 at 6504a3af). -/
def emptySlots (avail : List (Option Tx)) : List Nat := emptySlotsFrom 0 avail

/-- [SRC] 2026-10-15: the scan's state: the available transactions, the
matched marks (`have_txn`) and the matched count (`mempool_count`)
(src/blockencodings.cpp:171-234 at 6504a3af). -/
structure Scan where
  avail : List (Option Tx)
  seen : List Bool
  count : Nat
  deriving Repr

/-- [SRC] 2026-10-15: one pool transaction (src/blockencodings.cpp:173-191 at
6504a3af): its short id looked up; an unmatched position takes it; a
position matched before is emptied (two pool transactions on one short id:
"just request it") and stays matched. -/
def Scan.poolStep (sid : Bytes → Nat) (table : List (Nat × Nat)) (s : Scan) (tx : Tx) : Scan :=
  match table.lookup (sid (txid tx)) with
  | none => s
  | some j =>
    if !(s.seen.getD j false) then
      { avail := s.avail.set j (some tx), seen := s.seen.set j true, count := s.count + 1 }
    else if (s.avail.getD j none).isSome then
      { s with avail := s.avail.set j none, count := s.count - 1 }
    else s

/-- [SRC] 2026-10-15: one extra transaction (src/blockencodings.cpp:201-226
at 6504a3af): as a pool transaction, except that a position already holding
a transaction of the same hash is left as it is. -/
def Scan.extraStep (sid : Bytes → Nat) (table : List (Nat × Nat)) (s : Scan) (tx : Tx) : Scan :=
  match table.lookup (sid (txid tx)) with
  | none => s
  | some j =>
    if !(s.seen.getD j false) then
      { avail := s.avail.set j (some tx), seen := s.seen.set j true, count := s.count + 1 }
    else match s.avail.getD j none with
      | some t => if txid t != txid tx then { s with avail := s.avail.set j none, count := s.count - 1 } else s
      | none => s

/-- [SRC] 2026-10-15: a scan with the source's early exit after every
transaction once the count reaches the number of short ids
(src/blockencodings.cpp:192-197,228-233 at 6504a3af). -/
def Scan.run (step : Scan → Tx → Scan) (size : Nat) : Scan → List Tx → Scan
  | s, [] => s
  | s, tx :: rest =>
    let s' := step s tx
    if s'.count = size then s' else Scan.run step size s' rest

/-- [SRC] 2026-10-15: `InitData` (src/blockencodings.cpp:84-242 at
6504a3af), from a fresh object (the re-initialisation refusal at :97-102 is
the caller's). The checks in the source's order: a null header or an empty
message, more transactions than the block size allows (INVALID); the
prefilled placement (INVALID); a crowded bucket (`crowded`, an input) or two
equal short ids (FAILED, "Short ID collision"); then the pool's
transactions and the extra transactions. `pool` is the mempool's
transactions in its iteration order (`GetTransactions`); `extra` the ring of
`GetCompactExtraTxns` in its order (src/net/net.cpp:3569-3571). [D] The
model lists the filled entries only; an unfilled slot (zero hash, no
transaction: the ring is sized when the empty ring is written, src/orphan_txns.cpp:410-414,
and returned whole, :162-165; `InitData` reads it, src/blockencodings.cpp:201-210)
whose short id met one of the message's would mark the position held with
no transaction, a case of probability 2^-48 per short id not modeled. -/
def initData (maxBlockSize : Nat) (c : CompactBlock) (pool extra : List Tx)
    (crowded : Bool := false) : Except ReadStatus PartialBlock := do
  if headerIsNull c.header || (c.shortIds.isEmpty && c.prefilled.isEmpty) then throw .invalid
  if c.txCount > maxBlockSize / minTxSize then throw .invalid
  let avail ← placePrefilled c.shortIds.length 0 0 c.prefilled (List.replicate c.txCount none)
  if crowded then throw .failed
  if !(decide c.shortIds.Nodup) then throw .failed
  let table := c.shortIds.zip (emptySlots avail)
  let sid := shortIdOf (shortIdKeys c.header c.nonce)
  let size := c.shortIds.length
  let s0 : Scan := { avail, seen := List.replicate c.txCount false, count := 0 }
  let s1 := Scan.run (Scan.poolStep sid table) size s0 pool
  let s2 := Scan.run (Scan.extraStep sid table) size s1 extra
  pure { header := c.header, avail := s2.avail }

/-- [SRC] 2026-10-15: the positions the receiver asks for with
`getblocktxn` (src/net/net_processing.cpp:3919-3924 at 6504a3af). -/
def PartialBlock.missing (p : PartialBlock) : List Nat := emptySlots p.avail

/-- [SRC] 2026-10-15: the block's transactions, the missing ones taken in
order; `none` when they run out; the leftover returned
(src/blockencodings.cpp:267-278 at 6504a3af). -/
def fillTxs : List (Option Tx) → List Tx → Option (List Tx × List Tx)
  | [], ms => some ([], ms)
  | some t :: rest, ms => (fillTxs rest ms).map fun (ts, r) => (t :: ts, r)
  | none :: _, [] => none
  | none :: rest, m :: ms => (fillTxs rest ms).map fun (ts, r) => (m :: ts, r)

/-- [SRC] 2026-10-15: `FillBlock` (src/blockencodings.cpp:254-316 at
6504a3af): too few or too many missing transactions are INVALID; the block
then goes through `CheckBlock` (#63's `checkBlock`, default options): a
failure that may be corruption (a wrong merkle root, a mutated tree: the
possible short-id collision) is FAILED, any other CHECKBLOCK_FAILED. -/
def fillBlock (params : ChainParams) (cfg : NodeConfig) (height : Nat) (p : PartialBlock)
    (vtxMissing : List Tx) : Except ReadStatus Block := do
  if headerIsNull p.header then throw .invalid
  let some (txs, left) := fillTxs p.avail vtxMissing | throw .invalid
  unless left.isEmpty do throw .invalid
  let b : Block := ⟨p.header, txs⟩
  match checkBlock params cfg b height with
  | .ok _ => pure b
  | .error r => throw (if r.corruptionPossible then .failed else .checkBlockFailed)

/-- [SRC] 2026-10-15: what the receiver of a requested `cmpctblock` does
next (src/net/net_processing.cpp:3903-3935 at 6504a3af): INVALID scores 100
("invalid-cmpctblk"); FAILED asks for the whole block (`getdata`
`MSG_BLOCK`, no score: BIP152 line 142, collisions are never penalized); a
missing set asks for it with `getblocktxn`; none missing fills the block at
once (the empty `blocktxn`, :3925-3931). -/
inductive CompactAnswer where
  | misbehaving (score : Nat) (reason : String)
  | getBlock
  | getBlockTxn (indices : List Nat)
  | fill (p : PartialBlock)
  deriving Repr

/-- [SRC] 2026-10-15: the receiver's answer from `InitData`'s result
(src/net/net_processing.cpp:3903-3935 at 6504a3af). -/
def answerOf : Except ReadStatus PartialBlock → CompactAnswer
  | .error .invalid => .misbehaving 100 "invalid-cmpctblk"
  | .error _ => .getBlock
  | .ok p => if p.missing.isEmpty then .fill p else .getBlockTxn p.missing

/-- [SRC] 2026-10-15: the sender's choice for `getblocktxn`
(src/net/net_processing.cpp:2744-2783 at 6504a3af): more than the setting's
percentage of the block's transactions is answered with the block; an index
out of range scores 100 ("out-of-bound-tx-index"); otherwise `blocktxn`
with the requested transactions in order. [D] The source compares a
`double`, `(k / n) * 100 > p` (:2748-2750); the integer form
`k * 100 > p * n` agrees with it at the default 99 for every block of up to
2,000,000 transactions (lens-s7-79, [X] 2026-10-15) and differs at other
settings: at p = 7, k = 7, n = 100 the double reads 7.000000000000001 and the
source answers with the whole block where this function answers `blocktxn`. -/
def answerGetBlockTxn (cfg : CompactConfig) (b : Block) (r : BlockTxnRequest) :
    Option BlockTxns ⊕ Option Block :=
  let n := b.transactions.length
  if n > 0 && r.indices.length * 100 > cfg.maxBlockTxnPercent * n then .inr (some b)
  else match r.indices.mapM (fun i => b.transactions[i]?) with
    | some txs => .inl (some { blockHash := r.blockHash, txs })
    | none => .inl none

end BsvChain.Wire
