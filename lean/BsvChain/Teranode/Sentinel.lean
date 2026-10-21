import BsvScript.Flags
import BsvScript.Properties.Eras

/-!
# BsvChain.Teranode.Sentinel: the unconfirmed-parent sentinel against the reference's word (#91)

[M] 2026-10-14 (#91). Teranode stamps a parent the UTXO store holds without a
recorded block height with its own sentinel and translates the sentinel at the GoBDK boundary; GoBDK then
computes each input's flag word with the reference's functions compiled in (`NodeConfig.bdkCalculateFlags`).
This module transcribes the translation from Teranode v0.16.0 at `4edb60a4` and GoBDK at `4eab3acd`
(`docs/PROVENANCE.md` §1) and proves the word GoBDK verifies an input under equal to the reference's at
bitcoin-sv v1.2.3 (`6504a3af`):

* on the mempool path, for every parent height up to `int32Max` or unconfirmed parent and every tip below
  `int32Max`, the reference's mempool word (`teranode_word_eq_mempool_word`);
* at block connection, on the validator paths that set `Options.UnconfirmedParentsAtCandidateHeight`
  (CheckBlockSubtrees and CheckSubtree's legacy branch; CheckSubtree's peer-facing branch runs without it,
  `services/subtreevalidation/Server.go:954–963`), the reference's block word, a same-block parent's coin standing
  at the block's own height (`teranode_word_eq_block_word`);
* the two pairs where they differ, each kernel-checked: a consensus-mode call WITHOUT that option refuses an
  unconfirmed parent before any word is computed (`teranode_unconfirmed_refused_without_option`), where the
  reference connects a same-block parent under the block word, and a confirmed parent's word there is the
  reference's block word (`teranode_word_without_option`); and the reference's
  `-promiscuousmempoolflags` word on a chain that does not require standardness, for which neither Teranode
  nor GoBDK has a setting (`teranode_word_ne_promiscuous`; policy, a node's setting, never block validity).

Both words read one configuration's chain heights and era heights (`SameEras`), nothing of the policy
limits. Whether the refusal of the bullet above (`teranode_unconfirmed_refused_without_option`) reaches a verdict on a block the reference accepts depends
on which Teranode caller runs consensus mode without the option and on the block-level backstops behind it
(the module map of #87, the driven instance of #74); this module proves the word, not the verdict.
-/

namespace BsvChain.Teranode

open BsvScript.Params

/-! ## The heights as Teranode writes them -/

/-- Teranode's sentinel for a parent the UTXO store holds with no recorded block height:
`unconfirmedParentHeight uint32 = 0xFFFFFFFF` (`services/validator/Validator.go:179–197`), written into
the input's height slot when the parent's `BlockHeights` is empty
(`services/validator/Validator.go:1752–1767`), distinct on purpose from `MEMPOOL_HEIGHT`
(`:190–196`) `[SRC]`. -/
def unconfirmedParentHeight : Nat := 0xFFFFFFFF

/-- `math.MaxInt32`. Every height crosses the GoBDK call as an `int32` (`uint2int`,
`services/validator/ScriptVerifierGoBDK.go:95–108`, called at `:286–290`) through
`Uint32ToInt32` (`safe_conversion.go:234–240` at go-safe-conversion v1.2.0, `ebbf2d45`, the version Teranode's
`go.mod:203` requires), which refuses a value above it `[SRC]`. -/
def int32Max : Nat := 0x7FFFFFFF

/-- The adapter's `mempoolHeight uint32 = 0x7FFFFFFF` (`services/validator/ScriptVerifierGoBDK.go:23–38`)
is the reference's `MEMPOOL_HEIGHT` (`mempoolHeight`, `BsvScript.Flags`), and it is `math.MaxInt32`. -/
theorem adapter_mempoolHeight : (0x7FFFFFFF : Nat) = mempoolHeight ∧ mempoolHeight = int32Max :=
  ⟨rfl, rfl⟩

/-! ## The substitution (`services/validator/ScriptVerifierGoBDK.go:40–93`) -/

/-- One slot of `substituteUnconfirmedHeights` (`services/validator/ScriptVerifierGoBDK.go:66–81`): the
sentinel becomes `mempoolHeight` in consensus mode (`:67–68`) and `blockHeight` in policy mode (`:69–71`),
"the candidate height the caller is validating against; in policy mode that is tip+1" (`:50–53`); every other
height passes through (`:77–78`) `[SRC]`. -/
def substituteSlot (blockHeight : Nat) (consensus : Bool) (h : Nat) : Nat :=
  if h = unconfirmedParentHeight then (if consensus then mempoolHeight else blockHeight) else h

/-- **`substituteUnconfirmedHeights`** (`services/validator/ScriptVerifierGoBDK.go:54–82`): the input returned
unchanged when no slot holds the sentinel (`:55–64`), else every slot through `substituteSlot` (`:66–81`)
`[SRC]`. -/
def substituteUnconfirmedHeights (utxoHeights : List Nat) (blockHeight : Nat) (consensus : Bool) : List Nat :=
  if utxoHeights.any (· == unconfirmedParentHeight) then utxoHeights.map (substituteSlot blockHeight consensus)
  else utxoHeights

/-- `resolveUnconfirmedParentsAtCandidateHeight` (`services/validator/ScriptVerifierGoBDK.go:84–93`): the
`consensus = false` branch of the substitution, reused for its candidate-height rewrite, "NOT because the caller
is in policy mode" (`:87–90`), which the validator applies BEFORE the adapter's when
`Options.UnconfirmedParentsAtCandidateHeight` is set (`services/validator/Validator.go:2867–2889`) `[SRC]`. -/
def resolveUnconfirmedParentsAtCandidateHeight (utxoHeights : List Nat) (blockHeight : Nat) : List Nat :=
  substituteUnconfirmedHeights utxoHeights blockHeight false

/-- *What it says:* the substitution is slot by slot. The early return of
`services/validator/ScriptVerifierGoBDK.go:62–64` changes nothing, since on a list with no sentinel the map is
the identity; so each input's word below reads its own slot only. -/
theorem substituteUnconfirmedHeights_eq_map (hs : List Nat) (b : Nat) (c : Bool) :
    substituteUnconfirmedHeights hs b c = hs.map (substituteSlot b c) := by
  unfold substituteUnconfirmedHeights
  split
  · rfl
  · rename_i hno
    simp only [List.any_eq_true, beq_iff_eq, not_exists, not_and] at hno
    conv_lhs => rw [← List.map_id hs]
    apply List.map_congr_left
    intro h hm
    simp [substituteSlot, hno h hm]

/-! ## The call into GoBDK (`services/validator/ScriptVerifierGoBDK.go:261–313`) -/

/-- `Uint32ToInt32` on one height: refused above `int32Max` (`int32Max`'s citation); a refused slot fails the
call with an invalid-argument error before GoBDK runs (`services/validator/ScriptVerifierGoBDK.go:286–290`)
`[SRC]`. -/
def uint32ToInt32 (h : Nat) : Option Nat := if h ≤ int32Max then some h else none

/-- `bdkBlockHeight` (`services/validator/ScriptVerifierGoBDK.go:261–271`): consensus mode hands GoBDK the
candidate block's height (`:262–264`); policy mode refuses zero (`:266–268`) and hands it `blockHeight − 1`
(`:270`), the tip, GoBDK's policy convention (GoBDK `core/txvalidator.cpp:669–672`: "blockHeight is the chain
tip") `[SRC]`. -/
def bdkBlockHeight (blockHeight : Nat) (consensus : Bool) : Option Nat :=
  if consensus then uint32ToInt32 blockHeight
  else if blockHeight = 0 then none
  else uint32ToInt32 (blockHeight - 1)

/-- **The word GoBDK verifies one input under, as Teranode calls it.** Teranode's validator runs with
`blockHeight`, the candidate block's (`blockState.Height + 1` when the caller passes none,
`services/validator/Validator.go:896–900`), the mode `consensus` (`SkipPolicyChecks`, "equivalent to BDK
consensus=true", `services/validator/TxValidator.go:224–229`) and the option `atCandidate`
(`Options.UnconfirmedParentsAtCandidateHeight`). The input's slot `h` goes through the option's substitution
(`services/validator/Validator.go:2887–2889`), the adapter's (`services/validator/ScriptVerifierGoBDK.go:283`),
the `int32` conversion (`:286–290`) and `bdkBlockHeight` (`:292–295`); GoBDK then refuses a `MEMPOOL_HEIGHT`
slot in consensus mode with `UnconfirmedInputInBlock` (GoBDK `core/txvalidator.cpp:902–904`; before Genesis
already in the sigop check, `core/txvalidator.cpp:1270–1272`) and otherwise verifies under
`CalculateFlags(utxoHeight, blockHeight, consensus)` (`core/txvalidator.cpp:905`, the function at `:659–681`,
`NodeConfig.bdkCalculateFlags`). `none` is a refusal before any script runs; a conversion refusal of any
slot refuses the whole call (`:286–290`) `[SRC]`. A call with `Options.SkipScriptValidation` (legacy catch-up
below the highest checkpoint) runs no script and computes no word (`services/validator/TxValidator.go:147–152`);
the theorems speak of the calls that do. -/
def teranodeInputWord (cfg : NodeConfig) (blockHeight : Nat) (consensus atCandidate : Bool) (h : Nat) :
    Option Flags := do
  let h := if atCandidate then substituteSlot blockHeight false h else h
  let h ← uint32ToInt32 (substituteSlot blockHeight consensus h)
  let bh ← bdkBlockHeight blockHeight consensus
  if consensus && h == mempoolHeight then none
  else some (cfg.bdkCalculateFlags h bh consensus)

/-! ## The parent as each node records it, and the reference's words -/

/-- A parent output's height: confirmed in a block, or not yet. -/
inductive ParentHeight where
  | confirmed (height : Nat)
  | unconfirmed
  deriving DecidableEq, Repr

/-- Teranode's slot for the parent (`services/validator/Validator.go:1752–1767`): the stored block height,
or the sentinel. -/
def ParentHeight.teranodeSlot : ParentHeight → Nat
  | .confirmed h => h
  | .unconfirmed => unconfirmedParentHeight

/-- The reference's coin height on the mempool path: a confirmed coin's block, and `MEMPOOL_HEIGHT` for an
output of a transaction in the pool (`CCoinsViewMemPool::GetCoin`, `src/txmempool.cpp:2070–2082`, the height at
`:2079`) `[SRC]`. -/
def ParentHeight.mempoolCoinHeight : ParentHeight → Nat
  | .confirmed h => h
  | .unconfirmed => mempoolHeight

/-- The reference's coin height at block connection: a same-block parent's outputs are added at the block's
height before the child is checked (`UpdateCoins(tx, shard, pindex->GetHeight())`,
`src/validation.cpp:3439–3443`; `UpdateCoins` adding the outputs through `AddCoins` with that height, `src/validation.cpp:2479–2495`, the
call at `:2494`) `[SRC]`. -/
def ParentHeight.blockCoinHeight (blockHeight : Nat) : ParentHeight → Nat
  | .confirmed h => h
  | .unconfirmed => blockHeight

/-- The reference's mempool word for an input when the tip is `tip` (`CheckInputScripts`,
`src/validation.cpp:2692–2696`, the spend height `tip + 1` (`GetSpendHeightAndMTP`, `src/validation.cpp:2545–2548`,
read at `:2857`); the coin's height through
`GetInputScriptBlockHeight`, `src/validation.cpp:2667–2674`): `NodeConfig.flagWord` on the mempool path. -/
def referenceMempoolWord (cfg : NodeConfig) (tip : Nat) (p : ParentHeight) : Flags :=
  cfg.flagWord (tip + 1) (inputScriptBlockHeight p.mempoolCoinHeight tip) false

/-- The reference's block word for an input of the block at `blockHeight` (`NodeConfig.flagWord` on the block
path, the coin at `ParentHeight.blockCoinHeight`). -/
def referenceBlockWord (cfg : NodeConfig) (blockHeight : Nat) (p : ParentHeight) : Flags :=
  cfg.flagWord blockHeight (p.blockCoinHeight blockHeight) true

/-- The fields both words read agree: the chain's activation heights and the two era heights. Teranode
pushes Genesis and Chronicle from go-chaincfg (`services/validator/ScriptVerifierGoBDK.go:157–165`) and GoBDK
compiles the reference's other heights in (`NodeConfig.teranodeDefault`); on mainnet the two configurations of
`BsvScript.Params` satisfy it (`sameEras_defaults`). -/
structure SameEras (a b : NodeConfig) : Prop where
  chain : a.chain = b.chain
  genesis : a.genesisActivationHeight = b.genesisActivationHeight
  chronicle : a.chronicleActivationHeight = b.chronicleActivationHeight

/-- *What it says:* Teranode's default configuration and the reference's mainnet default share the chain record
and both era heights, so `SameEras`'s hypothesis holds on mainnet: Teranode pushes go-chaincfg's mainnet Genesis
and Chronicle heights into GoBDK (`params.go:276–277` at go-chaincfg v1.6.2, pushed at
`services/validator/ScriptVerifierGoBDK.go:157–165`) and GoBDK's main table compiles the reference's other heights
in (`core/txvalidator.cpp:275–283`) `[SRC]`. -/
theorem sameEras_defaults : SameEras NodeConfig.teranodeDefault NodeConfig.svMainnetDefault :=
  ⟨rfl, rfl, rfl⟩

/-! ## The theorems -/

/-- *What it says:* with no promiscuous word in force, the mempool word is the era's standard word whatever
`requireStandard` reads: the standard word already carries FORKID, which is all `GetScriptVerifyFlags` adds
when standardness is not required (`verify_script_flags.cpp:18–26`). So GoBDK's reading of the node's setting
and the reference's reading of the chain's (`requireStandard`'s docstring) agree. -/
theorem mempoolScriptFlags_standard (era : Era) (rs : Bool) (prom : Option Flags)
    (h : rs = true ∨ prom = none) : mempoolScriptFlags era rs prom = standardScriptVerifyFlags era := by
  rcases h with h | h
  · simp [mempoolScriptFlags, h]
  · subst h; cases rs <;> cases era <;> decide

/-- *What it says:* GoBDK's policy-mode word under one configuration is the reference's mempool word under
another with the same eras (`BsvScript.Properties.bdkCalculateFlags_policy`, across two configurations). -/
theorem bdkCalculateFlags_policy_eq (cfgT cfgR : NodeConfig) (hs : SameEras cfgT cfgR)
    (hp : cfgR.requireStandard = true ∨ cfgR.promiscuousMempoolFlags = none) (u tip : Nat) :
    cfgT.bdkCalculateFlags u tip false = cfgR.flagWord (tip + 1) (inputScriptBlockHeight u tip) false := by
  simp only [NodeConfig.bdkCalculateFlags, NodeConfig.flagWord, Bool.false_eq_true, ite_false,
    NodeConfig.protocolEra, hs.genesis, hs.chronicle]
  rw [mempoolScriptFlags_standard _ _ _ (Or.inr rfl), mempoolScriptFlags_standard _ _ _ hp]

/-- *What it says:* GoBDK's consensus-mode word under one configuration is the reference's block word under
another with the same eras (`BsvScript.Properties.bdkCalculateFlags_consensus`, across two configurations). -/
theorem bdkCalculateFlags_consensus_eq (cfgT cfgR : NodeConfig) (hs : SameEras cfgT cfgR) (u h : Nat)
    (hu : u ≠ mempoolHeight) : cfgT.bdkCalculateFlags u h true = cfgR.flagWord h u true := by
  rw [BsvScript.Properties.bdkCalculateFlags_consensus cfgT u h hu]
  simp only [NodeConfig.flagWord, ↓reduceIte, NodeConfig.protocolEra, hs.chain, hs.genesis, hs.chronicle]

/-- **#91, the mempool path.** *What it says:* for every parent, confirmed at any height a block can carry
or unconfirmed, and every tip below `int32Max`, the word Teranode's GoBDK verifies the input under on the
mempool path (policy mode, `blockHeight` the tip plus one, with or without the candidate-height option) is
the reference's mempool word: the sentinel becomes the tip plus one in the adapter and the reference's
`MEMPOOL_HEIGHT` coin becomes the tip plus one in `GetInputScriptBlockHeight`. The configurations may differ
in every policy limit; they share the eras (`SameEras`), and the reference's promiscuous word is not in force
(`hp`; `teranode_word_ne_promiscuous` is the pair where it is). -/
theorem teranode_word_eq_mempool_word (cfgT cfgR : NodeConfig) (hs : SameEras cfgT cfgR)
    (hp : cfgR.requireStandard = true ∨ cfgR.promiscuousMempoolFlags = none)
    (tip : Nat) (htip : tip + 1 ≤ int32Max) (p : ParentHeight)
    (hpar : ∀ h, p = .confirmed h → h ≤ int32Max) (atCandidate : Bool) :
    teranodeInputWord cfgT (tip + 1) false atCandidate p.teranodeSlot = some (referenceMempoolWord cfgR tip p) := by
  have hbh : bdkBlockHeight (tip + 1) false = some tip := by
    have hle : tip ≤ int32Max := by omega
    simp [bdkBlockHeight, uint32ToInt32, hle]
  cases p with
  | confirmed h =>
    have hh := hpar h rfl
    have hne : h ≠ unconfirmedParentHeight := by
      unfold unconfirmedParentHeight; unfold int32Max at hh; omega
    have hconv : uint32ToInt32 h = some h := by simp [uint32ToInt32, hh]
    cases atCandidate <;>
    simp only [teranodeInputWord, ParentHeight.teranodeSlot, substituteSlot, hne,
      ↓reduceIte, hconv, hbh, Option.bind_eq_bind, Option.bind_some, Bool.false_and,
      Bool.false_eq_true] <;>
    rw [bdkCalculateFlags_policy_eq cfgT cfgR hs hp] <;>
    rfl
  | unconfirmed =>
    have hne : tip + 1 ≠ unconfirmedParentHeight := by
      unfold unconfirmedParentHeight; unfold int32Max at htip; omega
    have hconv : uint32ToInt32 (tip + 1) = some (tip + 1) := by simp [uint32ToInt32, htip]
    have hres : inputScriptBlockHeight (tip + 1) tip = tip + 1 := by
      simp [inputScriptBlockHeight]
    have href : referenceMempoolWord cfgR tip .unconfirmed = cfgR.flagWord (tip + 1) (tip + 1) false := by
      simp only [referenceMempoolWord, ParentHeight.mempoolCoinHeight,
        BsvScript.Properties.inputScriptBlockHeight_mempool]
    cases atCandidate <;>
    simp only [teranodeInputWord, ParentHeight.teranodeSlot, substituteSlot, hne,
      ↓reduceIte, Bool.false_eq_true, hconv, hbh, Option.bind_eq_bind, Option.bind_some,
      Bool.false_and] <;>
    rw [bdkCalculateFlags_policy_eq cfgT cfgR hs hp, hres, href]

/-- **#91, block connection.** *What it says:* at the block of height `blockHeight` (below `MEMPOOL_HEIGHT`),
on a validator call with the candidate-height option set, which CheckBlockSubtrees sets
(`services/subtreevalidation/check_block_subtrees.go:701–709`) and CheckSubtree's legacy branch sets "UNCONDITIONALLY"
(`services/subtreevalidation/Server.go:902–909`, `:864`); CheckSubtree's peer-facing branch does not (`:954–963`;
"MUST NOT be set on the peer-facing branch", `:892–893`), and there `teranode_unconfirmed_refused_without_option`
and `teranode_word_without_option` apply; the word Teranode's GoBDK
verifies an input under is the reference's block word, for a confirmed parent and for a same-block parent
alike: the sentinel becomes the candidate height, which is the height the reference's coins view gives a
same-block parent's coin. -/
theorem teranode_word_eq_block_word (cfgT cfgR : NodeConfig) (hs : SameEras cfgT cfgR)
    (blockHeight : Nat) (hb : blockHeight < mempoolHeight) (p : ParentHeight)
    (hpar : ∀ h, p = .confirmed h → h < mempoolHeight) :
    teranodeInputWord cfgT blockHeight true true p.teranodeSlot = some (referenceBlockWord cfgR blockHeight p) := by
  have hbconv : uint32ToInt32 blockHeight = some blockHeight := by
    have hle : blockHeight ≤ int32Max := by unfold int32Max; unfold mempoolHeight at hb; omega
    simp [uint32ToInt32, hle]
  have hbh : bdkBlockHeight blockHeight true = some blockHeight := by simp [bdkBlockHeight, hbconv]
  have hbne : blockHeight ≠ unconfirmedParentHeight := by
    unfold unconfirmedParentHeight; unfold mempoolHeight at hb; omega
  have hbm : (blockHeight == mempoolHeight) = false := by simp; omega
  cases p with
  | confirmed h =>
    have hh := hpar h rfl
    have hne : h ≠ unconfirmedParentHeight := by
      unfold unconfirmedParentHeight; unfold mempoolHeight at hh; omega
    have hconv : uint32ToInt32 h = some h := by
      have hle : h ≤ int32Max := by unfold int32Max; unfold mempoolHeight at hh; omega
      simp [uint32ToInt32, hle]
    have hm : (h == mempoolHeight) = false := by simp; omega
    simp only [teranodeInputWord, ParentHeight.teranodeSlot, substituteSlot, hne,
      ↓reduceIte, hconv, hbh, Option.bind_eq_bind, Option.bind_some, Bool.true_and, hm,
      Bool.false_eq_true]
    rw [bdkCalculateFlags_consensus_eq cfgT cfgR hs h blockHeight (Nat.ne_of_lt hh)]
    rfl
  | unconfirmed =>
    simp only [teranodeInputWord, ParentHeight.teranodeSlot, substituteSlot,
      Bool.false_eq_true, ↓reduceIte, hbne, hbconv, hbh, Option.bind_eq_bind, Option.bind_some,
      Bool.true_and, hbm]
    rw [bdkCalculateFlags_consensus_eq cfgT cfgR hs blockHeight blockHeight (Nat.ne_of_lt hb)]
    rfl

/-- **#91, the pair where they differ (1).** *What it says:* on a consensus-mode call WITHOUT the
candidate-height option, an unconfirmed parent is refused before any word is computed: the adapter turns
the sentinel into `MEMPOOL_HEIGHT` (`services/validator/ScriptVerifierGoBDK.go:47–49`, `:67–68`) and GoBDK
refuses it (`UnconfirmedInputInBlock`, GoBDK `core/txvalidator.cpp:903–904`), at every block height. The
reference connects a same-block parent under its block word (`referenceBlockWord`, the coin at the block's
height); a parent in neither the chain nor the block is refused by the reference too, as a missing input. -/
theorem teranode_unconfirmed_refused_without_option (cfg : NodeConfig) (blockHeight : Nat) :
    teranodeInputWord cfg blockHeight true false ParentHeight.unconfirmed.teranodeSlot = none := by
  have hconv : uint32ToInt32 mempoolHeight = some mempoolHeight := by decide
  simp only [teranodeInputWord, ParentHeight.teranodeSlot, substituteSlot,
    Bool.false_eq_true, ↓reduceIte, hconv, Option.bind_eq_bind, Option.bind_some, bdkBlockHeight]
  cases uint32ToInt32 blockHeight <;> simp

/-- **#91, the peer-facing branch.** *What it says:* on a consensus-mode call WITHOUT the candidate-height option,
the call CheckSubtree's peer-facing branch makes (`WithSkipPolicyChecks(true)`, `WithInBlock(true)`, no
`WithUnconfirmedParentsAtCandidateHeight`, `services/subtreevalidation/Server.go:954–963`; "MUST NOT be set on the
peer-facing branch", `:892–893`), the word Teranode's GoBDK verifies an input under is the reference's block word
for a confirmed parent and a refusal for an unconfirmed one (`teranode_unconfirmed_refused_without_option`): the
option changes the word of a same-block parent only. -/
theorem teranode_word_without_option (cfgT cfgR : NodeConfig) (hs : SameEras cfgT cfgR)
    (blockHeight : Nat) (hb : blockHeight < mempoolHeight) (p : ParentHeight)
    (hpar : ∀ h, p = .confirmed h → h < mempoolHeight) :
    teranodeInputWord cfgT blockHeight true false p.teranodeSlot =
      if p = .unconfirmed then none else some (referenceBlockWord cfgR blockHeight p) := by
  cases p with
  | confirmed h =>
    have hh := hpar h rfl
    have hbconv : uint32ToInt32 blockHeight = some blockHeight := by
      have hle : blockHeight ≤ int32Max := by unfold int32Max; unfold mempoolHeight at hb; omega
      simp [uint32ToInt32, hle]
    have hbh : bdkBlockHeight blockHeight true = some blockHeight := by simp [bdkBlockHeight, hbconv]
    have hne : h ≠ unconfirmedParentHeight := by
      unfold unconfirmedParentHeight; unfold mempoolHeight at hh; omega
    have hconv : uint32ToInt32 h = some h := by
      have hle : h ≤ int32Max := by unfold int32Max; unfold mempoolHeight at hh; omega
      simp [uint32ToInt32, hle]
    have hm : (h == mempoolHeight) = false := by simp; omega
    simp only [teranodeInputWord, ParentHeight.teranodeSlot, substituteSlot, hne,
      ↓reduceIte, hconv, hbh, Option.bind_eq_bind, Option.bind_some, Bool.true_and, hm,
      Bool.false_eq_true, reduceCtorEq]
    rw [bdkCalculateFlags_consensus_eq cfgT cfgR hs h blockHeight (Nat.ne_of_lt hh)]
    rfl
  | unconfirmed =>
    rw [teranode_unconfirmed_refused_without_option]
    simp

/-- The pair (1) as a value: the reference's block word for a same-block parent at mainnet's Chronicle
height, and Teranode's refusal there without the option. -/
theorem teranode_block_word_ne_without_option :
    teranodeInputWord NodeConfig.teranodeDefault 943816 true false ParentHeight.unconfirmed.teranodeSlot
      ≠ some (referenceBlockWord NodeConfig.svMainnetDefault 943816 .unconfirmed) := by
  decide

/-- **#91, the pair where they differ (2): policy.** *What it says:* a reference node on a chain that does
not require standardness (stn, testnet, regtest: `requireStandard`'s docstring) with `-promiscuousmempoolflags`
set verifies mempool inputs under that word (`verify_script_flags.cpp:19–25`); GoBDK has no such setting
("intentionally absent", GoBDK `core/txvalidator.hpp:43–45`) and Teranode passes none, so Teranode's word is
the standard word. Shown with the empty promiscuous word on the mainnet heights, the activation heights being
an input of both words. A node's setting, never block validity: the block word is untouched. -/
theorem teranode_word_ne_promiscuous :
    teranodeInputWord NodeConfig.teranodeDefault 967897 false false (ParentHeight.confirmed 967000).teranodeSlot
      ≠ some (referenceMempoolWord
          { NodeConfig.svMainnetDefault with requireStandard := false, promiscuousMempoolFlags := some Flags.none }
          967896 (.confirmed 967000)) := by
  decide

end BsvChain.Teranode
