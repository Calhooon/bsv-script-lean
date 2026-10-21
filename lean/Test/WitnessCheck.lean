import BsvScript.Flags
import BsvScript.TxContext
import Test.Common
import Lean.Data.Json
/-!
# The witness check: the policy-default witnesses under both nodes' derived parameters (#21)

`corpus/witnesses/policy-defaults.jsonl` (and the regenerated
`policy-defaults-large.jsonl`) carry the transactions that exhibit a
policy-default difference between bitcoin-sv v1.2.2 and Teranode v0.15.9 (and v0.16.0, #54)
(`docs/PARAMETERS.md` §5, §7). Each entry's `divergence` record states the two
nodes' mempool verdicts read from source (`[D]`). This leg decides the spec's
own verdict for every input under the four parameter sets `Params.derive`
produces from the two nodes' default configurations (`NodeConfig.svMainnetDefault`,
`NodeConfig.teranodeDefault`; the block path and the mempool path) and checks:

1. a script-level witness (`witness-policy/stack-memory`) reproduces the record:
   invalid with the recorded code under bitcoin-sv's mempool limits, valid under
   Teranode's, valid on both block paths (the consensus budget is INT64_MAX in
   both);
2. a transaction-level witness (`witness-policy/dust`, `witness-policy/tx-size`)
   is valid under all four: the difference lies outside the script semantics
   (DESIGN §5.5, the standardness gate).

What the leg executes is the spec's own verdicts, checked against the
expectations the `divergence` records derive from source (`[D]`: bitcoin-sv's
and Teranode's defaults read at their pins, `docs/PARAMETERS.md` §5). No node
and no Teranode instance has run these witnesses: the manifest
(`corpus/witnesses/policy-defaults-manifest.json`) records bsv-rs's verdicts
only, and the SV-node runner's manifest (`corpus/witnesses/sv-node/manifest.json`)
carries no policy-defaults entry.

Exit 1 on any mismatch. A missing large file is reported, not counted
(`make policywitnesses` regenerates it; its sha256 is in the manifest).
-/

open BsvScript BsvScript.Params BsvScript.Machine BsvScript.Tx BsvScript.Numbers BsvScript.Test
open BsvScript.TxContext
open Lean

structure Witness where
  id : String
  family : String
  rule : String
  txHex : String
  /-- per input: the locking script hex, the satoshis, the UTXO height -/
  prevouts : List (String × Nat × Nat)
  spendHeight : Nat
  aVerdict : String
  aCode : Option String
  bVerdict : String

def parseWitness (j : Json) : Except String Witness := do
  let id ← j.getObjValAs? String "id"
  let family ← j.getObjValAs? String "family"
  let rule ← j.getObjValAs? String "rule"
  let txHex ← j.getObjValAs? String "tx"
  let prevs ← j.getObjVal? "prevouts"
  let arr ← prevs.getArr?
  let mut prevouts : List (String × Nat × Nat) := []
  for p in arr do
    let s ← p.getObjValAs? String "script"
    let sat ← p.getObjValAs? Nat "satoshis"
    let h ← p.getObjValAs? Nat "height"
    prevouts := prevouts ++ [(s, sat, h)]
  let params ← j.getObjVal? "params"
  let spendHeight ← params.getObjValAs? Nat "spend_height"
  let d ← j.getObjVal? "divergence"
  let a ← d.getObjVal? "a_verdict"
  let b ← d.getObjVal? "b_verdict"
  let aVerdict ← a.getObjValAs? String "verdict"
  let aCode := (a.getObjValAs? String "code").toOption
  let bVerdict ← b.getObjValAs? String "verdict"
  pure { id, family, rule, txHex, prevouts, spendHeight, aVerdict, aCode, bVerdict }

/-- The spec's verdict on the whole transaction under one node's derived parameters:
every input in order, the first failure reported with its input index. -/
def runAll (cfg : NodeConfig) (consensus : Bool) (w : Witness) (tx : Tx) : IO (Verdict × Option Nat) := do
  let mut i := 0
  for (lockHex, sat, utxoHeight) in w.prevouts do
    let lock ← match hexDecode lockHex with | some b => pure b | none => throw (IO.userError s!"{w.id}: lock hex")
    let unlock ← match tx.inputs[i]? with | some inp => pure inp.scriptSig | none => throw (IO.userError s!"{w.id}: input {i}")
    let p := derive cfg w.spendHeight utxoHeight consensus
    let v := Eval.verifyScript p (txContext tx i sat) unlock lock
    match v with
    | .valid => i := i + 1
    | _ => return (v, some i)
  return (.valid, none)

def codeOf : Verdict → Option String
  | .invalid e => some e.name
  | _ => none

def show4 (svB svM tB tM : Verdict) : String :=
  s!"bitcoin-sv block {verdictShow svB}, mempool {verdictShow svM}; teranode block {verdictShow tB}, mempool {verdictShow tM}"

def runFile (path : String) : IO (Bool × Nat) := do
  if !(← System.FilePath.pathExists path) then
    IO.println s!"witnesscheck: {path} absent (make policywitnesses regenerates it; its sha256 is in corpus/witnesses/policy-defaults-manifest.json): not counted"
    return (true, 0)
  let lines ← IO.FS.lines path
  let mut ok := true
  let mut n := 0
  for line in lines do
    if line.trim.isEmpty then continue
    let j ← match Json.parse line with | .ok j => pure j | .error e => throw (IO.userError s!"json: {e}")
    let w ← match parseWitness j with | .ok w => pure w | .error e => throw (IO.userError s!"{path}: {e}")
    let txBytes ← match hexDecode w.txHex with | some b => pure b | none => throw (IO.userError s!"{w.id}: tx hex")
    let tx ← match decodeTx txBytes with | some t => pure t | none => throw (IO.userError s!"{w.id}: tx frame")
    n := n + 1
    let (svB, _) ← runAll NodeConfig.svMainnetDefault true w tx
    let (svM, _) ← runAll NodeConfig.svMainnetDefault false w tx
    let (tB, _) ← runAll NodeConfig.teranodeDefault true w tx
    let (tM, _) ← runAll NodeConfig.teranodeDefault false w tx
    let scriptLevel := w.family == "witness-policy/stack-memory"
    let good :=
      if scriptLevel then
        verdictKind svM == w.aVerdict && codeOf svM == w.aCode && verdictKind tM == w.bVerdict
          && svB == .valid && tB == .valid
      else svB == .valid && svM == .valid && tB == .valid && tM == .valid
    let kind := if scriptLevel then "script-level: the record reproduced on the spec"
                else "transaction-level (DESIGN §5.5): the scripts are valid under all four, the standardness gate decides outside the script semantics"
    if good then
      IO.println s!"witnesscheck: {w.id} {w.family} ({w.rule}): {show4 svB svM tB tM}: {kind}"
    else
      ok := false
      IO.println s!"witnesscheck: MISMATCH {w.id} {w.family}: {show4 svB svM tB tM}; the record says bitcoin-sv mempool {w.aVerdict} {w.aCode.getD ""}, teranode mempool {w.bVerdict}"
  return (ok, n)

def main (args : List String) : IO UInt32 := do
  let paths := if args.isEmpty then ["../corpus/witnesses/policy-defaults.jsonl", "../corpus/witnesses/policy-defaults-large.jsonl"] else args
  let mut allOk := true
  let mut total := 0
  for p in paths do
    let (ok, n) ← runFile p
    allOk := allOk && ok
    total := total + n
  IO.println s!"witnesscheck: {total} witness transactions decided under both nodes' derived parameters, {if allOk then "0 mismatches" else "MISMATCHES"}"
  return (if allOk then 0 else 1)
