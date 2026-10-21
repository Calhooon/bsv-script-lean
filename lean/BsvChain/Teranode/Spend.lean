import BsvChain.Chain
import BsvChain.Properties.Mempool

/-!
# Teranode's UTXO-store spend against the reference's conflict rule (#90)

[M] 2026-10-14 (#90). Which of two conflicting spends a node keeps
decides what a wallet sees. This module states the second oracle's store
spend as a transition and compares it with the reference's earliest-seen rule.

The store side is Teranode v0.16.0 at
`4edb60a40c6628ff0ef60231c2628efd7103fde5` (`docs/PROVENANCE.md` §1a), read
at the tag: the per-output spend of the Lua UDF `spendMulti`
(`stores/utxo/aerospike/teranode.lua:284-466`), the store's `Spend` with its
rollback (`stores/utxo/aerospike/spend.go:387-548`), the validator's
mempool path (`services/validator/Validator.go:1105-1257`), the conflicting
mark (`stores/utxo/aerospike/conflicting.go:42`, `SetConflicting`), the
reorg swap (`stores/utxo/process_conflicting.go:135,458`), its caller
(`services/blockassembly/subtreeprocessor/SubtreeProcessor.go:4159-4264`)
and the unmined mark (`stores/utxo/aerospike/longest_chain.go:49`) [SRC].

The store is Teranode's Aerospike backend; the SQL backend
(`stores/utxo/sql/sql.go`), which the `test` settings context selects
(`settings.conf:1592`, `utxostore.test = sqlite:///utxostore`), reaches the
same per-output outcomes by a per-input enqueue into one serialized batch
(`sql.go:223,2104-2128,2206-2207,2275`) [SRC] 4edb60a4. The instance of
record runs `SETTINGS_CONTEXT=test` (`docs/lanes/harness.md`, A3), so it
drives SQLite. The witnesses are about the model, which is the Aerospike
store; `concurrent_outcome_iff` states the per-record condition the empty
outcome needs, and its docstring says what meets it on each backend.

The reference side is bitcoin-sv v1.2.3 at
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: the conflict stage
(`src/validation.cpp:1147-1152`), the detector insertion
(`src/validation.cpp:1484-1494`) and the spent index
(`src/txmempool.cpp:298-304`) [SRC], as `BsvChain.stageConflict`,
`BsvChain.stageDetector` and `BsvChain.hasPoolConflict` model them.

What closes:
* `accepted_eq_mempool`: under sequential arrival (each submission's store
  calls finish before the next begins) and no reorg, for every arrival order
  the store keeps exactly the transactions the reference's earliest-seen rule
  keeps, in the same order, given one oracle for every other check.
* `conflict_bridge` and `accept_conflict_refuses`: the reference model's
  conflict test is BsvChain's stage-5 predicate, and BsvChain's complete
  `accept` refuses on it.
* `accepted_eq_accept_of_earliestSeen`: the same equality against BsvChain's
  complete `accept` for one arrival order `txs`, under
  `AcceptIsEarliestSeen … txs`, which is stated and NOT asserted (the
  remaining obligation). It is restricted to the run: each submission of
  `txs`, on the pool `accept` built from the ones before it, moves the
  accepted pool as `refSubmit` does with `valid`.
* Two witnesses, each `decide`-checked: a concurrent interleaving of the
  per-output spends in which the store keeps neither of two conflicting
  transactions while the reference keeps one (`concurrent_both_refused`, with
  the exact condition over every schedule in `concurrent_outcome_iff`), and
  a reorg in which the store restores the earlier mempool spender while the
  reference re-admits the disconnected block's spender (`reorg_keeps_differ`).
-/

namespace BsvChain.Teranode
open BsvChain BsvScript.Tx BsvScript.Numbers

/-! ## The abstract transaction and the two states -/

/-- An output: its transaction's id and its index. Teranode's `utxo.Spend`
keys an output the same way (`TxID`, `Vout`;
`stores/utxo/Interface.go:131-150` at 4edb60a4 [SRC]); the reference's
outpoint is `BsvChain.OutPoint` (`src/primitives/transaction.h:51-79` at
6504a3af [SRC]). -/
structure Out (ι : Type) where
  txid : ι
  vout : Nat
  deriving DecidableEq, Repr

/-- The comparison's transaction: its id and the outputs it spends, in input
order. Everything else about it is the oracle's. -/
structure STx (ι : Type) where
  id : ι
  inputs : List (Out ι)
  deriving DecidableEq, Repr

variable {ι : Type} [DecidableEq ι]

/-- The UTXO store's state for the comparison. `spent` holds each spent
output's spending data (the spender's id; the store writes the id and the
input index, `teranode.lua:161-192`). `conflicting` is the record bin
`conflicting` (`stores/utxo/fields/fields.go:40`); `records` the transaction
records created; `unmined` the records whose `unminedSince` is set
(`stores/utxo/fields/fields.go:79`). [SRC] at 4edb60a4. -/
structure Store (ι : Type) where
  spent : List (Out ι × ι) := []
  conflicting : List ι := []
  records : List ι := []
  unmined : List ι := []
  deriving DecidableEq, Repr

/-- The output's current spender, if any (`getUTXOAndSpendingData`,
`teranode.lua:194-232` at 4edb60a4 [SRC]). -/
def spender (s : Store ι) (o : Out ι) : Option ι :=
  (s.spent.find? (fun kv => kv.1 == o)).map (·.2)

/-- The store's mempool: unmined records not marked conflicting; DESIGN-S6
§5.2 reads a mempool entry as an unmined record, and a conflicting record is
refused as a parent (`teranode.lua:305-313`) and evicted from assembly
(`SubtreeProcessor.go:4261-4265`). [SRC] at 4edb60a4. -/
def kept (s : Store ι) : List ι :=
  s.records.filter (fun id => s.unmined.contains id && !s.conflicting.contains id)

/-! ## The store's spend, per output -/

/-- One output's spend inside `spendMulti`: a conflicting parent record
refuses unless the caller ignores the mark (`teranode.lua:305-313`); an
output already spent by the same spender is an idempotent success
(`:386-401`); spent by another, the `SPENT` error (`:415-425`); unspent, the
spending data is written (`:428-433`). The record's update is one UDF call,
atomic per record (`:439-444`). Teranode v0.16.0 at 4edb60a4 [SRC]. -/
def spendOne (ignoreConflicting : Bool) (s : Store ι) (id : ι) (o : Out ι) : Store ι × Bool :=
  if !ignoreConflicting && s.conflicting.contains o.txid then (s, false)
  else match spender s o with
    | some j => (s, j == id)
    | none => ({ s with spent := s.spent ++ [(o, id)] }, true)

/-- Every input of one transaction. The store keeps processing after a
failure to collect every error (`spend.go:600-618`), so the result carries
the outputs whose spend succeeded and whether all did. [SRC] 4edb60a4. -/
def spendAll (ignoreConflicting : Bool) (s : Store ι) (id : ι) :
    List (Out ι) → Store ι × List (Out ι) × Bool
  | [] => (s, [], true)
  | o :: os =>
    let r := spendOne ignoreConflicting s id o
    let t := spendAll ignoreConflicting r.1 id os
    (t.1, if r.2 then o :: t.2.1 else t.2.1, r.2 && t.2.2)

/-- `unspend` clears an output's spending data only when the caller owns the
spend (`teranode.lua:484-556`, the ownership check at 520-521). [SRC] 4edb60a4. -/
def unspendOne (s : Store ι) (id : ι) (o : Out ι) : Store ι :=
  { s with spent := s.spent.filter (fun kv => !(kv.1 == o && kv.2 == id)) }

/-- Unspend a list of outputs for one spender (`Store.Unspend`,
`stores/utxo/Interface.go:458`). [SRC] 4edb60a4. -/
def unspendAll (s : Store ι) (id : ι) (os : List (Out ι)) : Store ι :=
  os.foldl (fun s o => unspendOne s id o) s

/-- The store's `Spend` for a whole transaction: on a `SPENT`, `CONFLICTING`,
`FROZEN` or hash-mismatch failure every successful spend of the call is
unspent (`spend.go:513-527`, the predicate `isSpendRollbackError` 628-633).
Per output atomic, NOT atomic across the transaction's outputs: a
transaction's inputs are enqueued as one ordered group (`spend.go:407-411,461`),
and each parent record is a separate UDF call inside the batch's
`BatchOperate`. [SRC] 4edb60a4. -/
def spendTx (ignoreConflicting : Bool) (s : Store ι) (tx : STx ι) : Store ι × Bool :=
  let r := spendAll ignoreConflicting s tx.id tx.inputs
  if r.2.2 then (r.1, true) else (unspendAll r.1 tx.id r.2.1, false)

/-- The validator's mempool submission (`CreateConflicting` false, its default
`services/validator/options.go:227`): the oracle's checks, then the spend; a
refused spend refuses the transaction (`Validator.go:1143-1257`); a
transaction already recorded is an idempotent success with its spends left
(`:1106-1141`); otherwise the record is created unmined (`SpendAndCreate`,
`stores/utxo/Interface.go:432-454`). [SRC] 4edb60a4. -/
def submit (valid : STx ι → Bool) (s : Store ι) (tx : STx ι) : Store ι × Bool :=
  if !valid tx then (s, false) else
  let r := spendTx false s tx
  if !r.2 then r
  else if r.1.records.contains tx.id then r
  else ({ r.1 with records := r.1.records ++ [tx.id], unmined := r.1.unmined ++ [tx.id] }, true)

/-- Sequential arrival: each submission completes before the next. -/
def storeRun (valid : STx ι → Bool) (s : Store ι) : List (STx ι) → Store ι
  | [] => s
  | tx :: txs => storeRun valid (submit valid s tx).1 txs

/-! ## The reference's earliest-seen rule -/

/-- The reference's accepted pool for the comparison: the accepted entries and
the spent index `mapNextTx` (`src/txmempool.cpp:298-304` and
`src/txmempool.h:562` at 6504a3af [SRC]; `BsvChain.Mempool`). -/
structure Pool (ι : Type) where
  accepted : List (STx ι) := []
  mapNextTx : List (Out ι × ι) := []
  deriving DecidableEq, Repr

/-- Stage 5's test: an input already in the spent index
(`src/validation.cpp:1147-1152` at 6504a3af [SRC]; `BsvChain.hasPoolConflict`). -/
def refConflict (p : Pool ι) (tx : STx ι) : Bool :=
  tx.inputs.any (fun o => p.mapNextTx.any (fun kv => kv.1 == o))

/-- The reference's admission as the conflict rule sees it: an accepted id is
refused at stage 4 (`src/validation.cpp:1142-1145`), the oracle refuses or
the conflict stage does, else the entry joins and indexes its inputs
(`src/txmempool.cpp:758-778`). 6504a3af [SRC]. -/
def refSubmit (valid : STx ι → Bool) (p : Pool ι) (tx : STx ι) : Pool ι × Bool :=
  if p.accepted.any (fun e => e.id == tx.id) then (p, false)
  else if !valid tx then (p, false)
  else if refConflict p tx then (p, false)
  else ({ accepted := p.accepted ++ [tx],
          mapNextTx := p.mapNextTx ++ tx.inputs.map (fun o => (o, tx.id)) }, true)

/-- The reference's run over an arrival order. -/
def refRun (valid : STx ι → Bool) (p : Pool ι) : List (STx ι) → Pool ι
  | [] => p
  | tx :: txs => refRun valid (refSubmit valid p tx).1 txs

/-! ## The per-output lemmas -/

/-- The free test the per-output spend makes in a state without conflicting
marks: no spending data for the output. -/
def isFree (s : Store ι) (o : Out ι) : Bool := !s.spent.any (fun kv => kv.1 == o)

/-- A free output has no spender. -/
theorem spender_none_of_free {s : Store ι} {o : Out ι} (h : isFree s o = true) :
    spender s o = none := by
  have h' : s.spent.any (fun kv => kv.1 == o) = false := by
    unfold isFree at h; cases hb : s.spent.any (fun kv => kv.1 == o) <;> simp_all
  have hn : s.spent.find? (fun kv => kv.1 == o) = none :=
    List.find?_eq_none.mpr (fun kv hkv => List.any_eq_false.mp h' kv hkv)
  unfold spender; rw [hn]; rfl

/-- A taken output's spender is the owner of its earliest index entry. -/
theorem spender_some_of_not_free {s : Store ι} {o : Out ι} (h : isFree s o = false) :
    ∃ kv ∈ s.spent, kv.1 = o ∧ spender s o = some kv.2 := by
  have h' : s.spent.any (fun kv => kv.1 == o) = true := by
    unfold isFree at h; cases hb : s.spent.any (fun kv => kv.1 == o) <;> simp_all
  have hsome : (s.spent.find? (fun kv => kv.1 == o)).isSome = true := by
    rw [List.find?_isSome]; exact List.any_eq_true.mp h'
  obtain ⟨kv, hkv⟩ := Option.isSome_iff_exists.mp hsome
  refine ⟨kv, List.mem_of_find?_eq_some hkv, ?_, by simp [spender, hkv]⟩
  simpa using List.find?_some hkv

/-- Without conflicting marks, with distinct inputs and with no spend already
owned by `id` on any of them, the per-output spends append exactly the free
inputs, in order, and report whether every input was free. -/
theorem spendAll_eq (s : Store ι) (id : ι) (os : List (Out ι))
    (hc : s.conflicting = []) (hnd : os.Nodup)
    (hown : ∀ kv ∈ s.spent, kv.1 ∈ os → kv.2 ≠ id) :
    spendAll false s id os =
      ({ s with spent := s.spent ++ (os.filter (isFree s)).map (fun o => (o, id)) },
        os.filter (isFree s), os.all (isFree s)) := by
  induction os generalizing s with
  | nil => simp [spendAll]
  | cons o os ih =>
    simp only [List.nodup_cons] at hnd
    by_cases hf : isFree s o = true
    · have step : spendOne false s id o = ({ s with spent := s.spent ++ [(o, id)] }, true) := by
        simp [spendOne, hc, spender_none_of_free hf]
      have hown' : ∀ kv ∈ s.spent ++ [(o, id)], kv.1 ∈ os → kv.2 ≠ id := by
        intro kv hkv hk
        rcases List.mem_append.mp hkv with h | h
        · exact hown kv h (List.mem_cons_of_mem _ hk)
        · simp at h; subst h; exact absurd hk hnd.1
      have ih' := ih { s with spent := s.spent ++ [(o, id)] } hc hnd.2 hown'
      have hcongr : ∀ o' ∈ os, isFree { s with spent := s.spent ++ [(o, id)] } o' = isFree s o' := by
        intro o' ho'
        have hne : o ≠ o' := fun he => hnd.1 (he ▸ ho')
        simp [isFree, List.any_append, hne]
      have hallc : os.all (isFree { s with spent := s.spent ++ [(o, id)] }) = os.all (isFree s) := by
        rw [Bool.eq_iff_iff, List.all_eq_true, List.all_eq_true]
        exact ⟨fun h x hx => by rw [← hcongr x hx]; exact h x hx,
          fun h x hx => by rw [hcongr x hx]; exact h x hx⟩
      rw [List.filter_congr hcongr, hallc] at ih'
      simp only [spendAll, step, ih']
      simp [hf]
    · have hf' : isFree s o = false := by simpa using hf
      obtain ⟨kv, hm, hk, hsp⟩ := spender_some_of_not_free hf'
      have hj : kv.2 ≠ id := hown kv hm (hk ▸ List.mem_cons_self)
      have step : spendOne false s id o = (s, false) := by
        simp [spendOne, hc, hsp, hj]
      have hown' : ∀ kv ∈ s.spent, kv.1 ∈ os → kv.2 ≠ id :=
        fun kv hkv hk => hown kv hkv (List.mem_cons_of_mem _ hk)
      have ih' := ih s hc hnd.2 hown'
      simp only [spendAll, step, ih']
      simp [hf']

/-- When every input is already spent by `id` itself, the spend is an
idempotent success that changes nothing (`teranode.lua:386-401`). -/
theorem spendAll_owned (s : Store ι) (id : ι) (os : List (Out ι))
    (hc : s.conflicting = []) (h : ∀ o ∈ os, spender s o = some id) :
    spendAll false s id os = (s, os, true) := by
  induction os with
  | nil => simp [spendAll]
  | cons o os ih =>
    have step : spendOne false s id o = (s, true) := by
      simp [spendOne, hc, h o List.mem_cons_self]
    simp [spendAll, step, ih (fun o' ho' => h o' (List.mem_cons_of_mem _ ho'))]

/-- Unspending a list filters every owned entry on it. -/
theorem unspendAll_eq (s : Store ι) (id : ι) (os : List (Out ι)) :
    unspendAll s id os =
      { s with spent := s.spent.filter (fun kv => !(os.contains kv.1 && kv.2 == id)) } := by
  induction os generalizing s with
  | nil => simp [unspendAll]
  | cons o os ih =>
    simp only [unspendAll, List.foldl_cons] at ih ⊢
    rw [ih]
    simp only [unspendOne]
    congr 1
    rw [List.filter_filter]
    apply List.filter_congr
    intro kv _
    simp only [List.contains_cons]
    generalize (kv.1 == o) = a
    generalize os.contains kv.1 = b
    generalize (kv.2 == id) = c
    cases a <;> cases b <;> cases c <;> rfl

/-! ## The sequential theorem -/

/-- The relation the runs keep: the same spent index entry for entry, the
records the accepted ids, every record unmined, no conflicting mark, the index
rebuilt from the accepted entries as `BsvChain.reindex` builds it, distinct
index keys, and every accepted entry passed the oracle. -/
structure Related (valid : STx ι → Bool) (s : Store ι) (p : Pool ι) : Prop where
  spent_eq : s.spent = p.mapNextTx
  records_eq : s.records = p.accepted.map (·.id)
  unmined_eq : s.unmined = p.accepted.map (·.id)
  no_conflicting : s.conflicting = []
  index_eq : p.mapNextTx = p.accepted.flatMap (fun t => t.inputs.map (fun o => (o, t.id)))
  keys_nodup : (p.mapNextTx.map (·.1)).Nodup
  accepted_valid : ∀ e ∈ p.accepted, valid e = true

omit [DecidableEq ι] in
/-- The empty store and the empty pool are related. -/
theorem related_empty (valid : STx ι → Bool) : Related valid ({} : Store ι) ({} : Pool ι) :=
  ⟨rfl, rfl, rfl, rfl, rfl, List.nodup_nil, by simp⟩

/-- `find?` on a list with distinct keys finds an entry by its key. -/
theorem find_of_mem_nodup {l : List (Out ι × ι)} (h : (l.map (·.1)).Nodup)
    {o : Out ι} {j : ι} (hm : (o, j) ∈ l) :
    l.find? (fun kv => kv.1 == o) = some (o, j) := by
  induction l with
  | nil => simp at hm
  | cons kv l ih =>
    simp only [List.map_cons, List.nodup_cons] at h
    rcases List.mem_cons.mp hm with rfl | hm
    · simp
    · have hne : kv.1 ≠ o := by
        intro he
        exact h.1 (by rw [he]; exact List.mem_map.mpr ⟨(o, j), hm, rfl⟩)
      simp [hne, ih h.2 hm]

omit [DecidableEq ι] in
/-- An index entry's owner is an accepted id. -/
theorem owner_accepted {valid : STx ι → Bool} {s : Store ι} {p : Pool ι}
    (r : Related valid s p) {kv : Out ι × ι} (hm : kv ∈ s.spent) :
    ∃ t ∈ p.accepted, t.id = kv.2 ∧ kv.1 ∈ t.inputs := by
  rw [r.spent_eq, r.index_eq] at hm
  obtain ⟨t, ht, hkv⟩ := List.mem_flatMap.mp hm
  obtain ⟨o, ho, rfl⟩ := List.mem_map.mp hkv
  exact ⟨t, ht, rfl, ho⟩

/-- The store's submission when the oracle refuses. -/
theorem submit_invalid (valid : STx ι → Bool) (s : Store ι) (tx : STx ι) (h : valid tx = false) :
    submit valid s tx = (s, false) := by
  simp [submit, h]

/-- The store's submission when a spend fails: the state after the rollback. -/
theorem submit_fail (valid : STx ι → Bool) (s s' : Store ι) (tx : STx ι) (hv : valid tx = true)
    (h : spendTx false s tx = (s', false)) : submit valid s tx = (s', false) := by
  simp [submit, hv, h]

/-- The store's submission of a transaction already recorded: idempotent. -/
theorem submit_known (valid : STx ι → Bool) (s s' : Store ι) (tx : STx ι) (hv : valid tx = true)
    (h : spendTx false s tx = (s', true)) (hk : tx.id ∈ s'.records) :
    submit valid s tx = (s', true) := by
  simp [submit, hv, h, hk]

/-- The store's submission of a new transaction whose spends all succeed. -/
theorem submit_new (valid : STx ι → Bool) (s s' : Store ι) (tx : STx ι) (hv : valid tx = true)
    (h : spendTx false s tx = (s', true)) (hk : tx.id ∉ s'.records) :
    submit valid s tx =
      ({ s' with records := s'.records ++ [tx.id], unmined := s'.unmined ++ [tx.id] }, true) := by
  simp [submit, hv, h, hk]

/-- `spendTx` when every per-output spend succeeds. -/
theorem spendTx_all (s s' : Store ι) (tx : STx ι) (oks : List (Out ι))
    (h : spendAll false s tx.id tx.inputs = (s', oks, true)) : spendTx false s tx = (s', true) := by
  simp [spendTx, h]

/-- `spendTx` when a per-output spend fails: the successful ones are unspent. -/
theorem spendTx_fail (s s' : Store ι) (tx : STx ι) (oks : List (Out ι))
    (h : spendAll false s tx.id tx.inputs = (s', oks, false)) :
    spendTx false s tx = (unspendAll s' tx.id oks, false) := by
  simp [spendTx, h]

/-- The reference refuses an id already accepted (stage 4). -/
theorem refSubmit_known (valid : STx ι → Bool) (p : Pool ι) (tx : STx ι)
    (h : p.accepted.any (fun e => e.id == tx.id) = true) : refSubmit valid p tx = (p, false) := by
  rw [refSubmit, ite_eq_left h]

/-- The reference refuses what the oracle refuses. -/
theorem refSubmit_invalid (valid : STx ι → Bool) (p : Pool ι) (tx : STx ι)
    (hk : p.accepted.any (fun e => e.id == tx.id) = false) (hv : valid tx = false) :
    refSubmit valid p tx = (p, false) := by
  rw [refSubmit, ite_eq_right (by rw [hk]; exact Bool.false_ne_true), ite_eq_left (by rw [hv]; rfl)]

/-- The reference refuses a conflict (stage 5). -/
theorem refSubmit_conflict (valid : STx ι → Bool) (p : Pool ι) (tx : STx ι)
    (hk : p.accepted.any (fun e => e.id == tx.id) = false) (hv : valid tx = true)
    (hc : refConflict p tx = true) : refSubmit valid p tx = (p, false) := by
  rw [refSubmit, ite_eq_right (by rw [hk]; exact Bool.false_ne_true), ite_eq_right (by rw [hv]; decide), ite_eq_left hc]

/-- The reference admits a valid new transaction without a conflict. -/
theorem refSubmit_new (valid : STx ι → Bool) (p : Pool ι) (tx : STx ι)
    (hk : p.accepted.any (fun e => e.id == tx.id) = false) (hv : valid tx = true)
    (hc : refConflict p tx = false) :
    refSubmit valid p tx =
      ({ accepted := p.accepted ++ [tx],
         mapNextTx := p.mapNextTx ++ tx.inputs.map (fun o => (o, tx.id)) }, true) := by
  rw [refSubmit, ite_eq_right (by rw [hk]; exact Bool.false_ne_true), ite_eq_right (by rw [hv]; decide),
    ite_eq_right (by rw [hc]; exact Bool.false_ne_true)]

/-- One submission keeps the relation and the two machines agree on it. -/
theorem submit_related (valid : STx ι → Bool) (s : Store ι) (p : Pool ι) (tx : STx ι)
    (r : Related valid s p)
    (hnd : valid tx = true → tx.inputs.Nodup)
    (hid : ∀ e ∈ p.accepted, e.id = tx.id → e = tx) :
    Related valid (submit valid s tx).1 (refSubmit valid p tx).1 := by
  by_cases hk : p.accepted.any (fun e => e.id == tx.id) = true
  · -- stage 4 in the reference; the store's idempotent success
    obtain ⟨e, he, hei⟩ := List.any_eq_true.mp hk
    have heq : e = tx := hid e he (by simpa using hei)
    subst heq
    have hv : valid e = true := r.accepted_valid e he
    have howned : ∀ o ∈ e.inputs, spender s o = some e.id := by
      intro o ho
      have hm : (o, e.id) ∈ s.spent := by
        rw [r.spent_eq, r.index_eq]
        exact List.mem_flatMap.mpr ⟨e, he, List.mem_map.mpr ⟨o, ho, rfl⟩⟩
      have hkeys : (s.spent.map (·.1)).Nodup := r.spent_eq ▸ r.keys_nodup
      simp [spender, find_of_mem_nodup hkeys hm]
    have hrec : e.id ∈ s.records := by
      rw [r.records_eq]; exact List.mem_map.mpr ⟨e, he, rfl⟩
    have hsp := spendTx_all s s e e.inputs (spendAll_owned s e.id e.inputs r.no_conflicting howned)
    rw [submit_known valid s s e hv hsp hrec, refSubmit_known valid p e hk]
    exact r
  · have hk' : p.accepted.any (fun e => e.id == tx.id) = false := by simpa using hk
    have hnotrec : tx.id ∉ s.records := by
      rw [r.records_eq]
      intro hm
      obtain ⟨e, he, hei⟩ := List.mem_map.mp hm
      have h1 : p.accepted.any (fun e => e.id == tx.id) = true :=
        List.any_eq_true.mpr ⟨e, he, by simp [hei]⟩
      rw [hk'] at h1; exact Bool.false_ne_true h1
    by_cases hv : valid tx = true
    · have hnd' := hnd hv
      have hown : ∀ kv ∈ s.spent, kv.1 ∈ tx.inputs → kv.2 ≠ tx.id := by
        intro kv hm _ heq
        obtain ⟨t, ht, hti, _⟩ := owner_accepted r hm
        have h1 : p.accepted.any (fun e => e.id == tx.id) = true :=
          List.any_eq_true.mpr ⟨t, ht, by simp [hti, heq]⟩
        rw [hk'] at h1; exact Bool.false_ne_true h1
      have hsa := spendAll_eq s tx.id tx.inputs r.no_conflicting hnd' hown
      have hfree_iff : ∀ o, isFree s o = !p.mapNextTx.any (fun kv => kv.1 == o) := by
        intro o; simp [isFree, r.spent_eq]
      by_cases hc : refConflict p tx = true
      · -- the conflict stage refuses; the store's rollback restores every entry
        have hall : tx.inputs.all (isFree s) = false := by
          unfold refConflict at hc
          obtain ⟨o, ho, hoc⟩ := List.any_eq_true.mp hc
          exact List.all_eq_false.mpr ⟨o, ho, by simp [hfree_iff, hoc]⟩
        have key : (s.spent ++ (tx.inputs.filter (isFree s)).map (fun o => (o, tx.id))).filter
            (fun kv => !((tx.inputs.filter (isFree s)).contains kv.1 && kv.2 == tx.id)) = s.spent := by
          rw [List.filter_append]
          have h1 : s.spent.filter (fun kv => !((tx.inputs.filter (isFree s)).contains kv.1 &&
              kv.2 == tx.id)) = s.spent := by
            apply List.filter_eq_self.mpr
            intro kv hm
            by_cases hin : kv.1 ∈ tx.inputs
            · simp [hown kv hm hin]
            · simp [List.mem_filter, hin]
          have h2 : ((tx.inputs.filter (isFree s)).map (fun o => (o, tx.id))).filter
              (fun kv => !((tx.inputs.filter (isFree s)).contains kv.1 && kv.2 == tx.id)) = [] := by
            apply List.filter_eq_nil_iff.mpr
            intro kv hm
            obtain ⟨o, ho, rfl⟩ := List.mem_map.mp hm
            have ho' := List.mem_filter.mp ho
            simp [ho'.1, ho'.2]
          rw [h1, h2, List.append_nil]
        have hroll : unspendAll { s with spent := s.spent ++
            (tx.inputs.filter (isFree s)).map (fun o => (o, tx.id)) } tx.id
            (tx.inputs.filter (isFree s)) = s := by
          rw [unspendAll_eq]
          show ({ s with
              spent := (s.spent ++ (tx.inputs.filter (isFree s)).map (fun o => (o, tx.id))).filter
                (fun kv => !((tx.inputs.filter (isFree s)).contains kv.1 && kv.2 == tx.id)) } : Store ι) = s
          rw [key]
        rw [hall] at hsa
        have hsp := spendTx_fail s _ tx _ hsa
        rw [hroll] at hsp
        rw [submit_fail valid s s tx hv hsp, refSubmit_conflict valid p tx hk' hv hc]
        exact r
      · -- both admit and index the inputs
        have hc' : refConflict p tx = false := by simpa using hc
        have hallfree : ∀ o ∈ tx.inputs, isFree s o = true := by
          intro o ho
          have h1 : p.mapNextTx.any (fun kv => kv.1 == o) = false := by
            unfold refConflict at hc'
            have h2 := List.any_eq_false.mp hc' o ho
            cases hb : p.mapNextTx.any (fun kv => kv.1 == o) with
            | false => rfl
            | true => exact absurd hb h2
          simp [hfree_iff, h1]
        have hfilt : tx.inputs.filter (isFree s) = tx.inputs := List.filter_eq_self.mpr hallfree
        have hallt : tx.inputs.all (isFree s) = true := List.all_eq_true.mpr hallfree
        rw [hfilt, hallt] at hsa
        have hsp := spendTx_all s _ tx _ hsa
        rw [submit_new valid s _ tx hv hsp hnotrec, refSubmit_new valid p tx hk' hv hc']
        refine ⟨?_, ?_, ?_, r.no_conflicting, ?_, ?_, ?_⟩
        · simp [r.spent_eq]
        · simp [r.records_eq]
        · simp [r.unmined_eq]
        · simp [r.index_eq]
        · have hk1 : (tx.inputs.map (fun o => (o, tx.id))).map (·.1) = tx.inputs := by
            rw [List.map_map]; exact List.map_id _
          simp only [List.map_append, hk1]
          refine List.nodup_append.mpr ⟨r.keys_nodup, hnd', ?_⟩
          intro a ha b hb hab
          subst hab
          obtain ⟨kv, hkv, rfl⟩ := List.mem_map.mp ha
          have h1 := hallfree kv.1 hb
          rw [hfree_iff] at h1
          have h3 : p.mapNextTx.any (fun kv' => kv'.1 == kv.1) = true :=
            List.any_eq_true.mpr ⟨kv, hkv, by simp⟩
          rw [h3] at h1
          exact absurd h1 (by decide)
        · intro e he
          rcases List.mem_append.mp he with h | h
          · exact r.accepted_valid e h
          · simp at h; subst h; exact hv
    · have hv' : valid tx = false := by simpa using hv
      rw [submit_invalid valid s tx hv', refSubmit_invalid valid p tx hk' hv']
      exact r

/-- The runs keep the relation from any related pair. `hid` says the
transaction id determines the body across the run and the pool: the txid is
the body's double SHA-256 (`src/primitives/transaction.cpp:79-81` at 6504a3af
[SRC]), so this is the no-collision reading of the hash. -/
theorem run_related (valid : STx ι → Bool) (txs : List (STx ι)) :
    ∀ (s : Store ι) (p : Pool ι), Related valid s p →
    (∀ tx ∈ txs, valid tx = true → tx.inputs.Nodup) →
    (∀ a ∈ p.accepted ++ txs, ∀ b ∈ p.accepted ++ txs, a.id = b.id → a = b) →
    Related valid (storeRun valid s txs) (refRun valid p txs) := by
  induction txs with
  | nil => intro s p r _ _; exact r
  | cons tx txs ih =>
    intro s p r hnd hid
    have r1 := submit_related valid s p tx r (hnd tx List.mem_cons_self)
      (fun e he heq => hid e (List.mem_append_left _ he) tx (by simp) heq)
    refine ih _ _ r1 (fun t ht => hnd t (List.mem_cons_of_mem _ ht)) ?_
    have hsub : ∀ a ∈ (refSubmit valid p tx).1.accepted ++ txs, a ∈ p.accepted ++ tx :: txs := by
      intro a ha
      rcases List.mem_append.mp ha with h | h
      · unfold refSubmit at h
        split at h
        · exact List.mem_append_left _ h
        · split at h
          · exact List.mem_append_left _ h
          · split at h
            · exact List.mem_append_left _ h
            · rcases List.mem_append.mp h with h | h
              · exact List.mem_append_left _ h
              · simp at h; subst h; simp
      · exact List.mem_append_right _ (List.mem_cons_of_mem _ h)
    exact fun a ha b hb => hid a (hsub a ha) b (hsub b hb)

/-- In a related state the store's mempool is its records. -/
theorem kept_of_related {valid : STx ι → Bool} {s : Store ι} {p : Pool ι}
    (r : Related valid s p) : kept s = p.accepted.map (·.id) := by
  unfold kept
  rw [r.no_conflicting, ← r.records_eq]
  apply List.filter_eq_self.mpr
  intro x hm
  have hx : x ∈ s.unmined := by rw [r.unmined_eq, ← r.records_eq]; exact hm
  simp [hx]

/-- **The earlier spend wins on both nodes (#90), sequential arrival, no reorg.**
For every arrival order `txs` of a finite list, starting from an empty store and
an empty pool, the transactions Teranode's store keeps (its unmined,
non-conflicting records) are exactly the transactions the reference's
earliest-seen rule accepts, in the same order.

Hypotheses, exactly: one oracle `valid` decides every check other than the
spent-output check, the same on both nodes and independent of arrival order
(the same parameters, the same tip, no reorg; a child arriving before its
parent is outside, since its verdict depends on order); a transaction the
oracle passes has distinct inputs (`bad-txns-inputs-duplicate`,
`src/validation.cpp:632-635` at 6504a3af [SRC]); the id
determines the body (`hid`). Sequential arrival means each submission's store
calls finish before the next begins: the per-output spend is atomic per
record, the whole transaction is not (one ordered group of per-record UDF
calls, `spend.go:407-411,461`), and `concurrent_both_refused` is the
interleaving where the equality fails, under the condition
`concurrent_outcome_iff` states.
[SRC] Teranode `stores/utxo/aerospike/teranode.lua:284-466`,
`stores/utxo/aerospike/spend.go:387-548`, `services/validator/Validator.go:1105-1257`
at 4edb60a4; bitcoin-sv `src/validation.cpp:1142-1152`,
`src/txmempool.cpp:298-304` at 6504a3af. -/
theorem accepted_eq_mempool (valid : STx ι → Bool) (txs : List (STx ι))
    (hnd : ∀ tx ∈ txs, valid tx = true → tx.inputs.Nodup)
    (hid : ∀ a ∈ txs, ∀ b ∈ txs, a.id = b.id → a = b) :
    kept (storeRun valid {} txs) = (refRun valid {} txs).accepted.map (·.id) :=
  kept_of_related (run_related valid txs {} {} (related_empty valid) hnd (by simpa using hid))

/-! ## The bridge to BsvChain's mempool -/

/-- BsvChain's outpoint as the comparison's output. -/
def toOut (o : OutPoint) : Out Bytes := ⟨o.hash, o.index⟩

/-- The projection keeps outpoints apart. -/
theorem toOut_inj {a b : OutPoint} : toOut a = toOut b ↔ a = b := by
  cases a; cases b; simp [toOut]

/-- BsvChain's transaction as the comparison's: its txid and its spent outputs. -/
def proj (tx : Tx) : STx Bytes :=
  ⟨BsvScript.Sighash.txid tx, tx.inputs.map (fun i => toOut (OutPoint.ofInput i))⟩

/-- BsvChain's accepted pool as the comparison's. -/
def toPool (p : Mempool) : Pool Bytes :=
  ⟨p.accepted.map (fun e => proj e.tx), p.mapNextTx.map (fun kv => (toOut kv.1, kv.2))⟩

/-- The reference model's conflict test IS BsvChain's stage-5 predicate
`hasPoolConflict` on a final request when the held pool is empty (the held
locks are the reference's `CTimeLockedMempool`, which Teranode has no
counterpart of). [SRC] `src/txmempool.cpp:2257-2280` and
`src/validation.cpp:1147-1152` at 6504a3af. -/
theorem conflict_bridge (p : Mempool) (tx : Tx) (hnf : p.nonFinal = []) :
    hasPoolConflict p tx true = refConflict (toPool p) (proj tx) := by
  have hnc : nonFinalConflicts p tx = [] := by simp [nonFinalConflicts, hnf]
  simp only [hasPoolConflict, hnc, List.isEmpty_nil, Bool.not_true, Bool.and_false,
    Bool.false_and, Bool.or_false, refConflict, toPool, proj, List.any_map]
  apply List.any_congr rfl; intro i
  simp only [Function.comp_apply]
  apply List.any_congr rfl; intro kv
  simp only [Function.comp_apply]
  rw [Bool.eq_iff_iff, beq_iff_eq, beq_iff_eq, toOut_inj]

/-- BsvChain's complete `accept` refuses a request the reference model calls a
conflict, with the source's code and reason, and keeps the accepted pool,
once the P2P filter lets the request through and the ordered earlier stages
pass (they may otherwise refuse it for another reason).
[SRC] `src/validation.cpp:1031-1152` at 6504a3af. -/
theorem accept_conflict_refuses (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (obs : DetectorObservation) (request : TxRequest) (status : FinalityStatus)
    (hnf : p.nonFinal = [])
    (hconf : refConflict (toPool p) (proj request.tx) = true)
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
    (accept p utxo cfg ctx lists oracle obs request).1.accepted = p.accepted := by
  intro c w ready hr hs hf hk
  have hpc : hasPoolConflict p request.tx true = true := by rw [conflict_bridge p _ hnf]; exact hconf
  have hnc : nonFinalConflicts p request.tx = [] := by simp [nonFinalConflicts, hnf]
  have conflict : request.tx.inputs.any (fun i => p.mapNextTx.any
      (fun kv => kv.1 == OutPoint.ofInput i)) = true := by
    simp only [hasPoolConflict, hnc, List.isEmpty_nil, Bool.not_true, Bool.and_false,
      Bool.false_and, Bool.or_false] at hpc
    exact hpc
  have stop := Properties.Mempool.admission_conflict_rejects c ctx lists oracle w w w ready ready
    hr hs hf hk conflict
  simp only [accept, acceptWithTrace, submitted, Bool.false_eq_true, ↓reduceIte]
  rw [stop]
  simp only [finishAdmission]
  split <;> simp_all [ready, w]

/-- The submission request the comparison drives: an RPC submission at `t`. -/
def acceptRequest (t : Int) (tx : Tx) : TxRequest := { tx, acceptTime := t }

/-- BsvChain's complete `accept` over an arrival order, at one fixed context. -/
def acceptRun (utxo : UtxoSet) (cfg : NodeConfig) (ctx : AdmissionContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (obs : DetectorObservation) (t : Int) :
    Mempool → List Tx → Mempool
  | p, [] => p
  | p, tx :: txs => acceptRun utxo cfg ctx lists oracle obs t
      (accept p utxo cfg ctx lists oracle obs (acceptRequest t tx)).1 txs

/-- `acceptRun` over a concatenation: the trailing part runs from the pool the
leading part leaves. -/
theorem acceptRun_append (utxo : UtxoSet) (cfg : NodeConfig) (ctx : AdmissionContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (obs : DetectorObservation) (t : Int)
    (l₁ l₂ : List Tx) : ∀ (p : Mempool),
    acceptRun utxo cfg ctx lists oracle obs t p (l₁ ++ l₂) =
      acceptRun utxo cfg ctx lists oracle obs t (acceptRun utxo cfg ctx lists oracle obs t p l₁) l₂ := by
  induction l₁ with
  | nil => intro p; rfl
  | cons tx l₁ ih => intro p; simp only [List.cons_append, acceptRun]; exact ih _

/-- `refRun` over a concatenation, the same way. -/
theorem refRun_append (valid : STx ι → Bool) (l₁ l₂ : List (STx ι)) : ∀ (p : Pool ι),
    refRun valid p (l₁ ++ l₂) = refRun valid (refRun valid p l₁) l₂ := by
  induction l₁ with
  | nil => intro p; rfl
  | cons tx l₁ ih => intro p; simp only [List.cons_append, refRun]; exact ih _

/-- **The remaining obligation, stated and NOT asserted, for one arrival order
`txs`.** BsvChain's complete `accept` behaves, on the accepted pool, as the
earliest-seen rule with the oracle `valid` along the run of `txs`: for each
submission `tx` of `txs`, on the pool `acceptRun` built from the submissions
before it (`pre`), with an empty held pool, the submission leaves the held
pool empty and moves the accepted pool and its spent index exactly as
`refSubmit` does. It is quantified over the run, not over every pool and
every transaction: `valid` is one pool-independent verdict, and `accept`'s
verdict on a transaction depends on the pool (a child of a pool entry is
admitted on a pool holding its parent and orphaned on the empty one), so the
form over every pool fails as soon as `accept` admits a child of a pool entry.
A run that holds a non-final transaction (`accept` puts it in the held pool:
`BsvChain.stageFinality`, `BsvChain.insertNonFinal`) fails the held-pool
conjunct, so the obligation is false for it: it speaks of runs whose
transactions are final. What it asks beyond
`accept_conflict_refuses`: that every stage other than the conflict stage
(fee against the rolling minimum, ancestors, size limiting, scripts) gives
`valid`'s verdict on each pool of the run, and that the commit appends one
entry and indexes its inputs. -/
def AcceptIsEarliestSeen (utxo : UtxoSet) (cfg : NodeConfig) (ctx : AdmissionContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (obs : DetectorObservation) (t : Int)
    (valid : STx Bytes → Bool) (txs : List Tx) : Prop :=
  ∀ (pre : List Tx) (tx : Tx) (post : List Tx), txs = pre ++ tx :: post →
    (acceptRun utxo cfg ctx lists oracle obs t {} pre).nonFinal = [] →
    (accept (acceptRun utxo cfg ctx lists oracle obs t {} pre) utxo cfg ctx lists oracle obs
        (acceptRequest t tx)).1.nonFinal = [] ∧
    toPool (accept (acceptRun utxo cfg ctx lists oracle obs t {} pre) utxo cfg ctx lists oracle obs
        (acceptRequest t tx)).1 =
      (refSubmit valid (toPool (acceptRun utxo cfg ctx lists oracle obs t {} pre)) (proj tx)).1

/-- Under the obligation for `txs`, BsvChain's run projects onto the reference
model's run, submission by submission: by induction on the suffix still to
run, from any prefix `pre` on which the projection already holds. -/
theorem acceptRun_toPool (utxo : UtxoSet) (cfg : NodeConfig) (ctx : AdmissionContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (obs : DetectorObservation) (t : Int)
    (valid : STx Bytes → Bool) (txs : List Tx)
    (h : AcceptIsEarliestSeen utxo cfg ctx lists oracle obs t valid txs) :
    ∀ (rest pre : List Tx), txs = pre ++ rest →
      (acceptRun utxo cfg ctx lists oracle obs t {} pre).nonFinal = [] →
      toPool (acceptRun utxo cfg ctx lists oracle obs t {} pre) = refRun valid {} (pre.map proj) →
      toPool (acceptRun utxo cfg ctx lists oracle obs t {} txs) = refRun valid {} (txs.map proj) := by
  intro rest
  induction rest with
  | nil => intro pre heq _ hp; rw [heq, List.append_nil]; exact hp
  | cons tx rest ih =>
    intro pre heq hnf hp
    obtain ⟨hnf', hstep⟩ := h pre tx rest heq hnf
    refine ih (pre ++ [tx]) (by rw [heq]; simp) ?_ ?_
    · rw [acceptRun_append]; simp only [acceptRun]; exact hnf'
    · rw [acceptRun_append, List.map_append, refRun_append, ← hp]
      simp only [acceptRun, refRun, List.map_cons, List.map_nil]
      exact hstep

/-- **#90 against BsvChain's complete `accept`, under the remaining
obligation.** If `AcceptIsEarliestSeen` holds for the arrival order `txs`, the
store's mempool after `txs` equals the txids BsvChain's `accept` keeps after
`txs`, from empty pools. [SRC] as `accepted_eq_mempool`. -/
theorem accepted_eq_accept_of_earliestSeen (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (obs : DetectorObservation) (t : Int) (valid : STx Bytes → Bool) (txs : List Tx)
    (h : AcceptIsEarliestSeen utxo cfg ctx lists oracle obs t valid txs)
    (hnd : ∀ tx ∈ txs.map proj, valid tx = true → tx.inputs.Nodup)
    (hid : ∀ a ∈ txs.map proj, ∀ b ∈ txs.map proj, a.id = b.id → a = b) :
    kept (storeRun valid {} (txs.map proj)) =
      (acceptRun utxo cfg ctx lists oracle obs t {} txs).accepted.map
        (fun e => BsvScript.Sighash.txid e.tx) := by
  rw [accepted_eq_mempool valid _ hnd hid]
  have hrun := acceptRun_toPool utxo cfg ctx lists oracle obs t valid txs h txs []
    (by simp) rfl rfl
  rw [← hrun]
  simp [toPool, proj]

/-! ## The witness of concurrent arrival -/

/-- A store event: one output's spend inside a batch, or the end of one
submission's `Spend` call (its rollback or its record). -/
inductive Ev (ι : Type) where
  | spend (tx : STx ι) (o : Out ι)
  | finish (tx : STx ι)
  deriving DecidableEq, Repr

/-- One submission in flight: the outputs it has spent so far and whether any
spend failed (`resolveSpendCompletions`, `spend.go:574-625`). [SRC] 4edb60a4. -/
structure Flight (ι : Type) where
  id : ι
  oks : List (Out ι) := []
  failed : Bool := false
  deriving DecidableEq, Repr

def flightOf (fl : List (Flight ι)) (id : ι) : Flight ι :=
  (fl.find? (fun f => f.id == id)).getD { id }

def dropFlight (fl : List (Flight ι)) (id : ι) : List (Flight ι) :=
  fl.filter (fun f => f.id != id)

/-- The store under interleaved submissions, every transaction having passed
the oracle (the validator checks before it spends, `Validator.go:868-1104`).
A spend event is one output's UDF call; a finish event is the end of that
transaction's `Spend` call: the rollback of its successful spends after a
failure (`spend.go:513-527`), else its record (`Validator.go:1105`). Inputs of
different records run as separate UDF calls. Within one batch the duplicate
filter refuses every later claim on a claimed outpoint (`spend.go:692`,
`stores/utxo/duplicate_spend.go:15-52`), so the earlier group wins both
outputs. `bothLose` needs the two groups in two batches in flight together
(`stores/utxo/aerospike/aerospike.go:514-516`; a batch closes at 100 items or
100 ms, `settings/settings.go:485-486`) [SRC] 4edb60a4; the batcher library's
dispatch is read at go-batcher v2.0.6 (`965d11dea6d78ec244280fa9f941c2a263a30b02`,
the version Teranode's `go.mod:198` requires): `SetMaxConcurrent` starts a
pool of that many workers (`batcher.go:553-579`), a background flush hands
each batch to the pool (`:638-662`), and cross-batch completion order is not
guaranteed (`:336-345`) [SRC]. A spend event here is a claim reaching its
record; a claim the filter refuses is the same event placed after the
earlier claim, with the same outcome. -/
def evStep (st : Store ι × List (Flight ι)) : Ev ι → Store ι × List (Flight ι)
  | .spend tx o =>
    let r := spendOne false st.1 tx.id o
    let f := flightOf st.2 tx.id
    (r.1, dropFlight st.2 tx.id ++
      [{ f with oks := if r.2 then f.oks ++ [o] else f.oks, failed := f.failed || !r.2 }])
  | .finish tx =>
    let f := flightOf st.2 tx.id
    if f.failed then (unspendAll st.1 tx.id f.oks, dropFlight st.2 tx.id)
    else if st.1.records.contains tx.id then (st.1, dropFlight st.2 tx.id)
    else ({ st.1 with records := st.1.records ++ [tx.id], unmined := st.1.unmined ++ [tx.id] },
      dropFlight st.2 tx.id)

def concurrentRun (s : Store ι) (evs : List (Ev ι)) : Store ι :=
  (evs.foldl evStep (s, [])).1

/-- Two outputs of two different parent transactions, so two records. -/
def outF1 : Out Nat := ⟨1, 0⟩
def outF2 : Out Nat := ⟨2, 0⟩
/-- `A` spends both outputs; `B` spends them in the other input order. -/
def txA : STx Nat := ⟨10, [outF1, outF2]⟩
def txB : STx Nat := ⟨11, [outF2, outF1]⟩

/-- The interleaving: each transaction wins one record, loses the other, and
rolls back. -/
def bothLose : List (Ev Nat) :=
  [.spend txA outF1, .spend txB outF2, .spend txA outF2, .spend txB outF1, .finish txA, .finish txB]

/-- Every interleaving of two event lists, each list kept in its own order:
the left list's head goes after some prefix of the right list. -/
def interleavings {α : Type} : List α → List α → List (List α)
  | [], ys => [ys]
  | x :: xs, ys => (List.range (ys.length + 1)).flatMap (fun k =>
      (interleavings xs (ys.drop k)).map (fun r => ys.take k ++ x :: r))

/-- Every schedule of `A` and `B`: each transaction's two claims in either
order, then its finish, and the two transactions interleaved freely (80
schedules). The claims of one transaction reach their two records in no fixed
order, since each record is its own UDF call. -/
def schedulesAB : List (List (Ev Nat)) :=
  [[Ev.spend txA outF1, .spend txA outF2], [.spend txA outF2, .spend txA outF1]].flatMap (fun a =>
    [[Ev.spend txB outF2, .spend txB outF1], [.spend txB outF1, .spend txB outF2]].flatMap (fun b =>
      interleavings (a ++ [.finish txA]) (b ++ [.finish txB])))

/-- The position of an event in a schedule. -/
def posOf (e : Ev Nat) : List (Ev Nat) → Nat
  | [] => 0
  | x :: xs => if x = e then 0 else posOf e xs + 1

/-- `b`'s claim on `o` reaches the record after `a`'s claim and before `a`'s
finish (its rollback), so while `a` holds `o`. -/
def claimsWhileHeld (evs : List (Ev Nat)) (a b : STx Nat) (o : Out Nat) : Bool :=
  decide (posOf (.spend a o) evs < posOf (.spend b o) evs) &&
    decide (posOf (.spend b o) evs < posOf (.finish a) evs)

/-- **The exact condition of the empty outcome.** Each transaction holds one
output while the other's claim on it lands: `A` holds `F1` against `B` and
`B` holds `F2` against `A`, or the reverse. -/
def bothHeld (evs : List (Ev Nat)) : Bool :=
  (claimsWhileHeld evs txA txB outF1 && claimsWhileHeld evs txB txA outF2) ||
    (claimsWhileHeld evs txB txA outF1 && claimsWhileHeld evs txA txB outF2)

/-- **The condition, over every schedule (#90).** Of the 80 schedules of `A`
and `B`, the store keeps neither exactly when `bothHeld` holds, and it never
keeps both. A losing claim that lands after the holder's rollback succeeds,
so the later transaction is kept then, not neither.

What meets `bothHeld` on each backend at 4edb60a4 [SRC]:
* Aerospike (the model): within one batch the duplicate filter decides by
  batch order, and a transaction's inputs are one ordered group
  (`spend.go:407-411,461,692`), so the earlier group wins both outputs. The
  condition needs, for at least one output, the two claims in two batches in
  flight together: the two groups in two batches, or one group split at the
  size cap across two (`batcher.go:743-790` at go-batcher v2.0.6), each batch
  handed to the worker pool (`aerospike.go:514-516`), with the later batch's
  claim reaching the record before the other; and each losing claim landing before the
  holder's rollback (`spend.go:513-527`).
* SQL, so SQLite under `SETTINGS_CONTEXT=test`: each input is enqueued from
  its own goroutine (`sql.go:2104-2128`) into a batcher whose batches run one
  at a time (`sql.go:223`, background false), and the duplicate filter runs in
  each batch (`sql.go:2275`). A claim's arrival order is its order in that
  one stream, in one batch or across two, and the rollback follows the
  transaction's last reply (`sql.go:2198-2207`). The condition is the stream
  order of the four claims and the two rollbacks.
[M] model statement read from source, unobserved. -/
theorem concurrent_outcome_iff :
    ∀ evs ∈ schedulesAB, (kept (concurrentRun {} evs) = [] ↔ bothHeld evs = true) ∧
      (kept (concurrentRun {} evs)).length ≤ 1 := by
  decide +kernel

/-- **The concurrent witness (#90).** Under its condition `bothHeld`, stated
as a hypothesis over every schedule of `A` and `B`, the store keeps NEITHER
conflicting transaction and both outputs are unspent; `bothLose` is one such
schedule. The reference keeps exactly one under either serial order: its
detector inserts all of a transaction's inputs under one mutex, so of two
valid concurrent double spends the earlier continues and the other is refused
(`src/txn_double_spend_detector.cpp:11-57`, `src/validation.cpp:1484-1494` at
6504a3af [SRC]; `BsvChain.stageDetector`). Two transactions over two outputs
in two records is the smallest case: with one shared output the per-output
atomic spend decides, as `one_output_earlier_wins` checks. What meets the
condition on Teranode's two backends is in `concurrent_outcome_iff`'s
docstring: on Aerospike two batches in flight together, never one batch. [M]
model witness read from source, unobserved; the regtest scenario
`corpus/scenarios/2026-10-14-conflicting-spends-order.md` is its run, pending #66. -/
theorem concurrent_both_refused :
    (∀ evs ∈ schedulesAB, bothHeld evs = true →
      kept (concurrentRun {} evs) = [] ∧ (concurrentRun {} evs).spent = []) ∧
    bothLose ∈ schedulesAB ∧ bothHeld bothLose = true ∧
    (refRun (fun _ => true) {} [txA, txB]).accepted.map (·.id) = [10] ∧
    (refRun (fun _ => true) {} [txB, txA]).accepted.map (·.id) = [11] := by
  decide +kernel

/-- Serial schedules of the same two transactions agree with the reference. -/
theorem serial_schedules_agree :
    kept (concurrentRun {} [.spend txA outF1, .spend txA outF2, .finish txA,
      .spend txB outF2, .spend txB outF1, .finish txB]) = [10] ∧
    kept (concurrentRun {} [.spend txB outF2, .spend txB outF1, .finish txB,
      .spend txA outF1, .spend txA outF2, .finish txA]) = [11] := by
  decide

def txC : STx Nat := ⟨20, [outF1]⟩
def txD : STx Nat := ⟨21, [outF1]⟩

/-- With one shared output and one input each, every schedule of the two
transactions (a spend before its own finish) keeps exactly one of them, the
spend that reached the record before the other. -/
theorem one_output_earlier_wins :
    [[Ev.spend txC outF1, .spend txD outF1, .finish txC, .finish txD],
     [.spend txC outF1, .spend txD outF1, .finish txD, .finish txC],
     [.spend txC outF1, .finish txC, .spend txD outF1, .finish txD],
     [.spend txD outF1, .spend txC outF1, .finish txC, .finish txD],
     [.spend txD outF1, .spend txC outF1, .finish txD, .finish txC],
     [.spend txD outF1, .finish txD, .spend txC outF1, .finish txC]].map
      (fun evs => kept (concurrentRun {} evs)) = [[20], [20], [20], [21], [21], [21]] := by
  decide

/-! ## The reorg witness -/

/-- `SetConflicting` sets or clears the record bin (`conflicting.go:42`,
`teranode.lua:1072-1095`). [SRC] 4edb60a4. -/
def setConflicting (s : Store ι) (ids : List ι) (v : Bool) : Store ι :=
  if v then { s with conflicting := s.conflicting ++ ids.filter (fun i => !s.conflicting.contains i) }
  else { s with conflicting := s.conflicting.filter (fun i => !ids.contains i) }

/-- A block's transaction validated with `CreateConflicting` true
(`services/subtreevalidation/Server.go:905,961`): a refused spend creates the
record marked conflicting with no spends (`Validator.go:1155,1169-1217`), and
the subtree lists it (`SubtreeValidation.go:838`). [SRC] 4edb60a4. -/
def submitBlockTx (s : Store ι) (tx : STx ι) : Store ι :=
  let r := spendTx false s tx
  if r.2 then { r.1 with records := r.1.records ++ [tx.id] }
  else { r.1 with records := r.1.records ++ [tx.id], conflicting := r.1.conflicting ++ [tx.id] }

/-- `ProcessConflicting` for one winner and its counter-conflicting losers
(`process_conflicting.go:117-125`, the five phases; locks not modeled):
mark the losers, unspend their inputs, spend the winner ignoring the marks,
clear the winner's mark. [SRC] 4edb60a4. -/
def processConflicting (s : Store ι) (w : STx ι) (losers : List (STx ι)) : Store ι :=
  let s := setConflicting s (losers.map (·.id)) true
  let s := losers.foldl (fun s l => unspendAll s l.id l.inputs) s
  let s := (spendAll true s w.id w.inputs).1
  setConflicting s [w.id] false

/-- `ReverseProcessConflicting` (`process_conflicting.go:420-458`): mark the
demoted transaction, unspend it, spend the counters again, clear their marks.
[SRC] 4edb60a4. -/
def reverseProcessConflicting (s : Store ι) (d : STx ι) (counters : List (STx ι)) : Store ι :=
  let s := setConflicting s [d.id] true
  let s := unspendAll s d.id d.inputs
  let s := counters.foldl (fun s c => (spendAll true s c.id c.inputs).1) s
  setConflicting s (counters.map (·.id)) false

/-- `SetMinedMulti` on the longest chain clears `unminedSince`;
`MarkTransactionsOnLongestChain` with false stamps it when absent
(`longest_chain.go:49`). [SRC] 4edb60a4. -/
def setOnLongestChain (s : Store ι) (id : ι) (on : Bool) : Store ι :=
  if on then { s with unmined := s.unmined.filter (· != id) }
  else if s.unmined.contains id then s else { s with unmined := s.unmined ++ [id] }

/-- The reference's block connection as the conflict rule sees it: mined
entries and entries spending an output a block transaction spends leave the
pool (`BsvChain.removeForBlock`, `src/txmempool.cpp:1025-1173` at 6504a3af
[SRC]; descendants are removed too there, and the witness has none). -/
def refConnect (p : Pool ι) (block : List (STx ι)) : Pool ι :=
  let keep := p.accepted.filter (fun e => !block.any (fun b =>
    b.id == e.id || e.inputs.any (fun o => b.inputs.contains o)))
  { accepted := keep, mapNextTx := keep.flatMap (fun t => t.inputs.map (fun o => (o, t.id))) }

/-- The reference's disconnection: the block's transactions re-admitted on the
cleared pool, then the saved entries re-added (`BsvChain.addToMempoolForReorg`,
`src/txmempool.cpp:2283-2443` at 6504a3af [SRC]). -/
def refDisconnect (valid : STx ι → Bool) (p : Pool ι) (block : List (STx ι)) : Pool ι :=
  let q := refRun valid {} block
  let acc := p.accepted.foldl (fun acc e =>
    if acc.any (fun x => x.id == e.id) then acc else acc ++ [e]) q.accepted
  { accepted := acc, mapNextTx := acc.flatMap (fun t => t.inputs.map (fun o => (o, t.id))) }

def outF : Out Nat := ⟨1, 0⟩
/-- `A` spends `F:0` in the mempool; `B` spends it in a block. -/
def rA : STx Nat := ⟨30, [outF]⟩
def rB : STx Nat := ⟨31, [outF]⟩

/-- Teranode: `A` admitted; the block with `B` validated (`B` created
conflicting), connected (the block marked mined, `SubtreeProcessor.go:5253-5259`,
then `ProcessConflicting`, `:5272` from `moveForwardBlock` `:5768`), then moved
back (`ReverseProcessConflicting`, `SubtreeProcessor.go:4205`, then marked off
the longest chain). [SRC] 4edb60a4. -/
def teranodeReorg : Store Nat :=
  let s := (submit (fun _ => true) {} rA).1
  let s := submitBlockTx s rB
  let s := processConflicting (setOnLongestChain s rB.id true) rB [rA]
  setOnLongestChain (reverseProcessConflicting s rB [rA]) rB.id false

/-- The reference: `A` admitted; the block with `B` connected; disconnected. -/
def referenceReorg : Pool Nat :=
  let p := refRun (fun _ => true) {} [rA]
  let p := refConnect p [rB]
  refDisconnect (fun _ => true) p [rB]

/-- **The reorg witness (#90).** After a block that double-spends a mempool
transaction is connected and then disconnected, Teranode's store keeps the
earlier mempool spender `A` (its mark cleared, `F:0` spent by it again) and
marks the block's `B` conflicting, while the reference re-admits `B` and has
dropped `A` at the connection. The marks are reversed, but not where the
reference re-admits. Teranode at the tag also leaves the restored `A` out of
block assembly until it is resubmitted (`SubtreeProcessor.go:4226-4251`, its
own comment) [SRC]; that holds for a reorg through `reorgBlocks` only: after
an invalidation `handleReorg` resets and reloads unmined transactions
(`BlockAssembler.go:2258-2291`); a large reorg resets without the reverse
(`:2225-2239`) [SRC] 4edb60a4. [M] model witness read from source,
unobserved. -/
theorem reorg_keeps_differ :
    kept teranodeReorg = [30] ∧ spender teranodeReorg outF = some 30 ∧
    teranodeReorg.conflicting = [31] ∧
    referenceReorg.accepted.map (·.id) = [31] := by
  decide

end BsvChain.Teranode
