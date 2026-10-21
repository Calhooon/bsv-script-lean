import BsvChain.Properties.TxCodec
import BsvChain.Properties.MerkleProof

/-!
# Client wire formats as views: the shared byte layer (#86)

[M] 2026-10-15 (#86). The five wire views (`EF`, `BUMP`, `BEEF`,
`AtomicBEEF`, `TSC`) are client encodings. They are views, never rules: no
consensus or policy rule of the node reads any of them, and nothing here
changes a verdict of the machine. Each view has a codec, two round trips and a
function to the machine's objects (a transaction, its spent outputs, its
ancestry, a merkle path of #65).

This module holds the reverse direction of the readers the views share:
"serialize after parse is the identity on byte-valued input". #68 G4
(`decodeTxPrefix_serTx`) proved the forward direction (parse after
serialize); the lemmas below prove the other one for `readBytes`, `readLE`,
`readVarInt`, `readMany`, the input and output readers and the transaction
prefix decoder. The CompactSize reader refuses non-canonical encodings
([SRC] src/serialize.h:315-335 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b),
which is what makes this direction an identity: one value has one encoding.
Every BRC of the views says "VarInt" for its counts and lengths; this spec
reads that as the node's CompactSize, canonical form included [D], and records
an engine that accepts a non-canonical form as a divergence with its witness.
-/

namespace BsvChain.Views.Wire
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash BsvScript.Sighash BsvChain.Properties

/-- [D] 2026-10-15: byte-valuedness splits over a concatenation. -/
theorem byteValued_append {a b : Bytes} : ByteValued (a ++ b) ↔ ByteValued a ∧ ByteValued b := by
  simp only [ByteValued, List.mem_append]
  constructor
  · intro h
    exact ⟨fun x hx => h x (Or.inl hx), fun x hx => h x (Or.inr hx)⟩
  · rintro ⟨ha, hb⟩ x (hx | hx)
    · exact ha x hx
    · exact hb x hx

/-- [D] 2026-10-15: the tail of a byte-valued string is byte-valued. -/
theorem byteValued_cons {b : Nat} {bs : Bytes} (h : ByteValued (b :: bs)) : b < 256 ∧ ByteValued bs :=
  ⟨h b (List.mem_cons_self ..), fun x hx => h x (List.mem_cons_of_mem _ hx)⟩

/-- [D] 2026-10-15: a successful `readBytes` splits its input: the bytes taken,
then the rest. [SRC] src/serialize.h:786-792 at 6504a3af. -/
theorem readBytes_inv {n : Nat} {bs a r : Bytes} (h : readBytes n bs = some (a, r)) :
    a ++ r = bs ∧ a.length = n := by
  unfold readBytes at h
  split at h
  · cases h
  · rename_i hlt
    simp only [Option.some.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl⟩ := h
    refine ⟨List.take_append_drop n bs, ?_⟩
    simp only [List.length_take]
    omega

/-- [D] 2026-10-15: a successful little-endian read of byte-valued input is
the fixed-width word of its value, below `256 ^ n`, then the rest.
[SRC] src/serialize.h:71-91 at 6504a3af. -/
theorem readLE_inv {n v : Nat} {bs r : Bytes} (hb : ByteValued bs) (h : readLE n bs = some (v, r)) :
    headerWordBytes n v ++ r = bs ∧ v < 256 ^ n := by
  unfold readLE at h
  split at h
  · cases h
  · rename_i hlt
    simp only [Option.some.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl⟩ := h
    have hl : (bs.take n).length = n := by simp only [List.length_take]; omega
    have ht : ByteValued (bs.take n) := fun b hb' => hb b (List.mem_of_mem_take hb')
    have e := headerWordBytes_leNat (bs.take n) ht
    have lt := leNat_bytes_lt (bs.take n) ht
    rw [hl] at e lt
    exact ⟨by rw [e]; exact List.take_append_drop n bs, lt⟩

/-- [D] 2026-10-15: the 2-byte CompactSize body is the 2-byte word. -/
theorem compactSize2_eq (v : Nat) : [v % 256, v / 256 % 256] = headerWordBytes 2 v := by
  simp [headerWordBytes, Nat.div_div_eq_div_mul]

/-- [D] 2026-10-15: CompactSize after a successful canonical read of byte-valued
input gives the input back: the reader accepts exactly the writer's encodings.
[SRC] src/serialize.h:296-335 at 6504a3af. -/
theorem readVarInt_inv {v : Nat} {bs r : Bytes} (hb : ByteValued bs) (h : readVarInt bs = some (v, r)) :
    compactSize v ++ r = bs ∧ v < 2 ^ 64 := by
  match bs, hb, h with
  | b :: rest, hb, h =>
    obtain ⟨hb0, hr⟩ := byteValued_cons hb
    simp only [readVarInt] at h
    split at h
    · rename_i hlt
      simp only [Option.some.injEq, Prod.mk.injEq] at h
      obtain ⟨rfl, rfl⟩ := h
      refine ⟨by simp [compactSize, hlt], by omega⟩
    · rename_i hlt
      split at h
      · rename_i h253
        obtain ⟨hread, hge⟩ := Option.filter_eq_some_iff.mp h
        obtain ⟨e, lt⟩ := readLE_inv hr hread
        simp only [decide_eq_true_eq] at hge
        have hlt2 : v ≤ 0xffff := by norm_num at lt; omega
        refine ⟨?_, by omega⟩
        simp only [compactSize, show ¬ v < 253 by omega, if_false, hlt2, if_true, compactSize2_eq,
          List.cons_append, e, h253]
      · rename_i h253
        split at h
        · rename_i h254
          obtain ⟨hread, hge⟩ := Option.filter_eq_some_iff.mp h
          obtain ⟨e, lt⟩ := readLE_inv hr hread
          simp only [decide_eq_true_eq] at hge
          have hlt4 : v ≤ 0xffffffff := by norm_num at lt; omega
          refine ⟨?_, by omega⟩
          simp only [compactSize, show ¬ v < 253 by omega, show ¬ v ≤ 0xffff by omega, if_false,
            hlt4, if_true, le32_eq, List.cons_append, e, h254]
        · rename_i h254
          obtain ⟨hread, hge⟩ := Option.filter_eq_some_iff.mp h
          obtain ⟨e, lt⟩ := readLE_inv hr hread
          simp only [decide_eq_true_eq] at hge
          have hb255 : b = 255 := by omega
          refine ⟨?_, by norm_num at lt; omega⟩
          simp only [compactSize, show ¬ v < 253 by omega, show ¬ v ≤ 0xffff by omega,
            show ¬ v ≤ 0xffffffff by omega, if_false, le64_eq, List.cons_append, e, hb255]

/-- [D] 2026-10-15: `readMany` after a reader whose every success is undone by
its writer is undone by the concatenated writer; the count is the length.
[SRC] src/serialize.h:794-804,823-840 at 6504a3af. -/
theorem readMany_inv {α : Type} (reader : Bytes → Option (α × Bytes)) (ser : α → Bytes)
    (hr : ∀ bs x r, ByteValued bs → reader bs = some (x, r) → ser x ++ r = bs) :
    ∀ (n : Nat) (bs : Bytes) (xs : List α) (r : Bytes), ByteValued bs →
      readMany reader n bs = some (xs, r) → (xs.map ser).flatten ++ r = bs ∧ xs.length = n := by
  intro n
  induction n with
  | zero =>
    intro bs xs r _ h
    simp only [readMany, Option.some.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl⟩ := h
    simp
  | succ n ih =>
    intro bs xs r hb h
    simp only [readMany, bind, Option.bind] at h
    split at h
    · cases h
    · rename_i p hp
      obtain ⟨x, r1⟩ := p; try dsimp only at h
      split at h
      · cases h
      · rename_i q hq
        obtain ⟨ys, r2⟩ := q; try dsimp only at h
        simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl⟩ := h
        have e1 := hr bs x r1 hb hp
        have hb1 : ByteValued r1 := (byteValued_append.mp (e1 ▸ hb)).2
        obtain ⟨e2, hl⟩ := ih r1 ys r2 hb1 hq
        refine ⟨?_, by simp [hl]⟩
        simp only [List.map_cons, List.flatten_cons, List.append_assoc, e2, e1]

/-- [D] 2026-10-15: an input read from byte-valued bytes writes back to them.
[SRC] src/primitives/transaction.h:60-66,151-157 at 6504a3af. -/
theorem readTxIn_inv (bs : Bytes) (i : TxIn) (r : Bytes) (hb : ByteValued bs)
    (h : readTxIn bs = some (i, r)) : serTxIn i ++ r = bs := by
  simp only [readTxIn, bind, Option.bind] at h
  split at h; · cases h
  rename_i p1 h1; obtain ⟨prevHash, r1⟩ := p1; try dsimp only at h
  split at h; · cases h
  rename_i p2 h2; obtain ⟨prevIndex, r2⟩ := p2; try dsimp only at h
  split at h; · cases h
  rename_i p3 h3; obtain ⟨len, r3⟩ := p3; try dsimp only at h
  split at h; · cases h
  rename_i p4 h4; obtain ⟨script, r4⟩ := p4; try dsimp only at h
  split at h; · cases h
  rename_i p5 h5; obtain ⟨sequence, r5⟩ := p5; try dsimp only at h
  simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
  obtain ⟨rfl, rfl⟩ := h
  obtain ⟨e1, _⟩ := readBytes_inv h1
  have b1 : ByteValued r1 := (byteValued_append.mp (e1 ▸ hb)).2
  obtain ⟨e2, _⟩ := readLE_inv b1 h2
  have b2 : ByteValued r2 := (byteValued_append.mp (e2 ▸ b1)).2
  obtain ⟨e3, _⟩ := readVarInt_inv b2 h3
  have b3 : ByteValued r3 := (byteValued_append.mp (e3 ▸ b2)).2
  obtain ⟨e4, hl4⟩ := readBytes_inv h4
  have b4 : ByteValued r4 := (byteValued_append.mp (e4 ▸ b3)).2
  obtain ⟨e5, _⟩ := readLE_inv b4 h5
  simp only [serTxIn, serOutPoint, serScript, le32_eq, List.append_assoc, hl4, e5, e4, e3, e2, e1]

/-- [D] 2026-10-15: an output read from byte-valued bytes writes back to them.
[SRC] src/primitives/transaction.h:189-194 at 6504a3af. -/
theorem readTxOut_inv (bs : Bytes) (o : TxOut) (r : Bytes) (hb : ByteValued bs)
    (h : readTxOut bs = some (o, r)) : serTxOut o ++ r = bs := by
  simp only [readTxOut, bind, Option.bind] at h
  split at h; · cases h
  rename_i p1 h1; obtain ⟨value, r1⟩ := p1; try dsimp only at h
  split at h; · cases h
  rename_i p2 h2; obtain ⟨len, r2⟩ := p2; try dsimp only at h
  split at h; · cases h
  rename_i p3 h3; obtain ⟨script, r3⟩ := p3; try dsimp only at h
  simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
  obtain ⟨rfl, rfl⟩ := h
  obtain ⟨e1, _⟩ := readLE_inv hb h1
  have b1 : ByteValued r1 := (byteValued_append.mp (e1 ▸ hb)).2
  obtain ⟨e2, _⟩ := readVarInt_inv b1 h2
  have b2 : ByteValued r2 := (byteValued_append.mp (e2 ▸ b1)).2
  obtain ⟨e3, hl3⟩ := readBytes_inv h3
  simp only [serTxOut, serScript, le64_eq, List.append_assoc, hl3, e3, e2, e1]

/-- [D] 2026-10-15: the signed reading of a 32-bit word serializes back to it. -/
theorem serVersion_toInt32 (v : Nat) (h : v < 2 ^ 32) : serVersion (toInt32 v) = headerWordBytes 4 v := by
  have e : (toInt32 v % 2 ^ 32).toNat = v := by
    unfold toInt32
    split <;> omega
  simp only [serVersion, e, le32_eq]

/-- [M] 2026-10-15, #86 (the transaction codec's reverse round trip). A
transaction read from the front of byte-valued bytes serializes back to the
bytes it consumed: `serTx tx ++ rest = bs`. With #68 G4 this makes the raw
transaction format a bijection between well-formed transactions and the
byte strings the decoder accepts. Premise: the input is byte-valued.
[SRC] src/primitives/transaction.h:233-252 and src/serialize.h:71-116,296-340,786-840 at 6504a3af. -/
theorem serTx_decodeTxPrefix (bs : Bytes) (tx : Tx) (r : Bytes) (hb : ByteValued bs)
    (h : decodeTxPrefix bs = some (tx, r)) : serTx tx ++ r = bs := by
  simp only [decodeTxPrefix, bind, Option.bind] at h
  split at h; · cases h
  rename_i p1 h1; obtain ⟨v, r1⟩ := p1; try dsimp only at h
  split at h; · cases h
  rename_i p2 h2; obtain ⟨nIn, r2⟩ := p2; try dsimp only at h
  split at h; · cases h
  rename_i p3 h3; obtain ⟨inputs, r3⟩ := p3; try dsimp only at h
  split at h; · cases h
  rename_i p4 h4; obtain ⟨nOut, r4⟩ := p4; try dsimp only at h
  split at h; · cases h
  rename_i p5 h5; obtain ⟨outputs, r5⟩ := p5; try dsimp only at h
  split at h; · cases h
  rename_i p6 h6; obtain ⟨lockTime, r6⟩ := p6; try dsimp only at h
  simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
  obtain ⟨rfl, rfl⟩ := h
  obtain ⟨e1, lt1⟩ := readLE_inv hb h1
  have b1 : ByteValued r1 := (byteValued_append.mp (e1 ▸ hb)).2
  obtain ⟨e2, _⟩ := readVarInt_inv b1 h2
  have b2 : ByteValued r2 := (byteValued_append.mp (e2 ▸ b1)).2
  obtain ⟨e3, l3⟩ := readMany_inv readTxIn serTxIn (fun bs x r hb h => readTxIn_inv bs x r hb h) _ _ _ _ b2 h3
  have b3 : ByteValued r3 := (byteValued_append.mp (e3 ▸ b2)).2
  obtain ⟨e4, _⟩ := readVarInt_inv b3 h4
  have b4 : ByteValued r4 := (byteValued_append.mp (e4 ▸ b3)).2
  obtain ⟨e5, l5⟩ := readMany_inv readTxOut serTxOut (fun bs x r hb h => readTxOut_inv bs x r hb h) _ _ _ _ b4 h5
  have b5 : ByteValued r5 := (byteValued_append.mp (e5 ▸ b4)).2
  obtain ⟨e6, _⟩ := readLE_inv b5 h6
  simp only [serTx, serVersion_toInt32 v (by simpa using lt1), le32_eq, List.append_assoc, l3, l5,
    e6, e5, e4, e3, e2, e1]

/-- [D] 2026-10-15: exact framing in both directions: the exact decoder reads a
well-formed transaction's serialization, and the bytes it accepts are that
serialization. [SRC] src/core_read.cpp:184-191 at 6504a3af (`DecodeHexTx`
refuses trailing bytes). -/
theorem decodeTx_serTx (tx : Tx) (wf : TxWellFormed tx) : decodeTx (serTx tx) = some tx := by
  have h := decodeTxPrefix_serTx tx [] wf
  rw [List.append_nil] at h
  simp [decodeTx, h]

/-- [M] 2026-10-15, #86: the exact transaction decoder's accepted bytes are the
serialization of what it reads. Premise: the input is byte-valued. -/
theorem serTx_decodeTx (bs : Bytes) (tx : Tx) (hb : ByteValued bs) (h : decodeTx bs = some tx) :
    serTx tx = bs := by
  simp only [decodeTx, bind, Option.bind] at h
  split at h; · cases h
  rename_i p hp; obtain ⟨t, rest⟩ := p; try dsimp only at h
  split at h
  · rename_i he
    simp only [pure, Option.some.injEq] at h
    subst h
    have e := serTx_decodeTxPrefix bs t rest hb hp
    simp only [List.isEmpty_iff] at he
    rwa [he, List.append_nil] at e
  · cases h

/-! ## Fixed tags -/

/-- [D] 2026-10-15: consume a fixed byte tag (a version word, a marker or a
prefix) from the front of a byte string. -/
def expectTag (tag bs : Bytes) : Option Bytes :=
  if bs.take tag.length = tag then some (bs.drop tag.length) else none

/-- [D] 2026-10-15: a tag is consumed from the front of its own bytes. -/
theorem expectTag_append (tag rest : Bytes) : expectTag tag (tag ++ rest) = some rest := by
  simp [expectTag]

/-- [D] 2026-10-15: a consumed tag and the rest give the input back. -/
theorem expectTag_inv {tag bs r : Bytes} (h : expectTag tag bs = some r) : tag ++ r = bs := by
  unfold expectTag at h
  split at h
  · rename_i ht
    simp only [Option.some.injEq] at h
    subst h
    conv => rhs; rw [← List.take_append_drop tag.length bs]
    rw [ht]
  · cases h

/-- [D] 2026-10-15: a byte of a byte-valued string, read as a one-byte field. -/
def readByte : Bytes → Option (Nat × Bytes)
  | [] => none
  | b :: rest => some (b, rest)

/-- [D] 2026-10-15: a read byte and the rest give the input back. -/
theorem readByte_inv {bs r : Bytes} {b : Nat} (h : readByte bs = some (b, r)) : b :: r = bs := by
  match bs, h with
  | x :: rest, h =>
    simp only [readByte, Option.some.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl⟩ := h
    rfl

end BsvChain.Views.Wire
