# `OP_SIZE` (`0x82`)

**Family** splice · **module** `BsvScript.Ops.Splice` · **landed at** #10 · **the switch** `1687–1792`, `1057–1064` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `execI` (def, `lean/BsvScript/Impl/Stack.lean:101`)

`Ops.Stack.exec` over the implementation state: `OP_TOALTSTACK` `0x6b` … `OP_TUCK` `0x7d`, and `OP_SIZE`
`0x82`.

### `pushCountI_abs` (theorem, `lean/BsvScript/Impl/State.lean:354`)

**`pushCountI_abs`.** *What it says:* the implementation's count push stands for the spec's. *What it
assumes:* nothing. *Why it matters:* `OP_DEPTH`, `OP_SIZE` (#50).

### `pushCount` (def, `lean/BsvScript/Ops/Stack.lean:43`)

`CScriptNum(bsv::bint{n}, params.MaxScriptNumLength())` pushed (`OP_DEPTH`
`968`, `OP_SIZE` `1062`): the constructor refuses an encoding wider than the
number width in force (`script_num.cpp:45–51`, `scriptnum_overflow_error`; 4
bytes for a pre-Genesis coin on either path, and after Genesis the consensus width
on the block path and the node's policy setting on the mempool path, as for
`Ops.Arith.readOperand`).

`[SRC]` `interpreter.cpp:968`, `interpreter.cpp:1062`, `script_num.cpp:45–51`

### `exec` (def, `lean/BsvScript/Ops/Stack.lean:247`)

The family hook: `OP_TOALTSTACK` `0x6b` … `OP_TUCK` `0x7d`, and `OP_SIZE` `0x82`.

### `stack_exec_isSome` (theorem, `lean/BsvScript/Properties/Coverage.lean:64`)

The stack family's hook answers exactly on the opcodes from `OP_TOALTSTACK` to
`OP_TUCK` and on `OP_SIZE`, and on no other byte. One of the six lemmas
`opExec_isSome_of_hookOwns` assembles.

### `execStack_frame` (theorem, `lean/BsvScript/Properties/Hooks.lean:368`)

Every stack opcode is a frame (`876–1064`): the moves, the copies, the drops, the swaps and rotations,
`OP_PICK`/`OP_ROLL`, `OP_TUCK`, `OP_DEPTH`, `OP_SIZE`.

`[SRC]` `interpreter.cpp:876–1064`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `elem.size` | 458 | `script.h:29` (pre-Genesis 520), `limitedstack.h:79–151` (the post-Genesis accounting), `configscriptpolicy.cpp:139–154`; `interpreter.cpp:1057–1064` |

