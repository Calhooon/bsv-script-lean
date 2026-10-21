# `OP_NUMEQUALVERIFY` (`0x9d`)

**Family** arithmetic (binary) · **module** `BsvScript.Ops.Arith` · **landed at** #9 · **the switch** `1277–1378` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)
- operands read as `CScriptNum` with the era's width (4 pre-Genesis, 750,000 post-Genesis, 32,000,000 post-Chronicle) and, under MINIMALDATA with the gate, the minimal check (`script_num.cpp:53–89`)

## Semantics (the Lean docstrings that name it)

### `binary` (def, `lean/BsvScript/Ops/Arith.lean:141`)

The binary family (`1277–1378`): `bn1` is the second element, `bn2` the top,
read in that order (`1300–1301`); both popped (`1367–1368`); the result pushed
(`1369`); `OP_NUMEQUALVERIFY` then pops a true result or fails (`1371–1377`).

`[SRC]` `interpreter.cpp:1277–1378`, `interpreter.cpp:1300–1301`, `interpreter.cpp:1367–1368`, `interpreter.cpp:1369`, `interpreter.cpp:1371–1377`

### `castToBool_eq` (theorem, `lean/BsvScript/Impl/Elem.lean:304`)

**`castToBool_eq`.** *What it says:* the element's truth is its list's. *What it assumes:* nothing. *Why it
matters:* `OP_IF`, `OP_VERIFY`, `OP_IFDUP`, `OP_NUMEQUALVERIFY` (#143).

### `headD_abs` (theorem, `lean/BsvScript/Impl/State.lean:461`)

**`headD_abs`.** *What it says:* the spec's read of the top with `[]` for an empty stack is the
implementation's `topAtI s 0`. *What it assumes:* nothing. *Why it matters:* `OP_NUMEQUALVERIFY`'s and the
verdict's reads of the top (#50).

### `popTail_abs` (theorem, `lean/BsvScript/Impl/State.lean:497`)

**`popTail_abs`.** *What it says:* the implementation's "pop the top and continue with the rest" stands for
the spec's `match popElem st with | .ok (_, st') => pure st' | .error e => throw e`. *What it assumes:*
nothing. *Why it matters:* the `VERIFY` forms' final pop (`OP_EQUALVERIFY`, `OP_NUMEQUALVERIFY`), closed by
`exact` against each family's own `match` (#50).

### `binary_frame` (theorem, `lean/BsvScript/Properties/Hooks.lean:210`)

A binary arithmetic opcode is a frame, `OP_NUMEQUALVERIFY`'s pop included.

### `vNumEqVerify_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:291`)

`2 3 OP_NUMEQUALVERIFY` fails `SCRIPT_ERR_NUMEQUALVERIFY` (`1371–1377`).

`[SRC]` `interpreter.cpp:1371–1377`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `num.cmp.numequalverify`, `num.cmp.within` | 20 | `interpreter.cpp:1366–1373`, `1380–1399` |
| `flags.v1.minimaldata.push`, `flags.v1.minimaldata.number` | 36 | `interpreter.cpp:433–434`, `473–479`, `331–358`; `script_num.cpp:53–89`, `int_serialization.h:97–129`; the reads `546`, `577`, `622`, `624`, `655`, `680`, `709`, `717`, `745`, `753`, `1015`, `1129`, `1163`, `1235`, `1300–1301`, `1386–1390`, `1524`, `1551`, `1717`, `1747`; `policy.h:190` |

