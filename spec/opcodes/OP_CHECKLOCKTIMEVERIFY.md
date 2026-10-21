# `OP_CHECKLOCKTIMEVERIFY` (`0xb1`)

**Family** expansion (lock time) · **module** `BsvScript.Machine` · **landed at** #22 · **the switch** `519–597` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- live for pre-Genesis UTXOs under the flag (`520`, `563`); a NOP for post-Genesis UTXOs, discouraged under DISCOURAGE_UPGRADABLE_NOPS (policy)

## Semantics (the Lean docstrings that name it)

### `execCltv` (def, `lean/BsvScript/Machine.lean:270`)

`OP_CHECKLOCKTIMEVERIFY` (`519–560`): a NOP for post-Genesis UTXOs or without
the flag (discouraged under the policy flag, `520–526`); else a 5-byte number
(`546`), non-negative (`550–551`), against the checker (`555–556`). Leaves the
operand on the stack.

`[SRC]` `interpreter.cpp:519–560`, `interpreter.cpp:520–526`, `interpreter.cpp:546`, `interpreter.cpp:550–551`, `interpreter.cpp:555–556`

### `execCsv` (def, `lean/BsvScript/Machine.lean:289`)

`OP_CHECKSEQUENCEVERIFY` (`562–597`): as CLTV, plus an operand with the
disable flag (bit 31, `transaction.h:106`) makes it a NOP (`585–587`).

`[SRC]` `interpreter.cpp:562–597`, `transaction.h:106`, `interpreter.cpp:585–587`

### `blockScriptFlags` (def, `lean/BsvScript/Flags.lean:167`)

`GetBlockScriptFlags(consensus_params, height, protocol_era)`
(`verify_script_flags.cpp:32–81`): P2SH from `p2shHeight` (`:39`); DERSIG, CLTV and
CSV from `height + 1` against `BIP66Height`, `BIP65Height`, `CSVHeight`
(`:43`, `:47`, `:51`); STRICTENC and FORKID from `uahfHeight` (`:55–59`); LOW_S and
NULLFAIL from `daaHeight` (`:65–69`); `SCRIPT_GENESIS` and SIGPUSHONLY when Genesis
is active in the era (`:71–75`); `SCRIPT_CHRONICLE` when Chronicle is (`:77–78`).
`height` is the chain tip's (the block being validated is `height + 1`,
`validation.cpp:2972–2981`, `validation.cpp:3472`).

`[SRC]` `verify_script_flags.cpp:32–81`, `verify_script_flags.cpp:39`, `verify_script_flags.cpp:43`, `verify_script_flags.cpp:47`, `verify_script_flags.cpp:51`, `verify_script_flags.cpp:55–59`, `verify_script_flags.cpp:65–69`, `verify_script_flags.cpp:71–75`, `verify_script_flags.cpp:77–78`, `validation.cpp:2972–2981`, `validation.cpp:3472`

### `mainnetBlockWord` (def, `lean/BsvScript/Flags.lean:677`)

The block word of a post-Chronicle spend of a post-Chronicle output on mainnet
(every activation passed): P2SH · STRICTENC · DERSIG · LOW_S · SIGPUSHONLY · CLTV ·
CSV · NULLFAIL · FORKID · GENESIS · UTXO_AFTER_GENESIS · CHRONICLE ·
UTXO_AFTER_CHRONICLE = `0x3D462F`.

### `readNum_eq` (theorem, `lean/BsvScript/Impl/Elem.lean:292`)

**`readNum_eq`.** *What it says:* the element's reader answers what the spec's reader answers on its list.
*What it assumes:* nothing. *Why it matters:* `OP_CHECKLOCKTIMEVERIFY`, `OP_CHECKSEQUENCEVERIFY` (#143).

### `execCltvI_eq` (theorem, `lean/BsvScript/Impl/Machine.lean:182`)

**`execCltvI_eq`.** *What it says:* the implementation's `OP_CHECKLOCKTIMEVERIFY` says what the spec's says.
*What it assumes:* nothing. *Why it matters:* the lock-time check on the implementation (#50).

### `readNum` (def, `lean/BsvScript/Numbers.lean:247`)

Reading a number from a stack element: the length bound first, then, under
`requireMinimal` (`docs/DESIGN.md` §5.3), minimality; then `deserialize`.
`maxLen` is `MaxScriptNumLength` (`docs/PARAMETERS.md` §1) or `5` for
CLTV/CSV (`interpreter.cpp:546`, `577`).

`[SRC]` `interpreter.cpp:546`, `interpreter.cpp:577`

### `flagWord_block_cltv` (theorem, `lean/BsvScript/Properties/Eras.lean:218`)

**CLTV enters at `BIP65Height`** (`verify_script_flags.cpp:47` tests `height + 1`).

`[SRC]` `verify_script_flags.cpp:47`

### `derive_preGenesis_coin` (theorem, `lean/BsvScript/Properties/Eras.lean:388`)

**Q3 (`docs/DESIGN.md` §9): a pre-Genesis output spent after Genesis.** *What it says:*
for a coin created below the Genesis height, whatever the spend height, on the block path and on the
mempool path of a node with no promiscuous word (`hp`; the route it excludes is in `derive_utxoEra`), the
interpreter reads the coin's era as pre-Genesis (no UTXO marker, `411–427`), the limits
are the pre-Genesis constants (`2282–2302`, `configscriptpolicy.cpp:65–154`), and the
spending era's bits (GENESIS, SIGPUSHONLY, CHRONICLE) are the spend height's
(`policy.h:225–244`, `verify_script_flags.cpp:71–78`). *Why it matters:* the pre-Genesis
UTXO rules (the 520-byte element, the 1,000-element stack, 4-byte numbers, `OP_RETURN`
invalid, P2SH, CLTV/CSV live, the second `OP_ELSE`) hang on the coin's era, and the version
gate and push-only rule on the spend's: the two are separate parameters of one word.

`[SRC]` `interpreter.cpp:411–427`, `interpreter.cpp:2282–2302`, `configscriptpolicy.cpp:65–154`, `policy.h:225–244`, `verify_script_flags.cpp:71–78`

### `execCltv_nop_postGenesis` (theorem, `lean/BsvScript/Properties/Eras.lean:526`)

**CLTV is a NOP on a post-Genesis coin** (`520`: `|| utxo_after_genesis`), discouraged under
the policy flag (`522–526`).

`[SRC]` `interpreter.cpp:520`, `interpreter.cpp:522–526`

### `execCltv_unsatisfied_preGenesis` (theorem, `lean/BsvScript/Properties/Eras.lean:532`)

**CLTV is live on a pre-Genesis coin under the flag** (`520`, `546–556`): an unsatisfied lock
time is `SCRIPT_ERR_UNSATISFIED_LOCKTIME`, whatever the spend era.

`[SRC]` `interpreter.cpp:520`, `interpreter.cpp:546–556`

### `execCsv_satisfied_preGenesis` (theorem, `lean/BsvScript/Properties/Eras.lean:566`)

The satisfied case leaves the operand on the stack (`593–596`: only `break`), CLTV's twin
(`execCltv_satisfied_preGenesis`); with `execCsv_unsatisfied_preGenesis` and `checkSequence_iff` this is CSV's
verdict on a pre-Genesis coin under the flag once a non-negative operand without the disable flag is read. The
theorems assume that read (`hs`, `hr`, `hn`); CSV's other outcomes there are the empty stack (`571–572`), the
operand over five bytes or not minimal (`577`, caught at `1807–1814`) and the negative operand (`582–583`).

`[SRC]` `interpreter.cpp:593–596`, `interpreter.cpp:571–572`, `interpreter.cpp:577`, `interpreter.cpp:1807–1814`, `interpreter.cpp:582–583`

### `checkLockTime_iff` (theorem, `lean/BsvScript/Properties/Eras.lean:727`)

**`CheckLockTime` as one predicate** (`2166–2202`): satisfied iff the operand and `nLockTime` are of one kind
(both below `LOCKTIME_THRESHOLD` or both at least it, `2175–2180`), the operand is at most the lock time
(`2184–2186`) and the spent input is not final (`2196–2198`). With `execCltv_satisfied_preGenesis` and
`execCltv_unsatisfied_preGenesis` this is CLTV's verdict on a pre-Genesis coin under the flag once a non-negative
operand is read. Those theorems assume that read (`hs`, `hr`, `hn`); CLTV's other outcomes there are the empty
stack (`528–529`), the operand over five bytes or not minimal (`546`, caught at `1807–1814`) and the negative operand
(`551–552`).

`[SRC]` `interpreter.cpp:2166–2202`, `interpreter.cpp:2175–2180`, `interpreter.cpp:2184–2186`, `interpreter.cpp:2196–2198`, `interpreter.cpp:528–529`, `interpreter.cpp:546`, `interpreter.cpp:1807–1814`, `interpreter.cpp:551–552`

### `checkSequence_missing_input` (theorem, `lean/BsvScript/Properties/Eras.lean:780`)

As for CLTV: an input index past the inputs reads as final, never satisfied.

### `cltv_csv_block_postGenesis` (theorem, `lean/BsvScript/Properties/Eras.lean:894`)

… and CLTV/CSV on a post-Genesis coin continue (`520–526`, `563–569`), under the same hypothesis and a
post-Genesis coin (`hg`). With `mkEnv_block_discourage_off` the three are "policy never decides block validity", read
per opcode; the standard word (`standardOnly`, `policy.h:182–189`) fails each of these sites instead
(`nopOrDiscourage_standard`, `execFlow_nop_standard`, `execCltv_nop_postGenesis`, `execCsv_nop_postGenesis`).

`[SRC]` `interpreter.cpp:520–526`, `interpreter.cpp:563–569`, `policy.h:182–189`

### `nopOrDiscourage_standard` (theorem, `lean/BsvScript/Properties/Eras.lean:903`)

The relay side of the same sites: with the flag on (the standard word), the pre-Chronicle expansion NOP is
`SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS` (`613–614`), as `OP_NOP1`/`OP_NOP9`/`OP_NOP10` are (`768–769`,
`execFlow_nop_standard`) and post-Genesis CLTV/CSV are (`522–523`, `565–566`; `execCltv_nop_postGenesis`,
`execCsv_nop_postGenesis`).

`[SRC]` `interpreter.cpp:613–614`, `interpreter.cpp:768–769`, `interpreter.cpp:522–523`, `interpreter.cpp:565–566`

### `execCltv_opCount` (theorem, `lean/BsvScript/Properties/Resources.lean:97`)

`OP_CHECKLOCKTIMEVERIFY` leaves the op count as it found it (`519–560`: it only reads the stack).

`[SRC]` `interpreter.cpp:519–560`

### `execCltv_memInv` (theorem, `lean/BsvScript/Properties/Resources.lean:444`)

`OP_CHECKLOCKTIMEVERIFY` keeps the accounting invariant (`519–560`: it leaves the operand where it is).

`[SRC]` `interpreter.cpp:519–560`

### `execCltv_codeSep` (theorem, `lean/BsvScript/Properties/Sighash.lean:128`)

`OP_CHECKLOCKTIMEVERIFY` leaves `codeSep` as it found it (`519–560`).

`[SRC]` `interpreter.cpp:519–560`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `tx.locktime`, `tx.sequence` | 21 | `interpreter.cpp:519–597`, `2166–2250`; `script.h:36`, `transaction.h:99–119` |
| `eras.utxo.pre-genesis`, `eras.utxo.post-genesis`, `eras.utxo.post-chronicle` | 42 | `interpreter.cpp:411–427`, `2269–2280`; `configscriptpolicy.cpp:65–154`; the sites named |
| `eras.height.p2sh`, `eras.height.dersig`, `eras.height.cltv`, `eras.height.csv`, `eras.height.uahf`, `eras.height.daa` | 16 | `verify_script_flags.cpp:32–81`; `validation.cpp:2973–2982`, `3473`; `chainparams.cpp:1038–1076`, `:28` |

