import BsvScript.Hash.Sha256
/-!
# BsvScript.Hash.Ripemd160

RIPEMD-160, executable, for `OP_RIPEMD160` and `OP_HASH160`
(`interpreter.cpp:1402–1443`; `CHash160` = RIPEMD-160 of SHA-256, `src/hash.h:59–84`).
Transcribed from the reference's `src/crypto/ripemd160.cpp`: the five functions
(`src/crypto/ripemd160.cpp:17–29`), the initial state (`Initialize`, `src/crypto/ripemd160.cpp:32–40`), the round `a = rol(a + f + x + k, r) + e;
c = rol(c, 10)` (`Round`, `src/crypto/ripemd160.cpp:46–50`), the constants of the ten round groups (`R11`…`R52`,
`src/crypto/ripemd160.cpp:52–92`), the message-word order and rotation amounts of the two lines (the 160 `R` calls of
`Transform`, `src/crypto/ripemd160.cpp:110–273`, extracted by `tools/ripemd_tables.py`), the final
combination (`src/crypto/ripemd160.cpp:276–281`), and the padding with a little-endian length
(`Finalize`, `src/crypto/ripemd160.cpp:335–350`).
-/

namespace BsvScript.Hash

namespace Ripemd160

def rotl (x : UInt32) (n : Nat) : UInt32 := (x <<< n.toUInt32) ||| (x >>> (32 - n).toUInt32)

/-- `f1` … `f5` (`ripemd160.cpp:17–29`). -/
def f1 (x y z : UInt32) : UInt32 := x ^^^ y ^^^ z
def f2 (x y z : UInt32) : UInt32 := (x &&& y) ||| ((~~~x) &&& z)
def f3 (x y z : UInt32) : UInt32 := (x ||| (~~~y)) ^^^ z
def f4 (x y z : UInt32) : UInt32 := (x &&& z) ||| (y &&& (~~~z))
def f5 (x y z : UInt32) : UInt32 := x ^^^ (y ||| (~~~z))

/-- The function and constant of round `j` (0–79) on the left line (`R11` … `R51`). -/
def fL (j : Nat) (x y z : UInt32) : UInt32 :=
  if j < 16 then f1 x y z else if j < 32 then f2 x y z else if j < 48 then f3 x y z
  else if j < 64 then f4 x y z else f5 x y z
def kL (j : Nat) : UInt32 :=
  if j < 16 then 0 else if j < 32 then 0x5A827999 else if j < 48 then 0x6ED9EBA1
  else if j < 64 then 0x8F1BBCDC else 0xA953FD4E
/-- The function and constant of round `j` on the right line (`R12` … `R52`). -/
def fR (j : Nat) (x y z : UInt32) : UInt32 :=
  if j < 16 then f5 x y z else if j < 32 then f4 x y z else if j < 48 then f3 x y z
  else if j < 64 then f2 x y z else f1 x y z
def kR (j : Nat) : UInt32 :=
  if j < 16 then 0x50A28BE6 else if j < 32 then 0x5C4DD124 else if j < 48 then 0x6D703EF3
  else if j < 64 then 0x7A6D76E9 else 0

/-- The message-word order and rotation amounts (`tools/ripemd_tables.py` from `Transform`). -/
def wordsL : List Nat := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8, 3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12, 1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2, 4, 0, 5, 9, 7, 12, 2, 10, 14, 1, 3, 8, 11, 6, 15, 13]
def shiftsL : List Nat := [11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8, 7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12, 11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5, 11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12, 9, 15, 5, 11, 6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6]
def wordsR : List Nat := [5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12, 6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2, 15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13, 8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14, 12, 15, 10, 4, 1, 5, 8, 7, 6, 2, 13, 14, 0, 3, 9, 11]
def shiftsR : List Nat := [8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6, 9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11, 9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5, 15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8, 8, 5, 12, 9, 12, 5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11]

def H0 : Array UInt32 := #[0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]

/-- A 64-byte block as sixteen little-endian words (the sixteen `ReadLE32` reads of `Transform`, `src/crypto/ripemd160.cpp:100–107`). -/
def blockWordsLE (block : List Nat) : Array UInt32 :=
  let rec go : List Nat → Array UInt32 → Array UInt32
    | a :: b :: c :: d :: rest, acc =>
      go rest (acc.push (UInt32.ofNat (a + b * 256 + c * 65536 + d * 16777216)))
    | _, acc => acc
  go block #[]

/-- One line of 80 rounds: `T = rol(a + f(b,c,d) + X[w] + k, s) + e; a = e; e = d; d = rol(c, 10); c = b; b = T`. -/
def line (f : Nat → UInt32 → UInt32 → UInt32 → UInt32) (k : Nat → UInt32) (words shifts : List Nat)
    (x : Array UInt32) (h : Array UInt32) : Array UInt32 :=
  let rec go (a b c d e : UInt32) (j : Nat) : UInt32 × UInt32 × UInt32 × UInt32 × UInt32 :=
    if j < 80 then
      let t := rotl (a + f j b c d + x[words.getD j 0]! + k j) (shifts.getD j 0) + e
      go e t b (rotl c 10) d (j + 1)
    else (a, b, c, d, e)
  termination_by 80 - j
  let (a, b, c, d, e) := go h[0]! h[1]! h[2]! h[3]! h[4]! 0
  #[a, b, c, d, e]

/-- The transform (`Transform`, `src/crypto/ripemd160.cpp:95–283`): both lines from the same state, then the combination
`s0' = s1 + c1 + d2; s1' = s2 + d1 + e2; s2' = s3 + e1 + a2; s3' = s4 + a1 + b2; s4' = s0 + b1 + c2`. -/
def compress (h : Array UInt32) (x : Array UInt32) : Array UInt32 :=
  let l := line fL kL wordsL shiftsL x h
  let r := line fR kR wordsR shiftsR x h
  #[h[1]! + l[2]! + r[3]!, h[2]! + l[3]! + r[4]!, h[3]! + l[4]! + r[0]!, h[4]! + l[0]! + r[1]!, h[0]! + l[1]! + r[2]!]

def blocks (h : Array UInt32) : List Nat → Array UInt32
  | [] => h
  | b :: tl =>
    let block := (b :: tl).take 64
    blocks (compress h (blockWordsLE block)) ((b :: tl).drop 64)
termination_by msg => msg.length
decreasing_by all_goals simp [List.length_drop]

/-- The padding (`src/crypto/ripemd160.cpp:337–342`, in `Finalize`, `src/crypto/ripemd160.cpp:335–350`): `0x80`, zeros to 56 mod 64, the bit length little-endian. -/
def padLE (msg : List Nat) : List Nat :=
  let len := msg.length
  let bitLen := len * 8
  let zeros := (55 + 64 - len % 64) % 64
  let lenBytes := (List.range 8).map (fun i => bitLen / 256 ^ i % 256)
  msg ++ [0x80] ++ List.replicate zeros 0 ++ lenBytes

/-- A word as four little-endian bytes (`WriteLE32`). -/
def wordBytesLE (x : UInt32) : List Nat :=
  let n := x.toNat
  [n % 256, n / 256 % 256, n / 65536 % 256, n / 16777216 % 256]

end Ripemd160

/-- RIPEMD-160 of a byte list: 20 bytes. -/
def ripemd160 (msg : List Nat) : List Nat :=
  ((Ripemd160.blocks Ripemd160.H0 (Ripemd160.padLE msg)).toList.map Ripemd160.wordBytesLE).flatten

/-- `CHash160` (`src/hash.h:59–84`): RIPEMD-160 of SHA-256. -/
def hash160 (msg : List Nat) : List Nat := ripemd160 (sha256 msg)

/-- `CHash256` (`src/hash.h:24–56`): `sha256d`. -/
def hash256 (msg : List Nat) : List Nat := sha256d msg

end BsvScript.Hash

namespace BsvScript.Hash

/-- **One compression keeps a 5-word state.** *What it says:* `Ripemd160.compress` returns
an array of size 5 for any state and block. *What it assumes:* nothing. *Why it matters:*
it is the step of T-RMD1's induction (`Ripemd160.blocks_size`), which T-RMD2's 20-byte
digest rests on. -/
theorem Ripemd160.compress_size (h x : Array UInt32) : (Ripemd160.compress h x).size = 5 := by
  simp [Ripemd160.compress]

/-- T-RMD1: RIPEMD-160 keeps a 5-word state. -/
theorem Ripemd160.blocks_size (h : Array UInt32) (msg : List Nat) (hh : h.size = 5) :
    (Ripemd160.blocks h msg).size = 5 := by
  refine Ripemd160.blocks.induct (motive := fun h msg => h.size = 5 → (Ripemd160.blocks h msg).size = 5) ?_ ?_ h msg hh
  · intro h hh; simpa [Ripemd160.blocks] using hh
  · intro h b tl _block ih _
    rw [Ripemd160.blocks]
    exact ih (Ripemd160.compress_size _ _)

/-- **A word serializes to 4 bytes.** *What it says:* `Ripemd160.wordBytesLE` of any
32-bit word has length 4. *What it assumes:* nothing. *Why it matters:* with T-RMD1's
5 words it gives T-RMD2's 20 bytes (`ripemd160_length`). -/
theorem Ripemd160.wordBytesLE_length (w : UInt32) : (Ripemd160.wordBytesLE w).length = 4 := by
  simp [Ripemd160.wordBytesLE]

/-- T-RMD2: a RIPEMD-160 digest is 20 bytes; so is `hash160`. -/
theorem ripemd160_length (msg : List Nat) : (ripemd160 msg).length = 20 := by
  unfold ripemd160
  rw [List.length_flatten, List.map_map]
  have : ((Ripemd160.blocks Ripemd160.H0 (Ripemd160.padLE msg)).toList.map (List.length ∘ Ripemd160.wordBytesLE)) =
      (Ripemd160.blocks Ripemd160.H0 (Ripemd160.padLE msg)).toList.map (fun _ => 4) := by
    apply List.map_congr_left; intro w _; simp [Ripemd160.wordBytesLE_length]
  rw [this, List.map_const', List.sum_replicate, Array.length_toList, Ripemd160.blocks_size _ _ (by simp [Ripemd160.H0])]
  simp
/-- **`hash160` is 20 bytes.** *What it says:* `hash160` (`CHash160`, RIPEMD-160 of
SHA-256) of any message has length 20. *What it assumes:* nothing. *Why it matters:*
`OP_HASH160`'s result (`Ops/Crypto.lean`) is 20 bytes, the width of the hash in
`isP2SH`'s 23-byte shape (T-RMD2 applied to the SHA-256 digest). -/
theorem hash160_length (msg : List Nat) : (hash160 msg).length = 20 := ripemd160_length _

end BsvScript.Hash
