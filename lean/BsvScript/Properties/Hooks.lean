import BsvScript.Properties.Widths
/-!
# BsvScript.Properties.Hooks

The discharge of the two hook hypotheses of `BsvScript.Properties.Resources` for every family's `exec`
(#25, 2026-09-27): `HookOpCount` (a family's answer from a state within
the op limit is within it) and `HookMem` (a family's answer keeps the memory counter exact) hold for
`Eval.opExec`, so the op-count invariant R2a and the accounting invariant R3b hold for the evaluator's
own loop with no hook hypothesis left (`loop_opCount_le_opExec`, `loop_memInv_opExec`). Each keeps its
start condition, the op count within the limit and the counter exact; the locking phase after an
unlocking script that left elements on its alt stack does not start exact (H5).

Every family moves only the two stacks and the counter, through the machine's primitives (`pushElem`,
`popElem`, `Ops.Stack.swapTop`, `eraseTop`, `insertTop`, `toAlt`, `fromAlt`), each of which leaves the op
count as it was and keeps the invariant (`Resources`, R3a): a family step is a `Frame`. The one family
step that charges the op count is the multisig's key count (`1534–1536`), refused above the limit
before anything else moves (`checkMultiSigOp_opCount`).

Bare line numbers are `src/script/interpreter.cpp` at the pin (`docs/PROVENANCE.md`).
-/

namespace BsvScript.Properties
open BsvScript.Params BsvScript.Machine BsvScript.Numbers

/-- A family step's frame: the op count as it was, the memory invariant kept, the scriptCode's start `codeSep`
as it was (#149: only the loop's own separator writes it, `1445–1448`). -/
def Frame (st st' : State) : Prop :=
  st'.opCount = st.opCount ∧ (memInv st → memInv st') ∧ st'.codeSep = st.codeSep

/-- The empty step is a frame. -/
theorem Frame.refl (st : State) : Frame st st := ⟨rfl, id, rfl⟩

/-- Two frames compose. -/
theorem Frame.trans {a b c : State} (h1 : Frame a b) (h2 : Frame b c) : Frame a c :=
  ⟨h2.1.trans h1.1, fun h => h2.2.1 (h1.2.1 h), h2.2.2.trans h1.2.2⟩

/-- A pop is a frame (`limitedstack.cpp:211–219`). -/
theorem popElem_frame {st st' : State} {x : Bytes} (h : popElem st = .ok (x, st')) : Frame st st' := by
  refine ⟨?_, fun hi => popElem_memInv st st' x hi h, ?_⟩ <;>
  · unfold popElem at h
    split at h
    · cases h
    · cases h; rfl

/-- A pop's result, explicitly: the top removed, the counter shrunk by its weight (`limitedstack.cpp:211–219`). -/
theorem popElem_ok (st st' : State) (x : Bytes) (h : popElem st = .ok (x, st')) :
    ∃ rest, st.stack = x :: rest ∧
      st' = { st with stack := rest, memUsed := st.memUsed - (x.length + elementOverhead) } := by
  unfold popElem at h
  split at h
  · cases h
  · rename_i y ys hs
    cases h
    exact ⟨ys, hs, rfl⟩

/-- A push is a frame (`limitedstack.h:163–173`). -/
theorem pushElem_frame {env : Env} {st st' : State} {x : Bytes} (h : pushElem env st x = .ok st') : Frame st st' :=
  ⟨pushElem_opCount env st st' x h, fun hi => pushElem_memInv env st st' x hi h, by rw [pushElem_ok env st st' x h]⟩

/-- A number push (`pushCount`) is a frame. -/
theorem pushCount_frame {env : Env} {st st' : State} {n : Nat} (h : Ops.Stack.pushCount env st n = .ok st') :
    Frame st st' := by
  revert h
  unfold Ops.Stack.pushCount
  try dsimp only
  split
  · intro h; cases h
  · exact pushElem_frame

/-- A result push (`pushResult`) is a frame. -/
theorem pushResult_frame {env : Env} {st st' : State} {v : Int} {b : Bool}
    (h : Ops.Arith.pushResult env st v b = .ok st') : Frame st st' := by
  revert h
  unfold Ops.Arith.pushResult
  try dsimp only
  split
  · intro h; cases h
  · exact pushElem_frame

/-- A boolean push is a frame. -/
theorem pushBool_frame {env : Env} {st st' : State} {b : Bool} (h : Ops.Arith.pushBool env st b = .ok st') :
    Frame st st' :=
  pushResult_frame h

/-- A swap below the top is a frame (`limitedstack.cpp:285–288`). -/
theorem swapTop_frame {st : State} {i j : Nat} (hi : i < st.stack.length) (hj : j < st.stack.length) :
    Frame st (Ops.Stack.swapTop st i j) :=
  ⟨rfl, fun h => swapTop_memInv st i j hi hj h, rfl⟩

/-- An erase below the top is a frame (`limitedstack.cpp:260–267`). -/
theorem eraseTop_frame {st : State} {k : Nat} (hk : k < st.stack.length) : Frame st (Ops.Stack.eraseTop st k) :=
  ⟨rfl, fun h => eraseTop_memInv st k hk h, rfl⟩

/-- An insert below the top is a frame (`limitedstack.cpp:269–283`). -/
theorem insertTop_frame {env : Env} {st st' : State} {k : Nat} {x : Bytes} (hk : k ≤ st.stack.length)
    (h : Ops.Stack.insertTop env st k x = .ok st') : Frame st st' := by
  refine ⟨?_, fun hi => insertTop_memInv env st st' k x hk hi h, ?_⟩ <;>
  · revert h
    unfold Ops.Stack.insertTop
    try dsimp only
    split
    · intro h; cases h
    · intro h; cases h; rfl

/-- The two alt-stack moves are frames (`876–888`). -/
theorem toAlt_frame {st st' : State} (h : Ops.Stack.toAlt st = .ok st') : Frame st st' := by
  refine ⟨?_, fun hi => toAlt_memInv st st' hi h, ?_⟩ <;>
  · unfold Ops.Stack.toAlt Ops.Stack.need at h
    cases hs : st.stack with
    | nil => simp [hs, bind, Except.bind] at h
    | cons x rest =>
      simp [hs, bind, Except.bind, pure, Except.pure] at h
      subst h; rfl

/-- The move back from the alt stack is a frame. -/
theorem fromAlt_frame {st st' : State} (h : Ops.Stack.fromAlt st = .ok st') : Frame st st' := by
  refine ⟨?_, fun hi => fromAlt_memInv st st' hi h, ?_⟩ <;>
  · unfold Ops.Stack.fromAlt at h
    cases hs : st.alt with
    | nil => simp [hs, throw, throwThe, MonadExceptOf.throw] at h
    | cons x rest =>
      simp [hs, pure, Except.pure] at h
      subst h; rfl

/-! ## The splice family -/

/-- `OP_CAT` is a frame. -/
theorem cat_frame {env : Env} {st st' : State} (h : Ops.Splice.cat env st = .ok st') : Frame st st' := by
  unfold Ops.Splice.cat at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · split_ifs at h
    split at h
    · cases h
    · rename_i p1 hp1
      split at h
      · cases h
      · rename_i p2 hp2
        exact (popElem_frame hp1).trans ((popElem_frame hp2).trans (pushElem_frame h))

/-- `OP_SPLIT` is a frame. -/
theorem split_frame {env : Env} {st st' : State} (h : Ops.Splice.split env st = .ok st') : Frame st st' := by
  unfold Ops.Splice.split at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · split at h
    · cases h
    · split_ifs at h
      split at h
      · cases h
      · rename_i p1 hp1
        split at h
        · cases h
        · rename_i p2 hp2
          split at h
          · cases h
          · rename_i s3 hp3
            exact (popElem_frame hp1).trans ((popElem_frame hp2).trans ((pushElem_frame hp3).trans (pushElem_frame h)))

/-- `OP_NUM2BIN` is a frame. -/
theorem num2binOp_frame {env : Env} {st st' : State} (h : Ops.Splice.num2binOp env st = .ok st') : Frame st st' := by
  unfold Ops.Splice.num2binOp at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · split at h
    · cases h
    · split_ifs at h
      split at h
      · cases h
      · rename_i p1 hp1
        split at h
        · cases h
        · rename_i p2 hp2
          split_ifs at h
          split at h
          · cases h
          · exact (popElem_frame hp1).trans ((popElem_frame hp2).trans (pushElem_frame h))

/-- `OP_BIN2NUM` is a frame. -/
theorem bin2num_frame {env : Env} {st st' : State} (h : Ops.Splice.bin2num env st = .ok st') : Frame st st' := by
  unfold Ops.Splice.bin2num at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · split at h
    · cases h
    · rename_i p1 hp1
      split_ifs at h
      exact (popElem_frame hp1).trans (pushElem_frame h)

/-! ## The arithmetic family -/

/-- A unary arithmetic opcode is a frame. -/
theorem unary_frame {env : Env} {op : Nat} {st st' : State} (h : Ops.Arith.unary env op st = .ok st') :
    Frame st st' := by
  unfold Ops.Arith.unary at h
  simp only [bind, Except.bind] at h
  split at h
  · simp [throw, throwThe, MonadExceptOf.throw] at h
  · split at h
    · cases h
    · rename_i p1 hp1
      split at h
      · cases h
      · exact (popElem_frame hp1).trans (pushResult_frame h)

/-- A binary arithmetic opcode is a frame, `OP_NUMEQUALVERIFY`'s pop included. -/
theorem binary_frame {env : Env} {op : Nat} {st st' : State} (h : Ops.Arith.binary env op st = .ok st') :
    Frame st st' := by
  unfold Ops.Arith.binary at h
  simp only [bind, Except.bind] at h
  split at h
  · simp [throw, throwThe, MonadExceptOf.throw] at h
  · split at h
    · cases h
    · rename_i p1 hp1
      split at h
      · cases h
      · rename_i p2 hp2
        split at h
        · cases h
        · split at h
          · cases h
          · split at h
            · cases h
            · split at h
              · cases h
              · rename_i s4 hp4
                have f4 := (popElem_frame hp1).trans ((popElem_frame hp2).trans (pushResult_frame hp4))
                split at h
                · split at h
                  · split at h
                    · rename_i x s5 hp5
                      simp only [pure, Except.pure, Except.ok.injEq] at h
                      subst h
                      exact f4.trans (popElem_frame hp5)
                    · simp [throw, throwThe, MonadExceptOf.throw] at h
                  · simp [throw, throwThe, MonadExceptOf.throw] at h
                · simp only [pure, Except.pure, Except.ok.injEq] at h
                  subst h
                  exact f4

/-- `OP_WITHIN` is a frame. -/
theorem within_frame {env : Env} {st st' : State} (h : Ops.Arith.within env st = .ok st') : Frame st st' := by
  unfold Ops.Arith.within at h
  simp only [bind, Except.bind] at h
  split at h
  · simp [throw, throwThe, MonadExceptOf.throw] at h
  · split at h
    · cases h
    · rename_i p1 hp1
      split at h
      · cases h
      · rename_i p2 hp2
        split at h
        · cases h
        · rename_i p3 hp3
          split at h
          · cases h
          · split at h
            · cases h
            · split at h
              · cases h
              · exact (popElem_frame hp1).trans ((popElem_frame hp2).trans ((popElem_frame hp3).trans (pushBool_frame h)))

/-! ## The bitwise family -/

/-- `OP_AND`/`OP_OR`/`OP_XOR` are frames. -/
theorem bitwise2_frame {env : Env} {op : Nat} {st st' : State} (h : Ops.Bitwise.bitwise2 env op st = .ok st') :
    Frame st st' := by
  unfold Ops.Bitwise.bitwise2 at h
  simp only [bind, Except.bind] at h
  split at h
  · simp [throw, throwThe, MonadExceptOf.throw] at h
  · split at h
    · cases h
    · rename_i p1 hp1
      split at h
      · cases h
      · rename_i p2 hp2
        split at h
        · simp [throw, throwThe, MonadExceptOf.throw] at h
        · exact (popElem_frame hp1).trans ((popElem_frame hp2).trans (pushElem_frame h))

/-- `OP_INVERT` is a frame. -/
theorem invert_frame {env : Env} {st st' : State} (h : Ops.Bitwise.invert env st = .ok st') : Frame st st' := by
  unfold Ops.Bitwise.invert at h
  simp only [bind, Except.bind] at h
  split at h
  · simp [throw, throwThe, MonadExceptOf.throw] at h
  · split at h
    · cases h
    · rename_i p1 hp1
      exact (popElem_frame hp1).trans (pushElem_frame h)

/-- `OP_LSHIFT`/`OP_RSHIFT` are frames. -/
theorem shift_frame {env : Env} {op : Nat} {st st' : State} (h : Ops.Bitwise.shift env op st = .ok st') :
    Frame st st' := by
  unfold Ops.Bitwise.shift at h
  simp only [bind, Except.bind] at h
  split at h
  · simp [throw, throwThe, MonadExceptOf.throw] at h
  · split at h
    · cases h
    · rename_i p1 hp1
      split at h
      · cases h
      · rename_i p2 hp2
        split at h
        · cases h
        · split at h
          · simp [throw, throwThe, MonadExceptOf.throw] at h
          · exact (popElem_frame hp1).trans ((popElem_frame hp2).trans (pushElem_frame h))

/-- `OP_EQUAL`/`OP_EQUALVERIFY` are frames. -/
theorem equal_frame {env : Env} {op : Nat} {st st' : State} (h : Ops.Bitwise.equal env op st = .ok st') :
    Frame st st' := by
  unfold Ops.Bitwise.equal at h
  simp only [bind, Except.bind] at h
  split at h
  · simp [throw, throwThe, MonadExceptOf.throw] at h
  · split at h
    · cases h
    · rename_i p1 hp1
      split at h
      · cases h
      · rename_i p2 hp2
        split at h
        · cases h
        · rename_i s3 hp3
          have f3 := (popElem_frame hp1).trans ((popElem_frame hp2).trans (pushElem_frame hp3))
          split at h
          · split at h
            · split at h
              · rename_i x s4 hp4
                simp only [pure, Except.pure, Except.ok.injEq] at h
                subst h
                exact f3.trans (popElem_frame hp4)
              · simp [throw, throwThe, MonadExceptOf.throw] at h
            · simp [throw, throwThe, MonadExceptOf.throw] at h
          · simp only [pure, Except.pure, Except.ok.injEq] at h
            subst h
            exact f3

/-! ## The stack family -/

/-- The `then` branch of a decided `if` (the core lemma under a name both toolchains carry: `if_pos` at
v4.33.0, `ite_eq_left` at v4.34.0). -/
theorem ite_pos_of {c : Prop} {h : Decidable c} (hc : c) {α : Sort _} {t e : α} : (@ite α c h t e) = t := by
  cases h with
  | isTrue _ => rfl
  | isFalse hn => exact absurd hc hn

/-- The `else` branch of a decided `if` (`if_neg` at v4.33.0, `ite_eq_right` at v4.34.0). -/
theorem ite_neg_of {c : Prop} {h : Decidable c} (hnc : ¬c) {α : Sort _} {t e : α} : (@ite α c h t e) = e := by
  cases h with
  | isTrue hp => exact absurd hp hnc
  | isFalse _ => rfl

/-- `need st n` succeeds exactly when the stack holds at least `n` elements. -/
theorem need_ok_iff (st : State) (n : Nat) (u : Unit) : Ops.Stack.need st n = .ok u ↔ n ≤ st.stack.length := by
  unfold Ops.Stack.need
  split <;> simp_all

/-- Every stack opcode is a frame (`876–1064`): the moves, the copies, the drops, the swaps and rotations,
`OP_PICK`/`OP_ROLL`, `OP_TUCK`, `OP_DEPTH`, `OP_SIZE`. -/
theorem execStack_frame {env : Env} {op : Nat} {st st' : State} (h : Ops.Stack.execStack env op st = .ok st') :
    Frame st st' := by
  have hsw := Ops.Stack.swapTop_length
  unfold Ops.Stack.execStack at h
  by_cases c0 : op = Op.OP_TOALTSTACK
  · rw [ite_pos_of c0] at h
    exact toAlt_frame h
  rw [ite_neg_of c0] at h
  by_cases c1 : op = Op.OP_FROMALTSTACK
  · rw [ite_pos_of c1] at h
    exact fromAlt_frame h
  rw [ite_neg_of c1] at h
  by_cases c2 : op = Op.OP_2DROP
  · rw [ite_pos_of c2] at h
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · split at h
      · cases h
      · rename_i p1 hp1
        split at h
        · cases h
        · rename_i p2 hp2
          simp only [pure, Except.pure, Except.ok.injEq] at h
          subst h
          exact (popElem_frame hp1).trans (popElem_frame hp2)
  rw [ite_neg_of c2] at h
  by_cases c3 : op = Op.OP_2DUP
  · rw [ite_pos_of c3] at h
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · split at h
      · cases h
      · rename_i s1 hp1
        exact (pushElem_frame hp1).trans (pushElem_frame h)
  rw [ite_neg_of c3] at h
  by_cases c4 : op = Op.OP_3DUP
  · rw [ite_pos_of c4] at h
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · split at h
      · cases h
      · rename_i s1 hp1
        split at h
        · cases h
        · rename_i s2 hp2
          exact (pushElem_frame hp1).trans ((pushElem_frame hp2).trans (pushElem_frame h))
  rw [ite_neg_of c4] at h
  by_cases c5 : op = Op.OP_2OVER
  · rw [ite_pos_of c5] at h
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · split at h
      · cases h
      · rename_i s1 hp1
        exact (pushElem_frame hp1).trans (pushElem_frame h)
  rw [ite_neg_of c5] at h
  by_cases c6 : op = Op.OP_2ROT
  · rw [ite_pos_of c6] at h
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · rename_i u hn
      have hl := (need_ok_iff _ _ _).mp hn
      simp only [pure, Except.pure, Except.ok.injEq] at h
      subst h
      exact (swapTop_frame (by omega) (by omega)).trans ((swapTop_frame (by rw [hsw]; omega) (by rw [hsw]; omega)).trans
        ((swapTop_frame (by rw [hsw, hsw]; omega) (by rw [hsw, hsw]; omega)).trans
          (swapTop_frame (by rw [hsw, hsw, hsw]; omega) (by rw [hsw, hsw, hsw]; omega))))
  rw [ite_neg_of c6] at h
  by_cases c7 : op = Op.OP_2SWAP
  · rw [ite_pos_of c7] at h
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · rename_i u hn
      have hl := (need_ok_iff _ _ _).mp hn
      simp only [pure, Except.pure, Except.ok.injEq] at h
      subst h
      exact (swapTop_frame (by omega) (by omega)).trans (swapTop_frame (by rw [hsw]; omega) (by rw [hsw]; omega))
  rw [ite_neg_of c7] at h
  by_cases c8 : op = Op.OP_IFDUP
  · rw [ite_pos_of c8] at h
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · split at h
      · exact pushElem_frame h
      · simp only [pure, Except.pure, Except.ok.injEq] at h
        subst h
        exact Frame.refl _
  rw [ite_neg_of c8] at h
  by_cases c9 : op = Op.OP_DEPTH
  · rw [ite_pos_of c9] at h
    exact pushCount_frame h
  rw [ite_neg_of c9] at h
  by_cases c10 : op = Op.OP_DROP
  · rw [ite_pos_of c10] at h
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · split at h
      · cases h
      · rename_i p1 hp1
        simp only [pure, Except.pure, Except.ok.injEq] at h
        subst h
        exact popElem_frame hp1
  rw [ite_neg_of c10] at h
  by_cases c11 : op = Op.OP_DUP
  · rw [ite_pos_of c11] at h
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · exact pushElem_frame h
  rw [ite_neg_of c11] at h
  by_cases c12 : op = Op.OP_NIP
  · rw [ite_pos_of c12] at h
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · rename_i u hn
      have hl := (need_ok_iff _ _ _).mp hn
      simp only [pure, Except.pure, Except.ok.injEq] at h
      subst h
      exact eraseTop_frame (by omega)
  rw [ite_neg_of c12] at h
  by_cases c13 : op = Op.OP_OVER
  · rw [ite_pos_of c13] at h
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · exact pushElem_frame h
  rw [ite_neg_of c13] at h
  by_cases c14 : (op = Op.OP_PICK || op = Op.OP_ROLL) = true
  · rw [ite_pos_of c14] at h
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · split at h
      · cases h
      · rename_i p1 hp1
        split at h
        · cases h
        · rename_i n hn
          split at h
          · simp [throw, throwThe, MonadExceptOf.throw] at h
          · rename_i hk
            simp only [Bool.or_eq_true, decide_eq_true_eq, not_or, not_le, not_lt] at hk
            split at h
            · exact (popElem_frame hp1).trans ((eraseTop_frame (by omega)).trans (pushElem_frame h))
            · exact (popElem_frame hp1).trans (pushElem_frame h)
  rw [ite_neg_of c14] at h
  by_cases c15 : op = Op.OP_ROT
  · rw [ite_pos_of c15] at h
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · rename_i u hn
      have hl := (need_ok_iff _ _ _).mp hn
      simp only [pure, Except.pure, Except.ok.injEq] at h
      subst h
      exact (swapTop_frame (by omega) (by omega)).trans (swapTop_frame (by rw [hsw]; omega) (by rw [hsw]; omega))
  rw [ite_neg_of c15] at h
  by_cases c16 : op = Op.OP_SWAP
  · rw [ite_pos_of c16] at h
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · rename_i u hn
      have hl := (need_ok_iff _ _ _).mp hn
      simp only [pure, Except.pure, Except.ok.injEq] at h
      subst h
      exact swapTop_frame (by omega) (by omega)
  rw [ite_neg_of c16] at h
  by_cases c17 : op = Op.OP_TUCK
  · rw [ite_pos_of c17] at h
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · rename_i u hn
      have hl := (need_ok_iff _ _ _).mp hn
      exact insertTop_frame (by omega) h
  rw [ite_neg_of c17] at h
  -- OP_SIZE
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · exact pushCount_frame h

/-! ## The expansion family -/

/-- A family's `Except` answer read as a hook answer: `.ok` exactly when the `Except` is. -/
theorem ofExcept_ok {e : Except ScriptError State} {st' : State} (h : HookR.ofExcept e = .ok st') : e = .ok st' := by
  cases e with
  | error x => simp [HookR.ofExcept] at h
  | ok s => simp only [HookR.ofExcept, HookR.ok.injEq] at h; rw [h]

/-- Two pops and a push are a frame (the expansion opcodes' result write). -/
theorem popPopPush_frame {env : Env} {st st' : State} {x : Bytes}
    (h : (do
      let (_, st) ← popElem st
      let (_, st) ← popElem st
      pushElem env st x : Except ScriptError State) = .ok st') : Frame st st' := by
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · rename_i p1 hp1
    split at h
    · cases h
    · rename_i p2 hp2
      exact (popElem_frame hp1).trans ((popElem_frame hp2).trans (pushElem_frame h))

/-- The pre-Chronicle NOP is a frame (the state untouched). -/
theorem nopOrDiscourage_frame {env : Env} {st st' : State} (h : Ops.Expansion.nopOrDiscourage env st = .ok st') :
    Frame st st' := by
  unfold Ops.Expansion.nopOrDiscourage at h
  split at h
  · cases h
  · cases h; exact Frame.refl _

/-- `OP_SUBSTR` is a frame. -/
theorem substr_frame {env : Env} {st st' : State} (h : Ops.Expansion.substr env st = .ok st') : Frame st st' := by
  unfold Ops.Expansion.substr at h
  split at h
  · cases h
  · split at h
    · cases h
    · split at h
      · cases h
      · simp only at h
        split at h
        · cases h
        · have h' := ofExcept_ok h
          simp only [bind, Except.bind] at h'
          split at h'
          · cases h'
          · rename_i p1 hp1
            split at h'
            · cases h'
            · rename_i p2 hp2
              split at h'
              · cases h'
              · rename_i p3 hp3
                exact (popElem_frame hp1).trans ((popElem_frame hp2).trans ((popElem_frame hp3).trans (pushElem_frame h')))

/-- `OP_LEFT` is a frame. -/
theorem left_frame {env : Env} {st st' : State} (h : Ops.Expansion.left env st = .ok st') : Frame st st' := by
  unfold Ops.Expansion.left at h
  split at h
  · cases h
  · split at h
    · cases h
    · simp only at h
      split at h
      · cases h
      · exact popPopPush_frame (ofExcept_ok h)

/-- `OP_RIGHT` is a frame. -/
theorem right_frame {env : Env} {st st' : State} (h : Ops.Expansion.right env st = .ok st') : Frame st st' := by
  unfold Ops.Expansion.right at h
  split at h
  · cases h
  · split at h
    · cases h
    · simp only at h
      split at h
      · cases h
      · exact popPopPush_frame (ofExcept_ok h)

/-- `OP_LSHIFTNUM` is a frame. -/
theorem lshiftnum_frame {env : Env} {st st' : State} (h : Ops.Expansion.lshiftnum env st = .ok st') : Frame st st' := by
  unfold Ops.Expansion.lshiftnum at h
  split at h
  · cases h
  · split at h
    · cases h
    · split at h
      · cases h
      · split at h
        · cases h
        · simp only at h
          split at h
          · cases h
          · split at h
            · cases h
            · split at h
              · cases h
              · exact popPopPush_frame (ofExcept_ok h)

/-- `OP_RSHIFTNUM` is a frame. -/
theorem rshiftnum_frame {env : Env} {st st' : State} (h : Ops.Expansion.rshiftnum env st = .ok st') : Frame st st' := by
  unfold Ops.Expansion.rshiftnum at h
  split at h
  · cases h
  · split at h
    · cases h
    · split at h
      · cases h
      · split at h
        · cases h
        · split at h
          · cases h
          · exact popPopPush_frame (ofExcept_ok h)

/-! ## The crypto family -/

/-- The hash opcodes are frames (`1402–1443`). -/
theorem hashOp_frame {env : Env} {op : Nat} {st st' : State} (h : Ops.Crypto.hashOp env op st = .ok st') :
    Frame st st' := by
  unfold Ops.Crypto.hashOp at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · split at h
    · cases h
    · rename_i p1 hp1
      exact (popElem_frame hp1).trans (pushElem_frame h)

/-- `OP_CHECKSIG`/`OP_CHECKSIGVERIFY` are frames (`1450–1508`). -/
theorem checkSigOp_frame {env : Env} {op : Nat} {st st' : State} (h : Ops.Crypto.checkSigOp env op st = .ok st') :
    Frame st st' := by
  unfold Ops.Crypto.checkSigOp at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · split at h
    · cases h
    · split at h
      · cases h
      · split at h
        · simp [throw, throwThe, MonadExceptOf.throw] at h
        · split at h
          · cases h
          · rename_i p1 hp1
            split at h
            · cases h
            · rename_i p2 hp2
              split at h
              · cases h
              · rename_i s3 hp3
                have f3 := (popElem_frame hp1).trans ((popElem_frame hp2).trans (pushElem_frame hp3))
                split at h
                · split at h
                  · split at h
                    · cases h
                    · rename_i p4 hp4
                      simp only [pure, Except.pure, Except.ok.injEq] at h
                      subst h
                      exact f3.trans (popElem_frame hp4)
                  · simp [throw, throwThe, MonadExceptOf.throw] at h
                · simp only [pure, Except.pure, Except.ok.injEq] at h
                  subst h
                  exact f3

/-- A loop whose every step is a frame is a frame (the `for` over `List.range` of the multisig's pops,
`1636–1653`). -/
theorem forIn_frame {α : Type} (l : List α) (f : α → State → Except ScriptError (ForInStep State))
    (hy : ∀ a s s', f a s = .ok (.yield s') → Frame s s') (hd : ∀ a s s', f a s = .ok (.done s') → Frame s s') :
    ∀ (init res : State), forIn l init f = .ok res → Frame init res := by
  induction l with
  | nil =>
    intro init res h
    simp only [List.forIn_nil, pure, Except.pure, Except.ok.injEq] at h
    subst h
    exact Frame.refl _
  | cons a rest ih =>
    intro init res h
    simp only [List.forIn_cons, bind, Except.bind] at h
    split at h
    · cases h
    · rename_i r hr
      cases r with
      | done b =>
        simp only [pure, Except.pure, Except.ok.injEq] at h
        subst h
        exact hd a init b hr
      | yield b =>
        exact (hy a init b hr).trans (ih b res h)

/-- **H1 (the multisig success case).** *What it says:* an `OP_CHECKMULTISIG`/`OP_CHECKMULTISIGVERIFY` that
succeeds read a key count `n` (`1517–1526`), charged it to the op count, which stays within
`MaxOpsPerScript` (`1534–1536`), and left the op count exactly `n` higher; every pop and push after the
charge keeps the memory invariant. *What it assumes:* the opcode succeeded. *Why it matters:* the key
count is the only charge a family makes to the op count, and the charge is refused before it can pass
the limit, so the op-count invariant holds across the crypto family (`HookOpCount`), and the multisig's
pops of its arguments (`1636–1653`), the dummy and the result keep the counter exact (`HookMem`); and
`codeSep` is as it was (#149). -/
theorem checkMultiSigOp_ok {env : Env} {op : Nat} {st st' : State}
    (h : Ops.Crypto.checkMultiSigOp env op st = .ok st') :
    ∃ n : Nat, Ops.Crypto.readCount env (Ops.Stack.topAt st 0) = .ok (n : Int) ∧
      st'.opCount = st.opCount + n ∧ st.opCount + n ≤ env.params.limits.maxOpsPerScript ∧
      (memInv st → memInv st') ∧ st'.codeSep = st.codeSep := by
  unfold Ops.Crypto.checkMultiSigOp at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · split at h
    · cases h
    · rename_i nK hnK
      by_cases c1 : nK < 0
      · rw [ite_pos_of c1] at h; exact absurd h (by intro hc; cases hc)
      rw [ite_neg_of c1] at h
      by_cases c2 : env.params.limits.maxPubKeysPerMultiSig < nK.toNat
      · rw [ite_pos_of c2] at h; exact absurd h (by intro hc; cases hc)
      rw [ite_neg_of c2] at h
      by_cases c3 : env.params.limits.maxOpsPerScript < st.opCount + nK.toNat
      · rw [ite_pos_of c3] at h; exact absurd h (by intro hc; cases hc)
      rw [ite_neg_of c3] at h
      -- from here the state is the charged one
      generalize hs1 : ({ st with opCount := st.opCount + nK.toNat } : State) = st1 at h
      have hmem1 : memInv st → memInv st1 := by intro hi; subst hs1; exact hi
      have hop1 : st1.opCount = st.opCount + nK.toNat := by subst hs1; rfl
      have hcs1 : st1.codeSep = st.codeSep := by subst hs1; rfl
      split at h
      · cases h
      · split at h
        · cases h
        · rename_i nS hnS
          by_cases c4 : nS < 0
          · rw [ite_pos_of c4] at h; exact absurd h (by intro hc; cases hc)
          rw [ite_neg_of c4] at h
          by_cases c5 : nK.toNat < nS.toNat
          · rw [ite_pos_of c5] at h; exact absurd h (by intro hc; cases hc)
          rw [ite_neg_of c5] at h
          split at h
          · cases h
          · split at h
            · cases h
            · rename_i b hb
              split at h
              · cases h
              · rename_i stm hloop
                have floop : Frame st1 stm := by
                  refine forIn_frame _ _ ?_ ?_ st1 stm hloop
                  · intro a s s' hs
                    split at hs
                    · exact absurd hs (by intro hc; cases hc)
                    · split at hs
                      · cases hs
                      · rename_i p hp
                        simp only [pure, Except.pure, Except.ok.injEq, ForInStep.yield.injEq] at hs
                        subst hs
                        exact popElem_frame hp
                  · intro a s s' hs
                    split at hs
                    · exact absurd hs (by intro hc; cases hc)
                    · split at hs
                      · cases hs
                      · simp [pure, Except.pure] at hs
                by_cases c6 : stm.stack.isEmpty = true
                · rw [ite_pos_of c6] at h; exact absurd h (by intro hc; cases hc)
                rw [ite_neg_of c6] at h
                by_cases c7 : (env.params.flags.nullDummy && !List.isEmpty (Ops.Stack.topAt stm 0) &&
                    enforceNonMalleability env.params.flags env.ctx.version) = true
                · rw [ite_pos_of c7] at h; exact absurd h (by intro hc; cases hc)
                rw [ite_neg_of c7] at h
                split at h
                · cases h
                · rename_i p5 hp5
                  split at h
                  · cases h
                  · rename_i s6 hp6
                    have f6 : Frame st1 s6 := floop.trans ((popElem_frame hp5).trans (pushElem_frame hp6))
                    have fin : Frame st1 st' := by
                      by_cases c8 : op = Op.OP_CHECKMULTISIGVERIFY
                      · rw [ite_pos_of c8] at h
                        by_cases c9 : b = true
                        · rw [ite_pos_of c9] at h
                          split at h
                          · cases h
                          · rename_i p7 hp7
                            simp only [pure, Except.pure, Except.ok.injEq] at h
                            subst h
                            exact f6.trans (popElem_frame hp7)
                        · rw [ite_neg_of c9] at h; exact absurd h (by intro hc; cases hc)
                      · rw [ite_neg_of c8] at h
                        simp only [pure, Except.pure, Except.ok.injEq] at h
                        subst h
                        exact f6
                    refine ⟨nK.toNat, ?_, ?_, by omega, fun hi => fin.2.1 (hmem1 hi), fin.2.2.trans hcs1⟩
                    · rw [Int.toNat_of_nonneg (by omega)]; exact hnK
                    · rw [fin.1, hop1]

/-! ## The families' hooks and the evaluator's -/

/-- A hook answer that keeps the two invariants the loop needs: the op count within the limit if it was,
the memory counter exact if it was; and `codeSep` as it was (#149). -/
def Good (env : Env) (st st' : State) : Prop :=
  (st.opCount ≤ env.params.limits.maxOpsPerScript → st'.opCount ≤ env.params.limits.maxOpsPerScript) ∧
    (memInv st → memInv st') ∧ st'.codeSep = st.codeSep

/-- A frame is good. -/
theorem Frame.good {env : Env} {st st' : State} (h : Frame st st') : Good env st st' :=
  ⟨fun h1 => by rw [h.1]; exact h1, h.2.1, h.2.2⟩

/-- A family answer `some (.ok st')` built from an `Except` step is that step's success. -/
theorem some_ofExcept_ok {e : Except ScriptError State} {st' : State}
    (h : some (HookR.ofExcept e) = some (.ok st')) : e = .ok st' :=
  ofExcept_ok (Option.some.inj h)

/-- The arithmetic family's hook is good. -/
theorem arith_exec_good {env : Env} {op : Nat} {data : Bytes} {st st' : State}
    (h : Ops.Arith.exec op data env st = some (.ok st')) : Good env st st' := by
  unfold Ops.Arith.exec at h
  split at h
  · exact (unary_frame (some_ofExcept_ok h)).good
  split at h
  · exact (binary_frame (some_ofExcept_ok h)).good
  split at h
  · exact (within_frame (some_ofExcept_ok h)).good
  · cases h

/-- The bitwise family's hook is good. -/
theorem bitwise_exec_good {env : Env} {op : Nat} {data : Bytes} {st st' : State}
    (h : Ops.Bitwise.exec op data env st = some (.ok st')) : Good env st st' := by
  unfold Ops.Bitwise.exec at h
  split at h
  · exact (bitwise2_frame (some_ofExcept_ok h)).good
  split at h
  · exact (invert_frame (some_ofExcept_ok h)).good
  split at h
  · exact (shift_frame (some_ofExcept_ok h)).good
  split at h
  · exact (equal_frame (some_ofExcept_ok h)).good
  · cases h

/-- The stack family's hook is good. -/
theorem stack_exec_good {env : Env} {op : Nat} {data : Bytes} {st st' : State}
    (h : Ops.Stack.exec op data env st = some (.ok st')) : Good env st st' := by
  unfold Ops.Stack.exec at h
  split at h
  · exact (execStack_frame (some_ofExcept_ok h)).good
  · cases h

/-- The splice family's hook is good. -/
theorem splice_exec_good {env : Env} {op : Nat} {data : Bytes} {st st' : State}
    (h : Ops.Splice.exec op data env st = some (.ok st')) : Good env st st' := by
  unfold Ops.Splice.exec at h
  split at h
  · exact (cat_frame (some_ofExcept_ok h)).good
  split at h
  · exact (split_frame (some_ofExcept_ok h)).good
  split at h
  · exact (num2binOp_frame (some_ofExcept_ok h)).good
  split at h
  · exact (bin2num_frame (some_ofExcept_ok h)).good
  · cases h

/-- The crypto family's hook is good: the hashes and the signature checks are frames, the multisig
charges its key count within the limit (H1). -/
theorem crypto_exec_good {env : Env} {op : Nat} {data : Bytes} {st st' : State}
    (h : Ops.Crypto.exec op data env st = some (.ok st')) : Good env st st' := by
  unfold Ops.Crypto.exec at h
  split at h
  · exact (hashOp_frame (some_ofExcept_ok h)).good
  split at h
  · exact (checkSigOp_frame (some_ofExcept_ok h)).good
  split at h
  · obtain ⟨n, -, hop, hle, hmem, hcs⟩ := checkMultiSigOp_ok (some_ofExcept_ok h)
    exact ⟨fun _ => by rw [hop]; exact hle, hmem, hcs⟩
  · cases h

/-- The expansion family's hook is good (before Chronicle a NOP, the state untouched). -/
theorem expansion_exec_good {env : Env} {op : Nat} {data : Bytes} {st st' : State}
    (h : Ops.Expansion.exec op data env st = some (.ok st')) : Good env st st' := by
  unfold Ops.Expansion.exec at h
  split at h
  · have h' := Option.some.inj h
    split at h'
    · exact (nopOrDiscourage_frame h').good
    split at h'
    · exact (substr_frame h').good
    split at h'
    · exact (left_frame h').good
    split at h'
    · exact (right_frame h').good
    split at h'
    · exact (lshiftnum_frame h').good
    · exact (rshiftnum_frame h').good
  · cases h

/-- The evaluator's hook is good: the family that answers keeps both invariants. -/
theorem opExec_good {env : Env} {op : Nat} {data : Bytes} {st st' : State}
    (h : Eval.opExec op data env st = some (.ok st')) : Good env st st' := by
  unfold Eval.opExec at h
  cases h1 : Ops.Arith.exec op data env st with
  | some r =>
    rw [h1] at h
    simp only [HOrElse.hOrElse, OrElse.orElse, Option.orElse] at h
    rw [h] at h1
    exact arith_exec_good h1
  | none =>
    rw [h1] at h
    cases h2 : Ops.Bitwise.exec op data env st with
    | some r =>
      rw [h2] at h
      simp only [HOrElse.hOrElse, OrElse.orElse, Option.orElse] at h
      rw [h] at h2
      exact bitwise_exec_good h2
    | none =>
      rw [h2] at h
      cases h3 : Ops.Stack.exec op data env st with
      | some r =>
        rw [h3] at h
        simp only [HOrElse.hOrElse, OrElse.orElse, Option.orElse] at h
        rw [h] at h3
        exact stack_exec_good h3
      | none =>
        rw [h3] at h
        cases h4 : Ops.Splice.exec op data env st with
        | some r =>
          rw [h4] at h
          simp only [HOrElse.hOrElse, OrElse.orElse, Option.orElse] at h
          rw [h] at h4
          exact splice_exec_good h4
        | none =>
          rw [h4] at h
          cases h5 : Ops.Crypto.exec op data env st with
          | some r =>
            rw [h5] at h
            simp only [HOrElse.hOrElse, OrElse.orElse, Option.orElse] at h
            rw [h] at h5
            exact crypto_exec_good h5
          | none =>
            rw [h5] at h
            simp only [HOrElse.hOrElse, OrElse.orElse, Option.orElse] at h
            exact expansion_exec_good h

/-- **H2 (`HookOpCount` discharged).** *What it says:* the evaluator's hook `Eval.opExec` answers, from a
state within the op limit, only states within it. *What it assumes:* nothing. *Why it matters:* the
hypothesis of R2a is met by the evaluator itself: no family moves the op count but the multisig, whose
charge is refused above the limit (H1, `1534–1536`). -/
theorem hookOpCount_opExec (env : Env) : HookOpCount Eval.opExec env :=
  fun _ _ _ _ hle h => (opExec_good h).1 hle

/-- **H3 (`HookMem` discharged).** *What it says:* the evaluator's hook keeps the memory counter exact.
*What it assumes:* nothing. *Why it matters:* the hypothesis of R3b is met by the evaluator itself: every
family moves the stacks through the counted primitives only (`limitedstack.cpp:194–302`). -/
theorem hookMem_opExec (env : Env) : HookMem Eval.opExec env :=
  fun _ _ _ _ hi h => (opExec_good h).2.1 hi

/-- **H4 (R2a for the evaluator).** *What it says:* the evaluator's loop, from a state within the op
limit, returns a state at most one over it, whatever the outcome. *What it assumes:* nothing. *Why it
matters:* `loop_opCount_le` with its hook hypothesis discharged (H2): the op-count bound of `466–467` is a
property of the spec's evaluator, not of an assumed hook. -/
theorem loop_opCount_le_opExec (env : Env) (s : Bytes) (st : State)
    (hle : st.opCount ≤ env.params.limits.maxOpsPerScript) :
    (loop Eval.opExec env s st).2.opCount ≤ env.params.limits.maxOpsPerScript + 1 :=
  loop_opCount_le Eval.opExec env (hookOpCount_opExec env) s.length s le_rfl st hle

/-- **H5 (R3b for the evaluator).** *What it says:* the evaluator's loop keeps the memory counter equal to
the weights of both stacks. *What it assumes:* the counter exact at the start. *Why it matters:*
`loop_memInv` with its hook hypothesis discharged (H3): the memory the limit compares
(`limitedstack.h:163–173`) is the memory the stacks hold at every step of a phase that starts exact. The
unlocking phase does (`verifyScript` starts it on an empty stack at 0); the locking phase does when the
unlocking script left its alt stack empty, and not otherwise: the counter keeps the weight of elements
left there when a phase ends (`1993–2005`, `Machine.State`), so the locking phase then starts above its
stacks' weight by theirs, where this theorem's hypothesis fails. -/
theorem loop_memInv_opExec (env : Env) (s : Bytes) (st : State) (hi : memInv st) :
    memInv (loop Eval.opExec env s st).2 :=
  loop_memInv Eval.opExec env (hookMem_opExec env) s.length s le_rfl st hi

/-! ## NULLFAIL and NULLDUMMY under the gate -/

/-- **H6 (NULLFAIL under the gate, `OP_CHECKSIG`).** *What it says:* when both encodings pass and the
signature check fails on a non-empty signature, `OP_CHECKSIG`/`OP_CHECKSIGVERIFY` refuses
`SCRIPT_ERR_SIG_NULLFAIL` under `SCRIPT_VERIFY_NULLFAIL` and the version gate. *What it assumes:* two
elements, both encodings accepted, the failed check, the flag, the non-empty signature, the gate.
*Why it matters:* a failed signature must be empty for the script to go on (`1491–1497`), so a failing
`OP_CHECKSIG` cannot be turned into a `false` by a non-empty signature where the gate is on (before
Chronicle for every version, after it for a version of at most 1, `34–44`), the malleability NULLFAIL
closes. -/
theorem checkSigOp_nullfail {env : Env} {op : Nat} {st : State} (hn : 2 ≤ st.stack.length)
    (hse : Ops.Crypto.checkSignatureEncoding env (Ops.Stack.topAt st 1) = .ok ())
    (hpe : Ops.Crypto.checkPubKeyEncoding env (Ops.Stack.topAt st 0) = .ok ())
    (hfail : env.ctx.checkSig (Ops.Stack.topAt st 1) (Ops.Stack.topAt st 0)
        (Sighash.cleanupScriptCode (Ops.Crypto.scriptCodeOf env st) (Ops.Stack.topAt st 1)
          env.params.flags.enableSighashForkid) env.params.flags.enableSighashForkid = false)
    (hnf : env.params.flags.nullFail = true) (hne : Ops.Stack.topAt st 1 ≠ [])
    (hg : enforceNonMalleability env.params.flags env.ctx.version = true) :
    Ops.Crypto.checkSigOp env op st = .error .sigNullfail := by
  have hneed : Ops.Stack.need st 2 = .ok () := (need_ok_iff _ _ _).mpr hn
  have hemp : (Ops.Stack.topAt st 1).isEmpty = false := by
    cases h : Ops.Stack.topAt st 1 with
    | nil => exact absurd h hne
    | cons _ _ => rfl
  unfold Ops.Crypto.checkSigOp
  simp only [bind, Except.bind, hneed, hse, hpe, hfail, hnf, hemp, hg, Bool.not_false, Bool.and_true, ite_true]
  rfl

/-- A loop of steps that each pop one element pops as many as the list is long (the multisig's argument
pops, `1636–1653`). -/
theorem forIn_drop {α : Type} (l : List α) (f : α → State → Except ScriptError (ForInStep State))
    (hy : ∀ a s s', f a s = .ok (.yield s') → s'.stack = s.stack.drop 1)
    (hd : ∀ a s s', f a s = .ok (.done s') → False) :
    ∀ (init res : State), forIn l init f = .ok res → res.stack = init.stack.drop l.length := by
  induction l with
  | nil =>
    intro init res h
    simp only [List.forIn_nil, pure, Except.pure, Except.ok.injEq] at h
    subst h
    rfl
  | cons a rest ih =>
    intro init res h
    simp only [List.forIn_cons, bind, Except.bind] at h
    split at h
    · cases h
    · rename_i r hr
      cases r with
      | done b => exact (hd a init b hr).elim
      | yield b =>
        rw [ih b res h, hy a init b hr, List.drop_drop, List.length_cons]
        congr 1
        omega

/-- **H7 (NULLDUMMY under the gate, `OP_CHECKMULTISIG`).** *What it says:* an `OP_CHECKMULTISIG`/
`OP_CHECKMULTISIGVERIFY` that succeeds under `SCRIPT_VERIFY_NULLDUMMY` and the version gate found the
element under its arguments empty: with `n` keys and `m` signatures read, the element `n + 2 + m` below
the top. *What it assumes:* the opcode succeeded, the flag, the gate. *Why it matters:* the extra element
the historical off-by-one pops (`1655–1672`: the comment on the bug, then the pop) is the malleability
NULLDUMMY closes where the flag is set. The flag is policy (the standard word only, `policy.h:182–189`;
never in the block word, `blockScriptFlags_policy_off`), so on the mempool path, where the gate is on, a
third party cannot vary it without the spend failing, while a block accepts a varied dummy (`1664` tests
the flag first). -/
theorem checkMultiSigOp_nulldummy {env : Env} {op : Nat} {st st' : State}
    (h : Ops.Crypto.checkMultiSigOp env op st = .ok st') (hnd : env.params.flags.nullDummy = true)
    (hg : enforceNonMalleability env.params.flags env.ctx.version = true) :
    ∃ n m : Nat, Ops.Crypto.readCount env (Ops.Stack.topAt st 0) = .ok (n : Int) ∧
      Ops.Crypto.readCount env (Ops.Stack.topAt st (n + 1)) = .ok (m : Int) ∧
      Ops.Stack.topAt st (n + 2 + m) = [] := by
  unfold Ops.Crypto.checkMultiSigOp at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · split at h
    · cases h
    · rename_i nK hnK
      by_cases c1 : nK < 0
      · rw [ite_pos_of c1] at h; exact absurd h (by intro hc; cases hc)
      rw [ite_neg_of c1] at h
      by_cases c2 : env.params.limits.maxPubKeysPerMultiSig < nK.toNat
      · rw [ite_pos_of c2] at h; exact absurd h (by intro hc; cases hc)
      rw [ite_neg_of c2] at h
      by_cases c3 : env.params.limits.maxOpsPerScript < st.opCount + nK.toNat
      · rw [ite_pos_of c3] at h; exact absurd h (by intro hc; cases hc)
      rw [ite_neg_of c3] at h
      split at h
      · cases h
      · split at h
        · cases h
        · rename_i nS hnS
          by_cases c4 : nS < 0
          · rw [ite_pos_of c4] at h; exact absurd h (by intro hc; cases hc)
          rw [ite_neg_of c4] at h
          by_cases c5 : nK.toNat < nS.toNat
          · rw [ite_pos_of c5] at h; exact absurd h (by intro hc; cases hc)
          rw [ite_neg_of c5] at h
          split at h
          · cases h
          · split at h
            · cases h
            · rename_i b hb
              split at h
              · cases h
              · rename_i stm hloop
                have hdrop : stm.stack = st.stack.drop (nK.toNat + 2 + nS.toNat) := by
                  have := forIn_drop _ _ ?_ ?_ _ stm hloop
                  · rw [this, List.length_range]
                  · intro a s s' hs
                    split at hs
                    · exact absurd hs (by intro hc; cases hc)
                    · split at hs
                      · cases hs
                      · rename_i p hp
                        simp only [pure, Except.pure, Except.ok.injEq, ForInStep.yield.injEq] at hs
                        subst hs
                        obtain ⟨rest, hsr, hst⟩ := popElem_ok s p.2 p.1 (by rw [hp])
                        rw [hst, hsr]
                        rfl
                  · intro a s s' hs
                    split at hs
                    · exact absurd hs (by intro hc; cases hc)
                    · split at hs
                      · cases hs
                      · simp [pure, Except.pure] at hs
                by_cases c6 : stm.stack.isEmpty = true
                · rw [ite_pos_of c6] at h; exact absurd h (by intro hc; cases hc)
                rw [ite_neg_of c6] at h
                by_cases c7 : (env.params.flags.nullDummy && !List.isEmpty (Ops.Stack.topAt stm 0) &&
                    enforceNonMalleability env.params.flags env.ctx.version) = true
                · rw [ite_pos_of c7] at h; exact absurd h (by intro hc; cases hc)
                simp only [hnd, hg, Bool.true_and, Bool.and_true, Bool.not_eq_eq_eq_not, Bool.not_true,
                  List.isEmpty_eq_false_iff, not_not] at c7
                refine ⟨nK.toNat, nS.toNat, ?_, ?_, ?_⟩
                · rw [Int.toNat_of_nonneg (by omega)]; exact hnK
                · rw [Int.toNat_of_nonneg (by omega)]; simpa [Ops.Stack.topAt] using hnS
                · have ht : Ops.Stack.topAt stm 0 = Ops.Stack.topAt st (nK.toNat + 2 + nS.toNat) := by
                    simp only [Ops.Stack.topAt, hdrop, List.getD_eq_getElem?_getD, List.getElem?_drop, Nat.add_zero]
                  rw [← ht]
                  simpa using c7

/-- A loop over `List.range' start n` whose every successful step found its guard false and popped one
element found the guard false at every element, the guard reading the element then on top: the
`k`-th below the initial top. -/
theorem forIn_rangeFrom_guard (P : Nat → Bytes → Bool) (f : Nat → State → Except ScriptError (ForInStep State))
    (hf : ∀ j s r, f j s = .ok r →
      P j (Ops.Stack.topAt s 0) = false ∧ ∃ x s', popElem s = .ok (x, s') ∧ r = .yield s') :
    ∀ (n start : Nat) (init res : State), forIn (List.range' start n) init f = .ok res →
      ∀ k < n, P (start + k) (Ops.Stack.topAt init k) = false := by
  intro n
  induction n with
  | zero => intro _ _ _ _ k hk; omega
  | succ n ih =>
    intro start init res h k hk
    rw [List.range'_succ] at h
    simp only [List.forIn_cons, bind, Except.bind] at h
    split at h
    · cases h
    · rename_i r hr
      obtain ⟨hP, x, s', hpop, rfl⟩ := hf start init r hr
      obtain ⟨rest, hsr, hs'⟩ := popElem_ok init s' x hpop
      cases k with
      | zero => simpa using hP
      | succ k =>
        have := ih (start + 1) s' res h k (by omega)
        have ht : Ops.Stack.topAt s' k = Ops.Stack.topAt init (k + 1) := by
          simp [Ops.Stack.topAt, hs', hsr]
        rw [ht] at this
        rw [show start + (k + 1) = start + 1 + k by omega]
        exact this

/-- **H8 (NULLFAIL under the gate, `OP_CHECKMULTISIG`).** *What it says:* an `OP_CHECKMULTISIG` that
succeeds with a false result under `SCRIPT_VERIFY_NULLFAIL` and the version gate found every signature
empty: with `n` keys and `m` signatures read, the elements `n + 2` to `n + 1 + m` below the top.
*What it assumes:* the opcode `OP_CHECKMULTISIG` (its `VERIFY` form fails on a false result), its
success, the false result on top, the flag, the gate. *Why it matters:* the argument pops refuse a
non-empty signature after a failed check (`1641–1647`), so a failing multisig cannot carry a non-empty
signature where the gate is on, the malleability NULLFAIL closes (with H6 for `OP_CHECKSIG`). -/
theorem checkMultiSigOp_nullfail {env : Env} {st st' : State}
    (h : Ops.Crypto.checkMultiSigOp env Op.OP_CHECKMULTISIG st = .ok st')
    (hfalse : st'.stack.head? = some []) (hnf : env.params.flags.nullFail = true)
    (hg : enforceNonMalleability env.params.flags env.ctx.version = true) :
    ∃ n m : Nat, Ops.Crypto.readCount env (Ops.Stack.topAt st 0) = .ok (n : Int) ∧
      Ops.Crypto.readCount env (Ops.Stack.topAt st (n + 1)) = .ok (m : Int) ∧
      ∀ k < m, Ops.Stack.topAt st (n + 2 + k) = [] := by
  unfold Ops.Crypto.checkMultiSigOp at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · split at h
    · cases h
    · rename_i nK hnK
      by_cases c1 : nK < 0
      · rw [ite_pos_of c1] at h; exact absurd h (by intro hc; cases hc)
      rw [ite_neg_of c1] at h
      by_cases c2 : env.params.limits.maxPubKeysPerMultiSig < nK.toNat
      · rw [ite_pos_of c2] at h; exact absurd h (by intro hc; cases hc)
      rw [ite_neg_of c2] at h
      by_cases c3 : env.params.limits.maxOpsPerScript < st.opCount + nK.toNat
      · rw [ite_pos_of c3] at h; exact absurd h (by intro hc; cases hc)
      rw [ite_neg_of c3] at h
      split at h
      · cases h
      · split at h
        · cases h
        · rename_i nS hnS
          by_cases c4 : nS < 0
          · rw [ite_pos_of c4] at h; exact absurd h (by intro hc; cases hc)
          rw [ite_neg_of c4] at h
          by_cases c5 : nK.toNat < nS.toNat
          · rw [ite_pos_of c5] at h; exact absurd h (by intro hc; cases hc)
          rw [ite_neg_of c5] at h
          split at h
          · cases h
          · split at h
            · cases h
            · rename_i b hb
              split at h
              · cases h
              · rename_i stm hloop
                by_cases c6 : stm.stack.isEmpty = true
                · rw [ite_pos_of c6] at h; exact absurd h (by intro hc; cases hc)
                rw [ite_neg_of c6] at h
                by_cases c7 : (env.params.flags.nullDummy && !List.isEmpty (Ops.Stack.topAt stm 0) &&
                    enforceNonMalleability env.params.flags env.ctx.version) = true
                · rw [ite_pos_of c7] at h; exact absurd h (by intro hc; cases hc)
                rw [ite_neg_of c7] at h
                split at h
                · cases h
                · rename_i p5 hp5
                  split at h
                  · cases h
                  · rename_i s6 hp6
                    have hne : ¬ (Op.OP_CHECKMULTISIG = Op.OP_CHECKMULTISIGVERIFY) := by decide
                    rw [ite_neg_of hne] at h
                    simp only [pure, Except.pure, Except.ok.injEq] at h
                    subst h
                    have hst6 := pushElem_ok env _ _ _ hp6
                    have hbf : b = false := by
                      rw [hst6] at hfalse
                      cases b <;> simp_all
                    subst hbf
                    have hguard := forIn_rangeFrom_guard
                      (fun j top => (!false && env.params.flags.nullFail &&
                        enforceNonMalleability env.params.flags env.ctx.version && decide (nK.toNat + 2 ≤ j) &&
                        !List.isEmpty top)) _ ?_ (nK.toNat + 2 + nS.toNat) 0 _ stm
                      (by rw [← List.range_eq_range']; exact hloop)
                    · refine ⟨nK.toNat, nS.toNat, ?_, ?_, ?_⟩
                      · rw [Int.toNat_of_nonneg (by omega)]; exact hnK
                      · rw [Int.toNat_of_nonneg (by omega)]; simpa [Ops.Stack.topAt] using hnS
                      · intro k hk
                        have := hguard (nK.toNat + 2 + k) (by omega)
                        simp only [hnf, hg, Bool.not_false, Bool.true_and, Nat.zero_add] at this
                        simpa [Ops.Stack.topAt] using this
                    · intro j s r hs
                      split at hs
                      · exact absurd hs (by intro hc; cases hc)
                      · rename_i hcond
                        split at hs
                        · cases hs
                        · rename_i p hp
                          simp only [pure, Except.pure, Except.ok.injEq] at hs
                          refine ⟨by simpa using hcond, p.1, p.2, by rw [hp], hs.symm⟩

end BsvScript.Properties
