import BsvScript.Tx
import BsvScript.Machine
import BsvScript.Hash.Sha256
/-!
# BsvScript.Sighash

The signature hash (#12; `docs/DESIGN.md` §4.3): the hash type
(`src/script/sighashtype.h:14–96`), the BIP143-style digest
`SignatureHashBIP143` (`interpreter.cpp:2034–2084`), the original digest
`SignatureHashOriginal` (`2086–2110`) with its serializer
`CTransactionSignatureSerializer` (`1841–1958`), the dispatch `SignatureHash`
(`2112–2124`), and the scriptCode preparation the signature opcodes perform
before hashing: `GetHashType` (`247–253`) and `CleanupScriptCode` (`255–263`,
`CScript::FindAndDelete`, `script.h:201–224`). The digest is SHA-256d
(`CHashWriter::GetHash`, `src/hash.h:199–204`). The serialization formats are
`src/primitives/transaction.h` (`COutPoint`: the txid as stored then the index;
`CTxOut`: the value then the script; the null `CTxOut()` has `nValue = -1`,
`src/primitives/transaction.h:196–199`) and `src/serialize.h` (`CompactSize`; every integer little-endian).
Bare line numbers are `interpreter.cpp` at the pin (`docs/PROVENANCE.md`).

**Q2 closed** (DESIGN §4.3, `[SRC]`): the original digest is reachable on
mainnet today. `SignatureHash` takes it whenever the type lacks the FORKID bit
or carries the CHRONICLE bit (`2118–2123`); under the mainnet flags since UAHF
(`SCRIPT_ENABLE_SIGHASH_FORKID` from height 478,558, `chainparams.cpp:1065`,
`verify_script_flags.cpp:54–58`) a signature without FORKID is refused by
`CheckSignatureEncoding` (`SCRIPT_ERR_MUST_USE_FORKID`, `305–306`), so the
non-FORKID path is historical replay; the CHRONICLE bit (`0x20`, accepted only
with `SCRIPT_CHRONICLE`, `302–303`) selects the original digest for a live
signature. Both paths are executable here.

**The truncated-push corner, MEASURED 2026-09-24** (the harness; `corpus/gen`,
`sighash/original/truncated-push/*`: six shapes of a truncated push after a
post-Genesis top-level `OP_RETURN`, each signed over the spec's serialization of
the unparseable scriptCode; the spec's own SV-node instance agrees with the spec
on all six, both instances; `docs/records/20260924-150154-sighash-family-s3.md`,
`corpus/INDEX.md` §2 and §4c; the `[EST]` that stood here until 2026-09-26 is
gone): `SerializeScriptCode` (`1862–1892`) on a scriptCode whose parse fails (a
truncated push after the signature opcode) writes a size prefix of the whole
script minus the separators it parsed (`1875`), then the bytes up to the
parser's failure point (`1887–1891`; `GetOp2`, `script.h:165–198`: the opcode
and, when present, the length prefix are consumed before the failure). The
definition below follows the code as written; T-SH11 states the walk case by
case.
-/

namespace BsvScript.Sighash
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash

/-! ## The hash type (`sighashtype.h:14–96`) -/

/-- The bits (`sighashtype.h:14–22`).
[LIT] https://protocol.bsvblockchain.org/specification/signature-hashing#the-sighash-type-byte at v1.2.2 (the six bits of SIGHASH_ALL to SIGHASH_ANYONECANPAY). -/
def SIGHASH_ALL : Nat := 1
def SIGHASH_NONE : Nat := 2
def SIGHASH_SINGLE : Nat := 3
def SIGHASH_CHRONICLE : Nat := 0x20
def SIGHASH_FORKID : Nat := 0x40
def SIGHASH_ANYONECANPAY : Nat := 0x80

/-- `SigHashType` (`sighashtype.h:39–96`): a 32-bit word, `raw < 2^32`. -/
structure SigHashType where
  raw : Nat
  deriving DecidableEq, Repr

/-- A 32-bit little-endian word (`serialize.h`, `ser_writedata32`). -/
def le32 (u : Nat) : Bytes := [u % 256, u / 256 % 256, u / 65536 % 256, u / 16777216 % 256]
/-- A 64-bit little-endian word. -/
def le64 (u : Nat) : Bytes := (List.range 8).map (fun i => u / 256 ^ i % 256)

namespace SigHashType
/-- `getBaseType` (`sighashtype.h:73–75`): the low five bits (`BASE_SIGHASH_MASK = 0x1F`, `:43`).
[LIT] https://protocol.bsvblockchain.org/specification/signature-hashing#the-sighash-type-byte at v1.2.2. -/
def baseType (t : SigHashType) : Nat := t.raw % 32
/-- `getForkValue` (`:77`): the word above the low byte.
[LIT] https://protocol.bsvblockchain.org/specification/signature-hashing#the-sighash-type-byte at v1.2.2. -/
def forkValue (t : SigHashType) : Nat := t.raw / 256
/-- `hasChronicle` (`:86`), `hasForkId` (`:87`), `hasAnyoneCanPay` (`:88`). -/
def hasChronicle (t : SigHashType) : Bool := Nat.testBit t.raw 5
def hasForkId (t : SigHashType) : Bool := Nat.testBit t.raw 6
def hasAnyoneCanPay (t : SigHashType) : Bool := Nat.testBit t.raw 7
/-- `isDefined` (`:79–84`): the word with the CHRONICLE, FORKID and ANYONECANPAY
bits cleared, converted to `BaseSigHashType`, must be `ALL`, `NONE` or `SINGLE`.
The enumeration is fixed on `uint8_t` (`:31`), so the conversion keeps the low
byte: the fork value above it never reaches the test, and what does is the low
byte with the three flag bits cleared, the base (`:73–75`). The reference's unit
test says the same over the fork values 0, 1, 0x123456, 0xfedcba and 0xffffff
(`src/test/sighashtype_tests.cpp:94`, `:104–114`). -/
def isDefined (t : SigHashType) : Bool := SIGHASH_ALL ≤ t.baseType && t.baseType ≤ SIGHASH_SINGLE
/-- `GetHashType` (`247–253`): the last byte of the signature; `0` for an empty
signature. -/
def ofSig (sig : Bytes) : SigHashType := { raw := sig.getLast?.getD 0 }
/-- `Serialize` (`:92–94`): the raw 32-bit word, little-endian. -/
def serialize (t : SigHashType) : Bytes := le32 t.raw
end SigHashType

/-! ## Serialization (`src/serialize.h`, `src/primitives/transaction.h`) -/

/-- `WriteCompactSize` (`serialize.h`). -/
def compactSize (n : Nat) : Bytes :=
  if n < 253 then [n]
  else if n ≤ 0xffff then 253 :: [n % 256, n / 256 % 256]
  else if n ≤ 0xffffffff then 254 :: le32 n
  else 255 :: le64 n

/-- A script as serialized (`CScriptBase`): `CompactSize` then the bytes. -/
def serScript (s : Bytes) : Bytes := compactSize s.length ++ s

/-- `nVersion` (`int32_t`) as its serialized word. -/
def serVersion (v : Int) : Bytes := le32 (v % (2 ^ 32)).toNat

/-- `COutPoint` (`transaction.h`): the txid as stored, then the index. -/
def serOutPoint (i : TxIn) : Bytes := i.prevHash ++ le32 i.prevIndex

/-- `CTxOut` (`transaction.h`): the value (`int64_t`), then the script. -/
def serTxOut (o : TxOut) : Bytes := le64 o.value ++ serScript o.scriptPubKey

/-- The null `CTxOut()` (`transaction.h:180, 196–199`): `nValue = -1` and an
empty script, serialized as `ff…ff 00`. -/
def serNullTxOut : Bytes := le64 (2 ^ 64 - 1) ++ serScript []

/-- `uint256()`: thirty-two zero bytes. -/
def zero32 : Bytes := List.replicate 32 0

/-- The input `nIn` of `tx`, or a null input when `nIn` is out of range (the
reference indexes `vin[nIn]` unchecked in `SignatureHashBIP143`; every caller
passes an index of the transaction being validated). -/
def inputAt (tx : Tx) (nIn : Nat) : TxIn :=
  tx.inputs[nIn]?.getD { prevHash := zero32, prevIndex := 0, scriptSig := [], sequence := 0 }

/-- `CTxIn` (`transaction.h`): the outpoint, the script, the sequence. -/
def serTxIn (i : TxIn) : Bytes := serOutPoint i ++ serScript i.scriptSig ++ le32 i.sequence

/-- `CTransaction` serialized (`transaction.h`, `SerializeTransaction`): version, the
inputs, the outputs, the lock time. -/
def serTx (tx : Tx) : Bytes :=
  serVersion tx.version ++ compactSize tx.inputs.length ++ (tx.inputs.map serTxIn).flatten
    ++ compactSize tx.outputs.length ++ (tx.outputs.map serTxOut).flatten ++ le32 tx.lockTime

/-- `CTransaction::GetId` (`transaction.cpp`): SHA-256d of the serialization, as stored. -/
def txid (tx : Tx) : Bytes := sha256d (serTx tx)

/-! ## The BIP143-style digest (`SignatureHashBIP143`, `2034–2084`) -/

/-- `GetPrevoutHash` (`1960–1966`): SHA-256d of every outpoint in order. -/
def hashPrevouts (tx : Tx) : Bytes := sha256d ((tx.inputs.map serOutPoint).flatten)
/-- `GetSequenceHash` (`1968–1974`): SHA-256d of every sequence in order. -/
def hashSequence (tx : Tx) : Bytes := sha256d ((tx.inputs.map (fun i => le32 i.sequence)).flatten)
/-- `GetOutputsHash` (`1976–1982`): SHA-256d of every output in order. -/
def hashOutputs (tx : Tx) : Bytes := sha256d ((tx.outputs.map serTxOut).flatten)

/-- `hashPrevouts` of the preimage (`2043–2045`): zero under ANYONECANPAY. -/
def bip143Prevouts (tx : Tx) (t : SigHashType) : Bytes :=
  if t.hasAnyoneCanPay then zero32 else hashPrevouts tx

/-- `hashSequence` of the preimage (`2047–2051`): zero under ANYONECANPAY,
SINGLE or NONE. -/
def bip143Sequence (tx : Tx) (t : SigHashType) : Bytes :=
  if t.hasAnyoneCanPay || t.baseType = SIGHASH_SINGLE || t.baseType = SIGHASH_NONE then zero32
  else hashSequence tx

/-- `hashOutputs` of the preimage (`2053–2061`): all outputs unless SINGLE or
NONE; under SINGLE the SHA-256d of the output at `nIn` when it exists; zero
otherwise (SINGLE past the outputs, and NONE). -/
def bip143Outputs (tx : Tx) (nIn : Nat) (t : SigHashType) : Bytes :=
  if t.baseType ≠ SIGHASH_SINGLE && t.baseType ≠ SIGHASH_NONE then hashOutputs tx
  else if t.baseType = SIGHASH_SINGLE then
    match tx.outputs[nIn]? with
    | some o => sha256d (serTxOut o)
    | none => zero32
  else zero32

/-- The preimage (`2063–2081`): version · hashPrevouts · hashSequence · the
outpoint · the scriptCode length-prefixed (whole, `2072`) · the amount
(`int64_t`, `2073`) · the sequence · hashOutputs · the lock time · the 4-byte
hash type. -/
def preimageBIP143 (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) (amount : Nat) : Bytes :=
  serVersion tx.version ++ bip143Prevouts tx t ++ bip143Sequence tx t
    ++ serOutPoint (inputAt tx nIn) ++ serScript scriptCode ++ le64 amount
    ++ le32 (inputAt tx nIn).sequence ++ bip143Outputs tx nIn t ++ le32 tx.lockTime ++ t.serialize

/-- `SignatureHashBIP143`: SHA-256d of the preimage (`2083`). -/
def sighashBIP143 (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) (amount : Nat) : Bytes :=
  sha256d (preimageBIP143 scriptCode tx nIn t amount)

/-! ## The original digest (`SignatureHashOriginal`, `2086–2110`; the serializer `1841–1958`) -/

/-- The bytes `GetOp2` consumes before failing on a truncated push
(`script.h:175–193`): the opcode, then the length prefix when it is wholly
present. -/
def truncatedHead (op : Nat) (rest : Bytes) : Bytes :=
  if op = Op.OP_PUSHDATA1 then op :: (if 1 ≤ rest.length then rest.take 1 else [])
  else if op = Op.OP_PUSHDATA2 then op :: (if 2 ≤ rest.length then rest.take 2 else [])
  else if op = Op.OP_PUSHDATA4 then op :: (if 4 ≤ rest.length then rest.take 4 else [])
  else [op]

/-- The walk of `SerializeScriptCode` (`1862–1892`): the count of
`OP_CODESEPARATOR`s the parser reached and the bytes written (every parsed
`OP_CODESEPARATOR` byte removed; a failed parse ends the bytes after
`truncatedHead`). -/
def scriptCodeWalk : Bytes → Nat × Bytes
  | [] => (0, [])
  | op :: rest =>
    match Machine.getOpTail op rest with
    | none => (0, truncatedHead op rest)
    | some (_, k) =>
      let (n, tl) := scriptCodeWalk (rest.drop k)
      if op = Op.OP_CODESEPARATOR then (n + 1, tl) else (n, op :: rest.take k ++ tl)
termination_by s => s.length
decreasing_by all_goals simp [List.length_drop]

/-- `SerializeScriptCode` (`1862–1892`): the size prefix is the script's size
minus the separators parsed (`1874`); then the bytes of the walk. -/
def serScriptCodeOriginal (scriptCode : Bytes) : Bytes :=
  let (nSeps, body) := scriptCodeWalk scriptCode
  compactSize (scriptCode.length - nSeps) ++ body

/-- `SerializeInput` (`1894–1916`): under ANYONECANPAY only the signed input
(`1898–1900`); the outpoint; the scriptCode for the signed input, an empty
script for the others (`1902–1907`); the sequence, zero for the other inputs
under SINGLE or NONE (`1909–1915`). -/
def serInputOriginal (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) (nInput : Nat) : Bytes :=
  let idx := if t.hasAnyoneCanPay then nIn else nInput
  let input := inputAt tx idx
  serOutPoint input
    ++ (if idx ≠ nIn then serScript [] else serScriptCodeOriginal scriptCode)
    ++ (if idx ≠ nIn && (t.baseType = SIGHASH_SINGLE || t.baseType = SIGHASH_NONE) then le32 0
        else le32 input.sequence)

/-- `SerializeOutput` (`1918–1928`): under SINGLE every output but `nIn` is the
null `CTxOut()`; otherwise the output itself. -/
def serOutputOriginal (tx : Tx) (nIn : Nat) (t : SigHashType) (nOutput : Nat) : Bytes :=
  if t.baseType = SIGHASH_SINGLE && nOutput ≠ nIn then serNullTxOut
  else
    match tx.outputs[nOutput]? with
    | some o => serTxOut o
    | none => []

/-- `Serialize` (`1930–1957`): version; the inputs (one under ANYONECANPAY);
the outputs (none under NONE, `nIn + 1` under SINGLE, all otherwise); the lock
time. -/
def serTxOriginal (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) : Bytes :=
  let nInputs := if t.hasAnyoneCanPay then 1 else tx.inputs.length
  let nOutputs :=
    if t.baseType = SIGHASH_NONE then 0
    else if t.baseType = SIGHASH_SINGLE then nIn + 1
    else tx.outputs.length
  serVersion tx.version
    ++ compactSize nInputs ++ ((List.range nInputs).map (serInputOriginal scriptCode tx nIn t)).flatten
    ++ compactSize nOutputs ++ ((List.range nOutputs).map (serOutputOriginal tx nIn t)).flatten
    ++ le32 tx.lockTime

/-- `one` (`uint256S("00…01")`, `2089`), returned unhashed when `nIn` is out of
range (`2090–2093`) or SINGLE has no output at `nIn` (`2095–2100`): as stored,
`01` then thirty-one zeros. -/
def one256 : Bytes := 1 :: List.replicate 31 0

/-- `SignatureHashOriginal` (`2086–2110`). -/
def sighashOriginal (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) : Bytes :=
  if tx.inputs.length ≤ nIn then one256
  else if t.baseType = SIGHASH_SINGLE && tx.outputs.length ≤ nIn then one256
  else sha256d (serTxOriginal scriptCode tx nIn t ++ t.serialize)

/-! ## The dispatch (`SignatureHash`, `2112–2124`) -/

/-- `SignatureHash`: the BIP143 digest iff FORKID is enabled by the flags and
the type has the FORKID bit and not the CHRONICLE bit (`2118–2121`); the
original digest otherwise (`2123`). -/
def sighash (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) (amount : Nat)
    (enabledSighashForkid : Bool) : Bytes :=
  if enabledSighashForkid && t.hasForkId && !t.hasChronicle then sighashBIP143 scriptCode tx nIn t amount
  else sighashOriginal scriptCode tx nIn t

/-! ## The scriptCode preparation (`CleanupScriptCode`, `255–263`) -/

/-- `CScript::operator<<(const std::vector<uint8_t>&)` (`script.h:104–133`):
the push of `b` with the smallest push opcode for its size. `CScript(vchSig)`
(`script.h:71`) is this push. -/
def pushData (b : Bytes) : Bytes :=
  if b.length < Op.OP_PUSHDATA1 then b.length :: b
  else if b.length ≤ 0xff then Op.OP_PUSHDATA1 :: b.length :: b
  else if b.length ≤ 0xffff then Op.OP_PUSHDATA2 :: [b.length % 256, b.length / 256 % 256] ++ b
  else Op.OP_PUSHDATA4 :: le32 b.length ++ b

/-- Strip every copy of `b` at the front of `s` (`script.h:210–214`); `fuel`
bounds the loop (`b` is never empty at the call). -/
def stripPrefixes : Nat → Bytes → Bytes → Bytes
  | 0, s, _ => s
  | fuel + 1, s, b => if b.isPrefixOf s then stripPrefixes fuel (s.drop b.length) b else s

/-- The loop of `FindAndDelete` (`script.h:208–221`): at every opcode boundary
strip the copies of `b` that start there, then copy the next opcode with its
data; a tail the parser cannot read is copied as it is (`script.h:219`). -/
def findAndDeleteLoop (b : Bytes) : Nat → Bytes → Bytes
  | 0, s => s
  | fuel + 1, s =>
    let s' := stripPrefixes (s.length + 1) s b
    match s' with
    | [] => []
    | op :: rest =>
      match Machine.getOpTail op rest with
      | none => s'
      | some (_, k) => op :: rest.take k ++ findAndDeleteLoop b fuel (rest.drop k)

/-- `CScript::FindAndDelete` (`script.h:201–224`): the script with every copy
of `b` the walk meets removed, single pass. The walk compares at its own
positions, the start of each instruction `GetOp` reads from where the walk
stands and the end of each copy it deletes, so a deletion shifts the positions
the parse sees (T-SH12, T-SH12a; the two examples after the reference's unit
cases); an empty `b` changes nothing (`script.h:204`). -/
def findAndDelete (script b : Bytes) : Bytes :=
  if b = [] then script else findAndDeleteLoop b (script.length + 1) script

/-- `CleanupScriptCode` (`255–263`): when FORKID is not enabled by the flags or
the signature's type lacks the FORKID bit, the push of the signature is deleted
from the scriptCode before hashing. -/
def cleanupScriptCode (scriptCode sig : Bytes) (enabledSighashForkid : Bool) : Bytes :=
  if !enabledSighashForkid || !(SigHashType.ofSig sig).hasForkId then findAndDelete scriptCode (pushData sig)
  else scriptCode

/-! ## The reference's `FindAndDelete` unit cases (`src/test/script_tests.cpp:3819–3934`),
checked by the kernel. -/

example : findAndDelete [0x51, 0x52] [] = [0x51, 0x52] := by decide
example : findAndDelete [0x51, 0x52, 0x53] [0x52] = [0x51, 0x53] := by decide
example : findAndDelete [0x53, 0x51, 0x53, 0x53, 0x54, 0x53] [0x53] = [0x51, 0x54] := by decide
example : findAndDelete [0x03, 0x02, 0xff, 0x03] [0x03, 0x02, 0xff, 0x03] = [] := by decide
example : findAndDelete [0x03, 0x02, 0xff, 0x03, 0x03, 0x02, 0xff, 0x03] [0x03, 0x02, 0xff, 0x03] = [] := by decide
example : findAndDelete [0x03, 0x02, 0xff, 0x03, 0x03, 0x02, 0xff, 0x03] [0x02]
    = [0x03, 0x02, 0xff, 0x03, 0x03, 0x02, 0xff, 0x03] := by decide
example : findAndDelete [0x03, 0x02, 0xff, 0x03, 0x03, 0x02, 0xff, 0x03] [0xff]
    = [0x03, 0x02, 0xff, 0x03, 0x03, 0x02, 0xff, 0x03] := by decide
example : findAndDelete [0x03, 0x02, 0xff, 0x03, 0x03, 0x02, 0xff, 0x03] [0x03]
    = [0x02, 0xff, 0x03, 0x02, 0xff, 0x03] := by decide
example : findAndDelete [0x02, 0xfe, 0xed, 0x51, 0x69] [0xfe, 0xed, 0x51] = [0x02, 0xfe, 0xed, 0x51, 0x69] := by decide
example : findAndDelete [0x02, 0xfe, 0xed, 0x51, 0x69] [0x02, 0xfe, 0xed, 0x51] = [0x69] := by decide
example : findAndDelete [0x51, 0x69, 0x02, 0xfe, 0xed, 0x51, 0x69] [0xfe, 0xed, 0x51]
    = [0x51, 0x69, 0x02, 0xfe, 0xed, 0x51, 0x69] := by decide
example : findAndDelete [0x51, 0x69, 0x02, 0xfe, 0xed, 0x51, 0x69] [0x02, 0xfe, 0xed, 0x51] = [0x51, 0x69, 0x69] := by decide
example : findAndDelete [0x00, 0x00, 0x51, 0x51] [0x00, 0x51] = [0x00, 0x51] := by decide
example : findAndDelete [0x00, 0x00, 0x51, 0x00, 0x51, 0x51] [0x00, 0x51] = [0x00, 0x51] := by decide
example : findAndDelete [0x00, 0x03, 0xfe, 0xed] [0x03, 0xfe, 0xed] = [0x00] := by decide
example : findAndDelete [0x00, 0x03, 0xfe, 0xed] [0x00] = [0x03, 0xfe, 0xed] := by decide
-- Not a unit case of the reference: a copy that begins where a deleted copy ended is compared without a parse, so it
-- matches inside the push it sits in (`script.h:210–214`; #32's re-lens, part D, N2; T-SH12a).
example : findAndDelete [0x03, 0x03, 0x02, 0xff] [0x03] = [0x02, 0xff] := by decide
-- The other direction (#32's second re-lens, residue 4): after the deletion at offset 0 the walk parses from offset 2
-- and reads `0x4c 0x01 0x00` as one push, so the copy at offset 4, an instruction start of the script itself, is kept.
example : findAndDelete [0x00, 0x02, 0x4c, 0x01, 0x00, 0x02] [0x00, 0x02] = [0x4c, 0x01, 0x00, 0x02] := by decide

/-! ## Widths (the layout pinned by theorem) -/

/-- A 32-bit little-endian word is four bytes (`ser_writedata32`, `serialize.h`). -/
theorem le32_length (u : Nat) : (le32 u).length = 4 := by simp [le32]
/-- A 64-bit little-endian word is eight bytes (the amount's field). -/
theorem le64_length (u : Nat) : (le64 u).length = 8 := by simp [le64]
/-- The null hash BIP143 substitutes for a field the type leaves out is 32 bytes. -/
theorem zero32_length : zero32.length = 32 := by simp [zero32]
/-- The serialized version is four bytes (the `int32_t` `nVersion`, little-endian). -/
theorem serVersion_length (v : Int) : (serVersion v).length = 4 := le32_length _
/-- The serialized type is four bytes: the raw 32-bit word (`sighashtype.h:92–94`). -/
theorem SigHashType.serialize_length (t : SigHashType) : t.serialize.length = 4 := le32_length _
/-- An outpoint serializes as its txid as stored and a four-byte index (`COutPoint`,
`src/primitives/transaction.h`). -/
theorem serOutPoint_length (i : TxIn) : (serOutPoint i).length = i.prevHash.length + 4 := by
  simp [serOutPoint, le32]
/-- BIP143's `hashPrevouts` field is 32 bytes: a SHA-256d, or the null hash under ANYONECANPAY. -/
theorem bip143Prevouts_length (tx : Tx) (t : SigHashType) : (bip143Prevouts tx t).length = 32 := by
  unfold bip143Prevouts; split <;> simp [zero32, hashPrevouts, sha256d_length]
/-- BIP143's `hashSequence` field is 32 bytes: a SHA-256d, or the null hash under ANYONECANPAY, SINGLE or NONE. -/
theorem bip143Sequence_length (tx : Tx) (t : SigHashType) : (bip143Sequence tx t).length = 32 := by
  unfold bip143Sequence; split <;> simp [zero32, hashSequence, sha256d_length]
/-- BIP143's `hashOutputs` field is 32 bytes: the SHA-256d of every output, of the one output at `nIn` under SINGLE,
or the null hash. -/
theorem bip143Outputs_length (tx : Tx) (nIn : Nat) (t : SigHashType) : (bip143Outputs tx nIn t).length = 32 := by
  unfold bip143Outputs
  split
  · simp [hashOutputs, sha256d_length]
  · split
    · split <;> simp [zero32, sha256d_length]
    · simp [zero32]

/-- T-SH1: the BIP143 preimage has the fixed layout width: 124 bytes of fixed
fields, the outpoint's hash, and the length-prefixed scriptCode. With a 32-byte
txid, `156 + (serScript scriptCode).length`. -/
theorem preimageBIP143_length (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) (amount : Nat) :
    (preimageBIP143 scriptCode tx nIn t amount).length
      = 124 + (inputAt tx nIn).prevHash.length + (serScript scriptCode).length := by
  simp only [preimageBIP143, List.length_append, serVersion_length, bip143Prevouts_length,
    bip143Sequence_length, serOutPoint_length, le64_length, le32_length, bip143Outputs_length,
    SigHashType.serialize_length]
  omega

/-- The BIP143 digest is 32 bytes: a SHA-256d (`CHashWriter::GetHash`, `src/hash.h:199–204`). -/
theorem sighashBIP143_length (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) (amount : Nat) :
    (sighashBIP143 scriptCode tx nIn t amount).length = 32 := sha256d_length _
/-- The constant `one` the original digest returns in its two failure cases (`2090–2100`) is 32 bytes. -/
theorem one256_length : one256.length = 32 := by simp [one256]
/-- The original digest is 32 bytes: the constant `one` (T-SH3, T-SH4) or a SHA-256d. -/
theorem sighashOriginal_length (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) :
    (sighashOriginal scriptCode tx nIn t).length = 32 := by
  unfold sighashOriginal; split
  · exact one256_length
  · split
    · exact one256_length
    · exact sha256d_length _
/-- T-SH2: every digest `SignatureHash` returns is 32 bytes (`2112–2124`: the BIP143 digest or the original, each
32 bytes by the two theorems above). -/
theorem sighash_length (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) (amount : Nat) (e : Bool) :
    (sighash scriptCode tx nIn t amount e).length = 32 := by
  unfold sighash; split
  · exact sighashBIP143_length _ _ _ _ _
  · exact sighashOriginal_length _ _ _ _

/-- T-SH3: the original digest of an input index past the inputs is `one`
(`2090–2093`), whatever the type. -/
theorem sighashOriginal_nIn_out_of_range (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType)
    (h : tx.inputs.length ≤ nIn) : sighashOriginal scriptCode tx nIn t = one256 := by
  simp [sighashOriginal, h]

/-- T-SH4: the original digest under SINGLE with no output at `nIn` is `one`
(`2095–2100`): the known "SIGHASH_SINGLE bug", a signature over the constant. -/
theorem sighashOriginal_single_no_output (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType)
    (hs : t.baseType = SIGHASH_SINGLE) (h : tx.outputs.length ≤ nIn) :
    sighashOriginal scriptCode tx nIn t = one256 := by
  unfold sighashOriginal; split
  · rfl
  · simp [hs, h]

/-- T-SH5: an empty pattern deletes nothing (`script.h:204`). -/
theorem findAndDelete_nil (script : Bytes) : findAndDelete script [] = script := by
  simp [findAndDelete]

/-! ## The dispatch, the type, the scriptCode and the shapes as theorems (archived #25, the Lean families, 2026-09-26) -/

/-- T-SH6: `SignatureHash`'s dispatch as the reference writes it (`2118–2123`): the BIP143 digest
iff `SCRIPT_ENABLE_SIGHASH_FORKID` is on, the type carries the FORKID bit and not the CHRONICLE
bit; the original digest otherwise. Its four corners are the next four theorems. bsv-rs 0.3.28
computes the BIP143 digest for every type (`spend.rs:1953–1962` at 0.3.28; the crate class
`sighash.dispatch.chronicle-bip143`, `corpus/INDEX.md` §4). -/
theorem sighash_dispatch (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) (amount : Nat) (e : Bool) :
    sighash scriptCode tx nIn t amount e
      = (if e && t.hasForkId && !t.hasChronicle then sighashBIP143 scriptCode tx nIn t amount
         else sighashOriginal scriptCode tx nIn t) := rfl

/-- T-SH6a: the live mainnet path (`2118–2120`): FORKID enabled, the FORKID bit, no CHRONICLE bit. -/
theorem sighash_eq_bip143 (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) (amount : Nat)
    (hf : t.hasForkId = true) (hc : t.hasChronicle = false) :
    sighash scriptCode tx nIn t amount true = sighashBIP143 scriptCode tx nIn t amount := by
  simp [sighash, hf, hc]

/-- T-SH6b: with FORKID not enabled every type takes the original digest (`2118`, `2123`): the
pre-UAHF path, replayed by the mainnet vectors of `corpus/sighash/mainnet.jsonl` (block 400,000). -/
theorem sighash_original_of_not_enabled (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) (amount : Nat) :
    sighash scriptCode tx nIn t amount false = sighashOriginal scriptCode tx nIn t := by
  simp [sighash]

/-- T-SH6c (Q2): a type with the CHRONICLE bit takes the original digest whatever else is set
(`2118`, `2123`); the bit is legal under `SCRIPT_CHRONICLE` (`302–303`;
`Properties.checkSignatureEncoding_illegalChronicle`), so the original digest is live on mainnet
today: CONFIRMED BY EXECUTION on the spec's own SV-node instance, both instances (`corpus/gen`
`sighash/original/*` and `sighash/dispatch/*`; `docs/records/20260924-150154-sighash-family-s3.md`;
DESIGN §4.3). -/
theorem sighash_original_of_chronicle (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) (amount : Nat)
    (e : Bool) (hc : t.hasChronicle = true) :
    sighash scriptCode tx nIn t amount e = sighashOriginal scriptCode tx nIn t := by
  simp [sighash, hc]

/-- T-SH6d: a type without the FORKID bit takes the original digest (`2118`, `2123`); under
STRICTENC with FORKID enabled such a signature is refused before hashing
(`SCRIPT_ERR_MUST_USE_FORKID`, `305–306`; `Properties.checkSignatureEncoding_mustUseForkid`), so on
mainnet since UAHF this corner is historical replay. -/
theorem sighash_original_of_no_forkid_bit (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) (amount : Nat)
    (e : Bool) (hf : t.hasForkId = false) :
    sighash scriptCode tx nIn t amount e = sighashOriginal scriptCode tx nIn t := by
  simp [sighash, hf]

/-- The base type is five bits (`sighashtype.h:73–75`; `BASE_SIGHASH_MASK = 0x1F`, `:43`). -/
theorem SigHashType.baseType_lt (t : SigHashType) : t.baseType < 32 := Nat.mod_lt _ (by decide)

/-- T-SH7: `isDefined` (`sighashtype.h:79–84`) as a predicate on the base: defined iff the base
(`:73–75`) is `ALL`, `NONE` or `SINGLE`, whatever the three flag bits and the fork value above the
low byte (`isDefined_add_forkValue`). The undefined types are the bases 0 and 4–31
(`not_isDefined_of_base`); under STRICTENC the reference refuses them before hashing
(`293–294`, `SCRIPT_ERR_SIG_HASHTYPE`; `Properties.checkSignatureEncoding_sigHashtype`), where
bsv-rs 0.3.28 verifies over the BIP143 digest of the undefined type (the crate class
`sighash.type.undefined-base`, `spend.rs:1739–1766` at 0.3.28; `corpus/gen` `sighash/type/undefined/*`, the
spec's own SV-node instance agreeing with the spec on all three, `corpus/INDEX.md` §4c). -/
theorem SigHashType.isDefined_iff (t : SigHashType) :
    t.isDefined = true ↔ 1 ≤ t.baseType ∧ t.baseType ≤ 3 := by
  show (decide (1 ≤ t.baseType) && decide (t.baseType ≤ 3)) = true ↔ _
  simp only [Bool.and_eq_true, decide_eq_true_eq]

/-- T-SH7a: the undefined bases (`sighashtype.h:82–83`): 0, and 4 to 31. -/
theorem SigHashType.not_isDefined_of_base (t : SigHashType) (h : t.baseType = 0 ∨ 4 ≤ t.baseType) :
    t.isDefined = false := by
  rw [Bool.eq_false_iff, Ne, SigHashType.isDefined_iff]; omega

/-- T-SH7b: the fork value above the low byte (`sighashtype.h:77`) never reaches `isDefined`: a word
and the same word with any multiple of 256 added are defined together (the conversion to the `uint8_t`
enumeration, `:31`, `:80–81`; the reference's unit test over five fork values,
`src/test/sighashtype_tests.cpp:94`, `:104–114`). -/
theorem SigHashType.isDefined_add_forkValue (t : SigHashType) (f : Nat) :
    (⟨t.raw + 256 * f⟩ : SigHashType).isDefined = t.isDefined := by
  have h : (t.raw + 256 * f) % 32 = t.raw % 32 := by omega
  show (decide (SIGHASH_ALL ≤ (t.raw + 256 * f) % 32) && decide ((t.raw + 256 * f) % 32 ≤ SIGHASH_SINGLE))
    = (decide (SIGHASH_ALL ≤ t.raw % 32) && decide (t.raw % 32 ≤ SIGHASH_SINGLE))
  rw [h]

/-- `GetHashType` reads the signature's last byte (`252`). -/
theorem SigHashType.ofSig_raw (sig : Bytes) : (SigHashType.ofSig sig).raw = sig.getLast?.getD 0 := rfl

/-- An empty signature reads as type 0 (`248–250`), which is undefined (`isDefined_zero`); the
encoding check passes an empty signature before reading its type (`272–273`, T-C2) and `CheckSig`
fails it without hashing (`2145–2147`, `Properties.checksig_empty_sig`). -/
theorem SigHashType.ofSig_nil : SigHashType.ofSig [] = ⟨0⟩ := rfl

/-- Type 0 is undefined (`sighashtype.h:82–83`: the stripped word is below `ALL`). -/
theorem SigHashType.isDefined_zero : (⟨0⟩ : SigHashType).isDefined = false := by decide

/-- The type read from a byte-valued signature is one byte (`252`: a `uint8_t`). -/
theorem SigHashType.ofSig_raw_lt (sig : Bytes) (hv : ∀ b ∈ sig, b < 256) : (SigHashType.ofSig sig).raw < 256 := by
  rw [SigHashType.ofSig_raw]
  cases h : sig.getLast? with
  | none => simp
  | some b => simpa using hv b (List.mem_of_getLast? h)

/-- T-SH7c: a signature's type is defined iff the low five bits of its last byte (`GetHashType`,
`252`; an empty signature reads 0) are 1, 2 or 3. -/
theorem SigHashType.isDefined_ofSig_iff (sig : Bytes) :
    (SigHashType.ofSig sig).isDefined = true
      ↔ 1 ≤ sig.getLast?.getD 0 % 32 ∧ sig.getLast?.getD 0 % 32 ≤ 3 :=
  SigHashType.isDefined_iff _

/-- T-SH8: `CleanupScriptCode` (`255–263`): with FORKID enabled and the FORKID bit set the scriptCode
is hashed as it is (`260`: neither disjunct holds, nothing deleted). -/
theorem cleanupScriptCode_forkid (scriptCode sig : Bytes) (h : (SigHashType.ofSig sig).hasForkId = true) :
    cleanupScriptCode scriptCode sig true = scriptCode := by
  simp [cleanupScriptCode, h]

/-- T-SH8a: with FORKID not enabled the push of the signature is deleted first (`260–261`;
`FindAndDelete`, `script.h:201–224`): the pre-UAHF path. -/
theorem cleanupScriptCode_of_not_enabled (scriptCode sig : Bytes) :
    cleanupScriptCode scriptCode sig false = findAndDelete scriptCode (pushData sig) := by
  simp [cleanupScriptCode]

/-- T-SH8b: a signature without the FORKID bit is deleted from the scriptCode whatever the flags
(`260–261`). bsv-rs 0.3.24 deleted every signature (`spend.rs:1356–1361`, `:1509–1512` at 0.3.24; the class
`sighash.scriptcode.findanddelete`, `corpus/INDEX.md` §2); from 0.3.27 it deletes only a signature without the
FORKID bit, the reference's rule, and the pinned 0.3.32 keeps that guard (`spend.rs:1814–1820`, `:2031–2035`). -/
theorem cleanupScriptCode_of_no_forkid_bit (scriptCode sig : Bytes) (e : Bool)
    (h : (SigHashType.ofSig sig).hasForkId = false) :
    cleanupScriptCode scriptCode sig e = findAndDelete scriptCode (pushData sig) := by
  simp [cleanupScriptCode, h]

/-- `CScript(vchSig)` (`script.h:71`, `script.h:104–133`), the pattern `FindAndDelete` looks for, is never
empty: a push opcode always precedes the bytes (written at `script.h:131`). -/
theorem pushData_ne_nil (b : Bytes) : pushData b ≠ [] := by
  unfold pushData; split_ifs <;> simp

/-- Its length is the signature's plus the push opcode's: 1, 2, 3 or 5 bytes by the size class
(`script.h:106–130`: a direct push below `OP_PUSHDATA1`, then `OP_PUSHDATA1`, `OP_PUSHDATA2`,
`OP_PUSHDATA4` with their 1-, 2- and 4-byte prefixes). -/
theorem pushData_length (b : Bytes) :
    (pushData b).length
      = b.length + (if b.length < Op.OP_PUSHDATA1 then 1 else if b.length ≤ 0xff then 2 else if b.length ≤ 0xffff then 3 else 5) := by
  unfold pushData
  split_ifs <;> simp [le32]

/-- T-SH11: the bytes `GetOp2` consumes before failing on a truncated push (`script.h:171–193`: the length prefix
at `script.h:180–191`, the data-length test at `script.h:192–193`) are
the opcode and, for `OP_PUSHDATA1/2/4`, the length prefix when wholly present: one to five bytes. -/
theorem truncatedHead_length_le (op : Nat) (rest : Bytes) : (truncatedHead op rest).length ≤ 5 := by
  unfold truncatedHead; split_ifs <;> simp [List.length_take]

/-- The opcode itself is always consumed (`script.h:173`). -/
theorem truncatedHead_length_pos (op : Nat) (rest : Bytes) : 0 < (truncatedHead op rest).length := by
  unfold truncatedHead; split_ifs <;> simp

/-- A truncated direct push (`0x01`–`0x4b`) leaves the opcode alone (`script.h:178–179`, `script.h:192–193`). -/
theorem truncatedHead_of_not_pushdata (op : Nat) (rest : Bytes) (h1 : op ≠ Op.OP_PUSHDATA1) (h2 : op ≠ Op.OP_PUSHDATA2)
    (h4 : op ≠ Op.OP_PUSHDATA4) : truncatedHead op rest = [op] := by
  simp [truncatedHead, h1, h2, h4]

/-- T-SH11a: `SerializeScriptCode`'s walk (`1862–1892`) by cases: nothing for an empty scriptCode. -/
theorem scriptCodeWalk_nil : scriptCodeWalk [] = (0, []) := by simp [scriptCodeWalk]

/-- T-SH11b: a parse failure ends the bytes after `truncatedHead` (`1870`, `1887–1891`: the tail
from the last boundary to where `GetOp` stopped), no separator counted after it. MEASURED
2026-09-24 (the module docstring above). -/
theorem scriptCodeWalk_truncated (op : Nat) (rest : Bytes) (h : Machine.getOpTail op rest = none) :
    scriptCodeWalk (op :: rest) = (0, truncatedHead op rest) := by
  rw [scriptCodeWalk]; simp [h]

/-- `OP_CODESEPARATOR` parses as a bare opcode (`script.h:176`: no immediate operand above
`OP_PUSHDATA4`). -/
theorem getOpTail_codesep (rest : Bytes) : Machine.getOpTail Op.OP_CODESEPARATOR rest = some ([], 0) := by
  simp [Machine.getOpTail, Op.OP_CODESEPARATOR, Op.OP_PUSHDATA4]

/-- T-SH11c: an `OP_CODESEPARATOR` at an opcode boundary is counted (`1871–1873`) and dropped
(`1879–1883`: the bytes before it written, the boundary moved past it). -/
theorem scriptCodeWalk_codesep (rest : Bytes) :
    scriptCodeWalk (Op.OP_CODESEPARATOR :: rest) = ((scriptCodeWalk rest).1 + 1, (scriptCodeWalk rest).2) := by
  rw [scriptCodeWalk]; simp [getOpTail_codesep]

/-- T-SH11d: every other parsed instruction is copied with its data (`1877–1891`: it lies between
two boundaries, or before the end). -/
theorem scriptCodeWalk_op (op : Nat) (rest data : Bytes) (k : Nat) (h : Machine.getOpTail op rest = some (data, k))
    (hs : op ≠ Op.OP_CODESEPARATOR) :
    scriptCodeWalk (op :: rest) = ((scriptCodeWalk (rest.drop k)).1, op :: rest.take k ++ (scriptCodeWalk (rest.drop k)).2) := by
  rw [scriptCodeWalk]; simp [h, hs]

/-- T-SH11e: the size prefix of a truncated scriptCode counts the whole script (`1875`: the
script's size minus the separators parsed, none before the failure). -/
theorem serScriptCodeOriginal_truncated (op : Nat) (rest : Bytes) (h : Machine.getOpTail op rest = none) :
    serScriptCodeOriginal (op :: rest) = compactSize (rest.length + 1) ++ truncatedHead op rest := by
  simp [serScriptCodeOriginal, scriptCodeWalk_truncated op rest h]

/-- T-SH9: the three hashes of the BIP143 preimage under the type (`2043–2060`): `hashPrevouts` is
zero under ANYONECANPAY (`2043–2045`) … -/
theorem bip143Prevouts_anyonecanpay (tx : Tx) (t : SigHashType) (h : t.hasAnyoneCanPay = true) :
    bip143Prevouts tx t = zero32 := by
  simp [bip143Prevouts, h]

/-- … and the digest of every outpoint otherwise (`2043–2045`, `GetPrevoutHash` `1960–1966`). -/
theorem bip143Prevouts_all (tx : Tx) (t : SigHashType) (h : t.hasAnyoneCanPay = false) :
    bip143Prevouts tx t = hashPrevouts tx := by
  simp [bip143Prevouts, h]

/-- T-SH9a: `hashSequence` is zero under ANYONECANPAY, SINGLE or NONE (`2047–2051`). -/
theorem bip143Sequence_zero (tx : Tx) (t : SigHashType)
    (h : t.hasAnyoneCanPay = true ∨ t.baseType = SIGHASH_SINGLE ∨ t.baseType = SIGHASH_NONE) :
    bip143Sequence tx t = zero32 := by
  unfold bip143Sequence; rcases h with h | h | h <;> simp [h]

/-- … and the digest of every sequence otherwise (`2047–2051`, `GetSequenceHash` `1968–1974`). -/
theorem bip143Sequence_all (tx : Tx) (t : SigHashType) (h1 : t.hasAnyoneCanPay = false)
    (h2 : t.baseType ≠ SIGHASH_SINGLE) (h3 : t.baseType ≠ SIGHASH_NONE) : bip143Sequence tx t = hashSequence tx := by
  simp [bip143Sequence, h1, h2, h3]

/-- T-SH9b: `hashOutputs` is zero under NONE (`2053–2060`: neither branch assigns it). -/
theorem bip143Outputs_none (tx : Tx) (nIn : Nat) (t : SigHashType) (h : t.baseType = SIGHASH_NONE) :
    bip143Outputs tx nIn t = zero32 := by
  simp [bip143Outputs, h, SIGHASH_NONE, SIGHASH_SINGLE]

/-- T-SH9c: under SINGLE it is the digest of the matching output when it exists (`2056–2060`). -/
theorem bip143Outputs_single (tx : Tx) (nIn : Nat) (t : SigHashType) (o : TxOut) (h : t.baseType = SIGHASH_SINGLE)
    (ho : tx.outputs[nIn]? = some o) : bip143Outputs tx nIn t = sha256d (serTxOut o) := by
  simp [bip143Outputs, h, ho, SIGHASH_NONE, SIGHASH_SINGLE]

/-- T-SH9d: under SINGLE past the outputs it is zero (`2056–2057`: the guard `nIn < vout.size()`
fails and nothing assigns it): no `one` return on the BIP143 path, unlike the original digest's
T-SH4. -/
theorem bip143Outputs_single_past (tx : Tx) (nIn : Nat) (t : SigHashType) (h : t.baseType = SIGHASH_SINGLE)
    (ho : tx.outputs.length ≤ nIn) : bip143Outputs tx nIn t = zero32 := by
  have : tx.outputs[nIn]? = none := List.getElem?_eq_none ho
  simp [bip143Outputs, h, this, SIGHASH_NONE, SIGHASH_SINGLE]

/-- T-SH9e: every output otherwise (`2053–2055`, `GetOutputsHash` `1976–1982`). -/
theorem bip143Outputs_all (tx : Tx) (nIn : Nat) (t : SigHashType) (h2 : t.baseType ≠ SIGHASH_SINGLE)
    (h3 : t.baseType ≠ SIGHASH_NONE) : bip143Outputs tx nIn t = hashOutputs tx := by
  simp [bip143Outputs, h2, h3]

/-- T-SH10: the original serializer's blanking (`SerializeInput`, `1895–1919`): every input other
than the signed one carries an empty script (`1904–1906`) and, under SINGLE or NONE, a zero
sequence (`1911–1916`). -/
theorem serInputOriginal_other (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) (nInput : Nat)
    (ha : t.hasAnyoneCanPay = false) (hn : nInput ≠ nIn) :
    serInputOriginal scriptCode tx nIn t nInput
      = serOutPoint (inputAt tx nInput) ++ serScript []
        ++ (if t.baseType = SIGHASH_SINGLE || t.baseType = SIGHASH_NONE then le32 0 else le32 (inputAt tx nInput).sequence) := by
  simp [serInputOriginal, ha, hn]

/-- T-SH10a: the signed input carries the scriptCode (`1907–1908`) and its own sequence (`1917`). -/
theorem serInputOriginal_signed (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType)
    (ha : t.hasAnyoneCanPay = false) :
    serInputOriginal scriptCode tx nIn t nIn
      = serOutPoint (inputAt tx nIn) ++ serScriptCodeOriginal scriptCode ++ le32 (inputAt tx nIn).sequence := by
  simp [serInputOriginal, ha]

/-- T-SH10b: under ANYONECANPAY only the signed input is serialized, whatever `nInput` (`1898–1900`). -/
theorem serInputOriginal_anyonecanpay (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) (nInput : Nat)
    (ha : t.hasAnyoneCanPay = true) :
    serInputOriginal scriptCode tx nIn t nInput
      = serOutPoint (inputAt tx nIn) ++ serScriptCodeOriginal scriptCode ++ le32 (inputAt tx nIn).sequence := by
  simp [serInputOriginal, ha]

/-- T-SH10c: under SINGLE every output other than `nIn` is the null `CTxOut` (`1924–1927`,
`transaction.h:196–199`). -/
theorem serOutputOriginal_single_other (tx : Tx) (nIn : Nat) (t : SigHashType) (nOutput : Nat)
    (h : t.baseType = SIGHASH_SINGLE) (hn : nOutput ≠ nIn) : serOutputOriginal tx nIn t nOutput = serNullTxOut := by
  simp [serOutputOriginal, h, hn]

/-- T-SH10d: with the index in range and, under SINGLE, an output at `nIn`, the original digest is
SHA-256d of the serialization followed by the 4-byte type (`2104–2109`): T-SH3's and T-SH4's `one`
returns are the only other cases. -/
theorem sighashOriginal_hashed (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) (h1 : nIn < tx.inputs.length)
    (h2 : t.baseType = SIGHASH_SINGLE → nIn < tx.outputs.length) :
    sighashOriginal scriptCode tx nIn t = sha256d (serTxOriginal scriptCode tx nIn t ++ t.serialize) := by
  unfold sighashOriginal
  have h1' : ¬ tx.inputs.length ≤ nIn := Nat.not_le.2 h1
  simp only [h1', ite_false]
  split
  · rename_i hs
    simp only [Bool.and_eq_true, decide_eq_true_eq] at hs
    exact absurd (h2 hs.1) (Nat.not_lt.2 hs.2)
  · rfl

/-! ## `FindAndDelete`'s single pass (archived #25, the Lean families, 2026-09-27)

`CScript::FindAndDelete` (`script.h:202–224`) walks the script once: at every instruction start it strips every copy
of the pattern that begins there (`script.h:210–214`), then copies the next instruction whole (`script.h:209`, `script.h:215–216`: `GetOp`),
and a tail `GetOp` cannot read is appended as it stands (`script.h:219`). `findAndDelete` mirrors it with a fuel. The theorems
below are the walk case by case (T-SH12 to T-SH12c), what the walk preserves (T-SH12d, T-SH12e) and what a single
pass means (T-SH12f); the sixteen unit cases of the reference (`script_tests.cpp:3819–3934`) are the `decide`
examples above. -/

/-- Stripping never lengthens (`script.h:210–214`: the inner `while` only advances `pc`). -/
theorem stripPrefixes_length_le (f : Nat) (s b : Bytes) : (stripPrefixes f s b).length ≤ s.length := by
  induction f generalizing s with
  | zero => simp [stripPrefixes]
  | succ f ih =>
    unfold stripPrefixes
    split
    · exact le_trans (ih _) (by simp [List.length_drop])
    · exact le_refl _

/-- The strip is fuel-insensitive once the fuel exceeds the script's length: with a non-empty pattern every copy
removed is at least one byte, so the `while` of `script.h:210–214` ends by the bytes, never by a bound. -/
theorem stripPrefixes_fuel (b : Bytes) (hb : b ≠ []) (f f' : Nat) (s : Bytes) (h : s.length < f) (h' : s.length < f') :
    stripPrefixes f s b = stripPrefixes f' s b := by
  induction f generalizing f' s with
  | zero => omega
  | succ f ih =>
    cases f' with
    | zero => omega
    | succ f' =>
      unfold stripPrefixes
      split
      · rename_i hp
        have hbl : 0 < b.length := by cases b with | nil => exact absurd rfl hb | cons x xs => simp
        have hle := (List.isPrefixOf_iff_prefix.mp hp).length_le
        exact ih _ _ (by simp; omega) (by simp; omega)
      · rfl

/-- The walk is fuel-insensitive once the fuel exceeds the script's length: every iteration of the `do … while
(GetOp(pc, opcode))` (`script.h:208–216`) consumes at least the opcode byte; `findAndDelete` calls it at `length + 1`. -/
theorem findAndDeleteLoop_fuel (b : Bytes) (f f' : Nat) (s : Bytes) (h : s.length < f) (h' : s.length < f') :
    findAndDeleteLoop b f s = findAndDeleteLoop b f' s := by
  induction f generalizing f' s with
  | zero => omega
  | succ f ih =>
    cases f' with
    | zero => omega
    | succ f' =>
      rw [findAndDeleteLoop, findAndDeleteLoop]
      try dsimp only
      have hlen := stripPrefixes_length_le (s.length + 1) s b
      generalize stripPrefixes (s.length + 1) s b = s' at hlen ⊢
      cases s' with
      | nil => rfl
      | cons op rest =>
        try dsimp only
        cases hg : Machine.getOpTail op rest with
        | none => rfl
        | some p =>
          obtain ⟨d, k⟩ := p
          try dsimp only
          rw [ih f' (rest.drop k) (by simp at hlen ⊢; omega) (by simp at hlen ⊢; omega)]

/-- T-SH12: **a copy at an instruction start is deleted** (`script.h:210–214`: `pc` advances past every copy of `b` that begins
at the boundary, `nFound` counting each): with a non-empty pattern at the head of the script, the result is the result
on what follows the copy. -/
theorem findAndDelete_prefix (s b : Bytes) (hb : b ≠ []) (hp : b.isPrefixOf s = true) :
    findAndDelete s b = findAndDelete (s.drop b.length) b := by
  have hbl : 0 < b.length := by cases b with | nil => exact absurd rfl hb | cons x xs => simp
  have hle := (List.isPrefixOf_iff_prefix.mp hp).length_le
  unfold findAndDelete
  simp only [hb, ite_false]
  rw [findAndDeleteLoop, findAndDeleteLoop]
  try dsimp only
  have h1 : stripPrefixes (s.length + 1) s b = stripPrefixes ((s.drop b.length).length + 1) (s.drop b.length) b := by
    rw [stripPrefixes]
    simp only [hp, ite_true]
    exact stripPrefixes_fuel b hb _ _ _ (by simp; omega) (by simp)
  rw [h1]
  have hlen := stripPrefixes_length_le ((s.drop b.length).length + 1) (s.drop b.length) b
  generalize stripPrefixes ((s.drop b.length).length + 1) (s.drop b.length) b = s' at hlen ⊢
  cases s' with
  | nil => rfl
  | cons op rest =>
    try dsimp only
    cases hg : Machine.getOpTail op rest with
    | none => rfl
    | some p =>
      obtain ⟨d, k⟩ := p
      try dsimp only
      rw [findAndDeleteLoop_fuel b s.length (s.drop b.length).length (rest.drop k)
            (by simp at hlen ⊢; omega) (by simp at hlen ⊢; omega)]

/-- T-SH12a: **an instruction that begins no copy is kept whole** (`script.h:215–216`: `pc2 = pc`, `GetOp` advances
one instruction, and `:207` copies it at the next iteration): the opcode and its push data are copied and the walk
goes on after them. The pattern is compared only where the walk stands: at the start of each instruction `GetOp` reads,
and again right after each copy it deletes, the parser not run in between (`script.h:210–214`). So a copy inside an
instruction the walk read whole never matches (inside a push's data: the unit cases `script_tests.cpp:3858–3868` and
`:3878–3885`, the latter a copy running on into the next instructions), while one that begins where a deleted copy
ended matches even there (the script `0x03 0x03 0x02 0xff` with the pattern `0x03`: both copies deleted,
`0x02 0xff` left, decided as an example beside the reference's unit cases). A copy that begins at an instruction start is deleted even when it runs across several instructions
(`script_tests.cpp:3887–3892`: the push and `OP_1`; `:3906–3918`: `OP_0 OP_1`; T-SH12, T-SH12f). -/
theorem findAndDelete_op (op : Nat) (rest b data : Bytes) (k : Nat) (hb : b ≠ [])
    (hp : b.isPrefixOf (op :: rest) = false) (hg : Machine.getOpTail op rest = some (data, k)) :
    findAndDelete (op :: rest) b = op :: rest.take k ++ findAndDelete (rest.drop k) b := by
  unfold findAndDelete
  simp only [hb, ite_false]
  conv_lhs => rw [findAndDeleteLoop]
  try dsimp only
  have h1 : stripPrefixes ((op :: rest).length + 1) (op :: rest) b = op :: rest := by
    rw [stripPrefixes]; simp [hp]
  rw [h1]
  try dsimp only
  rw [hg]
  try dsimp only
  rw [findAndDeleteLoop_fuel b (op :: rest).length ((rest.drop k).length + 1) (rest.drop k) (by simp) (by simp)]

/-- T-SH12b: **a tail the parser cannot read is kept as it stands** (`script.h:216`: `GetOp` fails and the loop ends; `script.h:219`:
the bytes from `pc2` are appended): the invalid push of `script_tests.cpp:3920–3933` is deleted when a copy starts at
its boundary and is never parsed past. -/
theorem findAndDelete_truncated (op : Nat) (rest b : Bytes) (hb : b ≠ [])
    (hp : b.isPrefixOf (op :: rest) = false) (hg : Machine.getOpTail op rest = none) :
    findAndDelete (op :: rest) b = op :: rest := by
  unfold findAndDelete
  simp only [hb, ite_false]
  rw [findAndDeleteLoop]
  try dsimp only
  have h1 : stripPrefixes ((op :: rest).length + 1) (op :: rest) b = op :: rest := by
    rw [stripPrefixes]; simp [hp]
  rw [h1]
  try dsimp only
  rw [hg]

/-- T-SH12c: an empty script deletes nothing (`script.h:216`: `GetOp` fails at once). -/
theorem findAndDelete_nil_script (b : Bytes) : findAndDelete [] b = [] := by
  unfold findAndDelete
  split
  · rfl
  · cases b with
    | nil => contradiction
    | cons x xs => rfl

/-- T-SH12d: **nothing moves**: the result is a sublist of the script, every byte kept in its order and nothing added
or rearranged. That the bytes removed are whole copies of the pattern at the walk's positions (instruction starts,
and the ends of the copies it deleted) is T-SH12, T-SH12a and T-SH12b together (`script.h:209–214`, `script.h:219`), not this
statement. *Why it matters:* `CleanupScriptCode`
(`255–263`) feeds it the signature's push (T-SH8), so the scriptCode a pre-FORKID digest hashes is the executed script
with that push cut out and nothing rearranged. -/
theorem findAndDelete_sublist (s b : Bytes) : (findAndDelete s b).Sublist s := by
  suffices h : ∀ (n : Nat) (s : Bytes), s.length ≤ n → (findAndDelete s b).Sublist s from h s.length s le_rfl
  intro n
  induction n with
  | zero =>
    intro s hs
    have : s = [] := List.eq_nil_of_length_eq_zero (by omega)
    subst this
    rw [findAndDelete_nil_script]
  | succ n ih =>
    intro s hs
    by_cases hb : b = []
    · subst hb; rw [findAndDelete_nil]
    · cases s with
      | nil => rw [findAndDelete_nil_script]
      | cons op rest =>
        by_cases hp : b.isPrefixOf (op :: rest) = true
        · rw [findAndDelete_prefix _ _ hb hp]
          have hbl : 0 < b.length := by cases b with | nil => exact absurd rfl hb | cons x xs => simp
          exact (ih _ (by simp at hs ⊢; omega)).trans (List.drop_sublist _ _)
        · have hp' : b.isPrefixOf (op :: rest) = false := Bool.eq_false_iff.mpr hp
          cases hg : Machine.getOpTail op rest with
          | none => rw [findAndDelete_truncated _ _ _ hb hp' hg]
          | some p =>
            obtain ⟨d, k⟩ := p
            rw [findAndDelete_op _ _ _ _ _ hb hp' hg]
            have hx := ih (rest.drop k) (by simp at hs ⊢; omega)
            simpa only [List.cons_append, List.take_append_drop] using hx.append_left (op :: rest.take k)

/-- T-SH12e: the result is never longer than the script (from T-SH12d). -/
theorem findAndDelete_length_le (s b : Bytes) : (findAndDelete s b).length ≤ s.length :=
  (findAndDelete_sublist s b).length_le

/-- T-SH12f: **the pass is single** (the reference's own two cases, `script_tests.cpp:3906–3918`): `OP_0 OP_0 OP_1 OP_1`
with the pattern `OP_0 OP_1` leaves `OP_0 OP_1`, a fresh copy that a second pass would delete. The deletion is not a
fixpoint, and the digest of a pre-FORKID signature check depends on that: a `FindAndDelete` iterated to a fixpoint
would hash a different scriptCode on such a script. -/
theorem findAndDelete_single_pass :
    findAndDelete [0x00, 0x00, 0x51, 0x51] [0x00, 0x51] = [0x00, 0x51]
      ∧ findAndDelete (findAndDelete [0x00, 0x00, 0x51, 0x51] [0x00, 0x51]) [0x00, 0x51] = [] := by
  decide

end BsvScript.Sighash
