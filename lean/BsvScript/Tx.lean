import BsvScript.Machine
/-!
# BsvScript.Tx

The transaction frame (`src/primitives/transaction.h` at the pin): the fields
the machine and the sighash read, and the decoder from the serialized bytes
(`docs/DESIGN.md` §6: the corpus carries the spending transaction as hex). The
serialization for the sighash is #12's.
-/

namespace BsvScript.Tx
open BsvScript.Numbers

/-- `CTxIn`: the outpoint (the previous txid in the serialized, internal order,
and the index), the unlocking script, the sequence.
[LIT] https://protocol.bsvblockchain.org/specification/transactions#serialization-format at v1.2.2. -/
structure TxIn where
  prevHash : Bytes
  prevIndex : Nat
  scriptSig : Bytes
  sequence : Nat
  deriving Repr

/-- `CTxOut`: the value in satoshis and the locking script.
[LIT] https://protocol.bsvblockchain.org/specification/transactions#serialization-format at v1.2.2. -/
structure TxOut where
  value : Nat
  scriptPubKey : Bytes
  deriving Repr

/-- `CTransaction`: `nVersion` (a signed 32-bit integer, `transaction.h`), the
inputs, the outputs, `nLockTime`.
[LIT] https://protocol.bsvblockchain.org/specification/transactions#serialization-format at v1.2.2. -/
structure Tx where
  version : Int
  inputs : List TxIn
  outputs : List TxOut
  lockTime : Nat
  deriving Repr

/-- The signed reading of a 32-bit word. -/
def toInt32 (u : Nat) : Int := if u < 2 ^ 31 then (u : Int) else (u : Int) - 2 ^ 32

/-- A little-endian fixed-width integer. -/
def readLE (n : Nat) (bs : Bytes) : Option (Nat × Bytes) :=
  if bs.length < n then none else some (leNat (bs.take n), bs.drop n)

/-- `ReadCompactSize` (`serialize.h:315–340`): one byte below 253, else a marker and 2, 4 or 8
little-endian bytes, refused when non-canonical: a value below 253 after `0xfd`, below `0x10000` after
`0xfe`, below `2^32` after `0xff` (`320–335`, "non-canonical ReadCompactSize()"; `DecodeHexTx` then fails,
`core_read.cpp:184–191`). The `MAX_SIZE` bound (`336–338`) has no verdict consequence here: a count or a
length that large is never backed by the bytes that follow (lean #32's second lens, finding B-1).
[LIT] https://protocol.bsvblockchain.org/specification/transactions#compactsize-varint at v1.2.2. -/
def readVarInt (bs : Bytes) : Option (Nat × Bytes) :=
  match bs with
  | [] => none
  | b :: rest =>
    if b < 253 then some (b, rest)
    else if b = 253 then (readLE 2 rest).filter (fun (v, _) => 253 ≤ v)
    else if b = 254 then (readLE 4 rest).filter (fun (v, _) => 0x10000 ≤ v)
    else (readLE 8 rest).filter (fun (v, _) => 0x100000000 ≤ v)

def readBytes (n : Nat) (bs : Bytes) : Option (Bytes × Bytes) :=
  if bs.length < n then none else some (bs.take n, bs.drop n)

def readTxIn (bs : Bytes) : Option (TxIn × Bytes) := do
  let (prevHash, r1) ← readBytes 32 bs
  let (prevIndex, r2) ← readLE 4 r1
  let (len, r3) ← readVarInt r2
  let (script, r4) ← readBytes len r3
  let (sequence, r5) ← readLE 4 r4
  pure ({ prevHash, prevIndex, scriptSig := script, sequence }, r5)

def readTxOut (bs : Bytes) : Option (TxOut × Bytes) := do
  let (value, r1) ← readLE 8 bs
  let (len, r2) ← readVarInt r1
  let (script, r3) ← readBytes len r2
  pure ({ value, scriptPubKey := script }, r3)

def readMany {α : Type} (reader : Bytes → Option (α × Bytes)) : Nat → Bytes → Option (List α × Bytes)
  | 0, bs => some ([], bs)
  | n + 1, bs => do
    let (x, r) ← reader bs
    let (xs, r') ← readMany reader n r
    pure (x :: xs, r')

/-- One transaction read from the front of a byte string, the rest returned
(`CTransaction` `Unserialize`, `transaction.h`: version, the inputs, the
outputs, the lock time; a stream may carry more after it, as the reference's
vector runner's does). -/
def decodeTxPrefix (bs : Bytes) : Option (Tx × Bytes) := do
  let (v, r1) ← readLE 4 bs
  let (nIn, r2) ← readVarInt r1
  let (inputs, r3) ← readMany readTxIn nIn r2
  let (nOut, r4) ← readVarInt r3
  let (outputs, r5) ← readMany readTxOut nOut r4
  let (lockTime, r6) ← readLE 4 r5
  pure ({ version := toInt32 v, inputs, outputs, lockTime }, r6)

/-- Exactly one transaction: the corpus format's `tx` (`docs/DESIGN.md` §6). -/
def decodeTx (bs : Bytes) : Option Tx := do
  let (tx, rest) ← decodeTxPrefix bs
  if rest.isEmpty then pure tx else none

/-! ## Hex -/

def hexVal (c : Char) : Option Nat :=
  if '0' ≤ c ∧ c ≤ '9' then some (c.toNat - '0'.toNat)
  else if 'a' ≤ c ∧ c ≤ 'f' then some (c.toNat - 'a'.toNat + 10)
  else if 'A' ≤ c ∧ c ≤ 'F' then some (c.toNat - 'A'.toNat + 10)
  else none

def hexDecodeChars : List Char → Option Bytes
  | [] => some []
  | a :: b :: rest => do
    let hi ← hexVal a
    let lo ← hexVal b
    let tl ← hexDecodeChars rest
    pure ((hi * 16 + lo) :: tl)
  | _ => none

/-- The hex decoder's compiled loop (#48, 2026-09-29, moved beside the definition):
`hexDecodeChars` recurses once per byte before it conses (`let tl ← hexDecodeChars rest; pure (_ :: tl)`), so a
reader overflows the thread's stack on a script of 16,000,000 bytes where 8,000,000 decode
(`docs/records/20260929-020042-ladder48-s1.md`); this loop carries the bytes decoded so far, reversed, and reverses
once at the end. -/
def hexDecodeCharsLoop : List Char → List Nat → Option Bytes
  | [], acc => some acc.reverse
  | a :: b :: rest, acc =>
    match hexVal a, hexVal b with
    | some hi, some lo => hexDecodeCharsLoop rest ((hi * 16 + lo) :: acc)
    | _, _ => none
  | [_], _ => none

/-- **`hexDecodeCharsLoop_eq`.** *What it says:* the loop from an accumulator `acc` is the decoder's answer with
`acc` reversed in front. *What it assumes:* nothing. *Why it matters:* it is the fact the decoder's compiled form
rests on: with `acc = []` the loop is `hexDecodeChars` itself. -/
theorem hexDecodeCharsLoop_eq : ∀ (l : List Char) (acc : List Nat),
    hexDecodeCharsLoop l acc = (hexDecodeChars l).map (acc.reverse ++ ·)
  | [], acc => by simp [hexDecodeCharsLoop, hexDecodeChars]
  | [_], acc => by simp [hexDecodeCharsLoop, hexDecodeChars]
  | a :: b :: rest, acc => by
    have ih := hexDecodeCharsLoop_eq rest
    cases ha : hexVal a with
    | none => simp [hexDecodeCharsLoop, hexDecodeChars, ha]
    | some hi =>
      cases hb : hexVal b with
      | none => simp [hexDecodeCharsLoop, hexDecodeChars, ha, hb]
      | some lo =>
        simp only [hexDecodeCharsLoop, hexDecodeChars, ha, hb, ih]
        cases hexDecodeChars rest <;> simp

/-- The decoder as it is compiled: the loop from the empty accumulator. -/
def hexDecodeCharsViaLoop (l : List Char) : Option Bytes := hexDecodeCharsLoop l []

/-- `@[csimp]` (lean #48; S1's ask 7): every call of `hexDecodeChars` compiled after this lemma runs the loop, so
`hexDecode` below and every caller of either (the reader, the CLI, the Test harnesses' direct calls) does; by
`hexDecodeCharsLoop_eq`. Nothing in the semantics moves: every theorem about the decoder is about the definition. -/
@[csimp] theorem hexDecodeChars_eq_viaLoop : @hexDecodeChars = @hexDecodeCharsViaLoop := by
  funext l
  simp [hexDecodeCharsViaLoop, hexDecodeCharsLoop_eq]

def hexDecode (s : String) : Option Bytes := hexDecodeChars s.toList

def hexEncode (bs : Bytes) : String :=
  let digit (n : Nat) : Char := if n < 10 then Char.ofNat ('0'.toNat + n) else Char.ofNat ('a'.toNat + n - 10)
  String.ofList (bs.foldr (fun b acc => digit (b / 16) :: digit (b % 16) :: acc) [])

-- ======================================================================================================
-- THE COMPILED IMPLEMENTATIONS (2026-09-27; #45's technique
-- of `Machine.lean` and `Numbers.lean`). The readers above are the semantics and do not move; each function
-- below is proven equal to one of them and `@[csimp]` makes the compiler substitute it in the code compiled
-- after the lemma (a csimp lemma rewrites only the calls compiled after it: the copies below exist for that). Why: `readLE` and `readBytes` test `bs.length < n` on the REST of the transaction for every
-- field they read, so a decode costs fields × size (`tx-00033` of `corpus/tx`, 1,020,053 bytes and 30,000
-- outputs, decided in 53.34 s with `List.lengthTR` in 1,710 of 1,717 stack samples,
-- `docs/records/20260927-031436-diff-s1.md`); `Machine.takeExact` walks the field's own length, never the rest. The
-- copies `readVarIntFast` … `decodeTxFast` are the definitions restated after the csimp lemmas of what
-- they call (a csimp lemma applies only to code compiled after it), each equal by `rfl`; `readMany` takes
-- its reader as an argument and needs no copy.

-- `readLE` in time linear in the field's own length (`Machine.takeExact`, then `drop n`).
def readLEFast (n : Nat) (bs : Bytes) : Option (Nat × Bytes) :=
  match Machine.takeExact n bs with
  | none => none
  | some f => some (leNat f, bs.drop n)

/-- `@[csimp]` (S1's ask 4 (a)): the compiler reads a fixed-width field with `readLEFast`, which walks the field's own `n` bytes (`Machine.takeExact`) instead of measuring the rest of the transaction (the decoder's wall of `docs/records/20260927-031436-diff-s1.md`, quadratic in fields × size); by `Machine.takeExact_eq`; nothing in the semantics moves, every theorem about the decoder is about `readLE`. -/
@[csimp] theorem readLE_eq_fast : @readLE = @readLEFast := by
  funext n bs
  simp only [readLE, readLEFast, Machine.takeExact_eq]
  split_ifs <;> rfl

-- `readBytes` in time linear in the field's own length (`Machine.takeExact`, then `drop n`).
def readBytesFast (n : Nat) (bs : Bytes) : Option (Bytes × Bytes) :=
  match Machine.takeExact n bs with
  | none => none
  | some f => some (f, bs.drop n)

/-- `@[csimp]` (S1's ask 4 (a)): the compiler reads a script or an outpoint's hash with `readBytesFast`, the field's own `n` bytes walked (`Machine.takeExact`, then `drop n`: linear in the field, never in the rest of the transaction); by `Machine.takeExact_eq`; nothing in the semantics moves. -/
@[csimp] theorem readBytes_eq_fast : @readBytes = @readBytesFast := by
  funext n bs
  simp only [readBytes, readBytesFast, Machine.takeExact_eq]
  split_ifs <;> rfl

-- The copies (the same definitions, restated after the csimp lemmas of what they call).
def readVarIntFast (bs : Bytes) : Option (Nat × Bytes) :=
  match bs with
  | [] => none
  | b :: rest =>
    if b < 253 then some (b, rest)
    else if b = 253 then (readLE 2 rest).filter (fun (v, _) => 253 ≤ v)
    else if b = 254 then (readLE 4 rest).filter (fun (v, _) => 0x10000 ≤ v)
    else (readLE 8 rest).filter (fun (v, _) => 0x100000000 ≤ v)

/-- `@[csimp]`: `readVarInt` restated after `readLE`'s csimp lemma so its compiled code calls the fast leaf; the same term (`rfl`). -/
@[csimp] theorem readVarInt_eq_fast : @readVarInt = @readVarIntFast := rfl

def readTxInFast (bs : Bytes) : Option (TxIn × Bytes) := do
  let (prevHash, r1) ← readBytes 32 bs
  let (prevIndex, r2) ← readLE 4 r1
  let (len, r3) ← readVarInt r2
  let (script, r4) ← readBytes len r3
  let (sequence, r5) ← readLE 4 r4
  pure ({ prevHash, prevIndex, scriptSig := script, sequence }, r5)

/-- `@[csimp]`: `readTxIn` restated after the csimp lemmas of `readBytes`, `readLE` and `readVarInt`; the same term (`rfl`). -/
@[csimp] theorem readTxIn_eq_fast : @readTxIn = @readTxInFast := rfl

def readTxOutFast (bs : Bytes) : Option (TxOut × Bytes) := do
  let (value, r1) ← readLE 8 bs
  let (len, r2) ← readVarInt r1
  let (script, r3) ← readBytes len r2
  pure ({ value, scriptPubKey := script }, r3)

/-- `@[csimp]`: `readTxOut` restated after the csimp lemmas of `readLE`, `readVarInt` and `readBytes`; the same term (`rfl`). -/
@[csimp] theorem readTxOut_eq_fast : @readTxOut = @readTxOutFast := rfl

def decodeTxPrefixFast (bs : Bytes) : Option (Tx × Bytes) := do
  let (v, r1) ← readLE 4 bs
  let (nIn, r2) ← readVarInt r1
  let (inputs, r3) ← readMany readTxIn nIn r2
  let (nOut, r4) ← readVarInt r3
  let (outputs, r5) ← readMany readTxOut nOut r4
  let (lockTime, r6) ← readLE 4 r5
  pure ({ version := toInt32 v, inputs, outputs, lockTime }, r6)

/-- `@[csimp]`: `decodeTxPrefix` restated after the readers' csimp lemmas (its `readMany` receives `readTxInFast` and `readTxOutFast` in compiled code); the same term (`rfl`). -/
@[csimp] theorem decodeTxPrefix_eq_fast : @decodeTxPrefix = @decodeTxPrefixFast := rfl

def decodeTxFast (bs : Bytes) : Option Tx := do
  let (tx, rest) ← decodeTxPrefix bs
  if rest.isEmpty then pure tx else none

/-- `@[csimp]`: `decodeTx` restated after `decodeTxPrefix`'s csimp lemma; the same term (`rfl`): the compiled evaluator decodes with the fast readers at every call site, and every theorem about `decodeTx` is about the definition. -/
@[csimp] theorem decodeTx_eq_fast : @decodeTx = @decodeTxFast := rfl

end BsvScript.Tx
