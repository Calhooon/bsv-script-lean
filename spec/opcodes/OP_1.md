# `OP_1` (`0x51`)

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

### `vPushOnlyV1_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:393`)

An unlocking script `OP_1 OP_DUP` at version 1 fails `SCRIPT_ERR_SIG_PUSHONLY`: post-Chronicle the gate is on for version 1 (`2321–2334`); decided through `isPushOnly_eq_fuel`.

`[SRC]` `interpreter.cpp:2321–2334`

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

### `findAndDelete_op` (theorem, `lean/BsvScript/Sighash.lean:800`)

T-SH12a: **an instruction that begins no copy is kept whole** (`script.h:215–216`: `pc2 = pc`, `GetOp` advances
one instruction, and `:207` copies it at the next iteration): the opcode and its push data are copied and the walk
goes on after them. The pattern is compared only where the walk stands: at the start of each instruction `GetOp` reads,
and again right after each copy it deletes, the parser not run in between (`script.h:210–214`). So a copy inside an
instruction the walk read whole never matches (inside a push's data: the unit cases `script_tests.cpp:3858–3868` and
`:3878–3885`, the latter a copy running on into the next instructions), while one that begins where a deleted copy
ended matches even there (the script `0x03 0x03 0x02 0xff` with the pattern `0x03`: both copies deleted,
`0x02 0xff` left, decided as an example beside the reference's unit cases). A copy that begins at an instruction start is deleted even when it runs across several instructions
(`script_tests.cpp:3887–3892`: the push and `OP_1`; `:3906–3918`: `OP_0 OP_1`; T-SH12, T-SH12f).

`[SRC]` `script.h:215–216`, `script.h:207`, `script.h:210–214`, `script_tests.cpp:3858–3868`, `script_tests.cpp:3878–3885`, `script_tests.cpp:3887–3892`, `script_tests.cpp:3906–3918`

### `findAndDelete_single_pass` (theorem, `lean/BsvScript/Sighash.lean:888`)

T-SH12f: **the pass is single** (the reference's own two cases, `script_tests.cpp:3906–3918`): `OP_0 OP_0 OP_1 OP_1`
with the pattern `OP_0 OP_1` leaves `OP_0 OP_1`, a fresh copy that a second pass would delete. The deletion is not a
fixpoint, and the digest of a pre-FORKID signature check depends on that: a `FindAndDelete` iterated to a fixpoint
would hash a different scriptCode on such a script.

`[SRC]` `script_tests.cpp:3906–3918`

### `matchOne` (def, `lean/BsvScript/Standard.lean:87`)

One template opcode against the current instruction (`164–192`): a key of 33 to 65 bytes, a key hash of
20, a small integer (`OP_0`, or after Genesis any push of at most 4 bytes, `176–182`; or `OP_1` to `OP_16`, its
value, `183–185`), else the same opcode with no data (`189–192`). The solutions extended, or `none` for a
mismatch (`break`).

`[SRC]` `standard.cpp:164–192`, `standard.cpp:176–182`, `standard.cpp:183–185`, `standard.cpp:189–192`

### `solver_opTrue` (theorem, `lean/BsvScript/Standard.lean:336`)

**T-ST2.** *What it says:* the locking script `OP_TRUE` (`OP_1`) has no type in either era. *What it
assumes:* nothing. *Why it matters:* it is the corpus's usual output and coin (`corpus/tx`: `tx-00032`,
`tx-00037`), and with no type it makes every transaction that creates it non-standard and every input spending
it non-standard (`388–390`). `IsStandardTx` reports its first reason, so `scriptpubkey` (`493–497`) only
when no earlier one is met (the version, the size, the unlocking scripts, an output's `bare-multisig` or
`dust`, the data carrier's total, `431–491`): a zero-value `OP_TRUE` output is reported `dust`
(`TxPolicy.standardnessRefusal_preGenesis_witnesses`, T-STD7).

`[SRC]` `standard.cpp:388–390`, `standard.cpp:493–497`, `standard.cpp:431–491`

### `standardnessRefusal_preGenesis_witnesses` (theorem, `lean/BsvScript/TxPolicy.lean:751`)

**T-STD7 (the road's pre-Genesis rows, by shape).** *What it says:* at SV-node's mainnet default, for a
spend at 610,000 (before Genesis) of a coin of 600,000: a transaction creating a one-satoshi `OP_TRUE` output
is refused `scriptpubkey`; one creating a zero-value `OP_TRUE` output is refused `dust`, before its type is
reported (`standard.cpp:476–485`, then `:493–497`); one creating a standard output (pay to a key hash) from an
`OP_TRUE` coin is refused `bad-txns-nonstandard-inputs`. *What it assumes:* the witnesses' shapes. *Why it
matters:* these are the node's mempool verdicts on `tx-00032`, `tx-00037` and `tx-00038`, `tx-00035` and
`tx-00036` (`docs/records/20260927-231608-d123-road-s3.md` for `tx-00032`, `tx-00035`, `tx-00036` and `tx-00037`,
`docs/records/20260928-113333-road-a3-s3.md` for all five), which the spec's gate did not give before it modeled the standardness.

`[SRC]` `standard.cpp:476–485`, `standard.cpp:493–497`

### `standardnessRefusal_postGenesis_witnesses` (theorem, `lean/BsvScript/TxPolicy.lean:772`)

**T-STD8 (the same shapes after Genesis).** *What it says:* at SV-node's mainnet default, for a spend at
967,896 (after Chronicle) of a coin of the same height, the one-satoshi `OP_TRUE` output and the `OP_TRUE` coin
are not refused, and the zero-value output is refused `dust`. *What it assumes:* the witnesses' shapes. *Why it
matters:* after Genesis that default's gate refuses no output for having no standard type, and no coin (`1085`,
`1208`), and still refuses dust, a reason other than `scriptpubkey`; a P2SH output never reaches the gate after
Genesis, refused first by consensus (`610–623`, `bad-txns-vout-p2sh`, at `1036`).

`[SRC]` `validation.cpp:1085`, `validation.cpp:1208`, `validation.cpp:610–623`, `validation.cpp:1036`

### `opName` (def, `lean/Bsvs/Trace.lean:226`)

The opcode's name, through the generated table: the reference's stream operator's spelling
(`opcodes.cpp:8–72`) except in three places: a bare push, which the operator prints as its decimal
length (`opcodes.cpp:10–13`) and this as `PUSH<n>`; `OP_1NEGATE`, which the operator prints as `-1`
through its default branch and `GetOpName` (`opcodes.cpp:69–70`, `opcodes.cpp:88–89`) and this as
`OP_1NEGATE`; and every byte from `0xba`, where the generated table stops (`core_read.cpp:23`),
which the operator prints as `OP_UNKNOWN` (`opcodes.cpp:326–327`), or as `OP_INVALIDOPCODE` for
`0xff` (`opcodes.cpp:317–318`), and this as `0x<hex>`. `GetOpName` alone (`opcodes.cpp:75`) prints
`"0"`, `OP_UNKNOWN` for a bare push (it has no case for one, `opcodes.cpp:326–327`) and `"1"` to
`"16"`, where this prints `OP_0`, `PUSH<n>` and `OP_1`…`OP_16` (lean #32's second lens, B-15, and
its re-lenses; the file on every line, since the spec reads a bare number as `interpreter.cpp`'s,
its fourth re-lens, A4N-1).

`[SRC]` `opcodes.cpp:8–72`, `opcodes.cpp:10–13`, `opcodes.cpp:69–70`, `opcodes.cpp:88–89`, `core_read.cpp:23`, `opcodes.cpp:326–327`, `opcodes.cpp:317–318`, `opcodes.cpp:75`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `push.minimal`, `push.constant`, `push.truncated` | 760 | `473–481`, `331–358`, `488–507`, `script.h:163–198`, `450–451` |
| `flags.v1.minimaldata.push`, `flags.v1.minimaldata.number` | 36 | `interpreter.cpp:433–434`, `473–479`, `331–358`; `script_num.cpp:53–89`, `int_serialization.h:97–129`; the reads `546`, `577`, `622`, `624`, `655`, `680`, `709`, `717`, `745`, `753`, `1015`, `1129`, `1163`, `1235`, `1300–1301`, `1386–1390`, `1524`, `1551`, `1717`, `1747`; `policy.h:190` |

