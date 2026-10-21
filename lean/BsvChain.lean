import BsvChain.Properties.Merkle
import BsvChain.Teranode.Subtree
import BsvChain.Properties.Theorems
import BsvChain.Properties.Reachable
import BsvChain.Properties.TxCodec
import BsvChain.Views.Status
import BsvChain.Views.MerkleProof
import BsvChain.Views.Events
import BsvChain.Properties.MerkleProof
import BsvChain.Views.MinerId
import BsvChain.Properties.MinerId
import BsvChain.Properties.Chain
import BsvChain.Chain
import BsvChain.Properties.Mempool
import BsvChain.Mempool
import BsvChain.Persist
import BsvChain.Properties.Persist
import BsvChain.Params
import BsvChain.Finality
import BsvChain.Properties.Finality
import BsvChain.Coin
import BsvChain.Oracle
import BsvChain.Utxo
import BsvChain.Properties.Utxo
import BsvChain.Properties.Oracle
import BsvChain.Header
import BsvChain.Pow
import BsvChain.Merkle
import BsvChain.Block
import BsvChain.Properties.Block
import BsvChain.Eras
import BsvChain.Properties.Eras
import BsvChain.Rejects
import BsvChain.Properties.Rejects
import BsvChain.Depth
import BsvChain.Properties.Depth
import BsvChain.Frozen
import BsvChain.Properties.Frozen
import BsvChain.Teranode.Sentinel
import BsvChain.Teranode.Spend
-- #92 (2026-10-15): record lifetimes, Teranode's store marks against expiry and maturity.
import BsvChain.Teranode.Lifetimes
-- #93 (2026-10-15): Teranode's chain selection, longest-chain marking and invalidation.
import BsvChain.Teranode.Chain
-- #94 (2026-10-15): the alert service against the reference's frozen-TXO path.
import BsvChain.Teranode.Alert
-- #88 (2026-10-15): the refinement relation, Teranode's observable state onto the reference machine.
import BsvChain.Teranode.Refinement
-- #98 (2026-10-18): the legacy bridge onto the protocol machine of #78, the theorem half.
import BsvChain.Teranode.Bridge
-- #86 (2026-10-15): the client wire formats as views (EF, BUMP, BEEF, Atomic BEEF, TSC).
import BsvChain.Views.Wire.EF
import BsvChain.Views.Wire.AtomicBEEF
import BsvChain.Views.Wire.TSC
import BsvChain.Wire.P2P
import BsvChain.Properties.P2P
import BsvChain.Wire.Relay
import BsvChain.Properties.Relay
-- #79 (2026-10-15): compact blocks, the short id and the reconstruction.
import BsvChain.Wire.CompactBlocks
import BsvChain.Properties.CompactBlocks
import BsvChain.Wire.DoubleSpend
import BsvChain.Properties.DoubleSpend
import BsvChain.Views.Prune
import BsvChain.Properties.Prune

/-!
# BsvChain

The transaction state machine library, born at #59. `BsvChain.Params` extends
`BsvScript.Params`; subsequent S6 issues add the executable transitions.
The import direction and census are checked by the pins leg.
[M] 2026-10-14, #120: the kernel-checked stale run of #68 G2
(`BsvChain.Properties.StaleRun`) is not imported here. It is the Lake library
`StaleRunCheck`, so `lake build BsvChain` never reduces it; the axioms leg of
`tools/check.sh` builds it and `AxiomCheck.lean` imports and walks it.
-/

-- Kernel audit of the record template and its default instance (rule 7).
#print axioms BsvChain.NodeConfig.defaults
#print axioms BsvChain.instInhabitedNodeConfig

-- The network projection agrees with the existing interpreter mainnet data.
#guard BsvChain.ChainParams.mainnet.toScript? = some BsvScript.Params.ChainParams.mainnet
-- Absent STN assignments cannot silently become executable heights.
#guard BsvChain.ChainParams.stn.toScript? = none
