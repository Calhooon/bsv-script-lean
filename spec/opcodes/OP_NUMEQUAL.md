# `OP_NUMEQUAL` (`0x9c`)

**Family** arithmetic (binary) · **module** `BsvScript.Ops.Arith` · **landed at** #9 · **the switch** `1277–1378` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)
- operands read as `CScriptNum` with the era's width (4 pre-Genesis, 750,000 post-Genesis, 32,000,000 post-Chronicle) and, under MINIMALDATA with the gate, the minimal check (`script_num.cpp:53–89`)

## Semantics (the Lean docstrings that name it)

### `vAdd_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:273`)

`2 3 OP_ADD 5 OP_NUMEQUAL` is valid (`1304–1306`, `1338–1341`).

`[SRC]` `interpreter.cpp:1304–1306`, `interpreter.cpp:1338–1341`

### `vNegZero_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:303`)

`<0x80> OP_1ADD 1 OP_NUMEQUAL` is valid: negative zero reads as zero on the block path, where MINIMALDATA is off (`1222–1240`, `script_num.cpp:67`).

`[SRC]` `interpreter.cpp:1222–1240`, `script_num.cpp:67`

### `vMinimalV1Mempool_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:405`)

`<01 00> OP_1ADD 2 OP_NUMEQUAL` at version 1 on the mempool path fails `SCRIPT_ERR_SCRIPTNUM_MINENCODE`: MINIMALDATA under the gate (`433`, `script_num.cpp:67`).

`[SRC]` `interpreter.cpp:433`, `script_num.cpp:67`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `num.cmp.lessthan`, `num.cmp.greaterthan`, `num.cmp.numequal`, `num.cmp.numnotequal` | 1612 | `interpreter.cpp:1338–1356` |

