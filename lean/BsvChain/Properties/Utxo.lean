import BsvChain.Utxo
import BsvChain.Properties.Finality

/-!
# One-transaction UTXO laws (#61)

All oracles, configurations, times and network parameters remain quantified.
The map is executable Finmap, with no representation-equality assumption.
[SRC] src/validation.cpp:2480–2495,2552–2665 and
src/processing_block_index.cpp:30–69 at 6504a3af.
-/

namespace BsvChain.Properties
open BsvScript.Tx

/-- Erasing a list removes exactly its keys and leaves every other lookup
unchanged, with no uniqueness assumption. This is the removal half of the
transition's exactness law. [SRC] src/validation.cpp:2483–2491 at 6504a3af. -/
theorem lookup_eraseKeys (s : UtxoSet) (keys : List OutPoint) (p : OutPoint) :
    (eraseKeys s keys).lookup p = if p ∈ keys then none else s.lookup p := by
  induction keys with
  | nil => simp [eraseKeys]
  | cons q qs ih =>
    by_cases h : p = q
    · subst q; simp [eraseKeys]
    · simp [eraseKeys, Finmap.lookup_erase_ne h, ih, h]

/-- A finite map made from pairs contains exactly their keys; duplicate keys
do not invent members. This connects the output list to the executable map.
[SRC] src/coins.cpp:548–565 at 6504a3af. -/
theorem mem_coinMap (pairs : List (OutPoint × Coin)) (p : OutPoint) :
    p ∈ coinMap pairs ↔ p ∈ pairs.map Prod.fst := by
  induction pairs with
  | nil => simp [coinMap, Finmap.notMem_empty]
  | cons pair rest ih => cases pair; simp [coinMap, ih]

/-- The retained undo map is exactly the original lookup restricted to spent
keys. It keeps coins, not a hidden copy of the original UTXO set.
[SRC] src/undo.h:80–83 and src/validation.cpp:2483–2489 at 6504a3af. -/
theorem lookup_coinsAt (s : UtxoSet) (keys : List OutPoint) (p : OutPoint) :
    (coinMap (coinsAt s keys)).lookup p = if p ∈ keys then s.lookup p else none := by
  induction keys with
  | nil => simp [coinsAt, coinMap]
  | cons q qs ih =>
    cases hq : s.lookup q with
    | none =>
      by_cases hp : p = q
      · subst q; simp [coinsAt, hq, ih]
      · simp [coinsAt, hq, ih, hp]
    | some coin =>
      by_cases hp : p = q
      · subst q; simp [coinsAt, hq, coinMap]
      · simp [coinsAt, hq, coinMap, Finmap.lookup_insert_of_ne _ hp, ih, hp]

/-- Success exposes both validation and the precise pure update; there is no
other successful mutation branch. This bridges later laws to applyTx itself.
[SRC] src/validation.cpp:2480–2495,3326–3434 at 6504a3af. -/
theorem applyTx_success (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (tx : Tx) (result : UtxoSet × Undo)
    (h : applyTx s cfg ctx lists oracle tx = .ok result) :
    validateUtxoTx s cfg ctx lists oracle tx = .ok () ∧
      result = updateCoins s ctx.params ctx.height tx := by
  cases hv : validateUtxoTx s cfg ctx lists oracle tx with
  | error e => simp [applyTx, hv] at h
  | ok u =>
    cases u
    simp [applyTx, hv] at h
    exact ⟨rfl, h.symm⟩

/-- Acceptance of the input stage includes acceptance of #60's fee stage.
The proof follows its ordered guards, without assuming a bound on the oracle.
[SRC] src/validation.cpp:2552–2665 at 6504a3af. -/
theorem checkTxInputs_fee (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (tx : Tx) (amount : Int)
    (h : checkTxInputs s cfg ctx lists tx = .ok amount) :
    fee (inputValue s tx) (outputValue tx) = .ok amount := by
  unfold checkTxInputs at h
  simp only [bind, Except.bind] at h
  split at h <;> simp_all
  split at h
  · split at h <;> simp_all
    split at h <;> simp_all
    cases hc : checkInputCoins s cfg ctx lists true tx.inputs 0 <;> simp_all
  · cases hc : checkInputCoins s cfg ctx lists false tx.inputs 0 <;> simp_all

/-- Every accepted non-coinbase application passed the input stage. Coinbase
is explicitly excluded, since its subsidy and structure are checked by #63.
[SRC] src/validation.cpp:3326–3392 at 6504a3af. -/
theorem applyTx_inputs_checked (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (tx : Tx) (result : UtxoSet × Undo)
    (hcb : BsvScript.TxRules.isCoinBase tx = false)
    (h : applyTx s cfg ctx lists oracle tx = .ok result) :
    ∃ amount, checkTxInputs s cfg ctx lists tx = .ok amount := by
  have hv := (applyTx_success s cfg ctx lists oracle tx result h).1
  simp only [validateUtxoTx, hcb, Bool.false_eq_true, ↓reduceIte,
    bind, Except.bind, pure, Except.pure] at hv
  cases hs : checkUtxoStructure tx <;> simp_all
  split at hv <;> simp_all
  cases hc : checkTxInputs s cfg ctx lists tx with
  | error e => simp_all
  | ok amount => exact ⟨amount, rfl⟩

/-- Value conservation for every accepted non-coinbase transaction: all input
values equal all output values plus an accepted, nonnegative fee. Burned
outputs are included. The statement holds for every oracle; cryptography is
not an assumption. [SRC] src/validation.cpp:2639–2663 at 6504a3af. -/
theorem applyTx_value_conservation (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (tx : Tx) (result : UtxoSet × Undo)
    (hcb : BsvScript.TxRules.isCoinBase tx = false)
    (h : applyTx s cfg ctx lists oracle tx = .ok result) :
    ∃ amount, fee (inputValue s tx) (outputValue tx) = .ok amount ∧
      0 ≤ amount ∧ inputValue s tx = outputValue tx + amount := by
  obtain ⟨amount, ha⟩ := applyTx_inputs_checked s cfg ctx lists oracle tx result hcb h
  have hf := checkTxInputs_fee s cfg ctx lists tx amount ha
  refine ⟨amount, hf, fee_nonnegative _ _ _ hf, ?_⟩
  unfold fee at hf
  split at hf <;> simp_all
  split at hf <;> simp_all
  omega

/-- Output eligibility has exactly the pin's creation-era predicate. Each
returned pair names an indexed transaction output and its complete coin
metadata; every such spendable output is returned. No validity of script
execution is substituted for the pruning predicate.
[SRC] src/coins.cpp:45–64,548–565 at 6504a3af. -/
theorem createdOutputs_membership (params : ChainParams) (height : Nat) (tx : Tx)
    (p : OutPoint) (coin : Coin) :
    (p, coin) ∈ createdOutputs params height tx ↔
      ∃ output index, (output, index) ∈ tx.outputs.zipIdx ∧
        isUnspendable (decide (params.genesisHeight ≤ height)) output.scriptPubKey = false ∧
        p = ⟨BsvScript.Sighash.txid tx, index⟩ ∧
        coin = ⟨output.value, output.scriptPubKey, height,
          BsvScript.TxRules.isCoinBase tx, isConfiscationTx tx⟩ := by
  simp only [createdOutputs, List.mem_filterMap, Prod.exists]
  constructor
  · rintro ⟨output, index, hm, he⟩
    split at he <;> simp_all
    exact ⟨output, index, hm, by assumption, he.1.symm, he.2.symm⟩
  · rintro ⟨output, index, hm, hu, rfl, rfl⟩
    exact ⟨output, index, hm, by simp [hu]⟩

/-- Complete membership characterization after an accepted application:
eligible new outputs, together with precisely the old keys not spent.
Re-created spent keys appear through the output clause. Combined with
createdOutputs_membership this states both set changes under the creation era.
[SRC] src/validation.cpp:2483–2494 and src/coins.cpp:45–64,548–565 at 6504a3af. -/
theorem applyTx_membership (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (tx : Tx) (result : UtxoSet × Undo)
    (h : applyTx s cfg ctx lists oracle tx = .ok result) (p : OutPoint) :
    p ∈ result.1 ↔ p ∈ (createdOutputs ctx.params ctx.height tx).map Prod.fst ∨
      (p ∈ s ∧ p ∉ spentOutpoints tx) := by
  rw [(applyTx_success s cfg ctx lists oracle tx result h).2]
  simp only [updateCoins, Finmap.mem_union, mem_coinMap]
  have hm : p ∈ eraseKeys s (spentOutpoints tx) ↔ p ∈ s ∧ p ∉ spentOutpoints tx := by
    rw [← not_iff_not, ← Finmap.lookup_eq_none, lookup_eraseKeys]
    by_cases hp : p ∈ spentOutpoints tx <;> simp [hp, Finmap.lookup_eq_none]
  rw [hm]

/-- Outside the eligible outputs, an accepted application removes spent keys
and preserves every other coin, including all metadata. This is the lookup
form of the removal law. [SRC] src/validation.cpp:2483–2494 at 6504a3af. -/
theorem applyTx_retained (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (tx : Tx) (result : UtxoSet × Undo)
    (h : applyTx s cfg ctx lists oracle tx = .ok result) (p : OutPoint)
    (hp : p ∉ (createdOutputs ctx.params ctx.height tx).map Prod.fst) :
    result.1.lookup p = if p ∈ spentOutpoints tx then none else s.lookup p := by
  rw [(applyTx_success s cfg ctx lists oracle tx result h).2]
  simp only [updateCoins]
  rw [Finmap.lookup_union_right ((mem_coinMap _ _).not.mpr hp), lookup_eraseKeys]

/-- Every eligible output receives its new coin, even if a coinbase overwrites
a live outpoint. This is the lookup form of the addition law.
[SRC] src/coins.cpp:548–565 at 6504a3af. -/
theorem applyTx_added (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (tx : Tx) (result : UtxoSet × Undo)
    (h : applyTx s cfg ctx lists oracle tx = .ok result) (p : OutPoint)
    (hp : p ∈ (createdOutputs ctx.params ctx.height tx).map Prod.fst) :
    result.1.lookup p = (coinMap (createdOutputs ctx.params ctx.height tx)).lookup p := by
  rw [(applyTx_success s cfg ctx lists oracle tx result h).2]
  exact Finmap.lookup_union_left ((mem_coinMap _ _).mpr hp)

/-- A one-transaction update followed by its retained undo restores the map
when no eligible output overwrites a remaining entry. For a live UTXO set
this is precisely the no-live-overwrite condition; it allows a spent key to
be re-created. The pin's coinbase overwrite permission makes the hypothesis
necessary, because undo retains no replaced outputs.
[SRC] src/coins.cpp:560–565, src/undo.h:80–83 and
src/processing_block_index.cpp:30–69 at 6504a3af. -/
theorem undo_updateCoins (s : UtxoSet) (params : ChainParams) (height : Nat) (tx : Tx)
    (hn : ∀ p ∈ (createdOutputs params height tx).map Prod.fst,
      p ∉ eraseKeys s (spentOutpoints tx)) :
    undoTx (updateCoins s params height tx).1 params height tx
      (updateCoins s params height tx).2 = s := by
  apply Finmap.ext_lookup
  intro p
  simp only [undoTx, updateCoins]
  by_cases hsp : p ∈ spentOutpoints tx
  · cases hs : s.lookup p with
    | some coin =>
      have hu : (coinMap (coinsAt s (spentOutpoints tx))).lookup p = some coin := by
        rw [lookup_coinsAt, ite_eq_left hsp, hs]
      rw [Finmap.lookup_union_left (Finmap.mem_of_lookup_eq_some hu), hu]
    | none =>
      have hu : p ∉ coinMap (coinsAt s (spentOutpoints tx)) := by
        rw [← Finmap.lookup_eq_none, lookup_coinsAt, ite_eq_left hsp, hs]
      rw [Finmap.lookup_union_right hu, lookup_eraseKeys]
      by_cases ho : p ∈ (createdOutputs params height tx).map Prod.fst
      · simp [ho]
      · rw [ite_eq_right ho, Finmap.lookup_union_right ((mem_coinMap _ _).not.mpr ho),
          lookup_eraseKeys, ite_eq_left hsp]
  · have hu : p ∉ coinMap (coinsAt s (spentOutpoints tx)) := by
      rw [← Finmap.lookup_eq_none, lookup_coinsAt, ite_eq_right hsp]
    rw [Finmap.lookup_union_right hu, lookup_eraseKeys]
    by_cases ho : p ∈ (createdOutputs params height tx).map Prod.fst
    · rw [ite_eq_left ho]
      have hh := Finmap.lookup_eq_none.mpr (hn p ho)
      rw [lookup_eraseKeys, ite_eq_right hsp] at hh
      exact hh.symm
    · rw [ite_eq_right ho, Finmap.lookup_union_right ((mem_coinMap _ _).not.mpr ho),
        lookup_eraseKeys, ite_eq_right hsp]

/-- Undo identity for applyTx itself, on every successful application and
under the pin's no-overwrite hypothesis. No assumption about the oracle's
implementation is used. [SRC] src/coins.cpp:560–565 and
src/processing_block_index.cpp:30–69 at 6504a3af. -/
theorem applyTx_undo (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (tx : Tx) (result : UtxoSet × Undo)
    (h : applyTx s cfg ctx lists oracle tx = .ok result)
    (hn : ∀ p ∈ (createdOutputs ctx.params ctx.height tx).map Prod.fst,
      p ∉ eraseKeys s (spentOutpoints tx)) :
    undoTx result.1 ctx.params ctx.height tx result.2 = s := by
  rw [(applyTx_success s cfg ctx lists oracle tx result h).2]
  exact undo_updateCoins s ctx.params ctx.height tx hn

/-- Determinism includes the undo: fixed explicit inputs and a fixed oracle
yield one result. It uses no clock, network or cryptographic axiom.
This is a definition-level law: applyTx is deterministic because it is a
function of its explicit inputs and the oracle.
[SRC] src/validation.cpp:2480–2495,2552–2665 at 6504a3af. -/
theorem applyTx_deterministic (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (tx : Tx)
    (a b : Except Reject (UtxoSet × Undo))
    (ha : applyTx s cfg ctx lists oracle tx = a)
    (hb : applyTx s cfg ctx lists oracle tx = b) : a = b := by
  rw [← ha, ← hb]

end BsvChain.Properties
