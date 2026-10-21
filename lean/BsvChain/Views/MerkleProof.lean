import BsvChain.Merkle
import BsvChain.Header

/-!
# The proof surface: getmerkleproof, getmerkleproof2 and the TSC proof format (#75)

[M] 2026-10-13 (#75). Every definition here is a view of #65's
`(leaf, path, index, root)`, never a rule: a proof object is a client
encoding of a merkle branch, and its verification is `verifyPath`. Hash words
are internal-order 32-byte words; the RPC's hex strings are the reversed
display order, which the views below render with `hexEncode` of the reversed word.

**`getmerkleproof` [SRC] src/rpc/rawtransaction.cpp:2242-2339 at
6504a3aff65ba97c0f6c80962b033e35ecbfed4b.** Parameters: `txid` (required) and
`blockhash` (optional, :2259-2261; without it the block is found only through
an unspent output or `-txindex`, :2253-2256, `GetBlockIndex` at :2286).
The help text marks it DEPRECATED in favour of `getmerkleproof2` (:2250). The
result (:2322-2338): `flags` always 2, meaning `txOrId` is a transaction id
and `target` is a block header (:2264, :2324); `index`, the transaction's
position in the block (:2265, :2325); `txOrId`, the txid hex (:2266, :2326);
`target`, the verbose header object as `getblockheader true` renders it
(:2267, :2336); `nodes`, one hash per level with the string `*` for a null
word, "a copy of the calculated node" (:2268-2269, :2309-2319, :2337).
Errors: "Block for this transaction not found" (:2288-2291), "Can't read
block from disk" (:2297-2300), and RPC `-5` (`RPC_INVALID_ADDRESS_OR_KEY`) with the text
`Transaction(s) not found in provided block` when the proof vector is empty
(:2302-2306). The pinned regtest node answers exactly that `-5` for a block
containing only its coinbase (a finding on #75 of 2026-10-13, measured again by
the record below): `GetMerkleProof` reaches the root at once for a one-leaf
tree and returns an empty vector (src/merkletree.cpp:335-339), so the node
supplies NO proof for a lone transaction; the offset-0 reading (index 0, an
empty branch, the lone leaf) is body-derived, never a node output.

**`getmerkleproof2` [SRC] src/rpc/rawtransaction.cpp:2342-2525 at 6504a3af;
the issue's `src/rpc/client_utils.cpp:137` is the CLI's conversion row for
its third parameter, the server handler is the function above.** Parameters
(:2362-2366, read at :2404-2418): `blockhash` (required, the empty string
meaning "find the block", :2362, :2407-2409), `txid` (required), `includeFullTx`
(default false, :2416), `targetType` (default `hash`; `header` or `merkleroot`,
refused otherwise with `RPC_INVALID_PARAMS`, :2421-2427) and `format` (default
`json`; `binary` is refused at the pin with `RPC_INVALID_PARAMS`, the JSON-RPC
code `-32602` (src/rpc/protocol.h:28), and the text `format is 'binary',  must be 'json'`,
:2429-2436; the source comment says "enable binary in next version"; [M] measured
on the pinned regtest node by the record docs/records/20261014-015319-s6-75-regtest-s3.md). So the node of record serves the JSON form
only; the binary TSC form below is the standard's, measured here by decoding
the node's JSON into the structure and re-encoding. The result (:2465-2524):
`index` (:2468); `txOrId`, the txid hex or, with `includeFullTx`, the whole
transaction hex (:2471-2499); `targetType`, present only when it is not
`hash` (:2503-2504); `target`, the 80-byte header hex (:2505-2510), the block
hash hex (:2512-2514) or the merkle root hex (:2516-2518); `nodes` as above
(:2454-2460, :2522). The same `-5` for an empty vector (:2447-2450). The
command table at :2631 lists the positional names as `txid, blockhash` while
the handler reads `params[0]` as the block hash and `params[1]` as the txid
(:2404-2409); the names only serve named-argument conversion.

**`verifymerkleproof` [SRC] src/rpc/rawtransaction.cpp:2527-2613 at
6504a3af.** Accepts the `getmerkleproof` object with `flags` 2 only
(:2565-2572), reads `target.merkleroot` (:2588), maps `*` to the null word
(:2601-2607) and compares `ComputeMerkleRootFromBranch` with the root
(:2610-2611): the node's own verification is `verifyPath` over the marker
reading, which the theorems of `BsvChain.Properties.MerkleProof` relate to
the recomputed-duplicate reading.

**The marker [SRC] src/merkletree.cpp:294-346 and src/consensus/merkle.cpp:291-310
at 6504a3af.** `GetMerkleProof(index, skipDuplicates)` walks the stored levels:
a sibling in range is emitted (:304-308); when the sibling is the level's
virtual duplicated parent, the actual hash is emitted unless the previous
level already emitted a marker (:309-321); the last node of a level with an
odd count emits the marker (:322-334); a level of one node is the root
(:335-339). `ComputeMerkleRootFromBranch` reads a null word as "hash the
running value with itself" (src/consensus/merkle.cpp:297-301), so a `*` stands for the running hash
at that level; `tscPath` below resolves it by recomputation.

**The TSC format [LIT].** The "Merkle Proof Standardised Format" at
https://tsc.bsvblockchain.org/standards/merkle-proof-standardised-format/
(retrieved 2026-10-13T23:44:03Z, 190341 bytes, sha256
`438f2ffb08a225769761934c40479ea7aa0e893e74eae780d7619b5c58c916e7`; the URL the
source comments at :2345, tsc.bitcoinassociation.net, answered 403 at
2026-10-13T23:44:04Z). Binary form: `flags` (one byte), `index` (varint),
`txLength` (varint, only when flag bit 0 is set), `txOrId` (32 bytes or the
transaction), `target` (32 or 80 bytes by flag bits 1 and 2), `nodeCount`
(varint), then nodes, each a type byte: 0 a 32-byte hash, 1 a duplicate with
no value, 2 an index varint "reserved for use in an extension format". Flag
bit 0: txid (0) or full transaction (1); bits 1 and 2, `(flags & 6) >> 1`:
0 a block hash, 1 a block header, 2 a merkle root; bit 3 the proof type
(tree, an extension); bit 4 composite (an extension). Binary words are the
reverse of the hex display order ("Endianness"). The JSON form omits the flags
byte: `index`, `txOrId` (64 hex characters for an id, longer for a
transaction), `target`, `nodes` of hex strings with `*` for "a copy of the
calculated node", optional `targetType` (`hash` default, `header`,
`merkleRoot` in the document's spelling; the node writes `merkleroot`),
`proofType` and `composite`. This module covers the simple standard: the
decoder refuses the extension bits and the index node type.
-/

namespace BsvChain.Views
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash BsvScript.Sighash

/-- [LIT] 2026-10-13: a proof node, a 32-byte hash word in internal order or the
duplicate marker (`*` in JSON, type byte 1 in binary). The index node type (2)
belongs to the extension and is not represented. [SRC] src/rpc/rawtransaction.cpp:2309-2319
at 6504a3af. -/
inductive TscNode where
  | hash (word : Bytes)
  | duplicate
  deriving DecidableEq, Repr

/-- [LIT] 2026-10-13: the `txOrId` field: a transaction id (flag bit 0 clear) or
the whole transaction (bit 0 set, `includeFullTx`). [SRC] src/rpc/rawtransaction.cpp:2471-2499
at 6504a3af. -/
inductive TscTxOrId where
  | txid (word : Bytes)
  | tx (raw : Bytes)
  deriving DecidableEq, Repr

/-- [LIT] 2026-10-13: the `target` by `targetType`: a block hash (flag bits 1-2 = 0),
a block header (= 1, the 80-byte frame of #63) or a merkle root (= 2).
[SRC] src/rpc/rawtransaction.cpp:2503-2518 at 6504a3af. -/
inductive TscTarget where
  | hash (word : Bytes)
  | header (h : BlockHeader)
  | merkleRoot (word : Bytes)
  deriving DecidableEq, Repr

/-- [LIT] 2026-10-13: the TSC merkle proof, the JSON-level view and the value the
binary codec encodes: the position, the transaction or its id, the target and
the nodes from the leaf's level upward. Views, never rules. -/
structure TscProof where
  index : Nat
  txOrId : TscTxOrId
  target : TscTarget
  nodes : List TscNode
  deriving DecidableEq, Repr

/-- [LIT] 2026-10-13: flag bit 0. -/
def txBit : TscTxOrId → Nat
  | .txid _ => 0
  | .tx _ => 1

/-- [LIT] 2026-10-13: flag bits 1 and 2 as the value `(flags & 6) >> 1`. -/
def targetKind : TscTarget → Nat
  | .hash _ => 0
  | .header _ => 1
  | .merkleRoot _ => 2

/-- [LIT] 2026-10-13: the flags byte of the simple standard: bits 3 and 4 clear.
`getmerkleproof` reports `flags` 2 (txid and header). [SRC] src/rpc/rawtransaction.cpp:2324
at 6504a3af. -/
def TscProof.flags (p : TscProof) : Nat := txBit p.txOrId + 2 * targetKind p.target

/-- [SRC] 2026-10-13: the RPC's `targetType` word for the three targets, in the
node's spelling (src/rpc/rawtransaction.cpp:2421 at 6504a3af); the document
writes `merkleRoot`. -/
def targetTypeWord : TscTarget → String
  | .hash _ => "hash"
  | .header _ => "header"
  | .merkleRoot _ => "merkleroot"

/-- [SRC] 2026-10-13: the node omits `targetType` for a hash target
(src/rpc/rawtransaction.cpp:2503-2504 at 6504a3af). -/
def targetTypeField (t : TscTarget) : Option String :=
  match t with
  | .hash _ => none
  | _ => some (targetTypeWord t)

/-- [SRC] 2026-10-13: a node's JSON word: the display-order hex of a hash, or `*`
(src/rpc/rawtransaction.cpp:2454-2460 at 6504a3af). -/
def tscNodeWord : TscNode → String
  | .hash w => hexEncode w.reverse
  | .duplicate => "*"

/-- [SRC] 2026-10-13: the `txOrId` word: display-order hex of an id, wire-order
hex of a transaction (src/rpc/rawtransaction.cpp:2471-2499 at 6504a3af). -/
def txOrIdWord : TscTxOrId → String
  | .txid w => hexEncode w.reverse
  | .tx raw => hexEncode raw

/-- [SRC] 2026-10-13: the `target` word: display-order hex of a hash or root,
wire-order hex of a header (src/rpc/rawtransaction.cpp:2505-2518 at 6504a3af). -/
def targetWord : TscTarget → String
  | .hash w => hexEncode w.reverse
  | .header h => hexEncode h.encode
  | .merkleRoot w => hexEncode w.reverse

/-! ## The binary codec [LIT] -/

/-- [LIT] 2026-10-13: a node's binary form: type byte 0 then the word, or the
single byte 1. -/
def encodeNode : TscNode → Bytes
  | .hash w => 0 :: w
  | .duplicate => [1]

/-- [LIT] 2026-10-13: the `txOrId` field: 32 bytes, or `txLength` then the transaction. -/
def encodeTxOrId : TscTxOrId → Bytes
  | .txid w => w
  | .tx raw => compactSize raw.length ++ raw

/-- [LIT] 2026-10-13: the `target` field: 32 bytes or the 80-byte header frame. -/
def encodeTarget : TscTarget → Bytes
  | .hash w => w
  | .header h => h.encode
  | .merkleRoot w => w

/-- [LIT] 2026-10-13: the binary TSC proof: flags, index, txOrId, target, the
node count and the nodes. -/
def TscProof.encode (p : TscProof) : Bytes :=
  p.flags :: (compactSize p.index ++ encodeTxOrId p.txOrId ++ encodeTarget p.target ++
    compactSize p.nodes.length ++ (p.nodes.map encodeNode).flatten)

/-- [LIT] 2026-10-13: read one node; type 2 (the extension's index) and every
other type byte are refused. -/
def readNode : Bytes → Option (TscNode × Bytes)
  | 0 :: rest => (readBytes 32 rest).map fun (w, r) => (.hash w, r)
  | 1 :: rest => some (.duplicate, rest)
  | _ => none

/-- [LIT] 2026-10-13: read the `txOrId` field under flag bit 0. -/
def decodeTxOrId (bit : Nat) (bs : Bytes) : Option (TscTxOrId × Bytes) :=
  if bit = 1 then
    (readVarInt bs).bind fun (len, r) => (readBytes len r).map fun (raw, r') => (.tx raw, r')
  else (readBytes 32 bs).map fun (w, r) => (.txid w, r)

/-- [LIT] 2026-10-13: read the `target` field under flag bits 1 and 2; the
reserved value 3 is refused. -/
def decodeTarget (kind : Nat) (bs : Bytes) : Option (TscTarget × Bytes) :=
  match kind with
  | 0 => (readBytes 32 bs).map fun (w, r) => (.hash w, r)
  | 1 => (BlockHeader.decodePrefix bs).map fun (h, r) => (.header h, r)
  | 2 => (readBytes 32 bs).map fun (w, r) => (.merkleRoot w, r)
  | _ => none

/-- [LIT] 2026-10-13: read a binary proof from the front of a byte string and
return the rest; a flags byte with bit 3, bit 4 or a higher bit set (the
extensions) is refused. -/
def decodePrefix : Bytes → Option (TscProof × Bytes)
  | [] => none
  | flags :: bs =>
    if flags ≥ 8 then none else
    (readVarInt bs).bind fun (index, r1) =>
    (decodeTxOrId (flags % 2) r1).bind fun (txOrId, r2) =>
    (decodeTarget (flags / 2 % 4) r2).bind fun (target, r3) =>
    (readVarInt r3).bind fun (count, r4) =>
    (readMany readNode count r4).map fun (nodes, r5) => (⟨index, txOrId, target, nodes⟩, r5)

/-- [LIT] 2026-10-13: exactly one binary proof, trailing bytes refused. -/
def decode (bs : Bytes) : Option TscProof :=
  match decodePrefix bs with
  | some (p, []) => some p
  | _ => none

/-- [D] 2026-10-13: the well-formed proofs the round trip covers: a CompactSize
index and node count, a 32-byte id, a transaction of CompactSize length, 32-byte
hash and root targets, 32-byte hash nodes. The header target is typed. The
byte values of the words are the caller's domain, as with the transaction codec. -/
def NodeWellFormed : TscNode → Prop
  | .hash w => w.length = 32
  | .duplicate => True

def TxOrIdWellFormed : TscTxOrId → Prop
  | .txid w => w.length = 32
  | .tx raw => raw.length < 2 ^ 64

def TargetWellFormed : TscTarget → Prop
  | .hash w => w.length = 32
  | .header _ => True
  | .merkleRoot w => w.length = 32

def TscWellFormed (p : TscProof) : Prop :=
  p.index < 2 ^ 64 ∧ TxOrIdWellFormed p.txOrId ∧ TargetWellFormed p.target ∧
    p.nodes.length < 2 ^ 64 ∧ ∀ n ∈ p.nodes, NodeWellFormed n

/-! ## The projection to #65's `(leaf, path, index, root)` -/

/-- [SRC] 2026-10-13: the leaf: the id, or the id of the carried transaction
(src/rpc/rawtransaction.cpp:2471-2499; src/primitives/transaction.cpp:79-81 at 6504a3af). -/
def tscLeaf : TscTxOrId → Bytes
  | .txid w => w
  | .tx raw => sha256d raw

/-- [SRC] 2026-10-13: the node's own reading of the nodes: a marker is the
null word `ComputeMerkleRootFromBranch` duplicates (src/rpc/rawtransaction.cpp:2601-2607,
src/consensus/merkle.cpp:297-301 at 6504a3af). -/
def markerPath : List TscNode → List Bytes
  | [] => []
  | .hash w :: rest => w :: markerPath rest
  | .duplicate :: rest => zero32 :: markerPath rest

/-- [D] 2026-10-13: the recomputed reading: a marker is resolved to the running
hash of its level, so the result is a literal branch with no marker. For a
hash node the running hash advances as the pair ordered by the index. -/
def tscPath : Bytes → List TscNode → Nat → List Bytes
  | _, [], _ => []
  | leaf, .hash w :: rest, index =>
    let pair := branchPair leaf w index
    w :: tscPath (sha256d (pair.1 ++ pair.2)) rest (index / 2)
  | leaf, .duplicate :: rest, index => leaf :: tscPath (sha256d (leaf ++ leaf)) rest (index / 2)

/-- [SRC] 2026-10-13: the root a target supplies: a merkle root directly, a
header's root field, and a block hash only through a header the caller
supplies whose hash is that word (src/rpc/rawtransaction.cpp:2505-2518 at 6504a3af;
the hash case is the standard's "envelope" case). -/
def resolveTarget : TscTarget → Option BlockHeader → Option Bytes
  | .merkleRoot w, _ => some w
  | .header h, _ => some (headerWordBytes 32 h.merkleRoot.toNat)
  | .hash w, some h =>
    if headerWordBytes 32 h.hash.toNat == w then some (headerWordBytes 32 h.merkleRoot.toNat) else none
  | .hash _, none => none

/-- [D] 2026-10-13: proof verification as a view: `verifyPath` over the marker
reading against the resolved root; false when no root is available. Root
equality only; inclusion keeps #65's premises. -/
def verifyTsc (p : TscProof) (supplied : Option BlockHeader := none) : Bool :=
  match resolveTarget p.target supplied with
  | some root => verifyPath (tscLeaf p.txOrId) (markerPath p.nodes) p.index root
  | none => false

/-- [SRC] 2026-10-13: the model of `GetMerkleProof(index, skipDuplicates = true)`
over the level-wise tree, with `branchReduce`'s fuel: the sibling as a hash node,
or the duplicate marker when the position is the last of a level with an odd
count (src/merkletree.cpp:294-346 at 6504a3af). The virtual-parent case there
(:309-321) coincides with the level-wise padding: the padded node is a stored
node here, emitted as a hash unless it is the running node itself. A one-leaf
level ends the walk (:335-339), so a one-transaction body yields `[]`, the
empty vector `getmerkleproof` refuses with RPC -5. -/
def tscBranchReduce : Nat → List Bytes → Nat → List TscNode
  | _, [], _ => []
  | _, [_], _ => []
  | 0, _ :: _ :: _, _ => []
  | fuel + 1, a :: b :: rest, index =>
    (if index % 2 = 0 ∧ index + 1 = (a :: b :: rest).length then TscNode.duplicate
      else TscNode.hash (siblingAt (a :: b :: rest) index)) ::
      tscBranchReduce fuel (merkleLevel (a :: b :: rest)).1 (index / 2)

/-- [SRC] 2026-10-13: the proof the node serves for a body, as a view: txid,
merkle-root target, the marker branch (src/rpc/rawtransaction.cpp:2454-2460,2516-2518
at 6504a3af). -/
def bodyProof (leaves : List Bytes) (index : Nat) : TscProof :=
  ⟨index, .txid ((leaves[index]?).getD zero32), .merkleRoot (computeMerkleRoot leaves).root,
    tscBranchReduce leaves.length leaves index⟩

end BsvChain.Views
