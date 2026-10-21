# `OP_0` (`0x00`)

**Family** push · **module** `BsvScript.Machine` · **landed at** #8 · **the switch** the pushes: `473–481`; minimality `331–358` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- pre-Genesis UTXO: a push above 520 bytes is `SCRIPT_ERR_PUSH_SIZE` (`455–456`, `script.h:29`); post-Genesis: the memory budget only (`limitedstack.cpp:194–207`)
- under MINIMALDATA and the version gate the push must be the minimal form (`CheckMinimalPush` `331–358`, `474–479`; MINIMALDATA is a POLICY flag, never in a block word)

## Semantics (the Lean docstrings that name it)

### `multisigSigOps` (def, `lean/BsvScript/SigOps.lean:36`)

The number a multisig adds (`script.cpp:75–123`) after the instruction `lastOp` with operand
`lastData`; `none` is `sigOpCountError`. Under `fAccurate` or Genesis a preceding `OP_1`–`OP_16` counts
its number (`74–77`; `DecodeOP_N`, `script.h:333`); otherwise after Genesis `OP_0` counts nothing
(`81–84`) and any other instruction's operand is read as a script number of at most four bytes (`85–91`),
minimally encoded (`98–104`) and non-negative (`106–111`), which `readNum … true 4` checks in that order,
the value added (`112`; within four bytes `getint` never clamps, `script_num.cpp:413–419`); before Genesis
without `fAccurate`, `MAX_PUBKEYS_PER_MULTISIG_BEFORE_GENESIS` = 20 (`115–118`, `consensus.h:50`).

`[SRC]` `script.cpp:75–123`, `script.cpp:74–77`, `script.h:333`, `script.cpp:81–84`, `script.cpp:85–91`, `script.cpp:98–104`, `script.cpp:106–111`, `script.cpp:112`, `script_num.cpp:413–419`, `script.cpp:115–118`, `consensus.h:50`

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

### `solver` (def, `lean/BsvScript/Standard.lean:158`)

`Solver(scriptPubKey, era, typeRet, vSolutionsRet)` (`40–199`): the type, whether the script solves, and
the solutions (read by `isStandardOutput` for the multisig's counts). P2SH first (`72–83`: no type after
Genesis), then the data carrier (`85–105`: `OP_RETURN` before Genesis, `OP_FALSE OP_RETURN` in both eras,
pushes only after it, `CScript::IsPushOnly(pc)`, `script.cpp:209–220`), then the templates. `genesis` is the
era's Genesis.

`[SRC]` `standard.cpp:40–199`, `standard.cpp:72–83`, `standard.cpp:85–105`, `script.cpp:209–220`

### `isUnspendable` (def, `lean/BsvScript/Standard.lean:191`)

`CScript::IsUnspendable(era)` (`script/script.h:260–277`): after Genesis only `OP_FALSE OP_RETURN`
(`script/script.h:262–270`); before it also a leading `OP_RETURN` and a script above `MAX_SCRIPT_SIZE_BEFORE_GENESIS`
(`script/script.h:271–276`).

`[SRC]` `script/script.h:260–277`, `script/script.h:262–270`, `script/script.h:271–276`

### `isDust_iff` (theorem, `lean/BsvScript/Standard.lean:346`)

**T-ST3.** *What it says:* an output is dust exactly when its value is 0 and its script is not provably
unspendable in the era. *What it assumes:* nothing. *Why it matters:* the threshold is hard-coded to one
satoshi (`primitives/transaction.h:204`), so no setting moves it; a zero-value `OP_FALSE OP_RETURN` carrier is
never dust, and before Genesis neither is a leading `OP_RETURN`.

`[SRC]` `primitives/transaction.h:204`

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

