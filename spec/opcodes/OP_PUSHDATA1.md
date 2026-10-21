# `OP_PUSHDATA1` (`0x4c`)

**Family** push · **module** `BsvScript.Machine` · **landed at** #8 · **the switch** the pushes: `473–481`; minimality `331–358` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- pre-Genesis UTXO: a push above 520 bytes is `SCRIPT_ERR_PUSH_SIZE` (`455–456`, `script.h:29`); post-Genesis: the memory budget only (`limitedstack.cpp:194–207`)
- under MINIMALDATA and the version gate the push must be the minimal form (`CheckMinimalPush` `331–358`, `474–479`; MINIMALDATA is a POLICY flag, never in a block word)

## Semantics (the Lean docstrings that name it)

### `getOpTail` (def, `lean/BsvScript/Machine.lean:24`)

`GetOp2` after the opcode byte (`script.h:173`): for a push opcode (`≤ OP_PUSHDATA4`,
`script.h:176`), the size is the opcode itself below `OP_PUSHDATA1` (`script.h:178–179`), else 1,
2 or 4 little-endian length bytes (`script.h:180–191`); a truncated length or a truncated push
fails the parse (`return false`, the push's own test at `script.h:192–193`). Returns the push
data (empty for a non-push opcode) and the number of bytes consumed after the opcode.

`[SRC]` `script.h:173`, `script.h:176`, `script.h:178–179`, `script.h:180–191`, `script.h:192–193`

### `pushData_length` (theorem, `lean/BsvScript/Sighash.lean:560`)

Its length is the signature's plus the push opcode's: 1, 2, 3 or 5 bytes by the size class
(`script.h:106–130`: a direct push below `OP_PUSHDATA1`, then `OP_PUSHDATA1`, `OP_PUSHDATA2`,
`OP_PUSHDATA4` with their 1-, 2- and 4-byte prefixes).

`[SRC]` `script.h:106–130`

### `truncatedHead_length_le` (theorem, `lean/BsvScript/Sighash.lean:569`)

T-SH11: the bytes `GetOp2` consumes before failing on a truncated push (`script.h:171–193`: the length prefix
at `script.h:180–191`, the data-length test at `script.h:192–193`) are
the opcode and, for `OP_PUSHDATA1/2/4`, the length prefix when wholly present: one to five bytes.

`[SRC]` `script.h:171–193`, `script.h:180–191`, `script.h:192–193`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `push.minimal`, `push.constant`, `push.truncated` | 760 | `473–481`, `331–358`, `488–507`, `script.h:163–198`, `450–451` |
| `flags.v1.minimaldata.push`, `flags.v1.minimaldata.number` | 36 | `interpreter.cpp:433–434`, `473–479`, `331–358`; `script_num.cpp:53–89`, `int_serialization.h:97–129`; the reads `546`, `577`, `622`, `624`, `655`, `680`, `709`, `717`, `745`, `753`, `1015`, `1129`, `1163`, `1235`, `1300–1301`, `1386–1390`, `1524`, `1551`, `1717`, `1747`; `policy.h:190` |

