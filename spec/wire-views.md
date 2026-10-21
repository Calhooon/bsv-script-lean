# Client wire formats as views: EF, BUMP, BEEF, Atomic BEEF and the TSC proof (#86)

[M] 62 theorems on this page; `#print axioms` lists every one in `lean/AxiomCheck.lean`.

[M] 2026-10-15. Generated from `lean/BsvChain/Views/Wire/*.lean`. Every codec here is a client encoding, never a rule: no consensus or policy rule of the node reads any of these formats. Each format has a codec, two round trips (parse after serialize on well-formed values, serialize after parse on byte-valued input) and a function to the machine's objects. The corpus is [`corpus/wire/`](../corpus/wire/) (mainnet-derived, read only); the engines' runs and their witnesses are in the conformance record named by `corpus/INDEX.md`.

## `BsvChain.Views.Wire.Bytes`


[M] 2026-10-15 (#86). The five wire views (`EF`, `BUMP`, `BEEF`,
`AtomicBEEF`, `TSC`) are client encodings. They are views, never rules: no
consensus or policy rule of the node reads any of them, and nothing here
changes a verdict of the machine. Each view has a codec, two round trips and a
function to the machine's objects (a transaction, its spent outputs, its
ancestry, a merkle path of #65).

This module holds the reverse direction of the readers the views share:
"serialize after parse is the identity on byte-valued input". #68 G4
(`decodeTxPrefix_serTx`) proved the forward direction (parse after
serialize); the lemmas below prove the other one for `readBytes`, `readLE`,
`readVarInt`, `readMany`, the input and output readers and the transaction
prefix decoder. The CompactSize reader refuses non-canonical encodings
([SRC] src/serialize.h:315-335 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b),
which is what makes this direction an identity: one value has one encoding.
Every BRC of the views says "VarInt" for its counts and lengths; this spec
reads that as the node's CompactSize, canonical form included [D], and records
an engine that accepts a non-canonical form as a divergence with its witness.

### Definitions

#### `expectTag` (def)

[D] 2026-10-15: consume a fixed byte tag (a version word, a marker or a
prefix) from the front of a byte string.

#### `readByte` (def)

[D] 2026-10-15: a byte of a byte-valued string, read as a one-byte field.

### Theorems

#### `byteValued_append`

[D] 2026-10-15: byte-valuedness splits over a concatenation.

#### `byteValued_cons`

[D] 2026-10-15: the tail of a byte-valued string is byte-valued.

#### `readBytes_inv`

[D] 2026-10-15: a successful `readBytes` splits its input: the bytes taken,
then the rest. [SRC] src/serialize.h:786-792 at 6504a3af.

#### `readLE_inv`

[D] 2026-10-15: a successful little-endian read of byte-valued input is
the fixed-width word of its value, below `256 ^ n`, then the rest.
[SRC] src/serialize.h:71-91 at 6504a3af.

#### `compactSize2_eq`

[D] 2026-10-15: the 2-byte CompactSize body is the 2-byte word.

#### `readVarInt_inv`

[D] 2026-10-15: CompactSize after a successful canonical read of byte-valued
input gives the input back: the reader accepts exactly the writer's encodings.
[SRC] src/serialize.h:296-335 at 6504a3af.

#### `readMany_inv`

[D] 2026-10-15: `readMany` after a reader whose every success is undone by
its writer is undone by the concatenated writer; the count is the length.
[SRC] src/serialize.h:794-804,823-840 at 6504a3af.

#### `readTxIn_inv`

[D] 2026-10-15: an input read from byte-valued bytes writes back to them.
[SRC] src/primitives/transaction.h:60-66,151-157 at 6504a3af.

#### `readTxOut_inv`

[D] 2026-10-15: an output read from byte-valued bytes writes back to them.
[SRC] src/primitives/transaction.h:189-194 at 6504a3af.

#### `serVersion_toInt32`

[D] 2026-10-15: the signed reading of a 32-bit word serializes back to it.

#### `serTx_decodeTxPrefix`

[M] 2026-10-15, #86 (the transaction codec's reverse round trip). A
transaction read from the front of byte-valued bytes serializes back to the
bytes it consumed: `serTx tx ++ rest = bs`. With #68 G4 this makes the raw
transaction format a bijection between well-formed transactions and the
byte strings the decoder accepts. Premise: the input is byte-valued.
[SRC] src/primitives/transaction.h:233-252 and src/serialize.h:71-116,296-340,786-840 at 6504a3af.

#### `decodeTx_serTx`

[D] 2026-10-15: exact framing in both directions: the exact decoder reads a
well-formed transaction's serialization, and the bytes it accepts are that
serialization. [SRC] src/core_read.cpp:184-191 at 6504a3af (`DecodeHexTx`
refuses trailing bytes).

#### `serTx_decodeTx`

[M] 2026-10-15, #86: the exact transaction decoder's accepted bytes are the
serialization of what it reads. Premise: the input is byte-valued.

#### `expectTag_append`

[D] 2026-10-15: a tag is consumed from the front of its own bytes.

#### `expectTag_inv`

[D] 2026-10-15: a consumed tag and the rest give the input back.

#### `readByte_inv`

[D] 2026-10-15: a read byte and the rest give the input back.

## `BsvChain.Views.Wire.EF`


[M] 2026-10-15 (#86). [LIT] BRC-30 "Transaction Extended Format (EF)",
bsv-blockchain/BRCs at 5333fd449c70fd5982029876376dcf1ed9c64ffe,
`transactions/0030.md` (read 2026-10-15T03:25:54Z from
https://raw.githubusercontent.com/bsv-blockchain/BRCs/5333fd449c70fd5982029876376dcf1ed9c64ffe/transactions/0030.md,
9663 bytes, sha256 `395fa0566fcae8e2c5478a03b8a500034553fbce634f48c6df114c8c828dab44`).
Views, never rules: EF is a client encoding of a transaction with the outputs
its inputs spend; no node rule reads it.

The layout (0030.md:36-44, :60-69): the version (4 bytes), the marker
`0000000000EF` (6 bytes, :39), the input count (VarInt), the extended inputs,
the output count (VarInt), the outputs, the lock time (4 bytes). An extended
input (:60-69) is the plain input (previous hash 32 bytes, previous index 4,
script length VarInt, script, sequence 4) followed by the spent output's value
and its locking script (length VarInt, then the script).

**The value width: the text and the engines disagree.** The table at
0030.md:67 gives "Previous TX satoshi output ... 4 bytes". Every engine read
for this view writes and reads 8 bytes, the width of `CTxOut::nValue`
([SRC] src/primitives/transaction.h:175-194 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b):
bsv-rs 0.5.0 `src/transaction/transaction.rs:261` (`read_u64_le`), go-sdk
v1.7.2 `transaction/input.go:125-131`, @bsv/sdk 3.0.0
`packages/sdk/src/transaction/Transaction.ts:388`. The codec below
reads 8 bytes, the named parameter `efValueWidth`, and the record carries the
text's 4 as a documentation divergence; the mainnet-derived corpus is
written by the engines' width. [D]

The marker is chosen so that a reader of the plain format sees a transaction
with no inputs, no outputs and a lock time, and stops before the rest
(0030.md:46, :73); `ef_legacy_reading` below states what the machine's own
decoder reads from an EF stream.

### Definitions

#### `efMarker` (def)

[LIT] 2026-10-15: the EF marker `0000000000EF` (BRCs 5333fd4 transactions/0030.md:39).

#### `efValueWidth` (def)

[D] 2026-10-15: the width of the spent output's value in an extended input:
8 bytes, the engines' width and `CTxOut::nValue`'s; the BRC text at 0030.md:67
says 4 (the divergence of the module docstring).

#### `EfInput` (structure)

[LIT] 2026-10-15: an extended input: the plain input, then the value and the
locking script of the output it spends (0030.md:60-69).

#### `EfTx` (structure)

[LIT] 2026-10-15: an EF transaction (0030.md:36-44).

#### `serEfInput` (def)

[LIT] 2026-10-15: an extended input's bytes.

#### `EfTx.encode` (def)

[LIT] 2026-10-15: the EF bytes: version, marker, inputs, outputs, lock time.

#### `readEfInput` (def)

[LIT] 2026-10-15: read one extended input.

#### `EfTx.decodePrefix` (def)

[LIT] 2026-10-15: read an EF transaction from the front of a byte string; a
missing or different marker is refused.

#### `EfTx.decode` (def)

[LIT] 2026-10-15: exactly one EF transaction, trailing bytes refused.

#### `EfTx.tx` (def)

[D] 2026-10-15: the transaction an EF carries: the plain inputs, the outputs.

#### `EfTx.spent` (def)

[D] 2026-10-15: the outputs the inputs spend, in input order: the coins the
evaluator needs for each input's locking script and the sighash's value.

#### `EfTx.ofTx` (def)

[D] 2026-10-15: the EF of a transaction and the outputs it spends.

#### `EfInputWellFormed` (def)

[D] 2026-10-15: an extended input whose fields fit their wire widths.

#### `EfWellFormed` (def)

[D] 2026-10-15: a well-formed EF transaction: #68's transaction conditions
over the plain fields, and well-formed extended inputs.

### Theorems

#### `readEfInput_serEfInput`

[D] 2026-10-15: an extended input reads back from its bytes.

#### `serEfInput_readEfInput`

[D] 2026-10-15: an extended input read from byte-valued bytes writes back.

#### `ef_decodePrefix_encode`

[M] 2026-10-15, #86 (EF, parse after serialize). For every well-formed EF
transaction the decoder reads the encoder's bytes back exactly and leaves any
following stream untouched. Premise: `wf`, the field widths of #68's G4 and
of the extended fields. [LIT] BRC-30 at 5333fd4, 0030.md:36-69.

#### `ef_encode_decodePrefix`

[M] 2026-10-15, #86 (EF, serialize after parse). An EF transaction read
from the front of byte-valued bytes encodes back to exactly the bytes read.
Premise: the input is byte-valued. [LIT] BRC-30 at 5333fd4, 0030.md:36-69.

#### `ef_decode_encode`

[M] 2026-10-15, #86: the exact EF decoder and the encoder are inverse:
`decode (encode t) = some t` for well-formed `t`, and `encode t = bs` whenever
`decode bs = some t` on byte-valued `bs`.

#### `ef_encode_decode`

[M] 2026-10-15, #86: the exact EF decoder's accepted bytes are the encoding
of what it reads. Premise: the input is byte-valued.

#### `ef_ofTx_tx_spent`

[M] 2026-10-15, #86 (the projection is a section). The EF built from a
transaction and as many spent outputs as it has inputs projects back to that
transaction and those outputs. Premise: one spent output per input.

#### `ef_legacy_reading`

[M] 2026-10-15, #86 (BRC-30's backward-compatibility sentence, 0030.md:46
and :73, as a theorem of the machine's own decoder). The transaction prefix
decoder reads the front of every well-formed EF stream as a transaction with
the EF's version, no inputs, no outputs and the lock time `0xEF000000`
(the marker's last four bytes, little-endian), and leaves a non-empty rest; so
the exact decoder `decodeTx` refuses every EF stream. Premise: `wf`.
[SRC] src/primitives/transaction.h:233-252 at 6504a3af; [LIT] BRC-30 at 5333fd4.

#### `ef_not_plain`

[M] 2026-10-15, #86: the exact transaction decoder refuses every well-formed
EF stream (the corollary of `ef_legacy_reading`).

## `BsvChain.Views.Wire.BUMP`


[M] 2026-10-15 (#86). [LIT] BRC-74 "BSV Unified Merkle Path (BUMP)
Format", bsv-blockchain/BRCs at 5333fd449c70fd5982029876376dcf1ed9c64ffe,
`transactions/0074.md` (read 2026-10-15T03:25:54Z from
https://raw.githubusercontent.com/bsv-blockchain/BRCs/5333fd449c70fd5982029876376dcf1ed9c64ffe/transactions/0074.md,
18597 bytes, sha256 `0cd56c0f9e6b31a2500899b1791abcf15b216cb4aeb7576608b3cc19942d6aad`).
Views, never rules: a BUMP is a client encoding of one or more merkle paths
of #65 in one block; its verification is `verifyPath` of #65 through the
node list of #75 (`markerPath`, `tscPath`).

The layout (0074.md:45-77): the block height (VarInt, :50), the tree height
(1 byte, "max 64", :51), then per level the leaf count (VarInt, :58) and the
leaves; a leaf is the offset (VarInt, :66), the flags byte (:67) and a
32-byte hash unless the flags say duplicate (:68). The flags table (:73-77):
`00` data follows, not a client txid; `01` nothing follows, duplicate the
working hash; `02` data follows, a client txid. This codec reads exactly the
three values of the table and refuses every other flags byte; the reference
JavaScript of the BRC (:289-296) and the three engines read the flags as bits
(`flags & 1` duplicate, else `flags & 2` client), so `04` and above are read
by them and refused here (the conformance record's `bump-028`); `03`, the
duplicate bit with the client bit, they read as a duplicate (`bump-027`).
A tree height above 64 is refused (:51). Hashes are internal-order words; the
JSON form (:158-261) and the hex display order are the reversed words.

**The projection.** A path for the leaf at offset `index` takes, at each level
`h` below the tree height, the leaf at the sibling offset of `index / 2^h`
(:326-345, `calculateMerkleRootFromBUMP`); a duplicate is the marker of #75.
A leaf the BUMP omits is computed from the level below when both children are
present (the engines' reading: @bsv/sdk 3.0.0 `MerklePath.ts:421` (`findOrComputeLeaf`),
the text "only include branches of the tree which are required", :15); the
BRC's reference function throws instead (:335). A one-level BUMP of one leaf is
the lone transaction of its block, whose root is the leaf itself (@bsv/sdk
3.0.0 `MerklePath.ts:390` ("special case for blocks with only one
transaction"); ts-stack 4d0ea63c, identical at edf6e03d); #75 records that the
node serves no proof for that case.

### Definitions

#### `BumpNode` (inductive)

[LIT] 2026-10-15: a leaf's content by its flags byte (0074.md:73-77).

#### `BumpLeaf` (structure)

[LIT] 2026-10-15: a leaf: its offset from the left of its level and its content.

#### `Bump` (structure)

[LIT] 2026-10-15: a BUMP: the block height and the levels from the leaves
upward; the tree height is the number of levels (0074.md:48-59).

#### `bumpMaxTreeHeight` (def)

[LIT] 2026-10-15: the tree height's bound, "max 64" (0074.md:51).

#### `BumpNode.flags` (def)

[LIT] 2026-10-15: the flags byte of a leaf (0074.md:73-77).

#### `encodeBumpLeaf` (def)

[LIT] 2026-10-15: a leaf's bytes: offset, flags, the hash unless duplicate.

#### `encodeBumpLevel` (def)

[LIT] 2026-10-15: a level's bytes: the leaf count, the leaves.

#### `Bump.encode` (def)

[LIT] 2026-10-15: the BUMP bytes: block height, tree height, the levels.

#### `readBumpLeaf` (def)

[LIT] 2026-10-15: read one leaf; a flags byte outside the table is refused.

#### `readBumpLevel` (def)

[LIT] 2026-10-15: read one level: the count, then the leaves.

#### `Bump.decodePrefix` (def)

[LIT] 2026-10-15: read a BUMP from the front of a byte string; a tree height
above 64 is refused.

#### `Bump.decode` (def)

[LIT] 2026-10-15: exactly one BUMP, trailing bytes refused.

#### `BumpLeafWellFormed` (def)

[D] 2026-10-15: a leaf whose offset fits CompactSize and whose word is 32 bytes.

#### `BumpLevelWellFormed` (def)

[D] 2026-10-15: a well-formed level.

#### `BumpWellFormed` (def)

[D] 2026-10-15: a well-formed BUMP: a CompactSize block height, at most 64
levels, well-formed levels.

#### `BumpNode.word?` (def)

[LIT] 2026-10-15: the word a leaf carries, none for a duplicate.

#### `BumpNode.toTsc` (def)

[D] 2026-10-15: a BUMP node as a node of #75's list: a word, or the marker.

#### `BumpNode.ofTsc` (def)

[D] 2026-10-15: a #75 node as a BUMP node (not a client txid).

#### `sibOffset` (def)

[LIT] 2026-10-15: the sibling offset, `offset ^ 1` (0074.md:333).

#### `Bump.findLeaf` (def)

[LIT] 2026-10-15: the leaf a level lists at an offset (0074.md:334).

#### `Bump.nodeAt` (def)

[D] 2026-10-15: the node at a level and offset: listed, or computed from
the two children below when the left is a word and the right a word or the
duplicate marker. [SRC] @bsv/sdk 3.0.0 `src/transaction/MerklePath.ts:421`
(`findOrComputeLeaf`; ts-stack 4d0ea63c, identical at edf6e03d).

#### `Bump.pathFrom` (def)

[D] 2026-10-15: the node list from level `h` for `count` levels.

#### `Bump.pathFor` (def)

[D] 2026-10-15: the path of #75's nodes for the leaf at `index`, one node per
level; a lone leaf in a one-level BUMP has the empty path.

#### `bumpFold` (def)

[LIT] 2026-10-15: BRC-74's root calculation (0074.md:326-345,
`calculateMerkleRootFromBUMP`): a duplicate hashes the working hash with
itself; a word is hashed with the working hash in the order the offset gives,
literally. #65's `computeRootFromBranch` (the node's `ComputeMerkleRootFromBranch`)
also reads an all-zero word as the duplicate marker; `bumpFold_eq` proves the
two agree on every node list without a zero word.

#### `Bump.rootFor` (def)

[LIT] 2026-10-15: the root a leaf word computes at `index`: BRC-74's
calculation over the leaf's path (`bumpFold`).

#### `Bump.clientTxids` (def)

[LIT] 2026-10-15: the client txids of a BUMP with their offsets: the level-0
leaves flagged `02` (0074.md:77).

#### `Bump.indexOf` (def)

[LIT] 2026-10-15: the offset of a word among the level-0 leaves (BRC-62's
validation step "Lookup the txid within level 0 leaves", 0062.md:179).

#### `Bump.leafRoots` (def)

[D] 2026-10-15: the roots every level-0 word computes, in level order;
`none` when one of them has no path.

#### `Bump.root` (def)

[D] 2026-10-15: the BUMP's root: the common root of every level-0 word,
`none` when a word has no path, when the roots differ, or when there is no word.
This is the check the engines run on construction (the conformance record).

#### `Bump.ofTsc` (def)

[D] 2026-10-15: the single-path BUMP of a leaf, its index and #75's node
list: level 0 holds the leaf (a client txid) and its sibling in offset order,
each level above holds the sibling node of that level.

### Theorems

#### `readBumpLeaf_encode`

[D] 2026-10-15: a well-formed leaf reads back from its bytes.

#### `readBumpLevel_encode`

[D] 2026-10-15: a well-formed level reads back from its bytes.

#### `bump_decodePrefix_encode`

[M] 2026-10-15, #86 (BUMP, parse after serialize). For every well-formed
BUMP the decoder reads the encoder's bytes back exactly and leaves any
following stream untouched. Premise: `wf` (CompactSize fields, at most 64
levels, 32-byte words). [LIT] BRC-74 at 5333fd4, 0074.md:45-77.

#### `encodeBumpLeaf_read`

[D] 2026-10-15: a leaf read from byte-valued bytes writes back.

#### `encodeBumpLevel_read`

[D] 2026-10-15: a level read from byte-valued bytes writes back.

#### `bump_encode_decodePrefix`

[M] 2026-10-15, #86 (BUMP, serialize after parse). A BUMP read from the
front of byte-valued bytes encodes back to exactly the bytes read: one BUMP
value has one encoding, leaf order included (no engine-side sorting is part
of the format). Premise: the input is byte-valued. [LIT] BRC-74 at 5333fd4.

#### `bump_decode_encode`

[M] 2026-10-15, #86: the exact BUMP decoder and the encoder are inverse.

#### `bump_encode_decode`

[M] 2026-10-15, #86: the exact BUMP decoder's accepted bytes are the encoding
of what it reads, leaf order included. Premise: the input is byte-valued.

#### `bumpFold_eq`

[M] 2026-10-15, #86 (BRC-74's root and #65's). On a node list with no
all-zero hash word, BRC-74's literal root and #65's `computeRootFromBranch`
over the marker path are the same function of the leaf and the index. Premise:
no hash node is the zero word (an all-zero SHA256d output); with one, the node's
reading takes it as the marker and BRC-74 hashes it (the conformance record's
witness of the zero word). [SRC] src/consensus/merkle.cpp:291-310 at 6504a3af.

#### `toTsc_ofTsc`

[D] 2026-10-15: a #75 node survives the BUMP node and back.

#### `sibOffset_ne`

[D] 2026-10-15: no offset is its own sibling.

#### `pathFrom_upper`

[D] 2026-10-15: the levels above level 0 of `ofTsc` list the sibling node.

#### `pathFor_ofTsc`

[M] 2026-10-15, #86 (BUMP and #75). The single-path BUMP built from a leaf,
its index and a node list returns exactly that node list as the leaf's path;
so its root for the leaf is the root #75's proof computes, and #65's
`verifyPath` decides both alike. No premise: every node list and index.

#### `rootFor_ofTsc`

[M] 2026-10-15, #86: the root of a #75 proof's BUMP for its leaf is BRC-74's
root over the proof's nodes, and, when no hash node is the zero word, the root
#65's `computeRootFromBranch` gives over the proof's marker path. Premise of the
second part: no zero hash word (`bumpFold_eq`).

## `BsvChain.Views.Wire.BEEF`


[M] 2026-10-15 (#86). [LIT] BRC-62 "Background Evaluation Extended
Format (BEEF) Transactions", bsv-blockchain/BRCs at
5333fd449c70fd5982029876376dcf1ed9c64ffe, `transactions/0062.md` (read
2026-10-15T03:25:54Z from
https://raw.githubusercontent.com/bsv-blockchain/BRCs/5333fd449c70fd5982029876376dcf1ed9c64ffe/transactions/0062.md,
15674 bytes, sha256 `7fdee54fa863a3787143ba86a076e1b790d9d9d0584059aa156214fea828a313`),
and BRC-96 "BEEF V2, Txid Only Extension", `transactions/0096.md` at the same
commit (read 2026-10-15T03:27:47Z from
https://raw.githubusercontent.com/bsv-blockchain/BRCs/5333fd449c70fd5982029876376dcf1ed9c64ffe/transactions/0096.md,
4635 bytes, sha256 `9b4b11fdb28c5ec66332cb3260716f82d61318e9dc376aba730fef903a577283`).
Views, never rules: a BEEF carries transactions with their ancestry and the
merkle paths (BUMPs) of the mined ones; its validation process (0062.md:172-191)
is a client's, and nothing here changes a verdict of the machine.

**Version 1** (0062.md:59-69): the version 4022206465 as 4 little-endian bytes
(`0100BEEF`), the BUMP count (VarInt) and the BUMPs (BRC-74), the transaction
count (VarInt), then per transaction the raw transaction (BRC-12), the
"Has BUMP" byte (`01` or `00`, :68) and, after `01`, the BUMP index (VarInt, :69).
**Version 2** (0096.md:46-61): the version 4022206466 (`0200BEEF`), the same
BUMP section, then per transaction the "Tx Data Format" byte, ahead of the body
(:48-50): `00` a raw transaction without a BUMP index, `01` the BUMP index
(VarInt) then the raw transaction, `02` a 32-byte txid only (:58-61).
This codec reads exactly the byte values the two tables name and refuses
every other; it does not check that a BUMP index is in range (the grammar has
no such field); the view `Beef.objects` does, and returns `none` when a
mined transaction's BUMP is missing or does not list its txid.

### Definitions

#### `BeefVersion` (inductive)

[LIT] 2026-10-15: the two BEEF versions (0062.md:59; 0096.md:46).

#### `BeefVersion.word` (def)

[LIT] 2026-10-15: the version words: 4022206465 (`0100BEEF`, 0062.md:59,63)
and 4022206466 (`0200BEEF`, 0096.md:46,54).

#### `BeefEntry` (inductive)

[LIT] 2026-10-15: one transaction entry: a raw transaction with an optional
BUMP index, or (version 2 only) a txid alone (0096.md:58-61).

#### `Beef` (structure)

[LIT] 2026-10-15: a BEEF: its version, its BUMPs, its transactions in order.

#### `encodeHasBump` (def)

[LIT] 2026-10-15: version 1's "Has BUMP" byte and index (0062.md:68-69).

#### `encodeBeefEntry` (def)

[LIT] 2026-10-15: one entry's bytes under a version. A txid-only entry has
no version-1 form (the well-formedness below excludes it there).

#### `Beef.encode` (def)

[LIT] 2026-10-15: the BEEF bytes.

#### `readBeefVersion` (def)

[LIT] 2026-10-15: read the version word; any other word is refused.

#### `readBeefEntryV1` (def)

[LIT] 2026-10-15: read a version-1 entry: the transaction, then `00`, or
`01` and the index; any other byte is refused.

#### `readBeefEntryV2` (def)

[LIT] 2026-10-15: read a version-2 entry: the format byte, then its body;
any other format byte is refused.

#### `readBeefEntry` (def)

[LIT] 2026-10-15: the entry reader of a version.

#### `Beef.decodePrefix` (def)

[LIT] 2026-10-15: read a BEEF from the front of a byte string.

#### `Beef.decode` (def)

[LIT] 2026-10-15: exactly one BEEF, trailing bytes refused.

#### `BeefEntryWellFormed` (def)

[D] 2026-10-15: a well-formed entry under a version: #68's transaction
conditions, a CompactSize index, a 32-byte txid that only version 2 carries.

#### `BeefWellFormed` (def)

[D] 2026-10-15: a well-formed BEEF.

#### `BeefEntry.txid` (def)

[LIT] 2026-10-15: an entry's txid: the hash of the raw transaction, or the
word a txid-only entry carries (0062.md:176; 0096.md:61).

#### `BeefObject` (inductive)

[D] 2026-10-15: what a BEEF says of one of its transactions: mined, with the
block height and #75's node path at its level-0 offset in its BUMP; unmined
(validated through its parents, 0062.md:183-187); or known by its txid alone
(0096.md:65-67).

#### `Beef.object` (def)

[D] 2026-10-15: the object of an entry: a BUMP index resolves to that BUMP,
the txid to its level-0 offset (0062.md:179) and the offset to a path; `none`
when the BUMP is missing, does not list the txid, or has no path for it.

#### `Beef.objects` (def)

[D] 2026-10-15: every entry's txid and object, in BEEF order.

#### `BeefEntry.parents` (def)

[D] 2026-10-15: the txids an entry spends from (its inputs' previous hashes).

#### `Beef.find` (def)

[D] 2026-10-15: the entry with a txid, the earliest.

#### `Beef.closure` (def)

[D] 2026-10-15: the closure of a set of txids under "a parent present in the
BEEF", with fuel: one round per entry suffices.

#### `Beef.ancestorsOf` (def)

[D] 2026-10-15: the txids of a subject and its ancestors in the BEEF.

#### `Beef.subjectTx` (def)

[D] 2026-10-15: the raw transaction a BEEF carries under a txid, the earliest
entry with that txid; `none` when it is absent or txid-only.

#### `Beef.ancestry` (def)

[D] 2026-10-15: the transaction with its ancestry: the subject transaction
(a raw entry whose txid is the word) and the object of every entry in its
ancestry, in BEEF order. `none` when the subject is absent or txid-only, or
when an object fails.

#### `Beef.ordered` (def)

[LIT] 2026-10-15: BRC-62's ordering (0062.md:72-74, :50): every parent present
in the BEEF comes before its child.

#### `Beef.last?` (def)

[LIT] 2026-10-15: the transaction a version-1 BEEF ends with, the one under
evaluation (0062.md:74).

### Theorems

#### `readBeefVersion_encode`

[D] 2026-10-15: each version word reads back as its version.

#### `readBeefEntry_encode`

[D] 2026-10-15: a well-formed entry reads back under its version.

#### `beef_decodePrefix_encode`

[M] 2026-10-15, #86 (BEEF, parse after serialize). For every well-formed
BEEF of either version the decoder reads the encoder's bytes back exactly
and leaves any following stream untouched. Premise: `wf` (CompactSize counts
and indices, well-formed BUMPs and transactions, txid-only entries in version
2 only). [LIT] BRC-62 and BRC-96 at 5333fd4.

#### `readBeefVersion_inv`

[D] 2026-10-15: the version word read from byte-valued bytes writes back.

#### `readBeefEntry_inv`

[D] 2026-10-15: an entry read from byte-valued bytes writes back under its version.

#### `beef_encode_decodePrefix`

[M] 2026-10-15, #86 (BEEF, serialize after parse). A BEEF read from the
front of byte-valued bytes encodes back to exactly the bytes read: the
entries keep their order, each BUMP its leaf order. Premise: the input is
byte-valued. [LIT] BRC-62 and BRC-96 at 5333fd4.

#### `beef_decode_encode`

[M] 2026-10-15, #86: the exact BEEF decoder and the encoder are inverse.

#### `beef_encode_decode`

[M] 2026-10-15, #86: the exact BEEF decoder's accepted bytes are the encoding
of what it reads. Premise: the input is byte-valued.

#### `subjectTx_txid`

[M] 2026-10-15, #86: the transaction a BEEF carries under a txid has that
txid. No premise beyond the lookup's success.

#### `ancestry_subject`

[M] 2026-10-15, #86: the subject of an ancestry has the requested txid. No
premise beyond the projection's success.

## `BsvChain.Views.Wire.AtomicBEEF`


[M] 2026-10-15 (#86). [LIT] BRC-95 "Atomic BEEF Transactions",
bsv-blockchain/BRCs at 5333fd449c70fd5982029876376dcf1ed9c64ffe,
`transactions/0095.md` (read 2026-10-15T03:25:55Z from
https://raw.githubusercontent.com/bsv-blockchain/BRCs/5333fd449c70fd5982029876376dcf1ed9c64ffe/transactions/0095.md,
6801 bytes, sha256 `e5ceb51ecbfd9b3715227e65891503908e485eb09d1a0bfd8060d99b2e13026e`).
Views, never rules.

The layout (0095.md:27-38, :73-79): the prefix `0x01010101` (4 bytes, :31),
the subject's txid (32 bytes, :32), then a BEEF of BRC-62 (`0100beef ...`, :78;
this codec also takes BRC-96's version 2, as the three engines do). The two
error conditions (:65-71), a missing subject and an unrelated transaction, are
validation, not grammar: the codec reads every prefix, word and BEEF, and the
view `AtomicBeef.scoped` decides the two conditions. A second prefix inside is
refused by the grammar: the inner bytes must begin with a BEEF version word.

### Definitions

#### `atomicPrefix` (def)

[LIT] 2026-10-15: the Atomic BEEF prefix `0x01010101` (0095.md:31).

#### `AtomicBeef` (structure)

[LIT] 2026-10-15: an Atomic BEEF: the subject's txid (internal order) and the BEEF.

#### `AtomicBeef.encode` (def)

[LIT] 2026-10-15: the Atomic BEEF bytes (0095.md:34-38).

#### `AtomicBeef.decodePrefix` (def)

[LIT] 2026-10-15: read an Atomic BEEF from the front of a byte string.

#### `AtomicBeef.decode` (def)

[LIT] 2026-10-15: exactly one Atomic BEEF, trailing bytes refused.

#### `AtomicWellFormed` (def)

[D] 2026-10-15: a well-formed Atomic BEEF: a 32-byte subject, a well-formed BEEF.

#### `AtomicBeef.ancestry` (def)

[D] 2026-10-15: the subject transaction with its ancestry (BEEF's projection
at the subject's txid).

#### `AtomicBeef.scoped` (def)

[LIT] 2026-10-15: BRC-95's two error conditions as a view (0095.md:65-71):
the subject is a raw entry of the BEEF, and every entry is the subject or one
of its ancestors in the BEEF.

### Theorems

#### `atomic_decodePrefix_encode`

[M] 2026-10-15, #86 (Atomic BEEF, parse after serialize). Premise: `wf`.
[LIT] BRC-95 at 5333fd4, 0095.md:27-38.

#### `atomic_encode_decodePrefix`

[M] 2026-10-15, #86 (Atomic BEEF, serialize after parse). Premise: the
input is byte-valued. [LIT] BRC-95 at 5333fd4.

#### `atomic_decode_encode`

[M] 2026-10-15, #86: the exact Atomic BEEF decoder and the encoder are inverse.

#### `atomic_encode_decode`

[M] 2026-10-15, #86: the exact Atomic BEEF decoder's accepted bytes are the
encoding of what it reads. Premise: the input is byte-valued.

#### `atomic_not_beef`

[M] 2026-10-15, #86: an Atomic BEEF is never read as a plain BEEF: its
leading four bytes are the word `0x01010101`, neither BEEF version. No premise.

#### `scoped_subject`

[M] 2026-10-15, #86: a scoped Atomic BEEF names a subject it carries as a
raw transaction whose txid is the subject word. No premise beyond `scoped`.

## `BsvChain.Views.Wire.TSC`


[M] 2026-10-15 (#86). The binary codec of the TSC "Merkle Proof
Standardised Format" is #75's (`BsvChain.Views.MerkleProof`, the [LIT]
citation of the standard there: retrieved 2026-10-13T23:44:03Z, sha256
`438f2ffb08a225769761934c40479ea7aa0e893e74eae780d7619b5c58c916e7`), and #75
proved parse after serialize (`tsc_decodePrefix_encode`). This module adds
the other direction, serialize after parse on byte-valued input, and the
function to a BUMP of BRC-74, so the five wire views share one projection to
#65's `(leaf, path, index, root)`. Views, never rules.

### Definitions

#### `_root_.BsvChain.Views.TscProof.toBump` (def)

[D] 2026-10-15: the single-path BUMP of a TSC proof at a block height: its
leaf (the id, or the carried transaction's id), its index, its nodes.

### Theorems

#### `header_encode_decodePrefix`

[D] 2026-10-15: a header frame read from byte-valued bytes encodes back:
every field's value is below its width, so the bit vector keeps it.
[SRC] src/primitives/block.h:38-45 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.

#### `readNode_inv`

[D] 2026-10-15: a node read from bytes writes back to them. [LIT] the TSC node layout.

#### `decodeTxOrId_inv`

[D] 2026-10-15: a `txOrId` field read from byte-valued bytes writes back, and
its flag bit is the one read.

#### `decodeTarget_inv`

[D] 2026-10-15: a `target` field read from byte-valued bytes writes back, and
its kind is the one read.

#### `tsc_encode_decodePrefix`

[M] 2026-10-15, #86 (the TSC proof, serialize after parse). A binary TSC
proof read from the front of byte-valued bytes encodes back to exactly the
bytes read: the flags byte is the one the fields determine, so no other
flags value is accepted for the same fields. Premise: the input is
byte-valued. With #75's `tsc_decodePrefix_encode` the codec is a bijection
between well-formed proofs and the bytes the decoder accepts.
[LIT] the TSC binary layout, cited in `BsvChain.Views.MerkleProof`.

#### `tsc_encode_decode`

[M] 2026-10-15, #86: the exact TSC decoder's accepted bytes are the encoding
of what it reads. Premise: the input is byte-valued.

#### `verifyTsc_eq_bump`

[M] 2026-10-15, #86 (TSC, BUMP and #65 agree). Whenever the target supplies
a root and no hash node is the zero word, the TSC proof verifies exactly when
its BUMP computes that root for the proof's leaf at the proof's index.
Premises: the target resolves to `root`; no hash node is the all-zero word
(the node reads that word as the marker, BRC-74 hashes it).
[SRC] src/consensus/merkle.cpp:291-310 at 6504a3af; [LIT] BRC-74 at 5333fd4.
