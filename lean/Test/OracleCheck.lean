import BsvChain
import Bsvs.Run
import Lean.Data.Json

/-!
# Recorded script oracle agreement (#76)

The existing cpp-sigopcount columns are loaded independently of evaluation.
The supplemental call corpus records exact parameters for wrapper boundaries.
[SRC] src/validation.cpp:1328–1347,1411–1423,705–717,2693–2707,2738–2749
at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
-/

open Lean BsvChain BsvScript.Tx BsvScript.Numbers BsvScript.Params BsvScript.Machine

namespace OracleCheck

private def requireSome (o : Option α) (message : String) : Except String α :=
  match o with
  | some value => .ok value
  | none => .error message

private def bytesOf (s : String) : Except String Bytes :=
  requireSome (hexDecode s) "invalid hex"

-- The parser lists the existing ScriptError constructors, then uses their
-- existing names. It adds no error vocabulary or rule.
private def errors : List BsvScript.ScriptError := [.unknownError,
    .evalFalse,
    .opReturn,
    .scriptSize,
    .pushSize,
    .opCount,
    .stackSize,
    .sigCount,
    .pubkeyCount,
    .invalidOperandSize,
    .invalidNumberRange,
    .impossibleEncoding,
    .invalidSplitRange,
    .scriptnumOverflow,
    .scriptnumMinencode,
    .verify,
    .equalverify,
    .checkmultisigverify,
    .checksigverify,
    .numequalverify,
    .badOpcode,
    .disabledOpcode,
    .invalidStackOperation,
    .invalidAltstackOperation,
    .unbalancedConditional,
    .divByZero,
    .modByZero,
    .negativeLocktime,
    .unsatisfiedLocktime,
    .sigHashtype,
    .sigDer,
    .minimaldata,
    .sigPushonly,
    .sigHighS,
    .sigNulldummy,
    .pubkeytype,
    .cleanstack,
    .minimalif,
    .sigNullfail,
    .discourageUpgradableNops,
    .noncompressedPubkey,
    .illegalForkid,
    .mustUseForkid,
    .illegalChronicle,
    .bigInt,
    .invalidFlags]

private def verdictOf (j : Json) : Except String Verdict := do
  match ← j.getObjValAs? String "verdict" with
  | "valid" => return .valid
  | "invalid" =>
    let code ← j.getObjValAs? String "code"
    return .invalid (← requireSome (errors.find? (·.name == code)) s!"unknown script code {code}")
  | v => throw s!"non-judging recorded verdict {v}"

private def verdictJson (v : Verdict) : Except String Json := do
  match v with
  | .valid => return Json.mkObj [("verdict", toJson "valid")]
  | .invalid e => return Json.mkObj [("verdict", toJson "invalid"), ("code", toJson e.name)]
  | _ => throw "cannot record a non-judging oracle result"

private def columnOf : String → Except String OracleColumn
  | "spec" => .ok .spec
  | "spec-mempool" => .ok .specMempool
  | _ => .error "expected spec or spec-mempool column"

private def paramsJson (p : EvalParams) : Json := Json.mkObj [
  ("flags", toJson p.flags.toWord),
  ("maxOpsPerScript", toJson p.limits.maxOpsPerScript),
  ("maxScriptNumLength", toJson p.limits.maxScriptNumLength),
  ("maxScriptSize", toJson p.limits.maxScriptSize),
  ("maxPubKeysPerMultiSig", toJson p.limits.maxPubKeysPerMultiSig),
  ("maxStackMemoryUsage", toJson p.limits.maxStackMemoryUsage)]

private def paramsOf (j : Json) : Except String EvalParams := do
  let word ← j.getObjValAs? Nat "flags"
  let flags := Flags.ofWord word
  unless flags.toWord == word do throw "unknown flag bits"
  return { flags, limits := {
    maxOpsPerScript := ← j.getObjValAs? Nat "maxOpsPerScript"
    maxScriptNumLength := ← j.getObjValAs? Nat "maxScriptNumLength"
    maxScriptSize := ← j.getObjValAs? Nat "maxScriptSize"
    maxPubKeysPerMultiSig := ← j.getObjValAs? Nat "maxPubKeysPerMultiSig"
    maxStackMemoryUsage := ← j.getObjValAs? Nat "maxStackMemoryUsage" } }

private def coinOf (j : Json) : Except String Prevout := do
  let hash ← bytesOf (← j.getObjValAs? String "hash")
  unless hash.length == 32 do throw "outpoint hash width"
  let point := OutPoint.mk hash (← j.getObjValAs? Nat "index")
  return (point, { value := ← j.getObjValAs? Int "value"
                   script := ← bytesOf (← j.getObjValAs? String "script")
                   height := ← j.getObjValAs? Nat "height"
                   isCoinbase := ← j.getObjValAs? Bool "isCoinbase"
                   isConfiscation := ← j.getObjValAs? Bool "isConfiscation" })

private def configOf (j : Json) : Except String BsvChain.NodeConfig := do
  return { BsvChain.NodeConfig.defaults with
    maxStackMemoryUsageConsensus := ← j.getObjValAs? Nat "maxStackMemoryUsageConsensus"
    maxStackMemoryUsagePolicy := ← j.getObjValAs? Nat "maxStackMemoryUsagePolicy"
    maxScriptSizePolicy := ← j.getObjValAs? Nat "maxScriptSizePolicy"
    maxScriptNumLengthPolicy := ← j.getObjValAs? Nat "maxScriptNumLengthPolicy" }

private def chainOf (j : Json) : Except String BsvChain.ChainParams := do
  let network ← j.getObjValAs? String "network"
  let base ← match network with
    | "regtest" => pure BsvChain.ChainParams.regtest
    | "mainnet" => pure BsvChain.ChainParams.mainnet
    | _ => throw "unsupported network"
  return { base with genesisHeight := ← j.getObjValAs? Nat "genesisHeight"
                     chronicleHeight := ← j.getObjValAs? Nat "chronicleHeight" }

private def wordOf (j : Json) : Except String ScriptWord := do
  match ← j.getObjValAs? String "word" with
  | "block" => return .block
  | "relay" => return .relay (Flags.ofWord (← j.getObjValAs? Nat "excluded"))
  | "mandatory" => return .mandatory
  | "explicit" => return .explicit (Flags.ofWord (← j.getObjValAs? Nat "flags"))
  | _ => throw "unsupported caller word"

private def supplementalCall (j : Json) : Except String ScriptCall := do
  let tx ← requireSome (decodeTx (← bytesOf (← j.getObjValAs? String "tx"))) "invalid tx frame"
  let prevouts ← (← j.getObjValAs? (List Json) "utxo").mapM coinOf
  unless prevouts.length == tx.inputs.length do throw "unaligned prevouts"
  for (input, (point, _)) in tx.inputs.zip prevouts do
    unless point == OutPoint.ofInput input do throw "prevout identity mismatch"
  let input ← j.getObjValAs? Nat "input"
  let (_, coin) ← requireSome prevouts[input]? "input out of range"
  let cfg ← configOf (← j.getObjVal? "config")
  let context ← j.getObjVal? "context"
  let chain ← chainOf context
  let height ← context.getObjValAs? Nat "height"
  let tipHeight ← context.getObjValAs? Nat "tipHeight"
  let request ← j.getObjVal? "request"
  let params ← requireSome (scriptEvalParams cfg chain height tipHeight (← wordOf request)
      (← request.getObjValAs? Bool "consensus") coin) "unresolved script heights"
  let params ← match (← request.getObjValAs? String "stage") with
    | "input" => pure params
    | "modified-mandatory" => pure (mandatoryRecheckParams cfg
        (protocolEraOf chain.genesisHeight chain.chronicleHeight height) params.flags)
    | "inverse-genesis" | "inverse-chronicle" => do
      let flags ← requireSome (callerScriptFlags cfg chain height (← wordOf request)) "unresolved word"
      requireSome (graceRecheckParams cfg chain height tipHeight flags
        ((← request.getObjValAs? String "stage") == "inverse-genesis") coin) "unsupported inverse era"
    | _ => throw "unknown call stage"
  return ⟨tx, prevouts, input, coin.height, height, params⟩

private def insertRecording (m : RecordedVerdicts) (key : RecordedKey) (v : Verdict) :
    Except String RecordedVerdicts := do
  if let some old := m.lookup key then
    unless old == v do throw "conflicting recordings for the same full key"
  return m.insert key v

private def checkCall (column : OracleColumn) (call : ScriptCall) (v : Verdict) : Bool :=
  let recorded : RecordedVerdicts := (∅ : RecordedVerdicts).insert ⟨column, call⟩ v
  call.run evalOracle == v && call.run (recordedOracle recorded column) == v

-- Mutate every component of the key, including each resource limit. None may
-- reuse the old verdict. This guards the lookup's context boundary.
private def keyIsolation (column : OracleColumn) (call : ScriptCall) : Bool := Id.run do
  let m : RecordedVerdicts := (∅ : RecordedVerdicts).insert ⟨column, call⟩ .valid
  let limits := call.params.limits
  let changedLimits := [
    { limits with maxOpsPerScript := limits.maxOpsPerScript + 1 },
    { limits with maxScriptNumLength := limits.maxScriptNumLength + 1 },
    { limits with maxScriptSize := limits.maxScriptSize + 1 },
    { limits with maxPubKeysPerMultiSig := limits.maxPubKeysPerMultiSig + 1 },
    { limits with maxStackMemoryUsage := limits.maxStackMemoryUsage + 1 }]
  let changed := [
    { call with tx := { call.tx with lockTime := call.tx.lockTime + 1 } },
    { call with prevouts := [] }, { call with input := call.input + 1 },
    { call with coinHeight := call.coinHeight + 1 },
    { call with spendHeight := call.spendHeight + 1 },
    { call with params := { call.params with flags :=
        { call.params.flags with minimalIf := !call.params.flags.minimalIf } } }]
    ++ changedLimits.map (fun limits => { call with params := { call.params with limits } })
  let other := match column with | .spec => .specMempool | .specMempool => .spec
  return changed.all (fun c => c.run (recordedOracle m column) == recordedOracleMissing) &&
    call.run (recordedOracle m other) == recordedOracleMissing

private def existingRow (j : Json) : Except String (String × List (OracleColumn × ScriptCall × Verdict)) := do
  let entry ← Bsvs.Corpus.parseEntry j
  -- The chosen family has one input per row; a transaction aggregate must
  -- never be guessed to be each input's verdict in a multi-input family.
  unless entry.tx.inputs.length == 1 do throw "existing column requires one-input rows"
  let prevouts ← entry.prevouts.mapM fun p => do
    let hash ← bytesOf p.txid
    return (OutPoint.mk hash.reverse p.vout, Coin.mk p.satoshis p.script p.height false false)
  let (_, coin) ← requireSome prevouts[0]? "missing prevout"
  let mut calls := []
  for (column, name, consensus) in [(OracleColumn.spec, "spec@cb7e46e", true),
      (OracleColumn.specMempool, "spec-mempool@cb7e46e", false)] do
    let expected ← requireSome (entry.expect.lookup name) s!"missing recorded column {name}"
    let raw ← (← j.getObjVal? "expect").getObjVal? name
    let v ← verdictOf raw
    unless expected.input == none || expected.input == some 0 do throw "wrong recorded input"
    -- run_diff's spec-mempool column uses the relay word and ignores the
    -- entry's explicit flags; spec retains them (harness/src/bin/run_diff.rs).
    let explicit := if consensus then entry.flags.bind (·[0]?) else none
    let params := (Bsvs.Run.paramsFor BsvScript.Params.NodeConfig.svMainnetDefault
      entry.spendHeight coin.height consensus explicit).params
    let call : ScriptCall := ⟨entry.tx, prevouts, 0, coin.height, entry.spendHeight, params⟩
    calls := calls ++ [(column, call, v)]
  return (entry.id, calls)

private def put (j : Json) (key : String) (value : Json) : Except String Json := do
  let obj ← j.getObj?
  return Json.mkObj ((obj.toList.filter (fun pair => pair.1 != key)) ++ [(key, value)])

private def recordRow (j : Json) : Except String Json := do
  let call ← supplementalCall j
  let column ← j.getObjValAs? String "column"
  let _ ← columnOf column
  let v ← verdictJson (call.run evalOracle)
  let j ← put j "effective" (paramsJson call.params)
  let j ← put j "expect" (Json.mkObj [(column, v)])
  put j "label" (toJson "[M]")

private def rejectionJson : Except Reject Unit → Json
  | .ok () => Json.mkObj [("status", toJson "ok")]
  | .error e => Json.mkObj [("status", toJson "rejected"),
      ("code", match e.code with | .node n => toJson n | .rpc n => toJson n),
      ("reason", toJson e.reason)]

private def checkInline (recorded : RecordedVerdicts) (j : Json) : Except String Unit := do
  let call ← supplementalCall j
  let cfg ← configOf (← j.getObjVal? "config")
  let ctx ← j.getObjVal? "context"
  let chain ← chainOf ctx
  let tip ← ctx.getObjValAs? Nat "tipHeight"
  let flags ← requireSome (callerScriptFlags cfg chain call.spendHeight
    (← wordOf (← j.getObjVal? "request"))) "unresolved word"
  let column ← columnOf (← j.getObjValAs? String "column")
  let spec ← j.getObjVal? "inline"
  let genesis ← spec.getObjValAs? Bool "genesisGrace"
  let chronicle ← spec.getObjValAs? Bool "chronicleGrace"
  let expected ← spec.getObjVal? "expected"
  let run := fun oracle => inlineScriptCheck cfg chain tip flags genesis chronicle oracle call
  let actual := rejectionJson (run evalOracle)
  unless actual == expected do throw s!"inline evaluator mismatch: {actual.compress}"
  unless rejectionJson (run (recordedOracle recorded column)) == expected do
    throw "inline recorded-oracle mismatch"
  if (← spec.getObjValAs? Bool "requiresRecheck") then
    let onlyInitial : RecordedVerdicts := (∅ : RecordedVerdicts).insert ⟨column, call⟩ (call.run evalOracle)
    unless (run (recordedOracle onlyInitial column)) ==
        .error ⟨.node 0, "model: non-judging script oracle result"⟩ do
      throw "unexecuted re-check did not decline"

private def checkFiles (existing supplement : String) : IO UInt32 := do
  let mut rows := 0
  let mut agreements := 0
  let mut mismatch := 0
  let mut seen : List String := []
  let mut recorded : RecordedVerdicts := ∅
  let mut allCalls : List (OracleColumn × ScriptCall × Verdict) := []
  let mut supplements := 0
  let mut inlineRows : List Json := []
  for (path, isSupplement) in [(existing, false), (supplement, true)] do
    let mut fileRows := 0
    for line in ← IO.FS.lines path do
      if line.trimAscii.isEmpty then continue
      let parsed := do
        let j ← Json.parse line
        if !isSupplement then existingRow j else do
          let id ← j.getObjValAs? String "id"
          unless (← j.getObjValAs? String "label") == "[M]" do throw "missing measurement label"
          unless (← j.getObjValAs? String "source").contains "6504a3aff65ba97c0f6c80962b033e35ecbfed4b" do
            throw "missing source pin"
          let call ← supplementalCall j
          let saved ← paramsOf (← j.getObjVal? "effective")
          unless saved == call.params do throw "effective parameters changed from recording"
          let name ← j.getObjValAs? String "column"
          let column ← columnOf name
          let v ← verdictOf (← (← j.getObjVal? "expect").getObjVal? name)
          return (id, [(column, { call with params := saved }, v)])
      match parsed with
      | .error e => IO.eprintln s!"oraclecheck: malformed row: {e}"; return 1
      | .ok (id, calls) =>
        if seen.contains id then
          IO.eprintln s!"oraclecheck: duplicate id {id}"
          return 1
        seen := id :: seen
        rows := rows + 1
        fileRows := fileRows + 1
        if isSupplement then
          supplements := supplements + 1
          if let .ok j := Json.parse line then
            if (j.getObjVal? "inline").isOk then inlineRows := inlineRows ++ [j]
        for (column, call, v) in calls do
          match insertRecording recorded ⟨column, call⟩ v with
          | .error e => IO.eprintln s!"oraclecheck: {e}: {id}"; return 1
          | .ok m => recorded := m
          allCalls := allCalls ++ [(column, call, v)]
          if !keyIsolation column call then
            IO.eprintln s!"oraclecheck: key isolation failed {id}"
            return 1
    if fileRows == 0 then
      IO.eprintln s!"oraclecheck: empty corpus {path}"
      return 1
  for (column, call, v) in allCalls do
    if checkCall column call v && call.run (recordedOracle recorded column) == call.run evalOracle then
      agreements := agreements + 1
    else
      mismatch := mismatch + 1
      IO.eprintln s!"oraclecheck: MISMATCH input {call.input}: {repr (call.run evalOracle)}"
  for j in inlineRows do
    match checkInline recorded j with
    | .ok () => pure ()
    | .error e => IO.eprintln s!"oraclecheck: {e}"; return 1
  IO.println s!"oraclecheck: inline mappings GREEN ({inlineRows.length}; uncovered re-checks decline)"
  IO.println s!"oraclecheck: {if mismatch == 0 then "GREEN" else "RED"} ({rows} rows; cpp-sigopcount {rows - supplements}; wrapper {supplements}; agree {agreements}; mismatch {mismatch}; key isolation {allCalls.length * 12})"
  return if mismatch == 0 then 0 else 1

end OracleCheck

def main (args : List String) : IO UInt32 := do
  match args with
  | ["--record", input, output] =>
    let mut lines := []
    for line in ← IO.FS.lines input do
      if line.trimAscii.isEmpty then continue
      match Json.parse line >>= OracleCheck.recordRow with
      | .error e => IO.eprintln s!"oraclecheck record: {e}"; return 1
      | .ok j => lines := lines ++ [j.compress]
    if lines.isEmpty then
      IO.eprintln "oraclecheck record: empty corpus"
      return 1
    IO.FS.writeFile output (String.intercalate "\n" lines ++ "\n")
    IO.println s!"oraclecheck record: {lines.length} measured rows [M]"
    return 0
  | [] =>
    OracleCheck.checkFiles "../corpus/cpp/replay/cpp-sigopcount/cases.jsonl"
      "../corpus/chain/oracle/oracle.jsonl"
  | [existing, supplement] => OracleCheck.checkFiles existing supplement
  | _ => IO.eprintln "usage: oraclecheck [existing.jsonl oracle.jsonl] | --record input.jsonl output.jsonl"; return 2
