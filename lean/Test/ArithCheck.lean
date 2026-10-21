import BsvScript.Eval
import BsvScript.Tx
import Test.Common
import Lean.Data.Json
/-!
# The arithmetic check of `BsvScript.Ops.Arith` against the pinned bsv-rs (#9; `docs/PROVENANCE.md` §1a: 0.3.32 since 2026-10-06 (R1.6), 0.3.30 from 2026-09-27 (#47), 0.3.28 from 2026-09-24; the verdict line names the vector file's version, lean #47)

Value by value: `corpus/arith/bsv-rs-<version>.jsonl` (`harness/src/bin/arith_vectors.rs`)
holds, for 10,000 operand pairs (the width boundaries of 4, 8 and 9 bytes and
beyond, both signs, negative zero, non-minimal pads, random widths to 100 bytes),
bsv-rs's result bytes for every binary opcode, every unary opcode on the first
operand, and one `OP_WITHIN` triple. The spec's `binaryValue`/`unaryValue`
(the same definitions the machine executes) must produce the same bytes through
`encode`; a zero divisor must be the spec's `DIV_BY_ZERO`/`MOD_BY_ZERO`.

Through the engine: `corpus/arith/cases.jsonl` (`harness/src/bin/arith_cases.rs`)
holds the bitwise family (`OP_AND`/`OP_OR`/`OP_XOR`, `OP_INVERT`,
`OP_LSHIFT`/`OP_RSHIFT`, `OP_EQUAL`/`OP_EQUALVERIFY`), the arithmetic error
paths, wide operands and the version-1 twins, each with bsv-rs's verdict; the
comparable families (`bitwise/`, `arith/`) must agree on the verdict kind;
`arith-candidate/` is recorded, never counted.

Exit 1 on any mismatch or any `unimplemented` in a comparable entry.
-/

open BsvScript BsvScript.Numbers BsvScript.Tx BsvScript.Ops.Arith BsvScript.Test
open Lean

def binOps : List (String × Nat) :=
  [("ADD", Op.OP_ADD), ("SUB", Op.OP_SUB), ("MUL", Op.OP_MUL), ("DIV", Op.OP_DIV), ("MOD", Op.OP_MOD),
   ("BOOLAND", Op.OP_BOOLAND), ("BOOLOR", Op.OP_BOOLOR), ("NUMEQUAL", Op.OP_NUMEQUAL),
   ("NUMNOTEQUAL", Op.OP_NUMNOTEQUAL), ("LESSTHAN", Op.OP_LESSTHAN), ("GREATERTHAN", Op.OP_GREATERTHAN),
   ("LESSTHANOREQUAL", Op.OP_LESSTHANOREQUAL), ("GREATERTHANOREQUAL", Op.OP_GREATERTHANOREQUAL),
   ("MIN", Op.OP_MIN), ("MAX", Op.OP_MAX)]

def unOps : List (String × Nat) :=
  [("1ADD", Op.OP_1ADD), ("1SUB", Op.OP_1SUB), ("2MUL", Op.OP_2MUL), ("2DIV", Op.OP_2DIV),
   ("NEGATE", Op.OP_NEGATE), ("ABS", Op.OP_ABS), ("NOT", Op.OP_NOT), ("0NOTEQUAL", Op.OP_0NOTEQUAL)]

def hexOrFail (s : String) (what : String) : IO Bytes :=
  match hexDecode s with
  | some b => pure b
  | none => throw (IO.userError s!"bad hex in {what}")

def vectorsCheck (path : String) : IO (Nat × Nat) := do
  let lines ← IO.FS.lines path
  let mut n := 0
  let mut checks := 0
  let mut bad := 0
  let mut shown := 0
  for line in lines do
    if line.trim.isEmpty then continue
    let j ← match Json.parse line with | .ok j => pure j | .error e => throw (IO.userError s!"json: {e}")
    let get := fun (o : Json) (k : String) => match o.getObjValAs? String k with
      | .ok v => pure v | .error e => throw (IO.userError s!"{k}: {e}")
    let obj := fun (k : String) => match j.getObjVal? k with
      | .ok v => pure v | .error e => throw (IO.userError s!"{k}: {e}")
    let a ← hexOrFail (← get j "a") "a"
    let b ← hexOrFail (← get j "b") "b"
    let x := decode a
    let y := decode b
    n := n + 1
    let bin ← obj "bin"
    for (name, op) in binOps do
      let want ← get bin name
      let got := match binaryValue op x y with
        | .ok v => hexEncode (encode v)
        | .error _ => "div0"
      checks := checks + 1
      if got != want then
        bad := bad + 1
        if shown < 20 then
          shown := shown + 1
          IO.println s!"MISMATCH #{n} {name}: a={hexEncode a} b={hexEncode b} spec {got} bsv-rs {want}"
    let un ← obj "un"
    for (name, op) in unOps do
      let want ← get un name
      let got := hexEncode (encode (unaryValue op x))
      checks := checks + 1
      if got != want then
        bad := bad + 1
        if shown < 20 then
          shown := shown + 1
          IO.println s!"MISMATCH #{n} {name}: a={hexEncode a} spec {got} bsv-rs {want}"
    let w ← obj "within"
    let lo := decode (← hexOrFail (← get w "lo") "lo")
    let hi := decode (← hexOrFail (← get w "hi") "hi")
    let want ← get w "r"
    let got := hexEncode (encode (if lo ≤ x && x < hi then 1 else 0))
    checks := checks + 1
    if got != want then
      bad := bad + 1
      if shown < 20 then
        shown := shown + 1
        IO.println s!"MISMATCH #{n} WITHIN: x={hexEncode a} spec {got} bsv-rs {want}"
  IO.println s!"arithcheck: {n} operand pairs, {checks} value checks against bsv-rs {bsvRsVersionOfPath path} (15 binary + 8 unary + WITHIN each): {bad} mismatch(es)"
  pure (n, bad)

def casesCheck (path : String) : IO (Nat × Nat × Nat) := do
  let lines ← IO.FS.lines path
  let mut n := 0
  let mut agree := 0
  let mut mismatch := 0
  let mut unimpl := 0
  let mut shown := 0
  let mut candidates : Array String := #[]
  for line in lines do
    if line.trim.isEmpty then continue
    let j ← match Json.parse line with | .ok j => pure j | .error e => throw (IO.userError s!"json: {e}")
    let c ← match parseEntry j with | .ok c => pure c | .error e => throw (IO.userError e)
    n := n + 1
    let (v, scriptSig, tx) ← runEntry c
    let kind := verdictKind v
    if c.family.startsWith "arith-candidate/" then
      candidates := candidates.push s!"  {c.id} {c.family}: spec {verdictShow v} vs bsv-rs {c.expect}"
    else if kind == "unimplemented" then
      unimpl := unimpl + 1
      if shown < 20 then
        shown := shown + 1
        IO.println s!"UNIMPLEMENTED {c.id} ({c.family}): {verdictShow v}"
    else if kind == c.expect then agree := agree + 1
    else
      mismatch := mismatch + 1
      if shown < 20 then
        shown := shown + 1
        IO.println s!"MISMATCH {c.id} ({c.family}): spec {verdictShow v} vs bsv-rs {c.expect}; lock {c.lockHex} unlock {hexEncode scriptSig} version {tx.version}"
  IO.println s!"arithcheck: {n} engine cases; comparable {n - candidates.size}: agree {agree}, mismatch {mismatch}, unimplemented {unimpl}; recorded (not counted) {candidates.size}"
  for s in candidates do IO.println s
  pure (agree, mismatch, unimpl)

def main (args : List String) : IO UInt32 := do
  match args with
  | [vectors, cases] =>
    let (n, bad) ← vectorsCheck vectors
    let (agree, mismatch, unimpl) ← casesCheck cases
    if n == 0 || agree == 0 then
      IO.println "arithcheck: ZERO vectors or cases"
      return 1
    return (if bad == 0 && mismatch == 0 && unimpl == 0 then 0 else 1)
  | _ => IO.println "usage: arithcheck <bsv-rs vectors.jsonl> <cases.jsonl>"; return 2
