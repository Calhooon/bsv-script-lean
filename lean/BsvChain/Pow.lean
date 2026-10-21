import BsvChain.Header
import BsvChain.Finality

/-!
# Proof of work and the difficulty rule (#63)

[SRC] bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.
`HeaderChain` is the ancestor projection for #64's HeaderTree to refine.
`none` means missing ancestry or a violated arithmetic/assertion precondition,
never a node rejection or permission to substitute the observed candidate bits.
The explicit configuration supplies the existing census median span.
-/

namespace BsvChain

/-- The ancestor fields read by the difficulty helpers.
[SRC] src/pow.cpp:22–92,177–244,256–297 at 6504a3af. -/
structure HeaderWork where
  time : Nat
  bits : BitVec 32
  chainWork : BitVec 256
  deriving DecidableEq, Repr, Inhabited

/-- Contiguous ancestors, newest to oldest, including the parent. The height
belongs to the head. #64 supplies valid linked ancestry and accumulated work;
bounded corpus windows may omit older ancestors explicitly.
[SRC] src/block_index.h:330–349 and src/pow.cpp:22–297 at 6504a3af. -/
structure HeaderChain where
  height : Nat
  ancestors : List HeaderWork
  deriving Repr

/-- Ancestor lookup by height, preserving absence.
[SRC] src/pow.cpp:34–35,72–73,283–285 at 6504a3af. -/
def HeaderChain.atHeight (c : HeaderChain) (height : Nat) : Option HeaderWork :=
  if height > c.height then none else c.ancestors[c.height - height]?

/-- Project times to #60's median, only when all required ancestors are present.
[SRC] src/block_index.h:720–737 and src/pow.cpp:72–76 at 6504a3af. -/
def HeaderChain.medianAt (c : HeaderChain) (cfg : NodeConfig) (height : Nat) : Option Nat :=
  let times := (c.ancestors.drop (c.height - height)).map (·.time)
  if height > c.height || times.length < min cfg.medianTimeSpan (height + 1) then none
  else some (medianTimePast times cfg.medianTimeSpan)

/-- Target validity precedes the inclusive hash bound.
[SRC] src/pow.cpp:150–171 at 6504a3af.
[LIT] https://protocol.bsvblockchain.org/specification/blocks#proof-of-work at v1.2.2. -/
def checkProofOfWork (params : ChainParams) (hash : BitVec 256) (bits : BitVec 32) : Bool :=
  let t := compactTarget bits
  !t.negative && !t.overflow && t.target != 0 && t.target ≤ params.powLimit && hash.toNat ≤ t.target

/-- Legacy periodic retarget, with signed time subtraction, factor-four clamp,
256-bit multiplication and then division. [SRC] src/pow.cpp:119–147 and
src/arith_uint256.cpp:68–91 at 6504a3af. Zero timespan is outside source parameters. -/
def calculateNextWorkRequired (params : ChainParams) (parent : HeaderWork)
    (startTime : Nat) : Option (BitVec 32) := do
  if params.powNoRetargeting then return parent.bits
  if params.powTargetTimespan = 0 then none else do
    let elapsed := max ((params.powTargetTimespan / 4 : Nat) : Int)
      (min ((parent.time : Int) - startTime) ((params.powTargetTimespan * 4 : Nat) : Int))
    let target := ((compactTarget parent.bits).target * elapsed.toNat % 2 ^ 256) / params.powTargetTimespan
    return targetCompact (min target params.powLimit)

/-- Testnet's backward scan stops at genesis, an interval boundary, or a
non-special target. [SRC] src/pow.cpp:53–61 at 6504a3af. -/
def lastNonSpecialBits (interval : Nat) (limit : BitVec 32) : Nat → List HeaderWork → Option (BitVec 32)
  | _, [] => none
  | height, p :: ps =>
    if height = 0 || height % interval = 0 || p.bits != limit then some p.bits
    else lastNonSpecialBits interval limit (height - 1) ps

/-- Full legacy/EDA path: periodic retarget precedes testnet's rule; the
six-block median difference uses a strict twelve-hour lower comparison.
There is no UAHF-height guard in this function at the pin.
[SRC] src/pow.cpp:22–92 at 6504a3af. -/
def getNextEDAWorkRequired (params : ChainParams) (cfg : NodeConfig)
    (chain : HeaderChain) (candidate : BlockHeader) : Option (BitVec 32) := do
  let p ← chain.ancestors.head?
  let interval := params.powTargetTimespan / params.powTargetSpacing
  if interval = 0 then none else do
    let height := chain.height + 1
    if height % interval = 0 then
      if height < interval then none else do
        let start ← chain.atHeight (height - interval)
        calculateNextWorkRequired params p start.time
    else
      let limit := targetCompact params.powLimit
      if params.powAllowMinDifficultyBlocks then
        if candidate.time.toNat > p.time + 2 * params.powTargetSpacing then some limit
        else lastNonSpecialBits interval limit chain.height chain.ancestors
      else if p.bits = limit then some limit
      else if chain.height < 6 then none
      else do
        let recent ← chain.medianAt cfg chain.height
        let older ← chain.medianAt cfg (chain.height - 6)
        if (recent : Int) - older < 12 * 3600 then return p.bits
        let target := (compactTarget p.bits).target
        return targetCompact (min ((target + target / 4) % 2 ^ 256) params.powLimit)

/-- The pin's three-comparator sorting network, preserving its tie choices.
Input order is newest, middle, oldest; the source initializes the array in
the opposite order. [SRC] src/pow.cpp:214–244 at 6504a3af. -/
def suitableBlock (newest middle oldest : HeaderWork) : HeaderWork :=
  let (a, c) := if oldest.time > newest.time then (newest, oldest) else (oldest, newest)
  let (_, b) := if a.time > middle.time then (middle, a) else (a, middle)
  let (b, _) := if b.time > c.time then (c, b) else (b, c)
  b

/-- Suitable ancestor, requiring the source's height assertion and two parents.
[SRC] src/pow.cpp:214–244 at 6504a3af. -/
def HeaderChain.suitableAt (c : HeaderChain) (height : Nat) : Option HeaderWork := do
  if height < 3 then none else do
    let newest ← c.atHeight height
    let middle ← c.atHeight (height - 1)
    let oldest ← c.atHeight (height - 2)
    return suitableBlock newest middle oldest

/-- Cash target, including unsigned work subtraction/multiplication and unary
negation modulo 2^256, then integer division. The time clamp is in [SRC]
72 to 288 spacings. Division by zero is non-judging, as the source cannot
return a target in that case. [SRC] src/pow.cpp:177–207 at 6504a3af. -/
def computeCashTarget (params : ChainParams) (older newer : HeaderWork) : Option Nat := do
  let work := (newer.chainWork - older.chainWork).toNat * params.powTargetSpacing % 2 ^ 256
  let elapsed := max ((72 * params.powTargetSpacing : Nat) : Int)
    (min ((newer.time : Int) - older.time) ((288 * params.powTargetSpacing : Nat) : Int))
  if elapsed ≤ 0 then none else do
    let work := work / elapsed.toNat
    if work = 0 then none else some ((2 ^ 256 - work) / work)

/-- Full DAA path: testnet exception, suitable endpoints separated by [SRC]
144 heights, target cap. [SRC] src/pow.cpp:256–297 at 6504a3af.
[LIT] https://protocol.bsvblockchain.org/specification/blocks#proof-of-work at v1.2.2. -/
def getNextCashWorkRequired (params : ChainParams) (chain : HeaderChain)
    (candidate : BlockHeader) : Option (BitVec 32) := do
  let p ← chain.ancestors.head?
  if params.powAllowMinDifficultyBlocks && candidate.time.toNat > p.time + 2 * params.powTargetSpacing then
    return targetCompact params.powLimit
  if chain.height < params.powTargetTimespan / params.powTargetSpacing || chain.height < 144 then none
  else do
    let newer ← chain.suitableAt chain.height
    let older ← chain.suitableAt (chain.height - 144)
    let target ← computeCashTarget params older newer
    return targetCompact (min target params.powLimit)

/-- Genesis, no-retargeting, then the parent-height DAA switch, otherwise EDA.
Regtest's no-retargeting precedes its zero DAA threshold.
[SRC] src/pow.cpp:95–117 at 6504a3af.
[LIT] https://protocol.bsvblockchain.org/specification/blocks#proof-of-work at v1.2.2. -/
def getNextWorkRequired (params : ChainParams) (cfg : NodeConfig)
    (previous : Option HeaderChain) (candidate : BlockHeader) : Option (BitVec 32) :=
  match previous with
  | none => some (targetCompact params.powLimit)
  | some chain => do
    let p ← chain.ancestors.head?
    if params.powNoRetargeting then return p.bits
    if chain.height ≥ params.daaHeight then getNextCashWorkRequired params chain candidate
    else getNextEDAWorkRequired params cfg chain candidate

end BsvChain
