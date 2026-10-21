# `OP_NUM2BIN` (`0x80`)

**Family** splice · **module** `BsvScript.Ops.Splice` · **landed at** #10 · **the switch** `1687–1792`, `1057–1064` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `num2binOp` (def, `lean/BsvScript/Ops/Splice.lean:63`)

`OP_NUM2BIN` (`1741–1778`): the width read as a number (`1746–1747`);
negative or above `INT32_MAX` is `SCRIPT_ERR_PUSH_SIZE` (`1748–1749`), so is a
pre-Genesis width above 520 (`1752–1753`); the width popped; the number
minimally encoded in place (`1760`, `bsv::MinimallyEncode`, the reference
algorithm `Numbers.minimallyEncodeRef`, `encode ∘ decode` on bytes by T4); wider than the
width is `SCRIPT_ERR_IMPOSSIBLE_ENCODING` (`1761–1763`); equal is kept
(`1767–1769`); else the sign bit moves to the last byte of the zero padding
(`1771–1777`). `Numbers.num2bin` is exactly this (T7).

The memory refusal comes BEFORE the padded element is built (#142). [SRC] v1.2.3
`6504a3af`, `limitedstack.cpp:60–71`: `padRight` charges the growth
(`increaseCombinedStackSize(sizeDifference)`, `:66`) before `resize` (`:68`), and
`limitedstack.cpp:194–207` throws `stack_overflow_error` when
`getCombinedStackSize() + additionalSize > maxStackSize` (`:202–204`), mapped to
`SCRIPT_ERR_STACK_SIZE` (`interpreter.cpp:1815–1818`). The counter there holds the
minimally encoded number at its own charge (`limitedstack.cpp:113–120`), so the
refusal is exactly `memUsed + width + elementOverhead` over the limit, `pushElem`'s
own test on an element of `width` bytes: the verdict is the late push's on every
state, and the bytes are never made. The equal case is tested as the late push
tested it, where the reference charges nothing (`1767–1769`); the test admits it on
every state whose counter is within the limit, the element being no longer than the
one popped (no theorem states that invariant).

`[SRC]` `interpreter.cpp:1741–1778`, `interpreter.cpp:1746–1747`, `interpreter.cpp:1748–1749`, `interpreter.cpp:1752–1753`, `interpreter.cpp:1760`, `interpreter.cpp:1761–1763`, `interpreter.cpp:1767–1769`, `interpreter.cpp:1771–1777`, `limitedstack.cpp:60–71`, `limitedstack.cpp:66`, `limitedstack.cpp:68`, `limitedstack.cpp:194–207`, `limitedstack.cpp:202–204`, `interpreter.cpp:1815–1818`, `limitedstack.cpp:113–120`

### `toBytes_pushList` (theorem, `lean/BsvScript/Impl/Elem.lean:41`)

**`toBytes_pushList`.** *What it says:* pushing a valid list appends it. *What it assumes:*
`Bytes.valid bs`. *Why it matters:* `OP_NUM2BIN`'s pad (#143).

### `toBytes_pushZeros` (theorem, `lean/BsvScript/Impl/Elem.lean:325`)

**`toBytes_pushZeros`.** *What it says:* pushing `n` zeros appends `n` zeros to the list. *What it assumes:*
nothing. *Why it matters:* `OP_NUM2BIN`'s pad (#143).

### `num2binPad` (def, `lean/BsvScript/Impl/Elem.lean:336`)

`num2binPad` (`OP_NUM2BIN`'s pad, `interpreter.cpp:1771–1777`, `padRight`, `limitedstack.cpp:60–71`) built in
one array of the width's capacity: the encoding with its top byte's sign bit cleared, the zeros, the sign byte. The
encoding is a short list (a minimal encoding); the zeros are written in place, never as a list.

`[SRC]` `interpreter.cpp:1771–1777`, `limitedstack.cpp:60–71`

### `toBytes_num2binPad` (theorem, `lean/BsvScript/Impl/Elem.lean:346`)

**`toBytes_num2binPad`.** *What it says:* the element is the spec's pad. *What it assumes:* `Bytes.valid m`.
*Why it matters:* `OP_NUM2BIN` to a width of two billion bytes holds two billion bytes, not two billion cons cells
(#142's record; #143).

### `num2binM` (def, `lean/BsvScript/Impl/Elem.lean:374`)

`OP_NUM2BIN`'s padding step (`num2bin`, `1755–1778`) on the minimal encoding `m` of the operand, computed
once by the opcode: the impossible encoding (`none`), the equal case, or the pad built in place.

`[SRC]` `interpreter.cpp:1755–1778`

### `num2binM_map` (theorem, `lean/BsvScript/Impl/Elem.lean:381`)

**`num2binM_map`.** *What it says:* the padding step on the operand's minimal encoding answers what the
spec's answers on the operand. *What it assumes:* nothing. *Why it matters:* `OP_NUM2BIN` (#143).

### `optPush_abs` (theorem, `lean/BsvScript/Impl/Splice.lean:79`)

**`optPush_abs`.** *What it says:* pushing an optional element, or failing, read as the spec's, is pushing the
optional list, or failing. *What it assumes:* nothing. *Why it matters:* `OP_NUM2BIN`'s last step over
`Elem.num2binM` (#143).

### `num2binOpI_abs` (theorem, `lean/BsvScript/Impl/Splice.lean:93`)

**`num2binOpI_abs`.** *What it says:* the implementation's `OP_NUM2BIN` computes what
`Ops.Splice.num2binOp` computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the
family on the implementation (#50).

### `minimallyEncode` (def, `lean/BsvScript/Numbers.lean:229`)

The minimal encoding of the value: what `OP_BIN2NUM` (`interpreter.cpp:1780–1789`)
and `OP_NUM2BIN`'s first step (`1760`) compute. Defined as the canonical form;
`minimallyEncodeRef_eq` (T4, below) proves it equal on bytes (`Bytes.valid`) to the
reference's algorithm as transcribed (`minimallyEncodeRef`), and the property check
`lean/Test/NumbersCheck.lean` compares it with bsv-rs over `corpus/numbers/`.

`[SRC]` `interpreter.cpp:1780–1789`, `interpreter.cpp:1760`

### `num2binPad` (def, `lean/BsvScript/Numbers.lean:267`)

The padding of `OP_NUM2BIN` for a minimal encoding `m` shorter than the width
(`1765–1777`): clear the sign bit of the top byte, pad with zero bytes and put
the sign bit in the last byte (`padRight`, `limitedstack.cpp:60–71`). An empty
`m` (the value zero) pads to zero bytes with a zero sign byte.

`[SRC]` `interpreter.cpp:1765–1777`, `limitedstack.cpp:60–71`

### `num2bin` (def, `lean/BsvScript/Numbers.lean:276`)

The padding step of `OP_NUM2BIN` after the minimal encoding (`1755–1778`):
longer than the width → `SCRIPT_ERR_IMPOSSIBLE_ENCODING` (`none`); equal →
unchanged; shorter → `num2binPad`. The width's own checks (`n < 0`,
`n > INT32_MAX`, the pre-Genesis 520) are the opcode's, at #10.

`[SRC]` `interpreter.cpp:1755–1778`

### `minimallyEncodeRef_eq` (theorem, `lean/BsvScript/Numbers.lean:893`)

**T4, the reference algorithm is the canonical re-encoding**: `MinimallyEncode`
(`int_serialization.h:154–208`, transcribed as `minimallyEncodeRef`) computes
`encode (decode b)` on every list of bytes (so `OP_BIN2NUM` (`1786`) and
`OP_NUM2BIN`'s first step (`1760`) are re-encodings). *What it assumes:*
`Bytes.valid b`, every entry below 256 (the byte type is `Nat`; `[257]` is left
unchanged by `minimallyEncodeRef` and re-encodes to `[0x81]`). That bsv-rs's
decode-then-encode agrees with it is not this theorem's: the property check
`lean/Test/NumbersCheck.lean` compares the two over `corpus/numbers/`, at the
pinned release.

`[SRC]` `int_serialization.h:154–208`, `interpreter.cpp:1786`, `interpreter.cpp:1760`

### `num2bin_none_iff` (theorem, `lean/BsvScript/Numbers.lean:1106`)

**T7, the failure**: `num2bin` refuses (`none`: `OP_NUM2BIN`'s
`SCRIPT_ERR_IMPOSSIBLE_ENCODING`, `1761–1763`) exactly when the width is below the
length of the minimal encoding.

`[SRC]` `interpreter.cpp:1761–1763`

### `num2bin_length` (theorem, `lean/BsvScript/Numbers.lean:1130`)

**T7, the length**: a result of `num2bin` has exactly the requested width (equal:
unchanged, `1767–1769`; shorter: padded, `1771–1777`), as `OP_NUM2BIN` pushes it.

`[SRC]` `interpreter.cpp:1767–1769`, `interpreter.cpp:1771–1777`

### `num2bin_decode` (theorem, `lean/BsvScript/Numbers.lean:1169`)

**T7, the value**: a result of `num2bin` decodes to the input's value: the minimal
encoding keeps it (T1, `decode_encode`) and the padding keeps it (`decode_num2binPad`,
the sign-bit move `1771–1777`), so `OP_NUM2BIN`, when it succeeds, changes the width
and never the number.

`[SRC]` `interpreter.cpp:1771–1777`

### `num2bin_eq_fast` (theorem, `lean/BsvScript/Numbers.lean:1629`)

`@[csimp]`: `num2bin` restated after `minimallyEncode`'s; the same term (`rfl`), so `OP_NUM2BIN` on a large element runs the fast leaves too.

### `splice_exec_isSome` (theorem, `lean/BsvScript/Properties/Coverage.lean:72`)

The splice family's hook answers exactly on `OP_CAT`, `OP_SPLIT`, `OP_NUM2BIN`
and `OP_BIN2NUM`, and on no other byte. One of the six lemmas
`opExec_isSome_of_hookOwns` assembles.

### `num2binOp_frame` (theorem, `lean/BsvScript/Properties/Hooks.lean:162`)

`OP_NUM2BIN` is a frame.

### `num2binOp_stackSize_iff` (theorem, `lean/BsvScript/Properties/Widths.lean:167`)

**W5 (`OP_NUM2BIN`'s memory at the opcode; the flagged rule `splice.num2bin.memory`).** *What it says:*
when the width `w` and the number pass their checks (the width read as a number in `0 … INT32_MAX`, at
most 520 before Genesis, the number fitting it), `OP_NUM2BIN` refuses `SCRIPT_ERR_STACK_SIZE` exactly when
the counter after the two pops plus `w` and the element overhead exceeds `MaxStackMemoryUsage`. *What it
assumes:* the stack `wb :: raw :: rest`, the width's read and the fit. *Why it matters:* the padding is
charged against the memory budget before the result exists (`padRight`, `limitedstack.cpp:60–71`, at
`1771–1777`; the spec refuses before `num2bin` builds it, #142): a small number padded to a width of up to
2³¹ − 1 bytes is refused by the memory limit, not by a width limit, the corner the corpus flags.

`[SRC]` `limitedstack.cpp:60–71`, `interpreter.cpp:1771–1777`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `splice.num2bin.width` | 410 | `interpreter.cpp:1741–1778`, `1780–1792`; `limitedstack.cpp:60–69` (`padRight`) |
| `splice.num2bin.memory` | 2 | `interpreter.cpp:1771–1777`, `configscriptpolicy.cpp:139–154`; bsv-rs at 0.3.30 `spend.rs:94` (the default mode's 32,000,000), `96–101` (a word's budget, the node's policy default), `1174–1175` (`OP_NUM2BIN`'s element check); before: `spend.rs:54` at 0.3.24, `1018` at 0.3.27 |
| `flags.v1.minimaldata.push`, `flags.v1.minimaldata.number` | 36 | `interpreter.cpp:433–434`, `473–479`, `331–358`; `script_num.cpp:53–89`, `int_serialization.h:97–129`; the reads `546`, `577`, `622`, `624`, `655`, `680`, `709`, `717`, `745`, `753`, `1015`, `1129`, `1163`, `1235`, `1300–1301`, `1386–1390`, `1524`, `1551`, `1717`, `1747`; `policy.h:190` |

