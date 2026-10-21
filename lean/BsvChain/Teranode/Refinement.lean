import BsvChain.Teranode.Lifetimes
import BsvChain.Teranode.Chain
import BsvChain.Teranode.Alert
import BsvChain.Teranode.Spend
import BsvChain.Teranode.Subtree
import BsvChain.Teranode.Sentinel
import BsvChain.Teranode.Bridge
import BsvChain.Views.Status
import BsvChain.Views.Wire.EF
import BsvChain.Depth
import BsvChain.Merkle

/-!
# The refinement relation: Teranode's state as the components model it onto the reference machine (#88)

[M] 2026-10-15 (#88). S8's keystone: one relation from Teranode's state as the
components model it (the fields #97's contract reads marked) to the reference machine's state and #58's derived
status, the statement of each Teranode transition as a stutter, a named divergence or an owed simulation, and one
obligation per row of #87's module map (`corpus/teranode/map.json`, rendered as `spec/teranode-map.md`).
[M] 2026-10-17 (#88's close): the three measured legs (#92, #93, #94) and #140's soft freeze read in as the
`Divergence`s and the legs' witnesses, the transitions accounted per family, the list re-cut to six kinds
and emitted as `corpus/teranode/obligations.json`, rendered as section 5 of `spec/node-client-contract.md`.

The second oracle is Teranode v0.16.0 at `4edb60a40c6628ff0ef60231c2628efd7103fde5`; the reference is
bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b` (`docs/PROVENANCE.md` §1a) [SRC]. Every field of
`Obs` below cites the Teranode source that fills it, says whether #97's contract
(`docs/CONFORMANCE-TERANODE-OBSERVATION.md`) reads it, and names the reference observation it answers, at the two
pins.

**The relation.** `Obs` assembles the components' states: the UTXO store's master records with their marks
(#92's `Lifetimes.Record`), the blocks table and its best header (#93's `Chain.Row`, `Chain.bestRow`), the
blocks the blockchain service calls current, block assembly's transactions, the spenders the asset route
names, the runner's journals, the FSM state (#93), the alert-written output store and ban list (#94), and the
Kafka messages. Of these, #97's contract reads `rows`, `current`, `assembly`, the records' blocks, the spenders
and `fsm`; the records' marks, `alert`, `bans` and `events` are internal, read by no surface (#97 §0, §4, F6);
`journal` and `refused` are the runner's. `observe` is #74's derive (`docs/CONFORMANCE-TERANODE-MACHINE.md`
section 5) as a function onto #74's `Views.TeranodeState`, and it reads the contract's fields and the runner's two journals (`journal`, `refused`), never the internal ones;
`abstractStatus` reads it back onto #58's `Status` through `Views.teranodeRead`. `Refines o m` is the
conjunction of `StatusRefines` (per transaction, #74's column `Views.teranodeState` of the reference's status is
the observed state, except on `orphan`, the recorded no-function cell) and `ChainRefines` (the correspondence of
the two candidate sets that #93's bridge theorems take as hypotheses, `Chain.Validated`, the current-chain read
agreeing with the rows' ancestry, and the FSM in RUNNING, the precondition of every observation: #93's
`floater_invalidated_only_running`, #96 row `rl.fsm`, #97 §6 `fsm()`). `cover`, `back` and `validated` are
assumed by the relation; #93's hand-off ("#88 constructs it") stays owed on the Lean side. The base case holds:
`refines_empty` relates the empty states (no block on either side); the genesis row's form is owed (the Lean semantics), since
the spec defines no genesis `StatusState`. The frozen lists relate through `FrozenRefinesAt` (#94's projection),
outside `Refines`.

**The transitions** (section 9's `accounts`, one per family of `Family`; `accounts_families`). Every store
transition of one record but the block-mined one keeps `observe` (`record_step_stutters`): it maps to the
reference's identity, a stutter. The FSM's events that keep RUNNING, the ban list, the alert's store and a Kafka
publication are stutters of the status (`fsm_stutters`, `ban_stutters`, `alert_stutters`, `event_stutters`), and
so is the pruner's delete under the runner's journal of blocks (`prune_stutters`). A stutter keeps `Refines` with
the reference unchanged (`refines_of_stutter`); simulations compose (`Simulates.comp`), so any run of alert
writes, bans and Kafka publications keeps the relation (`stutter_run_simulates`) and #93's work agreement
survives it (`stutter_run_best_work`); an alert fund that freezes keeps `Refines` and leaves the frozen
projection agreeing (`alert_freeze_keeps_relation`, from #94's `freeze_agrees`). An FSM event out of RUNNING
suspends observation (`fsm_exit_suspends`: no reference state is related after it); the relation's return at the
re-entry to RUNNING is owed (the Lean semantics). No transition that moves the status is proven to simulate a reference
transition at this commit: the connection (`connectSimulates`), the reorg's moveBack, moveForward and reset
(`reorgSimulates`), the assembler's drop of a conflicting transaction (`conflictDropSimulates`) and the
alert-driven invalidate (`Alert.InvalidationRefines`) are owed to the Lean semantics, each naming the reference's step
(`refActivate`, `BsvChain.activateBestChain` with its context, lists, oracle and fuel) and taking Teranode's
step as a parameter: named, NOT stated. Five families leave the relation by a divergence
(`departs_carry_divergence`): the reconsider of a descendant (`Divergence.reconsiderDescendant`), the block
spending a frozen output (`Divergence.softFreezeHoldLapse`, the one chain split), the reference's expiry and its
eviction (`Divergence.unminedExpiry`, `Divergence.poolEviction`), and the alert store's reassign
(`Divergence.alertReassign`: the reassign write is the divergence itself, so no theorem says its frozen projection
agrees); the ban and the invalidate carry the authority path's design rows (`Divergence.alertBan`,
`Divergence.alertInvalidate`); the block connection, owed, carries #92's premature-block design row
(`Divergence.prematureBlockParked`). The admission (`AcceptIsEarliestSeen`) is owed.

**The divergences** (section 8, [M] 2026-10-17; [M] 2026-10-18 for #92's premature-block row). `Divergence` has the ruled rows
(`softFreezeHoldLapse` #153; `alertInvalidate`, `alertBan` #154; `reconsiderDescendant`, `tipsListing` #155;
`poolEviction` on the ledger's `tl.pool-size`, ruled `gap`) and two rows classified as design under the
maintainers' framing rule of card Z8 (`alertReassign`, the store half's reassign row; `unminedExpiry`, #92's row b), their
class the maintainers' to confirm at the close; #92's premature-block row is a design row by the maintainers' ruling of
2026-10-17 23:5xZ (card Z10, `92: design`: `prematureBlockParked`, carried by the block connection's account): one
chain split (`softFreezeHoldLapse`, #140 and #153, consensus) and eight design rows, policy. Each carries its legs and their public counts (`Divergence.witnesses`), its model objects
(`Divergence.model`) and Teranode's reason cited before the difference (`Divergence.reason`). A witnessed
divergence's obligation is the stated `Divergence.WitnessedAt`, discharged by its legs (rule 4), never asserted.

**The obligation list** (section 10, `obligations`; `obligations_rows` proves its rows are `mapRows`, the map's
54 ids in its order; `chaincheck --refinement` checks `mapRows`, each row's issue and each row's kind against
the map's `mechanism` in `corpus/teranode/map.json`, every ledger row of `corpus/teranode/absences.json` against
the obligation of its `map_id`, every landed leg's record by its path, and `corpus/teranode/obligations.json`
against the list it emits). Each row points at exactly one obligation of one kind: `theorem` (the
agreement theorems, every name resolved by the elaborator, with their premises, the legs that measured the row agreeing,
the model witnesses of a divergence on the same row, and any half still owed), `witness` (a measured leg
agreeing, the harness the judge), `design` (an architecture decision of Teranode's, its divergence policy, the row keeping its rule's label: the
divergences of the legs and the ledger rows ruled by the maintainers' rule of 2026-10-15, with their reasons),
`chain-split` (the two nodes decide the same blocks differently, consensus), `report` (a `same` row, judged by
#95's per-release gate) and `open` (stated, the Lean objects it names, its owner, the legs that measured part of
it). Every obligation carries its rule-1 label and names the ledger rows keyed to its row, whatever its kind.

Counts [M] (read from `obligations`; `kind_counts`): 54 rows; 11 theorem (5 of them also carrying model
witnesses), 1 witness, 18 design, 1 chain-split, 10 report (#95), 13 open; 6 owed halves on theorem and design rows; 19 ledger rows, 17 on design rows, 1 on the
chain-split row, 1 on a theorem row, all 19 ruled by the maintainers. [M] 2026-10-18: #98's theorem half
(`lean/BsvChain/Teranode/Bridge.lean`) discharged `tx-relay` and `reject-filter` as theorem rows and gave the
`orphans` design row its supporting theorems; each keeps the bridge's measured half owed to #98's bridge leg. The
bridge's 16 design divergences are `Bridge.BridgeDivergence`, outside the list's `Divergence`, three of them
(`resubmitReannounced`, `feeFilterBypassed`, `rejectFlattened`) named by the rows' model witnesses; the block road
(`Bridge.bridge_block_accepted`) is named on the `wire-block` design row, its horizon measured (the tips re-agree
unaided, `docs/records/20261018-145427-s8-98-teranode-bridge-horizon2-s4b.md`).

Kinds (rule 1): every relation here is a view onto the reference's status, never a rule of validity; the
settings the components read (retentions, optimistic mining, the alert's authority) are policy, at their
defaults in the components' docstrings: #93's in `docs/PARAMETERS.md` §8.9, #94's in §8.10. #92's retention and
pruner switches are in `Lifetimes.lean`'s docstring, with no PARAMETERS section yet (the harness's). The two witnesses
this module adds read the reference's `excessiveBlockSize` (consensus, node-configurable) and `assumeValid`
(policy) as parameters, both in `docs/PARAMETERS.md` §8.2 with their defaults; Teranode's `excessiveblocksize`
is a parameter at its default 4294967296 (`settings/settings.go:104`), and its checkpoint skip reads no setting.
-/

namespace BsvChain.Teranode.Refinement
open BsvChain BsvScript.Tx BsvScript.Numbers

/-! ## 1. Teranode's state as the components model it -/

/-- The Kafka topics of `settings/settings.go:137-161` (the topic names and their configuration URLs) at
4edb60a4 [SRC], the ten #97 maps. The reference has none (#96 row `rl.kafka`); its ZMQ topics are
`src/zmq/zmqpublishnotifier.cpp` at 6504a3af, written as `BsvChain.Views.Events.Topic`. -/
inductive KafkaTopic where
  | blocks | blocksFinal | invalidBlocks | invalidSubtrees | legacyInv
  | rejectedTx | subtrees | txMeta | validatorTxs | txPolicyRejected
  deriving DecidableEq, Repr

/-- One Kafka message as the model keeps it: its topic and its key (a block, subtree or transaction hash).
On the instance of record the broker is in-process and not readable from outside
(`docs/CONFORMANCE-TERANODE-OBSERVATION.md` section 0). -/
structure KafkaEvent where
  topic : KafkaTopic
  key : Bytes
  deriving DecidableEq, Repr

/-- Teranode's state as the components model it, with the fields #97's contract reads marked. `ι` is the block
hash's type of #93's rows. Each field: its Teranode source [SRC] 4edb60a4, whether a surface reads it, and the
reference observation it answers [SRC] 6504a3af.
* `records`: the UTXO store's master record of a transaction with its lifetime marks (#92's `Record`). The
  contract reads its blocks only: the asset route `txmeta` (`services/asset/httpimpl/GetTransactionMeta.go:94`)
  answers `blockIDs` (`:218`; `stores/utxo/meta/data.go:40` `BlockIDs`). The marks (`:61-64` `UnminedSince`,
  `:77` `Conflicting`, `:83` `Locked`) are internal, on no route (the response `GetTransactionMeta.go:214-228`;
  #97 §0, §4 row 2, F6). The reference's pool entry and coins (`src/txmempool.h:421`, `CTxMemPool`).
* `rows` (a contract read, `tip()`, `block(at)`): the blocks table (#93's `Row`), its best header the query
  `stores/blockchain/sql/GetBestBlockHeader.go:134-135` served at `services/blockchain/Server.go:1679`; the
  reference's header tree and `FindMostWorkChain` (`src/validation.cpp:4413`).
* `current` (a contract read): the block IDs the blockchain service calls current (`CheckBlockIsInCurrentChain`,
  `services/blockchain/Server.go:1705`); the reference's `chainActive` (`src/rpc/blockchain.cpp:79-90`).
* `assembly` (a contract read): block assembly's transaction hashes less the coinbase placeholder
  (`getrawmempool`, `services/rpc/handlers.go:1353`); the reference's `getrawmempool` (`src/rpc/blockchain.cpp:440`).
* `inputSpenders` (a contract read, `utxos`): per transaction, the spenders the asset route names for the
  outputs its inputs spend (`services/asset/httpimpl/GetUTXOsByTXID.go:40-46`); the reference's `gettxout`
  (`src/rpc/blockchain.cpp:1923`) and the spender's body.
* `journal` (the runner's): the runner's journal of each watched transaction's blocks, kept because an
  invalidation removes the record's entry (`stores/utxo/aerospike/teranode.lua:584-606`); the reference keeps
  every body.
* `refused` (the runner's): the runner's journal of refusals, the RPC's -25 (`services/rpc/handlers.go:926-930`);
  the reference's rejection reasons (`src/rpc/rawtransaction.cpp:1636-1650`).
* `fsm` (a contract read, gRPC `GetFSMCurrentState`, #97 §1 and §6 `fsm()`): the blockchain service's FSM state
  (#93's `FSMState`, its transition table `services/blockchain/fsm.go:17-42`); the reference has none (#96 row
  `rl.fsm`).
* `alert`, `bans` (internal, read by no surface): the alert-written output store and ban list (#94's `Store`,
  `BanList`; written by `FreezeUTXOs`, `stores/utxo/aerospike/alert_system.go:88`); the reference's operator
  lists through its RPC table (`src/rpc/frozentxo_rpc.cpp:897-915`).
* `events` (internal on the instance of record: its Kafka is not readable from outside, #97 §0): the Kafka
  messages (#96 row `rl.kafka`).
A view, never a rule. -/
structure Obs (ι : Type) where
  records : TxId → Option Lifetimes.Record
  rows : List (Chain.Row ι)
  current : List Nat
  assembly : List TxId
  inputSpenders : TxId → List TxId
  journal : TxId → List Nat
  refused : List TxId
  fsm : Chain.FSMState
  alert : Alert.Store
  bans : Alert.BanList
  events : List KafkaEvent

variable {ι : Type}

/-- The block IDs that hold a transaction: its record's and the runner's journal's (#74's section 5: "a
block hash of the record or of the journal"). -/
def Obs.blocksOf (o : Obs ι) (id : TxId) : List Nat :=
  ((o.records id).map (·.blocks)).getD [] ++ o.journal id

/-! ## 2. The abstraction: #74's derive, then #58's status -/

/-- The greatest height of a stored block that holds the transaction and is current (the reference's
`activeHeight`, `BsvChain.activeHeight`). `holds id b` is the observed inclusion. -/
def activeHeightAt (holds : TxId → Nat → Bool) (rows : List (Chain.Row ι)) (current : List Nat)
    (id : TxId) : Option Nat :=
  ((rows.filter (fun r => current.contains r.id && holds id r.id)).map (·.height)).max?

/-- A stored block that holds the transaction and is not current. -/
def staleAt (holds : TxId → Nat → Bool) (rows : List (Chain.Row ι)) (current : List Nat) (id : TxId) : Bool :=
  rows.any (fun r => holds id r.id && !current.contains r.id)

/-- #74's derive over the observed data, section 3's clauses in their order (`harness/src/scenarios/teranode.rs`,
`derive`): mined on the current chain, listed by assembly, mined only off it, an input spent by another
transaction mined on it, refused, else no record. `heldNonFinal` and `orphan` have no Teranode state.
[SRC] `services/rpc/handlers.go:127-142,1353`, `services/asset/httpimpl/GetUTXOsByTXID.go:40-46` at 4edb60a4;
`src/rpc/blockchain.cpp:79-90` at 6504a3af. A view, never a rule. -/
def observeAt (holds : TxId → Nat → Bool) (rows : List (Chain.Row ι)) (current : List Nat)
    (assembly : List TxId) (inputSpenders : TxId → List TxId) (refused : List TxId) (id : TxId) :
    Views.TeranodeState :=
  match activeHeightAt holds rows current id with
  | some h => .minedOnCurrent h
  | none =>
    if assembly.contains id then .unmined
    else if staleAt holds rows current id then .minedOffCurrent
    else if (inputSpenders id).any (fun s => s != id && (activeHeightAt holds rows current s).isSome) then
      .spentByMinedOther
    else if refused.contains id then .refused
    else .noRecord

/-- The observed inclusion of a state. -/
def Obs.holds (o : Obs ι) (id : TxId) (b : Nat) : Bool := (o.blocksOf id).contains b

/-- The observed Teranode state of a transaction. A view, never a rule. -/
def observe (o : Obs ι) (id : TxId) : Views.TeranodeState :=
  observeAt o.holds o.rows o.current o.assembly o.inputSpenders o.refused id

/-- The abstraction onto #58's derived status: #74's reading back. A refusal has no `Status` here (its code
and words are Teranode's namespace). A view, never a rule. -/
def abstractStatus (o : Obs ι) (id : TxId) : Option Status := Views.teranodeRead (observe o id)

/-- [M] 2026-10-15: the abstraction is undefined exactly on a refusal: every other observed state has its
status. A view, never a rule. -/
theorem abstractStatus_none_iff (o : Obs ι) (id : TxId) :
    abstractStatus o id = none ↔ observe o id = .refused := by
  unfold abstractStatus
  cases observe o id <;> simp [Views.teranodeRead]

/-! ## 3. The relation -/

/-- Per transaction: #74's column of the reference's status is the observed state, on every status but
`orphan` (the recorded no-function cell, `Views.teranodeNoFunction`; #98's row `orphans`). The non-final hold
is #74's `refused` cell (#96 row `tl.nonfinal-pool`). A view, never a rule. -/
def StatusRefines (o : Obs ι) (m : StatusState) : Prop :=
  ∀ id, status m id ≠ .orphan → Views.teranodeState (status m id) = some (observe o id)

/-- [M] 2026-10-15, support for row `observation-rpc`: under the relation, off a refusal and off `orphan`, the
abstraction gives the reference's status exactly (from #74's `teranode_read_inverse`). It takes the
observation's agreement as its hypothesis; the row's differences are #97's contract (§4). A view, never a rule. -/
theorem refines_abstract (o : Obs ι) (m : StatusState) (h : StatusRefines o m) (id : TxId)
    (ho : status m id ≠ .orphan) (hr : observe o id ≠ .refused) :
    abstractStatus o id = some (status m id) :=
  Views.teranode_read_inverse _ _ (h id ho) hr

/-- [M] 2026-10-15, support for row `observation-rpc`: under the relation a Teranode refusal is the reference's
rejection or its non-final hold, the divergence of row `non-final-hold`. A view, never a rule. -/
theorem refines_refused (o : Obs ι) (m : StatusState) (h : StatusRefines o m) (id : TxId)
    (ho : status m id ≠ .orphan) (hr : observe o id = .refused) :
    (∃ c r, status m id = .rejected c r) ∨ status m id = .heldNonFinal := by
  have e := h id ho
  rw [hr] at e
  generalize status m id = st at e ho ⊢
  cases st <;> simp_all [Views.teranodeState]

/-- [M] 2026-10-15: under the relation a transaction observed mined on the current chain at height `n` has
the reference's status `minedActive n` (from #74's `teranode_mined_implies_active`). A view, never a rule. -/
theorem refines_mined (o : Obs ι) (m : StatusState) (h : StatusRefines o m) (id : TxId) (n : Nat)
    (ho : status m id ≠ .orphan) (hm : observe o id = .minedOnCurrent n) :
    status m id = .minedActive n :=
  Views.teranode_mined_implies_active _ _ (by rw [h id ho, hm])

variable [DecidableEq ι]

/-- The chain half: the correspondence of the reference's eligible candidates and Teranode's rows not marked
invalid that #93's bridge theorems take as hypotheses (`cover`, `back`), the reference's activation complete,
#93's optimistic-mining obligation `Validated`, the current-chain read agreeing with the rows' ancestry of the
best header (`Chain.OnLongestChain`), and the FSM in RUNNING (every observation's precondition: #93's
`floater_invalidated_only_running`, #96 row `rl.fsm`, #97 §6 `fsm()`). `cover`, `back` and `validated` are
assumed here, not constructed: #93's hand-off ("#88 constructs it") stays owed, S1.
[SRC] `stores/blockchain/sql/GetBestBlockHeader.go:134-135`, `services/blockchain/Server.go:1705`,
`services/blockchain/fsm.go:17-42` at 4edb60a4; `src/validation.cpp:4413` at 6504a3af. -/
structure ChainRefines (o : Obs ι) (s : ChainState) : Prop where
  complete : activationComplete s = true
  cover : ∀ x ∈ eligibleCandidates s, ∃ y ∈ o.rows, y.invalid = false ∧ y.work = x.work.toNat
  back : ∀ y ∈ o.rows, y.invalid = false → ∃ x ∈ eligibleCandidates s, x.work.toNat = y.work
  validated : Chain.Validated o.rows
  currentRead : ∀ r ∈ o.rows, (r.id ∈ o.current ↔ Chain.OnLongestChain o.rows r.hash)
  running : o.fsm = .RUNNING

/-- The relation: Teranode's state refines the reference's state and its derived status. -/
def Refines (o : Obs ι) (m : StatusState) : Prop := StatusRefines o m ∧ ChainRefines o m.chain

/-- The reference's empty state: no block, an empty pool and journal. -/
def emptyStatus : StatusState := { chain := {} }

/-- [M] 2026-10-15, the base case: a Teranode state with no row, nothing in assembly and no refusal, in
RUNNING, refines the empty reference state (no block, an empty pool and journal), where every transaction is
`unknown` on one side and has no record on the other. The genesis row's form (one row, `current` its id,
against the reference's genesis) is owed on the Lean side: the spec defines no genesis `StatusState`. -/
theorem refines_empty (o : Obs ι) (hrows : o.rows = []) (ha : o.assembly = []) (hr : o.refused = [])
    (hf : o.fsm = .RUNNING) : Refines o emptyStatus := by
  refine ⟨fun id _ => ?_, ⟨?_, ?_, ?_, ?_, ?_, hf⟩⟩
  · simp [emptyStatus, status, activeHeight, minedConflict, observe, observeAt, activeHeightAt, staleAt, hrows,
      ha, hr, Views.teranodeState]
  · rfl
  · intro x hx; simp [emptyStatus, eligibleCandidates] at hx
  · intro y hy; simp [hrows] at hy
  · intro y hy; simp [hrows] at hy
  · intro y hy; simp [hrows] at hy

/-- [M] 2026-10-15, row `chain-selection`: under the relation the reference's active tip is an eligible
index with the work of Teranode's best header (from #93's `active_work_agrees`, its correspondence assumed by
the relation). A state lemma: no step is in it. The tip itself can differ at equal work
(`Chain.tie_rules_differ`). -/
theorem refines_best_work (o : Obs ι) (s : ChainState) (h : ChainRefines o s) (tip : BitVec 256)
    (htip : s.active.getLast? = some tip) (t : Chain.Row ι) (ht : Chain.bestRow o.rows = some t) :
    ∃ best ∈ eligibleCandidates s, best.id = tip ∧ best.work.toNat = t.work :=
  Chain.active_work_agrees s h.complete tip htip o.rows t ht h.cover h.back

/-- [M] 2026-10-15: under the relation Teranode's best header is validated: no optimistically stored row
heads the chain (from #93's `Validated`). -/
theorem refines_best_validated (o : Obs ι) (s : ChainState) (h : ChainRefines o s) (t : Chain.Row ι)
    (ht : Chain.bestRow o.rows = some t) : t.pending = false :=
  h.validated t (Chain.best_maximal_work o.rows t ht).1

/-! ## 4. The transitions: stutters, the FSM's exit and the owed simulations -/

/-- [M] 2026-10-15: a state whose status reads, chain reads and FSM state agree with another's refines what
the other refines. -/
theorem refines_congr (o o' : Obs ι) (m : StatusState) (hobs : observe o' = observe o)
    (hrows : o'.rows = o.rows) (hcur : o'.current = o.current) (hfsm : o'.fsm = o.fsm) (h : Refines o m) :
    Refines o' m := by
  obtain ⟨hs, hc⟩ := h
  refine ⟨fun x ho => by rw [hobs]; exact hs x ho, ?_⟩
  obtain ⟨c1, c2, c3, c4, c5, c6⟩ := hc
  exact ⟨c1, by rw [hrows]; exact c2, by rw [hrows]; exact c3, by rw [hrows]; exact c4,
    by rw [hrows, hcur]; exact c5, by rw [hfsm]; exact c6⟩

/-- A Teranode transition simulates a reference transition: from every related pair, the two steps land in a
related pair. The form every owed transition is named in. -/
def Simulates (stepT : Obs ι → Obs ι) (stepR : StatusState → StatusState) : Prop :=
  ∀ o m, Refines o m → Refines (stepT o) (stepR m)

/-- [M] 2026-10-15: a Teranode transition that keeps the status reads, the chain reads and the FSM state
simulates the reference's identity: a stutter. -/
theorem refines_of_stutter (stepT : Obs ι → Obs ι) (hobs : ∀ o, observe (stepT o) = observe o)
    (hrows : ∀ o, (stepT o).rows = o.rows) (hcur : ∀ o, (stepT o).current = o.current)
    (hfsm : ∀ o, (stepT o).fsm = o.fsm) : Simulates stepT id :=
  fun o m h => refines_congr o (stepT o) m (hobs o) (hrows o) (hcur o) (hfsm o) h

/-- [M] 2026-10-15, row `node-fsm`: an FSM event (#93's `fire`) that keeps RUNNING is a stutter: the FSM gates
the services and is no transaction's state (`docs/CONFORMANCE-TERANODE-MACHINE.md` section 2; #96 row
`rl.fsm`). -/
theorem fsm_stutters (p : Bool) (e : Chain.FSMEvent) (hkeep : (Chain.fire p .RUNNING e).1 = .RUNNING) :
    Simulates (fun o : Obs ι => { o with fsm := (Chain.fire p o.fsm e).1 }) id := by
  intro o m h
  refine refines_congr o _ m rfl rfl rfl ?_ h
  show (Chain.fire p o.fsm e).1 = o.fsm
  rw [h.2.running]
  exact hkeep

/-- [M] 2026-10-15, row `node-fsm`: an FSM event out of RUNNING suspends observation: no reference state is
related to the state after it (#97 §6, the RUNNING precondition). The relation's return at the re-entry to
RUNNING is owed on the Lean side. -/
theorem fsm_exit_suspends (p : Bool) (e : Chain.FSMEvent) (o : Obs ι) (m : StatusState)
    (hrun : o.fsm = .RUNNING) (hexit : (Chain.fire p .RUNNING e).1 ≠ .RUNNING) :
    ¬ Refines { o with fsm := (Chain.fire p o.fsm e).1 } m := by
  intro h
  have hr := h.2.running
  rw [hrun] at hr
  exact hexit hr

/-- [M] 2026-10-15, row `freeze-confiscation`: an alert's store write is a stutter of the status and the
chain; it relates to the reference's lists through `FrozenRefinesAt`. The model keeps `alert` apart from
`records` and `inputSpenders`, while at the pin the alert writes the same record's UTXO bins that the `utxos`
route reads (`FreezeUTXOs` "Sets the spending transaction ID to FF...FF",
`stores/utxo/aerospike/alert_system.go:71-77,88`; `stores/utxo/aerospike/teranode.lua:713` `freeze`, `:870`
`reassign`; the route serves `Status` and `SpendingData`, `services/asset/httpimpl/GetUTXOsByTXID.go:41-46`).
The status reads stay unmoved: a frozen output's spending data is `FF…FF`
(`stores/utxo/aerospike/teranode.lua:234-245` `isFrozen`), never a transaction mined on the current chain, so `observeAt`'s
`spentByMinedOther` clause does not fire. A reassignment (`teranode.lua:870-948`) changes the output's hash and
spend height, not a spender. [SRC] 4edb60a4. -/
theorem alert_stutters (f : Alert.Store → Alert.Store) :
    Simulates (fun o : Obs ι => { o with alert := f o.alert }) id :=
  refines_of_stutter _ (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) (fun _ => rfl)

/-- [M] 2026-10-15: a ban or unban (#94's `teraBan`, `teraUnban`) is a stutter. -/
theorem ban_stutters (f : Alert.BanList → Alert.BanList) :
    Simulates (fun o : Obs ι => { o with bans := f o.bans }) id :=
  refines_of_stutter _ (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) (fun _ => rfl)

/-- [M] 2026-10-15, row `event-surface`: a Kafka publication is a stutter of the status: the topics carry no
state the reference's status reads (#96 rows `rl.kafka`, `tl.zmq-announce`, `tl.zmq-removal`). -/
theorem event_stutters (e : KafkaEvent) :
    Simulates (fun o : Obs ι => { o with events := e :: o.events }) id :=
  refines_of_stutter _ (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) (fun _ => rfl)

/-- Replace one transaction's master record. -/
def Obs.setRecord (o : Obs ι) (tx : TxId) (r : Option Lifetimes.Record) : Obs ι :=
  { o with records := fun x => if x = tx then r else o.records x }

omit [DecidableEq ι] in
/-- [M] 2026-10-15: the status reads depend on the records only through the blocks they hold. -/
theorem observe_of_holds (o o' : Obs ι) (hh : o'.holds = o.holds) (hrows : o'.rows = o.rows)
    (hcur : o'.current = o.current) (ha : o'.assembly = o.assembly)
    (hs : o'.inputSpenders = o.inputSpenders) (hr : o'.refused = o.refused) : observe o' = observe o := by
  funext x
  unfold observe
  rw [hh, hrows, hcur, ha, hs, hr]

omit [DecidableEq ι] in
/-- [M] 2026-10-15: replacing a record by one with the same blocks keeps every status read. -/
theorem setRecord_stutters (o : Obs ι) (tx : TxId) (r r' : Lifetimes.Record) (hrec : o.records tx = some r)
    (hb : r'.blocks = r.blocks) : observe (o.setRecord tx (some r')) = observe o := by
  refine observe_of_holds o (o.setRecord tx (some r')) ?_ rfl rfl rfl rfl rfl
  funext x b
  by_cases hx : x = tx
  · subst hx; simp [Obs.holds, Obs.blocksOf, Obs.setRecord, hrec, hb]
  · simp [Obs.holds, Obs.blocksOf, Obs.setRecord, hx]

/-- [M] 2026-10-15: no lifetime transition of #92 but `setMined` moves a record's blocks. -/
theorem setDAH_blocks (s : Lifetimes.StoreSettings) (r : Lifetimes.Record) (h : Nat) :
    (Lifetimes.setDAH s r h).blocks = r.blocks := by
  unfold Lifetimes.setDAH
  repeat' split
  all_goals rfl

/-- [M] 2026-10-15: every store transition of one record (#92's `Step`) keeps its blocks, or is the
block-mined transition `setMined`. -/
theorem step_blocks {s : Lifetimes.StoreSettings} {r r' : Lifetimes.Record} (hs : Lifetimes.Step s r r') :
    r'.blocks = r.blocks ∨ ∃ b bh c ol u, r' = Lifetimes.setMined s r b bh c ol u := by
  cases hs with
  | mined b bh c ol u => exact .inr ⟨b, bh, c, ol, u, rfl⟩
  | longest ol c =>
    left; unfold Lifetimes.markLongestChain; repeat' split
    all_goals rfl
  | conflicting v h => left; simp [Lifetimes.setConflictingUdf, setDAH_blocks]
  | locked => left; rfl
  | spent a h => left; simp [Lifetimes.spendOutputs, setDAH_blocks]
  | preserved h => left; unfold Lifetimes.preserve; split <;> rfl
  | expired h =>
    left; unfold Lifetimes.expirePreservation; repeat' split
    all_goals rfl

/-- [M] 2026-10-15, THE TRANSITION STATEMENT for the store's records: each lifetime transition of #92
(`setDAH`'s callers, the longest-chain mark, the conflicting and locked marks, a spend's all-spent test, a
preservation and its expiry) on a transaction's record is a stutter of the relation, the reference unmoved;
the one exception is `setMined`, the block's connection, which `connectSimulates` owes. The record's
conflicting mark is a stutter; the assembler's drop that accompanies it is `conflictDropSimulates`, owed. -/
theorem record_step_stutters {s : Lifetimes.StoreSettings} {r r' : Lifetimes.Record} (o : Obs ι) (tx : TxId)
    (hrec : o.records tx = some r) (hs : Lifetimes.Step s r r') :
    (∀ m, Refines o m → Refines (o.setRecord tx (some r')) m) ∨
      ∃ b bh c ol u, r' = Lifetimes.setMined s r b bh c ol u := by
  rcases step_blocks hs with hb | hm
  · exact .inl fun m h => refines_congr o _ m (setRecord_stutters o tx r r' hrec hb) rfl rfl rfl h
  · exact .inr hm

omit [DecidableEq ι] in
/-- [M] 2026-10-15, the record half of row `pruning`: the pruner's delete of a record (#92's `pruneDeletes`)
keeps every status read when the runner's journal holds the record's blocks (#74: the journal is kept for
exactly this, since the store forgets). By `prune_only_mined_or_conflicting` such a record is mined or
conflicting. The row's block-file half is owed. -/
theorem prune_stutters (o : Obs ι) (tx : TxId) (r : Lifetimes.Record) (hrec : o.records tx = some r)
    (hj : ∀ b ∈ r.blocks, b ∈ o.journal tx) : observe (o.setRecord tx none) = observe o := by
  refine observe_of_holds o (o.setRecord tx none) ?_ rfl rfl rfl rfl rfl
  funext x b
  by_cases hx : x = tx
  · subst hx
    simp [Obs.holds, Obs.blocksOf, Obs.setRecord, hrec]
    exact fun hm => hj b hm
  · simp [Obs.holds, Obs.blocksOf, Obs.setRecord, hx]

/-- The reference's step on the status state: `BsvChain.activateBestChain` with its context, lists, oracle and
fuel, from a state whose tree already holds the arriving block (its acceptance), the journal unmoved. Its
connection, disconnection, re-admission (`addToMempoolForReorg`) and the pool's removal of a block's conflicts
(`removeForBlock`) are its parts. [SRC] `src/validation.cpp:4561,4913-5130`, `src/txmempool.cpp:2330` at
6504a3af. -/
def refActivate (ctx : ChainContext) (lists : FrozenLists) (oracle : ScriptOracle) (fuel : Nat)
    (m : StatusState) : StatusState :=
  { m with chain := (activateBestChain m.chain ctx lists oracle fuel).1 }

/-- **Owed, row `block-connect`: named, NOT stated.** Teranode's block connection (the row stored, `setMined`
on every record of its body, the longest-chain marks, the current read moved) simulates the reference's
connection of the same block. The reference's step is `refActivate`; Teranode's is the parameter `connectT`,
its model owed with the row. [SRC] `services/blockvalidation/BlockValidation.go:1410`,
`stores/utxo/aerospike/teranode.lua:558-663` at 4edb60a4; `src/validation.cpp:4561` at 6504a3af. Owner S1. -/
def connectSimulates (connectT : Obs ι → Obs ι) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (fuel : Nat) : Prop :=
  Simulates connectT (refActivate ctx lists oracle fuel)

/-- **Owed, row `reorg`'s re-admission half: named, NOT stated.** Teranode's reorganization of `assembly`,
`current` and the longest-chain marks (the assembler's moveBack and moveForward, `SubtreeProcessor.Reorg`, and
its reset at a reorg of `CoinbaseMaturity` blocks or more above height 1000, `services/blockassembly/BlockAssembler.go:2225-2232`)
simulates the reference's disconnect and re-admit (`refActivate`, through `addToMempoolForReorg`). Teranode's
step is the parameter `reorgT`, its model owed. [SRC] 4edb60a4; `src/validation.cpp:4561`,
`src/txmempool.cpp:2330` at 6504a3af. Owner S1. -/
def reorgSimulates (reorgT : Obs ι → Obs ι) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (fuel : Nat) : Prop :=
  Simulates reorgT (refActivate ctx lists oracle fuel)

/-- **Owed: named, NOT stated.** The assembler's drop of a transaction that a connected block's spend
conflicts with (the record's conflicting mark is `record_step_stutters`' stutter; the drop moves `assembly`)
simulates the reference's removal of the block's conflicts from the pool (`removeForBlock` inside
`refActivate`). Teranode's step is the parameter `dropT`, its model owed. [SRC] 4edb60a4;
`src/txmempool.cpp:1091-1117` at 6504a3af. Owner S1. -/
def conflictDropSimulates (dropT : Obs ι → Obs ι) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (fuel : Nat) : Prop :=
  Simulates dropT (refActivate ctx lists oracle fuel)

/-! ## 5. The frozen lists -/

/-- The frozen-list half at one output and height: Teranode's projection of the alert-written store (#94's
`Store.project`) and the reference's lists (#70's `OperatorLists.project`) agree. Outside `Refines`. [SRC]
`stores/utxo/aerospike/alert_system.go:88` at 4edb60a4; `src/rpc/frozentxo_rpc.cpp:897-915` at 6504a3af. -/
def FrozenRefinesAt (o : Obs ι) (d : OperatorLists) (onBlock : Bool) (h : Nat) (p : OutPoint) : Prop :=
  o.alert.project.frozen onBlock h p = d.project.frozen onBlock h p

omit [DecidableEq ι] in
/-- [M] 2026-10-15, row `freeze-confiscation`: an alert fund that freezes (#94's `freeze_agrees`' premises)
leaves the frozen projection agreeing at its output and at every height of its interval, the reference's
`addToConsensusBlacklist` applied beside it. Outside `Refines`: no step of the relation is in it. -/
theorem alert_freeze_refines (H : Alert.UtxoHash) (parents : Alert.Parents) (o : Obs ι) (d : OperatorLists)
    (f : Alert.Fund) (sats : Nat) (script : Bytes) (u : Alert.Utxo) (h : Nat)
    (hparent : parents f.out = some (sats, script)) (hu : o.alert.utxo f.out = some u)
    (hhash : u.hash = H f.out sats script) (hslot : u.slot = .unspent ∨ u.slot = .frozen)
    (hfreeze : ¬ f.stop < (o.alert.height : Int)) (hstart : f.start ≤ (h : Int)) (hstop : (h : Int) < f.stop)
    (onBlock : Bool) :
    FrozenRefinesAt { o with alert := Alert.blacklistOne H parents o.alert f } (Alert.refBlacklistOne d f)
      onBlock h f.out := by
  obtain ⟨h1, h2⟩ := Alert.freeze_agrees H parents o.alert d f sats script u h hparent hu hhash hslot hfreeze
    hstart hstop onBlock
  unfold FrozenRefinesAt
  rw [h1, h2]

omit [DecidableEq ι] in
/-- [M] 2026-10-15, row `freeze-confiscation`: an alert fund that unfreezes (#94's `unfreeze_agrees`'
premises) leaves the frozen projection agreeing at its output at and past its stop. Outside `Refines`. -/
theorem alert_unfreeze_refines (H : Alert.UtxoHash) (parents : Alert.Parents) (o : Obs ι) (d : OperatorLists)
    (f : Alert.Fund) (sats : Nat) (script : Bytes) (u : Alert.Utxo) (h : Nat)
    (hparent : parents f.out = some (sats, script)) (hu : o.alert.utxo f.out = some u)
    (hhash : u.hash = H f.out sats script) (hslot : u.slot = .unspent ∨ u.slot = .frozen)
    (hunfreeze : f.stop < (o.alert.height : Int)) (hexp : f.expires = true)
    (hconf : ∀ x, d.frozenData f.out = some x → x.blacklist ≠ .confiscation)
    (hpast : f.stop ≤ (h : Int)) (onBlock : Bool) :
    FrozenRefinesAt { o with alert := Alert.blacklistOne H parents o.alert f } (Alert.refBlacklistOne d f)
      onBlock h f.out := by
  obtain ⟨h1, h2⟩ := Alert.unfreeze_agrees H parents o.alert d f sats script u h hparent hu hhash hslot
    hunfreeze hexp hconf hpast onBlock
  unfold FrozenRefinesAt
  rw [h1, h2]

/-! ## 6. The block's structure -/

/-- [M] 2026-10-15, support for row `block-structure`: a block with no subtree is its coinbase alone. -/
theorem flatLeaves_single (coinbase : Bytes) : flatLeaves coinbase [] = [coinbase] := rfl

/-- [M] 2026-10-15, support for row `block-structure`: Teranode's body (the coinbase and the subtrees, #89's
`flatLeaves`) has the coinbase at its head, the leading subtree's placeholder replaced.
[SRC] `model/Block.go:2720-2751` at 4edb60a4. -/
theorem flatLeaves_head (coinbase : Bytes) (lead : List Bytes) (rest : List (List Bytes)) :
    (flatLeaves coinbase (lead :: rest)).head? = some coinbase := by
  cases lead <;> rfl

/-- [M] 2026-10-15, support for row `block-structure`: after the coinbase, the transaction order is the
subtrees' concatenation (the leading subtree past its placeholder). -/
theorem flatLeaves_tail (coinbase x : Bytes) (lead : List Bytes) (rest : List (List Bytes)) :
    (flatLeaves coinbase ((x :: lead) :: rest)).tail = lead ++ rest.flatten := rfl

/-- [M] 2026-10-15, row `block-structure`: a reference block (`BsvChain.Block`, a header and a flat, ordered
list of transactions) whose transaction ids are Teranode's flat leaves of its coinbase and subtrees has that
coinbase's transaction at index 0. [SRC] `model/Block.go:95-100,2720-2751` at 4edb60a4;
`src/primitives/block.h:79` at 6504a3af. -/
theorem block_structure_refines (b : BsvChain.Block) (coinbase : Bytes) (subtrees : List (List Bytes))
    (h : b.transactions.map BsvScript.Sighash.txid = flatLeaves coinbase subtrees) :
    b.transactions.head?.map BsvScript.Sighash.txid = some coinbase := by
  rw [← List.head?_map, h]
  match subtrees with
  | [] => rfl
  | lead :: rest => exact flatLeaves_head coinbase lead rest

/-- [M] 2026-10-15, row `block-structure`: in such a block the transactions after the coinbase are the
subtrees' in their concatenated order (the leading subtree past its placeholder). [SRC] `model/Block.go:2720-2751`
at 4edb60a4; `src/primitives/block.h:79` at 6504a3af. -/
theorem block_order_refines (b : BsvChain.Block) (coinbase x : Bytes) (lead : List Bytes)
    (rest : List (List Bytes))
    (h : b.transactions.map BsvScript.Sighash.txid = flatLeaves coinbase ((x :: lead) :: rest)) :
    b.transactions.tail.map BsvScript.Sighash.txid = lead ++ rest.flatten := by
  rw [List.map_tail, h]; rfl

/-! ## 7. The two witnesses the map gives #88 -/

/-- Teranode's script skip on the legacy path, `quickValidationAllowed`
(`services/legacy/netsync/handle_block.go:655-665`): the chain parameters present, the block's header proven by
the checkpoint walk, and the height below the highest checkpoint (`model.BelowCheckpoint`,
`model/checkpoint.go:40-44`: a highest checkpoint exists, the height is not genesis and is at most it). Such a
block is validated with `WithSkipScriptValidation(true)` (`handle_block.go:1461`). No setting reads it.
[SRC] 4edb60a4. A view of the second oracle, never a rule. -/
def teraScriptsSkipped (hasParams headerProven : Bool) (highest height : Nat) : Bool :=
  hasParams && headerProven && (decide (0 < highest) && decide (0 < height) && decide (height ≤ highest))

/-- [M] 2026-10-15, row `validation-depth`, a witness: at `-assumevalid=0` (`assumeValid`, policy,
`docs/PARAMETERS.md` §8.2) the reference checks the scripts of every block it connects
(`scriptChecksRequired`, `src/validation.cpp:3482-3518` at 6504a3af), while Teranode's legacy path skips them
for a header-proven block at any height from 1 to its highest checkpoint, with no setting
(`teraScriptsSkipped`). Neither is an assumed-valid hash and a work floor on the other side. [D] until #66's
cut 2 drives it. -/
theorem validation_depth_differs (params : ChainParams) (cfg : NodeConfig) (tree : HeaderTree)
    (best : Option BlockIndex) (i : BlockIndex) (hav : cfg.assumeValid = 0) (highest height : Nat)
    (hpos : 0 < height) (hle : height ≤ highest) :
    scriptChecksRequired params cfg tree best i = true ∧ teraScriptsSkipped true true highest height = true := by
  refine ⟨by simp [scriptChecksRequired, hav], ?_⟩
  simp [teraScriptsSkipped]; omega

/-- Teranode's size decline, `excessiveBlockSizeDeclined` (`services/blockvalidation/Server.go:2681-2692`): a
positive configured `excessiveblocksize` (a parameter; its default 4294967296, `settings/settings.go:104`) and a
block larger than it. The caller returns `NewBlockPolicyDeclinedError` and never marks the hash invalid
(`services/blockvalidation/BlockValidation.go:1755-1766`). [SRC] 4edb60a4. A view of the second oracle, never a
rule. -/
def teraSizeDeclined (excessive : Int) (size : Nat) : Bool :=
  decide (0 < excessive) && decide ((size : Int) > excessive)

/-- [M] 2026-10-15, row `block-size`, a witness: a block over the reference's `excessiveBlockSize` (consensus,
node-configurable, `docs/PARAMETERS.md` §8.2) whose header passes is refused by `checkBlock` with
`bad-blk-length` and corruption not possible, so the reference marks the header failed
(`src/validation.cpp:5809-5815` at 6504a3af); Teranode declines the same size as policy and never marks the hash
(`teraSizeDeclined`). The merkle check is off here (`options.merkleRoot = false`) so the size clause is the
deciding one. [D] until #66's cut 2 drives it. -/
theorem block_size_differs (params : ChainParams) (cfg : NodeConfig) (b : BsvChain.Block) (height : Nat)
    (options : BlockCheckOptions) (hpow : checkBlockHeader params b.header options = .ok ())
    (hmr : options.merkleRoot = false) (hmax : options.maxBlockSize = true) (htx : b.transactions ≠ [])
    (hbig : b.encode.length > cfg.excessiveBlockSize) (excessive : Int) (hpos : 0 < excessive)
    (hsize : (b.encode.length : Int) > excessive) :
    (∃ r, checkBlock params cfg b height options = .error r ∧ r.reason = "bad-blk-length" ∧
      r.corruptionPossible = false) ∧ teraSizeDeclined excessive b.encode.length = true := by
  refine ⟨?_, by simp [teraSizeDeclined, hpos, hsize]⟩
  obtain ⟨cb, rest, hc⟩ : ∃ cb rest, b.transactions = cb :: rest := by
    cases h : b.transactions with
    | nil => exact absurd h htx
    | cons cb rest => exact ⟨cb, rest, rfl⟩
  unfold checkBlock
  simp only [hpow, hmr, hmax, hc, Except.mapError, bind, Except.bind, pure, Except.pure, throw, throwThe,
    MonadExceptOf.throw]
  simp only [Bool.false_eq_true, ↓reduceIte]
  split <;> simp_all

/-! ## 8. The measured legs and the divergences

[M] 2026-10-17 (#88's close, on the maintainers' plan of 2026-10-17 and their framing rule of
19:1xZ on card Z8: every difference read against Teranode's north star, scale without a protocol change; an
architecture decision is a DESIGN row with Teranode's reason cited, labeled policy; only a chain decision that
differs on the same blocks is a chain-split row). The legs' records are withheld from the public edition by name
and were not opened for this section: every count below is the public one, from the machine page
(`docs/CONFORMANCE-TERANODE-MACHINE.md` section 1) and the issues' closing comments. -/

/-- A measured leg of S8 on both nodes (the reference v1.2.3 and a Teranode v0.16.0 regtest instance side by
side): its issue, the branch it was measured on, its record (by name only), its public counts, and whether the record is on `main` at
this commit. -/
structure Leg where
  issue : String
  lane : String
  record : String
  counts : String
  landed : Bool
  deriving Repr

/-- #94's alert-path leg (2026-10-17): the chain and peer transitions driven; the store transitions'
agreement carried by #140's row and the theorems. -/
def legAlert : Leg :=
  ⟨"#94", "hz-94", "docs/records/20261017-170959-s4b-94-teranode-alert-path-s4b.md",
    "8 rows: 3 agree, 3 differ, 2 not run (the signed-alert gossip delivery, go-alert-system v0.1.17's drop)", true⟩

/-- #94's store half and #93's alert row (2026-10-17; on `main` at `661b75c2`): freeze,
unfreeze, a second freeze and an invalidate through the signed-alert sync stream, and the reassign RPC, beside the
reference's blacklist and invalidate RPCs. The counts as the #94 comment gives them (6240682985: 8 rows, agree 6, differ
2, not run 1 by name): the 8 rows are the rows run, the not-run row beside them. -/
def legStore : Leg :=
  ⟨"#94", "hz-94s", "docs/records/20261017-203139-s4b-94-teranode-store-half-s4b.md",
    "8 rows run: agree 6, differ 2; and 1 row not run by name (the alert gossip delivery), the #94 comment's counts", true⟩

/-- #93's chain-selection and reorg leg (2026-10-17). -/
def legChain : Leg :=
  ⟨"#93", "hz-93", "docs/records/20261017-180732-s4b-93-teranode-chain-reorg-s4b.md",
    "11 rows: 9 agree, 1 differ, 1 not run (the peer-blocks optimistic-mining opt-in)", true⟩

/-- #92's record-lifetimes leg (2026-10-17). -/
def legLifetimes : Leg :=
  ⟨"#92", "hz-92", "docs/records/20261017-192745-s4b-92-teranode-lifetimes-s4b.md",
    "26 rows: 23 agree, 3 differ, 0 not run", true⟩

/-- #140's soft-freeze row measured on both oracles (2026-10-16): the reference's run and the
Teranode projection of cut 2, read by `jq` fields under the quarantine rule. -/
def legSoftFreeze : Leg :=
  ⟨"#140", "ns-140", "docs/records/20261016-173411-s8-140-soft-freeze-reference-s3.json",
    "the row measured on both oracles (the ledger's `tl.soft-freeze` `measured`)", true⟩

/-- #152's step 2 (2026-10-17): the signer corpus submitted to a Teranode regtest instance beside
the reference. -/
def legSigner : Leg :=
  ⟨"#152", "hz-152b", "docs/records/20261017-031159-s4b-152-teranode-signer-chain-s4b.md",
    "1,860 slots signed: 1,850 agree, 0 differ, 10 apart on finality only", true⟩

/-- Where a divergence sits (rule 1): a `chainSplit` is a chain decision the two nodes make differently on the
same blocks (consensus); a `design` row is an architecture decision of Teranode's in the protocol's service,
its reason cited (policy). The maintainers' framing rule of 2026-10-17 19:1xZ (card Z8). -/
inductive DivergenceClass where
  | chainSplit
  | design
  deriving DecidableEq, Repr

/-- The rows where Teranode and the reference differ, from S8's measured legs. `Divergence` has the ruled rows
(`softFreezeHoldLapse` #153; `alertInvalidate`, `alertBan` #154; `reconsiderDescendant`, `tipsListing` #155;
`poolEviction` on the ledger's `tl.pool-size`, ruled `gap`) and two rows classified as design under the
maintainers' framing rule of card Z8 (`alertReassign`, the store half's reassign row; `unminedExpiry`, #92's row b), their
class the maintainers' to confirm at the close. The absence ledger's nineteen rulings
(2026-10-15, `ruling_rule` in `corpus/teranode/absences.json`) are named by id in the obligations' `ledger`,
not repeated here. #92's premature-block row (f4) is `prematureBlockParked`, a design row by the maintainers' ruling on
card Z10. -/
inductive Divergence where
  /-- **Chain split, consensus (#140, #153; #94's row c).** A block spending a consensus-frozen output: the
  reference holds it for its soft-freeze duration and then activates through it; Teranode refuses it and stays on
  its own tip. Two tips on the same blocks with no operator action pending. Counts: #94's leg 8 rows, 3 agree, 3
  differ, 2 not run; #140's row measured on both oracles. The operator list it reads is the third kind of the
  maintainers' ruling of 2026-10-05 (a block-validity mechanism driven by an operator's list). -/
  | softFreezeHoldLapse
  /-- **Design, policy (#154; #94's row e).** The operator's invalidate reaches Teranode by signed alert and
  the reference by RPC: who may act and how the action arrives, never what it does
  (`Alert.trust_root_changes_who_not_what`). Counts: #94's leg 8 rows, 3 agree, 3 differ, 2 not run. -/
  | alertInvalidate
  /-- **Design, policy (#154; #94's row f).** The peer ban reaches Teranode by signed alert and by an RPC
  (`setban`), the reference by RPC: the authority path differs, by the same trust root as
  `alertInvalidate`, and so does the ban's length (`Alert.ban_until_differs`). Counts: #94's leg 8 rows, 3 agree, 3 differ, 2 not run. -/
  | alertBan
  /-- **Design, policy (#94's store half, the reassign row; classified under the framing rule of
  card Z8, its class the maintainers' to confirm at the close).** Teranode's alert
  service reassigns a frozen output to a new key behind a 1,000-block gate, a node setting; the reference has no
  reassign (its old-script acceptance the control). Counts: #94's store half 8 rows run, agree 6, differ 2;
  1 row not run by name.
  Model: `Alert.reassign_gate`, `Alert.reassign_strands`. -/
  | alertReassign
  /-- **Design, policy (#155; #93's row e2).** Reconsidering a descendant of an invalidated block: the
  reference clears the ancestors and reorganises, Teranode waits for the invalidated block itself, after which
  both agree (row e3). Counts: #93's leg 11 rows, 9 agree, 1 differ, 1 not run; re-measured under the
  alert-driven invalidate in #94's store half (the difference stands). Model: `Chain.reconsider_descendant_differs`. -/
  | reconsiderDescendant
  /-- **Design, policy (#155; #93's row g).** A block the reference lists among its chain tips is absent from
  Teranode's listing; the chain decision agrees. Counts: #93's leg 11 rows, 9 agree, 1 differ, 1 not run. -/
  | tipsListing
  /-- **Design, policy (#92's row b; classified under the framing rule of card Z8, its class the
  maintainers' to confirm at the close).** An unmined transaction: the reference expires it after
  `-mempoolexpiry`; Teranode keeps its record. Counts: #92's leg 26 rows, 23 agree, 3 differ, 0 not run.
  Model: `Lifetimes.expiry_rules_differ`. -/
  | unminedExpiry
  /-- **Design, policy (#92's eviction row; the ledger's `tl.pool-size`, ruled `gap`).** The reference evicts
  by size and fee under `-maxmempool`; Teranode has no pool to evict from. Counts: #92's leg 26 rows, 23 agree,
  3 differ, 0 not run. -/
  | poolEviction
  /-- **Design, policy for the hold; the maturity rule itself consensus (#92's row f4; the maintainers' ruling on card Z10,
  2026-10-17 23:5xZ, `92: design`).** Teranode validates a block's spends at its UTXO store's spend gate
  (`stores/utxo/sql/sql.go:2477-2478` at `4edb60a4`) (the Aerospike store's twin:
  `stores/utxo/aerospike/teranode.lua:325-326` at `4edb60a4`) and has no block-context maturity check of its own at the pin,
  so a block spending a coinbase at depth 99 is parked as its best block with nothing built on it while the store's
  gate governs the spend; the reference refuses that block at its block-context check (`COINBASE_MATURITY = 100`,
  `src/consensus/consensus.h:75`; `bad-txns-premature-spend-of-coinbase`, `src/validation.cpp:2617-2625` at
  `6504a3af`). The chain-level consequence a client sees: for a window Teranode's best-tip answer names a block the
  reference refuses, until a valid branch overtakes it. Counts: #92's leg 26 rows, 23 agree, 3 differ, 0 not run;
  the row's window 4 s, 0 blocks built on the parked block, after which Teranode followed the reference's branch.
  The ruling is read under the framing rule of card Z8 (Teranode's reason before the
  difference). Model: `Lifetimes.coinbase_maturity_agrees` (the rule agrees in the mempool), the block half the
  leg alone. -/
  | prematureBlockParked
  deriving DecidableEq, Repr

/-- Every divergence, in the constructors' order. -/
def Divergence.all : List Divergence :=
  [.softFreezeHoldLapse, .alertInvalidate, .alertBan, .alertReassign, .reconsiderDescendant, .tipsListing,
   .unminedExpiry, .poolEviction, .prematureBlockParked]

/-- [M] 2026-10-17: `Divergence.all` lists every constructor. -/
theorem Divergence.mem_all (d : Divergence) : d ∈ Divergence.all := by
  cases d <;> simp [Divergence.all]

/-- The divergence's class. -/
def Divergence.cls : Divergence → DivergenceClass
  | .softFreezeHoldLapse => .chainSplit
  | _ => .design

/-- The rule-1 label: a chain split is consensus, a design row policy. -/
def Divergence.label (d : Divergence) : String :=
  match d.cls with
  | .chainSplit => "consensus"
  | .design => "policy"

/-- The rule-1 label of the rule the divergence's row states. A design row's hold is policy while the rule it sits
on may be consensus: #92's premature-block row, the maturity rule consensus and the hold policy (the maintainers' ruling on
card Z10). Every other divergence's rule carries its own label. -/
def Divergence.ruleLabel : Divergence → String
  | .prematureBlockParked => "consensus"
  | d => d.label

/-- [M] 2026-10-18: the premature-block row is the one divergence whose rule's label differs from its own. -/
theorem Divergence.ruleLabel_differs :
    Divergence.all.filter (fun d => d.ruleLabel != d.label) = [.prematureBlockParked] := by decide

/-- The divergence's id in `corpus/teranode/obligations.json`. -/
def Divergence.id : Divergence → String
  | .softFreezeHoldLapse => "soft-freeze-hold-lapse"
  | .alertInvalidate => "alert-invalidate"
  | .alertBan => "alert-ban"
  | .alertReassign => "alert-reassign"
  | .reconsiderDescendant => "reconsider-descendant"
  | .tipsListing => "tips-listing"
  | .unminedExpiry => "unmined-expiry"
  | .poolEviction => "pool-eviction"
  | .prematureBlockParked => "premature-block-parked"

/-- The issue that carries the divergence. -/
def Divergence.issue : Divergence → String
  | .softFreezeHoldLapse => "#153"
  | .alertInvalidate | .alertBan => "#154"
  | .alertReassign => "#94"
  | .reconsiderDescendant | .tipsListing => "#155"
  | .unminedExpiry | .poolEviction | .prematureBlockParked => "#92"

/-- The legs that witness the divergence, each with the leg's row. -/
def Divergence.witnesses : Divergence → List (Leg × String)
  | .softFreezeHoldLapse => [(legSoftFreeze, "tl.soft-freeze (during the hold)"),
      (legAlert, "row c (after the reference's hold lapses)")]
  | .alertInvalidate => [(legAlert, "row e")]
  | .alertBan => [(legAlert, "row f")]
  | .alertReassign => [(legStore, "the reassign row")]
  | .reconsiderDescendant => [(legChain, "row e2 (row e3 restores agreement)"),
      (legStore, "row e2 under the alert-driven invalidate")]
  | .tipsListing => [(legChain, "row g")]
  | .unminedExpiry => [(legLifetimes, "row b")]
  | .poolEviction => [(legLifetimes, "the eviction row")]
  | .prematureBlockParked => [(legLifetimes, "row f4 (row a, the mempool's maturity, agrees)")]

/-- The model objects that state the divergence in the components, each resolved by the elaborator. -/
def Divergence.model : Divergence → List Lean.Name
  | .softFreezeHoldLapse => [``BsvChain.freezeBlockIndex, ``Alert.freeze_spent_refused]
  | .alertInvalidate => [``Alert.trust_root_changes_who_not_what, ``Alert.InvalidationRefines]
  | .alertBan => [``Alert.trust_root_changes_who_not_what, ``ban_stutters, ``Alert.ban_until_differs]
  | .alertReassign => [``Alert.reassign_gate, ``Alert.reassign_strands]
  | .reconsiderDescendant => [``Chain.reconsider_descendant_differs]
  | .tipsListing => []
  | .unminedExpiry => [``Lifetimes.expiry_rules_differ]
  | .poolEviction => []
  | .prematureBlockParked => [``Lifetimes.coinbase_maturity_agrees, ``Lifetimes.defaults_maturity_agree]

/-- Teranode's reason, cited at `4edb60a4`, then the reference's side at `6504a3af`, then what the leg
measured (counts only). -/
def Divergence.reason : Divergence → String
  | .softFreezeHoldLapse =>
    "Teranode's freeze path has no hold state by design: the alert service freezes the output in the UTXO store and a block spending it is refused at the store's spend (stores/utxo/aerospike/spend.go:1103-1107), its best header chosen among blocks not marked invalid (stores/blockchain/sql/GetBestBlockHeader.go:134-135) [SRC]. The reference holds such a block out of its best chain for -softconsensusfreezeduration blocks (a setting, default 3, src/validation.h:219; the trigger src/validation.cpp:3402-3406; the hold src/block_index.h:283-285) [SRC] and then activates through it. The chain decision differs on the same blocks once the hold lapses"
  | .alertInvalidate =>
    "A node built as many services across many machines takes the operator's invalidate from one signed channel, the alert service (services/alert/node.go:160-176 InvalidateBlock; the keys settings/settings.go:198,202) [SRC], beside its RPC handler (services/rpc/handlers.go:1862, #85's contract); the reference takes it from the RPC credential's holder (src/rpc/blockchain.cpp:2732-2768) [SRC]. The authority is a node setting (docs/PARAMETERS.md section 8.10); the action is the same whichever authority admits it"
  | .alertBan =>
    "The peer ban arrives at Teranode by the same signed channel (services/alert/node.go:189-216 BanPeer), beside its RPC handler (`setban`, services/rpc/handlers.go:2447, mapped at services/rpc/Server.go:208) [SRC]; the reference bans by RPC (`setban`, `src/rpc/net.cpp:669-757` at `6504a3af`) [SRC]. The authority is a node setting (docs/PARAMETERS.md section 8.10); the trust root changes who, never what (`trust_root_changes_who_not_what`), but the ban's length differs: 100 years by the alert against the reference's `-bantime`, a day by default (`ban_until_differs`), and the reference's ban only lengthens where Teranode's overwrites"
  | .alertReassign =>
    "Teranode's alert service confiscates by reassignment: a frozen output is given a new locking script (stores/utxo/aerospike/alert_system.go:233-270 ReAssignUTXO, teranode.lua:870-958) and stays unspendable for utxostore_reassignedUtxoSpendableAfterBlocks blocks (a node setting, default 1000, settings/settings.go:528; docs/PARAMETERS.md section 8.10) [SRC]; the reference has no reassign and confiscates by a whitelisted confiscation transaction instead (#70; the row rl.alert-service)"
  | .reconsiderDescendant =>
    "Teranode marks blocks invalid in its blocks table and its reconsider clears the block it names (services/rpc/handlers.go:1919-2028, services/blockvalidation/BlockValidation.go:2001-2042) [SRC]; the reference's reconsiderblock clears the failure marks of the named block's ancestors and re-activates (src/rpc/blockchain.cpp:2770-2818, src/validation.cpp:4913-5126) [SRC]. Reconsidering the invalidated block itself brings both to the same tip"
  | .tipsListing =>
    "Teranode's getchaintips (services/rpc/handlers.go:2928) lists the tips its blocks table reports (services/blockchain/Server.go:1747 GetChainTips) [SRC]; the reference walks its block index (src/rpc/blockchain.cpp:2497-2615) [SRC]. The chain decision agrees; the listing's membership differs"
  | .unminedExpiry =>
    "Teranode has no traditional mempool by design (docs/topics/architecture/teranode-overall-system-design.md:174) [LIT]: an unmined transaction is a store record stamped UnminedSince (stores/utxo/meta/data.go:61) [SRC] and kept, the pruner deleting only mined or conflicting records (Lifetimes.prune_only_mined_or_conflicting); the reference expires a pool entry after -mempoolexpiry (336 hours, policy; src/txmempool.cpp:2201-2220, src/config.cpp:87) [SRC]"
  | .poolEviction =>
    "Teranode has no traditional mempool by design (docs/topics/architecture/teranode-overall-system-design.md:174) [LIT], so there is no pool to bound or trim; the reference trims its pool by size and fee under -maxmempool (policy; `TrimToSize`, `src/txmempool.cpp:2704-2799` at `6504a3af`) [SRC]"
  | .prematureBlockParked =>
    "Teranode validates a block's spends where the outputs live, at its UTXO store's spend gate (stores/utxo/sql/sql.go:2477-2478 at `4edb60a4`) (the Aerospike store's twin: stores/utxo/aerospike/teranode.lua:325-326 at `4edb60a4`) [SRC], and has no block-context maturity check of its own at the pin, so a block spending a coinbase below maturity can stand as its best block, parked with nothing built on it, while the store's gate governs the spend; the hold is policy. The reference refuses the same block at its block-context check: a coinbase output matures at COINBASE_MATURITY = 100 blocks (src/consensus/consensus.h:75 at `6504a3af`, consensus), each input checked in the block's context (`bad-txns-premature-spend-of-coinbase`, src/validation.cpp:2617-2625 at `6504a3af`) [SRC]. The chain-level consequence a client sees: for a window Teranode's best-tip answer names a block the reference refuses, until a valid branch overtakes it (measured: 4 s, 0 blocks built on the parked block, then the reference's branch followed); the maturity rule itself agrees in the mempool at depths 98 to 101 and across the reorg (Lifetimes.coinbase_maturity_agrees). The reading of record (docs/CONFORMANCE-TERANODE-MACHINE.md section 1): a design row"

/-- [M] 2026-10-17: a divergence is a chain split exactly when its label is consensus. -/
theorem Divergence.chainSplit_iff_consensus (d : Divergence) :
    d.cls = .chainSplit ↔ d.label = "consensus" := by
  cases d <;> simp [Divergence.cls, Divergence.label]

/-- [M] 2026-10-17: the soft freeze's hold lapse is the one chain-split row the legs ruled. -/
theorem Divergence.chain_splits :
    Divergence.all.filter (fun d => d.cls == .chainSplit) = [.softFreezeHoldLapse] := by decide

/-- **The obligation a witnessed divergence carries, stated, never asserted.** Over the leg's recorded answers
on its row (`reference d`, `teranode d`: each node's answer as the record's JSON names it), the two differ. The
measured legs of `Divergence.witnesses` discharge it (rule 4: the harness is the judge); no theorem that the
relation holds on a recorded row is owed. -/
def Divergence.WitnessedAt (d : Divergence) (reference teranode : Divergence → String) : Prop :=
  reference d ≠ teranode d

/-! ## 9. The transitions by family: a stutter, a simulation, or a divergence -/

/-- [M] 2026-10-17: simulations compose: a Teranode step that simulates a reference step, followed by one that
simulates another, simulates the two reference steps in order. -/
theorem Simulates.comp {f g : Obs ι → Obs ι} {r r' : StatusState → StatusState} (hf : Simulates f r)
    (hg : Simulates g r') : Simulates (g ∘ f) (r' ∘ r) :=
  fun o m h => hg _ _ (hf o m h)

/-- A step of the families that stutter by construction: an alert's store write, a ban or unban, a Kafka
publication. -/
inductive StutterStep where
  | alert (f : Alert.Store → Alert.Store)
  | ban (f : Alert.BanList → Alert.BanList)
  | event (e : KafkaEvent)

/-- The step on Teranode's state. -/
def StutterStep.apply : StutterStep → Obs ι → Obs ι
  | .alert f, o => { o with alert := f o.alert }
  | .ban f, o => { o with bans := f o.bans }
  | .event e, o => { o with events := e :: o.events }

/-- [M] 2026-10-17: each such step is a stutter (`alert_stutters`, `ban_stutters`, `event_stutters`). -/
theorem StutterStep.simulates (s : StutterStep) : Simulates (ι := ι) s.apply id := by
  cases s with
  | alert f => exact alert_stutters f
  | ban f => exact ban_stutters f
  | event e => exact event_stutters e

/-- A run of such steps, in order. -/
def runStutters (steps : List StutterStep) (o : Obs ι) : Obs ι :=
  steps.foldl (fun o s => s.apply o) o

/-- [M] 2026-10-17: any run of alert writes, bans and Kafka publications keeps the relation with the reference
unmoved. -/
theorem stutter_run_simulates (steps : List StutterStep) : Simulates (runStutters (ι := ι) steps) id := by
  induction steps with
  | nil => intro o m h; exact h
  | cons s rest ih => intro o m h; exact ih _ _ (s.simulates o m h)

/-- [M] 2026-10-17, row `chain-selection` composed through the relation: after any run of stutter steps the
reference's active tip still has the work of Teranode's best header (#93's `active_work_agrees`, through
`refines_best_work`). -/
theorem stutter_run_best_work (steps : List StutterStep) (o : Obs ι) (m : StatusState) (h : Refines o m)
    (tip : BitVec 256) (htip : m.chain.active.getLast? = some tip) (t : Chain.Row ι)
    (ht : Chain.bestRow (runStutters steps o).rows = some t) :
    ∃ best ∈ eligibleCandidates m.chain, best.id = tip ∧ best.work.toNat = t.work :=
  refines_best_work _ _ (stutter_run_simulates steps o m h).2 tip htip t ht

/-- [M] 2026-10-17, row `freeze-confiscation` composed through the relation: an alert fund that freezes keeps
`Refines` with the reference's status unmoved (`alert_stutters`) and leaves the frozen projection agreeing with
the reference's `addToConsensusBlacklist` at its output (`alert_freeze_refines`, from #94's `freeze_agrees`). -/
theorem alert_freeze_keeps_relation (H : Alert.UtxoHash) (parents : Alert.Parents) (o : Obs ι)
    (m : StatusState) (d : OperatorLists) (f : Alert.Fund) (sats : Nat) (script : Bytes) (u : Alert.Utxo)
    (h : Nat) (hrel : Refines o m) (hparent : parents f.out = some (sats, script))
    (hu : o.alert.utxo f.out = some u) (hhash : u.hash = H f.out sats script)
    (hslot : u.slot = .unspent ∨ u.slot = .frozen) (hfreeze : ¬ f.stop < (o.alert.height : Int))
    (hstart : f.start ≤ (h : Int)) (hstop : (h : Int) < f.stop) (onBlock : Bool) :
    Refines { o with alert := Alert.blacklistOne H parents o.alert f } m ∧
      FrozenRefinesAt { o with alert := Alert.blacklistOne H parents o.alert f } (Alert.refBlacklistOne d f)
        onBlock h f.out :=
  ⟨alert_stutters (fun a => Alert.blacklistOne H parents a f) o m hrel,
    alert_freeze_refines H parents o d f sats script u h hparent hu hhash hslot hfreeze hstart hstop onBlock⟩

/-- Teranode's transition families as the components model them. -/
inductive Family where
  | recordMark | blockMined | prune | fsmKeep | fsmExit | alertStore | alertReassign | ban | kafka
  | reorg | conflictDrop | invalidate | reconsider | frozenSpendBlock | unminedExpire | evict
  deriving DecidableEq, Repr

/-- Every family, in the constructors' order. -/
def Family.all : List Family :=
  [.recordMark, .blockMined, .prune, .fsmKeep, .fsmExit, .alertStore, .alertReassign, .ban, .kafka, .reorg,
   .conflictDrop, .invalidate, .reconsider, .frozenSpendBlock, .unminedExpire, .evict]

/-- [M] 2026-10-17: `Family.all` lists every constructor. -/
theorem Family.mem_all (f : Family) : f ∈ Family.all := by
  cases f <;> simp [Family.all]

/-- How the relation meets a family's step. -/
inductive Rel where
  /-- a stutter: the reference unmoved; the theorems that prove it -/
  | stutter (thms : List Lean.Name)
  /-- observation suspended: no reference state is related after it -/
  | suspends (thm : Lean.Name)
  /-- a stutter of `Refines` whose frozen projection agrees outside it -/
  | agreesOutside (thms : List Lean.Name)
  /-- a simulation of the reference's named step, named and owed, with its owner -/
  | owed (name : Lean.Name) (owner : String)
  /-- the relation is left at the step by a divergence -/
  | departs
  deriving Repr

/-- Whether the relation is left at the step. -/
def Rel.isDeparts : Rel → Bool
  | .departs => true
  | _ => false

/-- One family's account: how the relation meets its step, and the divergence on it, if any. -/
structure Account where
  family : Family
  rel : Rel
  divergence : Option Divergence
  deriving Repr

/-- **THE TRANSITION STATEMENT, per family.** Each Teranode transition is a stutter of the relation (the
reference unmoved), suspends observation, keeps the frozen projection agreeing outside the relation, simulates a
named reference step (owed, with its owner), or leaves the relation by a divergence. A family whose step
stutters may still carry a divergence of who may take it (the ban's authority path). -/
def accounts : List Account :=
  [⟨.recordMark, .stutter [``record_step_stutters], none⟩,
   ⟨.blockMined, .owed ``connectSimulates "S1", some .prematureBlockParked⟩,
   ⟨.prune, .stutter [``prune_stutters], none⟩,
   ⟨.fsmKeep, .stutter [``fsm_stutters], none⟩,
   ⟨.fsmExit, .suspends ``fsm_exit_suspends, none⟩,
   ⟨.alertStore, .agreesOutside [``alert_stutters, ``alert_freeze_keeps_relation, ``alert_unfreeze_refines], none⟩,
   ⟨.alertReassign, .departs, some .alertReassign⟩,
   ⟨.ban, .stutter [``ban_stutters, ``stutter_run_simulates], some .alertBan⟩,
   ⟨.kafka, .stutter [``event_stutters, ``stutter_run_simulates], none⟩,
   ⟨.reorg, .owed ``reorgSimulates "S1", none⟩,
   ⟨.conflictDrop, .owed ``conflictDropSimulates "S1", none⟩,
   ⟨.invalidate, .owed ``Alert.InvalidationRefines "S1", some .alertInvalidate⟩,
   ⟨.reconsider, .departs, some .reconsiderDescendant⟩,
   ⟨.frozenSpendBlock, .departs, some .softFreezeHoldLapse⟩,
   ⟨.unminedExpire, .departs, some .unminedExpiry⟩,
   ⟨.evict, .departs, some .poolEviction⟩]

/-- [M] 2026-10-17: every family has exactly one account, in the families' order. -/
theorem accounts_families : accounts.map (·.family) = Family.all := rfl

/-- [M] 2026-10-17: every family that leaves the relation carries a divergence. -/
theorem departs_carry_divergence : accounts.all (fun a => !a.rel.isDeparts || a.divergence.isSome) = true := rfl

/-! ## 10. The obligation list -/

/-- An owed obligation: the Lean objects it names (each resolved by the elaborator), its statement, its owner. -/
structure Owed where
  names : List Lean.Name
  statement : String
  owner : String
  deriving Repr

/-- How a row of #87's map is discharged: exactly one obligation of one kind. -/
inductive Discharge where
  /-- Kind `theorem`: agreement theorems, each name resolved by the elaborator; the premises they hold under; the
  legs that measured the row agreeing; the divergences the components prove on the same row (model witnesses);
  the halves still owed. -/
  | proved (names : List Lean.Name) (premises : String) (legs : List (Leg × String)) (witnesses : List Lean.Name)
      (rest : List Owed)
  /-- Kind `witness`: a measured leg agreeing on the row, the harness the judge (rule 4), and the theorems that
  support it. -/
  | witness (legs : List (Leg × String)) (support : List Lean.Name)
  /-- Kind `design`: an architecture decision of Teranode's, its divergence labeled policy (the row's own label its rule's, `coinbase-maturity` consensus), its reason cited: the
  divergences of the legs and the absence ledger's rows named in the obligation's `ledger`; the contract page that
  carries it, if any; the supporting theorems and model witnesses; the halves still owed. -/
  | design (ds : List Divergence) (page : Option String) (support : List Lean.Name) (rest : List Owed)
  /-- Kind `chain-split`: the two nodes decide the same blocks differently; the divergence, its supporting model. -/
  | chainSplit (d : Divergence) (support : List Lean.Name)
  /-- Kind `report`: a `same` row, judged by the per-release divergence gate (#95). -/
  | report
  /-- Kind `open`: stated, not discharged; the legs that measured part of it. -/
  | owed (o : Owed) (legs : List (Leg × String))
  deriving Repr

/-- One row's obligation: the row's id, the issue the map names, its rule-1 label (consensus or policy), its
discharge, and the ledger rows of #96 keyed to the row with the row's effective word each (the maintainers' where
ruled, else the proposal). -/
structure Obligation where
  row : String
  issue : String
  label : String
  discharge : Discharge
  ledger : List (String × String)
  deriving Repr

/-- The map's 54 row ids in its order (`corpus/teranode/map.json`, #87). -/
def mapRows : List String :=
  ["tx-receive", "tx-gate", "script-verdict", "script-word", "utxo-spend", "coinbase-maturity", "conflicts",
   "finality", "non-final-hold", "sequence-locks", "orphans", "reject-filter", "fee-floor", "unmined-lifetime",
   "pool-size", "block-structure", "subtrees", "merkle-root", "block-check", "block-connect", "header-pow",
   "difficulty", "header-context", "median-time-past", "coinbase-height", "coinbase-amount", "block-size",
   "block-order", "bip30", "checkpoints", "validation-depth", "chain-selection", "reorg", "invalidation",
   "soft-freeze", "safe-mode", "node-fsm", "freeze-confiscation", "alert-system", "mining-candidate",
   "tx-relay", "compact-blocks", "double-spend-notify", "event-surface", "event-zmq", "event-kafka",
   "observation-rpc", "merkle-proof", "pool-persistence", "block-persistence", "pruning", "miner-id",
   "wire-tx", "wire-block"]

/-- The scenario files the rows' model witnesses name (S3's corpus). -/
def scenarioConflicts : String := "corpus/scenarios/2026-10-14-conflicting-spends-order.md"
/-- The record-lifetimes scenario (#92). -/
def scenarioLifetimes : String := "corpus/scenarios/2026-10-15-record-lifetimes.md"
/-- The competing-branch scenario (#93). -/
def scenarioBranches : String := "corpus/scenarios/2026-10-15-competing-branch-selection.md"

/-- The obligation list: one obligation per row of #87's map, in the map's order. -/
def obligations : List Obligation :=
  [⟨"tx-receive", "#88", "policy", .owed ⟨[``AcceptIsEarliestSeen, ``accepted_eq_accept_of_earliestSeen], "AcceptIsEarliestSeen (Spend.lean, stated and not asserted); under it accepted_eq_accept_of_earliestSeen", "S1"⟩ [], []⟩,
   ⟨"tx-gate", "#95", "consensus", .report, []⟩,
   ⟨"script-verdict", "#95", "consensus", .witness [(legSigner, "step 2: every signature shape of the signer corpus, on the chain")] [], []⟩,
   ⟨"script-word", "#91", "consensus", .proved [``teranode_word_eq_mempool_word, ``teranode_word_eq_block_word] "" [] [] [], []⟩,
   ⟨"utxo-spend", "#90", "consensus", .proved [``accepted_eq_mempool] "under sequential arrival, no reorg, one oracle and distinct inputs, the id determining the body" [] [] [], []⟩,
   ⟨"coinbase-maturity", "#92", "consensus", .design [.prematureBlockParked] (some "spec/node-client-contract.md") [``Lifetimes.coinbase_maturity_agrees, ``Lifetimes.defaults_maturity_agree] [], []⟩,
   ⟨"conflicts", "#90", "policy", .design [] none [``concurrent_both_refused, ``reorg_keeps_differ] [], [("rl.conflicting-record", "new")]⟩,
   ⟨"finality", "#95", "consensus", .report, []⟩,
   ⟨"non-final-hold", "#96", "policy", .design [] none [] [], [("tl.nonfinal-pool", "gap")]⟩,
   ⟨"sequence-locks", "#95", "consensus", .report, []⟩,
   ⟨"orphans", "#98", "policy", .design [] none [``Bridge.bridge_orphan_relayed, ``Bridge.bridge_orphan_reaches_peers, ``Bridge.bridge_orphan_invalid_kept] [⟨[``Bridge.orphanStep], "the legacy bridge's orphan map driven: a child before its parent, a locked parent and a conflicting orphan on the mixed two-node scenario (#98's measured half, docs/CONFORMANCE-TERANODE-BRIDGE.md section 6)", "S4b"⟩], [("tl.orphan-pool", "dropped")]⟩,
   ⟨"reject-filter", "#98", "policy", .proved [``Bridge.bridge_rejected_ignored] "the id in the bridge's rejected map and the machine's recent rejects; the sender not whitelisted under forced relay" [] [``Bridge.bridge_reject_flattened, ``Bridge.bridge_reject_flattened_witness] [⟨[``Bridge.handleTx], "the legacy bridge's reject map driven: its 10,000 bound and its clear at each block against the reference's reset at a tip change, and the 0x10 reject on the reference's log (#98's measured half, docs/CONFORMANCE-TERANODE-BRIDGE.md section 6)", "S4b"⟩], []⟩,
   ⟨"fee-floor", "#88", "policy", .owed ⟨[``rollingMinimum], "the rolling minimum without eviction equals the configured floor (policy); not cheap: the rolling rate is a Float, opaque to the kernel", "S1"⟩ [], []⟩,
   ⟨"unmined-lifetime", "#92", "policy", .design [.unminedExpiry] none [``Lifetimes.expiry_rules_differ] [], []⟩,
   ⟨"pool-size", "#96", "policy", .design [.poolEviction] none [] [], [("tl.pool-size", "gap")]⟩,
   ⟨"block-structure", "#88", "consensus", .proved [``block_structure_refines, ``block_order_refines, ``flatLeaves_single, ``flatLeaves_head, ``flatLeaves_tail] "under the block's transaction ids being Teranode's flat leaves" [] [] [], []⟩,
   ⟨"subtrees", "#96", "policy", .design [] none [] [], [("rl.subtrees", "new")]⟩,
   ⟨"merkle-root", "#89", "consensus", .proved [``subtreeRoot_eq_blockMerkleRoot, ``assembly_root_eq_blockMerkleRoot] "" [] [] [], []⟩,
   ⟨"block-check", "#88", "consensus", .owed ⟨[``checkBlock, ``Chain.Validated], "Teranode's block pass onto checkBlock, under Chain.Validated", "S1"⟩ [], []⟩,
   ⟨"block-connect", "#88", "consensus", .owed ⟨[``connectSimulates, ``refActivate], "connectSimulates (this module, named, NOT stated: Teranode's step owed)", "S1"⟩ [], []⟩,
   ⟨"header-pow", "#95", "consensus", .report, []⟩,
   ⟨"difficulty", "#95", "consensus", .report, []⟩,
   ⟨"header-context", "#95", "consensus", .report, []⟩,
   ⟨"median-time-past", "#95", "consensus", .report, []⟩,
   ⟨"coinbase-height", "#95", "consensus", .report, []⟩,
   ⟨"coinbase-amount", "#95", "consensus", .report, []⟩,
   ⟨"block-size", "#88", "consensus", .owed ⟨[``block_size_differs], "a witness scenario for #66 on the harness-block road (the model witness block_size_differs: Teranode declines as policy, the reference refuses and marks the header)", "S3"⟩ [], []⟩,
   ⟨"block-order", "#88", "policy", .owed ⟨[], "a witness scenario for #66 on the harness-block road (the order check's distance)", "S3"⟩ [], []⟩,
   ⟨"bip30", "#90", "consensus", .owed ⟨[``bip30Enforced], "the create-once record against bip30Enforced; not cheap: the create phase returns ErrTxExists to a caller that decides, and no caller is modelled", "S1"⟩ [], []⟩,
   ⟨"checkpoints", "#95", "consensus", .report, []⟩,
   ⟨"validation-depth", "#88", "policy", .owed ⟨[``validation_depth_differs], "a witness scenario for #66 (a header-proven block below the checkpoint at -assumevalid=0; the model witness validation_depth_differs)", "S3"⟩ [], []⟩,
   ⟨"chain-selection", "#93", "consensus", .proved [``Chain.selected_work_agrees, ``Chain.active_work_agrees, ``refines_best_work, ``stutter_run_best_work] "" [(legChain, "the equal-work rows at the defaults and rows c and d (agree)")] [``Chain.tie_rules_differ, ``Chain.equal_work_tie_moves_tip] [], []⟩,
   ⟨"reorg", "#93", "consensus", .proved [``Chain.mark_off_on_identity, ``Chain.tx_leaves_only_on_more_work] "" [(legChain, "rows c and d, the reorgs in both directions, the same transactions on the longest chain (agree)")] [``Chain.mark_on_off_restamps, ``Chain.mark_on_off_not_identity] [⟨[``reorgSimulates, ``addToMempoolForReorg], "the re-admission half: the assembler's moveBack, moveForward and reset against addToMempoolForReorg", "S1"⟩], []⟩,
   ⟨"invalidation", "#93", "policy", .design [.reconsiderDescendant, .tipsListing] none [``Chain.reconsider_descendant_differs, ``Chain.invalidate_unknown, ``Chain.invalidate_lowers_work] [⟨[``Alert.InvalidationRefines], "Alert.InvalidationRefines (the invalidate half, outside the descendant-reconsider and unknown-hash witnesses)", "S1"⟩], []⟩,
   ⟨"soft-freeze", "#96", "consensus", .chainSplit .softFreezeHoldLapse [``BsvChain.freezeBlockIndex, ``Alert.freeze_spent_refused], [("tl.soft-freeze", "gap")]⟩,
   ⟨"safe-mode", "#96", "policy", .design [] none [] [], [("tl.safe-mode", "dropped")]⟩,
   ⟨"node-fsm", "#96", "policy", .design [] none [``fsm_stutters, ``fsm_exit_suspends] [], [("rl.fsm", "new")]⟩,
   ⟨"freeze-confiscation", "#94", "consensus", .proved [``Alert.freeze_agrees, ``Alert.unfreeze_agrees, ``alert_freeze_refines, ``alert_unfreeze_refines, ``alert_freeze_keeps_relation] "" [(legAlert, "the freeze and unfreeze rows (agree)"), (legStore, "the freeze, unfreeze and second-freeze rows and the reassign's strand row (agree)")] [``Alert.unfreeze_keeps_policy_freeze, ``Alert.future_start_frozen_early, ``Alert.stop_passed_still_frozen, ``Alert.freeze_spent_refused, ``Alert.whitelist_ignores_enforce, ``Alert.reassign_gate, ``Alert.reassign_strands, ``Alert.whitelist_not_confiscation] [], []⟩,
   ⟨"alert-system", "#96", "policy", .design [.alertInvalidate, .alertBan, .alertReassign] none [``Alert.trust_root_changes_who_not_what] [], [("rl.alert-service", "new")]⟩,
   ⟨"mining-candidate", "#88", "policy", .owed ⟨[], "a model of the template on either side", "S1"⟩ [], []⟩,
   ⟨"tx-relay", "#98", "policy", .proved [``Bridge.bridge_accept_relayed, ``Bridge.bridge_accept_reaches_peers, ``Bridge.bridge_tx_refines, ``Bridge.bridge_inv_requests] "under VerdictAgrees (the validator's answer is the mempool machine's verdict), the transaction new to the machine, the sender present, not under blocks-only and not whitelisted under forced relay, not a miner-info data transaction; the inventory road under RUNNING as the download latch off and the store's have-it as the inventory test" [] [``Bridge.bridge_known_accept_diverges, ``Bridge.bridge_announce_passes_fee_filter, ``Bridge.fee_filter_withholds_witness] [⟨[``Bridge.VerdictAgrees], "the legacy bridge's relay driven: the verdict, inventory and RUNNING correspondences measured on the mixed two-node scenario, a transaction each way, the resubmit and the fee filter (#98's measured half, docs/CONFORMANCE-TERANODE-BRIDGE.md section 6)", "S4b"⟩], [("rl.rejected-tx-gossip", "new")]⟩,
   ⟨"compact-blocks", "#96", "policy", .design [] none [] [], [("tl.compact-blocks", "dropped")]⟩,
   ⟨"double-spend-notify", "#96", "policy", .design [] none [] [], [("tl.dsdetected", "gap"), ("tl.ds-attempt-callback", "gap")]⟩,
   ⟨"event-surface", "#97", "policy", .design [] (some "docs/CONFORMANCE-TERANODE-OBSERVATION.md") [``event_stutters] [], [("tl.invalidtx-sinks", "dropped"), ("rl.websocket", "new")]⟩,
   ⟨"event-zmq", "#96", "policy", .design [] none [] [], [("tl.zmq-announce", "dropped"), ("tl.zmq-removal", "gap")]⟩,
   ⟨"event-kafka", "#96", "policy", .design [] none [] [], [("rl.kafka", "new")]⟩,
   ⟨"observation-rpc", "#97", "policy", .proved [``Views.teranode_read_inverse, ``refines_abstract, ``refines_refused] "the observation's agreement as the hypothesis; the read's differences are #97's contract (docs/CONFORMANCE-TERANODE-OBSERVATION.md section 4)" [] [] [], []⟩,
   ⟨"merkle-proof", "#97", "policy", .owed ⟨[``verifyPath], "the harness reads /merkle_proof/:hash and checks it with the evaluator's verifyPath (harness)", "S4b"⟩ [], []⟩,
   ⟨"pool-persistence", "#92", "policy", .owed ⟨[], "the assembler's reload against #81's load", "S1"⟩ [], []⟩,
   ⟨"block-persistence", "#88", "policy", .owed ⟨[], "the block persister against the reference's block file and undo", "S1"⟩ [], []⟩,
   ⟨"pruning", "#92", "policy", .owed ⟨[``Lifetimes.prune_only_mined_or_conflicting, ``prune_stutters], "the block-file half: Teranode's block persister retention against -prune (#82's Store.addBlock, docs/PARAMETERS.md section 8.8); the record's deletion holds by prune_only_mined_or_conflicting, prune_stutters", "S1"⟩ [], []⟩,
   ⟨"miner-id", "#96", "policy", .design [] none [] [], [("tl.miner-id", "dropped")]⟩,
   ⟨"wire-tx", "#98", "consensus", .proved [``Views.Wire.ef_ofTx_tx_spent, ``Views.Wire.ef_decode_encode] "" [] [] [], []⟩,
   ⟨"wire-block", "#98", "consensus", .design [] none [``Bridge.bridgeBlockAccepts, ``Bridge.BlockVerdictAgrees, ``Bridge.bridge_block_accepted] [⟨[``Bridge.bridge_block_accepted], "the bridge's streaming wire reader skips the payload checksum ([SRC] bitcoin-sv `6504a3af` `src/net/net_processing.cpp:5053-5059`, the checksum check and its drop), the design reason (Teranode `wire_streaming.go:11-25` at the pin, the `checksumSkipped` divergence constructor of `bridge_block_accepted`): it takes the block the reference drops at the same bytes; and the split it makes heals itself unaided on a live wire, measured (the reference drops, the bridge takes and announces, the reference's open fetch gate re-agrees the tips inside one announce round; 8 blocks mined on the healed tip and a 180 s quiet watch, both tips one; docs/records/20261018-145427-s8-98-teranode-bridge-horizon2-s4b.md)", "S4b"⟩], []⟩]

/-- [M] 2026-10-15: every row of #87's map has exactly one obligation, in the map's order: the list's rows
are `mapRows` (and `chaincheck --refinement` checks `mapRows` against `corpus/teranode/map.json`). -/
theorem obligations_rows : obligations.map (·.row) = mapRows := rfl

/-- The kind of a discharge, as the counts and `corpus/teranode/obligations.json` name it. -/
def Discharge.kind : Discharge → String
  | .proved .. => "theorem"
  | .witness .. => "witness"
  | .design .. => "design"
  | .chainSplit .. => "chain-split"
  | .report => "report"
  | .owed .. => "open"

/-- The halves still owed on a proved or design row. -/
def Discharge.rest : Discharge → List Owed
  | .proved _ _ _ _ r => r
  | .design _ _ _ r => r
  | _ => []

/-- The legs a discharge reads, each with the leg's row, the divergences' legs included. -/
def Discharge.legs : Discharge → List (Leg × String)
  | .proved _ _ l _ _ => l
  | .witness l _ => l
  | .design ds _ _ _ => ds.flatMap (·.witnesses)
  | .chainSplit d _ => d.witnesses
  | .report => []
  | .owed _ l => l

/-- The divergences a discharge names. -/
def Discharge.divergences : Discharge → List Divergence
  | .design ds _ _ _ => ds
  | .chainSplit d _ => [d]
  | _ => []

/-- Whether a proved row also carries model witnesses of a divergence. -/
def Discharge.hasWitnesses : Discharge → Bool
  | .proved _ _ _ w _ => !w.isEmpty
  | _ => false

/-- Who owes an open row. -/
def Discharge.owner? : Discharge → Option String
  | .owed o _ => some o.owner
  | _ => none

/-- Whether #95's per-release gate re-measures the row: a report row, or a row a leg measured. -/
def Discharge.rerun (d : Discharge) : Bool := d.kind == "report" || !d.legs.isEmpty

/-- The number of rows of a kind. -/
def countKind (k : String) : Nat := (obligations.filter (fun o => o.discharge.kind == k)).length

/-- The number of open rows of an owner. -/
def countOwedBy (s : String) : Nat := (obligations.filter (fun o => o.discharge.owner? == some s)).length

/-- The number of proved rows that also carry model witnesses. -/
def countWithWitnesses : Nat := (obligations.filter (·.discharge.hasWitnesses)).length

/-- The owed halves on proved and design rows. -/
def owedHalves : List Owed := obligations.flatMap (·.discharge.rest)

/-- [M] 2026-10-17: every divergence is named by at least one obligation. -/
theorem divergences_named :
    Divergence.all.all (fun d => obligations.any (fun o => o.discharge.divergences.contains d)) = true := by
  decide

/-- [M] 2026-10-18 (#98, #92; 2026-10-17 #88): the kinds' counts: 11 theorem, 1 witness, 18 design, 1 chain-split, 10 report, 13 open. -/
theorem kind_counts :
    (countKind "theorem", countKind "witness", countKind "design", countKind "chain-split", countKind "report",
      countKind "open") = (11, 1, 18, 1, 10, 13) := by
  decide

end BsvChain.Teranode.Refinement
