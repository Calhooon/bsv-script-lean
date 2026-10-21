# `OP_LSHIFTNUM` (`0xb6`)

**Family** expansion (Chronicle) · **module** `BsvScript.Ops.Expansion` · **landed at** #18 · **the switch** `609–764` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- pre-Chronicle UTXO era: a no-op (discouraged under the policy flag); post-Chronicle: executes (`609–764`); in the evaluator since #18 (`lean/BsvScript/Ops/Expansion.lean`); at v1.2.3 `6504a3af`, `OP_SUBSTR`/`OP_LEFT`/`OP_RIGHT` use the fixed-width reader: at most eight bytes read as sign-magnitude; nine require a pure sign byte and a magnitude below 2^63, or exactly 2^63 with a negative sign; longer operands refuse `SCRIPT_ERR_SCRIPTNUM_OVERFLOW` (`int_serialization.h:61–118`, `script_num.cpp:80–91`, `interpreter.cpp:1807–1809`). The previous pin's reading and measurements are retained in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`)

## Semantics (the Lean docstrings that name it)

### `nopOrDiscourage` (def, `lean/BsvScript/Ops/Expansion.lean:28`)

Pre-Chronicle, each opcode's own branch (`OP_SUBSTR` `611–616`, `OP_LEFT` `644–649`, `OP_RIGHT`
`669–674`, `OP_LSHIFTNUM` `694–699`, `OP_RSHIFTNUM` `730–735`): a NOP, or the policy error.

`[SRC]` `interpreter.cpp:611–616`, `interpreter.cpp:644–649`, `interpreter.cpp:669–674`, `interpreter.cpp:694–699`, `interpreter.cpp:730–735`

### `lshiftnum` (def, `lean/BsvScript/Ops/Expansion.lean:213`)

`OP_LSHIFTNUM` (`692–727`): `values <<= n` on the `bint` branch
(`script_num.cpp:306–319`): the size of the value plus `n / 8` bytes may not
exceed the number width (`scriptnum_overflow_error`), then the shift, then the
result's width checked again; the result `v · 2ⁿ` (`BN_lshift` on a
sign-magnitude number).

`[SRC]` `interpreter.cpp:692–727`, `script_num.cpp:306–319`

### `pushEncode_abs` (theorem, `lean/BsvScript/Impl/Expansion.lean:32`)

**`pushEncode_abs`.** *What it says:* pushing a number's encoding, read as the spec's, is pushing its packed
encoding. *What it assumes:* nothing. *Why it matters:* `OP_LSHIFTNUM`, `OP_RSHIFTNUM`, whose range test reads the
same encoding, computed once (#143).

### `lshiftnumI_abs` (theorem, `lean/BsvScript/Impl/Expansion.lean:166`)

**`lshiftnumI_abs`.** *What it says:* the implementation's `OP_LSHIFTNUM` answers what
`Ops.Expansion.lshiftnum` answers on the state it stands for. *What it assumes:* nothing. *Why it matters:*
the family on the implementation (#50).

### `expansion_exec_isSome` (theorem, `lean/BsvScript/Properties/Coverage.lean:92`)

The expansion family's hook answers exactly on the opcodes from `OP_SUBSTR` to
`OP_RSHIFTNUM` (`OP_SUBSTR`, `OP_LEFT`, `OP_RIGHT`, `OP_LSHIFTNUM`,
`OP_RSHIFTNUM`), and on no other byte. One of the six lemmas
`opExec_isSome_of_hookOwns` assembles.

### `expansion_exec_preChronicle` (theorem, `lean/BsvScript/Properties/Eras.lean:607`)

**The expansion opcodes are NOPs on a pre-Chronicle coin** (`611–618`, `644–650`, `669–675`,
`694–700`, `730–736`): `OP_SUBSTR`, `OP_LEFT`, `OP_RIGHT`, `OP_LSHIFTNUM`, `OP_RSHIFTNUM` do
nothing, or fail under DISCOURAGE_UPGRADABLE_NOPS (a policy flag); they execute only for a
coin created after Chronicle (#18; bsv-rs 0.3.28 gates them the same way, `flags.rs`
`UTXO_AFTER_CHRONICLE`, `spend.rs` `utxo_after_chronicle`).

`[SRC]` `interpreter.cpp:611–618`, `interpreter.cpp:644–650`, `interpreter.cpp:669–675`, `interpreter.cpp:694–700`, `interpreter.cpp:730–736`

### `lshiftnum_frame` (theorem, `lean/BsvScript/Properties/Hooks.lean:642`)

`OP_LSHIFTNUM` is a frame.

### `lshiftnum_ne_bigInt` (theorem, `lean/BsvScript/Properties/Widths.lean:223`)

**W6 (the left shift's count bound is reached only by overflow).** *What it says:* when the number
width is below 2²⁸, `OP_LSHIFTNUM` never refuses `SCRIPT_ERR_BIG_INT`. *What it assumes:* the width below
268,435,456. It holds on the block path (the consensus widths: 750,000 after Genesis, `consensus.h:64`;
32,000,000 after Chronicle, `consensus.h:66`) and at the policy default (10,000, `policy.h:156`), not at
every policy setting: `-maxscriptnumlengthpolicy` has no upper bound (`configscriptpolicy.cpp:192–215`
refuses only a negative value and 1 to 3; the mempool path uses it as set, `:108–109`). *Why it
matters:* the size test (`script_num.cpp:311–314`: the value's size plus `n / 8` bytes within the width)
runs before `bint::operator<<=` refuses a count above `INT_MAX` (`big_int.cpp:359–366`), and a count
above `INT_MAX` already asks for at least 2²⁸ bytes, so below that width the big-number refusal is dead
and `SCRIPT_ERR_SCRIPTNUM_OVERFLOW` is what such a count gets; on the mempool path of a node set to at
least 2²⁸ bytes plus the value's size (at exactly 2²⁸ only the zero value; `-maxscriptnumlengthpolicy=1GB`,
say, for every value) a count just above `INT_MAX` passes the size test (`script_num.cpp:311–314`) and is
refused as `SCRIPT_ERR_BIG_INT` (`1819–1822`).

`[SRC]` `consensus.h:64`, `consensus.h:66`, `policy.h:156`, `configscriptpolicy.cpp:192–215`, `configscriptpolicy.cpp:108–109`, `script_num.cpp:311–314`, `big_int.cpp:359–366`, `interpreter.cpp:1819–1822`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `expansion.substr`, `expansion.left`, `expansion.right`, `expansion.lshiftnum`, `expansion.rshiftnum` | 83 | `interpreter.cpp:609–641`, `642–666`, `667–691`, `692–727`, `728–764`; `script_num.cpp:250–374` (`operator<<=`/`>>=`), `big_int.cpp:347–394`; each opcode's own pre-Chronicle branch, `611–616`, `644–649`, `669–674`, `694–699`, `730–735` (a NOP, or `SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS` under the flag; `765–771` is `OP_NOP1`/`OP_NOP9`/`OP_NOP10`'s case, the same rule at another site: corrected 2026-09-27 on the harness's lens of the Lean semantics' section) |
| `eras.utxo.pre-genesis`, `eras.utxo.post-genesis`, `eras.utxo.post-chronicle` | 42 | `interpreter.cpp:411–427`, `2269–2280`; `configscriptpolicy.cpp:65–154`; the sites named |

