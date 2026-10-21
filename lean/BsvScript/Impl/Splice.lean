import BsvScript.Impl.State
import BsvScript.Ops.Splice
/-!
# BsvScript.Impl.Splice: the splice family over the implementation state (lean #50, slice (c))

`Ops.Splice`'s `OP_CAT` (`interpreter.cpp:1687–1706`), `OP_SPLIT` (`1708–1736`), `OP_NUM2BIN` (`1741–1778`) and
`OP_BIN2NUM` (`1780–1792`) restated over `Impl.IState`: the byte and number logic is the spec's own (`num2bin`,
`minimallyEncode`, `isMinimallyEncoded`) read through `Impl.Elem`'s operations (#143: the concatenation and the
split copy packed bytes, `OP_NUM2BIN`'s pad is written in place, `Elem.num2binM`), and only the stack is reached
through `State.lean`'s helpers. Each `…I_abs` theorem proves the restated function computes what the spec's
computes on every state it stands for (#50's design, its comment 5884618665).
-/

set_option autoImplicit false

namespace BsvScript.Impl
open BsvScript.Params BsvScript.Numbers BsvScript.Machine BsvScript.Ops.Splice IState

namespace Splice

/-- `Ops.Splice.cat` over the implementation state (`1687–1706`). -/
def catI (env : Env) (s : IState) : Except ScriptError IState := do
  needI s 2
  let v1 := topAtI s 1
  let v2 := topAtI s 0
  if !env.utxoAfterGenesis && Consensus.maxScriptElementSizeBeforeGenesis < v1.size + v2.size then
    throw .pushSize
  let p ← popElemI s
  let q ← popElemI p.2
  pushElemI env q.2 (v1 ++ v2)

/-- **`catI_abs`.** *What it says:* the implementation's `OP_CAT` computes what `Ops.Splice.cat` computes on
the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the implementation
(#50). -/
theorem catI_abs (env : Env) (s : IState) : IState.abs <$> catI env s = cat env s.abs := by
  unfold catI cat
  simp only [need_abs, topAt_abs, popElem_abs, ← Elem.toBytes_append, pushElem_abs, map_bind, bind_map_left,
    apply_ite (Functor.map IState.abs), Elem.length_toBytes]

/-- `Ops.Splice.split` over the implementation state (`1708–1736`). -/
def splitI (env : Env) (s : IState) : Except ScriptError IState := do
  needI s 2
  let data := topAtI s 1
  let n ← Elem.readOperand env (topAtI s 0)
  if invalidSplitPosition data.size n then throw .invalidSplitRange
  let p ← popElemI s
  let q ← popElemI p.2
  let s ← pushElemI env q.2 (Elem.take data n.toNat)
  pushElemI env s (Elem.drop data n.toNat)

/-- **`splitI_abs`.** *What it says:* the implementation's `OP_SPLIT` computes what `Ops.Splice.split`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the
implementation (#50). -/
theorem splitI_abs (env : Env) (s : IState) : IState.abs <$> splitI env s = split env s.abs := by
  unfold splitI split
  simp only [need_abs, topAt_abs, popElem_abs, ← Elem.toBytes_take, ← Elem.toBytes_drop, pushElem_abs, map_bind,
    bind_map_left, apply_ite (Functor.map IState.abs), ← Elem.readOperand_eq, Elem.length_toBytes]

/-- `Ops.Splice.num2binOp` over the implementation state (`1741–1778`): the impossible encoding, then the memory
refusal of the padded width BEFORE `num2bin` builds it (#142; [SRC] v1.2.3 `6504a3af`, `limitedstack.cpp:60–71`,
`padRight` charging the growth at `:66` before `resize` at `:68`, the throw at `:202–204`), as the spec's; the pad
written in place into one packed array of the width (`Elem.num2binM`, #143). -/
def num2binOpI (env : Env) (s : IState) : Except ScriptError IState := do
  needI s 2
  let n ← Elem.readOperand env (topAtI s 0)
  if n < 0 || (2147483647 : Int) < n then throw .pushSize
  let width := n.toNat
  if !env.utxoAfterGenesis && Consensus.maxScriptElementSizeBeforeGenesis < width then throw .pushSize
  let p ← popElemI s
  let q ← popElemI p.2
  let m := minimallyEncode (Elem.toBytes q.1)
  if width < m.length then throw .impossibleEncoding
  if env.params.limits.maxStackMemoryUsage < q.2.memUsed + width + elementOverhead then throw .stackSize
  match Elem.num2binM m width with
  -- unreachable after the test above; kept so `num2bin` (`Elem.num2binM`) is used as T7 states it
  | none => throw .impossibleEncoding
  | some r => pushElemI env q.2 r

/-- **`optPush_abs`.** *What it says:* pushing an optional element, or failing, read as the spec's, is pushing the
optional list, or failing. *What it assumes:* nothing. *Why it matters:* `OP_NUM2BIN`'s last step over
`Elem.num2binM` (#143). -/
theorem optPush_abs (env : Env) (t : IState) (o : Option Elem) (e : ScriptError) :
    (IState.abs <$> match o with
      | none => throw e
      | some r => pushElemI env t r) =
      (match o.map Elem.toBytes with
        | none => throw e
        | some r => pushElem env t.abs r : Except ScriptError State) := by
  cases o with
  | none => rfl
  | some r => exact (pushElem_abs env t r).symm

/-- **`num2binOpI_abs`.** *What it says:* the implementation's `OP_NUM2BIN` computes what
`Ops.Splice.num2binOp` computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the
family on the implementation (#50). -/
theorem num2binOpI_abs (env : Env) (s : IState) : IState.abs <$> num2binOpI env s = num2binOp env s.abs := by
  unfold num2binOpI num2binOp
  simp only [need_abs, topAt_abs, popElem_abs, map_bind, bind_map_left, apply_ite (Functor.map IState.abs),
    ← Elem.readOperand_eq, ← Elem.num2binM_map]
  impl_descend
  all_goals first | rfl | exact optPush_abs env _ _ _

/-- **`pushMin_abs`.** *What it says:* pushing a minimal encoding, read as the spec's, is pushing it packed. *What
it assumes:* nothing. *Why it matters:* `OP_BIN2NUM`, whose range test reads the same list, computed once
(#143). -/
theorem pushMin_abs (env : Env) (t : IState) (bs : Bytes) :
    pushElem env t.abs (minimallyEncode bs) = IState.abs <$> pushElemI env t (Elem.ofBytes (minimallyEncode bs)) := by
  rw [← pushElem_abs, Elem.toBytes_ofBytes _ (show Bytes.valid (minimallyEncode bs) from encode_valid _)]

/-- `Ops.Splice.bin2num` over the implementation state (`1780–1792`). -/
def bin2numI (env : Env) (s : IState) : Except ScriptError IState := do
  needI s 1
  let p ← popElemI s
  let m := minimallyEncode (Elem.toBytes p.1)
  if !isMinimallyEncoded m env.params.limits.maxScriptNumLength then throw .invalidNumberRange
  pushElemI env p.2 (Elem.ofBytes m)

/-- **`bin2numI_abs`.** *What it says:* the implementation's `OP_BIN2NUM` computes what `Ops.Splice.bin2num`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the
implementation (#50). -/
theorem bin2numI_abs (env : Env) (s : IState) : IState.abs <$> bin2numI env s = bin2num env s.abs := by
  unfold bin2numI bin2num
  simp only [need_abs, popElem_abs, pushMin_abs, map_bind, bind_map_left, apply_ite (Functor.map IState.abs)]

/-- `Ops.Splice.exec` over the implementation state. -/
def execI : OpExecI := fun op _ env s =>
  if op = Op.OP_CAT then some (catI env s)
  else if op = Op.OP_SPLIT then some (splitI env s)
  else if op = Op.OP_NUM2BIN then some (num2binOpI env s)
  else if op = Op.OP_BIN2NUM then some (bin2numI env s)
  else none

/-- **`Splice.execI_refines`.** *What it says:* the implementation's splice hook refines `Ops.Splice.exec`.
*What it assumes:* nothing. *Why it matters:* the family's part of the machine's refinement (#50). -/
theorem execI_refines : Refines Ops.Splice.exec execI := by
  intro op data env s
  unfold execI Ops.Splice.exec
  split
  · simp only [Option.map_some, HookRI.abs_ofExcept, catI_abs]
  · split
    · simp only [Option.map_some, HookRI.abs_ofExcept, splitI_abs]
    · split
      · simp only [Option.map_some, HookRI.abs_ofExcept, num2binOpI_abs]
      · split
        · simp only [Option.map_some, HookRI.abs_ofExcept, bin2numI_abs]
        · rfl

/-- The opcodes the family's hook answers for: `execI`'s tests, which read the opcode alone. The machine's
dispatcher asks this first, so the state goes to one family only and its array stays unshared (#50). -/
def owns (op : Nat) : Bool :=
  op = Op.OP_CAT || op = Op.OP_SPLIT || op = Op.OP_NUM2BIN || op = Op.OP_BIN2NUM

/-- **`Splice.execI_of_not_owns`.** *What it says:* the hook answers `none` for an opcode it does not own. *What
it assumes:* `owns op = false`. *Why it matters:* the machine's dispatcher (#50). -/
theorem execI_of_not_owns (op : Nat) (data : Bytes) (env : Env) (s : IState) (h : owns op = false) :
    execI op data env s = none := by
  unfold execI
  unfold owns at h
  simp_all

/-- **`Splice.isSome_execI`.** *What it says:* the hook answers for every opcode it owns. *What it assumes:*
`owns op = true`. *Why it matters:* the machine's dispatcher (#50). -/
theorem isSome_execI (op : Nat) (data : Bytes) (env : Env) (s : IState) (h : owns op = true) :
    (execI op data env s).isSome = true := by
  unfold execI
  unfold owns at h
  split_ifs <;> simp_all

end Splice

end BsvScript.Impl
