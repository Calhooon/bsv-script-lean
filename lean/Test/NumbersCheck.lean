import Test.ReaderCheck
import BsvScript.Numbers
import BsvScript.Eval
import Test.Common
import Lean.Data.Json
/-!
# The property check of `BsvScript.Numbers` against the pinned bsv-rs (#7; `docs/PROVENANCE.md` §1a: 0.3.32 since 2026-10-06 (R1.6), 0.3.30 from 2026-09-27 (#47), 0.3.28 from 2026-09-24; the verdict line names the vector file's version, lean #47)

Reads the vectors `corpus/numbers/bsv-rs-<version>.jsonl` (one JSON object per
line, from `harness/src/bin/num_vectors.rs`) and runs the executable Lean
definitions on every byte string. bsv-rs is the implementation under
comparison, not the reference: a mismatch is printed and counted, never
resolved by bending either side. Exit 1 on any mismatch or on zero vectors.

Run: `make numcheck` (= `lake build numcheck && .lake/build/bin/numcheck <file>`).
-/

open BsvScript.Numbers
open Lean

def hexVal (c : Char) : Option Nat :=
  if '0' ≤ c ∧ c ≤ '9' then some (c.toNat - '0'.toNat)
  else if 'a' ≤ c ∧ c ≤ 'f' then some (c.toNat - 'a'.toNat + 10)
  else if 'A' ≤ c ∧ c ≤ 'F' then some (c.toNat - 'A'.toNat + 10)
  else none

def hexDecode (s : String) : Option Bytes := do
  let cs := s.toList
  if cs.length % 2 ≠ 0 then none
  let rec go : List Char → Option Bytes
    | [] => some []
    | a :: b :: rest => do
      let hi ← hexVal a
      let lo ← hexVal b
      let tl ← go rest
      pure ((hi * 16 + lo) :: tl)
    | _ => none
  go cs

def hexEncode (bs : Bytes) : String :=
  let digit (n : Nat) : Char := if n < 10 then Char.ofNat ('0'.toNat + n) else Char.ofNat ('a'.toNat + n - 10)
  String.mk (bs.foldr (fun b acc => digit (b / 16) :: digit (b % 16) :: acc) [])

/-- bsv-rs has no length bound on its number type; the vectors compare the
structural part of minimality, so the Lean side is run at a bound no vector
reaches (`docs/PARAMETERS.md` §1: the post-Chronicle consensus limit). -/
def bigLen : Nat := 32000000

structure Vec where
  bytes : Bytes
  value : Int
  strictOk : Bool
  minimal : Bool
  minimallyEncoded : Bytes
  encodeOfValue : Bytes
  bool : Bool

def parseVec (j : Json) : Except String Vec := do
  let bytesHex ← j.getObjValAs? String "bytes"
  let bytes ← match hexDecode bytesHex with | some b => pure b | none => throw s!"bad hex {bytesHex}"
  let valueStr ← j.getObjValAs? String "value"
  let value ← match valueStr.toInt? with | some v => pure v | none => throw s!"bad value {valueStr}"
  let strictOk ← j.getObjValAs? Bool "strict_ok"
  let minimal ← j.getObjValAs? Bool "minimal"
  let meHex ← j.getObjValAs? String "minimally_encoded"
  let me ← match hexDecode meHex with | some b => pure b | none => throw s!"bad hex {meHex}"
  let evHex ← j.getObjValAs? String "encode_of_value"
  let ev ← match hexDecode evHex with | some b => pure b | none => throw s!"bad hex {evHex}"
  let bool ← j.getObjValAs? Bool "bool"
  pure { bytes, value, strictOk, minimal, minimallyEncoded := me, encodeOfValue := ev, bool }

/-- The seven checks per vector; the names are the fields they compare. -/
def checks (v : Vec) : List (String × Bool) :=
  let strict := match readNum v.bytes true bigLen with | .ok _ => true | .error _ => false
  [ ("decode = value", decode v.bytes == v.value),
    ("readNum strict ok = strict_ok", strict == v.strictOk),
    ("isMinimallyEncoded = minimal", isMinimallyEncoded v.bytes bigLen == v.minimal),
    ("minimallyEncode = minimally_encoded", minimallyEncode v.bytes == v.minimallyEncoded),
    ("minimallyEncodeRef = minimally_encoded", minimallyEncodeRef v.bytes == v.minimallyEncoded),
    ("encode (decode) = encode_of_value", encode (decode v.bytes) == v.encodeOfValue),
    ("castToBool = bool", castToBool v.bytes == v.bool) ]

/-- The bsv-rs version a vector file names (`…/bsv-rs-<x.y.z>.jsonl`, `…/ecdsa-bsv-rs-<x.y.z>.jsonl`:
the harness writes the pinned version into the file's name, `docs/PROVENANCE.md` §1a; lean #47): the
verdict line names the vectors it read, never a literal version. -/
def bsvRsVersionOfPath (path : String) : String :=
  let file := (path.splitOn "/").getLastD path
  match file.splitOn "bsv-rs-" with
  | [_, rest] => (rest.splitOn ".jsonl").headD rest
  | _ => file


def main (args : List String) : IO UInt32 := do
  let boundaries ← Repin123Check.run
  if boundaries != 0 then return boundaries
  let path := args.headD "../corpus/numbers/bsv-rs-0.3.32.jsonl"
  let lines ← IO.FS.lines path
  let mut n := 0
  let mut bad := 0
  let mut shown := 0
  for line in lines do
    if line.trim.isEmpty then continue
    let j ← match Json.parse line with | .ok j => pure j | .error e => throw (IO.userError s!"json: {e}")
    let v ← match parseVec j with | .ok v => pure v | .error e => throw (IO.userError e)
    n := n + 1
    for (name, ok) in checks v do
      if !ok then
        bad := bad + 1
        if shown < 20 then
          shown := shown + 1
          IO.println s!"MISMATCH {name}: bytes {hexEncode v.bytes} (bsv-rs value {v.value}, minimal {v.minimal}, minimally_encoded {hexEncode v.minimallyEncoded}); Lean decode {decode v.bytes}, minimal {isMinimallyEncoded v.bytes bigLen}, minimallyEncode {hexEncode (minimallyEncode v.bytes)}, ref {hexEncode (minimallyEncodeRef v.bytes)}, bool {castToBool v.bytes}"
  IO.println s!"numcheck: {n} vectors × 7 checks against bsv-rs {bsvRsVersionOfPath path}: {bad} mismatch(es)"
  if n == 0 then
    IO.println "numcheck: ZERO vectors read"
    return 1
  return (if bad == 0 then 0 else 1)
