# `OP_2DIV` (`0x8e`)

**Family** arithmetic (unary) · **module** `BsvScript.Ops.Arith` · **landed at** #9 · **the switch** `1222–1275` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- disabled unless the UTXO era is post-Chronicle (`IsOpcodeDisabled` `360–375`); pre-Genesis it fails even unexecuted (`470–471`)
- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)
- operands read as `CScriptNum` with the era's width (4 pre-Genesis, 750,000 post-Genesis, 32,000,000 post-Chronicle) and, under MINIMALDATA with the gate, the minimal check (`script_num.cpp:53–89`)

## Semantics (the Lean docstrings that name it)

### `unaryValue` (def, `lean/BsvScript/Ops/Arith.lean:65`)

The value of a unary opcode (`1235–1270`). `OP_2MUL` is `bn += bn`
(`1247–1249`), `OP_2DIV` is `bn /= 2` (`1251–1253`), both reachable only when
the UTXO era is post-Chronicle (`IsOpcodeDisabled`, `360–375`, checked by the
loop at `470–471`).

`[SRC]` `interpreter.cpp:1235–1270`, `interpreter.cpp:1247–1249`, `interpreter.cpp:1251–1253`, `interpreter.cpp:360–375`, `interpreter.cpp:470–471`

### `unaryBounded` (def, `lean/BsvScript/Ops/Arith.lean:79`)

The unary opcodes whose result passes the post-Genesis width bound
(`+=`, `-=`, the negation's constructor): all but `OP_2DIV`, `OP_NOT` and
`OP_0NOTEQUAL` (booleans are `int64` assignments, `script_num.h:65–69`).

`[SRC]` `script_num.h:65–69`

### `isOpcodeDisabled` (def, `lean/BsvScript/Machine.lean:82`)

`IsOpcodeDisabled` (`360–375`): `OP_2MUL`/`OP_2DIV` unless the UTXO era is
post-Chronicle.

`[SRC]` `interpreter.cpp:360–375`

### `loop_disabled_preGenesis` (theorem, `lean/BsvScript/Properties/Eras.lean:471`)

**A disabled opcode fails even unexecuted on a pre-Genesis coin** (`470–471`:
`IsOpcodeDisabled(opcode, utxoEra) && (!utxo_after_genesis || fExec)`; `360–375`:
`OP_2MUL`/`OP_2DIV` unless the coin is post-Chronicle). The op count is charged first (`466`).

`[SRC]` `interpreter.cpp:470–471`, `interpreter.cpp:360–375`, `interpreter.cpp:466`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `num.arith.2mul`, `num.arith.2div` | 4 | `interpreter.cpp:360–375`, `470–471`, `1247–1254` |

