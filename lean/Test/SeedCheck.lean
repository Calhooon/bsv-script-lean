import BsvScript.Eval
import BsvScript.Tx
import Lean.Data.Json
/-!
# The seed-corpus check of the evaluator against the pinned bsv-rs (#9 onward; `docs/PROVENANCE.md` §1a: 0.3.32 since 2026-10-06 (R1.6), 0.3.30 from 2026-09-27 (#47), 0.3.28 from 2026-09-24, 0.3.27 from 2026-09-23; the key read by `bsvRsExpect`, lean #47)

Runs every entry of `corpus/seed/seed.jsonl` (10,000 generated cases with
bsv-rs's verdicts, `corpus/INDEX.md` §1) through the spec's evaluator on input
0 under the relay flag word of a post-Chronicle node with the consensus limits
(as `Test/FlowCheck.lean`), and compares the verdict kind. An entry that reaches
an opcode no family has written yet is `unimplemented`: counted per family and
allowed only for the families named `deferred` below (they wait for #10); every
other entry must agree. Exit 1 on a mismatch, on an `unimplemented` outside the
deferred families, or on zero comparable entries.
-/

open BsvScript BsvScript.Params BsvScript.Machine BsvScript.Tx BsvScript.Numbers
open Lean

/-- The relay flag word of a post-Chronicle node for a post-Chronicle UTXO (`Test/FlowCheck.lean`). -/
def relayFlags : Flags :=
  { p2sh := true, strictEnc := true, derSig := true, lowS := true, nullDummy := true,
    sigPushOnly := true, minimalData := true, discourageUpgradableNops := true, cleanStack := true,
    checkLockTimeVerify := true, checkSequenceVerify := true, minimalIf := false, nullFail := true,
    compressedPubKeyType := false, enableSighashForkid := true, genesis := true,
    utxoAfterGenesis := true, chronicle := true, utxoAfterChronicle := true }

def consensusLimits : Limits :=
  { maxOpsPerScript := Consensus.maxOpsPerScriptAfterGenesis,
    maxScriptNumLength := Consensus.maxScriptNumLengthAfterChronicle,
    maxScriptSize := Consensus.maxScriptSizeAfterGenesis,
    maxPubKeysPerMultiSig := Consensus.maxPubKeysPerMultisigAfterGenesis,
    maxStackMemoryUsage := Consensus.defaultStackMemoryUsageConsensusAfterGenesis }

/-- The families still allowed to reach an opcode no family has written: the
mutations, which can land on the crypto and expansion opcodes (#11, #18). -/
def deferred (family : String) : Bool := family.startsWith "mutation/"

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

/-- The two bsv-rs divergences the mutation family runs into (`corpus/INDEX.md`
§2 `push.truncated`, `flow.unknown-opcode`; #15's witnesses): a push the script
cannot complete (`GetOp2`, `script.h:165–198`, the reference's `SCRIPT_ERR_BAD_OPCODE`
at `450–451`; bsv-rs's parser is lenient) and an undefined opcode `0xba`–`0xff`
(the reference's `default:` at `1795`; bsv-rs executes it as a NOP,
`spend.rs:410` at 0.3.24). A mutation mismatch is explained when the spec's verdict is
`BAD_OPCODE` and one of the two is present in the lock or the unlock. -/
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

/-- The third bsv-rs divergence a mutation can run into: an unlocking script
that is not push-only. The reference requires push-only only under
SIGPUSHONLY with Genesis-without-Chronicle or Chronicle with version ≤ 1
(`2321–2334`); bsv-rs requires it regardless of version (`spend.rs:186/237` at 0.3.24;
`flow.sigpushonly`, #15's witness). A mutation mismatch is explained when the
spec accepts a version-2 spend whose unlock is not push-only and bsv-rs rejects it. -/
def explained (v : Verdict) (version : Int) (lock unlock : Bytes) (expect : String) : Bool :=
  (v == .invalid .badOpcode && (hasDivergenceShape lock || hasDivergenceShape unlock))
  || (v == .valid && expect == "invalid" && version > 1 && !isPushOnly unlock)
  || (hasExpansionOp lock || hasExpansionOp unlock)

/-- The family's head: `arith/ADD/twin/v1` → `arith`. -/
def familyHead (f : String) : String := (f.splitOn "/").headD f

def main (args : List String) : IO UInt32 := do
  let path := args.headD "../corpus/seed/seed.jsonl"
  let lines ← IO.FS.lines path
  let params : EvalParams := { flags := relayFlags, limits := consensusLimits }
  let mut n := 0
  let mut agree := 0
  let mut mismatch := 0
  let mut unimplAllowed := 0
  let mut unimplBad := 0
  let mut explainedN := 0
  let mut shown := 0
  let mut perFamily : Std.HashMap String (Nat × Nat × Nat) := {}   -- agree, mismatch, unimplemented
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
    let head := familyHead c.family
    let (fa, fm, fu) := perFamily.getD head (0, 0, 0)
    if kind == "undefined-in-reference" then
      IO.println s!"UNDEFINED-IN-REFERENCE {c.id} ({c.family}): {verdictShow v} (recorded, the S3 witness family)"
    else if kind == "unimplemented" then
      perFamily := perFamily.insert head (fa, fm, fu + 1)
      if deferred c.family then unimplAllowed := unimplAllowed + 1
      else
        unimplBad := unimplBad + 1
        if shown < 20 then
          shown := shown + 1
          IO.println s!"UNIMPLEMENTED {c.id} ({c.family}): {verdictShow v}"
    else if kind == c.expect then
      agree := agree + 1
      perFamily := perFamily.insert head (fa + 1, fm, fu)
    else if c.family.startsWith "mutation/" && explained v tx.version lock scriptSig c.expect then
      explainedN := explainedN + 1
    else
      mismatch := mismatch + 1
      perFamily := perFamily.insert head (fa, fm + 1, fu)
      if shown < 20 then
        shown := shown + 1
        IO.println s!"MISMATCH {c.id} ({c.family}): spec {verdictShow v} vs bsv-rs {c.expect}; lock {c.lockHex} unlock {hexEncode scriptSig} version {tx.version}"
  IO.println s!"seedcheck: {n} entries: agree {agree}, mismatch {mismatch}, mutation mismatches explained by bsv-rs's lenient parser, NOP undefined opcodes, push-only unlocks regardless of version or the expansion opcodes as NOPs (recorded, not counted) {explainedN}, unimplemented {unimplAllowed} in the deferred family (mutation/, the crypto and expansion opcodes of #11/#18) and {unimplBad} elsewhere"
  for (f, (a, m, u)) in perFamily.toList.mergeSort (fun x y => x.1 ≤ y.1) do
    IO.println s!"  {f}: agree {a}, mismatch {m}, unimplemented {u}"
  if agree == 0 then
    IO.println "seedcheck: ZERO comparable entries"
    return 1
  return (if mismatch == 0 && unimplBad == 0 then 0 else 1)
