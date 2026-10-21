# `OP_SPLIT` (`0x7f`)

**Family** splice · **module** `BsvScript.Ops.Splice` · **landed at** #10 · **the switch** `1687–1792`, `1057–1064` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `invalidSplitPosition` (def, `lean/BsvScript/Ops/Splice.lean:35`)

The position guard of `OP_SPLIT`, [SRC] v1.2.3 `6504a3af`,
`interpreter.cpp:1718–1719`: negative, above `INT32_MAX`, or past the element.
The 32-bit bound is an opcode validity rule, independent of relay policy.

`[SRC]` `interpreter.cpp:1718–1719`

### `split` (def, `lean/BsvScript/Ops/Splice.lean:48`)

`OP_SPLIT`, [SRC] v1.2.3 `6504a3af`, `interpreter.cpp:1708–1736`:
the position is read at `1716–1717`; outside `0 … min(size, INT32_MAX)` is
`SCRIPT_ERR_INVALID_SPLIT_RANGE` (`1718–1719`); both operands are popped and
the halves pushed (`1730–1735`). The previous pin's reading is retained in a history module withheld from the
public edition at the maintainers' request (group `d8-node-team-discretion`).

`[SRC]` `interpreter.cpp:1708–1736`, `interpreter.cpp:1716–1717`, `interpreter.cpp:1718–1719`, `interpreter.cpp:1730–1735`

### `split_halves` (theorem, `lean/BsvScript/Ops/Splice.lean:126`)

T-SP1: the two halves `OP_SPLIT` builds, `data.take n` and `data.drop n` (`n1` and `n2`, `1726–1727`),
reassemble the element. This is the list fact alone, Lean core's `List.take_append_drop` under the spec's
name: it names no opcode and no state. The statement at the opcode is W4 `split_ok`
(`Properties/Widths.lean`).

`[SRC]` `interpreter.cpp:1726–1727`

### `toBytes_take` (theorem, `lean/BsvScript/Impl/Elem.lean:197`)

**`toBytes_take`.** *What it says:* an element's leading `n` bytes are its list's. *What it assumes:* nothing.
*Why it matters:* `OP_SPLIT`, `OP_LEFT`, `OP_SUBSTR` (#143).

### `toBytes_drop` (theorem, `lean/BsvScript/Impl/Elem.lean:202`)

**`toBytes_drop`.** *What it says:* an element's bytes after the first `n` are its list's. *What it assumes:*
nothing. *Why it matters:* `OP_SPLIT`, `OP_RIGHT`, `OP_SUBSTR` (#143).

### `splitI_abs` (theorem, `lean/BsvScript/Impl/Splice.lean:51`)

**`splitI_abs`.** *What it says:* the implementation's `OP_SPLIT` computes what `Ops.Splice.split`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the
implementation (#50).

### `splice_exec_isSome` (theorem, `lean/BsvScript/Properties/Coverage.lean:72`)

The splice family's hook answers exactly on `OP_CAT`, `OP_SPLIT`, `OP_NUM2BIN`
and `OP_BIN2NUM`, and on no other byte. One of the six lemmas
`opExec_isSome_of_hookOwns` assembles.

### `split_frame` (theorem, `lean/BsvScript/Properties/Hooks.lean:142`)

`OP_SPLIT` is a frame.

### `split_ok` (theorem, `lean/BsvScript/Properties/Widths.lean:100`)

**W4 (`OP_SPLIT` is `OP_CAT`'s inverse).** *What it says:* an `OP_SPLIT` that succeeds read the
position `n` from the top element `p` (the number read, `1716–1717`), at most
`INT32_MAX` ([SRC] `6504a3af`, `interpreter.cpp:1718`) and the length of the element
`x` under it, and replaced the two by the halves `x.take n` (below) and `x.drop n` (on top), which
concatenate back to `x`. *What it assumes:* the opcode succeeded. *Why it matters:* `OP_SPLIT` then
`OP_CAT` restores the element (the halves cut at the position, `1726–1727`, both popped and the halves
pushed, `1730–1735`; T-SP1), so a split never loses or reorders a byte.

`[SRC]` `interpreter.cpp:1716–1717`, `interpreter.cpp:1718`, `interpreter.cpp:1726–1727`, `interpreter.cpp:1730–1735`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `splice.cat`, `splice.split`, `splice.bin2num` | 70 | `interpreter.cpp:1687–1706`, `1708–1736`, `1780–1792` |
| `flags.v1.minimaldata.push`, `flags.v1.minimaldata.number` | 36 | `interpreter.cpp:433–434`, `473–479`, `331–358`; `script_num.cpp:53–89`, `int_serialization.h:97–129`; the reads `546`, `577`, `622`, `624`, `655`, `680`, `709`, `717`, `745`, `753`, `1015`, `1129`, `1163`, `1235`, `1300–1301`, `1386–1390`, `1524`, `1551`, `1717`, `1747`; `policy.h:190` |

