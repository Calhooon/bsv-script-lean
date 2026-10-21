# `OP_CHECKSEQUENCEVERIFY` (`0xb2`)

**Family** expansion (lock time) · **module** `BsvScript.Machine` · **landed at** #22 · **the switch** `519–597` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- live for pre-Genesis UTXOs under the flag (`520`, `563`); a NOP for post-Genesis UTXOs, discouraged under DISCOURAGE_UPGRADABLE_NOPS (policy)

## Semantics (the Lean docstrings that name it)

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

### `execCsvI_eq` (theorem, `lean/BsvScript/Impl/Machine.lean:216`)

**`execCsvI_eq`.** *What it says:* the implementation's `OP_CHECKSEQUENCEVERIFY` says what the spec's says.
*What it assumes:* nothing. *Why it matters:* the sequence check on the implementation (#50).

### `readNum` (def, `lean/BsvScript/Numbers.lean:247`)

Reading a number from a stack element: the length bound first, then, under
`requireMinimal` (`docs/DESIGN.md` §5.3), minimality; then `deserialize`.
`maxLen` is `MaxScriptNumLength` (`docs/PARAMETERS.md` §1) or `5` for
CLTV/CSV (`interpreter.cpp:546`, `577`).

`[SRC]` `interpreter.cpp:546`, `interpreter.cpp:577`

### `ChainParams.mainnet` (def, `lean/BsvScript/Params.lean:183`)

Mainnet (`CMainParams`, `chainparams.cpp:1034–1076`): P2SH 173,805
(`P2SH_ACTIVATION_MAIN`, `:28`, `:1076`), BIP66 363,725 (`:1044`), BIP65 388,381
(`:1042`), CSV 419,328 (`:1046`), UAHF 478,558 (`:1065`), DAA 504,031 (`:1068`),
Genesis 620,538 (`GENESIS_ACTIVATION_MAIN`, `:18`, `:1071`), Chronicle 943,816
(`CHRONICLE_ACTIVATION_MAIN`, `:23`, `:1074`).
[LIT] https://protocol.bsvblockchain.org/specification/upgrade-history#timeline at v1.2.2 (the heights only; not its "fork by time" rows for UAHF, Nov 2017, May 2018 and Nov 2018, THEIRS T3).
[LIT] https://protocol.bsvblockchain.org/specification/upgrade-history#genesis-2020-02-04 at v1.2.2 (the Genesis height only).
[LIT] https://protocol.bsvblockchain.org/specification/upgrade-history#chronicle-2026-04-07 at v1.2.2 (the Chronicle height only).

`[SRC]` `chainparams.cpp:1034–1076`, `chainparams.cpp:28`, `chainparams.cpp:1076`, `chainparams.cpp:1044`, `chainparams.cpp:1042`, `chainparams.cpp:1046`, `chainparams.cpp:1065`, `chainparams.cpp:1068`, `chainparams.cpp:18`, `chainparams.cpp:1071`, `chainparams.cpp:23`, `chainparams.cpp:1074`

### `flagWord_block_csv` (theorem, `lean/BsvScript/Properties/Eras.lean:224`)

**CSV enters at `CSVHeight`** (`verify_script_flags.cpp:51` tests `height + 1`).

`[SRC]` `verify_script_flags.cpp:51`

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

### `execCsv_nop_postGenesis` (theorem, `lean/BsvScript/Properties/Eras.lean:551`)

**CSV is a NOP on a post-Genesis coin** (`563`), discouraged under the policy flag (`565–569`).

`[SRC]` `interpreter.cpp:563`, `interpreter.cpp:565–569`

### `execCsv_unsatisfied_preGenesis` (theorem, `lean/BsvScript/Properties/Eras.lean:556`)

**CSV is live on a pre-Genesis coin under the flag** (`563`, `577–595`): an operand without the
disable bit whose relative lock is unsatisfied is `SCRIPT_ERR_UNSATISFIED_LOCKTIME`.

`[SRC]` `interpreter.cpp:563`, `interpreter.cpp:577–595`

### `execCsv_satisfied_preGenesis` (theorem, `lean/BsvScript/Properties/Eras.lean:566`)

The satisfied case leaves the operand on the stack (`593–596`: only `break`), CLTV's twin
(`execCltv_satisfied_preGenesis`); with `execCsv_unsatisfied_preGenesis` and `checkSequence_iff` this is CSV's
verdict on a pre-Genesis coin under the flag once a non-negative operand without the disable flag is read. The
theorems assume that read (`hs`, `hr`, `hn`); CSV's other outcomes there are the empty stack (`571–572`), the
operand over five bytes or not minimal (`577`, caught at `1807–1814`) and the negative operand (`582–583`).

`[SRC]` `interpreter.cpp:593–596`, `interpreter.cpp:571–572`, `interpreter.cpp:577`, `interpreter.cpp:1807–1814`, `interpreter.cpp:582–583`

### `execCsv_disable_flag_operand` (theorem, `lean/BsvScript/Properties/Eras.lean:579`)

**An operand with the disable flag makes CSV a NOP** (`585–590`: `nSequence & SEQUENCE_LOCKTIME_DISABLE_FLAG`
non-zero, `break` before the checker; bit 31, `transaction.h:106`): the operand's own bit, whatever the spent input's
sequence, so the checker's test of the input's bit (`checkSequence_disable_flag`, `2220–2222`) is never reached.

`[SRC]` `interpreter.cpp:585–590`, `transaction.h:106`, `interpreter.cpp:2220–2222`

### `checkSequence_disable_flag` (theorem, `lean/BsvScript/Properties/Eras.lean:764`)

**The disable flag on the sequence** (`2220–2222`): with bit 31 set on the spent input's `nSequence`, CSV is
never satisfied (relative lock time is off for that input, BIP 68).

`[SRC]` `interpreter.cpp:2220–2222`

### `checkSequence_final` (theorem, `lean/BsvScript/Properties/Eras.lean:773`)

`SEQUENCE_FINAL` (`0xffffffff`, `transaction.h:99`) carries the disable flag, so a final input never satisfies
CSV either (`2220–2222`).

`[SRC]` `transaction.h:99`, `interpreter.cpp:2220–2222`

### `checkSequence_iff` (theorem, `lean/BsvScript/Properties/Eras.lean:786`)

**`CheckSequence` as one predicate** (`2204–2250`): the version at least 2 as an unsigned word (`2212–2214`),
no disable flag on the sequence (`2220–2222`), the two values masked to the type flag and the low sixteen bits
(`2226–2229`) of one kind (`2237–2242`), and the operand's at most the sequence's (`2246–2248`). With
`execCsv_unsatisfied_preGenesis` and `execCsv_satisfied_preGenesis` this is CSV's verdict on a pre-Genesis coin under
the flag once a non-negative operand without the disable flag is read (the outcomes before that read are named at
`execCsv_satisfied_preGenesis`).

`[SRC]` `interpreter.cpp:2204–2250`, `interpreter.cpp:2212–2214`, `interpreter.cpp:2220–2222`, `interpreter.cpp:2226–2229`, `interpreter.cpp:2237–2242`, `interpreter.cpp:2246–2248`

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

### `execCsv_opCount` (theorem, `lean/BsvScript/Properties/Resources.lean:105`)

`OP_CHECKSEQUENCEVERIFY` leaves the op count as it found it (`562–597`: it only reads the stack).

`[SRC]` `interpreter.cpp:562–597`

### `execCsv_memInv` (theorem, `lean/BsvScript/Properties/Resources.lean:452`)

`OP_CHECKSEQUENCEVERIFY` keeps the accounting invariant (`562–597`: it leaves the operand where it is).

`[SRC]` `interpreter.cpp:562–597`

### `execCsv_codeSep` (theorem, `lean/BsvScript/Properties/Sighash.lean:137`)

`OP_CHECKSEQUENCEVERIFY` leaves `codeSep` as it found it (`562–597`).

`[SRC]` `interpreter.cpp:562–597`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `tx.locktime`, `tx.sequence` | 21 | `interpreter.cpp:519–597`, `2166–2250`; `script.h:36`, `transaction.h:99–119` |
| `eras.utxo.pre-genesis`, `eras.utxo.post-genesis`, `eras.utxo.post-chronicle` | 42 | `interpreter.cpp:411–427`, `2269–2280`; `configscriptpolicy.cpp:65–154`; the sites named |
| `eras.height.p2sh`, `eras.height.dersig`, `eras.height.cltv`, `eras.height.csv`, `eras.height.uahf`, `eras.height.daa` | 16 | `verify_script_flags.cpp:32–81`; `validation.cpp:2973–2982`, `3473`; `chainparams.cpp:1038–1076`, `:28` |

