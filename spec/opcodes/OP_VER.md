# `OP_VER` (`0x62`)

**Family** flow · **module** `BsvScript.Machine` · **landed at** #8 · **the switch** §2.4 of DESIGN · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- pre-Chronicle UTXO era: `SCRIPT_ERR_BAD_OPCODE` (`OP_VER` `598–608`; `OP_VERIF`/`OP_VERNOTIF` `773–781`, even unexecuted pre-Genesis); post-Chronicle: the version push / the version comparison (`603–606`, `806–812`)

## Semantics (the Lean docstrings that name it)

### `versionLE` (def, `lean/BsvScript/Machine.lean:87`)

The transaction version as four little-endian bytes (`to_le`, `382–386`, on
the `int32`): what `OP_VER` pushes and `OP_VERIF`/`OP_VERNOTIF` compare.

`[SRC]` `interpreter.cpp:382–386`

### `versionLE_valid` (theorem, `lean/BsvScript/Impl/Elem.lean:231`)

**`versionLE_valid`.** *What it says:* the version's four bytes are bytes. *What it assumes:* nothing.
*Why it matters:* `OP_VER` (#143).

### `toBytes_versionLE` (theorem, `lean/BsvScript/Impl/Elem.lean:241`)

**`toBytes_versionLE`.** *What it says:* the element is the version's bytes. *What it assumes:* nothing.
*Why it matters:* `OP_VER` (#143).

### `execFlow_ver_preChronicle` (theorem, `lean/BsvScript/Properties/Eras.lean:499`)

**`OP_VER` fails on a pre-Chronicle coin** (`598–601`): `SCRIPT_ERR_BAD_OPCODE` when
executed; post-Chronicle it pushes the transaction version (`603–606`).

`[SRC]` `interpreter.cpp:598–601`, `interpreter.cpp:603–606`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `flow.ver`, `flow.verif` | 10 | `598–608`, `773–781`, `806–812` |
| `eras.utxo.pre-genesis`, `eras.utxo.post-genesis`, `eras.utxo.post-chronicle` | 42 | `interpreter.cpp:411–427`, `2269–2280`; `configscriptpolicy.cpp:65–154`; the sites named |

