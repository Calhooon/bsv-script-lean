import BsvScript.Machine
import BsvScript.Ops.Arith
/-!
# BsvScript.Ops.Bitwise

The bitwise opcodes on byte vectors (#9; `docs/DESIGN.md` §3): `OP_AND`/`OP_OR`/
`OP_XOR` (`interpreter.cpp:1069–1106`), `OP_INVERT` (`1108–1119`),
`OP_LSHIFT`/`OP_RSHIFT` (`1121–1187`, the helpers `52–117`), and the byte-vector
equality `OP_EQUAL`/`OP_EQUALVERIFY` (`1189–1217`). Bare line numbers are
`interpreter.cpp` at the pin (`docs/PROVENANCE.md`).
-/

namespace BsvScript.Ops.Bitwise
open BsvScript.Params BsvScript.Numbers BsvScript.Machine

/-- `vchFalse` and `vchTrue` (`interpreter.cpp`): the empty vector and `[0x01]`. -/
def vchFalse : Bytes := []
def vchTrue : Bytes := [1]

/-- `make_rshift_mask` (`52–56`): the bits of a byte that stay in it under a
right shift by `n` bits. -/
def rmask (n : Nat) : Nat := [0xFF, 0xFE, 0xFC, 0xF8, 0xF0, 0xE0, 0xC0, 0x80].getD n 0
/-- `make_lshift_mask` (`58–62`): the bits of a byte that stay in it under a
left shift by `n` bits. -/
def lmask (n : Nat) : Nat := [0xFF, 0x7F, 0x3F, 0x1F, 0x0F, 0x07, 0x03, 0x01].getD n 0

/-- `RShift` (`65–88`): the vector as a big-endian bit string shifted right by
`n` bits at its width; byte `k` receives the kept bits of byte `k − n/8`
(`75–79`) and the carried bits of byte `k − n/8 − 1` (`81–85`). -/
def rshift (x : Bytes) (n : Nat) : Bytes :=
  let bs := n % 8
  let sh := n / 8
  (List.range x.length).map fun k =>
    let hi := if sh ≤ k then (x.getD (k - sh) 0 &&& rmask bs) >>> bs else 0
    let lo := if sh + 1 ≤ k then ((x.getD (k - sh - 1) 0 &&& (255 - rmask bs)) <<< (8 - bs)) % 256 else 0
    hi ||| lo

/-- `LShift` (`91–117`): the vector shifted left by `n` bits at its width; byte
`k` receives the kept bits of byte `k + n/8` (`104–107`) and the carried bits
of byte `k + n/8 + 1` (`109–113`). -/
def lshift (x : Bytes) (n : Nat) : Bytes :=
  let bs := n % 8
  let sh := n / 8
  (List.range x.length).map fun k =>
    let hi := if k + sh < x.length then ((x.getD (k + sh) 0 &&& lmask bs) <<< bs) % 256 else 0
    let lo := if k + sh + 1 < x.length then (x.getD (k + sh + 1) 0 &&& (255 - lmask bs)) >>> (8 - bs) else 0
    hi ||| lo

/-- `OP_AND`/`OP_OR`/`OP_XOR` (`1069–1106`): two operands of equal size
(`1080–1081`, else `SCRIPT_ERR_INVALID_OPERAND_SIZE`), combined byte by byte
in place, the top popped (`1105`). -/
def bitwise2 (env : Env) (op : Nat) (st : State) : Except ScriptError State := do
  if st.stack.length < 2 then throw .invalidStackOperation                    -- 1073–1074
  let (v2, st) ← popElem st
  let (v1, st) ← popElem st
  if v1.length ≠ v2.length then throw .invalidOperandSize
  let f : Nat → Nat → Nat :=
    if op = Op.OP_AND then (· &&& ·) else if op = Op.OP_OR then (· ||| ·) else (· ^^^ ·)
  pushElem env st (List.zipWith f v1 v2)

-- `bitwise2`'s compiled form (#48): the depth test walks at most 2 elements (`Machine.atLeast`).
def bitwise2Fast (env : Env) (op : Nat) (st : State) : Except ScriptError State := do
  if !atLeast 2 st.stack then throw .invalidStackOperation                    -- 1073–1074
  let (v2, st) ← popElem st
  let (v1, st) ← popElem st
  if v1.length ≠ v2.length then throw .invalidOperandSize
  let f : Nat → Nat → Nat :=
    if op = Op.OP_AND then (· &&& ·) else if op = Op.OP_OR then (· ||| ·) else (· ^^^ ·)
  pushElem env st (List.zipWith f v1 v2)

/-- `@[csimp]` (#48): the compiler runs `bitwise2Fast`, whose depth test walks at most 2 elements of the stack (`Machine.atLeast_eq`) where `bitwise2`'s `st.stack.length < 2` measures it whole; nothing in the semantics moves, every theorem about `bitwise2` is about the definition. -/
@[csimp] theorem bitwise2_eq_fast : @bitwise2 = @bitwise2Fast := by
  funext env op st
  unfold bitwise2 bitwise2Fast
  by_cases h : st.stack.length < 2
  · have h' : atLeast 2 st.stack = false := by rw [atLeast_eq, decide_eq_false_iff_not]; omega
    simp only [h, h']
    rfl
  · have h' : atLeast 2 st.stack = true := by rw [atLeast_eq, decide_eq_true_eq]; omega
    simp only [h, h']
    rfl

/-- `OP_INVERT` (`1108–1119`): every byte complemented in place. -/
def invert (env : Env) (st : State) : Except ScriptError State := do
  if st.stack.length < 1 then throw .invalidStackOperation                    -- 1110–1111
  let (v, st) ← popElem st
  pushElem env st (v.map (255 - ·))

-- `invert`'s compiled form (#48): the depth test walks at most 1 element (`Machine.atLeast`).
def invertFast (env : Env) (st : State) : Except ScriptError State := do
  if !atLeast 1 st.stack then throw .invalidStackOperation                    -- 1110–1111
  let (v, st) ← popElem st
  pushElem env st (v.map (255 - ·))

/-- `@[csimp]` (#48): the compiler runs `invertFast`, whose depth test walks at most 1 element of the stack (`Machine.atLeast_eq`) where `invert`'s `st.stack.length < 1` measures it whole; nothing in the semantics moves, every theorem about `invert` is about the definition. -/
@[csimp] theorem invert_eq_fast : @invert = @invertFast := by
  funext env st
  unfold invert invertFast
  by_cases h : st.stack.length < 1
  · have h' : atLeast 1 st.stack = false := by rw [atLeast_eq, decide_eq_false_iff_not]; omega
    simp only [h, h']
    rfl
  · have h' : atLeast 1 st.stack = true := by rw [atLeast_eq, decide_eq_true_eq]; omega
    simp only [h, h']
    rfl

/-- `OP_LSHIFT`/`OP_RSHIFT` (`1121–1153`, `1155–1187`): the count `n` is a number read as an
operand (`1129`, `1163`, `Ops.Arith.readOperand`), negative is
`SCRIPT_ERR_INVALID_NUMBER_RANGE` (`1130–1131`, `1164–1165`); a count of at least eight times
the width gives zeros (`1137–1138`, `1171–1172`); otherwise the shift by `n`. The reference
shifts in steps of `INT32_MAX` bits (`1141–1149`, `1175–1183`; `getint` saturates at
`INT_MAX`, `script_num.cpp:400–420`); successive width-preserving shifts compose
to the shift by their sum, so one shift by `n` is written here. -/
def shift (env : Env) (op : Nat) (st : State) : Except ScriptError State := do
  if st.stack.length < 2 then throw .invalidStackOperation                    -- 1124–1125, 1158–1159
  let (nb, st) ← popElem st
  let (x, st) ← popElem st
  let n ← Arith.readOperand env nb
  if n < 0 then throw .invalidNumberRange
  let r :=
    if (x.length * 8 : Int) ≤ n then List.replicate x.length 0
    else if op = Op.OP_LSHIFT then lshift x n.toNat else rshift x n.toNat
  pushElem env st r

-- `shift`'s compiled form (#48): the depth test walks at most 2 elements (`Machine.atLeast`).
def shiftFast (env : Env) (op : Nat) (st : State) : Except ScriptError State := do
  if !atLeast 2 st.stack then throw .invalidStackOperation                    -- 1124–1125, 1158–1159
  let (nb, st) ← popElem st
  let (x, st) ← popElem st
  let n ← Arith.readOperand env nb
  if n < 0 then throw .invalidNumberRange
  let r :=
    if (x.length * 8 : Int) ≤ n then List.replicate x.length 0
    else if op = Op.OP_LSHIFT then lshift x n.toNat else rshift x n.toNat
  pushElem env st r

/-- `@[csimp]` (#48): the compiler runs `shiftFast`, whose depth test walks at most 2 elements of the stack (`Machine.atLeast_eq`) where `shift`'s `st.stack.length < 2` measures it whole; nothing in the semantics moves, every theorem about `shift` is about the definition. -/
@[csimp] theorem shift_eq_fast : @shift = @shiftFast := by
  funext env op st
  unfold shift shiftFast
  by_cases h : st.stack.length < 2
  · have h' : atLeast 2 st.stack = false := by rw [atLeast_eq, decide_eq_false_iff_not]; omega
    simp only [h, h']
    rfl
  · have h' : atLeast 2 st.stack = true := by rw [atLeast_eq, decide_eq_true_eq]; omega
    simp only [h, h']
    rfl

/-- `OP_EQUAL`/`OP_EQUALVERIFY` (`1189–1217`): byte-vector equality, the two
popped, the boolean pushed (`1207–1209`); `OP_EQUALVERIFY` pops a true result
or fails with `SCRIPT_ERR_EQUALVERIFY` (`1210–1215`). -/
def equal (env : Env) (op : Nat) (st : State) : Except ScriptError State := do
  if st.stack.length < 2 then throw .invalidStackOperation                    -- 1194–1195
  let (v2, st) ← popElem st
  let (v1, st) ← popElem st
  let eq := decide (v1 = v2)
  let st ← pushElem env st (if eq then vchTrue else vchFalse)
  if op = Op.OP_EQUALVERIFY then
    if eq then
      match popElem st with
      | .ok (_, st') => pure st'
      | .error e => throw e
    else throw .equalverify
  else pure st

-- `equal`'s compiled form (#48): the depth test walks at most 2 elements (`Machine.atLeast`).
def equalFast (env : Env) (op : Nat) (st : State) : Except ScriptError State := do
  if !atLeast 2 st.stack then throw .invalidStackOperation                    -- 1194–1195
  let (v2, st) ← popElem st
  let (v1, st) ← popElem st
  let eq := decide (v1 = v2)
  let st ← pushElem env st (if eq then vchTrue else vchFalse)
  if op = Op.OP_EQUALVERIFY then
    if eq then
      match popElem st with
      | .ok (_, st') => pure st'
      | .error e => throw e
    else throw .equalverify
  else pure st

/-- `@[csimp]` (#48): the compiler runs `equalFast`, whose depth test walks at most 2 elements of the stack (`Machine.atLeast_eq`) where `equal`'s `st.stack.length < 2` measures it whole; nothing in the semantics moves, every theorem about `equal` is about the definition. -/
@[csimp] theorem equal_eq_fast : @equal = @equalFast := by
  funext env op st
  unfold equal equalFast
  by_cases h : st.stack.length < 2
  · have h' : atLeast 2 st.stack = false := by rw [atLeast_eq, decide_eq_false_iff_not]; omega
    simp only [h, h']
    rfl
  · have h' : atLeast 2 st.stack = true := by rw [atLeast_eq, decide_eq_true_eq]; omega
    simp only [h, h']
    rfl

/-- The family hook. -/
def exec : OpExec := fun op _ env st =>
  if op = Op.OP_AND || op = Op.OP_OR || op = Op.OP_XOR then some (bitwise2 env op st)
  else if op = Op.OP_INVERT then some (invert env st)
  else if op = Op.OP_LSHIFT || op = Op.OP_RSHIFT then some (shift env op st)
  else if op = Op.OP_EQUAL || op = Op.OP_EQUALVERIFY then some (equal env op st)
  else none

end BsvScript.Ops.Bitwise

namespace BsvScript.Ops.Bitwise
open BsvScript.Numbers

/-! ## Widths -/

/-- T-B1: the right shift preserves the width (`RShift`'s `result(x.size(), 0x00)`, `72`). -/
theorem rshift_length (x : Bytes) (n : Nat) : (rshift x n).length = x.length := by
  simp [rshift]
/-- T-B1: the left shift preserves the width (`LShift`'s `result(x.size(), 0x00)`, `98`). -/
theorem lshift_length (x : Bytes) (n : Nat) : (lshift x n).length = x.length := by
  simp [lshift]

/-- T-B2: a shift by at least eight times the width is zeros in both helpers: every source byte then lies
outside the vector, so each bounds test fails (the reference's `RShift`/`LShift` likewise write nothing into
their zeroed result, `72`, `75`, `81`, `98`, `102`). The opcodes test such a count and fill the zeros
themselves (`1137–1138`, `1171–1172`; `shift` has the same test), so this says that shortcut and the shift
it skips agree. -/
theorem shift_zero_of_wide (x : Bytes) (n : Nat) (h : 8 * x.length ≤ n) :
    lshift x n = List.replicate x.length 0 ∧ rshift x n = List.replicate x.length 0 := by
  constructor
  · refine List.ext_getElem (by simp [lshift]) fun k _ h2 => ?_
    have hk : k < x.length := by simpa using h2
    simp only [lshift, List.getElem_map, List.getElem_range, List.getElem_replicate]
    split <;> split <;> first | omega | simp
  · refine List.ext_getElem (by simp [rshift]) fun k _ h2 => ?_
    have hk : k < x.length := by simpa using h2
    simp only [rshift, List.getElem_map, List.getElem_range, List.getElem_replicate]
    split <;> split <;> first | omega | simp

end BsvScript.Ops.Bitwise
