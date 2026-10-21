import BsvChain.Views.MerkleProof
import BsvChain.Properties.TxCodec

/-!
# The TSC proof codec and its projection to the merkle path (#75)

[M] 2026-10-13 (#75). The binary TSC codec of `BsvChain.Views.MerkleProof`
round-trips every well-formed proof (the shape of #68's `decodeTxPrefix_serTx`);
the duplicate marker read as the null word (the node's `verifymerkleproof`) and
the marker resolved by recomputation (`tscPath`) compute the same root; proof
verification is `verifyPath` of #65 over the resolved path whenever the target
supplies a root, and is false for a bare block-hash target with no header; the
model of the node's own branch generator verifies against the body root for
every in-range position whose generated hash nodes are non-null, and yields
the empty vector for a one-transaction body, the vector the RPC refuses with `-5`. Views, never rules: every theorem
is about an encoding of `(leaf, path, index, root)`; inclusion keeps #65's
premises (`active_path_inclusion`, `reachable_path_inclusion`).
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/rpc/rawtransaction.cpp:2242-2339,2342-2525,2527-2612, src/merkletree.cpp:275-346,
src/consensus/merkle.cpp:291-310. [LIT] the TSC merkle proof standard, cited in the view module.
-/

namespace BsvChain.Properties
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash BsvScript.Sighash BsvChain.Views

/-- [D] 2026-10-13: flag bit 0 is a bit. -/
theorem txBit_lt (t : TscTxOrId) : txBit t < 2 := by cases t <;> simp [txBit]

/-- [D] 2026-10-13: the target kind is one of the three the standard assigns. -/
theorem targetKind_lt (t : TscTarget) : targetKind t < 3 := by cases t <;> simp [targetKind]

/-- [D] 2026-10-13: the flags byte of the simple standard is below 8: bits 3 and
4 (the extensions) are clear. [LIT] the TSC flags table. -/
theorem tsc_flags_lt (p : TscProof) : p.flags < 8 := by
  have := txBit_lt p.txOrId
  have := targetKind_lt p.target
  unfold TscProof.flags
  omega

/-- [D] 2026-10-13: a node reads back from its binary form: a 32-byte hash after
the type byte 0, or the type byte 1 alone. [LIT] the TSC node layout. -/
theorem readNode_encodeNode (n : TscNode) (rest : Bytes) (wf : NodeWellFormed n) :
    readNode (encodeNode n ++ rest) = some (n, rest) := by
  cases n with
  | hash w =>
    have h := readBytes_append w rest
    rw [show w.length = 32 from wf] at h
    simp [encodeNode, readNode, h]
  | duplicate => rfl

/-- [D] 2026-10-13: the `txOrId` field reads back under its own flag bit.
[LIT] the TSC `txLength` and `txOrId` fields. -/
theorem decodeTxOrId_encodeTxOrId (t : TscTxOrId) (rest : Bytes) (wf : TxOrIdWellFormed t) :
    decodeTxOrId (txBit t) (encodeTxOrId t ++ rest) = some (t, rest) := by
  cases t with
  | txid w =>
    have h := readBytes_append w rest
    rw [show w.length = 32 from wf] at h
    simp [txBit, encodeTxOrId, decodeTxOrId, h]
  | tx raw =>
    simp [txBit, encodeTxOrId, decodeTxOrId, List.append_assoc,
      readVarInt_compactSize _ _ (wf : raw.length < 2 ^ 64), readBytes_append]

/-- [D] 2026-10-13: the `target` field reads back under its own kind: a 32-byte
word, or the header frame by #63's `header_decodePrefix_encode`. -/
theorem decodeTarget_encodeTarget (t : TscTarget) (rest : Bytes) (wf : TargetWellFormed t) :
    decodeTarget (targetKind t) (encodeTarget t ++ rest) = some (t, rest) := by
  cases t with
  | hash w =>
    have h := readBytes_append w rest
    rw [show w.length = 32 from wf] at h
    simp [targetKind, encodeTarget, decodeTarget, h]
  | header h => simp [targetKind, encodeTarget, decodeTarget, header_decodePrefix_encode]
  | merkleRoot w =>
    have h := readBytes_append w rest
    rw [show w.length = 32 from wf] at h
    simp [targetKind, encodeTarget, decodeTarget, h]

/-- [M] 2026-10-13, #75 (the TSC round trip). For every well-formed proof, the
binary decoder reads the encoder's bytes back exactly and leaves any following
stream untouched. Premise in plain words: the proof is well formed (`wf`): a
CompactSize index and node count, a 32-byte id or a transaction of CompactSize
length, a 32-byte hash or root target (the header target is typed), 32-byte hash
nodes. The byte values of the words are the caller's domain, as in #68's G4.
[LIT] the TSC binary layout; [SRC] src/serialize.h:296-340 at 6504a3af for CompactSize. -/
theorem tsc_decodePrefix_encode (p : TscProof) (rest : Bytes) (wf : TscWellFormed p) :
    decodePrefix (p.encode ++ rest) = some (p, rest) := by
  obtain ⟨hi, ht, hg, hc, hn⟩ := wf
  have hb := txBit_lt p.txOrId
  have hk := targetKind_lt p.target
  have h8 : ¬ (txBit p.txOrId + 2 * targetKind p.target ≥ 8) := by omega
  have hm : (txBit p.txOrId + 2 * targetKind p.target) % 2 = txBit p.txOrId := by omega
  have hd : (txBit p.txOrId + 2 * targetKind p.target) / 2 % 4 = targetKind p.target := by omega
  have hnodes := readMany_ser readNode encodeNode NodeWellFormed
    (fun x r h => readNode_encodeNode x r h) p.nodes hn rest
  simp only [TscProof.encode, TscProof.flags, List.cons_append, List.append_assoc, decodePrefix,
    h8, if_false, hm, hd, readVarInt_compactSize _ _ hi, Option.bind, Option.map,
    decodeTxOrId_encodeTxOrId _ _ ht, decodeTarget_encodeTarget _ _ hg,
    readVarInt_compactSize _ _ hc, hnodes] <;> rfl

/-- [M] 2026-10-13, #75: `decode (encode p) = some p` for well-formed proofs.
Premise: `wf` as in `tsc_decodePrefix_encode`. -/
theorem tsc_decode_encode (p : TscProof) (wf : TscWellFormed p) : Views.decode p.encode = some p := by
  have h := tsc_decodePrefix_encode p [] wf
  rw [List.append_nil] at h
  unfold Views.decode
  simp [h]

/-- [D] 2026-10-13: the encoder is injective on well-formed proofs, so equal
bytes are equal proofs. -/
theorem tsc_encode_injective (a b : TscProof) (wa : TscWellFormed a) (wb : TscWellFormed b)
    (h : a.encode = b.encode) : a = b := by
  have ha := tsc_decode_encode a wa
  rw [h, tsc_decode_encode b wb] at ha
  exact (Option.some.inj ha).symm

/-- [D] 2026-10-13: a null sibling and the running hash itself make the same
pair: the marker and the duplicated node hash alike. [SRC] src/consensus/merkle.cpp:297-301
at 6504a3af. -/
theorem branchPair_zero (leaf : Bytes) (index : Nat) : branchPair leaf zero32 index = (leaf, leaf) := by
  simp [branchPair]

/-- [D] 2026-10-14: pairing the running word with itself gives (leaf, leaf) for
every index, including the null-word case. No premise. -/
theorem branchPair_self (leaf : Bytes) (index : Nat) : branchPair leaf leaf index = (leaf, leaf) := by
  unfold branchPair
  split_ifs <;> rfl

/-- [M] 2026-10-13, #75: the marker reading and the recomputed reading agree.
Resolving every `*` to the running hash of its level (`tscPath`) and reading
`*` as the null word the reference duplicates (`markerPath`) compute the same
root from the same leaf and index, for every node list. No premise.
[SRC] src/consensus/merkle.cpp:291-310, src/rpc/rawtransaction.cpp:2601-2607 at 6504a3af. -/
theorem computeRootFromBranch_tscPath (leaf : Bytes) (nodes : List TscNode) (index : Nat) :
    computeRootFromBranch leaf (tscPath leaf nodes index) index =
      computeRootFromBranch leaf (markerPath nodes) index := by
  induction nodes generalizing leaf index with
  | nil => rfl
  | cons n rest ih =>
    cases n with
    | hash w =>
      simp only [tscPath, markerPath, computeRootFromBranch]
      exact ih _ _
    | duplicate =>
      simp only [tscPath, markerPath, computeRootFromBranch, branchPair_zero, branchPair_self]
      exact ih _ _

/-- [M] 2026-10-13, #75: proof verification is #65's `verifyPath` over the
resolved path. Whenever the target supplies a root (`h`: a merkle root, a
header, or a block hash bound to a supplied header), `verifyTsc` equals
`verifyPath leaf (tscPath leaf nodes index) index root`, the leaf being the id
or the carried transaction's id. Premise: `h` only. Root equality, not
inclusion: #65's commitment and shape premises stay where they are.
[SRC] src/consensus/merkle.cpp:291-310, src/rpc/rawtransaction.cpp:2503-2518,2610-2611 at 6504a3af. -/
theorem verifyTsc_eq_verifyPath (p : TscProof) (supplied : Option BlockHeader) (root : Bytes)
    (h : resolveTarget p.target supplied = some root) :
    verifyTsc p supplied =
      verifyPath (tscLeaf p.txOrId) (tscPath (tscLeaf p.txOrId) p.nodes p.index) p.index root := by
  simp only [verifyTsc, h, verifyPath, computeRootFromBranch_tscPath]

/-- [D] 2026-10-13: the strongest relation for a bare block-hash target: with no
header supplied there is no root, so verification is false; the hash target is
the standard's envelope case and needs the header resolved by the hash.
[LIT] the TSC target type 0; [SRC] src/rpc/rawtransaction.cpp:2512-2514 at 6504a3af. -/
theorem verifyTsc_hash_needs_header (p : TscProof) (w : Bytes) (ht : p.target = .hash w) :
    verifyTsc p none = false := by
  simp [verifyTsc, ht, resolveTarget]

/-- [D] 2026-10-13: a block-hash target resolves only through a header whose hash
is the target word, and then to that header's root. -/
theorem resolveTarget_hash (w root : Bytes) (h : BlockHeader)
    (hr : resolveTarget (.hash w) (some h) = some root) :
    headerWordBytes 32 h.hash.toNat = w ∧ root = headerWordBytes 32 h.merkleRoot.toNat := by
  simp only [resolveTarget] at hr
  split at hr
  · rename_i hc
    exact ⟨beq_iff_eq.mp hc, (Option.some.inj hr).symm⟩
  · exact absurd hr (by simp)

/-- [D] 2026-10-13: the sibling of the last position of a level with an odd count
is the position's own word: the reference duplicates the last node.
[SRC] src/consensus/merkle.cpp:57-178; src/merkletree.cpp:322-334 at 6504a3af. -/
theorem siblingAt_last : ∀ (xs : List Bytes) (index : Nat), index % 2 = 0 →
    index + 1 = xs.length → siblingAt xs index = (xs[index]?).getD zero32
  | [], _, _, hl => by simp at hl
  | [_], index, _, hl => by
    have : index = 0 := by simp at hl; omega
    subst this; rfl
  | _ :: _ :: _, 0, _, hl => by simp only [List.length_cons] at hl; omega
  | _ :: _ :: _, 1, he, _ => absurd he (by decide)
  | _ :: _ :: rest, i + 2, he, hl => by
    have he' : i % 2 = 0 := by omega
    have hl' : i + 1 = rest.length := by simp only [List.length_cons] at hl; omega
    simpa only [siblingAt, List.getElem?_cons_succ] using siblingAt_last rest i he' hl'

/-- [M] 2026-10-13, #75 (completeness of the node's own branch). For an in-range
position of a leaf list, enough fuel (the leaf count at most fuel plus one, as
`computeMerkleRoot` supplies) and non-null hash nodes, the marker branch the
node serves (`tscBranchReduce`, the model of `GetMerkleProof` with
`skipDuplicates`) recomputes the body root from the leaf at that position,
read as the node's `verifymerkleproof` reads it. Premises in plain words: the
position is in range, the fuel suffices, and no hash node is the null word
(a null literal would be read as a marker, #65's restriction).
[SRC] src/merkletree.cpp:294-346, src/consensus/merkle.cpp:291-310 at 6504a3af. -/
theorem tscBranchReduce_complete (fuel : Nat) (xs : List Bytes) (index : Nat)
    (hi : index < xs.length) (hf : xs.length ≤ fuel + 1)
    (hn : ∀ w, TscNode.hash w ∈ tscBranchReduce fuel xs index → w ≠ zero32) :
    computeRootFromBranch ((xs[index]?).getD zero32)
      (markerPath (tscBranchReduce fuel xs index)) index = (merkleReduce fuel xs).root := by
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
        have hr : index / 2 < (merkleLevel (a :: b :: rest)).1.length := by
          rw [merkleLevel_length]; simp only [List.length_cons] at hi ⊢; omega
        have hfuel : (merkleLevel (a :: b :: rest)).1.length ≤ fuel + 1 := by
          rw [merkleLevel_length]; simp only [List.length_cons] at hf ⊢; omega
        have hp := merkleLevel_get (a :: b :: rest) index hi
        -- the generator's one step: the marker or the sibling, then the level above
        rw [tscBranchReduce] at hn ⊢
        by_cases hc : index % 2 = 0 ∧ index + 1 = (a :: b :: rest).length
        · rw [if_pos hc] at hn ⊢
          have hnodes : ∀ w, TscNode.hash w ∈ tscBranchReduce fuel (merkleLevel (a :: b :: rest)).1 (index / 2) →
              w ≠ zero32 := fun w h => hn w (List.mem_cons_of_mem _ h)
          have ht := ih (merkleLevel (a :: b :: rest)).1 (index / 2) hr hfuel hnodes
          have hs := siblingAt_last (a :: b :: rest) index hc.1 hc.2
          have hodd : ¬ index % 2 = 1 := by omega
          rw [if_neg hodd, hs] at hp
          simp only [markerPath, computeRootFromBranch, branchPair_zero]
          simpa only [hp, merkleReduce] using ht
        · rw [if_neg hc] at hn ⊢
          have hnull : siblingAt (a :: b :: rest) index ≠ zero32 := hn _ List.mem_cons_self
          have hnodes : ∀ w, TscNode.hash w ∈ tscBranchReduce fuel (merkleLevel (a :: b :: rest)).1 (index / 2) →
              w ≠ zero32 := fun w h => hn w (List.mem_cons_of_mem _ h)
          have ht := ih (merkleLevel (a :: b :: rest)).1 (index / 2) hr hfuel hnodes
          simp only [markerPath, computeRootFromBranch, branchPair, beq_iff_eq, hnull, ite_false]
          split
          · simpa only [hp, if_pos ‹index % 2 = 1›, merkleReduce] using ht
          · simpa only [hp, if_neg ‹¬ index % 2 = 1›, merkleReduce] using ht

/-- [M] 2026-10-13, #75: the proof the node serves for a body verifies as a TSC
proof. For an in-range position of a leaf list with non-null hash nodes,
`verifyTsc (bodyProof leaves index)` holds with no header supplied, the target
being the body's root. Premises: the position in range and the non-null hash
nodes of `tscBranchReduce_complete`. [SRC] src/rpc/rawtransaction.cpp:2437-2460,2516-2518,
src/consensus/merkle.cpp:247-282,291-310 at 6504a3af. -/
theorem bodyProof_verifies (leaves : List Bytes) (index : Nat) (hi : index < leaves.length)
    (hn : ∀ w, TscNode.hash w ∈ tscBranchReduce leaves.length leaves index → w ≠ zero32) :
    verifyTsc (bodyProof leaves index) = true := by
  have h := tscBranchReduce_complete leaves.length leaves index hi (by omega) hn
  simp only [verifyTsc, bodyProof, resolveTarget, tscLeaf, verifyPath, computeMerkleRoot, h, beq_self_eq_true]

/-- [M] 2026-10-13, #75 (the one-transaction boundary). The node's branch
generator yields the empty vector for a one-leaf body at every position and
fuel; `getmerkleproof` and `getmerkleproof2` refuse an empty vector with RPC
`-5` (`Transaction(s) not found in provided block`), so the node supplies no
proof for a lone transaction. The body-derived reading, `verifyPath leaf [] 0 leaf`,
is #65's `verifyPath_empty`. No premise. [SRC] src/merkletree.cpp:335-339,
src/rpc/rawtransaction.cpp:2302-2306,2447-2450 at 6504a3af. -/
theorem tscBranchReduce_single (fuel : Nat) (a : Bytes) (index : Nat) :
    tscBranchReduce fuel [a] index = [] := by
  cases fuel <;> rfl

/-- [D] 2026-10-13: the empty marker branch and the body-derived empty path
agree: both equate the leaf and the root. [SRC] src/consensus/merkle.cpp:291-310 at 6504a3af. -/
theorem verifyTsc_single (a : Bytes) (index : Nat) :
    verifyTsc ⟨index, .txid a, .merkleRoot a, []⟩ = true := by
  simp [verifyTsc, resolveTarget, tscLeaf, markerPath, verifyPath, computeRootFromBranch]

end BsvChain.Properties
