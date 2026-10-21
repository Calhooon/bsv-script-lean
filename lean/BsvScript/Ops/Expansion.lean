import BsvScript.Machine
import BsvScript.Ops.Arith
import BsvScript.Ops.Stack
/-!
# BsvScript.Ops.Expansion

The expansion opcodes `OP_SUBSTR` `0xb3`, `OP_LEFT` `0xb4`, `OP_RIGHT` `0xb5`,
`OP_LSHIFTNUM` `0xb6`, `OP_RSHIFTNUM` `0xb7` (#18; `docs/DESIGN.md` §3,
`interpreter.cpp:609–764`). For a pre-Chronicle UTXO each is a NOP, or
`SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS` under the policy flag
(`IsDiscourageUpgradableNops`, `script_flags.h:137–140`); post-Chronicle they
execute. Bare line numbers are `interpreter.cpp` at the pin (`docs/PROVENANCE.md`).

[SRC] At v1.2.3 `6504a3af`, the `OP_SUBSTR` family selects the fixed-width
constructor (`interpreter.cpp:622–625`, `655–656`, `680–681`;
`script_num.h:60–63`). `Numbers.readNumInt64` checks width and minimality,
then the conversion (`int_serialization.h:61–118`, `script_num.cpp:53–91`).
No value is a defined `SCRIPT_ERR_SCRIPTNUM_OVERFLOW`
(`interpreter.cpp:1807–1809`). The previous pin's reading is retained in a history module withheld from the
public edition at the maintainers' request (group `d8-node-team-discretion`).
`OP_LSHIFTNUM`/`OP_RSHIFTNUM` read with `big_int = true` (`708–711`, `716–719`,
`744–747`, `752–755`): the ordinary number read.
-/

namespace BsvScript.Ops.Expansion
open BsvScript.Params BsvScript.Numbers BsvScript.Machine BsvScript.Ops.Stack

/-- Pre-Chronicle, each opcode's own branch (`OP_SUBSTR` `611–616`, `OP_LEFT` `644–649`, `OP_RIGHT`
`669–674`, `OP_LSHIFTNUM` `694–699`, `OP_RSHIFTNUM` `730–735`): a NOP, or the policy error. -/
def nopOrDiscourage (env : Env) (st : State) : HookR :=
  if env.params.flags.discourageUpgradableNops then .fail .discourageUpgradableNops else .ok st

/-- The `OP_SUBSTR`/`OP_LEFT`/`OP_RIGHT` operand read at v1.2.3 `6504a3af`:
[SRC] `interpreter.cpp:622–625`, `655–656`, `680–681`, `script_num.cpp:53–91`.
After width and minimality, `none` from the fixed-width decoder becomes
`SCRIPT_ERR_SCRIPTNUM_OVERFLOW` (`interpreter.cpp:1807–1809`); successful
values saturate via `getint` (`script_num.cpp:396–422`). The previous pin's reading is retained in a history module withheld from the
public edition at the maintainers' request (group `d8-node-team-discretion`). -/
def readInt64Operand (env : Env) (bs : Bytes) : Except ScriptError Int :=
  match readNumInt64 bs env.requireMinimal env.params.limits.maxScriptNumLength with
  | .error .overflow => .error .scriptnumOverflow
  | .error .minencode => .error .scriptnumMinencode
  | .ok v => .ok (getint v)

/-- A failed fixed-width conversion produces a defined overflow refusal, provided
minimality has not refused earlier. [SRC] `6504a3af`, `script_num.cpp:62–87`,
`interpreter.cpp:1807–1809`. -/
theorem readInt64Operand_of_none (env : Env) (bs : Bytes)
    (hminimal : (env.requireMinimal &&
      !isMinimallyEncoded bs env.params.limits.maxScriptNumLength) = false)
    (hread : deserializeInt64 bs = none) :
    readInt64Operand env bs = .error .scriptnumOverflow := by
  simp [readInt64Operand, readNumInt64_of_none bs _ _ hminimal hread]

/-- [SRC] v1.2.3 `6504a3af`, `OP_SUBSTR` (`609–640`): the length (top) and the offset (second) read, the
data third; `offset < 0`, `offset ≥ size`, `len < 0` or `len > size − offset`
is `SCRIPT_ERR_INVALID_NUMBER_RANGE` (`629–635`); the data shrunk to
`[offset, offset + len)` (`637`, `LimitedVector::shrink`, `limitedstack.cpp:132–147`),
the two operands popped (`638–639`). -/
def substr (env : Env) (st : State) : HookR :=
  if st.stack.length < 3 then .fail .invalidStackOperation
  else
    match readInt64Operand env (topAt st 0) with
    | .error e => .fail e

    | .ok len =>
      match readInt64Operand env (topAt st 1) with
      | .error e => .fail e

      | .ok offset =>
        let data := topAt st 2
        let size : Int := data.length
        if offset < 0 || size ≤ offset || len < 0 || size - offset < len then .fail .invalidNumberRange
        else
          (do
            let (_, st) ← popElem st
            let (_, st) ← popElem st
            let (_, st) ← popElem st
            pushElem env st ((data.drop offset.toNat).take len.toNat) : Except ScriptError State)

-- `substr`'s compiled form (#48): the depth test walks at most 3 elements (`Machine.atLeast`).
def substrFast (env : Env) (st : State) : HookR :=
  if !atLeast 3 st.stack then .fail .invalidStackOperation
  else
    match readInt64Operand env (topAt st 0) with
    | .error e => .fail e

    | .ok len =>
      match readInt64Operand env (topAt st 1) with
      | .error e => .fail e

      | .ok offset =>
        let data := topAt st 2
        let size : Int := data.length
        if offset < 0 || size ≤ offset || len < 0 || size - offset < len then .fail .invalidNumberRange
        else
          (do
            let (_, st) ← popElem st
            let (_, st) ← popElem st
            let (_, st) ← popElem st
            pushElem env st ((data.drop offset.toNat).take len.toNat) : Except ScriptError State)

/-- `@[csimp]` (#48): the compiler runs `substrFast`, whose depth test walks at most 3 elements of the stack (`Machine.atLeast_eq`) where `substr`'s `st.stack.length < 3` measures it whole; nothing in the semantics moves, every theorem about `substr` is about the definition. -/
@[csimp] theorem substr_eq_fast : @substr = @substrFast := by
  funext env st
  unfold substr substrFast
  by_cases h : st.stack.length < 3
  · have h' : atLeast 3 st.stack = false := by rw [atLeast_eq, decide_eq_false_iff_not]; omega
    simp only [h, h']
    rfl
  · have h' : atLeast 3 st.stack = true := by rw [atLeast_eq, decide_eq_true_eq]; omega
    simp only [h, h']
    rfl

/-- [SRC] v1.2.3 `6504a3af`, `OP_LEFT` (`642–666`): the length (top) read; `len < 0` or `len > size` is
`SCRIPT_ERR_INVALID_NUMBER_RANGE` (`660–661`); the data shrunk to its first
`len` bytes (`663`); the operand popped (`664`). -/
def left (env : Env) (st : State) : HookR :=
  if st.stack.length < 2 then .fail .invalidStackOperation
  else
    match readInt64Operand env (topAt st 0) with
    | .error e => .fail e

    | .ok len =>
      let data := topAt st 1
      if len < 0 || (data.length : Int) < len then .fail .invalidNumberRange
      else
        (do
          let (_, st) ← popElem st
          let (_, st) ← popElem st
          pushElem env st (data.take len.toNat) : Except ScriptError State)

-- `left`'s compiled form (#48): the depth test walks at most 2 elements (`Machine.atLeast`).
def leftFast (env : Env) (st : State) : HookR :=
  if !atLeast 2 st.stack then .fail .invalidStackOperation
  else
    match readInt64Operand env (topAt st 0) with
    | .error e => .fail e

    | .ok len =>
      let data := topAt st 1
      if len < 0 || (data.length : Int) < len then .fail .invalidNumberRange
      else
        (do
          let (_, st) ← popElem st
          let (_, st) ← popElem st
          pushElem env st (data.take len.toNat) : Except ScriptError State)

/-- `@[csimp]` (#48): the compiler runs `leftFast`, whose depth test walks at most 2 elements of the stack (`Machine.atLeast_eq`) where `left`'s `st.stack.length < 2` measures it whole; nothing in the semantics moves, every theorem about `left` is about the definition. -/
@[csimp] theorem left_eq_fast : @left = @leftFast := by
  funext env st
  unfold left leftFast
  by_cases h : st.stack.length < 2
  · have h' : atLeast 2 st.stack = false := by rw [atLeast_eq, decide_eq_false_iff_not]; omega
    simp only [h, h']
    rfl
  · have h' : atLeast 2 st.stack = true := by rw [atLeast_eq, decide_eq_true_eq]; omega
    simp only [h, h']
    rfl

/-- [SRC] v1.2.3 `6504a3af`, `OP_RIGHT` (`667–691`): as `OP_LEFT`, the data shrunk to its last `len`
bytes (`688`). -/
def right (env : Env) (st : State) : HookR :=
  if st.stack.length < 2 then .fail .invalidStackOperation
  else
    match readInt64Operand env (topAt st 0) with
    | .error e => .fail e

    | .ok len =>
      let data := topAt st 1
      if len < 0 || (data.length : Int) < len then .fail .invalidNumberRange
      else
        (do
          let (_, st) ← popElem st
          let (_, st) ← popElem st
          pushElem env st (data.drop (data.length - len.toNat)) : Except ScriptError State)

-- `right`'s compiled form (#48): the depth test walks at most 2 elements (`Machine.atLeast`).
def rightFast (env : Env) (st : State) : HookR :=
  if !atLeast 2 st.stack then .fail .invalidStackOperation
  else
    match readInt64Operand env (topAt st 0) with
    | .error e => .fail e

    | .ok len =>
      let data := topAt st 1
      if len < 0 || (data.length : Int) < len then .fail .invalidNumberRange
      else
        (do
          let (_, st) ← popElem st
          let (_, st) ← popElem st
          pushElem env st (data.drop (data.length - len.toNat)) : Except ScriptError State)

/-- `@[csimp]` (#48): the compiler runs `rightFast`, whose depth test walks at most 2 elements of the stack (`Machine.atLeast_eq`) where `right`'s `st.stack.length < 2` measures it whole; nothing in the semantics moves, every theorem about `right` is about the definition. -/
@[csimp] theorem right_eq_fast : @right = @rightFast := by
  funext env st
  unfold right rightFast
  by_cases h : st.stack.length < 2
  · have h' : atLeast 2 st.stack = false := by rw [atLeast_eq, decide_eq_false_iff_not]; omega
    simp only [h, h']
    rfl
  · have h' : atLeast 2 st.stack = true := by rw [atLeast_eq, decide_eq_true_eq]; omega
    simp only [h, h']
    rfl

/-- The bit count of the number shifts (`706–716`, `742–752`): read with
`big_int = true` (the ordinary number read), negative is
`SCRIPT_ERR_INVALID_NUMBER_RANGE`; a count above `INT_MAX` throws
`big_int_error` in `bint::operator<<=`/`>>=` (`big_int.cpp:359–366`, `:383–390`),
caught as `SCRIPT_ERR_BIG_INT` (`1819–1822`). -/
def INT_MAX : Int := 2 ^ 31 - 1

/-- `OP_LSHIFTNUM` (`692–727`): `values <<= n` on the `bint` branch
(`script_num.cpp:306–319`): the size of the value plus `n / 8` bytes may not
exceed the number width (`scriptnum_overflow_error`), then the shift, then the
result's width checked again; the result `v · 2ⁿ` (`BN_lshift` on a
sign-magnitude number). -/
def lshiftnum (env : Env) (st : State) : HookR :=
  if st.stack.length < 2 then .fail .invalidStackOperation
  else
    match Arith.readOperand env (topAt st 0) with
    | .error e => .fail e
    | .ok n =>
      if n < 0 then .fail .invalidNumberRange
      else
        match Arith.readOperand env (topAt st 1) with
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
                let (_, st) ← popElem st
                let (_, st) ← popElem st
                pushElem env st (encode r) : Except ScriptError State)

-- `lshiftnum`'s compiled form (#48): the depth test walks at most 2 elements (`Machine.atLeast`).
def lshiftnumFast (env : Env) (st : State) : HookR :=
  if !atLeast 2 st.stack then .fail .invalidStackOperation
  else
    match Arith.readOperand env (topAt st 0) with
    | .error e => .fail e
    | .ok n =>
      if n < 0 then .fail .invalidNumberRange
      else
        match Arith.readOperand env (topAt st 1) with
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
                let (_, st) ← popElem st
                let (_, st) ← popElem st
                pushElem env st (encode r) : Except ScriptError State)

/-- `@[csimp]` (#48): the compiler runs `lshiftnumFast`, whose depth test walks at most 2 elements of the stack (`Machine.atLeast_eq`) where `lshiftnum`'s `st.stack.length < 2` measures it whole; nothing in the semantics moves, every theorem about `lshiftnum` is about the definition. -/
@[csimp] theorem lshiftnum_eq_fast : @lshiftnum = @lshiftnumFast := by
  funext env st
  unfold lshiftnum lshiftnumFast
  by_cases h : st.stack.length < 2
  · have h' : atLeast 2 st.stack = false := by rw [atLeast_eq, decide_eq_false_iff_not]; omega
    simp only [h, h']
    rfl
  · have h' : atLeast 2 st.stack = true := by rw [atLeast_eq, decide_eq_true_eq]; omega
    simp only [h, h']
    rfl

/-- `OP_RSHIFTNUM` (`728–764`): `values >>= n` on the `bint` branch
(`script_num.cpp:367–372`): `BN_rshift` on a sign-magnitude number, the
magnitude shifted, so the quotient toward zero (`Int.tdiv`); a count at or above
the value's bit width gives zero. -/
def rshiftnum (env : Env) (st : State) : HookR :=
  if st.stack.length < 2 then .fail .invalidStackOperation
  else
    match Arith.readOperand env (topAt st 0) with
    | .error e => .fail e
    | .ok n =>
      if n < 0 then .fail .invalidNumberRange
      else
        match Arith.readOperand env (topAt st 1) with
        | .error e => .fail e
        | .ok v =>
          if INT_MAX < n then .fail .bigInt
          else
            let r := if (8 * (encode v).length : Int) ≤ n then 0 else Int.tdiv v (2 ^ n.toNat)
            (do
              let (_, st) ← popElem st
              let (_, st) ← popElem st
              pushElem env st (encode r) : Except ScriptError State)

-- `rshiftnum`'s compiled form (#48): the depth test walks at most 2 elements (`Machine.atLeast`).
def rshiftnumFast (env : Env) (st : State) : HookR :=
  if !atLeast 2 st.stack then .fail .invalidStackOperation
  else
    match Arith.readOperand env (topAt st 0) with
    | .error e => .fail e
    | .ok n =>
      if n < 0 then .fail .invalidNumberRange
      else
        match Arith.readOperand env (topAt st 1) with
        | .error e => .fail e
        | .ok v =>
          if INT_MAX < n then .fail .bigInt
          else
            let r := if (8 * (encode v).length : Int) ≤ n then 0 else Int.tdiv v (2 ^ n.toNat)
            (do
              let (_, st) ← popElem st
              let (_, st) ← popElem st
              pushElem env st (encode r) : Except ScriptError State)

/-- `@[csimp]` (#48): the compiler runs `rshiftnumFast`, whose depth test walks at most 2 elements of the stack (`Machine.atLeast_eq`) where `rshiftnum`'s `st.stack.length < 2` measures it whole; nothing in the semantics moves, every theorem about `rshiftnum` is about the definition. -/
@[csimp] theorem rshiftnum_eq_fast : @rshiftnum = @rshiftnumFast := by
  funext env st
  unfold rshiftnum rshiftnumFast
  by_cases h : st.stack.length < 2
  · have h' : atLeast 2 st.stack = false := by rw [atLeast_eq, decide_eq_false_iff_not]; omega
    simp only [h, h']
    rfl
  · have h' : atLeast 2 st.stack = true := by rw [atLeast_eq, decide_eq_true_eq]; omega
    simp only [h, h']
    rfl

/-- The family hook: `0xb3`–`0xb7`, the pre-Chronicle NOP rule first. -/
def exec : OpExec := fun op _ env st =>
  if Op.OP_SUBSTR ≤ op && op ≤ Op.OP_RSHIFTNUM then
    some (if !env.utxoAfterChronicle then nopOrDiscourage env st
          else if op = Op.OP_SUBSTR then substr env st
          else if op = Op.OP_LEFT then left env st
          else if op = Op.OP_RIGHT then right env st
          else if op = Op.OP_LSHIFTNUM then lshiftnum env st
          else rshiftnum env st)
  else none

end BsvScript.Ops.Expansion
