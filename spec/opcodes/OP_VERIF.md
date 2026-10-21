# `OP_VERIF` (`0x65`)

**Family** flow · **module** `BsvScript.Machine` · **landed at** #8 · **the switch** §2.4 of DESIGN · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- pre-Chronicle UTXO era: `SCRIPT_ERR_BAD_OPCODE` (`OP_VER` `598–608`; `OP_VERIF`/`OP_VERNOTIF` `773–781`, even unexecuted pre-Genesis); post-Chronicle: the version push / the version comparison (`603–606`, `806–812`)

## Semantics (the Lean docstrings that name it)

### `versionLE` (def, `lean/BsvScript/Machine.lean:87`)

The transaction version as four little-endian bytes (`to_le`, `382–386`, on
the `int32`): what `OP_VER` pushes and `OP_VERIF`/`OP_VERNOTIF` compare.

`[SRC]` `interpreter.cpp:382–386`

### `execIf` (def, `lean/BsvScript/Machine.lean:245`)

`OP_IF`/`OP_NOTIF`/`OP_VERIF`/`OP_VERNOTIF` (`784–825`): when executing, pop
the condition (`792–793`, `821`), MINIMALIF under the version gate for
`IF`/`NOTIF` only (`796–804`), the version comparison for `VERIF`/`VERNOTIF`
(`806–812`: only a 4-byte element can be true), `CastToBool` otherwise (`815`),
negated for the NOT forms (`817–818`); a non-executing one pushes `false`
without popping (`789`, `823`).

`[SRC]` `interpreter.cpp:784–825`, `interpreter.cpp:792–793`, `interpreter.cpp:821`, `interpreter.cpp:796–804`, `interpreter.cpp:806–812`, `interpreter.cpp:815`, `interpreter.cpp:817–818`, `interpreter.cpp:789`, `interpreter.cpp:823`

### `execFlow_verif_preGenesis` (theorem, `lean/BsvScript/Properties/Eras.lean:507`)

**`OP_VERIF`/`OP_VERNOTIF` fail on a pre-Genesis coin even unexecuted** (`773–781`: the
skip at `777` needs `utxo_after_genesis`).

`[SRC]` `interpreter.cpp:773–781`, `interpreter.cpp:777`

### `execFlow_verif_postGenesis_preChronicle` (theorem, `lean/BsvScript/Properties/Eras.lean:517`)

**`OP_VERIF`/`OP_VERNOTIF` are skipped unexecuted on a post-Genesis, pre-Chronicle coin**
(`777–778`) and fail executed (`780`).

`[SRC]` `interpreter.cpp:777–778`, `interpreter.cpp:780`

### `scopeAfter` (def, `lean/BsvScript/SigOps.lean:62`)

The scope level after an instruction (`script.cpp:47–69`), tracked only under `fAccurate` or Genesis
(`tracked`): `OP_IF`, `OP_NOTIF`, `OP_VERIF`, `OP_VERNOTIF` open a scope (`50–54`), `OP_ENDIF` closes one
(`55–58`).

`[SRC]` `script.cpp:47–69`, `script.cpp:50–54`, `script.cpp:55–58`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `flow.ver`, `flow.verif` | 10 | `598–608`, `773–781`, `806–812` |
| `eras.utxo.pre-genesis`, `eras.utxo.post-genesis`, `eras.utxo.post-chronicle` | 42 | `interpreter.cpp:411–427`, `2269–2280`; `configscriptpolicy.cpp:65–154`; the sites named |

