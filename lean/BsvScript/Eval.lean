import BsvScript.Machine
import BsvScript.Ops.Arith
import BsvScript.Ops.Bitwise
import BsvScript.Ops.Stack
import BsvScript.Ops.Splice
import BsvScript.Ops.Crypto
import BsvScript.Ops.Expansion
import BsvScript.Impl.Machine
import BsvScript.Impl.Arith
import BsvScript.Impl.Bitwise
import BsvScript.Impl.Stack
import BsvScript.Impl.Splice
import BsvScript.Impl.Crypto
import BsvScript.Impl.Expansion
/-!
# BsvScript.Eval

The evaluator: the machine with every family hook assembled (`docs/DESIGN.md`
§5.4, `eval : EvalParams → Context → ScriptSig → ScriptPubKey → Verdict`). At #8
no family was written yet, the hook empty and every non-flow opcode
`unimplemented`; #9, #10, #11 and #18 added theirs here, and `opExec` now
assembles all six (`Properties.Coverage`).

**The compiled evaluator (#50).** `verifyScript` below is the semantics and does not move. The compiler runs
`verifyScriptI` in its place (`@[csimp] verifyScript_eq_I`, at the end of this file): the same machine over an
array-backed stack (`BsvScript.Impl`), where the element `k` below the top is one index and the depth one read,
proven to give `verifyScript`'s verdict on every spend (`Impl.verifyScriptA_eq`, with `opExecI_refines`).
-/

namespace BsvScript.Eval
open BsvScript.Params BsvScript.Machine BsvScript.Numbers

/-- The family hooks, tried in order; `none` = no family owns the opcode. -/
def opExec : OpExec := fun op data env st =>
  Ops.Arith.exec op data env st <|> Ops.Bitwise.exec op data env st
    <|> Ops.Stack.exec op data env st <|> Ops.Splice.exec op data env st
    <|> Ops.Crypto.exec op data env st <|> Ops.Expansion.exec op data env st

/-- The spec's evaluator. -/
def verifyScript (params : EvalParams) (ctx : Context) (scriptSig scriptPubKey : Bytes) : Verdict :=
  Machine.verifyScript opExec params ctx scriptSig scriptPubKey

/-- **Determinism** (`docs/DESIGN.md` §9): the verdict is a function of its
inputs; two evaluations of the same spend under the same parameters agree. A
definitional fact, stated as the issue's done-bar asks. -/
theorem verifyScript_deterministic (params : EvalParams) (ctx : Context) (scriptSig scriptPubKey : Bytes)
    (v₁ v₂ : Verdict) (h₁ : verifyScript params ctx scriptSig scriptPubKey = v₁)
    (h₂ : verifyScript params ctx scriptSig scriptPubKey = v₂) : v₁ = v₂ := by
  rw [← h₁, ← h₂]

/-! ## The compiled evaluator (#50) -/

/-- `opExec` over the implementation state: the family that owns the opcode answers, and it alone receives the
state (`Impl.<family>.owns`), so the stack's array is updated in place; the families' order is `opExec`'s. -/
def opExecI : Impl.OpExecI := fun op data env s =>
  if Impl.Arith.owns op then Impl.Arith.execI op data env s
  else if Impl.Bitwise.owns op then Impl.Bitwise.execI op data env s
  else if Impl.Stack.owns op then Impl.Stack.execI op data env s
  else if Impl.Splice.owns op then Impl.Splice.execI op data env s
  else if Impl.Crypto.owns op then Impl.Crypto.execI op data env s
  else Impl.Expansion.execI op data env s

/-- **`opExecI_refines`.** *What it says:* the implementation's hook refines `opExec`: on every opcode, push
data, environment and state it answers what `opExec` answers on the spec state it stands for. *What it
assumes:* nothing. *Why it matters:* the one hypothesis of the machine's refinement (`Impl.verifyScriptA_eq`)
(#50). -/
theorem opExecI_refines : Impl.Refines opExec opExecI := by
  intro op data env s
  unfold opExecI opExec
  rw [← Impl.Arith.execI_refines op data env s, ← Impl.Bitwise.execI_refines op data env s,
    ← Impl.Stack.execI_refines op data env s, ← Impl.Splice.execI_refines op data env s,
    ← Impl.Crypto.execI_refines op data env s, ← Impl.Expansion.execI_refines op data env s]
  refine Impl.dispatch_abs _ _ _ _ (Impl.Arith.execI_of_not_owns op data env s)
    (Impl.Arith.isSome_execI op data env s) ?_
  refine Impl.dispatch_abs _ _ _ _ (Impl.Bitwise.execI_of_not_owns op data env s)
    (Impl.Bitwise.isSome_execI op data env s) ?_
  refine Impl.dispatch_abs _ _ _ _ (Impl.Stack.execI_of_not_owns op data env s)
    (Impl.Stack.isSome_execI op data env s) ?_
  refine Impl.dispatch_abs _ _ _ _ (Impl.Splice.execI_of_not_owns op data env s)
    (Impl.Splice.isSome_execI op data env s) ?_
  refine Impl.dispatch_abs _ _ _ _ (Impl.Crypto.execI_of_not_owns op data env s)
    (Impl.Crypto.isSome_execI op data env s) ?_
  rfl

/-- The evaluator on the implementation machine (#50). -/
def verifyScriptI (params : EvalParams) (ctx : Context) (scriptSig scriptPubKey : Bytes) : Verdict :=
  Impl.verifyScriptA opExec opExecI params ctx scriptSig scriptPubKey

/-- **`verifyScript_eq_I`.** *What it says:* the evaluator on the array-backed machine is the spec's evaluator,
as functions. *What it assumes:* nothing. *Why it matters:* `@[csimp]`: every compiled call of
`verifyScript` after this module runs `verifyScriptI` (the CLI's `eval` and `corpus`, `lean/Bsvs/Run.lean`; the
flow leg's corpus run, its kernel sample and its array-machine large-lock row; the list-machine row calls
`Machine.verifyScript` directly), where `OP_PICK`/`OP_ROLL` index the stack instead of walking it; nothing in the
semantics moves, and every theorem about `verifyScript` is about the definition (#50). -/
@[csimp] theorem verifyScript_eq_I : @verifyScript = @verifyScriptI := by
  funext params ctx scriptSig scriptPubKey
  exact (Impl.verifyScriptA_eq opExec opExecI opExecI_refines params ctx scriptSig scriptPubKey).symm

end BsvScript.Eval
