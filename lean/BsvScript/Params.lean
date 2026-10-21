/-!
# BsvScript.Params

The parameters record: every value the interpreter reads, by kind, with its
default and its `[SRC]` (`docs/PARAMETERS.md`, #6; the census is the source of
this file and the two are changed together).

Design (`docs/DESIGN.md` §5.4): the semantics takes `EvalParams` (the flag word,
the five limits); a second, cited function derives an `EvalParams` from a node's
configuration, the heights and the consensus switch (`Params.derive`,
`BsvScript.Flags`, #13),
mirroring the reference's split between `make_verify_script_params`
(`interpreter.cpp:2282–2302`) and the flag derivation
(`verify_script_flags.cpp:11–81`, `policy.h:208–244`).

Every `[SRC]` below is bitcoin-sv v1.2.3 at `6504a3af` (`docs/PROVENANCE.md`).
-/

namespace BsvScript.Params

/-- The protocol era of a height (`src/protocol_era.h:28–34`). `Unknown = 0`
exists in the reference as the invalid value; it is not a constructor here
because no rule takes it (`GetProtocolEra` never returns it for a valid
configuration). -/
inductive Era where
  | preGenesis
  | postGenesis
  | postChronicle
  deriving DecidableEq, Repr

/-- The script verification flags, one field per bit of `src/script/script_flags.h:13–115`.
Bits 11, 12 and 17 are unassigned at the pin and have no field; `SCRIPT_FLAG_LAST`
(bit 22) is the bound, not a flag. Each field's kind (consensus by height,
policy, version-gated, era marker, never set) is `docs/PARAMETERS.md` §2. -/
structure Flags where
  /-- bit 0, `SCRIPT_VERIFY_P2SH` (:17): consensus by height (`p2shHeight`); effective for pre-Genesis UTXOs only. -/
  p2sh : Bool
  /-- bit 1, `SCRIPT_VERIFY_STRICTENC` (:23): consensus by height (`uahfHeight`); implied by `enableSighashForkid` (`interpreter.cpp:2315–2319`). -/
  strictEnc : Bool
  /-- bit 2, `SCRIPT_VERIFY_DERSIG` (:27): consensus by height (`BIP66Height`). -/
  derSig : Bool
  /-- bit 3, `SCRIPT_VERIFY_LOW_S` (:32): consensus by height (`daaHeight`), version-gated at `interpreter.cpp:285`. -/
  lowS : Bool
  /-- bit 4, `SCRIPT_VERIFY_NULLDUMMY` (:36): policy (the standard set only), version-gated at `:1666`. -/
  nullDummy : Bool
  /-- bit 5, `SCRIPT_VERIFY_SIGPUSHONLY` (:40): consensus by height (Genesis), gated by era and version at `:2321–2334`. -/
  sigPushOnly : Bool
  /-- bit 6, `SCRIPT_VERIFY_MINIMALDATA` (:49): policy, version-gated at `:433`. -/
  minimalData : Bool
  /-- bit 7, `SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_NOPS` (:59): policy. -/
  discourageUpgradableNops : Bool
  /-- bit 8, `SCRIPT_VERIFY_CLEANSTACK` (:68): policy, version-gated at `:2441`; requires `p2sh` (`:2435`). -/
  cleanStack : Bool
  /-- bit 9, `SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY` (:73): consensus by height (`BIP65Height`); live for pre-Genesis UTXOs only (`:520`). -/
  checkLockTimeVerify : Bool
  /-- bit 10, `SCRIPT_VERIFY_CHECKSEQUENCEVERIFY` (:78): consensus by height (`CSVHeight`); live for pre-Genesis UTXOs only (`:563`). -/
  checkSequenceVerify : Bool
  /-- bit 13, `SCRIPT_VERIFY_MINIMALIF` (:82): never set by the node at the pin; version-gated at `:801` where read. -/
  minimalIf : Bool
  /-- bit 14, `SCRIPT_VERIFY_NULLFAIL` (:86): consensus by height (`daaHeight`), version-gated at `:1493`, `:1643`. -/
  nullFail : Bool
  /-- bit 15, `SCRIPT_VERIFY_COMPRESSED_PUBKEYTYPE` (:90): never set by the node at the pin. -/
  compressedPubKeyType : Bool
  /-- bit 16, `SCRIPT_ENABLE_SIGHASH_FORKID` (:94): consensus by height (`uahfHeight`). -/
  enableSighashForkid : Bool
  /-- bit 18, `SCRIPT_GENESIS` (:98): era marker, the spending era. -/
  genesis : Bool
  /-- bit 19, `SCRIPT_UTXO_AFTER_GENESIS` (:103): era marker, the UTXO's creation era. -/
  utxoAfterGenesis : Bool
  /-- bit 20, `SCRIPT_CHRONICLE` (:107): era marker, the spending era; the version gate reads it (`interpreter.cpp:40–44`). -/
  chronicle : Bool
  /-- bit 21, `SCRIPT_UTXO_AFTER_CHRONICLE` (:111): era marker, the UTXO's creation era; requires `utxoAfterGenesis` (`valid_flags`, `interpreter.cpp:2259–2262`). -/
  utxoAfterChronicle : Bool
  deriving DecidableEq, Repr, Inhabited

/-- `valid_flags` (`interpreter.cpp:2259–2262`): `SCRIPT_UTXO_AFTER_CHRONICLE`
requires `SCRIPT_UTXO_AFTER_GENESIS`. -/
def Flags.valid (f : Flags) : Bool := !(f.utxoAfterChronicle && !f.utxoAfterGenesis)

/-- `utxo_era` (`interpreter.cpp:2269–2280`): the UTXO's era from the two markers,
under the precondition `valid`. -/
def Flags.utxoEra (f : Flags) : Era :=
  if f.utxoAfterChronicle then .postChronicle
  else if f.utxoAfterGenesis then .postGenesis
  else .preGenesis

/-- `IsMalleableTxnVersion` (`interpreter.cpp:34–38`): post-Chronicle, malleability is
permitted for a transaction version above 1. -/
def isMalleableTxnVersion (version : Int) : Bool := version > 1

/-- `EnforceNonMalleability` (`interpreter.cpp:40–44`): the one expression the seven
version-gated restrictions hang on (LOW_S `:285`, MINIMALDATA `:433`, MINIMALIF `:801`,
NULLFAIL `:1493`/`:1643`, NULLDUMMY `:1666`, SIGPUSHONLY `:2327`, CLEANSTACK `:2441`). -/
def enforceNonMalleability (f : Flags) (version : Int) : Bool :=
  !(f.chronicle && isMalleableTxnVersion version)

/-- The flag word the environment carries (#16, P3): the seven restrictions that
hang on `EnforceNonMalleability` (`interpreter.cpp:40–44`) are read at their sites as
`bit && gate` (MINIMALDATA `433`, MINIMALIF `801`, NULLFAIL `1493`/`1643`,
NULLDUMMY `1666`, LOW_S's high-S test `282–287`, SIGPUSHONLY under CHRONICLE
`2321–2334`, CLEANSTACK's stack-size test `2441–2445`), so the word may carry
them cleared when the gate is off and every site reads the same value. Two
sites read a bit ungated and keep reading the original word: LOW_S also selects
the strict DER shape (`275–280`, `Env.strictDer`) and CLEANSTACK also demands
P2SH (`2432–2435`, `verifyScript`). -/
def Flags.gate (f : Flags) (version : Int) : Flags :=
  if enforceNonMalleability f version then f
  else { f with minimalData := false, minimalIf := false, nullFail := false, nullDummy := false,
                lowS := false, sigPushOnly := false, cleanStack := false }

/-- STRICTENC from FORKID (`interpreter.cpp:2315–2319`): the word `VerifyScript` runs under. -/
def Flags.forkAdjust (f : Flags) : Flags :=
  if f.enableSighashForkid then { f with strictEnc := true } else f

/-- The strict DER shape is demanded (`275–277`): DERSIG, LOW_S or STRICTENC, ungated. -/
def Flags.strictDer (f : Flags) : Bool := f.derSig || f.lowS || f.strictEnc

/-- The P2SH stack copy is taken (`2354–2356`): P2SH for a pre-Genesis UTXO. -/
def Flags.p2shCopy (f : Flags) : Bool := f.p2sh && !f.utxoAfterGenesis

/-- CLEANSTACK without P2SH is an invalid word (`2432–2435`), ungated. -/
def Flags.cleanStackDemand (f : Flags) : Bool := f.cleanStack && !f.p2sh


-- The four `static_assert`s of `interpreter.cpp:46–49`, as decided facts
-- (`default : Flags` is every bit off; `Inhabited` is derived from `Bool`'s `false`).
example : enforceNonMalleability { (default : Flags) with chronicle := false } 1 = true := by decide
example : enforceNonMalleability { (default : Flags) with chronicle := false } 2 = true := by decide
example : enforceNonMalleability { (default : Flags) with chronicle := true } 1 = true := by decide
example : enforceNonMalleability { (default : Flags) with chronicle := true } 2 = false := by decide

/-- The five limits of `eval_script_params` / `verify_script_params`
(`interpreter.h:136–195`), as the interpreter reads them: already selected by the
UTXO era and the consensus switch (`docs/PARAMETERS.md` §1). -/
structure Limits where
  /-- `MaxOpsPerScript`: `interpreter.cpp:466–467`, `377–380`. -/
  maxOpsPerScript : Nat
  /-- `MaxScriptNumLength`: every number read, `script_num.cpp:62`; `OP_BIN2NUM`'s result, `interpreter.cpp:1789`. -/
  maxScriptNumLength : Nat
  /-- `MaxScriptSize`: `interpreter.cpp:429–430`. -/
  maxScriptSize : Nat
  /-- `MaxPubKeysPerMultiSig`: `OP_CHECKMULTISIG`. -/
  maxPubKeysPerMultiSig : Nat
  /-- `MaxStackMemoryUsage`: the combined budget of both stacks, `limitedstack.cpp:194–207`. -/
  maxStackMemoryUsage : Nat
  deriving DecidableEq, Repr

/-- What the semantics takes (`docs/DESIGN.md` §5.4): exactly what `EvalScript`
and `VerifyScript` read. The caller's `consensus` switch is NOT a field: nothing
in `interpreter.cpp:388–1833` or `2304–2451` reads it; it is an argument of the
derivation (`Params.derive`, #13/#20) that selected `limits`. -/
structure EvalParams where
  flags : Flags
  limits : Limits
  deriving Repr, DecidableEq

/-- `Consensus::Params` (`src/consensus/params.h:20–39`): the activation heights of
a chain, read by the block flags (`verify_script_flags.cpp:32–81`). Consensus by
height; a chain constant, never a node setting (`chainparams.cpp:1038–1076` for
mainnet). `genesisHeight`/`chronicleHeight` (`params.h:37–38`) are "the height of
the block where the new rules are active" (`params.h:33–36`); the node's
`ConfigScriptPolicy` copies them at start-up unless overridden
(`init.cpp:2609–2616`), which is why `NodeConfig` carries them a second time. -/
structure ChainParams where
  /-- `p2shHeight` (`params.h:39`): P2SH from this height (`verify_script_flags.cpp:39`). -/
  p2shHeight : Nat
  /-- `BIP66Height` (`params.h:26`): DERSIG from `height + 1` (`:43`). -/
  bip66Height : Nat
  /-- `BIP65Height` (`params.h:24`): CLTV from `height + 1` (`:47`). -/
  bip65Height : Nat
  /-- `CSVHeight` (`params.h:28`): CSV from `height + 1` (`:51`). -/
  csvHeight : Nat
  /-- `uahfHeight` (`params.h:30`): STRICTENC and FORKID from this height (`:55–59`). -/
  uahfHeight : Nat
  /-- `daaHeight` (`params.h:32`): LOW_S and NULLFAIL from this height (`:65–69`). -/
  daaHeight : Nat
  /-- `genesisHeight` (`params.h:37`). -/
  genesisHeight : Nat
  /-- `chronicleHeight` (`params.h:38`). -/
  chronicleHeight : Nat
  deriving DecidableEq, Repr

/-- Mainnet (`CMainParams`, `chainparams.cpp:1034–1076`): P2SH 173,805
(`P2SH_ACTIVATION_MAIN`, `:28`, `:1076`), BIP66 363,725 (`:1044`), BIP65 388,381
(`:1042`), CSV 419,328 (`:1046`), UAHF 478,558 (`:1065`), DAA 504,031 (`:1068`),
Genesis 620,538 (`GENESIS_ACTIVATION_MAIN`, `:18`, `:1071`), Chronicle 943,816
(`CHRONICLE_ACTIVATION_MAIN`, `:23`, `:1074`).
[LIT] https://protocol.bsvblockchain.org/specification/upgrade-history#timeline at v1.2.2 (the heights only; not its "fork by time" rows for UAHF, Nov 2017, May 2018 and Nov 2018, THEIRS T3).
[LIT] https://protocol.bsvblockchain.org/specification/upgrade-history#genesis-2020-02-04 at v1.2.2 (the Genesis height only).
[LIT] https://protocol.bsvblockchain.org/specification/upgrade-history#chronicle-2026-04-07 at v1.2.2 (the Chronicle height only). -/
def ChainParams.mainnet : ChainParams :=
  { p2shHeight := 173805, bip66Height := 363725, bip65Height := 388381, csvHeight := 419328,
    uahfHeight := 478558, daaHeight := 504031, genesisHeight := 620538, chronicleHeight := 943816 }

/-- A node's script configuration (`ConfigScriptPolicy`, `configscriptpolicy.h:25–92`)
with its chain (`Consensus::Params`): the values a node sets, from which
`EvalParams` is derived (`Params.derive`, `BsvScript.Flags`, #13). Zero means "the
consensus limit" for every `max*Policy` (`configscriptpolicy.cpp:164–308`) and is
resolved at derivation (`NodeConfig.normalize`), not here. -/
structure NodeConfig where
  /-- the chain's activation heights (`Consensus::Params`) -/
  chain : ChainParams
  maxOpsPerScriptPolicy : Nat
  maxScriptNumLengthPolicy : Nat
  maxScriptSizePolicy : Nat
  maxPubKeysPerMultiSigPolicy : Nat
  maxStackMemoryUsagePolicy : Nat
  /-- `maxstackmemoryusageconsensus`: consensus, node-configurable (`consensus.h:82`). -/
  maxStackMemoryUsageConsensus : Nat
  /-- `-maxtxsigopscountspolicy` (`policy.h:84–85`, `config.cpp:61`): the largest sigop count a transaction
  may carry to be relayed or mined after Genesis (`validation.cpp:1242–1245`, `bad-txns-too-many-sigops`);
  before Genesis the getter reads the constant `MAX_TX_SIGOPS_COUNT_POLICY_BEFORE_GENESIS` = 4,000 instead
  (`policy.h:81`, `config.cpp:2422–2430`); the setter maps 0 to `UINT32_MAX` and refuses a larger value
  (`config.cpp:2391–2415`), so the field holds the resolved setting: policy, transaction-level, read by
  `BsvScript.TxPolicy` (2026-09-27; the spec gap of `docs/records/20260926-231004-txroad-s3.md`). -/
  maxTxSigOpsCountPolicy : Nat
  /-- `-maxtxsizepolicy` (`policy.h:70`, `configscriptpolicy.cpp:57`): the largest serialized size a
  transaction may have to be relayed or mined after Genesis (`IsStandardTx`, `script/standard.cpp:445–449`,
  `tx-size`); before Genesis the getter reads the constant `MAX_TX_SIZE_POLICY_BEFORE_GENESIS` = 99,999
  instead (`policy.h:68`, `configscriptpolicy.cpp:397–413`); the setter maps 0 to the consensus size and
  refuses a value above it or below 99,999 (`configscriptpolicy.cpp:415–446`), so the field holds the
  resolved setting: policy, transaction-level, read by `BsvScript.TxPolicy`. -/
  maxTxSizePolicy : Nat
  /-- `-genesisactivationheight` (`init.cpp:2609–2612`): defaults to the chain's. -/
  genesisActivationHeight : Nat
  /-- `-chronicleactivationheight` (`init.cpp:2613–2616`): defaults to the chain's. -/
  chronicleActivationHeight : Nat
  /-- Standardness required: ONE field for TWO values the reference reads at different sites, a modelling choice
  of the spec. The mempool flag word reads the CHAIN's `RequireStandard()` (`validation.cpp:798`,
  `chainparams.h:86`), true on mainnet (`chainparams.cpp:1121`), false on stn, testnet and regtest (`:1271`,
  `:1416`, `:1527`); the standardness refusal reads the node's SETTING (`validation.cpp:1084`; before Genesis
  through `GetAcceptNonStandardOutput`, `configscriptpolicy.cpp:468–471`), which `-acceptnonstdtxn` sets,
  defaulting to the chain's value (`init.cpp:3158–3160`; the policy object's default `requireStandard = true`,
  `configscriptpolicy.cpp:61`). The spec reads this one field at both sites (`NodeConfig.flagWord`,
  `BsvScript.TxPolicy`), and GoBDK's flag word reads the setting (`core/txvalidator.cpp:673`,
  `NodeConfig.bdkCalculateFlags`). The two values differ only when the option is set against the chain's default:
  on mainnet the flag word's reading is the chain's `true` whatever the option says, so the field set `false`
  models such a node at the refusal, and at the flag word only while `promiscuousMempoolFlags` is `none` (the
  standard word either way, FORKID being mandatory). Policy: relay and mining, never block validity. -/
  requireStandard : Bool
  /-- `-promiscuousmempoolflags` (`init.cpp:2463–2466`, `config.cpp:2590–2599`): when set, the word REPLACES the
  mempool flag word, FORKID added (`verify_script_flags.cpp:19–26`), but only where the CHAIN does not require
  standardness: the switch is the chain's `RequireStandard()` (`validation.cpp:795–801`), not `-acceptnonstdtxn`,
  so a mainnet node never uses the option. The spec reads it where the one field `requireStandard` above is
  false: policy. `none` = not set. -/
  promiscuousMempoolFlags : Option Flags
  /-- `-acceptnonstdoutputs` (`init.cpp:3162–3163`; the policy object's default `acceptNonStandardOutput = true`,
  `configscriptpolicy.cpp:60`): "relay and mine transactions that create or consume non standard outputs after
  Genesis is activated" (`init.cpp:1080–1083`); read by `GetAcceptNonStandardOutput(era)`
  (`configscriptpolicy.cpp:468–471`, the setting after Genesis, `!requireStandard` before it) where a failed
  standardness test refuses (`validation.cpp:1080–1088`, `TxPolicy.standardnessEnforced`): policy. -/
  acceptNonStandardOutput : Bool := true
  /-- `-datacarrier` (`init.cpp:3196`; `DEFAULT_ACCEPT_DATACARRIER` = true, `script/standard.h:20`; the policy
  object's default at `configscriptpolicy.cpp:59`): a data carrier output (`OP_RETURN` before Genesis, `OP_FALSE
  OP_RETURN` in both eras, then pushes) is standard (`IsStandardOutput`, `script/standard.cpp:367–371`;
  `BsvScript.Standard`): policy. -/
  dataCarrier : Bool := true
  /-- `-datacarriersize` (`init.cpp:2532–2533`; `DEFAULT_DATA_CARRIER_SIZE` = `UINT32_MAX`, `script/standard.h:46`;
  `configscriptpolicy.cpp:58`): the largest total of data carrier scripts a standard transaction carries
  (`script/standard.cpp:487–491`, `datacarrier-size-exceeded`; `BsvScript.Standard`): policy. -/
  dataCarrierSize : Nat := 4294967295
  /-- `-permitbaremultisig` (`init.cpp:3194–3195`; `DEFAULT_PERMIT_BAREMULTISIG` = true, `script/standard.h:23`;
  `configscriptpolicy.cpp:62`): a bare multisig output is standard (`script/standard.cpp:478–480`, else
  `bare-multisig`; `BsvScript.Standard`): policy. -/
  permitBareMultisig : Bool := true
  deriving DecidableEq, Repr

/-- The spec's default spending height (`docs/DESIGN.md` §6, `docs/PARAMETERS.md` §3):
the mainnet tip read at the pin date (2026-09-22T15:48Z, a read) `[M]`; the evaluator
never reads a chain, so every default flag word derives from this constant. -/
def defaultSpendHeight : Nat := 967896

-- The consensus constants (`src/consensus/consensus.h`).
-- [LIT] https://protocol.bsvblockchain.org/specification/script#limits-by-era at v1.2.2 (the operation, multisig key, script size and script number length limits only; not its stack memory sentence, THEIRS T4).
-- [LIT] https://protocol.bsvblockchain.org/specification/transactions#size-limits-by-era at v1.2.2.
namespace Consensus
def maxOpsPerScriptBeforeGenesis : Nat := 500                 -- :40
def maxOpsPerScriptAfterGenesis : Nat := 4294967295           -- :43, UINT32_MAX
def maxPubKeysPerMultisigBeforeGenesis : Nat := 20            -- :50
def maxPubKeysPerMultisigAfterGenesis : Nat := 4294967295     -- :55
def maxScriptSizeBeforeGenesis : Nat := 10000                 -- :58
def maxScriptSizeAfterGenesis : Nat := 4294967295             -- :60
def maxScriptNumLengthBeforeGenesis : Nat := 4                -- :62
def maxScriptNumLengthAfterGenesis : Nat := 750000            -- :64, 750 * ONE_KILOBYTE (:13)
def maxScriptNumLengthAfterChronicle : Nat := 32000000        -- :66, 32 * ONE_MEGABYTE (:15)
def defaultStackMemoryUsageConsensusAfterGenesis : Nat := 9223372036854775807  -- :82, INT64_MAX
/-- `script.h:29`, pre-Genesis element size. -/
def maxScriptElementSizeBeforeGenesis : Nat := 520
/-- `script.h:32`, pre-Genesis stack elements. -/
def maxStackElementsBeforeGenesis : Nat := 1000
/-- `limitedstack.h:43`, the per-element overhead of the memory budget. -/
def elementOverhead : Nat := 32
/-- The UAHF height on mainnet, from which `SCRIPT_ENABLE_SIGHASH_FORKID` is in
the block flags (`chainparams.cpp:1065`; `verify_script_flags.cpp:54–58`). -/
def uahfHeight : Nat := 478558

end Consensus

/-- bitcoin-sv's default `ConfigScriptPolicy` on mainnet (`configscriptpolicy.cpp:43–63`
with `policy.h:93, 147, 150, 153, 156`, `consensus.h:82`, `chainparams.cpp:18, 23`,
`configscriptpolicy.cpp:61`; the two transaction-level caps `policy.h:85` through `config.cpp:61`
and `policy.h:70` through `configscriptpolicy.cpp:57`; `acceptnonstdoutputs` true, `configscriptpolicy.cpp:60`;
the data carrier on, its size `UINT32_MAX` and bare multisig permitted, `configscriptpolicy.cpp:58–59, 62` with
`script/standard.h:20, 46, 23`). The two defaults differ in seven fields, all policy: the ops policy, the
script size policy (since Teranode v0.16.0), the stack memory policy, the transaction size policy and
`requireStandard` (the census findings of `docs/PARAMETERS.md` §5), and `dataCarrier` and `dataCarrierSize`
(Teranode's values recorded at `NodeConfig.teranodeDefault`); they agree on every other field (the
`example` after `NodeConfig.teranodeDefault`). The witnesses of `docs/PARAMETERS.md` §7 exhibit the stack
memory policy, the transaction size policy and `requireStandard` (dust). -/
def NodeConfig.svMainnetDefault : NodeConfig :=
  { chain := ChainParams.mainnet
    maxOpsPerScriptPolicy := 4294967295
    maxScriptNumLengthPolicy := 10000
    maxScriptSizePolicy := 500000
    maxPubKeysPerMultiSigPolicy := 4294967295
    maxStackMemoryUsagePolicy := 100000000
    maxStackMemoryUsageConsensus := 9223372036854775807
    maxTxSigOpsCountPolicy := 4294967295
    maxTxSizePolicy := 10000000
    genesisActivationHeight := 620538
    chronicleActivationHeight := 943816
    requireStandard := true
    promiscuousMempoolFlags := none
    acceptNonStandardOutput := true
    dataCarrier := true
    dataCarrierSize := 4294967295
    permitBareMultisig := true }

/-- Teranode v0.16.0's defaults as passed to GoBDK, read at the tag
(`git show v0.16.0:settings/settings.go`, lines 108–125, the clone at commit `4edb60a`):
`maxscriptsizepolicy` 100,000,000 `:113`, a **policy** default (the consensus limit is
`UINT32_MAX`, `Consensus.maxScriptSizeAfterGenesis`; the struct tag's default reads the same,
`settings/policy_settings.go:9`; 500,000 at v0.15.9 `settings.go:102`, moved by #54),
`maxopsperscriptpolicy` 1,000,000 `:114`,
`maxscriptnumlengthpolicy` 10,000 `:115`, `maxpubkeyspermultisigpolicy` 0 `:116`,
`maxstackmemoryusagepolicy` 104,857,600 `:118`, `maxstackmemoryusageconsensus` 0 `:119`,
`requirestandard` false `:123`, `acceptnonstdoutputs` true `:122` (pushed at
`ScriptVerifierGoBDK.go:202`), `datacarrier` false `:124` (pushed at `:200`), `datacarriersize` 1,000,000 `:112`
(pushed at `:201`), `permitbaremultisig` true `:125` (pushed at `:204`); the `settings/policy_settings.go` struct
tags document these settings and `NewPolicySettings` (`:36–40`) sets none, `maxtxsizepolicy` 10,485,760 `:108`
(`SetMaxTxSizePolicy`, `ScriptVerifierGoBDK.go:171`), `maxtxsigopscountspolicy` 0 `:117`
(`SetMaxSigOpsPostGenesisPolicy`, `:175`; 0 → `UINT32_MAX` by BDK's setter, `core/txvalidator.cpp:537–551`
at GoBDK `4eab3acd`, mirroring `config.cpp:2406–2409`); pushed into GoBDK's own `ConfigScriptPolicy` by
`services/validator/ScriptVerifierGoBDK.go:147–243` through `bdk/core/txvalidator.cpp:372–520`,
so the zero rules are the reference's setters, `configscriptpolicy.cpp:164–308`:
`maxpubkeyspermultisigpolicy` 0 → UINT32_MAX, `maxstackmemoryusageconsensus` 0 → INT64_MAX;
the Genesis and Chronicle heights from go-chaincfg v1.6.2 `params.go:276–277` through
`ScriptVerifierGoBDK.go:158–165`; the other heights are the reference's `CChainParams`
compiled in, `ChainParams.mainnet`). `docs/PARAMETERS.md` §1–§4 (#6, completed at #21; re-cut at
Teranode v0.16.0 by #54). -/
def NodeConfig.teranodeDefault : NodeConfig :=
  { chain := ChainParams.mainnet
    maxOpsPerScriptPolicy := 1000000
    maxScriptNumLengthPolicy := 10000
    maxScriptSizePolicy := 100000000
    maxPubKeysPerMultiSigPolicy := 4294967295
    maxStackMemoryUsagePolicy := 104857600
    maxStackMemoryUsageConsensus := 9223372036854775807
    maxTxSigOpsCountPolicy := 4294967295
    maxTxSizePolicy := 10485760
    genesisActivationHeight := 620538
    chronicleActivationHeight := 943816
    requireStandard := false
    promiscuousMempoolFlags := none
    acceptNonStandardOutput := true
    dataCarrier := false
    dataCarrierSize := 1000000
    permitBareMultisig := true }

-- The two defaults differ in seven fields, all policy: the five of the census (`docs/PARAMETERS.md` §5:
-- the ops policy, the script size policy since Teranode v0.16.0, the stack memory policy, the transaction
-- size policy, `requireStandard`) and the data carrier's two (`dataCarrier`, `dataCarrierSize`); with those
-- seven set to bitcoin-sv's values Teranode's defaults are bitcoin-sv's, so they agree on every other field.
example : NodeConfig.svMainnetDefault ≠ NodeConfig.teranodeDefault := by decide
example : { NodeConfig.teranodeDefault with
              maxOpsPerScriptPolicy := 4294967295, maxScriptSizePolicy := 500000,
              maxStackMemoryUsagePolicy := 100000000, maxTxSizePolicy := 10000000,
              requireStandard := true, dataCarrier := true, dataCarrierSize := 4294967295 }
            = NodeConfig.svMainnetDefault := by decide
-- Teranode v0.16.0's script size policy default (`settings/settings.go:113`), a policy value,
-- differs from bitcoin-sv's 500,000 (`policy.h:93`); the consensus limit is `UINT32_MAX` in both.
example : NodeConfig.teranodeDefault.maxScriptSizePolicy = 100000000 := by decide
example : NodeConfig.svMainnetDefault.maxScriptSizePolicy ≠ NodeConfig.teranodeDefault.maxScriptSizePolicy := by decide
example : NodeConfig.svMainnetDefault.maxScriptNumLengthPolicy = NodeConfig.teranodeDefault.maxScriptNumLengthPolicy := by decide
example : NodeConfig.svMainnetDefault.genesisActivationHeight = NodeConfig.teranodeDefault.genesisActivationHeight := by decide
example : NodeConfig.svMainnetDefault.chronicleActivationHeight = NodeConfig.teranodeDefault.chronicleActivationHeight := by decide

end BsvScript.Params
