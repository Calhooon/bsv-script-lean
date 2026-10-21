# `OP_ADD` (`0x93`)

**Family** arithmetic (binary) · **module** `BsvScript.Ops.Arith` · **landed at** #9 · **the switch** `1277–1378` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)
- operands read as `CScriptNum` with the era's width (4 pre-Genesis, 750,000 post-Genesis, 32,000,000 post-Chronicle) and, under MINIMALDATA with the gate, the minimal check (`script_num.cpp:53–89`)

## Semantics (the Lean docstrings that name it)

### `binaryBounded` (def, `lean/BsvScript/Ops/Arith.lean:135`)

The binary opcodes whose result passes the post-Genesis width bound:
`OP_ADD`, `OP_SUB`, `OP_MUL` (`+=`, `-=`, `*=`, `script_num.cpp:166–167`, `script_num.cpp:196–197`,
`script_num.cpp:216–217`).

`[SRC]` `script_num.cpp:166–167`, `script_num.cpp:196–197`, `script_num.cpp:216–217`

### `binaryI_abs` (theorem, `lean/BsvScript/Impl/Arith.lean:79`)

**`binaryI_abs`.** *What it says:* the implementation's binary family computes what `Ops.Arith.binary`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* `OP_ADD` … `OP_MAX` on the
implementation (#50).

### `vAdd_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:273`)

`2 3 OP_ADD 5 OP_NUMEQUAL` is valid (`1304–1306`, `1338–1341`).

`[SRC]` `interpreter.cpp:1304–1306`, `interpreter.cpp:1338–1341`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `num.arith.add`, `num.arith.sub`, `num.arith.mul`, `num.arith.div`, `num.arith.mod`, `num.arith.min`, `num.arith.max`, `num.arith.1add`, `num.arith.1sub`, `num.arith.negate`, `num.arith.abs` | 4392 | `interpreter.cpp:1222–1275` (unary), `1277–1378` (binary), the operand read `script_num.cpp:53–89`, the result `:463–481` (`getvch`), the width checks `:164–165`, `:194–195`, `:214–215` (within `:142–220`); the number type `script_num.cpp`, `big_int.cpp:238–262` (`BN_div`/`BN_mod`: truncation, the dividend's sign) |
| `flags.v1.minimaldata.push`, `flags.v1.minimaldata.number` | 36 | `interpreter.cpp:433–434`, `473–479`, `331–358`; `script_num.cpp:53–89`, `int_serialization.h:97–129`; the reads `546`, `577`, `622`, `624`, `655`, `680`, `709`, `717`, `745`, `753`, `1015`, `1129`, `1163`, `1235`, `1300–1301`, `1386–1390`, `1524`, `1551`, `1717`, `1747`; `policy.h:190` |
| `eras.spend.genesis`, `eras.spend.chronicle` | 6 | `verify_script_flags.cpp:71–78`; `interpreter.cpp:2321–2334`, `40–44`, `296–303`, `2112–2124` |

