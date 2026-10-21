import BsvScript.Eval
import Test.Common
/-!
# v1.2.3 boundaries (#57)

[SRC] bitcoin-sv `6504a3af`, `int_serialization.h:61–118`,
`script_num.cpp:62–87`, `interpreter.cpp:622–681`, `1718–1719`, `1807–1809`.
The expected reader values and opcode errors are independent boundary vectors.
Both the list definitions and the compiled array hooks are executed. The split
predicate is tested at large logical sizes; no multi-gigabyte element is allocated.
The existing `numcheck` executable runs these vectors before its corpus checks.
-/

open BsvScript BsvScript.Numbers BsvScript.Machine BsvScript.Params

namespace Repin123Check

private def env : Env :=
  { params := BsvScript.Test.relayParams
    ctx := { version := 2
             checkLockTime := fun _ => false
             checkSequence := fun _ => false
             checkSig := fun _ _ _ _ => false }
    requireMinimal := false
    strictDer := false
    utxoEra := .postChronicle
    checksigData := none }

private def readerCases : List (String × Bytes × Option Int) :=
  [ ("empty", [], some 0),
    ("eight-positive-max", [255,255,255,255,255,255,255,127], some 9223372036854775807),
    ("eight-negative-max", [255,255,255,255,255,255,255,255], some (-9223372036854775807)),
    ("eight-negative-zero", [0,0,0,0,0,0,0,128], some 0),
    ("nine-negative-zero", [0,0,0,0,0,0,0,0,128], some 0),
    ("nine-positive-max", [255,255,255,255,255,255,255,127,0], some 9223372036854775807),
    ("nine-minimum", [0,0,0,0,0,0,0,128,128], some (-9223372036854775808)),
    ("nine-positive-overflow", [0,0,0,0,0,0,0,128,0], none),
    ("nine-negative-overflow", [1,0,0,0,0,0,0,128,128], none),
    ("nine-all-bits", [255,255,255,255,255,255,255,255,128], none),
    ("nine-sign-magnitude-positive", [0,0,0,0,0,0,0,0,1], none),
    ("nine-sign-magnitude-negative", [0,0,0,0,0,0,0,0,129], none),
    ("ten-zero", List.replicate 10 0, none),
    ("sixty-four", List.replicate 64 0, none) ]

private def outcome : HookR → Except ScriptError (List Bytes)
  | .ok st => .ok st.stack
  | .fail e => .error e
  | .undefined _ => .error .unknownError

private def state (stack : List Bytes) : State :=
  { stack, memUsed := (stack.map (fun b => b.length + elementOverhead)).sum }

def runWithCases (extra : List (String × Bytes × Option Int)) : IO UInt32 := do
  let mut checks := 0
  let mut failed := 0
  let check := fun (name : String) (ok : Bool) => do
    unless ok do IO.println s!"FAIL {name}"
    pure (if ok then 0 else 1)
  for (name, bs, expected) in readerCases ++ extra do
    checks := checks + 1
    failed := failed + (← check name (deserializeInt64 bs == expected))
    let expectedCtor : Except NumError Int := match expected with
      | none => .error .overflow
      | some v => .ok v
    checks := checks + 1
    failed := failed + (← check (name ++ " constructor") (readNumInt64 bs false 100 == expectedCtor))
    -- A short data element makes positive large values range errors, not overflow.
    let opcodeExpected : Except ScriptError (List Bytes) := match expected with
      | none => .error .scriptnumOverflow
      | some v => if v < 0 || 16 < v then .error .invalidNumberRange
                  else .ok [List.range v.toNat]
    let data := List.range 16
    for (opname, op, opI) in
        [("left", Ops.Expansion.left, Impl.Expansion.leftI),
         ("right", Ops.Expansion.right, Impl.Expansion.rightI),
         ("substr-length", Ops.Expansion.substr, Impl.Expansion.substrI),
         ("substr-offset", Ops.Expansion.substr, Impl.Expansion.substrI)] do
      let stack := if opname == "substr-length" then [bs, [], data]
                   else if opname == "substr-offset" then [[4], bs, data]
                   else [bs, data]
      let expectedOp := if opname == "substr-offset" then
          match expected with
          | none => .error .scriptnumOverflow
          | some v => if v < 0 || 12 < v then .error .invalidNumberRange
                      else .ok [(data.drop v.toNat).take 4]
        else if opname == "right" then
          match expected with
          | none => .error .scriptnumOverflow
          | some v => if v < 0 || 16 < v then .error .invalidNumberRange
                      else .ok [data.drop (16 - v.toNat)]
        else opcodeExpected
      let s := state stack
      for (machine, result) in [("list", op env s), ("array", (opI env (Impl.IState.ofState s)).abs)] do
        checks := checks + 1
        failed := failed + (← check s!"{name} {opname} {machine}" (outcome result == expectedOp))
  for (name, bs, rm, width, expected) in
      [("minimal-before-overflow", List.replicate 10 0, true, 100, NumError.minencode),
       ("width-before-minimal", List.replicate 10 0, true, 9, NumError.overflow),
       ("minimal-minimum-accepted-width", [0,0,0,0,0,0,0,128,128], true, 8, NumError.overflow)] do
    checks := checks + 1
    failed := failed + (← check name (readNumInt64 bs rm width == .error expected))
  checks := checks + 1
  failed := failed + (← check "minimal signed minimum" (readNumInt64 [0,0,0,0,0,0,0,128,128] true 9 == .ok (-9223372036854775808)))
  for (size, n, bad) in [(2147483647, 2147483647, false), (2147483648, 2147483647, false),
                         (2147483648, 2147483648, true), (4294967296, 2147483648, true),
                         (0, 0, false), (0, -1, true), (1, 2, true)] do
    checks := checks + 1
    failed := failed + (← check s!"split guard {size} {n}" (Ops.Splice.invalidSplitPosition size n == bad))
  for n in [2147483647, 2147483648] do
    let s := state [encode n, [1,2,3]]
    for (machine, result) in [("list", Ops.Splice.split env s),
      ("array", (Impl.Splice.splitI env (Impl.IState.ofState s)).map Impl.IState.abs)] do
      checks := checks + 1
      let bad := match result with | .error .invalidSplitRange => true | _ => false
      failed := failed + (← check s!"split opcode {machine} {n}" bad)
  IO.println s!"repin123check: {checks} checks, {failed} failures"
  return if failed == 0 then 0 else 1

def run : IO UInt32 := runWithCases []

end Repin123Check
