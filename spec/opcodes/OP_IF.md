# `OP_IF` (`0x63`)

**Family** flow · **module** `BsvScript.Machine` · **landed at** #8 · **the switch** §2.4 of DESIGN · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- MINIMALIF (never set by the node at the pin) under the version gate (`796–804`)

## Semantics (the Lean docstrings that name it)

### `execIf` (def, `lean/BsvScript/Machine.lean:245`)

`OP_IF`/`OP_NOTIF`/`OP_VERIF`/`OP_VERNOTIF` (`784–825`): when executing, pop
the condition (`792–793`, `821`), MINIMALIF under the version gate for
`IF`/`NOTIF` only (`796–804`), the version comparison for `VERIF`/`VERNOTIF`
(`806–812`: only a 4-byte element can be true), `CastToBool` otherwise (`815`),
negated for the NOT forms (`817–818`); a non-executing one pushes `false`
without popping (`789`, `823`).

`[SRC]` `interpreter.cpp:784–825`, `interpreter.cpp:792–793`, `interpreter.cpp:821`, `interpreter.cpp:796–804`, `interpreter.cpp:806–812`, `interpreter.cpp:815`, `interpreter.cpp:817–818`, `interpreter.cpp:789`, `interpreter.cpp:823`

### `execFlow` (def, `lean/BsvScript/Machine.lean:307`)

The pushes and the flow opcodes of the switch (`483–871`), then the family
hook. Called with `fExec`, or for `OP_IF`…`OP_ENDIF` regardless (`482`).

`[SRC]` `interpreter.cpp:483–871`, `interpreter.cpp:482`

### `execStep` (def, `lean/BsvScript/Machine.lean:358`)

One opcode once the guards passed: a push under `fExec` (`473–481`), the
separator (`1445–1448`, the loop's own: `pbegincodehash = pc`, the byte after
it), the switch under `fExec` or for `OP_IF`…`OP_ENDIF` regardless (`482`),
else nothing (an unexecuted branch).

`[SRC]` `interpreter.cpp:473–481`, `interpreter.cpp:1445–1448`, `interpreter.cpp:482`

### `head?_toBytes` (theorem, `lean/BsvScript/Impl/Elem.lean:172`)

**`head?_toBytes`.** *What it says:* the list's first byte is the element's. *What it assumes:* nothing.
*Why it matters:* `OP_IF`'s minimal-if test (#143).

### `castToBool_eq` (theorem, `lean/BsvScript/Impl/Elem.lean:304`)

**`castToBool_eq`.** *What it says:* the element's truth is its list's. *What it assumes:* nothing. *Why it
matters:* `OP_IF`, `OP_VERIFY`, `OP_IFDUP`, `OP_NUMEQUALVERIFY` (#143).

### `execIfI_eq` (theorem, `lean/BsvScript/Impl/Machine.lean:153`)

**`execIfI_eq`.** *What it says:* the implementation's `OP_IF` family says what the spec's says. *What it
assumes:* nothing. *Why it matters:* the conditionals on the implementation (#50).

### `execStep_codeseparator_unexecuted` (theorem, `lean/BsvScript/Properties/Eras.lean:816`)

Unexecuted (an inactive branch) it changes nothing (`482`: the switch runs only under `fExec` or for
`OP_IF`…`OP_ENDIF`, and `0xab` is outside that range).

`[SRC]` `interpreter.cpp:482`

### `vIfElse_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:345`)

`0 OP_IF 0 OP_ELSE 1 OP_ENDIF` is valid: the false branch is skipped, the else branch runs (`784–840`).

`[SRC]` `interpreter.cpp:784–840`

### `vNotifNested_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:351`)

`0 OP_NOTIF 1 OP_IF 1 OP_ENDIF OP_ELSE 0 OP_ENDIF` is valid: a nested conditional inside a taken `NOTIF` branch (`784–840`).

`[SRC]` `interpreter.cpp:784–840`

### `vUnclosedIf_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:357`)

`1 OP_IF 1` fails `SCRIPT_ERR_UNBALANCED_CONDITIONAL`: the script ends with the `IF` open (`1828–1830`).

`[SRC]` `interpreter.cpp:1828–1830`

### `execIf_opCount` (theorem, `lean/BsvScript/Properties/Resources.lean:88`)

`OP_IF` and its three siblings leave the op count as they found it (`784–825`: the tracker and one pop).

`[SRC]` `interpreter.cpp:784–825`

### `execIf_memInv` (theorem, `lean/BsvScript/Properties/Resources.lean:428`)

`OP_IF` and its three siblings keep the accounting invariant (`784–825`: one pop, its weight released, or nothing).

`[SRC]` `interpreter.cpp:784–825`

### `codeSep_sites` (theorem, `lean/BsvScript/Properties/Sighash.lean:74`)

**`codeSep_sites`.** *The rule:* `codeSep` is the script from the last executed `OP_CODESEPARATOR`, the whole
script before any. *What it says:* the two sites that write it: `evalScript` starts the loop with `codeSep` the
whole script (within the size limit), an executed separator sets it to the bytes after itself, and an unexecuted
one (an inactive branch) leaves the state as it was. *What it assumes:* the script within `maxScriptSize` for the
opening clause; nothing for the other two. [SRC] `407` (`pbegincodehash = script.begin()`), `1445–1448`
(`pbegincodehash = pc`), `482` (the switch runs only under `fExec` or for `OP_IF`…`OP_ENDIF`). The opcodes other
than the separator do not write `codeSep` (`execStep_codeSep`); the whole run is `codeSep_last`.

`[SRC]` `interpreter.cpp:407`, `interpreter.cpp:1445–1448`, `interpreter.cpp:482`

### `execIf_codeSep` (theorem, `lean/BsvScript/Properties/Sighash.lean:119`)

`OP_IF` and its three siblings leave `codeSep` as they found it (`784–854`: the tracker and one pop).

`[SRC]` `interpreter.cpp:784–854`

### `execStep_codeSep` (theorem, `lean/BsvScript/Properties/Sighash.lean:159`)

**`execStep_codeSep`.** *The rule:* an instruction other than an executed `OP_CODESEPARATOR` leaves the
scriptCode's start where it was. *What it says:* when `execStep` continues, the state's `codeSep` is the one it
was handed unless the opcode is `OP_CODESEPARATOR` and `fExec` holds (that site is `codeSep_sites`): the push
branch, the switch and the hook, the latter under the frame hypothesis `opExec_codeSep` discharges for the
evaluator. *What it assumes:* the hook's frame. [SRC] `473–481` (the push), `1445–1448` (the separator, the one
writer), `482` (the switch under `fExec` or for `OP_IF`…`OP_ENDIF`).

`[SRC]` `interpreter.cpp:473–481`, `interpreter.cpp:1445–1448`, `interpreter.cpp:482`

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

### `scopeAfter` (def, `lean/BsvScript/SigOps.lean:62`)

The scope level after an instruction (`script.cpp:47–69`), tracked only under `fAccurate` or Genesis
(`tracked`): `OP_IF`, `OP_NOTIF`, `OP_VERIF`, `OP_VERNOTIF` open a scope (`50–54`), `OP_ENDIF` closes one
(`55–58`).

`[SRC]` `script.cpp:47–69`, `script.cpp:50–54`, `script.cpp:55–58`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `flow.if`, `flow.notif`, `flow.nesting`, `flow.else`, `flow.unbalanced` | 156 | `interpreter.cpp:773–840` (the tracker `conditional_tracker.cpp:32–71`), `1828–1830` |

