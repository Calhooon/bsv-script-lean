import BsvChain.Utxo
import BsvChain.Properties.Mempool

/-!
# Teranode's record lifetimes against the reference's expiry and maturity (#92)

[M] 2026-10-15 (#92). How long a node keeps an unconfirmed transaction,
and when a coinbase output becomes spendable, decide what a wallet can rely
on. This module states the lifetime marks of Teranode's UTXO store as
transitions on one record and compares them with the reference's expiry and
coinbase maturity as the chain layer already has them; the size eviction
(`TrimToSize`, #62's `BsvChain.trimToSize`) is owed.

The store side is Teranode v0.16.0 at
`4edb60a40c6628ff0ef60231c2628efd7103fde5` (`docs/PROVENANCE.md` §1a), read
at the tag: the marks `stores/utxo/fields/fields.go:44` (`locked`), `:50`
(`spendingHeight`), `:72` (`deleteAtHeight`), `:79` (`unminedSince`), `:83`
(`preserveUntil`); the record's reading `stores/utxo/meta/data.go:61-64`
(`UnminedSince`, set means unmined on the longest chain); the interface
`stores/utxo/Interface.go:493-501` (`PreserveTransactions`,
`ProcessExpiredPreservations`), `:567` (`SetLocked`), `:590-594`
(`MarkTransactionsOnLongestChain`); the Lua functions of
`stores/utxo/aerospike/teranode.lua` (`spendMulti` `:284-466`, `unspend`
`:484-555`, `setMined` `:558-703`, `setDeleteAtHeight` `:974-1055`,
`setConflicting` `:1072-1098`, `preserveUntil` `:1114-1142`, `setLocked`
`:1196-1222`); the create path `stores/utxo/aerospike/create.go:892-945`; the
pruner `services/pruner/worker.go:210-262` with its phases in
`stores/utxo/pruner_unmined.go:16-151`,
`stores/utxo/aerospike/aerospike.go:1108-1402` and the delete query
`stores/utxo/aerospike/pruner/pruner_service.go:577-580` [SRC].

The store is Teranode's Aerospike backend, the one #90's module models. The SQL
backend (`stores/utxo/sql/sql.go`), which the instance of record runs under
`SETTINGS_CONTEXT=test`, writes the same marks by its own statements and is
not read line by line here: its `UnsetMined` path clears `delete_at_height`
unconditionally (`stores/utxo/sql/sql.go:3597-3615`) where the Lua function
re-evaluates it. That reading is owed with the measured leg.

The reference side is bitcoin-sv v1.2.3 at
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: the expiry
`CTxMemPool::Expire` (`src/txmempool.cpp:2201-2220`) under `-mempoolexpiry`
(`DEFAULT_MEMPOOL_EXPIRY` 336 hours, `src/validation.h:91`, resolved to
seconds at `src/config.cpp:87`), as #62's `BsvChain.expire` models it; and
the coinbase maturity of `Consensus::CheckTxInputs`
(`src/validation.cpp:2617-2625`, `COINBASE_MATURITY` = 100 at
`src/consensus/consensus.h:75`), #61's `BsvChain.checkInputCoins` [SRC].

What closes:
* Removal. `prune_only_mined_or_conflicting`: in every record the store's
  transitions reach, the pruner deletes only a record that is conflicting or
  carries a block ID. So `never_mined_kept`: a record that was never mined
  and is not conflicting survives every pruner cycle at every height, however
  old its `unminedSince`. The reference removes the same transaction once its
  entry time is older than `-mempoolexpiry` (`reference_expires_old`).
  Removal iff the reference's expiry is therefore NOT a theorem: the rules
  differ, and `expiry_rules_differ` is the witness, with the scenario
  `corpus/scenarios/2026-10-15-record-lifetimes.md` for #66's cut 2. Teranode
  counts an unmined record's age in blocks from `unminedSince` and uses it
  only to preserve the record's parents (`backdated_prunable`); the reference
  counts seconds from entry and removes. A record mined, fully spent and then
  reorganized off the longest chain keeps its deletion height while unmined
  (`reorged_spent_keeps_dah`): its survival then rests on the pruner's
  parent-preservation phase.
* Maturity. `coinbase_maturity_agrees`: for a coinbase output, at every
  record the store reaches from the coinbase's creation, Teranode's coinbase
  gate refuses it as immature exactly when the reference's `checkInputCoins`
  refuses it as `bad-txns-premature-spend-of-coinbase`, given the same
  maturity (100 on every network of both pins: `defaults_maturity_agree`),
  the same coinbase height and the same spend height. This is a theorem.
* Locked. No reference transition corresponds. `locked` is the store's
  two-phase commit between the record's creation and its hand-off to block
  assembly: a spend of its outputs is refused (`locked_refuses`) and the child
  is retried (`services/validator/Validator.go:663-690`); mining clears it
  (`setMined_unlocks`). The reference commits an accepted transaction to its
  pool in one step under the pool's lock (`CommitTxToMempool`,
  `src/validation.cpp:895`), so no accepted transaction's outputs are refused
  to a child for this reason; the nearest observable is the orphan path a
  child takes while its parent is still being validated. #96's ledger has no
  row for the mark (spec/teranode-absences.md: 19 rows, none on `locked`).
* Owed. The reference's size eviction `TrimToSize` (`src/txmempool.cpp:2704`,
  #62's `BsvChain.trimToSize`) is cited and not compared here: no theorem, no
  witness, no scenario step states it.
* Out of scope: the reorg's deletion of a coinbase's descendants
  (`services/blockassembly/subtreeprocessor/SubtreeProcessor.go:4927-4964`)
  and the validator's shed unwind (`services/validator/Validator.go:2539-2540`);
  neither reads a lifetime mark.

Every retention below is a node setting (policy), never a rule of validity;
the coinbase maturity is a chain parameter on both sides (consensus).
-/

namespace BsvChain.Teranode.Lifetimes
open BsvChain BsvScript.Tx

/-! ## The settings and the record -/

/-- The store's lifetime settings. `blockHeightRetention`, `unminedTxRetention`
and `parentPreservationBlocks` are POLICY: node settings with defaults
`global_blockHeightRetention` 288 (`settings/settings.go:31-33`;
`settings.conf:782`) plus `utxostore_blockHeightRetentionAdjustment` 0
(`settings/settings.go:525`, summed at `settings/interface.go:99-108`),
`utxostore_unminedTxRetention`, default `global_blockHeightRetention/2` = 144
(`settings/settings.go:480`; the model's two defaults are independent fields,
so a setting that moves one moves the other only at the node) and
`utxostore_parentPreservationBlocks` 1440 (`settings/settings.go:481`) at
4edb60a4 [SRC]. `coinbaseMaturity` is the network's chain parameter
`CoinbaseMaturity` (go-chaincfg v1.6.2 `params.go:279` mainnet, `:463`
regtest, 100 on all six networks), a rule of validity, read by the store at
`stores/utxo/aerospike/create.go:898` [SRC].

The model is the Lua path and the full pruner cycle: POLICY switches at their
defaults, `aerospike_enable_{spend,setmined,preserve}_filter_expressions` false
(`settings/settings.go:185-187`), `pruner_skipPreserveParents` and
`pruner_skipProcessExpiredPreservations` false (`:661-662`),
`pruner_utxoDefensiveEnabled` false (`:649`) [SRC] 4edb60a4. Under the
expression writers (`stores/utxo/aerospike/spend_expressions.go:233-285`,
`stores/utxo/aerospike/set_mined_expressions.go:165-244`; selected at
`stores/utxo/aerospike/spend.go:667-668,711-713`, the spend writer only at a
batch size of 1, `stores/utxo/aerospike/set_mined.go:210-211` and
`stores/utxo/aerospike/aerospike.go:1135-1136`) the
deletion height is re-stamped, not raised, and `Inv` still holds; under the
skips phase 1 or 1b never runs (`services/pruner/worker.go:212,237`). -/
structure StoreSettings where
  blockHeightRetention : Nat := 288
  unminedTxRetention : Nat := 144
  parentPreservationBlocks : Nat := 1440
  coinbaseMaturity : Nat := 100
  deriving DecidableEq, Repr

/-- One master record's lifetime marks (record 0 of a transaction: the mined
state lives only there, `stores/utxo/aerospike/create.go:910-917`). `blocks`
is `blockIDs` (`stores/utxo/fields/fields.go:64`; the parallel heights and
subtree indexes are not needed here); `allSpent` is the master test
`totalExtraRecs == spentExtraRecs and spentUtxos == recordUtxos`
(`stores/utxo/aerospike/teranode.lua:1035-1036`); the other fields are the
bins of the same names (`stores/utxo/fields/fields.go:40,44,50,72,79,83`)
[SRC] 4edb60a4. The `creating` bin and pagination records are out of scope:
neither moves a lifetime mark of the master record. -/
structure Record where
  blocks : List Nat := []
  unminedSince : Option Nat := none
  conflicting : Bool := false
  locked : Bool := false
  allSpent : Bool := false
  deleteAtHeight : Option Nat := none
  preserveUntil : Option Nat := none
  spendingHeight : Option Nat := none
  deriving DecidableEq, Repr

/-! ## The transitions -/

/-- `setDeleteAtHeight`, the master branch: nothing with retention 0 or a
preservation; a conflicting record gets `h + retention` once; a fully spent
record with a block on the longest chain gets it (raised, never lowered);
otherwise the mark is cleared.
[SRC] stores/utxo/aerospike/teranode.lua:974-1055 at 4edb60a4. -/
def setDAH (s : StoreSettings) (r : Record) (h : Nat) : Record :=
  if s.blockHeightRetention = 0 then r
  else if r.preserveUntil.isSome then r
  else if r.conflicting then
    if r.deleteAtHeight.isNone then { r with deleteAtHeight := some (h + s.blockHeightRetention) } else r
  else if r.allSpent && !r.blocks.isEmpty && r.unminedSince.isNone then
    match r.deleteAtHeight with
    | some d =>
      if d < h + s.blockHeightRetention then { r with deleteAtHeight := some (h + s.blockHeightRetention) } else r
    | none => { r with deleteAtHeight := some (h + s.blockHeightRetention) }
  else { r with deleteAtHeight := none }

/-- The validator's create of an unmined record: `unminedSince` is the
height the validator works at (the tip plus one,
`services/validator/Validator.go:898-900`), `locked` when it goes to block
assembly (`:2147-2150`); no block, no deletion height (a conflicting record's
is stamped at the create, `deleteAtHeightFor(blockHeight)` at
`stores/utxo/aerospike/create.go:537-541,1178-1182`; the model reaches the
same marks through `createUnmined h true l` then `setConflictingUdf`). The validator refuses a
coinbase before this (`:905`).
[SRC] stores/utxo/aerospike/create.go:902-905,919-921 at 4edb60a4. -/
def createUnmined (h : Nat) (conflicting locked : Bool) : Record :=
  { unminedSince := some h, conflicting, locked }

/-- A record created already mined (block validation; the coinbase from
`processCoinbaseUtxos`, `services/blockassembly/subtreeprocessor/SubtreeProcessor.go:6183-6226`,
at the block's height): a coinbase's `spendingHeight` is its height plus the
maturity; a record with no spendable output gets `height + retention` when
retention is on.
[SRC] stores/utxo/aerospike/create.go:892-899,913-945 and
stores/utxo/aerospike/aerospike.go:688-695 at 4edb60a4. -/
def createMined (s : StoreSettings) (blockID height : Nat) (isCoinbase noSpendable : Bool) : Record :=
  { blocks := [blockID],
    spendingHeight := if isCoinbase then some (height + s.coinbaseMaturity) else none,
    deleteAtHeight :=
      if noSpendable && s.blockHeightRetention != 0 then some (height + s.blockHeightRetention) else none }

/-- `setMined`, adding a block or (`unset`, an invalidation) removing it:
with no block left `unminedSince` is the current height; with a block and
`onLongest` it is cleared; `locked` is cleared; then the deletion height is
re-evaluated at the block's height.
[SRC] stores/utxo/aerospike/teranode.lua:558-663 at 4edb60a4. -/
def setMined (s : StoreSettings) (r : Record) (blockID blockHeight current : Nat)
    (onLongest unset : Bool) : Record :=
  let blocks :=
    if unset then r.blocks.erase blockID
    else if r.blocks.contains blockID then r.blocks else r.blocks ++ [blockID]
  let unminedSince :=
    if blocks.isEmpty then some current else if onLongest then none else r.unminedSince
  setDAH s { r with blocks, unminedSince, locked := false } blockHeight

/-- Teranode's backdated stamp for a record moved off the longest chain:
the current height less `unminedTxRetention`, never below 1.
[SRC] stores/utxo/pruner_unmined.go:16-35 at 4edb60a4. -/
def backdatedUnminedSince (current retention : Nat) : Nat :=
  if current ≤ retention then 1 else current - retention

/-- `MarkTransactionsOnLongestChain`: on the longest chain clears
`unminedSince`; off it, stamps the backdated height only when absent. The
deletion height is not touched.
[SRC] stores/utxo/aerospike/longest_chain.go:17-38,71-87 at 4edb60a4. -/
def markLongestChain (s : StoreSettings) (r : Record) (onLongest : Bool) (current : Nat) : Record :=
  if onLongest then { r with unminedSince := none }
  else match r.unminedSince with
    | some _ => r
    | none => { r with unminedSince := some (backdatedUnminedSince current s.unminedTxRetention) }

/-- `setConflicting`: the mark, then the deletion height re-evaluated.
[SRC] stores/utxo/aerospike/teranode.lua:1072-1098 at 4edb60a4. -/
def setConflictingUdf (s : StoreSettings) (r : Record) (v : Bool) (h : Nat) : Record :=
  setDAH s { r with conflicting := v } h

/-- `setLocked`: the mark; locking clears the deletion height.
[SRC] stores/utxo/aerospike/teranode.lua:1196-1222 and
stores/utxo/aerospike/locked.go:46 at 4edb60a4. -/
def setLocked (r : Record) (v : Bool) : Record :=
  { r with locked := v, deleteAtHeight := if v then none else r.deleteAtHeight }

/-- A spend or an unspend moving the all-spent test, then the deletion height
re-evaluated at the operation's height.
[SRC] stores/utxo/aerospike/teranode.lua:442,542,1271-1273 at 4edb60a4. -/
def spendOutputs (s : StoreSettings) (r : Record) (allSpent : Bool) (h : Nat) : Record :=
  setDAH s { r with allSpent } h

/-- `PreserveTransactions` on one parent: only a record already carrying a
deletion height or a preservation is preserved; preserving clears the
deletion height and sets `preserveUntil`.
[SRC] stores/utxo/aerospike/aerospike.go:1112-1118,1143-1152 and
stores/utxo/aerospike/teranode.lua:1114-1142 at 4edb60a4. -/
def preserve (r : Record) (h : Nat) : Record :=
  if r.deleteAtHeight.isSome || r.preserveUntil.isSome then
    { r with deleteAtHeight := none, preserveUntil := some h }
  else r

/-- `ProcessExpiredPreservations` on one record whose `preserveUntil` is in
`[1, h]`: the preservation is cleared, and the deletion height is set to
`h + retention` exactly when the record is conflicting (with no deletion
height before) or fully spent with a block on the longest chain.
[SRC] stores/utxo/aerospike/aerospike.go:1268-1365 and
stores/utxo/aerospike/set_mined_expressions.go:150-239 at 4edb60a4. -/
def expirePreservation (s : StoreSettings) (r : Record) (h : Nat) : Record :=
  match r.preserveUntil with
  | some p =>
    if 1 ≤ p ∧ p ≤ h then
      { r with preserveUntil := none,
               deleteAtHeight :=
                 if s.blockHeightRetention ≠ 0 ∧
                    ((r.conflicting && r.deleteAtHeight.isNone) ||
                      (r.allSpent && !r.blocks.isEmpty && r.unminedSince.isNone))
                 then some (h + s.blockHeightRetention) else none }
    else r
  | none => r

/-- Phase 2 of the pruner deletes a record whose deletion height is in
`[1, h]`. The defensive mode (`stores/utxo/aerospike/pruner/pruner_service.go:966-979`,
`pruner_utxoDefensiveEnabled`) only skips deletions, so every "deleted only if" statement below holds under it.
[SRC] services/pruner/worker.go:250-262 and
stores/utxo/aerospike/pruner/pruner_service.go:577-580 at 4edb60a4. -/
def pruneDeletes (r : Record) (h : Nat) : Bool :=
  match r.deleteAtHeight with
  | some d => decide (1 ≤ d ∧ d ≤ h)
  | none => false

/-- Phase 1's selection of a child whose parents are preserved: unmined since
a height in `[1, h - unminedTxRetention]`, once `h` passes the retention. The
child itself is kept intact.
[SRC] stores/utxo/pruner_unmined.go:41-49,64-88 at 4edb60a4. -/
def prunableUnmined (s : StoreSettings) (r : Record) (h : Nat) : Bool :=
  decide (s.unminedTxRetention < h) &&
    match r.unminedSince with
    | some u => decide (1 ≤ u ∧ u ≤ h - s.unminedTxRetention)
    | none => false

/-- The store's refusals of a spend that read the lifetime marks, in the
store's order (the `creating` gate before them is out of scope).
[SRC] stores/utxo/aerospike/teranode.lua:305-333 and
stores/utxo/aerospike/spend.go:1049-1057 at 4edb60a4. -/
inductive SpendRefusal where
  | conflicting
  | locked
  | coinbaseImmature
  deriving DecidableEq, Repr

/-- The coinbase gate: refused while `spendingHeight` is positive and above
the spend's height.
[SRC] stores/utxo/aerospike/teranode.lua:325-333 at 4edb60a4. -/
def coinbaseImmature (r : Record) (current : Nat) : Bool :=
  match r.spendingHeight with
  | some sh => decide (0 < sh ∧ current < sh)
  | none => false

/-- The gates of `spendMulti` that read the marks, in order.
[SRC] stores/utxo/aerospike/teranode.lua:305-333 at 4edb60a4. -/
def spendGate (r : Record) (current : Nat) (ignoreConflicting ignoreLocked : Bool) :
    Option SpendRefusal :=
  if !ignoreConflicting && r.conflicting then some .conflicting
  else if !ignoreLocked && r.locked then some .locked
  else if coinbaseImmature r current then some .coinbaseImmature
  else none

/-- One store transition on a record. -/
inductive Step (s : StoreSettings) : Record → Record → Prop where
  | mined (r : Record) (blockID blockHeight current : Nat) (onLongest unset : Bool) :
      Step s r (setMined s r blockID blockHeight current onLongest unset)
  | longest (r : Record) (onLongest : Bool) (current : Nat) :
      Step s r (markLongestChain s r onLongest current)
  | conflicting (r : Record) (v : Bool) (h : Nat) : Step s r (setConflictingUdf s r v h)
  | locked (r : Record) (v : Bool) : Step s r (setLocked r v)
  | spent (r : Record) (allSpent : Bool) (h : Nat) : Step s r (spendOutputs s r allSpent h)
  | preserved (r : Record) (h : Nat) : Step s r (preserve r h)
  | expired (r : Record) (h : Nat) : Step s r (expirePreservation s r h)

/-- Runs of store transitions from a start record. -/
inductive Reach (s : StoreSettings) : Record → Record → Prop where
  | refl (r : Record) : Reach s r r
  | tail {r₀ r r' : Record} : Reach s r₀ r → Step s r r' → Reach s r₀ r'

/-- A record as one of the two create paths writes it. -/
abbrev Created (s : StoreSettings) (r : Record) : Prop :=
  (∃ h conflicting locked, r = createUnmined h conflicting locked) ∨
    (∃ blockID height isCoinbase noSpendable, r = createMined s blockID height isCoinbase noSpendable)

/-- A record some run of the store reaches from a create. -/
abbrev Reachable (s : StoreSettings) (r : Record) : Prop :=
  ∃ r₀, Created s r₀ ∧ Reach s r₀ r

/-! ## The invariant: a deletion height marks a mined or conflicting record -/

/-- The lifetime invariant: a deletion height only on a conflicting record or
one with a block ID; none while preserved; none with retention off. -/
abbrev Inv (s : StoreSettings) (r : Record) : Prop :=
  (r.deleteAtHeight.isSome → r.conflicting = true ∨ r.blocks ≠ []) ∧
    (r.preserveUntil.isSome → r.deleteAtHeight = none) ∧
    (s.blockHeightRetention = 0 → r.deleteAtHeight = none)

/-- `setDeleteAtHeight` re-establishes the invariant from its two side
conditions alone, whatever the record's blocks were before (the invalidation
case removes the last one). -/
theorem setDAH_inv (s : StoreSettings) (r : Record) (h : Nat)
    (hp : r.preserveUntil.isSome = true → r.deleteAtHeight = none)
    (hz : s.blockHeightRetention = 0 → r.deleteAtHeight = none) :
    Inv s (setDAH s r h) := by
  unfold setDAH
  by_cases h0 : s.blockHeightRetention = 0
  · rw [ite_eq_left_of_eq_true _ _ (eq_true h0)]
    exact ⟨fun hd => by simp [hz h0] at hd, fun _ => hz h0, fun _ => hz h0⟩
  rw [ite_eq_right_of_eq_false _ _ (eq_false h0)]
  by_cases hpu : r.preserveUntil.isSome = true
  · rw [ite_eq_left_of_eq_true _ _ (eq_true hpu)]
    exact ⟨fun hd => by simp [hp hpu] at hd, fun _ => hp hpu, fun e => absurd e h0⟩
  rw [ite_eq_right_of_eq_false _ _ (eq_false hpu)]
  by_cases hc : r.conflicting = true
  · rw [ite_eq_left_of_eq_true _ _ (eq_true hc)]
    split
    · exact ⟨fun _ => Or.inl hc, fun e => absurd e hpu, fun e => absurd e h0⟩
    · exact ⟨fun _ => Or.inl hc, fun e => absurd e hpu, fun e => absurd e h0⟩
  rw [ite_eq_right_of_eq_false _ _ (eq_false hc)]
  by_cases he : (r.allSpent && !r.blocks.isEmpty && r.unminedSince.isNone) = true
  · have hb : r.blocks ≠ [] := by
      intro e
      simp [e] at he
    rw [ite_eq_left_of_eq_true _ _ (eq_true he)]
    split
    · split
      · exact ⟨fun _ => Or.inr hb, fun e => absurd e hpu, fun e => absurd e h0⟩
      · exact ⟨fun _ => Or.inr hb, fun e => absurd e hpu, fun e => absurd e h0⟩
    · exact ⟨fun _ => Or.inr hb, fun e => absurd e hpu, fun e => absurd e h0⟩
  · rw [ite_eq_right_of_eq_false _ _ (eq_false he)]
    exact ⟨fun hd => by simp at hd, fun _ => rfl, fun _ => rfl⟩

/-- Re-evaluating the deletion height never touches the lock. -/
theorem setDAH_locked (s : StoreSettings) (r : Record) (h : Nat) :
    (setDAH s r h).locked = r.locked := by
  unfold setDAH
  repeat' split
  all_goals rfl

/-- Re-evaluating the deletion height never touches a coinbase's spending height. -/
theorem setDAH_spendingHeight (s : StoreSettings) (r : Record) (h : Nat) :
    (setDAH s r h).spendingHeight = r.spendingHeight := by
  unfold setDAH
  repeat' split
  all_goals rfl

/-- Every store transition keeps the invariant. -/
theorem step_inv {s : StoreSettings} {r r' : Record} (hi : Inv s r) (hs : Step s r r') :
    Inv s r' := by
  obtain ⟨h1, h2, h3⟩ := hi
  cases hs with
  | mined blockID blockHeight current onLongest unset =>
    simp only [setMined]
    exact setDAH_inv s _ blockHeight h2 h3
  | longest onLongest current =>
    unfold markLongestChain
    split
    · exact ⟨h1, h2, h3⟩
    · split
      · exact ⟨h1, h2, h3⟩
      · exact ⟨h1, h2, h3⟩
  | conflicting v h => exact setDAH_inv s _ h h2 h3
  | locked v =>
    cases v
    · simpa [setLocked, Inv] using (⟨h1, h2, h3⟩ : Inv s r)
    · simp [setLocked, Inv]
  | spent a h => exact setDAH_inv s _ h h2 h3
  | preserved h =>
    unfold preserve
    split
    · exact ⟨by simp, by simp, by simp⟩
    · exact ⟨h1, h2, h3⟩
  | expired h =>
    unfold expirePreservation
    split
    · split
      · refine ⟨fun hd => ?_, fun hp' => by simp at hp', fun h0 => by simp [h0]⟩
        simp only at hd
        split at hd
        · rename_i hc
          obtain ⟨_, hc⟩ := hc
          cases hcf : r.conflicting
          · right
            intro hb
            have hb' : r.blocks = [] := hb
            simp [hcf, hb'] at hc
          · exact Or.inl rfl
        · simp at hd
      · exact ⟨h1, h2, h3⟩
    · exact ⟨h1, h2, h3⟩

/-- A run of store transitions from a record that satisfies the invariant ends in one that does. -/
theorem reach_inv {s : StoreSettings} {r₀ r : Record} (hr : Reach s r₀ r) (hi : Inv s r₀) :
    Inv s r := by
  induction hr with
  | refl => exact hi
  | tail _ hs ih => exact step_inv ih hs

/-- Both create paths write a record that satisfies the invariant: an unmined
record has no deletion height; a mined one has a block. -/
theorem created_inv {s : StoreSettings} {r : Record} (hc : Created s r) : Inv s r := by
  rcases hc with ⟨h, c, l, rfl⟩ | ⟨b, h, cb, ns, rfl⟩
  · exact ⟨fun hd => by simp [createUnmined] at hd, fun _ => rfl, fun _ => rfl⟩
  · exact ⟨fun _ => Or.inr (by simp [createMined]), fun hp => by simp [createMined] at hp,
      fun h0 => by simp [createMined, h0]⟩

/-- The invariant holds in every reachable record. -/
theorem reachable_inv {s : StoreSettings} {r : Record} (hr : Reachable s r) : Inv s r := by
  obtain ⟨r₀, hc, hreach⟩ := hr
  exact reach_inv hreach (created_inv hc)

/-! ## Removal: the pruner against the reference's expiry -/

/-- The pruner deletes only a conflicting record or one with a block ID. -/
theorem prune_only_mined_or_conflicting {s : StoreSettings} {r : Record} (hr : Reachable s r)
    {h : Nat} (hd : pruneDeletes r h = true) : r.conflicting = true ∨ r.blocks ≠ [] := by
  apply (reachable_inv hr).1
  unfold pruneDeletes at hd
  split at hd
  · rename_i d e; simp [e]
  · simp at hd

/-- A record never mined and not conflicting is kept by every pruner cycle at
every height, whatever its age. -/
theorem never_mined_kept {s : StoreSettings} {r : Record} (hr : Reachable s r)
    (hb : r.blocks = []) (hc : r.conflicting = false) (h : Nat) : pruneDeletes r h = false := by
  cases hd : pruneDeletes r h
  · rfl
  · rcases prune_only_mined_or_conflicting hr hd with e | e
    · simp [hc] at e
    · exact absurd hb e

/-- A preserved record is kept by every pruner cycle while preserved. -/
theorem preserved_kept {s : StoreSettings} {r : Record} (hr : Reachable s r)
    (hp : r.preserveUntil.isSome) (h : Nat) : pruneDeletes r h = false := by
  simp [pruneDeletes, (reachable_inv hr).2.1 hp]

/-- The reference's expiry removes every accepted entry whose entry time is
strictly older than `-mempoolexpiry` (POLICY, `NodeConfig.mempoolExpiry`,
default 1,209,600 seconds), with its descendants.
[SRC] src/txmempool.cpp:2201-2220 and src/config.cpp:87 at 6504a3af. -/
theorem reference_expires_old (p : Mempool) (cfg : NodeConfig) (now : Int) (e : MempoolEntry)
    (he : e ∈ p.accepted) (hold : e.time < now - (cfg.mempoolExpiry : Int)) :
    e.id ∉ (expire p cfg now).accepted.map (·.id) := by
  rw [BsvChain.Properties.Mempool.expire_removes_only_expiry_closure]
  have hroot : e.id ∈ expiryRoots p cfg now :=
    List.mem_map.mpr ⟨e, List.mem_filter.mpr ⟨he, decide_eq_true hold⟩, rfl⟩
  have hdesc := BsvChain.Properties.Mempool.descendant_root_mem p e _ he hroot
  intro hmem
  obtain ⟨x, hx, hxe⟩ := List.mem_map.mp hmem
  have hx2 := (List.mem_filter.mp hx).2
  rw [hxe] at hx2
  simp [hdesc] at hx2

/-- THE WITNESS that removal iff the reference's expiry is not a theorem:
for every pool entry older than `-mempoolexpiry` the reference removes the
transaction, while every Teranode record that is unmined, never mined and not
conflicting (the record of `e`'s transaction among them, the scenario's `s3`
observes it) is kept at every height of every pruner cycle. -/
theorem expiry_rules_differ (p : Mempool) (cfg : NodeConfig) (now : Int) (e : MempoolEntry)
    (he : e ∈ p.accepted) (hold : e.time < now - (cfg.mempoolExpiry : Int))
    {s : StoreSettings} {r : Record} (hr : Reachable s r) (hb : r.blocks = [])
    (hc : r.conflicting = false) :
    e.id ∉ (expire p cfg now).accepted.map (·.id) ∧ ∀ h, pruneDeletes r h = false :=
  ⟨reference_expires_old p cfg now e he hold, never_mined_kept hr hb hc⟩

/-- A concrete run: created unmined and locked at height 101, unlocked by the
two-phase commit; kept at every height. -/
theorem unmined_record_kept_witness (s : StoreSettings) (h : Nat) :
    pruneDeletes (setLocked (createUnmined 101 false true) false) h = false :=
  never_mined_kept (s := s) ⟨_, Or.inl ⟨101, false, true, rfl⟩, .tail (.refl _) (.locked _ false)⟩
    rfl rfl h

/-- Teranode's age of an unmined record selects only its parents for
preservation: a record moved off the longest chain at height `h` above the
retention is selected at `h` (the backdating of issue 1768). -/
theorem backdated_prunable (s : StoreSettings) (r : Record) (h : Nat)
    (hu : r.unminedSince = none) (hh : s.unminedTxRetention < h) :
    prunableUnmined s (markLongestChain s r false h) h = true := by
  simp [prunableUnmined, markLongestChain, hu, backdatedUnminedSince, hh,
    Nat.not_le.mpr hh]
  omega

/-- A record mined in block 7 at height 100 with one output, the output
spent at height 150, then moved off the longest chain at height 200, under the
default settings. -/
def reorgedRecord : Record :=
  markLongestChain {} (spendOutputs {} (createMined {} 7 100 false false) true 150) false 200

/-- A record mined, fully spent and then moved off the longest chain is
unmined and still carries its deletion height: the store, on its own, deletes
it at the spend's height plus the retention. Its survival rests on phase 1
preserving it as the parent of an unmined child. -/
theorem reorged_spent_keeps_dah :
    reorgedRecord.unminedSince = some 56 ∧ reorgedRecord.deleteAtHeight = some 438 ∧
      pruneDeletes reorgedRecord 438 = true := by
  decide

/-! ## Maturity: the coinbase gate against the reference's -/

/-- No store transition moves a coinbase's spending height: it is written once,
at creation (`stores/utxo/aerospike/create.go:898` at 4edb60a4 [SRC]). -/
theorem step_spendingHeight {s : StoreSettings} {r r' : Record} (hs : Step s r r') :
    r'.spendingHeight = r.spendingHeight := by
  cases hs with
  | mined => simp [setMined, setDAH_spendingHeight]
  | longest => unfold markLongestChain; split <;> (try split) <;> rfl
  | conflicting => simp [setConflictingUdf, setDAH_spendingHeight]
  | locked => rfl
  | spent => simp [spendOutputs, setDAH_spendingHeight]
  | preserved => unfold preserve; split <;> rfl
  | expired => unfold expirePreservation; split <;> (try split) <;> rfl

/-- Every record a run reaches keeps the spending height its creation wrote. -/
theorem reach_spendingHeight {s : StoreSettings} {r₀ r : Record} (hr : Reach s r₀ r) :
    r.spendingHeight = r₀.spendingHeight := by
  induction hr with
  | refl => rfl
  | tail _ hs ih => exact (step_spendingHeight hs).trans ih

/-- Teranode's coinbase gate, on every record reached from the coinbase's
creation at height `h`: immature at spend height `H` exactly when the depth
`H - h` is below the maturity. -/
theorem coinbase_immature_iff {s : StoreSettings} {blockID h : Nat} {ns : Bool} {r : Record}
    (hr : Reach s (createMined s blockID h true ns) r) (H : Nat) :
    coinbaseImmature r H = true ↔ (H : Int) - h < s.coinbaseMaturity := by
  simp [coinbaseImmature, reach_spendingHeight hr, createMined]
  omega

/-- The reference's per-input stage refuses a coinbase input as premature
exactly when its depth is below `coinbaseMaturity` (consensus,
`COINBASE_MATURITY` = 100), for an available coin the operator lists do not
freeze. [SRC] src/validation.cpp:2591-2625 at 6504a3af. -/
theorem reference_premature_iff (u : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (confiscation : Bool) (input : TxIn) (total : Int) (coin : Coin)
    (hcoin : getCoin u (.ofInput input) = some coin) (hcb : coin.isCoinbase = true)
    (hfree : (!confiscation && lists.frozen ctx.onBlock ctx.height (.ofInput input)) = false) :
    checkInputCoins u cfg ctx lists confiscation [input] total =
        .error ⟨.node 0x10, "bad-txns-premature-spend-of-coinbase"⟩ ↔
      (ctx.height : Int) - coin.height < cfg.coinbaseMaturity := by
  by_cases hd : (ctx.height : Int) - coin.height < cfg.coinbaseMaturity
  · simp [checkInputCoins, hcoin, hcb, hfree, hd]
  · rw [iff_false_intro hd]
    simp only [checkInputCoins, hfree, hcoin, hcb, hd, decide_false, Bool.and_false,
      Bool.false_eq_true, ↓reduceIte]
    split_ifs <;> simp

/-- THE THEOREM for maturity: on every record the store reaches from a
coinbase created at the coin's height, Teranode's coinbase gate refuses the
spend as immature exactly when the reference refuses it as `bad-txns-premature-spend-of-coinbase`,
given equal maturities and the same spend height (the validator's height is
the tip plus one on the pool path, `services/validator/Validator.go:898-900`;
the reference's `nSpendHeight` is the tip's successor there,
`src/validation.cpp:2545-2549` (`GetSpendHeightAndMTP`, the best block's
height plus one; called at `:2857`)). -/
theorem coinbase_maturity_agrees {s : StoreSettings} {blockID : Nat} {ns : Bool} {r : Record}
    (u : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext) (lists : FrozenLists)
    (confiscation : Bool) (input : TxIn) (total : Int) (coin : Coin)
    (hcoin : getCoin u (.ofInput input) = some coin) (hcb : coin.isCoinbase = true)
    (hfree : (!confiscation && lists.frozen ctx.onBlock ctx.height (.ofInput input)) = false)
    (hr : Reach s (createMined s blockID coin.height true ns) r)
    (hm : s.coinbaseMaturity = cfg.coinbaseMaturity) :
    coinbaseImmature r ctx.height = true ↔
      checkInputCoins u cfg ctx lists confiscation [input] total =
        .error ⟨.node 0x10, "bad-txns-premature-spend-of-coinbase"⟩ := by
  rw [coinbase_immature_iff hr, reference_premature_iff u cfg ctx lists confiscation input total
    coin hcoin hcb hfree, hm]

/-- The two pins' defaults agree: Teranode's chain parameter (100 on every
go-chaincfg v1.6.2 network) and the reference's `COINBASE_MATURITY`, so
`coinbase_maturity_agrees`'s premise holds at the defaults. The general form is
`coinbase_maturity_agrees`, for every configuration with equal maturities; this
theorem is its instance at the census defaults. -/
theorem defaults_maturity_agree :
    ({} : StoreSettings).coinbaseMaturity = NodeConfig.defaults.coinbaseMaturity := rfl

/-! ## Locked: the two-phase commit mark -/

/-- A locked record refuses a spend of its outputs unless the caller ignores
the mark (and a conflicting record refuses before it). -/
theorem locked_refuses (r : Record) (current : Nat) (ignoreConflicting : Bool)
    (hl : r.locked = true) (hc : (!ignoreConflicting && r.conflicting) = false) :
    spendGate r current ignoreConflicting false = some .locked := by
  simp [spendGate, hc, hl]

/-- Mining a record clears its lock. -/
theorem setMined_unlocks (s : StoreSettings) (r : Record) (blockID blockHeight current : Nat)
    (onLongest unset : Bool) :
    (setMined s r blockID blockHeight current onLongest unset).locked = false := by
  simp [setMined, setDAH_locked]

/-- Locking clears the deletion height, so a locked record is never pruned
while locked unless a later transition re-stamps it. -/
theorem lock_clears_dah (r : Record) : (setLocked r true).deleteAtHeight = none := by
  simp [setLocked]

end BsvChain.Teranode.Lifetimes
