import BsvChain.Pow
import BsvChain.Merkle
import BsvChain.Utxo
import Bsvs.Run

/-!
# Block validity (#63)

[SRC] bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.
These are fresh checks of immutable bodies. The source's memory-only
`fChecked` hint (src/validation.cpp:5754–5760,5892–5897) belongs to #64's
cache discipline; it is not an unchecked caller assertion in this API.
`Bsvs.Run.rejectCode` is the existing pure transaction-reason rendering;
importing it avoids a second mapping. Every transaction check and hash is
the existing interpreter definition. No definition here performs IO.
-/

namespace BsvChain
open BsvScript.Numbers BsvScript.Tx BsvScript.TxRules

/-- Header and transactions in serialized order.
[SRC] src/primitives/block.h:79–107 at 6504a3af. -/
structure Block where
  header : BlockHeader
  transactions : List Tx
  deriving Repr

/-- Block serialization reuses the transaction serializer and CompactSize.
[SRC] src/primitives/block.h:103–107 at 6504a3af. -/
def Block.encode (b : Block) : Bytes :=
  b.header.encode ++ BsvScript.Sighash.compactSize b.transactions.length ++
    (b.transactions.map BsvScript.Sighash.serTx).flatten

/-- Decode one whole block using the interpreter's transaction prefix reader.
[SRC] src/primitives/block.h:103–107 at 6504a3af. -/
def Block.decode (bs : Bytes) : Option Block := do
  let (header, rest) ← BlockHeader.decodePrefix bs
  let (count, rest) ← readVarInt rest
  let (transactions, rest) ← readMany decodeTxPrefix count rest
  if rest.isEmpty then some ⟨header, transactions⟩ else none

/-- Explicit validation switches, defaulting to full validation, as read by
[SRC] src/validation.h:358–372 and src/validation.cpp:5740,5769,5801,5811 at 6504a3af. Cache publication
and mining RPC construction are outside these immutable checks. -/
structure BlockCheckOptions where
  proofOfWork : Bool := true
  merkleRoot : Bool := true
  maxBlockSize : Bool := true
  deriving Repr

/-- Preserve the distinction that prevents an incorrect body from permanently
invalidating its header. [SRC] src/consensus/validation.h:26–42,68–75 and
src/validation.cpp:5772–5785 at 6504a3af. Code and reason reuse #60's record. -/
structure BlockReject extends Reject where
  corruptionPossible : Bool := false
  deriving DecidableEq, Repr

/-- The header's proof-of-work gate with the node's reason.
[SRC] src/validation.cpp:5736–5747 at 6504a3af. -/
def checkBlockHeader (params : ChainParams) (header : BlockHeader)
    (options : BlockCheckOptions := {}) : Except Reject Unit :=
  if options.proofOfWork && !checkProofOfWork params header.hash header.bits then
    .error ⟨.node 0x10, "high-hash"⟩
  else .ok ()

/-- Lift the existing structural check, retaining its existing reason text.
[SRC] src/validation.cpp:519–639,5823–5827,5877–5882 at 6504a3af. -/
def blockTxCheck (result : Except TxReject Unit) : Except BlockReject Unit :=
  result.mapError (fun r => ⟨⟨.node 0x10, Bsvs.Run.rejectCode r⟩, false⟩)

/-- Full uncached body check, in source order: PoW, root, mutation, empty
body, early count/serialized-size setting, coinbase, then alternating regular
checks and running pre-Genesis sigops. The block size is a setting with a
consensus role (`excessiveBlockSize`); it is not a universal resource limit.
The transaction caps are the existing cited constants, not policy caps.
[SRC] src/validation.cpp:5749–5901, src/config.cpp:831–834,2417–2420,
src/configscriptpolicy.cpp:397–412 and src/validation.h:67–68 at 6504a3af. -/
def checkBlock (params : ChainParams) (cfg : NodeConfig) (block : Block)
    (height : Nat) (options : BlockCheckOptions := {}) : Except BlockReject Unit := do
  (checkBlockHeader params block.header options).mapError (fun r => ⟨r, false⟩)
  if options.merkleRoot then
    let m := blockMerkleRoot block.transactions
    if headerWordBytes 32 block.header.merkleRoot.toNat != m.root then
      throw ⟨⟨.node 0x10, "bad-txnmrklroot"⟩, true⟩
    if m.mutated then throw ⟨⟨.node 0x10, "bad-txns-duplicate"⟩, true⟩
  let coinbase ← match block.transactions with
    | [] => throw ⟨⟨.node 0x10, "bad-cb-missing"⟩, false⟩
    | cb :: _ => pure cb
  let minSize := (BsvScript.Sighash.serTx ⟨1, [], [], 0⟩).length
  if options.maxBlockSize && minSize > 0 && block.transactions.length > cfg.excessiveBlockSize / minSize then
    throw ⟨⟨.node 0x10, "bad-blk-length"⟩, false⟩
  let size := block.encode.length
  if options.maxBlockSize && size > cfg.excessiveBlockSize then
    throw ⟨⟨.node 0x10, "bad-blk-length"⟩, false⟩
  let preGenesis := !(BsvScript.Params.protocolEraOf params.genesisHeight params.chronicleHeight height).genesisActive
  let maxSize := if preGenesis then MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS
    else BsvScript.TxPolicy.MAX_TX_SIZE_CONSENSUS_AFTER_GENESIS
  blockTxCheck (checkCoinbase coinbase MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS maxSize preGenesis)
  let maxSigOps := (1 + (size - 1) / MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS) * cfg.maxBlockSigOpsPerMbBeforeGenesis
  let mut sigops := 0
  for (tx, index) in block.transactions.zipIdx do
    if index > 0 then
      blockTxCheck (checkRegularTransaction tx MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS maxSize preGenesis)
    if preGenesis then
      sigops := sigops + sigOpCountWithoutP2SH tx
      if sigops > maxSigOps then throw ⟨⟨.node 0x10, "bad-blk-sigops"⟩, false⟩
  return ()

/-- Exact hexadecimal version reason, with the source's eight wire digits.
[SRC] src/validation.cpp:5968–5971 at 6504a3af. -/
def badVersionReason (header : BlockHeader) : String :=
  "bad-version(0x" ++ hexEncode (headerWordBytes 4 header.version.toNat).reverse ++ ")"

/-- Contextual check for a non-genesis header. `AcceptBlockHeader` skips the
genesis hash and only calls this after finding a parent; the callee itself
dereferences that parent for MTP. Missing ancestry or unresolved network
heights is `none`, never a rejection. `now` is the explicit signed adjusted
time. Difficulty, lower time, upper time, then version floors retain priority.
[SRC] src/validation.cpp:5933–5975,6152–6187 at 6504a3af. -/
def contextualCheckBlockHeader (params : ChainParams) (cfg : NodeConfig)
    (header : BlockHeader) (previous : HeaderChain) (now : Int) : Option (Except Reject Unit) := do
  let expected ← getNextWorkRequired params cfg (some previous) header
  if header.bits != expected then return .error ⟨.node 0x10, "bad-diffbits"⟩
  let median ← previous.medianAt cfg previous.height
  if header.time.toNat ≤ median then return .error ⟨.node 0x10, "time-too-old"⟩
  if (header.time.toNat : Int) > now + cfg.maxFutureBlockTimeSeconds then
    return .error ⟨.node 0x10, "time-too-new"⟩
  let bip66 ← params.bip66Height
  let bip65 ← params.bip65Height
  let height := previous.height + 1
  if (header.signedVersion < 2 && height ≥ params.bip34Height) ||
      (header.signedVersion < 3 && height ≥ bip66) ||
      (header.signedVersion < 4 && height ≥ bip65) then
    return .error ⟨.node 0x11, badVersionReason header⟩
  return .ok ()

/-- The coinbase's expected height push. Small integers use their dedicated
opcodes; the remaining heights reuse the script-number encoder. Heights on
the source path are nonnegative `int32_t`, so the length fits a direct push.
[SRC] src/validation.cpp:6085–6093 and src/script/script.cpp:228–245 at 6504a3af. -/
def coinbaseHeightPush (height : Nat) : Bytes :=
  if height = 0 then [0]
  else if height ≤ 16 then [0x50 + height]
  else let bytes := BsvScript.Numbers.encode height; bytes.length :: bytes

/-- Body context: size setting, every transaction's existing #60 finality
judge, then the BIP34 height prefix. Earlier structural validity is the caller's
precondition; missing coinbase/input at the prefix stage yields `none`.
[SRC] src/validation.cpp:6039–6104 at 6504a3af. -/
def contextualCheckBlock (params : ChainParams) (cfg : NodeConfig) (block : Block)
    (previous : Option HeaderChain) : Option (Except Reject Unit) := do
  let height := previous.map (·.height + 1) |>.getD 0
  let times := previous.map (fun c => c.ancestors.map (·.time)) |>.getD []
  if block.encode.length > cfg.excessiveBlockSize then return .error ⟨.node 0x10, "bad-blk-length"⟩
  if let some c := previous then
    let _ ← c.medianAt cfg c.height
  for tx in block.transactions do
    let verdict ← contextualCheckTransactionForBlock params cfg tx height block.header.time.toNat times
    match verdict with
    | .error r => return .error r
    | .ok _ => pure ()
  if height ≥ params.bip34Height then
    let coinbase ← block.transactions.head?
    let input ← coinbase.inputs.head?
    let expect := coinbaseHeightPush height
    if input.scriptSig.take expect.length != expect then return .error ⟨.node 0x10, "bad-cb-height"⟩
  return .ok ()

/-- Subsidy in satoshis: [D] 50 * 100000000, shifted by the era, zero at
[SRC] 64 halvings. Positive halving interval is a source-parameter precondition.
[SRC] src/validation.cpp:2252–2262 and src/amount.h:115,130 at 6504a3af. -/
def getBlockSubsidy (params : ChainParams) (height : Nat) : Nat :=
  let halvings := height / params.subsidyHalvingInterval
  if halvings ≥ 64 then 0 else 5000000000 / 2 ^ halvings

/-- All subsidy eras, each lasting the network's halving interval. The
per-era constancy and eventual-zero theorems justify this finite schedule
total. [SRC] src/validation.cpp:2252–2262 at 6504a3af. -/
def subsidyScheduleTotal (params : ChainParams) : Nat :=
  params.subsidyHalvingInterval *
    ((List.range 64).map (fun era => getBlockSubsidy params (era * params.subsidyHalvingInterval))).sum

/-- The coinbase reward stage for #64 to call after deriving the fees from
sequentially accepted transactions. The coinbase structure and output money
ranges must already have passed `checkBlock`; the amount sum is #61's existing
definition. This is not block connection by itself.
[SRC] src/validation.cpp:3655–3666 at 6504a3af. -/
def checkCoinbaseAmount (params : ChainParams) (height : Nat) (coinbase : Tx)
    (fees : Int) : Except Reject Unit :=
  if outputValue coinbase > fees + getBlockSubsidy params height then
    .error ⟨.node 0x10, "bad-cb-amount"⟩
  else .ok ()

/-- The standalone TTOR scan: no transaction may occur after a transaction
that refers to its identifier. Coinbase's null outpoint is skipped.
[SRC] src/validation.cpp:5634–5655 at 6504a3af. -/
def checkBlockTTOROrder (block : Block) : Bool := Id.run do
  let mut used : List Bytes := []
  for tx in block.transactions do
    if used.contains (BsvScript.Sighash.txid tx) then return false
    for input in tx.inputs do
      if !outPointIsNull input then used := input.prevHash :: used
  return true

/-- TTOR is "a local policy and not a consensus rule" [SRC]
src/validation.h:345–350 at 6504a3af. This policy gate uses the census's
distance parameter, with signed tip-minus-block subtraction. No active tip
means no gate. The later UTXO connection order remains #64's obligation.
[SRC] src/validation.cpp:5671–5682 at 6504a3af. -/
def checkBlockTTORPolicy (cfg : NodeConfig) (block : Block) (height : Nat)
    (activeTip : Option Nat) : Except Reject Unit :=
  if activeTip.any (fun tip => (tip : Int) - height ≥ cfg.minTtorValidationDistance) && !checkBlockTTOROrder block then
    .error ⟨.node 0, "bad-blk-ttor"⟩
  else .ok ()

/-- C: coins and the best-block pointer are committed together. The genesis
connection changes only the pointer. [SRC] src/validation.cpp:3035–3050,3260
and src/processing_block_index.cpp:74 at 6504a3af. -/
structure CoinsView where
  coins : UtxoSet := ∅
  bestBlock : BitVec 256 := 0

/-- C: retained block undo contains only the non-coinbase spent-coin vectors.
It contains neither overwritten outputs nor previous views.
[SRC] src/undo.h:109–112 and src/validation.cpp:3437–3443 at 6504a3af. -/
structure BlockUndo where
  transactions : List Undo := []
  deriving DecidableEq, Repr

/-- Interfaces to the era-rule and validation-depth lanes. `bip30Required` is
the effective BIP30 branch (its historical exceptions, the BIP34 shortcut and
the resolved setting), not another setting; since #69 the chain transition
derives it by `eraConnectionChecks` over `bip30Enforced` (Eras.lean) at
[SRC] src/validation.cpp:3070–3117.
`checkScripts` is #73's effective assumevalid decision at :3482–3518.
the effective #69 branch (including its historical exceptions), not another
setting; #69 owns its derivation at [SRC] src/validation.cpp:3070–3117.
`checkScripts` is the effective assumevalid decision at :3482–3518, computed
by `scriptChecksRequired` (BsvChain/Depth.lean, #73) and fed through
`ChainContext.connectionChecks` by `ChainContext.withValidationDepth`.
The default performs both checks. `queued` records the execution schedule,
not a consensus choice; both schedules judge the same calls at :3421–3430,
3678–3714. All citations at 6504a3af. -/
structure ConnectionChecks where
  bip30Required : Bool := true
  checkScripts : Bool := true
  queued : Bool := true
  deriving Repr

/-- C: transient application receipt, exposed for the sequential-view laws and
diagnostics. Only its `undo` is retained in the block index.
[SRC] src/validation.cpp:3324–3443 at 6504a3af. -/
structure BlockApplication where
  tx : Tx
  before : UtxoSet
  after : UtxoSet
  undo : Undo

/-- C: sequential application result and queued script calls. Receipts are
not serialized undo. [SRC] src/validation.cpp:3290–3447,3655–3714 at 6504a3af. -/
structure BlockRun where
  coins : UtxoSet
  applications : List BlockApplication := []
  fees : Int := 0
  sigops : Nat := 0
  calls : List ScriptCall := []

/-- C: reconstruct the exact oracle keys from the view immediately before a
transaction. Coinbase and confiscation queue no scripts.
[SRC] src/validation.cpp:2864–2868,2900–2924,3379–3393 at 6504a3af. -/
def blockScriptCalls (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (tx : Tx) : List ScriptCall :=
  if isCoinBase tx || isConfiscationTx tx then [] else
    let prevouts := tx.inputs.filterMap fun i => (getCoin s (.ofInput i)).map (OutPoint.ofInput i, ·)
    prevouts.zipIdx.map fun ((_, coin), index) =>
      ⟨tx, prevouts, index, coin.height, ctx.height,
        inputEvalParams cfg ctx.params ctx.height ctx.tipHeight ctx.flags true coin⟩

/-- C: a deferred call has no result yet. This oracle is used only while
constructing a queued batch, or under #73's explicit script-check waiver;
the queued path judges the collected calls before committing the block.
[SRC] src/validation.cpp:2910–2914,3379–3393,3678–3714 at 6504a3af. -/
def deferredBlockOracle : ScriptOracle := fun _ _ _ _ _ _ => .valid

/-- C: availability, block BIP68 and the pre-Genesis sigop sum, in source
order. CSV selects the block word; the mempool tip shortcut is not used.
Missing network/ancestor data is a model error, never a validity judgment.
[SRC] src/validation.cpp:3324–3365,3461–3472 at 6504a3af. -/
def checkBlockInputs (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (previous : Option HeaderChain) (tx : Tx) (total cap : Nat) : Except Reject Nat := do
  if !haveInputs s tx then throw ⟨.node 0x10, "bad-txns-inputs-missingorspent"⟩
  let era := BsvScript.Params.protocolEraOf ctx.params.genesisHeight ctx.params.chronicleHeight ctx.height
  if !isCoinBase tx then
    let some csv := ctx.params.csvHeight | throw ⟨.node 0, "model: unresolved CSV height"⟩
    let flags := if ctx.height ≥ csv then standardNonFinalVerifyFlags era else 0
    let heights := tx.inputs.filterMap fun i => (getCoin s (.ofInput i)).map (·.height)
    let ancestor := fun h => previous.bind (fun p => p.medianAt cfg h)
    let some locks := calculateSequenceLocks tx flags heights ancestor
      | throw ⟨.node 0, "model: missing sequence-lock ancestry"⟩
    let median := previous.bind (fun p => p.medianAt cfg p.height) |>.getD 0
    if !evaluateSequenceLocks ctx.height median locks then
      throw ⟨.node 0x10, "bad-txns-nonfinal"⟩
  if era.genesisActive then return total
  let coins := tx.inputs.filterMap fun i =>
    (getCoin s (.ofInput i)).map (fun c => (c.script, (c.era ctx.params ctx.tipHeight).genesisActive))
  let counted := if ctx.flags.p2sh then BsvScript.TxPolicy.txSigOpCount false tx coins
    else BsvScript.TxPolicy.sigOpCountWithoutP2SHAt false tx
  let some count := counted
    | throw ⟨.node 0x10, "bad-txn-sigops"⟩
  if count > MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS then throw ⟨.node 0x10, "bad-txn-sigops"⟩
  if total + count > cap then throw ⟨.node 0x10, "bad-blk-sigops"⟩
  return total + count

/-- C: every transaction goes through the landed `applyTx` in body order.
The running view determines availability, fees, oracle keys and spent undo.
[SRC] src/validation.cpp:3290–3447 at 6504a3af. -/
def runBlockTransactions (cfg : NodeConfig) (ctx : UtxoContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (previous : Option HeaderChain) (checks : ConnectionChecks)
    (cap : Nat) : List Tx → UtxoSet → Nat → Except Reject BlockRun
  | [], s, total => .ok ⟨s, [], 0, total, []⟩
  | tx :: rest, s, total => do
    let count ← checkBlockInputs s cfg ctx previous tx total cap
    let judge := if checks.checkScripts && !checks.queued then oracle else deferredBlockOracle
    let (next, undo) ← applyTx s cfg ctx lists judge tx
    let tail ← runBlockTransactions cfg ctx lists oracle previous checks cap rest next count
    let amount := if isCoinBase tx then 0 else inputValue s tx - outputValue tx
    let calls := if checks.checkScripts && checks.queued then blockScriptCalls s cfg ctx tx else []
    return { tail with
      applications := ⟨tx, s, next, undo⟩ :: tail.applications
      fees := amount + tail.fees
      calls := calls ++ tail.calls }

/-- C: the parallel queue's failure reason has no script-error suffix. A
non-verdict remains non-judging; it cannot mark a chain invalid.
[SRC] src/validation.cpp:3678–3714 at 6504a3af. -/
def finishBlockScripts (oracle : ScriptOracle) (calls : List ScriptCall) : Except Reject Unit := do
  for call in calls do
    match call.run oracle with
    | .valid => pure ()
    | .invalid _ => throw ⟨.node 0x10, "blk-bad-inputs"⟩
    | verdict => queuedScriptResult verdict

/-- C: atomic connection result, with transient receipts separate from the
retained undo. [SRC] src/validation.cpp:3204–3224,3260 at 6504a3af. -/
structure ConnectedBlock where
  view : CoinsView
  undo : BlockUndo
  run : BlockRun

/-- C: connect to the current best pointer, repeat `checkBlock`, apply body
context and the effective BIP30 gate (#69's `bip30Enforced`), use the block script word, apply
transactions, bound the reward, finish queued checks, then update the pointer.
Genesis creates no coins. #70 supplies effective block frozen lists; #73
supplies the depth decision. The block index retains the returned undo.
[SRC] src/validation.cpp:3021–3050,3070–3117,3204–3260,3290–3719 at 6504a3af. -/
def prepareBlockConnection (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int)
    (checks : ConnectionChecks) : Except BlockReject (Option UtxoContext) := do
  let height := previous.map (·.height + 1) |>.getD 0
  checkBlock params cfg block height
  if block.header.prevBlock != view.bestBlock then
    throw ⟨⟨.node 0, "model: parent is not the coins tip"⟩, false⟩
  if block.header.hash.toNat == params.hashGenesisBlock then
    return none
  let lift := fun (r : Reject) => BlockReject.mk r false
  let some contextual := contextualCheckBlock params cfg block previous
    | throw ⟨⟨.node 0, "model: unresolved body context"⟩, false⟩
  contextual.mapError lift
  if checks.bip30Required then
    for tx in block.transactions do
      for (_, index) in tx.outputs.zipIdx do
        if (getCoin view.coins ⟨BsvScript.Sighash.txid tx, index⟩).isSome then
          throw ⟨⟨.node 0x10, "bad-txns-BIP30"⟩, false⟩
  let some flags := ordinaryScriptFlags cfg params height true
    | throw ⟨⟨.node 0, "model: unresolved block script word"⟩, false⟩
  return some ⟨params, height, height - 1, flags, true, true, now⟩

/-- C: atomic connection using the prepared context, then reward and queued
script validation. Genesis publishes only its best pointer.
[SRC] src/validation.cpp:3021–3050,3290–3719 at 6504a3af. -/
def connectBlock (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int)
    (lists : FrozenLists) (oracle : ScriptOracle) (checks : ConnectionChecks := {}) :
    Except BlockReject ConnectedBlock := do
  let context ← prepareBlockConnection view params cfg block previous now checks
  let some ctx := context
    | return ⟨{ view with bestBlock := block.header.hash }, {}, ⟨view.coins, [], 0, 0, []⟩⟩
  let lift := fun (r : Reject) => BlockReject.mk r false
  let cap := (1 + (block.encode.length - 1) / MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS) *
    cfg.maxBlockSigOpsPerMbBeforeGenesis
  let run ← (runBlockTransactions cfg ctx lists oracle previous checks cap block.transactions view.coins 0).mapError lift
  let some cb := block.transactions.head? | throw ⟨⟨.node 0x10, "bad-cb-missing"⟩, false⟩
  (checkCoinbaseAmount params ctx.height cb run.fees).mapError lift
  (finishBlockScripts oracle run.calls).mapError lift
  return ⟨⟨run.coins, block.header.hash⟩, ⟨(run.applications.drop 1).map (·.undo)⟩, run⟩

/-- C: source disconnect status, distinct from the transition's publication.
[SRC] src/processing_block_index.cpp:16–18,43–46,57–69,76 at 6504a3af. -/
inductive DisconnectResult where
  | failed | unclean | ok
  deriving DecidableEq, Repr

/-- C: AddCoin's stored-height pruning also applies to restored coins.
[SRC] src/validation.cpp:2937–2953 and src/coins.cpp:45–64 at 6504a3af. -/
def restorableUndo (params : ChainParams) (undo : Undo) : Undo :=
  ⟨undo.spent.filter fun (_, coin) =>
    !(isUnspendable (decide (params.genesisHeight ≤ coin.height)) coin.script)⟩

/-- C: apply one retained vector, comparing output value/script only, then
restoring inputs in reverse order. Existing input coins make the undo unclean
but are overwritten. Key alignment is the model's vector-shape precondition.
[SRC] src/processing_block_index.cpp:21–69 and src/validation.cpp:2937–2953
at 6504a3af. -/
def disconnectTransaction (s : UtxoSet) (params : ChainParams) (height : Nat)
    (tx : Tx) (undo : Undo) (coinbase : Bool) : DisconnectResult × UtxoSet :=
  let outputs := createdOutputs params height tx
  let missing := outputs.any fun (p, coin) =>
    match getCoin s p with
    | none => true
    | some actual => actual.value != coin.value || actual.script != coin.script
  let erased := eraseKeys s (outputs.map Prod.fst)
  if !coinbase && (undo.spent.map Prod.fst != tx.inputs.map OutPoint.ofInput) then
    (.failed, erased)
  else
    let undo := if coinbase then Undo.mk [] else undo
    let collision := (undo.spent.reverse.foldl (fun (state : UtxoSet × Bool) (p, coin) =>
      let dirty := state.2 || (getCoin state.1 p).isSome
      let next := if isUnspendable (decide (params.genesisHeight ≤ coin.height)) coin.script then state.1
        else state.1.insert p coin
      (next, dirty)) (erased, false)).2
    (if missing || collision then .unclean else .ok,
      undoTx s params height tx (restorableUndo params undo))

/-- C: reverse transaction order and reverse input restoration, with failed
dominating unclean. The recursive form also exposes the inverse for proofs.
[SRC] src/processing_block_index.cpp:21–69 at 6504a3af. -/
def disconnectTransactions (params : ChainParams) (height : Nat) :
    List (Tx × Undo × Bool) → UtxoSet → DisconnectResult × UtxoSet
  | [], s => (.ok, s)
  | (tx, undo, coinbase) :: rest, s =>
    let (status, after) := disconnectTransactions params height rest s
    if status == .failed then (.failed, after) else
      let (current, before) := disconnectTransaction after params height tx undo coinbase
      (if current == .failed then .failed
       else if status == .unclean || current == .unclean then .unclean else .ok, before)

/-- C align the non-coinbase vectors with their transactions, giving coinbase
an empty vector. Count agreement is checked before use.
[SRC] src/processing_block_index.cpp:16–18,51–59 at 6504a3af. -/
def blockUndoPairs (txs : List Tx) (undos : List Undo) : List (Tx × Undo × Bool) :=
  match txs with
  | [] => []
  | cb :: rest => (cb, ⟨[]⟩, true) :: (rest.zip undos).map (fun (tx, u) => (tx, u, false))

/-- C: low-level tentative undo, including count failure and best-pointer
update even for an unclean result. [SRC] src/processing_block_index.cpp:9–77
at 6504a3af. -/
def applyBlockUndo (view : CoinsView) (params : ChainParams) (height : Nat)
    (block : Block) (undo : BlockUndo) : DisconnectResult × CoinsView :=
  if undo.transactions.length + 1 != block.transactions.length then (.failed, view)
  else
    let pairs := blockUndoPairs block.transactions undo.transactions
    let (status, coins) := disconnectTransactions params height pairs view.coins
    (status, ⟨coins, if status == .failed then view.bestBlock else block.header.prevBlock⟩)

/-- C: DisconnectTip publishes only a clean undo; a failed or unclean local
span is discarded. The caller adds the returned body's transactions to its
bounded disconnect pool and updates the active tip only on `ok`.
[SRC] src/validation.cpp:4065–4117 at 6504a3af. -/
def disconnectBlock (view : CoinsView) (params : ChainParams) (height : Nat)
    (block : Block) (undo : BlockUndo) : DisconnectResult × CoinsView :=
  if view.bestBlock != block.header.hash then (.failed, view) else
    let (status, tentative) := applyBlockUndo view params height block undo
    (status, if status == .ok then tentative else view)

end BsvChain
