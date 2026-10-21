import BsvChain.Eras
import BsvChain.Chain

/-!
# Chain-layer era theorems (#69)

The issue's two theorems in the form the machine proves, and the three era
switches the brief adds (version floors, the UAHF reader, the CSV cutoff).
Each statement names the executable definitions; each premise is stated.
[SRC] bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`:
src/pow.cpp:95–117, src/validation.cpp:3070–3117,5962–5972,6039–6104,
src/verify_script_flags.cpp:32–81, src/chainparams.cpp:1038–1068,1463–1490.
-/

namespace BsvChain.Properties
open BsvScript.Tx

/-! ## (a) The difficulty path -/

/-- For a candidate with a parent, `getNextWorkRequired` takes exactly the branch `nextWorkPath`
names: the parent's bits under no-retargeting, the cash algorithm when the
parent's height reaches `daaHeight`, the EDA otherwise. Premise: the header
chain has a parent (`ancestors = p :: rest`). [SRC] src/pow.cpp:95–117 at 6504a3af. -/
theorem getNextWorkRequired_path (params : ChainParams) (cfg : NodeConfig)
    (chain : HeaderChain) (candidate : BlockHeader) (p : HeaderWork) (rest : List HeaderWork)
    (hp : chain.ancestors = p :: rest) :
    getNextWorkRequired params cfg (some chain) candidate =
      match nextWorkPath params (some chain.height) with
      | .genesis => some (targetCompact params.powLimit)
      | .noRetargeting => some p.bits
      | .cash => getNextCashWorkRequired params chain candidate
      | .eda => getNextEDAWorkRequired params cfg chain candidate := by
  unfold getNextWorkRequired nextWorkPath
  simp only [hp, List.head?_cons, Option.pure_def, Option.bind_eq_bind, Option.bind_some]
  split <;> split <;> simp_all

/-- (a) for ANY parameters with `fPowNoRetargeting` set: the path is
no-retargeting at every parent height, whatever `daaHeight` is, because the
flag is tested before the DAA height. Premise: the flag.
[SRC] src/pow.cpp:106–113 at 6504a3af. -/
theorem nextWorkPath_no_retargeting (params : ChainParams)
    (hnr : params.powNoRetargeting = true) (height : Nat) :
    nextWorkPath params (some height) = .noRetargeting := by
  simp [nextWorkPath, hnr]

/-- (a) for ANY parameters with `fPowNoRetargeting` set: every next-work
computation with a parent returns the parent's bits; the DAA height is never
read. Premises: the flag and a parent (`ancestors = p :: rest`); the genesis
case is :101–104. [SRC] src/pow.cpp:101–117 at 6504a3af. -/
theorem s6_no_retargeting_parent_bits (params : ChainParams) (cfg : NodeConfig)
    (hnr : params.powNoRetargeting = true) (chain : HeaderChain)
    (candidate : BlockHeader) (p : HeaderWork) (rest : List HeaderWork)
    (hp : chain.ancestors = p :: rest) :
    getNextWorkRequired params cfg (some chain) candidate = some p.bits := by
  have h := getNextWorkRequired_path params cfg chain candidate p rest hp
  rw [nextWorkPath_no_retargeting params hnr] at h
  exact h

/-- (a), the true form of the issue's "on regtest the post-DAA path is taken
from height 0". Regtest compiles `daaHeight = 0` AND `fPowNoRetargeting =
true` (src/chainparams.cpp:1477,1490), and `GetNextWorkRequired` returns the
parent's bits at :107–109, before it tests the DAA height at :111–113; so on
regtest no next-work computation reaches the DAA. Every one returns the
parent's bits. Premise: a parent exists (`ancestors = p :: rest`); the genesis
case is :101–104. The general form is `s6_no_retargeting_parent_bits`, for
every network with the flag set; this theorem is its regtest instance.
[SRC] src/pow.cpp:101–117 at 6504a3af. -/
theorem s6_regtest_next_work_parent_bits (cfg : NodeConfig) (chain : HeaderChain)
    (candidate : BlockHeader) (p : HeaderWork) (rest : List HeaderWork)
    (hp : chain.ancestors = p :: rest) :
    getNextWorkRequired .regtest cfg (some chain) candidate = some p.bits :=
  s6_no_retargeting_parent_bits .regtest cfg rfl chain candidate p rest hp

/-- On regtest the path is no-retargeting at every parent height; the cash
branch is never named. The general form is `nextWorkPath_no_retargeting`, for
every network with the flag set. [SRC] src/pow.cpp:106–109, src/chainparams.cpp:1477 at 6504a3af. -/
theorem s6_regtest_path_no_retargeting (height : Nat) :
    nextWorkPath .regtest (some height) = .noRetargeting := rfl

/-- (a), the DAA half: for ANY parameters with `daaHeight = 0` and
no-retargeting off (testing the DAA separately, as DESIGN-S6 §4.2 requires),
the cash algorithm is taken at every parent height, from height 0.
Premises: the two parameter values and a parent. [SRC] src/pow.cpp:107–113 at 6504a3af. -/
theorem s6_daa_zero_cash_path (params : ChainParams) (cfg : NodeConfig)
    (hdaa : params.daaHeight = 0) (hnr : params.powNoRetargeting = false)
    (chain : HeaderChain) (candidate : BlockHeader) (p : HeaderWork) (rest : List HeaderWork)
    (hp : chain.ancestors = p :: rest) :
    nextWorkPath params (some chain.height) = .cash ∧
    getNextWorkRequired params cfg (some chain) candidate = getNextCashWorkRequired params chain candidate := by
  have hpath : nextWorkPath params (some chain.height) = .cash := by
    simp [nextWorkPath, hdaa, hnr]
  refine ⟨hpath, ?_⟩
  rw [getNextWorkRequired_path _ _ _ _ p rest hp, hpath]

/-- (a) for ANY parameters with `fPowNoRetargeting` off: the path is the cash
algorithm from the parent height `daaHeight` on and the EDA below it.
Premise: the flag. [SRC] src/pow.cpp:106–116 at 6504a3af. -/
theorem nextWorkPath_retargeting (params : ChainParams)
    (hnr : params.powNoRetargeting = false) (height : Nat) :
    nextWorkPath params (some height) =
      if params.daaHeight ≤ height then .cash else .eda := by
  simp [nextWorkPath, hnr]

/-- Mainnet's DAA switch reads the parent's height: a candidate whose parent
is at 504030 takes the EDA, one whose parent is at `daaHeight` = 504031 the
cash algorithm. The general form is `nextWorkPath_retargeting`; this theorem
reads mainnet's two values from its record. [SRC] src/pow.cpp:111–116, src/chainparams.cpp:1068 at 6504a3af. -/
theorem s6_mainnet_daa_switch (height : Nat) :
    nextWorkPath .mainnet (some height) = if 504031 ≤ height then .cash else .eda := by
  simp [nextWorkPath, ChainParams.mainnet]

/-- For ANY parameters with `fPowNoRetargeting` set, a header accepted by the
contextual check carries its parent's bits, for every configuration and every
`now`. Premises: the flag, acceptance and a parent.
[SRC] src/validation.cpp:5943–5948, src/pow.cpp:106–109 at 6504a3af. -/
theorem s6_no_retargeting_accepted_header_bits (params : ChainParams) (cfg : NodeConfig)
    (hnr : params.powNoRetargeting = true) (header : BlockHeader)
    (previous : HeaderChain) (now : Int) (p : HeaderWork) (rest : List HeaderWork)
    (hp : previous.ancestors = p :: rest)
    (h : contextualCheckBlockHeader params cfg header previous now = some (.ok ())) :
    header.bits = p.bits := by
  unfold contextualCheckBlockHeader at h
  rw [s6_no_retargeting_parent_bits params cfg hnr previous header p rest hp] at h
  simp only [bind, Option.bind, pure] at h
  split at h
  · cases h
  · rename_i hb
    simpa using hb

/-- A regtest header accepted by the contextual check carries its parent's
bits: the measured "every regtest block has the genesis bits" is this,
iterated along the chain. Premises: acceptance and a parent. The general form
is `s6_no_retargeting_accepted_header_bits`; this theorem is its regtest
instance. [SRC] src/validation.cpp:5943–5948, src/pow.cpp:106–109 at 6504a3af. -/
theorem s6_regtest_accepted_header_bits (cfg : NodeConfig) (header : BlockHeader)
    (previous : HeaderChain) (now : Int) (p : HeaderWork) (rest : List HeaderWork)
    (hp : previous.ancestors = p :: rest)
    (h : contextualCheckBlockHeader .regtest cfg header previous now = some (.ok ())) :
    header.bits = p.bits :=
  s6_no_retargeting_accepted_header_bits .regtest cfg rfl header previous now p rest hp h

/-! ## (b) BIP30 -/

/-- The gate unfolded: enforced iff the block is not one of the two historical
exceptions, the BIP34 shortcut does not apply, and the resolved setting does
not disable it. [SRC] src/validation.cpp:3070–3100 at 6504a3af. -/
theorem bip30Enforced_iff (params : ChainParams) (cfg : NodeConfig) (height : Nat)
    (hash : BitVec 256) (anc : Option (BitVec 256)) :
    bip30Enforced params cfg height hash anc = true ↔
      bip30Exception height hash = false ∧ bip34Shortcut params anc = false ∧
      cfg.disableBip30Checks = false := by
  simp [bip30Enforced, and_assoc]

/-- (b), the true form of the issue's "BIP30 is enforced at every height but the
two named": on every network, when the BIP34 shortcut does not apply and the
setting is off, the check runs unless the block is (91842, its hash) or
(91880, its hash). The exceptions are height AND hash; a different block at
either height is checked. The issue's unconditional sentence is false on
mainnet above BIP34 activation, where the shortcut skips the check on the known
chain (`s6_bip30_bip34_shortcut`), and wherever the network permits the setting.
Premises: shortcut absent, setting off. [SRC] src/validation.cpp:3070–3100 at 6504a3af. -/
theorem s6_bip30_two_exceptions (params : ChainParams) (cfg : NodeConfig)
    (hcfg : cfg.disableBip30Checks = false) (height : Nat) (hash : BitVec 256)
    (anc : Option (BitVec 256)) (hanc : bip34Shortcut params anc = false) :
    bip30Enforced params cfg height hash anc = true ↔
      ¬ ((height = 91842 ∧ hash = bip30ExceptionHash91842) ∨
         (height = 91880 ∧ hash = bip30ExceptionHash91880)) := by
  simp [bip30Enforced, bip30Exception, hcfg, hanc, Decidable.imp_iff_not_or]

/-- The BIP34 shortcut: when the parent's ancestor at `bip34Height` carries the
network's `bip34Hash`, connection skips the BIP30 check at any height.
[SRC] src/validation.cpp:3088–3095 at 6504a3af. -/
theorem s6_bip30_bip34_shortcut (params : ChainParams) (cfg : NodeConfig)
    (height : Nat) (hash h : BitVec 256) (hh : h.toNat = params.bip34Hash) :
    bip30Enforced params cfg height hash (some h) = false := by
  simp [bip30Enforced, bip34Shortcut, hh]

/-- The chain transition's gate: for an index at or below `bip34Height` the
ancestor is never read, so with the setting off the default
`eraConnectionChecks` requires BIP30 exactly outside the two exceptions.
Premises: the height bound and the setting. [SRC] src/validation.cpp:3070–3100 at 6504a3af. -/
theorem s6_bip30_connection_gate (params : ChainParams) (cfg : NodeConfig)
    (hcfg : cfg.disableBip30Checks = false) (s : ChainState) (i : BlockIndex)
    (hheight : i.height ≤ params.bip34Height) :
    (eraConnectionChecks params cfg s i).bip30Required = true ↔
      ¬ ((i.height = 91842 ∧ i.id = bip30ExceptionHash91842) ∨
         (i.height = 91880 ∧ i.id = bip30ExceptionHash91880)) := by
  have hanc : bip34Ancestor params s.tree i = none := by
    simp [bip34Ancestor]; omega
  simp only [eraConnectionChecks, hanc]
  exact s6_bip30_two_exceptions params cfg hcfg _ _ none (by simp [bip34Shortcut])

/-- (b) on regtest: below `bip34Height` = 100,000,000 (src/chainparams.cpp:1463),
with the setting at its default, every block at a height other than 91842 and
91880 has BIP30 required by the chain transition; at those two heights only
the two mainnet hashes are exempt. The general form is
`s6_bip30_connection_gate`, for every network; this theorem is its regtest
instance. [SRC] src/validation.cpp:3070–3100 at 6504a3af. -/
theorem s6_bip30_regtest (cfg : NodeConfig) (hcfg : cfg.disableBip30Checks = false)
    (s : ChainState) (i : BlockIndex) (hheight : i.height ≤ 100000000)
    (h1 : i.height ≠ 91842) (h2 : i.height ≠ 91880) :
    (eraConnectionChecks .regtest cfg s i).bip30Required = true :=
  (s6_bip30_connection_gate .regtest cfg hcfg s i hheight).2 (by omega)

/-- (b) on mainnet through height 227931 (BIP34 activation, src/chainparams.cpp:1038):
with the setting off, BIP30 is required at every block but the two named.
The general form is `s6_bip30_connection_gate`; this theorem is its mainnet
instance. [SRC] src/validation.cpp:3070–3100 at 6504a3af. -/
theorem s6_bip30_mainnet (cfg : NodeConfig) (hcfg : cfg.disableBip30Checks = false)
    (s : ChainState) (i : BlockIndex) (hheight : i.height ≤ 227931) :
    (eraConnectionChecks .mainnet cfg s i).bip30Required = true ↔
      ¬ ((i.height = 91842 ∧ i.id = bip30ExceptionHash91842) ∨
         (i.height = 91880 ∧ i.id = bip30ExceptionHash91880)) :=
  s6_bip30_connection_gate .mainnet cfg hcfg s i hheight

/-! ## (c) The version floors -/

/-- The floor predicate is "below the largest floor reached", for any order of
the three activation heights (regtest's are not monotone).
[SRC] src/validation.cpp:5965–5967 at 6504a3af. -/
theorem versionObsolete_iff_floor (bip34 bip66 bip65 height : Nat) (version : Int) :
    versionObsolete bip34 bip66 bip65 height version = true ↔
      ∃ floor, versionFloor bip34 bip66 bip65 height = some floor ∧ version < floor := by
  unfold versionObsolete versionFloor
  split_ifs <;> simp_all <;> omega

/-- (c): with the bits and the two timestamp checks passed, the contextual
header check is exactly the version floor check at the block's height.
Premises: the three earlier checks pass, as `contextualCheckBlockHeader`
orders them. [SRC] src/validation.cpp:5943–5972 at 6504a3af. -/
theorem s6_contextual_header_version (params : ChainParams) (cfg : NodeConfig)
    (header : BlockHeader) (previous : HeaderChain) (now : Int) (median : Nat)
    (hw : getNextWorkRequired params cfg (some previous) header = some header.bits)
    (hm : previous.medianAt cfg previous.height = some median)
    (hlo : median < header.time.toNat)
    (hhi : (header.time.toNat : Int) ≤ now + cfg.maxFutureBlockTimeSeconds) :
    contextualCheckBlockHeader params cfg header previous now =
      checkBlockVersion params header (previous.height + 1) := by
  unfold contextualCheckBlockHeader checkBlockVersion
  simp only [hw, hm, bind, Option.bind, pure, bne_self_eq_false, Bool.false_eq_true, ite_false]
  have h1 : ¬ header.time.toNat ≤ median := by omega
  have h2 : ¬ (header.time.toNat : Int) > now + cfg.maxFutureBlockTimeSeconds := by omega
  simp only [h1, h2, ite_false]
  cases params.bip66Height <;> cases params.bip65Height <;> simp [versionObsolete]
  split <;> rfl

/-- (c) six concrete mainnet floor cells: none at 227930, 2 at 227931 and
363724, 3 at 363725 and 388380, and 4 at 388381 (BIP34 227931, BIP66 363725,
BIP65 388381, src/chainparams.cpp:1038,1044,1042). The three heights are read
from mainnet's record, `ChainParams.mainnet`, in its leading three conjuncts.
The general equivalence is `versionObsolete_iff_floor`.
[SRC] src/validation.cpp:5965–5967 at 6504a3af. -/
theorem s6_mainnet_version_floors :
    ChainParams.mainnet.bip34Height = 227931 ∧
    ChainParams.mainnet.bip66Height = some 363725 ∧
    ChainParams.mainnet.bip65Height = some 388381 ∧
    versionFloor 227931 363725 388381 227930 = none ∧
    versionFloor 227931 363725 388381 227931 = some 2 ∧
    versionFloor 227931 363725 388381 363724 = some 2 ∧
    versionFloor 227931 363725 388381 363725 = some 3 ∧
    versionFloor 227931 363725 388381 388380 = some 3 ∧
    versionFloor 227931 363725 388381 388381 = some 4 := by
  refine ⟨rfl, rfl, rfl, ?_⟩
  decide

/-- (c) on regtest (BIP34 100,000,000, BIP66 1251, BIP65 1351,
src/chainparams.cpp:1463–1468): BIP66's floor of 3 binds at 1251 before BIP34,
then BIP65's floor of 4 binds at 1351. The BIP34 floor never binds alone.
A version-1 block passes the floors only below
height 1251; versions 1 and 2 are rejected from 1251 and version 3 from 1351.
The general equivalence is `versionObsolete_iff_floor`; this theorem is its
regtest instance. [SRC] src/validation.cpp:5965–5967 at 6504a3af. -/
theorem s6_regtest_version_floors (height : Nat) (version : Int) :
    versionObsolete ChainParams.regtest.bip34Height 1251 1351 height version = true ↔
      (version < 3 ∧ 1251 ≤ height) ∨ (version < 4 ∧ 1351 ≤ height) := by
  simp only [versionObsolete, ChainParams.regtest]
  constructor
  · intro h; simp at h; omega
  · intro h; simp; omega

/-! ## (d) The UAHF height -/

/-- (d), the true form of "the fork-block size rule at `uahfHeight` and only
there": at the pin no block size rule reads `uahfHeight`. `checkBlock` is the
same function for every value of it. [SRC] src/validation.cpp:5749–5901 at 6504a3af. -/
theorem s6_checkBlock_uahf_irrelevant (params : ChainParams) (u : Nat) (cfg : NodeConfig)
    (block : Block) (height : Nat) (options : BlockCheckOptions) :
    checkBlock { params with uahfHeight := u } cfg block height options =
      checkBlock params cfg block height options := rfl

/-- The body's contextual check (size, finality, coinbase height) does not read
`uahfHeight`. [SRC] src/validation.cpp:6039–6104 at 6504a3af. -/
theorem s6_contextualCheckBlock_uahf_irrelevant (params : ChainParams) (u : Nat)
    (cfg : NodeConfig) (block : Block) (previous : Option HeaderChain) :
    contextualCheckBlock { params with uahfHeight := u } cfg block previous =
      contextualCheckBlock params cfg block previous := rfl

/-- The header's contextual check does not read `uahfHeight`.
[SRC] src/validation.cpp:5933–5975, src/pow.cpp:22–297 at 6504a3af. -/
theorem s6_contextualCheckBlockHeader_uahf_irrelevant (params : ChainParams) (u : Nat)
    (cfg : NodeConfig) (header : BlockHeader) (previous : HeaderChain) (now : Int) :
    contextualCheckBlockHeader { params with uahfHeight := u } cfg header previous now =
      contextualCheckBlockHeader params cfg header previous now := rfl

/-- (d) where `uahfHeight` IS read: the theorem equates the block script word's
FORKID bit to whether the PARENT's height (the block's height minus one)
reaches `uahfHeight`. The source additionally sets STRICTENC at that boundary;
that bit is not part of this theorem's equality. On regtest (`uahfHeight = 0`,
src/chainparams.cpp:1487) that is every block above genesis. Premise: the
network's script heights are assigned. [SRC] src/verify_script_flags.cpp:54–59, src/validation.cpp:2972–2981 at 6504a3af. -/
theorem s6_uahf_script_word (cfg : NodeConfig) (params : ChainParams)
    (sp : BsvScript.Params.ChainParams) (hsp : params.toScript? = some sp) (height : Nat) :
    (ordinaryScriptFlags cfg params height true).map (·.enableSighashForkid) =
      some (decide (params.uahfHeight ≤ height - 1)) := by
  have hu : sp.uahfHeight = params.uahfHeight := by
    unfold ChainParams.toScript? at hsp
    cases h65 : params.bip65Height <;> cases h66 : params.bip66Height <;>
      cases hc : params.csvHeight <;> simp_all
    subst hsp; rfl
  simp [ordinaryScriptFlags, hsp, BsvScript.Params.blockScriptFlags, hu]

/-! ## (e) The lock-time cutoff -/

/-- (e): from `csvHeight` the block's finality cutoff is the median time past of
the previous blocks; below it, the block's own time. Premise: the network
assigns `csvHeight`. [SRC] src/validation.cpp:6046–6050,6055–6056,6067–6074 at 6504a3af. -/
theorem s6_lock_cutoff_switch (params : ChainParams) (cfg : NodeConfig) (k : Nat)
    (hk : params.csvHeight = some k) (height blockTime : Nat) (previousTimes : List Nat) :
    blockFinalityCutoff params cfg height blockTime previousTimes =
      some (if k ≤ height then medianTimePast previousTimes cfg.medianTimeSpan else blockTime) := by
  simp [blockFinalityCutoff, hk]

/-- (e) at mainnet's CSV height 419,328 (src/chainparams.cpp:1046): the block at
419,327 is judged against its own time, the block at 419,328 against the
previous median. The general form is `s6_lock_cutoff_switch`, for every
network that assigns `csvHeight`; this theorem is its mainnet instance.
[SRC] src/validation.cpp:6046–6050 at 6504a3af. -/
theorem s6_mainnet_lock_cutoff (cfg : NodeConfig) (blockTime : Nat) (previousTimes : List Nat) :
    blockFinalityCutoff .mainnet cfg 419327 blockTime previousTimes = some blockTime ∧
    blockFinalityCutoff .mainnet cfg 419328 blockTime previousTimes =
      some (medianTimePast previousTimes cfg.medianTimeSpan) := by
  constructor <;> simp [blockFinalityCutoff, ChainParams.mainnet]

/-- (e) applied to a transaction: the block's finality judge compares the lock
time with that cutoff, so a time-locked transaction final against the block's
own time below `csvHeight` is judged against the median from it.
[SRC] src/validation.cpp:5977–5996,6067–6083 at 6504a3af. -/
theorem s6_block_finality_cutoff (params : ChainParams) (cfg : NodeConfig) (k : Nat)
    (hk : params.csvHeight = some k) (tx : Tx) (height blockTime : Nat) (previousTimes : List Nat) :
    contextualCheckTransactionForBlock params cfg tx height blockTime previousTimes =
      some (contextualCheckTransaction params tx height
        (if k ≤ height then medianTimePast previousTimes cfg.medianTimeSpan else blockTime) true) := by
  simp [contextualCheckTransactionForBlock, s6_lock_cutoff_switch params cfg k hk]

end BsvChain.Properties
