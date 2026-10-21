# `OP_CHECKSIGVERIFY` (`0xad`)

**Family** crypto (signatures) · **module** `BsvScript.Ops.Crypto` · **landed at** #11 · **the switch** `1450–1682` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)
- the version gate: LOW_S (`285`), NULLFAIL (`1493`, `1643`), NULLDUMMY (`1666`) bind only when `EnforceNonMalleability` (`40–44`) holds, i.e. pre-Chronicle or version ≤ 1; the strict DER shape and the hash-type rules are ungated (`275–280`, `291–307`)
- post-Chronicle a check executing in the unlocking script signs the unlock from the last separator plus the locking script (`1474–1481`)

## Semantics (the Lean docstrings that name it)

### `checkSigOp` (def, `lean/BsvScript/Ops/Crypto.lean:133`)

`OP_CHECKSIG`/`OP_CHECKSIGVERIFY` (`1450–1508`): the signature is the
second element, the key the top (`1456–1457`); both encodings checked
(`1459–1469`); the scriptCode (`1471–1481`) cleaned of the signature when FORKID
is not in play (`1484`, `CleanupScriptCode` `255–263`); the check (`1486–1487`);
a failed check with a non-empty signature under NULLFAIL and the version gate is
`SCRIPT_ERR_SIG_NULLFAIL` (`1491–1497`); the two popped, the boolean pushed
(`1499–1501`); `VERIFY` pops a true or fails (`1502–1507`).

`[SRC]` `interpreter.cpp:1450–1508`, `interpreter.cpp:1456–1457`, `interpreter.cpp:1459–1469`, `interpreter.cpp:1471–1481`, `interpreter.cpp:1484`, `interpreter.cpp:255–263`, `interpreter.cpp:1486–1487`, `interpreter.cpp:1491–1497`, `interpreter.cpp:1499–1501`, `interpreter.cpp:1502–1507`

### `checkSigOpI_abs` (theorem, `lean/BsvScript/Impl/Crypto.lean:79`)

**`checkSigOpI_abs`.** *What it says:* the implementation's `OP_CHECKSIG`/`OP_CHECKSIGVERIFY` computes
what `Ops.Crypto.checkSigOp` computes on the state it stands for. *What it assumes:* nothing. *Why it
matters:* the family on the implementation (#50).

### `checkSigOp_frame` (theorem, `lean/BsvScript/Properties/Hooks.lean:691`)

`OP_CHECKSIG`/`OP_CHECKSIGVERIFY` are frames (`1450–1508`).

`[SRC]` `interpreter.cpp:1450–1508`

### `checkSigOp_nullfail` (theorem, `lean/BsvScript/Properties/Hooks.lean:1037`)

**H6 (NULLFAIL under the gate, `OP_CHECKSIG`).** *What it says:* when both encodings pass and the
signature check fails on a non-empty signature, `OP_CHECKSIG`/`OP_CHECKSIGVERIFY` refuses
`SCRIPT_ERR_SIG_NULLFAIL` under `SCRIPT_VERIFY_NULLFAIL` and the version gate. *What it assumes:* two
elements, both encodings accepted, the failed check, the flag, the non-empty signature, the gate.
*Why it matters:* a failed signature must be empty for the script to go on (`1491–1497`), so a failing
`OP_CHECKSIG` cannot be turned into a `false` by a non-empty signature where the gate is on (before
Chronicle for every version, after it for a version of at most 1, `34–44`), the malleability NULLFAIL
closes.

`[SRC]` `interpreter.cpp:1491–1497`, `interpreter.cpp:34–44`

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

### `sigOpCountPreGenesis_checksigverify` (theorem, `lean/BsvScript/TxRules.lean:153`)

… as does `OP_CHECKSIGVERIFY` (`script.cpp:71–74`) …

`[SRC]` `script.cpp:71–74`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `crypto.checksig`, `crypto.checksig.encoding` | 32 | `interpreter.cpp:1450–1508`, `177–329`, `2133–2164`; `pubkey.cpp:32–214`; libsecp256k1 `eckey_impl.h:17–35`, `ecdsa_impl.h:195–262` |
| `crypto.checksig.unlock` | 2 | `interpreter.cpp:1474–1481`, `2321–2334`; bsv-rs 0.3.24 `spend.rs:186/237` |
| `sighash.scriptcode.findanddelete` | 2 | `interpreter.cpp:255–263`, `1484` |
| `sighash.type` | 18 | `sighashtype.h:14–96`; `interpreter.cpp:247–253` (`GetHashType`) |
| `sighash.bip143` | 16 | `interpreter.cpp:1960–1982`, `2034–2084` |
| `sighash.original` | 7 | `interpreter.cpp:1841–1958`, `2086–2110`; `transaction.h:196–199` |
| `sighash.dispatch` | 5 | `interpreter.cpp:2112–2124`; `302–306` |
| `sighash.scriptcode.findanddelete` | 2 | `interpreter.cpp:255–263`; `script.h:71`, `102–124`, `199–222`; the reference's unit cases `src/test/script_tests.cpp:3819–3934` (16, kernel-checked in `Sighash.lean`) |
| `sighash.original.truncated-push` | 6 | `interpreter.cpp:1862–1892`; `script.h:163–196` (`GetOp2`) |

