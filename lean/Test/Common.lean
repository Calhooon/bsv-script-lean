import BsvScript.Eval
import BsvScript.Tx
import Lean.Data.Json
/-!
# What the corpus checks share

The relay flag word and the consensus limits of a post-Chronicle node (the
setting every generated corpus is recorded under, `docs/DESIGN.md` §5.2), the
entry fields a check reads, and the run of one entry through the evaluator on
input 0.
-/

namespace BsvScript.Test
open BsvScript BsvScript.Params BsvScript.Machine BsvScript.Tx BsvScript.Numbers
open Lean

/-- The relay flag word of a post-Chronicle node for a post-Chronicle UTXO
(`StandardScriptVerifyFlags` for the Chronicle era, `policy.h:208–222`, the
input flags `policy.h:225–244`, `SCRIPT_ENABLE_SIGHASH_FORKID` as the mempool
path sets it, `verify_script_flags.cpp:11–30`). -/
def relayFlags : Flags :=
  { p2sh := true, strictEnc := true, derSig := true, lowS := true, nullDummy := true,
    sigPushOnly := true, minimalData := true, discourageUpgradableNops := true, cleanStack := true,
    checkLockTimeVerify := true, checkSequenceVerify := true, minimalIf := false, nullFail := true,
    compressedPubKeyType := false, enableSighashForkid := true, genesis := true,
    utxoAfterGenesis := true, chronicle := true, utxoAfterChronicle := true }

/-- The consensus limits post-Chronicle (`docs/PARAMETERS.md` §1). -/
def consensusLimits : Limits :=
  { maxOpsPerScript := Consensus.maxOpsPerScriptAfterGenesis,
    maxScriptNumLength := Consensus.maxScriptNumLengthAfterChronicle,
    maxScriptSize := Consensus.maxScriptSizeAfterGenesis,
    maxPubKeysPerMultiSig := Consensus.maxPubKeysPerMultisigAfterGenesis,
    maxStackMemoryUsage := Consensus.defaultStackMemoryUsageConsensusAfterGenesis }

def relayParams : EvalParams := { flags := relayFlags, limits := consensusLimits }

/-- The consensus limits of a flag word's UTXO era (`make_verify_script_params`,
`interpreter.cpp:2282–2302`, `consensus = true`; the pre-Genesis memory limit is
unbounded, `configscriptpolicy.cpp:139–146`; `docs/PARAMETERS.md` §1). -/
def limitsFor (f : Flags) : Limits :=
  if !f.utxoAfterGenesis then
    { maxOpsPerScript := Consensus.maxOpsPerScriptBeforeGenesis,
      maxScriptNumLength := Consensus.maxScriptNumLengthBeforeGenesis,
      maxScriptSize := Consensus.maxScriptSizeBeforeGenesis,
      maxPubKeysPerMultiSig := Consensus.maxPubKeysPerMultisigBeforeGenesis,
      maxStackMemoryUsage := Consensus.defaultStackMemoryUsageConsensusAfterGenesis }
  else
    { maxOpsPerScript := Consensus.maxOpsPerScriptAfterGenesis,
      maxScriptNumLength := if f.utxoAfterChronicle then Consensus.maxScriptNumLengthAfterChronicle
                            else Consensus.maxScriptNumLengthAfterGenesis,
      maxScriptSize := Consensus.maxScriptSizeAfterGenesis,
      maxPubKeysPerMultiSig := Consensus.maxPubKeysPerMultisigAfterGenesis,
      maxStackMemoryUsage := Consensus.defaultStackMemoryUsageConsensusAfterGenesis }

/-- No flag set. -/
def noFlags : Flags :=
  { p2sh := false, strictEnc := false, derSig := false, lowS := false, nullDummy := false,
    sigPushOnly := false, minimalData := false, discourageUpgradableNops := false, cleanStack := false,
    checkLockTimeVerify := false, checkSequenceVerify := false, minimalIf := false, nullFail := false,
    compressedPubKeyType := false, enableSighashForkid := false, genesis := false,
    utxoAfterGenesis := false, chronicle := false, utxoAfterChronicle := false }

structure Entry where
  id : String
  family : String
  txHex : String
  lockHex : String
  satoshis : Nat
  expect : String

/-- The entry's bsv-rs verdict object (lean #47): the ONE key of `expect` that starts with `bsv-rs@`,
whichever pinned version the corpus was recorded at (`docs/PROVENANCE.md` §1a), never a literal
version; none, or more than one, is the entry's parse error. -/
def bsvRsExpect (expect : Json) : Except String Json := do
  let kvs := (← expect.getObj?).toList.filter (fun kv => kv.1.startsWith "bsv-rs@")
  match kvs with
  | [kv] => pure kv.2
  | [] => throw "expect carries no bsv-rs@<version> key"
  | _ => throw s!"expect carries {kvs.length} bsv-rs@<version> keys"

/-- The bsv-rs version a vector file names (`…/bsv-rs-<x.y.z>.jsonl`, `…/ecdsa-bsv-rs-<x.y.z>.jsonl`:
the harness writes the pinned version into the file's name, `docs/PROVENANCE.md` §1a; lean #47): the
verdict line names the vectors it read, never a literal version. -/
def bsvRsVersionOfPath (path : String) : String :=
  let file := (path.splitOn "/").getLastD path
  match file.splitOn "bsv-rs-" with
  | [_, rest] => (rest.splitOn ".jsonl").headD rest
  | _ => file

def parseEntry (j : Json) : Except String Entry := do
  let id ← j.getObjValAs? String "id"
  let family ← j.getObjValAs? String "family"
  let txHex ← j.getObjValAs? String "tx"
  let prevouts ← j.getObjVal? "prevouts"
  let p0 ← match prevouts.getArr? with
    | .ok arr => match arr[0]? with | some p => pure p | none => throw "no prevout"
    | .error e => throw e
  let lockHex ← p0.getObjValAs? String "script"
  let satoshis ← p0.getObjValAs? Nat "satoshis"
  let expect ← j.getObjVal? "expect"
  let e ← bsvRsExpect expect
  let verdict ← e.getObjValAs? String "verdict"
  pure { id, family, txHex, lockHex, satoshis, expect := verdict }

def verdictKind : Verdict → String
  | .valid => "valid"
  | .invalid _ => "invalid"
  | .unimplemented _ => "unimplemented"
  | .undefinedInReference _ => "undefined-in-reference"

def verdictShow : Verdict → String
  | .valid => "valid"
  | .invalid e => s!"invalid {e.name}"
  | .unimplemented op => s!"unimplemented 0x{String.ofList (Nat.toDigits 16 op)}"
  | .undefinedInReference f => s!"undefined-in-reference ({f})"

/-- Run an entry's input 0 through the evaluator under the relay word; the
transaction's own version selects the branch (`Context.version`). The
lock-time and sequence checks are false (no corpus entry is recorded against a
lock time), and the signature check is the one the caller supplies, built from
the transaction, the lock and the satoshis (`CryptoCheck` passes the real one,
`Ops.Crypto.txCheckSig`). -/
def runEntryWith (c : Entry) (mkCheckSig : Tx → Bytes → Nat → (Bytes → Bytes → Bytes → Bool → Bool)) :
    IO (Verdict × Bytes × Tx) := do
  let txBytes ← match hexDecode c.txHex with | some b => pure b | none => throw (IO.userError s!"{c.id}: tx hex")
  let tx ← match decodeTx txBytes with | some t => pure t | none => throw (IO.userError s!"{c.id}: tx frame")
  let lock ← match hexDecode c.lockHex with | some b => pure b | none => throw (IO.userError s!"{c.id}: lock hex")
  let scriptSig ← match tx.inputs.head? with | some i => pure i.scriptSig | none => throw (IO.userError s!"{c.id}: no input")
  let ctx : Context := { version := tx.version, checkLockTime := fun _ => false, checkSequence := fun _ => false,
                         checkSig := mkCheckSig tx lock c.satoshis }
  pure (Eval.verifyScript relayParams ctx scriptSig lock, scriptSig, tx)

/-- `runEntryWith` under a signature check that answers false for every signature (the
stack, arith and bytes legs' runner): an entry is decided as if each `CHECKSIG` it reaches
failed, so a leg whose entries need a valid signature uses `runEntryWith`. -/
def runEntry (c : Entry) : IO (Verdict × Bytes × Tx) := runEntryWith c (fun _ _ _ => fun _ _ _ _ => false)

end BsvScript.Test
