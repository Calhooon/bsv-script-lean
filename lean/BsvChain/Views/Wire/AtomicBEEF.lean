import BsvChain.Views.Wire.BEEF

/-!
# Atomic BEEF (BRC-95) as a view (#86)

[M] 2026-10-15 (#86). [LIT] BRC-95 "Atomic BEEF Transactions",
bsv-blockchain/BRCs at 5333fd449c70fd5982029876376dcf1ed9c64ffe,
`transactions/0095.md` (read 2026-10-15T03:25:55Z from
https://raw.githubusercontent.com/bsv-blockchain/BRCs/5333fd449c70fd5982029876376dcf1ed9c64ffe/transactions/0095.md,
6801 bytes, sha256 `e5ceb51ecbfd9b3715227e65891503908e485eb09d1a0bfd8060d99b2e13026e`).
Views, never rules.

The layout (0095.md:27-38, :73-79): the prefix `0x01010101` (4 bytes, :31),
the subject's txid (32 bytes, :32), then a BEEF of BRC-62 (`0100beef ...`, :78;
this codec also takes BRC-96's version 2, as the three engines do). The two
error conditions (:65-71), a missing subject and an unrelated transaction, are
validation, not grammar: the codec reads every prefix, word and BEEF, and the
view `AtomicBeef.scoped` decides the two conditions. A second prefix inside is
refused by the grammar: the inner bytes must begin with a BEEF version word.
-/

namespace BsvChain.Views.Wire
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash BsvScript.Sighash BsvChain.Properties BsvChain.Views

/-- [LIT] 2026-10-15: the Atomic BEEF prefix `0x01010101` (0095.md:31). -/
def atomicPrefix : Bytes := [1, 1, 1, 1]

/-- [LIT] 2026-10-15: an Atomic BEEF: the subject's txid (internal order) and the BEEF. -/
structure AtomicBeef where
  subject : Bytes
  beef : Beef
  deriving Repr

/-- [LIT] 2026-10-15: the Atomic BEEF bytes (0095.md:34-38). -/
def AtomicBeef.encode (a : AtomicBeef) : Bytes := atomicPrefix ++ a.subject ++ a.beef.encode

/-- [LIT] 2026-10-15: read an Atomic BEEF from the front of a byte string. -/
def AtomicBeef.decodePrefix (bs : Bytes) : Option (AtomicBeef × Bytes) := do
  let r1 ← expectTag atomicPrefix bs
  let (subject, r2) ← readBytes 32 r1
  let (beef, r3) ← Beef.decodePrefix r2
  pure ({ subject, beef }, r3)

/-- [LIT] 2026-10-15: exactly one Atomic BEEF, trailing bytes refused. -/
def AtomicBeef.decode (bs : Bytes) : Option AtomicBeef :=
  match AtomicBeef.decodePrefix bs with
  | some (a, []) => some a
  | _ => none

/-- [D] 2026-10-15: a well-formed Atomic BEEF: a 32-byte subject, a well-formed BEEF. -/
def AtomicWellFormed (a : AtomicBeef) : Prop := a.subject.length = 32 ∧ BeefWellFormed a.beef

/-- [M] 2026-10-15, #86 (Atomic BEEF, parse after serialize). Premise: `wf`.
[LIT] BRC-95 at 5333fd4, 0095.md:27-38. -/
theorem atomic_decodePrefix_encode (a : AtomicBeef) (rest : Bytes) (wf : AtomicWellFormed a) :
    AtomicBeef.decodePrefix (a.encode ++ rest) = some (a, rest) := by
  obtain ⟨hs, wb⟩ := wf
  have h := readBytes_append a.subject (a.beef.encode ++ rest)
  rw [hs] at h
  simp only [AtomicBeef.encode, AtomicBeef.decodePrefix, List.append_assoc, bind, Option.bind,
    expectTag_append, h, beef_decodePrefix_encode _ _ wb, pure]

/-- [M] 2026-10-15, #86 (Atomic BEEF, serialize after parse). Premise: the
input is byte-valued. [LIT] BRC-95 at 5333fd4. -/
theorem atomic_encode_decodePrefix (bs : Bytes) (a : AtomicBeef) (r : Bytes) (hb : ByteValued bs)
    (h : AtomicBeef.decodePrefix bs = some (a, r)) : a.encode ++ r = bs := by
  simp only [AtomicBeef.decodePrefix, bind, Option.bind] at h
  split at h; · cases h
  rename_i r1 h1; try dsimp only at h
  split at h; · cases h
  rename_i p2 h2; obtain ⟨subject, r2⟩ := p2; try dsimp only at h
  split at h; · cases h
  rename_i p3 h3; obtain ⟨beef, r3⟩ := p3; try dsimp only at h
  simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
  obtain ⟨rfl, rfl⟩ := h
  have e1 := expectTag_inv h1
  have b1 : ByteValued r1 := (byteValued_append.mp (e1 ▸ hb)).2
  obtain ⟨e2, _⟩ := readBytes_inv h2
  have b2 : ByteValued r2 := (byteValued_append.mp (e2 ▸ b1)).2
  have e3 := beef_encode_decodePrefix r2 beef r3 b2 h3
  simp only [AtomicBeef.encode, List.append_assoc, e3, e2, e1]

/-- [M] 2026-10-15, #86: the exact Atomic BEEF decoder and the encoder are inverse. -/
theorem atomic_decode_encode (a : AtomicBeef) (wf : AtomicWellFormed a) :
    AtomicBeef.decode a.encode = some a := by
  have h := atomic_decodePrefix_encode a [] wf
  rw [List.append_nil] at h
  simp [AtomicBeef.decode, h]

/-- [M] 2026-10-15, #86: the exact Atomic BEEF decoder's accepted bytes are the
encoding of what it reads. Premise: the input is byte-valued. -/
theorem atomic_encode_decode (bs : Bytes) (a : AtomicBeef) (hb : ByteValued bs)
    (h : AtomicBeef.decode bs = some a) : a.encode = bs := by
  unfold AtomicBeef.decode at h
  split at h
  · rename_i a' hp
    simp only [Option.some.injEq] at h
    subst h
    simpa using atomic_encode_decodePrefix bs a' [] hb hp
  · cases h

/-- [M] 2026-10-15, #86: an Atomic BEEF is never read as a plain BEEF: its
leading four bytes are the word `0x01010101`, neither BEEF version. No premise. -/
theorem atomic_not_beef (a : AtomicBeef) : Beef.decodePrefix a.encode = none := by
  have hw : atomicPrefix = headerWordBytes 4 16843009 := by decide
  have hv : readBeefVersion a.encode = none := by
    simp only [AtomicBeef.encode, List.append_assoc, hw, readBeefVersion, bind, Option.bind,
      readLE_headerWordBytes _ _ _ (by norm_num : (16843009 : Nat) < 256 ^ 4)]
    simp
  simp only [Beef.decodePrefix, bind, Option.bind, hv]

/-! ## The function to the machine's objects -/

/-- [D] 2026-10-15: the subject transaction with its ancestry (BEEF's projection
at the subject's txid). -/
def AtomicBeef.ancestry (a : AtomicBeef) : Option (Tx × List (Bytes × BeefObject)) :=
  a.beef.ancestry a.subject

/-- [LIT] 2026-10-15: BRC-95's two error conditions as a view (0095.md:65-71):
the subject is a raw entry of the BEEF, and every entry is the subject or one
of its ancestors in the BEEF. -/
def AtomicBeef.scoped (a : AtomicBeef) : Bool :=
  (match a.beef.find a.subject with
    | some (.raw _ _) => true
    | _ => false) &&
  a.beef.txs.all fun e => (a.beef.ancestorsOf a.subject).contains e.txid

/-- [M] 2026-10-15, #86: a scoped Atomic BEEF names a subject it carries as a
raw transaction whose txid is the subject word. No premise beyond `scoped`. -/
theorem scoped_subject (a : AtomicBeef) (h : a.scoped = true) :
    ∃ tx bump, a.beef.find a.subject = some (.raw tx bump) ∧ BsvScript.Sighash.txid tx = a.subject := by
  simp only [AtomicBeef.scoped, Bool.and_eq_true] at h
  obtain ⟨h1, _⟩ := h
  split at h1
  · rename_i tx bump hf
    refine ⟨tx, bump, hf, ?_⟩
    have := List.find?_some hf
    simpa [BeefEntry.txid] using this
  · cases h1

end BsvChain.Views.Wire
