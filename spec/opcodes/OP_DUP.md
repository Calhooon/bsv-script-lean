# `OP_DUP` (`0x76`)

**Family** stack · **module** `BsvScript.Ops.Stack` · **landed at** #10 · **the switch** `876–1055` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `vPushOnlyV1_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:393`)

An unlocking script `OP_1 OP_DUP` at version 1 fails `SCRIPT_ERR_SIG_PUSHONLY`: post-Chronicle the gate is on for version 1 (`2321–2334`); decided through `isPushOnly_eq_fuel`.

`[SRC]` `interpreter.cpp:2321–2334`

### `p2pkhScript` (def, `lean/BsvScript/TxPolicy.lean:742`)

A pay-to-public-key-hash locking script (`OP_DUP OP_HASH160 <20 bytes> OP_EQUALVERIFY OP_CHECKSIG`),
the template `standard.cpp:53–57`.

`[SRC]` `standard.cpp:53–57`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `stack.ops`, `stack.alt`, `stack.pick`, `stack.roll` | 96 | `interpreter.cpp:876–1055`; `limitedstack.cpp:211–302` |

