import BsvChain.Frozen
import BsvChain.Chain

/-!
# Frozen outputs and the confiscation whitelist (#70)

The issue's theorems in the form the machine proves. Every list here is
operator data (the operator-list mechanism, a policy parameter); the reference's
"consensus" list is an operator list the node also applies at block connection.
Each statement names the executable definitions and states every premise.
[SRC] bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`:
src/frozentxo.cpp:27–171, src/frozentxo_db.h:179–377, src/validation.cpp:1320–1482,
2552–2665,3290–3447,3529–3555.
-/

namespace BsvChain.Properties
open BsvScript.Tx BsvScript.Numbers

/-! ## The derivation is the reference's check -/

/-- The connection projection is `CFrozenTXOCheck::Check`: the projection of the
records adjusted by the block's explicit freeze flag `e` and waiver `w` reports
an output frozen exactly when `check` returns an effective list. No premise.
[SRC] src/frozentxo.cpp:37–83 at 6504a3af. -/
theorem s6_frozen_projection_check (d : OperatorLists) (e w onBlock : Bool) (h : Nat) (p : OutPoint) :
    (d.project.atBlock e w).frozen onBlock h p = (d.check onBlock e h p).isSome := by
  cases onBlock <;> cases e <;> simp [FrozenLists.atBlock, OperatorLists.project, OperatorLists.check]

/-- The whitelist half: the adjusted projection is
`CheckConfiscationTxWhitelisted` with the waiver `w`. No premise.
[SRC] src/frozentxo.cpp:133–171 at 6504a3af. -/
theorem s6_whitelist_projection_check (d : OperatorLists) (e w onBlock : Bool) (h : Nat) (txid : Bytes) :
    (d.project.atBlock e w).whitelisted onBlock h txid = d.checkWhitelisted onBlock w h txid := by
  simp [FrozenLists.atBlock, OperatorLists.project, OperatorLists.checkWhitelisted]

/-! ## Congruence: what the UTXO stage reads of the lists -/

/-- The per-input loop reads the frozen projection only on the context's path
and at its height. Premise: the two frozen predicates are equal on that path
at that height. [SRC] src/validation.cpp:2591–2643 at 6504a3af. -/
theorem checkInputCoins_congr (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (l₁ l₂ : FrozenLists) (hf : l₁.frozen ctx.onBlock ctx.height = l₂.frozen ctx.onBlock ctx.height)
    (c : Bool) (xs : List TxIn) (t : Int) :
    checkInputCoins s cfg ctx l₁ c xs t = checkInputCoins s cfg ctx l₂ c xs t := by
  induction xs generalizing t with
  | nil => rfl
  | cons x xs ih =>
    simp only [checkInputCoins, hf]
    split <;> simp [ih]

/-- A confiscation transaction's loop never reads the frozen projection.
[SRC] src/validation.cpp:2594–2611 at 6504a3af. -/
theorem checkInputCoins_confiscation (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (l₁ l₂ : FrozenLists) (xs : List TxIn) (t : Int) :
    checkInputCoins s cfg ctx l₁ true xs t = checkInputCoins s cfg ctx l₂ true xs t := by
  induction xs generalizing t with
  | nil => rfl
  | cons x xs ih =>
    simp only [checkInputCoins, Bool.not_true, Bool.false_and, Bool.false_eq_true, ↓reduceIte]
    split <;> simp [ih]

/-- The input stage reads both projections only on the context's path and at
its height. Premises: the two frozen predicates are equal, and the two whitelist
predicates are equal, on that path at that height.
[SRC] src/validation.cpp:2552–2665 at 6504a3af. -/
theorem checkTxInputs_congr (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (l₁ l₂ : FrozenLists) (hf : l₁.frozen ctx.onBlock ctx.height = l₂.frozen ctx.onBlock ctx.height)
    (hw : l₁.whitelisted ctx.onBlock ctx.height = l₂.whitelisted ctx.onBlock ctx.height) (tx : Tx) :
    checkTxInputs s cfg ctx l₁ tx = checkTxInputs s cfg ctx l₂ tx := by
  simp only [checkTxInputs, hw, checkInputCoins_congr s cfg ctx l₁ l₂ hf]

/-- One transaction's application, likewise. Premises: the two frozen
predicates are equal, and the two whitelist predicates are equal, on the
context's path at its height. [SRC] src/validation.cpp:3326–3434 at 6504a3af. -/
theorem applyTx_congr (cfg : NodeConfig) (ctx : UtxoContext) (l₁ l₂ : FrozenLists)
    (hf : l₁.frozen ctx.onBlock ctx.height = l₂.frozen ctx.onBlock ctx.height)
    (hw : l₁.whitelisted ctx.onBlock ctx.height = l₂.whitelisted ctx.onBlock ctx.height)
    (s : UtxoSet) (oracle : ScriptOracle) (tx : Tx) :
    applyTx s cfg ctx l₁ oracle tx = applyTx s cfg ctx l₂ oracle tx := by
  simp only [applyTx, validateUtxoTx, checkTxInputs_congr s cfg ctx l₁ l₂ hf hw]

/-- A block's transaction run, likewise. Premises: the two frozen predicates
are equal, and the two whitelist predicates are equal, on the context's path at
its height. [SRC] src/validation.cpp:3290–3447 at 6504a3af. -/
theorem runBlockTransactions_congr (cfg : NodeConfig) (ctx : UtxoContext) (l₁ l₂ : FrozenLists)
    (hf : l₁.frozen ctx.onBlock ctx.height = l₂.frozen ctx.onBlock ctx.height)
    (hw : l₁.whitelisted ctx.onBlock ctx.height = l₂.whitelisted ctx.onBlock ctx.height)
    (oracle : ScriptOracle) (previous : Option HeaderChain) (checks : ConnectionChecks) (cap : Nat)
    (txs : List Tx) (s : UtxoSet) (total : Nat) :
    runBlockTransactions cfg ctx l₁ oracle previous checks cap txs s total =
      runBlockTransactions cfg ctx l₂ oracle previous checks cap txs s total := by
  induction txs generalizing s total with
  | nil => rfl
  | cons tx rest ih => simp only [runBlockTransactions, applyTx_congr cfg ctx l₁ l₂ hf hw, ih]

/-- The connection's prepared context is the block path at the block's height.
Premise: the preparation succeeds for a non-genesis block, returning `some ctx`.
[SRC] src/validation.cpp:3021–3050,3376–3392 at 6504a3af. -/
theorem prepareBlockConnection_ctx (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int) (checks : ConnectionChecks)
    (ctx : UtxoContext)
    (h : prepareBlockConnection view params cfg block previous now checks = .ok (some ctx)) :
    ctx.onBlock = true ∧ ctx.height = (previous.map (·.height + 1)).getD 0 := by
  unfold prepareBlockConnection at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (cases h; done)
    | (simp only [Except.ok.injEq, Option.some.injEq] at h; subst h; exact ⟨rfl, rfl⟩)

/-- Block connection reads the operator lists only on the block path at the
block's height `H`: two projections that agree there connect every block alike.
[SRC] src/frozentxo.cpp:52–62 and src/validation.cpp:3529,3376–3392 at 6504a3af. -/
theorem connectBlock_lists_congr (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int) (l₁ l₂ : FrozenLists)
    (oracle : ScriptOracle) (checks : ConnectionChecks)
    (hf : l₁.frozen true ((previous.map (·.height + 1)).getD 0) =
      l₂.frozen true ((previous.map (·.height + 1)).getD 0))
    (hw : l₁.whitelisted true ((previous.map (·.height + 1)).getD 0) =
      l₂.whitelisted true ((previous.map (·.height + 1)).getD 0)) :
    connectBlock view params cfg block previous now l₁ oracle checks =
      connectBlock view params cfg block previous now l₂ oracle checks := by
  unfold connectBlock
  cases hp : prepareBlockConnection view params cfg block previous now checks with
  | error e => rfl
  | ok c =>
    cases c with
    | none => rfl
    | some ctx =>
      obtain ⟨hon, hh⟩ := prepareBlockConnection_ctx view params cfg block previous now checks ctx hp
      have ef : l₁.frozen ctx.onBlock ctx.height = l₂.frozen ctx.onBlock ctx.height := by rw [hon, hh]; exact hf
      have ew : l₁.whitelisted ctx.onBlock ctx.height = l₂.whitelisted ctx.onBlock ctx.height := by
        rw [hon, hh]; exact hw
      simp only [bind, Except.bind, runBlockTransactions_congr cfg ctx l₁ l₂ ef ew]

/-! ## The records and the projection -/

/-- A record found by `frozenData` is an entry of the records.
[SRC] src/frozentxo_db.cpp:520–533 at 6504a3af. -/
theorem frozenData_mem (d : OperatorLists) (p : OutPoint) (x : FrozenTxoData)
    (h : d.frozenData p = some x) : (p, x) ∈ d.frozen := by
  simp only [OperatorLists.frozenData, Option.map_eq_some_iff] at h
  obtain ⟨e, he, rfl⟩ := h
  have hp : e.1 = p := by simpa using List.find?_some he
  have hm := List.mem_of_find?_eq_some he
  rcases e with ⟨q, x⟩
  simp only at hp
  subst hp
  exact hm

/-- At height `H` the block-path projection of records none of which is frozen
on the ranged predicate there is the empty records' projection. -/
theorem project_block_empty (d : OperatorLists) (H : Nat)
    (hout : ∀ e ∈ d.frozen, e.2.frozenOnConsensus H = false) :
    d.project.frozen true H = ({ d with frozen := [] } : OperatorLists).project.frozen true H := by
  funext p
  simp only [OperatorLists.project, OperatorLists.check, Bool.and_false, Bool.false_eq_true, ↓reduceIte,
    OperatorLists.frozenData, List.find?_nil, Option.map_none]
  cases hd : (d.frozen.find? (fun e => e.1 == p)).map (·.2) with
  | none => rfl
  | some x =>
    have hx := hout (p, x) (frozenData_mem d p x hd)
    simp [hx]

/-! ## (a) The policy list: refused at admission, not consulted at connection -/

/-- The input stage's frozen refusal: the head input frozen on the context's
path gives `bad-txns-inputs-frozen`, code 0x13 on the block path and 0x10 on
admission. Premises: inputs available, not a confiscation transaction, the
head input `i` frozen. [SRC] src/validation.cpp:2552–2607 at 6504a3af. -/
theorem checkTxInputs_frozen_head (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (tx : Tx) (i : TxIn) (rest : List TxIn)
    (havail : haveInputs s tx = true) (hord : isConfiscationTx tx = false)
    (hinputs : tx.inputs = i :: rest) (hfrozen : lists.frozen ctx.onBlock ctx.height (.ofInput i) = true) :
    checkTxInputs s cfg ctx lists tx =
      .error ⟨.node (if ctx.onBlock then 0x13 else 0x10), "bad-txns-inputs-frozen"⟩ := by
  simp [checkTxInputs, havail, hord, hinputs, checkInputCoins, hfrozen, bind, Except.bind]

/-- A run of admission stages whose prefix passes continues with the suffix.
[SRC] src/validation.cpp:1031–1482 at 6504a3af (the source order). -/
theorem runAdmissionStages_append_pass (xs ys : List (AdmissionStage × (AdmissionWork → AdmissionStep)))
    (w w' : AdmissionWork) (t : List AdmissionStage) (h : runAdmissionStages xs w = (w', none, t)) :
    runAdmissionStages (xs ++ ys) w =
      ((runAdmissionStages ys w').1, (runAdmissionStages ys w').2.1, t ++ (runAdmissionStages ys w').2.2) := by
  induction xs generalizing w t with
  | nil =>
    simp only [runAdmissionStages, Prod.mk.injEq] at h
    obtain ⟨rfl, -, rfl⟩ := h
    simp
  | cons x xs ih =>
    rcases x with ⟨name, check⟩
    simp only [runAdmissionStages] at h
    rcases hc : check w with ⟨w1, o⟩
    rw [hc] at h
    cases o with
    | some o => simp at h
    | none =>
      simp only at h
      rcases hr : runAdmissionStages xs w1 with ⟨w2, o2, t2⟩
      rw [hr] at h
      simp only [Prod.mk.injEq] at h
      obtain ⟨rfl, rfl, rfl⟩ := h
      simp only [List.cons_append, runAdmissionStages, hc, ih w1 t2 hr, List.cons_append]

/-- (a), admission: a spend of an output frozen on the policy predicate at the
tip's successor is refused by `accept` with `bad-txns-inputs-frozen`, code 0x10.
Premises: the request is submitted (not inventory-suppressed) with no per-call
configuration; every source-ordered earlier stage passes (`earlier`, ending in
the work `w`); the relay word resolves; inputs are available in `w`'s view; the
transaction is not a confiscation transaction; its head input `i` has a record
frozen on the policy predicate (`IsFrozenOnPolicy`) at height `tipHeight + 1`.
[SRC] src/validation.cpp:1320–1348,2552–2607 and src/frozentxo.cpp:63–75 at 6504a3af. -/
theorem s6_policy_frozen_admission_refused (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (d : OperatorLists) (oracle : ScriptOracle) (obs : DetectorObservation)
    (request : TxRequest) (w : AdmissionWork) (trace : List AdmissionStage) (relay : BsvScript.Params.Flags)
    (i : TxIn) (rest : List TxIn) (data : FrozenTxoData)
    (submitted : (request.source == .p2p && p.recentRejects.contains (BsvScript.Sighash.txid request.tx)) = false)
    (noOverride : request.configOverride = none)
    (earlier : runAdmissionStages (admissionPrefix cfg ctx ++
      [(.conflict, stageConflict), (.inputs, stageInputs cfg ctx), (.sequence, stageSequence cfg ctx),
       (.inputStandard, stageInputStandard cfg ctx), (.sigops, stageSigops cfg ctx),
       (.fee, stageFee cfg ctx), (.ancestors, stageAncestors cfg ctx)])
      { pool := p, view := mempoolView p utxo, request } = (w, none, trace))
    (hrelay : callerScriptFlags cfg ctx.params (ctx.tipHeight + 1) (.relay w.request.skipScriptFlags) = some relay)
    (havail : haveInputs w.view w.request.tx = true)
    (hord : isConfiscationTx w.request.tx = false)
    (hinputs : w.request.tx.inputs = i :: rest)
    (hlisted : d.frozenData (.ofInput i) = some data)
    (hpolicy : data.frozenOnPolicy ((ctx.tipHeight + 1 : Nat) : Int) = true) :
    (accept p utxo cfg ctx d.project oracle obs request).2 =
      .completed (.rejected (.node 0x10) "bad-txns-inputs-frozen") := by
  have hp' : data.frozenOnPolicy ((ctx.tipHeight : Int) + 1) = true := by simpa using hpolicy
  have hfrozen : d.project.frozen false (ctx.tipHeight + 1) (.ofInput i) = true := by
    simp [OperatorLists.project, OperatorLists.check, hlisted, hp']
  have hin := fun flags now => checkTxInputs_frozen_head w.view cfg
    { params := ctx.params, height := ctx.tipHeight + 1, tipHeight := ctx.tipHeight, flags,
      consensus := false, onBlock := false, now } d.project w.request.tx i rest havail hord hinputs hfrozen
  have hstage : stageScripts cfg ctx d.project oracle w =
      (w, some (.completed (.rejected (.node 0x10) "bad-txns-inputs-frozen"))) := by
    simp only [stageScripts, hrelay, Id.run]
    simp [hin, scriptFailure, checkedStep, rejectOutcome]
    rfl
  have hbefore : beforeDetector cfg ctx d.project oracle { pool := p, view := mempoolView p utxo, request } =
      (w, some (.completed (.rejected (.node 0x10) "bad-txns-inputs-frozen")), trace ++ [.scripts]) := by
    unfold beforeDetector
    have split := runAdmissionStages_append_pass _ [(.scripts, stageScripts cfg ctx d.project oracle)] _ _ _ earlier
    simp only [List.append_assoc, List.cons_append, List.nil_append] at split
    rw [split]
    simp [runAdmissionStages, hstage]
  simp only [accept, acceptWithTrace, noOverride, Option.getD_none, submitted, Bool.false_eq_true,
    ↓reduceIte, hbefore]

/-- (a), the policy-only corollary: a record on the policy-only list.
[SRC] src/frozentxo_db.h:323–329 at 6504a3af. -/
theorem s6_policy_only_frozen_on_policy (data : FrozenTxoData) (h : Int)
    (hpolicy : data.blacklist = .policyOnly) : data.frozenOnPolicy h = true := by
  simp [FrozenTxoData.frozenOnPolicy, hpolicy]

/-- (a), connection: block connection does not consult the policy-only list.
Records all on that list connect every block exactly as no records do, so a
block whose connection succeeds with no frozen records succeeds with them.
Premise: every record is policy-only. [SRC] src/frozentxo.cpp:52–62 at 6504a3af. -/
theorem s6_policy_list_not_consulted_at_connection (view : CoinsView) (params : ChainParams)
    (cfg : NodeConfig) (block : Block) (previous : Option HeaderChain) (now : Int) (d : OperatorLists)
    (oracle : ScriptOracle) (checks : ConnectionChecks)
    (hpolicy : ∀ e ∈ d.frozen, e.2.blacklist = .policyOnly) :
    connectBlock view params cfg block previous now d.project oracle checks =
      connectBlock view params cfg block previous now ({ d with frozen := [] } : OperatorLists).project oracle checks :=
  connectBlock_lists_congr view params cfg block previous now _ _ oracle checks
    (project_block_empty d _ (fun e he => by simp [FrozenTxoData.frozenOnConsensus, hpolicy e he])) rfl

/-! ## (b) The ranged list: refused inside its intervals, not consulted outside -/

/-- (b), inside: a spend of an output whose ranged record holds an interval
containing the block's height is refused by the transaction's application on
the block path with `bad-txns-inputs-frozen`, code 0x13. Premises: block path,
not coinbase, the structural loops pass, inputs available, not a confiscation
transaction, the head input `i` has a ranged record with an interval `iv`
containing `ctx.height`. [SRC] src/frozentxo_db.h:353–377, src/frozentxo.cpp:52–62
and src/validation.cpp:2594–2607 at 6504a3af. -/
theorem s6_ranged_frozen_refused_in_range (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (d : OperatorLists) (oracle : ScriptOracle) (tx : Tx) (i : TxIn) (rest : List TxIn)
    (data : FrozenTxoData) (iv : HeightInterval)
    (honBlock : ctx.onBlock = true) (hcb : BsvScript.TxRules.isCoinBase tx = false)
    (hstruct : checkUtxoStructure tx = .ok ()) (havail : haveInputs s tx = true)
    (hord : isConfiscationTx tx = false) (hinputs : tx.inputs = i :: rest)
    (hlisted : d.frozenData (.ofInput i) = some data) (hranged : data.blacklist = .consensus)
    (hiv : iv ∈ data.enforceAtHeight) (hstart : iv.start ≤ ctx.height) (hstop : (ctx.height : Int) < iv.stop) :
    applyTx s cfg ctx d.project oracle tx = .error ⟨.node 0x13, "bad-txns-inputs-frozen"⟩ := by
  have hcons : data.frozenOnConsensus ctx.height = true := by
    simp only [FrozenTxoData.frozenOnConsensus, hranged, List.any_eq_true, Bool.and_eq_true,
      decide_eq_true_eq]
    exact ⟨iv, hiv, hstart, hstop⟩
  have hfrozen : d.project.frozen ctx.onBlock ctx.height (.ofInput i) = true := by
    simp [OperatorLists.project, OperatorLists.check, honBlock, hlisted, hcons]
  have hin := checkTxInputs_frozen_head s cfg ctx d.project tx i rest havail hord hinputs hfrozen
  simp only [honBlock, ↓reduceIte] at hin
  simp [applyTx, validateUtxoTx, hcb, hstruct, havail, hin, bind, Except.bind]

/-- (b), inside, at the block's transaction step: when the block's own input
checks pass for the transaction, the run stops with the frozen verdict 0x13.
Premises: those of `s6_ranged_frozen_refused_in_range` and `checkBlockInputs`
succeeding for the transaction. [SRC] src/validation.cpp:3324–3411 at 6504a3af. -/
theorem s6_ranged_frozen_block_step (cfg : NodeConfig) (ctx : UtxoContext) (d : OperatorLists)
    (oracle : ScriptOracle) (previous : Option HeaderChain) (checks : ConnectionChecks) (cap : Nat)
    (s : UtxoSet) (total count : Nat) (tx : Tx) (txs : List Tx) (i : TxIn) (rest : List TxIn)
    (data : FrozenTxoData) (iv : HeightInterval)
    (honBlock : ctx.onBlock = true) (hcb : BsvScript.TxRules.isCoinBase tx = false)
    (hstruct : checkUtxoStructure tx = .ok ()) (havail : haveInputs s tx = true)
    (hord : isConfiscationTx tx = false) (hinputs : tx.inputs = i :: rest)
    (hlisted : d.frozenData (.ofInput i) = some data) (hranged : data.blacklist = .consensus)
    (hiv : iv ∈ data.enforceAtHeight) (hstart : iv.start ≤ ctx.height) (hstop : (ctx.height : Int) < iv.stop)
    (hblock : checkBlockInputs s cfg ctx previous tx total cap = .ok count) :
    runBlockTransactions cfg ctx d.project oracle previous checks cap (tx :: txs) s total =
      .error ⟨.node 0x13, "bad-txns-inputs-frozen"⟩ := by
  have happ := fun judge => s6_ranged_frozen_refused_in_range s cfg ctx d judge tx i rest data iv
    honBlock hcb hstruct havail hord hinputs hlisted hranged hiv hstart hstop
  simp [runBlockTransactions, hblock, happ, bind, Except.bind]

/-- A block's transaction run whose prefix succeeds fails exactly as its suffix
fails from where the prefix ends. Premises: the prefix run from view `s` and
sigop total `total` succeeds with the receipt `r` (its final view `r.coins` and
running total `r.sigops`); the suffix run from that view and total fails with
`e`. [SRC] src/validation.cpp:3290–3447 at 6504a3af. -/
theorem runBlockTransactions_append_error (cfg : NodeConfig) (ctx : UtxoContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (previous : Option HeaderChain) (checks : ConnectionChecks) (cap : Nat)
    (pre txs : List Tx) (s : UtxoSet) (total : Nat) (r : BlockRun) (e : Reject)
    (hpre : runBlockTransactions cfg ctx lists oracle previous checks cap pre s total = .ok r)
    (hrest : runBlockTransactions cfg ctx lists oracle previous checks cap txs r.coins r.sigops = .error e) :
    runBlockTransactions cfg ctx lists oracle previous checks cap (pre ++ txs) s total = .error e := by
  induction pre generalizing s total r with
  | nil =>
    simp only [runBlockTransactions, Except.ok.injEq] at hpre
    subst hpre
    simpa using hrest
  | cons tx pre ih =>
    simp only [List.cons_append, runBlockTransactions, bind, Except.bind] at hpre ⊢
    rcases hb : checkBlockInputs s cfg ctx previous tx total cap with _ | count <;>
      simp only [hb] at hpre ⊢
    · cases hpre
    rcases ha : applyTx s cfg ctx lists
        (if checks.checkScripts && !checks.queued then oracle else deferredBlockOracle) tx with
      _ | ⟨next, undo⟩ <;> simp only [ha] at hpre ⊢
    · cases hpre
    rcases ht : runBlockTransactions cfg ctx lists oracle previous checks cap pre next count with
      _ | tail <;> simp only [ht] at hpre
    · cases hpre
    simp only [pure, Except.pure, Except.ok.injEq] at hpre
    subst hpre
    simp only [ih next count tail ht hrest]

/-- (b), inside, at the block's transaction step, for any effective projection:
when the block's own input checks pass for the transaction and its head input
is frozen on the block path at the context's height, the run stops with the
frozen verdict 0x13. Premises: block path, not coinbase, the structural loops
pass, inputs available, not a confiscation transaction, the head input `i`
frozen in `lists` there, and `checkBlockInputs` succeeding for the transaction.
[SRC] src/validation.cpp:2594–2607,3324–3411 at 6504a3af. -/
theorem runBlockTransactions_frozen_step (cfg : NodeConfig) (ctx : UtxoContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (previous : Option HeaderChain) (checks : ConnectionChecks) (cap : Nat)
    (s : UtxoSet) (total count : Nat) (tx : Tx) (txs : List Tx) (i : TxIn) (rest : List TxIn)
    (honBlock : ctx.onBlock = true) (hcb : BsvScript.TxRules.isCoinBase tx = false)
    (hstruct : checkUtxoStructure tx = .ok ()) (havail : haveInputs s tx = true)
    (hord : isConfiscationTx tx = false) (hinputs : tx.inputs = i :: rest)
    (hfrozen : lists.frozen true ctx.height (.ofInput i) = true)
    (hblock : checkBlockInputs s cfg ctx previous tx total cap = .ok count) :
    runBlockTransactions cfg ctx lists oracle previous checks cap (tx :: txs) s total =
      .error ⟨.node 0x13, "bad-txns-inputs-frozen"⟩ := by
  have hin := checkTxInputs_frozen_head s cfg ctx lists tx i rest havail hord hinputs
    (by rw [honBlock]; exact hfrozen)
  simp only [honBlock, ↓reduceIte] at hin
  simp [runBlockTransactions, hblock, applyTx, validateUtxoTx, hcb, hstruct, havail, hin, bind, Except.bind]

/-- (b), inside, at block connection: `connectBlock` rejects a block whose
ordinary transaction spends an output with a ranged record holding an interval
that contains the block's height `H`, with the frozen verdict, code 0x13, and
the header left valid (`corruptionPossible` false). The lists are the records'
projection adjusted for a block outside an explicit soft consensus freeze, with
any whitelist waiver `w`. Premises: the connection's preparation succeeds for a
non-genesis block (`some ctx`); the body is a prefix `pre`, then the offending
transaction `tx`, then any suffix; `pre` runs successfully from the coins view
with sigop total zero, ending in the view `r.coins` and total `r.sigops`;
`cap` is the block's pre-Genesis sigop cap; in that view `tx` is not coinbase,
passes the structural loops, has its inputs available, is not a confiscation
transaction and passes the block's own input checks; its head input `i` has a
ranged record with an interval `iv` containing `H`. Whether the prefix and the
earlier stages succeed is not decided here: they are premises.
[SRC] src/validation.cpp:3021–3050,3290–3411, src/frozentxo.cpp:39–62 and
src/frozentxo_db.h:353–377 at 6504a3af. -/
theorem s6_ranged_frozen_connect_rejected (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int) (d : OperatorLists) (w : Bool)
    (oracle : ScriptOracle) (checks : ConnectionChecks) (ctx : UtxoContext)
    (pre txs : List Tx) (tx : Tx) (r : BlockRun) (cap count : Nat) (i : TxIn) (rest : List TxIn)
    (data : FrozenTxoData) (iv : HeightInterval)
    (hprep : prepareBlockConnection view params cfg block previous now checks = .ok (some ctx))
    (hcap : cap = (1 + (block.encode.length - 1) / BsvScript.TxRules.MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS) *
      cfg.maxBlockSigOpsPerMbBeforeGenesis)
    (hbody : block.transactions = pre ++ tx :: txs)
    (hpre : runBlockTransactions cfg ctx (d.project.atBlock false w) oracle previous checks cap pre
      view.coins 0 = .ok r)
    (hcb : BsvScript.TxRules.isCoinBase tx = false) (hstruct : checkUtxoStructure tx = .ok ())
    (havail : haveInputs r.coins tx = true) (hord : isConfiscationTx tx = false)
    (hinputs : tx.inputs = i :: rest)
    (hblock : checkBlockInputs r.coins cfg ctx previous tx r.sigops cap = .ok count)
    (hlisted : d.frozenData (.ofInput i) = some data) (hranged : data.blacklist = .consensus)
    (hiv : iv ∈ data.enforceAtHeight) (hstart : iv.start ≤ ((previous.map (·.height + 1)).getD 0 : Nat))
    (hstop : (((previous.map (·.height + 1)).getD 0 : Nat) : Int) < iv.stop) :
    connectBlock view params cfg block previous now (d.project.atBlock false w) oracle checks =
      .error ⟨⟨.node 0x13, "bad-txns-inputs-frozen"⟩, false⟩ := by
  obtain ⟨hon, hh⟩ := prepareBlockConnection_ctx view params cfg block previous now checks ctx hprep
  have hcons : data.frozenOnConsensus ctx.height = true := by
    simp only [FrozenTxoData.frozenOnConsensus, hranged, List.any_eq_true, Bool.and_eq_true,
      decide_eq_true_eq]
    exact ⟨iv, hiv, hh ▸ hstart, hh ▸ hstop⟩
  have hfrozen : (d.project.atBlock false w).frozen true ctx.height (.ofInput i) = true := by
    simp [FrozenLists.atBlock, OperatorLists.project, OperatorLists.check, hlisted, hcons]
  have hrun : runBlockTransactions cfg ctx (d.project.atBlock false w) oracle previous checks cap
      block.transactions view.coins 0 = .error ⟨.node 0x13, "bad-txns-inputs-frozen"⟩ := by
    rw [hbody]
    exact runBlockTransactions_append_error cfg ctx _ oracle previous checks cap pre (tx :: txs)
      view.coins 0 r _ hpre
      (runBlockTransactions_frozen_step cfg ctx _ oracle previous checks cap r.coins r.sigops count tx txs
        i rest hon hcb hstruct havail hord hinputs hfrozen hblock)
  subst hcap
  unfold connectBlock
  simp only [hprep, hrun, bind, Except.bind, Except.mapError]

/-- (b), outside: at a block height `H` where no record is frozen on the ranged
predicate (in particular a ranged record outside all its intervals), block
connection is exactly connection with no frozen records: the same block
connects, its frozen check passing, under the same other premises.
[SRC] src/frozentxo.cpp:52–62 and src/frozentxo_db.h:353–377 at 6504a3af. -/
theorem s6_ranged_frozen_outside_not_consulted (view : CoinsView) (params : ChainParams)
    (cfg : NodeConfig) (block : Block) (previous : Option HeaderChain) (now : Int) (d : OperatorLists)
    (oracle : ScriptOracle) (checks : ConnectionChecks)
    (hout : ∀ e ∈ d.frozen, e.2.frozenOnConsensus ((previous.map (·.height + 1)).getD 0 : Nat) = false) :
    connectBlock view params cfg block previous now d.project oracle checks =
      connectBlock view params cfg block previous now ({ d with frozen := [] } : OperatorLists).project oracle checks :=
  connectBlock_lists_congr view params cfg block previous now _ _ oracle checks
    (project_block_empty d _ hout) rfl

/-- (b), the interval reading: a ranged record outside every interval is not
frozen on the ranged predicate. [SRC] src/frozentxo_db.h:367–376 at 6504a3af. -/
theorem s6_ranged_outside_intervals (data : FrozenTxoData) (h : Int)
    (hout : ∀ iv ∈ data.enforceAtHeight, ¬ (iv.start ≤ h ∧ h < iv.stop)) (hranged : data.blacklist = .consensus) :
    data.frozenOnConsensus h = false := by
  simp only [FrozenTxoData.frozenOnConsensus, hranged, List.any_eq_false, Bool.and_eq_true, decide_eq_true_eq]
  intro iv hiv hin
  exact hout iv hiv hin

/-! ## (c) The confiscation whitelist -/

/-- (c), listed: a confiscation transaction listed with an enforce height at
most `ctx.height` is judged by the input stage, on either path, exactly as with
nothing frozen and every transaction listed: availability, its contents,
maturity and values decide, the operator lists nothing further. Premises: a
confiscation transaction; listed; the height at or beyond the enforce height.
[SRC] src/validation.cpp:2562–2611 and src/frozentxo.cpp:133–141 at 6504a3af. -/
theorem s6_whitelisted_confiscation_lists_inert (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (d : OperatorLists) (tx : Tx) (wl : WhitelistedTx) (hctx : isConfiscationTx tx = true)
    (hlisted : d.whitelisted? (BsvScript.Sighash.txid tx) = some wl)
    (hheight : wl.enforceAtHeight ≤ (ctx.height : Int)) :
    checkTxInputs s cfg ctx d.project tx =
      checkTxInputs s cfg ctx ⟨fun _ _ _ => false, fun _ _ _ => true⟩ tx := by
  have hw : d.project.whitelisted ctx.onBlock ctx.height (BsvScript.Sighash.txid tx) = true := by
    simp [OperatorLists.project, OperatorLists.checkWhitelisted, hlisted, hheight]
  simp only [checkTxInputs, hctx, hw, checkInputCoins_confiscation s cfg ctx d.project
    ⟨fun _ _ _ => false, fun _ _ _ => true⟩]

/-- (c), listed, the whole application: on either path the listed confiscation
transaction's application is its application with nothing frozen and every
transaction listed. Same premises. [SRC] src/validation.cpp:2552–2665,2864–2868
at 6504a3af. -/
theorem s6_whitelisted_confiscation_applies (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (d : OperatorLists) (oracle : ScriptOracle) (tx : Tx) (wl : WhitelistedTx)
    (hctx : isConfiscationTx tx = true)
    (hlisted : d.whitelisted? (BsvScript.Sighash.txid tx) = some wl)
    (hheight : wl.enforceAtHeight ≤ (ctx.height : Int)) :
    applyTx s cfg ctx d.project oracle tx =
      applyTx s cfg ctx ⟨fun _ _ _ => false, fun _ _ _ => true⟩ oracle tx := by
  simp only [applyTx, validateUtxoTx,
    s6_whitelisted_confiscation_lists_inert s cfg ctx d tx wl hctx hlisted hheight]

/-- (c), unlisted: a confiscation transaction with valid contents that is not
listed, or listed above `ctx.height`, is refused on either path with
`bad-ctx-not-whitelisted` (code 0x10) by the records' projection (no depth
waiver). Premises: inputs available; a confiscation transaction with valid
contents; no record at or below `ctx.height`.
[SRC] src/validation.cpp:2562–2586 and src/frozentxo.cpp:133–171 at 6504a3af. -/
theorem s6_unlisted_confiscation_refused (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (d : OperatorLists) (tx : Tx) (havail : haveInputs s tx = true) (hctx : isConfiscationTx tx = true)
    (hvalid : validConfiscationContents tx = true)
    (hnot : ∀ wl, d.whitelisted? (BsvScript.Sighash.txid tx) = some wl → (ctx.height : Int) < wl.enforceAtHeight) :
    checkTxInputs s cfg ctx d.project tx = .error ⟨.node 0x10, "bad-ctx-not-whitelisted"⟩ := by
  have hw : d.project.whitelisted ctx.onBlock ctx.height (BsvScript.Sighash.txid tx) = false := by
    simp only [OperatorLists.project, OperatorLists.checkWhitelisted, Bool.and_false, Bool.or_false]
    cases hl : d.whitelisted? (BsvScript.Sighash.txid tx) with
    | none => rfl
    | some wl =>
      have := hnot wl hl
      simp only [Option.any_some, decide_eq_false_iff_not, Int.not_le]
      exact this
  simp [checkTxInputs, havail, hctx, hvalid, hw, bind, Except.bind]
  rfl

/-- (c), the waiver: with the depth waiver on, the block path admits every
confiscation transaction's whitelist check; admission is unchanged. No premise.
[SRC] src/frozentxo.cpp:158–165 and src/validation.cpp:3530–3555 at 6504a3af. -/
theorem s6_waiver_block_path_only (lists : FrozenLists) (e : Bool) (h : Nat) (txid : Bytes) :
    (lists.atBlock e true).whitelisted true h txid = true ∧
      (lists.atBlock e true).whitelisted false h txid = lists.whitelisted false h txid := by
  simp [FrozenLists.atBlock]

/-- (c), confiscated outputs: an output whose found record is on the
confiscation list is frozen on both paths at every height in the unadjusted
projection `d.project`. The connecting block's adjustments (`atBlock`) can
waive the block-path check: an explicit soft consensus freeze makes it a no-op,
and the depth waiver admits every confiscation transaction's whitelist check.
Premises: the output's record is found and is on the confiscation list.
[SRC] src/frozentxo_db.h:213–218,325–328,355–359 and src/frozentxo.cpp:39–42,158–165
at 6504a3af. -/
theorem s6_confiscated_frozen_everywhere (d : OperatorLists) (p : OutPoint) (data : FrozenTxoData)
    (hlisted : d.frozenData p = some data) (hconf : data.blacklist = .confiscation) (onBlock : Bool) (h : Nat) :
    d.project.frozen onBlock h p = true := by
  cases onBlock <;>
    simp [OperatorLists.project, OperatorLists.check, hlisted, FrozenTxoData.frozenOnPolicy,
      FrozenTxoData.frozenOnConsensus, hconf]

/-! ## (d) The explicit soft consensus freeze -/

/-- (d): `Check` is a no-op on the block path of a block in an explicit soft
consensus freeze. No premise. [SRC] src/frozentxo.cpp:39–42 and
src/frozentxo.h:49 at 6504a3af. -/
theorem s6_explicit_freeze_check_noop (d : OperatorLists) (h : Int) (p : OutPoint) :
    d.check true true h p = none := by
  simp [OperatorLists.check]

/-- (d), at connection: when the connecting index is in an explicit soft
consensus freeze (its explicit count, read from the current tree, at least
zero), the derived projection freezes nothing on the block path and leaves the
admission path unchanged. [SRC] src/frozentxo.cpp:27–42 and
src/block_index.h:569–574 at 6504a3af. -/
theorem s6_explicit_freeze_connection_lists (cfg : NodeConfig) (s : ChainState) (i target : BlockIndex)
    (best : Option (BitVec 256)) (lists : FrozenLists)
    (hfrozen : ((s.tree.get i.id).getD i).explicitSoftFrozen ≥ 0) :
    (∀ h p, (connectionFrozenLists cfg s i target best lists).frozen true h p = false) ∧
      (connectionFrozenLists cfg s i target best lists).frozen false = lists.frozen false := by
  constructor
  · intro h p
    simp [connectionFrozenLists, FrozenLists.atBlock, hfrozen]
  · funext h p
    simp [connectionFrozenLists, FrozenLists.atBlock]

/-- (d), the connected block: in an explicit soft consensus freeze the block
connects exactly as with no output frozen. No further premise.
[SRC] src/frozentxo.cpp:39–42 and src/validation.cpp:3376–3407 at 6504a3af. -/
theorem s6_explicit_freeze_connects_unfrozen (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int) (oracle : ScriptOracle)
    (checks : ConnectionChecks) (s : ChainState) (i target : BlockIndex) (best : Option (BitVec 256))
    (lists : FrozenLists) (hfrozen : ((s.tree.get i.id).getD i).explicitSoftFrozen ≥ 0) :
    connectBlock view params cfg block previous now (connectionFrozenLists cfg s i target best lists) oracle checks =
      connectBlock view params cfg block previous now
        ⟨fun _ _ _ => false, (connectionFrozenLists cfg s i target best lists).whitelisted⟩ oracle checks :=
  connectBlock_lists_congr view params cfg block previous now _ _ oracle checks
    (funext fun p => (s6_explicit_freeze_connection_lists cfg s i target best lists hfrozen).1 _ p) rfl

end BsvChain.Properties
