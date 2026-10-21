import BsvScript.Flags
import BsvScript.Ops.Expansion
import BsvScript.TxContext
import BsvScript.Properties.Basic
/-!
# BsvScript.Properties.Eras

The activation rules as parameters (#20; `docs/DESIGN.md` §3, §5.2, §9 Q3;
`docs/PARAMETERS.md` §3, §6). The heights are parameters of `Params.derive`
(`ChainParams`, `NodeConfig.genesisActivationHeight`, `chronicleActivationHeight`,
`lean/BsvScript/Flags.lean`); this module states what the derivation and the
machine do with them, each theorem at its site of the reference:

* **the era selection** (`src/protocol_era.cpp:21–39`, `89–103`): the three cases as
  inequalities on the height, monotone in the height, the activation height being
  the first height of the new era (`consensus/params.h:33–36`);
* **the height conventions**: the block word is built at the tip's height with the
  era of the block being connected (`validation.cpp:2972–2981`, `validation.cpp:3472`), so the flags
  that test `height` (P2SH, UAHF, DAA) enter one block after their chain height and
  the flags that test `height + 1` (DERSIG, CLTV, CSV) enter at theirs
  (`verify_script_flags.cpp:39–69`); the era bits follow the spend height's era on
  both paths; the mempool word depends on the heights only through the eras; a
  mempool coin is the next block's (`validation.cpp:2667–2674`); Teranode's engine
  computes the same words (BDK `core/txvalidator.cpp:659–681`);
* **the UTXO's era** (Q3): the markers and the limits are the coin's, whatever the
  spend era: a pre-Genesis output spent post-Genesis or post-Chronicle runs under the
  pre-Genesis limits with the spending era's word (`411–427`, `2282–2302`);
* **the era rules per opcode**, as theorems on the machine: `OP_RETURN` (`856–871`),
  the 520-byte push (`455–456`), the disabled opcodes executed or not (`470–471`,
  `360–375`), `OP_VER` and `OP_VERIF`/`OP_VERNOTIF` (`598–608`, `773–781`), CLTV/CSV
  (`520`, `563`), the second `OP_ELSE` (`829–831`), the expansion opcodes
  (`611–618` … `730–736`);
* **the signature's hash type under the era flags** (#25, S2, 2026-09-26): the four
  refusals of `CheckSignatureEncoding` under STRICTENC (`291–306`) as theorems, each a
  rule on the signature's last byte under the word's bits; and **the checkers' reads of `nLockTime` and
  `nSequence`** (`2166–2250`, #22) as one predicate each, the verdicts CLTV and CSV
  give on a pre-Genesis coin.

Every `[SRC]` that names no other source is bitcoin-sv v1.2.2 at `879fc8b`
(`docs/PROVENANCE.md`); GoBDK's lines are its pin's (`4eab3acd`) and bsv-rs's carry
their release; a bare number is a line of `src/script/interpreter.cpp`.
-/

namespace BsvScript.Properties
open BsvScript.Params BsvScript.Machine BsvScript.Numbers

/-! ## The era selection (`src/protocol_era.cpp`) -/

/-- The ordinal of the era enum (`protocol_era.h:28–34`: `Unknown = 0`, `PreGenesis = 1`,
`PostGenesis = 2`, `PostChronicle = 3`); `IsProtocolActive` compares on it
(`protocol_era.cpp:89–103`: `era >= PostGenesis`, `era >= PostChronicle`). -/
def _root_.BsvScript.Params.Era.toNat : Era → Nat
  | .preGenesis => 1
  | .postGenesis => 2
  | .postChronicle => 3

/-- `IsProtocolActive(era, Genesis)` is `era >= PostGenesis` on the ordinal (`protocol_era.cpp:91–94`). -/
theorem Era.genesisActive_eq_toNat (e : Era) : e.genesisActive = decide (2 ≤ e.toNat) := by
  cases e <;> simp [Era.genesisActive, Era.toNat]

/-- `IsProtocolActive(era, Chronicle)` is `era >= PostChronicle` (`protocol_era.cpp:95–98`). -/
theorem Era.chronicleActive_eq_toNat (e : Era) : e.chronicleActive = decide (3 ≤ e.toNat) := by
  cases e <;> simp [Era.chronicleActive, Era.toNat]

/-- Chronicle activity implies Genesis activity: the enum is ordered (`protocol_era.h:28–34`). -/
theorem Era.chronicleActive_imp_genesisActive (e : Era) (h : e.chronicleActive = true) : e.genesisActive = true := by
  cases e <;> simp_all [Era.chronicleActive, Era.genesisActive]

/-- **The era selection's three cases** (`protocol_era.cpp:32–38`). *What it says:* every height takes one of the
three branches, each with its heights: pre-Genesis below the Genesis height, post-Genesis from it and below the
Chronicle height, post-Chronicle from both. *What it assumes:* nothing. *Why it matters:* the three height conditions
are disjoint (`h < g` against `g ≤ h`, `h < c` against `c ≤ h`), so exactly one case holds for each height. That
`Unknown` is never returned is carried by the type (`Era` has the three constructors, `Params.lean`), not by this
theorem; the statement until #32's lens 1 (A12) was the bare three-way disjunction, true of any function into
`Era`.
[LIT] https://protocol.bsvblockchain.org/specification/opcodes#protocol-eras at v1.2.2 (the heights only). -/
theorem protocolEraOf_total (g c h : Nat) :
    (protocolEraOf g c h = .preGenesis ∧ h < g)
      ∨ (protocolEraOf g c h = .postGenesis ∧ g ≤ h ∧ h < c)
      ∨ (protocolEraOf g c h = .postChronicle ∧ g ≤ h ∧ c ≤ h) := by
  unfold protocolEraOf; split_ifs <;> simp <;> omega

/-- **Pre-Genesis below the Genesis height** (`protocol_era.cpp:32–33`). -/
theorem protocolEraOf_eq_preGenesis_iff (g c h : Nat) : protocolEraOf g c h = .preGenesis ↔ h < g := by
  unfold protocolEraOf; split_ifs <;> simp <;> omega

/-- **Post-Genesis from the Genesis height, below the Chronicle height** (`protocol_era.cpp:35–36`). -/
theorem protocolEraOf_eq_postGenesis_iff (g c h : Nat) : protocolEraOf g c h = .postGenesis ↔ g ≤ h ∧ h < c := by
  unfold protocolEraOf; split_ifs <;> simp <;> omega

/-- **Post-Chronicle from the Chronicle height** (`protocol_era.cpp:38`), given the Genesis height too. -/
theorem protocolEraOf_eq_postChronicle_iff (g c h : Nat) : protocolEraOf g c h = .postChronicle ↔ g ≤ h ∧ c ≤ h := by
  unfold protocolEraOf; split_ifs <;> simp <;> omega

/-- Genesis is active at a height iff the height is at or past the Genesis height. -/
theorem genesisActive_protocolEraOf (g c h : Nat) : (protocolEraOf g c h).genesisActive = decide (g ≤ h) := by
  by_cases hg : g ≤ h
  · have h1 : ¬ h < g := by omega
    by_cases hc : h < c <;> simp [protocolEraOf, Era.genesisActive, h1, hc, hg]
  · have h1 : h < g := by omega
    simp [protocolEraOf, Era.genesisActive, h1, hg]

/-- Chronicle is active at a height iff the height is at or past both heights. -/
theorem chronicleActive_protocolEraOf (g c h : Nat) : (protocolEraOf g c h).chronicleActive = decide (g ≤ h ∧ c ≤ h) := by
  by_cases hg : g ≤ h
  · have h1 : ¬ h < g := by omega
    by_cases hc : c ≤ h
    · have h2 : ¬ h < c := by omega
      simp [protocolEraOf, Era.chronicleActive, h1, h2, hg, hc]
    · have h2 : h < c := by omega
      simp [protocolEraOf, Era.chronicleActive, h1, h2, hg, hc]
  · have h1 : h < g := by omega
    simp [protocolEraOf, Era.chronicleActive, h1, hg]

/-- **Monotone in the height**: a later height is never an earlier era. -/
theorem protocolEraOf_toNat_mono (g c h h' : Nat) (hh : h ≤ h') :
    (protocolEraOf g c h).toNat ≤ (protocolEraOf g c h').toNat := by
  unfold protocolEraOf; split_ifs <;> simp [Era.toNat] <;> omega

/-- **The activation height is the first height of the new era** ("the height of the block
where the new rules are active. It is not the height of the last block with the old
rules", `consensus/params.h:33–36`; `protocol_era.cpp:32–38`): the Genesis boundary. -/
theorem protocolEraOf_genesis_boundary (g c : Nat) (hg : 0 < g) :
    protocolEraOf g c (g - 1) = .preGenesis ∧ protocolEraOf g c g ≠ .preGenesis := by
  constructor
  · rw [protocolEraOf_eq_preGenesis_iff]; omega
  · intro h; rw [protocolEraOf_eq_preGenesis_iff] at h; omega

/-- The Chronicle boundary, likewise. -/
theorem protocolEraOf_chronicle_boundary (g c : Nat) (hgc : g < c) :
    protocolEraOf g c (c - 1) = .postGenesis ∧ protocolEraOf g c c = .postChronicle := by
  constructor
  · rw [protocolEraOf_eq_postGenesis_iff]; omega
  · rw [protocolEraOf_eq_postChronicle_iff]; omega

/-- The node's configured heights (`configscriptpolicy.cpp:156–162`; `init.cpp:2609–2616`:
the chain's unless overridden): the three cases for `NodeConfig.protocolEra`. -/
theorem protocolEra_preGenesis_iff (cfg : NodeConfig) (h : Nat) :
    cfg.protocolEra h = .preGenesis ↔ h < cfg.genesisActivationHeight :=
  protocolEraOf_eq_preGenesis_iff _ _ _

/-- The node's post-Genesis case: from its Genesis height and below its Chronicle height
(`protocolEraOf_eq_postGenesis_iff` at the configured heights). -/
theorem protocolEra_postGenesis_iff (cfg : NodeConfig) (h : Nat) :
    cfg.protocolEra h = .postGenesis ↔ cfg.genesisActivationHeight ≤ h ∧ h < cfg.chronicleActivationHeight :=
  protocolEraOf_eq_postGenesis_iff _ _ _

/-- The node's post-Chronicle case: from both configured heights (`protocolEraOf_eq_postChronicle_iff`). -/
theorem protocolEra_postChronicle_iff (cfg : NodeConfig) (h : Nat) :
    cfg.protocolEra h = .postChronicle ↔ cfg.genesisActivationHeight ≤ h ∧ cfg.chronicleActivationHeight ≤ h :=
  protocolEraOf_eq_postChronicle_iff _ _ _

/-- Genesis is active at a height for the node iff the height is at or past its Genesis height
(`genesisActive_protocolEraOf`; `IsProtocolActive`, `protocol_era.cpp:89–103`). -/
theorem protocolEra_genesisActive (cfg : NodeConfig) (h : Nat) :
    (cfg.protocolEra h).genesisActive = decide (cfg.genesisActivationHeight ≤ h) :=
  genesisActive_protocolEraOf _ _ _

/-- Chronicle is active at a height for the node iff the height is at or past both of its heights
(`chronicleActive_protocolEraOf`). -/
theorem protocolEra_chronicleActive (cfg : NodeConfig) (h : Nat) :
    (cfg.protocolEra h).chronicleActive = decide (cfg.genesisActivationHeight ≤ h ∧ cfg.chronicleActivationHeight ≤ h) :=
  chronicleActive_protocolEraOf _ _ _

/-! ## The mempool coin (`validation.cpp:2667–2674`) -/

/-- **A mempool coin is the next block's**: its era is that of the spend height on the
mempool path (the tip plus one, `validation.cpp:2545–2548`, `validation.cpp:2857`; the substitution at
`validation.cpp:2670`; BDK `core/txvalidator.cpp:267–269` with `core/txvalidator.cpp:677`; the `verifyscript`
RPC, `rpc/misc.cpp:803–809`). -/
theorem inputScriptBlockHeight_mempool (tip : Nat) : inputScriptBlockHeight mempoolHeight tip = tip + 1 := by
  simp [inputScriptBlockHeight]

/-- A confirmed coin keeps its height (`validation.cpp:2673`). -/
theorem inputScriptBlockHeight_of_ne (coin tip : Nat) (h : coin ≠ mempoolHeight) :
    inputScriptBlockHeight coin tip = coin := by
  simp [inputScriptBlockHeight, h]

/-! ## Teranode's height convention (BDK `core/txvalidator.cpp:659–681`) -/

/-- **Teranode's block word is the reference's** (`core/txvalidator.cpp:663–668`): in consensus mode
`CalculateFlags(utxoHeight, blockHeight, true)` is `Params.derive`'s block word at the
spend height `blockHeight` for a coin at `utxoHeight` (the corpus convention of
`docs/DESIGN.md` §6: BDK consensus mode takes `spend_height` as is). A mempool coin never
reaches it (`core/txvalidator.cpp:903–904`). -/
theorem bdkCalculateFlags_consensus (cfg : NodeConfig) (u h : Nat) (hu : u ≠ mempoolHeight) :
    cfg.bdkCalculateFlags u h true = cfg.flagWord h u true := by
  simp [NodeConfig.bdkCalculateFlags, NodeConfig.flagWord, inputScriptBlockHeight, hu]

/-- **Teranode's mempool word is the reference's** (`core/txvalidator.cpp:669–674`, `core/txvalidator.cpp:677`): in policy mode
`CalculateFlags(utxoHeight, tip, false)` is the mempool word at the spend height `tip + 1`
for the coin's resolved height (the corpus convention: BDK policy mode takes
`spend_height − 1` as the tip); Teranode has no promiscuous word. -/
theorem bdkCalculateFlags_policy (cfg : NodeConfig) (u tip : Nat) (hp : cfg.promiscuousMempoolFlags = none) :
    cfg.bdkCalculateFlags u tip false = cfg.flagWord (tip + 1) (inputScriptBlockHeight u tip) false := by
  simp [NodeConfig.bdkCalculateFlags, NodeConfig.flagWord, hp]

/-! ## The word by height: the tip's-height convention, flag by flag -/

/-- The block word is built by `GetBlockScriptFlags(config, tip)` (`validation.cpp:2972–2981`: the
tip's height read at `validation.cpp:2977`, the era of `height + 1` at `validation.cpp:2980`) with the
block's parent (`validation.cpp:3472`), so for a spend in block `h ≥ 1` the flags that test `height`
(`verify_script_flags.cpp:39`, `verify_script_flags.cpp:55`, `verify_script_flags.cpp:65`) test `h − 1`:
**P2SH enters the block word of block `p2shHeight + 1`** (mainnet 173,806; the comment at
`verify_script_flags.cpp:38` names 173,805, the code's height is the parent's: recorded on #20). Real history does not
part the two: block 173,805 (106 transactions, 256 inputs) spends and creates no P2SH-shaped output (`docs/records/20260928-115150-replay-173805-s3.md`). -/
theorem flagWord_block_p2sh (cfg : NodeConfig) (h u : Nat) (hh : 1 ≤ h) :
    (cfg.flagWord h u true).p2sh = decide (cfg.chain.p2shHeight + 1 ≤ h) := by
  simp [NodeConfig.flagWord, blockScriptFlags, inputScriptVerifyFlags, Flags.union, Flags.none, decide_eq_decide]
  omega

/-- **DERSIG enters at `BIP66Height`** (`verify_script_flags.cpp:43` tests `height + 1`). -/
theorem flagWord_block_derSig (cfg : NodeConfig) (h u : Nat) (hh : 1 ≤ h) :
    (cfg.flagWord h u true).derSig = decide (cfg.chain.bip66Height ≤ h) := by
  simp [NodeConfig.flagWord, blockScriptFlags, inputScriptVerifyFlags, Flags.union, Flags.none, decide_eq_decide]
  omega

/-- **CLTV enters at `BIP65Height`** (`verify_script_flags.cpp:47` tests `height + 1`). -/
theorem flagWord_block_cltv (cfg : NodeConfig) (h u : Nat) (hh : 1 ≤ h) :
    (cfg.flagWord h u true).checkLockTimeVerify = decide (cfg.chain.bip65Height ≤ h) := by
  simp [NodeConfig.flagWord, blockScriptFlags, inputScriptVerifyFlags, Flags.union, Flags.none, decide_eq_decide]
  omega

/-- **CSV enters at `CSVHeight`** (`verify_script_flags.cpp:51` tests `height + 1`). -/
theorem flagWord_block_csv (cfg : NodeConfig) (h u : Nat) (hh : 1 ≤ h) :
    (cfg.flagWord h u true).checkSequenceVerify = decide (cfg.chain.csvHeight ≤ h) := by
  simp [NodeConfig.flagWord, blockScriptFlags, inputScriptVerifyFlags, Flags.union, Flags.none, decide_eq_decide]
  omega

/-- **STRICTENC and FORKID enter one block after `uahfHeight`** (`verify_script_flags.cpp:55–59` test `height`: the
UAHF height is the parent's by design, the fork block being `uahfHeight + 1`). -/
theorem flagWord_block_strictEnc (cfg : NodeConfig) (h u : Nat) (hh : 1 ≤ h) :
    (cfg.flagWord h u true).strictEnc = decide (cfg.chain.uahfHeight + 1 ≤ h) := by
  simp [NodeConfig.flagWord, blockScriptFlags, inputScriptVerifyFlags, Flags.union, Flags.none, decide_eq_decide]
  omega

/-- **FORKID enters with STRICTENC, one block after `uahfHeight`** (`verify_script_flags.cpp:55–59`: the two
are set in one branch testing `height`). -/
theorem flagWord_block_forkid (cfg : NodeConfig) (h u : Nat) (hh : 1 ≤ h) :
    (cfg.flagWord h u true).enableSighashForkid = decide (cfg.chain.uahfHeight + 1 ≤ h) := by
  simp [NodeConfig.flagWord, blockScriptFlags, inputScriptVerifyFlags, Flags.union, Flags.none, decide_eq_decide]
  omega

/-- **LOW_S and NULLFAIL enter one block after `daaHeight`** (`verify_script_flags.cpp:65–69` test `height`).
[LIT] https://protocol.bsvblockchain.org/specification/upgrade-history#nov-2017 at v1.2.2. -/
theorem flagWord_block_lowS (cfg : NodeConfig) (h u : Nat) (hh : 1 ≤ h) :
    (cfg.flagWord h u true).lowS = decide (cfg.chain.daaHeight + 1 ≤ h) := by
  simp [NodeConfig.flagWord, blockScriptFlags, inputScriptVerifyFlags, Flags.union, Flags.none, decide_eq_decide]
  omega

/-- **NULLFAIL enters with LOW_S, one block after `daaHeight`** (`verify_script_flags.cpp:65–69`: one branch
testing `height`).
[LIT] https://protocol.bsvblockchain.org/specification/upgrade-history#nov-2017 at v1.2.2. -/
theorem flagWord_block_nullFail (cfg : NodeConfig) (h u : Nat) (hh : 1 ≤ h) :
    (cfg.flagWord h u true).nullFail = decide (cfg.chain.daaHeight + 1 ≤ h) := by
  simp [NodeConfig.flagWord, blockScriptFlags, inputScriptVerifyFlags, Flags.union, Flags.none, decide_eq_decide]
  omega

/-- **The era bits follow the eras, on both paths** (the block word's era is the block's,
`validation.cpp:2980`; the mempool word's the next block's, `validation.cpp:1031`; the per-input word
`policy.h:225–244`): GENESIS and SIGPUSHONLY iff Genesis is active at the spend height
(`verify_script_flags.cpp:71–75`, `policy.h:229–232`, `policy.h:216–220`), CHRONICLE iff
Chronicle is (`verify_script_flags.cpp:77–78`, `policy.h:195–197`), the two UTXO markers by the coin's era
(`policy.h:234–241`). Without promiscuous flags. -/
theorem flagWord_era_bits (cfg : NodeConfig) (h u : Nat) (c : Bool) (hp : cfg.promiscuousMempoolFlags = none) :
    (cfg.flagWord h u c).genesis = (cfg.protocolEra h).genesisActive ∧
    (cfg.flagWord h u c).sigPushOnly = (cfg.protocolEra h).genesisActive ∧
    (cfg.flagWord h u c).chronicle = (cfg.protocolEra h).chronicleActive ∧
    (cfg.flagWord h u c).utxoAfterGenesis = (cfg.protocolEra u).genesisActive ∧
    (cfg.flagWord h u c).utxoAfterChronicle = (cfg.protocolEra u).chronicleActive := by
  cases c <;> cases hE : cfg.protocolEra h <;> cases hU : cfg.protocolEra u <;> cases hs : cfg.requireStandard <;>
    simp [NodeConfig.flagWord, hE, hU, hs, hp, blockScriptFlags, mempoolScriptFlags, standardScriptVerifyFlags,
          mandatoryFlags, mandatoryPreChronicle, mandatoryPostChronicle, standardOnly, inputScriptVerifyFlags,
          Flags.union, Flags.none, Era.genesisActive, Era.chronicleActive]

/-- **GENESIS is in the word from the Genesis height** (the "+1" convention of the era:
the block word of block 620,538 carries it on mainnet). -/
theorem flagWord_genesis (cfg : NodeConfig) (h u : Nat) (c : Bool) (hp : cfg.promiscuousMempoolFlags = none) :
    (cfg.flagWord h u c).genesis = decide (cfg.genesisActivationHeight ≤ h) := by
  rw [(flagWord_era_bits cfg h u c hp).1, protocolEra_genesisActive]

/-- **SIGPUSHONLY is in the word from the Genesis height**, on both paths (the block word's Genesis branch,
`verify_script_flags.cpp:71–75`; the per-input word, `policy.h:229–232`). Without promiscuous flags. -/
theorem flagWord_sigPushOnly (cfg : NodeConfig) (h u : Nat) (c : Bool) (hp : cfg.promiscuousMempoolFlags = none) :
    (cfg.flagWord h u c).sigPushOnly = decide (cfg.genesisActivationHeight ≤ h) := by
  rw [(flagWord_era_bits cfg h u c hp).2.1, protocolEra_genesisActive]

/-- **CHRONICLE is in the word from the Chronicle height.** -/
theorem flagWord_chronicle (cfg : NodeConfig) (h u : Nat) (c : Bool) (hp : cfg.promiscuousMempoolFlags = none) :
    (cfg.flagWord h u c).chronicle = decide (cfg.genesisActivationHeight ≤ h ∧ cfg.chronicleActivationHeight ≤ h) := by
  rw [(flagWord_era_bits cfg h u c hp).2.2.1, protocolEra_chronicleActive]

/-- **The UTXO markers are the coin's** (`policy.h:234–241`). -/
theorem flagWord_utxoAfterGenesis (cfg : NodeConfig) (h u : Nat) (c : Bool) (hp : cfg.promiscuousMempoolFlags = none) :
    (cfg.flagWord h u c).utxoAfterGenesis = decide (cfg.genesisActivationHeight ≤ u) := by
  rw [(flagWord_era_bits cfg h u c hp).2.2.2.1, protocolEra_genesisActive]

/-- **The coin's Chronicle marker is its own era's** (`policy.h:238–241`): set iff the coin's height is at or
past both configured heights. Without promiscuous flags. -/
theorem flagWord_utxoAfterChronicle (cfg : NodeConfig) (h u : Nat) (c : Bool) (hp : cfg.promiscuousMempoolFlags = none) :
    (cfg.flagWord h u c).utxoAfterChronicle = decide (cfg.genesisActivationHeight ≤ u ∧ cfg.chronicleActivationHeight ≤ u) := by
  rw [(flagWord_era_bits cfg h u c hp).2.2.2.2, protocolEra_chronicleActive]

/-- **The mempool word depends on the heights only through the eras** (`GetScriptVerifyFlags(era, …)`,
`verify_script_flags.cpp:11–30`, `policy.h:208–244`): two spends whose spend heights and
coin heights fall in the same eras get the same relay word, whatever the heights. The
block word has no such property (the theorems above). -/
theorem flagWord_mempool_of_eras (cfg : NodeConfig) (h h' u u' : Nat)
    (hE : cfg.protocolEra h = cfg.protocolEra h') (hU : cfg.protocolEra u = cfg.protocolEra u') :
    cfg.flagWord h u false = cfg.flagWord h' u' false := by
  simp [NodeConfig.flagWord, hE, hU]

/-- The block path never reads the promiscuous word: the coin's Genesis marker is the
coin's era's unconditionally (the twin of `flagWord_utxoAfterGenesis` without its hypothesis). -/
theorem flagWord_block_utxoAfterGenesis (cfg : NodeConfig) (h u : Nat) :
    (cfg.flagWord h u true).utxoAfterGenesis = (cfg.protocolEra u).genesisActive := by
  cases hU : cfg.protocolEra u <;>
    simp [NodeConfig.flagWord, Flags.union, blockScriptFlags, inputScriptVerifyFlags, Flags.none,
          Era.genesisActive, Era.chronicleActive, hU]

/-- The block path never reads the promiscuous word: the UTXO era it carries is the
coin's unconditionally (the twin of `flagWord_utxoEra` without its hypothesis). -/
theorem flagWord_block_utxoEra (cfg : NodeConfig) (h u : Nat) : (cfg.flagWord h u true).utxoEra = cfg.protocolEra u := by
  cases hU : cfg.protocolEra u <;>
    simp [NodeConfig.flagWord, Flags.utxoEra, Flags.union, blockScriptFlags, inputScriptVerifyFlags, Flags.none,
          Era.genesisActive, Era.chronicleActive, hU]

/-! ## The derivation and the coin's era (Q3) -/

/-- The setters leave the era selection alone (`NodeConfig.normalize` touches the five limit settings only,
`configscriptpolicy.cpp:164–308`): the normalized configuration's era of every height is the configuration's. -/
theorem normalize_protocolEra (cfg : NodeConfig) (x : Nat) : cfg.normalize.protocolEra x = cfg.protocolEra x := by
  simp [NodeConfig.normalize, NodeConfig.protocolEra]

/-- The setters leave the promiscuous word alone. -/
theorem normalize_promiscuous (cfg : NodeConfig) : cfg.normalize.promiscuousMempoolFlags = cfg.promiscuousMempoolFlags := by
  simp [NodeConfig.normalize]

/-- The setters leave the Genesis height alone. -/
theorem normalize_genesisActivationHeight (cfg : NodeConfig) : cfg.normalize.genesisActivationHeight = cfg.genesisActivationHeight := by
  simp [NodeConfig.normalize]

/-- The setters leave the Chronicle height alone. -/
theorem normalize_chronicleActivationHeight (cfg : NodeConfig) : cfg.normalize.chronicleActivationHeight = cfg.chronicleActivationHeight := by
  simp [NodeConfig.normalize]

/-- `derive`'s word is the normalized configuration's `flagWord` (the setters leave the heights alone). -/
theorem derive_flags (cfg : NodeConfig) (h u : Nat) (c : Bool) : (derive cfg h u c).flags = cfg.normalize.flagWord h u c := rfl

/-- **The interpreter reads the coin's era** (`utxo_era`, `2269–2280`; `411–427`): under
`Params.derive` it is the era of the coin's height, whatever the spend height, on the block path and on the mempool
path of a node with no promiscuous word (`hp`). On a chain whose `RequireStandard()` is false a promiscuous word
replaces the mempool word and gains FORKID (`verify_script_flags.cpp:21–25`), passes the skip mask, which cannot
clear a UTXO marker (`validation.cpp:1328–1330`, `rpc/rawtransaction.cpp:1486`), and is OR-ed with the per-input word
(`validation.cpp:2696–2701`): one carrying `SCRIPT_UTXO_AFTER_GENESIS` makes that node's mempool path read a
pre-Genesis coin as post-Genesis, and one carrying `SCRIPT_UTXO_AFTER_CHRONICLE` alone refuses a pre-Genesis
coin (`SCRIPT_ERR_INVALID_FLAGS`, `interpreter.cpp:2312–2313`) and makes a post-Genesis coin, whose per-input word
carries the Genesis marker, read as post-Chronicle (`interpreter.cpp:2269–2274`). -/
theorem derive_utxoEra (cfg : NodeConfig) (h u : Nat) (c : Bool) (hp : cfg.promiscuousMempoolFlags = none) :
    (derive cfg h u c).flags.utxoEra = cfg.protocolEra u := by
  rw [derive_flags, flagWord_utxoEra _ _ _ _ (by rw [normalize_promiscuous]; exact hp), normalize_protocolEra]

/-- **A pre-Genesis coin carries the pre-Genesis limits, whatever the spend era**, on the block path and on the
mempool path of a node with no promiscuous word (`hp`; `derive_utxoEra` names the route it excludes)
(`make_verify_script_params`, `2282–2302`, over the getters' `!utxo_after_genesis` branches,
`configscriptpolicy.cpp:65–154`): 500 ops, 4-byte numbers, 10,000-byte scripts, 20 keys, an
unbounded memory budget. -/
theorem derive_limits_preGenesis (cfg : NodeConfig) (h u : Nat) (c : Bool) (hp : cfg.promiscuousMempoolFlags = none)
    (hu : u < cfg.genesisActivationHeight) :
    (derive cfg h u c).limits = preGenesisLimits := by
  have hafter : (cfg.normalize.flagWord h u c).utxoAfterGenesis = false := by
    rw [flagWord_utxoAfterGenesis _ _ _ _ (by rw [normalize_promiscuous]; exact hp), normalize_genesisActivationHeight]
    simp; omega
  simp [derive, NodeConfig.limitsFor, hafter, preGenesisLimits]

/-- **A post-Genesis coin on the block path carries the consensus limits of its era**
(the getters' `consensus` branches): unbounded ops, size and keys, the era's number width
(750,000 or 32,000,000), the node's `maxstackmemoryusageconsensus`. -/
theorem derive_limits_block_postGenesis (cfg : NodeConfig) (h u : Nat) (hu : cfg.genesisActivationHeight ≤ u) :
    (derive cfg h u true).limits = eraConsensusLimits (cfg.protocolEra u) cfg.normalize.maxStackMemoryUsageConsensus := by
  have hafter : (cfg.normalize.flagWord h u true).utxoAfterGenesis = true := by
    rw [flagWord_block_utxoAfterGenesis, normalize_protocolEra, protocolEra_genesisActive]
    simp; omega
  have hera : (cfg.normalize.flagWord h u true).utxoEra = cfg.protocolEra u := by
    rw [flagWord_block_utxoEra, normalize_protocolEra]
  simp [derive, NodeConfig.limitsFor, hafter, hera, eraConsensusLimits]

/-- **Q3 (`docs/DESIGN.md` §9): a pre-Genesis output spent after Genesis.** *What it says:*
for a coin created below the Genesis height, whatever the spend height, on the block path and on the
mempool path of a node with no promiscuous word (`hp`; the route it excludes is in `derive_utxoEra`), the
interpreter reads the coin's era as pre-Genesis (no UTXO marker, `411–427`), the limits
are the pre-Genesis constants (`2282–2302`, `configscriptpolicy.cpp:65–154`), and the
spending era's bits (GENESIS, SIGPUSHONLY, CHRONICLE) are the spend height's
(`policy.h:225–244`, `verify_script_flags.cpp:71–78`). *Why it matters:* the pre-Genesis
UTXO rules (the 520-byte element, the 1,000-element stack, 4-byte numbers, `OP_RETURN`
invalid, P2SH, CLTV/CSV live, the second `OP_ELSE`) hang on the coin's era, and the version
gate and push-only rule on the spend's: the two are separate parameters of one word. -/
theorem derive_preGenesis_coin (cfg : NodeConfig) (h u : Nat) (c : Bool) (hp : cfg.promiscuousMempoolFlags = none)
    (hu : u < cfg.genesisActivationHeight) :
    (derive cfg h u c).flags.utxoEra = .preGenesis ∧
    (derive cfg h u c).limits = preGenesisLimits ∧
    (derive cfg h u c).flags.genesis = decide (cfg.genesisActivationHeight ≤ h) ∧
    (derive cfg h u c).flags.sigPushOnly = decide (cfg.genesisActivationHeight ≤ h) ∧
    (derive cfg h u c).flags.chronicle = decide (cfg.genesisActivationHeight ≤ h ∧ cfg.chronicleActivationHeight ≤ h) := by
  have hp' : cfg.normalize.promiscuousMempoolFlags = none := by rw [normalize_promiscuous]; exact hp
  refine ⟨?_, derive_limits_preGenesis cfg h u c hp hu, ?_, ?_, ?_⟩
  · rw [derive_utxoEra cfg h u c hp, protocolEra_preGenesis_iff]; exact hu
  · rw [derive_flags, flagWord_genesis _ _ _ _ hp', normalize_genesisActivationHeight]
  · rw [derive_flags, flagWord_sigPushOnly _ _ _ _ hp', normalize_genesisActivationHeight]
  · rw [derive_flags, flagWord_chronicle _ _ _ _ hp', normalize_genesisActivationHeight, normalize_chronicleActivationHeight]

/-- The machine reads the coin's era from the original word (`mkEnv`, `411–427`): neither
STRICTENC-from-FORKID (`2315–2319`) nor the version gate (`Flags.gate`) touches the two markers. -/
theorem mkEnv_utxoEra (p : EvalParams) (ctx : Context) (f0 : Flags) (cd : Option Bytes) :
    (mkEnv p ctx f0 cd).utxoEra = f0.utxoEra := rfl

/-- STRICTENC from FORKID (`2315–2319`, `Flags.forkAdjust`) leaves the two UTXO markers, so the coin's era. -/
theorem forkAdjust_utxoEra (f : Flags) : f.forkAdjust.utxoEra = f.utxoEra := by
  simp [Flags.forkAdjust, Flags.utxoEra]; split_ifs <;> rfl

/-- The version gate (`Flags.gate`, `40–44`) leaves the two UTXO markers, so the coin's era, in both branches: the
word unchanged where `EnforceNonMalleability` holds, the seven restrictions cleared where it does not. -/
theorem gate_utxoEra (f : Flags) (v : Int) : (f.gate v).utxoEra = f.utxoEra := by
  simp [Flags.gate, Flags.utxoEra]; split_ifs <;> rfl

/-! ## The era rules per opcode (the machine) -/

/-- A pre-Genesis coin is neither post-Genesis nor post-Chronicle in the environment. -/
theorem utxoEra_of_not_afterGenesis (env : Env) (h : env.utxoAfterGenesis = false) : env.utxoEra = .preGenesis := by
  cases he : env.utxoEra <;> simp_all [Env.utxoAfterGenesis]

/-- A coin that is not post-Genesis is not post-Chronicle either (its era is pre-Genesis,
`utxoEra_of_not_afterGenesis`). -/
theorem utxoAfterChronicle_of_not_afterGenesis (env : Env) (h : env.utxoAfterGenesis = false) :
    env.utxoAfterChronicle = false := by
  simp [Env.utxoAfterChronicle, utxoEra_of_not_afterGenesis env h]

/-- **`OP_RETURN` on a pre-Genesis coin fails** (`856–871`, `867–869`): executed, it is
`SCRIPT_ERR_OP_RETURN` whatever the spend era. -/
theorem execFlow_return_preGenesis (exec : OpExec) (env : Env) (data : Bytes) (fExec : Bool) (st : State)
    (hg : env.utxoAfterGenesis = false) :
    execFlow exec env Op.OP_RETURN data fExec st = .fail .opReturn := by
  simp [execFlow, hg, Op.OP_RETURN, Op.OP_1NEGATE, Op.OP_1, Op.OP_16, Op.OP_NOP, Op.OP_CHECKLOCKTIMEVERIFY,
        Op.OP_CHECKSEQUENCEVERIFY, Op.OP_VER, Op.OP_NOP1, Op.OP_NOP9, Op.OP_NOP10, Op.OP_VERIF, Op.OP_VERNOTIF,
        Op.OP_IF, Op.OP_NOTIF, Op.OP_ELSE, Op.OP_ENDIF, Op.OP_VERIFY]

/-- **A top-level `OP_RETURN` on a post-Genesis coin ends the script as success** (`858–861`). -/
theorem execFlow_return_postGenesis_top (exec : OpExec) (env : Env) (data : Bytes) (fExec : Bool) (st : State)
    (hg : env.utxoAfterGenesis = true) (hc : st.cond.empty = true) :
    execFlow exec env Op.OP_RETURN data fExec st = .done := by
  simp [execFlow, hg, hc, Op.OP_RETURN, Op.OP_1NEGATE, Op.OP_1, Op.OP_16, Op.OP_NOP, Op.OP_CHECKLOCKTIMEVERIFY,
        Op.OP_CHECKSEQUENCEVERIFY, Op.OP_VER, Op.OP_NOP1, Op.OP_NOP9, Op.OP_NOP10, Op.OP_VERIF, Op.OP_VERNOTIF,
        Op.OP_IF, Op.OP_NOTIF, Op.OP_ELSE, Op.OP_ENDIF, Op.OP_VERIFY]

/-- **A nested `OP_RETURN` on a post-Genesis coin marks the rest as unexecuted** (`863–866`). -/
theorem execFlow_return_postGenesis_nested (exec : OpExec) (env : Env) (data : Bytes) (fExec : Bool) (st : State)
    (hg : env.utxoAfterGenesis = true) (hc : st.cond.empty = false) :
    execFlow exec env Op.OP_RETURN data fExec st = .cont { st with nonTopLevelReturn := true } := by
  simp [execFlow, hg, hc, Op.OP_RETURN, Op.OP_1NEGATE, Op.OP_1, Op.OP_16, Op.OP_NOP, Op.OP_CHECKLOCKTIMEVERIFY,
        Op.OP_CHECKSEQUENCEVERIFY, Op.OP_VER, Op.OP_NOP1, Op.OP_NOP9, Op.OP_NOP10, Op.OP_VERIF, Op.OP_VERNOTIF,
        Op.OP_IF, Op.OP_NOTIF, Op.OP_ELSE, Op.OP_ENDIF, Op.OP_VERIFY]

/-- **A push above 520 bytes fails on a pre-Genesis coin** (`455–456`, `script.h:29`), executed
or not, before the op count, the disabled check and the push itself. -/
theorem loop_pushSize_preGenesis (exec : OpExec) (env : Env) (op : Nat) (rest data : Bytes) (k : Nat) (st : State)
    (hg : env.utxoAfterGenesis = false) (hop : getOpTail op rest = some (data, k))
    (hlen : Consensus.maxScriptElementSizeBeforeGenesis < data.length) :
    loop exec env (op :: rest) st = (.err .pushSize, st) := by
  rw [loop.eq_2]; simp [hop, hg, hlen]

/-- **A disabled opcode fails even unexecuted on a pre-Genesis coin** (`470–471`:
`IsOpcodeDisabled(opcode, utxoEra) && (!utxo_after_genesis || fExec)`; `360–375`:
`OP_2MUL`/`OP_2DIV` unless the coin is post-Chronicle). The op count is charged first (`466`). -/
theorem loop_disabled_preGenesis (exec : OpExec) (env : Env) (op : Nat) (rest : Bytes) (st : State)
    (hg : env.utxoAfterGenesis = false) (hop : op = Op.OP_2MUL ∨ op = Op.OP_2DIV)
    (hcount : st.opCount + 1 ≤ env.params.limits.maxOpsPerScript) :
    loop exec env (op :: rest) st = (.err .disabledOpcode, { st with opCount := st.opCount + 1 }) := by
  have hera := utxoEra_of_not_afterGenesis env hg
  have hc' : ¬ (st.opCount + 1 > env.params.limits.maxOpsPerScript) := by omega
  rw [loop.eq_2]
  rcases hop with rfl | rfl <;>
    simp [getOpTail, hg, hera, isOpcodeDisabled, hc', Op.OP_2MUL, Op.OP_2DIV, Op.OP_PUSHDATA4, Op.OP_16,
          Consensus.maxScriptElementSizeBeforeGenesis]

/-- **A disabled opcode in a dead branch is skipped on a post-Genesis, pre-Chronicle coin**
(`470–471`: `fExec` false and the coin after Genesis; `360–375`): the loop moves on with the op
count charged (`466`). Executed, it fails (`execStep` never reaches it: `470` precedes `473`). -/
theorem loop_disabled_postGenesis_dead (exec : OpExec) (env : Env) (op : Nat) (rest : Bytes) (st : State)
    (hera : env.utxoEra = .postGenesis) (hop : op = Op.OP_2MUL ∨ op = Op.OP_2DIV)
    (hdead : st.cond.isActive = false) (hcount : st.opCount + 1 ≤ env.params.limits.maxOpsPerScript) :
    loop exec env (op :: rest) st = loop exec env rest { st with opCount := st.opCount + 1 } := by
  have hg : env.utxoAfterGenesis = true := by simp [Env.utxoAfterGenesis, hera]
  have hc' : ¬ (st.opCount + 1 > env.params.limits.maxOpsPerScript) := by omega
  rw [loop.eq_2]
  rcases hop with rfl | rfl <;>
    simp [getOpTail, hg, hera, isOpcodeDisabled, hdead, hc', execStep, Op.OP_2MUL, Op.OP_2DIV, Op.OP_PUSHDATA4,
          Op.OP_16, Op.OP_IF, Op.OP_ENDIF, Op.OP_CODESEPARATOR]

/-- **`OP_VER` fails on a pre-Chronicle coin** (`598–601`): `SCRIPT_ERR_BAD_OPCODE` when
executed; post-Chronicle it pushes the transaction version (`603–606`). -/
theorem execFlow_ver_preChronicle (exec : OpExec) (env : Env) (data : Bytes) (fExec : Bool) (st : State)
    (hc : env.utxoAfterChronicle = false) :
    execFlow exec env Op.OP_VER data fExec st = .fail .badOpcode := by
  simp [execFlow, hc, Op.OP_VER, Op.OP_1NEGATE, Op.OP_1, Op.OP_16, Op.OP_NOP, Op.OP_CHECKLOCKTIMEVERIFY,
        Op.OP_CHECKSEQUENCEVERIFY]

/-- **`OP_VERIF`/`OP_VERNOTIF` fail on a pre-Genesis coin even unexecuted** (`773–781`: the
skip at `777` needs `utxo_after_genesis`). -/
theorem execFlow_verif_preGenesis (exec : OpExec) (env : Env) (op : Nat) (data : Bytes) (fExec : Bool) (st : State)
    (hg : env.utxoAfterGenesis = false) (hop : op = Op.OP_VERIF ∨ op = Op.OP_VERNOTIF) :
    execFlow exec env op data fExec st = .fail .badOpcode := by
  have hc := utxoAfterChronicle_of_not_afterGenesis env hg
  rcases hop with rfl | rfl <;>
    simp [execFlow, hg, hc, Op.OP_VERIF, Op.OP_VERNOTIF, Op.OP_1NEGATE, Op.OP_1, Op.OP_16, Op.OP_NOP,
          Op.OP_CHECKLOCKTIMEVERIFY, Op.OP_CHECKSEQUENCEVERIFY, Op.OP_VER, Op.OP_NOP1, Op.OP_NOP9, Op.OP_NOP10]

/-- **`OP_VERIF`/`OP_VERNOTIF` are skipped unexecuted on a post-Genesis, pre-Chronicle coin**
(`777–778`) and fail executed (`780`). -/
theorem execFlow_verif_postGenesis_preChronicle (exec : OpExec) (env : Env) (op : Nat) (data : Bytes) (st : State)
    (hg : env.utxoAfterGenesis = true) (hc : env.utxoAfterChronicle = false) (hop : op = Op.OP_VERIF ∨ op = Op.OP_VERNOTIF) :
    execFlow exec env op data false st = .cont st ∧ execFlow exec env op data true st = .fail .badOpcode := by
  rcases hop with rfl | rfl <;>
    simp [execFlow, hg, hc, Op.OP_VERIF, Op.OP_VERNOTIF, Op.OP_1NEGATE, Op.OP_1, Op.OP_16, Op.OP_NOP,
          Op.OP_CHECKLOCKTIMEVERIFY, Op.OP_CHECKSEQUENCEVERIFY, Op.OP_VER, Op.OP_NOP1, Op.OP_NOP9, Op.OP_NOP10]

/-- **CLTV is a NOP on a post-Genesis coin** (`520`: `|| utxo_after_genesis`), discouraged under
the policy flag (`522–526`). -/
theorem execCltv_nop_postGenesis (env : Env) (st : State) (hg : env.utxoAfterGenesis = true) :
    execCltv env st = (if env.params.flags.discourageUpgradableNops then .fail .discourageUpgradableNops else .cont st) := by
  simp [execCltv, hg]

/-- **CLTV is live on a pre-Genesis coin under the flag** (`520`, `546–556`): an unsatisfied lock
time is `SCRIPT_ERR_UNSATISFIED_LOCKTIME`, whatever the spend era. -/
theorem execCltv_unsatisfied_preGenesis (env : Env) (st : State) (top : Bytes) (rest : List Bytes) (n : Int)
    (hg : env.utxoAfterGenesis = false) (hf : env.params.flags.checkLockTimeVerify = true)
    (hs : st.stack = top :: rest) (hr : readNum top env.requireMinimal 5 = .ok n) (hn : 0 ≤ n)
    (hck : env.ctx.checkLockTime n = false) :
    execCltv env st = .fail .unsatisfiedLocktime := by
  have hn' : ¬ n < 0 := by omega
  simp [execCltv, hg, hf, hs, hr, hn', hck]

/-- The satisfied case leaves the operand on the stack (`559`: only `break`). -/
theorem execCltv_satisfied_preGenesis (env : Env) (st : State) (top : Bytes) (rest : List Bytes) (n : Int)
    (hg : env.utxoAfterGenesis = false) (hf : env.params.flags.checkLockTimeVerify = true)
    (hs : st.stack = top :: rest) (hr : readNum top env.requireMinimal 5 = .ok n) (hn : 0 ≤ n)
    (hck : env.ctx.checkLockTime n = true) :
    execCltv env st = .cont st := by
  have hn' : ¬ n < 0 := by omega
  simp [execCltv, hg, hf, hs, hr, hn', hck]

/-- **CSV is a NOP on a post-Genesis coin** (`563`), discouraged under the policy flag (`565–569`). -/
theorem execCsv_nop_postGenesis (env : Env) (st : State) (hg : env.utxoAfterGenesis = true) :
    execCsv env st = (if env.params.flags.discourageUpgradableNops then .fail .discourageUpgradableNops else .cont st) := by
  simp [execCsv, hg]

/-- **CSV is live on a pre-Genesis coin under the flag** (`563`, `577–595`): an operand without the
disable bit whose relative lock is unsatisfied is `SCRIPT_ERR_UNSATISFIED_LOCKTIME`. -/
theorem execCsv_unsatisfied_preGenesis (env : Env) (st : State) (top : Bytes) (rest : List Bytes) (n : Int)
    (hg : env.utxoAfterGenesis = false) (hf : env.params.flags.checkSequenceVerify = true)
    (hs : st.stack = top :: rest) (hr : readNum top env.requireMinimal 5 = .ok n) (hn : 0 ≤ n)
    (hbit : Nat.testBit n.toNat 31 = false) (hck : env.ctx.checkSequence n = false) :
    execCsv env st = .fail .unsatisfiedLocktime := by
  have hn' : ¬ n < 0 := by omega
  simp [execCsv, hg, hf, hs, hr, hn', hbit, hck]

/-- The satisfied case leaves the operand on the stack (`593–596`: only `break`), CLTV's twin
(`execCltv_satisfied_preGenesis`); with `execCsv_unsatisfied_preGenesis` and `checkSequence_iff` this is CSV's
verdict on a pre-Genesis coin under the flag once a non-negative operand without the disable flag is read. The
theorems assume that read (`hs`, `hr`, `hn`); CSV's other outcomes there are the empty stack (`571–572`), the
operand over five bytes or not minimal (`577`, caught at `1807–1814`) and the negative operand (`582–583`). -/
theorem execCsv_satisfied_preGenesis (env : Env) (st : State) (top : Bytes) (rest : List Bytes) (n : Int)
    (hg : env.utxoAfterGenesis = false) (hf : env.params.flags.checkSequenceVerify = true)
    (hs : st.stack = top :: rest) (hr : readNum top env.requireMinimal 5 = .ok n) (hn : 0 ≤ n)
    (hbit : Nat.testBit n.toNat 31 = false) (hck : env.ctx.checkSequence n = true) :
    execCsv env st = .cont st := by
  have hn' : ¬ n < 0 := by omega
  simp [execCsv, hg, hf, hs, hr, hn', hbit, hck]

/-- **An operand with the disable flag makes CSV a NOP** (`585–590`: `nSequence & SEQUENCE_LOCKTIME_DISABLE_FLAG`
non-zero, `break` before the checker; bit 31, `transaction.h:106`): the operand's own bit, whatever the spent input's
sequence, so the checker's test of the input's bit (`checkSequence_disable_flag`, `2220–2222`) is never reached. -/
theorem execCsv_disable_flag_operand (env : Env) (st : State) (top : Bytes) (rest : List Bytes) (n : Int)
    (hg : env.utxoAfterGenesis = false) (hf : env.params.flags.checkSequenceVerify = true)
    (hs : st.stack = top :: rest) (hr : readNum top env.requireMinimal 5 = .ok n) (hn : 0 ≤ n)
    (hbit : Nat.testBit n.toNat 31 = true) :
    execCsv env st = .cont st := by
  have hn' : ¬ n < 0 := by omega
  simp [execCsv, hg, hf, hs, hr, hn', hbit]

/-- **A second `OP_ELSE` toggles again on a pre-Genesis coin** (`829–831` test
`has_op_else() && utxo_after_genesis`; `conditional_tracker.cpp:57–65`). -/
theorem execFlow_else_preGenesis (exec : OpExec) (env : Env) (data : Bytes) (fExec : Bool) (st : State)
    (hg : env.utxoAfterGenesis = false) (hne : st.cond.empty = false) :
    execFlow exec env Op.OP_ELSE data fExec st = .cont { st with cond := st.cond.opElse } := by
  simp [execFlow, hg, hne, Op.OP_ELSE, Op.OP_1NEGATE, Op.OP_1, Op.OP_16, Op.OP_NOP, Op.OP_CHECKLOCKTIMEVERIFY,
        Op.OP_CHECKSEQUENCEVERIFY, Op.OP_VER, Op.OP_NOP1, Op.OP_NOP9, Op.OP_NOP10, Op.OP_VERIF, Op.OP_VERNOTIF,
        Op.OP_IF, Op.OP_NOTIF]

/-- **A second `OP_ELSE` is unbalanced on a post-Genesis coin** (`829–831`; `conditional_tracker.cpp:51–55`). -/
theorem execFlow_else_postGenesis_second (exec : OpExec) (env : Env) (data : Bytes) (fExec : Bool) (st : State)
    (hg : env.utxoAfterGenesis = true) (hne : st.cond.empty = false) (he : st.cond.hasOpElse = true) :
    execFlow exec env Op.OP_ELSE data fExec st = .fail .unbalancedConditional := by
  simp [execFlow, hg, hne, he, Op.OP_ELSE, Op.OP_1NEGATE, Op.OP_1, Op.OP_16, Op.OP_NOP, Op.OP_CHECKLOCKTIMEVERIFY,
        Op.OP_CHECKSEQUENCEVERIFY, Op.OP_VER, Op.OP_NOP1, Op.OP_NOP9, Op.OP_NOP10, Op.OP_VERIF, Op.OP_VERNOTIF,
        Op.OP_IF, Op.OP_NOTIF]

/-- **The expansion opcodes are NOPs on a pre-Chronicle coin** (`611–618`, `644–650`, `669–675`,
`694–700`, `730–736`): `OP_SUBSTR`, `OP_LEFT`, `OP_RIGHT`, `OP_LSHIFTNUM`, `OP_RSHIFTNUM` do
nothing, or fail under DISCOURAGE_UPGRADABLE_NOPS (a policy flag); they execute only for a
coin created after Chronicle (#18; bsv-rs 0.3.28 gates them the same way, `flags.rs`
`UTXO_AFTER_CHRONICLE`, `spend.rs` `utxo_after_chronicle`). -/
theorem expansion_exec_preChronicle (op : Nat) (d : Bytes) (env : Env) (st : State)
    (hc : env.utxoAfterChronicle = false) (hop : Op.OP_SUBSTR ≤ op ∧ op ≤ Op.OP_RSHIFTNUM) :
    Ops.Expansion.exec op d env st = some (Ops.Expansion.nopOrDiscourage env st) := by
  unfold Ops.Expansion.exec
  simp [hop.1, hop.2, hc]

/-! ## The signature's hash type under the era flags (`CheckSignatureEncoding`, `265–310`; #25)

STRICTENC is consensus by height (`uahfHeight`, `verify_script_flags.cpp:54–59`; `flagWord_block_strictEnc`),
FORKID enters with it (`flagWord_block_forkid`) and CHRONICLE is an era marker of the spend (`flagWord_chronicle`):
the four refusals of `291–306` are rules on the signature's last byte (`GetHashType`, `247–253`) under the word's
bits, each theorem conditional on those bits. No word the node derives has STRICTENC without FORKID, so the FORKID
refusal is reached only under an explicit word (`checkSignatureEncoding_illegalForkid`). Each theorem assumes
the two checks before the type's pass, as Bool equations in the code's own terms: the strict DER shape (`275–280`,
`Env.strictDer`) and the low-S rule under the version gate (`282–288`); an empty signature passes them all
(`272–273`, `Ops.Crypto.checkSignatureEncoding_empty`). -/

open BsvScript.Tx BsvScript.Sighash BsvScript.Ops.Crypto BsvScript.TxContext

/-- **Without STRICTENC the type is never read** (`291`): the check passes whatever the last byte, as for a
pre-UAHF spend under the derived word (`flagWord_block_strictEnc`). -/
theorem checkSignatureEncoding_of_not_strictEnc (env : Env) (sig : Bytes)
    (hder : (env.strictDer && !isValidSignatureEncoding sig) = false)
    (hlow : (env.params.flags.lowS && !Crypto.Secp256k1.checkLowS sig.dropLast
              && enforceNonMalleability env.params.flags env.ctx.version) = false)
    (hs : env.params.flags.strictEnc = false) :
    checkSignatureEncoding env sig = .ok () := by
  unfold checkSignatureEncoding
  simp only [hder, hlow, hs, Bool.false_eq_true, ite_false, ite_self]

/-- **The undefined base under STRICTENC** (`293–294`): a non-empty signature whose type is not defined
(`Sighash.SigHashType.isDefined_iff`: base 0 or 4–31; the fork value above the low byte is never read,
`Sighash.SigHashType.isDefined_add_forkValue`) is `SCRIPT_ERR_SIG_HASHTYPE`. The spec's
own SV-node instance says so on gen-00969, gen-00970 and gen-00971 (`corpus/INDEX.md` §4c); bsv-rs 0.3.28 accepts
them (the crate class `sighash.type.undefined-base`, `spend.rs:1739–1766` at 0.3.28). -/
theorem checkSignatureEncoding_sigHashtype (env : Env) (sig : Bytes) (hne : sig.isEmpty = false)
    (hder : (env.strictDer && !isValidSignatureEncoding sig) = false)
    (hlow : (env.params.flags.lowS && !Crypto.Secp256k1.checkLowS sig.dropLast
              && enforceNonMalleability env.params.flags env.ctx.version) = false)
    (hs : env.params.flags.strictEnc = true) (hd : (SigHashType.ofSig sig).isDefined = false) :
    checkSignatureEncoding env sig = .error .sigHashtype := by
  unfold checkSignatureEncoding
  simp only [hne, hder, hlow, hs, hd, Bool.false_eq_true, Bool.not_false, ite_false, ite_true]

/-- **The FORKID bit without FORKID enabled** (`300–301`): under a word with STRICTENC and without
`SCRIPT_ENABLE_SIGHASH_FORKID`, a defined type carrying the FORKID bit is `SCRIPT_ERR_ILLEGAL_FORKID`. No word the
node derives is such a word: on the block path the two flags enter in one branch (`verify_script_flags.cpp:54–59`),
both are in both mandatory sets (`standard.h:55–68`) so in every standard word (`policy.h:191–197`), a promiscuous
word gains FORKID (`verify_script_flags.cpp:25`), and the skip mask clears neither (`rpc/rawtransaction.cpp:1486`).
The refusal is reached only under an explicit word, the `verifyscript` RPC's integer `flags` (`rpc/misc.cpp:697–702`)
or the reference's test vectors; before UAHF the word has neither flag and the type is never read
(`checkSignatureEncoding_of_not_strictEnc`). -/
theorem checkSignatureEncoding_illegalForkid (env : Env) (sig : Bytes) (hne : sig.isEmpty = false)
    (hder : (env.strictDer && !isValidSignatureEncoding sig) = false)
    (hlow : (env.params.flags.lowS && !Crypto.Secp256k1.checkLowS sig.dropLast
              && enforceNonMalleability env.params.flags env.ctx.version) = false)
    (hs : env.params.flags.strictEnc = true) (hd : (SigHashType.ofSig sig).isDefined = true)
    (he : env.params.flags.enableSighashForkid = false) (hf : (SigHashType.ofSig sig).hasForkId = true) :
    checkSignatureEncoding env sig = .error .illegalForkid := by
  unfold checkSignatureEncoding
  simp only [hne, hder, hlow, hs, hd, he, hf, Bool.false_eq_true, Bool.not_false, Bool.not_true, Bool.true_and,
    ite_false, ite_true]

/-- **The CHRONICLE bit before Chronicle** (`302–303`): without `SCRIPT_CHRONICLE` in the word a CHRONICLE-bit
signature is `SCRIPT_ERR_ILLEGAL_CHRONICLE`. Under STRICTENC the bit is legal only with `SCRIPT_CHRONICLE` in the
word, the Chronicle era's (`flagWord_chronicle`), where it selects the original digest (`Sighash.sighash_original_of_chronicle`, Q2). go-sdk v1.5.2 has no image
of the bit and ts-sdk 2.8.0 gates it on the coin's era (the class `sighash.type.chronicle-bit`, `corpus/INDEX.md`
§4b). Without STRICTENC (a pre-UAHF block word) the type is never read, so the bit passes the encoding check
there too (`checkSignatureEncoding_of_not_strictEnc`). -/
theorem checkSignatureEncoding_illegalChronicle (env : Env) (sig : Bytes) (hne : sig.isEmpty = false)
    (hder : (env.strictDer && !isValidSignatureEncoding sig) = false)
    (hlow : (env.params.flags.lowS && !Crypto.Secp256k1.checkLowS sig.dropLast
              && enforceNonMalleability env.params.flags env.ctx.version) = false)
    (hs : env.params.flags.strictEnc = true) (hd : (SigHashType.ofSig sig).isDefined = true)
    (hf : (!env.params.flags.enableSighashForkid && (SigHashType.ofSig sig).hasForkId) = false)
    (hc : env.params.flags.chronicle = false) (hb : (SigHashType.ofSig sig).hasChronicle = true) :
    checkSignatureEncoding env sig = .error .illegalChronicle := by
  unfold checkSignatureEncoding
  simp only [hne, hder, hlow, hs, hd, hf, hc, hb, Bool.false_eq_true, Bool.not_false, Bool.not_true, Bool.true_and,
    ite_false, ite_true]

/-- **FORKID enabled demands the bit** (`305–306`): after UAHF a defined type without the FORKID bit is
`SCRIPT_ERR_MUST_USE_FORKID`, so the non-FORKID original digest (`Sighash.sighash_original_of_no_forkid_bit`) is
historical replay on mainnet. go-sdk v1.5.2 never enforces it (the class `sighash.must-use-forkid`,
`corpus/INDEX.md` §4b). -/
theorem checkSignatureEncoding_mustUseForkid (env : Env) (sig : Bytes) (hne : sig.isEmpty = false)
    (hder : (env.strictDer && !isValidSignatureEncoding sig) = false)
    (hlow : (env.params.flags.lowS && !Crypto.Secp256k1.checkLowS sig.dropLast
              && enforceNonMalleability env.params.flags env.ctx.version) = false)
    (hs : env.params.flags.strictEnc = true) (hd : (SigHashType.ofSig sig).isDefined = true)
    (he : env.params.flags.enableSighashForkid = true)
    (hc : (!env.params.flags.chronicle && (SigHashType.ofSig sig).hasChronicle) = false)
    (hf : (SigHashType.ofSig sig).hasForkId = false) :
    checkSignatureEncoding env sig = .error .mustUseForkid := by
  unfold checkSignatureEncoding
  simp only [hne, hder, hlow, hs, hd, he, hc, hf, Bool.false_eq_true, Bool.not_false, Bool.not_true, Bool.true_and,
    Bool.false_and, ite_false, ite_true]

/-- **The type accepted under STRICTENC** (`309`): defined, and each bit lawful for the word; the four theorems
above and this one are the whole of `291–309`. -/
theorem checkSignatureEncoding_ok_strictEnc (env : Env) (sig : Bytes)
    (hder : (env.strictDer && !isValidSignatureEncoding sig) = false)
    (hlow : (env.params.flags.lowS && !Crypto.Secp256k1.checkLowS sig.dropLast
              && enforceNonMalleability env.params.flags env.ctx.version) = false)
    (hd : (SigHashType.ofSig sig).isDefined = true)
    (hf : (!env.params.flags.enableSighashForkid && (SigHashType.ofSig sig).hasForkId) = false)
    (hc : (!env.params.flags.chronicle && (SigHashType.ofSig sig).hasChronicle) = false)
    (hm : (env.params.flags.enableSighashForkid && !(SigHashType.ofSig sig).hasForkId) = false) :
    checkSignatureEncoding env sig = .ok () := by
  unfold checkSignatureEncoding
  simp only [hder, hlow, hd, hf, hc, hm, Bool.false_eq_true, Bool.not_true, ite_false, ite_self]

/-! ## `nLockTime` and `nSequence` as the checkers read them (`CheckLockTime` `2166–2202`,
`CheckSequence` `2204–2250`; #22, #25) -/

/-- **`CheckLockTime` as one predicate** (`2166–2202`): satisfied iff the operand and `nLockTime` are of one kind
(both below `LOCKTIME_THRESHOLD` or both at least it, `2175–2180`), the operand is at most the lock time
(`2184–2186`) and the spent input is not final (`2196–2198`). With `execCltv_satisfied_preGenesis` and
`execCltv_unsatisfied_preGenesis` this is CLTV's verdict on a pre-Genesis coin under the flag once a non-negative
operand is read. Those theorems assume that read (`hs`, `hr`, `hn`); CLTV's other outcomes there are the empty
stack (`528–529`), the operand over five bytes or not minimal (`546`, caught at `1807–1814`) and the negative operand
(`551–552`). -/
theorem checkLockTime_iff (tx : Tx) (nIn : Nat) (n : Int) :
    checkLockTime tx nIn n = true ↔
      (((tx.lockTime : Int) < LOCKTIME_THRESHOLD ∧ n < LOCKTIME_THRESHOLD)
        ∨ ((LOCKTIME_THRESHOLD : Int) ≤ tx.lockTime ∧ (LOCKTIME_THRESHOLD : Int) ≤ n))
      ∧ n ≤ tx.lockTime
      ∧ (tx.inputs[nIn]?.map (·.sequence)).getD SEQUENCE_FINAL ≠ SEQUENCE_FINAL := by
  unfold checkLockTime
  simp only [Bool.not_eq_true']
  split_ifs with h1 h2 h3 <;> simp_all
  all_goals omega

/-- An operand above the lock time fails (`2184–2186`): the transaction is not yet spendable by the script's
own reading. -/
theorem checkLockTime_of_lt (tx : Tx) (nIn : Nat) (n : Int) (h : (tx.lockTime : Int) < n) :
    checkLockTime tx nIn n = false := by
  rw [Bool.eq_false_iff, Ne, checkLockTime_iff]; omega

/-- A height operand against a time lock, or a time operand against a height lock, fails (`2175–2180`). -/
theorem checkLockTime_kind_mismatch (tx : Tx) (nIn : Nat) (n : Int)
    (h : ((tx.lockTime : Int) < LOCKTIME_THRESHOLD) ↔ ((LOCKTIME_THRESHOLD : Int) ≤ n)) :
    checkLockTime tx nIn n = false := by
  rw [Bool.eq_false_iff, Ne, checkLockTime_iff]; omega

/-- An input index past the inputs reads as final in the spec (`getD SEQUENCE_FINAL`; the reference indexes
`vin[nIn]` of the transaction being validated, `2197`, so the case never arises there): never satisfied. -/
theorem checkLockTime_missing_input (tx : Tx) (nIn : Nat) (n : Int) (h : tx.inputs.length ≤ nIn) :
    checkLockTime tx nIn n = false := by
  apply checkLockTime_final
  simp [List.getElem?_eq_none h]

/-- **The disable flag on the sequence** (`2220–2222`): with bit 31 set on the spent input's `nSequence`, CSV is
never satisfied (relative lock time is off for that input, BIP 68). -/
theorem checkSequence_disable_flag (tx : Tx) (nIn : Nat) (n : Int)
    (h : Nat.testBit ((tx.inputs[nIn]?.map (·.sequence)).getD SEQUENCE_FINAL) 31 = true) :
    checkSequence tx nIn n = false := by
  unfold checkSequence
  simp only [h, ite_true]
  split <;> rfl

/-- `SEQUENCE_FINAL` (`0xffffffff`, `transaction.h:99`) carries the disable flag, so a final input never satisfies
CSV either (`2220–2222`). -/
theorem checkSequence_final (tx : Tx) (nIn : Nat) (n : Int)
    (h : (tx.inputs[nIn]?.map (·.sequence)).getD SEQUENCE_FINAL = SEQUENCE_FINAL) :
    checkSequence tx nIn n = false :=
  checkSequence_disable_flag tx nIn n (by rw [h]; decide)

/-- As for CLTV: an input index past the inputs reads as final, never satisfied. -/
theorem checkSequence_missing_input (tx : Tx) (nIn : Nat) (n : Int) (h : tx.inputs.length ≤ nIn) :
    checkSequence tx nIn n = false := by
  apply checkSequence_final
  simp [List.getElem?_eq_none h]

/-- **`CheckSequence` as one predicate** (`2204–2250`): the version at least 2 as an unsigned word (`2212–2214`),
no disable flag on the sequence (`2220–2222`), the two values masked to the type flag and the low sixteen bits
(`2226–2229`) of one kind (`2237–2242`), and the operand's at most the sequence's (`2246–2248`). With
`execCsv_unsatisfied_preGenesis` and `execCsv_satisfied_preGenesis` this is CSV's verdict on a pre-Genesis coin under
the flag once a non-negative operand without the disable flag is read (the outcomes before that read are named at
`execCsv_satisfied_preGenesis`). -/
theorem checkSequence_iff (tx : Tx) (nIn : Nat) (n : Int) :
    checkSequence tx nIn n = true ↔
      2 ≤ (tx.version % (2 ^ 32)).toNat
      ∧ Nat.testBit ((tx.inputs[nIn]?.map (·.sequence)).getD SEQUENCE_FINAL) 31 = false
      ∧ ((((tx.inputs[nIn]?.map (·.sequence)).getD SEQUENCE_FINAL &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) < SEQUENCE_LOCKTIME_TYPE_FLAG
            ∧ (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) < SEQUENCE_LOCKTIME_TYPE_FLAG)
          ∨ (SEQUENCE_LOCKTIME_TYPE_FLAG ≤ ((tx.inputs[nIn]?.map (·.sequence)).getD SEQUENCE_FINAL &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK))
            ∧ SEQUENCE_LOCKTIME_TYPE_FLAG ≤ (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK))))
      ∧ (n.toNat &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK))
          ≤ ((tx.inputs[nIn]?.map (·.sequence)).getD SEQUENCE_FINAL &&& (SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK)) := by
  unfold checkSequence
  simp only [Bool.not_eq_true']
  split_ifs with h1 h2 h3 h4 <;> simp_all
  all_goals omega

/-! ## `OP_CODESEPARATOR`'s slice, and the block word at the upgradable NOPs (#25, S2, 2026-09-27) -/

/-- **`OP_CODESEPARATOR` moves the scriptCode's start** (`1445–1448`: `pbegincodehash = pc`, the byte after the
separator; `execStep`, the loop's own case): executed, it changes nothing but `codeSep`, which becomes the bytes after
it (`k`, the parser's count after the opcode, is 0 for every non-push opcode). -/
theorem execStep_codeseparator (exec : OpExec) (env : Env) (data rest : Bytes) (k : Nat) (st : State) :
    execStep exec env Op.OP_CODESEPARATOR data rest k true st = .cont { st with codeSep := rest.drop k } := by
  simp [execStep, Op.OP_CODESEPARATOR, Op.OP_PUSHDATA4]

/-- Unexecuted (an inactive branch) it changes nothing (`482`: the switch runs only under `fExec` or for
`OP_IF`…`OP_ENDIF`, and `0xab` is outside that range). -/
theorem execStep_codeseparator_unexecuted (exec : OpExec) (env : Env) (data rest : Bytes) (k : Nat) (st : State) :
    execStep exec env Op.OP_CODESEPARATOR data rest k false st = .cont st := by
  simp [execStep, Op.OP_CODESEPARATOR, Op.OP_PUSHDATA4, Op.OP_IF, Op.OP_ENDIF]

/-- **At the loop** (`450–451`, `466–471`, `1445–1448`): an executed `OP_CODESEPARATOR` with the op count in bounds
continues on the rest of the script with the count charged and `codeSep` that rest; the hypotheses are the loop's
guards before the switch (an active branch with no non-top-level return, the count) and the pre-Genesis stack limit
the loop checks after the step (`1800–1803`). -/
theorem loop_codeseparator (exec : OpExec) (env : Env) (rest : Bytes) (st : State)
    (hact : st.cond.isActive = true) (hret : st.nonTopLevelReturn = false)
    (hcount : st.opCount + 1 ≤ env.params.limits.maxOpsPerScript)
    (hstk : env.utxoAfterGenesis = true ∨ st.stack.length + st.alt.length ≤ Consensus.maxStackElementsBeforeGenesis) :
    loop exec env (Op.OP_CODESEPARATOR :: rest) st
      = loop exec env rest { st with opCount := st.opCount + 1, codeSep := rest } := by
  have hc' : ¬ (st.opCount + 1 > env.params.limits.maxOpsPerScript) := by omega
  rw [loop.eq_2]
  simp [getOpTail, hact, hret, hc', isOpcodeDisabled, execStep, Op.OP_CODESEPARATOR, Op.OP_PUSHDATA4, Op.OP_16,
        Op.OP_2MUL, Op.OP_2DIV]
  rcases hstk with h | h
  · simp [h]
  · simp [h]

/-- **The scriptCode of a signature check inside the unlocking script under Chronicle** (`1472–1481`, `1568–1577`:
`scriptCode += *checksigData` when `checksigData && IsChronicle(flags)`; `checksigData` is the locking script while
the unlocking script runs, `2338–2352`): the bytes from the last separator with the locking script appended. -/
theorem scriptCodeOf_chronicle (env : Env) (st : State) (lock : Bytes)
    (hc : env.checksigData = some lock) (hf : env.params.flags.chronicle = true) :
    scriptCodeOf env st = st.codeSep ++ lock := by
  simp [scriptCodeOf, hc, hf]

/-- Otherwise the bytes from the last separator alone (`1473`, `1569`: `CScript scriptCode {pbegincodehash, pend}`):
in the locking script (`checksigData` null) or on a pre-Chronicle spend. -/
theorem scriptCodeOf_eq_codeSep (env : Env) (st : State)
    (h : env.checksigData = none ∨ env.params.flags.chronicle = false) :
    scriptCodeOf env st = st.codeSep := by
  unfold scriptCodeOf
  rcases h with h | h
  · simp [h]
  · cases env.checksigData <;> simp [h]

/-- **Every environment of the block path has DISCOURAGE_UPGRADABLE_NOPS off** (#32's lens 1, A3 and A10: the
three theorems after this one assume the bit off, and this is where the block path meets them). *What it says:* the
environment `Machine.verifyScript` builds for either phase of a spend on the block path (`mkEnv` over the word
`Params.derive` gives with `consensus = true`, after STRICTENC from FORKID, `2315–2319`; `verifyScript`, `phase2`) has
the bit off. *What it assumes:* nothing: every configuration, every spend height and coin height (so every coin's
era), every version, either phase. *Why it matters:* the block word never carries the bit
(`blockScriptFlags_policy_off`; `policy.h:177–181`; `script_flags.h:56–57`: "will never be a mandatory flag applied to
scripts in a block"), the per-input word adds only SIGPUSHONLY and the two UTXO markers (`policy.h:225–244`), and
neither `Flags.forkAdjust` nor the version gate `Flags.gate` sets it; so on the block path each of the flag's eight
read sites (`522`, `565`, `613`, `646`, `671`, `696`, `732`, `768`) passes. -/
theorem mkEnv_block_discourage_off (cfg : NodeConfig) (h u : Nat) (ctx : Context) (cd : Option Bytes) :
    (mkEnv (derive cfg h u true) ctx (derive cfg h u true).flags.forkAdjust cd).params.flags.discourageUpgradableNops
      = false := by
  have hb := blockScriptFlags_policy_off cfg.normalize.chain (h - 1) (cfg.normalize.protocolEra h)
    .discourageUpgradableNops rfl
  simp [FlagBit.get] at hb
  simp only [mkEnv, derive, NodeConfig.flagWord, Flags.forkAdjust, Flags.gate]
  split_ifs <;> simp [Flags.union, inputScriptVerifyFlags, Flags.none, hb]

/-- **DISCOURAGE_UPGRADABLE_NOPS never fires in a block**, read at the opcode. *What it assumes:* the bit off in the
environment's word (`hd`), as every environment of the block path has it (`mkEnv_block_discourage_off`, whatever the
coin's era). *What it says:* the expansion opcodes' pre-Chronicle NOP is a NOP (`613–614`, `646–647`, `671–672`,
`696–697`, `732–733`) … -/
theorem nopOrDiscourage_block (env : Env) (st : State) (hd : env.params.flags.discourageUpgradableNops = false) :
    Ops.Expansion.nopOrDiscourage env st = .ok st := by
  simp [Ops.Expansion.nopOrDiscourage, hd]

/-- … `OP_NOP1`, `OP_NOP9` and `OP_NOP10` continue (`765–771`), under the same hypothesis … -/
theorem execFlow_nop_block (exec : OpExec) (env : Env) (op : Nat) (data : Bytes) (fExec : Bool) (st : State)
    (hd : env.params.flags.discourageUpgradableNops = false)
    (hop : op = Op.OP_NOP1 ∨ op = Op.OP_NOP9 ∨ op = Op.OP_NOP10) :
    execFlow exec env op data fExec st = .cont st := by
  rcases hop with rfl | rfl | rfl <;>
    simp [execFlow, hd, Op.OP_NOP1, Op.OP_NOP9, Op.OP_NOP10, Op.OP_1NEGATE, Op.OP_1, Op.OP_16, Op.OP_NOP,
          Op.OP_CHECKLOCKTIMEVERIFY, Op.OP_CHECKSEQUENCEVERIFY, Op.OP_VER]

/-- … and CLTV/CSV on a post-Genesis coin continue (`520–526`, `563–569`), under the same hypothesis and a
post-Genesis coin (`hg`). With `mkEnv_block_discourage_off` the three are "policy never decides block validity", read
per opcode; the standard word (`standardOnly`, `policy.h:182–189`) fails each of these sites instead
(`nopOrDiscourage_standard`, `execFlow_nop_standard`, `execCltv_nop_postGenesis`, `execCsv_nop_postGenesis`). -/
theorem cltv_csv_block_postGenesis (env : Env) (st : State) (hd : env.params.flags.discourageUpgradableNops = false)
    (hg : env.utxoAfterGenesis = true) :
    execCltv env st = .cont st ∧ execCsv env st = .cont st := by
  simp [execCltv, execCsv, hd, hg]

/-- The relay side of the same sites: with the flag on (the standard word), the pre-Chronicle expansion NOP is
`SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS` (`613–614`), as `OP_NOP1`/`OP_NOP9`/`OP_NOP10` are (`768–769`,
`execFlow_nop_standard`) and post-Genesis CLTV/CSV are (`522–523`, `565–566`; `execCltv_nop_postGenesis`,
`execCsv_nop_postGenesis`). -/
theorem nopOrDiscourage_standard (env : Env) (st : State) (h : env.params.flags.discourageUpgradableNops = true) :
    Ops.Expansion.nopOrDiscourage env st = .fail .discourageUpgradableNops := by
  simp [Ops.Expansion.nopOrDiscourage, h]

/-- **`OP_NOP1`, `OP_NOP9` and `OP_NOP10` under the flag** (`768–769`): with DISCOURAGE_UPGRADABLE_NOPS on (the
standard word), each is `SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS`; the relay side of `execFlow_nop_block`. -/
theorem execFlow_nop_standard (exec : OpExec) (env : Env) (op : Nat) (data : Bytes) (fExec : Bool) (st : State)
    (hd : env.params.flags.discourageUpgradableNops = true)
    (hop : op = Op.OP_NOP1 ∨ op = Op.OP_NOP9 ∨ op = Op.OP_NOP10) :
    execFlow exec env op data fExec st = .fail .discourageUpgradableNops := by
  rcases hop with rfl | rfl | rfl <;>
    simp [execFlow, hd, Op.OP_NOP1, Op.OP_NOP9, Op.OP_NOP10, Op.OP_1NEGATE, Op.OP_1, Op.OP_16, Op.OP_NOP,
          Op.OP_CHECKLOCKTIMEVERIFY, Op.OP_CHECKSEQUENCEVERIFY, Op.OP_VER]

end BsvScript.Properties
