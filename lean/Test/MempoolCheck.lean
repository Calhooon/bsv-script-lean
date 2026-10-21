import BsvChain.Rejects
import Lean.Data.Json
import Test.NodeMetadata

/-!
Source-derived policy boundary corpus for #62. The evaluator is the existing
script oracle; expected verdicts are literal source readings, not node runs.
The node column records per-row metadata independently of this spec projection.
[SRC] src/validation.cpp:895–946,1009–1494 and src/txmempool.cpp:2201–2220,
2704–2798 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.

[D] 2026-10-14 (#71): the `p2pTrace` action replays an ordered list of peer
and RPC steps through the inventory envelope of `BsvChain.Rejects`, each
inventory test under the tip label the row names, each timed validation under
the elapsed observation the row names.
[SRC] src/net/net_processing.cpp:930–961,3351–3408 and
src/txn_validator.cpp:633–641 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
-/
open Lean BsvChain BsvScript.Tx BsvScript.Numbers

namespace MempoolCheck

def field [FromJson α] (j : Json) (key : String) (fallback : α) : Except String α :=
  match j.getObjVal? key with
  | .error _ => .ok fallback
  | .ok value => fromJson? value

def object (j : Json) (key : String) : Json := (j.getObjVal? key).toOption.getD (Json.mkObj [])

def bytes (s : String) : Except String Bytes :=
  match hexDecode s with | some b => .ok b | none => .error "bad hex"

def txOf (j : Json) : Except String Tx := do
  let raw ← bytes (← j.getStr?)
  match BsvScript.Tx.decodeTx raw with
  | some tx => return tx
  | none => throw "bad transaction"

def pointOf (j : Json) : Except String OutPoint := do
  return ⟨← bytes (← j.getObjValAs? String "hash"), ← field j "index" 0⟩

def configOf (j : Json) : Except String NodeConfig := do
  let c := NodeConfig.defaults
  return { c with
    requireStandard := ← field j "requireStandard" c.requireStandard
    acceptNonStandardOutput := ← field j "acceptNonStdOutputs" c.acceptNonStandardOutput
    chainRequireStandard := ← field j "chainRequireStandard" c.chainRequireStandard
    maxTxSigOpsCountConsensusBeforeGenesis := ← field j "maxTxSigOpsCountConsensusBeforeGenesis" c.maxTxSigOpsCountConsensusBeforeGenesis
    maxTxSizeConsensusBeforeGenesis := ← field j "maxTxSizeConsensusBeforeGenesis" c.maxTxSizeConsensusBeforeGenesis
    maxTxSizeConsensusAfterGenesis := ← field j "maxTxSizeConsensusAfterGenesis" c.maxTxSizeConsensusAfterGenesis
    maxTxSizePolicy := ← field j "maxTxSizePolicy" c.maxTxSizePolicy
    maxTxSigOpsCountPolicy := ← field j "maxTxSigOpsCountPolicy" c.maxTxSigOpsCountPolicy
    maxMempool := ← field j "maxMempool" c.maxMempool
    maxPrimaryPromotionVisits := ← field j "maxPrimaryPromotionVisits" c.maxPrimaryPromotionVisits
    maxMempoolSizeDisk := ← field j "maxMempoolSizeDisk" c.maxMempoolSizeDisk
    mempoolMaxPercentCPFP := ← field j "mempoolMaxPercentCPFP" c.mempoolMaxPercentCPFP
    maxMempoolNonFinal := ← field j "maxMempoolNonFinal" c.maxMempoolNonFinal
    mempoolExpiry := ← field j "mempoolExpiry" c.mempoolExpiry
    mempoolNonFinalExpiry := ← field j "mempoolNonFinalExpiry" c.mempoolNonFinalExpiry
    maxOrphanTxSize := ← field j "maxOrphanTxSize" c.maxOrphanTxSize
    orphanTrimHysteresisDivisor := ← field j "orphanTrimHysteresisDivisor" c.orphanTrimHysteresisDivisor
    orphanExpirySeconds := ← field j "orphanExpirySeconds" c.orphanExpirySeconds
    orphanExpiryCheckIntervalSeconds := ← field j "orphanExpiryCheckIntervalSeconds" c.orphanExpiryCheckIntervalSeconds
    maxCoinsViewCacheSize := ← field j "maxCoinsViewCacheSize" c.maxCoinsViewCacheSize
    maxStdTxnValidationDuration := ← field j "maxStdTxnValidationDuration" c.maxStdTxnValidationDuration
    maxNonStdTxnValidationDuration := ← field j "maxNonStdTxnValidationDuration" c.maxNonStdTxnValidationDuration
    maxTxnChainValidationBudget := ← field j "maxTxnChainValidationBudget" c.maxTxnChainValidationBudget
    maxTxFee := ← field j "maxTxFee" c.maxTxFee
    minDebugRejectionFee := ← field j "minDebugRejectionFee" c.minDebugRejectionFee
    blockMinTxFee := ← field j "blockMinTxFee" c.blockMinTxFee
    limitAncestorCount := ← field j "limitAncestorCount" c.limitAncestorCount
    limitSecondaryMempoolAncestorCount := ← field j "limitSecondaryMempoolAncestorCount" c.limitSecondaryMempoolAncestorCount
    nonFinalMaxReplacementRate := ← field j "nonFinalMaxReplacementRate" c.nonFinalMaxReplacementRate
    nonFinalReplacementPeriodMinutes := ← field j "nonFinalReplacementPeriodMinutes" c.nonFinalReplacementPeriodMinutes
    minConsolidationFactor := ← field j "minConsolidationFactor" c.minConsolidationFactor
    minConfConsolidationInput := ← field j "minConfConsolidationInput" c.minConfConsolidationInput
    maxConsolidationInputScriptSize := ← field j "maxConsolidationInputScriptSize" c.maxConsolidationInputScriptSize
    acceptNonStdConsolidationInput := ← field j "acceptNonStdConsolidationInput" c.acceptNonStdConsolidationInput
    rollingFeeHalfLifeSeconds := ← field j "rollingFeeHalfLifeSeconds" c.rollingFeeHalfLifeSeconds
    genesisGracefulPeriod := ← field j "genesisGracefulPeriod" c.genesisGracefulPeriod
    chronicleGracefulPeriod := ← field j "chronicleGracefulPeriod" c.chronicleGracefulPeriod }

def sourceOf : String → Except String TxSource
  | "rpc" => .ok .rpc | "p2p" => .ok .p2p | "reorg" => .ok .reorg
  | "finalised" => .ok .finalised | "file" => .ok .file
  | s => .error s!"unknown source {s}"

def requestOf (tx : Tx) (j : Json) (now : Int) : Except String TxRequest := do
  return {
    tx, acceptTime := ← field j "acceptTime" now,
    source := ← sourceOf (← field j "source" "rpc"),
    priority := if (← field j "lowPriority" false) then .low else .high,
    useLimits := ← field j "useLimits" false,
    limitMempoolSize := ← field j "limitMempoolSize" true,
    orphanHandler := ← field j "orphanHandler" false,
    absurdFee := ← field j "absurdFee" none,
    skipScriptFlags := BsvScript.Params.Flags.ofWord (← field j "skipScriptFlags" 0) }

def entryOf (j : Json) : Except String MempoolEntry := do
  let tx ← txOf (← j.getObjVal? "tx")
  let size := (BsvScript.Sighash.serTx tx).length
  return {
    tx, fee := ← field j "fee" 100, time := ← field j "time" 1000,
    height := ← field j "height" 200, size, innerUsage := ← field j "innerUsage" size,
    ancestorCount := ← field j "ancestorCount" 0,
    groupingFee := ← field j "groupingFee" (← field j "fee" 100),
    groupingSize := ← field j "groupingSize" size,
    secondaryAncestorCount := ← field j "secondaryAncestorCount" 0,
    primary := ← field j "primary" true,
    cpfpGroup := ← (← field j "cpfpGroup" (none : Option String)).mapM bytes }

def poolOf (cfg : NodeConfig) (j : Json) : Except String Mempool := do
  let accepted ← (← field j "accepted" ([] : List Json)).mapM entryOf
  let nonFinal ← (← field j "nonFinal" ([] : List Json)).mapM fun row => do
    let entry ← entryOf row
    let fill ← field row "rateFill" (0 : Nat)
    let last ← field row "lastDrainNanos" (0 : Int)
    return (⟨entry, ⟨fill.toFloat.toBits, last⟩⟩ : NonFinalEntry)
  let orphans ← (← field j "orphans" ([] : List Json)).mapM fun row => do
    let tx ← txOf (← row.getObjVal? "tx")
    let request ← requestOf tx (object row "request") 1000
    let expires ← field row "expiresAt" (2200 : Int)
    return (⟨request, expires, (BsvScript.Sighash.serTx tx).length⟩ : OrphanEntry)
  let rate ← field j "rollingRate" (0 : Nat)
  let deltaRows ← field j "feeDeltas" ([] : List Json)
  let deltas ← deltaRows.mapM fun row => do
    return (← bytes (← row.getObjValAs? String "id"), ← row.getObjValAs? Int "delta")
  return reindex {
    accepted, nonFinal, orphans, feeDeltas := deltas,
    recentRejects := rejectFilter cfg (← (← field j "recentRejects" ([] : List String)).mapM bytes),
    nonFinalRecentlyRemoved := removedNonFinalFilter cfg,
    rollingFee := ⟨rate.toFloat.toBits, ← field j "lastUpdate" 1000, ← field j "blockSinceBump" false⟩,
    orphanControl := ⟨← field j "nextSweep" 0, ← field j "untrimmedBytes" 0⟩ }

def contextOf (j : Json) : Except String AdmissionContext := do
  let tipHeight ← field j "tipHeight" 200
  let median ← field j "median" (1000 : Int)
  let params := { ChainParams.regtest with
    genesisHeight := ← field j "genesisHeight" 0,
    chronicleHeight := ← field j "chronicleHeight" 1000000 }
  let budget ← match (← field j "budget" "available") with
    | "available" => pure ValidationBudget.available
    | "inputs" => pure .inputsExpired | "relay" => pure .relayExpired
    | "block" => pure .blockExpired | "mandatory" => pure .mandatoryExpired
    | _ => throw "unknown budget"
  let evictionIndex ← field j "orphanEvictionIndex" 0
  let override ← field j "innerUsage" (none : Option Nat)
  return {
    orphanEvictionChoice := fun _ => evictionIndex,
    params, tipHeight, tipMedianTimePast := median, tipTimes := [median.toNat],
    now := ← field j "now" 1000, bucketTime := ← field j "bucketTimeNanos" 0, budget, accounting := PoolAccounting.byteOnly,
    innerUsage := fun tx => override.getD (BsvScript.Sighash.serTx tx).length }

def utxoOf (j : Json) : Except String UtxoSet := do
  let coins ← (← fromJson? j : List Json).mapM fun row => do
    let point ← pointOf row
    let coin : Coin := ⟨← field row "value" 1000, ← bytes (← field row "script" "51"),
      ← field row "height" 1, ← field row "coinbase" false, ← field row "confiscation" false⟩
    return (point, coin)
  return coinMap coins

def stageName : AdmissionStage → String
  | .regular => "regular" | .standard => "standard" | .finality => "finality"
  | .alreadyKnown => "alreadyKnown" | .conflict => "conflict" | .inputs => "inputs"
  | .sequence => "sequence" | .inputStandard => "inputStandard" | .sigops => "sigops"
  | .fee => "fee" | .ancestors => "ancestors" | .scripts => "scripts"
  | .detector => "detector" | .commit => "commit"

def outcomeFields : TxOutcome → List (String × Json)
  | .completed (.rejected code reason) => [("status", toJson "rejected"),
      ("code", match code with | .node n => toJson n | .rpc n => toJson n), ("reason", toJson reason)]
  | .completed .accepted => [("status", toJson "accepted")]
  | .completed .heldNonFinal => [("status", toJson "heldNonFinal")]
  | .completed .orphan => [("status", toJson "orphan")]
  | .deferred => [("status", toJson "deferred")]
  | .suppressed => [("status", toJson "suppressed")]
  | .unverifiable s => [("status", toJson "unverifiable"), ("reason", toJson s)]

def snapshot (p : Mempool) : List (String × Json) :=
  [("primary", toJson ((p.accepted.filter (·.primary)).map (fun e => hexEncode e.id))),
   ("accepted", toJson (p.accepted.map (fun e => hexEncode e.id))),
   ("held", toJson (p.nonFinal.map (fun e => hexEncode e.entry.id))),
   ("orphanCount", toJson p.orphans.length),
   ("orphanBytes", toJson ((p.orphans.map (·.size)).sum)),
   ("retainedSetSize", toJson ((p.orphans.map (fun e => BsvScript.Sighash.txid e.request.tx)).eraseDups.length)),
   ("orphans", toJson (p.orphans.map (fun e => hexEncode (BsvScript.Sighash.txid e.request.tx)))),
   ("pending", toJson (p.pending.map (fun e => hexEncode (BsvScript.Sighash.txid e.request.tx)))),
   ("pendingLow", toJson (p.pending.all (fun e => e.request.priority == .low))),
   ("lastUpdate", toJson p.rollingFee.lastUpdate),
   ("blockSinceBump", toJson p.rollingFee.blockSinceBump),
   ("rollingRate", toJson ((Float.ofBits p.rollingFee.rateBits).toUInt64.toNat)),
   ("usage", toJson (poolUsage PoolAccounting.byteOnly p)),
   ("spentCount", toJson p.mapNextTx.length),
   ("nextSweep", toJson p.orphanControl.nextSweep),
   ("untrimmedBytes", toJson p.orphanControl.untrimmedBytes)]

/-- One answer word per step of a `p2pTrace` row (#71). -/
def answerOf : TxOutcome → String
  | .completed .accepted => "accepted"
  | .completed .heldNonFinal => "heldNonFinal"
  | .completed .orphan => "orphan"
  | .completed (.rejected code reason) =>
    s!"rejected {match code with | .node n => toString n | .rpc n => toString n} {reason}"
  | .deferred => "deferred"
  | .suppressed => "suppressed"
  | .unverifiable reason => s!"unverifiable {reason}"

def elapsedOf (j : Json) : Except String ElapsedObservation := do
  return {
    carried := ← field j "carried" 0, inputs := ← field j "inputs" 0, relay := ← field j "relay" 0,
    block := ← field j "block" 0, mandatory := ← field j "mandatory" 0 }

/-- [D] 2026-10-14 (#71): replay peer and RPC steps in order. `inv` and `tx`
run the inventory test under the step's tip label; a `tx` whose request is
moved to low priority is taken through the validator's next cycle, as the
node does before it answers; `mine` and `invalidate` change the node's tip
and are no pool event (the blocks of these rows are empty). A step is listed
in `nonJudging` when `budgetJudgment` of its validations' clock dependence is
non-judging (an available budget included), or when `inventoryJudgment` of
its inventory test is (fix-71, [M] 2026-10-14). -/
def traceRow (j : Json) (cfg : NodeConfig) (ctx : AdmissionContext) (p : Mempool)
    (utxo : UtxoSet) (lists : FrozenLists) (detector : DetectorObservation) : Except String Json := do
  let named ← (← (← j.getObjVal? "txs").getObj?).toList.mapM fun (name, raw) => do
    return (name, ← txOf raw)
  let mut pool := p
  let mut answers : Array String := #[]
  let mut nonJudging : Array Nat := #[]
  for (step, index) in (← field j "steps" ([] : List Json)).zipIdx do
    let op ← step.getObjValAs? String "op"
    if op == "mine" || op == "invalidate" then
      answers := answers.push "tip"
      continue
    let name ← step.getObjValAs? String "tx"
    let some tx := named.lookup name | throw s!"unknown transaction {name}"
    if op == "rpc" then
      let (next, outcome) := accept pool utxo cfg ctx lists evalOracle detector
        { tx, source := .rpc, acceptTime := ctx.now }
      pool := next
      answers := answers.push (answerOf outcome)
      continue
    let obs : InventoryObservation := { tip := ← bytes (← step.getObjValAs? String "tip") }
    let inventory := inventoryJudgment pool obs (BsvScript.Sighash.txid tx)
    if op == "inv" then
      let (next, answer) := receiveInv pool obs (BsvScript.Sighash.txid tx)
      pool := next
      answers := answers.push (if answer == .request then "request" else "silence")
      if inventory != .judging then nonJudging := nonJudging.push index
    else if op == "tx" then
      let high ← elapsedOf (object step "elapsedHigh")
      let low ← elapsedOf (object step "elapsedLow")
      let mut dependence := receiveP2PTxClockDependence pool utxo cfg ctx lists evalOracle detector obs tx
      let mut budget := budgetObservation cfg .high high
      let mut state := receiveP2PTx pool utxo cfg ctx lists evalOracle detector obs high tx
      -- A request is lowered at most once and a finalising update queued once.
      for _ in [0:3] do
        if state.2 == .deferred then
          dependence := dependence.join
            (revalidateClockDependence state.1 utxo cfg ctx lists evalOracle detector)
          budget := budgetObservation cfg .low low
          let (next, outcome) := revalidateTimed state.1 utxo cfg ctx lists evalOracle detector low
          state := (next, outcome.getD .deferred)
      pool := state.1
      answers := answers.push (answerOf state.2)
      if budgetJudgment dependence budget != .judging || inventory != .judging then
        nonJudging := nonJudging.push index
    else throw s!"unknown step {op}"
  return Json.mkObj [("status", toJson "trace"), ("answers", toJson answers),
    ("remembered", toJson ((named.filter (fun (_, tx) =>
      pool.recentRejects.contains (BsvScript.Sighash.txid tx))).map (·.1))),
    ("insertions", toJson pool.recentRejects.insertions),
    ("wipeFree", toJson pool.recentRejects.wipeFree),
    ("nonJudging", toJson nonJudging)]

def runRow (j : Json) : Except String Json := do
  let cfg ← configOf (object j "cfg")
  let ctx ← contextOf (object j "context")
  let p ← poolOf cfg (object j "pool")
  let utxo ← utxoOf ((j.getObjVal? "utxo").toOption.getD (toJson ([] : List Json)))
  let frozen ← (← field j "frozen" ([] : List Json)).mapM pointOf
  let lists := { FrozenLists.empty with frozen := fun _ _ point => frozen.contains point }
  let detector : DetectorObservation := {
    committedSpends := ← (← field j "detectorCommitted" ([] : List Json)).mapM pointOf,
    validatingSpends := ← (← field j "detectorValidating" ([] : List Json)).mapM pointOf }
  let action ← field j "action" "accept"
  if action == "p2pTrace" then return ← traceRow j cfg ctx p utxo lists detector
  if action == "accept" then
    let tx ← txOf (← j.getObjVal? "tx")
    let request ← requestOf tx (object j "request") ctx.now
    let (pool, result, trace) := acceptWithTrace p utxo cfg ctx lists evalOracle detector request
    return Json.mkObj (outcomeFields result ++ [("stage", toJson ((trace.getLast?).map stageName |>.getD "none")),
      ("trace", toJson (trace.map stageName))] ++ snapshot pool)
  if action == "arrivalRevalidate" then
    let parent ← txOf (← j.getObjVal? "tx")
    let queued := retryOrphans { p with collected := [(BsvScript.Sighash.txid parent, parent.outputs.length)] }
      cfg ctx.now (← field j "batchSize" 100)
    let (pool, result) := revalidatePending queued utxo cfg ctx lists evalOracle detector
    return Json.mkObj (outcomeFields (result.getD (.unverifiable "no pending result")) ++ snapshot pool)
  if action == "revalidate" then
    let child ← txOf (← j.getObjVal? "tx")
    let request ← requestOf child (object j "request") ctx.now
    let (pool, result) := revalidatePending { p with pending := [⟨request, ctx.now⟩] } utxo cfg ctx lists evalOracle detector
    return Json.mkObj (outcomeFields (result.getD (.unverifiable "no pending result")) ++ snapshot pool)
  let pool ← match action with
    | "expire" => pure (expire p cfg ctx.now)
    | "trim" => pure (trimToSize p cfg ctx.accounting (← field j "limit" cfg.maxMempool))
    | "limit" => pure (advanceTime p cfg ctx .limit)
    | "nonFinalCheck" => pure (advanceTime p cfg ctx .nonFinalCheck)
    | "orphanSweep" => pure (advanceTime p cfg ctx .orphanSweep)
    | "blockThenDecay" => pure (decayRollingFee cfg ctx.accounting ctx.now (advanceTime p cfg ctx .blockObserved))
    | "promote" => pure (promoteLoop cfg true ((p.accepted.length + 1) ^ 2) p
        (← (← field j "queued" ([] : List String)).mapM bytes) 0)
    | "decay" => pure (decayRollingFee cfg ctx.accounting ctx.now p)
    | "retry" =>
      let parent ← txOf (← j.getObjVal? "tx")
      pure (retryOrphans { p with collected := [(BsvScript.Sighash.txid parent, parent.outputs.length)] }
        cfg ctx.now (← field j "batchSize" 100))
    | _ => throw s!"unknown action {action}"
  return Json.mkObj ([("status", toJson "maintenance")] ++ snapshot pool)

def checkRow (j : Json) : Except String (String × Bool × String) := do
  let id ← j.getObjValAs? String "id"
  unless (← j.getObjValAs? String "label") == "[D]" do throw "missing derived label"
  unless NodeMetadata.valid (← j.getObjValAs? String "node") do throw "invalid node column"
  unless (← j.getObjValAs? String "source").contains "6504a3aff65ba97c0f6c80962b033e35ecbfed4b" do
    throw "missing source pin"
  let expected ← j.getObjVal? "expected"
  let fields ← expected.getObj?
  unless (← expected.getObjValAs? String "status") != "" do throw "empty expected status"
  let actual ← runRow j
  let agrees := fields.toList.all (fun (key, value) => (actual.getObjVal? key).toOption == some value)
  return (id, agrees, s!"expected {expected.compress}; actual {actual.compress}")

end MempoolCheck

def main (args : List String) : IO UInt32 := do
  let path := args.headD "../corpus/chain/mempool/mempool.jsonl"
  let lines ← IO.FS.lines path
  let mut seen : List String := []
  let mut agree := 0
  let mut mismatch := 0
  for line in lines do
    if line.trimAscii.isEmpty then continue
    match Json.parse line >>= MempoolCheck.checkRow with
    | .error error => IO.eprintln s!"mempoolcheck: malformed row: {error}"; return 1
    | .ok (id, agrees, detail) =>
      if seen.contains id then IO.eprintln s!"mempoolcheck: duplicate id {id}"; return 1
      seen := id :: seen
      if agrees then agree := agree + 1
      else
        mismatch := mismatch + 1
        IO.eprintln s!"mempoolcheck: MISMATCH {id}: {detail}"
  let good := !seen.isEmpty && mismatch == 0
  IO.println s!"mempoolcheck: {if good then "GREEN" else "RED"} [X] ([M] {seen.length} rows; agree {agree}; mismatch {mismatch}; spec column [D]; node column independently recorded)"
  return if good then 0 else 1
