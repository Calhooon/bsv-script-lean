import BsvScript.Ops.Stack
import BsvScript.Ops.Bitwise
import BsvScript.Ops.Expansion
import BsvScript.Ops.Crypto
/-!
# BsvScript.Impl.Elem: the implementation's stack element, a packed byte array (lean #143)

The implementation state (`Impl.IState`, #50) holds every stack element as an `Elem`, Lean's packed `ByteArray`:
one byte per byte, as the reference's `std::vector<uint8_t>` (`limitedstack.h:14`, `:30`), where the spec's `Bytes`
(`List Nat`) is a cons cell per byte (#142's record: a 2147483647-byte element some 30 GB resident on the 36 GB
box). `Elem.toBytes` reads an element as the spec's `Bytes`; every operation the implementation does to an element
is named here with its lemma to the list operation through `toBytes`, so nothing outside this file knows
`ByteArray`'s API and no op touches the representation twice. The spec's own `Bytes` stays `List Nat`, and every
theorem about the semantics stays about it.
-/

set_option autoImplicit false

namespace BsvScript.Impl
open BsvScript.Params BsvScript.Numbers BsvScript.Machine BsvScript.Hash

/-- The implementation's stack element: a packed byte array (#143). -/
abbrev Elem := ByteArray

namespace Elem

/-! ## The two conversions -/

/-- The spec's `Bytes` an element stands for: its bytes, in order, as natural numbers. -/
def toBytes (e : Elem) : Bytes := e.data.toList.map UInt8.toNat

/-- An element of a byte list, in order. A value at or above 256 is kept modulo 256 (`Nat.toUInt8`), so the round
trip holds on `Bytes.valid` lists only (`toBytes_ofBytes`); every list the implementation converts is valid. -/
def ofBytes (bs : Bytes) : Elem := (bs.map Nat.toUInt8).toByteArray

/-- A list's bytes pushed at the end. -/
def pushList : Elem → Bytes → Elem
  | a, [] => a
  | a, b :: bs => pushList (a.push b.toUInt8) bs

/-- **`toBytes_pushList`.** *What it says:* pushing a valid list appends it. *What it assumes:*
`Bytes.valid bs`. *Why it matters:* `OP_NUM2BIN`'s pad (#143). -/
theorem toBytes_pushList (a : Elem) (bs : Bytes) (h : Bytes.valid bs) :
    toBytes (pushList a bs) = toBytes a ++ bs := by
  induction bs generalizing a with
  | nil => simp [pushList]
  | cons b bs ih =>
    rw [valid_cons] at h
    rw [pushList, ih _ h.2]
    simp [toBytes, ByteArray.data_push, Nat.toUInt8, Nat.mod_eq_of_lt h.1]

/-! ## The two conversions' compiled forms

`toBytes` and `ofBytes` are stated through `ByteArray.data` and `List.toByteArray`, the forms the lemmas read; at
run time `data` builds a boxed `Array UInt8` on the way to the list. The machine converts once per phase (the stack
handed from the unlocking phase to the locking phase, `Impl.evalScriptA`), a million times on #48's large lock, so
the compiler runs two loops instead (`@[csimp]`, proven equal; nothing in the semantics moves). -/

/-- `toBytes`'s loop: the bytes read from the last back to the earliest onto the list. -/
def toBytesLoop (e : Elem) : (i : Nat) → i ≤ e.size → Bytes → Bytes
  | 0, _, acc => acc
  | i + 1, h, acc => toBytesLoop e i (Nat.le_of_succ_le h) (e[i].toNat :: acc)

/-- `toBytes` as the loop. -/
def toBytesFast (e : Elem) : Bytes := toBytesLoop e e.size (Nat.le_refl _) []

/-- **`toBytesLoop_eq`.** *What it says:* the loop from index `i` puts the leading `i` bytes before the
accumulator. *What it assumes:* nothing. *Why it matters:* `toBytes_eq_fast` (#143). -/
theorem toBytesLoop_eq (e : Elem) (i : Nat) (h : i ≤ e.size) (acc : Bytes) :
    toBytesLoop e i h acc = (toBytes e).take i ++ acc := by
  induction i generalizing acc with
  | zero => simp [toBytesLoop]
  | succ i ih =>
    rw [toBytesLoop, ih]
    have hi : i < (toBytes e).length := by simp [toBytes]; omega
    rw [List.take_add_one, List.getElem?_eq_getElem hi]
    simp [toBytes, ByteArray.getElem_eq_getElem_data]

/-- `@[csimp]` (#143): the compiler reads an element's bytes by the loop. -/
@[csimp] theorem toBytes_eq_fast : @toBytes = @toBytesFast := by
  funext e
  rw [toBytesFast, toBytesLoop_eq, List.append_nil, List.take_of_length_le]
  simp [toBytes]

/-- **`data_pushList`.** *What it says:* pushing a list appends its bytes, each modulo 256. *What it assumes:*
nothing. *Why it matters:* `ofBytes_eq_fast` (#143). -/
theorem data_pushList (a : Elem) (bs : Bytes) : (pushList a bs).data = a.data ++ (bs.map Nat.toUInt8).toArray := by
  induction bs generalizing a with
  | nil => simp [pushList]
  | cons b bs ih => rw [pushList, ih, ByteArray.data_push]; simp

/-- `ofBytes` as the loop: one array of the list's length, the bytes pushed in place. -/
def ofBytesFast (bs : Bytes) : Elem := pushList (ByteArray.emptyWithCapacity bs.length) bs

/-- `@[csimp]` (#143): the compiler packs a list by the loop. -/
@[csimp] theorem ofBytes_eq_fast : @ofBytes = @ofBytesFast := by
  funext bs
  apply ByteArray.ext
  rw [ofBytesFast, data_pushList, ofBytes, List.data_toByteArray]
  simp only [ByteArray.emptyWithCapacity]
  exact Array.empty_append.symm

/-- `Bytes.valid` as a test: every value below 256. -/
def validB (bs : Bytes) : Bool := bs.all (· < 256)

/-- **`validB_iff`.** *What it says:* the test answers `Bytes.valid`. *What it assumes:* nothing. *Why it
matters:* the machine's guard on a script and a stack handed in from outside (#143). -/
theorem validB_iff (bs : Bytes) : validB bs = true ↔ Bytes.valid bs := by
  simp [validB, Bytes.valid]

/-- **`toBytes_valid`.** *What it says:* an element's bytes are bytes. *What it assumes:* nothing. *Why it
matters:* the state carries `Bytes.valid` by its type (#143). -/
theorem toBytes_valid (e : Elem) : Bytes.valid (toBytes e) := by
  intro b hb
  simp only [toBytes, List.mem_map] at hb
  obtain ⟨u, _, rfl⟩ := hb
  exact u.toNat_lt

/-- **`toBytes_ofBytes`.** *What it says:* the element of a valid byte list reads back as that list. *What it
assumes:* `Bytes.valid bs`. *Why it matters:* every element the implementation builds from a list (#143). -/
theorem toBytes_ofBytes (bs : Bytes) (h : Bytes.valid bs) : toBytes (ofBytes bs) = bs := by
  simp only [toBytes, ofBytes, List.data_toByteArray, List.toList_toArray, List.map_map]
  conv_rhs => rw [← List.map_id bs]
  apply List.map_congr_left
  intro b hb
  simp [Nat.toUInt8, Nat.mod_eq_of_lt (h b hb)]

/-- **`ofBytes_toBytes`.** *What it says:* an element read as a list and back is itself. *What it assumes:*
nothing. *Why it matters:* `IState.ofState_abs` (#143). -/
theorem ofBytes_toBytes (e : Elem) : ofBytes (toBytes e) = e := by
  apply ByteArray.ext
  simp only [ofBytes, toBytes, List.data_toByteArray, List.map_map]
  have : (Nat.toUInt8 ∘ UInt8.toNat) = id := by funext u; simp [Nat.toUInt8]
  rw [this, List.map_id]

/-- **`toBytes_inj`.** *What it says:* two elements with the same bytes are the same. *What it assumes:*
nothing. *Why it matters:* `OP_EQUAL` compares the packed arrays (#143). -/
theorem toBytes_inj {a b : Elem} : toBytes a = toBytes b ↔ a = b := by
  constructor
  · intro h
    rw [← ofBytes_toBytes a, h, ofBytes_toBytes]
  · rintro rfl; rfl

/-! ## Size, emptiness, equality -/

/-- **`length_toBytes`.** *What it says:* the list's length is the element's size. *What it assumes:* nothing.
*Why it matters:* every memory charge and every length test in one read (#143). -/
@[simp] theorem length_toBytes (e : Elem) : (toBytes e).length = e.size := by
  simp [toBytes]

/-- The empty element. -/
def empty : Elem := ByteArray.empty

/-- **`toBytes_empty`.** *What it says:* the empty element is the empty list. *What it assumes:* nothing. *Why
it matters:* `vchFalse`, and `topAt`'s value past the depth (#143). -/
@[simp] theorem toBytes_empty : toBytes empty = [] := rfl

/-- **`isEmpty_toBytes`.** *What it says:* the list is empty exactly when the element's size is zero. *What it
assumes:* nothing. *Why it matters:* the signature checks' empty-signature tests (#143). -/
theorem isEmpty_toBytes (e : Elem) : (toBytes e).isEmpty = (e.size == 0) := by
  rw [← length_toBytes]
  cases toBytes e <;> rfl

/-- **`decide_toBytes_eq`.** *What it says:* comparing two elements' lists is comparing the elements (the
runtime's `lean_sarray_dec_eq`, a `memcmp`). *What it assumes:* nothing. *Why it matters:* `OP_EQUAL` (#143). -/
theorem decide_toBytes_eq (a b : Elem) : decide (toBytes a = toBytes b) = decide (a = b) := by
  simp only [toBytes_inj]

/-- The first byte, if any. -/
def head? (e : Elem) : Option Nat := if h : 0 < e.size then some e[0].toNat else none

/-- **`head?_toBytes`.** *What it says:* the list's first byte is the element's. *What it assumes:* nothing.
*Why it matters:* `OP_IF`'s minimal-if test (#143). -/
theorem head?_toBytes (e : Elem) : (toBytes e).head? = head? e := by
  unfold head? toBytes
  rcases e with ⟨⟨l⟩⟩
  cases l with
  | nil => simp [ByteArray.size]
  | cons a l =>
    simp only [List.map_cons, List.head?_cons]
    rw [dite_eq_left_of_eq_true (by simp [ByteArray.size])]
    rfl

/-! ## Append, take, drop -/

/-- **`toBytes_append`.** *What it says:* appending elements is appending their lists. *What it assumes:*
nothing. *Why it matters:* `OP_CAT` in one copy (#143). -/
@[simp] theorem toBytes_append (a b : Elem) : toBytes (a ++ b) = toBytes a ++ toBytes b := by
  simp [toBytes]

/-- The leading `n` bytes. -/
def take (e : Elem) (n : Nat) : Elem := e.extract 0 n

/-- Every byte after the leading `n`. -/
def drop (e : Elem) (n : Nat) : Elem := e.extract n e.size

/-- **`toBytes_take`.** *What it says:* an element's leading `n` bytes are its list's. *What it assumes:* nothing.
*Why it matters:* `OP_SPLIT`, `OP_LEFT`, `OP_SUBSTR` (#143). -/
@[simp] theorem toBytes_take (e : Elem) (n : Nat) : toBytes (take e n) = (toBytes e).take n := by
  simp [take, toBytes, ByteArray.data_extract, Array.toList_extract, List.extract_eq_take_drop, List.map_take]

/-- **`toBytes_drop`.** *What it says:* an element's bytes after the first `n` are its list's. *What it assumes:*
nothing. *Why it matters:* `OP_SPLIT`, `OP_RIGHT`, `OP_SUBSTR` (#143). -/
@[simp] theorem toBytes_drop (e : Elem) (n : Nat) : toBytes (drop e n) = (toBytes e).drop n := by
  simp only [drop, toBytes, ByteArray.data_extract, Array.toList_extract, List.extract_eq_take_drop,
    List.map_take, List.map_drop]
  rw [List.take_of_length_le]
  simp

/-! ## Elements built from short lists -/

/-- The script number of `v` as an element (`encode`). -/
def encode (v : Int) : Elem := ofBytes (Numbers.encode v)

/-- **`toBytes_encode`.** *What it says:* the element is the encoding. *What it assumes:* nothing. *Why it
matters:* every arithmetic result, count and small-number push (#143). -/
@[simp] theorem toBytes_encode (v : Int) : toBytes (encode v) = Numbers.encode v :=
  toBytes_ofBytes _ (encode_valid v)

/-- `vchTrue`, `[0x01]`, as an element. -/
def vchTrue : Elem := ofBytes Ops.Bitwise.vchTrue

/-- **`toBytes_vchTrue`.** *What it says:* the element is `[1]`. *What it assumes:* nothing. *Why it matters:*
`OP_EQUAL` and the signature checks' results (#143). -/
@[simp] theorem toBytes_vchTrue : toBytes vchTrue = Ops.Bitwise.vchTrue := rfl

/-- **`toBytes_vchFalse`.** *What it says:* `vchFalse` is the empty element. *What it assumes:* nothing. *Why
it matters:* `OP_EQUAL` and the signature checks' results (#143). -/
@[simp] theorem toBytes_vchFalse : toBytes empty = Ops.Bitwise.vchFalse := rfl

/-- **`versionLE_valid`.** *What it says:* the version's four bytes are bytes. *What it assumes:* nothing.
*Why it matters:* `OP_VER` (#143). -/
theorem versionLE_valid (v : Int) : Bytes.valid (versionLE v) := by
  intro b hb
  simp only [versionLE, List.mem_cons, List.not_mem_nil, or_false] at hb
  rcases hb with rfl | rfl | rfl | rfl <;> exact Nat.mod_lt _ (by norm_num)

/-- The version's four little-endian bytes as an element. -/
def versionLE (v : Int) : Elem := ofBytes (Machine.versionLE v)

/-- **`toBytes_versionLE`.** *What it says:* the element is the version's bytes. *What it assumes:* nothing.
*Why it matters:* `OP_VER` (#143). -/
@[simp] theorem toBytes_versionLE (v : Int) : toBytes (versionLE v) = Machine.versionLE v :=
  toBytes_ofBytes _ (versionLE_valid v)

/-! ## The number readers: the length bound read from the size, before any list is built -/

/-- `Ops.Arith.readOperand` on an element: the length bound first, from the size (`script_num.cpp:62–65`). -/
def readOperand (env : Env) (e : Elem) : Except ScriptError Int :=
  if env.params.limits.maxScriptNumLength < e.size then .error .scriptnumOverflow
  else Ops.Arith.readOperand env (toBytes e)

/-- **`readOperand_eq`.** *What it says:* the element's reader answers what the spec's reader answers on its
list. *What it assumes:* nothing. *Why it matters:* an operand too long to be a number is refused without its
list being built (#143). -/
theorem readOperand_eq (env : Env) (e : Elem) : readOperand env e = Ops.Arith.readOperand env (toBytes e) := by
  unfold readOperand
  split
  · rename_i h; unfold Ops.Arith.readOperand; rw [length_toBytes]; simp [h]
  · rfl

/-- `Ops.Expansion.readInt64Operand` on an element: the length bound first, from the size. -/
def readInt64Operand (env : Env) (e : Elem) : Except ScriptError Int :=
  if env.params.limits.maxScriptNumLength < e.size then .error .scriptnumOverflow
  else Ops.Expansion.readInt64Operand env (toBytes e)

/-- **`readInt64Operand_eq`.** *What it says:* the element's reader answers what the spec's reader answers on its
list. *What it assumes:* nothing. *Why it matters:* `OP_SUBSTR`, `OP_LEFT`, `OP_RIGHT` (#143). -/
theorem readInt64Operand_eq (env : Env) (e : Elem) :
    readInt64Operand env e = Ops.Expansion.readInt64Operand env (toBytes e) := by
  unfold readInt64Operand
  split
  · rename_i h; unfold Ops.Expansion.readInt64Operand readNumInt64; rw [length_toBytes]; simp [h]
  · rfl

/-- `Ops.Crypto.readCount` on an element: the length bound first, from the size. -/
def readCount (env : Env) (e : Elem) : Except ScriptError Int :=
  if 4 < e.size then .error .scriptnumOverflow else Ops.Crypto.readCount env (toBytes e)

/-- **`readCount_eq`.** *What it says:* the element's reader answers what the spec's reader answers on its list.
*What it assumes:* nothing. *Why it matters:* `OP_CHECKMULTISIG`'s counts (#143). -/
theorem readCount_eq (env : Env) (e : Elem) : readCount env e = Ops.Crypto.readCount env (toBytes e) := by
  unfold readCount
  split
  · rename_i h; unfold Ops.Crypto.readCount; rw [length_toBytes]; simp [h]
  · rfl

/-- `Numbers.readNum` on an element: the length bound first, from the size. -/
def readNum (e : Elem) (requireMinimal : Bool) (maxLen : Nat) : Except NumError Int :=
  if maxLen < e.size then .error .overflow else Numbers.readNum (toBytes e) requireMinimal maxLen

/-- **`readNum_eq`.** *What it says:* the element's reader answers what the spec's reader answers on its list.
*What it assumes:* nothing. *Why it matters:* `OP_CHECKLOCKTIMEVERIFY`, `OP_CHECKSEQUENCEVERIFY` (#143). -/
theorem readNum_eq (e : Elem) (requireMinimal : Bool) (maxLen : Nat) :
    readNum e requireMinimal maxLen = Numbers.readNum (toBytes e) requireMinimal maxLen := by
  unfold readNum
  split
  · rename_i h; unfold Numbers.readNum; rw [length_toBytes]; simp [h]
  · rfl

/-- `castToBool` on an element (`interpreter.cpp:119–130`). -/
def castToBool (e : Elem) : Bool := Numbers.castToBool (toBytes e)

/-- **`castToBool_eq`.** *What it says:* the element's truth is its list's. *What it assumes:* nothing. *Why it
matters:* `OP_IF`, `OP_VERIFY`, `OP_IFDUP`, `OP_NUMEQUALVERIFY` (#143). -/
theorem castToBool_eq (e : Elem) : castToBool e = Numbers.castToBool (toBytes e) := rfl

/-! ## `OP_NUM2BIN` and `OP_BIN2NUM`: the minimal encoding and the pad, built in place -/

/-- The minimal encoding of an element's value (`minimallyEncode`). -/
def minimallyEncode (e : Elem) : Elem := ofBytes (Numbers.minimallyEncode (toBytes e))

/-- **`toBytes_minimallyEncode`.** *What it says:* the element is the minimal encoding of the list. *What it
assumes:* nothing. *Why it matters:* `OP_BIN2NUM` (#143). -/
@[simp] theorem toBytes_minimallyEncode (e : Elem) :
    toBytes (minimallyEncode e) = Numbers.minimallyEncode (toBytes e) :=
  toBytes_ofBytes _ (encode_valid _)

/-- `n` zero bytes pushed at the end, one `ByteArray.push` each: in place when the array is unshared, inside its
capacity when it was made with room. -/
def pushZeros : Elem → Nat → Elem
  | a, 0 => a
  | a, n + 1 => pushZeros (a.push 0) n

/-- **`toBytes_pushZeros`.** *What it says:* pushing `n` zeros appends `n` zeros to the list. *What it assumes:*
nothing. *Why it matters:* `OP_NUM2BIN`'s pad (#143). -/
theorem toBytes_pushZeros (a : Elem) (n : Nat) : toBytes (pushZeros a n) = toBytes a ++ List.replicate n 0 := by
  induction n generalizing a with
  | zero => simp [pushZeros]
  | succ n ih =>
    rw [pushZeros, ih]
    simp only [toBytes, ByteArray.data_push, Array.toList_push, List.map_append, List.append_assoc]
    rw [List.replicate_succ]
    rfl

/-- `num2binPad` (`OP_NUM2BIN`'s pad, `interpreter.cpp:1771–1777`, `padRight`, `limitedstack.cpp:60–71`) built in
one array of the width's capacity: the encoding with its top byte's sign bit cleared, the zeros, the sign byte. The
encoding is a short list (a minimal encoding); the zeros are written in place, never as a list. -/
def num2binPad (m : Bytes) (width : Nat) : Elem :=
  match m.reverse with
  | [] => (pushZeros (ByteArray.emptyWithCapacity width) (width - 1)).push 0
  | l :: r =>
    (pushZeros (pushList (ByteArray.emptyWithCapacity width) (l % 128 :: r).reverse) (width - m.length - 1)).push
      (if 128 ≤ l then 128 else 0)

/-- **`toBytes_num2binPad`.** *What it says:* the element is the spec's pad. *What it assumes:* `Bytes.valid m`.
*Why it matters:* `OP_NUM2BIN` to a width of two billion bytes holds two billion bytes, not two billion cons cells
(#142's record; #143). -/
theorem toBytes_num2binPad (m : Bytes) (width : Nat) (h : Bytes.valid m) :
    toBytes (num2binPad m width) = Numbers.num2binPad m width := by
  have hE : toBytes (ByteArray.emptyWithCapacity width) = [] := rfl
  unfold num2binPad Numbers.num2binPad
  split
  · rename_i hr
    simp only [toBytes, ByteArray.data_push] at *
    rw [Array.toList_push, List.map_append]
    have := toBytes_pushZeros (ByteArray.emptyWithCapacity width) (width - 1)
    simp only [toBytes] at this
    rw [this, hE, hr]
    simp
  · rename_i l r hr
    have hv : Bytes.valid (l % 128 :: r).reverse := by
      rw [valid_reverse, valid_cons]
      have hm : Bytes.valid m.reverse := (valid_reverse m).mpr h
      rw [hr, valid_cons] at hm
      exact ⟨by omega, hm.2⟩
    have hp := toBytes_pushZeros (pushList (ByteArray.emptyWithCapacity width) (l % 128 :: r).reverse)
      (width - m.length - 1)
    rw [toBytes_pushList _ _ hv, hE, List.nil_append] at hp
    simp only [toBytes, ByteArray.data_push, Array.toList_push, List.map_append] at hp ⊢
    rw [hp, hr]
    split <;> simp <;> omega

/-- `OP_NUM2BIN`'s padding step (`num2bin`, `1755–1778`) on the minimal encoding `m` of the operand, computed
once by the opcode: the impossible encoding (`none`), the equal case, or the pad built in place. -/
def num2binM (m : Bytes) (width : Nat) : Option Elem :=
  if width < m.length then none
  else if m.length = width then some (ofBytes m)
  else some (num2binPad m width)

/-- **`num2binM_map`.** *What it says:* the padding step on the operand's minimal encoding answers what the
spec's answers on the operand. *What it assumes:* nothing. *Why it matters:* `OP_NUM2BIN` (#143). -/
theorem num2binM_map (bs : Bytes) (width : Nat) :
    (num2binM (Numbers.minimallyEncode bs) width).map toBytes = Numbers.num2bin bs width := by
  have hv : Bytes.valid (Numbers.minimallyEncode bs) := encode_valid _
  unfold num2binM Numbers.num2bin
  split
  · rfl
  · split
    · simp [toBytes_ofBytes _ hv]
    · simp [toBytes_num2binPad _ _ hv]

/-! ## The bitwise family -/

/-- `OP_AND`/`OP_OR`/`OP_XOR`'s byte-by-byte combination on elements. -/
def zipWith (f : Nat → Nat → Nat) (a b : Elem) : Elem := ofBytes (List.zipWith f (toBytes a) (toBytes b))

/-- **`toBytes_zipWith`.** *What it says:* the combination is the spec's on the two lists. *What it assumes:*
`f` keeps two bytes a byte. *Why it matters:* `OP_AND`, `OP_OR`, `OP_XOR` (#143). -/
theorem toBytes_zipWith (f : Nat → Nat → Nat) (hf : ∀ x y, x < 256 → y < 256 → f x y < 256) (a b : Elem) :
    toBytes (zipWith f a b) = List.zipWith f (toBytes a) (toBytes b) := by
  apply toBytes_ofBytes
  intro z hz
  obtain ⟨i, hi, rfl⟩ := List.getElem_of_mem hz
  rw [List.getElem_zipWith]
  exact hf _ _ (toBytes_valid a _ (List.getElem_mem _)) (toBytes_valid b _ (List.getElem_mem _))

/-- **`bitwise_byte`.** *What it says:* `&&&`, `|||` and `^^^` keep two bytes a byte, as the op's selection of
them does. *What it assumes:* nothing. *Why it matters:* `toBytes_zipWith`'s side condition for `OP_AND`/`OP_OR`/
`OP_XOR` (#143). -/
theorem bitwise_byte (op : Nat) :
    ∀ x y, x < 256 → y < 256 →
      (if op = Op.OP_AND then (· &&& ·) else if op = Op.OP_OR then (· ||| ·) else (· ^^^ ·) :
        Nat → Nat → Nat) x y < 256 := by
  intro x y hx hy
  have hx' : x < 2 ^ 8 := hx
  have hy' : y < 2 ^ 8 := hy
  split
  · exact Nat.and_lt_two_pow x hy'
  · split
    · exact Nat.or_lt_two_pow hx' hy'
    · exact Nat.xor_lt_two_pow hx' hy'

/-- `OP_INVERT`'s bytes (`255 − b` each). -/
def invert (e : Elem) : Elem := ofBytes ((toBytes e).map (255 - ·))

/-- **`toBytes_invert`.** *What it says:* the inverted element is the spec's map on its list. *What it assumes:*
nothing. *Why it matters:* `OP_INVERT` (#143). -/
@[simp] theorem toBytes_invert (e : Elem) : toBytes (invert e) = (toBytes e).map (255 - ·) := by
  apply toBytes_ofBytes
  intro z hz
  simp only [List.mem_map] at hz
  obtain ⟨b, _, rfl⟩ := hz
  omega

/-- `n` zero bytes, written in place. -/
def zeros (n : Nat) : Elem := pushZeros (ByteArray.emptyWithCapacity n) n

/-- **`toBytes_zeros`.** *What it says:* the element is `n` zeros. *What it assumes:* nothing. *Why it matters:*
`OP_LSHIFT`/`OP_RSHIFT` by the width or more (#143). -/
@[simp] theorem toBytes_zeros (n : Nat) : toBytes (zeros n) = List.replicate n 0 := by
  unfold zeros
  rw [toBytes_pushZeros]
  rfl

/-- **`or_byte`.** *What it says:* two bytes or'd are a byte. *What it assumes:* both below 256. *Why it
matters:* the shifts' bytes (#143). -/
theorem or_byte (x y : Nat) (hx : x < 256) (hy : y < 256) : x ||| y < 256 :=
  Nat.or_lt_two_pow (n := 8) hx hy

/-- **`and_byte`.** *What it says:* anything and'd with a byte is a byte. *What it assumes:* `y < 256`. *Why it
matters:* the shifts' bytes (#143). -/
theorem and_byte (x y : Nat) (hy : y < 256) : x &&& y < 256 := Nat.and_lt_two_pow (n := 8) x hy

/-- **`rmask_lt`.** *What it says:* `make_rshift_mask` is a byte. *What it assumes:* nothing. *Why it matters:*
the shifts' bytes (#143). -/
theorem rmask_lt (n : Nat) : Ops.Bitwise.rmask n < 256 := by
  unfold Ops.Bitwise.rmask
  rcases n with _ | _ | _ | _ | _ | _ | _ | _ | n <;> simp

/-- **`lmask_lt`.** *What it says:* `make_lshift_mask` is a byte. *What it assumes:* nothing. *Why it matters:*
the shifts' bytes (#143). -/
theorem lmask_lt (n : Nat) : Ops.Bitwise.lmask n < 256 := by
  unfold Ops.Bitwise.lmask
  rcases n with _ | _ | _ | _ | _ | _ | _ | _ | n <;> simp

/-- **`rshift_valid`.** *What it says:* `RShift`'s bytes are bytes. *What it assumes:* nothing. *Why it matters:*
`OP_RSHIFT` (#143). -/
theorem rshift_valid (x : Bytes) (n : Nat) : Bytes.valid (Ops.Bitwise.rshift x n) := by
  intro z hz
  simp only [Ops.Bitwise.rshift, List.mem_map, List.mem_range] at hz
  obtain ⟨k, _, rfl⟩ := hz
  apply or_byte
  · split
    · exact Nat.lt_of_le_of_lt (Nat.shiftRight_le _ _) (and_byte _ _ (rmask_lt _))
    · omega
  · split
    · exact Nat.mod_lt _ (by norm_num)
    · omega

/-- **`lshift_valid`.** *What it says:* `LShift`'s bytes are bytes. *What it assumes:* nothing. *Why it matters:*
`OP_LSHIFT` (#143). -/
theorem lshift_valid (x : Bytes) (n : Nat) : Bytes.valid (Ops.Bitwise.lshift x n) := by
  intro z hz
  simp only [Ops.Bitwise.lshift, List.mem_map, List.mem_range] at hz
  obtain ⟨k, _, rfl⟩ := hz
  apply or_byte
  · split
    · exact Nat.mod_lt _ (by norm_num)
    · omega
  · split
    · exact Nat.lt_of_le_of_lt (Nat.shiftRight_le _ _) (and_byte _ _ (by have := lmask_lt (n % 8); omega))
    · omega

/-- `RShift` on an element. -/
def rshift (e : Elem) (n : Nat) : Elem := ofBytes (Ops.Bitwise.rshift (toBytes e) n)

/-- **`toBytes_rshift`.** *What it says:* the element is the spec's `RShift` of its list. *What it assumes:*
nothing. *Why it matters:* `OP_RSHIFT` (#143). -/
@[simp] theorem toBytes_rshift (e : Elem) (n : Nat) : toBytes (rshift e n) = Ops.Bitwise.rshift (toBytes e) n :=
  toBytes_ofBytes _ (rshift_valid _ _)

/-- `LShift` on an element. -/
def lshift (e : Elem) (n : Nat) : Elem := ofBytes (Ops.Bitwise.lshift (toBytes e) n)

/-- **`toBytes_lshift`.** *What it says:* the element is the spec's `LShift` of its list. *What it assumes:*
nothing. *Why it matters:* `OP_LSHIFT` (#143). -/
@[simp] theorem toBytes_lshift (e : Elem) (n : Nat) : toBytes (lshift e n) = Ops.Bitwise.lshift (toBytes e) n :=
  toBytes_ofBytes _ (lshift_valid _ _)

/-! ## The hash inputs -/

/-- **`flatten_wordBytes_valid`.** *What it says:* words written as big-endian bytes are bytes. *What it
assumes:* nothing. *Why it matters:* SHA-256 and SHA-1 digests (#143). -/
theorem flatten_wordBytes_valid (ws : List UInt32) : Bytes.valid (ws.map wordBytes).flatten := by
  intro z hz
  simp only [List.mem_flatten, List.mem_map] at hz
  obtain ⟨_, ⟨w, _, rfl⟩, hz⟩ := hz
  simp only [wordBytes, List.mem_cons, List.not_mem_nil, or_false] at hz
  rcases hz with rfl | rfl | rfl | rfl <;> exact Nat.mod_lt _ (by norm_num)

/-- **`flatten_wordBytesLE_valid`.** *What it says:* words written as little-endian bytes are bytes. *What it
assumes:* nothing. *Why it matters:* RIPEMD-160 digests (#143). -/
theorem flatten_wordBytesLE_valid (ws : List UInt32) : Bytes.valid (ws.map Ripemd160.wordBytesLE).flatten := by
  intro z hz
  simp only [List.mem_flatten, List.mem_map] at hz
  obtain ⟨_, ⟨w, _, rfl⟩, hz⟩ := hz
  simp only [Ripemd160.wordBytesLE, List.mem_cons, List.not_mem_nil, or_false] at hz
  rcases hz with rfl | rfl | rfl | rfl <;> exact Nat.mod_lt _ (by norm_num)

/-- **`sha256_valid`.** *What it says:* a SHA-256 digest is bytes. *What it assumes:* nothing. *Why it matters:*
`OP_SHA256`, `OP_HASH160`, `OP_HASH256` (#143). -/
theorem sha256_valid (msg : Bytes) : Bytes.valid (sha256 msg) := flatten_wordBytes_valid _

/-- **`sha1_valid`.** *What it says:* a SHA-1 digest is bytes. *What it assumes:* nothing. *Why it matters:*
`OP_SHA1` (#143). -/
theorem sha1_valid (msg : Bytes) : Bytes.valid (sha1 msg) := flatten_wordBytes_valid _

/-- **`ripemd160_valid`.** *What it says:* a RIPEMD-160 digest is bytes. *What it assumes:* nothing. *Why it
matters:* `OP_RIPEMD160`, `OP_HASH160` (#143). -/
theorem ripemd160_valid (msg : Bytes) : Bytes.valid (ripemd160 msg) := flatten_wordBytesLE_valid _

/-- The hash opcodes' digest of an element (`interpreter.cpp:1402–1443`), read from its list. -/
def hashOp (op : Nat) (e : Elem) : Elem :=
  let x := toBytes e
  ofBytes (if op = Op.OP_RIPEMD160 then ripemd160 x
    else if op = Op.OP_SHA1 then sha1 x
    else if op = Op.OP_SHA256 then sha256 x
    else if op = Op.OP_HASH160 then hash160 x
    else hash256 x)

/-- **`toBytes_hashOp`.** *What it says:* the element is the spec's digest of its list. *What it assumes:*
nothing. *Why it matters:* the hash opcodes (#143). -/
theorem toBytes_hashOp (op : Nat) (e : Elem) :
    toBytes (hashOp op e) =
      (let x := toBytes e
       if op = Op.OP_RIPEMD160 then ripemd160 x
       else if op = Op.OP_SHA1 then sha1 x
       else if op = Op.OP_SHA256 then sha256 x
       else if op = Op.OP_HASH160 then hash160 x
       else hash256 x) := by
  apply toBytes_ofBytes
  split
  · exact ripemd160_valid _
  · split
    · exact sha1_valid _
    · split
      · exact sha256_valid _
      · split
        · exact ripemd160_valid _
        · exact sha256_valid _

end Elem

end BsvScript.Impl
