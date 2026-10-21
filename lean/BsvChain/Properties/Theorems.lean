import BsvChain.Properties.Merkle
import BsvChain.Properties.Block

/-!
# The five theorems of S6 (#68)

[M] 2026-10-13 (#68). DESIGN-S6 §4.4 names five statements; each is
proved here in its true form over the executable transitions, quantified over
the chain parameters, the node configuration, the script oracle and the
explicit time. Where the charter's sentence is false in the machine, the
explainer says what it said and why the machine says otherwise.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/coins.cpp:560-565, src/undo.h:109-112, src/processing_block_index.cpp:50-96,
src/validation.cpp:2483-2494,3326-3373,3436-3443,3655-3668,4413-4494,5234-5256,
src/consensus/merkle.cpp:291-310.
-/

namespace BsvChain.Properties
open BsvScript.Tx BsvScript.TxRules

/-! ## Loop and preparation lemmas -/

/-- [D] 2026-10-13: an accepted loop in the error monad ran every element's
body successfully at some carried state, when no body stops early. This is the
shape of the block checks' `for` loops.
[SRC] src/validation.cpp:3061-3117,5853-5889 at 6504a3af. -/
theorem forIn_except_each {α β ε : Type} (l : List α) (f : α → β → Except ε (ForInStep β))
    (yields : ∀ x b r, f x b = .ok r → ∃ b', r = .yield b') :
    ∀ (init res : β), forIn l init f = .ok res → ∀ x ∈ l, ∃ b r, f x b = .ok r := by
  induction l with
  | nil => intro _ _ _ x hx; simp at hx
  | cons y ys ih =>
    intro init res h x hx
    simp only [List.forIn_cons, bind, Except.bind] at h
    cases hy : f y init with
    | error e => simp [hy] at h
    | ok r =>
      obtain ⟨b', rfl⟩ := yields y init r hy
      simp only [hy] at h
      rcases List.mem_cons.mp hx with rfl | hx
      · exact ⟨init, _, hy⟩
      · exact ih b' res h x hx

/-- [D] 2026-10-13: a bind in the error monad succeeds exactly when both of
its stages do. A proof device for reading the ordered checks.
[SRC] src/validation.cpp:5749-5901 at 6504a3af. -/
theorem except_bind_ok {ε α β : Type} (x : Except ε α) (f : α → Except ε β) (b : β) :
    (x >>= f) = .ok b ↔ ∃ a, x = .ok a ∧ f a = .ok b := by
  cases x <;> simp [bind, Except.bind]

/-- [D] 2026-10-13: a throw followed by anything never succeeds.
[SRC] src/validation.cpp:5749-5901 at 6504a3af. -/
theorem except_throw_bind_ok {ε α β : Type} (e : ε) (f : α → Except ε β) (b : β) :
    ((throw e : Except ε α) >>= f) = .ok b ↔ False := by
  simp [throw, throwThe, MonadExceptOf.throw, bind, Except.bind]

/-- [D] 2026-10-13: a bare throw never succeeds.
[SRC] src/validation.cpp:5749-5901 at 6504a3af. -/
theorem except_throw_ok {ε α : Type} (e : ε) (a : α) :
    (throw e : Except ε α) = .ok a ↔ False := by
  simp [throw, throwThe, MonadExceptOf.throw]

/-- [D] 2026-10-13: an accepted coinbase check names a coinbase.
[SRC] src/validation.cpp:5823-5827 at 6504a3af. -/
theorem blockTxCheck_coinbase (tx : Tx) (a b : Nat) (c : Bool) (u : Unit)
    (h : blockTxCheck (checkCoinbase tx a b c) = .ok u) : isCoinBase tx = true := by
  unfold blockTxCheck checkCoinbase at h
  cases hc : isCoinBase tx
  · simp [hc, Except.mapError, throw, throwThe, MonadExceptOf.throw, bind, Except.bind] at h
  · rfl

/-- [D] 2026-10-13: an accepted regular check names a non-coinbase.
[SRC] src/validation.cpp:5877-5889 at 6504a3af. -/
theorem blockTxCheck_regular (tx : Tx) (a b : Nat) (c : Bool) (u : Unit)
    (h : blockTxCheck (checkRegularTransaction tx a b c) = .ok u) : isCoinBase tx = false := by
  unfold blockTxCheck checkRegularTransaction at h
  cases hc : isCoinBase tx
  · rfl
  · simp [hc, Except.mapError, throw, throwThe, MonadExceptOf.throw, bind, Except.bind] at h

/-- [D] 2026-10-13: an accepted block check leaves a body whose leading
transaction is a coinbase and whose later transactions are not: CheckCoinbase
on the leading one, CheckRegularTransaction (bad-tx-coinbase) on every later one.
[SRC] src/validation.cpp:5788-5791,5823-5827,5877-5889 at 6504a3af. -/
theorem checkBlock_coinbase (params : ChainParams) (cfg : NodeConfig) (block : Block)
    (height : Nat) (options : BlockCheckOptions)
    (h : checkBlock params cfg block height options = .ok ()) :
    ∃ cb rest, block.transactions = cb :: rest ∧ isCoinBase cb = true ∧
      ∀ tx ∈ rest, isCoinBase tx = false := by
  unfold checkBlock at h
  generalize hm : (blockMerkleRoot block.transactions) = m at h
  cases ht : block.transactions with
  | nil =>
    exfalso
    simp only [ht] at h
    cases h1 : options.merkleRoot <;>
      cases h2 : (headerWordBytes 32 block.header.merkleRoot.toNat != m.root) <;>
      cases h3 : m.mutated <;>
      simp [h1, h2, h3, except_bind_ok, except_throw_bind_ok, pure, Except.pure] at h
  | cons cb rest =>
    simp only [ht] at h
    cases h1 : options.merkleRoot <;>
      cases h2 : (headerWordBytes 32 block.header.merkleRoot.toNat != m.root) <;>
      cases h3 : m.mutated <;>
      simp only [h1, h2, h3, except_bind_ok, except_throw_bind_ok, Bool.false_eq_true, ite_false, ite_true,
        false_and, exists_false, and_false, pure, Except.pure, Except.ok.injEq, exists_eq_left',
        except_throw_ok] at h
    any_goals (rcases h with ⟨_, _, h⟩)
    all_goals
      split at h
      · simp only [except_throw_bind_ok] at h
      split at h
      · simp only [except_throw_bind_ok] at h
      simp only [except_bind_ok] at h
      obtain ⟨_, hcb, r, hloop, _⟩ := h
      refine ⟨cb, rest, rfl, blockTxCheck_coinbase _ _ _ _ _ hcb, ?_⟩
      intro tx htx
      obtain ⟨index, hidx⟩ : ∃ index, (tx, index + 1) ∈ (cb :: rest).zipIdx := by
        obtain ⟨i, hi, he⟩ := List.getElem_of_mem htx
        refine ⟨i, List.mem_iff_getElem.mpr ⟨i + 1, by simpa using hi, ?_⟩⟩
        simp [he, Nat.add_comm]
      obtain ⟨b, r', hstep⟩ := forIn_except_each _ _ (by
        intro x b r hr
        repeat' (first | split at hr | simp only [except_bind_ok, except_throw_bind_ok, except_throw_ok,
          pure, Except.pure, Except.ok.injEq, false_and, and_false, exists_false] at hr)
        all_goals first | exact ⟨_, hr.symm⟩ | (obtain ⟨_, _, hr⟩ := hr; exact ⟨_, hr.symm⟩)) 0 r hloop _ hidx
      simp only [Nat.lt_add_left_iff_pos, Nat.zero_lt_succ, ite_true, gt_iff_lt] at hstep
      obtain ⟨_, hreg, _⟩ := (except_bind_ok _ _ _).mp hstep
      exact blockTxCheck_regular _ _ _ _ _ hreg

/-- [D] 2026-10-13: a prepared non-genesis connection ran the block check at
the parent's successor height, carries the given parameters and that height,
and, where BIP30 is enforced, found no live coin at any output of the body.
[SRC] src/validation.cpp:3021-3117,3467-3472 at 6504a3af. -/
theorem prepare_some (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int) (checks : ConnectionChecks)
    (ctx : UtxoContext)
    (h : prepareBlockConnection view params cfg block previous now checks = .ok (some ctx)) :
    checkBlock params cfg block ((previous.map (·.height + 1)).getD 0) = .ok () ∧
      ctx.params = params ∧ ctx.height = (previous.map (·.height + 1)).getD 0 ∧
      (checks.bip30Required = true → ∀ tx ∈ block.transactions, ∀ output index,
        (output, index) ∈ tx.outputs.zipIdx →
          getCoin view.coins ⟨BsvScript.Sighash.txid tx, index⟩ = none) := by
  unfold prepareBlockConnection at h
  simp only [except_bind_ok] at h
  obtain ⟨u, hcheck, h⟩ := h
  cases u
  refine ⟨hcheck, ?_⟩
  cases h1 : (block.header.prevBlock != view.bestBlock) <;>
    cases h2 : (block.header.hash.toNat == params.hashGenesisBlock) <;>
    simp only [h1, h2, except_bind_ok, except_throw_bind_ok, except_throw_ok, Bool.false_eq_true, ite_false,
      ite_true, pure, Except.pure, Except.ok.injEq, reduceCtorEq, false_and, exists_false] at h
  cases hc : contextualCheckBlock params cfg block previous with
  | none => simp [hc, except_throw_bind_ok, except_throw_ok] at h
  | some contextual =>
    simp only [hc, except_bind_ok] at h
    obtain ⟨_, _, h⟩ := h
    have finish : ∀ flags, ordinaryScriptFlags cfg params ((previous.map (·.height + 1)).getD 0) true = some flags →
        (Except.ok (some (UtxoContext.mk params ((previous.map (·.height + 1)).getD 0)
          ((previous.map (·.height + 1)).getD 0 - 1) flags true true now)) : Except BlockReject _) = .ok (some ctx) →
        ctx.params = params ∧ ctx.height = (previous.map (·.height + 1)).getD 0 := by
      intro flags _ he
      simp only [Except.ok.injEq, Option.some.injEq] at he
      subst ctx
      exact ⟨rfl, rfl⟩
    cases hb : checks.bip30Required
    · simp only [hb, Bool.false_eq_true, ite_false] at h
      cases hf : ordinaryScriptFlags cfg params ((previous.map (·.height + 1)).getD 0) true with
      | none => simp [hf, except_throw_ok] at h
      | some flags =>
        simp only [hf] at h
        exact ⟨(finish flags hf h).1, (finish flags hf h).2, by simp⟩
    · simp only [hb, ite_true, except_bind_ok] at h
      obtain ⟨_, hloop, h⟩ := h
      cases hf : ordinaryScriptFlags cfg params ((previous.map (·.height + 1)).getD 0) true with
      | none => simp [hf, except_throw_ok] at h
      | some flags =>
        simp only [hf] at h
        refine ⟨(finish flags hf h).1, (finish flags hf h).2, fun _ tx htx output index hidx => ?_⟩
        obtain ⟨_, _, hbody⟩ := forIn_except_each _ _ (by
          intro x b r hr
          simp only [except_bind_ok] at hr
          obtain ⟨_, _, hr⟩ := hr
          exact ⟨_, (Except.ok.inj hr).symm⟩) _ _ hloop tx htx
        simp only [except_bind_ok] at hbody
        obtain ⟨_, hinner, _⟩ := hbody
        obtain ⟨_, _, hcell⟩ := forIn_except_each _ _ (by
          intro x b r hr
          split at hr
          · simp [except_throw_bind_ok] at hr
          · exact ⟨_, (Except.ok.inj hr).symm⟩) _ _ hinner _ hidx
        split at hcell
        · simp [except_throw_bind_ok] at hcell
        · simpa using (by assumption : ¬ (getCoin view.coins ⟨BsvScript.Sighash.txid tx, index⟩).isSome = true)

/-- [D] 2026-10-13: an accepted connection either prepared a context or is
the genesis block, whose connection publishes only the best pointer.
[SRC] src/validation.cpp:3021-3050 at 6504a3af. -/
theorem prepare_none_genesis (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int) (checks : ConnectionChecks)
    (h : prepareBlockConnection view params cfg block previous now checks = .ok none) :
    block.header.hash.toNat = params.hashGenesisBlock := by
  unfold prepareBlockConnection at h
  simp only [except_bind_ok] at h
  obtain ⟨_, _, h⟩ := h
  cases h1 : (block.header.prevBlock != view.bestBlock) <;>
    cases h2 : (block.header.hash.toNat == params.hashGenesisBlock) <;>
    simp only [h1, h2, except_bind_ok, except_throw_bind_ok, except_throw_ok, Bool.false_eq_true, ite_false,
      ite_true, pure, Except.pure, Except.ok.injEq, reduceCtorEq, false_and, exists_false] at h
  · cases hc : contextualCheckBlock params cfg block previous with
    | none => simp [hc, except_throw_bind_ok, except_throw_ok] at h
    | some contextual =>
      simp only [hc, except_bind_ok] at h
      obtain ⟨_, _, h⟩ := h
      cases hb : checks.bip30Required <;>
        cases hf : ordinaryScriptFlags cfg params ((previous.map (·.height + 1)).getD 0) true <;>
        simp [hb, hf, except_bind_ok, except_throw_ok] at h
  · simpa using h2

/-- [D] 2026-10-13: a successful non-genesis connection exposes its prepared
context, the coinbase reward stage and the executed run.
[SRC] src/validation.cpp:3021-3050,3290-3719 at 6504a3af. -/
theorem connectBlock_parts (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int) (lists : FrozenLists)
    (oracle : ScriptOracle) (checks : ConnectionChecks) (out : ConnectedBlock)
    (hc : connectBlock view params cfg block previous now lists oracle checks = .ok out)
    (nonGenesis : block.header.hash.toNat ≠ params.hashGenesisBlock) :
    ∃ ctx cb, prepareBlockConnection view params cfg block previous now checks = .ok (some ctx) ∧
      block.transactions.head? = some cb ∧
      checkCoinbaseAmount params ctx.height cb out.run.fees = .ok () := by
  unfold connectBlock at hc
  simp only [except_bind_ok] at hc
  obtain ⟨context, hp, hc⟩ := hc
  cases context with
  | none => exact absurd (prepare_none_genesis view params cfg block previous now checks hp) nonGenesis
  | some ctx =>
    refine ⟨ctx, ?_⟩
    simp only [Except.mapError, except_bind_ok] at hc
    obtain ⟨run, hrun, hc⟩ := hc
    cases hr : runBlockTransactions cfg ctx lists oracle previous checks
        ((1 + (List.length block.encode - 1) / BsvScript.TxRules.MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS) *
          cfg.maxBlockSigOpsPerMbBeforeGenesis) block.transactions view.coins 0 with
    | error e => simp [hr] at hrun
    | ok run' =>
      simp only [hr, Except.ok.injEq] at hrun
      subst run'
      cases hb : block.transactions.head? with
      | none => simp [hb, except_throw_ok] at hc
      | some cb =>
        simp only [hb, except_bind_ok] at hc
        cases ha : checkCoinbaseAmount params ctx.height cb run.fees with
        | error e => simp [ha] at hc
        | ok u =>
          cases u
          simp only [ha] at hc
          cases hs : finishBlockScripts oracle run.calls with
          | error e => simp [hs] at hc
          | ok u =>
            simp only [hs, pure, Except.pure, Except.ok.injEq] at hc
            obtain ⟨_, _, _, _, hc⟩ := hc
            subst out
            exact ⟨cb, hp, rfl, ha⟩

/-! ## Well-formed coin views -/

/-- [D] 2026-10-13: a coin view is well formed when every stored entry is a
live coin (not the spent sentinel) whose script AddCoin would have stored at
its own creation height. Every view the connection step builds from such a
view keeps this shape (`updateCoins_wellFormed`).
[SRC] src/coins.h:235, src/coins.cpp:45-64,548-565 at 6504a3af. -/
def WellFormedCoins (params : ChainParams) (s : UtxoSet) : Prop :=
  ∀ p coin, s.lookup p = some coin → coin.isSpent = false ∧
    isUnspendable (decide (params.genesisHeight ≤ coin.height)) coin.script = false

/-- [D] 2026-10-13: a stored pair of the executable map is one of its pairs.
[SRC] src/coins.cpp:548-565 at 6504a3af. -/
theorem lookup_coinMap_mem (pairs : List (OutPoint × Coin)) (p : OutPoint) (coin : Coin)
    (h : (coinMap pairs).lookup p = some coin) : (p, coin) ∈ pairs := by
  induction pairs with
  | nil => simp [coinMap] at h
  | cons pair rest ih =>
    rcases pair with ⟨q, c⟩
    by_cases hp : p = q
    · subst q
      simp only [coinMap, Finmap.lookup_insert, Option.some.injEq] at h
      subst h
      exact List.mem_cons_self ..
    · simp only [coinMap, Finmap.lookup_insert_of_ne _ hp] at h
      exact List.mem_cons_of_mem _ (ih h)

/-- [D] 2026-10-13: every created coin is live and stored by AddCoin's rule.
[SRC] src/coins.cpp:45-64,548-565 at 6504a3af. -/
theorem createdOutputs_wellFormed (params : ChainParams) (height : Nat) (tx : Tx)
    (p : OutPoint) (coin : Coin) (h : (p, coin) ∈ createdOutputs params height tx) :
    coin.isSpent = false ∧
      isUnspendable (decide (params.genesisHeight ≤ coin.height)) coin.script = false := by
  obtain ⟨output, index, _, hu, _, rfl⟩ := (createdOutputs_membership params height tx p coin).mp h
  refine ⟨?_, hu⟩
  simp only [Coin.isSpent, beq_eq_false_iff_ne, ne_eq]
  omega

/-- [D] 2026-10-13: the pure update keeps a well-formed view well formed.
[SRC] src/validation.cpp:2480-2495 and src/coins.cpp:548-565 at 6504a3af. -/
theorem updateCoins_wellFormed (s : UtxoSet) (params : ChainParams) (height : Nat) (tx : Tx)
    (wf : WellFormedCoins params s) : WellFormedCoins params (updateCoins s params height tx).1 := by
  intro p coin h
  simp only [updateCoins] at h
  by_cases hm : p ∈ coinMap (createdOutputs params height tx)
  · rw [Finmap.lookup_union_left hm] at h
    exact createdOutputs_wellFormed params height tx p coin (lookup_coinMap_mem _ p coin h)
  · rw [Finmap.lookup_union_right hm, lookup_eraseKeys] at h
    split at h
    · cases h
    · exact wf p coin h

/-- [D] 2026-10-13: erasing keys keeps a view well formed.
[SRC] src/validation.cpp:2483-2491 at 6504a3af. -/
theorem eraseKeys_wellFormed (s : UtxoSet) (params : ChainParams) (keys : List OutPoint)
    (wf : WellFormedCoins params s) : WellFormedCoins params (eraseKeys s keys) := by
  intro p coin h
  rw [lookup_eraseKeys] at h
  split at h
  · cases h
  · exact wf p coin h

/-- [D] 2026-10-13: in a well-formed view a stored key is a live coin.
[SRC] src/coins.h:235 and src/coins.cpp:116-128 at 6504a3af. -/
theorem wellFormed_mem_getCoin (params : ChainParams) (s : UtxoSet) (p : OutPoint)
    (wf : WellFormedCoins params s) (h : getCoin s p = none) : p ∉ s := by
  intro hm
  obtain ⟨coin, hc⟩ := Finmap.mem_iff.mp hm
  have live := (wf p coin hc).1
  simp [getCoin, hc, Option.filter, live] at h

/-- [D] 2026-10-13: along an executed run every view is well formed when the
starting view is. [SRC] src/validation.cpp:3290-3447 at 6504a3af. -/
theorem applications_wellFormed (cfg : NodeConfig) (ctx : UtxoContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (before after : UtxoSet) (apps : List BlockApplication)
    (hv : ApplicationsValid cfg ctx lists oracle before apps after)
    (wf : WellFormedCoins ctx.params before) :
    WellFormedCoins ctx.params after ∧ ∀ a ∈ apps, WellFormedCoins ctx.params a.before := by
  induction apps generalizing before with
  | nil => exact ⟨hv ▸ wf, by simp⟩
  | cons a rest ih =>
    rcases hv with ⟨hb, ha, ht⟩
    have next : WellFormedCoins ctx.params a.after := by
      have := congrArg Prod.fst (applyTx_success before cfg ctx lists oracle a.tx _ ha).2
      simp only at this
      rw [this]
      exact updateCoins_wellFormed before ctx.params ctx.height a.tx wf
    obtain ⟨hafter, hall⟩ := ih a.after ht next
    refine ⟨hafter, ?_⟩
    intro x hx
    rcases List.mem_cons.mp hx with rfl | hx
    · exact hb ▸ wf
    · exact hall x hx

/-- [D] 2026-10-13: every receipt of an executed run is an actual applyTx
success from its own preceding view.
[SRC] src/validation.cpp:3290-3447 at 6504a3af. -/
theorem applications_member (cfg : NodeConfig) (ctx : UtxoContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (before after : UtxoSet) (apps : List BlockApplication)
    (hv : ApplicationsValid cfg ctx lists oracle before apps after) (a : BlockApplication) (ha : a ∈ apps) :
    applyTx a.before cfg ctx lists oracle a.tx = .ok (a.after, a.undo) := by
  induction apps generalizing before with
  | nil => simp at ha
  | cons x rest ih =>
    rcases hv with ⟨hb, hx, ht⟩
    rcases List.mem_cons.mp ha with rfl | ha
    · exact hb ▸ hx
    · exact ih x.after ht ha

/-- [D] 2026-10-13: an accepted non-coinbase transaction creates no output
over a live entry left after its own spends: the pin's logic-error guard.
[SRC] src/coins.cpp:386-401,548-565 and src/validation.cpp:2480-2495 at 6504a3af. -/
theorem validateUtxoTx_fresh (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (tx : Tx)
    (hcb : isCoinBase tx = false) (h : validateUtxoTx s cfg ctx lists oracle tx = .ok ()) :
    ∀ p ∈ (createdOutputs ctx.params ctx.height tx).map Prod.fst,
      getCoin (eraseKeys s (spentOutpoints tx)) p = none := by
  unfold validateUtxoTx at h
  simp only [hcb, Bool.false_eq_true, ite_false, except_bind_ok] at h
  obtain ⟨_, _, h⟩ := h
  split at h
  · simp only [except_throw_bind_ok] at h
  simp only [except_bind_ok] at h
  obtain ⟨_, _, _, _, h⟩ := h
  split at h
  · simp only [except_throw_bind_ok] at h
  rename_i hany
  intro p hp
  obtain ⟨⟨q, coin⟩, hm, rfl⟩ := List.mem_map.mp hp
  simp only [Bool.not_eq_true, List.any_eq_false, Option.isSome_iff_ne_none, ne_eq,
    Decidable.not_not, Prod.forall] at hany
  exact hany q coin hm

/-- [D] 2026-10-13: the per-application no-overwrite premise of #64 holds for
every non-coinbase receipt of an executed run from a well-formed view (the
pin's guard), so only the coinbase case remains a premise.
[SRC] src/coins.cpp:560-565 and src/undo.h:109-112 at 6504a3af. -/
theorem noBlockOverwrite_of_run (cfg : NodeConfig) (ctx : UtxoContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (before after : UtxoSet) (apps : List BlockApplication)
    (hv : ApplicationsValid cfg ctx lists oracle before apps after)
    (wf : WellFormedCoins ctx.params before)
    (coinbaseFresh : ∀ a ∈ apps, isCoinBase a.tx = true →
      ∀ p ∈ (createdOutputs ctx.params ctx.height a.tx).map Prod.fst, getCoin a.before p = none) :
    NoBlockOverwrite ctx.params ctx.height apps := by
  intro a ha p hp
  have wfa := (applications_wellFormed cfg ctx lists oracle before after apps hv wf).2 a ha
  cases hcb : isCoinBase a.tx
  · have hval := (applyTx_success a.before cfg ctx lists oracle a.tx _
      (applications_member cfg ctx lists oracle before after apps hv a ha)).1
    exact wellFormed_mem_getCoin _ _ p (eraseKeys_wellFormed _ _ _ wfa)
      (validateUtxoTx_fresh _ _ _ _ _ _ hcb hval p hp)
  · have hs : spentOutpoints a.tx = [] := by simp [spentOutpoints, hcb]
    rw [hs]
    exact wellFormed_mem_getCoin _ _ p wfa (coinbaseFresh a ha hcb p hp)

/-! ## Fees -/

/-- [D] 2026-10-13: the fees of an executed run, each non-coinbase receipt's
input value in its own preceding view less its output value.
[SRC] src/validation.cpp:3371-3373 at 6504a3af. -/
def blockFees (apps : List BlockApplication) : Int :=
  (apps.map fun a => if isCoinBase a.tx then 0 else inputValue a.before a.tx - outputValue a.tx).sum

/-- [D] 2026-10-13: the run's fee tally is the sum of its receipts' fees.
[SRC] src/validation.cpp:3371-3373 at 6504a3af. -/
theorem runBlockTransactions_fees (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (previous : Option HeaderChain)
    (checks : ConnectionChecks) (cap : Nat) (txs : List Tx) (s : UtxoSet)
    (total : Nat) (run : BlockRun)
    (h : runBlockTransactions cfg ctx lists oracle previous checks cap txs s total = .ok run) :
    run.fees = blockFees run.applications := by
  induction txs generalizing s total run with
  | nil => simp [runBlockTransactions] at h; subst run; simp [blockFees]
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
          have ht := ih next count tail hr
          simp only [blockFees, List.map_cons, List.sum_cons] at ht ⊢
          rw [ht]

/-! ## The shape of a connected block -/

/-- [D] 2026-10-13: a successful non-genesis connection has its prepared
context at the parent's successor height, its body led by its only coinbase,
and an executed run whose receipts follow the body in order from the parent
view to the published view, with the retained undo vectors.
[SRC] src/validation.cpp:3021-3117,3290-3447,5823-5889 at 6504a3af. -/
theorem connected_shape (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int) (lists : FrozenLists)
    (oracle : ScriptOracle) (checks : ConnectionChecks) (out : ConnectedBlock)
    (hc : connectBlock view params cfg block previous now lists oracle checks = .ok out)
    (nonGenesis : block.header.hash.toNat ≠ params.hashGenesisBlock) :
    ∃ ctx cb rest, prepareBlockConnection view params cfg block previous now checks = .ok (some ctx) ∧
      ctx.params = params ∧ ctx.height = (previous.map (·.height + 1)).getD 0 ∧
      block.transactions = cb :: rest ∧ isCoinBase cb = true ∧ (∀ tx ∈ rest, isCoinBase tx = false) ∧
      checkCoinbaseAmount params ctx.height cb out.run.fees = .ok () ∧
      ApplicationsValid cfg ctx lists (if checks.checkScripts && !checks.queued then oracle else deferredBlockOracle)
        view.coins out.run.applications out.view.coins ∧
      out.run.applications.map (·.tx) = block.transactions ∧
      out.run.fees = blockFees out.run.applications ∧
      out.undo.transactions = (out.run.applications.drop 1).map (·.undo) := by
  obtain ⟨ctx, cb, hp, hhead, hamount⟩ := connectBlock_parts view params cfg block previous now lists oracle
    checks out hc nonGenesis
  obtain ⟨hcheck, hparams, hheight, _⟩ := prepare_some view params cfg block previous now checks ctx hp
  obtain ⟨cb', rest, htx, hcb, hrest⟩ := checkBlock_coinbase params cfg block _ {} hcheck
  rw [htx] at hhead
  simp only [List.head?_cons, Option.some.injEq] at hhead
  subst cb'
  obtain ⟨hr, hview, hundo⟩ := connectBlock_run view params cfg block previous now lists oracle checks ctx out hp hc
  obtain ⟨hv, horder⟩ := runBlockTransactions_valid cfg ctx lists oracle previous checks _ _ _ _ _ hr
  exact ⟨ctx, cb, rest, hp, hparams, hheight, htx, hcb, hrest, hamount, hview ▸ hv, horder,
    runBlockTransactions_fees cfg ctx lists oracle previous checks _ _ _ _ _ hr, hundo⟩

/-! ## Theorem 2: no inflation -/

/-- [M] 2026-10-13, #68 theorem 2 (no inflation). For every successful
connection of a non-genesis block, under any parameters, configuration,
operator lists, script oracle and time: the block's leading transaction is its
only coinbase; its outputs pay at most the subsidy at the block's height (the
parent's height plus one) plus the block's fees; the fees are the sum, over
the non-coinbase transactions in body order, of each one's input value in the
view immediately before it less its output value; and every non-coinbase
transaction conserves value, its inputs equal to its outputs plus a fee that
is not negative. Premises in plain words: the connection succeeded (`hc`), and
the block is not the network's genesis block (`nonGenesis`), whose connection
creates no coins. The fees are derived from the executed transactions, closing
what `coinbase_amount_bound` left to #64. Burned outputs count as outputs.
[SRC] src/validation.cpp:2252-2263,3371-3373,3655-3668,2639-2663 at 6504a3af. -/
theorem s6_no_inflation (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int) (lists : FrozenLists)
    (oracle : ScriptOracle) (checks : ConnectionChecks) (out : ConnectedBlock)
    (hc : connectBlock view params cfg block previous now lists oracle checks = .ok out)
    (nonGenesis : block.header.hash.toNat ≠ params.hashGenesisBlock) :
    ∃ cb rest, block.transactions = cb :: rest ∧ isCoinBase cb = true ∧
      (∀ tx ∈ rest, isCoinBase tx = false) ∧
      out.run.applications.map (·.tx) = block.transactions ∧
      outputValue cb ≤ blockFees out.run.applications +
        getBlockSubsidy params ((previous.map (·.height + 1)).getD 0) ∧
      ∀ a ∈ out.run.applications, isCoinBase a.tx = false →
        ∃ fee, 0 ≤ fee ∧ inputValue a.before a.tx = outputValue a.tx + fee := by
  obtain ⟨ctx, cb, rest, _, _, hheight, htx, hcb, hrest, hamount, hv, horder, hfees, _⟩ :=
    connected_shape view params cfg block previous now lists oracle checks out hc nonGenesis
  refine ⟨cb, rest, htx, hcb, hrest, horder, ?_, ?_⟩
  · have := coinbase_amount_bound params ctx.height cb out.run.fees hamount
    rw [hfees, hheight] at this
    exact this
  · intro a ha hacb
    obtain ⟨fee, _, hnn, hcons⟩ := applyTx_value_conservation a.before cfg ctx lists _ a.tx _ hacb
      (applications_member cfg ctx lists _ _ _ _ hv a ha)
    exact ⟨fee, hnn, hcons⟩

/-! ## Theorem 3: inputs unspent immediately before -/

/-- [D] 2026-10-13: receipts chain their views: the leading one starts at the given
view and each next one starts where the previous ended.
[SRC] src/validation.cpp:3290-3447 at 6504a3af. -/
theorem applications_chain (cfg : NodeConfig) (ctx : UtxoContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (before after : UtxoSet) (apps : List BlockApplication)
    (hv : ApplicationsValid cfg ctx lists oracle before apps after) :
    (∀ a, apps.head? = some a → a.before = before) ∧
      ∀ k (hk : k + 1 < apps.length), apps[k + 1].before = apps[k].after := by
  induction apps generalizing before with
  | nil => simp
  | cons a rest ih =>
    rcases hv with ⟨hb, _, ht⟩
    obtain ⟨hhead, hnext⟩ := ih a.after ht
    refine ⟨fun x hx => by simp at hx; exact hx ▸ hb, ?_⟩
    intro k hk
    cases k with
    | zero =>
      cases rest with
      | nil => simp at hk
      | cons b bs => exact hhead b rfl
    | succ k => exact hnext k (by simpa using hk)

/-- [M] 2026-10-13, #68 theorem 3 (every input unspent immediately before its
transaction). For every successful connection of a non-genesis block, under
any parameters, configuration, operator lists, script oracle and time, there
are receipts, one per body transaction in body order, such that: the opening
receipt's view is the parent's coin view; each next receipt's view is exactly
the view the previous transaction left, so an output created earlier in the
same block is available to a later one and an output spent earlier is not; the
last view is the published view; each receipt is an actual applyTx success;
and every input of every non-coinbase transaction names a live coin in the view
immediately before that transaction. The coinbase spends nothing; it follows
its structural and subsidy checks (theorem 2). Premises in plain words: the
connection succeeded and the block is not genesis. The receipts' script judge
is the deferred one when checks are queued; the queued checks are run with the
oracle before the block is published (`finishBlockScripts`).
[SRC] src/validation.cpp:2483-2494,3324-3331,3436-3443 at 6504a3af. -/
theorem s6_inputs_unspent (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int) (lists : FrozenLists)
    (oracle : ScriptOracle) (checks : ConnectionChecks) (out : ConnectedBlock)
    (hc : connectBlock view params cfg block previous now lists oracle checks = .ok out)
    (nonGenesis : block.header.hash.toNat ≠ params.hashGenesisBlock) :
    ∃ ctx judge, ApplicationsValid cfg ctx lists judge view.coins out.run.applications out.view.coins ∧
      out.run.applications.map (·.tx) = block.transactions ∧
      (∀ a, out.run.applications.head? = some a → a.before = view.coins) ∧
      (∀ k (hk : k + 1 < out.run.applications.length),
        out.run.applications[k + 1].before = out.run.applications[k].after) ∧
      ∀ a ∈ out.run.applications, isCoinBase a.tx = false →
        ∀ input ∈ a.tx.inputs, (getCoin a.before (.ofInput input)).isSome = true := by
  obtain ⟨ctx, _, _, _, _, _, _, _, _, _, hv, horder, _, _⟩ :=
    connected_shape view params cfg block previous now lists oracle checks out hc nonGenesis
  obtain ⟨hhead, hnext⟩ := applications_chain cfg ctx lists _ _ _ _ hv
  exact ⟨ctx, _, hv, horder, hhead, hnext,
    fun a ha hcb => applications_inputs_unspent cfg ctx lists _ _ _ _ hv a ha hcb⟩

/-! ## Theorem 1: undo restores the coin set -/

/-- [D] 2026-10-13: every retained spent coin is the view's own entry.
[SRC] src/validation.cpp:2483-2489 and src/undo.h:80-83 at 6504a3af. -/
theorem coinsAt_lookup (s : UtxoSet) (keys : List OutPoint) (p : OutPoint) (coin : Coin)
    (h : (p, coin) ∈ coinsAt s keys) : s.lookup p = some coin := by
  induction keys with
  | nil => simp [coinsAt] at h
  | cons q qs ih =>
    unfold coinsAt at h
    split at h
    · exact ih h
    · rename_i c hq
      rcases List.mem_cons.mp h with he | h
      · simp only [Prod.mk.injEq] at he
        rw [he.1, he.2]
        exact hq
      · exact ih h

/-- [D] 2026-10-13: a receipt's retained vector from a well-formed view is
already pruned by stored creation height, so restoring filters nothing.
[SRC] src/validation.cpp:2937-2953 and src/coins.cpp:45-64 at 6504a3af. -/
theorem restorable_of_wellFormed (params : ChainParams) (s : UtxoSet) (keys : List OutPoint)
    (wf : WellFormedCoins params s) : restorableUndo params ⟨coinsAt s keys⟩ = ⟨coinsAt s keys⟩ := by
  simp only [restorableUndo, Undo.mk.injEq]
  apply List.filter_eq_self.mpr
  intro ⟨p, coin⟩ hm
  simp [(wf p coin (coinsAt_lookup s keys p coin hm)).2]

/-- [D] 2026-10-13: the coinbase receipt retains an empty vector.
[SRC] src/validation.cpp:2483-2491,3436-3443 at 6504a3af. -/
theorem coinbase_receipt_undo (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (a : BlockApplication) (hcb : isCoinBase a.tx = true)
    (h : applyTx s cfg ctx lists oracle a.tx = .ok (a.after, a.undo)) : a.undo = ⟨[]⟩ := by
  have := congrArg Prod.snd (applyTx_success s cfg ctx lists oracle a.tx _ h).2
  simp only [updateCoins, spentOutpoints, hcb, ite_true, coinsAt] at this
  exact this

/-- [M] 2026-10-13, #68 theorem 1, the coinbase case stated separately (undo
correctness). For every successful connection of a non-genesis block followed
by a clean disconnection of the same block with the undo the connection
retained, under any parameters, configuration, operator lists, script oracle
and time, the disconnection restores the original coin set exactly. Premises
in plain words: the connection succeeded (`hc`); the block is not genesis
(`nonGenesis`); the starting view is well formed, every entry a live coin that
AddCoin would store at its own height (`wf`, which every connection preserves);
the coinbase's spendable outputs overwrite no live coin of the parent view
(`coinbaseFresh`); and the disconnection, at the block's height, reported a
clean result (`hd`). The coinbase premise is the reference's own gap: AddCoins
lets a coinbase overwrite a live coin and the block undo keeps no record of it,
so after such an overwrite no undo can restore the lost coin. Every other
transaction's overwrite is refused by the pin's guard, proved here, not assumed.
The landed law is equality of `CoinsView.coins` for `connectBlock` followed
by a clean `disconnectBlock` at the height derived from `previous`. A
`connectTip`/`disconnectTip` law on `ChainState` is owed: `connectTip` takes
its height through `headerContext`, while `disconnectTip` reads the stored
index height, so the lift needs index-height and ancestry invariants.
`WellFormedCoins` is a normalized live-view representation condition motivated
by AddCoin, not an extra block-validity test: a raw map may contain spent
sentinels or entries AddCoin would prune. The condition is sufficient,
preserved with the same parameters, and stronger than requiring only touched
undo coins to be restorable.
[SRC] src/coins.h:235, src/coins.cpp:45-64,386-401,560-565,
src/validation.cpp:3034-3050,4065-4117 and
src/processing_block_index.cpp:30-69 at 6504a3af.
[SRC] src/coins.cpp:560-565, src/undo.h:109-112,
src/processing_block_index.cpp:50-57,79-96 and src/validation.cpp:2483-2494 at 6504a3af. -/
theorem s6_undo_identity_coinbase (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int) (lists : FrozenLists)
    (oracle : ScriptOracle) (checks : ConnectionChecks) (out : ConnectedBlock)
    (hc : connectBlock view params cfg block previous now lists oracle checks = .ok out)
    (nonGenesis : block.header.hash.toNat ≠ params.hashGenesisBlock)
    (wf : WellFormedCoins params view.coins)
    (coinbaseFresh : ∀ cb ∈ block.transactions.head?,
      ∀ p ∈ (createdOutputs params ((previous.map (·.height + 1)).getD 0) cb).map Prod.fst,
        getCoin view.coins p = none)
    (restored : CoinsView)
    (hd : disconnectBlock out.view params ((previous.map (·.height + 1)).getD 0) block out.undo =
      (.ok, restored)) :
    restored.coins = view.coins := by
  obtain ⟨ctx, cb, rest, hp, hparams, hheight, htx, hcb, hrest, _, hv, horder, _, hundo⟩ :=
    connected_shape view params cfg block previous now lists oracle checks out hc nonGenesis
  rw [← hparams] at wf hd coinbaseFresh
  rw [← hheight] at hd coinbaseFresh
  rw [htx] at coinbaseFresh horder
  have wfAll := applications_wellFormed cfg ctx lists _ _ _ _ hv wf
  cases happs : out.run.applications with
  | nil => rw [happs] at horder; simp at horder
  | cons a0 arest =>
    rw [happs] at horder hv hundo
    simp only [List.map_cons, List.cons.injEq] at horder
    obtain ⟨h0, hmap⟩ := horder
    have hb0 : a0.before = view.coins := hv.1
    have hr0 := hv.2.1
    rw [← hb0] at hr0
    have nb : NoBlockOverwrite ctx.params ctx.height (a0 :: arest) := by
      rw [← happs]
      apply noBlockOverwrite_of_run cfg ctx lists _ view.coins out.view.coins _ (happs ▸ hv) wf
      intro a ha hacb p hp
      rw [happs] at ha
      rcases List.mem_cons.mp ha with rfl | ha
      · rw [hb0]
        exact coinbaseFresh cb rfl p (h0 ▸ hp)
      · have : a.tx ∈ rest := hmap ▸ List.mem_map_of_mem ha
        rw [hrest a.tx this] at hacb
        cases hacb
    have headEmpty : ∀ a, (a0 :: arest).head? = some a → a.undo = ⟨[]⟩ := by
      intro a ha
      simp only [List.head?_cons, Option.some.injEq] at ha
      subst a
      exact coinbase_receipt_undo _ cfg ctx lists _ a0 (h0 ▸ hcb) hr0
    have hw : UndoPairsWellFormed ctx.params (blockUndoPairs block.transactions out.undo.transactions) := by
      rw [htx, hundo]
      intro tx u b hm
      simp only [blockUndoPairs, List.mem_cons, Prod.mk.injEq, List.drop_succ_cons, List.drop_zero,
        List.mem_map, Prod.exists] at hm
      rcases hm with ⟨_, rfl, rfl⟩ | ⟨t, u', hz, rfl, rfl, rfl⟩
      · exact ⟨rfl, fun _ => rfl⟩
      · refine ⟨?_, by simp⟩
        obtain ⟨a, ha, rfl⟩ := List.mem_map.mp (List.of_mem_zip hz).2
        have hra := applications_member cfg ctx lists _ _ _ _ (happs ▸ hv) a (happs ▸ List.mem_cons_of_mem _ ha)
        have hu := congrArg Prod.snd (applyTx_success a.before cfg ctx lists _ a.tx _ hra).2
        simp only [updateCoins] at hu
        rw [hu]
        exact restorable_of_wellFormed ctx.params a.before _
          (wfAll.2 a (happs ▸ List.mem_cons_of_mem _ ha))
    exact connect_disconnect_identity view params cfg block previous now lists oracle checks ctx out hp hc
      hparams (happs ▸ nb) (happs ▸ headEmpty) (hparams ▸ hw) restored (hparams ▸ hd)

/-- [M] 2026-10-13, #68 theorem 1 (undo correctness), where BIP30 is enforced.
For every successful connection of a non-genesis block whose effective BIP30
check ran (`bip30`: the branch #69 derives, true at every height outside the
two historical exceptions, the BIP34 shortcut and a network-permitted disable
switch), followed by a clean disconnection with the retained undo at the
block's height, under any parameters, configuration, operator lists, script
oracle and time, the disconnection restores the original coin set exactly,
whenever the starting view is well formed (`wf`). No coinbase premise remains:
the connection's own BIP30 loop refused every output of the body over a live
coin of the parent view, the coinbase's among them. Where BIP30 is not
enforced, `s6_undo_identity_coinbase` states the separate law with its premise.
The landed law is equality of `CoinsView.coins` for `connectBlock` followed
by a clean `disconnectBlock` at the height derived from `previous`. A
`connectTip`/`disconnectTip` law on `ChainState` is owed: `connectTip` takes
its height through `headerContext`, while `disconnectTip` reads the stored
index height, so the lift needs index-height and ancestry invariants.
`WellFormedCoins` is a normalized live-view representation condition motivated
by AddCoin, not an extra block-validity test: a raw map may contain spent
sentinels or entries AddCoin would prune. The condition is sufficient,
preserved with the same parameters, and stronger than requiring only touched
undo coins to be restorable.
[SRC] src/coins.h:235, src/coins.cpp:45-64,386-401,560-565,
src/validation.cpp:3034-3050,4065-4117 and
src/processing_block_index.cpp:30-69 at 6504a3af.
[SRC] src/validation.cpp:3061-3117, src/coins.cpp:560-565, src/undo.h:109-112
and src/processing_block_index.cpp:50-57,79-96 at 6504a3af. -/
theorem s6_undo_identity (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int) (lists : FrozenLists)
    (oracle : ScriptOracle) (checks : ConnectionChecks) (out : ConnectedBlock)
    (hc : connectBlock view params cfg block previous now lists oracle checks = .ok out)
    (nonGenesis : block.header.hash.toNat ≠ params.hashGenesisBlock)
    (bip30 : checks.bip30Required = true)
    (wf : WellFormedCoins params view.coins)
    (restored : CoinsView)
    (hd : disconnectBlock out.view params ((previous.map (·.height + 1)).getD 0) block out.undo =
      (.ok, restored)) :
    restored.coins = view.coins := by
  apply s6_undo_identity_coinbase view params cfg block previous now lists oracle checks out hc nonGenesis wf
    _ restored hd
  intro cb hcb p hp
  obtain ⟨ctx, _, hp', _⟩ := connectBlock_parts view params cfg block previous now lists oracle checks out hc
    nonGenesis
  obtain ⟨_, _, _, fresh⟩ := prepare_some view params cfg block previous now checks ctx hp'
  obtain ⟨⟨q, coin⟩, hm, rfl⟩ := List.mem_map.mp hp
  obtain ⟨output, index, hidx, _, rfl, _⟩ := (createdOutputs_membership params _ cb q coin).mp hm
  exact fresh bip30 cb (List.mem_of_mem_head? hcb) output index hidx

/-! ## Theorem 4: maximal work after automatic activation -/

/-- [M] 2026-10-13, #68 theorem 4 (maximal work). After a successful automatic
activation, under any parameters, configuration, operator lists, script
oracle, budget and time, the active tip names an eligible candidate whose
accumulated work bounds every eligible candidate's, and every retained index
that is eligible (available valid ancestry with its body, not failed, not
soft-rejected or soft-frozen), pruned from the candidate set or not, has work at
most the tip's. Premises in plain words: activation returned complete (`h`),
which the executable checks after every setting change; an interrupted or
failed activation claims nothing; and the chain has a tip (`ht`). The charter's
sentence, "a transaction leaves the active chain only when a chain of more
accumulated work is connected", is false in the machine: an operator's
invalidation disconnects at once with no higher-work replacement
(src/validation.cpp:5234-5256), as do soft rejection and freeze changes, and
an equal-work choice moves the tip without strict growth. The kernel-checked
counterexample is `s6_charter_removal_false`; the landed removal laws name their causes
(`disconnectTip_removal`, `activateBestChain_removal`, `invalidateBlock_removal`,
`setSoftRejection_removal`, `setSoftFreeze_removal`). The removal laws of
`reconsiderBlock` and `preciousBlock` are OWED as their own theorems. Their
`ChainExecution` proof needs unique block index identifiers, either a stated
local condition or a proved reachable-state invariant, never an axiom.
The inherited `activateBestChain_removal` covers their activation today;
`reconsiderBlock_bound` and `preciousBlock_bound` prove body binding, not removal.
[SRC] src/rpc/blockchain.cpp:2770-2818 and
src/validation.cpp:5528-5562,5156-5190 at 6504a3af.
[SRC] src/validation.cpp:4413-4494,4498-4523,4913-5130 and
src/block_index.h:1225-1274 at 6504a3af. -/
theorem s6_activation_maximal_work (s : ChainState) (ctx : ChainContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (fuel : Nat) (out : ChainState)
    (h : activateBestChain s ctx lists oracle fuel = (out, .complete))
    (tip : BitVec 256) (ht : out.active.getLast? = some tip) :
    (∃ best ∈ eligibleCandidates out, best.id = tip ∧
      ∀ i ∈ eligibleCandidates out, i.work.toNat ≤ best.work.toNat) ∧
    ∀ i ∈ out.tree.nodes, candidateEligible out i = true → i.work.toNat ≤ activeWork out := by
  refine ⟨activateBestChain_maximal_work s ctx lists oracle fuel out h tip ht, ?_⟩
  intro i hi he
  have bound := (List.all_eq_true.mp (activateBestChain_work_complete s ctx lists oracle fuel out h)) i hi
  simpa [he] using bound

/-- [M] 2026-10-13, #68 theorem 4 (the non-decrease). A successful automatic
activation does not decrease the selected work when the previous tip stays
selectable. Premises in plain words: the previous tip is the index the tree
returns for it (`tipBefore`, `indexBefore`) and was eligible (`eligibleBefore`);
no effective soft rejection or freeze count changed (`settings`, the additional
before-and-after hypothesis `EligibilitySettingsUnchanged`, which activation
can violate even with a fixed `ChainContext`); the previous tip still has available
valid ancestry afterwards (`remains`); and activation returned complete (`h`).
On a frozen-input failure `connectRun` calls `freezeBlockIndex`
(lean/BsvChain/Chain.lean:694), editing and propagating freeze counts, as the
reference's `softConsensusFreeze` does on that failure.
[SRC] src/validation.cpp:3402-3407,3720-3741 at 6504a3af.
Strict growth needs, beyond these, the premise that the selected work changed
(`activation_work_strict_growth`): an equal-work choice ordered by completion,
sequence or rank satisfies no strict-growth claim.
[SRC] src/validation.cpp:4413-4523,4755-4767,4913-5130 at 6504a3af. -/
theorem s6_activation_work_nondecreasing (before out : ChainState) (ctx : ChainContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (fuel : Nat) (old : BlockIndex)
    (tipBefore : before.active.getLast? = some old.id)
    (indexBefore : before.tree.get old.id = some old)
    (eligibleBefore : candidateEligible before old = true)
    (settings : EligibilitySettingsUnchanged before out)
    (remains : ∃ current, out.tree.get old.id = some current ∧ candidateAvailable out current = true)
    (h : activateBestChain before ctx lists oracle fuel = (out, .complete)) :
    activeWork before ≤ activeWork out :=
  activation_work_nondecreasing before out ctx lists oracle fuel old tipBefore indexBefore
    eligibleBefore settings remains h

end BsvChain.Properties
