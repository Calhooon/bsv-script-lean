import BsvScript.Eval
import BsvScript.Ops.Crypto
/-!
# BsvScript.Properties.Resources

The resource bounds (#25, S1's half; `docs/DESIGN.md` §9): what the machine enforces, at the site
the reference enforces it, as theorems on the machine. `Machine.loop` is parametrized by the
family hook `OpExec`; a bound the loop enforces after every step (the pre-Genesis stack depth,
`1800–1803`) is a theorem for every hook; a bound a family may touch (the op count through
`OP_CHECKMULTISIG`, `1534–1536`; the memory counter through every push and pop) is a theorem
under a named hypothesis on the hook (`HookOpCount`, `HookMem`) that each family discharges for
its own `exec`: the crypto family's two multisig bounds are below (R5); the two hypotheses are
discharged for every family's `exec` and for `Eval.opExec` in `BsvScript.Properties.Hooks` (H2, H3;
2026-09-27), so R2a and R3b hold for the evaluator's loop with no hook hypothesis left (H4, H5), each
from its start condition (the op count within the limit; the counter exact, which the locking phase
lacks after an unlocking script that left elements on its alt stack, R3b). The machine's own steps (the
pushes, the flow opcodes, the separator) are discharged here.

Bare line numbers are `src/script/interpreter.cpp` at the pin (`docs/PROVENANCE.md`).
-/

namespace BsvScript.Properties
open BsvScript.Params BsvScript.Machine BsvScript.Numbers

/-! ## R1: the script-size gate (`429–430`) -/

/-- **R1 (the script-size gate).** *What it says:* the spec's `evalScript` refuses a script longer than
`MaxScriptSize` before reading a byte (`429–430`), `SCRIPT_ERR_SCRIPT_SIZE`, with the state as it
was handed in. *What it assumes:* nothing. *Why it matters:* the limit is per script (the unlocking
and the locking script separately), read from the era's parameters (`docs/PARAMETERS.md` §1). The
reference's `EvalScript` tests one thing before it, a flag word that marks the UTXO post-Chronicle and
not post-Genesis (`SCRIPT_ERR_INVALID_FLAGS`, `413–414`); the spec tests that once, in `verifyScript`
before any call (`valid_flags`, `2312–2313`), so on every call `VerifyScript` makes the two agree. -/
theorem evalScript_scriptSize (exec : OpExec) (env : Env) (script : Bytes) (stack : List Bytes) (memUsed : Nat)
    (h : env.params.limits.maxScriptSize < script.length) :
    evalScript exec env script stack memUsed
      = (.err .scriptSize, { stack := stack, memUsed := memUsed, codeSep := script }) := by
  simp [evalScript, h]

/-- **R1a.** Within the limit the spec's `evalScript` is the loop on the fresh state (`1984–2006`, `407`):
in the spec the size gate is the only thing between the call and the first instruction (the reference's
`EvalScript` refuses an invalid pair of UTXO markers first, `413–414`, which `verifyScript` has refused
before any call, `2312–2313`). -/
theorem evalScript_of_size_le (exec : OpExec) (env : Env) (script : Bytes) (stack : List Bytes) (memUsed : Nat)
    (h : script.length ≤ env.params.limits.maxScriptSize) :
    evalScript exec env script stack memUsed
      = loop exec env script { stack := stack, memUsed := memUsed, codeSep := script } := by
  simp [evalScript, Nat.not_lt.mpr h]

/-! ## R2: the op count (`466–467`, `377–380`) -/

/-- **R2 (the op count's refusal).** *What it says:* every opcode above `OP_16` is charged to the op
count before the disabled test and the step, executed or not (`466–467`), and the instruction that
takes the count over `MaxOpsPerScript` fails `SCRIPT_ERR_OP_COUNT` with the count already charged
(`377–380`). *What it assumes:* the instruction parses and passes the pre-Genesis push-size test.
*Why it matters:* the limit counts instructions, not executed ones; a dead branch costs the same. -/
theorem loop_opCount (exec : OpExec) (env : Env) (op : Nat) (rest data : Bytes) (k : Nat) (st : State)
    (hop : getOpTail op rest = some (data, k))
    (hsize : env.utxoAfterGenesis = true ∨ data.length ≤ Consensus.maxScriptElementSizeBeforeGenesis)
    (h16 : Op.OP_16 < op) (hc : env.params.limits.maxOpsPerScript < st.opCount + 1) :
    loop exec env (op :: rest) st = (.err .opCount, { st with opCount := st.opCount + 1 }) := by
  rw [loop.eq_2]
  rcases hsize with hs | hs <;> simp [hop, hs, h16, hc, Nat.not_lt.mpr]

/-- A hook keeps the op count within the limit: from a state within it, every `.ok` answer is within
it. The crypto family's `OP_CHECKMULTISIG` charges the key count and refuses over the limit
(`1534–1536`, R5b below); no other opcode touches the count. -/
def HookOpCount (exec : OpExec) (env : Env) : Prop :=
  ∀ (op : Nat) (data : Bytes) (st st' : State), st.opCount ≤ env.params.limits.maxOpsPerScript →
    exec op data env st = some (.ok st') → st'.opCount ≤ env.params.limits.maxOpsPerScript

/-- A push's result, explicitly (`limitedstack.h:163–173`): the element on top, the counter grown by its
weight. -/
theorem pushElem_ok (env : Env) (st st' : State) (x : Bytes) (h : pushElem env st x = .ok st') :
    st' = { st with stack := x :: st.stack, memUsed := st.memUsed + x.length + elementOverhead } := by
  revert h
  unfold pushElem
  dsimp only
  split
  · intro h; cases h
  · intro h; cases h; rfl

/-- A push leaves the op count as it was (only the stack and the counter move, `limitedstack.h:163–173`). -/
theorem pushElem_opCount (env : Env) (st st' : State) (x : Bytes) (h : pushElem env st x = .ok st') :
    st'.opCount = st.opCount := by
  rw [pushElem_ok env st st' x h]

/-- `OP_IF` and its three siblings leave the op count as they found it (`784–825`: the tracker and one pop). -/
theorem execIf_opCount (env : Env) (op : Nat) (fExec : Bool) (st st' : State)
    (h : execIf env op fExec st = .cont st') : st'.opCount = st.opCount := by
  revert h
  unfold execIf
  try dsimp only
  repeat' split
  all_goals (intro h; cases h <;> rfl)

/-- `OP_CHECKLOCKTIMEVERIFY` leaves the op count as it found it (`519–560`: it only reads the stack). -/
theorem execCltv_opCount (env : Env) (st st' : State) (h : execCltv env st = .cont st') : st'.opCount = st.opCount := by
  revert h
  unfold execCltv
  try dsimp only
  repeat' split
  all_goals (intro h; cases h <;> rfl)

/-- `OP_CHECKSEQUENCEVERIFY` leaves the op count as it found it (`562–597`: it only reads the stack). -/
theorem execCsv_opCount (env : Env) (st st' : State) (h : execCsv env st = .cont st') : st'.opCount = st.opCount := by
  revert h
  unfold execCsv
  try dsimp only
  repeat' split
  all_goals (intro h; cases h <;> rfl)

/-- **The machine's own switch, branch by branch** (`483–871`): a property of states that holds of the
state handed in, of every push's result, of the three checkers' results (`execCltv`, `execCsv`,
`execIf`), of the tracker and `OP_RETURN` updates, of `OP_VERIFY`'s pop and of the hook's answer holds
of every state `execFlow` continues with. Walked `if` by `if` (`split_ifs` on the thirteen-way chain
times out), so each of R2 and R3 discharges the branches once. -/
theorem execFlow_preserves (P : State → Prop) (exec : OpExec) (env : Env) (op : Nat) (data : Bytes)
    (fExec : Bool) (st st' : State) (hst : P st)
    (hpush : ∀ v s, pushElem env st v = .ok s → P s)
    (hcltv : ∀ s, execCltv env st = .cont s → P s)
    (hcsv : ∀ s, execCsv env st = .cont s → P s)
    (hif : ∀ s, execIf env op fExec st = .cont s → P s)
    (hcond : ∀ c, P { st with cond := c })
    (hret : P { st with nonTopLevelReturn := true })
    (hpop : ∀ x xs, st.stack = x :: xs → P { st with stack := xs, memUsed := st.memUsed - (x.length + elementOverhead) })
    (hhook : ∀ s, exec op data env st = some (.ok s) → P s)
    (h : execFlow exec env op data fExec st = .cont st') : P st' := by
  unfold execFlow at h
  by_cases c1 : (op = Op.OP_1NEGATE) ∨ (Op.OP_1 ≤ op ∧ op ≤ Op.OP_16)
  · rw [ite_eq_left c1] at h
    split at h
    · cases h; exact hpush _ _ ‹_›
    · cases h
  rw [ite_eq_right c1] at h
  by_cases c2 : op = Op.OP_NOP
  · rw [ite_eq_left c2] at h; cases h; exact hst
  rw [ite_eq_right c2] at h
  by_cases c3 : op = Op.OP_CHECKLOCKTIMEVERIFY
  · rw [ite_eq_left c3] at h; exact hcltv _ h
  rw [ite_eq_right c3] at h
  by_cases c4 : op = Op.OP_CHECKSEQUENCEVERIFY
  · rw [ite_eq_left c4] at h; exact hcsv _ h
  rw [ite_eq_right c4] at h
  by_cases c5 : op = Op.OP_VER
  · rw [ite_eq_left c5] at h
    split at h
    · cases h
    · split at h
      · cases h; exact hpush _ _ ‹_›
      · cases h
  rw [ite_eq_right c5] at h
  by_cases c6 : op = Op.OP_NOP1 ∨ op = Op.OP_NOP9 ∨ op = Op.OP_NOP10
  · rw [ite_eq_left c6] at h
    split at h
    · cases h
    · cases h; exact hst
  rw [ite_eq_right c6] at h
  by_cases c7 : op = Op.OP_VERIF ∨ op = Op.OP_VERNOTIF
  · rw [ite_eq_left c7] at h
    split at h
    · split at h
      · cases h; exact hst
      · cases h
    · exact hif _ h
  rw [ite_eq_right c7] at h
  by_cases c8 : op = Op.OP_IF ∨ op = Op.OP_NOTIF
  · rw [ite_eq_left c8] at h; exact hif _ h
  rw [ite_eq_right c8] at h
  by_cases c9 : op = Op.OP_ELSE
  · rw [ite_eq_left c9] at h
    split at h
    · cases h
    · cases h; exact hcond _
  rw [ite_eq_right c9] at h
  by_cases c10 : op = Op.OP_ENDIF
  · rw [ite_eq_left c10] at h
    split at h
    · cases h
    · cases h; exact hcond _
  rw [ite_eq_right c10] at h
  by_cases c11 : op = Op.OP_VERIFY
  · rw [ite_eq_left c11] at h
    split at h
    · cases h
    · split at h
      · cases h; exact hpop _ _ ‹_›
      · cases h
  rw [ite_eq_right c11] at h
  by_cases c12 : op = Op.OP_RETURN
  · rw [ite_eq_left c12] at h
    split at h
    · split at h
      · cases h
      · cases h; exact hret
    · cases h
  rw [ite_eq_right c12] at h
  split at h
  · cases h; exact hhook _ ‹_›
  · cases h
  · cases h
  · split at h <;> cases h

/-- The machine's own switch keeps the op count within the limit; the hook by `HookOpCount`. -/
theorem execFlow_opCount (exec : OpExec) (env : Env) (hh : HookOpCount exec env) (op : Nat) (data : Bytes)
    (fExec : Bool) (st st' : State) (hle : st.opCount ≤ env.params.limits.maxOpsPerScript)
    (h : execFlow exec env op data fExec st = .cont st') : st'.opCount ≤ env.params.limits.maxOpsPerScript :=
  execFlow_preserves (fun s => s.opCount ≤ env.params.limits.maxOpsPerScript) exec env op data fExec st st' hle
    (fun v s hs => by rw [pushElem_opCount env st s v hs]; exact hle)
    (fun s hs => by rw [execCltv_opCount env st s hs]; exact hle)
    (fun s hs => by rw [execCsv_opCount env st s hs]; exact hle)
    (fun s hs => by rw [execIf_opCount env op fExec st s hs]; exact hle)
    (fun _ => hle) hle (fun _ _ _ => hle) (fun s hs => hh op data st s hle hs) h

/-- `execStep` keeps the op count within the limit under `HookOpCount` (`473–482`, `1445–1448`). -/
theorem execStep_opCount (exec : OpExec) (env : Env) (hh : HookOpCount exec env) (op : Nat) (data rest : Bytes)
    (k : Nat) (fExec : Bool) (st st' : State) (hle : st.opCount ≤ env.params.limits.maxOpsPerScript)
    (h : execStep exec env op data rest k fExec st = .cont st') : st'.opCount ≤ env.params.limits.maxOpsPerScript := by
  revert h
  unfold execStep
  try dsimp only
  repeat' split
  all_goals intro h
  all_goals first
    | (cases h; done)
    | (cases h; exact hle)
    | (cases h; rw [pushElem_opCount _ _ _ _ ‹_›]; exact hle)
    | exact execFlow_opCount exec env hh op data fExec st st' hle h

/-- **R2a (the op count's invariant).** *What it says:* under `HookOpCount`, from a state within the
limit the loop returns a state at most one over it, whatever the outcome (the one over is the
refusal's own state, R2; every step is handed a state within the limit). *What it assumes:* the hook
hypothesis. *Why it matters:* the count bounds the instructions of a script, so a verifier that must
fit `MaxOpsPerScript` can read its budget off the state at any step. Induction on a bound of the
script length, as `loop_ne_unimplemented`. -/
theorem loop_opCount_le (exec : OpExec) (env : Env) (hh : HookOpCount exec env) :
    ∀ (n : Nat) (s : Bytes), s.length ≤ n → ∀ (st : State), st.opCount ≤ env.params.limits.maxOpsPerScript →
      (loop exec env s st).2.opCount ≤ env.params.limits.maxOpsPerScript + 1 := by
  intro n
  induction n with
  | zero =>
    intro s hs st hle
    cases s with
    | nil => rw [loop.eq_1]; split <;> (dsimp only; omega)
    | cons a t => simp at hs
  | succ n ih =>
    intro s hs st hle
    cases s with
    | nil => rw [loop.eq_1]; split <;> (dsimp only; omega)
    | cons op rest =>
      rw [loop.eq_2]
      dsimp only
      repeat' split
      all_goals first
        | (dsimp only; omega)
        | (dsimp only; simp_all; omega)
        | (dsimp only
           have hstep := ‹execStep _ _ _ _ _ _ _ _ = StepR.cont _›
           have := execStep_opCount exec env hh _ _ _ _ _ _ _ (by simp_all) hstep
           omega)
        | (have hstep := ‹execStep _ _ _ _ _ _ _ _ = StepR.cont _›
           apply ih
           · simp only [List.length_cons, List.length_drop] at hs ⊢; omega
           · exact execStep_opCount exec env hh _ _ _ _ _ _ _ (by simp_all) hstep)

/-! ## R3: the stack memory (`limitedstack.cpp:194–207`, `1815–1818`) -/

/-- The accounting weight of an element: its size plus `ELEMENT_OVERHEAD` (`limitedstack.h:43`). -/
def elemWeight (x : Bytes) : Nat := x.length + elementOverhead

/-- What the counter should read: the weight of every element on both stacks (`combinedStackSize`,
`limitedstack.h:86`; the alt stack shares the budget, `1993`). -/
def memOf (st : State) : Nat := (st.stack.map elemWeight).sum + (st.alt.map elemWeight).sum

/-- The accounting invariant: the counter is exact. -/
def memInv (st : State) : Prop := st.memUsed = memOf st

/-- **R3 (the memory refusal).** *What it says:* a push fails `SCRIPT_ERR_STACK_SIZE` exactly when the
counter plus the element's weight would exceed `MaxStackMemoryUsage` (`limitedstack.h:163–173`,
`limitedstack.cpp:194–207`, `1815–1818`). *What it assumes:* nothing. *Why it matters:* the limit is
on bytes plus 32 per element, not on the element count; with R3b the counter it compares is the
sum over both stacks in a phase that starts exact (not in the locking phase after an unlocking script
that left elements on its alt stack, R3b). -/
theorem pushElem_stackSize_iff (env : Env) (st : State) (x : Bytes) :
    pushElem env st x = .error .stackSize ↔ env.params.limits.maxStackMemoryUsage < st.memUsed + elemWeight x := by
  unfold pushElem elemWeight
  try dsimp only
  split
  · rename_i hc; constructor
    · intro _; omega
    · intro _; rfl
  · rename_i hc; constructor
    · intro h; cases h
    · intro h; omega

/-- **R3a.** A push keeps the invariant: the counter grows by the element's weight (`limitedstack.h:171`). -/
theorem pushElem_memInv (env : Env) (st st' : State) (x : Bytes) (hi : memInv st) (h : pushElem env st x = .ok st') :
    memInv st' := by
  rw [pushElem_ok env st st' x h]
  unfold memInv memOf at hi ⊢
  simp only [List.map_cons, List.sum_cons, elemWeight] at hi ⊢
  omega

/-- A pop keeps the invariant: the counter shrinks by the element's weight (`limitedstack.cpp:211–219`). -/
theorem popElem_memInv (st st' : State) (x : Bytes) (hi : memInv st) (h : popElem st = .ok (x, st')) : memInv st' := by
  unfold popElem at h
  cases hs : st.stack with
  | nil => simp [hs] at h
  | cons y ys =>
    simp only [hs] at h
    cases h
    unfold memInv memOf at hi ⊢
    rw [hs] at hi
    simp only [List.map_cons, List.sum_cons, elemWeight] at hi ⊢
    omega

/-- A move to the alt stack keeps the invariant: nothing is charged (`876–881`; the weight moves from
one sum to the other). -/
theorem toAlt_memInv (st st' : State) (hi : memInv st) (h : Ops.Stack.toAlt st = .ok st') : memInv st' := by
  unfold Ops.Stack.toAlt Ops.Stack.need at h
  cases hs : st.stack with
  | nil => simp [hs, bind, Except.bind] at h
  | cons x rest =>
    simp [hs, bind, Except.bind, pure, Except.pure] at h
    subst h
    unfold memInv memOf at hi ⊢
    rw [hs] at hi
    simp only [List.map_cons, List.sum_cons, elemWeight] at hi ⊢
    omega

/-- A move back from the alt stack keeps the invariant (`883–888`). -/
theorem fromAlt_memInv (st st' : State) (hi : memInv st) (h : Ops.Stack.fromAlt st = .ok st') : memInv st' := by
  unfold Ops.Stack.fromAlt at h
  cases hs : st.alt with
  | nil => simp [hs, throw, throwThe, MonadExceptOf.throw] at h
  | cons x rest =>
    simp [hs, pure, Except.pure] at h
    subst h
    unfold memInv memOf at hi ⊢
    rw [hs] at hi
    simp only [List.map_cons, List.sum_cons, elemWeight] at hi ⊢
    omega

/-- The weight sum after `set`: the old element's weight out, the new one's in. -/
theorem sum_map_set (l : List Bytes) (n : Nat) (a : Bytes) (h : n < l.length) :
    ((l.set n a).map elemWeight).sum + elemWeight l[n] = (l.map elemWeight).sum + elemWeight a := by
  induction l generalizing n with
  | nil => simp at h
  | cons x xs ih =>
    cases n with
    | zero => simp only [List.set_cons_zero, List.map_cons, List.sum_cons, List.getElem_cons_zero]; omega
    | succ m =>
      simp only [List.set_cons_succ, List.map_cons, List.sum_cons, List.getElem_cons_succ]
      have := ih m (by simp at h; omega)
      omega

/-- The weight sum after `eraseIdx`: the erased element's weight out. -/
theorem sum_map_eraseIdx (l : List Bytes) (k : Nat) (h : k < l.length) :
    ((l.eraseIdx k).map elemWeight).sum + elemWeight l[k] = (l.map elemWeight).sum := by
  induction l generalizing k with
  | nil => simp at h
  | cons x xs ih =>
    cases k with
    | zero => simp only [List.eraseIdx_cons_zero, List.map_cons, List.sum_cons, List.getElem_cons_zero]; omega
    | succ m =>
      simp only [List.eraseIdx_cons_succ, List.map_cons, List.sum_cons, List.getElem_cons_succ]
      have := ih m (by simp at h; omega)
      omega

/-- The weight sum after `insertIdx`: the inserted element's weight in. -/
theorem sum_map_insertIdx (l : List Bytes) (k : Nat) (x : Bytes) (h : k ≤ l.length) :
    ((l.insertIdx k x).map elemWeight).sum = (l.map elemWeight).sum + elemWeight x := by
  induction l generalizing k with
  | nil =>
    have hk : k = 0 := by simpa using h
    subst hk; simp [List.insertIdx_zero]
  | cons y ys ih =>
    cases k with
    | zero => simp only [List.insertIdx_zero, List.map_cons, List.sum_cons]; omega
    | succ m =>
      simp only [List.insertIdx_succ_cons, List.map_cons, List.sum_cons]
      have := ih m (by simp at h; omega)
      omega

/-- An erase below the top keeps the invariant (`limitedstack.cpp:260–267`): the element's weight is
released. -/
theorem eraseTop_memInv (st : State) (k : Nat) (hk : k < st.stack.length) (hi : memInv st) :
    memInv (Ops.Stack.eraseTop st k) := by
  unfold memInv memOf at hi ⊢
  unfold Ops.Stack.eraseTop Ops.Stack.topAt
  dsimp only
  simp only [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hk, Option.getD_some]
  have := sum_map_eraseIdx st.stack k hk
  have hw : elemWeight st.stack[k] = st.stack[k].length + elementOverhead := rfl
  omega

/-- An insert below the top keeps the invariant (`limitedstack.cpp:269–283`): charged like a push. -/
theorem insertTop_memInv (env : Env) (st st' : State) (k : Nat) (x : Bytes) (hk : k ≤ st.stack.length)
    (hi : memInv st) (h : Ops.Stack.insertTop env st k x = .ok st') : memInv st' := by
  revert h
  unfold Ops.Stack.insertTop
  try dsimp only
  split
  · intro h; cases h
  · intro h
    cases h
    unfold memInv memOf at hi ⊢
    have := sum_map_insertIdx st.stack k x hk
    have hw : elemWeight x = x.length + elementOverhead := rfl
    dsimp only
    omega

/-- A swap keeps the invariant: nothing moves in the sums (`limitedstack.cpp:285–288`). -/
theorem swapTop_memInv (st : State) (i j : Nat) (hi' : i < st.stack.length) (hj : j < st.stack.length)
    (hi : memInv st) : memInv (Ops.Stack.swapTop st i j) := by
  unfold memInv memOf at hi ⊢
  unfold Ops.Stack.swapTop Ops.Stack.topAt
  dsimp only
  simp only [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hi', List.getElem?_eq_getElem hj, Option.getD_some]
  have h1 := sum_map_set st.stack i st.stack[j] hi'
  have hlen : (st.stack.set i st.stack[j]).length = st.stack.length := by simp
  have h2 := sum_map_set (st.stack.set i st.stack[j]) j st.stack[i] (by rw [hlen]; exact hj)
  rw [List.getElem_set] at h2
  split at h2
  · rename_i hij; subst hij; omega
  · omega

/-- `OP_IF` and its three siblings keep the accounting invariant (`784–825`: one pop, its weight released, or nothing). -/
theorem execIf_memInv (env : Env) (op : Nat) (fExec : Bool) (st st' : State) (hi : memInv st)
    (h : execIf env op fExec st = .cont st') : memInv st' := by
  revert h
  unfold execIf
  try dsimp only
  repeat' split
  all_goals intro h
  all_goals first
    | (cases h; done)
    | (cases h; exact hi)
    | (cases h
       unfold memInv memOf at hi ⊢
       simp_all only [List.map_cons, List.sum_cons, elemWeight]
       omega)

/-- `OP_CHECKLOCKTIMEVERIFY` keeps the accounting invariant (`519–560`: it leaves the operand where it is). -/
theorem execCltv_memInv (env : Env) (st st' : State) (hi : memInv st) (h : execCltv env st = .cont st') : memInv st' := by
  revert h
  unfold execCltv
  try dsimp only
  repeat' split
  all_goals (intro h; cases h <;> exact hi)

/-- `OP_CHECKSEQUENCEVERIFY` keeps the accounting invariant (`562–597`: it leaves the operand where it is). -/
theorem execCsv_memInv (env : Env) (st st' : State) (hi : memInv st) (h : execCsv env st = .cont st') : memInv st' := by
  revert h
  unfold execCsv
  try dsimp only
  repeat' split
  all_goals (intro h; cases h <;> exact hi)

/-- A hook keeps the accounting invariant: from an exact counter every `.ok` answer has an exact
counter. Each family's `exec` discharges it through `pushElem`/`popElem` and the stack primitives above. -/
def HookMem (exec : OpExec) (env : Env) : Prop :=
  ∀ (op : Nat) (data : Bytes) (st st' : State), memInv st → exec op data env st = some (.ok st') → memInv st'

/-- The machine's own switch keeps the invariant; the hook by `HookMem`. -/
theorem execFlow_memInv (exec : OpExec) (env : Env) (hh : HookMem exec env) (op : Nat) (data : Bytes)
    (fExec : Bool) (st st' : State) (hi : memInv st) (h : execFlow exec env op data fExec st = .cont st') : memInv st' :=
  execFlow_preserves memInv exec env op data fExec st st' hi
    (fun v s hs => pushElem_memInv env st s v hi hs)
    (fun s hs => execCltv_memInv env st s hi hs)
    (fun s hs => execCsv_memInv env st s hi hs)
    (fun s hs => execIf_memInv env op fExec st s hi hs)
    (fun _ => hi) hi
    (fun x xs hs => by
      unfold memInv memOf at hi ⊢
      rw [hs] at hi
      simp only [List.map_cons, List.sum_cons, elemWeight] at hi ⊢
      omega)
    (fun s hs => hh op data st s hi hs) h

/-- `execStep` keeps the invariant under `HookMem` (`473–482`: the push; `1445–1448`: the separator
touches no stack). -/
theorem execStep_memInv (exec : OpExec) (env : Env) (hh : HookMem exec env) (op : Nat) (data rest : Bytes)
    (k : Nat) (fExec : Bool) (st st' : State) (hi : memInv st)
    (h : execStep exec env op data rest k fExec st = .cont st') : memInv st' := by
  revert h
  unfold execStep
  try dsimp only
  repeat' split
  all_goals intro h
  all_goals first
    | (cases h; done)
    | (cases h; exact hi)
    | (cases h; exact pushElem_memInv _ _ _ _ hi ‹_›)
    | exact execFlow_memInv exec env hh op data fExec st st' hi h

/-- **R3b (the accounting invariant).** *What it says:* under `HookMem`, from an exact counter the loop
returns an exact counter whatever the outcome (an error returns the state of the step that failed,
exact as well). *What it assumes:* the hook hypothesis. *Why it matters:* `MaxStackMemoryUsage` is
compared against `memUsed` (R3); this theorem says that, from an exact start, that number stays the sum
of the elements' weights on both stacks, so within a phase that starts exact the limit is a statement
about the stacks, not about a counter. A phase need not start exact: the counter keeps the weight of
elements left on the alt stack when a phase ends (`1993–2005`, `Machine.State`), in the reference as in
the spec, so after an unlocking script that left some there the locking phase compares a counter above
its stacks' weight (H5). -/
theorem loop_memInv (exec : OpExec) (env : Env) (hh : HookMem exec env) :
    ∀ (n : Nat) (s : Bytes), s.length ≤ n → ∀ (st : State), memInv st → memInv (loop exec env s st).2 := by
  intro n
  induction n with
  | zero =>
    intro s hs st hi
    cases s with
    | nil => rw [loop.eq_1]; split <;> exact hi
    | cons a t => simp at hs
  | succ n ih =>
    intro s hs st hi
    cases s with
    | nil => rw [loop.eq_1]; split <;> exact hi
    | cons op rest =>
      rw [loop.eq_2]
      dsimp only
      repeat' split
      all_goals first
        | (dsimp only; exact hi)
        | (dsimp only
           have hstep := ‹execStep _ _ _ _ _ _ _ _ = StepR.cont _›
           exact execStep_memInv exec env hh _ _ _ _ _ _ _ (by exact hi) hstep)
        | (have hstep := ‹execStep _ _ _ _ _ _ _ _ = StepR.cont _›
           apply ih
           · simp only [List.length_cons, List.length_drop] at hs ⊢; omega
           · exact execStep_memInv exec env hh _ _ _ _ _ _ _ (by exact hi) hstep)

/-! ## R4: the pre-Genesis stack depth (`1800–1803`, `script.h:32`) -/

/-- The depth of both stacks (`stack.size() + altstack.size()`, `1800`). -/
def depth (st : State) : Nat := st.stack.length + st.alt.length

/-- **R4 (the depth refusal).** *What it says:* on a pre-Genesis coin a step that leaves more than
`MAX_STACK_ELEMENTS_BEFORE_GENESIS` = 1,000 elements on the two stacks fails `SCRIPT_ERR_STACK_SIZE`
(`1800–1803`, `script.h:32`) with the state the step left; stated for an instruction at or below
`OP_16` (a push: no op count, never disabled), the case that adds the 1,001st element by a push.
*What it assumes:* the instruction parses and passes the push-size test, and the step continues.
*Why it matters:* pre-Genesis the element count is the limit (the memory budget is unlimited there,
`docs/PARAMETERS.md` §1). -/
theorem loop_stackSize_preGenesis (exec : OpExec) (env : Env) (hg : env.utxoAfterGenesis = false)
    (op : Nat) (rest data : Bytes) (k : Nat) (st st' : State)
    (hop : getOpTail op rest = some (data, k)) (hsize : data.length ≤ Consensus.maxScriptElementSizeBeforeGenesis)
    (hlow : op ≤ Op.OP_16)
    (hstep : execStep exec env op data rest k (st.cond.isActive && (!st.nonTopLevelReturn || op == Op.OP_RETURN)) st
      = .cont st')
    (hdepth : Consensus.maxStackElementsBeforeGenesis < depth st') :
    loop exec env (op :: rest) st = (.err .stackSize, st') := by
  have h16 : ¬ (Op.OP_16 < op) := Nat.not_lt.mpr hlow
  have hdis : isOpcodeDisabled op env.utxoEra = false := by
    unfold isOpcodeDisabled
    have h1 : op ≠ Op.OP_2MUL := by unfold Op.OP_2MUL; unfold Op.OP_16 at hlow; omega
    have h2 : op ≠ Op.OP_2DIV := by unfold Op.OP_2DIV; unfold Op.OP_16 at hlow; omega
    simp [h1, h2]
  unfold depth at hdepth
  rw [loop.eq_2]
  simp [hop, hg, Nat.not_lt.mpr hsize, h16, hdis, hstep, hdepth]

/-- **R4a (the depth invariant).** *What it says:* on a pre-Genesis coin, from at most 1,000 elements
the loop returns at most 1,000 when it succeeds, for EVERY hook: the loop checks the depth after each
step (`1800–1803`) before continuing. *What it assumes:* nothing about the families. *Why it
matters:* the bound is the loop's, not the opcodes'. -/
theorem loop_depth_preGenesis (exec : OpExec) (env : Env) (hg : env.utxoAfterGenesis = false) :
    ∀ (n : Nat) (s : Bytes), s.length ≤ n → ∀ (st : State), depth st ≤ Consensus.maxStackElementsBeforeGenesis →
      (loop exec env s st).1 = .ok → depth (loop exec env s st).2 ≤ Consensus.maxStackElementsBeforeGenesis := by
  intro n
  induction n with
  | zero =>
    intro s hs st hd
    cases s with
    | nil => rw [loop.eq_1]; split <;> (intro _; exact hd)
    | cons a t => simp at hs
  | succ n ih =>
    intro s hs st hd
    cases s with
    | nil => rw [loop.eq_1]; split <;> (intro _; exact hd)
    | cons op rest =>
      rw [loop.eq_2]
      dsimp only
      repeat' split
      all_goals first
        | (intro h; cases h; done)
        | (intro h; simp at h; done)
        | (intro _; simpa [depth] using hd)
        | (apply ih
           · simp only [List.length_cons, List.length_drop] at hs ⊢; omega
           · unfold depth; simp_all)

/-! ## R5: the multisig bounds (`1517–1536`) -/

/-- **R5 (the key count).** *What it says:* `OP_CHECKMULTISIG` refuses a key count above
`MaxPubKeysPerMultiSig` as `SCRIPT_ERR_PUBKEY_COUNT` (`1530–1532`), after the count's read (`1519–1526`) and
its sign test (`1527–1528`), before any key or signature is read.
*What it assumes:* the count reads (`readCount`, width 4 under the minimal rule). *Why it matters:*
pre-Genesis the limit is 20 (`consensus.h:50`); post-Genesis it is the consensus constant `UINT32_MAX` on
the block path (`consensus.h:55`, `configscriptpolicy.cpp:131–134`) and the node's policy setting on the
mempool path (`configscriptpolicy.cpp:136`; default `UINT32_MAX`, `policy.h:150`; `docs/PARAMETERS.md`
§1). -/
theorem checkMultiSigOp_pubkeyCount (env : Env) (op : Nat) (st : State) (n : Int)
    (hlen : 1 ≤ st.stack.length) (hread : Ops.Crypto.readCount env (Ops.Stack.topAt st 0) = .ok n)
    (hnn : 0 ≤ n) (hbig : env.params.limits.maxPubKeysPerMultiSig < n.toNat) :
    Ops.Crypto.checkMultiSigOp env op st = .error .pubkeyCount := by
  have hneed : Ops.Stack.need st 1 = .ok () := by simp [Ops.Stack.need, Nat.not_lt.mpr hlen]
  have hneg : ¬ n < 0 := by omega
  simp [Ops.Crypto.checkMultiSigOp, hneed, hread, hneg, hbig, bind, Except.bind]
  all_goals rfl

/-- **R5a (a negative key count).** *What it says:* a negative key count is `SCRIPT_ERR_PUBKEY_COUNT`
(`1527–1528`). -/
theorem checkMultiSigOp_pubkeyCount_neg (env : Env) (op : Nat) (st : State) (n : Int)
    (hlen : 1 ≤ st.stack.length) (hread : Ops.Crypto.readCount env (Ops.Stack.topAt st 0) = .ok n) (hneg : n < 0) :
    Ops.Crypto.checkMultiSigOp env op st = .error .pubkeyCount := by
  have hneed : Ops.Stack.need st 1 = .ok () := by simp [Ops.Stack.need, Nat.not_lt.mpr hlen]
  simp [Ops.Crypto.checkMultiSigOp, hneed, hread, hneg, bind, Except.bind]
  all_goals rfl

/-- **R5b (the op count).** *What it says:* the key count is charged to the op count and the
instruction fails `SCRIPT_ERR_OP_COUNT` when the charged count exceeds `MaxOpsPerScript`
(`1534–1536`), after the key-count test and before any key is read. *What it assumes:* the count
reads and is within `MaxPubKeysPerMultiSig`. *Why it matters:* this is the one opcode that charges
more than one to the count; it is why `HookOpCount` is a hypothesis of R2a and this theorem its
discharge for the refusal side. -/
theorem checkMultiSigOp_opCount (env : Env) (op : Nat) (st : State) (n : Int)
    (hlen : 1 ≤ st.stack.length) (hread : Ops.Crypto.readCount env (Ops.Stack.topAt st 0) = .ok n)
    (hnn : 0 ≤ n) (hle : n.toNat ≤ env.params.limits.maxPubKeysPerMultiSig)
    (hops : env.params.limits.maxOpsPerScript < st.opCount + n.toNat) :
    Ops.Crypto.checkMultiSigOp env op st = .error .opCount := by
  have hneed : Ops.Stack.need st 1 = .ok () := by simp [Ops.Stack.need, Nat.not_lt.mpr hlen]
  have hneg : ¬ n < 0 := by omega
  simp [Ops.Crypto.checkMultiSigOp, hneed, hread, hneg, Nat.not_lt.mpr hle, hops, bind, Except.bind]
  all_goals rfl

/-! ## R6: the result width (`script_num.cpp:144–222`, `1273–1274`, `1367–1369`) -/

/-- A push never answers `SCRIPT_ERR_SCRIPTNUM_OVERFLOW`: its only error is the memory budget's. -/
theorem pushElem_ne_scriptnumOverflow (env : Env) (st : State) (x : Bytes) :
    pushElem env st x ≠ .error .scriptnumOverflow := by
  unfold pushElem
  try dsimp only
  split <;> simp

/-- **R6 (the result-width bound).** *What it says:* post-Genesis a bounded arithmetic result
(`+=`, `-=`, `*=`) whose minimal encoding exceeds `MaxScriptNumLength` is `SCRIPT_ERR_SCRIPTNUM_OVERFLOW`
(`script_num.cpp:144–222`, the checks at `script_num.cpp:166–167`, `script_num.cpp:196–197`, `script_num.cpp:216–217`, reached through the by-value
copies at `script_num.h:114–130` in the binary family, `interpreter.cpp:1305`, `1309`, `1313`, and directly in
the unary one, `1238–1245`, `1249`; thrown at the arithmetic, before the pops and the push, `1273–1274` in the unary
family and `1367–1369` in the binary one), and that is the only way `pushResult` answers that error.
*What it assumes:* nothing. *Why it matters:* the width in force (on the block path the consensus width,
750,000 bytes post-Genesis and 32,000,000 post-Chronicle, `configscriptpolicy.cpp:88–95`; on the mempool
path the node's policy setting, default 10,000, `policy.h:156`, `configscriptpolicy.cpp:97–109`;
`docs/PARAMETERS.md` §1) bounds every arithmetic result the machine will hold; pre-Genesis the `int64`
branch cannot overflow. -/
theorem pushResult_overflow_iff (env : Env) (st : State) (v : Int) (bounded : Bool) :
    Ops.Arith.pushResult env st v bounded = .error .scriptnumOverflow
      ↔ bounded = true ∧ env.utxoAfterGenesis = true ∧ env.params.limits.maxScriptNumLength < (encode v).length := by
  unfold Ops.Arith.pushResult
  try dsimp only
  split
  · rename_i hc
    simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
    constructor
    · intro _; exact ⟨hc.1.1, hc.1.2, hc.2⟩
    · intro _; rfl
  · rename_i hc
    constructor
    · intro h; exact absurd h (pushElem_ne_scriptnumOverflow env st _)
    · rintro ⟨h1, h2, h3⟩
      exact absurd (by simp [h1, h2, h3]) hc

/-- **R6a.** A result the push accepts is on the stack at its minimal encoding, within the width in force
when bounded post-Genesis. -/
theorem pushResult_ok (env : Env) (st st' : State) (v : Int) (bounded : Bool)
    (h : Ops.Arith.pushResult env st v bounded = .ok st') :
    st'.stack = encode v :: st.stack
      ∧ (bounded = true → env.utxoAfterGenesis = true → (encode v).length ≤ env.params.limits.maxScriptNumLength) := by
  revert h
  unfold Ops.Arith.pushResult
  try dsimp only
  split
  · intro h; cases h
  · rename_i hc
    intro h
    rw [pushElem_ok env st st' _ h]
    refine ⟨rfl, fun hb hg => ?_⟩
    simp only [hb, hg, Bool.true_and, decide_eq_true_eq] at hc
    omega

/-- **R6b (the boolean shape).** *What it says:* `pushBool` leaves `[0x01]` for true and `[]` for false on
top: `OP_WITHIN`'s push, `vchTrue` or `vchFalse` (`interpreter.cpp:402–403`, `1396`); `within` and its
compiled copy are `pushBool`'s only callers. The comparisons and the unary family's booleans leave the same
two byte strings by another road, an `int64` `1` or `0` (`script_num.h:65–69`) pushed through
`pushResult`, which this theorem does not carry. -/
theorem pushBool_shape (env : Env) (st st' : State) (b : Bool) (h : Ops.Arith.pushBool env st b = .ok st') :
    st'.stack = (if b then [1] else []) :: st.stack := by
  unfold Ops.Arith.pushBool at h
  rw [(pushResult_ok env st st' _ false h).1]
  cases b
  · show encode 0 :: st.stack = [] :: st.stack
    rfl
  · show encode 1 :: st.stack = [1] :: st.stack
    rw [show encode 1 = [1] by decide]

end BsvScript.Properties
