# `OP_RETURN` (`0x6a`)

**Family** flow · **module** `BsvScript.Machine` · **landed at** #8 · **the switch** §2.4 of DESIGN · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- pre-Genesis UTXO: `SCRIPT_ERR_OP_RETURN` (`867–869`); post-Genesis: a top-level `OP_RETURN` ends the script as success (`858–861`), inside a conditional nothing executes but the balance is enforced (`865`, `482`)

## Semantics (the Lean docstrings that name it)

### `abs_nonTopLevelReturn` (theorem, `lean/BsvScript/Impl/State.lean:132`)

**`abs_nonTopLevelReturn`.** *What it says:* the spec state's `nonTopLevelReturn` is the implementation's. *What it assumes:*
nothing. *Why it matters:* the post-Genesis `OP_RETURN` mark, read by the loop's `fExec` (#50).

### `opreturn_suffix` (theorem, `lean/BsvScript/Properties/Basic.lean:115`)

**`opreturn_suffix`.** *What it says:* the loop never reads the bytes after a
top-level `OP_RETURN`: for a post-Genesis UTXO, with no enclosing conditional,
the loop returns at the `OP_RETURN` whatever follows it (`interpreter.cpp:858–861`:
`return SCRIPT_ERR_OK;` from `EvalScript`), so nothing after it is parsed,
counted or executed. *What it assumes:* the UTXO is post-Genesis and the tracker
is empty (so the `OP_RETURN` is top-level and executing). *Why it matters:* it
says what the loop does with the suffix and no more; the suffix still bears on
the verdict. Its bytes count toward the script size, checked on the whole script
before the loop runs (`429–430`, `Machine.evalScript`), and a signature checked
earlier in the same script signs them, its scriptCode running from the last
separator to the script's end (`1473`, `1569`); post-Chronicle, a signature check
in the unlocking script also signs the whole locking script (`1475–1481`). So a
change to the suffix can change the verdict.

`[SRC]` `interpreter.cpp:858–861`, `interpreter.cpp:429–430`, `interpreter.cpp:1473`, `interpreter.cpp:1569`, `interpreter.cpp:1475–1481`

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

### `execFlow_return_preGenesis` (theorem, `lean/BsvScript/Properties/Eras.lean:438`)

**`OP_RETURN` on a pre-Genesis coin fails** (`856–871`, `867–869`): executed, it is
`SCRIPT_ERR_OP_RETURN` whatever the spend era.

`[SRC]` `interpreter.cpp:856–871`, `interpreter.cpp:867–869`

### `execFlow_return_postGenesis_top` (theorem, `lean/BsvScript/Properties/Eras.lean:447`)

**A top-level `OP_RETURN` on a post-Genesis coin ends the script as success** (`858–861`).

`[SRC]` `interpreter.cpp:858–861`

### `execFlow_return_postGenesis_nested` (theorem, `lean/BsvScript/Properties/Eras.lean:455`)

**A nested `OP_RETURN` on a post-Genesis coin marks the rest as unexecuted** (`863–866`).

`[SRC]` `interpreter.cpp:863–866`

### `vReturnSuffix_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:375`)

`1 OP_RETURN` followed by a truncated push is valid: a top-level `OP_RETURN` post-Genesis ends the script before the rest is parsed (`856–861`).

`[SRC]` `interpreter.cpp:856–861`

### `execFlow_preserves` (theorem, `lean/BsvScript/Properties/Resources.lean:113`)

**The machine's own switch, branch by branch** (`483–871`): a property of states that holds of the
state handed in, of every push's result, of the three checkers' results (`execCltv`, `execCsv`,
`execIf`), of the tracker and `OP_RETURN` updates, of `OP_VERIFY`'s pop and of the hook's answer holds
of every state `execFlow` continues with. Walked `if` by `if` (`split_ifs` on the thirteen-way chain
times out), so each of R2 and R3 discharges the branches once.

`[SRC]` `interpreter.cpp:483–871`

### `sigOpWalk` (def, `lean/BsvScript/SigOps.lean:71`)

`CScript::GetSigOpCount(fAccurate, era, sigOpCountError)` (`script.cpp:30–128`), the walk: `fuel`
bounds the steps (`sigOpCount` gives the script's length, enough since every step consumes a byte); the
state is the last instruction's opcode and operand (`37`, `120`), the scope level (`33`) and the count
(`29`); a failed decode or a literal `0xff` ends it (`40–41`), a top-level `OP_RETURN` under `fAccurate`
or Genesis ends it (`45–49`), an unbalanced `OP_ENDIF` there is `none` (`55–63`), as is an instruction's
error (`opSigOps`).

`[SRC]` `script.cpp:30–128`, `script.cpp:37`, `script.cpp:120`, `script.cpp:33`, `script.cpp:29`, `script.cpp:40–41`, `script.cpp:45–49`, `script.cpp:55–63`

### `sigOpCount_return` (theorem, `lean/BsvScript/SigOps.lean:345`)

**T-SO5 (a top-level `OP_RETURN` ends the walk).** *What it says:* under `fAccurate` or Genesis a script
that begins with `OP_RETURN` counts nothing, whatever follows. *What it assumes:* `accurate || genesis`.
*Why it matters:* "everything after `OP_RETURN` at top level scope is unexecutable" (`script.cpp:49–53`);
a data carrier's bytes never count after Genesis.

`[SRC]` `script.cpp:49–53`

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

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `flow.verify`, `flow.return` | 64 | `842–854`, `856–871`, `459`, `482` |
| `sighash.original.truncated-push` | 6 | `interpreter.cpp:1862–1892`; `script.h:163–196` (`GetOp2`) |
| `flags.v1.minimaldata.push`, `flags.v1.minimaldata.number` | 36 | `interpreter.cpp:433–434`, `473–479`, `331–358`; `script_num.cpp:53–89`, `int_serialization.h:97–129`; the reads `546`, `577`, `622`, `624`, `655`, `680`, `709`, `717`, `745`, `753`, `1015`, `1129`, `1163`, `1235`, `1300–1301`, `1386–1390`, `1524`, `1551`, `1717`, `1747`; `policy.h:190` |
| `eras.utxo.pre-genesis`, `eras.utxo.post-genesis`, `eras.utxo.post-chronicle` | 42 | `interpreter.cpp:411–427`, `2269–2280`; `configscriptpolicy.cpp:65–154`; the sites named |

