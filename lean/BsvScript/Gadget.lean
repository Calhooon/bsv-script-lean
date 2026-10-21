import BsvScript.Machine
/-!
# BsvScript.Gadget: the gadget-level API, "this script computes this spec" (#35, 35a)

`docs/DESIGN.md` §12.4. A layer-4 consumer (a sibling's emitted verifier) is a long script built
from gadgets; this module states one gadget's effect on the machine state and composes gadgets by
concatenation, over the spec's own loop (`Machine.loop`, `interpreter.cpp:388–1833`):

* `run exec env g tail st`: the loop over the fragment `g` followed by `tail`, without the
  end-of-script test (`1828–1830`); only `OP_CODESEPARATOR` reads `tail` (`1445–1448`);
* `loop_eq_run`: `Machine.loop` is `run` with an empty tail followed by the end test;
* `framed g`: every instruction of `g` parses inside `g`; `run_append`: a framed fragment followed
  by another runs as the first, then, at its end, the second;
* `Triple exec env P g Q` with `Triple.seq` and `Triple.conseq`: the statement a consumer proves
  per gadget, and its composition.

Written on 2026-09-29 as the companion of
`docs/records/20260929-014620-gadget-api-35-s2.md`, compiled against `main` there; applied to the
tree by S1 under its own tag (the file is S1's glob by `docs/OWNERS`; RULES-TREE (32)), unchanged but
for this paragraph and the `#print axioms` lines, which stand on `lean/AxiomCheck.lean`.
-/

set_option autoImplicit false

namespace BsvScript.Gadget
open BsvScript.Params BsvScript.Numbers BsvScript.Machine

/-- The outcome of a fragment run inside a larger script. -/
inductive GOut where
  /-- the fragment ran to its end; the script goes on in this state -/
  | next (st : State)
  /-- a top-level `OP_RETURN` after Genesis ended the whole script successfully (`858–861`) -/
  | stop (st : State)
  | err (e : ScriptError) (st : State)
  /-- the reference is undefined on the input (`docs/DESIGN.md` §1.2, Q7) -/
  | undefined (family : String) (st : State)
  | unimpl (op : Nat) (st : State)

/-- Sequencing: on `next`, go on with `f`; any other outcome ends the script. -/
def GOut.andThen : GOut → (State → GOut) → GOut
  | .next st, f => f st
  | o, _ => o

/-- The loop (`Machine.loop`) over the fragment `g` followed by `tail`, without the end-of-script
test: each step is `loop`'s, the push data parsed inside `g`, the rest of the whole script
(`rest ++ tail`) handed to the step for `OP_CODESEPARATOR` (`1445–1448`). -/
def run (exec : OpExec) (env : Env) : (g : Bytes) → (tail : Bytes) → State → GOut
  | [], _, st => .next st
  | op :: rest, tail, st =>
    match getOpTail op rest with
    | none => .err .badOpcode st
    | some (data, k) =>
      if !env.utxoAfterGenesis && data.length > Consensus.maxScriptElementSizeBeforeGenesis then .err .pushSize st
      else
        let fExec := st.cond.isActive && (!st.nonTopLevelReturn || op == Op.OP_RETURN)
        let st := if op > Op.OP_16 then { st with opCount := st.opCount + 1 } else st
        if op > Op.OP_16 && st.opCount > env.params.limits.maxOpsPerScript then .err .opCount st
        else if isOpcodeDisabled op env.utxoEra && (!env.utxoAfterGenesis || fExec) then .err .disabledOpcode st
        else
          match execStep exec env op data (rest ++ tail) k fExec st with
          | .fail e => .err e st
          | .unimpl o => .unimpl o st
          | .undefined f => .undefined f st
          | .done => .stop st
          | .cont st' =>
            if !env.utxoAfterGenesis && st'.stack.length + st'.alt.length > Consensus.maxStackElementsBeforeGenesis then
              .err .stackSize st'
            else run exec env (rest.drop k) tail st'
termination_by g => g.length
decreasing_by all_goals simp [List.length_drop]

/-- The end-of-script reading of a fragment's outcome (`loop`'s `[]` case, `1828–1830`). -/
def GOut.toLoop : GOut → Outcome × State
  | .next st => if st.cond.empty then (.ok, st) else (.err .unbalancedConditional, st)
  | .stop st => (.ok, st)
  | .err e st => (.err e, st)
  | .undefined f st => (.undefinedInReference f, st)
  | .unimpl o st => (.unimplemented o, st)

/-- **The API runs the semantics' own loop.** `Machine.loop` on a whole script is `run` with an
empty tail, read at the end. *What it assumes:* nothing. *Why it matters:* a consumer's statements
about `run` are statements about the spec's execution, never about a second machine. -/
theorem loop_eq_run (exec : OpExec) (env : Env) :
    ∀ (s : Bytes) (st : State), loop exec env s st = (run exec env s [] st).toLoop
  | [], st => by rw [loop.eq_1, run.eq_1]; rfl
  | op :: rest, st => by
    rw [loop.eq_2, run.eq_2, List.append_nil]
    rcases hp : getOpTail op rest with _ | ⟨data, k⟩
    · rfl
    · simp only
      split_ifs <;> try rfl
      all_goals (split <;> rename_i heq <;> simp only [heq, GOut.toLoop] <;> (try split_ifs) <;>
        first | rfl | exact loop_eq_run exec env (rest.drop k) _)
termination_by s => s.length
decreasing_by all_goals (simp only [List.length_drop, List.length_cons]; omega)

/-- The instruction walk of `g` ends at its last byte: every push's data lies inside `g`. -/
def framed : Bytes → Bool
  | [] => true
  | op :: rest =>
    match getOpTail op rest with
    | none => false
    | some (_, k) => framed (rest.drop k)
termination_by g => g.length
decreasing_by simp [List.length_drop]

/-- A parse inside a prefix is the parse inside the whole: `GetOp2` reads only the bytes it
consumes (`script.h:165–200`). -/
theorem getOpTail_append {op : Nat} {rest t d : Bytes} {k : Nat}
    (h : getOpTail op rest = some (d, k)) : getOpTail op (rest ++ t) = some (d, k) ∧ k ≤ rest.length := by
  unfold getOpTail at h ⊢
  by_cases hp : op ≤ Op.OP_PUSHDATA4
  · simp only [hp, ↓reduceIte] at h ⊢
    by_cases h1 : op < Op.OP_PUSHDATA1
    · simp only [h1, ↓reduceIte, List.drop_zero, Nat.zero_add] at h ⊢
      by_cases hl : rest.length < op
      · simp [hl] at h
      · simp only [hl, ↓reduceIte, Option.some.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl⟩ := h
        have hl' : ¬ (rest ++ t).length < op := by simp only [List.length_append]; omega
        simp only [hl', ↓reduceIte, List.take_append_of_le_length (by omega : op ≤ rest.length)]
        exact ⟨by simp, by omega⟩
    · simp only [h1, ↓reduceIte] at h ⊢
      by_cases h2 : op = Op.OP_PUSHDATA1
      · simp only [h2, ↓reduceIte] at h ⊢
        rcases rest with _ | ⟨n, r⟩
        · simp at h
        · simp only [List.cons_append, List.drop_succ_cons, List.drop_zero, List.length_cons] at h ⊢
          by_cases hl : r.length < n
          · simp [hl] at h
          · simp only [hl, ↓reduceIte, Option.some.injEq, Prod.mk.injEq] at h
            obtain ⟨rfl, rfl⟩ := h
            have hl' : ¬ (r ++ t).length < n := by simp only [List.length_append]; omega
            simp only [hl', ↓reduceIte, List.take_append_of_le_length (by omega : n ≤ r.length)]
            exact ⟨by simp, by omega⟩
      · simp only [h2, ↓reduceIte] at h ⊢
        by_cases h3 : op = Op.OP_PUSHDATA2
        · simp only [h3, ↓reduceIte] at h ⊢
          rcases rest with _ | ⟨a, _ | ⟨b, r⟩⟩
          · simp at h
          · simp at h
          · simp only [List.cons_append, List.drop_succ_cons, List.drop_zero, List.length_cons] at h ⊢
            by_cases hl : r.length < a + 256 * b
            · simp [hl] at h
            · simp only [hl, ↓reduceIte, Option.some.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, rfl⟩ := h
              have hl' : ¬ (r ++ t).length < a + 256 * b := by simp only [List.length_append]; omega
              simp only [hl', ↓reduceIte, List.take_append_of_le_length (by omega : a + 256 * b ≤ r.length)]
              exact ⟨by simp, by omega⟩
        · simp only [h3, ↓reduceIte] at h ⊢
          rcases rest with _ | ⟨a, _ | ⟨b, _ | ⟨c, _ | ⟨e, r⟩⟩⟩⟩
          · simp at h
          · simp at h
          · simp at h
          · simp at h
          · simp only [List.cons_append, List.drop_succ_cons, List.drop_zero, List.length_cons] at h ⊢
            by_cases hl : r.length < a + 256 * (b + 256 * (c + 256 * e))
            · simp [hl] at h
            · simp only [hl, ↓reduceIte, Option.some.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, rfl⟩ := h
              have hl' : ¬ (r ++ t).length < a + 256 * (b + 256 * (c + 256 * e)) := by simp only [List.length_append]; omega
              simp only [hl', ↓reduceIte,
                List.take_append_of_le_length (by omega : a + 256 * (b + 256 * (c + 256 * e)) ≤ r.length)]
              exact ⟨by simp, by omega⟩
  · simp only [hp, ↓reduceIte, Option.some.injEq, Prod.mk.injEq] at h ⊢
    obtain ⟨rfl, rfl⟩ := h
    exact ⟨by simp, Nat.zero_le _⟩

/-- **Composition.** A framed fragment `g` followed by `h` runs as `g` (its tail `h ++ t`) and then,
at `g`'s end, `h`. *What it assumes:* `g` is framed (a push of `g` that runs into `h` would read
`h`'s bytes as data). *Why it matters:* a gadget proved once composes by concatenation. -/
theorem run_append (exec : OpExec) (env : Env) (h t : Bytes) :
    ∀ (g : Bytes) (st : State), framed g = true →
      run exec env (g ++ h) t st = (run exec env g (h ++ t) st).andThen (run exec env h t)
  | [], st, _ => by rw [List.nil_append, run.eq_1]; rfl
  | op :: rest, st, hf => by
    rw [framed.eq_2] at hf
    rcases hp : getOpTail op rest with _ | ⟨data, k⟩
    · rw [hp] at hf; simp at hf
    · rw [hp] at hf
      simp only at hf
      obtain ⟨hpa, hk⟩ := getOpTail_append (t := h) hp
      rw [List.cons_append, run.eq_2, run.eq_2, hpa, hp, List.append_assoc]
      simp only
      split_ifs <;> try rfl
      all_goals (split <;> rename_i heq <;> simp only [heq, GOut.andThen] <;> (try split_ifs) <;>
        first | rfl | (rw [List.drop_append_of_le_length hk]; exact run_append exec env h t (rest.drop k) _ hf))
termination_by g => g.length
decreasing_by all_goals (simp only [List.length_drop, List.length_cons]; omega)

/-- **The statement a consumer proves per gadget.** From every state satisfying `P`, whatever
follows, the fragment `g` runs to its end in a state satisfying `Q`. -/
def Triple (exec : OpExec) (env : Env) (P : State → Prop) (g : Bytes) (Q : State → Prop) : Prop :=
  ∀ st tail, P st → ∃ st', run exec env g tail st = .next st' ∧ Q st'

/-- **Sequential composition.** *What it assumes:* the first fragment is framed. *Why it matters:*
the whole emitted script's claim is the chain of its gadgets' claims. -/
theorem Triple.seq {exec : OpExec} {env : Env} {P Q R : State → Prop} {g h : Bytes}
    (hg : framed g = true) (h₁ : Triple exec env P g Q) (h₂ : Triple exec env Q h R) :
    Triple exec env P (g ++ h) R := by
  intro st t hP
  obtain ⟨st₁, hr₁, hQ⟩ := h₁ st (h ++ t) hP
  obtain ⟨st₂, hr₂, hR⟩ := h₂ st₁ t hQ
  refine ⟨st₂, ?_, hR⟩
  rw [run_append exec env h t g st hg, hr₁]
  exact hr₂

/-- **Consequence.** A stronger precondition and a weaker postcondition keep a triple. -/
theorem Triple.conseq {exec : OpExec} {env : Env} {P P' Q Q' : State → Prop} {g : Bytes}
    (hP : ∀ st, P' st → P st) (hQ : ∀ st, Q st → Q' st) (h : Triple exec env P g Q) :
    Triple exec env P' g Q' := by
  intro st t hP'
  obtain ⟨st', hr, hq⟩ := h st t (hP st hP')
  exact ⟨st', hr, hQ st' hq⟩

end BsvScript.Gadget
