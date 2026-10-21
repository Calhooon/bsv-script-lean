import BsvScript.Eval
import Test.Common
import Lean.Data.Json
/-!
# The stack and splice check of `BsvScript.Ops.Stack`/`Ops.Splice` against the pinned bsv-rs (#10; `docs/PROVENANCE.md` §1a: 0.3.32 since 2026-10-06 (R1.6), 0.3.30 from 2026-09-27 (#47), 0.3.28 from 2026-09-24, 0.3.27 from 2026-09-23; the key read by `Test.Common.bsvRsExpect`, lean #47)

`corpus/stack/cases.jsonl` (`harness/src/bin/stack_cases.rs`): every stack
opcode with its exact expected stack verified in the lock, the alt stack,
`OP_PICK`/`OP_ROLL` at every index and outside, `OP_DEPTH`/`OP_SIZE`, `OP_CAT`,
`OP_SPLIT`, `OP_NUM2BIN` over a value × width table, `OP_BIN2NUM` over a table,
the underflows, the version-1 twins; the comparable families (`stack/`,
`splice/`) must agree on the verdict kind; `stack-candidate/` is recorded,
never counted. Exit 1 on any mismatch or `unimplemented`.
-/

open BsvScript BsvScript.Tx BsvScript.Test
open Lean

def main (args : List String) : IO UInt32 := do
  let path := args.headD "../corpus/stack/cases.jsonl"
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
    if c.family.startsWith "stack-candidate/" then
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
        IO.println s!"MISMATCH {c.id} ({c.family}): spec {verdictShow v} vs bsv-rs {c.expect}; lock {c.lockHex.take 120} unlock {(hexEncode scriptSig).take 120} version {tx.version}"
  IO.println s!"stackcheck: {n} engine cases; comparable {n - candidates.size}: agree {agree}, mismatch {mismatch}, unimplemented {unimpl}; recorded (not counted) {candidates.size}"
  for s in candidates do IO.println s
  if agree == 0 then
    IO.println "stackcheck: ZERO comparable entries"
    return 1
  return (if mismatch == 0 && unimpl == 0 then 0 else 1)
