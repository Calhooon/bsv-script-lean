import BsvScript.Impl.State
import BsvScript.Ops.Bitwise
/-!
# BsvScript.Impl.Bitwise: the bitwise family over the implementation state (lean #50, slice (c))

`Ops.Bitwise`'s `OP_AND`/`OP_OR`/`OP_XOR` (`interpreter.cpp:1069–1106`), `OP_INVERT` (`1108–1119`),
`OP_LSHIFT`/`OP_RSHIFT` (`1121–1187`) and `OP_EQUAL`/`OP_EQUALVERIFY` (`1189–1217`) restated over
`Impl.IState`: the byte logic is the spec's own (`List.zipWith`, `rshift`, `lshift`) read through `Impl.Elem`'s
operations (#143: `OP_EQUAL` compares the packed arrays), and only the stack is reached through `State.lean`'s
helpers. Each `…I_abs` theorem proves the restated function computes what the
spec's computes on every state it stands for (#50's design, its comment 5884618665).
-/

set_option autoImplicit false

namespace BsvScript.Impl
open BsvScript.Params BsvScript.Numbers BsvScript.Machine BsvScript.Ops.Bitwise IState

namespace Bitwise

/-- `Ops.Bitwise.bitwise2` over the implementation state (`1069–1106`). -/
def bitwise2I (env : Env) (op : Nat) (s : IState) : Except ScriptError IState := do
  if s.stack.size < 2 then throw .invalidStackOperation                        -- 1073–1074
  let p ← popElemI s
  let q ← popElemI p.2
  if q.1.size ≠ p.1.size then throw .invalidOperandSize
  let f : Nat → Nat → Nat :=
    if op = Op.OP_AND then (· &&& ·) else if op = Op.OP_OR then (· ||| ·) else (· ^^^ ·)
  pushElemI env q.2 (Elem.zipWith f q.1 p.1)

/-- **`bitwise2I_abs`.** *What it says:* the implementation's `OP_AND`/`OP_OR`/`OP_XOR` computes what
`Ops.Bitwise.bitwise2` computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the
family on the implementation (#50). -/
theorem bitwise2I_abs (env : Env) (op : Nat) (s : IState) :
    IState.abs <$> bitwise2I env op s = bitwise2 env op s.abs := by
  unfold bitwise2I bitwise2
  simp only [length_abs, popElem_abs, ← Elem.toBytes_zipWith _ (Elem.bitwise_byte op), pushElem_abs, map_bind,
    bind_map_left, apply_ite (Functor.map IState.abs), Elem.length_toBytes]

/-- `Ops.Bitwise.invert` over the implementation state (`1108–1119`). -/
def invertI (env : Env) (s : IState) : Except ScriptError IState := do
  if s.stack.size < 1 then throw .invalidStackOperation                        -- 1110–1111
  let p ← popElemI s
  pushElemI env p.2 (Elem.invert p.1)

/-- **`invertI_abs`.** *What it says:* the implementation's `OP_INVERT` computes what `Ops.Bitwise.invert`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the
implementation (#50). -/
theorem invertI_abs (env : Env) (s : IState) :
    IState.abs <$> invertI env s = invert env s.abs := by
  unfold invertI invert
  simp only [length_abs, popElem_abs, ← Elem.toBytes_invert, pushElem_abs, map_bind, bind_map_left,
    apply_ite (Functor.map IState.abs)]

/-- `Ops.Bitwise.shift` over the implementation state (`1121–1187`). -/
def shiftI (env : Env) (op : Nat) (s : IState) : Except ScriptError IState := do
  if s.stack.size < 2 then throw .invalidStackOperation                        -- 1124–1125
  let p ← popElemI s
  let q ← popElemI p.2
  let n ← Elem.readOperand env p.1
  if n < 0 then throw .invalidNumberRange
  let r :=
    if (q.1.size * 8 : Int) ≤ n then Elem.zeros q.1.size
    else if op = Op.OP_LSHIFT then Elem.lshift q.1 n.toNat else Elem.rshift q.1 n.toNat
  pushElemI env q.2 r

/-- **`shiftI_abs`.** *What it says:* the implementation's `OP_LSHIFT`/`OP_RSHIFT` computes what
`Ops.Bitwise.shift` computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the
family on the implementation (#50). -/
theorem shiftI_abs (env : Env) (op : Nat) (s : IState) :
    IState.abs <$> shiftI env op s = shift env op s.abs := by
  unfold shiftI shift
  simp only [length_abs, popElem_abs, Elem.length_toBytes, ← Elem.toBytes_zeros, ← Elem.toBytes_lshift,
    ← Elem.toBytes_rshift, ← apply_ite Elem.toBytes, pushElem_abs, map_bind, bind_map_left,
    apply_ite (Functor.map IState.abs), ← Elem.readOperand_eq]

/-- `Ops.Bitwise.equal` over the implementation state (`1189–1217`). -/
def equalI (env : Env) (op : Nat) (s : IState) : Except ScriptError IState := do
  if s.stack.size < 2 then throw .invalidStackOperation                        -- 1194–1195
  let p ← popElemI s
  let q ← popElemI p.2
  let eq := decide (q.1 = p.1)
  let s ← pushElemI env q.2 (if eq then Elem.vchTrue else Elem.empty)
  if op = Op.OP_EQUALVERIFY then
    if eq then
      let t ← popElemI s
      pure t.2
    else throw .equalverify
  else pure s

/-- **`equalI_abs`.** *What it says:* the implementation's `OP_EQUAL`/`OP_EQUALVERIFY` computes what
`Ops.Bitwise.equal` computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the
family on the implementation (#50). -/
theorem equalI_abs (env : Env) (op : Nat) (s : IState) :
    IState.abs <$> equalI env op s = equal env op s.abs := by
  unfold equalI equal
  simp only [length_abs, popElem_abs, Elem.decide_toBytes_eq, ← Elem.toBytes_vchTrue, ← Elem.toBytes_vchFalse,
    ← apply_ite Elem.toBytes, pushElem_abs, map_bind, bind_map_left, map_pure,
    apply_ite (Functor.map IState.abs)]
  impl_descend
  all_goals first | rfl | exact popTail_abs _

/-- `Ops.Bitwise.exec` over the implementation state. -/
def execI : OpExecI := fun op _ env s =>
  if op = Op.OP_AND || op = Op.OP_OR || op = Op.OP_XOR then some (bitwise2I env op s)
  else if op = Op.OP_INVERT then some (invertI env s)
  else if op = Op.OP_LSHIFT || op = Op.OP_RSHIFT then some (shiftI env op s)
  else if op = Op.OP_EQUAL || op = Op.OP_EQUALVERIFY then some (equalI env op s)
  else none

/-- **`Bitwise.execI_refines`.** *What it says:* the implementation's bitwise hook refines
`Ops.Bitwise.exec`. *What it assumes:* nothing. *Why it matters:* the family's part of the machine's
refinement (#50). -/
theorem execI_refines : Refines Ops.Bitwise.exec execI := by
  intro op data env s
  unfold execI Ops.Bitwise.exec
  split
  · simp only [Option.map_some, HookRI.abs_ofExcept, bitwise2I_abs]
  · split
    · simp only [Option.map_some, HookRI.abs_ofExcept, invertI_abs]
    · split
      · simp only [Option.map_some, HookRI.abs_ofExcept, shiftI_abs]
      · split
        · simp only [Option.map_some, HookRI.abs_ofExcept, equalI_abs]
        · rfl

/-- The opcodes the family's hook answers for: `execI`'s tests, which read the opcode alone. The machine's
dispatcher asks this first, so the state goes to one family only and its array stays unshared (#50). -/
def owns (op : Nat) : Bool :=
  (op = Op.OP_AND || op = Op.OP_OR || op = Op.OP_XOR) || op = Op.OP_INVERT ||
    (op = Op.OP_LSHIFT || op = Op.OP_RSHIFT) || (op = Op.OP_EQUAL || op = Op.OP_EQUALVERIFY)

/-- **`Bitwise.execI_of_not_owns`.** *What it says:* the hook answers `none` for an opcode it does not own. *What
it assumes:* `owns op = false`. *Why it matters:* the machine's dispatcher (#50). -/
theorem execI_of_not_owns (op : Nat) (data : Bytes) (env : Env) (s : IState) (h : owns op = false) :
    execI op data env s = none := by
  unfold execI
  unfold owns at h
  simp_all

/-- **`Bitwise.isSome_execI`.** *What it says:* the hook answers for every opcode it owns. *What it assumes:*
`owns op = true`. *Why it matters:* the machine's dispatcher (#50). -/
theorem isSome_execI (op : Nat) (data : Bytes) (env : Env) (s : IState) (h : owns op = true) :
    (execI op data env s).isSome = true := by
  unfold execI
  unfold owns at h
  split_ifs <;> simp_all

end Bitwise

end BsvScript.Impl
