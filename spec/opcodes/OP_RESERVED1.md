# `OP_RESERVED1` (`0x89`)

**Family** reserved · **module** `BsvScript.Machine` · **landed at** #8 · **the switch** the `default:` `1795` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `hasCase` (def, `lean/BsvScript/Opcodes.lean:143`)

The opcodes that have a `case` label in `EvalScript`'s switch at the pin
(the case-label map, `docs/DESIGN.md` §3): `OP_1NEGATE`, `OP_1`–`OP_16`, the
flow, stack, splice, bitwise and equality opcodes `0x61`–`0x88`, the numeric,
crypto and expansion opcodes `0x8b`–`0xb9`. Everything else above the pushes
(`OP_RESERVED` `0x50`, `OP_RESERVED1/2` `0x89`/`0x8a`, `0xba`–`0xff`) reaches
the `default:` case, `SCRIPT_ERR_BAD_OPCODE` when executed (`interpreter.cpp:1795`).

`[SRC]` `interpreter.cpp:1795`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `flow.nop`, `flow.reserved`, `flow.unknown-opcode` | 38 | `516`, `765–771`, `1795` (the `default:`), `470–471` |

