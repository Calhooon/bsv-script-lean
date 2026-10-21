import BsvScript.Eval
import Test.OpNames
/-!
# Bsvs.Trace: the evaluator's trace, proven to be the loop's own execution (#14)

The CLI reports what the machine did instruction by instruction. The machine's
loop (`BsvScript.Machine.loop`, `EvalScript` `interpreter.cpp:388–1833`) is
the semantics and is not duplicated here: `stepK` is one instruction of the
loop with its two exits abstracted, `loop_stepK` proves that the loop is
`stepK` with the loop as its continuation (the loop's own recursion equation,
by unfolding), and `traceLoop` is the loop written with `stepK` plus an
accumulator of steps. `traceLoop_fst` proves that the traced run returns
exactly `loop`'s result (through `stepK_map`, the exits being the only places a
value leaves `stepK`): the outcome the trace prints for a phase is the list
machine's `Machine.loop` outcome of that phase. The CLI's verdict is NOT taken from
the trace: it is `Eval.verifyScript`, compiled as `verifyScriptI` (the array machine,
`verifyScript_eq_I`), and `--trace` runs the same spend a second time on the list
machine (`traceVerifyScript`; lean #32's second lens, A-10, and its final lens on
Lean B, NEW-7). The steps it prints are recorded inside the same `stepK`
continuation, so each is a state of the list machine's run by construction; no
statement of the list of steps is proven (lean #32's second lens, B-10).

The trace records, per instruction: the byte offset, the opcode and its push
length, whether it executed (`fExec`, `459`), the outcome (`cont`, `done`,
`fail <code>`, `unimplemented`), and after it the stack depth, the alt-stack
depth, the top element, the memory counter and the op count.
-/

namespace Bsvs.Trace
open BsvScript BsvScript.Params BsvScript.Numbers BsvScript.Machine

/-- One instruction of `Machine.loop` (the `op :: rest` case), body for body, with
its two exits abstracted: `kont` receives the state after the instruction and the
number of bytes consumed after the opcode, `stop` the outcome and the state when
the instruction ends the script. The parse (`450–451`), the pre-Genesis push size
(`455–456`), `fExec` (`459`), the op count (`466–467`, `377–380`), the disabled
opcodes (`470–471`), then the instruction itself (`Machine.execStep`: a push
`473–481`, the separator `1445–1448`, the switch `482`, or nothing in a dead
branch; #18), the pre-Genesis stack limit (`1800–1803`). `loop_stepK` proves it
is the loop's body. -/
def stepK {α : Type} (exec : OpExec) (env : Env) (op : Nat) (rest : Bytes) (st : State)
    (kont : State → Nat → α) (stop : Outcome × State → α) : α :=
  match getOpTail op rest with
  | none => stop (.err .badOpcode, st)
  | some (data, k) =>
    if !env.utxoAfterGenesis && data.length > Consensus.maxScriptElementSizeBeforeGenesis then stop (.err .pushSize, st)
    else
      let fExec := st.cond.isActive && (!st.nonTopLevelReturn || op == Op.OP_RETURN)
      let st := if op > Op.OP_16 then { st with opCount := st.opCount + 1 } else st
      if op > Op.OP_16 && st.opCount > env.params.limits.maxOpsPerScript then stop (.err .opCount, st)
      else if isOpcodeDisabled op env.utxoEra && (!env.utxoAfterGenesis || fExec) then stop (.err .disabledOpcode, st)
      else
        match execStep exec env op data rest k fExec st with
        | .fail e => stop (.err e, st)
        | .unimpl o => stop (.unimplemented o, st)
        | .undefined f => stop (.undefinedInReference f, st)
        | .done => stop (.ok, st)
        | .cont st' =>
          if !env.utxoAfterGenesis && st'.stack.length + st'.alt.length > Consensus.maxStackElementsBeforeGenesis then
            stop (.err .stackSize, st')
          else kont st' k

/-- **The loop is `stepK` with itself as the continuation.** *What it says:* on a
non-empty script, `Machine.loop` is one `stepK` whose continuation is the loop on
the bytes after the instruction and whose stop is the identity: the loop's own
recursion equation. *What it assumes:* nothing; it holds by unfolding. *Why it
matters:* it is the only place the trace and the semantics meet. -/
theorem loop_stepK (exec : OpExec) (env : Env) (op : Nat) (rest : Bytes) (st : State) :
    loop exec env (op :: rest) st = stepK exec env op rest st (fun st' k => loop exec env (rest.drop k) st') id := by
  rw [loop.eq_2]
  rfl

/-- `stepK` commutes with any function applied to its result: the exits are the
only places a value leaves it. -/
theorem stepK_map {α β : Type} (g : α → β) (exec : OpExec) (env : Env) (op : Nat) (rest : Bytes) (st : State)
    (kont : State → Nat → α) (stop : Outcome × State → α) :
    g (stepK exec env op rest st kont stop)
      = stepK exec env op rest st (fun st' k => g (kont st' k)) (fun r => g (stop r)) := by
  unfold stepK
  cases getOpTail op rest with
  | none => rfl
  | some p =>
    obtain ⟨data, k⟩ := p
    simp only
    repeat' split
    all_goals rfl

/-- One recorded instruction. -/
structure Step where
  /-- the byte offset of the opcode in the script -/
  pc : Nat
  op : Nat
  /-- the push length (0 for a non-push opcode) -/
  dataLen : Nat
  /-- `fExec` at the instruction (`459`) -/
  exec : Bool
  /-- `cont` · `done` · `fail <SCRIPT_ERR_*>` · `unimplemented` -/
  result : String
  depth : Nat
  altDepth : Nat
  top : Option Bytes
  mem : Nat
  ops : Nat
  deriving Repr

def outcomeResult : Outcome → String
  | .ok => "done"
  | .err e => s!"fail {e.name}"
  | .unimplemented o => s!"unimplemented 0x{String.ofList (Nat.toDigits 16 o)}"
  | .undefinedInReference f => s!"undefined-in-reference ({f})"

def mkStep (pc op : Nat) (rest : Bytes) (before after : State) (result : String) : Step :=
  { pc, op,
    dataLen := match getOpTail op rest with | some (d, _) => d.length | none => 0,
    exec := before.cond.isActive && (!before.nonTopLevelReturn || op == Op.OP_RETURN),
    result, depth := after.stack.length, altDepth := after.alt.length, top := after.stack.head?,
    mem := after.memUsed, ops := after.opCount }

/-- `Machine.loop` with the trace accumulated: the same recursion, through `stepK`,
the continuation recording the step and the stop recording the last one. -/
def traceLoop (exec : OpExec) (env : Env) : (s : Bytes) → State → Nat → List Step → (Outcome × State) × List Step
  | [], st, _, acc => ((if st.cond.empty then (.ok, st) else (.err .unbalancedConditional, st)), acc.reverse)
  | op :: rest, st, pc, acc =>
    stepK exec env op rest st
      (fun st' k => traceLoop exec env (rest.drop k) st' (pc + 1 + k) (mkStep pc op rest st st' "cont" :: acc))
      (fun r => (r, (mkStep pc op rest st r.2 (outcomeResult r.1) :: acc).reverse))
termination_by s => s.length
decreasing_by all_goals simp [List.length_drop]

/-- **The traced run is the loop.** *What it says:* for every script, state,
offset and accumulator, the first component of `traceLoop` is `Machine.loop`.
*What it assumes:* nothing. *Why it matters:* the trace's outcome per phase is
the list machine's `Machine.loop` outcome, not a third reading of the script. It
is a second run beside the CLI's verdict, which comes from `verifyScriptI` (the
array machine, `verifyScript_eq_I`), not from the trace. The steps are the states
the run records inside `stepK`'s continuation (`loop_stepK` at every instruction),
by construction: no theorem states the list of steps (B-10; #32's final lens on
Lean B, NEW-7). -/
theorem traceLoop_fst (exec : OpExec) (env : Env) (s : Bytes) (st : State) (pc : Nat) (acc : List Step) :
    (traceLoop exec env s st pc acc).1 = loop exec env s st := by
  match s with
  | [] => rw [traceLoop.eq_1, loop.eq_1]
  | op :: rest =>
    rw [traceLoop.eq_2, loop_stepK, stepK_map Prod.fst]
    congr 1
    funext st' k
    exact traceLoop_fst exec env (rest.drop k) st' (pc + 1 + k) (mkStep pc op rest st st' "cont" :: acc)
termination_by s.length
decreasing_by all_goals simp [List.length_drop]

/-- `Machine.evalScript` traced: the script-size check (`429–430`) then the traced loop. -/
def traceEvalScript (exec : OpExec) (env : Env) (script : Bytes) (stack : List Bytes) (memUsed : Nat) :
    (Outcome × State) × List Step :=
  let st : State := { stack := stack, memUsed := memUsed, codeSep := script }
  if script.length > env.params.limits.maxScriptSize then ((.err .scriptSize, st), [])
  else traceLoop exec env script st 0 []

/-- **The traced phase is `evalScript`.** *What it says:* for every script, stack and
memory counter, the first component of `traceEvalScript` is `Machine.evalScript`.
*What it assumes:* nothing. *Why it matters:* the script-size check (`429–430`) and
the loop are the semantics' own, so each phase `traceVerifyScript` prints has the
list machine's outcome and final state for that phase (`traceLoop_fst` below the
size check). -/
theorem traceEvalScript_fst (exec : OpExec) (env : Env) (script : Bytes) (stack : List Bytes) (memUsed : Nat) :
    (traceEvalScript exec env script stack memUsed).1 = evalScript exec env script stack memUsed := by
  unfold traceEvalScript evalScript
  split
  · rfl
  · exact traceLoop_fst _ _ _ _ _ _

/-- The trace of one phase: its name, the steps, the outcome, the final stack. -/
structure PhaseTrace where
  phase : String
  steps : List Step
  outcome : String
  stack : List Bytes
  alt : List Bytes
  memUsed : Nat
  deriving Repr

def phaseTrace (name : String) (r : (Outcome × State) × List Step) : PhaseTrace :=
  { phase := name, steps := r.2, outcome := outcomeResult r.1.1, stack := r.1.2.stack, alt := r.1.2.alt, memUsed := r.1.2.memUsed }

/-- The phases `VerifyScript` runs (`2338–2424`), each traced with the same
environment and inputs the semantics gives it (`Machine.verifyScript`,
`Machine.phase2`): the unlocking script; the locking script on the stack it left;
for P2SH (a pre-Genesis UTXO under the flag, `2380–2424`) the serialized script
on the copied stack. The verdict is not computed here (the CLI takes it from
`Eval.verifyScript`, compiled since #50 as `verifyScriptI`, the array machine); this traces the
same spend through the list machine (`Machine.execStep` with the hook), a second run on a second
machine, each phase's result proven equal to the loop's (lean #32's second lens, A-10, and its
re-lens). -/
def traceVerifyScript (exec : OpExec) (params : EvalParams) (ctx : Context) (scriptSig scriptPubKey : Bytes) :
    List PhaseTrace :=
  if !params.flags.valid then []
  else
    let flags0 := params.flags.forkAdjust
    let flags := flags0.gate ctx.version
    let pushOnlyRequired :=
      flags.sigPushOnly &&
        ((flags.genesis && !flags.chronicle) || (flags.chronicle && !isMalleableTxnVersion ctx.version))
    if pushOnlyRequired && !isPushOnly scriptSig then []
    else
      let r1 := traceEvalScript exec (mkEnv params ctx flags0 (some scriptPubKey)) scriptSig [] 0
      let t1 := phaseTrace "scriptSig" r1
      match r1.1.1 with
      | .ok =>
        let st1 := r1.1.2
        let r2 := traceEvalScript exec (mkEnv params ctx flags0 none) scriptPubKey st1.stack st1.memUsed
        let t2 := phaseTrace "scriptPubKey" r2
        match r2.1.1 with
        | .ok =>
          let st2 := r2.1.2
          let topTrue := match st2.stack with | [] => false | t :: _ => castToBool t
          if flags0.p2shCopy && isP2SH scriptPubKey && isPushOnly scriptSig && topTrue then
            match st1.stack with
            | pubKey2 :: copyRest =>
              let mem' := st1.memUsed - (pubKey2.length + elementOverhead)
              let r3 := traceEvalScript exec (mkEnv params ctx flags0 none) pubKey2 copyRest mem'
              [t1, t2, phaseTrace "p2sh" r3]
            | [] => [t1, t2]
          else [t1, t2]
        | _ => [t1, t2]
      | _ => [t1]

/-- The opcode's name, through the generated table: the reference's stream operator's spelling
(`opcodes.cpp:8–72`) except in three places: a bare push, which the operator prints as its decimal
length (`opcodes.cpp:10–13`) and this as `PUSH<n>`; `OP_1NEGATE`, which the operator prints as `-1`
through its default branch and `GetOpName` (`opcodes.cpp:69–70`, `opcodes.cpp:88–89`) and this as
`OP_1NEGATE`; and every byte from `0xba`, where the generated table stops (`core_read.cpp:23`),
which the operator prints as `OP_UNKNOWN` (`opcodes.cpp:326–327`), or as `OP_INVALIDOPCODE` for
`0xff` (`opcodes.cpp:317–318`), and this as `0x<hex>`. `GetOpName` alone (`opcodes.cpp:75`) prints
`"0"`, `OP_UNKNOWN` for a bare push (it has no case for one, `opcodes.cpp:326–327`) and `"1"` to
`"16"`, where this prints `OP_0`, `PUSH<n>` and `OP_1`…`OP_16` (lean #32's second lens, B-15, and
its re-lenses; the file on every line, since the spec reads a bare number as `interpreter.cpp`'s,
its fourth re-lens, A4N-1). -/
def opName (op : Nat) : String :=
  if op = 0 then "OP_0"
  else if op < Op.OP_PUSHDATA1 then s!"PUSH{op}"
  else match BsvScript.Test.opNames.find? (fun (n, v) => v == op && n.startsWith "OP_") with
    | some (n, _) => n
    | none =>
      match BsvScript.Test.opNames.find? (fun (_, v) => v == op) with
      | some (n, _) => if n = "-1" then "OP_1NEGATE" else s!"OP_{n}"
      | none => s!"0x{String.ofList (Nat.toDigits 16 op)}"

end Bsvs.Trace
