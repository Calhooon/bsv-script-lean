# `OP_7` (`0x57`)

**Family** push · **module** `BsvScript.Machine` · **landed at** #8 · **the switch** `488–507` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## Semantics (the Lean docstrings that name it)

### `hasCase` (def, `lean/BsvScript/Opcodes.lean:143`)

The opcodes that have a `case` label in `EvalScript`'s switch at the pin
(the case-label map, `docs/DESIGN.md` §3): `OP_1NEGATE`, `OP_1`–`OP_16`, the
flow, stack, splice, bitwise and equality opcodes `0x61`–`0x88`, the numeric,
crypto and expansion opcodes `0x8b`–`0xb9`. Everything else above the pushes
(`OP_RESERVED` `0x50`, `OP_RESERVED1/2` `0x89`/`0x8a`, `0xba`–`0xff`) reaches
the `default:` case, `SCRIPT_ERR_BAD_OPCODE` when executed (`interpreter.cpp:1795`).

`[SRC]` `interpreter.cpp:1795`

### `multisigSigOps` (def, `lean/BsvScript/SigOps.lean:36`)

The number a multisig adds (`script.cpp:75–123`) after the instruction `lastOp` with operand
`lastData`; `none` is `sigOpCountError`. Under `fAccurate` or Genesis a preceding `OP_1`–`OP_16` counts
its number (`74–77`; `DecodeOP_N`, `script.h:333`); otherwise after Genesis `OP_0` counts nothing
(`81–84`) and any other instruction's operand is read as a script number of at most four bytes (`85–91`),
minimally encoded (`98–104`) and non-negative (`106–111`), which `readNum … true 4` checks in that order,
the value added (`112`; within four bytes `getint` never clamps, `script_num.cpp:413–419`); before Genesis
without `fAccurate`, `MAX_PUBKEYS_PER_MULTISIG_BEFORE_GENESIS` = 20 (`115–118`, `consensus.h:50`).

`[SRC]` `script.cpp:75–123`, `script.cpp:74–77`, `script.h:333`, `script.cpp:81–84`, `script.cpp:85–91`, `script.cpp:98–104`, `script.cpp:106–111`, `script.cpp:112`, `script_num.cpp:413–419`, `script.cpp:115–118`, `consensus.h:50`

### `sigOpCount_opN_paths` (theorem, `lean/BsvScript/SigOps.lean:376`)

**T-SO8 (the three multisig paths).** *What it says:* `OP_2 OP_CHECKMULTISIG` counts 20 before Genesis
without `fAccurate`, 2 with it, and 2 after Genesis. *What it assumes:* nothing. *Why it matters:* the
consensus gate's pre-Genesis count charges every multisig the key limit (`script.cpp:119–122`); a P2SH
redeem script (`fAccurate`, `155–161`) and every count after Genesis read the key count from the preceding
`OP_1`–`OP_16` (`74–77`).

`[SRC]` `script.cpp:119–122`, `script.cpp:155–161`, `script.cpp:74–77`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `push.minimal`, `push.constant`, `push.truncated` | 760 | `473–481`, `331–358`, `488–507`, `script.h:163–198`, `450–451` |
| `flags.v1.minimaldata.push`, `flags.v1.minimaldata.number` | 36 | `interpreter.cpp:433–434`, `473–479`, `331–358`; `script_num.cpp:53–89`, `int_serialization.h:97–129`; the reads `546`, `577`, `622`, `624`, `655`, `680`, `709`, `717`, `745`, `753`, `1015`, `1129`, `1163`, `1235`, `1300–1301`, `1386–1390`, `1524`, `1551`, `1717`, `1747`; `policy.h:190` |

