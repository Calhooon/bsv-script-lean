import BsvChain.Chain
import BsvChain.Properties.Utxo

/-!
# Qualified chain laws (#64)

All maps, settings and oracles remain quantified. The retained undo is the
spent-coin vector, with an explicit no-overwrite premise. Automatic selection
is distinguished from interruptions and explicit removals.
[SRC] src/validation.cpp:3021–3719,4065–4133,4413–5130 and
src/processing_block_index.cpp:9–77 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
-/

namespace BsvChain.Properties
open BsvScript.Tx

/-- Sequential receipt validity states actual applyTx success in the view
immediately preceding each transaction. This is derived from execution below,
not stored as a trusted field. [SRC] src/validation.cpp:3324–3443 at 6504a3af. -/
def ApplicationsValid (cfg : NodeConfig) (ctx : UtxoContext) (lists : FrozenLists)
    (oracle : ScriptOracle) : UtxoSet → List BlockApplication → UtxoSet → Prop
  | before, [], after => before = after
  | before, a :: rest, after => a.before = before ∧
      applyTx before cfg ctx lists oracle a.tx = .ok (a.after, a.undo) ∧
      ApplicationsValid cfg ctx lists oracle a.after rest after

/-- Every successful sequential run has faithful receipts and the same body
order. The induction follows each guard and applyTx, then the recursive tail.
[SRC] src/validation.cpp:3290–3447 at 6504a3af. -/
theorem runBlockTransactions_valid (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (previous : Option HeaderChain)
    (checks : ConnectionChecks) (cap : Nat) (txs : List Tx) (s : UtxoSet)
    (total : Nat) (run : BlockRun)
    (h : runBlockTransactions cfg ctx lists oracle previous checks cap txs s total = .ok run) :
    ApplicationsValid cfg ctx lists (if checks.checkScripts && !checks.queued then oracle else deferredBlockOracle)
      s run.applications run.coins ∧ run.applications.map (·.tx) = txs := by
  induction txs generalizing s total run with
  | nil => simp [runBlockTransactions] at h; subst run; simp [ApplicationsValid]
  | cons tx rest ih =>
    simp only [runBlockTransactions, bind, Except.bind] at h
    cases hc : checkBlockInputs s cfg ctx previous tx total cap with
    | error e => simp [hc] at h
    | ok count =>
      simp only [hc] at h
      cases ha : applyTx s cfg ctx lists
          (if checks.checkScripts && !checks.queued then oracle else deferredBlockOracle) tx with
      | error e => rw [ha] at h; cases h
      | ok pair =>
        rcases pair with ⟨next, undo⟩
        simp only [ha] at h
        cases hr : runBlockTransactions cfg ctx lists oracle previous checks cap rest next count with
        | error e => simp [hr] at h
        | ok tail =>
          simp only [hr, pure, Except.pure, Except.ok.injEq] at h
          subst run
          obtain ⟨hv, ht⟩ := ih next count tail hr
          exact ⟨⟨rfl, ha, hv⟩, by simp [ht]⟩

/-- Accepted non-coinbase transactions have all inputs live. This exposes the
availability guard already present in the reused input validator.
[SRC] src/validation.cpp:3326–3331 at 6504a3af. -/
theorem applyTx_haveInputs (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (tx : Tx) (out : UtxoSet × Undo)
    (hcb : BsvScript.TxRules.isCoinBase tx = false)
    (h : applyTx s cfg ctx lists oracle tx = .ok out) : haveInputs s tx = true := by
  obtain ⟨fee, hf⟩ := applyTx_inputs_checked s cfg ctx lists oracle tx out hcb h
  unfold checkTxInputs at hf
  cases hi : haveInputs s tx <;> simp_all [bind, Except.bind, throw]

/-- Each receipt in an actual sequential run supplies the immediately preceding
view, in which every non-coinbase input is unspent. Later transactions may
spend outputs created earlier in the same block.
[SRC] src/validation.cpp:3324–3443 at 6504a3af. -/
theorem applications_inputs_unspent (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (before after : UtxoSet)
    (apps : List BlockApplication)
    (hv : ApplicationsValid cfg ctx lists oracle before apps after)
    (a : BlockApplication) (ha : a ∈ apps)
    (hcb : BsvScript.TxRules.isCoinBase a.tx = false) :
    ∀ input ∈ a.tx.inputs, (getCoin a.before (.ofInput input)).isSome = true := by
  induction apps generalizing before with
  | nil => simp at ha
  | cons head rest ih =>
    rcases hv with ⟨hb, hh, ht⟩
    rcases List.mem_cons.mp ha with he | he
    · subst a
      have hav := applyTx_haveInputs before cfg ctx lists oracle head.tx _ hcb hh
      simpa [haveInputs, hcb, ← hb, List.all_eq_true] using hav
    · exact ih head.after ht he

/-- No output may overwrite a surviving map entry in any sequential view.
For normalized live coins this is the note's no-live-overwrite premise.
[SRC] src/coins.cpp:560–565 and src/undo.h:109–112 at 6504a3af. -/
def NoBlockOverwrite (params : ChainParams) (height : Nat) (apps : List BlockApplication) : Prop :=
  ∀ a ∈ apps, ∀ p ∈ (createdOutputs params height a.tx).map Prod.fst,
    p ∉ eraseKeys a.before (spentOutpoints a.tx)

/-- Reverse application using retained vectors, without reading earlier views.
The receipts supply transaction and undo only to this inverse operation.
[SRC] src/processing_block_index.cpp:21–69 at 6504a3af. -/
def undoApplications (params : ChainParams) (height : Nat) : List BlockApplication → UtxoSet → UtxoSet
  | [], s => s
  | a :: rest, s => undoTx (undoApplications params height rest s) params height a.tx a.undo

/-- Qualified block undo identity. Induction reverses the tail, then applies
#61's map-extensional undo theorem. No prior-view snapshot is used by undo.
The no-overwrite premise is essential for coinbase outputs.
[SRC] src/processing_block_index.cpp:21–69, src/coins.cpp:560–565 and
src/undo.h:109–112 at 6504a3af. -/
theorem applications_undo_identity (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (before after : UtxoSet)
    (apps : List BlockApplication)
    (hv : ApplicationsValid cfg ctx lists oracle before apps after)
    (hn : NoBlockOverwrite ctx.params ctx.height apps) :
    undoApplications ctx.params ctx.height apps after = before := by
  induction apps generalizing before with
  | nil => exact hv.symm
  | cons a rest ih =>
    rcases hv with ⟨hb, ha, ht⟩
    have tailNo : NoBlockOverwrite ctx.params ctx.height rest := fun x hx => hn x (List.mem_cons_of_mem _ hx)
    simp only [undoApplications, ih a.after ht tailNo]
    have no := hn a (List.mem_cons_self ..)
    rw [hb] at no
    exact applyTx_undo before cfg ctx lists oracle a.tx (a.after, a.undo) ha no

/-- A non-genesis successful connection exposes its actual sequential run,
published coins and retained non-coinbase vectors. The prepared context is
explicit because unresolved network data is not a node judgment.
[SRC] src/validation.cpp:3021–3117,3290–3719 at 6504a3af. -/
theorem connectBlock_run (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int) (lists : FrozenLists)
    (oracle : ScriptOracle) (checks : ConnectionChecks) (ctx : UtxoContext) (out : ConnectedBlock)
    (hp : prepareBlockConnection view params cfg block previous now checks = .ok (some ctx))
    (hc : connectBlock view params cfg block previous now lists oracle checks = .ok out) :
    runBlockTransactions cfg ctx lists oracle previous checks
      ((1 + (block.encode.length - 1) / BsvScript.TxRules.MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS) *
        cfg.maxBlockSigOpsPerMbBeforeGenesis) block.transactions view.coins 0 = .ok out.run ∧
    out.view.coins = out.run.coins ∧ out.undo.transactions = (out.run.applications.drop 1).map (·.undo) := by
  unfold connectBlock at hc
  simp only [hp, bind, Except.bind] at hc
  generalize hr : runBlockTransactions cfg ctx lists oracle previous checks
    ((1 + (block.encode.length - 1) / BsvScript.TxRules.MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS) *
      cfg.maxBlockSigOpsPerMbBeforeGenesis) block.transactions view.coins 0 = result at hc
  cases result with
  | error e => simp [Except.mapError] at hc
  | ok run =>
    simp only [Except.mapError] at hc
    cases hb : block.transactions.head? with
    | none => simp [hb] at hc
    | some cb =>
      simp only [hb] at hc
      cases hf : checkCoinbaseAmount params ctx.height cb run.fees with
      | error e => simp [hf, Except.mapError] at hc
      | ok u =>
        cases u
        simp only [hf, Except.mapError] at hc
        cases hs : finishBlockScripts oracle run.calls with
        | error e => simp [hs, Except.mapError] at hc
        | ok u =>
          cases u
          simp only [hs, Except.mapError, pure, Except.pure, Except.ok.injEq] at hc
          subst out
          exact ⟨rfl, rfl, rfl⟩

/-- Every non-coinbase transaction in a successful connection has all inputs
unspent in its recorded sequential view. The receipts are derived above from
the executed body order, not provided by a caller.
[SRC] src/validation.cpp:3324–3443 at 6504a3af. -/
theorem connected_block_inputs_unspent (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int) (lists : FrozenLists)
    (oracle : ScriptOracle) (checks : ConnectionChecks) (ctx : UtxoContext) (out : ConnectedBlock)
    (hp : prepareBlockConnection view params cfg block previous now checks = .ok (some ctx))
    (hc : connectBlock view params cfg block previous now lists oracle checks = .ok out)
    (a : BlockApplication) (ha : a ∈ out.run.applications)
    (hcb : BsvScript.TxRules.isCoinBase a.tx = false) :
    ∀ input ∈ a.tx.inputs, (getCoin a.before (.ofInput input)).isSome = true := by
  have hr := (connectBlock_run view params cfg block previous now lists oracle checks ctx out hp hc).1
  have hv := (runBlockTransactions_valid cfg ctx lists oracle previous checks _ _ _ _ _ hr).1
  exact applications_inputs_unspent cfg ctx lists _ _ _ _ hv a ha hcb

/-- Successful connection followed by retained-vector reversal restores the
original map under the per-application no-overwrite condition. The following
clean-disconnect lemma connects this inverse to the status-returning API.
[SRC] src/processing_block_index.cpp:21–69 and src/coins.cpp:560–565 at 6504a3af. -/
theorem connected_block_undo_identity (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int) (lists : FrozenLists)
    (oracle : ScriptOracle) (checks : ConnectionChecks) (ctx : UtxoContext) (out : ConnectedBlock)
    (hp : prepareBlockConnection view params cfg block previous now checks = .ok (some ctx))
    (hc : connectBlock view params cfg block previous now lists oracle checks = .ok out)
    (hn : NoBlockOverwrite ctx.params ctx.height out.run.applications) :
    undoApplications ctx.params ctx.height out.run.applications out.view.coins = view.coins := by
  obtain ⟨hr, hv, _⟩ := connectBlock_run view params cfg block previous now lists oracle checks ctx out hp hc
  rw [hv]
  exact applications_undo_identity cfg ctx lists _ _ _ _
    (runBlockTransactions_valid cfg ctx lists oracle previous checks _ _ _ _ _ hr).1 hn

/-- Work wins independently of the tie observations.
[SRC] src/block_index.h:1225–1274 at 6504a3af. -/
theorem preferred_work (a b : BlockIndex) (h : preferred a b = true) : b.work.toNat ≤ a.work.toNat := by
  unfold preferred at h
  split at h
  · simp_all
    omega
  · simp_all

/-- Refusing a candidate never selects less work.
[SRC] src/block_index.h:1225–1274 at 6504a3af. -/
theorem not_preferred_work (a b : BlockIndex) (h : preferred a b = false) : a.work.toNat ≤ b.work.toNat := by
  unfold preferred at h
  split at h
  · simp_all
  · simp_all

/-- The chosen index is a member, and bounds the work of every candidate.
The proof follows the executable maximum, retaining equal-work possibilities.
[SRC] src/validation.cpp:4413–4494 at 6504a3af. -/
theorem bestCandidate_maximal (xs : List BlockIndex) (best : BlockIndex)
    (h : bestCandidate xs = some best) : best ∈ xs ∧ ∀ i ∈ xs, i.work.toNat ≤ best.work.toNat := by
  induction xs generalizing best with
  | nil => simp [bestCandidate] at h
  | cons i rest ih =>
    cases hr : bestCandidate rest with
    | none =>
      simp only [bestCandidate, hr, Option.some.injEq] at h
      subst best
      have empty : rest = [] := by
        cases rest with
        | nil => rfl
        | cons j js => cases hj : bestCandidate js <;> simp [bestCandidate, hj] at hr
      subst rest
      simp
    | some b =>
      obtain ⟨hb, hm⟩ := ih b hr
      cases hp : preferred i b with
      | false =>
        simp [bestCandidate, hr, hp] at h
        subst best
        refine ⟨List.mem_cons_of_mem _ hb, ?_⟩
        intro j hj
        rcases List.mem_cons.mp hj with rfl | hj
        · exact not_preferred_work j b hp
        · exact hm j hj
      | true =>
        simp [bestCandidate, hr, hp] at h
        subst best
        refine ⟨List.mem_cons_self .., ?_⟩
        intro j hj
        rcases List.mem_cons.mp hj with rfl | hj
        · exact Nat.le_refl _
        · exact Nat.le_trans (hm j hj) (preferred_work i b hp)

/-- A completed automatic activation passes its executable maximal-selection
postcondition. Interruptions, explicit invalidation and setting changes are
not silently called completed selections.
[SRC] src/validation.cpp:4913–5130 at 6504a3af. -/
theorem activateBestChain_complete (s : ChainState) (ctx : ChainContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (fuel : Nat) (out : ChainState)
    (h : activateBestChain s ctx lists oracle fuel = (out, .complete)) :
    activationComplete out = true := by
  unfold activateBestChain at h
  generalize he : activateLoop ctx lists oracle fuel s = result at h
  rcases result with ⟨final, status⟩
  cases status <;> simp_all
  exact h.1 ▸ h.2.1

/-- At a completed nonempty selection, the active identifier names an eligible
candidate of maximal accumulated work, including its available valid ancestry.
[SRC] src/validation.cpp:4413–4494,4913–5130 at 6504a3af. -/
theorem activation_maximal_work (s : ChainState) (h : activationComplete s = true)
    (tip : BitVec 256) (ht : s.active.getLast? = some tip) :
    ∃ best ∈ eligibleCandidates s, best.id = tip ∧
      ∀ i ∈ eligibleCandidates s, i.work.toNat ≤ best.work.toNat := by
  simp only [activationComplete, ht, beq_iff_eq] at h
  cases hb : bestCandidate (eligibleCandidates s) with
  | none => simp [hb] at h
  | some best =>
    have hi : best.id = tip := by simpa [hb] using h
    obtain ⟨hm, hw⟩ := bestCandidate_maximal _ best hb
    exact ⟨best, hm, hi, hw⟩

/-- Strict growth needs unequal selected work; an equal-work rank change cannot
prove it. [SRC] src/block_index.h:1225–1274 at 6504a3af. -/
theorem selection_strict_growth (xs : List BlockIndex) (old best : BlockIndex)
    (h : bestCandidate xs = some best) (ho : old ∈ xs)
    (different : old.work.toNat ≠ best.work.toNat) : old.work.toNat < best.work.toNat := by
  have := (bestCandidate_maximal xs best h).2 old ho
  omega

/-- Connecting preserves every existing active-chain member. The executable
event operation is the one used by connectTip.
[SRC] src/validation.cpp:4391 at 6504a3af. -/
theorem connection_preserves_members (active : List (BitVec 256)) (h block : BitVec 256)
    (hm : h ∈ active) : h ∈ applyChainEvent active (.connected block) := by
  simp [applyChainEvent, hm]

/-- Any lost active block requires a disconnect event, with its cause named.
This replaces the issue's unqualified more-work-only removal claim.
[SRC] src/validation.cpp:4117,4391,4526–4553,5203–5330 at 6504a3af. -/
theorem removal_requires_disconnect (active : List (BitVec 256)) (event : ChainEvent)
    (h : BitVec 256) (before : h ∈ active) (after : h ∉ applyChainEvent active event) :
    ∃ cause block, event = .disconnected cause block := by
  cases event with
  | connected block => exact False.elim (after (connection_preserves_members active h block before))
  | disconnected cause block => exact ⟨cause, block, rfl⟩

/-- The removal causes are exhaustive, including explicit disconnect, invalidate,
soft rejection and freeze changes separately from a reorg.
[SRC] src/validation.cpp:4065–4133,4526–4553,4603–4612,5203–5330 at 6504a3af. -/
theorem removal_causes (active : List (BitVec 256)) (event : ChainEvent)
    (h : BitVec 256) (before : h ∈ active) (after : h ∉ applyChainEvent active event) :
    ∃ block, event = .disconnected .reorg block ∨ event = .disconnected .explicit block ∨
      event = .disconnected .invalidate block ∨ event = .disconnected .softRejection block ∨
      event = .disconnected .freezeChange block := by
  obtain ⟨cause, block, rfl⟩ := removal_requires_disconnect active event h before after
  cases cause <;> exact ⟨block, by simp⟩

/-- The inverse depends only on the retained transaction/vector pairs.
[SRC] src/processing_block_index.cpp:21–69 at 6504a3af. -/
def undoPairs (params : ChainParams) (height : Nat) : List (Tx × Undo × Bool) → UtxoSet → UtxoSet
  | [], s => s
  | (tx, undo, _) :: rest, s => undoTx (undoPairs params height rest s) params height tx undo

/-- Well-formed retained vectors are already pruned by stored creation height;
coinbase's vector is empty. These are representation invariants, distinct from
the no-overwrite condition. [SRC] src/coins.cpp:45–64 and src/undo.h:109–112
at 6504a3af. -/
def UndoPairsWellFormed (params : ChainParams) (pairs : List (Tx × Undo × Bool)) : Prop :=
  ∀ tx undo cb, (tx, undo, cb) ∈ pairs →
    restorableUndo params undo = undo ∧ (cb = true → undo = ⟨[]⟩)

/-- A clean one-transaction undo is precisely the spent-vector inverse on a
well-formed retained vector. Status checks cannot invent a prior coin.
[SRC] src/processing_block_index.cpp:30–69 at 6504a3af. -/
theorem disconnectTransaction_clean (params : ChainParams) (height : Nat) (s out : UtxoSet)
    (tx : Tx) (undo : Undo) (cb : Bool)
    (hn : restorableUndo params undo = undo) (hb : cb = true → undo = ⟨[]⟩)
    (h : disconnectTransaction s params height tx undo cb = (.ok, out)) :
    out = undoTx s params height tx undo := by
  unfold disconnectTransaction at h
  split at h
  · cases h
  · cases cb with
    | true =>
      have he := hb rfl
      subst undo
      have hh := congrArg Prod.snd h
      simpa [restorableUndo] using hh.symm
    | false =>
      have hh := congrArg Prod.snd h
      simpa [hn] using hh.symm

/-- Clean block undo equals the reverse retained-vector computation. A clean
aggregate requires every transaction undo to be clean; failure never publishes.
[SRC] src/processing_block_index.cpp:21–76 at 6504a3af. -/
theorem disconnectTransactions_clean (params : ChainParams) (height : Nat)
    (pairs : List (Tx × Undo × Bool)) (s out : UtxoSet)
    (hw : UndoPairsWellFormed params pairs)
    (h : disconnectTransactions params height pairs s = (.ok, out)) :
    out = undoPairs params height pairs s := by
  induction pairs generalizing out with
  | nil => simpa [disconnectTransactions, undoPairs] using congrArg Prod.snd h |>.symm
  | cons pair rest ih =>
    rcases pair with ⟨tx, undo, cb⟩
    have hr : UndoPairsWellFormed params rest := fun t u b hm => hw t u b (List.mem_cons_of_mem _ hm)
    obtain ⟨hn, hb⟩ := hw tx undo cb (List.mem_cons_self ..)
    cases ht : disconnectTransactions params height rest s with
    | mk status middle =>
      cases status with
      | failed => simp [disconnectTransactions, ht] at h
      | unclean =>
        cases hh : disconnectTransaction middle params height tx undo cb with
        | mk status before => cases status <;> simp [disconnectTransactions, ht, hh] at h
      | ok =>
        cases hh : disconnectTransaction middle params height tx undo cb with
        | mk status before =>
          cases status with
          | failed => simp [disconnectTransactions, ht, hh] at h
          | unclean => simp [disconnectTransactions, ht, hh] at h
          | ok =>
            have he : before = out := by simpa [disconnectTransactions, ht, hh] using congrArg Prod.snd h
            rw [← he, disconnectTransaction_clean params height middle before tx undo cb hn hb hh]
            simp only [undoPairs, ih middle hr ht]

/-- A receipt list projected to ordinary vectors has the same reverse action.
[SRC] src/processing_block_index.cpp:21–69 at 6504a3af. -/
theorem undoPairs_applications (params : ChainParams) (height : Nat)
    (apps : List BlockApplication) (s : UtxoSet) :
    undoPairs params height (apps.map (fun a => (a.tx, a.undo, false))) s =
      undoApplications params height apps s := by
  induction apps with
  | nil => rfl
  | cons a rest ih => simp [undoPairs, undoApplications, ih]

/-- The source's vector layout equals the receipt projection when its coinbase
vector is empty. No earlier UTXO views occur in this equality.
[SRC] src/undo.h:109–112 and src/processing_block_index.cpp:51–59 at 6504a3af. -/
theorem blockUndoPairs_applications (apps : List BlockApplication)
    (headEmpty : ∀ a, apps.head? = some a → a.undo = ⟨[]⟩) :
    (blockUndoPairs (apps.map (·.tx)) ((apps.drop 1).map (·.undo))).map
      (fun (tx, u, _) => (tx, u)) = apps.map (fun a => (a.tx, a.undo)) := by
  cases apps with
  | nil => rfl
  | cons a rest =>
    have he := headEmpty a rfl
    clear headEmpty
    simp only [List.map_cons, List.drop_succ_cons, List.drop_zero, blockUndoPairs, List.map_cons]
    congr 1
    · simp [he]
    · induction rest with
      | nil => rfl
      | cons b rest ih => simpa using congrArg (List.cons (b.tx, b.undo)) ih

/-- Erasing the positional coinbase marker preserves the inverse's input.
[SRC] src/processing_block_index.cpp:21–69 at 6504a3af. -/
theorem undoPairs_congr (params : ChainParams) (height : Nat)
    (xs ys : List (Tx × Undo × Bool))
    (h : xs.map (fun (t,u,_) => (t,u)) = ys.map (fun (t,u,_) => (t,u))) (s : UtxoSet) :
    undoPairs params height xs s = undoPairs params height ys s := by
  induction xs generalizing ys with
  | nil => cases ys <;> simp_all [undoPairs]
  | cons x xs ih =>
    cases ys with
    | nil => simp at h
    | cons y ys =>
      rcases x with ⟨tx, u, cb⟩
      rcases y with ⟨ty, v, db⟩
      simp only [List.map_cons, List.cons.injEq, Prod.mk.injEq] at h
      rcases h with ⟨⟨rfl, rfl⟩, ht⟩
      simp [undoPairs, ih ys ht]

/-- The actual clean DisconnectTip API restores the original set after a
successful non-genesis connection, given a well-formed retained undo and no
live overwrite. This combines executable connection, vector layout, status
checks and #61's map-extensional inverse, with no domain axiom.
[SRC] src/validation.cpp:4065–4117, src/processing_block_index.cpp:9–77,
src/coins.cpp:560–565 and src/undo.h:109–112 at 6504a3af. -/
theorem connect_disconnect_identity (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int) (lists : FrozenLists)
    (oracle : ScriptOracle) (checks : ConnectionChecks) (ctx : UtxoContext) (out : ConnectedBlock)
    (hp : prepareBlockConnection view params cfg block previous now checks = .ok (some ctx))
    (hc : connectBlock view params cfg block previous now lists oracle checks = .ok out)
    (paramsAgree : ctx.params = params)
    (hn : NoBlockOverwrite ctx.params ctx.height out.run.applications)
    (headEmpty : ∀ a, out.run.applications.head? = some a → a.undo = ⟨[]⟩)
    (hw : UndoPairsWellFormed params (blockUndoPairs block.transactions out.undo.transactions))
    (restored : CoinsView)
    (hd : disconnectBlock out.view params ctx.height block out.undo = (.ok, restored)) :
    restored.coins = view.coins := by
  obtain ⟨hr, _, hu⟩ := connectBlock_run view params cfg block previous now lists oracle checks ctx out hp hc
  have order := (runBlockTransactions_valid cfg ctx lists oracle previous checks _ _ _ _ _ hr).2
  have inverse := connected_block_undo_identity view params cfg block previous now lists oracle checks ctx out hp hc hn
  rw [paramsAgree] at inverse
  unfold disconnectBlock at hd
  split at hd
  · cases hd
  · cases hundo : applyBlockUndo out.view params ctx.height block out.undo with
    | mk status tentative =>
      cases status with
      | failed => simp [hundo] at hd
      | unclean => simp [hundo] at hd
      | ok =>
        have he : tentative = restored := by simpa [hundo] using hd
        subst restored
        unfold applyBlockUndo at hundo
        split at hundo
        · cases hundo
        · cases ht : disconnectTransactions params ctx.height (blockUndoPairs block.transactions out.undo.transactions) out.view.coins with
          | mk status coins =>
            simp only [ht, Prod.mk.injEq] at hundo
            rcases hundo with ⟨hs, hv⟩
            subst status
            have hi := disconnectTransactions_clean params ctx.height _ out.view.coins coins hw ht
            have pairs := blockUndoPairs_applications out.run.applications headEmpty
            rw [order, ← hu] at pairs
            have heq := undoPairs_congr params ctx.height _
              (out.run.applications.map (fun a => (a.tx, a.undo, false)))
              (by simpa only [List.map_map, Function.comp_def] using pairs) out.view.coins
            have := congrArg CoinsView.coins hv
            dsimp at this
            rw [← this, hi, heq, undoPairs_applications, inverse]

/-- The maximal-work law directly for the public activation transition. It is
conditional on completion, not merely on the source's boolean return.
[SRC] src/validation.cpp:4413–4494,4913–5130 at 6504a3af. -/
theorem activateBestChain_maximal_work (s : ChainState) (ctx : ChainContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (fuel : Nat) (out : ChainState)
    (h : activateBestChain s ctx lists oracle fuel = (out, .complete))
    (tip : BitVec 256) (ht : out.active.getLast? = some tip) :
    ∃ best ∈ eligibleCandidates out, best.id = tip ∧
      ∀ i ∈ eligibleCandidates out, i.work.toNat ≤ best.work.toNat := by
  exact activation_maximal_work out (activateBestChain_complete s ctx lists oracle fuel out h) tip ht

/-- Active transaction membership is inclusion in an active block body. This
does not synthesize the later status machine or a merkle-proof judgment.
[SRC] src/validation.cpp:4117,4391 at 6504a3af. -/
def ActiveTransaction (tree : HeaderTree) (active : List (BitVec 256)) (tx : Tx) : Prop :=
  ∃ hash ∈ active, ∃ block, (tree.get hash).bind (·.body) = some block ∧ tx ∈ block.transactions

/-- A transaction can lose active-body membership at an active-chain event only
through disconnection. Connection preserves all old bodies and memberships;
reorg, explicit disconnect, invalidate, soft rejection and freeze changes are
the named causes in removal_causes, not an unqualified more-work promise.
[SRC] src/validation.cpp:4117,4391,4526–4553,5203–5330 at 6504a3af. -/
theorem transaction_removal_requires_disconnect (tree : HeaderTree)
    (active : List (BitVec 256)) (tx : Tx) (event : ChainEvent)
    (before : ActiveTransaction tree active tx)
    (after : ¬ ActiveTransaction tree (applyChainEvent active event) tx) :
    ∃ cause block, event = .disconnected cause block := by
  cases event with
  | disconnected cause block => exact ⟨cause, block, rfl⟩
  | connected block =>
    obtain ⟨hash, hh, body, hb, ht⟩ := before
    exact False.elim (after ⟨hash, connection_preserves_members active hash block hh, body, hb, ht⟩)

/-- Named removal laws cover explicit disconnect, invalidation and settings as
well as reorg. Work growth needs its own eligibility hypotheses.
[SRC] src/validation.cpp:4065–4133,4526–4553,4603–4612,5203–5330 at 6504a3af. -/
theorem transaction_removal_causes (tree : HeaderTree)
    (active : List (BitVec 256)) (tx : Tx) (event : ChainEvent)
    (before : ActiveTransaction tree active tx)
    (after : ¬ ActiveTransaction tree (applyChainEvent active event) tx) :
    ∃ block, event = .disconnected .reorg block ∨ event = .disconnected .explicit block ∨
      event = .disconnected .invalidate block ∨ event = .disconnected .softRejection block ∨
      event = .disconnected .freezeChange block := by
  obtain ⟨cause, block, rfl⟩ := transaction_removal_requires_disconnect tree active tx event before after
  cases cause <;> exact ⟨block, by simp⟩

/-- Immutable index data throughout chain execution, including retained bodies
and work even when a candidate is pruned. [SRC] src/validation.cpp:4498–4523,
4345–4404,5528–5562 at 6504a3af. -/
def indexCore (i : BlockIndex) := (i.header, i.work, i.chainTx, i.body)

/-- Projection unaffected by validity, settings, candidate and undo updates.
[SRC] src/validation.cpp:4065–4133,4345–4553 at 6504a3af. -/
def treeCore (t : HeaderTree) := t.nodes.map indexCore

/-- Executed trace with preserved body/work data and caller-specific causes.
[SRC] src/validation.cpp:4117,4391,4526–4553,4603–4616,5203–5330 at 6504a3af. -/
def ChainExecution (allowed : DisconnectCause → Prop) (s t : ChainState) : Prop :=
  treeCore t.tree = treeCore s.tree ∧ ∃ trace,
    t.events = s.events ++ trace ∧ t.active = trace.foldl applyChainEvent s.active ∧
    ∀ cause hash, ChainEvent.disconnected cause hash ∈ trace → allowed cause

/-- An unchanged active projection executes an empty trace.
[SRC] src/validation.cpp:4065–4117 at 6504a3af. -/
theorem execution_quiet (allowed : DisconnectCause → Prop) (s t : ChainState)
    (hc : treeCore t.tree = treeCore s.tree) (ha : t.active = s.active)
    (he : t.events = s.events) : ChainExecution allowed s t := by
  exact ⟨hc, [], by simpa using he, ha, by simp⟩

/-- Concatenation composes actual traces and their cause restrictions.
[SRC] src/validation.cpp:4603–4767 at 6504a3af. -/
theorem execution_trans {allowed : DisconnectCause → Prop} {s t u : ChainState}
    (h : ChainExecution allowed s t) (j : ChainExecution allowed t u) :
    ChainExecution allowed s u := by
  obtain ⟨hc, xs, he, ha, hx⟩ := h
  obtain ⟨jc, ys, je, ja, hy⟩ := j
  refine ⟨jc.trans hc, xs ++ ys, ?_, ?_, ?_⟩
  · simp [je, he, List.append_assoc]
  · simp [List.foldl_append, ← ha, ja]
  · intro c b hm
    exact (List.mem_append.mp hm).elim (hx c b) (hy c b)

/-- Emission records precisely the event used to mutate the active chain.
[SRC] src/validation.cpp:4117,4391 at 6504a3af. -/
theorem execution_emit (allowed : DisconnectCause → Prop) (s : ChainState) (e : ChainEvent)
    (hc : ∀ c b, e = .disconnected c b → allowed c) :
    ChainExecution allowed s (s.emit e) := by
  refine ⟨rfl, [e], rfl, rfl, ?_⟩
  intro c b hm
  exact hc c b (List.mem_singleton.mp hm).symm

/-- Branches that preserve index data also preserve it under a boolean choice.
[SRC] src/validation.cpp:4453–4475,5528–5562 at 6504a3af. -/
theorem indexCore_choice {condition : Prop} [Decidable condition] (a b i : BlockIndex)
    (ha : indexCore a = indexCore i) (hb : indexCore b = indexCore i) :
    indexCore (if condition then a else b) = indexCore i := by
  split <;> assumption

/-- Mapping index edits preserves their ordered immutable projection when each
edit preserves it. [SRC] src/validation.cpp:5528–5562 at 6504a3af. -/
theorem map_indexCore (nodes : List BlockIndex) (f : BlockIndex → BlockIndex)
    (h : ∀ i, indexCore (f i) = indexCore i) :
    (nodes.map f).map indexCore = nodes.map indexCore := by
  induction nodes with
  | nil => rfl
  | cons i rest ih => simp only [List.map_cons, h i, ih]

/-- Metadata modification keeps the ordered immutable index projection.
[SRC] src/block_index.h:508–514 and src/validation.cpp:5528–5562 at 6504a3af. -/
theorem modify_core (tree : HeaderTree) (hash : BitVec 256) (f : BlockIndex → BlockIndex)
    (h : ∀ i, indexCore (f i) = indexCore i) :
    treeCore (tree.modify hash f) = treeCore tree := by
  apply map_indexCore
  intro i
  exact indexCore_choice _ _ i (h i) rfl

/-- Candidate insertion changes no retained index data.
[SRC] src/validation.cpp:5705–5708 at 6504a3af. -/
@[simp] theorem insertCandidate_core (tree : HeaderTree) (active : List (BitVec 256)) (i : BlockIndex) :
    treeCore (insertCandidate tree active i) = treeCore tree := by
  unfold insertCandidate
  split <;> rfl

/-- Explicit rewind restores the candidate set without rewriting bodies/work.
[SRC] src/validation.cpp:5294–5303 at 6504a3af. -/
theorem restoreCandidates_execution (allowed : DisconnectCause → Prop) (s : ChainState) :
    ChainExecution allowed s (restoreCandidates s) := by
  apply execution_quiet <;> try rfl
  unfold restoreCandidates
  dsimp
  generalize s.tree.nodes = nodes
  induction nodes generalizing s with
  | nil => rfl
  | cons i rest ih =>
    simp only [List.foldl_cons]
    split
    · exact (ih { s with tree := insertCandidate s.tree s.active i }).trans (insertCandidate_core ..)
    · exact ih s

/-- Invalid marking changes failure metadata and candidate membership only.
[SRC] src/validation.cpp:4453–4475,5230–5289 at 6504a3af. -/
@[simp] theorem markInvalid_core (tree : HeaderTree) (hash : BitVec 256) (markSelf : Bool) :
    treeCore (markInvalid tree hash markSelf) = treeCore tree := by
  apply map_indexCore
  intro i
  apply indexCore_choice
  · exact indexCore_choice _ _ i rfl rfl
  · exact indexCore_choice _ _ i rfl rfl

/-- Soft-count propagation preserves immutable data on every finite pass.
[SRC] src/block_index.h:542–580,1131–1146 at 6504a3af. -/
@[simp] theorem propagateSoftSettings_core (tree : HeaderTree) :
    treeCore (propagateSoftSettings tree) = treeCore tree := by
  unfold propagateSoftSettings
  generalize List.range (tree.nodes.length + 1) = rounds
  induction rounds generalizing tree with
  | nil => rfl
  | cons n rest ih =>
    simp only [List.foldl_cons]
    rw [ih]
    simp [treeCore, List.map_map, indexCore]

/-- Effective freeze marking changes only setting metadata.
[SRC] src/validation.cpp:3402–3407 at 6504a3af. -/
@[simp] theorem freezeBlockIndex_core (tree : HeaderTree) (hash : BitVec 256) (duration : Nat) :
    treeCore (freezeBlockIndex tree hash duration) = treeCore tree := by
  unfold freezeBlockIndex
  rw [propagateSoftSettings_core]
  exact modify_core _ _ _ (fun _ => rfl)

/-- Pruning leaves active membership, event history and retained bodies intact.
[SRC] src/validation.cpp:4498–4523 at 6504a3af. -/
theorem pruneCandidates_execution (allowed : DisconnectCause → Prop) (s : ChainState) :
    ChainExecution allowed s (pruneCandidates s) := by
  unfold pruneCandidates
  split
  · exact execution_quiet allowed _ _ rfl rfl rfl
  · split <;> exact execution_quiet allowed _ _ rfl rfl rfl

/-- Pool settlement cannot alter chain membership, bodies or accumulated work.
[SRC] src/txmempool.cpp:2330–2485 at 6504a3af. -/
theorem settleReorg_execution (allowed : DisconnectCause → Prop) (s : ChainState)
    (ctx : ChainContext) (lists : FrozenLists) (oracle : ScriptOracle) (failed : Bool) :
    ChainExecution allowed s (settleReorg s ctx lists oracle failed) := by
  unfold settleReorg
  split <;> exact execution_quiet allowed _ _ rfl rfl rfl

/-- Successful connection preserves bodies/work and records only connection.
[SRC] src/validation.cpp:4345–4404 at 6504a3af. -/
theorem connectTip_execution (allowed : DisconnectCause → Prop) (s out : ChainState)
    (ctx : ChainContext) (lists : FrozenLists) (oracle : ScriptOracle) (i target : BlockIndex)
    (h : connectTip s ctx lists oracle i target = .ok out) : ChainExecution allowed s out := by
  cases hb : i.body with
  | none => simp [connectTip, hb] at h
  | some block =>
    simp only [connectTip, hb, bind, Except.bind] at h
    split at h
    · cases h
    · cases hr : connectBlock s.view ctx.params ctx.cfg block (headerContext s.tree i.parent)
        ctx.now (ctx.connectionLists s i target lists) oracle (ctx.connectionChecks s i target) with
      | error r => simp [hr] at h
      | ok connected =>
        simp only [hr, pure, Except.pure, Except.ok.injEq] at h
        subst out
        apply execution_trans _ (pruneCandidates_execution allowed _)
        apply execution_trans _ (execution_emit allowed _ _ (by simp))
        apply execution_quiet <;> try rfl
        exact modify_core _ _ _ (fun _ => rfl)

/-- Every clean disconnection emits its caller's cause; failed undo is quiet.
[SRC] src/validation.cpp:4065–4133 at 6504a3af. -/
theorem disconnectTip_execution (allowed : DisconnectCause → Prop) (s : ChainState)
    (ctx : ChainContext) (cause : DisconnectCause) (hc : allowed cause) :
    ChainExecution allowed s (disconnectTip s ctx cause).1 := by
  unfold disconnectTip
  simp only [Id.run, bind, pure]
  cases ht : s.active.getLast?.bind s.tree.get with
  | none => exact execution_quiet allowed _ _ rfl rfl rfl
  | some tip =>
    simp only [ht]
    cases hb : tip.body with
    | none => simp only [hb]; exact execution_quiet allowed _ _ rfl rfl rfl
    | some block =>
      simp only [hb]
      cases hu : tip.undo with
      | none => simp only [hu]; exact execution_quiet allowed _ _ rfl rfl rfl
      | some undo =>
        simp only [hu]
        split
        · exact execution_quiet allowed _ _ rfl rfl rfl
        · apply execution_trans _ (execution_emit allowed _ _ ?_)
          · exact execution_quiet allowed _ _ rfl rfl rfl
          · intro c b h
            cases h
            exact hc

/-- Candidate search only changes metadata and candidate/unlinked membership.
[SRC] src/validation.cpp:4413–4494 at 6504a3af. -/
theorem findMostWorkLoop_execution (allowed : DisconnectCause → Prop) (fuel : Nat) (s : ChainState) :
    ChainExecution allowed s (findMostWorkLoop fuel s).1 := by
  induction fuel generalizing s with
  | zero => exact execution_quiet allowed _ _ rfl rfl rfl
  | succ n ih =>
    simp only [findMostWorkLoop]
    split
    · exact execution_quiet allowed _ _ rfl rfl rfl
    · split
      · exact execution_quiet allowed _ _ rfl rfl rfl
      · apply execution_trans _ (ih _)
        apply execution_quiet <;> try rfl
        dsimp only [treeCore]
        split
        · split
          · exact markInvalid_core _ _ _
          · rfl
        · rfl

/-- The fork walk composes clean disconnections with their supplied cause.
[SRC] src/validation.cpp:4603–4616 at 6504a3af. -/
theorem disconnectToFork_execution (allowed : DisconnectCause → Prop) (ctx : ChainContext)
    (cause : DisconnectCause) (hc : allowed cause) (fork : Option (BitVec 256))
    (fuel : Nat) (s : ChainState) :
    ChainExecution allowed s (disconnectToFork ctx cause fork fuel s).1 := by
  induction fuel generalizing s with
  | zero => exact execution_quiet allowed _ _ rfl rfl rfl
  | succ n ih =>
    simp only [disconnectToFork]
    split
    · exact execution_quiet allowed _ _ rfl rfl rfl
    · split
      · exact execution_trans (disconnectTip_execution allowed s ctx cause hc) (ih _)
      · exact disconnectTip_execution allowed s ctx cause hc

/-- Excluded-tip cleanup emits the effective setting responsible at each step.
[SRC] src/validation.cpp:4526–4553,5203–5225 at 6504a3af. -/
theorem disconnectExcludedTips_execution (allowed : DisconnectCause → Prop) (ctx : ChainContext)
    (hs : allowed .softRejection) (hf : allowed .freezeChange) (fuel : Nat) (s : ChainState) :
    ChainExecution allowed s (disconnectExcludedTips ctx fuel s).1 := by
  induction fuel generalizing s with
  | zero => exact execution_quiet allowed _ _ rfl rfl rfl
  | succ n ih =>
    simp only [disconnectExcludedTips]
    split
    · exact execution_quiet allowed _ _ rfl rfl rfl
    · split
      · exact execution_quiet allowed _ _ rfl rfl rfl
      · rename_i tip _ _
        by_cases hrej : tip.softRejected ≥ 0
        · simp only [if_pos hrej]
          have hd := disconnectTip_execution allowed s ctx .softRejection hs
          split
          · exact execution_trans hd (ih _)
          · exact hd
        · simp only [if_neg hrej]
          have hd := disconnectTip_execution allowed s ctx .freezeChange hf
          split
          · exact execution_trans hd (ih _)
          · exact hd

/-- A connection run preserves bodies/work and composes its actual events;
failure metadata itself removes no active membership.
[SRC] src/validation.cpp:4692–4754 at 6504a3af. -/
theorem connectRun_execution (allowed : DisconnectCause → Prop) (ctx : ChainContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (target : BlockIndex) (oldWork : Nat)
    (path : List BlockIndex) (s : ChainState) :
    ChainExecution allowed s (connectRun ctx lists oracle target oldWork path s).1 := by
  induction path generalizing s with
  | nil => exact execution_quiet allowed _ _ rfl rfl rfl
  | cons i rest ih =>
    let start := if (s.active.getLast?.bind s.tree.get).any (fun tip => tip.work.toNat == oldWork) then
      settleReorg s ctx lists oracle else s
    have hstart : ChainExecution allowed s start := by
      dsimp [start]
      split
      · exact settleReorg_execution allowed s ctx lists oracle false
      · exact execution_quiet allowed _ _ rfl rfl rfl
    change ChainExecution allowed s
      ((match connectTip start ctx lists oracle i target with
       | .ok next => if i.work.toNat > oldWork then (next, .stepDone)
           else connectRun ctx lists oracle target oldWork rest next
       | .error r => if r.code == .node 0x13 then
           ({ start with tree := freezeBlockIndex start.tree i.id ctx.cfg.softConsensusFreezeDuration }, .stepDone)
         else if r.code == .node 0 || r.corruptionPossible then (start, .failed (.unresolved r.reason))
         else ({ start with tree := markInvalid start.tree i.id }, .stepDone)) : ChainState × ConnectionProgress).1
    cases hconn : connectTip start ctx lists oracle i target with
    | ok next =>
      simp only [hconn]
      have hn := execution_trans hstart (connectTip_execution allowed start next ctx lists oracle i target hconn)
      split
      · exact hn
      · exact execution_trans hn (ih next)
    | error r =>
      simp only [hconn]
      split
      · exact execution_trans hstart (execution_quiet allowed _ _ (freezeBlockIndex_core ..) rfl rfl)
      · split
        · exact hstart
        · exact execution_trans hstart (execution_quiet allowed _ _ (markInvalid_core ..) rfl rfl)

/-- Every batch retains the trace and immutable-data invariant of its input.
[SRC] src/validation.cpp:4674–4767 at 6504a3af. -/
theorem connectBatches_execution (allowed : DisconnectCause → Prop) (ctx : ChainContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (target : BlockIndex) (oldWork fuel : Nat)
    (path : List BlockIndex) (s : ChainState) :
    ChainExecution allowed s (connectBatches ctx lists oracle target oldWork fuel path s).1 := by
  induction fuel generalizing path s with
  | zero => exact execution_quiet allowed _ _ rfl rfl rfl
  | succ n ih =>
    simp only [connectBatches]
    split
    · exact execution_quiet allowed _ _ rfl rfl rfl
    · split
      · exact execution_quiet allowed _ _ rfl rfl rfl
      · have hr := connectRun_execution allowed ctx lists oracle target oldWork
          (path.take ctx.cfg.maxBlockConnectionBatch) s
        split
        · exact execution_trans hr (ih _ _)
        · exact hr

/-- Automatic removals are reorgs or effective setting exclusions. Explicit
invalidation/disconnection use separate callers. [SRC]
src/validation.cpp:4526–4553,4603–4616,5203–5225 at 6504a3af. -/
def AutomaticCause (cause : DisconnectCause) : Prop :=
  cause = .reorg ∨ cause = .softRejection ∨ cause = .freezeChange

/-- One activation step records only automatic causes and preserves bodies/work.
[SRC] src/validation.cpp:4561–4800 at 6504a3af. -/
theorem activationStep_execution (allowed : DisconnectCause → Prop) (ctx : ChainContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (hr : allowed .reorg) (s : ChainState) :
    ChainExecution allowed s (activationStep s ctx lists oracle).1 := by
  unfold activationStep
  simp only [Id.run, bind, pure]
  have hsearch := findMostWorkLoop_execution allowed (s.tree.candidates.length + 1) s
  change ChainExecution allowed s (findMostWorkChain s).1 at hsearch
  split
  · exact hsearch
  · split
    · split
      · rename_i choice _ backwards _
        have hd := disconnectToFork_execution allowed ctx .reorg hr
          ((backwards.find? (fun i => (findMostWorkChain s).1.active.contains i.id)).map (·.id))
          ((findMostWorkChain s).1.active.length + 1) (findMostWorkChain s).1
        split
        · exact execution_trans (execution_trans hsearch hd) (settleReorg_execution allowed _ ctx lists oracle false)
        · split <;> exact execution_trans (execution_trans (execution_trans hsearch hd)
            (connectBatches_execution allowed ctx lists oracle _ _ _ _ _))
            (settleReorg_execution allowed _ ctx lists oracle false)
      · exact hsearch
    · exact hsearch

/-- The exclusion classifier names the effective setting behind the rewind.
[SRC] src/validation.cpp:4526–4553,5203–5225 at 6504a3af. -/
theorem activeExclusion_cause (s : ChainState) (cause : DisconnectCause)
    (h : activeExclusion s = some cause) : cause = .softRejection ∨ cause = .freezeChange := by
  unfold activeExclusion at h
  split at h
  · simp at h
  · split at h
    · exact Or.inr (by simpa using h.symm)
    · split at h <;> simp_all

/-- The automatic loop composes actual event traces through retries, batches
and failed undo, retaining all bodies and work. [SRC]
src/validation.cpp:4413–4800,4913–5130 at 6504a3af. -/
theorem activateLoop_execution (allowed : DisconnectCause → Prop) (ctx : ChainContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (hr : allowed .reorg)
    (hs : allowed .softRejection) (hf : allowed .freezeChange) (fuel : Nat) (s : ChainState) :
    ChainExecution allowed s (activateLoop ctx lists oracle fuel s).1 := by
  induction fuel generalizing s with
  | zero => exact execution_quiet allowed _ _ rfl rfl rfl
  | succ n ih =>
    simp only [activateLoop]
    cases he : activeExclusion s with
    | some cause =>
      simp only [he]
      have hc : allowed cause := (activeExclusion_cause s cause he).elim (fun h => h.symm ▸ hs) (fun h => h.symm ▸ hf)
      have hd := disconnectTip_execution allowed s ctx cause hc
      split
      · exact execution_trans hd (settleReorg_execution allowed _ ctx lists oracle true)
      · exact execution_trans (execution_trans hd (restoreCandidates_execution allowed _)) (ih _)
    | none =>
      simp only [he]
      have ht := activationStep_execution allowed ctx lists oracle hr s
      split
      · exact ht
      · exact execution_trans ht (ih _)

/-- Public automatic activation executes the recorded trace with automatic
causes, on both completed and interrupted/error outcomes.
[SRC] src/validation.cpp:4913–5130 at 6504a3af. -/
theorem activateBestChain_execution (allowed : DisconnectCause → Prop) (ctx : ChainContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (hr : allowed .reorg)
    (hs : allowed .softRejection) (hf : allowed .freezeChange) (fuel : Nat) (s : ChainState) :
    ChainExecution allowed s (activateBestChain s ctx lists oracle fuel).1 := by
  exact execution_trans (activateLoop_execution allowed ctx lists oracle hr hs hf fuel s)
    (settleReorg_execution allowed _ ctx lists oracle false)

/-- Folding metadata-only edits preserves the immutable index projection.
[SRC] src/validation.cpp:5234–5289,5294–5303 at 6504a3af. -/
theorem fold_treeCore {α : Type} (f : HeaderTree → α → HeaderTree)
    (hf : ∀ tree a, treeCore (f tree a) = treeCore tree) (xs : List α) (tree : HeaderTree) :
    treeCore (xs.foldl f tree) = treeCore tree := by
  induction xs generalizing tree with
  | nil => rfl
  | cons a rest ih => exact (ih (f tree a)).trans (hf tree a)

/-- Invalidation composes marked-index preservation, its own rewind cause,
setting cleanup, and automatic reactivation. Failed undo retains the trace.
[SRC] src/validation.cpp:5230–5330 at 6504a3af. -/
theorem invalidateBlock_execution (allowed : DisconnectCause → Prop) (s : ChainState)
    (ctx : ChainContext) (lists : FrozenLists) (oracle : ScriptOracle) (hash : BitVec 256) (fuel : Nat)
    (hi : allowed .invalidate) (hr : allowed .reorg) (hs : allowed .softRejection) (hf : allowed .freezeChange) :
    ChainExecution allowed s (invalidateBlock s ctx lists oracle hash fuel).1 := by
  let tree := (s.active.dropWhile (· != hash)).foldl
    (fun tree h => tree.modify h (fun i => { i with status := { i.status with failedParent := true } }))
    (markInvalid s.tree hash)
  let marked := { s with tree }
  have hm : ChainExecution allowed s marked := by
    apply execution_quiet <;> try rfl
    exact (fold_treeCore
      (fun tree h => tree.modify h (fun i => { i with status := { i.status with failedParent := true } }))
      (fun tree hash => modify_core tree hash _ (fun _ => rfl)) _ _).trans (markInvalid_core ..)
  let fork := if s.active.contains hash then (s.tree.get hash).bind (·.parent) else s.active.getLast?
  let rewound := disconnectToFork ctx .invalidate fork (s.active.length + 1) marked
  have hd : ChainExecution allowed s rewound.1 :=
    execution_trans hm (disconnectToFork_execution allowed ctx .invalidate hi _ _ marked)
  let excluded := if rewound.2 then disconnectExcludedTips ctx (rewound.1.active.length + 1) rewound.1
    else (rewound.1, false)
  have hx : ChainExecution allowed s excluded.1 := by
    dsimp only [excluded]
    split
    · exact execution_trans hd (disconnectExcludedTips_execution allowed ctx hs hf _ _)
    · exact hd
  change ChainExecution allowed s (if !excluded.2 then
    ({ excluded.1 with
        mempool := removeFromMempoolForReorg excluded.1.mempool excluded.1.disconnectPool
          excluded.1.view.coins ctx.cfg (admissionContext excluded.1 ctx)
        disconnectPool := {}, reorgPending := false }, ActivationStatus.disconnectFailed)
    else activateBestChain (restoreCandidates (settleReorg { excluded.1 with reorgPending := true }
      ctx lists oracle)) ctx lists oracle fuel).1
  split
  · exact hx
  · apply execution_trans hx
    apply execution_trans (execution_quiet allowed excluded.1
      { excluded.1 with reorgPending := true } rfl rfl rfl)
    apply execution_trans (settleReorg_execution allowed
      { excluded.1 with reorgPending := true } ctx lists oracle false)
    exact execution_trans (restoreCandidates_execution allowed _)
      (activateBestChain_execution allowed ctx lists oracle hr hs hf fuel _)

/-- Soft-rejection metadata preserves bodies/work before its automatic trace.
[SRC] src/validation.cpp:5203–5225 and src/rpc/blockchain.cpp:2820–2892 at 6504a3af. -/
theorem setSoftRejection_execution (s : ChainState) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (hash : BitVec 256) (duration : Int) (fuel : Nat) :
    ChainExecution AutomaticCause s (setSoftRejection s ctx lists oracle hash duration fuel).1 := by
  unfold setSoftRejection
  apply execution_trans _ (activateBestChain_execution AutomaticCause ctx lists oracle
    (by simp [AutomaticCause]) (by simp [AutomaticCause]) (by simp [AutomaticCause]) fuel _)
  apply execution_trans _ (restoreCandidates_execution AutomaticCause _)
  apply execution_quiet <;> try rfl
  rw [propagateSoftSettings_core]
  exact modify_core _ _ _ (fun _ => rfl)

/-- Freeze metadata preserves bodies/work before its distinct automatic trace.
[SRC] src/validation.cpp:4526–4553 and src/block_index.h:542–580 at 6504a3af. -/
theorem setSoftFreeze_execution (s : ChainState) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (hash : BitVec 256) (duration : Int) (fuel : Nat) :
    ChainExecution AutomaticCause s (setSoftFreeze s ctx lists oracle hash duration fuel).1 := by
  unfold setSoftFreeze
  apply execution_trans _ (activateBestChain_execution AutomaticCause ctx lists oracle
    (by simp [AutomaticCause]) (by simp [AutomaticCause]) (by simp [AutomaticCause]) fuel _)
  apply execution_trans _ (restoreCandidates_execution AutomaticCause _)
  apply execution_quiet <;> try rfl
  rw [propagateSoftSettings_core]
  exact modify_core _ _ _ (fun _ => rfl)

/-- Equal index projections give equal lookup projections, including bodies and
work. This does not assume unique hashes or hash injectivity.
[SRC] src/validation.cpp:4345–4404,4498–4523 at 6504a3af. -/
theorem treeCore_lookup (a b : HeaderTree) (h : treeCore a = treeCore b) (hash : BitVec 256) :
    (a.get hash).map indexCore = (b.get hash).map indexCore := by
  have he := congrArg (List.find? (fun core => core.1.hash == hash)) h
  simpa only [treeCore, List.find?_map, Function.comp_def, indexCore, HeaderTree.get, BlockIndex.id] using he

/-- Retained bodies are identical at every hash across an executed transition.
[SRC] src/validation.cpp:4065–4133,4345–4404,5230–5330 at 6504a3af. -/
theorem execution_bodies {allowed : DisconnectCause → Prop} {s t : ChainState}
    (h : ChainExecution allowed s t) (hash : BitVec 256) :
    (t.tree.get hash).bind (·.body) = (s.tree.get hash).bind (·.body) := by
  have he := congrArg (fun x => x.bind (fun core => core.2.2.2)) (treeCore_lookup _ _ h.1 hash)
  simpa only [Option.bind_map, Function.comp_def, indexCore] using he

/-- Body preservation transports membership at any fixed active projection.
[SRC] src/validation.cpp:4117,4391 at 6504a3af. -/
theorem execution_membership {allowed : DisconnectCause → Prop} {s t : ChainState}
    (h : ChainExecution allowed s t) (active : List (BitVec 256)) (tx : Tx) :
    ActiveTransaction t.tree active tx ↔ ActiveTransaction s.tree active tx := by
  unfold ActiveTransaction
  simp only [execution_bodies h]

/-- A loss along a finite actual trace identifies a earlier and the disconnect
that removes membership at that step, before any later reconnect.
[SRC] src/validation.cpp:4117,4391,4603–4767 at 6504a3af. -/
theorem trace_transaction_removal (tree : HeaderTree) (active : List (BitVec 256))
    (trace : List ChainEvent) (tx : Tx) (hb : ActiveTransaction tree active tx)
    (ha : ¬ ActiveTransaction tree (trace.foldl applyChainEvent active) tx) :
    ∃ earlier suffix cause hash, trace = earlier ++ .disconnected cause hash :: suffix ∧
      ActiveTransaction tree (earlier.foldl applyChainEvent active) tx ∧
      ¬ ActiveTransaction tree (applyChainEvent (earlier.foldl applyChainEvent active) (.disconnected cause hash)) tx := by
  classical
  induction trace generalizing active with
  | nil => exact False.elim (ha hb)
  | cons event rest ih =>
    by_cases hm : ActiveTransaction tree (applyChainEvent active event) tx
    · obtain ⟨earlier, suffix, cause, hash, he, hp, hn⟩ := ih _ hm ha
      exact ⟨event :: earlier, suffix, cause, hash, by simp [he], hp, hn⟩
    · obtain ⟨cause, hash, rfl⟩ := transaction_removal_requires_disconnect tree active tx event hb hm
      exact ⟨[], rest, cause, hash, rfl, hb, hm⟩

/-- A removal witness is on the appended executed trace, with its caller's
cause and the membership immediately before/after the removing event. All
retained bodies are preserved despite metadata changes.
[SRC] src/validation.cpp:4117,4391,4526–4553,5203–5330 at 6504a3af. -/
def TransactionRemoval (allowed : DisconnectCause → Prop) (s t : ChainState) (tx : Tx) : Prop :=
  (∀ hash, (t.tree.get hash).bind (·.body) = (s.tree.get hash).bind (·.body)) ∧
  ∃ earlier suffix cause hash,
    t.events = s.events ++ (earlier ++ .disconnected cause hash :: suffix) ∧ allowed cause ∧
    ActiveTransaction s.tree (earlier.foldl applyChainEvent s.active) tx ∧
    ¬ ActiveTransaction s.tree (applyChainEvent (earlier.foldl applyChainEvent s.active) (.disconnected cause hash)) tx

/-- The executor trace and preserved bodies yield a concrete removing step.
[SRC] src/validation.cpp:4117,4391,4526–4553,4603–4767,5203–5330 at 6504a3af. -/
theorem execution_removal {allowed : DisconnectCause → Prop} {s t : ChainState}
    (h : ChainExecution allowed s t) (tx : Tx) (hb : ActiveTransaction s.tree s.active tx)
    (ha : ¬ ActiveTransaction t.tree t.active tx) : TransactionRemoval allowed s t tx := by
  have bodies := execution_bodies h
  have ha' : ¬ ActiveTransaction s.tree t.active tx := fun hm => ha ((execution_membership h _ _).mpr hm)
  obtain ⟨_, trace, he, ht, hc⟩ := h
  rw [ht] at ha'
  obtain ⟨earlier, suffix, cause, hash, htrace, hp, hn⟩ := trace_transaction_removal s.tree s.active trace tx hb ha'
  refine ⟨bodies, earlier, suffix, cause, hash, ?_, ?_, hp, hn⟩
  · exact he.trans (congrArg (s.events ++ ·) htrace)
  · apply hc cause hash
    simp [htrace]

/-- Successful connectTip preserves active transaction membership, including
old bodies while undo/completion metadata changes.
[SRC] src/validation.cpp:4345–4404 at 6504a3af. -/
theorem connectTip_preserves_transaction (s t : ChainState) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (i target : BlockIndex) (tx : Tx)
    (h : connectTip s ctx lists oracle i target = .ok t)
    (hb : ActiveTransaction s.tree s.active tx) : ActiveTransaction t.tree t.active tx := by
  classical
  by_contra ha
  obtain ⟨_, _, _, _, _, _, impossible, _⟩ := execution_removal
    (connectTip_execution (fun _ => False) s t ctx lists oracle i target h) tx hb ha
  exact impossible

/-- Explicit disconnectTip loss is assigned precisely its supplied cause.
[SRC] src/validation.cpp:4065–4133 at 6504a3af. -/
theorem disconnectTip_removal (s t : ChainState) (ctx : ChainContext) (cause : DisconnectCause)
    (result : DisconnectResult) (tx : Tx) (h : disconnectTip s ctx cause = (t, result))
    (hb : ActiveTransaction s.tree s.active tx) (ha : ¬ ActiveTransaction t.tree t.active tx) :
    TransactionRemoval (· = cause) s t tx := by
  have he := disconnectTip_execution (· = cause) s ctx cause rfl
  rw [h] at he
  exact execution_removal he tx hb ha

/-- Public automatic activation loss names its actual reorg/setting event.
[SRC] src/validation.cpp:4526–4800,4913–5130 at 6504a3af. -/
theorem activateBestChain_removal (s t : ChainState) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (fuel : Nat) (status : ActivationStatus) (tx : Tx)
    (h : activateBestChain s ctx lists oracle fuel = (t, status))
    (hb : ActiveTransaction s.tree s.active tx) (ha : ¬ ActiveTransaction t.tree t.active tx) :
    TransactionRemoval AutomaticCause s t tx := by
  have he := activateBestChain_execution AutomaticCause ctx lists oracle
    (by simp [AutomaticCause]) (by simp [AutomaticCause]) (by simp [AutomaticCause]) fuel s
  rw [h] at he
  exact execution_removal he tx hb ha

/-- Invalidation has its own executed removal law, including reactivation's
separate automatic causes. [SRC] src/validation.cpp:5230–5330 at 6504a3af. -/
theorem invalidateBlock_removal (s t : ChainState) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (hash : BitVec 256) (fuel : Nat) (status : ActivationStatus) (tx : Tx)
    (h : invalidateBlock s ctx lists oracle hash fuel = (t, status))
    (hb : ActiveTransaction s.tree s.active tx) (ha : ¬ ActiveTransaction t.tree t.active tx) :
    TransactionRemoval (fun c => c = .invalidate ∨ AutomaticCause c) s t tx := by
  have he := invalidateBlock_execution (fun c => c = .invalidate ∨ AutomaticCause c)
    s ctx lists oracle hash fuel (by simp) (by simp [AutomaticCause])
    (by simp [AutomaticCause]) (by simp [AutomaticCause])
  rw [h] at he
  exact execution_removal he tx hb ha

/-- A soft-rejection change loses inclusion only on its executed disconnect
trace, preserving bodies across setting propagation and reactivation.
[SRC] src/validation.cpp:5203–5225 and src/rpc/blockchain.cpp:2820–2892 at 6504a3af. -/
theorem setSoftRejection_removal (s t : ChainState) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (hash : BitVec 256) (duration : Int) (fuel : Nat) (status : ActivationStatus) (tx : Tx)
    (h : setSoftRejection s ctx lists oracle hash duration fuel = (t, status))
    (hb : ActiveTransaction s.tree s.active tx) (ha : ¬ ActiveTransaction t.tree t.active tx) :
    TransactionRemoval AutomaticCause s t tx := by
  have he := setSoftRejection_execution s ctx lists oracle hash duration fuel
  rw [h] at he
  exact execution_removal he tx hb ha

/-- A freeze change has a separate executed removal law with retained bodies
and the cause at the actual removing step.
[SRC] src/validation.cpp:4526–4553 and src/block_index.h:542–580 at 6504a3af. -/
theorem setSoftFreeze_removal (s t : ChainState) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (hash : BitVec 256) (duration : Int) (fuel : Nat) (status : ActivationStatus) (tx : Tx)
    (h : setSoftFreeze s ctx lists oracle hash duration fuel = (t, status))
    (hb : ActiveTransaction s.tree s.active tx) (ha : ¬ ActiveTransaction t.tree t.active tx) :
    TransactionRemoval AutomaticCause s t tx := by
  have he := setSoftFreeze_execution s ctx lists oracle hash duration fuel
  rw [h] at he
  exact execution_removal he tx hb ha

/-- Unchanged effective soft eligibility settings across the execution. The
public transition has one fixed ChainContext, so its configuration cannot
change during that call. [SRC] src/validation.cpp:4426–4431,4526–4553 at 6504a3af. -/
def EligibilitySettingsUnchanged (s t : ChainState) : Prop :=
  ∀ hash, (s.tree.get hash).map (fun i => (i.softRejected, i.softFrozen)) =
    (t.tree.get hash).map (fun i => (i.softRejected, i.softFrozen))

/-- Public completion verifies work coverage even for pruned retained indices.
[SRC] src/validation.cpp:4498–4523,4755–4767,4913–5130 at 6504a3af. -/
theorem activateBestChain_work_complete (s : ChainState) (ctx : ChainContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (fuel : Nat) (out : ChainState)
    (h : activateBestChain s ctx lists oracle fuel = (out, .complete)) :
    activationWorkComplete out = true := by
  unfold activateBestChain at h
  generalize he : activateLoop ctx lists oracle fuel s = result at h
  rcases result with ⟨final, status⟩
  cases status <;> simp_all
  exact h.1 ▸ h.2.2

/-- Before/after nondecrease for public completed activation: the old active
index is initially eligible, stays available, and its eligibility settings do
not change. The executed trace proves retained work; the work certificate
covers the old tip even after candidate pruning. No final candidate-list
membership of the old index is assumed.
[SRC] src/validation.cpp:4413–4523,4755–4767,4913–5130 at 6504a3af. -/
theorem activation_work_nondecreasing (before out : ChainState) (ctx : ChainContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (fuel : Nat) (old : BlockIndex)
    (tipBefore : before.active.getLast? = some old.id)
    (indexBefore : before.tree.get old.id = some old)
    (eligibleBefore : candidateEligible before old = true)
    (settings : EligibilitySettingsUnchanged before out)
    (remains : ∃ current, out.tree.get old.id = some current ∧ candidateAvailable out current = true)
    (h : activateBestChain before ctx lists oracle fuel = (out, .complete)) :
    activeWork before ≤ activeWork out := by
  obtain ⟨current, hcurrent, available⟩ := remains
  have execution := activateBestChain_execution AutomaticCause ctx lists oracle
    (by simp [AutomaticCause]) (by simp [AutomaticCause]) (by simp [AutomaticCause]) fuel before
  rw [h] at execution
  have core := treeCore_lookup _ _ execution.1 old.id
  simp only [hcurrent, indexBefore, Option.map_some, Option.some.injEq] at core
  have work : current.work = old.work := congrArg (fun x => x.2.1) core
  have unchanged := settings old.id
  simp only [indexBefore, hcurrent, Option.map_some, Option.some.injEq, Prod.mk.injEq] at unchanged
  have eligible : candidateEligible out current = true := by
    simp only [candidateEligible, Bool.and_eq_true] at eligibleBefore ⊢
    exact ⟨⟨unchanged.1 ▸ eligibleBefore.1.1, unchanged.2 ▸ eligibleBefore.1.2⟩, available⟩
  have coverage := activateBestChain_work_complete before ctx lists oracle fuel out h
  have bound := (List.all_eq_true.mp coverage) current (List.mem_of_find?_eq_some hcurrent)
  simp only [eligible, Bool.not_true, Bool.or_false, decide_eq_true_eq] at bound
  simpa only [activeWork, tipBefore, Option.bind_some, indexBefore, Option.map_some, Option.getD_some, work] using bound

/-- Strict growth is the same public transition law with unequal selected
work; equal-work completion/sequence/rank changes do not satisfy that premise.
[SRC] src/block_index.h:1225–1274 and src/validation.cpp:4755–4767 at 6504a3af. -/
theorem activation_work_strict_growth (before out : ChainState) (ctx : ChainContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (fuel : Nat) (old : BlockIndex)
    (tipBefore : before.active.getLast? = some old.id)
    (indexBefore : before.tree.get old.id = some old)
    (eligibleBefore : candidateEligible before old = true)
    (settings : EligibilitySettingsUnchanged before out)
    (remains : ∃ current, out.tree.get old.id = some current ∧ candidateAvailable out current = true)
    (h : activateBestChain before ctx lists oracle fuel = (out, .complete))
    (different : activeWork before ≠ activeWork out) : activeWork before < activeWork out := by
  have bound := activation_work_nondecreasing before out ctx lists oracle fuel old
    tipBefore indexBefore eligibleBefore settings remains h
  omega

end BsvChain.Properties
