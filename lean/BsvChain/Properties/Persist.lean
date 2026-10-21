import BsvChain.Persist
import BsvChain.Properties.Mempool

/-!
# Persistence laws (#81)

What a restart keeps and why. The load re-validates every record through the
admission machine of #62, so a transaction in the pool after a start was
accepted by `accept` at its own load step, against the load's tip and clock;
a record the load dropped carries its reason; and a run with the setting off
neither reads nor writes the files. The growth law of admission
(`accept_ids`) is the step that carries the load's survivors back to
admission's verdicts. [SRC] src/txmempool.cpp:3154-3344,
src/time_locked_mempool.cpp:247-378, src/init.cpp:237-240,1901-1905 and
src/validation.cpp:895-946,1009-1505 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.

[D] Owed on #81, none claimed here: the load law over `DumpTopological`
(a load of a `DumpTopological` dump drops no child as `missingInputs` when
its parent's step was kept), the held survivors' law `held_survivor_at_load`
(every held-pool survivor of a start has its own `kept .heldNonFinal` step),
and the restart's round trip (with the setting on, the same tip and coins and
unexpired records, a start keeps every record of the dump).
-/

namespace BsvChain.Properties.Persist
open BsvChain BsvChain.Persist BsvScript.Tx

/-- The accepted pool's ids, in order. -/
def ids (p : Mempool) : List TxId := p.accepted.map (·.id)

/-- The entry a stage builds carries the request's own transaction. -/
def EntryTx (w : AdmissionWork) : Prop := ∀ e, w.entry = some e → e.tx = w.request.tx

/-- A stage's law: the request is untouched, the built entry stays the
request's, and an id enters the accepted pool only with the accepted verdict
and only as the request's own id. -/
def Grows (w : AdmissionWork) (r : AdmissionStep) : Prop :=
  EntryTx r.1 ∧ r.1.request = w.request ∧
    ∀ id ∈ ids r.1.pool, id ∈ ids w.pool ∨
      (r.2 = some (.completed .accepted) ∧ id = BsvScript.Sighash.txid w.request.tx)

/-- Every work item satisfying `EntryTx` steps by `Grows`. -/
def StageGrows (s : AdmissionWork → AdmissionStep) : Prop := ∀ w, EntryTx w → Grows w (s w)

/-- A checked step returns its work unchanged; only the outcome differs. -/
theorem checkedStep_fst (w : AdmissionWork) (x : Except Reject Unit) : (checkedStep w x).1 = w := by
  cases x <;> rfl

/-- A step that keeps the accepted pool, the request and the built entry satisfies the growth law. -/
theorem grows_of_frame (w : AdmissionWork) (r : AdmissionStep) (hw : EntryTx w)
    (ha : r.1.pool.accepted = w.pool.accepted) (hr : r.1.request = w.request)
    (he : r.1.entry = w.entry) : Grows w r := by
  refine ⟨?_, hr, ?_⟩
  · intro e h; rw [hr]; exact hw e (he ▸ h)
  · intro id h; left; simpa [ids, ha] using h

/-- A step that returns its input work satisfies the growth law. -/
theorem grows_of_eq (w : AdmissionWork) (r : AdmissionStep) (hw : EntryTx w) (h : r.1 = w) : Grows w r :=
  grows_of_frame w r hw (by rw [h]) (by rw [h]) (by rw [h])

/-- The rolling fee's decay leaves the accepted pool unchanged. -/
theorem decayRollingFee_accepted (cfg : NodeConfig) (a : PoolAccounting) (now : Int) (p : Mempool) :
    (decayRollingFee cfg a now p).accepted = p.accepted := by
  unfold decayRollingFee; try dsimp only
  split <;> rfl

/-- Limiting the orphan pool leaves the accepted pool unchanged. -/
theorem limitOrphans_accepted (p : Mempool) (cfg : NodeConfig) (now : Int)
    (choose : List OrphanEntry → Nat) (skip : Bool) :
    (limitOrphans p cfg now choose skip).accepted = p.accepted := by
  unfold limitOrphans
  simp only [Id.run]
  split <;> rfl

/-- Retaining an orphan leaves the accepted pool unchanged. -/
theorem retainOrphan_accepted (p : Mempool) (cfg : NodeConfig) (ctx : AdmissionContext) (r : TxRequest) :
    (retainOrphan p cfg ctx r).accepted = p.accepted := by
  unfold retainOrphan
  try dsimp only
  repeat' split
  all_goals (try rw [limitOrphans_accepted]) <;> rfl

/-- A script failure returns its work unchanged; only the outcome differs. -/
theorem scriptFailure_fst (w : AdmissionWork) (r : Reject) : (scriptFailure w r).1 = w := by
  unfold scriptFailure; split
  · rfl
  · exact checkedStep_fst _ _

/-- Deferring work keeps the accepted pool, the request and the built entry. -/
theorem deferWork_frame (w : AdmissionWork) (now : Int) :
    (deferWork w now).1.pool.accepted = w.pool.accepted ∧ (deferWork w now).1.request = w.request ∧
      (deferWork w now).1.entry = w.entry := by
  unfold deferWork; split <;> simp [checkedStep_fst]

/-- Deferring work satisfies the growth law: it adds no id to the accepted pool. -/
theorem deferWork_grows (w : AdmissionWork) (now : Int) (hw : EntryTx w) : Grows w (deferWork w now) :=
  grows_of_frame w _ hw (deferWork_frame w now).1 (deferWork_frame w now).2.1 (deferWork_frame w now).2.2

/-- Inserting into the held pool keeps the accepted pool, the request and the built entry. -/
theorem insertNonFinal_frame (w : AdmissionWork) (cfg : NodeConfig) (ctx : AdmissionContext)
    (entry : MempoolEntry) (rate : NonFinalRate) :
    (insertNonFinal w cfg ctx entry rate).1.pool.accepted = w.pool.accepted ∧
    (insertNonFinal w cfg ctx entry rate).1.request = w.request ∧
    (insertNonFinal w cfg ctx entry rate).1.entry = w.entry := by
  unfold insertNonFinal
  try dsimp only
  split <;> simp [checkedStep_fst, removeNonFinal]

/-- The regular-transaction stage only refuses or passes; it adds no id to the accepted pool. -/
theorem stageRegular_grows (cfg : NodeConfig) (ctx : AdmissionContext) : StageGrows (stageRegular cfg ctx) := by
  intro w hw; unfold stageRegular; try dsimp only
  repeat' split
  all_goals first
    | exact grows_of_eq _ _ hw (checkedStep_fst _ _)
    | exact grows_of_eq _ _ hw (scriptFailure_fst _ _)
    | exact grows_of_eq _ _ hw rfl
    | exact deferWork_grows _ _ hw
    | exact grows_of_frame _ _ hw rfl rfl rfl
    | (apply grows_of_frame _ _ hw <;> simp [checkedStep_fst, decayRollingFee_accepted,
          retainOrphan_accepted, insertNonFinal_frame, removeNonFinal])

/-- The standardness stage only refuses or passes; it adds no id to the accepted pool. -/
theorem stageStandard_grows (cfg : NodeConfig) (ctx : AdmissionContext) : StageGrows (stageStandard cfg ctx) := by
  intro w hw; unfold stageStandard; try dsimp only
  repeat' split
  all_goals first
    | exact grows_of_eq _ _ hw (checkedStep_fst _ _)
    | exact grows_of_eq _ _ hw (scriptFailure_fst _ _)
    | exact grows_of_eq _ _ hw rfl
    | exact deferWork_grows _ _ hw
    | exact grows_of_frame _ _ hw rfl rfl rfl
    | (apply grows_of_frame _ _ hw <;> simp [checkedStep_fst, decayRollingFee_accepted,
          retainOrphan_accepted, insertNonFinal_frame, removeNonFinal])

/-- The finality stage refuses, holds or passes; it adds no id to the accepted pool. -/
theorem stageFinality_grows (cfg : NodeConfig) (ctx : AdmissionContext) : StageGrows (stageFinality cfg ctx) := by
  intro w hw; unfold stageFinality; try dsimp only
  repeat' split
  all_goals first
    | exact grows_of_eq _ _ hw (checkedStep_fst _ _)
    | exact grows_of_eq _ _ hw (scriptFailure_fst _ _)
    | exact grows_of_eq _ _ hw rfl
    | exact deferWork_grows _ _ hw
    | exact grows_of_frame _ _ hw rfl rfl rfl
    | (apply grows_of_frame _ _ hw <;> simp [checkedStep_fst, decayRollingFee_accepted,
          retainOrphan_accepted, insertNonFinal_frame, removeNonFinal])

/-- The already-known stage only refuses or passes; it adds no id to the accepted pool. -/
theorem stageAlreadyKnown_grows : StageGrows stageAlreadyKnown := by
  intro w hw; unfold stageAlreadyKnown; try dsimp only
  repeat' split
  all_goals first
    | exact grows_of_eq _ _ hw (checkedStep_fst _ _)
    | exact grows_of_eq _ _ hw (scriptFailure_fst _ _)
    | exact grows_of_eq _ _ hw rfl
    | exact deferWork_grows _ _ hw
    | exact grows_of_frame _ _ hw rfl rfl rfl
    | (apply grows_of_frame _ _ hw <;> simp [checkedStep_fst, decayRollingFee_accepted,
          retainOrphan_accepted, insertNonFinal_frame, removeNonFinal])

/-- The conflict stage only refuses or passes; it adds no id to the accepted pool. -/
theorem stageConflict_grows : StageGrows stageConflict := by
  intro w hw; unfold stageConflict; try dsimp only
  repeat' split
  all_goals first
    | exact grows_of_eq _ _ hw (checkedStep_fst _ _)
    | exact grows_of_eq _ _ hw (scriptFailure_fst _ _)
    | exact grows_of_eq _ _ hw rfl
    | exact deferWork_grows _ _ hw
    | exact grows_of_frame _ _ hw rfl rfl rfl
    | (apply grows_of_frame _ _ hw <;> simp [checkedStep_fst, decayRollingFee_accepted,
          retainOrphan_accepted, insertNonFinal_frame, removeNonFinal])

/-- The inputs stage refuses, retains an orphan or passes; it adds no id to the accepted pool. -/
theorem stageInputs_grows (cfg : NodeConfig) (ctx : AdmissionContext) : StageGrows (stageInputs cfg ctx) := by
  intro w hw; unfold stageInputs; try dsimp only
  repeat' split
  all_goals first
    | exact grows_of_eq _ _ hw (checkedStep_fst _ _)
    | exact grows_of_eq _ _ hw (scriptFailure_fst _ _)
    | exact grows_of_eq _ _ hw rfl
    | exact deferWork_grows _ _ hw
    | exact grows_of_frame _ _ hw rfl rfl rfl
    | (apply grows_of_frame _ _ hw <;> simp [checkedStep_fst, decayRollingFee_accepted,
          retainOrphan_accepted, insertNonFinal_frame, removeNonFinal])

/-- The sequence-lock stage only refuses or passes; it adds no id to the accepted pool. -/
theorem stageSequence_grows (cfg : NodeConfig) (ctx : AdmissionContext) : StageGrows (stageSequence cfg ctx) := by
  intro w hw; unfold stageSequence; try dsimp only
  repeat' split
  all_goals first
    | exact grows_of_eq _ _ hw (checkedStep_fst _ _)
    | exact grows_of_eq _ _ hw (scriptFailure_fst _ _)
    | exact grows_of_eq _ _ hw rfl
    | exact deferWork_grows _ _ hw
    | exact grows_of_frame _ _ hw rfl rfl rfl
    | (apply grows_of_frame _ _ hw <;> simp [checkedStep_fst, decayRollingFee_accepted,
          retainOrphan_accepted, insertNonFinal_frame, removeNonFinal])

/-- The input-standardness stage only refuses or passes; it adds no id to the accepted pool. -/
theorem stageInputStandard_grows (cfg : NodeConfig) (ctx : AdmissionContext) :
    StageGrows (stageInputStandard cfg ctx) := by
  intro w hw; unfold stageInputStandard; try dsimp only
  repeat' split
  all_goals first
    | exact grows_of_eq _ _ hw (checkedStep_fst _ _)
    | exact grows_of_eq _ _ hw (scriptFailure_fst _ _)
    | exact grows_of_eq _ _ hw rfl
    | exact deferWork_grows _ _ hw
    | exact grows_of_frame _ _ hw rfl rfl rfl
    | (apply grows_of_frame _ _ hw <;> simp [checkedStep_fst, decayRollingFee_accepted,
          retainOrphan_accepted, insertNonFinal_frame, removeNonFinal])

/-- The signature-operation stage only refuses or passes; it adds no id to the accepted pool. -/
theorem stageSigops_grows (cfg : NodeConfig) (ctx : AdmissionContext) : StageGrows (stageSigops cfg ctx) := by
  intro w hw; unfold stageSigops; try dsimp only
  repeat' split
  all_goals first
    | exact grows_of_eq _ _ hw (checkedStep_fst _ _)
    | exact grows_of_eq _ _ hw (scriptFailure_fst _ _)
    | exact grows_of_eq _ _ hw rfl
    | exact deferWork_grows _ _ hw
    | exact grows_of_frame _ _ hw rfl rfl rfl
    | (apply grows_of_frame _ _ hw <;> simp [checkedStep_fst, decayRollingFee_accepted,
          retainOrphan_accepted, insertNonFinal_frame, removeNonFinal])

/-- The fee stage only refuses or passes; it adds no id to the accepted pool. -/
theorem stageFee_grows (cfg : NodeConfig) (ctx : AdmissionContext) : StageGrows (stageFee cfg ctx) := by
  intro w hw; unfold stageFee; try dsimp only
  repeat' split
  all_goals first
    | exact grows_of_eq _ _ hw (checkedStep_fst _ _)
    | exact grows_of_eq _ _ hw (scriptFailure_fst _ _)
    | exact grows_of_eq _ _ hw rfl
    | exact deferWork_grows _ _ hw
    | exact grows_of_frame _ _ hw rfl rfl rfl
    | (apply grows_of_frame _ _ hw <;> simp [checkedStep_fst, decayRollingFee_accepted,
          retainOrphan_accepted, insertNonFinal_frame, removeNonFinal])

/-- The ancestor stage builds the request's entry or refuses; it adds no id to the accepted pool. -/
theorem stageAncestors_grows (cfg : NodeConfig) (ctx : AdmissionContext) : StageGrows (stageAncestors cfg ctx) := by
  intro w hw; unfold stageAncestors; try dsimp only
  split
  · first | exact grows_of_eq _ _ hw (checkedStep_fst _ _)
          | exact grows_of_eq _ _ hw (scriptFailure_fst _ _)
          | exact grows_of_eq _ _ hw rfl
          | exact deferWork_grows _ _ hw
          | exact grows_of_frame _ _ hw rfl rfl rfl
          | (apply grows_of_frame _ _ hw <;> simp [checkedStep_fst, decayRollingFee_accepted,
              retainOrphan_accepted, insertNonFinal_frame, removeNonFinal])
  · refine ⟨?_, rfl, ?_⟩
    · intro e h; simp only [Option.some.injEq] at h; rw [← h]
    · intro id h; left; exact h

/-- The script stage refuses, defers or passes; it adds no id to the accepted pool. -/
theorem stageScripts_grows (cfg : NodeConfig) (ctx : AdmissionContext) (lists : FrozenLists)
    (oracle : ScriptOracle) : StageGrows (stageScripts cfg ctx lists oracle) := by
  intro w hw; unfold stageScripts; try simp only [Id.run]; try dsimp only
  repeat' split
  all_goals first
    | exact grows_of_eq _ _ hw (checkedStep_fst _ _)
    | exact grows_of_eq _ _ hw (scriptFailure_fst _ _)
    | exact grows_of_eq _ _ hw rfl
    | exact deferWork_grows _ _ hw
    | exact grows_of_frame _ _ hw rfl rfl rfl
    | (apply grows_of_frame _ _ hw <;> simp [checkedStep_fst, decayRollingFee_accepted,
          retainOrphan_accepted, insertNonFinal_frame, removeNonFinal])

/-- The double-spend detector's stage only refuses or passes; it adds no id to the accepted pool. -/
theorem stageDetector_grows (obs : DetectorObservation) : StageGrows (stageDetector obs) := by
  intro w hw; unfold stageDetector; try dsimp only
  repeat' split
  all_goals first
    | exact grows_of_eq _ _ hw (checkedStep_fst _ _)
    | exact grows_of_eq _ _ hw (scriptFailure_fst _ _)
    | exact grows_of_eq _ _ hw rfl
    | exact deferWork_grows _ _ hw
    | exact grows_of_frame _ _ hw rfl rfl rfl
    | (apply grows_of_frame _ _ hw <;> simp [checkedStep_fst, decayRollingFee_accepted,
          retainOrphan_accepted, insertNonFinal_frame, removeNonFinal])

/-- Raising the rolling fee leaves the accepted pool unchanged. -/
theorem bumpRollingFee_accepted (cfg : NodeConfig) (p : Mempool) (rate : Int) :
    (bumpRollingFee cfg p rate).accepted = p.accepted := by
  unfold bumpRollingFee; try dsimp only
  repeat' split
  all_goals rfl

/-- Removing staged entries only removes: every id left was in the pool before. -/
theorem remove_staged_mem (p : Mempool) (cfg : NodeConfig) (ids' : List TxId) (id : TxId)
    (h : id ∈ ids (removeStaged p cfg ids')) : id ∈ ids p := by
  simp only [ids] at h ⊢
  rw [BsvChain.Properties.Mempool.remove_staged_ids] at h
  obtain ⟨e, he, rfl⟩ := List.mem_map.mp h
  exact List.mem_map.mpr ⟨e, List.mem_of_mem_filter he, rfl⟩

/-- The size limit's trim loop only removes: every id left was in the pool before. -/
theorem trimLoop_ids (cfg : NodeConfig) (a : PoolAccounting) (limit fuel : Nat) (p : Mempool)
    (rate : Int) (evicted : Bool) : ∀ id ∈ ids (trimLoop cfg a limit fuel p rate evicted), id ∈ ids p := by
  induction fuel generalizing p rate evicted with
  | zero =>
    intro id h
    simp only [trimLoop] at h
    split at h
    · simpa [ids, bumpRollingFee_accepted] using h
    · exact h
  | succ n ih =>
    intro id h
    simp only [trimLoop] at h
    split at h
    · split at h
      · simpa [ids, bumpRollingFee_accepted] using h
      · exact h
    · split at h
      · split at h
        · simpa [ids, bumpRollingFee_accepted] using h
        · exact h
      · exact remove_staged_mem p cfg _ id (ih _ _ _ id h)

/-- The commit's maintenance (expiry, then the size limit) only removes ids from the accepted pool. -/
theorem limitPool_ids (p : Mempool) (cfg : NodeConfig) (a : PoolAccounting) (now : Int) :
    ∀ id ∈ ids (limitPool p cfg a now), id ∈ ids p := by
  intro id h
  have hexp : ∀ id ∈ ids (expire p cfg now), id ∈ ids p :=
    fun id h => remove_staged_mem p cfg _ id h
  unfold limitPool at h
  try dsimp only at h
  split at h
  · exact hexp id (trimLoop_ids cfg a _ _ _ _ _ id h)
  · exact hexp id h

/-- Adding an entry appends exactly its id to the accepted pool's ids. -/
theorem addUnchecked_ids (p : Mempool) (cfg : NodeConfig) (entry : MempoolEntry) :
    ids (addUnchecked p cfg entry) = ids p ++ [entry.id] := by
  unfold addUnchecked
  simp only [ids]
  rw [BsvChain.Properties.Mempool.promote_loop_ids]
  simp [reindex, MempoolEntry.id]

/-- The commit's accepted branch: the verdict is accepted exactly when the new
entry is still in the pool after the size limit, and the limit only removes. -/
theorem commit_tail (w : AdmissionWork) (hw : EntryTx w) (entry : MempoolEntry)
    (htx : entry.tx = w.request.tx) (q : Mempool)
    (hq : ∀ id ∈ ids q, id ∈ ids w.pool ∨ id = entry.id) :
    Grows w (if q.accepted.any (fun e => e.id == entry.id) then ({ w with pool := q }, some (.completed .accepted))
      else checkedStep { w with pool := q } (.error ⟨.node 0x42, "mempool full"⟩)) := by
  split
  · refine ⟨fun e h => hw e h, rfl, ?_⟩
    intro id h
    rcases hq id h with h | h
    · exact Or.inl h
    · exact Or.inr ⟨rfl, by rw [h, MempoolEntry.id, htx]⟩
  · rename_i hnot
    refine ⟨fun e h => by rw [checkedStep_fst] at h ⊢; exact hw e h, by rw [checkedStep_fst], ?_⟩
    intro id h
    rw [checkedStep_fst] at h
    rcases hq id h with h' | h'
    · exact Or.inl h'
    · exfalso
      apply hnot
      simp only [ids, List.mem_map] at h
      obtain ⟨e, he, rfl⟩ := h
      exact List.any_eq_true.mpr ⟨e, he, by simp [h']⟩

/-- The commit stage adds at most the request's own id, and only with the accepted verdict. -/
theorem stageCommit_grows (cfg : NodeConfig) (ctx : AdmissionContext) : StageGrows (stageCommit cfg ctx) := by
  intro w hw
  unfold stageCommit
  split
  · exact grows_of_eq w _ hw rfl
  · rename_i entry hentry
    have htx : entry.tx = w.request.tx := hw entry hentry
    split
    · repeat' split
      all_goals first
        | exact grows_of_eq _ _ hw (checkedStep_fst _ _)
        | exact grows_of_eq _ _ hw (scriptFailure_fst _ _)
        | exact grows_of_eq _ _ hw rfl
        | exact deferWork_grows _ _ hw
        | exact grows_of_frame _ _ hw rfl rfl rfl
        | (apply grows_of_frame _ _ hw <;> simp [checkedStep_fst, decayRollingFee_accepted,
              retainOrphan_accepted, insertNonFinal_frame, removeNonFinal])
    · try dsimp only
      refine commit_tail w hw entry htx _ ?_
      intro id h
      have h' : id ∈ ids (addUnchecked w.pool cfg entry) := by
        split at h
        · exact limitPool_ids _ _ _ _ id h
        · exact h
      rw [addUnchecked_ids] at h'
      simpa using h'

/-- Ordered stages keep the growth law: a stage that continues adds no id, so
only the stage that completes with the accepted verdict can. -/
theorem run_grows (stages : List (AdmissionStage × (AdmissionWork → AdmissionStep)))
    (h : ∀ x ∈ stages, StageGrows x.2) (w : AdmissionWork) (hw : EntryTx w) :
    EntryTx (runAdmissionStages stages w).1 ∧ (runAdmissionStages stages w).1.request = w.request ∧
    ∀ id ∈ ids (runAdmissionStages stages w).1.pool, id ∈ ids w.pool ∨
      ((runAdmissionStages stages w).2.1 = some (.completed .accepted) ∧
        id = BsvScript.Sighash.txid w.request.tx) := by
  induction stages generalizing w with
  | nil => exact ⟨hw, rfl, fun id h => Or.inl h⟩
  | cons x rest ih =>
    obtain ⟨stage, check⟩ := x
    have g : Grows w (check w) := h (stage, check) (List.mem_cons_self ..) w hw
    simp only [runAdmissionStages]
    rcases hc : check w with ⟨w1, _ | o⟩
    · rw [hc] at g
      obtain ⟨g1, g2, g3⟩ := g
      have r := ih (fun x hx => h x (List.mem_cons_of_mem _ hx)) w1 g1
      simp only
      refine ⟨r.1, r.2.1.trans g2, ?_⟩
      intro id hid
      rcases r.2.2 id hid with h1 | ⟨h1, h2⟩
      · rcases g3 id h1 with h3 | ⟨h3, _⟩
        · exact Or.inl h3
        · simp at h3
      · exact Or.inr ⟨h1, by rw [h2, g2]⟩
    · rw [hc] at g
      exact g

/-- `run_grows` read through an equation for the run's result. -/
theorem run_grows_eq (stages : List (AdmissionStage × (AdmissionWork → AdmissionStep)))
    (h : ∀ x ∈ stages, StageGrows x.2) (w : AdmissionWork) (hw : EntryTx w)
    (w' : AdmissionWork) (r : Option TxOutcome) (t : List AdmissionStage)
    (heq : runAdmissionStages stages w = (w', r, t)) :
    EntryTx w' ∧ w'.request = w.request ∧
    ∀ id ∈ ids w'.pool, id ∈ ids w.pool ∨ (r = some (.completed .accepted) ∧
      id = BsvScript.Sighash.txid w.request.tx) := by
  have g := run_grows stages h w hw
  rw [heq] at g
  exact g

/-- Finishing an admission leaves the accepted pool as the stages left it. -/
theorem finishAdmission_accepted (w : AdmissionWork) (o : TxOutcome) :
    (finishAdmission w o).accepted = w.pool.accepted := by
  unfold finishAdmission; try dsimp only
  repeat' split
  all_goals rfl

/-- Finishing a commit leaves the accepted pool as the stages left it. -/
theorem finishCommit_accepted (w : AdmissionWork) (o : TxOutcome) :
    (finishCommit w o).accepted = w.pool.accepted := by
  unfold finishCommit; split
  · rfl
  · exact finishAdmission_accepted w o

/-- Every stage before the detector satisfies the growth law. -/
theorem before_detector_grows (c : NodeConfig) (ctx : AdmissionContext) (lists : FrozenLists)
    (oracle : ScriptOracle) :
    ∀ x ∈ admissionPrefix c ctx ++
        [(.conflict, stageConflict), (.inputs, stageInputs c ctx), (.sequence, stageSequence c ctx),
         (.inputStandard, stageInputStandard c ctx), (.sigops, stageSigops c ctx),
         (.fee, stageFee c ctx), (.ancestors, stageAncestors c ctx),
         (.scripts, stageScripts c ctx lists oracle)], StageGrows x.2 := by
  intro x hx
  simp only [admissionPrefix, List.cons_append, List.nil_append, List.mem_cons,
    List.not_mem_nil, or_false] at hx
  rcases hx with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  · exact stageRegular_grows c ctx
  · exact stageStandard_grows c ctx
  · exact stageFinality_grows c ctx
  · exact stageAlreadyKnown_grows
  · exact stageConflict_grows
  · exact stageInputs_grows c ctx
  · exact stageSequence_grows c ctx
  · exact stageInputStandard_grows c ctx
  · exact stageSigops_grows c ctx
  · exact stageFee_grows c ctx
  · exact stageAncestors_grows c ctx
  · exact stageScripts_grows c ctx lists oracle

/-- The detector's stage and the commit stage satisfy the growth law. -/
theorem after_detector_grows (c : NodeConfig) (ctx : AdmissionContext) (obs : DetectorObservation) :
    ∀ x ∈ [(AdmissionStage.detector, stageDetector obs), (.commit, stageCommit c ctx)], StageGrows x.2 := by
  intro x hx
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hx
  rcases hx with rfl | rfl
  · exact stageDetector_grows obs
  · exact stageCommit_grows c ctx

/-- The traced admission's growth law: a new id is the request's own, with the accepted verdict. -/
theorem acceptWithTrace_ids (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig) (ctx : AdmissionContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (obs : DetectorObservation) (request : TxRequest) :
    ∀ id ∈ ids (acceptWithTrace p utxo cfg ctx lists oracle obs request).1, id ∈ ids p ∨
      ((acceptWithTrace p utxo cfg ctx lists oracle obs request).2.1 = .completed .accepted ∧
        id = BsvScript.Sighash.txid request.tx) := by
  intro id hid
  have hw0 : EntryTx { pool := p, view := mempoolView p utxo, request := request } := fun e h => by
    simp at h
  unfold acceptWithTrace beforeDetector at hid ⊢
  try dsimp only at hid ⊢
  split
  · rename_i hs
    rw [if_pos hs] at hid
    exact Or.inl hid
  · rename_i hs
    rw [if_neg hs] at hid
    have r1 := run_grows _ (before_detector_grows (request.configOverride.getD cfg) ctx lists oracle) _ hw0
    split
    · rename_i outcome heq
      rw [heq] at hid
      simp only [ids, finishAdmission_accepted] at hid
      rcases r1.2.2 id hid with h | ⟨h1, h2⟩
      · exact Or.inl h
      · rw [heq] at h1
        simp only [Option.some.injEq] at h1
        exact Or.inr ⟨h1, h2⟩
    · rename_i heq
      rw [heq] at hid
      simp only at hid ⊢
      have r2 := run_grows _ (after_detector_grows (request.configOverride.getD cfg) ctx obs) _ r1.1
      split at hid <;> simp only [ids, finishCommit_accepted, finishAdmission_accepted] at hid
      all_goals
        rcases r2.2.2 id hid with h | ⟨h1, h2⟩
        · rcases r1.2.2 id h with h' | ⟨h', _⟩
          · exact Or.inl h'
          · rw [heq] at h'; simp at h'
        · exact Or.inr ⟨by simp [h1], by rw [h2, r1.2.1]⟩

/-- The growth law of admission (#62): after `accept`, every id of the accepted
pool was there before, or the outcome is the accepted verdict and the id is the
request's own. Earlier stages and every refusal leave the accepted pool as it
was; maintenance at the commit only removes. This is what lets a load's
survivor be traced to the admission verdict of its own record.
[SRC] src/validation.cpp:895-946,1009-1505,1759-1866 and
src/txmempool.cpp:736-805,2130-2221,2734-2792 at 6504a3af. -/
theorem accept_ids (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig) (ctx : AdmissionContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (obs : DetectorObservation) (request : TxRequest) :
    ∀ id ∈ ids (accept p utxo cfg ctx lists oracle obs request).1, id ∈ ids p ∨
      ((accept p utxo cfg ctx lists oracle obs request).2 = .completed .accepted ∧
        id = BsvScript.Sighash.txid request.tx) := by
  have g := acceptWithTrace_ids p utxo cfg ctx lists oracle obs request
  rcases ht : acceptWithTrace p utxo cfg ctx lists oracle obs request with ⟨a, b, c⟩
  rw [ht] at g
  simp only [accept, ht]
  exact g

/-- A ledger line's admissible shape: kept lines carry admission's own
verdict, accepted or held, from an unexpired record; dropped lines are expired
with no validation, or carry admission's refusal. -/
def StepShape (lc : LoadContext) (s : LoadStep) : Prop :=
  let expiry : Int := expiryOf lc.cfg s.file
  (∀ v, s.fate = .kept v → s.outcome = some (.completed v) ∧
      (v = .accepted ∨ v = .heldNonFinal) ∧ s.time + expiry > lc.ctx.now) ∧
  (∀ r, s.fate = .dropped r → (r = .expired ∧ s.outcome = none ∧ s.time + expiry ≤ lc.ctx.now) ∨
      (∃ o, s.outcome = some o ∧ fateOf o = .dropped r ∧ s.time + expiry > lc.ctx.now))

/-- A kept fate is admission's own completed verdict, accepted or held. -/
theorem fateOf_kept (o : TxOutcome) (v : TxVerdict) (h : fateOf o = .kept v) :
    o = .completed v ∧ (v = .accepted ∨ v = .heldNonFinal) := by
  cases o with
  | completed verdict => cases verdict <;> simp_all [fateOf]
  | _ => simp [fateOf] at h

/-- One record's ledger line has the admissible shape of `StepShape`. -/
theorem loadOne_shape (lc : LoadContext) (file : PersistFile) (priority : TxPriority)
    (p : Mempool) (tx : Tx) (time : Int) :
    StepShape lc (loadOne lc file (expiryOf lc.cfg file) priority p tx time).2 := by
  unfold loadOne StepShape
  split
  · rename_i hlive
    simp only
    refine ⟨fun v hv => ?_, fun r hr => Or.inr ⟨_, rfl, hr, hlive⟩⟩
    obtain ⟨h1, h2⟩ := fateOf_kept _ v hv
    exact ⟨by rw [h1], h2, hlive⟩
  · rename_i hdead
    simp only
    refine ⟨fun v hv => by simp at hv, fun r hr => Or.inl ⟨?_, by simp, by omega⟩⟩
    simp only [LoadFate.dropped.injEq] at hr; exact hr.symm

/-- The step of one record: the kept id is the record's own. -/
theorem loadOne_ids (lc : LoadContext) (file : PersistFile) (expiry : Nat) (priority : TxPriority)
    (p : Mempool) (tx : Tx) (time : Int) :
    ∀ id ∈ ids (loadOne lc file expiry priority p tx time).1, id ∈ ids p ∨
      ((loadOne lc file expiry priority p tx time).2.fate = .kept .accepted ∧
        (loadOne lc file expiry priority p tx time).2.id = id) := by
  intro id h
  unfold loadOne at h ⊢
  split at h
  · rename_i hlive
    rw [if_pos hlive]
    rcases accept_ids p lc.utxo lc.cfg lc.ctx lc.lists lc.oracle lc.observation
      (fileRequest tx time priority) id h with h' | ⟨h1, h2⟩
    · exact Or.inl h'
    · right; refine ⟨by simp only; rw [h1]; rfl, h2.symm⟩
  · exact Or.inl h

/-- A fee delta leaves the accepted pool unchanged. -/
theorem prioritise_accepted (p : Mempool) (id : TxId) (d : Int) : (prioritise p id d).accepted = p.accepted := rfl

/-- Applying the residual deltas leaves the accepted pool unchanged. -/
theorem deltas_accepted (ds : List (TxId × Int)) (p : Mempool) :
    (ds.foldl (fun q (x : TxId × Int) => prioritise q x.1 x.2) p).accepted = p.accepted := by
  induction ds generalizing p with
  | nil => rfl
  | cons d ds ih => simp only [List.foldl]; rw [ih]; rfl

/-- What survives a run of records is traced to its own step. -/
def Traced (p0 p : Mempool) (steps : List LoadStep) : Prop :=
  ∀ id ∈ ids p, id ∈ ids p0 ∨ ∃ s ∈ steps, s.fate = .kept .accepted ∧ s.id = id

/-- Tracing composes over a run: one traced step followed by a traced rest is traced. -/
theorem traced_cons (p0 p1 p : Mempool) (step : LoadStep) (steps : List LoadStep)
    (one : ∀ id ∈ ids p1, id ∈ ids p0 ∨ (step.fate = .kept .accepted ∧ step.id = id))
    (rest : Traced p1 p steps) : Traced p0 p (step :: steps) := by
  intro id h
  rcases rest id h with h' | ⟨s, hs, hk, hi⟩
  · rcases one id h' with h'' | ⟨hk, hi⟩
    · exact Or.inl h''
    · exact Or.inr ⟨step, List.mem_cons_self .., hk, hi⟩
  · exact Or.inr ⟨s, List.mem_cons_of_mem _ hs, hk, hi⟩

/-- Shape composes over a run: one shaped step followed by shaped steps are all shaped. -/
theorem shaped_cons (lc : LoadContext) (step : LoadStep) (steps : List LoadStep)
    (one : StepShape lc step) (rest : ∀ s ∈ steps, StepShape lc s) : ∀ s ∈ step :: steps, StepShape lc s := by
  intro s hs
  simp only [List.mem_cons] at hs
  rcases hs with rfl | hs
  · exact one
  · exact rest s hs

/-- The accepted file's records: every survivor is traced to its own kept step, and every step is shaped. -/
theorem loadRecords_traced (lc : LoadContext) (rs : List DumpRecord) (p : Mempool) :
    Traced p (loadRecords lc p rs).1 (loadRecords lc p rs).2.1 ∧
    ∀ s ∈ (loadRecords lc p rs).2.1, StepShape lc s := by
  induction rs generalizing p with
  | nil => exact ⟨fun id h => Or.inl h, fun s h => by simp [loadRecords] at h⟩
  | cons r rs ih =>
    simp only [loadRecords]
    split
    · exact ⟨fun id h => Or.inl h, fun s h => by simp at h⟩
    · rename_i tx _
      try dsimp only
      have hp1 : ∀ q, q = (if r.feeDelta != 0 then prioritise p (BsvScript.Sighash.txid tx) r.feeDelta else p) →
          ids q = ids p := by
        intro q hq; rw [hq]; split <;> rfl
      have hq := hp1 _ rfl
      obtain ⟨t, sh⟩ := ih (loadOne lc .mempool (expiryOf lc.cfg .mempool) .high
        (if r.feeDelta != 0 then prioritise p (BsvScript.Sighash.txid tx) r.feeDelta else p) tx r.time).1
      refine ⟨traced_cons _ _ _ _ _ ?_ t, shaped_cons _ _ _ (loadOne_shape _ _ _ _ _ _) sh⟩
      intro id h
      rcases loadOne_ids _ _ _ _ _ _ _ id h with h' | h'
      · exact Or.inl (hq ▸ h')
      · exact Or.inr h'

/-- The accepted file, failures included: every survivor is traced and every step is shaped. -/
theorem loadMempoolFile_traced (lc : LoadContext) (p : Mempool) (d : Option MempoolDump) :
    Traced p (loadMempoolFile lc p d).1 (loadMempoolFile lc p d).2.1 ∧
    ∀ s ∈ (loadMempoolFile lc p d).2.1, StepShape lc s := by
  cases d with
  | none => exact ⟨fun id h => by simp [loadMempoolFile, clearPool, ids] at h, fun s h => by simp [loadMempoolFile] at h⟩
  | some d =>
    simp only [loadMempoolFile]
    split
    · exact ⟨fun id h => by simp [clearPool, ids] at h, fun s h => by simp at h⟩
    · have r := loadRecords_traced lc d.records p
      try dsimp only
      split
      · exact ⟨fun id h => by simp [clearPool, ids] at h, r.2⟩
      · try dsimp only
        split
        · refine ⟨fun id h => r.1 id ?_, r.2⟩
          simpa [ids, deltas_accepted] using h
        · exact ⟨fun id h => by simp [clearPool, ids] at h, r.2⟩

/-- The held file's records: every survivor is traced to its own kept step, and every step is shaped. -/
theorem loadNonFinalRecords_traced (lc : LoadContext) (rs : List NonFinalRecord) (p : Mempool) :
    Traced p (loadNonFinalRecords lc p rs).1 (loadNonFinalRecords lc p rs).2 ∧
    ∀ s ∈ (loadNonFinalRecords lc p rs).2, StepShape lc s := by
  induction rs generalizing p with
  | nil => exact ⟨fun id h => Or.inl h, fun s h => by simp [loadNonFinalRecords] at h⟩
  | cons r rs ih =>
    simp only [loadNonFinalRecords]
    try dsimp only
    obtain ⟨t, sh⟩ := ih (loadOne lc .nonFinal (expiryOf lc.cfg .nonFinal) _ p r.tx r.time).1
    exact ⟨traced_cons _ _ _ _ _ (loadOne_ids _ _ _ _ _ _ _) t,
      shaped_cons _ _ _ (loadOne_shape _ _ _ _ _ _) sh⟩

/-- The held file, absent or of another version included: survivors traced, steps shaped. -/
theorem loadNonFinalFile_traced (lc : LoadContext) (p : Mempool) (d : Option NonFinalDump) :
    Traced p (loadNonFinalFile lc p d).1 (loadNonFinalFile lc p d).2 ∧
    ∀ s ∈ (loadNonFinalFile lc p d).2, StepShape lc s := by
  cases d with
  | none => exact ⟨fun id h => Or.inl h, fun s h => by simp [loadNonFinalFile] at h⟩
  | some d =>
    simp only [loadNonFinalFile]
    split
    · exact ⟨fun id h => Or.inl h, fun s h => by simp at h⟩
    · exact loadNonFinalRecords_traced lc d.records p

/-- The whole load: every survivor of the empty start is traced to its own kept step, every step shaped. -/
theorem load_traced (lc : LoadContext) (dir : DataDir) :
    Traced (emptyPool lc.cfg) (load lc dir).pool (load lc dir).steps ∧
    ∀ s ∈ (load lc dir).steps, StepShape lc s := by
  unfold load
  try dsimp only
  have m := loadMempoolFile_traced lc (emptyPool lc.cfg) dir.mempool
  have n := loadNonFinalFile_traced lc (loadMempoolFile lc (emptyPool lc.cfg) dir.mempool).1 dir.nonFinal
  refine ⟨?_, ?_⟩
  · intro id h
    rcases n.1 id h with h' | ⟨s, hs, hk, hi⟩
    · rcases m.1 id h' with h'' | ⟨s, hs, hk, hi⟩
      · exact Or.inl h''
      · exact Or.inr ⟨s, List.mem_append_left _ hs, hk, hi⟩
    · exact Or.inr ⟨s, List.mem_append_right _ hs, hk, hi⟩
  · intro s hs
    rcases List.mem_append.mp hs with hs | hs
    · exact m.2 s hs
    · exact n.2 s hs

/-- **A survivor of the load was accepted at its own load step.** Every
transaction in the accepted pool after a start has a ledger line of the load,
for its own id, whose fate is kept with admission's accepted verdict: the
record was unexpired at the load's clock and `accept` admitted it against the
load's tip and coins. Nothing enters the accepted pool without re-validation;
the held pool's survivors are not stated here [D].
[SRC] src/txmempool.cpp:3154-3273, src/time_locked_mempool.cpp:287-378 and
src/init.cpp:1901-1905 at 6504a3af. -/
theorem survivor_accepted_at_load (pc : PersistConfig) (lc : LoadContext) (dir : DataDir) :
    ∀ e ∈ (start pc lc dir).pool.accepted, ∃ s ∈ (start pc lc dir).steps,
      s.id = e.id ∧ s.fate = .kept .accepted ∧
      s.outcome = some (.completed .accepted) := by
  intro e he
  have hid : e.id ∈ ids (start pc lc dir).pool := List.mem_map.mpr ⟨e, he, rfl⟩
  unfold start at hid ⊢
  split at hid
  · rename_i hon
    rw [if_pos hon]
    have t := load_traced lc dir
    rcases t.1 e.id hid with h | ⟨s, hs, hk, hi⟩
    · simp [emptyPool, ids] at h
    · exact ⟨s, hs, hi, hk, ((t.2 s hs).1 _ hk).1⟩
  · simp [emptyPool, ids] at hid

/-- **A record the load dropped names its reason.** Every ledger line of a
start is kept with admission's verdict (accepted or held, from an unexpired
record), or dropped as expired (never validated; entry time plus the file's
expiry not after the load's clock), or dropped with admission's own outcome:
missing inputs, the refusal's code and reason, or an incomplete outcome.
[SRC] src/txmempool.cpp:3209-3240 and src/time_locked_mempool.cpp:325-359 at 6504a3af. -/
theorem load_steps_shaped (pc : PersistConfig) (lc : LoadContext) (dir : DataDir) :
    ∀ s ∈ (start pc lc dir).steps, StepShape lc s := by
  unfold start
  split
  · exact (load_traced lc dir).2
  · intro s hs; simp at hs

/-- **Without the setting a start reads nothing.** The pool is the fresh
process's empty pool and the ledger is empty, whatever the data directory
holds. [SRC] src/init.cpp:1901-1905 at 6504a3af. -/
theorem start_without_persist (lc : LoadContext) (dir : DataDir) :
    start { persistMempool := false } lc dir = ⟨emptyPool lc.cfg, [], none⟩ := rfl

/-- **Without the setting a shutdown writes nothing**, so the files of an
earlier run with the setting stay in the data directory, and a later start
with the setting reads them. [SRC] src/init.cpp:237-240 at 6504a3af. -/
theorem shutdown_without_persist (p : Mempool) (dir : DataDir) (onDisk : List TxId) :
    shutdown { persistMempool := false } p dir onDisk = dir := rfl

/-- **The stale file.** A run with the setting, then a run without it, leaves
the earlier run's dump as the files the next start with the setting loads:
whatever the run without the setting held is not in them.
[SRC] src/init.cpp:237-240,1901-1905 at 6504a3af.
[D] Bodies the pool had moved to its transaction database are not in these
files; a start without the setting clears that database
(src/txmempool.cpp:3032-3037), so such a record fails the next load
(src/txmempool.cpp:3186-3193), outside this model. -/
theorem stale_file_after_run_without (p1 p2 : Mempool) (dir : DataDir) (od1 od2 : List TxId) :
    shutdown { persistMempool := false } p2 (shutdown {} p1 dir od1) od2 =
      { mempool := some (dumpMempool p1 od1), nonFinal := some (dumpNonFinal p1) } := rfl

/-- **The dump keeps the pool's order and entry times.** Its records are the
accepted entries in the pool's insertion order, each with its own entry time,
which the load passes back to admission as the acceptance time.
[SRC] src/txmempool.cpp:1851-1858,3307-3323,3200-3222 at 6504a3af. -/
theorem dump_order_and_times (p : Mempool) (onDisk : List TxId) :
    (dumpMempool p onDisk).records.map (·.id) = p.accepted.map (·.id) ∧
    (dumpMempool p onDisk).records.map (·.time) = p.accepted.map (·.time) := by
  simp [dumpMempool, List.map_map, Function.comp_def]

/-- **A topological pool writes a topological file.** The dump keeps the pool's
order, so when no entry spends an output of a later entry, no record's body
spends an output of a later record. The pool's order is the model's assumption
`PoolTopological` [D]. [SRC] src/txmempool.cpp:1851-1858,2386,3307-3323 at
6504a3af. -/
theorem dump_topological (p : Mempool) (onDisk : List TxId) (h : PoolTopological p) :
    DumpTopological (dumpMempool p onDisk) := by
  intro pre r post hrec tx hbody i hi
  simp only [dumpMempool] at hrec
  obtain ⟨l1, l2, hl, _, h2⟩ := List.map_eq_append_iff.mp hrec
  obtain ⟨e, post', rfl, he, hpost⟩ := List.map_eq_cons_iff.mp h2
  subst he
  have htx : e.tx = tx := by
    simp only at hbody
    split at hbody
    · exact absurd hbody (by simp)
    · exact Option.some.inj hbody
  have hids : post.map (·.id) = post'.map (·.id) := by
    rw [← hpost, List.map_map]; rfl
  rw [hids]
  exact h l1 e post' hl i (by rw [htx]; exact hi)

/-- **Residual deltas name no dumped record.** Each entry's delta travels with
its record; the map written after the records holds only ids outside the pool.
[SRC] src/txmempool.cpp:3282-3284,3324,3328 at 6504a3af. -/
theorem dump_residual_absent (p : Mempool) (onDisk : List TxId) :
    ∀ d ∈ (dumpMempool p onDisk).deltas, d.1 ∉ (dumpMempool p onDisk).records.map (·.id) := by
  intro d hd
  have := (dump_order_and_times p onDisk).1
  rw [this]
  simp only [dumpMempool, List.mem_filter] at hd
  simpa using hd.2

/-- **A load time is the request's acceptance time.** The record's entry time,
not the load's clock, is what admission stores, so expiry keeps counting from
the transaction's original arrival. [SRC] src/txmempool.cpp:3200-3222 and
src/time_locked_mempool.cpp:322-341 at 6504a3af. -/
theorem file_request_time (tx : Tx) (time : Int) (priority : TxPriority) :
    (fileRequest tx time priority).acceptTime = time ∧ (fileRequest tx time priority).source = .file := ⟨rfl, rfl⟩

end BsvChain.Properties.Persist
