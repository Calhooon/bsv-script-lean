import BsvScript.Eval
import Test.Common
import Lean.Data.Json
/-!
# Every byte 0x00–0xff against the pinned bsv-rs (#18; `docs/PROVENANCE.md` §1a: 0.3.32 since 2026-10-06 (R1.6), 0.3.30 from 2026-09-27 (#47), 0.3.28 from 2026-09-24, 0.3.27 from 2026-09-23; the key read by `Test.Common.bsvRsExpect`, lean #47)

`corpus/bytes/cases.jsonl` (`harness/src/bin/bytes_cases.rs`): every byte as
the locking script on the stack `1 2 3 4 5 6`, under both versions, with
bsv-rs's verdict. The comparable bytes (`bytes/`) must agree on the verdict
kind. The candidates (`bytes-candidate/`, recorded, never counted) are bsv-rs's
known divergence classes, each cited at the reference: `0xba`–`0xff` executed as
NOPs (`spend.rs:410` at 0.3.24; the reference's `default:` `1795`, `SCRIPT_ERR_BAD_OPCODE`),
`OP_VER`/`OP_VERIF`/`OP_VERNOTIF` `0x62`/`0x65`/`0x66` and `OP_2MUL`/`OP_2DIV`
`0x8d`/`0x8e` disabled always (`spend.rs:1699–1701` at 0.3.24; the reference executes
them for a post-Chronicle UTXO, `598–608`, `773–781`, `360–375`), and the
expansion opcodes `0xb3`–`0xb7` as NOPs (`spend.rs:407` at 0.3.24; the reference executes
them post-Chronicle, `609–764`). The policy bytes (`bytes-policy/`, recorded):
`OP_NOP1`/`OP_NOP9`/`OP_NOP10` and, post-Genesis, `OP_CHECKLOCKTIMEVERIFY`/
`OP_CHECKSEQUENCEVERIFY` (`0xb0`–`0xb2`, `0xb8`–`0xb9`), which the relay word's
`SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_NOPS` rejects (`765–771`, `519–527`,
`562–570`; `policy.h:208–222`) and which bsv-rs, without the flag, treats as
NOPs, as the reference's block validation does. Exit 1 on any mismatch or
`unimplemented`.
-/

open BsvScript BsvScript.Tx BsvScript.Test
open Lean

def main (args : List String) : IO UInt32 := do
  let path := args.headD "../corpus/bytes/cases.jsonl"
  let lines ← IO.FS.lines path
  let mut n := 0
  let mut agree := 0
  let mut mismatch := 0
  let mut unimpl := 0
  let mut undefined := 0
  let mut shown := 0
  let mut candidates : Array String := #[]
  for line in lines do
    if line.trim.isEmpty then continue
    let j ← match Json.parse line with | .ok j => pure j | .error e => throw (IO.userError s!"json: {e}")
    let c ← match parseEntry j with | .ok c => pure c | .error e => throw (IO.userError e)
    n := n + 1
    let (v, _, tx) ← runEntry c
    let kind := verdictKind v
    if c.family.startsWith "bytes-candidate/" || c.family.startsWith "bytes-policy/" then
      candidates := candidates.push s!"  {c.id} {c.family}: spec {verdictShow v} vs bsv-rs {c.expect}"
    else if kind == "unimplemented" then
      unimpl := unimpl + 1
      IO.println s!"UNIMPLEMENTED {c.id} ({c.family}): {verdictShow v}"
    else if kind == "undefined-in-reference" then
      undefined := undefined + 1
      IO.println s!"UNDEFINED-IN-REFERENCE {c.id} ({c.family}): {verdictShow v}"
    else if kind == c.expect then agree := agree + 1
    else
      mismatch := mismatch + 1
      if shown < 40 then
        shown := shown + 1
        IO.println s!"MISMATCH {c.id} ({c.family}): spec {verdictShow v} vs bsv-rs {c.expect}; lock {c.lockHex} version {tx.version}"
  IO.println s!"bytescheck: {n} entries (every byte × two versions); comparable {n - candidates.size}: agree {agree}, mismatch {mismatch}, unimplemented {unimpl}, undefined-in-reference {undefined}; recorded (not counted) {candidates.size}"
  if agree == 0 then
    IO.println "bytescheck: ZERO comparable entries"
    return 1
  return (if mismatch == 0 && unimpl == 0 then 0 else 1)
