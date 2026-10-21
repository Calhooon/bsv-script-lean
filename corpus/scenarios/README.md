# Scenarios: the transaction state machine's witness corpus

[D] 2026-10-13, S3, lane trim-66: `tools/receipt_trim.py` is the reference
for committed receipt projections; full evidence stays in each run's
`receipt.json`. The runner and metadata guard apply the 10 MB rule; the
[trimming and replay record](../../docs/records/20261013-165052-receipt-trim-s3.md)
indexes the tool, tests and archival receipts.

[M] Intake dated 2026-10-12. This seeds deliverable (1) of #66 under the
owner's `intake go` at [M] 2026-10-12 16:27Z. The runner belongs to #66.
These are [D] expectations; the node column records per-row metadata independently
of the spec projection. Node replays are indexed below; client replay and the
commitment hypothesis remains a separate premise.

## File and trace format

Use one `<id>.md` file with one fenced `json` block. Prose carries the class,
witness, initial chain, steps, expected observations per machine and replay
boundary. JSON keys use their plain counterparts: `id`, `class`, `witness`,
`initial_chain`, `steps`,
`expected_observations`, `replay`. This keeps the review table and the data
citable in one file; #66 extracts the block, checks the table against it,
materializes the symbolic fixtures and records actual observations separately.
This is a seed format, not an implemented runner or a byte fixture format.

`steps` is the primary ordered trace. `variants` contains named traces with a
`fork_after` checkpoint. Each variant starts from an independent clone of
that checkpoint, including journals, time and client history; variants never
run cumulatively. Count a step once where it is declared, without counting
the setup or replaying a shared prefix in the family's step total.

Each step has `id`, `action`, `kind`, `rules`, `expected_observations`,
`label: "[D]"` and `node: "pending #66"`. Its observations contain:

- `mempool` and `non_final_pool`: exact sets of symbolic transaction names.
- `tip`: named block and height; `chain_tips`: named blocks with RPC statuses.
- `transactions`: a status for every fixture transaction, including an
  unsubmitted child. Each entry carries `[D]`, rule references and the pending
  node marker. Setup coinbases are covered by the initial-chain invariant.
- `utxos`: named outpoints and chain-only `gettxout` results; pool membership
  is observed separately. A null result alone never proves a mined conflict.
- `evidence`: the exact body, active-chain and journal observations required
  to judge the row. `client_views` records words from the selected client
  histories, beside the node status. These are derived client witnesses, not
  RPC answers or fresh measurements of those clients.

[D] Every action requesting a maintenance observation declares `trigger`
inside `action`. The trigger names its `type` (`rpc` or
`oracleInstrumentation`), its RPC or `event`, pinned `sources`, synchronization
preconditions in `after`, a `completion` witness and its pool/journal `effects`.
The trigger's inputs and expected completion inherit the step's [D] label;
source ranges inherit [SRC] at `source_pin`. #66 records the actual operation
and completion before comparing observations. A clock change alone supplies
no maintenance event.

The literal status tags are [D] the eight values of DESIGN-S6 §3:
`unknown`, `orphan`, `inMempool`, `heldNonFinal`, `minedActive` (with `height`),
`onStaleBranch`, `conflictedByMinedSpend`, `rejected` (with code namespace,
code and reason). Evaluate clauses in that section's table order. In
particular, successful re-admission gives `inMempool` before the stale-body
clause; after policy expiry a retained off-active body gives `onStaleBranch`.
`seen`, `proven`, `completed`, `Paid` and `MINED` are client words, never extra
S6 constructors. A wallet refusal is not a node `rejected` receipt.

All numeric literals in JSON inherit `input_label: "[D]"` for selected
synthetic inputs and `label: "[D]"` for expectations. Pins and cited source
line numbers inherit [SRC]; dates and declared file/step counts inherit [M].
This convention also covers symbolic heights expanded from the profile.

## Initial chain: `regtest-intake`

[D] All scenarios using this profile, including the [M] 2026-10-13
orphaned-block-proof addition, use `BsvChain.ChainParams.regtest`, with no activation override,
and `BsvChain.NodeConfig.defaults` plus the explicit launch inputs below.
The census is `docs/PARAMETERS.md` §§8.2–8.3; the definitions are in
`lean/BsvChain/Params.lean`. The reference throughout is [SRC] bitcoin-sv
v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.

| parameter | [SRC] regtest value and source at the pin |
|---|---|
| BIP34, BIP65, BIP66, CSV heights | 100000000, 1351, 1251, 576; `src/chainparams.cpp:1463–1470` |
| UAHF, DAA, Genesis, Chronicle, P2SH heights | 0, 0, 10000, 15000, 1; `src/chainparams.cpp:1487–1498` and `src/chainparams.cpp:21–31` |
| subsidy halving interval | 150 blocks; `src/chainparams.cpp:1460` |
| PoW limit, target timespan, target spacing | `0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff`, 1209600 seconds, 600 seconds; `src/chainparams.cpp:1471–1475` |
| allow minimum difficulty, no retargeting | true, true; `src/chainparams.cpp:1476–1477`; no-retargeting precedes DAA at `src/pow.cpp:107–113` |
| coinbase maturity | 100 blocks, consensus constant represented by `coinbaseMaturity`; `src/consensus/consensus.h:71–75` |
| accepted-pool expiry | `mempoolExpiry = 1209600` seconds (336 hours); policy, `src/validation.h:91`, `src/config.cpp:87` |
| non-final capacity and expiry | `maxMempoolNonFinal = 52428800` bytes, `mempoolNonFinalExpiry = 2419200` seconds; policy, `src/policy/policy.h:89`, `src/time_locked_mempool.cpp:400–404` |

[D] Mine an isolated prefix to height 100; a coinbase from height 1 funds the
ordinary transaction `F` in `base` at height 101. Its spend depth is 100, as
`checkTxInputs` requires. `F:fund` is unspent. Its output and every later
output use standard spendable scripts with valid signatures and sufficient
fees; #66 generates these from synthetic material and records the bytes.
All named transactions have `lockTime = 0`, final input sequences, distinct
inputs within a transaction and values within `MoneyRange`. In the presence
scenario `T` and `K` spend the same `F:fund`; in the proof scenario `T` spends
`F:fund` and `U` spends `T:credit`. Each ordinary transaction has one named
spendable output. Setup coinbases and `F` remain on the common prefix.

[D] Set mock time to 1700000000 seconds, with prefix header times strictly
increasing below it and every new block above its parent's median. Increment
block times within the allowed future window. This stays below the signed
tip-median boundary. `now`, entry times and the zero adjusted-time offset are
explicit inputs. Set `txIndex = true` for observations. Supply
`excessiveBlockSize = 1000001` bytes and `maxStackMemoryUsageConsensus = 100000000`
bytes as C/setting inputs, and `blockMinTxFee = 500` satoshis per 1000 bytes
as policy. These are selected launch inputs, not implicit daemon defaults
([SRC] `src/bitcoind.cpp:140–164`; census §§8.1–8.2).

[D] Start with empty accepted, non-final and orphan pools, empty rejection
journals, empty operator lists, no pending validation, and no memory pressure.
Keep default pool limits and fee history; serialize completion. The fixture
must pass the remaining admission/block checks, not merely `isFinalTx` or
`applyTx` (#60/#61). No era boundary is crossed. No peer, broadcaster or wallet
service is contacted: client inputs are local stubs. #66's later node is
isolated regtest under DESIGN-S6 §5.1. This intake starts no node.

## Steps, observations and source rules

[SRC] RPC handlers below are the pinned handlers from DESIGN-S6 §5.1.

| action or observation | RPC and source | judging contract |
|---|---|---|
| `submit` | `sendrawtransaction`, `src/rpc/rawtransaction.cpp:1530` | `receiveTx`; record the synchronous receipt and the settled pools |
| `mine` on `branch` with named `parent` | `generatetoaddress`, `src/rpc/mining.cpp:227`; `submitblock`, `src/rpc/mining.cpp:916` | Read assembled contents with `getblock`; for a specified competing spend, build and submit the named valid body without trying to admit it to the conflicting pool |
| `invalidateBlock`, `reconsiderBlock` | `invalidateblock`, `src/rpc/blockchain.cpp:2732`; `reconsiderblock`, `src/rpc/blockchain.cpp:2770` | Operator settings followed by activation, including completed re-admission |
| `advanceTime` | `setmocktime`, `src/rpc/misc.cpp:1002–1007`; the declared RPC batch invokes `LimitMempoolSize`, `src/validation.cpp:847–879` | Change `now`, execute `action.trigger`, record its completion, then read the pools; the batch completion is witnessed by #66 |
| accepted / non-final sets | `getrawmempool`, `src/rpc/blockchain.cpp:440`; `getrawnonfinalmempool`, `src/rpc/blockchain.cpp:502` | Exact sets after completion; holding and expiry are policy |
| tip and active membership | `getchaintips`, `src/rpc/blockchain.cpp:2497`; `getbestblockhash`, `src/rpc/blockchain.cpp:220`; `getblock`, `src/rpc/blockchain.cpp:1108` | Read the selected block's body and confirmations, not just a claimed height |
| input/output availability | `gettxout`, `src/rpc/blockchain.cpp:1923` | Use `include_mempool=false` for the chain-only cells; bind a conflicting spender's body to the exact input |
| transaction body | `getrawtransaction`, `src/rpc/rawtransaction.cpp:53` | Supplementary under txindex; the selected block body disambiguates inclusion |
| merkle path | `getmerkleproof`, `src/rpc/rawtransaction.cpp:2242` | Record the path and target header; #65's `verifyPath` checks root equality; inclusion has explicit commitment/shape premises; #75's codec is owed |

[D] `observeClient`, `serveBeef`, `walletRoundTrip` and `checkPath` deliver or
check local client inputs and leave node state unchanged. Their node rows
repeat the preceding state. Client evidence delivery is explicit: the harness
can know a block body before the client receives a header and path.

[SRC] Accepted-pool expiry runs inside `LimitMempoolSize`
(`src/validation.cpp:847–879`). A final transaction's commit calls it after
`AddUnchecked` (`src/validation.cpp:928–945`, DESIGN-S6 §2.1 row 14).
The synchronous batch validator also calls it after processing work
(`src/txn_validator.cpp:216–228`, `src/txn_validator.cpp:303–314`). The
asynchronous validator calls it only inside the nonempty processing-queue
branch (`src/txn_validator.cpp:417–444`). The scheduled non-final check
(`src/time_locked_mempool.cpp:240–244`, `src/time_locked_mempool.cpp:611–663`)
can enqueue a newly final held transaction, but the declared empty non-final
pool supplies no such work. Waiting after `setmocktime` is therefore
insufficient for these isolated accepted-pool expiry steps.

[M] 2026-10-13, R1: the declared size is amended to 1000001 bytes because
[SRC] `src/config.cpp:232-245` rejects a nonzero value at or below 1000000.
The historical launch witness retains the refused value.

[M] 2026-10-13, R2: the pinned RPC batch validator supplies a reachable sweep
without admitting an auxiliary transaction. Submit two distinct input-empty
transactions together through `sendrawtransactions`. The raw validator takes
its multi-item branch ([SRC] `src/rawtxvalidator.cpp:54-92,126-138`); after
processing the rejected work the batch validator calls `LimitMempoolSize`
([SRC] `src/txn_validator.cpp:216-228,303-314`). The handler waits for both
results ([SRC] `src/rpc/rawtransaction.cpp:2134-2155`). This differs from a
single rejected request, whose commit path does not sweep. No scheduler
sweep is available for the declared empty held pool.

[D] The maintenance trigger is an RPC batch containing `sweep0` and `sweep1`,
synthetic input-empty transactions with one standard output, version 1 and
lock times 0 and 1. Neither references any fixture outpoint and neither can
be admitted. Record both rejection receipts, then require a new captured
`Expired 1 transactions from the memory pool` log line ([SRC]
`src/validation.cpp:853-856`, category `mempool`), then read the pools.
The synchronous RPC return occurs after the journal change set is destroyed
([SRC] `src/rawtxvalidator.cpp:64-91`). The auxiliary rejection receipts are
kept separately; fixture journals, chain, and exact expected pool sets stay
unchanged. This replaces the unavailable direct instrumentation event.

| rule id | DESIGN-S6 rows and [SRC] basis at the pin |
|---|---|
| `receive` | §2.1 rows 1, 3, 12, 14; §3 row 2. Finality `src/validation.cpp:227–247`; inputs/fee `src/validation.cpp:2552–2665`; commit `src/validation.cpp:895–946`; pool observable above. |
| `mine` | §2.2 header/body/connection; §3 row 1. `src/validation.cpp:5736–5901`, `src/validation.cpp:6039–6107`, `src/validation.cpp:3326–3434`, `src/txmempool.cpp:1025–1173`; active selected body's membership, `src/rpc/blockchain.cpp:79–90`. Inclusion and block finality are consensus predicates. |
| `conflict` | §2.2 connection; §3 row 6, after excluding earlier clauses. `src/txmempool.cpp:1091–1117` removes the losing pool entry; a distinct active spender's body plus the journaled input establishes the conflict. Removal from the pool is policy maintenance; active input spending is a chain fact. |
| `expiry` | §2.1 row 14 and its expiry paragraph; §2.5 `advanceTime`; §3 row 8 if no branch body, row 5 if an off-active body remains. Execute the declared `trigger`: `src/validation.cpp:847–879`, `src/txmempool.cpp:2201–2221`; expiry and eviction are policy. `seen` alone does not match any positive status clause. |
| `invalidate` | §2.3; §2.4 operator and reorg-pool paragraphs; §3 rows 2, 5 in that order. `src/validation.cpp:5230–5330`, `src/processing_block_index.cpp:9–96`, `src/txmempool.cpp:2330–2443`. Invalidation is an operator setting; re-admission is policy; undo concerns chain state. |
| `reconsider` | §2.4 operator paragraph; §3 row 1. `src/rpc/blockchain.cpp:2770–2818`, `src/validation.cpp:5528–5562`. Clear failure flags and activate the sole eligible longer candidate. |
| `unchanged` | §1.4 journals and §3's ordered clauses. Delivery, storage and a wallet refusal call no node transition; there is no node rejection receipt to journal. For an unsubmitted child §3 row 8 gives `unknown`. |
| `path` | §4.4 row 5, §8 S6-1, §3 row 1. `src/consensus/merkle.cpp:284–310`. Check leaf identity, index/path shape, root against the named header and header membership in the active chain. Root equality alone is not inclusion; #65 proves the membership-or-collision theorem over the hash definition. |

[D] The proof scenario keeps `transactions` as the full node-state status.
Its `client_evidence.status` is the conservative status supported by the
client's recorded inputs, with `seen_body` tracked separately. With no pool
observation, path or header it is `unknown`, even when the node has already
mined the transaction. Storage does not create inclusion. Receiving a checked
path changes the client's evidence, not the already-mined node's history.
This distinction avoids changing §3's body-based definition into a rule about
whether a particular wallet downloaded a proof. A reorg invalidates active
inclusion even if the old path still recomputes the old header's root.

## Seeds and status views for #67

[M] Two scenario files, twenty declared steps, all measured agree [X]; the aggregate record below binds their receipts:

| id | [M] primary + variant steps | mechanism |
|---|---:|---|
| [2026-10-12-mempool-presence-terminal](2026-10-12-mempool-presence-terminal.md) | 4 + 6 = 10 | A presence latches the door; a conflicting active spend, expiry or invalidation changes the status. |
| [2026-10-12-bumpless-beef-stored-proof](2026-10-12-bumpless-beef-stored-proof.md) | 6 + 4 = 10 | A stored stub supplies no inclusion; the wallet refuses its assembly; a checked path and then a reorg change the evidence. |

[D] The table lives here beside its witnesses, leaving DESIGN-S6 §3's
definition untouched. #67 turns it into `BsvChain/Views/Status.lean`, cites
each client implementation at its pin and replays its cells. The local audit
provenance is in the [intake record](../../docs/records/20261012-163524-intake-22-s6.md).
Aliases `presence` and `proof` below mean the complete scenario ids above.

[D] A word shared by different statuses cannot recover a unique status, but
that alone does not refute a function **from** Status to a coarse vocabulary.
The `no function` rows also name equal-status/different-word witnesses or the
extra state they need. These are trace witnesses, not global equivalence
theorems or claims that all coarsenings must be injective.

| vocabulary / word | Status values or verdict [D] | witness scenario and step [D]; node observations recorded per step |
|---|---|---|
| Courier `Present` / `confirmed:false` | Fresh accepted-pool observation in this fixture means `inMempool`; a cached `Present` has no inverse and no function of current Status alone. | `presence` p2 / e1: `inMempool` / `unknown` under the latched presence; e1 / e2: equal `unknown`, cached Present / fresh absent. |
| Door `Accepted`, `networkSeen:true`, felt `seen` | **no function**: admission/latch history is extra state; neither terminality nor active inclusion follows. | `presence` p2 / p3: same word under `inMempool` / `conflictedByMinedSpend`; p1 / p2: equal `inMempool`, pending / Accepted; p3 / p4: equal conflict, Accepted / refused. |
| Broadcaster `REJECTED`, `DOUBLE_SPEND_ATTEMPTED` | **no function**: remote hints are neither the selected node's receipt nor its conflict journal. | `presence` p2 / p3: hints persist under pool / mined conflict; p1 / p2: equal pool status before / after hint delivery. |
| Courier or broadcaster `MINED`, positive claimed height | **no function** without current header/path evidence; a stale claim can accompany `inMempool` or `onStaleBranch`. | `presence` r1 / r2 / r3: claimed MINED under active / pool / stale; `presence` p2 / r2: equal pool status with Present / cached MINED. |
| Tracker's checked `mined(h)` / application's `confirmed` | In a synchronized evidence projection, `minedActive h`; **no function of node Status alone** for an asynchronous tracker. | `proof` b2 / b5: equal `minedActive 102`, evidence `unknown` / checked `minedActive 102`; q1 withdraws confirmed after invalidation. |
| Wallet stored `completed` / `proven` | **no function**: stored bytes and checked inclusion differ, and a stored latch survives a reorg. | `proof` b3 / q1 / q2: stored proven under active / pool / stale; b2 / b3: equal active, unstored / stored. |
| Wallet `refused`, `InputNamesNoElement` | **no function**: a body/ancestry refusal is not `rejected code reason`. | `proof` b4 / b6: `U` remains `unknown`, wallet refused / credited; `T` remains at the same active height. |
| Application `POT_INTERNALIZED`, `Paid` | **no function**: receipt and ledger state are extra inputs; a legacy latch can outlive refusal. | `proof` b4 / b6: same Paid with refused / credited receipt; `U` is `unknown` in both. b3 / b4 changes the latch with node status unchanged. |
| Application credit `REFUSED`, `PARKED`, `LANDED` | **no function**: wallet receipt and retry clock determine these words. | `proof` b4 / b5 / b6: refused / parked / landed while `T` stays `minedActive 102` and `U` stays `unknown`. |
| Overlay `spent:false`, `spendingTxid:null` | **no function**: release of an index pointer is not restoration of the chain UTXO. | `presence` p3 / p4: exact active spender unchanged, released / repaired pointer; `gettxout F:fund` stays null. |

[D] Application-bundle `proven` and transport `present`/`health-up` describe
other objects; they are not aliases for transaction inclusion. They require
their own evidence and are outside this table's transaction traces.

## Incident intake, the one-day route (#119)

[D] 2026-10-14, #119: every chain-level incident (one whose cause is a question about a transaction's status, its inclusion, or the chain's state, DESIGN-S6 section 8) filed on a program this spec serves becomes a scenario here within one day of its filing: a `<date>-<class>.md` file in this page's format with synthetic names only, each step `node: "pending #66"`, its `witness` naming the source issue; its id added to the runner's list (`harness/src/scenarios/mod.rs`) and to the spec projection's (`lean/Test/ChainCheck.lean`, `--scenarios`); its row in the table above, in `corpus/INDEX.md` and in DESIGN-S6 section 5.1; and its client words as rows of the status-view table with witness steps; the node column follows on the next `tools/node_scenarios.sh` run. Nothing from the private programs enters (rule 5). [M] The precedent: two incidents filed on a program this spec serves, on 2026-10-12 09:20Z and 09:37Z, entered as `2026-10-12-mempool-presence-terminal` and `2026-10-12-bumpless-beef-stored-proof` at `981c23c3` the same day (17:41Z).

## Node runner, 2026-10-13

[M] The [superseding record](../../docs/records/20261013-032121-s6-66b-regtest-s3.md) records [M] 20 realized intake steps, 20 agree, 0 diverge, 0 rpc-precheck, 0 unrealizable, 0 needs-peer and 0 pending. Each independent trace has its own node, prefix and journal. Sidecars retain all RPCs, bytes, exact pool/tip/output/status comparisons, expiry completion logs and proof checks. Client vocabulary rows remain declared local inputs, not measurements of client programs; [M] 2026-10-13: #65's theorem carries explicit hypotheses; #75's codec remains owed.

[M] 2026-10-13, lane fix-pend2: one full fresh-instance run at `352d089c` (main's runner after s6-65 and fix-65) replayed the three traces: mempool-presence [M] 10 of 10 steps realized and agree; bumpless [M] 4 realized and agree, 6 not reached by the RPC runner; orphaned-block [M] 2 realized and agree, 3 not reached. [X] Only realized steps change: their tokens cite the [fix-pend2 record](../../docs/records/20261013-162245-s6-fix-pend2-regtest-s3.md); the others keep their s6-65 tokens (the intake replay with its Lean checks and the orphaned-block receipt above). No token's verdict changed.

[X] Witnesses: [launch amendment](witnesses/s6-66-intake-launch-profile.md), [maintenance amendment](witnesses/s6-66b-maintenance-trigger.md), [single-transaction proof RPC](witnesses/s6-66b-one-transaction-proof.md). The proof boundary is an extra probe, outside the intake step counts. Historical [block empty](witnesses/s6-66-block-block-empty.md) and [missing coinbase](witnesses/s6-66-block-block-missing-coinbase.md) receipts are retained.


[M] Witness file index (separate from the intake totals):

- [`s6-66-block-block-empty.md`](witnesses/s6-66-block-block-empty.md)
- [`s6-66-block-block-missing-coinbase.md`](witnesses/s6-66-block-block-missing-coinbase.md)
- [`s6-66-intake-launch-profile.md`](witnesses/s6-66-intake-launch-profile.md)
- [`s6-66b-maintenance-trigger.md`](witnesses/s6-66b-maintenance-trigger.md)
- [`s6-66b-one-transaction-proof.md`](witnesses/s6-66b-one-transaction-proof.md)

- [`s6-66-fin-mempool-capacity-1.md`](witnesses/s6-66-fin-mempool-capacity-1.md)
- [`s6-66-mem-absurd-fee-above.md`](witnesses/s6-66-mem-absurd-fee-above.md)
- [`s6-66-mem-absurd-fee-default-rpc.md`](witnesses/s6-66-mem-absurd-fee-default-rpc.md)
- [`s6-66-mem-absurd-fee-equality.md`](witnesses/s6-66-mem-absurd-fee-equality.md)
- [`s6-66-utx-scripts-false.md`](witnesses/s6-66-utx-scripts-false.md)
- [`s6-66-utx-scripts-number-unequal.md`](witnesses/s6-66-utx-scripts-number-unequal.md)

[M] 2026-10-13: [aggregate record](../../docs/records/20261013-061601-s6-66-agg-regtest-s3.md) indexes all round witnesses and the measured intake steps.

[M] 2026-10-13, #65: [orphaned-block proof](2026-10-13-orphaned-block-proof.md)
adds [M] five declared steps. [D] The proof is fetched from a body with its
coinbase and T, then the identical stored proof is replayed after invalidation.
The node runner checks Lean verifyPath and scans all active bodies for T.
The one-leaf path remains body-derived, never a getmerkleproof result.

[M] 2026-10-14, #75: [the proof surface](2026-10-13-tsc-proof-surface.md)
adds [M] six declared steps, all measured agree [X] on a fresh instance
([record](../../docs/records/20261014-015319-s6-75-regtest-s3.md)): bodies of
1, 2, 3, 5, 6 and 8 transactions; 120 served proofs (`getmerkleproof`,
`getmerkleproof2` with every `targetType` and `includeFullTx`) through the Lean
TSC view, the binary round trip and the model of the node's branch generator;
72 `verifymerkleproof` verdicts equal to Lean's; the one-transaction block's
`-5` quoted; `format` `binary` refused with `-32602` at the pin. Views, never
rules; inclusion keeps #65's premises.

[M] 2026-10-13, #65 node replay: [orphaned-block receipt](../../docs/records/20261013-141426-s6-65-regtest-s3.md)
realizes [M] 5 steps, [M] 5 agree, [M] 0 diverge and [M] 0 pending.
[X] The identical path verifies in Lean after A is invalidated; [M] 102 active
bodies exclude T. [Intake replay](../../docs/records/20261013-141521-s6-65-intake-regtest-s3.md) realizes [M] 10 steps,
[M] 10 agree, including b5/q4 Lean checks. #75's codec remains owed.
[D] 2026-10-13, #72 (lane s6-72): [assembly excludes a low-fee transaction](2026-10-13-assembly-excludes-low-fee.md)
adds [M] four declared steps. [D] `generatetoaddress` assembles while the pool
holds T and L, L paying below `-minminingtxfee`; the runner reads the body the
node chose, writes it into the step as an observation, and judges the state
after it. A `mine` step's `transactions` is the observed body for a node
assembly and the declared body only for `"method": "submitblock"`
(`harness/README.md`, the #72 contract).
[D] 2026-10-14, #90 (lane spend-90): [conflicting spends under arrival order, concurrency
and reorg](2026-10-14-conflicting-spends-order.md) adds [M] two primary steps and two
variants (one and three steps). Each step carries a `second_oracle` object, the
Teranode column read from source through `lean/BsvChain/Teranode/Spend.lean`;
`submitConcurrent` and the `*_one_of` keys await the runner (#66). Every node
marker is `pending #66`.
[D] 2026-10-15, #92 (lane s8-92): [record lifetimes: expiry, coinbase maturity and
the locked window](2026-10-15-record-lifetimes.md) adds [M] three primary steps and two
variants (four and one steps). Each step carries a `second_oracle` object, the
Teranode column read from source through `lean/BsvChain/Teranode/Lifetimes.lean`, with
`records` (the marks of the named records); step `s3` disagrees by design (policy
expiry with no Teranode counterpart), a non-judging row. Every node marker is
`pending #66`.

[D] 2026-10-15, #84 (lane events-84): [the event vocabulary through a reorg and a double spend](2026-10-15-events-reorg-doublespend.md)
adds [M] twelve declared steps after the common prefix, which is judged as a thirteenth (`s0`). Each step declares its machine
transitions; the runner (`run_scenarios --events`, `harness/src/scenarios/events.rs`) maps them to the messages of
`lean/BsvChain/Views/Events.lean`, and a ZMTP subscriber (`Subscriber` in `harness/src/scenarios/core.rs`) records every message of
one fresh instance of the zmq build (`BUILD_BITCOIN_ZMQ=ON`; the node of record has no notifier). A message with no mapped
transition, or a mapped message the node did not publish, is filed as a witness. The node markers follow the run's record.
[M] 2026-10-15: [the run](../../docs/records/20261015-035435-s7-84-events-s1.md) at `94e53ad8`: 13 steps, 13 agree; 936 messages recorded, 936 matched,
0 witnesses [X]; the genesis coinbase pair, sent before the subscription, is accounted by the console log.

[D] 2026-10-15, #78 (lane s7-78): [two nodes, one connection](2026-10-15-p2p-relay-two-node.md) adds [M] eight steps
on two fresh instances (B dials A once) with the reference's test peer logging on each. Each step declares its
stimuli in the relay machine's events (`lean/BsvChain/Wire/Relay.lean`) and the observations the machine must
produce; the runner (`run_scenarios --relay`, `harness/src/scenarios/relay.rs`) records observations only, and
`chaincheck --p2p <record.json>` (`lean/Test/P2PCheck.lean`) runs the machine and compares three ways (declared,
machine, node). [M] 2026-10-15: [the run](../../docs/records/20261015-125403-s7-78-p2p-machine-s1.md) at `ca3855b6`: 8 steps, 8 agree,
81 checks, 0 witnesses [X]; the node markers name it.

[D] 2026-10-15, #81 (lane s7-81): [mempool persistence across restarts](2026-10-15-persist-restart.md) adds [M] sixteen declared
steps on one instance: submissions of the kinds a load keeps and drops, then three restarts on the instance's own data directory
(`Node::restart`) with `-persistmempool` on, off and on, and a generated block between the last two. Its new action types are
`restart` (`persistmempool`, the launch clock, an optional `mempoolexpirynonfinal`), `prioritise`, `invalidateblock`, `generate`
and `stop`; its observations add `entry_times`, `fee_deltas`, `files_read` and `files_written` (the two dump files by name),
`load` (the ledger of `Persist.load`) and `counts` (the node's logged success, failed and expired counts). The projection is
`chaincheck --persist` over `lean/BsvChain/Persist.lean`; the runner is `run_scenarios --persist`
(`harness/src/scenarios/persist.rs`).
[M] 2026-10-15: [the run](../../docs/records/20261015-130103-s7-81-persist-s1.md) at `ffa3f8b1`: 16 steps, 16 agree, 0 witnesses
[X]; the node's logged counts 5, 0, 0 and 2, 0, 0 at the start with the setting, 3, 1, 1 and 1, 0, 1 at the start after the run
without it; `chaincheck --persist` GREEN on the same file.

[D] 2026-10-15, #82 (lane s7-82): [pruning on regtest](2026-10-15-prune-retention.md) declares 14 steps on six fresh
instances; the runner (`run_scenarios --prune`, `harness/src/scenarios/prune.rs`) compares every node answer, every
block's data and undo bits after each acting `pruneblockchain`, and the instance's own block files with the Lean
function `lean/BsvChain/Views/Prune.lean`, fed the node's block sizes in arrival order. Pruning is a node setting, never
consensus. [M] 2026-10-15: [the run](../../docs/records/20261015-130232-s7-82-prune-s1.md) at `8b57a775`: 14 steps, 14
agree [X].
[D] 2026-10-15, #93 (lane s8-93): [competing branches: selection, the longest-chain mark, invalidate and
reconsider](2026-10-15-competing-branch-selection.md) adds [M] seven primary steps and three variants (`v-unknown` and `v-strict` one step
each, `v-tie` two). Each step carries a `second_oracle` object, the Teranode column read from source through
`lean/BsvChain/Teranode/Chain.lean`; `c6` (reconsider a descendant of an invalidated block), `v-unknown` and
`v-tie` are the model witnesses where the columns differ. `c3`, `c4` (and so every later step), `v-strict` and `v-tie` need a peer block source on the Teranode instance
(`submitblock` is unimplemented there, `services/rpc/Server.go:211`); the runner's support is owed by #66's cut 2.
Every node marker is `pending #66`; nothing run.

## Status vocabulary witnesses, 2026-10-13

[D] `regtest-status-views` uses the common intake prefix with explicit Genesis
activation at height 100. Each independent node has its own fresh datadir.
Only the orphan witness enables a listener bound to the loopback; it records
the missing-parent request, isolated count and child retry after parent arrival.
The held witness adds funding height 102 and lockTime 103. These are selected
synthetic inputs; defaults remain the pinned regtest census. Views are never rules.

[D] Every no-function cell has two declared producer contexts with the same node
status. Client words come from predicate-checked Lean `Views.contextWords`, independently
checked in Rust against declared input records, labeled [D], and no
external producer is run. Node columns are populated from fresh RPC/P2P receipts.

- [`2026-10-13-status-view-unknown`](2026-10-13-status-view-unknown.md)
- [`2026-10-13-status-view-orphan`](2026-10-13-status-view-orphan.md)
- [`2026-10-13-status-view-inMempool`](2026-10-13-status-view-inMempool.md)
- [`2026-10-13-status-view-heldNonFinal`](2026-10-13-status-view-heldNonFinal.md)
- [`2026-10-13-status-view-minedActive`](2026-10-13-status-view-minedActive.md)
- [`2026-10-13-status-view-onStaleBranch`](2026-10-13-status-view-onStaleBranch.md)
- [`2026-10-13-status-view-conflictedByMinedSpend`](2026-10-13-status-view-conflictedByMinedSpend.md)
- [`2026-10-13-status-view-rejected`](2026-10-13-status-view-rejected.md)

[M] 2026-10-13: [status-view replay](../../docs/records/20261013-142247-s6-67-regtest-s3.md) measured [M] 8 independent scenarios, 16 steps, 16 agree, 0 diverge, 0 pending; [M] 48 historical structural cells (8 function, 40 no-function); these counts are superseded by the corrected table. Node RPC words are OBSERVED [M]; producer context words and status projections remain [D]. No producer was run.

[M] 2026-10-13: [historical fix-67 status replay](../../docs/records/20261013-161732-s6-fix-67-regtest-s3.md):
8 fresh instances, 16 steps, 16 agree, 0 diverge; 48 cells, with 11 functions
including 3 partial cells and 37 no-function cells. [X] Lean and Rust check the
explicit receipt, send intent/rejection history, failed-row recovery, HTTP option
and processing-error predicates, including incompatible contexts. [D] Stored
producer words remain separate from semantic partial outputs. External producers
were not run. Historical aggregate receipts preserve the earlier structural coverage.

[M] 2026-10-13, fix-67b: the generated table then had 13 function cells,
including 5 partial cells, and 35 no-function cells over six columns. [M] 2026-10-15,
lane status-74 (#74): a seventh column, `Teranode node`, adds 7 function cells and 1
no-function cell (20 function cells including 5 partial, 36 no-function); its witnesses
are the Teranode instance record's steps, not these scenarios, whose six cells per row stand. [D] Off-active body inclusion
supplies Arcade MINED; the exact completed input-empty node receipt supplies
Arcade REJECTED. Stored report history and reorg events stay separately qualified.
The scenario semantic_views expectations are checked against typed cell outputs.

[M/X] 2026-10-13: [fresh fix-67b replay](../../docs/records/20261013-172431-s6-fix-67b-regtest-s3.md):
8 fresh instances, 16 steps, 16 agree, 0 diverge, 0 pending; all 48 cells checked,
13 function cells including 5 partial, 35 no-function cells. Node verdict wall
[M] 30.235 s. Both repaired Arcade predicates agree at both unchanged boundaries.

[M] 2026-10-13, lane land-peer: the peer-66/fix-peer work realizes [M] 20 peer rows (17 agree, 3 scoped walls) beside main's pending-row recipes, restart and full/trimmed receipt writer. The [landing census](../../docs/records/20261013-184430-s6-66-column-s3.md) counts the three intake traces and their variant steps directly: [M] 25 steps, 25 agree, 0 diverge, 0 rpc-precheck, 0 unrealizable, 0 needs-peer, 0 pending; #67's status-view scenarios remain separately indexed above.

[D] 2026-10-15, #85 (lane rpc-85): three RPC-contract rows, the edges of
[docs/CONFORMANCE-RPC-CONTRACT.md](../../docs/CONFORMANCE-RPC-CONTRACT.md) §2:
[safe mode](2026-10-15-rpc-safe-mode.md) ([M] 5 steps), [pruning](2026-10-15-rpc-pruning.md) ([M] 11 steps) and
[mock time](2026-10-15-rpc-mock-time.md) ([M] 9 steps). Their format differs from the traces above: each step's
`action` is `{"type": "rpc", "method", "params"}` and its `expected_observations` is the node's `reply` (or a
named projection of it), not the machine's state; `initial_chain.launch` names the instance's extra settings. The
expectations are the contract's [D]; the probe of #85 observed them [X]
(`docs/records/20261015-035438-s7-85-rpc-contract-s4b.md`), and every node marker is `pending #66`: the runner
needs a launch-settings profile and an `rpc` action, owed by the lane that wires the interface.

[D] 2026-10-15, #94 (lane s8-94): [freezing an output on both nodes](2026-10-15-alert-freeze-output.md)
([M] 4 primary steps and 2 variant steps) in the #85 format above: the reference's steps are `rpc` actions
(`addToConsensusBlacklist`, `sendrawtransaction`), each step names its theorem of
`lean/BsvChain/Teranode/Alert.lean`, and a `second_oracle` object carries the Teranode column read from source
through it (the #90 format), the alert's fund in place of the RPC's. The variant (`fork_after`) ends the freeze
without ending its policy half, where the reference still refuses and Teranode admits. Every node marker is
`pending #66`: cut 2 owes the Teranode instance's alert keys and a signed alert (or the node interface's call).

[D] 2026-10-15, #79 (lane s7-79): [compact blocks between two nodes](2026-10-15-compact-blocks-two-node.md) adds [M] four
declared blocks on #78's harness (two fresh instances, B dials A once, the reference's test peer on A): the coinbase
alone, two transactions B holds, one held and one never relayed, two never relayed, each with its declared missing
set. The runner (`run_scenarios --compact`, `harness/src/scenarios/compact.rs`) records observations only;
`chaincheck --compact <record.json>` (`lean/Test/CompactCheck.lean`) runs the Lean reconstruction
(`lean/BsvChain/Wire/CompactBlocks.lean`) and compares three ways (declared, Lean, node). [M] 2026-10-15: [the
run](../../docs/records/20261015-162637-s7-79-compact-blocks-s1.md) at `6ae5669b`: 4 blocks as declared, 0 witnesses [X]; 149 checks at the lens
fixes, the declared pool counts included ([record](../../docs/records/20261015-173931-fix-s7-79-compact-lens-s1.md)). Nothing of compact blocks is consensus.
