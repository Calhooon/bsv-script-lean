import BsvScript.Impl.State
import BsvScript.Ops.Expansion
/-!
# BsvScript.Impl.Expansion: the expansion family over the implementation state (lean #50, slice (c))

`Ops.Expansion`'s `OP_SUBSTR`, `OP_LEFT`, `OP_RIGHT`, `OP_LSHIFTNUM` and `OP_RSHIFTNUM` (`interpreter.cpp:609–764`)
restated over `Impl.IState`: the operand reads and the byte and number logic are the spec's own
(`readInt64Operand`, `Ops.Arith.readOperand`, `encode`) read through `Impl.Elem`'s operations (#143: the substrings
copied as packed bytes), and only the stack is reached through `State.lean`'s helpers. Each `…I_abs` theorem proves
the restated function answers what the spec's answers on every state it stands for (#50's design, its comment
5884618665).
-/

set_option autoImplicit false

namespace BsvScript.Impl
open BsvScript.Params BsvScript.Numbers BsvScript.Machine BsvScript.Ops.Expansion IState

namespace Expansion

/-- `Ops.Expansion.nopOrDiscourage` over the implementation state. -/
def nopOrDiscourageI (env : Env) (s : IState) : HookRI :=
  if env.params.flags.discourageUpgradableNops then .fail .discourageUpgradableNops else .ok s

/-- **`nopOrDiscourageI_abs`.** *What it says:* the implementation's pre-Chronicle rule answers as the
spec's. *What it assumes:* nothing. *Why it matters:* the family on the implementation (#50). -/
theorem nopOrDiscourageI_abs (env : Env) (s : IState) :
    (nopOrDiscourageI env s).abs = nopOrDiscourage env s.abs := by
  unfold nopOrDiscourageI nopOrDiscourage
  split <;> rfl

/-- **`pushEncode_abs`.** *What it says:* pushing a number's encoding, read as the spec's, is pushing its packed
encoding. *What it assumes:* nothing. *Why it matters:* `OP_LSHIFTNUM`, `OP_RSHIFTNUM`, whose range test reads the
same encoding, computed once (#143). -/
theorem pushEncode_abs (env : Env) (t : IState) (v : Int) :
    pushElem env t.abs (encode v) = IState.abs <$> pushElemI env t (Elem.ofBytes (encode v)) := by
  rw [← pushElem_abs, Elem.toBytes_ofBytes _ (encode_valid v)]

/-- `Ops.Expansion.substr` over the implementation state (`609–640`). -/
def substrI (env : Env) (s : IState) : HookRI :=
  if s.stack.size < 3 then .fail .invalidStackOperation
  else
    match Elem.readInt64Operand env (topAtI s 0) with
    | .error e => .fail e

    | .ok len =>
      match Elem.readInt64Operand env (topAtI s 1) with
      | .error e => .fail e

      | .ok offset =>
        let data := topAtI s 2
        let size : Int := data.size
        if offset < 0 || size ≤ offset || len < 0 || size - offset < len then .fail .invalidNumberRange
        else
          (do
            let p ← popElemI s
            let q ← popElemI p.2
            let r ← popElemI q.2
            pushElemI env r.2 (Elem.take (Elem.drop data offset.toNat) len.toNat) : Except ScriptError IState)

/-- **`substrI_abs`.** *What it says:* the implementation's `OP_SUBSTR` answers what `Ops.Expansion.substr`
answers on the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the
implementation (#50). -/
theorem substrI_abs (env : Env) (s : IState) : (substrI env s).abs = substr env s.abs := by
  unfold substrI substr
  simp only [length_abs, topAt_abs, ← Elem.readInt64Operand_eq, Elem.length_toBytes]
  split
  · rfl
  · rcases Elem.readInt64Operand env (topAtI s 0) with e | len
    · rfl
    · simp only []
      rcases Elem.readInt64Operand env (topAtI s 1) with e | offset
      · rfl
      · simp only []
        split
        · rfl
        · simp only [HookRI.abs_ofExcept, popElem_abs, ← Elem.toBytes_take, ← Elem.toBytes_drop, pushElem_abs,
          map_bind, bind_map_left]

/-- `Ops.Expansion.left` over the implementation state (`642–666`). -/
def leftI (env : Env) (s : IState) : HookRI :=
  if s.stack.size < 2 then .fail .invalidStackOperation
  else
    match Elem.readInt64Operand env (topAtI s 0) with
    | .error e => .fail e

    | .ok len =>
      let data := topAtI s 1
      if len < 0 || (data.size : Int) < len then .fail .invalidNumberRange
      else
        (do
          let p ← popElemI s
          let q ← popElemI p.2
          pushElemI env q.2 (Elem.take data len.toNat) : Except ScriptError IState)

/-- **`leftI_abs`.** *What it says:* the implementation's `OP_LEFT` answers what `Ops.Expansion.left` answers
on the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the implementation
(#50). -/
theorem leftI_abs (env : Env) (s : IState) : (leftI env s).abs = left env s.abs := by
  unfold leftI left
  simp only [length_abs, topAt_abs, ← Elem.readInt64Operand_eq, Elem.length_toBytes]
  split
  · rfl
  · rcases Elem.readInt64Operand env (topAtI s 0) with e | len
    · rfl
    · simp only []
      split
      · rfl
      · simp only [HookRI.abs_ofExcept, popElem_abs, ← Elem.toBytes_take, pushElem_abs, map_bind, bind_map_left]

/-- `Ops.Expansion.right` over the implementation state (`667–691`). -/
def rightI (env : Env) (s : IState) : HookRI :=
  if s.stack.size < 2 then .fail .invalidStackOperation
  else
    match Elem.readInt64Operand env (topAtI s 0) with
    | .error e => .fail e

    | .ok len =>
      let data := topAtI s 1
      if len < 0 || (data.size : Int) < len then .fail .invalidNumberRange
      else
        (do
          let p ← popElemI s
          let q ← popElemI p.2
          pushElemI env q.2 (Elem.drop data (data.size - len.toNat)) : Except ScriptError IState)

/-- **`rightI_abs`.** *What it says:* the implementation's `OP_RIGHT` answers what `Ops.Expansion.right`
answers on the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the
implementation (#50). -/
theorem rightI_abs (env : Env) (s : IState) : (rightI env s).abs = right env s.abs := by
  unfold rightI right
  simp only [length_abs, topAt_abs, ← Elem.readInt64Operand_eq, Elem.length_toBytes]
  split
  · rfl
  · rcases Elem.readInt64Operand env (topAtI s 0) with e | len
    · rfl
    · simp only []
      split
      · rfl
      · simp only [HookRI.abs_ofExcept, popElem_abs, ← Elem.toBytes_drop, pushElem_abs, map_bind, bind_map_left]

/-- `Ops.Expansion.lshiftnum` over the implementation state (`692–727`). -/
def lshiftnumI (env : Env) (s : IState) : HookRI :=
  if s.stack.size < 2 then .fail .invalidStackOperation
  else
    match Elem.readOperand env (topAtI s 0) with
    | .error e => .fail e
    | .ok n =>
      if n < 0 then .fail .invalidNumberRange
      else
        match Elem.readOperand env (topAtI s 1) with
        | .error e => .fail e
        | .ok v =>
          let maxLen := env.params.limits.maxScriptNumLength
          if maxLen < (encode v).length + n.toNat / 8 then .fail .scriptnumOverflow
          else if INT_MAX < n then .fail .bigInt
          else
            let r := v * 2 ^ n.toNat
            if maxLen < (encode r).length then .fail .scriptnumOverflow
            else
              (do
                let p ← popElemI s
                let q ← popElemI p.2
                pushElemI env q.2 (Elem.ofBytes (encode r)) : Except ScriptError IState)

/-- **`lshiftnumI_abs`.** *What it says:* the implementation's `OP_LSHIFTNUM` answers what
`Ops.Expansion.lshiftnum` answers on the state it stands for. *What it assumes:* nothing. *Why it matters:*
the family on the implementation (#50). -/
theorem lshiftnumI_abs (env : Env) (s : IState) : (lshiftnumI env s).abs = lshiftnum env s.abs := by
  unfold lshiftnumI lshiftnum
  simp only [length_abs, topAt_abs, ← Elem.readOperand_eq]
  split
  · rfl
  · rcases Elem.readOperand env (topAtI s 0) with e | n
    · rfl
    · simp only []
      split
      · rfl
      · rcases Elem.readOperand env (topAtI s 1) with e | v
        · rfl
        · simp only []
          split
          · rfl
          · split
            · rfl
            · split
              · rfl
              · simp only [HookRI.abs_ofExcept, popElem_abs, pushEncode_abs, map_bind, bind_map_left]

/-- `Ops.Expansion.rshiftnum` over the implementation state (`728–764`). -/
def rshiftnumI (env : Env) (s : IState) : HookRI :=
  if s.stack.size < 2 then .fail .invalidStackOperation
  else
    match Elem.readOperand env (topAtI s 0) with
    | .error e => .fail e
    | .ok n =>
      if n < 0 then .fail .invalidNumberRange
      else
        match Elem.readOperand env (topAtI s 1) with
        | .error e => .fail e
        | .ok v =>
          if INT_MAX < n then .fail .bigInt
          else
            let r := if (8 * (encode v).length : Int) ≤ n then 0 else Int.tdiv v (2 ^ n.toNat)
            (do
              let p ← popElemI s
              let q ← popElemI p.2
              pushElemI env q.2 (Elem.ofBytes (encode r)) : Except ScriptError IState)

/-- **`rshiftnumI_abs`.** *What it says:* the implementation's `OP_RSHIFTNUM` answers what
`Ops.Expansion.rshiftnum` answers on the state it stands for. *What it assumes:* nothing. *Why it matters:*
the family on the implementation (#50). -/
theorem rshiftnumI_abs (env : Env) (s : IState) : (rshiftnumI env s).abs = rshiftnum env s.abs := by
  unfold rshiftnumI rshiftnum
  simp only [length_abs, topAt_abs, ← Elem.readOperand_eq]
  split
  · rfl
  · rcases Elem.readOperand env (topAtI s 0) with e | n
    · rfl
    · simp only []
      split
      · rfl
      · rcases Elem.readOperand env (topAtI s 1) with e | v
        · rfl
        · simp only []
          split
          · rfl
          · simp only [HookRI.abs_ofExcept, popElem_abs, pushEncode_abs, map_bind, bind_map_left]

/-- `Ops.Expansion.exec` over the implementation state: `0xb3`–`0xb7`, the pre-Chronicle NOP rule first. -/
def execI : OpExecI := fun op _ env s =>
  if Op.OP_SUBSTR ≤ op && op ≤ Op.OP_RSHIFTNUM then
    some (if !env.utxoAfterChronicle then nopOrDiscourageI env s
          else if op = Op.OP_SUBSTR then substrI env s
          else if op = Op.OP_LEFT then leftI env s
          else if op = Op.OP_RIGHT then rightI env s
          else if op = Op.OP_LSHIFTNUM then lshiftnumI env s
          else rshiftnumI env s)
  else none

/-- **`Expansion.execI_refines`.** *What it says:* the implementation's expansion hook refines
`Ops.Expansion.exec`. *What it assumes:* nothing. *Why it matters:* the family's part of the machine's
refinement (#50). -/
theorem execI_refines : Refines Ops.Expansion.exec execI := by
  intro op data env s
  unfold execI Ops.Expansion.exec
  split
  · simp only [Option.map_some, apply_ite HookRI.abs, nopOrDiscourageI_abs, substrI_abs, leftI_abs, rightI_abs,
      lshiftnumI_abs, rshiftnumI_abs]
  · rfl

/-- The opcodes the family's hook answers for: `execI`'s tests, which read the opcode alone. The machine's
dispatcher asks this first, so the state goes to one family only and its array stays unshared (#50). -/
def owns (op : Nat) : Bool :=
  Op.OP_SUBSTR ≤ op && op ≤ Op.OP_RSHIFTNUM

/-- **`Expansion.execI_of_not_owns`.** *What it says:* the hook answers `none` for an opcode it does not own. *What
it assumes:* `owns op = false`. *Why it matters:* the machine's dispatcher (#50). -/
theorem execI_of_not_owns (op : Nat) (data : Bytes) (env : Env) (s : IState) (h : owns op = false) :
    execI op data env s = none := by
  unfold execI
  unfold owns at h
  simp_all

/-- **`Expansion.isSome_execI`.** *What it says:* the hook answers for every opcode it owns. *What it assumes:*
`owns op = true`. *Why it matters:* the machine's dispatcher (#50). -/
theorem isSome_execI (op : Nat) (data : Bytes) (env : Env) (s : IState) (h : owns op = true) :
    (execI op data env s).isSome = true := by
  unfold execI
  unfold owns at h
  split_ifs <;> simp_all

end Expansion

end BsvScript.Impl
