import BsvChain.Chain

/-!
# Validation depth and safe mode (#73)

[M] 2026-10-14 (#73). [SRC] bitcoin-sv v1.2.3 at
6504a3aff65ba97c0f6c80962b033e35ecbfed4b.

The model defines the depth settings, per-network data, script-check decision,
and safe-mode client projections. `scriptChecksRequired` has the six conditions
listed at its definition; `ConnectionChecks.checkScripts` receives its result
through `ChainContext.withValidationDepth`. These are policy settings and client
projections. The model theorems and their premises are in
`BsvChain/Properties/Depth.lean`. Source interpretations and the recorded corpus
scope are in `docs/records/20261014-013925-s6-73-regtest-s3.md`.
-/

namespace BsvChain

/-! ## The network data of the depth settings -/

/-- P network data: the compiled work floor, assumed-valid hash and checkpoint
table of one network. The node's launch values are `-minimumchainwork`,
`-assumevalid` and `-checkpoints`; `NodeConfig`'s three fields carry the
resolved values and their template is mainnet's.
[SRC] src/consensus/params.h:50-51, src/checkpoints.cpp:14-36,
src/init.cpp:2352-2382 at 6504a3af. -/
structure DepthNetwork where
  minimumChainWork : Nat
  assumeValid : BitVec 256
  checkpoints : List (Nat × BitVec 256)

/-- P mainnet's depth data: sixteen checkpoints.
[SRC] src/chainparams.cpp:1056-1057,1061-1062,1124-1160 at 6504a3af. -/
def DepthNetwork.mainnet : DepthNetwork where
  minimumChainWork := 0x000000000000000000000000000000000000000000a0f3064330647e2f6c4828
  assumeValid := 0x000000000000000000e45ad2fbcc5ff3e85f0868dd8f00ad4e92dffabe28f8d2
  checkpoints := [
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

/-- P testnet's depth data: three checkpoints.
[SRC] src/chainparams.cpp:1352-1353,1357-1358,1419-1428 at 6504a3af. -/
def DepthNetwork.testnet : DepthNetwork where
  minimumChainWork := 0x00000000000000000000000000000000000000000000002a650f6ff7649485da
  assumeValid := 0x0000000000327972b8470c11755adf8f4319796bafae01f5a6650490b98a17db
  checkpoints := [
    (546, 0x000000002a936ca763904c3c35fce2f3556c559c0214345d31b1bcebf76acb70),
    (1155875, 0x00000000f17c850672894b9a75b63a1e72830bbd5f4c8889b5c1a80e7faef138),
    (1188697, 0x0000000000170ed0918077bde7b4d36cc4c91be69fa09211f748240dabe047fb)]

/-- P regtest's depth data: a zero floor, no assumed-valid hash, and the
genesis block as the only checkpoint.
[SRC] src/chainparams.cpp:1480,1484,1530-1533 at 6504a3af. -/
def DepthNetwork.regtest : DepthNetwork where
  minimumChainWork := 0
  assumeValid := 0
  checkpoints := [(0, 0x0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206)]

/-- P STN's depth data: a zero floor, no assumed-valid hash (the constructor
assigns none, the member's zero) and eleven checkpoints (heights 0 through 11 excluding 3).
[SRC] src/chainparams.cpp:1195-1304 (the floor at :1222, the table at
:1274-1285) and src/consensus/params.h:50-51 at 6504a3af. -/
def DepthNetwork.stn : DepthNetwork where
  minimumChainWork := 0
  assumeValid := 0
  checkpoints := [
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

/-! ## The script-check decision -/

/-- `GetAncestor`: the index at `height` on the chain ending at `i`, absent
above the tip or on broken ancestry.
[SRC] src/block_index.cpp:75-112 and src/validation.cpp:3494-3495
at 6504a3af. -/
def ancestorAt (tree : HeaderTree) (i : BlockIndex) (height : Nat) : Option BlockIndex :=
  if height > i.height then none
  else (ancestry tree (tree.nodes.length + 1) (some i.id)).bind
    (fun path => path.find? (fun p => p.height == height))

/-- The pointer test `tip->GetAncestor(i->GetHeight()) == i`: `i` is on the
chain ending at `tip`, compared by block identifier.
[SRC] src/validation.cpp:3494-3495 at 6504a3af. -/
def onChainOf (tree : HeaderTree) (tip i : BlockIndex) : Bool :=
  (ancestorAt tree tip i.height).any (fun p => p.id == i.id)

/-- P the store's best-header rule at insertion: the new index replaces the
pointer exactly when the work comparator prefers it. Nothing clears the
pointer when its block is later marked failed.
[SRC] src/block_index_store.h:71-75,131-150 and src/block_index.h:1225-1274
at 6504a3af. -/
def bestHeaderStep (best : Option BlockIndex) (new : BlockIndex) : Option BlockIndex :=
  match best with
  | none => some new
  | some b => if preferred new b then some new else some b

/-- [D] 2026-10-14: the model's default best header, folded over the tree in
insertion order using the current indices. `scriptChecksRequired` accepts an
explicit best-header observation. Stored-pointer and history limitations are
in `docs/records/20261014-013925-s6-73-regtest-s3.md`.
[SRC] src/block_index_store.h:47-78,131-150 at 6504a3af. -/
def bestHeader (tree : HeaderTree) : Option BlockIndex :=
  tree.nodes.foldl bestHeaderStep none

/-- The 63-bit saturation of the reference's signed result: a quotient of 64
bits or more becomes the largest signed 64-bit value.
[SRC] src/block_index.cpp:146-149 at 6504a3af. -/
def saturateInt63 (r : Nat) : Int := if r ≥ 2 ^ 63 then 2 ^ 63 - 1 else r

/-- `GetBlockProofEquivalentTime`: the work between two indices as seconds at
the tip's own proof rate, with the unsigned 256-bit product, the 63-bit
saturation and the sign of the direction. `none` is the reference's division
by a zero proof (an exception there); no stored header has one, since a
header's target passed the proof-of-work check.
[SRC] src/block_index.cpp:130-150, src/arith_uint256.h:160-161,206-210
at 6504a3af. -/
def blockProofEquivalentTime (params : ChainParams) (toWork fromWork : BitVec 256)
    (tipBits : BitVec 32) : Option Int :=
  if blockProof tipBits = 0 then none
  else if toWork.toNat > fromWork.toNat then
    some (saturateInt63 ((toWork.toNat - fromWork.toNat) * (params.powTargetSpacing % 2 ^ 64) % 2 ^ 256 /
      blockProof tipBits))
  else
    some (-(saturateInt63 ((fromWork.toNat - toWork.toNat) * (params.powTargetSpacing % 2 ^ 64) % 2 ^ 256 /
      blockProof tipBits)))

/-- P the effective script-check decision of one block connection, exactly the
reference's `fScriptChecks`: `true` runs the input scripts, `false` skips them.
The skip needs every conjunct, in source order:

1. an assumed-valid hash is configured (`hashAssumeValid` not null, :3483);
2. that hash is a block of the index (:3491);
3. the connecting block is on the assumed block's chain (:3494);
4. the connecting block is on the best header's chain (:3495);
5. the best header's work is at least `minimumChainWork` (:3496);
6. the proof-equivalent time from the block to the best header, at the best
   header's proof rate, exceeds `assumeValidMinWorkTimeSeconds`, two weeks
   (:3511-3514).

The model uses proof-equivalent time. An absent best header or a zero proof
returns `true`; the source/model boundary is recorded in
`docs/records/20261014-013925-s6-73-regtest-s3.md`.
[SRC] src/validation.cpp:3482-3518 at 6504a3af. -/
def scriptChecksRequired (params : ChainParams) (cfg : NodeConfig) (tree : HeaderTree)
    (best : Option BlockIndex) (i : BlockIndex) : Bool :=
  if cfg.assumeValid == 0 then true else
    match tree.get cfg.assumeValid, best with
    | some assumed, some best =>
      if onChainOf tree assumed i && onChainOf tree best i &&
          best.work.toNat ≥ cfg.minimumChainWork then
        match blockProofEquivalentTime params best.work i.work best.header.bits with
        | some seconds => seconds ≤ (cfg.assumeValidMinWorkTimeSeconds : Int)
        | none => true
      else true
    | _, _ => true

/-- P the connection checks of the reference node: the lanes' other decisions
unchanged, `checkScripts` the depth decision on the tree and best header of
the state the connection sees.
[SRC] src/validation.cpp:3482-3518,4261-4262 at 6504a3af. -/
def validationDepthChecks (ctx : ChainContext)
    (base : ChainState → BlockIndex → BlockIndex → ConnectionChecks)
    (s : ChainState) (i target : BlockIndex) : ConnectionChecks :=
  { base s i target with
    checkScripts := scriptChecksRequired ctx.params ctx.cfg s.tree (bestHeader s.tree) i }

/-- P a context whose connections take the depth decision: the fill of
`ChainContext.connectionChecks`' `checkScripts` (Block.lean's
`ConnectionChecks`). The record's default (every script judged) is the node
with no assumed-valid hash; a node configured with one is this context.
[SRC] src/validation.cpp:3482-3518 at 6504a3af. -/
def ChainContext.withValidationDepth (ctx : ChainContext) : ChainContext :=
  { ctx with connectionChecks := validationDepthChecks ctx ctx.connectionChecks }

/-- P the wiring premise of the depth theorems: this context's connections use
the depth decision. `withValidationDepth` builds such a context.
[SRC] src/validation.cpp:3482-3518 at 6504a3af. -/
def DepthWired (ctx : ChainContext) : Prop :=
  ∀ s i target, (ctx.connectionChecks s i target).checkScripts =
    scriptChecksRequired ctx.params ctx.cfg s.tree (bestHeader s.tree) i

/-! ## Safe mode: a client behavior -/

/-- P the safe-mode level, in the reference's numeric order (the maximum over
the forks is taken in this order).
[SRC] src/warnings.h:13-35 at 6504a3af. -/
inductive SafeModeLevel where
  | none | unknown | invalid | valid
  deriving DecidableEq, Repr

/-- The level's numeric value. [SRC] src/warnings.h:13-35 at 6504a3af. -/
def SafeModeLevel.rank : SafeModeLevel → Nat
  | .none => 0 | .unknown => 1 | .invalid => 2 | .valid => 3

/-- P the client switches of safe mode that are not `NodeConfig` fields:
`-disablesafemode` (default false) lifts the RPC refusal, `-testsafemode`
(default false) forces the RPC warning. The webhook address
(`-safemodewebhookurl`, default empty) only adds a notification and is not
modelled as a field. [SRC] src/init.cpp:96,326-332,1694-1703,2651-2655,
src/warnings.h:43, src/warnings.cpp:46-47, src/config.cpp:182-184
at 6504a3af. -/
structure SafeModeClient where
  disableSafeMode : Bool := false
  testSafeMode : Bool := false
  deriving DecidableEq, Repr

/-- P the lowest height safe mode still looks at: the active tip's height less
the maximum fork distance, floored at zero.
[SRC] src/safe_mode.cpp:117-127 at 6504a3af. -/
def minimumRelevantBlockHeight (cfg : NodeConfig) (tipHeight : Nat) : Nat :=
  tipHeight - cfg.safeModeMaxForkDistance

/-- P fork length: the fork's blocks from its base to its tip, at least the
setting. [SRC] src/safe_mode.cpp:72-79 at 6504a3af. -/
def forkLongEnough (cfg : NodeConfig) (forkTip forkBase : BlockIndex) : Bool :=
  decide (forkTip.height - forkBase.height + 1 ≥ cfg.safeModeMinForkLength)

/-- P fork distance: the active tip's height above the last common block
(the base's parent), at most the setting.
[SRC] src/safe_mode.cpp:81-88 at 6504a3af. -/
def forkCloseEnough (cfg : NodeConfig) (activeTip forkBase : BlockIndex) : Bool :=
  decide ((activeTip.height : Int) - ((forkBase.height : Int) - 1) ≤ cfg.safeModeMaxForkDistance)

/-- P the work a fork tip needs: the active tip's work moved by the setting's
count of blocks at the active tip's proof. A negative setting lowers the bar,
floored at zero; a positive one raises it. The count enters the 256-bit
product through the 32-bit overload.
[SRC] src/safe_mode.cpp:90-95, src/arith_uint256.h:160,232-234 at 6504a3af. -/
def forkMinimumWork (cfg : NodeConfig) (activeTip : BlockIndex) : Nat :=
  let difference := blockProof activeTip.header.bits *
    (cfg.safeModeMinPowDifference.natAbs % 2 ^ 32) % 2 ^ 256
  let tipWork := activeTip.work.toNat
  if cfg.safeModeMinPowDifference > 0 then (tipWork + difference) % 2 ^ 256
  else tipWork - min tipWork difference

/-- P fork work: the fork tip's accumulated work reaches the bar.
[SRC] src/safe_mode.cpp:97-100 at 6504a3af. -/
def forkHeavyEnough (cfg : NodeConfig) (activeTip forkTip : BlockIndex) : Bool :=
  decide (forkTip.work.toNat ≥ forkMinimumWork cfg activeTip)

/-- P `ShouldForkTriggerSafeMode`: a fork off the active chain that is long
enough, close enough and heavy enough triggers a level by its tip's status:
failed is `invalid`, transaction-valid with linked bodies is `valid`, else
(headers only) `unknown`.
[SRC] src/safe_mode.cpp:58-115, src/block_index.h:202-210 at 6504a3af. -/
def forkSafeModeLevel (cfg : NodeConfig) (active : List (BitVec 256))
    (activeTip forkTip forkBase : BlockIndex) : SafeModeLevel :=
  if active.contains forkTip.id then .none
  else if !forkLongEnough cfg forkTip forkBase then .none
  else if !forkCloseEnough cfg activeTip forkBase then .none
  else if !forkHeavyEnough cfg activeTip forkTip then .none
  else if forkTip.status.failed || forkTip.status.failedParent then .invalid
  else if forkTip.status.validity ≥ 3 && forkTip.chainTx > 0 then .valid
  else .unknown

/-- P `GetForkTips`: every index off the active chain that is not the parent
of another index off the active chain.
[SRC] src/validation.cpp:2379-2403 at 6504a3af. -/
def forkTips (tree : HeaderTree) (active : List (BitVec 256)) : List BlockIndex :=
  let off := tree.nodes.filter (fun i => !active.contains i.id)
  off.filter (fun i => !off.any (fun child => child.parent == some i.id))

/-- P `ExcludeIgnoredBlocks`: walk a fork from its tip to the active chain;
the lowest block flagged by `ignoresafemodeforblock` cuts the fork below
itself. `none` is no fork left (a block below the relevant height, or the
whole fork ignored). The flag lives on the index in the reference and is an
explicit list here. [SRC] src/safe_mode.cpp:227-268 and
src/rpc/safe_mode.cpp:12-51 at 6504a3af. -/
def excludeIgnoredBlocks (tree : HeaderTree) (cfg : NodeConfig) (active ignored : List (BitVec 256))
    (tipHeight : Nat) (forkTip : BlockIndex) : Option BlockIndex :=
  let path := (ancestry tree (tree.nodes.length + 1) (some forkTip.id)).getD []
  let fork := path.takeWhile (fun p => !active.contains p.id)
  if fork.any (fun p => p.height < minimumRelevantBlockHeight cfg tipHeight) then none
  else match (fork.filter (fun p => ignored.contains p.id)).getLast? with
    | none => some forkTip
    | some lowest =>
      match lowest.parent with
      | none => none
      | some parent => if active.contains parent then none else tree.get parent

/-- P `CreateForkData`'s new-fork walk with the stale-fork prune: the fork's
blocks from its tip down to its base (the block whose parent is active). No
fork when the tip is active, when it extends the active tip, when a block of
the walk is below the relevant height or has no parent, or when the last
common block is below the relevant height.
[SRC] src/safe_mode.cpp:129-179,207-225 at 6504a3af. -/
def forkElements (tree : HeaderTree) (cfg : NodeConfig) (active : List (BitVec 256))
    (tipHeight : Nat) (forkTip : BlockIndex) : Option (List BlockIndex) :=
  if active.contains forkTip.id || active.getLast? == forkTip.parent then none else
    let path := (ancestry tree (tree.nodes.length + 1) (some forkTip.id)).getD []
    let fork := path.takeWhile (fun p => !active.contains p.id)
    match fork.getLast? with
    | none => none
    | some base =>
      let relevant := minimumRelevantBlockHeight cfg tipHeight
      if fork.any (fun p => p.height < relevant) then none
      else match base.parent.bind tree.get with
        | none => none
        | some common => if active.contains common.id && common.height ≥ relevant then some fork else none

/-- P one fork of the safe-mode result: its tip, its base and its level. -/
structure SafeModeFork where
  tip : BitVec 256
  base : BitVec 256
  level : SafeModeLevel
  deriving DecidableEq, Repr

/-- P the safe-mode result recomputed from the whole tree, the reference's
path after a reorg or an unspecified change (`pindexNew == nullptr`, which the
two safe-mode RPCs and start-up take): every fork tip, cut by the ignore
flags, turned into a fork and judged. [D] 2026-10-14: scope. The reference
also updates a cached fork table one index at a time (:356-366); that cache is
not modelled, and its membership test returns early in pointer order
(:22-31), so a cut tip lying inside another recorded fork can be listed twice
there. The recomputation here keys the forks by tip, as the reference's
table does, and drops a cut tip that is already a block of another fork.
[SRC] src/safe_mode.cpp:14-56,270-302,324-405 at 6504a3af. -/
def safeModeForks (tree : HeaderTree) (cfg : NodeConfig) (active ignored : List (BitVec 256)) :
    List SafeModeFork :=
  match active.getLast?.bind tree.get with
  | none => []
  | some activeTip =>
    let cut := (forkTips tree active).filterMap
      (excludeIgnoredBlocks tree cfg active ignored activeTip.height)
    let tips := cut.foldl (fun (seen : List BlockIndex) tip =>
      if seen.any (fun other => other.id == tip.id) then seen else seen ++ [tip]) []
    let forks := tips.filterMap (fun tip =>
      (forkElements tree cfg active activeTip.height tip).map (fun elements => (tip, elements)))
    let forks := forks.filter (fun (tip, _) =>
      !forks.any (fun (other, elements) => other.id != tip.id && elements.any (fun p => p.id == tip.id)))
    forks.filterMap (fun (tip, elements) =>
      elements.getLast?.bind (fun base =>
        let level := forkSafeModeLevel cfg active activeTip tip base
        if level == .none then none else some (SafeModeFork.mk tip.id base.id level)))

/-- P the node's safe-mode level: the maximum over its triggering forks.
[SRC] src/safe_mode.cpp:290-301,434-436 at 6504a3af. -/
def safeModeLevel (tree : HeaderTree) (cfg : NodeConfig) (active ignored : List (BitVec 256)) :
    SafeModeLevel :=
  (safeModeForks tree cfg active ignored).foldl
    (fun level fork => if fork.level.rank > level.rank then fork.level else level) .none

/-- P `ignoresafemodeforblock`: flag one block of the index that is off the
active chain; it and its descendants then trigger nothing. The two refusals
are the RPC's own (code -32602, the reference's `RPC_INVALID_PARAMS`).
[SRC] src/rpc/safe_mode.cpp:12-51 at 6504a3af. -/
def ignoreSafeModeForBlock (tree : HeaderTree) (active ignored : List (BitVec 256))
    (hash : BitVec 256) : Except String (List (BitVec 256)) :=
  if (tree.get hash).isNone then .error "Unknown block!\n"
  else if active.contains hash then .error "Can not ignore a block on the main chain!\n"
  else .ok (if ignored.contains hash then ignored else hash :: ignored)

/-- P `reconsidersafemodeforblock`: clear the flag on the block and on every
ancestor of it down to the active chain.
[SRC] src/rpc/safe_mode.cpp:53-95 at 6504a3af. -/
def reconsiderSafeModeForBlock (tree : HeaderTree) (active ignored : List (BitVec 256))
    (hash : BitVec 256) : Except String (List (BitVec 256)) :=
  if (tree.get hash).isNone then .error "Unknown block!\n"
  else if active.contains hash then .error "Can not reconsider a block on the main chain!\n"
  else
    let path := (ancestry tree (tree.nodes.length + 1) (some hash)).getD []
    let cleared := (path.takeWhile (fun p => !active.contains p.id)).map (·.id)
    .ok (ignored.filter (fun h => !cleared.contains h))

/-- P the RPC warning string: forced by `-testsafemode`, replaced by the
level's sentence, with the start-up sentence appended during initial block
download. Empty means no warning.
[SRC] src/warnings.cpp:36-96 at 6504a3af. -/
def safeModeRpcWarning (client : SafeModeClient) (level : SafeModeLevel)
    (initialBlockDownload : Bool) : String :=
  let base := match level with
    | .valid => "Warning: The network does not appear to fully agree! Some miners appear to be experiencing issues. A large valid fork has been detected."
    | .invalid => "Warning: We do not appear to fully agree with our peers! You may need to upgrade, or other nodes may need to upgrade. A large invalid fork has been detected."
    | .unknown => "Warning: The network does not appear to agree with the local blockchain! Still waiting for block data for more details."
    | .none => if client.testSafeMode then "testsafemode enabled" else ""
  if initialBlockDownload && level != .none && base != "" then
    base ++ " We are in the startup process (e.g. Initial block download or reindex), this might be reason for disagreement."
  else base

/-- P the RPC effect of safe mode: a command registered as not safe is refused
with `RPC_FORBIDDEN_BY_SAFE_MODE` (-2) and the warning behind "Safe mode: ",
unless `-disablesafemode`. `none` is no refusal.
[SRC] src/init.cpp:324-333, src/rpc/protocol.h:37-38 at 6504a3af. -/
def safeModeRpcRefusal (client : SafeModeClient) (level : SafeModeLevel)
    (initialBlockDownload okSafeMode : Bool) : Option (Int × String) :=
  let warning := safeModeRpcWarning client level initialBlockDownload
  if warning != "" && !client.disableSafeMode && !okSafeMode then
    some (-2, "Safe mode: " ++ warning)
  else none

/-- P the source list of 24 `okSafeMode = false` entries for a wallet-enabled
build at the pin: three raw-transaction entries and twenty-one wallet entries.
`ENABLE_WALLET` guards the wallet registrars; all 21 wallet entries, including
`fundrawtransaction`, are absent from the wallet-less node of record. The list
is source data; measured unsafe-command coverage is only `sendrawtransaction`
in `docs/records/20261014-013925-s6-73-regtest-s3.md`.
[SRC] src/rpc/rawtransaction.cpp:2624-2626, src/wallet/rpcwallet.cpp:3514-3546
and src/init.cpp:3083-3087 at 6504a3af. -/
def safeModeRefusedCommands : List String :=
  ["sendrawtransaction", "sendrawtransactions", "signrawtransaction",
   "fundrawtransaction", "abandontransaction", "getbalance", "getreceivedbyaccount",
   "getreceivedbyaddress", "gettransaction", "getunconfirmedbalance", "getwalletinfo",
   "listaccounts", "listaddressgroupings", "listlockunspent", "listreceivedbyaccount",
   "listreceivedbyaddress", "listsinceblock", "listtransactions", "listunspent", "move",
   "rescanblockchain", "sendfrom", "sendmany", "sendtoaddress"]

end BsvChain
