# The flags model

From `lean/BsvScript/Params.lean` (`Flags`, its fields) and `lean/BsvScript/Flags.lean` (`FlagBit`, `Params.derive`); the census is `docs/PARAMETERS.md` §2 and §6.

| field | the bit and its kind (from the field docstring) |
|---|---|
| `p2sh` | bit 0, `SCRIPT_VERIFY_P2SH` (:17): consensus by height (`p2shHeight`); effective for pre-Genesis UTXOs only. |
| `strictEnc` | bit 1, `SCRIPT_VERIFY_STRICTENC` (:23): consensus by height (`uahfHeight`); implied by `enableSighashForkid` (`interpreter.cpp:2315–2319`). |
| `derSig` | bit 2, `SCRIPT_VERIFY_DERSIG` (:27): consensus by height (`BIP66Height`). |
| `lowS` | bit 3, `SCRIPT_VERIFY_LOW_S` (:32): consensus by height (`daaHeight`), version-gated at `interpreter.cpp:285`. |
| `nullDummy` | bit 4, `SCRIPT_VERIFY_NULLDUMMY` (:36): policy (the standard set only), version-gated at `:1666`. |
| `sigPushOnly` | bit 5, `SCRIPT_VERIFY_SIGPUSHONLY` (:40): consensus by height (Genesis), gated by era and version at `:2321–2334`. |
| `minimalData` | bit 6, `SCRIPT_VERIFY_MINIMALDATA` (:49): policy, version-gated at `:433`. |
| `discourageUpgradableNops` | bit 7, `SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_NOPS` (:59): policy. |
| `cleanStack` | bit 8, `SCRIPT_VERIFY_CLEANSTACK` (:68): policy, version-gated at `:2441`; requires `p2sh` (`:2435`). |
| `checkLockTimeVerify` | bit 9, `SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY` (:73): consensus by height (`BIP65Height`); live for pre-Genesis UTXOs only (`:520`). |
| `checkSequenceVerify` | bit 10, `SCRIPT_VERIFY_CHECKSEQUENCEVERIFY` (:78): consensus by height (`CSVHeight`); live for pre-Genesis UTXOs only (`:563`). |
| `minimalIf` | bit 13, `SCRIPT_VERIFY_MINIMALIF` (:82): never set by the node at the pin; version-gated at `:801` where read. |
| `nullFail` | bit 14, `SCRIPT_VERIFY_NULLFAIL` (:86): consensus by height (`daaHeight`), version-gated at `:1493`, `:1643`. |
| `compressedPubKeyType` | bit 15, `SCRIPT_VERIFY_COMPRESSED_PUBKEYTYPE` (:90): never set by the node at the pin. |
| `enableSighashForkid` | bit 16, `SCRIPT_ENABLE_SIGHASH_FORKID` (:94): consensus by height (`uahfHeight`). |
| `genesis` | bit 18, `SCRIPT_GENESIS` (:98): era marker, the spending era. |
| `utxoAfterGenesis` | bit 19, `SCRIPT_UTXO_AFTER_GENESIS` (:103): era marker, the UTXO's creation era. |
| `chronicle` | bit 20, `SCRIPT_CHRONICLE` (:107): era marker, the spending era; the version gate reads it (`interpreter.cpp:40–44`). |
| `utxoAfterChronicle` | bit 21, `SCRIPT_UTXO_AFTER_CHRONICLE` (:111): era marker, the UTXO's creation era; requires `utxoAfterGenesis` (`valid_flags`, `interpreter.cpp:2259–2262`). |

### `Era.genesisActive` (def, `lean/BsvScript/Flags.lean:57`)

`IsProtocolActive(era, ProtocolName::Genesis)` (`protocol_era.cpp:91–94`):
`era >= PostGenesis`.

### `Era.chronicleActive` (def, `lean/BsvScript/Flags.lean:64`)

`IsProtocolActive(era, ProtocolName::Chronicle)` (`protocol_era.cpp:95–98`):
`era >= PostChronicle`.

### `protocolEraOf` (def, `lean/BsvScript/Flags.lean:71`)

`GetProtocolEra(genesis_activation_height, chronicle_activation_height, nHeight)`
(`protocol_era.cpp:21–39`): below the Genesis height pre-Genesis, below the
Chronicle height post-Genesis, else post-Chronicle. `MEMPOOL_HEIGHT`
(`protocol_era.h:14`) throws there (`protocol_era.cpp:25–30`) and is not a height here: the callers
substitute the next block's height first (`validation.cpp:2667–2674`,
`rpc/misc.cpp:803–808`), which is the corpus's convention (`docs/DESIGN.md` §6); the CLI's reader refuses
it and every height above it (`lean/Bsvs/Corpus.lean`, `mempoolHeight`; lean #32's second lens, B-2).
[LIT] https://protocol.bsvblockchain.org/specification/opcodes#protocol-eras at v1.2.2 (the heights only).

### `NodeConfig.protocolEra` (def, `lean/BsvScript/Flags.lean:84`)

`GetProtocolEra(const ConfigScriptPolicy&, nHeight)` (`protocol_era.cpp:42–47`):
the node's configured activation heights (`configscriptpolicy.cpp:156–162`).

### `Flags.none` (def, `lean/BsvScript/Flags.lean:99`)

`SCRIPT_VERIFY_NONE` (`script_flags.h:14`): every bit off.

### `Flags.union` (def, `lean/BsvScript/Flags.lean:107`)

The union of two words (`|=`).

### `mandatoryPreChronicle` (def, `lean/BsvScript/Flags.lean:129`)

`PRE_CHRONICLE_MANDATORY_SCRIPT_VERIFY_FLAGS` (`standard.h:55–60`): P2SH,
STRICTENC, `SCRIPT_ENABLE_SIGHASH_FORKID`, NULLFAIL, LOW_S: "mandatory script
verification flags that all new blocks must comply with" (`standard.h:48–54`).

### `mandatoryPostChronicle` (def, `lean/BsvScript/Flags.lean:135`)

`POST_CHRONICLE_MANDATORY_SCRIPT_VERIFY_FLAGS` (`standard.h:62–68`): the
pre-Chronicle set plus `SCRIPT_CHRONICLE`.

### `mandatoryFlags` (def, `lean/BsvScript/Flags.lean:139`)

`MandatoryScriptVerifyFlags(era)` (`standard.cpp:330–337`).

### `standardOnly` (def, `lean/BsvScript/Flags.lean:143`)

`STANDARD_SCRIPT_VERIFY_FLAGS` (`policy.h:182–189`): DERSIG, NULLDUMMY,
DISCOURAGE_UPGRADABLE_NOPS, CHECKLOCKTIMEVERIFY, CHECKSEQUENCEVERIFY, CLEANSTACK,
MINIMALDATA: "standard script verification flags that standard transactions will
comply with. However scripts violating these flags may still be present in valid
blocks and we must accept those blocks" (`policy.h:177–181`): the policy set.

### `standardScriptVerifyFlags` (def, `lean/BsvScript/Flags.lean:152`)

`StandardScriptVerifyFlags(era)` (`policy.h:208–222`): the era's mandatory set
with the standard set (`PRE_/POST_CHRONICLE_STANDARD_SCRIPT_VERIFY_FLAGS`,
`policy.h:191–197`), plus `SCRIPT_GENESIS` when Genesis is active (`policy.h:216–219`).

### `inputScriptVerifyFlags` (def, `lean/BsvScript/Flags.lean:159`)

`InputScriptVerifyFlags(era, utxoEra)` (`policy.h:225–244`): SIGPUSHONLY when
Genesis is active in the spending era (`policy.h:229–232`); `SCRIPT_UTXO_AFTER_GENESIS` /
`SCRIPT_UTXO_AFTER_CHRONICLE` when Genesis / Chronicle is active in the UTXO's era
(`policy.h:234–241`).

### `blockScriptFlags` (def, `lean/BsvScript/Flags.lean:167`)

`GetBlockScriptFlags(consensus_params, height, protocol_era)`
(`verify_script_flags.cpp:32–81`): P2SH from `p2shHeight` (`:39`); DERSIG, CLTV and
CSV from `height + 1` against `BIP66Height`, `BIP65Height`, `CSVHeight`
(`:43`, `:47`, `:51`); STRICTENC and FORKID from `uahfHeight` (`:55–59`); LOW_S and
NULLFAIL from `daaHeight` (`:65–69`); `SCRIPT_GENESIS` and SIGPUSHONLY when Genesis
is active in the era (`:71–75`); `SCRIPT_CHRONICLE` when Chronicle is (`:77–78`).
`height` is the chain tip's (the block being validated is `height + 1`,
`validation.cpp:2972–2981`, `validation.cpp:3472`).

### `mempoolScriptFlags` (def, `lean/BsvScript/Flags.lean:189`)

`GetScriptVerifyFlags(era, require_standard, is_prom_mempool_flags, prom_mempool_flags)`
(`verify_script_flags.cpp:11–30`): the era's standard word (`:18`); when
standardness is not required, `-promiscuousmempoolflags` REPLACES the word when
set (`:21–24`) and FORKID is added (`:25`).

### `uint32Max` (def, `lean/BsvScript/Flags.lean:200`)

`UINT32_MAX` and `INT64_MAX`, as the consensus constants spell them
(`consensus.h:43, 55, 60`, `:82`).

### `NodeConfig.normalize` (def, `lean/BsvScript/Flags.lean:205`)

The configuration as the setters leave it (`configscriptpolicy.cpp:164–308`):
a configured zero is the consensus limit for `MaxOpsPerScript` (`:180–183`),
`MaxScriptSize` (`:231–233`) and `MaxPubKeysPerMultiSig` (`:257–260`), and
`INT64_MAX` for both stack-memory values (`:280–283`, `:289–292`);
`MaxScriptNumLength`'s zero is kept and resolved by its getter (`:209–211`,
`:97–106`). What the setters refuse (a value above the consensus limit, a number
length below 4, a policy stack budget above the consensus one) is a start-up error
in the reference and a precondition here, not a rule.

### `consensusMaxScriptNumLength` (def, `lean/BsvScript/Flags.lean:221`)

`GetMaxScriptNumLength`'s consensus value for an era (`configscriptpolicy.cpp:88–95`,
also the zero-policy fallback `:97–106`): 750,000 post-Genesis, 32,000,000
post-Chronicle.

### `NodeConfig.limitsFor` (def, `lean/BsvScript/Flags.lean:227`)

`make_verify_script_params(policySettings, flags, consensus)` (`2295–2302`) over
`make_eval_script_params` (`2282–2293`): the UTXO era from the word (`utxo_era`,
`2269–2280`), then the five getters (`configscriptpolicy.cpp`): `GetMaxOpsPerScript`
(`65–77`), `GetMaxScriptNumLength` (`79–110`), `GetMaxScriptSize` (`112–122`),
`GetMaxPubKeysPerMultiSig` (`124–137`), `GetMaxStackMemoryUsage` (`139–154`). Each
is the pre-Genesis value for a pre-Genesis UTXO (`INT64_MAX` for the stack memory,
`:143–146`), else the node's policy value without `consensus`; under `consensus`
four are consensus constants and the stack memory is NOT one: `GetMaxStackMemoryUsage`
returns the operator's configured `maxStackMemoryUsageConsensus` (`:148–151`), set
from `-maxstackmemoryusageconsensus` (`src/init.cpp:2618–2621`, a required
parameter by its help text `src/init.cpp:1097–1101`; 0 → `INT64_MAX`, `configscriptpolicy.cpp:280–283`
with `src/consensus/consensus.h:82`), so two nodes configured apart can disagree on a
block (consensus, node-configurable: `docs/PARAMETERS.md` §1). The configuration is
taken as the setters leave it (`NodeConfig.normalize`).

### `NodeConfig.flagWord` (def, `lean/BsvScript/Flags.lean:268`)

The flag word of one input (`CheckInputScripts`, `validation.cpp:2676–2710`):
the caller's word, which is the block word at `spendHeight − 1` with the era of
`spendHeight` under `consensus` (`validation.cpp:3472`, `validation.cpp:2972–2981`; BDK `core/txvalidator.cpp:663–668`)
or the mempool word of the era of `spendHeight` otherwise (`validation.cpp:1031`, `validation.cpp:795–801`;
BDK `core/txvalidator.cpp:669–674`), united with the per-input word of the spend era and the UTXO's
era (`validation.cpp:2694–2696`; BDK `core/txvalidator.cpp:677–678`). `spendHeight` is the height of the block the spend
is in (on the mempool path the tip plus one, `validation.cpp:2857`, `validation.cpp:2544–2548`); `utxoHeight` is the
height of the block that created the output (`validation.cpp:2693`, `validation.cpp:2667–2674`).

### `derive` (def, `lean/BsvScript/Flags.lean:284`)

**`Params.derive`** (DESIGN §5.4, the signature frozen there): the `EvalParams`
one input of a spend at `spendHeight` of an output created at `utxoHeight` is
verified under by a node configured `cfg`, on the block path (`consensus = true`)
or the mempool path. The word is `flagWord`; the limits are
`make_verify_script_params` on that word (`2701`; BDK `787`). The `consensus`
switch selects the path and the limits and is not in the result (nothing in
`388–1833` or `2304–2451` reads it).

### `preGenesisLimits` (def, `lean/BsvScript/Flags.lean:298`)

The pre-Genesis limits (`docs/PARAMETERS.md` §1, the first column; the getters'
`!utxo_after_genesis` branches, `configscriptpolicy.cpp:65–154`): 500 ops
(`consensus.h:40`), 4-byte numbers (`consensus.h:62`), 10,000-byte scripts (`consensus.h:58`), 20 keys
(`consensus.h:50`), and an unbounded memory budget (`INT64_MAX`, `configscriptpolicy.cpp:143–146`: the 520-byte
element and 1,000-element limits apply instead, `script.h:29, 32`). They are the
coin's, whatever the path: a pre-Genesis output spent today runs under them (#20).

### `eraConsensusLimits` (def, `lean/BsvScript/Flags.lean:311`)

The post-Genesis consensus limits of a coin's era (the second column; the getters'
`consensus` branches): unbounded ops, script size and keys (`consensus.h:43, 60, 55`),
the era's number width (750,000 post-Genesis, 32,000,000 post-Chronicle, `consensus.h:64`, `consensus.h:66`),
and the node's `maxstackmemoryusageconsensus` as the setter leaves it (`INT64_MAX` by
default, `consensus.h:82`; consensus, node-configurable).

### `mempoolHeight` (def, `lean/BsvScript/Flags.lean:325`)

`MEMPOOL_HEIGHT` (`protocol_era.h:14`): the fake height (`0x7FFFFFFF`) a coin created
by an unconfirmed transaction carries in the coins view. `GetProtocolEra` throws on it
(`protocol_era.cpp:25–30`), so every caller substitutes a real height first
(`inputScriptBlockHeight`). Not a corpus value (`docs/DESIGN.md` §6: a prevout height is
required; BDK refuses it in consensus mode, `core/txvalidator.cpp:903–904`).

### `inputScriptBlockHeight` (def, `lean/BsvScript/Flags.lean:332`)

`GetInputScriptBlockHeight(coinHeight)` (`validation.cpp:2667–2674`): "when spending
an output that was created in mempool, we assume that it will be mined in the next
block", `chainActive.Height() + 1`; any other coin keeps its height. The same substitution
is BDK's `resolveUtxoEraHeight(utxoHeight, nextBlockHeight)` (`core/txvalidator.cpp:267–269`,
the next block's height passed in at `core/txvalidator.cpp:677`) and the `verifyscript` RPC's
(`rpc/misc.cpp:803–809`, `tip + 1`). `tip` is the chain tip's height, so the substituted
height is the spend height of the mempool path (`validation.cpp:2545–2548`, `validation.cpp:2857`).

### `NodeConfig.bdkCalculateFlags` (def, `lean/BsvScript/Flags.lean:342`)

Teranode's engine computes the word of one input in
`CalculateFlags(utxoHeight, blockHeight, consensus)` (BDK `core/txvalidator.cpp:659–681`,
the reference's own functions compiled in; `docs/PARAMETERS.md` §2), under its height
convention: in consensus mode `blockHeight` is the height of the block the transaction
belongs to, the era is that height's and the block word is
`GetBlockScriptFlags(params, blockHeight − 1, era)` (`core/txvalidator.cpp:663–668`: "the chainTip is
blockHeight−1"); in policy mode `blockHeight` is the chain tip, the era is that of
`blockHeight + 1` and the word is `GetScriptVerifyFlags(era, requireStandard)` (`core/txvalidator.cpp:669–674`;
no promiscuous word exists on this side); the UTXO's era is that of
`resolveUtxoEraHeight(utxoHeight, blockHeight + 1)` (`core/txvalidator.cpp:677`, `core/txvalidator.cpp:267–269`); the per-input word
is OR-ed on (`core/txvalidator.cpp:678–680`). `bdkCalculateFlags_consensus`/`_policy`
(`Properties/Eras.lean`) show it is `flagWord` under the corpus convention of
`docs/DESIGN.md` §6. A mempool coin in consensus mode is refused before it runs (`core/txvalidator.cpp:903–904`).

### `FlagKind` (inductive, `lean/BsvScript/Flags.lean:365`)

The kinds of `docs/PARAMETERS.md` (the census, #6).

### `FlagBit` (inductive, `lean/BsvScript/Flags.lean:377`)

The nineteen flags of `script_flags.h:13–115`.

### `bit` (def, `lean/BsvScript/Flags.lean:391`)

The bit position (`script_flags.h:17–111`).

### `name` (def, `lean/BsvScript/Flags.lean:398`)

The enum identifier (`script_flags.h`).

### `testName` (def, `lean/BsvScript/Flags.lean:409`)

The name the reference's flag parsers accept (`rpc/misc.cpp:1281–1302`,
`src/test/scriptflags.cpp:17–38`, the same map).

### `kind` (def, `lean/BsvScript/Flags.lean:419`)

The kind of each flag (`docs/PARAMETERS.md` §2, each cell `[SRC]`).

### `gateSites` (def, `lean/BsvScript/Flags.lean:441`)

The seven restrictions that hang on `EnforceNonMalleability` (`40–44`), with
their gate sites (`docs/DESIGN.md` §5.3): LOW_S `285`, MINIMALDATA `433`,
MINIMALIF `801`, NULLFAIL `1493`/`1643`, NULLDUMMY `1666`, SIGPUSHONLY `2327`,
CLEANSTACK `2441`.

### `get` (def, `lean/BsvScript/Flags.lean:452`)

Read a bit of a word.

### `set` (def, `lean/BsvScript/Flags.lean:462`)

Set a bit of a word.

### `ofFlags` (def, `lean/BsvScript/Flags.lean:478`)

The set bits of a word, in bit order.

### `ofTestName` (def, `lean/BsvScript/Flags.lean:481`)

The test-map name lookup (`ParseScriptFlags`).

### `bitOf` (def, `lean/BsvScript/Flags.lean:488`)

One bit of a word: `2^k` when set.

### `Flags.toWord` (def, `lean/BsvScript/Flags.lean:491`)

The `uint32_t` the reference passes around (`VerifyScript`'s `flags`, the
`verifyscript` RPC's `flags`, the corpus's explicit `flags` per input).

### `Flags.ofWord` (def, `lean/BsvScript/Flags.lean:501`)

The word read back; the unassigned bits 11, 12, 17 and everything from 22 up are
ignored, as the interpreter ignores them (it tests named bits only,
`script_flags.h:117–171`).

### `testBit_bitOf` (theorem, `lean/BsvScript/Flags.lean:512`)

A one-bit word read back: bit `i` of `bitOf b k` is `b` at `i = k` and clear elsewhere; the step
`Flags.ofWord_toWord` (T-F1, below) reads each named bit of the word with.

### `Flags.ofWord_toWord` (theorem, `lean/BsvScript/Flags.lean:517`)

**T-F1.** *What it says:* the word encodes the record faithfully: reading the
word back gives the record. *Why it matters:* the CLI's `--flags <u32>` and the
corpus's explicit `flags` are the interpreter's own `uint32_t`, so the JSON
echo (`Flags.toWord`) is the word the interpreter runs. The RPC's `reportflags`
(`rpc/misc.cpp:540–541`, `rpc/misc.cpp:908–911`) echoes `(int)scr.flags` after re-deriving
the two UTXO bits from `txo.height` when one is given (`rpc/misc.cpp:803–823`), and keeps bits
`toWord` has no name for (lean #32's second lens, B-9; the file on every line, its fourth
re-lens, B4N-1).

### `Flags.toWord_ofWord` (theorem, `lean/BsvScript/Flags.lean:530`)

**T-F2.** The bits the record does not name are the only information a
`uint32_t` can lose: a word below `SCRIPT_FLAG_LAST` (`2^22`, `script_flags.h:114`)
with bits 11, 12 and 17 clear round-trips.

### `blockScriptFlags_policy_off` (theorem, `lean/BsvScript/Flags.lean:551`)

**The block word never carries a policy flag** (constitution 01 at the flag
level; `policy.h:177–181`: "scripts violating these flags may still be present in
valid blocks and we must accept those blocks"; `script_flags.h:56–57`). *What it
says:* for every chain, every height and every era, the four flags the census
classes as policy (NULLDUMMY, MINIMALDATA, DISCOURAGE_UPGRADABLE_NOPS, CLEANSTACK)
are off in `GetBlockScriptFlags`'s word. *Why it matters:* it is the theorem behind
the sentence "policy never decides block validity", read off the derivation.

### `flagWord_neverSet_off` (theorem, `lean/BsvScript/Flags.lean:562`)

The never-set flags are never set by either derivation (without promiscuous flags): the node's own words
never carry MINIMALIF or COMPRESSED_PUBKEYTYPE. They reach the interpreter in an explicit word, the `verifyscript`
RPC's integer `flags` (`rpc/misc.cpp:697–702`), and, on a chain whose `RequireStandard()` is false (stn, testnet,
regtest: `chainparams.cpp:1271`, `:1416`, `:1527`), in a `-promiscuousmempoolflags` word (any non-negative integer,
`config.cpp:2584–2590`, made the mempool word at `verify_script_flags.cpp:23`): the route the hypothesis `hp`
excludes. `sendrawtransactions`' `skipscriptflags` only clears flags, and it refuses both of these
(`rpc/rawtransaction.cpp:1486`, `:1501–1506`).

### `flagWord_valid` (theorem, `lean/BsvScript/Flags.lean:578`)

**The derived word is `valid_flags` on a node with no promiscuous word** (`2259–2262`; the hypothesis
`hp`, the exceptions below): the UTXO's
Chronicle marker implies its Genesis marker because Chronicle activity implies
Genesis activity (`protocol_era.cpp:89–103` on the ordered enum
`protocol_era.h:28–34`). So the derived word passes `valid_flags` (`interpreter.cpp:2312–2313`), and with
`flagWord_cleanStackDemand` (the error's other source, CLEANSTACK without P2SH, never in a derived word)
`SCRIPT_ERR_INVALID_FLAGS` is unreachable from a node's own derivation. The exceptions are configurations, and
none exists on mainnet. A
`-promiscuousmempoolflags` word reaches the interpreter only on a chain whose `RequireStandard()` is false
(`validation.cpp:795–801` passes the chain's value, true on mainnet, `chainparams.cpp:1121`; `-acceptnonstdtxn`
sets another value, `init.cpp:3158–3160`). There it replaces the mempool word and gains FORKID
(`verify_script_flags.cpp:21–25`), passes the skip mask (`validation.cpp:1330`) and is OR-ed with the per-input
word (`validation.cpp:2701`). A word carrying `SCRIPT_UTXO_AFTER_CHRONICLE` without `SCRIPT_UTXO_AFTER_GENESIS`
then fails every pre-Genesis input of that node with `SCRIPT_ERR_INVALID_FLAGS` (`interpreter.cpp:2312–2313`), and a
word carrying CLEANSTACK without P2SH fails every input that otherwise passes the same way
(`interpreter.cpp:2430–2436`): policy settings, and misconfigurations, never a consensus fact.

### `flagWord_cleanStackDemand` (theorem, `lean/BsvScript/Flags.lean:601`)

**CLEANSTACK without P2SH is in no derived word** (`interpreter.cpp:2430–2436`, the second source of
`SCRIPT_ERR_INVALID_FLAGS`): the block word never carries CLEANSTACK (`blockScriptFlags_policy_off`) and every
standard word carries P2SH (mandatory in both eras, `standard.h:56`, `:63`), so `VerifyScript`'s demand
(`Flags.cleanStackDemand`) is off on both paths. Without promiscuous flags, as `flagWord_valid`.

### `flagWord_utxoEra` (theorem, `lean/BsvScript/Flags.lean:612`)

The UTXO era the interpreter reads back (`utxo_era`, `2269–2280`) is the era of
the UTXO's height (without promiscuous flags, as above).

### `flagWord_block_valid` (theorem, `lean/BsvScript/Flags.lean:621`)

The block path never reads the promiscuous word: the block word is valid unconditionally (the twin of
`flagWord_valid` without its hypothesis; that it carries the UTXO's era unconditionally is
`Properties.flagWord_block_utxoEra`).

### `derive_consensus_separation` (theorem, `lean/BsvScript/Flags.lean:629`)

**P5, parameter separation** (`docs/DESIGN.md` §9; constitution 01). *What it
says:* on the block path (`consensus = true`) `Params.derive` reads only the
consensus fields of a node's configuration: its chain, its two activation heights
and `maxstackmemoryusageconsensus`; two nodes that agree on those verify every
input under the same `EvalParams`, whatever their policy settings
(`maxopsperscriptpolicy`, `maxscriptnumlengthpolicy`, `maxscriptsizepolicy`,
`maxpubkeyspermultisigpolicy`, `maxstackmemoryusagepolicy`, `acceptnonstdtxn`,
`-promiscuousmempoolflags`). *What it assumes:* nothing. *Why it matters:* it is
the machine-checked form of "a policy limit never decides block validity"; a
Teranode and an SV-node with their different policy defaults (`docs/PARAMETERS.md`
§5) derive the same block parameters (the example below).

### `verifyScript_consensus_separation` (theorem, `lean/BsvScript/Flags.lean:649`)

The verdict-level corollary of P5: the block verdict of a spend is the same
under any two nodes that agree on the consensus fields.

### `mainnetBlockWord` (def, `lean/BsvScript/Flags.lean:677`)

The block word of a post-Chronicle spend of a post-Chronicle output on mainnet
(every activation passed): P2SH · STRICTENC · DERSIG · LOW_S · SIGPUSHONLY · CLTV ·
CSV · NULLFAIL · FORKID · GENESIS · UTXO_AFTER_GENESIS · CHRONICLE ·
UTXO_AFTER_CHRONICLE = `0x3D462F`.

### `mainnetRelayWord` (def, `lean/BsvScript/Flags.lean:687`)

The mempool (relay) word of the same spend under `requireStandard`: the block
word plus NULLDUMMY · MINIMALDATA · DISCOURAGE_UPGRADABLE_NOPS · CLEANSTACK =
`0x3D47FF`. This is the word every corpus leg so far ran under (`Test/Common.lean`
`relayFlags`, hand-written at #8); `Test/FlagsCheck.lean` decides that the two agree.

### `Flags.gate_off_of_chronicle` (theorem, `lean/BsvScript/Flags.lean:723`)

With `SCRIPT_CHRONICLE` set and a version above 1 the gate is off (`40–44`) and
`Flags.gate` clears the seven restrictions.

### `flagWord_mempool_eq_block_mainnet` (theorem, `lean/BsvScript/Flags.lean:730`)

**The relay word and the block word on mainnet today differ in exactly the
four standard-only bits.** *What it says:* for a spend at or after the Chronicle
height on mainnet, under `requireStandard` (`hstd`), the mempool word is the block word plus NULLDUMMY,
DISCOURAGE_UPGRADABLE_NOPS, CLEANSTACK and MINIMALDATA. *What it assumes:* the mainnet chain and heights and `hstd`;
no promiscuous word is assumed or needed, since under `requireStandard` it is never read (`mempoolScriptFlags`,
`verify_script_flags.cpp:19–26`). At the pin the switch the word reads is the chain's `RequireStandard()`
(`validation.cpp:798`), true on mainnet (`chainparams.cpp:1121`) whatever `-acceptnonstdtxn` says (that option sets
another value, `init.cpp:3158–3160`), so on mainnet `hstd` describes every node. The word is the one a transaction
submitted without `skipscriptflags` runs under; that option can clear DERSIG, MINIMALDATA, NULLDUMMY,
DISCOURAGE_UPGRADABLE_NOPS or CLEANSTACK from it (`validation.cpp:1330`, `rpc/rawtransaction.cpp:1483–1510`).
*Why it matters:* three of the four hang on the version gate; the theorem after this one draws the consequence.

### `verifyScript_relay_block_version2` (theorem, `lean/BsvScript/Flags.lean:759`)

**Relay versus block for a version-2 spend post-Chronicle (the CLAUDE.md
gotcha, for derived words).** *What it says:* on mainnet today, a version-2
spend verified under the relay word is judged exactly as under the block word
with DISCOURAGE_UPGRADABLE_NOPS added, whatever the limits: NULLDUMMY,
CLEANSTACK and MINIMALDATA are cleared by the version gate
(`EnforceNonMalleability`, `40–44`, at `1666`, `2441`, `433`) and only the
ungated policy bit survives. *What it assumes:* the mainnet chain and heights,
`requireStandard` (`hstd`: at the pin the chain's switch, true on mainnet, as `flagWord_mempool_eq_block_mainnet`
says), a spend height at or past Chronicle, a version above 1; the limits are a free parameter (they differ
between the paths and are not the subject). *Why it matters:* the seven-restriction
divergence the predecessor read from source (at its commit `c59f47a`) is here a theorem
about what a relaying node and a mining node do to the same version-2 spend: they
differ only on executed upgradable NOPs and on the resource limits, for a transaction submitted without
`skipscriptflags`, which can clear DERSIG (consensus by height), MINIMALDATA, NULLDUMMY,
DISCOURAGE_UPGRADABLE_NOPS or CLEANSTACK from the relay word (`validation.cpp:1330`, `rpc/rawtransaction.cpp:1486`).

