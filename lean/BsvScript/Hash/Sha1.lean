import BsvScript.Hash.Sha256
/-!
# BsvScript.Hash.Sha1

SHA-1 (FIPS 180-4 §6.1), executable, for `OP_SHA1` (`interpreter.cpp:1402–1443`;
the reference's `src/crypto/sha1.cpp`: the round `:18–22`, the functions
`:24–31`, the constants `:45–48`, the transform `:51–150`, the padding as
SHA-256's with a big-endian length).
-/

namespace BsvScript.Hash

namespace Sha1

def rotl (x : UInt32) (n : Nat) : UInt32 := (x <<< n.toUInt32) ||| (x >>> (32 - n).toUInt32)

/-- `f1` = Ch (`sha1.cpp:24–26`), `f2` = Parity (`:27`), `f3` = Maj (`:28–30`). -/
def f (t : Nat) (b c d : UInt32) : UInt32 :=
  if t < 20 then d ^^^ (b &&& (c ^^^ d))
  else if t < 40 then b ^^^ c ^^^ d
  else if t < 60 then (b &&& c) ||| (d &&& (b ||| c))
  else b ^^^ c ^^^ d

/-- `k1` … `k4` (`sha1.cpp:45–48`). -/
def k (t : Nat) : UInt32 :=
  if t < 20 then 0x5A827999 else if t < 40 then 0x6ED9EBA1 else if t < 60 then 0x8F1BBCDC else 0xCA62C1D6

def H0 : Array UInt32 := #[0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]

/-- The message schedule: `W[t] = rotl(W[t−3] ^ W[t−8] ^ W[t−14] ^ W[t−16], 1)` (`left`, `:32`). -/
def schedule (w16 : Array UInt32) : Array UInt32 :=
  let rec go (w : Array UInt32) (t : Nat) : Array UInt32 :=
    if t < 80 then go (w.push (rotl (w[t - 3]! ^^^ w[t - 8]! ^^^ w[t - 14]! ^^^ w[t - 16]!) 1)) (t + 1)
    else w
  termination_by 80 - t
  go w16 16

/-- The 80 rounds (`sha1.cpp:18–22`: `e += rotl(a, 5) + f + k + w; b = rotl(b, 30)`, with the
register rotation of the standard). -/
def compress (h : Array UInt32) (w : Array UInt32) : Array UInt32 :=
  let rec rounds (a b c d e : UInt32) (t : Nat) : UInt32 × UInt32 × UInt32 × UInt32 × UInt32 :=
    if t < 80 then
      let tmp := rotl a 5 + f t b c d + e + k t + w[t]!
      rounds tmp a (rotl b 30) c d (t + 1)
    else (a, b, c, d, e)
  termination_by 80 - t
  let (a, b, c, d, e) := rounds h[0]! h[1]! h[2]! h[3]! h[4]! 0
  #[h[0]! + a, h[1]! + b, h[2]! + c, h[3]! + d, h[4]! + e]

def blocks (h : Array UInt32) : List Nat → Array UInt32
  | [] => h
  | b :: tl =>
    let block := (b :: tl).take 64
    blocks (compress h (schedule (blockWords block))) ((b :: tl).drop 64)
termination_by msg => msg.length
decreasing_by all_goals simp [List.length_drop]

end Sha1

/-- SHA-1 of a byte list: 20 bytes. The padding is SHA-256's (`pad`, a big-endian length). -/
def sha1 (msg : List Nat) : List Nat :=
  ((Sha1.blocks Sha1.H0 (pad msg)).toList.map wordBytes).flatten

end BsvScript.Hash

namespace BsvScript.Hash

/-- **One compression keeps a 5-word state.** *What it says:* `Sha1.compress` returns an
array of size 5 for any state and block. *What it assumes:* nothing. *Why it matters:*
it is the step of T-SHA4's induction (`Sha1.blocks_size`), which `OP_SHA1`'s 20-byte
digest rests on. -/
theorem Sha1.compress_size (h w : Array UInt32) : (Sha1.compress h w).size = 5 := by
  simp [Sha1.compress]

/-- T-SHA4: SHA-1 keeps a 5-word state. -/
theorem Sha1.blocks_size (h : Array UInt32) (msg : List Nat) (hh : h.size = 5) :
    (Sha1.blocks h msg).size = 5 := by
  refine Sha1.blocks.induct (motive := fun h msg => h.size = 5 → (Sha1.blocks h msg).size = 5) ?_ ?_ h msg hh
  · intro h hh; simpa [Sha1.blocks] using hh
  · intro h b tl _block ih _
    rw [Sha1.blocks]
    exact ih (Sha1.compress_size _ _)

/-- T-SHA5: a SHA-1 digest is 20 bytes. -/
theorem sha1_length (msg : List Nat) : (sha1 msg).length = 20 := by
  unfold sha1
  rw [List.length_flatten, List.map_map]
  have : ((Sha1.blocks Sha1.H0 (pad msg)).toList.map (List.length ∘ wordBytes)) =
      (Sha1.blocks Sha1.H0 (pad msg)).toList.map (fun _ => 4) := by
    apply List.map_congr_left; intro w _; simp [wordBytes_length]
  rw [this, List.map_const', List.sum_replicate, Array.length_toList, Sha1.blocks_size _ _ (by simp [Sha1.H0])]
  simp

end BsvScript.Hash
