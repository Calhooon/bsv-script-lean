# `OP_ENDIF` (`0x68`)

**Family** flow · **module** `BsvScript.Machine` · **landed at** #8 · **the switch** §2.4 of DESIGN · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## Semantics (the Lean docstrings that name it)

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

### `vEndifAlone_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:363`)

`1 OP_ENDIF` fails `SCRIPT_ERR_UNBALANCED_CONDITIONAL`: no `IF` is open (`835–840`).

`[SRC]` `interpreter.cpp:835–840`

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

### `sigOpWalk` (def, `lean/BsvScript/SigOps.lean:71`)

`CScript::GetSigOpCount(fAccurate, era, sigOpCountError)` (`script.cpp:30–128`), the walk: `fuel`
bounds the steps (`sigOpCount` gives the script's length, enough since every step consumes a byte); the
state is the last instruction's opcode and operand (`37`, `120`), the scope level (`33`) and the count
(`29`); a failed decode or a literal `0xff` ends it (`40–41`), a top-level `OP_RETURN` under `fAccurate`
or Genesis ends it (`45–49`), an unbalanced `OP_ENDIF` there is `none` (`55–63`), as is an instruction's
error (`opSigOps`).

`[SRC]` `script.cpp:30–128`, `script.cpp:37`, `script.cpp:120`, `script.cpp:33`, `script.cpp:29`, `script.cpp:40–41`, `script.cpp:45–49`, `script.cpp:55–63`

### `sigOpCount_endif` (theorem, `lean/BsvScript/SigOps.lean:322`)

**T-SO3 (an unbalanced `OP_ENDIF`).** *What it says:* under `fAccurate` or Genesis a script that
begins with `OP_ENDIF` has no count, whatever follows. *What it assumes:* `accurate || genesis`. *Why it
matters:* this is `sigOpCountError` (`script.cpp:59–67`), which the mempool refuses at any cap
(`validation.cpp:1242`): an output script opening with `OP_ENDIF` makes its transaction non-relayable
after Genesis, though no script ever runs it.

`[SRC]` `script.cpp:59–67`, `validation.cpp:1242`

### `endifWitnessTx` (def, `lean/BsvScript/TxPolicy.lean:424`)

The witness of an unbalanced `OP_ENDIF` (`SigOps.sigOpCount_endif`): one input and one output of
0 satoshis paying `OP_ENDIF`.

### `txSigOpCount_output_error` (theorem, `lean/BsvScript/TxPolicy.lean:548`)

**T-SO14 (an output's error is the transaction's).** *What it says:* when an output script's count is
`sigOpCountError`, the transaction's count is too. *What it assumes:* the output is the transaction's.
*Why it matters:* one output opening with an unbalanced `OP_ENDIF` (after Genesis), or a multisig after
a bad count push, makes the whole transaction's count an error (`validation.cpp:453–457`), refused by the
mempool at any cap (`txPolicyGateCounted_error`).

`[SRC]` `validation.cpp:453–457`

### `txPolicyGateCounted_postGenesis_iff` (theorem, `lean/BsvScript/TxPolicy.lean:571`)

**T-TP6 (what the counted gate adds after Genesis, at the consensus configuration).** *What it says:*
after Genesis, on the node's zero-rule caps (`txPolicyAtConsensus`), a transaction the consensus gate
accepts passes the counted gate exactly when its count is a number of at most `UINT32_MAX`. *What it
assumes:* the consensus gate's `.ok ()` at the after-Genesis size cap. *Why it matters:* on a transaction the
standardness gate passes (T-STD5), this is the whole difference between the block's transaction gate and the
mempool's (`Bsvs.Run.txGate`) after Genesis at those caps, the scripts aside (they run under the relay word and
the policy limits, `Params.derive` with `consensus` false; for a version-2 spend after Chronicle on mainnet,
`Params.verifyScript_relay_block_version2`): a `sigOpCountError` (an unbalanced `OP_ENDIF`, a bad multisig count
push) or a count past `UINT32_MAX` (`multisigWitnessTx`), never the size (T-TP3); the standardness gate,
which runs first, adds its own reasons (`dust` in T-STD8).

### `mempoolTxPolicy_endif_witness` (theorem, `lean/BsvScript/TxPolicy.lean:625`)

**T-TP8 (the witness of the unbalanced `OP_ENDIF`).** *What it says:* after Genesis the transaction
`endifWitnessTx` has no count, and the mempool refuses it at every node configuration. *What it assumes:*
a spend after Genesis. *Why it matters:* `sigOpCountError` (`script.cpp:59–67`) on an output script that
no script ever executes still keeps the transaction out of every SV-node mempool (`validation.cpp:1242`),
whether or not the standardness gate refuses it first (its zero-value output is dust, refused where the
gate's condition holds); the corpus entry that exercises it is the harness's (#26).

`[SRC]` `script.cpp:59–67`, `validation.cpp:1242`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `flow.if`, `flow.notif`, `flow.nesting`, `flow.else`, `flow.unbalanced` | 156 | `interpreter.cpp:773–840` (the tracker `conditional_tracker.cpp:32–71`), `1828–1830` |

