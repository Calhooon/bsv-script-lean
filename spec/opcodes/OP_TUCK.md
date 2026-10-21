# `OP_TUCK` (`0x7d`)

**Family** stack · **module** `BsvScript.Ops.Stack` · **landed at** #10 · **the switch** `876–1055` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `exec` (def, `lean/BsvScript/Ops/Stack.lean:247`)

The family hook: `OP_TOALTSTACK` `0x6b` … `OP_TUCK` `0x7d`, and `OP_SIZE` `0x82`.

### `execI` (def, `lean/BsvScript/Impl/Stack.lean:101`)

`Ops.Stack.exec` over the implementation state: `OP_TOALTSTACK` `0x6b` … `OP_TUCK` `0x7d`, and `OP_SIZE`
`0x82`.

### `reverse_insertIdx` (theorem, `lean/BsvScript/Impl/State.lean:46`)

**`reverse_insertIdx`.** *What it says:* inserting at index `i` of a list and reversing is inserting at
index `length − i` of the reversed list. *What it assumes:* `i ≤ length`. *Why it matters:* the
implementation's `OP_TUCK` inserts `k` below the top at array index `size − k` (#50).

### `insertTopArr_eq` (theorem, `lean/BsvScript/Impl/State.lean:242`)

**`insertTopArr_eq`.** *What it says:* inserting `k` below the array's top is `List.insertIdx k` on the
top-first list. *What it assumes:* nothing. *Why it matters:* `OP_TUCK` (#50).

### `insertTopI_abs` (theorem, `lean/BsvScript/Impl/State.lean:338`)

**`insertTopI_abs`.** *What it says:* the implementation's insert stands for the spec's, charged the
same. *What it assumes:* nothing. *Why it matters:* `OP_TUCK` (#50).

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
| `stack.ops`, `stack.alt`, `stack.pick`, `stack.roll` | 96 | `interpreter.cpp:876–1055`; `limitedstack.cpp:211–302` |

