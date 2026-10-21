import BsvChain.Views.Wire.Bytes

/-!
# The Extended Format (EF, BRC-30) as a view (#86)

[M] 2026-10-15 (#86). [LIT] BRC-30 "Transaction Extended Format (EF)",
bsv-blockchain/BRCs at 5333fd449c70fd5982029876376dcf1ed9c64ffe,
`transactions/0030.md` (read 2026-10-15T03:25:54Z from
https://raw.githubusercontent.com/bsv-blockchain/BRCs/5333fd449c70fd5982029876376dcf1ed9c64ffe/transactions/0030.md,
9663 bytes, sha256 `395fa0566fcae8e2c5478a03b8a500034553fbce634f48c6df114c8c828dab44`).
Views, never rules: EF is a client encoding of a transaction with the outputs
its inputs spend; no node rule reads it.

The layout (0030.md:36-44, :60-69): the version (4 bytes), the marker
`0000000000EF` (6 bytes, :39), the input count (VarInt), the extended inputs,
the output count (VarInt), the outputs, the lock time (4 bytes). An extended
input (:60-69) is the plain input (previous hash 32 bytes, previous index 4,
script length VarInt, script, sequence 4) followed by the spent output's value
and its locking script (length VarInt, then the script).

**The value width: the text and the engines disagree.** The table at
0030.md:67 gives "Previous TX satoshi output ... 4 bytes". Every engine read
for this view writes and reads 8 bytes, the width of `CTxOut::nValue`
([SRC] src/primitives/transaction.h:175-194 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b):
bsv-rs 0.5.0 `src/transaction/transaction.rs:261` (`read_u64_le`), go-sdk
v1.7.2 `transaction/input.go:125-131`, @bsv/sdk 3.0.0
`packages/sdk/src/transaction/Transaction.ts:388`. The codec below
reads 8 bytes, the named parameter `efValueWidth`, and the record carries the
text's 4 as a documentation divergence; the mainnet-derived corpus is
written by the engines' width. [D]

The marker is chosen so that a reader of the plain format sees a transaction
with no inputs, no outputs and a lock time, and stops before the rest
(0030.md:46, :73); `ef_legacy_reading` below states what the machine's own
decoder reads from an EF stream.
-/

namespace BsvChain.Views.Wire
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash BsvScript.Sighash BsvChain.Properties

/-- [LIT] 2026-10-15: the EF marker `0000000000EF` (BRCs 5333fd4 transactions/0030.md:39). -/
def efMarker : Bytes := [0, 0, 0, 0, 0, 0xef]

/-- [D] 2026-10-15: the width of the spent output's value in an extended input:
8 bytes, the engines' width and `CTxOut::nValue`'s; the BRC text at 0030.md:67
says 4 (the divergence of the module docstring). -/
def efValueWidth : Nat := 8

/-- [LIT] 2026-10-15: an extended input: the plain input, then the value and the
locking script of the output it spends (0030.md:60-69). -/
structure EfInput where
  input : TxIn
  prevValue : Nat
  prevScript : Bytes
  deriving Repr

/-- [LIT] 2026-10-15: an EF transaction (0030.md:36-44). -/
structure EfTx where
  version : Int
  inputs : List EfInput
  outputs : List TxOut
  lockTime : Nat
  deriving Repr

/-- [LIT] 2026-10-15: an extended input's bytes. -/
def serEfInput (e : EfInput) : Bytes :=
  serTxIn e.input ++ headerWordBytes efValueWidth e.prevValue ++ serScript e.prevScript

/-- [LIT] 2026-10-15: the EF bytes: version, marker, inputs, outputs, lock time. -/
def EfTx.encode (t : EfTx) : Bytes :=
  serVersion t.version ++ efMarker ++ compactSize t.inputs.length ++ (t.inputs.map serEfInput).flatten
    ++ compactSize t.outputs.length ++ (t.outputs.map serTxOut).flatten ++ le32 t.lockTime

/-- [LIT] 2026-10-15: read one extended input. -/
def readEfInput (bs : Bytes) : Option (EfInput × Bytes) := do
  let (input, r1) ← readTxIn bs
  let (prevValue, r2) ← readLE efValueWidth r1
  let (len, r3) ← readVarInt r2
  let (prevScript, r4) ← readBytes len r3
  pure ({ input, prevValue, prevScript }, r4)

/-- [LIT] 2026-10-15: read an EF transaction from the front of a byte string; a
missing or different marker is refused. -/
def EfTx.decodePrefix (bs : Bytes) : Option (EfTx × Bytes) := do
  let (v, r1) ← readLE 4 bs
  let r2 ← expectTag efMarker r1
  let (nIn, r3) ← readVarInt r2
  let (inputs, r4) ← readMany readEfInput nIn r3
  let (nOut, r5) ← readVarInt r4
  let (outputs, r6) ← readMany readTxOut nOut r5
  let (lockTime, r7) ← readLE 4 r6
  pure ({ version := toInt32 v, inputs, outputs, lockTime }, r7)

/-- [LIT] 2026-10-15: exactly one EF transaction, trailing bytes refused. -/
def EfTx.decode (bs : Bytes) : Option EfTx :=
  match EfTx.decodePrefix bs with
  | some (t, []) => some t
  | _ => none

/-! ## The function to the machine's objects -/

/-- [D] 2026-10-15: the transaction an EF carries: the plain inputs, the outputs. -/
def EfTx.tx (t : EfTx) : Tx :=
  { version := t.version, inputs := t.inputs.map (·.input), outputs := t.outputs, lockTime := t.lockTime }

/-- [D] 2026-10-15: the outputs the inputs spend, in input order: the coins the
evaluator needs for each input's locking script and the sighash's value. -/
def EfTx.spent (t : EfTx) : List TxOut :=
  t.inputs.map fun e => { value := e.prevValue, scriptPubKey := e.prevScript }

/-- [D] 2026-10-15: the EF of a transaction and the outputs it spends. -/
def EfTx.ofTx (tx : Tx) (spent : List TxOut) : EfTx :=
  { version := tx.version,
    inputs := (tx.inputs.zip spent).map fun p => { input := p.1, prevValue := p.2.value, prevScript := p.2.scriptPubKey },
    outputs := tx.outputs, lockTime := tx.lockTime }

/-! ## Well-formedness and the round trips -/

/-- [D] 2026-10-15: an extended input whose fields fit their wire widths. -/
def EfInputWellFormed (e : EfInput) : Prop :=
  TxInWellFormed e.input ∧ e.prevValue < 2 ^ 64 ∧ ByteValued e.prevScript ∧ e.prevScript.length < 2 ^ 64

/-- [D] 2026-10-15: a well-formed EF transaction: #68's transaction conditions
over the plain fields, and well-formed extended inputs. -/
def EfWellFormed (t : EfTx) : Prop :=
  -2 ^ 31 ≤ t.version ∧ t.version < 2 ^ 31 ∧ t.inputs.length < 2 ^ 64 ∧
    t.outputs.length < 2 ^ 64 ∧ t.lockTime < 2 ^ 32 ∧
    (∀ e ∈ t.inputs, EfInputWellFormed e) ∧ ∀ o ∈ t.outputs, TxOutWellFormed o

/-- [D] 2026-10-15: an extended input reads back from its bytes. -/
theorem readEfInput_serEfInput (e : EfInput) (rest : Bytes) (wf : EfInputWellFormed e) :
    readEfInput (serEfInput e ++ rest) = some (e, rest) := by
  obtain ⟨wi, hv, _, hl⟩ := wf
  have h1 : serEfInput e ++ rest = serTxIn e.input ++ (headerWordBytes efValueWidth e.prevValue ++
      (compactSize e.prevScript.length ++ (e.prevScript ++ rest))) := by
    simp [serEfInput, serScript, List.append_assoc]
  rw [h1]
  simp only [readEfInput, bind, Option.bind, readTxIn_serTxIn _ _ wi,
    readLE_headerWordBytes _ _ _ (by simp only [efValueWidth]; omega : e.prevValue < 256 ^ efValueWidth),
    readVarInt_compactSize _ _ hl, readBytes_append, pure]

/-- [D] 2026-10-15: an extended input read from byte-valued bytes writes back. -/
theorem serEfInput_readEfInput (bs : Bytes) (e : EfInput) (r : Bytes) (hb : ByteValued bs)
    (h : readEfInput bs = some (e, r)) : serEfInput e ++ r = bs := by
  simp only [readEfInput, bind, Option.bind] at h
  split at h; · cases h
  rename_i p1 h1; obtain ⟨input, r1⟩ := p1; try dsimp only at h
  split at h; · cases h
  rename_i p2 h2; obtain ⟨prevValue, r2⟩ := p2; try dsimp only at h
  split at h; · cases h
  rename_i p3 h3; obtain ⟨len, r3⟩ := p3; try dsimp only at h
  split at h; · cases h
  rename_i p4 h4; obtain ⟨prevScript, r4⟩ := p4; try dsimp only at h
  simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
  obtain ⟨rfl, rfl⟩ := h
  have e1 := readTxIn_inv bs input r1 hb h1
  have b1 : ByteValued r1 := (byteValued_append.mp (e1 ▸ hb)).2
  obtain ⟨e2, _⟩ := readLE_inv b1 h2
  have b2 : ByteValued r2 := (byteValued_append.mp (e2 ▸ b1)).2
  obtain ⟨e3, _⟩ := readVarInt_inv b2 h3
  have b3 : ByteValued r3 := (byteValued_append.mp (e3 ▸ b2)).2
  obtain ⟨e4, hl4⟩ := readBytes_inv h4
  simp only [serEfInput, serScript, List.append_assoc, hl4, e4, e3, e2, e1]

/-- [M] 2026-10-15, #86 (EF, parse after serialize). For every well-formed EF
transaction the decoder reads the encoder's bytes back exactly and leaves any
following stream untouched. Premise: `wf`, the field widths of #68's G4 and
of the extended fields. [LIT] BRC-30 at 5333fd4, 0030.md:36-69. -/
theorem ef_decodePrefix_encode (t : EfTx) (rest : Bytes) (wf : EfWellFormed t) :
    EfTx.decodePrefix (t.encode ++ rest) = some (t, rest) := by
  obtain ⟨lo, hi, hin, hout, hlock, win, wout⟩ := wf
  have h1 : t.encode ++ rest = headerWordBytes 4 ((t.version % 2 ^ 32).toNat) ++ (efMarker ++
      (compactSize t.inputs.length ++ ((t.inputs.map serEfInput).flatten ++
      (compactSize t.outputs.length ++ ((t.outputs.map serTxOut).flatten ++
      (headerWordBytes 4 t.lockTime ++ rest)))))) := by
    simp [EfTx.encode, serVersion, le32_eq, List.append_assoc]
  rw [h1]
  have hv : (t.version % 2 ^ 32).toNat < 256 ^ 4 := by omega
  simp only [EfTx.decodePrefix, bind, Option.bind, readLE_headerWordBytes _ _ _ hv, expectTag_append,
    readVarInt_compactSize _ _ hin, readVarInt_compactSize _ _ hout,
    readMany_ser readEfInput serEfInput EfInputWellFormed (fun x r h => readEfInput_serEfInput x r h) _ win,
    readMany_ser readTxOut serTxOut TxOutWellFormed (fun x r h => readTxOut_serTxOut x r h) _ wout,
    readLE_headerWordBytes _ _ _ (by omega : t.lockTime < 256 ^ 4), pure, toInt32_version _ lo hi]

/-- [M] 2026-10-15, #86 (EF, serialize after parse). An EF transaction read
from the front of byte-valued bytes encodes back to exactly the bytes read.
Premise: the input is byte-valued. [LIT] BRC-30 at 5333fd4, 0030.md:36-69. -/
theorem ef_encode_decodePrefix (bs : Bytes) (t : EfTx) (r : Bytes) (hb : ByteValued bs)
    (h : EfTx.decodePrefix bs = some (t, r)) : t.encode ++ r = bs := by
  simp only [EfTx.decodePrefix, bind, Option.bind] at h
  split at h; · cases h
  rename_i p1 h1; obtain ⟨v, r1⟩ := p1; try dsimp only at h
  split at h; · cases h
  rename_i r2 h2; try dsimp only at h
  split at h; · cases h
  rename_i p3 h3; obtain ⟨nIn, r3⟩ := p3; try dsimp only at h
  split at h; · cases h
  rename_i p4 h4; obtain ⟨inputs, r4⟩ := p4; try dsimp only at h
  split at h; · cases h
  rename_i p5 h5; obtain ⟨nOut, r5⟩ := p5; try dsimp only at h
  split at h; · cases h
  rename_i p6 h6; obtain ⟨outputs, r6⟩ := p6; try dsimp only at h
  split at h; · cases h
  rename_i p7 h7; obtain ⟨lockTime, r7⟩ := p7; try dsimp only at h
  simp only [pure, Option.some.injEq, Prod.mk.injEq] at h
  obtain ⟨rfl, rfl⟩ := h
  obtain ⟨e1, lt1⟩ := readLE_inv hb h1
  have b1 : ByteValued r1 := (byteValued_append.mp (e1 ▸ hb)).2
  have e2 := expectTag_inv h2
  have b2 : ByteValued r2 := (byteValued_append.mp (e2 ▸ b1)).2
  obtain ⟨e3, _⟩ := readVarInt_inv b2 h3
  have b3 : ByteValued r3 := (byteValued_append.mp (e3 ▸ b2)).2
  obtain ⟨e4, l4⟩ := readMany_inv readEfInput serEfInput
    (fun bs x r hb h => serEfInput_readEfInput bs x r hb h) _ _ _ _ b3 h4
  have b4 : ByteValued r4 := (byteValued_append.mp (e4 ▸ b3)).2
  obtain ⟨e5, _⟩ := readVarInt_inv b4 h5
  have b5 : ByteValued r5 := (byteValued_append.mp (e5 ▸ b4)).2
  obtain ⟨e6, l6⟩ := readMany_inv readTxOut serTxOut (fun bs x r hb h => readTxOut_inv bs x r hb h) _ _ _ _ b5 h6
  have b6 : ByteValued r6 := (byteValued_append.mp (e6 ▸ b5)).2
  obtain ⟨e7, _⟩ := readLE_inv b6 h7
  simp only [EfTx.encode, serVersion_toInt32 v (by simpa using lt1), le32_eq, List.append_assoc, l4, l6,
    e7, e6, e5, e4, e3, e2, e1]

/-- [M] 2026-10-15, #86: the exact EF decoder and the encoder are inverse:
`decode (encode t) = some t` for well-formed `t`, and `encode t = bs` whenever
`decode bs = some t` on byte-valued `bs`. -/
theorem ef_decode_encode (t : EfTx) (wf : EfWellFormed t) : EfTx.decode t.encode = some t := by
  have h := ef_decodePrefix_encode t [] wf
  rw [List.append_nil] at h
  simp [EfTx.decode, h]

/-- [M] 2026-10-15, #86: the exact EF decoder's accepted bytes are the encoding
of what it reads. Premise: the input is byte-valued. -/
theorem ef_encode_decode (bs : Bytes) (t : EfTx) (hb : ByteValued bs) (h : EfTx.decode bs = some t) :
    t.encode = bs := by
  unfold EfTx.decode at h
  split at h
  · rename_i t' hp
    simp only [Option.some.injEq] at h
    subst h
    simpa using ef_encode_decodePrefix bs t' [] hb hp
  · cases h

/-- [M] 2026-10-15, #86 (the projection is a section). The EF built from a
transaction and as many spent outputs as it has inputs projects back to that
transaction and those outputs. Premise: one spent output per input. -/
theorem ef_ofTx_tx_spent (tx : Tx) (spent : List TxOut) (h : spent.length = tx.inputs.length) :
    (EfTx.ofTx tx spent).tx = tx ∧ (EfTx.ofTx tx spent).spent = spent := by
  constructor
  · simp only [EfTx.ofTx, EfTx.tx, List.map_map]
    have : (tx.inputs.zip spent).map ((·.input) ∘ fun p : TxIn × TxOut =>
        ({ input := p.1, prevValue := p.2.value, prevScript := p.2.scriptPubKey } : EfInput)) =
        (tx.inputs.zip spent).map Prod.fst := rfl
    rw [this, List.map_fst_zip (by omega)]
  · simp only [EfTx.ofTx, EfTx.spent, List.map_map]
    have : (tx.inputs.zip spent).map ((fun e : EfInput => ({ value := e.prevValue, scriptPubKey := e.prevScript } : TxOut)) ∘
        fun p : TxIn × TxOut =>
        ({ input := p.1, prevValue := p.2.value, prevScript := p.2.scriptPubKey } : EfInput)) =
        (tx.inputs.zip spent).map Prod.snd := rfl
    rw [this, List.map_snd_zip (by omega)]

/-- [M] 2026-10-15, #86 (BRC-30's backward-compatibility sentence, 0030.md:46
and :73, as a theorem of the machine's own decoder). The transaction prefix
decoder reads the front of every well-formed EF stream as a transaction with
the EF's version, no inputs, no outputs and the lock time `0xEF000000`
(the marker's last four bytes, little-endian), and leaves a non-empty rest; so
the exact decoder `decodeTx` refuses every EF stream. Premise: `wf`.
[SRC] src/primitives/transaction.h:233-252 at 6504a3af; [LIT] BRC-30 at 5333fd4. -/
theorem ef_legacy_reading (t : EfTx) (wf : EfWellFormed t) :
    ∃ rest, rest ≠ [] ∧
      decodeTxPrefix t.encode = some ({ version := t.version, inputs := [], outputs := [], lockTime := 0xEF000000 }, rest) := by
  obtain ⟨lo, hi, _, _, _, _, _⟩ := wf
  refine ⟨compactSize t.inputs.length ++ (t.inputs.map serEfInput).flatten ++ compactSize t.outputs.length ++
    (t.outputs.map serTxOut).flatten ++ le32 t.lockTime, ?_, ?_⟩
  · unfold compactSize
    split_ifs <;> simp
  · have h1 : t.encode = headerWordBytes 4 ((t.version % 2 ^ 32).toNat) ++ (0 :: 0 :: (headerWordBytes 4 0xEF000000 ++
        (compactSize t.inputs.length ++ (t.inputs.map serEfInput).flatten ++ compactSize t.outputs.length ++
          (t.outputs.map serTxOut).flatten ++ le32 t.lockTime))) := by
      simp [EfTx.encode, serVersion, le32_eq, efMarker, headerWordBytes, List.append_assoc]
    rw [h1]
    have hv : (t.version % 2 ^ 32).toNat < 256 ^ 4 := by omega
    simp only [decodeTxPrefix, bind, Option.bind, readLE_headerWordBytes _ _ _ hv, List.cons_append,
      readVarInt, show (0 : Nat) < 253 by decide, if_true, readMany,
      readLE_headerWordBytes _ _ _ (by norm_num : (0xEF000000 : Nat) < 256 ^ 4), pure,
      toInt32_version _ lo hi, List.append_assoc]

/-- [M] 2026-10-15, #86: the exact transaction decoder refuses every well-formed
EF stream (the corollary of `ef_legacy_reading`). -/
theorem ef_not_plain (t : EfTx) (wf : EfWellFormed t) : decodeTx t.encode = none := by
  obtain ⟨rest, hne, h⟩ := ef_legacy_reading t wf
  simp only [decodeTx, bind, Option.bind, h]
  cases rest with
  | nil => exact absurd rfl hne
  | cons _ _ => rfl

end BsvChain.Views.Wire
