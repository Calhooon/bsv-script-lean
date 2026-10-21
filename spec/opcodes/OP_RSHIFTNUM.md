# `OP_RSHIFTNUM` (`0xb7`)

**Family** expansion (Chronicle) · **module** `BsvScript.Ops.Expansion` · **landed at** #18 · **the switch** `609–764` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- pre-Chronicle UTXO era: a no-op (discouraged under the policy flag); post-Chronicle: executes (`609–764`); in the evaluator since #18 (`lean/BsvScript/Ops/Expansion.lean`); at v1.2.3 `6504a3af`, `OP_SUBSTR`/`OP_LEFT`/`OP_RIGHT` use the fixed-width reader: at most eight bytes read as sign-magnitude; nine require a pure sign byte and a magnitude below 2^63, or exactly 2^63 with a negative sign; longer operands refuse `SCRIPT_ERR_SCRIPTNUM_OVERFLOW` (`int_serialization.h:61–118`, `script_num.cpp:80–91`, `interpreter.cpp:1807–1809`). The previous pin's reading and measurements are retained in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`)

## Semantics (the Lean docstrings that name it)

### `nopOrDiscourage` (def, `lean/BsvScript/Ops/Expansion.lean:28`)

Pre-Chronicle, each opcode's own branch (`OP_SUBSTR` `611–616`, `OP_LEFT` `644–649`, `OP_RIGHT`
`669–674`, `OP_LSHIFTNUM` `694–699`, `OP_RSHIFTNUM` `730–735`): a NOP, or the policy error.

`[SRC]` `interpreter.cpp:611–616`, `interpreter.cpp:644–649`, `interpreter.cpp:669–674`, `interpreter.cpp:694–699`, `interpreter.cpp:730–735`

### `rshiftnum` (def, `lean/BsvScript/Ops/Expansion.lean:277`)

`OP_RSHIFTNUM` (`728–764`): `values >>= n` on the `bint` branch
(`script_num.cpp:367–372`): `BN_rshift` on a sign-magnitude number, the
magnitude shifted, so the quotient toward zero (`Int.tdiv`); a count at or above
the value's bit width gives zero.

`[SRC]` `interpreter.cpp:728–764`, `script_num.cpp:367–372`

### `pushEncode_abs` (theorem, `lean/BsvScript/Impl/Expansion.lean:32`)

**`pushEncode_abs`.** *What it says:* pushing a number's encoding, read as the spec's, is pushing its packed
encoding. *What it assumes:* nothing. *Why it matters:* `OP_LSHIFTNUM`, `OP_RSHIFTNUM`, whose range test reads the
same encoding, computed once (#143).

### `rshiftnumI_abs` (theorem, `lean/BsvScript/Impl/Expansion.lean:210`)

**`rshiftnumI_abs`.** *What it says:* the implementation's `OP_RSHIFTNUM` answers what
`Ops.Expansion.rshiftnum` answers on the state it stands for. *What it assumes:* nothing. *Why it matters:*
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

### `rshiftnum_frame` (theorem, `lean/BsvScript/Properties/Hooks.lean:662`)

`OP_RSHIFTNUM` is a frame.

### `rshiftnum_ok` (theorem, `lean/BsvScript/Properties/Widths.lean:291`)

**W7 (the right shift's result width).** *What it says:* an `OP_RSHIFTNUM` that succeeds read its
count `n` from the top element, `0 ≤ n ≤ INT_MAX`, and its value `v` from the second, and replaced the
two by `r`: zero when `n` is at least `v`'s encoded width in bits, else `v` divided by `2ⁿ` toward zero;
`r` encodes in no more bytes than `v`. *What it assumes:* the opcode succeeded. *Why it matters:* the
quotient toward zero never grows the magnitude (`BN_rshift` on the magnitude, `big_int.cpp:376`, from the
`bint` branch of `operator>>=`, `script_num.cpp:367–372`), so the right shift needs no width test on its
result, as the reference has none. Its count is refused at its read (`744–747`: over the width
`SCRIPT_ERR_SCRIPTNUM_OVERFLOW`, non-minimal under the minimal rule `SCRIPT_ERR_SCRIPTNUM_MINENCODE`),
when negative (`SCRIPT_ERR_INVALID_NUMBER_RANGE`, `748–749`) and above `INT_MAX` (`SCRIPT_ERR_BIG_INT`,
`big_int.cpp:383–390`).

`[SRC]` `big_int.cpp:376`, `script_num.cpp:367–372`, `interpreter.cpp:744–747`, `interpreter.cpp:748–749`, `big_int.cpp:383–390`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `expansion.substr`, `expansion.left`, `expansion.right`, `expansion.lshiftnum`, `expansion.rshiftnum` | 83 | `interpreter.cpp:609–641`, `642–666`, `667–691`, `692–727`, `728–764`; `script_num.cpp:250–374` (`operator<<=`/`>>=`), `big_int.cpp:347–394`; each opcode's own pre-Chronicle branch, `611–616`, `644–649`, `669–674`, `694–699`, `730–735` (a NOP, or `SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS` under the flag; `765–771` is `OP_NOP1`/`OP_NOP9`/`OP_NOP10`'s case, the same rule at another site: corrected 2026-09-27 on the harness's lens of the Lean semantics' section) |
| `eras.utxo.pre-genesis`, `eras.utxo.post-genesis`, `eras.utxo.post-chronicle` | 42 | `interpreter.cpp:411–427`, `2269–2280`; `configscriptpolicy.cpp:65–154`; the sites named |

