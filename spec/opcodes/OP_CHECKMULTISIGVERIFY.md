# `OP_CHECKMULTISIGVERIFY` (`0xaf`)

**Family** crypto (signatures) · **module** `BsvScript.Ops.Crypto` · **landed at** #11 · **the switch** `1450–1682` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)
- the version gate: LOW_S (`285`), NULLFAIL (`1493`, `1643`), NULLDUMMY (`1666`) bind only when `EnforceNonMalleability` (`40–44`) holds, i.e. pre-Chronicle or version ≤ 1; the strict DER shape and the hash-type rules are ungated (`275–280`, `291–307`)
- post-Chronicle a check executing in the unlocking script signs the unlock from the last separator plus the locking script (`1474–1481`)

## Semantics (the Lean docstrings that name it)

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

### `checkMultiSigOpI_abs` (theorem, `lean/BsvScript/Impl/Crypto.lean:191`)

**`checkMultiSigOpI_abs`.** *What it says:* the implementation's `OP_CHECKMULTISIG`/
`OP_CHECKMULTISIGVERIFY` computes what `Ops.Crypto.checkMultiSigOp` computes on the state it stands for.
*What it assumes:* nothing. *Why it matters:* the family on the implementation (#50).

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

### `opSigOps` (def, `lean/BsvScript/SigOps.lean:53`)

What an instruction adds to the count (`script.cpp:71–123`): one for `OP_CHECKSIG` and
`OP_CHECKSIGVERIFY`, `multisigSigOps` for `OP_CHECKMULTISIG` and `OP_CHECKMULTISIGVERIFY`, nothing
otherwise; `none` is `sigOpCountError`.

`[SRC]` `script.cpp:71–123`

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

### `sigOpCountPreGenesis_checkmultisigverify` (theorem, `lean/BsvScript/TxRules.lean:169`)

… as does `OP_CHECKMULTISIGVERIFY` (`script.cpp:119–122`) …

`[SRC]` `script.cpp:119–122`

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

