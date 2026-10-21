import BsvChain
import Lean.Data.Json
import Test.NodeMetadata

/-!
# The #60 derived boundary corpus

Runs the public definitions against `expected`, a source-derived spec column.
The node column records per-row metadata independently of this spec projection.
[SRC] src/validation.cpp:227–341,1094–1124,2646–2663,5977–6074 and
src/block_index.h:720–737 at 6504a3af. The corpus supplies all times explicitly.
-/

open Lean BsvChain BsvScript.Tx

namespace FinalityCheck

private def txOf (j : Json) : Except String Tx := do
  let sequences ← j.getObjValAs? (List Nat) "sequences"
  let version ← j.getObjValAs? Int "version"
  let lockTime ← j.getObjValAs? Nat "lockTime"
  return { version, lockTime, outputs := [], inputs := sequences.map (fun sequence =>
    { prevHash := [], prevIndex := 0, scriptSig := [], sequence }) }

private def paramsOf (j : Json) : Except String ChainParams := do
  let genesisHeight ← j.getObjValAs? Nat "genesisHeight"
  let chronicleHeight ← j.getObjValAs? Nat "chronicleHeight"
  let csvHeight ← j.getObjValAs? (Option Nat) "csvHeight"
  return { ChainParams.regtest with genesisHeight, chronicleHeight, csvHeight }

private def configOf (j : Json) : Except String NodeConfig := do
  let medianTimeSpan ← j.getObjValAs? Nat "span"
  let maxMempoolNonFinal ← j.getObjValAs? Nat "capacity"
  let mempoolNonFinalExpiry ← j.getObjValAs? Nat "expiry"
  return { NodeConfig.defaults with medianTimeSpan, maxMempoolNonFinal, mempoolNonFinalExpiry }

private def statusJson (status : String) : Json := Json.mkObj [("status", toJson status)]

private def rejectJson (reject : Reject) : Json :=
  let (namespace_, code) := match reject.code with
    | .node n => ("node", toJson n)
    | .rpc n => ("rpc", toJson n)
  Json.mkObj [("status", toJson "rejected"), ("namespace", toJson namespace_),
    ("code", code), ("reason", toJson reject.reason)]

private def judgeJson : Except Reject Bool → Json
  | .ok true => statusJson "final"
  | .ok false => statusJson "heldNonFinal"
  | .error reject => rejectJson reject

private def holdJson : Except Reject FinalityStatus → Json
  | .ok .final => statusJson "final"
  | .ok .heldNonFinal => statusJson "heldNonFinal"
  | .error reject => rejectJson reject

private def runRow (j : Json) : Except String Json := do
  let kind ← j.getObjValAs? String "kind"
  match kind with
  | "finality" => return toJson (isFinalTx (← txOf j)
      (← j.getObjValAs? Nat "height") (← j.getObjValAs? Int "time"))
  | "median" => return toJson (medianTimePast (← j.getObjValAs? (List Nat) "times")
      (← j.getObjValAs? Nat "span"))
  | "tip" => return judgeJson (contextualCheckTransactionForCurrentBlock (← paramsOf j) (← txOf j)
      (← j.getObjValAs? Nat "tipHeight")
      (medianTimePast (← j.getObjValAs? (List Nat) "times") (← j.getObjValAs? Nat "span"))
      (← j.getObjValAs? Int "now") (← j.getObjValAs? Int "flags"))
  | "mempool" => return holdJson (mempoolFinality (← paramsOf j) (← configOf j) (← txOf j)
      (← j.getObjValAs? Nat "tipHeight") (← j.getObjValAs? (List Nat) "times")
      (← j.getObjValAs? Int "now"))
  | "block" =>
    let result := contextualCheckTransactionForBlock (← paramsOf j) (← configOf j)
      (← txOf j) (← j.getObjValAs? Nat "height") (← j.getObjValAs? Nat "blockTime")
      (← j.getObjValAs? (List Nat) "times")
    return match result with
      | none => statusJson "unresolved"
      | some result => judgeJson result
  | "sequence" => return toJson (checkSequenceLocks (← paramsOf j) (← configOf j) (← txOf j)
      (← j.getObjValAs? Nat "tipHeight") (← j.getObjValAs? (List Nat) "times")
      (← j.getObjValAs? (List (Option Nat)) "coinHeights") (← j.getObjValAs? Nat "flags"))
  | "flags" =>
      let params ← paramsOf j
      return toJson (standardNonFinalVerifyFlags (BsvScript.Params.protocolEraOf
        params.genesisHeight params.chronicleHeight (← j.getObjValAs? Nat "tipHeight")))
  | "fee" =>
    let result := fee (← j.getObjValAs? Int "valueIn") (← j.getObjValAs? Int "valueOut")
    return match result with
      | .ok amount => Json.mkObj [("status", toJson "ok"), ("fee", toJson amount)]
      | .error reject => rejectJson reject
  | "expiry" => return toJson (nonFinalExpired (← configOf j)
      (← j.getObjValAs? Int "insertionTime") (← j.getObjValAs? Int "now"))
  | _ => throw s!"unknown kind {kind}"

private def checkRow (j : Json) : Except String (String × Bool) := do
  let id ← j.getObjValAs? String "id"
  unless (← j.getObjValAs? String "label") == "[D]" do throw s!"{id}: missing derived label"
  unless NodeMetadata.valid (← j.getObjValAs? String "node") do throw s!"{id}: unexpected node column"
  unless (← j.getObjValAs? String "source").contains "6504a3af" do throw s!"{id}: missing source pin"
  let _ ← j.getObjValAs? String "boundary"
  let _ ← j.getObjValAs? String "derivation"
  let expected ← j.getObjVal? "expected"
  return (id, (← runRow j) == expected)

end FinalityCheck

def main (args : List String) : IO UInt32 := do
  let path := args.headD "../corpus/chain/finality/finality.jsonl"
  let lines ← IO.FS.lines path
  let mut seen : List String := []
  let mut agree := 0
  let mut mismatch := 0
  for line in lines do
    if line.trimAscii.isEmpty then continue
    let result := do
      let j ← Json.parse line
      FinalityCheck.checkRow j
    match result with
    | .error error =>
        IO.eprintln s!"finalitycheck: malformed row: {error}"
        return 1
    | .ok (id, agrees) =>
        if seen.contains id then
          IO.eprintln s!"finalitycheck: duplicate id {id}"
          return 1
        seen := id :: seen
        if agrees then agree := agree + 1
        else
          mismatch := mismatch + 1
          IO.eprintln s!"finalitycheck: MISMATCH {id}"
  let good := !seen.isEmpty && mismatch == 0
  IO.println s!"finalitycheck: {if good then "GREEN" else "RED"} [X] ([M] {seen.length} rows; agree {agree}; mismatch {mismatch}; spec column [D]; node column independently recorded)"
  return if good then 0 else 1
