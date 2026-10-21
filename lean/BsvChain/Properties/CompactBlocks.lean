import BsvChain.Wire.CompactBlocks
import BsvChain.Properties.P2P

/-!
# Compact blocks' laws (#79), 2026-10-15 [D]

Views of the relay layer, never block-validity rules. The SipHash of the
short id at the reference's own test vectors; the round trips of
`cmpctblock`, `getblocktxn`, `blocktxn` and `sendcmpct`; and THE
RECONSTRUCTION THEOREM: for the message a sender builds from a block, when no
two of the receiver's candidate transactions share a short id with
different transactions, `InitData` yields exactly the block's transactions it
holds, the positions it asks for with `getblocktxn` are exactly the block's
transactions it lacks and nothing else, and `FillBlock` with them yields
exactly the announced block, or the reference's `CheckBlock` verdict when the
block is invalid. The collision cases as the source handles them: two equal
short ids in the message fail it (the whole block is requested, no score);
two pool transactions on one short id leave the position to be requested;
the scan's early exit can place a wrong transaction, which only a
`CheckBlock` that accepts the filled block lets through.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b, as cited
in `lean/BsvChain/Wire/CompactBlocks.lean`.
-/

namespace BsvChain.Wire
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash BsvScript.Sighash BsvChain.Properties

/-! ## 1. SipHash at the reference's test vectors -/

/-- [D] 2026-10-15: SipHash-2-4 of the empty string under the key 00..0f is
the vector of src/test/hash_tests.cpp:62-63,87-88 at 6504a3af (the SipHash
paper's). A view, never a rule. -/
theorem sipHash24_empty_vector :
    sipHash24 0x0706050403020100 0x0F0E0D0C0B0A0908 [] = 0x726fdb47dd0e0e31 := by
  decide +kernel

/-- [D] 2026-10-15: SipHash-2-4 of the 32 bytes 00..1f under the key 00..0f
is the vector `SipHashUint256` meets at src/test/hash_tests.cpp:111-115 at
6504a3af (the 32-byte form the short id takes). A view, never a rule. -/
theorem sipHash24_uint256_vector :
    sipHash24 0x0706050403020100 0x0F0E0D0C0B0A0908 (List.range 32) = 0x7127512f72f27cce := by
  decide +kernel

/-- [D] 2026-10-15: a short id fits its six bytes (src/blockencodings.cpp:81
at 6504a3af). A view, never a rule. -/
theorem shortIdOf_lt (keys : UInt64 × UInt64) (h : Bytes) : shortIdOf keys h < 2 ^ 48 :=
  Nat.mod_lt _ (by norm_num)

/-! ## 2. The round trips -/

/-- [D] 2026-10-15: a prefilled transaction with a 32-bit index and a
well-formed transaction reads back. [SRC] src/blockencodings.h:131-140 at
6504a3af. -/
theorem PrefilledTx.read_encode (p : PrefilledTx) (rest : Bytes) (hi : p.index ≤ 0xffffffff)
    (hw : TxWellFormed p.tx) : PrefilledTx.read (p.encode ++ rest) = some (p, rest) := by
  have hn : ¬ p.index > 0xffffffff := by omega
  simp only [PrefilledTx.read, PrefilledTx.encode, List.append_assoc, bind, Option.bind,
    readVarInt_compactSize _ _ (by omega : p.index < 2 ^ 64), hn, ite_false,
    decodeTxPrefix_serTx _ _ hw, pure]

/-- [D] 2026-10-15: a message whose fields fit their wire widths: a 64-bit
nonce, counts below 2^64, short ids of 48 bits, 32-bit prefilled indices,
well-formed prefilled transactions. -/
def CompactBlock.WellFormed (c : CompactBlock) : Prop :=
  c.nonce < 2 ^ 64 ∧ c.shortIds.length < 2 ^ 64 ∧ (∀ s ∈ c.shortIds, s < 2 ^ 48) ∧
    c.prefilled.length < 2 ^ 64 ∧ ∀ p ∈ c.prefilled, p.index ≤ 0xffffffff ∧ TxWellFormed p.tx

/-- [D] 2026-10-15: THE `cmpctblock` ROUND TRIP: a well-formed message reads
back from its writer's bytes. [SRC] src/blockencodings.h:188-223 at
6504a3af. A view, never a rule. -/
theorem CompactBlock.decode_encode (c : CompactBlock) (wf : c.WellFormed) :
    CompactBlock.decode c.encode = some c := by
  obtain ⟨hn, hl, hs, hpl, hp⟩ := wf
  have h1 := readMany_ser (readLE shortIdBytes) (headerWordBytes shortIdBytes) (· < 2 ^ 48)
    (fun x r hx => readLE_headerWordBytes _ _ _ (by unfold shortIdBytes; norm_num at hx ⊢; omega))
    c.shortIds hs
  have h2 := readMany_ser PrefilledTx.read PrefilledTx.encode
    (fun p => p.index ≤ 0xffffffff ∧ TxWellFormed p.tx)
    (fun x r hx => PrefilledTx.read_encode x r hx.1 hx.2) c.prefilled hp []
  simp only [List.append_nil] at h2
  simp only [CompactBlock.decode, CompactBlock.encode, List.append_assoc, bind, Option.bind,
    header_decodePrefix_encode,
    readLE_headerWordBytes _ _ _ (by norm_num at hn ⊢; omega : c.nonce < 256 ^ 8),
    readVarInt_compactSize _ _ hl, h1, readVarInt_compactSize _ _ hpl, h2, pure, ite_true]

/-- [D] 2026-10-15: the sender's message for a block of well-formed
transactions is well formed (its nonce a 64-bit draw). [SRC]
src/blockencodings.cpp:18-32 at 6504a3af. -/
theorem CompactBlock.ofBlock_wellFormed (b : Block) (nonce : Nat) (hn : nonce < 2 ^ 64)
    (hl : b.transactions.length < 2 ^ 64) (hw : ∀ t ∈ b.transactions, TxWellFormed t) :
    (CompactBlock.ofBlock b nonce).WellFormed := by
  unfold CompactBlock.ofBlock
  split
  · exact ⟨hn, by simp, by simp, by simp, by simp⟩
  · rename_i cb rest h
    rw [h] at hl hw
    refine ⟨hn, by simp at hl ⊢; omega, ?_, by simp, ?_⟩
    · intro s hs
      simp only [List.mem_map] at hs
      obtain ⟨t, _, rfl⟩ := hs
      exact shortIdOf_lt _ _
    · intro p hp
      simp only [List.mem_singleton] at hp
      subst hp
      exact ⟨by norm_num, hw cb (by simp)⟩

/-- [D] 2026-10-15: strictly increasing indices from `next`, each below
0xffffffff (so the reader's 32-bit offset never wraps). -/
def IncreasingFrom : Nat → List Nat → Prop
  | _, [] => True
  | next, i :: is => next ≤ i ∧ i < 0xffffffff ∧ IncreasingFrom (i + 1) is

/-- [D] 2026-10-15: the differential writer keeps the count. -/
theorem diffIndices_length (next : Nat) (is : List Nat) :
    (diffIndices next is).length = is.length := by
  induction is generalizing next with
  | nil => rfl
  | cons i is ih => simp [diffIndices, ih]

/-- [D] 2026-10-15: each difference of increasing indices fits 32 bits. -/
theorem diffIndices_bound (next : Nat) (is : List Nat) (h : IncreasingFrom next is) :
    ∀ d ∈ diffIndices next is, d ≤ 0xffffffff := by
  induction is generalizing next with
  | nil => simp [diffIndices]
  | cons i is ih =>
    obtain ⟨h1, h2, h3⟩ := h
    have hw : (i + 1) % 2 ^ 32 = i + 1 := Nat.mod_eq_of_lt (by omega)
    intro d hd
    simp only [diffIndices, List.mem_cons, hw] at hd
    rcases hd with rfl | hd
    · omega
    · exact ih _ h3 d hd

/-- [D] 2026-10-15: the reader undoes the writer's differences.
[SRC] src/blockencodings.h:65-79 at 6504a3af. -/
theorem undiffIndices_diffIndices (next : Nat) (is : List Nat) (h : IncreasingFrom next is) :
    undiffIndices next (diffIndices next is) = some is := by
  induction is generalizing next with
  | nil => rfl
  | cons i is ih =>
    obtain ⟨h1, h2, h3⟩ := h
    have hw : (i + 1) % 2 ^ 32 = i + 1 := Nat.mod_eq_of_lt (by omega)
    have he : i - next + next = i := by omega
    have hn : ¬ i > 0xffffffff := by omega
    simp only [diffIndices, undiffIndices, he, hn, ite_false, hw, ih _ h3, Option.map_some]

/-- [D] 2026-10-15: one differential index within 32 bits reads back. -/
theorem readIndex_compactSize (d : Nat) (rest : Bytes) (h : d ≤ 0xffffffff) :
    readIndex (compactSize d ++ rest) = some (d, rest) := by
  have hn : ¬ d > 0xffffffff := by omega
  simp only [readIndex, bind, Option.bind, readVarInt_compactSize _ _ (by omega : d < 2 ^ 64),
    hn, ite_false, pure]

/-- [D] 2026-10-15: THE `getblocktxn` ROUND TRIP: a 32-byte hash and strictly
increasing indices below 0xffffffff read back from the writer's bytes.
[SRC] src/blockencodings.h:36-82 at 6504a3af. A view, never a rule. -/
theorem BlockTxnRequest.decode_encode (r : BlockTxnRequest) (hh : r.blockHash.length = 32)
    (hi : IncreasingFrom 0 r.indices) (hl : r.indices.length < 2 ^ 64) :
    BlockTxnRequest.decode r.encode = some r := by
  have hm := readMany_ser readIndex compactSize (· ≤ 0xffffffff)
    (fun x rest hx => readIndex_compactSize x rest hx) (diffIndices 0 r.indices)
    (diffIndices_bound 0 r.indices hi) []
  simp only [List.append_nil, diffIndices_length] at hm
  have hb := readBytes_prefix 32 r.blockHash (compactSize r.indices.length ++
    ((diffIndices 0 r.indices).map compactSize).flatten) hh
  simp only [BlockTxnRequest.decode, BlockTxnRequest.encode, List.append_assoc, bind,
    Option.bind, hb, readVarInt_compactSize _ _ hl, hm, undiffIndices_diffIndices 0 _ hi,
    ite_true, pure]

/-- [D] 2026-10-15: THE `blocktxn` ROUND TRIP: a 32-byte hash and
well-formed transactions read back. [SRC] src/blockencodings.h:84-115 at
6504a3af. A view, never a rule. -/
theorem BlockTxns.decode_encode (b : BlockTxns) (hh : b.blockHash.length = 32)
    (hl : b.txs.length < 2 ^ 64) (hw : ∀ t ∈ b.txs, TxWellFormed t) :
    BlockTxns.decode b.encode = some b := by
  have hm := readMany_ser decodeTxPrefix serTx TxWellFormed
    (fun x rest hx => decodeTxPrefix_serTx x rest hx) b.txs hw []
  simp only [List.append_nil] at hm
  have hb := readBytes_prefix 32 b.blockHash (compactSize b.txs.length ++
    (b.txs.map serTx).flatten) hh
  simp only [BlockTxns.decode, BlockTxns.encode, List.append_assoc, bind, Option.bind, hb,
    readVarInt_compactSize _ _ hl, hm, ite_true, pure]

/-- [D] 2026-10-15: THE `sendcmpct` ROUND TRIP. [SRC]
src/net/net_processing.cpp:1978-1981,2430-2432 at 6504a3af. A view, never a rule. -/
theorem SendCmpct.decode_encode (s : SendCmpct) (hv : s.version < 2 ^ 64) :
    SendCmpct.decode s.encode = some s := by
  obtain ⟨a, v⟩ := s
  have e8 := readLE_headerWordBytes 8 v [] (by norm_num at hv ⊢; omega)
  simp only [List.append_nil] at e8
  cases a <;>
    simp [SendCmpct.decode, SendCmpct.encode, readLE_headerWordBytes _ _ _
      (by norm_num : (0 : Nat) < 256 ^ 1), readLE_headerWordBytes _ _ _
      (by norm_num : (1 : Nat) < 256 ^ 1), e8]

/-! ## 3. The reconstruction -/

section Reconstruction
open Classical

/-- [D] 2026-10-15: the empty positions of a run of empty positions. -/
theorem emptySlotsFrom_replicate (j m : Nat) :
    emptySlotsFrom j (List.replicate m none) = List.range' j m := by
  induction m generalizing j with
  | zero => rfl
  | succ m ih => simp [List.replicate_succ, emptySlotsFrom, ih, List.range'_succ]

/-- [D] 2026-10-15: a short id at position `k` of a list of distinct ones is
found at `j0 + k`. -/
theorem lookup_zip_range'_of_get (keys : List Nat) (hk : keys.Nodup) (j0 k x : Nat)
    (hx : keys[k]? = some x) : (keys.zip (List.range' j0 keys.length)).lookup x = some (j0 + k) := by
  induction keys generalizing j0 k with
  | nil => simp at hx
  | cons a keys ih =>
    rw [List.nodup_cons] at hk
    cases k with
    | zero =>
      simp only [List.getElem?_cons_zero, Option.some.injEq] at hx
      subst hx
      simp [List.range'_succ, List.lookup]
    | succ k =>
      simp only [List.getElem?_cons_succ] at hx
      have hne : x ≠ a := fun h => hk.1 (h ▸ List.mem_of_getElem? hx)
      have := ih hk.2 (j0 + 1) k hx
      have hb : (x == a) = false := by simp [hne]
      simp only [List.length_cons, List.range'_succ, List.zip_cons_cons, List.lookup, hb, this]
      congr 1; omega

/-- [D] 2026-10-15: a short id outside the list is found nowhere. -/
theorem lookup_zip_range'_none (keys : List Nat) (j0 x : Nat) (hx : x ∉ keys) :
    (keys.zip (List.range' j0 keys.length)).lookup x = none := by
  induction keys generalizing j0 with
  | nil => rfl
  | cons a keys ih =>
    simp only [List.mem_cons, not_or] at hx
    have hb : (x == a) = false := by simp [hx.1]
    simp only [List.length_cons, List.range'_succ, List.zip_cons_cons, List.lookup, hb, ih _ hx.2]

/-- [D] 2026-10-15: the scan's state when exactly the block's transactions
that are in `S` have been matched. -/
noncomputable def target (cb : Tx) (rest S : List Tx) : Scan where
  avail := some cb :: rest.map (fun u => if u ∈ S then some u else none)
  seen := false :: rest.map (fun u => decide (u ∈ S))
  count := rest.countP (fun u => decide (u ∈ S))

/-- [D] 2026-10-15: the state depends on `S` only through the block's transactions. -/
theorem target_congr (cb : Tx) (rest S S' : List Tx) (h : ∀ u ∈ rest, u ∈ S ↔ u ∈ S') :
    target cb rest S = target cb rest S' := by
  unfold target
  have h1 : rest.map (fun u => if u ∈ S then some u else none) =
      rest.map (fun u => if u ∈ S' then some u else none) :=
    List.map_congr_left (fun u hu => by simp [h u hu])
  have h2 : rest.map (fun u => decide (u ∈ S)) = rest.map (fun u => decide (u ∈ S')) :=
    List.map_congr_left (fun u hu => by simp [h u hu])
  have h3 : rest.countP (fun u => decide (u ∈ S)) = rest.countP (fun u => decide (u ∈ S')) :=
    List.countP_congr (fun u hu => by simp [h u hu])
  rw [h1, h2, h3]

/-- [D] 2026-10-15: one position of a mapped list replaced. -/
theorem map_set_eq {α β : Type} (l : List α) (k : Nat) (a : α) (b : β) (f g : α → β)
    (hk : l[k]? = some a) (hfg : ∀ i x, l[i]? = some x → i ≠ k → f x = g x) (hg : g a = b) :
    (l.map f).set k b = l.map g := by
  induction l generalizing k with
  | nil => simp at hk
  | cons y l ih =>
    cases k with
    | zero =>
      simp only [List.getElem?_cons_zero, Option.some.injEq] at hk
      subst hk
      simp only [List.map_cons, List.set_cons_zero, hg, List.cons.injEq, true_and]
      exact List.map_congr_left (fun x hx => by
        obtain ⟨i, hi⟩ := List.getElem?_of_mem hx
        exact hfg (i + 1) x (by simpa using hi) (by omega))
    | succ k =>
      simp only [List.getElem?_cons_succ] at hk
      simp only [List.map_cons, List.set_cons_succ, List.cons.injEq]
      exact ⟨hfg 0 y (by simp) (by omega),
        ih k hk (fun i x hx hik => hfg (i + 1) x (by simpa using hx) (by omega))⟩

/-- [D] 2026-10-15: adding a new block transaction to `S` adds one match. -/
theorem countP_insert (l S : List Tx) (a : Tx) (hl : l.Nodup) (ha : a ∈ l) (hS : a ∉ S) :
    l.countP (fun u => decide (u ∈ a :: S)) = l.countP (fun u => decide (u ∈ S)) + 1 := by
  induction l with
  | nil => simp at ha
  | cons x l ih =>
    rw [List.nodup_cons] at hl
    by_cases hx : x = a
    · subst hx
      rw [List.countP_cons, List.countP_cons, List.countP_congr
        (p := fun u => decide (u ∈ x :: S)) (q := fun u => decide (u ∈ S))
        (fun u hu => by
          have : u ≠ x := fun h => hl.1 (h ▸ hu)
          simp [this])]
      simp [hS]
    · have ha' : a ∈ l := by simpa [Ne.symm hx] using ha
      have hx' : (x ∈ a :: S) ↔ x ∈ S := by simp [hx]
      simp only [List.countP_cons, ih hl.2 ha', decide_eq_true_eq, hx']
      omega

/-- [D] 2026-10-15: a list without repeats holds each element at one index. -/
theorem nodup_getElem?_inj {α : Type} (l : List α) (hl : l.Nodup) {i j : Nat} {x : α}
    (hi : l[i]? = some x) (hj : l[j]? = some x) : i = j := by
  rw [List.getElem?_eq_some_iff] at hi hj
  obtain ⟨hi, rfl⟩ := hi
  obtain ⟨hj, he⟩ := hj
  exact (hl.getElem_inj_iff).mp he.symm

/-- [D] 2026-10-15: the facts of a candidate transaction's lookup: found at
the position after its index in the block's other transactions, or nowhere. -/
def LookupFacts (table : List (Nat × Nat)) (sid : Bytes → Nat) (rest : List Tx) (tx : Tx) : Prop :=
  (∀ k, rest[k]? = some tx → table.lookup (sid (txid tx)) = some (k + 1)) ∧
    (tx ∉ rest → table.lookup (sid (txid tx)) = none) ∧
    (∀ j, table.lookup (sid (txid tx)) = some j → ∃ k, j = k + 1 ∧ rest[k]? = some tx)

/-- [D] 2026-10-15: a pool transaction not matched before moves the state
from `S` to `tx :: S`. [SRC] src/blockencodings.cpp:173-191 at 6504a3af. -/
theorem poolStep_target (cb : Tx) (rest S : List Tx) (table : List (Nat × Nat)) (sid : Bytes → Nat)
    (tx : Tx) (hl : rest.Nodup) (hS : tx ∉ S) (hf : LookupFacts table sid rest tx) :
    (target cb rest S).poolStep sid table tx = target cb rest (tx :: S) := by
  obtain ⟨hfound, hnone, hback⟩ := hf
  by_cases hr : tx ∈ rest
  · obtain ⟨k, hk⟩ := List.getElem?_of_mem hr
    have hlk := hfound k hk
    have hseen : (target cb rest S).seen.getD (k + 1) false = false := by
      simp [target, List.getD_eq_getElem?_getD, List.getElem?_map, hk, hS]
    have hne : ∀ i x, rest[i]? = some x → i ≠ k → x ≠ tx := by
      intro i x hx hik hxt
      subst hxt
      exact hik (nodup_getElem?_inj rest hl hx hk)
    unfold Scan.poolStep
    rw [hlk]
    simp only [hseen, Bool.not_false, ite_true]
    unfold target
    simp only [List.set_cons_succ, Scan.mk.injEq, List.cons.injEq, true_and]
    refine ⟨map_set_eq rest k tx (some tx) _ _ hk (fun i x hx hik => ?_) (by simp),
      map_set_eq rest k tx true _ _ hk (fun i x hx hik => ?_) (by simp),
      (countP_insert rest S tx hl hr hS).symm⟩
    · simp [hne i x hx hik]
    · simp [hne i x hx hik]
  · unfold Scan.poolStep
    rw [hnone hr]
    exact target_congr cb rest S (tx :: S) (fun u hu => by
      have : u ≠ tx := fun h => hr (h ▸ hu)
      simp [this])

/-- [D] 2026-10-15: an extra transaction moves the state from `S` to
`tx :: S` (a position already holding the same transaction is left as it
is). [SRC] src/blockencodings.cpp:201-226 at 6504a3af. -/
theorem extraStep_target (cb : Tx) (rest S : List Tx) (table : List (Nat × Nat)) (sid : Bytes → Nat)
    (tx : Tx) (hl : rest.Nodup) (hf : LookupFacts table sid rest tx) :
    (target cb rest S).extraStep sid table tx = target cb rest (tx :: S) := by
  by_cases hS : tx ∈ S
  · obtain ⟨hfound, hnone, hback⟩ := hf
    have hsame : target cb rest (tx :: S) = target cb rest S :=
      target_congr cb rest (tx :: S) S (fun u _ => by
        constructor
        · intro h; simp only [List.mem_cons] at h; rcases h with rfl | h <;> assumption
        · intro h; exact List.mem_cons_of_mem _ h)
    rw [hsame]
    unfold Scan.extraStep
    cases hlk : table.lookup (sid (txid tx)) with
    | none => rfl
    | some j =>
      obtain ⟨k, rfl, hk⟩ := hback j hlk
      have hseen : (target cb rest S).seen.getD (k + 1) false = true := by
        simp [target, List.getD_eq_getElem?_getD, List.getElem?_map, hk, hS]
      have hav : (target cb rest S).avail.getD (k + 1) none = some tx := by
        simp [target, List.getD_eq_getElem?_getD, List.getElem?_map, hk, hS]
      simp only [hseen, Bool.not_true, Bool.false_eq_true, ite_false, hav, bne_self_eq_false]
  · obtain ⟨hfound, hnone, hback⟩ := hf
    by_cases hr : tx ∈ rest
    · obtain ⟨k, hk⟩ := List.getElem?_of_mem hr
      have hlk := hfound k hk
      have hseen : (target cb rest S).seen.getD (k + 1) false = false := by
        simp [target, List.getD_eq_getElem?_getD, List.getElem?_map, hk, hS]
      have hne : ∀ i x, rest[i]? = some x → i ≠ k → x ≠ tx := by
        intro i x hx hik hxt
        subst hxt
        exact hik (nodup_getElem?_inj rest hl hx hk)
      unfold Scan.extraStep
      rw [hlk]
      simp only [hseen, Bool.not_false, ite_true]
      unfold target
      simp only [List.set_cons_succ, Scan.mk.injEq, List.cons.injEq, true_and]
      refine ⟨map_set_eq rest k tx (some tx) _ _ hk (fun i x hx hik => ?_) (by simp),
        map_set_eq rest k tx true _ _ hk (fun i x hx hik => ?_) (by simp),
        (countP_insert rest S tx hl hr hS).symm⟩
      · simp [hne i x hx hik]
      · simp [hne i x hx hik]
    · unfold Scan.extraStep
      rw [hnone hr]
      exact target_congr cb rest S (tx :: S) (fun u hu => by
        have : u ≠ tx := fun h => hr (h ▸ hu)
        simp [this])

/-- [D] 2026-10-15: a full count means every block transaction is matched. -/
theorem all_of_count (cb : Tx) (rest S : List Tx)
    (h : (target cb rest S).count = rest.length) : ∀ u ∈ rest, u ∈ S := by
  have := (List.countP_eq_length (p := fun u => decide (u ∈ S)) (l := rest)).mp h
  intro u hu
  simpa using this u hu

/-- [D] 2026-10-15: the scan with the early exit ends in the state of every
candidate seen. [SRC] src/blockencodings.cpp:192-197,228-233 at 6504a3af. -/
theorem run_target (cb : Tx) (rest : List Tx) (step : Scan → Tx → Scan) (L S : List Tx)
    (good : List Tx → Tx → Prop)
    (hstep : ∀ S' tx, good S' tx → step (target cb rest S') tx = target cb rest (tx :: S'))
    (hgood : ∀ pre tx post, L = pre ++ tx :: post → good (pre.reverse ++ S) tx) :
    Scan.run step rest.length (target cb rest S) L = target cb rest (L.reverse ++ S) := by
  induction L generalizing S with
  | nil => rfl
  | cons tx L ih =>
    have h1 := hstep S tx (by simpa using hgood [] tx L rfl)
    simp only [Scan.run, h1]
    split
    · rename_i hc
      have hall := all_of_count cb rest (tx :: S) hc
      exact target_congr cb rest _ _ (fun u hu => by
        have := hall u hu
        simp only [List.reverse_cons, List.append_assoc, List.singleton_append]
        constructor
        · intro _; exact List.mem_append_right _ this
        · intro _; exact this)
    · have := ih (tx :: S) (fun pre t post hL => by
        have := hgood (tx :: pre) t post (by simp [hL])
        simpa using this)
      simpa using this

/-- [D] 2026-10-15: THE RECONSTRUCTION THEOREM, its `InitData` half. For the
message a sender builds from a block (`ofBlock`: the coinbase prefilled, a
short id for each other transaction) and a receiver whose pool holds
distinct transactions, when the block's short ids are distinct and no
candidate transaction (pool or extra) shares a short id with a block
transaction other than itself, `InitData` yields the block's header and,
at every position, exactly the block's transaction if the receiver holds it
and nothing otherwise. Premises in plain words: a non-null header and
coinbase, a count the block size allows, the bucket bound not exceeded (`crowded` false, its default: the C++ table's
bucket of more than 12 short ids, src/blockencodings.cpp:157-160, fails the
message whatever the ids), the no-collision condition (the
collision case is `initData_ofBlock_duplicate` and the witnesses below).
[SRC] src/blockencodings.cpp:18-32,84-242 at 6504a3af; BIP152 lines 128,141. -/
theorem initData_ofBlock (B : Block) (cb : Tx) (rest : List Tx) (hB : B.transactions = cb :: rest)
    (nonce maxBlockSize : Nat) (pool extra : List Tx)
    (hnull : headerIsNull B.header = false) (hcb : txIsNull cb = false)
    (hsize : rest.length + 1 ≤ maxBlockSize / minTxSize)
    (hids : (rest.map (fun t => shortIdOf (shortIdKeys B.header nonce) (txid t))).Nodup)
    (hpool : pool.Nodup)
    (hcoll : ∀ t, t ∈ pool ∨ t ∈ extra → ∀ u ∈ rest,
      shortIdOf (shortIdKeys B.header nonce) (txid t) =
        shortIdOf (shortIdKeys B.header nonce) (txid u) → t = u) :
    initData maxBlockSize (CompactBlock.ofBlock B nonce) pool extra =
      .ok { header := B.header,
            avail := some cb :: rest.map (fun u => if u ∈ pool ∨ u ∈ extra then some u else none) } := by
  set sid := shortIdOf (shortIdKeys B.header nonce) with hsid
  have hrest : rest.Nodup := List.Nodup.of_map _ hids
  have hc : CompactBlock.ofBlock B nonce =
      { header := B.header, nonce, shortIds := rest.map (fun t => sid (txid t)),
        prefilled := [⟨0, cb⟩] } := by
    simp [CompactBlock.ofBlock, hB, hsid]
  set table := (rest.map (fun t => sid (txid t))).zip (List.range' 1 rest.length) with htable
  have hfacts : ∀ t, t ∈ pool ∨ t ∈ extra → LookupFacts table sid rest t := by
    intro t ht
    have hkeys : (rest.map (fun t => sid (txid t))).length = rest.length := by simp
    refine ⟨fun k hk => ?_, fun hr => ?_, fun j hj => ?_⟩
    · have := lookup_zip_range'_of_get _ hids 1 k (sid (txid t)) (by simp [hk])
      rw [hkeys] at this
      rw [htable, this]; congr 1; omega
    · have hnot : sid (txid t) ∉ rest.map (fun t => sid (txid t)) := by
        intro hm
        simp only [List.mem_map] at hm
        obtain ⟨u, hu, he⟩ := hm
        exact hr (hcoll t ht u hu he.symm ▸ hu)
      have := lookup_zip_range'_none _ 1 _ hnot
      rw [hkeys] at this
      exact this
    · by_cases hr : t ∈ rest
      · obtain ⟨k, hk⟩ := List.getElem?_of_mem hr
        have := lookup_zip_range'_of_get _ hids 1 k (sid (txid t)) (by simp [hk])
        rw [hkeys] at this
        rw [htable, this] at hj
        exact ⟨k, by simp at hj; omega, hk⟩
      · have hnot : sid (txid t) ∉ rest.map (fun t => sid (txid t)) := by
          intro hm
          simp only [List.mem_map] at hm
          obtain ⟨u, hu, he⟩ := hm
          exact hr (hcoll t ht u hu he.symm ▸ hu)
        have := lookup_zip_range'_none _ 1 _ hnot
        rw [hkeys] at this
        rw [htable, this] at hj
        cases hj
  have h0 : Scan.mk (some cb :: List.replicate rest.length none)
      (false :: List.replicate rest.length false) 0 = target cb rest [] := by
    simp [target, List.replicate_succ, List.map_const']
  have hpoolrun := run_target cb rest (Scan.poolStep sid table) pool []
    (fun S tx => tx ∉ S ∧ (tx ∈ pool ∨ tx ∈ extra))
    (fun S tx h => poolStep_target cb rest S table sid tx hrest h.1 (hfacts tx h.2))
    (fun pre tx post hL => by
      subst hL
      refine ⟨?_, Or.inl (by simp)⟩
      rw [List.nodup_append] at hpool
      intro hm
      simp only [List.append_nil, List.mem_reverse] at hm
      exact hpool.2.2 tx hm tx (by simp) rfl)
  have hextrarun := run_target cb rest (Scan.extraStep sid table) extra (pool.reverse ++ [])
    (fun _ tx => tx ∈ pool ∨ tx ∈ extra)
    (fun S tx h => extraStep_target cb rest S table sid tx hrest (hfacts tx h))
    (fun pre tx post hL => Or.inr (by simp [hL]))
  have hfinal : target cb rest (extra.reverse ++ (pool.reverse ++ [])) =
      target cb rest (pool ++ extra) :=
    target_congr cb rest _ _ (fun u _ => by simp [or_comm])
  have hdec : decide (rest.map (fun t => sid (txid t))).Nodup = true := decide_eq_true hids
  rw [hc]
  simp only [initData, CompactBlock.txCount, List.length_map, List.length_singleton, hnull,
    Bool.false_or, List.isEmpty_cons, Bool.and_false, Bool.false_eq_true, ite_false]
  have hsz : ¬ rest.length + 1 > maxBlockSize / minTxSize := by omega
  simp only [hsz, ite_false, bind, Except.bind, pure, Except.pure]
  simp only [placePrefilled, hcb, Bool.false_eq_true, ite_false, Nat.add_zero]
  have hp1 : ¬ (0 : Nat) > 0xffffffff := by omega
  have hp2 : ¬ (0 : Nat) > rest.length := by omega
  simp only [hp1, hp2, ite_false, List.replicate_succ, List.set_cons_zero, hdec, Bool.not_true]
  simp only [emptySlots, emptySlotsFrom, emptySlotsFrom_replicate]
  rw [← htable]
  simp only [Bool.false_eq_true, ite_false]
  rw [← hsid, h0, hpoolrun, hextrarun, hfinal]
  simp [target, List.mem_append]

/-- [D] 2026-10-15: the empty positions of a list from `j` are the positions
`j + i` of its empty entries. -/
theorem mem_emptySlotsFrom (j x : Nat) (l : List (Option Tx)) :
    x ∈ emptySlotsFrom j l ↔ ∃ i, x = j + i ∧ l[i]? = some none := by
  induction l generalizing j with
  | nil => simp [emptySlotsFrom]
  | cons a l ih =>
    cases a with
    | none =>
      simp only [emptySlotsFrom, List.mem_cons, ih]
      constructor
      · rintro (rfl | ⟨i, rfl, hi⟩)
        · exact ⟨0, by simp, rfl⟩
        · exact ⟨i + 1, by omega, by simpa using hi⟩
      · rintro ⟨i, rfl, hi⟩
        cases i with
        | zero => left; rfl
        | succ i => right; exact ⟨i, by omega, by simpa using hi⟩
    | some t =>
      simp only [emptySlotsFrom, ih]
      constructor
      · rintro ⟨i, rfl, hi⟩
        exact ⟨i + 1, by omega, by simpa using hi⟩
      · rintro ⟨i, rfl, hi⟩
        cases i with
        | zero => simp at hi
        | succ i => exact ⟨i, by omega, by simpa using hi⟩

/-- [D] 2026-10-15: the empty positions come in increasing order from `j`. -/
theorem emptySlotsFrom_increasing (j : Nat) (l : List (Option Tx)) (next : Nat) (hj : next ≤ j)
    (hb : j + l.length ≤ 0xffffffff) : IncreasingFrom next (emptySlotsFrom j l) := by
  induction l generalizing j next with
  | nil => trivial
  | cons a l ih =>
    simp only [List.length_cons] at hb
    cases a with
    | none => exact ⟨hj, by omega, ih (j + 1) (j + 1) le_rfl (by omega)⟩
    | some t => exact ih (j + 1) next (by omega) (by omega)

/-- [D] 2026-10-15: THE RECONSTRUCTION THEOREM, the missing set. Under
`initData_ofBlock`'s premises the positions the receiver asks for with
`getblocktxn` are exactly the positions of the block's transactions it holds
in neither its pool nor its extra transactions, and nothing else; the
coinbase is never asked for; they come in increasing order, so the request
reads back (`BlockTxnRequest.decode_encode`) for a block of fewer than
0xffffffff transactions. [SRC] src/blockencodings.cpp:244-252 and
src/net/net_processing.cpp:3919-3935 at 6504a3af. A view, never a rule. -/
theorem missing_ofBlock (B : Block) (cb : Tx) (rest : List Tx) (hB : B.transactions = cb :: rest)
    (pool extra : List Tx) (p : PartialBlock)
    (hp : p.avail = some cb :: rest.map (fun u => if u ∈ pool ∨ u ∈ extra then some u else none)) :
    (∀ j, j ∈ p.missing ↔ ∃ u, B.transactions[j]? = some u ∧ j ≠ 0 ∧ ¬ (u ∈ pool ∨ u ∈ extra)) ∧
      (B.transactions.length ≤ 0xffffffff → IncreasingFrom 0 p.missing) := by
  refine ⟨fun j => ?_, fun hl => ?_⟩
  · simp only [PartialBlock.missing, emptySlots, hp, emptySlotsFrom, mem_emptySlotsFrom, hB]
    constructor
    · rintro ⟨i, rfl, hi⟩
      simp only [List.getElem?_map, Option.map_eq_some_iff] at hi
      obtain ⟨u, hu, he⟩ := hi
      refine ⟨u, by rw [show 1 + i = i + 1 by omega]; simpa using hu, by omega, ?_⟩
      intro hm; simp [hm] at he
    · rintro ⟨u, hu, hj, hn⟩
      cases j with
      | zero => exact absurd rfl hj
      | succ i => exact ⟨i, by omega, by simp at hu; simp [hu, hn]⟩
  · simp only [PartialBlock.missing, emptySlots, hp, emptySlotsFrom]
    rw [hB] at hl
    exact emptySlotsFrom_increasing 1 _ 0 (by omega) (by simp at hl ⊢; omega)

/-- [D] 2026-10-15: the transactions at the empty positions of a mapped
list, read from the block, are the ones the map left out, in order. -/
theorem filterMap_emptySlotsFrom (pre l : List Tx) (f : Tx → Option Tx)
    (hf : ∀ u, f u = some u ∨ f u = none) :
    (emptySlotsFrom pre.length (l.map f)).filterMap (fun i => (pre ++ l)[i]?) =
      l.filter (fun u => (f u).isNone) := by
  induction l generalizing pre with
  | nil => simp [emptySlotsFrom]
  | cons a l ih =>
    have ih' := ih (pre ++ [a])
    simp only [List.length_append, List.length_singleton, List.append_assoc,
      List.singleton_append] at ih'
    rcases hf a with h | h
    · simp only [List.map_cons, h, emptySlotsFrom, ih', List.filter_cons, Option.isNone_some,
        Bool.false_eq_true, ite_false]
    · simp only [List.map_cons, h, emptySlotsFrom, List.filterMap_cons, List.getElem?_append_right
        (le_refl _), Nat.sub_self, List.getElem?_cons_zero, ih', List.filter_cons,
        Option.isNone_none, ite_true]

/-- [D] 2026-10-15: filling a mapped list with the entries it left out gives
the list back. [SRC] src/blockencodings.cpp:267-278 at 6504a3af. -/
theorem fillTxs_map (l : List Tx) (f : Tx → Option Tx) (hf : ∀ u, f u = some u ∨ f u = none)
    (ms : List Tx) : fillTxs (l.map f) (l.filter (fun u => (f u).isNone) ++ ms) = some (l, ms) := by
  induction l with
  | nil => simp [fillTxs]
  | cons a l ih =>
    rcases hf a with h | h
    · simp [fillTxs, h, ih]
    · simp [fillTxs, h, ih]

/-- [D] 2026-10-15: THE RECONSTRUCTION THEOREM, the block. Under
`initData_ofBlock`'s premises, `FillBlock` given the block's transactions at
the requested positions, in order (what `blocktxn` carries), yields exactly
the announced block when the reference's `CheckBlock` accepts it, and
otherwise its verdict: FAILED for a failure that may be corruption,
CHECKBLOCK_FAILED for any other. Premises in plain words: those of
`initData_ofBlock` (which gives `p`), and a non-null header.
[SRC] src/blockencodings.cpp:254-316 at 6504a3af. A view, never a rule. -/
theorem fillBlock_ofBlock (params : ChainParams) (cfg : NodeConfig) (height : Nat) (B : Block)
    (cb : Tx) (rest : List Tx) (hB : B.transactions = cb :: rest) (pool extra : List Tx)
    (hnull : headerIsNull B.header = false) (p : PartialBlock) (hh : p.header = B.header)
    (hp : p.avail = some cb :: rest.map (fun u => if u ∈ pool ∨ u ∈ extra then some u else none)) :
    fillBlock params cfg height p (p.missing.filterMap (fun i => B.transactions[i]?)) =
      match checkBlock params cfg B height with
      | .ok _ => .ok B
      | .error r => .error (if r.corruptionPossible then .failed else .checkBlockFailed) := by
  set f := fun u => if u ∈ pool ∨ u ∈ extra then some u else none with hfdef
  have hf : ∀ u, f u = some u ∨ f u = none := fun u => by
    by_cases h : u ∈ pool ∨ u ∈ extra <;> simp [hfdef, h]
  have hm : p.missing.filterMap (fun i => B.transactions[i]?) = rest.filter (fun u => (f u).isNone) := by
    have := filterMap_emptySlotsFrom [cb] rest f hf
    simpa [PartialBlock.missing, emptySlots, hp, emptySlotsFrom, hB, ← hfdef] using this
  have hfill : fillTxs p.avail (rest.filter (fun u => (f u).isNone)) = some (cb :: rest, []) := by
    have := fillTxs_map rest f hf []
    simp only [List.append_nil] at this
    simp [hp, fillTxs, ← hfdef, this]
  have hblock : (⟨p.header, cb :: rest⟩ : Block) = B := by
    cases B; simp_all
  rw [hm]
  simp only [fillBlock, hh, hnull, Bool.false_eq_true, ite_false, hfill, List.isEmpty_nil,
    bind, Except.bind, pure, Except.pure]
  rw [← hh, hblock]
  rfl

/-- [D] 2026-10-15: THE RECONSTRUCTION THEOREM (#79), whole. For the message
a sender builds from a block and a receiver holding distinct pool
transactions, with no short id shared by two different candidate and block
transactions: reconstruction names exactly the missing set (the positions of
the block's transactions the receiver lacks, and nothing else, in
increasing order), and with the block's transactions at those positions
yields exactly the announced block, or the reference's `CheckBlock` verdict
on it. Premises in plain words: a non-null header and coinbase, a count the block size allows, the
bucket bound not exceeded (`crowded` false, its default: the C++ table's
bucket of more than 12 short ids, src/blockencodings.cpp:157-160, fails the
message whatever the ids), the no-collision condition.
[SRC] src/blockencodings.cpp:18-32,84-316 at 6504a3af; BIP152 lines
100-104,128,141. A view, never a rule. -/
theorem compact_reconstruction (params : ChainParams) (cfg : NodeConfig) (height : Nat) (B : Block)
    (cb : Tx) (rest : List Tx) (hB : B.transactions = cb :: rest)
    (nonce maxBlockSize : Nat) (pool extra : List Tx)
    (hnull : headerIsNull B.header = false) (hcb : txIsNull cb = false)
    (hsize : rest.length + 1 ≤ maxBlockSize / minTxSize)
    (hids : (rest.map (fun t => shortIdOf (shortIdKeys B.header nonce) (txid t))).Nodup)
    (hpool : pool.Nodup)
    (hcoll : ∀ t, t ∈ pool ∨ t ∈ extra → ∀ u ∈ rest,
      shortIdOf (shortIdKeys B.header nonce) (txid t) =
        shortIdOf (shortIdKeys B.header nonce) (txid u) → t = u) :
    ∃ p, initData maxBlockSize (CompactBlock.ofBlock B nonce) pool extra = .ok p ∧
      p.header = B.header ∧
      (∀ j, j ∈ p.missing ↔ ∃ u, B.transactions[j]? = some u ∧ j ≠ 0 ∧ ¬ (u ∈ pool ∨ u ∈ extra)) ∧
      (B.transactions.length ≤ 0xffffffff → IncreasingFrom 0 p.missing) ∧
      fillBlock params cfg height p (p.missing.filterMap (fun i => B.transactions[i]?)) =
        match checkBlock params cfg B height with
        | .ok _ => .ok B
        | .error r => .error (if r.corruptionPossible then .failed else .checkBlockFailed) := by
  refine ⟨{ header := B.header,
             avail := some cb :: rest.map (fun u => if u ∈ pool ∨ u ∈ extra then some u else none) },
    initData_ofBlock B cb rest hB nonce maxBlockSize pool extra hnull hcb hsize hids hpool hcoll,
    rfl, ?_⟩
  have hm := missing_ofBlock B cb rest hB pool extra
    { header := B.header,
      avail := some cb :: rest.map (fun u => if u ∈ pool ∨ u ∈ extra then some u else none) } rfl
  exact ⟨hm.1, hm.2, fillBlock_ofBlock params cfg height B cb rest hB pool extra hnull _ rfl rfl⟩

/-! ## 4. The collision cases, as the source handles them -/

/-- [D] 2026-10-15: two equal short ids in the message fail it: `InitData`
is FAILED ("Short ID collision", src/blockencodings.cpp:163-169 at
6504a3af), and the receiver asks for the whole block with no score
(`answerOf`, src/net/net_processing.cpp:3911-3917; BIP152 line 142). A
view, never a rule. -/
theorem initData_ofBlock_duplicate (B : Block) (cb : Tx) (rest : List Tx)
    (hB : B.transactions = cb :: rest) (nonce maxBlockSize : Nat) (pool extra : List Tx)
    (hnull : headerIsNull B.header = false) (hcb : txIsNull cb = false)
    (hsize : rest.length + 1 ≤ maxBlockSize / minTxSize)
    (hdup : ¬ (rest.map (fun t => shortIdOf (shortIdKeys B.header nonce) (txid t))).Nodup) :
    initData maxBlockSize (CompactBlock.ofBlock B nonce) pool extra = .error .failed ∧
      answerOf (initData maxBlockSize (CompactBlock.ofBlock B nonce) pool extra) = .getBlock := by
  have hc : CompactBlock.ofBlock B nonce =
      { header := B.header, nonce,
        shortIds := rest.map (fun t => shortIdOf (shortIdKeys B.header nonce) (txid t)),
        prefilled := [⟨0, cb⟩] } := by
    simp [CompactBlock.ofBlock, hB]
  have hdec : decide (rest.map (fun t => shortIdOf (shortIdKeys B.header nonce) (txid t))).Nodup =
      false := decide_eq_false hdup
  have hsz : ¬ rest.length + 1 > maxBlockSize / minTxSize := by omega
  have hp1 : ¬ (0 : Nat) > 0xffffffff := by omega
  have hp2 : ¬ (0 : Nat) > rest.length := by omega
  have h : initData maxBlockSize (CompactBlock.ofBlock B nonce) pool extra = .error .failed := by
    rw [hc]
    simp only [initData, CompactBlock.txCount, List.length_map, List.length_singleton, hnull,
      Bool.false_or, List.isEmpty_cons, Bool.and_false, Bool.false_eq_true, ite_false, hsz,
      bind, Except.bind, pure, Except.pure, placePrefilled, hcb, Nat.add_zero, hp1, hp2,
      List.replicate_succ, List.set_cons_zero, hdec, Bool.not_false, ite_true]
    rfl
  exact ⟨h, by rw [h]; rfl⟩

/-- [D] 2026-10-15: a witness of two pool transactions on one short id (a
toy short-id function, every transaction mapping to 7, a message of two
short ids): the position both match is emptied and stays matched, so it is
asked for with `getblocktxn` ("just request it",
src/blockencodings.cpp:181-190 at 6504a3af). A view, never a rule. -/
theorem double_match_requested (cb t1 t2 : Tx) :
    let s := Scan.run (Scan.poolStep (fun _ => 7) [(7, 1), (8, 2)]) 2
      ⟨[some cb, none, none], [false, false, false], 0⟩ [t1, t2]
    s.avail.map Option.isSome = [true, false, false] ∧ s.seen = [false, true, false] ∧ s.count = 0 := by
  intro s
  exact ⟨rfl, rfl, rfl⟩

/-- [D] 2026-10-15: a witness of the early exit's risk (the toy short-id
function again, one short id): the scan stops at the count, so a pool
transaction that shares the short id with the block's (here `t1`, met
before the block's own `t2`) is placed and the collision is never seen
(src/blockencodings.cpp:192-197 at 6504a3af: "worth the extra risk"). Only
`FillBlock`'s `CheckBlock` then stands between it and the block:
`fillBlock_ok_checked`. A view, never a rule. -/
theorem early_exit_places_first (cb t1 t2 : Tx) :
    (Scan.run (Scan.poolStep (fun _ => 7) [(7, 1)]) 1
      ⟨[some cb, none], [false, false], 0⟩ [t1, t2]).avail.map (Option.map txid) =
      [some (txid cb), some (txid t1)] := by
  rfl

/-- [D] 2026-10-15: whatever the pool and the collisions, a block
`FillBlock` returns has the announced header and passes the reference's
`CheckBlock`: a body whose merkle root differs from the header's, or whose
tree is mutated, is refused there with the corruption mark, so FAILED, and
the receiver asks for the whole block (src/blockencodings.cpp:288-299,
src/validation.cpp:5749-5785 at 6504a3af). A view, never a rule. -/
theorem fillBlock_ok_checked (params : ChainParams) (cfg : NodeConfig) (height : Nat)
    (p : PartialBlock) (v : List Tx) (b : Block)
    (h : fillBlock params cfg height p v = .ok b) :
    b.header = p.header ∧ checkBlock params cfg b height = .ok () := by
  unfold fillBlock at h
  by_cases hn : headerIsNull p.header = true
  · simp [hn] at h; cases h
  · simp only [hn, Bool.false_eq_true, ite_false] at h
    cases hf : fillTxs p.avail v with
    | none => simp [hf] at h
    | some r =>
      obtain ⟨txs, left⟩ := r
      cases hl : left.isEmpty with
      | false => simp [hf, hl] at h; cases h
      | true =>
        cases hc : checkBlock params cfg ⟨p.header, txs⟩ height with
        | error e => simp [hf, hl, hc] at h
        | ok u =>
          simp [hf, hl, hc] at h
          cases h
          exact ⟨rfl, by cases u; exact hc⟩

end Reconstruction

end BsvChain.Wire
