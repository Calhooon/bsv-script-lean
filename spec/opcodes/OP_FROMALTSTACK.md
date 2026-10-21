# `OP_FROMALTSTACK` (`0x6c`)

**Family** stack · **module** `BsvScript.Ops.Stack` · **landed at** #10 · **the switch** `876–1055` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `toAlt` (def, `lean/BsvScript/Ops/Stack.lean:74`)

`OP_TOALTSTACK` (`876–881`) and `OP_FROMALTSTACK` (`883–888`): a move
between the stacks, no accounting.

`[SRC]` `interpreter.cpp:876–881`, `interpreter.cpp:883–888`

### `fromAltI_abs` (theorem, `lean/BsvScript/Impl/State.lean:409`)

**`fromAltI_abs`.** *What it says:* the implementation's move from the alt stack stands for the spec's.
*What it assumes:* nothing. *Why it matters:* `OP_FROMALTSTACK` (#50).

### `vAlt_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:327`)

`5 OP_TOALTSTACK OP_FROMALTSTACK 5 OP_EQUAL` is valid: the round trip through the alt stack (`876–887`).

`[SRC]` `interpreter.cpp:876–887`

### `vFromAltEmpty_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:333`)

`OP_FROMALTSTACK` on an empty alt stack fails `SCRIPT_ERR_INVALID_ALTSTACK_OPERATION` (`883–887`).

`[SRC]` `interpreter.cpp:883–887`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `stack.ops`, `stack.alt`, `stack.pick`, `stack.roll` | 96 | `interpreter.cpp:876–1055`; `limitedstack.cpp:211–302` |

