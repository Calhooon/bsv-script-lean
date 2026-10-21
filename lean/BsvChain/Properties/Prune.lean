import BsvChain.Views.Prune

/-!
# Pruning: what the selections keep, and what a pruned block can and cannot serve (#82)

[M] 2026-10-15 (#82). Views, never rules: pruning is a node's storage setting
(cited in `lean/BsvChain/Views/Prune.lean`'s header). On the store: a block stays while
its file stays, its undo never outlives its data, and neither selection removes a file
holding a block within `minBlocksToKeep` of the tip or the file being written; the
automatic selection takes nothing at or below `nPruneAfterHeight` while `pruneblockchain`
already acts there; the RPC never prunes past the tip less `minBlocksToKeep`, and when that
is negative it answers the negative height's `uint64_t` cast and removes nothing;
`pruneheight` bounds a run of blocks that all have their data. On the answers: a block's
header, its index reads and the UTXO set survive pruning; its body and its transactions
through the index do not; a merkle proof is served exactly when the block's data or its
merkle tree is held, so "a proof the node can serve names a block it retains" is FALSE at
the pin (`merkleproof_pruned_tree_served`), and true for a node that holds no tree
(`merkleproof_served_no_tree`). On #64's undo data: pruning removes body and undo together,
so an undo the node lacks for a connected block is a block it pruned, and the spec's tip
disconnection fails at a pruned tip without moving the chain or the coins.
[D] The weakening: the store (Views §2-3) and the header tree (§6) are not bridged; `pruneTree`'s
`gone` is any predicate, so the composition "a disconnect within `minBlocksToKeep` of the tip
finds its undo" is owed, and `header_served` is a statement about the answer table, not about
#65's `verifyTsc`.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/blockfileinfostore.cpp:21-39,74-103,177-300, src/block_file_info.cpp:19-44,
src/validation.cpp:3826-3860,4065-4080,6584-6635, src/block_index.h:669-690,
src/rpc/blockchain.cpp:1810-1875,2467-2480, src/rpc/rawtransaction.cpp:2286-2300,2404-2444,
src/merkletreestore.cpp:540-570.
-/

namespace BsvChain.Properties
open BsvChain BsvChain.Views.Prune

/-- The store's height invariant: a stored block whose file was not removed is at or below
its file's highest height (`AddBlock` raises `nHeightLast`,
src/block_file_info.cpp:29-44). -/
def PruneStoreWF (s : Store) : Prop :=
  ∀ h n u, (h, n, u) ∈ s.placed → s.removed.contains n = false → h ≤ (s.files n).heightLast

/-- [D] 2026-10-15: the empty store satisfies the invariant. -/
theorem pruneStoreWF_empty : PruneStoreWF {} := by
  intro h n u hm; simp at hm

/-- [D] 2026-10-15: storing a block keeps the invariant: the receiving file's highest height
becomes at least the new block's, and no other file changes.
[SRC] src/blockfileinfostore.cpp:74-103, src/block_file_info.cpp:19-44 at 6504a3af. -/
theorem addBlock_wf (c : Config) (s : Store) (height size undoBytes : Nat) (u : Bool)
    (hs : PruneStoreWF s) : PruneStoreWF (s.addBlock c height size undoBytes u) := by
  intro h n u' hm hr
  simp only [Store.addBlock, List.mem_append, List.mem_singleton, Prod.mk.injEq] at hm hr ⊢
  rcases hm with hm | ⟨rfl, rfl, rfl⟩
  · have := hs h n u' hm hr
    split
    · rename_i heq; subst heq; simp only; omega
    · exact this
  · simp

/-- [D] 2026-10-15: removing files keeps the invariant: a file not removed keeps its info.
[SRC] src/validation.cpp:6584-6628 at 6504a3af. -/
theorem unlink_wf (s : Store) (set : List Nat) (hs : PruneStoreWF s) :
    PruneStoreWF (s.unlink set) := by
  intro h n u hm hr
  simp only [Store.unlink, List.contains_append, Bool.or_eq_false_iff] at hm hr ⊢
  simp only [hr.2, Bool.false_eq_true, ↓reduceIte]
  exact hs h n u hm hr.1

/-- [D] 2026-10-15: lock-step: a block's undo bit implies its data bit (block and undo
files are removed together). [SRC] src/validation.cpp:6608-6617,
src/block_index.h:669-690 at 6504a3af. -/
theorem hasUndo_hasData (s : Store) (k : Nat) (h : s.hasUndo k = true) : s.hasData k = true := by
  unfold Store.hasUndo at h; unfold Store.hasData
  split at h <;> simp_all

/-- [D] 2026-10-15: every file the manual selection takes is non-empty, below the file being
written, and has its highest block at or below the bound.
[SRC] src/blockfileinfostore.cpp:196-203 at 6504a3af. -/
theorem manualSet_mem (c : Config) (s : Store) (tip h n : Nat) (hn : n ∈ manualSet c s tip h) :
    n < s.last ∧ (s.files n).size ≠ 0 ∧ (s.files n).heightLast ≤ manualBound c tip h := by
  simp only [manualSet, List.mem_filter, List.mem_range, Bool.and_eq_true, bne_iff_ne, ne_eq,
    decide_eq_true_eq] at hn
  exact ⟨hn.1, hn.2.1, hn.2.2⟩

/-- [D] 2026-10-15: with a chain at least `minBlocksToKeep` long, the manual bound is at or
below the tip less `minBlocksToKeep`. [SRC] src/blockfileinfostore.cpp:189-194 at 6504a3af. -/
theorem manualBound_le (c : Config) (tip h : Nat) (hk : c.minBlocksToKeep ≤ tip) :
    manualBound c tip h ≤ tip - c.minBlocksToKeep := by
  unfold manualBound; split <;> omega

/-- [D] 2026-10-15: THE MANUAL RETENTION: a stored block within `minBlocksToKeep` of the tip
keeps its data through the manual selection, whatever height was asked.
[SRC] src/blockfileinfostore.cpp:177-208 at 6504a3af. -/
theorem manual_keeps_recent (c : Config) (s : Store) (tip h k height n : Nat) (u : Bool)
    (hs : PruneStoreWF s) (hk : c.minBlocksToKeep ≤ tip)
    (hp : s.placed[k]? = some (height, n, u)) (hd : s.hasData k = true)
    (hrec : tip - c.minBlocksToKeep < height) :
    (s.unlink (manualSet c s tip h)).hasData k = true := by
  unfold Store.hasData at hd ⊢
  simp only [hp, Bool.not_eq_true'] at hd
  simp only [Store.unlink, hp, List.contains_append, hd, Bool.false_or, Bool.not_eq_true']
  by_contra hc
  simp only [Bool.not_eq_false, List.contains_iff_mem] at hc
  have hm := manualSet_mem c s tip h n hc
  have hw := hs height n u (List.mem_of_getElem? hp) hd
  have := manualBound_le c tip h hk
  omega

/-- [D] 2026-10-15: every file the automatic scan takes is a file of the scanned list with
its highest block at or below the bound. [SRC] src/blockfileinfostore.cpp:266-288 at 6504a3af. -/
theorem autoLoop_mem (s : Store) (bound : Int) (stop : Nat) :
    ∀ (ns : List Nat) (cur n : Nat), n ∈ autoLoop s bound stop ns cur →
      n ∈ ns ∧ ((s.files n).heightLast : Int) ≤ bound
  | [], _, _, hn => by simp [autoLoop] at hn
  | m :: ms, cur, n, hn => by
    unfold autoLoop at hn
    split at hn
    · have := autoLoop_mem s bound stop ms cur n hn; exact ⟨List.mem_cons_of_mem _ this.1, this.2⟩
    · split at hn
      · simp at hn
      · split at hn
        · have := autoLoop_mem s bound stop ms cur n hn
          exact ⟨List.mem_cons_of_mem _ this.1, this.2⟩
        · rcases List.mem_cons.mp hn with rfl | hn
          · exact ⟨List.mem_cons_self .., by omega⟩
          · have := autoLoop_mem s bound stop ms _ n hn
            exact ⟨List.mem_cons_of_mem _ this.1, this.2⟩

/-- [D] 2026-10-15: every file the automatic selection takes is below the file being written
and has its highest block at or below the tip less `minBlocksToKeep`.
[SRC] src/blockfileinfostore.cpp:244-251,266-288 at 6504a3af. -/
theorem autoSet_mem (c : Config) (s : Store) (pa tip fl n : Nat)
    (hn : n ∈ autoSet c s pa tip fl) :
    n < s.last ∧ ((s.files n).heightLast : Int) ≤ (tip : Int) - c.minBlocksToKeep := by
  unfold autoSet at hn
  split at hn
  · simp at hn
  · split at hn
    · simp at hn
    · have := autoLoop_mem s _ _ _ _ n hn
      refine ⟨List.mem_range.mp this.1, ?_⟩
      have hb := this.2; unfold autoBound at hb; omega

/-- [D] 2026-10-15: THE AUTOMATIC RETENTION: a stored block within `minBlocksToKeep` of the
tip keeps its data through the automatic selection. [SRC]
src/blockfileinfostore.cpp:230-300 at 6504a3af. -/
theorem auto_keeps_recent (c : Config) (s : Store) (pa tip fl k height n : Nat) (u : Bool)
    (hs : PruneStoreWF s) (hp : s.placed[k]? = some (height, n, u)) (hd : s.hasData k = true)
    (hrec : (tip : Int) - c.minBlocksToKeep < height) :
    (s.unlink (autoSet c s pa tip fl)).hasData k = true := by
  unfold Store.hasData at hd ⊢
  simp only [hp, Bool.not_eq_true'] at hd
  simp only [Store.unlink, hp, List.contains_append, hd, Bool.false_or, Bool.not_eq_true']
  by_contra hc
  simp only [Bool.not_eq_false, List.contains_iff_mem] at hc
  have hm := autoSet_mem c s pa tip fl n hc
  have hw := hs height n u (List.mem_of_getElem? hp) hd
  omega

/-- [D] 2026-10-15: neither selection takes the file being written.
[SRC] src/blockfileinfostore.cpp:196,266 at 6504a3af. -/
theorem selections_spare_last (c : Config) (s : Store) (pa tip fl h : Nat) :
    s.last ∉ manualSet c s tip h ∧ s.last ∉ autoSet c s pa tip fl := by
  constructor
  · intro hn; have := (manualSet_mem c s tip h _ hn).1; omega
  · intro hn; have := (autoSet_mem c s pa tip fl _ hn).1; omega

/-- [D] 2026-10-15: the automatic selection takes nothing while the tip is at or below
`nPruneAfterHeight`. [SRC] src/blockfileinfostore.cpp:240-242 at 6504a3af. -/
theorem autoSet_nil_of_le (c : Config) (s : Store) (pa tip fl : Nat) (h : tip ≤ pa) :
    autoSet c s pa tip fl = [] := by
  unfold autoSet; simp [h]

/-- [D] 2026-10-15: in manual mode (`-prune=1`, the target the largest `uint64_t`) the
automatic selection takes nothing while usage plus one chunk of each kind is below that
target. [SRC] src/init.cpp:2821-2826, src/blockfileinfostore.cpp:265 at 6504a3af. -/
theorem automatic_manual_nil (c : Config) (s : Store) (pa tip fl : Nat) (hm : c.mode = .manual)
    (hu : s.usage + blockFileChunkSize + undoFileChunkSize < maxUInt64) :
    autoSet c s pa tip fl = [] := by
  unfold autoSet; simp [hm, Mode.target, hu]

/-- [D] 2026-10-15: THE BOUNDARY: at a tip exactly `nPruneAfterHeight` the RPC is not refused
as too short (its test is `<`) while the automatic selection takes nothing (its test is
`<=`). [SRC] src/rpc/blockchain.cpp:1860, src/blockfileinfostore.cpp:240 at 6504a3af. -/
theorem boundary_rpc_acts_auto_does_not (c : Config) (s : Store) (pa fl : Nat) (p : Int)
    (r : Int → Option Nat) :
    pruneblockchain c pa pa p r ≠ .error (-1, "Blockchain is too short for pruning.") ∧
      autoSet c s pa pa fl = [] := by
  refine ⟨?_, autoSet_nil_of_le c s pa pa fl (Nat.le_refl _)⟩
  unfold pruneblockchain
  split
  · simp
  · split
    · simp
    · split <;> (try split) <;> simp_all <;> (try split) <;> (try split) <;> simp_all

/-- [D] 2026-10-15: whatever it answers, the RPC never prunes past the tip less
`minBlocksToKeep`. [SRC] src/rpc/blockchain.cpp:1859-1873 at 6504a3af. -/
theorem pruneblockchain_le (c : Config) (pa tip : Nat) (p : Int) (r : Int → Option Nat) (h : Int)
    (hok : pruneblockchain c pa tip p r = .ok h) : h ≤ (tip : Int) - c.minBlocksToKeep := by
  unfold pruneblockchain at hok
  split at hok
  · simp at hok
  · split at hok
    · simp at hok
    · split at hok <;> (try split at hok) <;> simp_all <;>
        (repeat' split at hok) <;> simp_all

/-- [D] 2026-10-15: THE NEGATIVE CLAMP: when `minBlocksToKeep` exceeds the tip, a request at
or below the tip answers the tip less `minBlocksToKeep`, a negative height that the reply
casts to `uint64_t`, and removes nothing (the manual selection runs only above zero).
[SRC] src/rpc/blockchain.cpp:1867-1874, src/validation.cpp:3840-3842 at 6504a3af. -/
theorem pruneblockchain_negative (c : Config) (s : Store) (pa tip : Nat) (p : Int)
    (hc : c.mode.enabled = true) (hpa : pa ≤ tip) (hk : tip < c.minBlocksToKeep) (hp : 0 ≤ p)
    (hp2 : p ≤ tip) (hpt : p ≤ 1000000000) :
    s.pruneRpc c pa tip p = (.ok ((tip : Int) - c.minBlocksToKeep), s) := by
  have hp3 : ¬ (1000000000 < p) := by omega
  unfold Store.pruneRpc pruneblockchain
  simp only [hc, Bool.not_true, Bool.false_eq_true, ↓reduceIte, show ¬ p < 0 by omega, hp3,
    show ¬ ((tip : Int) < pa) by omega, show ¬ ((tip : Int) < p) by omega,
    show (tip : Int) - c.minBlocksToKeep < p by omega]
  simp only [Prod.mk.injEq, true_and]
  split
  · exfalso; omega
  · rfl

/-- [D] 2026-10-15: every block from `pruneheight` up to the tip's parent has its data.
[SRC] src/rpc/blockchain.cpp:2467-2480 at 6504a3af. -/
theorem pruneHeightFrom_data (data : Nat → Bool) :
    ∀ tip m, pruneHeightFrom data tip ≤ m → m < tip → data m = true
  | 0, m, _, hm => by omega
  | t + 1, m, hp, hm => by
    unfold pruneHeightFrom at hp
    split at hp
    · rename_i hd
      by_cases hmt : m = t
      · subst hmt; exact hd
      · exact pruneHeightFrom_data data t m hp (by omega)
    · omega

/-- [D] 2026-10-15: `pruneheight` is genesis or a block whose parent has no data.
[SRC] src/rpc/blockchain.cpp:2474-2477 at 6504a3af. -/
theorem pruneHeightFrom_stop (data : Nat → Bool) :
    ∀ tip, pruneHeightFrom data tip = 0 ∨ data (pruneHeightFrom data tip - 1) = false
  | 0 => by simp [pruneHeightFrom]
  | t + 1 => by
    unfold pruneHeightFrom
    split
    · exact pruneHeightFrom_stop data t
    · rename_i hd; right; simpa using hd

/-- [D] 2026-10-15: a merkle proof is served exactly when the block's data or its merkle
tree is held. [SRC] src/rpc/rawtransaction.cpp:2293-2300,2439-2444,
src/merkletreestore.cpp:540-570 at 6504a3af. -/
theorem merkleproof_served_iff (hash : String) (h : Held) :
    answer hash h .getmerkleproof = .served ↔ (h.data || h.treeHeld) = true := by
  cases h with | mk d t => cases d <;> cases t <;> simp [answer]

/-- [D] 2026-10-15: the same for `getmerkleproof2`. [SRC] src/rpc/rawtransaction.cpp:2439-2444
at 6504a3af. -/
theorem merkleproof2_served_iff (hash : String) (h : Held) :
    answer hash h .getmerkleproof2 = .served ↔ (h.data || h.treeHeld) = true := by
  cases h with | mk d t => cases d <;> cases t <;> simp [answer]

/-- [D] 2026-10-15: THE CHARTER'S SENTENCE IS FALSE AT THE PIN: a pruned block whose merkle
tree is still held is served a proof. [SRC] src/merkletreestore.cpp:540-570 at 6504a3af. -/
theorem merkleproof_pruned_tree_served (hash : String) :
    answer hash { data := false, treeHeld := true } .getmerkleproof = .served := by
  rfl

/-- [D] 2026-10-15: for a node that holds no tree of the block, a proof it serves names a
block it retains. [SRC] src/merkletreestore.cpp:552-563 at 6504a3af. -/
theorem merkleproof_served_no_tree (hash : String) (h : Held) (ht : h.treeHeld = false)
    (hs : answer hash h .getmerkleproof = .served) : h.data = true := by
  have := (merkleproof_served_iff hash h).mp hs
  simpa [ht] using this

/-- [D] 2026-10-15: the header a proof's target names is always served, pruned or not, so a
held tree's proof can be checked against it (#65's `verifyTsc`; the bridge is not stated here).
[SRC] src/rpc/blockchain.cpp:93-158 at 6504a3af. -/
theorem header_served (hash : String) (h : Held) (code : Int) (msg : String) :
    answer hash h .getblockheader ≠ .error code msg ∧
      answer hash h .getblockheader ≠ .headThenError code msg := by
  cases h with | mk d t => cases d <;> simp [answer]

/-- [D] 2026-10-15: the body is served exactly when the data is held, at every verbosity.
[SRC] src/rpc/blockchain.cpp:1446-1474,1591-1620,1665-1678 at 6504a3af. -/
theorem getblock_served_iff (hash : String) (h : Held) (v : Nat) :
    answer hash h (.getblock v) = .served ↔ h.data = true := by
  cases h with | mk d t => cases v <;> cases d <;> simp [answer]

/-- [D] 2026-10-15: a transaction is served through `-txindex` exactly when its block's data
is held. [SRC] src/validation.cpp:2178-2185, src/rpc/rawtransaction.cpp:196-205 at 6504a3af. -/
theorem getrawtransaction_served_iff (hash : String) (h : Held) :
    answer hash h .getrawtransaction = .served ↔ h.data = true := by
  cases h with | mk d t => cases d <;> simp [answer]

/-- [D] 2026-10-15: the UTXO set is not pruned: an unspent output is served whatever the
block's data. [SRC] src/rpc/blockchain.cpp:1923-2029 at 6504a3af. -/
theorem gettxout_unpruned (hash : String) (h : Held) : answer hash h .gettxout = .served := rfl

/-- [D] 2026-10-15: a list lookup by a key that a map preserves commutes with the map. -/
theorem find?_map_key {α β : Type} [BEq β] (key : α → β) (f : α → α)
    (hf : ∀ a, key (f a) = key a) (k : β) :
    ∀ l : List α, (l.map f).find? (fun a => key a == k) = (l.find? (fun a => key a == k)).map f
  | [] => rfl
  | a :: l => by
    simp only [List.map_cons, List.find?_cons, hf]
    split
    · rfl
    · exact find?_map_key key f hf k l

/-- [D] 2026-10-15: a pruned index keeps its header, hence its id.
[SRC] src/block_index.h:669-690 at 6504a3af. -/
theorem pruneIndex_header (i : BlockIndex) : (pruneIndex i).header = i.header := rfl

/-- [D] 2026-10-15: pruning never changes an index's id. -/
theorem pruneIf_id (g : BitVec 256 → Bool) (i : BlockIndex) :
    (if g i.id = true then pruneIndex i else i).id = i.id := by
  split
  · show BlockHeader.hash (pruneIndex i).header = BlockHeader.hash i.header
    rw [pruneIndex_header]
  · rfl

/-- [D] 2026-10-15: pruning the header tree keeps every index (and its id); a pruned index
has neither body nor undo. [SRC] src/block_index.h:669-690 at 6504a3af. -/
theorem pruneTree_get (t : HeaderTree) (g : BitVec 256 → Bool) (hash : BitVec 256) :
    (pruneTree t g).get hash =
      (t.get hash).map (fun i => if g i.id = true then pruneIndex i else i) := by
  unfold pruneTree HeaderTree.get
  exact find?_map_key BlockIndex.id _ (pruneIf_id g) hash t.nodes

/-- [D] 2026-10-15: the index a lookup returns carries the id it was looked up by. -/
theorem get_id (t : HeaderTree) (hash : BitVec 256) (i : BlockIndex) (hi : t.get hash = some i) :
    i.id = hash := by
  unfold HeaderTree.get at hi
  have := List.find?_some hi
  simpa using this

/-- [D] 2026-10-15: THE UNDO INTERACTION: an undo the node lacks for a block it had connected
(its index held an undo record) is a block it pruned.
[SRC] src/validation.cpp:6584-6606, src/block_index.h:669-690 at 6504a3af. -/
theorem undo_absent_pruned (t : HeaderTree) (g : BitVec 256 → Bool) (hash : BitVec 256)
    (i j : BlockIndex) (hi : t.get hash = some i) (hu : i.undo.isSome = true)
    (hj : (pruneTree t g).get hash = some j) (hn : j.undo = none) : g hash = true := by
  rw [pruneTree_get, hi, Option.map_some, Option.some.injEq] at hj
  have hid := get_id t hash i hi
  by_cases hg : g i.id = true
  · rw [← hid]; exact hg
  · simp only [hg, Bool.false_eq_true, ↓reduceIte] at hj; subst hj; rw [hn] at hu
    exact absurd hu (by decide)

/-- [D] 2026-10-15: lock-step on the spec's tree: a pruned index lacks both its body and its
undo. [SRC] src/block_index.h:669-690 at 6504a3af. -/
theorem pruned_lockstep (t : HeaderTree) (g : BitVec 256 → Bool) (hash : BitVec 256)
    (j : BlockIndex) (hj : (pruneTree t g).get hash = some j) (hg : g hash = true) :
    j.body = none ∧ j.undo = none := by
  rw [pruneTree_get] at hj
  cases hi : t.get hash with
  | none => rw [hi] at hj; exact absurd hj (by simp)
  | some i =>
    rw [hi, Option.map_some, Option.some.injEq] at hj
    have hid := get_id t hash i hi
    rw [hid] at hj
    simp only [hg, ↓reduceIte] at hj
    subst hj
    exact ⟨rfl, rfl⟩

/-- [D] 2026-10-15: THE DISCONNECT AT A PRUNED TIP: the spec's `disconnectTip` fails without
moving the active chain or the coins. At the pin the node's observable is held in the record
under the discretion group until routed.
[SRC] src/validation.cpp:4065-4080 at 6504a3af. -/
theorem disconnectTip_pruned (s : ChainState) (ctx : ChainContext) (cause : DisconnectCause)
    (g : BitVec 256 → Bool) (tip : BitVec 256) (i : BlockIndex)
    (hlast : s.active.getLast? = some tip) (hi : s.tree.get tip = some i) (hg : g tip = true) :
    (disconnectTip (pruneState s g) ctx cause).2 = .failed ∧
      (disconnectTip (pruneState s g) ctx cause).1.active = s.active ∧
      (disconnectTip (pruneState s g) ctx cause).1.view = s.view := by
  have hget : (pruneTree s.tree g).get tip = some (pruneIndex i) := by
    rw [pruneTree_get, hi, Option.map_some, get_id s.tree tip i hi]
    simp only [hg, ↓reduceIte]
  have hbody : (pruneIndex i).body = none := rfl
  unfold disconnectTip pruneState
  simp only [hlast, Option.bind_some, hget, hbody]
  exact ⟨rfl, rfl, rfl⟩

end BsvChain.Properties
