import BsvChain.Chain
import BsvChain.Properties.Chain

/-!
# Teranode's chain selection, longest-chain marking and invalidation (#93)

[M] 2026-10-15 (#93). Which chain a node calls the longest decides which
transactions it calls mined. This module states the second oracle's chain
selection as transitions and compares them with the reference's
`ActivateBestChain` as #64 models it (`BsvChain.activateBestChain`,
`BsvChain.invalidateBlock`, `BsvChain.reconsiderBlock`).

The second oracle is Teranode v0.16.0 at
`4edb60a40c6628ff0ef60231c2628efd7103fde5` (`docs/PROVENANCE.md` §1a), read
at the tag [SRC]:
* the blockchain service's FSM (`services/blockchain/fsm.go:17-42,70-122`)
  over looplab/fsm v1.0.2 (`go.mod:37`; its `Event`, `fsm.go:316-341` in the
  module cache at that version);
* the best header (`services/blockchain/Server.go:1679`, the store's query
  `stores/blockchain/sql/GetBestBlockHeader.go:114-137` and
  `GetBestBlockID.go:38-39`: `WHERE invalid = false ORDER BY chain_work DESC,
  peer_id ASC, id ASC LIMIT 1`); the main chain is the best row's ancestry
  (`services/blockchain/Server.go:1705`, `CheckBlockIsInCurrentChain`);
  the chain tips (`Server.go:1747`);
* the block insert (`stores/blockchain/sql/StoreBlock.go:100-437`: the parent's
  invalid flag inherited `:554-560`, the cumulative work `:1038-1052` over
  `services/blockchain/work/work.go:51-64,90`, the difficulty
  `services/blockchain/Difficulty.go:74`; the difficulty is not modeled:
  `storeBlock` takes the block's work as an argument);
* the longest-chain mark (`stores/utxo/aerospike/longest_chain.go:49-196`, the
  SQL backend's `stores/utxo/sql/sql.go:4892-4941`, the stamp
  `stores/utxo/pruner_unmined.go:29-35`) and its callers in the assembler's
  reorg (`services/blockassembly/BlockAssembler.go:1108-1175,2211-2240`,
  `services/blockassembly/subtreeprocessor/SubtreeProcessor.go:4374-4452,4573-4598`);
* optimistic mining (`services/blockvalidation/BlockValidation.go:1668,2166-2401`;
  the settings `settings/settings.go:375-376`,
  `settings/blockvalidation_settings.go:56-57`);
* invalidate and reconsider (`services/blockchain/Server.go:2380-2454,2497-2547`,
  `stores/blockchain/sql/InvalidateBlock.go:62-182`, `RevalidateBlock.go:11-72`,
  the RPC `services/rpc/handlers.go:1862-2028`, the full revalidation
  `services/blockvalidation/Server.go:1401-1450` and
  `BlockValidation.go:2001-2042,2547-2561`); the alert service's
  `services/alert/node.go:160-176` reaches the same `InvalidateBlock`, and
  the authority behind it is #94's.

The reference is bitcoin-sv v1.2.3 at
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b` [SRC]: `FindMostWorkChain`
(`src/validation.cpp:4413`), `ActivateBestChainStep` (`:4561`),
`ActivateBestChain` (`:4913`), `InvalidateBlock` (`:5230`),
`ResetBlockFailureFlags` (`:5528`), `DisconnectBlock`
(`src/processing_block_index.cpp:79`), the RPCs `invalidateblock` and
`reconsiderblock` (`src/rpc/blockchain.cpp:2732,2770`).

What closes, the issue's three theorems:
* Marking off then on is the identity on every record mined on the longest
  chain (`mark_off_on_identity`), as connect then disconnect is for the
  reference's coins (`BsvChain.Properties.s6_undo_identity`). The other order
  re-stamps the clock (`mark_on_off_restamps`): no undo, a backdated mark.
* The best header has maximal work among the rows not marked invalid
  (`best_maximal_work`); against the reference's completed activation the
  selected work agrees under a work-preserving correspondence of the two
  candidate sets (`active_work_agrees`), and the tip itself can differ only at
  equal work, where the tie rules differ (`tie_rules_differ`).
* A transaction leaves the longest chain at a block's arrival only when the
  arriving block becomes the best with more work, or with equal work and a
  smaller peer rank (`tx_leaves_only_on_more_work`); with one peer rank, more
  work strictly (`tx_leaves_strict_one_peer`). The equal-work case is real
  (`equal_work_tie_moves_tip`), and an invalidation removes without more work
  in both machines (`invalidate_lowers_work`;
  `BsvChain.Properties.s6_charter_removal_false` for the reference).
Optimistic mining is a parameter, off at the defaults
(`optimistic_off_at_defaults`); its obligation is `Validated`, which the
non-optimistic insert keeps (`storeBlock_validated`) and the optimistic one
breaks (`optimistic_best_pending`). Invalidate and reconsider map onto the
reference's: the reference clears a reconsidered block's ancestors
(`reference_reconsider_clears_ancestors`), Teranode refuses a block under an
invalid parent (`reconsider_refuses_under_invalid_parent`,
`reconsider_descendant_differs`).

Nothing here is a measurement: the witnesses are model witnesses read from
source [D]; their scenario is
`corpus/scenarios/2026-10-15-competing-branch-selection.md`, its columns owed
to #66's cut 2.
-/

namespace BsvChain.Teranode.Chain
open BsvChain

/-! ## 1. The blockchain service's FSM -/

/-- The FSM's states: `FSMStateType` IDLE, RUNNING, CATCHINGBLOCKS
(`services/blockchain/fsm.go:17-42,62`). The reference has no such machine
(`spec/teranode-absences.md`, row `rl.fsm`). Teranode v0.16.0 at 4edb60a4 [SRC]. -/
inductive FSMState where
  | IDLE | RUNNING | CATCHINGBLOCKS
  deriving DecidableEq, Repr

/-- The FSM's events: RUN, CATCHUPBLOCKS, STOP (`fsm.go:17-42,63`) [SRC] 4edb60a4. -/
inductive FSMEvent where
  | RUN | CATCHUPBLOCKS | STOP
  deriving DecidableEq, Repr

/-- The source states of each event, `FSMTransitions` (`fsm.go:17-42`) [SRC] 4edb60a4. -/
def FSMEvent.sources : FSMEvent → List FSMState
  | .RUN => [.IDLE, .CATCHINGBLOCKS]
  | .CATCHUPBLOCKS => [.IDLE, .RUNNING]
  | .STOP => [.RUNNING, .CATCHINGBLOCKS]

/-- The destination of each event (`fsm.go:24,32,40`) [SRC] 4edb60a4. -/
def FSMEvent.dst : FSMEvent → FSMState
  | .RUN => .RUNNING
  | .CATCHUPBLOCKS => .CATCHINGBLOCKS
  | .STOP => .IDLE

/-- The events in the table's declaration order (`fsm.go:17-42`) [SRC] 4edb60a4. -/
def fsmEvents : List FSMEvent := [.RUN, .CATCHUPBLOCKS, .STOP]

/-- The machine starts in IDLE (`fsm.go:109-110`) [SRC] 4edb60a4. -/
def fsmInitial : FSMState := .IDLE

/-- `AvailableEventsForState` (`fsm.go:47-58`): the events whose sources hold
the state, in declaration order [SRC] 4edb60a4. -/
def availableEvents (s : FSMState) : List FSMEvent :=
  fsmEvents.filter (fun e => e.sources.contains s)

/-- Why an event did not move the machine: looplab/fsm v1.0.2 returns
`InvalidEventError` for a known event whose sources do not hold the current
state (`fsm.go:316-323` at v1.0.2, the version `go.mod:37` pins); the
`before_event` callback persists the destination and cancels the event when
the write fails, the in-memory state unchanged (`services/blockchain/fsm.go:73-86`)
[SRC] 4edb60a4. -/
inductive FSMError where
  | invalidEvent | persistFailed
  deriving DecidableEq, Repr

/-- One event fired (`SendFSMEvent` through looplab's `Event`): `persisted`
is whether the store's `SetFSMState` succeeded (`fsm.go:76-85`) [SRC] 4edb60a4.
The pair is the state after and the error, if any. -/
def fire (persisted : Bool) (s : FSMState) (e : FSMEvent) : FSMState × Option FSMError :=
  if e.sources.contains s then
    if persisted then (e.dst, none) else (s, some .persistFailed)
  else (s, some .invalidEvent)

/-- [M] 2026-10-15: an event succeeds exactly when the table lists it for the
state; a refused event is the library's error, never a silent no-op. A view of
the service, never a validity rule. [SRC] `fsm.go:17-58` at 4edb60a4. -/
theorem fire_ok_iff (s : FSMState) (e : FSMEvent) :
    (fire true s e).2 = none ↔ e ∈ availableEvents s := by
  cases s <;> cases e <;> decide

/-- [M] 2026-10-15: the table has no self-loop, so every accepted event moves
the machine; an observation names the state it was taken in (#97). [SRC]
`fsm.go:17-42` at 4edb60a4. -/
theorem fire_moves (p : Bool) (s : FSMState) (e : FSMEvent)
    (h : (fire p s e).2 = none) : (fire p s e).1 ≠ s := by
  revert h
  cases p <;> cases s <;> cases e <;> decide

/-- [M] 2026-10-15: a refused or unpersisted event leaves the state where it
was (`fsm.go:76-84`). [SRC] 4edb60a4. -/
theorem fire_error_keeps (p : Bool) (s : FSMState) (e : FSMEvent)
    (h : (fire p s e).2.isSome = true) : (fire p s e).1 = s := by
  revert h
  cases p <;> cases s <;> cases e <;> decide

/-- [M] 2026-10-15: every state is one event from IDLE, the initial state
(`fsm.go:109-110`); the machine has no unreachable state. [SRC] 4edb60a4. -/
theorem fsm_reachable (t : FSMState) :
    t = fsmInitial ∨ ∃ e, fire true fsmInitial e = (t, none) := by
  cases t
  · exact .inl rfl
  · exact .inr ⟨.RUN, rfl⟩
  · exact .inr ⟨.CATCHUPBLOCKS, rfl⟩

/-- What the background validation does with a block whose parent transaction
is neither in the block nor on the chain (a floater): invalidated when the
node is caught up, retried otherwise (re-queued for revalidation on the
optimistic path, `:2356`; refused as transient for catch-up to retry on the
non-optimistic path, `:2505-2508`)
(`services/blockvalidation/BlockValidation.go:2337-2357,2487-2509,2650-2657`;
`isCaughtUp` is the FSM's RUNNING, `:2650-2657`) [SRC] 4edb60a4. -/
inductive FloaterAction where
  | invalidate | revalidate
  deriving DecidableEq, Repr

/-- The FSM's one gate on chain selection read here (`BlockValidation.go:2337-2357,2487-2509,2650-2657`)
[SRC] 4edb60a4. -/
def floaterAction (s : FSMState) : FloaterAction :=
  if s = .RUNNING then .invalidate else .revalidate

/-- [M] 2026-10-15: a floater is invalidated only in RUNNING; in a sync state
the same block is retried, so a chain-selection observation is comparable
with the reference's only in RUNNING (#97). [SRC] `BlockValidation.go:2337-2357,2487-2509,2650-2657`
at 4edb60a4. -/
theorem floater_invalidated_only_running (s : FSMState) :
    floaterAction s = .invalidate ↔ s = .RUNNING := by
  cases s <;> decide

/-! ## 2. The settings and the optimistic-mining option -/

/-- The settings this module reads; every one is policy (a node setting),
never consensus (rule 1). Teranode v0.16.0 at 4edb60a4 [SRC]. -/
structure ChainSettings where
  /-- `blockvalidation_optimistic_mining`, default `true`
  (`settings/settings.go:375`, `settings/blockvalidation_settings.go:56`). -/
  optimisticMining : Bool := true
  /-- `blockvalidation_optimistic_mining_peer_blocks`, default `false`
  (`settings/settings.go:376`, `settings/blockvalidation_settings.go:57`). -/
  optimisticMiningPeerBlocks : Bool := false
  /-- `utxostore_unminedTxRetention`, in blocks: `global_blockHeightRetention / 2`,
  144 at the defaults (`settings/settings.go:33,480`,
  `settings/utxostore_settings.go:12`). `markOnLongestChain` takes the retention
  as an argument (every theorem quantifies it); this field records the default
  the store reads (`longest_chain.go:77`). -/
  unminedTxRetention : Nat := 144
  deriving DecidableEq, Repr

/-- The routes into `ValidateBlockWithOptions`: a peer-served block (`processBlockFound`,
`services/blockvalidation/Server.go:1855-1865`), a direct caller with no
override (`BlockValidation.go:1668-1676`), the legacy route
(`Server.go:1656-1666`, baseURL `legacy`), catch-up (`catchup.go:1728`) and
revalidation (`Server.go:1438-1442`) [SRC] 4edb60a4. -/
inductive ValidationPath where
  | peer | direct | legacy | catchup | revalidation
  deriving DecidableEq, Repr

/-- Whether a validation runs optimistically: both flags on every path
(`BlockValidation.go:2166-2176`), and never on legacy, catch-up or
revalidation, which disable it unconditionally [SRC] 4edb60a4. -/
def optimisticEffective (cfg : ChainSettings) : ValidationPath → Bool
  | .peer | .direct => cfg.optimisticMining && cfg.optimisticMiningPeerBlocks
  | .legacy | .catchup | .revalidation => false

/-- [M] 2026-10-15: at the defaults no path is optimistic: the global flag is
on, the peer-blocks flag off, and the second gates every path
(`settings/settings.go:375-376`, `BlockValidation.go:2166-2176`). `settings.conf`
at the tag sets neither key ([M] `git show 4edb60a4:settings.conf | grep -ci optimistic`: 0),
so the instance of record runs the defaults. [SRC] 4edb60a4. -/
theorem optimistic_off_at_defaults (p : ValidationPath) :
    optimisticEffective {} p = false := by
  cases p <;> rfl

/-! ## 3. The blocks table and the best header -/

variable {ι : Type}

/-- A row of the blocks table, the columns the selection reads (the schema
`stores/blockchain/sql/sql.go:647-674`). `work` is `chain_work`, the
cumulative work: stored as 32 big-endian bytes (`StoreBlock.go:1038-1052`,
`work.go:51-64`), so the byte order the query sorts by is the numeric order.
`peerRank` is `peer_id`'s rank under the database's text order (TEXT,
`sql.go:667`; SQLite's BINARY collation compares bytes, PostgreSQL its
collation): the model takes the rank as data. `id` is the auto-increment
insertion id. `pending` is no column: it marks a row added optimistically
whose background validation has not finished (`BlockValidation.go:2238-2401`),
the bookkeeping of the obligation in section 6. Teranode v0.16.0 at 4edb60a4 [SRC]. -/
structure Row (ι : Type) where
  hash : ι
  parent : Option ι
  height : Nat
  work : Nat
  peerRank : Nat
  id : Nat
  invalid : Bool
  pending : Bool := false
  txs : List ι := []
  deriving DecidableEq, Repr

/-- `ORDER BY chain_work DESC, peer_id ASC, id ASC`: `a` sorts strictly
before `b` (`GetBestBlockHeader.go:135`, `GetBestBlockID.go:39`) [SRC] 4edb60a4. -/
def before (a b : Row ι) : Bool :=
  decide (b.work < a.work) ||
    (decide (a.work = b.work) &&
      (decide (a.peerRank < b.peerRank) || (decide (a.peerRank = b.peerRank) && decide (a.id < b.id))))

/-- One step of `LIMIT 1` over the ordered rows. -/
def pickStep (acc : Option (Row ι)) (r : Row ι) : Option (Row ι) :=
  match acc with
  | none => some r
  | some b => if before r b then some r else some b

/-- The row `LIMIT 1` returns. -/
def firstRow (rows : List (Row ι)) : Option (Row ι) := rows.foldl pickStep none

/-- The best header: the top row of those not marked invalid
(`WHERE invalid = false`, `GetBestBlockHeader.go:134`; served by
`services/blockchain/Server.go:1679`) [SRC] 4edb60a4. -/
def bestRow (rows : List (Row ι)) : Option (Row ι) :=
  firstRow (rows.filter (fun r => !r.invalid))

/-- [M] 2026-10-15: a row sorted before another has at least its work: work is the query's primary key. [SRC] `GetBestBlockHeader.go:135` at 4edb60a4. -/
theorem before_work (a b : Row ι) (h : before a b = true) : b.work ≤ a.work := by
  unfold before at h
  simp only [Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq] at h
  omega

/-- [M] 2026-10-15: a row not sorted before another has at most its work. [SRC] `GetBestBlockHeader.go:135` at 4edb60a4. -/
theorem not_before_work (a b : Row ι) (h : before a b = false) : a.work ≤ b.work := by
  unfold before at h
  simp only [Bool.or_eq_false_iff, Bool.and_eq_false_iff, decide_eq_false_iff_not] at h
  omega

/-- [M] 2026-10-15: one step of `LIMIT 1` always keeps a row. -/
theorem pickStep_some (acc : Option (Row ι)) (r : Row ι) : ∃ c, pickStep acc r = some c := by
  cases acc with
  | none => exact ⟨r, rfl⟩
  | some b =>
    by_cases hb : before r b = true
    · exact ⟨r, by simp [pickStep, hb]⟩
    · exact ⟨b, by simp [pickStep, hb]⟩

/-- [M] 2026-10-15: what one step keeps bounds both its inputs and is one of them. -/
theorem pickStep_spec (acc : Option (Row ι)) (x c : Row ι) (h : pickStep acc x = some c) :
    x.work ≤ c.work ∧ (∀ a, acc = some a → a.work ≤ c.work) ∧ (c = x ∨ acc = some c) := by
  cases acc with
  | none =>
    simp only [pickStep, Option.some.injEq] at h
    subst h
    refine ⟨Nat.le_refl _, ?_, .inl rfl⟩
    intro a ha
    simp at ha
  | some b =>
    by_cases hb : before x b = true
    · simp [pickStep, hb] at h
      subst h
      refine ⟨Nat.le_refl _, ?_, .inl rfl⟩
      intro a ha
      simp only [Option.some.injEq] at ha
      subst ha
      exact before_work _ _ hb
    · simp [pickStep, hb] at h
      subst h
      refine ⟨not_before_work _ _ (by simpa using hb), ?_, .inr rfl⟩
      intro a ha
      simp only [Option.some.injEq] at ha
      subst ha
      exact Nat.le_refl _

/-- [M] 2026-10-15: the row the ordered scan keeps came from the scan or its start, and bounds the work of both. [SRC] `GetBestBlockHeader.go:114-137` at 4edb60a4. -/
theorem foldl_pick (xs : List (Row ι)) (acc : Option (Row ι)) (b : Row ι)
    (h : xs.foldl pickStep acc = some b) :
    (b ∈ xs ∨ acc = some b) ∧ (∀ r ∈ xs, r.work ≤ b.work) ∧
      (∀ a, acc = some a → a.work ≤ b.work) := by
  induction xs generalizing acc with
  | nil =>
    simp only [List.foldl_nil] at h
    subst h
    refine ⟨.inr rfl, by simp, ?_⟩
    intro a ha
    simp only [Option.some.injEq] at ha
    subst ha
    exact Nat.le_refl _
  | cons x xs ih =>
    simp only [List.foldl_cons] at h
    obtain ⟨hm, hw, hacc⟩ := ih (pickStep acc x) h
    obtain ⟨c, hc⟩ := pickStep_some acc x
    have hcb := hacc c hc
    obtain ⟨hx, ha, hcx⟩ := pickStep_spec acc x c hc
    refine ⟨?_, ?_, fun a h' => Nat.le_trans (ha a h') hcb⟩
    · rcases hm with hm | hm
      · exact .inl (List.mem_cons_of_mem _ hm)
      · rw [hc] at hm
        simp only [Option.some.injEq] at hm
        subst hm
        rcases hcx with rfl | hcx
        · exact .inl (List.mem_cons_self ..)
        · exact .inr hcx
    · intro r hr
      rcases List.mem_cons.mp hr with rfl | hr
      · exact Nat.le_trans hx hcb
      · exact hw r hr

/-- [M] 2026-10-15: the row `LIMIT 1` returns is a member and bounds the work
of every row it sorted. [SRC] `GetBestBlockHeader.go:114-137` at 4edb60a4. -/
theorem firstRow_maximal (xs : List (Row ι)) (b : Row ι) (h : firstRow xs = some b) :
    b ∈ xs ∧ ∀ r ∈ xs, r.work ≤ b.work := by
  obtain ⟨hm, hw, -⟩ := foldl_pick xs none b h
  exact ⟨hm.resolve_right (by simp), hw⟩

/-- [M] 2026-10-15, #93 theorem 2 (Teranode's side). The best header is a
stored row not marked invalid, and its cumulative work is at least every such
row's: the query's `WHERE invalid = false ORDER BY chain_work DESC` read as a
law. "Valid" here is the stored flag, not a proof of validation: under
optimistic mining a row is stored before its block is validated (section 6),
and an ancestor's flag is not read (a child stored after its parent's
invalidation inherits the flag at insert, `StoreBlock.go:554-560`; the
revalidation path of section 7 refuses a block under an invalid parent).
The reference's side is `BsvChain.Properties.activation_maximal_work`.
[SRC] `GetBestBlockHeader.go:114-137`, `Server.go:1679` at 4edb60a4. -/
theorem best_maximal_work (rows : List (Row ι)) (b : Row ι) (h : bestRow rows = some b) :
    b ∈ rows ∧ b.invalid = false ∧ ∀ r ∈ rows, r.invalid = false → r.work ≤ b.work := by
  obtain ⟨hm, hw⟩ := firstRow_maximal _ b h
  have hm' := List.mem_filter.mp hm
  refine ⟨hm'.1, by simpa using hm'.2, fun r hr hv => hw r (List.mem_filter.mpr ⟨hr, by simp [hv]⟩)⟩

/-- [M] 2026-10-15: the best header changes at an insert only to the new row,
by one comparison with the old best. [SRC] `StoreBlock.go:306-434` at 4edb60a4. -/
theorem bestRow_append (rows : List (Row ι)) (r : Row ι) :
    bestRow (rows ++ [r]) = if r.invalid then bestRow rows else pickStep (bestRow rows) r := by
  unfold bestRow firstRow
  cases hr : r.invalid <;> simp [List.filter_append, List.foldl_append, hr]

/-- [M] 2026-10-15, #88 obligation of the map row `chain-selection`. Under a
correspondence of the two candidate sets that preserves work (every reference
candidate has a stored valid row of its work, and back), the reference's
selection and Teranode's best header carry the same work. Given only when
`Validated` holds (section 6): an optimistically stored row has no reference
candidate. [SRC] `src/validation.cpp:4413-4494` at 6504a3af;
`GetBestBlockHeader.go:114-137` at 4edb60a4. -/
theorem selected_work_agrees (xs : List BlockIndex) (rows : List (Row ι))
    (b : BlockIndex) (t : Row ι) (hb : bestCandidate xs = some b) (ht : bestRow rows = some t)
    (cover : ∀ x ∈ xs, ∃ y ∈ rows, y.invalid = false ∧ y.work = x.work.toNat)
    (back : ∀ y ∈ rows, y.invalid = false → ∃ x ∈ xs, x.work.toNat = y.work) :
    b.work.toNat = t.work := by
  obtain ⟨hbm, hbw⟩ := BsvChain.Properties.bestCandidate_maximal xs b hb
  obtain ⟨htm, htv, htw⟩ := best_maximal_work rows t ht
  obtain ⟨y, hy, hyv, hyw⟩ := cover b hbm
  obtain ⟨x, hx, hxw⟩ := back t htm htv
  have h1 := htw y hy hyv
  have h2 := hbw x hx
  omega

/-- [M] 2026-10-15, #88 obligation of `chain-selection`, against the
reference's completed activation: its active tip names an eligible index whose
work is Teranode's best header's, under the same correspondence over
`eligibleCandidates`. [SRC] `src/validation.cpp:4413-4494,4913-5126` at 6504a3af;
`GetBestBlockHeader.go:114-137` at 4edb60a4. -/
theorem active_work_agrees (s : ChainState) (hc : activationComplete s = true)
    (tip : BitVec 256) (htip : s.active.getLast? = some tip)
    (rows : List (Row ι)) (t : Row ι) (ht : bestRow rows = some t)
    (cover : ∀ x ∈ eligibleCandidates s, ∃ y ∈ rows, y.invalid = false ∧ y.work = x.work.toNat)
    (back : ∀ y ∈ rows, y.invalid = false → ∃ x ∈ eligibleCandidates s, x.work.toNat = y.work) :
    ∃ best ∈ eligibleCandidates s, best.id = tip ∧ best.work.toNat = t.work := by
  simp only [activationComplete, htip, beq_iff_eq] at hc
  cases hb : bestCandidate (eligibleCandidates s) with
  | none => simp [hb] at hc
  | some best =>
    have hid : best.id = tip := by simpa [hb] using hc
    exact ⟨best, (BsvChain.Properties.bestCandidate_maximal _ best hb).1, hid,
      selected_work_agrees _ rows best t hb ht cover back⟩

/-- [M] 2026-10-15: Teranode's equal-work tie goes to the smaller peer rank,
whatever arrived earlier. [SRC] `GetBestBlockHeader.go:135` at 4edb60a4. -/
theorem teranode_tie_peer (a b : Row ι) (hw : a.work = b.work) (hp : a.peerRank < b.peerRank) :
    before a b = true := by
  simp [before, hw, hp]

/-- [M] 2026-10-15: the reference's equal-work tie goes, at equal completion
key, to the earlier sequence id (the block received earlier), whatever its
source. [SRC] `src/block_index.h:1225-1274` at 6504a3af. -/
theorem reference_tie_earlier (a b : BlockIndex) (hw : a.work.toNat = b.work.toNat)
    (hk : a.completion.key = b.completion.key) (hs : a.sequence < b.sequence) :
    preferred a b = true := by
  have h1 : (a.work.toNat != b.work.toNat) = false := by simp [hw]
  have h2 : (a.completion.key != b.completion.key) = false := by simp [hk]
  have h3 : (a.sequence != b.sequence) = true := by simp; omega
  simp only [preferred, h1, h2, h3, Bool.false_eq_true, ↓reduceIte]
  simpa using hs

/-- [D] 2026-10-15, a model witness: two rows of equal work, the later insert
(`id` 2) with the smaller peer rank; Teranode's best header is the later one,
where the reference keeps the earlier received (`reference_tie_earlier`).
Read from source, unobserved: scenario variant `tie` owes the run (#66). -/
theorem tie_rules_differ :
    let x : Row Nat := { hash := 1, parent := some 0, height := 1, work := 2, peerRank := 5, id := 2, invalid := false }
    let y : Row Nat := { hash := 2, parent := some 0, height := 1, work := 2, peerRank := 3, id := 3, invalid := false }
    x.id < y.id ∧ x.work = y.work ∧ bestRow [x, y] = some y := by
  decide

/-! ## 4. The longest chain and the block insert -/

variable [DecidableEq ι]

/-- The row a hash names (the `hash` column is unique). [SRC] `sql.go:647-674,770` at 4edb60a4. -/
def lookup (rows : List (Row ι)) (h : ι) : Option (Row ι) :=
  rows.find? (fun r => r.hash == h)

/-- `Descends rows t h`: `h` is `t` or an ancestor of `t` through the
`previous_hash` links. The main chain is the best row's ancestry: the
`on_main_chain` flag is rebuilt from the best by that walk, and
`CheckBlockIsInCurrentChain` falls back to the same walk
(`stores/blockchain/sql/StoreBlock.go:132-157,368-434`;
`services/blockchain/Server.go:1705-1720`) [SRC] 4edb60a4. -/
inductive Descends (rows : List (Row ι)) : ι → ι → Prop
  | refl (h : ι) : Descends rows h h
  | step {t p h : ι} {x : Row ι} :
      lookup rows t = some x → x.parent = some p → Descends rows p h → Descends rows t h

/-- A block is on the longest chain: an ancestor-or-self of the best header. -/
def OnLongestChain (rows : List (Row ι)) (h : ι) : Prop :=
  ∃ b, bestRow rows = some b ∧ Descends rows b.hash h

/-- A transaction is on the longest chain: a block of the longest chain holds it.
The assembler marks exactly the transactions of the blocks that leave
(`moveBackBlocks`) and enter (`moveForwardBlocks`) the main chain
(`SubtreeProcessor.go:4374-4452,4573-4598`) [SRC] 4edb60a4. -/
def TxOnLongestChain (rows : List (Row ι)) (tx : ι) : Prop :=
  ∃ h x, OnLongestChain rows h ∧ lookup rows h = some x ∧ tx ∈ x.txs

/-- The largest insertion id stored. -/
def maxId (rows : List (Row ι)) : Nat := rows.foldr (fun r m => max r.id m) 0

/-- `StoreBlock`: an existing hash is refused (the unique index
`ux_blocks_hash`, `sql.go:770`, surfaced as `BlockExists`,
`StoreBlock.go:862-899`); a missing parent is refused
(`getPreviousBlockData`, `:964-993`); the parent's invalid flag is inherited
(`:554-560`); the work is the parent's plus the block's own
(`calculateAndPrepareChainWork`, `:1038-1052`; `blockWork` is
`work.CalcBlockWork` of the header's bits, `work.go:90`); the id is the next
auto-increment id. `r`'s `work` and `id` are ignored. [SRC] 4edb60a4. -/
def storeBlock (rows : List (Row ι)) (r : Row ι) (blockWork : Nat) : Option (List (Row ι)) :=
  if (lookup rows r.hash).isSome then none else
  match r.parent with
  | none => some (rows ++ [{ r with work := blockWork, id := maxId rows + 1 }])
  | some p => match lookup rows p with
    | none => none
    | some q =>
      let stored : Row ι := { r with work := q.work + blockWork, id := maxId rows + 1, invalid := r.invalid || q.invalid }
      some (rows ++ [stored])

omit [DecidableEq ι] in
/-- [M] 2026-10-15: every stored id is at most the largest. -/
theorem le_maxId (rows : List (Row ι)) (r : Row ι) (h : r ∈ rows) : r.id ≤ maxId rows := by
  induction rows with
  | nil => cases h
  | cons x xs ih =>
    simp only [maxId, List.foldr_cons] at *
    rcases List.mem_cons.mp h with rfl | h
    · exact Nat.le_max_left _ _
    · exact Nat.le_trans (ih h) (Nat.le_max_right _ _)

/-- [M] 2026-10-15: an insert appends one row, with the block's hash, peer rank, transactions and pending mark, and the next id, to a table that did not hold the hash. [SRC] `StoreBlock.go:100-437` at 4edb60a4. -/
theorem storeBlock_shape (rows rows' : List (Row ι)) (r : Row ι) (w : Nat)
    (h : storeBlock rows r w = some rows') :
    ∃ r', rows' = rows ++ [r'] ∧ r'.hash = r.hash ∧ r'.id = maxId rows + 1 ∧
      r'.peerRank = r.peerRank ∧ r'.txs = r.txs ∧ r'.pending = r.pending ∧
      (lookup rows r.hash).isSome = false := by
  unfold storeBlock at h
  split at h
  · cases h
  · rename_i hfresh
    split at h
    · cases h
      exact ⟨_, rfl, rfl, rfl, rfl, rfl, rfl, by simpa using hfresh⟩
    · split at h
      · cases h
      · cases h
        exact ⟨_, rfl, rfl, rfl, rfl, rfl, rfl, by simpa using hfresh⟩

/-- [M] 2026-10-15: an insert never changes the row an existing hash names. [SRC] `sql.go:770` at 4edb60a4. -/
theorem lookup_append (rows ys : List (Row ι)) (h : ι) (x : Row ι)
    (hl : lookup rows h = some x) : lookup (rows ++ ys) h = some x := by
  unfold lookup at *
  rw [List.find?_append, hl]
  rfl

/-- [M] 2026-10-15: an insert never cuts an existing ancestry: every chain of `previous_hash` links survives it. -/
theorem descends_append (rows ys : List (Row ι)) (t h : ι) (hd : Descends rows t h) :
    Descends (rows ++ ys) t h := by
  induction hd with
  | refl h => exact .refl h
  | step hl hp _ ih => exact .step (lookup_append _ _ _ _ hl) hp ih

/-- [M] 2026-10-15: if the best header is unchanged by an insert, every transaction on its chain stays on the longest chain. -/
theorem tx_append (rows ys : List (Row ι)) (b : Row ι) (tx : ι)
    (hb : bestRow (rows ++ ys) = some b)
    (hbefore : ∃ h x, Descends rows b.hash h ∧ lookup rows h = some x ∧ tx ∈ x.txs) :
    TxOnLongestChain (rows ++ ys) tx := by
  obtain ⟨h, x, hd, hl, ht⟩ := hbefore
  exact ⟨h, x, ⟨b, hb, descends_append _ _ _ _ hd⟩, lookup_append _ _ _ _ hl, ht⟩

/-- [M] 2026-10-15, #93 theorem 3 (Teranode's side, a block's arrival). A
transaction leaves the longest chain when a block is stored only if the
stored block becomes the best header with more work than the old best, or
with equal work and a smaller peer rank. The insertion id cannot win: the new
row's id is the largest. The equal-work case is the second oracle's own
(`equal_work_tie_moves_tip`); the reference's equal-work tie keeps the earlier
block (`reference_tie_earlier`). The other transitions that move the best
header (invalidate, revalidate) remove without more work, in both machines
(`invalidate_lowers_work`; `BsvChain.Properties.s6_charter_removal_false`).
[SRC] `StoreBlock.go:100-437`, `GetBestBlockHeader.go:114-137`,
`BlockAssembler.go:1108-1175` at 4edb60a4. -/
theorem tx_leaves_only_on_more_work (rows rows' : List (Row ι)) (r : Row ι) (w : Nat) (tx : ι)
    (hs : storeBlock rows r w = some rows')
    (hbefore : TxOnLongestChain rows tx) (hafter : ¬ TxOnLongestChain rows' tx) :
    ∃ old new, bestRow rows = some old ∧ bestRow rows' = some new ∧ new.hash = r.hash ∧
      (old.work < new.work ∨ (old.work = new.work ∧ new.peerRank < old.peerRank)) := by
  obtain ⟨r', rfl, hh, hid, -, -, -, -⟩ := storeBlock_shape rows rows' r w hs
  obtain ⟨h, x, ⟨old, hold, hd⟩, hl, ht⟩ := hbefore
  have kept : bestRow (rows ++ [r']) ≠ some old := fun hb =>
    hafter (tx_append rows [r'] old tx hb ⟨h, x, hd, hl, ht⟩)
  have hmem := (best_maximal_work rows old hold).1
  have hlt : old.id < r'.id := by have := le_maxId rows old hmem; omega
  rw [bestRow_append, hold] at kept
  by_cases hinv : r'.invalid = true
  · simp [hinv] at kept
  · by_cases hb : before r' old = true
    · refine ⟨old, r', hold, ?_, hh, ?_⟩
      · rw [bestRow_append, hold]
        simp [hinv, pickStep, hb]
      · unfold before at hb
        simp only [Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq] at hb
        omega
    · simp [hinv, pickStep, hb] at kept

/-- [M] 2026-10-15, #93 theorem 3 with one peer rank (every stored row and the
arriving block share it, as for blocks the node mines itself, each stored with
`peer_id` `""`, `services/blockassembly/Server.go:2099`; `submitblock` is
unimplemented, `services/rpc/Server.go:211`): a
transaction leaves the longest chain at a block's arrival only when strictly
more work is connected, the reference's form under the same premise.
[SRC] `GetBestBlockHeader.go:135`, `StoreBlock.go:100-437` at 4edb60a4. -/
theorem tx_leaves_strict_one_peer (rows rows' : List (Row ι)) (r : Row ι) (w : Nat) (tx : ι)
    (hs : storeBlock rows r w = some rows')
    (hpeer : ∀ x ∈ rows, x.peerRank = r.peerRank)
    (hbefore : TxOnLongestChain rows tx) (hafter : ¬ TxOnLongestChain rows' tx) :
    ∃ old new, bestRow rows = some old ∧ bestRow rows' = some new ∧ old.work < new.work := by
  obtain ⟨old, new, hold, hnew, -, hw⟩ := tx_leaves_only_on_more_work rows rows' r w tx hs hbefore hafter
  obtain ⟨r', rfl, -, -, hpr, -, -, -⟩ := storeBlock_shape rows rows' r w hs
  have hmem := (best_maximal_work rows old hold).1
  have hnm := (best_maximal_work _ new hnew).1
  have hp1 := hpeer old hmem
  have hp2 : new.peerRank = r.peerRank := by
    rcases List.mem_append.mp hnm with hn | hn
    · exact hpeer new hn
    · simp at hn; subst hn; exact hpr
  refine ⟨old, new, hold, hnew, ?_⟩
  omega

/-- [M] 2026-10-15: no ancestor above a root: a row without a parent descends only to itself. -/
theorem descends_root (rows : List (Row ι)) (t h : ι) (x : Row ι)
    (hl : lookup rows t = some x) (hp : x.parent = none) (hd : Descends rows t h) : h = t := by
  cases hd with
  | refl => rfl
  | step hl' hp' _ => rw [hl] at hl'; cases hl'; rw [hp] at hp'; cases hp'

/-- [M] 2026-10-15: one step down a chain. -/
theorem descends_cases (rows : List (Row ι)) (t h : ι) (hd : Descends rows t h) :
    h = t ∨ ∃ x p, lookup rows t = some x ∧ x.parent = some p ∧ Descends rows p h := by
  cases hd with
  | refl => exact .inl rfl
  | step hl hp hd => exact .inr ⟨_, _, hl, hp, hd⟩



/-- The witnesses' rows. `G` the genesis (hash 0), `A` its child (hash 1)
holding transaction 10, stored from a peer of rank 5; `B` a child of `G`
(hash 2) of the same work from a peer of rank 3, the tie's arrival; `C` a
child of `A` (hash 3), the invalidation's tip. -/
def rowG : Row Nat := { hash := 0, parent := none, height := 0, work := 1, peerRank := 0, id := 1, invalid := false }
def rowA : Row Nat := { hash := 1, parent := some 0, height := 1, work := 2, peerRank := 5, id := 2, invalid := false, txs := [10] }
def rowB : Row Nat := { hash := 2, parent := some 0, height := 1, work := 2, peerRank := 3, id := 3, invalid := false }
def rowC : Row Nat := { hash := 3, parent := some 1, height := 2, work := 3, peerRank := 5, id := 4, invalid := false }

/-- `B` as it arrives, before the insert assigns its work and id. -/
def arrivingB : Row Nat := { rowB with work := 0, id := 0 }

/-- [M] 2026-10-15: the tie witness's insert: `B` stored with its parent's work plus its own and the next id. [SRC] `StoreBlock.go:100-437` at 4edb60a4. -/
theorem tie_store : storeBlock [rowG, rowA] arrivingB 1 = some [rowG, rowA, rowB] := by decide

/-- [D] 2026-10-15, a model witness: a block of equal work from a peer of
smaller rank moves the best header, and transaction 10 leaves the longest
chain with no more work connected; the reference keeps `A`, received earlier
(`reference_tie_earlier`). Read from source, unobserved: the scenario's
variant `tie` owes the run on both nodes (#66). The reference's half is read
from `reference_tie_earlier` and `src/validation.cpp:4913-5126`, not computed
in this theorem. [SRC] `GetBestBlockHeader.go:135`,
`StoreBlock.go:100-437` at 4edb60a4. -/
theorem equal_work_tie_moves_tip :
    storeBlock [rowG, rowA] arrivingB 1 = some [rowG, rowA, rowB] ∧
      TxOnLongestChain [rowG, rowA] 10 ∧ ¬ TxOnLongestChain [rowG, rowA, rowB] 10 ∧
      (bestRow [rowG, rowA]).map (·.work) = (bestRow [rowG, rowA, rowB]).map (·.work) := by
  refine ⟨tie_store, ⟨1, rowA, ⟨rowA, by decide, .refl _⟩, by decide, by decide⟩, ?_, by decide⟩
  rintro ⟨h, x, ⟨b, hb, hd⟩, hl, ht⟩
  rw [show bestRow [rowG, rowA, rowB] = some rowB by decide] at hb
  cases hb
  rcases descends_cases _ _ _ hd with rfl | ⟨y, p, hy, hp, hd⟩
  · rw [show lookup [rowG, rowA, rowB] rowB.hash = some rowB by decide] at hl
    cases hl
    simp [rowB] at ht
  · rw [show lookup [rowG, rowA, rowB] rowB.hash = some rowB by decide] at hy
    cases hy
    simp only [rowB, Option.some.injEq] at hp
    subst hp
    have := descends_root _ _ _ rowG (by decide) rfl hd
    subst this
    rw [show lookup [rowG, rowA, rowB] 0 = some rowG by decide] at hl
    cases hl
    simp [rowG] at ht

/-! ## 5. The longest-chain mark on the UTXO store -/

/-- A transaction's record in the UTXO store, the bin the mark writes:
`unminedSince` (`stores/utxo/fields/fields.go:79`); absent means mined on the
longest chain to every reader (`stores/utxo/pruner_unmined.go:28`); the value
0, which readers also take as mined, is outside the model: the mark never
writes it (`backdated_pos`) [SRC] 4edb60a4. -/
structure TxRecord (ι : Type) where
  txid : ι
  unminedSince : Option Nat
  deriving DecidableEq, Repr

/-- `BackdatedUnminedSince`: the current height less the retention, never
below 1 (`stores/utxo/pruner_unmined.go:29-35`) [SRC] 4edb60a4. -/
def backdated (height retention : Nat) : Nat :=
  if height ≤ retention then 1 else height - retention

/-- One record's mark: on the longest chain clears the bin; off it keeps an
existing value and stamps an absent one (`longest_chain.go:68-87`; the SQL
backend's `NULL` and `COALESCE`, `stores/utxo/sql/sql.go:4927-4941`)
[SRC] 4edb60a4. -/
def markRecord (onLongestChain : Bool) (stamp : Nat) (u : Option Nat) : Option Nat :=
  if onLongestChain then none else
    match u with
    | some v => some v
    | none => some stamp

/-- The update `MarkTransactionsOnLongestChain` applies to a record. -/
def markUpdate (txs : List ι) (onLongestChain : Bool) (stamp : Nat) (r : TxRecord ι) : TxRecord ι :=
  if txs.contains r.txid then { r with unminedSince := markRecord onLongestChain stamp r.unminedSince } else r

/-- `MarkTransactionsOnLongestChain` (`stores/utxo/aerospike/longest_chain.go:49-196`):
every listed record updated (`UPDATE_ONLY`, `:62`), the stamp read at the
store's current height (`:59,77`); a missing record among the errors collected
(the earliest ten, `:153-161`) is fatal, the process
stops (`:159-160,183-186`), modeled as `none`. The per-batch errors that leave
some records unwritten are not modeled: the result is the successful run.
[SRC] 4edb60a4. -/
def markOnLongestChain (store : List (TxRecord ι)) (txs : List ι) (onLongestChain : Bool)
    (height retention : Nat) : Option (List (TxRecord ι)) :=
  if txs.all (fun t => store.any (fun r => r.txid == t)) then
    some (store.map (markUpdate txs onLongestChain (backdated height retention)))
  else none

/-- [M] 2026-10-15: the mark changes a record's bin, never its key. [SRC] `longest_chain.go:115-131` at 4edb60a4. -/
theorem markUpdate_txid (txs : List ι) (b : Bool) (s : Nat) (r : TxRecord ι) :
    (markUpdate txs b s r).txid = r.txid := by
  unfold markUpdate; split <;> rfl

/-- [M] 2026-10-15: a stamp is never 0, the value that reads as mined.
[SRC] `pruner_unmined.go:28-35` at 4edb60a4. -/
theorem backdated_pos (height retention : Nat) : 1 ≤ backdated height retention := by
  unfold backdated; split <;> omega

/-- [M] 2026-10-15: off the longest chain never overwrites an existing value
(issue 1768's guard). [SRC] `longest_chain.go:75-87` at 4edb60a4. -/
theorem mark_off_keeps (s v : Nat) : markRecord false s (some v) = some v := rfl

/-- [M] 2026-10-15: each mark is idempotent, so a repeated batch (a retry, a
duplicate hash) writes nothing new. [SRC] `longest_chain.go:68-87` at 4edb60a4. -/
theorem mark_idempotent (b : Bool) (s : Nat) (u : Option Nat) :
    markRecord b s (markRecord b s u) = markRecord b s u := by
  cases b <;> cases u <;> rfl

/-- [M] 2026-10-15: per record, off then on restores the record exactly when
it was mined on the longest chain. [SRC] `longest_chain.go:68-87` at 4edb60a4. -/
theorem mark_off_on_record (s s' : Nat) (u : Option Nat) :
    markRecord true s' (markRecord false s u) = u ↔ u = none := by
  cases u <;> simp [markRecord]

/-- [M] 2026-10-15, #93 theorem 1. Marking a set of mined records off the
longest chain and back on is the identity on the store, at any two heights:
the second oracle's form of the reference's undo identity
(`BsvChain.Properties.s6_undo_identity`, connect then disconnect restores the
coins). Premises in plain words: every listed transaction has a record (else
the store stops), and every listed record is mined on the longest chain
(`unminedSince` absent), the state a reorg's moved-back block leaves its
transactions in before the reorg. [SRC] `longest_chain.go:49-196`,
`stores/utxo/sql/sql.go:4927-4941` at 4edb60a4. -/
theorem mark_off_on_identity (store : List (TxRecord ι)) (txs : List ι) (h h' retention : Nat)
    (hpresent : txs.all (fun t => store.any (fun r => r.txid == t)) = true)
    (hmined : ∀ r ∈ store, r.txid ∈ txs → r.unminedSince = none) :
    (markOnLongestChain store txs false h retention).bind
      (fun s => markOnLongestChain s txs true h' retention) = some store := by
  have hp2 : txs.all (fun t => (store.map (markUpdate txs false (backdated h retention))).any
      (fun r => r.txid == t)) = true := by
    simpa [List.any_map, Function.comp_def, markUpdate_txid] using hpresent
  simp only [markOnLongestChain, hpresent, ↓reduceIte, Option.bind_some, hp2, List.map_map]
  congr 1
  conv => rhs; rw [← List.map_id store]
  apply List.map_congr_left
  intro r hr
  simp only [Function.comp_apply, id]
  by_cases hc : r.txid ∈ txs
  · have hn := hmined r hr hc
    obtain ⟨t, u⟩ := r
    simp only at hn hc
    subst hn
    simp [markUpdate, hc, markRecord]
  · simp [markUpdate, hc]

/-- [M] 2026-10-15: the other order, on then off (a block connected, then
moved back), does not undo: the record comes back unmined with the stamp, not
with the value it had. The store keeps no undo; what it restores is the
unmined view (`isSome`), never the clock. [SRC] `longest_chain.go:68-87`,
`pruner_unmined.go:16-35` at 4edb60a4. -/
theorem mark_on_off_restamps (s s' : Nat) (u : Option Nat) :
    markRecord false s (markRecord true s' u) = some s := rfl

/-- [D] 2026-10-15, a model witness: an unmined transaction stamped at 50,
mined at height 300 and moved back at height 300 under the default retention
of 144, reads `unminedSince` 156, not 50; connect then disconnect is the
identity on the reference's coins (`s6_undo_identity`) and not on this bin.
[SRC] `longest_chain.go:68-87`, `pruner_unmined.go:29-35` at 4edb60a4. -/
theorem mark_on_off_not_identity :
    ((markOnLongestChain [({ txid := 7, unminedSince := some 50 } : TxRecord Nat)] [7] true 300 144).bind
      (fun s => markOnLongestChain s [7] false 300 144)) = some [{ txid := 7, unminedSince := some 156 }] := by
  decide

/-! ## 6. The optimistic-mining obligation -/

/-- The obligation optimistic mining adds: every stored row's block has been
validated in full. A row added optimistically is stored before `block.Valid`
runs (`BlockValidation.go:2238-2249`): the merkle root, the coinbase and BIP34,
duplicate transactions, ordering and parent spends, the old-block-ID
double-spend scan run later in the background (`:2259-2401`;
`settings/blockvalidation_settings.go:56`) [SRC] 4edb60a4. -/
def Validated (rows : List (Row ι)) : Prop := ∀ r ∈ rows, r.pending = false

/-- The insert a validation path makes: optimistic, the row stored pending
before validation (`BlockValidation.go:2238-2249`); otherwise after it
(`:2544-2579`) [SRC] 4edb60a4. -/
def addBlock (cfg : ChainSettings) (path : ValidationPath) (rows : List (Row ι)) (r : Row ι)
    (blockWork : Nat) : Option (List (Row ι)) :=
  storeBlock rows { r with pending := optimisticEffective cfg path } blockWork

/-- [M] 2026-10-15: a non-pending insert keeps the obligation.
[SRC] `StoreBlock.go:100-437` at 4edb60a4. -/
theorem storeBlock_validated (rows rows' : List (Row ι)) (r : Row ι) (w : Nat)
    (hv : Validated rows) (hr : r.pending = false) (hs : storeBlock rows r w = some rows') :
    Validated rows' := by
  obtain ⟨r', rfl, -, -, -, -, hp, -⟩ := storeBlock_shape rows rows' r w hs
  intro x hx
  rcases List.mem_append.mp hx with hx | hx
  · exact hv x hx
  · simp only [List.mem_singleton] at hx
    subst hx
    rw [hp, hr]

/-- [M] 2026-10-15: at the defaults every path keeps the obligation, so the
best header's "not marked invalid" is "validated in full".
[SRC] `settings/settings.go:375-376`, `BlockValidation.go:2166-2176` at 4edb60a4. -/
theorem addBlock_validated_at_defaults (path : ValidationPath) (rows rows' : List (Row ι))
    (r : Row ι) (w : Nat) (hv : Validated rows) (hs : addBlock {} path rows r w = some rows') :
    Validated rows' :=
  storeBlock_validated rows rows' _ w hv (optimistic_off_at_defaults path) hs

omit [DecidableEq ι] in
/-- [M] 2026-10-15: under the obligation the best header is validated and has
maximal work among the stored rows not marked invalid: theorem 2 with what
it assumes made explicit. [SRC] `GetBestBlockHeader.go:114-137` at 4edb60a4. -/
theorem best_validated (rows : List (Row ι)) (hv : Validated rows) (b : Row ι)
    (h : bestRow rows = some b) :
    b.pending = false ∧ ∀ r ∈ rows, r.invalid = false → r.work ≤ b.work :=
  ⟨hv b (best_maximal_work rows b h).1, (best_maximal_work rows b h).2.2⟩

/-- [D] 2026-10-15, a model witness: with both flags on, a peer-served block of
more work becomes the best header before its validation has run. Read from
source, unobserved: the instance of record runs the defaults, where this
cannot happen (`optimistic_off_at_defaults`). [SRC] `BlockValidation.go:2166-2249`
at 4edb60a4. -/
theorem optimistic_best_pending :
    ((addBlock { optimisticMiningPeerBlocks := true } .peer [rowG] arrivingB 1).bind bestRow).map
      (fun b => (b.hash, b.pending)) = some (2, true) := by
  decide

/-! ## 7. Invalidate and reconsider -/

/-- The recursive CTE of `InvalidateBlock`: the block and every row whose
`previous_hash` is in the set, to a fixed point
(`stores/blockchain/sql/InvalidateBlock.go:99-113`) [SRC] 4edb60a4. The fuel
is the table's size. -/
def childrenClosure (rows : List (Row ι)) : Nat → List ι → List ι
  | 0, acc => acc
  | n + 1, acc =>
    let next := (rows.filter (fun r => r.parent.any (fun p => acc.contains p) && !acc.contains r.hash)).map (·.hash)
    if next.isEmpty then acc else childrenClosure rows n (acc ++ next)

/-- [M] 2026-10-15: the recursive CTE never drops a hash it has collected, the target among them. [SRC] `InvalidateBlock.go:99-113` at 4edb60a4. -/
theorem closure_mono (rows : List (Row ι)) (n : Nat) (acc : List ι) (x : ι) (h : x ∈ acc) :
    x ∈ childrenClosure rows n acc := by
  induction n generalizing acc with
  | zero => exact h
  | succ n ih =>
    simp only [childrenClosure]
    split
    · exact h
    · exact ih _ (List.mem_append_left _ h)

/-- `InvalidateBlock`: the genesis block refused (`services/blockchain/Server.go:2393-2398`,
`InvalidateBlock.go:70-72`); an unknown hash is a success that changes
nothing (`InvalidateBlock.go:74-85`); otherwise the block and every
descendant marked invalid in one statement (`:99-113`), the hashes returned.
No chain is disconnected here: the notifications (`Server.go:2433-2449`)
make the assembler re-read the best header and reorganize
(`BlockAssembler.go:1108-1175`). The RPC (`services/rpc/handlers.go:1862-1886`)
and the alert service (`services/alert/node.go:160-176`, #94's authority)
reach the same call. [SRC] 4edb60a4. -/
def invalidate (rows : List (Row ι)) (genesis h : ι) : Except String (List (Row ι) × List ι) :=
  if h = genesis then .error "cannot invalidate the genesis block"
  else if (lookup rows h).isNone then .ok (rows, [])
  else
    let set := childrenClosure rows rows.length [h]
    .ok (rows.map (fun r => if set.contains r.hash then { r with invalid := true } else r), set)

/-- [M] 2026-10-15: after an invalidation every row of the returned set is
marked invalid, the target among them. [SRC] `InvalidateBlock.go:99-113` at 4edb60a4. -/
theorem invalidate_marks (rows rows' : List (Row ι)) (g h : ι) (set : List ι)
    (hi : invalidate rows g h = .ok (rows', set)) :
    (∀ r ∈ rows', r.hash ∈ set → r.invalid = true) ∧ ((lookup rows h).isSome = true → h ∈ set) := by
  unfold invalidate at hi
  by_cases hg : h = g
  · simp [hg] at hi
  · by_cases hn : (lookup rows h).isNone = true
    · simp only [hg, hn, ↓reduceIte, Except.ok.injEq, Prod.mk.injEq] at hi
      obtain ⟨h1, h2⟩ := hi
      subst h1; subst h2
      refine ⟨fun _ _ hm => by simp at hm, fun hs => ?_⟩
      cases hl : lookup rows h <;> simp_all
    · simp only [hg, hn, ↓reduceIte] at hi
      cases hi
      refine ⟨fun r hr hm => ?_, fun _ => closure_mono _ _ _ _ (List.mem_singleton_self _)⟩
      obtain ⟨r0, -, rfl⟩ := List.mem_map.mp hr
      by_cases hc : r0.hash ∈ childrenClosure rows rows.length [h]
      · simp [hc]
      · simp [hc] at hm

/-- [M] 2026-10-15: an unknown hash is invalidated successfully and nothing
moves; the reference's RPC refuses it with `RPC_INVALID_ADDRESS_OR_KEY`,
"Block not found" (`src/rpc/blockchain.cpp:2752-2756` at 6504a3af).
[SRC] `InvalidateBlock.go:74-85`, `handlers.go:1880-1885` at 4edb60a4. -/
theorem invalidate_unknown (rows : List (Row ι)) (g h : ι) (hg : h ≠ g)
    (hl : lookup rows h = none) : invalidate rows g h = .ok (rows, []) := by
  simp [invalidate, hg, hl]

/-- Why a reconsideration stopped: the block absent (`RevalidateBlock.go:19-21`,
`services/blockvalidation/Server.go:1413-1416`), its parent invalid
(`BlockValidation.go:2041`) or a failed check (`Server.go:1444-1447`)
[SRC] 4edb60a4. The RPC wraps each in `RPC_VERIFY` (`handlers.go:1946-1951`). -/
inductive ReconsiderError where
  | blockNotFound | parentInvalid | failedRevalidation
  deriving DecidableEq, Repr

/-- The blockchain service's `RevalidateBlock`: the one block's flag cleared,
its children untouched (`services/blockchain/Server.go:2510-2514`,
`stores/blockchain/sql/RevalidateBlock.go:11-43`) [SRC] 4edb60a4. -/
def revalidateStore (rows : List (Row ι)) (h : ι) : Except ReconsiderError (List (Row ι)) :=
  if (lookup rows h).isNone then .error .blockNotFound
  else .ok (rows.map (fun r => if r.hash = h then { r with invalid := false } else r))

/-- The block-validation service's `RevalidateBlock`: the stored block
validated again in full, never optimistically (`services/blockvalidation/Server.go:1401-1450`),
refused under an invalid parent (`BlockValidation.go:2001-2042`, the
persisting branch skipped for a revalidation), and on success the store's
`RevalidateBlock` (`:2547-2561`). `valid` is the oracle for every other check
of `ValidateBlockWithOptions`. [SRC] 4edb60a4. -/
def revalidateFull (valid : ι → Bool) (rows : List (Row ι)) (h : ι) : Except ReconsiderError (List (Row ι)) :=
  match lookup rows h with
  | none => .error .blockNotFound
  | some x =>
    if (x.parent.bind (lookup rows)).any (·.invalid) then .error .parentInvalid
    else if valid h then revalidateStore rows h else .error .failedRevalidation

/-- Insert a row ahead of every row of lower height. -/
def insertByHeight (r : Row ι) : List (Row ι) → List (Row ι)
  | [] => [r]
  | x :: xs => if x.height < r.height then r :: x :: xs else x :: insertByHeight r xs

/-- `GetLastNInvalidBlocks`: the invalid rows by height, the highest leading, at most
`n` (`stores/blockchain/sql/GetLastNInvalidBlocks.go:88-90`); the order among
equal heights is the database's [SRC] 4edb60a4. -/
def lastInvalid (rows : List (Row ι)) (n : Nat) : List (Row ι) :=
  ((rows.filter (·.invalid)).foldr insertByHeight []).take n

/-- Revalidate a list of blocks in order, stopping at the earliest refusal. -/
def revalidateEach (valid : ι → Bool) : List ι → List (Row ι) → List (Row ι) × Option ReconsiderError
  | [], rows => (rows, none)
  | k :: ks, rows =>
    match revalidateFull valid rows k with
    | .error e => (rows, some e)
    | .ok rows => revalidateEach valid ks rows

/-- `reconsiderInvalidChildren`: breadth-wise from the block, each invalid
child in the snapshot revalidated in full; the earliest refusal ends the RPC
with an error, the earlier revalidations kept (`handlers.go:1974-2028`)
[SRC] 4edb60a4. -/
def reconsiderChildren (snapshot : List (Row ι)) (valid : ι → Bool) :
    Nat → List ι → List (Row ι) → List (Row ι) × Option ReconsiderError
  | 0, _, rows => (rows, none)
  | _ + 1, [], rows => (rows, none)
  | n + 1, p :: queue, rows =>
    let kids := (snapshot.filter (fun c => c.parent == some p)).map (·.hash)
    match revalidateEach valid kids rows with
    | (rows, some e) => (rows, some e)
    | (rows, none) => reconsiderChildren snapshot valid n (queue ++ kids) rows

/-- The RPC `reconsiderblock`: the block revalidated in full, then its invalid
descendants among the last `window` invalid blocks (10,000 at the call,
`handlers.go:1976`), each in full (`handlers.go:1919-1967`). The result is the
store after and the RPC's error, if any. The reference instead clears the
failure flags of the block, its descendants and its ancestors, then activates
(`src/rpc/blockchain.cpp:2770-2818`, `src/validation.cpp:5528-5562` at
6504a3af; `BsvChain.reconsiderBlock`). [SRC] 4edb60a4. -/
def reconsider (valid : ι → Bool) (window : Nat) (rows : List (Row ι)) (h : ι) :
    List (Row ι) × Option ReconsiderError :=
  match revalidateFull valid rows h with
  | .error e => (rows, some e)
  | .ok rows1 => reconsiderChildren (lastInvalid rows1 window) valid (rows1.length + 1) [h] rows1

/-- [M] 2026-10-15: Teranode's `reconsiderblock` of a block under an invalid
parent is refused and changes nothing; the parent is never cleared from
below. [SRC] `BlockValidation.go:2001-2042`, `handlers.go:1945-1952` at 4edb60a4. -/
theorem reconsider_refuses_under_invalid_parent (valid : ι → Bool) (window : Nat)
    (rows : List (Row ι)) (h p : ι) (x y : Row ι)
    (hx : lookup rows h = some x) (hp : x.parent = some p) (hy : lookup rows p = some y)
    (hinv : y.invalid = true) :
    reconsider valid window rows h = (rows, some .parentInvalid) := by
  simp [reconsider, revalidateFull, hx, hp, hy, hinv]

/-- [M] 2026-10-15: the reference's `reconsiderblock` clears the failure flags
of every ancestor of the reconsidered block before it activates, so a
descendant can bring its invalidated ancestor back.
[SRC] `src/validation.cpp:5554-5560`, `src/rpc/blockchain.cpp:2798-2811` at 6504a3af. -/
theorem reference_reconsider_clears_ancestors (s : ChainState) (ctx : ChainContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (hash : BitVec 256) (fuel : Nat) :
    ∃ tree : HeaderTree,
      reconsiderBlock s ctx lists oracle hash fuel = activateBestChain { s with tree } ctx lists oracle fuel ∧
      ∀ i ∈ tree.nodes,
        (((ancestry s.tree (s.tree.nodes.length + 1) (some hash)).getD []).map (·.id)).contains i.id = true →
          i.status.failed = false ∧ i.status.failedParent = false := by
  refine ⟨_, rfl, ?_⟩
  intro i hi hc
  obtain ⟨j, -, rfl⟩ := List.mem_map.mp hi
  split at hc <;> simp_all

/-- The chain of the invalidation witnesses: `G`, then `A` holding
transaction 10, then `C`. -/
def chainGAC : List (Row Nat) := [rowG, rowA, rowC]

/-- The same rows after `invalidateblock A`. -/
def chainGACInvalid : List (Row Nat) := [rowG, { rowA with invalid := true }, { rowC with invalid := true }]

/-- [M] 2026-10-15: the invalidation witness's step: `A` and its child `C` marked invalid, both hashes returned. [SRC] `InvalidateBlock.go:62-182` at 4edb60a4. -/
theorem invalidate_A : invalidate chainGAC 0 1 = .ok (chainGACInvalid, [1, 3]) := by rfl

/-- [D] 2026-10-15, a model witness against the issue's unconditional
sentence: `invalidateblock A` takes transaction 10 off the longest chain and
lowers the best header's work from 3 to 1. The reference's
`BsvChain.Properties.s6_charter_removal_false` is the same refutation in its
machine. [SRC] `InvalidateBlock.go:62-182`, `GetBestBlockHeader.go:114-137`
at 4edb60a4. -/
theorem invalidate_lowers_work :
    invalidate chainGAC 0 1 = .ok (chainGACInvalid, [1, 3]) ∧
      TxOnLongestChain chainGAC 10 ∧ ¬ TxOnLongestChain chainGACInvalid 10 ∧
      (bestRow chainGAC).map (·.work) = some 3 ∧ (bestRow chainGACInvalid).map (·.work) = some 1 := by
  refine ⟨invalidate_A, ⟨1, rowA, ⟨rowC, by decide, .step (x := rowC) (by decide) rfl (.refl _)⟩,
    by decide, by decide⟩, ?_, by decide, by decide⟩
  rintro ⟨h, x, ⟨b, hb, hd⟩, hl, ht⟩
  rw [show bestRow chainGACInvalid = some rowG by decide] at hb
  cases hb
  have := descends_root _ _ _ rowG (by decide) rfl hd
  subst this
  rw [show lookup chainGACInvalid rowG.hash = some rowG by decide] at hl
  cases hl
  simp [rowG] at ht

/-- [D] 2026-10-15, a model witness: after `invalidateblock A`, Teranode's
`reconsiderblock C` is refused (its parent is invalid) and the best header
stays `G`; the reference's clears `A` as `C`'s ancestor
(`reference_reconsider_clears_ancestors`) and activates back to `C`.
`reconsiderblock A` brings `C` back on both. Read from source, unobserved:
the scenario's variant `reconsider` owes the run (#66). The reference's half
is read from `reference_reconsider_clears_ancestors` and
`src/validation.cpp:4913-5126`, not computed in this theorem.
[SRC] `handlers.go:1919-2028`, `BlockValidation.go:2001-2042` at 4edb60a4. -/
theorem reconsider_descendant_differs :
    reconsider (fun _ => true) 10000 chainGACInvalid 3 = (chainGACInvalid, some .parentInvalid) ∧
      (bestRow (reconsider (fun _ => true) 10000 chainGACInvalid 3).1).map (·.hash) = some 0 ∧
      (reconsider (fun _ => true) 10000 chainGACInvalid 1).2 = none ∧
      (bestRow (reconsider (fun _ => true) 10000 chainGACInvalid 1).1).map (·.hash) = some 3 := by
  decide

end BsvChain.Teranode.Chain
