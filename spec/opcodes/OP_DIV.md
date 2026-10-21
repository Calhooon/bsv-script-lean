# `OP_DIV` (`0x96`)

**Family** arithmetic (binary) · **module** `BsvScript.Ops.Arith` · **landed at** #9 · **the switch** `1277–1378` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)
- operands read as `CScriptNum` with the era's width (4 pre-Genesis, 750,000 post-Genesis, 32,000,000 post-Chronicle) and, under MINIMALDATA with the gate, the minimal check (`script_num.cpp:53–89`)

## Semantics (the Lean docstrings that name it)

### `binaryValue` (def, `lean/BsvScript/Ops/Arith.lean:112`)

The value of a binary opcode (`1303–1361`); `OP_DIV` and `OP_MOD` refuse a
zero divisor (`1316–1329`); `OP_MIN`/`OP_MAX` copy an operand (`1357–1361`),
re-serialized minimally.

`[SRC]` `interpreter.cpp:1303–1361`, `interpreter.cpp:1316–1329`, `interpreter.cpp:1357–1361`

### `binaryValue_div_zero` (theorem, `lean/BsvScript/Ops/Arith.lean:246`)

T-A1: `OP_DIV` by zero is its dedicated error, `SCRIPT_ERR_DIV_BY_ZERO`, whatever the dividend
(`1318–1319`).

`[SRC]` `interpreter.cpp:1318–1319`

### `vDivZero_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:285`)

`1 0 OP_DIV` fails `SCRIPT_ERR_DIV_BY_ZERO` (`1316–1319`).

`[SRC]` `interpreter.cpp:1316–1319`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `num.arith.add`, `num.arith.sub`, `num.arith.mul`, `num.arith.div`, `num.arith.mod`, `num.arith.min`, `num.arith.max`, `num.arith.1add`, `num.arith.1sub`, `num.arith.negate`, `num.arith.abs` | 4392 | `interpreter.cpp:1222–1275` (unary), `1277–1378` (binary), the operand read `script_num.cpp:53–89`, the result `:463–481` (`getvch`), the width checks `:164–165`, `:194–195`, `:214–215` (within `:142–220`); the number type `script_num.cpp`, `big_int.cpp:238–262` (`BN_div`/`BN_mod`: truncation, the dividend's sign) |
| `num.arith.div0`, `num.arith.mod0` | 7 | `interpreter.cpp:1316–1330` → `SCRIPT_ERR_DIV_BY_ZERO`/`SCRIPT_ERR_MOD_BY_ZERO` |

