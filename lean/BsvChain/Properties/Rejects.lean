import BsvChain.Rejects

/-!
# Laws of the reject cache and the time budgets (#71)

Every statement here is about node policy at bitcoin-sv v1.2.3,
6504a3aff65ba97c0f6c80962b033e35ecbfed4b; none is a block-validity claim.
The four the issue names: a remembered rejection draws silence on the P2P
path until the reset (`remembered_inv_silent`, `remembered_tx_suppressed`,
`validation_rejection_remembered`); the reset follows an observed tip change
and nothing else (`reset_follows_tip_change`, `no_reset_without_tip_change`);
a timed-out high-priority request keeps its state and lowers its priority
(`timeout_high_requeues_low`, `timeout_keeps_pool`); and the budget preserves
the available-budget result or stops with a timeout answer, a high-priority
timeout deferring and a low-priority timeout completing with
`too-long-validation-time` (`budget_changes_timing_only`,
`elapsed_changes_timing_only`). A cell is judged by its clock dependence, not
by its budget's value (`budget_judgment_judging_iff`), and an inventory
reading only when both rolling filters it consults are exact
(`inventory_judging_exact`).
[SRC] src/net/net_processing.cpp:930–961,3351–3408,
src/validation.cpp:1210–1233,1349–1355,1786–1836,2037–2048 and
src/txn_validator.cpp:633–641 at 6504a3af.

These insert and silence laws are proved at the routing and inventory-envelope
levels. Their composition through acceptance is owed: stage frame lemmas must
establish preservation of the request and recentRejectsTip. No theorem here
proves that acceptance-level composition.
-/

namespace BsvChain.Properties.Rejects
open BsvChain BsvScript.Tx BsvScript.Numbers

/-! ## The filter -/

/-- An inserted id is a member at once: the filter has no false negative for
its newest insertion.
[SRC] src/txn_recent_rejects.cpp:14–21 at 6504a3af. -/
theorem remember_contains (f : RejectFilter) (id : TxId) :
    (f.remember id).contains id = true := by
  simp [RejectFilter.remember, RejectFilter.contains]

/-- A reset filter has no member and no insertion count: it is wipe-free
whatever its capacity.
[SRC] src/txn_recent_rejects.cpp:24–27 and src/bloom.cpp:322–329 at 6504a3af. -/
theorem reset_empty (f : RejectFilter) (id : TxId) :
    f.reset.contains id = false ∧ f.reset.wipeFree = true := by
  simp [RejectFilter.reset, RejectFilter.contains, RejectFilter.wipeFree]

/-- For ANY configuration, the reject filter's generation is half the
configured capacity rounded up, and a filter built from a member list is
wipe-free exactly when the list's length is at most three generations.
[SRC] src/txn_recent_rejects.cpp:9–11, src/bloom.cpp:222–225,265–281 at 6504a3af. -/
theorem rejectFilter_wipe_free_iff (cfg : NodeConfig) (members : List TxId) :
    (rejectFilter cfg members).generationSize = (cfg.recentRejectCapacity + 1) / 2 ∧
    ((rejectFilter cfg members).wipeFree = true ↔
      members.length ≤ 3 * ((cfg.recentRejectCapacity + 1) / 2)) := by
  refine ⟨rfl, ?_⟩
  simp only [rejectFilter, RejectFilter.wipeFree, RejectFilter.generationSize]
  exact ⟨of_decide_eq_true, decide_eq_true⟩

/-- At the census defaults the wipe-free regime is 180,000 insertions between
two resets: three generations of 60,000. The general form is
`rejectFilter_wipe_free_iff`, for every configuration; this theorem is its
instance at the census defaults.
[SRC] src/txn_recent_rejects.cpp:9–11 and src/bloom.cpp:222–225 at 6504a3af. -/
theorem default_wipe_free_bound :
    (rejectFilter NodeConfig.defaults).generationSize = 60000 ∧
    3 * (rejectFilter NodeConfig.defaults).generationSize = 180000 := by
  decide

/-! ## The reset follows an observed tip change -/

/-- No reset without an observed tip change: an inventory test under the
recorded tip hash leaves the whole pool, the filter included, as it was.
[SRC] src/net/net_processing.cpp:935–942 at 6504a3af. -/
theorem no_reset_without_tip_change (p : Mempool) (tip : Bytes)
    (same : p.recentRejectsTip = some tip) : observeTip p tip = p := by
  simp [observeTip, same]

/-- An inventory test under a tip hash other than the recorded one empties
the filter, records the new hash and touches nothing else that decides a
transaction's fate.
[SRC] src/net/net_processing.cpp:935–942 and src/net/net.cpp:3563–3564
at 6504a3af. -/
theorem tip_change_resets (p : Mempool) (tip : Bytes)
    (changed : p.recentRejectsTip ≠ some tip) :
    (observeTip p tip).recentRejects = p.recentRejects.reset ∧
    (observeTip p tip).recentRejectsTip = some tip ∧
    (observeTip p tip).accepted = p.accepted ∧
    (observeTip p tip).nonFinal = p.nonFinal ∧
    (observeTip p tip).orphans = p.orphans ∧
    (observeTip p tip).pending = p.pending ∧
    (observeTip p tip).nonFinalRecentlyRemoved = p.nonFinalRecentlyRemoved := by
  simp [observeTip, changed]

/-- The record always names the tip of the last test, so a second test under
the same tip is the identity: the reset happens once per observed change.
[SRC] src/net/net_processing.cpp:935–942 at 6504a3af. -/
theorem observe_tip_idempotent (p : Mempool) (tip : Bytes) :
    observeTip (observeTip p tip) tip = observeTip p tip := by
  by_cases h : p.recentRejectsTip = some tip
  · simp [observeTip, h]
  · simp [observeTip, h]

/-! ## A remembered rejection draws silence on the P2P path -/

/-- Silence for an inventory. A txid in the filter, announced by a peer while
the recorded tip is still the observed tip, is not requested, and the pool is
returned unchanged. Because the pool is unchanged the premises hold again for
the next announcement: the silence lasts until a test observes another tip.
[SRC] src/net/net_processing.cpp:930–961,2479,2518–2519 at 6504a3af. -/
theorem remembered_inv_silent (p : Mempool) (obs : InventoryObservation) (id : TxId)
    (remembered : p.recentRejects.contains id = true)
    (sameTip : p.recentRejectsTip = some obs.tip) :
    receiveInv p obs id = (p, .silence) := by
  simp [receiveInv, observeTip, sameTip, knownTx, remembered]

/-- Silence for the body. The same transaction sent again by a peer under the
same recorded tip is dropped before validation: no verdict, no reject message,
the pool unchanged.
[SRC] src/net/net_processing.cpp:3351–3408 at 6504a3af. -/
theorem remembered_tx_suppressed (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (detector : DetectorObservation) (obs : InventoryObservation)
    (elapsed : ElapsedObservation) (tx : Tx)
    (remembered : p.recentRejects.contains (BsvScript.Sighash.txid tx) = true)
    (sameTip : p.recentRejectsTip = some obs.tip) :
    receiveP2PTx p utxo cfg ctx lists oracle detector obs elapsed tx = (p, .suppressed) := by
  simp [receiveP2PTx, observeTip, sameTip, knownTx, remembered]

/-- After a test observes another tip, an id with no declared bloom false
positive and no other known-transaction reason is requested again; the reject
filter is empty.
[SRC] src/net/net_processing.cpp:930–961 at 6504a3af. -/
theorem reset_follows_tip_change (p : Mempool) (obs : InventoryObservation) (id : TxId)
    (changed : p.recentRejectsTip ≠ some obs.tip)
    (noFalsePositive : obs.filterFalsePositive id = false)
    (unknownElsewhere : knownElsewhere p obs id = false) :
    (receiveInv p obs id).2 = .request ∧
    ∀ other, (receiveInv p obs id).1.recentRejects.contains other = false := by
  have known : knownElsewhere
      { p with recentRejects := p.recentRejects.reset, recentRejectsTip := some obs.tip } obs id = false := by
    simpa [knownElsewhere] using unknownElsewhere
  have empty : p.recentRejects.reset.contains id = false := (reset_empty _ _).1
  constructor
  · simp [receiveInv, observeTip, changed, knownTx, noFalsePositive, known, empty]
  · intro other
    simp [receiveInv, observeTip, changed, RejectFilter.reset, RejectFilter.contains]

/-! ## Which rejections are remembered -/

/-- A rejection that validation itself returns for a peer's request enters
the filter under the request's own txid.
[SRC] src/validation.cpp:1786–1797,2037–2048 at 6504a3af. -/
theorem validation_rejection_remembered (w : AdmissionWork) (code : RejectCode) (reason : String)
    (peer : w.request.source = .p2p) :
    (finishAdmission w (.completed (.rejected code reason))).recentRejects.contains
      (BsvScript.Sighash.txid w.request.tx) = true := by
  simp [finishAdmission, peer, remember_contains]

/-- A refusal by the commit is not remembered: the pool is returned as the
commit left it, the filter included.
[SRC] src/validation.cpp:1808–1836,2097–2136 at 6504a3af. -/
theorem commit_refusal_not_remembered (w : AdmissionWork) (code : RejectCode) (reason : String) :
    finishCommit w (.completed (.rejected code reason)) = w.pool := rfl

/-- No other source writes the filter when a request finishes: an RPC, reorg,
finalised or file request leaves it as validation left it, whatever the
outcome.
[SRC] src/validation.cpp:1786–1797 at 6504a3af. -/
theorem other_sources_never_remember (w : AdmissionWork) (outcome : TxOutcome)
    (notPeer : w.request.source ≠ .p2p) :
    (finishAdmission w outcome).recentRejects = w.pool.recentRejects := by
  unfold finishAdmission
  split <;> first | rfl | (split <;> rfl) | simp [notPeer]

/-- For a peer request, the predicate marks a scripts-stage completed rejection
as remembered; it excludes a commit refusal, a deferral and an orphan outcome.
The actual routing functions have separate laws.
[SRC] src/validation.cpp:1786–1836,2037–2048 at 6504a3af. -/
theorem remembers_matches_routing (w : AdmissionWork) (code : RejectCode) (reason : String)
    (peer : w.request.source = .p2p) :
    remembersRejection w.request.source (some .scripts) (.completed (.rejected code reason)) = true ∧
    remembersRejection w.request.source (some .commit) (.completed (.rejected code reason)) = false ∧
    remembersRejection w.request.source (some .scripts) .deferred = false ∧
    remembersRejection w.request.source (some .inputs) (.completed .orphan) = false := by
  simp [remembersRejection, peer]

/-- A stage list's trace begins with the head stage, whether that stage stops
or continues. -/
theorem run_stages_head (name : AdmissionStage) (check : AdmissionWork → AdmissionStep)
    (rest : List (AdmissionStage × (AdmissionWork → AdmissionStep))) (w : AdmissionWork) :
    (runAdmissionStages ((name, check) :: rest) w).2.2.head? = some name := by
  rcases hcheck : check w with ⟨next, outcome⟩
  cases outcome with
  | some result => simp [runAdmissionStages, hcheck]
  | none =>
    rcases hrest : runAdmissionStages rest next with ⟨last, result, trace⟩
    simp [runAdmissionStages, hcheck, hrest]

/-- A request that is not a peer's is never suppressed by the filter: its
trace begins with the regular validation stage even when its txid is remembered.
The synchronous RPC path does not consult the filter.
[SRC] src/rpc/rawtransaction.cpp:1586–1594,1625–1626 and
src/txn_validator.cpp:141–177 at 6504a3af. -/
theorem other_sources_bypass_filter (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (detector : DetectorObservation) (request : TxRequest)
    (notPeer : request.source ≠ .p2p) :
    (acceptWithTrace p utxo cfg ctx lists oracle detector request).2.2.head? = some .regular := by
  have loud : (request.source == .p2p &&
      p.recentRejects.contains (BsvScript.Sighash.txid request.tx)) = false := by
    simp [notPeer]
  have head : (beforeDetector (request.configOverride.getD cfg) ctx lists oracle
      { pool := p, view := mempoolView p utxo, request }).2.2.head? = some .regular := by
    simp only [beforeDetector, admissionPrefix, List.cons_append]
    exact run_stages_head _ _ _ _
  rcases hbefore : beforeDetector (request.configOverride.getD cfg) ctx lists oracle
      { pool := p, view := mempoolView p utxo, request } with ⟨next, result, trace⟩
  rw [hbefore] at head
  have hhead : trace.head? = some .regular := head
  cases result with
  | some outcome =>
    simp only [acceptWithTrace, loud, Bool.false_eq_true, ↓reduceIte, hbefore]
    exact hhead
  | none =>
    simp only [acceptWithTrace, loud, Bool.false_eq_true, ↓reduceIte, hbefore]
    rcases hd : stageDetector detector next with ⟨afterDetector, outcome⟩
    cases outcome with
    | some result => simp [runAdmissionStages, hd, List.head?_append, hhead]
    | none =>
      rcases hc : stageCommit (request.configOverride.getD cfg) ctx afterDetector with ⟨committed, result⟩
      cases result <;> simp [runAdmissionStages, hd, hc, List.head?_append, hhead]

/-- The remembered rejection as a status cell: a suppressed resubmission and
a deferral leave the journal's rejection receipts as they were, so the derived
status of a transaction rejected before stays `rejected`, with the earlier
code and reason, through every silent resubmission. The receipt is the
spec's bookkeeping; the node keeps membership only.
[SRC] src/txn_recent_rejects.h:31–36 and src/net/net_processing.cpp:3380,3394
at 6504a3af. -/
theorem silence_keeps_rejection_receipt (journal : TxJournal) (tx : Tx) :
    (recordTxOutcome journal tx .suppressed).rejected = journal.rejected ∧
    (recordTxOutcome journal tx .deferred).rejected = journal.rejected := ⟨rfl, rfl⟩

/-! ## The timeout transition -/

/-- The priority lattice is a two-element chain and the timeout's move goes
down it.
[SRC] src/txn_validation_data.h:28–33 and src/txn_validator.cpp:633–638
at 6504a3af. -/
theorem lowered_le (priority : TxPriority) :
    priority.lowered ≤ priority ∧ TxPriority.low ≤ TxPriority.high ∧
    ¬ TxPriority.high ≤ TxPriority.low := by
  cases priority <;> decide

/-- A timed-out high-priority request is answered by no verdict: the same
request, with every override, is queued again at low priority, and the stage
reports `deferred`.
[SRC] src/txn_validator.cpp:633–638 and src/validation.cpp:1214–1216 at 6504a3af. -/
theorem timeout_high_requeues_low (w : AdmissionWork) (now : Int)
    (high : w.request.priority = .high) :
    deferWork w now =
      ({ w with pool := { w.pool with pending := w.pool.pending ++ [⟨w.request.lowered, now⟩] } },
        some .deferred) := by
  simp [deferWork, high, TxRequest.lowered, TxPriority.lowered]

/-- For a high-priority request, the timeout keeps the pool's deciding state:
the accepted and held sets, the spent index, the orphans and the filter are untouched, the finish adds
nothing, and the rejection journal of the derived status records no rejection.
No rejection and no acceptance came out of this step.
[SRC] src/txn_validator.cpp:633–638 and src/validation.cpp:1786–1836 at 6504a3af. -/
theorem timeout_keeps_pool (w : AdmissionWork) (now : Int) (journal : TxJournal)
    (high : w.request.priority = .high) :
    (deferWork w now).2 = some .deferred ∧
    (deferWork w now).1.pool.accepted = w.pool.accepted ∧
    (deferWork w now).1.pool.nonFinal = w.pool.nonFinal ∧
    (deferWork w now).1.pool.mapNextTx = w.pool.mapNextTx ∧
    (deferWork w now).1.pool.orphans = w.pool.orphans ∧
    (deferWork w now).1.pool.recentRejects = w.pool.recentRejects ∧
    finishAdmission (deferWork w now).1 .deferred = (deferWork w now).1.pool ∧
    (recordTxOutcome journal w.request.tx .deferred).rejected = journal.rejected := by
  rw [timeout_high_requeues_low w now high]
  simp [finishAdmission, recordTxOutcome]

/-- For a low-priority request, the timeout completes with policy rejection
too-long-validation-time. A fully processed P2P validation refusal is
remembered when routed through finishAdmission; this theorem states the
timeout outcome only.
[SRC] src/txn_validator.cpp:639–641 and src/validation.cpp:1214–1216,2037–2048
at 6504a3af. -/
theorem timeout_low_rejects (w : AdmissionWork) (now : Int)
    (low : w.request.priority = .low) :
    deferWork w now =
      (w, some (.completed (.rejected (.node 0x40) "too-long-validation-time"))) := by
  simp [deferWork, low, checkedStep, rejectOutcome]

/-! ## The budget preserves the available-budget result or stops with a timeout answer -/

/-- The two answers a budget expiry can produce. -/
def TimeoutAnswer (outcome : TxOutcome) : Prop :=
  outcome = .deferred ∨
  outcome = .completed (.rejected (.node 0x40) "too-long-validation-time")

/-- Whatever the priority, the timeout's step ends in one of the two answers. -/
theorem defer_work_answer (w : AdmissionWork) (now : Int) :
    ∃ outcome, (deferWork w now).2 = some outcome ∧ TimeoutAnswer outcome := by
  cases h : w.request.priority
  · exact ⟨_, by rw [timeout_high_requeues_low w now h], Or.inl rfl⟩
  · exact ⟨_, by rw [timeout_low_rejects w now h], Or.inr rfl⟩

/-- Two stage functions agree, or the timed stage stops with a timeout answer. -/
def BudgetStep (timed plain : AdmissionWork → AdmissionStep) : Prop :=
  ∀ w, timed w = plain w ∨ ∃ outcome, (timed w).2 = some outcome ∧ TimeoutAnswer outcome

/-- Two ordered stage lists with the same names whose stages are related by
`BudgetStep`. -/
inductive BudgetStages :
    List (AdmissionStage × (AdmissionWork → AdmissionStep)) →
    List (AdmissionStage × (AdmissionWork → AdmissionStep)) → Prop
  | nil : BudgetStages [] []
  | cons {name timed plain rest rest'} :
      BudgetStep timed plain → BudgetStages rest rest' →
      BudgetStages ((name, timed) :: rest) ((name, plain) :: rest')

/-- Running related stage lists gives the same result, or the timed run
stops with a timeout answer. -/
theorem run_budget_stages {timed plain} (related : BudgetStages timed plain) (w : AdmissionWork) :
    runAdmissionStages timed w = runAdmissionStages plain w ∨
    ∃ outcome, (runAdmissionStages timed w).2.1 = some outcome ∧ TimeoutAnswer outcome := by
  induction related generalizing w with
  | nil => exact Or.inl rfl
  | @cons name f g rest rest' step _ ih =>
    rcases step w with same | ⟨outcome, stopped, answer⟩
    · rcases hg : g w with ⟨next, result⟩
      rw [hg] at same
      cases result with
      | some o => left; simp only [runAdmissionStages, same, hg]
      | none =>
        rcases ih next with tail | ⟨outcome, stopped, answer⟩
        · left; simp only [runAdmissionStages, same, hg, tail]
        · right
          rcases hrest : runAdmissionStages rest next with ⟨last, result, trace⟩
          rw [hrest] at stopped
          have found : result = some outcome := stopped
          refine ⟨outcome, ?_, answer⟩
          simp only [runAdmissionStages, same, hrest]
          exact found
    · right
      rcases hf : f w with ⟨next, result⟩
      rw [hf] at stopped
      have found : result = some outcome := stopped
      subst found
      exact ⟨outcome, by simp only [runAdmissionStages, hf], answer⟩

/-- A stage that agrees everywhere is related to itself. -/
theorem budget_step_of_eq {timed plain : AdmissionWork → AdmissionStep}
    (same : timed = plain) : BudgetStep timed plain := fun w => Or.inl (by rw [same])

/-- The era of an admission does not read the budget observation. -/
theorem admissionEra_budget (ctx : AdmissionContext) (budget : ValidationBudget) :
    admissionEra { ctx with budget } = admissionEra ctx := rfl

/-- Changing the budget observation leaves the admission's script configuration unchanged: that configuration reads the era and policy fields, not the budget. -/
theorem admissionScriptConfig_budget (cfg : NodeConfig) (ctx : AdmissionContext)
    (budget : ValidationBudget) :
    admissionScriptConfig cfg { ctx with budget } = admissionScriptConfig cfg ctx := rfl

/-- One script attempt does not read the budget observation: the polls are
the stage's, between attempts. -/
theorem admissionScriptAttempt_budget (cfg : NodeConfig) (ctx : AdmissionContext)
    (budget : ValidationBudget) :
    admissionScriptAttempt cfg { ctx with budget } = admissionScriptAttempt cfg ctx := rfl

/-- Stage 8 passes at once when non-standard outputs are accepted and the
request is unlimited or already low: no poll is reached.
[SRC] src/validation.cpp:1207,1225 at 6504a3af. -/
theorem input_standard_skips (cfg : NodeConfig) (ctx : AdmissionContext) (w : AdmissionWork)
    (skip : (BsvScript.TxPolicy.acceptsNonStandardOutput (admissionScriptConfig cfg ctx)
      (!(admissionEra ctx).genesisActive) &&
      (!w.request.useLimits || w.request.priority == .low)) = true) :
    stageInputStandard cfg ctx w = (w, none) := by
  unfold stageInputStandard
  dsimp only
  split
  · rfl
  · next h => exact absurd skip h

/-- Stage 8's poll: a limited request that reaches it with the inputs budget
expired takes the timeout's step.
[SRC] src/validation.cpp:1212–1216,1228–1232 at 6504a3af. -/
theorem input_standard_expired (cfg : NodeConfig) (ctx : AdmissionContext) (w : AdmissionWork)
    (reached : (BsvScript.TxPolicy.acceptsNonStandardOutput (admissionScriptConfig cfg ctx)
      (!(admissionEra ctx).genesisActive) &&
      (!w.request.useLimits || w.request.priority == .low)) = false)
    (limited : w.request.useLimits = true) (expired : ctx.budget = .inputsExpired) :
    stageInputStandard cfg ctx w = deferWork w ctx.now := by
  unfold stageInputStandard
  dsimp only
  split
  · next h => exact absurd (h.symm.trans reached) (by decide)
  · split
    · rfl
    · next h => exact absurd (by simp [limited, expired]) h

/-- Stage 8 of an unlimited request does not read the budget observation.
[SRC] src/validation.cpp:1225 at 6504a3af. -/
theorem input_standard_unlimited (cfg : NodeConfig) (ctx : AdmissionContext) (w : AdmissionWork)
    (budget : ValidationBudget) (unlimited : w.request.useLimits = false) :
    stageInputStandard cfg { ctx with budget } w =
      stageInputStandard cfg { ctx with budget := .available } w := by
  unfold stageInputStandard
  simp only [admissionEra_budget, admissionScriptConfig_budget, unlimited, Bool.false_and,
    Bool.false_eq_true, ↓reduceIte]
  try rfl

/-- Stage 8 reads the budget at one poll; when the poll fires, the stage is
the timeout's step.
[SRC] src/validation.cpp:1206–1233 at 6504a3af. -/
theorem input_standard_budget (cfg : NodeConfig) (ctx : AdmissionContext) (budget : ValidationBudget) :
    BudgetStep (stageInputStandard cfg { ctx with budget })
      (stageInputStandard cfg { ctx with budget := .available }) := by
  intro w
  cases budget
  case inputsExpired =>
    cases skip : (BsvScript.TxPolicy.acceptsNonStandardOutput (admissionScriptConfig cfg ctx)
        (!(admissionEra ctx).genesisActive) &&
        (!w.request.useLimits || w.request.priority == .low))
    · cases limited : w.request.useLimits
      · exact Or.inl (input_standard_unlimited cfg ctx w .inputsExpired limited)
      · right
        have fired : stageInputStandard cfg { ctx with budget := .inputsExpired } w =
            deferWork w ctx.now :=
          input_standard_expired cfg { ctx with budget := .inputsExpired } w skip limited rfl
        rw [fired]
        exact defer_work_answer w ctx.now
    · left
      have timed : stageInputStandard cfg { ctx with budget := .inputsExpired } w = (w, none) :=
        input_standard_skips cfg { ctx with budget := .inputsExpired } w skip
      have plain : stageInputStandard cfg { ctx with budget := .available } w = (w, none) :=
        input_standard_skips cfg { ctx with budget := .available } w skip
      rw [timed, plain]
  all_goals exact Or.inl rfl

/-- Stage 12 of an unlimited request does not read the budget observation.
[SRC] src/validation.cpp:990–1006 at 6504a3af. -/
theorem scripts_unlimited (cfg : NodeConfig) (ctx : AdmissionContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (w : AdmissionWork) (budget : ValidationBudget)
    (unlimited : w.request.useLimits = false) :
    stageScripts cfg { ctx with budget } lists oracle w =
      stageScripts cfg { ctx with budget := .available } lists oracle w := by
  unfold stageScripts
  simp only [admissionEra_budget, admissionScriptAttempt_budget, unlimited, Bool.false_and,
    Bool.false_eq_true, ↓reduceIte]
  try rfl

/-- Stage 12 of a limited request, by cases on the poll that fired: the stage
is the untimed stage or the timeout's step.
[SRC] src/validation.cpp:1335–1355,1414–1430,1444–1464 at 6504a3af. -/
theorem scripts_limited (cfg : NodeConfig) (ctx : AdmissionContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (w : AdmissionWork) (budget : ValidationBudget)
    (limited : w.request.useLimits = true) :
    stageScripts cfg { ctx with budget } lists oracle w =
      stageScripts cfg { ctx with budget := .available } lists oracle w ∨
    stageScripts cfg { ctx with budget } lists oracle w = deferWork w ctx.now := by
  have relay : (ValidationBudget.available == ValidationBudget.relayExpired) = false := by decide
  have block : (ValidationBudget.available == ValidationBudget.blockExpired) = false := by decide
  have mandatory : (ValidationBudget.available == ValidationBudget.mandatoryExpired) = false := by decide
  cases budget
  case available => exact Or.inl rfl
  case inputsExpired => exact Or.inl rfl
  case relayExpired =>
    unfold stageScripts
    simp only [admissionEra_budget, admissionScriptAttempt_budget, limited, Bool.true_and,
      beq_self_eq_true, relay, block, mandatory, Bool.false_eq_true, ↓reduceIte]
    repeat' split
    all_goals first | exact Or.inl rfl | exact Or.inr rfl
  case blockExpired =>
    have a : (ValidationBudget.blockExpired == ValidationBudget.relayExpired) = false := by decide
    unfold stageScripts
    simp only [admissionEra_budget, admissionScriptAttempt_budget, limited, Bool.true_and,
      beq_self_eq_true, relay, block, mandatory, a, Bool.false_eq_true, ↓reduceIte]
    repeat' split
    all_goals first | exact Or.inl rfl | exact Or.inr rfl
  case mandatoryExpired =>
    have a : (ValidationBudget.mandatoryExpired == ValidationBudget.relayExpired) = false := by decide
    have b : (ValidationBudget.mandatoryExpired == ValidationBudget.blockExpired) = false := by decide
    unfold stageScripts
    simp only [admissionEra_budget, admissionScriptAttempt_budget, limited, Bool.true_and,
      beq_self_eq_true, relay, block, mandatory, a, b, Bool.false_eq_true, ↓reduceIte]
    repeat' split
    all_goals first | exact Or.inl rfl | exact Or.inr rfl

/-- Stage 12 reads the budget at three polls, each guarded by the request's
limits; when a poll fires, the stage is the timeout's step.
[SRC] src/validation.cpp:1335–1355,1414–1430,1444–1464 at 6504a3af. -/
theorem scripts_budget (cfg : NodeConfig) (ctx : AdmissionContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (budget : ValidationBudget) :
    BudgetStep (stageScripts cfg { ctx with budget } lists oracle)
      (stageScripts cfg { ctx with budget := .available } lists oracle) := by
  intro w
  cases limited : w.request.useLimits
  · exact Or.inl (scripts_unlimited cfg ctx lists oracle w budget limited)
  · rcases scripts_limited cfg ctx lists oracle w budget limited with same | fired
    · exact Or.inl same
    · right
      rw [fired]
      exact defer_work_answer w ctx.now

/-- The acceptance reads its context at two places only: the stages before
the detector, and the commit. Two contexts that agree there give the same
acceptance. -/
theorem accept_trace_congr (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx ctx' : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (detector : DetectorObservation) (request : TxRequest)
    (before : beforeDetector (request.configOverride.getD cfg) ctx lists oracle
        { pool := p, view := mempoolView p utxo, request } =
      beforeDetector (request.configOverride.getD cfg) ctx' lists oracle
        { pool := p, view := mempoolView p utxo, request })
    (commit : stageCommit (request.configOverride.getD cfg) ctx =
      stageCommit (request.configOverride.getD cfg) ctx') :
    acceptWithTrace p utxo cfg ctx lists oracle detector request =
      acceptWithTrace p utxo cfg ctx' lists oracle detector request := by
  unfold acceptWithTrace
  dsimp only
  rw [before, commit]

/-- An acceptance that is not suppressed and stops before the detector
returns the stopping stage's outcome. -/
theorem accept_trace_stopped (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (detector : DetectorObservation) (request : TxRequest) (next : AdmissionWork)
    (outcome : TxOutcome) (trace : List AdmissionStage)
    (loud : (request.source == .p2p &&
      p.recentRejects.contains (BsvScript.Sighash.txid request.tx)) = false)
    (stopped : beforeDetector (request.configOverride.getD cfg) ctx lists oracle
        { pool := p, view := mempoolView p utxo, request } = (next, some outcome, trace)) :
    (acceptWithTrace p utxo cfg ctx lists oracle detector request).2.1 = outcome := by
  unfold acceptWithTrace
  dsimp only
  rw [stopped]
  simp only [loud, Bool.false_eq_true, ↓reduceIte]

/-- The budget preserves the available-budget result or stops with a timeout
answer. A high-priority timeout defers; a low-priority timeout completes with
too-long-validation-time and can replace the available-budget verdict or
reason. For any state, request and budget observation, the acceptance with
that observation either equals the acceptance with an available budget (the
same pool, outcome and trace), or it stops with a timeout answer: `deferred`,
the request queued again at low priority, or the low-priority rejection
`too-long-validation-time`. The theorem does not assert verdict invariance for
low-priority requests.
[SRC] src/validation.cpp:1210–1233,1349–1355,1424–1430,1458–1464 and
src/txn_validator.cpp:633–641 at 6504a3af. -/
theorem budget_changes_timing_only (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (detector : DetectorObservation) (request : TxRequest) (budget : ValidationBudget) :
    acceptWithTrace p utxo cfg { ctx with budget } lists oracle detector request =
      acceptWithTrace p utxo cfg { ctx with budget := .available } lists oracle detector request ∨
    TimeoutAnswer (acceptWithTrace p utxo cfg { ctx with budget } lists oracle detector request).2.1 := by
  have related : ∀ c : NodeConfig, BudgetStages
      (admissionPrefix c { ctx with budget } ++
        [(.conflict, stageConflict), (.inputs, stageInputs c { ctx with budget }),
         (.sequence, stageSequence c { ctx with budget }),
         (.inputStandard, stageInputStandard c { ctx with budget }),
         (.sigops, stageSigops c { ctx with budget }),
         (.fee, stageFee c { ctx with budget }), (.ancestors, stageAncestors c { ctx with budget }),
         (.scripts, stageScripts c { ctx with budget } lists oracle)])
      (admissionPrefix c { ctx with budget := .available } ++
        [(.conflict, stageConflict), (.inputs, stageInputs c { ctx with budget := .available }),
         (.sequence, stageSequence c { ctx with budget := .available }),
         (.inputStandard, stageInputStandard c { ctx with budget := .available }),
         (.sigops, stageSigops c { ctx with budget := .available }),
         (.fee, stageFee c { ctx with budget := .available }),
         (.ancestors, stageAncestors c { ctx with budget := .available }),
         (.scripts, stageScripts c { ctx with budget := .available } lists oracle)]) := by
    intro c
    simp only [admissionPrefix, List.cons_append, List.nil_append]
    refine .cons (budget_step_of_eq rfl) (.cons (budget_step_of_eq rfl) (.cons (budget_step_of_eq rfl)
      (.cons (budget_step_of_eq rfl) (.cons (budget_step_of_eq rfl) (.cons (budget_step_of_eq rfl)
      (.cons (budget_step_of_eq rfl) (.cons (input_standard_budget c ctx budget)
      (.cons (budget_step_of_eq rfl) (.cons (budget_step_of_eq rfl) (.cons (budget_step_of_eq rfl)
      (.cons (scripts_budget c ctx lists oracle budget) .nil)))))))))))
  have commit : ∀ c : NodeConfig,
      stageCommit c { ctx with budget } = stageCommit c { ctx with budget := .available } :=
    fun _ => rfl
  cases loud : (request.source == .p2p &&
      p.recentRejects.contains (BsvScript.Sighash.txid request.tx))
  case true =>
    left
    simp only [acceptWithTrace, loud, ↓reduceIte]
  case false =>
    rcases run_budget_stages (related (request.configOverride.getD cfg))
        { pool := p, view := mempoolView p utxo, request } with same | ⟨outcome, stopped, answer⟩
    · exact Or.inl (accept_trace_congr p utxo cfg _ _ lists oracle detector request same (commit _))
    · right
      rcases hrun : beforeDetector (request.configOverride.getD cfg) { ctx with budget } lists oracle
          { pool := p, view := mempoolView p utxo, request } with ⟨next, result, trace⟩
      have stopped' : (beforeDetector (request.configOverride.getD cfg) { ctx with budget } lists oracle
          { pool := p, view := mempoolView p utxo, request }).2.1 = some outcome := stopped
      rw [hrun] at stopped'
      have found : result = some outcome := stopped'
      subst found
      rw [accept_trace_stopped p utxo cfg _ lists oracle detector request next outcome trace loud hrun]
      exact answer

/-- The same law with the elapsed time as the explicit input: whatever
elapsed-time observation the harness supplies, the timed acceptance equals
the acceptance with an available budget, or it ends in a timeout answer. The
machine is deterministic in the observation; the observation is the node's.
[SRC] src/taskcancellation.h:155–164 and src/validation.cpp:990–1006 at 6504a3af. -/
theorem elapsed_changes_timing_only (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (detector : DetectorObservation) (request : TxRequest) (elapsed : ElapsedObservation) :
    acceptTimed p utxo cfg ctx lists oracle detector elapsed request =
      accept p utxo cfg { ctx with budget := .available } lists oracle detector request ∨
    TimeoutAnswer (acceptTimed p utxo cfg ctx lists oracle detector elapsed request).2 := by
  rcases budget_changes_timing_only p utxo cfg ctx lists oracle detector request
      (if request.useLimits then
        budgetObservation (request.configOverride.getD cfg) request.priority elapsed
       else .available) with same | answer
  · exact Or.inl (congrArg
      (fun r : Mempool × TxOutcome × List AdmissionStage => (r.1, r.2.1)) same)
  · exact Or.inr answer

/-- Within the allowance nothing fires: an observation whose every poll is at
or under the allowance is the available budget, so the timed acceptance is
the untimed one. Equality with the allowance does not fire; the source's
comparison is strict. Whether such a cell is judged is decided by its clock
dependence (`budget_judgment_judging_iff`), not by this value.
[SRC] src/taskcancellation.h:155–164 at 6504a3af. -/
theorem within_allowance_available (cfg : NodeConfig) (priority : TxPriority)
    (elapsed : ElapsedObservation)
    (inputs : elapsed.inputs ≤ validationAllowance cfg priority elapsed)
    (relay : elapsed.relay ≤ validationAllowance cfg priority elapsed)
    (block : elapsed.block ≤ validationAllowance cfg priority elapsed)
    (mandatory : elapsed.mandatory ≤ validationAllowance cfg priority elapsed) :
    budgetObservation cfg priority elapsed = .available := by
  simp [budgetObservation, Nat.not_lt.mpr inputs, Nat.not_lt.mpr relay,
    Nat.not_lt.mpr block, Nat.not_lt.mpr mandatory]

/-- A cell is judged exactly when it is clock-free, whatever budget it
carries: a clock-dependent cell is non-judging on an available budget as on an
expired one, and a clock-free cell is judged even under an expired observation.
[SRC] src/validation.cpp:990–1006,1077–1078, src/taskcancellation.h:155–164
and src/init.cpp:2890–2895 at 6504a3af. -/
theorem budget_judgment_judging_iff (dependence : ClockDependence) (budget : ValidationBudget) :
    budgetJudgment dependence budget = .judging ↔ dependence = .clockFree := by
  cases dependence <;> simp [budgetJudgment]

/-- An unlimited request is clock-free: it builds no timed source.
[SRC] src/validation.cpp:990–997 at 6504a3af. -/
theorem unlimited_clock_free (request : TxRequest) (run : ValidationBudget → TxOutcome)
    (unlimited : request.useLimits = false) :
    clockDependence request run = .clockFree := by
  simp [clockDependence, unlimited]

/-- A limited request classified clock-free has the same outcome under every
budget observation: no poll's firing changes what it answers, so the judged
cell does not depend on the node's clock.
[SRC] src/validation.cpp:1210–1233,1349–1355,1424–1430,1458–1464 at 6504a3af. -/
theorem clock_free_budget_invariant (request : TxRequest) (run : ValidationBudget → TxOutcome)
    (free : clockDependence request run = .clockFree) (limited : request.useLimits = true)
    (budget : ValidationBudget) : run budget = run .available := by
  unfold clockDependence at free
  split at free
  · exact absurd free (by decide)
  · next h =>
    have none : expiredBudgets.any (fun b => run b != run .available) = false := by
      rw [limited, Bool.true_and] at h
      simpa using h
    have all := List.any_eq_false.1 none
    cases budget with
    | available => rfl
    | inputsExpired => simpa using all .inputsExpired (by simp [expiredBudgets])
    | relayExpired => simpa using all .relayExpired (by simp [expiredBudgets])
    | blockExpired => simpa using all .blockExpired (by simp [expiredBudgets])
    | mandatoryExpired => simpa using all .mandatoryExpired (by simp [expiredBudgets])

/-- One rolling filter's reading is judged exactly inside its wipe-free regime
with no declared false positive outside its members.
[SRC] src/bloom.cpp:265–281 and src/bloom.h:112–118 at 6504a3af. -/
theorem filter_judging_iff (f : RejectFilter) (falsePositive : TxId → Bool) (id : TxId) :
    filterJudgment f falsePositive id = .judging ↔
      f.wipeFree = true ∧ (falsePositive id = true → f.contains id = true) := by
  unfold filterJudgment
  cases hw : f.wipeFree <;> cases hf : falsePositive id <;> cases hc : f.contains id <;> simp

/-- The inventory reading is judged exactly when both rolling filters it
consults are exact after the lazy reset: the reject filter and the separate
filter of recently removed held transactions, each inside its own wipe-free
regime and with no declared false positive for the id outside its members.
[SRC] src/net/net_processing.cpp:930–961, src/time_locked_mempool.cpp:217–221,481–510
and src/bloom.cpp:265–281 at 6504a3af. -/
theorem inventory_judging_exact (p : Mempool) (obs : InventoryObservation) (id : TxId) :
    inventoryJudgment p obs id = .judging ↔
      ((observeTip p obs.tip).recentRejects.wipeFree = true ∧
        (obs.filterFalsePositive id = true → (observeTip p obs.tip).recentRejects.contains id = true)) ∧
      ((observeTip p obs.tip).nonFinalRecentlyRemoved.wipeFree = true ∧
        (obs.removedFalsePositive id = true →
          (observeTip p obs.tip).nonFinalRecentlyRemoved.contains id = true)) := by
  rw [← filter_judging_iff (observeTip p obs.tip).recentRejects obs.filterFalsePositive id,
    ← filter_judging_iff (observeTip p obs.tip).nonFinalRecentlyRemoved obs.removedFalsePositive id]
  unfold inventoryJudgment
  cases filterJudgment (observeTip p obs.tip).recentRejects obs.filterFalsePositive id <;> simp

/-- The lazy reset leaves the separate filter of recently removed held
transactions as it was: only the reject filter is reset.
[SRC] src/net/net_processing.cpp:935–942 and src/time_locked_mempool.cpp:481–490
at 6504a3af. -/
theorem observe_tip_removed (p : Mempool) (tip : Bytes) :
    (observeTip p tip).nonFinalRecentlyRemoved = p.nonFinalRecentlyRemoved := by
  unfold observeTip
  split <;> rfl

/-- A rollover of the separate filter makes the inventory reading non-judging
even when the reject filter is wipe-free.
[SRC] src/time_locked_mempool.cpp:481–490 and src/bloom.cpp:265–281 at 6504a3af. -/
theorem removed_wipe_non_judging (p : Mempool) (obs : InventoryObservation) (id : TxId)
    (wiped : p.nonFinalRecentlyRemoved.wipeFree = false) :
    inventoryJudgment p obs id ≠ .judging := by
  intro judged
  have w := ((inventory_judging_exact p obs id).1 judged).2.1
  rw [observe_tip_removed, wiped] at w
  exact absurd w (by decide)

/-- A Boolean disjunct implied by the other is absorbed. -/
theorem or_absorb {a b : Bool} (implied : b = true → a = true) : (a || b) = a := by
  cases a <;> cases b <;> simp_all

/-- A judged inventory reading is the ideal-set reading: with both filters
exact, the declared false positives do not change the answer or the pool.
[SRC] src/net/net_processing.cpp:930–961 at 6504a3af. -/
theorem inventory_judging_ideal (p : Mempool) (obs : InventoryObservation) (id : TxId)
    (judged : inventoryJudgment p obs id = .judging) :
    receiveInv p obs id = receiveInv p obs.ideal id := by
  obtain ⟨⟨_, rejects⟩, ⟨_, removed⟩⟩ := (inventory_judging_exact p obs id).1 judged
  simp only [receiveInv, knownTx, knownElsewhere, InventoryObservation.ideal,
    or_absorb rejects, or_absorb removed, Bool.or_false]

/-- For ANY configuration, the held pool's removal filter has the generation
of its own configured capacity, and is wipe-free exactly when its member list
is at most three generations long.
[SRC] src/time_locked_mempool.h:213–214, src/bloom.cpp:222–225,265–281 at 6504a3af. -/
theorem removedNonFinalFilter_wipe_free_iff (cfg : NodeConfig) (members : List TxId) :
    (removedNonFinalFilter cfg members).generationSize =
      (cfg.nonFinalRecentlyRemovedCapacity + 1) / 2 ∧
    ((removedNonFinalFilter cfg members).wipeFree = true ↔
      members.length ≤ 3 * ((cfg.nonFinalRecentlyRemovedCapacity + 1) / 2)) := by
  refine ⟨rfl, ?_⟩
  simp only [removedNonFinalFilter, RejectFilter.wipeFree, RejectFilter.generationSize]
  exact ⟨of_decide_eq_true, decide_eq_true⟩

/-- At the census defaults the separate filter's wipe-free regime is 15,000
insertions: three generations of 5,000. The general form is
`removedNonFinalFilter_wipe_free_iff`; this theorem is its instance at the
census defaults.
[SRC] src/time_locked_mempool.h:214 and src/bloom.cpp:222–225 at 6504a3af. -/
theorem default_removed_wipe_free_bound :
    (removedNonFinalFilter NodeConfig.defaults).generationSize = 5000 ∧
    3 * (removedNonFinalFilter NodeConfig.defaults).generationSize = 15000 := by
  decide

/-- For ANY configuration, a request's allowance is its priority's configured
duration (in microseconds) plus the carried time, and the carried part never
exceeds the configured chain budget.
[SRC] src/txn_validation_config.h:39–46,
src/taskcancellation.h:113–121,173–179 and src/validation.cpp:1577 at 6504a3af. -/
theorem validationAllowance_bounds (cfg : NodeConfig) (priority : TxPriority)
    (elapsed : ElapsedObservation) :
    1000 * validationDuration cfg priority ≤ validationAllowance cfg priority elapsed ∧
    validationAllowance cfg priority elapsed ≤
      1000 * validationDuration cfg priority + 1000 * cfg.maxTxnChainValidationBudget := by
  simp only [validationAllowance]
  constructor <;> omega

/-- The census defaults give a high-priority request 3,000 microseconds and a
low-priority request 1,000,000, each with at most 50,000 carried. The general
form is `validationAllowance_bounds`, for every configuration; this theorem is
its instance at the census defaults.
[SRC] src/txn_validation_config.h:39–46 at 6504a3af. -/
theorem default_allowances :
    validationAllowance NodeConfig.defaults .high {} = 3000 ∧
    validationAllowance NodeConfig.defaults .low {} = 1000000 ∧
    validationAllowance NodeConfig.defaults .high { carried := 9000000 } = 53000 := by
  decide

end BsvChain.Properties.Rejects
