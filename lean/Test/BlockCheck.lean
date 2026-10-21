import BsvChain
import Lean.Data.Json
import Test.NodeMetadata

/-!
# Block and public-header corpus runner (#63)

Headers carry measured [M] chain bits; synthetic boundary rows are derived
[D]. The node column records per-row metadata independently of this spec projection.
The runner compares exact reasons and
corruption flags. [SRC] src/validation.cpp:5736–6104, src/pow.cpp:22–297,
src/consensus/merkle.cpp:247–282 at
6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
-/

open Lean BsvChain BsvScript.Numbers BsvScript.Tx

namespace BlockCheck

private def need (o : Option α) (message : String) : Except String α :=
  match o with
  | some a => .ok a
  | none => .error message

private def bytes (s : String) : Except String Bytes := need (hexDecode s) "invalid hex"

private def headerOf (s : String) : Except String BlockHeader := do
  need (BlockHeader.decode (← bytes s)) "invalid header frame"

private def valueOr [FromJson α] (j : Json) (key : String) (default : α) : Except String α :=
  match j.getObjVal? key with
  | .error _ => .ok default
  | .ok value => fromJson? value

private def objectOr (j : Json) (key : String) : Json := (j.getObjVal? key).toOption.getD (Json.mkObj [])

private def paramsOf (j : Json) : Except String ChainParams := do
  let network ← valueOr j "network" "regtest"
  let base ← match network with
    | "mainnet" => pure ChainParams.mainnet
    | "testnet" => pure ChainParams.testnet
    | "regtest" => pure ChainParams.regtest
    | "stn" => pure ChainParams.stn
    | _ => throw "unknown network"
  let p := objectOr j "params"
  return { base with
    bip34Height := ← valueOr p "bip34Height" base.bip34Height
    bip65Height := ← valueOr p "bip65Height" base.bip65Height
    bip66Height := ← valueOr p "bip66Height" base.bip66Height
    csvHeight := ← valueOr p "csvHeight" base.csvHeight
    genesisHeight := ← valueOr p "genesisHeight" base.genesisHeight
    daaHeight := ← valueOr p "daaHeight" base.daaHeight
    powNoRetargeting := ← valueOr p "powNoRetargeting" base.powNoRetargeting }

private def configOf (j : Json) : Except String NodeConfig := do
  let c := objectOr j "config"
  return { NodeConfig.defaults with
    excessiveBlockSize := ← valueOr c "excessiveBlockSize" NodeConfig.defaults.excessiveBlockSize
    maxBlockSigOpsPerMbBeforeGenesis := ← valueOr c "maxBlockSigOpsPerMbBeforeGenesis" NodeConfig.defaults.maxBlockSigOpsPerMbBeforeGenesis
    maxFutureBlockTimeSeconds := ← valueOr c "maxFutureBlockTimeSeconds" NodeConfig.defaults.maxFutureBlockTimeSeconds
    medianTimeSpan := ← valueOr c "medianTimeSpan" NodeConfig.defaults.medianTimeSpan
    minTtorValidationDistance := ← valueOr c "minTtorValidationDistance" NodeConfig.defaults.minTtorValidationDistance }

private def chainOf (j : Json) : Except String (Option HeaderChain) := do
  if j == Json.null then return none
  let height ← j.getObjValAs? Nat "height"
  let ancestors ← (← j.getObjValAs? (List Json) "ancestors").mapM fun r => do
    let time ← r.getObjValAs? Nat "time"
    let bits ← r.getObjValAs? Nat "bits"
    let work ← r.getObjValAs? Nat "work"
    unless time < 2 ^ 32 && bits < 2 ^ 32 && work < 2 ^ 256 do throw "ancestor word out of range"
    return (⟨time, BitVec.ofNat 32 bits, BitVec.ofNat 256 work⟩ : HeaderWork)
  return some ⟨height, ancestors⟩

private def resultJson (result : Except Reject Unit) (corrupt : Bool := false) : Json :=
  match result with
  | .ok _ => Json.mkObj [("status", toJson "ok")]
  | .error r =>
    let code := match r.code with | .node n => toJson n | .rpc n => toJson n
    Json.mkObj [("status", toJson "rejected"), ("code", code),
      ("reason", toJson r.reason), ("corruptionPossible", toJson corrupt)]

private def contextJson (result : Option (Except Reject Unit)) : Json :=
  match result with
  | none => Json.mkObj [("status", toJson "unresolved")]
  | some r => resultJson r

private def runRow (j : Json) : Except String Json := do
  let kind ← j.getObjValAs? String "kind"
  let params ← paramsOf j
  let cfg ← configOf j
  if kind == "coinbase-amount" then
    let tx ← need (decodeTx (← bytes (← j.getObjValAs? String "tx"))) "invalid coinbase frame"
    return resultJson (checkCoinbaseAmount params (← j.getObjValAs? Nat "height") tx (← j.getObjValAs? Int "fees"))
  if kind == "subsidy" then
    return toJson (getBlockSubsidy params (← j.getObjValAs? Nat "height"))
  if kind == "compact" || kind == "pow" then
    let bits ← j.getObjValAs? Nat "bits"
    unless bits < 2 ^ 32 do throw "bits out of range"
    let bits := BitVec.ofNat 32 bits
    if kind == "pow" then
      let hash ← j.getObjValAs? Nat "hash"
      unless hash < 2 ^ 256 do throw "hash out of range"
      return toJson (checkProofOfWork params (BitVec.ofNat 256 hash) bits)
    let t := compactTarget bits
    return Json.mkObj [("target", toJson t.target), ("negative", toJson t.negative), ("overflow", toJson t.overflow)]
  if kind == "context-header" || kind == "nextwork" then
    let header ← headerOf (← j.getObjValAs? String "header")
    let previous ← chainOf (← j.getObjVal? "previous")
    if kind == "nextwork" then
      return toJson ((getNextWorkRequired params cfg previous header).map (·.toNat))
    let previous ← need previous "contextual header requires parent"
    return contextJson (contextualCheckBlockHeader params cfg header previous (← j.getObjValAs? Int "now"))
  let raw ← bytes (← j.getObjValAs? String "block")
  let block ← need (Block.decode raw) "invalid block frame"
  unless block.encode == raw do throw "block codec mismatch"
  if kind == "context-block" then
    return contextJson (contextualCheckBlock params cfg block (← chainOf (← j.getObjVal? "previous")))
  if kind == "ttor" then
    return resultJson (checkBlockTTORPolicy cfg block (← j.getObjValAs? Nat "height") (← j.getObjValAs? (Option Nat) "tip"))
  unless kind == "block" do throw s!"unknown row kind {kind}"
  let opt := objectOr j "options"
  let options : BlockCheckOptions := {
    proofOfWork := ← valueOr opt "proofOfWork" true
    merkleRoot := ← valueOr opt "merkleRoot" true
    maxBlockSize := ← valueOr opt "maxBlockSize" true }
  match checkBlock params cfg block (← j.getObjValAs? Nat "height") options with
  | .ok _ => return resultJson (.ok ())
  | .error r => return resultJson (.error r.toReject) r.corruptionPossible

private def boundaryRow (j : Json) : Except String (String × Bool × String) := do
  let id ← j.getObjValAs? String "id"
  unless (← j.getObjValAs? String "label") == "[D]" do throw "missing derived label"
  unless NodeMetadata.valid (← j.getObjValAs? String "node") do throw "unexpected node column"
  unless (← j.getObjValAs? String "source").contains "6504a3aff65ba97c0f6c80962b033e35ecbfed4b" do throw "missing pin"
  let _ ← j.getObjValAs? String "derivation"
  let expected ← j.getObjVal? "expected"
  let actual ← runRow j
  return (id, actual == expected, actual.compress)

private def checkBoundaries (path : String) : IO Bool := do
  let lines ← IO.FS.lines path
  let mut seen : List String := []
  let mut agree := 0
  let mut mismatch := 0
  for line in lines do
    if line.trimAscii.isEmpty then continue
    match Json.parse line >>= boundaryRow with
    | .error error => IO.eprintln s!"blockcheck: malformed boundary: {error}"; return false
    | .ok (id, agrees, detail) =>
      if seen.contains id then IO.eprintln s!"blockcheck: duplicate id {id}"; return false
      seen := id :: seen
      if agrees then agree := agree + 1
      else mismatch := mismatch + 1; IO.eprintln s!"blockcheck: MISMATCH {id}: {detail}"
  let good := !seen.isEmpty && mismatch == 0
  IO.println s!"blockcheck: boundaries {if good then "GREEN" else "RED"} [X] ([M] {seen.length} rows; agree {agree}; mismatch {mismatch}; spec column [D]; node column independently recorded)"
  return good

private def measuredHeader (j : Json) : Except String (String × Nat × BlockHeader × String × Nat) := do
  unless (← j.getObjValAs? String "label") == "[M]" do throw "missing measured label"
  unless (← j.getObjValAs? String "source").startsWith "https://api.whatsonchain.com/" do throw "unexpected header source"
  let _ ← j.getObjValAs? String "requestedAt"
  let expected ← j.getObjVal? "expected"
  unless (← expected.getObjValAs? Bool "proofOfWork") do throw "unexpected PoW expectation"
  let raw ← bytes (← j.getObjValAs? String "header")
  let header ← need (BlockHeader.decode raw) "invalid measured header"
  unless header.encode == raw do throw "header codec mismatch"
  return (← j.getObjValAs? String "group", ← j.getObjValAs? Nat "height", header,
    ← j.getObjValAs? String "hash", ← expected.getObjValAs? Nat "nextBits")

private def checkHeaders (path : String) : IO Bool := do
  let lines ← IO.FS.lines path
  let mut group := ""
  let mut chain : Option HeaderChain := none
  let mut previousHash : Option (BitVec 256) := none
  let mut seen : List Nat := []
  let mut groups : List String := []
  let mut powOK := 0
  let mut difficultyOK := 0
  let mut unavailable := 0
  let mut mismatch := 0
  for line in lines do
    if line.trimAscii.isEmpty then continue
    match Json.parse line >>= measuredHeader with
    | .error error => IO.eprintln s!"blockcheck: malformed header: {error}"; return false
    | .ok (g, height, header, expectedHash, expectedBits) =>
      if seen.contains height then IO.eprintln "blockcheck: duplicate header height"; return false
      seen := height :: seen
      if g != group then
        if groups.contains g then IO.eprintln "blockcheck: split header group"; return false
        groups := g :: groups
        group := g
        chain := none
        previousHash := none
      if let some c := chain then
        unless height == c.height + 1 && previousHash == some header.prevBlock do
          IO.eprintln s!"blockcheck: broken chain at {height}"; return false
      let hash := header.hash
      unless hexEncode (headerWordBytes 32 hash.toNat).reverse == expectedHash do
        IO.eprintln s!"blockcheck: header hash mismatch at {height}"; return false
      if checkProofOfWork ChainParams.mainnet hash header.bits then powOK := powOK + 1
      else mismatch := mismatch + 1; IO.eprintln s!"blockcheck: PoW mismatch at {height}"
      unless expectedBits == header.bits.toNat do
        IO.eprintln "blockcheck: expectation is not the observed chain bits"; return false
      let next := if chain.isSome || height == 0 then getNextWorkRequired ChainParams.mainnet NodeConfig.defaults chain header else none
      match next with
      | none => unavailable := unavailable + 1
      | some bits =>
        if bits.toNat == expectedBits then difficultyOK := difficultyOK + 1
        else mismatch := mismatch + 1; IO.eprintln s!"blockcheck: difficulty mismatch at {height}: {bits.toNat} != {expectedBits}"
      let parentWork := chain.bind (fun c => c.ancestors.head?.map (·.chainWork)) |>.getD 0
      let ancestor : HeaderWork := ⟨header.time.toNat, header.bits, addChainWork parentWork header.bits⟩
      chain := some ⟨height, ancestor :: (chain.map (·.ancestors)).getD []⟩
      previousHash := some hash
  let good := !seen.isEmpty && difficultyOK > 0 && mismatch == 0
  IO.println s!"blockcheck: headers {if good then "GREEN" else "RED"} [X] ([M] {seen.length} rows; pow {powOK}; difficulty {difficultyOK}; ancestry unavailable {unavailable}; mismatch {mismatch}; chain column [M])"
  return good

end BlockCheck

def main (args : List String) : IO UInt32 := do
  if args.length != 2 then
    IO.eprintln "usage: blockcheck HEADERS.jsonl BLOCK.jsonl"
    return 2
  let headers ← BlockCheck.checkHeaders args[0]!
  let blocks ← BlockCheck.checkBoundaries args[1]!
  return if headers && blocks then 0 else 1
