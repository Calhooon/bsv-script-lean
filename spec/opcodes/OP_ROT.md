# `OP_ROT` (`0x7b`)

**Family** stack · **module** `BsvScript.Ops.Stack` · **landed at** #10 · **the switch** `876–1055` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `swapTopI_abs` (theorem, `lean/BsvScript/Impl/State.lean:313`)

**`swapTopI_abs`.** *What it says:* the implementation's swap stands for the spec's. *What it assumes:*
nothing. *Why it matters:* `OP_SWAP`, `OP_ROT`, `OP_2SWAP`, `OP_2ROT` (#50).

### `vRot_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:315`)

`1 2 3 OP_ROT 1 OP_EQUAL` is valid: the third element moves to the top (`1029–1038`).

`[SRC]` `interpreter.cpp:1029–1038`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `stack.ops`, `stack.alt`, `stack.pick`, `stack.roll` | 96 | `interpreter.cpp:876–1055`; `limitedstack.cpp:211–302` |

