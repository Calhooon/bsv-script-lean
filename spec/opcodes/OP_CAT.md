# `OP_CAT` (`0x7e`)

**Family** splice · **module** `BsvScript.Ops.Splice` · **landed at** #10 · **the switch** `1687–1792`, `1057–1064` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `cat` (def, `lean/BsvScript/Ops/Splice.lean:22`)

`OP_CAT` (`1687–1706`): pre-Genesis the concatenation may not exceed
`MAX_SCRIPT_ELEMENT_SIZE_BEFORE_GENESIS` (`1699–1702`, `script.h:29`); the top
popped and appended to the second (`1704–1705`).

`[SRC]` `interpreter.cpp:1687–1706`, `interpreter.cpp:1699–1702`, `script.h:29`, `interpreter.cpp:1704–1705`

### `toBytes_append` (theorem, `lean/BsvScript/Impl/Elem.lean:186`)

**`toBytes_append`.** *What it says:* appending elements is appending their lists. *What it assumes:*
nothing. *Why it matters:* `OP_CAT` in one copy (#143).

### `catI_abs` (theorem, `lean/BsvScript/Impl/Splice.lean:32`)

**`catI_abs`.** *What it says:* the implementation's `OP_CAT` computes what `Ops.Splice.cat` computes on
the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the implementation
(#50).

### `splice_exec_isSome` (theorem, `lean/BsvScript/Properties/Coverage.lean:72`)

The splice family's hook answers exactly on `OP_CAT`, `OP_SPLIT`, `OP_NUM2BIN`
and `OP_BIN2NUM`, and on no other byte. One of the six lemmas
`opExec_isSome_of_hookOwns` assembles.

### `cat_frame` (theorem, `lean/BsvScript/Properties/Hooks.lean:127`)

`OP_CAT` is a frame.

### `vCat_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:387`)

`<11> <22> OP_CAT <1122> OP_EQUAL` is valid (`1687–1706`).

`[SRC]` `interpreter.cpp:1687–1706`

### `cat_ok` (theorem, `lean/BsvScript/Properties/Widths.lean:68`)

**W3 (`OP_CAT`'s result).** *What it says:* an `OP_CAT` that succeeds replaces the top two elements
`x2` (the second) and `x1` (the top) by `x2 ++ x1`, whose length is the sum. *What it assumes:* the opcode
succeeded. *Why it matters:* the concatenation is the second element followed by the top
(`1704–1705`: the top popped, then appended to the second in place), and by the length conjunct the
result weighs one element's overhead less than the two it replaces. The counter and the alt stack are not in this
statement: that the counter drops by that overhead, where it is exact, needs the alt stack unchanged too,
which the primitives' shapes give (`popElem_ok`, `pushElem_ok`), with `cat_frame`
(`BsvScript.Properties.Hooks`).

`[SRC]` `interpreter.cpp:1704–1705`

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
| `eras.utxo.pre-genesis`, `eras.utxo.post-genesis`, `eras.utxo.post-chronicle` | 42 | `interpreter.cpp:411–427`, `2269–2280`; `configscriptpolicy.cpp:65–154`; the sites named |

