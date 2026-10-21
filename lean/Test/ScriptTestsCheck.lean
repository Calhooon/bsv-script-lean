import BsvScript.Eval
import BsvScript.Sighash
import BsvScript.Ops.Crypto
import BsvScript.Tx
import Test.OpNames
import Test.Common
import Test.ScriptNotation
import Lean.Data.Json
/-!
# The reference's own script vectors against the evaluator (#9 onward)

`corpus/reference/bitcoin-sv-v1.2.2-script_tests.json` is `src/test/data/script_tests.json`
at the pin, run by `src/test/script_tests.cpp` (`script_json_test`, `1483–1530`):
a row is `[[amount]?, "version", "scriptSig", "scriptPubKey", "flags",
"expected error", comment?]`; the scripts are parsed by `ParseScript`
(`src/core_read.cpp:37–174`), the flag names by `ParseScriptFlags`
(`src/test/scriptflags.cpp:14–56`), the error names by `ParseScriptError`
(`script_tests.cpp:52–124`); `DoTest` (`271–300`) adds P2SH under CLEANSTACK,
builds the consensus limits of the flag word's era (`make_verify_script_params`,
`interpreter.cpp:2282–2302`; the pre-Genesis memory limit is unbounded,
`configscriptpolicy.cpp:139–146`), and runs `VerifyScript` on a one-input
spending transaction of the row's version with `nSequence = SEQUENCE_FINAL` and
`nLockTime = 0` (`BuildSpendingTransaction`, `253–269`): so every executed
`CHECKLOCKTIMEVERIFY` fails its lock-time test and every
`CHECKSEQUENCEVERIFY` fails under version 1 (`CheckLockTime`, `CheckSequence`).

Every row the evaluator can decide must reproduce the expected verdict and
error; a row that reaches an opcode no family has written yet is skipped and
counted by that opcode (the count falls as the families land). Exit 1 on any
mismatch or parse failure.
-/

open BsvScript BsvScript.Params BsvScript.Machine BsvScript.Tx BsvScript.Numbers BsvScript.Test BsvScript.Ops.Crypto
open Lean

/-- `ParseScriptFlags` then `DoTest` (`281–282`): CLEANSTACK implies P2SH. -/
def parseFlags (s : String) : Except String Flags := do
  let f ← parseFlagWord s
  pure (if f.cleanStack then { f with p2sh := true } else f)

/-- `script_errors` (`script_tests.cpp:52–99`): the test name of each `SCRIPT_ERR_*`. -/
def errName (json : String) : String :=
  match json with
  | "OPERAND_SIZE" => "SCRIPT_ERR_INVALID_OPERAND_SIZE"
  | "SPLIT_RANGE" => "SCRIPT_ERR_INVALID_SPLIT_RANGE"
  | "NULLFAIL" => "SCRIPT_ERR_SIG_NULLFAIL"
  | "MISSING_FORKID" => "SCRIPT_ERR_MUST_USE_FORKID"
  | s => "SCRIPT_ERR_" ++ s

def getStr (j : Json) (what : String) : IO String :=
  match j.getStr? with
  | .ok s => pure s
  | .error e => throw (IO.userError s!"{what}: {e}")

def main (args : List String) : IO UInt32 := do
  let path := args.headD "../corpus/reference/bitcoin-sv-v1.2.2-script_tests.json"
  let text ← IO.FS.readFile path
  let j ← match Json.parse text with | .ok j => pure j | .error e => throw (IO.userError s!"json: {e}")
  let rows ← match j.getArr? with | .ok a => pure a | .error e => throw (IO.userError e)
  let mut n := 0
  let mut agree := 0
  let mut mismatch := 0
  let mut skipped := 0
  let mut parseFail := 0
  let mut shown := 0
  let mut blocking : Std.HashMap Nat Nat := {}
  for row in rows do
    let cells ← match row.getArr? with | .ok a => pure a | .error e => throw (IO.userError e)
    -- the optional leading `[amount]` in BSV (`AmountFromValue`, `1497–1499`): satoshis = value × 10⁸
    let (amount, cells) := match cells[0]?.bind (fun c => c.getArr?.toOption) with
      | some arr =>
        let sats := match arr[0]? with
          | some (Json.num n) => (n.mantissa * (10 : Int) ^ 8 / (10 : Int) ^ n.exponent).toNat
          | _ => 0
        (sats, cells.extract 1 cells.size)
      | none => (0, cells)
    if cells.size < 5 then continue   -- a comment row
    n := n + 1
    let verStr ← getStr cells[0]! "version"
    let sigStr ← getStr cells[1]! "scriptSig"
    let pkStr ← getStr cells[2]! "scriptPubKey"
    let flagStr ← getStr cells[3]! "flags"
    let errStr ← getStr cells[4]! "expected"
    let parsed : Except String (Bytes × Bytes × Flags) := do
      let sig ← parseScript sigStr
      let pk ← parseScript pkStr
      let f ← parseFlags flagStr
      pure (sig, pk, f)
    match parsed with
    | .error e =>
      parseFail := parseFail + 1
      IO.println s!"PARSE {n}: {e} in [{sigStr}] [{pkStr}] [{flagStr}]"
    | .ok (sig, pk, f) =>
      let version : Int := verStr.toInt?.getD 1
      let params : EvalParams := { flags := f, limits := limitsFor f }
      -- `BuildCreditingTransaction` (`236–251`) and `BuildSpendingTransaction` (`253–269`):
      -- the credit is version 1, one null-prevout input with scriptSig `0 0` and SEQUENCE_FINAL,
      -- one output (scriptPubKey, amount), lock time 0; the spend is the row's version, one input
      -- spending the credit's output 0 with the scriptSig and SEQUENCE_FINAL, one empty-script
      -- output of the same amount, lock time 0. The checker is over that spend (`292–298`).
      let credit : Tx := { version := 1, inputs := [{ prevHash := List.replicate 32 0, prevIndex := 0xffffffff, scriptSig := [0, 0], sequence := 0xffffffff }],
                           outputs := [{ value := amount, scriptPubKey := pk }], lockTime := 0 }
      let spend : Tx := { version, inputs := [{ prevHash := Sighash.txid credit, prevIndex := 0, scriptSig := sig, sequence := 0xffffffff }],
                          outputs := [{ value := amount, scriptPubKey := [] }], lockTime := 0 }
      let ctx : Context := { version, checkLockTime := fun _ => false, checkSequence := fun _ => false,
                             checkSig := txCheckSig spend 0 amount }
      let v := Eval.verifyScript params ctx sig pk
      match v with
      | .unimplemented op =>
        skipped := skipped + 1
        blocking := blocking.insert op (blocking.getD op 0 + 1)
      | .undefinedInReference f =>
        skipped := skipped + 1
        IO.println s!"UNDEFINED-IN-REFERENCE row {n} ({f}): sig [{sigStr}] pk [{pkStr}]"
      | .valid =>
        if errStr == "OK" then agree := agree + 1
        else
          mismatch := mismatch + 1
          if shown < 25 then
            shown := shown + 1
            IO.println s!"MISMATCH row {n}: spec valid, expected {errStr}; sig [{sigStr}] pk [{pkStr}] flags [{flagStr}]"
      | .invalid e =>
        if errStr != "OK" && e.name == errName errStr then agree := agree + 1
        else
          mismatch := mismatch + 1
          if shown < 25 then
            shown := shown + 1
            IO.println s!"MISMATCH row {n}: spec {e.name}, expected {errStr}; sig [{sigStr}] pk [{pkStr}] flags [{flagStr}]"
  IO.println s!"scripttests: {n} rows of the reference's script_tests.json at the pin: agree {agree}, mismatch {mismatch}, skipped (an opcode no family has written) {skipped}, parse failures {parseFail}"
  let bl := blocking.toList.mergeSort (fun a b => a.2 ≥ b.2)
  IO.println s!"  skipped by the first unwritten opcode: {bl.map (fun (op, c) => s!"0x{String.ofList (Nat.toDigits 16 op)}×{c}") |> String.intercalate " "}"
  if agree == 0 then
    IO.println "scripttests: ZERO decided rows"
    return 1
  return (if mismatch == 0 && parseFail == 0 then 0 else 1)
