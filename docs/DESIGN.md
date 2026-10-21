# DESIGN v1: the machine model (frozen 2026-09-22, #5; three lenses folded)
Issue numbers on this page are the archived tracker's ([docs/GLOSSARY.md](GLOSSARY.md), "archived #n").
**Status.** v1 fixes the content the S1 issues implement. Every rule below is
read from bitcoin-sv **v1.2.3** at the pin (`docs/PROVENANCE.md`; `[SRC]` =
file:line at commit `6504a3aff`; **a bare number is a line of
`src/script/interpreter.cpp`**); a sentence without a citation is a design
choice, marked *(design)*. The two decisions that cannot move later are the
parameters record (§5.4, `docs/PARAMETERS.md`) and the trust boundary (§4.1).
v0 (2026-09-21) fixed the shape; the three-lens review of v1 is §11; the change
protocol is §10.

## 1. The objects

**1.1 Bytes.** A stack element is a byte vector (`valtype`). A script is a byte
vector parsed instruction by instruction by `CScript::GetOp2` (`script.h:163–198`):
an opcode byte, then for `0x01`–`0x4b` that many bytes, for `OP_PUSHDATA1/2/4`
a 1/2/4-byte little-endian length then the bytes; a truncated push fails the
parse (`script.h:192–193`; `GetOp` false → `SCRIPT_ERR_BAD_OPCODE`, `450–451`).
Parsing is lazy: the interpreter reads one instruction per step, so bytes after
a terminating `OP_RETURN` are never parsed (§2.4).

**1.2 Script numbers.** The number type is the integers `ℤ`. The reference
holds a `CScriptNum` as either an `int64` or a `bsv::bint` (OpenSSL BIGNUM),
chosen **per construction site** by the `big_int` argument (`script_num.h:60–63`,
default `false`; `script_num.cpp:72–90`), never by the magnitude: every
arithmetic, splice and stack-index read passes `utxo_after_genesis` (`1015`,
`1129`, `1163`, `1235`, `1300–1301`, `1386–1390`, `1717`, `1747`);
`OP_LSHIFTNUM`/`OP_RSHIFTNUM` pass `true` (`708–719`, `744–755`);
`OP_DEPTH`/`OP_SIZE` construct a `bint` directly (`968`, `1062`); the width-5
reads of CLTV/CSV (`546`, `577`), the width-4 reads of the two `CHECKMULTISIG`
counts (`1523–1526`, `1550–1553`) and the `OP_SUBSTR`/`OP_LEFT`/`OP_RIGHT`
operands (`622`, `624`, `655`, `680`) use the `int64` path. So on the branch in
force post-Genesis the values are unbounded integers and the only bound is the
encoded length.

The encoding is little-endian sign-magnitude (`int_serialization.h:23–59`
`serialize`, `61–118` `deserialize`; the `bint` path `big_int.cpp:559–568`,
`577–594` is the same encoding): zero is the empty vector; the magnitude's
bytes little-endian; if the top byte's bit 7 is set, a further byte `0x00`
(positive) or `0x80` (negative) is appended; else the sign is bit 7 of the top
byte. Minimality (`IsMinimallyEncoded`, `120–152`): size ≤ the length limit; the
top byte with bit 7 cleared is not zero unless the byte below it has bit 7 set
(so `0x80`, negative zero, and every `0x00`/`0x80` pad beyond the necessary one
are non-minimal). The arbitrary-precision decode maps negative zero to 0 and padding to the
encoded value. The fixed-width decode can reject at its signed range, as
recorded below. Every read of a number goes through the `CScriptNum`
byte constructor (`script_num.cpp:53–91`): first the length limit (`62`,
`scriptnum_overflow_error` → `SCRIPT_ERR_SCRIPTNUM_OVERFLOW`, `1807–1810`), then,
when `requireMinimal` (§5.3), the minimality check (`67`,
`scriptnum_minencode_error` → `SCRIPT_ERR_SCRIPTNUM_MINENCODE`, `1811–1814`).
The length limit is `MaxScriptNumLength` (§5.1) except the width-5 and width-4
reads above.

Four rules of the number type that change verdicts, written here so #7/#9/#10
inherit them:
- **Division truncates toward zero and the remainder takes the dividend's sign**
  (C++ `/` and `%`, `script_num.cpp:230`, `242`; `BN_div`/`BN_mod`,
  `big_int.cpp:242`, `255` `[LIT]` OpenSSL). In Lean this is `Int.tdiv`/`Int.tmod`,
  never `/`/`%` (which floor); the corpus carries `-7 2 OP_MOD`.
- **The post-Genesis result bound.** On the `bint` path `+=`, `-=`, `*=` and
  `<<=` throw `scriptnum_overflow_error` when the result's serialized size
  exceeds the length limit (`script_num.cpp:166–167`, `194–195`, `214–215`,
  `315–316`); `/=`, `%=`, `>>=` and unary minus never do. Pre-Genesis (`int64`)
  results are unbounded: `<ff ff ff 7f> OP_1ADD` pushes the 5-byte
  `00 00 00 80 00`. `OP_LSHIFTNUM`'s pre-check `size(x) + ⌊n/8⌋ > limit`
  (`script_num.cpp:311–314`) fires even for `x = 0`.
- **`SCRIPT_ERR_BIG_INT` is reachable**: `OP_RSHIFTNUM` with a count above
  `INT_MAX` throws `big_int_error` (`big_int.cpp:388–389` via
  `script_num.cpp:371`) → `SCRIPT_ERR_BIG_INT` (`1819–1822`, `script_error.h:82`).
- **The fixed-width reader.** The reading of record at v1.2.3 is a defined refusal ([SRC] `int_serialization.h:61–118`, `script_num.cpp:80–91` at `6504a3af`); the previous pin's reading and its measurements are recorded in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`).
- `getint` saturates to `INT_MIN`/`INT_MAX` (`script_num.cpp:406–417`) at the
  `OP_SUBSTR` family (`623`, `625`, `656`, `681`): modelled at those sites.

`OP_BIN2NUM` is `MinimallyEncode` (`int_serialization.h:154–208`; `1780–1792`:
the result must still satisfy the length limit, else
`SCRIPT_ERR_INVALID_NUMBER_RANGE`, `1789–1790`); `OP_NUM2BIN` minimally encodes
first (`1760`), fails when that is longer than the width
(`SCRIPT_ERR_IMPOSSIBLE_ENCODING`, `1761–1763`), else pads with `padRight`
(`limitedstack.cpp:60–71`) moving the sign bit to the last byte (`1771–1777`).
Truthiness is `CastToBool` (`119–130`): every byte zero, or only the top byte
`0x80` with the rest zero, is false.

The theorems (#7; `lean/BsvScript/Numbers.lean`): T1 `decode (encode z) = z`;
T2 `encode z` is minimal; T3 canonicality, for a byte list `b` whose entries are
bytes (`Bytes.valid b`: each below 256, the list being of `Nat`s) with a minimal
tail, `encode (decode b) = b`; T4 the reference's `MinimallyEncode` transcribed,
`minimallyEncodeRef b = encode (decode b)` for `Bytes.valid b` (the spec's
`minimallyEncode` is defined as `encode ∘ decode`); T5 `castToBool b ↔ decode b ≠ 0`
for `Bytes.valid b`; T6 the width lemma, for `n ≥ 1`,
`(encode z).length ≤ n ↔ |z| ≤ 2^(8n−1) − 1` (n = 4 is the
pre-Genesis operand range; `encode 2^31 = 00 00 00 80 00`); T7 `num2bin`'s
failure and length; T8 the v1.2.3 reader agrees with `decode` through eight bytes (`deserializeInt64_eq_decode`), has the exact acceptance predicate `deserializeInt64_isSome_iff`, refuses longer encodings (`deserializeInt64_long`), and has one encoding of the signed minimum (`deserializeInt64_min_iff`). `readInt64Operand_of_none` states the defined overflow refusal.

**1.3 The machine state.** `EvalScript` (`388–1833`) runs over: the main stack
and the alt stack, two `LimitedStack`s sharing one memory budget (the alt stack
is a child of the main stack, `1993` `makeChildStack`; `limitedstack.h:86–89`);
each element costs its size plus 32 bytes (`limitedstack.h:43, 163, 171`);
exceeding the budget throws `stack_overflow_error` → `SCRIPT_ERR_STACK_SIZE`
(`1815–1818`). **The memory counter is state that crosses phases**: it lives in
the root stack, `OP_TOALTSTACK` moves without accounting
(`limitedstack.cpp:292–305`), the alt stack dies with the wrapper without
decrementing (`1993–2005`; no destructor does, `limitedstack.h:93–102`), and
the P2SH copy copies the counter (`limitedstack.cpp:351–359`): bytes left on the
alt stack after the unlocking script keep consuming the budget through the
locking script. The condition state is a `conditional_tracker`
(`conditional_tracker.h:12–26`): a vector of branch conditions, a vector of
"else seen" marks, and a count of false conditions; execution is active iff the
false count is zero (`conditional_tracker.cpp:46–49`); `op_else` toggles the
innermost condition and adjusts the count (`57–65`). The program counter `pc`,
the position after the last `OP_CODESEPARATOR` (`pbegincodehash`, `407`,
`1445–1448`), the operation counter `nOpCount` (`432`; every opcode above
`OP_16`, `466`, plus the key count of every executed `CHECKMULTISIG`,
`1534–1536`), the post-Genesis flag `nonTopLevelReturnAfterGenesis` (`438`), and
the phase flag (`checksigData ≠ nullptr`: the unlocking script sees the locking
script, `2338–2352`, §4.2) complete the state. The alt stack, the tracker and
`pbegincodehash` are fresh per `EvalScript` call (`1984–2006`); the main stack
and the memory counter cross.

**1.4 The parameters.** `docs/PARAMETERS.md` (#6): the flag word, the five
limits, the activation heights, the `consensus` switch of the derivation, and
where each comes from. §5 says how they enter the semantics.

**1.5 The transaction context.** The spending transaction, the input index
`nIn`, the amount of the output being spent, and a `BaseSignatureChecker`
(`interpreter.h:52`) that answers `CheckSig`, `CheckLockTime`, `CheckSequence`
and `Version()` (`2254–2257`: the spending transaction's `nVersion`). The
version is a 32-bit word read two ways: signed by the gate (`34–38`) and
unsigned by CSV (`2212`), so a negative `nVersion` is non-malleable and passes
CSV's `≥ 2` (#22 states both). The UTXO's creation height enters only through
the flag word (§5.2).

## 2. The execution

**2.1 The verdict.** `VerifyScript` returns `std::optional<ScriptError>`
(`2304–2451`): `SCRIPT_ERR_OK` is *valid*; any other `ScriptError`
(`script_error.h:12–87`, 48 values) is *invalid* with that reason; an empty
optional means the cancellation token fired (`442–445`, `1589–1592`,
propagated `2345–2348`, `2365–2368`, `2409–2412`), which is timed only in
mempool validation (`validation.cpp:990–1005`, rejected as
`too-long-validation-time`) and never in block validation. The spec's `Verdict`
is `valid | invalid reason` with `reason` the reference's enum *(design)*. The
harness adds `undecided` for what is not a verdict: a cancellation, the
reference's own aborts (assertions are live in the reference build,
`validation.cpp:78`; `to_size_t_limited`'s precondition is
`script_num.cpp:452–457`. At v1.2.3 `6504a3af`, `OP_SPLIT` refuses positions
above `INT32_MAX` before this conversion (`interpreter.cpp:1718–1721`);
the v1.2.2 abort reading at v1.2.2 `interpreter.cpp:1718–1721` is history.
`OP_PICK`/`OP_ROLL` remain the separate Q8 sites. `catch(...)` →
`SCRIPT_ERR_UNKNOWN_ERROR`, `1823–1826`, is resource exhaustion), an input an
engine does not model (bsv-rs before Genesis), and an entry without a spec
verdict. An ENGINE's abort on an input the reference decides (a resource wall,
a crash, an exception, a timeout that survives one re-run at ten times the
adapter wall) is not `undecided` but a WITNESS under a class naming the
engine's mechanism (`engine.resource-abort`, `engine.timeout`, `engine.exception` since #32's
third lens: an exception inside the engine's own call or a crate panic; the SDKs'
`splice.num2bin.memory` and `bitwise.shift.bigint-limit`; `corpus/INDEX.md`
§4/§4b): D15 as written and D15a, ruled 2026-09-24 on #42; an entry is a
witness or an undecided run, never both. An SDK's refusal to DECODE a
transaction the reference decides is such an abort (the maintainers' ruling R3 on
#32, 2026-10-05, road 1: D15 as written; `engine.decode-refusal`): it is the
SDK's own decoder, never the adapter's failure (`harness/src/gosdk_codes.rs`
`DECODE_REFUSALS` tells the two apart under the adapters' shared code
`tx-decode`), ruled implementation-wrong, the engine's script status
`undecided` and the spec's script verdict kept. The transaction's validity, the
spec's script verdict and the engine's lack of one stay three things: the class
does not establish an engine failure on a transaction the reference would accept. The spec's total function picks the
natural reading at an abort site (Q8) and the record says so.

**2.2 The two-phase spend** (`VerifyScript`, `2304–2451`):
1. `valid_flags` (`2312–2313`, `2259–2262`): `SCRIPT_UTXO_AFTER_CHRONICLE`
   requires `SCRIPT_UTXO_AFTER_GENESIS`, else `SCRIPT_ERR_INVALID_FLAGS`.
2. `SCRIPT_ENABLE_SIGHASH_FORKID` implies `SCRIPT_VERIFY_STRICTENC` (`2315–2319`).
3. SIGPUSHONLY (`2321–2334`): when the flag is set and (Genesis without
   Chronicle, or Chronicle with `nVersion ≤ 1`), the unlocking script must be
   push-only (`CScript::IsPushOnly`, `script.cpp:209`), else
   `SCRIPT_ERR_SIG_PUSHONLY`.
4. Two stacks with the memory budget (`2336–2337`).
5. `EvalScript(scriptSig, checksigData = &scriptPubKey)` (`2338–2352`).
6. If P2SH is set and the UTXO is pre-Genesis, the stack is copied (`2354–2356`).
7. `EvalScript(scriptPubKey, nullptr)` on the resulting main stack (`2358–2372`).
8. The final-stack rule (`2374–2378`): an empty stack, or a false top element
   (`CastToBool`), is `SCRIPT_ERR_EVAL_FALSE`.
9. P2SH (`2380–2424`), only when the flag is set, the UTXO is pre-Genesis and
   the locking script has the P2SH shape (`IsP2SH`, `script.cpp:164–168`): the
   unlocking script must be push-only; the copied stack's top element is
   deserialized as a script and evaluated with a fresh alt stack and tracker;
   empty or false top is `SCRIPT_ERR_EVAL_FALSE`. (Rules at #23, `Properties/P2SH.lean`:
   disabled for a coin created after Genesis, grandfathered before.)
10. CLEANSTACK (`2430–2448`): when the flag is set, P2SH must be set too
    (`2435–2436`, `SCRIPT_ERR_INVALID_FLAGS`), and when the version gate
    enforces, the stack must hold exactly one element.

**2.3 The execution loop** (`EvalScript`, `388–1833`). Before the loop: the
UTXO era from the flags (`411–427`); `script.size() > MaxScriptSize` →
`SCRIPT_ERR_SCRIPT_SIZE` (`429–430`); `requireMinimal` = MINIMALDATA ∧ the
version gate (`433–434`). Per instruction: `GetOp` (`450–451`); pre-Genesis, a
push above 520 bytes is `SCRIPT_ERR_PUSH_SIZE` (`455–456`); `fExec` = the
tracker is active ∧ (no non-top-level `OP_RETURN` seen ∨ this is `OP_RETURN`)
(`459`); every opcode above `OP_16` counts against `MaxOpsPerScript`, executed
or not (`466–467`, `377–380`; `OP_RESERVED` `0x50` does not count); a disabled
opcode (`OP_2MUL`/`OP_2DIV` unless the UTXO era is post-Chronicle, `360–375`)
fails when executed, and pre-Genesis even when not (`470–471`). A push executes
(`473–481`; under `requireMinimal` it must be the minimal push form,
`CheckMinimalPush` `331–358`, else `SCRIPT_ERR_MINIMALDATA`); every other
opcode's case runs if `fExec`, and `OP_IF`…`OP_ENDIF` (`0x63`–`0x68`, which
includes `OP_VERIF`/`OP_VERNOTIF`) run always (`482`). After each instruction,
pre-Genesis, `stack + altstack > 1000` is `SCRIPT_ERR_STACK_SIZE`
(`1800–1803`). The four catches (`1807–1826`): overflow, minencode,
`stack_overflow_error` → `SCRIPT_ERR_STACK_SIZE`, `big_int_error` →
`SCRIPT_ERR_BIG_INT`, and `catch(...)` → `SCRIPT_ERR_UNKNOWN_ERROR`. At the end
an open conditional is `SCRIPT_ERR_UNBALANCED_CONDITIONAL` (`1828–1830`).

**2.4 Flow.** `OP_IF`/`OP_NOTIF` (labels `784–785`, block `773–825`): when
executing, pop the condition (empty stack → `SCRIPT_ERR_UNBALANCED_CONDITIONAL`,
`792–793`); under MINIMALIF and the version gate the element must be `[]` or
`[0x01]` (`796–804`; MINIMALIF does not apply to `OP_VERIF`/`OP_VERNOTIF`,
`796`); the value is `CastToBool`, negated for `NOTIF`; push it onto the tracker
(a non-executing `IF` pushes `false` without popping, `789`, `823`;
`conditional_tracker.cpp:37–44`). `OP_VERIF`/`OP_VERNOTIF` (`773–781`,
`806–814`): pre-Chronicle UTXO era they are `SCRIPT_ERR_BAD_OPCODE`, even
unexecuted pre-Genesis (post-Genesis only when executed); post-Chronicle they
branch on whether the top element is exactly the 4-byte little-endian
transaction version (`808–812`): any other size is `false` with no error, and
the element is popped either way (`821`). `OP_ELSE` (`827–833`): an empty
tracker, or post-Genesis a second `ELSE` for the same `IF`
(`conditional_tracker.cpp:51–55`), is unbalanced; pre-Genesis every further
`ELSE` toggles the branch again (`61–64`). `OP_ENDIF` (`835–840`). `OP_VERIFY`
(`842–854`). `OP_RETURN` (`856–871`): pre-Genesis UTXO → `SCRIPT_ERR_OP_RETURN`
(`867–869`); post-Genesis with no open conditional → the script succeeds
immediately with the stack as it is (`858–861`; the rest is never parsed);
inside a conditional (`865`) → nothing executes except `OP_IF`/`ELSE`/`ENDIF`
(`482`, which is how balance is still enforced), the op count (`466`), the
pre-Genesis push size (`455`) and the disabled-opcode check (`470`) still run,
and a later `OP_RETURN` reached with no open conditional still returns
`SCRIPT_ERR_OK` (`861`). `OP_NOP` (`516`); `OP_NOP1`, `OP_NOP9`, `OP_NOP10` are
no-ops unless DISCOURAGE_UPGRADABLE_NOPS (`765–771`). `OP_VER` (`598–608`):
post-Chronicle pushes the 4-byte version, else `SCRIPT_ERR_BAD_OPCODE`.
`CHECKLOCKTIMEVERIFY`/`CHECKSEQUENCEVERIFY` (`519–560`, `562–597`): for a
post-Genesis UTXO they are `NOP2`/`NOP3` (discouraged under the policy flag);
for a pre-Genesis UTXO with the flag they read a 5-byte number and call the
checker (#22).

## 3. The opcode table

One Lean definition per opcode (`opcodes.h:13–160`), each with its byte, its
enable history, its stack effect, its semantics, its failure conditions and its
`[SRC]` in `EvalScript`. **The switch is not in opcode order** (`OP_CAT` is at
`1687`, after the crypto cases); the ranges below are the case-label map at the
pin (`grep -n 'case OP_' src/script/interpreter.cpp`).

| family | opcodes | `[SRC]` | issue |
|---|---|---|---|
| push and constants | `0x00`–`0x4e` (§2.3, `473–481`), `OP_1NEGATE` `0x4f`, `OP_1`–`OP_16` `0x51`–`0x60`; `OP_RESERVED` `0x50` | `488–511` | #8 |
| flow | `OP_NOP` `0x61` (`516`), `OP_VER` `0x62` (`598–608`), `OP_VERIF`/`OP_VERNOTIF` `0x65`/`0x66` (`773–781`), `OP_IF`/`OP_NOTIF` `0x63`/`0x64` (`784–825`), `OP_ELSE` `0x67` (`827–833`), `OP_ENDIF` `0x68` (`835–840`), `OP_VERIFY` `0x69` (`842–854`), `OP_RETURN` `0x6a` (`856–871`) | §2.4 | #8 |
| stack | `OP_TOALTSTACK` `0x6b` (`876`), `OP_FROMALTSTACK` (`883`), `OP_2DROP` (`890`), `OP_2DUP` (`899`), `OP_3DUP` (`910`), `OP_2OVER` (`923`), `OP_2ROT` (`934`), `OP_2SWAP` (`946`), `OP_IFDUP` (`955`), `OP_DEPTH` (`966`), `OP_DROP` (`972`), `OP_DUP` (`980`), `OP_NIP` (`989`), `OP_OVER` (`997`), `OP_PICK`/`OP_ROLL` (`1006–1028`), `OP_ROT` (`1029`), `OP_SWAP` (`1040`), `OP_TUCK` `0x7d` (`1048–1055`) | `876–1055` | #10 |
| splice | `OP_SIZE` `0x82` (`1057–1064`), `OP_CAT` `0x7e` (`1687–1706`), `OP_SPLIT` `0x7f` (`1708–1739`), `OP_NUM2BIN` `0x80` (`1741–1778`), `OP_BIN2NUM` `0x81` (`1780–1792`) | as listed | #10 |
| bitwise | `OP_AND`/`OP_OR`/`OP_XOR` `0x84`–`0x86` (`1069–1106`; operands of equal size, `1080–1081`), `OP_INVERT` `0x83` (`1108–1119`), `OP_LSHIFT`/`OP_RSHIFT` `0x98`/`0x99` (bit shifts on byte vectors, `1121–1187`, `65–117`), `OP_EQUAL`/`OP_EQUALVERIFY` `0x87`/`0x88` (`1189–1217`) | as listed | #9 |
| arithmetic | unary `OP_1ADD`…`OP_0NOTEQUAL` `0x8b`–`0x92` (`1222–1275`; `OP_2MUL`/`OP_2DIV` `0x8d`/`0x8e` disabled unless the UTXO era is post-Chronicle, `360–375`), binary `OP_ADD`…`OP_MAX` `0x93`–`0xa4` (`1277–1378`), `OP_WITHIN` `0xa5` (`1380–1399`) | as listed | #9 |
| crypto | `OP_RIPEMD160`…`OP_HASH256` `0xa6`–`0xaa` (`1402–1443`), `OP_CODESEPARATOR` `0xab` (`1445–1448`), `OP_CHECKSIG(VERIFY)` `0xac`–`0xad` (`1450–1508`), `OP_CHECKMULTISIG(VERIFY)` `0xae`–`0xaf` (`1510–1682`) | §4 | #11 |
| expansion | `OP_NOP1` `0xb0`, `OP_NOP9`–`OP_NOP10` `0xb8`–`0xb9` (`765–771`); `CLTV` `0xb1` (`519–560`), `CSV` `0xb2` (`562–597`); `OP_SUBSTR` `0xb3` (`609–641`), `OP_LEFT` `0xb4` (`642–666`), `OP_RIGHT` `0xb5` (`667–691`), `OP_LSHIFTNUM` `0xb6` (`692–727`), `OP_RSHIFTNUM` `0xb7` (`728–764`): pre-Chronicle UTXO era `0xb3`–`0xb7` are no-ops (discouraged under the policy flag); post-Chronicle they execute | as listed | #18 (the Lean half landed 2026-09-22: `Ops/Expansion.lean`), #22 |
| reserved and undefined | `OP_RESERVED1/2` `0x89`/`0x8a`, `0xba`–`0xff` (`FIRST_UNDEFINED_OP_VALUE` `opcodes.h:152`): `SCRIPT_ERR_BAD_OPCODE` when executed (`1795`, the `default`) | | #18 (landed: `Op.hasCase`, `Machine.execFlow`) |

**Every byte is defined** (2026-09-22, #18's Lean half; `lean/BsvScript/Properties/Coverage.lean`):
every opcode with a `case` label is handled by the flow dispatch or answered by
one of the six family hooks (`coverage`, decided over the 256 bytes), each hook
answers exactly on the opcodes it owns, and the loop's per-opcode step
(`Machine.execStep`: a push, the separator, the switch, or nothing in a dead
branch) never yields the machine's `unimplemented` verdict
(`evalScript_ne_unimplemented`). The only verdict kind beyond `valid`/`invalid`
the machine carries is `undefined-in-reference` with its family name (Q7, §9);
the v1.2.3 fixed-width reader returns a value or `ScriptError`, and the
`undefinedReader` hook and its optional-success branches have been removed.
The reading of record at v1.2.3 is a defined refusal ([SRC] `int_serialization.h:61–118`, `script_num.cpp:80–91` at `6504a3af`); the previous pin's reading and its measurements are recorded in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`).

Three UTXO eras (`protocol_era.h:28–34`): **pre-Genesis** (the 520-byte element
and 1,000-element limits; 500 ops; 4-byte numbers; P2SH; CLTV/CSV live;
`OP_RETURN` invalid; `OP_VERIF`/`OP_VERNOTIF` invalid even unexecuted),
**post-Genesis** (the memory budget instead; the era's limits; `OP_RETURN`
terminates; one `ELSE` per `IF`; CLTV/CSV are NOPs), **post-Chronicle**
(`OP_VER`, `OP_VERIF`/`OP_VERNOTIF`, `OP_SUBSTR`/`OP_LEFT`/`OP_RIGHT`,
`OP_LSHIFTNUM`/`OP_RSHIFTNUM`, `OP_2MUL`/`OP_2DIV` execute; numbers to 32 MB).
The *spending* era adds the version gate (§5.3) and the post-Chronicle
`CHECKSIG` `scriptCode` rule (§4.2, `1475` tests `IsChronicle(flags)`).

## 4. Signatures and the trust boundary

**4.1 The trust boundary** *(design; re-stamped 2026-09-22 by the maintainers'
ruling of Q9 on #38, choice (A))*. `CPubKey::Verify` (`pubkey.cpp:183–214`) is:
`IsValid` (`size() > 0`, the size from the tag byte, `Set` invalidating a tag/length mismatch; `pubkey.h:54–57`,
`69–77`, `92`, `157`) → point decoding `secp256k1_ec_pubkey_parse`
(the key must be on the curve; hybrid `06`/`07` accepted here,
`eckey_impl.h:17–35`) → a non-empty signature → the lax DER parse
(`pubkey.cpp:32–175`, the `ecdsa_signature_parse_der_lax` of
`secp256k1/contrib/lax_der_parsing.c`; an `r` or `s` above 32 bytes or ≥ `n`
becomes the zero signature, `146–173`) → normalization of `s` → the ECDSA
equation `secp256k1_ecdsa_verify` (`secp256k1.c:462–476`, which rejects
`r = 0 ∨ s = 0`, `ecdsa_impl.h:204–205`). **Every step is an executable Lean
definition and the spec carries no axiom beyond Lean's three**
(`lean/BsvScript/Crypto/Secp256k1.lean`, #11): the field `F_p` on `Nat`, the
curve points and the scalar multiplication, the square root for point
decoding, the lax DER parser, the zero-signature substitution, normalization
(`s ≤ (n−1)/2`), the range and zero checks, and the equation itself,
`ecdsaVerify Q z r s = true ↔ 0 < r, s < n ∧ (u₁·G + u₂·Q ≠ O) ∧ (u₁·G + u₂·Q).x mod n = r`
with `u₁ = z·s⁻¹`, `u₂ = r·s⁻¹` mod `n` and `z` the 32-byte digest reduced
mod `n` (written as `ecdsaEquation`, with the reference's second `x` test,
`ecdsa_impl.h:228–261`). In front of it, also executable: the strict DER shape
check (`IsValidSignatureEncoding`, `177–245`), the pubkey encoding checks
(`132–164`, `312–329`), the hash-type byte, the sighash (§4.3), and the hashes
(`1402–1443`; SHA-1, SHA-256, RIPEMD-160). What is trusted is the transcription,
as for every other rule: `docs/HYPOTHESES.md` states that and the evidence
(the curve's facts and the secp256k1 signature RFC 6979's nonce procedure gives for key 1 and SHA-256("Satoshi
Nakamoto"), in low-S form, a community vector, checked by the crypto leg since lean #32's second lens; 1,340
cases from 200 signatures bsv-rs made through RustCrypto's `k256`, not libsecp256k1, labelled by construction; the
node oracle's `corpus/crypto` and `corpus/gen` columns, where libsecp256k1 decided, runs recorded against
`spec@e78a043` (`corpus/crypto`, 2026-09-24) and `spec@8389375` (`corpus/gen`, 2026-09-27), before D-1's change to the
lax parser, outside the tripwire, reported in `docs/CONFORMANCE-2026-09-27.md`; the mainnet inputs through the evaluator; the reference's own
vectors), and
keeps the reading the design started from (the equation as an axiom with a
trusted secp256k1 link in the evaluator) as the alternative the maintainers did not
choose. `lean/AXIOMS-ALLOWED` lists Lean's three axioms and nothing else;
`tools/axiom_check.py` enforces it on every listed theorem.

**`CheckLowS`** (`pubkey.cpp:353–363`, read under LOW_S at `282–287`) is the
lax parse followed by `!normalize`: a signature that does not lax-parse fails
the check (`SCRIPT_ERR_SIG_HIGH_S`); an `r` or `s` that overflows is replaced by
zero, which is low, so the check **passes** and the signature then fails
verification (`CHECKSIG` false → `SCRIPT_ERR_SIG_NULLFAIL` under NULLFAIL, not
`SIG_HIGH_S`); otherwise the check is `s ≤ (n−1)/2`.

**4.2 `CHECKSIG`** (`1450–1508`): two elements (`sig`, `pubkey`);
`CheckSignatureEncoding` (`265–310`): an empty signature is accepted here
(`272–273`) and fails the check (`2145–2147`); under DERSIG, LOW_S or STRICTENC
the strict DER shape (`275–280`); under LOW_S and the version gate the low-S
rule (`282–287`); under STRICTENC the hash-type byte must be defined
(`sighashtype.h:79–84`: base ∈ {1, 2, 3} after masking `0x20 | 0x40 | 0x80`), a
FORKID bit needs `SCRIPT_ENABLE_SIGHASH_FORKID`, a CHRONICLE bit needs
`SCRIPT_CHRONICLE`, and when FORKID is enabled the bit is mandatory
(`291–307`). `CheckPubKeyEncoding` (`312–329`; `IsCompressedOrUncompressedPubKey`
rejects `06`/`07` under STRICTENC, so the hybrid path is live only in pre-UAHF
replay). `scriptCode` = the bytes from `pbegincodehash` to the end of the
current script (`1473`); when executing inside the unlocking script
post-Chronicle, the locking script is appended (`1474–1481`). `CleanupScriptCode`
(`255–263`): only when FORKID is not enabled or the signature lacks the bit, the
signature is `FindAndDelete`d from the whole `scriptCode` (`1484`).
`checker.CheckSig` (`2133–2164`): the pubkey must be non-empty, the signature
non-empty, its last byte is the hash type, the digest is `SignatureHash`
(§4.3), then §4.1. A failed check with a non-empty signature under NULLFAIL and
the version gate is `SCRIPT_ERR_SIG_NULLFAIL` (`1491–1497`). `CHECKMULTISIG`
(`1510–1682`): the two counts read at width 4 (`1523–1526`, `1550–1553`), the
key count charged to `nOpCount` (`1534–1536`) and bounded by
`MaxPubKeysPerMultiSig`, the order rule, NULLFAIL (`1641–1647`) and NULLDUMMY
(`1664–1670`) under the version gate; #11 cites each line.

**4.3 The signature hash** (`SignatureHash`, `2112–2124`): if FORKID is enabled
and the type has the FORKID bit and not the CHRONICLE bit (`2118`), the
BIP143-style digest (`SignatureHashBIP143`, `2034–2084`: version;
`hashPrevouts` (zero under ANYONECANPAY); `hashSequence` (zero under
ANYONECANPAY, SINGLE or NONE); the outpoint; `scriptCode` as a length-prefixed
script (`OP_CODESEPARATOR`s kept); the amount; `nSequence`; `hashOutputs` (all,
or the matching output for SINGLE when `nIn < vout.size()`, else zero);
`nLockTime`; the 4-byte hash type; `2063–2081`); otherwise the original digest
(`SignatureHashOriginal`, `2086–2110`, with the serializer `1841–1958`: the
`OP_CODESEPARATOR`s are removed from `scriptCode` (`1862–1892`); other inputs'
scripts are blanked (`1904–1906`); ANYONECANPAY keeps only the signed input
(`1898–1900`, `1938–1943`); NONE drops the outputs and, **like SINGLE, zeroes
the other inputs' sequences** (`1911–1915`, `1945–1950`); SINGLE keeps outputs
up to `nIn` with the others blanked (`1925–1932`); and the two `one` cases,
`nIn` out of range or SINGLE with `nIn ≥ vout.size()`, **return** the constant
`1` as the digest, nothing hashed (`2089–2099`)).

**Q2 closed.** The original digest is reachable on mainnet post-Chronicle by
setting the CHRONICLE bit (`0x20`) in the hash type together with FORKID
(`0x40`) (`2118`; the bit is legal only under `SCRIPT_CHRONICLE`, `302–303`);
without FORKID it is unreachable under mainnet flags since UAHF
(`SCRIPT_ERR_MUST_USE_FORKID`, `305–306`; FORKID is a block flag from
`uahfHeight`, `verify_script_flags.cpp:55–59`; the guard is unconditional
because FORKID forces STRICTENC, `2315–2318`) and reachable only in historical
replay below that height. Both paths are modelled (#12). **Confirmed by execution 2026-09-24** (`corpus/gen`, the sighash family): the spec's own SV-node instance of the pinned build accepts every CHRONICLE-bit signature made over the ORIGINAL digest (the type, original and truncated-push rows: `sighash/type/*/forkid-chronicle*`, `sighash/original/*`) and refuses the one made over BIP143 (`sighash/dispatch/chronicle-over-bip143`), both instances (`corpus/INDEX.md` §4c); bsv-rs 0.3.28 does the opposite on all of them (the crate class `sighash.dispatch.chronicle-bip143`, §4).

## 5. The parameters and the flag branches

**5.1 The limits** enter as `eval_script_params` (`interpreter.h:136–166`:
`MaxOpsPerScript`, `MaxScriptNumLength`, `MaxScriptSize`,
`MaxPubKeysPerMultiSig`) and `verify_script_params` (`176–191`: plus
`MaxStackMemoryUsage`), built by `make_eval_script_params` /
`make_verify_script_params` (`2282–2302`) from the node's `ConfigScriptPolicy`,
the UTXO era of the flag word, and the `consensus` switch. Each limit is a
pre-Genesis constant, a post-Genesis consensus constant, or the node's policy
value, with two shapes to note: `GetMaxScriptNumLength` is four-way
(pre-Genesis 4 / post-Genesis / post-Chronicle / policy, a zero policy falling
back to the era's consensus limit, `configscriptpolicy.cpp:79–110`) and
`GetMaxStackMemoryUsage` is `INT64_MAX` pre-Genesis (`139–146`) and after it no
constant on either branch: the consensus branch returns the operator's MANDATORY
`-maxstackmemoryusageconsensus` (`148–151`; the node refuses to start without it,
`bitcoind.cpp:140–157`; a 0 is stored as `INT64_MAX`, `280–283`, `consensus.h:82`), a
named parameter of the semantics (rule 1), never a fixed budget.
`docs/PARAMETERS.md` §1 has every value with its kind, its default in
bitcoin-sv and in Teranode, and what a configured zero means.

**5.2 The flag word** is computed outside the interpreter and read inside it.
For a block, `GetBlockScriptFlags(params, height, era)` (`verify_script_flags.cpp:32–81`)
by activation height, where P2SH, UAHF and DAA test `height` (`39`, `55`, `65`)
and DERSIG, CLTV and CSV test `height + 1` (`43`, `47`, `51`); Genesis →
`SCRIPT_GENESIS` + SIGPUSHONLY; Chronicle → `SCRIPT_CHRONICLE`. For the
mempool, `GetScriptVerifyFlags(era, require_standard, …)` (`11–30`: the standard
set of the era, `policy.h:175–222`, plus FORKID when standardness is not
required; `-promiscuousmempoolflags` **replaces** the word, `21–24`). Per input,
`InputScriptVerifyFlags(era, utxoEra)` (`policy.h:226–245`) adds SIGPUSHONLY
(Genesis) and the UTXO era markers `SCRIPT_UTXO_AFTER_GENESIS` /
`SCRIPT_UTXO_AFTER_CHRONICLE` from the output's creation height.
`SCRIPT_VERIFY_MINIMALIF` and `SCRIPT_VERIFY_COMPRESSED_PUBKEYTYPE` are set by no
derivation: they reach the interpreter in an explicit word (the `verifyscript` RPC's
integer `flags`, `rpc/misc.cpp:697–702`) or, on a chain that does not require
standardness, in a `-promiscuousmempoolflags` word (`Params.flagWord_neverSet_off`). Teranode's engine computes the same word (BDK `4eab3acd`
`core/txvalidator.cpp:659–681` `CalculateFlags`) **under a height convention**:
in consensus mode the block flags at `blockHeight − 1` with the era of
`blockHeight`, in policy mode the mempool flags with the era of
`blockHeight + 1`, plus the input flags from the UTXO height (§6 fixes the
convention the corpus uses). `docs/PARAMETERS.md` §2 classifies every flag with
every read site.

**5.3 The version gate.** `IsMalleableTxnVersion(v) = v > 1` (`34–38`);
`EnforceNonMalleability(flags, v) = ¬(IsChronicle(flags) ∧ v > 1)` (`40–44`).
Seven restrictions hang on it, at seven `EnforceNonMalleability` sites plus one
inlined read: LOW_S (`285`), MINIMALDATA (`433`), MINIMALIF (`801`), NULLFAIL
(`1493`, `1643`), NULLDUMMY (`1666`), CLEANSTACK (`2441`), and SIGPUSHONLY
(`2327`, `IsMalleableTxnVersion` under `IsChronicle`); an exhaustive grep at the
pin for `EnforceNonMalleability` returns exactly the seven (corrected 2026-09-23,
#19's lens: the earlier "eight sites" counted the inlined read as a call). Post-Chronicle a version-2 spend runs with all seven off and a
version-1 spend with the flag word's own settings; pre-Chronicle the gate is
always true. The gate is one Lean function and every site calls it *(design)*.

**5.4 One semantics** *(design, frozen)*.
`eval : EvalParams → Context → ScriptSig → ScriptPubKey → Verdict` with
`EvalParams = {flags, limits}`: exactly what `EvalScript` and `VerifyScript`
read (every `flags` bit, every `params.` limit; the `checker.` calls are the
Context). The `consensus` switch is **not** in the record: nothing in
`388–1833` or `2304–2451` reads it; it is an argument of the second, cited
function `Params.derive (cfg : NodeConfig) (spendHeight utxoHeight : ℕ) (consensus : Bool) : EvalParams`
(#13, landed 2026-09-22 in `lean/BsvScript/Flags.lean` with this signature;
`docs/PARAMETERS.md` §6 lists each step with its lines), mirroring the reference's
split (`make_verify_script_params` + `GetBlockScriptFlags`/`GetScriptVerifyFlags`/
`InputScriptVerifyFlags`), so that a node's settings and the semantics never blur
(constitution 01; the theorem P5 of §9 says block validation never reads a
policy setting).

**5.5 The transaction context and the scope boundary** (#22). Script reads
the transaction through `TransactionSignatureChecker` (`interpreter.cpp:2126–2256`;
`lean/BsvScript/TxContext.lean` `txContext tx nIn amount`): the version
(`2254–2257`; the version gate §5.3, `OP_VER`, `CheckSequence`), the lock time
and the spent input's sequence (`CheckLockTime` `2166–2202`, `CheckSequence`
`2204–2250`; the constants `script.h:36`, `transaction.h:99–119`), the whole
transaction and the spent amount through the sighash (§4.3) and `CheckSig`
(`2133–2164`). Nothing else of the transaction reaches the interpreter. The
transaction's own validity (`CheckRegularTransaction`/`CheckCoinbase`,
`validation.cpp:519–639`: non-empty inputs and outputs, the size, the amounts in
range, pre-Genesis the sigop count, no null or duplicate outpoint, the coinbase
script length) is the gate the reference's vector runner applies before script
and is `lean/BsvScript/TxRules.lean`; a coinbase input's script is never
evaluated. The node's two transaction-level policy caps (`maxtxsizepolicy`,
`maxtxsigopscountspolicy`; `docs/PARAMETERS.md` §4) are `NodeConfig` fields read by
`BsvScript.TxPolicy`, the mempool's policy gate beside `TxRules` (2026-09-27); the
script semantics never reads them. The node's standardness tests (`IsStandardTx`, `AreInputsStandard`) are modeled
in `BsvScript.Standard` and refused by `TxPolicy.standardnessRefusal` before the two caps,
under `requireStandard` and `-acceptnonstdoutputs`. The block-level rules (fees, the UTXO set, ordering, maturity,
the block flags by height) are the transaction state machine's, chartered as S6 by #58 (2026-10-07;
`docs/DESIGN-S6.md`), which consumes this semantics as its per-input script oracle under the UTXO's era (Q3);
`docs/BLOCK-CONSENSUS.md` is the boundary's record as of 2026-10-05.

## 6. The evaluator CLI and the corpus format

`bsvs eval --tx <hex> --prevouts <json> [--params <json>] [--flags <u32|json>] [--spend-height <n>] [--consensus <bool>]`
→ `{"verdict": "valid" | "invalid", "reason": <ScriptError name>, "input": <i>, "params": {flags, limits}, "trace": [...]}`
*(design; landed at #14, 2026-09-22, as `eval/bsvs` from `lean/Bsvs/`: `--params` is
`--config sv|teranode` with `--spend-height`/`--consensus`, the word and the limits
are echoed per input, `code`/`message` carry the reason, `--trace` gives the
per-phase, per-instruction trace, each phase's result proven to be the loop's
(`Bsvs.Trace.traceLoop_fst`) and the steps the same computation by construction; `eval/README.md`)*.
The evaluator never reads a chain: the spend height is a parameter with a recorded default, the pinned
constant `DEFAULT_SPEND_HEIGHT` of `docs/PARAMETERS.md` §3 (the mainnet tip at the pin date), with
`consensus = true`; every prevout carries its own height (required). `--config`, `--spend-height` and
`--consensus` select the derivation; `--flags` replaces the word per input (the word's own UTXO bits then
decide the era: the RPC's word without `txo.height`, whose limits match the RPC's only under `consensus`
false, `rpc/misc.cpp:806–826`, `858–859`); the limits are never set directly. The output **echoes the
resolved `flags` and `limits`** so a verdict is never quoted without its parameters (SV-node's
`reportflags`, `rpc/misc.cpp:540–541`, `911–914`, echoes the word it ran, after the height's override;
lean #32's second lens, B-7, B-9, B-10, B-14).

The corpus entry (`harness/src/corpus.rs`, #4, revised at #5; one JSON object
per line):

```
{"id", "family", "rule",
 "tx": <hex of the spending transaction>,
 "prevouts": [{"txid": <display-order hex>, "vout", "script": <hex>, "satoshis", "height": <u32, required>}, ...]   // aligned with tx.inputs
 "params": {"spend_height": <u32>, "era": <derived label>, "consensus": bool, "tx_version": int},
 "flags"?: [<u32 per input>],                         // the explicit flag words; absent = derive from the heights (#13)
 "expect": {"<name>@<version>": {"verdict": "valid" | "invalid" | "undecided", "code"?: <SCRIPT_ERR_* at the pin>, "reason"?: <raw message>, "input"?: <i>}, ...},
 "reference"?: {"model", "expect"}, "note"?,
 "divergence"?: {"rule", "a", "b", "a_verdict", "b_verdict", "decided_by": <[SRC]>, "ruling": "spec-wrong" | "impl-wrong" | "open", "minimized"?, "minimized_prevouts"?, "note"}}
```

Conventions: `spend_height` is the height of the block the spend is in (the
consensus convention; a runner converts: BDK consensus mode takes it as is,
BDK policy mode takes `spend_height − 1` as the tip, SV-node's `verifyscript`
takes the block at `spend_height − 1` as `prevblockhash` when flags are not
given); a prevout `height` is required (`null` is not a corpus value: BDK
rejects `MEMPOOL_HEIGHT` in consensus mode as a DoS error,
`core/txvalidator.cpp:903–904`, and SV-node maps a `height` of −1 to `MEMPOOL_HEIGHT`, `rpc/misc.cpp:782–790`,
then assumes the next block, the tip's height plus one, `806–812`; lean #32's second lens, B-5); an entry has at least one input and one output
(`Entry::check`: BDK throws on zero inputs, `891–892`, and uses a constant-false
checker with zero outputs, `911–914`; `satoshis ≤ i64::MAX`). The manifest
beside a corpus carries the generator, its seed, the count, the file's sha256,
every implementation's configuration, and for GoBDK the bitcoin-sv tree it was
built from.

**The comparison** *(design)*: tier 1 is validity (`valid` / `invalid` /
`undecided`), the only divergence class; tier 2 is the `code` (the reference's
`ScriptError` name at the pin: SV-node and GoBDK share the enum, mapped back
from `ScriptErrorString`; bsv-rs has no code, its message-to-code table is a
cited table in its runner and a divergence *in the table* is a finding),
reported as a note; `reason` (the raw message) is never compared across
implementations; `input` is advisory, compared only when both sides report it;
an `undecided` is a property of the run, reported and never counted. **Q5
closed at the design level, uncovered by the corpus**: the transaction verdict
is the comparable object; "the first failing input" holds on the reference's
mempool path (`validation.cpp:2900–2924`, sequential) and not on its block path
(the checks are queued, `2711–2714`, run in parallel, `3418`, and the outcome is
a set, `3680`, `3714`); Teranode reports no index (GoBDK returns one error);
where the index matters the generator emits the single-input projections
beside the multi-input entry (#26). The spec's own verdicts are keyed
`spec@<commit>`. The rule vocabulary is `corpus/INDEX.md` §2.

## 7. The harness

Generators (`harness/src/gen.rs`: the reference-model families, the mutation
family; #26 adds the sighash, locktime, multi-input and historical-replay
families) → runners:
- **bsv-rs** in-process (`engine.rs`, done): every binary runs it in `Mode::Native`, the
  transaction's own version under the reference's flag word (`Spend::set_flags`);
  `engine::Mode`'s `V1Strict` and `V2MinimalOnly`, the predecessor's mode differential,
  are run by no binary.
- **SV-node** (#27): the spec's own instances of the pinned build (`harness/oracle/`:
  private regtest chains, `listen=0`, never a shared node's), each with **mainnet's
  Genesis and Chronicle heights** (the two an operator may set, `init.cpp:2609–2616`;
  every other height is regtest's compiled one, `chainparams.cpp:1456–1559`: BIP34 at
  100,000,000, `:1463`, against mainnet's 227,931, `:1038`, so no block of the road is
  held to a coinbase height push, `validation.cpp:6085–6093` `bad-cb-height` `[SRC]`;
  that requirement is block context and stays OUTSIDE the spec's transaction gate, by the
  maintainers' ruling R2 on #32, 2026-10-05). Two roads. **`verifyscript`** (`rpc/misc.cpp:506–915`;
  `run_svnode.rs`) for the script corpora: one call per entry and column, one element
  per input with `txo{lock, value, height}` and the explicit `flags` (the spec's own
  word, `flags_oracle.rs`), the `spec` column on the CONSENSUS instance (`bitcoin.conf`)
  and the `spec-mempool` column on the POLICY instance (`bitcoin-policy.conf`, the caps
  at the node's defaults). It is the
  **policy path** (`consensus{}` is hard-coded false, `misc.cpp:855–856`); the
  consensus instance reaches the consensus limits by zeroing every policy setting
  (`-maxopsperscriptpolicy=0 -maxscriptnumlengthpolicy=0 -maxscriptsizepolicy=0 -maxpubkeyspermultisigpolicy=0 -maxstackmemoryusagepolicy=0`,
  `configscriptpolicy.cpp:164–308`), recorded in the manifest; that these are the
  consensus path's numbers is Q6, answered below. `txo.height` re-derives the two
  UTXO-era bits and overrides them in the given flags (`misc.cpp:813–822`); a script is
  cancelled after the node's `maxstdtxvalidationduration` (`misc.cpp:867–873`; 3 ms by
  default, `txn_validation_config.h:38–40`, 300,000 ms in the instances'
  configurations) and the call after its `totalTimeout` (100 ms by default,
  `misc.cpp:614–626`; the runner passes 60,000 ms, `run_svnode --total-timeout`); a
  `timeout` or `skipped` is `undecided`; `stopOnFirstInvalid` is passed explicitly (its
  help says the default is true, `misc.cpp:565`, the code makes it false,
  `609–615`: recorded, rule 15). **The block road** (D97; `run_svnode --mode tx`,
  `harness/src/txroad.rs`) for `corpus/tx` and `corpus/road`: the `spec` column by
  `submitblock` of a block the harness assembles on the BLOCK instance
  (`bitcoin-block.conf`, a chain baked by `oracle_chain`), the `spec-mempool` column by
  `sendrawtransaction` on the policy instance holding a copy of that chain;
  `testmempoolaccept` does not exist at v1.2.2. Nothing is broadcast (private regtest
  nodes, `listen=0`, `dnsseed=0`): CLAUDE.md rule 10 holds by construction. The road's
  agreements are the instance's results: one whose verdict turns on the coinbase height
  requirement holds at the block instance's BIP34 height (100,000,000) only, and the road
  counts it APART from the ordinary agreements (`agree_instance_qualified` beside `agree`
  in `corpus/witnesses/sv-node/manifest.json`, the instance's activation context with it;
  `txroad::bip34_qualified`): on `corpus/tx` the two accepted coinbases `tx-00029` and
  `tx-00030`, whose scripts do not open with the height 620,600, so mainnet's rule would
  refuse their blocks. The excluded class (a coinbase without its height push at or above
  `BIP34Height`) is recorded from source, never executed by the road (R2 on #32).
- **Teranode** (#28; D14, 2026-09-23: the GoBDK shim is the script verdict's
  road, the Teranode instance a dated second leg, #41, local on the box by D37):
  the engine is GoBDK, the module Teranode v0.16.0 pins (`go.mod:12` at the tag; `4eab3acd`
  since #54, 2026-10-06; v0.15.9's `cdfa7814` until then),
  whose prebuilt `libGoBDK` is bitcoin-sv v1.2.2 at `879fc8b42` compiled in. The
  runner is the shim `harness/engines/gobdk/` (`d9e89da`): a cgo program on
  the pinned module, built from the local clone at the commit and checked to hash
  to Teranode's own `go.sum` sums, driven by `run_engine.rs` as an out-of-process
  adapter (`--engine gobdk`; the keys `gobdk@4eab3acd` and `gobdk-mempool@4eab3acd`),
  that calls GoBDK's own
  `VerifyScriptWithCustomFlags(extendedTX, utxoHeights, blockHeight, consensus, flags)`
  (`module/gobdk/script/txvalidator.go:120`; `core/txvalidator.cpp:905` honours
  the flags per input) under the spec's own word per input: the block column with
  the entry's `consensus`, the mempool column with `false`, `blockHeight` the spend
  height and one below it on the policy path (§6). The extended transaction is
  `nVersion ‖ 00 00 00 00 00 EF ‖ n ‖ (CTxIn ‖ CTxOut)* ‖ vout ‖ nLockTime`
  (`core/extendedTx.hpp:99–108`), built from the entry. GoBDK returns one
  error and no input index: the runner bisects (re-runs input *i* alone) when
  the index is wanted (not built at `d9e89da`: the shim reports index 0 for a
  one-input transaction and none otherwise). The shim's code table is GoBDK's own
  codes (`harness/engines/gobdk/codes.go`: the script domain is the reference's
  `ScriptError_t` ordinal, checked against the linked library's own texts), never
  Teranode's remap: Teranode's own `ValidateTransaction` adds standardness,
  sigops, fee and consolidation checks and remaps the errors
  (`ScriptVerifierGoBDK.go:351–443`); it is not the script oracle. Executed:
  every entry of the eight corpora agrees with the spec in both columns, verdict
  and code (`docs/records/20260926-210253-gobdk-shim-s4b.md` at `801e635`;
  `…-211729-gobdk-hunk-d83c-s4b.md` at `334ee23`, the driver's hunk re-cut for
  D83c; the hunk lands on the harness side) `[X]`; at `4eab3acd` (#54, 2026-10-06) every
  entry of the nine corpora (13,769) agrees with the spec in both columns, verdict
  and code, each verdict object identical to `cdfa7814`'s (`docs/records/20261006-014513-repin54.md`) `[X]`.
- **go-sdk** v1.7.2 and **@bsv/sdk** 3.0.0 (the ts-sdk; #29, adopted 2026-09-23 at v1.5.2 and 2.8.0, re-pinned 2026-10-05 by #51 and #52 to v1.7.0 and 2.8.10, then by #55 and go-sdk by #99 on 2026-10-12): out of
  process, the adapters `harness/engines/go/main.go` and `harness/engines/ts/runner.mjs`
  driven by `run_engine.rs` over JSON lines (`harness/src/engines.rs`: the pins of
  `docs/PROVENANCE.md` §1a checked at every spawn), under the spec's own word per input
  in both columns and, for the ts-sdk, in its default mode too (`corpus/INDEX.md` §4b).
  The default mode (@bsv/sdk without `verifyFlags`) is judged against both spec columns
  and its classes are scoped to it (the maintainers' ruling R4 on #32, 2026-10-05, road 1):
  the four omissions of the mode on the consensus side (NULLFAIL, the second `OP_ELSE`,
  the FORKID requirement; the fourth (a class under a still-private advisory: withheld, D135)) carry one disposition,
  implementation-wrong, each claim naming the engine, the mode, the corpus and the pin;
  a row the reference's block word accepts and only its relay word refuses is a POLICY
  omission, `flags.default-mode.policy-only`, ruled open and kept apart (the split reads
  the spec's consensus verdict, `spec_consensus`, as `limits.maxscriptnumlength.policy`
  does).

→ the report (#30): per entry every implementation's verdict beside the spec's;
every disagreement a witness (`divergence`) with its rule; classified
spec-wrong vs implementation-wrong with the citation that decides.

→ the Teranode gate (#95; [D] 2026-10-17): the pipeline's
per-release form for the second node. `make teranode-gate` reads the two pins
of `docs/PROVENANCE.md` §1a, the scenario column on both oracles (#66), the
script column (Teranode's by run_teranode, its runs since 2026-10-15 through the observation contract of #97, the
reference's committed column) and #88's obligation list, and writes
`docs/records/<stamp>-s8-95-gate-report-s3.md`: the counts per corpus and per
obligation kind, every difference a witness row in the list's six kinds
(theorem, witness, design, chain-split, report, open) with its citation and
where its ruling stands, and the delta from the previous gate record. The
report cites rulings and makes none; under the maintainers' framing rule
(2026-10-17, card Z8) a Teranode difference is read against its north star,
scale without a protocol change, so an architecture decision is a design row
with Teranode's reason cited, policy, and only the same blocks decided
differently is a chain split. `DRY_RUN=1` builds the page from the records on
disk and starts nothing (the shape record
`docs/records/20261017-231954-s8-95-gate-report-s3.md`); the live steps, which start
the nodes, are a hazard run's (`harness/README.md`, the gate's runbook). The page is public
(codes, classes, row ids, hashes and counts, never a node's message text); the steps' raw
log is a sibling file withheld from the public edition (the maintainers' ruling, 2026-10-17).

## 8. The generated spec

Unchanged from v0: one page per opcode from the Lean docstrings and the opcode
table, with its semantics, its history, its citation and the corpus entries
that exercise it (by `rule`); a rule without a corpus entry is flagged (#17,
landed 2026-09-22: `tools/specgen.py` → `spec/`, regenerated by `make spec` and
checked byte-identical by `make check`; the flagged list in `spec/rules.md` is
#26's input).

## 9. The questions and the opening theorems

- **Q1** closed by #6 (`docs/PARAMETERS.md`, `lean/BsvScript/Params.lean`).
- **Q2** closed (§4.3).
- **Q3** answered at the design level (§3, §5.2): a pre-Genesis output spent
  post-Genesis is evaluated under the pre-Genesis UTXO-era rules with the
  spending era's flag word (`policy.h:226–245` ORs only the era markers;
  `411–427` derives `utxoEra` from the markers alone); the derivation of the
  word and the limits from the heights is #13's `Params.derive`
  (`flagWord_utxoEra`: the interpreter reads back the era of the UTXO's height);
  the era rules per opcode are written at #20 (`lean/BsvScript/Properties/Eras.lean`,
  closed 2026-09-23; the P2SH history at #23, `Properties/P2SH.lean`; the corpus
  `corpus/eras`, the leg `make erascheck`).
- **Q4** narrowed (#2's finding, §7): Teranode exposes the wrapper's verdict;
  the engine is the reference's (#28). By citation at the tag (#28, 2026-09-26):
  the validator constructs the GoBDK verifier (`services/validator/TxValidator.go:115`,
  `newScriptVerifierGoBDK`), whose `ValidateTransaction`
  (`ScriptVerifierGoBDK.go:274–313`) calls GoBDK's `ValidateTransaction` at 297
  (the transaction-level checks and the scripts in one call) and remaps its
  errors at 351–443 (at v0.16.0); the script verdict beneath the remap is the shim's (§7), the
  node pipeline's verdict the instance's (#41).
- **Q5** closed at the design level, uncovered by the corpus (§6).
- **Q6** (new, #27): is "the consensus limits via zeroed policy settings" the
  same object as the reference's consensus path (`CScriptCheck` with
  `consensus = true`: built for every input when a block is connected,
  `CheckInputs(…, true, …, &vChecks)` at `validation.cpp:3381–3394`, the check constructed
  at `2702–2710` and queued at `2711–2714`; the mempool path builds one only to re-check a
  failed script under the mandatory flags, `2743–2750`, `2774–2781`, `2798–2805`; since
  D97 the harness reaches the block path itself, by `submitblock`, §7)? **Answered from
  source (2026-09-24; `harness/oracle/README.md`, "Q6, answered from source"):
  yes, for everything the interpreter reads.** `consensus` is read in exactly two
  functions, `make_eval_script_params` and `make_verify_script_params`
  (`interpreter.cpp:2282–2302`), which pass it to the five getters of
  `ConfigScriptPolicy` (`configscriptpolicy.cpp:65–154`); a policy value configured
  0 is stored as the consensus maximum by the setters of the op count, the script size
  and the multisig keys (`:180–183`, `231–233`, `257–260`) and as `INT64_MAX` by the
  stack memory setter (`:289–292`), the figure the consensus branch returns too when the
  operator's MANDATORY `-maxstackmemoryusageconsensus` is 0 (`148–151`, `280–283`;
  `bitcoind.cpp:140–157`), as the spec's instances set it; the number-length setter
  stores the 0 itself (`:209–212`) and its getter resolves 0 to the era's consensus
  width (`:98–106`); so
  both branches return the same number for every limit and the RPC evaluates under
  the consensus limits on the policy path. What differs sits outside `CScriptCheck`
  (the mempool's standardness gate, modeled since 2026-09-28 by `BsvScript.Standard` and
  `TxPolicy` (§5.5), and the block-connection wrapper in `validation.cpp`, now assigned to the transaction state machine, S6 (#58; `docs/DESIGN-S6.md`)); D97 runs the `tx.*` family through both (#27). Written here
  on 2026-09-26 (C3's lens 3, C10).
- **The operand reader (#57).** The reading of record at v1.2.3 is a defined refusal ([SRC] `int_serialization.h:61–118`, `script_num.cpp:80–91` at `6504a3af`); the previous pin's reading and its measurements are recorded in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`). [X] The official v1.2.3 x86-64 Linux release binary was measured on 2026-10-07, record [20261007-014131-x86-123.md](records/20261007-014131-x86-123.md): all 1,157 `corpus/gen` entries agree with the node of record in both columns, including code, input index and reason text.
- **Q8** (new, #10): the reading at the reference's abort sites (§2.1).
- **Q9 ruled** (the maintainers, 2026-09-22, on #38; choice (A)): the ECDSA equation
  stays an executable definition with no axiom; §4.1 re-stamped to say so;
  `docs/HYPOTHESES.md` keeps both readings.

The opening theorems (#16), stated from this design: **P1** canonicality (T1–T3);
**P2** `castToBool_iff` and the width lemma (T5, T6); **P3** gate
non-interference: with `flags.chronicle` and `1 < version`, `eval` is invariant
under the seven gated bits (the CLAUDE.md gotcha as a theorem; stated at #16
with the two side conditions found at the reference's ungated reads: DERSIG,
STRICTENC or FORKID set, since LOW_S also selects the strict DER shape,
`275–280`; and P2SH set, since CLEANSTACK without P2SH is an invalid word,
`2432–2435`; the mainnet word satisfies both); **P4** phase
crossing: the locking phase depends on the unlocking phase only through the
main stack and the memory counter (§1.3); **P5** parameter separation:
`Params.derive` with `consensus = true` depends only on the consensus fields of
`NodeConfig` (constitution 01; proven at #13 as `derive_consensus_separation`
with its verdict-level corollary, beside `blockScriptFlags_policy_off`, the
block word never carrying a policy flag, and `verifyScript_relay_block_version2`,
the relay and block words judging a version-2 spend post-Chronicle the same
but for DISCOURAGE_UPGRADABLE_NOPS; `lean/BsvScript/Flags.lean`). Cheap and real: `opreturn_suffix` (the loop from
a top-level `OP_RETURN` onward never reads the bytes after it, `858–861`; the
script-size check before the loop, `429–430`, and every signature digest taken
earlier in the script, whose scriptCode runs to the script's end, `1473`, `1569`,
still cover them) and `checksig_empty_sig` (an
empty signature never invokes the predicate, `2145–2147`, axiom-free).
Determinism and termination are by construction (a total function;
`termination_by` on the remaining bytes, each `GetOp` consuming at least one,
`script.h:173`; the semantics has no `LSHIFT`/`RSHIFT` chunk loop, the reference's steps of `INT32_MAX`
bits, `interpreter.cpp:1141–1149` for `OP_LSHIFT` and `1175–1183` for `OP_RSHIFT`, being one shift by `n` here; the multisig loop decreases the key count,
`termination_by … nKeys`; lean #32's second lens, C-6). Termination is listed as a definitional
fact, not a theorem; determinism, a definitional fact too, is also stated as #16's
done-bar asked, by `Eval.verifyScript_deterministic` (`lean/BsvScript/Eval.lean`,
proved by rewriting), and carries nothing beyond the function being a function.

## 10. The change protocol

v1 is frozen: §4.1 and §5.4 do not move without a maintainers' ruling. A correction
to a cited rule replaces the sentence and re-cites (CLAUDE.md rule 9); a new
opcode-level fact found at S1 is written in the opcode's module and this page
is not re-stamped for it. Every S1 issue cites the section it implements.
`tools/cite_check.py` (#43; a file of the harness side alone, by `docs/OWNERS`): every
`file:line` citation in the docs and the Lean docstrings is resolved to its
pinned source and anchored on a grep pattern at the pin (a symbol within the
cited lines, or the cited lines' own text), and `make check` fails when an
anchored pattern moves (the `cite` leg, the twenty-first, since `f84a62a`).

## 11. The v1 review (2026-09-22, the done-bar of #5)

Three lenses, read-only, each on the source at the pin: **A** (fidelity: every
citation of §1–§5 checked line by line), **B** (the semantics and the Lean:
totality, the number model, the state, the trust boundary, the parameters
record, the verdict, the opening theorems), **C** (the harness and the formats
against GoBDK, `verifyscript`, bsv-rs and the extended-transaction layout).
Folded: the `bint`/`int64` selector is the construction site; the five
verdict-changing number rules of §1.2; the memory counter and the multisig op
count in the state; the trust boundary restated as the ECDSA equation with the
lax DER parser and point decoding executable in front; `CheckLowS`'s
overflow-passes rule; NONE zeroes the other inputs' sequences; the `one` digest
is returned, not hashed; §3 regenerated from the case-label map; `consensus`
moved out of `EvalParams`; the corpus format (spend height, explicit flags,
required prevout heights, the `code` vocabulary, the `Divergence` record, the
entry checks); the SV-node runner as `verifyscript`, the policy path, with the
zeroed-policy configuration and the timeout rules; the Teranode runner as
`VerifyScriptWithCustomFlags`; Q5 scoped; Q6–Q8 opened; the citation drift
swept. Two reference-documentation findings booked on #6 (`stopOnFirstInvalid`;
GoBDK's `SCRIPT_ERR_ILLEGAL_RELAX` name at bitcoin-sv's
`SCRIPT_ERR_ILLEGAL_CHRONICLE` ordinal).

## 12. The layer-4 vendoring interface (#35, 35a)

**Status (2026-09-29).** The siblings' layer 4 (translation validation of
their generated scripts, tracked in the siblings' own trees) consumes this semantics. The
maintainers' D22 re-cut #35 as that interface and D44 ruled 35a's content; D44's
toolchain clause is moot since the joint re-pin R6 put the spec and both
siblings at Lean `v4.34.0` with Mathlib `5ed2965` (`docs/PROVENANCE.md` §1a).
This section is the interface: what a consumer requires and imports (12.1),
what it must not rely on (12.2), the Mathlib surface (12.3), the gadget-level
API (12.4), the evaluator on a foreign fixture (12.5) and the tag scheme
(12.6). Nothing of a sibling's verifier, script generator or contract enters this tree
(CLAUDE.md rule 5): #35's done-bar, one sibling's emitted verifier judged by
`eval/bsvs` at the tag, is the sibling's act, recorded in its own tree.

**12.1 What a consumer requires and imports.** The Lake package is `bsvscript`
in `lean/` of this repository; a consumer's `lakefile.toml` names it as

```toml
[[require]]
name = "bsvscript"
git = "https://github.com/Calhooon/bsv-script-lean"
rev = "<the tag, 12.6>"
subDir = "lean"
```

and requires Mathlib, if it uses Mathlib itself, at the spec's revision: Lake
admits one Mathlib per build graph. A scratch consumer outside the tree that
requires the package this way at `b3406bf` builds cold in 213.28 s on the Studio
at two Lean threads (Lake's own clone over GitHub, the 33 modules of the library
and one of its own, Mathlib's oleans from the shared cache: `Build completed
successfully (8959 jobs)`), and its kernel decides a vector of its own on the
spec's definitions `[M]` (`docs/records/20260929-015132-consumer-35-s2.md`). At
`v0.2.0` (`21ae89e`), the same consumer, now also naming the gadget API's worked example
(`BsvScript.Gadget.HashLock.hashLock_triple`, its axioms Lean's three), builds cold in
58.19 s at a maximum resident set of 1,910,013,952 B (`Build completed successfully (1041 jobs)`,
against `v0.1.0`'s 8,959: the narrowing's effect, 12.3) `[M]` (`docs/records/20260929-214540-consumer-v020-35-s2.md`). Lake
builds only what the consumer's
imports reach. `import BsvScript` (the library root) reaches every module of
`lean/BsvScript/`; a narrower import reaches fewer (the closures read from the
modules' import lines, at `cae8c35` `[X]`; the same instrument gives `b3406bf`'s
column, 4, 5, 9, 14, 17, 19, 23 and 33, before #50's eight `BsvScript.Impl`
modules entered `Eval`'s imports):

| import | what it gives | modules in its closure |
|---|---|---|
| `BsvScript.Machine` | the state, `loop`, `evalScript`, `verifyScript exec` for a caller's own opcode hook (§2) | 4 |
| `BsvScript.Tx` | the decoder `Tx.decodeTx` | 5 |
| `BsvScript.TxRules` | the transaction's consensus gate, `checkRegularTransaction` (§5.5) | 9 |
| `BsvScript.TxContext` | `txContext tx nIn amount`, the checker's context (§5.5) | 14 |
| `BsvScript.Eval` | the evaluator `Eval.verifyScript params ctx scriptSig scriptPubKey : Verdict` (§5.4) with every family hook, `Eval.opExec` | 25 |
| `BsvScript.Flags` | `Params.derive cfg spendHeight utxoHeight consensus`, the flag word and the limits from a node's settings (§5.2, §5.4) | 27 |
| `BsvScript.TxPolicy` | the mempool's gate: standardness, then the two caps (§5.5) | 31 |
| `BsvScript` | all of the above and the theorems, `BsvScript.Properties.*`, `BsvScript.Gadget`, `BsvScript.Gadget.HashLock` and the eight `BsvScript.Impl.*` | 43 (with the root) |

`Bsvs.*` (the CLI's Lean side), `Test.*`, `TestSupport` and the fifteen
`lean_exe`s are not the interface and never enter a consumer's build.

**12.2 What a consumer must not rely on.** (1) Mathlib through the spec (D44):
the spec imports Mathlib only in `lean/BsvScript/Numbers.lean`, whose lines 1–74 name
74 Mathlib-side modules (the narrowing, landed at `a210516`), and no other
module of `lean/BsvScript/` imports any (12.3); a consumer that uses Mathlib
imports it itself and never takes a Mathlib name through `import BsvScript`,
which a later tag may narrow or remove. (2) The compiled copies: the 36
`@[csimp]` implementations (#45's 13 in `Machine` and `Numbers`, the number leaves on
7-byte limbs since #53; the 7 transaction readers of ask 4 (a) in `Tx`; #48's 14
depth-test copies and its hex loop; #50's array-backed machine of `BsvScript.Impl`,
reached through `Eval.opExecI` and `verifyScriptI` by `verifyScript_eq_I`), and the
helpers they call (`Machine.takeExact`, `Machine.atLeast`), are code proven equal to the
definitions (lean #32's second lens, A-8); a
consumer's statements name the definitions (`Machine.loop`,
`Eval.verifyScript`, `Tx.decodeTx`), which are the semantics. (3) Anything
outside `lean/`: the harness, the corpus and `eval/` are not Lake-consumed;
`eval/bsvs` runs from a checkout at the tag (12.5). (4) An unfolding: the
interface is the definitions' signatures and the theorems' statements at the
tag; a consumer's proof that unfolds a definition is re-checked at every new
tag (12.6 says which tags can move a definition).

**12.3 The Mathlib surface** `[M]` (`docs/records/20260929-013409-mathlib-surface-35-s2.md`,
at `b3406bf`, its instrument and output beside it). One module imports Mathlib,
`BsvScript.Numbers` (`Numbers.lean:1` at `b3406bf`; lines 1–74 since `a210516`); no other file under `lean/` does. Every
module that imports `Numbers` (all but `Opcodes` and `Params`) still sees all of
it: `import BsvScript` loads 10,777 modules, 8,908 of them Mathlib-side (Mathlib
and the packages it brings). In the kernel terms, 216 of the library's 1,806
named declarations use a Mathlib-side constant (247 distinct): 49 in `Numbers`
and 167 in 25 other modules, mostly the order and monoid instances and the simp
lemmas the elaborator picks with Mathlib in scope; seven modules use none
(`Params`, `Opcodes`, `Eval`, `Ops.Arith`, `Ops.Splice`, `Ops.Stack` and the
root). In the source outside `Numbers`: 63 Mathlib-side tactic nodes in 13
modules (`split_ifs` 51) and 16 Mathlib lemma names. So D44's confinement holds
at the import level at no cost; at the level of use it costs those edits and a
re-check of the 167 declarations, whose breaks stay unmeasured until Mathlib is
out of their scope (`Numbers` on core, or Lean's module system). What a build
verifies today is a narrowing: `Numbers.lean` importing 74 named Mathlib-side
modules instead of `Mathlib` (the 73 the library's terms and syntax use, and
`Mathlib.Tactic.Positivity.Basic`, whose extension no term names), under which
every target builds, the axiom check reads the same 545 theorems and the terms
name the same constants, while `import BsvScript` loads 980 Mathlib-side modules
instead of 8,908 `[X local]` `[M]`
(`docs/records/20260929-020414-narrowing-35-s2.md`, the hunk its companion). The Lean side
landed the narrowing at `a210516`, after which `import BsvScript` loaded 2,501
modules, 980 of them Mathlib-side, with the Gadget module beside it `[M]`
(`docs/records/20260929-051445-patches-35-s1.md`). #50's eight `BsvScript.Impl`
modules and `Gadget.HashLock` import only `BsvScript` modules, so it now loads
2,510, the same 980 Mathlib-side `[D on M]` (the **Correction.** on #35,
5886366916); the Mathlib use of `Eval` and the `Impl` modules is unmeasured.

**12.4 The gadget-level API: "this script computes this spec"**. An
emitted verifier is a long locking script built from gadgets (a field
multiplication, a hash, a Merkle step), and layer 4 proves that the script
computes the verifier's statement. The spec's execution is
`Machine.loop exec env s st : Outcome × State` (§2); the API states one
gadget's effect on the machine state and composes gadgets by concatenation.
Its pieces, a module `BsvScript.Gadget` over `Machine` alone:

1. `Gadget.run exec env g tail st`: the loop over the fragment `g` without the
   end-of-script test (the `[]` case of `loop` refuses an open conditional,
   `1828–1830`), `tail` being what follows `g` in the whole script. Only
   `OP_CODESEPARATOR` reads the tail: it keeps the rest of the whole script as
   `codeSep` (`1445–1448`; `loop_codeseparator`,
   `lean/BsvScript/Properties/Eras.lean`). The result tells apart the
   fragment's end (`next st'`), the end of the whole script at a top-level
   `OP_RETURN` after Genesis (`stop st'`, `858–861`; `opreturn_suffix`,
   `lean/BsvScript/Properties/Basic.lean`), an error, an input on which the
   reference is undefined (§1.2, Q7) and an unimplemented opcode.
2. `Gadget.loop_eq_run`: `loop exec env s st` is `run exec env s [] st`
   followed by the end test, so the API runs the semantics' own loop and never
   a second machine.
3. `Gadget.Framed g`: every push of `g` ends inside `g` (the instruction walk
   of `getOpTail` ends at `g`'s last byte); then `Gadget.run_append`:
   `run exec env (g ++ h) t st` is `run exec env g (h ++ t) st` followed, on
   `next st'`, by `run exec env h t st'`.
4. `Gadget.Triple exec env P g Q`: from every state satisfying `P`, whatever
   follows, `g` runs to its end in a state satisfying `Q`; `Triple.seq` (from
   `run_append`) and `Triple.conseq` compose them. For a gadget that computes
   `f` on the top `n` elements, `P` fixes those elements as the encodings of
   the inputs (`Numbers.encode`, §1.2), an executing branch
   (`st.cond.isActive`, no non-top-level `OP_RETURN`) and the budgets (the op
   count, the memory counter and, before Genesis, the depth, §5.1; the
   invariants of `Properties/Resources.lean` and `Properties/Hooks.lean`); `Q`
   fixes the top as the encoding of `f` of the inputs and keeps the rest of the
   stack, the alt stack and the conditional state.
5. The executable side: on a concrete fragment and concrete states `run`
   evaluates by `#eval`. In the kernel `run` is well-founded (`Gadget.run`,
   `termination_by g => g.length`) and has no fuel copy: `decide` or `rfl` reach
   it only for a whole script, through `loop_eq_run` (an empty tail, read by
   `GOut.toLoop`) and the structural copy of the loop (`loop_eq_fuel`,
   `lean/BsvScript/Properties/KernelSample.lean`); a fragment's `run` needs its
   own fuel copy (lean #32's second lens, A-12). A gadget's claim is tested on
   vectors before it is proved.

The environment `env` (`Machine.Env`: the flag word gated by the version, the
limits, the era, the checker's context) is a parameter throughout: a triple
states the era and the flags it assumes (§5.2, §5.3), and a gadget is proved
once per branch it runs under. Items 1 to 4 are `lean/BsvScript/Gadget.lean` on
`main`: written as the companion of `docs/records/20260929-014620-gadget-api-35-s2.md`,
landed at `d3a73e0` (the file falls under `lean/BsvScript` in
`docs/OWNERS`; from the paste of 2026-09-29 05:09 UTC).
`loop_eq_run`, `getOpTail_append`, `run_append`, `Triple.seq` and `Triple.conseq`
prove with no `sorry`, within `[propext, Classical.choice, Quot.sound]`, on the axiom
list the tripwire checks.

*The worked example* (`docs/records/20260929-054850-gadget-hashlock-35-s2.md`, the
module `BsvScript.Gadget.HashLock` its companion, landed as
`lean/BsvScript/Gadget/HashLock.lean` at `d4b0e1d`, its nine theorems on the axiom
list): BIP 199's hash puzzle with `OP_SHA256` and a 32-byte digest,
`OP_SHA256 <h> OP_EQUALVERIFY` (bitcoin/bips `bip-0199.mediawiki`, blob `74bf6d6b`,
lines 26–27 and 34). `hashLock_triple` states that from every state whose top is a
preimage `x` of `h`, the gadget runs to its end, whatever follows it, and leaves
the stack below `x`, the alt stack and the conditional state kept, two opcodes
charged and `x`'s memory given back. It is composed by `Triple.seq` from the three
instructions' triples (`OP_SHA256`, the digest's minimal push, `OP_EQUALVERIFY`),
each proved from `Gadget.run` over `Eval.opExec`, with the digest's equality
carried across by `Triple.conseq`: no `sorry`, within `[propext, Classical.choice,
Quot.sound]` `[X local]`. Its hypotheses are an executing branch, the op count and
memory budgets, and a post-Genesis UTXO.

**12.5 The evaluator on a foreign fixture.** `eval/bsvs corpus <path> --out
<path>` judges a corpus file (§6's entry: `tx`, `prevouts`, `params`) wherever
it lies: a sibling's emitted verifier is a prevout's locking script and its
proof the spending input's unlocking script. It runs from a checkout of this
repository at the tag; the wrapper builds the binary on its first use, only
under a held slot of the plan's Lean lock and with the shared package cache
linked (`eval/bsvs`'s header). Measured `[M]`
(`docs/records/20260929-013700-foreign-fixture-35-s2.md`, at `b3406bf`): the
corpus's largest locking script a spend executes (`eras-00012`, a prevout's,
10,005 bytes; the largest of any kind is `tx-00040`'s output script, 10,000,036
bytes `[X]`) judged by a path outside the tree in 1.50 s at a maximum resident set
of 62,832,640 bytes, and its largest transaction (`tx-00040`, 10,000,100 bytes) in
1.91 s at 2,147,041,280
bytes, each verdict and code as the corpus records them `[X local]`; for a large
emitted verifier, the ladder after #45 decides a 2,199,971-byte push-shaped
script in 0.45 s at 0.447 GB (`docs/records/20260926-211841-ladder45-after-s1.md`).

**12.6 The tag scheme.** 35a's interface is tagged `v0.<minor>.<patch>` on
`main` (semver's `0.y.z`: the interface can still move), each tag at a commit
whose tripwire is GREEN on its record and at which a consumer build is
recorded; a tag is never moved, and its annotation names both records. 35b
(#44, S4 · Review and release) tags `v1.0.0`, the pin both siblings record in
their `docs/PROVENANCE.md`. Within `0.y.z`, a patch moves no definition's
signature and no theorem's statement (a docstring, a proof, a compiled copy);
a minor may add definitions and theorems and may correct a definition against
the reference (12.2 (4): a consumer re-checks its proofs that unfold it); from
`v1.0.0` on, semver in full. The 35a tags: **`v0.1.0` at `b3406bf`**, the commit
the consumer of 12.1 built, and **`v0.2.0` at `21ae89e`**, a minor: it adds the gadget API
(`BsvScript.Gadget`, `BsvScript.Gadget.HashLock`), confines Mathlib to `Numbers.lean`'s
named imports, and carries #32's corrections of definitions against the reference
(among them `SigHashType.isDefined`'s base, the lax DER parser's sequence length (D-1) and
`ReadCompactSize`'s canonical encodings (B-1)), so a consumer re-checks its proofs that
unfold them (12.2 (4)). Its tripwire: `docs/records/20260929-214052-make-check-box.txt`, its
`commit:` line `21ae89e`; its consumer: `docs/records/20260929-214540-consumer-v020-35-s2.md`. `v0.1.0`'s: GREEN on the box at `b3406bf` itself
(`docs/records/20260929-032755-make-check-box.txt`, its `commit:` line `b3406bf`).
A first box record launched for it, `docs/records/20260929-015344-make-check-box.txt`,
GREEN, ran at `994d280` (`b3406bf` and `tools/check_box.sh` alone) and does not
count: under the rule of the **Finding.** 5882258722 on #35, a record counts
only if its `commit:` line names the caller's own commit.
