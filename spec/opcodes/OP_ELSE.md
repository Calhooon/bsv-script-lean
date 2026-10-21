# `OP_ELSE` (`0x67`)

**Family** flow · **module** `BsvScript.Machine` · **landed at** #8 · **the switch** §2.4 of DESIGN · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- post-Genesis a second `OP_ELSE` for the same `OP_IF` is unbalanced (`conditional_tracker.cpp:51–55`, `829–831`); pre-Genesis every further `OP_ELSE` toggles again (`61–64`)

## Semantics (the Lean docstrings that name it)

### `derive_preGenesis_coin` (theorem, `lean/BsvScript/Properties/Eras.lean:388`)

**Q3 (`docs/DESIGN.md` §9): a pre-Genesis output spent after Genesis.** *What it says:*
for a coin created below the Genesis height, whatever the spend height, on the block path and on the
mempool path of a node with no promiscuous word (`hp`; the route it excludes is in `derive_utxoEra`), the
interpreter reads the coin's era as pre-Genesis (no UTXO marker, `411–427`), the limits
are the pre-Genesis constants (`2282–2302`, `configscriptpolicy.cpp:65–154`), and the
spending era's bits (GENESIS, SIGPUSHONLY, CHRONICLE) are the spend height's
(`policy.h:225–244`, `verify_script_flags.cpp:71–78`). *Why it matters:* the pre-Genesis
UTXO rules (the 520-byte element, the 1,000-element stack, 4-byte numbers, `OP_RETURN`
invalid, P2SH, CLTV/CSV live, the second `OP_ELSE`) hang on the coin's era, and the version
gate and push-only rule on the spend's: the two are separate parameters of one word.

`[SRC]` `interpreter.cpp:411–427`, `interpreter.cpp:2282–2302`, `configscriptpolicy.cpp:65–154`, `policy.h:225–244`, `verify_script_flags.cpp:71–78`

### `execFlow_else_preGenesis` (theorem, `lean/BsvScript/Properties/Eras.lean:590`)

**A second `OP_ELSE` toggles again on a pre-Genesis coin** (`829–831` test
`has_op_else() && utxo_after_genesis`; `conditional_tracker.cpp:57–65`).

`[SRC]` `interpreter.cpp:829–831`, `conditional_tracker.cpp:57–65`

### `execFlow_else_postGenesis_second` (theorem, `lean/BsvScript/Properties/Eras.lean:599`)

**A second `OP_ELSE` is unbalanced on a post-Genesis coin** (`829–831`; `conditional_tracker.cpp:51–55`).

`[SRC]` `interpreter.cpp:829–831`, `conditional_tracker.cpp:51–55`

### `vIfElse_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:345`)

`0 OP_IF 0 OP_ELSE 1 OP_ENDIF` is valid: the false branch is skipped, the else branch runs (`784–840`).

`[SRC]` `interpreter.cpp:784–840`

### `vNotifNested_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:351`)

`0 OP_NOTIF 1 OP_IF 1 OP_ENDIF OP_ELSE 0 OP_ENDIF` is valid: a nested conditional inside a taken `NOTIF` branch (`784–840`).

`[SRC]` `interpreter.cpp:784–840`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `flow.if`, `flow.notif`, `flow.nesting`, `flow.else`, `flow.unbalanced` | 156 | `interpreter.cpp:773–840` (the tracker `conditional_tracker.cpp:32–71`), `1828–1830` |
| `eras.utxo.pre-genesis`, `eras.utxo.post-genesis`, `eras.utxo.post-chronicle` | 42 | `interpreter.cpp:411–427`, `2269–2280`; `configscriptpolicy.cpp:65–154`; the sites named |

