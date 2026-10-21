# `OP_TOALTSTACK` (`0x6b`)

**Family** stack · **module** `BsvScript.Ops.Stack` · **landed at** #10 · **the switch** `876–1055` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `toAlt` (def, `lean/BsvScript/Ops/Stack.lean:74`)

`OP_TOALTSTACK` (`876–881`) and `OP_FROMALTSTACK` (`883–888`): a move
between the stacks, no accounting.

`[SRC]` `interpreter.cpp:876–881`, `interpreter.cpp:883–888`

### `exec` (def, `lean/BsvScript/Ops/Stack.lean:247`)

The family hook: `OP_TOALTSTACK` `0x6b` … `OP_TUCK` `0x7d`, and `OP_SIZE` `0x82`.

### `execI` (def, `lean/BsvScript/Impl/Stack.lean:101`)

`Ops.Stack.exec` over the implementation state: `OP_TOALTSTACK` `0x6b` … `OP_TUCK` `0x7d`, and `OP_SIZE`
`0x82`.

### `toAltI_abs` (theorem, `lean/BsvScript/Impl/State.lean:387`)

**`toAltI_abs`.** *What it says:* the implementation's move to the alt stack stands for the spec's.
*What it assumes:* nothing. *Why it matters:* `OP_TOALTSTACK` (#50).

### `stack_exec_isSome` (theorem, `lean/BsvScript/Properties/Coverage.lean:64`)

The stack family's hook answers exactly on the opcodes from `OP_TOALTSTACK` to
`OP_TUCK` and on `OP_SIZE`, and on no other byte. One of the six lemmas
`opExec_isSome_of_hookOwns` assembles.

### `vAlt_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:327`)

`5 OP_TOALTSTACK OP_FROMALTSTACK 5 OP_EQUAL` is valid: the round trip through the alt stack (`876–887`).

`[SRC]` `interpreter.cpp:876–887`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `stack.ops`, `stack.alt`, `stack.pick`, `stack.roll` | 96 | `interpreter.cpp:876–1055`; `limitedstack.cpp:211–302` |

