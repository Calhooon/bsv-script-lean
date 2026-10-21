# `OP_1NEGATE` (`0x4f`)

**Family** push · **module** `BsvScript.Machine` · **landed at** #8 · **the switch** `488–507` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## Semantics (the Lean docstrings that name it)

### `hasCase` (def, `lean/BsvScript/Opcodes.lean:143`)

The opcodes that have a `case` label in `EvalScript`'s switch at the pin
(the case-label map, `docs/DESIGN.md` §3): `OP_1NEGATE`, `OP_1`–`OP_16`, the
flow, stack, splice, bitwise and equality opcodes `0x61`–`0x88`, the numeric,
crypto and expansion opcodes `0x8b`–`0xb9`. Everything else above the pushes
(`OP_RESERVED` `0x50`, `OP_RESERVED1/2` `0x89`/`0x8a`, `0xba`–`0xff`) reaches
the `default:` case, `SCRIPT_ERR_BAD_OPCODE` when executed (`interpreter.cpp:1795`).

`[SRC]` `interpreter.cpp:1795`

### `opName` (def, `lean/Bsvs/Trace.lean:226`)

The opcode's name, through the generated table: the reference's stream operator's spelling
(`opcodes.cpp:8–72`) except in three places: a bare push, which the operator prints as its decimal
length (`opcodes.cpp:10–13`) and this as `PUSH<n>`; `OP_1NEGATE`, which the operator prints as `-1`
through its default branch and `GetOpName` (`opcodes.cpp:69–70`, `opcodes.cpp:88–89`) and this as
`OP_1NEGATE`; and every byte from `0xba`, where the generated table stops (`core_read.cpp:23`),
which the operator prints as `OP_UNKNOWN` (`opcodes.cpp:326–327`), or as `OP_INVALIDOPCODE` for
`0xff` (`opcodes.cpp:317–318`), and this as `0x<hex>`. `GetOpName` alone (`opcodes.cpp:75`) prints
`"0"`, `OP_UNKNOWN` for a bare push (it has no case for one, `opcodes.cpp:326–327`) and `"1"` to
`"16"`, where this prints `OP_0`, `PUSH<n>` and `OP_1`…`OP_16` (lean #32's second lens, B-15, and
its re-lenses; the file on every line, since the spec reads a bare number as `interpreter.cpp`'s,
its fourth re-lens, A4N-1).

`[SRC]` `opcodes.cpp:8–72`, `opcodes.cpp:10–13`, `opcodes.cpp:69–70`, `opcodes.cpp:88–89`, `core_read.cpp:23`, `opcodes.cpp:326–327`, `opcodes.cpp:317–318`, `opcodes.cpp:75`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `push.minimal`, `push.constant`, `push.truncated` | 760 | `473–481`, `331–358`, `488–507`, `script.h:163–198`, `450–451` |
| `flags.v1.minimaldata.push`, `flags.v1.minimaldata.number` | 36 | `interpreter.cpp:433–434`, `473–479`, `331–358`; `script_num.cpp:53–89`, `int_serialization.h:97–129`; the reads `546`, `577`, `622`, `624`, `655`, `680`, `709`, `717`, `745`, `753`, `1015`, `1129`, `1163`, `1235`, `1300–1301`, `1386–1390`, `1524`, `1551`, `1717`, `1747`; `policy.h:190` |

