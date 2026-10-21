# Status vocabularies as views

[D] 2026-10-13. Generated from `lean/BsvChain/Status.lean` and `lean/BsvChain/Views/Status.lean`. Every cell describes a view, never a rule. Partial functions return a source word where Status determines its predicate, undefined elsewhere. Stored asynchronous reports separately need producer history. The node column is an Option extension of the completed rejection vocabulary: `none` is a derivation, never a literal RPC word.

[M] Table shape: 8 rows by 7 columns; 20 function cells including 5 partial cells; 36 no-function cells.

| derived status [D] | Arcade | ProvenTxReqStatus | TransactionStatus | Teranode validator | Teranode propagation | node rejection | Teranode node |
|---|---|---|---|---|---|---|---|
| `unknown` | no function: initial receipt delivery and prior lifecycle state (models/transaction.go:90-93,167-176 at 1ae1208e); [2026-10-13-status-view-unknown](../corpus/scenarios/2026-10-13-status-view-unknown.md) | no function: signed noSend versus delayed queue; rejected receipt history (sdk/types.ts:22-26,30-34,48,50; storage/methods/processAction.ts:359-370 at edf6e03d); [2026-10-13-status-view-unknown](../corpus/scenarios/2026-10-13-status-view-unknown.md) | no function: prior failed storage record and recovery label (monitor/tasks/TaskFailAbandoned.ts:36-46; storage/methods/ListActionsSpecOp.ts:123-139 at edf6e03d); [2026-10-13-status-view-unknown](../corpus/scenarios/2026-10-13-status-view-unknown.md) | no function: non-default HTTP options versus a returned processing error (services/validator/Server.go:899-909,733-740,970-1002 at 4edb60a4); [2026-10-13-status-view-unknown](../corpus/scenarios/2026-10-13-status-view-unknown.md) | no function: ErrInvalidArgument versus dependency failure cause (services/propagation/Server.go:759-790 at 4edb60a4); [2026-10-13-status-view-unknown](../corpus/scenarios/2026-10-13-status-view-unknown.md) | function: `none` (derived status has no rejection output) | function: `noRecord` [SRC] map section 1 row no record; the asset txmeta route (services/asset/httpimpl/http.go:340) and getrawmempool (services/rpc/handlers.go:1353) at 4edb60a4; witness: step unknown (4eb99653aae55cd8...): observed unknown [M], agree; [20261014-215508-s6-74-second-oracle-s4b](../docs/records/20261014-215508-s6-74-second-oracle-s4b.md#the-status-witnesses) |
| `orphan` | no function: initial receipt delivery and prior lifecycle state (models/transaction.go:90-93,167-176 at 1ae1208e); [2026-10-13-status-view-orphan](../corpus/scenarios/2026-10-13-status-view-orphan.md) | no function: signed noSend versus delayed queue; rejected receipt history (sdk/types.ts:22-26,30-34,48,50; storage/methods/processAction.ts:359-370 at edf6e03d); [2026-10-13-status-view-orphan](../corpus/scenarios/2026-10-13-status-view-orphan.md) | no function: prior failed storage record and recovery label (monitor/tasks/TaskFailAbandoned.ts:36-46; storage/methods/ListActionsSpecOp.ts:123-139 at edf6e03d); [2026-10-13-status-view-orphan](../corpus/scenarios/2026-10-13-status-view-orphan.md) | no function: non-default HTTP options versus a returned processing error (services/validator/Server.go:899-909,733-740,970-1002 at 4edb60a4); [2026-10-13-status-view-orphan](../corpus/scenarios/2026-10-13-status-view-orphan.md) | no function: ErrInvalidArgument versus dependency failure cause (services/propagation/Server.go:759-790 at 4edb60a4); [2026-10-13-status-view-orphan](../corpus/scenarios/2026-10-13-status-view-orphan.md) | function: `none` (derived status has no rejection output) | no function: the retained orphan lives only in the legacy bridge's expiring map (services/legacy/netsync/manager.go:487,1335-1352), which no RPC or asset route reads and the recipe runs off (-legacy=0, daemon/daemon.go:577-600); on RPC nothing is kept, the absurd-fee parent read refusing ahead of validation (services/rpc/handlers.go:880-904) at 4edb60a4; witness: step orphan (RPC path) (146984bf39c452d0...): observed rejected -25 None [M] (the RPC's PROCESSING (4) refusal before validation, record's status witnesses); the value orphan unrealized; [20261014-215508-s6-74-second-oracle-s4b](../docs/records/20261014-215508-s6-74-second-oracle-s4b.md#the-status-witnesses) |
| `inMempool` | no function: initial receipt delivery and prior lifecycle state (models/transaction.go:90-93,167-176 at 1ae1208e); [2026-10-13-status-view-inMempool](../corpus/scenarios/2026-10-13-status-view-inMempool.md) | no function: signed noSend versus delayed queue; rejected receipt history (sdk/types.ts:22-26,30-34,48,50; storage/methods/processAction.ts:359-370 at edf6e03d); [2026-10-13-status-view-inMempool](../corpus/scenarios/2026-10-13-status-view-inMempool.md) | no function: prior failed storage record and recovery label (monitor/tasks/TaskFailAbandoned.ts:36-46; storage/methods/ListActionsSpecOp.ts:123-139 at edf6e03d); [2026-10-13-status-view-inMempool](../corpus/scenarios/2026-10-13-status-view-inMempool.md) | no function: non-default HTTP options versus a returned processing error (services/validator/Server.go:899-909,733-740,970-1002 at 4edb60a4); [2026-10-13-status-view-inMempool](../corpus/scenarios/2026-10-13-status-view-inMempool.md) | no function: ErrInvalidArgument versus dependency failure cause (services/propagation/Server.go:759-790 at 4edb60a4); [2026-10-13-status-view-inMempool](../corpus/scenarios/2026-10-13-status-view-inMempool.md) | function: `none` (derived status has no rejection output) | function: `unmined` [SRC] unminedSince set (stores/utxo/fields/fields.go:79), listed by block assembly through getrawmempool (services/rpc/handlers.go:1353) at 4edb60a4; witness: step inMempool (1601152dd94823ac...): observed inMempool [M], agree; [20261014-215508-s6-74-second-oracle-s4b](../docs/records/20261014-215508-s6-74-second-oracle-s4b.md#the-status-witnesses) |
| `heldNonFinal` | no function: initial receipt delivery and prior lifecycle state (models/transaction.go:90-93,167-176 at 1ae1208e); [2026-10-13-status-view-heldNonFinal](../corpus/scenarios/2026-10-13-status-view-heldNonFinal.md) | no function: signed noSend versus delayed queue; rejected receipt history (sdk/types.ts:22-26,30-34,48,50; storage/methods/processAction.ts:359-370 at edf6e03d); [2026-10-13-status-view-heldNonFinal](../corpus/scenarios/2026-10-13-status-view-heldNonFinal.md) | no function: prior failed storage record and recovery label (monitor/tasks/TaskFailAbandoned.ts:36-46; storage/methods/ListActionsSpecOp.ts:123-139 at edf6e03d); [2026-10-13-status-view-heldNonFinal](../corpus/scenarios/2026-10-13-status-view-heldNonFinal.md) | no function: non-default HTTP options versus a returned processing error (services/validator/Server.go:899-909,733-740,970-1002 at 4edb60a4); [2026-10-13-status-view-heldNonFinal](../corpus/scenarios/2026-10-13-status-view-heldNonFinal.md) | no function: ErrInvalidArgument versus dependency failure cause (services/propagation/Server.go:759-790 at 4edb60a4); [2026-10-13-status-view-heldNonFinal](../corpus/scenarios/2026-10-13-status-view-heldNonFinal.md) | function: `none` (derived status has no rejection output) | function: `refused` [SRC] no non-final pool: a non-final transaction is refused with UTXO_NON_FINAL 71 wrapping TX_LOCK_TIME 35 (services/validator/Validator.go:976-983; util/lock_time.go) at 4edb60a4; the hold is policy (DESIGN-S6 2.1 row 3), never the rule; witness: step heldNonFinal (53c6bc6316407bd3...): observed rejected -25 TX_LOCK_TIME [M], non-judging; [20261014-215508-s6-74-second-oracle-s4b](../docs/records/20261014-215508-s6-74-second-oracle-s4b.md#the-status-witnesses) |
| `minedActive h` | function (partial): `MINED` [SRC] models/transaction.go:110-111 at 1ae1208e; separate stored-report obstruction: initial receipt delivery and prior lifecycle state (models/transaction.go:90-93,167-176 at 1ae1208e); [2026-10-13-status-view-minedActive](../corpus/scenarios/2026-10-13-status-view-minedActive.md) | no function: signed noSend versus delayed queue; rejected receipt history (sdk/types.ts:22-26,30-34,48,50; storage/methods/processAction.ts:359-370 at edf6e03d); [2026-10-13-status-view-minedActive](../corpus/scenarios/2026-10-13-status-view-minedActive.md) | no function: prior failed storage record and recovery label (monitor/tasks/TaskFailAbandoned.ts:36-46; storage/methods/ListActionsSpecOp.ts:123-139 at edf6e03d); [2026-10-13-status-view-minedActive](../corpus/scenarios/2026-10-13-status-view-minedActive.md) | no function: non-default HTTP options versus a returned processing error (services/validator/Server.go:899-909,733-740,970-1002 at 4edb60a4); [2026-10-13-status-view-minedActive](../corpus/scenarios/2026-10-13-status-view-minedActive.md) | no function: ErrInvalidArgument versus dependency failure cause (services/propagation/Server.go:759-790 at 4edb60a4); [2026-10-13-status-view-minedActive](../corpus/scenarios/2026-10-13-status-view-minedActive.md) | function: `none` (derived status has no rejection output) | function: `minedOnCurrent h` [SRC] blockIDs and blockHeights (stores/utxo/fields/fields.go:64-66), the block current by getblock confirmations (services/rpc/handlers.go:127-142) at 4edb60a4; witness: step minedActive (1601152dd94823ac...): observed minedActive 103 [M], agree; [20261014-215508-s6-74-second-oracle-s4b](../docs/records/20261014-215508-s6-74-second-oracle-s4b.md#the-status-witnesses) |
| `onStaleBranch` | function (partial): `MINED` [SRC] models/transaction.go:110-111 at 1ae1208e; off-active body inclusion, stored reorg events separate (:326-331); separate stored-report obstruction: initial receipt delivery and prior lifecycle state (models/transaction.go:90-93,167-176 at 1ae1208e); stored reorg_unmined SEEN_ON_NETWORK / reorg_reanchor MINED events (:326-331 at 1ae1208e); [2026-10-13-status-view-onStaleBranch](../corpus/scenarios/2026-10-13-status-view-onStaleBranch.md) | no function: signed noSend versus delayed queue; rejected receipt history (sdk/types.ts:22-26,30-34,48,50; storage/methods/processAction.ts:359-370 at edf6e03d); [2026-10-13-status-view-onStaleBranch](../corpus/scenarios/2026-10-13-status-view-onStaleBranch.md) | no function: prior failed storage record and recovery label (monitor/tasks/TaskFailAbandoned.ts:36-46; storage/methods/ListActionsSpecOp.ts:123-139 at edf6e03d); [2026-10-13-status-view-onStaleBranch](../corpus/scenarios/2026-10-13-status-view-onStaleBranch.md) | no function: non-default HTTP options versus a returned processing error (services/validator/Server.go:899-909,733-740,970-1002 at 4edb60a4); [2026-10-13-status-view-onStaleBranch](../corpus/scenarios/2026-10-13-status-view-onStaleBranch.md) | no function: ErrInvalidArgument versus dependency failure cause (services/propagation/Server.go:759-790 at 4edb60a4); [2026-10-13-status-view-onStaleBranch](../corpus/scenarios/2026-10-13-status-view-onStaleBranch.md) | function: `none` (derived status has no rejection output) | function: `minedOffCurrent` [SRC] blocks only off the current chain (getblock confirmations -1, services/rpc/handlers.go:127-142); after an invalidation the store drops the entry (stores/utxo/aerospike/teranode.lua:584-606) and the runner's journal keeps it, at 4edb60a4; witness: by source, unwitnessed: step onStaleBranch (after invalidation) (dfd683cd95242bbd...) observed inMempool [M], the transaction re-admitted, the value unrealized; [20261014-215508-s6-74-second-oracle-s4b](../docs/records/20261014-215508-s6-74-second-oracle-s4b.md#the-status-witnesses) |
| `conflictedByMinedSpend` | no function: initial receipt delivery and prior lifecycle state (models/transaction.go:90-93,167-176 at 1ae1208e); [2026-10-13-status-view-conflictedByMinedSpend](../corpus/scenarios/2026-10-13-status-view-conflictedByMinedSpend.md) | function (partial): `doubleSpend` [SRC] sdk/types.ts:46 at edf6e03d; separate stored-report obstruction: signed noSend versus delayed queue; rejected receipt history (sdk/types.ts:22-26,30-34,48,50; storage/methods/processAction.ts:359-370 at edf6e03d); [2026-10-13-status-view-conflictedByMinedSpend](../corpus/scenarios/2026-10-13-status-view-conflictedByMinedSpend.md) | no function: prior failed storage record and recovery label (monitor/tasks/TaskFailAbandoned.ts:36-46; storage/methods/ListActionsSpecOp.ts:123-139 at edf6e03d); [2026-10-13-status-view-conflictedByMinedSpend](../corpus/scenarios/2026-10-13-status-view-conflictedByMinedSpend.md) | no function: non-default HTTP options versus a returned processing error (services/validator/Server.go:899-909,733-740,970-1002 at 4edb60a4); [2026-10-13-status-view-conflictedByMinedSpend](../corpus/scenarios/2026-10-13-status-view-conflictedByMinedSpend.md) | no function: ErrInvalidArgument versus dependency failure cause (services/propagation/Server.go:759-790 at 4edb60a4); [2026-10-13-status-view-conflictedByMinedSpend](../corpus/scenarios/2026-10-13-status-view-conflictedByMinedSpend.md) | function: `none` (derived status has no rejection output) | function: `spentByMinedOther` [SRC] an input's output SPENT with spendingData (services/asset/httpimpl/GetUTXOsByTXID.go:40-46) naming another transaction mined on the current chain; the spend refused with UTXO_SPENT (stores/utxo/aerospike/spend.go:1095) at 4edb60a4; witness: step conflictedByMinedSpend (188a438b06a3ccb0...): observed conflictedByMinedSpend [M], agree; [20261014-215508-s6-74-second-oracle-s4b](../docs/records/20261014-215508-s6-74-second-oracle-s4b.md#the-status-witnesses) |
| `rejected code reason` | function (partial): `REJECTED` [SRC] models/transaction.go:104-105 at 1ae1208e; node 16 bad-txns-vin-empty only, other receipts undefined (src/validation.cpp:526-527 at 6504a3af); separate stored-report obstruction: initial receipt delivery and prior lifecycle state (models/transaction.go:90-93,167-176 at 1ae1208e); stored transition restrictions (:227-237 at 1ae1208e); [2026-10-13-status-view-rejected](../corpus/scenarios/2026-10-13-status-view-rejected.md) | function (partial): `invalid` [SRC] sdk/types.ts:48 at edf6e03d; node 16 bad-txns-vin-empty only, other receipts undefined (src/validation.cpp:526-527 at 6504a3af); separate stored-report obstruction: signed noSend versus delayed queue; rejected receipt history (sdk/types.ts:22-26,30-34,48,50; storage/methods/processAction.ts:359-370 at edf6e03d); [2026-10-13-status-view-rejected](../corpus/scenarios/2026-10-13-status-view-rejected.md) | no function: prior failed storage record and recovery label (monitor/tasks/TaskFailAbandoned.ts:36-46; storage/methods/ListActionsSpecOp.ts:123-139 at edf6e03d); [2026-10-13-status-view-rejected](../corpus/scenarios/2026-10-13-status-view-rejected.md) | no function: non-default HTTP options versus a returned processing error (services/validator/Server.go:899-909,733-740,970-1002 at 4edb60a4); [2026-10-13-status-view-rejected](../corpus/scenarios/2026-10-13-status-view-rejected.md) | no function: ErrInvalidArgument versus dependency failure cause (services/propagation/Server.go:759-790 at 4edb60a4); [2026-10-13-status-view-rejected](../corpus/scenarios/2026-10-13-status-view-rejected.md) | function: `nodeWord code`, exact reason (RPC namespace retained) | function: `refused` [SRC] no stored state; -25 with Teranode's words (services/rpc/handlers.go:924-931), malformed bytes -22 (:854-856) at 4edb60a4; the reference's code and reason are not carried; witness: step rejected (92f06005f51981ae...): observed rejected -25 TX_INVALID [M], agree; [20261014-215508-s6-74-second-oracle-s4b](../docs/records/20261014-215508-s6-74-second-oracle-s4b.md#the-status-witnesses) |

[D] No-function witnesses vary declared producer context while leaving the node state unchanged. Source predicates reject incompatible contexts, including signed noSend for the input-empty rejected fixture and validator OK without a valid response for structurally valid bytes. They do not measure Arcade, wallet-toolbox or Teranode. A shared word alone would not refute a function from Status; the missing input and equal-status context boundary are the obstruction.

[D] The Teranode node column (#74) is Teranode v0.16.0's own transaction state in its UTXO store and block assembly, a partial function of the derived status from the map's sections 1, 5 and 6 ([docs/CONFORMANCE-TERANODE-MACHINE.md](../docs/CONFORMANCE-TERANODE-MACHINE.md)). Its witnesses are the steps of one measured instance run, not producer contexts; a function cell whose step did not reach its value says so. A refusal keeps the class only: Teranode's code and words are its own namespace. The second oracle's defaults are never the rule.

## `node_rejection_reason`

[D] 2026-10-13: exact reason bytes survive the rejection projection.
This theorem is about a view, never a validation rule.

## `rpc_namespace_preserved`

[D] 2026-10-13: signed RPC errors are not silently put in the wire-code
namespace. This theorem is about a view, never a validation rule.

## `partial_mined_implies_stale`

[D] 2026-10-13: hypothesis h : arcadeStaleMining s = some MINED
entails the stale constructor, whose actual derived status retains off-active
body inclusion. No stored report is inferred. Views, never rules.

## `partial_rejected_implies_receipt`

[D] 2026-10-13: hypothesis h : arcadeRejected s = some REJECTED
entails the exact completed node receipt in this narrow domain. No producer
receipt delivery is inferred. Views, never rules.

## `empty_inputs_rejected`

[D] 2026-10-13: hypothesis hInputs : tx.inputs = [] supplies the machine's
vinEmpty rejection at every size/sigop parameter choice, and its completed receipt
projects to Arcade REJECTED. Stored history is separate. Views, never rules.
[SRC] models/transaction.go:104-105 at 1ae1208e; src/validation.cpp:526-527 at 6504a3af.

## `empty_inputs_invalid`

[D] 2026-10-13: hypothesis hInputs : tx.inputs = [] establishes the existing
machine's structural vinEmpty rejection at every size/sigop parameter choice.
The exact completed node receipt projects to invalid; an arbitrary cached report
is not used to prove hInputs. Views, never rules.
[SRC] src/validation.cpp:526-527 at 6504a3af; sdk/types.ts:48 at edf6e03d.

## `partial_mined_implies_active`

[D] 2026-10-13: active constructor suffices for the mining word.
Hypothesis h : arcadeMining s = some MINED concludes s = minedActive height
for some height. Stored reports are outside this view, never a rule.

## `doubleSpend_implies_mined_conflict`

[D] 2026-10-13: hypothesis h : requestConflict (status s id) = some doubleSpend
entails the machine's exact different active spender predicate minedConflict s id.
That predicate tests a shared outpoint, not gettxout absence alone. Views, never rules.
[SRC] sdk/types.ts:46 at edf6e03d; src/txmempool.cpp:1093-1116 at 6504a3af.

## `mined_implies_branch`

[D] 2026-10-13: hypothesis h : synchronizedMining s = MINED
concludes (exists height, s = minedActive height) or s = onStaleBranch.
Body inclusion is inherited from an actual machine-derived constructor.
Actual remote hints require synchronized evidence;
a cached MINED word has no such theorem. This view is never a rule.

## `immutable_needs_client_depth`

[D] 2026-10-13: the same machine status and tip admit different client
depth decisions. No Status-only function equals every client's depth view.
This impossibility theorem concerns views, never a machine rule.

## `seen_says_nothing_about_active`

[D] 2026-10-13: for any two machine statuses the same remote SEEN report
has the same word; it cannot distinguish unknown from active inclusion.
This theorem is about source-limited views, never a rule.

## `context_words_differ`

[D] 2026-10-13: predicate-checked contexts have different words at the
same status. Unsupported contexts return none. These are local models of cited
producer steps, never measurements or machine rules.

## `teranode_undefined_iff`

[D] 2026-10-15 (#74): the Teranode node column is undefined exactly on the
one recorded no-function row, orphan, and defined on the other seven. This
theorem is about a view, never a rule.

## `teranode_read_inverse`

[D] 2026-10-15 (#74): hypotheses h : teranodeState s = some x and
hx : x ≠ refused give back s through the map's reading: off a refusal the column
loses nothing of the derived status. This theorem is about a view, never a rule.

## `teranode_refusal_forgets_reason`

[D] 2026-10-15 (#74): any two rejections have the same Teranode state, whatever
their codes and reasons: the refusal's words are Teranode's namespace, recorded
beside the reference's and never compared. This theorem is about a view, never a rule.

## `teranode_mined_implies_active`

[D] 2026-10-15 (#74): hypothesis hs : teranodeState s = some (minedOnCurrent h)
concludes s = minedActive h: the current-chain state carries the derived height.
This theorem is about a view, never a rule.

## Pinned sources [SRC]

# Status vocabularies, 2026-10-13 [D] (#67)

Every definition and theorem here is a view, never a rule. Partial semantic functions use the facts Status determines. Exact stored
producer words separately need history; no-function cells record independent
inputs on the remaining domains. Witness contexts
are derived local inputs, never measurements of these programs.

[SRC] Arcade models/transaction.go:87-113,126-247,329-333 at 1ae1208e,
https://github.com/bsv-blockchain/arcade/blob/1ae1208e/models/transaction.go.
[SRC] wallet-toolbox packages/wallet/wallet-toolbox/src/sdk/types.ts:19-84
at edf6e03d, https://github.com/bsv-blockchain/ts-stack/blob/edf6e03d/packages/wallet/wallet-toolbox/src/sdk/types.ts.
[SRC] Stored TransactionStatus failure/recovery steps, edf6e03d:
https://github.com/bsv-blockchain/ts-stack/blob/edf6e03d/packages/wallet/wallet-toolbox/src/monitor/tasks/TaskFailAbandoned.ts#L36-L46;
https://github.com/bsv-blockchain/ts-stack/blob/edf6e03d/packages/wallet/wallet-toolbox/src/storage/methods/ListActionsSpecOp.ts#L123-L139.
[SRC] Signed send intent, edf6e03d:
https://github.com/bsv-blockchain/ts-stack/blob/edf6e03d/packages/wallet/wallet-toolbox/src/storage/methods/processAction.ts#L359-L370.
Completed notifications require sdk/types.ts:50, independent of active inclusion.
[SRC] Teranode services/validator/validator_api/validator_api.proto:88-105,
services/validator/Server.go:899-909,941-1002 and
services/propagation/Server.go:755-790; errors/Error_types.go:31,37 at v0.16.0 (4edb60a4),
https://github.com/bsv-blockchain/teranode/tree/4edb60a40c6628ff0ef60231c2628efd7103fde5/services. [SRC] Node column (#74): stores/utxo/fields/fields.go:40,64-66,79, stores/utxo/aerospike/teranode.lua:584-606, services/rpc/handlers.go:127-142,924-931, services/asset/httpimpl/GetUTXOsByTXID.go:40-46, services/asset/httpimpl/http.go:340, services/rpc/handlers.go:854-856,880-904,1353, stores/utxo/aerospike/spend.go:1095, services/legacy/netsync/manager.go:487,1335-1352, daemon/daemon.go:577-600, services/validator/Validator.go:976-983 at 4edb60a4, read through docs/CONFORMANCE-TERANODE-MACHINE.md sections 1, 5 and 6; witnesses: docs/records/20261014-215508-s6-74-second-oracle-s4b.md.
[SRC] Exact structural-invalid receipt: src/validation.cpp:526-527,
https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/validation.cpp#L526-L527.
[SRC] bitcoin-sv src/consensus/validation.h:14-24,
src/validation.h:1150-1163, src/rpc/rawtransaction.cpp:1636-1650,1716-1724
at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
