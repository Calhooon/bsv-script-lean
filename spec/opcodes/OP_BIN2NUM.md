# `OP_BIN2NUM` (`0x81`)

**Family** splice · **module** `BsvScript.Ops.Splice` · **landed at** #10 · **the switch** `1687–1792`, `1057–1064` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `bin2num` (def, `lean/BsvScript/Ops/Splice.lean:100`)

`OP_BIN2NUM` (`1780–1792`): the top minimally encoded in place (`1786`);
the result must be a number of the width in force (`1789–1790`,
`bsv::IsMinimallyEncoded(…, MaxScriptNumLength)`; 4 bytes for a pre-Genesis coin
on either path, and after Genesis the consensus width on the block path and the
node's policy setting on the mempool path, as for `Ops.Arith.readOperand`), else
`SCRIPT_ERR_INVALID_NUMBER_RANGE`.

`[SRC]` `interpreter.cpp:1780–1792`, `interpreter.cpp:1786`, `interpreter.cpp:1789–1790`

### `toBytes_minimallyEncode` (theorem, `lean/BsvScript/Impl/Elem.lean:313`)

**`toBytes_minimallyEncode`.** *What it says:* the element is the minimal encoding of the list. *What it
assumes:* nothing. *Why it matters:* `OP_BIN2NUM` (#143).

### `pushMin_abs` (theorem, `lean/BsvScript/Impl/Splice.lean:103`)

**`pushMin_abs`.** *What it says:* pushing a minimal encoding, read as the spec's, is pushing it packed. *What
it assumes:* nothing. *Why it matters:* `OP_BIN2NUM`, whose range test reads the same list, computed once
(#143).

### `bin2numI_abs` (theorem, `lean/BsvScript/Impl/Splice.lean:118`)

**`bin2numI_abs`.** *What it says:* the implementation's `OP_BIN2NUM` computes what `Ops.Splice.bin2num`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the
implementation (#50).

### `minimallyEncode` (def, `lean/BsvScript/Numbers.lean:229`)

The minimal encoding of the value: what `OP_BIN2NUM` (`interpreter.cpp:1780–1789`)
and `OP_NUM2BIN`'s first step (`1760`) compute. Defined as the canonical form;
`minimallyEncodeRef_eq` (T4, below) proves it equal on bytes (`Bytes.valid`) to the
reference's algorithm as transcribed (`minimallyEncodeRef`), and the property check
`lean/Test/NumbersCheck.lean` compares it with bsv-rs over `corpus/numbers/`.

`[SRC]` `interpreter.cpp:1780–1789`, `interpreter.cpp:1760`

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

### `splice_exec_isSome` (theorem, `lean/BsvScript/Properties/Coverage.lean:72`)

The splice family's hook answers exactly on `OP_CAT`, `OP_SPLIT`, `OP_NUM2BIN`
and `OP_BIN2NUM`, and on no other byte. One of the six lemmas
`opExec_isSome_of_hookOwns` assembles.

### `bin2num_frame` (theorem, `lean/BsvScript/Properties/Hooks.lean:182`)

`OP_BIN2NUM` is a frame.

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `splice.num2bin.width` | 410 | `interpreter.cpp:1741–1778`, `1780–1792`; `limitedstack.cpp:60–69` (`padRight`) |
| `splice.cat`, `splice.split`, `splice.bin2num` | 70 | `interpreter.cpp:1687–1706`, `1708–1736`, `1780–1792` |
| `splice.num2bin.memory` | 2 | `interpreter.cpp:1771–1777`, `configscriptpolicy.cpp:139–154`; bsv-rs at 0.3.30 `spend.rs:94` (the default mode's 32,000,000), `96–101` (a word's budget, the node's policy default), `1174–1175` (`OP_NUM2BIN`'s element check); before: `spend.rs:54` at 0.3.24, `1018` at 0.3.27 |

