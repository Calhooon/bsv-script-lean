import BsvScript.Machine
import BsvScript.Ops.Arith
import BsvScript.Ops.Stack
/-!
# BsvScript.Ops.Splice

The splice and conversion opcodes (#10; `docs/DESIGN.md` §3): `OP_CAT`
(`interpreter.cpp:1687–1706`), `OP_SPLIT` (`1708–1736`), `OP_NUM2BIN`
(`1741–1778`), `OP_BIN2NUM` (`1780–1792`). Bare line numbers are
`interpreter.cpp` at the pin (`docs/PROVENANCE.md`).

[SRC] v1.2.3 `6504a3af`, `interpreter.cpp:1718–1721`: `OP_SPLIT`
refuses a position above `INT32_MAX` before `to_size_t_limited`.
The previous pin's reading is retained in a history module withheld from the
public edition at the maintainers' request (group `d8-node-team-discretion`).
The `OP_PICK`/`OP_ROLL` Q8 reading is separate and unchanged.
-/

namespace BsvScript.Ops.Splice
open BsvScript.Params BsvScript.Numbers BsvScript.Machine BsvScript.Ops.Stack

/-- `OP_CAT` (`1687–1706`): pre-Genesis the concatenation may not exceed
`MAX_SCRIPT_ELEMENT_SIZE_BEFORE_GENESIS` (`1699–1702`, `script.h:29`); the top
popped and appended to the second (`1704–1705`). -/
def cat (env : Env) (st : State) : Except ScriptError State := do
  need st 2
  let v1 := topAt st 1
  let v2 := topAt st 0
  if !env.utxoAfterGenesis && Consensus.maxScriptElementSizeBeforeGenesis < v1.length + v2.length then
    throw .pushSize
  let (_, st) ← popElem st
  let (_, st) ← popElem st
  pushElem env st (v1 ++ v2)

/-- The position guard of `OP_SPLIT`, [SRC] v1.2.3 `6504a3af`,
`interpreter.cpp:1718–1719`: negative, above `INT32_MAX`, or past the element.
The 32-bit bound is an opcode validity rule, independent of relay policy. -/
def invalidSplitPosition (size : Nat) (n : Int) : Bool :=
  n < 0 || (2147483647 : Int) < n || (size : Int) < n

/-- The split guard admits exactly the nonnegative positions bounded by both
`INT32_MAX` and the element length. [SRC] `6504a3af`, `interpreter.cpp:1718–1719`.
Testing this predicate needs no allocation of a multi-gigabyte element. -/
theorem invalidSplitPosition_eq_false (size : Nat) (n : Int) :
    invalidSplitPosition size n = false ↔ 0 ≤ n ∧ n ≤ 2147483647 ∧ n ≤ (size : Int) := by
  simp [invalidSplitPosition, Bool.or_eq_false_iff, not_lt, and_assoc]

/-- `OP_SPLIT`, [SRC] v1.2.3 `6504a3af`, `interpreter.cpp:1708–1736`:
the position is read at `1716–1717`; outside `0 … min(size, INT32_MAX)` is
`SCRIPT_ERR_INVALID_SPLIT_RANGE` (`1718–1719`); both operands are popped and
the halves pushed (`1730–1735`). The previous pin's reading is retained in a history module withheld from the
public edition at the maintainers' request (group `d8-node-team-discretion`). -/
def split (env : Env) (st : State) : Except ScriptError State := do
  need st 2
  let data := topAt st 1
  let n ← Arith.readOperand env (topAt st 0)
  if invalidSplitPosition data.length n then throw .invalidSplitRange
  let (_, st) ← popElem st
  let (_, st) ← popElem st
  let st ← pushElem env st (data.take n.toNat)
  pushElem env st (data.drop n.toNat)

/-- `OP_NUM2BIN` (`1741–1778`): the width read as a number (`1746–1747`);
negative or above `INT32_MAX` is `SCRIPT_ERR_PUSH_SIZE` (`1748–1749`), so is a
pre-Genesis width above 520 (`1752–1753`); the width popped; the number
minimally encoded in place (`1760`, `bsv::MinimallyEncode`, the reference
algorithm `Numbers.minimallyEncodeRef`, `encode ∘ decode` on bytes by T4); wider than the
width is `SCRIPT_ERR_IMPOSSIBLE_ENCODING` (`1761–1763`); equal is kept
(`1767–1769`); else the sign bit moves to the last byte of the zero padding
(`1771–1777`). `Numbers.num2bin` is exactly this (T7).

The memory refusal comes BEFORE the padded element is built (#142). [SRC] v1.2.3
`6504a3af`, `limitedstack.cpp:60–71`: `padRight` charges the growth
(`increaseCombinedStackSize(sizeDifference)`, `:66`) before `resize` (`:68`), and
`limitedstack.cpp:194–207` throws `stack_overflow_error` when
`getCombinedStackSize() + additionalSize > maxStackSize` (`:202–204`), mapped to
`SCRIPT_ERR_STACK_SIZE` (`interpreter.cpp:1815–1818`). The counter there holds the
minimally encoded number at its own charge (`limitedstack.cpp:113–120`), so the
refusal is exactly `memUsed + width + elementOverhead` over the limit, `pushElem`'s
own test on an element of `width` bytes: the verdict is the late push's on every
state, and the bytes are never made. The equal case is tested as the late push
tested it, where the reference charges nothing (`1767–1769`); the test admits it on
every state whose counter is within the limit, the element being no longer than the
one popped (no theorem states that invariant). -/
def num2binOp (env : Env) (st : State) : Except ScriptError State := do
  need st 2
  let n ← Arith.readOperand env (topAt st 0)
  if n < 0 || (2147483647 : Int) < n then throw .pushSize
  let width := n.toNat
  if !env.utxoAfterGenesis && Consensus.maxScriptElementSizeBeforeGenesis < width then throw .pushSize
  let (_, st) ← popElem st
  let (raw, st) ← popElem st
  if width < (minimallyEncode raw).length then throw .impossibleEncoding
  if env.params.limits.maxStackMemoryUsage < st.memUsed + width + elementOverhead then throw .stackSize
  match num2bin raw width with
  -- unreachable after the test above; kept so `num2bin` is used as T7 states it
  | none => throw .impossibleEncoding
  | some r => pushElem env st r

/-- `OP_BIN2NUM` (`1780–1792`): the top minimally encoded in place (`1786`);
the result must be a number of the width in force (`1789–1790`,
`bsv::IsMinimallyEncoded(…, MaxScriptNumLength)`; 4 bytes for a pre-Genesis coin
on either path, and after Genesis the consensus width on the block path and the
node's policy setting on the mempool path, as for `Ops.Arith.readOperand`), else
`SCRIPT_ERR_INVALID_NUMBER_RANGE`. -/
def bin2num (env : Env) (st : State) : Except ScriptError State := do
  need st 1
  let (raw, st) ← popElem st
  let m := minimallyEncode raw
  if !isMinimallyEncoded m env.params.limits.maxScriptNumLength then throw .invalidNumberRange
  pushElem env st m

/-- The family hook. -/
def exec : OpExec := fun op _ env st =>
  if op = Op.OP_CAT then some (cat env st)
  else if op = Op.OP_SPLIT then some (split env st)
  else if op = Op.OP_NUM2BIN then some (num2binOp env st)
  else if op = Op.OP_BIN2NUM then some (bin2num env st)
  else none

end BsvScript.Ops.Splice

namespace BsvScript.Ops.Splice
open BsvScript.Numbers BsvScript.Machine

/-- T-SP1: the two halves `OP_SPLIT` builds, `data.take n` and `data.drop n` (`n1` and `n2`, `1726–1727`),
reassemble the element. This is the list fact alone, Lean core's `List.take_append_drop` under the spec's
name: it names no opcode and no state. The statement at the opcode is W4 `split_ok`
(`Properties/Widths.lean`). -/
theorem split_halves (data : Bytes) (n : Nat) : data.take n ++ data.drop n = data := List.take_append_drop n data

end BsvScript.Ops.Splice
