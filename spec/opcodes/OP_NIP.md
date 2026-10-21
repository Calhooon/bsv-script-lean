# `OP_NIP` (`0x77`)

**Family** stack · **module** `BsvScript.Ops.Stack` · **landed at** #10 · **the switch** `876–1055` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `eraseTopI_abs` (theorem, `lean/BsvScript/Impl/State.lean:325`)

**`eraseTopI_abs`.** *What it says:* the implementation's erase stands for the spec's, the charge
released the same. *What it assumes:* nothing. *Why it matters:* `OP_ROLL`, `OP_NIP` (#50).

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `stack.ops`, `stack.alt`, `stack.pick`, `stack.roll` | 96 | `interpreter.cpp:876–1055`; `limitedstack.cpp:211–302` |

