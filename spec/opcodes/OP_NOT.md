# `OP_NOT` (`0x91`)

**Family** arithmetic (unary) · **module** `BsvScript.Ops.Arith` · **landed at** #9 · **the switch** `1222–1275` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)
- operands read as `CScriptNum` with the era's width (4 pre-Genesis, 750,000 post-Genesis, 32,000,000 post-Chronicle) and, under MINIMALDATA with the gate, the minimal check (`script_num.cpp:53–89`)

## Semantics (the Lean docstrings that name it)

### `unaryBounded` (def, `lean/BsvScript/Ops/Arith.lean:79`)

The unary opcodes whose result passes the post-Genesis width bound
(`+=`, `-=`, the negation's constructor): all but `OP_2DIV`, `OP_NOT` and
`OP_0NOTEQUAL` (booleans are `int64` assignments, `script_num.h:65–69`).

`[SRC]` `script_num.h:65–69`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `eras.spend.genesis`, `eras.spend.chronicle` | 6 | `verify_script_flags.cpp:71–78`; `interpreter.cpp:2321–2334`, `40–44`, `296–303`, `2112–2124` |
| `eras.height.p2sh`, `eras.height.dersig`, `eras.height.cltv`, `eras.height.csv`, `eras.height.uahf`, `eras.height.daa` | 16 | `verify_script_flags.cpp:32–81`; `validation.cpp:2973–2982`, `3473`; `chainparams.cpp:1038–1076`, `:28` |

