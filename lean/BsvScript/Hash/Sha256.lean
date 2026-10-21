import BsvScript.Numbers
/-!
# BsvScript.Hash.Sha256

SHA-256 (FIPS 180-4 §6.2) as an executable Lean function on byte lists, the digest
of `OP_SHA256` (`CSHA256`, `interpreter.cpp:1426–1429`), and SHA-256d (`Hash`,
`src/hash.h:24` `CHash256`: SHA-256 applied twice), the digest of every signature
hash (`CHashWriter::GetHash`, `interpreter.cpp:2083`, `2109`) and of `OP_HASH256`
(`1435–1439`) (#11). The reference computes it with
`src/crypto/sha256.cpp`; this is the specification's own implementation,
cross-checked against bsv-rs on vectors (`Test/SighashCheck.lean`) and against
the FIPS examples, never trusted from a library (`docs/DESIGN.md` §4.1).

The arithmetic is on `UInt32` (wrapping addition, rotations, the bitwise
functions of §4.1.2); bytes are the `Bytes` of `Numbers` (naturals below 256).
-/

namespace BsvScript.Hash

/-- Rotate right by `n` (`ROTR^n`, §3.2), `0 < n < 32`. -/
def rotr (x : UInt32) (n : Nat) : UInt32 := (x >>> n.toUInt32) ||| (x <<< (32 - n).toUInt32)

/-- The 64 round constants (§4.2.2): the first 32 bits of the fractional parts of
the cube roots of the first 64 primes. -/
def K : Array UInt32 := #[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2 ]

/-- The initial hash value (§5.3.3). -/
def H0 : Array UInt32 := #[
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 ]

def ch (x y z : UInt32) : UInt32 := (x &&& y) ^^^ ((~~~x) &&& z)
def maj (x y z : UInt32) : UInt32 := (x &&& y) ^^^ (x &&& z) ^^^ (y &&& z)
def bigSigma0 (x : UInt32) : UInt32 := rotr x 2 ^^^ rotr x 13 ^^^ rotr x 22
def bigSigma1 (x : UInt32) : UInt32 := rotr x 6 ^^^ rotr x 11 ^^^ rotr x 25
def smallSigma0 (x : UInt32) : UInt32 := rotr x 7 ^^^ rotr x 18 ^^^ (x >>> 3)
def smallSigma1 (x : UInt32) : UInt32 := rotr x 17 ^^^ rotr x 19 ^^^ (x >>> 10)

/-- Padding (§5.1.1): a `1` bit, zeros to 56 mod 64 bytes, the bit length as a
64-bit big-endian integer. -/
def pad (msg : List Nat) : List Nat :=
  let len := msg.length
  let bitLen := len * 8
  let zeros := (55 + 64 - len % 64) % 64
  let lenBytes := (List.range 8).map (fun i => (bitLen / 256 ^ (7 - i)) % 256)
  msg ++ [0x80] ++ List.replicate zeros 0 ++ lenBytes

/-- A 64-byte block as sixteen big-endian words. -/
def blockWords (block : List Nat) : Array UInt32 :=
  let rec go : List Nat → Array UInt32 → Array UInt32
    | a :: b :: c :: d :: rest, acc =>
      go rest (acc.push (UInt32.ofNat (a * 16777216 + b * 65536 + c * 256 + d)))
    | _, acc => acc
  go block #[]

/-- The message schedule (§6.2.2 step 1). -/
def schedule (w16 : Array UInt32) : Array UInt32 :=
  let rec go (w : Array UInt32) (t : Nat) : Array UInt32 :=
    if t < 64 then
      let v := smallSigma1 w[t - 2]! + w[t - 7]! + smallSigma0 w[t - 15]! + w[t - 16]!
      go (w.push v) (t + 1)
    else w
  termination_by 64 - t
  go w16 16

/-- The compression of one block into the hash state (§6.2.2 steps 2–4). -/
def compress (h : Array UInt32) (w : Array UInt32) : Array UInt32 :=
  let rec rounds (a b c d e f g hh : UInt32) (t : Nat) : UInt32 × UInt32 × UInt32 × UInt32 × UInt32 × UInt32 × UInt32 × UInt32 :=
    if t < 64 then
      let t1 := hh + bigSigma1 e + ch e f g + K[t]! + w[t]!
      let t2 := bigSigma0 a + maj a b c
      rounds (t1 + t2) a b c (d + t1) e f g (t + 1)
    else (a, b, c, d, e, f, g, hh)
  termination_by 64 - t
  let (a, b, c, d, e, f, g, hh) := rounds h[0]! h[1]! h[2]! h[3]! h[4]! h[5]! h[6]! h[7]! 0
  #[h[0]! + a, h[1]! + b, h[2]! + c, h[3]! + d, h[4]! + e, h[5]! + f, h[6]! + g, h[7]! + hh]

/-- Process the padded message block by block. -/
def blocks (h : Array UInt32) : List Nat → Array UInt32
  | [] => h
  | b :: tl =>
    let block := (b :: tl).take 64
    blocks (compress h (schedule (blockWords block))) ((b :: tl).drop 64)
termination_by msg => msg.length
decreasing_by all_goals simp [List.length_drop]

/-- A word as four big-endian bytes. -/
def wordBytes (x : UInt32) : List Nat :=
  let n := x.toNat
  [n / 16777216 % 256, n / 65536 % 256, n / 256 % 256, n % 256]

/-- SHA-256 of a byte list: 32 bytes. -/
def sha256 (msg : List Nat) : List Nat :=
  let h := blocks H0 (pad msg)
  (h.toList.map wordBytes).flatten

/-- SHA-256 applied twice (`CHash256`, `src/hash.h:24–56`): the transaction
hash, `OP_HASH256`, and every signature-hash digest. -/
def sha256d (msg : List Nat) : List Nat := sha256 (sha256 msg)

end BsvScript.Hash

namespace BsvScript.Hash

/-! ## Widths -/

/-- **One compression keeps an 8-word state.** *What it says:* SHA-256's `compress`
returns an array of size 8 for any state and block. *What it assumes:* nothing.
*Why it matters:* it is the step of T-SHA1's induction (`blocks_size`), which T-SHA2's
32-byte digest rests on. -/
theorem compress_size (h w : Array UInt32) : (compress h w).size = 8 := by
  simp [compress]

/-- T-SHA1: `blocks` keeps an 8-word state. -/
theorem blocks_size (h : Array UInt32) (msg : List Nat) (hh : h.size = 8) :
    (blocks h msg).size = 8 := by
  refine blocks.induct (motive := fun h msg => h.size = 8 → (blocks h msg).size = 8) ?_ ?_ h msg hh
  · intro h hh; simpa [blocks] using hh
  · intro h b tl _block ih _
    rw [blocks]
    exact ih (compress_size _ _)

/-- **A word serializes to 4 bytes.** *What it says:* `wordBytes` of any 32-bit word has
length 4. *What it assumes:* nothing. *Why it matters:* with T-SHA1's 8 words it gives
T-SHA2's 32 bytes (`sha256_length`). -/
theorem wordBytes_length (w : UInt32) : (wordBytes w).length = 4 := by
  simp [wordBytes]

/-- T-SHA2: a SHA-256 digest is 32 bytes. -/
theorem sha256_length (msg : List Nat) : (sha256 msg).length = 32 := by
  unfold sha256
  rw [List.length_flatten, List.map_map]
  have : ((blocks H0 (pad msg)).toList.map (List.length ∘ wordBytes)) =
      (blocks H0 (pad msg)).toList.map (fun _ => 4) := by
    apply List.map_congr_left; intro w _; simp [wordBytes_length]
  rw [this, List.map_const', List.sum_replicate, Array.length_toList, blocks_size _ _ (by simp [H0])]
  simp

/-- T-SHA3: a SHA-256d digest is 32 bytes. -/
theorem sha256d_length (msg : List Nat) : (sha256d msg).length = 32 := sha256_length _

end BsvScript.Hash
