import BsvChain
import Lean.Data.Json
import Test.NodeMetadata

/-!
# The #61 derived UTXO corpus

Checks rejection details, complete maps, spent vectors, fee and undo using the
executable definitions and the existing signature machine. Expected rows are
[D] source derivations. The node column records per-row metadata independently of this spec projection.
[SRC] src/validation.cpp:2480–2495,2552–2709,3421–3430,
src/coins.cpp:45–64,548–565 and src/undo.h:80–83 at
6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
-/

open Lean BsvChain BsvScript.Tx BsvScript.Numbers

namespace UtxoCheck

private def requireSome (o : Option α) (message : String) : Except String α :=
  match o with
  | some value => .ok value
  | none => .error message

private def bytesOf (s : String) : Except String Bytes :=
  requireSome (hexDecode s) "invalid hex"

private def pointOf (j : Json) : Except String OutPoint := do
  let hash ← bytesOf (← j.getObjValAs? String "hash")
  unless hash.length == 32 do throw "outpoint hash must contain 32 bytes"
  let index ← j.getObjValAs? Nat "index"
  return ⟨hash, index⟩

private def coinOf (j : Json) : Except String (OutPoint × Coin) := do
  let p ← pointOf j
  let value ← j.getObjValAs? Int "value"
  let script ← bytesOf (← j.getObjValAs? String "script")
  let height ← j.getObjValAs? Nat "height"
  let isCoinbase ← j.getObjValAs? Bool "isCoinbase"
  let isConfiscation ← j.getObjValAs? Bool "isConfiscation"
  return (p, ⟨value, script, height, isCoinbase, isConfiscation⟩)

private def coinsOf (j : Json) : Except String (List (OutPoint × Coin)) := do
  let coins ← (← fromJson? j : List Json).mapM coinOf
  unless (coins.map Prod.fst).Nodup do throw "duplicate UTXO key"
  return coins

private def configOf (j : Json) : Except String NodeConfig := do
  let coinbaseMaturity ← j.getObjValAs? Nat "coinbaseMaturity"
  let confiscationMaturity ← j.getObjValAs? Nat "confiscationMaturity"
  let maxStackMemoryUsageConsensus ← j.getObjValAs? Nat "maxStackMemoryUsageConsensus"
  let maxStackMemoryUsagePolicy ← j.getObjValAs? Nat "maxStackMemoryUsagePolicy"
  let maxScriptSizePolicy ← j.getObjValAs? Nat "maxScriptSizePolicy"
  let maxTxFee ← j.getObjValAs? Nat "maxTxFee"
  return { NodeConfig.defaults with
    coinbaseMaturity, confiscationMaturity, maxStackMemoryUsageConsensus,
    maxStackMemoryUsagePolicy, maxScriptSizePolicy, maxTxFee }

private def contextOf (cfg : NodeConfig) (j : Json) : Except String UtxoContext := do
  let network ← j.getObjValAs? String "network"
  let base ← match network with
    | "regtest" => pure ChainParams.regtest
    | "mainnet" => pure ChainParams.mainnet
    | _ => throw s!"unsupported fixture network {network}"
  let genesisHeight ← j.getObjValAs? Nat "genesisHeight"
  let chronicleHeight ← j.getObjValAs? Nat "chronicleHeight"
  let params := { base with genesisHeight, chronicleHeight }
  let height ← j.getObjValAs? Nat "height"
  let tipHeight ← j.getObjValAs? Nat "tipHeight"
  let consensus ← j.getObjValAs? Bool "consensus"
  let onBlock ← j.getObjValAs? Bool "onBlock"
  let now ← j.getObjValAs? Int "now"
  let flags ← match (← j.getObjValAs? (Option Nat) "flags") with
    | some word => pure (BsvScript.Params.Flags.ofWord word)
    | none => requireSome (ordinaryScriptFlags cfg params height
        (← j.getObjValAs? Bool "blockWord")) "unresolved script heights"
  return { params, height, tipHeight, flags, consensus, onBlock, now }

private def listsOf (j : Json) : Except String FrozenLists := do
  let block ← (← j.getObjValAs? (List Json) "block").mapM pointOf
  let policy ← (← j.getObjValAs? (List Json) "policy").mapM pointOf
  let whitelist ← (← j.getObjValAs? (List String) "whitelist").mapM bytesOf
  -- These are effective projections at this row's height, not operator modes.
  return { frozen := fun onBlock _ p => block.contains p || (!onBlock && policy.contains p)
           whitelisted := fun _ _ id => whitelist.contains id }

private def rejectJson (reject : Reject) : Json :=
  let code := match reject.code with
    | .node n => toJson n
    | .rpc n => toJson n
  Json.mkObj [("status", toJson "rejected"), ("code", code), ("reason", toJson reject.reason)]

private def feeJson : Except Reject Int → Json
  | .ok amount => Json.mkObj [("status", toJson "ok"), ("fee", toJson amount)]
  | .error reject => rejectJson reject

private def runRow (j expected : Json) : Except String (Bool × String) := do
  let kind ← j.getObjValAs? String "kind"
  if kind == "fee" then
    let actual := feeJson (fee (← j.getObjValAs? Int "valueIn") (← j.getObjValAs? Int "valueOut"))
    return (actual == expected, actual.compress)
  let tx ← requireSome (decodeTx (← bytesOf (← j.getObjValAs? String "tx"))) "invalid transaction"
  let s := coinMap (← coinsOf (← j.getObjVal? "utxo"))
  let cfg ← configOf (← j.getObjVal? "config")
  let ctx ← contextOf cfg (← j.getObjVal? "context")
  let lists ← listsOf (← j.getObjVal? "frozen")
  if kind == "inputs" then
    let actual := feeJson (checkTxInputs s cfg ctx lists tx)
    return (actual == expected, actual.compress)
  unless kind == "apply" do throw s!"unknown kind {kind}"
  match applyTx s cfg ctx lists evalOracle tx with
  | .error reject =>
    let actual := rejectJson reject
    return (actual == expected, actual.compress)
  | .ok (next, undo) =>
    unless (← expected.getObjValAs? String "status") == "ok" do
      return (false, "accepted, expected rejection")
    let expectedState := coinMap (← coinsOf (← expected.getObjVal? "state"))
    let expectedSpent ← coinsOf (← expected.getObjVal? "spent")
    let expectedFee ← expected.getObjValAs? Int "fee"
    let actualFee := if BsvScript.TxRules.isCoinBase tx then 0 else inputValue s tx - outputValue tx
    let expectedRestore ← expected.getObjValAs? Bool "undoRestores"
    let restored := decide (undoTx next ctx.params ctx.height tx undo = s)
    let stateOk := decide (next = expectedState)
    let undoOk := decide (undo.spent = expectedSpent)
    let feeOk := actualFee == expectedFee
    return (stateOk && undoOk && feeOk && restored == expectedRestore,
      s!"state={stateOk} spent={undoOk} fee={feeOk} undoRestores={restored}")

private def checkRow (j : Json) : Except String (String × Bool × String) := do
  let id ← j.getObjValAs? String "id"
  unless (← j.getObjValAs? String "label") == "[D]" do throw s!"{id}: missing derived label"
  unless NodeMetadata.valid (← j.getObjValAs? String "node") do throw s!"{id}: unexpected node column"
  unless (← j.getObjValAs? String "source").contains "6504a3aff65ba97c0f6c80962b033e35ecbfed4b" do
    throw s!"{id}: missing source pin"
  let _ ← j.getObjValAs? String "family"
  let _ ← j.getObjValAs? String "scope"
  let (agrees, detail) ← runRow j (← j.getObjVal? "expected")
  return (id, agrees, detail)

end UtxoCheck

def main (args : List String) : IO UInt32 := do
  let path := args.headD "../corpus/chain/utxo/utxo.jsonl"
  let lines ← IO.FS.lines path
  let mut seen : List String := []
  let mut agree := 0
  let mut mismatch := 0
  for line in lines do
    if line.trimAscii.isEmpty then continue
    let result := do
      let j ← Json.parse line
      UtxoCheck.checkRow j
    match result with
    | .error error =>
      IO.eprintln s!"utxocheck: malformed row: {error}"
      return 1
    | .ok (id, agrees, detail) =>
      if seen.contains id then
        IO.eprintln s!"utxocheck: duplicate id {id}"
        return 1
      seen := id :: seen
      if agrees then agree := agree + 1
      else
        mismatch := mismatch + 1
        IO.eprintln s!"utxocheck: MISMATCH {id}: {detail}"
  let good := !seen.isEmpty && mismatch == 0
  IO.println s!"utxocheck: {if good then "GREEN" else "RED"} [X] ([M] {seen.length} rows; agree {agree}; mismatch {mismatch}; spec column [D]; node column independently recorded)"
  return if good then 0 else 1
