# Teranode v0.16.0: the observation contract (#97; written 2026-10-14)

Issue numbers on this page are the archived tracker's ([docs/GLOSSARY.md](GLOSSARY.md), "archived #n").

[D] 2026-10-14 (the design for #97 under the maintainers' `wave 1 go` and `teranode now` of
2026-10-14 21:2xZ; docs/PLAN-2026-10-14-WAVES.md §2, wave 2's reads). This page is the contract the Teranode
runner of #66 and the status views of #67 read through: every rpc of the four gRPC services the status function reads
(`BlockchainAPI`, `PeerRegistryService`, `ValidatorAPI`, `PropagationAPI`: 100 rpcs; the seven other services at the
pin, 62 rpcs, are named in §1.6 with the two that observe a transition), every asset HTTP route and every Kafka topic
the node exposes at the pin, what each carries, and what transition of the machine (docs/DESIGN-S6.md §2) or what
clause of the status function (DESIGN-S6 §3) each observes. Every citation is read at Teranode `v0.16.0` =
`4edb60a40c6628ff0ef60231c2628efd7103fde5` (docs/PROVENANCE.md §1a) with `git show <commit>:<path>`, never a working
tree; the reference's ZMQ topics at bitcoin-sv `v1.2.3` = `6504a3aff65ba97c0f6c80962b033e35ecbfed4b` `[SRC]`.

**What this page measures.** Sections 1 to 5 run nothing: the observations are read from source `[SRC]` and the
mapping is design `[D]`. Section 6's interface is landed Rust (2026-10-15). Section 7's findings
were read from source; since 2026-10-15 each carries its witness run on the instance of #41 `[M]`, or says why it
has none (record docs/records/20261015-034125-s8-97-trait-witness-s4b.md). Teranode's defaults are the second oracle's settings, never the rule
(DESIGN-S6 §5.2); a policy row here is named policy.

## 0. The answer in one block

| question | answer at the pin |
|---|---|
| the tip | gRPC `GetBestBlockHeader` (`services/blockchain/Server.go:1679`), or `GET /api/v1/bestblockheader/json` (`services/asset/httpimpl/GetBestBlockHeader.go:82`); both read the store's best non-invalid header ordered by chain work, then `peer_id`, then store id (`stores/blockchain/sql/GetBestBlockHeader.go:134–135`; §7 F5) (through the store's response cache, `:94–107`) |
| a transaction's status | `GET /api/v1/txmeta/:hash/json` (`services/asset/httpimpl/GetTransactionMeta.go:94–238`): `blockIDs`, `blockHeights`, `mainChainIndex`; 404 for an unknown id. No surface exposes the UTXO record's `unminedSince`, `conflicting` or `locked` marks on the SQL store (§4, §7 F6) |
| the mempool's contents | none in the reference's sense (DESIGN-S6 §5.2). The RPC `getrawmempool` answers block assembly's transaction hashes (`services/rpc/handlers.go:1353–1392`), the nearest observation |
| a reject reason | synchronous only: the RPC `sendrawtransaction` error (code −25, text `TX rejected: ` and the error chain, `services/rpc/handlers.go:67`, `:925–931`) or the validator gRPC status with its error chain; afterwards the `rejectedtx` topic, which carries only the TX_INVALID class while the node is RUNNING (`services/validator/Validator.go:722–762`) |
| the orphan pool | ABSENT: a missing-parent submission is refused, never held; the validator's own comment defers an orphan pool (`services/validator/Validator.go:712–721`) |
| a stale branch | gRPC `GetChainTips` (`services/blockchain/Server.go:1747`) with `status` per tip, and `CheckBlockIsInCurrentChain` (`:1705`) per store id |
| Kafka on the instance of #41 | not readable from outside the process as configured: the instance runs the `test` settings context, whose Kafka scheme is the in-process `memory` broker (`settings.conf:57`; §3.2) |

## 1. The gRPC surface

### 1.1 `BlockchainAPI` (`services/blockchain/blockchain_api/blockchain_api.proto:20`), 68 rpcs

Every rpc of the service at the pin, in the proto's order. The request and response columns name the message's fields
as the proto declares them; `model.*` types are `model/model.proto` (`BlockInfo` `:55`, `SuitableBlock` `:67`,
`BlockStats` `:76`, `BlockDataPoints` `:94`, `ChainTip` `:99`, `NotificationType` `:36`). "WRITE" marks an rpc that
moves Teranode's state: the runner never calls one outside a scenario step that names it. The server type embeds
`UnimplementedBlockchainAPIServer` (`services/blockchain/Server.go:102`), so an rpc with no method of its exact name
answers `Unimplemented` (§7 F1).

| rpc | proto | server | request | response | observes (DESIGN-S6) | runner method (§6) |
|---|---|---|---|---|---|---|
| `HealthGRPC` | `services/blockchain/blockchain_api/blockchain_api.proto:22` | `services/blockchain/Server.go:364` | (empty) | `HealthResponse`: `ok`, `details`, `timestamp` | NO TRANSITION: liveness | none |
| `AddBlock` | `services/blockchain/blockchain_api/blockchain_api.proto:26` | `services/blockchain/Server.go:1104` | `header`, `subtree_hashes`, `coinbase_tx`, `transaction_count`, `size_in_bytes`, `external`, `peer_id`, `optionMinedSet`, `optionSubtreesSet`, `optionInvalid`, `optionID`, `coinbase_bump` | (empty) | WRITE: the commit of `acceptBlock` (§2.2; header and body stored, `invalid` set when `optionInvalid`); its effects are observed through `GetBlockHeader`, the `Block` notification and blocks-final (§3.1) | never called |
| `GetBlock` | `services/blockchain/blockchain_api/blockchain_api.proto:29` | `services/blockchain/Server.go:1256` | `hash` | `GetBlockResponse`: `header`, `height`, `coinbase_tx`, `transaction_count`, `subtree_hashes`, `size_in_bytes`, `id`, `coinbase_bump` | the header tree and a block body as subtree hashes (§1.3); evidence for §3 clauses 1 and 5 only through the subtrees (§4 row 3) | none (`block` by hash reads `GetBlockHeader`) |
| `GetBlocks` | `services/blockchain/blockchain_api/blockchain_api.proto:32` | `services/blockchain/Server.go:1297` | `hash`, `count` | `GetBlocksResponse`: `blocks` | the header tree walked from a hash (§1.3) | none |
| `GetBlockByHeight` | `services/blockchain/blockchain_api/blockchain_api.proto:35` | `services/blockchain/Server.go:1332` | `height` | `GetBlockResponse`: `header`, `height`, `coinbase_tx`, `transaction_count`, `subtree_hashes`, `size_in_bytes`, `id`, `coinbase_bump` | the active chain at a height (§1.3; `stores/blockchain/sql/GetBlockByHeight.go:14`) | `block` |
| `GetBlockByID` | `services/blockchain/blockchain_api/blockchain_api.proto:38` | `services/blockchain/Server.go:1368` | `id` | `GetBlockResponse`: `header`, `height`, `coinbase_tx`, `transaction_count`, `subtree_hashes`, `size_in_bytes`, `id`, `coinbase_bump` | the header tree by store id (§1.3); resolves `blockIDs` of the txmeta record | `block` |
| `GetNextBlockID` | `services/blockchain/blockchain_api/blockchain_api.proto:41` | `services/blockchain/Server.go:1404` | (empty) | `GetNextBlockIDResponse`: `next_block_id` | NO TRANSITION: store id allocation | none |
| `AssignBlockID` | `services/blockchain/blockchain_api/blockchain_api.proto:46` | `services/blockchain/Server.go:1422` | `block_hash` | `AssignBlockIDResponse`: `block_id` | NO TRANSITION (a write of a store id) | never called |
| `GetBlockStats` | `services/blockchain/blockchain_api/blockchain_api.proto:49` | `services/blockchain/Server.go:1443` | (empty) | `BlockStats`: `block_count`, `tx_count`, `max_height`, `avg_block_size`, `avg_tx_count_per_block`, `first_block_time`, `last_block_time`, `chain_work` | NO TRANSITION: aggregates | none |
| `GetBlockGraphData` | `services/blockchain/blockchain_api/blockchain_api.proto:52` | `services/blockchain/Server.go:1456` | `period_millis` | `BlockDataPoints`: `data_points` | NO TRANSITION: aggregates | none |
| `GetLastNBlocks` | `services/blockchain/blockchain_api/blockchain_api.proto:55` | `services/blockchain/Server.go:1469` | `numberOfBlocks`, `includeOrphans`, `fromHeight` | `GetLastNBlocksResponse`: `blocks` | the header tree, recent blocks with `orphaned` (§1.3) | none |
| `GetLastNInvalidBlocks` | `services/blockchain/blockchain_api/blockchain_api.proto:58` | `services/blockchain/Server.go:1487` | `n` | `GetLastNInvalidBlocksResponse`: `blocks` | the invalid marks: `acceptBlock`/`connectBlock` failures and `invalidateBlock` (§2.2, §2.4) | none |
| `GetSuitableBlock` | `services/blockchain/blockchain_api/blockchain_api.proto:61` | `services/blockchain/Server.go:1504` | `hash` | `GetSuitableBlockResponse`: `block` | NO TRANSITION: the difficulty helper's input | none |
| `GetHashOfAncestorBlock` | `services/blockchain/blockchain_api/blockchain_api.proto:64` | `services/blockchain/Server.go:1559` | `hash`, `depth` | `GetHashOfAncestorBlockResponse`: `hash` | the header tree (§1.3) | none |
| `GetLatestBlockHeaderFromBlockLocator` | `services/blockchain/blockchain_api/blockchain_api.proto:67` | none by this name; `services/blockchain/Server.go:1576` is `GetLatestBlockHeaderFromBlockLocatorRequest` | `bestBlockHash`, `blockLocatorHashes` | `GetBlockHeaderResponse`: `blockHeader`, `id`, `height`, `tx_count`, `size_in_bytes`, `miner`, `peer_id`, `block_time`, `timestamp`, `chain_work`, `mined_set`, `subtrees_set`, `invalid`, `processed_at`, `median_time_past` | the header tree (§1.3); **unimplemented over gRPC at the tag** (§7 finding F1) | none |
| `GetBlockHeadersFromOldest` | `services/blockchain/blockchain_api/blockchain_api.proto:70` | none by this name; `services/blockchain/Server.go:1616` is `GetBlockHeadersFromOldestRequest` | `chainTipHash`, `targetHash`, `numberOfHeaders` | `GetBlockHeadersResponse`: `blockHeaders`, `metas` | the header tree (§1.3); **unimplemented over gRPC at the tag** (§7 finding F1) | none |
| `GetNextWorkRequired` | `services/blockchain/blockchain_api/blockchain_api.proto:73` | `services/blockchain/Server.go:1522` | `previousBlockHash`, `currentBlockTime` | `GetNextWorkRequiredResponse`: `bits` | `receiveHeader`'s `nBits` rule (§2.2, the reference's `pow.cpp:95`), a parameter observation | none |
| `GetBlockExists` | `services/blockchain/blockchain_api/blockchain_api.proto:76` | `services/blockchain/Server.go:1656` | `hash` | `GetBlockExistsResponse`: `exists` | header-tree membership (§1.3) | none |
| `GetBlockHeaders` | `services/blockchain/blockchain_api/blockchain_api.proto:79` | `services/blockchain/Server.go:1807` | `startHash`, `numberOfHeaders` | `GetBlockHeadersResponse`: `blockHeaders`, `metas` | the header tree walked back from a hash (§1.3) | none |
| `GetBlockHeadersToCommonAncestor` | `services/blockchain/blockchain_api/blockchain_api.proto:82` | `services/blockchain/Server.go:1840` | `targetHash`, `blockLocatorHashes`, `maxHeaders` | `GetBlockHeadersResponse`: `blockHeaders`, `metas` | the header tree (§1.3), sync | none |
| `GetBlockHeadersFromCommonAncestor` | `services/blockchain/blockchain_api/blockchain_api.proto:85` | `services/blockchain/Server.go:3463` | `targetHash`, `blockLocatorHashes`, `maxHeaders` | `GetBlockHeadersResponse`: `blockHeaders`, `metas` | the header tree (§1.3), sync | none |
| `GetBlockHeadersFromTill` | `services/blockchain/blockchain_api/blockchain_api.proto:88` | `services/blockchain/Server.go:1885` | `startHash`, `endHash` | `GetBlockHeadersResponse`: `blockHeaders`, `metas` | the header tree (§1.3) | none |
| `GetBlockHeadersFromHeight` | `services/blockchain/blockchain_api/blockchain_api.proto:91` | `services/blockchain/Server.go:1924` | `startHeight`, `limit` | `GetBlockHeadersFromHeightResponse`: `blockHeaders`, `metas` | the header tree by height (§1.3) | none |
| `GetBlockHeadersByHeight` | `services/blockchain/blockchain_api/blockchain_api.proto:94` | `services/blockchain/Server.go:1953` | `startHeight`, `endHeight` | `GetBlockHeadersByHeightResponse`: `blockHeaders`, `metas` | the header tree by height (§1.3) | none |
| `GetMedianTimePastByHeights` | `services/blockchain/blockchain_api/blockchain_api.proto:98` | `services/blockchain/Server.go:1993` | `heights` | `GetMedianTimePastByHeightsResponse`: `median_time_past` | the median time past `receiveTx` row 3 and `acceptBlock` read (§2.1, §2.2) | `mtp` |
| `GetBlocksByHeight` | `services/blockchain/blockchain_api/blockchain_api.proto:101` | `services/blockchain/Server.go:2022` | `startHeight`, `endHeight` | `GetBlocksByHeightResponse`: `blocks` | the header tree by height (§1.3) | none |
| `FindBlocksContainingSubtree` | `services/blockchain/blockchain_api/blockchain_api.proto:104` | `services/blockchain/Server.go:2047` | `subtree_hash`, `max_blocks` | `FindBlocksContainingSubtreeResponse`: `blocks` | the header tree by subtree (§1.3); Teranode staging | none |
| `GetBlockHeaderIDs` | `services/blockchain/blockchain_api/blockchain_api.proto:107` | `services/blockchain/Server.go:2316` | `startHash`, `numberOfHeaders` | `GetBlockHeaderIDsResponse`: `ids` | the header tree (§1.3), store ids | none |
| `GetBestBlockHeader` | `services/blockchain/blockchain_api/blockchain_api.proto:110` | `services/blockchain/Server.go:1679` | (empty) | `GetBlockHeaderResponse`: `blockHeader`, `id`, `height`, `tx_count`, `size_in_bytes`, `miner`, `peer_id`, `block_time`, `timestamp`, `chain_work`, `mined_set`, `subtrees_set`, `invalid`, `processed_at`, `median_time_past` | **the tip**: the result of `activateBestChain` (§2.4), the last node of `s.headers.active`; the tie order differs from the reference's (§7 finding F5) | `tip` |
| `CheckBlockIsInCurrentChain` | `services/blockchain/blockchain_api/blockchain_api.proto:113` | `services/blockchain/Server.go:1705` | `blockIDs` | `CheckBlockIsCurrentChainResponse`: `isPartOfCurrentChain` | **active-chain membership** of store ids: separates §3 clause 1 (`minedActive`) from clause 5 (`onStaleBranch`) | `on_active` |
| `CheckBlockIsAncestorOfBlock` | `services/blockchain/blockchain_api/blockchain_api.proto:117` | `services/blockchain/Server.go:1724` | `blockIDs`, `blockHash` | `CheckBlockIsAncestorOfBlockResponse`: `isAncestor` | the header tree (§1.3) | none |
| `GetChainTips` | `services/blockchain/blockchain_api/blockchain_api.proto:120` | `services/blockchain/Server.go:1747` | (empty) | `GetChainTipsResponse`: `tips` | **the tips** with `status` (`active`, `valid-fork`, `valid-headers`, `headers-only`, `invalid`), the reference's `getchaintips` (§3 clause 5) | `chain_tips` |
| `GetBlockHeader` | `services/blockchain/blockchain_api/blockchain_api.proto:123` | `services/blockchain/Server.go:1765` | `blockHash` | `GetBlockHeaderResponse`: `blockHeader`, `id`, `height`, `tx_count`, `size_in_bytes`, `miner`, `peer_id`, `block_time`, `timestamp`, `chain_work`, `mined_set`, `subtrees_set`, `invalid`, `processed_at`, `median_time_past` | a node of the header tree with `invalid`, `mined_set`, `subtrees_set`, `chain_work` (§1.3) | `block` |
| `InvalidateBlock` | `services/blockchain/blockchain_api/blockchain_api.proto:126` | `services/blockchain/Server.go:2380` | `blockHash` | `InvalidateBlockResponse`: `invalidatedBlocks` | WRITE: `invalidateBlock` (§2.4); answers the invalidated hashes; emits `Block` and `BlockMinedUnset` notifications | scenario step only |
| `RevalidateBlock` | `services/blockchain/blockchain_api/blockchain_api.proto:129` | `services/blockchain/Server.go:2497` | `blockHash` | (empty) | WRITE: `reconsiderBlock` (§2.4) | scenario step only |
| `Subscribe` | `services/blockchain/blockchain_api/blockchain_api.proto:132` | `services/blockchain/Server.go:2115` | `source` | stream `Notification`: `type`, `hash`, `base_URL`, `metadata` | the notification stream (§1.2) | none |
| `SendNotification` | `services/blockchain/blockchain_api/blockchain_api.proto:135` | `services/blockchain/Server.go:2585` | `type`, `hash`, `base_URL`, `metadata` | (empty) | NO TRANSITION (a write into the stream) | never called |
| `GetSubscribers` | `services/blockchain/blockchain_api/blockchain_api.proto:138` | `services/blockchain/Server.go:2161` | (empty) | `GetSubscribersResponse`: `sources` | NO TRANSITION | none |
| `GetState` | `services/blockchain/blockchain_api/blockchain_api.proto:141` | `services/blockchain/Server.go:2207` | `key` | `StateResponse`: `data` | NO TRANSITION: a service key-value store | none |
| `SetState` | `services/blockchain/blockchain_api/blockchain_api.proto:144` | `services/blockchain/Server.go:2261` | `key`, `data` | (empty) | NO TRANSITION (a write) | never called |
| `GetBlockIsMined` | `services/blockchain/blockchain_api/blockchain_api.proto:147` | `services/blockchain/Server.go:2599` | `blockHash` | `GetBlockIsMinedResponse`: `isMined` | Teranode staging after `connectBlock`: the block's transactions marked mined in the UTXO store (`setTxMinedStatus`, DESIGN-S6 §5.2); gates when `blockIDs` of §4 row 2 are complete | none (`block` by hash carries `mined_set` from `GetBlockHeader`) |
| `SetBlockMinedSet` | `services/blockchain/blockchain_api/blockchain_api.proto:150` | `services/blockchain/Server.go:2620` | `blockHash` | (empty) | NO TRANSITION (staging write) | never called |
| `ClearBlockMinedSet` | `services/blockchain/blockchain_api/blockchain_api.proto:153` | `services/blockchain/Server.go:2639` | `blockHash` | (empty) | NO TRANSITION (staging write) | never called |
| `GetBlocksMinedNotSet` | `services/blockchain/blockchain_api/blockchain_api.proto:156` | `services/blockchain/Server.go:2651` | (empty) | `GetBlocksMinedNotSetResponse`: `blockBytes` | Teranode staging (as `GetBlockIsMined`) | none |
| `SetBlockSubtreesSet` | `services/blockchain/blockchain_api/blockchain_api.proto:159` | `services/blockchain/Server.go:2724` | `blockHash` | (empty) | NO TRANSITION (staging write) | never called |
| `GetBlocksSubtreesNotSet` | `services/blockchain/blockchain_api/blockchain_api.proto:162` | `services/blockchain/Server.go:2748` | (empty) | `GetBlocksSubtreesNotSetResponse`: `blockBytes` | NO TRANSITION: staging | none |
| `SetBlockProcessedAt` | `services/blockchain/blockchain_api/blockchain_api.proto:165` | `services/blockchain/Server.go:3512` | `block_hash`, `clear` | (empty) | NO TRANSITION (a write) | never called |
| `SetBlockPersistedAt` | `services/blockchain/blockchain_api/blockchain_api.proto:168` | `services/blockchain/Server.go:2678` | `block_hash` | (empty) | NO TRANSITION (a write) | never called |
| `GetBlocksNotPersisted` | `services/blockchain/blockchain_api/blockchain_api.proto:171` | `services/blockchain/Server.go:2697` | `limit` | `GetBlocksNotPersistedResponse`: `block_bytes` | NO TRANSITION: persistence | none |
| `SendFSMEvent` | `services/blockchain/blockchain_api/blockchain_api.proto:176` | `services/blockchain/Server.go:2904` | `event` | `GetFSMStateResponse`: `state` | NO TRANSITION: the service state machine (`fsm.go:17–43`), not the chain's | never called |
| `GetFSMCurrentState` | `services/blockchain/blockchain_api/blockchain_api.proto:179` | `services/blockchain/Server.go:2814` | (empty) | `GetFSMStateResponse`: `state` | NO TRANSITION; **a precondition**: the rejected-transaction topics are silent unless the state is RUNNING (§3) | `fsm` |
| `WaitUntilFSMTransitionFromIdleState` | `services/blockchain/blockchain_api/blockchain_api.proto:182` | `services/blockchain/Server.go:2851` | (empty) | (empty) | NO TRANSITION | none |
| `Run` | `services/blockchain/blockchain_api/blockchain_api.proto:185` | `services/blockchain/Server.go:3107` | (empty) | (empty) | NO TRANSITION (a write of the service state) | never called |
| `CatchUpBlocks` | `services/blockchain/blockchain_api/blockchain_api.proto:188` | `services/blockchain/Server.go:3113` | (empty) | (empty) | NO TRANSITION (a write of the service state) | never called |
| `Idle` | `services/blockchain/blockchain_api/blockchain_api.proto:191` | `services/blockchain/Server.go:3142` | (empty) | (empty) | NO TRANSITION (a write of the service state) | never called |
| `ReportPeerFailure` | `services/blockchain/blockchain_api/blockchain_api.proto:194` | `services/blockchain/Server.go:3118` | `hash`, `peer_id`, `failure_type`, `reason` | (empty) | NO TRANSITION: peers | none |
| `GetBlockLocator` | `services/blockchain/blockchain_api/blockchain_api.proto:199` | `services/blockchain/Server.go:3149` | `hash`, `height` | `GetBlockLocatorResponse`: `locator` | the header tree (§1.3), sync | none |
| `LocateBlockHeaders` | `services/blockchain/blockchain_api/blockchain_api.proto:202` | `services/blockchain/Server.go:3178` | `locator`, `hash_stop`, `max_hashes` | `LocateBlockHeadersResponse`: `block_headers` | the header tree (§1.3), sync | none |
| `GetBestHeightAndTime` | `services/blockchain/blockchain_api/blockchain_api.proto:205` | `services/blockchain/Server.go:3210` | (empty) | `GetBestHeightAndTimeResponse`: `height`, `time` | the tip's height and the median of its last 11 timestamps, the tip included (`services/blockchain/Server.go:3210`), the inputs of `receiveTx` row 3 | `tip` (its `tip_mtp`) |
| `ScheduleBlobDeletion` | `services/blockchain/blockchain_api/blockchain_api.proto:210` | `services/blockchain/Server.go:3545` | `blob_key`, `file_type`, `store_type`, `delete_at_height` | `ScheduleBlobDeletionResponse`: `deletion_id`, `scheduled`, `message` | NO TRANSITION: blob retention scheduling (storage) | never called |
| `CancelBlobDeletion` | `services/blockchain/blockchain_api/blockchain_api.proto:213` | `services/blockchain/Server.go:3588` | `blob_key`, `file_type`, `store_type`, `cancel_reason` | `CancelBlobDeletionResponse`: `cancelled`, `message` | NO TRANSITION: blob retention scheduling (storage) | never called |
| `ListScheduledDeletions` | `services/blockchain/blockchain_api/blockchain_api.proto:216` | `services/blockchain/Server.go:3621` | `min_height`, `max_height`, `store_type`, `limit`, `offset`, `filter_by_store` | `ListScheduledDeletionsResponse`: `deletions`, `total_count` | NO TRANSITION: blob retention scheduling (storage) | never called |
| `GetPendingBlobDeletions` | `services/blockchain/blockchain_api/blockchain_api.proto:219` | `services/blockchain/Server.go:3667` | `height`, `limit` | `GetPendingBlobDeletionsResponse`: `deletions` | NO TRANSITION: blob retention scheduling (storage) | never called |
| `RemoveBlobDeletion` | `services/blockchain/blockchain_api/blockchain_api.proto:222` | `services/blockchain/Server.go:3703` | `deletion_id` | (empty) | NO TRANSITION: blob retention scheduling (storage) | never called |
| `IncrementBlobDeletionRetry` | `services/blockchain/blockchain_api/blockchain_api.proto:225` | `services/blockchain/Server.go:3720` | `deletion_id`, `max_retries` | `IncrementBlobDeletionRetryResponse`: `should_remove`, `new_retry_count` | NO TRANSITION: blob retention scheduling (storage) | never called |
| `CompleteBlobDeletions` | `services/blockchain/blockchain_api/blockchain_api.proto:229` | `services/blockchain/Server.go:3740` | `completed_ids`, `failed_ids`, `max_retries` | `CompleteBlobDeletionsResponse`: `removed_count`, `retry_incremented_count` | NO TRANSITION: blob retention scheduling (storage) | never called |
| `AcquireBlobDeletionBatch` | `services/blockchain/blockchain_api/blockchain_api.proto:233` | `services/blockchain/Server.go:3762` | `height`, `limit`, `lock_timeout_seconds` | `AcquireBlobDeletionBatchResponse`: `batch_token`, `deletions` | NO TRANSITION: blob retention scheduling (storage) | never called |
| `CompleteBlobDeletionBatch` | `services/blockchain/blockchain_api/blockchain_api.proto:237` | `services/blockchain/Server.go:3828` | `batch_token`, `completed_ids`, `failed_ids`, `max_retries` | (empty) | NO TRANSITION: blob retention scheduling (storage) | never called |

### 1.2 The notification stream (`Subscribe`)

`Subscribe` (`services/blockchain/Server.go:2115`) streams `Notification` (`blockchain_api.proto:508`: `type`, `hash`,
`base_URL`, `metadata`) of the types `model/model.proto:36–46` names. The sends at the pin `[SRC]`:

| type | sent where | observes |
|---|---|---|
| `Block` | `AddBlock` after the store (`services/blockchain/Server.go:1189–1194`), whether or not the block is marked invalid; `InvalidateBlock` (`:2434–2439`); `RevalidateBlock` (`:2526–2531`) | a change of the header tree (§1.3 of DESIGN-S6): `acceptBlock`, `invalidateBlock`, `reconsiderBlock`. NOT a tip change: the hash is the stored or invalidated block, and the reader re-reads `GetBestBlockHeader` |
| `BlockMinedUnset` | `InvalidateBlock` (`:2444–2449`); block validation's catch-up (`services/blockvalidation/catchup.go:311`) | Teranode staging: the block's mined marks cleared (DESIGN-S6 §5.2, `SetBlockMinedSet`) |
| `Subtree` | block assembly (`services/blockassembly/Server.go:851`) | NO TRANSITION: Teranode's subtree staging |
| `BlockSubtreesSet` | `SetBlockSubtreesSet` (`services/blockchain/Server.go:2740`) | NO TRANSITION: staging |
| `BlockPersisted` | the block persister (`services/blockpersister/Server.go:402`) | NO TRANSITION: storage |
| `FSMState` | the service FSM (`services/blockchain/fsm.go:94`) | NO TRANSITION; the RUNNING precondition of §3 |
| `PeerFailure` | `ReportPeerFailure` (`services/blockchain/Server.go:3123`) | NO TRANSITION |
| `PING` | the keep-alive (`services/blockchain/Server.go:782`) | NO TRANSITION |
| `NotUsed` | none (`model/model.proto:40`, retired) | none |

### 1.3 `PeerRegistryService` (`blockchain_api.proto:680`), 24 rpcs

Hosted by the blockchain service (`services/blockchain/peer_registry_grpc.go`). Every rpc observes peers, never the
chain or a transaction: **NO TRANSITION** for all 24 (S7's and #98's surface, not this contract's).

| rpc | proto | server (`services/blockchain/peer_registry_grpc.go`) | request | response |
|---|---|---|---|---|
| `RegisterPeer` | `services/blockchain/blockchain_api/blockchain_api.proto:682` | `:19` | `peer` | (empty) |
| `UpdatePeerMetrics` | `services/blockchain/blockchain_api/blockchain_api.proto:685` | `:29` | `peer_id`, `height`, `bytes_sent_delta`, `bytes_received_delta`, `record_success`, `record_failure`, `record_malicious`, `response_time_ms` | (empty) |
| `RemovePeer` | `services/blockchain/blockchain_api/blockchain_api.proto:688` | `:44` | `peer_id` | (empty) |
| `ListPeers` | `services/blockchain/blockchain_api/blockchain_api.proto:691` | `:50` | `transport_filter`, `filter_transport`, `min_reputation`, `min_height`, `exclude_banned`, `sort_by_storage` | `ListPeersResponse`: `peers` |
| `GetPeer` | `services/blockchain/blockchain_api/blockchain_api.proto:694` | `:70` | `peer_id` | `GetPeerResponse`: `peer`, `not_found` |
| `AddBanScore` | `services/blockchain/blockchain_api/blockchain_api.proto:697` | `:79` | `peer_id`, `reason`, `points` | `AddBanScoreResponse`: `score`, `banned` |
| `IsPeerBanned` | `services/blockchain/blockchain_api/blockchain_api.proto:700` | `:85` | `peer_id` | `IsPeerBannedResponse`: `banned` |
| `ListBannedPeers` | `services/blockchain/blockchain_api/blockchain_api.proto:703` | `:90` | (empty) | `ListBannedPeersResponse`: `peer_ids` |
| `ClearBannedPeers` | `services/blockchain/blockchain_api/blockchain_api.proto:706` | `:95` | (empty) | (empty) |
| `UpdateConnectionState` | `services/blockchain/blockchain_api/blockchain_api.proto:709` | `:101` | `peer_id`, `connected` | (empty) |
| `UpdateLastMessageTime` | `services/blockchain/blockchain_api/blockchain_api.proto:712` | `:107` | `peer_id` | (empty) |
| `UpdateStorage` | `services/blockchain/blockchain_api/blockchain_api.proto:715` | `:113` | `peer_id`, `storage` | (empty) |
| `RecordSyncAttempt` | `services/blockchain/blockchain_api/blockchain_api.proto:718` | `:119` | `peer_id` | (empty) |
| `ClearAllSyncAttempts` | `services/blockchain/blockchain_api/blockchain_api.proto:721` | `:125` | (empty) | `ClearAllSyncAttemptsResponse`: `cleared` |
| `RecordBlockReceived` | `services/blockchain/blockchain_api/blockchain_api.proto:725` | `:131` | `peer_id`, `response_time_ms` | (empty) |
| `RecordSubtreeReceived` | `services/blockchain/blockchain_api/blockchain_api.proto:728` | `:137` | `peer_id`, `response_time_ms` | (empty) |
| `RecordTransactionReceived` | `services/blockchain/blockchain_api/blockchain_api.proto:731` | `:143` | `peer_id`, `response_time_ms` | (empty) |
| `RecordCatchupError` | `services/blockchain/blockchain_api/blockchain_api.proto:734` | `:149` | `peer_id`, `error_message` | (empty) |
| `RecordCatchupAttempt` | `services/blockchain/blockchain_api/blockchain_api.proto:738` | `:155` | `peer_id` | (empty) |
| `RecordCatchupSuccess` | `services/blockchain/blockchain_api/blockchain_api.proto:742` | `:161` | `peer_id`, `response_time_ms` | (empty) |
| `RecordCatchupFailure` | `services/blockchain/blockchain_api/blockchain_api.proto:745` | `:167` | `peer_id` | (empty) |
| `ResetReputation` | `services/blockchain/blockchain_api/blockchain_api.proto:749` | `:173` | `peer_id` | `ResetReputationResponse`: `reset` |
| `ReconsiderBadPeers` | `services/blockchain/blockchain_api/blockchain_api.proto:753` | `:179` | `cooldown_seconds` | `ReconsiderBadPeersResponse`: `reconsidered` |
| `RecordValidatedPeerProgress` | `services/blockchain/blockchain_api/blockchain_api.proto:756` | `:186` | `peer_id`, `height`, `block_hash`, `chain_work` | (empty) |

### 1.4 `ValidatorAPI` (`services/validator/validator_api/validator_api.proto:24`), 5 rpcs

| rpc | proto | server | request | response | observes |
|---|---|---|---|---|---|
| `HealthGRPC` | `services/validator/validator_api/validator_api.proto:27` | `services/validator/Server.go:332` | (empty) | `HealthResponse`: `ok`, `details`, `timestamp` | NO TRANSITION |
| `ValidateTransaction` | `services/validator/validator_api/validator_api.proto:31` | `services/validator/Server.go:606` | `transaction_data`, `block_height`, `skip_utxo_creation`, `add_tx_to_block_assembly`, `skip_policy_checks`, `create_conflicting`, `skip_txmeta_publishing`, `candidate_block_time`, `candidate_parent_median_time`, `in_block`, `unconfirmed_parents_at_candidate_height`, `skip_script_validation`, `outpoint_only_spend` | `ValidateTransactionResponse`: `valid`, `txid`, `reason`, `metadata` | WRITE: `receiveTx` (§2.1) and its synchronous verdict (§3 clause 7); `in_block` and the candidate fields select the block-context road |
| `ValidateTransactionBatch` | `services/validator/validator_api/validator_api.proto:35` | `services/validator/Server.go:779` | `transactions` | `ValidateTransactionBatchResponse`: `valid`, `errors`, `metadata` | WRITE: `receiveTx` per item |
| `GetBlockHeight` | `services/validator/validator_api/validator_api.proto:39` | `services/validator/Server.go:848` | (empty) | `GetBlockHeightResponse`: `height` | the validator's view of the tip height |
| `GetMedianBlockTime` | `services/validator/validator_api/validator_api.proto:43` | `services/validator/Server.go:882` | (empty) | `GetMedianBlockTimeResponse`: `median_time` | the validator's median time (the inputs of `receiveTx` row 3) |

`ValidateTransaction` is `receiveTx` (DESIGN-S6 §2.1) with Teranode's options; a rejection returns `valid: false`
with a gRPC error whose status carries the error chain (`services/validator/Server.go:606–609`, `:733–740`), and the
`reason` field (`validator_api.proto:91`) is never written by the server at the pin (§7 F3). `ValidateTransactionBatch`
always answers `valid: true` and one `errors.TError` per item (`validator_api.proto:104–105`). The validator's gRPC
listener is off unless configured (the instance of #41 serves it only under `instance.py start --validator`).

### 1.5 `PropagationAPI` (`services/propagation/propagation_api/propagation_api.proto`), 3 rpcs: the submission road

| rpc | proto | server | request | response | observes |
|---|---|---|---|---|---|
| `HealthGRPC` | `services/propagation/propagation_api/propagation_api.proto:23` | `services/propagation/Server.go:278` | (empty) | `HealthResponse`: `ok`, `details`, `timestamp` | NO TRANSITION |
| `ProcessTransaction` | `services/propagation/propagation_api/propagation_api.proto:28` | `services/propagation/Server.go:1155` | `tx` | (empty) | WRITE: `receiveTx` (§2.1) through propagation (DESIGN-S6 §5.2); the answer is empty or an error |
| `ProcessTransactionBatch` | `services/propagation/propagation_api/propagation_api.proto:33` | `services/propagation/Server.go:1200` | `items` | `ProcessTransactionBatchResponse`: `errors` | WRITE: `receiveTx` per item |

### 1.6 The seven other gRPC services, 62 rpcs

Every other service a proto at the pin declares (the test protos `errors/grpctest/test_service.proto` and
`test/utils/tstore/tstore.proto` aside). None is read by the status function; two observe a DESIGN-S6 transition and
have rows below; the rest are named by proto line only `[SRC]`.

| service | proto | rpcs | observes |
|---|---|---|---|
| `BlockAssemblyAPI` | `services/blockassembly/blockassembly_api/blockassembly_api.proto:22` (rpcs `:25` to `:112`) | 19 | the assembly set and mining; rows below |
| `BlockValidationAPI` | `services/blockvalidation/blockvalidation_api/blockvalidation_api.proto:12` (rpcs `:14` to `:19`) | 6 | `receiveBlock`; rows below |
| `SubtreeValidationAPI` | `services/subtreevalidation/subtreevalidation_api/subtreevalidation_api.proto:14` (rpcs `:17` to `:24`) | 3 | NO TRANSITION: Teranode's subtree staging |
| the p2p `PeerService` | `services/p2p/p2p_api/p2p_api.proto:322` (rpcs `:323` to `:364`) | 25 | NO TRANSITION: peers (S7, #98) |
| the legacy `PeerService` | `services/legacy/peer_api/peer_api.proto:131` (rpcs `:132` to `:138`) | 7 | NO TRANSITION: peers (S7, #98) |
| `AlertAPI` | `services/alert/alert_api/alert_api.proto:15` (`HealthGRPC` `:19`) | 1 | NO TRANSITION: liveness |
| `PrunerAPI` | `services/pruner/pruner_api/pruner_api.proto:10` (`HealthGRPC` `:11`) | 1 | NO TRANSITION: liveness |

| rpc | proto | server | request | response | observes (DESIGN-S6) |
|---|---|---|---|---|---|
| `ProcessBlock` | `services/blockvalidation/blockvalidation_api/blockvalidation_api.proto:16` | `services/blockvalidation/Server.go:1467` | `block`, `height`, `base_url`, `peer_id`, `block_id` (`blockvalidation_api.proto:41–47`) | (empty) | WRITE: `receiveBlock` (§2.2) through `processBlockFound` (`services/blockvalidation/Server.go:1521`) |
| `ValidateBlock` | `services/blockvalidation/blockvalidation_api/blockvalidation_api.proto:17` | `services/blockvalidation/Server.go:1541` | `block`, `height`, `is_revalidation` (`blockvalidation_api.proto:50–54`) | `ValidateBlockResponse`: `ok`, `message` (`:57–60`) | `receiveBlock`'s verdict on a block's bytes (§2.2; `block.Valid` at `services/blockvalidation/Server.go:1584`) |
| `BlockFound` | `services/blockvalidation/blockvalidation_api/blockvalidation_api.proto:15` | `services/blockvalidation/Server.go:1347` | `hash`, `base_url`, `wait_to_complete`, `peer_id` (`blockvalidation_api.proto:33–38`) | (empty) | WRITE: `receiveBlock` by announcement (the block fetched from `base_url`) |
| `GetBlockAssemblyTxs` | `services/blockassembly/blockassembly_api/blockassembly_api.proto:105` | `services/blockassembly/Server.go:2521` | (empty) | `GetBlockAssemblyTxsResponse`: `txCount`, `txs` (`blockassembly_api.proto:311–314`) | the assembly set: the subtree processor's `GetTransactionHashes` (`services/blockassembly/Server.go:2528`), the set the RPC `getrawmempool` reads (§2.1); the nearest observation of `s.mempool.accepted` (§4 row 2), "primarily for debugging" by the proto's own comment (`:104`) |
| `AddTx`, `RemoveTx` | `services/blockassembly/blockassembly_api/blockassembly_api.proto:29`, `:33` | `services/blockassembly/Server.go:1160`, `:1232` | `txid`, `fee`, `size`, `locktime`, `utxos`, `txInpoints` (`blockassembly_api.proto:132–139`); `txid` (`:227–229`) | `AddTxResponse`: `ok` (`:232–234`); (empty) | WRITE: the assembly set's entry and exit, Teranode staging after `receiveTx` (DESIGN-S6 §5.2); never called |
| `GetMiningCandidate`, `SubmitMiningSolution`, `GenerateBlocks` | `services/blockassembly/blockassembly_api/blockassembly_api.proto:46`, `:58`, `:92` | `services/blockassembly/Server.go:1611`, `:1672`, `:2604` | | | block assembly; WRITE for the latter two (a block is mined); the RPC's `getminingcandidate` and `generatetoaddress` (§2.1) are the harness's road to them |

## 2. The asset HTTP (`services/asset/httpimpl/`)

The routes as `services/asset/httpimpl/http.go` registers them at the pin. `apiPrefix` is the setting
`asset_apiPrefix`, `/api/v1` by default (`settings.conf:203`; `services/asset/httpimpl/http.go:323`); the listener is `ASSET_HTTP_PORT` 8090
(`settings.conf:90`). A `:hash/hex` and `:hash/json` sibling of a binary route returns the same object in that
encoding unless the row says otherwise. Every route is a read unless marked WRITE.

| route (under `apiPrefix` unless absolute) | registered | handler | response | observes (DESIGN-S6) |
|---|---|---|---|---|
| `/alive`, `/health` (absolute) | `services/asset/httpimpl/http.go:305`, `:309` | inline | text | NO TRANSITION |
| `/rest/block/:hash.bin` (absolute) | `services/asset/httpimpl/http.go:321` | `services/asset/httpimpl/GetLegacyBlock.go:121` | the block in the wire format | a block body (§1.3) |
| `/tx/:hash` (+ `/hex`, `/json`) | `services/asset/httpimpl/http.go:326–328` | `GetTransaction.go:133` | the transaction's bytes (repository `GetTransaction`, `services/asset/repository/repository.go:316`) | NO TRANSITION by itself: presence of the bytes says nothing of status |
| `POST /tx`, `POST /txs` | `services/asset/httpimpl/http.go:335–336` (only with the propagation proxy enabled) | `propagation_proxy.go:16` | the propagation service's answer | WRITE: `receiveTx` |
| `/txmeta/:hash/json` | `services/asset/httpimpl/http.go:340` | `GetTransactionMeta.go:94` | `tx`, `txAvailable`, `parentTxHashes`, `blockIDs`, `blockHashes`, `blockHeights`, `subtreeIdxs`, `subtreeHashes`, `mainChainIndex`, `fee`, `sizeInBytes`, `isCoinbase`, `lockTime` (`GetTransactionMeta.go:214–228`); 404 when absent (`:115–128`) | **§3 clauses 1, 5 and 8** (§4 row 1) |
| `/txmeta_raw/:hash` (+ `/hex`, `/json`) | `services/asset/httpimpl/http.go:342–344` | `GetTxMetaByTXID.go:102` | the Aerospike record's bins (`key`, `digest`, `namespace`, `set`, `node`, `bins`, `generation`, `:17–23`) | the UTXO record's raw marks, **Aerospike stores only** (`:118`; §7 F6) |
| `/subtree/:hash` (+ `/hex`, `/json`) | `services/asset/httpimpl/http.go:346–348` | `GetSubtree.go:109` | the subtree's transaction hashes | Teranode staging; a block body's members through its subtrees |
| `/subtree_data/:hash` | `services/asset/httpimpl/http.go:349` | `services/asset/httpimpl/GetSubtreeData.go:43` | the subtree's transactions | as above |
| `POST /subtree/:hash/txs` | `services/asset/httpimpl/http.go:350` | `GetTransactions.go:78` | the requested transactions | as above |
| `/subtree/:hash/txs/json` | `services/asset/httpimpl/http.go:352` | `GetSubtreeTxs.go:113` | per transaction `index`, `txid`, `inputsCount`, `outputsCount`, `size`, `fee` (`:21–26`) | **a block's members** for §3 clause 1's "block body contains `id`" |
| `/headers/:hash` (+ `/hex`, `/json`) | `services/asset/httpimpl/http.go:354–356` | `services/asset/httpimpl/GetBlockHeaders.go:112` | headers walked back from a hash | the header tree (§1.3) |
| `/headers_to_common_ancestor/:hash`, `/headers_from_common_ancestor/:hash` (+ `/hex`, `/json`) | `services/asset/httpimpl/http.go:364–366`, `:372–374` | `GetBlockHeadersToCommonAncestor.go:111`, `GetBlockHeadersFromCommonAncestor.go:108` | headers | the header tree, sync |
| `/header/:hash` (+ `/hex`, `/json`) | `services/asset/httpimpl/http.go:376–378` | `services/asset/httpimpl/GetBlockHeader.go:90` | `hash`, `version`, `previousblockhash`, `merkleroot`, `time`, `bits`, `nonce`, `height`, `txCount`, `sizeInBytes`, `miner`, `invalid`, `processed_at` (`block_header_response.go:64–108`) | a node of the header tree with its invalid mark |
| `/blocks`, `/block_locator` | `services/asset/httpimpl/http.go:380–381` | `services/asset/httpimpl/GetBlocks.go:102`, `GetBlockLocator.go:68` | blocks, a locator | the header tree |
| `/blocks/:hash` (+ `/hex`, `/json`) | `services/asset/httpimpl/http.go:383–385` | `GetNBlocks.go:111` | blocks from a hash | the header tree |
| `/block_legacy/:hash` | `services/asset/httpimpl/http.go:387` | `services/asset/httpimpl/GetLegacyBlock.go:49` | the block in the wire format (also a mining candidate by query) | a block body |
| `/block/:hash` (+ `/hex`, `/json`) | `services/asset/httpimpl/http.go:389–391` | `services/asset/httpimpl/GetBlock.go:291` | `model.Block` (`header`, `coinbase_tx`, `transaction_count`, `size_in_bytes`, `subtrees`, `height`, `id`, `coinbase_bump`; `model/Block.go:95–104`) and `nextblock` (`services/asset/httpimpl/GetBlock.go:39–42`) | a block, its body as subtree hashes |
| `/block/:hash/forks` | `services/asset/httpimpl/http.go:392` | `GetBlockForks.go:143` | a tree of `id`, `hash`, `miner`, `height`, `tx_count`, `size`, `block_time`, `timestamp`, `link`, `children` (`:46–55`) | **the tree around a block** (§3 clause 5) |
| `/block/:hash/nearestforks` | `services/asset/httpimpl/http.go:393` | `GetNearestForkHeights.go:39` | `current_height`, `prev_fork`, `next_fork` (`:22–24`) | the tree |
| `/block/height/:height` (+ `/hex`, `/json`) | `services/asset/httpimpl/http.go:395–397` | `services/asset/httpimpl/GetBlock.go:142` | as `/block/:hash` | the active chain at a height |
| `/block/:hash/subtrees/json` | `services/asset/httpimpl/http.go:399` | `GetBlockSubtrees.go:108` | per subtree `txCount`, `hash`, `index`, `fee`, `size` (`:19–23`) | a block body's subtrees |
| `/search` | `services/asset/httpimpl/http.go:401` | `Search.go:95` | `type`, `hash` (`:18–19`) | NO TRANSITION |
| `/blockstats`, `/blockgraphdata/:period`, `/chainparams` | `services/asset/httpimpl/http.go:402–404` | `services/asset/httpimpl/GetBlockStats.go:47`, `services/asset/httpimpl/GetBlockGraphData.go:138`, `GetChainParams.go:18` | aggregates; chain parameter names | NO TRANSITION |
| `/v1/policy` (absolute) | `services/asset/httpimpl/http.go:407` | `get_policy.go:38` | `maxscriptsizepolicy`, `maxtxsigopscountspolicy`, `maxtxsizepolicy`, `miningFee`, `standardFormatSupported` (`:23–27`) | NO TRANSITION; the policy parameters of `receiveTx` (§4.2 of DESIGN-S6), Teranode's settings, never the rule |
| `/lastblocks` | `services/asset/httpimpl/http.go:409` | `services/asset/httpimpl/GetLastNBlocks.go:96` | `model.BlockInfo` rows | the header tree with `orphaned` |
| `/utxo/:hash` (+ `/hex`, `/json`; query `vout`) | `services/asset/httpimpl/http.go:411–413` | `GetUTXO.go:84` | `status`, `spendingData`, `lockTime` (`stores/utxo/spendresponse.go:13–22`); `status` is `stores/utxo/status.proto:8–25` (OK, SPENT, IMMATURE, NOT_FOUND, ALREADY_EXISTS, FROZEN, CONFLICTING, LOCKED); 404 for NOT_FOUND | **the UTXO set** (§1.1): an outpoint's spend and its spender for §3 clause 6 |
| `/utxos/:hash/json` | `services/asset/httpimpl/http.go:415` | `GetUTXOsByTXID.go:124` | per output `txid`, `vout`, `lockingScript`, `satoshis`, `utxoHash`, `status`, `spendingData`, `lockTime` (`:26–50`) | the UTXO set for one transaction's outputs |
| `POST /utxos` (+ `/hex`, `/json`) | `services/asset/httpimpl/http.go:423–425` | `GetUTXOs.go:93` | per requested outpoint a spend response (`:219`) | the UTXO set, bulk |
| `/bestblockheader` (+ `/hex`, `/json`) | `services/asset/httpimpl/http.go:427–429` | `services/asset/httpimpl/GetBestBlockHeader.go:82` | the header; JSON as `/header` with `height`, `invalid` (`:98–106`) | **the tip** (§2.4) |
| `/merkle_proof/:hash` (+ `/hex`, `/json`) | `services/asset/httpimpl/http.go:431–433` | `GetMerkleProof.go:145` | `txid`, `blockHash`, `blockHeight`, `merkleRoot`, `subtreeIndex`, `txIndexInSubtree`, `subtreeRoot`, `subtreeProof`, `blockProof`, `completePath`, `flags` (`:23–33`) | inclusion of a transaction in a block (§3 clause 1 evidence) |
| `/api/p2p/peers`, `POST /api/p2p/reset-reputation`, `/api/catchup/status` (absolute; dashboard on) | `services/asset/httpimpl/http.go:450–454` | `get_peers.go`, `reset_reputation.go:27`, `get_catchup_status.go:12` | peers; catch-up | NO TRANSITION |
| `/fsm/state`, `/fsm/events`, `/fsm/states`; `POST /fsm/state` (auth) | `services/asset/httpimpl/http.go:492–499` | `fsm_handler.go:54`, `:66`, `:114`, `:158` | the service FSM | NO TRANSITION; the RUNNING precondition |
| `POST /block/invalidate`, `POST /block/revalidate` (auth) | `services/asset/httpimpl/http.go:519–520` | `block_handler.go:160`, `:195` | `blockHash` request (`:48`) | WRITE: `invalidateBlock`, `reconsiderBlock` (§2.4) |
| `/blocks/invalid` | `services/asset/httpimpl/http.go:523` | `block_handler.go:221` | recent invalid blocks | the invalid marks |
| `/catchup/status`, `/service/heights`, `/peers` | `services/asset/httpimpl/http.go:526–532` | `get_catchup_status.go:12`, `get_service_heights.go:14`, `get_peers.go` | per-service heights; peers | NO TRANSITION (`/service/heights` names how far each service has processed, a staging read) |
| `/settings`, `/settings/categories` (auth) | `services/asset/httpimpl/http.go:539–540` | `settings_handler.go:57`, `:141` | the node's settings, redacted | the parameters of the run (#59's census) |
| `/connection/websocket` (absolute; Centrifuge, off when `asset_centrifuge_disable`) | `services/asset/centrifuge_impl/centrifuge.go:551`, `:564` (through `services/asset/httpimpl/http.go:672–673`) | the Centrifuge node | the channels `block`, `subtree`, `node_status` (`centrifuge.go:241–242`, `:269`), each notification published by its type (`:525`) | NO TRANSITION by itself: a relay of the blockchain service's notifications (§1.2); off on the instance of #41 (`harness/engines/instance41/settings_local.conf:19`) |

The dashboard's catch-all handlers (`services/asset/httpimpl/http.go:472–476`, every method on `*` when the dashboard
is on) and the 404 catch-all (`:478`, when it is off) are not routes of the contract.

### 2.1 The RPC service the runner reads today (`services/rpc/`)

The node's JSON-RPC service listens on `TERANODE_RPC_PORT` 9292 (`settings.conf:138`); its methods are a reduced
bitcoind vocabulary (`services/rpc/Server.go:161–225`; 31 of the listed names answer `handleUnimplemented`, among them
`getmempoolinfo`, `gettxout` and `getblockcount`). Since #97 (2026-10-15) the runner reads the tip, the
tips, the blocks and active-chain membership over gRPC (§6), and calls these methods through the contract only:
`sendrawtransaction`, `getrawmempool`, `getminingcandidate`, `generatetoaddress`, `invalidateblock`, `reconsiderblock`,
`getblock`, `freeze` and `getchaintips` (the three for #66 cut 2's road, §6) and `getblockchaininfo` for readiness (`instance.py` too reads it at start, `harness/engines/instance41/instance.py:222`).
`getmininginfo` and `getblockbyheight` were its tip read before #97; the runner and
the scenario client no longer call them, and `harness/engines/instance41/seed_chunk.zsh:54` reads `getmininginfo`
through `instance.py rpc` for its console's tip line only, judging nothing; `getchaintips` is called by the scenario client as a fixture of #66 cut 2's road (`chain_tips_rpc`), never as a judging read. Their place in this contract:

| method | handler | observes | the reference's counterpart |
|---|---|---|---|
| `sendrawtransaction` | `services/rpc/handlers.go:830–935`: the validator's `Validate(ctx, tx, 0)` at `:925`; every refusal is `ErrRPCVerify` −25 (`services/rpc/bsvjson/jsonrpcerr.go:41`) with `TX rejected: ` and the error chain | `receiveTx` and its synchronous verdict (§3 clause 7) | `src/rpc/rawtransaction.cpp:1636–1650` (−26 for an invalid transaction, −25 for missing inputs and for any other failure, −27 already in chain; §7 F4) |
| `getmininginfo` | `services/rpc/handlers.go:2638` | the tip's height; the runner does not call it since #97 (the chunk driver's console line does, `seed_chunk.zsh:54`) | `getmininginfo` (`src/rpc/mining.cpp:962`) |
| `getblockbyheight` | `services/rpc/handlers.go:177` | the active chain at a height; not called since #97 | `getblockbyheight` (`src/rpc/blockchain.cpp:3799`) |
| `getminingcandidate`, `generatetoaddress` | `services/rpc/handlers.go:1104`, `:1031` | block assembly; WRITE (a block is mined) | `getminingcandidate` (`src/rpc/mining-fbb.cpp:385`), `generatetoaddress` (`src/rpc/mining.cpp:968`) |
| `getblockchaininfo` | `services/rpc/Server.go:174` (`handleGetblockchaininfo`) | NO TRANSITION: the instance's readiness (`chain` = regtest) | `getblockchaininfo` |
| `getrawmempool` | `services/rpc/handlers.go:1353–1392`: block assembly's `GetTransactionHashes`; the verbose form is one object with `size`, `fee`, `time`, `height`, `depends` | the nearest observation of `s.mempool.accepted` (§3 clause 2; §7 F7) | `rpc/blockchain.cpp:440` |
| `getchaintips` | `services/rpc/handlers.go:2928` | the tips (§3 clause 5); a 300-second cache when the RPC cache is on (`services/rpc/handlers.go:2963–2965`; `rpc_cache_enabled` defaults true, `settings/settings.go:773`, and the instance's settings do not set it): read only as #66 cut 2's fixture (`chain_tips_rpc`), never judging; the trait reads gRPC `GetChainTips` | `rpc/blockchain.cpp:2497` |
| `invalidateblock`, `reconsiderblock` | `services/rpc/handlers.go:1862`, `services/rpc/handlers.go:1919` | WRITE: a scenario step (§2.4 of DESIGN-S6); `reconsiderblock` revalidates and needs the block's subtree data, refetched from a peer when missing (§7 F5) | `invalidateblock`, `reconsiderblock` |
| `getblock` | `services/rpc/handlers.go:101–152` (`Server.go:172`) | a block by hash, read by #66 cut 2's road beside the trait: the verbose form's `chainwork`, and `confirmations` −1 off the active chain (`:127–149`); the trait's `block` reads gRPC (§1.1) | `getblock` (`src/rpc/blockchain.cpp:3798`) |
| `freeze` | `services/rpc/handlers.go:2708–2730` (`Server.go:223`): the UTXO store's `FreezeUTXOs` at `:2725` (`stores/utxo/Interface.go:520–522`; on the instance's SQL store `stores/utxo/sql/alert_system.go:54–103`, refusing a spent or already frozen output) | WRITE: a scenario step of #66 cut 2's road; answers `null` on success | none in the reference's RPC (the alert system's freeze has no bitcoind counterpart) |

## 3. The Kafka topics (`settings/settings.go:151–161`)

### 3.1 The ten topic settings

Each row: the setting at `settings/settings.go`, the default topic name and URL of `settings.conf`, the message of
`util/kafka/kafka_message/kafka_messages.proto`, the producer and consumers as the daemon wires them
(`daemon/daemon_services.go`, `daemon/daemon_kafka.go`), and the observation.

| setting | topic (default) | message and fields | producer (publish site) | consumers | observes (DESIGN-S6) |
|---|---|---|---|---|---|
| `kafka_validatortxsConfig` (`settings.go:151`) | `validatortxs` (`settings.conf:80`); the URL is empty by default and set only in the `operator` context (`settings.conf:850–852`), so propagation calls the validator client directly otherwise (`daemon/daemon_kafka.go:94–98`) | `KafkaTxValidationTopicMessage` (`kafka_messages.proto:33–44`): `tx`, `height`, `options` (`skipUtxoCreation`, `addTXToBlockAssembly`, `skipPolicyChecks`, `createConflicting`) | propagation (`daemon/daemon_services.go:1105`; `services/propagation/Server.go:1606`) | the validator (`daemon/daemon_services.go:999`; `services/validator/Server.go:418`) | NO TRANSITION: a `receiveTx` request in flight, not its verdict |
| `kafka_txmetaConfig` (`settings.go:152`) | `txmeta` (`settings.conf:74`, URL `:845`) | **not** the proto's `KafkaTxMetaTopicMessage` (`kafka_messages.proto:58–67`, unused by the producer): a batch in the wire format of `stores/txmetacache/wire.go:12–18` (v1: count, then per entry hash, action, length, content; v2 adds a magic, a version and an xxhash), the content the record's `MetaBytes` (`stores/utxo/meta/data.go:340`) | the validator, after the spend and the create succeed (`services/validator/Validator.go:1486–1497`, `sendTxMetaToKafka` `:1829`, `serializeTxMetaBatch` `:1912`, v2 `:1986`); also the local validator of any service (`daemon/daemon_stores.go:247`) | subtree validation (`daemon/daemon_services.go:855`); legacy netsync (`services/legacy/netsync/manager.go:3827`) | `receiveTx` → `accepted` (§2.1), and the same for a block's transactions (`InBlock` set, `:1492`); the ADD action only: no site at the pin publishes DELETE (§7 F8) |
| `kafka_legacyInvConfig` (`settings.go:153`) | `legacy-inv` (`settings.conf:34`, URL `:835`) | `KafkaInvTopicMessage` (`kafka_messages.proto:69–84`): `peerAddress`, `inv` (`type`, `hash`) | the legacy service, a peer's `inv` (`services/legacy/netsync/inv_msg.go:90`, `manager.go:3792–3814`) | the legacy service itself (`manager.go:3877`) | NO TRANSITION: a peer announcement (S7, #98) |
| `kafka_blocksFinalConfig` (`settings.go:154`) | `blocks-final` (`settings.conf:18`, URL `:829`) | `KafkaBlocksFinalTopicMessage` (`kafka_messages.proto:86–93`): `header`, `transaction_count`, `size_in_bytes`, `subtree_hashes`, `coinbase_tx`, `height` | the blockchain service's `AddBlock`, unless `optionInvalid` (`services/blockchain/Server.go:1183–1186`, send `:1199–1233`, key the hash) | legacy netsync (`services/legacy/netsync/manager.go:3818`, `:3922`) | the commit of `acceptBlock` (§2.2): a block stored valid-so-far, **not** a tip change and not `connectBlock`; a fork block is published too (§5 row 1) |
| `kafka_rejectedTxConfig` (`settings.go:155`) | `rejectedtx` (`settings.conf:47`, URL `:837`) | `KafkaRejectedTxTopicMessage` (`kafka_messages.proto:46–50`): `txHash`, `reason` (the error chain as text), `peer_id` (empty: an internal rejection) | the validator, when the error chain carries TX_INVALID, never for a missing parent, and only while the FSM is RUNNING (`services/validator/Validator.go:711–762`) | p2p (`daemon/daemon_services.go:344`; `services/p2p/Server.go:1300`) | `receiveTx` → `rejected` (§2.1; §3 clause 7), a lossy view: policy and consensus share the class (a script-path policy error is TX_INVALID wrapping TX_POLICY, `services/validator/ScriptVerifierGoBDK.go:379–383`, `:419–420`), the code is text only, nothing during catch-up (§7 F2) |
| `kafka_invalidBlocksConfig` (`settings.go:156`) | `invalid-blocks` (`settings.conf:26`, URL `:831`) | `KafkaInvalidBlockTopicMessage` (`kafka_messages.proto:13–18`): `blockHash`, `reason`, `peer_id`, `peer_url` | block validation (`services/blockvalidation/BlockValidation.go:615`; `kafkaNotifyBlockInvalid` `:3052–3090`) | p2p, optional (`daemon/daemon_kafka.go:195–202`; `services/p2p/server_helpers.go:879`) | `acceptBlock`/`connectBlock` → invalid (§2.2): a `BlockVerdict` of rejection |
| `kafka_invalidSubtreesConfig` (`settings.go:157`) | `invalid-subtrees` (`settings.conf:30`, URL `:833`) | `KafkaInvalidSubtreeTopicMessage` (`kafka_messages.proto:20–25`): `subtreeHash`, `peerUrl`, `reason`, `peer_id` | subtree validation (`services/subtreevalidation/Server.go:1001`, `:1050`) | p2p, optional (`daemon/daemon_kafka.go:204–211`; `services/p2p/Server.go:1271`) | NO TRANSITION: a subtree is Teranode staging, outside DESIGN-S6's state |
| `kafka_txPolicyRejectedConfig` (`settings.go:159`; the topic name `KAFKA_TX_POLICY_REJECTED` at `:158`, default `tx-policy-rejected`) | no line in `settings.conf` at the pin: the URL is empty and both ends are nil (`daemon/daemon_kafka.go:213–232`) | `KafkaTxPolicyRejectedTopicMessage` (`kafka_messages.proto:52–56`): `txHash`, `rawTx`, `reason` | the validator, for an error chain carrying TX_POLICY, only while RUNNING, skipped over `validator_kafka_maxMessageBytes`, dropped when the buffer is full (`services/validator/Validator.go:767–769`, `:779–835`) | subtree validation's cache (`daemon/daemon_services.go:866`; `services/subtreevalidation/policy_rejected_tx.go:146`) | `receiveTx` → `rejected` for policy (§2.1), best effort by its own comment (`:825–828`); absent by default (§7 F9) |
| `kafka_subtreesConfig` (`settings.go:160`) | `subtrees` (`settings.conf:59`, URL `:843`) | `KafkaSubtreeTopicMessage` (`kafka_messages.proto:27–31`): `hash`, `URL`, `peer_id` | p2p, a peer's subtree announcement (`daemon/daemon_services.go:370`; `services/p2p/server_helpers.go:338`) | subtree validation (`daemon/daemon_services.go:843`; `services/subtreevalidation/subtreeHandler.go:71`) | NO TRANSITION: a staging request |
| `kafka_blocksConfig` (`settings.go:161`) | `blocks` (`settings.conf:14`, URL `:827`) | `KafkaBlockTopicMessage` (`kafka_messages.proto:7–11`): `hash`, `URL`, `peer_id` | p2p, a peer's block announcement or catch-up (`daemon/daemon_services.go:380`; `services/p2p/server_helpers.go:184`, `services/p2p/sync_coordinator.go:1677`) | block validation (`daemon/daemon_services.go:916`; `services/blockvalidation/Server.go:900`) | NO TRANSITION: a `receiveBlock` request in flight, not its verdict |

The rows' policy content (rule 1): every topic is a node's transport, no topic is a rule; the gate on RUNNING, the
size skip and the drop when full are the node's settings and code paths, never consensus.

### 3.2 The topics on the instance of #41

The instance runs with `SETTINGS_CONTEXT=test` (`harness/engines/instance41/instance.py:192`), so the scheme is
`KAFKA_SCHEMA.test = memory` (`settings.conf:57`; the in-memory implementation, `util/kafka/kafka_producer.go:104`):
the producers and consumers above meet inside the one process, and no external reader can subscribe. The p2p and legacy
services are off on that instance (`harness/engines/instance41/instance.py:42–46`), so `blocks`, `subtrees`, `legacy-inv` have no producer and
`rejectedtx`, `invalid-blocks`, `invalid-subtrees`, `blocks-final` no consumer there; `validatortxs` and `tx-policy-rejected` are unset
in the `test` context. **A Kafka observation needs a broker** (`KAFKA_SCHEMA=kafka` and a broker on the loopback): a
settings change of the instance, recorded in its attestation (`harness/engines/instance41/road.py:21–49`), never a
silent one. Until then the runner reads no topic (§6), and the synchronous answers of §1 and §2 carry every observation
the status function needs except a rejection after the fact (§7 F2).

## 4. The status function (DESIGN-S6 §3) through the contract

| # | clause | Teranode's observation `[SRC]` | what it cannot say |
|---|---|---|---|
| 1 | `minedActive h` | `/txmeta/:hash/json`: `blockIDs`, `blockHeights`, and `mainChainIndex` ≥ 0 (`GetTransactionMeta.go:180–205`); confirm the block by `GetBlockByID` and `CheckBlockIsInCurrentChain`; the body's membership by `/subtree/:hash/txs/json` or `/merkle_proof/:hash` | `mainChainIndex` is the lowest index of an on-chain entry (the loop breaks at the match, `:202–203`), where DESIGN-S6 §3 chooses the greatest active height: the runner reads `blockHeights` and chooses (§7 F10); `blockIDs` complete only once the block's `mined_set` holds (`GetBlockIsMined`) |
| 2 | `inMempool` | none exact. `getrawmempool` (block assembly's hashes) is the nearest; a txmeta record with empty `blockIDs` says "known, unmined" but not "not conflicting" | the UTXO record's `unminedSince` and `conflicting` marks (`stores/utxo/fields/fields.go:40`, `:79`) are on no route of the SQL store (§7 F6) |
| 3 | `heldNonFinal` | ABSENT: no surface lists a held set | (#96's absence ledger) |
| 4 | `orphan` | ABSENT: a missing parent is refused (`TX_MISSING_PARENT`), never held (`services/validator/Validator.go:712–721`) | the reference's orphan witness of DESIGN-S6 §3 has no Teranode counterpart |
| 5 | `onStaleBranch` | txmeta `blockIDs` non-empty with `mainChainIndex` −1, confirmed per block by `CheckBlockIsInCurrentChain` (−1 alone is not evidence: a failed check also leaves −1, `GetTransactionMeta.go:195–199`, and on the production path the check reads `mainChainCache`, `:189–190`, not the chain); `GetChainTips` (`status` other than `active`), `/block/:hash/forks` | a body on a branch the store holds as `headers-only` lists no transactions; a block made invalid leaves the record (its ids gone from `blockIDs` within 14 ms on the instance, §7 F12), so the harness's journal of where it saw the transaction is the evidence |
| 6 | `conflictedByMinedSpend` | `/utxo/:hash?vout=n` or `/utxos/:hash/json` of the parent: `status` SPENT with `spendingData` naming a different spender, whose txmeta shows `minedActive` | the losing transaction's own `conflicting` mark is not on the txmeta route (§7 F6) |
| 7 | `rejected code reason` | the synchronous answer: RPC −25 with the chain, or the validator gRPC status; the innermost `NAME (n)` of the chain is the code (`errors/error.proto:17–109`); afterwards `rejectedtx` for the TX_INVALID class only | the reference's code namespace differs (§7 F4); no after-the-fact read on the instance (§3.2) |
| 8 | `unknown` | 404 from `/txmeta/:hash/json` (`GetTransactionMeta.go:115–128`) | as in the reference, absence at one read proves nothing globally |

## 5. The mapping onto the reference's ZMQ topics (bitcoin-sv v1.2.3, `src/zmq/`)

#84's event vocabulary (S7) is unwritten at this date, so each row maps onto the reference's ZMQ topics directly
(`src/zmq/zmqnotificationinterface.cpp:59–80` registers eleven: `pubhashblock`, `pubhashtx`, `pubrawblock`, `pubrawtx`,
`pubinvalidtx`, `pubdiscardedfrommempool`, `pubremovedfrommempoolblock`, `pubhashblock2`, `pubrawblock2`, `pubhashtx2`,
`pubrawtx2`; the message names at `src/zmq/zmqpublishnotifier.cpp:22–36`) `[SRC]`. #84's rows map onto this table by
the reference's topic when it lands.

| Teranode | the reference's ZMQ topic | relation |
|---|---|---|
| `blocks-final`; the `Block` notification | `hashblock`/`rawblock` fire on `UpdatedBlockTip`, never in initial download and never when nothing new connected (`zmqnotificationinterface.cpp:176–197`, the return at `:180`); `hashblock2`/`rawblock2` on every connected block, reorgs included (`BlockConnected2` `:314–342`) | PARTIAL: Teranode's fire on the store of a block (§3.1), a fork block included; the reference's fire on a tip move or a connection. The runner derives the tip move by reading `GetBestBlockHeader` after each |
| the asset service's Centrifuge channels `block`, `subtree`, `node_status` (`/connection/websocket`, §2) | `hashblock`/`rawblock`, as the row above | PARTIAL, as the `Block` notification it relays (§1.2): a store of a block, not a tip move; off on the instance of #41 |
| `txmeta` | `hashtx`/`rawtx` on mempool acceptance and on every transaction of a connected or disconnected block (`TransactionAddedToMempool` `:217–238`, from `BlockConnected` `:300–310` and `BlockDisconnected` `:345–352`); `hashtx2`/`rawtx2` on acceptance and a connected block's new transactions (`:279–298`, `:314–342`) | PARTIAL: the acceptance half maps; the payload is the txmeta record, not the raw transaction; no disconnect event |
| `rejectedtx`, `tx-policy-rejected` | `invalidtx` through the invalid-transaction sink (`src/invalid_txn_sinks/zmq_sink.cpp:19`; `zmqnotificationinterface.cpp:199–215`) | PARTIAL: Teranode's carry a reason string and are gated on RUNNING (§3.1) |
| `invalid-blocks` | none | ABSENT in the reference's ZMQ |
| none | `discardedfrommempool`: `expired`, `mempool-sizelimit-exceeded`, `collision-in-block-tx` with `collidedWith` (`zmqpublishnotifier.cpp:170–227`) | ABSENT in Teranode: no pool to expire or trim, and a conflict is a UTXO mark (§4 row 6) |
| none | `removedfrommempoolblock`: `reorg`, `included-in-block` (`zmqpublishnotifier.cpp:229–256`; `src/txmempool.cpp:867`) | ABSENT in Teranode; the inclusion is observed through txmeta's `blockIDs` |
| `validatortxs`, `subtrees`, `blocks`, `legacy-inv`, `invalid-subtrees` | none | ABSENT: Teranode's intake and staging queues |

## 6. The runner's typed interface for Teranode

[D] 2026-10-15: the trait is Rust, `harness/engines/teranode/contract.rs` (the library's
`teranode_contract`), and the runner reads Teranode only through it. Its methods are named after the observations
the SV-node column makes (the tip, the mempool contents, a transaction's status, a reject reason); each names the
surface of §1 to §3 it reads; nothing else is read. One implementation, `Instance41`, owns the three transports:
the JSON-RPC on 9292, the asset HTTP on 8090, and the gRPC through the native client
(`harness/engines/instance41/native/main.go`, a JSON-lines child that dials the validator on 8081 and the
blockchain service on 8087, `settings.conf:91`, `settings.conf:139`). Every call is journaled with its surface,
its request, the node's whole answer and its handler at the pin.

| method | surface | notes `[SRC]` |
|---|---|---|
| `submit(raw, road)` | RPC `sendrawtransaction` (§2.1), or the validator's `ValidateTransaction` (§1.4) for `ValidatorBlockContext { height, time, mtp }` | answers `Submitted { verdict, answer }`: the verdict `Ok(txid)` or a `Refusal { rpc_code, innermost, text }` (the RPC code kept apart from the node's innermost `NAME`, `errors/error.proto:17–109`), and the node's whole envelope as received |
| `tip()` | gRPC `GetBestBlockHeader` with `GetBestHeightAndTime` (§1.1) | `hash`, `height`, `chain_work`, `time`, the header's own `median_time_past` (the median of the 11 blocks before it, `stores/blockchain/sql/StoreBlock.go:739–740`, `stores/blockchain/sql/StoreBlock.go:1148–1160`) and `tip_mtp` (the median of the tip's last 11 timestamps, the tip included, `services/blockchain/Server.go:3210–3240`): the candidate's parent median time is `tip_mtp`, the value the RPC's `mediantime` gives (`services/rpc/handlers.go:1590–1622`) |
| `chain_tips()` | gRPC `GetChainTips` (§1.1) | the trait does not read the RPC `getchaintips`: it answers from a 300-second cache when the RPC cache is on (`services/rpc/handlers.go:2963–2965`); the scenario client's fixture reads it beside the trait (`chain_tips_rpc`, §6 below) |
| `on_active(ids)` | gRPC `CheckBlockIsInCurrentChain` (§1.1) | true when ANY of the ids is on the active chain (`stores/blockchain/sql/CheckBlockIsInCurrentChain.go:19–24`): the status reads one id at a time |
| `block(at)` | gRPC `GetBlockHeader` by hash, `GetBlockByHeight`, `GetBlockByID` (§1.1) | by hash: the store id, `invalid`, `mined_set`, no body; by height or id: the coinbase and the subtree hashes |
| `block_members(hash)` | `/block/:hash/subtrees/json`, then `/subtree/:hash/txs/json` (§2), paged by `offset` and `limit` 100 | the coinbase placeholder left out |
| `assembly_contents()` | RPC `getrawmempool` (§2.1) | block assembly's hashes, the coinbase placeholder left out; labeled the nearest "mempool contents", never the reference's mempool (§7 F7) |
| `tx_record(id)` | `/txmeta/:hash/json` (§2) | `blockIDs`, `blockHashes`, `blockHeights`, `mainChainIndex` and the node's body; None on 404 |
| `tx_bytes(id)` | `/tx/:hash/hex` (§2) | the standard serialization: the route serves `Tx.ExtendedBytes()` (`services/asset/repository/repository.go:326`), stripped of the marker and each input's previous satoshis and script (go-bt v2.7.1 `tx.go:583`, `input.go:333–357`), the bytes the RPC `getrawtransaction` answered (`services/rpc/handlers.go:603`) [D] 2026-10-15; presence says nothing of status |
| `outpoint(txid, vout)`, `outputs(txid)` | `/utxo/:hash/json?vout=n`, `/utxos/:hash/json` (§2) | `status` and the spender of `spendingData`; None on 404 |
| `status(id, journal)` | the reads above, §4's clauses in DESIGN-S6 §3's order | a default method of the trait; clauses 3 and 4 have no surface; `KnownUnmined` is clause 2's nearest |
| `fsm()` | gRPC `GetFSMCurrentState` (§1.1) | the RUNNING precondition |
| `mtp(heights)` | gRPC `GetMedianTimePastByHeights` (§1.1) | |
| `rejections()` | the `rejectedtx` topic (§3.1) | None on the instance of #41 as configured (§3.2) |

Beside the trait, never through it: the writes of a scenario step (`mine`, `candidate_count`, `invalidate`,
`reconsider`, `freeze`: RPC `generatetoaddress`, `getminingcandidate`, `invalidateblock`, `reconsiderblock`, `freeze`),
the scenario road's reads (`block_rpc`: RPC `getblock`; `chain_tips_rpc`: RPC `getchaintips`, its 300-second cache
named, a fixture that judges nothing), the instance's readiness (`chain`: `getblockchaininfo`'s `chain`, which must be
`regtest`), and the findings' witness reads of §7 (`witness_unimplemented`, `witness_asset`, `witness_verbose_pool`),
which judge nothing. [D] 2026-10-15: `getblock`, `freeze` and `chain_tips_rpc` were admitted for #66
cut 2's road (`getblock`: `harness/src/scenarios/branch.rs:451`; `freeze`: `harness/src/scenarios/road.rs:1811`;
`getchaintips`: `harness/src/scenarios/road.rs:828`, `harness/src/scenarios/teranode.rs:1205`), each journaled with its handler at the pin like every call.

The readers: `harness/src/bin/run_teranode.rs` (the corpus road of #41: every submission, tip, block and record
through the contract; `harness/engines/instance41/road.py` keeps the recipe's attestation and the disk headroom
and reads nothing of the node) and `harness/engines/teranode/client.rs` (the scenario client of #74, its names kept
over the contract: a method the contract lacks is refused by name). `grep -nE
'Rpc::new|rpc::Rpc|TcpStream|urllib'` over the three files finds no transport [M] 2026-10-15 (record
docs/records/20261015-034125-s8-97-trait-witness-s4b.md).

## 7. Mismatches, as findings (each read from source; its witness run, record docs/records/20261015-034125-s8-97-trait-witness-s4b.md)

| # | finding `[SRC]` | the witness |
|---|---|---|
| F1 | `GetLatestBlockHeaderFromBlockLocator` and `GetBlockHeadersFromOldest` are rpcs of the proto (`blockchain_api.proto:67`, `:70`) whose server methods carry a `Request` suffix (`services/blockchain/Server.go:1576`, `:1616`); the embedded unimplemented server answers `Unimplemented` for both names (`blockchain_api_grpc.pb.go:1154–1159`), while the remote client calls them (`services/blockchain/Client.go:643`, `:670`). In-process callers reach the store through `LocalClient` (`LocalClient.go:247–253`) | MEASURED [M] 2026-10-15: both rpcs over gRPC on 8087 answer `Unimplemented` ("method … not implemented") |
| F2 | `rejectedtx` is not a complete rejection log: it carries the TX_INVALID class only, never a missing parent, and nothing unless the FSM is RUNNING (`Validator.go:711–762`); `tx-policy-rejected` is unset by default and lossy by design (`:779–835`) | owed [X]: a scenario submitting a policy refusal and a consensus refusal with a broker configured, the topic read |
| F3 | `ValidateTransactionResponse.reason` (`validator_api.proto:91`) is never written by `ValidateTransaction` (`services/validator/Server.go:606–777`): the reason is the gRPC status; a reader of `reason` reads an empty string | MEASURED [M] 2026-10-15: an acceptance on the validator road answers `reason` ""; a refusal answers no response message, only the gRPC status `Internal` with the TError chain in its details |
| F4 | the RPC refusal code is −25 for every refusal (`services/rpc/handlers.go:925–931`; `jsonrpcerr.go:41`), where the reference answers −26 for a rejection and −25 for missing inputs and other failures (DESIGN-S6 §3 clause 7): `RejectCode.rpc` does not transfer between the columns | MEASURED [M] 2026-10-15 on both columns: the bytes `0200000000018403000000000000015100000000` answer −25 on Teranode (`UTXO_NON_FINAL (71)` … `TX_INVALID (31)`) and −26 "16: bad-txns-vin-empty" on the reference (docs/records/20261013-024612-s6-66-regtest-s3.json); a script refusal and a missing input answer −25 on Teranode too |
| F5 | the tip is the best non-invalid header by chain work, then `peer_id`, then store id (`stores/blockchain/sql/GetBestBlockHeader.go:134–135`); the reference breaks equal work by validation completion time, then sequence id (DESIGN-S6 §2.4). An equal-work race is non-judging until #93 rules | NOT REPRODUCIBLE on the instance by `invalidateblock` and `reconsiderblock` [M] 2026-10-15: `reconsiderblock` answered −25 `SERVICE_ERROR (59)`, revalidation refetches the block's subtree data from a peer and the instance runs none; the race needs a second block delivered at the same height (#66 cut 2's legacy road), owed [X] |
| F6 | the UTXO record's `conflicting`, `locked` and `unminedSince` marks (`stores/utxo/fields/fields.go:40`, `:44`, `:79`) appear on no asset route on the SQL store: `/txmeta/:hash/json` omits them (`GetTransactionMeta.go:214–228`) and `/txmeta_raw` reads Aerospike only (`GetTxMetaByTXID.go:111–130`) | MEASURED [M] 2026-10-15, sharper than read: on the instance's SQLite store the route gives no answer within 30 s (the node's log shows the handler creating an Aerospike client for an empty host, `util/aerospike.go:95`, with the base policy `sqlite:///utxostore`, `util/aerospike.go:308`; the log lines and sha256 in the record's section 3), and the node's stop then waited out the 60 s of SIGTERM in both witness runs (stamps 20261015-034125 and 20261015-033905; `instance.py:147–148`; the record's section 3) |
| F7 | `getrawmempool` answers block assembly's hashes, and its verbose form is one summary object, not the reference's per-transaction map (`services/rpc/handlers.go:1353–1392`) | MEASURED [M] 2026-10-15 on both columns: Teranode's `getrawmempool true` is one object (`depends` listing the placeholder and the txids, one `fee`, `size` 3); the reference's is a map keyed by txid (docs/records/20261013-075032-s6-66-mem3-regtest-s3.json) |
| F8 | the txmeta topic never carries DELETE: no site at the pin builds an item with `isDelete` true (the serializers' branches at `Validator.go:1936–1937` (v1) and `:2006–2007` (v2) are unreached, and the consumer's DELETE case (`services/subtreevalidation/txmetaHandler.go:227`) never fires); the proto's `KafkaTxMetaTopicMessage` is not the wire format | owed [X]: a reorg scenario with a broker, the topic read |
| F9 | `kafka_txPolicyRejectedConfig` has no line in `settings.conf` at the pin, so the policy-rejected topic is off by default (`daemon/daemon_kafka.go:213–220`) | MEASURED [M] 2026-10-15: `/api/v1/settings` (the tag's test credentials) answers `kafka_txPolicyRejectedConfig` "" current and default, `kafka_rejectedTxConfig` a `memory://` URL |
| F10 | `mainChainIndex` picks the lowest on-chain index (`GetTransactionMeta.go:183–205`), DESIGN-S6 §3 the greatest active height; for a repeated id the two differ | none on the private chain (a repeated id is historical); recorded as a reading difference |
| F11 | `mainChainIndex` is best effort: a failed main-chain check leaves −1 without an error (`GetTransactionMeta.go:195–199`, "Best-effort: tolerate transient blockchain client errors here"), so a transient error reads as a stale branch; with `mainChainCache` set the check reads the cache, not the chain (`:189–190`) | NOT REPRODUCIBLE [M] 2026-10-15: the services run in one process (the attestation's one `pid`, 59160, with `-blockchain=1` among its 12 service flags) and the recipe's surface stops none alone (`harness/engines/instance41/instance.py:241`, `choices=("start", "stop", "status", "rpc")`); the asset service wires `mainChainCache` whenever it has a blockchain client (`services/asset/httpimpl/http.go:283–285`) and drops it only on a failed start with a warning (`:600–607`): the run's log has no such warning and closes the `asset-mainchain-cache` subscription at stop (the record's section 3), so the six reads went through the cache; the cache half not observed in six reads around an invalidation (in the four with a block in `blockIDs`, `mainChainIndex` 0 matched `CheckBlockIsInCurrentChain` true per block; in the two after `invalidateblock`, `blockIDs` was empty and `mainChainIndex` −1, so there was nothing to check) |
| F12 | (measured on the instance, then read) an invalidated block leaves the transaction's txmeta record: after `invalidateblock A` the record of a transaction A held answered `blockIDs`, `blockHashes`, `blockHeights` empty and `mainChainIndex` −1 within 14 ms, while A's header, read after the failed `reconsiderblock`, has `mined_set` true and `invalid` true; §4 row 5 cannot read that branch from txmeta | MEASURED [M] 2026-10-15; consistent with the `BlockMinedUnset` notification `InvalidateBlock` sends (`services/blockchain/Server.go:2444–2449`, §1.2); the harness's own journal of the blocks it saw the transaction in (DESIGN-S6 §1.4) is the evidence for clause 5 |

## 8. The record of the reads

[M] 2026-10-14, from 21:22 UTC to 21:42 UTC (`date -u` at the read's start and at the index row), the Studio: `git -C $BSV_SPEC_TERANODE_CLONE show 4edb60a4:<path>` (the maintainers' clone) for every
Teranode citation; `git -C $BSV_SPEC_REFERENCE_CLONE show 6504a3af:<path>` (the maintainers' clone) for `src/zmq/` and the two reference sites; the
gRPC tables of §1.1 and §1.3 generated from the proto at the pin (rpc name, proto line, the message fields, the server
method's line), the observation column written by hand. No instance was started, no topic read, nothing broadcast.

The citations resolve at the pins under `tools/cite_check.py --list` (315 found on this page at the lens fixes: 310
`unanchored`, 5 `self`, 0 beyond-eof, 0 unresolved, 0 ambiguous) and none is anchored yet (`unanchored` is reported,
never RED, so no moved line on this page turns the leg RED); the sibling citations written as
a bare `:N` are outside the leg's shape. Anchoring is owed: a page-scoped `--propose` (the repository-wide `--write`
would rewrite 3,388 rows), each bare `:N` written with its path.

[M] 2026-10-15, from 03:24 UTC to 03:48 UTC, the box: the Teranode citations of §6, §2.1's new rows
and §7's witness column read with `git -C ~/bsv/targets/spec-teranode/src-v0.16.0 show 4edb60a4:<path>` (the
recipe's own tagged source clone, its HEAD the pin, read through `git show`, never its working tree; no fetch). The
instance of #41 was started twice by its recipe on fresh data directories, the witnesses run through the contract
and the instance stopped, under the box leg lock and a Lean slot; nothing broadcast (record
docs/records/20261015-034125-s8-97-trait-witness-s4b.md).
