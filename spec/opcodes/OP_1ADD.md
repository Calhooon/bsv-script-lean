# `OP_1ADD` (`0x8b`)

**Family** arithmetic (unary) · **module** `BsvScript.Ops.Arith` · **landed at** #9 · **the switch** `1222–1275` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)
- operands read as `CScriptNum` with the era's width (4 pre-Genesis, 750,000 post-Genesis, 32,000,000 post-Chronicle) and, under MINIMALDATA with the gate, the minimal check (`script_num.cpp:53–89`)

## Semantics (the Lean docstrings that name it)

### `unaryI_abs` (theorem, `lean/BsvScript/Impl/Arith.lean:54`)

**`unaryI_abs`.** *What it says:* the implementation's unary family computes what `Ops.Arith.unary`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* `OP_1ADD` … `OP_0NOTEQUAL`
on the implementation (#50).

### `vNegZero_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:303`)

`<0x80> OP_1ADD 1 OP_NUMEQUAL` is valid: negative zero reads as zero on the block path, where MINIMALDATA is off (`1222–1240`, `script_num.cpp:67`).

`[SRC]` `interpreter.cpp:1222–1240`, `script_num.cpp:67`

### `vMinimalV1Mempool_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:405`)

`<01 00> OP_1ADD 2 OP_NUMEQUAL` at version 1 on the mempool path fails `SCRIPT_ERR_SCRIPTNUM_MINENCODE`: MINIMALDATA under the gate (`433`, `script_num.cpp:67`).

`[SRC]` `interpreter.cpp:433`, `script_num.cpp:67`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `num.arith.add`, `num.arith.sub`, `num.arith.mul`, `num.arith.div`, `num.arith.mod`, `num.arith.min`, `num.arith.max`, `num.arith.1add`, `num.arith.1sub`, `num.arith.negate`, `num.arith.abs` | 4392 | `interpreter.cpp:1222–1275` (unary), `1277–1378` (binary), the operand read `script_num.cpp:53–89`, the result `:463–481` (`getvch`), the width checks `:164–165`, `:194–195`, `:214–215` (within `:142–220`); the number type `script_num.cpp`, `big_int.cpp:238–262` (`BN_div`/`BN_mod`: truncation, the dividend's sign) |
| `num.encoding.nonminimal` | 553 | `interpreter.cpp:433` (`requireMinimal`), `script_num.cpp:53–89` (the constructor's minimal check at 67), `int_serialization.h:97–129` |
| `flags.v1.minimaldata.push`, `flags.v1.minimaldata.number` | 36 | `interpreter.cpp:433–434`, `473–479`, `331–358`; `script_num.cpp:53–89`, `int_serialization.h:97–129`; the reads `546`, `577`, `622`, `624`, `655`, `680`, `709`, `717`, `745`, `753`, `1015`, `1129`, `1163`, `1235`, `1300–1301`, `1386–1390`, `1524`, `1551`, `1717`, `1747`; `policy.h:190` |
| `eras.utxo.pre-genesis`, `eras.utxo.post-genesis`, `eras.utxo.post-chronicle` | 42 | `interpreter.cpp:411–427`, `2269–2280`; `configscriptpolicy.cpp:65–154`; the sites named |

