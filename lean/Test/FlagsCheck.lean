import BsvScript.Flags
import BsvScript.TxContext
import Test.Common
import Lean.Data.Json
/-!
# The flags check: both branches under the derived words, against bsv-rs (#13)

Every entry of `corpus/flow/flow.jsonl` and `corpus/seed/seed.jsonl` (each with
its version-1 twin: the `flags.version-gate` rule, `corpus/INDEX.md` §2) is run
through the evaluator under the two words `Params.derive` produces for the
entry's heights from SV-node's mainnet defaults: the **block word**
(`consensus = true`) and the **mempool word** (`consensus = false`), with their
limits. Nothing is hand-written: the words the earlier legs used
(`Test/Common.lean` `relayFlags`) are decided below to be the derivation's.

What is checked (exit 1 on any failure):

1. **Like-for-like against bsv-rs, both branches.** bsv-rs (the pin of `docs/PROVENANCE.md` §1a: 0.3.32 since 2026-10-06 (R1.6), 0.3.30 from 2026-09-27 (#47), 0.3.28 from 2026-09-24, 0.3.27 from 2026-09-23; the key read by `bsvRsExpect`, lean #47) records its verdict under the
   node's standard word (`ScriptFlags::standard`, the mempool word; before 0.3.26 its
   default mode gated three relay restrictions on the version, `spend.rs:190–192` at 0.3.24),
   so its verdict is compared with the spec's under the mempool word. Version-1
   entries exercise the gate ON, version-2 entries the gate OFF; the counts are
   reported per branch. A mismatch is allowed only when it is one of bsv-rs's
   known divergences (the truncated-push parser, NOP undefined opcodes, push-only
   unlocks regardless of version: `lean/Test/SeedCheck.lean`; the recorded
   `flow-candidate/` and `flow-policy/` families of the flow corpus): #15's
   witnesses, recorded and counted here, never counted as agreement.
2. **Block versus mempool, version 2.** By `verifyScript_relay_block_version2`
   the two verdicts may differ only through DISCOURAGE_UPGRADABLE_NOPS (or a
   policy limit, which no entry of these corpora reaches): every difference must
   carry that code on the mempool side.
3. **Block versus mempool, version 1.** The gate is on, so the four standard-only
   bits bite: every difference must be the mempool side failing with
   `MINIMALDATA`, `SCRIPTNUM_MINENCODE`, `CLEANSTACK`, `SIG_NULLDUMMY` or
   `DISCOURAGE_UPGRADABLE_NOPS`; the count per code is the measure of the
   version-1 branch.
4. **The gate, executed.** Clearing the seven gated bits of the mempool word
   changes no version-2 verdict (`gate_noninterference`, run on every entry) and
   the number of version-1 verdicts it changes is reported.
-/

open BsvScript BsvScript.Params BsvScript.Machine BsvScript.Tx BsvScript.Numbers BsvScript.Test
open BsvScript.TxContext
open Lean

-- The hand-written relay word and consensus limits of the earlier legs are the derivation's.
example : relayFlags = (derive NodeConfig.svMainnetDefault defaultSpendHeight defaultSpendHeight false).flags := by decide
example : relayFlags = mainnetRelayWord := by decide
example : consensusLimits = (derive NodeConfig.svMainnetDefault defaultSpendHeight defaultSpendHeight true).limits := by decide
example : relayParams.limits = (derive NodeConfig.svMainnetDefault defaultSpendHeight defaultSpendHeight true).limits := by decide

structure Row where
  id : String
  family : String
  txHex : String
  lockHex : String
  satoshis : Nat
  utxoHeight : Nat
  spendHeight : Nat
  expect : String

def parseRow (j : Json) : Except String Row := do
  let id ← j.getObjValAs? String "id"
  let family ← j.getObjValAs? String "family"
  let txHex ← j.getObjValAs? String "tx"
  let prevouts ← j.getObjVal? "prevouts"
  let p0 ← match prevouts.getArr? with
    | .ok arr => match arr[0]? with | some p => pure p | none => throw "no prevout"
    | .error e => throw e
  let lockHex ← p0.getObjValAs? String "script"
  let satoshis ← p0.getObjValAs? Nat "satoshis"
  let utxoHeight ← p0.getObjValAs? Nat "height"
  let params ← j.getObjVal? "params"
  let spendHeight ← params.getObjValAs? Nat "spend_height"
  let expect ← j.getObjVal? "expect"
  let e ← bsvRsExpect expect
  let verdict ← e.getObjValAs? String "verdict"
  pure { id, family, txHex, lockHex, satoshis, utxoHeight, spendHeight, expect := verdict }

/-- bsv-rs's known divergence shapes (`Test/SeedCheck.lean`): a truncated push or an
undefined opcode in either script (`push.truncated`, `flow.unknown-opcode`). -/
partial def hasDivergenceShape : Bytes → Bool
  | [] => false
  | op :: rest =>
    match getOpTail op rest with
    | none => true
    | some (_, k) => Op.FIRST_UNDEFINED_OP_VALUE ≤ op || hasDivergenceShape (rest.drop k)

/-- The fourth bsv-rs divergence a mutation can run into: the expansion opcodes
`0xb3`–`0xb7` executed as NOPs (`spend.rs:407` at 0.3.24); the reference executes them for
a post-Chronicle UTXO (`609–764`, #18). A script that carries one as an
instruction is judged by bsv-rs as if the opcode were absent. -/
partial def hasExpansionOp : Bytes → Bool
  | [] => false
  | op :: rest =>
    match getOpTail op rest with
    | none => false
    | some (_, k) => (Op.OP_SUBSTR ≤ op && op ≤ Op.OP_RSHIFTNUM) || hasExpansionOp (rest.drop k)

/-- bsv-rs's four known divergence classes (`Test/SeedCheck.lean`): a truncated push
or an undefined opcode in either script, a push-only unlock demanded regardless of
version, and the expansion opcodes `0xb3`–`0xb7` executed as NOPs (`spend.rs:407` at 0.3.24; #18). -/
def explainedByBsvRs (v : Verdict) (version : Int) (lock unlock : Bytes) (expect : String) : Bool :=
  (v == .invalid .badOpcode && (hasDivergenceShape lock || hasDivergenceShape unlock))
  || (v == .valid && expect == "invalid" && version > 1 && !isPushOnly unlock)
  || (hasExpansionOp lock || hasExpansionOp unlock)

def recordedFamily (family : String) : Bool :=
  family.startsWith "flow-candidate/" || family.startsWith "flow-policy/"

/-- The codes the mempool word can add over the block word (the four standard-only
bits: MINIMALDATA at `433` and every number read, CLEANSTACK `2441`, NULLDUMMY
`1666`, DISCOURAGE_UPGRADABLE_NOPS at its eight sites) and the policy limits
(`docs/PARAMETERS.md` §1). -/
def mempoolOnlyCode : ScriptError → Bool
  | .minimaldata => true | .scriptnumMinencode => true | .cleanstack => true | .sigNulldummy => true
  | .discourageUpgradableNops => true
  | .opCount => true | .scriptnumOverflow => true | .scriptSize => true | .stackSize => true | .pubkeyCount => true
  | _ => false

def codeOf : Verdict → String
  | .valid => "valid"
  | .invalid e => e.name
  | .unimplemented op => s!"unimplemented 0x{String.ofList (Nat.toDigits 16 op)}"
  | .undefinedInReference f => s!"undefined-in-reference ({f})"

structure Counts where
  n : Nat := 0
  agree : Nat := 0
  mismatch : Nat := 0
  explained : Nat := 0
  recorded : Nat := 0
  unimpl : Nat := 0
  deriving Repr

def runCorpus (path : String) : IO (Bool × String) := do
  let lines ← IO.FS.lines path
  let cfg := NodeConfig.svMainnetDefault
  let mut v1 : Counts := {}
  let mut v2 : Counts := {}
  let mut v2BlockMempoolDiff := 0
  let mut v2BlockMempoolBad := 0
  let mut v1BlockMempoolDiff : Std.HashMap String Nat := {}
  let mut v1BlockMempoolBad := 0
  let mut v2GateChanged := 0
  let mut v1GateChanged := 0
  let mut shown := 0
  let mut ok := true
  for line in lines do
    if line.trim.isEmpty then continue
    let j ← match Json.parse line with | .ok j => pure j | .error e => throw (IO.userError s!"json: {e}")
    let r ← match parseRow j with | .ok r => pure r | .error e => throw (IO.userError s!"{path}: {e}")
    let txBytes ← match hexDecode r.txHex with | some b => pure b | none => throw (IO.userError s!"{r.id}: tx hex")
    let tx ← match decodeTx txBytes with | some t => pure t | none => throw (IO.userError s!"{r.id}: tx frame")
    let lock ← match hexDecode r.lockHex with | some b => pure b | none => throw (IO.userError s!"{r.id}: lock hex")
    let unlock ← match tx.inputs.head? with | some i => pure i.scriptSig | none => throw (IO.userError s!"{r.id}: no input")
    let ctx := txContext tx 0 r.satoshis
    let block := derive cfg r.spendHeight r.utxoHeight true
    let mempool := derive cfg r.spendHeight r.utxoHeight false
    let vBlock := Eval.verifyScript block ctx unlock lock
    let vMempool := Eval.verifyScript mempool ctx unlock lock
    let gatedOff : EvalParams := { mempool with flags := mempool.flags.setGated false false false false false false false }
    let vGatedOff := Eval.verifyScript gatedOff ctx unlock lock
    let isV1 := tx.version ≤ 1
    -- 1. like-for-like against bsv-rs under the mempool word
    let mut c := if isV1 then v1 else v2
    c := { c with n := c.n + 1 }
    match vMempool with
    | .unimplemented _ => c := { c with unimpl := c.unimpl + 1 }
    | _ =>
      let kind := verdictKind vMempool
      if recordedFamily r.family then c := { c with recorded := c.recorded + 1 }
      else if kind == r.expect then c := { c with agree := c.agree + 1 }
      else if r.family.startsWith "mutation/" && explainedByBsvRs vMempool tx.version lock unlock r.expect then
        c := { c with explained := c.explained + 1 }
      else
        c := { c with mismatch := c.mismatch + 1 }
        ok := false
        if shown < 20 then
          shown := shown + 1
          IO.println s!"MISMATCH {r.id} ({r.family}, version {tx.version}): spec {codeOf vMempool} under the mempool word vs bsv-rs {r.expect}; lock {r.lockHex} unlock {hexEncode unlock}"
    if isV1 then v1 := c else v2 := c
    -- 2./3. block versus mempool
    if vBlock != vMempool then
      let allowed := match vMempool with | .invalid e => mempoolOnlyCode e | _ => false
      if isV1 then
        v1BlockMempoolDiff := v1BlockMempoolDiff.insert (codeOf vMempool) (v1BlockMempoolDiff.getD (codeOf vMempool) 0 + 1)
        if !allowed then
          v1BlockMempoolBad := v1BlockMempoolBad + 1
          ok := false
          if shown < 20 then
            shown := shown + 1
            IO.println s!"BLOCK/MEMPOOL v1 {r.id} ({r.family}): block {codeOf vBlock}, mempool {codeOf vMempool}; lock {r.lockHex} unlock {hexEncode unlock}"
      else
        v2BlockMempoolDiff := v2BlockMempoolDiff + 1
        if vMempool != .invalid .discourageUpgradableNops && !allowed then
          v2BlockMempoolBad := v2BlockMempoolBad + 1
          ok := false
          if shown < 20 then
            shown := shown + 1
            IO.println s!"BLOCK/MEMPOOL v2 {r.id} ({r.family}): block {codeOf vBlock}, mempool {codeOf vMempool}; lock {r.lockHex} unlock {hexEncode unlock}"
    -- 4. the gate, executed
    if vGatedOff != vMempool then
      if isV1 then v1GateChanged := v1GateChanged + 1
      else
        v2GateChanged := v2GateChanged + 1
        ok := false
        if shown < 20 then
          shown := shown + 1
          IO.println s!"GATE v2 {r.id} ({r.family}): clearing the gated bits changed the verdict {codeOf vMempool} → {codeOf vGatedOff}"
  let name := path.splitOn "/" |>.getLast!
  let line1 := s!"flagscheck {name}: version-2 (gate OFF) {v2.n}: agree {v2.agree}, mismatch {v2.mismatch}, explained by bsv-rs's known divergences {v2.explained}, recorded families {v2.recorded}, unimplemented {v2.unimpl}; version-1 (gate ON) {v1.n}: agree {v1.agree}, mismatch {v1.mismatch}, explained {v1.explained}, recorded {v1.recorded}, unimplemented {v1.unimpl}"
  let diffs := v1BlockMempoolDiff.toList.mergeSort (fun a b => a.1 ≤ b.1) |>.map (fun (k, c) => s!"{k} {c}") |> String.intercalate ", "
  let line2 := s!"  block vs mempool: version-2 differ {v2BlockMempoolDiff} (all DISCOURAGE_UPGRADABLE_NOPS, {v2BlockMempoolBad} unexplained); version-1 differ by mempool code: {if diffs.isEmpty then "none" else diffs} ({v1BlockMempoolBad} unexplained)"
  let line3 := s!"  the gate cleared: version-2 verdicts changed {v2GateChanged} (must be 0), version-1 verdicts changed {v1GateChanged}"
  IO.println line1
  IO.println line2
  IO.println line3
  let zero := v1.agree == 0 || v2.agree == 0
  if zero then IO.println s!"flagscheck {name}: ZERO comparable entries in a branch"
  pure (ok && !zero, line1)

def main (args : List String) : IO UInt32 := do
  let paths := if args.isEmpty then ["../corpus/flow/flow.jsonl", "../corpus/seed/seed.jsonl"] else args
  let mut allOk := true
  for p in paths do
    let (ok, _) ← runCorpus p
    allOk := allOk && ok
  return (if allOk then 0 else 1)
