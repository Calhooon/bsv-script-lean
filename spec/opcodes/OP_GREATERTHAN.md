# `OP_GREATERTHAN` (`0xa0`)

**Family** arithmetic (binary) · **module** `BsvScript.Ops.Arith` · **landed at** #9 · **the switch** `1277–1378` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)
- operands read as `CScriptNum` with the era's width (4 pre-Genesis, 750,000 post-Genesis, 32,000,000 post-Chronicle) and, under MINIMALDATA with the gate, the minimal check (`script_num.cpp:53–89`)

## Semantics (the Lean docstrings that name it)

Decided by its family module `BsvScript.Ops.Arith` (no docstring names it individually; the family's docstrings are in [`modules.md`](../modules.md)).

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `num.cmp.lessthan`, `num.cmp.greaterthan`, `num.cmp.numequal`, `num.cmp.numnotequal` | 1612 | `interpreter.cpp:1338–1356` |

