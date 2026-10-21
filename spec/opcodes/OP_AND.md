# `OP_AND` (`0x84`)

**Family** bitwise · **module** `BsvScript.Ops.Bitwise` · **landed at** #9 · **the switch** `1069–1217` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `bitwise2` (def, `lean/BsvScript/Ops/Bitwise.lean:49`)

`OP_AND`/`OP_OR`/`OP_XOR` (`1069–1106`): two operands of equal size
(`1080–1081`, else `SCRIPT_ERR_INVALID_OPERAND_SIZE`), combined byte by byte
in place, the top popped (`1105`).

`[SRC]` `interpreter.cpp:1069–1106`, `interpreter.cpp:1080–1081`, `interpreter.cpp:1105`

### `bitwise2I_abs` (theorem, `lean/BsvScript/Impl/Bitwise.lean:31`)

**`bitwise2I_abs`.** *What it says:* the implementation's `OP_AND`/`OP_OR`/`OP_XOR` computes what
`Ops.Bitwise.bitwise2` computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the
family on the implementation (#50).

### `zipWith` (def, `lean/BsvScript/Impl/Elem.lean:395`)

`OP_AND`/`OP_OR`/`OP_XOR`'s byte-by-byte combination on elements.

### `toBytes_zipWith` (theorem, `lean/BsvScript/Impl/Elem.lean:398`)

**`toBytes_zipWith`.** *What it says:* the combination is the spec's on the two lists. *What it assumes:*
`f` keeps two bytes a byte. *Why it matters:* `OP_AND`, `OP_OR`, `OP_XOR` (#143).

### `bitwise_byte` (theorem, `lean/BsvScript/Impl/Elem.lean:408`)

**`bitwise_byte`.** *What it says:* `&&&`, `|||` and `^^^` keep two bytes a byte, as the op's selection of
them does. *What it assumes:* nothing. *Why it matters:* `toBytes_zipWith`'s side condition for `OP_AND`/`OP_OR`/
`OP_XOR` (#143).

### `bitwise_exec_isSome` (theorem, `lean/BsvScript/Properties/Coverage.lean:54`)

The bitwise family's hook answers exactly on `OP_AND`, `OP_OR`, `OP_XOR`,
`OP_INVERT`, `OP_LSHIFT`, `OP_RSHIFT`, `OP_EQUAL` and `OP_EQUALVERIFY`, and on no
other byte. One of the six lemmas `opExec_isSome_of_hookOwns` assembles.

### `bitwise2_frame` (theorem, `lean/BsvScript/Properties/Hooks.lean:271`)

`OP_AND`/`OP_OR`/`OP_XOR` are frames.

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `bitwise.andorxor`, `bitwise.operand-size`, `bitwise.invert` | 86 | `interpreter.cpp:1069–1106` (`1080–1081` the size check), `1108–1119` |

