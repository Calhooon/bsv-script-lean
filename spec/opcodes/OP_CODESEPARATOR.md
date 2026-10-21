# `OP_CODESEPARATOR` (`0xab`)

**Family** crypto (separator) · **module** `BsvScript.Machine` · **landed at** #11 · **the switch** `1445–1448` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `State` (structure, `lean/BsvScript/Machine.lean:134`)

The machine state of one `EvalScript` call plus what crosses phases
(`docs/DESIGN.md` §1.3). The main stack and the alt stack are top-first. The
memory counter is the root `LimitedStack`'s `combinedStackSize`
(`limitedstack.h:86`): every element costs its size plus 32 (`limitedstack.h:43`),
the alt stack shares the budget (`1993`), and the counter is not decremented for
elements left on the alt stack when a phase ends (`1993–2005`). `codeSep` is the
script from the last `OP_CODESEPARATOR` on (`pbegincodehash`, `407`, `1445–1448`).

`[SRC]` `limitedstack.h:86`, `limitedstack.h:43`, `interpreter.cpp:1993`, `interpreter.cpp:1993–2005`, `interpreter.cpp:407`, `interpreter.cpp:1445–1448`

### `run` (def, `lean/BsvScript/Gadget.lean:44`)

The loop (`Machine.loop`) over the fragment `g` followed by `tail`, without the end-of-script
test: each step is `loop`'s, the push data parsed inside `g`, the rest of the whole script
(`rest ++ tail`) handed to the step for `OP_CODESEPARATOR` (`1445–1448`).

`[SRC]` `interpreter.cpp:1445–1448`

### `execI` (def, `lean/BsvScript/Impl/Crypto.lean:208`)

`Ops.Crypto.exec` over the implementation state (`OP_CODESEPARATOR` is the loop's).

### `IState` (structure, `lean/BsvScript/Impl/State.lean:74`)

The implementation state (#50): `Machine.State`'s fields, the main stack as an array held bottom-first
(its top at `back`). The alt stack stays a list: only its top is ever touched (`interpreter.cpp:876–888`). Every
element is a packed `Elem` (#143). The scriptCode's start `codeSep` stays the script's own suffix (`Bytes`): it is
not a stack element, `OP_CODESEPARATOR` takes it by `drop` without a copy, and a packed copy at every separator
would cost the rest of the script each time.

`[SRC]` `interpreter.cpp:876–888`

### `scriptCodeOf` (def, `lean/BsvScript/Ops/Crypto.lean:111`)

The scriptCode of a signature check (`1472–1481`, `1568–1577`): the script
from the last `OP_CODESEPARATOR` on, and, when executing inside the unlocking
script under `SCRIPT_CHRONICLE`, the locking script appended.

`[SRC]` `interpreter.cpp:1472–1481`, `interpreter.cpp:1568–1577`

### `exec` (def, `lean/BsvScript/Ops/Crypto.lean:240`)

The family hook (`OP_CODESEPARATOR` is the loop's, `Machine.loop`).

### `flowOwns` (def, `lean/BsvScript/Properties/Coverage.lean:16`)

The opcodes handled before the family hook: those `execFlow` handles itself
(`483–871`), and `OP_CODESEPARATOR` (`1445–1448`), which `execStep` handles before
`execFlow` is reached (`execFlow` has no branch for it, so `execFlow_ne_unimpl`
excludes it by hypothesis).

`[SRC]` `interpreter.cpp:483–871`, `interpreter.cpp:1445–1448`

### `coverage` (theorem, `lean/BsvScript/Properties/Coverage.lean:39`)

**Coverage.** Every byte with a `case` label is in `flowOwns` (an opcode
`execFlow` handles itself, or `OP_CODESEPARATOR`, which `execStep` handles) or in
`hookOwns` (a family's).

### `crypto_exec_isSome` (theorem, `lean/BsvScript/Properties/Coverage.lean:80`)

The crypto family's hook answers exactly on the hashes from `OP_RIPEMD160` to
`OP_HASH256` and on the four signature checks, and on no other byte: not on
`OP_CODESEPARATOR` (`0xab`, between `OP_HASH256` and `OP_CHECKSIG`), which
`execStep` handles (`flowOwns`). One of the six lemmas `opExec_isSome_of_hookOwns`
assembles.

### `execFlow_ne_unimpl` (theorem, `lean/BsvScript/Properties/Coverage.lean:185`)

**`execFlow` never answers `unimpl`** on any opcode but `OP_CODESEPARATOR`
(the loop's own, `1445–1448`, never handed to `execFlow`).

`[SRC]` `interpreter.cpp:1445–1448`

### `execStep_ne_unimpl` (theorem, `lean/BsvScript/Properties/Coverage.lean:218`)

**`execStep` never answers `unimpl`** (`473–482`, `1445–1448`): the loop hands
`execFlow` a byte only off `OP_CODESEPARATOR`.

`[SRC]` `interpreter.cpp:473–482`, `interpreter.cpp:1445–1448`

### `execStep_codeseparator` (theorem, `lean/BsvScript/Properties/Eras.lean:809`)

**`OP_CODESEPARATOR` moves the scriptCode's start** (`1445–1448`: `pbegincodehash = pc`, the byte after the
separator; `execStep`, the loop's own case): executed, it changes nothing but `codeSep`, which becomes the bytes after
it (`k`, the parser's count after the opcode, is 0 for every non-push opcode).

`[SRC]` `interpreter.cpp:1445–1448`

### `loop_codeseparator` (theorem, `lean/BsvScript/Properties/Eras.lean:822`)

**At the loop** (`450–451`, `466–471`, `1445–1448`): an executed `OP_CODESEPARATOR` with the op count in bounds
continues on the rest of the script with the count charged and `codeSep` that rest; the hypotheses are the loop's
guards before the switch (an active branch with no non-top-level return, the count) and the pre-Genesis stack limit
the loop checks after the step (`1800–1803`).

`[SRC]` `interpreter.cpp:450–451`, `interpreter.cpp:466–471`, `interpreter.cpp:1445–1448`, `interpreter.cpp:1800–1803`

### `codeSep_sites` (theorem, `lean/BsvScript/Properties/Sighash.lean:74`)

**`codeSep_sites`.** *The rule:* `codeSep` is the script from the last executed `OP_CODESEPARATOR`, the whole
script before any. *What it says:* the two sites that write it: `evalScript` starts the loop with `codeSep` the
whole script (within the size limit), an executed separator sets it to the bytes after itself, and an unexecuted
one (an inactive branch) leaves the state as it was. *What it assumes:* the script within `maxScriptSize` for the
opening clause; nothing for the other two. [SRC] `407` (`pbegincodehash = script.begin()`), `1445–1448`
(`pbegincodehash = pc`), `482` (the switch runs only under `fExec` or for `OP_IF`…`OP_ENDIF`). The opcodes other
than the separator do not write `codeSep` (`execStep_codeSep`); the whole run is `codeSep_last`.

`[SRC]` `interpreter.cpp:407`, `interpreter.cpp:1445–1448`, `interpreter.cpp:482`

### `execStep_codeSep` (theorem, `lean/BsvScript/Properties/Sighash.lean:159`)

**`execStep_codeSep`.** *The rule:* an instruction other than an executed `OP_CODESEPARATOR` leaves the
scriptCode's start where it was. *What it says:* when `execStep` continues, the state's `codeSep` is the one it
was handed unless the opcode is `OP_CODESEPARATOR` and `fExec` holds (that site is `codeSep_sites`): the push
branch, the switch and the hook, the latter under the frame hypothesis `opExec_codeSep` discharges for the
evaluator. *What it assumes:* the hook's frame. [SRC] `473–481` (the push), `1445–1448` (the separator, the one
writer), `482` (the switch under `fExec` or for `OP_IF`…`OP_ENDIF`).

`[SRC]` `interpreter.cpp:473–481`, `interpreter.cpp:1445–1448`, `interpreter.cpp:482`

### `afterLastSep` (def, `lean/BsvScript/Properties/Sighash.lean:225`)

The offset after the last executed `OP_CODESEPARATOR` of a trace, `0` (the script's start) when none executed:
the reference's `pbegincodehash` as an offset, set to `script.begin()` (`407`) and to `pc` after the separator's
`GetOp` (`1445–1448`, `450`), which consumed the one opcode byte. An unexecuted separator (`fExec` false) does not
move it (`482`).

`[SRC]` `interpreter.cpp:407`, `interpreter.cpp:1445–1448`, `interpreter.cpp:450`, `interpreter.cpp:482`

### `codeSep_last` (theorem, `lean/BsvScript/Properties/Sighash.lean:288`)

**`codeSep_last`.** *The rule:* the scriptCode a signature check digests begins after the last executed
`OP_CODESEPARATOR` before the check, or at the script's start when none executed: `pbegincodehash` is set to
`script.begin()` and moved only by an executed `OP_CODESEPARATOR`, to the byte after it. *What it says:* for every
hook `exec` whose continuations leave `codeSep` as they found it (the frame `opExec_codeSep` proves for the
evaluator's own table, `Eval.opExec`), every run of `loop exec env` from a state whose `codeSep` is the script `s₀`
(as `evalScript` starts it, `codeSep_sites`) and every configuration `(s, st)` it reaches through the trace `tr`:
`st.codeSep` is `s₀` from the offset `afterLastSep tr`, the offset after the trace's last executed separator or `0`;
that offset is at or before the current instruction's, `s₀.length - s.length`; and `s` is `s₀` from that
instruction's offset. *What it assumes:* the hook's frame and the start. [SRC] `405–407` (`pc` and
`pbegincodehash` both `script.begin()`), `450` (`GetOp(pc, …)` advances `pc` past the instruction), `459`
(`fExec`), `482` (the switch runs only under `fExec` or for `OP_IF`…`OP_ENDIF`), `1445–1448` (`case
OP_CODESEPARATOR: pbegincodehash = pc;`), `1471–1473` and `1567–1569` ("Subset of script starting at the most
recent codeseparator to the end of the current script", `CScript scriptCode {pbegincodehash, pend}`). *Measured
contradiction:* none of the three signers measured under #145 and #147 is classed on the separator; their class,
`sighash.scriptcode.in-unlock.lock-only` (at @bsv/sdk 3.0.0 ruled `caller-scriptcode-required`, the class id
unchanged), is which script the scriptCode is drawn from (`scriptCode_run`, `scriptCode_last`)
(`docs/records/20261016-203024-s3-145d-signer-column-s3.md`, `docs/records/20261016-234915-s3-147-signer-column-s3.md`),
and @bsv/sdk's appended-lock behaviour (2.1.5 to 3.2.1)
(`docs/records/20261016-234806-s4b-147-tssdk-releases-s4b.md`) is that same scriptCode question, not a separator
one.

`[SRC]` `interpreter.cpp:405–407`, `interpreter.cpp:450`, `interpreter.cpp:459`, `interpreter.cpp:482`, `interpreter.cpp:1445–1448`, `interpreter.cpp:1471–1473`, `interpreter.cpp:1567–1569`

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

### `scriptCodeWalk` (def, `lean/BsvScript/Sighash.lean:196`)

The walk of `SerializeScriptCode` (`1862–1892`): the count of
`OP_CODESEPARATOR`s the parser reached and the bytes written (every parsed
`OP_CODESEPARATOR` byte removed; a failed parse ends the bytes after
`truncatedHead`).

`[SRC]` `interpreter.cpp:1862–1892`

### `getOpTail_codesep` (theorem, `lean/BsvScript/Sighash.lean:594`)

`OP_CODESEPARATOR` parses as a bare opcode (`script.h:176`: no immediate operand above
`OP_PUSHDATA4`).

`[SRC]` `script.h:176`

### `scriptCodeWalk_codesep` (theorem, `lean/BsvScript/Sighash.lean:599`)

T-SH11c: an `OP_CODESEPARATOR` at an opcode boundary is counted (`1871–1873`) and dropped
(`1879–1883`: the bytes before it written, the boundary moved past it).

`[SRC]` `interpreter.cpp:1871–1873`, `interpreter.cpp:1879–1883`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `crypto.codeseparator` | 4 | `interpreter.cpp:1445–1448` (`Machine.loop`) |
| `sighash.original` | 7 | `interpreter.cpp:1841–1958`, `2086–2110`; `transaction.h:196–199` |

