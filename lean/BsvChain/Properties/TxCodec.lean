import BsvChain.Properties.Reachable

/-!
# The transaction serialization round trip (#68, G4)

[M] 2026-10-13 (#68). For a well-formed transaction (every field in its
wire width, every byte below 256), the interpreter's prefix decoder reads the
serializer's bytes back exactly, with any following stream left untouched.
Hence equal serializations are equal transactions, and exact transaction
identity rests on the hash hypothesis alone: equal identifiers of two
well-formed transactions are equal transactions or a SHA256d collision.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/primitives/transaction.h:51-66,89-157,175-194,233-252,
src/primitives/transaction.cpp:79-81 and src/serialize.h:71-116,211-250,296-340,786-840.
-/

namespace BsvChain.Properties
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash BsvScript.Sighash

/-- [D] 2026-10-13: every element is a byte.
[SRC] src/serialize.h:71-91 at 6504a3af. -/
def ByteValued (bs : Bytes) : Prop := ∀ b ∈ bs, b < 256

/-- [D] 2026-10-13: an input whose fields fit their wire widths: a 32-byte
previous hash, a 32-bit index and sequence, a byte-valued script whose length
fits CompactSize. [SRC] src/primitives/transaction.h:51-66,89-157 at 6504a3af. -/
def TxInWellFormed (i : TxIn) : Prop :=
  i.prevHash.length = 32 ∧ ByteValued i.prevHash ∧ i.prevIndex < 2 ^ 32 ∧
    ByteValued i.scriptSig ∧ i.scriptSig.length < 2 ^ 64 ∧ i.sequence < 2 ^ 32

/-- [D] 2026-10-13: an output whose value fits 64 bits and whose script is
byte-valued with a CompactSize length. [SRC] src/primitives/transaction.h:175-194 at 6504a3af. -/
def TxOutWellFormed (o : TxOut) : Prop :=
  o.value < 2 ^ 64 ∧ ByteValued o.scriptPubKey ∧ o.scriptPubKey.length < 2 ^ 64

/-- [D] 2026-10-13: a transaction whose version is a signed 32-bit integer,
whose counts fit CompactSize, whose lock time fits 32 bits and whose inputs and
outputs are well formed. [SRC] src/primitives/transaction.h:233-252 and
src/serialize.h:211-212,245-247 at 6504a3af. -/
def TxWellFormed (tx : Tx) : Prop :=
  -2 ^ 31 ≤ tx.version ∧ tx.version < 2 ^ 31 ∧ tx.inputs.length < 2 ^ 64 ∧
    tx.outputs.length < 2 ^ 64 ∧ tx.lockTime < 2 ^ 32 ∧
    (∀ i ∈ tx.inputs, TxInWellFormed i) ∧ ∀ o ∈ tx.outputs, TxOutWellFormed o

/-- [D] 2026-10-13: the 32-bit writer is the fixed-width word of four bytes.
[SRC] src/serialize.h:81-86,105-110 at 6504a3af. -/
theorem le32_eq (v : Nat) : le32 v = headerWordBytes 4 v := by
  simp [le32, headerWordBytes, Nat.div_div_eq_div_mul]

/-- [D] 2026-10-13: the 64-bit writer is the fixed-width word of eight bytes.
[SRC] src/serialize.h:87-92,111-116 at 6504a3af. -/
theorem le64_eq (v : Nat) : le64 v = headerWordBytes 8 v := by
  simp [le64, headerWordBytes, List.range_succ, Nat.div_div_eq_div_mul]

/-- [D] 2026-10-13: a byte string of the requested length reads back.
[SRC] src/serialize.h:786-792,806-820 at 6504a3af. -/
theorem readBytes_append (s rest : Bytes) :
    readBytes s.length (s ++ rest) = some (s, rest) := by
  simp [readBytes]

/-- [D] 2026-10-13: CompactSize reads back every length below 2^64,
canonically. [SRC] src/serialize.h:296-335 at 6504a3af. -/
theorem readVarInt_compactSize (n : Nat) (rest : Bytes) (h : n < 2 ^ 64) :
    readVarInt (compactSize n ++ rest) = some (n, rest) := by
  unfold compactSize
  split
  · simp [readVarInt, *]
  · split
    · have he : (253 :: [n % 256, n / 256 % 256]) ++ rest = 253 :: (headerWordBytes 2 n ++ rest) := by
        simp [headerWordBytes]
      rw [he]
      simp only [readVarInt, readLE_headerWordBytes _ _ _ (by omega : n < 256 ^ 2)]
      simp; omega
    · split
      · have he : (254 :: le32 n) ++ rest = 254 :: (headerWordBytes 4 n ++ rest) := by simp [le32_eq]
        rw [he]
        simp only [readVarInt, readLE_headerWordBytes _ _ _ (by omega : n < 256 ^ 4)]
        simp; omega
      · have he : (255 :: le64 n) ++ rest = 255 :: (headerWordBytes 8 n ++ rest) := by simp [le64_eq]
        rw [he]
        simp only [readVarInt, readLE_headerWordBytes _ _ _ (by omega : n < 256 ^ 8)]
        simp; omega

/-- [D] 2026-10-13: a well-formed input reads back from its serialization.
[SRC] src/primitives/transaction.h:60-66,151-157 at 6504a3af. -/
theorem readTxIn_serTxIn (i : TxIn) (rest : Bytes) (wf : TxInWellFormed i) :
    readTxIn (serTxIn i ++ rest) = some (i, rest) := by
  obtain ⟨hl, _, hidx, _, hsl, hseq⟩ := wf
  have h1 : serTxIn i ++ rest = i.prevHash ++ (headerWordBytes 4 i.prevIndex ++
      (compactSize i.scriptSig.length ++ (i.scriptSig ++ (headerWordBytes 4 i.sequence ++ rest)))) := by
    simp [serTxIn, serOutPoint, serScript, le32_eq, List.append_assoc]
  rw [h1]
  simp only [readTxIn, bind, Option.bind]
  rw [← hl, readBytes_append]
  simp only [readLE_headerWordBytes _ _ _ (by omega : i.prevIndex < 256 ^ 4),
    readVarInt_compactSize _ _ hsl, readBytes_append,
    readLE_headerWordBytes _ _ _ (by omega : i.sequence < 256 ^ 4), pure]

/-- [D] 2026-10-13: a well-formed output reads back from its serialization.
[SRC] src/primitives/transaction.h:189-194 at 6504a3af. -/
theorem readTxOut_serTxOut (o : TxOut) (rest : Bytes) (wf : TxOutWellFormed o) :
    readTxOut (serTxOut o ++ rest) = some (o, rest) := by
  obtain ⟨hv, _, hsl⟩ := wf
  have h1 : serTxOut o ++ rest = headerWordBytes 8 o.value ++
      (compactSize o.scriptPubKey.length ++ (o.scriptPubKey ++ rest)) := by
    simp [serTxOut, serScript, le64_eq, List.append_assoc]
  rw [h1]
  simp only [readTxOut, bind, Option.bind, readLE_headerWordBytes _ _ _ (by omega : o.value < 256 ^ 8),
    readVarInt_compactSize _ _ hsl, readBytes_append, pure]

/-- [D] 2026-10-13: a list of well-formed items reads back from the
concatenation of their serializations. [SRC] src/serialize.h:794-804,823-840 at 6504a3af. -/
theorem readMany_ser {α : Type} (reader : Bytes → Option (α × Bytes)) (ser : α → Bytes)
    (P : α → Prop) (hr : ∀ x rest, P x → reader (ser x ++ rest) = some (x, rest))
    (xs : List α) (hx : ∀ x ∈ xs, P x) (rest : Bytes) :
    readMany reader xs.length ((xs.map ser).flatten ++ rest) = some (xs, rest) := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
    simp only [List.length_cons, List.map_cons, List.flatten_cons, List.append_assoc, readMany, bind,
      Option.bind, hr x _ (hx x (List.mem_cons_self ..)),
      ih (fun y hy => hx y (List.mem_cons_of_mem _ hy)), pure]

/-- [D] 2026-10-13: the signed 32-bit version reads back.
[SRC] src/serialize.h:211-212,245-247 at 6504a3af. -/
theorem toInt32_version (v : Int) (lo : -2 ^ 31 ≤ v) (hi : v < 2 ^ 31) :
    toInt32 (v % 2 ^ 32).toNat = v := by
  unfold toInt32
  split <;> omega

/-- [M] 2026-10-13, #68 G4 (the serialization round trip). For every
well-formed transaction, the interpreter's prefix decoder reads its
serialization back exactly and leaves any following bytes untouched.
Premise in plain words: the transaction is well formed (`wf`): a signed 32-bit
version, counts and script lengths that fit CompactSize, 32-bit indices,
sequences and lock time, 64-bit values, 32-byte previous hashes and
byte-valued scripts; every transaction decoded from bytes is so. The
reference's writer and reader also refuse a CompactSize above MAX_SIZE
(src/serialize.h:297-299,336-338); the model's reader leaves that bound out,
as its own docstring says, so this round trip is the model codec's.
[SRC] src/primitives/transaction.h:233-252 and src/serialize.h:71-116,296-340,786-840 at 6504a3af. -/
theorem decodeTxPrefix_serTx (tx : Tx) (rest : Bytes) (wf : TxWellFormed tx) :
    decodeTxPrefix (serTx tx ++ rest) = some (tx, rest) := by
  obtain ⟨lo, hi, hin, hout, hlock, win, wout⟩ := wf
  have h1 : serTx tx ++ rest = headerWordBytes 4 ((tx.version % 2 ^ 32).toNat) ++
      (compactSize tx.inputs.length ++ ((tx.inputs.map serTxIn).flatten ++
      (compactSize tx.outputs.length ++ ((tx.outputs.map serTxOut).flatten ++
      (headerWordBytes 4 tx.lockTime ++ rest))))) := by
    simp [serTx, serVersion, le32_eq, List.append_assoc]
  rw [h1]
  have hv : (tx.version % 2 ^ 32).toNat < 256 ^ 4 := by omega
  simp only [decodeTxPrefix, bind, Option.bind, readLE_headerWordBytes _ _ _ hv,
    readVarInt_compactSize _ _ hin, readVarInt_compactSize _ _ hout,
    readMany_ser readTxIn serTxIn TxInWellFormed (fun x r h => readTxIn_serTxIn x r h) _ win,
    readMany_ser readTxOut serTxOut TxOutWellFormed (fun x r h => readTxOut_serTxOut x r h) _ wout,
    readLE_headerWordBytes _ _ _ (by omega : tx.lockTime < 256 ^ 4), pure, toInt32_version _ lo hi]

/-- [D] 2026-10-13: the serializer is injective on well-formed transactions.
[SRC] src/primitives/transaction.h:233-252 at 6504a3af. -/
theorem serTx_injective (a b : Tx) (wa : TxWellFormed a) (wb : TxWellFormed b)
    (h : serTx a = serTx b) : a = b := by
  have ha := decodeTxPrefix_serTx a [] wa
  rw [h, decodeTxPrefix_serTx b [] wb] at ha
  exact (Prod.mk.inj (Option.some.inj ha)).1.symm

/-- [M] 2026-10-13, #68 G4's corollary (exact identity from the hash alone).
Two well-formed transactions with equal identifiers are equal, or SHA256d has a
collision between their two distinct serializations. Premises in plain words:
both transactions are well formed and their identifiers are equal; no
collision freedom is assumed, so #65's local txid-injectivity premise reduces
to the hash's commitment on these two serializations.
[SRC] src/primitives/transaction.cpp:79-81 at 6504a3af. -/
theorem txid_eq_or_collision (a b : Tx) (wa : TxWellFormed a) (wb : TxWellFormed b)
    (h : txid a = txid b) : a = b ∨ (serTx a ≠ serTx b ∧ sha256d (serTx a) = sha256d (serTx b)) := by
  by_cases hs : serTx a = serTx b
  · exact Or.inl (serTx_injective a b wa wb hs)
  · exact Or.inr ⟨hs, h⟩

/-- [D] 2026-10-13: collision exclusion on a list holds on every sublist.
[SRC] src/consensus/merkle.cpp:43-50 at 6504a3af. -/
theorem hashCommits_subset (l l' : List Bytes) (h : HashCommits l) (sub : ∀ x ∈ l', x ∈ l) :
    HashCommits l' :=
  fun a ha b hb e => h a (sub a ha) b (sub b hb) e

/-- [M] 2026-10-13, #68 G3 with G4 (exact transaction inclusion for reachable
states). In every reachable state, a path for a transaction's identifier that
verifies against the header root of an active index with its body retained
proves that this very transaction is in that body and on the active chain.
Premises in plain words: those of `reachable_path_inclusion` (reachability,
the identification of the block, the path shape and the verification), the
well-formedness of the transaction and of every body transaction (true of
every decoded transaction), and the commitment hypothesis extended to their
serializations (a hypothesis of the theorem, never an axiom). #65's local
txid-injectivity premise is no longer assumed: G4 discharges it.
[SRC] src/consensus/merkle.cpp:284-327, src/validation.cpp:5770-5781 and
src/primitives/transaction.h:233-252 at 6504a3af. -/
theorem reachable_path_transaction (s : ChainState) (hr : Reachable s) (height : Nat)
    (i : BlockIndex) (b : Block) (tx : Tx) (path : List Bytes) (index : Nat)
    (active : s.active[height]? = some i.id) (lookup : s.tree.get i.id = some i)
    (atHeight : i.height = height) (retained : i.body = some b)
    (range : index < b.transactions.length)
    (depth : path.length = (computeBranch b.transactions index).length)
    (words : PathWords (txid tx) path)
    (canonicalWords : PathWords (txid b.transactions[index]) (computeBranch b.transactions index))
    (nonnull : ∀ node ∈ computeBranch b.transactions index, node ≠ zero32)
    (wfTx : TxWellFormed tx) (wfBody : ∀ other ∈ b.transactions, TxWellFormed other)
    (commitment : HashCommits (pathInputs (txid tx) path index ++
      pathInputs (txid b.transactions[index]) (computeBranch b.transactions index) index ++
      [i.header.encode, b.header.encode] ++ (serTx tx :: b.transactions.map serTx)))
    (valid : verifyPath (txid tx) path index (headerWordBytes 32 i.header.merkleRoot.toNat) = true) :
    tx ∈ b.transactions ∧ ActiveTransaction s.tree s.active tx := by
  obtain ⟨_, _, other, hm, he⟩ := reachable_path_inclusion s hr height i b (txid tx) path index active
    lookup atHeight retained range depth words canonicalWords nonnull
    (hashCommits_subset _ _ commitment (fun x hx => List.mem_append_left _ hx)) valid
  have same : other = tx := by
    rcases txid_eq_or_collision other tx (wfBody other hm) wfTx he with same | ⟨different, equal⟩
    · exact same
    · exact absurd (commitment _ (List.mem_append_right _ (List.mem_cons_of_mem _ (List.mem_map_of_mem hm)))
        _ (List.mem_append_right _ (List.mem_cons_self ..)) equal) different
  subst same
  exact ⟨hm, i.id, List.mem_of_getElem? active, b, by simp [lookup, retained], hm⟩

end BsvChain.Properties
