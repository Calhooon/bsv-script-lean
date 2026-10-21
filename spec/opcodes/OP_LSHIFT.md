# `OP_LSHIFT` (`0x98`)

**Family** bitwise (shifts) · **module** `BsvScript.Ops.Bitwise` · **landed at** #9 · **the switch** `1121–1187`, `65–117` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)
- operands read as `CScriptNum` with the era's width (4 pre-Genesis, 750,000 post-Genesis, 32,000,000 post-Chronicle) and, under MINIMALDATA with the gate, the minimal check (`script_num.cpp:53–89`)

## Semantics (the Lean docstrings that name it)

### `shift` (def, `lean/BsvScript/Ops/Bitwise.lean:107`)

`OP_LSHIFT`/`OP_RSHIFT` (`1121–1153`, `1155–1187`): the count `n` is a number read as an
operand (`1129`, `1163`, `Ops.Arith.readOperand`), negative is
`SCRIPT_ERR_INVALID_NUMBER_RANGE` (`1130–1131`, `1164–1165`); a count of at least eight times
the width gives zeros (`1137–1138`, `1171–1172`); otherwise the shift by `n`. The reference
shifts in steps of `INT32_MAX` bits (`1141–1149`, `1175–1183`; `getint` saturates at
`INT_MAX`, `script_num.cpp:400–420`); successive width-preserving shifts compose
to the shift by their sum, so one shift by `n` is written here.

`[SRC]` `interpreter.cpp:1121–1153`, `interpreter.cpp:1155–1187`, `interpreter.cpp:1129`, `interpreter.cpp:1163`, `interpreter.cpp:1130–1131`, `interpreter.cpp:1164–1165`, `interpreter.cpp:1137–1138`, `interpreter.cpp:1171–1172`, `interpreter.cpp:1141–1149`, `interpreter.cpp:1175–1183`, `script_num.cpp:400–420`

### `shiftI_abs` (theorem, `lean/BsvScript/Impl/Bitwise.lean:67`)

**`shiftI_abs`.** *What it says:* the implementation's `OP_LSHIFT`/`OP_RSHIFT` computes what
`Ops.Bitwise.shift` computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the
family on the implementation (#50).

### `toBytes_zeros` (theorem, `lean/BsvScript/Impl/Elem.lean:439`)

**`toBytes_zeros`.** *What it says:* the element is `n` zeros. *What it assumes:* nothing. *Why it matters:*
`OP_LSHIFT`/`OP_RSHIFT` by the width or more (#143).

### `lshift_valid` (theorem, `lean/BsvScript/Impl/Elem.lean:481`)

**`lshift_valid`.** *What it says:* `LShift`'s bytes are bytes. *What it assumes:* nothing. *Why it matters:*
`OP_LSHIFT` (#143).

### `toBytes_lshift` (theorem, `lean/BsvScript/Impl/Elem.lean:506`)

**`toBytes_lshift`.** *What it says:* the element is the spec's `LShift` of its list. *What it assumes:*
nothing. *Why it matters:* `OP_LSHIFT` (#143).

### `isBinary` (def, `lean/BsvScript/Ops/Arith.lean:227`)

The binary family's opcode range `0x93`–`0xa4` without the bit shifts
`OP_LSHIFT`/`OP_RSHIFT` (`0x98`/`0x99`, `BsvScript.Ops.Bitwise`).

### `bitwise_exec_isSome` (theorem, `lean/BsvScript/Properties/Coverage.lean:54`)

The bitwise family's hook answers exactly on `OP_AND`, `OP_OR`, `OP_XOR`,
`OP_INVERT`, `OP_LSHIFT`, `OP_RSHIFT`, `OP_EQUAL` and `OP_EQUALVERIFY`, and on no
other byte. One of the six lemmas `opExec_isSome_of_hookOwns` assembles.

### `shift_frame` (theorem, `lean/BsvScript/Properties/Hooks.lean:299`)

`OP_LSHIFT`/`OP_RSHIFT` are frames.

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `bitwise.shift` | 528 | `interpreter.cpp:1121–1187`, the loops `65–117`, the masks `52–62` |
| `flags.v1.minimaldata.push`, `flags.v1.minimaldata.number` | 36 | `interpreter.cpp:433–434`, `473–479`, `331–358`; `script_num.cpp:53–89`, `int_serialization.h:97–129`; the reads `546`, `577`, `622`, `624`, `655`, `680`, `709`, `717`, `745`, `753`, `1015`, `1129`, `1163`, `1235`, `1300–1301`, `1386–1390`, `1524`, `1551`, `1717`, `1747`; `policy.h:190` |

