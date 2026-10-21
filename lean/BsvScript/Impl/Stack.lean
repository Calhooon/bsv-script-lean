import BsvScript.Impl.State
/-!
# BsvScript.Impl.Stack: the stack family over the implementation state (lean #50, slice (b))

`Ops.Stack.execStack` (`interpreter.cpp:876–1064`) restated over `Impl.IState`, instruction for instruction, the
element logic shared and the stack reached through `State.lean`'s helpers, so the element `k` below the top is
one index and the depth one read: `OP_PICK`/`OP_ROLL` no longer walk the stack (#50's design, its comment
5884618665). `execStackI_abs` proves it computes what `execStack` computes on every state it stands for.
-/

set_option autoImplicit false

namespace BsvScript.Impl
open BsvScript.Params BsvScript.Numbers BsvScript.Machine BsvScript.Ops.Stack IState

/-! ## The family -/

/-- `Ops.Stack.execStack` over the implementation state (the same instructions, `876–1064`). -/
def execStackI (env : Env) (op : Nat) (s : IState) : Except ScriptError IState := do
  if op = Op.OP_TOALTSTACK then toAltI s
  else if op = Op.OP_FROMALTSTACK then fromAltI s
  else if op = Op.OP_2DROP then                                              -- 890–897
    needI s 2
    let p ← popElemI s
    let q ← popElemI p.2
    pure q.2
  else if op = Op.OP_2DUP then                                               -- 899–908
    needI s 2
    let s ← pushElemI env s (topAtI s 1)
    pushElemI env s (topAtI s 1)
  else if op = Op.OP_3DUP then                                               -- 910–921
    needI s 3
    let s ← pushElemI env s (topAtI s 2)
    let s ← pushElemI env s (topAtI s 2)
    pushElemI env s (topAtI s 2)
  else if op = Op.OP_2OVER then                                              -- 923–932
    needI s 4
    let s ← pushElemI env s (topAtI s 3)
    pushElemI env s (topAtI s 3)
  else if op = Op.OP_2ROT then                                               -- 934–944
    needI s 6
    pure (swapTopI (swapTopI (swapTopI (swapTopI s 0 2) 1 3) 0 4) 1 5)
  else if op = Op.OP_2SWAP then                                              -- 946–953
    needI s 4
    pure (swapTopI (swapTopI s 3 1) 2 0)
  else if op = Op.OP_IFDUP then                                              -- 955–964
    needI s 1
    if Elem.castToBool (topAtI s 0) then pushElemI env s (topAtI s 0) else pure s
  else if op = Op.OP_DEPTH then pushCountI env s s.stack.size               -- 966–970
  else if op = Op.OP_DROP then                                               -- 972–978
    needI s 1
    let p ← popElemI s
    pure p.2
  else if op = Op.OP_DUP then                                                -- 980–987
    needI s 1
    pushElemI env s (topAtI s 0)
  else if op = Op.OP_NIP then                                                -- 989–995
    needI s 2
    pure (eraseTopI s 1)
  else if op = Op.OP_OVER then                                               -- 997–1004
    needI s 2
    pushElemI env s (topAtI s 1)
  else if op = Op.OP_PICK || op = Op.OP_ROLL then                            -- 1006–1027
    needI s 2
    let p ← popElemI s
    let n ← Elem.readOperand env p.1
    if n < 0 || (p.2.stack.size : Int) ≤ n then throw .invalidStackOperation
    let k := n.toNat
    let x := topAtI p.2 k
    let s := if op = Op.OP_ROLL then eraseTopI p.2 k else p.2
    pushElemI env s x
  else if op = Op.OP_ROT then                                                -- 1029–1038
    needI s 3
    pure (swapTopI (swapTopI s 2 1) 1 0)
  else if op = Op.OP_SWAP then                                               -- 1040–1046
    needI s 2
    pure (swapTopI s 1 0)
  else if op = Op.OP_TUCK then                                               -- 1048–1055
    needI s 2
    insertTopI env s 2 (topAtI s 0)
  else                                                                       -- OP_SIZE, 1057–1064
    needI s 1
    pushCountI env s (topAtI s 0).size

/-- **`execStackI_abs`.** *What it says:* on every implementation state, the implementation's stack family
computes what `Ops.Stack.execStack` computes on the spec state it stands for: the same error, or a state that
stands for the spec's (the elements packed since #143). *What it assumes:* nothing. *Why it matters:*
`OP_PICK`/`OP_ROLL` in one index each, with the verdicts unmoved (#50, slice (b)). -/
theorem execStackI_abs (env : Env) (op : Nat) (s : IState) :
    IState.abs <$> execStackI env op s = execStack env op s.abs := by
  unfold execStackI execStack
  simp only [apply_ite (Functor.map IState.abs)]
  repeat' (apply ite_congr rfl <;> intro _)
  all_goals
    simp only [need_abs, topAt_abs, eraseTop_abs, ← apply_ite IState.abs, pushElem_abs, popElem_abs, swapTop_abs,
      insertTop_abs, pushCount_abs, toAlt_abs, fromAlt_abs, length_abs, map_bind, bind_map_left, map_pure,
      apply_ite (Functor.map IState.abs), ← Elem.readOperand_eq, ← Elem.castToBool_eq, Elem.length_toBytes]

namespace Stack

/-- `Ops.Stack.exec` over the implementation state: `OP_TOALTSTACK` `0x6b` … `OP_TUCK` `0x7d`, and `OP_SIZE`
`0x82`. -/
def execI : OpExecI := fun op _ env s =>
  if (Op.OP_TOALTSTACK ≤ op && op ≤ Op.OP_TUCK) || op = Op.OP_SIZE then some (execStackI env op s)
  else none

/-- **`Stack.execI_refines`.** *What it says:* the implementation's stack hook refines `Ops.Stack.exec`.
*What it assumes:* nothing. *Why it matters:* the family's part of the machine's refinement (#50). -/
theorem execI_refines : Refines Ops.Stack.exec execI := by
  intro op data env s
  unfold execI Ops.Stack.exec
  split
  · simp only [Option.map_some, HookRI.abs_ofExcept, execStackI_abs]
  · rfl

/-- The opcodes the family's hook answers for: `execI`'s tests, which read the opcode alone. The machine's
dispatcher asks this first, so the state goes to one family only and its array stays unshared (#50). -/
def owns (op : Nat) : Bool :=
  (Op.OP_TOALTSTACK ≤ op && op ≤ Op.OP_TUCK) || op = Op.OP_SIZE

/-- **`Stack.execI_of_not_owns`.** *What it says:* the hook answers `none` for an opcode it does not own. *What
it assumes:* `owns op = false`. *Why it matters:* the machine's dispatcher (#50). -/
theorem execI_of_not_owns (op : Nat) (data : Bytes) (env : Env) (s : IState) (h : owns op = false) :
    execI op data env s = none := by
  unfold execI
  unfold owns at h
  simp_all

/-- **`Stack.isSome_execI`.** *What it says:* the hook answers for every opcode it owns. *What it assumes:*
`owns op = true`. *Why it matters:* the machine's dispatcher (#50). -/
theorem isSome_execI (op : Nat) (data : Bytes) (env : Env) (s : IState) (h : owns op = true) :
    (execI op data env s).isSome = true := by
  unfold execI
  unfold owns at h
  simp [h]

end Stack

end BsvScript.Impl
