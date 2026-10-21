import BsvScript.Eval
/-!
# BsvScript.Properties.Coverage

Every byte is defined (#18): for every opcode with a `case` label in the
reference's switch (`Op.hasCase`, `interpreter.cpp:483–1795`), some family hook
owns it or the flow dispatch handles it, so the loop never returns
`unimplemented` on a byte. The proof is a decision over the 256 bytes for the
ownership predicates, plus one lemma per family that its hook answers exactly
on the opcodes it owns.
-/

namespace BsvScript.Properties
open BsvScript.Params BsvScript.Machine BsvScript.Numbers

/-- The opcodes handled before the family hook: those `execFlow` handles itself
(`483–871`), and `OP_CODESEPARATOR` (`1445–1448`), which `execStep` handles before
`execFlow` is reached (`execFlow` has no branch for it, so `execFlow_ne_unimpl`
excludes it by hypothesis). -/
def flowOwns (op : Nat) : Bool :=
  op = Op.OP_1NEGATE || (Op.OP_1 ≤ op && op ≤ Op.OP_16) || op = Op.OP_NOP
  || op = Op.OP_CHECKLOCKTIMEVERIFY || op = Op.OP_CHECKSEQUENCEVERIFY || op = Op.OP_VER
  || op = Op.OP_NOP1 || op = Op.OP_NOP9 || op = Op.OP_NOP10 || op = Op.OP_VERIF || op = Op.OP_VERNOTIF
  || op = Op.OP_IF || op = Op.OP_NOTIF || op = Op.OP_ELSE || op = Op.OP_ENDIF || op = Op.OP_VERIFY
  || op = Op.OP_RETURN || op = Op.OP_CODESEPARATOR

/-- The opcodes the family hooks own, as their `exec` decide them. -/
def hookOwns (op : Nat) : Bool :=
  (Ops.Arith.isUnary op || Ops.Arith.isBinary op || op = Op.OP_WITHIN)
  || (op = Op.OP_AND || op = Op.OP_OR || op = Op.OP_XOR || op = Op.OP_INVERT
      || op = Op.OP_LSHIFT || op = Op.OP_RSHIFT || op = Op.OP_EQUAL || op = Op.OP_EQUALVERIFY)
  || ((Op.OP_TOALTSTACK ≤ op && op ≤ Op.OP_TUCK) || op = Op.OP_SIZE)
  || (op = Op.OP_CAT || op = Op.OP_SPLIT || op = Op.OP_NUM2BIN || op = Op.OP_BIN2NUM)
  || ((Op.OP_RIPEMD160 ≤ op && op ≤ Op.OP_HASH256) || op = Op.OP_CHECKSIG || op = Op.OP_CHECKSIGVERIFY
      || op = Op.OP_CHECKMULTISIG || op = Op.OP_CHECKMULTISIGVERIFY)
  || (Op.OP_SUBSTR ≤ op && op ≤ Op.OP_RSHIFTNUM)

set_option maxRecDepth 16384 in
/-- **Coverage.** Every byte with a `case` label is in `flowOwns` (an opcode
`execFlow` handles itself, or `OP_CODESEPARATOR`, which `execStep` handles) or in
`hookOwns` (a family's). -/
theorem coverage : ∀ op, op < 256 → Op.hasCase op = true → (flowOwns op || hookOwns op) = true := by
  decide

/-- The arithmetic family's hook answers exactly on the opcodes it owns: `some` on
the opcodes of `Ops.Arith.isUnary` and `Ops.Arith.isBinary` and on `OP_WITHIN`,
`none` on every other byte, which it leaves to the next hook. One of the six lemmas
`opExec_isSome_of_hookOwns` assembles. -/
theorem arith_exec_isSome (op : Nat) (d : Bytes) (env : Env) (st : State) :
    (Ops.Arith.exec op d env st).isSome = (Ops.Arith.isUnary op || Ops.Arith.isBinary op || op = Op.OP_WITHIN) := by
  unfold Ops.Arith.exec
  split_ifs <;> simp_all

/-- The bitwise family's hook answers exactly on `OP_AND`, `OP_OR`, `OP_XOR`,
`OP_INVERT`, `OP_LSHIFT`, `OP_RSHIFT`, `OP_EQUAL` and `OP_EQUALVERIFY`, and on no
other byte. One of the six lemmas `opExec_isSome_of_hookOwns` assembles. -/
theorem bitwise_exec_isSome (op : Nat) (d : Bytes) (env : Env) (st : State) :
    (Ops.Bitwise.exec op d env st).isSome
      = (op = Op.OP_AND || op = Op.OP_OR || op = Op.OP_XOR || op = Op.OP_INVERT
         || op = Op.OP_LSHIFT || op = Op.OP_RSHIFT || op = Op.OP_EQUAL || op = Op.OP_EQUALVERIFY) := by
  unfold Ops.Bitwise.exec
  split_ifs <;> simp_all

/-- The stack family's hook answers exactly on the opcodes from `OP_TOALTSTACK` to
`OP_TUCK` and on `OP_SIZE`, and on no other byte. One of the six lemmas
`opExec_isSome_of_hookOwns` assembles. -/
theorem stack_exec_isSome (op : Nat) (d : Bytes) (env : Env) (st : State) :
    (Ops.Stack.exec op d env st).isSome = ((Op.OP_TOALTSTACK ≤ op && op ≤ Op.OP_TUCK) || op = Op.OP_SIZE) := by
  unfold Ops.Stack.exec
  split_ifs <;> simp_all

/-- The splice family's hook answers exactly on `OP_CAT`, `OP_SPLIT`, `OP_NUM2BIN`
and `OP_BIN2NUM`, and on no other byte. One of the six lemmas
`opExec_isSome_of_hookOwns` assembles. -/
theorem splice_exec_isSome (op : Nat) (d : Bytes) (env : Env) (st : State) :
    (Ops.Splice.exec op d env st).isSome = (op = Op.OP_CAT || op = Op.OP_SPLIT || op = Op.OP_NUM2BIN || op = Op.OP_BIN2NUM) := by
  unfold Ops.Splice.exec
  split_ifs <;> simp_all

/-- The crypto family's hook answers exactly on the hashes from `OP_RIPEMD160` to
`OP_HASH256` and on the four signature checks, and on no other byte: not on
`OP_CODESEPARATOR` (`0xab`, between `OP_HASH256` and `OP_CHECKSIG`), which
`execStep` handles (`flowOwns`). One of the six lemmas `opExec_isSome_of_hookOwns`
assembles. -/
theorem crypto_exec_isSome (op : Nat) (d : Bytes) (env : Env) (st : State) :
    (Ops.Crypto.exec op d env st).isSome
      = ((Op.OP_RIPEMD160 ≤ op && op ≤ Op.OP_HASH256) || op = Op.OP_CHECKSIG || op = Op.OP_CHECKSIGVERIFY
         || op = Op.OP_CHECKMULTISIG || op = Op.OP_CHECKMULTISIGVERIFY) := by
  unfold Ops.Crypto.exec
  split_ifs <;> simp_all <;> tauto

/-- The expansion family's hook answers exactly on the opcodes from `OP_SUBSTR` to
`OP_RSHIFTNUM` (`OP_SUBSTR`, `OP_LEFT`, `OP_RIGHT`, `OP_LSHIFTNUM`,
`OP_RSHIFTNUM`), and on no other byte. One of the six lemmas
`opExec_isSome_of_hookOwns` assembles. -/
theorem expansion_exec_isSome (op : Nat) (d : Bytes) (env : Env) (st : State) :
    (Ops.Expansion.exec op d env st).isSome = (Op.OP_SUBSTR ≤ op && op ≤ Op.OP_RSHIFTNUM) := by
  unfold Ops.Expansion.exec
  split_ifs <;> simp_all

/-- A fact of `Option`: `Option.orElse a b` answers exactly when `a` or `b ()`
does. It turns the chain of six hooks `Eval.opExec` builds with `<|>` into the
disjunction of the six lemmas above (`opExec_isSome_of_hookOwns`). -/
theorem isSome_orElse {α : Type} (a : Option α) (b : Unit → Option α) :
    (Option.orElse a b).isSome = (a.isSome || (b ()).isSome) := by
  cases a <;> rfl

/-- **Every byte is defined.** The assembled hook answers on every opcode the
families own. -/
theorem opExec_isSome_of_hookOwns (op : Nat) (d : Bytes) (env : Env) (st : State)
    (h : hookOwns op = true) : (Eval.opExec op d env st).isSome = true := by
  unfold Eval.opExec
  simp only [HOrElse.hOrElse, OrElse.orElse, isSome_orElse, arith_exec_isSome, bitwise_exec_isSome,
    stack_exec_isSome, splice_exec_isSome, crypto_exec_isSome, expansion_exec_isSome]
  unfold hookOwns at h
  simp only [Bool.or_eq_true] at h ⊢
  tauto

/-! ## The capstone: the machine never answers `unimplemented` on a byte

`execFlow` (`483–1795`) handles the flow opcodes itself and hands every other
opcode to the hook; with the six families assembled the hook answers on every one
of those with a `case` label but `OP_CODESEPARATOR`, which no family owns, so
`execFlow` never answers `unimpl` off the separator (`execFlow_ne_unimpl`). The
loop (`388–1833`) hands `execFlow` a byte only off `OP_CODESEPARATOR` (`1445–1448`
is the loop's own, in `execStep`), so the loop never returns `unimplemented`. -/

/-- `execIf` (`773–781`, `784–825`) never answers `unimpl`. -/
theorem execIf_ne_unimpl (env : Env) (op : Nat) (fExec : Bool) (st : State) (o : Nat) :
    execIf env op fExec st ≠ .unimpl o := by
  unfold execIf
  dsimp only
  (repeat' split) <;> simp

/-- `execCltv` (`519–560`) never answers `unimpl`. -/
theorem execCltv_ne_unimpl (env : Env) (st : State) (o : Nat) : execCltv env st ≠ .unimpl o := by
  unfold execCltv
  (repeat' split) <;> simp

/-- `execCsv` (`562–597`) never answers `unimpl`. -/
theorem execCsv_ne_unimpl (env : Env) (st : State) (o : Nat) : execCsv env st ≠ .unimpl o := by
  unfold execCsv
  (repeat' split) <;> simp

/-- Off the flow opcodes, `execFlow` is the hook's answer (`872–1795`). -/
theorem execFlow_of_not_flowOwns (exec : OpExec) (env : Env) (op : Nat) (d : Bytes) (fExec : Bool)
    (st : State) (h : flowOwns op = false) :
    execFlow exec env op d fExec st =
      (match exec op d env st with
        | some (.ok st') => .cont st'
        | some (.fail e) => .fail e
        | some (.undefined f) => .undefined f
        | none => if Op.hasCase op then .unimpl op else .fail .badOpcode) := by
  simp only [flowOwns, Bool.or_eq_false_iff, Bool.and_eq_false_iff, decide_eq_false_iff_not] at h
  obtain ⟨⟨⟨⟨⟨⟨⟨⟨⟨⟨⟨⟨⟨⟨⟨⟨⟨h1, h2⟩, h3⟩, h4⟩, h5⟩, h6⟩, h7⟩, h8⟩, h9⟩, h10⟩, h11⟩, h12⟩, h13⟩, h14⟩, h15⟩,
    h16⟩, h17⟩, _⟩ := h
  have c1 : ¬(op = Op.OP_1NEGATE ∨ (Op.OP_1 ≤ op ∧ op ≤ Op.OP_16)) := by
    rintro (hc | ⟨hc1, hc2⟩)
    · exact h1 hc
    · rcases h2 with h2 | h2
      · exact h2 hc1
      · exact h2 hc2
  have c6 : ¬(op = Op.OP_NOP1 ∨ op = Op.OP_NOP9 ∨ op = Op.OP_NOP10) := by
    rintro (hc | hc | hc) <;> first | exact h7 hc | exact h8 hc | exact h9 hc
  have c7 : ¬(op = Op.OP_VERIF ∨ op = Op.OP_VERNOTIF) := by
    rintro (hc | hc) <;> first | exact h10 hc | exact h11 hc
  have c8 : ¬(op = Op.OP_IF ∨ op = Op.OP_NOTIF) := by
    rintro (hc | hc) <;> first | exact h12 hc | exact h13 hc
  unfold execFlow
  simp only [ite_eq_right c1, ite_eq_right h3, ite_eq_right h4, ite_eq_right h5, ite_eq_right h6, ite_eq_right c6, ite_eq_right c7, ite_eq_right c8,
    ite_eq_right h14, ite_eq_right h15, ite_eq_right h16, ite_eq_right h17]
  cases exec op d env st with
  | none => rfl
  | some r => cases r <;> rfl

/-- Above the byte range nothing has a `case` label. -/
theorem hasCase_false_of_ge (op : Nat) (h : 256 ≤ op) : Op.hasCase op = false := by
  have e1 : (op == Op.OP_1NEGATE) = false := by simp [Op.OP_1NEGATE]; omega
  have e2 : decide (op ≤ Op.OP_EQUALVERIFY) = false := by
    rw [decide_eq_false_iff_not, Op.OP_EQUALVERIFY]; omega
  have e3 : decide (op ≤ Op.OP_NOP10) = false := by rw [decide_eq_false_iff_not, Op.OP_NOP10]; omega
  simp [Op.hasCase, e1, e2, e3]

set_option linter.unusedSimpArgs false in
/-- **`execFlow` never answers `unimpl`** on any opcode but `OP_CODESEPARATOR`
(the loop's own, `1445–1448`, never handed to `execFlow`). -/
theorem execFlow_ne_unimpl (env : Env) (op : Nat) (d : Bytes) (fExec : Bool) (st : State)
    (hcs : op ≠ Op.OP_CODESEPARATOR) (o : Nat) :
    execFlow Eval.opExec env op d fExec st ≠ .unimpl o := by
  by_cases hf : flowOwns op = true
  · unfold flowOwns at hf
    simp only [Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq] at hf
    rcases hf with (((((((((((((((((h | h) | h) | h) | h) | h) | h) | h) | h) | h) | h) | h) | h) | h) | h) | h) | h) | h)
    all_goals first
      | exact absurd ‹op = Op.OP_CODESEPARATOR› hcs
      | (simp only [execFlow]; rw [ite_eq_left (Or.inr ‹Op.OP_1 ≤ op ∧ op ≤ Op.OP_16›)]; split <;> simp)
      | (subst ‹op = _›
         simp +decide [execFlow, execIf_ne_unimpl, execCltv_ne_unimpl, execCsv_ne_unimpl,
           Op.OP_1NEGATE, Op.OP_1, Op.OP_16, Op.OP_NOP, Op.OP_CHECKLOCKTIMEVERIFY, Op.OP_CHECKSEQUENCEVERIFY,
           Op.OP_VER, Op.OP_NOP1, Op.OP_NOP9, Op.OP_NOP10, Op.OP_VERIF, Op.OP_VERNOTIF, Op.OP_IF, Op.OP_NOTIF,
           Op.OP_ELSE, Op.OP_ENDIF, Op.OP_VERIFY, Op.OP_RETURN]
         try ((repeat' split) <;> simp [execIf_ne_unimpl, execCltv_ne_unimpl, execCsv_ne_unimpl]))
  · rw [execFlow_of_not_flowOwns _ _ _ _ _ _ (Bool.eq_false_iff.mpr hf)]
    by_cases hc : Op.hasCase op = true
    · have hh : hookOwns op = true := by
        by_cases hop : op < 256
        · have := coverage op hop hc
          simpa [Bool.eq_false_iff.mpr hf] using this
        · exact absurd hc (by simp [hasCase_false_of_ge op (by omega)])
      have hs := opExec_isSome_of_hookOwns op d env st hh
      cases h : Eval.opExec op d env st with
      | none => simp [h] at hs
      | some r => cases r <;> simp
    · cases Eval.opExec op d env st with
      | none => simp [hc]
      | some r => cases r <;> simp

/-- **`execStep` never answers `unimpl`** (`473–482`, `1445–1448`): the loop hands
`execFlow` a byte only off `OP_CODESEPARATOR`. -/
theorem execStep_ne_unimpl (env : Env) (op : Nat) (data rest : Bytes) (k : Nat) (fExec : Bool)
    (st : State) (o : Nat) : execStep Eval.opExec env op data rest k fExec st ≠ .unimpl o := by
  unfold execStep
  split
  · split
    · simp
    · split <;> simp
  · split
    · simp
    · split
      · rename_i h2 h3
        apply execFlow_ne_unimpl
        intro hc
        subst hc
        cases fExec <;> simp [Op.OP_CODESEPARATOR, Op.OP_IF, Op.OP_ENDIF] at h2 h3
      · simp

set_option linter.unusedTactic false in
/-- **The loop never answers `unimplemented`** (`388–1833`): every byte is
defined. Induction on a bound of the script length (the loop consumes at least
one byte per step). -/
theorem loop_ne_unimplemented (env : Env) : ∀ (n : Nat) (s : Bytes), s.length ≤ n →
    ∀ (st : State) (o : Nat) (st' : State), loop Eval.opExec env s st ≠ (.unimplemented o, st') := by
  intro n
  induction n with
  | zero =>
    intro s hs st o st'
    cases s with
    | nil => rw [loop.eq_1]; split <;> simp
    | cons a t => simp at hs
  | succ n ih =>
    intro s hs st o st'
    cases s with
    | nil => rw [loop.eq_1]; split <;> simp
    | cons op rest =>
      rw [loop.eq_2]
      dsimp only
      repeat' split
      all_goals first
        | (apply ih; simp only [List.length_cons, List.length_drop] at hs ⊢; omega)
        | (exfalso; exact execStep_ne_unimpl _ _ _ _ _ _ _ _ ‹_›)
        | (simp; done)

/-- The corollary as `evalScript` states it (`1984–2006`): no script, stack and
memory counter reach `unimplemented`. -/
theorem evalScript_ne_unimplemented (env : Env) (script : Bytes) (stack : List Bytes) (memUsed : Nat)
    (o : Nat) (st' : State) : evalScript Eval.opExec env script stack memUsed ≠ (.unimplemented o, st') := by
  unfold evalScript
  split
  · simp
  · exact loop_ne_unimplemented env _ script le_rfl _ o st'

end BsvScript.Properties
