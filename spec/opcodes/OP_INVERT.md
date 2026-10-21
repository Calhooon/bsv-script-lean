# `OP_INVERT` (`0x83`)

**Family** bitwise · **module** `BsvScript.Ops.Bitwise` · **landed at** #9 · **the switch** `1069–1217` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `invert` (def, `lean/BsvScript/Ops/Bitwise.lean:83`)

`OP_INVERT` (`1108–1119`): every byte complemented in place.

`[SRC]` `interpreter.cpp:1108–1119`

### `invertI_abs` (theorem, `lean/BsvScript/Impl/Bitwise.lean:46`)

**`invertI_abs`.** *What it says:* the implementation's `OP_INVERT` computes what `Ops.Bitwise.invert`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the
implementation (#50).

### `invert` (def, `lean/BsvScript/Impl/Elem.lean:424`)

`OP_INVERT`'s bytes (`255 − b` each).

### `toBytes_invert` (theorem, `lean/BsvScript/Impl/Elem.lean:427`)

**`toBytes_invert`.** *What it says:* the inverted element is the spec's map on its list. *What it assumes:*
nothing. *Why it matters:* `OP_INVERT` (#143).

### `bitwise_exec_isSome` (theorem, `lean/BsvScript/Properties/Coverage.lean:54`)

The bitwise family's hook answers exactly on `OP_AND`, `OP_OR`, `OP_XOR`,
`OP_INVERT`, `OP_LSHIFT`, `OP_RSHIFT`, `OP_EQUAL` and `OP_EQUALVERIFY`, and on no
other byte. One of the six lemmas `opExec_isSome_of_hookOwns` assembles.

### `invert_frame` (theorem, `lean/BsvScript/Properties/Hooks.lean:288`)

`OP_INVERT` is a frame.

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `bitwise.andorxor`, `bitwise.operand-size`, `bitwise.invert` | 86 | `interpreter.cpp:1069–1106` (`1080–1081` the size check), `1108–1119` |

