import BsvScript.Properties.Resources
/-!
# BsvScript.Properties.Widths

#25's remaining rows at the opcode (2026-09-27; the list on #25, 5852538695): the
number reader's overflow refusal, the digest widths of the hash opcodes, `OP_CAT`'s length and
`OP_SPLIT` as its inverse, `OP_NUM2BIN`'s memory refusal at the opcode (the flagged rule
`splice.num2bin.memory`), and the count bounds and result widths of the two expansion shifts, each
stated on the opcode's own definition and cited at the pin.

Bare line numbers are `src/script/interpreter.cpp` at the pin (`docs/PROVENANCE.md`).
-/

namespace BsvScript.Properties
open BsvScript.Params BsvScript.Machine BsvScript.Numbers BsvScript.Hash

/-- **W1 (the number reader's overflow).** *What it says:* reading a number refuses
`SCRIPT_ERR_SCRIPTNUM_OVERFLOW` exactly when the element is longer than the width, whatever the minimal
rule. *What it assumes:* nothing. *Why it matters:* the length bound is tested first
(`script_num.cpp:62–65`, before the minimality check at `script_num.cpp:67–70`), so an over-long element
is an overflow even when it is also non-minimal. -/
theorem readNum_overflow_iff (bs : Bytes) (rm : Bool) (maxLen : Nat) :
    readNum bs rm maxLen = .error .overflow ↔ maxLen < bs.length := by
  unfold readNum
  by_cases h1 : maxLen < bs.length
  · simp [h1]
  · simp only [h1, ↓reduceIte]
    split <;> simp

/-- The digest of a hash opcode (`1402–1443`): what `Ops.Crypto.hashOp` pushes. -/
def digestOf (op : Nat) (v : Bytes) : Bytes :=
  if op = Op.OP_RIPEMD160 then ripemd160 v
  else if op = Op.OP_SHA1 then sha1 v
  else if op = Op.OP_SHA256 then sha256 v
  else if op = Op.OP_HASH160 then hash160 v
  else hash256 v

/-- **W2 (the digest widths).** *What it says:* a hash opcode that succeeds replaces the top element by its
digest, 20 bytes for `OP_RIPEMD160`, `OP_SHA1` and `OP_HASH160`, 32 for `OP_SHA256` and `OP_HASH256`.
*What it assumes:* the opcode succeeded. *Why it matters:* the widths are the digests' own
(`CRIPEMD160::OUTPUT_SIZE`, `CSHA1::OUTPUT_SIZE`, `CHash160`, `CSHA256`, `CHash256`, `1412–1440`), so the
memory a hash adds is known before it runs. -/
theorem hashOp_ok (env : Env) (op : Nat) (st st' : State) (h : Ops.Crypto.hashOp env op st = .ok st') :
    ∃ v rest, st.stack = v :: rest ∧ st'.stack = digestOf op v :: rest ∧
      (digestOf op v).length =
        (if op = Op.OP_RIPEMD160 ∨ op = Op.OP_SHA1 ∨ op = Op.OP_HASH160 then 20 else 32) := by
  unfold Ops.Crypto.hashOp at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · split at h
    · cases h
    · rename_i p hp
      obtain ⟨v, st1⟩ := p
      have hst := pushElem_ok env st1 st' _ h
      unfold popElem at hp
      split at hp
      · cases hp
      · rename_i x xs hs
        simp only [Except.ok.injEq, Prod.mk.injEq] at hp
        obtain ⟨rfl, rfl⟩ := hp
        refine ⟨x, xs, hs, ?_, ?_⟩
        · rw [hst]; rfl
        · unfold digestOf
          split_ifs <;> simp_all [ripemd160_length, sha1_length, sha256_length, hash160_length, hash256, sha256d,
            Op.OP_RIPEMD160, Op.OP_SHA1, Op.OP_SHA256, Op.OP_HASH160]

/-- **W3 (`OP_CAT`'s result).** *What it says:* an `OP_CAT` that succeeds replaces the top two elements
`x2` (the second) and `x1` (the top) by `x2 ++ x1`, whose length is the sum. *What it assumes:* the opcode
succeeded. *Why it matters:* the concatenation is the second element followed by the top
(`1704–1705`: the top popped, then appended to the second in place), and by the length conjunct the
result weighs one element's overhead less than the two it replaces. The counter and the alt stack are not in this
statement: that the counter drops by that overhead, where it is exact, needs the alt stack unchanged too,
which the primitives' shapes give (`popElem_ok`, `pushElem_ok`), with `cat_frame`
(`BsvScript.Properties.Hooks`). -/
theorem cat_ok (env : Env) (st st' : State) (h : Ops.Splice.cat env st = .ok st') :
    ∃ x1 x2 rest, st.stack = x1 :: x2 :: rest ∧ st'.stack = (x2 ++ x1) :: rest ∧
      (x2 ++ x1).length = x2.length + x1.length := by
  unfold Ops.Splice.cat at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · rename_i hneed
    unfold Ops.Stack.need at hneed
    split at hneed
    · cases hneed
    · rename_i hlen
      split_ifs at h with hsz
      obtain ⟨x1, x2, rest, hs⟩ : ∃ x1 x2 rest, st.stack = x1 :: x2 :: rest := by
        match hst : st.stack with
        | x1 :: x2 :: rest => exact ⟨x1, x2, rest, rfl⟩
        | [] => simp [hst] at hlen
        | [_] => simp [hst] at hlen
      simp only [popElem, hs] at h
      have hst := pushElem_ok env _ st' _ h
      refine ⟨x1, x2, rest, hs, ?_, List.length_append⟩
      rw [hst]
      simp [Ops.Stack.topAt, hs]

/-- **W4 (`OP_SPLIT` is `OP_CAT`'s inverse).** *What it says:* an `OP_SPLIT` that succeeds read the
position `n` from the top element `p` (the number read, `1716–1717`), at most
`INT32_MAX` ([SRC] `6504a3af`, `interpreter.cpp:1718`) and the length of the element
`x` under it, and replaced the two by the halves `x.take n` (below) and `x.drop n` (on top), which
concatenate back to `x`. *What it assumes:* the opcode succeeded. *Why it matters:* `OP_SPLIT` then
`OP_CAT` restores the element (the halves cut at the position, `1726–1727`, both popped and the halves
pushed, `1730–1735`; T-SP1), so a split never loses or reorders a byte. -/
theorem split_ok (env : Env) (st st' : State) (h : Ops.Splice.split env st = .ok st') :
    ∃ (x p : Bytes) (rest : List Bytes) (n : Nat), st.stack = p :: x :: rest ∧
      Ops.Arith.readOperand env p = .ok (n : Int) ∧ n ≤ 2147483647 ∧ n ≤ x.length ∧
      st'.stack = x.drop n :: x.take n :: rest ∧ x.take n ++ x.drop n = x := by
  unfold Ops.Splice.split at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · rename_i hneed
    unfold Ops.Stack.need at hneed
    split at hneed
    · cases hneed
    · rename_i hlen
      split at h
      · cases h
      · rename_i n hn
        split_ifs at h with hr
        obtain ⟨p, x, rest, hs⟩ : ∃ p x rest, st.stack = p :: x :: rest := by
          match hst : st.stack with
          | p :: x :: rest => exact ⟨p, x, rest, rfl⟩
          | [] => simp [hst] at hlen
          | [_] => simp [hst] at hlen
        simp only [popElem, hs] at h
        split at h
        · cases h
        · rename_i st2 hpush
          have h2 := pushElem_ok env _ _ _ hpush
          have h3 := pushElem_ok env _ st' _ h
          simp only [Ops.Splice.invalidSplitPosition, Bool.or_eq_true, decide_eq_true_eq, not_or, not_lt] at hr
          refine ⟨x, p, rest, n.toNat, hs, ?_, ?_, ?_, ?_, List.take_append_drop _ _⟩
          · rw [Int.toNat_of_nonneg (by omega)]
            simpa [Ops.Stack.topAt, hs] using hn
          · omega
          · simp only [Ops.Stack.topAt, hs, List.getD_cons_succ, List.getD_cons_zero] at hr
            omega
          · rw [h3, h2]
            simp [Ops.Stack.topAt, hs]

end BsvScript.Properties

namespace BsvScript.Properties
open BsvScript.Params BsvScript.Machine BsvScript.Numbers

/-- An integer of smaller magnitude never encodes longer (`serialize`, `int_serialization.h:23–59`: the
minimal encoding's length is a function of the magnitude, T6). -/
theorem encode_length_mono (a b : Int) (h : a.natAbs ≤ b.natAbs) : (encode a).length ≤ (encode b).length := by
  by_cases hb : b = 0
  · subst hb
    have ha : a = 0 := Int.natAbs_eq_zero.mp (by simpa using h)
    subst ha; simp [encode_zero]
  · have h1 : 1 ≤ (encode b).length := by
      by_contra hc
      have h0 : encode b = [] := List.eq_nil_of_length_eq_zero (by omega)
      have hd := decode_encode b
      rw [h0] at hd
      simp [decode, decodeRev] at hd
      exact hb hd.symm
    have hb' := (encode_length_le_iff b _ h1).mp le_rfl
    exact (encode_length_le_iff a _ h1).mpr (lt_of_le_of_lt h hb')

/-- **W5 (`OP_NUM2BIN`'s memory at the opcode; the flagged rule `splice.num2bin.memory`).** *What it says:*
when the width `w` and the number pass their checks (the width read as a number in `0 … INT32_MAX`, at
most 520 before Genesis, the number fitting it), `OP_NUM2BIN` refuses `SCRIPT_ERR_STACK_SIZE` exactly when
the counter after the two pops plus `w` and the element overhead exceeds `MaxStackMemoryUsage`. *What it
assumes:* the stack `wb :: raw :: rest`, the width's read and the fit. *Why it matters:* the padding is
charged against the memory budget before the result exists (`padRight`, `limitedstack.cpp:60–71`, at
`1771–1777`; the spec refuses before `num2bin` builds it, #142): a small number padded to a width of up to
2³¹ − 1 bytes is refused by the memory limit, not by a width limit, the corner the corpus flags. -/
theorem num2binOp_stackSize_iff (env : Env) (st : State) (wb raw r : Bytes) (rest : List Bytes) (w : Nat)
    (hs : st.stack = wb :: raw :: rest) (hread : Ops.Arith.readOperand env wb = .ok (w : Int))
    (hw : w ≤ 2147483647) (hpre : env.utxoAfterGenesis = true ∨ w ≤ Consensus.maxScriptElementSizeBeforeGenesis)
    (hfit : num2bin raw w = some r) :
    Ops.Splice.num2binOp env st = .error .stackSize ↔
      env.params.limits.maxStackMemoryUsage
        < st.memUsed - (wb.length + elementOverhead) - (raw.length + elementOverhead) + (w + elementOverhead) := by
  have hr := num2bin_length raw w r hfit
  unfold Ops.Splice.num2binOp
  simp only [bind, Except.bind, Ops.Stack.need, hs, List.length_cons, Ops.Stack.topAt, List.getD_cons_zero,
    hread]
  have h2 : ¬ (rest.length + 1 + 1 < 2) := by omega
  simp only [h2, ↓reduceIte]
  have h3 : ¬ ((w : Int) < 0 || (2147483647 : Int) < (w : Int)) = true := by
    simp only [Bool.or_eq_true, decide_eq_true_eq, not_or, not_lt]; omega
  simp only [h3, Bool.false_eq_true, ↓reduceIte, Int.toNat_natCast]
  have h4 : ¬ (!env.utxoAfterGenesis && decide (Consensus.maxScriptElementSizeBeforeGenesis < w)) = true := by
    rcases hpre with hp | hp <;> simp [hp]
  have h5 : ¬ w < (minimallyEncode raw).length := fun h => by
    rw [← num2bin_none_iff, hfit] at h; cases h
  simp only [h4, Bool.false_eq_true, ↓reduceIte, popElem, hs, h5, hfit]
  split
  · rename_i hc
    constructor
    · intro _; omega
    · intro _; rfl
  · rw [pushElem_stackSize_iff]
    simp only [elemWeight, hr]

/-- The number reader refuses only by the width or the minimal rule (`script_num.cpp:62–70`). -/
theorem readOperand_error (env : Env) (bs : Bytes) (e : ScriptError)
    (h : Ops.Arith.readOperand env bs = .error e) : e = .scriptnumOverflow ∨ e = .scriptnumMinencode := by
  unfold Ops.Arith.readOperand at h
  split_ifs at h <;> simp_all

/-- A pop refuses only an empty stack (`limitedstack.cpp:211–219`). -/
theorem popElem_error (st : State) (e : ScriptError) (h : popElem st = .error e) : e = .invalidStackOperation := by
  unfold popElem at h
  split at h <;> simp_all

/-- A push refuses only the memory limit (`limitedstack.h:163–173`). -/
theorem pushElem_error (env : Env) (st : State) (x : Bytes) (e : ScriptError) (h : pushElem env st x = .error e) :
    e = .stackSize := by
  revert h
  unfold pushElem
  try dsimp only
  split <;> intro h <;> simp_all

/-- **W6 (the left shift's count bound is reached only by overflow).** *What it says:* when the number
width is below 2²⁸, `OP_LSHIFTNUM` never refuses `SCRIPT_ERR_BIG_INT`. *What it assumes:* the width below
268,435,456. It holds on the block path (the consensus widths: 750,000 after Genesis, `consensus.h:64`;
32,000,000 after Chronicle, `consensus.h:66`) and at the policy default (10,000, `policy.h:156`), not at
every policy setting: `-maxscriptnumlengthpolicy` has no upper bound (`configscriptpolicy.cpp:192–215`
refuses only a negative value and 1 to 3; the mempool path uses it as set, `:108–109`). *Why it
matters:* the size test (`script_num.cpp:311–314`: the value's size plus `n / 8` bytes within the width)
runs before `bint::operator<<=` refuses a count above `INT_MAX` (`big_int.cpp:359–366`), and a count
above `INT_MAX` already asks for at least 2²⁸ bytes, so below that width the big-number refusal is dead
and `SCRIPT_ERR_SCRIPTNUM_OVERFLOW` is what such a count gets; on the mempool path of a node set to at
least 2²⁸ bytes plus the value's size (at exactly 2²⁸ only the zero value; `-maxscriptnumlengthpolicy=1GB`,
say, for every value) a count just above `INT_MAX` passes the size test (`script_num.cpp:311–314`) and is
refused as `SCRIPT_ERR_BIG_INT` (`1819–1822`). -/
theorem lshiftnum_ne_bigInt (env : Env) (st : State)
    (hw : env.params.limits.maxScriptNumLength < 268435456) :
    Ops.Expansion.lshiftnum env st ≠ .fail .bigInt := by
  unfold Ops.Expansion.lshiftnum
  split
  · simp
  · split
    · rename_i e he
      simp only [ne_eq, HookR.fail.injEq]
      rintro rfl
      rcases readOperand_error _ _ _ he with h | h <;> cases h
    · rename_i n hn
      split
      · simp
      · split
        · rename_i e he
          simp only [ne_eq, HookR.fail.injEq]
          rintro rfl
          rcases readOperand_error _ _ _ he with h | h <;> cases h
        · rename_i v hv
          simp only
          split
          · simp
          · rename_i hsz
            split
            · rename_i hbig
              exfalso
              have h8 : 268435456 ≤ n.toNat / 8 := by
                simp only [Ops.Expansion.INT_MAX] at hbig
                omega
              omega
            · split
              · simp
              · intro hc
                simp only [bind, Except.bind] at hc
                split at hc
                · rename_i e he
                  simp only [HookR.ofExcept, HookR.fail.injEq] at hc
                  subst hc
                  cases popElem_error _ _ he
                · split at hc
                  · rename_i e he
                    simp only [HookR.ofExcept, HookR.fail.injEq] at hc
                    subst hc
                    cases popElem_error _ _ he
                  · cases hp : pushElem env _ _ with
                    | error e =>
                      rw [hp] at hc
                      simp only [HookR.ofExcept, HookR.fail.injEq] at hc
                      subst hc
                      cases pushElem_error _ _ _ _ hp
                    | ok s =>
                      rw [hp] at hc
                      simp [HookR.ofExcept] at hc

/-- **W7 (the right shift's result width).** *What it says:* an `OP_RSHIFTNUM` that succeeds read its
count `n` from the top element, `0 ≤ n ≤ INT_MAX`, and its value `v` from the second, and replaced the
two by `r`: zero when `n` is at least `v`'s encoded width in bits, else `v` divided by `2ⁿ` toward zero;
`r` encodes in no more bytes than `v`. *What it assumes:* the opcode succeeded. *Why it matters:* the
quotient toward zero never grows the magnitude (`BN_rshift` on the magnitude, `big_int.cpp:376`, from the
`bint` branch of `operator>>=`, `script_num.cpp:367–372`), so the right shift needs no width test on its
result, as the reference has none. Its count is refused at its read (`744–747`: over the width
`SCRIPT_ERR_SCRIPTNUM_OVERFLOW`, non-minimal under the minimal rule `SCRIPT_ERR_SCRIPTNUM_MINENCODE`),
when negative (`SCRIPT_ERR_INVALID_NUMBER_RANGE`, `748–749`) and above `INT_MAX` (`SCRIPT_ERR_BIG_INT`,
`big_int.cpp:383–390`). -/
theorem rshiftnum_ok (env : Env) (st st' : State) (h : Ops.Expansion.rshiftnum env st = .ok st') :
    ∃ (nb vb : Bytes) (rest : List Bytes) (n v r : Int), st.stack = nb :: vb :: rest ∧
      Ops.Arith.readOperand env nb = .ok n ∧ 0 ≤ n ∧ n ≤ Ops.Expansion.INT_MAX ∧
      Ops.Arith.readOperand env vb = .ok v ∧
      r = (if (8 * (encode v).length : Int) ≤ n then 0 else Int.tdiv v (2 ^ n.toNat)) ∧
      st'.stack = encode r :: rest ∧ (encode r).length ≤ (encode v).length := by
  unfold Ops.Expansion.rshiftnum at h
  split at h
  · cases h
  · rename_i hlen
    split at h
    · cases h
    · rename_i n hn
      split at h
      · cases h
      · rename_i hneg
        split at h
        · cases h
        · rename_i v hv
          split at h
          · cases h
          · rename_i hbig
            match hs : st.stack, hlen with
            | nb :: vb :: rest, _ =>
              have hn' : Ops.Arith.readOperand env nb = .ok n := by
                simpa [Ops.Stack.topAt, hs] using hn
              have hv' : Ops.Arith.readOperand env vb = .ok v := by
                simpa [Ops.Stack.topAt, hs] using hv
              simp only [popElem, hs, bind, Except.bind] at h
              generalize hr : (if (8 * (encode v).length : Int) ≤ n then 0 else Int.tdiv v (2 ^ n.toNat)) = r at h
              cases hp : pushElem env _ (encode r) with
              | error e => rw [hp] at h; cases h
              | ok s =>
                rw [hp] at h
                simp only [HookR.ofExcept, HookR.ok.injEq] at h
                subst h
                have hst := pushElem_ok env _ s _ hp
                refine ⟨nb, vb, rest, n, v, r, rfl, hn', by omega, by omega, hv', hr.symm, ?_, ?_⟩
                · rw [hst]
                · apply encode_length_mono
                  rw [← hr]
                  split
                  · simp
                  · exact Int.natAbs_tdiv_le_natAbs _ _
            | [], hl => simp at hl
            | [_], hl => simp at hl

end BsvScript.Properties
