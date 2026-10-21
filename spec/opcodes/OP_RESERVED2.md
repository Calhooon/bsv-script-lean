# `OP_RESERVED2` (`0x8a`)

**Family** reserved · **module** `BsvScript.Machine` · **landed at** #8 · **the switch** the `default:` `1795` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

No opcode-level definition: the switch's `default:` case (`Op.hasCase` in `BsvScript.Opcodes`), `SCRIPT_ERR_BAD_OPCODE` when executed (`1795`).

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `flow.nop`, `flow.reserved`, `flow.unknown-opcode` | 38 | `516`, `765–771`, `1795` (the `default:`), `470–471` |

