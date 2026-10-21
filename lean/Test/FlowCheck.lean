import BsvScript.Eval
import BsvScript.Tx
import BsvScript.Properties.KernelSample
import Lean.Data.Json
/-!
# The flow check of `BsvScript.Machine` against the pinned bsv-rs (#8; `docs/PROVENANCE.md` §1a: 0.3.32 since 2026-10-06 (R1.6), 0.3.30 from 2026-09-27 (#47), 0.3.28 from 2026-09-24, 0.3.27 from 2026-09-23; the key read by `bsvRsExpect`, lean #47)

Reads `corpus/flow/flow.jsonl` (hand-written flow cases with bsv-rs's verdict,
`harness/src/bin/flow_cases.rs`), decodes each entry's transaction, and runs the
spec's evaluator on input 0 under the **relay flag word** of a post-Chronicle
node (`StandardScriptVerifyFlags` for the Chronicle era, `policy.h:208–222`,
plus the input flags `policy.h:225–244` for a post-Chronicle UTXO, plus
`SCRIPT_ENABLE_SIGHASH_FORKID` as the mempool path sets it,
`verify_script_flags.cpp:11–30`), with the consensus limits of the era
(`docs/PARAMETERS.md` §1). The comparable families (`flow/`, `push/`,
`stack/`, `flags/`) must agree on the verdict; `flow-candidate/` and
`flow-policy/` are recorded, never counted. Exit 1 on any comparable mismatch
or any `unimplemented`.

Then the kernel sample (`BsvScript/Properties/KernelSample.lean`, `docs/HYPOTHESES.md` §3): every
vector of `KernelSample.vectors`, each decided by the kernel on the definitions, is run here by the
compiled evaluator (since #50 the compiled `Eval.verifyScript` is `Eval.verifyScriptI`, the array machine,
by `@[csimp] Eval.verifyScript_eq_I`); exit 1 on any vector where the compiled verdict is not the kernel's.

Then the large-lock rows (lean #48): one synthetic lock of the depth wall's shape on the block path under a
wall budget, judged twice: by the compiled evaluator (the array machine of #50, whose depth tests read the
array's size) and by the list machine (a direct compiled call of `Machine.verifyScript` with `Eval.opExec`,
which reaches the fourteen functions whose depth tests #48 compiled: the machine behind the mempool gate's P2SH
standardness run and `--trace`). Exit 1 when either verdict is not valid or either wall passes the budget, so a
regression of either machine's compiled depth tests shows here (lean #32's second lens, finding A-2: from #50
until this second row the list machine had no row).
-/

open BsvScript BsvScript.Params BsvScript.Machine BsvScript.Tx BsvScript.Numbers
open Lean

/-- The relay flag word of a post-Chronicle node for a post-Chronicle UTXO. -/
def relayFlags : Flags :=
  { p2sh := true, strictEnc := true, derSig := true, lowS := true, nullDummy := true,
    sigPushOnly := true, minimalData := true, discourageUpgradableNops := true, cleanStack := true,
    checkLockTimeVerify := true, checkSequenceVerify := true, minimalIf := false, nullFail := true,
    compressedPubKeyType := false, enableSighashForkid := true, genesis := true,
    utxoAfterGenesis := true, chronicle := true, utxoAfterChronicle := true }

/-- The consensus limits post-Chronicle (`docs/PARAMETERS.md` §1). -/
def consensusLimits : Limits :=
  { maxOpsPerScript := Consensus.maxOpsPerScriptAfterGenesis,
    maxScriptNumLength := Consensus.maxScriptNumLengthAfterChronicle,
    maxScriptSize := Consensus.maxScriptSizeAfterGenesis,
    maxPubKeysPerMultiSig := Consensus.maxPubKeysPerMultisigAfterGenesis,
    maxStackMemoryUsage := Consensus.defaultStackMemoryUsageConsensusAfterGenesis }

structure Case where
  id : String
  family : String
  txHex : String
  lockHex : String
  expect : String

/-- The entry's bsv-rs verdict object (lean #47): the ONE key of `expect` that starts with `bsv-rs@`,
whichever pinned version the corpus was recorded at (`docs/PROVENANCE.md` §1a), never a literal
version; none, or more than one, is the entry's parse error. -/
def bsvRsExpect (expect : Json) : Except String Json := do
  let kvs := (← expect.getObj?).toList.filter (fun kv => kv.1.startsWith "bsv-rs@")
  match kvs with
  | [kv] => pure kv.2
  | [] => throw "expect carries no bsv-rs@<version> key"
  | _ => throw s!"expect carries {kvs.length} bsv-rs@<version> keys"

def parseCase (j : Json) : Except String Case := do
  let id ← j.getObjValAs? String "id"
  let family ← j.getObjValAs? String "family"
  let txHex ← j.getObjValAs? String "tx"
  let prevouts ← j.getObjVal? "prevouts"
  let p0 ← match prevouts.getArr? with
    | .ok arr => match arr[0]? with | some p => pure p | none => throw "no prevout"
    | .error e => throw e
  let lockHex ← p0.getObjValAs? String "script"
  let expect ← j.getObjVal? "expect"
  let e ← bsvRsExpect expect
  let verdict ← e.getObjValAs? String "verdict"
  pure { id, family, txHex, lockHex, expect := verdict }

def verdictKind : Verdict → String
  | .valid => "valid"
  | .invalid _ => "invalid"
  | .unimplemented _ => "unimplemented"
  | .undefinedInReference _ => "undefined-in-reference"

def verdictShow : Verdict → String
  | .valid => "valid"
  | .invalid e => s!"invalid {e.name}"
  | .unimplemented op => s!"unimplemented 0x{(Nat.toDigits 16 op).asString}"
  | .undefinedInReference f => s!"undefined-in-reference ({f})"

def comparable (family : String) : Bool :=
  !(family.startsWith "flow-candidate/" || family.startsWith "flow-policy/")

/-- The kernel sample through the compiled evaluator (`docs/HYPOTHESES.md` §3): each vector's verdict
from the compiled `Eval.verifyScript` (since #50 `Eval.verifyScriptI`, the array machine, by
`Eval.verifyScript_eq_I`) against the verdict the kernel decided for it
(`KernelSample.vectors`, one `decide +kernel` theorem each). Returns the number of disagreements. -/
def kernelSamplePart : IO Nat := do
  let vs := BsvScript.Properties.KernelSample.vectors
  let mut bad := 0
  for v in vs do
    let got := v.run
    if got != v.expect then
      bad := bad + 1
      IO.println s!"KERNEL SAMPLE DISAGREES: {v.name} ({v.cite}): compiled {verdictShow got} vs the kernel's {verdictShow v.expect}"
  IO.println s!"flowcheck: the kernel sample (BsvScript/Properties/KernelSample.lean): {vs.length} vectors; the compiled evaluator agrees with the kernel's verdict on {vs.length - bad}, disagrees on {bad}"
  pure bad

/-- The large-lock step (lean #48; `eval/ladder48.py`'s `STEP`, the same 55 bytes): on fresh constants over the
deep stack it reaches every opcode depth test that measures the stack, and leaves the depth where it found it:
on the list machine (`largeLockVerdictList`), the fourteen functions #48 compiled (`need` among them, which the
splice and crypto families also call); on the array machine (`largeLockVerdict`), `needI` and the `Impl` families'
size tests. Outside the step: the flow opcodes' tests (`OP_IF`, `OP_VERIFY`, CLTV, CSV) match the head of the
stack, at the same cost on both machines; the pre-Genesis element limit (`interpreter.cpp:1800–1804`) and
CLEANSTACK (`2441–2447`) measure it, bounded by the limit or once per spend, and neither applies to this row's
post-Genesis version-2 spend; `OP_DEPTH` reads it (`966–970`), on the list machine by walking it, on the array
machine by its size. The step, its 26 pushes (`OP_0`, `OP_1`, `OP_2`) testing no depth (`473–481`, `488–511`):
`OP_DUP OP_DROP` (`execStack`, `need`), `OP_1 OP_1ADD OP_DROP` (`Arith.unary`), `OP_1 OP_1 OP_ADD OP_DROP`
(`binary`), `OP_1 OP_0 OP_2 OP_WITHIN OP_DROP` (`within`), `OP_1 OP_1 OP_EQUAL OP_DROP` (`Bitwise.equal`),
`OP_1 OP_1 OP_AND OP_DROP` (`bitwise2`), `OP_1 OP_INVERT OP_DROP` (`invert`), `OP_1 OP_1 OP_LSHIFT OP_DROP`
(`shift`), `OP_1 OP_0 OP_1 OP_SUBSTR OP_DROP` (`Expansion.substr`), `OP_1 OP_1 OP_LEFT OP_DROP` (`left`),
`OP_1 OP_1 OP_RIGHT OP_DROP` (`right`), `OP_1 OP_1 OP_LSHIFTNUM OP_DROP` (`lshiftnum`),
`OP_1 OP_1 OP_RSHIFTNUM OP_DROP` (`rshiftnum`), `OP_0 OP_PICK OP_DROP` and `OP_1 OP_ROLL` (`execStack`'s
`OP_PICK`/`OP_ROLL` branch). -/
def largeLockStep : Bytes :=
  [0x76, 0x75, 0x51, 0x8B, 0x75, 0x51, 0x51, 0x93, 0x75, 0x51, 0x00, 0x52, 0xA5, 0x75,
   0x51, 0x51, 0x87, 0x75, 0x51, 0x51, 0x84, 0x75, 0x51, 0x83, 0x75, 0x51, 0x51, 0x98, 0x75,
   0x51, 0x00, 0x51, 0xB3, 0x75, 0x51, 0x51, 0xB4, 0x75, 0x51, 0x51, 0xB5, 0x75,
   0x51, 0x51, 0xB6, 0x75, 0x51, 0x51, 0xB7, 0x75, 0x00, 0x79, 0x75, 0x51, 0x7A]

/-- The large-lock spend (lean #48; `eval/ladder48.py <55m> <dir> <k>`'s bytes): the unlocking script pushes
`k` one-byte numbers (`OP_1` to `OP_16` in turn), so the lock runs on a stack `k` deep; the lock repeats
`largeLockStep` `m` times, then ends with `OP_1`. Returns (the unlocking script, the lock). -/
def largeLockSpend (m k : Nat) : Bytes × Bytes :=
  ((List.range k).map (fun i => 0x51 + i % 16), (List.replicate m largeLockStep).flatten ++ [0x51])

/-- The large-lock spend's verdict on the block path of a post-Chronicle coin at the spec's default
height (`derive` with SV-node's mainnet defaults at 967,896 and 967,896, as `eval/bsvs eval` derives
it; `nVersion` 2), by the compiled evaluator: since #50 the array machine (`Eval.verifyScriptI`).
`never_extract` keeps the compiler from evaluating it once at startup as a closed term, so the row's
clock reads the judgment. -/
@[never_extract, noinline] def largeLockVerdict (m k : Nat) : Verdict :=
  let (unlock, lock) := largeLockSpend m k
  Eval.verifyScript (derive NodeConfig.svMainnetDefault 967896 967896 true)
    { version := 2, checkLockTime := fun _ => false, checkSequence := fun _ => false,
      checkSig := fun _ _ _ _ => false }
    unlock lock

/-- The same spend through the LIST machine: a direct compiled call of `Machine.verifyScript` with the
spec's hook `Eval.opExec`, which `Machine.verifyScript_eq_fast` sends to `verifyScriptFast` (the fast parser
and number loops over the list stack), its hook reaching the fourteen functions whose depth tests #48 compiled
through the `Ops.*.exec` hooks. The evaluator's verdicts run the array machine since #50; the list machine
still produces judged output (the mempool gate's P2SH standardness run, `Standard.lean`, and `--trace`), so
its depth tests keep their own row. -/
@[never_extract, noinline] def largeLockVerdictList (m k : Nat) : Verdict :=
  let (unlock, lock) := largeLockSpend m k
  Machine.verifyScript Eval.opExec (derive NodeConfig.svMainnetDefault 967896 967896 true)
    { version := 2, checkLockTime := fun _ => false, checkSequence := fun _ => false,
      checkSig := fun _ _ _ _ => false }
    unlock lock

/-- The large-lock row's size: `m` steps, a lock of `55m + 1` bytes (550,001: above SV-node's default
policy script size, 500,000 B, `policy.h:93`; a size only the block path admits), on a stack `k` deep. -/
def largeLockSteps : Nat := 10000
def largeLockDepth : Nat := 1000000

/-- The large-lock row's wall budget in milliseconds. -/
def largeLockBudgetMs : Nat := 5000

/-- The judgment with its own clock, run as a task: the spend built and judged, the verdict forced before
the clock is read again. -/
def largeLockRun (judge : Nat → Nat → Verdict) (m k : Nat) : IO (Verdict × Nat) := do
  let t0 ← IO.monoMsNow
  let v := judge m k
  if (verdictKind v).isEmpty then throw (IO.userError "flowcheck: the large lock: no verdict")
  let t1 ← IO.monoMsNow
  pure (v, t1 - t0)

/-- A large-lock row (lean #48): the spend at `m` steps over a stack `k` deep, judged by `judge` (one of the
two machines, named by `machine`) in a task under a watchdog; it passes when the verdict is valid within
`budgetMs`. Before #48's fix every depth test walked the whole stack, so one step cost `k` cells per depth
test (on the list machine, a #48 copy that stops being compiled costs about `m · k` cells, some 10¹⁰ here;
on the array machine, a depth test that walks the array instead of reading its size, the same); after it, a
constant. A judgment still running at the budget is RED at once: the process exits 1 without waiting for it. -/
def largeLockPart (machine : String) (judge : Nat → Nat → Verdict) (m k budgetMs : Nat) : IO Bool := do
  let task ← IO.asTask (prio := .dedicated) (largeLockRun judge m k)
  let mut waited := 0
  while !(← IO.hasFinished task) && waited < budgetMs do
    IO.sleep 20
    waited := waited + 20
  let shape := s!"{machine}: {55 * m + 1} B over a stack {k} deep, {m} steps, the block path"
  if !(← IO.hasFinished task) then
    IO.println s!"flowcheck: the large lock (lean #48): {shape}: NOT judged within the budget {budgetMs} ms: RED"
    (← IO.getStdout).flush
    IO.Process.exit 1
  match task.get with
  | .error e =>
    IO.println s!"flowcheck: the large lock (lean #48): {shape}: {e}: RED"
    pure false
  | .ok (v, ms) =>
    let ok := verdictKind v == "valid" && ms ≤ budgetMs
    IO.println s!"flowcheck: the large lock (lean #48): {shape}: {verdictShow v} in {ms} ms, the budget {budgetMs} ms{if ok then "" else ": RED"}"
    pure ok

def main (args : List String) : IO UInt32 := do
  let path := args.headD "../corpus/flow/flow.jsonl"
  let lines ← IO.FS.lines path
  let params : EvalParams := { flags := relayFlags, limits := consensusLimits }
  let mut n := 0
  let mut comparableN := 0
  let mut agree := 0
  let mut mismatch := 0
  let mut unimpl := 0
  let mut shown := 0
  let mut candidates : Array String := #[]
  for line in lines do
    if line.trim.isEmpty then continue
    let j ← match Json.parse line with | .ok j => pure j | .error e => throw (IO.userError s!"json: {e}")
    let c ← match parseCase j with | .ok c => pure c | .error e => throw (IO.userError e)
    n := n + 1
    let txBytes ← match hexDecode c.txHex with | some b => pure b | none => throw (IO.userError s!"{c.id}: tx hex")
    let tx ← match decodeTx txBytes with | some t => pure t | none => throw (IO.userError s!"{c.id}: tx frame")
    let lock ← match hexDecode c.lockHex with | some b => pure b | none => throw (IO.userError s!"{c.id}: lock hex")
    let scriptSig ← match tx.inputs.head? with | some i => pure i.scriptSig | none => throw (IO.userError s!"{c.id}: no input")
    let ctx : Context := { version := tx.version, checkLockTime := fun _ => false, checkSequence := fun _ => false,
                           checkSig := fun _ _ _ _ => false }
    let v := Eval.verifyScript params ctx scriptSig lock
    let kind := verdictKind v
    if comparable c.family then
      comparableN := comparableN + 1
      if kind == "unimplemented" then
        unimpl := unimpl + 1
        if shown < 30 then
          shown := shown + 1
          IO.println s!"UNIMPLEMENTED {c.id} ({c.family}): {verdictShow v}"
      else if kind == c.expect then
        agree := agree + 1
      else
        mismatch := mismatch + 1
        if shown < 30 then
          shown := shown + 1
          IO.println s!"MISMATCH {c.id} ({c.family}): spec {verdictShow v} vs bsv-rs {c.expect}; lock {c.lockHex} unlock {hexEncode scriptSig} version {tx.version}"
    else
      candidates := candidates.push s!"  {c.id} {c.family}: spec {verdictShow v} vs bsv-rs {c.expect}"
  IO.println s!"flowcheck: {n} entries; comparable {comparableN}: agree {agree}, mismatch {mismatch}, unimplemented {unimpl}; recorded (not counted) {candidates.size}"
  for s in candidates do
    IO.println s
  let ksBad ← kernelSamplePart
  let largeOk ← largeLockPart "the array machine (#50)" largeLockVerdict largeLockSteps largeLockDepth largeLockBudgetMs
  let largeListOk ← largeLockPart "the list machine (#48's copies)" largeLockVerdictList largeLockSteps largeLockDepth largeLockBudgetMs
  if comparableN == 0 then
    IO.println "flowcheck: ZERO comparable entries"
    return 1
  return (if mismatch == 0 && unimpl == 0 && ksBad == 0 && largeOk && largeListOk then 0 else 1)
