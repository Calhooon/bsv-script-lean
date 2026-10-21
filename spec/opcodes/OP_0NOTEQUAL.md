# `OP_0NOTEQUAL` (`0x92`)

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

### `unaryI_abs` (theorem, `lean/BsvScript/Impl/Arith.lean:54`)

**`unaryI_abs`.** *What it says:* the implementation's unary family computes what `Ops.Arith.unary`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* `OP_1ADD` … `OP_0NOTEQUAL`
on the implementation (#50).

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `num.cmp.0notequal`, `num.cmp.booland`, `num.cmp.boolor`, `num.cmp.lessthanorequal`, `num.cmp.greaterthanorequal` | 738 | `interpreter.cpp:1229`, `1266–1268` (unary); `1282–1290`, `1300–1301` (the operand reads), `1332–1337`, `1351–1356` (binary) |

