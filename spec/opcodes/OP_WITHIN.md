# `OP_WITHIN` (`0xa5`)

**Family** arithmetic (ternary) · **module** `BsvScript.Ops.Arith` · **landed at** #9 · **the switch** `1380–1399` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)
- operands read as `CScriptNum` with the era's width (4 pre-Genesis, 750,000 post-Genesis, 32,000,000 post-Chronicle) and, under MINIMALDATA with the gate, the minimal check (`script_num.cpp:53–89`)

## Semantics (the Lean docstrings that name it)

### `pushBool` (def, `lean/BsvScript/Ops/Arith.lean:59`)

A boolean result: `bn = (…)` assigns an `int64` `1` or `0` (`script_num.h:65–69`),
serialized as `[0x01]` or `[]`; `OP_WITHIN` pushes `vchTrue`/`vchFalse` instead (`interpreter.cpp:402–403`,
`1396`), the same two byte strings.

`[SRC]` `script_num.h:65–69`, `interpreter.cpp:402–403`, `interpreter.cpp:1396`

### `within` (def, `lean/BsvScript/Ops/Arith.lean:189`)

`OP_WITHIN` (`1380–1399`): `x` is the third element, `min` the second, `max`
the top, read in that order (`1385–1390`); the result is `min ≤ x ∧ x < max`
(`1391`), pushed as the boolean vectors after three pops (`1392–1396`).

`[SRC]` `interpreter.cpp:1380–1399`, `interpreter.cpp:1385–1390`, `interpreter.cpp:1391`, `interpreter.cpp:1392–1396`

### `pushBool_abs` (theorem, `lean/BsvScript/Impl/Arith.lean:41`)

**`pushBool_abs`.** *What it says:* the implementation's boolean write stands for the spec's. *What it
assumes:* nothing. *Why it matters:* `OP_WITHIN` (#50).

### `withinI_abs` (theorem, `lean/BsvScript/Impl/Arith.lean:101`)

**`withinI_abs`.** *What it says:* the implementation's `OP_WITHIN` computes what `Ops.Arith.within`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* `OP_WITHIN` on the
implementation (#50).

### `arith_exec_isSome` (theorem, `lean/BsvScript/Properties/Coverage.lean:45`)

The arithmetic family's hook answers exactly on the opcodes it owns: `some` on
the opcodes of `Ops.Arith.isUnary` and `Ops.Arith.isBinary` and on `OP_WITHIN`,
`none` on every other byte, which it leaves to the next hook. One of the six lemmas
`opExec_isSome_of_hookOwns` assembles.

### `within_frame` (theorem, `lean/BsvScript/Properties/Hooks.lean:246`)

`OP_WITHIN` is a frame.

### `vWithin_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:297`)

`5 3 7 OP_WITHIN` is valid: 3 ≤ 5 < 7 (`1380–1397`).

`[SRC]` `interpreter.cpp:1380–1397`

### `pushBool_shape` (theorem, `lean/BsvScript/Properties/Resources.lean:692`)

**R6b (the boolean shape).** *What it says:* `pushBool` leaves `[0x01]` for true and `[]` for false on
top: `OP_WITHIN`'s push, `vchTrue` or `vchFalse` (`interpreter.cpp:402–403`, `1396`); `within` and its
compiled copy are `pushBool`'s only callers. The comparisons and the unary family's booleans leave the same
two byte strings by another road, an `int64` `1` or `0` (`script_num.h:65–69`) pushed through
`pushResult`, which this theorem does not carry.

`[SRC]` `interpreter.cpp:402–403`, `interpreter.cpp:1396`, `script_num.h:65–69`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `num.cmp.numequalverify`, `num.cmp.within` | 20 | `interpreter.cpp:1366–1373`, `1380–1399` |
| `flags.v1.minimaldata.push`, `flags.v1.minimaldata.number` | 36 | `interpreter.cpp:433–434`, `473–479`, `331–358`; `script_num.cpp:53–89`, `int_serialization.h:97–129`; the reads `546`, `577`, `622`, `624`, `655`, `680`, `709`, `717`, `745`, `753`, `1015`, `1129`, `1163`, `1235`, `1300–1301`, `1386–1390`, `1524`, `1551`, `1717`, `1747`; `policy.h:190` |

