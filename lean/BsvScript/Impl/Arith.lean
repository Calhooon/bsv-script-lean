import BsvScript.Impl.State
/-!
# BsvScript.Impl.Arith: the arithmetic family over the implementation state (lean #50, slice (c))

`Ops.Arith`'s unary family (`interpreter.cpp:1222–1275`), binary family (`1277–1378`) and `OP_WITHIN`
(`1380–1399`) restated over `Impl.IState`: the operand read, the values and the result write are the spec's own
functions (`readOperand`, `unaryValue`, `binaryValue`, `encode`) read through `Impl.Elem`'s (#143: an operand too
long to be a number is refused from its size), and only the stack is reached through `State.lean`'s helpers, so
the depth test is one read. Each `…I_abs` theorem proves the restated function
computes what the spec's computes on every state it stands for (#50's design, its comment 5884618665).
-/

set_option autoImplicit false

namespace BsvScript.Impl
open BsvScript.Params BsvScript.Numbers BsvScript.Machine BsvScript.Ops.Arith IState

namespace Arith

/-- `Ops.Arith.pushResult` over the implementation state (`1274`, `1369`). -/
def pushResultI (env : Env) (s : IState) (v : Int) (bounded : Bool) : Except ScriptError IState :=
  let bs := Elem.encode v
  if bounded && env.utxoAfterGenesis && env.params.limits.maxScriptNumLength < bs.size then
    .error .scriptnumOverflow
  else pushElemI env s bs

/-- **`pushResult_abs`.** *What it says:* the implementation's result write stands for the spec's. *What it
assumes:* nothing. *Why it matters:* every arithmetic result (#50). -/
theorem pushResult_abs (env : Env) (s : IState) (v : Int) (bounded : Bool) :
    pushResult env s.abs v bounded = IState.abs <$> pushResultI env s v bounded := by
  unfold pushResult pushResultI
  simp only [← Elem.length_toBytes, Elem.toBytes_encode]
  split
  · rfl
  · rw [← Elem.toBytes_encode, pushElem_abs]

/-- `Ops.Arith.pushBool` over the implementation state. -/
def pushBoolI (env : Env) (s : IState) (b : Bool) : Except ScriptError IState :=
  pushResultI env s (if b then 1 else 0) false

/-- **`pushBool_abs`.** *What it says:* the implementation's boolean write stands for the spec's. *What it
assumes:* nothing. *Why it matters:* `OP_WITHIN` (#50). -/
theorem pushBool_abs (env : Env) (s : IState) (b : Bool) :
    pushBool env s.abs b = IState.abs <$> pushBoolI env s b :=
  pushResult_abs env s _ false

/-- `Ops.Arith.unary` over the implementation state (`1222–1275`). -/
def unaryI (env : Env) (op : Nat) (s : IState) : Except ScriptError IState := do
  if s.stack.size < 1 then throw .invalidStackOperation                        -- 1231–1232
  let p ← popElemI s
  let v ← Elem.readOperand env p.1
  pushResultI env p.2 (unaryValue op v) (unaryBounded op)

/-- **`unaryI_abs`.** *What it says:* the implementation's unary family computes what `Ops.Arith.unary`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* `OP_1ADD` … `OP_0NOTEQUAL`
on the implementation (#50). -/
theorem unaryI_abs (env : Env) (op : Nat) (s : IState) :
    IState.abs <$> unaryI env op s = unary env op s.abs := by
  unfold unaryI unary
  simp only [length_abs, popElem_abs, pushResult_abs, map_bind, bind_map_left,
    apply_ite (Functor.map IState.abs), ← Elem.readOperand_eq]

/-- `Ops.Arith.binary` over the implementation state (`1277–1378`). -/
def binaryI (env : Env) (op : Nat) (s : IState) : Except ScriptError IState := do
  if s.stack.size < 2 then throw .invalidStackOperation                        -- 1294–1296
  let p ← popElemI s
  let q ← popElemI p.2
  let v1 ← Elem.readOperand env q.1
  let v2 ← Elem.readOperand env p.1
  let r ← binaryValue op v1 v2
  let s ← pushResultI env q.2 r (binaryBounded op)
  if op = Op.OP_NUMEQUALVERIFY then
    if Elem.castToBool (topAtI s 0) then
      let t ← popElemI s
      pure t.2
    else throw .numequalverify
  else pure s

/-- **`binaryI_abs`.** *What it says:* the implementation's binary family computes what `Ops.Arith.binary`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* `OP_ADD` … `OP_MAX` on the
implementation (#50). -/
theorem binaryI_abs (env : Env) (op : Nat) (s : IState) :
    IState.abs <$> binaryI env op s = binary env op s.abs := by
  unfold binaryI binary
  simp only [length_abs, popElem_abs, pushResult_abs, headD_abs, map_bind, bind_map_left, map_pure,
    apply_ite (Functor.map IState.abs), ← Elem.readOperand_eq, ← Elem.castToBool_eq]
  impl_descend
  all_goals first | rfl | exact popTail_abs _

/-- `Ops.Arith.within` over the implementation state (`1380–1399`). -/
def withinI (env : Env) (s : IState) : Except ScriptError IState := do
  if s.stack.size < 3 then throw .invalidStackOperation                        -- 1382–1383
  let p ← popElemI s
  let q ← popElemI p.2
  let r ← popElemI q.2
  let x ← Elem.readOperand env r.1
  let lo ← Elem.readOperand env q.1
  let hi ← Elem.readOperand env p.1
  pushBoolI env r.2 (lo ≤ x && x < hi)

/-- **`withinI_abs`.** *What it says:* the implementation's `OP_WITHIN` computes what `Ops.Arith.within`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* `OP_WITHIN` on the
implementation (#50). -/
theorem withinI_abs (env : Env) (s : IState) :
    IState.abs <$> withinI env s = within env s.abs := by
  unfold withinI within
  simp only [length_abs, popElem_abs, pushBool_abs, map_bind, bind_map_left,
    apply_ite (Functor.map IState.abs), ← Elem.readOperand_eq]

/-- `Ops.Arith.exec` over the implementation state. -/
def execI : OpExecI := fun op _ env s =>
  if isUnary op then some (unaryI env op s)
  else if isBinary op then some (binaryI env op s)
  else if op = Op.OP_WITHIN then some (withinI env s)
  else none

/-- **`Arith.execI_refines`.** *What it says:* the implementation's arithmetic hook refines
`Ops.Arith.exec`. *What it assumes:* nothing. *Why it matters:* the family's part of the machine's refinement
(#50). -/
theorem execI_refines : Refines Ops.Arith.exec execI := by
  intro op data env s
  unfold execI Ops.Arith.exec
  split
  · simp only [Option.map_some, HookRI.abs_ofExcept, unaryI_abs]
  · split
    · simp only [Option.map_some, HookRI.abs_ofExcept, binaryI_abs]
    · split
      · simp only [Option.map_some, HookRI.abs_ofExcept, withinI_abs]
      · rfl

/-- The opcodes the family's hook answers for: `execI`'s tests, which read the opcode alone. The machine's
dispatcher asks this first, so the state goes to one family only and its array stays unshared (#50). -/
def owns (op : Nat) : Bool :=
  isUnary op || isBinary op || op = Op.OP_WITHIN

/-- **`Arith.execI_of_not_owns`.** *What it says:* the hook answers `none` for an opcode it does not own. *What
it assumes:* `owns op = false`. *Why it matters:* the machine's dispatcher (#50). -/
theorem execI_of_not_owns (op : Nat) (data : Bytes) (env : Env) (s : IState) (h : owns op = false) :
    execI op data env s = none := by
  unfold execI
  unfold owns at h
  simp_all

/-- **`Arith.isSome_execI`.** *What it says:* the hook answers for every opcode it owns. *What it assumes:*
`owns op = true`. *Why it matters:* the machine's dispatcher (#50). -/
theorem isSome_execI (op : Nat) (data : Bytes) (env : Env) (s : IState) (h : owns op = true) :
    (execI op data env s).isSome = true := by
  unfold execI
  unfold owns at h
  split_ifs <;> simp_all

end Arith

end BsvScript.Impl
