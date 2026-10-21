import BsvChain.Views.Wire.Bytes

/-!
# The BSV Unified Merkle Path (BUMP, BRC-74) as a view (#86)

[M] 2026-10-15 (#86). [LIT] BRC-74 "BSV Unified Merkle Path (BUMP)
Format", bsv-blockchain/BRCs at 5333fd449c70fd5982029876376dcf1ed9c64ffe,
`transactions/0074.md` (read 2026-10-15T03:25:54Z from
https://raw.githubusercontent.com/bsv-blockchain/BRCs/5333fd449c70fd5982029876376dcf1ed9c64ffe/transactions/0074.md,
18597 bytes, sha256 `0cd56c0f9e6b31a2500899b1791abcf15b216cb4aeb7576608b3cc19942d6aad`).
Views, never rules: a BUMP is a client encoding of one or more merkle paths
of #65 in one block; its verification is `verifyPath` of #65 through the
node list of #75 (`markerPath`, `tscPath`).

The layout (0074.md:45-77): the block height (VarInt, :50), the tree height
(1 byte, "max 64", :51), then per level the leaf count (VarInt, :58) and the
leaves; a leaf is the offset (VarInt, :66), the flags byte (:67) and a
32-byte hash unless the flags say duplicate (:68). The flags table (:73-77):
`00` data follows, not a client txid; `01` nothing follows, duplicate the
working hash; `02` data follows, a client txid. This codec reads exactly the
three values of the table and refuses every other flags byte; the reference
JavaScript of the BRC (:289-296) and the three engines read the flags as bits
(`flags & 1` duplicate, else `flags & 2` client), so `04` and above are read
by them and refused here (the conformance record's `bump-028`); `03`, the
duplicate bit with the client bit, they read as a duplicate (`bump-027`).
A tree height above 64 is refused (:51). Hashes are internal-order words; the
JSON form (:158-261) and the hex display order are the reversed words.

**The projection.** A path for the leaf at offset `index` takes, at each level
`h` below the tree height, the leaf at the sibling offset of `index / 2^h`
(:326-345, `calculateMerkleRootFromBUMP`); a duplicate is the marker of #75.
A leaf the BUMP omits is computed from the level below when both children are
present (the engines' reading: @bsv/sdk 3.0.0 `MerklePath.ts:421` (`findOrComputeLeaf`),
the text "only include branches of the tree which are required", :15); the
BRC's reference function throws instead (:335). A one-level BUMP of one leaf is
the lone transaction of its block, whose root is the leaf itself (@bsv/sdk
3.0.0 `MerklePath.ts:390` ("special case for blocks with only one
transaction"); ts-stack 4d0ea63c, identical at edf6e03d); #75 records that the
node serves no proof for that case.
-/

namespace BsvChain.Views.Wire
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash BsvScript.Sighash BsvChain.Properties BsvChain.Views

/-- [LIT] 2026-10-15: a leaf's content by its flags byte (0074.md:73-77). -/
inductive BumpNode where
  | hash (w : Bytes)
  | duplicate
  | txid (w : Bytes)
  deriving DecidableEq, Repr

/-- [LIT] 2026-10-15: a leaf: its offset from the left of its level and its content. -/
structure BumpLeaf where
  offset : Nat
  node : BumpNode
  deriving DecidableEq, Repr

/-- [LIT] 2026-10-15: a BUMP: the block height and the levels from the leaves
upward; the tree height is the number of levels (0074.md:48-59). -/
structure Bump where
  blockHeight : Nat
  levels : List (List BumpLeaf)
  deriving DecidableEq, Repr

/-- [LIT] 2026-10-15: the tree height's bound, "max 64" (0074.md:51). -/
def bumpMaxTreeHeight : Nat := 64

/-- [LIT] 2026-10-15: the flags byte of a leaf (0074.md:73-77). -/
def BumpNode.flags : BumpNode → Nat
  | .hash _ => 0
  | .duplicate => 1
  | .txid _ => 2

/-- [LIT] 2026-10-15: a leaf's bytes: offset, flags, the hash unless duplicate. -/
def encodeBumpLeaf (l : BumpLeaf) : Bytes :=
  compactSize l.offset ++ match l.node with
    | .hash w => 0 :: w
    | .duplicate => [1]
    | .txid w => 2 :: w

/-- [LIT] 2026-10-15: a level's bytes: the leaf count, the leaves. -/
def encodeBumpLevel (lv : List BumpLeaf) : Bytes :=
  compactSize lv.length ++ (lv.map encodeBumpLeaf).flatten

/-- [LIT] 2026-10-15: the BUMP bytes: block height, tree height, the levels. -/
def Bump.encode (b : Bump) : Bytes :=
  compactSize b.blockHeight ++ (b.levels.length :: (b.levels.map encodeBumpLevel).flatten)

/-- [LIT] 2026-10-15: read one leaf; a flags byte outside the table is refused. -/
def readBumpLeaf (bs : Bytes) : Option (BumpLeaf × Bytes) := do
  let (offset, r1) ← readVarInt bs
  let (flag, r2) ← readByte r1
  if flag = 0 then
    let (w, r3) ← readBytes 32 r2
    pure ({ offset, node := .hash w }, r3)
  else if flag = 1 then
    pure ({ offset, node := .duplicate }, r2)
  else if flag = 2 then
    let (w, r3) ← readBytes 32 r2
    pure ({ offset, node := .txid w }, r3)
  else none

/-- [LIT] 2026-10-15: read one level: the count, then the leaves. -/
def readBumpLevel (bs : Bytes) : Option (List BumpLeaf × Bytes) := do
  let (n, r1) ← readVarInt bs
  readMany readBumpLeaf n r1

/-- [LIT] 2026-10-15: read a BUMP from the front of a byte string; a tree height
above 64 is refused. -/
def Bump.decodePrefix (bs : Bytes) : Option (Bump × Bytes) := do
  let (blockHeight, r1) ← readVarInt bs
  let (treeHeight, r2) ← readByte r1
  if treeHeight > bumpMaxTreeHeight then none else
  let (levels, r3) ← readMany readBumpLevel treeHeight r2
  pure ({ blockHeight, levels }, r3)

/-- [LIT] 2026-10-15: exactly one BUMP, trailing bytes refused. -/
def Bump.decode (bs : Bytes) : Option Bump :=
  match Bump.decodePrefix bs with
  | some (b, []) => some b
  | _ => none

/-! ## Well-formedness and the round trips -/

/-- [D] 2026-10-15: a leaf whose offset fits CompactSize and whose word is 32 bytes. -/
def BumpLeafWellFormed (l : BumpLeaf) : Prop :=
  l.offset < 2 ^ 64 ∧ match l.node with
    | .hash w => w.length = 32
    | .duplicate => True
    | .txid w => w.length = 32

/-- [D] 2026-10-15: a well-formed level. -/
def BumpLevelWellFormed (lv : List BumpLeaf) : Prop :=
  lv.length < 2 ^ 64 ∧ ∀ l ∈ lv, BumpLeafWellFormed l

/-- [D] 2026-10-15: a well-formed BUMP: a CompactSize block height, at most 64
levels, well-formed levels. -/
def BumpWellFormed (b : Bump) : Prop :=
  b.blockHeight < 2 ^ 64 ∧ b.levels.length ≤ bumpMaxTreeHeight ∧ ∀ lv ∈ b.levels, BumpLevelWellFormed lv

/-- [D] 2026-10-15: a well-formed leaf reads back from its bytes. -/
theorem readBumpLeaf_encode (l : BumpLeaf) (rest : Bytes) (wf : BumpLeafWellFormed l) :
    readBumpLeaf (encodeBumpLeaf l ++ rest) = some (l, rest) := by
  obtain ⟨offset, node⟩ := l
  obtain ⟨ho, hn⟩ := wf
  cases node with
  | hash w =>
    have h := readBytes_append w rest
    rw [show w.length = 32 from hn] at h
    simp [encodeBumpLeaf, readBumpLeaf, List.append_assoc, readVarInt_compactSize _ _ ho, readByte, h]
  | duplicate =>
    simp [encodeBumpLeaf, readBumpLeaf, List.append_assoc, readVarInt_compactSize _ _ ho, readByte]
  | txid w =>
    have h := readBytes_append w rest
    rw [show w.length = 32 from hn] at h
    simp [encodeBumpLeaf, readBumpLeaf, List.append_assoc, readVarInt_compactSize _ _ ho, readByte, h]

/-- [D] 2026-10-15: a well-formed level reads back from its bytes. -/
theorem readBumpLevel_encode (lv : List BumpLeaf) (rest : Bytes) (wf : BumpLevelWellFormed lv) :
    readBumpLevel (encodeBumpLevel lv ++ rest) = some (lv, rest) := by
  obtain ⟨hl, hx⟩ := wf
  simp only [readBumpLevel, encodeBumpLevel, List.append_assoc, bind, Option.bind,
    readVarInt_compactSize _ _ hl,
    readMany_ser readBumpLeaf encodeBumpLeaf BumpLeafWellFormed (fun x r h => readBumpLeaf_encode x r h) lv hx]

/-- [M] 2026-10-15, #86 (BUMP, parse after serialize). For every well-formed
BUMP the decoder reads the encoder's bytes back exactly and leaves any
following stream untouched. Premise: `wf` (CompactSize fields, at most 64
levels, 32-byte words). [LIT] BRC-74 at 5333fd4, 0074.md:45-77. -/
theorem bump_decodePrefix_encode (b : Bump) (rest : Bytes) (wf : BumpWellFormed b) :
    Bump.decodePrefix (b.encode ++ rest) = some (b, rest) := by
  obtain ⟨hh, ht, hl⟩ := wf
  have hlev := readMany_ser readBumpLevel encodeBumpLevel BumpLevelWellFormed
    (fun x r h => readBumpLevel_encode x r h) b.levels hl rest
  simp only [Bump.encode, Bump.decodePrefix, List.append_assoc, List.cons_append, bind, Option.bind,
    readVarInt_compactSize _ _ hh, readByte, show ¬ b.levels.length > bumpMaxTreeHeight by omega, if_false,
    hlev, pure]

/-- [D] 2026-10-15: a leaf read from byte-valued bytes writes back. -/
theorem encodeBumpLeaf_read (bs : Bytes) (l : BumpLeaf) (r : Bytes) (hb : ByteValued bs)
    (h : readBumpLeaf bs = some (l, r)) : encodeBumpLeaf l ++ r = bs := by
  simp only [readBumpLeaf, bind, Option.bind] at h
  split at h; · cases h
  rename_i p1 h1; obtain ⟨offset, r1⟩ := p1; try dsimp only at h
  split at h; · cases h
  rename_i p2 h2; obtain ⟨flag, r2⟩ := p2; try dsimp only at h
  obtain ⟨e1, _⟩ := readVarInt_inv hb h1
  have e2 := readByte_inv h2
  split at h
  · rename_i hf
    split at h; · cases h
    rename_i p3 h3; obtain ⟨w, r3⟩ := p3; try dsimp only at h
    simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl⟩ := h
    obtain ⟨e3, _⟩ := readBytes_inv h3
    simp only [encodeBumpLeaf, List.append_assoc, List.cons_append, e3, ← hf, e2, e1]
  · split at h
    · rename_i _ hf
      simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
      obtain ⟨rfl, rfl⟩ := h
      simp only [encodeBumpLeaf, List.append_assoc, List.cons_append, List.nil_append, ← hf, e2, e1]
    · split at h
      · rename_i _ _ hf
        split at h; · cases h
        rename_i p3 h3; obtain ⟨w, r3⟩ := p3; try dsimp only at h
        simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl⟩ := h
        obtain ⟨e3, _⟩ := readBytes_inv h3
        simp only [encodeBumpLeaf, List.append_assoc, List.cons_append, e3, ← hf, e2, e1]
      · cases h

/-- [D] 2026-10-15: a level read from byte-valued bytes writes back. -/
theorem encodeBumpLevel_read (bs : Bytes) (lv : List BumpLeaf) (r : Bytes) (hb : ByteValued bs)
    (h : readBumpLevel bs = some (lv, r)) : encodeBumpLevel lv ++ r = bs := by
  simp only [readBumpLevel, bind, Option.bind] at h
  split at h; · cases h
  rename_i p1 h1; obtain ⟨n, r1⟩ := p1; try dsimp only at h
  obtain ⟨e1, _⟩ := readVarInt_inv hb h1
  have b1 : ByteValued r1 := (byteValued_append.mp (e1 ▸ hb)).2
  obtain ⟨e2, hl⟩ := readMany_inv readBumpLeaf encodeBumpLeaf
    (fun bs x r hb h => encodeBumpLeaf_read bs x r hb h) _ _ _ _ b1 h
  simp only [encodeBumpLevel, List.append_assoc, hl, e2, e1]

/-- [M] 2026-10-15, #86 (BUMP, serialize after parse). A BUMP read from the
front of byte-valued bytes encodes back to exactly the bytes read: one BUMP
value has one encoding, leaf order included (no engine-side sorting is part
of the format). Premise: the input is byte-valued. [LIT] BRC-74 at 5333fd4. -/
theorem bump_encode_decodePrefix (bs : Bytes) (b : Bump) (r : Bytes) (hb : ByteValued bs)
    (h : Bump.decodePrefix bs = some (b, r)) : b.encode ++ r = bs := by
  simp only [Bump.decodePrefix, bind, Option.bind] at h
  split at h; · cases h
  rename_i p1 h1; obtain ⟨blockHeight, r1⟩ := p1; try dsimp only at h
  split at h; · cases h
  rename_i p2 h2; obtain ⟨treeHeight, r2⟩ := p2; try dsimp only at h
  split at h; · cases h
  split at h; · cases h
  rename_i p3 h3; obtain ⟨levels, r3⟩ := p3; try dsimp only at h
  simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
  obtain ⟨rfl, rfl⟩ := h
  obtain ⟨e1, _⟩ := readVarInt_inv hb h1
  have b1 : ByteValued r1 := (byteValued_append.mp (e1 ▸ hb)).2
  have e2 := readByte_inv h2
  have b2 : ByteValued r2 := (byteValued_cons (e2 ▸ b1)).2
  obtain ⟨e3, hl⟩ := readMany_inv readBumpLevel encodeBumpLevel
    (fun bs x r hb h => encodeBumpLevel_read bs x r hb h) _ _ _ _ b2 h3
  simp only [Bump.encode, List.append_assoc, List.cons_append, hl, e3, e2, e1]

/-- [M] 2026-10-15, #86: the exact BUMP decoder and the encoder are inverse. -/
theorem bump_decode_encode (b : Bump) (wf : BumpWellFormed b) : Bump.decode b.encode = some b := by
  have h := bump_decodePrefix_encode b [] wf
  rw [List.append_nil] at h
  simp [Bump.decode, h]

/-- [M] 2026-10-15, #86: the exact BUMP decoder's accepted bytes are the encoding
of what it reads, leaf order included. Premise: the input is byte-valued. -/
theorem bump_encode_decode (bs : Bytes) (b : Bump) (hb : ByteValued bs) (h : Bump.decode bs = some b) :
    b.encode = bs := by
  unfold Bump.decode at h
  split at h
  · rename_i b' hp
    simp only [Option.some.injEq] at h
    subst h
    simpa using bump_encode_decodePrefix bs b' [] hb hp
  · cases h

/-! ## The function to #65's merkle paths -/

/-- [LIT] 2026-10-15: the word a leaf carries, none for a duplicate. -/
def BumpNode.word? : BumpNode → Option Bytes
  | .hash w => some w
  | .duplicate => none
  | .txid w => some w

/-- [D] 2026-10-15: a BUMP node as a node of #75's list: a word, or the marker. -/
def BumpNode.toTsc : BumpNode → TscNode
  | .hash w => .hash w
  | .duplicate => .duplicate
  | .txid w => .hash w

/-- [D] 2026-10-15: a #75 node as a BUMP node (not a client txid). -/
def BumpNode.ofTsc : TscNode → BumpNode
  | .hash w => .hash w
  | .duplicate => .duplicate

/-- [LIT] 2026-10-15: the sibling offset, `offset ^ 1` (0074.md:333). -/
def sibOffset (k : Nat) : Nat := if k % 2 = 0 then k + 1 else k - 1

/-- [LIT] 2026-10-15: the leaf a level lists at an offset (0074.md:334). -/
def Bump.findLeaf (b : Bump) (h offset : Nat) : Option BumpNode :=
  (((b.levels[h]?).getD []).find? (fun l => l.offset == offset)).map (·.node)

/-- [D] 2026-10-15: the node at a level and offset: listed, or computed from
the two children below when the left is a word and the right a word or the
duplicate marker. [SRC] @bsv/sdk 3.0.0 `src/transaction/MerklePath.ts:421`
(`findOrComputeLeaf`; ts-stack 4d0ea63c, identical at edf6e03d). -/
def Bump.nodeAt (b : Bump) : Nat → Nat → Option BumpNode
  | 0, offset => b.findLeaf 0 offset
  | h + 1, offset =>
    match b.findLeaf (h + 1) offset with
    | some n => some n
    | none =>
      match (b.nodeAt h (2 * offset)).bind BumpNode.word?, b.nodeAt h (2 * offset + 1) with
      | some lw, some right =>
        match right.word? with
        | some rw => some (.hash (sha256d (lw ++ rw)))
        | none => some (.hash (sha256d (lw ++ lw)))
      | _, _ => none

/-- [D] 2026-10-15: the node list from level `h` for `count` levels. -/
def Bump.pathFrom (b : Bump) (index : Nat) : Nat → Nat → Option (List TscNode)
  | _, 0 => some []
  | h, count + 1 => do
    let n ← b.nodeAt h (sibOffset (index / 2 ^ h))
    let rest ← b.pathFrom index (h + 1) count
    pure (n.toTsc :: rest)

/-- [D] 2026-10-15: the path of #75's nodes for the leaf at `index`, one node per
level; a lone leaf in a one-level BUMP has the empty path. -/
def Bump.pathFor (b : Bump) (index : Nat) : Option (List TscNode) :=
  match b.levels with
  | [[_]] => some []
  | _ => b.pathFrom index 0 b.levels.length

/-- [LIT] 2026-10-15: BRC-74's root calculation (0074.md:326-345,
`calculateMerkleRootFromBUMP`): a duplicate hashes the working hash with
itself; a word is hashed with the working hash in the order the offset gives,
literally. #65's `computeRootFromBranch` (the node's `ComputeMerkleRootFromBranch`)
also reads an all-zero word as the duplicate marker; `bumpFold_eq` proves the
two agree on every node list without a zero word. -/
def bumpFold : Bytes → List TscNode → Nat → Bytes
  | leaf, [], _ => leaf
  | leaf, .hash w :: rest, index =>
    bumpFold (sha256d (if index % 2 = 1 then w ++ leaf else leaf ++ w)) rest (index / 2)
  | leaf, .duplicate :: rest, index => bumpFold (sha256d (leaf ++ leaf)) rest (index / 2)

/-- [M] 2026-10-15, #86 (BRC-74's root and #65's). On a node list with no
all-zero hash word, BRC-74's literal root and #65's `computeRootFromBranch`
over the marker path are the same function of the leaf and the index. Premise:
no hash node is the zero word (an all-zero SHA256d output); with one, the node's
reading takes it as the marker and BRC-74 hashes it (the conformance record's
witness of the zero word). [SRC] src/consensus/merkle.cpp:291-310 at 6504a3af. -/
theorem bumpFold_eq (leaf : Bytes) (nodes : List TscNode) (index : Nat)
    (h : ∀ w, TscNode.hash w ∈ nodes → w ≠ zero32) :
    bumpFold leaf nodes index = computeRootFromBranch leaf (markerPath nodes) index := by
  induction nodes generalizing leaf index with
  | nil => rfl
  | cons n rest ih =>
    have hr : ∀ w, TscNode.hash w ∈ rest → w ≠ zero32 := fun w hw => h w (List.mem_cons_of_mem _ hw)
    cases n with
    | hash w =>
      have hw : (w == zero32) = false := by simpa using h w (List.mem_cons_self ..)
      simp only [bumpFold, markerPath, computeRootFromBranch, branchPair, hw]
      by_cases hi : index % 2 = 1
      · simp only [hi, if_true, beq_self_eq_true]
        exact ih _ _ hr
      · simp only [hi, if_false, show (index % 2 == 1) = false by simpa using hi]
        exact ih _ _ hr
    | duplicate =>
      simp only [bumpFold, markerPath, computeRootFromBranch, branchPair_zero]
      exact ih _ _ hr

/-- [LIT] 2026-10-15: the root a leaf word computes at `index`: BRC-74's
calculation over the leaf's path (`bumpFold`). -/
def Bump.rootFor (b : Bump) (leaf : Bytes) (index : Nat) : Option Bytes :=
  (b.pathFor index).map fun nodes => bumpFold leaf nodes index

/-- [LIT] 2026-10-15: the client txids of a BUMP with their offsets: the level-0
leaves flagged `02` (0074.md:77). -/
def Bump.clientTxids (b : Bump) : List (Nat × Bytes) :=
  ((b.levels.head?).getD []).filterMap fun l =>
    match l.node with
    | .txid w => some (l.offset, w)
    | _ => none

/-- [LIT] 2026-10-15: the offset of a word among the level-0 leaves (BRC-62's
validation step "Lookup the txid within level 0 leaves", 0062.md:179). -/
def Bump.indexOf (b : Bump) (w : Bytes) : Option Nat :=
  (((b.levels.head?).getD []).find? fun l => l.node.word? == some w).map (·.offset)

/-- [D] 2026-10-15: the roots every level-0 word computes, in level order;
`none` when one of them has no path. -/
def Bump.leafRoots (b : Bump) : Option (List Bytes) :=
  ((b.levels.head?).getD []).filterMap (fun l => l.node.word?.map fun w => (l.offset, w))
    |>.mapM fun (o, w) => b.rootFor w o

/-- [D] 2026-10-15: the BUMP's root: the common root of every level-0 word,
`none` when a word has no path, when the roots differ, or when there is no word.
This is the check the engines run on construction (the conformance record). -/
def Bump.root (b : Bump) : Option Bytes :=
  match b.leafRoots with
  | some (r :: rs) => if rs.all (· == r) then some r else none
  | _ => none

/-! ## A #75 proof as a BUMP -/

/-- [D] 2026-10-15: the single-path BUMP of a leaf, its index and #75's node
list: level 0 holds the leaf (a client txid) and its sibling in offset order,
each level above holds the sibling node of that level. -/
def Bump.ofTsc (height : Nat) (leaf : Bytes) (index : Nat) : List TscNode → Bump
  | [] => { blockHeight := height, levels := [[{ offset := index, node := .txid leaf }]] }
  | n0 :: rest =>
    let t : BumpLeaf := { offset := index, node := .txid leaf }
    let s : BumpLeaf := { offset := sibOffset index, node := BumpNode.ofTsc n0 }
    { blockHeight := height,
      levels := (if index % 2 = 0 then [t, s] else [s, t]) ::
        (rest.zipIdx.map fun (n, k) => [{ offset := sibOffset (index / 2 ^ (k + 1)), node := BumpNode.ofTsc n }]) }

/-- [D] 2026-10-15: a #75 node survives the BUMP node and back. -/
theorem toTsc_ofTsc (n : TscNode) : (BumpNode.ofTsc n).toTsc = n := by
  cases n <;> rfl

/-- [D] 2026-10-15: no offset is its own sibling. -/
theorem sibOffset_ne (k : Nat) : (k == sibOffset k) = false := by
  unfold sibOffset
  split <;> simp <;> omega

/-- [D] 2026-10-15: the levels above level 0 of `ofTsc` list the sibling node. -/
theorem pathFrom_upper (b : Bump) (index : Nat) (rest : List TscNode) :
    ∀ (k : Nat), (∀ j (hj : j < rest.length),
        b.levels[j + k + 1]? = some [{ offset := sibOffset (index / 2 ^ (j + k + 1)), node := BumpNode.ofTsc rest[j] }]) →
      b.pathFrom index (k + 1) rest.length = some rest := by
  induction rest with
  | nil => intro k _; rfl
  | cons n rest ih =>
    intro k hl
    have h0 := hl 0 (by simp)
    simp only [Nat.zero_add, List.getElem_cons_zero] at h0
    have hnode : b.nodeAt (k + 1) (sibOffset (index / 2 ^ (k + 1))) = some (BumpNode.ofTsc n) := by
      simp [Bump.nodeAt, Bump.findLeaf, h0]
    have hrest : b.pathFrom index (k + 1 + 1) rest.length = some rest := by
      apply ih (k + 1)
      intro j hj
      have := hl (j + 1) (by simp; omega)
      simpa [Nat.add_assoc, Nat.add_comm 1 k, Nat.add_left_comm] using this
    simp only [List.length_cons, Bump.pathFrom, bind, Option.bind, hnode, hrest, toTsc_ofTsc, pure]

/-- [M] 2026-10-15, #86 (BUMP and #75). The single-path BUMP built from a leaf,
its index and a node list returns exactly that node list as the leaf's path;
so its root for the leaf is the root #75's proof computes, and #65's
`verifyPath` decides both alike. No premise: every node list and index. -/
theorem pathFor_ofTsc (height : Nat) (leaf : Bytes) (index : Nat) (nodes : List TscNode) :
    (Bump.ofTsc height leaf index nodes).pathFor index = some nodes := by
  cases nodes with
  | nil => rfl
  | cons n0 rest =>
    set b := Bump.ofTsc height leaf index (n0 :: rest) with hb
    have hlev : b.levels = (if index % 2 = 0 then
        [{ offset := index, node := .txid leaf }, { offset := sibOffset index, node := BumpNode.ofTsc n0 }]
        else [{ offset := sibOffset index, node := BumpNode.ofTsc n0 }, { offset := index, node := .txid leaf }]) ::
        (rest.zipIdx.map fun (n, k) => [{ offset := sibOffset (index / 2 ^ (k + 1)), node := BumpNode.ofTsc n }]) := rfl
    have hlen : b.levels.length = rest.length + 1 := by simp [hlev]
    have h0 : b.nodeAt 0 (sibOffset (index / 2 ^ 0)) = some (BumpNode.ofTsc n0) := by
      simp only [Nat.pow_zero, Nat.div_one, Bump.nodeAt, Bump.findLeaf, hlev]
      split <;> simp [sibOffset_ne, beq_self_eq_true]
    have hup : b.pathFrom index (0 + 1) rest.length = some rest := by
      apply pathFrom_upper b index rest 0
      intro j hj
      simp [hlev, List.getElem?_cons_succ, List.getElem?_map, List.getElem?_zipIdx, hj]
    have hpf : b.pathFor index = b.pathFrom index 0 b.levels.length := by
      unfold Bump.pathFor
      rw [hlev]
      split
      · rename_i heq
        simp only [List.cons.injEq] at heq
        obtain ⟨h1, h2⟩ := heq
        split at h1 <;> simp at h1
      · rfl
    rw [hpf, hlen]
    simp only [Bump.pathFrom, bind, Option.bind, h0, hup, toTsc_ofTsc, pure]

/-- [M] 2026-10-15, #86: the root of a #75 proof's BUMP for its leaf is BRC-74's
root over the proof's nodes, and, when no hash node is the zero word, the root
#65's `computeRootFromBranch` gives over the proof's marker path. Premise of the
second part: no zero hash word (`bumpFold_eq`). -/
theorem rootFor_ofTsc (height : Nat) (leaf : Bytes) (index : Nat) (nodes : List TscNode) :
    (Bump.ofTsc height leaf index nodes).rootFor leaf index = some (bumpFold leaf nodes index) := by
  simp [Bump.rootFor, pathFor_ofTsc]

end BsvChain.Views.Wire
