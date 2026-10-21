# `OP_ROLL` (`0x7a`)

**Family** stack · **module** `BsvScript.Ops.Stack` · **landed at** #10 · **the switch** `876–1055` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `pickBound_eq` (theorem, `lean/BsvScript/Ops/Stack.lean:223`)

**`pickBound_eq`.** *What it says:* `OP_PICK`/`OP_ROLL`'s refusal test, a negative index or an index at or
past the depth, reads the same as "negative, or the stack has no element at that index". *What it assumes:*
nothing. *Why it matters:* it lets `execStackFast` decide the bound and fetch the element in one walk to the
picked depth, where the definition measures the whole stack first (#48).

### `execStack_eq_fast` (theorem, `lean/BsvScript/Ops/Stack.lean:239`)

`@[csimp]` (#48): the compiler runs `execStackFast`, whose `OP_PICK`/`OP_ROLL` bound and fetch share one walk
to the picked depth (`pickBound_eq`, with `topAt`'s `getD` read as the same lookup) and whose depth tests run
`needFast`; nothing in the semantics moves, every theorem about `execStack` is about the definition.

### `verifyScript_eq_I` (theorem, `lean/BsvScript/Eval.lean:89`)

**`verifyScript_eq_I`.** *What it says:* the evaluator on the array-backed machine is the spec's evaluator,
as functions. *What it assumes:* nothing. *Why it matters:* `@[csimp]`: every compiled call of
`verifyScript` after this module runs `verifyScriptI` (the CLI's `eval` and `corpus`, `lean/Bsvs/Run.lean`; the
flow leg's corpus run, its kernel sample and its array-machine large-lock row; the list-machine row calls
`Machine.verifyScript` directly), where `OP_PICK`/`OP_ROLL` index the stack instead of walking it; nothing in the
semantics moves, and every theorem about `verifyScript` is about the definition (#50).

### `execStackI_abs` (theorem, `lean/BsvScript/Impl/Stack.lean:85`)

**`execStackI_abs`.** *What it says:* on every implementation state, the implementation's stack family
computes what `Ops.Stack.execStack` computes on the spec state it stands for: the same error, or a state that
stands for the spec's (the elements packed since #143). *What it assumes:* nothing. *Why it matters:*
`OP_PICK`/`OP_ROLL` in one index each, with the verdicts unmoved (#50, slice (b)).

### `reverse_eraseIdx` (theorem, `lean/BsvScript/Impl/State.lean:35`)

**`reverse_eraseIdx`.** *What it says:* erasing index `i` of a list and reversing is erasing index
`length − 1 − i` of the reversed list. *What it assumes:* `i` is inside the list. *Why it matters:* the
implementation's `OP_ROLL` erases the element `k` below the top at array index `size − 1 − k` (#50).

### `eraseTopArr_eq` (theorem, `lean/BsvScript/Impl/State.lean:224`)

**`eraseTopArr_eq`.** *What it says:* erasing the array's element `k` below the top is
`List.eraseIdx k` on the top-first list. *What it assumes:* nothing. *Why it matters:* `OP_ROLL` (#50).

### `eraseTopI_abs` (theorem, `lean/BsvScript/Impl/State.lean:325`)

**`eraseTopI_abs`.** *What it says:* the implementation's erase stands for the spec's, the charge
released the same. *What it assumes:* nothing. *Why it matters:* `OP_ROLL`, `OP_NIP` (#50).

### `execStack_frame` (theorem, `lean/BsvScript/Properties/Hooks.lean:368`)

Every stack opcode is a frame (`876–1064`): the moves, the copies, the drops, the swaps and rotations,
`OP_PICK`/`OP_ROLL`, `OP_TUCK`, `OP_DEPTH`, `OP_SIZE`.

`[SRC]` `interpreter.cpp:876–1064`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `stack.ops`, `stack.alt`, `stack.pick`, `stack.roll` | 96 | `interpreter.cpp:876–1055`; `limitedstack.cpp:211–302` |
| `flags.v1.minimaldata.push`, `flags.v1.minimaldata.number` | 36 | `interpreter.cpp:433–434`, `473–479`, `331–358`; `script_num.cpp:53–89`, `int_serialization.h:97–129`; the reads `546`, `577`, `622`, `624`, `655`, `680`, `709`, `717`, `745`, `753`, `1015`, `1129`, `1163`, `1235`, `1300–1301`, `1386–1390`, `1524`, `1551`, `1717`, `1747`; `policy.h:190` |

