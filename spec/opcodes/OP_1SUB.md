# `OP_1SUB` (`0x8c`)

**Family** arithmetic (unary) · **module** `BsvScript.Ops.Arith` · **landed at** #9 · **the switch** `1222–1275` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)
- operands read as `CScriptNum` with the era's width (4 pre-Genesis, 750,000 post-Genesis, 32,000,000 post-Chronicle) and, under MINIMALDATA with the gate, the minimal check (`script_num.cpp:53–89`)

## Semantics (the Lean docstrings that name it)

Decided by its family module `BsvScript.Ops.Arith` (no docstring names it individually; the family's docstrings are in [`modules.md`](../modules.md)).

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `num.arith.add`, `num.arith.sub`, `num.arith.mul`, `num.arith.div`, `num.arith.mod`, `num.arith.min`, `num.arith.max`, `num.arith.1add`, `num.arith.1sub`, `num.arith.negate`, `num.arith.abs` | 4392 | `interpreter.cpp:1222–1275` (unary), `1277–1378` (binary), the operand read `script_num.cpp:53–89`, the result `:463–481` (`getvch`), the width checks `:164–165`, `:194–195`, `:214–215` (within `:142–220`); the number type `script_num.cpp`, `big_int.cpp:238–262` (`BN_div`/`BN_mod`: truncation, the dividend's sign) |

