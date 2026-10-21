import BsvChain.Utxo
import BsvScript.TxPolicy

/-!
# Mempool admission and maintenance (#62)

Executable policy at bitcoin-sv v1.2.3,
6504a3aff65ba97c0f6c80962b033e35ecbfed4b. Bare line numbers are
`src/validation.cpp`. The fourteen named stages retain source order.
The accepted/non-final/orphan associations have unique transaction ids after
normal insertion; their list order records explicit iteration choices.
`mapNextTx` is the accepted pool's spent-outpoint index. The combined coins
view deliberately does not spend parent outputs: conflict checks own that job.
[SRC] src/txmempool.h:1380–1389 at 6504a3af.

All admission and maintenance limits read the existing NodeConfig census.
Allocator sizes and scheduling order are explicit observations, not limits.
Unmeasured ABI data, equal-score eviction order, filter false positives and
budget outcomes are non-judging for #66/#71. No clock or network is read.
`accept` returns TxOutcome because silence, priority downgrade and resubmission
are not completed TxVerdicts (DESIGN-S6 §2). The four completed verdicts stay
separate from those scheduling observations. The inventory envelope, the
filter's reset rule and the elapsed-time budget are `BsvChain.Rejects` (#71).
-/

namespace BsvChain
open BsvScript.Tx BsvScript.Numbers BsvScript.Params

/-- Transaction identity uses the interpreter's internal-order hash bytes.
[SRC] src/txmempool.h:483 at 6504a3af. -/
abbrev TxId := Bytes

/-- Completed admission vocabulary, including the policy hold and missing-input
route. Low-priority timeout is a rejection. [SRC] src/txn_validator.cpp:633–641,
src/validation.cpp:1118,1185,1349–1355,1482,1819–1835
at 6504a3af. -/
inductive TxVerdict where
  | accepted | heldNonFinal | orphan
  | rejected (code : RejectCode) (reason : String)
  deriving DecidableEq, Repr

/-- Scheduling envelope around a completed verdict. `unverifiable` is a named
model decline (incomplete oracle/ABI evidence), never a node rejection.
[SRC] src/txn_validator.cpp:633–641, src/net/net.cpp:3558–3564 and
src/time_locked_mempool.cpp:73–80 at 6504a3af. -/
inductive TxOutcome where
  | completed (verdict : TxVerdict)
  | deferred | suppressed | unverifiable (reason : String)
  deriving DecidableEq, Repr

/-- Policy request channel, including revalidation of newly final transactions.
[SRC] src/txn_validation_data.h:54–64 and src/time_locked_mempool.cpp:647–653
at 6504a3af. -/
inductive TxSource where
  | rpc | p2p | reorg | finalised | file
  deriving DecidableEq, Repr

/-- Policy validation priority; a timeout downgrades high priority, while a
low-priority timeout completes with the supplied validation rejection.
[SRC] src/txn_validator.cpp:633–641 at 6504a3af. -/
inductive TxPriority where
  | high | low
  deriving DecidableEq, Repr

/-- Retained request overrides. `none` on absurdFee resolves to the census's
RPC ceiling, or zero on P2P/reorg. Handler presence distinguishes persistent
P2P orphans, temporary batch handlers and synchronous RPC without a handler.
[SRC] src/txn_validation_data.h:54–64,169–177,
src/txn_validator.cpp:163–167,244–248 and src/validation.cpp:1023–1024,1330,1795–1796
at 6504a3af. -/
structure TxRequest where
  tx : Tx
  source : TxSource := .rpc
  priority : TxPriority := .high
  acceptTime : Int
  absurdFee : Option Nat := none
  skipScriptFlags : Flags := Flags.none
  useLimits : Bool := false
  limitMempoolSize : Bool := true
  orphanHandler : Bool := false
  configOverride : Option NodeConfig := none
  deriving Repr

/-- Pool entry fields read by admission, grouping and maintenance. `innerUsage`
is the node's measured RecursiveDynamicUsage; it is not
serialized size. Group identity is its paying transaction's id.
[SRC] src/txmempool.h:136–178, src/txmempool.cpp:748–791,2097–2127 and
src/validation.cpp:1301–1309 at 6504a3af. -/
structure MempoolEntry where
  tx : Tx
  fee : Int
  time : Int
  height : Nat
  size : Nat
  spendsCoinbaseOrConfiscation : Bool := false
  ancestorCount : Nat := 0
  secondaryAncestorCount : Nat := 0
  groupingFee : Int := 0
  groupingSize : Nat := 0
  primary : Bool := false
  cpfpGroup : Option TxId := none
  innerUsage : Nat
  deriving DecidableEq, Repr

/-- Entry's actual transaction id, never a separately trusted key.
[SRC] src/txmempool.h:185 at 6504a3af. -/
def MempoolEntry.id (entry : MempoolEntry) : TxId := BsvScript.Sighash.txid entry.tx

/-- Non-final replacement leaky bucket, retaining binary64 fill and explicit
system-clock observation in integer nanoseconds, independent of GetTime.
The source adds before draining. Nanosecond timestamps preserve fractional
seconds; finer clock samples floored to this unit introduce less than one
nanosecond of elapsed-time error, hence less than rate / periodSeconds / 10^9
fill error before binary64 rounding. Same-unit source clocks need no truncation.
[SRC] src/leaky_bucket.h:44–87 and src/time_locked_mempool.cpp:429–444
at 6504a3af. -/
structure NonFinalRate where
  fillBits : UInt64 := 0
  lastDrain : Int := 0
  deriving DecidableEq, Repr

/-- Held entry and its rate, reusing #60's hold/finality predicates.
[SRC] src/time_locked_mempool.h:100–117 at 6504a3af. -/
structure NonFinalEntry where
  entry : MempoolEntry
  rate : NonFinalRate
  deriving DecidableEq, Repr

/-- Orphan request and its expiry; all overrides survive retries.
[SRC] src/orphan_txns.cpp:66–71,288–301 at 6504a3af. -/
structure OrphanEntry where
  request : TxRequest
  expiresAt : Int
  size : Nat
  deriving Repr

/-- Retained validation work, separate from every completed verdict.
[SRC] src/txn_validator.cpp:567–578,633–640 at 6504a3af. -/
structure PendingWork where
  request : TxRequest
  enqueued : Int
  deriving Repr

/-- Binary64 rolling fee, including both gates that enable decay. The empty
pool initializes the rate to zero; eviction alone does not enable decay.
[SRC] src/txmempool.cpp:1354–1355,1365–1383,2624–2647 at 6504a3af. -/
structure RollingFee where
  rateBits : UInt64 := 0
  lastUpdate : Int := 0
  blockSinceBump : Bool := false
  deriving DecidableEq, Repr

/-- Policy side-pool sweep and insertion accounting. The hysteresis can skip
expiry even after nextSweep; time alone is not a maintenance event.
[SRC] src/orphan_txns.h:146–150 and src/orphan_txns.cpp:175–225 at 6504a3af. -/
structure OrphanControl where
  nextSweep : Int := 0
  untrimmedBytes : Nat := 0
  deriving DecidableEq, Repr

/-- P: parameterized ideal-set observation of a rolling reject filter. The
capacity and false-positive ratio are constructor policy from the census.
Membership here is exact in the supplied set and never invents a rejection
reason. `insertions` counts every insert since the last reset, repeats
included, as the pin's generation counter does; `BsvChain.Rejects` (#71)
states the reset, the wipe-free regime and the observation contract.
[SRC] src/txn_recent_rejects.cpp:9–21, src/bloom.cpp:265–281 and
src/time_locked_mempool.h:213–214 at 6504a3af. -/
structure RejectFilter where
  capacity : Nat
  falsePositiveRate : Nat × Nat
  members : List TxId := []
  insertions : Nat := 0
  deriving DecidableEq, Repr

/-- P: membership is the only filter observation admission consumes.
[SRC] src/net/net.cpp:3558–3564 at 6504a3af. -/
def RejectFilter.contains (f : RejectFilter) (id : TxId) : Bool := f.members.contains id

/-- P: retain ideal membership and count the insert. The bounded
probabilistic storage is the wipe-free regime of `BsvChain.Rejects` (#71).
[SRC] src/txn_recent_rejects.cpp:14–21 and src/bloom.cpp:265–281 at 6504a3af. -/
def RejectFilter.remember (f : RejectFilter) (id : TxId) : RejectFilter :=
  { f with members := id :: f.members.filter (· != id), insertions := f.insertions + 1 }

/-- P: reject filter initialized with the named census policy.
[SRC] src/txn_recent_rejects.cpp:9–11 at 6504a3af. -/
def rejectFilter (cfg : NodeConfig) (members : List TxId := []) : RejectFilter :=
  { capacity := cfg.recentRejectCapacity, falsePositiveRate := cfg.recentRejectFalsePositiveRate,
    members, insertions := members.length }

/-- P: held-pool removals use a separate filter with separate census policy.
[SRC] src/time_locked_mempool.h:213–214 at 6504a3af. -/
def removedNonFinalFilter (cfg : NodeConfig) (members : List TxId := []) : RejectFilter :=
  { capacity := cfg.nonFinalRecentlyRemovedCapacity,
    falsePositiveRate := cfg.nonFinalRecentlyRemovedFalsePositiveRate,
    members, insertions := members.length }

/-- The pool state. Lists implement finite associations with explicit ordering;
normal insertions check uniqueness. Reject membership is an ideal set
abstraction parameterized by the census. `recentRejectsTip` is the tip hash
recorded by the last inventory check, `none` before any check: the pin's
`hashRecentRejectsChainTip`, which the lazy reset of `BsvChain.Rejects` (#71)
compares with the observed tip. Collected parent outputs do not themselves
admit any orphan.
[SRC] src/txmempool.h:448–457,483,562, src/orphan_txns.cpp:262–357,
src/txn_recent_rejects.cpp:9–21 and src/net/net_processing.cpp:82,930–942
at 6504a3af. -/
structure Mempool where
  accepted : List MempoolEntry := []
  mapNextTx : List (OutPoint × TxId) := []
  nonFinal : List NonFinalEntry := []
  orphans : List OrphanEntry := []
  recentRejects : RejectFilter := rejectFilter NodeConfig.defaults
  recentRejectsTip : Option Bytes := none
  nonFinalRecentlyRemoved : RejectFilter := removedNonFinalFilter NodeConfig.defaults
  rollingFee : RollingFee := {}
  orphanControl : OrphanControl := {}
  feeDeltas : List (TxId × Int) := []
  pending : List PendingWork := []
  collected : List (TxId × Nat) := []
  deriving Repr

/-- ABI/accounting observations, not policy defaults. Supply allocator-rounded
node sizes for the two multi-index records, map nodes, link nodes and non-final
index; inner transaction allocations are supplied per entry. A zero profile
is a derived corpus abstraction, never a claim about a built node's memory.
[SRC] src/txmempool.cpp:2097–2127, src/time_locked_mempool.cpp:592–607 and
src/memusage.h:56–70 at 6504a3af. -/
structure PoolAccounting where
  entryIndexBytes : Nat
  spendIndexBytes : Nat
  deltaBytes : Nat
  linksBytes : Nat
  nonFinalIndexBytes : Nat
  nonFinalSpendBytes : Nat
  nonFinalEmptyBytes : Nat
  linkNodeBytes : Nat := 0
  mallocUsage : Nat → Nat := id

/-- Explicit byte-only corpus profile, labeled non-judging for ABI comparisons.
[SRC] src/txmempool.cpp:2097–2110 at 6504a3af. -/
def PoolAccounting.byteOnly : PoolAccounting := ⟨0, 0, 0, 0, 0, 0, 0, 0, id⟩

/-- Measured dynamic-index accounting, retaining deltas even for absent ids.
[SRC] src/txmempool.cpp:2097–2106 at 6504a3af. -/
def indexUsage (a : PoolAccounting) (p : Mempool) : Nat :=
  p.accepted.length * (a.entryIndexBytes + a.linksBytes) +
  p.mapNextTx.length * a.spendIndexBytes + p.feeDeltas.length * a.deltaBytes

/-- Policy size measurement consumed by TrimToSize, not a consensus limit.
[SRC] src/txmempool.cpp:2109–2110 at 6504a3af. -/
def poolUsage (a : PoolAccounting) (p : Mempool) : Nat :=
  indexUsage a p + (p.accepted.map (·.innerUsage)).sum +
    (p.accepted.map (fun e => (p.accepted.filter (fun parent =>
      e.tx.inputs.any (fun i => i.prevHash == parent.id))).length * (2 * a.linkNodeBytes))).sum

/-- Secondary pool's proportional index usage with the pin's binary64 multiply
and truncation, plus secondary inner allocations.
[SRC] src/txmempool.cpp:2118–2127 at 6504a3af. -/
def secondaryUsage (a : PoolAccounting) (p : Mempool) : Nat :=
  let entries := p.accepted.filter (fun e => !e.primary)
  ((indexUsage a p).toFloat * (entries.length.toFloat / (p.accepted.length + 1).toFloat)).toUInt64.toNat +
    (entries.map (·.innerUsage)).sum

/-- Policy non-final memory includes the empty container's allocation.
[SRC] src/time_locked_mempool.cpp:592–607 at 6504a3af. -/
def nonFinalUsage (a : PoolAccounting) (p : Mempool) : Nat :=
  a.mallocUsage (a.nonFinalEmptyBytes + p.nonFinal.length * a.nonFinalIndexBytes +
    (p.nonFinal.map (fun e => e.entry.size)).sum) +
    (p.nonFinal.map (fun e => e.entry.tx.inputs.length * a.nonFinalSpendBytes)).sum

/-- Rebuild mapNextTx after a pool mutation. Live accepted transactions have
non-null distinct inputs; admission refuses a previously indexed outpoint.
[SRC] src/txmempool.cpp:758–778,2694–2701 at 6504a3af. -/
def reindex (p : Mempool) : Mempool :=
  { p with mapNextTx := p.accepted.flatMap fun e => e.tx.inputs.map fun i => (OutPoint.ofInput i, e.id) }

/-- Accepted parent coins take precedence over chain coins and retain all
outputs, even those spent by another pool transaction. No pruning here.
[SRC] src/txmempool.cpp:2070–2084 and src/txmempool.h:1380–1389 at 6504a3af. -/
def mempoolView (p : Mempool) (utxo : UtxoSet) : UtxoSet :=
  p.accepted.foldl (fun s e => e.tx.outputs.zipIdx.foldl (fun s (o, n) =>
    s.insert ⟨e.id, n⟩ ⟨o.value, o.scriptPubKey, mempoolHeight, false, isConfiscationTx e.tx⟩) s) utxo

/-- Direct accepted parents, once per id, in stored iteration order.
[SRC] src/txmempool.cpp:208–224 at 6504a3af. -/
def poolParents (p : Mempool) (tx : Tx) : List MempoolEntry :=
  p.accepted.filter fun e => tx.inputs.any (fun i => i.prevHash == e.id)

/-- Non-final locks touched by a request, with each held entry once.
[SRC] src/time_locked_mempool.cpp:413–426 at 6504a3af. -/
def nonFinalConflicts (p : Mempool) (tx : Tx) : List NonFinalEntry :=
  p.nonFinal.filter fun e => tx.inputs.any fun i =>
    e.entry.tx.inputs.any (fun j => OutPoint.ofInput i == OutPoint.ofInput j)

/-- Special finalisation candidate: every requested input is locked by the
same held transaction and every sequence is final. This preliminary test
allows a subset of the old inputs; commit subsequently checks equal lengths.
[SRC] src/time_locked_mempool.cpp:114–156 at 6504a3af. -/
def finalisesExisting (p : Mempool) (tx : Tx) : Bool :=
  (nonFinalConflicts p tx).length == 1 && tx.inputs.all (fun i =>
    i.sequence == BsvScript.TxContext.SEQUENCE_FINAL && p.nonFinal.any (fun e =>
      e.entry.tx.inputs.any (fun j => OutPoint.ofInput i == OutPoint.ofInput j)))

/-- P: accepted locks always conflict. Held locks conflict only for a final
candidate that does not pass finalisesExisting; non-final updates have their
own commit checks. [SRC] src/txmempool.cpp:2257–2280 at 6504a3af. -/
def hasPoolConflict (p : Mempool) (tx : Tx) (final : Bool) : Bool :=
  tx.inputs.any (fun i => p.mapNextTx.any (fun kv => kv.1 == OutPoint.ofInput i)) ||
    (final && !(nonFinalConflicts p tx).isEmpty && !finalisesExisting p tx)

/-- P: byte fee calculation truncates toward zero, with a one-satoshi minimum
magnitude for nonzero rate and size. The decimal 1000 is the rate's unit.
[SRC] src/amount.cpp:18–42 at 6504a3af. -/
def feeForSize (rate : Int) (size : Nat) : Int :=
  let f := (rate * (size : Int)).tdiv 1000
  if f == 0 && size != 0 then if rate > 0 then 1 else if rate < 0 then -1 else 0 else f

/-- P: integer fee rate in satoshis per decimal kB, truncated toward zero.
[SRC] src/amount.cpp:18–26 at 6504a3af. -/
def feeRate (fee : Int) (size : Nat) : Int := (1000 * fee).tdiv size

/-- Signed integer to binary64 using Lean's defined float model.
[SRC] src/txmempool.cpp:2630,2640 at 6504a3af. -/
def feeFloat (n : Int) : Float := if n < 0 then -n.natAbs.toFloat else n.toNat.toFloat

/-- P: retained binary64 decay in the source's operation order; pow is the
runtime's binary64 libm operation. Cross-runtime rounding at a fee boundary
needs #66's measured bits; no exact-real decay theorem is claimed.
[SRC] src/txmempool.cpp:2624–2647 at 6504a3af. -/
def decayRollingFee (cfg : NodeConfig) (a : PoolAccounting) (now : Int) (p : Mempool) : Mempool :=
  let r := p.rollingFee
  let rate := Float.ofBits r.rateBits
  if r.blockSinceBump && rate != 0 && now > r.lastUpdate + (cfg.rollingFeeUpdateIntervalSeconds : Int) then
    let usage := poolUsage a p
    let half := cfg.rollingFeeHalfLifeSeconds.toFloat /
      (if usage < cfg.maxMempool / cfg.rollingFeeLowUsageDivisor then cfg.rollingFeeLowUsageDivisor.toFloat
       else if usage < cfg.maxMempool / cfg.rollingFeeMediumUsageDivisor then cfg.rollingFeeMediumUsageDivisor.toFloat
       else 1)
    let next := rate / Float.pow 2 (feeFloat (now - r.lastUpdate) / half)
    { p with rollingFee := { r with rateBits := next.toBits, lastUpdate := now } }
  else p

/-- P: the receive fee floor is max(truncated rolling rate, debug rate).
The static minRelayTxFee is not read on this path.
[SRC] src/txmempool.cpp:2644–2647 and src/validation.cpp:763–780 at 6504a3af. -/
def rollingMinimum (cfg : NodeConfig) (p : Mempool) : Int :=
  max ((Float.ofBits p.rollingFee.rateBits).toUInt64.toNat : Int) cfg.minDebugRejectionFee

/-- P: fee delta lookup survives removal, as the source's mapDeltas does.
[SRC] src/txmempool.cpp:736–740 and src/validation.cpp:1256–1258 at 6504a3af. -/
def feeDelta (p : Mempool) (id : TxId) : Int :=
  ((p.feeDeltas.find? (fun x => x.1 == id)).map Prod.snd).getD 0

/-- P: deterministic dependency closure, bounded by the finite vertex count,
not by a policy limit. Includes the roots and all accepted descendants.
[SRC] src/txmempool.cpp:2206–2218,2748–2763 at 6504a3af. -/
def descendantIds (p : Mempool) (roots : List TxId) : List TxId :=
  (List.range p.accepted.length).foldl (fun ids _ =>
    (p.accepted.filter (fun e => ids.contains e.id ||
      e.tx.inputs.any (fun i => ids.contains i.prevHash))).map (·.id)) roots

/-- P: eligible expiry roots use a strict age cutoff. Descendants may be
newer; an unconditional age-only removal claim would be false.
[SRC] src/txmempool.cpp:2201–2218 at 6504a3af. -/
def expiryRoots (p : Mempool) (cfg : NodeConfig) (now : Int) : List TxId :=
  (p.accepted.filter (fun e => e.time < now - (cfg.mempoolExpiry : Int))).map (·.id)

/-- P: remove selected entries and rebuild the spent index. Group repair is
performed by the maintenance caller after removal.
[SRC] src/txmempool.cpp:2130–2198 at 6504a3af. -/
def removePoolIds (p : Mempool) (ids : List TxId) : Mempool :=
  reindex { p with accepted := p.accepted.filter (fun e => !ids.contains e.id) }

/-- P: secondary ancestor closure, including the paying transaction, using
finite traversal rather than a policy truncation.
[SRC] src/txmempool.cpp:346–368 at 6504a3af. -/
def secondaryPackage (p : Mempool) (e : MempoolEntry) : List MempoolEntry :=
  let ids := (List.range p.accepted.length).foldl (fun ids _ =>
    (p.accepted.filter (fun parent => ids.contains parent.id || (!parent.primary &&
      p.accepted.any (fun child => ids.contains child.id &&
        child.tx.inputs.any (fun i => i.prevHash == parent.id))))).map (·.id)) [e.id]
  p.accepted.filter (fun m => ids.contains m.id)

/-- P: grouping data sums retained direct-parent data. The approximation can
count a shared ancestor repeatedly; group admission subsequently uses the
unique ancestor set but does not re-test its precise aggregate fee.
[SRC] src/txmempool.cpp:370–390,416–435,452–565 at 6504a3af. -/
def secondaryData (p : Mempool) (e : MempoolEntry) : Int × Nat × Nat :=
  (poolParents p e.tx).filter (fun x => !x.primary) |>.foldl (fun data parent =>
    (data.1 + parent.groupingFee, data.2.1 + parent.groupingSize,
     data.2.2 + parent.secondaryAncestorCount + 1))
    (e.fee + feeDelta p e.id, e.size, 0)

/-- P: one grouping update, with changed ids for child propagation and the
source's visited count (the size of a promoted group, otherwise one).
[SRC] src/txmempool.cpp:452–565 at 6504a3af. -/
def promoteEntry (cfg : NodeConfig) (p : Mempool) (e : MempoolEntry) : Mempool × List TxId × Nat :=
  if e.primary then (p, [], 1) else
  let data := secondaryData p e
  if data.1 < feeForSize cfg.blockMinTxFee data.2.1 then
    let changed := data != (e.groupingFee, e.groupingSize, e.secondaryAncestorCount)
    ({ p with accepted := p.accepted.map (fun x => if x.id == e.id then
      { x with groupingFee := data.1, groupingSize := data.2.1, secondaryAncestorCount := data.2.2 } else x) },
      if changed then [e.id] else [], 1)
  else
    let members := if data.2.2 == 0 then [e] else secondaryPackage p e
    let ids := members.map (·.id)
    ({ p with accepted := p.accepted.map (fun x => if ids.contains x.id then
      { x with primary := true, secondaryAncestorCount := 0, cpfpGroup := if data.2.2 == 0 then none else some e.id }
      else x) }, ids, members.length)

/-- P: source-ordered primary promotion. Pointer ties are supplied by retained
order. The finite traversal fuel is a graph bound, not a policy setting; live
pools are DAGs and a promotion can revisit children after removing group debt.
The source visit cap applies only to childless admission, with a strict test.
[SRC] src/txmempool.cpp:481–604 and src/txmempool.h:423 at 6504a3af. -/
def promoteLoop (cfg : NodeConfig) (limited : Bool) :
    Nat → Mempool → List TxId → Nat → Mempool
  | 0, p, _, _ => p
  | fuel + 1, p, queued, visited =>
    if limited && visited > cfg.maxPrimaryPromotionVisits then p else
    let entries := (p.accepted.filter (fun e => queued.contains e.id && !e.primary)).mergeSort
      (fun a b => a.ancestorCount ≤ b.ancestorCount)
    match entries with
    | [] => p
    | e :: _ =>
      let (next, changed, count) := promoteEntry cfg p e
      let children := next.accepted.filter (fun child => !child.primary &&
        child.tx.inputs.any (fun i => changed.contains i.prevHash)) |>.map (·.id)
      promoteLoop cfg limited fuel next ((queued.filter (· != e.id)) ++ children) (visited + count)

/-- P: AddUnchecked inherits deltas and uses the childless promotion path.
Normal received entries have no accepted children. Group propagation alone
uses the fixed visit cap; it may leave retained grouping data for a later event.
[SRC] src/txmempool.cpp:568–604,736–805 at 6504a3af. -/
def addUnchecked (p : Mempool) (cfg : NodeConfig) (entry : MempoolEntry) : Mempool :=
  let entry := { entry with primary := false, groupingFee := 0, groupingSize := 0, secondaryAncestorCount := 0 }
  let p := reindex { p with accepted := p.accepted ++ [entry] }
  promoteLoop cfg true ((p.accepted.length + 1) ^ 2) p [entry.id] 0

/-- P: disband groups touched by removal and propagate primary demotion
through descendants and their groups, before removing staged transactions.
[SRC] src/txmempool.cpp:605–672,2130–2198 at 6504a3af. -/
def demotionIds (p : Mempool) (ids : List TxId) : List TxId :=
  let roots := p.accepted.filter (fun e => ids.contains e.id && e.cpfpGroup.isSome) |>.map (·.id)
  (List.range p.accepted.length).foldl (fun ids _ => p.accepted.filter (fun e =>
    ids.contains e.id || (e.primary && (e.tx.inputs.any (fun i => ids.contains i.prevHash) ||
      e.cpfpGroup.any (fun g => p.accepted.any (fun m => ids.contains m.id && m.cpfpGroup == some g)))))
      |>.map (·.id)) roots

/-- P: removeStaged repairs the surviving group metadata with an unlimited
promotion pass. Neither disbanding nor promotion removes a transaction.
[SRC] src/txmempool.cpp:2130–2198 at 6504a3af. -/
def removeStaged (p : Mempool) (cfg : NodeConfig) (ids : List TxId) : Mempool :=
  let demote := demotionIds p ids
  let p := { p with accepted := p.accepted.map (fun e => if demote.contains e.id then
    { e with primary := false, cpfpGroup := none, groupingFee := 0, groupingSize := 0, secondaryAncestorCount := 0 }
    else e) }
  let p := removePoolIds p ids
  promoteLoop cfg false ((p.accepted.length + 1) ^ 2) p demote 0

/-- P: Expire's exact removal set: old roots and their descendants.
[SRC] src/txmempool.cpp:2201–2220 at 6504a3af. -/
def expire (p : Mempool) (cfg : NodeConfig) (now : Int) : Mempool :=
  removeStaged p cfg (descendantIds p (expiryRoots p cfg now))

/-- P: CPFP group fee/size or an individual entry's modified fee rate.
[SRC] src/txmempool.cpp:2724–2732 at 6504a3af. -/
def entryFeeRate (p : Mempool) (e : MempoolEntry) : Int :=
  let members := match e.cpfpGroup with
    | none => [e]
    | some id => p.accepted.filter (fun x => x.cpfpGroup == some id)
  feeRate (members.map (fun x => x.fee + feeDelta p x.id)).sum (members.map (·.size)).sum

/-- P: secondary entries sort below primary entries by the signed 64-bit
score offset; group scores have no such offset.
[SRC] src/txmempool.cpp:2650–2666 at 6504a3af. -/
def evictionScore (p : Mempool) (e : MempoolEntry) : Int :=
  entryFeeRate p e - (if !e.primary && e.cpfpGroup.isNone then 2 ^ 63 else 0)

/-- P: only leaves, or paying leaves of groups with no external children,
are candidates. The explicit list order resolves equal scores for a scenario.
[SRC] src/txmempoolevictioncandidates.cpp:57–118,170–174 at 6504a3af. -/
def evictionCandidates (p : Mempool) : List MempoolEntry :=
  p.accepted.filter fun e =>
    !p.accepted.any (fun child => child.tx.inputs.any (fun i => i.prevHash == e.id)) &&
    match e.cpfpGroup with
    | none => true
    | some g => !p.accepted.any (fun child => child.cpfpGroup != some g &&
        child.tx.inputs.any (fun i => p.accepted.any (fun m => m.cpfpGroup == some g && m.id == i.prevHash)))

/-- P: least eligible score; fallback on a cyclic malformed model state makes
maintenance total. Well-formed pool dependencies are acyclic.
[SRC] src/txmempoolevictioncandidates.cpp:7–9,170–174 at 6504a3af. -/
def evictionCandidate (p : Mempool) : Option MempoolEntry :=
  let candidates := evictionCandidates p
  let candidates := if candidates.isEmpty then p.accepted else candidates
  (candidates.mergeSort (fun a b => evictionScore p a ≤ evictionScore p b)).head?

/-- P: bump only when the proposed rate exceeds the retained rate; if secondary
entries remain the new rate is capped by the mining fee. Emptying the pool
passes zero and therefore does not necessarily clear an existing minimum.
[SRC] src/txmempool.cpp:1365–1383,2777–2792 at 6504a3af. -/
def bumpRollingFee (cfg : NodeConfig) (p : Mempool) (removedRate : Int) : Mempool :=
  let candidate := evictionCandidate p
  let rate := match candidate with
    | none => 0
    | some e => max removedRate (entryFeeRate p e) + cfg.mempoolFullFeeIncrement
  if feeFloat rate > Float.ofBits p.rollingFee.rateBits then
    let rate := match candidate with
      | some e => if !e.primary then min rate cfg.blockMinTxFee else rate
      | none => rate
    { p with rollingFee := { p.rollingFee with rateBits := (feeFloat rate).toBits, blockSinceBump := false } }
  else p

/-- P: TrimToSize iterates until at most the requested usage or no entries.
Fuel is the number of live entries, a termination bound, never a limit.
[SRC] src/txmempool.cpp:2734–2792 at 6504a3af. -/
def trimLoop (cfg : NodeConfig) (a : PoolAccounting) (limit : Nat) :
    Nat → Mempool → Int → Bool → Mempool
  | 0, p, rate, evicted => if evicted then bumpRollingFee cfg p rate else p
  | n + 1, p, rate, evicted =>
    if poolUsage a p ≤ limit then if evicted then bumpRollingFee cfg p rate else p
    else match evictionCandidate p with
    | none => if evicted then bumpRollingFee cfg p rate else p
    | some e => trimLoop cfg a limit n
        (removeStaged p cfg (descendantIds p [e.id])) (max rate (entryFeeRate p e)) true

/-- P: executable eviction with explicit memory accounting. With residual
mapDeltas allocations an empty pool can exceed an arbitrary tiny cap, exactly
as the source loop permits. The size theorem states this alternative.
[SRC] src/txmempool.cpp:2097–2110,2736–2792 at 6504a3af. -/
def trimToSize (p : Mempool) (cfg : NodeConfig) (a : PoolAccounting) (limit : Nat) : Mempool :=
  trimLoop cfg a limit p.accepted.length p 0 false

/-- Unsigned size_t subtraction for the declared 64-bit node profile. The
modulus is a type width, not a policy limit. Preserve underflow at the pin.
[SRC] src/validation.cpp:866–873 at 6504a3af. -/
def sizeTSub64 (a b : Nat) : Nat := ((a : Int) - b) % (2 ^ 64) |>.toNat

/-- P: LimitMempoolSize expires, computes the unsigned target, then
would save excess RAM to disk (#81's persistence). Total dynamic accounting
is independent of that physical placement. Underflow can leave usage above
the configured cap; the record documents this pinned corner as a Finding.
[SRC] src/validation.cpp:834–892 at 6504a3af. -/
def limitPool (p : Mempool) (cfg : NodeConfig) (a : PoolAccounting) (now : Int) : Mempool :=
  let p := expire p cfg now
  let total := cfg.maxMempool + cfg.maxMempoolSizeDisk
  let secondary := ((cfg.mempoolMaxPercentCPFP.toFloat / 100) * cfg.maxMempool.toFloat).toUInt64.toNat
  let usage := poolUsage a p
  let extra := secondaryUsage a p - secondary
  if usage > total || extra > 0 then trimToSize p cfg a (sizeTSub64 (min usage total) extra) else p

/-- P: explicit budget observations. These are non-judging scheduling inputs,
not deterministic predictions from now. `BsvChain.Rejects` (#71) derives one
from an explicit elapsed-time observation and the census budgets.
[SRC] src/validation.cpp:1210–1233,1349–1355,1424–1430,1458–1464 at 6504a3af. -/
inductive ValidationBudget where
  | available | inputsExpired | relayExpired | blockExpired | mandatoryExpired
  deriving DecidableEq, Repr

/-- Explicit environment for the atomic admission step. The full median and
ancestor times are supplied separately so #60 can preserve the caller's
narrowing and BIP68's ancestor lookup. innerUsage is a measured allocation,
not an override of validation. Cache hits may skip only proven identical
script calls; this uncached execution is the judging scenario projection.
[SRC] src/validation.cpp:1098–1106,1160–1176,1301–1309,2885–2915 at 6504a3af. -/
structure AdmissionContext where
  params : ChainParams
  tipHeight : Nat
  tipMedianTimePast : Int
  tipTimes : List Nat
  now : Int
  accounting : PoolAccounting
  innerUsage : Tx → Nat
  budget : ValidationBudget := .available
  /-- Explicit system_clock sample in nanoseconds, separate from node/mock now.
  The atomic observation profile holds this sample fixed during admission.
  [SRC] src/leaky_bucket.h:72–85,101–102 at 6504a3af. -/
  bucketTime : Int := 0
  /-- [D] 2026-10-13: index of the orphan selected on each eviction pass.
  [SRC] src/orphan_txns.cpp:227-243 selects begin() of the salted unordered
  map in src/orphan_txns.h:114 at 6504a3af, not the oldest arrival. -/
  orphanEvictionChoice : List OrphanEntry → Nat := fun _ => 0

/-- P: the detector's atomic observation of concurrent validated spends. Kept
outside AdmissionContext so no earlier stage can inspect it.
[SRC] src/txn_double_spend_detector.cpp:26–55 at 6504a3af. -/
structure DetectorObservation where
  committedSpends : List OutPoint := []
  validatingSpends : List OutPoint := []
  deriving DecidableEq, Repr

/-- Stage vocabulary for #66 observations and #67 views, in source order.
[SRC] src/validation.cpp:1031–1494,895–946 at 6504a3af. -/
inductive AdmissionStage where
  | regular | standard | finality | alreadyKnown | conflict | inputs | sequence
  | inputStandard | sigops | fee | ancestors | scripts | detector | commit
  deriving DecidableEq, Repr

/-- Internal stage data, retaining mutations such as a consolidation fee delta
when a later stage refuses the request.
[SRC] src/validation.cpp:1258–1273,1302–1309 at 6504a3af. -/
structure AdmissionWork where
  pool : Mempool
  view : UtxoSet
  request : TxRequest
  finality : FinalityStatus := .final
  judgedFinal : Bool := true
  entry : Option MempoolEntry := none

/-- A stage either continues or completes/defer its current request. This
projection retains a pool mutation even when the verdict is a refusal.
[SRC] src/validation.cpp:1258–1294,1759–1866 at 6504a3af. -/
abbrev AdmissionStep := AdmissionWork × Option TxOutcome

/-- Completed rejection constructor, preserving numeric namespace and exact
reason. [SRC] src/consensus/validation.h:74–78 at 6504a3af. -/
def rejectOutcome (r : Reject) : TxOutcome := .completed (.rejected r.code r.reason)

/-- Translate a reused check's result without replacing its reason.
[SRC] src/validation.cpp:1107–1114,1349–1394 at 6504a3af. -/
def checkedStep (w : AdmissionWork) (result : Except Reject Unit) : AdmissionStep :=
  match result with
  | .ok _ => (w, none)
  | .error e => (w, some (rejectOutcome e))

/-- Effective script configuration projects the caller's activation heights.
[SRC] src/validation.cpp:1031,1073,1210 at 6504a3af. -/
def admissionScriptConfig (cfg : NodeConfig) (ctx : AdmissionContext) : BsvScript.Params.NodeConfig :=
  { cfg.toNodeConfig.normalize with chain := { cfg.chain with
    genesisHeight := ctx.params.genesisHeight, chronicleHeight := ctx.params.chronicleHeight } }

/-- Era at the tip successor, reused by all admission stages.
[SRC] src/validation.cpp:1031 at 6504a3af. -/
def admissionEra (ctx : AdmissionContext) : Era :=
  protocolEraOf ctx.params.genesisHeight ctx.params.chronicleHeight (ctx.tipHeight + 1)

/-- P: strict open interval around activation, with signed subtraction.
[SRC] src/protocol_era.cpp:104–128 at 6504a3af. -/
def inGrace (activation period height : Nat) : Bool :=
  (activation : Int) - period < (height : Int) && (height : Int) < (activation : Int) + period

/-- C: the existing transaction gate's source reasons. Encoding only; no
second transaction predicate is introduced.
[SRC] src/validation.cpp:519–639 at 6504a3af. -/
def regularReason : BsvScript.TxRules.TxReject → String
  | .vinEmpty => "bad-txns-vin-empty"
  | .voutEmpty => "bad-txns-vout-empty"
  | .oversize => "bad-txns-oversize"
  | .voutNegative => "bad-txns-vout-negative"
  | .voutTooLarge => "bad-txns-vout-toolarge"
  | .txoutTotalTooLarge => "bad-txns-txouttotal-toolarge"
  | .sigops => "bad-txn-sigops"
  | .coinbaseWhereRegular => "bad-tx-coinbase"
  | .coinbaseMissing => "bad-cb-missing"
  | .coinbaseLength => "bad-cb-length"
  | .prevoutNull => "bad-txns-prevout-null"
  | .inputsDuplicate => "bad-txns-inputs-duplicate"
  | .p2shOutput => "bad-txns-vout-p2sh"

/-- Stage 1, C with P grace handling: reuse CheckRegularTransaction's twin;
opposite-era success prefixes the original reason with flexible-.
[SRC] src/validation.cpp:1031–1061, src/config.cpp:2417–2420 and
src/configscriptpolicy.cpp:397–412 at 6504a3af. -/
def stageRegular (cfg : NodeConfig) (ctx : AdmissionContext) (w : AdmissionWork) : AdmissionStep :=
  let check := fun era => BsvScript.TxRules.checkRegularTransaction w.request.tx
    cfg.maxTxSigOpsCountConsensusBeforeGenesis
    (if era.genesisActive then cfg.maxTxSizeConsensusAfterGenesis
     else cfg.maxTxSizeConsensusBeforeGenesis) (!era.genesisActive)
  match check (admissionEra ctx) with
  | .ok _ => (w, none)
  | .error e =>
    let flexible := inGrace ctx.params.genesisHeight cfg.genesisGracefulPeriod (ctx.tipHeight + 1) &&
      ((inverseInputEra true (admissionEra ctx)).map (fun era => (check era).isOk)).getD false
    checkedStep w (.error ⟨.node 0x10, (if flexible then "flexible-" else "") ++ regularReason e⟩)

/-- Stage 2, P: reuse IsStandardTx and the exact acceptnonstdoutputs switch.
[SRC] src/validation.cpp:1072–1088 at 6504a3af. -/
def stageStandard (cfg : NodeConfig) (ctx : AdmissionContext) (w : AdmissionWork) : AdmissionStep :=
  let c := admissionScriptConfig cfg ctx
  let era := admissionEra ctx
  match BsvScript.Standard.isStandardTx c era.genesisActive era.chronicleActive
      (BsvScript.TxPolicy.sizeCap c (!era.genesisActive)) w.request.tx with
  | none => (w, none)
  | some r => if BsvScript.TxPolicy.refusesNonStandard c (!era.genesisActive) r then
      checkedStep w (.error ⟨.node 0x40, r.code⟩) else (w, none)

/-- P: add before draining. now and lastDrain are system_clock nanoseconds;
convert their difference to duration<double> seconds before dividing by the
configured period. The decimal scale is a unit conversion, not a limit.
[SRC] src/leaky_bucket.h:44–87, src/time_locked_mempool.h:104–110 and
src/time_locked_mempool.cpp:429–444 at 6504a3af. -/
def updatedNonFinalRate (cfg : NodeConfig) (now : Int) (r : NonFinalRate) : NonFinalRate :=
  let seconds := feeFloat (now - r.lastDrain) / 1000000000
  let intervals := seconds / (cfg.nonFinalReplacementPeriodMinutes * 60).toFloat
  let next := Float.ofBits r.fillBits + 1 - intervals * cfg.nonFinalMaxReplacementRate.toFloat
  { fillBits := (if next < 0 then (0 : Float) else next).toBits, lastDrain := now }

/-- Stage 3, P tip judge/hold/caps: reuse #60's contextual judge and hold;
only non-final requests take the early rate/dependency checks.
[SRC] src/validation.cpp:1094–1138 and src/time_locked_mempool.cpp:182–205
at 6504a3af. -/
def stageFinality (cfg : NodeConfig) (ctx : AdmissionContext) (w : AdmissionWork) : AdmissionStep :=
  let tipEra := protocolEraOf ctx.params.genesisHeight ctx.params.chronicleHeight ctx.tipHeight
  let result : Except Reject FinalityStatus := do
    let final ← (contextualCheckTransactionForCurrentBlock ctx.params w.request.tx ctx.tipHeight
      ctx.tipMedianTimePast ctx.now (standardNonFinalVerifyFlags tipEra)).mapError
        (fun (r : Reject) => { r with code := .node 0x40 })
    routeNonFinal cfg final
  match result with
  | .error e => checkedStep w (.error e)
  | .ok status =>
    let w := { w with finality := status, judgedFinal := status == .final }
    if status == .final then (w, none)
    else if (nonFinalConflicts w.pool w.request.tx).any (fun e =>
        Float.ofBits (updatedNonFinalRate cfg ctx.bucketTime e.rate).fillBits > cfg.nonFinalMaxReplacementRate.toFloat) then
      checkedStep w (.error ⟨.node 0x45, "non-final-txn-replacement-rate"⟩)
    else if w.request.tx.inputs.any (fun i => w.pool.nonFinal.any (fun e => e.entry.id == i.prevHash)) then
      checkedStep w (.error ⟨.node 0x40, "too-long-non-final-chain"⟩)
    else (w, none)

/-- Stage 4, node fact (P admission): held entries are not in mapTx.
[SRC] src/validation.cpp:1142–1145 at 6504a3af. -/
def stageAlreadyKnown (w : AdmissionWork) : AdmissionStep :=
  if w.pool.accepted.any (fun e => e.id == BsvScript.Sighash.txid w.request.tx) then
    checkedStep w (.error ⟨.node 0x101, "txn-already-in-mempool"⟩) else (w, none)

/-- Stage 5, P: no accepted spender is replaced. Held update exceptions are
inside hasPoolConflict, as they are in the source.
[SRC] src/validation.cpp:1147–1152 and src/txmempool.cpp:2257–2280 at 6504a3af. -/
def stageConflict (w : AdmissionWork) : AdmissionStep :=
  if hasPoolConflict w.pool w.request.tx w.judgedFinal then
    checkedStep w (.error ⟨.node 0x102, "txn-mempool-conflict"⟩) else (w, none)

/-- P: limited input lookup stops in input order, missing before size on that
input; equality reaches the positive cache cap. Zero disables this cap.
[SRC] src/coins.cpp:131–156 at 6504a3af. -/
def haveInputsLimited (view : UtxoSet) (limit : Nat) : List TxIn → Nat → Option Bool
  | [], _ => some true
  | i :: rest, size => match getCoin view (OutPoint.ofInput i) with
    | none => some false
    | some coin =>
      let size := size + coin.script.length
      if limit > 0 && size ≥ limit then none else haveInputsLimited view limit rest size

/-- [D] 2026-10-13: bounded eviction with an explicit choice at each pass.
The choice indexes the current list modulo its length; removing that index
preserves the other entries' order. Zero-sized entries also terminate.
[SRC] src/orphan_txns.cpp:227-243, src/orphan_txns.h:114 at 6504a3af. -/
def evictOrphans (choose : List OrphanEntry → Nat) (target : Nat) :
    Nat → List OrphanEntry → List OrphanEntry
  | 0, entries => entries
  | fuel + 1, entries =>
    if (entries.map (·.size)).sum > target then
      evictOrphans choose target fuel (entries.eraseIdx (choose entries % entries.length))
    else entries

/-- [X] 2026-10-13: eviction never increases the retained count, regardless
of the explicit choice. Each pass only erases an index.
[SRC] src/orphan_txns.cpp:228-243 at 6504a3af. -/
theorem evictOrphans_length_le (choose : List OrphanEntry → Nat) (target fuel : Nat)
    (entries : List OrphanEntry) :
    (evictOrphans choose target fuel entries).length ≤ entries.length := by
  induction fuel generalizing entries with
  | zero => simp [evictOrphans]
  | succ fuel ih =>
    simp only [evictOrphans]
    split
    · exact Nat.le_trans (ih _) (List.length_eraseIdx_le _ _)
    · exact Nat.le_refl _

/-- [X] 2026-10-13: enough passes to visit every original entry leave the
aggregate within the trim target for every eviction choice. Overflow implies
nonempty entries, so the modulo index erases an entry on that pass.
[SRC] src/orphan_txns.cpp:192,228-243 at 6504a3af. -/
theorem evictOrphans_size_le (choose : List OrphanEntry → Nat) (target fuel : Nat)
    (entries : List OrphanEntry) (h : entries.length ≤ fuel) :
    ((evictOrphans choose target fuel entries).map (·.size)).sum ≤ target := by
  induction fuel generalizing entries with
  | zero =>
    have : entries = [] := List.length_eq_zero_iff.mp (by omega)
    simp [this, evictOrphans]
  | succ fuel ih =>
    simp only [evictOrphans]
    split
    · rename_i overflow
      have pos : 0 < entries.length := by
        cases entries with
        | nil => simp at overflow
        | cons e es => simp
      have idx := Nat.mod_lt (choose entries) pos
      apply ih
      rw [List.length_eraseIdx_of_lt idx]
      omega
    · omega

/-- [X] 2026-10-13: a target overflow with the full pass budget evicts a
nonempty set, witnessed by a strict decrease in count. This conclusion does
not identify a survivor; salted map order is an explicit transition input.
[SRC] src/orphan_txns.cpp:228-243 at 6504a3af. -/
theorem evictOrphans_overflow_removes (choose : List OrphanEntry → Nat) (target : Nat)
    (entries : List OrphanEntry) (overflow : (entries.map (·.size)).sum > target) :
    (evictOrphans choose target entries.length entries).length < entries.length := by
  cases entries with
  | nil => simp at overflow
  | cons e es =>
    rw [List.length_cons, evictOrphans, if_pos overflow]
    have idx := Nat.mod_lt (choose (e :: es)) (by simp : 0 < (e :: es).length)
    have bound := evictOrphans_length_le choose target es.length
      ((e :: es).eraseIdx (choose (e :: es) % (e :: es).length))
    rw [List.length_eraseIdx_of_lt idx] at bound
    simp only [List.length_cons] at bound ⊢
    omega

/-- P: orphan limits retain sweep/hysteresis gates. [D] 2026-10-13: the
choice of which orphan leaves is an explicit input of the transition, as
DESIGN-S6 §4.5 requires for nondeterministic inputs. The reference calls this
random eviction but selects begin() of a salted unordered map, with no age
ordering promise. All cap, hysteresis and expiry arithmetic is unchanged.
[SRC] src/orphan_txns.cpp:168-244, src/orphan_txns.h:114 at 6504a3af. -/
def limitOrphans (p : Mempool) (cfg : NodeConfig) (now : Int)
    (choose : List OrphanEntry → Nat) (skipEviction := false) : Mempool := Id.run do
  let hysteresis := cfg.maxOrphanTxSize / cfg.orphanTrimHysteresisDivisor
  if p.orphanControl.untrimmedBytes < hysteresis then return p
  let sweep := p.orphanControl.nextSweep ≤ now
  let entries := if sweep then p.orphans.filter (fun e => e.expiresAt > now) else p.orphans
  let next := if sweep then
    (entries.foldl (fun t e => min t e.expiresAt)
      (now + cfg.orphanExpirySeconds - cfg.orphanExpiryCheckIntervalSeconds)) + cfg.orphanExpiryCheckIntervalSeconds
    else p.orphanControl.nextSweep
  let entries := if skipEviction then entries else
    evictOrphans choose (cfg.maxOrphanTxSize - hysteresis) entries.length entries
  return { p with orphans := entries, orphanControl := ⟨next, 0⟩ }

/-- P: missing inputs are retained only with a handler, and rejected parents
suppress retention on P2P. Individual orphan size uses the post-Genesis
policy size setting, even before Genesis.
[SRC] src/validation.cpp:1795–1796,1896–1931 and src/orphan_txns.cpp:47–68
at 6504a3af. -/
def retainOrphan (p : Mempool) (cfg : NodeConfig) (ctx : AdmissionContext) (r : TxRequest) : Mempool :=
  let id := BsvScript.Sighash.txid r.tx
  let p2p := r.source == .p2p
  if !r.orphanHandler then p
  else if p2p && r.tx.inputs.any (fun i => p.recentRejects.contains i.prevHash) then
    { p with recentRejects := p.recentRejects.remember id }
  else
    let size := (BsvScript.Sighash.serTx r.tx).length
    let oversized := p2p && cfg.maxTxSizePolicy != 0 && size > cfg.maxTxSizePolicy
    let known := p.orphans.any (fun e => BsvScript.Sighash.txid e.request.tx == id)
    let p := if oversized || known then p else
      { p with
        orphans := p.orphans ++ [⟨r, ctx.now + cfg.orphanExpirySeconds, size⟩],
        orphanControl := { p.orphanControl with untrimmedBytes := p.orphanControl.untrimmedBytes + size } }
    if p2p then limitOrphans p cfg ctx.now ctx.orphanEvictionChoice else p

/-- Stage 6, P availability route: reuse the combined live view. When inputs
are missing, ANY already-known output gives txn-already-known; otherwise the
SetMissingInputs result is orphan, even for an RPC without retention.
[SRC] src/validation.cpp:721–746,1157–1193 at 6504a3af. -/
def stageInputs (cfg : NodeConfig) (ctx : AdmissionContext) (w : AdmissionWork) : AdmissionStep :=
  let limit := if w.request.useLimits then cfg.maxCoinsViewCacheSize else 0
  match haveInputsLimited w.view limit w.request.tx.inputs 0 with
  | none => checkedStep w (.error ⟨.node 0x10, "bad-txns-inputs-too-large"⟩)
  | some true => (w, none)
  | some false =>
    let id := BsvScript.Sighash.txid w.request.tx
    if w.request.tx.outputs.zipIdx.any (fun (_, n) => (getCoin w.view ⟨id, n⟩).isSome) then
      checkedStep w (.error ⟨.node 0x101, "txn-already-known"⟩)
    else ({ w with pool := retainOrphan w.pool cfg ctx w.request }, some (.completed .orphan))

/-- Stage 7, C before Genesis and no-op afterward: fresh #60 sequence locks.
No lock-cache entry is trusted without an ancestry invariant.
[SRC] src/validation.cpp:362–406,1199–1203 at 6504a3af. -/
def stageSequence (cfg : NodeConfig) (ctx : AdmissionContext) (w : AdmissionWork) : AdmissionStep :=
  let era := protocolEraOf ctx.params.genesisHeight ctx.params.chronicleHeight ctx.tipHeight
  if checkSequenceLocks ctx.params cfg w.request.tx ctx.tipHeight ctx.tipTimes
      (w.request.tx.inputs.map (fun i => (getCoin w.view (OutPoint.ofInput i)).map (·.height)))
      (standardNonFinalVerifyFlags era) then (w, none)
  else checkedStep w (.error ⟨.node 0x40, "non-BIP68-final"⟩)

/-- P: high-priority timeout queues a low-priority request. A low-priority
timeout enters the invalid branch with the source code/reason. Timing itself
is an explicit non-judging observation (`BsvChain.Rejects`, #71).
[SRC] src/txn_validator.cpp:633–641 and src/validation.cpp:1349–1355 at 6504a3af. -/
def deferWork (w : AdmissionWork) (now : Int) : AdmissionStep :=
  if w.request.priority == .low then
    checkedStep w (.error ⟨.node 0x40, "too-long-validation-time"⟩)
  else ({ w with pool := { w.pool with pending := w.pool.pending ++
    [⟨{ w.request with priority := .low }, now⟩] } }, some .deferred)

/-- Stage 8, P: inputs-standardness is reused, with its timed high-priority
branch preserved as a downgrade even when outputs are permitted.
[SRC] src/validation.cpp:1206–1233 at 6504a3af. -/
def stageInputStandard (cfg : NodeConfig) (ctx : AdmissionContext) (w : AdmissionWork) : AdmissionStep :=
  let c := admissionScriptConfig cfg ctx
  let accepts := BsvScript.TxPolicy.acceptsNonStandardOutput c (!(admissionEra ctx).genesisActive)
  if accepts && (!w.request.useLimits || w.request.priority == .low) then (w, none)
  else if w.request.useLimits && ctx.budget == .inputsExpired then deferWork w ctx.now
  else
    let coins := w.request.tx.inputs.filterMap (fun i =>
      (getCoin w.view (OutPoint.ofInput i)).map (fun c => (c.script, c.height)))
    if BsvScript.Standard.areInputsStandard c (ctx.tipHeight + 1) w.request.tx coins then (w, none)
    else if accepts then deferWork w ctx.now
    else checkedStep w (.error ⟨.node 0x40, "bad-txns-nonstandard-inputs"⟩)

/-- Stage 9, P: sigop counting and policy cap are the existing TxPolicy
functions, with each coin's own era and mempool-height resolution.
[SRC] src/validation.cpp:1235–1246,495–517 at 6504a3af. -/
def stageSigops (cfg : NodeConfig) (ctx : AdmissionContext) (w : AdmissionWork) : AdmissionStep :=
  let coins := w.request.tx.inputs.filterMap (fun i =>
    (getCoin w.view (OutPoint.ofInput i)).map (fun c => (c.script, (c.era ctx.params ctx.tipHeight).genesisActive)))
  let count := BsvScript.TxPolicy.txSigOpCount (admissionEra ctx).genesisActive w.request.tx coins
  if count.any (fun n => n ≤ BsvScript.TxPolicy.sigOpsCap cfg.toNodeConfig (!(admissionEra ctx).genesisActive)) then
    (w, none)
  else checkedStep w (.error ⟨.node 0x40, "bad-txns-too-many-sigops"⟩)

/-- P: free consolidation, including zero-value dust donations. Input maturity
uses the stored height, with the source's height-zero waiver; standardness
uses that height's era. Every threshold is a census field.
[SRC] src/policy/policy.cpp:22–158 and src/script/script.cpp:181–189 at 6504a3af. -/
def freeConsolidation (cfg : NodeConfig) (ctx : AdmissionContext) (view : UtxoSet) (tx : Tx) : Bool :=
  let donation := match tx.outputs with
    | [o] => o.value == 0 && o.scriptPubKey == [0, 0x6a, 4, 0x64, 0x75, 0x73, 0x74]
    | _ => false
  let factor := if donation then tx.inputs.length else cfg.minConsolidationFactor
  let minConf := if donation then 0 else cfg.minConfConsolidationInput
  cfg.minConsolidationFactor != 0 && !BsvScript.TxRules.isCoinBase tx &&
    tx.inputs.length ≥ factor * tx.outputs.length &&
    tx.inputs.all (fun i => match getCoin view (OutPoint.ofInput i) with
      | none => false
      | some c =>
        (minConf == 0 || (c.height != mempoolHeight &&
          (c.height == 0 || (ctx.tipHeight + 1 : Int) - c.height ≥ (minConf : Int)))) &&
        i.scriptSig.length ≤ cfg.maxConsolidationInputScriptSize &&
        (cfg.acceptNonStdConsolidationInput || (BsvScript.Standard.isStandardOutput
          (admissionScriptConfig cfg ctx)
          (protocolEraOf ctx.params.genesisHeight ctx.params.chronicleHeight c.height).genesisActive c.script).2)) &&
    (tx.inputs.map (fun i => ((getCoin view (OutPoint.ofInput i)).map (·.script.length)).getD 0)).sum ≥
      factor * (tx.outputs.map (·.scriptPubKey.length)).sum

/-- Stage 10, P: absurd fee is strict and zero disables it. Consolidation
changes the retained fee delta before testing the rolling minimum.
[SRC] src/validation.cpp:742–748,1249–1294 at 6504a3af. -/
def stageFee (cfg : NodeConfig) (ctx : AdmissionContext) (w : AdmissionWork) : AdmissionStep :=
  let tx := w.request.tx
  let id := BsvScript.Sighash.txid tx
  let amount := inputValue w.view tx - outputValue tx
  let ceiling := w.request.absurdFee.getD (if w.request.source == .rpc then cfg.maxTxFee else 0)
  if ceiling != 0 && amount > (ceiling : Int) then
    checkedStep w (.error ⟨.node 0x100, "absurdly-high-fee"⟩)
  else
    let size := (BsvScript.Sighash.serTx tx).length
    let p := if freeConsolidation cfg ctx w.view tx && feeDelta w.pool id == 0 then
      { w.pool with feeDeltas := (id, feeForSize cfg.blockMinTxFee size) ::
        w.pool.feeDeltas.filter (fun x => x.1 != id) }
      else w.pool
    let p := decayRollingFee cfg ctx.accounting ctx.now p
    let w := { w with pool := p }
    let minimum := feeForSize (rollingMinimum cfg p) size
    if minimum > 0 && amount + feeDelta p id < minimum then
      checkedStep w (.error ⟨.node 0x42, "mempool min fee not met"⟩)
    else (w, none)

/-- Stage 11, P: the ancestor statistic is maximum path length; secondary
counts add each distinct direct parent's retained grouping count plus one.
The caps are checked only when a parent exists, with equality refusing.
[SRC] src/txmempool.cpp:194–247 and src/validation.cpp:1301–1318 at 6504a3af. -/
def stageAncestors (cfg : NodeConfig) (ctx : AdmissionContext) (w : AdmissionWork) : AdmissionStep :=
  let tx := w.request.tx
  let parents := poolParents w.pool tx
  let depth := (parents.map (fun e => e.ancestorCount + 1)).foldl max 0
  let secondary := (parents.filter (fun e => !e.primary)).map (fun e => e.secondaryAncestorCount + 1) |>.sum
  if !parents.isEmpty && (depth ≥ cfg.limitAncestorCount || secondary ≥ cfg.limitSecondaryMempoolAncestorCount) then
    checkedStep w (.error ⟨.node 0x40, "too-long-mempool-chain"⟩)
  else
    let entry : MempoolEntry := {
      tx, fee := inputValue w.view tx - outputValue tx,
      time := w.request.acceptTime, height := ctx.tipHeight, size := (BsvScript.Sighash.serTx tx).length,
      ancestorCount := depth, secondaryAncestorCount := secondary, innerUsage := ctx.innerUsage tx,
      spendsCoinbaseOrConfiscation := tx.inputs.any (fun i =>
        (getCoin w.view (OutPoint.ofInput i)).any (fun c => c.isCoinbase || c.isConfiscation)) }
    ({ w with entry := some entry }, none)

/-- C input/value/maturity and operator-list checks followed by P relay
resources with the supplied caller word. Reuses #61/#76 and retains the
confiscation bypass. Both admission word paths check the admission lists;
the block-word cache caller supplies unknown acceptance time zero.
[SRC] src/validation.cpp:1335–1347,705–717,2552–2665,2853–2919 at 6504a3af. -/
def admissionScriptAttempt (cfg : NodeConfig) (ctx : AdmissionContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (w : AdmissionWork) (flags : Flags) (checkTime : Int) : Except Reject Unit := do
  let uc : UtxoContext := {
    params := ctx.params, height := ctx.tipHeight + 1,
    tipHeight := ctx.tipHeight, flags, consensus := false, onBlock := false, now := checkTime }
  let _ ← checkTxInputs w.view cfg uc lists w.request.tx
  if isConfiscationTx w.request.tx then return ()
  let prevouts ← w.request.tx.inputs.mapM fun i => do
    let point := OutPoint.ofInput i
    let some coin := getCoin w.view point | throw ⟨.node 0, ""⟩
    pure (point, coin)
  for ((_, coin), n) in prevouts.zipIdx do
    let params := inputEvalParams cfg ctx.params (ctx.tipHeight + 1) ctx.tipHeight flags false coin
    inlineScriptCheck cfg ctx.params ctx.tipHeight flags
      (inGrace ctx.params.genesisHeight cfg.genesisGracefulPeriod (ctx.tipHeight + 1))
      (inGrace ctx.params.chronicleHeight cfg.chronicleGracefulPeriod (ctx.tipHeight + 1)) oracle
      ⟨w.request.tx, prevouts, n, coin.height, ctx.tipHeight + 1, params⟩

/-- A non-judging oracle result propagates as a model decline, not a node code.
[SRC] src/validation.cpp:2538–2542,1349–1355 at 6504a3af; Oracle's explicit
recording-miss contract supplies the code-zero model signal. -/
def scriptFailure (w : AdmissionWork) (r : Reject) : AdmissionStep :=
  if r.code == .node 0 then (w, some (.unverifiable r.reason)) else checkedStep w (.error r)

/-- P: script failure severity needed by the outer Chronicle grace retry.
The reused wrapper maps policy failures to zero punishment, except that the
policy number-length and library overflow failures keep INVALID with ten
punishment points, the source encoding rather than a policy limit.
[SRC] src/validation.cpp:2727–2759,2789–2837 at 6504a3af. -/
def scriptPenalty (r : Reject) : Nat :=
  if r.code == .node 0x40 then 0
  else if r.reason.startsWith "max-script-num-length-policy-limit-violated" ||
      r.reason.startsWith "max-script-num-overflow" then 10 else 100

/-- Stage 12, mixed C/P/operator-list: relay word with exclusions, Chronicle
grace retry, block word with policy resources, then mandatory fallback.
Uncovered recorded calls and absent network heights decline explicitly.
A successful mandatory fallback resets the source's non-final mark while
the detector still uses the retained local finality judgment.
[SRC] src/validation.cpp:1320–1482 at 6504a3af. -/
def stageScripts (cfg : NodeConfig) (ctx : AdmissionContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (w : AdmissionWork) : AdmissionStep := Id.run do
  let some relay := callerScriptFlags cfg ctx.params (ctx.tipHeight + 1) (.relay w.request.skipScriptFlags) |
    return (w, some (.unverifiable "unresolved relay flags"))
  -- Input checks precede cancellation-sensitive scripts.
  let uc : UtxoContext := {
    params := ctx.params, height := ctx.tipHeight + 1, tipHeight := ctx.tipHeight,
    flags := relay, consensus := false, onBlock := false, now := w.request.acceptTime }
  if let .error r := checkTxInputs w.view cfg uc lists w.request.tx then return scriptFailure w r
  if w.request.useLimits && ctx.budget == .relayExpired then return deferWork w ctx.now
  if let .error original := admissionScriptAttempt cfg ctx lists oracle w relay w.request.acceptTime then
    if original.code == .node 0 then return scriptFailure w original
    if inGrace ctx.params.chronicleHeight cfg.chronicleGracefulPeriod (ctx.tipHeight + 1) then
      if let some inverse := inverseInputEra false (admissionEra ctx) then
        let word := excludeScriptFlags (mempoolScriptFlags inverse cfg.chainRequireStandard cfg.promiscuousMempoolFlags)
          w.request.skipScriptFlags
        match admissionScriptAttempt cfg ctx lists oracle w word w.request.acceptTime with
        | .ok _ => return checkedStep w (.error ⟨.node 0x40, "flexible-" ++ original.reason⟩)
        | .error less =>
          if less.code == .node 0 then return scriptFailure w less
          if scriptPenalty less < scriptPenalty original then
            return checkedStep w (.error ⟨.node 0x40, "flexible-" ++ original.reason⟩)
    return scriptFailure w original
  let some blockWord := callerScriptFlags cfg ctx.params (ctx.tipHeight + 1) .block |
    return (w, some (.unverifiable "unresolved block flags"))
  if w.request.useLimits && ctx.budget == .blockExpired then return deferWork w ctx.now
  match admissionScriptAttempt cfg ctx lists oracle w blockWord 0 with
  | .ok _ => return (w, none)
  | .error blockError =>
    if blockError.code == .node 0 then return scriptFailure w blockError
    if (excludeScriptFlags blockWord relay).toWord == 0 then return scriptFailure w blockError
    if w.request.useLimits && ctx.budget == .mandatoryExpired then return deferWork w ctx.now
    match admissionScriptAttempt cfg ctx lists oracle w (mandatoryFlags (admissionEra ctx)) w.request.acceptTime with
    | .error r => return scriptFailure w r
    | .ok _ => return ({ w with finality := .final }, none)

/-- Stage 13, P: detector insertion is after every validation stage. It checks
newly committed locks before in-flight spends. The atomic observation affects
no earlier stage and is not retained as a second spent index.
[SRC] src/validation.cpp:1484–1494, src/txn_double_spend_detector.cpp:26–55 and
src/txmempool.h:1380–1389 at 6504a3af. -/
def stageDetector (observation : DetectorObservation) (w : AdmissionWork) : AdmissionStep :=
  if hasPoolConflict w.pool w.request.tx w.judgedFinal ||
      w.request.tx.inputs.any (fun i => observation.committedSpends.contains (OutPoint.ofInput i)) then
    checkedStep w (.error ⟨.node 0x102, "txn-mempool-conflict"⟩)
  else if w.request.tx.inputs.any (fun i => observation.validatingSpends.contains (OutPoint.ofInput i)) then
    checkedStep w (.error ⟨.node 0x12, "txn-double-spend-detected"⟩)
  else (w, none)

/-- P: removing a held transaction releases locks and marks the separate
recently-removed filter (the same rolling filter class; the wipe-free regime
of `BsvChain.Rejects`, #71, bounds its exact reading).
[SRC] src/time_locked_mempool.cpp:481–510 at 6504a3af. -/
def removeNonFinal (p : Mempool) (id : TxId) : Mempool :=
  { p with
    nonFinal := p.nonFinal.filter (fun e => e.entry.id != id),
    nonFinalRecentlyRemoved := p.nonFinalRecentlyRemoved.remember id }

/-- P: non-final update checks preserve corresponding outpoints, never decrease
sequences and require an increase. now is system_clock nanoseconds, as in
updatedNonFinalRate. The finalised flag follows ONLY changed
sequences, including the source's unchanged-nonfinal-sequence corner.
[SRC] src/time_locked_mempool.cpp:516–589 at 6504a3af. -/
def validateNonFinalUpdate (cfg : NodeConfig) (now : Int) (old : NonFinalEntry)
    (tx : Tx) : Except Reject (Bool × NonFinalRate) := do
  let pairs := tx.inputs.zip old.entry.tx.inputs
  if tx.inputs.length != old.entry.tx.inputs.length ||
      !pairs.all (fun (a, b) => OutPoint.ofInput a == OutPoint.ofInput b && a.sequence ≥ b.sequence) ||
      !pairs.any (fun (a, b) => a.sequence > b.sequence) then
    throw ⟨.node 0x10, "bad-txn-update"⟩
  let rate := updatedNonFinalRate cfg now old.rate
  if Float.ofBits rate.fillBits > cfg.nonFinalMaxReplacementRate.toFloat then
    throw ⟨.node 0x45, "non-final-txn-replacement-rate"⟩
  return (pairs.all (fun (a, b) => a.sequence == b.sequence || a.sequence == BsvScript.TxContext.SEQUENCE_FINAL), rate)

/-- P: held insertion checks occupancy AFTER insertion, removes the new entry
on overflow, and does not restore a replaced old transaction.
[SRC] src/time_locked_mempool.cpp:67–86,447–478 at 6504a3af. -/
def insertNonFinal (w : AdmissionWork) (cfg : NodeConfig) (ctx : AdmissionContext)
    (entry : MempoolEntry) (rate : NonFinalRate) : AdmissionStep :=
  let p := { w.pool with nonFinal := w.pool.nonFinal ++ [⟨entry, rate⟩] }
  if nonFinalUsage ctx.accounting p > cfg.maxMempoolNonFinal then
    checkedStep { w with pool := removeNonFinal p entry.id }
      (.error ⟨.node 0x103, "non-final-pool-full"⟩)
  else ({ w with pool := p }, some (.completed .heldNonFinal))

/-- Stage 14, P: commit to the hold pool or accepted pool, then limit size.
An update finalising a held transaction schedules fresh validation and has
no completed admission verdict yet. Parent collection happens after commit.
[SRC] src/validation.cpp:895–946 and src/time_locked_mempool.cpp:35–97
at 6504a3af. -/
def stageCommit (cfg : NodeConfig) (ctx : AdmissionContext) (w : AdmissionWork) : AdmissionStep :=
  match w.entry with
  | none => (w, some (.unverifiable "entry absent at commit"))
  | some entry =>
    if w.finality == .heldNonFinal || finalisesExisting w.pool w.request.tx then
      match nonFinalConflicts w.pool w.request.tx with
      | [] => insertNonFinal w cfg ctx entry ⟨0, ctx.bucketTime⟩
      | [old] =>
        match validateNonFinalUpdate cfg ctx.bucketTime old w.request.tx with
        | .error r => checkedStep w (.error r)
        | .ok (finalised, rate) =>
          let w := { w with pool := removeNonFinal w.pool old.entry.id }
          if finalised then
            let r := { w.request with source := .finalised, acceptTime := ctx.now }
            ({ w with pool := { w.pool with pending := w.pool.pending ++ [⟨r, ctx.now⟩] } }, some .deferred)
          else insertNonFinal w cfg ctx entry rate
      | _ => checkedStep w (.error ⟨.node 0x10, "bad-txn-update"⟩)
    else
      let p := addUnchecked w.pool cfg entry
      let p := if w.request.limitMempoolSize then limitPool p cfg ctx.accounting ctx.now else p
      let w := { w with pool := p }
      if p.accepted.any (fun e => e.id == entry.id) then (w, some (.completed .accepted))
      else checkedStep w (.error ⟨.node 0x42, "mempool full"⟩)

/-- P: observable ordered stage execution; a stopped stage prevents every
later call. Trace values are harness metadata, not node event names (#84).
[SRC] src/validation.cpp:1009–1505 at 6504a3af. -/
def runAdmissionStages : List (AdmissionStage × (AdmissionWork → AdmissionStep)) →
    AdmissionWork → AdmissionWork × Option TxOutcome × List AdmissionStage
  | [], w => (w, none, [])
  | (stage, check) :: rest, w =>
    let (w, result) := check w
    match result with
    | some outcome => (w, some outcome, [stage])
    | none =>
      let (w, outcome, trace) := runAdmissionStages rest w
      (w, outcome, stage :: trace)

/-- Named pre-conflict prefix; the protected-spend theorem's hypotheses say
these source-ordered earlier checks succeeded. A malformed conflict can be
refused earlier for another reason.
[SRC] src/validation.cpp:1031–1145 at 6504a3af. -/
def admissionPrefix (cfg : NodeConfig) (ctx : AdmissionContext) :
    List (AdmissionStage × (AdmissionWork → AdmissionStep)) :=
  [(.regular, stageRegular cfg ctx), (.standard, stageStandard cfg ctx),
   (.finality, stageFinality cfg ctx), (.alreadyKnown, stageAlreadyKnown)]

/-- Stages preceding the detector have no detector argument. C/P kinds are
stated on each stage; this list fixes their order for all script oracles.
[SRC] src/validation.cpp:1031–1482 at 6504a3af. -/
def beforeDetector (cfg : NodeConfig) (ctx : AdmissionContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (w : AdmissionWork) :=
  runAdmissionStages (admissionPrefix cfg ctx ++
    [(.conflict, stageConflict), (.inputs, stageInputs cfg ctx), (.sequence, stageSequence cfg ctx),
     (.inputStandard, stageInputStandard cfg ctx), (.sigops, stageSigops cfg ctx),
     (.fee, stageFee cfg ctx), (.ancestors, stageAncestors cfg ctx),
     (.scripts, stageScripts cfg ctx lists oracle)]) w

/-- P: complete routing after validation. Successful requests collect outputs
for later orphan retry; no child is directly inserted here. A P2P rejection
returned by validation itself enters the filter and erases a stored orphan;
the commit's own refusals take `finishCommit` below.
[SRC] src/validation.cpp:1786–1797,1859–1864,1988–1995,2043–2048 at 6504a3af. -/
def finishAdmission (w : AdmissionWork) (outcome : TxOutcome) : Mempool :=
  let id := BsvScript.Sighash.txid w.request.tx
  match outcome with
  | .completed .accepted | .completed .heldNonFinal =>
    if !w.request.orphanHandler then w.pool else
      { w.pool with
        orphans := w.pool.orphans.filter (fun e => BsvScript.Sighash.txid e.request.tx != id),
        collected := w.pool.collected ++ [(id, w.request.tx.outputs.length)] }
  | .completed (.rejected _ _) =>
    if w.request.source == .p2p then { w.pool with
      recentRejects := w.pool.recentRejects.remember id,
      orphans := w.pool.orphans.filter (fun e => BsvScript.Sighash.txid e.request.tx != id) } else w.pool
  | _ => w.pool

/-- P, [D] 2026-10-14 (#71): a refusal by the commit (stage 14) is reached
only on the validated branch, after the invalid-state handlers that write the
filter; the P2P peer is answered with a reject message and nothing is
remembered, and a stored orphan is not erased. A commit that succeeds is
routed as before.
[SRC] src/validation.cpp:1786–1806 (the invalid branch),1808–1836 (the commit
and its post-validation step),1859–1864,2097–2136 and
src/time_locked_mempool.cpp:36–97 at 6504a3af. -/
def finishCommit (w : AdmissionWork) (outcome : TxOutcome) : Mempool :=
  match outcome with
  | .completed (.rejected _ _) => w.pool
  | _ => finishAdmission w outcome

/-- Atomic acceptance with trace. Filter consultation is a P2P inventory
observation only; RPC submission is never silently dropped by this filter.
This consult reads the filter as it stands: the lazy reset on an observed tip
change and the other known-transaction tests are the inventory envelope of
`BsvChain.Rejects` (#71), which calls this transition.
[SRC] src/net/net.cpp:3558–3564, src/validation.cpp:1009–1505,1759–1866
at 6504a3af. -/
def acceptWithTrace (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (observation : DetectorObservation) (request : TxRequest) :
    Mempool × TxOutcome × List AdmissionStage :=
  let cfg := request.configOverride.getD cfg
  if request.source == .p2p && p.recentRejects.contains (BsvScript.Sighash.txid request.tx) then
    (p, .suppressed, [])
  else
    let w : AdmissionWork := { pool := p, view := mempoolView p utxo, request }
    let (w, result, trace) := beforeDetector cfg ctx lists oracle w
    match result with
    | some outcome => (finishAdmission w outcome, outcome, trace)
    | none =>
      let (w, result, suffix) := runAdmissionStages
        [(.detector, stageDetector observation), (.commit, stageCommit cfg ctx)] w
      let outcome := result.getD (.unverifiable "commit returned no outcome")
      (if suffix.contains .commit then finishCommit w outcome else finishAdmission w outcome,
        outcome, trace ++ suffix)

/-- Public acceptance transition. Complete requests return the four-valued
TxVerdict inside completed; deferred and suppressed requests record no verdict.
This envelope is required by DESIGN-S6 §2 and the #62/#71 amendment.
[SRC] src/validation.cpp:1759–1866, src/txn_validator.cpp:633–641 and
src/time_locked_mempool.cpp:73–80 at 6504a3af. -/
def accept (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (observation : DetectorObservation) (request : TxRequest) : Mempool × TxOutcome :=
  let (p, result, _) := acceptWithTrace p utxo cfg ctx lists oracle observation request
  (p, result)

/-- Direct orphan dependencies selected by a collected parent's output index.
The retained request includes its source, priority and per-call overrides.
[SRC] src/orphan_txns.cpp:278–301 at 6504a3af. -/
def directOrphanRetries (p : Mempool) : List OrphanEntry :=
  p.orphans.filter fun e => e.request.tx.inputs.any fun i =>
    p.collected.any (fun (id, count) => i.prevHash == id && i.prevIndex < count)

/-- P: one secondary output appends its unique eligible child to both lists.
Ambiguous spends, excessive inputs and already-selected ids are skipped.
[SRC] src/orphan_txns.cpp:321–346 at 6504a3af. -/
def collectOrphanChild (p : Mempool) (cfg : NodeConfig) (id : TxId)
    (state : List OrphanEntry × List OrphanEntry) (n : Nat) :
    List OrphanEntry × List OrphanEntry :=
  match p.orphans.filter (fun e => e.request.tx.inputs.any
      (fun i => i.prevHash == id && i.prevIndex == n)) with
  | [child] =>
    if child.request.tx.inputs.length ≤ cfg.maxInputsOutputsPerSecondaryOrphan &&
        !state.1.any (fun e => BsvScript.Sighash.txid e.request.tx == BsvScript.Sighash.txid child.request.tx) then
      (state.1 ++ [child], state.2 ++ [child])
    else state
  | _ => state

/-- P: bounded finite breadth traversal for secondary orphan dependencies.
Fuel counts retained vertices, not a policy limit; selection only appends.
[SRC] src/orphan_txns.cpp:303–350 at 6504a3af. -/
def expandOrphanRetries (p : Mempool) (cfg : NodeConfig) (cap : Nat) :
    Nat → List OrphanEntry → List OrphanEntry → List OrphanEntry
  | 0, chosen, _ => chosen
  | fuel + 1, chosen, queue =>
    if chosen.length < cap then
      match queue with
      | [] => chosen
      | parent :: rest =>
        let state := (List.range (min parent.request.tx.outputs.length cfg.maxInputsOutputsPerSecondaryOrphan)).foldl
          (collectOrphanChild p cfg (BsvScript.Sighash.txid parent.request.tx)) (chosen, rest)
        expandOrphanRetries p cfg cap fuel state.1 state.2
    else chosen

/-- P: collect orphan retries in explicit retained order. Direct children are
all queued, even above the batch percentage. Secondary breadth traversal
skips ambiguous double spends and bounds inputs/outputs as the pin does.
[SRC] src/orphan_txns.cpp:256–350 and src/txn_validator.cpp:695–724
at 6504a3af. -/
def orphanRetryRequests (p : Mempool) (cfg : NodeConfig) (batchSize : Nat) : List TxRequest :=
  let direct := directOrphanRetries p
  (expandOrphanRetries p cfg (batchSize * cfg.maxPercentageOfOrphansInBatch / 100)
    p.orphans.length direct direct).map (·.request)

/-- P: parent arrival only queues requests for the same accept transition.
There is no accepted-pool write here, even when every parent has arrived.
[SRC] src/orphan_txns.cpp:288–301 and src/txn_validator.cpp:695–724 at 6504a3af. -/
def retryOrphans (p : Mempool) (cfg : NodeConfig) (now : Int) (batchSize : Nat) : Mempool :=
  { p with collected := [], pending := p.pending ++ (orphanRetryRequests p cfg batchSize).map (fun r =>
    ⟨{ r with acceptTime := now }, now⟩) }



/-- P: the periodic non-final callback tests full-width IsFinalTx before expiry,
removes the hold and queues fresh validation. Unlike the tip admission caller,
this callback does not narrow the median. Frozen lists are rechecked on retry.
[SRC] src/time_locked_mempool.cpp:611–660 at 6504a3af. -/
def checkNonFinalPool (p : Mempool) (cfg : NodeConfig) (ctx : AdmissionContext) : Mempool :=
  (p.nonFinal.mergeSort (fun a b => a.entry.tx.lockTime ≤ b.entry.tx.lockTime)).foldl (fun pool held =>
    if isFinalTx held.entry.tx (ctx.tipHeight + 1) ctx.tipMedianTimePast then
      let pool := removeNonFinal pool held.entry.id
      let era := admissionEra ctx
      let standard := BsvScript.Standard.isStandardTx (admissionScriptConfig cfg ctx)
        era.genesisActive era.chronicleActive (BsvScript.TxPolicy.sizeCap cfg.toNodeConfig (!era.genesisActive)) held.entry.tx
      let request : TxRequest := {
        tx := held.entry.tx, acceptTime := ctx.now, source := .finalised,
        priority := if standard.isNone then .high else .low }
      { pool with pending := pool.pending ++ [⟨request, ctx.now⟩] }
    else if nonFinalExpired cfg held.entry.time ctx.now then removeNonFinal pool held.entry.id
    else pool) p

/-- Explicit maintenance event. Merely changing now runs no callback; #66 must
observe scheduler completion. The configured non-final interval is a scheduler
parameter, not a finality cutoff. #84 owns externally visible event names.
[SRC] src/time_locked_mempool.cpp:402,611–660,
src/orphan_txns.cpp:168–244 and src/txn_validator.cpp:695–724 at 6504a3af. -/
inductive PoolMaintenance where
  | limit | nonFinalCheck | orphanSweep | retry (batchSize : Nat) | blockObserved
  deriving DecidableEq, Repr

/-- Policy maintenance driven by explicit event and now; block observation
sets its GetTime timestamp and opens the decay gate. No maintenance step
directly admits pending work.
[SRC] src/validation.cpp:847–892, src/txmempool.cpp:1170–1171 and
src/time_locked_mempool.cpp:611–660 at 6504a3af. -/
def advanceTime (p : Mempool) (cfg : NodeConfig) (ctx : AdmissionContext) : PoolMaintenance → Mempool
  | .limit => limitPool p cfg ctx.accounting ctx.now
  | .nonFinalCheck => checkNonFinalPool p cfg ctx
  | .orphanSweep => limitOrphans p cfg ctx.now ctx.orphanEvictionChoice true
  | .retry batchSize => retryOrphans p cfg ctx.now batchSize
  | .blockObserved => { p with rollingFee := { p.rollingFee with lastUpdate := ctx.now, blockSinceBump := true } }

/-- Consume one queued request through the same acceptance machine. Updating
its context/oracle is the caller's explicit step; parent arrival alone cannot
supply an accepted outcome.
[SRC] src/txn_validator.cpp:695–724 and src/time_locked_mempool.cpp:641–653
at 6504a3af. -/
def revalidatePending (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (observation : DetectorObservation) : Mempool × Option TxOutcome :=
  match p.pending with
  | [] => (p, none)
  | work :: rest =>
    let (pool, outcome) := accept { p with pending := rest } utxo cfg ctx lists oracle observation work.request
    (pool, some outcome)

/-- Spec journals, separate from the node's membership-only reject filter.
The chain State of #64 can retain this projection. [SRC] src/validation.cpp:1934–1950
at 6504a3af; DESIGN-S6 §1.4 specifies the additional observation history. -/
structure TxJournal where
  seen : List (TxId × Tx) := []
  rejected : List (TxId × Reject) := []
  deriving Repr

/-- Record every body; only completed verdicts alter the rejection journal.
A hold/orphan/accept clears an older rejection. This is harness bookkeeping,
not a claim that the node persists rejection reasons.
[SRC] src/validation.cpp:1934–1950 at 6504a3af; DESIGN-S6 §1.4. -/
def recordTxOutcome (journal : TxJournal) (tx : Tx) (outcome : TxOutcome) : TxJournal :=
  let id := BsvScript.Sighash.txid tx
  let seen := (id, tx) :: journal.seen.filter (fun e => e.1 != id)
  let rejected := match outcome with
    | .completed (.rejected code reason) => (id, ⟨code, reason⟩) :: journal.rejected.filter (fun e => e.1 != id)
    | .completed _ => journal.rejected.filter (fun e => e.1 != id)
    | _ => journal.rejected
  { seen, rejected }

end BsvChain
