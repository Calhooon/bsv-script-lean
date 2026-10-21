import BsvChain.Block
import BsvChain.Eras
import BsvChain.Frozen
import BsvChain.Mempool

/-!
# Chain transitions (#64)

[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
The active chain is ordered from genesis to tip. Header-only branches are
retained separately from the candidates. C denotes consensus, P policy;
operator lists, validation depth and scheduling are explicit settings/data.
The transition runs to quiescence or reports a non-completed outcome. The
source's early successful returns on cancellation/contention are not a proof
of maximal work (src/validation.cpp:4913–5130).
-/

namespace BsvChain
open BsvScript.Tx BsvScript.Numbers

/-- C validity levels and independent metadata. The double-spend marker is
not a consensus-failure bit. [SRC] src/block_index.h:41–115,187–195 at 6504a3af. -/
structure BlockStatus where
  validity : Nat := 2
  failed : Bool := false
  failedParent : Bool := false
  doubleSpend : Bool := false
  deriving DecidableEq, Repr

/-- Scheduling observation: pending compares after every completion; disk
reload and preciousblock ignore completion time. [SRC] src/block_index.h:
816–827,954,1073–1077,1239–1274 at 6504a3af. -/
inductive CompletionEvent where
  | ignored | completed (event : Nat) | pending
  deriving DecidableEq, Repr

/-- Ordered completion key, preserving the sentinel ordering without an
invented wall-clock bound. [SRC] src/block_index.h:1239–1252 at 6504a3af. -/
def CompletionEvent.key : CompletionEvent → Nat × Nat
  | .ignored => (0, 0)
  | .completed n => (1, n)
  | .pending => (2, 0)

/-- C index data, P candidate rank and setting-derived soft exclusion ranges.
`tieRank` records pointer order, never memory addresses; sequence records body
link order independently. Soft counts use -1 for absent and zero for this
block only. [SRC] src/block_index.h:330–349,542–580,1131–1146,1225–1274 and
src/validation.cpp:5662–5725 at 6504a3af. -/
structure BlockIndex where
  header : BlockHeader
  parent : Option (BitVec 256)
  height : Nat
  work : BitVec 256
  status : BlockStatus := {}
  body : Option Block := none
  undo : Option BlockUndo := none
  txCount : Nat := 0
  chainTx : Nat := 0
  completion : CompletionEvent := .pending
  sequence : Int := 0
  tieRank : Nat
  softRejected : Int := -1
  softFrozen : Int := -1
  explicitSoftRejected : Int := -1
  explicitSoftFrozen : Int := -1

/-- The block identifier is always derived from its header.
[SRC] src/block_index.h:694–707 at 6504a3af. -/
def BlockIndex.id (i : BlockIndex) : BitVec 256 := i.header.hash

/-- Header tree, candidates and parent-keyed unlinked bodies. Counters retain
the source's body-order and preciousblock scheduling observations.
[SRC] src/validation.cpp:4413–4523,5156–5190,5662–5725 at 6504a3af. -/
structure HeaderTree where
  nodes : List BlockIndex := []
  candidates : List (BitVec 256) := []
  unlinked : List (BitVec 256 × BitVec 256) := []
  nextSequence : Int := 1
  reverseSequence : Int := -1
  lastPreciousWork : Nat := 0

/-- Pure index lookup. [SRC] src/validation.cpp:6137–6169 at 6504a3af. -/
def HeaderTree.get (tree : HeaderTree) (hash : BitVec 256) : Option BlockIndex :=
  tree.nodes.find? (fun i => i.id == hash)

/-- Update an existing index without changing its observed pointer rank.
[SRC] src/validation.cpp:5528–5562 at 6504a3af. -/
def HeaderTree.modify (tree : HeaderTree) (hash : BitVec 256)
    (f : BlockIndex → BlockIndex) : HeaderTree :=
  { tree with nodes := tree.nodes.map (fun i => if i.id == hash then f i else i) }

/-- C ancestry projection, fuel bounded by the finite index size. Exhaustion
or a missing parent is explicit. [SRC] src/validation.cpp:4441–4449 at 6504a3af. -/
def ancestry (tree : HeaderTree) : Nat → Option (BitVec 256) → Option (List BlockIndex)
  | _, none => some []
  | 0, some _ => none
  | n + 1, some h => do
    let i ← tree.get h
    let rest ← ancestry tree n i.parent
    return i :: rest

/-- Complete newest-to-oldest path used by #63 and #60; missing ancestors
remain absent. [SRC] src/validation.cpp:6186–6187,3337–3347 at 6504a3af. -/
def headerContext (tree : HeaderTree) (hash : Option (BitVec 256)) : Option HeaderChain := do
  let xs ← ancestry tree (tree.nodes.length + 1) hash
  let tip ← xs.head?
  return ⟨tip.height, xs.map (fun i => ⟨i.header.time.toNat, i.header.bits, i.work⟩)⟩

/-- The hash of the ancestor at `height` on the path from `parent`, as
`GetAncestor` returns it; `none` for a missing path or no index at that height.
[SRC] src/validation.cpp:3088–3089, src/block_index.h:330–336 and
src/block_index.cpp:81–84 at 6504a3af. -/
def ancestorHashAt (tree : HeaderTree) (parent : Option (BitVec 256)) (height : Nat) :
    Option (BitVec 256) := do
  let xs ← ancestry tree (tree.nodes.length + 1) parent
  (xs.find? (·.height == height)).map (·.id)

/-- The BIP34 ancestor `pindex->GetPrev()->GetAncestor(BIP34Height)` of index
`i`: null unless the parent's height reaches `bip34Height` (`GetAncestor`
returns null above its own height), read only then.
[SRC] src/validation.cpp:3088–3095 and src/block_index.cpp:81–84 at 6504a3af. -/
def bip34Ancestor (params : ChainParams) (tree : HeaderTree) (i : BlockIndex) : Option (BitVec 256) :=
  if i.height > params.bip34Height then ancestorHashAt tree i.parent params.bip34Height else none

/-- Work is the primary C ordering. Completion, sequence and pointer rank are
P/scheduling tie choices, all earlier values preferred. [SRC]
src/block_index.h:1225–1274 at 6504a3af. -/
def preferred (a b : BlockIndex) : Bool :=
  if a.work.toNat != b.work.toNat then a.work.toNat > b.work.toNat
  else if a.completion.key != b.completion.key then (a.completion.key.1 < b.completion.key.1 ||
    (a.completion.key.1 == b.completion.key.1 && a.completion.key.2 < b.completion.key.2))
  else if a.sequence != b.sequence then a.sequence < b.sequence
  else a.tieRank < b.tieRank

/-- Maximum under the recorded comparator. [SRC] src/validation.cpp:4415–4424
and src/block_index.h:1225–1274 at 6504a3af. -/
def bestCandidate : List BlockIndex → Option BlockIndex
  | [] => none
  | i :: rest => match bestCandidate rest with
    | none => some i
    | some best => some (if preferred i best then i else best)

/-- P disconnect queue accounting observations. The allocator-rounded index
overhead is supplied by #66, not guessed from serialized bytes.
[SRC] src/txmempool.h:1481–1490 at 6504a3af. -/
structure DisconnectAccounting where
  indexBytes : Nat
  innerUsage : Tx → Nat

/-- P queue insertion order and filtered identifiers, including coinbase.
Coinbase consumes space before filtering at readmission.
[SRC] src/txmempool.h:1455–1500 and src/txmempool.cpp:2535–2560 at 6504a3af. -/
structure DisconnectPool where
  queued : List Tx := []
  filtered : List TxId := []
  cachedInnerUsage : Nat := 0

/-- P descendant removal also works when the transaction itself is absent.
[SRC] src/txmempool.cpp:913–945 at 6504a3af. -/
def removeRecursive (pool : Mempool) (cfg : NodeConfig) (tx : Tx) : Mempool :=
  let id := BsvScript.Sighash.txid tx
  let roots := pool.accepted.filter (fun e => e.id == id ||
    e.tx.inputs.any (fun i => i.prevHash == id && i.prevIndex < tx.outputs.length)) |>.map (·.id)
  removeStaged pool cfg (descendantIds pool roots)

/-- P queue usage, with the source's separately maintained inner allocation.
[SRC] src/txmempool.h:1481–1500 at 6504a3af. -/
def DisconnectPool.usage (p : DisconnectPool) (a : DisconnectAccounting) : Nat :=
  p.queued.length * a.indexBytes + p.cachedInnerUsage

/-- P drop the earliest queued transactions until the census cap is met,
removing their mempool descendants. [SRC] src/txmempool.cpp:2549–2559 at 6504a3af. -/
def capDisconnectPool (cfg : NodeConfig) (a : DisconnectAccounting) :
    Nat → DisconnectPool → Mempool → DisconnectPool × Mempool
  | 0, q, p => (q, p)
  | n + 1, q, p =>
    if q.usage a ≤ cfg.maxMempool then (q, p) else
      match q.queued with
      | [] => (q, p)
      | tx :: rest => capDisconnectPool cfg a n
        { q with queued := rest
                 cachedInnerUsage := q.cachedInnerUsage - a.innerUsage tx
                 filtered := q.filtered.filter (· != BsvScript.Sighash.txid tx) }
        (removeRecursive p cfg tx)

/-- P add a disconnected body in reverse transaction order, then cap it by
maxMempool. Miner-ID filtering is supplied as observed identifiers by #66/#68.
[SRC] src/txmempool.cpp:2487–2560 at 6504a3af. -/
def addToDisconnectPool (cfg : NodeConfig) (a : DisconnectAccounting) (q : DisconnectPool)
    (pool : Mempool) (block : Block) (filtered : List TxId := []) : DisconnectPool × Mempool :=
  let q := block.transactions.reverse.foldl (fun q tx =>
    let id := BsvScript.Sighash.txid tx
    { queued := if q.queued.any (fun t => BsvScript.Sighash.txid t == id) then q.queued else q.queued ++ [tx]
      filtered := if BsvScript.TxRules.isCoinBase tx || filtered.contains id then id :: q.filtered else q.filtered
      cachedInnerUsage := q.cachedInnerUsage + a.innerUsage tx }) q
  capDisconnectPool cfg a q.queued.length q pool

/-- P accepted-pool clearing preserves the held, orphan and fee-delta stores.
[SRC] src/txmempool.cpp:1345–1363 at 6504a3af. -/
def clearAccepted (p : Mempool) (now : Int) : Mempool :=
  { p with accepted := [], mapNextTx := [], rollingFee := ⟨0, now, false⟩ }

/-- P clear at the source's successor-era boundary, using the height passed
by ConnectTip or DisconnectTip. [SRC] src/validation.cpp:4036–4053,4073,4404
at 6504a3af. -/
def finalizeEraCrossing (params : ChainParams) (height : Nat) (now : Int) (p : Mempool) : Mempool :=
  if (height < params.genesisHeight && params.genesisHeight ≤ height + 1) ||
      (height < params.chronicleHeight && params.chronicleHeight ≤ height + 1) then clearAccepted p now else p

/-- P reorg removal: reject the contextual failure, fresh sequence locks or
newly immature/unavailable coinbase/confiscation inputs, with descendants.
The finality boolean is tested in both eras, including `.ok false` after
Genesis. [SRC] src/txmempool.cpp:947–1023 and
src/validation.cpp:5983–5986,6030–6036 at 6504a3af. -/
def removeForReorg (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) : Mempool :=
  let view := mempoolView p utxo
  let era := BsvScript.Params.protocolEraOf ctx.params.genesisHeight ctx.params.chronicleHeight ctx.tipHeight
  let flags := standardNonFinalVerifyFlags era
  let bad := p.accepted.filter fun entry =>
    let finalFailed := match contextualCheckTransactionForCurrentBlock ctx.params entry.tx
        ctx.tipHeight ctx.tipMedianTimePast ctx.now flags with
      | .error _ => true
      | .ok final => !final
    let sequences := checkSequenceLocks ctx.params cfg entry.tx ctx.tipHeight ctx.tipTimes
      (entry.tx.inputs.map (fun i => (getCoin view (.ofInput i)).map (·.height))) flags
    let immature := entry.spendsCoinbaseOrConfiscation && entry.tx.inputs.any (fun input =>
      if p.accepted.any (fun e => e.id == input.prevHash) then false else
        match getCoin utxo (.ofInput input) with
        | none => true
        | some coin =>
          let depth := (ctx.tipHeight + 1 : Int) - coin.height
          (coin.isCoinbase && depth < cfg.coinbaseMaturity) ||
          (coin.isConfiscation && depth < cfg.confiscationMaturity))
    finalFailed || !sequences || immature
  removeStaged p cfg (descendantIds p (bad.map (·.id)))

/-- Setting rechecks after reorg, including invalid confiscation whitelists.
Scanning every entry is the uncached equivalent of the source's change gates.
[SRC] src/txmempool.cpp:2413–2435 at 6504a3af. -/
def removeFrozenForReorg (p : Mempool) (cfg : NodeConfig) (ctx : AdmissionContext)
    (lists : FrozenLists) : Mempool :=
  let bad := p.accepted.filter fun e =>
    if isConfiscationTx e.tx then !lists.whitelisted false (ctx.tipHeight + 1) e.id
    else e.tx.inputs.any (fun i => lists.frozen false (ctx.tipHeight + 1) (.ofInput i))
  removeStaged p cfg (descendantIds p (bad.map (·.id)))

/-- P synchronous reorg admission consumes a finalisation resubmission before
the next body transaction. The finite held-entry count bounds these retries;
there is no timed cancellation on this path.
[SRC] src/txn_validator.cpp:242–302 at 6504a3af. -/
def acceptForReorg (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle) (tx : Tx) : Mempool :=
  let pending := p.pending
  let (p, _) := accept { p with pending := [] } utxo cfg ctx lists oracle {}
    { tx, source := .reorg, priority := .high, acceptTime := ctx.now, limitMempoolSize := false }
  let p := (List.range (p.nonFinal.length + 1)).foldl (fun p _ =>
    (revalidatePending p utxo cfg ctx lists oracle {}).1) p
  { p with pending := pending ++ p.pending }

/-- P disconnected transactions are submitted oldest-block order through
#62's accept with TxSource.reorg. The source's normal priority is projected to
#62's non-low value: useLimits is false and the budget is available, so no
timed priority branch can observe this projection. The saved pool is restored unchecked, as at
the pin; failed/held submissions lose descendants, then finality/maturity and
frozen settings are rechecked. [SRC] src/txmempool.cpp:2283–2443 at 6504a3af. -/
def addToMempoolForReorg (p : Mempool) (q : DisconnectPool) (utxo : UtxoSet)
    (cfg : NodeConfig) (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle) : Mempool :=
  let p := q.queued.foldl (fun p tx =>
    if q.filtered.contains (BsvScript.Sighash.txid tx) then removeRecursive p cfg tx else p) p
  let saved := p.accepted
  let rejects := p.recentRejects
  let collected := p.collected
  let txs := q.queued.reverse.filter (fun tx => !q.filtered.contains (BsvScript.Sighash.txid tx))
  let p := txs.foldl (fun p tx => acceptForReorg p utxo cfg ctx lists oracle tx) (clearAccepted p ctx.now)
  let p := if txs.isEmpty then p else limitPool p cfg ctx.accounting ctx.now
  let p := { p with recentRejects := rejects, collected }
  let p := saved.foldl (fun p e =>
    if p.accepted.any (fun present => present.id == e.id) then p else
      addUnchecked p cfg { e with ancestorCount := ((poolParents p e.tx).map (fun p => p.ancestorCount + 1)).foldl max 0 }) p
  let p := txs.foldl (fun p tx =>
    if p.accepted.any (fun e => e.id == BsvScript.Sighash.txid tx) then p else removeRecursive p cfg tx) p
  removeFrozenForReorg (removeForReorg p utxo cfg ctx) cfg ctx lists

/-- P remove-only cleanup for explicit failure callers.
[SRC] src/txmempool.cpp:2446–2485 at 6504a3af. -/
def removeFromMempoolForReorg (p : Mempool) (q : DisconnectPool) (utxo : UtxoSet)
    (cfg : NodeConfig) (ctx : AdmissionContext) : Mempool :=
  removeForReorg (q.queued.foldl (fun p tx => removeRecursive p cfg tx) p) utxo cfg ctx

/-- P remove mined entries and conflicts, repair ancestor counts, then regroup
surviving secondary children together with disbanded group members.
[SRC] src/txmempool.cpp:1025–1173,481–565 at 6504a3af. -/
def removeForBlock (p : Mempool) (cfg : NodeConfig) (block : Block) (now : Int) : Mempool :=
  let (p, mined) := block.transactions.reverse.foldl (fun (state : Mempool × List TxId) tx =>
    let (p, mined) := state
    let id := BsvScript.Sighash.txid tx
    if p.accepted.any (fun e => e.id == id) then (p, id :: mined) else
      let roots := p.accepted.filter (fun e => e.tx.inputs.any (fun i =>
        tx.inputs.any (fun j => OutPoint.ofInput i == OutPoint.ofInput j))) |>.map (·.id)
      (removeStaged p cfg (descendantIds p roots), mined)) (p, [])
  let secondary := p.accepted.filter (fun e => !e.primary &&
    e.tx.inputs.any (fun i => mined.contains i.prevHash)) |>.map (·.id)
  let demote := demotionIds p mined
  let p := { p with accepted := p.accepted.map (fun e => if demote.contains e.id then
    { e with
      primary := false, cpfpGroup := none, groupingFee := 0, groupingSize := 0
      secondaryAncestorCount := 0 } else e) }
  let p := removePoolIds p mined
  let p := (List.range p.accepted.length).foldl (fun p _ =>
    { p with accepted := p.accepted.map (fun e => { e with
      ancestorCount := ((poolParents p e.tx).map (fun parent => parent.ancestorCount + 1)).foldl max 0 }) }) p
  let p := promoteLoop cfg false ((p.accepted.length + 1) ^ 2) p (demote ++ secondary) 0
  let ids := block.transactions.map BsvScript.Sighash.txid
  { p with rollingFee := { p.rollingFee with lastUpdate := now, blockSinceBump := true }
           pending := p.pending.filter (fun work => !ids.contains (BsvScript.Sighash.txid work.request.tx)) }

/-- Removal causes distinguish the C work rule from explicit operations and
settings. No strict-work premise is attached to a setting-driven removal.
[SRC] src/validation.cpp:4526–4553,4603–4612,5203–5330 at 6504a3af. -/
inductive DisconnectCause where
  | reorg | explicit | invalidate | softRejection | freezeChange
  deriving DecidableEq, Repr

/-- Observable active-chain events. Only disconnect removes a suffix element.
[SRC] src/validation.cpp:4117,4391 at 6504a3af. -/
inductive ChainEvent where
  | connected (hash : BitVec 256)
  | disconnected (cause : DisconnectCause) (hash : BitVec 256)
  deriving DecidableEq, Repr

/-- C active-chain mutation shared by all transition paths. A disconnect is
tip-only. [SRC] src/validation.cpp:4117,4391 at 6504a3af. -/
def applyChainEvent (active : List (BitVec 256)) : ChainEvent → List (BitVec 256)
  | .connected h => active ++ [h]
  | .disconnected _ h => if active.getLast? == some h then active.dropLast else active

/-- The chain state includes the separate pool and coins pointer. Event history
is diagnostic data, not serialized node storage.
[SRC] src/validation.cpp:4065–4133,4345–4404 at 6504a3af. -/
structure ChainState where
  tree : HeaderTree := {}
  active : List (BitVec 256) := []
  view : CoinsView := {}
  mempool : Mempool := {}
  disconnectPool : DisconnectPool := {}
  events : List ChainEvent := []
  reorgPending : Bool := false

/-- C publish the same active mutation and its removal cause together.
[SRC] src/validation.cpp:4117,4391 at 6504a3af. -/
def ChainState.emit (s : ChainState) (event : ChainEvent) : ChainState :=
  { s with active := applyChainEvent s.active event, events := s.events ++ [event] }

/-- #69: the era-derived connection checks for index `i`: the BIP30 gate from
its height, its hash, its BIP34 ancestor and the resolved setting. Script
checking and the schedule keep their defaults (#73's interface).
[SRC] src/validation.cpp:3070–3117 at 6504a3af. -/
def eraConnectionChecks (params : ChainParams) (cfg : NodeConfig) (s : ChainState)
    (i : BlockIndex) : ConnectionChecks :=
  { bip30Required := bip30Enforced params cfg i.height i.id (bip34Ancestor params s.tree i) }

/-- #70: the whitelist depth waiver for connecting index `i` toward `target`.
With the setting on, enforcement is disabled when `i` is at least the configured
depth under the most-work target, or under the best header with `i` on its path.
The best header is an explicit input. [SRC] src/validation.cpp:3529–3555,4261 and
src/policy/policy.h:98–101 at 6504a3af. -/
def assumeWhitelisted (cfg : NodeConfig) (s : ChainState) (i target : BlockIndex)
    (best : Option (BitVec 256)) : Bool :=
  cfg.enableAssumeWhitelistedBlockDepth &&
    (decide ((target.height : Int) - i.height ≥ cfg.assumeWhitelistedBlockDepth) ||
      (best.bind s.tree.get).any (fun b =>
        decide ((b.height : Int) - i.height ≥ cfg.assumeWhitelistedBlockDepth) &&
          ancestorHashAt s.tree (some b.id) i.height == some i.id))

/-- #70: the effective projection for connecting index `i`, derived anew for
each attempt: `i`'s explicit soft consensus freeze, read from the current tree,
and the depth waiver. [SRC] src/frozentxo.cpp:27–42 and
src/validation.cpp:3529–3555 at 6504a3af. -/
def connectionFrozenLists (cfg : NodeConfig) (s : ChainState) (i target : BlockIndex)
    (best : Option (BitVec 256)) (lists : FrozenLists) : FrozenLists :=
  lists.atBlock (decide (((s.tree.get i.id).getD i).explicitSoftFrozen ≥ 0))
    (assumeWhitelisted cfg s i target best)

/-- Settings, external time, allocator observations and the effective interfaces of the
adjacent components. Checkpoints are network data, gated by the census setting.
No resource limit is silently introduced here.
[SRC] src/validation.cpp:3070–3117,3482–3562,5903–5930 at 6504a3af. -/
structure ChainContext where
  params : ChainParams
  cfg : NodeConfig
  now : Int
  /-- Explicit system-clock nanoseconds for #62, independent of adjusted now.
  [SRC] src/leaky_bucket.h:72–85 at 6504a3af. -/
  bucketTime : Int
  accounting : PoolAccounting
  disconnectAccounting : DisconnectAccounting
  innerUsage : Tx → Nat
  checkpoints : List (Nat × BitVec 256) := []
  /-- Each attempt sees the current state, connecting index and selected target.
  The default is #69's era gate for this network and configuration; #73
  supplies the depth decision. The default is fixed when the context is built:
  an update `{ ctx with cfg := … }` keeps the old closure, so a caller that
  changes `params` or `cfg` re-derives this field. [SRC] src/validation.cpp:4261–4262,3070–3117,3530–3554 at 6504a3af. -/
  connectionChecks : ChainState → BlockIndex → BlockIndex → ConnectionChecks :=
    fun s i _ => eraConnectionChecks params cfg s i
  /-- The best header `GetBestHeader()` returns, for the whitelist depth waiver:
  an explicit input; `none` leaves only the most-work branch.
  [SRC] src/block_index_store.h:63–75,131–149 and src/validation.cpp:3544–3546 at 6504a3af. -/
  bestHeader : ChainState → Option (BitVec 256) := fun _ => none
  /-- #70 derives the effective frozen projection anew for each selected target
  (`connectionFrozenLists`); the same closure caveat as `connectionChecks` holds.
  [SRC] src/validation.cpp:3529–3554 at 6504a3af. -/
  connectionLists : ChainState → BlockIndex → BlockIndex → FrozenLists → FrozenLists :=
    fun s i target lists => connectionFrozenLists cfg s i target (bestHeader s) lists
  completionEvent : BlockIndex → Nat
  minerIdFiltered : Block → List TxId := fun _ => []
  /-- [D] 2026-10-13: forward the explicit orphan eviction input unchanged.
  [SRC] src/orphan_txns.cpp:227-243 at 6504a3af. -/
  orphanEvictionChoice : List OrphanEntry → Nat := fun _ => 0

/-- Derive the admission tip from the active chain, reusing the median helper.
[SRC] src/txmempool.cpp:2385,2406–2408 at 6504a3af. -/
def admissionContext (s : ChainState) (ctx : ChainContext) : AdmissionContext :=
  let previous := headerContext s.tree s.active.getLast?
  let height := previous.map (·.height) |>.getD 0
  let times := previous.map (fun p => p.ancestors.map (·.time)) |>.getD []
  ⟨ctx.params, height, medianTimePast times ctx.cfg.medianTimeSpan, times,
    ctx.now, ctx.accounting, ctx.innerUsage, .available, ctx.bucketTime, ctx.orphanEvictionChoice⟩

/-- Setting: exact checkpoint equality and the last-known checkpoint fork
floor. [SRC] src/validation.cpp:5903–5930 at 6504a3af. -/
def checkCheckpoint (tree : HeaderTree) (ctx : ChainContext) (header : BlockHeader)
    (height : Nat) : Except Reject Unit := do
  if !ctx.cfg.checkpointsEnabled then return ()
  if ctx.checkpoints.any (fun (h, id) => h == height && id != header.hash) then
    throw ⟨.node 0x43, "checkpoint mismatch"⟩
  let known := ctx.checkpoints.filter (fun (_, id) => (tree.get id).isSome)
  if known.any (fun (h, _) => height < h) then throw ⟨.node 0x43, "bad-fork-prior-to-checkpoint"⟩

/-- C header acceptance with invalidation/checkpoint settings. Duplicate failed
headers retain the node's code-zero duplicate reason. Genesis bypasses the
non-genesis parent/context checks. [SRC] src/validation.cpp:6134–6197 at 6504a3af. -/
def acceptHeader (s : ChainState) (ctx : ChainContext) (header : BlockHeader)
    (tieRank : Nat) : Except Reject ChainState := do
  if ctx.cfg.invalidBlocks.contains header.hash then throw ⟨.node 10, "block is marked as invalid"⟩
  let genesis := header.hash.toNat == ctx.params.hashGenesisBlock
  if let some i := s.tree.get header.hash then
    if genesis then return s
    if i.status.failed || i.status.failedParent then throw ⟨.node 0, "duplicate"⟩ else return s
  if s.tree.nodes.any (fun i => i.tieRank == tieRank) then throw ⟨.node 0, "model: duplicate pointer rank"⟩
  let parent ← if genesis then pure none else do
    checkBlockHeader ctx.params header
    let some p := s.tree.get header.prevBlock | throw ⟨.node 0, "prev-blk-not-found"⟩
    if p.status.failed || p.status.failedParent then throw ⟨.node 0x10, "bad-prevblk"⟩
    checkCheckpoint s.tree ctx header (p.height + 1)
    let some history := headerContext s.tree (some p.id) | throw ⟨.node 0, "model: missing header ancestry"⟩
    let some result := contextualCheckBlockHeader ctx.params ctx.cfg header history ctx.now
      | throw ⟨.node 0, "model: unresolved header context"⟩
    result
    pure (some p)
  let index : BlockIndex :=
    { header, parent := parent.map (·.id), height := parent.map (·.height + 1) |>.getD 0
      work := addChainWork (parent.map (·.work) |>.getD 0) header.bits
      tieRank
      softRejected := parent.map (fun p => max (-1) (p.softRejected - 1)) |>.getD (-1)
      softFrozen := parent.map (fun p => max (-1) (p.softFrozen - 1)) |>.getD (-1) }
  return { s with tree := { s.tree with nodes := s.tree.nodes ++ [index] } }

/-- P add a unique candidate only when at least as preferred as the tip.
[SRC] src/validation.cpp:5705–5708 at 6504a3af. -/
def insertCandidate (tree : HeaderTree) (active : List (BitVec 256)) (i : BlockIndex) : HeaderTree :=
  if (active.getLast?.bind tree.get).any (fun tip => preferred tip i) then tree else
    { tree with candidates := if tree.candidates.contains i.id then tree.candidates else i.id :: tree.candidates }

/-- P restore candidates after an explicit rewind, including the new tip which
may have been pruned earlier. [SRC] src/validation.cpp:5294–5303 at 6504a3af. -/
def restoreCandidates (s : ChainState) : ChainState :=
  { s with tree := s.tree.nodes.foldl (fun tree i =>
    if !i.status.failed && !i.status.failedParent && i.status.validity ≥ 3 && i.chainTx > 0 then
      insertCandidate tree s.active i else tree) s.tree }

/-- P process the received body, then its parent-keyed unlinked queue in
receipt order. Previously linked/pruned indices are processed again. The
finite queue traversal bound is not a policy limit.
[SRC] src/validation.cpp:4474–4479,5688–5725 at 6504a3af. -/
def linkBodies (active : List (BitVec 256)) : Nat → List (BitVec 256) → HeaderTree → HeaderTree
  | 0, _, tree => tree
  | _ + 1, [], tree => tree
  | n + 1, hash :: queue, tree =>
    match tree.get hash with
    | none => linkBodies active n queue tree
    | some i =>
      let count := (i.parent.bind tree.get).map (·.chainTx) |>.getD 0
      let i := { i with chainTx := count + i.txCount, sequence := tree.nextSequence }
      let children := tree.unlinked.filter (fun (parent, _) => parent == hash) |>.map Prod.snd
      let tree := tree.modify i.id (fun _ => i)
      let tree := { tree with
        nextSequence := tree.nextSequence + 1
        unlinked := tree.unlinked.filter (fun (parent, _) => parent != hash) }
      linkBodies active n (queue ++ children) (insertCandidate tree active i)

/-- Body disposition is separate from validity: unrequested equal-work,
too-far-ahead or insufficient-work bodies can be ignored successfully.
[SRC] src/validation.cpp:6272–6316 at 6504a3af. -/
inductive BodyDisposition where
  | stored | alreadyPresent | ignored
  deriving DecidableEq, Repr

/-- Failure bookkeeping: C for a validation failure, P for TTOR, and setting
for explicit invalidation. Preserve the independent double-spend marker.
[SRC] src/validation.cpp:4453–4475,5230–5289,5578–5632
at 6504a3af. -/
def markInvalid (tree : HeaderTree) (hash : BitVec 256) (markSelf : Bool := true) : HeaderTree :=
  { tree with
    nodes := tree.nodes.map (fun i =>
      if i.id == hash then if markSelf then { i with status := { i.status with failed := true } } else i
      else if (ancestry tree (tree.nodes.length + 1) (some i.id)).any (fun xs => xs.any (fun p => p.id == hash)) then
        { i with status := { i.status with failedParent := true } } else i),
    candidates := tree.candidates.filter (fun h =>
      !((ancestry tree (tree.nodes.length + 1) (some h)).any (fun xs => xs.any (fun p => p.id == hash)))) }

/-- C body checks and P/settings intake gates. Failed non-corrupt bodies mark
the index; corrupt bodies do not. The work floor below is the setting
`minimumChainWork`, a successful ignore and never a rejection; the script-check
decision and safe mode are BsvChain/Depth.lean (#73).
[SRC] src/validation.cpp:6238–6395,5662–5725 at 6504a3af. -/
def acceptBlock (s : ChainState) (ctx : ChainContext) (block : Block) (tieRank : Nat)
    (requested : Bool) : ChainState × Except BlockReject BodyDisposition :=
  match acceptHeader s ctx block.header tieRank with
  | .error r => (s, .error ⟨r, false⟩)
  | .ok s => Id.run do
    let some i := s.tree.get block.header.hash | return (s, .error ⟨⟨.node 0, "model: absent accepted header"⟩, false⟩)
    if i.body.isSome then return (s, .ok .alreadyPresent)
    let tip := s.active.getLast?.bind s.tree.get
    if !requested && (i.txCount > 0 || tip.any (fun t => i.work.toNat ≤ t.work.toNat) ||
        (i.height : Int) > (tip.map (fun t => (t.height : Int)) |>.getD (-1)) + ctx.cfg.minBlocksToKeep ||
        i.work.toNat < ctx.cfg.minimumChainWork) then return (s, .ok .ignored)
    let checks : Except BlockReject Unit := do
      checkBlock ctx.params ctx.cfg block i.height
      let some contextual := contextualCheckBlock ctx.params ctx.cfg block (headerContext s.tree i.parent)
        | throw ⟨⟨.node 0, "model: unresolved body context"⟩, false⟩
      contextual.mapError (fun r => ⟨r, false⟩)
      (checkBlockTTORPolicy ctx.cfg block i.height (tip.map (·.height))).mapError (fun r => ⟨r, false⟩)
    match checks with
    | .error r =>
      let tree := if !r.corruptionPossible && (r.code != .node 0 || r.reason == "bad-blk-ttor") then
        markInvalid s.tree i.id else s.tree
      return ({ s with tree }, .error r)
    | .ok _ =>
      let tree := s.tree.modify i.id (fun i => { i with body := some block, txCount := block.transactions.length, status := { i.status with validity := 3 } })
      let tree := if i.parent.isNone || (i.parent.bind tree.get).any (fun p => p.chainTx > 0) then
          linkBodies s.active (tree.unlinked.length + 1) [i.id] tree
        else if (i.parent.bind tree.get).any (fun p => p.status.validity ≥ 2 && !p.status.failed && !p.status.failedParent) then
          { tree with unlinked := tree.unlinked ++ [(block.header.prevBlock, i.id)] }
        else tree
      return ({ s with tree }, .ok .stored)

/-- C linked transactions and available valid ancestry, stopping at the
active chain as at the pin. [SRC] src/validation.cpp:4437–4449 at 6504a3af. -/
def candidateAvailable (s : ChainState) (i : BlockIndex) : Bool :=
  i.chainTx > 0 &&
    match ancestry s.tree (s.tree.nodes.length + 1) (some i.id) with
    | none => false
    | some path => (path.takeWhile (fun p => !s.active.contains p.id)).all
        (fun p => !p.status.failed && !p.status.failedParent && p.body.isSome) &&
        !i.status.failed && !i.status.failedParent

/-- Eligibility combines availability with effective soft settings. Candidate
pruning does not erase the underlying index or its accumulated work.
[SRC] src/validation.cpp:4426–4449,4498–4523 at 6504a3af. -/
def candidateEligible (s : ChainState) (i : BlockIndex) : Bool :=
  i.softRejected < 0 && i.softFrozen < 0 && candidateAvailable s i

/-- C candidates to which the work theorem applies. The list makes all
availability and setting hypotheses explicit. [SRC] src/validation.cpp:4413–4494
at 6504a3af. -/
def eligibleCandidates (s : ChainState) : List BlockIndex :=
  (s.tree.candidates.filterMap s.tree.get).filter (candidateEligible s)

/-- C work search with P exclusions. An invalid ancestor marks the chain;
missing-body paths become unlinked and lose candidacy. Soft excluded tips are
skipped without acquiring failure bits. [SRC] src/validation.cpp:4413–4494
at 6504a3af. -/
def findMostWorkLoop : Nat → ChainState → ChainState × Option BlockIndex
  | 0, s => (s, none)
  | n + 1, s =>
    let choices := (s.tree.candidates.filterMap s.tree.get).filter
      (fun i => i.softRejected < 0 && i.softFrozen < 0)
    match bestCandidate choices with
    | none => (s, none)
    | some i =>
      if candidateEligible s i then (s, some i) else
        let path : List BlockIndex := (ancestry s.tree (s.tree.nodes.length + 1) (some i.id)).getD [i]
          |>.takeWhile (fun p => !s.active.contains p.id)
        let bad := path.find? (fun p => p.status.failed || p.status.failedParent || p.body.isNone)
        let affected : List BlockIndex := match bad with
          | none => [i]
          | some b => path.takeWhile (fun p => p.id != b.id) ++ [b]
        let tree := match bad with
          | some b => if b.status.failed || b.status.failedParent then markInvalid s.tree b.id false else
              { s.tree with unlinked := s.tree.unlinked ++ (affected.filterMap
                (fun (p : BlockIndex) => if p.id == b.id then none else p.parent.map (·, p.id))) }
          | none => s.tree
        let tree := { tree with candidates := tree.candidates.filter (fun h => !(affected.any (fun p => p.id == h))) }
        findMostWorkLoop n { s with tree }

/-- C most-work search, with enough iterations to discard every candidate.
[SRC] src/validation.cpp:4413–4494 at 6504a3af. -/
def findMostWorkChain (s : ChainState) : ChainState × Option BlockIndex :=
  findMostWorkLoop (s.tree.candidates.length + 1) s

/-- P prune candidates worse than the active tip, retaining the source's soft
exclusion exceptions. [SRC] src/validation.cpp:4498–4523 at 6504a3af. -/
def pruneCandidates (s : ChainState) : ChainState :=
  match s.active.getLast?.bind s.tree.get with
  | none => s
  | some tip => if tip.softFrozen ≥ 0 then s else
    { s with tree := { s.tree with candidates := s.tree.candidates.filter (fun h =>
      match s.tree.get h with
      | none => false
      | some i => i.id == tip.id || !preferred tip i || (tip.softRejected ≥ 0 && i.softRejected < 0)) } }

/-- C clean tip disconnection, with P era clearing and bounded pool insertion.
An unclean/failed local undo does not publish a coins or active-chain change.
[SRC] src/validation.cpp:4065–4133 at 6504a3af. -/
def disconnectTip (s : ChainState) (ctx : ChainContext) (cause : DisconnectCause) :
    ChainState × DisconnectResult := Id.run do
  let some tip := s.active.getLast?.bind s.tree.get | return (s, .failed)
  let s := { s with mempool := finalizeEraCrossing ctx.params tip.height ctx.now s.mempool }
  let some block := tip.body | return (s, .failed)
  let some undo := tip.undo | return (s, .failed)
  let (status, view) := disconnectBlock s.view ctx.params tip.height block undo
  if status != .ok then return (s, status)
  let (q, pool) := addToDisconnectPool ctx.cfg ctx.disconnectAccounting s.disconnectPool s.mempool block
    (ctx.minerIdFiltered block)
  return (({ s with view, mempool := pool, disconnectPool := q, reorgPending := true }).emit (.disconnected cause tip.id), .ok)

/-- C connect one selected index, retain undo and its observed completion,
then remove mined/conflicting transactions and apply era clearing.
[SRC] src/validation.cpp:4345–4404,3204–3224 at 6504a3af. -/
def connectTip (s : ChainState) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (i target : BlockIndex) : Except BlockReject ChainState := do
  let some block := i.body | throw ⟨⟨.node 0, "model: missing block body"⟩, false⟩
  if i.parent != s.active.getLast? then throw ⟨⟨.node 0, "model: parent is not active tip"⟩, false⟩
  let connected ← connectBlock s.view ctx.params ctx.cfg block (headerContext s.tree i.parent)
    ctx.now (ctx.connectionLists s i target lists) oracle (ctx.connectionChecks s i target)
  let tree := s.tree.modify i.id (fun p => { p with undo := some connected.undo, status := { p.status with validity := 5 }, completion := if p.completion == .pending then .completed (ctx.completionEvent p) else p.completion })
  let ids := block.transactions.map BsvScript.Sighash.txid
  let q := { s.disconnectPool with queued := s.disconnectPool.queued.filter (fun tx => !ids.contains (BsvScript.Sighash.txid tx)), filtered := s.disconnectPool.filtered.filter (fun id => !ids.contains id), cachedInnerUsage := s.disconnectPool.cachedInnerUsage -
      ((s.disconnectPool.queued.filter (fun tx => ids.contains (BsvScript.Sighash.txid tx))).map ctx.disconnectAccounting.innerUsage).sum }
  let pool := finalizeEraCrossing ctx.params i.height ctx.now (removeForBlock s.mempool ctx.cfg block ctx.now)
  return pruneCandidates (({ s with tree, view := connected.view, mempool := pool, disconnectPool := q }).emit (.connected i.id))

/-- P complete, failed undo, unresolved input, or exhausted scheduler budget.
Only complete is the maximal-work theorem's successful automatic activation.
[SRC] src/validation.cpp:4913–5130 at 6504a3af. -/
inductive ActivationStatus where
  | complete | disconnectFailed | unresolved (reason : String) | interrupted
  deriving DecidableEq, Repr

/-- C the selected active tip is exactly the best eligible index. This is a
checked postcondition, not an assumption supplied by a caller.
[SRC] src/validation.cpp:4913–5130 at 6504a3af. -/
def activationComplete (s : ChainState) : Bool :=
  (bestCandidate (eligibleCandidates s)).map (·.id) == s.active.getLast?

/-- Selected accumulated work, zero only for an absent active index.
[SRC] src/validation.cpp:4572,4700,4756–4757 at 6504a3af. -/
def activeWork (s : ChainState) : Nat :=
  (s.active.getLast?.bind s.tree.get).map (·.work.toNat) |>.getD 0

/-- [D] Executable completion certificate for candidate pruning: every retained
eligible index has work bounded by the selected tip, including former tips
pruned from the candidate set. A failed certificate declines completion without
changing the executed chain. This checks the representation invariant behind
[SRC] src/validation.cpp:4498–4523,4755–4767,4913–5130 at 6504a3af;
it is not an additional block-validity rule or a caller-supplied premise. -/
def activationWorkComplete (s : ChainState) : Bool :=
  let work := activeWork s
  s.tree.nodes.all (fun i => i.work.toNat ≤ work || !candidateEligible s i)

/-- P perform reorg maintenance only after an actual disconnect, preserving
pool fee history on a no-op activation. [SRC] src/validation.cpp:4616–4662 and
src/txmempool.cpp:2330–2485 at 6504a3af. -/
def settleReorg (s : ChainState) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (failed : Bool := false) : ChainState :=
  if !s.reorgPending then s else
    let pool := if failed then
      removeFromMempoolForReorg s.mempool s.disconnectPool s.view.coins ctx.cfg (admissionContext s ctx)
      else addToMempoolForReorg s.mempool s.disconnectPool s.view.coins ctx.cfg (admissionContext s ctx) lists oracle
    { s with mempool := pool, disconnectPool := {}, reorgPending := false }

/-- Setting propagation uses explicit counts and the parent's remaining count,
so clearing one explicit mark retains other ancestral exclusions.
[SRC] src/block_index.h:542–580,1131–1146 at 6504a3af. -/
def propagateSoftSettings (tree : HeaderTree) : HeaderTree :=
  (List.range (tree.nodes.length + 1)).foldl (fun tree _ =>
    { tree with nodes := tree.nodes.map fun i =>
      let p := i.parent.bind tree.get
      { i with softRejected := max i.explicitSoftRejected (p.map (fun p => max (-1) (p.softRejected - 1)) |>.getD (-1))
               softFrozen := max i.explicitSoftFrozen (p.map (fun p => max (-1) (p.softFrozen - 1)) |>.getD (-1)) } }) tree

/-- Setting mark for a frozen failure; it is not a consensus-invalid flag.
[SRC] src/validation.cpp:3402–3407 and src/block_index.h:542–580 at 6504a3af. -/
def freezeBlockIndex (tree : HeaderTree) (hash : BitVec 256) (duration : Nat) : HeaderTree :=
  propagateSoftSettings (tree.modify hash (fun p => { p with explicitSoftFrozen := duration }))

/-- C fork walk retains both earlier successes and a later failure. The
caller determines reorg cleanup. Explicit fuel is scheduling input.
[SRC] src/validation.cpp:4573–4612, src/txmempool.cpp:2446–2485 at 6504a3af. -/
def disconnectToFork (ctx : ChainContext) (cause : DisconnectCause) (fork : Option (BitVec 256)) :
    Nat → ChainState → ChainState × Bool
  | 0, s => (s, s.active.getLast? == fork)
  | n + 1, s =>
    if s.active.getLast? == fork then (s, true) else
      let (s, status) := disconnectTip s ctx cause
      if status == .ok then disconnectToFork ctx cause fork n s else (s, false)

/-- Setting removals after an explicit rewind precede re-admission. A surviving
descendant can have outgrown an ancestor's exclusion duration, so the newly
exposed ancestor must be checked again.
[SRC] src/validation.cpp:4526–4553,5203–5225,5263–5281 at 6504a3af. -/
def disconnectExcludedTips (ctx : ChainContext) : Nat → ChainState → ChainState × Bool
  | 0, s => (s, false)
  | n + 1, s =>
    match s.active.getLast?.bind s.tree.get with
    | none => (s, true)
    | some tip =>
      if tip.softRejected < 0 && tip.softFrozen < 0 then (s, true) else
        let cause := if tip.softRejected ≥ 0 then DisconnectCause.softRejection else .freezeChange
        let (s, result) := disconnectTip s ctx cause
        if result == .ok then disconnectExcludedTips ctx n s else (s, false)

/-- Internal activation-step outcome. A batch boundary is not a step boundary.
[SRC] src/validation.cpp:4674–4767 at 6504a3af. -/
inductive ConnectionProgress where
  | more | stepDone | failed (status : ActivationStatus)

/-- C/P one connection batch retains the original pre-step work threshold.
Only that threshold, step completion or failure triggers pool maintenance.
[SRC] src/validation.cpp:4692–4767 at 6504a3af. -/
def connectRun (ctx : ChainContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (target : BlockIndex) (oldWork : Nat) : List BlockIndex → ChainState → ChainState × ConnectionProgress
  | [], s => (s, .more)
  | i :: rest, s =>
    let s := if (s.active.getLast?.bind s.tree.get).any (fun tip => tip.work.toNat == oldWork) then
        settleReorg s ctx lists oracle else s
    match connectTip s ctx lists oracle i target with
    | .ok next =>
      if i.work.toNat > oldWork then (next, .stepDone)
      else connectRun ctx lists oracle target oldWork rest next
    | .error r =>
      if r.code == .node 0x13 then
        ({ s with tree := freezeBlockIndex s.tree i.id ctx.cfg.softConsensusFreezeDuration }, .stepDone)
      else if r.code == .node 0 || r.corruptionPossible then (s, .failed (.unresolved r.reason))
      else ({ s with tree := markInvalid s.tree i.id }, .stepDone)

/-- C/P successive batches share the activation step's pool and original work.
Fuel counts the finite forward path; a zero configured batch makes no progress
and is explicitly interrupted. [SRC] src/validation.cpp:4674–4705,4755–4767
at 6504a3af. -/
def connectBatches (ctx : ChainContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (target : BlockIndex) (oldWork : Nat) : Nat → List BlockIndex → ChainState → ChainState × ConnectionProgress
  | 0, _, s => (s, .failed .interrupted)
  | fuel + 1, forward, s =>
    if forward.isEmpty then (s, .stepDone)
    else if ctx.cfg.maxBlockConnectionBatch == 0 then (s, .failed .interrupted)
    else
      let (s, progress) := connectRun ctx lists oracle target oldWork
        (forward.take ctx.cfg.maxBlockConnectionBatch) s
      match progress with
      | .more => connectBatches ctx lists oracle target oldWork fuel
          (forward.drop ctx.cfg.maxBlockConnectionBatch) s
      | other => (s, other)

/-- C/P one activation step retains its fork, pool and original work across
all batches. Automatic failed undo re-admits earlier successful disconnections.
[SRC] src/validation.cpp:4561–4800 at 6504a3af. -/
def activationStep (s : ChainState) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) : ChainState × Option ActivationStatus := Id.run do
  let (s, choice) := findMostWorkChain s
  if activationComplete s then return (s, some .complete)
  let some choice := choice | return (s, some (.unresolved "no eligible chain for active tip"))
  let some backwards := ancestry s.tree (s.tree.nodes.length + 1) (some choice.id)
    | return (s, some (.unresolved "missing activation ancestry"))
  let oldWork := (s.active.getLast?.bind s.tree.get).map (·.work.toNat) |>.getD 0
  let fork := (backwards.find? (fun i => s.active.contains i.id)).map (·.id)
  let (s, clean) := disconnectToFork ctx .reorg fork (s.active.length + 1) s
  if !clean then return (settleReorg s ctx lists oracle, some .disconnectFailed)
  let forward := (backwards.takeWhile (fun i => some i.id != fork)).reverse
  let (s, progress) := connectBatches ctx lists oracle choice oldWork (forward.length + 1) forward s
  let s := settleReorg s ctx lists oracle
  match progress with
  | .failed status => return (s, some status)
  | _ => return (s, none)

/-- Effective setting behind a forced tip rewind, independent of work.
[SRC] src/validation.cpp:4526–4553,5203–5225 at 6504a3af. -/
def activeExclusion (s : ChainState) : Option DisconnectCause :=
  match s.active.getLast?.bind s.tree.get with
  | none => none
  | some tip => if tip.softFrozen ≥ 0 then some .freezeChange
    else if tip.softRejected ≥ 0 then some .softRejection else none

/-- C/P repeated automatic steps and distinct setting-driven rewinds. Failed
setting rewinds use remove-only cleanup; a failed automatic step has already
settled its scope through re-admission. [SRC] src/validation.cpp:4536–4539,
4608–4668,4913–5130 at 6504a3af. -/
def activateLoop (ctx : ChainContext) (lists : FrozenLists) (oracle : ScriptOracle) :
    Nat → ChainState → ChainState × ActivationStatus
  | 0, s => (s, .interrupted)
  | fuel + 1, s =>
    match activeExclusion s with
    | some cause =>
      let (s, result) := disconnectTip s ctx cause
      if result != .ok then (settleReorg s ctx lists oracle true, .disconnectFailed)
      else activateLoop ctx lists oracle fuel (restoreCandidates s)
    | none =>
      let (s, status) := activationStep s ctx lists oracle
      match status with
      | some status => (s, status)
      | none => activateLoop ctx lists oracle fuel s

/-- C automatic activation, P re-admission and maintenance. Completion is
checked again after all setting changes; interruption never claims maximal
work. The fuel parameter models an explicit scheduler budget, not a node cap.
[SRC] src/validation.cpp:4913–5130, src/txmempool.cpp:2330–2485 at 6504a3af. -/
def activateBestChain (s : ChainState) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (fuel : Nat) : ChainState × ActivationStatus :=
  let (s, status) := activateLoop ctx lists oracle fuel s
  let s := settleReorg s ctx lists oracle
  (s, if status == .complete && activationComplete s && activationWorkComplete s then .complete else
    if status == .complete then .interrupted else status)

/-- Setting invalidate: mark failure, disconnect the active descendants,
re-admit, repopulate eligible candidates, then activate. Failed disconnect uses
the remove-only path. [SRC] src/validation.cpp:5230–5330 at 6504a3af. -/
def invalidateBlock (s : ChainState) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (hash : BitVec 256) (fuel : Nat) : ChainState × ActivationStatus :=
  let target := s.tree.get hash
  let tree := (s.active.dropWhile (· != hash)).foldl
    (fun tree h => tree.modify h (fun i => { i with status := { i.status with failedParent := true } }))
    (markInvalid s.tree hash)
  let s := { s with tree }
  let fork := if s.active.contains hash then target.bind (·.parent) else s.active.getLast?
  let (s, clean) := disconnectToFork ctx .invalidate fork (s.active.length + 1) s
  let (s, clean) := if clean then disconnectExcludedTips ctx (s.active.length + 1) s else (s, false)
  if !clean then
    ({ s with mempool := removeFromMempoolForReorg s.mempool s.disconnectPool s.view.coins ctx.cfg (admissionContext s ctx)
              disconnectPool := {}, reorgPending := false }, .disconnectFailed)
  else
    let s := settleReorg { s with reorgPending := true } ctx lists oracle
    activateBestChain (restoreCandidates s) ctx lists oracle fuel

/-- Setting reconsider clears descendant and ancestor failure flags, then
repopulates linked candidates and activates. It does not clear soft settings
or the double-spend flag. [SRC] src/rpc/blockchain.cpp:2770–2818 and
src/validation.cpp:5528–5562 at 6504a3af. -/
def reconsiderBlock (s : ChainState) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (hash : BitVec 256) (fuel : Nat) : ChainState × ActivationStatus :=
  let ancestors : List (BitVec 256) := (ancestry s.tree (s.tree.nodes.length + 1) (some hash)).getD [] |>.map (·.id)
  let descendants := s.tree.nodes.filter fun i =>
    (i.status.failed || i.status.failedParent) &&
      (ancestry s.tree (s.tree.nodes.length + 1) (some i.id)).any (fun xs => xs.any (fun p => p.id == hash))
  let tip := s.active.getLast?.bind s.tree.get
  let tree := descendants.foldl (fun tree i =>
    let i := { i with status := { i.status with failed := false, failedParent := false } }
    let tree := tree.modify i.id (fun _ => i)
    if i.status.validity ≥ 3 && i.chainTx > 0 && tip.any (fun tip => preferred i tip) then
      { tree with candidates := if tree.candidates.contains i.id then tree.candidates else i.id :: tree.candidates }
    else tree) s.tree
  let tree := { tree with nodes := tree.nodes.map (fun (i : BlockIndex) =>
    if ancestors.contains i.id then { i with status := { i.status with failed := false, failedParent := false } } else i) }
  activateBestChain { s with tree } ctx lists oracle fuel

/-- P precious ordering requires transaction validity and linkage for candidate
insertion; the operator then prunes and activates. Lower-work requests leave
the state unchanged. [SRC] src/validation.cpp:5156–5190 at 6504a3af. -/
def preciousBlock (s : ChainState) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (hash : BitVec 256) (fuel : Nat) : ChainState × ActivationStatus :=
  let work := (s.active.getLast?.bind s.tree.get).map (·.work.toNat) |>.getD 0
  match s.tree.get hash with
  | none => (s, .unresolved "model: absent precious block")
  | some i => if i.work.toNat < work then (s, .complete) else
    let sequence := if work > s.tree.lastPreciousWork then -1 else s.tree.reverseSequence
    let tree := s.tree.modify hash (fun p => { p with sequence, completion := .ignored })
    let tree := { tree with
      reverseSequence := max (-(2^31)) (sequence - 1)
      lastPreciousWork := work, candidates := tree.candidates.filter (· != hash) }
    let eligible := i.status.validity ≥ 3 && !i.status.failed && !i.status.failedParent && i.chainTx > 0
    let s := if eligible then pruneCandidates { s with tree := { tree with candidates := hash :: tree.candidates } }
      else { s with tree }
    activateBestChain s ctx lists oracle fuel

/-- Setting transition for effective soft-rejection counts. RPC argument
validation and safe-mode client reactions remain #68/#73; the chain effect
and its distinct removal cause are executed here.
[SRC] src/rpc/blockchain.cpp:2820–2892 and src/validation.cpp:5203–5225
at 6504a3af. -/
def setSoftRejection (s : ChainState) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (hash : BitVec 256) (duration : Int) (fuel : Nat) : ChainState × ActivationStatus :=
  let tree := propagateSoftSettings (s.tree.modify hash (fun i => { i with explicitSoftRejected := max (-1) duration }))
  activateBestChain (restoreCandidates { s with tree }) ctx lists oracle fuel

/-- Setting transition for effective freeze counts, separate from consensus
failure. The connection reads it through `connectionFrozenLists` (#70).
[SRC] src/block_index.h:542–580,1131–1146 and src/validation.cpp:4526–4553
at 6504a3af. -/
def setSoftFreeze (s : ChainState) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (hash : BitVec 256) (duration : Int) (fuel : Nat) : ChainState × ActivationStatus :=
  let tree := propagateSoftSettings (s.tree.modify hash (fun i => { i with explicitSoftFrozen := max (-1) duration }))
  activateBestChain (restoreCandidates { s with tree }) ctx lists oracle fuel

end BsvChain
