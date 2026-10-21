# `OP_NOP1` (`0xb0`)

**Family** expansion (NOP) · **module** `BsvScript.Machine` · **landed at** #8 · **the switch** `765–771` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- a no-op; `SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS` under the policy flag (`765–771`)

## Semantics (the Lean docstrings that name it)

### `execFlow_nop_block` (theorem, `lean/BsvScript/Properties/Eras.lean:885`)

… `OP_NOP1`, `OP_NOP9` and `OP_NOP10` continue (`765–771`), under the same hypothesis …

`[SRC]` `interpreter.cpp:765–771`

### `nopOrDiscourage_standard` (theorem, `lean/BsvScript/Properties/Eras.lean:903`)

The relay side of the same sites: with the flag on (the standard word), the pre-Chronicle expansion NOP is
`SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS` (`613–614`), as `OP_NOP1`/`OP_NOP9`/`OP_NOP10` are (`768–769`,
`execFlow_nop_standard`) and post-Genesis CLTV/CSV are (`522–523`, `565–566`; `execCltv_nop_postGenesis`,
`execCsv_nop_postGenesis`).

`[SRC]` `interpreter.cpp:613–614`, `interpreter.cpp:768–769`, `interpreter.cpp:522–523`, `interpreter.cpp:565–566`

### `execFlow_nop_standard` (theorem, `lean/BsvScript/Properties/Eras.lean:911`)

**`OP_NOP1`, `OP_NOP9` and `OP_NOP10` under the flag** (`768–769`): with DISCOURAGE_UPGRADABLE_NOPS on (the
standard word), each is `SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS`; the relay side of `execFlow_nop_block`.

`[SRC]` `interpreter.cpp:768–769`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `flow.nop`, `flow.reserved`, `flow.unknown-opcode` | 38 | `516`, `765–771`, `1795` (the `default:`), `470–471` |

