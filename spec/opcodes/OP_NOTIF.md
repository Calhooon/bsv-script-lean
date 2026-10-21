# `OP_NOTIF` (`0x64`)

**Family** flow · **module** `BsvScript.Machine` · **landed at** #8 · **the switch** §2.4 of DESIGN · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- MINIMALIF (never set by the node at the pin) under the version gate (`796–804`)

## Semantics (the Lean docstrings that name it)

### `execIf` (def, `lean/BsvScript/Machine.lean:245`)

`OP_IF`/`OP_NOTIF`/`OP_VERIF`/`OP_VERNOTIF` (`784–825`): when executing, pop
the condition (`792–793`, `821`), MINIMALIF under the version gate for
`IF`/`NOTIF` only (`796–804`), the version comparison for `VERIF`/`VERNOTIF`
(`806–812`: only a 4-byte element can be true), `CastToBool` otherwise (`815`),
negated for the NOT forms (`817–818`); a non-executing one pushes `false`
without popping (`789`, `823`).

`[SRC]` `interpreter.cpp:784–825`, `interpreter.cpp:792–793`, `interpreter.cpp:821`, `interpreter.cpp:796–804`, `interpreter.cpp:806–812`, `interpreter.cpp:815`, `interpreter.cpp:817–818`, `interpreter.cpp:789`, `interpreter.cpp:823`

### `vNotifNested_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:351`)

`0 OP_NOTIF 1 OP_IF 1 OP_ENDIF OP_ELSE 0 OP_ENDIF` is valid: a nested conditional inside a taken `NOTIF` branch (`784–840`).

`[SRC]` `interpreter.cpp:784–840`

### `scopeAfter` (def, `lean/BsvScript/SigOps.lean:62`)

The scope level after an instruction (`script.cpp:47–69`), tracked only under `fAccurate` or Genesis
(`tracked`): `OP_IF`, `OP_NOTIF`, `OP_VERIF`, `OP_VERNOTIF` open a scope (`50–54`), `OP_ENDIF` closes one
(`55–58`).

`[SRC]` `script.cpp:47–69`, `script.cpp:50–54`, `script.cpp:55–58`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `flow.if`, `flow.notif`, `flow.nesting`, `flow.else`, `flow.unbalanced` | 156 | `interpreter.cpp:773–840` (the tracker `conditional_tracker.cpp:32–71`), `1828–1830` |

