import BsvScript.Impl.State
/-!
# BsvScript.Impl.Machine: the loop and the two phases over the implementation state (lean #50, slice (e))

`Machine`'s flow opcodes (`interpreter.cpp:483–871`), its step (`473–482`, `1445–1448`), its loop (`EvalScript`,
`388–1833`) and its two-phase spend (`VerifyScript`, `2304–2451`) over `Impl.IState`, generic in the family hook as
`Machine` is. Each step says what the spec's step says (`execFlowI_eq`, `execStepI_eq`; read through `StepRI.view`
since #143, the elements packed), so the loop agrees with `Machine.loop` on the outcome always and on the state
when the outcome is `.ok` (`loopI_rel`): an in-place machine no longer holds a step's input once the step has run,
and `Machine.loop` returns that input with a failure (`(.err e, st)`), which no consumer reads (`evalScript`,
`phase2`, `verifyScript`). The two phases are written once, generic in the evaluator (`phase2Gen`,
`verifyScriptGen`), equal to `Machine.phase2` and `Machine.verifyScript` on `Machine.evalScript` by `rfl`, and
equal to each other on any two evaluators that agree on the outcome and on the state at `.ok`
(`verifyScriptGen_congr`) (#50's design, its comment 5884618665). Since #143 `verifyScriptA` runs them over a
`PhaseView` (`verifyScriptP`), the unlocking phase's packed array handed to the locking phase as it is.
-/

set_option autoImplicit false

namespace BsvScript.Impl
open BsvScript.Params BsvScript.Numbers BsvScript.Machine IState

/-! ## A step's result -/

/-- `Machine.StepR` over the implementation state; `.done` carries the state the step started from, which the
loop returns (`Machine.loop`'s `.done => (.ok, st)`). -/
inductive StepRI where
  | cont (s : IState)
  | done (s : IState)
  | fail (e : ScriptError)
  | unimpl (op : Nat)
  | undefined (family : String)

/-- What a step says, read as the spec's: the outcome, and the state carried at `.cont` and `.done` (#143: the
implementation's step and the spec's are compared by what they say, so the spec's states need no packed form). -/
inductive StepV where
  | cont (st : State)
  | done (st : State)
  | fail (e : ScriptError)
  | unimpl (op : Nat)
  | undefined (family : String)

/-- The implementation's step read as the spec's: each state through `abs`. -/
def StepRI.view : StepRI → StepV
  | .cont s => .cont s.abs
  | .done s => .done s.abs
  | .fail e => .fail e
  | .unimpl o => .unimpl o
  | .undefined f => .undefined f

/-- The spec's step taken from the state `st`, read the same way: `.done` carries `st`, as `Machine.loop`
returns it. -/
def stepView (st : State) : StepR → StepV
  | .cont st' => .cont st'
  | .done => .done st
  | .fail e => .fail e
  | .unimpl o => .unimpl o
  | .undefined f => .undefined f

/-! ## The leaves the step proofs close by `exact` against each definition's own `match` -/

/-- **`pushStep_eq`.** *What it says:* a push of an element read as a step on the implementation says what the
spec's push of its bytes says. *What it assumes:* nothing. *Why it matters:* the pushes of `execFlow` and
`execStep` (#50). -/
theorem pushStep_eq (env : Env) (s : IState) (x : Elem) :
    (match pushElemI env s x with
      | .ok s' => StepRI.cont s'
      | .error e => .fail e).view =
      stepView s.abs (match pushElem env s.abs (Elem.toBytes x) with
        | .ok st' => StepR.cont st'
        | .error e => .fail e) := by
  rw [← pushElemI_abs]
  cases pushElemI env s x <;> rfl

/-- **`pushStepB_eq`.** *What it says:* `pushStep_eq` for an element packed from a valid list. *What it assumes:*
`Bytes.valid bs`. *Why it matters:* the pushes of the script's data and of the small numbers (#143). -/
theorem pushStepB_eq (env : Env) (s : IState) (bs : Bytes) (h : Bytes.valid bs) :
    (match pushElemI env s (Elem.ofBytes bs) with
      | .ok s' => StepRI.cont s'
      | .error e => .fail e).view =
      stepView s.abs (match pushElem env s.abs bs with
        | .ok st' => StepR.cont st'
        | .error e => .fail e) := by
  have := pushStep_eq env s (Elem.ofBytes bs)
  rwa [Elem.toBytes_ofBytes bs h] at this

/-- **`verifyStep_eq`.** *What it says:* `OP_VERIFY` on the implementation says what the spec's says. *What it
assumes:* nothing. *Why it matters:* `execFlow`'s `842–854` (#50). -/
theorem verifyStep_eq (s : IState) :
    (match s.stack.back? with
      | none => StepRI.fail .invalidStackOperation
      | some x =>
        if Elem.castToBool x then
          .cont { s with stack := s.stack.pop, memUsed := s.memUsed - (x.size + elementOverhead) }
        else .fail .verify).view =
      stepView s.abs (match s.abs.stack with
        | [] => StepR.fail .invalidStackOperation
        | x :: xs =>
          if castToBool x then .cont { s.abs with stack := xs, memUsed := s.abs.memUsed - (x.length + elementOverhead) }
          else .fail .verify) := by
  cases h : s.stack.back? with
  | none => simp only [abs_stack_of_back_none s h]; rfl
  | some x =>
    simp only [abs_stack_of_back_some s x h, Elem.length_toBytes, ← Elem.castToBool_eq]
    split <;> rfl

/-- **`hookStep_eq`.** *What it says:* a family's answer read as a step on the implementation says what the
spec's family's answer says, when the implementation's hook refines the spec's. *What it assumes:*
`Refines exec execI`. *Why it matters:* `execFlow`'s default case (`1795`) (#50). -/
theorem hookStep_eq (exec : OpExec) (execI : OpExecI) (h : Refines exec execI) (op : Nat) (data : Bytes)
    (env : Env) (s : IState) :
    (match execI op data env s with
      | some (.ok s') => StepRI.cont s'
      | some (.fail e) => .fail e
      | some (.undefined f) => .undefined f
      | none => if Op.hasCase op then .unimpl op else .fail .badOpcode).view =
      stepView s.abs (match exec op data env s.abs with
        | some (.ok st') => StepR.cont st'
        | some (.fail e) => .fail e
        | some (.undefined f) => .undefined f
        | none => if Op.hasCase op then .unimpl op else .fail .badOpcode) := by
  rw [← h op data env s]
  cases execI op data env s with
  | none => simp only [Option.map_none]; split <;> rfl
  | some r =>
    cases r with
    | ok s' => rfl
    | fail e => rfl
    | undefined f => rfl

/-! ## The flow opcodes (`483–871`) -/

/-- `Machine.execIf` over the implementation state (`784–825`). -/
def execIfI (env : Env) (op : Nat) (fExec : Bool) (s : IState) : StepRI :=
  if fExec then
    match s.stack.back? with
    | none => .fail .unbalancedConditional
    | some vch =>
      let minimalIfViolation :=
        (op == Op.OP_IF || op == Op.OP_NOTIF) && env.params.flags.minimalIf &&
          (vch.size > 1 || (vch.size == 1 && Elem.head? vch != some 1))
      if minimalIfViolation && enforceNonMalleability env.params.flags env.ctx.version then .fail .minimalif
      else
        let v0 :=
          if op == Op.OP_VERIF || op == Op.OP_VERNOTIF then
            vch.size == 4 && Elem.toBytes vch == versionLE env.ctx.version
          else Elem.castToBool vch
        let v := if op == Op.OP_NOTIF || op == Op.OP_VERNOTIF then !v0 else v0
        let s' := { s with stack := s.stack.pop, memUsed := s.memUsed - (vch.size + elementOverhead) }
        .cont { s' with cond := s'.cond.opIf v }
  else .cont { s with cond := s.cond.opIf false }

/-- **`execIfI_eq`.** *What it says:* the implementation's `OP_IF` family says what the spec's says. *What it
assumes:* nothing. *Why it matters:* the conditionals on the implementation (#50). -/
theorem execIfI_eq (env : Env) (op : Nat) (fExec : Bool) (s : IState) :
    (execIfI env op fExec s).view = stepView s.abs (execIf env op fExec s.abs) := by
  unfold execIfI execIf
  split
  · cases h : s.stack.back? with
    | none => simp only [abs_stack_of_back_none s h]; rfl
    | some x =>
      simp only [abs_stack_of_back_some s x h, Elem.length_toBytes, Elem.head?_toBytes, ← Elem.castToBool_eq]
      split <;> rfl
  · rfl

/-- `Machine.execCltv` over the implementation state (`519–560`). -/
def execCltvI (env : Env) (s : IState) : StepRI :=
  if !env.params.flags.checkLockTimeVerify || env.utxoAfterGenesis then
    if env.params.flags.discourageUpgradableNops then .fail .discourageUpgradableNops else .cont s
  else
    match s.stack.back? with
    | none => .fail .invalidStackOperation
    | some top =>
      match Elem.readNum top env.requireMinimal 5 with
      | .error .overflow => .fail .scriptnumOverflow
      | .error .minencode => .fail .scriptnumMinencode
      | .ok n =>
        if n < 0 then .fail .negativeLocktime
        else if !env.ctx.checkLockTime n then .fail .unsatisfiedLocktime
        else .cont s

/-- **`execCltvI_eq`.** *What it says:* the implementation's `OP_CHECKLOCKTIMEVERIFY` says what the spec's says.
*What it assumes:* nothing. *Why it matters:* the lock-time check on the implementation (#50). -/
theorem execCltvI_eq (env : Env) (s : IState) : (execCltvI env s).view = stepView s.abs (execCltv env s.abs) := by
  unfold execCltvI execCltv
  split
  · split <;> rfl
  · cases h : s.stack.back? with
    | none => simp only [abs_stack_of_back_none s h]; rfl
    | some x =>
      simp only [abs_stack_of_back_some s x h, ← Elem.readNum_eq]
      cases hr : Elem.readNum x env.requireMinimal 5 with
      | error e => cases e <;> rfl
      | ok n =>
        simp only [apply_ite StepRI.view, apply_ite (stepView s.abs)]
        repeat' (apply ite_congr rfl <;> intro _)
        all_goals rfl

/-- `Machine.execCsv` over the implementation state (`562–597`). -/
def execCsvI (env : Env) (s : IState) : StepRI :=
  if !env.params.flags.checkSequenceVerify || env.utxoAfterGenesis then
    if env.params.flags.discourageUpgradableNops then .fail .discourageUpgradableNops else .cont s
  else
    match s.stack.back? with
    | none => .fail .invalidStackOperation
    | some top =>
      match Elem.readNum top env.requireMinimal 5 with
      | .error .overflow => .fail .scriptnumOverflow
      | .error .minencode => .fail .scriptnumMinencode
      | .ok n =>
        if n < 0 then .fail .negativeLocktime
        else if Nat.testBit n.toNat 31 then .cont s
        else if !env.ctx.checkSequence n then .fail .unsatisfiedLocktime
        else .cont s

/-- **`execCsvI_eq`.** *What it says:* the implementation's `OP_CHECKSEQUENCEVERIFY` says what the spec's says.
*What it assumes:* nothing. *Why it matters:* the sequence check on the implementation (#50). -/
theorem execCsvI_eq (env : Env) (s : IState) : (execCsvI env s).view = stepView s.abs (execCsv env s.abs) := by
  unfold execCsvI execCsv
  split
  · split <;> rfl
  · cases h : s.stack.back? with
    | none => simp only [abs_stack_of_back_none s h]; rfl
    | some x =>
      simp only [abs_stack_of_back_some s x h, ← Elem.readNum_eq]
      cases hr : Elem.readNum x env.requireMinimal 5 with
      | error e => cases e <;> rfl
      | ok n =>
        simp only [apply_ite StepRI.view, apply_ite (stepView s.abs)]
        repeat' (apply ite_congr rfl <;> intro _)
        all_goals rfl

/-- `Machine.execFlow` over the implementation state (`483–871`, the default case `1795`). -/
def execFlowI (execI : OpExecI) (env : Env) (op : Nat) (data : Bytes) (fExec : Bool) (s : IState) : StepRI :=
  if (op = Op.OP_1NEGATE) ∨ (Op.OP_1 ≤ op ∧ op ≤ Op.OP_16) then
    match pushElemI env s (Elem.encode ((op : Int) - ((Op.OP_1 - 1 : Nat) : Int))) with
    | .ok s' => .cont s'
    | .error e => .fail e
  else if op = Op.OP_NOP then .cont s                                           -- 516
  else if op = Op.OP_CHECKLOCKTIMEVERIFY then execCltvI env s                    -- 519–560
  else if op = Op.OP_CHECKSEQUENCEVERIFY then execCsvI env s                     -- 562–597
  else if op = Op.OP_VER then                                                    -- 598–608
    if !env.utxoAfterChronicle then .fail .badOpcode
    else
      match pushElemI env s (Elem.versionLE env.ctx.version) with
      | .ok s' => .cont s'
      | .error e => .fail e
  else if op = Op.OP_NOP1 ∨ op = Op.OP_NOP9 ∨ op = Op.OP_NOP10 then             -- 765–771
    if env.params.flags.discourageUpgradableNops then .fail .discourageUpgradableNops else .cont s
  else if op = Op.OP_VERIF ∨ op = Op.OP_VERNOTIF then                           -- 773–781
    if !env.utxoAfterChronicle then
      (if env.utxoAfterGenesis && !fExec then .cont s else .fail .badOpcode)
    else execIfI env op fExec s
  else if op = Op.OP_IF ∨ op = Op.OP_NOTIF then execIfI env op fExec s           -- 784–825
  else if op = Op.OP_ELSE then                                                   -- 827–833
    if s.cond.empty || (s.cond.hasOpElse && env.utxoAfterGenesis) then .fail .unbalancedConditional
    else .cont { s with cond := s.cond.opElse }
  else if op = Op.OP_ENDIF then                                                  -- 835–840
    if s.cond.empty then .fail .unbalancedConditional else .cont { s with cond := s.cond.opEndif }
  else if op = Op.OP_VERIFY then                                                 -- 842–854
    match s.stack.back? with
    | none => .fail .invalidStackOperation
    | some x =>
      if Elem.castToBool x then .cont { s with stack := s.stack.pop, memUsed := s.memUsed - (x.size + elementOverhead) }
      else .fail .verify
  else if op = Op.OP_RETURN then                                                 -- 856–871
    if env.utxoAfterGenesis then
      (if s.cond.empty then .done s else .cont { s with nonTopLevelReturn := true })
    else .fail .opReturn
  else
    match execI op data env s with
    | some (.ok s') => .cont s'
    | some (.fail e) => .fail e
    | some (.undefined f) => .undefined f
    | none => if Op.hasCase op then .unimpl op else .fail .badOpcode

/-- **`execFlowI_eq`.** *What it says:* the implementation's flow opcodes and default case say what the spec's
say, when the implementation's hook refines the spec's. *What it assumes:* `Refines exec execI`. *Why it
matters:* every executed opcode but the pushes and the separator (#50). -/
theorem execFlowI_eq (exec : OpExec) (execI : OpExecI) (h : Refines exec execI) (env : Env) (op : Nat)
    (data : Bytes) (fExec : Bool) (s : IState) :
    (execFlowI execI env op data fExec s).view = stepView s.abs (execFlow exec env op data fExec s.abs) := by
  unfold execFlowI execFlow
  simp only [apply_ite StepRI.view, apply_ite (stepView s.abs)]
  repeat' (apply ite_congr rfl <;> intro _)
  all_goals first
    | rfl
    | exact pushStepB_eq _ _ _ (encode_valid _)
    | exact pushStepB_eq _ _ _ (Elem.versionLE_valid _)
    | exact execIfI_eq _ _ _ _
    | exact execCltvI_eq _ _
    | exact execCsvI_eq _ _
    | exact verifyStep_eq _
    | exact hookStep_eq exec execI h _ _ _ _

/-! ## The step and the loop (`EvalScript`, `388–1833`) -/

/-- `Machine.execStep` over the implementation state (`473–482`, `1445–1448`): the push's data packed once
(#143). -/
def execStepI (execI : OpExecI) (env : Env) (op : Nat) (data : Bytes) (rest : Bytes) (k : Nat)
    (fExec : Bool) (s : IState) : StepRI :=
  if fExec && op ≤ Op.OP_PUSHDATA4 then
    if env.requireMinimal && !checkMinimalPush data op then .fail .minimaldata
    else
      match pushElemI env s (Elem.ofBytes data) with
      | .ok s' => .cont s'
      | .error e => .fail e
  else if fExec && op = Op.OP_CODESEPARATOR then .cont { s with codeSep := rest.drop k }
  else if fExec || (Op.OP_IF ≤ op && op ≤ Op.OP_ENDIF) then execFlowI execI env op data fExec s
  else .cont s

/-- **`execStepI_eq`.** *What it says:* the implementation's step says what the spec's step says, when the
implementation's hook refines the spec's and the push's data is bytes. *What it assumes:* `Refines exec execI`;
`Bytes.valid data`. *Why it matters:* the loop's refinement, one instruction at a time (#50). -/
theorem execStepI_eq (exec : OpExec) (execI : OpExecI) (h : Refines exec execI) (env : Env) (op : Nat)
    (data rest : Bytes) (k : Nat) (fExec : Bool) (s : IState) (hd : Bytes.valid data) :
    (execStepI execI env op data rest k fExec s).view =
      stepView s.abs (execStep exec env op data rest k fExec s.abs) := by
  unfold execStepI execStep
  simp only [apply_ite StepRI.view, apply_ite (stepView s.abs)]
  repeat' (apply ite_congr rfl <;> intro _)
  all_goals first
    | rfl
    | exact pushStepB_eq _ _ _ hd
    | exact execFlowI_eq exec execI h _ _ _ _ _

/-- **`getOpTail_valid`.** *What it says:* the data of a push read from a byte list is bytes. *What it assumes:*
`Bytes.valid rest`. *Why it matters:* the push's data is packed (#143). -/
theorem getOpTail_valid (op : Nat) (rest : Bytes) (hv : Bytes.valid rest) (data : Bytes) (k : Nat)
    (h : getOpTail op rest = some (data, k)) : Bytes.valid data := by
  rw [getOpTail_eq_fast] at h
  unfold getOpTailFast at h
  split at h
  · split at h
    · cases h
    · rename_i n p _
      split at h
      · cases h
      · rename_i d hd
        cases h
        rw [takeExact_eq] at hd
        split at hd
        · cases hd
        · cases hd
          intro b hb
          exact hv b (List.mem_of_mem_drop (List.mem_of_mem_take hb))
  · cases h
    exact valid_nil

/-- `Machine.loop` over the implementation state (`388–1833`). A failure returns the empty state, not the
step's input, which the step has consumed; no consumer reads a state that is not `.ok`'s. -/
def loopI (execI : OpExecI) (env : Env) : (script : Bytes) → IState → Outcome × IState
  | [], s => if s.cond.empty then (.ok, s) else (.err .unbalancedConditional, s)
  | op :: rest, s =>
    match getOpTail op rest with
    | none => (.err .badOpcode, s)
    | some (data, k) =>
      if !env.utxoAfterGenesis && data.length > Consensus.maxScriptElementSizeBeforeGenesis then (.err .pushSize, s)
      else
        let fExec := s.cond.isActive && (!s.nonTopLevelReturn || op == Op.OP_RETURN)
        let s := if op > Op.OP_16 then { s with opCount := s.opCount + 1 } else s
        if op > Op.OP_16 && s.opCount > env.params.limits.maxOpsPerScript then (.err .opCount, s)
        else if isOpcodeDisabled op env.utxoEra && (!env.utxoAfterGenesis || fExec) then (.err .disabledOpcode, s)
        else
          match execStepI execI env op data rest k fExec s with
          | .fail e => (.err e, {})
          | .unimpl o => (.unimplemented o, {})
          | .undefined f => (.undefinedInReference f, {})
          | .done s' => (.ok, s')
          | .cont s' =>
            if !env.utxoAfterGenesis && s'.stack.size + s'.alt.length > Consensus.maxStackElementsBeforeGenesis then
              (.err .stackSize, s')
            else loopI execI env (rest.drop k) s'
termination_by s => s.length
decreasing_by all_goals simp [List.length_drop]

/-- The implementation's result of a loop stands for the spec's: the same outcome, and at `.ok` the state the
spec's stands for. -/
def LoopRel (r : Outcome × IState) (r' : Outcome × State) : Prop :=
  r.1 = r'.1 ∧ (r.1 = .ok → r.2.abs = r'.2)

/-- **`LoopRel.of_err`.** *What it says:* two loop results that fail with the same error stand for each other,
whatever their states. *What it assumes:* nothing. *Why it matters:* the loop's failing exits (#50). -/
theorem LoopRel.of_err (e : ScriptError) (s : IState) (st : State) : LoopRel (.err e, s) (.err e, st) :=
  ⟨rfl, fun h => by cases h⟩

/-- **`LoopRel.of_ok`.** *What it says:* a successful result stands for the successful result on the state it
stands for. *What it assumes:* nothing. *Why it matters:* the loop's successful exits (#50). -/
theorem LoopRel.of_ok (s : IState) : LoopRel (.ok, s) (.ok, s.abs) := ⟨rfl, fun _ => rfl⟩

/-- **`ofState_alt`.** *What it says:* the implementation state made from a spec state has its alt stack, packed.
*What it assumes:* nothing. *Why it matters:* the pre-Genesis depth test after each step reads the alt stack's
length (#50; packed since #143). -/
theorem ofState_alt (st : State) : (ofState st).alt = st.alt.map Elem.ofBytes := rfl

/-- **`loopI_rel`.** *What it says:* the implementation's loop agrees with `Machine.loop` on the outcome, and at
`.ok` on the state, when the implementation's hook refines the spec's and the script is bytes. *What it assumes:*
`Refines exec execI`; `Bytes.valid script` (its pushes are packed, #143). *Why it matters:* the whole script on
the implementation (#50). -/
theorem loopI_rel (exec : OpExec) (execI : OpExecI) (h : Refines exec execI) (env : Env) :
    ∀ (script : Bytes) (s : IState), Bytes.valid script →
      LoopRel (loopI execI env script s) (loop exec env script s.abs)
  | [], s, _ => by
    rw [loopI, loop, abs_cond]
    split
    · exact LoopRel.of_ok s
    · exact LoopRel.of_err _ _ _
  | op :: rest, s, hv => by
    rw [loopI, loop]
    have hrest : Bytes.valid rest := ((valid_cons op rest).mp hv).2
    cases hg : getOpTail op rest with
    | none => exact LoopRel.of_err _ _ _
    | some p =>
      obtain ⟨data, k⟩ := p
      have hd : Bytes.valid data := getOpTail_valid op rest hrest data k hg
      have hdrop : Bytes.valid (rest.drop k) := fun b hb => hrest b (List.mem_of_mem_drop hb)
      simp only []
      split
      · exact LoopRel.of_err _ _ _
      · have hst : (if op > Op.OP_16 then ({ s.abs with opCount := s.abs.opCount + 1 } : State) else s.abs) =
            IState.abs (if op > Op.OP_16 then ({ s with opCount := s.opCount + 1 } : IState) else s) := by
          split <;> rfl
        have hfe : (s.abs.cond.isActive && (!s.abs.nonTopLevelReturn || op == Op.OP_RETURN)) =
            (s.cond.isActive && (!s.nonTopLevelReturn || op == Op.OP_RETURN)) := rfl
        rw [hst, hfe]
        generalize (if op > Op.OP_16 then ({ s with opCount := s.opCount + 1 } : IState) else s) = s1
        generalize (s.cond.isActive && (!s.nonTopLevelReturn || op == Op.OP_RETURN)) = fExec
        have hstep := execStepI_eq exec execI h env op data rest k fExec s1 hd
        rw [abs_opCount]
        split
        · exact LoopRel.of_err _ _ _
        · split
          · exact LoopRel.of_err _ _ _
          · generalize execStepI execI env op data rest k fExec s1 = r at hstep
            generalize execStep exec env op data rest k fExec s1.abs = r' at hstep
            cases r <;> cases r' <;> simp only [StepRI.view, stepView, StepV.cont.injEq, StepV.done.injEq,
              StepV.fail.injEq, StepV.unimpl.injEq, StepV.undefined.injEq, reduceCtorEq] at hstep
            · rename_i s' st'
              subst hstep
              simp only []
              rw [← length_abs, abs_alt, List.length_map]
              split
              · exact LoopRel.of_err _ _ _
              · exact loopI_rel exec execI h env (rest.drop k) s' hdrop
            · rename_i s'
              exact ⟨rfl, fun _ => hstep⟩
            · subst hstep; exact LoopRel.of_err _ _ _
            · subst hstep; exact ⟨rfl, fun h => by cases h⟩
            · subst hstep; exact ⟨rfl, fun h => by cases h⟩
termination_by script => script.length
decreasing_by all_goals simp [List.length_drop]

/-- `Machine.evalScript` over the implementation state (`388–1833`; the script size `429–430`). -/
def evalScriptI (execI : OpExecI) (env : Env) (script : Bytes) (stack : Array Elem) (memUsed : Nat) :
    Outcome × IState :=
  let s : IState := { stack := stack, memUsed := memUsed, codeSep := script }
  if script.length > env.params.limits.maxScriptSize then (.err .scriptSize, s)
  else loopI execI env script s

/-- **`evalScriptI_rel`.** *What it says:* the implementation's `EvalScript` agrees with `Machine.evalScript` on
the outcome, and at `.ok` on the state, when the implementation's hook refines the spec's and the script is bytes.
*What it assumes:* `Refines exec execI`; `Bytes.valid script`. *Why it matters:* each phase of a spend on the
implementation (#50). -/
theorem evalScriptI_rel (exec : OpExec) (execI : OpExecI) (h : Refines exec execI) (env : Env) (script : Bytes)
    (stack : Array Elem) (memUsed : Nat) (hv : Bytes.valid script) :
    LoopRel (evalScriptI execI env script stack memUsed)
      (evalScript exec env script (stack.toList.reverse.map Elem.toBytes) memUsed) := by
  unfold evalScriptI evalScript
  split
  · exact LoopRel.of_err _ _ _
  · exact loopI_rel exec execI h env script _ hv

/-- `Machine.evalScript` run on the implementation: the stack handed in packed, the result read back as the
spec's at `.ok` only (both conversions once per phase). A script or a stack element with a value at or above 256
has no packed form: that phase runs on the spec's own `Machine.evalScript` (#143). -/
def evalScriptA (exec : OpExec) (execI : OpExecI) (env : Env) (script : Bytes) (stack : List Bytes)
    (memUsed : Nat) : Outcome × State :=
  if Elem.validB script && stack.all Elem.validB then
    let r := evalScriptI execI env script (stack.reverse.map Elem.ofBytes).toArray memUsed
    match r.1 with
    | .ok => (.ok, r.2.abs)
    | o => (o, {})
  else evalScript exec env script stack memUsed

/-- Two evaluators' results agree where a consumer can tell: the same outcome, and at `.ok` the same state. -/
def EvRel (r r' : Outcome × State) : Prop :=
  r.1 = r'.1 ∧ (r.1 = .ok → r.2 = r'.2)

/-- **`evalScriptA_rel`.** *What it says:* `EvalScript` run on the implementation agrees with
`Machine.evalScript` on the outcome, and at `.ok` on the state. *What it assumes:* `Refines exec execI`.
*Why it matters:* the two phases on the implementation (#50). -/
theorem evalScriptA_rel (exec : OpExec) (execI : OpExecI) (h : Refines exec execI) (env : Env) (script : Bytes)
    (stack : List Bytes) (memUsed : Nat) :
    EvRel (evalScriptA exec execI env script stack memUsed) (evalScript exec env script stack memUsed) := by
  unfold evalScriptA
  split
  · rename_i hg
    rw [Bool.and_eq_true, Elem.validB_iff, List.all_eq_true] at hg
    obtain ⟨hv, hs⟩ := hg
    have hr := evalScriptI_rel exec execI h env script (stack.reverse.map Elem.ofBytes).toArray memUsed hv
    have hstack : ((stack.reverse.map Elem.ofBytes).toArray.toList.reverse.map Elem.toBytes) = stack := by
      rw [List.toList_toArray, ← List.map_reverse, List.reverse_reverse, List.map_map]
      conv_rhs => rw [← List.map_id stack]
      exact List.map_congr_left (fun x hx => Elem.toBytes_ofBytes x ((Elem.validB_iff x).mp (hs x hx)))
    rw [hstack] at hr
    obtain ⟨h1, h2⟩ := hr
    generalize evalScriptI execI env script (stack.reverse.map Elem.ofBytes).toArray memUsed = r at h1 h2
    obtain ⟨o, t⟩ := r
    simp only at h1 h2
    cases o with
    | ok => exact ⟨h1, fun _ => h2 rfl⟩
    | err e => exact ⟨h1, fun h => by cases h⟩
    | undefinedInReference f => exact ⟨h1, fun h => by cases h⟩
    | unimplemented o => exact ⟨h1, fun h => by cases h⟩
  · exact ⟨rfl, fun _ => rfl⟩

/-! ## The two phases (`VerifyScript`, `2304–2451`), written once over the evaluator -/

/-- `Machine.phase2` with the evaluator a parameter: the same text, `ev` in place of `evalScript exec`. -/
def phase2Gen (ev : Env → Bytes → List Bytes → Nat → Outcome × State) (params : EvalParams) (ctx : Context)
    (flags0 : Flags) (scriptSig scriptPubKey : Bytes) (stack : List Bytes) (memUsed : Nat) : Verdict :=
  let flags := flags0.gate ctx.version
  let stackCopy : Option (List Bytes × Nat) :=
    if flags0.p2shCopy then some (stack, memUsed) else none
  match ev (mkEnv params ctx flags0 none) scriptPubKey stack memUsed with
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
                        match ev (mkEnv params ctx flags0 none) pubKey2 copyRest mem' with
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

/-- **`phase2_eq_gen`.** *What it says:* `Machine.phase2` is `phase2Gen` on `Machine.evalScript`. *What it
assumes:* nothing. *Why it matters:* the implementation's phases are the spec's text (#50). -/
theorem phase2_eq_gen (exec : OpExec) (params : EvalParams) (ctx : Context) (flags0 : Flags)
    (scriptSig scriptPubKey : Bytes) (stack : List Bytes) (memUsed : Nat) :
    phase2 exec params ctx flags0 scriptSig scriptPubKey stack memUsed =
      phase2Gen (evalScript exec) params ctx flags0 scriptSig scriptPubKey stack memUsed := rfl

/-- **`phase2Gen_congr`.** *What it says:* `phase2Gen` gives the same verdict on two evaluators that agree on
every outcome and on every state at `.ok`. *What it assumes:* the evaluators agree so. *Why it matters:* the
verdict reads a phase's state only at `.ok` (#50). -/
theorem phase2Gen_congr (ev1 ev2 : Env → Bytes → List Bytes → Nat → Outcome × State)
    (hev : ∀ env script stack mem, EvRel (ev1 env script stack mem) (ev2 env script stack mem))
    (params : EvalParams) (ctx : Context) (flags0 : Flags) (scriptSig scriptPubKey : Bytes) (stack : List Bytes)
    (memUsed : Nat) :
    phase2Gen ev1 params ctx flags0 scriptSig scriptPubKey stack memUsed =
      phase2Gen ev2 params ctx flags0 scriptSig scriptPubKey stack memUsed := by
  unfold phase2Gen
  obtain ⟨h1, h2⟩ := hev (mkEnv params ctx flags0 none) scriptPubKey stack memUsed
  generalize ev1 (mkEnv params ctx flags0 none) scriptPubKey stack memUsed = r1 at h1 h2 ⊢
  generalize ev2 (mkEnv params ctx flags0 none) scriptPubKey stack memUsed = r2 at h1 h2 ⊢
  obtain ⟨o1, t1⟩ := r1
  obtain ⟨o2, t2⟩ := r2
  simp only at h1 h2
  subst h1
  cases o1 with
  | err e => rfl
  | unimplemented o => rfl
  | undefinedInReference f => rfl
  | ok =>
    obtain rfl := h2 rfl
    simp only []
    cases t1.stack with
    | nil => rfl
    | cons top tail =>
      simp only []
      split
      · rfl
      · cases flags0.p2shCopy with
        | false => rfl
        | true =>
          simp only [↓reduceIte]
          by_cases hP : isP2SH scriptPubKey = true
          · by_cases hQ : (!isPushOnly scriptSig) = true
            · simp only [hP, hQ, ↓reduceIte]
            · simp only [hP, hQ, Bool.false_eq_true, ↓reduceIte]
              cases stack with
              | nil => rfl
              | cons pubKey2 copyRest =>
                simp only []
                obtain ⟨g1, g2⟩ :=
                  hev (mkEnv params ctx flags0 none) pubKey2 copyRest (memUsed - (pubKey2.length + elementOverhead))
                generalize ev1 (mkEnv params ctx flags0 none) pubKey2 copyRest
                  (memUsed - (pubKey2.length + elementOverhead)) = q1 at g1 g2 ⊢
                generalize ev2 (mkEnv params ctx flags0 none) pubKey2 copyRest
                  (memUsed - (pubKey2.length + elementOverhead)) = q2 at g1 g2 ⊢
                obtain ⟨p1, u1⟩ := q1
                obtain ⟨p2, u2⟩ := q2
                simp only at g1 g2
                subst g1
                cases p1 <;> first | rfl | (obtain rfl := g2 rfl; rfl)
          · simp only [hP, Bool.false_eq_true, ↓reduceIte]

/-- `Machine.verifyScript` with the evaluator a parameter: the same text, `ev` in place of `evalScript exec` and
`phase2Gen ev` in place of `phase2 exec`. -/
def verifyScriptGen (ev : Env → Bytes → List Bytes → Nat → Outcome × State) (params : EvalParams) (ctx : Context)
    (scriptSig scriptPubKey : Bytes) : Verdict :=
  if !params.flags.valid then .invalid .invalidFlags
  else
    let flags0 := params.flags.forkAdjust
    let flags := flags0.gate ctx.version
    let pushOnlyRequired :=
      flags.sigPushOnly &&
        ((flags.genesis && !flags.chronicle) || (flags.chronicle && !isMalleableTxnVersion ctx.version))
    if pushOnlyRequired && !isPushOnly scriptSig then .invalid .sigPushonly
    else
      match ev (mkEnv params ctx flags0 (some scriptPubKey)) scriptSig [] 0 with
      | (.err e, _) => .invalid e
      | (.unimplemented o, _) => .unimplemented o
      | (.undefinedInReference f, _) => .undefinedInReference f
      | (.ok, st1) => phase2Gen ev params ctx flags0 scriptSig scriptPubKey st1.stack st1.memUsed

/-- **`verifyScript_eq_gen`.** *What it says:* `Machine.verifyScript` is `verifyScriptGen` on
`Machine.evalScript`. *What it assumes:* nothing. *Why it matters:* the implementation's verifier is the spec's
text (#50). -/
theorem verifyScript_eq_gen (exec : OpExec) (params : EvalParams) (ctx : Context) (scriptSig scriptPubKey : Bytes) :
    verifyScript exec params ctx scriptSig scriptPubKey =
      verifyScriptGen (evalScript exec) params ctx scriptSig scriptPubKey := rfl

/-- **`verifyScriptGen_congr`.** *What it says:* `verifyScriptGen` gives the same verdict on two evaluators that
agree on every outcome and on every state at `.ok`. *What it assumes:* the evaluators agree so. *Why it
matters:* the verdict reads the unlocking phase's state only at `.ok` (#50). -/
theorem verifyScriptGen_congr (ev1 ev2 : Env → Bytes → List Bytes → Nat → Outcome × State)
    (hev : ∀ env script stack mem, EvRel (ev1 env script stack mem) (ev2 env script stack mem))
    (params : EvalParams) (ctx : Context) (scriptSig scriptPubKey : Bytes) :
    verifyScriptGen ev1 params ctx scriptSig scriptPubKey = verifyScriptGen ev2 params ctx scriptSig scriptPubKey := by
  unfold verifyScriptGen
  split
  · rfl
  · simp only []
    split
    · rfl
    · obtain ⟨h1, h2⟩ := hev (mkEnv params ctx params.flags.forkAdjust (some scriptPubKey)) scriptSig [] 0
      generalize ev1 (mkEnv params ctx params.flags.forkAdjust (some scriptPubKey)) scriptSig [] 0 = r1 at h1 h2 ⊢
      generalize ev2 (mkEnv params ctx params.flags.forkAdjust (some scriptPubKey)) scriptSig [] 0 = r2 at h1 h2 ⊢
      obtain ⟨o1, t1⟩ := r1
      obtain ⟨o2, t2⟩ := r2
      simp only at h1 h2
      subst h1
      cases o1 <;> first | rfl | (obtain rfl := h2 rfl; exact phase2Gen_congr ev1 ev2 hev _ _ _ _ _ _ _)

/-! ## The two phases over a packed hand-off (#143)

`phase2Gen` and `verifyScriptGen` hand the unlocking phase's stack to the locking phase as the spec's `List Bytes`;
on the implementation that reads every element into a list and packs every list again (`evalScriptA`), the seed
corpus's extra 9 % [M] (#143's record). `phase2P` and `verifyScriptP` are the same text over a stack type `σ` and a
state type `S`, read through a `PhaseView`. On the spec's view they are `phase2Gen` and `verifyScriptGen`
(`phase2P_spec`, `verifyScriptP_spec`); on two views whose stacks agree element by element they give the same verdict
(`phase2P_congr`, `verifyScriptP_congr`); so the implementation hands its packed array on as it is (`verifyScriptA`). -/

/-- What the two phases read: a phase's stack and memory counter, a stack's top (its bytes and the rest), its depth,
and the empty stack. -/
structure PhaseView (σ S : Type) where
  stack : S → σ
  memUsed : S → Nat
  top? : σ → Option (Bytes × σ)
  length : σ → Nat
  nil : σ

/-- `phase2Gen`'s P2SH step over a `PhaseView` (`2389–2424`): the verdict so far and the depth of the stack the
clean-stack test reads. -/
def afterP2shP {σ S : Type} (V : PhaseView σ S) (ev : Env → Bytes → σ → Nat → Outcome × S)
    (params : EvalParams) (ctx : Context) (flags0 : Flags) (scriptSig scriptPubKey : Bytes)
    (stackCopy : Option (σ × Nat)) (st2 : S) :
    Verdict × Nat :=
  match stackCopy with
  | some (copy, mem) =>
    if isP2SH scriptPubKey then
      if !isPushOnly scriptSig then (.invalid .sigPushonly, V.length (V.stack st2))
      else
        match V.top? copy with
        | none => (.invalid .evalFalse, V.length (V.stack st2))
        | some (pubKey2, copyRest) =>
          match ev (mkEnv params ctx flags0 none) pubKey2 copyRest (mem - (pubKey2.length + elementOverhead)) with
          | (.err e, s) => (.invalid e, V.length (V.stack s))
          | (.unimplemented o, s) => (.unimplemented o, V.length (V.stack s))
          | (.undefinedInReference f, s) => (.undefinedInReference f, V.length (V.stack s))
          | (.ok, st3) =>
            match V.top? (V.stack st3) with
            | none => (.invalid .evalFalse, V.length (V.stack st3))
            | some (t3, _) =>
              if !castToBool t3 then (.invalid .evalFalse, V.length (V.stack st3))
              else (.valid, V.length (V.stack st3))
    else (.valid, V.length (V.stack st2))
  | none => (.valid, V.length (V.stack st2))

/-- `phase2Gen`'s last step (`2426–2450`): the clean-stack tests on a valid verdict. -/
def finishP (flags0 : Flags) (ctx : Context) : Verdict × Nat → Verdict
  | (.valid, depth) =>
    if flags0.cleanStackDemand then .invalid .invalidFlags
    else if (flags0.gate ctx.version).cleanStack && depth != 1 then .invalid .cleanstack
    else .valid
  | (v, _) => v

/-- `phase2Gen` over a `PhaseView`: the same text, its P2SH step and its last step named. -/
def phase2P {σ S : Type} (V : PhaseView σ S) (ev : Env → Bytes → σ → Nat → Outcome × S)
    (params : EvalParams) (ctx : Context) (flags0 : Flags) (scriptSig scriptPubKey : Bytes) (stack : σ)
    (memUsed : Nat) : Verdict :=
  let stackCopy : Option (σ × Nat) := if flags0.p2shCopy then some (stack, memUsed) else none
  match ev (mkEnv params ctx flags0 none) scriptPubKey stack memUsed with
  | (.err e, _) => .invalid e
  | (.unimplemented o, _) => .unimplemented o
  | (.undefinedInReference f, _) => .undefinedInReference f
  | (.ok, st2) =>
    match V.top? (V.stack st2) with
    | none => .invalid .evalFalse
    | some (top, _) =>
      if !castToBool top then .invalid .evalFalse
      else finishP flags0 ctx (afterP2shP V ev params ctx flags0 scriptSig scriptPubKey stackCopy st2)

/-- `verifyScriptGen` over a `PhaseView`: the same text, the unlocking phase started on `V.nil`. -/
def verifyScriptP {σ S : Type} (V : PhaseView σ S) (ev : Env → Bytes → σ → Nat → Outcome × S) (params : EvalParams)
    (ctx : Context) (scriptSig scriptPubKey : Bytes) : Verdict :=
  if !params.flags.valid then .invalid .invalidFlags
  else
    let flags0 := params.flags.forkAdjust
    let flags := flags0.gate ctx.version
    let pushOnlyRequired :=
      flags.sigPushOnly &&
        ((flags.genesis && !flags.chronicle) || (flags.chronicle && !isMalleableTxnVersion ctx.version))
    if pushOnlyRequired && !isPushOnly scriptSig then .invalid .sigPushonly
    else
      match ev (mkEnv params ctx flags0 (some scriptPubKey)) scriptSig V.nil 0 with
      | (.err e, _) => .invalid e
      | (.unimplemented o, _) => .unimplemented o
      | (.undefinedInReference f, _) => .undefinedInReference f
      | (.ok, st1) => phase2P V ev params ctx flags0 scriptSig scriptPubKey (V.stack st1) (V.memUsed st1)

/-- The spec's view: the list stack, its head. -/
def specView : PhaseView (List Bytes) State :=
  { stack := State.stack, memUsed := State.memUsed,
    top? := fun l => match l with
      | [] => none
      | x :: xs => some (x, xs),
    length := List.length, nil := [] }

/-- **`phase2P_spec`.** *What it says:* `phase2P` on the spec's view is `phase2Gen`. *What it assumes:* nothing.
*Why it matters:* the packed hand-off's phases are the spec's text (#143). -/
theorem phase2P_spec (ev : Env → Bytes → List Bytes → Nat → Outcome × State) (params : EvalParams) (ctx : Context)
    (flags0 : Flags) (scriptSig scriptPubKey : Bytes) (stack : List Bytes) (memUsed : Nat) :
    phase2P specView ev params ctx flags0 scriptSig scriptPubKey stack memUsed =
      phase2Gen ev params ctx flags0 scriptSig scriptPubKey stack memUsed := by
  unfold phase2P phase2Gen finishP afterP2shP
  generalize ev (mkEnv params ctx flags0 none) scriptPubKey stack memUsed = r
  obtain ⟨o, st2⟩ := r
  cases o with
  | err e => rfl
  | unimplemented o => rfl
  | undefinedInReference f => rfl
  | ok =>
    simp only [specView]
    cases hs : st2.stack with
    | nil => rfl
    | cons top tail =>
      simp only []
      cases hc : castToBool top
      · rfl
      · cases hp : flags0.p2shCopy
        · simp only [Bool.not_true, Bool.false_eq_true, ↓reduceIte, hs]
        · cases hP : isP2SH scriptPubKey
          · simp only [Bool.not_true, Bool.false_eq_true, ↓reduceIte, hs]
          · cases hQ : isPushOnly scriptSig
            · simp only [Bool.not_true, Bool.not_false, Bool.false_eq_true, ↓reduceIte]
            · cases stack with
              | nil => simp only [Bool.not_true, Bool.false_eq_true, ↓reduceIte]
              | cons pubKey2 copyRest =>
                simp only [Bool.not_true, Bool.false_eq_true, ↓reduceIte]
                generalize ev (mkEnv params ctx flags0 none) pubKey2 copyRest
                  (memUsed - (pubKey2.length + elementOverhead)) = q
                obtain ⟨p, u⟩ := q
                cases p with
                | err e => rfl
                | unimplemented o => rfl
                | undefinedInReference f => rfl
                | ok =>
                  cases hu : u.stack with
                  | nil => simp only [hu]
                  | cons t3 _ =>
                    simp only []
                    cases hc3 : castToBool t3 <;>
                      simp only [hc3, hu, Bool.not_true, Bool.not_false, Bool.false_eq_true, ↓reduceIte]

/-- **`verifyScriptP_spec`.** *What it says:* `verifyScriptP` on the spec's view is `verifyScriptGen`. *What it
assumes:* nothing. *Why it matters:* the packed hand-off's verifier is the spec's text (#143). -/
theorem verifyScriptP_spec (ev : Env → Bytes → List Bytes → Nat → Outcome × State) (params : EvalParams)
    (ctx : Context) (scriptSig scriptPubKey : Bytes) :
    verifyScriptP specView ev params ctx scriptSig scriptPubKey =
      verifyScriptGen ev params ctx scriptSig scriptPubKey := by
  unfold verifyScriptP verifyScriptGen
  split
  · rfl
  · simp only []
    split
    · rfl
    · have hn : (specView.nil : List Bytes) = [] := rfl
      rw [hn]
      generalize ev (mkEnv params ctx params.flags.forkAdjust (some scriptPubKey)) scriptSig [] 0 = r
      obtain ⟨o, st1⟩ := r
      cases o
      · exact phase2P_spec ev params ctx _ scriptSig scriptPubKey _ _
      all_goals rfl

/-- Two stacks' tops agree: both empty, or the same bytes, which are bytes, over two rests that agree. -/
def TopRel {σ₁ σ₂ : Type} (R : σ₁ → σ₂ → Prop) : Option (Bytes × σ₁) → Option (Bytes × σ₂) → Prop
  | none, none => True
  | some (b, x), some (b', y) => b = b' ∧ Bytes.valid b ∧ R x y
  | _, _ => False

/-- **`TopRel.cases`.** *What it says:* two agreeing tops are both empty, or the same valid bytes over agreeing
rests. *What it assumes:* `TopRel R o₁ o₂`. *Why it matters:* the congruence proofs case on it (#143). -/
theorem TopRel.cases {σ₁ σ₂ : Type} {R : σ₁ → σ₂ → Prop} {o₁ : Option (Bytes × σ₁)} {o₂ : Option (Bytes × σ₂)}
    (h : TopRel R o₁ o₂) :
    (o₁ = none ∧ o₂ = none) ∨ ∃ b x y, o₁ = some (b, x) ∧ o₂ = some (b, y) ∧ Bytes.valid b ∧ R x y := by
  rcases o₁ with _ | ⟨b, x⟩ <;> rcases o₂ with _ | ⟨b', y⟩ <;> simp only [TopRel] at h
  · exact Or.inl ⟨rfl, rfl⟩
  · obtain ⟨rfl, hv, hr⟩ := h
    exact Or.inr ⟨b, x, y, rfl, rfl, hv, hr⟩

/-- Two views agree: related states have related stacks and the same counter, related stacks have agreeing tops
and the same depth, the empty stacks are related, and the two evaluators, on a byte script and related stacks, give
the same outcome and related states at `.ok`. -/
structure ViewRel {σ₁ S₁ σ₂ S₂ : Type} (V₁ : PhaseView σ₁ S₁) (V₂ : PhaseView σ₂ S₂)
    (ev₁ : Env → Bytes → σ₁ → Nat → Outcome × S₁) (ev₂ : Env → Bytes → σ₂ → Nat → Outcome × S₂) where
  R : σ₁ → σ₂ → Prop
  RS : S₁ → S₂ → Prop
  stack : ∀ s t, RS s t → R (V₁.stack s) (V₂.stack t)
  memUsed : ∀ s t, RS s t → V₁.memUsed s = V₂.memUsed t
  top : ∀ x y, R x y → TopRel R (V₁.top? x) (V₂.top? y)
  length : ∀ x y, R x y → V₁.length x = V₂.length y
  nil : R V₁.nil V₂.nil
  ev : ∀ env script x y mem, Bytes.valid script → R x y →
    (ev₁ env script x mem).1 = (ev₂ env script y mem).1 ∧
      ((ev₁ env script x mem).1 = .ok → RS (ev₁ env script x mem).2 (ev₂ env script y mem).2)

/-- **`afterP2shP_congr`.** *What it says:* the P2SH step gives the same verdict on two agreeing views, and the
same depth when that verdict is valid. *What it assumes:* `ViewRel`; the copies related (both absent, or related
stacks with the same counter); the two states related. *Why it matters:* `phase2P_congr` (#143). -/
theorem afterP2shP_congr {σ₁ S₁ σ₂ S₂ : Type} (V₁ : PhaseView σ₁ S₁) (V₂ : PhaseView σ₂ S₂)
    (ev₁ : Env → Bytes → σ₁ → Nat → Outcome × S₁) (ev₂ : Env → Bytes → σ₂ → Nat → Outcome × S₂)
    (W : ViewRel V₁ V₂ ev₁ ev₂) (params : EvalParams) (ctx : Context) (flags0 : Flags)
    (scriptSig scriptPubKey : Bytes) (c₁ : Option (σ₁ × Nat)) (c₂ : Option (σ₂ × Nat))
    (hc : (c₁ = none ∧ c₂ = none) ∨ ∃ x y m, c₁ = some (x, m) ∧ c₂ = some (y, m) ∧ W.R x y)
    (t₁ : S₁) (t₂ : S₂) (ht : W.RS t₁ t₂) :
    finishP flags0 ctx (afterP2shP V₁ ev₁ params ctx flags0 scriptSig scriptPubKey c₁ t₁) =
      finishP flags0 ctx (afterP2shP V₂ ev₂ params ctx flags0 scriptSig scriptPubKey c₂ t₂) := by
  have hl := W.length _ _ (W.stack _ _ ht)
  unfold afterP2shP
  rcases hc with ⟨rfl, rfl⟩ | ⟨x, y, m, rfl, rfl, hxy⟩
  · simp only [hl]
  · simp only []
    cases isP2SH scriptPubKey
    · simp only [Bool.false_eq_true, ↓reduceIte, hl]
    · cases isPushOnly scriptSig
      · rfl
      · simp only [Bool.not_true, Bool.false_eq_true, ↓reduceIte]
        rcases TopRel.cases (W.top _ _ hxy) with ⟨f1, f2⟩ | ⟨pk, xr, yr, f1, f2, hpk, hr⟩
        · simp only [f1, f2]; rfl
        · simp only [f1, f2]
          obtain ⟨g1, g2⟩ := W.ev (mkEnv params ctx flags0 none) pk xr yr (m - (pk.length + elementOverhead)) hpk hr
          generalize ev₁ (mkEnv params ctx flags0 none) pk xr (m - (pk.length + elementOverhead)) = q1 at g1 g2 ⊢
          generalize ev₂ (mkEnv params ctx flags0 none) pk yr (m - (pk.length + elementOverhead)) = q2 at g1 g2 ⊢
          obtain ⟨p1, u1⟩ := q1
          obtain ⟨p2, u2⟩ := q2
          simp only at g1 g2
          subst g1
          cases p1 with
          | err e => rfl
          | unimplemented o => rfl
          | undefinedInReference f => rfl
          | ok =>
            have hU := W.stack _ _ (g2 rfl)
            have hl3 := W.length _ _ hU
            rcases TopRel.cases (W.top _ _ hU) with ⟨k1, k2⟩ | ⟨t3, _, _, k1, k2, _, _⟩
            · simp only [k1, k2]; rfl
            · simp only [k1, k2, hl3]

/-- **`phase2P_congr`.** *What it says:* `phase2P` gives the same verdict on two agreeing views from related
stacks. *What it assumes:* `ViewRel`; the stacks related; the locking script is bytes. *Why it matters:* the
locking phase on the packed hand-off (#143). -/
theorem phase2P_congr {σ₁ S₁ σ₂ S₂ : Type} (V₁ : PhaseView σ₁ S₁) (V₂ : PhaseView σ₂ S₂)
    (ev₁ : Env → Bytes → σ₁ → Nat → Outcome × S₁) (ev₂ : Env → Bytes → σ₂ → Nat → Outcome × S₂)
    (W : ViewRel V₁ V₂ ev₁ ev₂) (params : EvalParams) (ctx : Context) (flags0 : Flags)
    (scriptSig scriptPubKey : Bytes) (x : σ₁) (y : σ₂) (memUsed : Nat) (hxy : W.R x y)
    (hspk : Bytes.valid scriptPubKey) :
    phase2P V₁ ev₁ params ctx flags0 scriptSig scriptPubKey x memUsed =
      phase2P V₂ ev₂ params ctx flags0 scriptSig scriptPubKey y memUsed := by
  unfold phase2P
  obtain ⟨h1, h2⟩ := W.ev (mkEnv params ctx flags0 none) scriptPubKey x y memUsed hspk hxy
  generalize ev₁ (mkEnv params ctx flags0 none) scriptPubKey x memUsed = r1 at h1 h2 ⊢
  generalize ev₂ (mkEnv params ctx flags0 none) scriptPubKey y memUsed = r2 at h1 h2 ⊢
  obtain ⟨o1, t1⟩ := r1
  obtain ⟨o2, t2⟩ := r2
  simp only at h1 h2
  subst h1
  cases o1 with
  | err e => rfl
  | unimplemented o => rfl
  | undefinedInReference f => rfl
  | ok =>
    have hS := h2 rfl
    rcases TopRel.cases (W.top _ _ (W.stack _ _ hS)) with ⟨e1, e2⟩ | ⟨b, x', y', e1, e2, _, _⟩
    · simp only [e1, e2]
    · simp only [e1, e2]
      cases castToBool b
      · rfl
      · simp only [Bool.not_true, Bool.false_eq_true, ↓reduceIte]
        apply afterP2shP_congr V₁ V₂ ev₁ ev₂ W _ _ _ _ _ _ _ _ _ _ hS
        cases flags0.p2shCopy
        · exact Or.inl ⟨rfl, rfl⟩
        · exact Or.inr ⟨x, y, memUsed, rfl, rfl, hxy⟩

/-- **`verifyScriptP_congr`.** *What it says:* `verifyScriptP` gives the same verdict on two agreeing views. *What
it assumes:* `ViewRel`; both scripts are bytes. *Why it matters:* the two phases on the packed hand-off (#143). -/
theorem verifyScriptP_congr {σ₁ S₁ σ₂ S₂ : Type} (V₁ : PhaseView σ₁ S₁) (V₂ : PhaseView σ₂ S₂)
    (ev₁ : Env → Bytes → σ₁ → Nat → Outcome × S₁) (ev₂ : Env → Bytes → σ₂ → Nat → Outcome × S₂)
    (W : ViewRel V₁ V₂ ev₁ ev₂) (params : EvalParams) (ctx : Context) (scriptSig scriptPubKey : Bytes)
    (hss : Bytes.valid scriptSig) (hspk : Bytes.valid scriptPubKey) :
    verifyScriptP V₁ ev₁ params ctx scriptSig scriptPubKey =
      verifyScriptP V₂ ev₂ params ctx scriptSig scriptPubKey := by
  unfold verifyScriptP
  split
  · rfl
  · simp only []
    split
    · rfl
    · obtain ⟨h1, h2⟩ := W.ev (mkEnv params ctx params.flags.forkAdjust (some scriptPubKey)) scriptSig V₁.nil V₂.nil 0
        hss W.nil
      generalize ev₁ (mkEnv params ctx params.flags.forkAdjust (some scriptPubKey)) scriptSig V₁.nil 0 = r1 at h1 h2 ⊢
      generalize ev₂ (mkEnv params ctx params.flags.forkAdjust (some scriptPubKey)) scriptSig V₂.nil 0 = r2 at h1 h2 ⊢
      obtain ⟨o1, t1⟩ := r1
      obtain ⟨o2, t2⟩ := r2
      simp only at h1 h2
      subst h1
      cases o1 with
      | err e => rfl
      | unimplemented o => rfl
      | undefinedInReference f => rfl
      | ok =>
        have hS := h2 rfl
        simp only []
        rw [W.memUsed _ _ hS]
        exact phase2P_congr V₁ V₂ ev₁ ev₂ W params ctx _ scriptSig scriptPubKey _ _ _ (W.stack _ _ hS) hspk

/-- The implementation's view: the packed array, its last element read as bytes. -/
def implView : PhaseView (Array Elem) IState :=
  { stack := IState.stack, memUsed := IState.memUsed,
    top? := fun a => match a.back? with
      | none => none
      | some x => some (Elem.toBytes x, a.pop),
    length := Array.size, nil := #[] }

/-- **`implView_rel`.** *What it says:* the implementation's view and loop agree with the spec's, an array related
to the list it reads as and a state to the state it stands for. *What it assumes:* `Refines exec execI`. *Why it
matters:* `verifyScriptA_eq` (#143). -/
def implView_rel (exec : OpExec) (execI : OpExecI) (h : Refines exec execI) :
    ViewRel implView specView (evalScriptI execI) (evalScript exec) where
  R a l := a.toList.reverse.map Elem.toBytes = l
  RS s st := s.abs = st
  stack s t hs := by subst hs; rfl
  memUsed s t hs := by subst hs; rfl
  top a l hal := by
    subst hal
    simp only [implView, specView]
    cases hb : a.back? with
    | none => rw [arr_back_none a hb]; trivial
    | some x =>
      rw [arr_back_some a x hb]
      exact ⟨rfl, Elem.toBytes_valid x, rfl⟩
  length a l hal := by subst hal; simp [implView, specView]
  nil := rfl
  ev env script a l mem hv hal := by
    subst hal
    exact evalScriptI_rel exec execI h env script a mem hv

/-- `Machine.verifyScript` on the implementation: `verifyScriptP` on the packed view, the unlocking phase's array
handed to the locking phase as it is (#143). A script with a value at or above 256 has no packed form: that spend
runs on the spec's `Machine.verifyScript`. -/
def verifyScriptA (exec : OpExec) (execI : OpExecI) (params : EvalParams) (ctx : Context)
    (scriptSig scriptPubKey : Bytes) : Verdict :=
  if Elem.validB scriptSig && Elem.validB scriptPubKey then
    verifyScriptP implView (evalScriptI execI) params ctx scriptSig scriptPubKey
  else verifyScript exec params ctx scriptSig scriptPubKey

/-- **`verifyScriptA_eq`.** *What it says:* the verifier run on the implementation gives `Machine.verifyScript`'s
verdict on every spend, when the implementation's hook refines the spec's. *What it assumes:*
`Refines exec execI`. *Why it matters:* the machine's refinement, whole (#50). -/
theorem verifyScriptA_eq (exec : OpExec) (execI : OpExecI) (h : Refines exec execI) (params : EvalParams)
    (ctx : Context) (scriptSig scriptPubKey : Bytes) :
    verifyScriptA exec execI params ctx scriptSig scriptPubKey =
      verifyScript exec params ctx scriptSig scriptPubKey := by
  unfold verifyScriptA
  split
  · rename_i hg
    rw [Bool.and_eq_true, Elem.validB_iff, Elem.validB_iff] at hg
    rw [verifyScript_eq_gen, ← verifyScriptP_spec]
    exact verifyScriptP_congr _ _ _ _ (implView_rel exec execI h) params ctx scriptSig scriptPubKey hg.1 hg.2
  · rfl

end BsvScript.Impl
