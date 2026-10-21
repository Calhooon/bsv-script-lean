import BsvScript.Params
import BsvScript.Numbers
import BsvScript.Opcodes
/-!
# BsvScript.Machine

The stack machine (#8; `docs/DESIGN.md` §1.3, §2): the instruction parser, the
state, the execution loop of `EvalScript` (`interpreter.cpp:388–1833`), the flow
opcodes and the pushes, and the two-phase spend of `VerifyScript`
(`2304–2451`). Every other opcode family reaches the loop through the hook
`OpExec` (#9 arithmetic and bitwise, #10 stack and splice, #11 crypto, #18 the
rest); an opcode no family has written yet is the `unimplemented` verdict, a
build-time state that #18 makes unreachable.

Bare line numbers are `src/script/interpreter.cpp` at the pin
(`docs/PROVENANCE.md`).
-/

namespace BsvScript.Machine
open BsvScript.Params BsvScript.Numbers

/-! ## The instruction parser (`CScript::GetOp2`, `script.h:165–200`) -/

/-- `GetOp2` after the opcode byte (`script.h:173`): for a push opcode (`≤ OP_PUSHDATA4`,
`script.h:176`), the size is the opcode itself below `OP_PUSHDATA1` (`script.h:178–179`), else 1,
2 or 4 little-endian length bytes (`script.h:180–191`); a truncated length or a truncated push
fails the parse (`return false`, the push's own test at `script.h:192–193`). Returns the push
data (empty for a non-push opcode) and the number of bytes consumed after the opcode. -/
def getOpTail (op : Nat) (rest : Bytes) : Option (Bytes × Nat) :=
  if op ≤ Op.OP_PUSHDATA4 then
    let hdr : Option (Nat × Nat) :=      -- (the size, the length-prefix bytes)
      if op < Op.OP_PUSHDATA1 then some (op, 0)
      else if op = Op.OP_PUSHDATA1 then
        match rest with
        | n :: _ => some (n, 1)
        | [] => none
      else if op = Op.OP_PUSHDATA2 then
        match rest with
        | a :: b :: _ => some (a + 256 * b, 2)
        | _ => none
      else
        match rest with
        | a :: b :: c :: d :: _ => some (a + 256 * (b + 256 * (c + 256 * d)), 4)
        | _ => none
    match hdr with
    | none => none
    | some (n, p) =>
      let body := rest.drop p
      if body.length < n then none else some (body.take n, p + n)
  else some ([], 0)

/-- `CScript::IsPushOnly` (`script.cpp:209–220`): every instruction parses and no
opcode is above `OP_16` (`OP_RESERVED` counts as a push). -/
def isPushOnly : Bytes → Bool
  | [] => true
  | op :: rest =>
    match getOpTail op rest with
    | none => false
    | some (_, k) => if op > Op.OP_16 then false else isPushOnly (rest.drop k)
termination_by s => s.length
decreasing_by all_goals simp [List.length_drop]

/-- `IsP2SH` (`script.cpp:168–172`): 23 bytes, `OP_HASH160 <20 bytes> OP_EQUAL`. -/
def isP2SH (s : Bytes) : Bool :=
  s.length == 23 && s.head? == some Op.OP_HASH160 && s[1]? == some 0x14 && s[22]? == some Op.OP_EQUAL

/-- `CheckMinimalPush` (`331–358`): the push opcode used must be the smallest
that could carry the data. -/
def checkMinimalPush (data : Bytes) (op : Nat) : Bool :=
  match data with
  | [] => op == Op.OP_0
  | [b] =>
    if 1 ≤ b ∧ b ≤ 16 then op == Op.OP_1 + (b - 1)
    else if b = 0x81 then op == Op.OP_1NEGATE
    else op == 1
  | _ =>
    if data.length ≤ 75 then op == data.length
    else if data.length ≤ 255 then op == Op.OP_PUSHDATA1
    else if data.length ≤ 65535 then op == Op.OP_PUSHDATA2
    else true

/-- `IsOpcodeDisabled` (`360–375`): `OP_2MUL`/`OP_2DIV` unless the UTXO era is
post-Chronicle. -/
def isOpcodeDisabled (op : Nat) (era : Era) : Bool :=
  (op == Op.OP_2MUL || op == Op.OP_2DIV) && era != Era.postChronicle

/-- The transaction version as four little-endian bytes (`to_le`, `382–386`, on
the `int32`): what `OP_VER` pushes and `OP_VERIF`/`OP_VERNOTIF` compare. -/
def versionLE (v : Int) : Bytes :=
  let u := (v % (2 ^ 32)).toNat
  [u % 256, u / 256 % 256, u / 65536 % 256, u / 16777216 % 256]

/-! ## The conditional tracker (`conditional_tracker.h:12–26`, `.cpp:32–71`) -/

/-- The IF/ELSE/ENDIF state: the conditions (innermost first), the "else seen"
marks, and the count of false conditions. -/
structure Cond where
  conditions : List Bool := []
  elses : List Bool := []
  falseCount : Nat := 0
  deriving Repr, DecidableEq

namespace Cond
/-- `empty` (`.cpp:32–35`). -/
def empty (c : Cond) : Bool := c.conditions.isEmpty
/-- `is_active` (`46–49`): executing iff no enclosing condition is false. -/
def isActive (c : Cond) : Bool := c.falseCount == 0
/-- `op_if` (`37–44`). -/
def opIf (c : Cond) (b : Bool) : Cond :=
  { conditions := b :: c.conditions, elses := false :: c.elses,
    falseCount := if b then c.falseCount else c.falseCount + 1 }
/-- `has_op_else` (`51–55`): the innermost `IF` has seen an `ELSE`. -/
def hasOpElse (c : Cond) : Bool :=
  match c.elses with
  | [] => false
  | e :: _ => e
/-- `op_else` (`57–65`): flip the innermost condition, mark the else, adjust the count. -/
def opElse (c : Cond) : Cond :=
  match c.conditions, c.elses with
  | b :: bs, _ :: es =>
    { conditions := (!b) :: bs, elses := true :: es,
      falseCount := if b then c.falseCount + 1 else c.falseCount - 1 }
  | _, _ => c
/-- `op_endif` (`67–75`). -/
def opEndif (c : Cond) : Cond :=
  match c.conditions, c.elses with
  | b :: bs, _ :: es =>
    { conditions := bs, elses := es, falseCount := if b then c.falseCount else c.falseCount - 1 }
  | _, _ => c
end Cond

/-! ## The state, the context, the environment -/

/-- The machine state of one `EvalScript` call plus what crosses phases
(`docs/DESIGN.md` §1.3). The main stack and the alt stack are top-first. The
memory counter is the root `LimitedStack`'s `combinedStackSize`
(`limitedstack.h:86`): every element costs its size plus 32 (`limitedstack.h:43`),
the alt stack shares the budget (`1993`), and the counter is not decremented for
elements left on the alt stack when a phase ends (`1993–2005`). `codeSep` is the
script from the last `OP_CODESEPARATOR` on (`pbegincodehash`, `407`, `1445–1448`). -/
structure State where
  stack : List Bytes := []
  alt : List Bytes := []
  memUsed : Nat := 0
  cond : Cond := {}
  opCount : Nat := 0
  nonTopLevelReturn : Bool := false
  codeSep : Bytes := []
  deriving Repr

/-- `LimitedVector::ELEMENT_OVERHEAD` (`limitedstack.h:43`). -/
def elementOverhead : Nat := 32

/-- The transaction context a script is evaluated in (`docs/DESIGN.md` §1.5):
the `BaseSignatureChecker` (`interpreter.h:52`) as functions. `version` is the
spending transaction's `nVersion` read as a signed 32-bit integer (`2254–2257`);
`checkLockTime`/`checkSequence` are `TransactionSignatureChecker::CheckLockTime`/
`CheckSequence` (`2166–2253`, #22); `checkSig` is `CheckSig` (`2133–2164`,
#11/#12) on (signature, pubkey, scriptCode, FORKID enabled). -/
structure Context where
  version : Int
  checkLockTime : Int → Bool
  checkSequence : Int → Bool
  checkSig : Bytes → Bytes → Bytes → Bool → Bool

/-- The per-call environment of `EvalScript`. -/
structure Env where
  /-- the parameters, the flag word gated (`Flags.gate`) -/
  params : EvalParams
  ctx : Context
  /-- `requireMinimal` (`433–434`): MINIMALDATA under the version gate. -/
  requireMinimal : Bool
  /-- the strict DER shape is demanded (`275–277`): DERSIG, LOW_S or STRICTENC in the
  original word, ungated -/
  strictDer : Bool
  /-- The UTXO's era from the flag word (`411–427`). -/
  utxoEra : Era
  /-- `checksigData` (`2338–2352`): the locking script, while the unlocking script runs. -/
  checksigData : Option Bytes

namespace Env
def utxoAfterGenesis (e : Env) : Bool := e.utxoEra != Era.preGenesis
def utxoAfterChronicle (e : Env) : Bool := e.utxoEra == Era.postChronicle
end Env

/-- Pushing an element accounts its size plus the overhead against the budget
(`limitedstack.h:163–173`, `limitedstack.cpp:194–207`); over the budget is
`stack_overflow_error` → `SCRIPT_ERR_STACK_SIZE` (`1815–1818`). -/
def pushElem (env : Env) (st : State) (x : Bytes) : Except ScriptError State :=
  let need := st.memUsed + x.length + elementOverhead
  if need > env.params.limits.maxStackMemoryUsage then .error .stackSize
  else .ok { st with stack := x :: st.stack, memUsed := need }

/-- Popping the top element (`limitedstack.cpp:211–219`); the callers check the
size first, so the empty case is unreachable and reported as a stack error. -/
def popElem (st : State) : Except ScriptError (Bytes × State) :=
  match st.stack with
  | [] => .error .invalidStackOperation
  | x :: xs => .ok (x, { st with stack := xs, memUsed := st.memUsed - (x.length + elementOverhead) })

/-- The result of one executed instruction. -/
inductive StepR where
  /-- continue with the new state -/
  | cont (st : State)
  /-- terminate the script successfully now (a top-level `OP_RETURN` post-Genesis, `858–861`) -/
  | done
  | fail (e : ScriptError)
  /-- no family module has written this opcode yet -/
  | unimpl (op : Nat)
  /-- the reference's code is undefined on this input (`docs/DESIGN.md` §1.2, §9 Q7): the
  witness family of the S3 harness is named; the harness's `undecided` -/
  | undefined (family : String)

/-- What a family module returns for an opcode it owns: the new state, the
reference's error, or the name of the witness family when the reference's code
is undefined on the input (Q7). -/
inductive HookR where
  | ok (st : State)
  | fail (e : ScriptError)
  | undefined (family : String)

def HookR.ofExcept : Except ScriptError State → HookR
  | .ok st => .ok st
  | .error e => .fail e

/-- A family's `Except` result is a `HookR` (the coercion the `exec` hooks use). -/
instance : Coe (Except ScriptError State) HookR := ⟨HookR.ofExcept⟩

/-- What a family module contributes to the loop: `none` when the opcode is not
its own. The opcode's push data is passed for completeness (always empty above
`OP_PUSHDATA4`). -/
abbrev OpExec := Nat → Bytes → Env → State → Option HookR

/-- The outcome of one `EvalScript` call. -/
inductive Outcome where
  | ok
  | err (e : ScriptError)
  /-- the reference's code is undefined on the input (Q7); the family named -/
  | undefinedInReference (family : String)
  | unimplemented (op : Nat)
  deriving DecidableEq, Repr

/-! ## The flow opcodes -/

/-- `OP_IF`/`OP_NOTIF`/`OP_VERIF`/`OP_VERNOTIF` (`784–825`): when executing, pop
the condition (`792–793`, `821`), MINIMALIF under the version gate for
`IF`/`NOTIF` only (`796–804`), the version comparison for `VERIF`/`VERNOTIF`
(`806–812`: only a 4-byte element can be true), `CastToBool` otherwise (`815`),
negated for the NOT forms (`817–818`); a non-executing one pushes `false`
without popping (`789`, `823`). -/
def execIf (env : Env) (op : Nat) (fExec : Bool) (st : State) : StepR :=
  if fExec then
    match st.stack with
    | [] => .fail .unbalancedConditional
    | vch :: rest =>
      let minimalIfViolation :=
        (op == Op.OP_IF || op == Op.OP_NOTIF) && env.params.flags.minimalIf &&
          (vch.length > 1 || (vch.length == 1 && vch.head? != some 1))
      if minimalIfViolation && enforceNonMalleability env.params.flags env.ctx.version then .fail .minimalif
      else
        let v0 :=
          if op == Op.OP_VERIF || op == Op.OP_VERNOTIF then
            vch.length == 4 && vch == versionLE env.ctx.version
          else castToBool vch
        let v := if op == Op.OP_NOTIF || op == Op.OP_VERNOTIF then !v0 else v0
        let st' := { st with stack := rest, memUsed := st.memUsed - (vch.length + elementOverhead) }
        .cont { st' with cond := st'.cond.opIf v }
  else .cont { st with cond := st.cond.opIf false }

/-- `OP_CHECKLOCKTIMEVERIFY` (`519–560`): a NOP for post-Genesis UTXOs or without
the flag (discouraged under the policy flag, `520–526`); else a 5-byte number
(`546`), non-negative (`550–551`), against the checker (`555–556`). Leaves the
operand on the stack. -/
def execCltv (env : Env) (st : State) : StepR :=
  if !env.params.flags.checkLockTimeVerify || env.utxoAfterGenesis then
    if env.params.flags.discourageUpgradableNops then .fail .discourageUpgradableNops else .cont st
  else
    match st.stack with
    | [] => .fail .invalidStackOperation
    | top :: _ =>
      match readNum top env.requireMinimal 5 with
      | .error .overflow => .fail .scriptnumOverflow
      | .error .minencode => .fail .scriptnumMinencode
      | .ok n =>
        if n < 0 then .fail .negativeLocktime
        else if !env.ctx.checkLockTime n then .fail .unsatisfiedLocktime
        else .cont st

/-- `OP_CHECKSEQUENCEVERIFY` (`562–597`): as CLTV, plus an operand with the
disable flag (bit 31, `transaction.h:106`) makes it a NOP (`585–587`). -/
def execCsv (env : Env) (st : State) : StepR :=
  if !env.params.flags.checkSequenceVerify || env.utxoAfterGenesis then
    if env.params.flags.discourageUpgradableNops then .fail .discourageUpgradableNops else .cont st
  else
    match st.stack with
    | [] => .fail .invalidStackOperation
    | top :: _ =>
      match readNum top env.requireMinimal 5 with
      | .error .overflow => .fail .scriptnumOverflow
      | .error .minencode => .fail .scriptnumMinencode
      | .ok n =>
        if n < 0 then .fail .negativeLocktime
        else if Nat.testBit n.toNat 31 then .cont st
        else if !env.ctx.checkSequence n then .fail .unsatisfiedLocktime
        else .cont st

/-- The pushes and the flow opcodes of the switch (`483–871`), then the family
hook. Called with `fExec`, or for `OP_IF`…`OP_ENDIF` regardless (`482`). -/
def execFlow (exec : OpExec) (env : Env) (op : Nat) (data : Bytes) (fExec : Bool) (st : State) : StepR :=
  if (op = Op.OP_1NEGATE) ∨ (Op.OP_1 ≤ op ∧ op ≤ Op.OP_16) then
    -- `488–507`: CScriptNum((int)opcode - (int)(OP_1 - 1)), pushed as bytes
    match pushElem env st (encode ((op : Int) - ((Op.OP_1 - 1 : Nat) : Int))) with
    | .ok st' => .cont st'
    | .error e => .fail e
  else if op = Op.OP_NOP then .cont st                                          -- 516
  else if op = Op.OP_CHECKLOCKTIMEVERIFY then execCltv env st                    -- 519–560
  else if op = Op.OP_CHECKSEQUENCEVERIFY then execCsv env st                     -- 562–597
  else if op = Op.OP_VER then                                                    -- 598–608
    if !env.utxoAfterChronicle then .fail .badOpcode
    else
      match pushElem env st (versionLE env.ctx.version) with
      | .ok st' => .cont st'
      | .error e => .fail e
  else if op = Op.OP_NOP1 ∨ op = Op.OP_NOP9 ∨ op = Op.OP_NOP10 then             -- 765–771
    if env.params.flags.discourageUpgradableNops then .fail .discourageUpgradableNops else .cont st
  else if op = Op.OP_VERIF ∨ op = Op.OP_VERNOTIF then                           -- 773–781
    if !env.utxoAfterChronicle then
      (if env.utxoAfterGenesis && !fExec then .cont st else .fail .badOpcode)
    else execIf env op fExec st
  else if op = Op.OP_IF ∨ op = Op.OP_NOTIF then execIf env op fExec st           -- 784–825
  else if op = Op.OP_ELSE then                                                   -- 827–833
    if st.cond.empty || (st.cond.hasOpElse && env.utxoAfterGenesis) then .fail .unbalancedConditional
    else .cont { st with cond := st.cond.opElse }
  else if op = Op.OP_ENDIF then                                                  -- 835–840
    if st.cond.empty then .fail .unbalancedConditional else .cont { st with cond := st.cond.opEndif }
  else if op = Op.OP_VERIFY then                                                 -- 842–854
    match st.stack with
    | [] => .fail .invalidStackOperation
    | x :: xs =>
      if castToBool x then .cont { st with stack := xs, memUsed := st.memUsed - (x.length + elementOverhead) }
      else .fail .verify
  else if op = Op.OP_RETURN then                                                 -- 856–871
    if env.utxoAfterGenesis then
      (if st.cond.empty then .done else .cont { st with nonTopLevelReturn := true })
    else .fail .opReturn
  else
    match exec op data env st with
    | some (.ok st') => .cont st'
    | some (.fail e) => .fail e
    | some (.undefined f) => .undefined f
    | none =>
      -- the `default:` case (`1795`): an opcode with no `case` label is `SCRIPT_ERR_BAD_OPCODE`
      -- when executed; an opcode with a label that no family has written yet is `unimplemented`
      if Op.hasCase op then .unimpl op else .fail .badOpcode

/-! ## The loop (`EvalScript`, `388–1833`) -/

/-- One opcode once the guards passed: a push under `fExec` (`473–481`), the
separator (`1445–1448`, the loop's own: `pbegincodehash = pc`, the byte after
it), the switch under `fExec` or for `OP_IF`…`OP_ENDIF` regardless (`482`),
else nothing (an unexecuted branch). -/
def execStep (exec : OpExec) (env : Env) (op : Nat) (data : Bytes) (rest : Bytes) (k : Nat)
    (fExec : Bool) (st : State) : StepR :=
  if fExec && op ≤ Op.OP_PUSHDATA4 then
    if env.requireMinimal && !checkMinimalPush data op then .fail .minimaldata
    else
      match pushElem env st data with
      | .ok st' => .cont st'
      | .error e => .fail e
  else if fExec && op = Op.OP_CODESEPARATOR then .cont { st with codeSep := rest.drop k }
  else if fExec || (Op.OP_IF ≤ op && op ≤ Op.OP_ENDIF) then execFlow exec env op data fExec st
  else .cont st

/-- One instruction per step: parse (`450–451`), the pre-Genesis push size
(`455–456`), `fExec` (`459`), the op count (`466–467`, `377–380`), the disabled
opcodes (`470–471`), a push (`473–481`) or the switch (`482`), then the
pre-Genesis stack limit (`1800–1803`); at the end of the script an open
conditional is unbalanced (`1828–1830`). -/
def loop (exec : OpExec) (env : Env) : (s : Bytes) → State → Outcome × State
  | [], st => if st.cond.empty then (.ok, st) else (.err .unbalancedConditional, st)
  | op :: rest, st =>
    match getOpTail op rest with
    | none => (.err .badOpcode, st)
    | some (data, k) =>
      if !env.utxoAfterGenesis && data.length > Consensus.maxScriptElementSizeBeforeGenesis then (.err .pushSize, st)
      else
        let fExec := st.cond.isActive && (!st.nonTopLevelReturn || op == Op.OP_RETURN)
        let st := if op > Op.OP_16 then { st with opCount := st.opCount + 1 } else st
        if op > Op.OP_16 && st.opCount > env.params.limits.maxOpsPerScript then (.err .opCount, st)
        else if isOpcodeDisabled op env.utxoEra && (!env.utxoAfterGenesis || fExec) then (.err .disabledOpcode, st)
        else
          match execStep exec env op data rest k fExec st with
          | .fail e => (.err e, st)
          | .unimpl o => (.unimplemented o, st)
          | .undefined f => (.undefinedInReference f, st)
          | .done => (.ok, st)
          | .cont st' =>
            if !env.utxoAfterGenesis && st'.stack.length + st'.alt.length > Consensus.maxStackElementsBeforeGenesis then
              (.err .stackSize, st')
            else loop exec env (rest.drop k) st'
termination_by s => s.length
decreasing_by all_goals simp [List.length_drop]

/-- `EvalScript` (`388–1833`) on a script with the main stack and the memory
counter carried in: the script size (`429–430`), then the loop with a fresh alt
stack, tracker and `pbegincodehash` (`1984–2006`, `407`). -/
def evalScript (exec : OpExec) (env : Env) (script : Bytes) (stack : List Bytes) (memUsed : Nat) : Outcome × State :=
  let st : State := { stack := stack, memUsed := memUsed, codeSep := script }
  if script.length > env.params.limits.maxScriptSize then (.err .scriptSize, st)
  else loop exec env script st

/-! ## The two-phase spend (`VerifyScript`, `2304–2451`) -/

/-- The verdict of a spend (`docs/DESIGN.md` §2.1): `SCRIPT_ERR_OK` is valid,
any other `ScriptError` is invalid with that reason; `unimplemented` is the
build-time state of an opcode no family has written (never a verdict of the
reference; #18 removes it). -/
inductive Verdict where
  | valid
  | invalid (e : ScriptError)
  | unimplemented (op : Nat)
  /-- the reference's code is undefined on the input (Q7): not a verdict of the
  reference; the witness family of the S3 harness is named -/
  | undefinedInReference (family : String)
  deriving DecidableEq, Repr

/-! ## The two phases (`VerifyScript`, `2304–2451`): the P2SH stack copy for a
pre-Genesis UTXO (`2354–2356`), the locking script on the resulting stack
(`2358–2372`), the final-stack rule (`2374–2378`), P2SH for a pre-Genesis UTXO
(`2380–2424`), CLEANSTACK (`2430–2448`). -/

/-- The environment of a phase: the original word `flags0` (after STRICTENC from
FORKID, `2315–2319`) gated by the version (`Flags.gate`), the era and the two
derived bits. -/
def mkEnv (params : EvalParams) (ctx : Context) (flags0 : Flags) (checksigData : Option Bytes) : Env :=
  let flags := flags0.gate ctx.version
  { params := { params with flags := flags }, ctx := ctx,
    requireMinimal := flags.minimalData && enforceNonMalleability flags ctx.version,
    strictDer := flags0.strictDer,
    utxoEra := flags0.utxoEra, checksigData := checksigData }

/-- The locking phase and what follows (#16, P4): of the unlocking phase's state it reads the main stack and
the memory counter only (`2358–2372`: the locking script runs on the stack the unlocking script left,
`2354–2356`: the P2SH copy of it); it also reads the unlocking script's bytes, whose push-only test the P2SH
branch repeats (`2382–2388`; `Properties.phase2_stack_mem_only` holds them fixed). -/
def phase2 (exec : OpExec) (params : EvalParams) (ctx : Context) (flags0 : Flags) (scriptSig scriptPubKey : Bytes)
    (stack : List Bytes) (memUsed : Nat) : Verdict :=
  let flags := flags0.gate ctx.version
  let stackCopy : Option (List Bytes × Nat) :=
    if flags0.p2shCopy then some (stack, memUsed) else none
  match evalScript exec (mkEnv params ctx flags0 none) scriptPubKey stack memUsed with
        | (.err e, _) => .invalid e
        | (.unimplemented o, _) => .unimplemented o
        | (.undefinedInReference f, _) => .undefinedInReference f
        | (.ok, st2) =>
          match st2.stack with
          | [] => .invalid .evalFalse
          | top :: _ =>
            if !castToBool top then .invalid .evalFalse
            else
              -- P2SH (`2380–2424`), pre-Genesis UTXOs only
              let afterP2sh : Verdict × State :=
                match stackCopy with
                | some (copy, mem) =>
                  if isP2SH scriptPubKey then
                    if !isPushOnly scriptSig then (.invalid .sigPushonly, st2)
                    else
                      match copy with
                      | [] => (.invalid .evalFalse, st2)   -- unreachable: asserted non-empty (`2395–2398`)
                      | pubKey2 :: copyRest =>
                        let mem' := mem - (pubKey2.length + elementOverhead)
                        match evalScript exec (mkEnv params ctx flags0 none) pubKey2 copyRest mem' with
                        | (.err e, s) => (.invalid e, s)
                        | (.unimplemented o, s) => (.unimplemented o, s)
                        | (.undefinedInReference f, s) => (.undefinedInReference f, s)
                        | (.ok, st3) =>
                          match st3.stack with
                          | [] => (.invalid .evalFalse, st3)
                          | t3 :: _ => if !castToBool t3 then (.invalid .evalFalse, st3) else (.valid, st3)
                  else (.valid, st2)
                | none => (.valid, st2)
              match afterP2sh with
              | (.valid, stF) =>
                -- CLEANSTACK (`2430–2448`): the P2SH demand ungated (`2432–2435`), the stack-size
                -- test under the gate (`2441–2445`)
                if flags0.cleanStackDemand then .invalid .invalidFlags
                else if flags.cleanStack && stF.stack.length != 1 then .invalid .cleanstack
                else .valid
              | (v, _) => v

/-- `VerifyScript` (`2304–2451`): `valid_flags` (`2312–2313`), STRICTENC from FORKID
(`2315–2319`), the SIGPUSHONLY gate (`2321–2334`), the unlocking script with the
locking script as `checksigData` (`2338–2352`), then `phase2` on the main stack
and the memory counter it left. -/
def verifyScript (exec : OpExec) (params : EvalParams) (ctx : Context) (scriptSig scriptPubKey : Bytes) : Verdict :=
  if !params.flags.valid then .invalid .invalidFlags
  else
    let flags0 := params.flags.forkAdjust
    let flags := flags0.gate ctx.version
    let pushOnlyRequired :=
      flags.sigPushOnly &&
        ((flags.genesis && !flags.chronicle) || (flags.chronicle && !isMalleableTxnVersion ctx.version))
    if pushOnlyRequired && !isPushOnly scriptSig then .invalid .sigPushonly
    else
      match evalScript exec (mkEnv params ctx flags0 (some scriptPubKey)) scriptSig [] 0 with
      | (.err e, _) => .invalid e
      | (.unimplemented o, _) => .unimplemented o
      | (.undefinedInReference f, _) => .undefinedInReference f
      | (.ok, st1) => phase2 exec params ctx flags0 scriptSig scriptPubKey st1.stack st1.memUsed


-- ======================================================================================================
-- THE COMPILED IMPLEMENTATIONS (#45; S1, Lean A, 2026-09-26). The definitions above are the semantics and
-- do not move; each function below is proven equal to one of them and `@[csimp]` makes the compiler
-- substitute it in the code compiled after the lemma, a csimp lemma rewriting only the calls compiled after it
-- (see the same section of `Numbers.lean`). Why: `getOpTail`
-- measures the REST OF THE SCRIPT for every push (`body.length < n`), so a script of k pushes costs
-- k × its length (`List.lengthTR` 1,394 of 1,399 stack samples on a 400 KB script of 32-byte pushes,
-- `docs/records/20260926-205320-ladder45-s1.md`); `takeExact` walks the push's own length once. The
-- copies `isPushOnlyFast` … `verifyScriptFast` are the definitions restated after the csimp lemmas of
-- what they call, so their compiled code runs the fast parser; each equality is `rfl` (the loop's under
-- `unseal`) but the push-only test's, proved by `isPushOnly.induct` case by case. The explainers were
-- comments until 2026-09-27 (the reason given in `Numbers.lean`'s section); each theorem
-- has its docstring since.

-- The first `n` elements when the list has at least `n`, else `none`.
def takeExact (n : Nat) (l : Bytes) : Option Bytes := go n l []
where
  go : Nat → Bytes → Bytes → Option Bytes
  | 0, _, acc => some acc.reverse
  | _ + 1, [], _ => none
  | k + 1, x :: xs, acc => go k xs (x :: acc)

/-- The accumulator form of `takeExact`: `none` when fewer than `k` elements remain, else the accumulator reversed followed by the first `k`. -/
theorem takeExact_go_eq (k : Nat) (l acc : Bytes) :
    takeExact.go k l acc = if l.length < k then none else some (acc.reverse ++ l.take k) := by
  induction k generalizing l acc with
  | zero => simp [takeExact.go]
  | succ k ih =>
    cases l with
    | nil => simp [takeExact.go]
    | cons x xs =>
      rw [takeExact.go, ih]
      by_cases hl : xs.length < k
      · rw [ite_eq_left hl, ite_eq_left (by simpa using hl)]
      · rw [ite_eq_right hl, ite_eq_right (by simpa using hl)]
        simp [List.take_succ_cons]

/-- `takeExact n l` is `l.take n` when the list has at least `n` elements, else `none`: the parser's length test (`script.h:192–193`, `body.length < n`) walked over the push's own length once. -/
theorem takeExact_eq (n : Nat) (l : Bytes) : takeExact n l = if l.length < n then none else some (l.take n) := by
  unfold takeExact; rw [takeExact_go_eq]; simp

-- The push header alone (`getOpTail`'s `hdr`, factored): the size and the length-prefix bytes.
def pushHeader (op : Nat) (rest : Bytes) : Option (Nat × Nat) :=
  if op < Op.OP_PUSHDATA1 then some (op, 0)
  else if op = Op.OP_PUSHDATA1 then
    match rest with
    | n :: _ => some (n, 1)
    | [] => none
  else if op = Op.OP_PUSHDATA2 then
    match rest with
    | a :: b :: _ => some (a + 256 * b, 2)
    | _ => none
  else
    match rest with
    | a :: b :: c :: d :: _ => some (a + 256 * (b + 256 * (c + 256 * d)), 4)
    | _ => none

-- `getOpTail` with the push's own length walked once.
def getOpTailFast (op : Nat) (rest : Bytes) : Option (Bytes × Nat) :=
  if op ≤ Op.OP_PUSHDATA4 then
    match pushHeader op rest with
    | none => none
    | some (n, p) =>
      match takeExact n (rest.drop p) with
      | none => none
      | some data => some (data, p + n)
  else some ([], 0)

/-- `@[csimp]` (#45): the compiler parses with `getOpTailFast`, which walks the push's own length (`takeExact`) instead of measuring the rest of the script for every push (the parser's wall of `docs/records/20260926-205320-ladder45-s1.md`, quadratic in pushes × script); by cases on the five shapes of the push header; nothing in the semantics moves. -/
@[csimp] theorem getOpTail_eq_fast : @getOpTail = @getOpTailFast := by
  funext op rest
  simp only [getOpTail, getOpTailFast, pushHeader, takeExact_eq]
  split
  · rcases rest with _ | ⟨a, _ | ⟨b, _ | ⟨c, _ | ⟨d, tl⟩⟩⟩⟩ <;> split_ifs <;> simp <;> split <;> simp_all
  · rfl

-- The copies (the same definitions, restated after the csimp lemmas of what they call).
def isPushOnlyFast : Bytes → Bool
  | [] => true
  | op :: rest =>
    match getOpTail op rest with
    | none => false
    | some (_, k) => if op > Op.OP_16 then false else isPushOnlyFast (rest.drop k)
termination_by s => s.length
decreasing_by all_goals simp [List.length_drop]

/-- `@[csimp]`: `isPushOnly` restated after the parser's csimp lemma so its compiled code calls the fast parser; the same recursion, by `isPushOnly.induct` case by case. -/
@[csimp] theorem isPushOnly_eq_fast : @isPushOnly = @isPushOnlyFast := by
  funext s
  induction s using isPushOnly.induct with
  | case1 => rw [isPushOnly, isPushOnlyFast]
  | case2 op rest h => rw [isPushOnly, isPushOnlyFast]; simp [h]
  | case3 op rest data k h hop => rw [isPushOnly, isPushOnlyFast]; simp [h, hop]
  | case4 op rest data k h hop ih => rw [isPushOnly, isPushOnlyFast]; simp [h, hop, ih]

def loopFast (exec : OpExec) (env : Env) : (s : Bytes) → State → Outcome × State
  | [], st => if st.cond.empty then (.ok, st) else (.err .unbalancedConditional, st)
  | op :: rest, st =>
    match getOpTail op rest with
    | none => (.err .badOpcode, st)
    | some (data, k) =>
      if !env.utxoAfterGenesis && data.length > Consensus.maxScriptElementSizeBeforeGenesis then (.err .pushSize, st)
      else
        let fExec := st.cond.isActive && (!st.nonTopLevelReturn || op == Op.OP_RETURN)
        let st := if op > Op.OP_16 then { st with opCount := st.opCount + 1 } else st
        if op > Op.OP_16 && st.opCount > env.params.limits.maxOpsPerScript then (.err .opCount, st)
        else if isOpcodeDisabled op env.utxoEra && (!env.utxoAfterGenesis || fExec) then (.err .disabledOpcode, st)
        else
          match execStep exec env op data rest k fExec st with
          | .fail e => (.err e, st)
          | .unimpl o => (.unimplemented o, st)
          | .undefined f => (.undefinedInReference f, st)
          | .done => (.ok, st)
          | .cont st' =>
            if !env.utxoAfterGenesis && st'.stack.length + st'.alt.length > Consensus.maxStackElementsBeforeGenesis then
              (.err .stackSize, st')
            else loopFast exec env (rest.drop k) st'
termination_by s => s.length
decreasing_by all_goals simp [List.length_drop]

unseal loop loopFast in
/-- `@[csimp]`: the loop restated after the parser's csimp lemma; the same term once both recursions are unsealed (`rfl`). -/
@[csimp] theorem loop_eq_fast : @loop = @loopFast := rfl

def evalScriptFast (exec : OpExec) (env : Env) (script : Bytes) (stack : List Bytes) (memUsed : Nat) : Outcome × State :=
  let st : State := { stack := stack, memUsed := memUsed, codeSep := script }
  if script.length > env.params.limits.maxScriptSize then (.err .scriptSize, st)
  else loop exec env script st

/-- `@[csimp]`: `evalScript` restated after the loop's; the same term (`rfl`). -/
@[csimp] theorem evalScript_eq_fast : @evalScript = @evalScriptFast := rfl

def phase2Fast (exec : OpExec) (params : EvalParams) (ctx : Context) (flags0 : Flags) (scriptSig scriptPubKey : Bytes)
    (stack : List Bytes) (memUsed : Nat) : Verdict :=
  let flags := flags0.gate ctx.version
  let stackCopy : Option (List Bytes × Nat) :=
    if flags0.p2shCopy then some (stack, memUsed) else none
  match evalScript exec (mkEnv params ctx flags0 none) scriptPubKey stack memUsed with
        | (.err e, _) => .invalid e
        | (.unimplemented o, _) => .unimplemented o
        | (.undefinedInReference f, _) => .undefinedInReference f
        | (.ok, st2) =>
          match st2.stack with
          | [] => .invalid .evalFalse
          | top :: _ =>
            if !castToBool top then .invalid .evalFalse
            else
              let afterP2sh : Verdict × State :=
                match stackCopy with
                | some (copy, mem) =>
                  if isP2SH scriptPubKey then
                    if !isPushOnly scriptSig then (.invalid .sigPushonly, st2)
                    else
                      match copy with
                      | [] => (.invalid .evalFalse, st2)
                      | pubKey2 :: copyRest =>
                        let mem' := mem - (pubKey2.length + elementOverhead)
                        match evalScript exec (mkEnv params ctx flags0 none) pubKey2 copyRest mem' with
                        | (.err e, s) => (.invalid e, s)
                        | (.unimplemented o, s) => (.unimplemented o, s)
                        | (.undefinedInReference f, s) => (.undefinedInReference f, s)
                        | (.ok, st3) =>
                          match st3.stack with
                          | [] => (.invalid .evalFalse, st3)
                          | t3 :: _ => if !castToBool t3 then (.invalid .evalFalse, st3) else (.valid, st3)
                  else (.valid, st2)
                | none => (.valid, st2)
              match afterP2sh with
              | (.valid, stF) =>
                if flags0.cleanStackDemand then .invalid .invalidFlags
                else if flags.cleanStack && stF.stack.length != 1 then .invalid .cleanstack
                else .valid
              | (v, _) => v

/-- `@[csimp]`: `phase2` restated after `evalScript`'s and `isPushOnly`'s; the same term (`rfl`). -/
@[csimp] theorem phase2_eq_fast : @phase2 = @phase2Fast := rfl

def verifyScriptFast (exec : OpExec) (params : EvalParams) (ctx : Context) (scriptSig scriptPubKey : Bytes) : Verdict :=
  if !params.flags.valid then .invalid .invalidFlags
  else
    let flags0 := params.flags.forkAdjust
    let flags := flags0.gate ctx.version
    let pushOnlyRequired :=
      flags.sigPushOnly &&
        ((flags.genesis && !flags.chronicle) || (flags.chronicle && !isMalleableTxnVersion ctx.version))
    if pushOnlyRequired && !isPushOnly scriptSig then .invalid .sigPushonly
    else
      match evalScript exec (mkEnv params ctx flags0 (some scriptPubKey)) scriptSig [] 0 with
      | (.err e, _) => .invalid e
      | (.unimplemented o, _) => .unimplemented o
      | (.undefinedInReference f, _) => .undefinedInReference f
      | (.ok, st1) => phase2 exec params ctx flags0 scriptSig scriptPubKey st1.stack st1.memUsed

/-- `@[csimp]`: `verifyScript` restated after `phase2`'s and `evalScript`'s; the same term (`rfl`), so every theorem about `verifyScript` is about the definition. A compiled call of `Machine.verifyScript` runs the fast parser and the fast number loops. Since #50 the evaluator's own compiled calls do not come here: they go through `Eval.verifyScript`, which `Eval.verifyScript_eq_I` sends to the array machine `verifyScriptI`; this lemma reaches the direct compiled calls of `Machine.verifyScript` alone (the flow leg's list-machine row, `lean/Test/FlowCheck.lean`). -/
@[csimp] theorem verifyScript_eq_fast : @verifyScript = @verifyScriptFast := rfl

-- ======================================================================================================
-- THE DEPTH TESTS' COMPILED FORM (#48, 2026-09-29). Every opcode that needs k
-- operands tests the stack's depth before it reads them (`stack.size() < k`, e.g. `interpreter.cpp:1231–1232`,
-- `1294–1295`; some test the era or a flag first, e.g. the expansion opcodes, `611` then `619`). The definitions state it
-- as `st.stack.length < k`, and the compiled `List.length` walks the whole stack, so on a deep stack every
-- instruction pays the depth: `List.lengthTR` held 88 % of the stack sampler's 11,773 samples on a 2 MB lock's
-- version-1 judgment (446.39 s), called from `Ops.Stack.execStack` and `Ops.Arith.binary`
-- (the depth wall's record, withheld from the public edition). `atLeast k l` walks at most `k` elements; each family's
-- function with a depth test has a copy that uses it, proven equal and marked `@[csimp]` right after its
-- definition, so every compiled caller runs the copy and every theorem stays about the definition.

/-- Whether a list holds at least `n` elements, walking at most `n` of them (#48). -/
def atLeast {α : Type} : Nat → List α → Bool
  | 0, _ => true
  | _ + 1, [] => false
  | n + 1, _ :: xs => atLeast n xs

/-- **`atLeast_eq`.** *What it says:* `atLeast n l` decides `n ≤ l.length`. *What it assumes:* nothing.
*Why it matters:* it is the one fact every depth test's compiled copy rests on (#48): the copy's answer is the
definition's, and it walks at most `n` elements where `List.length` walks them all. -/
theorem atLeast_eq {α : Type} (n : Nat) (l : List α) : atLeast n l = decide (n ≤ l.length) := by
  induction n generalizing l with
  | zero => simp [atLeast]
  | succ n ih =>
    cases l with
    | nil => simp [atLeast]
    | cons x xs => simp [atLeast, ih]

end BsvScript.Machine
