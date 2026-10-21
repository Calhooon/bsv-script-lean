import BsvChain.Views.Wire.BUMP

/-!
# The Background Evaluation Extended Format (BEEF, BRC-62 and BRC-96) as a view (#86)

[M] 2026-10-15 (#86). [LIT] BRC-62 "Background Evaluation Extended
Format (BEEF) Transactions", bsv-blockchain/BRCs at
5333fd449c70fd5982029876376dcf1ed9c64ffe, `transactions/0062.md` (read
2026-10-15T03:25:54Z from
https://raw.githubusercontent.com/bsv-blockchain/BRCs/5333fd449c70fd5982029876376dcf1ed9c64ffe/transactions/0062.md,
15674 bytes, sha256 `7fdee54fa863a3787143ba86a076e1b790d9d9d0584059aa156214fea828a313`),
and BRC-96 "BEEF V2, Txid Only Extension", `transactions/0096.md` at the same
commit (read 2026-10-15T03:27:47Z from
https://raw.githubusercontent.com/bsv-blockchain/BRCs/5333fd449c70fd5982029876376dcf1ed9c64ffe/transactions/0096.md,
4635 bytes, sha256 `9b4b11fdb28c5ec66332cb3260716f82d61318e9dc376aba730fef903a577283`).
Views, never rules: a BEEF carries transactions with their ancestry and the
merkle paths (BUMPs) of the mined ones; its validation process (0062.md:172-191)
is a client's, and nothing here changes a verdict of the machine.

**Version 1** (0062.md:59-69): the version 4022206465 as 4 little-endian bytes
(`0100BEEF`), the BUMP count (VarInt) and the BUMPs (BRC-74), the transaction
count (VarInt), then per transaction the raw transaction (BRC-12), the
"Has BUMP" byte (`01` or `00`, :68) and, after `01`, the BUMP index (VarInt, :69).
**Version 2** (0096.md:46-61): the version 4022206466 (`0200BEEF`), the same
BUMP section, then per transaction the "Tx Data Format" byte, ahead of the body
(:48-50): `00` a raw transaction without a BUMP index, `01` the BUMP index
(VarInt) then the raw transaction, `02` a 32-byte txid only (:58-61).
This codec reads exactly the byte values the two tables name and refuses
every other; it does not check that a BUMP index is in range (the grammar has
no such field); the view `Beef.objects` does, and returns `none` when a
mined transaction's BUMP is missing or does not list its txid.
-/

namespace BsvChain.Views.Wire
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash BsvScript.Sighash BsvChain.Properties BsvChain.Views

/-- [LIT] 2026-10-15: the two BEEF versions (0062.md:59; 0096.md:46). -/
inductive BeefVersion where
  | v1
  | v2
  deriving DecidableEq, Repr

/-- [LIT] 2026-10-15: the version words: 4022206465 (`0100BEEF`, 0062.md:59,63)
and 4022206466 (`0200BEEF`, 0096.md:46,54). -/
def BeefVersion.word : BeefVersion → Nat
  | .v1 => 4022206465
  | .v2 => 4022206466

/-- [LIT] 2026-10-15: one transaction entry: a raw transaction with an optional
BUMP index, or (version 2 only) a txid alone (0096.md:58-61). -/
inductive BeefEntry where
  | raw (tx : Tx) (bump : Option Nat)
  | txidOnly (w : Bytes)
  deriving Repr

/-- [LIT] 2026-10-15: a BEEF: its version, its BUMPs, its transactions in order. -/
structure Beef where
  version : BeefVersion
  bumps : List Bump
  txs : List BeefEntry
  deriving Repr

/-- [LIT] 2026-10-15: version 1's "Has BUMP" byte and index (0062.md:68-69). -/
def encodeHasBump : Option Nat → Bytes
  | none => [0]
  | some i => 1 :: compactSize i

/-- [LIT] 2026-10-15: one entry's bytes under a version. A txid-only entry has
no version-1 form (the well-formedness below excludes it there). -/
def encodeBeefEntry : BeefVersion → BeefEntry → Bytes
  | .v1, .raw tx bump => serTx tx ++ encodeHasBump bump
  | .v1, .txidOnly _ => []
  | .v2, .raw tx none => 0 :: serTx tx
  | .v2, .raw tx (some i) => 1 :: (compactSize i ++ serTx tx)
  | .v2, .txidOnly w => 2 :: w

/-- [LIT] 2026-10-15: the BEEF bytes. -/
def Beef.encode (b : Beef) : Bytes :=
  le32 b.version.word ++ compactSize b.bumps.length ++ (b.bumps.map Bump.encode).flatten ++
    compactSize b.txs.length ++ (b.txs.map (encodeBeefEntry b.version)).flatten

/-- [LIT] 2026-10-15: read the version word; any other word is refused. -/
def readBeefVersion (bs : Bytes) : Option (BeefVersion × Bytes) := do
  let (v, r) ← readLE 4 bs
  if v = 4022206465 then pure (.v1, r)
  else if v = 4022206466 then pure (.v2, r)
  else none

/-- [LIT] 2026-10-15: read a version-1 entry: the transaction, then `00`, or
`01` and the index; any other byte is refused. -/
def readBeefEntryV1 (bs : Bytes) : Option (BeefEntry × Bytes) := do
  let (tx, r1) ← decodeTxPrefix bs
  let (flag, r2) ← readByte r1
  if flag = 0 then pure (.raw tx none, r2)
  else if flag = 1 then
    let (i, r3) ← readVarInt r2
    pure (.raw tx (some i), r3)
  else none

/-- [LIT] 2026-10-15: read a version-2 entry: the format byte, then its body;
any other format byte is refused. -/
def readBeefEntryV2 (bs : Bytes) : Option (BeefEntry × Bytes) := do
  let (fmt, r1) ← readByte bs
  if fmt = 0 then
    let (tx, r2) ← decodeTxPrefix r1
    pure (.raw tx none, r2)
  else if fmt = 1 then
    let (i, r2) ← readVarInt r1
    let (tx, r3) ← decodeTxPrefix r2
    pure (.raw tx (some i), r3)
  else if fmt = 2 then
    let (w, r2) ← readBytes 32 r1
    pure (.txidOnly w, r2)
  else none

/-- [LIT] 2026-10-15: the entry reader of a version. -/
def readBeefEntry : BeefVersion → Bytes → Option (BeefEntry × Bytes)
  | .v1 => readBeefEntryV1
  | .v2 => readBeefEntryV2

/-- [LIT] 2026-10-15: read a BEEF from the front of a byte string. -/
def Beef.decodePrefix (bs : Bytes) : Option (Beef × Bytes) := do
  let (version, r1) ← readBeefVersion bs
  let (nb, r2) ← readVarInt r1
  let (bumps, r3) ← readMany Bump.decodePrefix nb r2
  let (nt, r4) ← readVarInt r3
  let (txs, r5) ← readMany (readBeefEntry version) nt r4
  pure ({ version, bumps, txs }, r5)

/-- [LIT] 2026-10-15: exactly one BEEF, trailing bytes refused. -/
def Beef.decode (bs : Bytes) : Option Beef :=
  match Beef.decodePrefix bs with
  | some (b, []) => some b
  | _ => none

/-! ## Well-formedness and the round trips -/

/-- [D] 2026-10-15: a well-formed entry under a version: #68's transaction
conditions, a CompactSize index, a 32-byte txid that only version 2 carries. -/
def BeefEntryWellFormed (v : BeefVersion) : BeefEntry → Prop
  | .raw tx bump => TxWellFormed tx ∧ ∀ i, bump = some i → i < 2 ^ 64
  | .txidOnly w => v = .v2 ∧ w.length = 32

/-- [D] 2026-10-15: a well-formed BEEF. -/
def BeefWellFormed (b : Beef) : Prop :=
  b.bumps.length < 2 ^ 64 ∧ (∀ x ∈ b.bumps, BumpWellFormed x) ∧
    b.txs.length < 2 ^ 64 ∧ ∀ e ∈ b.txs, BeefEntryWellFormed b.version e

/-- [D] 2026-10-15: each version word reads back as its version. -/
theorem readBeefVersion_encode (v : BeefVersion) (rest : Bytes) :
    readBeefVersion (le32 v.word ++ rest) = some (v, rest) := by
  cases v <;>
    simp [readBeefVersion, BeefVersion.word, le32_eq, bind, Option.bind,
      readLE_headerWordBytes _ _ _ (by norm_num : (4022206465 : Nat) < 256 ^ 4),
      readLE_headerWordBytes _ _ _ (by norm_num : (4022206466 : Nat) < 256 ^ 4), pure]

/-- [D] 2026-10-15: a well-formed entry reads back under its version. -/
theorem readBeefEntry_encode (v : BeefVersion) (e : BeefEntry) (rest : Bytes)
    (wf : BeefEntryWellFormed v e) : readBeefEntry v (encodeBeefEntry v e ++ rest) = some (e, rest) := by
  cases e with
  | raw tx bump =>
    obtain ⟨wt, wi⟩ := wf
    cases v with
    | v1 =>
      cases bump with
      | none =>
        simp [readBeefEntry, readBeefEntryV1, encodeBeefEntry, encodeHasBump, List.append_assoc,
          bind, Option.bind, decodeTxPrefix_serTx _ _ wt, readByte, pure]
      | some i =>
        simp [readBeefEntry, readBeefEntryV1, encodeBeefEntry, encodeHasBump, List.append_assoc,
          bind, Option.bind, decodeTxPrefix_serTx _ _ wt, readByte, readVarInt_compactSize _ _ (wi i rfl), pure]
    | v2 =>
      cases bump with
      | none =>
        simp [readBeefEntry, readBeefEntryV2, encodeBeefEntry, List.append_assoc,
          bind, Option.bind, decodeTxPrefix_serTx _ _ wt, readByte, pure]
      | some i =>
        simp [readBeefEntry, readBeefEntryV2, encodeBeefEntry, List.append_assoc,
          bind, Option.bind, decodeTxPrefix_serTx _ _ wt, readByte, readVarInt_compactSize _ _ (wi i rfl), pure]
  | txidOnly w =>
    obtain ⟨hv, hl⟩ := wf
    subst hv
    have h := readBytes_append w rest
    rw [show w.length = 32 from hl] at h
    simp [readBeefEntry, readBeefEntryV2, encodeBeefEntry, bind, Option.bind, readByte, h, pure]

/-- [M] 2026-10-15, #86 (BEEF, parse after serialize). For every well-formed
BEEF of either version the decoder reads the encoder's bytes back exactly
and leaves any following stream untouched. Premise: `wf` (CompactSize counts
and indices, well-formed BUMPs and transactions, txid-only entries in version
2 only). [LIT] BRC-62 and BRC-96 at 5333fd4. -/
theorem beef_decodePrefix_encode (b : Beef) (rest : Bytes) (wf : BeefWellFormed b) :
    Beef.decodePrefix (b.encode ++ rest) = some (b, rest) := by
  obtain ⟨hnb, wb, hnt, we⟩ := wf
  have hbumps := readMany_ser Bump.decodePrefix Bump.encode BumpWellFormed
    (fun x r h => bump_decodePrefix_encode x r h) b.bumps wb
  have htxs := readMany_ser (readBeefEntry b.version) (encodeBeefEntry b.version) (BeefEntryWellFormed b.version)
    (fun x r h => readBeefEntry_encode b.version x r h) b.txs we rest
  simp only [Beef.encode, Beef.decodePrefix, List.append_assoc, bind, Option.bind, readBeefVersion_encode,
    readVarInt_compactSize _ _ hnb, hbumps, readVarInt_compactSize _ _ hnt, htxs, pure]

/-- [D] 2026-10-15: the version word read from byte-valued bytes writes back. -/
theorem readBeefVersion_inv (bs : Bytes) (v : BeefVersion) (r : Bytes) (hb : ByteValued bs)
    (h : readBeefVersion bs = some (v, r)) : le32 v.word ++ r = bs := by
  simp only [readBeefVersion, bind, Option.bind] at h
  split at h; · cases h
  rename_i p1 h1; obtain ⟨w, r1⟩ := p1; try dsimp only at h
  obtain ⟨e1, _⟩ := readLE_inv hb h1
  split at h
  · rename_i hw
    simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl⟩ := h
    simp only [BeefVersion.word, le32_eq, ← hw, e1]
  · split at h
    · rename_i _ hw
      simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
      obtain ⟨rfl, rfl⟩ := h
      simp only [BeefVersion.word, le32_eq, ← hw, e1]
    · cases h

/-- [D] 2026-10-15: an entry read from byte-valued bytes writes back under its version. -/
theorem readBeefEntry_inv (v : BeefVersion) (bs : Bytes) (e : BeefEntry) (r : Bytes) (hb : ByteValued bs)
    (h : readBeefEntry v bs = some (e, r)) : encodeBeefEntry v e ++ r = bs := by
  cases v with
  | v1 =>
    simp only [readBeefEntry, readBeefEntryV1, bind, Option.bind] at h
    split at h; · cases h
    rename_i p1 h1; obtain ⟨tx, r1⟩ := p1; try dsimp only at h
    have e1 := serTx_decodeTxPrefix bs tx r1 hb h1
    have b1 : ByteValued r1 := (byteValued_append.mp (e1 ▸ hb)).2
    split at h; · cases h
    rename_i p2 h2; obtain ⟨flag, r2⟩ := p2; try dsimp only at h
    have e2 := readByte_inv h2
    have b2 : ByteValued r2 := (byteValued_cons (e2 ▸ b1)).2
    split at h
    · rename_i hf
      simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
      obtain ⟨rfl, rfl⟩ := h
      simp only [encodeBeefEntry, encodeHasBump, List.append_assoc, List.cons_append, List.nil_append,
        ← hf, e2, e1]
    · split at h
      · rename_i _ hf
        split at h; · cases h
        rename_i p3 h3; obtain ⟨i, r3⟩ := p3; try dsimp only at h
        simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl⟩ := h
        obtain ⟨e3, _⟩ := readVarInt_inv b2 h3
        simp only [encodeBeefEntry, encodeHasBump, List.append_assoc, List.cons_append, e3, ← hf, e2, e1]
      · cases h
  | v2 =>
    simp only [readBeefEntry, readBeefEntryV2, bind, Option.bind] at h
    split at h; · cases h
    rename_i p1 h1; obtain ⟨fmt, r1⟩ := p1; try dsimp only at h
    have e1 := readByte_inv h1
    have b1 : ByteValued r1 := (byteValued_cons (e1 ▸ hb)).2
    split at h
    · rename_i hf
      split at h; · cases h
      rename_i p2 h2; obtain ⟨tx, r2⟩ := p2; try dsimp only at h
      simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
      obtain ⟨rfl, rfl⟩ := h
      have e2 := serTx_decodeTxPrefix r1 tx r2 b1 h2
      simp only [encodeBeefEntry, List.cons_append, e2, ← hf, e1]
    · split at h
      · rename_i _ hf
        split at h; · cases h
        rename_i p2 h2; obtain ⟨i, r2⟩ := p2; try dsimp only at h
        obtain ⟨e2, _⟩ := readVarInt_inv b1 h2
        have b2 : ByteValued r2 := (byteValued_append.mp (e2 ▸ b1)).2
        split at h; · cases h
        rename_i p3 h3; obtain ⟨tx, r3⟩ := p3; try dsimp only at h
        simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl⟩ := h
        have e3 := serTx_decodeTxPrefix r2 tx r3 b2 h3
        simp only [encodeBeefEntry, List.cons_append, List.append_assoc, e3, e2, ← hf, e1]
      · split at h
        · rename_i _ _ hf
          split at h; · cases h
          rename_i p2 h2; obtain ⟨w, r2⟩ := p2; try dsimp only at h
          simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
          obtain ⟨rfl, rfl⟩ := h
          obtain ⟨e2, _⟩ := readBytes_inv h2
          simp only [encodeBeefEntry, List.cons_append, e2, ← hf, e1]
        · cases h

/-- [M] 2026-10-15, #86 (BEEF, serialize after parse). A BEEF read from the
front of byte-valued bytes encodes back to exactly the bytes read: the
entries keep their order, each BUMP its leaf order. Premise: the input is
byte-valued. [LIT] BRC-62 and BRC-96 at 5333fd4. -/
theorem beef_encode_decodePrefix (bs : Bytes) (b : Beef) (r : Bytes) (hb : ByteValued bs)
    (h : Beef.decodePrefix bs = some (b, r)) : b.encode ++ r = bs := by
  simp only [Beef.decodePrefix, bind, Option.bind] at h
  split at h; · cases h
  rename_i p1 h1; obtain ⟨version, r1⟩ := p1; try dsimp only at h
  split at h; · cases h
  rename_i p2 h2; obtain ⟨nb, r2⟩ := p2; try dsimp only at h
  split at h; · cases h
  rename_i p3 h3; obtain ⟨bumps, r3⟩ := p3; try dsimp only at h
  split at h; · cases h
  rename_i p4 h4; obtain ⟨nt, r4⟩ := p4; try dsimp only at h
  split at h; · cases h
  rename_i p5 h5; obtain ⟨txs, r5⟩ := p5; try dsimp only at h
  simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
  obtain ⟨rfl, rfl⟩ := h
  have e1 := readBeefVersion_inv bs version r1 hb h1
  have b1 : ByteValued r1 := (byteValued_append.mp (e1 ▸ hb)).2
  obtain ⟨e2, _⟩ := readVarInt_inv b1 h2
  have b2 : ByteValued r2 := (byteValued_append.mp (e2 ▸ b1)).2
  obtain ⟨e3, l3⟩ := readMany_inv Bump.decodePrefix Bump.encode
    (fun bs x r hb h => bump_encode_decodePrefix bs x r hb h) _ _ _ _ b2 h3
  have b3 : ByteValued r3 := (byteValued_append.mp (e3 ▸ b2)).2
  obtain ⟨e4, _⟩ := readVarInt_inv b3 h4
  have b4 : ByteValued r4 := (byteValued_append.mp (e4 ▸ b3)).2
  obtain ⟨e5, l5⟩ := readMany_inv (readBeefEntry version) (encodeBeefEntry version)
    (fun bs x r hb h => readBeefEntry_inv version bs x r hb h) _ _ _ _ b4 h5
  simp only [Beef.encode, List.append_assoc, l3, l5, e5, e4, e3, e2, e1]

/-- [M] 2026-10-15, #86: the exact BEEF decoder and the encoder are inverse. -/
theorem beef_decode_encode (b : Beef) (wf : BeefWellFormed b) : Beef.decode b.encode = some b := by
  have h := beef_decodePrefix_encode b [] wf
  rw [List.append_nil] at h
  simp [Beef.decode, h]

/-- [M] 2026-10-15, #86: the exact BEEF decoder's accepted bytes are the encoding
of what it reads. Premise: the input is byte-valued. -/
theorem beef_encode_decode (bs : Bytes) (b : Beef) (hb : ByteValued bs) (h : Beef.decode bs = some b) :
    b.encode = bs := by
  unfold Beef.decode at h
  split at h
  · rename_i b' hp
    simp only [Option.some.injEq] at h
    subst h
    simpa using beef_encode_decodePrefix bs b' [] hb hp
  · cases h

/-! ## The function to the machine's objects: a transaction with its ancestry -/

/-- [LIT] 2026-10-15: an entry's txid: the hash of the raw transaction, or the
word a txid-only entry carries (0062.md:176; 0096.md:61). -/
def BeefEntry.txid : BeefEntry → Bytes
  | .raw tx _ => BsvScript.Sighash.txid tx
  | .txidOnly w => w

/-- [D] 2026-10-15: what a BEEF says of one of its transactions: mined, with the
block height and #75's node path at its level-0 offset in its BUMP; unmined
(validated through its parents, 0062.md:183-187); or known by its txid alone
(0096.md:65-67). -/
inductive BeefObject where
  | mined (tx : Tx) (blockHeight : Nat) (index : Nat) (path : List TscNode)
  | unmined (tx : Tx)
  | known (w : Bytes)
  deriving Repr

/-- [D] 2026-10-15: the object of an entry: a BUMP index resolves to that BUMP,
the txid to its level-0 offset (0062.md:179) and the offset to a path; `none`
when the BUMP is missing, does not list the txid, or has no path for it. -/
def Beef.object (b : Beef) : BeefEntry → Option BeefObject
  | .raw tx none => some (.unmined tx)
  | .raw tx (some i) => do
    let bump ← b.bumps[i]?
    let index ← bump.indexOf (BsvScript.Sighash.txid tx)
    let path ← bump.pathFor index
    pure (.mined tx bump.blockHeight index path)
  | .txidOnly w => some (.known w)

/-- [D] 2026-10-15: every entry's txid and object, in BEEF order. -/
def Beef.objects (b : Beef) : Option (List (Bytes × BeefObject)) :=
  b.txs.mapM fun e => (b.object e).map fun o => (e.txid, o)

/-- [D] 2026-10-15: the txids an entry spends from (its inputs' previous hashes). -/
def BeefEntry.parents : BeefEntry → List Bytes
  | .raw tx _ => tx.inputs.map (·.prevHash)
  | .txidOnly _ => []

/-- [D] 2026-10-15: the entry with a txid, the earliest. -/
def Beef.find (b : Beef) (w : Bytes) : Option BeefEntry :=
  b.txs.find? fun e => e.txid == w

/-- [D] 2026-10-15: the closure of a set of txids under "a parent present in the
BEEF", with fuel: one round per entry suffices. -/
def Beef.closure (b : Beef) : Nat → List Bytes → List Bytes
  | 0, acc => acc
  | fuel + 1, acc =>
    let next := acc ++ ((acc.filterMap b.find).flatMap BeefEntry.parents).filter
      (fun p => (b.find p).isSome && !acc.contains p)
    if next.length = acc.length then acc else b.closure fuel next.dedup

/-- [D] 2026-10-15: the txids of a subject and its ancestors in the BEEF. -/
def Beef.ancestorsOf (b : Beef) (w : Bytes) : List Bytes := b.closure (b.txs.length + 1) [w]

/-- [D] 2026-10-15: the raw transaction a BEEF carries under a txid, the earliest
entry with that txid; `none` when it is absent or txid-only. -/
def Beef.subjectTx (b : Beef) (w : Bytes) : Option Tx :=
  match b.find w with
  | some (.raw tx _) => some tx
  | _ => none

/-- [D] 2026-10-15: the transaction with its ancestry: the subject transaction
(a raw entry whose txid is the word) and the object of every entry in its
ancestry, in BEEF order. `none` when the subject is absent or txid-only, or
when an object fails. -/
def Beef.ancestry (b : Beef) (w : Bytes) : Option (Tx × List (Bytes × BeefObject)) := do
  let tx ← b.subjectTx w
  let members := b.ancestorsOf w
  let objs ← (b.txs.filter fun e => members.contains e.txid).mapM fun e =>
    (b.object e).map fun o => (e.txid, o)
  pure (tx, objs)

/-- [LIT] 2026-10-15: BRC-62's ordering (0062.md:72-74, :50): every parent present
in the BEEF comes before its child. -/
def Beef.ordered (b : Beef) : Bool :=
  (List.range b.txs.length).all fun k =>
    match b.txs[k]? with
    | some e => e.parents.all fun p =>
        (b.txs.take k).any (fun x => x.txid == p) || !(b.txs.any fun x => x.txid == p)
    | none => true

/-- [LIT] 2026-10-15: the transaction a version-1 BEEF ends with, the one under
evaluation (0062.md:74). -/
def Beef.last? (b : Beef) : Option Bytes := b.txs.getLast?.map BeefEntry.txid

/-- [M] 2026-10-15, #86: the transaction a BEEF carries under a txid has that
txid. No premise beyond the lookup's success. -/
theorem subjectTx_txid (b : Beef) (w : Bytes) (tx : Tx) (h : b.subjectTx w = some tx) :
    BsvScript.Sighash.txid tx = w := by
  unfold Beef.subjectTx at h
  split at h
  · rename_i tx' bump hf
    simp only [Option.some.injEq] at h
    subst h
    have := List.find?_some hf
    simpa [BeefEntry.txid] using this
  · cases h

/-- [M] 2026-10-15, #86: the subject of an ancestry has the requested txid. No
premise beyond the projection's success. -/
theorem ancestry_subject (b : Beef) (w : Bytes) (tx : Tx) (objs : List (Bytes × BeefObject))
    (h : b.ancestry w = some (tx, objs)) : BsvScript.Sighash.txid tx = w := by
  unfold Beef.ancestry at h
  simp only [bind, Option.bind] at h
  split at h
  · cases h
  · rename_i t ht; try dsimp only at h
    split at h
    · cases h
    · simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
      obtain ⟨rfl, _⟩ := h
      exact subjectTx_txid b w t ht

end BsvChain.Views.Wire
