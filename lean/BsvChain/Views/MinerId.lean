import BsvChain.Merkle
import BsvScript.Crypto.Secp256k1

/-!
# Miner ID: the document formats, what the node validates and indexes, revocation, the RPC surface (#83)

[M] 2026-10-15 (#83). NOTHING HERE IS CONSENSUS. Miner ID is a voluntary
service of the miners ("in no way mandatory", [SRC] src/miner_id/miner_id.h:23-24 at
6504a3aff65ba97c0f6c80962b033e35ecbfed4b); the node's Miner ID database and dataref
index exist only when switched on (`-minerid`, default off,
src/miner_id/miner_id_db_defaults.h:18 and src/init.cpp:4095-4109); whatever the setting,
`FindMinerId` runs on every disconnected block. That block's miner-info transaction (and,
with the dataref index, its dataref transactions) is left out of the mempool's
re-admission after a reorg (src/validation.cpp:4110-4113,
src/txmempool.cpp:2494-2545,2359; the `filtered` input of
`BsvChain.Chain.addToDisconnectPool`, which `findMinerId` here can now supply). The node's
own miner-info and dataref transactions leave its mempool when another miner's block
connects (src/validation.cpp:4769-4810, src/init.cpp:3535-3536). These are mempool
effects, never a block's validity; every definition below is a view of a node's own
index, never a rule.

A block is never refused for its Miner ID [SRC]: the database hears of a block only
after `ConnectBlock` has accepted it (`BlockAdded`, src/validation.cpp:4331-4339), after
its disconnection (`BlockRemoved`, :4119-4122), or after its failure is decided
(`InvalidBlock` from `InvalidBlockFound`, :2462-2476). It returns nothing to any of them
and catches its own exceptions (src/miner_id/miner_id_db.cpp:162-202,205-239). In
src/validation.cpp no other line names a Miner ID function or global (`git grep -n
'FindMinerId\|IsMinerId\|IsMinerInfo\|g_minerIDs' 6504a3af -- src/validation.cpp` reads
2474-2475, 4120-4121, 4332-4334 only). The reputation has one reader, a peer's `authresp`
authentication (src/net/net_processing.cpp:2245-2249), never a block. Every parameter
below is a node setting (policy in the spec's sense), named with its default and
its source.

**Sources.** The reference is bitcoin-sv v1.2.3 at
6504a3aff65ba97c0f6c80962b033e35ecbfed4b; every `[SRC]` below is a file and lines
there. The protocol document [LIT] is the BRFC "minerId" README of
`bitcoin-sv-specs/brfc-minerid` at commit e28671bee520c45ce8bcfaf3a608e5099bb5aa42
(https://raw.githubusercontent.com/bitcoin-sv-specs/brfc-minerid/master/README.md,
read 2026-10-15T03:27:34Z, 29904 bytes, sha256
`457e7725ae3b1032efbf9747f6bd83e45caf232e2ed7c5aa10c2a65dec939b80`), its block-binding
page `docs/block_binding_technique.md` at the same commit (read 2026-10-15T03:27:51Z,
3173 bytes, sha256 `da289aa51c8846a60eebb8f89e2544410631af88c47f57672b39e9663fc7c592`)
and the P2P page `p2p/miner_id.md` of `bitcoin-sv-specs/protocol` at master
67d7de07c75d03598fb059d59c61c29ae3dbf87b (read 2026-10-15T03:27:51Z, 7211 bytes, sha256
`7272bf75d5e6ee4d5fe8536ee251e726e0b54a7719aa3736cd6e3d317f947a5d`). Where the node and
the document differ, both are recorded with their citations (rule 15); the node's
reading is the one these views execute.

**The two output formats.** Version 0.1/0.2 (the document's changelog, README.md lines 484-486)
carries the coinbase document in the coinbase itself: `OP_0 OP_RETURN 0x04 ac1eed88`
then pushes of the static document, its signature, and optionally a dynamic document
and its signature (src/script/script.cpp:198-207, src/miner_id/miner_id.cpp:454-555).
Version 0.3 (the document's 1.0) puts a reference in the coinbase,
`OP_0 OP_RETURN 0x04 601dface 0x00 txid blockBind sig(blockBind)`
(src/script/script.h:309-320, src/miner_id/miner_info_ref.cpp:60-114), and the miner-info
document in another transaction of the same block,
`OP_0 OP_RETURN 0x04 601dface 0x00 doc sig(doc)` (src/miner_id/miner_info_doc.cpp:445-491);
dataref transactions carry `OP_0 OP_RETURN 0x04 601dface 0x00 json`
(src/miner_id/miner_info.cpp:231-262).

**Node and document, where they differ [SRC] / [LIT].** (1) Hashes: the node signs and
verifies over ONE SHA-256 of the message bytes (src/miner_id/miner_id.cpp:87-100,
src/miner_id/miner_info_doc.cpp:145-182, src/miner_id/miner_info.cpp:109-125,
src/miner_id/revokemid.cpp:63-74); the document writes `HASH256` for `prevMinerIdSig`,
`prevRevocationKeySig` (README.md lines 121,124), `Hash256` for the revocation message
(README.md lines 145) and the block bind (block_binding_technique.md lines 32); its P2P page writes
SHA256 for `revokemid` (miner_id.md lines 108-119). (2) The miner-info signature
`sig(miner-info)`, "the main signature" of the document (README.md lines 175), is checked by the
node for its LENGTH only (64 to 72 bytes, src/miner_id/miner_info_doc.cpp:485-486 with
src/miner_id/miner_info.cpp:188-191); the document is bound through its txid inside the
modified coinbase that the block-bind signature covers (src/miner_id/miner_info.cpp:66-98).
(3) The document says the miner-info output is at index 0 (README.md lines 73); the node takes
the lowest-index output of the transaction that carries the prefix, wherever it is
(src/miner_id/miner_info.cpp:42-48). (4) The node never compares the version 0.3
document's `height` with the block's height (ParseMinerInfoDoc checks `height > 0`
only, src/miner_id/miner_info_doc.cpp:364-368; `FindMinerId` passes no height to it,
src/miner_id/miner_id.cpp:589); only `createminerinfotx` requires the next height
(src/rpc/miner_info.cpp:450-451). The static 0.1/0.2 document's height must equal the
block's (src/miner_id/miner_id.cpp:133-148). (5) The DER check on signature strings is the
regular expression `304[0-8]02([0-9a-fA-F]{2}){61,69}` (src/miner_id/miner_info.cpp:172-181);
the document says 70-72 bytes (README.md lines 121,154). (6) A static document of version
`0.3` in the 0xac1eed88 format is always refused: `0.3` is in `SUPPORTED_VERSIONS`
(src/miner_id/coinbase_doc.h:23) but the previous-id signature has no branch for it
(src/miner_id/miner_id.cpp:206-228). (7) The reference's text for
`doc_parse_error_invalid_prev_revocation_key_sig` reads "invalid revocationMessageSig"
(src/miner_id/miner_info_error.cpp:58-60).

**What the node indexes.** The miner ID database (src/miner_id/miner_id_db.h:100-268)
keeps, under LevelDB at `miner_id/MinerIdDB` (miner_id_db.cpp:1412-1421), one entry per
miner ID (prefix 'I', keyed by the key's hash: the miner's UUID, the key, the previous
key, the state CURRENT/ROTATED/REVOKED, the next key, the creation block and the coinbase
document), one entry per miner (prefix 'U': reputation M, void flag and voiding key, last
M decrease, earliest and latest block, latest id), the recent blocks (prefix 'B': hash,
height, miner, miner id) and the state (prefix 'S': version 1, best block, synced). The
dataref index (src/miner_id/dataref_index_detail.h:38-117) keeps, at `miner_id/dataRefTxDB`,
the miner-info ('I') and dataref ('T') transactions with their block and merkle proof.
`Db` and `DataRefIndex` below are those contents as views; `blockAdded`,
`processRevokemid`, `invalidBlock`, `prune` and the index's add and delete are the
transitions.

**Revocation.** A version 0.3 document carrying `revocationMessage` revokes, partially
(the key rolls: `minerId ≠ prevMinerId`; every id from the current back to the
compromised one is REVOKED and a new id is created) or fully (no roll: every id of the
miner is REVOKED), src/miner_id/miner_id_db.cpp:1009-1128,1219-1253; the P2P `revokemid`
message revokes without a block (miner_id_db.cpp:241-296, src/net/net_processing.cpp:4523-4568;
its wire format src/miner_id/revokemid.h:49-97). Only version 0.3 carries revocation keys
(src/miner_id/coinbase_doc.cpp:16-30), so no 0.1/0.2 document can revoke.
-/

namespace BsvChain.Views.MinerId
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash BsvScript.Sighash

/-- [D] 2026-10-15: the bytes of an ASCII string. -/
def ascii (s : String) : Bytes := s.toList.map Char.toNat

/-! ## 1. The output frames -/

/-- [SRC] 2026-10-15: the 0.1/0.2 protocol id `ac1eed88` (src/script/script.cpp:200). -/
def minerIdProtocolId : Bytes := [0xac, 0x1e, 0xed, 0x88]

/-- [SRC] 2026-10-15: the 0.3 protocol id `601dface` (src/script/script.h:311). -/
def minerInfoProtocolId : Bytes := [0x60, 0x1d, 0xfa, 0xce]

/-- [SRC] 2026-10-15: `OP_FALSE OP_RETURN` and a 4-byte push of the protocol id, the
leading seven bytes of both formats (src/script/script.cpp:201-205, src/script/script.h:312-319). -/
def frameHead (pid : Bytes) : Bytes := [0x00, 0x6a, 0x04] ++ pid

/-- [SRC] 2026-10-15: `IsMinerId`: at least 8 bytes, the head, and a push opcode (at
most `OP_PUSHDATA4`) at byte 7 (src/script/script.cpp:198-207). -/
def isMinerId (s : Bytes) : Bool :=
  decide (8 ≤ s.length) && s.take 7 == frameHead minerIdProtocolId && decide (s.getD 7 0 ≤ 0x4e)

/-- [SRC] 2026-10-15: `IsMinerInfo`: at least 7 bytes and the head (src/script/script.h:309-320). -/
def isMinerInfo (s : Bytes) : Bool :=
  decide (7 ≤ s.length) && s.take 7 == frameHead minerInfoProtocolId

/-- [SRC] 2026-10-15: one instruction, `bsv::decode_instruction` (src/script/instruction_iterator.h:19-77):
an opcode above `OP_PUSHDATA4` or `OP_0` is an instruction with an empty operand; a push
opcode is refused when nothing follows it or when its operand runs past the end; the
result is the opcode, the operand and the rest. `none` is the iterator's invalid state,
which is also its state at the end of the script (src/script/instruction_iterator.h:107,111-128). -/
def readInstr (bs : Bytes) : Option (Nat × Bytes × Bytes) :=
  match bs with
  | [] => none
  | op :: s =>
    if 0x4e < op ∨ op = 0 then some (op, [], s)
    else if s = [] then none
    else if op < 0x4c then (readBytes op s).map fun (d, r) => (op, d, r)
    else if op = 0x4c then (readLE 1 s).bind fun (n, r) => (readBytes n r).map fun (d, r') => (op, d, r')
    else if op = 0x4d then (readLE 2 s).bind fun (n, r) => (readBytes n r).map fun (d, r') => (op, d, r')
    else (readLE 4 s).bind fun (n, r) => (readBytes n r).map fun (d, r') => (op, d, r')

/-- [SRC] 2026-10-15: the operand of the next instruction and the rest. -/
def readOperand (bs : Bytes) : Option (Bytes × Bytes) := (readInstr bs).map fun (_, d, r) => (d, r)

/-- [SRC] 2026-10-15: the 0.1/0.2 output's pushes after the head: the static document and
its signature, and the dynamic document and its signature when a third instruction is
readable (src/miner_id/miner_id.cpp:454-555). The values are the documents' bytes. -/
structure MinerIdOutput where
  staticDoc : Bytes
  staticSig : Bytes
  dynamic : Option (Bytes × Bytes)
  deriving DecidableEq, Repr

/-- [D] 2026-10-15: the output a miner writes: the head and minimal pushes
(`pushData`, src/script/script.h:104-133). -/
def MinerIdOutput.encode (o : MinerIdOutput) : Bytes :=
  frameHead minerIdProtocolId ++ pushData o.staticDoc ++ pushData o.staticSig ++
    (match o.dynamic with
     | none => []
     | some (d, s) => pushData d ++ pushData s)

/-- [SRC] 2026-10-15: the frame as `ExtractMinerId` reads it, apart from the documents'
contents: the prefix (src/script/script.cpp:198-207); a static document and a
signature, each a non-empty operand (src/miner_id/miner_id.cpp:461-502); then, when a
third instruction is readable, a dynamic document and a fourth instruction, whose absence
loses the whole Miner ID (:513-541); anything after it is not read. -/
def MinerIdOutput.decode (s : Bytes) : Option MinerIdOutput :=
  if !isMinerId s then none else
  match readOperand (s.drop 7) with
  | none => none
  | some (doc, r1) =>
    if doc = [] then none else
    match readOperand r1 with
    | none => none
    | some (sig, r2) =>
      if sig = [] then none else
      match readOperand r2 with
      | none => some ⟨doc, sig, none⟩
      | some (ddoc, r3) =>
        match readOperand r3 with
        | none => none
        | some (dsig, _) => some ⟨doc, sig, some (ddoc, dsig)⟩

/-- [SRC] 2026-10-15: the coded errors of the 0.3 parsers, in the reference's order
(src/miner_id/miner_info_error.h:11-61). -/
inductive MinerInfoError where
  | minerInfoRefNotFound | invalidInstruction | scriptVersionUnsupported | invalidTxidLen
  | invalidMmrPbhHashLen | invalidSigLen | txidNotFound | docOutputNotFound
  | docIllFormedJson | docMissingFields | docInvalidStringType | docInvalidNumberType
  | docUnsupportedVersion | docInvalidHeight | docInvalidMinerId | docInvalidPrevMinerId
  | docInvalidPrevMinerIdSig | docPrevMinerIdSigVerificationFail | docInvalidRevocationKey
  | docInvalidPrevRevocationKey | docInvalidPrevRevocationKeySig | docPrevRevKeySigVerificationFail
  | docRevMsgFields | docRevMsgField | docRevMsgKey | docRevMsgSig1 | docRevMsgSig1Key
  | docSig1VerificationFailed | docRevMsgSig2 | docRevMsgSig2Key | docSig2VerificationFailed
  | datarefsInvalidDatarefsType | datarefsInvalidRefsType | datarefsInvalidDatarefType
  | datarefsDatarefMissingFields | datarefsInvalidRefFieldType | datarefsRefsBrfcidType
  | datarefsRefsBrfcidFieldType | datarefsRefsTxidType | datarefsRefsVoutType
  | datarefsRefsCompressType | blockBindHashMismatch | blockBindSigVerificationFailed
  | blockBindBadFormat | brfcidInvalidLength | brfcidInvalidContent | brfcidInvalidValueType
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: the log text of each error (src/miner_id/miner_info_error.cpp:18-114);
`datarefsInvalidRefFieldType` is in the table but no parser returns it. -/
def MinerInfoError.text : MinerInfoError → String
  | .minerInfoRefNotFound => "miner info ref not found"
  | .invalidInstruction => "invalid instruction"
  | .scriptVersionUnsupported => "unsupported version"
  | .invalidTxidLen => "invalid txid length"
  | .invalidMmrPbhHashLen => "invalid hash(modified merkle root || previous block hash) length"
  | .invalidSigLen => "invalid signature length"
  | .txidNotFound => "txid not found"
  | .docOutputNotFound => "script output not found"
  | .docIllFormedJson => "doc parse error - ill-formed json"
  | .docMissingFields => "doc parse error - missing fields"
  | .docInvalidStringType => "doc parse error - invalid string type"
  | .docInvalidNumberType => "doc parse error - invalid number type"
  | .docUnsupportedVersion => "doc parse error - unsupported version"
  | .docInvalidHeight => "doc parse error - invalid height"
  | .docInvalidMinerId => "doc parse error - invalid minerId"
  | .docInvalidPrevMinerId => "doc parse error - invalid prevMinerId"
  | .docInvalidPrevMinerIdSig => "doc parse error - invalid prevMinerId signature"
  | .docPrevMinerIdSigVerificationFail => "doc parse error - prevMinerIdSig verification fail"
  | .docInvalidRevocationKey => "doc parse error - invalid revocationKey"
  | .docInvalidPrevRevocationKey => "doc parse error - invalid prevRevocationKey"
  | .docInvalidPrevRevocationKeySig => "doc parse error - invalid revocationMessageSig"
  | .docPrevRevKeySigVerificationFail => "doc parse error - prevRevocationKeySig verification fail"
  | .docRevMsgFields => "doc parse error - revocation msg fields"
  | .docRevMsgField => "doc parse error - revocation msg field"
  | .docRevMsgKey => "doc parse error - revocation msg key"
  | .docRevMsgSig1 => "doc parse error - revocation msg sig1 field missing"
  | .docRevMsgSig1Key => "doc parse error - revocation msg sig1 invalid value"
  | .docSig1VerificationFailed => "doc parse error - revocation msg sig1 verification failed"
  | .docRevMsgSig2 => "doc parse error - revocation msg sig2 field missing"
  | .docRevMsgSig2Key => "doc parse error - revocation msg sig2 invalid value"
  | .docSig2VerificationFailed => "doc parse error - revocation msg sig2 verification failed"
  | .datarefsInvalidDatarefsType => "doc parse error - invalid dataRefs object"
  | .datarefsInvalidRefsType => "doc parse error - invalid dataRefs refs object"
  | .datarefsInvalidDatarefType => "doc parse error - invalid dataRefs dataref type"
  | .datarefsDatarefMissingFields => "doc parse error - invalid dataRefs dataref missing fields"
  | .datarefsInvalidRefFieldType => "doc parse error - dataRefs invalid ref field name"
  | .datarefsRefsBrfcidType => "doc parse error - dataRefs refs brfcids type"
  | .datarefsRefsBrfcidFieldType => "doc parse error - dataRefs refs brfcids field type"
  | .datarefsRefsTxidType => "doc parse error - dataRefs refs txid type"
  | .datarefsRefsVoutType => "doc parse error - dataRefs refs vout type"
  | .datarefsRefsCompressType => "doc parse error - dataRefs refs compress type"
  | .blockBindHashMismatch => "block bind - hash mismatch"
  | .blockBindSigVerificationFailed => "block bind - signature verification failed"
  | .blockBindBadFormat => "block bind - bad format"
  | .brfcidInvalidLength => "brfcid invalid length"
  | .brfcidInvalidContent => "brfcid invalid content"
  | .brfcidInvalidValueType => "brfcid invalid value type"

/-- [D] 2026-10-15: how a check ends when it does not succeed: a refusal (a check that
returns false or `{}`), a coded error of the 0.3 parsers, or an exception. The node
throws only from `UniValue::get_int` (a number that is not a 32-bit integer,
src/univalue/lib/univalue_get.cpp:104-112) on these paths; an exception leaves
`FindMinerId` at once, where a refusal moves to the next output, and every caller catches
it as "no Miner ID" (src/miner_id/miner_id_db.cpp:807-883,549-567, src/txmempool.cpp:2496-2527). -/
inductive Fault where
  | reject
  | code (e : MinerInfoError)
  | thrown
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: the 0.3 version push: one operand of exactly the byte 0
(src/miner_id/miner_info_ref.cpp:77-87); the rest after it. -/
def readVersion (bs : Bytes) : Except Fault Bytes :=
  match readOperand bs with
  | none => .error (.code .invalidInstruction)
  | some (v, r) => if v = [0] then .ok r else .error (.code .scriptVersionUnsupported)

/-- [SRC] 2026-10-15: `is_der_signature` on bytes: a length from 64 to 72
(src/miner_id/miner_info.cpp:188-191). -/
def derSigLength (sig : Bytes) : Bool := decide (64 ≤ sig.length) && decide (sig.length ≤ 72)

/-- [SRC] 2026-10-15: the coinbase's 0.3 reference: the miner-info txid (internal byte
order, compared with `GetId`, src/primitives/block.h:142-149), the block bind
`sha256(modified merkle root ‖ previous block hash)` and its signature
(src/miner_id/miner_info_ref.h:14-47). -/
structure MinerInfoRef where
  txid : Bytes
  blockBind : Bytes
  sig : Bytes
  deriving DecidableEq, Repr

/-- [D] 2026-10-15: the reference output a miner writes. -/
def MinerInfoRef.encode (r : MinerInfoRef) : Bytes :=
  frameHead minerInfoProtocolId ++ pushData [0] ++ pushData r.txid ++ pushData r.blockBind ++ pushData r.sig

/-- [SRC] 2026-10-15: `ParseMinerInfoRef` (src/miner_id/miner_info_ref.cpp:60-114): the
version, a 32-byte txid, a 32-byte hash, a signature of 64 to 72 bytes, each error in
the reference's order; anything after the signature is not read. The caller has checked
`IsMinerInfo` (the reference asserts it, :63; here a script without the prefix is
`miner_info_ref_not_found`). -/
def parseMinerInfoRef (s : Bytes) : Except Fault MinerInfoRef := do
  if !isMinerInfo s then throw (.code .minerInfoRefNotFound)
  let r0 ← readVersion (s.drop 7)
  let some (txid, r1) := readOperand r0 | throw (.code .invalidInstruction)
  if txid.length ≠ 32 then throw (.code .invalidTxidLen)
  let some (hash, r2) := readOperand r1 | throw (.code .invalidInstruction)
  if hash.length ≠ 32 then throw (.code .invalidMmrPbhHashLen)
  let some (sig, _) := readOperand r2 | throw (.code .invalidInstruction)
  if !derSigLength sig then throw (.code .invalidSigLen)
  pure ⟨txid, hash, sig⟩

/-- [SRC] 2026-10-15: the miner-info output's frame: the document's bytes and its
signature (src/miner_id/miner_info_doc.cpp:445-491). -/
structure MinerInfoFrame where
  doc : Bytes
  sig : Bytes
  deriving DecidableEq, Repr

/-- [D] 2026-10-15: the miner-info output a miner writes. -/
def MinerInfoFrame.encode (f : MinerInfoFrame) : Bytes :=
  frameHead minerInfoProtocolId ++ pushData [0] ++ pushData f.doc ++ pushData f.sig

/-- [SRC] 2026-10-15: the frame alone, in `ParseMinerInfoScript`'s order with the
document left unparsed (src/miner_id/miner_info_doc.cpp:462-490). -/
def MinerInfoFrame.decode (s : Bytes) : Except Fault MinerInfoFrame := do
  if !isMinerInfo s then throw (.code .minerInfoRefNotFound)
  let r0 ← readVersion (s.drop 7)
  let some (doc, r1) := readOperand r0 | throw (.code .invalidInstruction)
  let some (sig, _) := readOperand r1 | throw (.code .invalidInstruction)
  if !derSigLength sig then throw (.code .invalidSigLen)
  pure ⟨doc, sig⟩

/-- [D] 2026-10-15: the dataref output a miner writes: the version and the JSON object
(src/miner_id/miner_info.cpp:235-243; README.md lines 413 [LIT]). -/
def dataRefScript (json : Bytes) : Bytes := frameHead minerInfoProtocolId ++ pushData [0] ++ pushData json

/-- [SRC] 2026-10-15: the dataref output's JSON, as `VerifyDataScript` reads it before
`VerifyDataObject` (src/miner_id/miner_info.cpp:231-262). -/
def dataRefJson (s : Bytes) : Except Fault Bytes := do
  if !isMinerInfo s then throw (.code .minerInfoRefNotFound)
  let r0 ← readVersion (s.drop 7)
  let some (json, _) := readOperand r0 | throw (.code .invalidInstruction)
  pure json

/-! ## 2. The JSON values as UniValue reads and writes them -/

/-- [SRC] 2026-10-15: a UniValue (src/univalue/include/univalue.h): an object keeps its
keys in order and keeps duplicates (src/univalue/lib/univalue_read.cpp:435-449); a number
keeps its text (:421-432); a string keeps its bytes after unescaping. -/
inductive JVal where
  | null
  | bool (b : Bool)
  | num (text : Bytes)
  | str (s : Bytes)
  | arr (xs : List JVal)
  | obj (kvs : List (Bytes × JVal))
  deriving Repr, Inhabited

namespace JVal

/-- [SRC] 2026-10-15: `operator[](key)`: the earliest value under the key of an object,
else null (src/univalue/lib/univalue.cpp:168-178,198-208). -/
def get : JVal → Bytes → JVal
  | .obj kvs, k => ((kvs.find? (·.1 == k)).map (·.2)).getD .null
  | _, _ => .null

/-- [SRC] 2026-10-15: `exists(key)` (src/univalue/include/univalue.h:82). -/
def has : JVal → Bytes → Bool
  | .obj kvs, k => kvs.any (·.1 == k)
  | _, _ => false

def isNull : JVal → Bool | .null => true | _ => false
def isStr : JVal → Bool | .str _ => true | _ => false
def isNum : JVal → Bool | .num _ => true | _ => false
def isObj : JVal → Bool | .obj _ => true | _ => false
def isArr : JVal → Bool | .arr _ => true | _ => false

/-- [SRC] 2026-10-15: `get_str` on a value already checked to be a string. -/
def str? : JVal → Option Bytes | .str s => some s | _ => none

/-- [SRC] 2026-10-15: `getValStr`: a string's or a number's text, `"1"` for true, empty
otherwise (src/univalue/include/univalue.h:72, src/univalue/lib/univalue.cpp:30-37). -/
def valStr : JVal → Bytes
  | .str s => s
  | .num t => t
  | .bool true => ascii "1"
  | _ => []

/-- [SRC] 2026-10-15: an array's values (`size()` and `operator[](i)`). -/
def items : JVal → List JVal | .arr xs => xs | _ => []

/-- [SRC] 2026-10-15: an object's keys and values (`getKeys`, `getValues`). -/
def members : JVal → List (Bytes × JVal) | .obj kvs => kvs | _ => []

end JVal

/-- [SRC] 2026-10-15: the escape table (src/univalue/include/univalue_escapes.h:4-261):
the control bytes, `"`, `\` and 0x7f escaped, every other byte as it is. -/
def escapeByte (b : Nat) : Bytes :=
  let hex (d : Nat) : Nat := if d < 10 then 0x30 + d else 0x61 + d - 10
  if b = 0x22 then ascii "\\\""
  else if b = 0x5c then ascii "\\\\"
  else if b = 0x08 then ascii "\\b"
  else if b = 0x09 then ascii "\\t"
  else if b = 0x0a then ascii "\\n"
  else if b = 0x0c then ascii "\\f"
  else if b = 0x0d then ascii "\\r"
  else if b < 0x20 ∨ b = 0x7f then ascii "\\u00" ++ [hex (b / 16), hex (b % 16)]
  else [b]

/-- [SRC] 2026-10-15: `json_escape` (src/univalue/lib/univalue_write.cpp:10-26). -/
def escape (s : Bytes) : Bytes := (s.map escapeByte).flatten

mutual
/-- [SRC] 2026-10-15: `UniValue::write()` with no indent (src/univalue/lib/univalue_write.cpp:28-111):
the compact text every Miner ID signature is checked over (src/miner_id/miner_id.cpp:193,383-384). -/
def write : JVal → Bytes
  | .null => ascii "null"
  | .bool b => if b then ascii "true" else ascii "false"
  | .num t => t
  | .str s => [0x22] ++ escape s ++ [0x22]
  | .arr xs => [0x5b] ++ writeItems xs ++ [0x5d]
  | .obj kvs => [0x7b] ++ writeMembers kvs ++ [0x7d]
/-- [SRC] 2026-10-15: an array's values joined by commas (univalue_write.cpp:67-87). -/
def writeItems : List JVal → Bytes
  | [] => []
  | x :: rest => write x ++ (if rest.isEmpty then [] else 0x2c :: writeItems rest)
/-- [SRC] 2026-10-15: an object's members `"key":value` joined by commas (univalue_write.cpp:89-111). -/
def writeMembers : List (Bytes × JVal) → Bytes
  | [] => []
  | (k, v) :: rest =>
    [0x22] ++ escape k ++ [0x22, 0x3a] ++ write v ++ (if rest.isEmpty then [] else 0x2c :: writeMembers rest)
end

/-- [SRC] 2026-10-15: `json_isspace` (src/univalue/include/univalue.h:295-303). -/
def isWs (b : Nat) : Bool := b == 0x20 || b == 0x09 || b == 0x0a || b == 0x0d

def skipWs : Bytes → Bytes
  | [] => []
  | b :: r => if isWs b then skipWs r else b :: r

def isDigit (b : Nat) : Bool := decide (0x30 ≤ b) && decide (b ≤ 0x39)

/-- [D] 2026-10-15: the leading digits and the rest. -/
def spanDigits : Bytes → Bytes × Bytes
  | [] => ([], [])
  | b :: r => if isDigit b then let (d, r') := spanDigits r; (b :: d, r') else ([], b :: r)

/-- [SRC] 2026-10-15: the number token (src/univalue/lib/univalue_read.cpp:106-173): a
leading zero followed by a digit is refused; a `-` followed by a non-digit is refused;
then the integer digits, a fraction with at least one digit, an exponent with an
optional sign and at least one digit. The text is kept. [D] A lone `-` at the end of
the input reads as the number `-`, as the reference's loop does when the byte after it
is not a digit (:131). -/
def readNumber (bs : Bytes) : Option (Bytes × Bytes) :=
  match bs with
  | [] => none
  | c :: r =>
    let afterSign := if c = 0x2d then r else c :: r
    if afterSign.head? = some 0x30 ∧ (afterSign.drop 1).head?.any isDigit then none
    else if c = 0x2d ∧ r.head?.any (fun d => !isDigit d) then none
    else
      let (d1, r1) := spanDigits r
      let intPart := c :: d1
      let frac : Option (Bytes × Bytes) :=
        match r1 with
        | 0x2e :: r2 =>
          let (d2, r3) := spanDigits r2
          if d2 = [] then none else some (0x2e :: d2, r3)
        | _ => some ([], r1)
      frac.bind fun (fp, r3) =>
        let expo : Option (Bytes × Bytes) :=
          match r3 with
          | e :: r4 =>
            if e = 0x65 ∨ e = 0x45 then
              let (sg, r5) : Bytes × Bytes :=
                match r4 with
                | s :: r5 => if s = 0x2d ∨ s = 0x2b then ([s], r5) else ([], s :: r5)
                | [] => ([], [])
              let (d3, r6) := spanDigits r5
              if d3 = [] then none else some (e :: sg ++ d3, r6)
            else some ([], r3)
          | [] => some ([], [])
        expo.map fun (ep, r6) => (intPart ++ fp ++ ep, r6)

/-- [SRC] 2026-10-15: the UTF-8 filter's state (src/univalue/lib/univalue_utffilter.h:13-117):
the output (reversed here), validity, the code point being assembled, the bits still
expected, an open surrogate. -/
structure Utf8Filter where
  outRev : Bytes := []
  valid : Bool := true
  cp : Nat := 0
  state : Nat := 0
  surpair : Nat := 0

/-- [SRC] 2026-10-15: `append_codepoint` (univalue_utffilter.h:99-116), reversed onto the output. -/
def appendCodepoint (outRev : Bytes) (c : Nat) : Bytes :=
  if c ≤ 0x7f then c :: outRev
  else if c ≤ 0x7ff then (0x80 ||| (c &&& 0x3f)) :: (0xc0 ||| (c >>> 6)) :: outRev
  else if c ≤ 0xffff then
    (0x80 ||| (c &&& 0x3f)) :: (0x80 ||| ((c >>> 6) &&& 0x3f)) :: (0xe0 ||| (c >>> 12)) :: outRev
  else if c ≤ 0x1fffff then
    (0x80 ||| (c &&& 0x3f)) :: (0x80 ||| ((c >>> 6) &&& 0x3f)) :: (0x80 ||| ((c >>> 12) &&& 0x3f)) ::
      (0xf0 ||| (c >>> 18)) :: outRev
  else outRev

/-- [SRC] 2026-10-15: `push_back_u` (univalue_utffilter.h:49-71), the surrogate pair joined
with `|` as the reference does (:61), which differs from UTF-16's sum for a high
surrogate from 0xD840 (bit 16 of the shifted half is already set). -/
def Utf8Filter.pushU (f : Utf8Filter) (c : Nat) : Utf8Filter :=
  let f := if f.state ≠ 0 then { f with valid := false } else f
  if 0xD800 ≤ c ∧ c < 0xDC00 then
    if f.surpair ≠ 0 then { f with valid := false } else { f with surpair := c }
  else if 0xDC00 ≤ c ∧ c < 0xE000 then
    if f.surpair ≠ 0 then
      { f with outRev := appendCodepoint f.outRev (0x10000 ||| ((f.surpair - 0xD800) <<< 10) ||| (c - 0xDC00)),
               surpair := 0 }
    else { f with valid := false }
  else if f.surpair ≠ 0 then { f with valid := false }
  else { f with outRev := appendCodepoint f.outRev c }

/-- [SRC] 2026-10-15: `push_back` of a raw byte (univalue_utffilter.h:21-47). -/
def Utf8Filter.push (f : Utf8Filter) (ch : Nat) : Utf8Filter :=
  if f.state = 0 then
    if ch < 0x80 then { f with outRev := ch :: f.outRev }
    else if ch < 0xc0 then { f with valid := false }
    else if ch < 0xe0 then { f with cp := (ch &&& 0x1f) <<< 6, state := 6 }
    else if ch < 0xf0 then { f with cp := (ch &&& 0x0f) <<< 12, state := 12 }
    else if ch < 0xf8 then { f with cp := (ch &&& 0x07) <<< 18, state := 18 }
    else { f with valid := false }
  else
    let f := if ch &&& 0xc0 ≠ 0x80 then { f with valid := false } else f
    let st := f.state - 6
    let cp := f.cp ||| ((ch &&& 0x3f) <<< st)
    let f := { f with state := st, cp := cp }
    if st = 0 then f.pushU cp else f

/-- [D] 2026-10-15: four hex digits read as a code point (`hatoui`, univalue_read.cpp:19-43). -/
def hex4 (bs : Bytes) : Option Nat :=
  let v (c : Nat) : Option Nat :=
    if isDigit c then some (c - 0x30)
    else if 0x61 ≤ c ∧ c ≤ 0x66 then some (c - 0x61 + 10)
    else if 0x41 ≤ c ∧ c ≤ 0x46 then some (c - 0x41 + 10)
    else none
  match bs with
  | [a, b, c, d] => do pure ((((← v a) * 16 + (← v b)) * 16 + (← v c)) * 16 + (← v d))
  | _ => none

/-- [SRC] 2026-10-15: the string token after its opening quote (univalue_read.cpp:175-235): a byte
below 0x20 or the end refuses; the eight escapes and `\u` with four hex digits that the
end does not reach (:203-206); the closing quote; every other byte through the UTF-8
filter, whose `finalize` must hold (:230-231). -/
def readStringLoop : Nat → Utf8Filter → Bytes → Option (Bytes × Bytes)
  | 0, _, _ => none
  | fuel + 1, f, bs =>
    match bs with
    | [] => none
    | b :: r =>
      if b < 0x20 then none
      else if b = 0x22 then
        if f.valid ∧ f.state = 0 ∧ f.surpair = 0 then some (f.outRev.reverse, r) else none
      else if b = 0x5c then
        match r with
        | [] => none
        | e :: r' =>
          if e = 0x22 then readStringLoop fuel (f.push 0x22) r'
          else if e = 0x5c then readStringLoop fuel (f.push 0x5c) r'
          else if e = 0x2f then readStringLoop fuel (f.push 0x2f) r'
          else if e = 0x62 then readStringLoop fuel (f.push 0x08) r'
          else if e = 0x66 then readStringLoop fuel (f.push 0x0c) r'
          else if e = 0x6e then readStringLoop fuel (f.push 0x0a) r'
          else if e = 0x72 then readStringLoop fuel (f.push 0x0d) r'
          else if e = 0x74 then readStringLoop fuel (f.push 0x09) r'
          else if e = 0x75 then
            if r'.length ≤ 4 then none else
            match hex4 (r'.take 4) with
            | some c => readStringLoop fuel (f.pushU c) (r'.drop 4)
            | none => none
          else none
      else readStringLoop fuel (f.push b) r

def readString (bs : Bytes) : Option (Bytes × Bytes) := readStringLoop (bs.length + 1) {} bs

/-- [D] 2026-10-15: a keyword's bytes at the front (`strncmp`, univalue_read.cpp:88-104). -/
def readKeyword (kw : Bytes) (v : JVal) (bs : Bytes) : Option (JVal × Bytes) :=
  if kw.isPrefixOf bs then some (v, bs.drop kw.length) else none

/-- [SRC] 2026-10-15: the nesting bound, `m_JSONParseDepth` 2048 checked before each open
(univalue_read.cpp:319-322, src/univalue/include/univalue.h:27-52). -/
def jsonDepth : Nat := 2048

mutual
/-- [D] 2026-10-15: a value, read recursively; the reference's reader is a token machine
(univalue_read.cpp:254-466) whose expectations (`EXP_OBJ_NAME`, `EXP_COLON`,
`EXP_ARR_VALUE`, `EXP_VALUE`, `EXP_NOT_VALUE`, the comma rules at :352,380-381) admit the
same documents; `depth` counts the open containers. -/
def readValue : Nat → Nat → Bytes → Option (JVal × Bytes)
  | 0, _, _ => none
  | fuel + 1, depth, bs =>
    match skipWs bs with
    | [] => none
    | c :: r =>
      if c = 0x7b then (if jsonDepth < depth then none else readObject fuel (depth + 1) r)
      else if c = 0x5b then (if jsonDepth < depth then none else readArray fuel (depth + 1) r)
      else if c = 0x22 then (readString r).map fun (s, r') => (.str s, r')
      else if c = 0x6e then readKeyword (ascii "null") .null (c :: r)
      else if c = 0x74 then readKeyword (ascii "true") (.bool true) (c :: r)
      else if c = 0x66 then readKeyword (ascii "false") (.bool false) (c :: r)
      else if c = 0x2d ∨ isDigit c then (readNumber (c :: r)).map fun (t, r') => (.num t, r')
      else none
/-- [D] 2026-10-15: after `{`: `}` or the members. -/
def readObject : Nat → Nat → Bytes → Option (JVal × Bytes)
  | 0, _, _ => none
  | fuel + 1, depth, bs =>
    match skipWs bs with
    | 0x7d :: r => some (.obj [], r)
    | r => readMembers fuel depth [] r
/-- [D] 2026-10-15: a member `"key" : value`, then `,` and another member or `}`. -/
def readMembers : Nat → Nat → List (Bytes × JVal) → Bytes → Option (JVal × Bytes)
  | 0, _, _, _ => none
  | fuel + 1, depth, acc, bs =>
    match skipWs bs with
    | 0x22 :: r =>
      (readString r).bind fun (k, r1) =>
        match skipWs r1 with
        | 0x3a :: r2 =>
          (readValue fuel depth r2).bind fun (v, r3) =>
            match skipWs r3 with
            | 0x2c :: r4 => readMembers fuel depth ((k, v) :: acc) r4
            | 0x7d :: r4 => some (.obj ((k, v) :: acc).reverse, r4)
            | _ => none
        | _ => none
    | _ => none
/-- [D] 2026-10-15: after `[`: `]` or the values. -/
def readArray : Nat → Nat → Bytes → Option (JVal × Bytes)
  | 0, _, _ => none
  | fuel + 1, depth, bs =>
    match skipWs bs with
    | 0x5d :: r => some (.arr [], r)
    | r => readItems fuel depth [] r
/-- [D] 2026-10-15: a value, then `,` and another value or `]`. -/
def readItems : Nat → Nat → List JVal → Bytes → Option (JVal × Bytes)
  | 0, _, _, _ => none
  | fuel + 1, depth, acc, bs =>
    (readValue fuel depth bs).bind fun (v, r) =>
      match skipWs r with
      | 0x2c :: r' => readItems fuel depth (v :: acc) r'
      | 0x5d :: r' => some (.arr (v :: acc).reverse, r')
      | _ => none
end

/-- [SRC] 2026-10-15: `UniValue::read`: one value and nothing but whitespace after it
(univalue_read.cpp:254-466, the end at :460-465). -/
def readJson (bs : Bytes) : Option JVal :=
  match readValue (4 * bs.length + 4) 0 bs with
  | some (v, rest) => if skipWs rest = [] then some v else none
  | none => none

/-! ## 3. Text helpers the parsers call -/

/-- [D] 2026-10-15: C's `isspace` in the "C" locale. -/
def isCSpace (b : Nat) : Bool := b == 0x20 || (decide (0x09 ≤ b) && decide (b ≤ 0x0d))

/-- [SRC] 2026-10-15: `ParseInt32` (src/univalue/lib/univalue_get.cpp:19-44): no empty
string, no `json_isspace` at either end, no NUL; then `strtol` base 10 (leading C
whitespace, an optional sign, at least one digit, nothing after) within `int32_t`. -/
def parseInt32 (s : Bytes) : Option Int :=
  if s = [] then none
  else if (s.head?.any isWs) || (s.getLast?.any isWs) || s.contains 0 then none
  else
    let t := s.dropWhile isCSpace
    let (neg, u) : Bool × Bytes :=
      match t with
      | 0x2d :: u => (true, u)
      | 0x2b :: u => (false, u)
      | _ => (false, t)
    let (ds, rest) := spanDigits u
    if ds = [] ∨ rest ≠ [] then none
    else
      let n : Nat := ds.foldl (fun acc d => acc * 10 + (d - 0x30)) 0
      let v : Int := if neg then -(n : Int) else n
      if -2147483648 ≤ v ∧ v ≤ 2147483647 then some v else none

/-- [SRC] 2026-10-15: `UniValue::get_int` on a number: `ParseInt32` of its text, else the
exception (src/univalue/lib/univalue_get.cpp:104-112). -/
def getInt (v : JVal) : Except Fault Int :=
  match v with
  | .num t => match parseInt32 t with | some n => .ok n | none => .error .thrown
  | _ => .error .thrown

/-- [D] 2026-10-15: a hex digit's value, either case (`HexDigit`). -/
def hexDigit (c : Nat) : Option Nat :=
  if isDigit c then some (c - 0x30)
  else if 0x61 ≤ c ∧ c ≤ 0x66 then some (c - 0x61 + 10)
  else if 0x41 ≤ c ∧ c ≤ 0x46 then some (c - 0x41 + 10)
  else none

/-- [SRC] 2026-10-15: `ParseHex` (src/utilstrencodings.cpp:86-108): skip C whitespace,
read two hex digits as a byte, stop at the earliest byte that is not one. -/
def parseHexLoop : Nat → Bytes → Bytes
  | 0, _ => []
  | fuel + 1, bs =>
    match bs.dropWhile isCSpace with
    | a :: b :: r =>
      match hexDigit a, hexDigit b with
      | some x, some y => (x * 16 + y) :: parseHexLoop fuel r
      | _, _ => []
    | _ => []

def parseHex (s : Bytes) : Bytes := parseHexLoop s.length s

/-- [SRC] 2026-10-15: `transform_hex(string_view)` (src/utilstrencodings.h:202-234): nothing
unless every character is `0-9a-f` (lower case only); then pairs, an odd last character
dropped. -/
def transformHex (s : Bytes) : Bytes :=
  let lower (c : Nat) : Bool := isDigit c || (decide (0x61 ≤ c) && decide (c ≤ 0x66))
  if s.all lower then
    let rec pairs : Bytes → Bytes
      | a :: b :: r => ((hexDigit a).getD 0 * 16 + (hexDigit b).getD 0) :: pairs r
      | _ => []
    pairs s
  else []

def isHexChar (c : Nat) : Bool := (hexDigit c).isSome

/-- [SRC] 2026-10-15: `is_hash_256`, `([0-9a-fA-F]{2}){32}` (src/miner_id/miner_info.cpp:150-159). -/
def isHash256 (s : Bytes) : Bool := s.length == 64 && s.all isHexChar

/-- [SRC] 2026-10-15: `is_compressed_key`, `0[23]([0-9a-fA-F]{2}){32}` (src/miner_id/miner_info.cpp:161-170). -/
def isCompressedKey (s : Bytes) : Bool :=
  match s with
  | 0x30 :: k :: rest => (k == 0x32 || k == 0x33) && rest.length == 64 && rest.all isHexChar
  | _ => false

/-- [SRC] 2026-10-15: `is_der_signature` on a string, `304[0-8]02([0-9a-fA-F]{2}){61,69}`
(src/miner_id/miner_info.cpp:172-186): 64 to 72 bytes of hex led by `30 4x 02`. -/
def isDerSigHex (s : Bytes) : Bool :=
  match s with
  | 0x33 :: 0x30 :: 0x34 :: l :: 0x30 :: 0x32 :: rest =>
    decide (0x30 ≤ l) && decide (l ≤ 0x38) && rest.length % 2 == 0 &&
      decide (122 ≤ rest.length) && decide (rest.length ≤ 138) && rest.all isHexChar
  | _ => false

/-! ## 4. The documents -/

/-- [D] 2026-10-15: `CPubKey::Verify(digest, sig)` as a parameter (key, signature, 32-byte
digest), so the views run under any verifier; the node's is `nodeVerifier`. -/
abbrev Verifier := Bytes → Bytes → Bytes → Bool

/-- [SRC] 2026-10-15: the node's verifier, `CPubKey::Verify` (src/pubkey.cpp:183-214),
the spec's `BsvScript.Crypto.Secp256k1.verify`. -/
def nodeVerifier : Verifier := BsvScript.Crypto.Secp256k1.verify

/-- [SRC] 2026-10-15: `verify(msg, key, sig)`: ONE SHA-256 of the message, then the key's
check (src/miner_id/miner_id.cpp:87-100). -/
def verifyMsg (v : Verifier) (msg key sig : Bytes) : Bool := v key sig (sha256 msg)

/-- [SRC] 2026-10-15: `SUPPORTED_VERSIONS` (src/miner_id/coinbase_doc.h:23). -/
def supportedVersions : List Bytes := [ascii "0.1", ascii "0.2", ascii "0.3"]

/-- [SRC] 2026-10-15: one dataref: its BRFC ids, the txid as written (the node stores
`uint256S` of it), the output index, the compression word (src/miner_id/coinbase_doc.h:38-55,
src/miner_id/miner_info_doc.h:55-75). -/
structure DataRef where
  brfcIds : List Bytes
  txid : Bytes
  vout : Int
  compress : Bytes
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: `CoinbaseDocument`, the stored view (src/miner_id/coinbase_doc.h:34-241):
the JSON it came from, the version, the height, the previous and current keys and the
previous-key signature (hex text), the validity-check outpoint (0.1/0.2 only), the
datarefs, the revocation keys and message (0.3 only), the contact object. -/
structure CoinbaseDoc where
  rawJson : Bytes
  version : Bytes
  height : Int
  prevMinerId : Bytes
  prevMinerIdSig : Bytes
  minerId : Bytes
  vctx : Option (Bytes × Int)
  dataRefs : Option (List DataRef)
  prevRevocationKey : Bytes
  revocationKey : Bytes
  revocationMessage : Option Bytes
  minerContact : Option JVal
  deriving Repr

/-- [SRC] 2026-10-15: `parseDataRefs` of the 0.1/0.2 path (src/miner_id/miner_id.cpp:32-85):
absent is none; present, an object with a `refs` array whose every member has an array
`brfcIds` of strings, a string `txid` and a number `vout`; `compress` kept when a string;
`vout` through `get_int` (:74), which can throw. -/
def parseDataRefsLenient (doc : JVal) : Except Fault (List DataRef) := do
  if !doc.has (ascii "dataRefs") then return []
  let d := doc.get (ascii "dataRefs")
  if !(d.isObj && d.has (ascii "refs") && (d.get (ascii "refs")).isArr) then throw .reject
  (d.get (ascii "refs")).items.mapM fun ref => do
    let b := ref.get (ascii "brfcIds")
    let t := ref.get (ascii "txid")
    let o := ref.get (ascii "vout")
    if !(ref.has (ascii "brfcIds") && b.isArr && ref.has (ascii "txid") && t.isStr &&
        ref.has (ascii "vout") && o.isNum) then throw .reject
    let ids ← b.items.mapM fun x => match x.str? with | some s => pure s | none => throw .reject
    let c := ref.get (ascii "compress")
    let vout ← getInt o
    pure ⟨ids, t.valStr, vout, if ref.has (ascii "compress") && c.isStr then c.valStr else []⟩

/-- [D] 2026-10-15: a check as a step of `Except Fault`. -/
def need (b : Bool) (f : Fault := .reject) : Except Fault Unit := if b then pure () else throw f

/-- [SRC] 2026-10-15: `SetStaticCoinbaseDocument` (src/miner_id/miner_id.cpp:109-281), in its
order: a supported version string; `ParseInt32` of the height's text (a string, a number or
`true` all have text, :133-139) equal to the block's; string `prevMinerId`,
`prevMinerIdSig`, `minerId`; an object `vctx` with a string `txId` and a number `vout`; the
signature over the compact write of the PARSED document (:193-203), by `ParseHex(minerId)`;
the previous-key signature over the three strings concatenated (0.1) or their lower-case
hex decoded (0.2), and no branch for 0.3 (:205-243); `vctx.vout` through `get_int`
(:260); the datarefs (:263-272). -/
def setStatic (v : Verifier) (doc : JVal) (sig : Bytes) (blockHeight : Int) : Except Fault CoinbaseDoc := do
  let some version := (doc.get (ascii "version")).str? | throw .reject
  need (supportedVersions.contains version)
  let some height := parseInt32 (doc.get (ascii "height")).valStr | throw .reject
  need (height = blockHeight)
  let some prevMinerId := (doc.get (ascii "prevMinerId")).str? | throw .reject
  let some prevMinerIdSig := (doc.get (ascii "prevMinerIdSig")).str? | throw .reject
  let some minerId := (doc.get (ascii "minerId")).str? | throw .reject
  let vctx := doc.get (ascii "vctx")
  need vctx.isObj
  let some vtxid := (vctx.get (ascii "txId")).str? | throw .reject
  let vvout := vctx.get (ascii "vout")
  need vvout.isNum
  need (verifyMsg v (write doc) (parseHex minerId) sig)
  let data ←
    if version == ascii "0.1" then pure (prevMinerId ++ minerId ++ vtxid)
    else if version == ascii "0.2" then pure (transformHex prevMinerId ++ transformHex minerId ++ transformHex vtxid)
    else throw .reject
  need (verifyMsg v data (parseHex prevMinerId) (parseHex prevMinerIdSig))
  let contact := doc.get (ascii "minerContact")
  let vout ← getInt vvout
  let refs ← parseDataRefsLenient doc
  pure { rawJson := write doc, version, height, prevMinerId, prevMinerIdSig, minerId,
         vctx := some (vtxid, vout), dataRefs := if refs.isEmpty then none else some refs,
         prevRevocationKey := [], revocationKey := [], revocationMessage := none,
         minerContact := if contact.isObj then some contact else none }

/-- [SRC] 2026-10-15: `SetDynamicCoinbaseDocument` (src/miner_id/miner_id.cpp:283-415): every
field optional but `dynamicMinerId` (a string); a present field must have its type, a
present height must be a number equal to the block's (`get_int`, :316); the signature is
over the static document's compact text, the static signature's bytes and this
document's compact text (:380-397); datarefs only when the static document had none. -/
def setDynamic (v : Verifier) (st : CoinbaseDoc) (staticSig : Bytes) (doc : JVal) (sig : Bytes)
    (blockHeight : Int) : Except Fault CoinbaseDoc := do
  let version := doc.get (ascii "version")
  need (version.isNull || (version.isStr && supportedVersions.contains version.valStr))
  let height := doc.get (ascii "height")
  if !height.isNull then
    need height.isNum
    let h ← getInt height
    need (h = blockHeight)
  for k in [ascii "prevMinerId", ascii "prevMinerIdSig", ascii "minerId"] do
    let x := doc.get k
    need (x.isNull || x.isStr)
  let some dyn := (doc.get (ascii "dynamicMinerId")).str? | throw .reject
  let vctx := doc.get (ascii "vctx")
  if !vctx.isNull then
    need vctx.isObj
    need (vctx.get (ascii "txId")).isStr
    need (vctx.get (ascii "vout")).isNum
  need (verifyMsg v (st.rawJson ++ staticSig ++ write doc) (parseHex dyn) sig)
  if st.dataRefs.isNone then
    let refs ← parseDataRefsLenient doc
    pure { st with dataRefs := if refs.isEmpty then none else some refs }
  else pure st

/-- [SRC] 2026-10-15: `ExtractMinerId` for one 0.1/0.2 output (src/miner_id/miner_id.cpp:454-555),
in its order: the static pushes; the static document read as JSON and checked (an
ill-formed document refuses, :425-435); then, if a third instruction is readable, the
dynamic document and its signature (a missing fourth refuses) checked against it. -/
def extractMinerId (v : Verifier) (script : Bytes) (blockHeight : Int) : Except Fault CoinbaseDoc := do
  let some (doc, r1) := readOperand (script.drop 7) | throw .reject
  need (doc ≠ [])
  let some (sig, r2) := readOperand r1 | throw .reject
  need (sig ≠ [])
  let some j := readJson doc | throw .reject
  let st ← setStatic v j sig blockHeight
  match readOperand r2 with
  | none => pure st
  | some (ddoc, r3) =>
    let some (dsig, _) := readOperand r3 | throw .reject
    let some dj := readJson ddoc | throw .reject
    setDynamic v st sig dj dsig blockHeight

/-- [SRC] 2026-10-15: a 0.3 revocation message: the compromised key and the two signatures
(src/miner_id/miner_info_doc.h:36-53). -/
structure RevocationMsg where
  compromisedId : Bytes
  sig1 : Bytes
  sig2 : Bytes
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: the 0.3 miner-info document as the node keeps it
(src/miner_id/miner_info_doc.h:77-114): the height, the miner-id key set
(key, previous key, previous-key signature), the revocation key set, the optional
revocation message, the datarefs. -/
structure MinerInfoDoc where
  height : Int
  minerId : Bytes
  prevMinerId : Bytes
  prevMinerIdSig : Bytes
  revocationKey : Bytes
  prevRevocationKey : Bytes
  prevRevocationKeySig : Bytes
  revocation : Option RevocationMsg
  dataRefs : List DataRef
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: `parse_data_refs` of the 0.3 path, with its codes
(src/miner_id/miner_info_doc.cpp:239-310): `dataRefs` absent is empty; an object with an
array `refs`; each member an object with `brfcIds`, `txid`, `vout`; `brfcIds` an array of
strings; `txid` a string; `vout` a number; `compress` a string when present; `txid`
64 hex characters (:299-301); `vout` through `get_int` (:306). -/
def parseDataRefsCoded (uv : JVal) : Except Fault (List DataRef) := do
  if !uv.has (ascii "dataRefs") then return []
  let d := uv.get (ascii "dataRefs")
  need d.isObj (.code .datarefsInvalidDatarefsType)
  need (d.has (ascii "refs") && (d.get (ascii "refs")).isArr) (.code .datarefsInvalidRefsType)
  (d.get (ascii "refs")).items.mapM fun ref => do
    need ref.isObj (.code .datarefsInvalidDatarefType)
    need (ref.has (ascii "brfcIds") && ref.has (ascii "txid") && ref.has (ascii "vout"))
      (.code .datarefsDatarefMissingFields)
    let b := ref.get (ascii "brfcIds")
    need b.isArr (.code .datarefsRefsBrfcidType)
    let ids ← b.items.mapM fun x =>
      match x.str? with | some s => pure s | none => throw (.code .datarefsRefsBrfcidFieldType)
    let t := ref.get (ascii "txid")
    need t.isStr (.code .datarefsRefsTxidType)
    let o := ref.get (ascii "vout")
    need o.isNum (.code .datarefsRefsVoutType)
    let compress ←
      if ref.has (ascii "compress") then
        match (ref.get (ascii "compress")).str? with
        | some c => pure c
        | none => throw (.code .datarefsRefsCompressType)
      else pure []
    need (isHash256 t.valStr) (.code .datarefsRefsTxidType)
    let vout ← getInt o
    pure ⟨ids, t.valStr, vout, compress⟩

/-- [SRC] 2026-10-15: the key-set check: ONE SHA-256 of `ParseHex(prev) ‖ ParseHex(key)`
verified by the previous key (src/miner_id/miner_info_doc.cpp:171-182). -/
def verifyKeySet (v : Verifier) (key prev prevSig : Bytes) : Bool :=
  v (parseHex prev) (parseHex prevSig) (sha256 (parseHex prev ++ parseHex key))

/-- [SRC] 2026-10-15: the eight required fields and their types
(src/miner_id/miner_info_doc.cpp:322-330). -/
def requiredFields : List (Bytes × Bool) :=
  [(ascii "version", true), (ascii "height", false), (ascii "minerId", true),
   (ascii "prevMinerId", true), (ascii "prevMinerIdSig", true), (ascii "revocationKey", true),
   (ascii "prevRevocationKey", true), (ascii "prevRevocationKeySig", true)]

/-- [SRC] 2026-10-15: `ParseMinerInfoDoc` (src/miner_id/miner_info_doc.cpp:313-442), every
check in the reference's order with its code: well-formed JSON; no required field null;
each required field's type; version `0.3`; height a positive `int32_t`; `minerId` and
`prevMinerId` compressed keys; `prevMinerIdSig` DER-shaped; the miner-id key set verifies;
the revocation key set likewise; `revocationMessage` and `revocationMessageSig` both
absent or both objects; a present message: a compressed `compromised_minerId`, DER-shaped
`sig1` and `sig2`, `sig1` by the CURRENT revocation key and `sig2` by `prevMinerId`
over ONE SHA-256 of the compromised key's bytes (:152-169,406-424); an `extensions` object's
datarefs (:426-434). -/
def parseMinerInfoDoc (v : Verifier) (raw : Bytes) : Except Fault MinerInfoDoc := do
  let some doc := readJson raw | throw (.code .docIllFormedJson)
  need (requiredFields.all fun (k, _) => !(doc.get k).isNull) (.code .docMissingFields)
  for (k, isString) in requiredFields do
    let x := doc.get k
    if isString then need x.isStr (.code .docInvalidStringType)
    else need x.isNum (.code .docInvalidNumberType)
  need ((doc.get (ascii "version")).valStr == ascii "0.3") (.code .docUnsupportedVersion)
  let some height := parseInt32 (doc.get (ascii "height")).valStr | throw (.code .docInvalidHeight)
  need (0 < height) (.code .docInvalidHeight)
  let minerId := (doc.get (ascii "minerId")).valStr
  need (isCompressedKey minerId) (.code .docInvalidMinerId)
  let prevMinerId := (doc.get (ascii "prevMinerId")).valStr
  need (isCompressedKey prevMinerId) (.code .docInvalidPrevMinerId)
  let prevMinerIdSig := (doc.get (ascii "prevMinerIdSig")).valStr
  need (isDerSigHex prevMinerIdSig) (.code .docInvalidPrevMinerIdSig)
  need (verifyKeySet v minerId prevMinerId prevMinerIdSig) (.code .docPrevMinerIdSigVerificationFail)
  let revKey := (doc.get (ascii "revocationKey")).valStr
  need (isCompressedKey revKey) (.code .docInvalidRevocationKey)
  let prevRevKey := (doc.get (ascii "prevRevocationKey")).valStr
  need (isCompressedKey prevRevKey) (.code .docInvalidPrevRevocationKey)
  let prevRevKeySig := (doc.get (ascii "prevRevocationKeySig")).valStr
  need (isDerSigHex prevRevKeySig) (.code .docInvalidPrevRevocationKeySig)
  need (verifyKeySet v revKey prevRevKey prevRevKeySig) (.code .docPrevRevKeySigVerificationFail)
  let msg := doc.get (ascii "revocationMessage")
  let msgSig := doc.get (ascii "revocationMessageSig")
  need ((msg.isNull && msgSig.isNull) || (msg.isObj && msgSig.isObj)) (.code .docRevMsgFields)
  let revocation ←
    if msg.isObj && msgSig.isObj then do
      let some comp := (msg.get (ascii "compromised_minerId")).str? | throw (.code .docRevMsgField)
      need (isCompressedKey comp) (.code .docRevMsgKey)
      let some s1 := (msgSig.get (ascii "sig1")).str? | throw (.code .docRevMsgSig1)
      need (isDerSigHex s1) (.code .docRevMsgSig1Key)
      let some s2 := (msgSig.get (ascii "sig2")).str? | throw (.code .docRevMsgSig2)
      need (isDerSigHex s2) (.code .docRevMsgSig2Key)
      let h := sha256 (parseHex comp)
      need (v (parseHex revKey) (parseHex s1) h) (.code .docSig1VerificationFailed)
      need (v (parseHex prevMinerId) (parseHex s2) h) (.code .docSig2VerificationFailed)
      pure (some ⟨comp, s1, s2⟩)
    else pure none
  let ext := doc.get (ascii "extensions")
  let refs ← if ext.isObj then parseDataRefsCoded ext else pure []
  pure ⟨height, minerId, prevMinerId, prevMinerIdSig, revKey, prevRevKey, prevRevKeySig, revocation, refs⟩

/-- [SRC] 2026-10-15: `ParseMinerInfoScript` (src/miner_id/miner_info_doc.cpp:445-491): the
version, the document (parsed before the signature instruction is read), the signature
of 64 to 72 bytes; the result is the raw document, the parsed one and the signature. -/
def parseMinerInfoScript (v : Verifier) (s : Bytes) : Except Fault (Bytes × MinerInfoDoc × Bytes) := do
  if !isMinerInfo s then throw (.code .minerInfoRefNotFound)
  let r0 ← readVersion (s.drop 7)
  let some (raw, r1) := readOperand r0 | throw (.code .invalidInstruction)
  let doc ← parseMinerInfoDoc v raw
  let some (sig, _) := readOperand r1 | throw (.code .invalidInstruction)
  need (derSigLength sig) (.code .invalidSigLen)
  pure (raw, doc, sig)

/-- [SRC] 2026-10-15: `VerifyDataObject` (src/miner_id/miner_info.cpp:193-229): well-formed
JSON whose every key is 12 characters of hex and whose every value is an object. -/
def verifyDataObject (raw : Bytes) : Except Fault Unit := do
  let some j := readJson raw | throw (.code .docIllFormedJson)
  need (j.members.all fun (k, _) => k.length == 12) (.code .brfcidInvalidLength)
  need (j.members.all fun (k, _) => k.all isHexChar) (.code .brfcidInvalidContent)
  need (j.members.all fun (_, x) => x.isObj) (.code .brfcidInvalidValueType)

/-- [SRC] 2026-10-15: the coinbase document built from a 0.3 miner-info document
(src/miner_id/coinbase_doc.cpp:16-60): version `0.3`, the keys, the revocation keys, the
compromised key, `minerContact` read again from the raw text, the datarefs when any. -/
def CoinbaseDoc.ofMinerInfo (raw : Bytes) (d : MinerInfoDoc) : CoinbaseDoc :=
  let contact := ((readJson raw).getD .null).get (ascii "minerContact")
  { rawJson := raw, version := ascii "0.3", height := d.height, prevMinerId := d.prevMinerId,
    prevMinerIdSig := d.prevMinerIdSig, minerId := d.minerId, vctx := none,
    dataRefs := if d.dataRefs.isEmpty then none else some d.dataRefs,
    prevRevocationKey := d.prevRevocationKey, revocationKey := d.revocationKey,
    revocationMessage := d.revocation.map (·.compromisedId),
    minerContact := if contact.isObj then some contact else none }

/-! ## 5. The block: the block bind and `FindMinerId` -/

/-- [D] 2026-10-15: a block as these views read it: its transactions in order (the coinbase
leading) and the previous block's hash in internal byte order. -/
structure BlockView where
  txs : List Tx
  prevHash : Bytes

/-- [SRC] 2026-10-15: the modified coinbase (src/miner_id/miner_info.cpp:66-89): version 1,
the leading input's script eight zero bytes and its outpoint the null one (zero hash, index
0xffffffff, src/primitives/transaction.h:57), the lowest-index 0.3 output's script resized to 42
bytes (`CScript::resize`, zero-padded when shorter): the head, the version push and the
32-byte txid push. -/
def modifiedCoinbase (cb : Tx) : Tx :=
  let inputs := match cb.inputs with
    | [] => []
    | i :: rest => { i with prevHash := zero32, prevIndex := 0xffffffff, scriptSig := List.replicate 8 0 } :: rest
  let rec trunc : List TxOut → List TxOut
    | [] => []
    | o :: rest =>
      if isMinerInfo o.scriptPubKey then { o with scriptPubKey := (o.scriptPubKey ++ List.replicate 42 0).take 42 } :: rest
      else o :: trunc rest
  { cb with version := 1, inputs, outputs := trunc cb.outputs }

/-- [SRC] 2026-10-15: `modify_merkle_root` (src/miner_id/miner_info.cpp:66-98): the merkle
root with the coinbase's id replaced by the modified coinbase's. -/
def modifiedMerkleRoot (b : BlockView) : Bytes :=
  match b.txs with
  | [] => (computeMerkleRoot []).root
  | cb :: rest => (computeMerkleRoot (txid (modifiedCoinbase cb) :: rest.map txid)).root

/-- [SRC] 2026-10-15: the block bind's verification (src/miner_id/miner_info.cpp:100-128): a
coinbase with an input and at least two outputs; the pushed hash equal to ONE SHA-256 of
the modified root and the previous block hash; the pushed signature by the document's
`minerId` over that hash. -/
def verifyBlockBind (v : Verifier) (b : BlockView) (r : MinerInfoRef) (key : Bytes) : Except Fault Unit := do
  match b.txs with
  | cb :: _ => need (!cb.inputs.isEmpty && decide (2 ≤ cb.outputs.length)) (.code .blockBindBadFormat)
  | [] => throw (.code .blockBindBadFormat)
  need (r.blockBind == sha256 (modifiedMerkleRoot b ++ b.prevHash)) (.code .blockBindHashMismatch)
  need (v (parseHex key) r.sig r.blockBind) (.code .blockBindSigVerificationFailed)

/-- [SRC] 2026-10-15: `miner_info` (src/miner_id/miner_info.h:27-44): the raw document, the
parsed one, its signature, the miner-info transaction's id. -/
structure MinerInfo where
  raw : Bytes
  doc : MinerInfoDoc
  sig : Bytes
  txid : Bytes

/-- [SRC] 2026-10-15: `ParseMinerInfo(block, ref)` (src/miner_id/miner_info.cpp:31-64): the
transaction with the referenced id, its lowest-index 0.3 output, that output parsed, the block
bind verified by the document's `minerId`. -/
def parseMinerInfo (v : Verifier) (b : BlockView) (r : MinerInfoRef) : Except Fault MinerInfo := do
  let some tx := b.txs.find? (fun t => txid t == r.txid) | throw (.code .txidNotFound)
  let some out := tx.outputs.find? (fun o => isMinerInfo o.scriptPubKey) | throw (.code .docOutputNotFound)
  let (raw, doc, sig) ← parseMinerInfoScript v out.scriptPubKey
  verifyBlockBind v b r doc.minerId
  pure ⟨raw, doc, sig, txid tx⟩

/-- [SRC] 2026-10-15: what `FindMinerId` finds (src/miner_id/miner_id.h:41-76): the coinbase
document, and the miner-info transaction's id on the 0.3 path. -/
structure Found where
  doc : CoinbaseDoc
  minerInfoTx : Option Bytes

/-- [SRC] 2026-10-15: `FindMinerId` (src/miner_id/miner_id.cpp:557-615): the coinbase's outputs
in order; a 0.1/0.2 output that checks is the answer and one that refuses moves on; the
lowest-index 0.3 output decides: its reference and its document, or nothing (`break`, :584,605);
an exception ends the scan with nothing (every caller catches it). -/
def findMinerId (v : Verifier) (b : BlockView) (blockHeight : Int) : Option Found :=
  match b.txs with
  | [] => none
  | cb :: _ =>
    let rec scan : List TxOut → Option Found
      | [] => none
      | o :: rest =>
        let s := o.scriptPubKey
        if isMinerId s then
          match extractMinerId v s blockHeight with
          | .ok d => some ⟨d, none⟩
          | .error .thrown => none
          | .error _ => scan rest
        else if isMinerInfo s then
          match parseMinerInfoRef s with
          | .error _ => none
          | .ok r =>
            match parseMinerInfo v b r with
            | .ok mi => some ⟨CoinbaseDoc.ofMinerInfo mi.raw mi.doc, some mi.txid⟩
            | .error _ => none
        else scan rest
    scan cb.outputs

/-! ## 6. The node's settings (policy: node settings, never consensus) -/

/-- [SRC] 2026-10-15: the Miner ID settings with their defaults
(src/miner_id/miner_id_db_defaults.h:15-37, read at src/init.cpp:3030-3059 (the generator's URL and alias at :3061-3069 configure the
node's own mining service and are not modelled), bounded at
src/config.cpp:2082-2186): `-minerid` (off), `-mineridcachesize` (1 MiB, at most 16 MiB),
`-mineridnumtokeep` (10, at least 2), `-mineridreputation_m` (28, from 1 to N),
`-mineridreputation_n` (2016, from M to 26208), `-mineridreputation_mscale` (1.5, at least
1; here the ratio `mScaleNum / mScaleDen`, applied as the reference's `uint32_t *= double`,
which truncates). -/
structure MinerIdConfig where
  enabled : Bool := false
  cacheSize : Nat := 1 <<< 20
  numToKeep : Nat := 10
  reputationM : Nat := 28
  reputationN : Nat := 2016
  mScaleNum : Nat := 3
  mScaleDen : Nat := 2
  deriving Repr

/-- [SRC] 2026-10-15: the bounds the setters enforce (src/config.cpp:2082-2186;
src/miner_id/miner_id_db_defaults.h:22,29,33). -/
def MinerIdConfig.valid (c : MinerIdConfig) : Bool :=
  decide (c.cacheSize ≤ 1 <<< 24) && decide (2 ≤ c.numToKeep) && decide (1 ≤ c.reputationM) &&
    decide (c.reputationM ≤ c.reputationN) && decide (c.reputationN ≤ 26208) &&
    decide (0 < c.mScaleDen) && decide (c.mScaleDen ≤ c.mScaleNum)

/-! ## 7. The database as a view, and its transitions -/

/-- [SRC] 2026-10-15: an id's state (src/miner_id/miner_id_db.h:191, the names at
src/miner_id/miner_id_db.cpp:1424-1434). -/
inductive IdState where
  | unknown | current | rotated | revoked
  deriving DecidableEq, Repr

def IdState.name : IdState → String
  | .unknown => "UNKNOWN" | .current => "CURRENT" | .rotated => "ROTATED" | .revoked => "REVOKED"

/-- [SRC] 2026-10-15: `MinerIdEntry` (src/miner_id/miner_id_db.h:166-216). [D] The key is the
id's bytes (`ParseHex` of the document's hex); the node keys by `CPubKey::GetHash`,
SHA-256d of the parsed key (src/pubkey.h:148), one to one for the valid keys these
documents carry. -/
structure IdEntry where
  uuid : Nat
  key : Bytes
  prevKey : Bytes
  state : IdState
  nextKey : Option Bytes
  creationBlock : Bytes
  doc : CoinbaseDoc
  deriving Repr

/-- [SRC] 2026-10-15: `MinerReputation` (src/miner_id/miner_id_db.h:112-137). -/
structure Reputation where
  m : Nat
  void : Bool := false
  voidingId : Option Bytes := none
  lastMDecrease : Option Int := none
  deriving Repr

/-- [SRC] 2026-10-15: `MinerUUIdEntry` (src/miner_id/miner_id_db.h:141-163). [D] The UUID is a
number drawn from a counter; the node draws it at random (miner_id_db.cpp:899). -/
structure MinerEntry where
  uuid : Nat
  rep : Reputation
  firstBlock : Bytes
  lastBlock : Bytes
  latestId : Bytes
  deriving Repr

/-- [SRC] 2026-10-15: `RecentBlock` (src/miner_id/miner_id_db.h:220-244): `none` is the nil
UUID, `[]` the zero id hash. -/
structure RecentBlock where
  hash : Bytes
  height : Nat
  miner : Option Nat
  minerId : Bytes
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: the database's contents (src/miner_id/miner_id_db.h:102-109,389-415):
the ids, the miners, the recent-blocks table, the state's best block and synced flag. -/
structure Db where
  ids : List IdEntry := []
  miners : List MinerEntry := []
  recent : List RecentBlock := []
  bestBlock : Bytes := []
  synced : Bool := false
  nextUuid : Nat := 1
  deriving Repr

/-- [D] 2026-10-15: what the database reads from the chain: a block's height in the block
index and the ancestor test (src/miner_id/miner_id_db.cpp:27-32,1285-1294). -/
structure ChainView where
  heightOf : Bytes → Option Nat
  isAncestor : Bytes → Bytes → Bool

namespace Db

def lookupId (db : Db) (k : Bytes) : Option IdEntry := db.ids.find? (·.key == k)
def putId (db : Db) (e : IdEntry) : Db := { db with ids := e :: db.ids.filter (·.key != e.key) }
def lookupMiner (db : Db) (u : Nat) : Option MinerEntry := db.miners.find? (·.uuid == u)
def putMiner (db : Db) (m : MinerEntry) : Db := { db with miners := m :: db.miners.filter (·.uuid != m.uuid) }

/-- [SRC] 2026-10-15: `GetMinerIdsForMinerNL` (src/miner_id/miner_id_db.cpp:1256-1299): the
miner's ids, CURRENT ahead, then by creation height descending, an id whose creation
block is unknown last. [D] A stable merge sort; the reference's comparator is not a strict
weak order when two ids are CURRENT. -/
def idsOfMiner (ctx : ChainView) (db : Db) (u : Nat) : List IdEntry :=
  (db.ids.filter (·.uuid == u)).mergeSort fun a b =>
    if a.state = .current then true
    else if b.state = .current then false
    else match ctx.heightOf a.creationBlock, ctx.heightOf b.creationBlock with
      | some ha, some hb => decide (hb ≤ ha)
      | some _, none => true
      | none, _ => false

/-- [SRC] 2026-10-15: `GetNumRecentBlocksForMinerNL` (src/miner_id/miner_id_db.cpp:1406-1410). -/
def recentCount (db : Db) (u : Nat) : Nat := (db.recent.filter (·.miner == some u)).length

/-- [SRC] 2026-10-15: `CheckMinerReputation` (src/miner_id/miner_id_db.cpp:299-329): a known id
whose miner is not void and mined at least M of the recent blocks. [D] The reference throws
on a missing miner entry (database corruption); here that is false. -/
def goodReputation (db : Db) (k : Bytes) : Bool :=
  match db.lookupId k with
  | none => false
  | some e => match db.lookupMiner e.uuid with
    | none => false
    | some m => !m.rep.void && decide (m.rep.m ≤ db.recentCount e.uuid)

/-- [SRC] 2026-10-15: `UpdateRecentBlocksToRemoveMinerIdNL` (src/miner_id/miner_id_db.cpp:1153-1166):
the blocks mined under the id lose their miner. It edits the in-memory table only; the
stored rows keep the miner (the database write is at :635-641 only), so a restart
restores it. -/
def unlinkRecent (db : Db) (k : Bytes) : Db :=
  { db with recent := db.recent.map fun b => if b.minerId == k then { b with miner := none } else b }

/-- [SRC] 2026-10-15: `RemoveRecentBlockEntryNL` (src/miner_id/miner_id_db.cpp:1377-1387). -/
def removeRecent (db : Db) (hash : Bytes) : Db := { db with recent := db.recent.filter (·.hash != hash) }

/-- [SRC] 2026-10-15: `AddRecentBlockEntryNL` (src/miner_id/miner_id_db.cpp:1361-1374): insert
(the multi-index refuses a second entry with the same hash or the same height,
src/miner_id/miner_id_db.h:275-299), then drop the lowest heights while more than N
remain. -/
def addRecent (cfg : MinerIdConfig) (db : Db) (b : RecentBlock) : Db :=
  let t := if db.recent.any (fun x => x.hash == b.hash || x.height == b.height) then db.recent else b :: db.recent
  let sorted := t.mergeSort fun x y => decide (y.height ≤ x.height)
  { db with recent := sorted.take cfg.reputationN }

/-- [SRC] 2026-10-15: `ProcessNewMinerNL` (src/miner_id/miner_id_db.cpp:893-908). -/
def processNewMiner (cfg : MinerIdConfig) (db : Db) (k : Bytes) (doc : CoinbaseDoc) (block : Bytes) : Db × Nat :=
  let u := db.nextUuid
  let db := { db with nextUuid := u + 1 }
  let db := db.putMiner ⟨u, { m := cfg.reputationM }, block, block, k⟩
  (db.putId ⟨u, k, parseHex doc.prevMinerId, .current, none, block, doc⟩, u)

/-- [SRC] 2026-10-15: `ProcessExistingMinerIdNL` (src/miner_id/miner_id_db.cpp:911-956): only a
CURRENT id is reused (else the reference throws, :949-953); the creation block moves to
this block when the old one is not its ancestor; the document is replaced; the miner's
last block is this one. -/
def processExisting (ctx : ChainView) (db : Db) (e : IdEntry) (doc : CoinbaseDoc) (block : Bytes) :
    Except Fault (Db × Nat) := do
  need (e.state = .current) .thrown
  let e := { e with creationBlock := if ctx.isAncestor e.creationBlock block then e.creationBlock else block, doc := doc }
  let db := db.putId e
  let some m := db.lookupMiner e.uuid | throw .thrown
  pure (db.putMiner { m with lastBlock := block }, e.uuid)

/-- [SRC] 2026-10-15: `UpdateMinerDetailsAfterRotationNL` (src/miner_id/miner_id_db.cpp:1131-1150). -/
def afterRotation (db : Db) (u : Nat) (k block : Bytes) : Except Fault Db := do
  let some m := db.lookupMiner u | throw .thrown
  pure (db.putMiner { m with lastBlock := block, latestId := k })

/-- [SRC] 2026-10-15: `ProcessRotationNL` (src/miner_id/miner_id_db.cpp:959-1007): a rotation
from an unknown id is ignored (the nil UUID); from a CURRENT id, or a ROTATED one whose
successor is CURRENT (a fork's duplicate), the old id becomes ROTATED with its successor
and the new id is created CURRENT under the same miner; otherwise the reference throws. -/
def processRotation (db : Db) (cur prev : Bytes) (doc : CoinbaseDoc) (block : Bytes) : Except Fault (Db × Option Nat) := do
  match db.lookupId prev with
  | none => pure (db, none)
  | some pe =>
    let curCurrent := (db.lookupId cur).any (·.state == .current)
    need (pe.state = .current ∨ (curCurrent ∧ pe.state = .rotated)) .thrown
    let db := db.putId { pe with state := .rotated, nextKey := some cur }
    let db := db.putId ⟨pe.uuid, cur, prev, .current, none, block, doc⟩
    let db ← afterRotation db pe.uuid cur block
    pure (db, some pe.uuid)

/-- [D] 2026-10-15: revoke the ids of a sorted list up to and including the one whose key
is `stop` (every one when `stop` is not there): the loops of
src/miner_id/miner_id_db.cpp:275-285 and :1042-1076. -/
def revokeUpTo (db : Db) (stop : Bytes) : List IdEntry → Db
  | [] => db
  | e :: rest =>
    let db := (db.putId { e with state := .revoked }).unlinkRecent e.key
    if e.key == stop then db else revokeUpTo db stop rest

/-- [SRC] 2026-10-15: the voided reputation restored when the revoked ids include the
voiding one, M scaled by the factor (src/miner_id/miner_id_db.cpp:1056-1069). -/
def restoreIfVoiding (cfg : MinerIdConfig) (db : Db) (u : Nat) (revoked : List Bytes) : Db :=
  match db.lookupMiner u with
  | none => db
  | some m =>
    match m.rep.voidingId with
    | some vk =>
      if m.rep.void && revoked.contains vk then
        db.putMiner { m with rep := { m.rep with void := false, voidingId := none,
                                                  m := m.rep.m * cfg.mScaleNum / cfg.mScaleDen } }
      else db
    | none => db

/-- [D] 2026-10-15: the keys of a sorted list up to and including `stop`. -/
def keysUpTo (stop : Bytes) : List IdEntry → List Bytes
  | [] => []
  | e :: rest => if e.key == stop then [e.key] else e.key :: keysUpTo stop rest

/-- [SRC] 2026-10-15: `ProcessRevocationNL` (src/miner_id/miner_id_db.cpp:1010-1128): no
revocation-key roll during a revocation (else it throws, :1021-1025); PARTIAL when the
key rolls: the previous id must be known (:1228-1240) and a duplicate (the previous id
already REVOKED) revokes nothing again; the miner's ids from the current back to the
compromised one are REVOKED, a voiding id among them restores the reputation, the
predecessor of the last revoked id points to the new id, which is created CURRENT;
FULL when the key does not roll: the id must be known (:1241-1250), every id of the miner
is REVOKED and the block is credited to no one (:1124-1126). The result's last two
parts are the recent-block row's miner and id. -/
def processRevocation (cfg : MinerIdConfig) (ctx : ChainView) (db : Db) (cur prev : Bytes) (doc : CoinbaseDoc)
    (block : Bytes) : Except Fault (Db × Option Nat × Bytes) := do
  let some compromised := doc.revocationMessage | throw .thrown
  need (doc.revocationKey == doc.prevRevocationKey) .thrown
  if cur != prev then
    let some pe := db.lookupId prev | throw .thrown
    let duplicate := pe.state == .revoked
    let u := pe.uuid
    let ids := db.idsOfMiner ctx u
    let upTo := keysUpTo (parseHex compromised) ids
    let db := if duplicate then db else db.revokeUpTo (parseHex compromised) ids
    let db := db.restoreIfVoiding cfg u upTo
    let lastRevoked := (ids.find? (·.key == upTo.getLast?.getD [])).map (·.prevKey)
    let db := match lastRevoked.bind db.lookupId with
      | some pp => db.putId { pp with nextKey := some cur }
      | none => db
    let db := db.putId ⟨u, cur, prev, .current, none, block, doc⟩
    let db ← db.afterRotation u cur block
    pure (db, some u, prev)
  else
    let some ce := db.lookupId cur | throw .thrown
    let u := ce.uuid
    let db := (db.idsOfMiner ctx u).foldl (fun d e => (d.putId { e with state := .revoked }).unlinkRecent e.key) db
    let db := match db.lookupMiner u with
      | some m => db.putMiner { m with lastBlock := block }
      | none => db
    pure (db, none, [])

/-- [SRC] 2026-10-15: `CheckRevocationKeysNL` (src/miner_id/miner_id_db.cpp:1169-1217): for a
0.3 document whose previous id is known: from a pre-0.3 id the two revocation keys must
be equal valid keys; from a 0.3 id the previous revocation key must be the recorded one;
else it throws. [D] `std::stod` of the version is read as "is it 0.3". -/
def checkRevocationKeys (db : Db) (prev : Bytes) (doc : CoinbaseDoc) : Except Fault Unit := do
  if doc.version == ascii "0.3" then
    match db.lookupId prev with
    | none => pure ()
    | some old =>
      if old.doc.version != ascii "0.3" then
        need ((BsvScript.Crypto.Secp256k1.decodePubKey (parseHex doc.prevRevocationKey)).isSome &&
              doc.prevRevocationKey == doc.revocationKey) .thrown
      else need (old.doc.revocationKey == doc.prevRevocationKey) .thrown

/-- [SRC] 2026-10-15: the id work of `BlockAddedNL` (src/miner_id/miner_id_db.cpp:842-877): the
revocation-key check, then a revocation, a new id, a reuse or a rotation. An exception
leaves the database as it was and the block row keeps the id hash set before it (:854). -/
def processDoc (cfg : MinerIdConfig) (ctx : ChainView) (db : Db) (doc : CoinbaseDoc) (block : Bytes) :
    Except Bytes (Db × Option Nat × Bytes) :=
  let cur := parseHex doc.minerId
  let prev := parseHex doc.prevMinerId
  match checkRevocationKeys db prev doc with
  | .error _ => .error []
  | .ok () =>
    if doc.revocationMessage.isSome then
      match processRevocation cfg ctx db cur prev doc block with
      | .ok r => .ok r
      | .error _ => .error []
    else
      let r : Except Fault (Db × Option Nat) :=
        if cur == prev then
          match db.lookupId cur with
          | none => let (d, u) := processNewMiner cfg db cur doc block; .ok (d, some u)
          | some e => (processExisting ctx db e doc block).map fun (d, u) => (d, some u)
        else processRotation db cur prev doc block
      match r with
      | .ok (d, u) => .ok (d, u, cur)
      | .error _ => .error cur

/-- [SRC] 2026-10-15: `BlockAddedNL` (src/miner_id/miner_id_db.cpp:778-890) on a block of the
active chain, the database synced (`BlockAdded`, :162-178; a sync replays the same per block,
:425-542): the Miner ID the block carries, if any, processed; the block's row added to the
recent blocks; the best block moved; called after `ConnectBlock` succeeded
(src/validation.cpp:4331-4339). -/
def blockAdded (cfg : MinerIdConfig) (ctx : ChainView) (db : Db) (block : Bytes) (height : Nat)
    (found : Option CoinbaseDoc) : Db :=
  let (db', u, k) := match found with
    | none => (db, none, [])
    | some doc => match processDoc cfg ctx db doc block with
      | .ok r => r
      | .error k => (db, none, k)
  { addRecent cfg db' ⟨block, height, u, k⟩ with bestBlock := block }

/-- [SRC] 2026-10-15: `BlockRemoved` (src/miner_id/miner_id_db.cpp:181-202): the block's row
removed and the best block set to the new tip; called after the disconnect
(src/validation.cpp:4119-4122). -/
def blockRemoved (db : Db) (block tip : Bytes) : Db := { db.removeRecent block with bestBlock := tip }

/-- [SRC] 2026-10-15: `InvalidBlock` (src/miner_id/miner_id_db.cpp:205-239): an invalid block
signed by a CURRENT id voids its miner's reputation (once), recording the id; called from
`InvalidBlockFound` after the block's failure is decided (src/validation.cpp:2462-2476); the
verdict is the chain machine's, read here, never written. -/
def invalidBlock (db : Db) (found : Option CoinbaseDoc) : Db :=
  match found with
  | none => db
  | some doc =>
    match db.lookupId (parseHex doc.minerId) with
    | some e =>
      if e.state = .current then
        match db.lookupMiner e.uuid with
        | some m => if m.rep.void then db else db.putMiner { m with rep := { m.rep with void := true, voidingId := some e.key } }
        | none => db
      else db
    | none => db

/-- [SRC] 2026-10-15: `Prune` (src/miner_id/miner_id_db.cpp:1302-1358), daily
(:24-25,36-40): per miner, the oldest ids beyond `numToKeep + 1` erased from the oldest
up, and a CURRENT one met there throws, which ends the whole prune with the erasures
already written; a miner whose M is above the base and who is hitting it has M lowered
by one, at most once a day. `now` is the explicit clock. -/
def prune (cfg : MinerIdConfig) (ctx : ChainView) (db : Db) (now : Int) : Db :=
  let rec go (d : Db) : List MinerEntry → Db
    | [] => d
    | m :: rest =>
      let drop := ((d.idsOfMiner ctx m.uuid).drop (cfg.numToKeep + 1)).reverse
      let erase := drop.takeWhile (·.state != .current)
      let d := { d with ids := d.ids.filter fun e => !(erase.any (·.key == e.key)) }
      if erase.length < drop.length then d
      else
        let d := match d.lookupMiner m.uuid with
          | none => d
          | some m =>
            if decide (cfg.reputationM < m.rep.m) && decide (m.rep.m ≤ d.recentCount m.uuid) &&
                (m.rep.lastMDecrease.all fun t => decide (t ≤ now - 86400)) then
              d.putMiner { m with rep := { m.rep with m := m.rep.m - 1, lastMDecrease := some now } }
            else d
        go d rest
  go db db.miners

end Db

/-! ## 8. Revocation by P2P message and RPC -/

/-- [SRC] 2026-10-15: the `revokemid` message (src/miner_id/revokemid.h:19-124): version 0, the
revocation key, the miner id and the compromised id as 33 raw bytes each, and the two
signatures. -/
structure RevokeMid where
  revocationKey : Bytes
  minerId : Bytes
  revocationMessage : Bytes
  sig1 : Bytes
  sig2 : Bytes
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: its wire form (src/miner_id/revokemid.h:49-97, src/serialize.h:681-691):
the 32-bit version, the three arrays without length, then a byte vector
`len1 ‖ sig1 ‖ len2 ‖ sig2` with its CompactSize length (src/miner_id/revokemid.cpp:37-60);
the P2P page's layout (miner_id.md lines 96-122 [LIT]). -/
def RevokeMid.encode (m : RevokeMid) : Bytes :=
  let body := [m.sig1.length] ++ m.sig1 ++ [m.sig2.length] ++ m.sig2
  le32 0 ++ m.revocationKey ++ m.minerId ++ m.revocationMessage ++ compactSize body.length ++ body

/-- [SRC] 2026-10-15: a key the message accepts: `IsFullyValid` of 33 bytes, a key that
decodes to a curve point (src/miner_id/revokemid.h:79-85, src/pubkey.cpp). -/
def keyValid (k : Bytes) : Bool := k.length == 33 && (BsvScript.Crypto.Secp256k1.decodePubKey k).isSome

/-- [SRC] 2026-10-15: the message read (src/miner_id/revokemid.h:52-97): a version other than 0
throws; a key that is not fully valid throws; the signature field's two lengths must fill
it exactly (an index past the end throws, `std::vector::at`). Any throw is the peer's
misbehaviour, scored 10 (src/net/net_processing.cpp:4561-4566). -/
def RevokeMid.decode (bs : Bytes) : Option RevokeMid := do
  let (ver, r0) ← readLE 4 bs
  if ver ≠ 0 then none
  let (rk, r1) ← readBytes 33 r0
  let (mid, r2) ← readBytes 33 r1
  let (msg, r3) ← readBytes 33 r2
  let (n, r4) ← readVarInt r3
  let (body, _) ← readBytes n r4
  if !(keyValid rk && keyValid mid && keyValid msg) then none
  match body with
  | [] => none
  | l1 :: r5 =>
    let sig1 := r5.take l1
    match r5.drop l1 with
    | [] => none
    | l2 :: r6 =>
      if body.length = l1 + l2 + 2 then some ⟨rk, mid, msg, sig1, r6.take l2⟩ else none

/-- [SRC] 2026-10-15: `VerifySignatures`: both signatures over ONE SHA-256 of the 33-byte
compromised key, `sig1` by the revocation key and `sig2` by the miner id
(src/miner_id/revokemid.cpp:62-74,116-122). -/
def RevokeMid.verify (v : Verifier) (m : RevokeMid) : Bool :=
  let h := sha256 m.revocationMessage
  v m.revocationKey m.sig1 h && v m.minerId m.sig2 h

namespace Db

/-- [SRC] 2026-10-15: `ProcessRevokemidMessage` (src/miner_id/miner_id_db.cpp:242-296): the
signatures verify; the sending id is known; the message's revocation key is the one its
document recorded; the compromised id is among the miner's ids; then the ids from the
current back to the compromised one are REVOKED. Each failure throws (the peer is scored,
src/net/net_processing.cpp:4561-4566; the RPC `revokeminerid` returns the error). -/
def processRevokemid (v : Verifier) (ctx : ChainView) (db : Db) (m : RevokeMid) : Except Fault Db := do
  need (m.verify v) .thrown
  let some e := db.lookupId m.minerId | throw .thrown
  need (parseHex e.doc.revocationKey == m.revocationKey) .thrown
  let ids := db.idsOfMiner ctx e.uuid
  need (ids.any (·.key == m.revocationMessage)) .thrown
  pure (db.revokeUpTo m.revocationMessage ids)

end Db

/-! ## 9. The dataref index as a view -/

/-- [SRC] 2026-10-15: an entry: the transaction, the block whose coinbase document referenced
it, its merkle proof's nodes (src/miner_id/dataref_index_detail.h:77-117). -/
structure IndexEntry where
  txid : Bytes
  blockId : Bytes
  minerInfo : Bool
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: the dataref index's contents (prefixes 'T' and 'I',
src/miner_id/dataref_index_detail.h:54-59). -/
abbrev DataRefIndex := List IndexEntry

/-- [SRC] 2026-10-15: the index's additions on a block (`ExtractMinerInfoTxnFromBlock`,
`ExtractDatarefTxnsFromBlock`, src/miner_id/dataref_index.cpp:18-65, called at
src/miner_id/miner_id_db.cpp:820-840): the miner-info transaction and each referenced
dataref transaction THAT IS IN THE BLOCK and has a proof; `hasProof` is the merkle tree's
answer (:783-800). -/
def indexBlock (idx : DataRefIndex) (block : Bytes) (txids : List Bytes) (f : Found)
    (hasProof : Bytes → Bool) : DataRefIndex :=
  let add (i : DataRefIndex) (t : Bytes) (mi : Bool) : DataRefIndex :=
    if txids.contains t && hasProof t then ⟨t, block, mi⟩ :: i.filter (fun e => !(e.txid == t && e.minerInfo == mi)) else i
  let i1 := match f.minerInfoTx with | some t => add idx t true | none => idx
  match f.doc.dataRefs with
  | some refs => txids.foldl (fun i t => if refs.any (fun r => parseHex r.txid == t.reverse) then add i t false else i) i1
  | none => i1

/-- [SRC] 2026-10-15: a disconnected block's Miner ID transactions leave the index
(src/txmempool.cpp:2494-2522), and `datareftxndelete` deletes one dataref
(src/rpc/miner_info.cpp:992-1021). -/
def unindex (idx : DataRefIndex) (t : Bytes) (minerInfo : Bool) : DataRefIndex :=
  idx.filter fun e => !(e.txid == t && e.minerInfo == minerInfo)

/-! ## 10. The RPC surface -/

/-- [SRC] 2026-10-15: one RPC of the `minerid` category: its name, its arguments, its result
fields and its source lines. -/
structure RpcRow where
  name : String
  args : List String
  result : List String
  src : String
  deriving Repr

/-- [SRC] 2026-10-15: the fourteen commands (src/rpc/miner_info.cpp:1053-1077, every one
`okSafeMode`), with the fields their handlers return. Two are documented short of what
they return: `dumpminerids` also returns `dbversion`, `name`, `reputation` (`M`, `void`,
`voidingid`), `nextminerid` and `prevminerid` (src/miner_id/miner_id_db.cpp:346-422 against
the help at src/rpc/miner_info.cpp:920-946), and `datarefindexdump` returns `nodes`
(src/miner_id/dataref_index.cpp:67-88 against :964-977). -/
def rpcSurface : List RpcRow :=
  [ ⟨"createminerinfotx", ["scriptPubKey hex: OP_FALSE OP_RETURN 601dface 00 minerinfo"], ["txid hex"],
      "src/rpc/miner_info.cpp:373-530 (the document's height must be the tip's plus one, :450-451)"⟩,
    ⟨"replaceminerinfotx", ["scriptPubKey hex"], ["txid hex"], "src/rpc/miner_info.cpp:532-558"⟩,
    ⟨"createdatareftx", ["array of scriptPubKey hex, each 601dface with a BRFC object"], ["txid hex"],
      "src/rpc/miner_info.cpp:305-371,560-585"⟩,
    ⟨"getminerinfotxid", [], ["txid hex or null"], "src/rpc/miner_info.cpp:588-612"⟩,
    ⟨"getdatareftxid", [], ["txid hex or null"], "src/rpc/miner_info.cpp:1023-1048"⟩,
    ⟨"makeminerinfotxsigningkey", [], ["null; writes miner_id/Funding/.minerinfotxsigningkey.dat"],
      "src/rpc/miner_info.cpp:614-670 (a fixed key on regtest, :631-636)"⟩,
    ⟨"getminerinfotxfundingaddress", [], ["base58 address"], "src/rpc/miner_info.cpp:672-699"⟩,
    ⟨"setminerinfotxfundingoutpoint", ["txid", "n"], ["null"], "src/rpc/miner_info.cpp:701-734"⟩,
    ⟨"datarefindexdump", [], ["[{txid, blockid, nodes}]"], "src/rpc/miner_info.cpp:960-990"⟩,
    ⟨"datareftxndelete", ["txid"], ["null"], "src/rpc/miner_info.cpp:992-1021"⟩,
    ⟨"rebuildminerids", ["fullrebuild (bool, default false)"], ["true"], "src/rpc/miner_info.cpp:736-770"⟩,
    ⟨"revokeminerid", ["{revocationKey, minerId, revocationMessage{compromised_minerId}, revocationMessageSig{sig1, sig2}}"],
      ["null; the revokemid message relayed to every peer"], "src/rpc/miner_info.cpp:772-868"⟩,
    ⟨"getmineridinfo", ["minerid (hex key)"], ["{minerId, minerIdState, prevMinerId, revocationKey, prevRevocationKey} or {}"],
      "src/rpc/miner_info.cpp:870-914"⟩,
    ⟨"dumpminerids", [], ["{state{dbversion, synced, bestblock}, miners[{uuid, name, firstblock, latestblock, numrecentblocks, reputation{M, void, voidingid}, minerids[{minerid, version, state, nextminerid, prevminerid, creationblock}]}]}"],
      "src/rpc/miner_info.cpp:916-958, src/miner_id/miner_id_db.cpp:346-422"⟩ ]

/-- [SRC] 2026-10-15: `getmineridinfo`'s answer as a view of the database (src/rpc/miner_info.cpp:901-913). -/
def Db.minerIdInfo (db : Db) (k : Bytes) : Option (Bytes × String × Bytes × Bytes × Bytes) :=
  (db.lookupId k).map fun e => (e.doc.minerId, e.state.name, e.doc.prevMinerId, e.doc.revocationKey, e.doc.prevRevocationKey)

end BsvChain.Views.MinerId
