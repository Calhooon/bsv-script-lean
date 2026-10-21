# `OP_RIGHT` (`0xb5`)

**Family** expansion (Chronicle) · **module** `BsvScript.Ops.Expansion` · **landed at** #18 · **the switch** `609–764` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- pre-Chronicle UTXO era: a no-op (discouraged under the policy flag); post-Chronicle: executes (`609–764`); in the evaluator since #18 (`lean/BsvScript/Ops/Expansion.lean`); at v1.2.3 `6504a3af`, `OP_SUBSTR`/`OP_LEFT`/`OP_RIGHT` use the fixed-width reader: at most eight bytes read as sign-magnitude; nine require a pure sign byte and a magnitude below 2^63, or exactly 2^63 with a negative sign; longer operands refuse `SCRIPT_ERR_SCRIPTNUM_OVERFLOW` (`int_serialization.h:61–118`, `script_num.cpp:80–91`, `interpreter.cpp:1807–1809`). The previous pin's reading and measurements are retained in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`)

## Semantics (the Lean docstrings that name it)

### `nopOrDiscourage` (def, `lean/BsvScript/Ops/Expansion.lean:28`)

Pre-Chronicle, each opcode's own branch (`OP_SUBSTR` `611–616`, `OP_LEFT` `644–649`, `OP_RIGHT`
`669–674`, `OP_LSHIFTNUM` `694–699`, `OP_RSHIFTNUM` `730–735`): a NOP, or the policy error.

`[SRC]` `interpreter.cpp:611–616`, `interpreter.cpp:644–649`, `interpreter.cpp:669–674`, `interpreter.cpp:694–699`, `interpreter.cpp:730–735`

### `readInt64Operand` (def, `lean/BsvScript/Ops/Expansion.lean:33`)

The `OP_SUBSTR`/`OP_LEFT`/`OP_RIGHT` operand read at v1.2.3 `6504a3af`:
[SRC] `interpreter.cpp:622–625`, `655–656`, `680–681`, `script_num.cpp:53–91`.
After width and minimality, `none` from the fixed-width decoder becomes
`SCRIPT_ERR_SCRIPTNUM_OVERFLOW` (`interpreter.cpp:1807–1809`); successful
values saturate via `getint` (`script_num.cpp:396–422`). The previous pin's reading is retained in a history module withheld from the
public edition at the maintainers' request (group `d8-node-team-discretion`).

`[SRC]` `interpreter.cpp:622–625`, `interpreter.cpp:655–656`, `interpreter.cpp:680–681`, `script_num.cpp:53–91`, `interpreter.cpp:1807–1809`, `script_num.cpp:396–422`

### `right` (def, `lean/BsvScript/Ops/Expansion.lean:161`)

[SRC] v1.2.3 `6504a3af`, `OP_RIGHT` (`667–691`): as `OP_LEFT`, the data shrunk to its last `len`
bytes (`688`).

`[SRC]` `interpreter.cpp:667–691`, `interpreter.cpp:688`

### `toBytes_drop` (theorem, `lean/BsvScript/Impl/Elem.lean:202`)

**`toBytes_drop`.** *What it says:* an element's bytes after the first `n` are its list's. *What it assumes:*
nothing. *Why it matters:* `OP_SPLIT`, `OP_RIGHT`, `OP_SUBSTR` (#143).

### `readInt64Operand_eq` (theorem, `lean/BsvScript/Impl/Elem.lean:267`)

**`readInt64Operand_eq`.** *What it says:* the element's reader answers what the spec's reader answers on its
list. *What it assumes:* nothing. *Why it matters:* `OP_SUBSTR`, `OP_LEFT`, `OP_RIGHT` (#143).

### `rightI_abs` (theorem, `lean/BsvScript/Impl/Expansion.lean:127`)

**`rightI_abs`.** *What it says:* the implementation's `OP_RIGHT` answers what `Ops.Expansion.right`
answers on the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the
implementation (#50).

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

### `right_frame` (theorem, `lean/BsvScript/Properties/Hooks.lean:630`)

`OP_RIGHT` is a frame.

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `splice.substr.int64-reader` | 150 | [SRC] `int_serialization.h:61–118`, `script_num.cpp:80–91` at `6504a3af` |
| `expansion.substr`, `expansion.left`, `expansion.right`, `expansion.lshiftnum`, `expansion.rshiftnum` | 83 | `interpreter.cpp:609–641`, `642–666`, `667–691`, `692–727`, `728–764`; `script_num.cpp:250–374` (`operator<<=`/`>>=`), `big_int.cpp:347–394`; each opcode's own pre-Chronicle branch, `611–616`, `644–649`, `669–674`, `694–699`, `730–735` (a NOP, or `SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS` under the flag; `765–771` is `OP_NOP1`/`OP_NOP9`/`OP_NOP10`'s case, the same rule at another site: corrected 2026-09-27 on the harness's lens of the Lean semantics' section) |

