# `OP_NOP` (`0x61`)

**Family** flow · **module** `BsvScript.Machine` · **landed at** #8 · **the switch** §2.4 of DESIGN · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## Semantics (the Lean docstrings that name it)

Decided by its family module `BsvScript.Machine` (no docstring names it individually; the family's docstrings are in [`modules.md`](../modules.md)).

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `flow.nop`, `flow.reserved`, `flow.unknown-opcode` | 38 | `516`, `765–771`, `1795` (the `default:`), `470–471` |
| `eras.utxo.pre-genesis`, `eras.utxo.post-genesis`, `eras.utxo.post-chronicle` | 42 | `interpreter.cpp:411–427`, `2269–2280`; `configscriptpolicy.cpp:65–154`; the sites named |

