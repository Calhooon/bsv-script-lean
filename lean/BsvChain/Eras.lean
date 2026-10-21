import BsvChain.Block

/-!
# Chain-layer eras (#69)

The era-gated block rules as functions of height and `ChainParams`, at
[SRC] bitcoin-sv v1.2.3, `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.
Each function names the transition that reads it. The existing definitions
already carry four of the rules; this module adds the missing gate (BIP30),
the named predicates the proofs read (the version floor, the difficulty path),
and the setting residue of the UAHF size rule. No definition performs IO.

* BIP30: `bip30Enforced`, read by `eraConnectionChecks` (Chain.lean), the
  default of `ChainContext.connectionChecks`, which fills the
  `ConnectionChecks.bip30Required` hook of `prepareBlockConnection`
  [SRC] src/validation.cpp:3070–3117.
* Version floors: `versionObsolete`, the predicate inside
  `contextualCheckBlockHeader` [SRC] src/validation.cpp:5962–5972.
* Median-time-past cutoff: `blockFinalityCutoff` (#60, Finality.lean), read by
  `contextualCheckBlock` [SRC] src/validation.cpp:6046–6050,6067–6074.
* Difficulty: `nextWorkPath` names the branch `getNextWorkRequired` (Pow.lean)
  takes [SRC] src/pow.cpp:95–117.
* Pre-Genesis block sigops: `checkBlock` and `checkBlockInputs` (Block.lean)
  gate the count by the block's own era [SRC] src/validation.cpp:5818,5853–5866,3461,3352–3368.
* UAHF: no block check reads `uahfHeight` at the pin; see `LEGACY_MAX_BLOCK_SIZE`.
-/

namespace BsvChain
open BsvScript.Tx

/-! ## BIP30 -/

/-- The block at height 91842 that violates BIP30, by its hash in displayed
order. [SRC] src/validation.cpp:3070–3073 at 6504a3af. -/
def bip30ExceptionHash91842 : BitVec 256 :=
  0x00000000000a4d0a398161ffc163c503763b1f4360639393e0e4c8e300e0caec

/-- The block at height 91880 that violates BIP30, by its hash in displayed
order. [SRC] src/validation.cpp:3074–3077 at 6504a3af. -/
def bip30ExceptionHash91880 : BitVec 256 :=
  0x00000000000743f190a18c5577a3c2d2a1f610ae9601ac046a38084ccb7cd721

/-- The two historical exceptions, identified as the reference identifies them:
by height AND block hash, with no network test. The pair is compiled into the
connection code, not into `ChainParams`, so it is checked on every network;
testnet, STN and regtest have no exceptions of their own. A regtest block at
height 91842 is exempt only if its hash equals the mainnet block's hash.
The height test precedes the hash test, so the hash is read only at those two heights.
[SRC] src/validation.cpp:3057–3077 at 6504a3af. -/
def bip30Exception (height : Nat) (hash : BitVec 256) : Bool :=
  (height == 91842 && hash == bip30ExceptionHash91842) ||
  (height == 91880 && hash == bip30ExceptionHash91880)

/-- The BIP34 shortcut: the ancestor of the parent at `bip34Height` exists and
has the network's `bip34Hash`. `bip34Ancestor` is that ancestor's hash, `none`
when `GetAncestor` returns null (the block's height is at most `bip34Height`).
[SRC] src/validation.cpp:3079–3095 and src/consensus/params.h:20–22 at 6504a3af. -/
def bip34Shortcut (params : ChainParams) (bip34Ancestor : Option (BitVec 256)) : Bool :=
  bip34Ancestor.any (fun hash => hash.toNat == params.bip34Hash)

/-- C with a setting: whether connection runs the overwrite check. The two
historical exceptions, then the BIP34 shortcut, then the resolved node setting
`disableBip30Checks` (`GetDisableBIP30Checks`, the chain default when unset).
[SRC] src/validation.cpp:3070–3100 and src/config.cpp:2065–2067 at 6504a3af. -/
def bip30Enforced (params : ChainParams) (cfg : NodeConfig) (height : Nat)
    (hash : BitVec 256) (bip34Ancestor : Option (BitVec 256)) : Bool :=
  !bip30Exception height hash && !bip34Shortcut params bip34Ancestor && !cfg.disableBip30Checks

/-! ## Version floors -/

/-- C: the height floors on the header version, from the BIP34, BIP66 and
BIP65 activation heights. A height floor, not a version-majority vote.
[SRC] src/validation.cpp:5962–5972 at 6504a3af. -/
def versionObsolete (bip34 bip66 bip65 height : Nat) (version : Int) : Bool :=
  (version < 2 && height ≥ bip34) || (version < 3 && height ≥ bip66) ||
  (version < 4 && height ≥ bip65)

/-- The least accepted version at a height: the largest floor whose activation
the height has reached, `none` below all three. Derived from `versionObsolete`
for the theorems and the corpus. [SRC] src/validation.cpp:5965–5967 at 6504a3af. -/
def versionFloor (bip34 bip66 bip65 height : Nat) : Option Int :=
  if height ≥ bip65 then some 4
  else if height ≥ bip66 then some 3
  else if height ≥ bip34 then some 2
  else none

/-- The network's floor check for a header at `height`, with the reason and
code of `contextualCheckBlockHeader` (REJECT_OBSOLETE, 0x11); `none` for an unresolved activation
height. [SRC] src/validation.cpp:5962–5972 at 6504a3af. -/
def checkBlockVersion (params : ChainParams) (header : BlockHeader) (height : Nat) :
    Option (Except Reject Unit) := do
  let bip66 ← params.bip66Height
  let bip65 ← params.bip65Height
  return if versionObsolete params.bip34Height bip66 bip65 height header.signedVersion
    then .error ⟨.node 0x11, badVersionReason header⟩ else .ok ()

/-! ## Difficulty -/

/-- The four branches of `GetNextWorkRequired`.
[SRC] src/pow.cpp:95–117 at 6504a3af. -/
inductive WorkPath where
  | genesis | noRetargeting | cash | eda
  deriving DecidableEq, Repr

/-- The branch for a candidate whose parent has `parentHeight` (`none`: no
parent). No-retargeting precedes the DAA switch, which compares the PARENT's
height with `daaHeight`. [SRC] src/pow.cpp:101–116 at 6504a3af. -/
def nextWorkPath (params : ChainParams) (parentHeight : Option Nat) : WorkPath :=
  match parentHeight with
  | none => .genesis
  | some height =>
    if params.powNoRetargeting then .noRetargeting
    else if height ≥ params.daaHeight then .cash else .eda

/-! ## UAHF -/

/-- The pre-UAHF block size bound, 1,000,000 bytes.
[SRC] src/consensus/consensus.h:30–31 at 6504a3af. At the pin no block check
reads `uahfHeight` or this constant: `CheckBlock` and `ContextualCheckBlock`
bound the size by `GetMaxBlockSize()` only (src/validation.cpp:5795–5816,
6058–6065), and the only reader of `uahfHeight` is the script word, which adds
STRICTENC and SIGHASH_FORKID when the parent's height is at least `uahfHeight`
(src/verify_script_flags.cpp:54–59, called with the parent at
src/validation.cpp:2972–2981,3472). The constant's one reader is the setter of
the `excessiveBlockSize` setting below, whose comment names the "must be big"
UAHF rule (src/config.cpp:234–235).
[LIT] https://protocol.bsvblockchain.org/specification/blocks#block-size-by-era at v1.2.2 (the constant only). -/
def LEGACY_MAX_BLOCK_SIZE : Nat := 1000000

/-- C/setting: the values the `excessiveBlockSize` setter admits: zero (the
chain default) or strictly above the legacy bound. A launch or RPC value at or
below 1,000,000 bytes is refused, not stored.
[SRC] src/config.cpp:232–246 at 6504a3af. -/
def excessiveBlockSizeAdmissible (size : Nat) : Bool :=
  size == 0 || size > LEGACY_MAX_BLOCK_SIZE


/-! ## The selected network's data outside `Consensus::Params` -/

/-- The per-network values `CChainParams` holds beside the consensus record:
the checkpoint table (applied by `receiveHeader` under the `checkpointsEnabled`
setting), whether the BIP30 setting may be changed, the chain's standardness
default, and the defaults of the `minimumChainWork` and `assumeValid` settings.
Kinds: the table and the two defaults are network data read through settings
(PARAMETERS §8.2); none is a consensus rule. [SRC] src/chainparams.h:86,108,115 and
src/chainparams.cpp:1033–1559 at 6504a3af. -/
structure NetworkData where
  checkpoints : List (Nat × BitVec 256)
  canDisableBip30Checks : Bool
  requireStandard : Bool
  minimumChainWork : Nat
  assumeValid : BitVec 256
  deriving Repr

/-- mainnet: [SRC] src/chainparams.cpp:1056–1062 (the two defaults), 1121 (standardness),
1124–1160 (checkpoints; the source's comments name 478558 "UAHF fork block" and
504031 "DAA activation block"), 1187 (the BIP30 setting may not be changed) at 6504a3af. -/
def NetworkData.mainnet : NetworkData :=
  { checkpoints := [
      (11111, 0x0000000069e244f73d78e8fd29ba2fd2ed618bd6fa2ee92559f542fdb26e7c1d),
      (33333, 0x000000002dd5588a74784eaa7ab0507a18ad16a236e7b1ce69f00d7ddfb5d0a6),
      (74000, 0x0000000000573993a3c9e41ce34471c079dcf5f52a0e824a81e7f953b8661a20),
      (105000, 0x00000000000291ce28027faea320c8d2b054b2e0fe44a773f3eefb151d6bdc97),
      (134444, 0x00000000000005b12ffd4cd315cd34ffd4a594f430ac814c91184a0d42d2b0fe),
      (168000, 0x000000000000099e61ea72015e79632f216fe6cb33d7899acb35b75c8303b763),
      (193000, 0x000000000000059f452a5f7340de6682a977387c17010ff6e6c3bd83ca8b1317),
      (210000, 0x000000000000048b95347e83192f69cf0366076336c639f9b7228e9ba171342e),
      (216116, 0x00000000000001b4f4b433e81ee46494af945cf96014816a4e2370f11b23df4e),
      (225430, 0x00000000000001c108384350f74090433e7fcf79a606b8e797f065b130575932),
      (250000, 0x000000000000003887df1f29024b06fc2200b55f8af8f35453d7be294df2d214),
      (279000, 0x0000000000000001ae8c72a0b0c301f67e3afca10e819efa9041e458e9bd7e40),
      (295000, 0x00000000000000004d9b4ef50f0f9d686fd69db2e03af35a100370c64632a983),
      (478558, 0x0000000000000000011865af4122fe3b144e2cbeea86142e8ff2fb4107352d43),
      (504031, 0x0000000000000000011ebf65b60d0a3de80b8175be709d653b4c1a1beeb6ab9c),
      (530359, 0x0000000000000000011ada8bd08f46074f44a8f155396f43e38acf9501c49103)]
    canDisableBip30Checks := false
    requireStandard := true
    minimumChainWork := 0x000000000000000000000000000000000000000000a0f3064330647e2f6c4828
    assumeValid := 0x000000000000000000e45ad2fbcc5ff3e85f0868dd8f00ad4e92dffabe28f8d2 }

/-- testnet: [SRC] src/chainparams.cpp:1352–1358, 1416, 1419–1428, 1448 at 6504a3af. -/
def NetworkData.testnet : NetworkData :=
  { checkpoints := [
      (546, 0x000000002a936ca763904c3c35fce2f3556c559c0214345d31b1bcebf76acb70),
      (1155875, 0x00000000f17c850672894b9a75b63a1e72830bbd5f4c8889b5c1a80e7faef138),
      (1188697, 0x0000000000170ed0918077bde7b4d36cc4c91be69fa09211f748240dabe047fb)]
    canDisableBip30Checks := true
    requireStandard := false
    minimumChainWork := 0x00000000000000000000000000000000000000000000002a650f6ff7649485da
    assumeValid := 0x0000000000327972b8470c11755adf8f4319796bafae01f5a6650490b98a17db }

/-- STN: [SRC] src/chainparams.cpp:1222 (minimum work zero), 1271, 1274–1286, 1301 at
6504a3af. STN assigns no `defaultAssumeValid`; the member is a `uint256`, whose
constructor zeroes it [SRC] src/uint256.h:35, so the default is zero (disabled). -/
def NetworkData.stn : NetworkData :=
  { checkpoints := [
      (0, 0x000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943),
      (1, 0x00000000e23f9436cc8a6d6aaaa515a7b84e7a1720fc9f92805c0007c77420c4),
      (2, 0x0000000040f8f40b5111d037b8b7ff69130de676327bcbd76ca0e0498a06c44a),
      (4, 0x00000000d33661d5a6906f84e3c64ea6101d144ec83760bcb4ba81edcb15e68d),
      (5, 0x00000000e9222ebe623bf53f6ec774619703c113242327bdc24ac830787873d6),
      (6, 0x00000000764a4ff15c2645e8ede0d0f2af169f7a517dd94a6778684ed85a51e4),
      (7, 0x000000001f15fe3dac966c6bb873c63348ca3d877cd606759d26bd9ad41e5545),
      (8, 0x0000000074230d332b2ed9d87af3ad817b6f2616c154372311c9b2e4f386c24c),
      (9, 0x00000000ca21de811f04f5ec031aa3a102f8e27f2a436cde588786da1996ec9b),
      (10, 0x0000000046ceee1b7d771594c6c75f11f14f96822fd520e86ec5c703ec231e87),
      (11, 0x00000000e1ad0ed45011a4c7fe5afde3211b4bdcf60370234355338afbf70e2d)]
    canDisableBip30Checks := true
    requireStandard := false
    minimumChainWork := 0
    assumeValid := 0 }

/-- regtest: [SRC] src/chainparams.cpp:1480–1484, 1527, 1530–1533, 1556 at 6504a3af. -/
def NetworkData.regtest : NetworkData :=
  { checkpoints := [(0, 0x0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206)]
    canDisableBip30Checks := true
    requireStandard := false
    minimumChainWork := 0
    assumeValid := 0 }

/-- The selected network's defaults for `minimumChainWork` and `assumeValid`,
which explicit operator values may replace, and its fixed `chainRequireStandard`
value. Relay script flags read `CChainParams::RequireStandard()` directly
[SRC] src/validation.cpp:795–801, src/chainparams.h:86 at 6504a3af.
The operator's `-acceptnonstdtxn` initializes the separate inherited admission
setting `requireStandard` [SRC] src/init.cpp:3158–3160, src/config.cpp:867–869,
src/configscriptpolicy.cpp:478–486 at 6504a3af.
[SRC] src/init.cpp:2355–2375 at 6504a3af for the two operator defaults. -/
def NodeConfig.withNetwork (cfg : NodeConfig) (net : NetworkData) : NodeConfig :=
  { cfg with minimumChainWork := net.minimumChainWork,
             assumeValid := net.assumeValid,
             chainRequireStandard := net.requireStandard }

end BsvChain
