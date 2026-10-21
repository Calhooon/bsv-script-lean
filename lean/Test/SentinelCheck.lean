import BsvChain

/-!
# The sentinel grid (#91)

[M] 2026-10-14 (#91). The word Teranode's GoBDK verifies an input under
(`BsvChain.Teranode.teranodeInputWord`, Teranode's defaults) against the reference's
(`referenceMempoolWord`, `referenceBlockWord`, bitcoin-sv's mainnet defaults), computed, over a grid of
heights two blocks either side of every boundary of `ChainParams.mainnet` that `BsvScript.Properties.Eras`
names (P2SH, BIP66, BIP65, CSV, UAHF, DAA, Genesis, Chronicle): every tip of the grid against every parent
(confirmed at a grid height, or unconfirmed), with and without the candidate-height option on the mempool
path; every block height of the grid against every parent on the block path with the option; the
refusal without it; and the two `int32` edges of the theorems. The theorems of `BsvChain.Teranode.Sentinel`
prove the general case; this grid is the executable check of the transcription at the boundaries, run when `chaincheck` builds (it imports this
module). The heights are [D] synthetic.
-/

namespace SentinelCheck

open BsvScript.Params BsvChain.Teranode

/-- The boundaries `BsvScript.Properties.Eras` names on mainnet. -/
def boundaries : List Nat :=
  let c := ChainParams.mainnet
  [c.p2shHeight, c.bip66Height, c.bip65Height, c.csvHeight, c.uahfHeight, c.daaHeight,
   c.genesisHeight, c.chronicleHeight]

/-- [D] Two heights either side of every boundary, and the boundary. -/
def heights : List Nat := boundaries.flatMap fun b => [b - 2, b - 1, b, b + 1, b + 2]

/-- [D] Every parent of the grid. -/
def parents : List ParentHeight := heights.map .confirmed ++ [.unconfirmed]

def mempoolRow (tip : Nat) (p : ParentHeight) (atCandidate : Bool) : Bool :=
  decide (teranodeInputWord NodeConfig.teranodeDefault (tip + 1) false atCandidate p.teranodeSlot
    = some (referenceMempoolWord NodeConfig.svMainnetDefault tip p))

def blockRow (b : Nat) (p : ParentHeight) : Bool :=
  decide (teranodeInputWord NodeConfig.teranodeDefault b true true p.teranodeSlot
    = some (referenceBlockWord NodeConfig.svMainnetDefault b p))

def refusalRow (b : Nat) : Bool :=
  decide (teranodeInputWord NodeConfig.teranodeDefault b true false ParentHeight.unconfirmed.teranodeSlot = none)

def mempoolRows : List Bool :=
  heights.flatMap fun tip => parents.flatMap fun p => [false, true].map (mempoolRow tip p)

def blockRows : List Bool := heights.flatMap fun b => parents.map (blockRow b)

def refusalRows : List Bool := heights.map refusalRow

-- The grid's size: 40 heights, 41 parents.
#guard heights.length = 40 ∧ parents.length = 41
-- The mempool path: 40 tips × 41 parents × 2 option settings, every word equal.
#guard mempoolRows.length = 3280 ∧ mempoolRows.all id
-- Block connection with the option: 40 heights × 41 parents, every word equal.
#guard blockRows.length = 1640 ∧ blockRows.all id
-- Block connection without the option: the unconfirmed parent refused at all 40 heights.
#guard refusalRows.length = 40 ∧ refusalRows.all id

-- The theorems' own `int32` edges: the tip whose candidate height is `int32Max` still agrees, and a candidate
-- height above it is refused by the conversion before GoBDK runs.
#guard mempoolRow (int32Max - 1) .unconfirmed false
#guard teranodeInputWord NodeConfig.teranodeDefault (int32Max + 1) false false ParentHeight.unconfirmed.teranodeSlot
  = none

-- The words of the grid do change across the boundaries (the check is not comparing constants): the
-- mempool word at the tips either side of Genesis and the block word either side of P2SH differ.
#guard referenceMempoolWord NodeConfig.svMainnetDefault (ChainParams.mainnet.genesisHeight - 2) .unconfirmed
  ≠ referenceMempoolWord NodeConfig.svMainnetDefault (ChainParams.mainnet.genesisHeight - 1) .unconfirmed
#guard referenceBlockWord NodeConfig.svMainnetDefault ChainParams.mainnet.p2shHeight .unconfirmed
  ≠ referenceBlockWord NodeConfig.svMainnetDefault (ChainParams.mainnet.p2shHeight + 1) .unconfirmed

end SentinelCheck
