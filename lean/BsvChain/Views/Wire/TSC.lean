import BsvChain.Views.Wire.BUMP

/-!
# The TSC merkle proof as a wire view (#86)

[M] 2026-10-15 (#86). The binary codec of the TSC "Merkle Proof
Standardised Format" is #75's (`BsvChain.Views.MerkleProof`, the [LIT]
citation of the standard there: retrieved 2026-10-13T23:44:03Z, sha256
`438f2ffb08a225769761934c40479ea7aa0e893e74eae780d7619b5c58c916e7`), and #75
proved parse after serialize (`tsc_decodePrefix_encode`). This module adds
the other direction, serialize after parse on byte-valued input, and the
function to a BUMP of BRC-74, so the five wire views share one projection to
#65's `(leaf, path, index, root)`. Views, never rules.
-/

namespace BsvChain.Views.Wire
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash BsvScript.Sighash BsvChain.Properties BsvChain.Views

/-- [D] 2026-10-15: a header frame read from byte-valued bytes encodes back:
every field's value is below its width, so the bit vector keeps it.
[SRC] src/primitives/block.h:38-45 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b. -/
theorem header_encode_decodePrefix (bs : Bytes) (h : BlockHeader) (r : Bytes) (hb : ByteValued bs)
    (hd : BlockHeader.decodePrefix bs = some (h, r)) : h.encode ++ r = bs := by
  simp only [BlockHeader.decodePrefix, bind, Option.bind] at hd
  split at hd; · cases hd
  rename_i p1 h1; obtain ⟨version, r1⟩ := p1; try dsimp only at hd
  split at hd; · cases hd
  rename_i p2 h2; obtain ⟨prevBlock, r2⟩ := p2; try dsimp only at hd
  split at hd; · cases hd
  rename_i p3 h3; obtain ⟨merkleRoot, r3⟩ := p3; try dsimp only at hd
  split at hd; · cases hd
  rename_i p4 h4; obtain ⟨time, r4⟩ := p4; try dsimp only at hd
  split at hd; · cases hd
  rename_i p5 h5; obtain ⟨bits, r5⟩ := p5; try dsimp only at hd
  split at hd; · cases hd
  rename_i p6 h6; obtain ⟨nonce, r6⟩ := p6; try dsimp only at hd
  simp only [pure, Option.some.injEq, Prod.mk.injEq] at hd
  obtain ⟨rfl, rfl⟩ := hd
  obtain ⟨e1, l1⟩ := readLE_inv hb h1
  have b1 : ByteValued r1 := (byteValued_append.mp (e1 ▸ hb)).2
  obtain ⟨e2, l2⟩ := readLE_inv b1 h2
  have b2 : ByteValued r2 := (byteValued_append.mp (e2 ▸ b1)).2
  obtain ⟨e3, l3⟩ := readLE_inv b2 h3
  have b3 : ByteValued r3 := (byteValued_append.mp (e3 ▸ b2)).2
  obtain ⟨e4, l4⟩ := readLE_inv b3 h4
  have b4 : ByteValued r4 := (byteValued_append.mp (e4 ▸ b3)).2
  obtain ⟨e5, l5⟩ := readLE_inv b4 h5
  have b5 : ByteValued r5 := (byteValued_append.mp (e5 ▸ b4)).2
  obtain ⟨e6, l6⟩ := readLE_inv b5 h6
  have m32 : ∀ v, v < 256 ^ 4 → (BitVec.ofNat 32 v).toNat = v := by
    intro v hv; simp only [BitVec.toNat_ofNat]; exact Nat.mod_eq_of_lt (by simpa using hv)
  have m256 : ∀ v, v < 256 ^ 32 → (BitVec.ofNat 256 v).toNat = v := by
    intro v hv; simp only [BitVec.toNat_ofNat]; exact Nat.mod_eq_of_lt (by simpa using hv)
  simp only [BlockHeader.encode, List.append_assoc, m32 _ l1, m256 _ l2, m256 _ l3, m32 _ l4, m32 _ l5,
    m32 _ l6, e6, e5, e4, e3, e2, e1]

/-- [D] 2026-10-15: a node read from bytes writes back to them. [LIT] the TSC node layout. -/
theorem readNode_inv (bs : Bytes) (n : TscNode) (r : Bytes) (h : readNode bs = some (n, r)) :
    encodeNode n ++ r = bs := by
  match bs, h with
  | 0 :: rest, h =>
    simp only [readNode, Option.map_eq_some_iff] at h
    obtain ⟨⟨w, r'⟩, hr, he⟩ := h
    simp only [Prod.mk.injEq] at he
    obtain ⟨rfl, rfl⟩ := he
    obtain ⟨e, _⟩ := readBytes_inv hr
    simp [encodeNode, e]
  | 1 :: rest, h =>
    simp only [readNode, Option.some.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl⟩ := h
    rfl

/-- [D] 2026-10-15: a `txOrId` field read from byte-valued bytes writes back, and
its flag bit is the one read. -/
theorem decodeTxOrId_inv (bit : Nat) (bs : Bytes) (t : TscTxOrId) (r : Bytes) (hb : ByteValued bs)
    (h : decodeTxOrId bit bs = some (t, r)) : encodeTxOrId t ++ r = bs ∧ txBit t = (if bit = 1 then 1 else 0) := by
  unfold decodeTxOrId at h
  split at h
  · rename_i hbit
    simp only [Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
    obtain ⟨⟨len, r1⟩, h1, ⟨raw, r2⟩, h2, he⟩ := h
    simp only [Prod.mk.injEq] at he
    obtain ⟨rfl, rfl⟩ := he
    obtain ⟨e1, _⟩ := readVarInt_inv hb h1
    obtain ⟨e2, hl⟩ := readBytes_inv h2
    refine ⟨?_, by simp [txBit, hbit]⟩
    simp only [encodeTxOrId, List.append_assoc, hl, e2, e1]
  · rename_i hbit
    simp only [Option.map_eq_some_iff] at h
    obtain ⟨⟨w, r1⟩, h1, he⟩ := h
    simp only [Prod.mk.injEq] at he
    obtain ⟨rfl, rfl⟩ := he
    obtain ⟨e1, _⟩ := readBytes_inv h1
    exact ⟨by simp [encodeTxOrId, e1], by simp [txBit, hbit]⟩

/-- [D] 2026-10-15: a `target` field read from byte-valued bytes writes back, and
its kind is the one read. -/
theorem decodeTarget_inv (kind : Nat) (bs : Bytes) (t : TscTarget) (r : Bytes) (hb : ByteValued bs)
    (h : decodeTarget kind bs = some (t, r)) : encodeTarget t ++ r = bs ∧ targetKind t = kind := by
  unfold decodeTarget at h
  split at h
  · simp only [Option.map_eq_some_iff] at h
    obtain ⟨⟨w, r1⟩, h1, he⟩ := h
    simp only [Prod.mk.injEq] at he
    obtain ⟨rfl, rfl⟩ := he
    obtain ⟨e1, _⟩ := readBytes_inv h1
    exact ⟨by simp [encodeTarget, e1], rfl⟩
  · simp only [Option.map_eq_some_iff] at h
    obtain ⟨⟨hd, r1⟩, h1, he⟩ := h
    simp only [Prod.mk.injEq] at he
    obtain ⟨rfl, rfl⟩ := he
    exact ⟨header_encode_decodePrefix bs hd r1 hb h1, rfl⟩
  · simp only [Option.map_eq_some_iff] at h
    obtain ⟨⟨w, r1⟩, h1, he⟩ := h
    simp only [Prod.mk.injEq] at he
    obtain ⟨rfl, rfl⟩ := he
    obtain ⟨e1, _⟩ := readBytes_inv h1
    exact ⟨by simp [encodeTarget, e1], rfl⟩
  · cases h

/-- [M] 2026-10-15, #86 (the TSC proof, serialize after parse). A binary TSC
proof read from the front of byte-valued bytes encodes back to exactly the
bytes read: the flags byte is the one the fields determine, so no other
flags value is accepted for the same fields. Premise: the input is
byte-valued. With #75's `tsc_decodePrefix_encode` the codec is a bijection
between well-formed proofs and the bytes the decoder accepts.
[LIT] the TSC binary layout, cited in `BsvChain.Views.MerkleProof`. -/
theorem tsc_encode_decodePrefix (bs : Bytes) (p : TscProof) (r : Bytes) (hb : ByteValued bs)
    (h : Views.decodePrefix bs = some (p, r)) : p.encode ++ r = bs := by
  match bs, hb, h with
  | flags :: rest, hb, h =>
    obtain ⟨_, hr⟩ := byteValued_cons hb
    simp only [Views.decodePrefix] at h
    split at h; · cases h
    rename_i hf; try dsimp only at h
    simp only [Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
    obtain ⟨⟨index, r1⟩, h1, ⟨txOrId, r2⟩, h2, ⟨target, r3⟩, h3, ⟨count, r4⟩, h4, ⟨nodes, r5⟩, h5, he⟩ := h
    simp only [Prod.mk.injEq] at he
    obtain ⟨rfl, rfl⟩ := he
    obtain ⟨e1, _⟩ := readVarInt_inv hr h1
    have b1 : ByteValued r1 := (byteValued_append.mp (e1 ▸ hr)).2
    obtain ⟨e2, hbit⟩ := decodeTxOrId_inv _ _ _ _ b1 h2
    have b2 : ByteValued r2 := (byteValued_append.mp (e2 ▸ b1)).2
    obtain ⟨e3, hkind⟩ := decodeTarget_inv _ _ _ _ b2 h3
    have b3 : ByteValued r3 := (byteValued_append.mp (e3 ▸ b2)).2
    obtain ⟨e4, _⟩ := readVarInt_inv b3 h4
    have b4 : ByteValued r4 := (byteValued_append.mp (e4 ▸ b3)).2
    obtain ⟨e5, hl⟩ := readMany_inv readNode encodeNode (fun bs x r _ h => readNode_inv bs x r h) _ _ _ _ b4 h5
    have hflags : txBit txOrId + 2 * targetKind target = flags := by
      rw [hbit, hkind]
      split <;> omega
    simp only [TscProof.encode, TscProof.flags, hflags, List.cons_append, List.append_assoc, hl, e5, e4, e3,
      e2, e1]

/-- [M] 2026-10-15, #86: the exact TSC decoder's accepted bytes are the encoding
of what it reads. Premise: the input is byte-valued. -/
theorem tsc_encode_decode (bs : Bytes) (p : TscProof) (hb : ByteValued bs) (h : Views.decode bs = some p) :
    p.encode = bs := by
  unfold Views.decode at h
  split at h
  · rename_i p' hp
    simp only [Option.some.injEq] at h
    subst h
    simpa using tsc_encode_decodePrefix bs p' [] hb hp
  · cases h

/-! ## The function to a BUMP and to #65's path -/

/-- [D] 2026-10-15: the single-path BUMP of a TSC proof at a block height: its
leaf (the id, or the carried transaction's id), its index, its nodes. -/
def _root_.BsvChain.Views.TscProof.toBump (p : TscProof) (height : Nat) : Bump :=
  Bump.ofTsc height (tscLeaf p.txOrId) p.index p.nodes

/-- [M] 2026-10-15, #86 (TSC, BUMP and #65 agree). Whenever the target supplies
a root and no hash node is the zero word, the TSC proof verifies exactly when
its BUMP computes that root for the proof's leaf at the proof's index.
Premises: the target resolves to `root`; no hash node is the all-zero word
(the node reads that word as the marker, BRC-74 hashes it).
[SRC] src/consensus/merkle.cpp:291-310 at 6504a3af; [LIT] BRC-74 at 5333fd4. -/
theorem verifyTsc_eq_bump (p : TscProof) (supplied : Option BlockHeader) (root : Bytes) (height : Nat)
    (h : resolveTarget p.target supplied = some root) (nz : ∀ w, TscNode.hash w ∈ p.nodes → w ≠ zero32) :
    verifyTsc p supplied = ((p.toBump height).rootFor (tscLeaf p.txOrId) p.index == some root) := by
  simp only [verifyTsc, h, verifyPath, TscProof.toBump, rootFor_ofTsc, bumpFold_eq _ _ _ nz]
  cases hc : computeRootFromBranch (tscLeaf p.txOrId) (markerPath p.nodes) p.index == root <;>
    simp_all

end BsvChain.Views.Wire
