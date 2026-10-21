import BsvScript.Machine
/-!
# BsvScript.Ops.Arith

The numeric opcodes (#9; `docs/DESIGN.md` §3): the unary family `OP_1ADD` …
`OP_0NOTEQUAL` (`interpreter.cpp:1222–1275`), the binary family `OP_ADD` …
`OP_MAX` (`1277–1378`) and `OP_WITHIN` (`1380–1399`), on the number type of
`BsvScript.Numbers` with the operand read and the result write of `CScriptNum`
(`src/script/script_num.cpp`, `src/big_int.cpp`). Bare line numbers are
`interpreter.cpp` at the pin (`docs/PROVENANCE.md`).

The arithmetic is exact integer arithmetic: post-Genesis the reference computes
on `bsv::bint` (OpenSSL `BIGNUM`; `big_int.cpp`), pre-Genesis on `int64_t`
with 4-byte operands, and both agree with `Int` where they are defined. Division
and modulus truncate toward zero with the remainder taking the dividend's sign
(`BN_div`/`BN_mod`, `big_int.cpp:238–262`; C++ `/`/`%` on `int64_t`): `Int.tdiv`
and `Int.tmod`.
-/

namespace BsvScript.Ops.Arith
open BsvScript.Params BsvScript.Numbers BsvScript.Machine

/-- The operand read `CScriptNum{top, requireMinimal, params.MaxScriptNumLength(),
utxo_after_genesis}` (`1235`, `1300–1301`, `1386–1390`; the constructor
`script_num.cpp:53–91`): more bytes than the `MaxScriptNumLength` in force is
`scriptnum_overflow_error` (`:62–65`, caught at `1807–1809` as
`SCRIPT_ERR_SCRIPTNUM_OVERFLOW`); a non-minimal encoding under `requireMinimal`
is `scriptnum_minencode_error` (`:67–70`, caught at `1811–1813` as
`SCRIPT_ERR_SCRIPTNUM_MINENCODE`); the value is `bint::deserialize`
(`big_int.cpp:577–593`, the script-number decoding at any width) post-Genesis
and the `int64` reader (`int_serialization.h:61–118`) on at most 4 bytes
pre-Genesis; both are `decode` (`Numbers.deserializeInt64_eq_decode`). As
`NodeConfig.limitsFor` sets the width in force, it is 4 bytes for a pre-Genesis
UTXO; post-Genesis the consensus width of the UTXO's era on the block path
(750,000 bytes, 32,000,000 post-Chronicle) and, on the mempool path, the node's
policy setting `-maxscriptnumlengthpolicy` (default 10,000, `policy.h:156`). -/
def readOperand (env : Env) (bs : Bytes) : Except ScriptError Int :=
  if env.params.limits.maxScriptNumLength < bs.length then .error .scriptnumOverflow
  else if env.requireMinimal && !isMinimallyEncoded bs env.params.limits.maxScriptNumLength then
    .error .scriptnumMinencode
  else .ok (decode bs)

/-- The result write `bn.getvch()` (`1274`, `1369`; `script_num.cpp:465–483`):
`bint::serialize` (`big_int.cpp:559–568`) and `bsv::serialize` of an `int64`
are both the minimal script-number encoding, `encode`. Post-Genesis a result of
`+=`, `-=`, `*=` whose encoding exceeds `m_max_length` (the left operand's
`MaxScriptNumLength`; `script_num.cpp:166–167`, `script_num.cpp:196–197`, `script_num.cpp:216–217`, the
copy at `script_num.h:114–130`)
is `scriptnum_overflow_error`; so is a negation whose encoding exceeds it
(the constructor, `script_num.cpp:45–51`; never, the magnitude is unchanged).
Pre-Genesis the `int64` branch has only an `assert` (4-byte operands cannot
overflow it) and the result is pushed at whatever width. -/
def pushResult (env : Env) (st : State) (v : Int) (bounded : Bool) : Except ScriptError State :=
  let bs := encode v
  if bounded && env.utxoAfterGenesis && env.params.limits.maxScriptNumLength < bs.length then
    .error .scriptnumOverflow
  else pushElem env st bs

/-- A boolean result: `bn = (…)` assigns an `int64` `1` or `0` (`script_num.h:65–69`),
serialized as `[0x01]` or `[]`; `OP_WITHIN` pushes `vchTrue`/`vchFalse` instead (`interpreter.cpp:402–403`,
`1396`), the same two byte strings. -/
def pushBool (env : Env) (st : State) (b : Bool) : Except ScriptError State :=
  pushResult env st (if b then 1 else 0) false

/-- The value of a unary opcode (`1235–1270`). `OP_2MUL` is `bn += bn`
(`1247–1249`), `OP_2DIV` is `bn /= 2` (`1251–1253`), both reachable only when
the UTXO era is post-Chronicle (`IsOpcodeDisabled`, `360–375`, checked by the
loop at `470–471`). -/
def unaryValue (op : Nat) (v : Int) : Int :=
  if op = Op.OP_1ADD then v + 1                                 -- 1237–1241
  else if op = Op.OP_1SUB then v - 1                            -- 1242–1246
  else if op = Op.OP_2MUL then v + v                            -- 1247–1250
  else if op = Op.OP_2DIV then Int.tdiv v 2                     -- 1251–1254
  else if op = Op.OP_NEGATE then -v                             -- 1255–1257
  else if op = Op.OP_ABS then (if v < 0 then -v else v)         -- 1258–1262
  else if op = Op.OP_NOT then (if v = 0 then 1 else 0)          -- 1263–1265
  else (if v ≠ 0 then 1 else 0)                                 -- OP_0NOTEQUAL, 1266–1268

/-- The unary opcodes whose result passes the post-Genesis width bound
(`+=`, `-=`, the negation's constructor): all but `OP_2DIV`, `OP_NOT` and
`OP_0NOTEQUAL` (booleans are `int64` assignments, `script_num.h:65–69`). -/
def unaryBounded (op : Nat) : Bool :=
  op ≠ Op.OP_2DIV && op ≠ Op.OP_NOT && op ≠ Op.OP_0NOTEQUAL

/-- The unary family (`1222–1275`): one operand read (`1235`), popped (`1273`),
the result pushed (`1274`). -/
def unary (env : Env) (op : Nat) (st : State) : Except ScriptError State := do
  if st.stack.length < 1 then throw .invalidStackOperation                    -- 1231–1232
  let (top, st) ← popElem st
  let v ← readOperand env top
  pushResult env st (unaryValue op v) (unaryBounded op)

-- `unary`'s compiled form (#48): the depth test walks at most 1 element (`Machine.atLeast`).
def unaryFast (env : Env) (op : Nat) (st : State) : Except ScriptError State := do
  if !atLeast 1 st.stack then throw .invalidStackOperation                    -- 1231–1232
  let (top, st) ← popElem st
  let v ← readOperand env top
  pushResult env st (unaryValue op v) (unaryBounded op)

/-- `@[csimp]` (#48): the compiler runs `unaryFast`, whose depth test walks at most 1 element of the stack (`Machine.atLeast_eq`) where `unary`'s `st.stack.length < 1` measures it whole; nothing in the semantics moves, every theorem about `unary` is about the definition. -/
@[csimp] theorem unary_eq_fast : @unary = @unaryFast := by
  funext env op st
  unfold unary unaryFast
  by_cases h : st.stack.length < 1
  · have h' : atLeast 1 st.stack = false := by rw [atLeast_eq, decide_eq_false_iff_not]; omega
    simp only [h, h']
    rfl
  · have h' : atLeast 1 st.stack = true := by rw [atLeast_eq, decide_eq_true_eq]; omega
    simp only [h, h']
    rfl

/-- The value of a binary opcode (`1303–1361`); `OP_DIV` and `OP_MOD` refuse a
zero divisor (`1316–1329`); `OP_MIN`/`OP_MAX` copy an operand (`1357–1361`),
re-serialized minimally. -/
def binaryValue (op : Nat) (v1 v2 : Int) : Except ScriptError Int :=
  if op = Op.OP_ADD then .ok (v1 + v2)                                         -- 1304–1306
  else if op = Op.OP_SUB then .ok (v1 - v2)                                    -- 1308–1310
  else if op = Op.OP_MUL then .ok (v1 * v2)                                    -- 1312–1314
  else if op = Op.OP_DIV then                                                  -- 1316–1322
    if v2 = 0 then .error .divByZero else .ok (Int.tdiv v1 v2)
  else if op = Op.OP_MOD then                                                  -- 1324–1330
    if v2 = 0 then .error .modByZero else .ok (Int.tmod v1 v2)
  else if op = Op.OP_BOOLAND then .ok (if v1 ≠ 0 && v2 ≠ 0 then 1 else 0)      -- 1332–1334
  else if op = Op.OP_BOOLOR then .ok (if v1 ≠ 0 || v2 ≠ 0 then 1 else 0)       -- 1335–1337
  else if op = Op.OP_NUMEQUAL || op = Op.OP_NUMEQUALVERIFY then                -- 1338–1341
    .ok (if v1 = v2 then 1 else 0)
  else if op = Op.OP_NUMNOTEQUAL then .ok (if v1 ≠ v2 then 1 else 0)           -- 1342–1344
  else if op = Op.OP_LESSTHAN then .ok (if v1 < v2 then 1 else 0)              -- 1345–1347
  else if op = Op.OP_GREATERTHAN then .ok (if v1 > v2 then 1 else 0)           -- 1348–1350
  else if op = Op.OP_LESSTHANOREQUAL then .ok (if v1 ≤ v2 then 1 else 0)       -- 1351–1353
  else if op = Op.OP_GREATERTHANOREQUAL then .ok (if v1 ≥ v2 then 1 else 0)    -- 1354–1356
  else if op = Op.OP_MIN then .ok (if v1 < v2 then v1 else v2)                 -- 1357–1359
  else .ok (if v1 > v2 then v1 else v2)                                        -- OP_MAX, 1360–1362

/-- The binary opcodes whose result passes the post-Genesis width bound:
`OP_ADD`, `OP_SUB`, `OP_MUL` (`+=`, `-=`, `*=`, `script_num.cpp:166–167`, `script_num.cpp:196–197`,
`script_num.cpp:216–217`). -/
def binaryBounded (op : Nat) : Bool :=
  op = Op.OP_ADD || op = Op.OP_SUB || op = Op.OP_MUL

/-- The binary family (`1277–1378`): `bn1` is the second element, `bn2` the top,
read in that order (`1300–1301`); both popped (`1367–1368`); the result pushed
(`1369`); `OP_NUMEQUALVERIFY` then pops a true result or fails (`1371–1377`). -/
def binary (env : Env) (op : Nat) (st : State) : Except ScriptError State := do
  if st.stack.length < 2 then throw .invalidStackOperation                    -- 1294–1296
  let (b2, st) ← popElem st
  let (b1, st) ← popElem st
  let v1 ← readOperand env b1
  let v2 ← readOperand env b2
  let r ← binaryValue op v1 v2
  let st ← pushResult env st r (binaryBounded op)
  if op = Op.OP_NUMEQUALVERIFY then
    if castToBool (st.stack.headD []) then
      match popElem st with
      | .ok (_, st') => pure st'
      | .error e => throw e
    else throw .numequalverify
  else pure st

-- `binary`'s compiled form (#48): the depth test walks at most 2 elements (`Machine.atLeast`).
def binaryFast (env : Env) (op : Nat) (st : State) : Except ScriptError State := do
  if !atLeast 2 st.stack then throw .invalidStackOperation                    -- 1294–1296
  let (b2, st) ← popElem st
  let (b1, st) ← popElem st
  let v1 ← readOperand env b1
  let v2 ← readOperand env b2
  let r ← binaryValue op v1 v2
  let st ← pushResult env st r (binaryBounded op)
  if op = Op.OP_NUMEQUALVERIFY then
    if castToBool (st.stack.headD []) then
      match popElem st with
      | .ok (_, st') => pure st'
      | .error e => throw e
    else throw .numequalverify
  else pure st

/-- `@[csimp]` (#48): the compiler runs `binaryFast`, whose depth test walks at most 2 elements of the stack (`Machine.atLeast_eq`) where `binary`'s `st.stack.length < 2` measures it whole; nothing in the semantics moves, every theorem about `binary` is about the definition. -/
@[csimp] theorem binary_eq_fast : @binary = @binaryFast := by
  funext env op st
  unfold binary binaryFast
  by_cases h : st.stack.length < 2
  · have h' : atLeast 2 st.stack = false := by rw [atLeast_eq, decide_eq_false_iff_not]; omega
    simp only [h, h']
    rfl
  · have h' : atLeast 2 st.stack = true := by rw [atLeast_eq, decide_eq_true_eq]; omega
    simp only [h, h']
    rfl

/-- `OP_WITHIN` (`1380–1399`): `x` is the third element, `min` the second, `max`
the top, read in that order (`1385–1390`); the result is `min ≤ x ∧ x < max`
(`1391`), pushed as the boolean vectors after three pops (`1392–1396`). -/
def within (env : Env) (st : State) : Except ScriptError State := do
  if st.stack.length < 3 then throw .invalidStackOperation                    -- 1382–1383
  let (b3, st) ← popElem st
  let (b2, st) ← popElem st
  let (b1, st) ← popElem st
  let x ← readOperand env b1
  let lo ← readOperand env b2
  let hi ← readOperand env b3
  pushBool env st (lo ≤ x && x < hi)

-- `within`'s compiled form (#48): the depth test walks at most 3 elements (`Machine.atLeast`).
def withinFast (env : Env) (st : State) : Except ScriptError State := do
  if !atLeast 3 st.stack then throw .invalidStackOperation                    -- 1382–1383
  let (b3, st) ← popElem st
  let (b2, st) ← popElem st
  let (b1, st) ← popElem st
  let x ← readOperand env b1
  let lo ← readOperand env b2
  let hi ← readOperand env b3
  pushBool env st (lo ≤ x && x < hi)

/-- `@[csimp]` (#48): the compiler runs `withinFast`, whose depth test walks at most 3 elements of the stack (`Machine.atLeast_eq`) where `within`'s `st.stack.length < 3` measures it whole; nothing in the semantics moves, every theorem about `within` is about the definition. -/
@[csimp] theorem within_eq_fast : @within = @withinFast := by
  funext env st
  unfold within withinFast
  by_cases h : st.stack.length < 3
  · have h' : atLeast 3 st.stack = false := by rw [atLeast_eq, decide_eq_false_iff_not]; omega
    simp only [h, h']
    rfl
  · have h' : atLeast 3 st.stack = true := by rw [atLeast_eq, decide_eq_true_eq]; omega
    simp only [h, h']
    rfl

/-- The unary family's opcode range `0x8b`–`0x92` (`opcodes.h`). -/
def isUnary (op : Nat) : Bool := Op.OP_1ADD ≤ op && op ≤ Op.OP_0NOTEQUAL
/-- The binary family's opcode range `0x93`–`0xa4` without the bit shifts
`OP_LSHIFT`/`OP_RSHIFT` (`0x98`/`0x99`, `BsvScript.Ops.Bitwise`). -/
def isBinary (op : Nat) : Bool :=
  Op.OP_ADD ≤ op && op ≤ Op.OP_MAX && op ≠ Op.OP_LSHIFT && op ≠ Op.OP_RSHIFT

/-- The family hook. -/
def exec : OpExec := fun op _ env st =>
  if isUnary op then some (unary env op st)
  else if isBinary op then some (binary env op st)
  else if op = Op.OP_WITHIN then some (within env st)
  else none

end BsvScript.Ops.Arith

namespace BsvScript.Ops.Arith
open BsvScript.Numbers BsvScript.Machine

/-! ## The error paths, pinned -/

/-- T-A1: `OP_DIV` by zero is its dedicated error, `SCRIPT_ERR_DIV_BY_ZERO`, whatever the dividend
(`1318–1319`). -/
theorem binaryValue_div_zero (v : Int) : binaryValue Op.OP_DIV v 0 = .error .divByZero := by
  simp [binaryValue, Op.OP_DIV, Op.OP_ADD, Op.OP_SUB, Op.OP_MUL]
/-- T-A1: `OP_MOD` by zero is its dedicated error, `SCRIPT_ERR_MOD_BY_ZERO`, whatever the dividend
(`1326–1327`). -/
theorem binaryValue_mod_zero (v : Int) : binaryValue Op.OP_MOD v 0 = .error .modByZero := by
  simp [binaryValue, Op.OP_MOD, Op.OP_DIV, Op.OP_ADD, Op.OP_SUB, Op.OP_MUL]

/-- T-A2: an operand the read accepts is no longer than the number width in force,
`maxScriptNumLength` (the test `script_num.cpp:62–65`). As `NodeConfig.limitsFor` sets that width, it is
4 bytes for a pre-Genesis UTXO (`consensus.h:62`); post-Genesis the consensus width of the UTXO's era on the
block path (750,000 bytes, 32,000,000 post-Chronicle, `:64`, `:66`), and on the mempool path the node's
policy setting `-maxscriptnumlengthpolicy` (default 10,000, `policy.h:156`; 0 falls back to the consensus
width, `configscriptpolicy.cpp:97–106`). -/
theorem readOperand_length_le (env : Machine.Env) (bs : Bytes) (v : Int)
    (h : readOperand env bs = .ok v) : bs.length ≤ env.params.limits.maxScriptNumLength := by
  unfold readOperand at h
  by_cases hlt : env.params.limits.maxScriptNumLength < bs.length
  · simp [hlt] at h
  · exact Nat.le_of_not_lt hlt

end BsvScript.Ops.Arith
