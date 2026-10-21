import BsvChain.Mempool

/-!
# Policy-machine laws (#62)

These statements expose the qualifications in the pinned program: earlier
checks may refuse a conflicting transaction before the conflict stage; held
updates have a deliberate exception; expiry also removes young descendants;
and residual fee-delta allocations can exceed a cap after the pool is empty.
[SRC] src/validation.cpp:1031–1152, src/txmempool.cpp:2097–2110,2201–2220,
2257–2280,2736–2792 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
-/

namespace BsvChain.Properties.Mempool
open BsvChain BsvScript.Tx

/-- An indexed accepted spend refuses the conflict stage with the source's
exact internal code and reason. The returned work is identical: replacement
cannot occur in this branch. The prefix must have succeeded to reach it.
[SRC] src/validation.cpp:1147–1152 and src/txmempool.cpp:2257–2280 at 6504a3af. -/
theorem accepted_spend_conflict (w : AdmissionWork)
    (h : w.request.tx.inputs.any (fun i => w.pool.mapNextTx.any
      (fun kv => kv.1 == OutPoint.ofInput i)) = true) :
    stageConflict w = (w, some (.completed (.rejected (.node 0x102) "txn-mempool-conflict"))) := by
  simp [stageConflict, hasPoolConflict, h, checkedStep, rejectOutcome]

/-- Held locks refuse final requests outside the finalising-update exception.
An unconditional law for all held locks would contradict the pinned source.
[SRC] src/txmempool.cpp:2265–2280 and src/time_locked_mempool.cpp:114–156 at 6504a3af. -/
theorem held_spend_conflict (w : AdmissionWork) (hfinal : w.judgedFinal = true)
    (hlock : (nonFinalConflicts w.pool w.request.tx).isEmpty = false)
    (hupdate : finalisesExisting w.pool w.request.tx = false) :
    stageConflict w = (w, some (.completed (.rejected (.node 0x102) "txn-mempool-conflict"))) := by
  simp [stageConflict, hasPoolConflict, hfinal, hlock, hupdate, checkedStep, rejectOutcome]

/-- Definitional projection helper: retryOrphans writes only collected and
pending. The substantive selection/enqueue law is orphan_parent_enqueues below;
full validation is still required for every orphan.
[SRC] src/orphan_txns.cpp:256–350 and src/txn_validator.cpp:695–724 at 6504a3af. -/
theorem orphan_arrival_never_accepts (p : Mempool) (cfg : NodeConfig) (now : Int) (batch : Nat) :
    (retryOrphans p cfg now batch).accepted = p.accepted ∧
    (retryOrphans p cfg now batch).mapNextTx = p.mapNextTx := by
  exact ⟨rfl, rfl⟩

/-- A queued orphan is re-evaluated by accept, which can still refuse it.
This is the connection between the retry transition and all admission stages.
[SRC] src/txn_validator.cpp:567–578,695–724 at 6504a3af. -/
theorem pending_reuses_accept (p : Mempool) (cfg : NodeConfig) (ctx : AdmissionContext)
    (utxo : UtxoSet) (lists : FrozenLists) (oracle : ScriptOracle) (obs : DetectorObservation)
    (work : PendingWork) (rest : List PendingWork) (h : p.pending = work :: rest) :
    revalidatePending p utxo cfg ctx lists oracle obs =
      let result := accept { p with pending := rest } utxo cfg ctx lists oracle obs work.request
      (result.1, some result.2) := by
  simp [revalidatePending, h]

/-- Every completed earlier result is independent of the late detector
observation. Its argument is unavailable to beforeDetector and the trace stops
before insertion, regardless of the two concurrent-spend observations.
[SRC] src/validation.cpp:1484–1494 and src/txmempool.h:1380–1389 at 6504a3af. -/
theorem detector_last (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (request : TxRequest) (a b : DetectorObservation) (next : AdmissionWork)
    (outcome : TxOutcome) (trace : List AdmissionStage)
    (h : beforeDetector (request.configOverride.getD cfg) ctx lists oracle
      { pool := p, view := mempoolView p utxo, request } = (next, some outcome, trace)) :
    acceptWithTrace p utxo cfg ctx lists oracle a request =
      acceptWithTrace p utxo cfg ctx lists oracle b request := by
  simp only [acceptWithTrace]
  split <;> simp_all

/-- Promotion edits metadata only. This helper lets maintenance proofs ignore
fee sorting, floating-point rates and the configured propagation bound.
[SRC] src/txmempool.cpp:383–405,452–565 at 6504a3af. -/
theorem promote_entry_ids (cfg : NodeConfig) (p : Mempool) (e : MempoolEntry) :
    (promoteEntry cfg p e).1.accepted.map (·.id) = p.accepted.map (·.id) := by
  unfold promoteEntry
  split
  · rfl
  · dsimp only
    split <;> simp only [List.map_map]
    all_goals
      apply List.map_congr_left
      intro x _
      simp only [Function.comp_apply]
      split_ifs <;> rfl

/-- Propagating primary promotion preserves every accepted transaction id.
[SRC] src/txmempool.cpp:481–565 at 6504a3af. -/
theorem promote_loop_ids (cfg : NodeConfig) (limited : Bool) (fuel : Nat)
    (p : Mempool) (queued : List TxId) (visited : Nat) :
    (promoteLoop cfg limited fuel p queued visited).accepted.map (·.id) = p.accepted.map (·.id) := by
  induction fuel generalizing p queued visited with
  | zero => rfl
  | succ fuel ih =>
    simp only [promoteLoop]
    split
    · rfl
    · split
      · rfl
      · exact (ih _ _ _).trans (promote_entry_ids _ _ _)

/-- Group repair changes metadata, so the removal set is exactly the staged
ids. In particular, a younger descendant is removed only through that set.
[SRC] src/txmempool.cpp:2130–2198 at 6504a3af. -/
theorem remove_staged_ids (p : Mempool) (cfg : NodeConfig) (ids : List TxId) :
    (removeStaged p cfg ids).accepted.map (·.id) =
      (p.accepted.filter (fun e => !ids.contains e.id)).map (·.id) := by
  unfold removeStaged
  rw [promote_loop_ids]
  simp only [removePoolIds, reindex, List.filter_map, List.map_map]
  congr 1
  · funext x
    simp only [Function.comp_apply]
    split <;> rfl
  · congr 1
    funext x
    simp only [Function.comp_apply]
    split <;> rfl

/-- Expiry's exact removal law: the strict-age roots and their descendants.
This corrects an age-only statement, which the reference does not satisfy.
[SRC] src/txmempool.cpp:2201–2220 at 6504a3af. -/
theorem expire_removes_only_expiry_closure (p : Mempool) (cfg : NodeConfig) (now : Int) :
    (expire p cfg now).accepted.map (·.id) =
      (p.accepted.filter (fun e => !(descendantIds p (expiryRoots p cfg now)).contains e.id)).map (·.id) := by
  exact remove_staged_ids p cfg _

/-- Each expiry root really is older than the configured age; equality stays.
[SRC] src/txmempool.cpp:2201–2207 at 6504a3af. -/
theorem expiry_root_is_old (p : Mempool) (cfg : NodeConfig) (now : Int) (id : TxId)
    (h : id ∈ expiryRoots p cfg now) :
    ∃ e ∈ p.accepted, e.id = id ∧ e.time < now - (cfg.mempoolExpiry : Int) := by
  simpa [expiryRoots, List.mem_filter, and_assoc, and_left_comm, and_comm] using h

/-- No eviction is performed at or below the configured size boundary.
[SRC] src/txmempool.cpp:2736–2737 at 6504a3af. -/
theorem trim_at_limit (p : Mempool) (cfg : NodeConfig) (a : PoolAccounting) (limit : Nat)
    (h : poolUsage a p ≤ limit) : trimToSize p cfg a limit = p := by
  unfold trimToSize
  cases p.accepted.length <;> simp [trimLoop, h]

/-- A selected candidate is an accepted entry, including the total extension
for an inconsistent cyclic model state.
[SRC] src/txmempoolevictioncandidates.cpp:170–174 at 6504a3af. -/
theorem eviction_candidate_mem (p : Mempool) (e : MempoolEntry)
    (h : evictionCandidate p = some e) : e ∈ p.accepted := by
  unfold evictionCandidate at h
  have hm := List.mem_of_head? h
  simp only [List.mem_mergeSort] at hm
  split at hm
  · exact hm
  · exact (List.mem_filter.mp hm).1

/-- The total candidate selector returns none only for an empty pool.
[SRC] src/txmempool.cpp:2736–2737 at 6504a3af. -/
theorem eviction_none_empty (p : Mempool) (h : evictionCandidate p = none) : p.accepted = [] := by
  unfold evictionCandidate at h
  have hn := List.head?_eq_none_iff.mp h
  have hl := congrArg List.length hn
  simp only [List.length_mergeSort, List.length_nil] at hl
  split at hl
  · exact List.length_eq_zero_iff.mp hl
  · rename_i hne
    have : evictionCandidates p = [] := List.length_eq_zero_iff.mp hl
    simp [this] at hne

/-- Descendant closure retains each root that was an accepted entry.
[SRC] src/txmempool.cpp:2206–2218,2748–2750 at 6504a3af. -/
theorem descendant_root_mem (p : Mempool) (e : MempoolEntry) (roots : List TxId)
    (he : e ∈ p.accepted) (hr : e.id ∈ roots) : e.id ∈ descendantIds p roots := by
  unfold descendantIds
  have loop : ∀ (steps : List Nat) (ids : List TxId), e.id ∈ ids →
      e.id ∈ steps.foldl (fun ids _ =>
        (p.accepted.filter (fun x => ids.contains x.id || x.tx.inputs.any
          (fun i => ids.contains i.prevHash))).map (·.id)) ids := by
    intro steps
    induction steps with
    | nil => intro ids h; exact h
    | cons n ns ih =>
      intro ids h
      apply ih
      apply List.mem_map.mpr
      exact ⟨e, List.mem_filter.mpr ⟨he, by simp [h]⟩, rfl⟩
  exact loop _ _ hr

/-- Each eviction removes at least its selected accepted entry; metadata
repair cannot restore it. This is the finite progress fact for the size law.
[SRC] src/txmempool.cpp:2748–2763 at 6504a3af. -/
theorem eviction_decreases (p : Mempool) (cfg : NodeConfig) (e : MempoolEntry)
    (h : evictionCandidate p = some e) :
    (removeStaged p cfg (descendantIds p [e.id])).accepted.length < p.accepted.length := by
  have he := eviction_candidate_mem p e h
  have hr := descendant_root_mem p e [e.id] he (by simp)
  have ids := congrArg List.length (remove_staged_ids p cfg (descendantIds p [e.id]))
  simp only [List.length_map] at ids
  rw [ids]
  have le := List.length_filter_le (fun x : MempoolEntry => !(descendantIds p [e.id]).contains x.id) p.accepted
  have ne : (p.accepted.filter (fun x => !(descendantIds p [e.id]).contains x.id)).length ≠ p.accepted.length := by
    intro eq
    have kept := List.length_filter_eq_length_iff.mp eq e he
    simp [hr] at kept
  omega

/-- The rolling fee update touches no entries or memory-accounting fields.
[SRC] src/txmempool.cpp:1365–1383 at 6504a3af. -/
theorem bump_preserves_size (cfg : NodeConfig) (p : Mempool) (a : PoolAccounting) (rate : Int) :
    poolUsage a (bumpRollingFee cfg p rate) = poolUsage a p ∧
    (bumpRollingFee cfg p rate).accepted = p.accepted := by
  unfold bumpRollingFee
  dsimp only
  split_ifs <;> exact ⟨rfl, rfl⟩

/-- Enough live-entry fuel reaches the source loop's stop condition. The
empty alternative is necessary when mapDeltas allocations exceed the cap.
[SRC] src/txmempool.cpp:2097–2110,2736–2792 at 6504a3af. -/
theorem trim_loop_bound (cfg : NodeConfig) (a : PoolAccounting) (limit fuel : Nat)
    (p : Mempool) (rate : Int) (evicted : Bool) (h : p.accepted.length ≤ fuel) :
    poolUsage a (trimLoop cfg a limit fuel p rate evicted) ≤ limit ∨
      (trimLoop cfg a limit fuel p rate evicted).accepted = [] := by
  induction fuel generalizing p rate evicted with
  | zero =>
    have empty : p.accepted = [] := List.length_eq_zero_iff.mp (by omega)
    simp only [trimLoop]
    split
    · exact Or.inr ((bump_preserves_size cfg p a rate).2.trans empty)
    · exact Or.inr empty
  | succ n ih =>
    simp only [trimLoop]
    split
    · rename_i small
      split
      · exact Or.inl (by rw [(bump_preserves_size cfg p a rate).1]; exact small)
      · exact Or.inl small
    · split
      · rename_i absent
        have empty := eviction_none_empty p absent
        split
        · exact Or.inr ((bump_preserves_size cfg p a rate).2.trans empty)
        · exact Or.inr empty
      · rename_i e chosen
        apply ih
        have smaller := eviction_decreases p cfg e chosen
        omega

/-- After trimming, usage is at most the requested cap or no transaction
remains. The latter covers retained mapDeltas allocations, which the source
keeps even for absent ids. With zero residual allocation it implies the cap.
[SRC] src/txmempool.cpp:2097–2110,2736–2792 at 6504a3af. -/
theorem trim_size_bound (p : Mempool) (cfg : NodeConfig) (a : PoolAccounting) (limit : Nat) :
    poolUsage a (trimToSize p cfg a limit) ≤ limit ∨ (trimToSize p cfg a limit).accepted = [] := by
  exact trim_loop_bound cfg a limit p.accepted.length p 0 false (Nat.le_refl _)

/-- With byte-only accounting, an empty pool has zero usage, so the size law
has no residual-allocation exception. Equality with the cap is permitted.
[SRC] src/txmempool.cpp:2097–2110,2736–2792 at 6504a3af. -/
theorem trim_byte_only_bound (p : Mempool) (cfg : NodeConfig) (limit : Nat) :
    poolUsage PoolAccounting.byteOnly (trimToSize p cfg PoolAccounting.byteOnly limit) ≤ limit := by
  rcases trim_size_bound p cfg PoolAccounting.byteOnly limit with h | h
  · exact h
  · simp only [poolUsage, indexUsage, h]
    simp [PoolAccounting.byteOnly]

/-- Reaching the conflict stage after the ordered prefix gives the exact
conflict verdict before inputs, fees, scripts or detector insertion can run.
The prefix assumptions expose why a malformed conflict can have another code.
[SRC] src/validation.cpp:1031–1152 at 6504a3af. -/
theorem admission_conflict_rejects (cfg : NodeConfig) (ctx : AdmissionContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (w : AdmissionWork)
    (a b c d : AdmissionWork)
    (hr : stageRegular cfg ctx w = (a, none))
    (hs : stageStandard cfg ctx a = (b, none))
    (hf : stageFinality cfg ctx b = (c, none))
    (hk : stageAlreadyKnown c = (d, none))
    (hc : d.request.tx.inputs.any (fun i => d.pool.mapNextTx.any
      (fun kv => kv.1 == OutPoint.ofInput i)) = true) :
    beforeDetector cfg ctx lists oracle w =
      (d, some (.completed (.rejected (.node 0x102) "txn-mempool-conflict")),
        [.regular, .standard, .finality, .alreadyKnown, .conflict]) := by
  simp [beforeDetector, admissionPrefix, runAdmissionStages, hr, hs, hf, hk,
    accepted_spend_conflict d hc]

/-- Accepted entries index every spent outpoint under the spender's actual id.
This is the invariant required when a chain integration supplies pool state.
[SRC] src/txmempool.cpp:758–774 at 6504a3af. -/
def AcceptedSpendIndex (p : Mempool) : Prop :=
  ∀ e ∈ p.accepted, ∀ i ∈ e.tx.inputs, (OutPoint.ofInput i, e.id) ∈ p.mapNextTx

/-- Rebuilding the index establishes the accepted-entry/index connection.
[SRC] src/txmempool.cpp:758–774 at 6504a3af. -/
theorem reindex_spend_index (p : Mempool) : AcceptedSpendIndex (reindex p) := by
  intro e he i hi
  exact List.mem_flatMap.mpr ⟨e, he, List.mem_map.mpr ⟨i, hi, rfl⟩⟩

/-- An actual accepted spender and a shared outpoint imply the indexed conflict
predicate, under the pool's spend-index invariant. Held entries are separate.
[SRC] src/txmempool.cpp:758–774,2257–2280 at 6504a3af. -/
theorem accepted_member_conflicts (p : Mempool) (request : TxRequest)
    (old : MempoolEntry) (oldInput newInput : TxIn)
    (index : AcceptedSpendIndex p) (member : old ∈ p.accepted)
    (oldSpend : oldInput ∈ old.tx.inputs) (newSpend : newInput ∈ request.tx.inputs)
    (same : OutPoint.ofInput oldInput = OutPoint.ofInput newInput) :
    request.tx.inputs.any (fun i => p.mapNextTx.any
      (fun kv => kv.1 == OutPoint.ofInput i)) = true := by
  apply List.any_eq_true.mpr
  refine ⟨newInput, newSpend, List.any_eq_true.mpr ?_⟩
  exact ⟨(OutPoint.ofInput oldInput, old.id), index old member oldInput oldSpend, by simp [same]⟩

/-- The complete accept transition refuses a competing accepted spend and
retains the earlier entry, provided the P2P filter permits submission and the
ordered earlier gates succeed. Those gates may otherwise report another reason.
The ready work differs only in its finality judgment. Held locks have the
finalising-update exception and valid non-final updates can replace a held
entry; neither exception replaces an accepted spender.
[SRC] src/validation.cpp:1031–1152, src/txmempool.cpp:758–774,2257–2280 and
src/time_locked_mempool.cpp:67–85 at 6504a3af. -/
theorem accept_preserves_accepted_spender (p : Mempool) (utxo : UtxoSet)
    (cfg : NodeConfig) (ctx : AdmissionContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (obs : DetectorObservation) (request : TxRequest)
    (old : MempoolEntry) (oldInput newInput : TxIn) (status : FinalityStatus)
    (index : AcceptedSpendIndex p) (member : old ∈ p.accepted)
    (oldSpend : oldInput ∈ old.tx.inputs) (newSpend : newInput ∈ request.tx.inputs)
    (same : OutPoint.ofInput oldInput = OutPoint.ofInput newInput)
    (submitted : (request.source == .p2p && p.recentRejects.contains (BsvScript.Sighash.txid request.tx)) = false) :
    let c := request.configOverride.getD cfg
    let w : AdmissionWork := { pool := p, view := mempoolView p utxo, request }
    let ready := { w with finality := status, judgedFinal := status == .final }
    stageRegular c ctx w = (w, none) →
    stageStandard c ctx w = (w, none) →
    stageFinality c ctx w = (ready, none) →
    stageAlreadyKnown ready = (ready, none) →
    (accept p utxo cfg ctx lists oracle obs request).2 =
      .completed (.rejected (.node 0x102) "txn-mempool-conflict") ∧
    (accept p utxo cfg ctx lists oracle obs request).1.accepted = p.accepted ∧
    old ∈ (accept p utxo cfg ctx lists oracle obs request).1.accepted := by
  intro c w ready hr hs hf hk
  have conflict := accepted_member_conflicts p request old oldInput newInput index member oldSpend newSpend same
  have stop := admission_conflict_rejects c ctx lists oracle w w w ready ready hr hs hf hk conflict
  simp only [accept, acceptWithTrace, submitted, Bool.false_eq_true, ↓reduceIte]
  rw [stop]
  simp only [finishAdmission]
  split <;> simp_all [ready, w]

/-- Adding a secondary child never discards a selected retained request.
[SRC] src/orphan_txns.cpp:329–346 at 6504a3af. -/
theorem collect_orphan_child_retains (p : Mempool) (cfg : NodeConfig) (id : TxId)
    (state : List OrphanEntry × List OrphanEntry) (n : Nat) (e : OrphanEntry)
    (h : e ∈ state.1) : e ∈ (collectOrphanChild p cfg id state n).1 := by
  unfold collectOrphanChild
  split
  · split <;> simp_all
  · exact h

/-- Secondary breadth traversal retains every direct selected orphan, whatever
batch cap or finite traversal fuel is supplied. Direct children bypass that cap.
[SRC] src/orphan_txns.cpp:278–350 at 6504a3af. -/
theorem expand_orphan_retains (p : Mempool) (cfg : NodeConfig) (cap fuel : Nat)
    (chosen queue : List OrphanEntry) (e : OrphanEntry) (h : e ∈ chosen) :
    e ∈ expandOrphanRetries p cfg cap fuel chosen queue := by
  induction fuel generalizing chosen queue with
  | zero => exact h
  | succ fuel ih =>
    simp only [expandOrphanRetries]
    split
    · cases queue with
      | nil => exact h
      | cons parent rest =>
        apply ih
        have keep : ∀ (ns : List Nat) (state : List OrphanEntry × List OrphanEntry),
            e ∈ state.1 → e ∈ (ns.foldl
              (collectOrphanChild p cfg (BsvScript.Sighash.txid parent.request.tx)) state).1 := by
          intro ns
          induction ns with
          | nil => intro state he; exact he
          | cons n ns ihn =>
            intro state he
            exact ihn _ (collect_orphan_child_retains p cfg _ state n e he)
        exact keep _ (chosen, rest) h
    · exact h

/-- A collected parent output selects its dependent orphan's retained request
and enqueues that request, changing only its acceptance timestamp. This models
a retry scheduling event after the handler's cancellation/duplicate filtering;
the caller supplies the remaining eligible orphan set and explicit order.
No assumption that all other parents arrived or validation will pass is made.
[SRC] src/orphan_txns.cpp:278–301 and src/txn_validator.cpp:695–719 at 6504a3af. -/
theorem orphan_parent_enqueues (p : Mempool) (cfg : NodeConfig) (now : Int) (batch : Nat)
    (orphan : OrphanEntry) (input : TxIn) (parent : TxId) (outputs : Nat)
    (retained : orphan ∈ p.orphans) (spend : input ∈ orphan.request.tx.inputs)
    (arrived : (parent, outputs) ∈ p.collected) (hash : input.prevHash = parent)
    (index : input.prevIndex < outputs) :
    (⟨{ orphan.request with acceptTime := now }, now⟩ : PendingWork) ∈
      (retryOrphans p cfg now batch).pending := by
  have direct : orphan ∈ directOrphanRetries p := by
    apply List.mem_filter.mpr
    refine ⟨retained, List.any_eq_true.mpr ⟨input, spend, ?_⟩⟩
    exact List.any_eq_true.mpr ⟨(parent, outputs), arrived, by simp [hash, index]⟩
  have selected : orphan.request ∈ orphanRetryRequests p cfg batch := by
    exact List.mem_map.mpr ⟨orphan, expand_orphan_retains p cfg _ _ _ _ orphan direct, rfl⟩
  exact List.mem_append_right _ (List.mem_map.mpr ⟨orphan.request, selected, rfl⟩)

/-- A dependent orphan selected by arrival can enter the accepted set only via
full accept when its queued work is scheduled. The head premise exposes the
scheduler's order; parent arrival itself preserves the accepted set and index.
The queued request retains every override apart from the refreshed timestamp.
[SRC] src/orphan_txns.cpp:278–301 and src/txn_validator.cpp:695–719 at 6504a3af. -/
theorem selected_orphan_reuses_accept (p : Mempool) (cfg : NodeConfig)
    (ctx : AdmissionContext) (utxo : UtxoSet) (lists : FrozenLists)
    (oracle : ScriptOracle) (obs : DetectorObservation) (batch : Nat)
    (orphan : OrphanEntry) (rest : List PendingWork)
    (scheduled : (retryOrphans p cfg ctx.now batch).pending =
      ⟨{ orphan.request with acceptTime := ctx.now }, ctx.now⟩ :: rest) :
    (retryOrphans p cfg ctx.now batch).accepted = p.accepted ∧
    revalidatePending (retryOrphans p cfg ctx.now batch) utxo cfg ctx lists oracle obs =
      let result := accept { retryOrphans p cfg ctx.now batch with pending := rest }
        utxo cfg ctx lists oracle obs { orphan.request with acceptTime := ctx.now }
      (result.1, some result.2) := by
  exact ⟨rfl, pending_reuses_accept (retryOrphans p cfg ctx.now batch) cfg ctx utxo lists oracle obs
    ⟨{ orphan.request with acceptTime := ctx.now }, ctx.now⟩ rest scheduled⟩

/-- A stopped trace contains only stages actually present in its ordered list.
This helper covers every refusal, defer and explicit model decline uniformly.
[SRC] src/validation.cpp:1031–1494 at 6504a3af. -/
theorem run_stages_trace_subset (stages : List (AdmissionStage × (AdmissionWork → AdmissionStep)))
    (w : AdmissionWork) : (runAdmissionStages stages w).2.2 ⊆ stages.map Prod.fst := by
  induction stages generalizing w with
  | nil => simp [runAdmissionStages]
  | cons stage rest ih =>
    rcases stage with ⟨name, check⟩
    rcases hcheck : check w with ⟨next, outcome⟩
    cases outcome with
    | some result => simp [runAdmissionStages, hcheck]
    | none =>
      simpa [runAdmissionStages, hcheck] using List.cons_subset_cons name (ih next)

/-- If an ordered stage list continues throughout, its trace is the whole list.
Thus the successful validation prefix ends in scripts, before insertion.
[SRC] src/validation.cpp:1031–1485 at 6504a3af. -/
theorem run_stages_success_trace (stages : List (AdmissionStage × (AdmissionWork → AdmissionStep)))
    (w : AdmissionWork) (h : (runAdmissionStages stages w).2.1 = none) :
    (runAdmissionStages stages w).2.2 = stages.map Prod.fst := by
  induction stages generalizing w with
  | nil => rfl
  | cons stage rest ih =>
    rcases stage with ⟨name, check⟩
    rcases hcheck : check w with ⟨next, outcome⟩
    cases outcome with
    | some result => simp [runAdmissionStages, hcheck] at h
    | none =>
      simp only [runAdmissionStages, hcheck] at h ⊢
      exact congrArg (name :: ·) (ih next h)

/-- Every accept trace stopped during validation omits detector insertion.
Inventory suppression also has no detector stage. Unlike independence alone,
this statement forbids insertion in every earlier stopped trace.
[SRC] src/validation.cpp:1481–1494 and src/txmempool.h:1386–1390 at 6504a3af. -/
theorem accept_stopped_before_detector (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (obs : DetectorObservation) (request : TxRequest) (next : AdmissionWork)
    (outcome : TxOutcome) (trace : List AdmissionStage)
    (h : beforeDetector (request.configOverride.getD cfg) ctx lists oracle
      { pool := p, view := mempoolView p utxo, request } = (next, some outcome, trace)) :
    AdmissionStage.detector ∉ (acceptWithTrace p utxo cfg ctx lists oracle obs request).2.2 := by
  have sub := run_stages_trace_subset
    (admissionPrefix (request.configOverride.getD cfg) ctx ++
      [(.conflict, stageConflict), (.inputs, stageInputs (request.configOverride.getD cfg) ctx),
       (.sequence, stageSequence (request.configOverride.getD cfg) ctx),
       (.inputStandard, stageInputStandard (request.configOverride.getD cfg) ctx),
       (.sigops, stageSigops (request.configOverride.getD cfg) ctx),
       (.fee, stageFee (request.configOverride.getD cfg) ctx),
       (.ancestors, stageAncestors (request.configOverride.getD cfg) ctx),
       (.scripts, stageScripts (request.configOverride.getD cfg) ctx lists oracle)])
    { pool := p, view := mempoolView p utxo, request }
  change (beforeDetector _ _ _ _ _).2.2 ⊆ _ at sub
  rw [h] at sub
  have absent : AdmissionStage.detector ∉ trace := by
    intro mem
    have := sub mem
    simp [admissionPrefix] at this
  simp only [acceptWithTrace]
  split <;> simp [h, absent]

/-- A successful validation prefix reaches detector insertion immediately after
scripts, even if the detector or commit then refuses the request. The explicit
submission premise excludes inventory suppression. The suffix is harness trace
metadata and makes no promise of successful commit.
[SRC] src/validation.cpp:1481–1494 and src/txmempool.h:1386–1390 at 6504a3af. -/
theorem accept_detector_after_scripts (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (obs : DetectorObservation) (request : TxRequest) (next : AdmissionWork)
    (trace : List AdmissionStage)
    (submitted : (request.source == .p2p && p.recentRejects.contains (BsvScript.Sighash.txid request.tx)) = false)
    (h : beforeDetector (request.configOverride.getD cfg) ctx lists oracle
      { pool := p, view := mempoolView p utxo, request } = (next, none, trace)) :
    ∃ suffix, (acceptWithTrace p utxo cfg ctx lists oracle obs request).2.2 =
      [.regular, .standard, .finality, .alreadyKnown, .conflict, .inputs,
       .sequence, .inputStandard, .sigops, .fee, .ancestors, .scripts, .detector] ++ suffix := by
  have full := run_stages_success_trace _ _ (congrArg (fun r => r.2.1) h)
  change (beforeDetector _ _ _ _ _).2.2 = _ at full
  rw [h] at full
  simp only [admissionPrefix, List.map_cons, List.map_nil, List.cons_append, List.nil_append] at full
  simp only [acceptWithTrace, submitted, Bool.false_eq_true, ↓reduceIte, h]
  rcases hd : stageDetector obs next with ⟨afterDetector, outcome⟩
  cases outcome with
  | some result => exact ⟨[], by simp [runAdmissionStages, hd, full]⟩
  | none =>
    rcases hc : stageCommit (request.configOverride.getD cfg) ctx afterDetector with ⟨committed, result⟩
    cases result <;> exact ⟨[.commit], by simp [runAdmissionStages, hd, hc, full]⟩

end BsvChain.Properties.Mempool
