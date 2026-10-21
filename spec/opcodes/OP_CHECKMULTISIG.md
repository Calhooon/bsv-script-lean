# `OP_CHECKMULTISIG` (`0xae`)

**Family** crypto (signatures) · **module** `BsvScript.Ops.Crypto` · **landed at** #11 · **the switch** `1450–1682` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)
- the version gate: LOW_S (`285`), NULLFAIL (`1493`, `1643`), NULLDUMMY (`1666`) bind only when `EnforceNonMalleability` (`40–44`) holds, i.e. pre-Chronicle or version ≤ 1; the strict DER shape and the hash-type rules are ungated (`275–280`, `291–307`)
- post-Chronicle a check executing in the unlocking script signs the unlock from the last separator plus the locking script (`1474–1481`)

## Semantics (the Lean docstrings that name it)

### `readCount` (def, `lean/BsvScript/Ops/Crypto.lean:161`)

The counts of `OP_CHECKMULTISIG` are read at width 4 with the minimal rule
(`CScriptNum(…, requireMinimal, MAXIMUM_ELEMENT_SIZE).getint()`, `1523–1526`,
`1550–1553`; `getint` saturates at `INT_MAX`, unreachable at width 4).

`[SRC]` `interpreter.cpp:1523–1526`, `interpreter.cpp:1550–1553`

### `checkMultiSigOp` (def, `lean/BsvScript/Ops/Crypto.lean:188`)

`OP_CHECKMULTISIG`/`OP_CHECKMULTISIGVERIFY` (`1510–1682`). The layout from
the top: the key count (`1517–1526`, negative → `PUBKEY_COUNT`, above
`MaxPubKeysPerMultiSig` → `PUBKEY_COUNT`, charged to the op count → `OP_COUNT`,
`1527–1536`), the keys, the signature count (`1544–1560`, negative or above the
key count → `SIG_COUNT`), the signatures, the dummy (`1661–1672`). The
scriptCode (`1567–1577`) is cleaned of every signature when FORKID is not in
play (`1579–1585`); the loop (`1587–1634`); the arguments popped (`1636–1653`)
with `SIG_NULLFAIL` on a non-empty signature after a failure under NULLFAIL
and the version gate (`1641–1647`); the dummy must be empty under NULLDUMMY
and the gate (`1664–1670`, else `SIG_NULLDUMMY`); the boolean pushed
(`1674`); `VERIFY` pops a true or fails (`1676–1681`).

`[SRC]` `interpreter.cpp:1510–1682`, `interpreter.cpp:1517–1526`, `interpreter.cpp:1527–1536`, `interpreter.cpp:1544–1560`, `interpreter.cpp:1661–1672`, `interpreter.cpp:1567–1577`, `interpreter.cpp:1579–1585`, `interpreter.cpp:1587–1634`, `interpreter.cpp:1636–1653`, `interpreter.cpp:1641–1647`, `interpreter.cpp:1664–1670`, `interpreter.cpp:1674`, `interpreter.cpp:1676–1681`

### `pushBit_abs` (theorem, `lean/BsvScript/Impl/Crypto.lean:47`)

**`pushBit_abs`.** *What it says:* the signature checks' result push, `[1]` or `[]`, is the push of the packed
`vchTrue` or the empty element. *What it assumes:* nothing. *Why it matters:* `OP_CHECKSIG`'s and
`OP_CHECKMULTISIG`'s results (#143).

### `multisigLoop_abs` (theorem, `lean/BsvScript/Impl/Crypto.lean:105`)

**`multisigLoop_abs`.** *What it says:* the implementation's signature loop answers what
`Ops.Crypto.multisigLoop` answers on the state it stands for. *What it assumes:* nothing. *Why it matters:*
`OP_CHECKMULTISIG` on the implementation (#50).

### `forIn_bind_abs` (theorem, `lean/BsvScript/Impl/Crypto.lean:128`)

**`forIn_bind_abs`.** *What it says:* a `for` loop over a list whose body over the implementation state
stands for the spec's body, followed by continuations that agree, computes what the spec's loop and
continuation compute. *What it assumes:* the two bodies and the two continuations agree on every state.
*Why it matters:* `OP_CHECKMULTISIG`'s pops of its arguments (`1636–1653`) (#50).

`[SRC]` `interpreter.cpp:1636–1653`

### `checkMultiSigOpI_abs` (theorem, `lean/BsvScript/Impl/Crypto.lean:191`)

**`checkMultiSigOpI_abs`.** *What it says:* the implementation's `OP_CHECKMULTISIG`/
`OP_CHECKMULTISIGVERIFY` computes what `Ops.Crypto.checkMultiSigOp` computes on the state it stands for.
*What it assumes:* nothing. *Why it matters:* the family on the implementation (#50).

### `readCount_eq` (theorem, `lean/BsvScript/Impl/Elem.lean:280`)

**`readCount_eq`.** *What it says:* the element's reader answers what the spec's reader answers on its list.
*What it assumes:* nothing. *Why it matters:* `OP_CHECKMULTISIG`'s counts (#143).

### `isEmpty_abs` (theorem, `lean/BsvScript/Impl/State.lean:469`)

**`isEmpty_abs`.** *What it says:* the spec's stack is empty exactly when the array is. *What it
assumes:* nothing. *Why it matters:* `OP_CHECKMULTISIG`'s dummy test and the verdict (#50).

### `abs_opCount` (theorem, `lean/BsvScript/Impl/State.lean:485`)

**`abs_opCount`.** *What it says:* the spec state's op count is the implementation's. *What it assumes:*
nothing. *Why it matters:* the op-count tests of the loop and of `OP_CHECKMULTISIG` (#50).

### `abs_withOpCount` (theorem, `lean/BsvScript/Impl/State.lean:489`)

**`abs_withOpCount`.** *What it says:* the spec state with its op count replaced is the implementation
state with its op count replaced, read as the spec's. *What it assumes:* nothing. *Why it matters:* the op
count's charges in the loop (`466–467`) and in `OP_CHECKMULTISIG` (`1527–1536`) (#50).

`[SRC]` `interpreter.cpp:466–467`, `interpreter.cpp:1527–1536`

### `checksig_empty_sig` (theorem, `lean/BsvScript/Properties/Basic.lean:137`)

**`checksig_empty_sig`.** *What it says:* the transaction checker with an
empty signature is false without touching the curve (`2145–2147`). *What it
assumes:* nothing. *Why it matters:* an empty signature is the canonical "this
check fails" element of multisig scripts; the equation, the digest and the key
decoding are never reached for it, so no property of the curve is involved in
that verdict (and NULLFAIL exempts it: the refusal `1493–1496` is reached only
through the `!vchSig.empty()` conjunct of `1491`, and in `OP_CHECKMULTISIG` the
refusal `1643–1646` only through that of `1641`).

`[SRC]` `interpreter.cpp:2145–2147`, `interpreter.cpp:1493–1496`, `interpreter.cpp:1491`, `interpreter.cpp:1643–1646`, `interpreter.cpp:1641`

### `checkMultiSigOp_ok` (theorem, `lean/BsvScript/Properties/Hooks.lean:752`)

**H1 (the multisig success case).** *What it says:* an `OP_CHECKMULTISIG`/`OP_CHECKMULTISIGVERIFY` that
succeeds read a key count `n` (`1517–1526`), charged it to the op count, which stays within
`MaxOpsPerScript` (`1534–1536`), and left the op count exactly `n` higher; every pop and push after the
charge keeps the memory invariant. *What it assumes:* the opcode succeeded. *Why it matters:* the key
count is the only charge a family makes to the op count, and the charge is refused before it can pass
the limit, so the op-count invariant holds across the crypto family (`HookOpCount`), and the multisig's
pops of its arguments (`1636–1653`), the dummy and the result keep the counter exact (`HookMem`); and
`codeSep` is as it was (#149).

`[SRC]` `interpreter.cpp:1517–1526`, `interpreter.cpp:1534–1536`, `interpreter.cpp:1636–1653`

### `checkMultiSigOp_nulldummy` (theorem, `lean/BsvScript/Properties/Hooks.lean:1088`)

**H7 (NULLDUMMY under the gate, `OP_CHECKMULTISIG`).** *What it says:* an `OP_CHECKMULTISIG`/
`OP_CHECKMULTISIGVERIFY` that succeeds under `SCRIPT_VERIFY_NULLDUMMY` and the version gate found the
element under its arguments empty: with `n` keys and `m` signatures read, the element `n + 2 + m` below
the top. *What it assumes:* the opcode succeeded, the flag, the gate. *Why it matters:* the extra element
the historical off-by-one pops (`1655–1672`: the comment on the bug, then the pop) is the malleability
NULLDUMMY closes where the flag is set. The flag is policy (the standard word only, `policy.h:182–189`;
never in the block word, `blockScriptFlags_policy_off`), so on the mempool path, where the gate is on, a
third party cannot vary it without the spend failing, while a block accepts a varied dummy (`1664` tests
the flag first).

`[SRC]` `interpreter.cpp:1655–1672`, `policy.h:182–189`, `interpreter.cpp:1664`

### `checkMultiSigOp_nullfail` (theorem, `lean/BsvScript/Properties/Hooks.lean:1204`)

**H8 (NULLFAIL under the gate, `OP_CHECKMULTISIG`).** *What it says:* an `OP_CHECKMULTISIG` that
succeeds with a false result under `SCRIPT_VERIFY_NULLFAIL` and the version gate found every signature
empty: with `n` keys and `m` signatures read, the elements `n + 2` to `n + 1 + m` below the top.
*What it assumes:* the opcode `OP_CHECKMULTISIG` (its `VERIFY` form fails on a false result), its
success, the false result on top, the flag, the gate. *Why it matters:* the argument pops refuse a
non-empty signature after a failed check (`1641–1647`), so a failing multisig cannot carry a non-empty
signature where the gate is on, the malleability NULLFAIL closes (with H6 for `OP_CHECKSIG`).

`[SRC]` `interpreter.cpp:1641–1647`

### `HookOpCount` (def, `lean/BsvScript/Properties/Resources.lean:65`)

A hook keeps the op count within the limit: from a state within it, every `.ok` answer is within
it. The crypto family's `OP_CHECKMULTISIG` charges the key count and refuses over the limit
(`1534–1536`, R5b below); no other opcode touches the count.

`[SRC]` `interpreter.cpp:1534–1536`

### `checkMultiSigOp_pubkeyCount` (theorem, `lean/BsvScript/Properties/Resources.lean:595`)

**R5 (the key count).** *What it says:* `OP_CHECKMULTISIG` refuses a key count above
`MaxPubKeysPerMultiSig` as `SCRIPT_ERR_PUBKEY_COUNT` (`1530–1532`), after the count's read (`1519–1526`) and
its sign test (`1527–1528`), before any key or signature is read.
*What it assumes:* the count reads (`readCount`, width 4 under the minimal rule). *Why it matters:*
pre-Genesis the limit is 20 (`consensus.h:50`); post-Genesis it is the consensus constant `UINT32_MAX` on
the block path (`consensus.h:55`, `configscriptpolicy.cpp:131–134`) and the node's policy setting on the
mempool path (`configscriptpolicy.cpp:136`; default `UINT32_MAX`, `policy.h:150`; `docs/PARAMETERS.md`
§1).

`[SRC]` `interpreter.cpp:1530–1532`, `interpreter.cpp:1519–1526`, `interpreter.cpp:1527–1528`, `consensus.h:50`, `consensus.h:55`, `configscriptpolicy.cpp:131–134`, `configscriptpolicy.cpp:136`, `policy.h:150`

### `scriptCode_unlock_site` (theorem, `lean/BsvScript/Properties/Sighash.lean:41`)

**`scriptCode_unlock_site`.** *The rule:* the scriptCode a signature check builds is `codeSep` (the reference's
`{pbegincodehash, pend}`; what writes `codeSep` is `codeSep_sites`, and the whole run is `scriptCode_last`),
with the locking script appended when the check executes inside the unlocking script under `SCRIPT_CHRONICLE`.
*What it says:* in the environments `verifyScript` builds from the word `params.flags` (after STRICTENC from
FORKID, `Flags.forkAdjust`), the unlocking phase's, whose `checksigData` is the locking script, and the locking
and P2SH-redeem phases', whose `checksigData` is none (`Machine.lean`'s `phase2` builds that one twice),
`scriptCodeOf` is `codeSep ++ scriptPubKey` in the unlocking phase with the CHRONICLE bit set, `codeSep` in the
unlocking phase without it, and `codeSep` in the locking phase. *What it assumes:* nothing beyond the word: every
parameter record, context, locking script and state. [SRC] `1471–1481` (`CScript scriptCode {pbegincodehash,
pend}`; `if(checksigData && IsChronicle(flags)) scriptCode += *checksigData`) and of `OP_CHECKMULTISIG`
(`1567–1577`); `2338–2342` (the unlocking script evaluated with `&scriptPubKey` as `checksigData`); `2358–2362`
and `2402–2406` (the locking script and the P2SH redeem script evaluated with `nullptr` as `checksigData`);
`1445–1448` (`pbegincodehash`). *Measured contradiction:* go-sdk v1.7.2 hashes the source output's locking
script as the scriptCode on its default path (`transaction/signaturehash.go:277-299`), class
`sighash.scriptcode.in-unlock.lock-only`; at @bsv/sdk 3.0.0 the caller supplies the subscript
(`primitives/TransactionSignature.ts:262,394-396`), the class ruled `caller-scriptcode-required`
(`docs/records/20261016-203024-s3-145d-signer-column-s3.md`); bsv-rs 0.5.0 selects the source locking script
(`src/script/template.rs:85-99`), the same lock-only class (`docs/records/20261016-234915-s3-147-signer-column-s3.md`).

`[SRC]` `interpreter.cpp:1471–1481`, `interpreter.cpp:1567–1577`, `interpreter.cpp:2338–2342`, `interpreter.cpp:2358–2362`, `interpreter.cpp:2402–2406`, `interpreter.cpp:1445–1448`, `transaction/signaturehash.go:277-299`, `src/script/template.rs:85-99`

### `scriptCode_last` (theorem, `lean/BsvScript/Properties/Sighash.lean:377`)

**`scriptCode_last`.** *The rule:* the scriptCode a signature check digests is the script being run from the
byte after its last executed `OP_CODESEPARATOR` before the check (from its start when none executed), with the
locking script appended when the check runs inside the unlocking script under `SCRIPT_CHRONICLE`. *What it says:*
`codeSep_last` composed with `scriptCode_unlock_site` at the state the check reads: in the environments
`verifyScript` builds from the word, for a run of the evaluator's loop over `script` from `evalScript`'s start state
(any stack and memory counter) that reaches the instruction `op` (an `OP_CHECKSIG`, `OP_CHECKSIGVERIFY`,
`OP_CHECKMULTISIG`, `OP_CHECKMULTISIGVERIFY` or any other) through the trace `tr`, the scriptCode of the state
handed to `op`'s step (the reached state with the op count's charge, `466–467`) is `script.drop (afterLastSep tr)
++ scriptPubKey` in the unlocking phase under CHRONICLE, `script.drop (afterLastSep tr)` in it without the bit, and
`script.drop (afterLastSep tr)` in the locking and P2SH-redeem phases (`checksigData` none). The bytes are those
before `CleanupScriptCode` (`1484`; the FORKID form is `scriptCode_unlock_site_forkid`). *What it assumes:* the
run from the start state. [SRC] `405–407`, `450`, `1445–1448`, `1471–1481` and `1567–1577` (the scriptCode and the
CHRONICLE append), `2338–2342` (the unlocking script with `&scriptPubKey`), `2358–2362` and `2402–2406` (`nullptr`).
*Measured contradiction:* `sighash.scriptcode.in-unlock.lock-only` (go-sdk v1.7.2, bsv-rs 0.5.0; at @bsv/sdk 3.0.0
`caller-scriptcode-required`), which is the which-script half of this statement, not the separator half
(`docs/records/20261016-203024-s3-145d-signer-column-s3.md`, `docs/records/20261016-234915-s3-147-signer-column-s3.md`).

`[SRC]` `interpreter.cpp:466–467`, `interpreter.cpp:1484`, `interpreter.cpp:405–407`, `interpreter.cpp:450`, `interpreter.cpp:1445–1448`, `interpreter.cpp:1471–1481`, `interpreter.cpp:1567–1577`, `interpreter.cpp:2338–2342`, `interpreter.cpp:2358–2362`, `interpreter.cpp:2402–2406`

### `scriptCode_run` (theorem, `lean/BsvScript/Properties/Sighash.lean:426`)

**`scriptCode_run`.** *The rule:* a signature check that executes while the unlocking script runs under
`SCRIPT_CHRONICLE` digests the unlocking script from its scriptCode's start, which lies at or before the check
itself, followed by the locking script; so its scriptCode is never the locking script alone. *What it says:* in
the unlocking phase `verifyScript` builds (`mkEnv … (some scriptPubKey)`, its loop started by `evalScript` with
`codeSep` the unlocking script, `codeSep_sites`), at every configuration the evaluator's loop reaches, with the
instruction `op` next (an `OP_CHECKSIG`, `OP_CHECKSIGVERIFY`, `OP_CHECKMULTISIG` or any other), `codeSep` is a
suffix of the unlocking script that contains `op :: rest`; under the CHRONICLE bit `scriptCodeOf` is
`codeSep ++ scriptPubKey`, strictly longer than `scriptPubKey`, at the scriptCode before its cleanup (`1484`), so it differs from it. The state the check reads
differs from the reached one by the op count's charge only (`loop`, `466–467`), which leaves `codeSep` as it
was. *What it assumes:* the configuration reached from the unlocking phase's start state (`LoopReach`); the CHRONICLE bit for the third conjunct. [SRC] `407`, `1445–1448`, `1471–1481` and `1567–1577`
(the scriptCode and the CHRONICLE append), `2338–2342` (the unlocking script with `&scriptPubKey` as
`checksigData`). *Measured contradiction:* `sighash.scriptcode.in-unlock.lock-only`, a signer hashing
`scriptPubKey` alone where this scriptCode is longer (go-sdk v1.7.2 and bsv-rs 0.5.0; at @bsv/sdk 3.0.0 the
caller's obligation, `caller-scriptcode-required`; `docs/records/20261016-203024-s3-145d-signer-column-s3.md`,
`docs/records/20261016-234915-s3-147-signer-column-s3.md`). The bytes run from the scriptCode's start, which
the run fixes at the script's start or after an executed separator before `op` (`codeSep_sites`,
`execStep_codeSep`); which separator is the last, and the bytes from it, is `codeSep_last` and, at the check,
`scriptCode_last`.

`[SRC]` `interpreter.cpp:1484`, `interpreter.cpp:466–467`, `interpreter.cpp:407`, `interpreter.cpp:1445–1448`, `interpreter.cpp:1471–1481`, `interpreter.cpp:1567–1577`, `interpreter.cpp:2338–2342`

### `opSigOps` (def, `lean/BsvScript/SigOps.lean:53`)

What an instruction adds to the count (`script.cpp:71–123`): one for `OP_CHECKSIG` and
`OP_CHECKSIGVERIFY`, `multisigSigOps` for `OP_CHECKMULTISIG` and `OP_CHECKMULTISIGVERIFY`, nothing
otherwise; `none` is `sigOpCountError`.

`[SRC]` `script.cpp:71–123`

### `sigOpCount_multisig_max` (theorem, `lean/BsvScript/SigOps.lean:355`)

**T-SO6 (the multisig count after Genesis reaches 2,147,483,647).** *What it says:* after Genesis
the output script `04 ffffff7f OP_CHECKMULTISIG` (six bytes) counts 2,147,483,647. *What it assumes:*
nothing. *Why it matters:* the preceding four-byte push is the largest non-negative minimal script number
(`script.cpp:102–116`); three such outputs count 6,442,450,941, past `UINT32_MAX`, the largest cap
`-maxtxsigopscountspolicy` admits (`config.cpp:2391–2415`), so the mempool refuses them at every setting
(`TxPolicy.mempoolTxPolicy_multisig_witness`).

`[SRC]` `script.cpp:102–116`, `config.cpp:2391–2415`

### `sigOpCount_opN_paths` (theorem, `lean/BsvScript/SigOps.lean:376`)

**T-SO8 (the three multisig paths).** *What it says:* `OP_2 OP_CHECKMULTISIG` counts 20 before Genesis
without `fAccurate`, 2 with it, and 2 after Genesis. *What it assumes:* nothing. *Why it matters:* the
consensus gate's pre-Genesis count charges every multisig the key limit (`script.cpp:119–122`); a P2SH
redeem script (`fAccurate`, `155–161`) and every count after Genesis read the key count from the preceding
`OP_1`–`OP_16` (`74–77`).

`[SRC]` `script.cpp:119–122`, `script.cpp:155–161`, `script.cpp:74–77`

### `p2shRedeemSigOps_examples` (theorem, `lean/BsvScript/SigOps.lean:387`)

**T-SO9 (the P2SH redeem count).** *What it says:* an unlocking script whose last push is the redeem
script `OP_2 OP_CHECKMULTISIG` gives the P2SH part 2; an unlocking script that is not push-only gives it 0.
*What it assumes:* nothing. *Why it matters:* the P2SH part of the mempool's count reads the redeem script
accurately (`script.cpp:159–165`) and gives up without an error on a non-push unlocking script
(`137–148`), which the script check refuses on its own (`SCRIPT_ERR_SIG_PUSHONLY`).

`[SRC]` `script.cpp:159–165`, `script.cpp:137–148`

### `multisigWitnessTx` (def, `lean/BsvScript/TxPolicy.lean:415`)

The witness of a post-Genesis count past `UINT32_MAX` (`SigOps.sigOpCount_multisig_max`): one input
(a synthetic outpoint, an empty unlocking script) and three outputs of 1 satoshi each (not dust,
`Standard.isDust`) paying `04 ffffff7f OP_CHECKMULTISIG`, 18 bytes of locking script in all.

### `sigOpCountPreGenesis` (def, `lean/BsvScript/TxRules.lean:47`)

`CScript::GetSigOpCount(fAccurate, era)` (`script.cpp:30–128`) on the
pre-Genesis path (`fAccurate = false`, the era pre-Genesis, as the vector runner
calls it): the instructions are walked until one whose opcode is `OP_INVALIDOPCODE`
(`script.cpp:44–45`), a push that fails to decode (`instruction_iterator.h:31–72`) or a
literal `0xff`, which decodes as a valid instruction (`:26–27`);
`OP_CHECKSIG`/`OP_CHECKSIGVERIFY` count one (`script.cpp:71–74`); `OP_CHECKMULTISIG`/
`OP_CHECKMULTISIGVERIFY` count `MAX_PUBKEYS_PER_MULTISIG_BEFORE_GENESIS`
(`script.cpp:119–122`; the accurate count and the post-Genesis rules are the other
branches, `script.cpp:78–118`, `SigOps.sigOpCount`, equal to this walk on the pre-Genesis
path by T-TX11).

`[SRC]` `script.cpp:30–128`, `script.cpp:44–45`, `instruction_iterator.h:31–72`, `instruction_iterator.h:26–27`, `script.cpp:71–74`, `script.cpp:119–122`, `script.cpp:78–118`

### `sigOpCountPreGenesis_checkmultisig` (theorem, `lean/BsvScript/TxRules.lean:160`)

… `OP_CHECKMULTISIG` counts `MAX_PUBKEYS_PER_MULTISIG_BEFORE_GENESIS` = 20 (`script.cpp:119–122`, `consensus.h:50`;
the inaccurate count, whatever the key count pushed) …

`[SRC]` `script.cpp:119–122`, `consensus.h:50`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `crypto.checkmultisig` | 16 | `interpreter.cpp:1510–1682` |
| `sighash.scriptcode.findanddelete` | 2 | `interpreter.cpp:255–263`, `1484` |
| `sighash.type` | 18 | `sighashtype.h:14–96`; `interpreter.cpp:247–253` (`GetHashType`) |
| `sighash.bip143` | 16 | `interpreter.cpp:1960–1982`, `2034–2084` |
| `sighash.original` | 7 | `interpreter.cpp:1841–1958`, `2086–2110`; `transaction.h:196–199` |
| `sighash.dispatch` | 5 | `interpreter.cpp:2112–2124`; `302–306` |
| `sighash.scriptcode.findanddelete` | 2 | `interpreter.cpp:255–263`; `script.h:71`, `102–124`, `199–222`; the reference's unit cases `src/test/script_tests.cpp:3819–3934` (16, kernel-checked in `Sighash.lean`) |
| `sighash.original.truncated-push` | 6 | `interpreter.cpp:1862–1892`; `script.h:163–196` (`GetOp2`) |
| `flags.v1.minimaldata.push`, `flags.v1.minimaldata.number` | 36 | `interpreter.cpp:433–434`, `473–479`, `331–358`; `script_num.cpp:53–89`, `int_serialization.h:97–129`; the reads `546`, `577`, `622`, `624`, `655`, `680`, `709`, `717`, `745`, `753`, `1015`, `1129`, `1163`, `1235`, `1300–1301`, `1386–1390`, `1524`, `1551`, `1717`, `1747`; `policy.h:190` |
| `flags.v1.lows` | 16 | `interpreter.cpp:275–287`, `1459`, `1605`, `1491–1497`; `pubkey.cpp:146–173`, `207–213`, `353–363`; `verify_script_flags.cpp:65–67`; `secp256k1.c:443–460` |
| `eras.utxo.pre-genesis`, `eras.utxo.post-genesis`, `eras.utxo.post-chronicle` | 42 | `interpreter.cpp:411–427`, `2269–2280`; `configscriptpolicy.cpp:65–154`; the sites named |

