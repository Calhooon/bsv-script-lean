import BsvScript.Machine
import BsvScript.Ops.Arith
import BsvScript.Ops.Stack
import BsvScript.Sighash
import BsvScript.Hash.Sha1
import BsvScript.Hash.Ripemd160
import BsvScript.Crypto.Secp256k1
import BsvScript.Tx
/-!
# BsvScript.Ops.Crypto

The crypto family (#11; `docs/DESIGN.md` §4): the hash opcodes
(`interpreter.cpp:1402–1443`), `OP_CODESEPARATOR` (`1445–1448`, tracked by the
loop), `OP_CHECKSIG`/`OP_CHECKSIGVERIFY` (`1450–1508`) and
`OP_CHECKMULTISIG`/`OP_CHECKMULTISIGVERIFY` (`1510–1682`), with the encoding
checks `IsValidSignatureEncoding` (`177–245`), `CheckSignatureEncoding`
(`265–310`), `IsCompressedOrUncompressedPubKey` (`132–152`),
`IsCompressedPubKey` (`154–164`), `CheckPubKeyEncoding` (`312–329`), and the
transaction checker `TransactionSignatureChecker::CheckSig` (`2133–2164`) over
the sighash (`BsvScript.Sighash`) and the curve (`BsvScript.Crypto.Secp256k1`).
Bare line numbers are `interpreter.cpp` at the pin (`docs/PROVENANCE.md`).

The machine hands the transaction context in as `Context.checkSig`
(`docs/DESIGN.md` §5.4); `txCheckSig` below builds that function for a
transaction, an input and its amount.
-/

namespace BsvScript.Ops.Crypto
open BsvScript.Params BsvScript.Numbers BsvScript.Machine BsvScript.Hash BsvScript.Sighash BsvScript.Tx
open BsvScript.Ops.Stack

/-! ## The encoding checks -/

/-- `IsValidSignatureEncoding` (`177–245`): the strict DER shape with the hash-type byte. -/
def isValidSignatureEncoding (sig : Bytes) : Bool :=
  let len := sig.length
  if len < 9 || 73 < len then false                                             -- 193–194
  else if sig.getD 0 0 ≠ 0x30 then false                                        -- 197
  else if sig.getD 1 0 ≠ len - 3 then false                                     -- 200
  else
    let lenR := sig.getD 3 0
    if len ≤ 5 + lenR then false                                                -- 206
    else
      let lenS := sig.getD (5 + lenR) 0
      if lenR + lenS + 7 ≠ len then false                                       -- 214
      else if sig.getD 2 0 ≠ 0x02 then false                                    -- 217
      else if lenR = 0 then false                                               -- 220
      else if 128 ≤ sig.getD 4 0 then false                                     -- 223
      else if 1 < lenR && sig.getD 4 0 = 0 && sig.getD 5 0 < 128 then false     -- 227
      else if sig.getD (lenR + 4) 0 ≠ 0x02 then false                           -- 230
      else if lenS = 0 then false                                               -- 233
      else if 128 ≤ sig.getD (lenR + 6) 0 then false                            -- 236
      else if 1 < lenS && sig.getD (lenR + 6) 0 = 0 && sig.getD (lenR + 7) 0 < 128 then false  -- 240
      else true

/-- `CheckSignatureEncoding` (`265–310`): an empty signature passes (`272–273`);
under DERSIG, LOW_S or STRICTENC (`Env.strictDer`, ungated) the strict shape (`275–280`); under LOW_S and
the version gate the low-S rule on the signature without its last byte
(`282–288`, `CPubKey::CheckLowS`); under STRICTENC the hash type must be
defined (`293–294`), a FORKID bit needs FORKID enabled (`300–301`), a CHRONICLE
bit needs CHRONICLE (`302–303`), and FORKID enabled demands the bit (`305–306`). -/
def checkSignatureEncoding (env : Env) (sig : Bytes) : Except ScriptError Unit :=
  let f := env.params.flags
  if sig.isEmpty then .ok ()
  else if env.strictDer && !isValidSignatureEncoding sig then .error .sigDer
  else if f.lowS && !Crypto.Secp256k1.checkLowS (sig.dropLast) && enforceNonMalleability f env.ctx.version then
    .error .sigHighS
  else if f.strictEnc then
    let t := SigHashType.ofSig sig
    if !t.isDefined then .error .sigHashtype
    else if !f.enableSighashForkid && t.hasForkId then .error .illegalForkid
    else if !f.chronicle && t.hasChronicle then .error .illegalChronicle
    else if f.enableSighashForkid && !t.hasForkId then .error .mustUseForkid
    else .ok ()
  else .ok ()

/-- `IsCompressedOrUncompressedPubKey` (`132–152`). -/
def isCompressedOrUncompressedPubKey (pk : Bytes) : Bool :=
  if pk.length < 33 then false
  else match pk.head? with
    | some 4 => pk.length = 65
    | some 2 => pk.length = 33
    | some 3 => pk.length = 33
    | _ => false

/-- `IsCompressedPubKey` (`154–164`). -/
def isCompressedPubKey (pk : Bytes) : Bool :=
  pk.length = 33 && (pk.head? = some 2 || pk.head? = some 3)

/-- `CheckPubKeyEncoding` (`312–329`). -/
def checkPubKeyEncoding (env : Env) (pk : Bytes) : Except ScriptError Unit :=
  let f := env.params.flags
  if f.strictEnc && !isCompressedOrUncompressedPubKey pk then .error .pubkeytype
  else if f.compressedPubKeyType && !isCompressedPubKey pk then .error .noncompressedPubkey
  else .ok ()

/-! ## The transaction checker -/

/-- `TransactionSignatureChecker::CheckSig` (`2133–2164`): the key must be
non-empty (`CPubKey::IsValid`, `pubkey.h:157`), the signature non-empty, its
last byte the hash type (`247–253`), the digest `SignatureHash` (`2149–2155`,
§4.3), then `CPubKey::Verify` (`2126–2130`, `pubkey.cpp:183–214`). -/
def txCheckSig (tx : Tx) (nIn : Nat) (amount : Nat) : Bytes → Bytes → Bytes → Bool → Bool :=
  fun sig pubkey scriptCode enabledForkid =>
    if pubkey.isEmpty || sig.isEmpty then false
    else
      let t := SigHashType.ofSig sig
      let digest := sighash scriptCode tx nIn t amount enabledForkid
      Crypto.Secp256k1.verify pubkey sig.dropLast digest

/-- The scriptCode of a signature check (`1472–1481`, `1568–1577`): the script
from the last `OP_CODESEPARATOR` on, and, when executing inside the unlocking
script under `SCRIPT_CHRONICLE`, the locking script appended. -/
def scriptCodeOf (env : Env) (st : State) : Bytes :=
  match env.checksigData with
  | some lock => if env.params.flags.chronicle then st.codeSep ++ lock else st.codeSep
  | none => st.codeSep

/-! ## The opcodes -/

/-- The hash opcodes (`1402–1443`): the top replaced by its digest. -/
def hashOp (env : Env) (op : Nat) (st : State) : Except ScriptError State := do
  need st 1
  let (v, st) ← popElem st
  let h :=
    if op = Op.OP_RIPEMD160 then ripemd160 v
    else if op = Op.OP_SHA1 then sha1 v
    else if op = Op.OP_SHA256 then sha256 v
    else if op = Op.OP_HASH160 then hash160 v
    else hash256 v
  pushElem env st h

/-- `OP_CHECKSIG`/`OP_CHECKSIGVERIFY` (`1450–1508`): the signature is the
second element, the key the top (`1456–1457`); both encodings checked
(`1459–1469`); the scriptCode (`1471–1481`) cleaned of the signature when FORKID
is not in play (`1484`, `CleanupScriptCode` `255–263`); the check (`1486–1487`);
a failed check with a non-empty signature under NULLFAIL and the version gate is
`SCRIPT_ERR_SIG_NULLFAIL` (`1491–1497`); the two popped, the boolean pushed
(`1499–1501`); `VERIFY` pops a true or fails (`1502–1507`). -/
def checkSigOp (env : Env) (op : Nat) (st : State) : Except ScriptError State := do
  need st 2
  let sig := topAt st 1
  let pubkey := topAt st 0
  checkSignatureEncoding env sig
  checkPubKeyEncoding env pubkey
  let forkid := env.params.flags.enableSighashForkid
  let scriptCode := cleanupScriptCode (scriptCodeOf env st) sig forkid
  let ok := env.ctx.checkSig sig pubkey scriptCode forkid
  if !ok && env.params.flags.nullFail && !sig.isEmpty && enforceNonMalleability env.params.flags env.ctx.version then
    throw .sigNullfail
  let (_, st) ← popElem st
  let (_, st) ← popElem st
  let st ← pushElem env st (if ok then [1] else [])
  if op = Op.OP_CHECKSIGVERIFY then
    if ok then
      let (_, st) ← popElem st
      pure st
    else throw .checksigverify
  else pure st

/-- The counts of `OP_CHECKMULTISIG` are read at width 4 with the minimal rule
(`CScriptNum(…, requireMinimal, MAXIMUM_ELEMENT_SIZE).getint()`, `1523–1526`,
`1550–1553`; `getint` saturates at `INT_MAX`, unreachable at width 4). -/
def readCount (env : Env) (bs : Bytes) : Except ScriptError Int :=
  if 4 < bs.length then .error .scriptnumOverflow
  else if env.requireMinimal && !isMinimallyEncoded bs 4 then .error .scriptnumMinencode
  else .ok (decode bs)

/-- The signature loop (`1587–1634`): the signatures are tried in order against
the keys in order; a key is consumed by every try, a signature only by a success;
more signatures left than keys ends it as a failure. `isig`/`ikey` count from
the top: `isig` is the position of the current signature, `ikey` the key's. -/
def multisigLoop (env : Env) (st : State) (scriptCode : Bytes) (forkid : Bool) :
    Nat → Nat → Nat → Nat → Except ScriptError Bool
  | isig, ikey, nSigs, nKeys =>
    if nSigs = 0 then .ok true
    else if nKeys < nSigs then .ok false
    else do
      let sig := topAt st isig
      let pubkey := topAt st ikey
      checkSignatureEncoding env sig                                            -- 1605–1609
      checkPubKeyEncoding env pubkey                                            -- 1611–1615
      let ok := env.ctx.checkSig sig pubkey scriptCode forkid                   -- 1618–1619
      if ok then multisigLoop env st scriptCode forkid (isig + 1) (ikey + 1) (nSigs - 1) (nKeys - 1)
      else multisigLoop env st scriptCode forkid isig (ikey + 1) nSigs (nKeys - 1)
  termination_by _ _ _ nKeys => nKeys

/-- `OP_CHECKMULTISIG`/`OP_CHECKMULTISIGVERIFY` (`1510–1682`). The layout from
the top: the key count (`1517–1526`, negative → `PUBKEY_COUNT`, above
`MaxPubKeysPerMultiSig` → `PUBKEY_COUNT`, charged to the op count → `OP_COUNT`,
`1527–1536`), the keys, the signature count (`1544–1560`, negative or above the
key count → `SIG_COUNT`), the signatures, the dummy (`1661–1672`). The
scriptCode (`1567–1577`) is cleaned of every signature when FORKID is not in
play (`1579–1585`); the loop (`1587–1634`); the arguments popped (`1636–1653`)
with `SIG_NULLFAIL` on a non-empty signature after a failure under NULLFAIL
and the version gate (`1641–1647`); the dummy must be empty under NULLDUMMY
and the gate (`1664–1670`, else `SIG_NULLDUMMY`); the boolean pushed
(`1674`); `VERIFY` pops a true or fails (`1676–1681`). -/
def checkMultiSigOp (env : Env) (op : Nat) (st : State) : Except ScriptError State := do
  need st 1
  let nKeysI ← readCount env (topAt st 0)
  if nKeysI < 0 then throw .pubkeyCount
  let nKeys := nKeysI.toNat
  if env.params.limits.maxPubKeysPerMultiSig < nKeys then throw .pubkeyCount
  let st := { st with opCount := st.opCount + nKeys }
  if env.params.limits.maxOpsPerScript < st.opCount then throw .opCount
  need st (nKeys + 2)
  let nSigsI ← readCount env (topAt st (nKeys + 1))
  if nSigsI < 0 then throw .sigCount
  let nSigs := nSigsI.toNat
  if nKeys < nSigs then throw .sigCount
  need st (nKeys + 2 + nSigs + 1)
  let forkid := env.params.flags.enableSighashForkid
  let scriptCode0 := scriptCodeOf env st
  let scriptCode := (List.range nSigs).foldl (fun sc k => cleanupScriptCode sc (topAt st (nKeys + 2 + k)) forkid) scriptCode0
  let ok ← multisigLoop env st scriptCode forkid (nKeys + 2) 1 nSigs nKeys
  -- pop the arguments: the key count, the keys, the signature count, the signatures (1636–1653)
  let total := nKeys + 2 + nSigs
  let nullfailBites := !ok && env.params.flags.nullFail && enforceNonMalleability env.params.flags env.ctx.version
  let mut stm := st
  for j in List.range total do
    -- `ikey2` counts down from `nKeys + 2`: zero once the popped elements are the signatures
    let sigRegion := nKeys + 2 ≤ j
    if nullfailBites && sigRegion && !(topAt stm 0).isEmpty then throw .sigNullfail
    let (_, st') ← popElem stm
    stm := st'
  let st1 := stm
  if st1.stack.isEmpty then throw .invalidStackOperation                         -- 1661–1662
  if env.params.flags.nullDummy && !(topAt st1 0).isEmpty && enforceNonMalleability env.params.flags env.ctx.version then
    throw .sigNulldummy
  let (_, st2) ← popElem st1
  let st3 ← pushElem env st2 (if ok then [1] else [])
  if op = Op.OP_CHECKMULTISIGVERIFY then
    if ok then
      let (_, st4) ← popElem st3
      pure st4
    else throw .checkmultisigverify
  else pure st3

/-- The family hook (`OP_CODESEPARATOR` is the loop's, `Machine.loop`). -/
def exec : OpExec := fun op _ env st =>
  if Op.OP_RIPEMD160 ≤ op && op ≤ Op.OP_HASH256 then some (hashOp env op st)
  else if op = Op.OP_CHECKSIG || op = Op.OP_CHECKSIGVERIFY then some (checkSigOp env op st)
  else if op = Op.OP_CHECKMULTISIG || op = Op.OP_CHECKMULTISIGVERIFY then some (checkMultiSigOp env op st)
  else none

end BsvScript.Ops.Crypto

namespace BsvScript.Ops.Crypto
open BsvScript.Numbers BsvScript.Machine

/-- T-C1: a strictly encoded signature is 9 to 73 bytes (`193–194`). -/
theorem isValidSignatureEncoding_length (sig : Bytes) (h : isValidSignatureEncoding sig = true) :
    9 ≤ sig.length ∧ sig.length ≤ 73 := by
  by_cases hlen : sig.length < 9 ∨ 73 < sig.length
  · have hb : (sig.length < 9 || 73 < sig.length) = true := by
      simp only [Bool.or_eq_true, decide_eq_true_eq]; exact hlen
    simp only [isValidSignatureEncoding] at h
    rw [ite_eq_left hb] at h
    exact absurd h Bool.false_ne_true
  · omega

/-- T-C2: the empty signature passes the encoding check (`272–273`). -/
theorem checkSignatureEncoding_empty (env : Env) : checkSignatureEncoding env [] = .ok () := rfl

end BsvScript.Ops.Crypto
