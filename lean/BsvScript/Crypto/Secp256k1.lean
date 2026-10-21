import BsvScript.Numbers
/-!
# BsvScript.Crypto.Secp256k1

The curve and the ECDSA equation, executable (#11; `docs/DESIGN.md` §4.1). The
reference verifies through libsecp256k1 (`src/secp256k1`, vendored at the pin):
point decoding `secp256k1_eckey_pubkey_parse` (`eckey_impl.h:17–35`; the
cofactor is 1, `secp256k1_ge_is_in_correct_subgroup` is the identity outside
exhaustive tests, `group_impl.h:893–915`, its non-exhaustive branch `908–914`), the compact parse with its overflow
rule (`secp256k1.c:397–416`: `r` or `s` at or above `n` is an overflow), the
normalization of `s` (`secp256k1.c:443–460`: a high `s` is replaced by `n − s`),
and the equation `secp256k1_ecdsa_sig_verify` (`ecdsa_impl.h:195–262`):
`r ≠ 0 ∧ s ≠ 0`; `u₁ = z·s⁻¹`, `u₂ = r·s⁻¹` mod `n`; `R = u₁·G + u₂·Q ≠ O`; then
`R.x = r` or (`r + n < p` and `R.x = r + n`), that is `R.x mod n = r` since
`2n > p` (`228–261`). `secp256k1_ecdsa_verify` (`secp256k1.c:462–476`) also
requires a low `s`, which holds after the normalization the reference applies
first (`pubkey.cpp:207–213`).

The field is `F_p` on `Nat` with `p = 2²⁵⁶ − 2³² − 977`; the points are
Jacobian triples with the point at infinity as `none`; the scalar
multiplication is double-and-add over the 256 bits. Every function is a
definition: the spec carries no axiom for the curve (Q9, ruled (A) by the maintainers
on archived #38, 2026-09-22; `docs/HYPOTHESES.md` keeps both readings).

What is transcribed with its lines, and what is not: the point decoding, the lax
DER parser, the normalization of `s` and the equation follow the reference's code
with its lines. The field and group arithmetic computes the same values by other
means and is NOT a line-by-line transcription: the inverses by Fermat (`invN`, the
scalar inverse, for the reference's `secp256k1_scalar_inverse_var`, `ecdsa_impl.h:208`;
`invP`, the field inverse in `toAffine`, has no counterpart on the reference's
verification path, which compares `R.x` in Jacobian coordinates to avoid the inversion,
`ecdsa_impl.h:233–248`, the equivalence above), the square
root by `powMod` to `(p + 1) / 4` (the reference reaches the same exponent by an
addition chain, `field_impl.h:33–142`), the doubling by the textbook formula for
`a = 0` (a different Jacobian representative of the same point than
`secp256k1_gej_double`'s, `group_impl.h:429–462`), the scalar multiplication by
double-and-add (the reference's `secp256k1_ecmult`, `ecdsa_impl.h:212`). The
addition follows `secp256k1_gej_add_var` (`group_impl.h:495–557`). The evidence
that the values agree is the tests (`lean/Test/CryptoCheck.lean`).
-/

namespace BsvScript.Crypto.Secp256k1
open BsvScript.Numbers

/-- The field prime `p` (`field.h`). -/
def p : Nat := 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
/-- The group order `n` (`scalar_4x64_impl.h`). -/
def n : Nat := 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
/-- The generator `G` (`SECP256K1_G`, `group_impl.h:36–41`, bound as `secp256k1_ge_const_g` at `:70` with
`SECP256K1_B 7` at `:71`). -/
def Gx : Nat := 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
def Gy : Nat := 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8

/-- Modular exponentiation by squaring (executable on 256-bit `Nat`). -/
def powMod (b e m : Nat) : Nat :=
  let rec go (b e acc : Nat) (fuel : Nat) : Nat :=
    match fuel with
    | 0 => acc
    | fuel + 1 =>
      if e = 0 then acc
      else
        let acc := if e % 2 = 1 then acc * b % m else acc
        go (b * b % m) (e / 2) acc fuel
  go (b % m) e (1 % m) 512

/-- The inverse in `F_p` by Fermat (`x^(p−2)`); `0` maps to `0`. -/
def invP (x : Nat) : Nat := powMod x (p - 2) p
/-- The inverse mod `n`. -/
def invN (x : Nat) : Nat := powMod x (n - 2) n

/-- A square root in `F_p` (`p ≡ 3 mod 4`: `a^((p+1)/4)`), `none` when `a` is not a square
(the value of `secp256k1_fe_sqrt`, which reaches the same exponent by an addition chain,
`field_impl.h:33–142`). -/
def sqrtP (a : Nat) : Option Nat :=
  let r := powMod a ((p + 1) / 4) p
  if r * r % p = a % p then some r else none

/-- A Jacobian point `(X, Y, Z)` = affine `(X/Z², Y/Z³)`; `none` is the point at infinity. -/
abbrev Point := Option (Nat × Nat × Nat)

def ofAffine (x y : Nat) : Point := some (x, y, 1)

/-- The affine coordinates of a point (`secp256k1_ge_set_gej`). -/
def toAffine : Point → Option (Nat × Nat)
  | none => none
  | some (x, y, z) =>
    let zi := invP z
    let zi2 := zi * zi % p
    some (x * zi2 % p, y * zi2 % p * zi % p)

/-- Point doubling in Jacobian coordinates (`a = 0`), by the textbook formula: the point
`secp256k1_gej_double` computes (`group_impl.h:429–462`), as a different Jacobian representative. -/
def double : Point → Point
  | none => none
  | some (x, y, z) =>
    if y = 0 then none
    else
      let y2 := y * y % p
      let s := 4 * x % p * y2 % p
      let m := 3 * (x * x % p) % p
      let x' := (m * m % p + 2 * (p - s)) % p
      let y' := (m * ((s + p - x') % p) % p + p - 8 * (y2 * y2 % p) % p) % p
      let z' := 2 * y % p * z % p
      some (x', y', z')

/-- Point addition in Jacobian coordinates (`secp256k1_gej_add_var`). -/
def add : Point → Point → Point
  | none, q => q
  | q, none => q
  | some (x1, y1, z1), some (x2, y2, z2) =>
    let z1z1 := z1 * z1 % p
    let z2z2 := z2 * z2 % p
    let u1 := x1 * z2z2 % p
    let u2 := x2 * z1z1 % p
    let s1 := y1 * z2 % p * z2z2 % p
    let s2 := y2 * z1 % p * z1z1 % p
    if u1 = u2 then
      if s1 = s2 then double (some (x1, y1, z1)) else none
    else
      let h := (u2 + p - u1) % p
      let r := (s2 + p - s1) % p
      let h2 := h * h % p
      let h3 := h2 * h % p
      let u1h2 := u1 * h2 % p
      let x3 := (r * r % p + p - h3 + 2 * (p - u1h2)) % p
      let y3 := (r * ((u1h2 + p - x3) % p) % p + p - s1 * h3 % p) % p
      let z3 := z1 * z2 % p * h % p
      some (x3, y3, z3)

/-- Scalar multiplication, double-and-add over the bits of `k` (most significant first); the
reference's value by `secp256k1_ecmult` (`ecdsa_impl.h:212`), computed otherwise. -/
def mul (k : Nat) (q : Point) : Point :=
  let rec go (i : Nat) (acc : Point) : Point :=
    match i with
    | 0 => acc
    | i + 1 =>
      let acc := double acc
      let acc := if Nat.testBit k i then add acc q else acc
      go i acc
  go 256 none

def G : Point := ofAffine Gx Gy

/-- Is the affine point on the curve `y² = x³ + 7` (`secp256k1_ge_is_valid_var`, `group_impl.h:415–428`)? -/
def onCurve (x y : Nat) : Bool := y * y % p = (x * x % p * x % p + 7) % p

/-- A 32-byte big-endian field element below `p` (`secp256k1_fe_set_b32_limit`). -/
def fe (bs : Bytes) : Option Nat :=
  let v := bs.foldl (fun acc b => acc * 256 + b) 0
  if v < p then some v else none

/-- `secp256k1_eckey_pubkey_parse` (`eckey_impl.h:17–35`): 33 bytes `02`/`03`
give `x` and the `y` of that parity from the square root; 65 bytes `04`/`06`/`07`
give `x` and `y`, which must lie on the curve, and for the hybrid tags `06`/`07`
the parity of `y` must match the tag. -/
def decodePubKey (bs : Bytes) : Option Point :=
  match bs with
  | tag :: rest =>
    if rest.length = 32 && (tag = 2 || tag = 3) then
      match fe rest with
      | none => none
      | some x =>
        match sqrtP ((x * x % p * x % p + 7) % p) with
        | none => none
        | some y =>
          let y := if (y % 2 = 1) = (tag = 3) then y else p - y
          some (ofAffine x y)
    else if rest.length = 64 && (tag = 4 || tag = 6 || tag = 7) then
      match fe (rest.take 32), fe (rest.drop 32) with
      | some x, some y =>
        if (tag = 6 || tag = 7) && ((y % 2 = 1) != (tag = 7)) then none
        else if onCurve x y then some (ofAffine x y) else none
      | _, _ => none
    else none
  | [] => none

/-- A big-endian integer of a byte string. -/
def beNat (bs : Bytes) : Nat := bs.foldl (fun acc b => acc * 256 + b) 0

/-- The length of `r` or of `s` as the lax parser reads it (`pubkey.cpp:68–97` for `r`,
`108–137` for `s`): a short form byte, or a long form whose leading zero bytes are
skipped (`79–82`, `119–122`) and whose remaining bytes must be fewer than
`sizeof(size_t)` (`83–85`, `123–125`), which is 8 on the pinned 64-bit build (the literal
`8` below); `none` when the bytes run out: no length byte (`69–71` for `r`, `109–111` for `s`) or a
long form's bytes past the end (`76–78`, `116–118`). Returns the length and the
bytes consumed. The SEQUENCE length is read otherwise (`laxSeqLength`). -/
def laxLength (bs : Bytes) : Option (Nat × Nat) :=
  match bs with
  | [] => none
  | b :: rest =>
    if b < 128 then some (b, 1)
    else
      let cnt := b - 128
      if rest.length < cnt then none
      else
        let digits := (rest.take cnt).dropWhile (· = 0)
        if 8 ≤ digits.length then none
        else some (beNat digits, 1 + cnt)

/-- The SEQUENCE length as the lax parser reads it (`pubkey.cpp:48–60`): a short form
byte, or a long form whose length bytes are skipped UNREAD, only their count checked
against the input (`56–58`): no leading-zero rule and no `sizeof(size_t)` rule, which
hold for `r` and `s` alone (`laxLength`). `none` when the byte or the skipped bytes run
out. Returns the bytes consumed. -/
def laxSeqLength (bs : Bytes) : Option Nat :=
  match bs with
  | [] => none
  | b :: rest =>
    if b < 128 then some 1
    else if rest.length < b - 128 then none
    else some (1 + (b - 128))

/-- `ecdsa_signature_parse_der_lax` (`pubkey.cpp:32–175`): `30` (`43–46`), the
sequence length, never read as a value (`48–60`, `laxSeqLength`), `02`, `r`'s length,
`r`, `02`, `s`'s length, `s` (`62–137`, `laxLength`); trailing bytes are ignored;
`none` when the shape fails; leading zeros of `r` and `s` dropped; more than 32 bytes
left, or a value at or above `n`, makes the whole signature the zero pair (`139–173`,
the compact parse `secp256k1.c:397–416`). -/
def parseDerLax (sig : Bytes) : Option (Nat × Nat) := do
  guard (sig.headD 0 = 0x30 && !sig.isEmpty)
  let s1 := sig.drop 1
  let k1 ← laxSeqLength s1
  let s2 := s1.drop k1
  guard (s2.headD 0 = 0x02 && !s2.isEmpty)
  let s3 := s2.drop 1
  let (rlen, k2) ← laxLength s3
  let s4 := s3.drop k2
  guard (rlen ≤ s4.length)
  let rBytes := s4.take rlen
  let s5 := s4.drop rlen
  guard (s5.headD 0 = 0x02 && !s5.isEmpty)
  let s6 := s5.drop 1
  let (slen, k3) ← laxLength s6
  let s7 := s6.drop k3
  guard (slen ≤ s7.length)
  let sBytes := s7.take slen
  let r := rBytes.dropWhile (· = 0)
  let s := sBytes.dropWhile (· = 0)
  let overflow := 32 < r.length || 32 < s.length || n ≤ beNat r || n ≤ beNat s
  pure (if overflow then (0, 0) else (beNat r, beNat s))

/-- `secp256k1_scalar_is_high`: `s > (n − 1) / 2`. -/
def isHighS (s : Nat) : Bool := (n - 1) / 2 < s

/-- The normalization (`secp256k1.c:443–460`): a high `s` becomes `n − s`. -/
def normalizeS (s : Nat) : Nat := if isHighS s then n - s else s

/-- The ECDSA equation (`ecdsa_impl.h:195–262`) on a decoded point, the digest
as a number reduced mod `n` (`secp256k1_scalar_set_b32`), and the pair `(r, s)`
with `s` already low. -/
def ecdsaEquation (q : Point) (z r s : Nat) : Bool :=
  if r = 0 || s = 0 || n ≤ r || n ≤ s then false
  else
    let sInv := invN s
    let u1 := z % n * sInv % n
    let u2 := r * sInv % n
    match toAffine (add (mul u1 G) (mul u2 q)) with
    | none => false
    | some (rx, _) => rx % n = r

/-- `CPubKey::Verify` (`pubkey.cpp:183–214`): a non-empty key that decodes, a
non-empty signature that lax-parses, `s` normalized, then the equation with a
low `s` (`secp256k1_ecdsa_verify`, `secp256k1.c:462–476`). `hash` is the
32-byte digest. -/
def verify (pubkey sig hash : Bytes) : Bool :=
  if pubkey.isEmpty then false
  else
    match decodePubKey pubkey with
    | none => false
    | some q =>
      if sig.isEmpty then false
      else
        match parseDerLax sig with
        | none => false
        | some (r, s) => ecdsaEquation q (beNat hash) r (normalizeS s)

/-- `CPubKey::CheckLowS` (`pubkey.cpp:353–363`): the lax parse then `!normalize`;
a signature that does not lax-parse fails; an overflowed `r` or `s` is zero,
which is low. -/
def checkLowS (sig : Bytes) : Bool :=
  match parseDerLax sig with
  | none => false
  | some (_, s) => !isHighS s

end BsvScript.Crypto.Secp256k1

namespace BsvScript.Crypto.Secp256k1

/-- T-EC1: the normalization yields a low `s` for any `s` below `n`
(`secp256k1.c:443–460`; `n` is odd, so `n − s ≤ (n − 1) / 2` when `s > (n − 1) / 2`). -/
theorem normalizeS_low (s : Nat) (h : s < n) : isHighS (normalizeS s) = false := by
  unfold normalizeS
  by_cases hh : isHighS s
  · rw [ite_eq_left hh]
    unfold isHighS at hh ⊢
    unfold n at *
    simp only [decide_eq_true_eq] at hh
    simp only [decide_eq_false_iff_not, not_lt]
    omega
  · rw [ite_eq_right hh]
    simpa using hh

end BsvScript.Crypto.Secp256k1
