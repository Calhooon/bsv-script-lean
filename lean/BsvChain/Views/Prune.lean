import BsvChain.Chain

/-!
# Pruning: which block files a node keeps, and what it can still serve (#82)

[M] 2026-10-15 (#82). NOTHING HERE IS CONSENSUS. Pruning is a node's storage
setting (`-prune`, default off, [SRC] src/init.cpp:2815-2838 at
6504a3aff65ba97c0f6c80962b033e35ecbfed4b): it decides which of the node's own block and
undo files stay on disk, never which blocks are valid. A pruned node validates exactly
as an unpruned one and keeps the whole block index and the UTXO set; it loses the bodies
and undo records of old blocks, and with them the answers that need those bytes. Every
definition below is a view of a node's own storage, never a rule; every parameter is a
node setting (policy in the spec's sense) or per-network data, named with its default
and its source.

**Sources.** bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b; every `[SRC]`
is a file and lines there. Blocks are appended to block files (`blk?????.dat`) in arrival
order; a file is left for the next one when the block would bring it to the preferred
size (src/blockfileinfostore.cpp:21-39,74-103); a block's undo record goes to the
`rev?????.dat` of the same number (src/blockfileinfostore.cpp:127-134). Pruning removes
WHOLE files, block and undo together (src/validation.cpp:6584-6628), and clears the
data, undo and disk-metadata bits of every index whose block lay in the file
(src/block_index.h:669-690). Two selections choose the files: the manual one behind the
`pruneblockchain` RPC (src/blockfileinfostore.cpp:177-208, called at
src/validation.cpp:3842) and the automatic one under a size target
(src/blockfileinfostore.cpp:230-300, called at src/validation.cpp:3845-3846). Neither ever
selects the file being written (the loops stop below `nLastBlockFile_`,
src/blockfileinfostore.cpp:196,266).

**What each request the harness reads answers for a retained and a pruned block** (§5,
`answer`; `[SRC]` at the pin; `[X]` the scenario `corpus/scenarios/2026-10-15-prune-retention.md`,
steps s8 to s10, measured on the node of record by its record). A pruned block keeps its
index entry, so every index-only read is unchanged; the UTXO set is never pruned.

| request | retained block | pruned block | `[SRC]` |
|---|---|---|---|
| `getblock <h> 0` | the raw block | a 200 reply already begun, then -1 `<hash> not found on disk` on the same connection (#85's Finding R2) | src/rpc/blockchain.cpp:1446-1474,1591-1620 |
| `getblock <h> 1` (2, 3) | the block | -1 `Block file <hash> not available.` | src/rpc/blockchain.cpp:1665-1678 |
| `getblockheader <h> true` | the header with `size`; status `data`, `undo` true | the header without `size`; status `data`, `undo`, `disk meta` false | src/rpc/blockchain.cpp:93-158 |
| `getblockheader <h> 2` | also the coinbase `tx` and its `merkleproof` | without `size`, `tx`, `merkleproof` | src/rpc/blockchain.cpp:177-201,1009-1040 |
| `getrawtransaction <tx> 1` (`-txindex`) | the transaction | -5 `No such mempool or blockchain transaction. If using -prune, the transaction may be in a pruned block. Use gettransaction for wallet transactions.` | src/validation.cpp:2178-2185, src/rpc/rawtransaction.cpp:196-205 |
| `getmerkleproof <tx> <h>`, `getmerkleproof2 <h> <tx>` | the proof | the proof while the block's merkle tree is held (memory cache or store), else -32603 `Can't read block from disk` | src/rpc/rawtransaction.cpp:2286-2300,2404-2444; src/merkletreestore.cpp:540-570 |
| `gettxout <tx> <n>` | the output while unspent | the same | src/rpc/blockchain.cpp:1923-2029 |
| `getblockhash`, `getchaintxstats` | from the index | the same | src/rpc/blockchain.cpp:801-828,3054-3155 |
| `verifymerkleproof <object>` | reads the object's own `target.merkleroot`, no block | the same (not measured) | src/rpc/rawtransaction.cpp:2527-2612 |
| `invalidateblock` whose disconnect reaches a pruned block | (disconnects with the undo) | held in the record under the discretion group until routed | src/validation.cpp:5230-5258 |
| `pruneblockchain <h>` | | §4 `pruneblockchain` | src/rpc/blockchain.cpp:1810-1875 |
| `getblockchaininfo` | `pruned` is the mode; `pruneheight` only in prune mode | §5 `pruneHeightFrom` | src/rpc/blockchain.cpp:2454,2467-2480 |

The proof surface is NOT limited to retained blocks: a tree computed before pruning (by any
call of `GetMerkleTree` before the file is gone: the proof RPCs
(src/rpc/rawtransaction.cpp:2295,2440), the extended header (src/rpc/blockchain.cpp:1032),
REST's extended headers (src/rest.cpp:284), a peer's `gethdrsen`
(src/net/net_processing.cpp:3199) and the Miner ID database
(src/miner_id/miner_id_db.cpp:786)) stays in the factory's memory
cache (`-maxmerkletreememcachesize`) and its on-disk store (`-maxmerkletreediskspace`,
pruned by its own rule, src/merkletreestore.cpp:128-200) after the block's file is gone.

**The second oracle** [SRC] Teranode v0.16.0 at 4edb60a40c6628ff0ef60231c2628efd7103fde5
(read only, no instance driven): retention is a delete-at-height on each stored item,
the block's height plus `global_blockHeightRetention` (288 by default, settings.conf:782,
settings/interface.go:93) and a per-service adjustment (settings/interface.go:100-120),
written on subtree files (services/blockvalidation/get_blocks.go:501,
services/legacy/netsync/handle_block.go:779,
services/subtreevalidation/SubtreeValidation.go:908) and UTXO records
(stores/utxo/aerospike/aerospike.go:689); `getblock` reads the block from the blockchain
store (services/rpc/handlers.go:101-117). No block-file layout and no `pruneblockchain`
selection exist there; nothing below models it.
-/

namespace BsvChain.Views.Prune

/-! ## 1. The settings and the network data (policy; never consensus) -/

/-- The per-network data the pruning selections read: a record per network, the
values below; the selections take the value as an argument. [SRC]
src/chainparams.cpp:1033,1195,1329,1456 (the four networks), the getter
src/chainparams.h:87 at 6504a3af. -/
structure PruneNetwork where
  /-- `nPruneAfterHeight`, read by the automatic selection
  (src/validation.cpp:3845-3846, src/blockfileinfostore.cpp:240) and by `pruneblockchain`
  (src/rpc/blockchain.cpp:1860). [SRC] src/chainparams.h:87 at 6504a3af. -/
  pruneAfterHeight : Nat
  deriving DecidableEq, Repr

/-- Mainnet's `nPruneAfterHeight`. [SRC] src/chainparams.cpp:1092 at 6504a3af. -/
def PruneNetwork.mainnet : PruneNetwork where
  pruneAfterHeight := 100000

/-- STN's `nPruneAfterHeight`. [SRC] src/chainparams.cpp:1252 at 6504a3af. -/
def PruneNetwork.stn : PruneNetwork where
  pruneAfterHeight := 1000

/-- Testnet's `nPruneAfterHeight`. [SRC] src/chainparams.cpp:1383 at 6504a3af. -/
def PruneNetwork.testnet : PruneNetwork where
  pruneAfterHeight := 1000

/-- Regtest's `nPruneAfterHeight`. [SRC] src/chainparams.cpp:1509 at 6504a3af. -/
def PruneNetwork.regtest : PruneNetwork where
  pruneAfterHeight := 1000

/-- One mebibyte. [SRC] the `-prune` argument is MiB (src/init.cpp:2820) at 6504a3af. -/
def mebibyte : Nat := 1048576

/-- `MIN_DISK_SPACE_FOR_BLOCK_FILES`, 550 MiB, the smallest automatic target.
[SRC] src/validation.h:305, read at src/init.cpp:2828 at 6504a3af. -/
def minDiskSpaceForBlockFiles : Nat := 550 * 1024 * 1024

/-- `BLOCKFILE_CHUNK_SIZE` and `UNDOFILE_CHUNK_SIZE`, the automatic selection's
allocation buffer. [SRC] src/block_file_access.h:25,27; used at
src/blockfileinfostore.cpp:255 at 6504a3af. -/
def blockFileChunkSize : Nat := 0x1000000
def undoFileChunkSize : Nat := 0x100000

/-- The largest `uint64_t`: the manual mode's target. [SRC] src/init.cpp:2825 at 6504a3af. -/
def maxUInt64 : Nat := 2 ^ 64 - 1

/-- The three readings of `-prune`: off, manual (`-prune=1`, the RPC only), automatic
with a target in bytes. [SRC] src/init.cpp:2815-2838 at 6504a3af. -/
inductive Mode where
  | off
  | manual
  | auto (target : Nat)
  deriving DecidableEq, Repr

/-- `nPruneTarget`: 0 when off, the largest `uint64_t` in manual mode, the target
otherwise. [SRC] src/validation.cpp:101, src/init.cpp:2820,2825 at 6504a3af. -/
def Mode.target : Mode → Nat
  | .off => 0
  | .manual => maxUInt64
  | .auto t => t

/-- `fPruneMode`. [SRC] src/validation.cpp:98, src/init.cpp:2826,2837 at 6504a3af. -/
def Mode.enabled : Mode → Bool
  | .off => false
  | _ => true

/-- The launch reading of `-prune=<n>`: a negative value and an automatic target below
550 MiB refuse to start the node, with these messages. [SRC] src/init.cpp:2815-2838 at
6504a3af. [D] the reference multiplies in `uint64_t`; arguments below 2^44 are modelled. -/
def modeOfArg (arg : Int) : Except String Mode :=
  if arg < 0 then .error "Prune cannot be configured with a negative value."
  else if arg = 0 then .ok .off
  else if arg = 1 then .ok .manual
  else if arg.toNat * mebibyte < minDiskSpaceForBlockFiles then
    .error "Prune configured below the minimum of 550 MiB.  Please use a higher number."
  else .ok (.auto (arg.toNat * mebibyte))

/-- The pruning settings: the mode, `-pruneminblockstokeep` (default 288, at least 6),
`-prunehysteresis` (default 25, 0 to 99) and `-preferredblockfilesize` (default 128 MiB).
[SRC] src/validation.h:99,272,274,280; src/config.cpp:34,100-101,1209-1244;
src/init.cpp:2473-2475,2841-2849 at 6504a3af. `minBlocksToKeep` is the same setting as
`BsvChain.NodeConfig.minBlocksToKeep` (docs/PARAMETERS.md §8.2). -/
structure Config where
  mode : Mode := .off
  minBlocksToKeep : Nat := 288
  hysteresis : Nat := 25
  preferredBlockFileSize : Nat := 0x8000000
  deriving DecidableEq, Repr

/-- The setters' bounds. [SRC] src/config.cpp:1209-1244 at 6504a3af. -/
def Config.valid (c : Config) : Bool := 6 ≤ c.minBlocksToKeep && c.hysteresis ≤ 99

/-! ## 2. The block files -/

/-- What the reference keeps per file: the block count, the highest height, the used
bytes of the block and undo files. [SRC] src/block_file_info.h:10-30 at 6504a3af. -/
structure FileInfo where
  blocks : Nat := 0
  heightLast : Nat := 0
  size : Nat := 0
  undoSize : Nat := 0
  deriving DecidableEq, Repr

/-- The record header written before each block: 8 bytes, 16 for a block of 2^32 - 1
bytes or more. [SRC] src/validation.cpp:2240-2250,6361-6368 at 6504a3af. -/
def recordHeaderSize (blockSize : Nat) : Nat :=
  if 2 ^ 32 - 1 ≤ blockSize then 16 else 8

/-- The node's block storage: the file table (`vinfoBlockFile`, `count` entries), the
file being written (`nLastBlockFile_`), every stored block as (height, file, has undo) in
arrival order, and the files removed so far. -/
structure Store where
  files : Nat → FileInfo := fun _ => {}
  count : Nat := 0
  last : Nat := 0
  placed : List (Nat × Nat × Bool) := []
  removed : List Nat := []

/-- `FindNextFileWithEnoughEmptySpace`: from file `n`, skip every non-empty file the
block would bring to the preferred size or past it (`>=`). [SRC]
src/blockfileinfostore.cpp:21-39 at 6504a3af. -/
def nextFile (preferred add : Nat) (files : Nat → FileInfo) : Nat → Nat → Nat
  | 0, n => n
  | fuel + 1, n =>
    if (files n).size != 0 && decide (preferred ≤ (files n).size + add) then
      nextFile preferred add files fuel (n + 1)
    else n

/-- Store one block of `blockSize` bytes at `height` (`FindBlockPos` with `AddNewBlock`),
and, when the block is connected, its undo record of `undoBytes` in the same file's
`rev` (`FindUndoPos`). The genesis block has no undo record (src/validation.cpp:3040-3046).
[SRC] src/blockfileinfostore.cpp:74-103,127-134; src/block_file_info.cpp:19-44;
src/validation.cpp:6361-6368 at 6504a3af. -/
def Store.addBlock (c : Config) (s : Store) (height blockSize undoBytes : Nat) (undo : Bool) :
    Store :=
  let add := blockSize + recordHeaderSize blockSize
  let n := nextFile c.preferredBlockFileSize add s.files (s.count + 1) s.last
  let f := s.files n
  let f' : FileInfo := { blocks := f.blocks + 1, heightLast := max f.heightLast height,
                         size := f.size + add, undoSize := f.undoSize + undoBytes }
  { s with files := fun m => if m = n then f' else s.files m,
           count := max s.count (n + 1), last := n,
           placed := s.placed ++ [(height, n, undo)] }

/-- `CalculateCurrentUsage`: block plus undo bytes over every file. [SRC]
src/blockfileinfostore.cpp:156-163 at 6504a3af. -/
def Store.usage (s : Store) : Nat :=
  (List.range s.count).foldl (fun a n => a + (s.files n).size + (s.files n).undoSize) 0

/-- `UnlinkPrunedFiles` and `PruneOneBlockFile`: each chosen file's info is cleared
(`ClearFileInfo`) and the file is recorded as removed. [SRC]
src/validation.cpp:6584-6628, src/blockfileinfostore.cpp:165-169 at 6504a3af. [D] a
removal the filesystem refuses is skipped by the reference (:6612-6626); not modelled. -/
def Store.unlink (s : Store) (set : List Nat) : Store :=
  { s with files := fun m => if set.contains m then {} else s.files m,
           removed := s.removed ++ set }

/-- The data bit of the `k`-th stored block: its file was never removed. [SRC]
src/block_index.h:669-690 at 6504a3af. -/
def Store.hasData (s : Store) (k : Nat) : Bool :=
  match s.placed[k]? with
  | none => false
  | some (_, n, _) => !s.removed.contains n

/-- The undo bit: written at connection, cleared with the data. [SRC]
src/block_index.h:669-690,1023-1029 at 6504a3af. -/
def Store.hasUndo (s : Store) (k : Nat) : Bool :=
  match s.placed[k]? with
  | none => false
  | some (_, n, u) => u && !s.removed.contains n

/-! ## 3. The two selections -/

/-- The manual selection's bound: the lesser of the requested height and the tip less
`minBlocksToKeep`, the request alone while the chain is shorter than that.
[SRC] src/blockfileinfostore.cpp:189-194 at 6504a3af. -/
def manualBound (c : Config) (tip h : Nat) : Nat :=
  if tip < c.minBlocksToKeep then h else min h (tip - c.minBlocksToKeep)

/-- `FindFilesToPruneManual`: every file below the one being written, non-empty, whose
highest block is at or below the bound. [SRC] src/blockfileinfostore.cpp:177-208 at
6504a3af. -/
def manualSet (c : Config) (s : Store) (tip h : Nat) : List Nat :=
  (List.range s.last).filter fun n =>
    (s.files n).size != 0 && decide ((s.files n).heightLast ≤ manualBound c tip h)

/-- The automatic selection's bound: the lesser of the tip less `minBlocksToKeep` and the
height the coins database was last flushed at (crash recovery needs the blocks above it).
[SRC] src/blockfileinfostore.cpp:244-251, src/validation.cpp:3826-3836 at 6504a3af. -/
def autoBound (c : Config) (tip flushed : Nat) : Int :=
  min ((tip : Int) - c.minBlocksToKeep) flushed

/-- The stop threshold, the target less the hysteresis band. [SRC]
src/blockfileinfostore.cpp:261 at 6504a3af. [D] the reference computes it in `double`;
this is the exact floor, which can differ by one byte. -/
def stopThreshold (c : Config) (target : Nat) : Nat := target * (100 - c.hysteresis) / 100

/-- The automatic scan in file order: skip empty files, stop once usage is below the
threshold, skip files with a block above the bound, else take the file and subtract its
bytes. [SRC] src/blockfileinfostore.cpp:265-288 at 6504a3af. -/
def autoLoop (s : Store) (bound : Int) (stop : Nat) : List Nat → Nat → List Nat
  | [], _ => []
  | n :: ns, cur =>
    if (s.files n).size = 0 then autoLoop s bound stop ns cur
    else if cur < stop then []
    else if bound < ((s.files n).heightLast : Int) then autoLoop s bound stop ns cur
    else n :: autoLoop s bound stop ns (cur - ((s.files n).size + (s.files n).undoSize))

/-- `FindFilesToPrune`: nothing without a target or while the tip is at or below
`nPruneAfterHeight`; nothing while usage plus one chunk of each kind is below the target.
[SRC] src/blockfileinfostore.cpp:230-300 at 6504a3af. -/
def autoSet (c : Config) (s : Store) (pruneAfter tip flushed : Nat) : List Nat :=
  if c.mode.target = 0 || decide (tip ≤ pruneAfter) then []
  else if s.usage + blockFileChunkSize + undoFileChunkSize < c.mode.target then []
  else autoLoop s (autoBound c tip flushed) (stopThreshold c c.mode.target)
    (List.range s.last) s.usage

/-! ## 4. `pruneblockchain` -/

/-- The RPC's answer: the height it prunes to (a signed height; the reply is its
`uint64_t` cast, `asUInt64`) or the error code and message. `resolveTime` is
`FindEarliestAtLeast` over the active chain, for a parameter above 10^9 read as a time
less `TIMESTAMP_WINDOW` (7200 s). [SRC] src/rpc/blockchain.cpp:1810-1875,
src/block_index.h:39, src/rpc/protocol.h:36,46 at 6504a3af. -/
def pruneblockchain (c : Config) (pruneAfter tip : Nat) (param : Int)
    (resolveTime : Int → Option Nat := fun _ => none) : Except (Int × String) Int :=
  if !c.mode.enabled then .error (-1, "Cannot prune blocks because node is not in prune mode.")
  else if param < 0 then .error (-8, "Negative block height.")
  else
    let resolved : Except (Int × String) Int :=
      if 1000000000 < param then
        match resolveTime (param - 7200) with
        | some h => .ok (h : Int)
        | none => .error (-8, "Could not find block with at least the specified timestamp.")
      else .ok param
    match resolved with
    | .error e => .error e
    | .ok h =>
      if (tip : Int) < pruneAfter then .error (-1, "Blockchain is too short for pruning.")
      else if (tip : Int) < h then
        .error (-8, "Blockchain is shorter than the attempted prune height.")
      else if (tip : Int) - c.minBlocksToKeep < h then .ok ((tip : Int) - c.minBlocksToKeep)
      else .ok h

/-- The reply's `uint64_t(height)`. [SRC] src/rpc/blockchain.cpp:1874 at 6504a3af. -/
def asUInt64 (h : Int) : Nat := (h % (2 ^ 64 : Int)).toNat

/-- The RPC applied: `PruneBlockFilesManual(height)` runs the manual selection only for a
height above zero (src/validation.cpp:3840-3842,6631-6635), and in manual mode the
automatic one selects nothing (`automatic_manual_nil`). -/
def Store.pruneRpc (c : Config) (s : Store) (pruneAfter tip : Nat) (param : Int)
    (resolveTime : Int → Option Nat := fun _ => none) : Except (Int × String) Int × Store :=
  match pruneblockchain c pruneAfter tip param resolveTime with
  | .error e => (.error e, s)
  | .ok h => (.ok h, if 0 < h then s.unlink (manualSet c s tip h.toNat) else s)

/-! ## 5. What the node answers for a block -/

/-- `getblockchaininfo`'s `pruneheight` over the active chain's data bits: from the tip,
step back while the parent has its data, never past genesis. [SRC]
src/rpc/blockchain.cpp:2467-2480 at 6504a3af. -/
def pruneHeightFrom (data : Nat → Bool) : Nat → Nat
  | 0 => 0
  | h + 1 => if data h then pruneHeightFrom data h else h + 1

/-- The requests the harness reads, for one block (`getblock` at a verbosity; the
verbose and extended header; a transaction of the block through `-txindex`; the two
proof RPCs; an unspent output the block created; the index-only reads). -/
inductive Request where
  | getblock (verbosity : Nat)
  | getblockheader
  | getblockheaderExtended
  | getrawtransaction
  | getmerkleproof
  | getmerkleproof2
  | gettxout
  | getblockhash
  | getchaintxstats
  deriving DecidableEq, Repr

/-- The answer's shape: served, served without the named fields, refused with a code and
message, or (raw `getblock`) a 200 reply already begun and then the error (#85's Finding
R2, docs/records/20261015-035438-s7-85-rpc-contract-s4b.md). -/
inductive Answer where
  | served
  | servedWithout (fields : List String)
  | error (code : Int) (message : String)
  | headThenError (code : Int) (message : String)
  deriving DecidableEq, Repr

/-- What the node holds for a block: its data bit, and whether its merkle tree is in the
factory's memory cache or on-disk store (`treeHeld`). -/
structure Held where
  data : Bool
  treeHeld : Bool := false
  deriving DecidableEq, Repr

/-- The text of `getrawtransaction`'s refusal under `-txindex`. [SRC]
src/rpc/rawtransaction.cpp:196-205 at 6504a3af. -/
def noSuchTx : String :=
  "No such mempool or blockchain transaction. If using -prune, the transaction may be in a pruned block. Use gettransaction for wallet transactions."

/-- The answer for a block whose display hash is `hash`, a function of what the node holds.
[SRC] at 6504a3af: `getblock` raw src/rpc/blockchain.cpp:1446-1474,1591-1620 (the stream
opens only with the data bit, src/block_index.h:1043-1049, src/block_index.cpp:402-408);
`getblock` JSON :1665-1678 (src/block_index.cpp:295-303); the header without `size` when
the disk metadata is cleared :93-106, and its status bits :140-158; the extended header's
coinbase `tx` and `merkleproof` only when the block is read :1009-1040,177-201;
`getrawtransaction` through the index src/validation.cpp:2178-2185 and
src/rpc/rawtransaction.cpp:196-205; the proofs src/rpc/rawtransaction.cpp:2286-2300,
2404-2444 over src/merkletreestore.cpp:540-570 (the block index looked up without a read,
src/rpc/rawtransaction.cpp:265-281); `gettxout` reads the UTXO set
src/rpc/blockchain.cpp:1923-2029; `getblockhash` and `getchaintxstats` read the index
:801-828,3054-3155. -/
def answer (hash : String) (h : Held) : Request → Answer
  | .getblock 0 => if h.data then .served else .headThenError (-1) (hash ++ " not found on disk")
  | .getblock _ => if h.data then .served else .error (-1) ("Block file " ++ hash ++ " not available.")
  | .getblockheader => if h.data then .served else .servedWithout ["size"]
  | .getblockheaderExtended =>
    if h.data then .served else .servedWithout ["size", "tx", "merkleproof"]
  | .getrawtransaction => if h.data then .served else .error (-5) noSuchTx
  | .getmerkleproof =>
    if h.data || h.treeHeld then .served else .error (-32603) "Can't read block from disk"
  | .getmerkleproof2 =>
    if h.data || h.treeHeld then .served else .error (-32603) "Can't read block from disk"
  | .gettxout => .served
  | .getblockhash => .served
  | .getchaintxstats => .served

/-! ## 6. The undo data of #64: a pruned index has neither body nor undo -/

/-- One index whose block lay in a removed file: body and undo gone, the rest kept.
[SRC] src/block_index.h:669-690 at 6504a3af. -/
def pruneIndex (i : BlockIndex) : BlockIndex := { i with body := none, undo := none }

/-- `PruneOneBlockFile` on the spec's header tree: every index whose block lay in a
removed file (`gone`) loses its body and its undo record together; the index, its work
and its status otherwise stay. [SRC] src/validation.cpp:6584-6606,
src/block_index.h:669-690 at 6504a3af. -/
def pruneTree (tree : HeaderTree) (gone : BitVec 256 → Bool) : HeaderTree :=
  { tree with nodes := tree.nodes.map (fun i => if gone i.id = true then pruneIndex i else i) }

/-- The same on the chain state; the coins view and the active chain are untouched. -/
def pruneState (s : ChainState) (gone : BitVec 256 → Bool) : ChainState :=
  { s with tree := pruneTree s.tree gone }

/-! ## 7. The checks that run when the module builds -/

/-- A store of `n` blocks of `size` bytes from height `from`, each connected but the genesis. -/
def fill (c : Config) (s : Store) (start n size : Nat) : Store :=
  (List.range n).foldl (fun s k => s.addBlock c (start + k) size 0 (start + k != 0)) s

-- 4096-byte files hold 19 blocks of 197 + 8 bytes (a 20th would bring 3895 to 4100, past 4096).
#guard ((fill { mode := .manual, preferredBlockFileSize := 4096 } {} 0 1301 197).count) = 69
#guard ((fill { mode := .manual, preferredBlockFileSize := 4096 } {} 0 1301 197).files 0).heightLast = 18
-- The RPC: too short below 1000, allowed at 1000, the clamp, the negative clamp's cast.
#guard pruneblockchain { mode := .manual } 1000 999 500 = .error (-1, "Blockchain is too short for pruning.")
#guard pruneblockchain { mode := .manual } 1000 1000 500 = .ok 500
#guard pruneblockchain { mode := .manual } 1000 1300 1100 = .ok 1012
#guard pruneblockchain { mode := .manual, minBlocksToKeep := 2000 } 1000 1000 10 = .ok (-1000)
#guard asUInt64 (-1000) = 18446744073709550616
#guard pruneblockchain {} 1000 1300 10 = .error (-1, "Cannot prune blocks because node is not in prune mode.")
-- The launch reading.
#guard modeOfArg 549 = .error "Prune configured below the minimum of 550 MiB.  Please use a higher number."
#guard modeOfArg 550 = .ok (.auto (550 * 1048576))
-- Manual mode never selects automatically; an automatic target far above usage selects nothing.
#guard autoSet { mode := .manual } (fill { mode := .manual } {} 0 1301 197) 1000 1300 1300 = []
#guard autoSet { mode := .auto (550 * 1048576) } (fill {} {} 0 1301 197) 1000 1300 1300 = []

end BsvChain.Views.Prune
