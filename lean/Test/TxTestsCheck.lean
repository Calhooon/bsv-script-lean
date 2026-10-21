import BsvScript.Eval
import BsvScript.TxContext
import BsvScript.TxRules
import Test.Common
import Test.ScriptNotation
import Lean.Data.Json
/-!
# The reference's transaction vectors against the evaluator (#22)

`corpus/reference/bitcoin-sv-v1.2.2-tx_valid.json` and `-tx_invalid.json` are
`src/test/data/tx_valid.json` and `tx_invalid.json` at the pin, run by
`src/test/transaction_tests.cpp` `RunTests` (`70–175`): a row is
`[[[prevout txid, index, scriptPubKey, amount?], …], transaction hex, flags]`
with the flags a string or an array of strings (each a comma-separated word,
`ParseScriptFlags`); the transaction passes `CheckCoinbase` or
`CheckRegularTransaction` under the pre-Genesis limits (`115–121`; an invalid
row may already fail there), then for every flag word every input's script
runs under `TransactionSignatureChecker(&tx, i, amount)` (`128–139`) and the
row is valid iff every input is. The prevout txid in the row is in display
order; the transaction stores it reversed.

Every decidable row must reproduce the expected validity under every flag word;
a row that reaches an opcode no family has written is skipped and counted. Exit
1 on any mismatch or parse failure.
-/

open BsvScript BsvScript.Params BsvScript.Machine BsvScript.Tx BsvScript.Numbers BsvScript.Test
open BsvScript.TxContext BsvScript.TxRules
open Lean

structure Row where
  prevouts : List (Bytes × Nat × Bytes × Nat)   -- stored-order txid, index, script, amount
  tx : Tx
  txHex : String
  flagWords : List String

def getStr (j : Json) (what : String) : IO String :=
  match j.getStr? with
  | .ok s => pure s
  | .error e => throw (IO.userError s!"{what}: {e}")

def parseRow (cells : Array Json) : IO (Option Row) := do
  if cells.size < 3 then return none
  let prevs ← match cells[0]!.getArr? with | .ok a => pure a | .error _ => return none
  let mut prevouts : List (Bytes × Nat × Bytes × Nat) := []
  for p in prevs do
    let pc ← match p.getArr? with | .ok a => pure a | .error e => throw (IO.userError e)
    let txidHex ← getStr pc[0]! "prevout txid"
    let txid ← match hexDecode txidHex with | some b => pure b.reverse | none => throw (IO.userError "prevout txid hex")
    -- `COutPoint(uint256S(…), vinput[1].get_int())` (`105–106`): the index as an unsigned word (`-1` is `0xffffffff`)
    let index ← match pc[1]!.getInt? with | .ok v => pure (v % (2 ^ 32 : Int)).toNat | .error e => throw (IO.userError e)
    let script ← match parseScript (← getStr pc[2]! "prevout script") with
      | .ok b => pure b | .error e => throw (IO.userError s!"prevout script: {e}")
    let amount ← match pc[3]? with
      | some a => match a.getInt? with | .ok v => pure v.toNat | .error e => throw (IO.userError e)
      | none => pure 0
    prevouts := prevouts ++ [(txid, index, script, amount)]
  let txHex ← getStr cells[1]! "tx"
  -- `CDataStream >> tx` (`RunTests` `112–114`): one transaction, whatever follows it in the stream ignored
  let tx ← match hexDecode txHex >>= decodeTxPrefix with | some (t, _) => pure t | none => throw (IO.userError "tx frame")
  let flagWords ← match cells[2]!.getStr? with
    | .ok s => pure [s]
    | .error _ => match cells[2]!.getArr? with
      | .ok arr => arr.toList.mapM (fun j => getStr j "flag word")
      | .error e => throw (IO.userError e)
  pure (some { prevouts, tx, txHex, flagWords })

/-- The transaction verdict under one flag word (`RunTests` `115–139`). -/
def rowVerdict (r : Row) (word : String) : IO (Except String Verdict) := do
  let f ← match parseFlagWord word with | .ok f => pure f | .error e => throw (IO.userError e)
  let params : EvalParams := { flags := f, limits := limitsFor f }
  let mut verdict : Verdict := .valid
  let mut i := 0
  for input in r.tx.inputs do
    if verdict != .valid then break
    match r.prevouts.find? (fun (h, n, _, _) => h == input.prevHash && n == input.prevIndex) with
    | none => return .error s!"input {i}: no prevout in the row"
    | some (_, _, script, amount) =>
      let ctx := txContext r.tx i amount
      verdict := Eval.verifyScript params ctx input.scriptSig script
    i := i + 1
  pure (.ok verdict)

def runFile (path : String) (shouldBeValid : Bool) : IO (Nat × Nat × Nat × Nat × Nat) := do
  let text ← IO.FS.readFile path
  let j ← match Json.parse text with | .ok j => pure j | .error e => throw (IO.userError s!"json: {e}")
  let rows ← match j.getArr? with | .ok a => pure a | .error e => throw (IO.userError e)
  let mut n := 0
  let mut agree := 0
  let mut mismatch := 0
  let mut skipped := 0
  let mut txLevel := 0
  let mut shown := 0
  for row in rows do
    let cells ← match row.getArr? with | .ok a => pure a | .error e => throw (IO.userError e)
    let some r ← parseRow cells | continue
    n := n + 1
    -- the transaction-level checks under the pre-Genesis limits (`115–121`)
    let pre := if isCoinBase r.tx then checkCoinbase r.tx MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS true
               else checkRegularTransaction r.tx MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS true
    match pre with
    | .error rej =>
      if shouldBeValid then
        mismatch := mismatch + 1
        IO.println s!"MISMATCH row {n}: rejected at the transaction level ({repr rej}) but expected valid; tx {r.txHex.take 80}…"
      else txLevel := txLevel + 1
    | .ok () =>
      let mut rowOk := true
      let mut rowSkipped := false
      for word in r.flagWords do
        match ← rowVerdict r word with
        | .error e => throw (IO.userError s!"row {n}: {e}")
        | .ok (.unimplemented _) => rowSkipped := true
        | .ok (.undefinedInReference f) =>
          rowSkipped := true
          IO.println s!"UNDEFINED-IN-REFERENCE row {n} ({f})"
        | .ok v =>
          let valid := v == .valid
          if valid != shouldBeValid then
            rowOk := false
            if shown < 20 then
              shown := shown + 1
              IO.println s!"MISMATCH row {n} under [{word}]: spec {verdictShow v}, expected {if shouldBeValid then "valid" else "invalid"}; tx {r.txHex.take 100}…"
      if rowSkipped then skipped := skipped + 1
      else if rowOk then agree := agree + 1
      else mismatch := mismatch + 1
  IO.println s!"txtests {path.splitOn "/" |>.getLast!}: {n} rows: agree {agree}, mismatch {mismatch}, skipped (an unwritten opcode) {skipped}, rejected at the transaction level {txLevel}{if shouldBeValid then "" else " (invalid as expected)"}"
  pure (n, agree, mismatch, skipped, txLevel)

def main (args : List String) : IO UInt32 := do
  match args with
  | [valid, invalid] =>
    let (n1, a1, m1, _, _) ← runFile valid true
    let (n2, a2, m2, _, _) ← runFile invalid false
    if n1 == 0 || n2 == 0 || a1 == 0 || a2 == 0 then
      IO.println "txtests: ZERO rows"
      return 1
    return (if m1 + m2 == 0 then 0 else 1)
  | _ => IO.println "usage: txtests <tx_valid.json> <tx_invalid.json>"; return 2
