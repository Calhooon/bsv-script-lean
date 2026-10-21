import BsvChain.Properties.Merkle

/-!
# Teranode's subtree merkle root against the reference's flat root (#89)

[M] 2026-10-14 (#89). The two pins: Teranode `v0.16.0` =
`4edb60a40c6628ff0ef60231c2628efd7103fde5` and its go-subtree module `v1.5.1`
(go.mod:17, go.sum:142 `h1:l/Qui+HT+yQKXIoCW4zAyBlD2St9iLjC9ydvzcr9YSM=`);
bitcoin-sv `v1.2.3` = `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.

[SRC] Teranode validates a body's merkle root in model/Block.go:2709-2771
(`CheckMerkleRoot`): the leading subtree's root with the coinbase txid put in
place of its placeholder (:2737, via `RootHashWithReplaceRootNode`,
subtree.go:544-562 (v1.5.1), which recomputes from the nodes (it never reads
the cache)), every other subtree's `RootHash` (:2744), and for more than one
subtree `blockMerkleRoot` (:2793-2879): the shape rules of
model/subtree_body_shape.go:37-60 (the leading subtree's leaf count a power
of two, the middle ones equal to it, the last one no longer), the last root
lifted to the leading subtree's height when short (the power-of-two note
Block.go:2820-2833; the lift :2852-2876), and `ComposeSubtreeRootsToMerkleRoot`
(subtree_body_shape.go:75-103): a duplicate-root scan, then one more go-subtree
tree over the roots. The leading root, the top tree and the root of a subtree
built in memory are go-subtree's `BuildMerkleTreeStoreFromBytes`
(merkle_tree.go:45-94 at v1.5.1), which pads the level to a power of two with
the zero word and treats the zero word as "no node" (merkle_tree.go:127-161).
For a subtree read from storage `RootHash` is the header's cached claim
(subtree.go:481-483,837-839): the model takes it as `claim`, and the theorem
takes `RootsAnchored`, the binding of claim = recomputed = key that quick
validation runs (services/blockvalidation/quick_validate.go:1292-1304,
model/subtree_meta_reader.go:57-111); the stored-load path of Block.Valid
checks the claim against the key only (model/Block.go:2423-2433).

[SRC] The reference hashes the flat list of transaction ids
(src/consensus/merkle.cpp:312-319 `BlockMerkleRoot`) with the duplicate-last
rule (stated at merkle.cpp:21-24; done at :215-222,239-244,269-270) and the mutation flag (merkle.cpp:210-213); #63's
`computeMerkleRoot` is that computation.

[D] What is proven here, for every list of transaction ids and every subtree
size that is a power of two (the dynamic-size flag of settings.go:313 only
chooses the size, so it is a parameter):

* `compose_eq_flat`: the root over the subtree roots, the last one lifted,
  equals the flat root, and the flat `mutated` flag is the OR of every
  subtree's flag and the top tree's flag. No premise beyond the shape.
* `storeRoot_eq_computeMerkleRoot`: go-subtree's zero-sentinel builder equals
  the reference's root when no paired word is the zero word.
* `subtreeRoot_eq_blockMerkleRoot`: every root Teranode's check accepts is the
  flat `BlockMerkleRoot` root, for every body shape a peer can send, under
  `BodyNonzero` (no word Teranode's builder pairs in this body is the zero
  word: go-subtree reads it as "no node", merkle_tree.go:138-140; neither
  source checks it; a body that breaks it carries a SHA256d preimage of the
  zero word) and `RootsAnchored` (every stored subtree's header root equals
  its nodes' root). `ZeroFree` is a sufficient condition for `BodyNonzero`
  (`bodyNonzero_of_zeroFree`), not the premise of record.
* `zero_leaf_counterexample`: the zero-word premise is needed by the model:
  at a zero transaction id the builder and the reference disagree.
  Infeasible: a zero txid needs a SHA256d preimage of the zero word.

The mutation flag has no counterpart in Teranode's root: it rejects a repeated
subtree root (any two, not only siblings) and a repeated transaction id
(model/Block.go:912-940); the flag's decomposition is `compose_eq_flat`'s
second half, and the vectors of `corpus/merkle/subtree-vectors.jsonl` carry
both behaviors per case.
-/

namespace BsvChain.Teranode
open BsvScript.Numbers BsvScript.Hash BsvChain BsvChain.Properties

/-- [SRC] The zero word that go-subtree's builder reads as "no node":
`chainhash.Hash{}`, merkle_tree.go:127-133,139-140 (go-subtree v1.5.1, the
module Teranode 4edb60a4 pins at go.mod:17). It is the reference's null word,
src/consensus/merkle.cpp:247-255 at 6504a3af (the empty list's root). -/
abbrev zeroHash : Bytes := BsvScript.Sighash.zero32

/-- [SRC] go-subtree's `CoinbasePlaceholder`, thirty-two 0xFF bytes,
coinbase_placeholder.go:13-18 (v1.5.1); block assembly puts it at index 0 of
the leading subtree (services/blockassembly/subtreeprocessor/SubtreeProcessor.go:609
at 4edb60a4) and model/Block.go:891 requires it there before the root check.
The reference has no placeholder: its index 0 is the coinbase txid,
src/consensus/merkle.cpp:312-319 at 6504a3af. -/
def coinbasePlaceholder : Bytes := List.replicate 32 0xff

/-- [SRC] go-subtree's `calcMerkle`, merkle_tree.go:136-161 (v1.5.1): a zero
left child makes a zero parent, a zero right child hashes the left one with
itself, otherwise the double SHA-256 of the two. The reference pairs the same
way without a sentinel and pads an odd level with its last hash,
src/consensus/merkle.cpp:21-24,227-237 at 6504a3af. -/
def calcMerkle (l r : Bytes) : Bytes :=
  if l = zeroHash then zeroHash
  else if r = zeroHash then sha256d (l ++ l)
  else sha256d (l ++ r)

/-- [SRC] One level of `BuildMerkleTreeStoreFromBytes`: adjacent pairs through
`calcMerkle`, merkle_tree.go:97-124 (v1.5.1); `getNodeHashAt` reads the zero
word past the end (:127-133), the `[a]` case. The reference's level is
`merkleLevel`, src/consensus/merkle.cpp:210-236 at 6504a3af. -/
def pairLevel : List Bytes → List Bytes
  | [] => []
  | [a] => [calcMerkle a zeroHash]
  | a :: b :: rest => calcMerkle a b :: pairLevel rest

/-- [SRC] Go's `bits.Len`, the bit length, which go-subtree's `RootHashPadded`
uses for a subtree's natural height, subtree.go:526 (v1.5.1). Teranode reads
the reference's binary counter only through the root, src/consensus/merkle.cpp:247-282
at 6504a3af. -/
def bitLen (n : Nat) : Nat := if h : n = 0 then 0 else bitLen (n / 2) + 1
decreasing_by omega

/-- [SRC] A tree's height, `ceil(log2 n)`: `bits.Len(length-1)` at subtree.go:526
and `math.Ceil(math.Log2(n))` at merkle_tree.go:66 and at the deserializer's
`Height`, subtree.go:925,976 (v1.5.1); the two agree on every count below
2^32 [D]. The reference's level count is the same, src/consensus/merkle.cpp:239-244,273-280
at 6504a3af. -/
def treeHeight (n : Nat) : Nat := bitLen (n - 1)

/-- [SRC] `k` levels of `pairLevel`, the loop of merkle_tree.go:70-91 (v1.5.1).
The reference iterates `merkleLevel`, src/consensus/merkle.cpp:263-280 at 6504a3af. -/
def iterLevels : Nat → List Bytes → List Bytes
  | 0, xs => xs
  | k + 1, xs => iterLevels k (pairLevel xs)

/-- [SRC] The last entry of `BuildMerkleTreeStoreFromBytes`, which is what
`RootHash` returns for a subtree built in memory; for one read from storage
`RootHash` is the header's cached claim (subtree.go:481-483,837-839), equal to
this under `RootsAnchored`, subtree.go:476-498 and merkle_tree.go:45-94 (v1.5.1): no
root for an empty subtree (`RootHash` nil, model/Block.go:2744-2748 at 4edb60a4),
the node itself for one node (:58-62), else the level padded with zero words
to the next power of two and reduced. The reference: src/consensus/merkle.cpp:247-282
at 6504a3af. -/
def storeRoot (nodes : List Bytes) : Option Bytes :=
  match nodes with
  | [] => none
  | [a] => some a
  | _ => (iterLevels (treeHeight nodes.length)
      (nodes ++ List.replicate (2 ^ treeHeight nodes.length - nodes.length) zeroHash)).head?

/-- [SRC] One self-hash, `H(prev, prev)`, of `RootHashPadded`, subtree.go:532-538
(v1.5.1); the reference's odd-level rule, src/consensus/merkle.cpp:215-222,270-271 at 6504a3af. -/
def selfHash (x : Bytes) : Bytes := sha256d (x ++ x)

/-- [SRC] The lift of `RootHashPadded` by `k` self-hashes, subtree.go:516-541
(v1.5.1); src/consensus/merkle.cpp:215-222,270-271 at 6504a3af. -/
def liftRoot (k : Nat) (x : Bytes) : Bytes := selfHash^[k] x

/-- [SRC] `RootHashPadded(targetHeight)`, subtree.go:516-541 (v1.5.1): no root
for an empty subtree (:521-524), refused when the target is lower than the
natural height `bits.Len(length-1)` (:526-529), else `root`, the subtree's
`RootHash` (:531: the header's cached claim for a stored subtree), lifted by
self-hashes (:532-538, no zero-word test); called for a short last subtree at
model/Block.go:2867-2876 at 4edb60a4. The reference lifts the same way inside
its binary counter: `lift_combine` raises the shorter partial tree by `lift`'s
self-hash, src/consensus/merkle.cpp:215-222,239-244 at 6504a3af. -/
def rootHashPadded (target : Nat) (root : Bytes) (nodes : List Bytes) : Option Bytes :=
  match nodes with
  | [] => none
  | _ => if target < treeHeight nodes.length then none
      else some (liftRoot (target - treeHeight nodes.length) root)

/-- [SRC] `ReplaceRootNode`, subtree.go:290-306 (v1.5.1): index 0 replaced, or
the node appended to an empty subtree; `CheckMerkleRoot` replaces the leading
subtree's placeholder by the coinbase txid, model/Block.go:2736-2737 at 4edb60a4,
via `RootHashWithReplaceRootNode`, subtree.go:544-562 (v1.5.1), which recomputes
from the nodes (it never reads the cache).
src/consensus/merkle.cpp:312-319 at 6504a3af reads the coinbase txid at index 0. -/
def replaceRoot (node : Bytes) : List Bytes → List Bytes
  | [] => [node]
  | _ :: rest => node :: rest

/-- [SRC] Go's `IsPowerOfTwo`, power_of_two.go:24-30 (v1.5.1), as
model/subtree_body_shape.go:38 calls it on the leading subtree's length at
4edb60a4. The reference has no subtree: src/consensus/merkle.cpp:312-319 at 6504a3af. -/
def goIsPowerOfTwo (n : Nat) : Bool := n != 0 && (n &&& (n - 1)) == 0

/-- [SRC] `CheckSubtreeShape` for the subtrees after the leading one,
model/subtree_body_shape.go:45-57 at 4edb60a4 (every one but the last equal to
the target, the last no longer). The reference: src/consensus/merkle.cpp:312-319
at 6504a3af has one flat list. -/
def shapeOk (target : Nat) : List Nat → Bool
  | [] => true
  | [l] => decide (l ≤ target)
  | l :: m :: rest => l == target && shapeOk target (m :: rest)

/-- [SRC] The roots of the subtrees after the leading one: `RootHash`
(model/Block.go:2744 at 4edb60a4), `claim s` here: the header's cached root for
a subtree read from storage (go-subtree subtree.go:481-483,837-839, v1.5.1),
`recomputed` for one built in memory; the last one replaced by its
`RootHashPadded` to the leading subtree's height when it is short (:2867-2876).
The target height is `firstSubtree.Height`, model/Block.go:2813:
ceil(log2 length) for a stored subtree (subtree.go:925,976), the capacity's
height for one built in memory (subtree.go:79-110), equal when the leading
subtree is full (services/legacy/netsync/handle_block.go:430-456 at 4edb60a4).
`RootHashPadded` returns no root and no error for an empty subtree
(subtree.go:521-524) and Block.go:2868-2873 dereferences the result without a
nil test; the model reads it as no root (`none`); whether an empty last
subtree reaches that line was not read. src/consensus/merkle.cpp:247-282 at
6504a3af is the flat counterpart. -/
def restRoots (claim : List Bytes → Bytes) (target : Nat) : List (List Bytes) → Option (List Bytes)
  | [] => some []
  | [last] => if last.length < target then
        (rootHashPadded (treeHeight target) (claim last) last).map ([·])
      else some [claim last]
  | s :: m :: more => (restRoots claim target (m :: more)).map (claim s :: ·)

/-- [SRC] `ComposeSubtreeRootsToMerkleRoot`, model/subtree_body_shape.go:75-103
at 4edb60a4: a repeated root is refused (:81-88) and `AddNode` refuses the
placeholder (go-subtree subtree.go:421-423, v1.5.1); the rest is one more
`BuildMerkleTreeStoreFromBytes` over the roots (:95). The reference refuses
only equal siblings, through `mutated`: src/consensus/merkle.cpp:210-213 at 6504a3af. -/
def composeTop (roots : List Bytes) : Option Bytes :=
  if roots.Nodup ∧ coinbasePlaceholder ∉ roots then storeRoot roots else none

/-- [SRC] Teranode's root of a body: `CheckMerkleRoot` and `blockMerkleRoot`,
model/Block.go:2709-2771,2793-2879 at 4edb60a4. No subtree: the coinbase txid
(:2760-2761). One subtree: its root with the coinbase in place, with no shape
rule (:2794-2796; subtree_body_shape.go:28-33). More: the shape rules, the
lift, the composition. `none` is every error return. `claim` is the
`RootHash` of a subtree after the leading one (`restRoots`). The reference's root is
`computeMerkleRoot` of `flatLeaves`, src/consensus/merkle.cpp:312-319 at 6504a3af. -/
def checkMerkleRoot (claim : List Bytes → Bytes) (coinbase : Bytes) : List (List Bytes) → Option Bytes
  | [] => some coinbase
  | [lead] => storeRoot (replaceRoot coinbase lead)
  | lead :: s :: more =>
    if goIsPowerOfTwo lead.length && shapeOk lead.length ((s :: more).map List.length) then
      match storeRoot (replaceRoot coinbase lead), restRoots claim lead.length (s :: more) with
      | some r0, some rs => composeTop (r0 :: rs)
      | _, _ => none
    else none

/-- [SRC] The transaction ids the reference hashes for the same body: the
coinbase txid, then every subtree's nodes in order, src/consensus/merkle.cpp:312-319
at 6504a3af; Teranode's order is the subtrees' (model/Block.go:2720-2751 at 4edb60a4). -/
def flatLeaves (coinbase : Bytes) : List (List Bytes) → List Bytes
  | [] => [coinbase]
  | lead :: rest => replaceRoot coinbase lead ++ rest.flatten

/-- [SRC] Block assembly's partition: subtrees of `size` nodes, a new one when
the current is full, the last one partial; the coinbase placeholder at index 0
of the leading one (services/blockassembly/subtreeprocessor/SubtreeProcessor.go:601-611
at 4edb60a4, `NewTreeByLeafCount` refusing a size that is not a power of two,
go-subtree subtree.go:97-105, v1.5.1). The reference has one list:
src/consensus/merkle.cpp:312-319 at 6504a3af. -/
def partition (size : Nat) (xs : List Bytes) : List (List Bytes) :=
  if _h : size = 0 ∨ xs.length ≤ size then [xs]
  else xs.take size :: partition size (xs.drop size)
termination_by xs.length
decreasing_by simp only [List.length_drop]; omega

/-- [SRC] The subtree size block assembly uses: `initial_merkle_items_per_subtree`
(default 1,048,576, settings/settings.go:303 at 4edb60a4) when
`blockassembly_useDynamicSubtreeSize` (default false, :313) is off, else the
size `adjustSubtreeSize` last chose, a power of two at the defaults of
settings.go:304-305 (the rounding at :2333,2417,2455, then the clamps)
(SubtreeProcessor.go:2297-2460, called once per block at :5699). Both are
`2 ^ k` here. src/consensus/merkle.cpp:312-319 at 6504a3af has no such setting. -/
def assemblySize (useDynamicSubtreeSize : Bool) (initialLog2 currentLog2 : Nat) : Nat :=
  if useDynamicSubtreeSize then 2 ^ currentLog2 else 2 ^ initialLog2

/-- [D] The reference's root, #63's `computeMerkleRoot`.
[SRC] src/consensus/merkle.cpp:247-282,312-319 at 6504a3af. -/
abbrev refRoot (xs : List Bytes) : Bytes := (computeMerkleRoot xs).root

/-- [D] The premise of the builder: every word the builder pairs is nonzero,
level by level, along the reference's own levels.
[SRC] merkle_tree.go:136-150 (go-subtree v1.5.1); src/consensus/merkle.cpp:210-236
at 6504a3af. -/
def PairedNonzero : List Bytes → Prop
  | a :: b :: rest => (∀ x ∈ a :: b :: rest, x ≠ zeroHash) ∧
      PairedNonzero (merkleLevel (a :: b :: rest)).1
  | _ => True
termination_by xs => xs.length
decreasing_by rw [merkleLevel_length]; simp only [List.length_cons]; omega

/-- [D] No SHA256d output is the zero word: a sufficient condition for
`BodyNonzero`, not the premise of record. In the random-oracle reading it
holds with probability about e^-1 (the outer SHA-256 sees 2^256 words), and it
cannot be decided.
[SRC] merkle_tree.go:138-140 (go-subtree v1.5.1); the reference has no
zero-word premise: its null word is only the empty list's root,
src/consensus/merkle.cpp:254 at 6504a3af. -/
def ZeroFree : Prop := ∀ m : Bytes, sha256d m ≠ zeroHash

/-- [SRC] The premise of the stored roots: every subtree after the leading one,
when nonempty, claims its nodes' root. go-subtree subtree.go:481-483,837-839
(v1.5.1): a stored subtree's `RootHash` is its header's claim;
model/Block.go:2423-2433 binds the claim to the key only;
services/blockvalidation/quick_validate.go:1292-1304 and
model/subtree_meta_reader.go:57-111 bind claim = recomputed = key at 4edb60a4.
src/consensus/merkle.cpp:312-319 at 6504a3af caches no root. -/
def RootsAnchored (claim : List Bytes → Bytes) (rest : List (List Bytes)) : Prop :=
  ∀ s ∈ rest, s ≠ [] → claim s = (storeRoot s).get!

/-- [SRC] The `RootHash` of a subtree built in memory, whose cache is unset:
the recomputation, go-subtree subtree.go:485-497 (v1.5.1); the legacy path
builds its subtrees so (services/legacy/netsync/handle_block.go:446-536 at
4edb60a4). The vectors of `corpus/merkle/subtree-vectors.jsonl` read every
root so. src/consensus/merkle.cpp:247-282 at 6504a3af. -/
def recomputed (s : List Bytes) : Bytes := (storeRoot s).get!

/-- [D] The words of Teranode's top tree, read through the reference: the
leading subtree's root, every later subtree's root, the last one lifted to
height `h`. [SRC] model/Block.go:2744,2867-2876 and subtree_body_shape.go:95 at
4edb60a4; src/consensus/merkle.cpp:247-282 at 6504a3af. -/
def topWords (lead : List Bytes) (h : Nat) (rest : List (List Bytes)) : List Bytes :=
  refRoot lead :: (rest.dropLast.map refRoot ++
    rest.getLast?.toList.map (fun l => liftRoot (h - treeHeight l.length) (refRoot l)))

/-- [D] The premise of record, finite and per body: no word Teranode's builder
pairs in this body is the zero word. `PairedNonzero` of the leading subtree
with the coinbase in place, of each later subtree, and of the top tree's words.
The lift's self-hashes read no sentinel (subtree.go:532-538, v1.5.1), so their
inputs carry no premise. [SRC] merkle_tree.go:138-140 (go-subtree v1.5.1) reads
the zero word as "no node"; neither source checks it (model/Block.go:2709-2879,
model/subtree_body_shape.go at 4edb60a4); src/consensus/merkle.cpp:210-282 at
6504a3af has no sentinel. -/
def BodyNonzero (coinbase : Bytes) : List (List Bytes) → Prop
  | [] => True
  | [lead] => PairedNonzero (replaceRoot coinbase lead)
  | lead :: s :: more => PairedNonzero (replaceRoot coinbase lead) ∧
      (∀ c ∈ s :: more, PairedNonzero c) ∧
      PairedNonzero (topWords (replaceRoot coinbase lead) (treeHeight lead.length) (s :: more))

/-! ## The reference's merkle root, fuel-free -/

/-- [D] The reference's reduction does not depend on surplus fuel.
[SRC] src/consensus/merkle.cpp:247-282 at 6504a3af. -/
theorem merkleReduce_fuel (f g : Nat) (xs : List Bytes) (hf : xs.length ≤ f + 1)
    (hg : xs.length ≤ g + 1) : merkleReduce f xs = merkleReduce g xs := by
  induction f generalizing g xs with
  | zero =>
    match xs, g with
    | [], g => cases g <;> rfl
    | [_], g => cases g <;> rfl
    | _ :: _ :: _, _ => simp at hf
  | succ f ih =>
    match xs, g with
    | [], g => cases g <;> rfl
    | [_], g => cases g <;> rfl
    | _ :: _ :: _, 0 => simp at hg
    | a :: b :: rest, g + 1 =>
      have hl := merkleLevel_length (a :: b :: rest)
      simp only [List.length_cons] at hf hg hl
      simp only [merkleReduce]
      rw [ih g (merkleLevel (a :: b :: rest)).1 (by rw [hl]; omega) (by rw [hl]; omega)]

/-- [D] One level of the reference: for two or more leaves the root and the
flag are those of the next level, the level's own flag OR'd in.
[SRC] src/consensus/merkle.cpp:210-244 at 6504a3af. -/
theorem computeMerkleRoot_step (xs : List Bytes) (h : 2 ≤ xs.length) :
    computeMerkleRoot xs =
      ⟨(computeMerkleRoot (merkleLevel xs).1).root,
        (merkleLevel xs).2 || (computeMerkleRoot (merkleLevel xs).1).mutated⟩ := by
  match xs with
  | a :: b :: rest =>
    have hl := merkleLevel_length (a :: b :: rest)
    simp only [List.length_cons] at hl
    simp only [computeMerkleRoot, List.length_cons, merkleReduce]
    rw [merkleReduce_fuel (rest.length + 1) (merkleLevel (a :: b :: rest)).1.length
      (merkleLevel (a :: b :: rest)).1 (by rw [hl]; omega) (by omega)]

/-- [D] A single leaf is its own root, unmutated.
[SRC] src/consensus/merkle.cpp:249-255 at 6504a3af. -/
theorem computeMerkleRoot_single (a : Bytes) : computeMerkleRoot [a] = ⟨a, false⟩ := rfl

/-- [D] The reference's level on two leaves and a rest.
[SRC] src/consensus/merkle.cpp:210-236 at 6504a3af. -/
theorem merkleLevel_cons₂ (a b : Bytes) (rest : List Bytes) :
    merkleLevel (a :: b :: rest) =
      (sha256d (a ++ b) :: (merkleLevel rest).1, (a == b) || (merkleLevel rest).2) := rfl

/-- [D] A level splits at an even boundary: the pairs never straddle it.
[SRC] src/consensus/merkle.cpp:263-271 at 6504a3af. -/
theorem merkleLevel_append (c ys : List Bytes) (h : c.length % 2 = 0) :
    merkleLevel (c ++ ys) =
      ((merkleLevel c).1 ++ (merkleLevel ys).1, (merkleLevel c).2 || (merkleLevel ys).2) := by
  induction c using merkleLevel.induct with
  | case1 => simp [merkleLevel]
  | case2 a => simp at h
  | case3 a b rest next mutated he ih =>
    simp only [List.length_cons] at h
    have ih' := ih (by omega)
    simp only [List.cons_append, merkleLevel_cons₂, ih', Bool.or_assoc]

/-- [D] A level of a list of even-length chunks then a tail is the chunks'
levels then the tail's.
[SRC] src/consensus/merkle.cpp:263-271 at 6504a3af. -/
theorem merkleLevel_flatten (cs : List (List Bytes)) (l : List Bytes)
    (h : ∀ c ∈ cs, c.length % 2 = 0) :
    merkleLevel (cs.flatten ++ l) =
      ((cs.map (fun c => (merkleLevel c).1)).flatten ++ (merkleLevel l).1,
        cs.any (fun c => (merkleLevel c).2) || (merkleLevel l).2) := by
  induction cs with
  | nil => simp
  | cons c cs ih =>
    have hc := h c (by simp)
    have ih' := ih (fun d hd => h d (by simp [hd]))
    simp only [List.flatten_cons, List.append_assoc, List.map_cons, List.any_cons]
    rw [merkleLevel_append c _ hc, ih', Bool.or_assoc]

/-- [D] The bit length on a power of two minus one.
[SRC] Go `bits.Len` at subtree.go:526 (go-subtree v1.5.1); src/consensus/merkle.cpp:239-244,273-280 at 6504a3af. -/
theorem bitLen_two_pow_sub_one (k : Nat) : bitLen (2 ^ k - 1) = k := by
  induction k with
  | zero => simp [bitLen]
  | succ k ih =>
    rw [bitLen]
    have hp : 0 < 2 ^ k := Nat.two_pow_pos k
    have hd : (2 ^ (k + 1) - 1) / 2 = 2 ^ k - 1 := by rw [Nat.pow_succ]; omega
    split
    · rw [Nat.pow_succ] at *; omega
    · rw [hd, ih]

/-- [D] A power of two's height is its exponent.
[SRC] subtree.go:526,925 (go-subtree v1.5.1); src/consensus/merkle.cpp:239-244,273-280 at 6504a3af. -/
theorem treeHeight_two_pow (k : Nat) : treeHeight (2 ^ k) = k := bitLen_two_pow_sub_one k

/-- [D] Halving (rounded up) a count of two or more lowers its height by one.
[SRC] merkle_tree.go:66 (go-subtree v1.5.1); src/consensus/merkle.cpp:239-244,273-280 at 6504a3af. -/
theorem treeHeight_half (n : Nat) (h : 2 ≤ n) : treeHeight n = treeHeight ((n + 1) / 2) + 1 := by
  unfold treeHeight
  conv => lhs; rw [bitLen]
  split
  · omega
  · congr 2
    omega

/-- [D] The bit length bounds its argument: `x < 2 ^ bitLen x ≤ 2 x` for positive `x`.
[SRC] Go `bits.Len` at subtree.go:526 (go-subtree v1.5.1); src/consensus/merkle.cpp:239-244,273-280 at 6504a3af. -/
theorem bitLen_spec (x : Nat) : x < 2 ^ bitLen x ∧ (x = 0 ∨ 2 ^ bitLen x ≤ 2 * x) := by
  induction x using Nat.strong_induction_on with
  | _ x ih =>
    rw [bitLen]
    split
    · simp_all
    · rename_i hx
      have ⟨h1, h2⟩ := ih (x / 2) (by omega)
      rw [Nat.pow_succ]
      constructor
      · omega
      · right
        rcases h2 with h2 | h2
        · have : x = 1 := by omega
          subst this
          simp [h2, bitLen]
        · omega

/-- [D] A number below `2 ^ k` has at most `k` bits.
[SRC] Go `bits.Len` at subtree.go:526 (go-subtree v1.5.1); src/consensus/merkle.cpp:239-244,273-280 at 6504a3af. -/
theorem bitLen_le (k x : Nat) (h : x < 2 ^ k) : bitLen x ≤ k := by
  induction k generalizing x with
  | zero => have : x = 0 := by simp at h; omega
            subst this; simp [bitLen]
  | succ k ih =>
    rw [bitLen]
    split
    · omega
    · have := ih (x / 2) (by rw [Nat.pow_succ] at h; omega)
      omega

/-! ## The structural theorem: the composed root is the flat root -/

/-- [D] One leaf has height zero.
[SRC] subtree.go:526 (go-subtree v1.5.1); src/consensus/merkle.cpp:249-255 at 6504a3af. -/
theorem treeHeight_one : treeHeight 1 = 0 := by simp [treeHeight, bitLen]

/-- [D] A lifted root by one more level.
[SRC] subtree.go:532-538 (go-subtree v1.5.1); src/consensus/merkle.cpp:215-222,270-271 at 6504a3af. -/
theorem liftRoot_succ (k : Nat) (x : Bytes) : liftRoot (k + 1) x = liftRoot k (selfHash x) :=
  Function.iterate_succ_apply selfHash k x

/-- [D] The flag over chunks distributes.
[SRC] src/consensus/merkle.cpp:210-213 at 6504a3af. -/
theorem any_or {α} (cs : List α) (f g : α → Bool) :
    cs.any (fun c => f c || g c) = (cs.any f || cs.any g) := by
  induction cs with
  | nil => rfl
  | cons c cs ih =>
    simp only [List.any_cons, ih]
    cases f c <;> cases g c <;> simp

/-- [D] `any` respects pointwise equality on the list.
[SRC] src/consensus/merkle.cpp:210-213 at 6504a3af. -/
theorem any_congr' {α} (cs : List α) (f g : α → Bool) (h : ∀ c ∈ cs, f c = g c) :
    cs.any f = cs.any g := by
  induction cs with
  | nil => rfl
  | cons c cs ih =>
    simp only [List.any_cons, h c (by simp), ih (fun d hd => h d (by simp [hd]))]

/-- [D] THE STRUCTURAL THEOREM. Chunks of `2 ^ h` leaves (at least one) then a
last chunk of one to `2 ^ h` leaves: the reference's root over the flat list
equals the reference's root over the chunk roots, the last root lifted by
self-hashing to height `h`; and the flat flag is the OR of every chunk's flag,
the last chunk's flag and the top tree's flag. No premise on the hash.
[SRC] model/Block.go:2793-2879 and subtree_body_shape.go:37-103 at 4edb60a4;
subtree.go:516-541 (go-subtree v1.5.1); src/consensus/merkle.cpp:21-24,210-282,312-319
at 6504a3af. -/
theorem compose_eq_flat (h : Nat) (cs : List (List Bytes)) (l : List Bytes)
    (hc : ∀ c ∈ cs, c.length = 2 ^ h) (hl0 : 0 < l.length) (hl : l.length ≤ 2 ^ h)
    (hne : cs ≠ []) :
    computeMerkleRoot (cs.flatten ++ l) =
      ⟨(computeMerkleRoot (cs.map refRoot ++ [liftRoot (h - treeHeight l.length) (refRoot l)])).root,
        cs.any (fun c => (computeMerkleRoot c).mutated) || (computeMerkleRoot l).mutated ||
          (computeMerkleRoot (cs.map refRoot ++
            [liftRoot (h - treeHeight l.length) (refRoot l)])).mutated⟩ := by
  induction h generalizing cs l with
  | zero =>
    have hl1 : l.length = 1 := by simp at hl; omega
    obtain ⟨y, rfl⟩ : ∃ y, l = [y] := List.length_eq_one_iff.mp hl1
    have hsingle : ∀ c ∈ cs, ∃ x, c = [x] := fun c hcm => List.length_eq_one_iff.mp (by simpa using hc c hcm)
    have hmap : cs.map refRoot = cs.flatten := by
      clear hne hc
      induction cs with
      | nil => rfl
      | cons c cs ih =>
        obtain ⟨x, rfl⟩ := hsingle c (by simp)
        simp only [List.map_cons, List.flatten_cons, ih (fun d hd => hsingle d (by simp [hd]))]
        rfl
    have hany : cs.any (fun c => (computeMerkleRoot c).mutated) = false := by
      rw [List.any_eq_false]
      intro c hcm
      obtain ⟨x, rfl⟩ := hsingle c hcm
      simp [computeMerkleRoot_single]
    have hy : liftRoot (0 - treeHeight [y].length) (refRoot [y]) = y := by rw [Nat.zero_sub]; rfl
    rw [hmap, hany, hy]
    generalize computeMerkleRoot (cs.flatten ++ [y]) = R
    cases R
    rfl
  | succ h ih =>
    have hpos : 0 < 2 ^ h := Nat.two_pow_pos h
    have hev : ∀ c ∈ cs, c.length % 2 = 0 := fun c hcm => by rw [hc c hcm, Nat.pow_succ]; omega
    have hlev := merkleLevel_flatten cs l hev
    obtain ⟨c0, cs0, rfl⟩ : ∃ c0 cs0, cs = c0 :: cs0 := List.exists_cons_of_ne_nil hne
    have hc0 := hc c0 (by simp)
    have hflat : 2 ≤ ((c0 :: cs0).flatten ++ l).length := by
      simp only [List.flatten_cons, List.length_append, hc0, Nat.pow_succ]; omega
    -- the next level is the same shape at height h
    obtain ⟨cs', hcs'⟩ : ∃ cs', cs' = (c0 :: cs0).map (fun c => (merkleLevel c).1) := ⟨_, rfl⟩
    obtain ⟨l', hl'def⟩ : ∃ l', l' = (merkleLevel l).1 := ⟨_, rfl⟩
    rw [← hcs', ← hl'def] at hlev
    have hc' : ∀ c ∈ cs', c.length = 2 ^ h := by
      intro c hcm
      rw [hcs'] at hcm
      obtain ⟨d, hd, rfl⟩ := List.mem_map.mp hcm
      rw [merkleLevel_length, hc d hd, Nat.pow_succ]; omega
    have hl'len : l'.length = (l.length + 1) / 2 := by rw [hl'def]; exact merkleLevel_length l
    have hl0' : 0 < l'.length := by rw [hl'len]; omega
    have hl' : l'.length ≤ 2 ^ h := by rw [hl'len]; rw [Nat.pow_succ] at hl; omega
    have hne' : cs' ≠ [] := by simp [hcs']
    have step := ih cs' l' hc' hl0' hl' hne'
    -- each chunk's root and flag through one level
    have hchunk : ∀ c ∈ c0 :: cs0, computeMerkleRoot c =
        ⟨(computeMerkleRoot (merkleLevel c).1).root,
          (merkleLevel c).2 || (computeMerkleRoot (merkleLevel c).1).mutated⟩ := by
      intro c hcm
      apply computeMerkleRoot_step
      rw [hc c hcm, Nat.pow_succ]; omega
    have hroots : (c0 :: cs0).map refRoot = cs'.map refRoot := by
      rw [hcs', List.map_map]
      refine List.map_inj_left.mpr (fun c hcm => ?_)
      rw [Function.comp_apply, refRoot, refRoot, hchunk c hcm]
    have hflags : (c0 :: cs0).any (fun c => (computeMerkleRoot c).mutated) =
        ((c0 :: cs0).any (fun c => (merkleLevel c).2) ||
          cs'.any (fun c => (computeMerkleRoot c).mutated)) := by
      rw [hcs', List.any_map, ← any_or]
      exact any_congr' _ _ _ (fun c hcm => by rw [Function.comp_apply, hchunk c hcm])
    -- the last chunk: one leaf lifts, two or more step
    have hlast : liftRoot (h + 1 - treeHeight l.length) (refRoot l) =
          liftRoot (h - treeHeight l'.length) (refRoot l') ∧
        (computeMerkleRoot l).mutated = ((merkleLevel l).2 || (computeMerkleRoot l').mutated) := by
      by_cases h1 : l.length = 1
      · obtain ⟨y, rfl⟩ := List.length_eq_one_iff.mp h1
        subst hl'def
        refine ⟨?_, rfl⟩
        rw [show (merkleLevel [y]).1 = [selfHash y] from rfl]
        simp only [List.length_singleton, treeHeight_one, Nat.sub_zero]
        rw [liftRoot_succ]
        rfl
      · have h2 : 2 ≤ l.length := by omega
        have hs := computeMerkleRoot_step l h2
        rw [← hl'def] at hs
        refine ⟨?_, by rw [hs]⟩
        rw [treeHeight_half l.length h2, ← hl'len, refRoot, refRoot, hs, Nat.add_sub_add_right]
    rw [computeMerkleRoot_step _ hflat, hlev]
    dsimp only
    rw [step, hroots, hlast.1, hflags, hlast.2]
    simp only [Bool.or_assoc, Bool.or_comm, Bool.or_left_comm]

/-! ## The builder: zero-sentinel levels equal the reference's levels -/

/-- [D] The zero word pairs to the zero word.
[SRC] merkle_tree.go:139-140 (go-subtree v1.5.1); src/consensus/merkle.cpp:247-255 at 6504a3af. -/
theorem pairLevel_zeros : ∀ m : Nat,
    pairLevel (List.replicate m zeroHash) = List.replicate ((m + 1) / 2) zeroHash
  | 0 => rfl
  | 1 => by simp [pairLevel, calcMerkle]
  | m + 2 => by
    rw [List.replicate_succ, List.replicate_succ, pairLevel, pairLevel_zeros m]
    rw [show (m + 2 + 1) / 2 = (m + 1) / 2 + 1 by omega, List.replicate_succ]
    simp [calcMerkle]

/-- [D] On nonzero words then zero padding, the builder's level is the
reference's level then zero padding.
[SRC] merkle_tree.go:97-161 (go-subtree v1.5.1); src/consensus/merkle.cpp:210-236 at 6504a3af. -/
theorem pairLevel_pad (xs : List Bytes) (m : Nat) (hx : ∀ x ∈ xs, x ≠ zeroHash) :
    ∃ z, pairLevel (xs ++ List.replicate m zeroHash) = (merkleLevel xs).1 ++ List.replicate z zeroHash := by
  induction xs using merkleLevel.induct with
  | case1 => exact ⟨(m + 1) / 2, by simp [merkleLevel, pairLevel_zeros]⟩
  | case2 a =>
    have ha := hx a (by simp)
    cases m with
    | zero => exact ⟨0, by simp [pairLevel, merkleLevel, calcMerkle, ha]⟩
    | succ m =>
      refine ⟨(m + 1) / 2, ?_⟩
      simp only [List.singleton_append, List.replicate_succ, pairLevel, pairLevel_zeros, merkleLevel]
      simp [calcMerkle, ha]
  | case3 a b rest next mutated he ih =>
    have ha := hx a (by simp)
    have hb := hx b (by simp)
    obtain ⟨z, hz⟩ := ih (fun x hm => hx x (by simp [hm]))
    refine ⟨z, ?_⟩
    simp only [List.cons_append, pairLevel, hz, merkleLevel_cons₂, calcMerkle, ha, hb, ite_false]

/-- [D] Exactly `k` builder levels on a list of `2 ^ (k-1) + 1` to `2 ^ k`
nonzero-paired words, padded with zeros, leave the reference's root on top.
[SRC] merkle_tree.go:45-94 (go-subtree v1.5.1); src/consensus/merkle.cpp:247-282 at 6504a3af. -/
theorem iterLevels_pad (k : Nat) : ∀ (xs : List Bytes) (m : Nat), 2 ≤ xs.length →
    xs.length ≤ 2 ^ k → 2 ^ k < 2 * xs.length → PairedNonzero xs →
    (iterLevels k (xs ++ List.replicate m zeroHash)).head? = some (refRoot xs) := by
  induction k with
  | zero => intro xs m h2 hk; simp at hk; omega
  | succ k ih =>
    intro xs m h2 hk hk2 hp
    match xs, h2, hp with
    | a :: b :: rest, _, hp =>
      rw [PairedNonzero] at hp
      obtain ⟨hnz, hnext⟩ := hp
      obtain ⟨z, hz⟩ := pairLevel_pad (a :: b :: rest) m hnz
      have hl := merkleLevel_length (a :: b :: rest)
      have hs := computeMerkleRoot_step (a :: b :: rest) (by simp)
      simp only [iterLevels, hz, refRoot, hs]
      simp only [List.length_cons] at hl hk hk2
      have hpk : 0 < 2 ^ k := Nat.two_pow_pos k
      rw [Nat.pow_succ] at hk hk2
      by_cases hn : (merkleLevel (a :: b :: rest)).1.length = 1
      · obtain ⟨y, hy⟩ := List.length_eq_one_iff.mp hn
        have hk0 : k = 0 := by
          rcases k with _ | k
          · rfl
          · rw [Nat.pow_succ] at hk2; omega
        subst hk0
        simp [hy, iterLevels, computeMerkleRoot_single]
      · exact ih _ z (by omega) (by omega) (by omega) hnext

/-- [D] go-subtree's builder equals the reference's root on every nonempty
list whose paired words are nonzero.
[SRC] merkle_tree.go:45-161 and subtree.go:476-498 (go-subtree v1.5.1);
src/consensus/merkle.cpp:247-282 at 6504a3af. -/
theorem storeRoot_eq_computeMerkleRoot (xs : List Bytes) (hne : xs ≠ [])
    (hp : PairedNonzero xs) : storeRoot xs = some (refRoot xs) := by
  match xs, hne, hp with
  | [a], _, _ => rfl
  | a :: b :: rest, _, hp =>
    have ⟨h1, h2⟩ := bitLen_spec ((a :: b :: rest).length - 1)
    exact iterLevels_pad _ _ _ (by simp) (by unfold treeHeight; omega)
      (by unfold treeHeight; simp only [List.length_cons] at h1 h2 ⊢; omega) hp

/-- [D] Every word of a reference level is a SHA256d output.
[SRC] src/consensus/merkle.cpp:210-236 at 6504a3af. -/
theorem merkleLevel_hashes (xs : List Bytes) : ∀ y ∈ (merkleLevel xs).1, ∃ m, y = sha256d m := by
  induction xs using merkleLevel.induct with
  | case1 => simp [merkleLevel]
  | case2 a => intro y hy; simp [merkleLevel] at hy; exact ⟨_, hy⟩
  | case3 a b rest next mutated he ih =>
    intro y hy
    rw [merkleLevel_cons₂] at hy
    rcases List.mem_cons.mp hy with rfl | hy
    · exact ⟨_, rfl⟩
    · exact ih y hy

/-- [D] Under `ZeroFree`, nonzero leaves make every paired word nonzero.
[SRC] merkle_tree.go:136-150 (go-subtree v1.5.1); src/consensus/merkle.cpp:210-236 at 6504a3af. -/
theorem pairedNonzero_of_zeroFree (zf : ZeroFree) (xs : List Bytes)
    (hx : ∀ x ∈ xs, x ≠ zeroHash) : PairedNonzero xs := by
  match xs with
  | [] => rw [PairedNonzero.eq_def]; trivial
  | [_] => rw [PairedNonzero.eq_def]; trivial
  | a :: b :: rest =>
    rw [PairedNonzero]
    refine ⟨hx, pairedNonzero_of_zeroFree zf _ ?_⟩
    intro y hy
    obtain ⟨m, rfl⟩ := merkleLevel_hashes _ y hy
    exact zf m
termination_by xs.length
decreasing_by rw [merkleLevel_length]; simp only [List.length_cons]; omega

/-- [D] A property of every leaf and of every SHA256d output holds of the
reference's root of a nonempty list.
[SRC] src/consensus/merkle.cpp:210-282 at 6504a3af. -/
theorem refRoot_prop (P : Bytes → Prop) (hh : ∀ m, P (sha256d m)) (xs : List Bytes)
    (hne : xs ≠ []) (hx : ∀ x ∈ xs, P x) : P (refRoot xs) := by
  match xs with
  | [a] => exact hx a (by simp)
  | a :: b :: rest =>
    have hs := computeMerkleRoot_step (a :: b :: rest) (by simp)
    have hl := merkleLevel_length (a :: b :: rest)
    simp only [refRoot, hs]
    exact refRoot_prop P hh _ (List.ne_nil_of_length_pos (by rw [hl]; simp))
      (fun y hy => by obtain ⟨m, rfl⟩ := merkleLevel_hashes _ y hy; exact hh m)
termination_by xs.length
decreasing_by rw [merkleLevel_length]; simp only [List.length_cons]; omega

/-- [D] A lift keeps a property every SHA256d output has.
[SRC] subtree.go:532-538 (go-subtree v1.5.1); src/consensus/merkle.cpp:215-222,270-271 at 6504a3af. -/
theorem liftRoot_prop (P : Bytes → Prop) (hh : ∀ m, P (sha256d m)) (k : Nat) (x : Bytes)
    (hx : P x) : P (liftRoot k x) := by
  induction k generalizing x with
  | zero => exact hx
  | succ k ih => rw [liftRoot_succ]; exact ih _ (hh _)

/-! ## Teranode's check against the flat root -/

/-- [D] The shape rule splits the subtrees after the leading one into full ones and
a last one no longer.
[SRC] model/subtree_body_shape.go:45-57 at 4edb60a4; src/consensus/merkle.cpp:312-319 at 6504a3af. -/
theorem shapeOk_split (target : Nat) (rest : List (List Bytes)) (hne : rest ≠ [])
    (h : shapeOk target (rest.map List.length) = true) :
    ∃ middle last, rest = middle ++ [last] ∧ (∀ c ∈ middle, c.length = target) ∧
      last.length ≤ target := by
  induction rest with
  | nil => exact absurd rfl hne
  | cons s more ih =>
    match more, ih, h with
    | [], _, h => exact ⟨[], s, rfl, by simp, by simpa [shapeOk] using h⟩
    | m :: more', ih, h =>
      simp only [List.map_cons, shapeOk, Bool.and_eq_true, beq_iff_eq] at h
      obtain ⟨middle, last, he, hm, hl⟩ := ih (by simp) (by simpa using h.2)
      refine ⟨s :: middle, last, by simp [he], ?_, hl⟩
      intro c hc
      rcases List.mem_cons.mp hc with rfl | hc
      · exact h.1
      · exact hm c hc

/-- [D] A nonempty subtree's padded root is the lift of the root it is given.
[SRC] subtree.go:516-541 (go-subtree v1.5.1); src/consensus/merkle.cpp:215-222,239-244 at 6504a3af. -/
theorem rootHashPadded_of_ne (target : Nat) (root : Bytes) (nodes : List Bytes) (hne : nodes ≠ []) :
    rootHashPadded target root nodes = if target < treeHeight nodes.length then none
      else some (liftRoot (target - treeHeight nodes.length) root) := by
  cases nodes with
  | nil => exact absurd rfl hne
  | cons _ _ => rfl

/-- [D] An anchored claim of a nonempty subtree with nonzero paired words is the
reference's root of its nodes.
[SRC] subtree.go:481-498 (go-subtree v1.5.1); model/subtree_meta_reader.go:57-111 at
4edb60a4; src/consensus/merkle.cpp:247-282 at 6504a3af. -/
theorem claim_eq_refRoot (claim : List Bytes → Bytes) (s : List Bytes) (hne : s ≠ [])
    (hp : PairedNonzero s) (ha : claim s = (storeRoot s).get!) : claim s = refRoot s := by
  rw [ha, storeRoot_eq_computeMerkleRoot s hne hp]
  rfl

/-- [D] The in-memory reading is anchored: `recomputed` is the recomputation.
[SRC] subtree.go:485-497 (go-subtree v1.5.1); src/consensus/merkle.cpp:247-282 at 6504a3af. -/
theorem recomputed_anchored (rest : List (List Bytes)) : RootsAnchored recomputed rest :=
  fun _ _ _ => rfl

/-- [D] The roots after the leading one: each full subtree's reference root, the last
one's lifted to height `k`, when the claims are anchored and the paired words nonzero.
[SRC] model/Block.go:2744,2867-2876 at 4edb60a4; subtree.go:476-541 (go-subtree v1.5.1);
src/consensus/merkle.cpp:247-282 at 6504a3af. -/
theorem restRoots_eq (claim : List Bytes → Bytes) (k : Nat) (middle : List (List Bytes))
    (last : List Bytes) (rs : List Bytes) (hm : ∀ c ∈ middle, c.length = 2 ^ k)
    (hl : last.length ≤ 2 ^ k) (hp : ∀ c ∈ middle ++ [last], PairedNonzero c)
    (ha : RootsAnchored claim (middle ++ [last]))
    (h : restRoots claim (2 ^ k) (middle ++ [last]) = some rs) :
    last ≠ [] ∧ rs = middle.map refRoot ++ [liftRoot (k - treeHeight last.length) (refRoot last)] := by
  induction middle generalizing rs with
  | nil =>
    have hpos : 0 < 2 ^ k := Nat.two_pow_pos k
    have hne : last ≠ [] := by
      rintro rfl
      simp [restRoots, rootHashPadded, hpos] at h
    have hc : claim last = refRoot last :=
      claim_eq_refRoot claim last hne (hp last (by simp)) (ha last (by simp) hne)
    refine ⟨hne, ?_⟩
    simp only [List.nil_append, restRoots] at h
    split at h
    · rw [rootHashPadded_of_ne _ _ _ hne, treeHeight_two_pow] at h
      have hle : ¬ k < treeHeight last.length := by
        unfold treeHeight
        have := bitLen_le k (last.length - 1) (by have := List.length_pos_iff.mpr hne; omega)
        omega
      simp only [hle, ↓reduceIte, Option.map_some, Option.some.injEq] at h
      simp [← h, hc]
    · rename_i hlt
      have heq : last.length = 2 ^ k := by omega
      simp only [Option.some.injEq] at h
      simp [← h, hc, heq, treeHeight_two_pow, liftRoot]
  | cons s middle ih =>
    have hs0 : s.length = 2 ^ k := hm s (by simp)
    have hsne : s ≠ [] := by
      intro he
      rw [he, List.length_nil] at hs0
      exact (Nat.two_pow_pos k).ne' hs0.symm
    have hcs : claim s = refRoot s :=
      claim_eq_refRoot claim s hsne (hp s (by simp)) (ha s (by simp) hsne)
    obtain ⟨m, more, hmm⟩ : ∃ m more, middle ++ [last] = m :: more := by
      cases middle with
      | nil => exact ⟨last, [], rfl⟩
      | cons m middle => exact ⟨m, middle ++ [last], rfl⟩
    have h' := h
    rw [List.cons_append, hmm] at h'
    simp only [restRoots] at h'
    rw [← hmm] at h'
    cases hrs : restRoots claim (2 ^ k) (middle ++ [last]) with
    | none => rw [hrs] at h'; simp at h'
    | some rs' =>
      rw [hrs, Option.map_some, Option.some.injEq] at h'
      have hsub : ∀ c ∈ middle ++ [last], c ∈ s :: middle ++ [last] := fun c hc => by
        rw [List.cons_append]; exact List.mem_cons_of_mem _ hc
      obtain ⟨hne, hrs'⟩ := ih rs' (fun c hc => hm c (List.mem_cons_of_mem _ hc))
        (fun c hc => hp c (hsub c hc)) (fun c hc => ha c (hsub c hc)) hrs
      exact ⟨hne, by rw [← h', hcs, hrs']; simp⟩

/-- [D] `ZeroFree` is a sufficient condition for `BodyNonzero`: with no SHA256d
output the zero word, nonzero leaves in nonempty subtrees make every paired word
of the body nonzero.
[SRC] merkle_tree.go:138-140 (go-subtree v1.5.1); src/consensus/merkle.cpp:210-282 at 6504a3af. -/
theorem bodyNonzero_of_zeroFree (zf : ZeroFree) (coinbase : Bytes) (subtrees : List (List Bytes))
    (hne : ∀ c ∈ subtrees, c ≠ []) (hx : ∀ x ∈ flatLeaves coinbase subtrees, x ≠ zeroHash) :
    BodyNonzero coinbase subtrees := by
  match subtrees with
  | [] => simp [BodyNonzero]
  | [lead] =>
    have hxf : ∀ x ∈ replaceRoot coinbase lead, x ≠ zeroHash := by simpa [flatLeaves] using hx
    simp only [BodyNonzero]
    exact pairedNonzero_of_zeroFree zf _ hxf
  | lead :: s :: more =>
    have hxf : ∀ x ∈ replaceRoot coinbase lead, x ≠ zeroHash := fun x hxm =>
      hx x (by simp only [flatLeaves, List.mem_append]; exact Or.inl hxm)
    have hxc : ∀ c ∈ s :: more, ∀ x ∈ c, x ≠ zeroHash := fun c hc x hxm =>
      hx x (by rw [flatLeaves, List.mem_append]; exact Or.inr (List.mem_flatten.mpr ⟨c, hc, hxm⟩))
    have hrne : replaceRoot coinbase lead ≠ [] := by cases lead <;> simp [replaceRoot]
    simp only [BodyNonzero]
    refine ⟨pairedNonzero_of_zeroFree zf _ hxf,
      fun c hc => pairedNonzero_of_zeroFree zf c (hxc c hc), ?_⟩
    apply pairedNonzero_of_zeroFree zf
    obtain ⟨middle, last, he⟩ : ∃ middle last, s :: more = middle ++ [last] :=
      ⟨(s :: more).dropLast, (s :: more).getLast (by simp),
        (List.dropLast_append_getLast (by simp)).symm⟩
    have hmem : ∀ c, c ∈ middle ∨ c = last → c ∈ s :: more := fun c hc => by
      rw [he]; rcases hc with hc | rfl
      · exact List.mem_append_left _ hc
      · exact List.mem_append_right _ (by simp)
    rw [he]
    intro y hy
    simp only [topWords, List.dropLast_concat, List.getLast?_concat, Option.toList_some,
      List.map_cons, List.map_nil, List.mem_cons, List.mem_append, List.mem_map,
      List.not_mem_nil, or_false] at hy
    rcases hy with rfl | ⟨c, hc, rfl⟩ | rfl
    · exact refRoot_prop (· ≠ zeroHash) zf _ hrne hxf
    · exact refRoot_prop (· ≠ zeroHash) zf _ (hne c (by simp [hmem c (Or.inl hc)]))
        (hxc c (hmem c (Or.inl hc)))
    · exact liftRoot_prop (· ≠ zeroHash) zf _ _ (refRoot_prop (· ≠ zeroHash) zf _
        (hne _ (by simp [hmem _ (Or.inr rfl)])) (hxc _ (hmem _ (Or.inr rfl))))

/-- [D] THE THEOREM OF #89. Every root Teranode's check accepts for a body
(no subtree, one subtree of any length, or subtrees of a power-of-two size with
the last one partial, the size chosen by the dynamic-size flag or not) is the
reference's `BlockMerkleRoot` root of the same transaction ids in order, the
coinbase txid at index 0. Premises: `BodyNonzero` (no word the builder pairs in
this body is the zero word; `zero_leaf_counterexample` shows the model needs
it) and `RootsAnchored` (every stored subtree's header root is its nodes' root,
Teranode's own premise of the composition, quick_validate.go:1292-1299).
[SRC] model/Block.go:2709-2771,2793-2879 and model/subtree_body_shape.go:37-103 at
4edb60a4; merkle_tree.go:45-161 and subtree.go:290-306,476-562 (go-subtree v1.5.1);
src/consensus/merkle.cpp:21-24,247-282,312-319 at 6504a3af. -/
theorem subtreeRoot_eq_blockMerkleRoot (claim : List Bytes → Bytes) (coinbase : Bytes)
    (subtrees : List (List Bytes)) (r : Bytes)
    (hbn : BodyNonzero coinbase subtrees) (ha : RootsAnchored claim subtrees.tail)
    (h : checkMerkleRoot claim coinbase subtrees = some r) :
    r = (computeMerkleRoot (flatLeaves coinbase subtrees)).root := by
  match subtrees with
  | [] =>
    simp only [checkMerkleRoot, Option.some.injEq] at h
    simp [← h, flatLeaves, computeMerkleRoot_single]
  | [lead] =>
    simp only [BodyNonzero] at hbn
    have hne : replaceRoot coinbase lead ≠ [] := by cases lead <;> simp [replaceRoot]
    simp only [checkMerkleRoot, storeRoot_eq_computeMerkleRoot _ hne hbn,
      Option.some.injEq] at h
    simp [← h, flatLeaves, refRoot]
  | lead :: s :: more =>
    simp only [BodyNonzero] at hbn
    obtain ⟨hzl, hzs, hzt⟩ := hbn
    simp only [checkMerkleRoot] at h
    split at h
    · rename_i hshape
      simp only [Bool.and_eq_true, goIsPowerOfTwo, bne_iff_ne, ne_eq, beq_iff_eq] at hshape
      obtain ⟨⟨hz, hand⟩, hsh⟩ := hshape
      obtain ⟨k, hk⟩ := Nat.ne_zero_and_sub_one_eq_zero_iff_isPowerOfTwo.mp ⟨hz, hand⟩
      obtain ⟨middle, last, hrest, hm, hl⟩ := shapeOk_split lead.length (s :: more) (by simp) hsh
      rw [hk] at hm hl
      have ha' : RootsAnchored claim (middle ++ [last]) := by rw [← hrest]; exact ha
      have hzs' : ∀ c ∈ middle ++ [last], PairedNonzero c := by rw [← hrest]; exact hzs
      rw [hrest, hk, treeHeight_two_pow] at hzt
      have hfne : lead ≠ [] := by rintro rfl; simp at hz
      have hrne : replaceRoot coinbase lead ≠ [] := by cases lead <;> simp [replaceRoot]
      have hrlen : (replaceRoot coinbase lead).length = 2 ^ k := by
        cases lead with
        | nil => exact absurd rfl hfne
        | cons _ t => simpa [replaceRoot] using hk
      rw [storeRoot_eq_computeMerkleRoot _ hrne hzl, hrest, hk] at h
      split at h
      · rename_i r0 rs hr0 hrs
        simp only [Option.some.injEq] at hr0
        subst hr0
        obtain ⟨hlne, hrs'⟩ := restRoots_eq claim k middle last rs hm hl hzs' ha' hrs
        subst hrs'
        simp only [composeTop] at h
        split at h
        · have htop : topWords (replaceRoot coinbase lead) k (middle ++ [last]) =
              refRoot (replaceRoot coinbase lead) :: (middle.map refRoot ++
                [liftRoot (k - treeHeight last.length) (refRoot last)]) := by
            simp [topWords]
          rw [htop] at hzt
          rw [storeRoot_eq_computeMerkleRoot _ (by simp) hzt, Option.some.injEq] at h
          have hc : ∀ c ∈ replaceRoot coinbase lead :: middle, c.length = 2 ^ k := by
            intro c hc
            rcases List.mem_cons.mp hc with rfl | hc
            · exact hrlen
            · exact hm c hc
          have hcomp := compose_eq_flat k (replaceRoot coinbase lead :: middle) last hc
            (List.length_pos_iff.mpr hlne) hl (by simp)
          have hflat : flatLeaves coinbase (lead :: (middle ++ [last])) =
              (replaceRoot coinbase lead :: middle).flatten ++ last := by
            simp [flatLeaves]
          rw [← hrest] at hflat
          rw [hflat, hcomp, ← h]
          simp [refRoot]
        · simp at h
      · simp at h
    · simp at h

/-- [D] Every count and every power-of-two size: the root block assembly's
partition produces, whenever Teranode's check accepts it, is the flat root;
the dynamic-size flag only picks the size. The premises are the body's, as in
`subtreeRoot_eq_blockMerkleRoot`.
[SRC] services/blockassembly/subtreeprocessor/SubtreeProcessor.go:601-611,2297-2460
and settings/settings.go:303,313 at 4edb60a4; src/consensus/merkle.cpp:312-319 at 6504a3af. -/
theorem assembly_root_eq_blockMerkleRoot (claim : List Bytes → Bytes) (dynamic : Bool) (i c : Nat)
    (coinbase : Bytes) (txids : List Bytes) (r : Bytes)
    (hbn : BodyNonzero coinbase
      (partition (assemblySize dynamic i c) (coinbasePlaceholder :: txids)))
    (ha : RootsAnchored claim
      (partition (assemblySize dynamic i c) (coinbasePlaceholder :: txids)).tail)
    (h : checkMerkleRoot claim coinbase
      (partition (assemblySize dynamic i c) (coinbasePlaceholder :: txids)) = some r) :
    r = (computeMerkleRoot (coinbase :: txids)).root := by
  have hflat : ∀ (size : Nat) (xs : List Bytes), (partition size xs).flatten = xs := by
    intro size xs
    induction xs using (measure List.length).wf.induction with
    | _ xs ih =>
      rw [partition]
      split
      · simp
      · rename_i hs
        simp only [List.flatten_cons]
        rw [ih (xs.drop size) (by show (xs.drop size).length < xs.length; simp only [List.length_drop]; omega), List.take_append_drop]
  have hfl : flatLeaves coinbase (partition (assemblySize dynamic i c)
      (coinbasePlaceholder :: txids)) = coinbase :: txids := by
    rw [partition]
    split
    · simp [flatLeaves, replaceRoot]
    · rename_i hs
      have hsz : 0 < assemblySize dynamic i c := by omega
      obtain ⟨t, ht⟩ : ∃ t, (coinbasePlaceholder :: txids).take (assemblySize dynamic i c) =
          coinbasePlaceholder :: t ∧ t ++ ((coinbasePlaceholder :: txids).drop
            (assemblySize dynamic i c)) = txids := by
        obtain ⟨n, hn⟩ : ∃ n, assemblySize dynamic i c = n + 1 := ⟨_, (Nat.succ_pred_eq_of_pos hsz).symm⟩
        rw [hn]
        exact ⟨txids.take n, rfl, by simp [List.take_append_drop]⟩
      simp only [flatLeaves, ht.1, replaceRoot, hflat, List.cons_append, ht.2]
  have := subtreeRoot_eq_blockMerkleRoot claim coinbase _ r hbn ha h
  rwa [hfl] at this

/-! ## The premise is needed: a zero transaction id -/

/-- [D] At two zero words the builder returns the zero word (a zero left child
makes a zero parent) and the reference hashes them.
[SRC] merkle_tree.go:139-140 (go-subtree v1.5.1); src/consensus/merkle.cpp:227-237 at 6504a3af. -/
theorem zero_leaf_roots :
    storeRoot [zeroHash, zeroHash] = some zeroHash ∧
      refRoot [zeroHash, zeroHash] = sha256d (zeroHash ++ zeroHash) := by
  constructor
  · simp [storeRoot, treeHeight, bitLen, iterLevels, pairLevel, calcMerkle]
  · simp [refRoot, computeMerkleRoot_step, merkleLevel, computeMerkleRoot_single]

/-- [D] The kernel's evaluation of one double SHA-256: the hash of sixty-four
zero bytes is not the zero word (`decide +kernel`, no native code).
[SRC] src/consensus/merkle.cpp:43-50 at 6504a3af; merkle_tree.go:136-161 (go-subtree v1.5.1). -/
theorem sha256d_zero64_ne_zero : sha256d (zeroHash ++ zeroHash) ≠ zeroHash := by decide +kernel

/-- [D] THE COUNTEREXAMPLE OF THE MODEL WITHOUT ITS PREMISE, at the smallest
count (two; one leaf is its own root on both sides): two zero transaction ids.
The builder reads a zero left child as "no node" and returns the zero word;
the reference hashes the pair. Infeasible: a zero txid needs a SHA256d
preimage of the zero word. `subtreeRoot_eq_blockMerkleRoot` assumes it away
through `BodyNonzero`.
[SRC] merkle_tree.go:136-161 (go-subtree v1.5.1); src/consensus/merkle.cpp:227-237 at 6504a3af. -/
theorem zero_leaf_counterexample :
    storeRoot [zeroHash, zeroHash] ≠ some (refRoot [zeroHash, zeroHash]) := by
  rw [zero_leaf_roots.1, zero_leaf_roots.2]
  intro h
  exact sha256d_zero64_ne_zero (Option.some.inj h).symm

/-- [D] Four one-leaf subtree words for the duplicate-root example: a
coinbase txid and three transaction ids, synthetic.
[SRC] model/subtree_body_shape.go:81-88 at 4edb60a4; src/consensus/merkle.cpp:210-213 at 6504a3af. -/
def dupWord (b : Nat) : Bytes := List.replicate 32 b

/-- [D] THE MUTATION FLAG ACROSS THE TWO CONSTRUCTIONS, a decided witness:
subtrees of one leaf each, `[coinbase] [B] [C] [B]`. Teranode's composition
refuses the repeated root `B` (a corrupt body); the reference's flat flag is
false, because `B` and `B` are not siblings at any level, and its root exists.
Both refusals are on the same body only when the repeat is between siblings.
Whether the reference accepts the block is decided by rules outside the merkle
root (the repeated transaction), not read here.
[SRC] model/subtree_body_shape.go:75-103 at 4edb60a4; src/consensus/merkle.cpp:210-213,247-282 at 6504a3af. -/
theorem duplicate_root_divergence :
    checkMerkleRoot recomputed (dupWord 1) [[coinbasePlaceholder], [dupWord 2], [dupWord 3], [dupWord 2]] = none ∧
      (computeMerkleRoot [dupWord 1, dupWord 2, dupWord 3, dupWord 2]).mutated = false := by
  decide +kernel

/-- [D] THE CONVERSE, a decided witness: one subtree `[placeholder, A, B, B]`.
Teranode's root check accepts it with the flat root, while the reference's flat
flag is true (the last pair repeats). Teranode's refusal of that body is left to
its repeated-transaction check, model/Block.go:912-940 at 4edb60a4, outside this
model. [SRC] model/Block.go:2794-2796 at 4edb60a4; src/consensus/merkle.cpp:210-213,247-282
at 6504a3af. -/
theorem mutated_flag_without_refusal :
    checkMerkleRoot recomputed (dupWord 1)
        [[coinbasePlaceholder, dupWord 2, dupWord 3, dupWord 3]] =
      some (computeMerkleRoot [dupWord 1, dupWord 2, dupWord 3, dupWord 3]).root ∧
      (computeMerkleRoot [dupWord 1, dupWord 2, dupWord 3, dupWord 3]).mutated = true := by
  decide +kernel
