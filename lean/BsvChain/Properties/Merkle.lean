import BsvChain.Properties.Chain

/-!
# Header and path inclusion (#65)

[M] 2026-10-13. [SRC] bitcoin-sv v1.2.3 at
6504a3aff65ba97c0f6c80962b033e35ecbfed4b, src/consensus/merkle.cpp:57-178,284-327.
The empty path has no positional information. Inclusion additionally needs
body/header binding, an in-range position, equal branch depths and commitment
on the hashes touched by the paths. AuthenticatedBody names active/tree
lookups, height, retained body, matching headers, root binding and mutation
false. Both paths have 32-byte words; canonical literals are non-null; the
supplied path verifies against the header root. Exact Tx membership also
assumes local txid injectivity. These are premises, never domain axioms.

[LIT] 2026-10-13: BRC-74 BUMP at BRCs commit
793f18685803924e3c6433fa226ee0b5bac0dad0 (transactions/0074.md) and the TSC
merkle proof are client encodings of the leaf, path and index with a header
supplied directly or resolved by height. BUMP can carry multiple paths and
omits the header itself. After projection their root verification is
verifyPath; active header membership is a separate premise. #75 owns the TSC
codec. A one-leaf empty path here is body-derived: the pinned getmerkleproof
returns RPC -5 rather than a proof for that block (src/rpc/rawtransaction.cpp:2302-2306).
-/

namespace BsvChain.Properties
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash

/-- [D] 2026-10-13: a sibling-free check equates only the two byte words.
[SRC] src/consensus/merkle.cpp:291-310 at 6504a3af. -/
theorem verifyPath_empty (leaf root : Bytes) (index : Nat) :
    verifyPath leaf [] index root = true ↔ root = leaf := by
  change (leaf == root) = true ↔ root = leaf
  rw [beq_iff_eq]
  exact eq_comm

/-- [D] 2026-10-13: the next level has the ceiling of half the leaf count.
This establishes sufficient reduction fuel and index range after shifting.
[SRC] src/consensus/merkle.cpp:57-178,263-270 at 6504a3af. -/
theorem merkleLevel_length (xs : List Bytes) :
    (merkleLevel xs).1.length = (xs.length + 1) / 2 := by
  induction xs using merkleLevel.induct with
  | case1 => rfl
  | case2 a => simp only [merkleLevel, List.length_cons, List.length_nil]
  | case3 a b rest next mutated he ih =>
    simp only [merkleLevel, List.length_cons, ih]
    omega

/-- [D] 2026-10-13: an in-range child and its sibling hash to the indexed
parent. This is the pairwise calculation used by completeness; synthetic
padding does not claim a second transaction exists.
[SRC] src/consensus/merkle.cpp:57-178 at 6504a3af. -/
theorem merkleLevel_get (xs : List Bytes) (index : Nat) (hi : index < xs.length) :
    ((merkleLevel xs).1[index / 2]?).getD BsvScript.Sighash.zero32 =
      sha256d (if index % 2 = 1 then
        siblingAt xs index ++ (xs[index]?).getD BsvScript.Sighash.zero32
      else (xs[index]?).getD BsvScript.Sighash.zero32 ++ siblingAt xs index) := by
  induction xs using merkleLevel.induct generalizing index with
  | case1 => simp at hi
  | case2 a =>
    have : index = 0 := by simpa using hi
    subst index; rfl
  | case3 a b rest next mutated he ih =>
    cases index with
    | zero => rfl
    | succ index =>
      cases index with
      | zero => rfl
      | succ index =>
        have hr : index < rest.length := by simpa using hi
        have hd : (index + 2) / 2 = index / 2 + 1 := by omega
        have hm : (index + 2) % 2 = index % 2 := by omega
        simpa only [merkleLevel, ← he, List.getElem?_cons_succ, siblingAt, hd, hm] using ih index hr

/-- [D] 2026-10-13: completeness for the source's literal branch,
assuming an in-range position, enough fuel that the leaf count is at most
fuel plus one, and non-null branch literals. A zero literal is interpreted
as a marker by RootFromBranch. The non-null premise is independent of mutation.
[SRC] src/consensus/merkle.cpp:284-310 at 6504a3af. -/
theorem branchReduce_complete (fuel : Nat) (xs : List Bytes) (index : Nat)
    (hi : index < xs.length) (hf : xs.length ≤ fuel + 1)
    (hn : ∀ node ∈ branchReduce fuel xs index, node ≠ BsvScript.Sighash.zero32) :
    computeRootFromBranch ((xs[index]?).getD BsvScript.Sighash.zero32)
      (branchReduce fuel xs index) index = (merkleReduce fuel xs).root := by
  induction fuel generalizing xs index with
  | zero =>
    cases xs with
    | nil => simp at hi
    | cons a rest =>
      cases rest with
      | nil =>
        have hz : index = 0 := by simpa only [List.length_singleton, Nat.lt_one_iff] using hi
        subst index
        rfl
      | cons b rest => simp at hf
  | succ fuel ih =>
    cases xs with
    | nil => simp at hi
    | cons a rest =>
      cases rest with
      | nil =>
        have hz : index = 0 := by simpa only [List.length_singleton, Nat.lt_one_iff] using hi
        subst index
        rfl
      | cons b rest =>
        let xs := a :: b :: rest
        have hnull : siblingAt xs index ≠ BsvScript.Sighash.zero32 := hn _ (by simp [xs, branchReduce])
        have hr : index / 2 < (merkleLevel xs).1.length := by rw [merkleLevel_length]; dsimp [xs] at *; omega
        have hfuel : (merkleLevel xs).1.length ≤ fuel + 1 := by rw [merkleLevel_length]; dsimp [xs] at *; omega
        have hnodes : ∀ node ∈ branchReduce fuel (merkleLevel xs).1 (index / 2),
            node ≠ BsvScript.Sighash.zero32 := fun node h => hn node (by simp [xs, branchReduce, h])
        have hp := merkleLevel_get xs index hi
        have ht := ih (merkleLevel xs).1 (index / 2) hr hfuel hnodes
        change computeRootFromBranch
          (sha256d ((branchPair ((xs[index]?).getD BsvScript.Sighash.zero32) (siblingAt xs index) index).1 ++
            (branchPair ((xs[index]?).getD BsvScript.Sighash.zero32) (siblingAt xs index) index).2))
          (branchReduce fuel (merkleLevel xs).1 (index / 2)) (index / 2) = _
        simp only [branchPair, beq_iff_eq, hnull, ite_false]
        split
        · simpa only [hp, if_pos ‹index % 2 = 1›, merkleReduce] using ht
        · simpa only [hp, if_neg ‹¬ index % 2 = 1›, merkleReduce] using ht

/-- [D] 2026-10-13: an in-range transaction's generated path verifies the
body root. Mutation false is the block acceptance side condition, although
root recomputation itself also works for mutated bodies. Literal null nodes
need the separate source-marker restriction described above.
[SRC] src/consensus/merkle.cpp:284-327; src/validation.cpp:5770-5781 at 6504a3af. -/
theorem computeBranch_complete (txs : List Tx) (index : Nat) (hi : index < txs.length)
    (_unmutated : (blockMerkleRoot txs).mutated = false)
    (hn : ∀ node ∈ computeBranch txs index, node ≠ BsvScript.Sighash.zero32) :
    verifyPath (BsvScript.Sighash.txid txs[index]) (computeBranch txs index)
      index (blockMerkleRoot txs).root = true := by
  have h := branchReduce_complete txs.length (txs.map BsvScript.Sighash.txid) index
    (by simpa using hi) (by simp) (by simpa [computeBranch] using hn)
  simpa [verifyPath, computeBranch, blockMerkleRoot, computeMerkleRoot,
    List.getElem?_map, List.getElem?_eq_getElem hi] using h

/-- [D] 2026-10-13: the exact hash inputs touched by a path, including
null-marker expansion. [SRC] src/consensus/merkle.cpp:291-308 at 6504a3af. -/
def pathInputs : Bytes → List Bytes → Nat → List Bytes
  | _, [], _ => []
  | leaf, sibling :: rest, index =>
    let pair := branchPair leaf sibling index
    (pair.1 ++ pair.2) :: pathInputs (sha256d (pair.1 ++ pair.2)) rest (index / 2)

/-- [D] 2026-10-13: collision exclusion restricted to supplied inputs.
This is a theorem hypothesis over the executable hash, never an axiom.
[SRC] src/consensus/merkle.cpp:43-50,291-308 at 6504a3af. -/
def HashCommits (inputs : List Bytes) : Prop :=
  ∀ a ∈ inputs, ∀ b ∈ inputs, sha256d a = sha256d b → a = b

/-- [D] 2026-10-13: fixed-width words prevent ambiguous concatenation.
[SRC] src/consensus/merkle.cpp:291-308 at 6504a3af. -/
def PathWords (leaf : Bytes) (path : List Bytes) : Prop :=
  leaf.length = 32 ∧ ∀ sibling ∈ path, sibling.length = 32

/-- [D] 2026-10-13: assuming all four leaf/sibling words have 32 bytes
and the two ordered concatenations are equal at the same supplied index,
the working leaves are equal. The marker still puts the working leaf on
the index-selected side.
[SRC] src/consensus/merkle.cpp:296-306 at 6504a3af. -/
theorem branchPair_leaf (a b c d : Bytes) (index : Nat)
    (ha : a.length = 32) (hb : b.length = 32)
    (hc : c.length = 32) (hd : d.length = 32)
    (he : (branchPair a b index).1 ++ (branchPair a b index).2 =
      (branchPair c d index).1 ++ (branchPair c d index).2) : a = c := by
  have leftLength (x y : Bytes) (hx : x.length = 32) (hy : y.length = 32) :
      (branchPair x y index).1.length = 32 := by
    by_cases hz : y = BsvScript.Sighash.zero32 <;>
      by_cases hi : index % 2 = 1 <;> simp only [branchPair, beq_iff_eq, hz, hi, ite_true, ite_false, hx, hy]
  have hl := leftLength a b ha hb
  have hl' := leftLength c d hc hd
  have ht := congrArg (List.take 32) he
  have hr := congrArg (List.drop 32) he
  rw [← hl, List.take_left, hl, ← hl', List.take_left] at ht
  rw [← hl, List.drop_left, hl, ← hl', List.drop_left] at hr
  by_cases hz : b = BsvScript.Sighash.zero32 <;>
    by_cases hz' : d = BsvScript.Sighash.zero32 <;>
      by_cases hi : index % 2 = 1 <;>
        simp only [branchPair, beq_iff_eq, hz, hz', hi, ite_true, ite_false] at ht hr <;>
          assumption

/-- [D] 2026-10-13: two equal-depth paths at the same supplied index,
with 32-byte leaves and siblings and equal computed roots, have equal leaves
under the explicit HashCommits hypothesis: SHA256d is injective on the
inputs touched by these two paths. Siblings may be externally supplied;
canonical sibling equality is not a premise. [SRC] src/consensus/merkle.cpp:291-310 at 6504a3af. -/
theorem path_leaf_of_commitment (a c : Bytes) (p q : List Bytes) (index : Nat)
    (depth : p.length = q.length) (wp : PathWords a p) (wq : PathWords c q)
    (commitment : HashCommits (pathInputs a p index ++ pathInputs c q index))
    (roots : computeRootFromBranch a p index = computeRootFromBranch c q index) : a = c := by
  induction p generalizing a c q index with
  | nil => cases q <;> simp_all [computeRootFromBranch]
  | cons b rest ih =>
    cases q with
    | nil => simp at depth
    | cons d tail =>
      let x := branchPair a b index
      let y := branchPair c d index
      have htail : HashCommits (pathInputs (sha256d (x.1 ++ x.2)) rest (index / 2) ++
          pathInputs (sha256d (y.1 ++ y.2)) tail (index / 2)) := by
        intro u hu v hv he
        apply commitment u _ v _ he
        · simp only [pathInputs, List.mem_append, List.mem_cons] at *
          exact hu.elim (fun h => Or.inl (Or.inr h)) (fun h => Or.inr (Or.inr h))
        · simp only [pathInputs, List.mem_append, List.mem_cons] at *
          exact hv.elim (fun h => Or.inl (Or.inr h)) (fun h => Or.inr (Or.inr h))
      have hhash : sha256d (x.1 ++ x.2) = sha256d (y.1 ++ y.2) :=
        ih _ _ tail (index / 2) (by simpa using depth)
          ⟨sha256d_length _, fun s hs => wp.2 s (List.mem_cons_of_mem _ hs)⟩
          ⟨sha256d_length _, fun s hs => wq.2 s (List.mem_cons_of_mem _ hs)⟩
          htail roots
      have he : x.1 ++ x.2 = y.1 ++ y.2 :=
        commitment _ (by simp [pathInputs, x]) _ (by simp [pathInputs, y]) hhash
      exact branchPair_leaf a b c d index wp.1 (wp.2 b (by simp)) wq.1 (wq.2 d (by simp)) he

/-- [D] 2026-10-13: assuming equal path depths, a common supplied index,
32-byte leaves and siblings on both paths, and equal computed roots, the
leaves are equal or two distinct touched inputs have equal SHA256d outputs.
The collision witness is restricted to these two paths. No HashCommits
hypothesis is needed for this disjunction.
[SRC] src/consensus/merkle.cpp:43-50,291-310 at 6504a3af. -/
theorem path_leaf_or_collision (a c : Bytes) (p q : List Bytes) (index : Nat)
    (depth : p.length = q.length) (wp : PathWords a p) (wq : PathWords c q)
    (roots : computeRootFromBranch a p index = computeRootFromBranch c q index) :
    a = c ∨ ∃ u ∈ pathInputs a p index ++ pathInputs c q index,
      ∃ v ∈ pathInputs a p index ++ pathInputs c q index, u ≠ v ∧ sha256d u = sha256d v := by
  classical
  by_cases h : HashCommits (pathInputs a p index ++ pathInputs c q index)
  · exact Or.inl (path_leaf_of_commitment a c p q index depth wp wq h roots)
  · right
    simp only [HashCommits, not_forall, Classical.not_imp] at h
    obtain ⟨u, hu, v, hv, equal, different⟩ := h
    exact ⟨u, hu, v, hv, different, equal⟩

/-- [D] 2026-10-13: AuthenticatedBody explicitly requires the active-height
lookup to return the index identifier, the tree lookup to return that index,
the index height to equal the supplied height, and the index to retain the
supplied body. It also requires matching index/body headers, equality of
the header merkle root and body root, and mutation false. This local
refinement is explicit because #64's state also represents missing/pruned bodies.
It is not a claim that arbitrary ChainState records have been validated.
[SRC] src/validation.cpp:5770-5781,4345-4404 at 6504a3af. -/
def AuthenticatedBody (s : ChainState) (height : Nat) (i : BlockIndex) (b : Block) : Prop :=
  s.active[height]? = some i.id ∧ s.tree.get i.id = some i ∧ i.height = height ∧
  i.body = some b ∧ i.header = b.header ∧
  headerWordBytes 32 i.header.merkleRoot.toNat = (blockMerkleRoot b.transactions).root ∧
  (blockMerkleRoot b.transactions).mutated = false

/-- [D] 2026-10-13: identifier inclusion at the active height or a collision
between distinct touched inputs, assuming AuthenticatedBody as fully unpacked
in its explainer above: active-height lookup, tree lookup, matching height,
retained body, matching headers, header/body-root binding and mutation false.
The position must be in range; the supplied path must have the body branch
depth at that same index; both paths must have 32-byte leaves and siblings;
canonical branch literals must be non-null. The supplied path must verify
successfully against the header merkle root. No HashCommits hypothesis is
needed for this identifier-membership-or-collision disjunction.
[SRC] src/consensus/merkle.cpp:284-327; src/validation.cpp:5770-5781 at 6504a3af. -/
theorem active_path_inclusion_or_collision (s : ChainState) (height : Nat)
    (i : BlockIndex) (b : Block) (leaf : Bytes) (path : List Bytes) (index : Nat)
    (body : AuthenticatedBody s height i b) (range : index < b.transactions.length)
    (depth : path.length = (computeBranch b.transactions index).length)
    (words : PathWords leaf path)
    (canonicalWords : PathWords (BsvScript.Sighash.txid b.transactions[index]) (computeBranch b.transactions index))
    (nonnull : ∀ node ∈ computeBranch b.transactions index, node ≠ BsvScript.Sighash.zero32)
    (valid : verifyPath leaf path index (headerWordBytes 32 i.header.merkleRoot.toNat) = true) :
    (s.active[height]? = some i.id ∧ i.height = height ∧
      ∃ tx ∈ b.transactions, BsvScript.Sighash.txid tx = leaf) ∨
    ∃ u ∈ pathInputs leaf path index ++ pathInputs (BsvScript.Sighash.txid b.transactions[index])
        (computeBranch b.transactions index) index,
      ∃ v ∈ pathInputs leaf path index ++ pathInputs (BsvScript.Sighash.txid b.transactions[index])
        (computeBranch b.transactions index) index, u ≠ v ∧ sha256d u = sha256d v := by
  have complete := computeBranch_complete b.transactions index range body.2.2.2.2.2.2 nonnull
  have roots : computeRootFromBranch leaf path index =
      computeRootFromBranch (BsvScript.Sighash.txid b.transactions[index]) (computeBranch b.transactions index) index := by
    simp only [verifyPath, beq_iff_eq] at valid complete
    exact valid.trans (body.2.2.2.2.2.1.trans complete.symm)
  rcases path_leaf_or_collision leaf _ path _ index depth words canonicalWords roots with same | collision
  · exact Or.inl ⟨body.1, body.2.2.1, b.transactions[index], List.getElem_mem range, same.symm⟩
  · exact Or.inr collision

/-- [D] 2026-10-13: wallet identifier inclusion at the named active height
assumes AuthenticatedBody: active-height lookup, tree lookup, matching height,
retained body, matching headers, header/body-root binding and mutation false.
It also assumes an in-range position, equal supplied/body branch depth at
the same index, 32-byte leaves and siblings on both paths, non-null canonical
literals, and successful verification against the header merkle root.
HashCommits is an explicit hypothesis excluding distinct-input SHA256d
collisions on the inputs touched by these two paths, never an axiom.
[SRC] src/consensus/merkle.cpp:43-50,284-327 at 6504a3af. -/
theorem active_path_inclusion (s : ChainState) (height : Nat)
    (i : BlockIndex) (b : Block) (leaf : Bytes) (path : List Bytes) (index : Nat)
    (body : AuthenticatedBody s height i b) (range : index < b.transactions.length)
    (depth : path.length = (computeBranch b.transactions index).length)
    (words : PathWords leaf path)
    (canonicalWords : PathWords (BsvScript.Sighash.txid b.transactions[index]) (computeBranch b.transactions index))
    (nonnull : ∀ node ∈ computeBranch b.transactions index, node ≠ BsvScript.Sighash.zero32)
    (commitment : HashCommits (pathInputs leaf path index ++
      pathInputs (BsvScript.Sighash.txid b.transactions[index]) (computeBranch b.transactions index) index))
    (valid : verifyPath leaf path index (headerWordBytes 32 i.header.merkleRoot.toNat) = true) :
    s.active[height]? = some i.id ∧ i.height = height ∧
      ∃ tx ∈ b.transactions, BsvScript.Sighash.txid tx = leaf := by
  rcases active_path_inclusion_or_collision s height i b leaf path index body range depth words
    canonicalWords nonnull valid with inclusion | collision
  · exact inclusion
  · obtain ⟨u, hu, v, hv, different, equal⟩ := collision
    exact False.elim (different (commitment u hu v hv equal))

/-- [D] 2026-10-13: exact Lean transaction membership assumes AuthenticatedBody:
active-height lookup, tree lookup, matching height, retained body, matching
headers, header/body-root binding and mutation false. It also assumes an
in-range position, equal supplied/body branch depth at the same index,
32-byte leaves and siblings on both paths, non-null canonical literals,
HashCommits on their touched inputs, and successful verification of the
supplied transaction identifier against the header merkle root. The additional
local txid injectivity premise says every body transaction with that identifier
equals the supplied transaction. It excludes distinct aliases on this local
domain; it does not exclude the same noncanonical record whose serializer
truncates wire fields.
[SRC] src/consensus/merkle.cpp:312-327 at 6504a3af. -/
theorem active_path_transaction (s : ChainState) (height : Nat) (i : BlockIndex)
    (b : Block) (tx : Tx) (path : List Bytes) (index : Nat)
    (body : AuthenticatedBody s height i b) (range : index < b.transactions.length)
    (depth : path.length = (computeBranch b.transactions index).length)
    (words : PathWords (BsvScript.Sighash.txid tx) path)
    (canonicalWords : PathWords (BsvScript.Sighash.txid b.transactions[index]) (computeBranch b.transactions index))
    (nonnull : ∀ node ∈ computeBranch b.transactions index, node ≠ BsvScript.Sighash.zero32)
    (commitment : HashCommits (pathInputs (BsvScript.Sighash.txid tx) path index ++
      pathInputs (BsvScript.Sighash.txid b.transactions[index]) (computeBranch b.transactions index) index))
    (identity : ∀ other ∈ b.transactions, BsvScript.Sighash.txid other = BsvScript.Sighash.txid tx → other = tx)
    (valid : verifyPath (BsvScript.Sighash.txid tx) path index (headerWordBytes 32 i.header.merkleRoot.toNat) = true) :
    tx ∈ b.transactions ∧ ActiveTransaction s.tree s.active tx := by
  obtain ⟨active, _, other, hm, he⟩ := active_path_inclusion s height i b _ path index
    body range depth words canonicalWords nonnull commitment valid
  have membership : tx ∈ b.transactions := identity other hm he ▸ hm
  exact ⟨membership, i.id, List.mem_of_getElem? active, b, by simp [body.2.1, body.2.2.2.1], membership⟩

/-- [D] 2026-10-13: stale-header path evidence, including retained body
membership. There is no active-header premise.
[SRC] src/consensus/merkle.cpp:291-310; src/validation.cpp:4117 at 6504a3af. -/
def StalePath (s : ChainState) (i : BlockIndex) (tx : Tx) (path : List Bytes) (index : Nat) : Prop :=
  i.id ∉ s.active ∧ ∃ b, s.tree.get i.id = some i ∧ i.body = some b ∧
    i.header = b.header ∧ tx ∈ b.transactions ∧
    verifyPath (BsvScript.Sighash.txid tx) path index (headerWordBytes 32 i.header.merkleRoot.toNat) = true

/-- [D] 2026-10-13: a small retained-body witness of #64's raw state type.
The nonempty validated-chain execution is checked separately in ChainCheck;
this minimal logical countermodel makes no block-validation claim.
[SRC] src/primitives/block.h:79-107 at 6504a3af. -/
def staleWitnessTx : Tx := ⟨1, [], [], 0⟩

/-- [D] 2026-10-13: singleton body, whose empty path is body-derived.
[SRC] src/consensus/merkle.cpp:247-255,291-310 at 6504a3af. -/
def staleWitnessBlock : Block :=
  ⟨⟨1, 0, BitVec.ofNat 256 (leNat (BsvScript.Sighash.txid staleWitnessTx)), 0, 0, 0⟩, [staleWitnessTx]⟩

/-- [D] 2026-10-13: retain the stale body outside an empty active projection.
[SRC] src/block_index.h:330-349 at 6504a3af. -/
def staleWitnessIndex : BlockIndex :=
  { header := staleWitnessBlock.header, parent := none, height := 0, work := 0,
    tieRank := 0, body := some staleWitnessBlock }

/-- [D] 2026-10-13: no active bodies exist in the minimal countermodel.
[SRC] src/validation.cpp:4117 at 6504a3af. -/
def staleWitnessState : ChainState := { tree := { nodes := [staleWitnessIndex] } }

/-- [D] 2026-10-13: bounded byte words fit their little-endian frame.
This permits header normalization without evaluating a hash in the kernel.
[SRC] src/primitives/block.h:26-45 at 6504a3af. -/
theorem leNat_bytes_lt (bs : Bytes) (hb : ∀ b ∈ bs, b < 256) :
    leNat bs < 256 ^ bs.length := by
  induction bs with
  | nil => simp [leNat]
  | cons b rest ih =>
    have head := hb b (by simp)
    have tail := ih (fun x hx => hb x (List.mem_cons_of_mem _ hx))
    simp only [leNat, List.length_cons, Nat.pow_succ] at *
    omega

/-- [D] 2026-10-13: byte-valued words survive header encode after decode.
[SRC] src/primitives/block.h:26-45 at 6504a3af. -/
theorem headerWordBytes_leNat (bs : Bytes) (hb : ∀ b ∈ bs, b < 256) :
    headerWordBytes bs.length (leNat bs) = bs := by
  induction bs with
  | nil => rfl
  | cons b rest ih =>
    have head := hb b (by simp)
    have hm : (b + 256 * leNat rest) % 256 = b := by omega
    have hd : (b + 256 * leNat rest) / 256 = leNat rest := by omega
    simpa only [List.length_cons, leNat, headerWordBytes, hm, hd] using
      congrArg (b :: ·) (ih (fun x hx => hb x (List.mem_cons_of_mem _ hx)))

/-- [D] 2026-10-13: the existing hash emits byte-valued words. This is
representation, not a cryptographic assumption.
[SRC] src/consensus/merkle.cpp:291-310 (uint256 hash words) at 6504a3af. -/
theorem sha256d_bytes (input : Bytes) : ∀ b ∈ sha256d input, b < 256 := by
  intro b hb
  obtain ⟨word, hw, hm⟩ := List.mem_flatten.mp hb
  obtain ⟨value, _, rfl⟩ := List.mem_map.mp hw
  simp only [wordBytes, List.mem_cons, List.not_mem_nil, or_false] at hm
  rcases hm with rfl | rfl | rfl | rfl <;> exact Nat.mod_lt _ (by decide)

/-- [D] 2026-10-13: the countermodel has a header-valid body-derived path,
yet no active transaction. This kernel proof uses neither native_decide nor
an assumption about SHA256. The executable transition witness uses a mined
two-transaction body instead of this minimal raw-state countermodel.
[SRC] src/consensus/merkle.cpp:291-310 at 6504a3af. -/
theorem stale_path_witness :
    StalePath staleWitnessState staleWitnessIndex staleWitnessTx [] 0 ∧
      ¬ ActiveTransaction staleWitnessState.tree staleWitnessState.active staleWitnessTx := by
  constructor
  · refine ⟨by simp [staleWitnessState], staleWitnessBlock, ?_, rfl, rfl, by simp [staleWitnessBlock], ?_⟩
    · simp only [staleWitnessState, HeaderTree.get, List.find?_cons, beq_self_eq_true, ite_true]
    · apply (verifyPath_empty _ _ _).2
      change headerWordBytes 32 (BitVec.ofNat 256 (leNat (BsvScript.Sighash.txid staleWitnessTx))).toNat = _
      have hb := sha256d_bytes (BsvScript.Sighash.serTx staleWitnessTx)
      have hl : (BsvScript.Sighash.txid staleWitnessTx).length = 32 := sha256d_length _
      have bound : leNat (BsvScript.Sighash.txid staleWitnessTx) < 2 ^ 256 := by
        have power : 256 ^ 32 = 2 ^ 256 := by norm_num
        rw [← power, ← hl]
        exact leNat_bytes_lt _ hb
      rw [BitVec.toNat_ofNat, Nat.mod_eq_of_lt bound, ← hl]
      exact headerWordBytes_leNat _ hb
  · simp [ActiveTransaction, staleWitnessState]

/-- [D] 2026-10-13: stale-header validity does not imply active-body inclusion.
The counterexample refutes the universal implication even when the retained
stale body contains the transaction. A stronger valid-transition witness is
executed by ChainCheck's orphanedProofCase on the assumed intake prefix.
[SRC] src/consensus/merkle.cpp:291-310; src/validation.cpp:5230-5330 at 6504a3af. -/
theorem stale_path_does_not_entail_active :
    ¬ (∀ s i tx path index, StalePath s i tx path index → ActiveTransaction s.tree s.active tx) := by
  intro claim
  exact stale_path_witness.2 (claim _ _ _ _ _ stale_path_witness.1)

end BsvChain.Properties
