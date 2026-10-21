# `OP_DEPTH` (`0x74`)

**Family** stack · **module** `BsvScript.Ops.Stack` · **landed at** #10 · **the switch** `876–1055` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `pushCount` (def, `lean/BsvScript/Ops/Stack.lean:43`)

`CScriptNum(bsv::bint{n}, params.MaxScriptNumLength())` pushed (`OP_DEPTH`
`968`, `OP_SIZE` `1062`): the constructor refuses an encoding wider than the
number width in force (`script_num.cpp:45–51`, `scriptnum_overflow_error`; 4
bytes for a pre-Genesis coin on either path, and after Genesis the consensus width
on the block path and the node's policy setting on the mempool path, as for
`Ops.Arith.readOperand`).

`[SRC]` `interpreter.cpp:968`, `interpreter.cpp:1062`, `script_num.cpp:45–51`

### `pushCountI_abs` (theorem, `lean/BsvScript/Impl/State.lean:354`)

**`pushCountI_abs`.** *What it says:* the implementation's count push stands for the spec's. *What it
assumes:* nothing. *Why it matters:* `OP_DEPTH`, `OP_SIZE` (#50).

### `depth_abs` (theorem, `lean/BsvScript/Impl/State.lean:375`)

**`depth_abs`.** *What it says:* the implementation's depth is the spec's. *What it assumes:* nothing.
*Why it matters:* `OP_DEPTH` and the pre-Genesis depth test, in constant time (#50).

### `execStack_frame` (theorem, `lean/BsvScript/Properties/Hooks.lean:368`)

Every stack opcode is a frame (`876–1064`): the moves, the copies, the drops, the swaps and rotations,
`OP_PICK`/`OP_ROLL`, `OP_TUCK`, `OP_DEPTH`, `OP_SIZE`.

`[SRC]` `interpreter.cpp:876–1064`

### `vDepth_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:339`)

`1 1 OP_DEPTH 2 OP_EQUAL` is valid: the depth is pushed as a number (`966–970`).

`[SRC]` `interpreter.cpp:966–970`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `stack.depth` | 328 | `script.h:32` (pre-Genesis 1000), `interpreter.cpp:2430–2448` (CLEANSTACK), `966–970` |
| `stack.ops`, `stack.alt`, `stack.pick`, `stack.roll` | 96 | `interpreter.cpp:876–1055`; `limitedstack.cpp:211–302` |

