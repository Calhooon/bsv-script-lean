import Batteries.Classes.Order
import Batteries.Tactic.Init
import Mathlib.Algebra.BigOperators.Group.List.Defs
import Mathlib.Algebra.CharP.Defs
import Mathlib.Algebra.CharZero.Defs
import Mathlib.Algebra.Divisibility.Basic
import Mathlib.Algebra.Group.Basic
import Mathlib.Algebra.Group.Defs
import Mathlib.Algebra.Group.DivInvMonoid
import Mathlib.Algebra.Group.Int.Defs
import Mathlib.Algebra.Group.Monoid
import Mathlib.Algebra.Group.Nat.Defs
import Mathlib.Algebra.Group.Semigroup
import Mathlib.Algebra.GroupWithZero.Defs
import Mathlib.Algebra.GroupWithZero.Nat
import Mathlib.Algebra.NeZero
import Mathlib.Algebra.Order.Group.Nat
import Mathlib.Algebra.Order.Group.Unbundled.Abs
import Mathlib.Algebra.Order.GroupWithZero.Basic
import Mathlib.Algebra.Order.GroupWithZero.Canonical
import Mathlib.Algebra.Order.GroupWithZero.Defs
import Mathlib.Algebra.Order.IsBotOne
import Mathlib.Algebra.Order.Monoid.Canonical.Defs
import Mathlib.Algebra.Order.Monoid.Defs
import Mathlib.Algebra.Order.Monoid.Unbundled.Basic
import Mathlib.Algebra.Order.Monoid.Unbundled.Defs
import Mathlib.Algebra.Order.Ring.Defs
import Mathlib.Algebra.Order.Ring.Int
import Mathlib.Algebra.Order.Ring.Nat
import Mathlib.Algebra.Order.Ring.Star
import Mathlib.Algebra.Order.Star.Basic
import Mathlib.Algebra.Order.Sub.Basic
import Mathlib.Algebra.Order.Sub.Defs
import Mathlib.Algebra.Order.SuccPred
import Mathlib.Algebra.Order.ZeroLEOne
import Mathlib.Algebra.Ring.Defs
import Mathlib.Algebra.Ring.Int.Defs
import Mathlib.Algebra.Ring.Nat
import Mathlib.Algebra.Star.Basic
import Mathlib.Basic.IsEmpty.Basic
import Mathlib.Basic.IsEmpty.Defs
import Mathlib.Data.Int.Cast.Basic
import Mathlib.Data.Int.Cast.Defs
import Mathlib.Data.Int.Order.Basic
import Mathlib.Data.Int.Star
import Mathlib.Data.Nat.Basic
import Mathlib.Data.Nat.Cast.Defs
import Mathlib.Data.Nat.Cast.Order.Basic
import Mathlib.Data.Nat.Cast.Order.Ring
import Mathlib.Data.Nat.Init
import Mathlib.Data.Nat.SuccPred
import Mathlib.Data.Option.Basic
import Mathlib.Logic.Function.Defs
import Mathlib.Order.Basic
import Mathlib.Order.Defs.LinearOrder
import Mathlib.Order.Defs.PartialOrder
import Mathlib.Order.Lattice
import Mathlib.Order.Lattice.Nat
import Mathlib.Order.Nat
import Mathlib.Order.RelClasses
import Mathlib.Tactic.Conv
import Mathlib.Tactic.Linter.Style
import Mathlib.Tactic.NormNum.Basic
import Mathlib.Tactic.NormNum.Core
import Mathlib.Tactic.NormNum.Ineq
import Mathlib.Tactic.NormNum.Pow
import Mathlib.Tactic.NormNum.Result
import Mathlib.Tactic.Positivity.Core
import Mathlib.Tactic.Positivity.Basic
import Mathlib.Tactic.Ring.Basic
import Mathlib.Tactic.Ring.Common
import Mathlib.Tactic.Ring.RingNF
import Mathlib.Tactic.SplitIfs
import Mathlib.Tactic.Tauto
/-!
# BsvScript.Numbers

Script numbers (#7): the little-endian sign-magnitude encoding, minimal encoding,
the acceptance rule, `OP_BIN2NUM` and `OP_NUM2BIN`, truthiness. Every definition
is transcribed from bitcoin-sv v1.2.3 at `6504a3af` (`docs/PROVENANCE.md`); the
theorems are the canonicality properties `docs/DESIGN.md` §1.2 names.

**The byte model.** A byte is a natural number below 256 (`Byte := Nat`, with
`Bytes.valid` where a lemma needs the bound). The reference's bit operations on
a byte reduce to arithmetic: "bit 7 set" is `128 ≤ b`, `b & 0x7f` is `b % 128`,
and `b | 0x80` on a byte below 128 is `b + 128`. The evaluator's boundary
converts `UInt8` to and from this model (a bijection on 0..255, #14).

**The number model.** The integers `ℤ`. The reference holds an `int64` or a
`bsv::bint` (`script_num.h:104`), the alternative chosen at construction by the
`big_int` argument (`script_num.cpp:72–90`), never by the magnitude, and never
promoted afterwards: the arithmetic operators assert that both operands hold the
same alternative (`+=`, `-=`, `*=` at `script_num.cpp:147`, `script_num.cpp:177`, `script_num.cpp:207`). Every arithmetic
opcode constructs with `big_int = utxo_after_genesis` (`interpreter.cpp:1235`,
`1300–1301`, `1386–1390`), so post-Genesis its values are unbounded integers and
the only bound is the encoded length (`MaxScriptNumLength`, `docs/PARAMETERS.md`
§1). The `int64` path (`big_int` false, the default, `script_num.h:60–63`) is
every number read of a pre-Genesis coin (length ≤ 4, or 5 for CLTV/CSV,
`interpreter.cpp:546`, `577`), `OP_CHECKMULTISIG`'s two counts in every era
(`1523–1526`, `1550–1553`, length ≤ 4) and, post-Chronicle, the
`OP_SUBSTR`/`OP_LEFT`/`OP_RIGHT` operands (`622`, `624`, `655`, `680`, at
`MaxScriptNumLength`). Its fixed-width overflow check
([SRC] `6504a3af`, `int_serialization.h:80–114`) is unreachable at a length
bound of at most 8 and reachable at the `OP_SUBSTR` family's reads (below).
-/

namespace BsvScript.Numbers

/-- A byte list. A byte is a natural number below 256 (`Bytes.valid`); the byte
type is `Nat` itself (an abbreviation would hide the arithmetic from `omega`). -/
abbrev Bytes := List Nat

/-- Every byte is below 256. -/
def Bytes.valid (bs : Bytes) : Prop := ∀ b ∈ bs, b < 256

/-! ## Encoding (`int_serialization.h:23–59`, `serialize`)

The top byte is where the sign lives, so the definitions work on the reversed
list (top byte first) and reverse back; a byte list `bs` and its reverse carry
the same information, and the property check runs the executable on the
forward lists. -/

/-- The little-endian bytes of a magnitude, with no trailing zero byte
(`serialize`'s loop, `int_serialization.h:31–36`, before the sign handling): `magBytesFuel fuel m`
with `fuel ≥ m` is `magBytes m`. Structural recursion on the fuel so that
`decide` can evaluate it. -/
def magBytesFuel : Nat → Nat → Bytes
  | 0, _ => []
  | fuel + 1, m => if m = 0 then [] else (m % 256) :: magBytesFuel fuel (m / 256)

/-- The little-endian bytes of a magnitude, minimal. -/
def magBytes (m : Nat) : Bytes := magBytesFuel m m

/-- The sign handling on the top byte (`serialize`, `int_serialization.h:39–55`), on the reversed list
(top byte first): if the top byte has bit 7 set, a new top byte `0x80`
(negative) or `0x00` is added; else bit 7 of the top byte is set when negative. -/
def signTopRev : Bytes → Bool → Bytes
  | [], _ => []
  | t :: rest, neg =>
    if 128 ≤ t then (if neg then 128 else 0) :: t :: rest
    else (if neg then t + 128 else t) :: rest

/-- `serialize` (`int_serialization.h:23–59`): zero is the empty vector (`:26–27`);
otherwise the magnitude's little-endian bytes with the sign on the top byte. The
reference's `getvch` (`script_num.cpp:465–483`) is this function on the value. -/
def encode (v : Int) : Bytes :=
  if v = 0 then [] else (signTopRev (magBytes v.natAbs).reverse (decide (v < 0))).reverse

/-! ## Decoding (`int_serialization.h:61–118`, `deserialize`) -/

/-- The big-endian value of a byte list (top byte first). -/
def beNat (bs : Bytes) : Nat := bs.foldl (fun acc b => acc * 256 + b) 0

/-- The magnitude and the sign, from the reversed list: the top byte's bit 7 is
the sign and its low seven bits are the top of the magnitude; every byte below
is taken whole (`deserialize`, `int_serialization.h:86–117`, which reads the same digits little-endian).
The empty list is `(0, false)`. -/
def decodeRev : Bytes → Nat × Bool
  | [] => (0, false)
  | t :: rest => (beNat (t % 128 :: rest), 128 ≤ t)

/-- `deserialize`: the value of a byte list. Never fails: negative zero (`0x80`,
or zeros ending in `0x80`) is `0`, a padded encoding is its value. -/
def decode (bs : Bytes) : Int :=
  let r := decodeRev bs.reverse
  if r.2 then -(r.1 : Int) else (r.1 : Int)

/-- The signed value of a magnitude and a sign, by pattern matching (the shape the
proofs case on; `decode_eq_signInt`). -/
def signInt : Nat × Bool → Int
  | (m, false) => (m : Int)
  | (m, true) => -(m : Int)

/-- `decode` restated by pattern matching: `signInt` of the reversed list's magnitude
and sign (the definition's `if` on the sign, as a match on the pair; the shape T3 and
T4 case on). -/
theorem decode_eq_signInt (bs : Bytes) : decode bs = signInt (decodeRev bs.reverse) := by
  unfold decode
  cases h : decodeRev bs.reverse with
  | mk m sgn => cases sgn <;> simp [signInt]

/-! ## Minimality (`int_serialization.h:120–152`, `IsMinimallyEncoded`) -/

/-- The structural part of `IsMinimallyEncoded` (`int_serialization.h:131–150`): the empty vector is
minimal; else the top byte with bit 7 cleared must be non-zero, unless there is
a byte below it with bit 7 set (the `±255` case, `0xff00`/`0xff80`). Stated on
the reversed list because only the top two bytes matter. -/
def minimalTail (bs : Bytes) : Bool :=
  match bs.reverse with
  | [] => true
  | [b] => b % 128 != 0
  | b :: a :: _ => b % 128 != 0 || 128 ≤ a

/-- `IsMinimallyEncoded(span, nMaxNumSize)` (`int_serialization.h:120–152`): the length bound (`int_serialization.h:124–127`)
and the structural condition. -/
def isMinimallyEncoded (bs : Bytes) (maxLen : Nat) : Bool :=
  bs.length ≤ maxLen && minimalTail bs

/-! ## `MinimallyEncode` (`int_serialization.h:154–208`) -/

/-- The zero bytes below the top byte are skipped (`MinimallyEncode`, `int_serialization.h:183–186`:
"for(i = size-1; i > 0; i--) if(data[i-1] != 0)"): the first non-zero byte and
what lies below it, top first. -/
def dropZeros : Bytes → Bytes
  | [] => []
  | 0 :: xs => dropZeros xs
  | x :: xs => x :: xs

/-- The reference's in-place algorithm, transcribed on the reversed list: with the
top byte `last` and the rest below it (`rest`, top first): `last` with bit 7 set
low bits non-zero → unchanged (`int_serialization.h:162–166`); one byte → empty (`int_serialization.h:170–174`); the byte
below with bit 7 set → unchanged (`int_serialization.h:177–180`); else drop the zero bytes below the
top, and at the first non-zero byte `c`: if `c` has bit 7 set keep it and put
`last` above it (`int_serialization.h:189–193`), else fold `last` into `c` (`int_serialization.h:195–198`); no non-zero
byte → empty (`int_serialization.h:205–207`). `last` is `0` or `0x80` on every path but the first. -/
def minimallyEncodeRef (bs : Bytes) : Bytes :=
  match bs.reverse with
  | [] => []
  | last :: rest =>
    if last % 128 != 0 then bs
    else match rest with
      | [] => []
      | r0 :: _ =>
        if 128 ≤ r0 then bs
        else match dropZeros rest with
          | [] => []
          | c :: more => if 128 ≤ c then (last :: c :: more).reverse else ((c + last) :: more).reverse

/-- The minimal encoding of the value: what `OP_BIN2NUM` (`interpreter.cpp:1780–1789`)
and `OP_NUM2BIN`'s first step (`1760`) compute. Defined as the canonical form;
`minimallyEncodeRef_eq` (T4, below) proves it equal on bytes (`Bytes.valid`) to the
reference's algorithm as transcribed (`minimallyEncodeRef`), and the property check
`lean/Test/NumbersCheck.lean` compares it with bsv-rs over `corpus/numbers/`. -/
def minimallyEncode (bs : Bytes) : Bytes := encode (decode bs)

/-! ## The acceptance rule (`script_num.cpp:53–91`, the byte constructor) -/

/-- The two failures of the byte constructor: the length bound (`script_num.cpp:62–65`,
`scriptnum_overflow_error` → `SCRIPT_ERR_SCRIPTNUM_OVERFLOW`, `interpreter.cpp:1807–1810`)
and the minimality check (`script_num.cpp:67–70`, `scriptnum_minencode_error` →
`SCRIPT_ERR_SCRIPTNUM_MINENCODE`, `interpreter.cpp:1811–1814`). -/
inductive NumError where
  | overflow
  | minencode
  deriving DecidableEq, Repr

/-- Reading a number from a stack element: the length bound first, then, under
`requireMinimal` (`docs/DESIGN.md` §5.3), minimality; then `deserialize`.
`maxLen` is `MaxScriptNumLength` (`docs/PARAMETERS.md` §1) or `5` for
CLTV/CSV (`interpreter.cpp:546`, `577`). -/
def readNum (bs : Bytes) (requireMinimal : Bool) (maxLen : Nat) : Except NumError Int :=
  if maxLen < bs.length then .error .overflow
  else if requireMinimal && !isMinimallyEncoded bs maxLen then .error .minencode
  else .ok (decode bs)

/-! ## Truthiness (`interpreter.cpp:119–130`, `CastToBool`) -/

/-- `CastToBool`: false iff every byte is zero, or every byte is zero except the
last which is `0x80` (negative zero). -/
def castToBool : Bytes → Bool
  | [] => false
  | [b] => b != 0 && b != 128
  | b :: bs => b != 0 || castToBool bs

/-! ## `OP_NUM2BIN` (`interpreter.cpp:1741–1779`) -/

/-- The padding of `OP_NUM2BIN` for a minimal encoding `m` shorter than the width
(`1765–1777`): clear the sign bit of the top byte, pad with zero bytes and put
the sign bit in the last byte (`padRight`, `limitedstack.cpp:60–71`). An empty
`m` (the value zero) pads to zero bytes with a zero sign byte. -/
def num2binPad (m : Bytes) (width : Nat) : Bytes :=
  match m.reverse with
  | [] => List.replicate (width - 1) 0 ++ [0]
  | l :: r => (l % 128 :: r).reverse ++ List.replicate (width - m.length - 1) 0 ++ [if 128 ≤ l then 128 else 0]

/-- The padding step of `OP_NUM2BIN` after the minimal encoding (`1755–1778`):
longer than the width → `SCRIPT_ERR_IMPOSSIBLE_ENCODING` (`none`); equal →
unchanged; shorter → `num2binPad`. The width's own checks (`n < 0`,
`n > INT32_MAX`, the pre-Genesis 520) are the opcode's, at #10. -/
def num2bin (bs : Bytes) (width : Nat) : Option Bytes :=
  if width < (minimallyEncode bs).length then none
  else if (minimallyEncode bs).length = width then some (minimallyEncode bs)
  else some (num2binPad (minimallyEncode bs) width)

/-! ## The fixed-width reader at v1.2.3

[SRC] bitcoin-sv v1.2.3, commit `6504a3af`, `int_serialization.h:61–118`:
empty reads zero; up to eight bytes use sign-magnitude; nine bytes require a
pure sign byte and a magnitude below 2^63, or exactly 2^63 with a negative sign;
longer operands return no value. `script_num.cpp:80–91` turns no value into
`scriptnum_overflow_error`, mapped by `interpreter.cpp:1807–1809` to
`SCRIPT_ERR_SCRIPTNUM_OVERFLOW`. This is a defined refusal.

The previous pin's reading is retained in a history module withheld from the
public edition at the maintainers' request (group `d8-node-team-discretion`).
-/

/-- The nine-byte case at `6504a3af`: a pure sign byte, then a representable
magnitude. [SRC] `int_serialization.h:83–117`. `beNat restRev` assembles the
eight disjoint byte positions of the OR loop (`int_serialization.h:86–92`); the range test is
`int_serialization.h:110–114` expressed on the unsigned magnitude, including the signed minimum. -/
def deserializeInt64Nine (last : Nat) (restRev : Bytes) : Option Int :=
  let m := beNat restRev
  if last % 128 ≠ 0 then none
  else if m < 2 ^ 63 ∨ (m = 2 ^ 63 ∧ 128 ≤ last) then
    some (if 128 ≤ last then -(m : Int) else (m : Int))
  else none

/-- `deserialize<int64_t>` at v1.2.3 `6504a3af`, [SRC]
`int_serialization.h:61–118`: at most eight bytes read as sign-magnitude;
nine use `deserializeInt64Nine`; ten and above refuse. On `Bytes.valid`
inputs the magnitude arithmetic is the source's bytewise OR. `none` means
overflow, a defined refusal. The previous pin's reading is retained in a history module withheld from the
public edition at the maintainers' request (group `d8-node-team-discretion`). -/
def deserializeInt64 (bs : Bytes) : Option Int :=
  if bs.length ≤ 8 then some (decode bs)
  else if bs.length = 9 then
    match bs.reverse with
    | [] => none
    | last :: restRev => deserializeInt64Nine last restRev
  else none

/-- The fixed-width constructor at `6504a3af`, [SRC] `script_num.cpp:53–91`:
width, then minimality, then conversion. A failed conversion throws overflow
(`script_num.cpp:84–87`), so the result contains a value or a defined error, without an
optional success. The previous pin's reading is retained in a history module withheld from the
public edition at the maintainers' request (group `d8-node-team-discretion`). -/
def readNumInt64 (bs : Bytes) (requireMinimal : Bool) (maxLen : Nat) : Except NumError Int :=
  if maxLen < bs.length then .error .overflow
  else if requireMinimal && !isMinimallyEncoded bs maxLen then .error .minencode
  else match deserializeInt64 bs with
    | none => .error .overflow
    | some v => .ok v

/-- `getint` (`script_num.cpp:396–422`): saturation to the `int` range, read at the
`OP_SUBSTR` family's sites (`623`, `625`, `656`, `681`). -/
def getint (v : Int) : Int :=
  if v > 2 ^ 31 - 1 then 2 ^ 31 - 1 else if v < -(2 ^ 31) then -(2 ^ 31) else v

/-! ## The theorems -/

/-- **Zero.** `encode 0 = []` (`serialize`, `int_serialization.h:26–27`). -/
theorem encode_zero : encode 0 = [] := by simp [encode]

/-- **The empty vector is zero.** -/
theorem decode_nil : decode [] = 0 := by simp [decode, decodeRev]

/-- **Negative zero decodes to zero** (`deserialize` never rejects; `0x80` is
`-0 = 0`). -/
theorem decode_negzero : decode [128] = 0 := by decide

/-- **Negative zero is not minimal** (`IsMinimallyEncoded`, `int_serialization.h:134–137`
and, for a single byte, `int_serialization.h:144–146`: "this test also rejects the negative-zero
encoding, 0x80"). -/
theorem negzero_not_minimal : minimalTail [128] = false := by decide

/-- `Bytes.valid` on a cons: the head is below 256 and the tail is valid (the rewrite
the validity proofs below use). -/
theorem valid_cons (a : Nat) (l : Bytes) : Bytes.valid (a :: l) ↔ a < 256 ∧ Bytes.valid l := by
  simp [Bytes.valid]

/-- The empty list is valid: it has no entry to bound. -/
theorem valid_nil : Bytes.valid [] := by simp [Bytes.valid]

/-- Validity ignores order: a list is valid exactly when its reverse is (the
definitions work top byte first, the statements on the forward list). -/
theorem valid_reverse (l : Bytes) : Bytes.valid l.reverse ↔ Bytes.valid l := by
  simp [Bytes.valid]

/-- Every magnitude byte is a byte: `magBytesFuel` emits only remainders modulo 256,
at any fuel and any value. -/
theorem magBytesFuel_valid (fuel m : Nat) : Bytes.valid (magBytesFuel fuel m) := by
  induction fuel generalizing m with
  | zero => simp [magBytesFuel, Bytes.valid]
  | succ n ih =>
    simp only [magBytesFuel]
    split
    · exact valid_nil
    · rw [valid_cons]
      exact ⟨Nat.mod_lt _ (by norm_num), ih _⟩

/-- The little-endian value of a byte list. -/
def leNat : Bytes → Nat
  | [] => 0
  | b :: bs => b + 256 * leNat bs

/-- The magnitude bytes read back: `leNat (magBytesFuel fuel m) = m` when the fuel
covers the value (the hypothesis `m ≤ fuel`; `magBytes` runs at `fuel = m`), so the
transcription of `serialize`'s loop (`int_serialization.h:31–36`) loses no digit. -/
theorem leNat_magBytesFuel (fuel m : Nat) (h : m ≤ fuel) : leNat (magBytesFuel fuel m) = m := by
  induction fuel generalizing m with
  | zero => simp [magBytesFuel, leNat]; omega
  | succ n ih =>
    simp only [magBytesFuel]
    split
    · simp [leNat]; omega
    · simp only [leNat]
      rw [ih (m / 256) (by omega)]
      omega

/-- `beNat` of a reversed list is `leNat`. -/
theorem beNat_reverse (bs : Bytes) : beNat bs.reverse = leNat bs := by
  induction bs with
  | nil => rfl
  | cons b bs ih =>
    simp only [beNat, List.reverse_cons, List.foldl_append, List.foldl_cons, List.foldl_nil] at ih ⊢
    rw [ih]; simp [leNat]; ring

/-- A zero top byte adds nothing to the big-endian value (a `0x00` above the
magnitude is value-free). -/
theorem beNat_zero_cons (l : Bytes) : beNat (0 :: l) = beNat l := by
  simp [beNat]

/-- One more low byte under a top-first list: the value shifts up a byte and adds it. -/
theorem beNat_append_single (l : Bytes) (x : Nat) : beNat (l ++ [x]) = beNat l * 256 + x := by
  simp [beNat, List.foldl_append]

/-- The reversed magnitude bytes: non-empty with a non-zero head (the top byte)
when the magnitude is non-zero (`serialize` stops at the last non-zero byte). -/
theorem magBytes_reverse_head (m : Nat) (hm : m ≠ 0) :
    ∃ t rest, (magBytes m).reverse = t :: rest ∧ t ≠ 0 ∧ t < 256 := by
  suffices h : ∀ fuel k, k ≠ 0 → k ≤ fuel → ∃ t rest, (magBytesFuel fuel k).reverse = t :: rest ∧ t ≠ 0 ∧ t < 256 from
    h m m hm le_rfl
  intro fuel
  induction fuel with
  | zero => intro k hk h; omega
  | succ n ih =>
    intro k hk h
    simp only [magBytesFuel, hk, ite_false, List.reverse_cons]
    by_cases hq : k / 256 = 0
    · have hnil : magBytesFuel n (k / 256) = [] := by cases n <;> simp [magBytesFuel, hq]
      have hlt : k < 256 := by omega
      have hmod : k % 256 = k := Nat.mod_eq_of_lt hlt
      refine ⟨k % 256, [], ?_, ?_, Nat.mod_lt _ (by norm_num)⟩
      · rw [hnil]; rfl
      · rw [hmod]; exact hk
    · obtain ⟨t, rest, hrev, ht, ht2⟩ := ih (k / 256) hq (by omega)
      exact ⟨t, rest ++ [k % 256], by rw [hrev]; rfl, ht, ht2⟩

/-- Decoding undoes the sign handling: for a top byte `t` with `0 < t < 256` (the
hypotheses), `decodeRev` of `signTopRev (t :: rest) neg` is the magnitude
`beNat (t :: rest)` with the sign `neg`, whether a sign byte went above `t` or bit 7
of `t` was set (`serialize`, `int_serialization.h:48–55`, against `deserialize`,
`int_serialization.h:94–117`). The step of T1, `decode_encode`. -/
theorem decodeRev_signTopRev (t : Nat) (rest : Bytes) (neg : Bool) (ht : t ≠ 0) (ht2 : t < 256) :
    decodeRev (signTopRev (t :: rest) neg) = (beNat (t :: rest), neg) := by
  simp only [signTopRev]
  by_cases h : 128 ≤ t
  · simp only [h, ite_true]
    cases neg
    · show decodeRev (0 :: t :: rest) = (beNat (t :: rest), false)
      simp [decodeRev, beNat_zero_cons]
    · show decodeRev (128 :: t :: rest) = (beNat (t :: rest), true)
      simp [decodeRev, beNat_zero_cons]
  · simp only [h, ite_false]
    have h1 : (t + 128) % 128 = t := by omega
    have h2 : t % 128 = t := by omega
    cases neg
    · show decodeRev (t :: rest) = (beNat (t :: rest), false)
      simp only [decodeRev, h2]
      simp [h]
    · show decodeRev ((t + 128) :: rest) = (beNat (t :: rest), true)
      simp only [decodeRev, h1]
      simp

/-- **Decoding an encoding gives the value back** (for every integer; the
canonicality theorem's easy half). -/
theorem decode_encode (v : Int) : decode (encode v) = v := by
  by_cases h0 : v = 0
  · subst h0; simp [encode, decode, decodeRev]
  · simp only [encode, h0, ite_false, decode, List.reverse_reverse]
    have hm : v.natAbs ≠ 0 := by omega
    obtain ⟨t, rest, hrev, ht, ht2⟩ := magBytes_reverse_head v.natAbs hm
    rw [hrev, decodeRev_signTopRev t rest _ ht ht2, ← hrev, beNat_reverse]
    simp only [magBytes, leNat_magBytesFuel v.natAbs v.natAbs le_rfl]
    by_cases hneg : v < 0
    · simp [hneg, abs_of_neg hneg]
    · simp [hneg, abs_of_nonneg (not_lt.mp hneg)]

/-- The sign handling keeps a valid list valid (the hypothesis `Bytes.valid bs`): it puts
`0x00` or `0x80` above a top byte with bit 7 set, or sets bit 7 of a top byte below
128 (`t + 128 < 256`). With `magBytesFuel_valid`, the step of `encode_valid`. -/
theorem signTopRev_valid (bs : Bytes) (neg : Bool) (hv : Bytes.valid bs) : Bytes.valid (signTopRev bs neg) := by
  cases bs with
  | nil => simp [signTopRev, Bytes.valid]
  | cons t rest =>
    rw [valid_cons] at hv
    obtain ⟨ht, hrest⟩ := hv
    simp only [signTopRev]
    by_cases h : 128 ≤ t
    · simp only [h, ite_true]
      cases neg
      · show Bytes.valid (0 :: t :: rest)
        exact (valid_cons _ _).mpr ⟨by norm_num, (valid_cons _ _).mpr ⟨ht, hrest⟩⟩
      · show Bytes.valid (128 :: t :: rest)
        exact (valid_cons _ _).mpr ⟨by norm_num, (valid_cons _ _).mpr ⟨ht, hrest⟩⟩
    · simp only [h, ite_false]
      cases neg
      · show Bytes.valid (t :: rest)
        exact (valid_cons _ _).mpr ⟨ht, hrest⟩
      · show Bytes.valid ((t + 128) :: rest)
        exact (valid_cons _ _).mpr ⟨by omega, hrest⟩

/-- **An encoding is made of bytes.** -/
theorem encode_valid (v : Int) : Bytes.valid (encode v) := by
  unfold encode
  split
  · exact valid_nil
  · rw [valid_reverse]
    exact signTopRev_valid _ _ ((valid_reverse _).mpr (magBytesFuel_valid _ _))

/-- **An encoding is minimal** (the canonicality theorem's second half:
`serialize` produces what `IsMinimallyEncoded` accepts, at any length bound it
fits). -/
theorem encode_minimal (v : Int) : minimalTail (encode v) = true := by
  by_cases h0 : v = 0
  · subst h0; simp [encode, minimalTail]
  · have hm : v.natAbs ≠ 0 := by omega
    obtain ⟨t, rest, hrev, ht, ht2⟩ := magBytes_reverse_head v.natAbs hm
    simp only [encode, h0, ite_false, minimalTail, List.reverse_reverse, hrev, signTopRev]
    by_cases h : 128 ≤ t
    · simp only [h, ite_true]
      by_cases hvn : v < 0 <;> simp [hvn]
    · simp only [h, ite_false]
      by_cases hvn : v < 0
      · cases rest <;> simp [hvn] <;> omega
      · cases rest <;> simp [hvn] <;> omega

/-- An encoding passes `IsMinimallyEncoded` exactly when it fits the length bound:
the structural half holds of every encoding (`encode_minimal`, T2), so only the size
test (`int_serialization.h:124–127`) can refuse it. -/
theorem isMinimallyEncoded_encode (v : Int) (maxLen : Nat) :
    isMinimallyEncoded (encode v) maxLen = decide ((encode v).length ≤ maxLen) := by
  simp [isMinimallyEncoded, encode_minimal]

/-- **The width boundaries**, as decided facts (this theorem heads eleven, each with
its own explainer; T6, `encode_length_le_iff`, is the general statement): the encoded
length steps up where the top magnitude byte reaches `0x80`, whose bit 7 then costs a
sign byte (`serialize`, `int_serialization.h:48–52`). Decided on both sides of the
step (the last value of the shorter length and the first of the longer): +2⁷, −2⁷,
+2¹⁵, +2³¹, +2⁶³. On one side only: −2³¹ (five bytes; the four-byte side,
−(2³¹ − 1), is not decided). On neither side: −2¹⁵ and −2⁶³. The `int64` boundary:
`INT64_SERIALIZED_SIZE` is 9 (`script_num.h:55`), and the one `int64` that needs
nine bytes is `INT64_MIN` = −2⁶³ (magnitude 2⁶³, top byte `0x80`, then the sign
byte), which T6 carries and no fact here decides; `INT64_MAX` = 2⁶³ − 1 is eight
bytes (`width_2p63m1`), and `width_2p63` decides +2⁶³, which is not an `int64`. This
theorem: 127 is one byte, `0x7f`. -/
theorem width_127 : (encode 127).length = 1 := by decide
/-- 128 is two bytes, `[0x80, 0x00]`: its magnitude byte `0x80` has bit 7 set, so a
sign byte follows (`int_serialization.h:48–52`); the first value past one byte. -/
theorem width_128 : (encode 128).length = 2 := by decide
/-- −127 is one byte, `0xff`: the magnitude `0x7f` leaves bit 7 for the sign
(`int_serialization.h:55`). -/
theorem width_neg127 : (encode (-127)).length = 1 := by decide
/-- −128 is two bytes, `[0x80, 0x80]`: the magnitude byte `0x80` has bit 7 set, so the
sign byte `0x80` follows (`int_serialization.h:48–52`). -/
theorem width_neg128 : (encode (-128)).length = 2 := by decide
/-- 32767 (2¹⁵ − 1) is two bytes, `[0xff, 0x7f]`: the top byte `0x7f` leaves bit 7 for
the sign (`int_serialization.h:55`). -/
theorem width_32767 : (encode 32767).length = 2 := by decide
/-- 32768 (2¹⁵) is three bytes, `[0x00, 0x80, 0x00]`: the top magnitude byte `0x80`
costs a sign byte (`int_serialization.h:48–52`). -/
theorem width_32768 : (encode 32768).length = 3 := by decide
/-- 2³¹ − 1 is four bytes, `[0xff, 0xff, 0xff, 0x7f]`: the top of the pre-Genesis
operand range `[-2^31+1, 2^31-1]` (`script_num.h:45–47`). -/
theorem width_2p31m1 : (encode (2 ^ 31 - 1)).length = 4 := by decide
/-- 2³¹ is five bytes, `[0x00, 0x00, 0x00, 0x80, 0x00]`: the top magnitude byte `0x80`
costs a sign byte (`int_serialization.h:48–52`), so 2³¹ is past the pre-Genesis
four-byte operands. -/
theorem width_2p31 : (encode (2 ^ 31)).length = 5 := by decide
/-- −2³¹ is five bytes, `[0x00, 0x00, 0x00, 0x80, 0x80]`: the top magnitude byte `0x80`
costs the sign byte `0x80` (`int_serialization.h:48–52`). The four-byte side of this
step, −(2³¹ − 1), is not decided here (T6 carries it). -/
theorem width_neg2p31 : (encode (-(2 ^ 31))).length = 5 := by decide
/-- 2⁶³ − 1, `INT64_MAX`, is eight bytes: the top byte `0x7f` leaves bit 7 for the sign
(`int_serialization.h:55`). -/
theorem width_2p63m1 : (encode (2 ^ 63 - 1)).length = 8 := by decide
/-- 2⁶³ is nine bytes: seven zero bytes, the top magnitude byte `0x80`, then the sign
byte `0x00` (`int_serialization.h:48–52`). 2⁶³ is not an `int64`: the nine-byte
`int64` is `INT64_MIN` = −2⁶³ (`INT64_SERIALIZED_SIZE`, `script_num.h:55`), which T6
carries and no fact here decides. -/
theorem width_2p63 : (encode (2 ^ 63)).length = 9 := by decide

/-- **The reference vectors** the predecessor's fuzz asserts (`harness/src/gen.rs`,
`enc_num_vectors`: nine vectors). Five are decided here as byte equalities of the
spec's encoder, this theorem and the four after it (1, −1, 255, 256, −255); the zero
vector is `encode_zero`; 127, 128 and −128 are decided only as lengths (`width_127`,
`width_128`, `width_neg128`). This theorem: 1 is `[0x01]`
(`int_serialization.h:55`). -/
theorem vec_1 : encode 1 = [1] := by decide
/-- −1 is `[0x81]`: the magnitude 1 with the sign bit set on its one byte
(`int_serialization.h:55`). -/
theorem vec_neg1 : encode (-1) = [0x81] := by decide
/-- 255 is `[0xff, 0x00]`: the magnitude byte `0xff` has bit 7 set, so a zero sign
byte follows (`int_serialization.h:48–52`); the positive case of
`IsMinimallyEncoded`'s exception (`int_serialization.h:139–144`). -/
theorem vec_255 : encode 255 = [0xff, 0x00] := by decide
/-- 256 is `[0x00, 0x01]`: two magnitude bytes, low first, the top byte `0x01` below
`0x80` carrying the clear sign bit (`int_serialization.h:31–36`, `:55`). -/
theorem vec_256 : encode 256 = [0x00, 0x01] := by decide
/-- −255 is `[0xff, 0x80]`: the magnitude byte `0xff` has bit 7 set, so the sign byte
`0x80` follows (`int_serialization.h:48–52`); the negative case of
`IsMinimallyEncoded`'s exception (`int_serialization.h:139–144`). -/
theorem vec_neg255 : encode (-255) = [0xff, 0x80] := by decide

/-- The forward truthiness test against the magnitude: `CastToBool` is true iff
some byte is non-zero other than a lone sign bit in the last byte, which is
exactly "the magnitude, top byte masked, is non-zero" (on bytes). -/
theorem castToBool_iff_beNat (bs : Bytes) (hv : Bytes.valid bs) :
    castToBool bs = true ↔ (decodeRev bs.reverse).1 ≠ 0 := by
  induction bs with
  | nil => simp [castToBool, decodeRev]
  | cons b bs ih =>
    rw [valid_cons] at hv
    obtain ⟨hb, hbs⟩ := hv
    cases bs with
    | nil =>
      simp only [castToBool, List.reverse_cons, List.reverse_nil, List.nil_append, decodeRev, beNat,
        List.foldl_cons, List.foldl_nil, Bool.and_eq_true, bne_iff_ne, ne_eq, zero_mul, zero_add]
      omega
    | cons c cs =>
      have hne : (c :: cs).reverse ≠ [] := by simp
      have hsplit : (decodeRev ((c :: cs).reverse ++ [b])).1 = (decodeRev (c :: cs).reverse).1 * 256 + b := by
        obtain ⟨t, r, htr⟩ : ∃ t r, (c :: cs).reverse = t :: r := by
          cases h : (c :: cs).reverse with
          | nil => exact absurd h hne
          | cons t r => exact ⟨t, r, rfl⟩
        rw [htr]
        simp only [decodeRev, List.cons_append]
        rw [← List.cons_append, beNat_append_single]
      rw [List.reverse_cons, hsplit]
      show (b != 0 || castToBool (c :: cs)) = true ↔ _
      rw [Bool.or_eq_true, bne_iff_ne, ih hbs]
      constructor
      · rintro (hb0 | hx) <;> omega
      · intro hx
        by_cases hb0 : b = 0
        · right; omega
        · left; exact hb0

/-- **T5, truthiness is non-zeroness**: `CastToBool` (`119–130`) is true exactly when
the decoded value is non-zero (so negative zero and every all-zero vector are false).
*What it assumes:* `Bytes.valid bs`, every entry below 256 (the byte type is `Nat`;
`[256]` is true to `castToBool` but decodes to 0). -/
theorem castToBool_eq (bs : Bytes) (hv : Bytes.valid bs) : castToBool bs = (decode bs != 0) := by
  have h := castToBool_iff_beNat bs hv
  simp only [decode]
  cases hb : castToBool bs
  · rw [hb] at h
    have h' : (decodeRev bs.reverse).1 = 0 := by simpa using h
    simp [h']
  · rw [hb] at h
    have h' := h.mp rfl
    split <;> simp <;> omega


/-! ## The owed theorems (T3, T4, T6, T7, T8) -/

/-- `magBytesFuel` does not depend on the fuel once the fuel covers the value. -/
theorem magBytesFuel_fuel_irrel (f1 f2 m : Nat) (h1 : m ≤ f1) (h2 : m ≤ f2) :
    magBytesFuel f1 m = magBytesFuel f2 m := by
  induction f1 generalizing f2 m with
  | zero =>
    have : m = 0 := by omega
    subst this
    cases f2 <;> simp [magBytesFuel]
  | succ n ih =>
    cases f2 with
    | zero =>
      have : m = 0 := by omega
      subst this
      simp [magBytesFuel]
    | succ k =>
      simp only [magBytesFuel]
      split
      · rfl
      · rw [ih k (m / 256) (by omega) (by omega)]

/-- The recursion of `magBytes` itself (`serialize`, `int_serialization.h:31–36`): the low byte, then
the bytes of the quotient. -/
theorem magBytes_cons (m : Nat) (hm : m ≠ 0) : magBytes m = (m % 256) :: magBytes (m / 256) := by
  unfold magBytes
  cases hm' : m with
  | zero => exact absurd hm' hm
  | succ k =>
    simp only [magBytesFuel, Nat.succ_ne_zero, ite_false]
    rw [magBytesFuel_fuel_irrel k ((k + 1) / 256) ((k + 1) / 256) (by omega) le_rfl]

/-- Zero has no magnitude bytes (`serialize`'s loop, `int_serialization.h:31–36`, runs
while the magnitude is non-zero). -/
theorem magBytes_zero : magBytes 0 = [] := by simp [magBytes, magBytesFuel]

/-- Every byte of `magBytes m` is below 256 (`magBytesFuel_valid` at `fuel = m`). -/
theorem magBytes_valid (m : Nat) : Bytes.valid (magBytes m) := magBytesFuel_valid m m

/-- A magnitude's bytes read back little-endian give the magnitude, for every `m`
(`leNat_magBytesFuel` at `fuel = m`); the converse, on valid lists (`Bytes.valid`) with a
non-zero top byte, is `magBytes_leNat`. -/
theorem leNat_magBytes (m : Nat) : leNat (magBytes m) = m := leNat_magBytesFuel m m le_rfl

/-- `magBytes` is bounded by the value's size: `m < 256^k` gives at most `k` bytes. -/
theorem magBytes_length_le (k : Nat) : ∀ m, m < 256 ^ k → (magBytes m).length ≤ k := by
  induction k with
  | zero => intro m hm; simp at hm; subst hm; simp [magBytes_zero]
  | succ k ih =>
    intro m hm
    by_cases h0 : m = 0
    · subst h0; simp [magBytes_zero]
    · rw [magBytes_cons m h0]
      simp only [List.length_cons]
      have : m / 256 < 256 ^ k := by
        rw [pow_succ] at hm; omega
      have := ih (m / 256) this
      omega

/-- The last byte (the top byte, `lastNZ`) of a byte list is non-zero. -/
def lastNZ : Bytes → Bool
  | [] => false
  | [b] => b != 0
  | _ :: bs => lastNZ bs

/-- `lastNZ` reads the last byte only: `lastNZ (l ++ [t])` is `t ≠ 0`, whatever `l`. -/
theorem lastNZ_append_single (l : Bytes) (t : Nat) : lastNZ (l ++ [t]) = (t != 0) := by
  induction l with
  | nil => rfl
  | cons x xs ih =>
    cases xs with
    | nil => simp [lastNZ]
    | cons y ys => simp only [List.cons_append, lastNZ] at ih ⊢; exact ih

/-- A list whose last (top) byte is non-zero has a positive little-endian value. -/
theorem leNat_pos_of_lastNZ (l : Bytes) (h : lastNZ l = true) : 0 < leNat l := by
  induction l with
  | nil => simp [lastNZ] at h
  | cons b bs ih =>
    cases bs with
    | nil => simp [lastNZ] at h; simp [leNat]; omega
    | cons c cs =>
      simp only [lastNZ] at h
      have := ih h
      simp only [leNat] at this ⊢; omega

/-- **`magBytes` inverts `leNat`** on byte lists with a non-zero top byte: the
little-endian digits of a number are unique (`serialize`, `int_serialization.h:31–36`,
against `deserialize`, `int_serialization.h:86–92`). -/
theorem magBytes_leNat (l : Bytes) (hv : Bytes.valid l) (hnz : lastNZ l = true) : magBytes (leNat l) = l := by
  induction l with
  | nil => simp [lastNZ] at hnz
  | cons b bs ih =>
    rw [valid_cons] at hv
    obtain ⟨hb, hbs⟩ := hv
    have hpos : 0 < leNat (b :: bs) := leNat_pos_of_lastNZ _ hnz
    rw [magBytes_cons _ (by omega)]
    simp only [leNat] at hpos ⊢
    have hmod : (b + 256 * leNat bs) % 256 = b := by omega
    have hdiv : (b + 256 * leNat bs) / 256 = leNat bs := by omega
    rw [hmod, hdiv]
    cases bs with
    | nil => simp [leNat, magBytes_zero]
    | cons c cs =>
      simp only [lastNZ] at hnz
      rw [ih hbs hnz]

/-- The reversed form: `magBytes (beNat (t :: rest))` reversed is `t :: rest` when
the top byte is non-zero and the list is valid (`Bytes.valid`, the hypothesis `hv`). -/
theorem magBytes_beNat_reverse (t : Nat) (rest : Bytes) (ht : t ≠ 0) (hv : Bytes.valid (t :: rest)) :
    (magBytes (beNat (t :: rest))).reverse = t :: rest := by
  have h1 : beNat (t :: rest) = leNat ((t :: rest).reverse) := by
    rw [← beNat_reverse, List.reverse_reverse]
  rw [h1, magBytes_leNat _ ((valid_reverse _).mpr hv) (by rw [List.reverse_cons, lastNZ_append_single]; simpa using ht),
    List.reverse_reverse]

/-- `encode` of a non-zero natural `m` (the hypothesis `m ≠ 0`): the reversed magnitude
bytes under the positive sign handling (`signTopRev … false`), reversed back. -/
theorem encode_ofNat (m : Nat) (hm : m ≠ 0) : encode (m : Int) = (signTopRev (magBytes m).reverse false).reverse := by
  have h1 : (m : Int) ≠ 0 := by omega
  have h3 : ¬ ((m : Int) < 0) := by omega
  simp [encode, h1, h3, hm]

/-- `encode` of `-m` for a non-zero natural `m`: the same magnitude bytes under the
negative sign handling (`signTopRev … true`), reversed back. -/
theorem encode_negOfNat (m : Nat) (hm : m ≠ 0) : encode (-(m : Int)) = (signTopRev (magBytes m).reverse true).reverse := by
  have h1 : (-(m : Int)) ≠ 0 := by omega
  have h2 : (-(m : Int)) < 0 := by omega
  have h3 : 0 < m := by omega
  simp [encode, h1, h2, h3]

/-- `beNat` of a list of zero bytes in front of `l` is `beNat l`. -/
theorem beNat_leading_zeros (z l : Bytes) (hz : ∀ x ∈ z, x = 0) : beNat (z ++ l) = beNat l := by
  induction z with
  | nil => rfl
  | cons x xs ih =>
    have hx : x = 0 := hz x (by simp)
    subst hx
    rw [List.cons_append, beNat_zero_cons]
    exact ih (fun y hy => hz y (by simp [hy]))

/-- A top-first list with a non-zero top byte has a non-zero big-endian value (no
validity needed: the top byte alone contributes `t * 256 ^ rest.length`). -/
theorem beNat_pos_of_top (t : Nat) (rest : Bytes) (ht : t ≠ 0) : beNat (t :: rest) ≠ 0 := by
  have := leNat_pos_of_lastNZ ((t :: rest).reverse) (by rw [List.reverse_cons, lastNZ_append_single]; simpa using ht)
  rw [← beNat_reverse, List.reverse_reverse] at this
  omega

/-- The encoding of `beNat (t :: rest)` for a top-first list with a non-zero top byte
`t` and every entry a byte (the hypotheses): `signTopRev (t :: rest) false`, reversed
back; the negation is `encode_beNat_neg`. -/
theorem encode_beNat_pos (t : Nat) (rest : Bytes) (ht : t ≠ 0) (hv : Bytes.valid (t :: rest)) :
    encode (beNat (t :: rest) : Int) = (signTopRev (t :: rest) false).reverse := by
  rw [encode_ofNat _ (beNat_pos_of_top t rest ht), magBytes_beNat_reverse t rest ht hv]

/-- The encoding of `-(beNat (t :: rest))` under the same hypotheses:
`signTopRev (t :: rest) true`, reversed back. With `encode_beNat_pos`, the step T3 and
T4 rest on. -/
theorem encode_beNat_neg (t : Nat) (rest : Bytes) (ht : t ≠ 0) (hv : Bytes.valid (t :: rest)) :
    encode (-(beNat (t :: rest) : Int)) = (signTopRev (t :: rest) true).reverse := by
  rw [encode_negOfNat _ (beNat_pos_of_top t rest ht), magBytes_beNat_reverse t rest ht hv]

/-- **T3, canonicality**: a minimal encoding is the encoding of its value
(`IsMinimallyEncoded`, `int_serialization.h:120–152`, accepts exactly `serialize`'s
outputs; with `encode_minimal` this is the bijection between values and minimal byte
lists). *What it assumes:* `Bytes.valid b`, every entry below 256 (the byte type is
`Nat`; `[257]` has a minimal tail and decodes to −1, which encodes as `[0x81]`). -/
theorem encode_decode_of_minimal (b : Bytes) (hv : Bytes.valid b) (hm : minimalTail b = true) :
    encode (decode b) = b := by
  obtain ⟨r, rfl⟩ : ∃ r, b = r.reverse := ⟨b.reverse, by simp⟩
  rw [valid_reverse] at hv
  simp only [minimalTail, List.reverse_reverse] at hm
  rw [decode_eq_signInt, List.reverse_reverse]
  cases r with
  | nil => simp [decodeRev, signInt, encode]
  | cons t rest =>
    rw [valid_cons] at hv
    obtain ⟨ht, hrest⟩ := hv
    simp only [decodeRev]
    by_cases htm : t % 128 = 0
    · -- the top byte is 0 or 128: minimality forces a byte below with bit 7 set
      cases rest with
      | nil => simp [htm] at hm
      | cons a more =>
        simp [htm] at hm
        have ha : a ≠ 0 := by omega
        have hz : beNat (t % 128 :: a :: more) = beNat (a :: more) := by
          rw [htm]; exact beNat_zero_cons _
        rw [hz]
        by_cases h128 : 128 ≤ t
        · have ht0 : t = 128 := by omega
          simp only [decide_eq_true h128, signInt]
          rw [encode_beNat_neg a more ha hrest]
          simp [signTopRev, hm, ht0]
        · have ht0 : t = 0 := by omega
          simp only [decide_eq_false h128, signInt]
          rw [encode_beNat_pos a more ha hrest]
          simp [signTopRev, hm, ht0]
    · -- the top byte carries value: its low seven bits are the top magnitude byte
      have hv' : Bytes.valid (t % 128 :: rest) := (valid_cons _ _).mpr ⟨by omega, hrest⟩
      have hlt : ¬ 128 ≤ t % 128 := by omega
      by_cases h128 : 128 ≤ t
      · have hmod : t % 128 + 128 = t := by omega
        simp only [decide_eq_true h128, signInt]
        rw [encode_beNat_neg (t % 128) rest htm hv']
        simp [signTopRev, hlt, hmod]
      · have hmod : t % 128 = t := Nat.mod_eq_of_lt (by omega)
        simp only [decide_eq_false h128, signInt]
        rw [encode_beNat_pos (t % 128) rest htm hv']
        simp [signTopRev, hlt, hmod] <;> omega

/-- The zero-dropping recursion of `minimallyEncodeRef`: what it drops is zeros,
and what it keeps starts with a non-zero byte or is empty. -/
theorem dropZeros_spec (l : Bytes) :
    ∃ z, (∀ x ∈ z, x = 0) ∧ l = z ++ dropZeros l ∧
      (dropZeros l = [] ∨ ∃ c more, dropZeros l = c :: more ∧ c ≠ 0) := by
  induction l with
  | nil => exact ⟨[], by simp, rfl, Or.inl rfl⟩
  | cons x xs ih =>
    by_cases hx : x = 0
    · subst hx
      obtain ⟨z, hz, hl, hd⟩ := ih
      refine ⟨0 :: z, ?_, ?_, ?_⟩
      · intro y hy
        simp at hy
        rcases hy with rfl | hy
        · rfl
        · exact hz y hy
      · simp only [dropZeros]; rw [List.cons_append, ← hl]
      · simpa [dropZeros] using hd
    · have hd : dropZeros (x :: xs) = x :: xs := by
        cases x with
        | zero => exact absurd rfl hx
        | succ n => simp [dropZeros]
      exact ⟨[], by simp, by simp [hd], Or.inr ⟨x, xs, hd, hx⟩⟩

/-- **T4, the reference algorithm is the canonical re-encoding**: `MinimallyEncode`
(`int_serialization.h:154–208`, transcribed as `minimallyEncodeRef`) computes
`encode (decode b)` on every list of bytes (so `OP_BIN2NUM` (`1786`) and
`OP_NUM2BIN`'s first step (`1760`) are re-encodings). *What it assumes:*
`Bytes.valid b`, every entry below 256 (the byte type is `Nat`; `[257]` is left
unchanged by `minimallyEncodeRef` and re-encodes to `[0x81]`). That bsv-rs's
decode-then-encode agrees with it is not this theorem's: the property check
`lean/Test/NumbersCheck.lean` compares the two over `corpus/numbers/`, at the
pinned release. -/
theorem minimallyEncodeRef_eq (b : Bytes) (hv : Bytes.valid b) : minimallyEncodeRef b = encode (decode b) := by
  obtain ⟨r, rfl⟩ : ∃ r, b = r.reverse := ⟨b.reverse, by simp⟩
  have hvr := (valid_reverse _).mp hv
  simp only [minimallyEncodeRef, List.reverse_reverse]
  cases r with
  | nil => simp [decode, decodeRev, encode]
  | cons last rest =>
    rw [valid_cons] at hvr
    obtain ⟨hlast, hrest⟩ := hvr
    by_cases hl : last % 128 = 0
    · simp only [hl, bne_self_eq_false, Bool.false_eq_true, ite_false]
      cases rest with
      | nil =>
        -- one byte, 0 or 128: zero either way
        have : decode [last].reverse = 0 := by
          simp [decode, decodeRev, beNat, hl]
        rw [this, encode_zero]
      | cons r0 more =>
        by_cases h0 : 128 ≤ r0
        · simp only [h0, ite_true]
          symm
          apply encode_decode_of_minimal _ hv
          simp [minimalTail, hl, h0]
        · simp only [h0, ite_false]
          obtain ⟨z, hz, hsplit, hd⟩ := dropZeros_spec (r0 :: more)
          rw [decode_eq_signInt, List.reverse_reverse]
          simp only [decodeRev]
          rw [hl]
          have hbe : beNat (0 :: r0 :: more) = beNat (dropZeros (r0 :: more)) := by
            rw [beNat_zero_cons]
            conv_lhs => rw [hsplit]
            exact beNat_leading_zeros z _ hz
          rcases hd with hnil | ⟨c, more', hcm, hc⟩
          · have hbe0 : beNat (0 :: r0 :: more) = 0 := by rw [hbe, hnil]; rfl
            rw [hbe0, hnil]
            cases hd128 : decide (128 ≤ last) <;> simp [signInt, encode]
          · rw [hcm] at hbe
            have hvc : Bytes.valid (c :: more') := by
              rw [hsplit, hcm] at hrest
              intro x hx; exact hrest x (by simp [hx])
            rw [hbe, hcm]
            by_cases h128 : 128 ≤ last
            · have hl0 : last = 128 := by omega
              simp only [decide_eq_true h128, signInt]
              rw [encode_beNat_neg c more' hc hvc]
              by_cases hc128 : 128 ≤ c
              · simp [signTopRev, hc128, hl0]
              · simp [signTopRev, hc128, hl0]
            · have hl0 : last = 0 := by omega
              simp only [decide_eq_false h128, signInt]
              rw [encode_beNat_pos c more' hc hvc]
              by_cases hc128 : 128 ≤ c
              · simp [signTopRev, hc128, hl0]
              · simp [signTopRev, hc128, hl0]
    · have hl' : (last % 128 != 0) = true := by simpa using hl
      simp only [hl', ite_true]
      symm
      apply encode_decode_of_minimal _ hv
      cases rest <;> simp [minimalTail, hl]

/-- T4 in the spec's own names: `minimallyEncodeRef b = minimallyEncode b` on bytes
(`Bytes.valid b`), `minimallyEncode` being defined as `encode (decode b)`: the
function the opcodes run is the reference's algorithm as transcribed. (Named
`minimallyEncodeRef_eq'` until lean #32's second lens: the axiom checker's parser reads no
primed name, finding C-10.) -/
theorem minimallyEncodeRef_eq_minimallyEncode (b : Bytes) (hv : Bytes.valid b) : minimallyEncodeRef b = minimallyEncode b :=
  minimallyEncodeRef_eq b hv

/-- The fold with an accumulator: the accumulator scales by 256 per byte. -/
theorem foldl_beNat_acc (l : Bytes) (a : Nat) :
    l.foldl (fun acc b => acc * 256 + b) a = a * 256 ^ l.length + beNat l := by
  induction l generalizing a with
  | nil => simp [beNat]
  | cons x xs ih =>
    simp only [beNat, List.foldl_cons, List.length_cons, zero_mul, zero_add] at ih ⊢
    rw [ih (a * 256 + x), ih x]
    ring

/-- The big-endian value of a top-first list: the top byte times `256 ^ rest.length`
plus the value of the rest (the unfolding `beNat_lt` and T6 use). -/
theorem beNat_cons (t : Nat) (rest : Bytes) : beNat (t :: rest) = t * 256 ^ rest.length + beNat rest := by
  simp only [beNat, List.foldl_cons, zero_mul, zero_add]
  exact foldl_beNat_acc rest t

/-- `beNat` is bounded by the size of the list. -/
theorem beNat_lt (l : Bytes) (hv : Bytes.valid l) : beNat l < 256 ^ l.length := by
  induction l with
  | nil => simp [beNat]
  | cons t rest ih =>
    rw [valid_cons] at hv
    obtain ⟨ht, hrest⟩ := hv
    have h := ih hrest
    rw [beNat_cons]
    simp only [List.length_cons]
    calc t * 256 ^ rest.length + beNat rest < t * 256 ^ rest.length + 256 ^ rest.length := by omega
      _ = (t + 1) * 256 ^ rest.length := by ring
      _ ≤ 256 * 256 ^ rest.length := Nat.mul_le_mul_right _ (by omega)
      _ = 256 ^ (rest.length + 1) := by ring

/-- The encoded length of a non-zero value: the magnitude's bytes plus one when
the top byte has bit 7 set (`serialize`, `int_serialization.h:48–52`). -/
theorem encode_length_eq (v : Int) (hv0 : v ≠ 0) (t : Nat) (rest : Bytes)
    (hrev : (magBytes v.natAbs).reverse = t :: rest) :
    (encode v).length = rest.length + 1 + (if 128 ≤ t then 1 else 0) := by
  have hE : encode v = (signTopRev (t :: rest) (decide (v < 0))).reverse := by
    simp only [encode, hv0, ite_false, hrev]
  rw [hE, List.length_reverse]
  by_cases h128 : 128 ≤ t
  · simp [signTopRev, h128]
  · simp [signTopRev, h128]

/-- **T6, the width lemma**: an integer encodes in at most `n` bytes exactly when its
magnitude is below `2^(8n−1)` (the top byte's bit 7 costs a sign byte). `n = 4` is
the pre-Genesis operand range `[-2^31+1, 2^31-1]` (`script_num.h:44–53`).
*What it assumes:* `1 ≤ n` (the hypothesis `hn`: at `n = 0` the natural-number
`n - 1` is 0, the right side reads `|z| < 128`, and the equivalence fails at
`z = 1`). -/
theorem encode_length_le_iff (z : Int) (n : Nat) (hn : 1 ≤ n) :
    (encode z).length ≤ n ↔ z.natAbs < 128 * 256 ^ (n - 1) := by
  by_cases hz : z = 0
  · subst hz; simp [encode]
  · have hm : z.natAbs ≠ 0 := by omega
    obtain ⟨t, rest, hrev, ht, ht2⟩ := magBytes_reverse_head z.natAbs hm
    rw [encode_length_eq z hz t rest hrev]
    -- the magnitude in terms of the top byte
    have hval : beNat (t :: rest) = z.natAbs := by
      rw [← hrev, beNat_reverse, magBytes, leNat_magBytesFuel _ _ le_rfl]
    have hvalid : Bytes.valid (t :: rest) := by
      rw [← hrev, valid_reverse]; exact magBytes_valid _
    have hrestv : Bytes.valid rest := ((valid_cons _ _).mp hvalid).2
    have hlen : (magBytes z.natAbs).length = rest.length + 1 := by
      rw [← List.length_reverse, hrev]; rfl
    have hr : beNat rest < 256 ^ rest.length := beNat_lt rest hrestv
    rw [beNat_cons] at hval
    rw [← hval]
    generalize hB : 256 ^ rest.length = B at hr hval
    have hBpos : 0 < B := by rw [← hB]; positivity
    constructor
    · intro hle
      by_cases h128 : 128 ≤ t
      · -- a sign byte is present: rest.length + 2 ≤ n, so the magnitude is below 256^(rest.length+1) ≤ 256^(n-1)
        simp only [h128, ite_true] at hle
        have h1 : t * B + beNat rest < 256 * B := by
          calc t * B + beNat rest < t * B + B := by omega
            _ = (t + 1) * B := by ring
            _ ≤ 256 * B := Nat.mul_le_mul_right _ (by omega)
        have h2 : 256 * B ≤ 256 ^ (n - 1) := by
          rw [← hB, ← pow_succ']
          exact Nat.pow_le_pow_right (by norm_num) (by omega)
        have h3 : 256 ^ (n - 1) ≤ 128 * 256 ^ (n - 1) := by omega
        omega
      · simp only [h128, ite_false, add_zero] at hle
        have h1 : t * B + beNat rest < 128 * B := by
          calc t * B + beNat rest < t * B + B := by omega
            _ = (t + 1) * B := by ring
            _ ≤ 128 * B := Nat.mul_le_mul_right _ (by omega)
        have h2 : B ≤ 256 ^ (n - 1) := by
          rw [← hB]; exact Nat.pow_le_pow_right (by norm_num) (by omega)
        have h3 : 128 * B ≤ 128 * 256 ^ (n - 1) := Nat.mul_le_mul_left _ h2
        omega
    · intro hlt
      -- the magnitude is below 256^n, so there are at most n magnitude bytes
      have hlt' : z.natAbs < 256 ^ n := by
        have : 128 * 256 ^ (n - 1) < 256 ^ n := by
          have : 256 ^ n = 256 * 256 ^ (n - 1) := by
            rw [← pow_succ']; congr 1; omega
          rw [this]; have : 0 < 256 ^ (n - 1) := by positivity
          omega
        omega
      have hk := magBytes_length_le n z.natAbs hlt'
      rw [hlen] at hk
      by_cases h128 : 128 ≤ t
      · simp only [h128, ite_true]
        -- t ≥ 128 forces the magnitude ≥ 128·B, so B < 256^(n-1): rest.length < n - 1
        have h1 : 128 * B ≤ t * B := Nat.mul_le_mul_right _ h128
        have h2 : B < 256 ^ (n - 1) := by
          by_contra hcon
          have hcon' : 256 ^ (n - 1) ≤ B := Nat.le_of_not_lt hcon
          have : 128 * 256 ^ (n - 1) ≤ 128 * B := Nat.mul_le_mul_left _ hcon'
          omega
        have h3 : rest.length < n - 1 := by
          by_contra hcon
          have hcon' : n - 1 ≤ rest.length := Nat.le_of_not_lt hcon
          have : 256 ^ (n - 1) ≤ B := by rw [← hB]; exact Nat.pow_le_pow_right (by norm_num) hcon'
          omega
        omega
      · simp only [h128, ite_false, add_zero]
        omega

/-- The general width lemma in the reference's phrasing: `2^(8n−1)`. -/
theorem encode_length_le_iff_pow (z : Int) (n : Nat) (hn : 1 ≤ n) :
    (encode z).length ≤ n ↔ z.natAbs < 2 ^ (8 * n - 1) := by
  rw [encode_length_le_iff z n hn]
  have : 2 ^ (8 * n - 1) = 128 * 256 ^ (n - 1) := by
    have h1 : 8 * n - 1 = 7 + 8 * (n - 1) := by omega
    rw [h1, pow_add, pow_mul]; norm_num
  rw [this]

/-- The pre-Genesis operand range: four bytes hold exactly `|z| ≤ 2^31 − 1`. -/
theorem encode_length_le_four_iff (z : Int) : (encode z).length ≤ 4 ↔ z.natAbs < 2 ^ 31 := by
  rw [encode_length_le_iff_pow z 4 (by norm_num)]

/-! ### T7, `OP_NUM2BIN` -/

/-- **T7, the failure**: `num2bin` refuses (`none`: `OP_NUM2BIN`'s
`SCRIPT_ERR_IMPOSSIBLE_ENCODING`, `1761–1763`) exactly when the width is below the
length of the minimal encoding. -/
theorem num2bin_none_iff (b : Bytes) (w : Nat) :
    num2bin b w = none ↔ w < (minimallyEncode b).length := by
  unfold num2bin
  split_ifs with h1 h2
  · simp [h1]
  · simp; omega
  · simp; omega

/-- The padding reaches the width exactly: for `m` shorter than `w` (the hypothesis),
`num2binPad m w` has `w` bytes (`padRight` resizes to the width,
`limitedstack.cpp:60–71`). -/
theorem num2binPad_length (m : Bytes) (w : Nat) (h : m.length < w) : (num2binPad m w).length = w := by
  unfold num2binPad
  cases hm : m.reverse with
  | nil =>
    have : m.length = 0 := by rw [← List.length_reverse, hm]; rfl
    simp; omega
  | cons l rr =>
    have : m.length = rr.length + 1 := by rw [← List.length_reverse, hm]; rfl
    simp; omega

/-- **T7, the length**: a result of `num2bin` has exactly the requested width (equal:
unchanged, `1767–1769`; shorter: padded, `1771–1777`), as `OP_NUM2BIN` pushes it. -/
theorem num2bin_length (b : Bytes) (w : Nat) (r : Bytes) (h : num2bin b w = some r) : r.length = w := by
  unfold num2bin at h
  split_ifs at h with h1 h2
  · simp only [Option.some.injEq] at h; subst h; exact h2
  · simp only [Option.some.injEq] at h; subst h
    exact num2binPad_length _ _ (by omega)

/-- The padding keeps the value (the sign-bit move `1771–1777` and `padRight`). -/
theorem decode_num2binPad (m : Bytes) (w : Nat) (h : m.length < w) : decode (num2binPad m w) = decode m := by
  unfold num2binPad
  cases hm : m.reverse with
  | nil =>
    have hz : m = [] := by rw [← List.reverse_reverse m, hm]; rfl
    subst hz
    have hall : ∀ x ∈ (0 :: List.replicate (w - 1) 0), x = 0 := by
      intro x hx
      simp only [List.mem_cons, List.mem_replicate] at hx
      omega
    have hbe : beNat (0 :: List.replicate (w - 1) 0) = 0 := by
      have := beNat_leading_zeros (0 :: List.replicate (w - 1) 0) [] hall
      simpa [beNat] using this
    simp [decode, decodeRev, List.reverse_append, List.reverse_replicate, hbe]
  | cons l rr =>
    have hmv : m = (l :: rr).reverse := by rw [← hm, List.reverse_reverse]
    have hdm : decode m = (if 128 ≤ l then -(beNat (l % 128 :: rr) : Int) else (beNat (l % 128 :: rr) : Int)) := by
      simp [decode, hm, decodeRev]
    rw [hdm]
    have hs : (if 128 ≤ l then 128 else 0) % 128 = 0 := by split <;> rfl
    have hz : ∀ k, beNat ((if 128 ≤ l then 128 else 0) % 128 :: (List.replicate k 0 ++ l % 128 :: rr)) = beNat (l % 128 :: rr) := by
      intro k
      rw [hs, ← List.cons_append, ← List.replicate_succ]
      exact beNat_leading_zeros _ _ (by intro x hx; exact (List.mem_replicate.mp hx).2)
    simp only [decode, List.reverse_append, List.reverse_replicate, List.reverse_reverse, List.reverse_cons,
      List.reverse_nil, List.nil_append, List.singleton_append, List.cons_append, List.append_assoc, decodeRev]
    rw [hz]
    by_cases h128 : 128 ≤ l <;> simp [h128]

/-- **T7, the value**: a result of `num2bin` decodes to the input's value: the minimal
encoding keeps it (T1, `decode_encode`) and the padding keeps it (`decode_num2binPad`,
the sign-bit move `1771–1777`), so `OP_NUM2BIN`, when it succeeds, changes the width
and never the number. -/
theorem num2bin_decode (b : Bytes) (w : Nat) (r : Bytes) (h : num2bin b w = some r) : decode r = decode b := by
  have hdec : decode (minimallyEncode b) = decode b := decode_encode _
  unfold num2bin at h
  split_ifs at h with h1 h2
  · simp only [Option.some.injEq] at h; subst h; exact hdec
  · simp only [Option.some.injEq] at h; subst h
    rw [decode_num2binPad _ _ (by omega), hdec]

/-! ### T8, the `int64` reader -/

/-- Up to eight bytes the active reader agrees with sign-magnitude, including
negative zero. [SRC] `6504a3af`, `int_serialization.h:75–107`, `int_serialization.h:117`. -/
theorem deserializeInt64_eq_decode (b : Bytes) (h : b.length ≤ 8) :
    deserializeInt64 b = some (decode b) := by
  simp [deserializeInt64, h]

/-- At most eight bytes also preserve the constructor's width and minimality
errors. [SRC] `6504a3af`, `script_num.cpp:62–87`. -/
theorem readNumInt64_eq_readNum (b : Bytes) (rm : Bool) (maxLen : Nat) (h : b.length ≤ 8) :
    readNumInt64 b rm maxLen = readNum b rm maxLen := by
  unfold readNumInt64 readNum
  split_ifs <;> simp [deserializeInt64_eq_decode b h]

/-- Ten bytes and above always refuse at v1.2.3. [SRC] `6504a3af`, `int_serialization.h:80–81`. -/
theorem deserializeInt64_long (b : Bytes) (h : 10 ≤ b.length) :
    deserializeInt64 b = none := by
  simp [deserializeInt64, show ¬ b.length ≤ 8 by omega, show b.length ≠ 9 by omega]

/-- At nine bytes the lower eight give the magnitude and the last byte supplies
only the sign. [SRC] `6504a3af`, `int_serialization.h:83–117`. -/
theorem deserializeInt64_nine (low : Bytes) (last : Nat) (h : low.length = 8) :
    deserializeInt64 (low ++ [last]) = deserializeInt64Nine last low.reverse := by
  simp [deserializeInt64, h]

/-- Exact acceptance at v1.2.3: short operands, or nine bytes with a pure sign
and a magnitude representable with that sign. [SRC] `6504a3af`,
`int_serialization.h:75–117`. Byte validity is needed for correspondence with
C++ bytes, not for this equality of the model's acceptance conditions. -/
theorem deserializeInt64_isSome_iff (b : Bytes) :
    (deserializeInt64 b).isSome = true ↔ b.length ≤ 8 ∨
      (b.length = 9 ∧ ∃ last rest, b.reverse = last :: rest ∧ last % 128 = 0 ∧
        (beNat rest < 2 ^ 63 ∨ (beNat rest = 2 ^ 63 ∧ 128 ≤ last))) := by
  by_cases h8 : b.length ≤ 8
  · simp [deserializeInt64, h8]
  · by_cases h9 : b.length = 9
    · cases hr : b.reverse with
      | nil => simp [deserializeInt64, h8, h9, hr]
      | cons last rest =>
        simp [deserializeInt64, h8, h9, hr, deserializeInt64Nine]
        split_ifs <;> simp_all
    · simp [deserializeInt64, h8, h9]

/-- A ninth byte carrying magnitude bits is refused even when the lower eight
bytes denote zero. [SRC] `6504a3af`, `int_serialization.h:83–84`. -/
theorem deserializeInt64_nine_magnitude_bits (low : Bytes) (last : Nat)
    (hlen : low.length = 8) (hbits : last % 128 ≠ 0) :
    deserializeInt64 (low ++ [last]) = none := by
  simp [deserializeInt64_nine low last hlen, deserializeInt64Nine, hbits]

/-- Fixed-length valid little-endian digits are unique, including zero padding.
This supplies byte uniqueness for the signed minimum without assuming minimal encoding. -/
theorem leNat_inj_of_length_eq (a b : Bytes) (ha : a.valid) (hb : b.valid)
    (hlen : a.length = b.length) (hval : leNat a = leNat b) : a = b := by
  induction a generalizing b with
  | nil => simpa using hlen.symm
  | cons x xs ih =>
    cases b with
    | nil => simp at hlen
    | cons y ys =>
      rw [valid_cons] at ha hb
      simp only [List.length_cons] at hlen
      simp only [leNat] at hval
      have hxy : x = y := by omega
      subst y
      congr 1
      exact ih ys ha.2 hb.2 (by omega) (by omega)

/-- At nine bytes the only encoding of the signed minimum is seven zero bytes,
`0x80`, then a negative sign byte `0x80`. [SRC] `6504a3af`,
`int_serialization.h:110–114`. The hypotheses say these are eight actual bytes
and an actual sign byte; no minimality assumption is imposed. -/
theorem deserializeInt64_nine_min_iff (low : Bytes) (last : Nat)
    (hlen : low.length = 8) (hv : low.valid) (hlast : last < 256) :
    deserializeInt64 (low ++ [last]) = some (-(2 ^ 63 : Int)) ↔
      low = [0, 0, 0, 0, 0, 0, 0, 128] ∧ last = 128 := by
  constructor
  · intro h
    rw [deserializeInt64_nine low last hlen] at h
    have hdata : last % 128 = 0 ∧ 128 ≤ last ∧ beNat low.reverse = 2 ^ 63 := by
      unfold deserializeInt64Nine at h
      dsimp only at h
      split_ifs at h <;> simp_all <;> omega
    have hs : last = 128 := by omega
    refine ⟨?_, hs⟩
    apply leNat_inj_of_length_eq low _ hv (by simp [Bytes.valid]) (by simpa using hlen)
    rw [← beNat_reverse, hdata.2.2]
    decide
  · rintro ⟨rfl, rfl⟩
    decide

/-- A valid sign-magnitude operand of at most eight bytes has magnitude strictly
below 2^63. [SRC] `6504a3af`, `int_serialization.h:94–107`: the top bit is sign.
Thus the signed minimum cannot be encoded without the extra sign byte. -/
theorem decode_natAbs_lt_int64_of_short (b : Bytes) (hv : b.valid) (hlen : b.length ≤ 8) :
    (decode b).natAbs < 2 ^ 63 := by
  have hvr := (valid_reverse b).mpr hv
  have hlr : b.reverse.length ≤ 8 := by simpa using hlen
  cases hr : b.reverse with
  | nil => simp [decode, decodeRev, hr]
  | cons last rest =>
    rw [hr, valid_cons] at hvr
    rw [hr, List.length_cons] at hlr
    have hrest := beNat_lt rest hvr.2
    have hp : 256 ^ rest.length ≤ 256 ^ 7 :=
      Nat.pow_le_pow_right (by decide) (by omega)
    have ht : last % 128 + 1 ≤ 128 := by omega
    have hm : beNat (last % 128 :: rest) < 2 ^ 63 := by
      rw [beNat_cons]
      calc
        last % 128 * 256 ^ rest.length + beNat rest
            < last % 128 * 256 ^ rest.length + 256 ^ rest.length := by omega
        _ = (last % 128 + 1) * 256 ^ rest.length := by ring
        _ ≤ 128 * 256 ^ rest.length := Nat.mul_le_mul_right _ ht
        _ ≤ 128 * 256 ^ 7 := Nat.mul_le_mul_left _ hp
        _ = 2 ^ 63 := by norm_num
    simp only [decode, hr, decodeRev]
    split <;> simpa using hm

/-- Over actual byte strings the signed minimum has exactly one accepted
encoding at v1.2.3. Short operands cannot reach its magnitude, and the ninth
byte must be the negative sign. [SRC] `6504a3af`, `int_serialization.h:80–117`. -/
theorem deserializeInt64_min_iff (b : Bytes) (hv : b.valid) :
    deserializeInt64 b = some (-(2 ^ 63 : Int)) ↔
      b = [0, 0, 0, 0, 0, 0, 0, 128, 128] := by
  constructor
  · intro h
    by_cases h8 : b.length ≤ 8
    · rw [deserializeInt64_eq_decode b h8] at h
      have hbound := decode_natAbs_lt_int64_of_short b hv h8
      simp only [Option.some.injEq] at h
      rw [h] at hbound
      norm_num at hbound
    · have h9 : b.length = 9 := by
        by_contra hn
        simp [deserializeInt64, h8, hn] at h
      cases hr : b.reverse with
      | nil => have := congrArg List.length hr; simp [h9] at this
      | cons last rest =>
        have hb : b = rest.reverse ++ [last] := by
          have he := congrArg List.reverse hr
          simpa using he
        have hl : rest.reverse.length = 8 := by
          have he := congrArg List.length hr
          simp [h9] at he
          simpa using he
        have hv' : Bytes.valid (last :: rest) := by
          rw [← hr, valid_reverse]; exact hv
        rw [valid_cons] at hv'
        rw [hb] at h
        obtain ⟨hlow, hlast⟩ := (deserializeInt64_nine_min_iff rest.reverse last hl
          ((valid_reverse rest).mpr hv'.2) hv'.1).mp h
        simp [hb, hlow, hlast]
  · rintro rfl
    decide

/-- A conversion failure is an overflow error when minimality does not already
refuse. A width failure has the same error. [SRC] `6504a3af`,
`script_num.cpp:62–87`; this states the constructor's error precedence. -/
theorem readNumInt64_of_none (b : Bytes) (rm : Bool) (maxLen : Nat)
    (hminimal : (rm && !isMinimallyEncoded b maxLen) = false)
    (hread : deserializeInt64 b = none) : readNumInt64 b rm maxLen = .error .overflow := by
  simp [readNumInt64, hminimal, hread]

-- ======================================================================================================
-- THE COMPILED IMPLEMENTATIONS (#45; S1, Lean A, 2026-09-26). The definitions above are the semantics and
-- do not move. Each function below is proven equal to one of them, and the `@[csimp]` attribute makes the
-- compiler substitute it at every call site compiled after it (the mechanism of Lean's own `List.take`,
-- `take_eq_takeTR` at `Init/Data/List/Impl.lean:210`, and `List.length`, `length_eq_lengthTR` at
-- `Init/Data/List/Basic.lean:2420`, in the pinned toolchain v4.34.0); every theorem in this file is about the
-- definitions. Two definitions compiled before the lemmas keep the definitions' folds, being bounded: `readNum`
-- (a CLTV or CSV operand, at most 5 bytes; the sigop count's, at most 4) and `deserializeInt64` (at most nine accepted bytes; longer operands refuse before decoding). Why: `beNat`'s fold
-- does one bignum multiplication per byte and `magBytesFuel` one bignum division and one predecessor per
-- byte (the fuel being the number itself), so a large number costs quadratic time and the resident set
-- grows with the byte count (4.74 GB at 50 KB: `docs/records/20260926-205320-ladder45-s1.md`); the halving
-- versions do a logarithmic number of operations of the number's size. Since #53 (2026-09-29) their leaves go
-- by 7-byte limbs (`beNatLimbs`, `fixedLELimbs`, `magBytesFast`'s limb branch): below `2^56` a number is an
-- unboxed scalar, so a big-number operation falls once per 7 bytes, where the per-byte leaves did one or three
-- per byte on the operands of a script's arithmetic (`docs/records/20260929-072759-impl-50-s1.md`). The
-- explainers were comments until 2026-09-27, when each theorem got its docstring
-- (rule 7); `spec/` is regenerated and committed with each landing. The copies at the end (`decodeRevFast` … `num2binFast`) are the
-- definitions restated after the csimp lemmas so their compiled code calls the fast leaves; each equality
-- is `rfl`.

/-- `beNat` of two halves is the high half shifted by the low half's width plus the low half (`foldl_beNat_acc`): the split rule the halving implementation of #45 rests on. -/
theorem beNat_append (l₁ l₂ : Bytes) : beNat (l₁ ++ l₂) = beNat l₁ * 256 ^ l₂.length + beNat l₂ := by
  simp only [beNat, List.foldl_append]
  exact foldl_beNat_acc l₂ _

/-- The limb fold of `beNat` (#53): the top-first list read byte by byte into a scalar limb `cur` of at most 7
bytes (`cnt` counts its bytes past the first; every intermediate below `2^56`, an unboxed scalar, so a byte allocates
nothing), the limb shifted into the accumulator `acc` once per 7 bytes; at the end `acc` shifted by the limb's width
plus `cur`. A big-number operation per 7 bytes, where the fold `beNat` does one per byte
(`docs/records/20260929-072759-impl-50-s1.md`: 669 of a 2 MB lock's 1,819 samples in that fold). Only small
constants appear (`6`, `56`, `8`): a literal of `2^32` or more compiles to a string conversion at each use. -/
def beNatLimbs : Nat → Nat → Nat → Bytes → Nat
  | acc, cur, cnt, [] => (acc <<< (8 * cnt)) + cur
  | acc, cur, cnt, b :: bs =>
    if cnt = 6 then beNatLimbs ((acc <<< 56) + (cur * 256 + b)) 0 0 bs
    else beNatLimbs acc (cur * 256 + b) (cnt + 1) bs

/-- **`beNatLimbs_eq`.** *What it says:* the limb fold from `(acc, cur, cnt)` is `acc * 256 ^ cnt + cur` shifted by
the list's width plus the list's `beNat`, whatever `cnt` (the test on it chooses only when a limb joins the
accumulator). *What it assumes:* nothing. *Why it matters:* from `(0, 0, 0)` it is `beNat` itself, the leaf
`beNatFast` runs (#53); by `beNat_cons` at each byte. -/
theorem beNatLimbs_eq (acc cur cnt : Nat) (l : Bytes) :
    beNatLimbs acc cur cnt l = (acc * 256 ^ cnt + cur) * 256 ^ l.length + beNat l := by
  induction l generalizing acc cur cnt with
  | nil =>
    simp only [beNatLimbs, beNat, List.foldl_nil, List.length_nil, pow_zero, mul_one, add_zero, Nat.shiftLeft_eq,
      pow_mul]
    norm_num
  | cons b bs ih =>
    rw [beNat_cons, List.length_cons, pow_succ]
    by_cases hc : cnt = 6
    · rw [beNatLimbs, ite_eq_left hc, ih, Nat.shiftLeft_eq, hc]
      ring
    · rw [beNatLimbs, ite_eq_right hc, ih, pow_succ]
      ring

-- `beNat` by halves (#45) over limb leaves (#53): at most 256 bytes by the limb fold, longer lists split at the middle.
def beNatFast (l : Bytes) : Nat :=
  if h : l.length ≤ 256 then beNatLimbs 0 0 0 l
  else beNatFast (l.take (l.length / 2)) * 256 ^ (l.length - l.length / 2) + beNatFast (l.drop (l.length / 2))
termination_by l.length
decreasing_by all_goals (simp only [List.length_take, List.length_drop]; omega)

/-- The halving `beNatFast` computes the fold `beNat`: its leaves by `beNatLimbs_eq` (#53), its splits by `beNat_append`; the definition stays the semantics, the halving over limbs is its compiled implementation. -/
theorem beNatFast_eq (l : Bytes) : beNatFast l = beNat l := by
  induction l using beNatFast.induct with
  | case1 l h => rw [beNatFast, dite_eq_left h, beNatLimbs_eq]; simp
  | case2 l h ih1 ih2 =>
    rw [beNatFast, dite_eq_right h, ih1, ih2]
    have := beNat_append (l.take (l.length / 2)) (l.drop (l.length / 2))
    rw [List.take_append_drop, List.length_drop] at this
    exact this.symm

/-- `@[csimp]` (#45): the compiler evaluates `beNat` as `beNatFast` in code compiled after this lemma (a csimp lemma does not reach code compiled before it: `decodeRev` is restated below for that reason, and `deserializeInt64`, whose folds read at most eight bytes at a time, has no copy), a linear number of operations at logarithmic depth (leaves of at most 256 bytes by the limb fold `beNatLimbs`, a big-number shift-add per 7 bytes since #53, joined by halves) instead of one multiplication per byte on a growing accumulator (the decode walls of `docs/records/20260926-205320-ladder45-s1.md` and `docs/records/20260929-072759-impl-50-s1.md`); nothing in the semantics moves, every theorem of this file is about `beNat`. -/
@[csimp] theorem beNat_eq_fast : @beNat = @beNatFast := funext fun l => (beNatFast_eq l).symm

-- Exactly `k` little-endian bytes of a number below `256^k`: the low half of a split of `magBytes`.
def fixedLE : Nat → Nat → Bytes
  | 0, _ => []
  | k + 1, m => (m % 256) :: fixedLE k (m / 256)

/-- `fixedLE k m` has exactly `k` bytes, whatever `m`. -/
theorem fixedLE_length (k m : Nat) : (fixedLE k m).length = k := by
  induction k generalizing m with
  | zero => rfl
  | succ k ih => simp [fixedLE, ih]

/-- Every byte of `fixedLE k m` is below 256 (`Bytes.valid`), each being a remainder modulo 256. -/
theorem fixedLE_valid (k m : Nat) : Bytes.valid (fixedLE k m) := by
  induction k generalizing m with
  | zero => exact valid_nil
  | succ k ih => rw [fixedLE, valid_cons]; exact ⟨Nat.mod_lt _ (by norm_num), ih _⟩

/-- `fixedLE` is the fixed-width little-endian encoding of its value: `leNat` reads back `m` when `m < 256^k`. -/
theorem leNat_fixedLE (k m : Nat) (h : m < 256 ^ k) : leNat (fixedLE k m) = m := by
  induction k generalizing m with
  | zero => simp only [fixedLE, leNat, Nat.pow_zero] at h ⊢; omega
  | succ k ih =>
    simp only [fixedLE, leNat]
    rw [ih (m / 256) (by rw [pow_succ] at h; omega)]
    omega

/-- The little-endian value of two halves: the low half's value plus the high half's value shifted by the low half's width. -/
theorem leNat_append (l₁ l₂ : Bytes) : leNat (l₁ ++ l₂) = leNat l₁ + 256 ^ l₁.length * leNat l₂ := by
  induction l₁ with
  | nil => simp [leNat]
  | cons b bs ih => simp only [List.cons_append, leNat, List.length_cons, ih, pow_succ]; ring

/-- The fixed-width bytes split at any width: the low `a` bytes of `m mod 256^a`, then the `b` bytes of the quotient `m / 256^a`. -/
theorem fixedLE_split (a b m : Nat) : fixedLE (a + b) m = fixedLE a (m % 256 ^ a) ++ fixedLE b (m / 256 ^ a) := by
  induction a generalizing m with
  | zero => simp [fixedLE]
  | succ a ih =>
    have h1 : m % 256 ^ (a + 1) % 256 = m % 256 := Nat.mod_mod_of_dvd m (dvd_pow_self 256 (Nat.succ_ne_zero a))
    have h2 : m % 256 ^ (a + 1) / 256 = m / 256 % 256 ^ a := by
      rw [pow_succ', Nat.mod_mul_right_div_self]
    have h3 : m / 256 ^ (a + 1) = m / 256 / 256 ^ a := by
      rw [Nat.div_div_eq_div_mul, ← pow_succ']
    rw [Nat.add_right_comm, fixedLE, fixedLE, ih (m / 256), h1, h2, h3, List.cons_append]

/-- **`fixedLE_mod`.** *What it says:* the `k` low bytes of a number are the `k` bytes of its remainder modulo
`256^k`. *What it assumes:* nothing. *Why it matters:* a limb's bytes are computed on its remainder, a scalar,
never on the whole number (#53). -/
theorem fixedLE_mod (k m : Nat) : fixedLE k m = fixedLE k (m % 256 ^ k) := by
  induction k generalizing m with
  | zero => rfl
  | succ k ih =>
    have h1 : m % 256 ^ (k + 1) % 256 = m % 256 := Nat.mod_mod_of_dvd m (dvd_pow_self 256 (Nat.succ_ne_zero k))
    have h2 : m % 256 ^ (k + 1) / 256 = m / 256 % 256 ^ k := by
      rw [pow_succ', Nat.mod_mul_right_div_self]
    rw [fixedLE, fixedLE, h1, h2, ih (m / 256), ih (m / 256 % 256 ^ k), Nat.mod_mod]

/-- **`mod56`.** *What it says:* the remainder modulo `1 <<< 56` is the remainder modulo `256^7`. *What it
assumes:* nothing. *Why it matters:* a limb is cut by a remainder whose modulus is one shift, a primitive, with no
literal of `2^32` or more, which would compile to a string conversion at each use (#53). -/
theorem mod56 (m : Nat) : m % (1 <<< 56) = m % 256 ^ 7 := by
  rw [Nat.shiftLeft_eq]
  norm_num

/-- **`two_pow_le_of_log2`.** *What it says:* a number whose `log2` is at least `k`, for `k` positive, is at least
`2^k`. *What it assumes:* `0 < k` and `¬ m.log2 < k`. *Why it matters:* `magBytesFast` tests a size by `Nat.log2`,
a primitive, where a test against `2^k` would build that number at each call (#53). -/
theorem two_pow_le_of_log2 (k m : Nat) (hk : 0 < k) (h : ¬ m.log2 < k) : 2 ^ k ≤ m := by
  have hm : m ≠ 0 := by
    rintro rfl
    exact h (by simp [Nat.log2_zero]; omega)
  exact Nat.le_of_not_lt fun hlt => h ((Nat.log2_lt hm).mpr hlt)

/-- **`shift56`.** *What it says:* the shift right by 56 bits is the quotient by `256^7`. *What it assumes:*
nothing. *Why it matters:* the next limb is reached by one shift, a primitive, not a division (#53). -/
theorem shift56 (m : Nat) : m >>> 56 = m / 256 ^ 7 := by
  rw [Nat.shiftRight_eq_div_pow]
  norm_num

/-- `fixedLE` by 7-byte limbs (#53): each limb's 7 bytes computed on its low 56 bits (a remainder, a scalar), the
number shifted right by 56 bits once per limb. -/
def fixedLELimbs (k m : Nat) : Bytes :=
  if k ≤ 7 then fixedLE k (m % 256 ^ k)
  else fixedLE 7 (m % (1 <<< 56)) ++ fixedLELimbs (k - 7) (m >>> 56)
termination_by k
decreasing_by omega

/-- **`fixedLELimbs_eq`.** *What it says:* the limb form computes `fixedLE`. *What it assumes:* nothing. *Why it
matters:* the leaf `fixedLEFast` runs (#53); by `fixedLE_mod`, `mod56`, `shift56` and `fixedLE_split` at 7. -/
theorem fixedLELimbs_eq (k m : Nat) : fixedLELimbs k m = fixedLE k m := by
  induction k, m using fixedLELimbs.induct with
  | case1 k m h => rw [fixedLELimbs, ite_eq_left h, ← fixedLE_mod]
  | case2 k m h ih =>
    rw [fixedLELimbs, ite_eq_right h, ih, mod56, shift56]
    have := fixedLE_split 7 (k - 7) m
    rw [show 7 + (k - 7) = k by omega] at this
    exact this.symm

-- `fixedLE` by halves (#45) over limb leaves (#53): widths of at most 256 bytes by limbs, longer ones split.
def fixedLEFast (k m : Nat) : Bytes :=
  if _h : k ≤ 256 then fixedLELimbs k m
  else fixedLEFast (k / 2) (m % 256 ^ (k / 2)) ++ fixedLEFast (k - k / 2) (m / 256 ^ (k / 2))
termination_by k
decreasing_by all_goals omega

/-- The halving `fixedLEFast` computes `fixedLE` (widths of at most 256 bytes by `fixedLELimbs_eq`, longer ones by `fixedLE_split` at the middle). -/
theorem fixedLEFast_eq (k m : Nat) : fixedLEFast k m = fixedLE k m := by
  induction k, m using fixedLEFast.induct with
  | case1 k m h => rw [fixedLEFast, dite_eq_left h, fixedLELimbs_eq]
  | case2 k m h ih1 ih2 =>
    rw [fixedLEFast, dite_eq_right h, ih1, ih2, ← fixedLE_split]
    congr 1; omega

-- Half the byte count of a number (from `Nat.log2`, a primitive): the split point of `magBytesFast`.
def splitWidth (m : Nat) : Nat := (Nat.log2 m / 8 + 1) / 2

/-- For a number of at least 257 bits (the hypothesis `2 ^ 256 ≤ m`) the split point `splitWidth m` (half its byte count, from `Nat.log2`) is at least one byte and `256^(splitWidth m) ≤ m`, so the quotient at the split is non-zero and strictly smaller: the measure of `magBytesFast`'s recursion. -/
theorem splitWidth_le (m : Nat) (hm : 2 ^ 256 ≤ m) : 256 ^ splitWidth m ≤ m ∧ 1 ≤ splitWidth m := by
  have hm0 : m ≠ 0 := Nat.pos_iff_ne_zero.mp (Nat.lt_of_lt_of_le (Nat.two_pow_pos 256) hm)
  have hlog : 256 ≤ Nat.log2 m := (Nat.le_log2 hm0).mpr hm
  refine ⟨?_, by unfold splitWidth; omega⟩
  have h8 : 8 * splitWidth m ≤ Nat.log2 m := by unfold splitWidth; omega
  calc 256 ^ splitWidth m = 2 ^ (8 * splitWidth m) := by rw [Nat.pow_mul]
    _ ≤ 2 ^ Nat.log2 m := Nat.pow_le_pow_right (by norm_num) h8
    _ ≤ m := Nat.log2_self_le hm0

/-- The minimal magnitude bytes split at `256^k` when the quotient is non-zero: the low `k` bytes at fixed width, then the minimal bytes of the quotient (the digits of a magnitude are unique, `magBytes_leNat`). -/
theorem magBytes_split (m k : Nat) (h : 256 ^ k ≤ m) :
    magBytes m = fixedLE k (m % 256 ^ k) ++ magBytes (m / 256 ^ k) := by
  have hpos : 0 < 256 ^ k := Nat.pow_pos (by norm_num)
  have hq : m / 256 ^ k ≠ 0 := (Nat.div_pos h hpos).ne'
  obtain ⟨t, rest, hrev, ht, _⟩ := magBytes_reverse_head (m / 256 ^ k) hq
  have hmb : magBytes (m / 256 ^ k) = rest.reverse ++ [t] := by
    rw [← List.reverse_reverse (magBytes _), hrev, List.reverse_cons]
  have hval : Bytes.valid (fixedLE k (m % 256 ^ k) ++ magBytes (m / 256 ^ k)) := by
    intro b hb
    rw [List.mem_append] at hb
    rcases hb with hb | hb
    · exact fixedLE_valid k _ b hb
    · exact magBytes_valid _ b hb
  have hnz : lastNZ (fixedLE k (m % 256 ^ k) ++ magBytes (m / 256 ^ k)) = true := by
    rw [hmb, ← List.append_assoc, lastNZ_append_single]; simpa using ht
  have hle : leNat (fixedLE k (m % 256 ^ k) ++ magBytes (m / 256 ^ k)) = m := by
    rw [leNat_append, fixedLE_length, leNat_fixedLE _ _ (Nat.mod_lt _ hpos), leNat_magBytes, Nat.mod_add_div]
  rw [← magBytes_leNat _ hval hnz, hle]

-- `magBytes` by limbs and halves (#45, #53): below `2^56` the direct recursion on a scalar, below `2^2048` the low
-- 7-byte limb cut by a remainder and the rest reached by a shift, larger numbers split at `splitWidth`; each size
-- tested by `Nat.log2`.
def magBytesFast (m : Nat) : Bytes :=
  if _h : m.log2 < 56 then magBytesFuel m m
  else if _h2 : m.log2 < 2048 then fixedLE 7 (m % (1 <<< 56)) ++ magBytesFast (m >>> 56)
  else fixedLEFast (splitWidth m) (m % 256 ^ splitWidth m) ++ magBytesFast (m / 256 ^ splitWidth m)
termination_by m
decreasing_by
  · have h56 := two_pow_le_of_log2 56 m (by decide) _h
    rw [shift56]; exact Nat.div_lt_self (by omega) (by norm_num)
  · have hs := splitWidth_le m (two_pow_le_of_log2 256 m (by decide) (by omega))
    exact Nat.div_lt_self (Nat.lt_of_lt_of_le (Nat.pow_pos (by norm_num)) hs.1) (Nat.one_lt_pow (by omega) (by norm_num))

/-- The limb and halving `magBytesFast` computes `magBytes`: below `2^56` by the direct recursion, below `2^2048` by `magBytes_split` at 7 bytes with `mod56` and `shift56` (#53), larger numbers by `magBytes_split` at `splitWidth`. -/
theorem magBytesFast_eq (m : Nat) : magBytesFast m = magBytes m := by
  induction m using magBytesFast.induct with
  | case1 m h => rw [magBytesFast, dite_eq_left h]; rfl
  | case2 m h h2 ih =>
    rw [magBytesFast, dite_eq_right h, dite_eq_left h2, ih, mod56, shift56]
    have h56 := two_pow_le_of_log2 56 m (by decide) h
    exact (magBytes_split m 7 (by norm_num at h56 ⊢; omega)).symm
  | case3 m h h2 ih =>
    rw [magBytesFast, dite_eq_right h, dite_eq_right h2, fixedLEFast_eq, ih]
    have h256 : 2 ^ 256 ≤ m := two_pow_le_of_log2 256 m (by decide) (by omega)
    exact (magBytes_split m _ (splitWidth_le m h256).1).symm

/-- `@[csimp]` (#45, #53): the compiler evaluates `magBytes` as `magBytesFast` in code compiled after this lemma (the encode walls: `magBytesFuel` does one bignum division, one remainder and one predecessor per byte with the number itself as fuel; #45's ladder record's 4.743 GB at 50 KB, `docs/records/20260926-205320-ladder45-s1.md`, is the decode and the encode together, its `number` entry reading and writing one 50 KB number, and #50's record finds the fuel's predecessor alone in 427 of a 2 MB lock's 1,819 samples, `docs/records/20260929-072759-impl-50-s1.md`); since #53 the fuel runs on scalars only; nothing in the semantics moves. -/
@[csimp] theorem magBytes_eq_fast : @magBytes = @magBytesFast := funext fun m => (magBytesFast_eq m).symm

-- The copies: `decodeRev`, `decode`, `encode`, `minimallyEncode`, `num2bin` restated after the csimp lemmas.
def decodeRevFast : Bytes → Nat × Bool
  | [] => (0, false)
  | t :: rest => (beNat (t % 128 :: rest), 128 ≤ t)

/-- `@[csimp]`: `decodeRev` restated after `beNat`'s csimp lemma so its compiled code calls the fast leaf (a csimp lemma applies only to code compiled after it); the same term, `rfl` per case. -/
@[csimp] theorem decodeRev_eq_fast : @decodeRev = @decodeRevFast := by
  funext bs; cases bs <;> rfl

def decodeFast (bs : Bytes) : Int :=
  let r := decodeRev bs.reverse
  if r.2 then -(r.1 : Int) else (r.1 : Int)

/-- `@[csimp]`: `decode` restated after the csimp lemmas of what it calls; the same term (`rfl`). -/
@[csimp] theorem decode_eq_fast : @decode = @decodeFast := rfl

def encodeFast (v : Int) : Bytes :=
  if v = 0 then [] else (signTopRev (magBytes v.natAbs).reverse (decide (v < 0))).reverse

/-- `@[csimp]`: `encode` restated after `magBytes`'s csimp lemma; the same term (`rfl`). -/
@[csimp] theorem encode_eq_fast : @encode = @encodeFast := rfl

def minimallyEncodeFast (bs : Bytes) : Bytes := encode (decode bs)

/-- `@[csimp]`: `minimallyEncode` restated after `encode`'s and `decode`'s; the same term (`rfl`). -/
@[csimp] theorem minimallyEncode_eq_fast : @minimallyEncode = @minimallyEncodeFast := rfl

def num2binFast (bs : Bytes) (width : Nat) : Option Bytes :=
  if width < (minimallyEncode bs).length then none
  else if (minimallyEncode bs).length = width then some (minimallyEncode bs)
  else some (num2binPad (minimallyEncode bs) width)

/-- `@[csimp]`: `num2bin` restated after `minimallyEncode`'s; the same term (`rfl`), so `OP_NUM2BIN` on a large element runs the fast leaves too. -/
@[csimp] theorem num2bin_eq_fast : @num2bin = @num2binFast := rfl

end BsvScript.Numbers
