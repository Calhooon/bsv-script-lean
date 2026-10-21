import BsvChain.Mempool

/-!
# The reject cache and the validation time budgets (#71; amends #62)

Policy at bitcoin-sv v1.2.3, 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
Nothing in this module is a block-validity rule: the filter, its reset, the
two validation priorities and the time budgets are node policy, each a field
of the #59 census (`recentRejectCapacity`, `recentRejectFalsePositiveRate`,
`maxStdTxnValidationDuration`, `maxNonStdTxnValidationDuration`,
`maxTxnChainValidationBudget`, `validationClockCpu`; docs/PARAMETERS.md §8.2).

The reject cache. `CTxnRecentRejects` is a rolling bloom filter of txids,
membership only. It is written by the invalid-state handlers of a P2P request
and read by the inventory test `IsTxnKnown`; it is emptied lazily, by the
next inventory test that observes a tip hash different from the one recorded
at the previous test. A synchronous RPC submission neither reads nor writes it.
[SRC] src/txn_recent_rejects.h:20–58, src/txn_recent_rejects.cpp:9–27,
src/net/net_processing.cpp:82,930–961, src/net/net.cpp:3558–3564,
src/validation.cpp:1786–1797,1888–1932,1988–1995,2043–2048 and
src/rpc/rawtransaction.cpp:1586–1594,1625–1626 at 6504a3af.

The time budgets. A limited request is validated under a cancellation source
whose allowance is its priority's duration plus the unused time carried from
the previous transaction of its chain. When the source fires, a high-priority
request is moved to the low-priority queue with no answer, and a low-priority
request is refused with `too-long-validation-time`. The clock is the node's
(thread CPU time by default), so the elapsed time is an explicit input here
and every observation whose outcome depends on it is non-judging, whether its
budget expired or not (`ClockDependence`, `budgetJudgment`; DESIGN-S6 §4.5).
[SRC] src/validation.cpp:990–1006,1077–1078,1210–1233,1349–1355,1424–1430,
1458–1464, src/taskcancellation.h:106–179, src/txn_validator.cpp:633–641 and
src/txn_validation_config.h:36–46 at 6504a3af.
-/

namespace BsvChain
open BsvScript.Tx BsvScript.Numbers BsvScript.Params

/-! ## The filter: reset and the wipe-free regime -/

/-- P: one generation of the rolling filter holds half the capacity, rounded
up. With the census default 120,000 this is 60,000 insertions.
[SRC] src/bloom.cpp:222–225 and src/txn_recent_rejects.cpp:9–11 at 6504a3af. -/
def RejectFilter.generationSize (f : RejectFilter) : Nat := (f.capacity + 1) / 2

/-- P: no generation has been wiped since the last reset. The filter keeps
three generations; the insertion that opens a fourth reuses the oldest
generation's number and wipes its entries. Inside this regime every inserted
id is still present at the node, so the ideal set reads a real member exactly
as the node does. Outside it an old member may have been forgotten, and the
observation is non-judging.
[SRC] src/bloom.cpp:265–281,322–329 and src/bloom.h:117–118 at 6504a3af. -/
def RejectFilter.wipeFree (f : RejectFilter) : Bool :=
  f.insertions ≤ 3 * f.generationSize

/-- P: the reset empties the membership and restarts the generation count.
The node also draws a fresh hash tweak; the ideal set has no tweak.
[SRC] src/txn_recent_rejects.cpp:24–27 and src/bloom.cpp:322–329 at 6504a3af. -/
def RejectFilter.reset (f : RejectFilter) : RejectFilter :=
  { f with members := [], insertions := 0 }

/-- P: the lazy reset. Every inventory test compares the active tip's hash
with the hash recorded by the previous test before membership tests; when they
differ it records the new hash and resets the filter. The tip hash is an explicit input: this
module reads no chain. A tip that moved and came back between two tests is not
observed, and the filter survives it. Before any test the record is the null
hash (`none`), which no tip equals.
[SRC] src/net/net_processing.cpp:82,930–942 and src/net/net.cpp:3563–3564
at 6504a3af. -/
def observeTip (p : Mempool) (tip : Bytes) : Mempool :=
  if p.recentRejectsTip == some tip then p
  else { p with recentRejects := p.recentRejects.reset, recentRejectsTip := some tip }

/-! ## Which rejections are remembered -/

/-- P: the insert rule. A rejection enters the filter when all of these hold:
the request came from a peer; validation itself returned an invalid state
(stages 1 to 13: a refusal by the commit, stage 14, is answered but not
remembered); the request is fully processed, which excludes a high-priority
timeout (`deferred`); the state is not a missing-inputs state (`orphan`).
The corruption flag that also excludes an insert is set only by the block's
merkle checks, never on this path. An orphan whose parent is remembered is
inserted by `retainOrphan` with the `orphan` outcome, outside this predicate.
[SRC] src/validation.cpp:1786–1797,1888–1932,1967–1995,2037–2048,5773,5780
and src/consensus/validation.h:68–74 at 6504a3af. -/
def remembersRejection (source : TxSource) (stopped : Option AdmissionStage) :
    TxOutcome → Bool
  | .completed (.rejected _ _) => source == .p2p && stopped != some .commit
  | _ => false

/-! ## The inventory envelope -/

/-- Explicit inputs of one inventory test. `tip` is the active tip's hash as
the node reads it at the test. `coinInCache` is the node's coins-cache lookup
for an outpoint, a cache presence and not a UTXO existence. `filterFalsePositive`
marks an id the node's reject filter would report although it was never
inserted; `removedFalsePositive` does the same for the separate rolling filter
of recently removed held transactions. The defaults are the ideal sets.
[SRC] src/net/net_processing.cpp:930–961, src/time_locked_mempool.h:209–214,
src/time_locked_mempool.cpp:217–221 and src/bloom.h:112–118 at 6504a3af. -/
structure InventoryObservation where
  tip : Bytes
  coinInCache : OutPoint → Bool := fun _ => false
  filterFalsePositive : TxId → Bool := fun _ => false
  removedFalsePositive : TxId → Bool := fun _ => false

/-- The same inventory test with both filters read as ideal sets: no declared
false positive on either. -/
def InventoryObservation.ideal (obs : InventoryObservation) : InventoryObservation :=
  { tip := obs.tip, coinInCache := obs.coinInCache }

/-- P: the known-transaction tests other than the reject filter: an accepted
or held transaction, a recently removed held transaction (or a declared false
positive of that separate filter), a transaction in the validation queues or
the orphan pool (the id tracker), or outputs 0 or 1 found in the coins cache.
[SRC] src/net/net_processing.cpp:949–961 and src/time_locked_mempool.cpp:217–221
at 6504a3af. -/
def knownElsewhere (p : Mempool) (obs : InventoryObservation) (id : TxId) : Bool :=
  p.accepted.any (fun e => e.id == id) ||
  p.nonFinal.any (fun e => e.entry.id == id) ||
  (p.nonFinalRecentlyRemoved.contains id || obs.removedFalsePositive id) ||
  p.pending.any (fun w => BsvScript.Sighash.txid w.request.tx == id) ||
  p.orphans.any (fun e => BsvScript.Sighash.txid e.request.tx == id) ||
  obs.coinInCache ⟨id, 0⟩ || obs.coinInCache ⟨id, 1⟩

/-- P: `IsTxnKnown` after its lazy reset: a recent rejection (or a declared
false positive of the node's filter), or any of the other tests.
[SRC] src/net/net_processing.cpp:948–961 at 6504a3af. -/
def knownTx (p : Mempool) (obs : InventoryObservation) (id : TxId) : Bool :=
  p.recentRejects.contains id || obs.filterFalsePositive id || knownElsewhere p obs id

/-- The node's answer to a transaction inventory: it asks for the body
(`getdata`) or stays silent. Silence is not a message.
[SRC] src/net/net_processing.cpp:2479,2518–2519,5794–5800 at 6504a3af. -/
inductive InvAnswer where
  | request | silence
  deriving DecidableEq, Repr

/-- P: receive a transaction inventory from a peer. The lazy reset runs
before the known-id test; a known id draws silence, any other id is requested. The node asks
only outside initial block download, import and reindex; those states are
not part of this machine.
[SRC] src/net/net_processing.cpp:914–961,2479,2518–2519 at 6504a3af. -/
def receiveInv (p : Mempool) (obs : InventoryObservation) (id : TxId) : Mempool × InvAnswer :=
  let p := observeTip p obs.tip
  (p, if knownTx p obs id then .silence else .request)

/-- P: the request the message handler builds for a transaction received
from a peer: high priority, limited, with the persistent orphan pool, no
per-transaction pool trim (the batch trims afterwards) and a zero absurd-fee
ceiling.
[SRC] src/net/net_processing.cpp:3380–3394, src/txn_validator.cpp:421–438
and src/validation.cpp:1611 at 6504a3af. -/
def p2pRequest (tx : Tx) (now : Int) : TxRequest :=
  { tx, source := .p2p, priority := .high, acceptTime := now, absurdFee := some 0,
    useLimits := true, limitMempoolSize := false, orphanHandler := true }

/-! ## The priority lattice -/

/-- P: the two validation priorities as a chain, low below high. The pin's
enumeration has a third value, `normal`, carried by the synchronous RPC
request; that path builds no cancellation source, so no timeout transition
exists for it, and #62 projects it to `high` with `useLimits := false`.
[SRC] src/txn_validation_data.h:28–33, src/rpc/rawtransaction.cpp:1590 and
src/txn_validator.cpp:171–177 at 6504a3af. -/
def TxPriority.rank : TxPriority → Nat
  | .low => 0
  | .high => 1

instance : LE TxPriority := ⟨fun a b => a.rank ≤ b.rank⟩

instance (a b : TxPriority) : Decidable (a ≤ b) := inferInstanceAs (Decidable (a.rank ≤ b.rank))

/-- P: the timeout's move. High becomes low; low stays low.
[SRC] src/txn_validator.cpp:633–641 at 6504a3af. -/
def TxPriority.lowered : TxPriority → TxPriority := fun _ => .low

/-- P: the queued request after a timeout, every other field retained.
[SRC] src/txn_validator.cpp:633–638 at 6504a3af. -/
def TxRequest.lowered (r : TxRequest) : TxRequest := { r with priority := r.priority.lowered }

/-! ## The time budget, with elapsed time as an explicit input -/

/-- P: the duration a priority is validated under, in milliseconds: the
standard duration for high, the non-standard duration for low.
[SRC] src/validation.cpp:999–1001, src/txn_validation_config.h:39–43 and
src/config.cpp:64–65 at 6504a3af. -/
def validationDuration (cfg : NodeConfig) : TxPriority → Nat
  | .high => cfg.maxStdTxnValidationDuration
  | .low => cfg.maxNonStdTxnValidationDuration

/-- Explicit elapsed-time observation of one limited validation, in
microseconds of the budget's clock (thread CPU time when `validationClockCpu`
is set, the steady clock otherwise). `carried` is the unused time the previous
transaction of the same chain left; the other fields are the elapsed time at
the last poll inside each cancellable check, zero for a check that did not
run. The machine reads no clock: the harness supplies the observation or
marks the cell non-judging.
[SRC] src/taskcancellation.h:106–179 and src/validation.cpp:1002–1005,
1210–1233,1335–1355,1414–1430,1444–1464 at 6504a3af. -/
structure ElapsedObservation where
  carried : Nat := 0
  inputs : Nat := 0
  relay : Nat := 0
  block : Nat := 0
  mandatory : Nat := 0
  deriving DecidableEq, Repr

/-- P: the cancellation source's allowance in microseconds: the priority's
duration plus the carried time, the carry capped by the chain budget.
[SRC] src/taskcancellation.h:113–121,173–179 and src/validation.cpp:1577
at 6504a3af. -/
def validationAllowance (cfg : NodeConfig) (priority : TxPriority) (elapsed : ElapsedObservation) : Nat :=
  1000 * validationDuration cfg priority + min elapsed.carried (1000 * cfg.maxTxnChainValidationBudget)

/-- P: the budget observation #62's stages consume, derived from the elapsed
time. The source fires at the earliest poll whose elapsed time strictly
exceeds the allowance.
[SRC] src/taskcancellation.h:155–164 and src/validation.cpp:1210–1233,
1349–1355,1424–1430,1458–1464 at 6504a3af. -/
def budgetObservation (cfg : NodeConfig) (priority : TxPriority) (elapsed : ElapsedObservation) :
    ValidationBudget :=
  let allowance := validationAllowance cfg priority elapsed
  if allowance < elapsed.inputs then .inputsExpired
  else if allowance < elapsed.relay then .relayExpired
  else if allowance < elapsed.block then .blockExpired
  else if allowance < elapsed.mandatory then .mandatoryExpired
  else .available

/-- P: #62's acceptance with the elapsed time as an explicit input. A request
without limits builds no timed source, so its budget is always available. The
durations are read from the request's effective configuration.
[SRC] src/validation.cpp:990–1006,1077–1078 at 6504a3af. -/
def acceptTimed (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (detector : DetectorObservation) (elapsed : ElapsedObservation) (request : TxRequest) :
    Mempool × TxOutcome :=
  let budget := if request.useLimits then
      budgetObservation (request.configOverride.getD cfg) request.priority elapsed
    else .available
  accept p utxo cfg { ctx with budget } lists oracle detector request

/-- P: receive a transaction message from a peer. The same inventory test
runs before validation: a known id is dropped with no validation and no answer; any other
transaction enters #62's acceptance as a high-priority limited request, timed
by the supplied elapsed observation.
[SRC] src/net/net_processing.cpp:3351–3408 at 6504a3af. -/
def receiveP2PTx (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (detector : DetectorObservation) (obs : InventoryObservation)
    (elapsed : ElapsedObservation) (tx : Tx) : Mempool × TxOutcome :=
  let p := observeTip p obs.tip
  if knownTx p obs (BsvScript.Sighash.txid tx) then (p, .suppressed)
  else acceptTimed p utxo cfg ctx lists oracle detector elapsed (p2pRequest tx ctx.now)

/-- P: the validator's next cycle takes the head of the queue, a request
lowered by a timeout among them, through the same timed acceptance. The
inventory test is not repeated for a queued request.
[SRC] src/txn_validator.cpp:359–438,459–471 at 6504a3af. -/
def revalidateTimed (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (detector : DetectorObservation) (elapsed : ElapsedObservation) : Mempool × Option TxOutcome :=
  match p.pending with
  | [] => (p, none)
  | work :: rest =>
    let (pool, outcome) :=
      acceptTimed { p with pending := rest } utxo cfg ctx lists oracle detector elapsed work.request
    (pool, some outcome)

/-! ## Nondeterminism recorded as such -/

/-- Whether an observation may be judged against the machine. A non-judging
observation is recorded with its reason and never counted as agreement or
divergence (DESIGN-S6 §4.5, §5.1). -/
inductive Judgment where
  | judging
  | nonJudging (reason : String)
  deriving DecidableEq, Repr

/-- Whether the outcome of one validation depends on the node's validation
clock. A limited request is validated under a timed cancellation source on the
CPU clock or the steady clock, whether its budget expires or not, so its
outcome is clock-dependent when the firing of some poll would change it. An
unlimited request builds no timed source, and an outcome that no poll's firing
changes (a refusal before the polls, the deferral at the nonstandard-input
guard) is clock-free. The classification is distinct from the budget's value.
[SRC] src/validation.cpp:990–1006,1077–1078,1210–1233, src/taskcancellation.h:155–164
and src/init.cpp:2890–2895 at 6504a3af. -/
inductive ClockDependence where
  | clockFree
  | clockDependent
  deriving DecidableEq, Repr

/-- Two classifications of one step: clock-dependent when either is. -/
def ClockDependence.join : ClockDependence → ClockDependence → ClockDependence
  | .clockFree, d => d
  | .clockDependent, _ => .clockDependent

/-- The four expired budget observations, one per poll. -/
def expiredBudgets : List ValidationBudget :=
  [.inputsExpired, .relayExpired, .blockExpired, .mandatoryExpired]

/-- P: the classification read off the outcome under every budget observation:
a limited request whose outcome under some expired observation differs from
its outcome under the available one is clock-dependent; every other request is
clock-free.
[SRC] src/validation.cpp:990–1006,1210–1233,1349–1355,1424–1430,1458–1464 at 6504a3af. -/
def clockDependence (request : TxRequest) (run : ValidationBudget → TxOutcome) : ClockDependence :=
  if request.useLimits && expiredBudgets.any (fun budget => run budget != run .available) then
    .clockDependent
  else .clockFree

/-- P: the classification of one acceptance.
[SRC] src/validation.cpp:990–1006 at 6504a3af. -/
def acceptClockDependence (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (detector : DetectorObservation) (request : TxRequest) : ClockDependence :=
  clockDependence request fun budget =>
    (accept p utxo cfg { ctx with budget } lists oracle detector request).2

/-- P: the classification of a peer's transaction message: a known id is
dropped before validation, clock-free; any other id is classified as the
acceptance `receiveP2PTx` runs.
[SRC] src/net/net_processing.cpp:3351–3408 at 6504a3af. -/
def receiveP2PTxClockDependence (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (detector : DetectorObservation) (obs : InventoryObservation) (tx : Tx) : ClockDependence :=
  let p := observeTip p obs.tip
  if knownTx p obs (BsvScript.Sighash.txid tx) then .clockFree
  else acceptClockDependence p utxo cfg ctx lists oracle detector (p2pRequest tx ctx.now)

/-- P: the classification of the validator's next cycle, the acceptance
`revalidateTimed` runs.
[SRC] src/txn_validator.cpp:359–438,459–471 at 6504a3af. -/
def revalidateClockDependence (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (detector : DetectorObservation) : ClockDependence :=
  match p.pending with
  | [] => .clockFree
  | work :: rest =>
    acceptClockDependence { p with pending := rest } utxo cfg ctx lists oracle detector work.request

/-- P: a cell whose outcome the node's validation clock decides is
non-judging, on an available budget as on an expired one; a clock-free cell is
judged, whatever budget observation it carries. The budget names the reason.
[SRC] src/txn_validation_config.h:36–37, src/init.cpp:2890–2895,
src/validation.cpp:990–1006 and src/taskcancellation.h:155–164 at 6504a3af. -/
def budgetJudgment (dependence : ClockDependence) (budget : ValidationBudget) : Judgment :=
  match dependence with
  | .clockFree => .judging
  | .clockDependent => .nonJudging (match budget with
    | .available => "a limited validation timed by the node's validation clock, no expiry"
    | _ => "time-budget expiry under the node's validation clock")

/-- P: one rolling filter's reading is judged only inside its wipe-free
regime and without a declared false positive for the id.
[SRC] src/bloom.cpp:265–281 and src/bloom.h:112–118 at 6504a3af. -/
def filterJudgment (f : RejectFilter) (falsePositive : TxId → Bool) (id : TxId) : Judgment :=
  if !f.wipeFree then .nonJudging "the rolling filter may have wiped a generation"
  else if falsePositive id && !f.contains id then
    .nonJudging "a bloom false positive, not an inserted id"
  else .judging

/-- P: an inventory test reads two rolling filters, the reject filter and the
separate filter of recently removed held transactions. Its reading is judged
only when both are exact after the lazy reset: each inside its own wipe-free
regime (180,000 and 15,000 insertions at the census defaults) and neither with
a declared false positive for the id. Otherwise it is non-judging.
[SRC] src/net/net_processing.cpp:930–961, src/time_locked_mempool.h:209–214,
src/time_locked_mempool.cpp:217–221,481–510 and src/bloom.cpp:222–225,265–281
at 6504a3af. -/
def inventoryJudgment (p : Mempool) (obs : InventoryObservation) (id : TxId) : Judgment :=
  match filterJudgment (observeTip p obs.tip).recentRejects obs.filterFalsePositive id with
  | .judging =>
    filterJudgment (observeTip p obs.tip).nonFinalRecentlyRemoved obs.removedFalsePositive id
  | reason => reason

end BsvChain
