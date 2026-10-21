import BsvScript.Params
import BsvScript.Eval
import BsvScript.Properties.Basic
/-!
# BsvScript.Flags

The flags model (#13; `docs/DESIGN.md` §5.2–§5.4, `docs/PARAMETERS.md` §2–§3):
how the reference builds the flag word and the limits one input is verified
under, transcribed from the pin, and what the derivation proves.

* the protocol eras: `GetProtocolEra` (`src/protocol_era.cpp:21–39`) and
  `IsProtocolActive` (`89–103`);
* the flag sets: the mandatory sets (`src/script/standard.h:55–68`,
  `standard.cpp:330–337`), the standard set (`src/policy/policy.h:175–222`), the
  per-input set (`policy.h:225–244`);
* the block word by height (`src/verify_script_flags.cpp:32–81`) and the mempool
  word (`11–30`);
* where the reference calls them: `CheckInputScripts` (`src/validation.cpp:2676–2710`:
  the era of the spend height, the UTXO's era from the coin's height, the union of
  the caller's word and the per-input word at `2697–2702`); the block path
  (`3473` → `GetBlockScriptFlags(config, tip)` `2973–2982`: the height is the tip's
  = the block's height − 1, the era is that of `tip + 1` = the block's height);
  the mempool path (`1032`: the era of `tip + 1`; `1329` → `GetScriptVerifyFlags(config, era)`
  `796–802`; the spend height is `tip + 1`, `2858` with `2545–2549`); Teranode's engine
  does the same in BDK `core/txvalidator.cpp:659–681` (`CalculateFlags`: consensus mode
  = the block flags at `blockHeight − 1` with the era of `blockHeight`; policy mode =
  the mempool flags with the era of `blockHeight + 1`, `blockHeight` being the tip);
* the limits: `make_verify_script_params` (`src/script/interpreter.cpp:2282–2302`) over
  the getters (`src/configscriptpolicy.cpp:65–154`) and the setters' zero rules
  (`164–308`);
* `Params.derive` = all of the above (DESIGN §5.4, its signature frozen there); the
  version gate `enforceNonMalleability` (`Params.lean`, `interpreter.cpp:40–44`) is
  applied by the machine at its eight READ sites (seven `EnforceNonMalleability` calls
  plus the inlined `IsMalleableTxnVersion` read of SIGPUSHONLY at `2321–2334`; #19's
  Correction on #2) and is not part of the word;
* every flag as a `FlagBit` with its kind (`docs/PARAMETERS.md` §2), its gate site
  and its bit; the 32-bit word of `script_flags.h:13–115` both ways;
* the theorems: **P5** (parameter separation: block validation reads only the
  consensus fields of a node's configuration), the block word never carries a policy
  flag, the derived word is `valid_flags` on a node with no `-promiscuousmempoolflags`
  word (`flagWord_valid`'s hypothesis `hp`: such a word REPLACES the mempool word,
  `verify_script_flags.cpp:19–25`, and is read only where the chain's `RequireStandard()`
  is false, `validation.cpp:795–801`: stn, testnet and regtest, `chainparams.cpp:1271`,
  `:1416`, `:1527`, never mainnet, `:1121`; a promiscuous word can fail it), and the relay-versus-block
  difference for a version-2 spend post-Chronicle on mainnet is exactly
  `SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_NOPS` (the CLAUDE.md gotcha, for derived words).

Every `[SRC]` that names no other source is bitcoin-sv v1.2.3 at `6504a3af`
(`docs/PROVENANCE.md`); GoBDK's lines are its pin's (`4eab3acd`); a bare number is a
line of `src/script/interpreter.cpp`.
-/

namespace BsvScript.Params

/-! ## The eras (`src/protocol_era.cpp`) -/

/-- `IsProtocolActive(era, ProtocolName::Genesis)` (`protocol_era.cpp:91–94`):
`era >= PostGenesis`. -/
def Era.genesisActive : Era → Bool
  | .preGenesis => false
  | .postGenesis => true
  | .postChronicle => true

/-- `IsProtocolActive(era, ProtocolName::Chronicle)` (`protocol_era.cpp:95–98`):
`era >= PostChronicle`. -/
def Era.chronicleActive : Era → Bool
  | .preGenesis => false
  | .postGenesis => false
  | .postChronicle => true

/-- `GetProtocolEra(genesis_activation_height, chronicle_activation_height, nHeight)`
(`protocol_era.cpp:21–39`): below the Genesis height pre-Genesis, below the
Chronicle height post-Genesis, else post-Chronicle. `MEMPOOL_HEIGHT`
(`protocol_era.h:14`) throws there (`protocol_era.cpp:25–30`) and is not a height here: the callers
substitute the next block's height first (`validation.cpp:2667–2674`,
`rpc/misc.cpp:803–808`), which is the corpus's convention (`docs/DESIGN.md` §6); the CLI's reader refuses
it and every height above it (`lean/Bsvs/Corpus.lean`, `mempoolHeight`; lean #32's second lens, B-2).
[LIT] https://protocol.bsvblockchain.org/specification/opcodes#protocol-eras at v1.2.2 (the heights only). -/
def protocolEraOf (genesisHeight chronicleHeight height : Nat) : Era :=
  if height < genesisHeight then .preGenesis
  else if height < chronicleHeight then .postGenesis
  else .postChronicle

/-- `GetProtocolEra(const ConfigScriptPolicy&, nHeight)` (`protocol_era.cpp:42–47`):
the node's configured activation heights (`configscriptpolicy.cpp:156–162`). -/
def NodeConfig.protocolEra (cfg : NodeConfig) (height : Nat) : Era :=
  protocolEraOf cfg.genesisActivationHeight cfg.chronicleActivationHeight height

-- The mainnet boundaries, decided (`chainparams.cpp:18, 23`: "the height of the
-- block where the new rules are active", `consensus/params.h:33–36`).
example : NodeConfig.svMainnetDefault.protocolEra 620537 = .preGenesis := by decide
example : NodeConfig.svMainnetDefault.protocolEra 620538 = .postGenesis := by decide
example : NodeConfig.svMainnetDefault.protocolEra 943815 = .postGenesis := by decide
example : NodeConfig.svMainnetDefault.protocolEra 943816 = .postChronicle := by decide
example : NodeConfig.svMainnetDefault.protocolEra defaultSpendHeight = .postChronicle := by decide

/-! ## The flag sets -/

/-- `SCRIPT_VERIFY_NONE` (`script_flags.h:14`): every bit off. -/
def Flags.none : Flags :=
  { p2sh := false, strictEnc := false, derSig := false, lowS := false, nullDummy := false,
    sigPushOnly := false, minimalData := false, discourageUpgradableNops := false, cleanStack := false,
    checkLockTimeVerify := false, checkSequenceVerify := false, minimalIf := false, nullFail := false,
    compressedPubKeyType := false, enableSighashForkid := false, genesis := false,
    utxoAfterGenesis := false, chronicle := false, utxoAfterChronicle := false }

/-- The union of two words (`|=`). -/
def Flags.union (a b : Flags) : Flags :=
  { p2sh := a.p2sh || b.p2sh
    strictEnc := a.strictEnc || b.strictEnc
    derSig := a.derSig || b.derSig
    lowS := a.lowS || b.lowS
    nullDummy := a.nullDummy || b.nullDummy
    sigPushOnly := a.sigPushOnly || b.sigPushOnly
    minimalData := a.minimalData || b.minimalData
    discourageUpgradableNops := a.discourageUpgradableNops || b.discourageUpgradableNops
    cleanStack := a.cleanStack || b.cleanStack
    checkLockTimeVerify := a.checkLockTimeVerify || b.checkLockTimeVerify
    checkSequenceVerify := a.checkSequenceVerify || b.checkSequenceVerify
    minimalIf := a.minimalIf || b.minimalIf
    nullFail := a.nullFail || b.nullFail
    compressedPubKeyType := a.compressedPubKeyType || b.compressedPubKeyType
    enableSighashForkid := a.enableSighashForkid || b.enableSighashForkid
    genesis := a.genesis || b.genesis
    utxoAfterGenesis := a.utxoAfterGenesis || b.utxoAfterGenesis
    chronicle := a.chronicle || b.chronicle
    utxoAfterChronicle := a.utxoAfterChronicle || b.utxoAfterChronicle }

/-- `PRE_CHRONICLE_MANDATORY_SCRIPT_VERIFY_FLAGS` (`standard.h:55–60`): P2SH,
STRICTENC, `SCRIPT_ENABLE_SIGHASH_FORKID`, NULLFAIL, LOW_S: "mandatory script
verification flags that all new blocks must comply with" (`standard.h:48–54`). -/
def mandatoryPreChronicle : Flags :=
  { Flags.none with p2sh := true, strictEnc := true, enableSighashForkid := true, nullFail := true, lowS := true }

/-- `POST_CHRONICLE_MANDATORY_SCRIPT_VERIFY_FLAGS` (`standard.h:62–68`): the
pre-Chronicle set plus `SCRIPT_CHRONICLE`. -/
def mandatoryPostChronicle : Flags := { mandatoryPreChronicle with chronicle := true }

/-- `MandatoryScriptVerifyFlags(era)` (`standard.cpp:330–337`). -/
def mandatoryFlags (era : Era) : Flags :=
  if era.chronicleActive then mandatoryPostChronicle else mandatoryPreChronicle

/-- `STANDARD_SCRIPT_VERIFY_FLAGS` (`policy.h:182–189`): DERSIG, NULLDUMMY,
DISCOURAGE_UPGRADABLE_NOPS, CHECKLOCKTIMEVERIFY, CHECKSEQUENCEVERIFY, CLEANSTACK,
MINIMALDATA: "standard script verification flags that standard transactions will
comply with. However scripts violating these flags may still be present in valid
blocks and we must accept those blocks" (`policy.h:177–181`): the policy set. -/
def standardOnly : Flags :=
  { Flags.none with derSig := true, nullDummy := true, discourageUpgradableNops := true,
                    checkLockTimeVerify := true, checkSequenceVerify := true, cleanStack := true, minimalData := true }

/-- `StandardScriptVerifyFlags(era)` (`policy.h:208–222`): the era's mandatory set
with the standard set (`PRE_/POST_CHRONICLE_STANDARD_SCRIPT_VERIFY_FLAGS`,
`policy.h:191–197`), plus `SCRIPT_GENESIS` when Genesis is active (`policy.h:216–219`). -/
def standardScriptVerifyFlags (era : Era) : Flags :=
  let base := (mandatoryFlags era).union standardOnly
  if era.genesisActive then { base with genesis := true } else base

/-- `InputScriptVerifyFlags(era, utxoEra)` (`policy.h:225–244`): SIGPUSHONLY when
Genesis is active in the spending era (`policy.h:229–232`); `SCRIPT_UTXO_AFTER_GENESIS` /
`SCRIPT_UTXO_AFTER_CHRONICLE` when Genesis / Chronicle is active in the UTXO's era
(`policy.h:234–241`). -/
def inputScriptVerifyFlags (era utxoEra : Era) : Flags :=
  { Flags.none with sigPushOnly := era.genesisActive,
                    utxoAfterGenesis := utxoEra.genesisActive, utxoAfterChronicle := utxoEra.chronicleActive }

/-- `GetBlockScriptFlags(consensus_params, height, protocol_era)`
(`verify_script_flags.cpp:32–81`): P2SH from `p2shHeight` (`:39`); DERSIG, CLTV and
CSV from `height + 1` against `BIP66Height`, `BIP65Height`, `CSVHeight`
(`:43`, `:47`, `:51`); STRICTENC and FORKID from `uahfHeight` (`:55–59`); LOW_S and
NULLFAIL from `daaHeight` (`:65–69`); `SCRIPT_GENESIS` and SIGPUSHONLY when Genesis
is active in the era (`:71–75`); `SCRIPT_CHRONICLE` when Chronicle is (`:77–78`).
`height` is the chain tip's (the block being validated is `height + 1`,
`validation.cpp:2972–2981`, `validation.cpp:3472`). -/
def blockScriptFlags (chain : ChainParams) (height : Nat) (era : Era) : Flags :=
  { Flags.none with
    p2sh := decide (chain.p2shHeight ≤ height)
    derSig := decide (chain.bip66Height ≤ height + 1)
    checkLockTimeVerify := decide (chain.bip65Height ≤ height + 1)
    checkSequenceVerify := decide (chain.csvHeight ≤ height + 1)
    strictEnc := decide (chain.uahfHeight ≤ height)
    enableSighashForkid := decide (chain.uahfHeight ≤ height)
    lowS := decide (chain.daaHeight ≤ height)
    nullFail := decide (chain.daaHeight ≤ height)
    genesis := era.genesisActive
    sigPushOnly := era.genesisActive
    chronicle := era.chronicleActive }

/-- `GetScriptVerifyFlags(era, require_standard, is_prom_mempool_flags, prom_mempool_flags)`
(`verify_script_flags.cpp:11–30`): the era's standard word (`:18`); when
standardness is not required, `-promiscuousmempoolflags` REPLACES the word when
set (`:21–24`) and FORKID is added (`:25`). -/
def mempoolScriptFlags (era : Era) (requireStandard : Bool) (promiscuous : Option Flags) : Flags :=
  let f := standardScriptVerifyFlags era
  if requireStandard then f
  else { promiscuous.getD f with enableSighashForkid := true }

/-! ## The limits (`make_verify_script_params`, `2282–2302`; `configscriptpolicy.cpp`) -/

/-- `UINT32_MAX` and `INT64_MAX`, as the consensus constants spell them
(`consensus.h:43, 55, 60`, `:82`). -/
def uint32Max : Nat := 4294967295
def int64Max : Nat := 9223372036854775807

/-- The configuration as the setters leave it (`configscriptpolicy.cpp:164–308`):
a configured zero is the consensus limit for `MaxOpsPerScript` (`:180–183`),
`MaxScriptSize` (`:231–233`) and `MaxPubKeysPerMultiSig` (`:257–260`), and
`INT64_MAX` for both stack-memory values (`:280–283`, `:289–292`);
`MaxScriptNumLength`'s zero is kept and resolved by its getter (`:209–211`,
`:97–106`). What the setters refuse (a value above the consensus limit, a number
length below 4, a policy stack budget above the consensus one) is a start-up error
in the reference and a precondition here, not a rule. -/
def NodeConfig.normalize (cfg : NodeConfig) : NodeConfig :=
  { cfg with
    maxOpsPerScriptPolicy := if cfg.maxOpsPerScriptPolicy = 0 then Consensus.maxOpsPerScriptAfterGenesis else cfg.maxOpsPerScriptPolicy
    maxScriptSizePolicy := if cfg.maxScriptSizePolicy = 0 then Consensus.maxScriptSizeAfterGenesis else cfg.maxScriptSizePolicy
    maxPubKeysPerMultiSigPolicy := if cfg.maxPubKeysPerMultiSigPolicy = 0 then Consensus.maxPubKeysPerMultisigAfterGenesis else cfg.maxPubKeysPerMultiSigPolicy
    maxStackMemoryUsagePolicy := if cfg.maxStackMemoryUsagePolicy = 0 then Consensus.defaultStackMemoryUsageConsensusAfterGenesis else cfg.maxStackMemoryUsagePolicy
    maxStackMemoryUsageConsensus := if cfg.maxStackMemoryUsageConsensus = 0 then Consensus.defaultStackMemoryUsageConsensusAfterGenesis else cfg.maxStackMemoryUsageConsensus }

/-- `GetMaxScriptNumLength`'s consensus value for an era (`configscriptpolicy.cpp:88–95`,
also the zero-policy fallback `:97–106`): 750,000 post-Genesis, 32,000,000
post-Chronicle. -/
def consensusMaxScriptNumLength (era : Era) : Nat :=
  if era.chronicleActive then Consensus.maxScriptNumLengthAfterChronicle else Consensus.maxScriptNumLengthAfterGenesis

/-- `make_verify_script_params(policySettings, flags, consensus)` (`2295–2302`) over
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
taken as the setters leave it (`NodeConfig.normalize`). -/
def NodeConfig.limitsFor (cfg : NodeConfig) (f : Flags) (consensus : Bool) : Limits :=
  let era := f.utxoEra
  let afterGenesis := f.utxoAfterGenesis
  { maxOpsPerScript :=
      if !afterGenesis then Consensus.maxOpsPerScriptBeforeGenesis
      else if consensus then Consensus.maxOpsPerScriptAfterGenesis
      else cfg.maxOpsPerScriptPolicy
    maxScriptNumLength :=
      if !afterGenesis then Consensus.maxScriptNumLengthBeforeGenesis
      else if consensus then consensusMaxScriptNumLength era
      else if cfg.maxScriptNumLengthPolicy = 0 then consensusMaxScriptNumLength era
      else cfg.maxScriptNumLengthPolicy
    maxScriptSize :=
      if !afterGenesis then Consensus.maxScriptSizeBeforeGenesis
      else if consensus then Consensus.maxScriptSizeAfterGenesis
      else cfg.maxScriptSizePolicy
    maxPubKeysPerMultiSig :=
      if !afterGenesis then Consensus.maxPubKeysPerMultisigBeforeGenesis
      else if consensus then Consensus.maxPubKeysPerMultisigAfterGenesis
      else cfg.maxPubKeysPerMultiSigPolicy
    maxStackMemoryUsage :=
      if !afterGenesis then int64Max
      else if consensus then cfg.maxStackMemoryUsageConsensus
      else cfg.maxStackMemoryUsagePolicy }

/-! ## The derivation (`docs/DESIGN.md` §5.4) -/

/-- The flag word of one input (`CheckInputScripts`, `validation.cpp:2676–2710`):
the caller's word, which is the block word at `spendHeight − 1` with the era of
`spendHeight` under `consensus` (`validation.cpp:3472`, `validation.cpp:2972–2981`; BDK `core/txvalidator.cpp:663–668`)
or the mempool word of the era of `spendHeight` otherwise (`validation.cpp:1031`, `validation.cpp:795–801`;
BDK `core/txvalidator.cpp:669–674`), united with the per-input word of the spend era and the UTXO's
era (`validation.cpp:2694–2696`; BDK `core/txvalidator.cpp:677–678`). `spendHeight` is the height of the block the spend
is in (on the mempool path the tip plus one, `validation.cpp:2857`, `validation.cpp:2544–2548`); `utxoHeight` is the
height of the block that created the output (`validation.cpp:2693`, `validation.cpp:2667–2674`). -/
def NodeConfig.flagWord (cfg : NodeConfig) (spendHeight utxoHeight : Nat) (consensus : Bool) : Flags :=
  let era := cfg.protocolEra spendHeight
  let utxoEra := cfg.protocolEra utxoHeight
  let base :=
    if consensus then blockScriptFlags cfg.chain (spendHeight - 1) era
    else mempoolScriptFlags era cfg.requireStandard cfg.promiscuousMempoolFlags
  base.union (inputScriptVerifyFlags era utxoEra)

/-- **`Params.derive`** (DESIGN §5.4, the signature frozen there): the `EvalParams`
one input of a spend at `spendHeight` of an output created at `utxoHeight` is
verified under by a node configured `cfg`, on the block path (`consensus = true`)
or the mempool path. The word is `flagWord`; the limits are
`make_verify_script_params` on that word (`2701`; BDK `787`). The `consensus`
switch selects the path and the limits and is not in the result (nothing in
`388–1833` or `2304–2451` reads it). -/
def derive (cfg : NodeConfig) (spendHeight utxoHeight : Nat) (consensus : Bool) : EvalParams :=
  let cfg := cfg.normalize
  let flags := cfg.flagWord spendHeight utxoHeight consensus
  { flags, limits := cfg.limitsFor flags consensus }

/-! ## The named limit sets (`docs/PARAMETERS.md` §1, the columns) -/

/-- The pre-Genesis limits (`docs/PARAMETERS.md` §1, the first column; the getters'
`!utxo_after_genesis` branches, `configscriptpolicy.cpp:65–154`): 500 ops
(`consensus.h:40`), 4-byte numbers (`consensus.h:62`), 10,000-byte scripts (`consensus.h:58`), 20 keys
(`consensus.h:50`), and an unbounded memory budget (`INT64_MAX`, `configscriptpolicy.cpp:143–146`: the 520-byte
element and 1,000-element limits apply instead, `script.h:29, 32`). They are the
coin's, whatever the path: a pre-Genesis output spent today runs under them (#20). -/
def preGenesisLimits : Limits :=
  { maxOpsPerScript := Consensus.maxOpsPerScriptBeforeGenesis
    maxScriptNumLength := Consensus.maxScriptNumLengthBeforeGenesis
    maxScriptSize := Consensus.maxScriptSizeBeforeGenesis
    maxPubKeysPerMultiSig := Consensus.maxPubKeysPerMultisigBeforeGenesis
    maxStackMemoryUsage := int64Max }

/-- The post-Genesis consensus limits of a coin's era (the second column; the getters'
`consensus` branches): unbounded ops, script size and keys (`consensus.h:43, 60, 55`),
the era's number width (750,000 post-Genesis, 32,000,000 post-Chronicle, `consensus.h:64`, `consensus.h:66`),
and the node's `maxstackmemoryusageconsensus` as the setter leaves it (`INT64_MAX` by
default, `consensus.h:82`; consensus, node-configurable). -/
def eraConsensusLimits (era : Era) (maxStackMemoryUsageConsensus : Nat) : Limits :=
  { maxOpsPerScript := Consensus.maxOpsPerScriptAfterGenesis
    maxScriptNumLength := consensusMaxScriptNumLength era
    maxScriptSize := Consensus.maxScriptSizeAfterGenesis
    maxPubKeysPerMultiSig := Consensus.maxPubKeysPerMultisigAfterGenesis
    maxStackMemoryUsage := maxStackMemoryUsageConsensus }

/-! ## The mempool coin and Teranode's height convention (#20) -/

/-- `MEMPOOL_HEIGHT` (`protocol_era.h:14`): the fake height (`0x7FFFFFFF`) a coin created
by an unconfirmed transaction carries in the coins view. `GetProtocolEra` throws on it
(`protocol_era.cpp:25–30`), so every caller substitutes a real height first
(`inputScriptBlockHeight`). Not a corpus value (`docs/DESIGN.md` §6: a prevout height is
required; BDK refuses it in consensus mode, `core/txvalidator.cpp:903–904`). -/
def mempoolHeight : Nat := 0x7FFFFFFF

/-- `GetInputScriptBlockHeight(coinHeight)` (`validation.cpp:2667–2674`): "when spending
an output that was created in mempool, we assume that it will be mined in the next
block", `chainActive.Height() + 1`; any other coin keeps its height. The same substitution
is BDK's `resolveUtxoEraHeight(utxoHeight, nextBlockHeight)` (`core/txvalidator.cpp:267–269`,
the next block's height passed in at `core/txvalidator.cpp:677`) and the `verifyscript` RPC's
(`rpc/misc.cpp:803–809`, `tip + 1`). `tip` is the chain tip's height, so the substituted
height is the spend height of the mempool path (`validation.cpp:2545–2548`, `validation.cpp:2857`). -/
def inputScriptBlockHeight (coinHeight tip : Nat) : Nat :=
  if coinHeight = mempoolHeight then tip + 1 else coinHeight

/-- Teranode's engine computes the word of one input in
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
`docs/DESIGN.md` §6. A mempool coin in consensus mode is refused before it runs (`core/txvalidator.cpp:903–904`). -/
def NodeConfig.bdkCalculateFlags (cfg : NodeConfig) (utxoHeight blockHeight : Nat) (consensus : Bool) : Flags :=
  let era := if consensus then cfg.protocolEra blockHeight else cfg.protocolEra (blockHeight + 1)
  let protocolFlags :=
    if consensus then blockScriptFlags cfg.chain (blockHeight - 1) era
    else mempoolScriptFlags era cfg.requireStandard none
  let utxoEra := cfg.protocolEra (inputScriptBlockHeight utxoHeight blockHeight)
  protocolFlags.union (inputScriptVerifyFlags era utxoEra)

/-! ## Every flag: its bit, its kind, its gate (`docs/PARAMETERS.md` §2) -/

/-- The kinds of `docs/PARAMETERS.md` (the census, #6). -/
inductive FlagKind where
  /-- decides block validity for every node; set by the block flags at an activation height -/
  | consensusByHeight
  /-- a node's setting for what it relays or mines; in the standard set only, never in a block word (`policy.h:177–181`) -/
  | policy
  /-- carries the spending era or the UTXO's era into the interpreter; derived from heights -/
  | eraMarker
  /-- defined but absent from every set the node computes at the pin; it reaches the interpreter in an explicit word (the `verifyscript` RPC's integer `flags`, `rpc/misc.cpp:697–702`) or in a `-promiscuousmempoolflags` word on a chain that does not require standardness (`flagWord_neverSet_off`) -/
  | neverSet
  deriving DecidableEq, Repr

/-- The nineteen flags of `script_flags.h:13–115`. -/
inductive FlagBit where
  | p2sh | strictEnc | derSig | lowS | nullDummy | sigPushOnly | minimalData | discourageUpgradableNops
  | cleanStack | checkLockTimeVerify | checkSequenceVerify | minimalIf | nullFail | compressedPubKeyType
  | enableSighashForkid | genesis | utxoAfterGenesis | chronicle | utxoAfterChronicle
  deriving DecidableEq, Repr

namespace FlagBit

def all : List FlagBit :=
  [p2sh, strictEnc, derSig, lowS, nullDummy, sigPushOnly, minimalData, discourageUpgradableNops,
   cleanStack, checkLockTimeVerify, checkSequenceVerify, minimalIf, nullFail, compressedPubKeyType,
   enableSighashForkid, genesis, utxoAfterGenesis, chronicle, utxoAfterChronicle]

/-- The bit position (`script_flags.h:17–111`). -/
def bit : FlagBit → Nat
  | p2sh => 0 | strictEnc => 1 | derSig => 2 | lowS => 3 | nullDummy => 4 | sigPushOnly => 5
  | minimalData => 6 | discourageUpgradableNops => 7 | cleanStack => 8 | checkLockTimeVerify => 9
  | checkSequenceVerify => 10 | minimalIf => 13 | nullFail => 14 | compressedPubKeyType => 15
  | enableSighashForkid => 16 | genesis => 18 | utxoAfterGenesis => 19 | chronicle => 20 | utxoAfterChronicle => 21

/-- The enum identifier (`script_flags.h`). -/
def name : FlagBit → String
  | p2sh => "SCRIPT_VERIFY_P2SH" | strictEnc => "SCRIPT_VERIFY_STRICTENC" | derSig => "SCRIPT_VERIFY_DERSIG"
  | lowS => "SCRIPT_VERIFY_LOW_S" | nullDummy => "SCRIPT_VERIFY_NULLDUMMY" | sigPushOnly => "SCRIPT_VERIFY_SIGPUSHONLY"
  | minimalData => "SCRIPT_VERIFY_MINIMALDATA" | discourageUpgradableNops => "SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_NOPS"
  | cleanStack => "SCRIPT_VERIFY_CLEANSTACK" | checkLockTimeVerify => "SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY"
  | checkSequenceVerify => "SCRIPT_VERIFY_CHECKSEQUENCEVERIFY" | minimalIf => "SCRIPT_VERIFY_MINIMALIF"
  | nullFail => "SCRIPT_VERIFY_NULLFAIL" | compressedPubKeyType => "SCRIPT_VERIFY_COMPRESSED_PUBKEYTYPE"
  | enableSighashForkid => "SCRIPT_ENABLE_SIGHASH_FORKID" | genesis => "SCRIPT_GENESIS"
  | utxoAfterGenesis => "SCRIPT_UTXO_AFTER_GENESIS" | chronicle => "SCRIPT_CHRONICLE" | utxoAfterChronicle => "SCRIPT_UTXO_AFTER_CHRONICLE"

/-- The name the reference's flag parsers accept (`rpc/misc.cpp:1281–1302`,
`src/test/scriptflags.cpp:17–38`, the same map). -/
def testName : FlagBit → String
  | p2sh => "P2SH" | strictEnc => "STRICTENC" | derSig => "DERSIG" | lowS => "LOW_S" | nullDummy => "NULLDUMMY"
  | sigPushOnly => "SIGPUSHONLY" | minimalData => "MINIMALDATA" | discourageUpgradableNops => "DISCOURAGE_UPGRADABLE_NOPS"
  | cleanStack => "CLEANSTACK" | checkLockTimeVerify => "CHECKLOCKTIMEVERIFY" | checkSequenceVerify => "CHECKSEQUENCEVERIFY"
  | minimalIf => "MINIMALIF" | nullFail => "NULLFAIL" | compressedPubKeyType => "COMPRESSED_PUBKEYTYPE"
  | enableSighashForkid => "SIGHASH_FORKID" | genesis => "GENESIS" | utxoAfterGenesis => "UTXO_AFTER_GENESIS"
  | chronicle => "CHRONICLE" | utxoAfterChronicle => "UTXO_AFTER_CHRONICLE"

/-- The kind of each flag (`docs/PARAMETERS.md` §2, each cell `[SRC]`). -/
def kind : FlagBit → FlagKind
  | p2sh => .consensusByHeight                 -- `verify_script_flags.cpp:39`; mandatory `standard.h:56, 63`
  | strictEnc => .consensusByHeight            -- `:55–57`; mandatory `:57, 64`; implied by FORKID `2315–2319`
  | derSig => .consensusByHeight               -- `:43`; also standard `policy.h:183`
  | lowS => .consensusByHeight                 -- `:65–67`; mandatory `:60, 67`; version-gated `285`
  | nullDummy => .policy                       -- standard only `policy.h:184`; version-gated `1666`
  | sigPushOnly => .consensusByHeight          -- Genesis `:71–75`; input `policy.h:229–232`; gated by era and version `2321–2334`
  | minimalData => .policy                     -- standard only `policy.h:189`; version-gated `433`
  | discourageUpgradableNops => .policy        -- standard only `policy.h:185`; "will never be a mandatory flag applied to scripts in a block" `script_flags.h:56–57`
  | cleanStack => .policy                      -- standard only `policy.h:188`; version-gated `2441`
  | checkLockTimeVerify => .consensusByHeight  -- `:47`; also standard `policy.h:186`
  | checkSequenceVerify => .consensusByHeight  -- `:51`; also standard `policy.h:187`
  | minimalIf => .neverSet                     -- in no derived word: an explicit one (`rpc/misc.cpp:697–702`) or a promiscuous one (`FlagKind.neverSet`); version-gated `801` where read
  | nullFail => .consensusByHeight             -- `:67–68`; mandatory `:59, 66`; version-gated `1493`, `1643`
  | compressedPubKeyType => .neverSet          -- in no derived word: an explicit one (`rpc/misc.cpp:697–702`) or a promiscuous one (`FlagKind.neverSet`)
  | enableSighashForkid => .consensusByHeight  -- `:58`; mandatory `:58, 65`
  | genesis => .eraMarker                      -- `:71–73`; `policy.h:216–219`
  | utxoAfterGenesis => .eraMarker             -- `policy.h:232–237`
  | chronicle => .eraMarker                    -- `:77–78`; `policy.h:195–197, 212–215`; mandatory `standard.h:68`
  | utxoAfterChronicle => .eraMarker           -- `policy.h:238–241`

/-- The seven restrictions that hang on `EnforceNonMalleability` (`40–44`), with
their gate sites (`docs/DESIGN.md` §5.3): LOW_S `285`, MINIMALDATA `433`,
MINIMALIF `801`, NULLFAIL `1493`/`1643`, NULLDUMMY `1666`, SIGPUSHONLY `2327`,
CLEANSTACK `2441`. -/
def gateSites : FlagBit → List Nat
  | lowS => [285] | minimalData => [433] | minimalIf => [801] | nullFail => [1493, 1643]
  | nullDummy => [1666] | sigPushOnly => [2327] | cleanStack => [2441]
  | _ => []

def versionGated (b : FlagBit) : Bool := !b.gateSites.isEmpty

/-- Read a bit of a word. -/
def get : FlagBit → Flags → Bool
  | p2sh, f => f.p2sh | strictEnc, f => f.strictEnc | derSig, f => f.derSig | lowS, f => f.lowS
  | nullDummy, f => f.nullDummy | sigPushOnly, f => f.sigPushOnly | minimalData, f => f.minimalData
  | discourageUpgradableNops, f => f.discourageUpgradableNops | cleanStack, f => f.cleanStack
  | checkLockTimeVerify, f => f.checkLockTimeVerify | checkSequenceVerify, f => f.checkSequenceVerify
  | minimalIf, f => f.minimalIf | nullFail, f => f.nullFail | compressedPubKeyType, f => f.compressedPubKeyType
  | enableSighashForkid, f => f.enableSighashForkid | genesis, f => f.genesis
  | utxoAfterGenesis, f => f.utxoAfterGenesis | chronicle, f => f.chronicle | utxoAfterChronicle, f => f.utxoAfterChronicle

/-- Set a bit of a word. -/
def set : FlagBit → Flags → Bool → Flags
  | p2sh, f, v => { f with p2sh := v } | strictEnc, f, v => { f with strictEnc := v }
  | derSig, f, v => { f with derSig := v } | lowS, f, v => { f with lowS := v }
  | nullDummy, f, v => { f with nullDummy := v } | sigPushOnly, f, v => { f with sigPushOnly := v }
  | minimalData, f, v => { f with minimalData := v }
  | discourageUpgradableNops, f, v => { f with discourageUpgradableNops := v }
  | cleanStack, f, v => { f with cleanStack := v }
  | checkLockTimeVerify, f, v => { f with checkLockTimeVerify := v }
  | checkSequenceVerify, f, v => { f with checkSequenceVerify := v }
  | minimalIf, f, v => { f with minimalIf := v } | nullFail, f, v => { f with nullFail := v }
  | compressedPubKeyType, f, v => { f with compressedPubKeyType := v }
  | enableSighashForkid, f, v => { f with enableSighashForkid := v }
  | genesis, f, v => { f with genesis := v } | utxoAfterGenesis, f, v => { f with utxoAfterGenesis := v }
  | chronicle, f, v => { f with chronicle := v } | utxoAfterChronicle, f, v => { f with utxoAfterChronicle := v }

/-- The set bits of a word, in bit order. -/
def ofFlags (f : Flags) : List FlagBit := all.filter (·.get f)

/-- The test-map name lookup (`ParseScriptFlags`). -/
def ofTestName (s : String) : Option FlagBit := all.find? (·.testName == s)

end FlagBit

/-! ## The 32-bit word (`script_flags.h:13–115`) -/

/-- One bit of a word: `2^k` when set. -/
def bitOf (b : Bool) (k : Nat) : Nat := if b then 2 ^ k else 0

/-- The `uint32_t` the reference passes around (`VerifyScript`'s `flags`, the
`verifyscript` RPC's `flags`, the corpus's explicit `flags` per input). -/
def Flags.toWord (f : Flags) : Nat :=
  bitOf f.p2sh 0 ||| bitOf f.strictEnc 1 ||| bitOf f.derSig 2 ||| bitOf f.lowS 3 |||
  bitOf f.nullDummy 4 ||| bitOf f.sigPushOnly 5 ||| bitOf f.minimalData 6 |||
  bitOf f.discourageUpgradableNops 7 ||| bitOf f.cleanStack 8 ||| bitOf f.checkLockTimeVerify 9 |||
  bitOf f.checkSequenceVerify 10 ||| bitOf f.minimalIf 13 ||| bitOf f.nullFail 14 |||
  bitOf f.compressedPubKeyType 15 ||| bitOf f.enableSighashForkid 16 ||| bitOf f.genesis 18 |||
  bitOf f.utxoAfterGenesis 19 ||| bitOf f.chronicle 20 ||| bitOf f.utxoAfterChronicle 21

/-- The word read back; the unassigned bits 11, 12, 17 and everything from 22 up are
ignored, as the interpreter ignores them (it tests named bits only,
`script_flags.h:117–171`). -/
def Flags.ofWord (w : Nat) : Flags :=
  { p2sh := w.testBit 0, strictEnc := w.testBit 1, derSig := w.testBit 2, lowS := w.testBit 3,
    nullDummy := w.testBit 4, sigPushOnly := w.testBit 5, minimalData := w.testBit 6,
    discourageUpgradableNops := w.testBit 7, cleanStack := w.testBit 8, checkLockTimeVerify := w.testBit 9,
    checkSequenceVerify := w.testBit 10, minimalIf := w.testBit 13, nullFail := w.testBit 14,
    compressedPubKeyType := w.testBit 15, enableSighashForkid := w.testBit 16, genesis := w.testBit 18,
    utxoAfterGenesis := w.testBit 19, chronicle := w.testBit 20, utxoAfterChronicle := w.testBit 21 }

/-- A one-bit word read back: bit `i` of `bitOf b k` is `b` at `i = k` and clear elsewhere; the step
`Flags.ofWord_toWord` (T-F1, below) reads each named bit of the word with. -/
theorem testBit_bitOf (b : Bool) (k i : Nat) : (bitOf b k).testBit i = (b && decide (k = i)) := by
  cases b <;> simp [bitOf, Nat.testBit_two_pow]

/-- **T-F1.** *What it says:* the word encodes the record faithfully: reading the
word back gives the record. *Why it matters:* the CLI's `--flags <u32>` and the
corpus's explicit `flags` are the interpreter's own `uint32_t`, so the JSON
echo (`Flags.toWord`) is the word the interpreter runs. The RPC's `reportflags`
(`rpc/misc.cpp:540–541`, `rpc/misc.cpp:908–911`) echoes `(int)scr.flags` after re-deriving
the two UTXO bits from `txo.height` when one is given (`rpc/misc.cpp:803–823`), and keeps bits
`toWord` has no name for (lean #32's second lens, B-9; the file on every line, its fourth
re-lens, B4N-1). -/
theorem Flags.ofWord_toWord (f : Flags) : Flags.ofWord f.toWord = f := by
  cases f
  simp only [Flags.ofWord, Flags.toWord, Nat.testBit_or, testBit_bitOf, Flags.mk.injEq]
  simp

/-- **T-F2.** The bits the record does not name are the only information a
`uint32_t` can lose: a word below `SCRIPT_FLAG_LAST` (`2^22`, `script_flags.h:114`)
with bits 11, 12 and 17 clear round-trips. -/
theorem Flags.toWord_ofWord (w : Nat) (hw : w < 2 ^ 22)
    (h11 : w.testBit 11 = false) (h12 : w.testBit 12 = false) (h17 : w.testBit 17 = false) :
    (Flags.ofWord w).toWord = w := by
  apply Nat.eq_of_testBit_eq
  intro i
  simp only [Flags.toWord, Flags.ofWord, Nat.testBit_or, testBit_bitOf]
  by_cases hi : i < 22
  · have hi' : i = 0 ∨ i = 1 ∨ i = 2 ∨ i = 3 ∨ i = 4 ∨ i = 5 ∨ i = 6 ∨ i = 7 ∨ i = 8 ∨ i = 9 ∨ i = 10 ∨
        i = 11 ∨ i = 12 ∨ i = 13 ∨ i = 14 ∨ i = 15 ∨ i = 16 ∨ i = 17 ∨ i = 18 ∨ i = 19 ∨ i = 20 ∨ i = 21 := by omega
    rcases hi' with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
      rfl | rfl | rfl | rfl | rfl | rfl <;> simp [h11, h12, h17]
  · have hz : w.testBit i = false :=
      Nat.testBit_lt_two_pow (Nat.lt_of_lt_of_le hw (Nat.pow_le_pow_right (by decide) (by omega)))
    have hk : ∀ k, k < 22 → decide (k = i) = false := fun k hk => by simp; omega
    simp [hz, hk]

/-! ## The theorems -/

/-- **The block word never carries a policy flag** (constitution 01 at the flag
level; `policy.h:177–181`: "scripts violating these flags may still be present in
valid blocks and we must accept those blocks"; `script_flags.h:56–57`). *What it
says:* for every chain, every height and every era, the four flags the census
classes as policy (NULLDUMMY, MINIMALDATA, DISCOURAGE_UPGRADABLE_NOPS, CLEANSTACK)
are off in `GetBlockScriptFlags`'s word. *Why it matters:* it is the theorem behind
the sentence "policy never decides block validity", read off the derivation. -/
theorem blockScriptFlags_policy_off (chain : ChainParams) (height : Nat) (era : Era)
    (b : FlagBit) (hb : b.kind = .policy) : b.get (blockScriptFlags chain height era) = false := by
  cases b <;> simp [FlagBit.kind] at hb <;> simp [FlagBit.get, blockScriptFlags, Flags.none]

/-- The never-set flags are never set by either derivation (without promiscuous flags): the node's own words
never carry MINIMALIF or COMPRESSED_PUBKEYTYPE. They reach the interpreter in an explicit word, the `verifyscript`
RPC's integer `flags` (`rpc/misc.cpp:697–702`), and, on a chain whose `RequireStandard()` is false (stn, testnet,
regtest: `chainparams.cpp:1271`, `:1416`, `:1527`), in a `-promiscuousmempoolflags` word (any non-negative integer,
`config.cpp:2584–2590`, made the mempool word at `verify_script_flags.cpp:23`): the route the hypothesis `hp`
excludes. `sendrawtransactions`' `skipscriptflags` only clears flags, and it refuses both of these
(`rpc/rawtransaction.cpp:1486`, `:1501–1506`). -/
theorem flagWord_neverSet_off (cfg : NodeConfig) (h u : Nat) (c : Bool)
    (hp : cfg.promiscuousMempoolFlags = none) (b : FlagBit) (hb : b.kind = .neverSet) :
    b.get (cfg.flagWord h u c) = false := by
  cases b <;> simp [FlagBit.kind] at hb <;>
    cases c <;> cases hE : cfg.protocolEra h <;> cases hU : cfg.protocolEra u <;> cases hs : cfg.requireStandard <;>
    simp [NodeConfig.flagWord, FlagBit.get, Flags.union, blockScriptFlags, mempoolScriptFlags,
          standardScriptVerifyFlags, mandatoryFlags, mandatoryPostChronicle, mandatoryPreChronicle,
          standardOnly, inputScriptVerifyFlags, Flags.none, Era.genesisActive, Era.chronicleActive, hp, hE, hU, hs]

/-- **The derived word is `valid_flags` on a node with no promiscuous word** (`2259–2262`; the hypothesis
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
(`interpreter.cpp:2430–2436`): policy settings, and misconfigurations, never a consensus fact. -/
theorem flagWord_valid (cfg : NodeConfig) (h u : Nat) (c : Bool) (hp : cfg.promiscuousMempoolFlags = none) :
    (cfg.flagWord h u c).valid = true := by
  cases c <;> cases hE : cfg.protocolEra h <;> cases hU : cfg.protocolEra u <;> cases hs : cfg.requireStandard <;>
    simp [NodeConfig.flagWord, Flags.valid, Flags.union, blockScriptFlags, mempoolScriptFlags,
          standardScriptVerifyFlags, mandatoryFlags, mandatoryPostChronicle, mandatoryPreChronicle,
          standardOnly, inputScriptVerifyFlags, Flags.none, Era.genesisActive, Era.chronicleActive, hE, hU, hs, hp]

/-- **CLEANSTACK without P2SH is in no derived word** (`interpreter.cpp:2430–2436`, the second source of
`SCRIPT_ERR_INVALID_FLAGS`): the block word never carries CLEANSTACK (`blockScriptFlags_policy_off`) and every
standard word carries P2SH (mandatory in both eras, `standard.h:56`, `:63`), so `VerifyScript`'s demand
(`Flags.cleanStackDemand`) is off on both paths. Without promiscuous flags, as `flagWord_valid`. -/
theorem flagWord_cleanStackDemand (cfg : NodeConfig) (h u : Nat) (c : Bool) (hp : cfg.promiscuousMempoolFlags = none) :
    (cfg.flagWord h u c).cleanStackDemand = false := by
  cases c <;> cases hE : cfg.protocolEra h <;> cases hU : cfg.protocolEra u <;> cases hs : cfg.requireStandard <;>
    simp [NodeConfig.flagWord, Flags.cleanStackDemand, Flags.union, blockScriptFlags, mempoolScriptFlags,
          standardScriptVerifyFlags, mandatoryFlags, mandatoryPostChronicle, mandatoryPreChronicle,
          standardOnly, inputScriptVerifyFlags, Flags.none, Era.genesisActive, Era.chronicleActive, hE, hU, hs, hp]

/-- The UTXO era the interpreter reads back (`utxo_era`, `2269–2280`) is the era of
the UTXO's height (without promiscuous flags, as above). -/
theorem flagWord_utxoEra (cfg : NodeConfig) (h u : Nat) (c : Bool) (hp : cfg.promiscuousMempoolFlags = none) :
    (cfg.flagWord h u c).utxoEra = cfg.protocolEra u := by
  cases c <;> cases hE : cfg.protocolEra h <;> cases hU : cfg.protocolEra u <;> cases hs : cfg.requireStandard <;>
    simp [NodeConfig.flagWord, Flags.utxoEra, Flags.union, blockScriptFlags, mempoolScriptFlags,
          standardScriptVerifyFlags, mandatoryFlags, mandatoryPostChronicle, mandatoryPreChronicle,
          standardOnly, inputScriptVerifyFlags, Flags.none, Era.genesisActive, Era.chronicleActive, hE, hU, hs, hp]

/-- The block path never reads the promiscuous word: the block word is valid unconditionally (the twin of
`flagWord_valid` without its hypothesis; that it carries the UTXO's era unconditionally is
`Properties.flagWord_block_utxoEra`). -/
theorem flagWord_block_valid (cfg : NodeConfig) (h u : Nat) : (cfg.flagWord h u true).valid = true := by
  cases hU : cfg.protocolEra u <;>
    simp [NodeConfig.flagWord, Flags.valid, Flags.union, blockScriptFlags, inputScriptVerifyFlags, Flags.none,
          Era.genesisActive, Era.chronicleActive, hU]

/-- **P5, parameter separation** (`docs/DESIGN.md` §9; constitution 01). *What it
says:* on the block path (`consensus = true`) `Params.derive` reads only the
consensus fields of a node's configuration: its chain, its two activation heights
and `maxstackmemoryusageconsensus`; two nodes that agree on those verify every
input under the same `EvalParams`, whatever their policy settings
(`maxopsperscriptpolicy`, `maxscriptnumlengthpolicy`, `maxscriptsizepolicy`,
`maxpubkeyspermultisigpolicy`, `maxstackmemoryusagepolicy`, `acceptnonstdtxn`,
`-promiscuousmempoolflags`). *What it assumes:* nothing. *Why it matters:* it is
the machine-checked form of "a policy limit never decides block validity"; a
Teranode and an SV-node with their different policy defaults (`docs/PARAMETERS.md`
§5) derive the same block parameters (the example below). -/
theorem derive_consensus_separation (cfg cfg' : NodeConfig) (h u : Nat)
    (hchain : cfg.chain = cfg'.chain)
    (hg : cfg.genesisActivationHeight = cfg'.genesisActivationHeight)
    (hc : cfg.chronicleActivationHeight = cfg'.chronicleActivationHeight)
    (hm : cfg.maxStackMemoryUsageConsensus = cfg'.maxStackMemoryUsageConsensus) :
    derive cfg h u true = derive cfg' h u true := by
  simp only [derive, NodeConfig.normalize, NodeConfig.flagWord, NodeConfig.protocolEra, NodeConfig.limitsFor,
             hchain, hg, hc, hm, ite_true]

/-- The verdict-level corollary of P5: the block verdict of a spend is the same
under any two nodes that agree on the consensus fields. -/
theorem verifyScript_consensus_separation (exec : Machine.OpExec) (cfg cfg' : NodeConfig) (h u : Nat)
    (ctx : Machine.Context) (s l : Numbers.Bytes)
    (hchain : cfg.chain = cfg'.chain)
    (hg : cfg.genesisActivationHeight = cfg'.genesisActivationHeight)
    (hc : cfg.chronicleActivationHeight = cfg'.chronicleActivationHeight)
    (hm : cfg.maxStackMemoryUsageConsensus = cfg'.maxStackMemoryUsageConsensus) :
    Machine.verifyScript exec (derive cfg h u true) ctx s l = Machine.verifyScript exec (derive cfg' h u true) ctx s l := by
  rw [derive_consensus_separation cfg cfg' h u hchain hg hc hm]

-- SV-node and Teranode, at their defaults, derive the same block parameters at
-- the spec's default height (P5 instantiated) and differ on the mempool path
-- exactly in the three policy limits the census flags (`docs/PARAMETERS.md` §5:
-- `maxopsperscriptpolicy` 4,294,967,295 vs 1,000,000; `maxstackmemoryusagepolicy`
-- 100,000,000 vs 104,857,600; `maxscriptsizepolicy` 500,000 vs 100,000,000 since
-- Teranode v0.16.0, #54), never in the word.
example : derive NodeConfig.svMainnetDefault defaultSpendHeight defaultSpendHeight true
    = derive NodeConfig.teranodeDefault defaultSpendHeight defaultSpendHeight true := by decide
example : (derive NodeConfig.svMainnetDefault defaultSpendHeight defaultSpendHeight false).flags
    = (derive NodeConfig.teranodeDefault defaultSpendHeight defaultSpendHeight false).flags := by decide
example : (derive NodeConfig.svMainnetDefault defaultSpendHeight defaultSpendHeight false).limits
    ≠ (derive NodeConfig.teranodeDefault defaultSpendHeight defaultSpendHeight false).limits := by decide
example : (derive NodeConfig.svMainnetDefault defaultSpendHeight defaultSpendHeight false).limits.maxOpsPerScript = 4294967295 := by decide
example : (derive NodeConfig.teranodeDefault defaultSpendHeight defaultSpendHeight false).limits.maxOpsPerScript = 1000000 := by decide
example : (derive NodeConfig.svMainnetDefault defaultSpendHeight defaultSpendHeight false).limits.maxStackMemoryUsage = 100000000 := by decide
example : (derive NodeConfig.teranodeDefault defaultSpendHeight defaultSpendHeight false).limits.maxStackMemoryUsage = 104857600 := by decide

/-- The block word of a post-Chronicle spend of a post-Chronicle output on mainnet
(every activation passed): P2SH · STRICTENC · DERSIG · LOW_S · SIGPUSHONLY · CLTV ·
CSV · NULLFAIL · FORKID · GENESIS · UTXO_AFTER_GENESIS · CHRONICLE ·
UTXO_AFTER_CHRONICLE = `0x3D462F`. -/
def mainnetBlockWord : Flags :=
  { Flags.none with p2sh := true, strictEnc := true, derSig := true, lowS := true, sigPushOnly := true,
                    checkLockTimeVerify := true, checkSequenceVerify := true, nullFail := true,
                    enableSighashForkid := true, genesis := true, utxoAfterGenesis := true,
                    chronicle := true, utxoAfterChronicle := true }

/-- The mempool (relay) word of the same spend under `requireStandard`: the block
word plus NULLDUMMY · MINIMALDATA · DISCOURAGE_UPGRADABLE_NOPS · CLEANSTACK =
`0x3D47FF`. This is the word every corpus leg so far ran under (`Test/Common.lean`
`relayFlags`, hand-written at #8); `Test/FlagsCheck.lean` decides that the two agree. -/
def mainnetRelayWord : Flags :=
  { mainnetBlockWord with nullDummy := true, minimalData := true, discourageUpgradableNops := true, cleanStack := true }

example : (derive NodeConfig.svMainnetDefault defaultSpendHeight defaultSpendHeight true).flags = mainnetBlockWord := by decide
example : (derive NodeConfig.svMainnetDefault defaultSpendHeight defaultSpendHeight false).flags = mainnetRelayWord := by decide
example : mainnetBlockWord.toWord = 0x3D462F := by decide
example : mainnetRelayWord.toWord = 0x3D47FF := by decide
example : (derive NodeConfig.svMainnetDefault defaultSpendHeight defaultSpendHeight true).limits
    = { maxOpsPerScript := 4294967295, maxScriptNumLength := 32000000, maxScriptSize := 4294967295,
        maxPubKeysPerMultiSig := 4294967295, maxStackMemoryUsage := 9223372036854775807 } := by decide
example : (derive NodeConfig.svMainnetDefault defaultSpendHeight defaultSpendHeight false).limits
    = { maxOpsPerScript := 4294967295, maxScriptNumLength := 10000, maxScriptSize := 500000,
        maxPubKeysPerMultiSig := 4294967295, maxStackMemoryUsage := 100000000 } := by decide
-- a pre-Genesis output spent today: the pre-Genesis limits, no UTXO markers
example : (derive NodeConfig.svMainnetDefault defaultSpendHeight 620537 true).flags
    = { mainnetBlockWord with utxoAfterGenesis := false, utxoAfterChronicle := false } := by decide
example : (derive NodeConfig.svMainnetDefault defaultSpendHeight 620537 true).limits
    = { maxOpsPerScript := 500, maxScriptNumLength := 4, maxScriptSize := 10000,
        maxPubKeysPerMultiSig := 20, maxStackMemoryUsage := 9223372036854775807 } := by decide
-- a post-Genesis, pre-Chronicle output spent today: the post-Genesis number width
example : (derive NodeConfig.svMainnetDefault defaultSpendHeight 943815 true).limits.maxScriptNumLength = 750000 := by decide
-- the spend height at the Chronicle boundary: the block word of block 943,816 carries CHRONICLE, that of 943,815 does not
example : (derive NodeConfig.svMainnetDefault 943816 943816 true).flags.chronicle = true := by decide
example : (derive NodeConfig.svMainnetDefault 943815 943815 true).flags.chronicle = false := by decide
example : (derive NodeConfig.svMainnetDefault 943815 943815 true).flags.genesis = true := by decide
-- the two `+ 1` sites: DERSIG is in the block word of block 363,725 (`height + 1 >= BIP66Height`
-- with `height = 363,724`), P2SH in the block word of block 173,806 (`height >= p2shHeight`)
example : (derive NodeConfig.svMainnetDefault 363725 100 true).flags.derSig = true := by decide
example : (derive NodeConfig.svMainnetDefault 363724 100 true).flags.derSig = false := by decide
example : (derive NodeConfig.svMainnetDefault 173806 100 true).flags.p2sh = true := by decide
example : (derive NodeConfig.svMainnetDefault 173805 100 true).flags.p2sh = false := by decide

/-- With `SCRIPT_CHRONICLE` set and a version above 1 the gate is off (`40–44`) and
`Flags.gate` clears the seven restrictions. -/
theorem Flags.gate_off_of_chronicle (f : Flags) (v : Int) (hf : f.chronicle = true) (hv : 1 < v) :
    f.gate v = { f with minimalData := false, minimalIf := false, nullFail := false, nullDummy := false,
                        lowS := false, sigPushOnly := false, cleanStack := false } := by
  simp [Flags.gate, enforceNonMalleability, isMalleableTxnVersion, hf, hv]

/-- **The relay word and the block word on mainnet today differ in exactly the
four standard-only bits.** *What it says:* for a spend at or after the Chronicle
height on mainnet, under `requireStandard` (`hstd`), the mempool word is the block word plus NULLDUMMY,
DISCOURAGE_UPGRADABLE_NOPS, CLEANSTACK and MINIMALDATA. *What it assumes:* the mainnet chain and heights and `hstd`;
no promiscuous word is assumed or needed, since under `requireStandard` it is never read (`mempoolScriptFlags`,
`verify_script_flags.cpp:19–26`). At the pin the switch the word reads is the chain's `RequireStandard()`
(`validation.cpp:798`), true on mainnet (`chainparams.cpp:1121`) whatever `-acceptnonstdtxn` says (that option sets
another value, `init.cpp:3158–3160`), so on mainnet `hstd` describes every node. The word is the one a transaction
submitted without `skipscriptflags` runs under; that option can clear DERSIG, MINIMALDATA, NULLDUMMY,
DISCOURAGE_UPGRADABLE_NOPS or CLEANSTACK from it (`validation.cpp:1330`, `rpc/rawtransaction.cpp:1483–1510`).
*Why it matters:* three of the four hang on the version gate; the theorem after this one draws the consequence. -/
theorem flagWord_mempool_eq_block_mainnet (cfg : NodeConfig) (h u : Nat)
    (hchain : cfg.chain = ChainParams.mainnet) (hg : cfg.genesisActivationHeight = 620538)
    (hc : cfg.chronicleActivationHeight = 943816) (hstd : cfg.requireStandard = true) (hh : 943816 ≤ h) :
    cfg.flagWord h u false
      = { cfg.flagWord h u true with nullDummy := true, discourageUpgradableNops := true, cleanStack := true, minimalData := true } := by
  have h1 : 173805 ≤ h - 1 := by omega
  have h2 : 363725 ≤ h - 1 + 1 := by omega
  have h3 : 388381 ≤ h - 1 + 1 := by omega
  have h4 : 419328 ≤ h - 1 + 1 := by omega
  have h5 : 478558 ≤ h - 1 := by omega
  have h6 : 504031 ≤ h - 1 := by omega
  have h7 : ¬ h < 620538 := by omega
  have h8 : ¬ h < 943816 := by omega
  simp [NodeConfig.flagWord, NodeConfig.protocolEra, protocolEraOf, blockScriptFlags, mempoolScriptFlags,
        standardScriptVerifyFlags, mandatoryFlags, mandatoryPostChronicle, mandatoryPreChronicle, standardOnly,
        inputScriptVerifyFlags, Flags.union, Flags.none, Era.genesisActive, Era.chronicleActive,
        ChainParams.mainnet, hchain, hg, hc, hstd, h1, h2, h3, h4, h5, h6, h7, h8]

/-- **Relay versus block for a version-2 spend post-Chronicle (the CLAUDE.md
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
DISCOURAGE_UPGRADABLE_NOPS or CLEANSTACK from the relay word (`validation.cpp:1330`, `rpc/rawtransaction.cpp:1486`). -/
theorem verifyScript_relay_block_version2 (exec : Machine.OpExec) (cfg : NodeConfig) (h u : Nat)
    (limits : Limits) (ctx : Machine.Context) (s l : Numbers.Bytes)
    (hchain : cfg.chain = ChainParams.mainnet) (hg : cfg.genesisActivationHeight = 620538)
    (hc : cfg.chronicleActivationHeight = 943816) (hstd : cfg.requireStandard = true)
    (hh : 943816 ≤ h) (hv : 1 < ctx.version) :
    Machine.verifyScript exec { flags := cfg.flagWord h u false, limits } ctx s l
      = Machine.verifyScript exec { flags := { cfg.flagWord h u true with discourageUpgradableNops := true }, limits } ctx s l := by
  rw [flagWord_mempool_eq_block_mainnet cfg h u hchain hg hc hstd hh]
  have hp : (cfg.flagWord h u true).p2sh = true := by
    have h1 : 173805 ≤ h - 1 := by omega
    simp [NodeConfig.flagWord, blockScriptFlags, Flags.union, Flags.none, ChainParams.mainnet, hchain, h1]
  have hch : (cfg.flagWord h u true).chronicle = true := by
    have h7 : ¬ h < 620538 := by omega
    have h8 : ¬ h < 943816 := by omega
    simp [NodeConfig.flagWord, NodeConfig.protocolEra, protocolEraOf, blockScriptFlags, Flags.union, Flags.none,
          inputScriptVerifyFlags, Era.chronicleActive, hg, hc, h7, h8]
  apply Properties.verifyScript_congr
  · rfl
  · simp [Flags.valid]
  · by_cases hfk : (cfg.flagWord h u true).enableSighashForkid = true <;>
      simp [Flags.forkAdjust, hfk, Flags.gate_off_of_chronicle, hch, hv]
  · by_cases hfk : (cfg.flagWord h u true).enableSighashForkid = true <;> simp [Flags.forkAdjust, Flags.strictDer, hfk]
  · by_cases hfk : (cfg.flagWord h u true).enableSighashForkid = true <;> simp [Flags.forkAdjust, Flags.utxoEra, hfk]
  · by_cases hfk : (cfg.flagWord h u true).enableSighashForkid = true <;> simp [Flags.forkAdjust, Flags.p2shCopy, hfk]
  · by_cases hfk : (cfg.flagWord h u true).enableSighashForkid = true <;>
      simp [Flags.forkAdjust, Flags.cleanStackDemand, hfk, hp]

end BsvScript.Params
