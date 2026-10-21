import BsvChain.Properties.Theorems

/-!
# Reachable states and the body binding (#68, G3)

[M] 2026-10-13 (#68). The states the machine's own transitions reach
from the empty state, and the invariant they keep: every retained body is
bound to its index by the header hash, and its own header commits to its
transactions with no mutation, as the block check established when the body
was stored. #65's inclusion theorem then holds for reachable states without
the per-use root-binding hypothesis: what remains is the identification of
the block (which index, at which active height) and the stated collision
disjuncts, never an axiom.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/validation.cpp:5770-5781,6134-6197,6238-6395,4913-5330,
src/consensus/merkle.cpp:284-327.
-/

namespace BsvChain.Properties
open BsvScript.Numbers BsvScript.Tx BsvScript.TxRules BsvScript.Hash

/-- [D] 2026-10-13: the transitions that change the header tree or the active
chain, each under its own explicit context, operator lists, oracle, rank,
budget and time, plus any change confined to the pool (receiving, expiring
or trimming transactions never touches the tree). Every argument is free:
the relation quantifies over parameters, configuration, oracle and time.
[SRC] src/validation.cpp:4913-5330,6134-6197,6238-6395 and
src/rpc/blockchain.cpp:2695,2770-2892 at 6504a3af. -/
inductive Reachable : ChainState → Prop where
  | empty : Reachable {}
  | header {s t : ChainState} (ctx : ChainContext) (header : BlockHeader) (rank : Nat) :
      Reachable s → acceptHeader s ctx header rank = .ok t → Reachable t
  | block {s : ChainState} (ctx : ChainContext) (block : Block) (rank : Nat) (requested : Bool) :
      Reachable s → Reachable (acceptBlock s ctx block rank requested).1
  | activate {s : ChainState} (ctx : ChainContext) (lists : FrozenLists) (oracle : ScriptOracle) (fuel : Nat) :
      Reachable s → Reachable (activateBestChain s ctx lists oracle fuel).1
  | invalidate {s : ChainState} (ctx : ChainContext) (lists : FrozenLists) (oracle : ScriptOracle)
      (hash : BitVec 256) (fuel : Nat) :
      Reachable s → Reachable (invalidateBlock s ctx lists oracle hash fuel).1
  | reconsider {s : ChainState} (ctx : ChainContext) (lists : FrozenLists) (oracle : ScriptOracle)
      (hash : BitVec 256) (fuel : Nat) :
      Reachable s → Reachable (reconsiderBlock s ctx lists oracle hash fuel).1
  | precious {s : ChainState} (ctx : ChainContext) (lists : FrozenLists) (oracle : ScriptOracle)
      (hash : BitVec 256) (fuel : Nat) :
      Reachable s → Reachable (preciousBlock s ctx lists oracle hash fuel).1
  | softReject {s : ChainState} (ctx : ChainContext) (lists : FrozenLists) (oracle : ScriptOracle)
      (hash : BitVec 256) (duration : Int) (fuel : Nat) :
      Reachable s → Reachable (setSoftRejection s ctx lists oracle hash duration fuel).1
  | softFreeze {s : ChainState} (ctx : ChainContext) (lists : FrozenLists) (oracle : ScriptOracle)
      (hash : BitVec 256) (duration : Int) (fuel : Nat) :
      Reachable s → Reachable (setSoftFreeze s ctx lists oracle hash duration fuel).1
  | pool {s : ChainState} (p : Mempool) : Reachable s → Reachable { s with mempool := p }

/-- [D] 2026-10-13: a body's own header commits to its transactions with no
mutation: the two merkle checks of the block check.
[SRC] src/validation.cpp:5770-5781 at 6504a3af. -/
def RootBound (b : Block) : Prop :=
  headerWordBytes 32 b.header.merkleRoot.toNat = (blockMerkleRoot b.transactions).root ∧
    (blockMerkleRoot b.transactions).mutated = false

/-- [D] 2026-10-13: an index's retained body is bound to it by the header hash
(the index map's key) and its own header commits to its transactions.
[SRC] src/validation.cpp:5770-5781,6137-6169 at 6504a3af. -/
def NodeBound (i : BlockIndex) : Prop :=
  ∀ b, i.body = some b → i.header.hash = b.header.hash ∧ RootBound b

/-- [D] 2026-10-13: the invariant: every index of the tree is bound.
[SRC] src/validation.cpp:5770-5781,6238-6395 at 6504a3af. -/
def BodiesBound (s : ChainState) : Prop := ∀ i ∈ s.tree.nodes, NodeBound i

/-- [D] 2026-10-13: equal immutable projections carry the invariant: the
binding reads only headers and bodies.
[SRC] src/validation.cpp:4345-4404,4498-4523 at 6504a3af. -/
theorem bound_of_treeCore (a b : HeaderTree) (h : treeCore a = treeCore b)
    (hb : ∀ i ∈ b.nodes, NodeBound i) : ∀ i ∈ a.nodes, NodeBound i := by
  intro i hi
  have hm : indexCore i ∈ treeCore b := h ▸ List.mem_map_of_mem hi
  obtain ⟨j, hj, he⟩ := List.mem_map.mp hm
  simp only [indexCore, Prod.mk.injEq] at he
  intro body hbody
  rw [← he.1]
  exact hb j hj body (he.2.2.2.trans hbody)

/-- [D] 2026-10-13: an executed transition preserves the invariant.
[SRC] src/validation.cpp:4065-4133,4345-4404,5230-5330 at 6504a3af. -/
theorem bound_of_execution {allowed : DisconnectCause → Prop} {s t : ChainState}
    (h : ChainExecution allowed s t) (hs : BodiesBound s) : BodiesBound t :=
  bound_of_treeCore _ _ h.1 hs

/-- [D] 2026-10-13: an edit that binds every edited index keeps the invariant.
[SRC] src/validation.cpp:5528-5562 at 6504a3af. -/
theorem bound_modify (tree : HeaderTree) (hash : BitVec 256) (f : BlockIndex → BlockIndex)
    (hb : ∀ i ∈ tree.nodes, NodeBound i)
    (hf : ∀ i ∈ tree.nodes, i.id = hash → NodeBound (f i)) :
    ∀ i ∈ (tree.modify hash f).nodes, NodeBound i := by
  intro i hi
  simp only [HeaderTree.modify, List.mem_map] at hi
  obtain ⟨j, hj, rfl⟩ := hi
  split
  · exact hf j hj (by simpa using (by assumption : (j.id == hash) = true))
  · exact hb j hj

/-- [D] 2026-10-13: a metadata edit keeps a bound index bound.
[SRC] src/block_index.h:364-375 at 6504a3af. -/
theorem nodeBound_congr (i j : BlockIndex) (hh : j.header = i.header) (hb : j.body = i.body)
    (h : NodeBound i) : NodeBound j := by
  intro b hbody
  rw [hh]
  exact h b (hb ▸ hbody)

/-- [D] 2026-10-13: a looked-up index is a member of the tree.
[SRC] src/validation.cpp:6137-6169 at 6504a3af. -/
theorem get_mem (tree : HeaderTree) (hash : BitVec 256) (i : BlockIndex)
    (h : tree.get hash = some i) : i ∈ tree.nodes ∧ i.id = hash := by
  unfold HeaderTree.get at h
  exact ⟨List.mem_of_find?_eq_some h, by simpa using List.find?_some h⟩

/-- [D] 2026-10-13: candidate insertion changes no index.
[SRC] src/validation.cpp:5705-5708 at 6504a3af. -/
theorem insertCandidate_nodes (tree : HeaderTree) (active : List (BitVec 256)) (i : BlockIndex) :
    (insertCandidate tree active i).nodes = tree.nodes := by
  unfold insertCandidate
  split <;> rfl

/-- [D] 2026-10-13: body linking edits only link metadata of looked-up indices.
[SRC] src/validation.cpp:5688-5725 at 6504a3af. -/
theorem linkBodies_bound (active : List (BitVec 256)) (n : Nat) (queue : List (BitVec 256))
    (tree : HeaderTree) (hb : ∀ i ∈ tree.nodes, NodeBound i) :
    ∀ i ∈ (linkBodies active n queue tree).nodes, NodeBound i := by
  induction n generalizing queue tree with
  | zero => simpa [linkBodies] using hb
  | succ n ih =>
    cases queue with
    | nil => simpa [linkBodies] using hb
    | cons hash queue =>
      unfold linkBodies
      split
      · exact ih _ _ hb
      · rename_i i hi
        apply ih
        rw [insertCandidate_nodes]
        apply bound_modify _ _ _ hb
        intro j _ _
        exact nodeBound_congr _ _ rfl rfl (hb i (get_mem _ _ _ hi).1)

/-- [D] 2026-10-13: failure marking edits status only.
[SRC] src/validation.cpp:4453-4475,5578-5632 at 6504a3af. -/
theorem markInvalid_bound (tree : HeaderTree) (hash : BitVec 256) (markSelf : Bool)
    (hb : ∀ i ∈ tree.nodes, NodeBound i) : ∀ i ∈ (markInvalid tree hash markSelf).nodes, NodeBound i :=
  bound_of_treeCore _ _ (markInvalid_core tree hash markSelf) hb

/-- [D] 2026-10-13: with the default options, an accepted block check bound
the header's merkle root to the body and found no mutation.
[SRC] src/validation.cpp:5768-5782 at 6504a3af. -/
theorem checkBlock_rootBound (params : ChainParams) (cfg : NodeConfig) (block : Block) (height : Nat)
    (h : checkBlock params cfg block height = .ok ()) : RootBound block := by
  unfold checkBlock at h
  simp only [except_bind_ok] at h
  obtain ⟨_, _, h⟩ := h
  cases h2 : (headerWordBytes 32 block.header.merkleRoot.toNat != (blockMerkleRoot block.transactions).root) <;>
    cases h3 : (blockMerkleRoot block.transactions).mutated <;>
    simp only [h2, h3, except_bind_ok, except_throw_bind_ok, except_throw_ok, Bool.false_eq_true,
      ite_false, ite_true, false_and, exists_false] at h
  all_goals exact ⟨by simpa using h2, h3⟩

/-- [D] 2026-10-13: header acceptance adds at most one index, without a body.
[SRC] src/validation.cpp:6134-6197 at 6504a3af. -/
theorem acceptHeader_bound (s t : ChainState) (ctx : ChainContext) (header : BlockHeader) (rank : Nat)
    (hs : BodiesBound s) (h : acceptHeader s ctx header rank = .ok t) : BodiesBound t := by
  unfold acceptHeader at h
  simp only [bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at h
  have fresh : ∀ (index : BlockIndex), index.body = none →
      Except.ok { s with tree := { s.tree with nodes := s.tree.nodes ++ [index] } } = (Except.ok t : Except Reject ChainState) →
      BodiesBound t := by
    intro index hnone he
    injection he with he
    subst he
    intro i hi
    simp only [List.mem_append, List.mem_singleton] at hi
    rcases hi with hi | rfl
    · exact hs i hi
    · intro b hb; simp [hnone] at hb
  split_ifs at h <;> (try split at h) <;> (try split_ifs at h) <;> (try split at h) <;> (try split_ifs at h) <;>
    (try split at h) <;> (try split_ifs at h) <;> (try split at h) <;> (try split at h) <;> (try split at h) <;>
    (try split at h) <;> (try split at h)
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; exact hs)
    | exact fresh _ rfl h

/-- [D] 2026-10-13: body acceptance stores a body only after the block check,
and only in the indices its header hash names.
[SRC] src/validation.cpp:6238-6395,5662-5725 at 6504a3af. -/
theorem acceptBlock_bound (s : ChainState) (ctx : ChainContext) (block : Block) (rank : Nat)
    (requested : Bool) (hs : BodiesBound s) : BodiesBound (acceptBlock s ctx block rank requested).1 := by
  unfold acceptBlock
  split
  · exact hs
  · rename_i s' hh
    have hs' := acceptHeader_bound s s' ctx block.header rank hs hh
    simp only [Id.run, bind, pure]
    split
    · rename_i i hi
      obtain ⟨_, hid⟩ := get_mem _ _ _ hi
      split
      · exact hs'
      split
      · exact hs'
      split
      · intro j hj
        dsimp only at hj
        split at hj
        · exact markInvalid_bound _ _ _ hs' j hj
        · exact hs' j hj
      · rename_i hchecks
        have hcheck : checkBlock ctx.params ctx.cfg block i.height = .ok () := by
          cases hc : checkBlock ctx.params ctx.cfg block i.height with
          | error e => simp [hc, Except.bind] at hchecks
          | ok u => rfl
        have root := checkBlock_rootBound _ _ _ _ hcheck
        have hmod := bound_modify s'.tree i.id
          (fun i => { i with body := some block, txCount := block.transactions.length, status := { i.status with validity := 3 } })
          hs' (by
            intro j _ hj b hb
            simp only [Option.some.injEq] at hb
            subst b
            refine ⟨?_, root⟩
            rw [← hid]
            exact hj)
        intro j hj
        dsimp only at hj
        split at hj
        · exact linkBodies_bound _ _ _ _ hmod j hj
        · split at hj
          · exact hmod j hj
          · exact hmod j hj
    · exact hs'

/-- [D] 2026-10-13: a fold whose every step keeps the tree bound keeps it bound.
[SRC] src/validation.cpp:5528-5562 at 6504a3af. -/
theorem fold_bound {α : Type} (f : HeaderTree → α → HeaderTree) (xs : List α)
    (hf : ∀ tree a, a ∈ xs → (∀ i ∈ tree.nodes, NodeBound i) → ∀ i ∈ (f tree a).nodes, NodeBound i)
    (tree : HeaderTree) (hb : ∀ i ∈ tree.nodes, NodeBound i) :
    ∀ i ∈ (xs.foldl f tree).nodes, NodeBound i := by
  induction xs generalizing tree with
  | nil => exact hb
  | cons a rest ih =>
    exact ih (fun t x hx => hf t x (List.mem_cons_of_mem _ hx)) _ (hf tree a (List.mem_cons_self ..) hb)

/-- [D] 2026-10-13: reconsideration edits failure flags and candidacy, then
activates; no body or header changes.
[SRC] src/rpc/blockchain.cpp:2770-2818 and src/validation.cpp:5528-5562 at 6504a3af. -/
theorem reconsiderBlock_bound (s : ChainState) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (hash : BitVec 256) (fuel : Nat) (hs : BodiesBound s) :
    BodiesBound (reconsiderBlock s ctx lists oracle hash fuel).1 := by
  unfold reconsiderBlock
  apply bound_of_execution (activateBestChain_execution (fun _ => True) ctx lists oracle trivial trivial trivial fuel _)
  intro i hi
  simp only [List.mem_map] at hi
  obtain ⟨j, hj, rfl⟩ := hi
  have hfold := fold_bound _ _ (by
    intro tree x hx htree
    have hxs := (List.mem_filter.mp hx).1
    intro k hk
    split at hk
    all_goals
      refine bound_modify _ _ _ htree ?_ k hk
      intro _ _ _
      exact nodeBound_congr _ _ rfl rfl (hs x hxs)) s.tree hs j hj
  split
  · exact nodeBound_congr _ _ rfl rfl hfold
  · exact hfold

/-- [D] 2026-10-13: precious ordering edits sequence and completion metadata,
prunes candidates, then activates; no body or header changes.
[SRC] src/validation.cpp:5156-5190 at 6504a3af. -/
theorem preciousBlock_bound (s : ChainState) (ctx : ChainContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (hash : BitVec 256) (fuel : Nat) (hs : BodiesBound s) :
    BodiesBound (preciousBlock s ctx lists oracle hash fuel).1 := by
  unfold preciousBlock
  split
  · exact hs
  · dsimp only
    split
    · exact hs
    · apply bound_of_execution (activateBestChain_execution (fun _ => True) ctx lists oracle trivial trivial trivial fuel _)
      split
      · apply bound_of_execution (pruneCandidates_execution (fun _ => True) _)
        intro i hi
        refine bound_modify _ _ _ hs ?_ i hi
        intro x hx _
        exact nodeBound_congr _ _ rfl rfl (hs x hx)
      · intro i hi
        refine bound_modify _ _ _ hs ?_ i hi
        intro x hx _
        exact nodeBound_congr _ _ rfl rfl (hs x hx)

/-- [M] 2026-10-13, #68 G3 (the body binding as an invariant). Every state the
machine's own transitions reach from the empty state keeps every retained body
bound: the index's header hash equals the body's header hash, and the body's
header commits to its transactions with no mutation. Premise in plain words:
the state is reachable (`Reachable`), by any sequence of header and body
acceptance, automatic activation, invalidation, reconsideration, precious
ordering, soft rejection or freeze changes, and pool-only changes, under any
parameters, configuration, operator lists, oracle, ranks, budgets and times.
The binding is established where the body is stored, by the block check, and
nothing else ever writes a body.
[SRC] src/validation.cpp:5770-5781,6238-6395,4913-5330 at 6504a3af. -/
theorem reachable_bodiesBound (s : ChainState) (h : Reachable s) : BodiesBound s := by
  induction h with
  | empty => intro i hi; simp at hi
  | header ctx header rank _ ha ih => exact acceptHeader_bound _ _ ctx header rank ih ha
  | block ctx block rank requested _ ih => exact acceptBlock_bound _ ctx block rank requested ih
  | activate ctx lists oracle fuel _ ih =>
    exact bound_of_execution (activateBestChain_execution (fun _ => True) ctx lists oracle trivial trivial trivial fuel _) ih
  | invalidate ctx lists oracle hash fuel _ ih =>
    exact bound_of_execution (invalidateBlock_execution (fun _ => True) _ ctx lists oracle hash fuel
      trivial trivial trivial trivial) ih
  | reconsider ctx lists oracle hash fuel _ ih => exact reconsiderBlock_bound _ ctx lists oracle hash fuel ih
  | precious ctx lists oracle hash fuel _ ih => exact preciousBlock_bound _ ctx lists oracle hash fuel ih
  | softReject ctx lists oracle hash duration fuel _ ih =>
    exact bound_of_execution (setSoftRejection_execution _ ctx lists oracle hash duration fuel) ih
  | softFreeze ctx lists oracle hash duration fuel _ ih =>
    exact bound_of_execution (setSoftFreeze_execution _ ctx lists oracle hash duration fuel) ih
  | pool p _ ih => exact ih

/-- [D] 2026-10-13: equal header hashes mean equal headers or a SHA256d
collision between their two distinct 80-byte encodings. No axiom: the hash is
the executable definition and the codec round trip is #63's theorem.
[SRC] src/primitives/block.cpp:16-18 and src/primitives/block.h:26-45 at 6504a3af. -/
theorem header_hash_eq (h1 h2 : BlockHeader) (h : h1.hash = h2.hash) :
    h1 = h2 ∨ (h1.encode ≠ h2.encode ∧ sha256d h1.encode = sha256d h2.encode) := by
  have bound (x : Bytes) : leNat (sha256d x) < 2 ^ 256 := by
    have power : (256 : Nat) ^ 32 = 2 ^ 256 := by norm_num
    rw [← power, ← sha256d_length x]
    exact leNat_bytes_lt _ (sha256d_bytes x)
  have hn := congrArg BitVec.toNat h
  simp only [BlockHeader.hash, BitVec.toNat_ofNat, Nat.mod_eq_of_lt (bound _)] at hn
  have hs : sha256d h1.encode = sha256d h2.encode := by
    rw [← headerWordBytes_leNat (sha256d h1.encode) (sha256d_bytes _),
      ← headerWordBytes_leNat (sha256d h2.encode) (sha256d_bytes _), sha256d_length, sha256d_length, hn]
  by_cases he : h1.encode = h2.encode
  · left
    have := header_codec_roundtrip h1
    rw [he, header_codec_roundtrip h2] at this
    exact (Option.some.inj this).symm
  · exact Or.inr ⟨he, hs⟩

/-- [M] 2026-10-13, #68 G3's corollary (#65's inclusion for reachable states,
in the disjunction form of the maintainers' ruling S6-1). In every reachable state,
for an index on the active chain at a height with its body retained: if a
supplied path verifies against that index's header root, then the leaf is the
identifier of a transaction of that body at that active height, or the hash
has a collision between two distinct inputs the two paths touch, or between
the two distinct encodings of the index's header and the body's header.
Premises in plain words: the state is reachable (`hr`); the active chain names
the index at that height (`active`), the tree returns it (`lookup`), its
height is that height (`atHeight`) and it retains the body (`retained`): the
identification of the block, never its authentication; the position is in
range, the supplied path has the body branch's depth, both paths are 32-byte
words and the canonical branch has no null literal (the path shape of #65);
and the path verifies. #65's AuthenticatedBody premise is no longer assumed:
the header/body binding, the root binding and mutation false are proved from
reachability (`reachable_bodiesBound`). No collision freedom is assumed.
[SRC] src/consensus/merkle.cpp:284-327 and src/validation.cpp:5770-5781,6238-6395 at 6504a3af. -/
theorem reachable_path_inclusion_or_collision (s : ChainState) (hr : Reachable s) (height : Nat)
    (i : BlockIndex) (b : Block) (leaf : Bytes) (path : List Bytes) (index : Nat)
    (active : s.active[height]? = some i.id) (lookup : s.tree.get i.id = some i)
    (atHeight : i.height = height) (retained : i.body = some b)
    (range : index < b.transactions.length)
    (depth : path.length = (computeBranch b.transactions index).length)
    (words : PathWords leaf path)
    (canonicalWords : PathWords (BsvScript.Sighash.txid b.transactions[index]) (computeBranch b.transactions index))
    (nonnull : ∀ node ∈ computeBranch b.transactions index, node ≠ BsvScript.Sighash.zero32)
    (valid : verifyPath leaf path index (headerWordBytes 32 i.header.merkleRoot.toNat) = true) :
    (s.active[height]? = some i.id ∧ i.height = height ∧
      ∃ tx ∈ b.transactions, BsvScript.Sighash.txid tx = leaf) ∨
    (∃ u ∈ pathInputs leaf path index ++ pathInputs (BsvScript.Sighash.txid b.transactions[index])
        (computeBranch b.transactions index) index,
      ∃ v ∈ pathInputs leaf path index ++ pathInputs (BsvScript.Sighash.txid b.transactions[index])
        (computeBranch b.transactions index) index, u ≠ v ∧ sha256d u = sha256d v) ∨
    (i.header.encode ≠ b.header.encode ∧ sha256d i.header.encode = sha256d b.header.encode) := by
  obtain ⟨hhash, root, mutated⟩ := reachable_bodiesBound s hr i (get_mem _ _ _ lookup).1 b retained
  rcases header_hash_eq i.header b.header hhash with same | collision
  · have body : AuthenticatedBody s height i b :=
      ⟨active, lookup, atHeight, retained, same, same ▸ root, mutated⟩
    rcases active_path_inclusion_or_collision s height i b leaf path index body range depth words
      canonicalWords nonnull valid with inclusion | pathCollision
    · exact Or.inl inclusion
    · exact Or.inr (Or.inl pathCollision)
  · exact Or.inr (Or.inr collision)

/-- [M] 2026-10-13, #68 G3's corollary, the inclusion form. In every reachable
state, a path that verifies against the header root of an active index with
its body retained proves that the leaf is the identifier of a transaction of
that body, included at that active height. Premises in plain words: those of
`reachable_path_inclusion_or_collision`, plus the explicitly stated commitment
hypothesis that SHA256d has no collision among the inputs the two paths touch
and the two header encodings (`commitment`, a hypothesis of the theorem, never
an axiom: rule 7). #65's AuthenticatedBody is not a premise.
[SRC] src/consensus/merkle.cpp:284-327 and src/validation.cpp:5770-5781,6238-6395 at 6504a3af. -/
theorem reachable_path_inclusion (s : ChainState) (hr : Reachable s) (height : Nat)
    (i : BlockIndex) (b : Block) (leaf : Bytes) (path : List Bytes) (index : Nat)
    (active : s.active[height]? = some i.id) (lookup : s.tree.get i.id = some i)
    (atHeight : i.height = height) (retained : i.body = some b)
    (range : index < b.transactions.length)
    (depth : path.length = (computeBranch b.transactions index).length)
    (words : PathWords leaf path)
    (canonicalWords : PathWords (BsvScript.Sighash.txid b.transactions[index]) (computeBranch b.transactions index))
    (nonnull : ∀ node ∈ computeBranch b.transactions index, node ≠ BsvScript.Sighash.zero32)
    (commitment : HashCommits (pathInputs leaf path index ++
      pathInputs (BsvScript.Sighash.txid b.transactions[index]) (computeBranch b.transactions index) index ++
      [i.header.encode, b.header.encode]))
    (valid : verifyPath leaf path index (headerWordBytes 32 i.header.merkleRoot.toNat) = true) :
    s.active[height]? = some i.id ∧ i.height = height ∧
      ∃ tx ∈ b.transactions, BsvScript.Sighash.txid tx = leaf := by
  rcases reachable_path_inclusion_or_collision s hr height i b leaf path index active lookup atHeight
    retained range depth words canonicalWords nonnull valid with inclusion | pathCollision | headerCollision
  · exact inclusion
  · obtain ⟨u, hu, v, hv, different, equal⟩ := pathCollision
    exact absurd (commitment u (List.mem_append_left _ hu) v (List.mem_append_left _ hv) equal) different
  · exact absurd (commitment _ (by simp) _ (by simp) headerCollision.2) headerCollision.1

end BsvChain.Properties
