# Teranode's machine where it differs from the reference (#74)

Issue numbers on this page are the archived tracker's ([docs/GLOSSARY.md](GLOSSARY.md), "archived #n").

[M] 2026-10-14, under the maintainers' ruling of 2026-10-14 21:2xZ (`wave 1 go`, `teranode now`). Every `[SRC]` below is Teranode `v0.16.0` at `4edb60a40c6628ff0ef60231c2628efd7103fde5` (docs/PROVENANCE.md 1a), read on the box from the instance's own source tree (`~/bsv/targets/spec-teranode/src-v0.16.0`, re-cloned at the tag tonight for the rebuild, HEAD the pin, `git status` empty), file and line; the corrections (2026-10-14, after the lens) were read at the same commit in a shallow fetch of `https://github.com/bsv-blockchain/teranode.git` (2026-10-14T22:15:25Z, a public read, rule 10) and the reference's lines at `6504a3af`. The derived status is DESIGN-S6 section 3's `Status`; the observation contract it answers is DESIGN-S6 section 5.1's. **The second oracle's defaults are never the rule** (DESIGN-S6 section 5.2): where Teranode's setting differs from the reference's, the row is recorded, never judged against the rule.

The run behind sections 5 and 6 is [the column record](records/20261014-215508-s6-74-second-oracle-s4b.md); the instance's rebuild is in the same record.

## 0. The answer in one block

Teranode has no mempool in the reference's sense. A transaction it accepts is a record in the UTXO store with `unminedSince` set and a node in block assembly's subtrees; a mined one is the same record with block IDs, heights and subtree indexes; a transaction that loses a mined double spend is the same record with `conflicting` set. There is no non-final pool (a non-final transaction is rejected), no orphan pool outside the legacy P2P bridge, and no reject filter. Every refusal of a decodable transaction is -25 with the node's own error words in the message (malformed bytes are -22, `services/rpc/handlers.go:848,854-856`; the absurd-fee refusal is -25 without the `TX rejected:` prefix, `:913-916`). Of the eight values of `Status`, five have a Teranode reading that the runner implements (`unknown`, `inMempool`, `minedActive h`, `conflictedByMinedSpend`, `rejected`), `onStaleBranch` has a reading through the journal of blocks (the store forgets an invalidated block's inclusion: `[SRC]` only, `teranode.lua:584-606`; the run did not read the record's `blockHashes` after `invalidateblock`), `orphan` is not observable on this instance, and `heldNonFinal` has no function.

## 1. The transaction states, the services that move them, and the derived status

The store's fields: `stores/utxo/fields/fields.go:40` (`conflicting`), `:42` (`conflictingCs`), `:44` (`locked`), `:46` (`creating`), `:48` (`utxoSpendableIn`), `:50` (`spendingHeight`), `:58` (`spentUtxos`), `:64`, `:66`, `:68` (`blockIDs`, `blockHeights`, `subtreeIdxs`, parallel lists, one entry per block on any branch), `:72` (`deleteAtHeight`), `:74` (`createdAt`), `:79` (`unminedSince`, set means unmined; comment `:75-78`), `:83` (`preserveUntil`), `:85` (`deletedChildren`) [SRC]. The record read back: `stores/utxo/meta/data.go:32` (`BlockIDs` `:40`, `UnminedSince` `:64`, `Frozen` `:74`, `Conflicting` `:77`, `Locked` `:83`, `Creating` `:94`, `SpendingDatas` `:97`) [SRC]. The store's interface: `stores/utxo/Interface.go:368` (`Get` `:408`, `SpendAndCreate` `:454`, `Unspend` `:458`, `SetMinedMulti` `:469`, `GetUnminedTxIterator` `:475`, `QueryOldUnminedTransactions` `:491`, `FreezeUTXOs` `:522`, `ReAssignUTXO` `:532`, `SetConflicting` `:541`, `SetLocked` `:567`, `MarkTransactionsOnLongestChain` `:594`, `SetBlockHeight` `:604`) [SRC]. Per-output status: `stores/utxo/status.proto:8-25` (OK 0, SPENT 1, IMMATURE 2, NOT_FOUND 3, ALREADY_EXISTS 4, FROZEN 5, CONFLICTING 6, LOCKED 7) [SRC].

| Teranode state | defined `[SRC]` | entered by `[SRC]` | left by `[SRC]` | derived status `[D]` |
|---|---|---|---|---|
| no record | | a refusal; the shed of a full assembly queue unwound (`services/validator/Validator.go:1430`); pruning at `deleteAtHeight` | admission | `unknown` |
| unmined: `unminedSince` set, no block IDs, not conflicting | `fields.go:79`; stamped at create `stores/utxo/aerospike/create.go:919-921` | `validateInternal` (`services/validator/Validator.go:868`) through `spendAndCreateInUtxoStore` (`:1105`, defined `:2125`), then `sendToBlockAssembler` (`:1346`, defined `:2200`) | Lua `setMined` (`stores/utxo/aerospike/teranode.lua:558`, clears it at `:637-641`) | `inMempool` (the pool is the store's unmined set plus block assembly's subtrees, reloaded by `loadUnminedTransactions`, `services/blockassembly/BlockAssembler.go:3199`) |
| unmined and `locked` (the two-phase commit between create and the assembly hand-off) | `fields.go:44` | `Validator.go:2147-2150` | `twoPhaseCommitTransaction` `Validator.go:1621`; `teranode.lua:646-649`; `BlockAssembler.go:3594` | `inMempool` (transient: a child sees TX_LOCKED 37 and is retried, `Validator.go:669-673`) |
| `creating` (a multi-record write in progress) | `fields.go:46` | `create.go:1401-1411` | `create.go:1443`; `teranode.lua:653-655` | NO FUNCTION: an internal write, read as `unknown` |
| non-final | none | none | none | `heldNonFinal`: NO FUNCTION. `util.IsTransactionFinal` fails into `NewUtxoNonFinalError` (`Validator.go:978-979`; UTXO_NON_FINAL 71 wrapping TX_LOCK_TIME 35) and the transaction is refused; `util/lock_time.go:38-40` says such a transaction is to be rejected |
| mined in a block on the current chain | `fields.go:64-68`; `data.go:40` | `setTxMinedStatus` (`services/blockvalidation/BlockValidation.go:1410`; `CheckBlockIsInCurrentChain` `:1453`; `model.UpdateTxMinedStatus` `:1500`; `SetBlockMinedSet` `:1539`) into `SetMinedMulti` and Lua `setMined` (appends at `teranode.lua:607-630`) | a reorganization (`MarkTransactionsOnLongestChain(false)`, `services/blockassembly/subtreeprocessor/SubtreeProcessor.go:4573,4592`); an invalidation (`unsetMined`, `teranode.lua:584-606`) | `minedActive h`, `h` the height of the block hash whose block is on the current chain (the store keeps no "active" field: `getblock`'s confirmations decide, `services/rpc/handlers.go:127-142`) |
| mined only in blocks off the current chain | the same fields; `unminedSince` re-stamped (`Interface.go:590-594`) | a fork block's validation; a reorganization | the branch's return (`SubtreeProcessor.go:3979`, `reorgBlocks`) | `onStaleBranch`, unless block assembly holds it again (it re-adds the transactions of a moved-back block, `SubtreeProcessor.go:4720`), in which case `inMempool` stands above it in section 3's order; an invalidation removes the block's entry from the record (`teranode.lua:584-606` `[SRC]`; not read back by the run), so the reading needs the runner's journal of blocks |
| `conflicting`, the loser of a mined double spend | `fields.go:40`; `data.go:77` | `ProcessConflicting` step 1 (`stores/utxo/process_conflicting.go:117-135`; called at `SubtreeProcessor.go:5272` from `processConflictingTransactions` `:5199`) | `ReverseProcessConflicting` (`process_conflicting.go:458`, called at `SubtreeProcessor.go:4205`); `UnmarkConflictingRecursively` (`:836`) | `conflictedByMinedSpend` for the immediate loser (`process_conflicting.go:126-129`); the descendants marked by `MarkConflictingRecursively` (`:995`) have no reference value (the reference's predicate is per input) |
| `conflicting`, a block-carried double spend whose block is not current | the same | `Validator.go:1155-1220` under `CreateConflicting` (set only by block-context callers: `services/subtreevalidation/Server.go:905,961`; `check_block_subtrees.go:704,1286`; `services/legacy/netsync/handle_block.go:1473`) | `ProcessConflicting` step 4 when its block becomes current | `onStaleBranch` while its block is off the current chain |
| a frozen output | `data.go:74`; `status.proto:20` | `FreezeUTXOs` (`Interface.go:522`, the alert system) | `UnFreezeUTXOs` (`:525`) | NO FUNCTION as a transaction status: a spend of it is refused with UTXO_FROZEN 72 |
| refused | no stored state | an error out of `ValidateWithOptions` (`Validator.go:637`); the legacy bridge's `rejectedTxns` (`services/legacy/netsync/manager.go:518`, set `:1358`, cleared per accepted block `:2181`) | | `rejected code reason` with `RejectCode` outside both of the reference's namespaces: the RPC code is always -25 (section 4) |
| orphan (legacy P2P only) | `services/legacy/netsync/manager.go:487` (an expiring map, cap 100 and TTL 10 minutes, `settings/settings.go:719-720`) | `handleTxMsg` (`manager.go:1271`) on TX_MISSING_PARENT, TX_LOCKED or TX_CREATING, `:1335-1352` | the parent accepted: `processOrphanTransactions` `:1390-1440`; eviction with one last validation `:3676-3686` | `orphan` on the P2P path only; NOT OBSERVABLE (no RPC or asset route reads the map) and NO FUNCTION on the RPC and propagation paths, where nothing is kept: on RPC a missing parent is refused before validation by the absurd-fee parent read, `-25 TX rejected: PROCESSING (4): failed to decorate previous outputs` (`services/rpc/handlers.go:880-904`; `maxrawtxfee` default 10,000,000, `settings/settings.go:110`) [M] this run; TX_MISSING_PARENT 34 (`Validator.go:1657-1663`; the comment `:680-686`) is the validator's answer, reached when the ceiling is off |

The validator's path, in order (`Validator.go`): the height defaults to the tip plus one (`:898-900`), a coinbase is refused (`:905`), finality (`:976-983`, the comparison time the tip's MTP in policy mode, `:577-584`), the parents read (`:1002`, `:1635-1675`), the script and policy checks (`validateTransaction` `:2843` into `services/validator/TxValidator.go:132`, inputs `:143`, the engine `:229`), spend and create (`:1105`), an existing record answered as success with its metadata (`:1106-1141`), a double spend stored only under `CreateConflicting` (`:1155`, `:1169-1220`) and otherwise refused (`:1248`), the hand-off to assembly (`:1346`). The options and their defaults: `services/validator/options.go:16-228` (`SkipPolicyChecks` `:27`, `CreateConflicting` `:31`, `InBlock` `:50`, defaults `:222-228`) [SRC].

**#94's measured leg** (the hazard rung, 2026-10-17, on the box): the alert path was driven on a fresh regtest
instance beside the reference's frozen-TXO RPC path, one scenario each column: 8 rows, agree 3 (fund and confirm, a freeze
refuses a spend, an unfreeze admits a spend), differ 3 (the chain split after the reference's soft-consensus-freeze hold
lapses; invalidate a block; ban a peer), not run 2 (the confiscation whitelist, alert-only on Teranode; reassign,
Teranode-only). The signed-alert delivery end to end is not run at the pin, with cause: go-alert-system v0.1.17 drops alerts
arriving over gossip (the Finding on #94) and the of-record recipe runs the alert service off; the chain and peer
transitions the alert makes were reached through the node's own RPC, and the store transitions' agreement is the theorem
half's with #140's measured row (`freeze_agrees`, `unfreeze_agrees`, `lean/BsvChain/Teranode/Alert.lean`). The
authority is policy on both nodes (`docs/PARAMETERS.md` §8.10);
the parameter set is the same, the trust root differs. The counts and the agree/differ words are the public record; the
Teranode-instance detail is in a record the export withholds
(`docs/records/20261017-170959-s4b-94-teranode-alert-path-s4b.md`). Each of the leg's rows now points at one obligation of #88's list (section 8): the freeze and unfreeze rows at
the row `freeze-confiscation` (theorem), row c at `soft-freeze` (chain-split, #153), rows e and f at `alert-system`
(design, #154). The store half's rows (its paragraph in this section) point at `freeze-confiscation` (theorem: the
freeze, unfreeze and strand rows agreeing), `alert-system` (design: the reassign row) and `invalidation` (design, #155:
row e2 under the alert-driven invalidate).

**#93's measured leg** (the hazard rung, 2026-10-17, on the box): chain selection and reorg, the same blocks
submitted to a fresh regtest reference and a fresh Teranode instance side by side (each reference-mined block carried to
Teranode over the legacy bridge): 11 rows, agree 9, differ 1 (reconsiderblock of a descendant of an invalidated parent:
the reference clears the ancestors and reorganises, Teranode refuses until the parent itself is reconsidered; the reorgs,
rows c and d, agree), not run 1 by name (the peer-blocks optimistic-mining opt-in). The counts and the verdict words are
the public record; the instance detail is a withheld record
(`docs/records/20261017-180732-s4b-93-teranode-chain-reorg-s4b.md`, withheld from the export). Its rows' obligations in #88's
list (section 8): the reorg and equal-work rows at `reorg` and `chain-selection` (theorem), row e2 and the tips-listing
row g at `invalidation` (design, #155; e2 re-measured under the alert-driven invalidate in the store half, the
difference standing).

**#92's measured leg** (the hazard rung, 2026-10-17, on the box): the record lifetimes were driven on a fresh
regtest instance beside three reference instances (the defaults, `mempoolexpiry=1`, `maxmempool=300`), the same
transactions and blocks on both columns: 26 rows, agree 23, differ 3, not run 0. The maturity rule agrees in the mempool
at every measured depth (98, 99, 100, 101) and across a reorg; the two policy lifetimes differ as the theorem half says
(the expiry: wall hours on the reference against Teranode's kept unmined record, `expiry_rules_differ`; the eviction: the
reference's mempool size against Teranode's unbounded store); the block-context maturity boundary differs, this leg's
finding: the same block carrying a depth-99 coinbase spend was refused by every reference instance
(`bad-txns-premature-spend-of-coinbase`) and held by Teranode as its best, the witness block named in the record; the maintainers ruled it a design
row (below). The lock mark was observed live inside the widened window (locked on 51 of 8591 reads, the two-phase
commit unlocking after) with no reference counterpart, a design difference. The counts and the agree/differ words are the
public record; the Teranode-instance detail is a withheld record
(`docs/records/20261017-192745-s4b-92-teranode-lifetimes-s4b.md`, withheld from the export). Its rows' obligations in #88's
list (section 8): the expiry row at `unmined-lifetime` and the eviction row at `pool-size` (design), the maturity rows
and the premature-block row at `coinbase-maturity`, a design row by the maintainers' ruling of 2026-10-17 23:5xZ (card Z10,
`92: design`; `Divergence.prematureBlockParked`): Teranode validates a block's spends at its UTXO store's spend gate
(`stores/utxo/sql/sql.go:2477-2478` at `4edb60a4`) (the Aerospike store's twin: `stores/utxo/aerospike/teranode.lua:325-326` at `4edb60a4`) and has no block-context maturity check of its own at the pin, so
the block was parked as its best with nothing built on it; the reference refuses it at its block-context check
(`src/consensus/consensus.h:75`, `src/validation.cpp:2617-2625` at `6504a3af`); the hold policy, the maturity rule
itself consensus.

**#94's store half and #93's alert row, measured** (the hazard rung, 2026-10-17, on the box): the store transitions
driven on a fresh regtest Teranode instance through the signed-alert sync stream (a freeze, an unfreeze, a second freeze
and a block invalidate) and the reassign RPC, beside the reference's blacklist and invalidate RPCs, the same blocks to
both: 8 rows run, agree 6 (the common chain; the freeze refusing a spend; the unfreeze admitting the same txid on both; the
reassign's strand row, past its maturity gate the reassigned output refused for both owners; the alert-driven invalidate
falling to the same tip on both; the parent reconsider restoring it), differ 2 (the reassign design row: the reference
has no reassign, its old-script acceptance the control, Teranode's refusal the reassign's own maturity gate, a named
policy parameter; reconsiderblock of a descendant of the alert-invalidated parent, #93's e2 re-measured through the alert
path, stands), and beside them 1 row not run by name (the alert gossip delivery, the Finding on #94). The counts and the verdict words are
the public record; the instance detail is a withheld record
(`docs/records/20261017-203139-s4b-94-teranode-store-half-s4b.md`, withheld from the export).

## 2. The block states, the subtrees, assembly and the chain's FSM

**The blockchain service's FSM** has three states at the tag: IDLE (initial, `services/blockchain/fsm.go:110`), RUNNING and CATCHINGBLOCKS (`services/blockchain/blockchain_api/blockchain_api.proto:983-985`; the legacy states are `reserved` at `:986-987`); the events RUN (`fsm.go:19-24`), CATCHUPBLOCKS (`:27-32`), STOP (`:35-40`) [SRC]. Only RUNNING feeds block assembly from block or subtree validation (`services/subtreevalidation/check_block_subtrees.go:550-556`). NO FUNCTION onto `Status`: the FSM gates the services, it is not a transaction's state; the instance's recipe starts in RUNNING (`harness/engines/instance41/README.md`, `LocalTestStartFromState`).

**The per-block marks** (`stores/blockchain/sql/sql.go:647-673`): `invalid` (`:664`; set over every descendant by `InvalidateBlock.go:100-112`, cleared for the block only by `RevalidateBlock.go:36-39`), `mined_set` (`:665`; set at the end of `setTxMinedStatus`, `BlockValidation.go:1539`), `subtrees_set` (`:666`), `processed_at` (`:669`; set when block assembly applies the block, cleared when it moves it back, `SubtreeProcessor.go:4773`), `chain_work` (`:658`), `on_main_chain` (`:673`) [SRC]. The current chain is `WHERE invalid = false ORDER BY chain_work DESC, peer_id ASC, id ASC` (`stores/blockchain/sql/GetBestBlockHeader.go:134-135`) [SRC].

| block state | moved by `[SRC]` | the reference's counterpart | onto `Status` `[D]` |
|---|---|---|---|
| received | `services/blockvalidation/Server.go:1347` (BlockFound), `:1467` (ProcessBlock, legacy); catchup | `ProcessNewBlock` | none (a block state) |
| stored invalid | `checkParentInvalid` then `storeInvalidBlock` (`BlockValidation.go:2025-2032`, `:2678`); `markBlockAsInvalid` (`:2659`) | `BLOCK_FAILED_VALID` | its transactions keep no active inclusion: not `minedActive` |
| validated and stored | `ValidateBlock` `:1668`, `ValidateBlockWithOptions` `:1688`, `validateBlockSubtrees` `:3516`, `checkOldBlockIDs` `:3621`, `AddBlock` (`services/blockchain/Server.go:1104`) | `AcceptBlock`, `ConnectBlock` | the body's transactions `minedActive h` once `mined_set` |
| subtrees set, mined set | `updateSubtreesDAH` (`BlockValidation.go:3497`), `setTxMinedStatus` (`:1410`) | `ConnectBlock`'s coins and `RemoveForBlock` | as above |
| applied by assembly (`processed_at`) | `SubtreeProcessor.go:1749,1826,4493,5702` | the mempool's block connection | none |
| on the current chain | the best-header query above | `chainActive` | `minedActive h` for its body |
| off the current chain | a reorganization; `InvalidateBlock` (`Server.go:2380`) | a stale branch, `invalidateblock` | `onStaleBranch` for a body transaction not held by assembly |

`getchaintips`' words (`stores/blockchain/sql/GetChainTips.go:115,153-162`): `invalid`, `active`, `valid-fork` (when `processed_at` is set), `valid-headers` (when `subtrees_set`), `headers-only` [SRC]. They do not mean the reference's: Teranode stores no header without its body, and `processed_at` is cleared on a move back, so a reorganized-away tip reads `valid-headers` (measured, rows c, d and f2 of `docs/records/20261017-180732-s4b-93-teranode-chain-reorg-s4b.md`, withheld; row e3 read `valid-fork` on both).

**Subtrees.** A subtree is validated and stored when its file and meta exist (`services/subtreevalidation/SubtreeValidation.go:111`, `:651-655`, `storeSubtreeFiles` `:895`); `ValidateSubtreeInternal` (`:627`), `blessMissingTransaction` (`:415`, through `ValidateWithOptions` `:433`), `processMissingTransactions` (`:1142`). A block's subtrees are checked by `CheckBlockSubtrees` (`check_block_subtrees.go:389`) with `SkipPolicyChecks`, `InBlock`, `CreateConflicting` and the candidate height (`:1283-1299`) [SRC]. A transaction that arrives only in a subtree is validated, stored unmined and added to assembly when the FSM is RUNNING. NO FUNCTION onto `Status` for the subtree itself: it is the body's staging, as the reference's block body is.

**Block assembly** (`services/blockassembly/BlockAssembler.go:63-92`: starting, running, resetting, blockchainSubscription, reorging, movingUp, reconciling). Its contents are the chained subtrees and the current subtree (`subtreeprocessor/SubtreeProcessor.go:267-298`, collected `:942-957`); `getrawmempool` lists them with the coinbase placeholder node at the head (`services/rpc/handlers.go:1353-1386`; [M] 2026-10-14: an empty instance answers the all-`ff` id); `getminingcandidate`'s `num_tx` counts them less that node (`BlockAssembler.go:2030-2059`). `GetMiningCandidate` (`:1969`), `AddTxBatchIfRoom` (`:1818`), `RemoveTx` (`:1830`), `handleReorg` (`:2211`), `getReorgBlocks` (`:2333`), `loadUnminedTransactions` (`:3199`), `setBestBlockHeader` (`:1226`); `moveBackBlock` (`SubtreeProcessor.go:4720`) puts a block's transactions back, `ReverseProcessConflicting` runs (`:4205`) [SRC]. Assembly's view is the `inMempool` reading of section 5.

**The legacy bridge** (`services/legacy`): transactions by `handleTxMsg` (`netsync/manager.go:1271`, `Validate` at `:1320` with default options), the orphan map above, blocks by `handleBlockMsg` (`:1726`) into `HandleBlockDirect` (`netsync/handle_block.go:52`) and `blockValidation.ProcessBlock` (`:348`) [SRC]. It is the only path with an orphan pool and the only one that delivers a block not mined by the node itself; the instance's recipe runs it off (`-legacy=0`, `daemon/daemon.go:577-600`). The bridge's map is S8's #98.

## 3. Where Teranode's machine differs from the reference's (each a Finding with its witness in section 6, or a reading owed)

1. No non-final pool: the reference holds a non-final transaction (`heldNonFinal`); Teranode refuses it (UTXO_NON_FINAL 71 / TX_LOCK_TIME 35). Holding is policy (DESIGN-S6 2.1 row 3), so the run records it non-judging, never diverge. Measured: section 6.
2. No orphan pool off the legacy bridge: on RPC both nodes answer an error for a missing parent (Teranode's from the absurd-fee parent read ahead of validation, section 1's orphan row); the retained orphan exists only in the bridge's map.
3. A resubmitted known transaction is answered as success (`Validator.go:1106-1141`), mined or not; the reference's RPC answers -27 `Transaction already in the mempool` from its precheck (`src/rpc/rawtransaction.cpp:1598-1664` at `6504a3af`) for a pooled transaction; a mined one goes to validation and is refused `txn-already-known` (`validation.cpp:1180-1183`). Measured on Teranode for the pooled case only: section 6 (`already-accepted`).
4. One RPC code for every refusal of a decodable transaction (-25, `services/rpc/handlers.go:900-904,913-916,926-930`); the class is in the message's words.
5. A losing double spend in the pool is refused, never stored (`CreateConflicting` false by default, `options.go:227`); block-carried double spends are stored conflicting and cascade to every descendant (`MarkConflictingRecursively`).
6. Equal-work tips are ordered by `peer_id`, then insertion id (`GetBestBlockHeader.go:134-135`), not by the order of arrival (measured at the defaults, rows b and f1, `docs/records/20261017-180732-s4b-93-teranode-chain-reorg-s4b.md`).
7. `getblockheader`'s `status` is fixed `"active"` (`handlers.go:362`), `getchaintips` is cached 300 s when `RPC.CacheEnabled` (`:2963-2964`; `rpc_cache_enabled` default true, `settings/settings.go:773`, not set by the recipe's `settings_local.conf`), `getbestblockhash` and `getblockchaininfo` 10 s (`:73-74`, `:515-527`, `:1473-1515`); `getblock`'s `tx` list is empty by design (`:475-483`).

## 4. The error vocabulary onto `Status`

Every refusal of `sendrawtransaction` is `{"code": -25, "message": "TX rejected: " + the error chain}` (`services/rpc/handlers.go:926-930`; the prefix `:67`; `-25` is `ErrRPCVerify`, `services/rpc/bsvjson/jsonrpcerr.go:41`) [SRC]. Malformed bytes are -22 (`:848`, `:854-856`) and the RPC's absurd-fee ceiling -25 (`:913-916`). The codes (`errors/error.proto:17-109`) and sentinels (`errors/Error_types.go`) that reach a transaction:

| code `[SRC] errors/error.proto` | sentinel `[SRC] Error_types.go` | raised at `[SRC]` | onto `Status` `[D]` | the reference's nearest reason |
|---|---|---|---|---|
| TX_INVALID 31 (`:54`) | `ErrTxInvalid` `:63` | consensus and script failures, `TxValidator.go:132-229` | `rejected` | `bad-txns-*`, `mandatory-script-verify-flag-failed` |
| TX_POLICY 39 (`:62`) | `ErrTxPolicy` `:68` | policy checks | `rejected` (policy: never the rule) | the standardness and fee reasons |
| TX_CONSENSUS 40 (`:63`) | | no non-test constructor at the tag | none | |
| TX_LOCK_TIME 35 (`:58`) inside UTXO_NON_FINAL 71 (`:76`) | `ErrTxLockTime` `:65`, `ErrNonFinal` `:41` | `Validator.go:978-979` | `rejected`, where the reference says `heldNonFinal` | `non-final` (held, not refused, by the reference) |
| TX_MISSING_PARENT 34 (`:57`) | `ErrTxMissingParent` `:66` | `Validator.go:1660`, `:2725` | `rejected` from the validator (on RPC the absurd-fee parent read refuses ahead of it, `handlers.go:880-904`, with PROCESSING 4); `orphan` in the legacy bridge | `Missing inputs` (RPC -25) |
| UTXO_SPENT 70 (`:75`) | `ErrSpent` `:42` | `stores/utxo/aerospike/spend.go:1095` | `rejected`, or `conflictedByMinedSpend` when the spender is mined on the current chain (section 3's clause 6 stands above clause 7) | `txn-mempool-conflict`, `bad-txns-inputs-missingorspent` |
| TX_CONFLICTING 36 (`:59`) | `ErrTxConflicting` `:60` | `spend.go:1051`; `Validator.go:1169-1220` | `rejected`, or the stored conflicting state of section 1 | `txn-mempool-conflict` |
| TX_LOCKED 37 (`:60`), TX_CREATING 41 (`:64`) | `ErrTxLocked` `:69`, `ErrTxCreating` `:70` | `spend.go:1053-1055` | retried (`Validator.go:669-700`); on exhaustion `rejected`, or `orphan` in the bridge | none |
| TX_COINBASE_IMMATURE 38 (`:61`) | `ErrTxCoinbaseImmature` `:59` | `spend.go:1057` | `rejected` | `bad-txns-premature-spend-of-coinbase` |
| UTXO_FROZEN 72 (`:77`) | `ErrFrozen` `:40` | `spend.go:1104` | `rejected` | the reference's frozen-TXO reasons (#70) |
| TX_EXISTS 33 (`:56`) | `ErrTxExists` `:62` | `Validator.go:1106-1141` | the existing status (success on RPC) | `txn-already-in-mempool`, `txn-already-known` |
| TX_NOT_FOUND 30 (`:53`), UTXO_NOT_FOUND 73 (`:78`) | `ErrTxNotFound` `:67` | `spend.go:1059,1110` | `rejected` (TX_MISSING_PARENT on the validator's path) | `Missing inputs` |
| TX_INVALID_DOUBLE_SPEND 32 (`:55`) | `ErrTxInvalidDoubleSpend` `:64` | no non-test constructor at the tag | none | |
| BLOCK_INVALID 11 (`:35`) and the block codes `:34-43`, `:106`, `:108` | `Error_types.go:14-25` | block validation | none (a block's) | the reference's block reasons |

The runner reads the words from the innermost outward (`harness/engines/teranode/client.rs`, `verdict_word`), the generic wrappers (PROCESSING 4, ERROR 9, the service and storage wrappers) skipped.

## 5. The observation set

For each observation the SV-node column makes per scenario step (DESIGN-S6 5.1's observe row), the Teranode read that answers it, as `harness/engines/teranode/client.rs` implements it:

| the SV-node observation | the Teranode read `[SRC]` | status |
|---|---|---|
| the tip: `getbestblockhash`, `getblock` | `getmininginfo` `blocks` (`services/rpc/handlers.go:2638-2673`) then `getblockbyheight` (`:177-194`): `getbestblockhash` and `getblockchaininfo` answer from a 10 s cache (`:73-74`, `:515-527`, `:1473-1515`) | implemented (`Tera::tip`) |
| the pool: `getrawmempool` | `getrawmempool` (`:1353-1386`, block assembly's `GetTransactionHashes`) less the coinbase placeholder node | implemented (`Tera::pool`, `settle_in_pool`) |
| the non-final pool: `getrawnonfinalmempool` | none: no entry in the handler table `services/rpc/Server.go:160-226` nor the unimplemented list `:277-285` (`git grep` of the name in `Server.go` at the tag: empty) `[SRC]`, and no such pool (`Validator.go:976-983`) | NOT OBSERVABLE; NO FUNCTION |
| the orphan pool: `getorphaninfo` | none: no entry in the handler table `services/rpc/Server.go:160-226` nor the unimplemented list `:277-285` (`git grep` of the name in `Server.go` at the tag: empty) `[SRC]`; the legacy bridge's map (`netsync/manager.go:487`) has no RPC or asset route | NOT OBSERVABLE |
| a transaction's inclusion: `getblock hash` and its tx list, `getrawtransaction id 1` | the asset `txmeta/<id>/json` (`services/asset/httpimpl/http.go:340`; `GetTransactionMeta.go:94-238`: `blockHashes`, `blockHeights`, `subtreeIdxs`, `mainChainIndex`), each block's `getblock` confirmations (-1 off the current chain, `handlers.go:127-142`); `getblock`'s tx list is empty by design (`:475-483`); the runner journals each watched transaction's blocks after every block, since an invalidation removes the entry (`teranode.lua:584-606`) | implemented (`Tera::txmeta`, `on_active`; the journal in `harness/src/scenarios/teranode.rs`) |
| an output's spender: `gettxout` and the spender's body | the asset `utxos/<txid>/json` (`http.go:415`; `GetUTXOsByTXID.go:40-60,124-240`: `status` and `spendingData.txId`); `gettxout` is unimplemented (`services/rpc/Server.go:196`) | implemented (`Tera::utxos`) |
| the reject reason: `sendrawtransaction`'s error | the same RPC's -25 and its words (section 4); no `sendrawtransactions` (no entry in the handler table `services/rpc/Server.go:160-226` nor the unimplemented list `:277-285` (`git grep` of the name in `Server.go` at the tag: empty) `[SRC]`) | implemented (`verdict_word`) |
| the chain tips: `getchaintips` | `getchaintips` (`handlers.go:2928-2970`), cached 300 s when `RPC.CacheEnabled` (`:2963-2964`, default true, `settings/settings.go:773`): judged never; recorded at the run's end | recorded, non-judging |
| the mempool's size and limits: `getmempoolinfo` | unimplemented (`Server.go:189`) | NOT OBSERVABLE |
| the clock: `setmocktime`, `getnetworkinfo` `timeoffset` | none: `setmocktime` has no entry in the handler table `services/rpc/Server.go:160-226` nor the unimplemented list `:277-285` (`git grep` of the name in `Server.go` at the tag: empty) `[SRC]`; `getnetworkinfo` unimplemented (`Server.go:281`); `generatetoaddress` stamps the host clock | NOT OBSERVABLE (every clock-driven row is unrealizable) |
| a harness block: `submitblock` | unimplemented (`Server.go:211` into `handleUnimplemented` `:389`); the bridge that could carry one is off | NOT OBSERVABLE (every row that delivers a harness block is unrealizable) |
| invalidation: `invalidateblock`, `reconsiderblock` | `invalidateblock` (`handlers.go:1862`); `reconsiderblock` (`:1919`, a full revalidation) | implemented (the stale witness) |

**The derived status read from these** (`derive` in `harness/src/scenarios/teranode.rs`, section 3's clauses in order): `minedActive h` when a block hash of the record or of the journal is on the current chain (the greatest height); `inMempool` when block assembly lists the id; `heldNonFinal` never (no function); `orphan` never (not observable); `onStaleBranch` when a block of the record or journal is off the current chain; `conflictedByMinedSpend` when an input's spender (`spendingData.txId`) is another transaction mined on the current chain; `rejected` from the journal's answer, namespace `teranode-rpc`; else `unknown`.

## 6. The Teranode column of #67 and the run

[M] The column's run, its counts per family and its findings are in [the record](records/20261014-215508-s6-74-second-oracle-s4b.md); the cells below come from that run's status witnesses (`status_witnesses` in [its JSON](records/20261014-215508-s6-74-second-oracle-s4b.json)) and from sections 1 and 5. The witness column names the step; the observed column is what the step read, so a step whose observed value differs from its row's status did not witness that status.

| derived status | Teranode's own state (store and assembly) | the reading | witness on the instance | observed [M] |
|---|---|---|---|---|
| `unknown` | no record | function | `unknown` | `unknown` |
| `orphan` | the legacy bridge's map only | not observable on this instance; no function on RPC | `orphan (RPC path)` | `rejected` (the value `orphan` is unrealized) |
| `inMempool` | unmined record, in assembly | function | `inMempool` | `inMempool` |
| `heldNonFinal` | none (refused: no non-final pool) | function (`refused`, namespace `teranode-rpc`; the hold is policy) | `heldNonFinal` | `rejected` (non-judging: the hold is policy, DESIGN-S6 2.1 row 3) |
| `minedActive h` | block IDs and heights; the block current | function | `minedActive` | `minedActive 103` |
| `onStaleBranch` | block IDs off the current chain, or the journal's block after an invalidation | function through the journal (by source; unwitnessed); the store alone forgets an invalidated block (`[SRC]` only) | `onStaleBranch (after invalidation)` | `inMempool` (the value `onStaleBranch` is unrealized: the transaction is re-admitted) |
| `conflictedByMinedSpend` | the input's spender mined on the current chain (the loser of a block-carried spend is also marked `conflicting`) | function | `conflictedByMinedSpend` | `conflictedByMinedSpend` |
| `rejected code reason` | no stored state; the RPC's -25 and its words | function (namespace `teranode-rpc`) | `rejected` | `rejected` |

**Where the cells live.** The generated table (`spec/status-views.md`) is written by `tools/specgen.py` from `lean/BsvChain/Views/Status.lean`, whose two client-facing Teranode columns are the validator's and propagation's HTTP answers. [D] 2026-10-15: the node-side column above is the generated table's seventh, `Teranode node`: `teranodeState : Status → Option TeranodeState` in `Views/Status.lean`, seven function cells (`noRecord`, `unmined`, `minedOnCurrent h`, `minedOffCurrent`, `spentByMinedOther`, `refused` for `rejected` and for `heldNonFinal`) and one recorded no-function cell (`orphan`), each cell naming its witness step in the record; `onStaleBranch`'s cell stays by source, its step unrealized. The chain leg checks each cell against `teranodeState` and the map's reading back (`teranodeRead`); the witnesses stay the record's, not a replay's.

## 7. What #66's cut 2 still needs from this observation set

The rows this cut leaves unrealizable fall in seven classes, each with its cited reason in the record: a harness-assembled block (no `submitblock`; the legacy bridge with a loopback peer would carry one: #98's road), the mock clock (none on Teranode: a scenario on the host clock with waits, or no realization), the reference's settings (each needs its Teranode setting named or the row recorded as policy), the orphan and reject-filter rows and the orphan re-evaluation rows (`orphanRetry`; the legacy bridge and a peer), a reference request mode or era context (no selector on Teranode's `sendrawtransaction`, `services/rpc/handlers.go:830-935`, and regtest eras fixed at Genesis 100 / Chronicle 200, go-chaincfg v1.6.2 `params.go:475-476`; a row that also names a setting Teranode has keeps that setting named beside), the reference's frozen admission list and double-spend detector (the alert-system freeze, `stores/utxo/Interface.go:522-532`, is not that list; no admission-time detector, a spend decided by the store's spend-then-create, `:432-454`), and the script verdicts (#41's column, through the validator's gRPC). The status witnesses and the admission rows run on one fresh instance in about a minute; a cut 2 that adds the legacy bridge needs the instance's recipe to start `-legacy=1` with a loopback peer, which the recipe does not yet do. Besides them, the run of record counts 11 rows `pending`, realizable in cut 2 without any of those roads: the two chain rows `chain-disconnected-readmitted` and `chain-invalidate-reconsider` (the steps exist on Teranode, the asset `utxos` route in place of `gettxout`); the 8 rows that select only a reference setting Teranode has by name (`acceptnonstdoutputs`, `maxtxsigopscountspolicy`, `maxrawtxfee`, `minconsolidationfactor` and `acceptnonstdconsolidationinput`, `settings/settings.go:110-134`), each policy, never the rule, `absurd-fee-zero-disables` with the per-call `allowhighfees` (`services/rpc/handlers.go:879-880`); and `missing-input-known-output` by mine-then-resubmit. The node-side Teranode column of `spec/status-views.md` landed on 2026-10-15 (section 6).

## 8. The refinement relation (#88): what is proven, what is witnessed, where the two differ

[M] 2026-10-17 (#88). The relation is `Refines` in `lean/BsvChain/Teranode/Refinement.lean`:
Teranode's state as the components model it (sections 1 and 2: the store's records with their marks, the blocks table
with its best header and tips, the current-chain read, block assembly, the FSM state, the alert service's store and ban
list, the Kafka events) is mapped onto the reference machine's state and #58's derived status by section 5's derive
(`observe`, `abstractStatus`), and it holds when every transaction's observed state is the reference's status read
through section 6's column, the candidate sets correspond, the current-chain read agrees with the rows' ancestry and the
FSM is RUNNING. Every Teranode transition family has one account (`accounts`, 16 families): seven stutter, suspend or
agree outside the relation by a theorem (`record_step_stutters`, `prune_stutters`, `fsm_stutters`, `fsm_exit_suspends`,
the alert store's freeze and unfreeze by `alert_freeze_keeps_relation` and `alert_unfreeze_refines`, `ban_stutters`,
`event_stutters`, composed by `stutter_run_simulates`); four simulate a named reference step, owed on the Lean side
(`connectSimulates`, `reorgSimulates`, `conflictDropSimulates`, `Alert.InvalidationRefines`); five leave the relation by a
divergence (`departs_carry_divergence`), the alert store's reassign among them (the reassign write is the divergence
itself, so no theorem says its frozen projection agrees); the block connection, owed, carries #92's premature-block
design row (`prematureBlockParked`). `Divergence` has the ruled rows (`softFreezeHoldLapse` #153;
`alertInvalidate`, `alertBan` #154; `reconsiderDescendant`, `tipsListing` #155; `poolEviction` on the ledger's
`tl.pool-size`, ruled `gap`) and two rows classified as design under the maintainers' framing rule of card Z8
(`alertReassign`, the store half's reassign row; `unminedExpiry`, #92's row b), their class the maintainers' to confirm at
the close, and #92's premature-block row as a design row by the maintainers' ruling on card Z10 (`prematureBlockParked`).

The obligation list, one obligation per row of #87's module map (54 rows), is `corpus/teranode/obligations.json`,
emitted from the Lean list and compared with it by `chaincheck --refinement` in the chain leg, and rendered as section 5
of `spec/node-client-contract.md`. Its counts [M]:

- **Proven: 11 theorem rows** (`script-word`, `utxo-spend`, `block-structure`, `merkle-root`, `chain-selection`,
  `reorg`, `freeze-confiscation`, `observation-rpc`, `wire-tx`, and #98's `tx-relay` and `reject-filter`,
  2026-10-18, `lean/BsvChain/Teranode/Bridge.lean`, each with the bridge's measured half owed to the mixed two-node scenario); three of
  them also carry a measured leg agreeing (#93's reorg and equal-work rows, #94's freeze and unfreeze rows).
- **Witnessed: 1 witness row** (`script-verdict`: #152's step 2, 1,860 slots signed, 1,850 agree, 0 differ, 10 apart on
  finality only).
- **Design: 17 rows** (the divergences policy, `coinbase-maturity`'s rule consensus; Teranode's reason before the difference): the eight design divergences of the measured legs on five rows,
  `unmined-lifetime` and `pool-size` (#92's expiry and eviction rows), `coinbase-maturity` (#92's premature-block row, card
  Z10), `invalidation` (#155: #93's rows e2 and g) and
  `alert-system` (#154: #94's rows e and f; the store half's reassign row), and the absence ledger's twelve other design rows, ruled by the maintainers'
  rule of 2026-10-15.
- **Chain split: 1 row** (`soft-freeze`, consensus, #153): the reference holds a block spending a consensus-frozen
  output for its soft-freeze duration and then activates through it; Teranode refuses the block and stays on its own
  tip. Witnessed by #140's row on both oracles and #94's row c (counts above).
- **Judged by the gate: 10 report rows** (#95), the rows the two implement the same way.
- **Open: 14 rows**, the Lean side 10, the harness side 4.

#95's per-release gate re-measures the 20 rows the list marks for a re-run (the report rows on the column, every row a
leg measured on its leg's scenario).

The gate's live run of record (2026-10-17, on the box): [the gate record](records/20261017-234627-s8-95-gate-report-s3.md),
Teranode v0.16.0 against bitcoin-sv v1.2.3 at `662bae70`, 478 scenario rows on both columns and 54,854 script entries
against the instance (53,822 judged, every one agreeing, 0 disagreeing), 11 divergences standing (7 design, 3 open,
1 chain-split) and 3 delta lines against the dry-run shape record.
