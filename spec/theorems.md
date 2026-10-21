# The theorems, with their explainers

Every `theorem` of the Lean sources, each with its docstring (the explainer: what it says, what it assumes, why it matters) where it has one of its own; a theorem without one is listed and marked. A `[SRC]` line reads a bare line number in the module's default file (`interpreter.cpp` unless the module says otherwise) and a `:NNN` in the file the docstring last named. `lean/AxiomCheck.lean` lists the main theorems; `tools/axiom_check.py` shows each depends on Lean's three axioms only.

Each `BsvChain` theorem carries its **quantification** line (#77), read from its statement: for each of `params`, `cfg`, the oracle and `now`, whether a binder quantifies it (directly, through a context structure such as `ChainContext`, or through a predicate whose steps bind it such as `Reachable`), the statement fixes it to a constant (a network's record, the census defaults `NodeConfig.defaults`, the evaluator, a literal time), or it is not an argument of the statement. A theorem that fixes one names its general form (quantified, or free of the four inputs), or states a concrete run. The counts, and the slots this reading does not see (a default argument or a structure field's default), are on [`README.md`](README.md).

## `BsvChain.Mempool`

### `evictOrphans_length_le` (`lean/BsvChain/Mempool.lean:761`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[X] 2026-10-13: eviction never increases the retained count, regardless
of the explicit choice. Each pass only erases an index.
[SRC] src/orphan_txns.cpp:228-243 at 6504a3af.

### `evictOrphans_size_le` (`lean/BsvChain/Mempool.lean:775`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[X] 2026-10-13: enough passes to visit every original entry leave the
aggregate within the trim target for every eviction choice. Overflow implies
nonempty entries, so the modulo index erases an entry on that pass.
[SRC] src/orphan_txns.cpp:192,228-243 at 6504a3af.

### `evictOrphans_overflow_removes` (`lean/BsvChain/Mempool.lean:800`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[X] 2026-10-13: a target overflow with the full pass budget evicts a
nonempty set, witnessed by a strict decrease in count. This conclusion does
not identify a survivor; salted map order is an explicit transition input.
[SRC] src/orphan_txns.cpp:228-243 at 6504a3af.

## `BsvChain.Properties.Block`

### `headerWordBytes_length` (`lean/BsvChain/Properties/Block.lean:16`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A fixed-width word always emits its requested byte count, independent
of its value. This is the framing fact used by the round trip.
[SRC] src/serialize.h:71–91 at 6504a3af.

### `leNat_headerWordBytes` (`lean/BsvChain/Properties/Block.lean:24`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A word that fits in the requested width reads back unchanged. The width
premise excludes truncation and is discharged by each header field's type.
[SRC] src/serialize.h:71–91 at 6504a3af.

### `readLE_headerWordBytes` (`lean/BsvChain/Properties/Block.lean:38`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The existing prefix reader consumes exactly an encoded bounded word and
leaves an arbitrary following stream untouched. This ties the new encoder
to the reused transaction reader. [SRC] src/primitives/block.h:38–45 and
src/serialize.h:71–91 at 6504a3af.

### `header_encode_length` (`lean/BsvChain/Properties/Block.lean:47`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Every header encodes to the fixed frame size, [D] 80 bytes. Typed fields
give their exact widths without a well-formedness predicate on callers.
[SRC] src/primitives/block.h:26–45 at 6504a3af.

### `header_decodePrefix_encode` (`lean/BsvChain/Properties/Block.lean:53`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The codec round trip also preserves an arbitrary body suffix. Each field
is a fixed-width bit vector, so no truncation premise is needed.
[SRC] src/primitives/block.h:26–45 at 6504a3af.

### `header_codec_roundtrip` (`lean/BsvChain/Properties/Block.lean:63`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Exact-frame round trip for every typed header, following the stronger
prefix theorem. This checks the wire encoder/decoder composition, not hashes.
[SRC] src/primitives/block.h:38–45 at 6504a3af.

### `merkle_padding_three` (`lean/BsvChain/Properties/Block.lean:72`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Padding the odd terminal leaf in this shape preserves the root for every
three leaves, with no hash-injectivity assumption. It does not assert the
false generalization to an arbitrary duplicated suffix.
[SRC] src/consensus/merkle.cpp:18–50,263–281 at 6504a3af.

### `merkle_duplicate_suffix_mutated` (`lean/BsvChain/Properties/Block.lean:80`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

An actual duplicate terminal pair sets the flag, even though the preceding
theorem equates the roots. Other sibling equalities may already mark the
shorter list; no claim of an unmutated shorter tree is made.
[SRC] src/consensus/merkle.cpp:210–213,263–279 at 6504a3af.

### `subsidy_in_era` (`lean/BsvChain/Properties/Block.lean:88`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

Every position within a positive-length subsidy era pays the same amount.
Together with the eventual-zero law, this justifies summing the schedule by
eras instead of evaluating millions of identical heights.
[SRC] src/validation.cpp:2252–2262 at 6504a3af.

### `subsidy_after_schedule` (`lean/BsvChain/Properties/Block.lean:101`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

No height after the finite schedule contributes subsidy. The interval
must be positive; division by zero is outside the pinned parameter domain.
[SRC] src/validation.cpp:2253–2256 at 6504a3af.

### `subsidyScheduleTotal_eq` (`lean/BsvChain/Properties/Block.lean:110`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

For a positive halving interval the schedule's total is the interval times
the sum of the 64 era subsidies, which no longer depends on the network.
[SRC] src/validation.cpp:2252–2262 at 6504a3af.

### `subsidy_total_bound_iff` (`lean/BsvChain/Properties/Block.lean:125`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

The general form of the money bound, for ANY parameters: the schedule's
total lies strictly below `MAX_MONEY` exactly when the halving interval is at
most 210,000. A zero interval contributes no subsidy (the total is 0); above
210,000 the bound is false, so the pinned networks' intervals (210,000 on
mainnet, testnet and STN, 150 on regtest) are within it and a larger interval
is not. An arithmetic bound on permitted subsidies, not a claim about
circulating supply. [SRC] src/validation.cpp:2252–2262, src/amount.h:130 at 6504a3af.

### `subsidy_total_pinned` (`lean/BsvChain/Properties/Block.lean:159`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params` fixed to mainnet's record, regtest's record, STN's record and testnet's record; `cfg`, `oracle` and `now` are not arguments of the statement. General form: `subsidy_total_bound_iff`, quantified; this theorem is its instance.

The total schedule lies strictly below the existing money bound on each
pinned network, including STN's independent subsidy interval. This is an
arithmetic bound on permitted subsidies, not a claim about circulating supply
or the genesis output's spendability. The kernel evaluates only the finite
era sum. The general form is `subsidy_total_bound_iff`, for every network; this
theorem is its instance on the four pinned records. [SRC] src/validation.cpp:2252–2262, src/amount.h:130 and
src/chainparams.cpp:1037,1211,1333,1460 at 6504a3af.

### `coinbase_amount_bound` (`lean/BsvChain/Properties/Block.lean:173`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

Passing the reward stage bounds coinbase outputs by the height's subsidy
plus supplied fees. #64 must establish that those fees came from accepted
transactions; this theorem does not assume that unproved integration.
[SRC] src/validation.cpp:3655–3666 at 6504a3af.

### `contextual_header_timestamp_window` (`lean/BsvChain/Properties/Block.lean:185`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now`; `oracle` is not an argument of the statement.

An accepted contextual header is strictly newer than the parent median
and no later than explicit `now` plus the configured future-time constant.
No proof-of-work or block-body acceptance is inferred by this theorem.
[SRC] src/validation.cpp:5943–5959 at 6504a3af.

### `contextual_header_two_hours` (`lean/BsvChain/Properties/Block.lean:217`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `cfg` fixed to the census defaults `NodeConfig.defaults`; for every `params` and `now`; `oracle` is not an argument of the statement. General form: `contextual_header_timestamp_window`, quantified; this theorem is its instance.

At the pinned future-time constant the preceding bound is exactly two
hours, [D] 2 * 60 * 60 = 7200 seconds, for arbitrary explicit `now`. The
general form is `contextual_header_timestamp_window`, for every configuration;
this theorem is its instance at the census defaults. [SRC] src/block_index.h:28–31 at 6504a3af.

## `BsvChain.Properties.Chain`

### `runBlockTransactions_valid` (`lean/BsvChain/Properties/Chain.lean:27`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

Every successful sequential run has faithful receipts and the same body
order. The induction follows each guard and applyTx, then the recursive tail.
[SRC] src/validation.cpp:3290–3447 at 6504a3af.

### `applyTx_haveInputs` (`lean/BsvChain/Properties/Chain.lean:59`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

Accepted non-coinbase transactions have all inputs live. This exposes the
availability guard already present in the reused input validator.
[SRC] src/validation.cpp:3326–3331 at 6504a3af.

### `applications_inputs_unspent` (`lean/BsvChain/Properties/Chain.lean:70`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

Each receipt in an actual sequential run supplies the immediately preceding
view, in which every non-coinbase input is unspent. Later transactions may
spend outputs created earlier in the same block.
[SRC] src/validation.cpp:3324–3443 at 6504a3af.

### `applications_undo_identity` (`lean/BsvChain/Properties/Chain.lean:105`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

Qualified block undo identity. Induction reverses the tail, then applies
#61's map-extensional undo theorem. No prior-view snapshot is used by undo.
The no-overwrite premise is essential for coinbase outputs.
[SRC] src/processing_block_index.cpp:21–69, src/coins.cpp:560–565 and
src/undo.h:109–112 at 6504a3af.

### `connectBlock_run` (`lean/BsvChain/Properties/Chain.lean:126`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

A non-genesis successful connection exposes its actual sequential run,
published coins and retained non-coinbase vectors. The prepared context is
explicit because unresolved network data is not a node judgment.
[SRC] src/validation.cpp:3021–3117,3290–3719 at 6504a3af.

### `connected_block_inputs_unspent` (`lean/BsvChain/Properties/Chain.lean:165`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

Every non-coinbase transaction in a successful connection has all inputs
unspent in its recorded sequential view. The receipts are derived above from
the executed body order, not provided by a caller.
[SRC] src/validation.cpp:3324–3443 at 6504a3af.

### `connected_block_undo_identity` (`lean/BsvChain/Properties/Chain.lean:181`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

Successful connection followed by retained-vector reversal restores the
original map under the per-application no-overwrite condition. The following
clean-disconnect lemma connects this inverse to the status-returning API.
[SRC] src/processing_block_index.cpp:21–69 and src/coins.cpp:560–565 at 6504a3af.

### `preferred_work` (`lean/BsvChain/Properties/Chain.lean:197`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Work wins independently of the tie observations.
[SRC] src/block_index.h:1225–1274 at 6504a3af.

### `not_preferred_work` (`lean/BsvChain/Properties/Chain.lean:206`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Refusing a candidate never selects less work.
[SRC] src/block_index.h:1225–1274 at 6504a3af.

### `bestCandidate_maximal` (`lean/BsvChain/Properties/Chain.lean:214`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The chosen index is a member, and bounds the work of every candidate.
The proof follows the executable maximum, retaining equal-work possibilities.
[SRC] src/validation.cpp:4413–4494 at 6504a3af.

### `activateBestChain_complete` (`lean/BsvChain/Properties/Chain.lean:252`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

A completed automatic activation passes its executable maximal-selection
postcondition. Interruptions, explicit invalidation and setting changes are
not silently called completed selections.
[SRC] src/validation.cpp:4913–5130 at 6504a3af.

### `activation_maximal_work` (`lean/BsvChain/Properties/Chain.lean:266`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

At a completed nonempty selection, the active identifier names an eligible
candidate of maximal accumulated work, including its available valid ancestry.
[SRC] src/validation.cpp:4413–4494,4913–5130 at 6504a3af.

### `selection_strict_growth` (`lean/BsvChain/Properties/Chain.lean:281`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Strict growth needs unequal selected work; an equal-work rank change cannot
prove it. [SRC] src/block_index.h:1225–1274 at 6504a3af.

### `connection_preserves_members` (`lean/BsvChain/Properties/Chain.lean:289`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Connecting preserves every existing active-chain member. The executable
event operation is the one used by connectTip.
[SRC] src/validation.cpp:4391 at 6504a3af.

### `removal_requires_disconnect` (`lean/BsvChain/Properties/Chain.lean:296`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Any lost active block requires a disconnect event, with its cause named.
This replaces the issue's unqualified more-work-only removal claim.
[SRC] src/validation.cpp:4117,4391,4526–4553,5203–5330 at 6504a3af.

### `removal_causes` (`lean/BsvChain/Properties/Chain.lean:306`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The removal causes are exhaustive, including explicit disconnect, invalidate,
soft rejection and freeze changes separately from a reorg.
[SRC] src/validation.cpp:4065–4133,4526–4553,4603–4612,5203–5330 at 6504a3af.

### `disconnectTransaction_clean` (`lean/BsvChain/Properties/Chain.lean:331`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

A clean one-transaction undo is precisely the spent-vector inverse on a
well-formed retained vector. Status checks cannot invent a prior coin.
[SRC] src/processing_block_index.cpp:30–69 at 6504a3af.

### `disconnectTransactions_clean` (`lean/BsvChain/Properties/Chain.lean:352`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

Clean block undo equals the reverse retained-vector computation. A clean
aggregate requires every transaction undo to be clean; failure never publishes.
[SRC] src/processing_block_index.cpp:21–76 at 6504a3af.

### `undoPairs_applications` (`lean/BsvChain/Properties/Chain.lean:384`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

A receipt list projected to ordinary vectors has the same reverse action.
[SRC] src/processing_block_index.cpp:21–69 at 6504a3af.

### `blockUndoPairs_applications` (`lean/BsvChain/Properties/Chain.lean:394`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The source's vector layout equals the receipt projection when its coinbase
vector is empty. No earlier UTXO views occur in this equality.
[SRC] src/undo.h:109–112 and src/processing_block_index.cpp:51–59 at 6504a3af.

### `undoPairs_congr` (`lean/BsvChain/Properties/Chain.lean:413`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

Erasing the positional coinbase marker preserves the inverse's input.
[SRC] src/processing_block_index.cpp:21–69 at 6504a3af.

### `connect_disconnect_identity` (`lean/BsvChain/Properties/Chain.lean:431`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

The actual clean DisconnectTip API restores the original set after a
successful non-genesis connection, given a well-formed retained undo and no
live overwrite. This combines executable connection, vector layout, status
checks and #61's map-extensional inverse, with no domain axiom.
[SRC] src/validation.cpp:4065–4117, src/processing_block_index.cpp:9–77,
src/coins.cpp:560–565 and src/undo.h:109–112 at 6504a3af.

### `activateBestChain_maximal_work` (`lean/BsvChain/Properties/Chain.lean:482`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

The maximal-work law directly for the public activation transition. It is
conditional on completion, not merely on the source's boolean return.
[SRC] src/validation.cpp:4413–4494,4913–5130 at 6504a3af.

### `transaction_removal_requires_disconnect` (`lean/BsvChain/Properties/Chain.lean:499`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A transaction can lose active-body membership at an active-chain event only
through disconnection. Connection preserves all old bodies and memberships;
reorg, explicit disconnect, invalidate, soft rejection and freeze changes are
the named causes in removal_causes, not an unqualified more-work promise.
[SRC] src/validation.cpp:4117,4391,4526–4553,5203–5330 at 6504a3af.

### `transaction_removal_causes` (`lean/BsvChain/Properties/Chain.lean:515`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Named removal laws cover explicit disconnect, invalidation and settings as
well as reorg. Work growth needs its own eligibility hypotheses.
[SRC] src/validation.cpp:4065–4133,4526–4553,4603–4612,5203–5330 at 6504a3af.

### `execution_quiet` (`lean/BsvChain/Properties/Chain.lean:544`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

An unchanged active projection executes an empty trace.
[SRC] src/validation.cpp:4065–4117 at 6504a3af.

### `execution_trans` (`lean/BsvChain/Properties/Chain.lean:551`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Concatenation composes actual traces and their cause restrictions.
[SRC] src/validation.cpp:4603–4767 at 6504a3af.

### `execution_emit` (`lean/BsvChain/Properties/Chain.lean:564`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Emission records precisely the event used to mutate the active chain.
[SRC] src/validation.cpp:4117,4391 at 6504a3af.

### `indexCore_choice` (`lean/BsvChain/Properties/Chain.lean:573`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Branches that preserve index data also preserve it under a boolean choice.
[SRC] src/validation.cpp:4453–4475,5528–5562 at 6504a3af.

### `map_indexCore` (`lean/BsvChain/Properties/Chain.lean:580`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Mapping index edits preserves their ordered immutable projection when each
edit preserves it. [SRC] src/validation.cpp:5528–5562 at 6504a3af.

### `modify_core` (`lean/BsvChain/Properties/Chain.lean:589`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Metadata modification keeps the ordered immutable index projection.
[SRC] src/block_index.h:508–514 and src/validation.cpp:5528–5562 at 6504a3af.

### `insertCandidate_core` (`lean/BsvChain/Properties/Chain.lean:598`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Candidate insertion changes no retained index data.
[SRC] src/validation.cpp:5705–5708 at 6504a3af.

### `restoreCandidates_execution` (`lean/BsvChain/Properties/Chain.lean:605`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Explicit rewind restores the candidate set without rewriting bodies/work.
[SRC] src/validation.cpp:5294–5303 at 6504a3af.

### `markInvalid_core` (`lean/BsvChain/Properties/Chain.lean:621`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Invalid marking changes failure metadata and candidate membership only.
[SRC] src/validation.cpp:4453–4475,5230–5289 at 6504a3af.

### `propagateSoftSettings_core` (`lean/BsvChain/Properties/Chain.lean:631`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Soft-count propagation preserves immutable data on every finite pass.
[SRC] src/block_index.h:542–580,1131–1146 at 6504a3af.

### `freezeBlockIndex_core` (`lean/BsvChain/Properties/Chain.lean:644`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Effective freeze marking changes only setting metadata.
[SRC] src/validation.cpp:3402–3407 at 6504a3af.

### `pruneCandidates_execution` (`lean/BsvChain/Properties/Chain.lean:652`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Pruning leaves active membership, event history and retained bodies intact.
[SRC] src/validation.cpp:4498–4523 at 6504a3af.

### `settleReorg_execution` (`lean/BsvChain/Properties/Chain.lean:661`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

Pool settlement cannot alter chain membership, bodies or accumulated work.
[SRC] src/txmempool.cpp:2330–2485 at 6504a3af.

### `connectTip_execution` (`lean/BsvChain/Properties/Chain.lean:669`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

Successful connection preserves bodies/work and records only connection.
[SRC] src/validation.cpp:4345–4404 at 6504a3af.

### `disconnectTip_execution` (`lean/BsvChain/Properties/Chain.lean:691`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (through `ChainContext`); `oracle` is not an argument of the statement.

Every clean disconnection emits its caller's cause; failed undo is quiet.
[SRC] src/validation.cpp:4065–4133 at 6504a3af.

### `findMostWorkLoop_execution` (`lean/BsvChain/Properties/Chain.lean:718`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Candidate search only changes metadata and candidate/unlinked membership.
[SRC] src/validation.cpp:4413–4494 at 6504a3af.

### `disconnectToFork_execution` (`lean/BsvChain/Properties/Chain.lean:739`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (through `ChainContext`); `oracle` is not an argument of the statement.

The fork walk composes clean disconnections with their supplied cause.
[SRC] src/validation.cpp:4603–4616 at 6504a3af.

### `disconnectExcludedTips_execution` (`lean/BsvChain/Properties/Chain.lean:755`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (through `ChainContext`); `oracle` is not an argument of the statement.

Excluded-tip cleanup emits the effective setting responsible at each step.
[SRC] src/validation.cpp:4526–4553,5203–5225 at 6504a3af.

### `connectRun_execution` (`lean/BsvChain/Properties/Chain.lean:781`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

A connection run preserves bodies/work and composes its actual events;
failure metadata itself removes no active membership.
[SRC] src/validation.cpp:4692–4754 at 6504a3af.

### `connectBatches_execution` (`lean/BsvChain/Properties/Chain.lean:821`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

Every batch retains the trace and immutable-data invariant of its input.
[SRC] src/validation.cpp:4674–4767 at 6504a3af.

### `activationStep_execution` (`lean/BsvChain/Properties/Chain.lean:847`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

One activation step records only automatic causes and preserves bodies/work.
[SRC] src/validation.cpp:4561–4800 at 6504a3af.

### `activeExclusion_cause` (`lean/BsvChain/Properties/Chain.lean:872`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The exclusion classifier names the effective setting behind the rewind.
[SRC] src/validation.cpp:4526–4553,5203–5225 at 6504a3af.

### `activateLoop_execution` (`lean/BsvChain/Properties/Chain.lean:883`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

The automatic loop composes actual event traces through retries, batches
and failed undo, retaining all bodies and work. [SRC]
src/validation.cpp:4413–4800,4913–5130 at 6504a3af.

### `activateBestChain_execution` (`lean/BsvChain/Properties/Chain.lean:909`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

Public automatic activation executes the recorded trace with automatic
causes, on both completed and interrupted/error outcomes.
[SRC] src/validation.cpp:4913–5130 at 6504a3af.

### `fold_treeCore` (`lean/BsvChain/Properties/Chain.lean:919`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Folding metadata-only edits preserves the immutable index projection.
[SRC] src/validation.cpp:5234–5289,5294–5303 at 6504a3af.

### `invalidateBlock_execution` (`lean/BsvChain/Properties/Chain.lean:928`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

Invalidation composes marked-index preservation, its own rewind cause,
setting cleanup, and automatic reactivation. Failed undo retains the trace.
[SRC] src/validation.cpp:5230–5330 at 6504a3af.

### `setSoftRejection_execution` (`lean/BsvChain/Properties/Chain.lean:972`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

Soft-rejection metadata preserves bodies/work before its automatic trace.
[SRC] src/validation.cpp:5203–5225 and src/rpc/blockchain.cpp:2820–2892 at 6504a3af.

### `setSoftFreeze_execution` (`lean/BsvChain/Properties/Chain.lean:985`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

Freeze metadata preserves bodies/work before its distinct automatic trace.
[SRC] src/validation.cpp:4526–4553 and src/block_index.h:542–580 at 6504a3af.

### `treeCore_lookup` (`lean/BsvChain/Properties/Chain.lean:998`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Equal index projections give equal lookup projections, including bodies and
work. This does not assume unique hashes or hash injectivity.
[SRC] src/validation.cpp:4345–4404,4498–4523 at 6504a3af.

### `execution_bodies` (`lean/BsvChain/Properties/Chain.lean:1006`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Retained bodies are identical at every hash across an executed transition.
[SRC] src/validation.cpp:4065–4133,4345–4404,5230–5330 at 6504a3af.

### `execution_membership` (`lean/BsvChain/Properties/Chain.lean:1014`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Body preservation transports membership at any fixed active projection.
[SRC] src/validation.cpp:4117,4391 at 6504a3af.

### `trace_transaction_removal` (`lean/BsvChain/Properties/Chain.lean:1022`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A loss along a finite actual trace identifies a earlier and the disconnect
that removes membership at that step, before any later reconnect.
[SRC] src/validation.cpp:4117,4391,4603–4767 at 6504a3af.

### `execution_removal` (`lean/BsvChain/Properties/Chain.lean:1052`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The executor trace and preserved bodies yield a concrete removing step.
[SRC] src/validation.cpp:4117,4391,4526–4553,4603–4767,5203–5330 at 6504a3af.

### `connectTip_preserves_transaction` (`lean/BsvChain/Properties/Chain.lean:1067`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

Successful connectTip preserves active transaction membership, including
old bodies while undo/completion metadata changes.
[SRC] src/validation.cpp:4345–4404 at 6504a3af.

### `disconnectTip_removal` (`lean/BsvChain/Properties/Chain.lean:1080`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (through `ChainContext`); `oracle` is not an argument of the statement.

Explicit disconnectTip loss is assigned precisely its supplied cause.
[SRC] src/validation.cpp:4065–4133 at 6504a3af.

### `activateBestChain_removal` (`lean/BsvChain/Properties/Chain.lean:1090`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

Public automatic activation loss names its actual reorg/setting event.
[SRC] src/validation.cpp:4526–4800,4913–5130 at 6504a3af.

### `invalidateBlock_removal` (`lean/BsvChain/Properties/Chain.lean:1102`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

Invalidation has its own executed removal law, including reactivation's
separate automatic causes. [SRC] src/validation.cpp:5230–5330 at 6504a3af.

### `setSoftRejection_removal` (`lean/BsvChain/Properties/Chain.lean:1115`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

A soft-rejection change loses inclusion only on its executed disconnect
trace, preserving bodies across setting propagation and reactivation.
[SRC] src/validation.cpp:5203–5225 and src/rpc/blockchain.cpp:2820–2892 at 6504a3af.

### `setSoftFreeze_removal` (`lean/BsvChain/Properties/Chain.lean:1127`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

A freeze change has a separate executed removal law with retained bodies
and the cause at the actual removing step.
[SRC] src/validation.cpp:4526–4553 and src/block_index.h:542–580 at 6504a3af.

### `activateBestChain_work_complete` (`lean/BsvChain/Properties/Chain.lean:1146`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

Public completion verifies work coverage even for pruned retained indices.
[SRC] src/validation.cpp:4498–4523,4755–4767,4913–5130 at 6504a3af.

### `activation_work_nondecreasing` (`lean/BsvChain/Properties/Chain.lean:1158`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

Before/after nondecrease for public completed activation: the old active
index is initially eligible, stays available, and its eligibility settings do
not change. The executed trace proves retained work; the work certificate
covers the old tip even after candidate pruning. No final candidate-list
membership of the old index is assumed.
[SRC] src/validation.cpp:4413–4523,4755–4767,4913–5130 at 6504a3af.

### `activation_work_strict_growth` (`lean/BsvChain/Properties/Chain.lean:1190`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

Strict growth is the same public transition law with unequal selected
work; equal-work completion/sequence/rank changes do not satisfy that premise.
[SRC] src/block_index.h:1225–1274 and src/validation.cpp:4755–4767 at 6504a3af.

## `BsvChain.Properties.CompactBlocks`

### `sipHash24_empty_vector` (`lean/BsvChain/Properties/CompactBlocks.lean:30`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: SipHash-2-4 of the empty string under the key 00..0f is
the vector of src/test/hash_tests.cpp:62-63,87-88 at 6504a3af (the SipHash
paper's). A view, never a rule.

### `sipHash24_uint256_vector` (`lean/BsvChain/Properties/CompactBlocks.lean:37`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: SipHash-2-4 of the 32 bytes 00..1f under the key 00..0f
is the vector `SipHashUint256` meets at src/test/hash_tests.cpp:111-115 at
6504a3af (the 32-byte form the short id takes). A view, never a rule.

### `shortIdOf_lt` (`lean/BsvChain/Properties/CompactBlocks.lean:44`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a short id fits its six bytes (src/blockencodings.cpp:81
at 6504a3af). A view, never a rule.

### `PrefilledTx.read_encode` (`lean/BsvChain/Properties/CompactBlocks.lean:51`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a prefilled transaction with a 32-bit index and a
well-formed transaction reads back. [SRC] src/blockencodings.h:131-140 at
6504a3af.

### `CompactBlock.decode_encode` (`lean/BsvChain/Properties/CompactBlocks.lean:68`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE `cmpctblock` ROUND TRIP: a well-formed message reads
back from its writer's bytes. [SRC] src/blockencodings.h:188-223 at
6504a3af. A view, never a rule.

### `CompactBlock.ofBlock_wellFormed` (`lean/BsvChain/Properties/CompactBlocks.lean:86`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the sender's message for a block of well-formed
transactions is well formed (its nonce a 64-bit draw). [SRC]
src/blockencodings.cpp:18-32 at 6504a3af.

### `diffIndices_length` (`lean/BsvChain/Properties/CompactBlocks.lean:113`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the differential writer keeps the count.

### `diffIndices_bound` (`lean/BsvChain/Properties/CompactBlocks.lean:120`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: each difference of increasing indices fits 32 bits.

### `undiffIndices_diffIndices` (`lean/BsvChain/Properties/CompactBlocks.lean:134`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the reader undoes the writer's differences.
[SRC] src/blockencodings.h:65-79 at 6504a3af.

### `readIndex_compactSize` (`lean/BsvChain/Properties/CompactBlocks.lean:147`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: one differential index within 32 bits reads back.

### `BlockTxnRequest.decode_encode` (`lean/BsvChain/Properties/CompactBlocks.lean:154`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE `getblocktxn` ROUND TRIP: a 32-byte hash and strictly
increasing indices below 0xffffffff read back from the writer's bytes.
[SRC] src/blockencodings.h:36-82 at 6504a3af. A view, never a rule.

### `BlockTxns.decode_encode` (`lean/BsvChain/Properties/CompactBlocks.lean:170`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE `blocktxn` ROUND TRIP: a 32-byte hash and
well-formed transactions read back. [SRC] src/blockencodings.h:84-115 at
6504a3af. A view, never a rule.

### `SendCmpct.decode_encode` (`lean/BsvChain/Properties/CompactBlocks.lean:184`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE `sendcmpct` ROUND TRIP. [SRC]
src/net/net_processing.cpp:1978-1981,2430-2432 at 6504a3af. A view, never a rule.

### `emptySlotsFrom_replicate` (`lean/BsvChain/Properties/CompactBlocks.lean:201`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the empty positions of a run of empty positions.

### `lookup_zip_range'_of_get` (`lean/BsvChain/Properties/CompactBlocks.lean:208`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a short id at position `k` of a list of distinct ones is
found at `j0 + k`.

### `lookup_zip_range'_none` (`lean/BsvChain/Properties/CompactBlocks.lean:229`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a short id outside the list is found nowhere.

### `target_congr` (`lean/BsvChain/Properties/CompactBlocks.lean:246`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the state depends on `S` only through the block's transactions.

### `map_set_eq` (`lean/BsvChain/Properties/CompactBlocks.lean:259`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: one position of a mapped list replaced.

### `countP_insert` (`lean/BsvChain/Properties/CompactBlocks.lean:280`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: adding a new block transaction to `S` adds one match.

### `nodup_getElem?_inj` (`lean/BsvChain/Properties/CompactBlocks.lean:300`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a list without repeats holds each element at one index.

### `poolStep_target` (`lean/BsvChain/Properties/CompactBlocks.lean:315`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a pool transaction not matched before moves the state
from `S` to `tx :: S`. [SRC] src/blockencodings.cpp:173-191 at 6504a3af.

### `extraStep_target` (`lean/BsvChain/Properties/CompactBlocks.lean:346`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: an extra transaction moves the state from `S` to
`tx :: S` (a position already holding the same transaction is left as it
is). [SRC] src/blockencodings.cpp:201-226 at 6504a3af.

### `all_of_count` (`lean/BsvChain/Properties/CompactBlocks.lean:396`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a full count means every block transaction is matched.

### `run_target` (`lean/BsvChain/Properties/CompactBlocks.lean:403`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the scan with the early exit ends in the state of every
candidate seen. [SRC] src/blockencodings.cpp:192-197,228-233 at 6504a3af.

### `initData_ofBlock` (`lean/BsvChain/Properties/CompactBlocks.lean:429`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE RECONSTRUCTION THEOREM, its `InitData` half. For the
message a sender builds from a block (`ofBlock`: the coinbase prefilled, a
short id for each other transaction) and a receiver whose pool holds
distinct transactions, when the block's short ids are distinct and no
candidate transaction (pool or extra) shares a short id with a block
transaction other than itself, `InitData` yields the block's header and,
at every position, exactly the block's transaction if the receiver holds it
and nothing otherwise. Premises in plain words: a non-null header and
coinbase, a count the block size allows, the bucket bound not exceeded (`crowded` false, its default: the C++ table's
bucket of more than 12 short ids, src/blockencodings.cpp:157-160, fails the
message whatever the ids), the no-collision condition (the
collision case is `initData_ofBlock_duplicate` and the witnesses below).
[SRC] src/blockencodings.cpp:18-32,84-242 at 6504a3af; BIP152 lines 128,141.

### `mem_emptySlotsFrom` (`lean/BsvChain/Properties/CompactBlocks.lean:527`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the empty positions of a list from `j` are the positions
`j + i` of its empty entries.

### `emptySlotsFrom_increasing` (`lean/BsvChain/Properties/CompactBlocks.lean:555`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the empty positions come in increasing order from `j`.

### `missing_ofBlock` (`lean/BsvChain/Properties/CompactBlocks.lean:566`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE RECONSTRUCTION THEOREM, the missing set. Under
`initData_ofBlock`'s premises the positions the receiver asks for with
`getblocktxn` are exactly the positions of the block's transactions it holds
in neither its pool nor its extra transactions, and nothing else; the
coinbase is never asked for; they come in increasing order, so the request
reads back (`BlockTxnRequest.decode_encode`) for a block of fewer than
0xffffffff transactions. [SRC] src/blockencodings.cpp:244-252 and
src/net/net_processing.cpp:3919-3935 at 6504a3af. A view, never a rule.

### `filterMap_emptySlotsFrom` (`lean/BsvChain/Properties/CompactBlocks.lean:595`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the transactions at the empty positions of a mapped
list, read from the block, are the ones the map left out, in order.

### `fillTxs_map` (`lean/BsvChain/Properties/CompactBlocks.lean:614`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: filling a mapped list with the entries it left out gives
the list back. [SRC] src/blockencodings.cpp:267-278 at 6504a3af.

### `fillBlock_ofBlock` (`lean/BsvChain/Properties/CompactBlocks.lean:625`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE RECONSTRUCTION THEOREM, the block. Under
`initData_ofBlock`'s premises, `FillBlock` given the block's transactions at
the requested positions, in order (what `blocktxn` carries), yields exactly
the announced block when the reference's `CheckBlock` accepts it, and
otherwise its verdict: FAILED for a failure that may be corruption,
CHECKBLOCK_FAILED for any other. Premises in plain words: those of
`initData_ofBlock` (which gives `p`), and a non-null header.
[SRC] src/blockencodings.cpp:254-316 at 6504a3af. A view, never a rule.

### `compact_reconstruction` (`lean/BsvChain/Properties/CompactBlocks.lean:659`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE RECONSTRUCTION THEOREM (#79), whole. For the message
a sender builds from a block and a receiver holding distinct pool
transactions, with no short id shared by two different candidate and block
transactions: reconstruction names exactly the missing set (the positions of
the block's transactions the receiver lacks, and nothing else, in
increasing order), and with the block's transactions at those positions
yields exactly the announced block, or the reference's `CheckBlock` verdict
on it. Premises in plain words: a non-null header and coinbase, a count the block size allows, the
bucket bound not exceeded (`crowded` false, its default: the C++ table's
bucket of more than 12 short ids, src/blockencodings.cpp:157-160, fails the
message whatever the ids), the no-collision condition.
[SRC] src/blockencodings.cpp:18-32,84-316 at 6504a3af; BIP152 lines
100-104,128,141. A view, never a rule.

### `initData_ofBlock_duplicate` (`lean/BsvChain/Properties/CompactBlocks.lean:701`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: two equal short ids in the message fail it: `InitData`
is FAILED ("Short ID collision", src/blockencodings.cpp:163-169 at
6504a3af), and the receiver asks for the whole block with no score
(`answerOf`, src/net/net_processing.cpp:3911-3917; BIP152 line 142). A
view, never a rule.

### `double_match_requested` (`lean/BsvChain/Properties/CompactBlocks.lean:732`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a witness of two pool transactions on one short id (a
toy short-id function, every transaction mapping to 7, a message of two
short ids): the position both match is emptied and stays matched, so it is
asked for with `getblocktxn` ("just request it",
src/blockencodings.cpp:181-190 at 6504a3af). A view, never a rule.

### `early_exit_places_first` (`lean/BsvChain/Properties/CompactBlocks.lean:744`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a witness of the early exit's risk (the toy short-id
function again, one short id): the scan stops at the count, so a pool
transaction that shares the short id with the block's (here `t1`, met
before the block's own `t2`) is placed and the collision is never seen
(src/blockencodings.cpp:192-197 at 6504a3af: "worth the extra risk"). Only
`FillBlock`'s `CheckBlock` then stands between it and the block:
`fillBlock_ok_checked`. A view, never a rule.

### `fillBlock_ok_checked` (`lean/BsvChain/Properties/CompactBlocks.lean:757`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: whatever the pool and the collisions, a block
`FillBlock` returns has the announced header and passes the reference's
`CheckBlock`: a body whose merkle root differs from the header's, or whose
tree is mutated, is refused there with the corruption mark, so FAILED, and
the receiver asks for the whole block (src/blockencodings.cpp:288-299,
src/validation.cpp:5749-5785 at 6504a3af). A view, never a rule.

## `BsvChain.Properties.Depth`

### `scriptChecks_no_assumed_valid` (`lean/BsvChain/Properties/Depth.lean:22`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

[M] 2026-10-14, #73 (the decision with no assumed-valid hash). With the
assumed-valid setting zero, the decision is to run the scripts, for every
tree, every best header and every block. Premise in plain words: the node was
launched with `-assumevalid=0`, or on a network whose compiled value is zero
(regtest, STN) with no override.
[SRC] src/validation.cpp:3482-3483 at 6504a3af.

### `scriptChecks_unknown_assumed_valid` (`lean/BsvChain/Properties/Depth.lean:33`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

[M] 2026-10-14, #73 (the assumed hash names no block of the index). When
the configured hash is not a block of the header tree, the decision is to run
the scripts. Premise in plain words: the lookup of the hash in the index finds
nothing, as on a node that has not yet received that header.
[SRC] src/validation.cpp:3491 at 6504a3af.

### `scriptChecks_skip_conjuncts` (`lean/BsvChain/Properties/Depth.lean:46`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

[M] 2026-10-14, #73 (what a skip needed). If the decision is to skip the
scripts of a block, then every conjunct of the reference held: a hash is
configured; it is a block of the index; the connecting block is on that
block's chain and on the best header's chain; the best header's work reaches
the floor; and the proof-equivalent time from the block to the best header
exceeds the two-week setting. Premise in plain words: the decision returned
`false`.
[SRC] src/validation.cpp:3482-3518 at 6504a3af.

### `scriptChecks_off_assumed_chain` (`lean/BsvChain/Properties/Depth.lean:84`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

[M] 2026-10-14, #73 (the second theorem: a block off the assumed chain is
never skipped). If the connecting block is not on the chain of the configured
block (it is no ancestor of the assumed-valid block, nor that block itself),
the decision is to run its scripts, whatever the best header, the work floor
and the burial. Premise in plain words: for the index entry the configured
hash names, the ancestor of that entry at the connecting block's height is not
the connecting block.
[SRC] src/validation.cpp:3494 at 6504a3af.

### `saturateInt63_nonneg` (`lean/BsvChain/Properties/Depth.lean:103`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-14: the saturated quotient is never negative.
[SRC] src/block_index.cpp:146-149 at 6504a3af.

### `blockProofEquivalentTime_nonpos` (`lean/BsvChain/Properties/Depth.lean:109`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-14: proof-equivalent time toward a block of no more work is
never positive. [SRC] src/block_index.cpp:130-150 at 6504a3af.

### `scriptChecks_unburied` (`lean/BsvChain/Properties/Depth.lean:124`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

[M] 2026-10-14, #73 (burial needs strictly more work). A skip is never
decided for the best header itself or for a block with at least the best
header's work: the proof-equivalent time is then not positive, and the setting
is not negative. Premise in plain words: the connecting block's accumulated
work is at least the best header's.
[SRC] src/block_index.cpp:130-150 and src/validation.cpp:3511-3514
at 6504a3af.

### `withValidationDepth_wired` (`lean/BsvChain/Properties/Depth.lean:159`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (through `ChainContext`); `oracle` is not an argument of the statement.

[M] 2026-10-14, #73 (the hook is filled). The context built by
`withValidationDepth` uses the depth decision on every connection.
[SRC] src/validation.cpp:3482-3518 at 6504a3af.

### `withValidationDepth_others` (`lean/BsvChain/Properties/Depth.lean:166`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (through `ChainContext`); `oracle` is not an argument of the statement.

[M] 2026-10-14, #73 (the other decisions are untouched). Filling the depth
decision changes neither the BIP30 gate nor the execution schedule.
[SRC] src/validation.cpp:3070-3117,3421-3430 at 6504a3af.

### `s6_no_assumed_valid_checks_scripts` (`lean/BsvChain/Properties/Depth.lean:175`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (through `ChainContext`); `oracle` is not an argument of the statement.

[M] 2026-10-14, #73. In the model, `DepthWired ctx` (`hw`) and
`assumeValid = 0` or absence of that hash from the current tree (`h`) imply
`checkScripts = true` for the supplied state, connecting index and target.
`withValidationDepth_wired` proves `hw` for the explicitly transformed context.
This is a conditional connection statement; `connectBlock_scripts_judged`
describes successful model connections under its additional premises.
[SRC] src/validation.cpp:3482-3491 at 6504a3af.

### `s6_skip_only_under_assumed_valid` (`lean/BsvChain/Properties/Depth.lean:191`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (through `ChainContext`); `oracle` is not an argument of the statement.

[M] 2026-10-14, #73 (the second theorem at the connection). On a wired
node, a connection that skips the scripts is the connection of a block on the
chain of the configured assumed-valid block: never of a block off that chain.
Premises in plain words: the context is wired (`hw`) and this connection was
made with `checkScripts = false` (`h`).
[SRC] src/validation.cpp:3491-3494 at 6504a3af.

### `s6_no_assumed_valid_context` (`lean/BsvChain/Properties/Depth.lean:205`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (through `ChainContext`); `oracle` is not an argument of the statement.

[M] 2026-10-14, #73 (the whole machine under `-assumevalid=0`). A wired
context with the setting zero IS the context that forces `checkScripts` on:
the two are equal, so every transition taken under it (activation,
invalidation, reconsideration, the soft settings) is the transition that
judges scripts on each of its connections. Premises in plain words: the
context is wired (`hw`) and the setting is zero (`h`).
[SRC] src/validation.cpp:3482-3483 at 6504a3af.

### `runBlockTransactions_calls` (`lean/BsvChain/Properties/Depth.lean:230`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

[D] 2026-10-14: the queued calls of a run are, in body order, the oracle
keys of each transaction in the view immediately before it, when the scripts
are on and queued; no call is collected otherwise.
[SRC] src/validation.cpp:3379-3393,3413-3430 at 6504a3af.

### `finishBlockScripts_valid` (`lean/BsvChain/Properties/Depth.lean:264`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `oracle`; `params`, `cfg` and `now` are not arguments of the statement.

[D] 2026-10-14: an accepted queue judged every one of its calls valid.
[SRC] src/validation.cpp:3678-3714 at 6504a3af.

### `connectBlock_scripts_judged` (`lean/BsvChain/Properties/Depth.lean:283`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now`.

[M] 2026-10-14, #73 (what the scripts-on connection judged). For every
successful connection of a non-genesis block made with `checkScripts = true`,
under any parameters, configuration, operator lists, oracle and time: on the
serial schedule, every transaction of the body was applied in order under the
real script oracle, each in the view immediately before it; on the queued
schedule, the queue holds exactly the oracle keys of every transaction in body
order (none for the coinbase and for a confiscation transaction), and the
oracle judged every one of them valid before the block was published.
Premises in plain words: the connection succeeded (`hc`), the block is not the
network's genesis block (`nonGenesis`), and the decision was to run the
scripts (`hs`). This statement describes the serial applications and queued
oracle calls of `connectBlock` under those premises.
[SRC] src/validation.cpp:2864-2889,3379-3430,3678-3714 at 6504a3af.

### `s6_connectTip_checks_scripts` (`lean/BsvChain/Properties/Depth.lean:338`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

[M] 2026-10-14, #73 (the tip connection under no assumed-valid hash). On a
wired node with no assumed-valid hash, a successful `connectTip` is a
successful block connection made with the scripts on. Premises in plain
words: the context is wired (`hw`), the hash is zero or unknown to the state's
tree (`h`), and the tip connection succeeded (`hc`).
[SRC] src/validation.cpp:3482-3518,4345-4404 at 6504a3af.

### `safeMode_none_refuses_nothing` (`lean/BsvChain/Properties/Depth.lean:366`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-14, #73 (safe mode refuses nothing without a warning). With
no triggering fork and `-testsafemode` off, no RPC command is refused.
Premises in plain words: the level is `none` and the test switch is off.
[SRC] src/init.cpp:324-333 and src/warnings.cpp:46-83 at 6504a3af.

### `safeMode_safe_command_answered` (`lean/BsvChain/Properties/Depth.lean:374`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-14, #73 (a safe command is always answered). A command
registered with `okSafeMode` true is never refused, at any level; neither is
any command under `-disablesafemode`. Premise in plain words: the command is
registered safe, or the operator disabled the refusal.
[SRC] src/init.cpp:324-333 at 6504a3af.

### `forkSafeModeLevel_active` (`lean/BsvChain/Properties/Depth.lean:384`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-14, #73 (a fork on the active chain triggers nothing). A tip
that is a block of the active chain has level `none`.
[SRC] src/safe_mode.cpp:67-70 at 6504a3af.

## `BsvChain.Properties.DoubleSpend`

### `readVarIntLoop_cont` (`lean/BsvChain/Properties/DoubleSpend.lean:35`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: one byte with the continuation bit read under the bound.

### `readVarIntLoop_stop` (`lean/BsvChain/Properties/DoubleSpend.lean:43`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the last byte read under the bound.

### `varIntHigh_read` (`lean/BsvChain/Properties/DoubleSpend.lean:49`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the digits before the last read back to their value plus
one, when that value is within the bound. [SRC] src/serialize.h:342-423 at 6504a3af.

### `writeVarInt_read` (`lean/BsvChain/Properties/DoubleSpend.lean:80`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: every VARINT within the bound reads back with the stream's
rest untouched. [SRC] src/serialize.h:379-423 at 6504a3af.

### `varIntHigh_length` (`lean/BsvChain/Properties/DoubleSpend.lean:108`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a value below `varIntBound k` writes at most `k + 1` digits before its last.

### `writeVarInt_length` (`lean/BsvChain/Properties/DoubleSpend.lean:125`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a 64-bit value's VARINT is at most ten bytes, the reader's
loop bound (src/serialize.h:407-408 at 6504a3af).

### `readVarInt64_write` (`lean/BsvChain/Properties/DoubleSpend.lean:136`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE VARINT ROUND TRIP, 64-bit (`ReadVarInt<uint64_t>`, the
callback message's counts). [SRC] src/serialize.h:379-423 at 6504a3af.

### `readVarInt32_write` (`lean/BsvChain/Properties/DoubleSpend.lean:145`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE VARINT ROUND TRIP, 32-bit (`ReadVarInt<uint32_t>`, the
callback message's inputs). [SRC] src/serialize.h:379-423 at 6504a3af.

### `varInt_2pow32_widths` (`lean/BsvChain/Properties/DoubleSpend.lean:154`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the source's table entry for 2^32, `8efefeff00`
(src/serialize.h:363 at 6504a3af), reads as 2^32 at 64 bits and is refused at
32 bits: before its last byte the accumulator passes 2^25 - 1, the 32-bit
type's bound (:405,409-411). A view, never a rule.

### `CallbackMsg.decode_encode` (`lean/BsvChain/Properties/DoubleSpend.lean:172`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE CALLBACK ROUND TRIP. A well-formed message reads back
from its writer's bytes. [SRC] src/double_spend/dscallback_msg.h:52-149 at
6504a3af. A view, never a rule.

### `writeVarInt_length_pos` (`lean/BsvChain/Properties/DoubleSpend.lean:198`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a VARINT is at least one byte.

### `callbackOfScript_dsntScript` (`lean/BsvChain/Properties/DoubleSpend.lean:202`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE NOTIFICATION OUTPUT'S ROUND TRIP. A well-formed message
of up to 65535 bytes, written as the notification output's push, is read back
by the handler's reader of an output script. [SRC] src/script/script.h:104-133,165-200,
src/script/script.cpp:174-179, src/double_spend/dscallback_msg.cpp:94-114 at
6504a3af. A view, never a rule.

### `ProofNode.read_encode` (`lean/BsvChain/Properties/DoubleSpend.lean:249`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a proof node of a one-byte type and a 32-byte hash reads back. [SRC] src/merkleproof.h:32-38 at 6504a3af.

### `MerkleProof.read_encode` (`lean/BsvChain/Properties/DoubleSpend.lean:271`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE PROOF'S ROUND TRIP. [SRC] src/merkleproof.h:100-137 at
6504a3af. A view, never a rule.

### `BlockDetails.read_encode` (`lean/BsvChain/Properties/DoubleSpend.lean:308`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: well-formed block details read back, the stream's rest untouched.
[SRC] src/double_spend/dsdetected_message.h:31-43 at 6504a3af.

### `DSDetected.read_encode` (`lean/BsvChain/Properties/DoubleSpend.lean:327`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE `dsdetected` ROUND TRIP. A message of version 1 with at
least two well-formed blocks reads back from its writer's bytes, the rest of
the payload untouched. [SRC] src/double_spend/dsdetected_message.h:29-98,
src/merkleproof.h:100-137 at 6504a3af. A view, never a rule.

### `acceptDetect_fst` (`lean/BsvChain/Properties/DoubleSpend.lean:347`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

[D] 2026-10-15: `acceptDetect`'s admission component is #62's `acceptWithTrace`:
the detection is read beside the admission and changes nothing of it. A view,
never a rule.

### `runAdmissionStages_none` (`lean/BsvChain/Properties/DoubleSpend.lean:366`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a run of stages that stops nowhere names every stage.

### `runAdmissionStages_some` (`lean/BsvChain/Properties/DoubleSpend.lean:387`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a run that stops names the stopping stage last, and that
stage's check produced the outcome.

### `stageConflict_some` (`lean/BsvChain/Properties/DoubleSpend.lean:415`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the conflict stage refuses only as `txn-mempool-conflict`
(0x102). [SRC] src/validation.cpp:1147-1153 at 6504a3af.

### `stageDetector_some` (`lean/BsvChain/Properties/DoubleSpend.lean:422`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the detector refuses only as `txn-mempool-conflict` (0x102)
or `txn-double-spend-detected` (0x12). [SRC] src/validation.cpp:1484-1494 at 6504a3af.

### `detection_some` (`lean/BsvChain/Properties/DoubleSpend.lean:433`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: what a detection says of its admission's outcome and trace.

### `beforeDetector_eq` (`lean/BsvChain/Properties/DoubleSpend.lean:455`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

[D] 2026-10-15: `beforeDetector` runs exactly `beforeDetectorStages`.

### `beforeDetector_names` (`lean/BsvChain/Properties/DoubleSpend.lean:460`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

[D] 2026-10-15: the stages before the detector, by name.

### `acceptDetect_snd` (`lean/BsvChain/Properties/DoubleSpend.lean:468`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

[D] 2026-10-15: THE DETECTOR'S EVENT, READ BACK. A detection of #62's
admission is a completed refusal of the request it names, by the pool's
conflict check (stage 5, 0x102, before any script ran; the scripts are not
marked checked) or by the double-spend detector (stage 13, 0x102 or 0x12,
after every earlier stage ran, the scripts' among them). [SRC]
src/validation.cpp:1147-1153,1478-1494 at 6504a3af. A view, never a rule.

### `Grows.refl` (`lean/BsvChain/Properties/DoubleSpend.lean:583`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a working state grows from itself.

### `Grows.trans` (`lean/BsvChain/Properties/DoubleSpend.lean:587`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: growth composes.

### `grows_emit` (`lean/BsvChain/Properties/DoubleSpend.lean:592`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: one effect whose notice satisfies `P` is a growth.

### `grows_plain` (`lean/BsvChain/Properties/DoubleSpend.lean:601`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: one effect with no notice is a growth under every `P`.

### `grows_blacklist` (`lean/BsvChain/Properties/DoubleSpend.lean:606`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: replacing the blacklist adds no effect and no task.

### `grows_next` (`lean/BsvChain/Properties/DoubleSpend.lean:610`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: reading a reply adds no effect and no task.

### `grows_ban` (`lean/BsvChain/Properties/DoubleSpend.lean:615`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now`; `params`, `cfg` and `oracle` are not arguments of the statement.

[D] 2026-10-15: blacklisting an endpoint adds one effect with no notice.

### `grows_record` (`lean/BsvChain/Properties/DoubleSpend.lean:619`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: recording a transaction adds at most one effect, with no notice.

### `grows_slow` (`lean/BsvChain/Properties/DoubleSpend.lean:626`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: queueing a slow task whose notice satisfies `P` is a growth.

### `attempt_grows` (`lean/BsvChain/Properties/DoubleSpend.lean:636`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now`; `params`, `cfg` and `oracle` are not arguments of the statement.

[D] 2026-10-15: one query-and-proof exchange adds requests and effects only under its own notice.
[SRC] src/double_spend/dsattempt_handler.cpp:698-767 at 6504a3af.

### `fastLoop_grows` (`lean/BsvChain/Properties/DoubleSpend.lean:680`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now`; `params`, `cfg` and `oracle` are not arguments of the statement.

[D] 2026-10-15: the fast path's loop adds requests and slow tasks only under its own notice.
[SRC] src/double_spend/dsattempt_handler.cpp:617-649 at 6504a3af.

### `slowLoop_grows` (`lean/BsvChain/Properties/DoubleSpend.lean:720`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now`; `params`, `cfg` and `oracle` are not arguments of the statement.

[D] 2026-10-15: a slow task's loop adds requests only under its own notice.
[SRC] src/double_spend/dsattempt_handler.cpp:660-696 at 6504a3af.

### `sendLoop_grows` (`lean/BsvChain/Properties/DoubleSpend.lean:756`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now` (through `Env`); `params`, `cfg` and `oracle` are not arguments of the statement.

[D] 2026-10-15: the loop over a message's addresses adds requests and slow tasks only under its notice.
[SRC] src/double_spend/dsattempt_handler.cpp:556-657 at 6504a3af.

### `verdictLoop_grows` (`lean/BsvChain/Properties/DoubleSpend.lean:783`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now` (through `Env`); `params`, `cfg` and `oracle` are not arguments of the statement.

[D] 2026-10-15: the verdict loop adds requests and slow tasks only under a
notice it checked and passed.

### `mem_conflictPairs` (`lean/BsvChain/Properties/DoubleSpend.lean:806`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a pair the search yields names two inputs that spend one outpoint.

### `sides_some` (`lean/BsvChain/Properties/DoubleSpend.lean:827`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the two sides are the pooled transaction and the double spend, the enabled one carrying a notification output.

### `noticeFor_some` (`lean/BsvChain/Properties/DoubleSpend.lean:846`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now` (through `Env`); `params`, `cfg` and `oracle` are not arguments of the statement.

[D] 2026-10-15: a notice the handler builds names its detection, the two
sides of the conflict on one outpoint, and an enabled side with a notification
output; it is not yet checked.

### `noticesLoop_mem` (`lean/BsvChain/Properties/DoubleSpend.lean:877`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now` (through `Env`); `params`, `cfg` and `oracle` are not arguments of the statement.

[D] 2026-10-15: every notice of the loop is `noticeFor`'s for one collided transaction.

### `mem_notices` (`lean/BsvChain/Properties/DoubleSpend.lean:902`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now` (through `Env`); `params`, `cfg` and `oracle` are not arguments of the statement.

[D] 2026-10-15: every notice of an attempt is its conflict's.

### `process_grows` (`lean/BsvChain/Properties/DoubleSpend.lean:918`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now` (through `Env`); `params`, `cfg` and `oracle` are not arguments of the statement.

[D] 2026-10-15: what one processing step sends and queues: every request
and every new slow task carries a notice of the popped attempt that its script
check passed.

### `notification_only_after_detection` (`lean/BsvChain/Properties/DoubleSpend.lean:944`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now` (through `Env`); `params`, `cfg` and `oracle` are not arguments of the statement.

[D] 2026-10-15: THE THEOREM, the handler's half. **A notification is
emitted only for a conflict the detector saw**: every query and every proof a
processing step sends names a notice whose attempt is a detection of #62's
admission (`Detected`), whose two sides are that conflict's on one outpoint
with a notification output on the enabled side (`NoticeShape`), and whose
double-spend input passed the script check that step ran or the admission
already ran (`checkOf`, recorded on the notice as `check`). Premise in plain
words: the queue holds only detections, which `Reach` below proves of every
reachable state. [SRC] src/double_spend/dsattempt_handler.cpp:323-465,555-767,
src/net/net.cpp:2653-2659, src/validation.cpp:1733-1757 at 6504a3af.
`Detected` is existential: some state of #62's machine (pool, UTXO view,
settings, script oracle, detector observation) refuses the double spend with
that detection, and `Reach` queues any such detection, so the theorem binds a
notice to a refusal #62's machine makes, not to this node's own admission; the
handler's own script check is an input (`Env.scriptCheck`), not #62's oracle;
the composed machine is owed. A view, never a rule.

### `notification_conflict_after_validation` (`lean/BsvChain/Properties/DoubleSpend.lean:976`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `now` (`params` and `now` through `AdmissionContext`; `now` through `Env`); `cfg` and `oracle` are not arguments of the statement.

[D] 2026-10-15: THE THEOREM, spelled against #62's machine. Every query and
every proof a processing step sends is for a completed refusal by
`acceptWithTrace` of a request whose transaction is one side of the notice;
either the refusal is the pool's conflict check (stage 5, `txn-mempool-conflict`
0x102), reached before any script ran, and the handler's own script check of
the double-spend input passed before it sent; or the refusal is the
double-spend detector's (stage 13, 0x102 or `txn-double-spend-detected` 0x12),
reached after every earlier stage, the script stage among them. **The issue's
sentence "after validation" holds literally of the detector's refusals only;
for a stage-5 conflict the detector saw the conflict before the double spend's
scripts ran, and the handler validates the input itself before it notifies**
(src/double_spend/dsattempt_handler.cpp:149-178,396-421 at 6504a3af).
`Detected` is existential: some state of #62's machine (pool, UTXO view,
settings, script oracle, detector observation) refuses the double spend with
that detection, and `Reach` queues any such detection, so the theorem binds a
notice to a refusal #62's machine makes, not to this node's own admission; the
handler's own script check is an input (`Env.scriptCheck`), not #62's oracle;
the composed machine is owed.
A notification is never a verdict. A view, never a rule.

### `reach_invariant` (`lean/BsvChain/Properties/DoubleSpend.lean:1037`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now` (through `Reach`); `params`, `cfg` and `oracle` are not arguments of the statement.

[D] 2026-10-15: the invariant: the queue holds detections, the slow queue good notices.

### `every_request_good` (`lean/BsvChain/Properties/DoubleSpend.lean:1084`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now` (through `Env`, `Reach`); `params`, `cfg` and `oracle` are not arguments of the statement.

[D] 2026-10-15: THE THEOREM over every reachable state: no request of the
handler, from the fast path or the slow queue, carries a notice that is not a
checked notice of a conflict the detector saw. A view, never a rule.

### `Blacklist.insert_fresh` (`lean/BsvChain/Properties/DoubleSpend.lean:1106`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: inserting a fresh endpoint keeps a subset of the old entries and appends the new one.

### `Blacklist.find_add` (`lean/BsvChain/Properties/DoubleSpend.lean:1121`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: an added endpoint is found with its new expiry: the
insertion never evicts itself and the update erased the old entry.
[SRC] src/double_spend/time_limited_blacklist.h:41-64, src/limitedmap.h:41-50 at 6504a3af.

### `Blacklist.add_hour` (`lean/BsvChain/Properties/DoubleSpend.lean:1138`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now`; `params`, `cfg` and `oracle` are not arguments of the statement.

[D] 2026-10-15: THE BLACKLIST'S HOUR. An endpoint the handler blacklists
at time `t` (`AddToBlacklist`: until `t` plus 3600 s) is blacklisted at every
earlier instant before the hour is out and not at or after it, whatever the
list held. [SRC] src/double_spend/dsattempt_handler.cpp:28,316-321,
src/double_spend/time_limited_blacklist.h:41-107 at 6504a3af. A view, never a rule.

### `Blacklist.check_erases` (`lean/BsvChain/Properties/DoubleSpend.lean:1150`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now`; `params`, `cfg` and `oracle` are not arguments of the statement.

[D] 2026-10-15: past its hour the entry is erased by the check that finds it expired.

### `sendLoop_blacklisted` (`lean/BsvChain/Properties/DoubleSpend.lean:1162`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now` (through `Env`); `params`, `cfg` and `oracle` are not arguments of the statement.

[D] 2026-10-15: an endpoint blacklisted at the check is never queried: the
one-address loop records the skip and sends nothing. [SRC]
src/double_spend/dsattempt_handler.cpp:575-605 at 6504a3af. A view, never a rule.

### `processDSDetected_sends` (`lean/BsvChain/Properties/DoubleSpend.lean:1177`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE `dsdetected` RELAY. The node sends something only for a
message it read, had not seen, judged valid, found high enough, whose headers
it accepted and whose blocks it marked; it relays the message to every peer
but the sender and posts it to the webhook only when one is set. Nothing here
judges a block or a transaction. [SRC] src/net/net_processing.cpp:4573-4684 at
6504a3af. A view, never a rule.

### `processDSDetected_duplicate` (`lean/BsvChain/Properties/DoubleSpend.lean:1220`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a message seen before is answered with nothing, whatever it
holds (the duplicate cache, src/net/net_processing.cpp:4601-4616 at 6504a3af).

## `BsvChain.Properties.Eras`

### `getNextWorkRequired_path` (`lean/BsvChain/Properties/Eras.lean:20`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

For a candidate with a parent, `getNextWorkRequired` takes exactly the branch `nextWorkPath`
names: the parent's bits under no-retargeting, the cash algorithm when the
parent's height reaches `daaHeight`, the EDA otherwise. Premise: the header
chain has a parent (`ancestors = p :: rest`). [SRC] src/pow.cpp:95–117 at 6504a3af.

### `nextWorkPath_no_retargeting` (`lean/BsvChain/Properties/Eras.lean:37`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

(a) for ANY parameters with `fPowNoRetargeting` set: the path is
no-retargeting at every parent height, whatever `daaHeight` is, because the
flag is tested before the DAA height. Premise: the flag.
[SRC] src/pow.cpp:106–113 at 6504a3af.

### `s6_no_retargeting_parent_bits` (`lean/BsvChain/Properties/Eras.lean:46`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

(a) for ANY parameters with `fPowNoRetargeting` set: every next-work
computation with a parent returns the parent's bits; the DAA height is never
read. Premises: the flag and a parent (`ancestors = p :: rest`); the genesis
case is :101–104. [SRC] src/pow.cpp:101–117 at 6504a3af.

### `s6_regtest_next_work_parent_bits` (`lean/BsvChain/Properties/Eras.lean:59`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params` fixed to regtest's record; for every `cfg`; `oracle` and `now` are not arguments of the statement. General form: `s6_no_retargeting_parent_bits`, quantified; this theorem is its instance.

(a), the true form of the issue's "on regtest the post-DAA path is taken
from height 0". Regtest compiles `daaHeight = 0` AND `fPowNoRetargeting =
true` (src/chainparams.cpp:1477,1490), and `GetNextWorkRequired` returns the
parent's bits at :107–109, before it tests the DAA height at :111–113; so on
regtest no next-work computation reaches the DAA. Every one returns the
parent's bits. Premise: a parent exists (`ancestors = p :: rest`); the genesis
case is :101–104. The general form is `s6_no_retargeting_parent_bits`, for
every network with the flag set; this theorem is its regtest instance.
[SRC] src/pow.cpp:101–117 at 6504a3af.

### `s6_regtest_path_no_retargeting` (`lean/BsvChain/Properties/Eras.lean:74`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params` fixed to regtest's record; `cfg`, `oracle` and `now` are not arguments of the statement. General form: `nextWorkPath_no_retargeting`, quantified; this theorem is its instance.

On regtest the path is no-retargeting at every parent height; the cash
branch is never named. The general form is `nextWorkPath_no_retargeting`, for
every network with the flag set. [SRC] src/pow.cpp:106–109, src/chainparams.cpp:1477 at 6504a3af.

### `s6_daa_zero_cash_path` (`lean/BsvChain/Properties/Eras.lean:80`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

(a), the DAA half: for ANY parameters with `daaHeight = 0` and
no-retargeting off (testing the DAA separately, as DESIGN-S6 §4.2 requires),
the cash algorithm is taken at every parent height, from height 0.
Premises: the two parameter values and a parent. [SRC] src/pow.cpp:107–113 at 6504a3af.

### `nextWorkPath_retargeting` (`lean/BsvChain/Properties/Eras.lean:95`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

(a) for ANY parameters with `fPowNoRetargeting` off: the path is the cash
algorithm from the parent height `daaHeight` on and the EDA below it.
Premise: the flag. [SRC] src/pow.cpp:106–116 at 6504a3af.

### `s6_mainnet_daa_switch` (`lean/BsvChain/Properties/Eras.lean:104`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params` fixed to mainnet's record; `cfg`, `oracle` and `now` are not arguments of the statement. General form: `nextWorkPath_retargeting`, quantified; this theorem is its instance.

Mainnet's DAA switch reads the parent's height: a candidate whose parent
is at 504030 takes the EDA, one whose parent is at `daaHeight` = 504031 the
cash algorithm. The general form is `nextWorkPath_retargeting`; this theorem
reads mainnet's two values from its record. [SRC] src/pow.cpp:111–116, src/chainparams.cpp:1068 at 6504a3af.

### `s6_no_retargeting_accepted_header_bits` (`lean/BsvChain/Properties/Eras.lean:112`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now`; `oracle` is not an argument of the statement.

For ANY parameters with `fPowNoRetargeting` set, a header accepted by the
contextual check carries its parent's bits, for every configuration and every
`now`. Premises: the flag, acceptance and a parent.
[SRC] src/validation.cpp:5943–5948, src/pow.cpp:106–109 at 6504a3af.

### `s6_regtest_accepted_header_bits` (`lean/BsvChain/Properties/Eras.lean:130`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params` fixed to regtest's record; for every `cfg` and `now`; `oracle` is not an argument of the statement. General form: `s6_no_retargeting_accepted_header_bits`, quantified; this theorem is its instance.

A regtest header accepted by the contextual check carries its parent's
bits: the measured "every regtest block has the genesis bits" is this,
iterated along the chain. Premises: acceptance and a parent. The general form
is `s6_no_retargeting_accepted_header_bits`; this theorem is its regtest
instance. [SRC] src/validation.cpp:5943–5948, src/pow.cpp:106–109 at 6504a3af.

### `bip30Enforced_iff` (`lean/BsvChain/Properties/Eras.lean:144`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

The gate unfolded: enforced iff the block is not one of the two historical
exceptions, the BIP34 shortcut does not apply, and the resolved setting does
not disable it. [SRC] src/validation.cpp:3070–3100 at 6504a3af.

### `s6_bip30_two_exceptions` (`lean/BsvChain/Properties/Eras.lean:154`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

(b), the true form of the issue's "BIP30 is enforced at every height but the
two named": on every network, when the BIP34 shortcut does not apply and the
setting is off, the check runs unless the block is (91842, its hash) or
(91880, its hash). The exceptions are height AND hash; a different block at
either height is checked. The issue's unconditional sentence is false on
mainnet above BIP34 activation, where the shortcut skips the check on the known
chain (`s6_bip30_bip34_shortcut`), and wherever the network permits the setting.
Premises: shortcut absent, setting off. [SRC] src/validation.cpp:3070–3100 at 6504a3af.

### `s6_bip30_bip34_shortcut` (`lean/BsvChain/Properties/Eras.lean:170`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

The BIP34 shortcut: when the parent's ancestor at `bip34Height` carries the
network's `bip34Hash`, connection skips the BIP30 check at any height.
[SRC] src/validation.cpp:3088–3095 at 6504a3af.

### `s6_bip30_connection_gate` (`lean/BsvChain/Properties/Eras.lean:178`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

The chain transition's gate: for an index at or below `bip34Height` the
ancestor is never read, so with the setting off the default
`eraConnectionChecks` requires BIP30 exactly outside the two exceptions.
Premises: the height bound and the setting. [SRC] src/validation.cpp:3070–3100 at 6504a3af.

### `s6_bip30_regtest` (`lean/BsvChain/Properties/Eras.lean:193`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params` fixed to regtest's record; for every `cfg`; `oracle` and `now` are not arguments of the statement. General form: `s6_bip30_connection_gate`, quantified; this theorem is its instance.

(b) on regtest: below `bip34Height` = 100,000,000 (src/chainparams.cpp:1463),
with the setting at its default, every block at a height other than 91842 and
91880 has BIP30 required by the chain transition; at those two heights only
the two mainnet hashes are exempt. The general form is
`s6_bip30_connection_gate`, for every network; this theorem is its regtest
instance. [SRC] src/validation.cpp:3070–3100 at 6504a3af.

### `s6_bip30_mainnet` (`lean/BsvChain/Properties/Eras.lean:205`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params` fixed to mainnet's record; for every `cfg`; `oracle` and `now` are not arguments of the statement. General form: `s6_bip30_connection_gate`, quantified; this theorem is its instance.

(b) on mainnet through height 227931 (BIP34 activation, src/chainparams.cpp:1038):
with the setting off, BIP30 is required at every block but the two named.
The general form is `s6_bip30_connection_gate`; this theorem is its mainnet
instance. [SRC] src/validation.cpp:3070–3100 at 6504a3af.

### `versionObsolete_iff_floor` (`lean/BsvChain/Properties/Eras.lean:218`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The floor predicate is "below the largest floor reached", for any order of
the three activation heights (regtest's are not monotone).
[SRC] src/validation.cpp:5965–5967 at 6504a3af.

### `s6_contextual_header_version` (`lean/BsvChain/Properties/Eras.lean:227`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now`; `oracle` is not an argument of the statement.

(c): with the bits and the two timestamp checks passed, the contextual
header check is exactly the version floor check at the block's height.
Premises: the three earlier checks pass, as `contextualCheckBlockHeader`
orders them. [SRC] src/validation.cpp:5943–5972 at 6504a3af.

### `s6_mainnet_version_floors` (`lean/BsvChain/Properties/Eras.lean:247`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params` fixed to mainnet's record; `cfg`, `oracle` and `now` are not arguments of the statement. General form: `versionObsolete_iff_floor`, free of the four inputs (general over the values it takes); this theorem is its instance.

(c) six concrete mainnet floor cells: none at 227930, 2 at 227931 and
363724, 3 at 363725 and 388380, and 4 at 388381 (BIP34 227931, BIP66 363725,
BIP65 388381, src/chainparams.cpp:1038,1044,1042). The three heights are read
from mainnet's record, `ChainParams.mainnet`, in its leading three conjuncts.
The general equivalence is `versionObsolete_iff_floor`.
[SRC] src/validation.cpp:5965–5967 at 6504a3af.

### `s6_regtest_version_floors` (`lean/BsvChain/Properties/Eras.lean:266`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params` fixed to regtest's record; `cfg`, `oracle` and `now` are not arguments of the statement. General form: `versionObsolete_iff_floor`, free of the four inputs (general over the values it takes); this theorem is its instance.

(c) on regtest (BIP34 100,000,000, BIP66 1251, BIP65 1351,
src/chainparams.cpp:1463–1468): BIP66's floor of 3 binds at 1251 before BIP34,
then BIP65's floor of 4 binds at 1351. The BIP34 floor never binds alone.
A version-1 block passes the floors only below
height 1251; versions 1 and 2 are rejected from 1251 and version 3 from 1351.
The general equivalence is `versionObsolete_iff_floor`; this theorem is its
regtest instance. [SRC] src/validation.cpp:5965–5967 at 6504a3af.

### `s6_checkBlock_uahf_irrelevant` (`lean/BsvChain/Properties/Eras.lean:283`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

(d), the true form of "the fork-block size rule at `uahfHeight` and only
there": at the pin no block size rule reads `uahfHeight`. `checkBlock` is the
same function for every value of it. [SRC] src/validation.cpp:5749–5901 at 6504a3af.

### `s6_contextualCheckBlock_uahf_irrelevant` (`lean/BsvChain/Properties/Eras.lean:291`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

The body's contextual check (size, finality, coinbase height) does not read
`uahfHeight`. [SRC] src/validation.cpp:6039–6104 at 6504a3af.

### `s6_contextualCheckBlockHeader_uahf_irrelevant` (`lean/BsvChain/Properties/Eras.lean:298`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now`; `oracle` is not an argument of the statement.

The header's contextual check does not read `uahfHeight`.
[SRC] src/validation.cpp:5933–5975, src/pow.cpp:22–297 at 6504a3af.

### `s6_uahf_script_word` (`lean/BsvChain/Properties/Eras.lean:305`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

(d) where `uahfHeight` IS read: the theorem equates the block script word's
FORKID bit to whether the PARENT's height (the block's height minus one)
reaches `uahfHeight`. The source additionally sets STRICTENC at that boundary;
that bit is not part of this theorem's equality. On regtest (`uahfHeight = 0`,
src/chainparams.cpp:1487) that is every block above genesis. Premise: the
network's script heights are assigned. [SRC] src/verify_script_flags.cpp:54–59, src/validation.cpp:2972–2981 at 6504a3af.

### `s6_lock_cutoff_switch` (`lean/BsvChain/Properties/Eras.lean:324`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

(e): from `csvHeight` the block's finality cutoff is the median time past of
the previous blocks; below it, the block's own time. Premise: the network
assigns `csvHeight`. [SRC] src/validation.cpp:6046–6050,6055–6056,6067–6074 at 6504a3af.

### `s6_mainnet_lock_cutoff` (`lean/BsvChain/Properties/Eras.lean:333`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params` fixed to mainnet's record; for every `cfg`; `oracle` and `now` are not arguments of the statement. General form: `s6_lock_cutoff_switch`, quantified; this theorem is its instance.

(e) at mainnet's CSV height 419,328 (src/chainparams.cpp:1046): the block at
419,327 is judged against its own time, the block at 419,328 against the
previous median. The general form is `s6_lock_cutoff_switch`, for every
network that assigns `csvHeight`; this theorem is its mainnet instance.
[SRC] src/validation.cpp:6046–6050 at 6504a3af.

### `s6_block_finality_cutoff` (`lean/BsvChain/Properties/Eras.lean:344`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

(e) applied to a transaction: the block's finality judge compares the lock
time with that cutoff, so a time-locked transaction final against the block's
own time below `csvHeight` is judged against the median from it.
[SRC] src/validation.cpp:5977–5996,6067–6083 at 6504a3af.

## `BsvChain.Properties.Finality`

### `isFinalTx_lockTime_zero` (`lean/BsvChain/Properties/Finality.lean:12`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A zero lock time makes a transaction final at every height and time.
The only assumption is `lockTime = 0`; input sequences are unrestricted.
This proves the early return [SRC] src/validation.cpp:229–231 at 6504a3af.

### `isFinalTx_all_sequences_final` (`lean/BsvChain/Properties/Finality.lean:19`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

All final input sequences disable absolute locking for every lock time,
height and time. The premise covers each input, including the empty list.
This is the final loop's success [SRC] src/validation.cpp:240–247 at 6504a3af.

### `fee_nonnegative` (`lean/BsvChain/Properties/Finality.lean:30`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A successful fee check returns a nonnegative fee. Acceptance here is
exactly `fee valueIn valueOut = .ok amount`, without assuming UTXO availability
or full admission. This isolates the value-preservation ingredient #61 needs.
[SRC] src/validation.cpp:2646–2663 at 6504a3af.

### `insertionSort_eq_mergeSort` (`lean/BsvChain/Properties/Finality.lean:44`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-13 (#68): on naturals, insertion sort and merge sort return
the same list, since both are sorted permutations of the input and the order
is antisymmetric. The median's sort changed presentation, not value.
[SRC] src/block_index.h:722–737 at 6504a3af.

### `medianTimePast_mem` (`lean/BsvChain/Properties/Finality.lean:58`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A median taken from a nonempty chain with positive span is one of that
chain's times. Sorting permutes the selected ancestors, so the result is an
observed time, including on short chains; no averaging creates a timestamp.
[SRC] src/block_index.h:722–737 at 6504a3af.

### `tip_block_finality_agree_of_mtp_lt` (`lean/BsvChain/Properties/Finality.lean:78`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now`; `oracle` is not an argument of the statement.

Below the signed-int boundary, the tip and block judges agree on finality
for every transaction and ancestor list. Both use the successor height and
median: the tip has the median flag, and CSV is active for the block. Their
non-final outcomes retain the policy hold versus block rejection distinction.
The nonnegative median below 2^31 is unchanged by the tip's narrowing, so this
width correction has no effect in that range.
[SRC] src/validation.cpp:1101–1106,5998–6037,6042–6056,6067–6074 at 6504a3af.

## `BsvChain.Properties.Frozen`

### `s6_frozen_projection_check` (`lean/BsvChain/Properties/Frozen.lean:21`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The connection projection is `CFrozenTXOCheck::Check`: the projection of the
records adjusted by the block's explicit freeze flag `e` and waiver `w` reports
an output frozen exactly when `check` returns an effective list. No premise.
[SRC] src/frozentxo.cpp:37–83 at 6504a3af.

### `s6_whitelist_projection_check` (`lean/BsvChain/Properties/Frozen.lean:29`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The whitelist half: the adjusted projection is
`CheckConfiscationTxWhitelisted` with the waiver `w`. No premise.
[SRC] src/frozentxo.cpp:133–171 at 6504a3af.

### `checkInputCoins_congr` (`lean/BsvChain/Properties/Frozen.lean:38`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `UtxoContext`); `oracle` is not an argument of the statement.

The per-input loop reads the frozen projection only on the context's path
and at its height. Premise: the two frozen predicates are equal on that path
at that height. [SRC] src/validation.cpp:2591–2643 at 6504a3af.

### `checkInputCoins_confiscation` (`lean/BsvChain/Properties/Frozen.lean:51`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `UtxoContext`); `oracle` is not an argument of the statement.

A confiscation transaction's loop never reads the frozen projection.
[SRC] src/validation.cpp:2594–2611 at 6504a3af.

### `checkTxInputs_congr` (`lean/BsvChain/Properties/Frozen.lean:62`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `UtxoContext`); `oracle` is not an argument of the statement.

The input stage reads both projections only on the context's path and at
its height. Premises: the two frozen predicates are equal, and the two whitelist
predicates are equal, on that path at that height.
[SRC] src/validation.cpp:2552–2665 at 6504a3af.

### `applyTx_congr` (`lean/BsvChain/Properties/Frozen.lean:72`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

One transaction's application, likewise. Premises: the two frozen
predicates are equal, and the two whitelist predicates are equal, on the
context's path at its height. [SRC] src/validation.cpp:3326–3434 at 6504a3af.

### `runBlockTransactions_congr` (`lean/BsvChain/Properties/Frozen.lean:82`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

A block's transaction run, likewise. Premises: the two frozen predicates
are equal, and the two whitelist predicates are equal, on the context's path at
its height. [SRC] src/validation.cpp:3290–3447 at 6504a3af.

### `prepareBlockConnection_ctx` (`lean/BsvChain/Properties/Frozen.lean:96`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `UtxoContext`); `oracle` is not an argument of the statement.

The connection's prepared context is the block path at the block's height.
Premise: the preparation succeeds for a non-genesis block, returning `some ctx`.
[SRC] src/validation.cpp:3021–3050,3376–3392 at 6504a3af.

### `connectBlock_lists_congr` (`lean/BsvChain/Properties/Frozen.lean:111`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now`.

Block connection reads the operator lists only on the block path at the
block's height `H`: two projections that agree there connect every block alike.
[SRC] src/frozentxo.cpp:52–62 and src/validation.cpp:3529,3376–3392 at 6504a3af.

### `frozenData_mem` (`lean/BsvChain/Properties/Frozen.lean:138`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A record found by `frozenData` is an entry of the records.
[SRC] src/frozentxo_db.cpp:520–533 at 6504a3af.

### `project_block_empty` (`lean/BsvChain/Properties/Frozen.lean:151`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

At height `H` the block-path projection of records none of which is frozen
on the ranged predicate there is the empty records' projection.

### `checkTxInputs_frozen_head` (`lean/BsvChain/Properties/Frozen.lean:167`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `UtxoContext`); `oracle` is not an argument of the statement.

The input stage's frozen refusal: the head input frozen on the context's
path gives `bad-txns-inputs-frozen`, code 0x13 on the block path and 0x10 on
admission. Premises: inputs available, not a confiscation transaction, the
head input `i` frozen. [SRC] src/validation.cpp:2552–2607 at 6504a3af.

### `runAdmissionStages_append_pass` (`lean/BsvChain/Properties/Frozen.lean:179`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A run of admission stages whose prefix passes continues with the suffix.
[SRC] src/validation.cpp:1031–1482 at 6504a3af (the source order).

### `s6_policy_frozen_admission_refused` (`lean/BsvChain/Properties/Frozen.lean:205`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

(a), admission: a spend of an output frozen on the policy predicate at the
tip's successor is refused by `accept` with `bad-txns-inputs-frozen`, code 0x10.
Premises: the request is submitted (not inventory-suppressed) with no per-call
configuration; every source-ordered earlier stage passes (`earlier`, ending in
the work `w`); the relay word resolves; inputs are available in `w`'s view; the
transaction is not a confiscation transaction; its head input `i` has a record
frozen on the policy predicate (`IsFrozenOnPolicy`) at height `tipHeight + 1`.
[SRC] src/validation.cpp:1320–1348,2552–2607 and src/frozentxo.cpp:63–75 at 6504a3af.

### `s6_policy_only_frozen_on_policy` (`lean/BsvChain/Properties/Frozen.lean:253`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

(a), the policy-only corollary: a record on the policy-only list.
[SRC] src/frozentxo_db.h:323–329 at 6504a3af.

### `s6_policy_list_not_consulted_at_connection` (`lean/BsvChain/Properties/Frozen.lean:259`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now`.

(a), connection: block connection does not consult the policy-only list.
Records all on that list connect every block exactly as no records do, so a
block whose connection succeeds with no frozen records succeeds with them.
Premise: every record is policy-only. [SRC] src/frozentxo.cpp:52–62 at 6504a3af.

### `s6_ranged_frozen_refused_in_range` (`lean/BsvChain/Properties/Frozen.lean:274`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

(b), inside: a spend of an output whose ranged record holds an interval
containing the block's height is refused by the transaction's application on
the block path with `bad-txns-inputs-frozen`, code 0x13. Premises: block path,
not coinbase, the structural loops pass, inputs available, not a confiscation
transaction, the head input `i` has a ranged record with an interval `iv`
containing `ctx.height`. [SRC] src/frozentxo_db.h:353–377, src/frozentxo.cpp:52–62
and src/validation.cpp:2594–2607 at 6504a3af.

### `s6_ranged_frozen_block_step` (`lean/BsvChain/Properties/Frozen.lean:300`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

(b), inside, at the block's transaction step: when the block's own input
checks pass for the transaction, the run stops with the frozen verdict 0x13.
Premises: those of `s6_ranged_frozen_refused_in_range` and `checkBlockInputs`
succeeding for the transaction. [SRC] src/validation.cpp:3324–3411 at 6504a3af.

### `runBlockTransactions_append_error` (`lean/BsvChain/Properties/Frozen.lean:320`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

A block's transaction run whose prefix succeeds fails exactly as its suffix
fails from where the prefix ends. Premises: the prefix run from view `s` and
sigop total `total` succeeds with the receipt `r` (its final view `r.coins` and
running total `r.sigops`); the suffix run from that view and total fails with
`e`. [SRC] src/validation.cpp:3290–3447 at 6504a3af.

### `runBlockTransactions_frozen_step` (`lean/BsvChain/Properties/Frozen.lean:352`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

(b), inside, at the block's transaction step, for any effective projection:
when the block's own input checks pass for the transaction and its head input
is frozen on the block path at the context's height, the run stops with the
frozen verdict 0x13. Premises: block path, not coinbase, the structural loops
pass, inputs available, not a confiscation transaction, the head input `i`
frozen in `lists` there, and `checkBlockInputs` succeeding for the transaction.
[SRC] src/validation.cpp:2594–2607,3324–3411 at 6504a3af.

### `s6_ranged_frozen_connect_rejected` (`lean/BsvChain/Properties/Frozen.lean:374`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

(b), inside, at block connection: `connectBlock` rejects a block whose
ordinary transaction spends an output with a ranged record holding an interval
that contains the block's height `H`, with the frozen verdict, code 0x13, and
the header left valid (`corruptionPossible` false). The lists are the records'
projection adjusted for a block outside an explicit soft consensus freeze, with
any whitelist waiver `w`. Premises: the connection's preparation succeeds for a
non-genesis block (`some ctx`); the body is a prefix `pre`, then the offending
transaction `tx`, then any suffix; `pre` runs successfully from the coins view
with sigop total zero, ending in the view `r.coins` and total `r.sigops`;
`cap` is the block's pre-Genesis sigop cap; in that view `tx` is not coinbase,
passes the structural loops, has its inputs available, is not a confiscation
transaction and passes the block's own input checks; its head input `i` has a
ranged record with an interval `iv` containing `H`. Whether the prefix and the
earlier stages succeed is not decided here: they are premises.
[SRC] src/validation.cpp:3021–3050,3290–3411, src/frozentxo.cpp:39–62 and
src/frozentxo_db.h:353–377 at 6504a3af.

### `s6_ranged_frozen_outside_not_consulted` (`lean/BsvChain/Properties/Frozen.lean:428`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now`.

(b), outside: at a block height `H` where no record is frozen on the ranged
predicate (in particular a ranged record outside all its intervals), block
connection is exactly connection with no frozen records: the same block
connects, its frozen check passing, under the same other premises.
[SRC] src/frozentxo.cpp:52–62 and src/frozentxo_db.h:353–377 at 6504a3af.

### `s6_ranged_outside_intervals` (`lean/BsvChain/Properties/Frozen.lean:442`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

(b), the interval reading: a ranged record outside every interval is not
frozen on the ranged predicate. [SRC] src/frozentxo_db.h:367–376 at 6504a3af.

### `s6_whitelisted_confiscation_lists_inert` (`lean/BsvChain/Properties/Frozen.lean:453`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `UtxoContext`); `oracle` is not an argument of the statement.

(c), listed: a confiscation transaction listed with an enforce height at
most `ctx.height` is judged by the input stage, on either path, exactly as with
nothing frozen and every transaction listed: availability, its contents,
maturity and values decide, the operator lists nothing further. Premises: a
confiscation transaction; listed; the height at or beyond the enforce height.
[SRC] src/validation.cpp:2562–2611 and src/frozentxo.cpp:133–141 at 6504a3af.

### `s6_whitelisted_confiscation_applies` (`lean/BsvChain/Properties/Frozen.lean:470`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

(c), listed, the whole application: on either path the listed confiscation
transaction's application is its application with nothing frozen and every
transaction listed. Same premises. [SRC] src/validation.cpp:2552–2665,2864–2868
at 6504a3af.

### `s6_unlisted_confiscation_refused` (`lean/BsvChain/Properties/Frozen.lean:484`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `UtxoContext`); `oracle` is not an argument of the statement.

(c), unlisted: a confiscation transaction with valid contents that is not
listed, or listed above `ctx.height`, is refused on either path with
`bad-ctx-not-whitelisted` (code 0x10) by the records' projection (no depth
waiver). Premises: inputs available; a confiscation transaction with valid
contents; no record at or below `ctx.height`.
[SRC] src/validation.cpp:2562–2586 and src/frozentxo.cpp:133–171 at 6504a3af.

### `s6_waiver_block_path_only` (`lean/BsvChain/Properties/Frozen.lean:506`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

(c), the waiver: with the depth waiver on, the block path admits every
confiscation transaction's whitelist check; admission is unchanged. No premise.
[SRC] src/frozentxo.cpp:158–165 and src/validation.cpp:3530–3555 at 6504a3af.

### `s6_confiscated_frozen_everywhere` (`lean/BsvChain/Properties/Frozen.lean:514`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

(c), confiscated outputs: an output whose found record is on the
confiscation list is frozen on both paths at every height in the unadjusted
projection `d.project`. The connecting block's adjustments (`atBlock`) can
waive the block-path check: an explicit soft consensus freeze makes it a no-op,
and the depth waiver admits every confiscation transaction's whitelist check.
Premises: the output's record is found and is on the confiscation list.
[SRC] src/frozentxo_db.h:213–218,325–328,355–359 and src/frozentxo.cpp:39–42,158–165
at 6504a3af.

### `s6_explicit_freeze_check_noop` (`lean/BsvChain/Properties/Frozen.lean:531`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

(d): `Check` is a no-op on the block path of a block in an explicit soft
consensus freeze. No premise. [SRC] src/frozentxo.cpp:39–42 and
src/frozentxo.h:49 at 6504a3af.

### `s6_explicit_freeze_connection_lists` (`lean/BsvChain/Properties/Frozen.lean:538`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

(d), at connection: when the connecting index is in an explicit soft
consensus freeze (its explicit count, read from the current tree, at least
zero), the derived projection freezes nothing on the block path and leaves the
admission path unchanged. [SRC] src/frozentxo.cpp:27–42 and
src/block_index.h:569–574 at 6504a3af.

### `s6_explicit_freeze_connects_unfrozen` (`lean/BsvChain/Properties/Frozen.lean:554`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now`.

(d), the connected block: in an explicit soft consensus freeze the block
connects exactly as with no output frozen. No further premise.
[SRC] src/frozentxo.cpp:39–42 and src/validation.cpp:3376–3407 at 6504a3af.

## `BsvChain.Properties.Mempool`

### `accepted_spend_conflict` (`lean/BsvChain/Properties/Mempool.lean:17`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

An indexed accepted spend refuses the conflict stage with the source's
exact internal code and reason. The returned work is identical: replacement
cannot occur in this branch. The prefix must have succeeded to reach it.
[SRC] src/validation.cpp:1147–1152 and src/txmempool.cpp:2257–2280 at 6504a3af.

### `held_spend_conflict` (`lean/BsvChain/Properties/Mempool.lean:27`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Held locks refuse final requests outside the finalising-update exception.
An unconditional law for all held locks would contradict the pinned source.
[SRC] src/txmempool.cpp:2265–2280 and src/time_locked_mempool.cpp:114–156 at 6504a3af.

### `orphan_arrival_never_accepts` (`lean/BsvChain/Properties/Mempool.lean:36`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `now`; `params` and `oracle` are not arguments of the statement.

Definitional projection helper: retryOrphans writes only collected and
pending. The substantive selection/enqueue law is orphan_parent_enqueues below;
full validation is still required for every orphan.
[SRC] src/orphan_txns.cpp:256–350 and src/txn_validator.cpp:695–724 at 6504a3af.

### `pending_reuses_accept` (`lean/BsvChain/Properties/Mempool.lean:45`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

A queued orphan is re-evaluated by accept, which can still refuse it.
This is the connection between the retry transition and all admission stages.
[SRC] src/txn_validator.cpp:567–578,695–724 at 6504a3af.

### `detector_last` (`lean/BsvChain/Properties/Mempool.lean:56`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

Every completed earlier result is independent of the late detector
observation. Its argument is unavailable to beforeDetector and the trace stops
before insertion, regardless of the two concurrent-spend observations.
[SRC] src/validation.cpp:1484–1494 and src/txmempool.h:1380–1389 at 6504a3af.

### `promote_entry_ids` (`lean/BsvChain/Properties/Mempool.lean:71`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

Promotion edits metadata only. This helper lets maintenance proofs ignore
fee sorting, floating-point rates and the configured propagation bound.
[SRC] src/txmempool.cpp:383–405,452–565 at 6504a3af.

### `promote_loop_ids` (`lean/BsvChain/Properties/Mempool.lean:87`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

Propagating primary promotion preserves every accepted transaction id.
[SRC] src/txmempool.cpp:481–565 at 6504a3af.

### `remove_staged_ids` (`lean/BsvChain/Properties/Mempool.lean:102`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

Group repair changes metadata, so the removal set is exactly the staged
ids. In particular, a younger descendant is removed only through that set.
[SRC] src/txmempool.cpp:2130–2198 at 6504a3af.

### `expire_removes_only_expiry_closure` (`lean/BsvChain/Properties/Mempool.lean:120`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `now`; `params` and `oracle` are not arguments of the statement.

Expiry's exact removal law: the strict-age roots and their descendants.
This corrects an age-only statement, which the reference does not satisfy.
[SRC] src/txmempool.cpp:2201–2220 at 6504a3af.

### `expiry_root_is_old` (`lean/BsvChain/Properties/Mempool.lean:128`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `now`; `params` and `oracle` are not arguments of the statement.

Each expiry root really is older than the configured age; equality stays.
[SRC] src/txmempool.cpp:2201–2207 at 6504a3af.

### `trim_at_limit` (`lean/BsvChain/Properties/Mempool.lean:135`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

No eviction is performed at or below the configured size boundary.
[SRC] src/txmempool.cpp:2736–2737 at 6504a3af.

### `eviction_candidate_mem` (`lean/BsvChain/Properties/Mempool.lean:142`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A selected candidate is an accepted entry, including the total extension
for an inconsistent cyclic model state.
[SRC] src/txmempoolevictioncandidates.cpp:170–174 at 6504a3af.

### `eviction_none_empty` (`lean/BsvChain/Properties/Mempool.lean:154`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The total candidate selector returns none only for an empty pool.
[SRC] src/txmempool.cpp:2736–2737 at 6504a3af.

### `descendant_root_mem` (`lean/BsvChain/Properties/Mempool.lean:167`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Descendant closure retains each root that was an accepted entry.
[SRC] src/txmempool.cpp:2206–2218,2748–2750 at 6504a3af.

### `eviction_decreases` (`lean/BsvChain/Properties/Mempool.lean:186`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

Each eviction removes at least its selected accepted entry; metadata
repair cannot restore it. This is the finite progress fact for the size law.
[SRC] src/txmempool.cpp:2748–2763 at 6504a3af.

### `bump_preserves_size` (`lean/BsvChain/Properties/Mempool.lean:204`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

The rolling fee update touches no entries or memory-accounting fields.
[SRC] src/txmempool.cpp:1365–1383 at 6504a3af.

### `trim_loop_bound` (`lean/BsvChain/Properties/Mempool.lean:213`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

Enough live-entry fuel reaches the source loop's stop condition. The
empty alternative is necessary when mapDeltas allocations exceed the cap.
[SRC] src/txmempool.cpp:2097–2110,2736–2792 at 6504a3af.

### `trim_size_bound` (`lean/BsvChain/Properties/Mempool.lean:245`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

After trimming, usage is at most the requested cap or no transaction
remains. The latter covers retained mapDeltas allocations, which the source
keeps even for absent ids. With zero residual allocation it implies the cap.
[SRC] src/txmempool.cpp:2097–2110,2736–2792 at 6504a3af.

### `trim_byte_only_bound` (`lean/BsvChain/Properties/Mempool.lean:253`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

With byte-only accounting, an empty pool has zero usage, so the size law
has no residual-allocation exception. Equality with the cap is permitted.
[SRC] src/txmempool.cpp:2097–2110,2736–2792 at 6504a3af.

### `admission_conflict_rejects` (`lean/BsvChain/Properties/Mempool.lean:263`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

Reaching the conflict stage after the ordered prefix gives the exact
conflict verdict before inputs, fees, scripts or detector insertion can run.
The prefix assumptions expose why a malformed conflict can have another code.
[SRC] src/validation.cpp:1031–1152 at 6504a3af.

### `reindex_spend_index` (`lean/BsvChain/Properties/Mempool.lean:288`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Rebuilding the index establishes the accepted-entry/index connection.
[SRC] src/txmempool.cpp:758–774 at 6504a3af.

### `accepted_member_conflicts` (`lean/BsvChain/Properties/Mempool.lean:294`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

An actual accepted spender and a shared outpoint imply the indexed conflict
predicate, under the pool's spend-index invariant. Held entries are separate.
[SRC] src/txmempool.cpp:758–774,2257–2280 at 6504a3af.

### `accept_preserves_accepted_spender` (`lean/BsvChain/Properties/Mempool.lean:308`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

The complete accept transition refuses a competing accepted spend and
retains the earlier entry, provided the P2P filter permits submission and the
ordered earlier gates succeed. Those gates may otherwise report another reason.
The ready work differs only in its finality judgment. Held locks have the
finalising-update exception and valid non-final updates can replace a held
entry; neither exception replaces an accepted spender.
[SRC] src/validation.cpp:1031–1152, src/txmempool.cpp:758–774,2257–2280 and
src/time_locked_mempool.cpp:67–85 at 6504a3af.

### `collect_orphan_child_retains` (`lean/BsvChain/Properties/Mempool.lean:343`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

Adding a secondary child never discards a selected retained request.
[SRC] src/orphan_txns.cpp:329–346 at 6504a3af.

### `expand_orphan_retains` (`lean/BsvChain/Properties/Mempool.lean:353`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

Secondary breadth traversal retains every direct selected orphan, whatever
batch cap or finite traversal fuel is supplied. Direct children bypass that cap.
[SRC] src/orphan_txns.cpp:278–350 at 6504a3af.

### `orphan_parent_enqueues` (`lean/BsvChain/Properties/Mempool.lean:380`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `now`; `params` and `oracle` are not arguments of the statement.

A collected parent output selects its dependent orphan's retained request
and enqueues that request, changing only its acceptance timestamp. This models
a retry scheduling event after the handler's cancellation/duplicate filtering;
the caller supplies the remaining eligible orphan set and explicit order.
No assumption that all other parents arrived or validation will pass is made.
[SRC] src/orphan_txns.cpp:278–301 and src/txn_validator.cpp:695–719 at 6504a3af.

### `selected_orphan_reuses_accept` (`lean/BsvChain/Properties/Mempool.lean:401`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

A dependent orphan selected by arrival can enter the accepted set only via
full accept when its queued work is scheduled. The head premise exposes the
scheduler's order; parent arrival itself preserves the accepted set and index.
The queued request retains every override apart from the refreshed timestamp.
[SRC] src/orphan_txns.cpp:278–301 and src/txn_validator.cpp:695–719 at 6504a3af.

### `run_stages_trace_subset` (`lean/BsvChain/Properties/Mempool.lean:420`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A stopped trace contains only stages actually present in its ordered list.
This helper covers every refusal, defer and explicit model decline uniformly.
[SRC] src/validation.cpp:1031–1494 at 6504a3af.

### `run_stages_success_trace` (`lean/BsvChain/Properties/Mempool.lean:435`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

If an ordered stage list continues throughout, its trace is the whole list.
Thus the successful validation prefix ends in scripts, before insertion.
[SRC] src/validation.cpp:1031–1485 at 6504a3af.

### `accept_stopped_before_detector` (`lean/BsvChain/Properties/Mempool.lean:452`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

Every accept trace stopped during validation omits detector insertion.
Inventory suppression also has no detector stage. Unlike independence alone,
this statement forbids insertion in every earlier stopped trace.
[SRC] src/validation.cpp:1481–1494 and src/txmempool.h:1386–1390 at 6504a3af.

### `accept_detector_after_scripts` (`lean/BsvChain/Properties/Mempool.lean:482`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

A successful validation prefix reaches detector insertion immediately after
scripts, even if the detector or commit then refuses the request. The explicit
submission premise excludes inventory suppression. The suffix is harness trace
metadata and makes no promise of successful commit.
[SRC] src/validation.cpp:1481–1494 and src/txmempool.h:1386–1390 at 6504a3af.

## `BsvChain.Properties.Merkle`

### `verifyPath_empty` (`lean/BsvChain/Properties/Merkle.lean:29`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: a sibling-free check equates only the two byte words.
[SRC] src/consensus/merkle.cpp:291-310 at 6504a3af.

### `merkleLevel_length` (`lean/BsvChain/Properties/Merkle.lean:37`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the next level has the ceiling of half the leaf count.
This establishes sufficient reduction fuel and index range after shifting.
[SRC] src/consensus/merkle.cpp:57-178,263-270 at 6504a3af.

### `merkleLevel_get` (`lean/BsvChain/Properties/Merkle.lean:49`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: an in-range child and its sibling hash to the indexed
parent. This is the pairwise calculation used by completeness; synthetic
padding does not claim a second transaction exists.
[SRC] src/consensus/merkle.cpp:57-178 at 6504a3af.

### `branchReduce_complete` (`lean/BsvChain/Properties/Merkle.lean:75`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: completeness for the source's literal branch,
assuming an in-range position, enough fuel that the leaf count is at most
fuel plus one, and non-null branch literals. A zero literal is interpreted
as a marker by RootFromBranch. The non-null premise is independent of mutation.
[SRC] src/consensus/merkle.cpp:284-310 at 6504a3af.

### `computeBranch_complete` (`lean/BsvChain/Properties/Merkle.lean:123`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: an in-range transaction's generated path verifies the
body root. Mutation false is the block acceptance side condition, although
root recomputation itself also works for mutated bodies. Literal null nodes
need the separate source-marker restriction described above.
[SRC] src/consensus/merkle.cpp:284-327; src/validation.cpp:5770-5781 at 6504a3af.

### `branchPair_leaf` (`lean/BsvChain/Properties/Merkle.lean:157`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: assuming all four leaf/sibling words have 32 bytes
and the two ordered concatenations are equal at the same supplied index,
the working leaves are equal. The marker still puts the working leaf on
the index-selected side.
[SRC] src/consensus/merkle.cpp:296-306 at 6504a3af.

### `path_leaf_of_commitment` (`lean/BsvChain/Properties/Merkle.lean:183`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: two equal-depth paths at the same supplied index,
with 32-byte leaves and siblings and equal computed roots, have equal leaves
under the explicit HashCommits hypothesis: SHA256d is injective on the
inputs touched by these two paths. Siblings may be externally supplied;
canonical sibling equality is not a premise. [SRC] src/consensus/merkle.cpp:291-310 at 6504a3af.

### `path_leaf_or_collision` (`lean/BsvChain/Properties/Merkle.lean:217`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: assuming equal path depths, a common supplied index,
32-byte leaves and siblings on both paths, and equal computed roots, the
leaves are equal or two distinct touched inputs have equal SHA256d outputs.
The collision witness is restricted to these two paths. No HashCommits
hypothesis is needed for this disjunction.
[SRC] src/consensus/merkle.cpp:43-50,291-310 at 6504a3af.

### `active_path_inclusion_or_collision` (`lean/BsvChain/Properties/Merkle.lean:250`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: identifier inclusion at the active height or a collision
between distinct touched inputs, assuming AuthenticatedBody as fully unpacked
in its explainer above: active-height lookup, tree lookup, matching height,
retained body, matching headers, header/body-root binding and mutation false.
The position must be in range; the supplied path must have the body branch
depth at that same index; both paths must have 32-byte leaves and siblings;
canonical branch literals must be non-null. The supplied path must verify
successfully against the header merkle root. No HashCommits hypothesis is
needed for this identifier-membership-or-collision disjunction.
[SRC] src/consensus/merkle.cpp:284-327; src/validation.cpp:5770-5781 at 6504a3af.

### `active_path_inclusion` (`lean/BsvChain/Properties/Merkle.lean:283`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: wallet identifier inclusion at the named active height
assumes AuthenticatedBody: active-height lookup, tree lookup, matching height,
retained body, matching headers, header/body-root binding and mutation false.
It also assumes an in-range position, equal supplied/body branch depth at
the same index, 32-byte leaves and siblings on both paths, non-null canonical
literals, and successful verification against the header merkle root.
HashCommits is an explicit hypothesis excluding distinct-input SHA256d
collisions on the inputs touched by these two paths, never an axiom.
[SRC] src/consensus/merkle.cpp:43-50,284-327 at 6504a3af.

### `active_path_transaction` (`lean/BsvChain/Properties/Merkle.lean:310`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: exact Lean transaction membership assumes AuthenticatedBody:
active-height lookup, tree lookup, matching height, retained body, matching
headers, header/body-root binding and mutation false. It also assumes an
in-range position, equal supplied/body branch depth at the same index,
32-byte leaves and siblings on both paths, non-null canonical literals,
HashCommits on their touched inputs, and successful verification of the
supplied transaction identifier against the header merkle root. The additional
local txid injectivity premise says every body transaction with that identifier
equals the supplied transaction. It excludes distinct aliases on this local
domain; it does not exclude the same noncanonical record whose serializer
truncates wire fields.
[SRC] src/consensus/merkle.cpp:312-327 at 6504a3af.

### `leNat_bytes_lt` (`lean/BsvChain/Properties/Merkle.lean:368`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: bounded byte words fit their little-endian frame.
This permits header normalization without evaluating a hash in the kernel.
[SRC] src/primitives/block.h:26-45 at 6504a3af.

### `headerWordBytes_leNat` (`lean/BsvChain/Properties/Merkle.lean:381`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: byte-valued words survive header encode after decode.
[SRC] src/primitives/block.h:26-45 at 6504a3af.

### `sha256d_bytes` (`lean/BsvChain/Properties/Merkle.lean:394`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the existing hash emits byte-valued words. This is
representation, not a cryptographic assumption.
[SRC] src/consensus/merkle.cpp:291-310 (uint256 hash words) at 6504a3af.

### `stale_path_witness` (`lean/BsvChain/Properties/Merkle.lean:404`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the countermodel has a header-valid body-derived path,
yet no active transaction. This kernel proof uses neither native_decide nor
an assumption about SHA256. The executable transition witness uses a mined
two-transaction body instead of this minimal raw-state countermodel.
[SRC] src/consensus/merkle.cpp:291-310 at 6504a3af.

### `stale_path_does_not_entail_active` (`lean/BsvChain/Properties/Merkle.lean:427`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: stale-header validity does not imply active-body inclusion.
The counterexample refutes the universal implication even when the retained
stale body contains the transaction. A stronger valid-transition witness is
executed by ChainCheck's orphanedProofCase on the assumed intake prefix.
[SRC] src/consensus/merkle.cpp:291-310; src/validation.cpp:5230-5330 at 6504a3af.

## `BsvChain.Properties.MerkleProof`

### `txBit_lt` (`lean/BsvChain/Properties/MerkleProof.lean:26`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: flag bit 0 is a bit.

### `targetKind_lt` (`lean/BsvChain/Properties/MerkleProof.lean:29`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the target kind is one of the three the standard assigns.

### `tsc_flags_lt` (`lean/BsvChain/Properties/MerkleProof.lean:32`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the flags byte of the simple standard is below 8: bits 3 and
4 (the extensions) are clear. [LIT] the TSC flags table.

### `readNode_encodeNode` (`lean/BsvChain/Properties/MerkleProof.lean:40`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: a node reads back from its binary form: a 32-byte hash after
the type byte 0, or the type byte 1 alone. [LIT] the TSC node layout.

### `decodeTxOrId_encodeTxOrId` (`lean/BsvChain/Properties/MerkleProof.lean:51`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the `txOrId` field reads back under its own flag bit.
[LIT] the TSC `txLength` and `txOrId` fields.

### `decodeTarget_encodeTarget` (`lean/BsvChain/Properties/MerkleProof.lean:64`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the `target` field reads back under its own kind: a 32-byte
word, or the header frame by #63's `header_decodePrefix_encode`.

### `tsc_decodePrefix_encode` (`lean/BsvChain/Properties/MerkleProof.lean:79`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-13, #75 (the TSC round trip). For every well-formed proof, the
binary decoder reads the encoder's bytes back exactly and leaves any following
stream untouched. Premise in plain words: the proof is well formed (`wf`): a
CompactSize index and node count, a 32-byte id or a transaction of CompactSize
length, a 32-byte hash or root target (the header target is typed), 32-byte hash
nodes. The byte values of the words are the caller's domain, as in #68's G4.
[LIT] the TSC binary layout; [SRC] src/serialize.h:296-340 at 6504a3af for CompactSize.

### `tsc_decode_encode` (`lean/BsvChain/Properties/MerkleProof.lean:101`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-13, #75: `decode (encode p) = some p` for well-formed proofs.
Premise: `wf` as in `tsc_decodePrefix_encode`.

### `tsc_encode_injective` (`lean/BsvChain/Properties/MerkleProof.lean:109`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the encoder is injective on well-formed proofs, so equal
bytes are equal proofs.

### `branchPair_zero` (`lean/BsvChain/Properties/MerkleProof.lean:117`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: a null sibling and the running hash itself make the same
pair: the marker and the duplicated node hash alike. [SRC] src/consensus/merkle.cpp:297-301
at 6504a3af.

### `branchPair_self` (`lean/BsvChain/Properties/MerkleProof.lean:123`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-14: pairing the running word with itself gives (leaf, leaf) for
every index, including the null-word case. No premise.

### `computeRootFromBranch_tscPath` (`lean/BsvChain/Properties/MerkleProof.lean:129`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-13, #75: the marker reading and the recomputed reading agree.
Resolving every `*` to the running hash of its level (`tscPath`) and reading
`*` as the null word the reference duplicates (`markerPath`) compute the same
root from the same leaf and index, for every node list. No premise.
[SRC] src/consensus/merkle.cpp:291-310, src/rpc/rawtransaction.cpp:2601-2607 at 6504a3af.

### `verifyTsc_eq_verifyPath` (`lean/BsvChain/Properties/MerkleProof.lean:148`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-13, #75: proof verification is #65's `verifyPath` over the
resolved path. Whenever the target supplies a root (`h`: a merkle root, a
header, or a block hash bound to a supplied header), `verifyTsc` equals
`verifyPath leaf (tscPath leaf nodes index) index root`, the leaf being the id
or the carried transaction's id. Premise: `h` only. Root equality, not
inclusion: #65's commitment and shape premises stay where they are.
[SRC] src/consensus/merkle.cpp:291-310, src/rpc/rawtransaction.cpp:2503-2518,2610-2611 at 6504a3af.

### `verifyTsc_hash_needs_header` (`lean/BsvChain/Properties/MerkleProof.lean:161`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the strongest relation for a bare block-hash target: with no
header supplied there is no root, so verification is false; the hash target is
the standard's envelope case and needs the header resolved by the hash.
[LIT] the TSC target type 0; [SRC] src/rpc/rawtransaction.cpp:2512-2514 at 6504a3af.

### `resolveTarget_hash` (`lean/BsvChain/Properties/MerkleProof.lean:169`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: a block-hash target resolves only through a header whose hash
is the target word, and then to that header's root.

### `siblingAt_last` (`lean/BsvChain/Properties/MerkleProof.lean:180`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the sibling of the last position of a level with an odd count
is the position's own word: the reference duplicates the last node.
[SRC] src/consensus/merkle.cpp:57-178; src/merkletree.cpp:322-334 at 6504a3af.

### `tscBranchReduce_complete` (`lean/BsvChain/Properties/MerkleProof.lean:196`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-13, #75 (completeness of the node's own branch). For an in-range
position of a leaf list, enough fuel (the leaf count at most fuel plus one, as
`computeMerkleRoot` supplies) and non-null hash nodes, the marker branch the
node serves (`tscBranchReduce`, the model of `GetMerkleProof` with
`skipDuplicates`) recomputes the body root from the leaf at that position,
read as the node's `verifymerkleproof` reads it. Premises in plain words: the
position is in range, the fuel suffices, and no hash node is the null word
(a null literal would be read as a marker, #65's restriction).
[SRC] src/merkletree.cpp:294-346, src/consensus/merkle.cpp:291-310 at 6504a3af.

### `bodyProof_verifies` (`lean/BsvChain/Properties/MerkleProof.lean:258`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-13, #75: the proof the node serves for a body verifies as a TSC
proof. For an in-range position of a leaf list with non-null hash nodes,
`verifyTsc (bodyProof leaves index)` holds with no header supplied, the target
being the body's root. Premises: the position in range and the non-null hash
nodes of `tscBranchReduce_complete`. [SRC] src/rpc/rawtransaction.cpp:2437-2460,2516-2518,
src/consensus/merkle.cpp:247-282,291-310 at 6504a3af.

### `tscBranchReduce_single` (`lean/BsvChain/Properties/MerkleProof.lean:270`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-13, #75 (the one-transaction boundary). The node's branch
generator yields the empty vector for a one-leaf body at every position and
fuel; `getmerkleproof` and `getmerkleproof2` refuse an empty vector with RPC
`-5` (`Transaction(s) not found in provided block`), so the node supplies no
proof for a lone transaction. The body-derived reading, `verifyPath leaf [] 0 leaf`,
is #65's `verifyPath_empty`. No premise. [SRC] src/merkletree.cpp:335-339,
src/rpc/rawtransaction.cpp:2302-2306,2447-2450 at 6504a3af.

### `verifyTsc_single` (`lean/BsvChain/Properties/MerkleProof.lean:281`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the empty marker branch and the body-derived empty path
agree: both equate the leaf and the root. [SRC] src/consensus/merkle.cpp:291-310 at 6504a3af.

## `BsvChain.Properties.MinerId`

### `readInstr_direct` (`lean/BsvChain/Properties/MinerId.lean:27`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a direct push opcode (1 to 75) reads that many bytes.
[SRC] src/script/instruction_iterator.h:34-42 at 6504a3af.

### `readInstr_pd1` (`lean/BsvChain/Properties/MinerId.lean:34`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: `OP_PUSHDATA1` reads a one-byte length. [SRC] src/script/instruction_iterator.h:44-50 at 6504a3af.

### `readInstr_pd2` (`lean/BsvChain/Properties/MinerId.lean:40`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: `OP_PUSHDATA2` reads a two-byte length. [SRC] src/script/instruction_iterator.h:52-63 at 6504a3af.

### `readInstr_pd4` (`lean/BsvChain/Properties/MinerId.lean:46`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: `OP_PUSHDATA4` reads a four-byte length. [SRC] src/script/instruction_iterator.h:65-75 at 6504a3af.

### `readOperand_pushData` (`lean/BsvChain/Properties/MinerId.lean:52`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a minimal push reads back as its operand, with any following stream
untouched; the empty push is `OP_0`, read as the empty operand.
[SRC] src/script/script.h:104-133, src/script/instruction_iterator.h:19-77 at 6504a3af.

### `readOperand_pushData_nil` (`lean/BsvChain/Properties/MinerId.lean:97`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the same with nothing after the push.

### `pushData_head` (`lean/BsvChain/Properties/MinerId.lean:102`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a minimal push begins with a push opcode (at most `OP_PUSHDATA4`), so
`IsMinerId`'s byte-7 test holds for every encoded output. [SRC] src/script/script.cpp:206 at 6504a3af.

### `readOperand_nil` (`lean/BsvChain/Properties/MinerId.lean:116`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the empty stream has no instruction (the iterator at the end).
[SRC] src/script/instruction_iterator.h:22-23 at 6504a3af.

### `readBytes_of_length` (`lean/BsvChain/Properties/MinerId.lean:120`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a byte string of the stated length reads back.
[SRC] src/serialize.h:786-792 at 6504a3af.

### `minerIdOutput_decode_encode` (`lean/BsvChain/Properties/MinerId.lean:125`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the 0.1/0.2 output a miner writes reads back: the static document and
signature (non-empty, as the node requires) and the dynamic pair when present.
[SRC] src/miner_id/miner_id.cpp:454-555, src/script/script.cpp:198-207 at 6504a3af.

### `readVersion_push` (`lean/BsvChain/Properties/MinerId.lean:153`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the version push reads back. [SRC] src/miner_id/miner_info_ref.cpp:77-87 at 6504a3af.

### `minerInfoRef_parse_encode` (`lean/BsvChain/Properties/MinerId.lean:157`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the coinbase's 0.3 reference reads back when its fields have the sizes
the node checks (a 32-byte txid and hash, a signature of 64 to 72 bytes).
[SRC] src/miner_id/miner_info_ref.cpp:60-114 at 6504a3af.

### `minerInfoFrame_decode_encode` (`lean/BsvChain/Properties/MinerId.lean:177`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the miner-info output's frame reads back.
[SRC] src/miner_id/miner_info_doc.cpp:445-491 at 6504a3af.

### `dataRefJson_script` (`lean/BsvChain/Properties/MinerId.lean:195`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the dataref output's JSON reads back.
[SRC] src/miner_id/miner_info.cpp:231-262 at 6504a3af.

### `revokeMid_decode_encode` (`lean/BsvChain/Properties/MinerId.lean:207`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the `revokemid` message reads back when its keys are valid and each
signature is shorter than 256 bytes (its length is one byte).
[SRC] src/miner_id/revokemid.h:49-97, src/miner_id/revokemid.cpp:37-60 at 6504a3af.

### `lookupId_putId` (`lean/BsvChain/Properties/MinerId.lean:234`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a lookup after an insertion under the same key finds the inserted entry,
and under another key finds what was there. [SRC] src/miner_id/miner_id_db.cpp:571-600 at 6504a3af.

### `lookupId_unlinkRecent` (`lean/BsvChain/Properties/MinerId.lean:253`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: unlinking recent blocks touches no id.

### `lookupId_putMiner` (`lean/BsvChain/Properties/MinerId.lean:256`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the miner table's update touches no id.

### `lookupMiner_putMiner` (`lean/BsvChain/Properties/MinerId.lean:259`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a lookup of the miner just written finds it.

### `goodReputation_void` (`lean/BsvChain/Properties/MinerId.lean:263`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a miner whose reputation is void fails the reputation test, whatever its
recent blocks. [SRC] src/miner_id/miner_id_db.cpp:299-329 at 6504a3af.

### `goodReputation_state_blind` (`lean/BsvChain/Properties/MinerId.lean:270`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the reputation test does not read the id's state: re-writing the entry
with any other state, the same miner, leaves the answer as it was. So a ROTATED or REVOKED
id answers as its miner does. [SRC] src/miner_id/miner_id_db.cpp:299-329 (no read of
`mState`) at 6504a3af.

### `invalidBlock_voids` (`lean/BsvChain/Properties/MinerId.lean:282`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: after an invalid block signed by a CURRENT id whose miner is known, that
id fails the reputation test. [SRC] src/miner_id/miner_id_db.cpp:205-239,299-329 at 6504a3af.

### `revokeUpTo_revokes` (`lean/BsvChain/Properties/MinerId.lean:305`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: revoking up to a key that the list holds leaves that key REVOKED.
[SRC] src/miner_id/miner_id_db.cpp:275-285,1042-1076 at 6504a3af.

### `processRevokemid_revokes` (`lean/BsvChain/Properties/MinerId.lean:324`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a `revokemid` the database accepts leaves the compromised id REVOKED.
[SRC] src/miner_id/miner_id_db.cpp:242-296 at 6504a3af.

### `foldl_revoke_keep` (`lean/BsvChain/Properties/MinerId.lean:341`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: revoking entries under other keys leaves a key's entry as it was.

### `foldl_revoke` (`lean/BsvChain/Properties/MinerId.lean:357`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: revoking every entry of a list leaves each of its keys REVOKED.
[SRC] src/miner_id/miner_id_db.cpp:1103-1112 at 6504a3af.

### `fullRevocation_revokes_all` (`lean/BsvChain/Properties/MinerId.lean:378`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a full revocation the database accepts (the key does not roll) leaves
every id it listed for the miner REVOKED.
[SRC] src/miner_id/miner_id_db.cpp:1101-1127,1241-1250 at 6504a3af.

### `blockAdded_reuse_refused` (`lean/BsvChain/Properties/MinerId.lean:399`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a block whose (non-revoking) document reuses a key that the database
holds as not CURRENT changes no id entry: the reuse is refused (the reference throws at
src/miner_id/miner_id_db.cpp:949-953) and only the recent-blocks row and the best block move.
So a REVOKED or ROTATED id stays as it is.

### `addRecent_bounded` (`lean/BsvChain/Properties/MinerId.lean:420`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the recent-blocks table never holds more than N rows after an addition.
[SRC] src/miner_id/miner_id_db.cpp:1361-1374 at 6504a3af.

## `BsvChain.Properties.Oracle`

### `recordedOracle_of_lookup` (`lean/BsvChain/Properties/Oracle.lean:15`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A covered key returns precisely its recorded verdict. The sole assumption
is lookup success, including the column and complete effective parameters.
This is the loader-to-oracle boundary, independent of the recorded producer.
[SRC] src/validation.cpp:2503–2542 at 6504a3af.

### `recordedOracle_missing` (`lean/BsvChain/Properties/Oracle.lean:25`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

An uncovered call declines by name. No evaluation or other column can
supply a guessed verdict, even if most of the spend context agrees.
[SRC] src/validation.cpp:2538–2542 at 6504a3af.

### `recordOracle_lookup` (`lean/BsvChain/Properties/Oracle.lean:34`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `oracle`; `params`, `cfg` and `now` are not arguments of the statement.

Materialization preserves every covered call's answer for every producer.
Repeated identical calls have identical values because the producer is a
function. No uniqueness or signature-validity hypothesis is needed.
[SRC] src/validation.cpp:2523–2542 at 6504a3af.

### `recorded_oracle_agree` (`lean/BsvChain/Properties/Oracle.lean:52`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `oracle`; `params`, `cfg` and `now` are not arguments of the statement.

For ANY oracle, the oracle and a map recorded from it agree on every
covered call: replaying a recording returns the recorded producer's verdict.
[SRC] src/validation.cpp:2523–2542 at 6504a3af.

### `recorded_eval_agree` (`lean/BsvChain/Properties/Oracle.lean:61`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `oracle` fixed to the evaluator `evalOracle`; `params`, `cfg` and `now` are not arguments of the statement. General form: `recorded_oracle_agree`, quantified; this theorem is its instance.

The evaluator and a map recorded from it agree on every covered call.
This proves the construction, including actual ECDSA as a definition; the
executable separately checks columns already committed as corpus evidence.
The general form is `recorded_oracle_agree`, for every oracle; this theorem is
its instance at the evaluator. [SRC] src/validation.cpp:2523–2542 at 6504a3af.

### `inputEvalParams_flags_independent` (`lean/BsvChain/Properties/Oracle.lean:72`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

The resource selector leaves the word unchanged. Thus block-word policy
re-checks cannot be collapsed into ordinary block derivation. Resource limits
can differ, as checked by the corpus's selector boundary. This is a
definition-level law: the proof is `rfl`, because the selector is passed only
to the limits constructor; it adds no transition or cryptographic fact.
[SRC] src/validation.cpp:705–717,2693–2707 at 6504a3af.

### `applyTx_oracle_ext` (`lean/BsvChain/Properties/Oracle.lean:83`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

Pointwise equal oracles yield the same applyTx result, including undo and
rejections, for all configurations, times, network parameters and operator
lists. This permits substitution without weakening any inherited UTXO law.
The conservation, membership, retained/added lookup, determinism and undo
statements in Properties.Utxo already have unrestricted oracle parameters.
[SRC] src/validation.cpp:2480–2495,3326–3434 at 6504a3af.

## `BsvChain.Properties.P2P`

### `registered_omits_revokemid` (`lean/BsvChain/Properties/P2P.lean:22`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: thirty-eight names, thirty-seven registered, and the one
the registered list omits is `revokemid` (src/protocol.cpp:16-53,107-121 at
6504a3af; rule 15: the comment at :103-106 says the list keeps in step). The
per-command byte counters are keyed by the registered list. A view, never a rule.

### `vocabulary_frames` (`lean/BsvChain/Properties/P2P.lean:32`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: every command of the vocabulary except `extmsg` itself is
a command the frame carries: at most twelve printable bytes whose padded field
does not begin with `extmsg`. A view, never a rule.

### `extmsg_not_framed` (`lean/BsvChain/Properties/P2P.lean:38`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: `extmsg` as a basic command does not read back: its
field begins with `extmsg`, so the reader takes the next twenty bytes as
the extended fields (src/protocol.cpp:259-266 at 6504a3af). The name is the
marker of the extended header, never a message of its own. A view, never a rule.

### `readBytes_prefix` (`lean/BsvChain/Properties/P2P.lean:46`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a byte string of its own length reads back.

### `padCommand_length` (`lean/BsvChain/Properties/P2P.lean:51`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the padded command field is twelve bytes.

### `takeWhile_nonzero_append` (`lean/BsvChain/Properties/P2P.lean:56`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: NUL padding after a NUL-free command stops the scan.

### `stripCommand_padCommand` (`lean/BsvChain/Properties/P2P.lean:65`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: `GetCommand` recovers a command with no NUL from its field.

### `checksumOf_length` (`lean/BsvChain/Properties/P2P.lean:70`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the checksum is four bytes.

### `unframe_frame` (`lean/BsvChain/Properties/P2P.lean:74`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE FRAMING ROUND TRIP. For network magic of four bytes,
a command the frame carries (`CommandOk`) and any payload below 2^64 bytes,
the frame reads back the command and the payload and leaves the rest of the
stream untouched: through the basic header and its checksum up to 2^32 - 1
payload bytes, through the extended header above. [SRC] the writer
src/protocol.cpp:208-241, the reader :244-276, the payload and checksum
src/net/net_message.cpp:12-53 and src/net/net_processing.cpp:5054-5090 at
6504a3af. A view, never a rule: the frame decides what a node reads, never
what is valid.

### `frame_length` (`lean/BsvChain/Properties/P2P.lean:110`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the frame's size is the header's plus the payload's:
24 bytes of header up to 2^32 - 1 payload bytes, 44 above
(`GetHeaderSizeForPayload`, src/protocol.cpp:304-312 at 6504a3af). A view,
never a rule.

### `InvItem.read_encode` (`lean/BsvChain/Properties/P2P.lean:129`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: an inventory item whose type fits 32 bits and whose hash
is 32 bytes reads back. [SRC] src/protocol.h:555-561 at 6504a3af.

### `decodeInv_encodeInv` (`lean/BsvChain/Properties/P2P.lean:137`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the inventory payload of `inv`, `getdata` and `notfound`
reads back from its writer's bytes. [SRC] src/serialize.h:716-726,794-840 and
src/net/net_processing.cpp:2461-2462,2544-2545 at 6504a3af. A view, never a rule.

### `readVarBytes_encode` (`lean/BsvChain/Properties/P2P.lean:151`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a string or byte vector within its limit reads back.

### `Reject.decode_encode` (`lean/BsvChain/Properties/P2P.lean:159`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a well-formed `reject` (a command of at most twelve bytes,
a one-byte code, a reason within 111 bytes, a 32-byte hash exactly when the
rejected message is `block` or `tx`) reads back from its writer's bytes.
[SRC] the writer src/validation.cpp:1943-1950, the reader
src/net/net_processing.cpp:1491-1506 at 6504a3af. A view, never a rule.

### `decodeNonce_encode` (`lean/BsvChain/Properties/P2P.lean:195`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the `ping` and `pong` nonce reads back. [SRC]
src/net/net_processing.cpp:4212-4290 at 6504a3af. A view, never a rule.

### `Protoconf.decode_encode` (`lean/BsvChain/Properties/P2P.lean:202`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the writer's two-field `protoconf` reads back. [SRC]
src/protocol.h:596-626 at 6504a3af. A view, never a rule.

### `NetAddr.read_encode` (`lean/BsvChain/Properties/P2P.lean:217`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: an address with a 64-bit services word, sixteen address
bytes and a 16-bit port reads back. [SRC] src/protocol.h:503-514 and
src/net/netaddress.h:172-178 at 6504a3af.

### `Version.decode_encode` (`lean/BsvChain/Properties/P2P.lean:230`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the `version` message in the writer's full form reads
back. [SRC] the writer src/net/net_processing.cpp:149-154, the reader
:1704,1744-1770 at 6504a3af. A view, never a rule.

### `commandFormatOk_padCommand` (`lean/BsvChain/Properties/P2P.lean:264`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a command the frame carries passes the reader's format
check once padded (`CheckCommandFormat`, src/protocol.cpp:128-152 at 6504a3af).

### `commandFormatOk_extmsg` (`lean/BsvChain/Properties/P2P.lean:276`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the extended form's basic command `extmsg` passes the
format check (src/protocol.cpp:128-152,222-229 at 6504a3af).

### `frame_valid` (`lean/BsvChain/Properties/P2P.lean:280`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE WRITER'S HEADER IS VALID. For a command the frame
carries and a payload within its command's cap, the header the writer makes
passes the reader's validity check at the same magic: the magic, the command's
format, the cap, and for the extended form the extended command's format
(src/protocol.cpp:208-241 the writer, :174-190,329-365 `IsValid` and
`IsOversized` at 6504a3af). A view, never a rule.

### `s8_header_read` (`lean/BsvChain/Properties/P2P.lean:315`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: s8's bytes read as the `ping` header of 2 MiB + 1 bytes,
nothing left over (src/protocol.cpp:244-276 at 6504a3af).

### `s8_header_oversized` (`lean/BsvChain/Properties/P2P.lean:320`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE s8 HEADER IS OVER ITS CAP, and invalid; the same
header at exactly 2 MiB is not (src/protocol.cpp:88-93,192-195,329-365 at
6504a3af). A view, never a rule.

### `protoconf_cap_boundary` (`lean/BsvChain/Properties/P2P.lean:330`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: `protoconf` at 1 MiB and 1 MiB + 1 (src/protocol.cpp:65-69
at 6504a3af). A view, never a rule.

### `getblocktxn_cap_boundary` (`lean/BsvChain/Properties/P2P.lean:337`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: `getblocktxn` at its estimate, 1000001 / 215 * 6 + 24 =
27930 bytes, and one above (src/protocol.cpp:76-87,304-312 at 6504a3af). A
view, never a rule.

### `blockLike_cap_boundary` (`lean/BsvChain/Properties/P2P.lean:345`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the block-like commands at the block size and one above
(src/protocol.cpp:55-61,94-98 at 6504a3af): `block` and `hdrsen` at 1000001
and 1000002 bytes. A view, never a rule.

### `tx_cap_boundary` (`lean/BsvChain/Properties/P2P.lean:355`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: `tx` at the consensus transaction-size bound and one above
(`GetMaxTxSize(PostGenesis, true)`, src/protocol.cpp:70-75 at 6504a3af). A
view, never a rule.

### `basic_header_max_read` (`lean/BsvChain/Properties/P2P.lean:363`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a basic header whose length field is 0xffffffff, the
largest it holds, reads back from its bytes (src/protocol.cpp:244-276 at
6504a3af). A view, never a rule.

### `extended_header_read` (`lean/BsvChain/Properties/P2P.lean:378`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE EXTENDED HEADER AT 2^32. It reads back from its 44
bytes, names `block` and 2^32 payload bytes, and is over the cap of a block
size of 1000001 (src/protocol.cpp:244-302,329-365 at 6504a3af). A view, never
a rule.

## `BsvChain.Properties.Persist`

### `checkedStep_fst` (`lean/BsvChain/Properties/Persist.lean:45`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A checked step returns its work unchanged; only the outcome differs.

### `grows_of_frame` (`lean/BsvChain/Properties/Persist.lean:49`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A step that keeps the accepted pool, the request and the built entry satisfies the growth law.

### `grows_of_eq` (`lean/BsvChain/Properties/Persist.lean:57`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A step that returns its input work satisfies the growth law.

### `decayRollingFee_accepted` (`lean/BsvChain/Properties/Persist.lean:61`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `now`; `params` and `oracle` are not arguments of the statement.

The rolling fee's decay leaves the accepted pool unchanged.

### `limitOrphans_accepted` (`lean/BsvChain/Properties/Persist.lean:67`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `now`; `params` and `oracle` are not arguments of the statement.

Limiting the orphan pool leaves the accepted pool unchanged.

### `retainOrphan_accepted` (`lean/BsvChain/Properties/Persist.lean:75`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

Retaining an orphan leaves the accepted pool unchanged.

### `scriptFailure_fst` (`lean/BsvChain/Properties/Persist.lean:83`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A script failure returns its work unchanged; only the outcome differs.

### `deferWork_frame` (`lean/BsvChain/Properties/Persist.lean:89`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now`; `params`, `cfg` and `oracle` are not arguments of the statement.

Deferring work keeps the accepted pool, the request and the built entry.

### `deferWork_grows` (`lean/BsvChain/Properties/Persist.lean:95`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now`; `params`, `cfg` and `oracle` are not arguments of the statement.

Deferring work satisfies the growth law: it adds no id to the accepted pool.

### `insertNonFinal_frame` (`lean/BsvChain/Properties/Persist.lean:99`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

Inserting into the held pool keeps the accepted pool, the request and the built entry.

### `stageRegular_grows` (`lean/BsvChain/Properties/Persist.lean:109`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

The regular-transaction stage only refuses or passes; it adds no id to the accepted pool.

### `stageStandard_grows` (`lean/BsvChain/Properties/Persist.lean:122`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

The standardness stage only refuses or passes; it adds no id to the accepted pool.

### `stageFinality_grows` (`lean/BsvChain/Properties/Persist.lean:135`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

The finality stage refuses, holds or passes; it adds no id to the accepted pool.

### `stageAlreadyKnown_grows` (`lean/BsvChain/Properties/Persist.lean:148`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The already-known stage only refuses or passes; it adds no id to the accepted pool.

### `stageConflict_grows` (`lean/BsvChain/Properties/Persist.lean:161`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The conflict stage only refuses or passes; it adds no id to the accepted pool.

### `stageInputs_grows` (`lean/BsvChain/Properties/Persist.lean:174`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

The inputs stage refuses, retains an orphan or passes; it adds no id to the accepted pool.

### `stageSequence_grows` (`lean/BsvChain/Properties/Persist.lean:187`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

The sequence-lock stage only refuses or passes; it adds no id to the accepted pool.

### `stageInputStandard_grows` (`lean/BsvChain/Properties/Persist.lean:200`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

The input-standardness stage only refuses or passes; it adds no id to the accepted pool.

### `stageSigops_grows` (`lean/BsvChain/Properties/Persist.lean:214`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

The signature-operation stage only refuses or passes; it adds no id to the accepted pool.

### `stageFee_grows` (`lean/BsvChain/Properties/Persist.lean:227`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

The fee stage only refuses or passes; it adds no id to the accepted pool.

### `stageAncestors_grows` (`lean/BsvChain/Properties/Persist.lean:240`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

The ancestor stage builds the request's entry or refuses; it adds no id to the accepted pool.

### `stageScripts_grows` (`lean/BsvChain/Properties/Persist.lean:255`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

The script stage refuses, defers or passes; it adds no id to the accepted pool.

### `stageDetector_grows` (`lean/BsvChain/Properties/Persist.lean:269`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The double-spend detector's stage only refuses or passes; it adds no id to the accepted pool.

### `bumpRollingFee_accepted` (`lean/BsvChain/Properties/Persist.lean:282`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

Raising the rolling fee leaves the accepted pool unchanged.

### `remove_staged_mem` (`lean/BsvChain/Properties/Persist.lean:289`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

Removing staged entries only removes: every id left was in the pool before.

### `trimLoop_ids` (`lean/BsvChain/Properties/Persist.lean:297`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

The size limit's trim loop only removes: every id left was in the pool before.

### `limitPool_ids` (`lean/BsvChain/Properties/Persist.lean:320`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `now`; `params` and `oracle` are not arguments of the statement.

The commit's maintenance (expiry, then the size limit) only removes ids from the accepted pool.

### `addUnchecked_ids` (`lean/BsvChain/Properties/Persist.lean:332`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

Adding an entry appends exactly its id to the accepted pool's ids.

### `commit_tail` (`lean/BsvChain/Properties/Persist.lean:340`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The commit's accepted branch: the verdict is accepted exactly when the new
entry is still in the pool after the size limit, and the limit only removes.

### `stageCommit_grows` (`lean/BsvChain/Properties/Persist.lean:365`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

The commit stage adds at most the request's own id, and only with the accepted verdict.

### `run_grows` (`lean/BsvChain/Properties/Persist.lean:393`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Ordered stages keep the growth law: a stage that continues adds no id, so
only the stage that completes with the accepted verdict can.

### `run_grows_eq` (`lean/BsvChain/Properties/Persist.lean:422`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

`run_grows` read through an equation for the run's result.

### `finishAdmission_accepted` (`lean/BsvChain/Properties/Persist.lean:434`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Finishing an admission leaves the accepted pool as the stages left it.

### `finishCommit_accepted` (`lean/BsvChain/Properties/Persist.lean:441`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Finishing a commit leaves the accepted pool as the stages left it.

### `before_detector_grows` (`lean/BsvChain/Properties/Persist.lean:448`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

Every stage before the detector satisfies the growth law.

### `after_detector_grows` (`lean/BsvChain/Properties/Persist.lean:473`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

The detector's stage and the commit stage satisfy the growth law.

### `acceptWithTrace_ids` (`lean/BsvChain/Properties/Persist.lean:482`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

The traced admission's growth law: a new id is the request's own, with the accepted verdict.

### `accept_ids` (`lean/BsvChain/Properties/Persist.lean:521`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

The growth law of admission (#62): after `accept`, every id of the accepted
pool was there before, or the outcome is the accepted verdict and the id is the
request's own. Earlier stages and every refusal leave the accepted pool as it
was; maintenance at the commit only removes. This is what lets a load's
survivor be traced to the admission verdict of its own record.
[SRC] src/validation.cpp:895-946,1009-1505,1759-1866 and
src/txmempool.cpp:736-805,2130-2221,2734-2792 at 6504a3af.

### `fateOf_kept` (`lean/BsvChain/Properties/Persist.lean:549`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A kept fate is admission's own completed verdict, accepted or held.

### `loadOne_shape` (`lean/BsvChain/Properties/Persist.lean:556`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `oracle` (through `LoadContext`); `params` and `now` are not arguments of the statement.

One record's ledger line has the admissible shape of `StepShape`.

### `loadOne_ids` (`lean/BsvChain/Properties/Persist.lean:572`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `oracle` (through `LoadContext`); `params` and `now` are not arguments of the statement.

The step of one record: the kept id is the record's own.

### `prioritise_accepted` (`lean/BsvChain/Properties/Persist.lean:589`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A fee delta leaves the accepted pool unchanged.

### `deltas_accepted` (`lean/BsvChain/Properties/Persist.lean:592`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Applying the residual deltas leaves the accepted pool unchanged.

### `traced_cons` (`lean/BsvChain/Properties/Persist.lean:603`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Tracing composes over a run: one traced step followed by a traced rest is traced.

### `shaped_cons` (`lean/BsvChain/Properties/Persist.lean:614`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `oracle` (through `LoadContext`); `params` and `now` are not arguments of the statement.

Shape composes over a run: one shaped step followed by shaped steps are all shaped.

### `loadRecords_traced` (`lean/BsvChain/Properties/Persist.lean:623`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `oracle` (through `LoadContext`); `params` and `now` are not arguments of the statement.

The accepted file's records: every survivor is traced to its own kept step, and every step is shaped.

### `loadMempoolFile_traced` (`lean/BsvChain/Properties/Persist.lean:647`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `oracle` (through `LoadContext`); `params` and `now` are not arguments of the statement.

The accepted file, failures included: every survivor is traced and every step is shaped.

### `loadNonFinalRecords_traced` (`lean/BsvChain/Properties/Persist.lean:667`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `oracle` (through `LoadContext`); `params` and `now` are not arguments of the statement.

The held file's records: every survivor is traced to its own kept step, and every step is shaped.

### `loadNonFinalFile_traced` (`lean/BsvChain/Properties/Persist.lean:680`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `oracle` (through `LoadContext`); `params` and `now` are not arguments of the statement.

The held file, absent or of another version included: survivors traced, steps shaped.

### `load_traced` (`lean/BsvChain/Properties/Persist.lean:692`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `oracle` (through `LoadContext`); `params` and `now` are not arguments of the statement.

The whole load: every survivor of the empty start is traced to its own kept step, every step shaped.

### `survivor_accepted_at_load` (`lean/BsvChain/Properties/Persist.lean:712`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `oracle` (through `LoadContext`); `params` and `now` are not arguments of the statement.

**A survivor of the load was accepted at its own load step.** Every
transaction in the accepted pool after a start has a ledger line of the load,
for its own id, whose fate is kept with admission's accepted verdict: the
record was unexpired at the load's clock and `accept` admitted it against the
load's tip and coins. Nothing enters the accepted pool without re-validation;
the held pool's survivors are not stated here [D].
[SRC] src/txmempool.cpp:3154-3273, src/time_locked_mempool.cpp:287-378 and
src/init.cpp:1901-1905 at 6504a3af.

### `load_steps_shaped` (`lean/BsvChain/Properties/Persist.lean:736`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `oracle` (through `LoadContext`); `params` and `now` are not arguments of the statement.

**A record the load dropped names its reason.** Every ledger line of a
start is kept with admission's verdict (accepted or held, from an unexpired
record), or dropped as expired (never validated; entry time plus the file's
expiry not after the load's clock), or dropped with admission's own outcome:
missing inputs, the refusal's code and reason, or an incomplete outcome.
[SRC] src/txmempool.cpp:3209-3240 and src/time_locked_mempool.cpp:325-359 at 6504a3af.

### `start_without_persist` (`lean/BsvChain/Properties/Persist.lean:749`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `oracle` (through `LoadContext`); `params` and `now` are not arguments of the statement.

**Without the setting a start reads nothing.** The pool is the fresh
process's empty pool and the ledger is empty, whatever the data directory
holds. [SRC] src/init.cpp:1901-1905 at 6504a3af.

### `shutdown_without_persist` (`lean/BsvChain/Properties/Persist.lean:755`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**Without the setting a shutdown writes nothing**, so the files of an
earlier run with the setting stay in the data directory, and a later start
with the setting reads them. [SRC] src/init.cpp:237-240 at 6504a3af.

### `stale_file_after_run_without` (`lean/BsvChain/Properties/Persist.lean:761`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**The stale file.** A run with the setting, then a run without it, leaves
the earlier run's dump as the files the next start with the setting loads:
whatever the run without the setting held is not in them.
[SRC] src/init.cpp:237-240,1901-1905 at 6504a3af.
[D] Bodies the pool had moved to its transaction database are not in these
files; a start without the setting clears that database
(src/txmempool.cpp:3032-3037), so such a record fails the next load
(src/txmempool.cpp:3186-3193), outside this model.

### `dump_order_and_times` (`lean/BsvChain/Properties/Persist.lean:773`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**The dump keeps the pool's order and entry times.** Its records are the
accepted entries in the pool's insertion order, each with its own entry time,
which the load passes back to admission as the acceptance time.
[SRC] src/txmempool.cpp:1851-1858,3307-3323,3200-3222 at 6504a3af.

### `dump_topological` (`lean/BsvChain/Properties/Persist.lean:782`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**A topological pool writes a topological file.** The dump keeps the pool's
order, so when no entry spends an output of a later entry, no record's body
spends an output of a later record. The pool's order is the model's assumption
`PoolTopological` [D]. [SRC] src/txmempool.cpp:1851-1858,2386,3307-3323 at
6504a3af.

### `dump_residual_absent` (`lean/BsvChain/Properties/Persist.lean:804`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**Residual deltas name no dumped record.** Each entry's delta travels with
its record; the map written after the records holds only ids outside the pool.
[SRC] src/txmempool.cpp:3282-3284,3324,3328 at 6504a3af.

### `file_request_time` (`lean/BsvChain/Properties/Persist.lean:815`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**A load time is the request's acceptance time.** The record's entry time,
not the load's clock, is what admission stores, so expiry keeps counting from
the transaction's original arrival. [SRC] src/txmempool.cpp:3200-3222 and
src/time_locked_mempool.cpp:322-341 at 6504a3af.

## `BsvChain.Properties.Prune`

### `pruneStoreWF_empty` (`lean/BsvChain/Properties/Prune.lean:41`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the empty store satisfies the invariant.

### `addBlock_wf` (`lean/BsvChain/Properties/Prune.lean:45`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: storing a block keeps the invariant: the receiving file's highest height
becomes at least the new block's, and no other file changes.
[SRC] src/blockfileinfostore.cpp:74-103, src/block_file_info.cpp:19-44 at 6504a3af.

### `unlink_wf` (`lean/BsvChain/Properties/Prune.lean:59`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: removing files keeps the invariant: a file not removed keeps its info.
[SRC] src/validation.cpp:6584-6628 at 6504a3af.

### `hasUndo_hasData` (`lean/BsvChain/Properties/Prune.lean:68`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: lock-step: a block's undo bit implies its data bit (block and undo
files are removed together). [SRC] src/validation.cpp:6608-6617,
src/block_index.h:669-690 at 6504a3af.

### `manualSet_mem` (`lean/BsvChain/Properties/Prune.lean:75`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: every file the manual selection takes is non-empty, below the file being
written, and has its highest block at or below the bound.
[SRC] src/blockfileinfostore.cpp:196-203 at 6504a3af.

### `manualBound_le` (`lean/BsvChain/Properties/Prune.lean:84`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: with a chain at least `minBlocksToKeep` long, the manual bound is at or
below the tip less `minBlocksToKeep`. [SRC] src/blockfileinfostore.cpp:189-194 at 6504a3af.

### `manual_keeps_recent` (`lean/BsvChain/Properties/Prune.lean:90`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE MANUAL RETENTION: a stored block within `minBlocksToKeep` of the tip
keeps its data through the manual selection, whatever height was asked.
[SRC] src/blockfileinfostore.cpp:177-208 at 6504a3af.

### `autoLoop_mem` (`lean/BsvChain/Properties/Prune.lean:108`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: every file the automatic scan takes is a file of the scanned list with
its highest block at or below the bound. [SRC] src/blockfileinfostore.cpp:266-288 at 6504a3af.

### `autoSet_mem` (`lean/BsvChain/Properties/Prune.lean:128`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: every file the automatic selection takes is below the file being written
and has its highest block at or below the tip less `minBlocksToKeep`.
[SRC] src/blockfileinfostore.cpp:244-251,266-288 at 6504a3af.

### `auto_keeps_recent` (`lean/BsvChain/Properties/Prune.lean:143`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE AUTOMATIC RETENTION: a stored block within `minBlocksToKeep` of the
tip keeps its data through the automatic selection. [SRC]
src/blockfileinfostore.cpp:230-300 at 6504a3af.

### `selections_spare_last` (`lean/BsvChain/Properties/Prune.lean:159`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: neither selection takes the file being written.
[SRC] src/blockfileinfostore.cpp:196,266 at 6504a3af.

### `autoSet_nil_of_le` (`lean/BsvChain/Properties/Prune.lean:167`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the automatic selection takes nothing while the tip is at or below
`nPruneAfterHeight`. [SRC] src/blockfileinfostore.cpp:240-242 at 6504a3af.

### `automatic_manual_nil` (`lean/BsvChain/Properties/Prune.lean:173`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: in manual mode (`-prune=1`, the target the largest `uint64_t`) the
automatic selection takes nothing while usage plus one chunk of each kind is below that
target. [SRC] src/init.cpp:2821-2826, src/blockfileinfostore.cpp:265 at 6504a3af.

### `boundary_rpc_acts_auto_does_not` (`lean/BsvChain/Properties/Prune.lean:181`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE BOUNDARY: at a tip exactly `nPruneAfterHeight` the RPC is not refused
as too short (its test is `<`) while the automatic selection takes nothing (its test is
`<=`). [SRC] src/rpc/blockchain.cpp:1860, src/blockfileinfostore.cpp:240 at 6504a3af.

### `pruneblockchain_le` (`lean/BsvChain/Properties/Prune.lean:196`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: whatever it answers, the RPC never prunes past the tip less
`minBlocksToKeep`. [SRC] src/rpc/blockchain.cpp:1859-1873 at 6504a3af.

### `pruneblockchain_negative` (`lean/BsvChain/Properties/Prune.lean:208`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE NEGATIVE CLAMP: when `minBlocksToKeep` exceeds the tip, a request at
or below the tip answers the tip less `minBlocksToKeep`, a negative height that the reply
casts to `uint64_t`, and removes nothing (the manual selection runs only above zero).
[SRC] src/rpc/blockchain.cpp:1867-1874, src/validation.cpp:3840-3842 at 6504a3af.

### `pruneHeightFrom_data` (`lean/BsvChain/Properties/Prune.lean:226`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: every block from `pruneheight` up to the tip's parent has its data.
[SRC] src/rpc/blockchain.cpp:2467-2480 at 6504a3af.

### `pruneHeightFrom_stop` (`lean/BsvChain/Properties/Prune.lean:240`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: `pruneheight` is genesis or a block whose parent has no data.
[SRC] src/rpc/blockchain.cpp:2474-2477 at 6504a3af.

### `merkleproof_served_iff` (`lean/BsvChain/Properties/Prune.lean:251`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a merkle proof is served exactly when the block's data or its merkle
tree is held. [SRC] src/rpc/rawtransaction.cpp:2293-2300,2439-2444,
src/merkletreestore.cpp:540-570 at 6504a3af.

### `merkleproof2_served_iff` (`lean/BsvChain/Properties/Prune.lean:258`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the same for `getmerkleproof2`. [SRC] src/rpc/rawtransaction.cpp:2439-2444
at 6504a3af.

### `merkleproof_pruned_tree_served` (`lean/BsvChain/Properties/Prune.lean:264`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE CHARTER'S SENTENCE IS FALSE AT THE PIN: a pruned block whose merkle
tree is still held is served a proof. [SRC] src/merkletreestore.cpp:540-570 at 6504a3af.

### `merkleproof_served_no_tree` (`lean/BsvChain/Properties/Prune.lean:270`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: for a node that holds no tree of the block, a proof it serves names a
block it retains. [SRC] src/merkletreestore.cpp:552-563 at 6504a3af.

### `header_served` (`lean/BsvChain/Properties/Prune.lean:277`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the header a proof's target names is always served, pruned or not, so a
held tree's proof can be checked against it (#65's `verifyTsc`; the bridge is not stated here).
[SRC] src/rpc/blockchain.cpp:93-158 at 6504a3af.

### `getblock_served_iff` (`lean/BsvChain/Properties/Prune.lean:285`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the body is served exactly when the data is held, at every verbosity.
[SRC] src/rpc/blockchain.cpp:1446-1474,1591-1620,1665-1678 at 6504a3af.

### `getrawtransaction_served_iff` (`lean/BsvChain/Properties/Prune.lean:291`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a transaction is served through `-txindex` exactly when its block's data
is held. [SRC] src/validation.cpp:2178-2185, src/rpc/rawtransaction.cpp:196-205 at 6504a3af.

### `gettxout_unpruned` (`lean/BsvChain/Properties/Prune.lean:297`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the UTXO set is not pruned: an unspent output is served whatever the
block's data. [SRC] src/rpc/blockchain.cpp:1923-2029 at 6504a3af.

### `find?_map_key` (`lean/BsvChain/Properties/Prune.lean:301`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a list lookup by a key that a map preserves commutes with the map.

### `pruneIndex_header` (`lean/BsvChain/Properties/Prune.lean:312`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a pruned index keeps its header, hence its id.
[SRC] src/block_index.h:669-690 at 6504a3af.

### `pruneIf_id` (`lean/BsvChain/Properties/Prune.lean:316`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: pruning never changes an index's id.

### `pruneTree_get` (`lean/BsvChain/Properties/Prune.lean:324`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: pruning the header tree keeps every index (and its id); a pruned index
has neither body nor undo. [SRC] src/block_index.h:669-690 at 6504a3af.

### `get_id` (`lean/BsvChain/Properties/Prune.lean:332`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the index a lookup returns carries the id it was looked up by.

### `undo_absent_pruned` (`lean/BsvChain/Properties/Prune.lean:339`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE UNDO INTERACTION: an undo the node lacks for a block it had connected
(its index held an undo record) is a block it pruned.
[SRC] src/validation.cpp:6584-6606, src/block_index.h:669-690 at 6504a3af.

### `pruned_lockstep` (`lean/BsvChain/Properties/Prune.lean:352`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: lock-step on the spec's tree: a pruned index lacks both its body and its
undo. [SRC] src/block_index.h:669-690 at 6504a3af.

### `disconnectTip_pruned` (`lean/BsvChain/Properties/Prune.lean:368`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (through `ChainContext`); `oracle` is not an argument of the statement.

[D] 2026-10-15: THE DISCONNECT AT A PRUNED TIP: the spec's `disconnectTip` fails without
moving the active chain or the coins. At the pin the node's observable is held in the record
under the discretion group until routed.
[SRC] src/validation.cpp:4065-4080 at 6504a3af.

## `BsvChain.Properties.Reachable`

### `bound_of_treeCore` (`lean/BsvChain/Properties/Reachable.lean:71`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: equal immutable projections carry the invariant: the
binding reads only headers and bodies.
[SRC] src/validation.cpp:4345-4404,4498-4523 at 6504a3af.

### `bound_of_execution` (`lean/BsvChain/Properties/Reachable.lean:84`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: an executed transition preserves the invariant.
[SRC] src/validation.cpp:4065-4133,4345-4404,5230-5330 at 6504a3af.

### `bound_modify` (`lean/BsvChain/Properties/Reachable.lean:90`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: an edit that binds every edited index keeps the invariant.
[SRC] src/validation.cpp:5528-5562 at 6504a3af.

### `nodeBound_congr` (`lean/BsvChain/Properties/Reachable.lean:103`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: a metadata edit keeps a bound index bound.
[SRC] src/block_index.h:364-375 at 6504a3af.

### `get_mem` (`lean/BsvChain/Properties/Reachable.lean:111`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: a looked-up index is a member of the tree.
[SRC] src/validation.cpp:6137-6169 at 6504a3af.

### `insertCandidate_nodes` (`lean/BsvChain/Properties/Reachable.lean:118`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: candidate insertion changes no index.
[SRC] src/validation.cpp:5705-5708 at 6504a3af.

### `linkBodies_bound` (`lean/BsvChain/Properties/Reachable.lean:125`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: body linking edits only link metadata of looked-up indices.
[SRC] src/validation.cpp:5688-5725 at 6504a3af.

### `markInvalid_bound` (`lean/BsvChain/Properties/Reachable.lean:146`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: failure marking edits status only.
[SRC] src/validation.cpp:4453-4475,5578-5632 at 6504a3af.

### `checkBlock_rootBound` (`lean/BsvChain/Properties/Reachable.lean:152`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: with the default options, an accepted block check bound
the header's merkle root to the body and found no mutation.
[SRC] src/validation.cpp:5768-5782 at 6504a3af.

### `acceptHeader_bound` (`lean/BsvChain/Properties/Reachable.lean:166`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (through `ChainContext`); `oracle` is not an argument of the statement.

[D] 2026-10-13: header acceptance adds at most one index, without a body.
[SRC] src/validation.cpp:6134-6197 at 6504a3af.

### `acceptBlock_bound` (`lean/BsvChain/Properties/Reachable.lean:191`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (through `ChainContext`); `oracle` is not an argument of the statement.

[D] 2026-10-13: body acceptance stores a body only after the block check,
and only in the indices its header hash names.
[SRC] src/validation.cpp:6238-6395,5662-5725 at 6504a3af.

### `fold_bound` (`lean/BsvChain/Properties/Reachable.lean:239`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: a fold whose every step keeps the tree bound keeps it bound.
[SRC] src/validation.cpp:5528-5562 at 6504a3af.

### `reconsiderBlock_bound` (`lean/BsvChain/Properties/Reachable.lean:250`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

[D] 2026-10-13: reconsideration edits failure flags and candidacy, then
activates; no body or header changes.
[SRC] src/rpc/blockchain.cpp:2770-2818 and src/validation.cpp:5528-5562 at 6504a3af.

### `preciousBlock_bound` (`lean/BsvChain/Properties/Reachable.lean:274`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

[D] 2026-10-13: precious ordering edits sequence and completion metadata,
prunes candidates, then activates; no body or header changes.
[SRC] src/validation.cpp:5156-5190 at 6504a3af.

### `reachable_bodiesBound` (`lean/BsvChain/Properties/Reachable.lean:298`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (through `Reachable`).

[M] 2026-10-13, #68 G3 (the body binding as an invariant). Every state the
machine's own transitions reach from the empty state keeps every retained body
bound: the index's header hash equals the body's header hash, and the body's
header commits to its transactions with no mutation. Premise in plain words:
the state is reachable (`Reachable`), by any sequence of header and body
acceptance, automatic activation, invalidation, reconsideration, precious
ordering, soft rejection or freeze changes, and pool-only changes, under any
parameters, configuration, operator lists, oracle, ranks, budgets and times.
The binding is established where the body is stored, by the block check, and
nothing else ever writes a body.
[SRC] src/validation.cpp:5770-5781,6238-6395,4913-5330 at 6504a3af.

### `header_hash_eq` (`lean/BsvChain/Properties/Reachable.lean:327`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: equal header hashes mean equal headers or a SHA256d
collision between their two distinct 80-byte encodings. No axiom: the hash is
the executable definition and the codec round trip is #63's theorem.
[SRC] src/primitives/block.cpp:16-18 and src/primitives/block.h:26-45 at 6504a3af.

### `reachable_path_inclusion_or_collision` (`lean/BsvChain/Properties/Reachable.lean:349`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (through `Reachable`).

[M] 2026-10-13, #68 G3's corollary (#65's inclusion for reachable states,
in the disjunction form of the maintainers' ruling S6-1). In every reachable state,
for an index on the active chain at a height with its body retained: if a
supplied path verifies against that index's header root, then the leaf is the
identifier of a transaction of that body at that active height, or the hash
has a collision between two distinct inputs the two paths touch, or between
the two distinct encodings of the index's header and the body's header.
Premises in plain words: the state is reachable (`hr`); the active chain names
the index at that height (`active`), the tree returns it (`lookup`), its
height is that height (`atHeight`) and it retains the body (`retained`): the
identification of the block, never its authentication; the position is in
range, the supplied path has the body branch's depth, both paths are 32-byte
words and the canonical branch has no null literal (the path shape of #65);
and the path verifies. #65's AuthenticatedBody premise is no longer assumed:
the header/body binding, the root binding and mutation false are proved from
reachability (`reachable_bodiesBound`). No collision freedom is assumed.
[SRC] src/consensus/merkle.cpp:284-327 and src/validation.cpp:5770-5781,6238-6395 at 6504a3af.

### `reachable_path_inclusion` (`lean/BsvChain/Properties/Reachable.lean:393`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (through `Reachable`).

[M] 2026-10-13, #68 G3's corollary, the inclusion form. In every reachable
state, a path that verifies against the header root of an active index with
its body retained proves that the leaf is the identifier of a transaction of
that body, included at that active height. Premises in plain words: those of
`reachable_path_inclusion_or_collision`, plus the explicitly stated commitment
hypothesis that SHA256d has no collision among the inputs the two paths touch
and the two header encodings (`commitment`, a hypothesis of the theorem, never
an axiom: rule 7). #65's AuthenticatedBody is not a premise.
[SRC] src/consensus/merkle.cpp:284-327 and src/validation.cpp:5770-5781,6238-6395 at 6504a3af.

## `BsvChain.Properties.Rejects`

### `remember_contains` (`lean/BsvChain/Properties/Rejects.lean:36`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

An inserted id is a member at once: the filter has no false negative for
its newest insertion.
[SRC] src/txn_recent_rejects.cpp:14–21 at 6504a3af.

### `reset_empty` (`lean/BsvChain/Properties/Rejects.lean:43`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A reset filter has no member and no insertion count: it is wipe-free
whatever its capacity.
[SRC] src/txn_recent_rejects.cpp:24–27 and src/bloom.cpp:322–329 at 6504a3af.

### `rejectFilter_wipe_free_iff` (`lean/BsvChain/Properties/Rejects.lean:50`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

For ANY configuration, the reject filter's generation is half the
configured capacity rounded up, and a filter built from a member list is
wipe-free exactly when the list's length is at most three generations.
[SRC] src/txn_recent_rejects.cpp:9–11, src/bloom.cpp:222–225,265–281 at 6504a3af.

### `default_wipe_free_bound` (`lean/BsvChain/Properties/Rejects.lean:62`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `cfg` fixed to the census defaults `NodeConfig.defaults`; `params`, `oracle` and `now` are not arguments of the statement. General form: `rejectFilter_wipe_free_iff`, quantified; this theorem is its instance.

At the census defaults the wipe-free regime is 180,000 insertions between
two resets: three generations of 60,000. The general form is
`rejectFilter_wipe_free_iff`, for every configuration; this theorem is its
instance at the census defaults.
[SRC] src/txn_recent_rejects.cpp:9–11 and src/bloom.cpp:222–225 at 6504a3af.

### `no_reset_without_tip_change` (`lean/BsvChain/Properties/Rejects.lean:74`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

No reset without an observed tip change: an inventory test under the
recorded tip hash leaves the whole pool, the filter included, as it was.
[SRC] src/net/net_processing.cpp:935–942 at 6504a3af.

### `tip_change_resets` (`lean/BsvChain/Properties/Rejects.lean:81`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

An inventory test under a tip hash other than the recorded one empties
the filter, records the new hash and touches nothing else that decides a
transaction's fate.
[SRC] src/net/net_processing.cpp:935–942 and src/net/net.cpp:3563–3564
at 6504a3af.

### `observe_tip_idempotent` (`lean/BsvChain/Properties/Rejects.lean:97`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The record always names the tip of the last test, so a second test under
the same tip is the identity: the reset happens once per observed change.
[SRC] src/net/net_processing.cpp:935–942 at 6504a3af.

### `remembered_inv_silent` (`lean/BsvChain/Properties/Rejects.lean:108`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Silence for an inventory. A txid in the filter, announced by a peer while
the recorded tip is still the observed tip, is not requested, and the pool is
returned unchanged. Because the pool is unchanged the premises hold again for
the next announcement: the silence lasts until a test observes another tip.
[SRC] src/net/net_processing.cpp:930–961,2479,2518–2519 at 6504a3af.

### `remembered_tx_suppressed` (`lean/BsvChain/Properties/Rejects.lean:119`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

Silence for the body. The same transaction sent again by a peer under the
same recorded tip is dropped before validation: no verdict, no reject message,
the pool unchanged.
[SRC] src/net/net_processing.cpp:3351–3408 at 6504a3af.

### `reset_follows_tip_change` (`lean/BsvChain/Properties/Rejects.lean:132`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

After a test observes another tip, an id with no declared bloom false
positive and no other known-transaction reason is requested again; the reject
filter is empty.
[SRC] src/net/net_processing.cpp:930–961 at 6504a3af.

### `validation_rejection_remembered` (`lean/BsvChain/Properties/Rejects.lean:153`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A rejection that validation itself returns for a peer's request enters
the filter under the request's own txid.
[SRC] src/validation.cpp:1786–1797,2037–2048 at 6504a3af.

### `commit_refusal_not_remembered` (`lean/BsvChain/Properties/Rejects.lean:162`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A refusal by the commit is not remembered: the pool is returned as the
commit left it, the filter included.
[SRC] src/validation.cpp:1808–1836,2097–2136 at 6504a3af.

### `other_sources_never_remember` (`lean/BsvChain/Properties/Rejects.lean:168`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

No other source writes the filter when a request finishes: an RPC, reorg,
finalised or file request leaves it as validation left it, whatever the
outcome.
[SRC] src/validation.cpp:1786–1797 at 6504a3af.

### `remembers_matches_routing` (`lean/BsvChain/Properties/Rejects.lean:178`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

For a peer request, the predicate marks a scripts-stage completed rejection
as remembered; it excludes a commit refusal, a deferral and an orphan outcome.
The actual routing functions have separate laws.
[SRC] src/validation.cpp:1786–1836,2037–2048 at 6504a3af.

### `run_stages_head` (`lean/BsvChain/Properties/Rejects.lean:190`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A stage list's trace begins with the head stage, whether that stage stops
or continues.

### `other_sources_bypass_filter` (`lean/BsvChain/Properties/Rejects.lean:202`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

A request that is not a peer's is never suppressed by the filter: its
trace begins with the regular validation stage even when its txid is remembered.
The synchronous RPC path does not consult the filter.
[SRC] src/rpc/rawtransaction.cpp:1586–1594,1625–1626 and
src/txn_validator.cpp:141–177 at 6504a3af.

### `silence_keeps_rejection_receipt` (`lean/BsvChain/Properties/Rejects.lean:236`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The remembered rejection as a status cell: a suppressed resubmission and
a deferral leave the journal's rejection receipts as they were, so the derived
status of a transaction rejected before stays `rejected`, with the earlier
code and reason, through every silent resubmission. The receipt is the
spec's bookkeeping; the node keeps membership only.
[SRC] src/txn_recent_rejects.h:31–36 and src/net/net_processing.cpp:3380,3394
at 6504a3af.

### `lowered_le` (`lean/BsvChain/Properties/Rejects.lean:249`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The priority lattice is a two-element chain and the timeout's move goes
down it.
[SRC] src/txn_validation_data.h:28–33 and src/txn_validator.cpp:633–638
at 6504a3af.

### `timeout_high_requeues_low` (`lean/BsvChain/Properties/Rejects.lean:258`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now`; `params`, `cfg` and `oracle` are not arguments of the statement.

A timed-out high-priority request is answered by no verdict: the same
request, with every override, is queued again at low priority, and the stage
reports `deferred`.
[SRC] src/txn_validator.cpp:633–638 and src/validation.cpp:1214–1216 at 6504a3af.

### `timeout_keeps_pool` (`lean/BsvChain/Properties/Rejects.lean:269`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now`; `params`, `cfg` and `oracle` are not arguments of the statement.

For a high-priority request, the timeout keeps the pool's deciding state:
the accepted and held sets, the spent index, the orphans and the filter are untouched, the finish adds
nothing, and the rejection journal of the derived status records no rejection.
No rejection and no acceptance came out of this step.
[SRC] src/txn_validator.cpp:633–638 and src/validation.cpp:1786–1836 at 6504a3af.

### `timeout_low_rejects` (`lean/BsvChain/Properties/Rejects.lean:287`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now`; `params`, `cfg` and `oracle` are not arguments of the statement.

For a low-priority request, the timeout completes with policy rejection
too-long-validation-time. A fully processed P2P validation refusal is
remembered when routed through finishAdmission; this theorem states the
timeout outcome only.
[SRC] src/txn_validator.cpp:639–641 and src/validation.cpp:1214–1216,2037–2048
at 6504a3af.

### `defer_work_answer` (`lean/BsvChain/Properties/Rejects.lean:306`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now`; `params`, `cfg` and `oracle` are not arguments of the statement.

Whatever the priority, the timeout's step ends in one of the two answers.

### `run_budget_stages` (`lean/BsvChain/Properties/Rejects.lean:327`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Running related stage lists gives the same result, or the timed run
stops with a timeout answer.

### `budget_step_of_eq` (`lean/BsvChain/Properties/Rejects.lean:357`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A stage that agrees everywhere is related to itself.

### `admissionEra_budget` (`lean/BsvChain/Properties/Rejects.lean:361`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `now` (through `AdmissionContext`); `cfg` and `oracle` are not arguments of the statement.

The era of an admission does not read the budget observation.

### `admissionScriptConfig_budget` (`lean/BsvChain/Properties/Rejects.lean:365`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

Changing the budget observation leaves the admission's script configuration unchanged: that configuration reads the era and policy fields, not the budget.

### `admissionScriptAttempt_budget` (`lean/BsvChain/Properties/Rejects.lean:370`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

One script attempt does not read the budget observation: the polls are
the stage's, between attempts.

### `input_standard_skips` (`lean/BsvChain/Properties/Rejects.lean:376`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

Stage 8 passes at once when non-standard outputs are accepted and the
request is unlimited or already low: no poll is reached.
[SRC] src/validation.cpp:1207,1225 at 6504a3af.

### `input_standard_expired` (`lean/BsvChain/Properties/Rejects.lean:390`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

Stage 8's poll: a limited request that reaches it with the inputs budget
expired takes the timeout's step.
[SRC] src/validation.cpp:1212–1216,1228–1232 at 6504a3af.

### `input_standard_unlimited` (`lean/BsvChain/Properties/Rejects.lean:407`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

Stage 8 of an unlimited request does not read the budget observation.
[SRC] src/validation.cpp:1225 at 6504a3af.

### `input_standard_budget` (`lean/BsvChain/Properties/Rejects.lean:418`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `AdmissionContext`); `oracle` is not an argument of the statement.

Stage 8 reads the budget at one poll; when the poll fires, the stage is
the timeout's step.
[SRC] src/validation.cpp:1206–1233 at 6504a3af.

### `scripts_unlimited` (`lean/BsvChain/Properties/Rejects.lean:446`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

Stage 12 of an unlimited request does not read the budget observation.
[SRC] src/validation.cpp:990–1006 at 6504a3af.

### `scripts_limited` (`lean/BsvChain/Properties/Rejects.lean:458`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

Stage 12 of a limited request, by cases on the poll that fired: the stage
is the untimed stage or the timeout's step.
[SRC] src/validation.cpp:1335–1355,1414–1430,1444–1464 at 6504a3af.

### `scripts_budget` (`lean/BsvChain/Properties/Rejects.lean:495`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

Stage 12 reads the budget at three polls, each guarded by the request's
limits; when a poll fires, the stage is the timeout's step.
[SRC] src/validation.cpp:1335–1355,1414–1430,1444–1464 at 6504a3af.

### `accept_trace_congr` (`lean/BsvChain/Properties/Rejects.lean:511`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

The acceptance reads its context at two places only: the stages before
the detector, and the commit. Two contexts that agree there give the same
acceptance.

### `accept_trace_stopped` (`lean/BsvChain/Properties/Rejects.lean:529`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

An acceptance that is not suppressed and stops before the detector
returns the stopping stage's outcome.

### `budget_changes_timing_only` (`lean/BsvChain/Properties/Rejects.lean:545`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

The budget preserves the available-budget result or stops with a timeout
answer. A high-priority timeout defers; a low-priority timeout completes with
too-long-validation-time and can replace the available-budget verdict or
reason. For any state, request and budget observation, the acceptance with
that observation either equals the acceptance with an available budget (the
same pool, outcome and trace), or it stops with a timeout answer: `deferred`,
the request queued again at low priority, or the low-priority rejection
`too-long-validation-time`. The theorem does not assert verdict invariance for
low-priority requests.
[SRC] src/validation.cpp:1210–1233,1349–1355,1424–1430,1458–1464 and
src/txn_validator.cpp:633–641 at 6504a3af.

### `elapsed_changes_timing_only` (`lean/BsvChain/Properties/Rejects.lean:608`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

The same law with the elapsed time as the explicit input: whatever
elapsed-time observation the harness supplies, the timed acceptance equals
the acceptance with an available budget, or it ends in a timeout answer. The
machine is deterministic in the observation; the observation is the node's.
[SRC] src/taskcancellation.h:155–164 and src/validation.cpp:990–1006 at 6504a3af.

### `within_allowance_available` (`lean/BsvChain/Properties/Rejects.lean:627`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

Within the allowance nothing fires: an observation whose every poll is at
or under the allowance is the available budget, so the timed acceptance is
the untimed one. Equality with the allowance does not fire; the source's
comparison is strict. Whether such a cell is judged is decided by its clock
dependence (`budget_judgment_judging_iff`), not by this value.
[SRC] src/taskcancellation.h:155–164 at 6504a3af.

### `budget_judgment_judging_iff` (`lean/BsvChain/Properties/Rejects.lean:643`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A cell is judged exactly when it is clock-free, whatever budget it
carries: a clock-dependent cell is non-judging on an available budget as on an
expired one, and a clock-free cell is judged even under an expired observation.
[SRC] src/validation.cpp:990–1006,1077–1078, src/taskcancellation.h:155–164
and src/init.cpp:2890–2895 at 6504a3af.

### `unlimited_clock_free` (`lean/BsvChain/Properties/Rejects.lean:652`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

An unlimited request is clock-free: it builds no timed source.
[SRC] src/validation.cpp:990–997 at 6504a3af.

### `clock_free_budget_invariant` (`lean/BsvChain/Properties/Rejects.lean:659`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A limited request classified clock-free has the same outcome under every
budget observation: no poll's firing changes what it answers, so the judged
cell does not depend on the node's clock.
[SRC] src/validation.cpp:1210–1233,1349–1355,1424–1430,1458–1464 at 6504a3af.

### `filter_judging_iff` (`lean/BsvChain/Properties/Rejects.lean:681`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

One rolling filter's reading is judged exactly inside its wipe-free regime
with no declared false positive outside its members.
[SRC] src/bloom.cpp:265–281 and src/bloom.h:112–118 at 6504a3af.

### `inventory_judging_exact` (`lean/BsvChain/Properties/Rejects.lean:690`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The inventory reading is judged exactly when both rolling filters it
consults are exact after the lazy reset: the reject filter and the separate
filter of recently removed held transactions, each inside its own wipe-free
regime and with no declared false positive for the id outside its members.
[SRC] src/net/net_processing.cpp:930–961, src/time_locked_mempool.cpp:217–221,481–510
and src/bloom.cpp:265–281 at 6504a3af.

### `observe_tip_removed` (`lean/BsvChain/Properties/Rejects.lean:708`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The lazy reset leaves the separate filter of recently removed held
transactions as it was: only the reject filter is reset.
[SRC] src/net/net_processing.cpp:935–942 and src/time_locked_mempool.cpp:481–490
at 6504a3af.

### `removed_wipe_non_judging` (`lean/BsvChain/Properties/Rejects.lean:717`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A rollover of the separate filter makes the inventory reading non-judging
even when the reject filter is wipe-free.
[SRC] src/time_locked_mempool.cpp:481–490 and src/bloom.cpp:265–281 at 6504a3af.

### `or_absorb` (`lean/BsvChain/Properties/Rejects.lean:728`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A Boolean disjunct implied by the other is absorbed.

### `inventory_judging_ideal` (`lean/BsvChain/Properties/Rejects.lean:732`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A judged inventory reading is the ideal-set reading: with both filters
exact, the declared false positives do not change the answer or the pool.
[SRC] src/net/net_processing.cpp:930–961 at 6504a3af.

### `removedNonFinalFilter_wipe_free_iff` (`lean/BsvChain/Properties/Rejects.lean:742`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

For ANY configuration, the held pool's removal filter has the generation
of its own configured capacity, and is wipe-free exactly when its member list
is at most three generations long.
[SRC] src/time_locked_mempool.h:213–214, src/bloom.cpp:222–225,265–281 at 6504a3af.

### `default_removed_wipe_free_bound` (`lean/BsvChain/Properties/Rejects.lean:755`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `cfg` fixed to the census defaults `NodeConfig.defaults`; `params`, `oracle` and `now` are not arguments of the statement. General form: `removedNonFinalFilter_wipe_free_iff`, quantified; this theorem is its instance.

At the census defaults the separate filter's wipe-free regime is 15,000
insertions: three generations of 5,000. The general form is
`removedNonFinalFilter_wipe_free_iff`; this theorem is its instance at the
census defaults.
[SRC] src/time_locked_mempool.h:214 and src/bloom.cpp:222–225 at 6504a3af.

### `validationAllowance_bounds` (`lean/BsvChain/Properties/Rejects.lean:765`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

For ANY configuration, a request's allowance is its priority's configured
duration (in microseconds) plus the carried time, and the carried part never
exceeds the configured chain budget.
[SRC] src/txn_validation_config.h:39–46,
src/taskcancellation.h:113–121,173–179 and src/validation.cpp:1577 at 6504a3af.

### `default_allowances` (`lean/BsvChain/Properties/Rejects.lean:778`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `cfg` fixed to the census defaults `NodeConfig.defaults`; `params`, `oracle` and `now` are not arguments of the statement. General form: `validationAllowance_bounds`, quantified; this theorem is its instance.

The census defaults give a high-priority request 3,000 microseconds and a
low-priority request 1,000,000, each with at most 50,000 carried. The general
form is `validationAllowance_bounds`, for every configuration; this theorem is
its instance at the census defaults.
[SRC] src/txn_validation_config.h:39–46 at 6504a3af.

## `BsvChain.Properties.Relay`

### `addOne_pending_mono` (`lean/BsvChain/Properties/Relay.lean:48`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the offer never shrinks a peer's queue.

### `foldl_addOne_pending_mono` (`lean/BsvChain/Properties/Relay.lean:53`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: offers never shrink a peer's queue.

### `addOne_filters` (`lean/BsvChain/Properties/Relay.lean:60`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: an offer leaves the filters it reads alone.

### `foldl_addOne_id` (`lean/BsvChain/Properties/Relay.lean:66`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: offers keep the peer's id.

### `feeOk_congr` (`lean/BsvChain/Properties/Relay.lean:72`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the fee filter reads the peer's rate only.

### `foldl_addOne_mem` (`lean/BsvChain/Properties/Relay.lean:77`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a queued transaction the peer's filters pass, and that is
not known to it or already queued for it, ends in its queue.

### `foldl_addOne_known` (`lean/BsvChain/Properties/Relay.lean:108`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a transaction a peer is known to have, and that is not
already queued for it, is never queued for it.

### `propagate_queues` (`lean/BsvChain/Properties/Relay.lean:126`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the propagator's pass queues a transaction of its queue
for every peer that relays transactions, passes its filters and is not known
to have it (src/txn_propagator.cpp:136-175; src/net/net.cpp:836-878). A view,
never a rule.

### `known_never_queued` (`lean/BsvChain/Properties/Relay.lean:140`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: NEVER TO A PEER THAT HAS IT. A transaction a peer is known
to have, and that is not already queued for it, is not queued by the
propagator's pass (src/net/net.cpp:869-870). A view, never a rule.

### `relay_off_offered_nothing` (`lean/BsvChain/Properties/Relay.lean:150`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: NEVER RELAYED to a peer whose version message asked for
no transactions: its queue is cleared (src/net/net.cpp:852-856). A view,
never a rule.

### `dataref_never_queued` (`lean/BsvChain/Properties/Relay.lean:157`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: NEVER RELAYED: a miner-info data transaction is never
queued (src/net/net.cpp:3576-3578). A view, never a rule.

### `knows_updPeer` (`lean/BsvChain/Properties/Relay.lean:163`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the inventory test reads the pools, never the peers.

### `mem_updPeer_other` (`lean/BsvChain/Properties/Relay.lean:167`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a peer other than the changed one is untouched.

### `accepted_queued_for_unseen` (`lean/BsvChain/Properties/Relay.lean:173`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE ANNOUNCEMENT. A transaction the node accepts from a
peer (`tx`, its verdict `accepted`, the node not knowing it before, not in
blocks-only mode for the sender, not a miner-info data transaction) is queued
by the next propagator's pass for every other peer that relays transactions,
passes its fee filter and loaded filter and is not known to have it
(src/net/net_processing.cpp:3351-3393; src/validation.cpp:2097-2116,
:975-997; src/net/net.cpp:3574-3582,836-878). A view, never a rule.

### `accepted_never_back_to_sender` (`lean/BsvChain/Properties/Relay.lean:202`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: NEVER BACK TO THE SENDER. After the `tx` message the
sender is known to have the transaction (src/net/net_processing.cpp:3370-3371),
so the propagator's pass does not queue it back to the sender, unless it was
already queued for it before. A view, never a rule.

### `Ext.refl` (`lean/BsvChain/Properties/Relay.lean:250`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a node extends itself.

### `Ext.trans` (`lean/BsvChain/Properties/Relay.lean:254`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: extensions compose: the log appends, no mark or misbehavior ban appears.

### `score_append` (`lean/BsvChain/Properties/Relay.lean:268`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the score never falls when the log grows.

### `score_of_log` (`lean/BsvChain/Properties/Relay.lean:273`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a log that only grows never lowers a score.

### `BanSound.of_ext` (`lean/BsvChain/Properties/Relay.lean:280`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: an extension keeps the ban invariant (the scores only grow).

### `Ext.updPeer` (`lean/BsvChain/Properties/Relay.lean:291`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: changing peers without touching their marks or ids.

### `Ext.peers_map` (`lean/BsvChain/Properties/Relay.lean:302`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: mapping every peer by a change that keeps marks and ids is an extension.

### `Ext.foldl` (`lean/BsvChain/Properties/Relay.lean:312`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a fold of extensions is an extension.

### `Ext.addKnown` (`lean/BsvChain/Properties/Relay.lean:319`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: marking an id known to a peer is an extension.

### `Ext.askFor` (`lean/BsvChain/Properties/Relay.lean:323`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: `AskFor` is an extension (src/net/net.cpp:3269-3318).

### `Ext.enqueue` (`lean/BsvChain/Properties/Relay.lean:335`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: `EnqueueTransaction` is an extension (src/net/net.cpp:3574-3582).

### `enqueue_cfg` (`lean/BsvChain/Properties/Relay.lean:341`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the queue's enqueue keeps the settings.

### `enqueue_log` (`lean/BsvChain/Properties/Relay.lean:344`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the queue's enqueue keeps the log.

### `enqueue_banned` (`lean/BsvChain/Properties/Relay.lean:347`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the queue's enqueue keeps the ban list.

### `enqueue_peers` (`lean/BsvChain/Properties/Relay.lean:350`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the queue's enqueue keeps the peers.

### `Ext.fields` (`lean/BsvChain/Properties/Relay.lean:354`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: changing only the pools, queues and lists the ban does not read.

### `BanSound.misbehaving` (`lean/BsvChain/Properties/Relay.lean:359`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: `Misbehaving` keeps the invariant: it marks a peer only
when the recorded score crosses the threshold
(src/net/net_processing.cpp:620-628).

### `BanSound.consumeBan` (`lean/BsvChain/Properties/Relay.lean:384`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the send pass's ban step keeps the invariant: an entry for
misbehavior is written only for a marked peer (src/net/net_processing.cpp:4900-4917).

### `Ext.ban` (`lean/BsvChain/Properties/Relay.lean:427`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a ban with a cause other than misbehavior is an extension (src/net/net.cpp:535-580).

### `Ext.directBan` (`lean/BsvChain/Properties/Relay.lean:441`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a direct ban by a peer's address is an extension.

### `foldl_addOne_shouldBan` (`lean/BsvChain/Properties/Relay.lean:448`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: offers keep a peer's mark.

### `Ext.addTxns_peer` (`lean/BsvChain/Properties/Relay.lean:455`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the inventory's gain keeps a peer's mark and id (src/net/net.cpp:836-878).

### `BanSound.recvTx` (`lean/BsvChain/Properties/Relay.lean:462`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the `tx` message keeps the ban invariant: its only score change is `Misbehaving` (src/validation.cpp:2091-2094).

### `BanSound.retryOrphan` (`lean/BsvChain/Properties/Relay.lean:509`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: an orphan's retry keeps the ban invariant (src/validation.cpp:1971-1981).

### `Ext.recvInv` (`lean/BsvChain/Properties/Relay.lean:526`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the `inv` message is an extension: it scores nothing (src/net/net_processing.cpp:2454-2532).

### `Ext.flush` (`lean/BsvChain/Properties/Relay.lean:545`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the inventory flush is an extension.

### `Ext.request` (`lean/BsvChain/Properties/Relay.lean:555`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the request pass is an extension.

### `BanSound.step` (`lean/BsvChain/Properties/Relay.lean:563`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: every transition keeps the ban invariant.

### `ban_sound_run` (`lean/BsvChain/Properties/Relay.lean:589`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE BAN. From a node with no peer marked and no ban for
misbehavior, along any run, every peer marked for a ban has recorded
increments summing to the threshold or more, and every ban entry for
misbehavior names such a peer: a ban for misbehavior is reached only through
recorded increments (src/net/net_processing.cpp:610-634,4900-4919). The
other causes are named in the entry (`BanCause`); `ban_without_increment`
shows the issue's unqualified sentence false of the ban list at the pin. A
view, never a rule.

### `BanSound.clean` (`lean/BsvChain/Properties/Relay.lean:602`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a node with no marks and no bans is sound.

### `ban_without_increment` (`lean/BsvChain/Properties/Relay.lean:607`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the witness. A peer whose header is over its cap is banned
with no increment recorded (src/net/net_message.cpp:22-26,
src/net/association.cpp:396-401): the ban list is reached outside the
misbehavior score. A view, never a rule.

### `local_never_banned_by_score` (`lean/BsvChain/Properties/Relay.lean:617`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a local peer is disconnected, never banned, for its score;
a whitelisted or manual peer is neither (src/net/net_processing.cpp:4900-4917).

### `peer?_map` (`lean/BsvChain/Properties/Relay.lean:630`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: finding a peer in a list changed without moving ids.

### `peer?_of_peers` (`lean/BsvChain/Properties/Relay.lean:635`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the lookup reads the peers only.

### `peer?_updPeer_ne` (`lean/BsvChain/Properties/Relay.lean:639`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: changing another peer leaves a peer's lookup alone.

### `propagate_flush_single` (`lean/BsvChain/Properties/Relay.lean:650`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: on a node whose queue holds one transaction, a peer with
nothing queued that relays transactions, passes the filters and is not known
to have it is sent exactly one `inv` naming it by the pass and its flush.

### `accepted_announced_when_idle` (`lean/BsvChain/Properties/Relay.lean:676`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE ANNOUNCEMENT, ON AN IDLE NODE. A transaction the node
accepts from a peer, with nothing else queued, is announced to each other
peer that relays transactions, passes its filters, has nothing queued and is
not known to have it, by exactly one `inv` naming it on that peer's next
flush after the propagator's pass (src/net/net_processing.cpp:3351-3393,
5536-5674; src/validation.cpp:2097-2116; src/net/net.cpp:836-878). A view,
never a rule.

### `rpcAccepted_queued_for_unseen` (`lean/BsvChain/Properties/Relay.lean:713`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE ANNOUNCEMENT, THE RPC'S ACCEPTANCE. A transaction
`sendrawtransaction` accepts (not a miner-info data transaction) is queued by
the next propagator's pass for every peer that relays transactions, passes its
fee filter and loaded filter and is not known to have it
(src/rpc/rawtransaction.cpp:1682; src/net/net.cpp:3574-3582,836-878). A view,
never a rule.

### `retryOrphan_accepted_queued_for_unseen` (`lean/BsvChain/Properties/Relay.lean:727`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE ANNOUNCEMENT, AN ORPHAN ACCEPTED ON RETRY. An orphan
retried after its parents arrived and accepted (not a miner-info data
transaction) is queued by the next propagator's pass for every peer that
relays transactions, passes its fee filter and loaded filter and is not known
to have it (src/txn_validator.cpp:695-720; src/validation.cpp:1859-1865,2109-2116;
src/net/net_processing.cpp:975-997; src/net/net.cpp:3574-3582,836-878). A view, never a rule.

### `flush_cfg` (`lean/BsvChain/Properties/Relay.lean:744`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a flush keeps the settings.

### `flush_peer?` (`lean/BsvChain/Properties/Relay.lean:751`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a peer's flush leaves it in place with its queue less the
items one flush takes (`SendTxnInventory`, src/net/net_processing.cpp:5539-5570, the fetch at :5543;
`FetchNInventory`, src/net/net.cpp:907-928).

### `flushes_peer?` (`lean/BsvChain/Properties/Relay.lean:773`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: `k` flushes of one peer, nothing else between them, take
`k` times the items one flush takes off its queue and keep the settings.

### `pending_announced_within` (`lean/BsvChain/Properties/Relay.lean:795`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE ANNOUNCEMENT UNDER LOAD. An id at index `i` of a peer's
queue is in the `inv` of that peer's `(i / broadcastMax + 1)`-th flush, the
flushes of that peer following one another with no other transition between
them, for `broadcastMax` above 0 (`SendTxnInventory` takes at most
`broadcastMax` items a flush from the queue's front,
src/net/net_processing.cpp:5539-5570, the fetch at :5543, called from
`SendInventory` at :5667-5669; src/net/net.cpp:907-928). A view, never
a rule.

### `queued_announced_within` (`lean/BsvChain/Properties/Relay.lean:835`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: every id in a peer's queue is announced by one of that
peer's flushes, the flushes following one another with no other transition
between them (`pending_announced_within`). A view, never a rule.

### `propagate_announced_within` (`lean/BsvChain/Properties/Relay.lean:846`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a queued transaction reaches every peer that relays
transactions, passes its filters and is not known to have it: the
propagator's pass queues it (`propagate_queues`) and one of that peer's
flushes after it announces it (`queued_announced_within`). A view, never a
rule.

### `accepted_announced_within` (`lean/BsvChain/Properties/Relay.lean:870`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE ANNOUNCEMENT, A PEER'S `tx`, UNDER ANY LOAD. A
transaction the node accepts from a peer (not known before, not in
blocks-only mode for the sender, not a miner-info data transaction) is
announced to each other peer that relays transactions, passes its filters and
is not known to have it, in the `inv` of one of that peer's flushes after the
propagator's pass, whatever was queued before
(src/net/net_processing.cpp:3351-3393,5536-5674; src/validation.cpp:2097-2116;
src/net/net.cpp:836-878). A view, never a rule.

### `rpcAccepted_announced_within` (`lean/BsvChain/Properties/Relay.lean:909`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE ANNOUNCEMENT, THE RPC'S ACCEPTANCE, UNDER ANY LOAD.
A transaction `sendrawtransaction` accepts (not a miner-info data
transaction) is announced to each peer that relays transactions, passes its
filters and is not known to have it, in the `inv` of one of that peer's
flushes after the propagator's pass (src/rpc/rawtransaction.cpp:1682;
src/net/net.cpp:3574-3582,836-878; src/net/net_processing.cpp:5536-5674). A
view, never a rule.

### `retryOrphan_announced_within` (`lean/BsvChain/Properties/Relay.lean:927`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE ANNOUNCEMENT, AN ORPHAN ACCEPTED ON RETRY, UNDER ANY
LOAD. An orphan retried after its parents arrived and accepted (not a
miner-info data transaction) is announced to each peer that relays
transactions, passes its filters and is not known to have it, in the `inv` of
one of that peer's flushes after the propagator's pass
(src/txn_validator.cpp:695-720; src/validation.cpp:1859-1865,2109-2116;
src/net/net_processing.cpp:975-997; src/net/net.cpp:3574-3582,836-878;
src/net/net_processing.cpp:5536-5674). A
view, never a rule.

### `updPeer_requested` (`lean/BsvChain/Properties/Relay.lean:951`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a peer change that keeps the request queues keeps them.

### `invItem_ibd` (`lean/BsvChain/Properties/Relay.lean:961`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: one `inv` item during the initial block download asks for
nothing and leaves the latch set.

### `ibd_inv_requests_nothing` (`lean/BsvChain/Properties/Relay.lean:981`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: THE IBD GATE. During the initial block download an `inv`
draws no request: no peer's request queue changes and nothing is asked for
(src/net/net_processing.cpp:2518-2520). A view, never a rule.

### `rejectFor_on_wire` (`lean/BsvChain/Properties/Relay.lean:1005`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the reject message carries only wire codes, above 0 and
below `REJECT_INTERNAL`, with a reason of at most 111 bytes
(src/validation.cpp:1940-1950).

### `recvTx_out` (`lean/BsvChain/Properties/Relay.lean:1022`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: every message the `tx` transition sends is its reject message.

### `retryOrphan_out` (`lean/BsvChain/Properties/Relay.lean:1032`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: every message an orphan's retry sends is its reject message.

### `step_rejects_on_wire` (`lean/BsvChain/Properties/Relay.lean:1042`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: NEVER ON THE WIRE: no transition sends an internal reject
code (0x100 and above: high fee, already known, conflict, mempool full,
src/validation.h:1150-1163) or a reason over 111 bytes. A view, never a rule.

## `BsvChain.Properties.StaleRun`

### `staleRunGenesis_hash` (`lean/BsvChain/Properties/StaleRun.lean:51`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params` fixed to regtest's record; `cfg`, `oracle` and `now` are not arguments of the statement. A statement about the concrete run `staleRunGenesis` (closed definitions of `lean/BsvChain/Properties/StaleRun.lean`): network-specific by design.

[SRC] 2026-10-13: the block reproduces the network's pinned genesis hash,
checked by the kernel. src/chainparams.cpp:1511-1514 at 6504a3af.

### `staleRunFinal_reachable` (`lean/BsvChain/Properties/StaleRun.lean:107`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params` fixed to regtest's record; `cfg` fixed to the census defaults `NodeConfig.defaults`; `oracle` fixed to the evaluator `evalOracle`; `now` fixed to the literal `1296700000`. A statement about the concrete run `staleRunWith1a` and `staleRunFinal` (closed definitions of `lean/BsvChain/Properties/StaleRun.lean`): network-specific by design.

[D] 2026-10-13: the run is a sequence of the machine's own transitions.
[SRC] src/validation.cpp:4913-5130,6238-6395 at 6504a3af.

### `staleFacts_sound` (`lean/BsvChain/Properties/StaleRun.lean:139`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the executable stale facts mean the propositions: a stale
path for the retained transaction, which is in no active block.
[SRC] src/consensus/merkle.cpp:291-310 and src/validation.cpp:4117 at 6504a3af.

### `staleRunChecks_true` (`lean/BsvChain/Properties/StaleRun.lean:177`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params` fixed to regtest's record; `cfg` fixed to the census defaults `NodeConfig.defaults`; `oracle` fixed to the evaluator `evalOracle`; `now` fixed to the literal `1296700000`. A statement about the concrete run `staleRunChecks` (closed definitions of `lean/BsvChain/Properties/StaleRun.lean`): network-specific by design.

[D] 2026-10-13: the kernel evaluates the run. [M] the kernel check takes
minutes on the box (#120's record states the wall and the memory).
[SRC] src/validation.cpp:4913-5130,6238-6395 at 6504a3af.

### `s6_stale_path_reachable` (`lean/BsvChain/Properties/StaleRun.lean:182`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params` fixed to regtest's record; `cfg` fixed to the census defaults `NodeConfig.defaults`; `oracle` fixed to the evaluator `evalOracle`; `now` fixed to the literal `1296700000`. A statement about the concrete run `staleRunGenesis`, `staleRun1b`, `staleRun2b` and `staleRunFinal` (closed definitions of `lean/BsvChain/Properties/StaleRun.lean`): network-specific by design.

[M] 2026-10-13, #68 G2 (the orphaned-branch class reached by the machine's
own transitions). There is a reachable state, the run from the regtest genesis
that mines T in block 1a, mines the competitor 1b, extends it with 2b and
activates, whose active chain is genesis, 1b, 2b, and in which a transaction
with T's identifier has a path that verifies against 1a's retained stale
header (StalePath) while it is in no active block. No premise: the run is
concrete and kernel-checked. T is block 1a's coinbase; its body holds one
transaction, the body-derived path is `[]`, and verification is root equals
txid. Near genesis no spendable output has reached the pinned maturity.
The path carries no positional information by itself and is not a node-emitted
proof: #75 measured RPC -5 for this body form. The non-degenerate class with
a multi-transaction body and a non-empty path is distinct and owed.
[SRC] src/validation.cpp:2620-2626, src/consensus/merkle.cpp:291-310 and
src/rpc/rawtransaction.cpp:2302-2306 at 6504a3af.
With #65's universal refutation
(`stale_path_does_not_entail_active`, over raw states) this places the
orphaned-proof class among reachable states: path validity against a header
says nothing about the active chain unless the header is on it.
[SRC] src/consensus/merkle.cpp:291-310, src/validation.cpp:4117,4913-5130,6238-6395
and src/chainparams.cpp:1511-1514 at 6504a3af.

### `charterFacts_sound` (`lean/BsvChain/Properties/StaleRun.lean:232`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the executable removal facts mean the propositions.
[SRC] src/validation.cpp:5230-5330 at 6504a3af.

### `staleRunInvalidated_facts` (`lean/BsvChain/Properties/StaleRun.lean:266`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params` fixed to regtest's record; `cfg` fixed to the census defaults `NodeConfig.defaults`; `oracle` fixed to the evaluator `evalOracle`; `now` fixed to the literal `1296700000`. A statement about the concrete run `staleRun1a`, `staleRunWith1a` and `staleRunInvalidated` (closed definitions of `lean/BsvChain/Properties/StaleRun.lean`): network-specific by design.

[D] 2026-10-13: the kernel evaluates the invalidation run.
[SRC] src/validation.cpp:5230-5330 at 6504a3af.

### `s6_charter_removal_false` (`lean/BsvChain/Properties/StaleRun.lean:272`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params` fixed to regtest's record; `cfg` fixed to the census defaults `NodeConfig.defaults`; `oracle` fixed to the evaluator `evalOracle`; `now` fixed to the literal `1296700000`. A statement about the concrete run `staleRunContext` and `staleRun1a` (closed definitions of `lean/BsvChain/Properties/StaleRun.lean`): network-specific by design.

[M] 2026-10-13, #68 theorem 4's charter note, kernel-checked. The charter's
unconditional sentence, "a transaction leaves the active chain only when a
chain of more accumulated work is connected", is false in the machine: from a
reachable state, a completed operator invalidation of the tip (one transition)
reaches a reachable state where a transaction that was in an active block is
in none, and the selected accumulated work strictly decreased. No premise: the
run is concrete. The reference does the same: InvalidateBlock marks the block
failed and disconnects it at once, with no higher-work replacement.
[SRC] src/validation.cpp:5234-5256 at 6504a3af.

## `BsvChain.Properties.Theorems`

### `forIn_except_each` (`lean/BsvChain/Properties/Theorems.lean:23`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: an accepted loop in the error monad ran every element's
body successfully at some carried state, when no body stops early. This is the
shape of the block checks' `for` loops.
[SRC] src/validation.cpp:3061-3117,5853-5889 at 6504a3af.

### `except_bind_ok` (`lean/BsvChain/Properties/Theorems.lean:44`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: a bind in the error monad succeeds exactly when both of
its stages do. A proof device for reading the ordered checks.
[SRC] src/validation.cpp:5749-5901 at 6504a3af.

### `except_throw_bind_ok` (`lean/BsvChain/Properties/Theorems.lean:51`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: a throw followed by anything never succeeds.
[SRC] src/validation.cpp:5749-5901 at 6504a3af.

### `except_throw_ok` (`lean/BsvChain/Properties/Theorems.lean:57`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: a bare throw never succeeds.
[SRC] src/validation.cpp:5749-5901 at 6504a3af.

### `blockTxCheck_coinbase` (`lean/BsvChain/Properties/Theorems.lean:63`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: an accepted coinbase check names a coinbase.
[SRC] src/validation.cpp:5823-5827 at 6504a3af.

### `blockTxCheck_regular` (`lean/BsvChain/Properties/Theorems.lean:72`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: an accepted regular check names a non-coinbase.
[SRC] src/validation.cpp:5877-5889 at 6504a3af.

### `checkBlock_coinbase` (`lean/BsvChain/Properties/Theorems.lean:81`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: an accepted block check leaves a body whose leading
transaction is a coinbase and whose later transactions are not: CheckCoinbase
on the leading one, CheckRegularTransaction (bad-tx-coinbase) on every later one.
[SRC] src/validation.cpp:5788-5791,5823-5827,5877-5889 at 6504a3af.

### `prepare_some` (`lean/BsvChain/Properties/Theorems.lean:131`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `UtxoContext`); `oracle` is not an argument of the statement.

[D] 2026-10-13: a prepared non-genesis connection ran the block check at
the parent's successor height, carries the given parameters and that height,
and, where BIP30 is enforced, found no live coin at any output of the body.
[SRC] src/validation.cpp:3021-3117,3467-3472 at 6504a3af.

### `prepare_none_genesis` (`lean/BsvChain/Properties/Theorems.lean:196`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now`; `oracle` is not an argument of the statement.

[D] 2026-10-13: an accepted connection either prepared a context or is
the genesis block, whose connection publishes only the best pointer.
[SRC] src/validation.cpp:3021-3050 at 6504a3af.

### `connectBlock_parts` (`lean/BsvChain/Properties/Theorems.lean:220`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now`.

[D] 2026-10-13: a successful non-genesis connection exposes its prepared
context, the coinbase reward stage and the executed run.
[SRC] src/validation.cpp:3021-3050,3290-3719 at 6504a3af.

### `lookup_coinMap_mem` (`lean/BsvChain/Properties/Theorems.lean:275`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: a stored pair of the executable map is one of its pairs.
[SRC] src/coins.cpp:548-565 at 6504a3af.

### `createdOutputs_wellFormed` (`lean/BsvChain/Properties/Theorems.lean:291`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: every created coin is live and stored by AddCoin's rule.
[SRC] src/coins.cpp:45-64,548-565 at 6504a3af.

### `updateCoins_wellFormed` (`lean/BsvChain/Properties/Theorems.lean:302`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the pure update keeps a well-formed view well formed.
[SRC] src/validation.cpp:2480-2495 and src/coins.cpp:548-565 at 6504a3af.

### `eraseKeys_wellFormed` (`lean/BsvChain/Properties/Theorems.lean:316`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: erasing keys keeps a view well formed.
[SRC] src/validation.cpp:2483-2491 at 6504a3af.

### `wellFormed_mem_getCoin` (`lean/BsvChain/Properties/Theorems.lean:326`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: in a well-formed view a stored key is a live coin.
[SRC] src/coins.h:235 and src/coins.cpp:116-128 at 6504a3af.

### `applications_wellFormed` (`lean/BsvChain/Properties/Theorems.lean:335`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

[D] 2026-10-13: along an executed run every view is well formed when the
starting view is. [SRC] src/validation.cpp:3290-3447 at 6504a3af.

### `applications_member` (`lean/BsvChain/Properties/Theorems.lean:358`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

[D] 2026-10-13: every receipt of an executed run is an actual applyTx
success from its own preceding view.
[SRC] src/validation.cpp:3290-3447 at 6504a3af.

### `validateUtxoTx_fresh` (`lean/BsvChain/Properties/Theorems.lean:373`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

[D] 2026-10-13: an accepted non-coinbase transaction creates no output
over a live entry left after its own spends: the pin's logic-error guard.
[SRC] src/coins.cpp:386-401,548-565 and src/validation.cpp:2480-2495 at 6504a3af.

### `noBlockOverwrite_of_run` (`lean/BsvChain/Properties/Theorems.lean:397`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

[D] 2026-10-13: the per-application no-overwrite premise of #64 holds for
every non-coinbase receipt of an executed run from a well-formed view (the
pin's guard), so only the coinbase case remains a premise.
[SRC] src/coins.cpp:560-565 and src/undo.h:109-112 at 6504a3af.

### `runBlockTransactions_fees` (`lean/BsvChain/Properties/Theorems.lean:427`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

[D] 2026-10-13: the run's fee tally is the sum of its receipts' fees.
[SRC] src/validation.cpp:3371-3373 at 6504a3af.

### `connected_shape` (`lean/BsvChain/Properties/Theorems.lean:460`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now`.

[D] 2026-10-13: a successful non-genesis connection has its prepared
context at the parent's successor height, its body led by its only coinbase,
and an executed run whose receipts follow the body in order from the parent
view to the published view, with the retained undo vectors.
[SRC] src/validation.cpp:3021-3117,3290-3447,5823-5889 at 6504a3af.

### `s6_no_inflation` (`lean/BsvChain/Properties/Theorems.lean:493`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now`.

[M] 2026-10-13, #68 theorem 2 (no inflation). For every successful
connection of a non-genesis block, under any parameters, configuration,
operator lists, script oracle and time: the block's leading transaction is its
only coinbase; its outputs pay at most the subsidy at the block's height (the
parent's height plus one) plus the block's fees; the fees are the sum, over
the non-coinbase transactions in body order, of each one's input value in the
view immediately before it less its output value; and every non-coinbase
transaction conserves value, its inputs equal to its outputs plus a fee that
is not negative. Premises in plain words: the connection succeeded (`hc`), and
the block is not the network's genesis block (`nonGenesis`), whose connection
creates no coins. The fees are derived from the executed transactions, closing
what `coinbase_amount_bound` left to #64. Burned outputs count as outputs.
[SRC] src/validation.cpp:2252-2263,3371-3373,3655-3668,2639-2663 at 6504a3af.

### `applications_chain` (`lean/BsvChain/Properties/Theorems.lean:531`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

[D] 2026-10-13: receipts chain their views: the leading one starts at the given
view and each next one starts where the previous ended.
[SRC] src/validation.cpp:3290-3447 at 6504a3af.

### `s6_inputs_unspent` (`lean/BsvChain/Properties/Theorems.lean:553`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now`.

[M] 2026-10-13, #68 theorem 3 (every input unspent immediately before its
transaction). For every successful connection of a non-genesis block, under
any parameters, configuration, operator lists, script oracle and time, there
are receipts, one per body transaction in body order, such that: the opening
receipt's view is the parent's coin view; each next receipt's view is exactly
the view the previous transaction left, so an output created earlier in the
same block is available to a later one and an output spent earlier is not; the
last view is the published view; each receipt is an actual applyTx success;
and every input of every non-coinbase transaction names a live coin in the view
immediately before that transaction. The coinbase spends nothing; it follows
its structural and subsidy checks (theorem 2). Premises in plain words: the
connection succeeded and the block is not genesis. The receipts' script judge
is the deferred one when checks are queued; the queued checks are run with the
oracle before the block is published (`finishBlockScripts`).
[SRC] src/validation.cpp:2483-2494,3324-3331,3436-3443 at 6504a3af.

### `coinsAt_lookup` (`lean/BsvChain/Properties/Theorems.lean:588`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: every retained spent coin is the view's own entry.
[SRC] src/validation.cpp:2483-2489 and src/undo.h:80-83 at 6504a3af.

### `restorable_of_wellFormed` (`lean/BsvChain/Properties/Theorems.lean:605`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: a receipt's retained vector from a well-formed view is
already pruned by stored creation height, so restoring filters nothing.
[SRC] src/validation.cpp:2937-2953 and src/coins.cpp:45-64 at 6504a3af.

### `coinbase_receipt_undo` (`lean/BsvChain/Properties/Theorems.lean:615`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

[D] 2026-10-13: the coinbase receipt retains an empty vector.
[SRC] src/validation.cpp:2483-2491,3436-3443 at 6504a3af.

### `s6_undo_identity_coinbase` (`lean/BsvChain/Properties/Theorems.lean:624`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now`.

[M] 2026-10-13, #68 theorem 1, the coinbase case stated separately (undo
correctness). For every successful connection of a non-genesis block followed
by a clean disconnection of the same block with the undo the connection
retained, under any parameters, configuration, operator lists, script oracle
and time, the disconnection restores the original coin set exactly. Premises
in plain words: the connection succeeded (`hc`); the block is not genesis
(`nonGenesis`); the starting view is well formed, every entry a live coin that
AddCoin would store at its own height (`wf`, which every connection preserves);
the coinbase's spendable outputs overwrite no live coin of the parent view
(`coinbaseFresh`); and the disconnection, at the block's height, reported a
clean result (`hd`). The coinbase premise is the reference's own gap: AddCoins
lets a coinbase overwrite a live coin and the block undo keeps no record of it,
so after such an overwrite no undo can restore the lost coin. Every other
transaction's overwrite is refused by the pin's guard, proved here, not assumed.
The landed law is equality of `CoinsView.coins` for `connectBlock` followed
by a clean `disconnectBlock` at the height derived from `previous`. A
`connectTip`/`disconnectTip` law on `ChainState` is owed: `connectTip` takes
its height through `headerContext`, while `disconnectTip` reads the stored
index height, so the lift needs index-height and ancestry invariants.
`WellFormedCoins` is a normalized live-view representation condition motivated
by AddCoin, not an extra block-validity test: a raw map may contain spent
sentinels or entries AddCoin would prune. The condition is sufficient,
preserved with the same parameters, and stronger than requiring only touched
undo coins to be restorable.
[SRC] src/coins.h:235, src/coins.cpp:45-64,386-401,560-565,
src/validation.cpp:3034-3050,4065-4117 and
src/processing_block_index.cpp:30-69 at 6504a3af.
[SRC] src/coins.cpp:560-565, src/undo.h:109-112,
src/processing_block_index.cpp:50-57,79-96 and src/validation.cpp:2483-2494 at 6504a3af.

### `s6_undo_identity` (`lean/BsvChain/Properties/Theorems.lean:715`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now`.

[M] 2026-10-13, #68 theorem 1 (undo correctness), where BIP30 is enforced.
For every successful connection of a non-genesis block whose effective BIP30
check ran (`bip30`: the branch #69 derives, true at every height outside the
two historical exceptions, the BIP34 shortcut and a network-permitted disable
switch), followed by a clean disconnection with the retained undo at the
block's height, under any parameters, configuration, operator lists, script
oracle and time, the disconnection restores the original coin set exactly,
whenever the starting view is well formed (`wf`). No coinbase premise remains:
the connection's own BIP30 loop refused every output of the body over a live
coin of the parent view, the coinbase's among them. Where BIP30 is not
enforced, `s6_undo_identity_coinbase` states the separate law with its premise.
The landed law is equality of `CoinsView.coins` for `connectBlock` followed
by a clean `disconnectBlock` at the height derived from `previous`. A
`connectTip`/`disconnectTip` law on `ChainState` is owed: `connectTip` takes
its height through `headerContext`, while `disconnectTip` reads the stored
index height, so the lift needs index-height and ancestry invariants.
`WellFormedCoins` is a normalized live-view representation condition motivated
by AddCoin, not an extra block-validity test: a raw map may contain spent
sentinels or entries AddCoin would prune. The condition is sufficient,
preserved with the same parameters, and stronger than requiring only touched
undo coins to be restorable.
[SRC] src/coins.h:235, src/coins.cpp:45-64,386-401,560-565,
src/validation.cpp:3034-3050,4065-4117 and
src/processing_block_index.cpp:30-69 at 6504a3af.
[SRC] src/validation.cpp:3061-3117, src/coins.cpp:560-565, src/undo.h:109-112
and src/processing_block_index.cpp:50-57,79-96 at 6504a3af.

### `s6_activation_maximal_work` (`lean/BsvChain/Properties/Theorems.lean:764`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

[M] 2026-10-13, #68 theorem 4 (maximal work). After a successful automatic
activation, under any parameters, configuration, operator lists, script
oracle, budget and time, the active tip names an eligible candidate whose
accumulated work bounds every eligible candidate's, and every retained index
that is eligible (available valid ancestry with its body, not failed, not
soft-rejected or soft-frozen), pruned from the candidate set or not, has work at
most the tip's. Premises in plain words: activation returned complete (`h`),
which the executable checks after every setting change; an interrupted or
failed activation claims nothing; and the chain has a tip (`ht`). The charter's
sentence, "a transaction leaves the active chain only when a chain of more
accumulated work is connected", is false in the machine: an operator's
invalidation disconnects at once with no higher-work replacement
(src/validation.cpp:5234-5256), as do soft rejection and freeze changes, and
an equal-work choice moves the tip without strict growth. The kernel-checked
counterexample is `s6_charter_removal_false`; the landed removal laws name their causes
(`disconnectTip_removal`, `activateBestChain_removal`, `invalidateBlock_removal`,
`setSoftRejection_removal`, `setSoftFreeze_removal`). The removal laws of
`reconsiderBlock` and `preciousBlock` are OWED as their own theorems. Their
`ChainExecution` proof needs unique block index identifiers, either a stated
local condition or a proved reachable-state invariant, never an axiom.
The inherited `activateBestChain_removal` covers their activation today;
`reconsiderBlock_bound` and `preciousBlock_bound` prove body binding, not removal.
[SRC] src/rpc/blockchain.cpp:2770-2818 and
src/validation.cpp:5528-5562,5156-5190 at 6504a3af.
[SRC] src/validation.cpp:4413-4494,4498-4523,4913-5130 and
src/block_index.h:1225-1274 at 6504a3af.

### `s6_activation_work_nondecreasing` (`lean/BsvChain/Properties/Theorems.lean:802`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

[M] 2026-10-13, #68 theorem 4 (the non-decrease). A successful automatic
activation does not decrease the selected work when the previous tip stays
selectable. Premises in plain words: the previous tip is the index the tree
returns for it (`tipBefore`, `indexBefore`) and was eligible (`eligibleBefore`);
no effective soft rejection or freeze count changed (`settings`, the additional
before-and-after hypothesis `EligibilitySettingsUnchanged`, which activation
can violate even with a fixed `ChainContext`); the previous tip still has available
valid ancestry afterwards (`remains`); and activation returned complete (`h`).
On a frozen-input failure `connectRun` calls `freezeBlockIndex`
(lean/BsvChain/Chain.lean:694), editing and propagating freeze counts, as the
reference's `softConsensusFreeze` does on that failure.
[SRC] src/validation.cpp:3402-3407,3720-3741 at 6504a3af.
Strict growth needs, beyond these, the premise that the selected work changed
(`activation_work_strict_growth`): an equal-work choice ordered by completion,
sequence or rank satisfies no strict-growth claim.
[SRC] src/validation.cpp:4413-4523,4755-4767,4913-5130 at 6504a3af.

## `BsvChain.Properties.TxCodec`

### `le32_eq` (`lean/BsvChain/Properties/TxCodec.lean:45`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the 32-bit writer is the fixed-width word of four bytes.
[SRC] src/serialize.h:81-86,105-110 at 6504a3af.

### `le64_eq` (`lean/BsvChain/Properties/TxCodec.lean:50`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the 64-bit writer is the fixed-width word of eight bytes.
[SRC] src/serialize.h:87-92,111-116 at 6504a3af.

### `readBytes_append` (`lean/BsvChain/Properties/TxCodec.lean:55`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: a byte string of the requested length reads back.
[SRC] src/serialize.h:786-792,806-820 at 6504a3af.

### `readVarInt_compactSize` (`lean/BsvChain/Properties/TxCodec.lean:61`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: CompactSize reads back every length below 2^64,
canonically. [SRC] src/serialize.h:296-335 at 6504a3af.

### `readTxIn_serTxIn` (`lean/BsvChain/Properties/TxCodec.lean:84`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: a well-formed input reads back from its serialization.
[SRC] src/primitives/transaction.h:60-66,151-157 at 6504a3af.

### `readTxOut_serTxOut` (`lean/BsvChain/Properties/TxCodec.lean:99`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: a well-formed output reads back from its serialization.
[SRC] src/primitives/transaction.h:189-194 at 6504a3af.

### `readMany_ser` (`lean/BsvChain/Properties/TxCodec.lean:111`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: a list of well-formed items reads back from the
concatenation of their serializations. [SRC] src/serialize.h:794-804,823-840 at 6504a3af.

### `toInt32_version` (`lean/BsvChain/Properties/TxCodec.lean:124`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the signed 32-bit version reads back.
[SRC] src/serialize.h:211-212,245-247 at 6504a3af.

### `decodeTxPrefix_serTx` (`lean/BsvChain/Properties/TxCodec.lean:131`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-13, #68 G4 (the serialization round trip). For every
well-formed transaction, the interpreter's prefix decoder reads its
serialization back exactly and leaves any following bytes untouched.
Premise in plain words: the transaction is well formed (`wf`): a signed 32-bit
version, counts and script lengths that fit CompactSize, 32-bit indices,
sequences and lock time, 64-bit values, 32-byte previous hashes and
byte-valued scripts; every transaction decoded from bytes is so. The
reference's writer and reader also refuse a CompactSize above MAX_SIZE
(src/serialize.h:297-299,336-338); the model's reader leaves that bound out,
as its own docstring says, so this round trip is the model codec's.
[SRC] src/primitives/transaction.h:233-252 and src/serialize.h:71-116,296-340,786-840 at 6504a3af.

### `serTx_injective` (`lean/BsvChain/Properties/TxCodec.lean:158`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the serializer is injective on well-formed transactions.
[SRC] src/primitives/transaction.h:233-252 at 6504a3af.

### `txid_eq_or_collision` (`lean/BsvChain/Properties/TxCodec.lean:166`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-13, #68 G4's corollary (exact identity from the hash alone).
Two well-formed transactions with equal identifiers are equal, or SHA256d has a
collision between their two distinct serializations. Premises in plain words:
both transactions are well formed and their identifiers are equal; no
collision freedom is assumed, so #65's local txid-injectivity premise reduces
to the hash's commitment on these two serializations.
[SRC] src/primitives/transaction.cpp:79-81 at 6504a3af.

### `hashCommits_subset` (`lean/BsvChain/Properties/TxCodec.lean:179`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: collision exclusion on a list holds on every sublist.
[SRC] src/consensus/merkle.cpp:43-50 at 6504a3af.

### `reachable_path_transaction` (`lean/BsvChain/Properties/TxCodec.lean:185`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (through `Reachable`).

[M] 2026-10-13, #68 G3 with G4 (exact transaction inclusion for reachable
states). In every reachable state, a path for a transaction's identifier that
verifies against the header root of an active index with its body retained
proves that this very transaction is in that body and on the active chain.
Premises in plain words: those of `reachable_path_inclusion` (reachability,
the identification of the block, the path shape and the verification), the
well-formedness of the transaction and of every body transaction (true of
every decoded transaction), and the commitment hypothesis extended to their
serializations (a hypothesis of the theorem, never an axiom). #65's local
txid-injectivity premise is no longer assumed: G4 discharges it.
[SRC] src/consensus/merkle.cpp:284-327, src/validation.cpp:5770-5781 and
src/primitives/transaction.h:233-252 at 6504a3af.

## `BsvChain.Properties.Utxo`

### `lookup_eraseKeys` (`lean/BsvChain/Properties/Utxo.lean:16`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Erasing a list removes exactly its keys and leaves every other lookup
unchanged, with no uniqueness assumption. This is the removal half of the
transition's exactness law. [SRC] src/validation.cpp:2483–2491 at 6504a3af.

### `mem_coinMap` (`lean/BsvChain/Properties/Utxo.lean:28`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A finite map made from pairs contains exactly their keys; duplicate keys
do not invent members. This connects the output list to the executable map.
[SRC] src/coins.cpp:548–565 at 6504a3af.

### `lookup_coinsAt` (`lean/BsvChain/Properties/Utxo.lean:37`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The retained undo map is exactly the original lookup restricted to spent
keys. It keeps coins, not a hidden copy of the original UTXO set.
[SRC] src/undo.h:80–83 and src/validation.cpp:2483–2489 at 6504a3af.

### `applyTx_success` (`lean/BsvChain/Properties/Utxo.lean:55`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

Success exposes both validation and the precise pure update; there is no
other successful mutation branch. This bridges later laws to applyTx itself.
[SRC] src/validation.cpp:2480–2495,3326–3434 at 6504a3af.

### `checkTxInputs_fee` (`lean/BsvChain/Properties/Utxo.lean:70`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `UtxoContext`); `oracle` is not an argument of the statement.

Acceptance of the input stage includes acceptance of #60's fee stage.
The proof follows its ordered guards, without assuming a bound on the oracle.
[SRC] src/validation.cpp:2552–2665 at 6504a3af.

### `applyTx_inputs_checked` (`lean/BsvChain/Properties/Utxo.lean:86`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

Every accepted non-coinbase application passed the input stage. Coinbase
is explicitly excluded, since its subsidy and structure are checked by #63.
[SRC] src/validation.cpp:3326–3392 at 6504a3af.

### `applyTx_value_conservation` (`lean/BsvChain/Properties/Utxo.lean:103`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

Value conservation for every accepted non-coinbase transaction: all input
values equal all output values plus an accepted, nonnegative fee. Burned
outputs are included. The statement holds for every oracle; cryptography is
not an assumption. [SRC] src/validation.cpp:2639–2663 at 6504a3af.

### `createdOutputs_membership` (`lean/BsvChain/Properties/Utxo.lean:121`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

Output eligibility has exactly the pin's creation-era predicate. Each
returned pair names an indexed transaction output and its complete coin
metadata; every such spendable output is returned. No validity of script
execution is substituted for the pruning predicate.
[SRC] src/coins.cpp:45–64,548–565 at 6504a3af.

### `applyTx_membership` (`lean/BsvChain/Properties/Utxo.lean:142`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

Complete membership characterization after an accepted application:
eligible new outputs, together with precisely the old keys not spent.
Re-created spent keys appear through the output clause. Combined with
createdOutputs_membership this states both set changes under the creation era.
[SRC] src/validation.cpp:2483–2494 and src/coins.cpp:45–64,548–565 at 6504a3af.

### `applyTx_retained` (`lean/BsvChain/Properties/Utxo.lean:159`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

Outside the eligible outputs, an accepted application removes spent keys
and preserves every other coin, including all metadata. This is the lookup
form of the removal law. [SRC] src/validation.cpp:2483–2494 at 6504a3af.

### `applyTx_added` (`lean/BsvChain/Properties/Utxo.lean:171`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

Every eligible output receives its new coin, even if a coinbase overwrites
a live outpoint. This is the lookup form of the addition law.
[SRC] src/coins.cpp:548–565 at 6504a3af.

### `undo_updateCoins` (`lean/BsvChain/Properties/Utxo.lean:182`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`; `cfg`, `oracle` and `now` are not arguments of the statement.

A one-transaction update followed by its retained undo restores the map
when no eligible output overwrites a remaining entry. For a live UTXO set
this is precisely the no-live-overwrite condition; it allows a spent key to
be re-created. The pin's coinbase overwrite permission makes the hypothesis
necessary, because undo retains no replaced outputs.
[SRC] src/coins.cpp:560–565, src/undo.h:80–83 and
src/processing_block_index.cpp:30–69 at 6504a3af.

### `applyTx_undo` (`lean/BsvChain/Properties/Utxo.lean:222`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

Undo identity for applyTx itself, on every successful application and
under the pin's no-overwrite hypothesis. No assumption about the oracle's
implementation is used. [SRC] src/coins.cpp:560–565 and
src/processing_block_index.cpp:30–69 at 6504a3af.

### `applyTx_deterministic` (`lean/BsvChain/Properties/Utxo.lean:235`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `UtxoContext`).

Determinism includes the undo: fixed explicit inputs and a fixed oracle
yield one result. It uses no clock, network or cryptographic axiom.
This is a definition-level law: applyTx is deterministic because it is a
function of its explicit inputs and the oracle.
[SRC] src/validation.cpp:2480–2495,2552–2665 at 6504a3af.

## `BsvChain.Status`

### `status_deterministic` (`lean/BsvChain/Status.lean:74`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: repeat evaluation of the same explicit state is identical.
This is determinism of a view, never a rule or a persistence guarantee.

### `active_inclusion_wins` (`lean/BsvChain/Status.lean:78`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: hypothesis h : activeHeight s.chain id = some height
selects minedActive height over every pool or rejection journal fact. This ordered-clause theorem concerns views, never rules.

## `BsvChain.Teranode.Alert`

### `set_utxo_self` (`lean/BsvChain/Teranode/Alert.lean:255`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Writing an output's entry makes it the entry the store reads back for that output.

### `find_map_set` (`lean/BsvChain/Teranode/Alert.lean:259`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Rewriting every entry of the output to its new record leaves the new record the one a lookup finds,
when the output had an entry.

### `setFrozen_frozenData` (`lean/BsvChain/Teranode/Alert.lean:277`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

#70's `setFrozen` makes the record the output's.

### `freezeConsensus_record` (`lean/BsvChain/Teranode/Alert.lean:296`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

After #70's `freezeConsensus` the output's record carries the call's intervals and expiry on the ranged
or the confiscated list: a policy-only or absent record moves to the ranged list, a ranged or confiscated
record keeps its list (`src/frozentxo_db.cpp:328-371`) [SRC] 6504a3af.

`[SRC]` `src/frozentxo_db.cpp:328-371`

### `freeze_agrees` (`lean/BsvChain/Teranode/Alert.lean:317`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**The freeze agrees.** Premises: the fund's parent is stored with the output's committed hash and the
output is unspent or already frozen in Teranode's store; the store's height is not past the fund's stop (so
`node.go:339` freezes); the height `h` lies in the fund's interval. Then, at `h` and on both paths, the
output is frozen in Teranode's projection and in the reference's after #70's `freezeConsensus`.
[SRC] `node.go:339-349`, `teranode.lua:713-787` at 4edb60a4; `src/frozentxo.cpp:37-83`,
`src/frozentxo_db.h:323-377` at 6504a3af.

`[SRC]` `node.go:339`, `node.go:339-349`, `src/frozentxo.cpp:37-83`, `src/frozentxo_db.h:323-377`

### `unfreeze_agrees` (`lean/BsvChain/Teranode/Alert.lean:342`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**The unfreeze agrees.** Premises: the fund's parent is stored with the output's committed hash and the
output is frozen or unspent in Teranode's store; the fund's stop is behind the store's height (so
`node.go:339` unfreezes); the fund's policy freeze expires with its interval; the reference's record is not
on the confiscation list; the height `h` is at or past the stop. Then, at `h` and on both paths, the output
is not frozen in either projection. [SRC] `node.go:339-343`, `teranode.lua:795-860` at 4edb60a4;
`src/frozentxo_db.h:323-377` at 6504a3af.

`[SRC]` `node.go:339`, `node.go:339-343`, `src/frozentxo_db.h:323-377`

### `unfreeze_keeps_policy_freeze` (`lean/BsvChain/Teranode/Alert.lean:387`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**Witness: an unfreeze that does not expire the policy freeze.** Under `unfreeze_agrees`'s premises but
the fund's `policyExpiresWithConsensus` false, Teranode's store reads the output not frozen while the
reference still refuses it on the admission path at every height at or past the stop: #70's record keeps
the policy freeze after its intervals (`src/frozentxo_db.h:323-348`) [SRC] 6504a3af, and `node.go:339` reads
neither the expiry flag nor anything but the stop [SRC] 4edb60a4.

`[SRC]` `src/frozentxo_db.h:323-348`, `node.go:339`

### `future_start_frozen_early` (`lean/BsvChain/Teranode/Alert.lean:408`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**Witness: an interval that has not begun.** A fund whose start is above `h` (and whose stop is not
behind the store's height): Teranode freezes the output at once, on both paths; the reference's block path
does not consult the record below the start for a ranged record (`src/frozentxo_db.h:353-377`) [SRC]
6504a3af, so a block at `h` spending it connects on the reference and is refused on Teranode. The premise on
the reference's prior record (none or policy-only) makes the resulting list the ranged one.

`[SRC]` `src/frozentxo_db.h:353-377`

### `stop_passed_still_frozen` (`lean/BsvChain/Teranode/Alert.lean:432`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**Witness: an interval that has ended under a standing freeze.** After a fund that froze the output
(the store's height not past the stop), with the policy freeze expiring with the interval, at every height
at or past the stop the reference reads the output free on both paths of a ranged record, while
Teranode's mark stands until another alert clears it: the store's mark carries no height
(`teranode.lua:768-774`) [SRC] 4edb60a4.

### `freeze_spent_refused` (`lean/BsvChain/Teranode/Alert.lean:457`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**Witness: an output an unmined transaction already spends.** Teranode's `freeze` refuses it with
`SPENT` and the store is unchanged, so the spender stays (`teranode.lua:743-765`) [SRC] 4edb60a4; the
reference records the freeze whatever the output's state (#70's `freezeConsensus` reads only the record) and
its handler then evicts the pool's spenders of frozen outputs (`RemoveFundsFromQueues`,
`src/rpc/frozentxo_rpc.cpp:250-267,375`) [SRC] 6504a3af.

`[SRC]` `src/rpc/frozentxo_rpc.cpp:250-267,375`

### `whitelist_ignores_enforce` (`lean/BsvChain/Teranode/Alert.lean:477`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**Witness: the confiscation's enforce height is not read.** Two confiscation alerts that differ only in
their enforce height leave the same store (`node.go:397-501` reads only the transaction) [SRC] 4edb60a4;
the reference's whitelist entry carries it and admits the transaction from that height
(`src/frozentxo.cpp:133-171`) [SRC] 6504a3af. [D] one-sided: the reference's half is that cited prose, not a
theorem here.

`[SRC]` `node.go:397-501`, `src/frozentxo.cpp:133-171`

### `reassign_gate` (`lean/BsvChain/Teranode/Alert.lean:487`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**Witness: the reassignment's height gate.** After a reassignment of a frozen output, a spend presenting
the new hash is `FROZEN_UNTIL` the store's height plus 1000 while the store's height is below it
(`teranode.lua:371-382,948`; `Interface.go:46-48`) [SRC] 4edb60a4. The reference admits the whitelisted
transaction from the enforce height the operator chose, and a confiscation output's own maturity is
`confiscationMaturity` (PARAMETERS §8.2) [SRC] 6504a3af. [D] one-sided: the reference's half is that cited
prose, not a theorem here.

`[SRC]` `Interface.go:46-48`

### `reassign_strands` (`lean/BsvChain/Teranode/Alert.lean:498`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**Witness: the reassigned output is stranded for its original script.** After the reassignment, a
spend presenting the hash of the output's stored script (the parent transaction the store still holds) meets
`UTXO_HASH_MISMATCH` whenever the new commitment differs from it, whatever the height: the store keeps the
new hash and not the script it commits to (`teranode.lua:922-925`); Teranode's own comment says the
replacement script is not persisted (`node.go:478-480`) [SRC] 4edb60a4.

`[SRC]` `node.go:478-480`

### `whitelist_not_confiscation` (`lean/BsvChain/Teranode/Alert.lean:508`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**Witness: no confiscation-shape check on the alert path.** The reference refuses to whitelist a
transaction that is not a confiscation transaction (its output zero not the `cftx` protocol prefix) and
leaves its lists unchanged (`src/frozentxo_db.cpp:614-636,720-800`) [SRC] 6504a3af; Teranode's
`whitelistInput` reads no output of the transaction, so a frozen input of any transaction is reassigned
(`node.go:411-497`) [SRC] 4edb60a4. [D] one-sided: the theorem states the reference's half; Teranode's half
is the sibling theorem `whitelist_input_reassigns`.

`[SRC]` `src/frozentxo_db.cpp:614-636,720-800`, `node.go:411-497`

### `whitelist_input_reassigns` (`lean/BsvChain/Teranode/Alert.lean:519`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The other half of the same witness: a frozen input with a stored parent, claimed satoshis at most the
parent's and an unlocking script `key` reads is reassigned, whatever the transaction's outputs. [D] one-sided:
the theorem states Teranode's half; the reference's half is the sibling theorem `whitelist_not_confiscation`.

### `ban_agrees` (`lean/BsvChain/Teranode/Alert.lean:569`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now`; `params`, `cfg` and `oracle` are not arguments of the statement.

**The ban agrees** when no ban of the address stands at `now`: Teranode's list after the alert is the
reference's after `setban <a> add <now + 100 years> true` (`src/rpc/net.cpp:726-747`); the RPC refuses
otherwise (`src/rpc/net.cpp:727-731`; `IsBanned` is `GetTime() < nBanUntil`, `src/net/net.cpp:512,527`)
[SRC] 6504a3af.

`[SRC]` `src/rpc/net.cpp:726-747`, `src/rpc/net.cpp:727-731`, `src/net/net.cpp:512,527`

### `unban_agrees` (`lean/BsvChain/Teranode/Alert.lean:579`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**The unban agrees**: the same list after `UnbanPeer` (`node.go:229-255`) and `setban <a> remove`; the
reference's call errors for an address not banned (`src/rpc/net.cpp:748-754`), leaving the list as it was,
which is the same list. [D] Under the key abstraction of `BanList`: a host held under several spellings is the
case this statement does not reach; Teranode clears them all (`internal/banlist/ban_list.go:221-226`), the
reference the one subnet (`src/net/net.cpp:587-594`).

`[SRC]` `node.go:229-255`, `src/rpc/net.cpp:748-754`, `internal/banlist/ban_list.go:221-226`, `src/net/net.cpp:587-594`

### `ban_until_differs` (`lean/BsvChain/Teranode/Alert.lean:590`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now`; `params`, `cfg` and `oracle` are not arguments of the statement.

**Witness: the ban's length.** The alert's ban lasts 100 years on Teranode; the standalone alert system
that drives the reference passes `setban add` with no time (go-alert-system v0.1.17
`app/config/node.go:65-68`) [SRC], which the reference reads as `-bantime`, a day by default. Stated on the
two transitions when no ban of the address stands at `now`: the ban's end each list records differs.

`[SRC]` `app/config/node.go:65-68`

### `alert_invalidate_is_operator_invalidate` (`lean/BsvChain/Teranode/Alert.lean:616`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The alert adds no step of its own to Teranode's invalidation.

### `alert_invalidate_refines` (`lean/BsvChain/Teranode/Alert.lean:627`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

Under #88's `invalidation` row the alert's invalidation is the reference's: the alert path discharges
nothing of the row and adds nothing to it.

### `trust_root_changes_who_not_what` (`lean/BsvChain/Teranode/Alert.lean:665`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**The trust root changes who, never what.** Under any two authorities that both admit a request, the
same action is applied to the same state: the parameter set is the same and only the trust root differs.
No premise beyond the two admissions. [D] by construction: whichever authority admits a request, the gate
applies the same action; whether the two nodes' actions agree is the module's §4 and §5.

## `BsvChain.Teranode.Bridge`

### `Message.all_length` (`lean/BsvChain/Teranode/Bridge.lean:72`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: the table has 39 rows.

### `Message.mem_all` (`lean/BsvChain/Teranode/Bridge.lean:75`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: every message type is a row of the table.

### `bridge_rows_distinct` (`lean/BsvChain/Teranode/Bridge.lean:329`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: one constructor per row: no two rows share a handling.

### `bridge_counts` (`lean/BsvChain/Teranode/Bridge.lean:332`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: the reading half's count, 13 SAME, 7 TRANSLATED, 19 DROPPED.

### `reachable_drops` (`lean/BsvChain/Teranode/Bridge.lean:337`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: the reading half's five reachable drops: `reject`, `sendcmpct`, `dsdetected`, `revokemid`,
`authch`.

### `handleTx_accepted_iff` (`lean/BsvChain/Teranode/Bridge.lean:412`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: the bridge accepts only on the validator's no-error answer, for an id it has not rejected.

### `accepted_verdict` (`lean/BsvChain/Teranode/Bridge.lean:418`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: under the correspondence, the bridge's acceptance is the machine's `accepted` verdict.

### `bridge_accept_relayed` (`lean/BsvChain/Teranode/Bridge.lean:425`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: **THE BRIDGE ACCEPTS ONLY WHAT THE MACHINE RELAYS.** A transaction the bridge accepts from a
peer (`handleTxMsg` reaching the announcement, `manager.go:1385`, on `Validate`'s no-error answer at `:1320`),
the validator's answer agreeing with the machine's verdict, is one #78's protocol machine relays on receiving it
from the same peer: it joins the pool and the propagator's queue. The machine's side conditions are the
reference's own: the peer present and not under blocks-only (`net_processing.cpp:3356-3364`), the transaction new
to the machine (`IsTxnKnown`, `:930-961`; a known one is `bridge_known_accept_diverges`), not a miner-info data
transaction (`src/net/net.cpp:3576-3578`). A view, never a rule.

`[SRC]` `manager.go:1385`, `manager.go:1320`, `net_processing.cpp:3356-3364`, `net_processing.cpp:930-961`, `src/net/net.cpp:3576-3578`

### `bridge_accept_reaches_peers` (`lean/BsvChain/Teranode/Bridge.lean:449`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: **AND THE MACHINE ANNOUNCES IT.** Under `bridge_accept_relayed`'s conditions the propagator's
next pass queues the transaction for every other peer that relays transactions, passes its fee filter and loaded
filter and is not known to have it (from #78's `accepted_queued_for_unseen`). "Relayed" is the machine's queue,
never the bytes on a socket: the bridge's own outbound relay is the txmeta topic (B5, `manager.go:3955`), outside
the accept road, and measured by the harness. A view, never a rule.

`[SRC]` `manager.go:3955`

### `bridge_known_accept_diverges` (`lean/BsvChain/Teranode/Bridge.lean:466`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: **THE RESUBMIT** (`BridgeDivergence.resubmitReannounced`). A transaction the machine already
knows is not queued again on a `tx` from a peer that is not whitelisted under forced relay
(`net_processing.cpp:3380-3392`): the machine's queue is unchanged. The bridge's validator answers a transaction
already in the store with an idempotent success (`Validator.go:1106-1117`), so the bridge announces it again. A view,
never a rule.

`[SRC]` `net_processing.cpp:3380-3392`, `Validator.go:1106-1117`

### `bridge_tx_refines` (`lean/BsvChain/Teranode/Bridge.lean:480`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: **THE TOTAL FORM.** Every acceptance by the bridge, the correspondence holding and the peer
not whitelisted under forced relay, is a relay of the machine, or the machine already knows the transaction (its
pool, its recent rejects or its orphans, `Node.knows`, `IsTxnKnown` `net_processing.cpp:930-961`) and its queue
stands. The pool case is the named divergence `resubmitReannounced`; the other two are states the two memories reach
apart (an earlier receipt the machine refused, a parent the machine does not know), measured by #98's bridge rows. A
view, never a rule.

`[SRC]` `net_processing.cpp:930-961`

### `bridge_rejected_ignored` (`lean/BsvChain/Teranode/Bridge.lean:499`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: **THE REJECTED ID.** The bridge ignores a transaction whose id it has rejected, with no reject
(`manager.go:1295-1299`); the machine, its inventory test holding the id among its recent rejects, relays nothing and
answers nothing for a peer not whitelisted under forced relay (`net_processing.cpp:930-961`, `:3380-3392`). Both
memories are cleared at a block: the bridge's at each accepted block (`manager.go:2181`), the reference's when the
active tip moves (`net_processing.cpp:934-942`). A view, never a rule.

`[SRC]` `manager.go:1295-1299`, `net_processing.cpp:930-961`, `net_processing.cpp:3380-3392`, `manager.go:2181`, `net_processing.cpp:934-942`

### `bridge_reject_flattened` (`lean/BsvChain/Teranode/Bridge.lean:515`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: **THE FLATTENED REJECT** (`BridgeDivergence.rejectFlattened`). The bridge's `reject` for a
rejected transaction carries 0x10 and `rejected` whatever the validator said (`manager.go:1368`); the machine's
carries the verdict's own code and reason (`src/validation.cpp:1934-1952`). The two messages are equal only when
the verdict's code is 0x10 and its reason is `rejected`. A view, never a rule.

`[SRC]` `manager.go:1368`, `src/validation.cpp:1934-1952`

### `bridge_reject_flattened_witness` (`lean/BsvChain/Teranode/Bridge.lean:528`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: a witness of `bridge_reject_flattened`: a verdict refused for a non-standard script (0x40,
`REJECT_NONSTANDARD`, `src/consensus/validation.h:16-24`) reaches the peer from the reference with its code and
from the bridge as 0x10. A view, never a rule.

`[SRC]` `src/consensus/validation.h:16-24`

### `bridge_announce_passes_fee_filter` (`lean/BsvChain/Teranode/Bridge.lean:534`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: **THE FEE FILTER** (`BridgeDivergence.feeFilterBypassed`). An announcement with no size passes
every peer's fee filter (`peer_server.go:2736-2755`: the rate stays at the maximum when the size is 0); in the
machine's terms the fee at any rate of a zero size is 0. A view, never a rule.

`[SRC]` `peer_server.go:2736-2755`

### `fee_filter_withholds_witness` (`lean/BsvChain/Teranode/Bridge.lean:540`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: the machine withholds a transaction below a peer's filter: at 1000 satoshis per kilobyte a
250-byte transaction paying 100 is not offered (`src/net/net.cpp:861-866`), where the bridge's sizeless announcement
is. A view, never a rule.

`[SRC]` `src/net/net.cpp:861-866`

### `bridge_orphan_relayed` (`lean/BsvChain/Teranode/Bridge.lean:564`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: **A FREED ORPHAN THE BRIDGE ACCEPTS, THE MACHINE RELAYS.** An orphan the bridge accepts when its
parent arrives (`orphanStep` `.ok`, the correspondence giving `accepted`), held by the machine as an orphan, is
relayed by the machine's retry: it joins the pool and the queue (#78's `Node.retryOrphan`;
`src/txn_validator.cpp:695-720`). A view, never a rule.

`[SRC]` `src/txn_validator.cpp:695-720`

### `bridge_orphan_reaches_peers` (`lean/BsvChain/Teranode/Bridge.lean:580`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: and the propagator's next pass queues it for every peer that relays transactions, passes its
filters and is not known to have it (from #78's `retryOrphan_accepted_queued_for_unseen`). A view, never a rule.

### `misbehaving_orphans` (`lean/BsvChain/Teranode/Bridge.lean:595`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: a misbehavior increment leaves the orphans alone.

### `bridge_orphan_invalid_kept` (`lean/BsvChain/Teranode/Bridge.lean:604`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: **THE KEPT ORPHAN** (`BridgeDivergence.invalidOrphanKept`). An orphan whose retry is invalid
leaves the machine's orphans (`src/validation.cpp:1954-2003`; #78's `retryOrphan`), while the bridge keeps it until
its eviction (`orphanStep` `.stays`; `manager.go:3615`, `:3674-3686`). A view, never a rule.

`[SRC]` `src/validation.cpp:1954-2003`, `manager.go:3615`, `manager.go:3674-3686`

### `bridge_inv_requests` (`lean/BsvChain/Teranode/Bridge.lean:629`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: **THE INVENTORY ROAD.** An `inv` entry the bridge requests (RUNNING, the store not having it),
with the FSM's RUNNING standing for the machine's download latch being off and the store's "have it" for the
machine's inventory test (`BridgeDivergence.invGatedByFsm` where they part), the peer present and not under
blocks-only, its request queue under the cap and the id neither in flight from it nor queued for it, is asked for by
the machine (`ProcessInvMessage`, `net_processing.cpp:2454-2532`; `AskFor`, `src/net/net.cpp:3269-3318`). A view,
never a rule.

`[SRC]` `net_processing.cpp:2454-2532`, `src/net/net.cpp:3269-3318`

### `bridge_block_filter` (`lean/BsvChain/Teranode/Bridge.lean:701`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: **THE BRIDGE ADDS NO BLOCK ACCEPTANCE.** A block the bridge accepts is one Teranode's block
validation accepts, and within the bridge's read bound. A view, never a rule.

### `bridge_block_accepted` (`lean/BsvChain/Teranode/Bridge.lean:708`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: **THE BLOCK ROAD.** A block the bridge accepts, the block verdict corresponding, is one the
reference accepts, or its checksum failed (the named divergence `checksumSkipped`: the bridge carries a block whose
header checksum is wrong and whose payload Teranode's validation accepts; the reference drops that message before
dispatch, and accepts the same block delivered with its checksum). A view, never a rule.

### `bridge_block_unrequested` (`lean/BsvChain/Teranode/Bridge.lean:721`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: **THE UNREQUESTED BLOCK** (`BridgeDivergence.unrequestedBlockDropped`). Off regtest, a block the
bridge did not request is not accepted through it, whatever the validation would say; the reference hands it to
`ProcessNewBlock` (`net_processing.cpp:4068-4074`, the call `:4092`), forced only for a whitelisted peer, where
`AcceptBlock` may still skip an unrequested block (`src/validation.cpp:6309-6324`); `refVerdict` carries that answer.
A view, never a rule.

`[SRC]` `net_processing.cpp:4068-4074`, `net_processing.cpp:4092`, `src/validation.cpp:6309-6324`

### `bridge_block_bound` (`lean/BsvChain/Teranode/Bridge.lean:731`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: **THE READ BOUND** (`BridgeDivergence.blockReadBound`). A block above 4,000,000,000 bytes is never
accepted through the bridge. A view, never a rule.

### `BridgeDivergence.mem_all` (`lean/BsvChain/Teranode/Bridge.lean:826`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: `BridgeDivergence.all` lists every constructor.

### `BridgeDivergence.rows_classed` (`lean/BsvChain/Teranode/Bridge.lean:859`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: every divergence sits on a TRANSLATED row, on row 25 (`feefilter`, SAME but for the
announcement's size) or on one of the five reachable DROPPED rows. A view, never a rule.

## `BsvChain.Teranode.Chain`

### `fire_ok_iff` (`lean/BsvChain/Teranode/Chain.lean:144`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: an event succeeds exactly when the table lists it for the
state; a refused event is the library's error, never a silent no-op. A view of
the service, never a validity rule. [SRC] `fsm.go:17-58` at 4edb60a4.

`[SRC]` `fsm.go:17-58`

### `fire_moves` (`lean/BsvChain/Teranode/Chain.lean:151`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: the table has no self-loop, so every accepted event moves
the machine; an observation names the state it was taken in (#97). [SRC]
`fsm.go:17-42` at 4edb60a4.

`[SRC]` `fsm.go:17-42`

### `fire_error_keeps` (`lean/BsvChain/Teranode/Chain.lean:159`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: a refused or unpersisted event leaves the state where it
was (`fsm.go:76-84`). [SRC] 4edb60a4.

`[SRC]` `fsm.go:76-84`

### `fsm_reachable` (`lean/BsvChain/Teranode/Chain.lean:166`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: every state is one event from IDLE, the initial state
(`fsm.go:109-110`); the machine has no unreachable state. [SRC] 4edb60a4.

`[SRC]` `fsm.go:109-110`

### `floater_invalidated_only_running` (`lean/BsvChain/Teranode/Chain.lean:191`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: a floater is invalidated only in RUNNING; in a sync state
the same block is retried, so a chain-selection observation is comparable
with the reference's only in RUNNING (#97). [SRC] `BlockValidation.go:2337-2357,2487-2509,2650-2657`
at 4edb60a4.

`[SRC]` `BlockValidation.go:2337-2357,2487-2509,2650-2657`

### `optimistic_off_at_defaults` (`lean/BsvChain/Teranode/Chain.lean:234`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: at the defaults no path is optimistic: the global flag is
on, the peer-blocks flag off, and the second gates every path
(`settings/settings.go:375-376`, `BlockValidation.go:2166-2176`). `settings.conf`
at the tag sets neither key ([M] `git show 4edb60a4:settings.conf | grep -ci optimistic`: 0),
so the instance of record runs the defaults. [SRC] 4edb60a4.

`[SRC]` `settings/settings.go:375-376`, `BlockValidation.go:2166-2176`

### `before_work` (`lean/BsvChain/Teranode/Chain.lean:291`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: a row sorted before another has at least its work: work is the query's primary key. [SRC] `GetBestBlockHeader.go:135` at 4edb60a4.

`[SRC]` `GetBestBlockHeader.go:135`

### `not_before_work` (`lean/BsvChain/Teranode/Chain.lean:297`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: a row not sorted before another has at most its work. [SRC] `GetBestBlockHeader.go:135` at 4edb60a4.

`[SRC]` `GetBestBlockHeader.go:135`

### `pickStep_some` (`lean/BsvChain/Teranode/Chain.lean:303`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: one step of `LIMIT 1` always keeps a row.

### `pickStep_spec` (`lean/BsvChain/Teranode/Chain.lean:312`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: what one step keeps bounds both its inputs and is one of them.

### `foldl_pick` (`lean/BsvChain/Teranode/Chain.lean:339`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: the row the ordered scan keeps came from the scan or its start, and bounds the work of both. [SRC] `GetBestBlockHeader.go:114-137` at 4edb60a4.

`[SRC]` `GetBestBlockHeader.go:114-137`

### `firstRow_maximal` (`lean/BsvChain/Teranode/Chain.lean:373`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: the row `LIMIT 1` returns is a member and bounds the work
of every row it sorted. [SRC] `GetBestBlockHeader.go:114-137` at 4edb60a4.

`[SRC]` `GetBestBlockHeader.go:114-137`

### `best_maximal_work` (`lean/BsvChain/Teranode/Chain.lean:380`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #93 theorem 2 (Teranode's side). The best header is a
stored row not marked invalid, and its cumulative work is at least every such
row's: the query's `WHERE invalid = false ORDER BY chain_work DESC` read as a
law. "Valid" here is the stored flag, not a proof of validation: under
optimistic mining a row is stored before its block is validated (section 6),
and an ancestor's flag is not read (a child stored after its parent's
invalidation inherits the flag at insert, `StoreBlock.go:554-560`; the
revalidation path of section 7 refuses a block under an invalid parent).
The reference's side is `BsvChain.Properties.activation_maximal_work`.
[SRC] `GetBestBlockHeader.go:114-137`, `Server.go:1679` at 4edb60a4.

`[SRC]` `StoreBlock.go:554-560`, `GetBestBlockHeader.go:114-137`, `Server.go:1679`

### `bestRow_append` (`lean/BsvChain/Teranode/Chain.lean:396`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: the best header changes at an insert only to the new row,
by one comparison with the old best. [SRC] `StoreBlock.go:306-434` at 4edb60a4.

`[SRC]` `StoreBlock.go:306-434`

### `selected_work_agrees` (`lean/BsvChain/Teranode/Chain.lean:403`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #88 obligation of the map row `chain-selection`. Under a
correspondence of the two candidate sets that preserves work (every reference
candidate has a stored valid row of its work, and back), the reference's
selection and Teranode's best header carry the same work. Given only when
`Validated` holds (section 6): an optimistically stored row has no reference
candidate. [SRC] `src/validation.cpp:4413-4494` at 6504a3af;
`GetBestBlockHeader.go:114-137` at 4edb60a4.

`[SRC]` `src/validation.cpp:4413-4494`, `GetBestBlockHeader.go:114-137`

### `active_work_agrees` (`lean/BsvChain/Teranode/Chain.lean:423`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #88 obligation of `chain-selection`, against the
reference's completed activation: its active tip names an eligible index whose
work is Teranode's best header's, under the same correspondence over
`eligibleCandidates`. [SRC] `src/validation.cpp:4413-4494,4913-5126` at 6504a3af;
`GetBestBlockHeader.go:114-137` at 4edb60a4.

`[SRC]` `src/validation.cpp:4413-4494,4913-5126`, `GetBestBlockHeader.go:114-137`

### `teranode_tie_peer` (`lean/BsvChain/Teranode/Chain.lean:442`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: Teranode's equal-work tie goes to the smaller peer rank,
whatever arrived earlier. [SRC] `GetBestBlockHeader.go:135` at 4edb60a4.

`[SRC]` `GetBestBlockHeader.go:135`

### `reference_tie_earlier` (`lean/BsvChain/Teranode/Chain.lean:448`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: the reference's equal-work tie goes, at equal completion
key, to the earlier sequence id (the block received earlier), whatever its
source. [SRC] `src/block_index.h:1225-1274` at 6504a3af.

`[SRC]` `src/block_index.h:1225-1274`

### `tie_rules_differ` (`lean/BsvChain/Teranode/Chain.lean:460`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15, a model witness: two rows of equal work, the later insert
(`id` 2) with the smaller peer rank; Teranode's best header is the later one,
where the reference keeps the earlier received (`reference_tie_earlier`).
Read from source, unobserved: scenario variant `tie` owes the run (#66).

### `le_maxId` (`lean/BsvChain/Teranode/Chain.lean:522`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: every stored id is at most the largest.

### `storeBlock_shape` (`lean/BsvChain/Teranode/Chain.lean:532`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: an insert appends one row, with the block's hash, peer rank, transactions and pending mark, and the next id, to a table that did not hold the hash. [SRC] `StoreBlock.go:100-437` at 4edb60a4.

`[SRC]` `StoreBlock.go:100-437`

### `lookup_append` (`lean/BsvChain/Teranode/Chain.lean:550`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: an insert never changes the row an existing hash names. [SRC] `sql.go:770` at 4edb60a4.

`[SRC]` `sql.go:770`

### `descends_append` (`lean/BsvChain/Teranode/Chain.lean:557`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: an insert never cuts an existing ancestry: every chain of `previous_hash` links survives it.

### `tx_append` (`lean/BsvChain/Teranode/Chain.lean:564`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: if the best header is unchanged by an insert, every transaction on its chain stays on the longest chain.

### `tx_leaves_only_on_more_work` (`lean/BsvChain/Teranode/Chain.lean:572`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #93 theorem 3 (Teranode's side, a block's arrival). A
transaction leaves the longest chain when a block is stored only if the
stored block becomes the best header with more work than the old best, or
with equal work and a smaller peer rank. The insertion id cannot win: the new
row's id is the largest. The equal-work case is the second oracle's own
(`equal_work_tie_moves_tip`); the reference's equal-work tie keeps the earlier
block (`reference_tie_earlier`). The other transitions that move the best
header (invalidate, revalidate) remove without more work, in both machines
(`invalidate_lowers_work`; `BsvChain.Properties.s6_charter_removal_false`).
[SRC] `StoreBlock.go:100-437`, `GetBestBlockHeader.go:114-137`,
`BlockAssembler.go:1108-1175` at 4edb60a4.

`[SRC]` `StoreBlock.go:100-437`, `GetBestBlockHeader.go:114-137`, `BlockAssembler.go:1108-1175`

### `tx_leaves_strict_one_peer` (`lean/BsvChain/Teranode/Chain.lean:606`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #93 theorem 3 with one peer rank (every stored row and the
arriving block share it, as for blocks the node mines itself, each stored with
`peer_id` `""`, `services/blockassembly/Server.go:2099`; `submitblock` is
unimplemented, `services/rpc/Server.go:211`): a
transaction leaves the longest chain at a block's arrival only when strictly
more work is connected, the reference's form under the same premise.
[SRC] `GetBestBlockHeader.go:135`, `StoreBlock.go:100-437` at 4edb60a4.

`[SRC]` `services/blockassembly/Server.go:2099`, `services/rpc/Server.go:211`, `GetBestBlockHeader.go:135`, `StoreBlock.go:100-437`

### `descends_root` (`lean/BsvChain/Teranode/Chain.lean:630`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: no ancestor above a root: a row without a parent descends only to itself.

### `descends_cases` (`lean/BsvChain/Teranode/Chain.lean:637`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: one step down a chain.

### `tie_store` (`lean/BsvChain/Teranode/Chain.lean:658`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: the tie witness's insert: `B` stored with its parent's work plus its own and the next id. [SRC] `StoreBlock.go:100-437` at 4edb60a4.

`[SRC]` `StoreBlock.go:100-437`

### `equal_work_tie_moves_tip` (`lean/BsvChain/Teranode/Chain.lean:661`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15, a model witness: a block of equal work from a peer of
smaller rank moves the best header, and transaction 10 leaves the longest
chain with no more work connected; the reference keeps `A`, received earlier
(`reference_tie_earlier`). Read from source, unobserved: the scenario's
variant `tie` owes the run on both nodes (#66). The reference's half is read
from `reference_tie_earlier` and `src/validation.cpp:4913-5126`, not computed
in this theorem. [SRC] `GetBestBlockHeader.go:135`,
`StoreBlock.go:100-437` at 4edb60a4.

`[SRC]` `src/validation.cpp:4913-5126`, `GetBestBlockHeader.go:135`, `StoreBlock.go:100-437`

### `markUpdate_txid` (`lean/BsvChain/Teranode/Chain.lean:735`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: the mark changes a record's bin, never its key. [SRC] `longest_chain.go:115-131` at 4edb60a4.

`[SRC]` `longest_chain.go:115-131`

### `backdated_pos` (`lean/BsvChain/Teranode/Chain.lean:740`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: a stamp is never 0, the value that reads as mined.
[SRC] `pruner_unmined.go:28-35` at 4edb60a4.

`[SRC]` `pruner_unmined.go:28-35`

### `mark_off_keeps` (`lean/BsvChain/Teranode/Chain.lean:745`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: off the longest chain never overwrites an existing value
(issue 1768's guard). [SRC] `longest_chain.go:75-87` at 4edb60a4.

`[SRC]` `longest_chain.go:75-87`

### `mark_idempotent` (`lean/BsvChain/Teranode/Chain.lean:749`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: each mark is idempotent, so a repeated batch (a retry, a
duplicate hash) writes nothing new. [SRC] `longest_chain.go:68-87` at 4edb60a4.

`[SRC]` `longest_chain.go:68-87`

### `mark_off_on_record` (`lean/BsvChain/Teranode/Chain.lean:755`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: per record, off then on restores the record exactly when
it was mined on the longest chain. [SRC] `longest_chain.go:68-87` at 4edb60a4.

`[SRC]` `longest_chain.go:68-87`

### `mark_off_on_identity` (`lean/BsvChain/Teranode/Chain.lean:761`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #93 theorem 1. Marking a set of mined records off the
longest chain and back on is the identity on the store, at any two heights:
the second oracle's form of the reference's undo identity
(`BsvChain.Properties.s6_undo_identity`, connect then disconnect restores the
coins). Premises in plain words: every listed transaction has a record (else
the store stops), and every listed record is mined on the longest chain
(`unminedSince` absent), the state a reorg's moved-back block leaves its
transactions in before the reorg. [SRC] `longest_chain.go:49-196`,
`stores/utxo/sql/sql.go:4927-4941` at 4edb60a4.

`[SRC]` `longest_chain.go:49-196`, `stores/utxo/sql/sql.go:4927-4941`

### `mark_on_off_restamps` (`lean/BsvChain/Teranode/Chain.lean:792`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: the other order, on then off (a block connected, then
moved back), does not undo: the record comes back unmined with the stamp, not
with the value it had. The store keeps no undo; what it restores is the
unmined view (`isSome`), never the clock. [SRC] `longest_chain.go:68-87`,
`pruner_unmined.go:16-35` at 4edb60a4.

`[SRC]` `longest_chain.go:68-87`, `pruner_unmined.go:16-35`

### `mark_on_off_not_identity` (`lean/BsvChain/Teranode/Chain.lean:800`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15, a model witness: an unmined transaction stamped at 50,
mined at height 300 and moved back at height 300 under the default retention
of 144, reads `unminedSince` 156, not 50; connect then disconnect is the
identity on the reference's coins (`s6_undo_identity`) and not on this bin.
[SRC] `longest_chain.go:68-87`, `pruner_unmined.go:29-35` at 4edb60a4.

`[SRC]` `longest_chain.go:68-87`, `pruner_unmined.go:29-35`

### `storeBlock_validated` (`lean/BsvChain/Teranode/Chain.lean:827`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: a non-pending insert keeps the obligation.
[SRC] `StoreBlock.go:100-437` at 4edb60a4.

`[SRC]` `StoreBlock.go:100-437`

### `addBlock_validated_at_defaults` (`lean/BsvChain/Teranode/Chain.lean:840`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: at the defaults every path keeps the obligation, so the
best header's "not marked invalid" is "validated in full".
[SRC] `settings/settings.go:375-376`, `BlockValidation.go:2166-2176` at 4edb60a4.

`[SRC]` `settings/settings.go:375-376`, `BlockValidation.go:2166-2176`

### `best_validated` (`lean/BsvChain/Teranode/Chain.lean:849`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: under the obligation the best header is validated and has
maximal work among the stored rows not marked invalid: theorem 2 with what
it assumes made explicit. [SRC] `GetBestBlockHeader.go:114-137` at 4edb60a4.

`[SRC]` `GetBestBlockHeader.go:114-137`

### `optimistic_best_pending` (`lean/BsvChain/Teranode/Chain.lean:857`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15, a model witness: with both flags on, a peer-served block of
more work becomes the best header before its validation has run. Read from
source, unobserved: the instance of record runs the defaults, where this
cannot happen (`optimistic_off_at_defaults`). [SRC] `BlockValidation.go:2166-2249`
at 4edb60a4.

`[SRC]` `BlockValidation.go:2166-2249`

### `closure_mono` (`lean/BsvChain/Teranode/Chain.lean:879`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: the recursive CTE never drops a hash it has collected, the target among them. [SRC] `InvalidateBlock.go:99-113` at 4edb60a4.

`[SRC]` `InvalidateBlock.go:99-113`

### `invalidate_marks` (`lean/BsvChain/Teranode/Chain.lean:906`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: after an invalidation every row of the returned set is
marked invalid, the target among them. [SRC] `InvalidateBlock.go:99-113` at 4edb60a4.

`[SRC]` `InvalidateBlock.go:99-113`

### `invalidate_unknown` (`lean/BsvChain/Teranode/Chain.lean:928`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: an unknown hash is invalidated successfully and nothing
moves; the reference's RPC refuses it with `RPC_INVALID_ADDRESS_OR_KEY`,
"Block not found" (`src/rpc/blockchain.cpp:2752-2756` at 6504a3af).
[SRC] `InvalidateBlock.go:74-85`, `handlers.go:1880-1885` at 4edb60a4.

`[SRC]` `src/rpc/blockchain.cpp:2752-2756`, `InvalidateBlock.go:74-85`, `handlers.go:1880-1885`

### `reconsider_refuses_under_invalid_parent` (`lean/BsvChain/Teranode/Chain.lean:1010`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: Teranode's `reconsiderblock` of a block under an invalid
parent is refused and changes nothing; the parent is never cleared from
below. [SRC] `BlockValidation.go:2001-2042`, `handlers.go:1945-1952` at 4edb60a4.

`[SRC]` `BlockValidation.go:2001-2042`, `handlers.go:1945-1952`

### `reference_reconsider_clears_ancestors` (`lean/BsvChain/Teranode/Chain.lean:1020`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params`, `cfg` and `now` through `ChainContext`).

[M] 2026-10-15: the reference's `reconsiderblock` clears the failure flags
of every ancestor of the reconsidered block before it activates, so a
descendant can bring its invalidated ancestor back.
[SRC] `src/validation.cpp:5554-5560`, `src/rpc/blockchain.cpp:2798-2811` at 6504a3af.

`[SRC]` `src/validation.cpp:5554-5560`, `src/rpc/blockchain.cpp:2798-2811`

### `invalidate_A` (`lean/BsvChain/Teranode/Chain.lean:1043`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: the invalidation witness's step: `A` and its child `C` marked invalid, both hashes returned. [SRC] `InvalidateBlock.go:62-182` at 4edb60a4.

`[SRC]` `InvalidateBlock.go:62-182`

### `invalidate_lowers_work` (`lean/BsvChain/Teranode/Chain.lean:1046`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15, a model witness against the issue's unconditional
sentence: `invalidateblock A` takes transaction 10 off the longest chain and
lowers the best header's work from 3 to 1. The reference's
`BsvChain.Properties.s6_charter_removal_false` is the same refutation in its
machine. [SRC] `InvalidateBlock.go:62-182`, `GetBestBlockHeader.go:114-137`
at 4edb60a4.

`[SRC]` `InvalidateBlock.go:62-182`, `GetBestBlockHeader.go:114-137`

### `reconsider_descendant_differs` (`lean/BsvChain/Teranode/Chain.lean:1067`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15, a model witness: after `invalidateblock A`, Teranode's
`reconsiderblock C` is refused (its parent is invalid) and the best header
stays `G`; the reference's clears `A` as `C`'s ancestor
(`reference_reconsider_clears_ancestors`) and activates back to `C`.
`reconsiderblock A` brings `C` back on both. Read from source, unobserved:
the scenario's variant `reconsider` owes the run (#66). The reference's half
is read from `reference_reconsider_clears_ancestors` and
`src/validation.cpp:4913-5126`, not computed in this theorem.
[SRC] `handlers.go:1919-2028`, `BlockValidation.go:2001-2042` at 4edb60a4.

`[SRC]` `src/validation.cpp:4913-5126`, `handlers.go:1919-2028`, `BlockValidation.go:2001-2042`

## `BsvChain.Teranode.Lifetimes`

### `setDAH_inv` (`lean/BsvChain/Teranode/Lifetimes.lean:352`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

`setDeleteAtHeight` re-establishes the invariant from its two side
conditions alone, whatever the record's blocks were before (the invalidation
case removes the last one).

### `setDAH_locked` (`lean/BsvChain/Teranode/Lifetimes.lean:387`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Re-evaluating the deletion height never touches the lock.

### `setDAH_spendingHeight` (`lean/BsvChain/Teranode/Lifetimes.lean:394`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Re-evaluating the deletion height never touches a coinbase's spending height.

### `step_inv` (`lean/BsvChain/Teranode/Lifetimes.lean:401`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Every store transition keeps the invariant.

### `reach_inv` (`lean/BsvChain/Teranode/Lifetimes.lean:446`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now` (through `Reach`); `params`, `cfg` and `oracle` are not arguments of the statement.

A run of store transitions from a record that satisfies the invariant ends in one that does.

### `created_inv` (`lean/BsvChain/Teranode/Lifetimes.lean:453`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Both create paths write a record that satisfies the invariant: an unmined
record has no deletion height; a mined one has a block.

### `reachable_inv` (`lean/BsvChain/Teranode/Lifetimes.lean:461`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (through `Reachable`).

The invariant holds in every reachable record.

### `prune_only_mined_or_conflicting` (`lean/BsvChain/Teranode/Lifetimes.lean:468`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (through `Reachable`).

The pruner deletes only a conflicting record or one with a block ID.

### `never_mined_kept` (`lean/BsvChain/Teranode/Lifetimes.lean:477`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (through `Reachable`).

A record never mined and not conflicting is kept by every pruner cycle at
every height, whatever its age.

### `preserved_kept` (`lean/BsvChain/Teranode/Lifetimes.lean:487`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (through `Reachable`).

A preserved record is kept by every pruner cycle while preserved.

### `reference_expires_old` (`lean/BsvChain/Teranode/Lifetimes.lean:492`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `now`; `params` and `oracle` are not arguments of the statement.

The reference's expiry removes every accepted entry whose entry time is
strictly older than `-mempoolexpiry` (POLICY, `NodeConfig.mempoolExpiry`,
default 1,209,600 seconds), with its descendants.
[SRC] src/txmempool.cpp:2201-2220 and src/config.cpp:87 at 6504a3af.

### `expiry_rules_differ` (`lean/BsvChain/Teranode/Lifetimes.lean:509`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (through `Reachable`).

THE WITNESS that removal iff the reference's expiry is not a theorem:
for every pool entry older than `-mempoolexpiry` the reference removes the
transaction, while every Teranode record that is unmined, never mined and not
conflicting (the record of `e`'s transaction among them, the scenario's `s3`
observes it) is kept at every height of every pruner cycle.

### `unmined_record_kept_witness` (`lean/BsvChain/Teranode/Lifetimes.lean:521`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A concrete run: created unmined and locked at height 101, unlocked by the
two-phase commit; kept at every height.

### `backdated_prunable` (`lean/BsvChain/Teranode/Lifetimes.lean:528`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Teranode's age of an unmined record selects only its parents for
preservation: a record moved off the longest chain at height `h` above the
retention is selected at `h` (the backdating of issue 1768).

### `reorged_spent_keeps_dah` (`lean/BsvChain/Teranode/Lifetimes.lean:544`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A record mined, fully spent and then moved off the longest chain is
unmined and still carries its deletion height: the store, on its own, deletes
it at the spend's height plus the retention. Its survival rests on phase 1
preserving it as the parent of an unmined child.

### `step_spendingHeight` (`lean/BsvChain/Teranode/Lifetimes.lean:555`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

No store transition moves a coinbase's spending height: it is written once,
at creation (`stores/utxo/aerospike/create.go:898` at 4edb60a4 [SRC]).

`[SRC]` `stores/utxo/aerospike/create.go:898`

### `reach_spendingHeight` (`lean/BsvChain/Teranode/Lifetimes.lean:568`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now` (through `Reach`); `params`, `cfg` and `oracle` are not arguments of the statement.

Every record a run reaches keeps the spending height its creation wrote.

### `coinbase_immature_iff` (`lean/BsvChain/Teranode/Lifetimes.lean:575`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `now` (through `Reach`); `params`, `cfg` and `oracle` are not arguments of the statement.

Teranode's coinbase gate, on every record reached from the coinbase's
creation at height `h`: immature at spend height `H` exactly when the depth
`H - h` is below the maturity.

### `reference_premature_iff` (`lean/BsvChain/Teranode/Lifetimes.lean:584`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`params` and `now` through `UtxoContext`); `oracle` is not an argument of the statement.

The reference's per-input stage refuses a coinbase input as premature
exactly when its depth is below `coinbaseMaturity` (consensus,
`COINBASE_MATURITY` = 100), for an available coin the operator lists do not
freeze. [SRC] src/validation.cpp:2591-2625 at 6504a3af.

### `coinbase_maturity_agrees` (`lean/BsvChain/Teranode/Lifetimes.lean:602`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg` and `now` (`now` through `Reach`; `params` and `now` through `UtxoContext`); `oracle` is not an argument of the statement.

THE THEOREM for maturity: on every record the store reaches from a
coinbase created at the coin's height, Teranode's coinbase gate refuses the
spend as immature exactly when the reference refuses it as `bad-txns-premature-spend-of-coinbase`,
given equal maturities and the same spend height (the validator's height is
the tip plus one on the pool path, `services/validator/Validator.go:898-900`;
the reference's `nSpendHeight` is the tip's successor there,
`src/validation.cpp:2545-2549` (`GetSpendHeightAndMTP`, the best block's
height plus one; called at `:2857`)).

`[SRC]` `services/validator/Validator.go:898-900`, `src/validation.cpp:2545-2549`, `src/validation.cpp:2857`

### `defaults_maturity_agree` (`lean/BsvChain/Teranode/Lifetimes.lean:623`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `cfg` fixed to the census defaults `NodeConfig.defaults`; `params`, `oracle` and `now` are not arguments of the statement. General form: `coinbase_maturity_agrees`, quantified; this theorem is its instance.

The two pins' defaults agree: Teranode's chain parameter (100 on every
go-chaincfg v1.6.2 network) and the reference's `COINBASE_MATURITY`, so
`coinbase_maturity_agrees`'s premise holds at the defaults. The general form is
`coinbase_maturity_agrees`, for every configuration with equal maturities; this
theorem is its instance at the census defaults.

### `locked_refuses` (`lean/BsvChain/Teranode/Lifetimes.lean:633`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A locked record refuses a spend of its outputs unless the caller ignores
the mark (and a conflicting record refuses before it).

### `setMined_unlocks` (`lean/BsvChain/Teranode/Lifetimes.lean:640`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Mining a record clears its lock.

### `lock_clears_dah` (`lean/BsvChain/Teranode/Lifetimes.lean:646`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Locking clears the deletion height, so a locked record is never pruned
while locked unless a later transition re-stamps it.

## `BsvChain.Teranode.Refinement`

### `abstractStatus_none_iff` (`lean/BsvChain/Teranode/Refinement.lean:229`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: the abstraction is undefined exactly on a refusal: every other observed state has its
status. A view, never a rule.

### `refines_abstract` (`lean/BsvChain/Teranode/Refinement.lean:244`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, support for row `observation-rpc`: under the relation, off a refusal and off `orphan`, the
abstraction gives the reference's status exactly (from #74's `teranode_read_inverse`). It takes the
observation's agreement as its hypothesis; the row's differences are #97's contract (§4). A view, never a rule.

### `refines_refused` (`lean/BsvChain/Teranode/Refinement.lean:252`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, support for row `observation-rpc`: under the relation a Teranode refusal is the reference's
rejection or its non-final hold, the divergence of row `non-final-hold`. A view, never a rule.

### `refines_mined` (`lean/BsvChain/Teranode/Refinement.lean:262`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: under the relation a transaction observed mined on the current chain at height `n` has
the reference's status `minedActive n` (from #74's `teranode_mined_implies_active`). A view, never a rule.

### `refines_empty` (`lean/BsvChain/Teranode/Refinement.lean:293`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, the base case: a Teranode state with no row, nothing in assembly and no refusal, in
RUNNING, refines the empty reference state (no block, an empty pool and journal), where every transaction is
`unknown` on one side and has no record on the other. The genesis row's form (one row, `current` its id,
against the reference's genesis) is owed, S1: the spec defines no genesis `StatusState`.

### `refines_best_work` (`lean/BsvChain/Teranode/Refinement.lean:308`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, row `chain-selection`: under the relation the reference's active tip is an eligible
index with the work of Teranode's best header (from #93's `active_work_agrees`, its correspondence assumed by
the relation). A state lemma: no step is in it. The tip itself can differ at equal work
(`Chain.tie_rules_differ`).

### `refines_best_validated` (`lean/BsvChain/Teranode/Refinement.lean:317`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: under the relation Teranode's best header is validated: no optimistically stored row
heads the chain (from #93's `Validated`).

### `refines_congr` (`lean/BsvChain/Teranode/Refinement.lean:325`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: a state whose status reads, chain reads and FSM state agree with another's refines what
the other refines.

### `refines_of_stutter` (`lean/BsvChain/Teranode/Refinement.lean:341`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: a Teranode transition that keeps the status reads, the chain reads and the FSM state
simulates the reference's identity: a stutter.

### `fsm_stutters` (`lean/BsvChain/Teranode/Refinement.lean:348`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, row `node-fsm`: an FSM event (#93's `fire`) that keeps RUNNING is a stutter: the FSM gates
the services and is no transaction's state (`docs/CONFORMANCE-TERANODE-MACHINE.md` section 2; #96 row
`rl.fsm`).

### `fsm_exit_suspends` (`lean/BsvChain/Teranode/Refinement.lean:359`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, row `node-fsm`: an FSM event out of RUNNING suspends observation: no reference state is
related to the state after it (#97 §6, the RUNNING precondition). The relation's return at the re-entry to
RUNNING is owed, S1.

### `alert_stutters` (`lean/BsvChain/Teranode/Refinement.lean:370`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, row `freeze-confiscation`: an alert's store write is a stutter of the status and the
chain; it relates to the reference's lists through `FrozenRefinesAt`. The model keeps `alert` apart from
`records` and `inputSpenders`, while at the pin the alert writes the same record's UTXO bins that the `utxos`
route reads (`FreezeUTXOs` "Sets the spending transaction ID to FF...FF",
`stores/utxo/aerospike/alert_system.go:71-77,88`; `stores/utxo/aerospike/teranode.lua:713` `freeze`, `:870`
`reassign`; the route serves `Status` and `SpendingData`, `services/asset/httpimpl/GetUTXOsByTXID.go:41-46`).
The status reads stay unmoved: a frozen output's spending data is `FF…FF`
(`stores/utxo/aerospike/teranode.lua:234-245` `isFrozen`), never a transaction mined on the current chain, so `observeAt`'s
`spentByMinedOther` clause does not fire. A reassignment (`teranode.lua:870-948`) changes the output's hash and
spend height, not a spender. [SRC] 4edb60a4.

`[SRC]` `stores/utxo/aerospike/alert_system.go:71-77,88`, `stores/utxo/aerospike/alert_system.go:870`, `services/asset/httpimpl/GetUTXOsByTXID.go:41-46`

### `ban_stutters` (`lean/BsvChain/Teranode/Refinement.lean:384`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: a ban or unban (#94's `teraBan`, `teraUnban`) is a stutter.

### `event_stutters` (`lean/BsvChain/Teranode/Refinement.lean:389`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, row `event-surface`: a Kafka publication is a stutter of the status: the topics carry no
state the reference's status reads (#96 rows `rl.kafka`, `tl.zmq-announce`, `tl.zmq-removal`).

### `observe_of_holds` (`lean/BsvChain/Teranode/Refinement.lean:400`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: the status reads depend on the records only through the blocks they hold.

### `setRecord_stutters` (`lean/BsvChain/Teranode/Refinement.lean:409`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: replacing a record by one with the same blocks keeps every status read.

### `setDAH_blocks` (`lean/BsvChain/Teranode/Refinement.lean:418`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: no lifetime transition of #92 but `setMined` moves a record's blocks.

### `step_blocks` (`lean/BsvChain/Teranode/Refinement.lean:425`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: every store transition of one record (#92's `Step`) keeps its blocks, or is the
block-mined transition `setMined`.

### `record_step_stutters` (`lean/BsvChain/Teranode/Refinement.lean:442`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, THE TRANSITION STATEMENT for the store's records: each lifetime transition of #92
(`setDAH`'s callers, the longest-chain mark, the conflicting and locked marks, a spend's all-spent test, a
preservation and its expiry) on a transaction's record is a stutter of the relation, the reference unmoved;
the one exception is `setMined`, the block's connection, which `connectSimulates` owes. The record's
conflicting mark is a stutter; the assembler's drop that accompanies it is `conflictDropSimulates`, owed.

### `prune_stutters` (`lean/BsvChain/Teranode/Refinement.lean:456`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, the record half of row `pruning`: the pruner's delete of a record (#92's `pruneDeletes`)
keeps every status read when the runner's journal holds the record's blocks (#74: the journal is kept for
exactly this, since the store forgets). By `prune_only_mined_or_conflicting` such a record is mined or
conflicting. The row's block-file half is owed.

### `alert_freeze_refines` (`lean/BsvChain/Teranode/Refinement.lean:516`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, row `freeze-confiscation`: an alert fund that freezes (#94's `freeze_agrees`' premises)
leaves the frozen projection agreeing at its output and at every height of its interval, the reference's
`addToConsensusBlacklist` applied beside it. Outside `Refines`: no step of the relation is in it.

### `alert_unfreeze_refines` (`lean/BsvChain/Teranode/Refinement.lean:533`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, row `freeze-confiscation`: an alert fund that unfreezes (#94's `unfreeze_agrees`'
premises) leaves the frozen projection agreeing at its output at and past its stop. Outside `Refines`.

### `flatLeaves_single` (`lean/BsvChain/Teranode/Refinement.lean:551`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, support for row `block-structure`: a block with no subtree is its coinbase alone.

### `flatLeaves_head` (`lean/BsvChain/Teranode/Refinement.lean:554`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, support for row `block-structure`: Teranode's body (the coinbase and the subtrees, #89's
`flatLeaves`) has the coinbase at its head, the leading subtree's placeholder replaced.
[SRC] `model/Block.go:2720-2751` at 4edb60a4.

`[SRC]` `model/Block.go:2720-2751`

### `flatLeaves_tail` (`lean/BsvChain/Teranode/Refinement.lean:561`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, support for row `block-structure`: after the coinbase, the transaction order is the
subtrees' concatenation (the leading subtree past its placeholder).

### `block_structure_refines` (`lean/BsvChain/Teranode/Refinement.lean:566`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, row `block-structure`: a reference block (`BsvChain.Block`, a header and a flat, ordered
list of transactions) whose transaction ids are Teranode's flat leaves of its coinbase and subtrees has that
coinbase's transaction at index 0. [SRC] `model/Block.go:95-100,2720-2751` at 4edb60a4;
`src/primitives/block.h:79` at 6504a3af.

`[SRC]` `model/Block.go:95-100,2720-2751`, `src/primitives/block.h:79`

### `block_order_refines` (`lean/BsvChain/Teranode/Refinement.lean:578`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, row `block-structure`: in such a block the transactions after the coinbase are the
subtrees' in their concatenated order (the leading subtree past its placeholder). [SRC] `model/Block.go:2720-2751`
at 4edb60a4; `src/primitives/block.h:79` at 6504a3af.

`[SRC]` `model/Block.go:2720-2751`, `src/primitives/block.h:79`

### `validation_depth_differs` (`lean/BsvChain/Teranode/Refinement.lean:598`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, row `validation-depth`, a witness: at `-assumevalid=0` (`assumeValid`, policy,
`docs/PARAMETERS.md` §8.2) the reference checks the scripts of every block it connects
(`scriptChecksRequired`, `src/validation.cpp:3482-3518` at 6504a3af), while Teranode's legacy path skips them
for a header-proven block at any height from 1 to its highest checkpoint, with no setting
(`teraScriptsSkipped`). Neither is an assumed-valid hash and a work floor on the other side. [D] until #66's
cut 2 drives it.

`[SRC]` `src/validation.cpp:3482-3518`

### `block_size_differs` (`lean/BsvChain/Teranode/Refinement.lean:619`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params` and `cfg`; `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, row `block-size`, a witness: a block over the reference's `excessiveBlockSize` (consensus,
node-configurable, `docs/PARAMETERS.md` §8.2) whose header passes is refused by `checkBlock` with
`bad-blk-length` and corruption not possible, so the reference marks the header failed
(`src/validation.cpp:5809-5815` at 6504a3af); Teranode declines the same size as policy and never marks the hash
(`teraSizeDeclined`). The merkle check is off here (`options.merkleRoot = false`) so the size clause is the
deciding one. [D] until #66's cut 2 drives it.

`[SRC]` `src/validation.cpp:5809-5815`

### `Divergence.mem_all` (`lean/BsvChain/Teranode/Refinement.lean:775`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-17: `Divergence.all` lists every constructor.

### `Divergence.ruleLabel_differs` (`lean/BsvChain/Teranode/Refinement.lean:797`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18: the premature-block row is the one divergence whose rule's label differs from its own.

### `Divergence.chainSplit_iff_consensus` (`lean/BsvChain/Teranode/Refinement.lean:869`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-17: a divergence is a chain split exactly when its label is consensus.

### `Divergence.chain_splits` (`lean/BsvChain/Teranode/Refinement.lean:874`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-17: the soft freeze's hold lapse is the one chain-split row the legs ruled.

### `Simulates.comp` (`lean/BsvChain/Teranode/Refinement.lean:887`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-17: simulations compose: a Teranode step that simulates a reference step, followed by one that
simulates another, simulates the two reference steps in order.

### `StutterStep.simulates` (`lean/BsvChain/Teranode/Refinement.lean:906`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-17: each such step is a stutter (`alert_stutters`, `ban_stutters`, `event_stutters`).

### `stutter_run_simulates` (`lean/BsvChain/Teranode/Refinement.lean:917`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-17: any run of alert writes, bans and Kafka publications keeps the relation with the reference
unmoved.

### `stutter_run_best_work` (`lean/BsvChain/Teranode/Refinement.lean:924`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-17, row `chain-selection` composed through the relation: after any run of stutter steps the
reference's active tip still has the work of Teranode's best header (#93's `active_work_agrees`, through
`refines_best_work`).

### `alert_freeze_keeps_relation` (`lean/BsvChain/Teranode/Refinement.lean:933`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-17, row `freeze-confiscation` composed through the relation: an alert fund that freezes keeps
`Refines` with the reference's status unmoved (`alert_stutters`) and leaves the frozen projection agreeing with
the reference's `addToConsensusBlacklist` at its output (`alert_freeze_refines`, from #94's `freeze_agrees`).

### `Family.mem_all` (`lean/BsvChain/Teranode/Refinement.lean:959`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-17: `Family.all` lists every constructor.

### `accounts_families` (`lean/BsvChain/Teranode/Refinement.lean:1011`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-17: every family has exactly one account, in the families' order.

### `departs_carry_divergence` (`lean/BsvChain/Teranode/Refinement.lean:1014`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-17: every family that leaves the relation carries a divergence.

### `obligations_rows` (`lean/BsvChain/Teranode/Refinement.lean:1135`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15: every row of #87's map has exactly one obligation, in the map's order: the list's rows
are `mapRows` (and `chaincheck --refinement` checks `mapRows` against `corpus/teranode/map.json`).

### `divergences_named` (`lean/BsvChain/Teranode/Refinement.lean:1194`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-17: every divergence is named by at least one obligation.

### `kind_counts` (`lean/BsvChain/Teranode/Refinement.lean:1199`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-18 (#98, #92; 2026-10-17 #88): the kinds' counts: 11 theorem, 1 witness, 18 design, 1 chain-split, 10 report, 13 open.

## `BsvChain.Teranode.Sentinel`

### `adapter_mempoolHeight` (`lean/BsvChain/Teranode/Sentinel.lean:52`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The adapter's `mempoolHeight uint32 = 0x7FFFFFFF` (`services/validator/ScriptVerifierGoBDK.go:23–38`)
is the reference's `MEMPOOL_HEIGHT` (`mempoolHeight`, `BsvScript.Flags`), and it is `math.MaxInt32`.

`[SRC]` `services/validator/ScriptVerifierGoBDK.go:23–38`

### `substituteUnconfirmedHeights_eq_map` (`lean/BsvChain/Teranode/Sentinel.lean:80`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

*What it says:* the substitution is slot by slot. The early return of
`services/validator/ScriptVerifierGoBDK.go:62–64` changes nothing, since on a list with no sentinel the map is
the identity; so each input's word below reads its own slot only.

`[SRC]` `services/validator/ScriptVerifierGoBDK.go:62–64`

### `sameEras_defaults` (`lean/BsvChain/Teranode/Sentinel.lean:183`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

*What it says:* Teranode's default configuration and the reference's mainnet default share the chain record
and both era heights, so `SameEras`'s hypothesis holds on mainnet: Teranode pushes go-chaincfg's mainnet Genesis
and Chronicle heights into GoBDK (`params.go:276–277` at go-chaincfg v1.6.2, pushed at
`services/validator/ScriptVerifierGoBDK.go:157–165`) and GoBDK's main table compiles the reference's other heights
in (`core/txvalidator.cpp:275–283`) `[SRC]`.

`[SRC]` `params.go:276–277`, `services/validator/ScriptVerifierGoBDK.go:157–165`, `core/txvalidator.cpp:275–283`

### `mempoolScriptFlags_standard` (`lean/BsvChain/Teranode/Sentinel.lean:193`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

*What it says:* with no promiscuous word in force, the mempool word is the era's standard word whatever
`requireStandard` reads: the standard word already carries FORKID, which is all `GetScriptVerifyFlags` adds
when standardness is not required (`verify_script_flags.cpp:18–26`). So GoBDK's reading of the node's setting
and the reference's reading of the chain's (`requireStandard`'s docstring) agree.

`[SRC]` `verify_script_flags.cpp:18–26`

### `bdkCalculateFlags_policy_eq` (`lean/BsvChain/Teranode/Sentinel.lean:203`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

*What it says:* GoBDK's policy-mode word under one configuration is the reference's mempool word under
another with the same eras (`BsvScript.Properties.bdkCalculateFlags_policy`, across two configurations).

### `bdkCalculateFlags_consensus_eq` (`lean/BsvChain/Teranode/Sentinel.lean:212`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

*What it says:* GoBDK's consensus-mode word under one configuration is the reference's block word under
another with the same eras (`BsvScript.Properties.bdkCalculateFlags_consensus`, across two configurations).

### `teranode_word_eq_mempool_word` (`lean/BsvChain/Teranode/Sentinel.lean:219`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

**#91, the mempool path.** *What it says:* for every parent, confirmed at any height a block can carry
or unconfirmed, and every tip below `int32Max`, the word Teranode's GoBDK verifies the input under on the
mempool path (policy mode, `blockHeight` the tip plus one, with or without the candidate-height option) is
the reference's mempool word: the sentinel becomes the tip plus one in the adapter and the reference's
`MEMPOOL_HEIGHT` coin becomes the tip plus one in `GetInputScriptBlockHeight`. The configurations may differ
in every policy limit; they share the eras (`SameEras`), and the reference's promiscuous word is not in force
(`hp`; `teranode_word_ne_promiscuous` is the pair where it is).

### `teranode_word_eq_block_word` (`lean/BsvChain/Teranode/Sentinel.lean:261`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

**#91, block connection.** *What it says:* at the block of height `blockHeight` (below `MEMPOOL_HEIGHT`),
on a validator call with the candidate-height option set, which CheckBlockSubtrees sets
(`services/subtreevalidation/check_block_subtrees.go:701–709`) and CheckSubtree's legacy branch sets "UNCONDITIONALLY"
(`services/subtreevalidation/Server.go:902–909`, `:864`); CheckSubtree's peer-facing branch does not (`:954–963`;
"MUST NOT be set on the peer-facing branch", `:892–893`), and there `teranode_unconfirmed_refused_without_option`
and `teranode_word_without_option` apply; the word Teranode's GoBDK
verifies an input under is the reference's block word, for a confirmed parent and for a same-block parent
alike: the sentinel becomes the candidate height, which is the height the reference's coins view gives a
same-block parent's coin.

`[SRC]` `services/subtreevalidation/check_block_subtrees.go:701–709`, `services/subtreevalidation/Server.go:902–909`, `services/subtreevalidation/Server.go:864`, `services/subtreevalidation/Server.go:954–963`, `services/subtreevalidation/Server.go:892–893`

### `teranode_unconfirmed_refused_without_option` (`lean/BsvChain/Teranode/Sentinel.lean:302`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

**#91, the pair where they differ (1).** *What it says:* on a consensus-mode call WITHOUT the
candidate-height option, an unconfirmed parent is refused before any word is computed: the adapter turns
the sentinel into `MEMPOOL_HEIGHT` (`services/validator/ScriptVerifierGoBDK.go:47–49`, `:67–68`) and GoBDK
refuses it (`UnconfirmedInputInBlock`, GoBDK `core/txvalidator.cpp:903–904`), at every block height. The
reference connects a same-block parent under its block word (`referenceBlockWord`, the coin at the block's
height); a parent in neither the chain nor the block is refused by the reference too, as a missing input.

`[SRC]` `services/validator/ScriptVerifierGoBDK.go:47–49`, `services/validator/ScriptVerifierGoBDK.go:67–68`, `core/txvalidator.cpp:903–904`

### `teranode_word_without_option` (`lean/BsvChain/Teranode/Sentinel.lean:315`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg`; `params`, `oracle` and `now` are not arguments of the statement.

**#91, the peer-facing branch.** *What it says:* on a consensus-mode call WITHOUT the candidate-height option,
the call CheckSubtree's peer-facing branch makes (`WithSkipPolicyChecks(true)`, `WithInBlock(true)`, no
`WithUnconfirmedParentsAtCandidateHeight`, `services/subtreevalidation/Server.go:954–963`; "MUST NOT be set on the
peer-facing branch", `:892–893`), the word Teranode's GoBDK verifies an input under is the reference's block word
for a confirmed parent and a refusal for an unconfirmed one (`teranode_unconfirmed_refused_without_option`): the
option changes the word of a same-block parent only.

`[SRC]` `services/subtreevalidation/Server.go:954–963`, `services/subtreevalidation/Server.go:892–893`

### `teranode_block_word_ne_without_option` (`lean/BsvChain/Teranode/Sentinel.lean:348`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The pair (1) as a value: the reference's block word for a same-block parent at mainnet's Chronicle
height, and Teranode's refusal there without the option.

### `teranode_word_ne_promiscuous` (`lean/BsvChain/Teranode/Sentinel.lean:355`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**#91, the pair where they differ (2): policy.** *What it says:* a reference node on a chain that does
not require standardness (stn, testnet, regtest: `requireStandard`'s docstring) with `-promiscuousmempoolflags`
set verifies mempool inputs under that word (`verify_script_flags.cpp:19–25`); GoBDK has no such setting
("intentionally absent", GoBDK `core/txvalidator.hpp:43–45`) and Teranode passes none, so Teranode's word is
the standard word. Shown with the empty promiscuous word on the mainnet heights, the activation heights being
an input of both words. A node's setting, never block validity: the block word is untouched.

`[SRC]` `verify_script_flags.cpp:19–25`, `core/txvalidator.hpp:43–45`

## `BsvChain.Teranode.Spend`

### `spender_none_of_free` (`lean/BsvChain/Teranode/Spend.lean:211`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A free output has no spender.

### `spender_some_of_not_free` (`lean/BsvChain/Teranode/Spend.lean:220`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

A taken output's spender is the owner of its earliest index entry.

### `spendAll_eq` (`lean/BsvChain/Teranode/Spend.lean:231`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Without conflicting marks, with distinct inputs and with no spend already
owned by `id` on any of them, the per-output spends append exactly the free
inputs, in order, and report whether every input was free.

### `spendAll_owned` (`lean/BsvChain/Teranode/Spend.lean:275`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

When every input is already spent by `id` itself, the spend is an
idempotent success that changes nothing (`teranode.lua:386-401`).

### `unspendAll_eq` (`lean/BsvChain/Teranode/Spend.lean:287`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Unspending a list filters every owned entry on it.

### `related_empty` (`lean/BsvChain/Teranode/Spend.lean:323`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The empty store and the empty pool are related.

### `find_of_mem_nodup` (`lean/BsvChain/Teranode/Spend.lean:327`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

`find?` on a list with distinct keys finds an entry by its key.

### `owner_accepted` (`lean/BsvChain/Teranode/Spend.lean:343`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

An index entry's owner is an accepted id.

### `submit_invalid` (`lean/BsvChain/Teranode/Spend.lean:352`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The store's submission when the oracle refuses.

### `submit_fail` (`lean/BsvChain/Teranode/Spend.lean:357`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The store's submission when a spend fails: the state after the rollback.

### `submit_known` (`lean/BsvChain/Teranode/Spend.lean:362`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The store's submission of a transaction already recorded: idempotent.

### `submit_new` (`lean/BsvChain/Teranode/Spend.lean:368`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The store's submission of a new transaction whose spends all succeed.

### `spendTx_all` (`lean/BsvChain/Teranode/Spend.lean:375`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

`spendTx` when every per-output spend succeeds.

### `spendTx_fail` (`lean/BsvChain/Teranode/Spend.lean:380`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

`spendTx` when a per-output spend fails: the successful ones are unspent.

### `refSubmit_known` (`lean/BsvChain/Teranode/Spend.lean:386`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The reference refuses an id already accepted (stage 4).

### `refSubmit_invalid` (`lean/BsvChain/Teranode/Spend.lean:391`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The reference refuses what the oracle refuses.

### `refSubmit_conflict` (`lean/BsvChain/Teranode/Spend.lean:397`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The reference refuses a conflict (stage 5).

### `refSubmit_new` (`lean/BsvChain/Teranode/Spend.lean:403`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The reference admits a valid new transaction without a conflict.

### `submit_related` (`lean/BsvChain/Teranode/Spend.lean:413`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

One submission keeps the relation and the two machines agree on it.

### `run_related` (`lean/BsvChain/Teranode/Spend.lean:535`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The runs keep the relation from any related pair. `hid` says the
transaction id determines the body across the run and the pool: the txid is
the body's double SHA-256 (`src/primitives/transaction.cpp:79-81` at 6504a3af
[SRC]), so this is the no-collision reading of the hash.

`[SRC]` `src/primitives/transaction.cpp:79-81`

### `kept_of_related` (`lean/BsvChain/Teranode/Spend.lean:567`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

In a related state the store's mempool is its records.

### `accepted_eq_mempool` (`lean/BsvChain/Teranode/Spend.lean:577`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**The earlier spend wins on both nodes (#90), sequential arrival, no reorg.**
For every arrival order `txs` of a finite list, starting from an empty store and
an empty pool, the transactions Teranode's store keeps (its unmined,
non-conflicting records) are exactly the transactions the reference's
earliest-seen rule accepts, in the same order.

Hypotheses, exactly: one oracle `valid` decides every check other than the
spent-output check, the same on both nodes and independent of arrival order
(the same parameters, the same tip, no reorg; a child arriving before its
parent is outside, since its verdict depends on order); a transaction the
oracle passes has distinct inputs (`bad-txns-inputs-duplicate`,
`src/validation.cpp:632-635` at 6504a3af [SRC]); the id
determines the body (`hid`). Sequential arrival means each submission's store
calls finish before the next begins: the per-output spend is atomic per
record, the whole transaction is not (one ordered group of per-record UDF
calls, `spend.go:407-411,461`), and `concurrent_both_refused` is the
interleaving where the equality fails, under the condition
`concurrent_outcome_iff` states.
[SRC] Teranode `stores/utxo/aerospike/teranode.lua:284-466`,
`stores/utxo/aerospike/spend.go:387-548`, `services/validator/Validator.go:1105-1257`
at 4edb60a4; bitcoin-sv `src/validation.cpp:1142-1152`,
`src/txmempool.cpp:298-304` at 6504a3af.

`[SRC]` `src/validation.cpp:632-635`, `spend.go:407-411,461`, `stores/utxo/aerospike/spend.go:387-548`, `services/validator/Validator.go:1105-1257`, `src/validation.cpp:1142-1152`, `src/txmempool.cpp:298-304`

### `toOut_inj` (`lean/BsvChain/Teranode/Spend.lean:610`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The projection keeps outpoints apart.

### `conflict_bridge` (`lean/BsvChain/Teranode/Spend.lean:622`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

The reference model's conflict test IS BsvChain's stage-5 predicate
`hasPoolConflict` on a final request when the held pool is empty (the held
locks are the reference's `CTimeLockedMempool`, which Teranode has no
counterpart of). [SRC] `src/txmempool.cpp:2257-2280` and
`src/validation.cpp:1147-1152` at 6504a3af.

`[SRC]` `src/txmempool.cpp:2257-2280`, `src/validation.cpp:1147-1152`

### `accept_conflict_refuses` (`lean/BsvChain/Teranode/Spend.lean:638`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

BsvChain's complete `accept` refuses a request the reference model calls a
conflict, with the source's code and reason, and keeps the accepted pool,
once the P2P filter lets the request through and the ordered earlier stages
pass (they may otherwise refuse it for another reason).
[SRC] `src/validation.cpp:1031-1152` at 6504a3af.

`[SRC]` `src/validation.cpp:1031-1152`

### `acceptRun_append` (`lean/BsvChain/Teranode/Spend.lean:685`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

`acceptRun` over a concatenation: the trailing part runs from the pool the
leading part leaves.

### `refRun_append` (`lean/BsvChain/Teranode/Spend.lean:696`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

`refRun` over a concatenation, the same way.

### `acceptRun_toPool` (`lean/BsvChain/Teranode/Spend.lean:733`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

Under the obligation for `txs`, BsvChain's run projects onto the reference
model's run, submission by submission: by induction on the suffix still to
run, from any prefix `pre` on which the projection already holds.

### `accepted_eq_accept_of_earliestSeen` (`lean/BsvChain/Teranode/Spend.lean:756`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `params`, `cfg`, `oracle` and `now` (`params` and `now` through `AdmissionContext`).

**#90 against BsvChain's complete `accept`, under the remaining
obligation.** If `AcceptIsEarliestSeen` holds for the arrival order `txs`, the
store's mempool after `txs` equals the txids BsvChain's `accept` keeps after
`txs`, from empty pools. [SRC] as `accepted_eq_mempool`.

### `concurrent_outcome_iff` (`lean/BsvChain/Teranode/Spend.lean:878`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**The condition, over every schedule (#90).** Of the 80 schedules of `A`
and `B`, the store keeps neither exactly when `bothHeld` holds, and it never
keeps both. A losing claim that lands after the holder's rollback succeeds,
so the later transaction is kept then, not neither.

What meets `bothHeld` on each backend at 4edb60a4 [SRC]:
* Aerospike (the model): within one batch the duplicate filter decides by
  batch order, and a transaction's inputs are one ordered group
  (`spend.go:407-411,461,692`), so the earlier group wins both outputs. The
  condition needs, for at least one output, the two claims in two batches in
  flight together: the two groups in two batches, or one group split at the
  size cap across two (`batcher.go:743-790` at go-batcher v2.0.6), each batch
  handed to the worker pool (`aerospike.go:514-516`), with the later batch's
  claim reaching the record before the other; and each losing claim landing before the
  holder's rollback (`spend.go:513-527`).
* SQL, so SQLite under `SETTINGS_CONTEXT=test`: each input is enqueued from
  its own goroutine (`sql.go:2104-2128`) into a batcher whose batches run one
  at a time (`sql.go:223`, background false), and the duplicate filter runs in
  each batch (`sql.go:2275`). A claim's arrival order is its order in that
  one stream, in one batch or across two, and the rollback follows the
  transaction's last reply (`sql.go:2198-2207`). The condition is the stream
  order of the four claims and the two rollbacks.
[M] model statement read from source, unobserved.

`[SRC]` `spend.go:407-411,461,692`, `batcher.go:743-790`, `aerospike.go:514-516`, `spend.go:513-527`, `sql.go:2104-2128`, `sql.go:223`, `sql.go:2275`, `sql.go:2198-2207`

### `concurrent_both_refused` (`lean/BsvChain/Teranode/Spend.lean:906`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**The concurrent witness (#90).** Under its condition `bothHeld`, stated
as a hypothesis over every schedule of `A` and `B`, the store keeps NEITHER
conflicting transaction and both outputs are unspent; `bothLose` is one such
schedule. The reference keeps exactly one under either serial order: its
detector inserts all of a transaction's inputs under one mutex, so of two
valid concurrent double spends the earlier continues and the other is refused
(`src/txn_double_spend_detector.cpp:11-57`, `src/validation.cpp:1484-1494` at
6504a3af [SRC]; `BsvChain.stageDetector`). Two transactions over two outputs
in two records is the smallest case: with one shared output the per-output
atomic spend decides, as `one_output_earlier_wins` checks. What meets the
condition on Teranode's two backends is in `concurrent_outcome_iff`'s
docstring: on Aerospike two batches in flight together, never one batch. [M]
model witness read from source, unobserved; the regtest scenario
`corpus/scenarios/2026-10-14-conflicting-spends-order.md` is its run, pending #66.

`[SRC]` `src/txn_double_spend_detector.cpp:11-57`, `src/validation.cpp:1484-1494`

### `serial_schedules_agree` (`lean/BsvChain/Teranode/Spend.lean:928`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

Serial schedules of the same two transactions agree with the reference.

### `one_output_earlier_wins` (`lean/BsvChain/Teranode/Spend.lean:939`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

With one shared output and one input each, every schedule of the two
transactions (a spend before its own finish) keeps exactly one of them, the
spend that reached the record before the other.

### `reorg_keeps_differ` (`lean/BsvChain/Teranode/Spend.lean:1035`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

**The reorg witness (#90).** After a block that double-spends a mempool
transaction is connected and then disconnected, Teranode's store keeps the
earlier mempool spender `A` (its mark cleared, `F:0` spent by it again) and
marks the block's `B` conflicting, while the reference re-admits `B` and has
dropped `A` at the connection. The marks are reversed, but not where the
reference re-admits. Teranode at the tag also leaves the restored `A` out of
block assembly until it is resubmitted (`SubtreeProcessor.go:4226-4251`, its
own comment) [SRC]; that holds for a reorg through `reorgBlocks` only: after
an invalidation `handleReorg` resets and reloads unmined transactions
(`BlockAssembler.go:2258-2291`); a large reorg resets without the reverse
(`:2225-2239`) [SRC] 4edb60a4. [M] model witness read from source,
unobserved.

`[SRC]` `SubtreeProcessor.go:4226-4251`, `BlockAssembler.go:2258-2291`, `BlockAssembler.go:2225-2239`

## `BsvChain.Teranode.Subtree`

### `merkleReduce_fuel` (`lean/BsvChain/Teranode/Subtree.lean:324`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] The reference's reduction does not depend on surplus fuel.
[SRC] src/consensus/merkle.cpp:247-282 at 6504a3af.

### `computeMerkleRoot_step` (`lean/BsvChain/Teranode/Subtree.lean:345`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] One level of the reference: for two or more leaves the root and the
flag are those of the next level, the level's own flag OR'd in.
[SRC] src/consensus/merkle.cpp:210-244 at 6504a3af.

### `computeMerkleRoot_single` (`lean/BsvChain/Teranode/Subtree.lean:360`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] A single leaf is its own root, unmutated.
[SRC] src/consensus/merkle.cpp:249-255 at 6504a3af.

### `merkleLevel_cons₂` (`lean/BsvChain/Teranode/Subtree.lean:364`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] The reference's level on two leaves and a rest.
[SRC] src/consensus/merkle.cpp:210-236 at 6504a3af.

### `merkleLevel_append` (`lean/BsvChain/Teranode/Subtree.lean:370`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] A level splits at an even boundary: the pairs never straddle it.
[SRC] src/consensus/merkle.cpp:263-271 at 6504a3af.

### `merkleLevel_flatten` (`lean/BsvChain/Teranode/Subtree.lean:383`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] A level of a list of even-length chunks then a tail is the chunks'
levels then the tail's.
[SRC] src/consensus/merkle.cpp:263-271 at 6504a3af.

### `bitLen_two_pow_sub_one` (`lean/BsvChain/Teranode/Subtree.lean:399`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] The bit length on a power of two minus one.
[SRC] Go `bits.Len` at subtree.go:526 (go-subtree v1.5.1); src/consensus/merkle.cpp:239-244,273-280 at 6504a3af.

### `treeHeight_two_pow` (`lean/BsvChain/Teranode/Subtree.lean:412`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] A power of two's height is its exponent.
[SRC] subtree.go:526,925 (go-subtree v1.5.1); src/consensus/merkle.cpp:239-244,273-280 at 6504a3af.

### `treeHeight_half` (`lean/BsvChain/Teranode/Subtree.lean:416`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] Halving (rounded up) a count of two or more lowers its height by one.
[SRC] merkle_tree.go:66 (go-subtree v1.5.1); src/consensus/merkle.cpp:239-244,273-280 at 6504a3af.

### `bitLen_spec` (`lean/BsvChain/Teranode/Subtree.lean:426`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] The bit length bounds its argument: `x < 2 ^ bitLen x ≤ 2 x` for positive `x`.
[SRC] Go `bits.Len` at subtree.go:526 (go-subtree v1.5.1); src/consensus/merkle.cpp:239-244,273-280 at 6504a3af.

### `bitLen_le` (`lean/BsvChain/Teranode/Subtree.lean:446`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] A number below `2 ^ k` has at most `k` bits.
[SRC] Go `bits.Len` at subtree.go:526 (go-subtree v1.5.1); src/consensus/merkle.cpp:239-244,273-280 at 6504a3af.

### `treeHeight_one` (`lean/BsvChain/Teranode/Subtree.lean:461`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] One leaf has height zero.
[SRC] subtree.go:526 (go-subtree v1.5.1); src/consensus/merkle.cpp:249-255 at 6504a3af.

### `liftRoot_succ` (`lean/BsvChain/Teranode/Subtree.lean:465`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] A lifted root by one more level.
[SRC] subtree.go:532-538 (go-subtree v1.5.1); src/consensus/merkle.cpp:215-222,270-271 at 6504a3af.

### `any_or` (`lean/BsvChain/Teranode/Subtree.lean:470`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] The flag over chunks distributes.
[SRC] src/consensus/merkle.cpp:210-213 at 6504a3af.

### `any_congr'` (`lean/BsvChain/Teranode/Subtree.lean:480`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] `any` respects pointwise equality on the list.
[SRC] src/consensus/merkle.cpp:210-213 at 6504a3af.

### `compose_eq_flat` (`lean/BsvChain/Teranode/Subtree.lean:489`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] THE STRUCTURAL THEOREM. Chunks of `2 ^ h` leaves (at least one) then a
last chunk of one to `2 ^ h` leaves: the reference's root over the flat list
equals the reference's root over the chunk roots, the last root lifted by
self-hashing to height `h`; and the flat flag is the OR of every chunk's flag,
the last chunk's flag and the top tree's flag. No premise on the hash.
[SRC] model/Block.go:2793-2879 and subtree_body_shape.go:37-103 at 4edb60a4;
subtree.go:516-541 (go-subtree v1.5.1); src/consensus/merkle.cpp:21-24,210-282,312-319
at 6504a3af.

### `pairLevel_zeros` (`lean/BsvChain/Teranode/Subtree.lean:590`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] The zero word pairs to the zero word.
[SRC] merkle_tree.go:139-140 (go-subtree v1.5.1); src/consensus/merkle.cpp:247-255 at 6504a3af.

### `pairLevel_pad` (`lean/BsvChain/Teranode/Subtree.lean:601`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] On nonzero words then zero padding, the builder's level is the
reference's level then zero padding.
[SRC] merkle_tree.go:97-161 (go-subtree v1.5.1); src/consensus/merkle.cpp:210-236 at 6504a3af.

### `iterLevels_pad` (`lean/BsvChain/Teranode/Subtree.lean:623`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] Exactly `k` builder levels on a list of `2 ^ (k-1) + 1` to `2 ^ k`
nonzero-paired words, padded with zeros, leave the reference's root on top.
[SRC] merkle_tree.go:45-94 (go-subtree v1.5.1); src/consensus/merkle.cpp:247-282 at 6504a3af.

### `storeRoot_eq_computeMerkleRoot` (`lean/BsvChain/Teranode/Subtree.lean:654`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] go-subtree's builder equals the reference's root on every nonempty
list whose paired words are nonzero.
[SRC] merkle_tree.go:45-161 and subtree.go:476-498 (go-subtree v1.5.1);
src/consensus/merkle.cpp:247-282 at 6504a3af.

### `merkleLevel_hashes` (`lean/BsvChain/Teranode/Subtree.lean:667`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] Every word of a reference level is a SHA256d output.
[SRC] src/consensus/merkle.cpp:210-236 at 6504a3af.

### `pairedNonzero_of_zeroFree` (`lean/BsvChain/Teranode/Subtree.lean:680`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] Under `ZeroFree`, nonzero leaves make every paired word nonzero.
[SRC] merkle_tree.go:136-150 (go-subtree v1.5.1); src/consensus/merkle.cpp:210-236 at 6504a3af.

### `refRoot_prop` (`lean/BsvChain/Teranode/Subtree.lean:696`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] A property of every leaf and of every SHA256d output holds of the
reference's root of a nonempty list.
[SRC] src/consensus/merkle.cpp:210-282 at 6504a3af.

### `liftRoot_prop` (`lean/BsvChain/Teranode/Subtree.lean:712`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] A lift keeps a property every SHA256d output has.
[SRC] subtree.go:532-538 (go-subtree v1.5.1); src/consensus/merkle.cpp:215-222,270-271 at 6504a3af.

### `shapeOk_split` (`lean/BsvChain/Teranode/Subtree.lean:722`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] The shape rule splits the subtrees after the leading one into full ones and
a last one no longer.
[SRC] model/subtree_body_shape.go:45-57 at 4edb60a4; src/consensus/merkle.cpp:312-319 at 6504a3af.

### `rootHashPadded_of_ne` (`lean/BsvChain/Teranode/Subtree.lean:743`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] A nonempty subtree's padded root is the lift of the root it is given.
[SRC] subtree.go:516-541 (go-subtree v1.5.1); src/consensus/merkle.cpp:215-222,239-244 at 6504a3af.

### `claim_eq_refRoot` (`lean/BsvChain/Teranode/Subtree.lean:752`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] An anchored claim of a nonempty subtree with nonzero paired words is the
reference's root of its nodes.
[SRC] subtree.go:481-498 (go-subtree v1.5.1); model/subtree_meta_reader.go:57-111 at
4edb60a4; src/consensus/merkle.cpp:247-282 at 6504a3af.

### `recomputed_anchored` (`lean/BsvChain/Teranode/Subtree.lean:761`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] The in-memory reading is anchored: `recomputed` is the recomputation.
[SRC] subtree.go:485-497 (go-subtree v1.5.1); src/consensus/merkle.cpp:247-282 at 6504a3af.

### `restRoots_eq` (`lean/BsvChain/Teranode/Subtree.lean:766`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] The roots after the leading one: each full subtree's reference root, the last
one's lifted to height `k`, when the claims are anchored and the paired words nonzero.
[SRC] model/Block.go:2744,2867-2876 at 4edb60a4; subtree.go:476-541 (go-subtree v1.5.1);
src/consensus/merkle.cpp:247-282 at 6504a3af.

### `bodyNonzero_of_zeroFree` (`lean/BsvChain/Teranode/Subtree.lean:824`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] `ZeroFree` is a sufficient condition for `BodyNonzero`: with no SHA256d
output the zero word, nonzero leaves in nonempty subtrees make every paired word
of the body nonzero.
[SRC] merkle_tree.go:138-140 (go-subtree v1.5.1); src/consensus/merkle.cpp:210-282 at 6504a3af.

### `subtreeRoot_eq_blockMerkleRoot` (`lean/BsvChain/Teranode/Subtree.lean:866`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] THE THEOREM OF #89. Every root Teranode's check accepts for a body
(no subtree, one subtree of any length, or subtrees of a power-of-two size with
the last one partial, the size chosen by the dynamic-size flag or not) is the
reference's `BlockMerkleRoot` root of the same transaction ids in order, the
coinbase txid at index 0. Premises: `BodyNonzero` (no word the builder pairs in
this body is the zero word; `zero_leaf_counterexample` shows the model needs
it) and `RootsAnchored` (every stored subtree's header root is its nodes' root,
Teranode's own premise of the composition, quick_validate.go:1292-1299).
[SRC] model/Block.go:2709-2771,2793-2879 and model/subtree_body_shape.go:37-103 at
4edb60a4; merkle_tree.go:45-161 and subtree.go:290-306,476-562 (go-subtree v1.5.1);
src/consensus/merkle.cpp:21-24,247-282,312-319 at 6504a3af.

### `assembly_root_eq_blockMerkleRoot` (`lean/BsvChain/Teranode/Subtree.lean:944`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] Every count and every power-of-two size: the root block assembly's
partition produces, whenever Teranode's check accepts it, is the flat root;
the dynamic-size flag only picks the size. The premises are the body's, as in
`subtreeRoot_eq_blockMerkleRoot`.
[SRC] services/blockassembly/subtreeprocessor/SubtreeProcessor.go:601-611,2297-2460
and settings/settings.go:303,313 at 4edb60a4; src/consensus/merkle.cpp:312-319 at 6504a3af.

### `zero_leaf_roots` (`lean/BsvChain/Teranode/Subtree.lean:988`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] At two zero words the builder returns the zero word (a zero left child
makes a zero parent) and the reference hashes them.
[SRC] merkle_tree.go:139-140 (go-subtree v1.5.1); src/consensus/merkle.cpp:227-237 at 6504a3af.

### `sha256d_zero64_ne_zero` (`lean/BsvChain/Teranode/Subtree.lean:998`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] The kernel's evaluation of one double SHA-256: the hash of sixty-four
zero bytes is not the zero word (`decide +kernel`, no native code).
[SRC] src/consensus/merkle.cpp:43-50 at 6504a3af; merkle_tree.go:136-161 (go-subtree v1.5.1).

### `zero_leaf_counterexample` (`lean/BsvChain/Teranode/Subtree.lean:1003`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] THE COUNTEREXAMPLE OF THE MODEL WITHOUT ITS PREMISE, at the smallest
count (two; one leaf is its own root on both sides): two zero transaction ids.
The builder reads a zero left child as "no node" and returns the zero word;
the reference hashes the pair. Infeasible: a zero txid needs a SHA256d
preimage of the zero word. `subtreeRoot_eq_blockMerkleRoot` assumes it away
through `BodyNonzero`.
[SRC] merkle_tree.go:136-161 (go-subtree v1.5.1); src/consensus/merkle.cpp:227-237 at 6504a3af.

### `duplicate_root_divergence` (`lean/BsvChain/Teranode/Subtree.lean:1021`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] THE MUTATION FLAG ACROSS THE TWO CONSTRUCTIONS, a decided witness:
subtrees of one leaf each, `[coinbase] [B] [C] [B]`. Teranode's composition
refuses the repeated root `B` (a corrupt body); the reference's flat flag is
false, because `B` and `B` are not siblings at any level, and its root exists.
Both refusals are on the same body only when the repeat is between siblings.
Whether the reference accepts the block is decided by rules outside the merkle
root (the repeated transaction), not read here.
[SRC] model/subtree_body_shape.go:75-103 at 4edb60a4; src/consensus/merkle.cpp:210-213,247-282 at 6504a3af.

### `mutated_flag_without_refusal` (`lean/BsvChain/Teranode/Subtree.lean:1034`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] THE CONVERSE, a decided witness: one subtree `[placeholder, A, B, B]`.
Teranode's root check accepts it with the flat root, while the reference's flat
flag is true (the last pair repeats). Teranode's refusal of that body is left to
its repeated-transaction check, model/Block.go:912-940 at 4edb60a4, outside this
model. [SRC] model/Block.go:2794-2796 at 4edb60a4; src/consensus/merkle.cpp:210-213,247-282
at 6504a3af.

## `BsvChain.Views.Events`

### `factory_is_pub_command` (`lean/BsvChain/Views/Events.lean:73`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: each factory key is `pub` and the command it publishes.
The source pairs them by hand in two files; this theorem is about a view,
never a rule.

### `help_option_registers_nothing` (`lean/BsvChain/Views/Events.lean:86`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: no topic answers the help text's option. A view, never a rule.

### `block_topic_iff` (`lean/BsvChain/Views/Events.lean:126`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the block-removal topic carries exactly BLOCK and REORG.
A view, never a rule.

### `unknown_reason_collapses` (`lean/BsvChain/Views/Events.lean:132`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: four reasons share one discard word, so the word has no
inverse onto the reason: a frozen input, a lost whitelisting, a replacement
and an unknown removal all read `unknown-reason`. The node disagrees with
its documentation (rule 15): doc/zmq.md:98-99 lists three discard reasons;
the default arm (src/zmq/zmqpublishnotifier.cpp:218-219) publishes
unknown-reason for FROZEN_INPUT and NOT_WHITELISTED
(src/txmempool.cpp:1291,1338 at 6504a3af). REPLACED and UNKNOWN have no
removal site at the pin. A view, never a rule.

### `discard_words_distinct` (`lean/BsvChain/Views/Events.lean:145`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the three named discard reasons have three words.
A view, never a rule.

### `removal_carries_reason` (`lean/BsvChain/Views/Events.lean:299`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: an evicted transaction's removal message carries the
reason its transition names, on that reason's topic, and the conflict record
only when the site passes one. A view, never a rule.

### `expire_events_say_expired` (`lean/BsvChain/Views/Events.lean:310`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): for every `cfg` and `now`; `params` and `oracle` are not arguments of the statement.

[D] 2026-10-15: the expiry step's messages read `expired` on the discard
topic and carry no conflict record. A view, never a rule.

### `conflict_names_spender` (`lean/BsvChain/Views/Events.lean:319`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a conflict removal's message names the block's spender
and the block, with the word `collision-in-block-tx`. A view, never a rule.

### `mined_says_included` (`lean/BsvChain/Views/Events.lean:328`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a mined entry's message reads `included-in-block` on the
block-removal topic. A view, never a rule.

### `expired_without_transition` (`lean/BsvChain/Views/Events.lean:336`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: `expired` has no inverse onto the machine's transitions:
a miner-info dataref removal, which no machine transition performs, passes
the same reason as Mempool.expire. A view, never a rule.

### `silent_publishes_nothing` (`lean/BsvChain/Views/Events.lean:479`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a silent transition publishes nothing. A view, never a rule.

### `already_known_silent` (`lean/BsvChain/Views/Events.lean:482`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: REJECT_ALREADY_KNOWN publishes no invalid record.
A view, never a rule.

### `rejection_publishes_reason` (`lean/BsvChain/Views/Events.lean:488`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: every other completed refusal publishes one invalid record
carrying the verdict's code and reason, byte for byte. A view, never a rule.

### `invalid_record_matches_journal` (`lean/BsvChain/Views/Events.lean:496`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the record's reason is the one the machine's rejection
journal keeps for the same body (Mempool.recordTxOutcome, #67's status view
reads it). A view, never a rule.

### `orphan_publishes_missing` (`lean/BsvChain/Views/Events.lean:508`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a missing input publishes the invalid record with
isMissingInputs, code 0 and an empty reason. A view, never a rule.

### `held_reads_as_accepted` (`lean/BsvChain/Views/Events.lean:513`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: an accepted and a held transaction publish the same four
messages, so the transaction topics cannot tell the pool from the non-final
pool. A view, never a rule.

### `disconnect_reads_as_added` (`lean/BsvChain/Views/Events.lean:520`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a disconnection's messages are those of re-adding its body;
nothing on the transaction topics tells a disconnect from an acceptance of
the same transactions. A view, never a rule.

### `fork_tip_silent` (`lean/BsvChain/Views/Events.lean:526`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: an activation that ends at its fork point publishes no
block hash. A view, never a rule.

### `ibd_connect_publishes_body` (`lean/BsvChain/Views/Events.lean:532`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: in initial download a connection publishes only its
transactions on hashtx and rawtx. A view, never a rule.

### `pooled_tx_no_hashtx2` (`lean/BsvChain/Views/Events.lean:538`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a transaction the pool held before the connection gets
no hashtx2 from it, whatever the block. A view, never a rule.

### `disconnect_cause_invisible` (`lean/BsvChain/Views/Events.lean:578`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the messages never name a disconnection's cause: a reorg,
an operator's invalidation and a soft rejection publish alike. No function
from the event stream recovers the DisconnectCause. A view, never a rule.

### `later_file_no_hex` (`lean/BsvChain/Views/Events.lean:618`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a later file of the same txid never carries the hex.
A view, never a rule.

## `BsvChain.Views.Status`

### `node_rejection_reason` (`lean/BsvChain/Views/Status.lean:112`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: exact reason bytes survive the rejection projection.
This theorem is about a view, never a validation rule.

### `rpc_namespace_preserved` (`lean/BsvChain/Views/Status.lean:117`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: signed RPC errors are not silently put in the wire-code
namespace. This theorem is about a view, never a validation rule.

### `partial_mined_implies_stale` (`lean/BsvChain/Views/Status.lean:194`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: hypothesis h : arcadeStaleMining s = some MINED
entails the stale constructor, whose actual derived status retains off-active
body inclusion. No stored report is inferred. Views, never rules.

### `partial_rejected_implies_receipt` (`lean/BsvChain/Views/Status.lean:201`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: hypothesis h : arcadeRejected s = some REJECTED
entails the exact completed node receipt in this narrow domain. No producer
receipt delivery is inferred. Views, never rules.

### `empty_inputs_rejected` (`lean/BsvChain/Views/Status.lean:209`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: hypothesis hInputs : tx.inputs = [] supplies the machine's
vinEmpty rejection at every size/sigop parameter choice, and its completed receipt
projects to Arcade REJECTED. Stored history is separate. Views, never rules.
[SRC] models/transaction.go:104-105 at 1ae1208e; src/validation.cpp:526-527 at 6504a3af.

### `empty_inputs_invalid` (`lean/BsvChain/Views/Status.lean:233`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: hypothesis hInputs : tx.inputs = [] establishes the existing
machine's structural vinEmpty rejection at every size/sigop parameter choice.
The exact completed node receipt projects to invalid; an arbitrary cached report
is not used to prove hInputs. Views, never rules.
[SRC] src/validation.cpp:526-527 at 6504a3af; sdk/types.ts:48 at edf6e03d.

### `partial_mined_implies_active` (`lean/BsvChain/Views/Status.lean:253`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: active constructor suffices for the mining word.
Hypothesis h : arcadeMining s = some MINED concludes s = minedActive height
for some height. Stored reports are outside this view, never a rule.

### `doubleSpend_implies_mined_conflict` (`lean/BsvChain/Views/Status.lean:260`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: hypothesis h : requestConflict (status s id) = some doubleSpend
entails the machine's exact different active spender predicate minedConflict s id.
That predicate tests a shared outpoint, not gettxout absence alone. Views, never rules.
[SRC] sdk/types.ts:46 at edf6e03d; src/txmempool.cpp:1093-1116 at 6504a3af.

### `mined_implies_branch` (`lean/BsvChain/Views/Status.lean:293`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: hypothesis h : synchronizedMining s = MINED
concludes (exists height, s = minedActive height) or s = onStaleBranch.
Body inclusion is inherited from an actual machine-derived constructor.
Actual remote hints require synchronized evidence;
a cached MINED word has no such theorem. This view is never a rule.

### `immutable_needs_client_depth` (`lean/BsvChain/Views/Status.lean:311`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: the same machine status and tip admit different client
depth decisions. No Status-only function equals every client's depth view.
This impossibility theorem concerns views, never a machine rule.

### `seen_says_nothing_about_active` (`lean/BsvChain/Views/Status.lean:329`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: for any two machine statuses the same remote SEEN report
has the same word; it cannot distinguish unknown from active inclusion.
This theorem is about source-limited views, never a rule.

### `context_words_differ` (`lean/BsvChain/Views/Status.lean:422`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-13: predicate-checked contexts have different words at the
same status. Unsupported contexts return none. These are local models of cited
producer steps, never measurements or machine rules.

### `teranode_undefined_iff` (`lean/BsvChain/Views/Status.lean:511`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15 (#74): the Teranode node column is undefined exactly on the
one recorded no-function row, orphan, and defined on the other seven. This
theorem is about a view, never a rule.

### `teranode_read_inverse` (`lean/BsvChain/Views/Status.lean:518`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15 (#74): hypotheses h : teranodeState s = some x and
hx : x ≠ refused give back s through the map's reading: off a refusal the column
loses nothing of the derived status. This theorem is about a view, never a rule.

### `teranode_refusal_forgets_reason` (`lean/BsvChain/Views/Status.lean:525`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15 (#74): any two rejections have the same Teranode state, whatever
their codes and reasons: the refusal's words are Teranode's namespace, recorded
beside the reference's and never compared. This theorem is about a view, never a rule.

### `teranode_mined_implies_active` (`lean/BsvChain/Views/Status.lean:531`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15 (#74): hypothesis hs : teranodeState s = some (minedOnCurrent h)
concludes s = minedActive h: the current-chain state carries the derived height.
This theorem is about a view, never a rule.

## `BsvChain.Views.Wire.AtomicBEEF`

### `atomic_decodePrefix_encode` (`lean/BsvChain/Views/Wire/AtomicBEEF.lean:53`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86 (Atomic BEEF, parse after serialize). Premise: `wf`.
[LIT] BRC-95 at 5333fd4, 0095.md:27-38.

### `atomic_encode_decodePrefix` (`lean/BsvChain/Views/Wire/AtomicBEEF.lean:63`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86 (Atomic BEEF, serialize after parse). Premise: the
input is byte-valued. [LIT] BRC-95 at 5333fd4.

### `atomic_decode_encode` (`lean/BsvChain/Views/Wire/AtomicBEEF.lean:83`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86: the exact Atomic BEEF decoder and the encoder are inverse.

### `atomic_encode_decode` (`lean/BsvChain/Views/Wire/AtomicBEEF.lean:90`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86: the exact Atomic BEEF decoder's accepted bytes are the
encoding of what it reads. Premise: the input is byte-valued.

### `atomic_not_beef` (`lean/BsvChain/Views/Wire/AtomicBEEF.lean:102`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86: an Atomic BEEF is never read as a plain BEEF: its
leading four bytes are the word `0x01010101`, neither BEEF version. No premise.

### `scoped_subject` (`lean/BsvChain/Views/Wire/AtomicBEEF.lean:128`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86: a scoped Atomic BEEF names a subject it carries as a
raw transaction whose txid is the subject word. No premise beyond `scoped`.

## `BsvChain.Views.Wire.BEEF`

### `readBeefVersion_encode` (`lean/BsvChain/Views/Wire/BEEF.lean:149`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: each version word reads back as its version.

### `readBeefEntry_encode` (`lean/BsvChain/Views/Wire/BEEF.lean:157`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a well-formed entry reads back under its version.

### `beef_decodePrefix_encode` (`lean/BsvChain/Views/Wire/BEEF.lean:187`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86 (BEEF, parse after serialize). For every well-formed
BEEF of either version the decoder reads the encoder's bytes back exactly
and leaves any following stream untouched. Premise: `wf` (CompactSize counts
and indices, well-formed BUMPs and transactions, txid-only entries in version
2 only). [LIT] BRC-62 and BRC-96 at 5333fd4.

### `readBeefVersion_inv` (`lean/BsvChain/Views/Wire/BEEF.lean:202`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the version word read from byte-valued bytes writes back.

### `readBeefEntry_inv` (`lean/BsvChain/Views/Wire/BEEF.lean:221`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: an entry read from byte-valued bytes writes back under its version.

### `beef_encode_decodePrefix` (`lean/BsvChain/Views/Wire/BEEF.lean:286`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86 (BEEF, serialize after parse). A BEEF read from the
front of byte-valued bytes encodes back to exactly the bytes read: the
entries keep their order, each BUMP its leaf order. Premise: the input is
byte-valued. [LIT] BRC-62 and BRC-96 at 5333fd4.

### `beef_decode_encode` (`lean/BsvChain/Views/Wire/BEEF.lean:318`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86: the exact BEEF decoder and the encoder are inverse.

### `beef_encode_decode` (`lean/BsvChain/Views/Wire/BEEF.lean:324`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86: the exact BEEF decoder's accepted bytes are the encoding
of what it reads. Premise: the input is byte-valued.

### `subjectTx_txid` (`lean/BsvChain/Views/Wire/BEEF.lean:422`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86: the transaction a BEEF carries under a txid has that
txid. No premise beyond the lookup's success.

### `ancestry_subject` (`lean/BsvChain/Views/Wire/BEEF.lean:435`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86: the subject of an ancestry has the requested txid. No
premise beyond the projection's success.

## `BsvChain.Views.Wire.BUMP`

### `readBumpLeaf_encode` (`lean/BsvChain/Views/Wire/BUMP.lean:141`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a well-formed leaf reads back from its bytes.

### `readBumpLevel_encode` (`lean/BsvChain/Views/Wire/BUMP.lean:158`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a well-formed level reads back from its bytes.

### `bump_decodePrefix_encode` (`lean/BsvChain/Views/Wire/BUMP.lean:166`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86 (BUMP, parse after serialize). For every well-formed
BUMP the decoder reads the encoder's bytes back exactly and leaves any
following stream untouched. Premise: `wf` (CompactSize fields, at most 64
levels, 32-byte words). [LIT] BRC-74 at 5333fd4, 0074.md:45-77.

### `encodeBumpLeaf_read` (`lean/BsvChain/Views/Wire/BUMP.lean:179`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a leaf read from byte-valued bytes writes back.

### `encodeBumpLevel_read` (`lean/BsvChain/Views/Wire/BUMP.lean:212`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a level read from byte-valued bytes writes back.

### `bump_encode_decodePrefix` (`lean/BsvChain/Views/Wire/BUMP.lean:224`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86 (BUMP, serialize after parse). A BUMP read from the
front of byte-valued bytes encodes back to exactly the bytes read: one BUMP
value has one encoding, leaf order included (no engine-side sorting is part
of the format). Premise: the input is byte-valued. [LIT] BRC-74 at 5333fd4.

### `bump_decode_encode` (`lean/BsvChain/Views/Wire/BUMP.lean:248`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86: the exact BUMP decoder and the encoder are inverse.

### `bump_encode_decode` (`lean/BsvChain/Views/Wire/BUMP.lean:254`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86: the exact BUMP decoder's accepted bytes are the encoding
of what it reads, leaf order included. Premise: the input is byte-valued.

### `bumpFold_eq` (`lean/BsvChain/Views/Wire/BUMP.lean:336`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86 (BRC-74's root and #65's). On a node list with no
all-zero hash word, BRC-74's literal root and #65's `computeRootFromBranch`
over the marker path are the same function of the leaf and the index. Premise:
no hash node is the zero word (an all-zero SHA256d output); with one, the node's
reading takes it as the marker and BRC-74 hashes it (the conformance record's
witness of the zero word). [SRC] src/consensus/merkle.cpp:291-310 at 6504a3af.

### `toTsc_ofTsc` (`lean/BsvChain/Views/Wire/BUMP.lean:408`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a #75 node survives the BUMP node and back.

### `sibOffset_ne` (`lean/BsvChain/Views/Wire/BUMP.lean:412`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: no offset is its own sibling.

### `pathFrom_upper` (`lean/BsvChain/Views/Wire/BUMP.lean:417`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the levels above level 0 of `ofTsc` list the sibling node.

### `pathFor_ofTsc` (`lean/BsvChain/Views/Wire/BUMP.lean:437`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86 (BUMP and #75). The single-path BUMP built from a leaf,
its index and a node list returns exactly that node list as the leaf's path;
so its root for the leaf is the root #75's proof computes, and #65's
`verifyPath` decides both alike. No premise: every node list and index.

### `rootFor_ofTsc` (`lean/BsvChain/Views/Wire/BUMP.lean:471`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86: the root of a #75 proof's BUMP for its leaf is BRC-74's
root over the proof's nodes, and, when no hash node is the zero word, the root
#65's `computeRootFromBranch` gives over the proof's marker path. Premise of the
second part: no zero hash word (`bumpFold_eq`).

## `BsvChain.Views.Wire.Bytes`

### `byteValued_append` (`lean/BsvChain/Views/Wire/Bytes.lean:30`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: byte-valuedness splits over a concatenation.

### `byteValued_cons` (`lean/BsvChain/Views/Wire/Bytes.lean:40`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the tail of a byte-valued string is byte-valued.

### `readBytes_inv` (`lean/BsvChain/Views/Wire/Bytes.lean:44`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a successful `readBytes` splits its input: the bytes taken,
then the rest. [SRC] src/serialize.h:786-792 at 6504a3af.

### `readLE_inv` (`lean/BsvChain/Views/Wire/Bytes.lean:58`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a successful little-endian read of byte-valued input is
the fixed-width word of its value, below `256 ^ n`, then the rest.
[SRC] src/serialize.h:71-91 at 6504a3af.

### `compactSize2_eq` (`lean/BsvChain/Views/Wire/Bytes.lean:76`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the 2-byte CompactSize body is the 2-byte word.

### `readVarInt_inv` (`lean/BsvChain/Views/Wire/Bytes.lean:80`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: CompactSize after a successful canonical read of byte-valued
input gives the input back: the reader accepts exactly the writer's encodings.
[SRC] src/serialize.h:296-335 at 6504a3af.

### `readMany_inv` (`lean/BsvChain/Views/Wire/Bytes.lean:123`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: `readMany` after a reader whose every success is undone by
its writer is undone by the concatenated writer; the count is the length.
[SRC] src/serialize.h:794-804,823-840 at 6504a3af.

### `readTxIn_inv` (`lean/BsvChain/Views/Wire/Bytes.lean:156`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: an input read from byte-valued bytes writes back to them.
[SRC] src/primitives/transaction.h:60-66,151-157 at 6504a3af.

### `readTxOut_inv` (`lean/BsvChain/Views/Wire/Bytes.lean:184`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: an output read from byte-valued bytes writes back to them.
[SRC] src/primitives/transaction.h:189-194 at 6504a3af.

### `serVersion_toInt32` (`lean/BsvChain/Views/Wire/Bytes.lean:204`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the signed reading of a 32-bit word serializes back to it.

### `serTx_decodeTxPrefix` (`lean/BsvChain/Views/Wire/Bytes.lean:211`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86 (the transaction codec's reverse round trip). A
transaction read from the front of byte-valued bytes serializes back to the
bytes it consumed: `serTx tx ++ rest = bs`. With #68 G4 this makes the raw
transaction format a bijection between well-formed transactions and the
byte strings the decoder accepts. Premise: the input is byte-valued.
[SRC] src/primitives/transaction.h:233-252 and src/serialize.h:71-116,296-340,786-840 at 6504a3af.

### `decodeTx_serTx` (`lean/BsvChain/Views/Wire/Bytes.lean:248`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: exact framing in both directions: the exact decoder reads a
well-formed transaction's serialization, and the bytes it accepts are that
serialization. [SRC] src/core_read.cpp:184-191 at 6504a3af (`DecodeHexTx`
refuses trailing bytes).

### `serTx_decodeTx` (`lean/BsvChain/Views/Wire/Bytes.lean:257`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86: the exact transaction decoder's accepted bytes are the
serialization of what it reads. Premise: the input is byte-valued.

### `expectTag_append` (`lean/BsvChain/Views/Wire/Bytes.lean:280`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a tag is consumed from the front of its own bytes.

### `expectTag_inv` (`lean/BsvChain/Views/Wire/Bytes.lean:284`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a consumed tag and the rest give the input back.

### `readByte_inv` (`lean/BsvChain/Views/Wire/Bytes.lean:300`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a read byte and the rest give the input back.

## `BsvChain.Views.Wire.EF`

### `readEfInput_serEfInput` (`lean/BsvChain/Views/Wire/EF.lean:130`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: an extended input reads back from its bytes.

### `serEfInput_readEfInput` (`lean/BsvChain/Views/Wire/EF.lean:142`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: an extended input read from byte-valued bytes writes back.

### `ef_decodePrefix_encode` (`lean/BsvChain/Views/Wire/EF.lean:165`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86 (EF, parse after serialize). For every well-formed EF
transaction the decoder reads the encoder's bytes back exactly and leaves any
following stream untouched. Premise: `wf`, the field widths of #68's G4 and
of the extended fields. [LIT] BRC-30 at 5333fd4, 0030.md:36-69.

### `ef_encode_decodePrefix` (`lean/BsvChain/Views/Wire/EF.lean:185`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86 (EF, serialize after parse). An EF transaction read
from the front of byte-valued bytes encodes back to exactly the bytes read.
Premise: the input is byte-valued. [LIT] BRC-30 at 5333fd4, 0030.md:36-69.

### `ef_decode_encode` (`lean/BsvChain/Views/Wire/EF.lean:224`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86: the exact EF decoder and the encoder are inverse:
`decode (encode t) = some t` for well-formed `t`, and `encode t = bs` whenever
`decode bs = some t` on byte-valued `bs`.

### `ef_encode_decode` (`lean/BsvChain/Views/Wire/EF.lean:232`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86: the exact EF decoder's accepted bytes are the encoding
of what it reads. Premise: the input is byte-valued.

### `ef_ofTx_tx_spent` (`lean/BsvChain/Views/Wire/EF.lean:244`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86 (the projection is a section). The EF built from a
transaction and as many spent outputs as it has inputs projects back to that
transaction and those outputs. Premise: one spent output per input.

### `ef_legacy_reading` (`lean/BsvChain/Views/Wire/EF.lean:262`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86 (BRC-30's backward-compatibility sentence, 0030.md:46
and :73, as a theorem of the machine's own decoder). The transaction prefix
decoder reads the front of every well-formed EF stream as a transaction with
the EF's version, no inputs, no outputs and the lock time `0xEF000000`
(the marker's last four bytes, little-endian), and leaves a non-empty rest; so
the exact decoder `decodeTx` refuses every EF stream. Premise: `wf`.
[SRC] src/primitives/transaction.h:233-252 at 6504a3af; [LIT] BRC-30 at 5333fd4.

### `ef_not_plain` (`lean/BsvChain/Views/Wire/EF.lean:288`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86: the exact transaction decoder refuses every well-formed
EF stream (the corollary of `ef_legacy_reading`).

## `BsvChain.Views.Wire.TSC`

### `header_encode_decodePrefix` (`lean/BsvChain/Views/Wire/TSC.lean:19`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a header frame read from byte-valued bytes encodes back:
every field's value is below its width, so the bit vector keeps it.
[SRC] src/primitives/block.h:38-45 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.

### `readNode_inv` (`lean/BsvChain/Views/Wire/TSC.lean:57`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a node read from bytes writes back to them. [LIT] the TSC node layout.

### `decodeTxOrId_inv` (`lean/BsvChain/Views/Wire/TSC.lean:73`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a `txOrId` field read from byte-valued bytes writes back, and
its flag bit is the one read.

### `decodeTarget_inv` (`lean/BsvChain/Views/Wire/TSC.lean:96`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: a `target` field read from byte-valued bytes writes back, and
its kind is the one read.

### `tsc_encode_decodePrefix` (`lean/BsvChain/Views/Wire/TSC.lean:121`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86 (the TSC proof, serialize after parse). A binary TSC
proof read from the front of byte-valued bytes encodes back to exactly the
bytes read: the flags byte is the one the fields determine, so no other
flags value is accepted for the same fields. Premise: the input is
byte-valued. With #75's `tsc_decodePrefix_encode` the codec is a bijection
between well-formed proofs and the bytes the decoder accepts.
[LIT] the TSC binary layout, cited in `BsvChain.Views.MerkleProof`.

### `tsc_encode_decode` (`lean/BsvChain/Views/Wire/TSC.lean:155`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86: the exact TSC decoder's accepted bytes are the encoding
of what it reads. Premise: the input is byte-valued.

### `verifyTsc_eq_bump` (`lean/BsvChain/Views/Wire/TSC.lean:174`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[M] 2026-10-15, #86 (TSC, BUMP and #65 agree). Whenever the target supplies
a root and no hash node is the zero word, the TSC proof verifies exactly when
its BUMP computes that root for the proof's leaf at the proof's index.
Premises: the target resolves to `root`; no hash node is the all-zero word
(the node reads that word as the marker, BRC-74 hashes it).
[SRC] src/consensus/merkle.cpp:291-310 at 6504a3af; [LIT] BRC-74 at 5333fd4.

## `BsvChain.Wire.Relay`

### `askForCap_default` (`lean/BsvChain/Wire/Relay.lean:83`)

**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): `params`, `cfg`, `oracle` and `now` are not arguments of the statement.

[D] 2026-10-15: the defaults above; `askForCap` is the defaults' quotient.

## `BsvScript.Crypto.Secp256k1`

### `normalizeS_low` (`lean/BsvScript/Crypto/Secp256k1.lean:289`)

T-EC1: the normalization yields a low `s` for any `s` below `n`
(`secp256k1.c:443–460`; `n` is odd, so `n − s ≤ (n − 1) / 2` when `s > (n − 1) / 2`).

`[SRC]` `secp256k1.c:443–460`

## `BsvScript.Eval`

### `verifyScript_deterministic` (`lean/BsvScript/Eval.lean:43`)

**Determinism** (`docs/DESIGN.md` §9): the verdict is a function of its
inputs; two evaluations of the same spend under the same parameters agree. A
definitional fact, stated as the issue's done-bar asks.

### `opExecI_refines` (`lean/BsvScript/Eval.lean:63`)

**`opExecI_refines`.** *What it says:* the implementation's hook refines `opExec`: on every opcode, push
data, environment and state it answers what `opExec` answers on the spec state it stands for. *What it
assumes:* nothing. *Why it matters:* the one hypothesis of the machine's refinement (`Impl.verifyScriptA_eq`)
(#50).

### `verifyScript_eq_I` (`lean/BsvScript/Eval.lean:89`)

**`verifyScript_eq_I`.** *What it says:* the evaluator on the array-backed machine is the spec's evaluator,
as functions. *What it assumes:* nothing. *Why it matters:* `@[csimp]`: every compiled call of
`verifyScript` after this module runs `verifyScriptI` (the CLI's `eval` and `corpus`, `lean/Bsvs/Run.lean`; the
flow leg's corpus run, its kernel sample and its array-machine large-lock row; the list-machine row calls
`Machine.verifyScript` directly), where `OP_PICK`/`OP_ROLL` index the stack instead of walking it; nothing in the
semantics moves, and every theorem about `verifyScript` is about the definition (#50).

## `BsvScript.Flags`

### `testBit_bitOf` (`lean/BsvScript/Flags.lean:512`)

A one-bit word read back: bit `i` of `bitOf b k` is `b` at `i = k` and clear elsewhere; the step
`Flags.ofWord_toWord` (T-F1, below) reads each named bit of the word with.

### `Flags.ofWord_toWord` (`lean/BsvScript/Flags.lean:517`)

**T-F1.** *What it says:* the word encodes the record faithfully: reading the
word back gives the record. *Why it matters:* the CLI's `--flags <u32>` and the
corpus's explicit `flags` are the interpreter's own `uint32_t`, so the JSON
echo (`Flags.toWord`) is the word the interpreter runs. The RPC's `reportflags`
(`rpc/misc.cpp:540–541`, `rpc/misc.cpp:908–911`) echoes `(int)scr.flags` after re-deriving
the two UTXO bits from `txo.height` when one is given (`rpc/misc.cpp:803–823`), and keeps bits
`toWord` has no name for (lean #32's second lens, B-9; the file on every line, its fourth
re-lens, B4N-1).

`[SRC]` `rpc/misc.cpp:540–541`, `rpc/misc.cpp:908–911`, `rpc/misc.cpp:803–823`

### `Flags.toWord_ofWord` (`lean/BsvScript/Flags.lean:530`)

**T-F2.** The bits the record does not name are the only information a
`uint32_t` can lose: a word below `SCRIPT_FLAG_LAST` (`2^22`, `script_flags.h:114`)
with bits 11, 12 and 17 clear round-trips.

`[SRC]` `script_flags.h:114`

### `blockScriptFlags_policy_off` (`lean/BsvScript/Flags.lean:551`)

**The block word never carries a policy flag** (constitution 01 at the flag
level; `policy.h:177–181`: "scripts violating these flags may still be present in
valid blocks and we must accept those blocks"; `script_flags.h:56–57`). *What it
says:* for every chain, every height and every era, the four flags the census
classes as policy (NULLDUMMY, MINIMALDATA, DISCOURAGE_UPGRADABLE_NOPS, CLEANSTACK)
are off in `GetBlockScriptFlags`'s word. *Why it matters:* it is the theorem behind
the sentence "policy never decides block validity", read off the derivation.

`[SRC]` `policy.h:177–181`, `script_flags.h:56–57`

### `flagWord_neverSet_off` (`lean/BsvScript/Flags.lean:562`)

The never-set flags are never set by either derivation (without promiscuous flags): the node's own words
never carry MINIMALIF or COMPRESSED_PUBKEYTYPE. They reach the interpreter in an explicit word, the `verifyscript`
RPC's integer `flags` (`rpc/misc.cpp:697–702`), and, on a chain whose `RequireStandard()` is false (stn, testnet,
regtest: `chainparams.cpp:1271`, `:1416`, `:1527`), in a `-promiscuousmempoolflags` word (any non-negative integer,
`config.cpp:2584–2590`, made the mempool word at `verify_script_flags.cpp:23`): the route the hypothesis `hp`
excludes. `sendrawtransactions`' `skipscriptflags` only clears flags, and it refuses both of these
(`rpc/rawtransaction.cpp:1486`, `:1501–1506`).

`[SRC]` `rpc/misc.cpp:697–702`, `chainparams.cpp:1271`, `chainparams.cpp:1416`, `chainparams.cpp:1527`, `config.cpp:2584–2590`, `verify_script_flags.cpp:23`, `rpc/rawtransaction.cpp:1486`, `rpc/rawtransaction.cpp:1501–1506`

### `flagWord_valid` (`lean/BsvScript/Flags.lean:578`)

**The derived word is `valid_flags` on a node with no promiscuous word** (`2259–2262`; the hypothesis
`hp`, the exceptions below): the UTXO's
Chronicle marker implies its Genesis marker because Chronicle activity implies
Genesis activity (`protocol_era.cpp:89–103` on the ordered enum
`protocol_era.h:28–34`). So the derived word passes `valid_flags` (`interpreter.cpp:2312–2313`), and with
`flagWord_cleanStackDemand` (the error's other source, CLEANSTACK without P2SH, never in a derived word)
`SCRIPT_ERR_INVALID_FLAGS` is unreachable from a node's own derivation. The exceptions are configurations, and
none exists on mainnet. A
`-promiscuousmempoolflags` word reaches the interpreter only on a chain whose `RequireStandard()` is false
(`validation.cpp:795–801` passes the chain's value, true on mainnet, `chainparams.cpp:1121`; `-acceptnonstdtxn`
sets another value, `init.cpp:3158–3160`). There it replaces the mempool word and gains FORKID
(`verify_script_flags.cpp:21–25`), passes the skip mask (`validation.cpp:1330`) and is OR-ed with the per-input
word (`validation.cpp:2701`). A word carrying `SCRIPT_UTXO_AFTER_CHRONICLE` without `SCRIPT_UTXO_AFTER_GENESIS`
then fails every pre-Genesis input of that node with `SCRIPT_ERR_INVALID_FLAGS` (`interpreter.cpp:2312–2313`), and a
word carrying CLEANSTACK without P2SH fails every input that otherwise passes the same way
(`interpreter.cpp:2430–2436`): policy settings, and misconfigurations, never a consensus fact.

`[SRC]` `interpreter.cpp:2259–2262`, `protocol_era.cpp:89–103`, `protocol_era.h:28–34`, `interpreter.cpp:2312–2313`, `validation.cpp:795–801`, `chainparams.cpp:1121`, `init.cpp:3158–3160`, `verify_script_flags.cpp:21–25`, `validation.cpp:1330`, `validation.cpp:2701`, `interpreter.cpp:2430–2436`

### `flagWord_cleanStackDemand` (`lean/BsvScript/Flags.lean:601`)

**CLEANSTACK without P2SH is in no derived word** (`interpreter.cpp:2430–2436`, the second source of
`SCRIPT_ERR_INVALID_FLAGS`): the block word never carries CLEANSTACK (`blockScriptFlags_policy_off`) and every
standard word carries P2SH (mandatory in both eras, `standard.h:56`, `:63`), so `VerifyScript`'s demand
(`Flags.cleanStackDemand`) is off on both paths. Without promiscuous flags, as `flagWord_valid`.

`[SRC]` `interpreter.cpp:2430–2436`, `standard.h:56`, `standard.h:63`

### `flagWord_utxoEra` (`lean/BsvScript/Flags.lean:612`)

The UTXO era the interpreter reads back (`utxo_era`, `2269–2280`) is the era of
the UTXO's height (without promiscuous flags, as above).

`[SRC]` `interpreter.cpp:2269–2280`

### `flagWord_block_valid` (`lean/BsvScript/Flags.lean:621`)

The block path never reads the promiscuous word: the block word is valid unconditionally (the twin of
`flagWord_valid` without its hypothesis; that it carries the UTXO's era unconditionally is
`Properties.flagWord_block_utxoEra`).

### `derive_consensus_separation` (`lean/BsvScript/Flags.lean:629`)

**P5, parameter separation** (`docs/DESIGN.md` §9; constitution 01). *What it
says:* on the block path (`consensus = true`) `Params.derive` reads only the
consensus fields of a node's configuration: its chain, its two activation heights
and `maxstackmemoryusageconsensus`; two nodes that agree on those verify every
input under the same `EvalParams`, whatever their policy settings
(`maxopsperscriptpolicy`, `maxscriptnumlengthpolicy`, `maxscriptsizepolicy`,
`maxpubkeyspermultisigpolicy`, `maxstackmemoryusagepolicy`, `acceptnonstdtxn`,
`-promiscuousmempoolflags`). *What it assumes:* nothing. *Why it matters:* it is
the machine-checked form of "a policy limit never decides block validity"; a
Teranode and an SV-node with their different policy defaults (`docs/PARAMETERS.md`
§5) derive the same block parameters (the example below).

### `verifyScript_consensus_separation` (`lean/BsvScript/Flags.lean:649`)

The verdict-level corollary of P5: the block verdict of a spend is the same
under any two nodes that agree on the consensus fields.

### `Flags.gate_off_of_chronicle` (`lean/BsvScript/Flags.lean:723`)

With `SCRIPT_CHRONICLE` set and a version above 1 the gate is off (`40–44`) and
`Flags.gate` clears the seven restrictions.

`[SRC]` `interpreter.cpp:40–44`

### `flagWord_mempool_eq_block_mainnet` (`lean/BsvScript/Flags.lean:730`)

**The relay word and the block word on mainnet today differ in exactly the
four standard-only bits.** *What it says:* for a spend at or after the Chronicle
height on mainnet, under `requireStandard` (`hstd`), the mempool word is the block word plus NULLDUMMY,
DISCOURAGE_UPGRADABLE_NOPS, CLEANSTACK and MINIMALDATA. *What it assumes:* the mainnet chain and heights and `hstd`;
no promiscuous word is assumed or needed, since under `requireStandard` it is never read (`mempoolScriptFlags`,
`verify_script_flags.cpp:19–26`). At the pin the switch the word reads is the chain's `RequireStandard()`
(`validation.cpp:798`), true on mainnet (`chainparams.cpp:1121`) whatever `-acceptnonstdtxn` says (that option sets
another value, `init.cpp:3158–3160`), so on mainnet `hstd` describes every node. The word is the one a transaction
submitted without `skipscriptflags` runs under; that option can clear DERSIG, MINIMALDATA, NULLDUMMY,
DISCOURAGE_UPGRADABLE_NOPS or CLEANSTACK from it (`validation.cpp:1330`, `rpc/rawtransaction.cpp:1483–1510`).
*Why it matters:* three of the four hang on the version gate; the theorem after this one draws the consequence.

`[SRC]` `verify_script_flags.cpp:19–26`, `validation.cpp:798`, `chainparams.cpp:1121`, `init.cpp:3158–3160`, `validation.cpp:1330`, `rpc/rawtransaction.cpp:1483–1510`

### `verifyScript_relay_block_version2` (`lean/BsvScript/Flags.lean:759`)

**Relay versus block for a version-2 spend post-Chronicle (the CLAUDE.md
gotcha, for derived words).** *What it says:* on mainnet today, a version-2
spend verified under the relay word is judged exactly as under the block word
with DISCOURAGE_UPGRADABLE_NOPS added, whatever the limits: NULLDUMMY,
CLEANSTACK and MINIMALDATA are cleared by the version gate
(`EnforceNonMalleability`, `40–44`, at `1666`, `2441`, `433`) and only the
ungated policy bit survives. *What it assumes:* the mainnet chain and heights,
`requireStandard` (`hstd`: at the pin the chain's switch, true on mainnet, as `flagWord_mempool_eq_block_mainnet`
says), a spend height at or past Chronicle, a version above 1; the limits are a free parameter (they differ
between the paths and are not the subject). *Why it matters:* the seven-restriction
divergence the predecessor read from source (at its commit `c59f47a`) is here a theorem
about what a relaying node and a mining node do to the same version-2 spend: they
differ only on executed upgradable NOPs and on the resource limits, for a transaction submitted without
`skipscriptflags`, which can clear DERSIG (consensus by height), MINIMALDATA, NULLDUMMY,
DISCOURAGE_UPGRADABLE_NOPS or CLEANSTACK from the relay word (`validation.cpp:1330`, `rpc/rawtransaction.cpp:1486`).

`[SRC]` `interpreter.cpp:40–44`, `interpreter.cpp:1666`, `interpreter.cpp:2441`, `interpreter.cpp:433`, `validation.cpp:1330`, `rpc/rawtransaction.cpp:1486`

## `BsvScript.Gadget`

### `loop_eq_run` (`lean/BsvScript/Gadget.lean:80`)

**The API runs the semantics' own loop.** `Machine.loop` on a whole script is `run` with an
empty tail, read at the end. *What it assumes:* nothing. *Why it matters:* a consumer's statements
about `run` are statements about the spec's execution, never about a second machine.

### `getOpTail_append` (`lean/BsvScript/Gadget.lean:107`)

A parse inside a prefix is the parse inside the whole: `GetOp2` reads only the bytes it
consumes (`script.h:165–200`).

`[SRC]` `script.h:165–200`

### `run_append` (`lean/BsvScript/Gadget.lean:169`)

**Composition.** A framed fragment `g` followed by `h` runs as `g` (its tail `h ++ t`) and then,
at `g`'s end, `h`. *What it assumes:* `g` is framed (a push of `g` that runs into `h` would read
`h`'s bytes as data). *Why it matters:* a gadget proved once composes by concatenation.

### `Triple.seq` (`lean/BsvScript/Gadget.lean:196`)

**Sequential composition.** *What it assumes:* the first fragment is framed. *Why it matters:*
the whole emitted script's claim is the chain of its gadgets' claims.

### `Triple.conseq` (`lean/BsvScript/Gadget.lean:208`)

**Consequence.** A stronger precondition and a weaker postcondition keep a triple.

## `BsvScript.Gadget.HashLock`

### `run_sha256` (`lean/BsvScript/Gadget/HashLock.lean:34`)

**`OP_SHA256`** (`1402–1443`) on a stack whose top is `x`: the top replaced by `sha256 x`, one opcode
charged, `x`'s memory given back and the digest's charged (`limitedstack.h:163–173`).

`[SRC]` `interpreter.cpp:1402–1443`, `limitedstack.h:163–173`

### `run_push32` (`lean/BsvScript/Gadget/HashLock.lean:60`)

**The digest's push** (`473–481`): `0x20` then the 32 bytes of `h`, a minimal push (`checkMinimalPush`),
pushes `h` and charges its memory; no opcode is counted (`466–467` counts above `OP_16` only).

`[SRC]` `interpreter.cpp:473–481`, `interpreter.cpp:466–467`

### `run_equalverify_same` (`lean/BsvScript/Gadget/HashLock.lean:79`)

**`OP_EQUALVERIFY`** (`1189–1217`) on two equal elements `v` on top: both popped, the result pushed and
verified away, one opcode charged.

`[SRC]` `interpreter.cpp:1189–1217`

### `framed_push32` (`lean/BsvScript/Gadget/HashLock.lean:104`)

The digest's push is framed: `0x20` reads exactly the 32 bytes that follow it.

### `framed_single` (`lean/BsvScript/Gadget/HashLock.lean:115`)

A one-opcode fragment above `OP_PUSHDATA4` is framed.

### `sha256_triple` (`lean/BsvScript/Gadget/HashLock.lean:121`)

**`OP_SHA256` as a triple.** From a state whose top is `x` (the rest of the stack, the alt stack, the
conditional state and the counters named by ghost values), the top becomes `sha256 x`, one opcode charged, `x`'s
memory given back and the digest's 32 bytes charged.

### `push32_triple` (`lean/BsvScript/Gadget/HashLock.lean:138`)

**The digest's push as a triple.** The digest `h` goes on top of the stack `s`, its memory charged; no
opcode is counted.

### `equalverify_triple` (`lean/BsvScript/Gadget/HashLock.lean:154`)

**`OP_EQUALVERIFY` on two equal elements as a triple.** Both are popped, the result pushed and verified
away, one opcode charged.

### `hashLock_triple` (`lean/BsvScript/Gadget/HashLock.lean:173`)

**The hash-lock as a triple** (BIP 199's `OP_SHA256 <h> OP_EQUALVERIFY`; `docs/DESIGN.md` §12.4). *What it
says:* from every state whose top is a preimage `x` of `h`, the rest of the stack, the alt stack, the conditional
state and the counters named by ghost values, the gadget runs to its end, whatever follows it, in the state that
keeps all of them but the top, with two opcodes charged and `x`'s memory given back. *What it assumes:* the
gadget's preconditions (the module's header). *Why it matters:* the preimage check a contract compiler produces is
proved once, at the gadget level, as the composition of its three instructions' triples by `Triple.seq`, the
digest's equality carried across by `Triple.conseq`; a consumer's chain of gadgets composes it the same way.

## `BsvScript.Hash.Ripemd160`

### `Ripemd160.compress_size` (`lean/BsvScript/Hash/Ripemd160.lean:116`)

**One compression keeps a 5-word state.** *What it says:* `Ripemd160.compress` returns
an array of size 5 for any state and block. *What it assumes:* nothing. *Why it matters:*
it is the step of T-RMD1's induction (`Ripemd160.blocks_size`), which T-RMD2's 20-byte
digest rests on.

### `Ripemd160.blocks_size` (`lean/BsvScript/Hash/Ripemd160.lean:123`)

T-RMD1: RIPEMD-160 keeps a 5-word state.

### `Ripemd160.wordBytesLE_length` (`lean/BsvScript/Hash/Ripemd160.lean:132`)

**A word serializes to 4 bytes.** *What it says:* `Ripemd160.wordBytesLE` of any
32-bit word has length 4. *What it assumes:* nothing. *Why it matters:* with T-RMD1's
5 words it gives T-RMD2's 20 bytes (`ripemd160_length`).

### `ripemd160_length` (`lean/BsvScript/Hash/Ripemd160.lean:138`)

T-RMD2: a RIPEMD-160 digest is 20 bytes; so is `hash160`.

### `hash160_length` (`lean/BsvScript/Hash/Ripemd160.lean:147`)

**`hash160` is 20 bytes.** *What it says:* `hash160` (`CHash160`, RIPEMD-160 of
SHA-256) of any message has length 20. *What it assumes:* nothing. *Why it matters:*
`OP_HASH160`'s result (`Ops/Crypto.lean`) is 20 bytes, the width of the hash in
`isP2SH`'s 23-byte shape (T-RMD2 applied to the SHA-256 digest).

## `BsvScript.Hash.Sha1`

### `Sha1.compress_size` (`lean/BsvScript/Hash/Sha1.lean:68`)

**One compression keeps a 5-word state.** *What it says:* `Sha1.compress` returns an
array of size 5 for any state and block. *What it assumes:* nothing. *Why it matters:*
it is the step of T-SHA4's induction (`Sha1.blocks_size`), which `OP_SHA1`'s 20-byte
digest rests on.

### `Sha1.blocks_size` (`lean/BsvScript/Hash/Sha1.lean:75`)

T-SHA4: SHA-1 keeps a 5-word state.

### `sha1_length` (`lean/BsvScript/Hash/Sha1.lean:84`)

T-SHA5: a SHA-1 digest is 20 bytes.

## `BsvScript.Hash.Sha256`

### `compress_size` (`lean/BsvScript/Hash/Sha256.lean:114`)

**One compression keeps an 8-word state.** *What it says:* SHA-256's `compress`
returns an array of size 8 for any state and block. *What it assumes:* nothing.
*Why it matters:* it is the step of T-SHA1's induction (`blocks_size`), which T-SHA2's
32-byte digest rests on.

### `blocks_size` (`lean/BsvScript/Hash/Sha256.lean:121`)

T-SHA1: `blocks` keeps an 8-word state.

### `wordBytes_length` (`lean/BsvScript/Hash/Sha256.lean:130`)

**A word serializes to 4 bytes.** *What it says:* `wordBytes` of any 32-bit word has
length 4. *What it assumes:* nothing. *Why it matters:* with T-SHA1's 8 words it gives
T-SHA2's 32 bytes (`sha256_length`).

### `sha256_length` (`lean/BsvScript/Hash/Sha256.lean:136`)

T-SHA2: a SHA-256 digest is 32 bytes.

### `sha256d_length` (`lean/BsvScript/Hash/Sha256.lean:146`)

T-SHA3: a SHA-256d digest is 32 bytes.

## `BsvScript.Impl.Arith`

### `pushResult_abs` (`lean/BsvScript/Impl/Arith.lean:27`)

**`pushResult_abs`.** *What it says:* the implementation's result write stands for the spec's. *What it
assumes:* nothing. *Why it matters:* every arithmetic result (#50).

### `pushBool_abs` (`lean/BsvScript/Impl/Arith.lean:41`)

**`pushBool_abs`.** *What it says:* the implementation's boolean write stands for the spec's. *What it
assumes:* nothing. *Why it matters:* `OP_WITHIN` (#50).

### `unaryI_abs` (`lean/BsvScript/Impl/Arith.lean:54`)

**`unaryI_abs`.** *What it says:* the implementation's unary family computes what `Ops.Arith.unary`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* `OP_1ADD` … `OP_0NOTEQUAL`
on the implementation (#50).

### `binaryI_abs` (`lean/BsvScript/Impl/Arith.lean:79`)

**`binaryI_abs`.** *What it says:* the implementation's binary family computes what `Ops.Arith.binary`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* `OP_ADD` … `OP_MAX` on the
implementation (#50).

### `withinI_abs` (`lean/BsvScript/Impl/Arith.lean:101`)

**`withinI_abs`.** *What it says:* the implementation's `OP_WITHIN` computes what `Ops.Arith.within`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* `OP_WITHIN` on the
implementation (#50).

### `execI_refines` (`lean/BsvScript/Impl/Arith.lean:117`)

**`Arith.execI_refines`.** *What it says:* the implementation's arithmetic hook refines
`Ops.Arith.exec`. *What it assumes:* nothing. *Why it matters:* the family's part of the machine's refinement
(#50).

### `execI_of_not_owns` (`lean/BsvScript/Impl/Arith.lean:136`)

**`Arith.execI_of_not_owns`.** *What it says:* the hook answers `none` for an opcode it does not own. *What
it assumes:* `owns op = false`. *Why it matters:* the machine's dispatcher (#50).

### `isSome_execI` (`lean/BsvScript/Impl/Arith.lean:144`)

**`Arith.isSome_execI`.** *What it says:* the hook answers for every opcode it owns. *What it assumes:*
`owns op = true`. *Why it matters:* the machine's dispatcher (#50).

## `BsvScript.Impl.Bitwise`

### `bitwise2I_abs` (`lean/BsvScript/Impl/Bitwise.lean:31`)

**`bitwise2I_abs`.** *What it says:* the implementation's `OP_AND`/`OP_OR`/`OP_XOR` computes what
`Ops.Bitwise.bitwise2` computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the
family on the implementation (#50).

### `invertI_abs` (`lean/BsvScript/Impl/Bitwise.lean:46`)

**`invertI_abs`.** *What it says:* the implementation's `OP_INVERT` computes what `Ops.Bitwise.invert`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the
implementation (#50).

### `shiftI_abs` (`lean/BsvScript/Impl/Bitwise.lean:67`)

**`shiftI_abs`.** *What it says:* the implementation's `OP_LSHIFT`/`OP_RSHIFT` computes what
`Ops.Bitwise.shift` computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the
family on the implementation (#50).

### `equalI_abs` (`lean/BsvScript/Impl/Bitwise.lean:91`)

**`equalI_abs`.** *What it says:* the implementation's `OP_EQUAL`/`OP_EQUALVERIFY` computes what
`Ops.Bitwise.equal` computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the
family on the implementation (#50).

### `execI_refines` (`lean/BsvScript/Impl/Bitwise.lean:111`)

**`Bitwise.execI_refines`.** *What it says:* the implementation's bitwise hook refines
`Ops.Bitwise.exec`. *What it assumes:* nothing. *Why it matters:* the family's part of the machine's
refinement (#50).

### `execI_of_not_owns` (`lean/BsvScript/Impl/Bitwise.lean:133`)

**`Bitwise.execI_of_not_owns`.** *What it says:* the hook answers `none` for an opcode it does not own. *What
it assumes:* `owns op = false`. *Why it matters:* the machine's dispatcher (#50).

### `isSome_execI` (`lean/BsvScript/Impl/Bitwise.lean:141`)

**`Bitwise.isSome_execI`.** *What it says:* the hook answers for every opcode it owns. *What it assumes:*
`owns op = true`. *Why it matters:* the machine's dispatcher (#50).

## `BsvScript.Impl.Crypto`

### `scriptCodeOf_abs` (`lean/BsvScript/Impl/Crypto.lean:29`)

**`scriptCodeOf_abs`.** *What it says:* the implementation's scriptCode is the spec's. *What it
assumes:* nothing. *Why it matters:* the signature checks (#50).

### `hashOpI_abs` (`lean/BsvScript/Impl/Crypto.lean:39`)

**`hashOpI_abs`.** *What it says:* the implementation's hash opcodes compute what `Ops.Crypto.hashOp`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the
implementation (#50).

### `pushBit_abs` (`lean/BsvScript/Impl/Crypto.lean:47`)

**`pushBit_abs`.** *What it says:* the signature checks' result push, `[1]` or `[]`, is the push of the packed
`vchTrue` or the empty element. *What it assumes:* nothing. *Why it matters:* `OP_CHECKSIG`'s and
`OP_CHECKMULTISIG`'s results (#143).

### `checkSigOpI_abs` (`lean/BsvScript/Impl/Crypto.lean:79`)

**`checkSigOpI_abs`.** *What it says:* the implementation's `OP_CHECKSIG`/`OP_CHECKSIGVERIFY` computes
what `Ops.Crypto.checkSigOp` computes on the state it stands for. *What it assumes:* nothing. *Why it
matters:* the family on the implementation (#50).

### `multisigLoop_abs` (`lean/BsvScript/Impl/Crypto.lean:105`)

**`multisigLoop_abs`.** *What it says:* the implementation's signature loop answers what
`Ops.Crypto.multisigLoop` answers on the state it stands for. *What it assumes:* nothing. *Why it matters:*
`OP_CHECKMULTISIG` on the implementation (#50).

### `forIn_bind_abs` (`lean/BsvScript/Impl/Crypto.lean:128`)

**`forIn_bind_abs`.** *What it says:* a `for` loop over a list whose body over the implementation state
stands for the spec's body, followed by continuations that agree, computes what the spec's loop and
continuation compute. *What it assumes:* the two bodies and the two continuations agree on every state.
*Why it matters:* `OP_CHECKMULTISIG`'s pops of its arguments (`1636–1653`) (#50).

`[SRC]` `interpreter.cpp:1636–1653`

### `checkMultiSigOpI_abs` (`lean/BsvScript/Impl/Crypto.lean:191`)

**`checkMultiSigOpI_abs`.** *What it says:* the implementation's `OP_CHECKMULTISIG`/
`OP_CHECKMULTISIGVERIFY` computes what `Ops.Crypto.checkMultiSigOp` computes on the state it stands for.
*What it assumes:* nothing. *Why it matters:* the family on the implementation (#50).

### `execI_refines` (`lean/BsvScript/Impl/Crypto.lean:215`)

**`Crypto.execI_refines`.** *What it says:* the implementation's crypto hook refines `Ops.Crypto.exec`.
*What it assumes:* nothing. *Why it matters:* the family's part of the machine's refinement (#50).

### `execI_of_not_owns` (`lean/BsvScript/Impl/Crypto.lean:234`)

**`Crypto.execI_of_not_owns`.** *What it says:* the hook answers `none` for an opcode it does not own. *What
it assumes:* `owns op = false`. *Why it matters:* the machine's dispatcher (#50).

### `isSome_execI` (`lean/BsvScript/Impl/Crypto.lean:242`)

**`Crypto.isSome_execI`.** *What it says:* the hook answers for every opcode it owns. *What it assumes:*
`owns op = true`. *Why it matters:* the machine's dispatcher (#50).

## `BsvScript.Impl.Elem`

### `toBytes_pushList` (`lean/BsvScript/Impl/Elem.lean:41`)

**`toBytes_pushList`.** *What it says:* pushing a valid list appends it. *What it assumes:*
`Bytes.valid bs`. *Why it matters:* `OP_NUM2BIN`'s pad (#143).

### `toBytesLoop_eq` (`lean/BsvScript/Impl/Elem.lean:67`)

**`toBytesLoop_eq`.** *What it says:* the loop from index `i` puts the leading `i` bytes before the
accumulator. *What it assumes:* nothing. *Why it matters:* `toBytes_eq_fast` (#143).

### `toBytes_eq_fast` (`lean/BsvScript/Impl/Elem.lean:79`)

`@[csimp]` (#143): the compiler reads an element's bytes by the loop.

### `data_pushList` (`lean/BsvScript/Impl/Elem.lean:85`)

**`data_pushList`.** *What it says:* pushing a list appends its bytes, each modulo 256. *What it assumes:*
nothing. *Why it matters:* `ofBytes_eq_fast` (#143).

### `ofBytes_eq_fast` (`lean/BsvScript/Impl/Elem.lean:95`)

`@[csimp]` (#143): the compiler packs a list by the loop.

### `validB_iff` (`lean/BsvScript/Impl/Elem.lean:106`)

**`validB_iff`.** *What it says:* the test answers `Bytes.valid`. *What it assumes:* nothing. *Why it
matters:* the machine's guard on a script and a stack handed in from outside (#143).

### `toBytes_valid` (`lean/BsvScript/Impl/Elem.lean:111`)

**`toBytes_valid`.** *What it says:* an element's bytes are bytes. *What it assumes:* nothing. *Why it
matters:* the state carries `Bytes.valid` by its type (#143).

### `toBytes_ofBytes` (`lean/BsvScript/Impl/Elem.lean:119`)

**`toBytes_ofBytes`.** *What it says:* the element of a valid byte list reads back as that list. *What it
assumes:* `Bytes.valid bs`. *Why it matters:* every element the implementation builds from a list (#143).

### `ofBytes_toBytes` (`lean/BsvScript/Impl/Elem.lean:128`)

**`ofBytes_toBytes`.** *What it says:* an element read as a list and back is itself. *What it assumes:*
nothing. *Why it matters:* `IState.ofState_abs` (#143).

### `toBytes_inj` (`lean/BsvScript/Impl/Elem.lean:136`)

**`toBytes_inj`.** *What it says:* two elements with the same bytes are the same. *What it assumes:*
nothing. *Why it matters:* `OP_EQUAL` compares the packed arrays (#143).

### `length_toBytes` (`lean/BsvScript/Impl/Elem.lean:146`)

**`length_toBytes`.** *What it says:* the list's length is the element's size. *What it assumes:* nothing.
*Why it matters:* every memory charge and every length test in one read (#143).

### `toBytes_empty` (`lean/BsvScript/Impl/Elem.lean:154`)

**`toBytes_empty`.** *What it says:* the empty element is the empty list. *What it assumes:* nothing. *Why
it matters:* `vchFalse`, and `topAt`'s value past the depth (#143).

### `isEmpty_toBytes` (`lean/BsvScript/Impl/Elem.lean:158`)

**`isEmpty_toBytes`.** *What it says:* the list is empty exactly when the element's size is zero. *What it
assumes:* nothing. *Why it matters:* the signature checks' empty-signature tests (#143).

### `decide_toBytes_eq` (`lean/BsvScript/Impl/Elem.lean:164`)

**`decide_toBytes_eq`.** *What it says:* comparing two elements' lists is comparing the elements (the
runtime's `lean_sarray_dec_eq`, a `memcmp`). *What it assumes:* nothing. *Why it matters:* `OP_EQUAL` (#143).

### `head?_toBytes` (`lean/BsvScript/Impl/Elem.lean:172`)

**`head?_toBytes`.** *What it says:* the list's first byte is the element's. *What it assumes:* nothing.
*Why it matters:* `OP_IF`'s minimal-if test (#143).

### `toBytes_append` (`lean/BsvScript/Impl/Elem.lean:186`)

**`toBytes_append`.** *What it says:* appending elements is appending their lists. *What it assumes:*
nothing. *Why it matters:* `OP_CAT` in one copy (#143).

### `toBytes_take` (`lean/BsvScript/Impl/Elem.lean:197`)

**`toBytes_take`.** *What it says:* an element's leading `n` bytes are its list's. *What it assumes:* nothing.
*Why it matters:* `OP_SPLIT`, `OP_LEFT`, `OP_SUBSTR` (#143).

### `toBytes_drop` (`lean/BsvScript/Impl/Elem.lean:202`)

**`toBytes_drop`.** *What it says:* an element's bytes after the first `n` are its list's. *What it assumes:*
nothing. *Why it matters:* `OP_SPLIT`, `OP_RIGHT`, `OP_SUBSTR` (#143).

### `toBytes_encode` (`lean/BsvScript/Impl/Elem.lean:215`)

**`toBytes_encode`.** *What it says:* the element is the encoding. *What it assumes:* nothing. *Why it
matters:* every arithmetic result, count and small-number push (#143).

### `toBytes_vchTrue` (`lean/BsvScript/Impl/Elem.lean:223`)

**`toBytes_vchTrue`.** *What it says:* the element is `[1]`. *What it assumes:* nothing. *Why it matters:*
`OP_EQUAL` and the signature checks' results (#143).

### `toBytes_vchFalse` (`lean/BsvScript/Impl/Elem.lean:227`)

**`toBytes_vchFalse`.** *What it says:* `vchFalse` is the empty element. *What it assumes:* nothing. *Why
it matters:* `OP_EQUAL` and the signature checks' results (#143).

### `versionLE_valid` (`lean/BsvScript/Impl/Elem.lean:231`)

**`versionLE_valid`.** *What it says:* the version's four bytes are bytes. *What it assumes:* nothing.
*Why it matters:* `OP_VER` (#143).

### `toBytes_versionLE` (`lean/BsvScript/Impl/Elem.lean:241`)

**`toBytes_versionLE`.** *What it says:* the element is the version's bytes. *What it assumes:* nothing.
*Why it matters:* `OP_VER` (#143).

### `readOperand_eq` (`lean/BsvScript/Impl/Elem.lean:253`)

**`readOperand_eq`.** *What it says:* the element's reader answers what the spec's reader answers on its
list. *What it assumes:* nothing. *Why it matters:* an operand too long to be a number is refused without its
list being built (#143).

### `readInt64Operand_eq` (`lean/BsvScript/Impl/Elem.lean:267`)

**`readInt64Operand_eq`.** *What it says:* the element's reader answers what the spec's reader answers on its
list. *What it assumes:* nothing. *Why it matters:* `OP_SUBSTR`, `OP_LEFT`, `OP_RIGHT` (#143).

### `readCount_eq` (`lean/BsvScript/Impl/Elem.lean:280`)

**`readCount_eq`.** *What it says:* the element's reader answers what the spec's reader answers on its list.
*What it assumes:* nothing. *Why it matters:* `OP_CHECKMULTISIG`'s counts (#143).

### `readNum_eq` (`lean/BsvScript/Impl/Elem.lean:292`)

**`readNum_eq`.** *What it says:* the element's reader answers what the spec's reader answers on its list.
*What it assumes:* nothing. *Why it matters:* `OP_CHECKLOCKTIMEVERIFY`, `OP_CHECKSEQUENCEVERIFY` (#143).

### `castToBool_eq` (`lean/BsvScript/Impl/Elem.lean:304`)

**`castToBool_eq`.** *What it says:* the element's truth is its list's. *What it assumes:* nothing. *Why it
matters:* `OP_IF`, `OP_VERIFY`, `OP_IFDUP`, `OP_NUMEQUALVERIFY` (#143).

### `toBytes_minimallyEncode` (`lean/BsvScript/Impl/Elem.lean:313`)

**`toBytes_minimallyEncode`.** *What it says:* the element is the minimal encoding of the list. *What it
assumes:* nothing. *Why it matters:* `OP_BIN2NUM` (#143).

### `toBytes_pushZeros` (`lean/BsvScript/Impl/Elem.lean:325`)

**`toBytes_pushZeros`.** *What it says:* pushing `n` zeros appends `n` zeros to the list. *What it assumes:*
nothing. *Why it matters:* `OP_NUM2BIN`'s pad (#143).

### `toBytes_num2binPad` (`lean/BsvScript/Impl/Elem.lean:346`)

**`toBytes_num2binPad`.** *What it says:* the element is the spec's pad. *What it assumes:* `Bytes.valid m`.
*Why it matters:* `OP_NUM2BIN` to a width of two billion bytes holds two billion bytes, not two billion cons cells
(#142's record; #143).

### `num2binM_map` (`lean/BsvScript/Impl/Elem.lean:381`)

**`num2binM_map`.** *What it says:* the padding step on the operand's minimal encoding answers what the
spec's answers on the operand. *What it assumes:* nothing. *Why it matters:* `OP_NUM2BIN` (#143).

### `toBytes_zipWith` (`lean/BsvScript/Impl/Elem.lean:398`)

**`toBytes_zipWith`.** *What it says:* the combination is the spec's on the two lists. *What it assumes:*
`f` keeps two bytes a byte. *Why it matters:* `OP_AND`, `OP_OR`, `OP_XOR` (#143).

### `bitwise_byte` (`lean/BsvScript/Impl/Elem.lean:408`)

**`bitwise_byte`.** *What it says:* `&&&`, `|||` and `^^^` keep two bytes a byte, as the op's selection of
them does. *What it assumes:* nothing. *Why it matters:* `toBytes_zipWith`'s side condition for `OP_AND`/`OP_OR`/
`OP_XOR` (#143).

### `toBytes_invert` (`lean/BsvScript/Impl/Elem.lean:427`)

**`toBytes_invert`.** *What it says:* the inverted element is the spec's map on its list. *What it assumes:*
nothing. *Why it matters:* `OP_INVERT` (#143).

### `toBytes_zeros` (`lean/BsvScript/Impl/Elem.lean:439`)

**`toBytes_zeros`.** *What it says:* the element is `n` zeros. *What it assumes:* nothing. *Why it matters:*
`OP_LSHIFT`/`OP_RSHIFT` by the width or more (#143).

### `or_byte` (`lean/BsvScript/Impl/Elem.lean:446`)

**`or_byte`.** *What it says:* two bytes or'd are a byte. *What it assumes:* both below 256. *Why it
matters:* the shifts' bytes (#143).

### `and_byte` (`lean/BsvScript/Impl/Elem.lean:451`)

**`and_byte`.** *What it says:* anything and'd with a byte is a byte. *What it assumes:* `y < 256`. *Why it
matters:* the shifts' bytes (#143).

### `rmask_lt` (`lean/BsvScript/Impl/Elem.lean:455`)

**`rmask_lt`.** *What it says:* `make_rshift_mask` is a byte. *What it assumes:* nothing. *Why it matters:*
the shifts' bytes (#143).

### `lmask_lt` (`lean/BsvScript/Impl/Elem.lean:461`)

**`lmask_lt`.** *What it says:* `make_lshift_mask` is a byte. *What it assumes:* nothing. *Why it matters:*
the shifts' bytes (#143).

### `rshift_valid` (`lean/BsvScript/Impl/Elem.lean:467`)

**`rshift_valid`.** *What it says:* `RShift`'s bytes are bytes. *What it assumes:* nothing. *Why it matters:*
`OP_RSHIFT` (#143).

### `lshift_valid` (`lean/BsvScript/Impl/Elem.lean:481`)

**`lshift_valid`.** *What it says:* `LShift`'s bytes are bytes. *What it assumes:* nothing. *Why it matters:*
`OP_LSHIFT` (#143).

### `toBytes_rshift` (`lean/BsvScript/Impl/Elem.lean:498`)

**`toBytes_rshift`.** *What it says:* the element is the spec's `RShift` of its list. *What it assumes:*
nothing. *Why it matters:* `OP_RSHIFT` (#143).

### `toBytes_lshift` (`lean/BsvScript/Impl/Elem.lean:506`)

**`toBytes_lshift`.** *What it says:* the element is the spec's `LShift` of its list. *What it assumes:*
nothing. *Why it matters:* `OP_LSHIFT` (#143).

### `flatten_wordBytes_valid` (`lean/BsvScript/Impl/Elem.lean:513`)

**`flatten_wordBytes_valid`.** *What it says:* words written as big-endian bytes are bytes. *What it
assumes:* nothing. *Why it matters:* SHA-256 and SHA-1 digests (#143).

### `flatten_wordBytesLE_valid` (`lean/BsvScript/Impl/Elem.lean:522`)

**`flatten_wordBytesLE_valid`.** *What it says:* words written as little-endian bytes are bytes. *What it
assumes:* nothing. *Why it matters:* RIPEMD-160 digests (#143).

### `sha256_valid` (`lean/BsvScript/Impl/Elem.lean:531`)

**`sha256_valid`.** *What it says:* a SHA-256 digest is bytes. *What it assumes:* nothing. *Why it matters:*
`OP_SHA256`, `OP_HASH160`, `OP_HASH256` (#143).

### `sha1_valid` (`lean/BsvScript/Impl/Elem.lean:535`)

**`sha1_valid`.** *What it says:* a SHA-1 digest is bytes. *What it assumes:* nothing. *Why it matters:*
`OP_SHA1` (#143).

### `ripemd160_valid` (`lean/BsvScript/Impl/Elem.lean:539`)

**`ripemd160_valid`.** *What it says:* a RIPEMD-160 digest is bytes. *What it assumes:* nothing. *Why it
matters:* `OP_RIPEMD160`, `OP_HASH160` (#143).

### `toBytes_hashOp` (`lean/BsvScript/Impl/Elem.lean:552`)

**`toBytes_hashOp`.** *What it says:* the element is the spec's digest of its list. *What it assumes:*
nothing. *Why it matters:* the hash opcodes (#143).

## `BsvScript.Impl.Expansion`

### `nopOrDiscourageI_abs` (`lean/BsvScript/Impl/Expansion.lean:25`)

**`nopOrDiscourageI_abs`.** *What it says:* the implementation's pre-Chronicle rule answers as the
spec's. *What it assumes:* nothing. *Why it matters:* the family on the implementation (#50).

### `pushEncode_abs` (`lean/BsvScript/Impl/Expansion.lean:32`)

**`pushEncode_abs`.** *What it says:* pushing a number's encoding, read as the spec's, is pushing its packed
encoding. *What it assumes:* nothing. *Why it matters:* `OP_LSHIFTNUM`, `OP_RSHIFTNUM`, whose range test reads the
same encoding, computed once (#143).

### `substrI_abs` (`lean/BsvScript/Impl/Expansion.lean:61`)

**`substrI_abs`.** *What it says:* the implementation's `OP_SUBSTR` answers what `Ops.Expansion.substr`
answers on the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the
implementation (#50).

### `leftI_abs` (`lean/BsvScript/Impl/Expansion.lean:96`)

**`leftI_abs`.** *What it says:* the implementation's `OP_LEFT` answers what `Ops.Expansion.left` answers
on the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the implementation
(#50).

### `rightI_abs` (`lean/BsvScript/Impl/Expansion.lean:127`)

**`rightI_abs`.** *What it says:* the implementation's `OP_RIGHT` answers what `Ops.Expansion.right`
answers on the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the
implementation (#50).

### `lshiftnumI_abs` (`lean/BsvScript/Impl/Expansion.lean:166`)

**`lshiftnumI_abs`.** *What it says:* the implementation's `OP_LSHIFTNUM` answers what
`Ops.Expansion.lshiftnum` answers on the state it stands for. *What it assumes:* nothing. *Why it matters:*
the family on the implementation (#50).

### `rshiftnumI_abs` (`lean/BsvScript/Impl/Expansion.lean:210`)

**`rshiftnumI_abs`.** *What it says:* the implementation's `OP_RSHIFTNUM` answers what
`Ops.Expansion.rshiftnum` answers on the state it stands for. *What it assumes:* nothing. *Why it matters:*
the family on the implementation (#50).

### `execI_refines` (`lean/BsvScript/Impl/Expansion.lean:241`)

**`Expansion.execI_refines`.** *What it says:* the implementation's expansion hook refines
`Ops.Expansion.exec`. *What it assumes:* nothing. *Why it matters:* the family's part of the machine's
refinement (#50).

### `execI_of_not_owns` (`lean/BsvScript/Impl/Expansion.lean:257`)

**`Expansion.execI_of_not_owns`.** *What it says:* the hook answers `none` for an opcode it does not own. *What
it assumes:* `owns op = false`. *Why it matters:* the machine's dispatcher (#50).

### `isSome_execI` (`lean/BsvScript/Impl/Expansion.lean:265`)

**`Expansion.isSome_execI`.** *What it says:* the hook answers for every opcode it owns. *What it assumes:*
`owns op = true`. *Why it matters:* the machine's dispatcher (#50).

## `BsvScript.Impl.Machine`

### `pushStep_eq` (`lean/BsvScript/Impl/Machine.lean:62`)

**`pushStep_eq`.** *What it says:* a push of an element read as a step on the implementation says what the
spec's push of its bytes says. *What it assumes:* nothing. *Why it matters:* the pushes of `execFlow` and
`execStep` (#50).

### `pushStepB_eq` (`lean/BsvScript/Impl/Machine.lean:75`)

**`pushStepB_eq`.** *What it says:* `pushStep_eq` for an element packed from a valid list. *What it assumes:*
`Bytes.valid bs`. *Why it matters:* the pushes of the script's data and of the small numbers (#143).

### `verifyStep_eq` (`lean/BsvScript/Impl/Machine.lean:87`)

**`verifyStep_eq`.** *What it says:* `OP_VERIFY` on the implementation says what the spec's says. *What it
assumes:* nothing. *Why it matters:* `execFlow`'s `842–854` (#50).

`[SRC]` `interpreter.cpp:842–854`

### `hookStep_eq` (`lean/BsvScript/Impl/Machine.lean:107`)

**`hookStep_eq`.** *What it says:* a family's answer read as a step on the implementation says what the
spec's family's answer says, when the implementation's hook refines the spec's. *What it assumes:*
`Refines exec execI`. *Why it matters:* `execFlow`'s default case (`1795`) (#50).

`[SRC]` `interpreter.cpp:1795`

### `execIfI_eq` (`lean/BsvScript/Impl/Machine.lean:153`)

**`execIfI_eq`.** *What it says:* the implementation's `OP_IF` family says what the spec's says. *What it
assumes:* nothing. *Why it matters:* the conditionals on the implementation (#50).

### `execCltvI_eq` (`lean/BsvScript/Impl/Machine.lean:182`)

**`execCltvI_eq`.** *What it says:* the implementation's `OP_CHECKLOCKTIMEVERIFY` says what the spec's says.
*What it assumes:* nothing. *Why it matters:* the lock-time check on the implementation (#50).

### `execCsvI_eq` (`lean/BsvScript/Impl/Machine.lean:216`)

**`execCsvI_eq`.** *What it says:* the implementation's `OP_CHECKSEQUENCEVERIFY` says what the spec's says.
*What it assumes:* nothing. *Why it matters:* the sequence check on the implementation (#50).

### `execFlowI_eq` (`lean/BsvScript/Impl/Machine.lean:277`)

**`execFlowI_eq`.** *What it says:* the implementation's flow opcodes and default case say what the spec's
say, when the implementation's hook refines the spec's. *What it assumes:* `Refines exec execI`. *Why it
matters:* every executed opcode but the pushes and the separator (#50).

### `execStepI_eq` (`lean/BsvScript/Impl/Machine.lean:312`)

**`execStepI_eq`.** *What it says:* the implementation's step says what the spec's step says, when the
implementation's hook refines the spec's and the push's data is bytes. *What it assumes:* `Refines exec execI`;
`Bytes.valid data`. *Why it matters:* the loop's refinement, one instruction at a time (#50).

### `getOpTail_valid` (`lean/BsvScript/Impl/Machine.lean:327`)

**`getOpTail_valid`.** *What it says:* the data of a push read from a byte list is bytes. *What it assumes:*
`Bytes.valid rest`. *Why it matters:* the push's data is packed (#143).

### `LoopRel.of_err` (`lean/BsvScript/Impl/Machine.lean:382`)

**`LoopRel.of_err`.** *What it says:* two loop results that fail with the same error stand for each other,
whatever their states. *What it assumes:* nothing. *Why it matters:* the loop's failing exits (#50).

### `LoopRel.of_ok` (`lean/BsvScript/Impl/Machine.lean:387`)

**`LoopRel.of_ok`.** *What it says:* a successful result stands for the successful result on the state it
stands for. *What it assumes:* nothing. *Why it matters:* the loop's successful exits (#50).

### `ofState_alt` (`lean/BsvScript/Impl/Machine.lean:391`)

**`ofState_alt`.** *What it says:* the implementation state made from a spec state has its alt stack, packed.
*What it assumes:* nothing. *Why it matters:* the pre-Genesis depth test after each step reads the alt stack's
length (#50; packed since #143).

### `loopI_rel` (`lean/BsvScript/Impl/Machine.lean:396`)

**`loopI_rel`.** *What it says:* the implementation's loop agrees with `Machine.loop` on the outcome, and at
`.ok` on the state, when the implementation's hook refines the spec's and the script is bytes. *What it assumes:*
`Refines exec execI`; `Bytes.valid script` (its pushes are packed, #143). *Why it matters:* the whole script on
the implementation (#50).

### `evalScriptI_rel` (`lean/BsvScript/Impl/Machine.lean:460`)

**`evalScriptI_rel`.** *What it says:* the implementation's `EvalScript` agrees with `Machine.evalScript` on
the outcome, and at `.ok` on the state, when the implementation's hook refines the spec's and the script is bytes.
*What it assumes:* `Refines exec execI`; `Bytes.valid script`. *Why it matters:* each phase of a spend on the
implementation (#50).

### `evalScriptA_rel` (`lean/BsvScript/Impl/Machine.lean:489`)

**`evalScriptA_rel`.** *What it says:* `EvalScript` run on the implementation agrees with
`Machine.evalScript` on the outcome, and at `.ok` on the state. *What it assumes:* `Refines exec execI`.
*Why it matters:* the two phases on the implementation (#50).

### `phase2_eq_gen` (`lean/BsvScript/Impl/Machine.lean:562`)

**`phase2_eq_gen`.** *What it says:* `Machine.phase2` is `phase2Gen` on `Machine.evalScript`. *What it
assumes:* nothing. *Why it matters:* the implementation's phases are the spec's text (#50).

### `phase2Gen_congr` (`lean/BsvScript/Impl/Machine.lean:569`)

**`phase2Gen_congr`.** *What it says:* `phase2Gen` gives the same verdict on two evaluators that agree on
every outcome and on every state at `.ok`. *What it assumes:* the evaluators agree so. *Why it matters:* the
verdict reads a phase's state only at `.ok` (#50).

### `verifyScript_eq_gen` (`lean/BsvScript/Impl/Machine.lean:643`)

**`verifyScript_eq_gen`.** *What it says:* `Machine.verifyScript` is `verifyScriptGen` on
`Machine.evalScript`. *What it assumes:* nothing. *Why it matters:* the implementation's verifier is the spec's
text (#50).

### `verifyScriptGen_congr` (`lean/BsvScript/Impl/Machine.lean:650`)

**`verifyScriptGen_congr`.** *What it says:* `verifyScriptGen` gives the same verdict on two evaluators that
agree on every outcome and on every state at `.ok`. *What it assumes:* the evaluators agree so. *Why it
matters:* the verdict reads the unlocking phase's state only at `.ok` (#50).

### `phase2P_spec` (`lean/BsvScript/Impl/Machine.lean:767`)

**`phase2P_spec`.** *What it says:* `phase2P` on the spec's view is `phase2Gen`. *What it assumes:* nothing.
*Why it matters:* the packed hand-off's phases are the spec's text (#143).

### `verifyScriptP_spec` (`lean/BsvScript/Impl/Machine.lean:813`)

**`verifyScriptP_spec`.** *What it says:* `verifyScriptP` on the spec's view is `verifyScriptGen`. *What it
assumes:* nothing. *Why it matters:* the packed hand-off's verifier is the spec's text (#143).

### `TopRel.cases` (`lean/BsvScript/Impl/Machine.lean:839`)

**`TopRel.cases`.** *What it says:* two agreeing tops are both empty, or the same valid bytes over agreeing
rests. *What it assumes:* `TopRel R o₁ o₂`. *Why it matters:* the congruence proofs case on it (#143).

### `afterP2shP_congr` (`lean/BsvScript/Impl/Machine.lean:865`)

**`afterP2shP_congr`.** *What it says:* the P2SH step gives the same verdict on two agreeing views, and the
same depth when that verdict is valid. *What it assumes:* `ViewRel`; the copies related (both absent, or related
stacks with the same counter); the two states related. *Why it matters:* `phase2P_congr` (#143).

### `phase2P_congr` (`lean/BsvScript/Impl/Machine.lean:907`)

**`phase2P_congr`.** *What it says:* `phase2P` gives the same verdict on two agreeing views from related
stacks. *What it assumes:* `ViewRel`; the stacks related; the locking script is bytes. *Why it matters:* the
locking phase on the packed hand-off (#143).

### `verifyScriptP_congr` (`lean/BsvScript/Impl/Machine.lean:942`)

**`verifyScriptP_congr`.** *What it says:* `verifyScriptP` gives the same verdict on two agreeing views. *What
it assumes:* `ViewRel`; both scripts are bytes. *Why it matters:* the two phases on the packed hand-off (#143).

### `verifyScriptA_eq` (`lean/BsvScript/Impl/Machine.lean:1014`)

**`verifyScriptA_eq`.** *What it says:* the verifier run on the implementation gives `Machine.verifyScript`'s
verdict on every spend, when the implementation's hook refines the spec's. *What it assumes:*
`Refines exec execI`. *Why it matters:* the machine's refinement, whole (#50).

## `BsvScript.Impl.Splice`

### `catI_abs` (`lean/BsvScript/Impl/Splice.lean:32`)

**`catI_abs`.** *What it says:* the implementation's `OP_CAT` computes what `Ops.Splice.cat` computes on
the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the implementation
(#50).

### `splitI_abs` (`lean/BsvScript/Impl/Splice.lean:51`)

**`splitI_abs`.** *What it says:* the implementation's `OP_SPLIT` computes what `Ops.Splice.split`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the
implementation (#50).

### `optPush_abs` (`lean/BsvScript/Impl/Splice.lean:79`)

**`optPush_abs`.** *What it says:* pushing an optional element, or failing, read as the spec's, is pushing the
optional list, or failing. *What it assumes:* nothing. *Why it matters:* `OP_NUM2BIN`'s last step over
`Elem.num2binM` (#143).

### `num2binOpI_abs` (`lean/BsvScript/Impl/Splice.lean:93`)

**`num2binOpI_abs`.** *What it says:* the implementation's `OP_NUM2BIN` computes what
`Ops.Splice.num2binOp` computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the
family on the implementation (#50).

### `pushMin_abs` (`lean/BsvScript/Impl/Splice.lean:103`)

**`pushMin_abs`.** *What it says:* pushing a minimal encoding, read as the spec's, is pushing it packed. *What
it assumes:* nothing. *Why it matters:* `OP_BIN2NUM`, whose range test reads the same list, computed once
(#143).

### `bin2numI_abs` (`lean/BsvScript/Impl/Splice.lean:118`)

**`bin2numI_abs`.** *What it says:* the implementation's `OP_BIN2NUM` computes what `Ops.Splice.bin2num`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the
implementation (#50).

### `execI_refines` (`lean/BsvScript/Impl/Splice.lean:133`)

**`Splice.execI_refines`.** *What it says:* the implementation's splice hook refines `Ops.Splice.exec`.
*What it assumes:* nothing. *Why it matters:* the family's part of the machine's refinement (#50).

### `execI_of_not_owns` (`lean/BsvScript/Impl/Splice.lean:153`)

**`Splice.execI_of_not_owns`.** *What it says:* the hook answers `none` for an opcode it does not own. *What
it assumes:* `owns op = false`. *Why it matters:* the machine's dispatcher (#50).

### `isSome_execI` (`lean/BsvScript/Impl/Splice.lean:161`)

**`Splice.isSome_execI`.** *What it says:* the hook answers for every opcode it owns. *What it assumes:*
`owns op = true`. *Why it matters:* the machine's dispatcher (#50).

## `BsvScript.Impl.Stack`

### `execStackI_abs` (`lean/BsvScript/Impl/Stack.lean:85`)

**`execStackI_abs`.** *What it says:* on every implementation state, the implementation's stack family
computes what `Ops.Stack.execStack` computes on the spec state it stands for: the same error, or a state that
stands for the spec's (the elements packed since #143). *What it assumes:* nothing. *Why it matters:*
`OP_PICK`/`OP_ROLL` in one index each, with the verdicts unmoved (#50, slice (b)).

### `execI_refines` (`lean/BsvScript/Impl/Stack.lean:107`)

**`Stack.execI_refines`.** *What it says:* the implementation's stack hook refines `Ops.Stack.exec`.
*What it assumes:* nothing. *Why it matters:* the family's part of the machine's refinement (#50).

### `execI_of_not_owns` (`lean/BsvScript/Impl/Stack.lean:121`)

**`Stack.execI_of_not_owns`.** *What it says:* the hook answers `none` for an opcode it does not own. *What
it assumes:* `owns op = false`. *Why it matters:* the machine's dispatcher (#50).

### `isSome_execI` (`lean/BsvScript/Impl/Stack.lean:129`)

**`Stack.isSome_execI`.** *What it says:* the hook answers for every opcode it owns. *What it assumes:*
`owns op = true`. *Why it matters:* the machine's dispatcher (#50).

## `BsvScript.Impl.State`

### `reverse_set` (`lean/BsvScript/Impl/State.lean:22`)

**`reverse_set`.** *What it says:* setting index `i` of a list and reversing is setting index
`length − 1 − i` of the reversed list. *What it assumes:* `i` is inside the list. *Why it matters:* the
implementation writes the element `k` below the top at array index `size − 1 − k` (#50).

### `reverse_eraseIdx` (`lean/BsvScript/Impl/State.lean:35`)

**`reverse_eraseIdx`.** *What it says:* erasing index `i` of a list and reversing is erasing index
`length − 1 − i` of the reversed list. *What it assumes:* `i` is inside the list. *Why it matters:* the
implementation's `OP_ROLL` erases the element `k` below the top at array index `size − 1 − k` (#50).

### `reverse_insertIdx` (`lean/BsvScript/Impl/State.lean:46`)

**`reverse_insertIdx`.** *What it says:* inserting at index `i` of a list and reversing is inserting at
index `length − i` of the reversed list. *What it assumes:* `i ≤ length`. *Why it matters:* the
implementation's `OP_TUCK` inserts `k` below the top at array index `size − k` (#50).

### `abs_ofState` (`lean/BsvScript/Impl/State.lean:101`)

**`abs_ofState`.** *What it says:* the implementation state made from a spec state whose elements are bytes
stands for it. *What it assumes:* every element of both stacks is `Bytes.valid` (a byte at or above 256 has no
packed form). *Why it matters:* the implementation loop starts from the spec's initial state.

### `ofState_abs` (`lean/BsvScript/Impl/State.lean:115`)

**`ofState_abs`.** *What it says:* reading an implementation state as the spec's and back gives it again:
`abs` loses nothing. *What it assumes:* nothing. *Why it matters:* the machine's refinement states each step
as the spec's step read back (#50).

### `abs_cond` (`lean/BsvScript/Impl/State.lean:123`)

**`abs_cond`.** *What it says:* the spec state's `cond` is the implementation's. *What it assumes:*
nothing. *Why it matters:* the conditionals' state, read by the loop's `fExec` and the flow opcodes (#50).

### `abs_alt` (`lean/BsvScript/Impl/State.lean:126`)

**`abs_alt`.** *What it says:* the spec state's `alt` is the implementation's. *What it assumes:*
nothing. *Why it matters:* the alt stack, read by the pre-Genesis depth test (#50).

### `abs_memUsed` (`lean/BsvScript/Impl/State.lean:129`)

**`abs_memUsed`.** *What it says:* the spec state's `memUsed` is the implementation's. *What it assumes:*
nothing. *Why it matters:* the memory counter, read by every push and pop (#50).

### `abs_nonTopLevelReturn` (`lean/BsvScript/Impl/State.lean:132`)

**`abs_nonTopLevelReturn`.** *What it says:* the spec state's `nonTopLevelReturn` is the implementation's. *What it assumes:*
nothing. *Why it matters:* the post-Genesis `OP_RETURN` mark, read by the loop's `fExec` (#50).

### `abs_codeSep` (`lean/BsvScript/Impl/State.lean:135`)

**`abs_codeSep`.** *What it says:* the spec state's `codeSep` is the implementation's. *What it assumes:*
nothing. *Why it matters:* the scriptCode's start, read by the signature checks (#50).

### `ofState_size` (`lean/BsvScript/Impl/State.lean:139`)

**`ofState_size`.** *What it says:* the implementation state made from a spec state has the spec's depth.
*What it assumes:* nothing. *Why it matters:* the pre-Genesis depth test after each step (#50).

### `arr_back_none` (`lean/BsvScript/Impl/State.lean:148`)

**`arr_back_none`.** *What it says:* an array with no last element reads as the empty top-first list.
*What it assumes:* `a.back? = none`. *Why it matters:* the flow opcodes' and the verdict's empty-stack cases
(#50).

### `arr_back_some` (`lean/BsvScript/Impl/State.lean:156`)

**`arr_back_some`.** *What it says:* an array whose last element is `x` reads as `x`'s bytes on top of its
`pop`. *What it assumes:* `a.back? = some x`. *Why it matters:* the flow opcodes' and the verdict's reads of the
top (#50).

### `abs_stack_of_back_none` (`lean/BsvScript/Impl/State.lean:166`)

**`abs_stack_of_back_none`.** *What it says:* an implementation state with no top stands for the empty
stack. *What it assumes:* `s.stack.back? = none`. *Why it matters:* the flow opcodes' empty-stack cases (#50).

### `abs_stack_of_back_some` (`lean/BsvScript/Impl/State.lean:171`)

**`abs_stack_of_back_some`.** *What it says:* an implementation state whose top is `x` stands for `x` on
top of its `pop`. *What it assumes:* `s.stack.back? = some x`. *Why it matters:* the flow opcodes' reads of the
top (#50).

### `topArr_eq` (`lean/BsvScript/Impl/State.lean:187`)

**`topArr_eq`.** *What it says:* the bytes of the array's element `k` below the top are the top-first list's
element `k`. *What it assumes:* nothing. *Why it matters:* `OP_PICK`'s fetch in one step (#50).

### `setTopArr_eq` (`lean/BsvScript/Impl/State.lean:206`)

**`setTopArr_eq`.** *What it says:* replacing the array's element `k` below the top is `List.set k` on
the top-first list. *What it assumes:* nothing. *Why it matters:* the swaps and rotations (#50).

### `eraseTopArr_eq` (`lean/BsvScript/Impl/State.lean:224`)

**`eraseTopArr_eq`.** *What it says:* erasing the array's element `k` below the top is
`List.eraseIdx k` on the top-first list. *What it assumes:* nothing. *Why it matters:* `OP_ROLL` (#50).

### `insertTopArr_eq` (`lean/BsvScript/Impl/State.lean:242`)

**`insertTopArr_eq`.** *What it says:* inserting `k` below the array's top is `List.insertIdx k` on the
top-first list. *What it assumes:* nothing. *Why it matters:* `OP_TUCK` (#50).

### `pushElemI_abs` (`lean/BsvScript/Impl/State.lean:266`)

**`pushElemI_abs`.** *What it says:* the implementation's push stands for the spec's push of the element's
bytes. *What it assumes:* nothing. *Why it matters:* every push of every family (#50).

### `popElemI_abs` (`lean/BsvScript/Impl/State.lean:283`)

**`popElemI_abs`.** *What it says:* the implementation's pop stands for the spec's, the popped element's
bytes the same. *What it assumes:* nothing. *Why it matters:* every pop of every family (#50).

### `topAtI_abs` (`lean/BsvScript/Impl/State.lean:301`)

**`topAtI_abs`.** *What it says:* the implementation reads the element `k` below the top that the spec
reads. *What it assumes:* nothing. *Why it matters:* `OP_PICK`'s fetch and every read below the top (#50).

### `swapTopI_abs` (`lean/BsvScript/Impl/State.lean:313`)

**`swapTopI_abs`.** *What it says:* the implementation's swap stands for the spec's. *What it assumes:*
nothing. *Why it matters:* `OP_SWAP`, `OP_ROT`, `OP_2SWAP`, `OP_2ROT` (#50).

### `eraseTopI_abs` (`lean/BsvScript/Impl/State.lean:325`)

**`eraseTopI_abs`.** *What it says:* the implementation's erase stands for the spec's, the charge
released the same. *What it assumes:* nothing. *Why it matters:* `OP_ROLL`, `OP_NIP` (#50).

### `insertTopI_abs` (`lean/BsvScript/Impl/State.lean:338`)

**`insertTopI_abs`.** *What it says:* the implementation's insert stands for the spec's, charged the
same. *What it assumes:* nothing. *Why it matters:* `OP_TUCK` (#50).

### `pushCountI_abs` (`lean/BsvScript/Impl/State.lean:354`)

**`pushCountI_abs`.** *What it says:* the implementation's count push stands for the spec's. *What it
assumes:* nothing. *Why it matters:* `OP_DEPTH`, `OP_SIZE` (#50).

### `needI_abs` (`lean/BsvScript/Impl/State.lean:369`)

**`needI_abs`.** *What it says:* the implementation's depth test answers as the spec's. *What it
assumes:* nothing. *Why it matters:* every depth test of every family, in constant time (#50).

### `depth_abs` (`lean/BsvScript/Impl/State.lean:375`)

**`depth_abs`.** *What it says:* the implementation's depth is the spec's. *What it assumes:* nothing.
*Why it matters:* `OP_DEPTH` and the pre-Genesis depth test, in constant time (#50).

### `toAltI_abs` (`lean/BsvScript/Impl/State.lean:387`)

**`toAltI_abs`.** *What it says:* the implementation's move to the alt stack stands for the spec's.
*What it assumes:* nothing. *Why it matters:* `OP_TOALTSTACK` (#50).

### `fromAltI_abs` (`lean/BsvScript/Impl/State.lean:409`)

**`fromAltI_abs`.** *What it says:* the implementation's move from the alt stack stands for the spec's.
*What it assumes:* nothing. *Why it matters:* `OP_FROMALTSTACK` (#50).

### `need_abs` (`lean/BsvScript/Impl/State.lean:422`)

**`need_abs`.** *What it says:* `needI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50).

### `topAt_abs` (`lean/BsvScript/Impl/State.lean:425`)

**`topAt_abs`.** *What it says:* `topAtI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50).

### `pushElem_abs` (`lean/BsvScript/Impl/State.lean:428`)

**`pushElem_abs`.** *What it says:* `pushElemI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50).

### `popElem_abs` (`lean/BsvScript/Impl/State.lean:432`)

**`popElem_abs`.** *What it says:* `popElemI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50).

### `swapTop_abs` (`lean/BsvScript/Impl/State.lean:436`)

**`swapTop_abs`.** *What it says:* `swapTopI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50).

### `eraseTop_abs` (`lean/BsvScript/Impl/State.lean:440`)

**`eraseTop_abs`.** *What it says:* `eraseTopI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50).

### `insertTop_abs` (`lean/BsvScript/Impl/State.lean:443`)

**`insertTop_abs`.** *What it says:* `insertTopI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50).

### `pushCount_abs` (`lean/BsvScript/Impl/State.lean:447`)

**`pushCount_abs`.** *What it says:* `pushCountI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50).

### `toAlt_abs` (`lean/BsvScript/Impl/State.lean:451`)

**`toAlt_abs`.** *What it says:* `toAltI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50).

### `fromAlt_abs` (`lean/BsvScript/Impl/State.lean:454`)

**`fromAlt_abs`.** *What it says:* `fromAltI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50).

### `length_abs` (`lean/BsvScript/Impl/State.lean:457`)

**`length_abs`.** *What it says:* `depth_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50).

### `headD_abs` (`lean/BsvScript/Impl/State.lean:461`)

**`headD_abs`.** *What it says:* the spec's read of the top with `[]` for an empty stack is the
implementation's `topAtI s 0`. *What it assumes:* nothing. *Why it matters:* `OP_NUMEQUALVERIFY`'s and the
verdict's reads of the top (#50).

### `isEmpty_abs` (`lean/BsvScript/Impl/State.lean:469`)

**`isEmpty_abs`.** *What it says:* the spec's stack is empty exactly when the array is. *What it
assumes:* nothing. *Why it matters:* `OP_CHECKMULTISIG`'s dummy test and the verdict (#50).

### `throw_bind_except` (`lean/BsvScript/Impl/State.lean:474`)

**`throw_bind_except`.** *What it says:* a failure followed by anything is the failure. *What it assumes:*
nothing. *Why it matters:* the `do` blocks' `if … then throw …` lines, whose continuation the elaborator copies
into both branches; this collapses the failing copy (#50).

### `map_throw_except` (`lean/BsvScript/Impl/State.lean:480`)

**`map_throw_except`.** *What it says:* a failure read through any function is the failure. *What it
assumes:* nothing. *Why it matters:* the families' failures, read as the spec's (#50).

### `abs_opCount` (`lean/BsvScript/Impl/State.lean:485`)

**`abs_opCount`.** *What it says:* the spec state's op count is the implementation's. *What it assumes:*
nothing. *Why it matters:* the op-count tests of the loop and of `OP_CHECKMULTISIG` (#50).

### `abs_withOpCount` (`lean/BsvScript/Impl/State.lean:489`)

**`abs_withOpCount`.** *What it says:* the spec state with its op count replaced is the implementation
state with its op count replaced, read as the spec's. *What it assumes:* nothing. *Why it matters:* the op
count's charges in the loop (`466–467`) and in `OP_CHECKMULTISIG` (`1527–1536`) (#50).

`[SRC]` `interpreter.cpp:466–467`, `interpreter.cpp:1527–1536`

### `popTail_abs` (`lean/BsvScript/Impl/State.lean:497`)

**`popTail_abs`.** *What it says:* the implementation's "pop the top and continue with the rest" stands for
the spec's `match popElem st with | .ok (_, st') => pure st' | .error e => throw e`. *What it assumes:*
nothing. *Why it matters:* the `VERIFY` forms' final pop (`OP_EQUALVERIFY`, `OP_NUMEQUALVERIFY`), closed by
`exact` against each family's own `match` (#50).

### `abs_ofExcept` (`lean/BsvScript/Impl/State.lean:531`)

**`abs_ofExcept`.** *What it says:* reading an `Except` result as a family result commutes with `abs`.
*What it assumes:* nothing. *Why it matters:* the families written with `Except` (#50).

### `dispatch_abs` (`lean/BsvScript/Impl/State.lean:556`)

**`dispatch_abs`.** *What it says:* a dispatcher that asks a family first whether it owns the opcode, and
gives the state to it alone if so, refines the spec's "try this family, else the rest". *What it assumes:* the
family answers `none` off its opcodes and some answer on them, and the rest refines the spec's rest. *Why it
matters:* the machine's hook hands its state to one family, so the array is never shared (#50).

## `BsvScript.Machine`

### `takeExact_go_eq` (`lean/BsvScript/Machine.lean:534`)

The accumulator form of `takeExact`: `none` when fewer than `k` elements remain, else the accumulator reversed followed by the first `k`.

### `takeExact_eq` (`lean/BsvScript/Machine.lean:549`)

`takeExact n l` is `l.take n` when the list has at least `n` elements, else `none`: the parser's length test (`script.h:192–193`, `body.length < n`) walked over the push's own length once.

`[SRC]` `script.h:192–193`

### `getOpTail_eq_fast` (`lean/BsvScript/Machine.lean:580`)

`@[csimp]` (#45): the compiler parses with `getOpTailFast`, which walks the push's own length (`takeExact`) instead of measuring the rest of the script for every push (the parser's wall of `docs/records/20260926-205320-ladder45-s1.md`, quadratic in pushes × script); by cases on the five shapes of the push header; nothing in the semantics moves.

### `isPushOnly_eq_fast` (`lean/BsvScript/Machine.lean:598`)

`@[csimp]`: `isPushOnly` restated after the parser's csimp lemma so its compiled code calls the fast parser; the same recursion, by `isPushOnly.induct` case by case.

### `loop_eq_fast` (`lean/BsvScript/Machine.lean:633`)

`@[csimp]`: the loop restated after the parser's csimp lemma; the same term once both recursions are unsealed (`rfl`).

### `evalScript_eq_fast` (`lean/BsvScript/Machine.lean:641`)

`@[csimp]`: `evalScript` restated after the loop's; the same term (`rfl`).

### `phase2_eq_fast` (`lean/BsvScript/Machine.lean:686`)

`@[csimp]`: `phase2` restated after `evalScript`'s and `isPushOnly`'s; the same term (`rfl`).

### `verifyScript_eq_fast` (`lean/BsvScript/Machine.lean:705`)

`@[csimp]`: `verifyScript` restated after `phase2`'s and `evalScript`'s; the same term (`rfl`), so every theorem about `verifyScript` is about the definition. A compiled call of `Machine.verifyScript` runs the fast parser and the fast number loops. Since #50 the evaluator's own compiled calls do not come here: they go through `Eval.verifyScript`, which `Eval.verifyScript_eq_I` sends to the array machine `verifyScriptI`; this lemma reaches the direct compiled calls of `Machine.verifyScript` alone (the flow leg's list-machine row, `lean/Test/FlowCheck.lean`).

### `atLeast_eq` (`lean/BsvScript/Machine.lean:725`)

**`atLeast_eq`.** *What it says:* `atLeast n l` decides `n ≤ l.length`. *What it assumes:* nothing.
*Why it matters:* it is the one fact every depth test's compiled copy rests on (#48): the copy's answer is the
definition's, and it walks at most `n` elements where `List.length` walks them all.

## `BsvScript.Numbers`

### `decode_eq_signInt` (`lean/BsvScript/Numbers.lean:174`)

`decode` restated by pattern matching: `signInt` of the reversed list's magnitude
and sign (the definition's `if` on the sign, as a match on the pair; the shape T3 and
T4 case on).

### `encode_zero` (`lean/BsvScript/Numbers.lean:342`)

**Zero.** `encode 0 = []` (`serialize`, `int_serialization.h:26–27`).

`[SRC]` `int_serialization.h:26–27`

### `decode_nil` (`lean/BsvScript/Numbers.lean:345`)

**The empty vector is zero.**

### `decode_negzero` (`lean/BsvScript/Numbers.lean:348`)

**Negative zero decodes to zero** (`deserialize` never rejects; `0x80` is
`-0 = 0`).

### `negzero_not_minimal` (`lean/BsvScript/Numbers.lean:352`)

**Negative zero is not minimal** (`IsMinimallyEncoded`, `int_serialization.h:134–137`
and, for a single byte, `int_serialization.h:144–146`: "this test also rejects the negative-zero
encoding, 0x80").

`[SRC]` `int_serialization.h:134–137`, `int_serialization.h:144–146`

### `valid_cons` (`lean/BsvScript/Numbers.lean:357`)

`Bytes.valid` on a cons: the head is below 256 and the tail is valid (the rewrite
the validity proofs below use).

### `valid_nil` (`lean/BsvScript/Numbers.lean:362`)

The empty list is valid: it has no entry to bound.

### `valid_reverse` (`lean/BsvScript/Numbers.lean:365`)

Validity ignores order: a list is valid exactly when its reverse is (the
definitions work top byte first, the statements on the forward list).

### `magBytesFuel_valid` (`lean/BsvScript/Numbers.lean:370`)

Every magnitude byte is a byte: `magBytesFuel` emits only remainders modulo 256,
at any fuel and any value.

### `leNat_magBytesFuel` (`lean/BsvScript/Numbers.lean:387`)

The magnitude bytes read back: `leNat (magBytesFuel fuel m) = m` when the fuel
covers the value (the hypothesis `m ≤ fuel`; `magBytes` runs at `fuel = m`), so the
transcription of `serialize`'s loop (`int_serialization.h:31–36`) loses no digit.

`[SRC]` `int_serialization.h:31–36`

### `beNat_reverse` (`lean/BsvScript/Numbers.lean:401`)

`beNat` of a reversed list is `leNat`.

### `beNat_zero_cons` (`lean/BsvScript/Numbers.lean:409`)

A zero top byte adds nothing to the big-endian value (a `0x00` above the
magnitude is value-free).

### `beNat_append_single` (`lean/BsvScript/Numbers.lean:414`)

One more low byte under a top-first list: the value shifts up a byte and adds it.

### `magBytes_reverse_head` (`lean/BsvScript/Numbers.lean:418`)

The reversed magnitude bytes: non-empty with a non-zero head (the top byte)
when the magnitude is non-zero (`serialize` stops at the last non-zero byte).

### `decodeRev_signTopRev` (`lean/BsvScript/Numbers.lean:440`)

Decoding undoes the sign handling: for a top byte `t` with `0 < t < 256` (the
hypotheses), `decodeRev` of `signTopRev (t :: rest) neg` is the magnitude
`beNat (t :: rest)` with the sign `neg`, whether a sign byte went above `t` or bit 7
of `t` was set (`serialize`, `int_serialization.h:48–55`, against `deserialize`,
`int_serialization.h:94–117`). The step of T1, `decode_encode`.

`[SRC]` `int_serialization.h:48–55`, `int_serialization.h:94–117`

### `decode_encode` (`lean/BsvScript/Numbers.lean:466`)

**Decoding an encoding gives the value back** (for every integer; the
canonicality theorem's easy half).

### `signTopRev_valid` (`lean/BsvScript/Numbers.lean:480`)

The sign handling keeps a valid list valid (the hypothesis `Bytes.valid bs`): it puts
`0x00` or `0x80` above a top byte with bit 7 set, or sets bit 7 of a top byte below
128 (`t + 128 < 256`). With `magBytesFuel_valid`, the step of `encode_valid`.

### `encode_valid` (`lean/BsvScript/Numbers.lean:504`)

**An encoding is made of bytes.**

### `encode_minimal` (`lean/BsvScript/Numbers.lean:512`)

**An encoding is minimal** (the canonicality theorem's second half:
`serialize` produces what `IsMinimallyEncoded` accepts, at any length bound it
fits).

### `isMinimallyEncoded_encode` (`lean/BsvScript/Numbers.lean:529`)

An encoding passes `IsMinimallyEncoded` exactly when it fits the length bound:
the structural half holds of every encoding (`encode_minimal`, T2), so only the size
test (`int_serialization.h:124–127`) can refuse it.

`[SRC]` `int_serialization.h:124–127`

### `width_127` (`lean/BsvScript/Numbers.lean:536`)

**The width boundaries**, as decided facts (this theorem heads eleven, each with
its own explainer; T6, `encode_length_le_iff`, is the general statement): the encoded
length steps up where the top magnitude byte reaches `0x80`, whose bit 7 then costs a
sign byte (`serialize`, `int_serialization.h:48–52`). Decided on both sides of the
step (the last value of the shorter length and the first of the longer): +2⁷, −2⁷,
+2¹⁵, +2³¹, +2⁶³. On one side only: −2³¹ (five bytes; the four-byte side,
−(2³¹ − 1), is not decided). On neither side: −2¹⁵ and −2⁶³. The `int64` boundary:
`INT64_SERIALIZED_SIZE` is 9 (`script_num.h:55`), and the one `int64` that needs
nine bytes is `INT64_MIN` = −2⁶³ (magnitude 2⁶³, top byte `0x80`, then the sign
byte), which T6 carries and no fact here decides; `INT64_MAX` = 2⁶³ − 1 is eight
bytes (`width_2p63m1`), and `width_2p63` decides +2⁶³, which is not an `int64`. This
theorem: 127 is one byte, `0x7f`.

`[SRC]` `int_serialization.h:48–52`, `script_num.h:55`

### `width_128` (`lean/BsvScript/Numbers.lean:549`)

128 is two bytes, `[0x80, 0x00]`: its magnitude byte `0x80` has bit 7 set, so a
sign byte follows (`int_serialization.h:48–52`); the first value past one byte.

`[SRC]` `int_serialization.h:48–52`

### `width_neg127` (`lean/BsvScript/Numbers.lean:552`)

−127 is one byte, `0xff`: the magnitude `0x7f` leaves bit 7 for the sign
(`int_serialization.h:55`).

`[SRC]` `int_serialization.h:55`

### `width_neg128` (`lean/BsvScript/Numbers.lean:555`)

−128 is two bytes, `[0x80, 0x80]`: the magnitude byte `0x80` has bit 7 set, so the
sign byte `0x80` follows (`int_serialization.h:48–52`).

`[SRC]` `int_serialization.h:48–52`

### `width_32767` (`lean/BsvScript/Numbers.lean:558`)

32767 (2¹⁵ − 1) is two bytes, `[0xff, 0x7f]`: the top byte `0x7f` leaves bit 7 for
the sign (`int_serialization.h:55`).

`[SRC]` `int_serialization.h:55`

### `width_32768` (`lean/BsvScript/Numbers.lean:561`)

32768 (2¹⁵) is three bytes, `[0x00, 0x80, 0x00]`: the top magnitude byte `0x80`
costs a sign byte (`int_serialization.h:48–52`).

`[SRC]` `int_serialization.h:48–52`

### `width_2p31m1` (`lean/BsvScript/Numbers.lean:564`)

2³¹ − 1 is four bytes, `[0xff, 0xff, 0xff, 0x7f]`: the top of the pre-Genesis
operand range `[-2^31+1, 2^31-1]` (`script_num.h:45–47`).

`[SRC]` `script_num.h:45–47`

### `width_2p31` (`lean/BsvScript/Numbers.lean:567`)

2³¹ is five bytes, `[0x00, 0x00, 0x00, 0x80, 0x00]`: the top magnitude byte `0x80`
costs a sign byte (`int_serialization.h:48–52`), so 2³¹ is past the pre-Genesis
four-byte operands.

`[SRC]` `int_serialization.h:48–52`

### `width_neg2p31` (`lean/BsvScript/Numbers.lean:571`)

−2³¹ is five bytes, `[0x00, 0x00, 0x00, 0x80, 0x80]`: the top magnitude byte `0x80`
costs the sign byte `0x80` (`int_serialization.h:48–52`). The four-byte side of this
step, −(2³¹ − 1), is not decided here (T6 carries it).

`[SRC]` `int_serialization.h:48–52`

### `width_2p63m1` (`lean/BsvScript/Numbers.lean:575`)

2⁶³ − 1, `INT64_MAX`, is eight bytes: the top byte `0x7f` leaves bit 7 for the sign
(`int_serialization.h:55`).

`[SRC]` `int_serialization.h:55`

### `width_2p63` (`lean/BsvScript/Numbers.lean:578`)

2⁶³ is nine bytes: seven zero bytes, the top magnitude byte `0x80`, then the sign
byte `0x00` (`int_serialization.h:48–52`). 2⁶³ is not an `int64`: the nine-byte
`int64` is `INT64_MIN` = −2⁶³ (`INT64_SERIALIZED_SIZE`, `script_num.h:55`), which T6
carries and no fact here decides.

`[SRC]` `int_serialization.h:48–52`, `script_num.h:55`

### `vec_1` (`lean/BsvScript/Numbers.lean:584`)

**The reference vectors** the predecessor's fuzz asserts (`harness/src/gen.rs`,
`enc_num_vectors`: nine vectors). Five are decided here as byte equalities of the
spec's encoder, this theorem and the four after it (1, −1, 255, 256, −255); the zero
vector is `encode_zero`; 127, 128 and −128 are decided only as lengths (`width_127`,
`width_128`, `width_neg128`). This theorem: 1 is `[0x01]`
(`int_serialization.h:55`).

`[SRC]` `int_serialization.h:55`

### `vec_neg1` (`lean/BsvScript/Numbers.lean:591`)

−1 is `[0x81]`: the magnitude 1 with the sign bit set on its one byte
(`int_serialization.h:55`).

`[SRC]` `int_serialization.h:55`

### `vec_255` (`lean/BsvScript/Numbers.lean:594`)

255 is `[0xff, 0x00]`: the magnitude byte `0xff` has bit 7 set, so a zero sign
byte follows (`int_serialization.h:48–52`); the positive case of
`IsMinimallyEncoded`'s exception (`int_serialization.h:139–144`).

`[SRC]` `int_serialization.h:48–52`, `int_serialization.h:139–144`

### `vec_256` (`lean/BsvScript/Numbers.lean:598`)

256 is `[0x00, 0x01]`: two magnitude bytes, low first, the top byte `0x01` below
`0x80` carrying the clear sign bit (`int_serialization.h:31–36`, `:55`).

`[SRC]` `int_serialization.h:31–36`, `int_serialization.h:55`

### `vec_neg255` (`lean/BsvScript/Numbers.lean:601`)

−255 is `[0xff, 0x80]`: the magnitude byte `0xff` has bit 7 set, so the sign byte
`0x80` follows (`int_serialization.h:48–52`); the negative case of
`IsMinimallyEncoded`'s exception (`int_serialization.h:139–144`).

`[SRC]` `int_serialization.h:48–52`, `int_serialization.h:139–144`

### `castToBool_iff_beNat` (`lean/BsvScript/Numbers.lean:606`)

The forward truthiness test against the magnitude: `CastToBool` is true iff
some byte is non-zero other than a lone sign bit in the last byte, which is
exactly "the magnitude, top byte masked, is non-zero" (on bytes).

### `castToBool_eq` (`lean/BsvScript/Numbers.lean:641`)

**T5, truthiness is non-zeroness**: `CastToBool` (`119–130`) is true exactly when
the decoded value is non-zero (so negative zero and every all-zero vector are false).
*What it assumes:* `Bytes.valid bs`, every entry below 256 (the byte type is `Nat`;
`[256]` is true to `castToBool` but decodes to 0).

`[SRC]` `interpreter.cpp:119–130`

### `magBytesFuel_fuel_irrel` (`lean/BsvScript/Numbers.lean:659`)

`magBytesFuel` does not depend on the fuel once the fuel covers the value.

### `magBytes_cons` (`lean/BsvScript/Numbers.lean:679`)

The recursion of `magBytes` itself (`serialize`, `int_serialization.h:31–36`): the low byte, then
the bytes of the quotient.

`[SRC]` `int_serialization.h:31–36`

### `magBytes_zero` (`lean/BsvScript/Numbers.lean:689`)

Zero has no magnitude bytes (`serialize`'s loop, `int_serialization.h:31–36`, runs
while the magnitude is non-zero).

`[SRC]` `int_serialization.h:31–36`

### `magBytes_valid` (`lean/BsvScript/Numbers.lean:693`)

Every byte of `magBytes m` is below 256 (`magBytesFuel_valid` at `fuel = m`).

### `leNat_magBytes` (`lean/BsvScript/Numbers.lean:696`)

A magnitude's bytes read back little-endian give the magnitude, for every `m`
(`leNat_magBytesFuel` at `fuel = m`); the converse, on valid lists (`Bytes.valid`) with a
non-zero top byte, is `magBytes_leNat`.

### `magBytes_length_le` (`lean/BsvScript/Numbers.lean:701`)

`magBytes` is bounded by the value's size: `m < 256^k` gives at most `k` bytes.

### `lastNZ_append_single` (`lean/BsvScript/Numbers.lean:722`)

`lastNZ` reads the last byte only: `lastNZ (l ++ [t])` is `t ≠ 0`, whatever `l`.

### `leNat_pos_of_lastNZ` (`lean/BsvScript/Numbers.lean:731`)

A list whose last (top) byte is non-zero has a positive little-endian value.

### `magBytes_leNat` (`lean/BsvScript/Numbers.lean:743`)

**`magBytes` inverts `leNat`** on byte lists with a non-zero top byte: the
little-endian digits of a number are unique (`serialize`, `int_serialization.h:31–36`,
against `deserialize`, `int_serialization.h:86–92`).

`[SRC]` `int_serialization.h:31–36`, `int_serialization.h:86–92`

### `magBytes_beNat_reverse` (`lean/BsvScript/Numbers.lean:764`)

The reversed form: `magBytes (beNat (t :: rest))` reversed is `t :: rest` when
the top byte is non-zero and the list is valid (`Bytes.valid`, the hypothesis `hv`).

### `encode_ofNat` (`lean/BsvScript/Numbers.lean:773`)

`encode` of a non-zero natural `m` (the hypothesis `m ≠ 0`): the reversed magnitude
bytes under the positive sign handling (`signTopRev … false`), reversed back.

### `encode_negOfNat` (`lean/BsvScript/Numbers.lean:780`)

`encode` of `-m` for a non-zero natural `m`: the same magnitude bytes under the
negative sign handling (`signTopRev … true`), reversed back.

### `beNat_leading_zeros` (`lean/BsvScript/Numbers.lean:788`)

`beNat` of a list of zero bytes in front of `l` is `beNat l`.

### `beNat_pos_of_top` (`lean/BsvScript/Numbers.lean:798`)

A top-first list with a non-zero top byte has a non-zero big-endian value (no
validity needed: the top byte alone contributes `t * 256 ^ rest.length`).

### `encode_beNat_pos` (`lean/BsvScript/Numbers.lean:805`)

The encoding of `beNat (t :: rest)` for a top-first list with a non-zero top byte
`t` and every entry a byte (the hypotheses): `signTopRev (t :: rest) false`, reversed
back; the negation is `encode_beNat_neg`.

### `encode_beNat_neg` (`lean/BsvScript/Numbers.lean:812`)

The encoding of `-(beNat (t :: rest))` under the same hypotheses:
`signTopRev (t :: rest) true`, reversed back. With `encode_beNat_pos`, the step T3 and
T4 rest on.

### `encode_decode_of_minimal` (`lean/BsvScript/Numbers.lean:819`)

**T3, canonicality**: a minimal encoding is the encoding of its value
(`IsMinimallyEncoded`, `int_serialization.h:120–152`, accepts exactly `serialize`'s
outputs; with `encode_minimal` this is the bijection between values and minimal byte
lists). *What it assumes:* `Bytes.valid b`, every entry below 256 (the byte type is
`Nat`; `[257]` has a minimal tail and decodes to −1, which encodes as `[0x81]`).

`[SRC]` `int_serialization.h:120–152`

### `dropZeros_spec` (`lean/BsvScript/Numbers.lean:868`)

The zero-dropping recursion of `minimallyEncodeRef`: what it drops is zeros,
and what it keeps starts with a non-zero byte or is empty.

### `minimallyEncodeRef_eq` (`lean/BsvScript/Numbers.lean:893`)

**T4, the reference algorithm is the canonical re-encoding**: `MinimallyEncode`
(`int_serialization.h:154–208`, transcribed as `minimallyEncodeRef`) computes
`encode (decode b)` on every list of bytes (so `OP_BIN2NUM` (`1786`) and
`OP_NUM2BIN`'s first step (`1760`) are re-encodings). *What it assumes:*
`Bytes.valid b`, every entry below 256 (the byte type is `Nat`; `[257]` is left
unchanged by `minimallyEncodeRef` and re-encodes to `[0x81]`). That bsv-rs's
decode-then-encode agrees with it is not this theorem's: the property check
`lean/Test/NumbersCheck.lean` compares the two over `corpus/numbers/`, at the
pinned release.

`[SRC]` `int_serialization.h:154–208`, `interpreter.cpp:1786`, `interpreter.cpp:1760`

### `minimallyEncodeRef_eq_minimallyEncode` (`lean/BsvScript/Numbers.lean:962`)

T4 in the spec's own names: `minimallyEncodeRef b = minimallyEncode b` on bytes
(`Bytes.valid b`), `minimallyEncode` being defined as `encode (decode b)`: the
function the opcodes run is the reference's algorithm as transcribed. (Named
`minimallyEncodeRef_eq'` until lean #32's second lens: the axiom checker's parser reads no
primed name, finding C-10.)

### `foldl_beNat_acc` (`lean/BsvScript/Numbers.lean:970`)

The fold with an accumulator: the accumulator scales by 256 per byte.

### `beNat_cons` (`lean/BsvScript/Numbers.lean:980`)

The big-endian value of a top-first list: the top byte times `256 ^ rest.length`
plus the value of the rest (the unfolding `beNat_lt` and T6 use).

### `beNat_lt` (`lean/BsvScript/Numbers.lean:986`)

`beNat` is bounded by the size of the list.

### `encode_length_eq` (`lean/BsvScript/Numbers.lean:1001`)

The encoded length of a non-zero value: the magnitude's bytes plus one when
the top byte has bit 7 set (`serialize`, `int_serialization.h:48–52`).

`[SRC]` `int_serialization.h:48–52`

### `encode_length_le_iff` (`lean/BsvScript/Numbers.lean:1013`)

**T6, the width lemma**: an integer encodes in at most `n` bytes exactly when its
magnitude is below `2^(8n−1)` (the top byte's bit 7 costs a sign byte). `n = 4` is
the pre-Genesis operand range `[-2^31+1, 2^31-1]` (`script_num.h:44–53`).
*What it assumes:* `1 ≤ n` (the hypothesis `hn`: at `n = 0` the natural-number
`n - 1` is 0, the right side reads `|z| < 128`, and the equivalence fails at
`z = 1`).

`[SRC]` `script_num.h:44–53`

### `encode_length_le_iff_pow` (`lean/BsvScript/Numbers.lean:1091`)

The general width lemma in the reference's phrasing: `2^(8n−1)`.

### `encode_length_le_four_iff` (`lean/BsvScript/Numbers.lean:1100`)

The pre-Genesis operand range: four bytes hold exactly `|z| ≤ 2^31 − 1`.

### `num2bin_none_iff` (`lean/BsvScript/Numbers.lean:1106`)

**T7, the failure**: `num2bin` refuses (`none`: `OP_NUM2BIN`'s
`SCRIPT_ERR_IMPOSSIBLE_ENCODING`, `1761–1763`) exactly when the width is below the
length of the minimal encoding.

`[SRC]` `interpreter.cpp:1761–1763`

### `num2binPad_length` (`lean/BsvScript/Numbers.lean:1117`)

The padding reaches the width exactly: for `m` shorter than `w` (the hypothesis),
`num2binPad m w` has `w` bytes (`padRight` resizes to the width,
`limitedstack.cpp:60–71`).

`[SRC]` `limitedstack.cpp:60–71`

### `num2bin_length` (`lean/BsvScript/Numbers.lean:1130`)

**T7, the length**: a result of `num2bin` has exactly the requested width (equal:
unchanged, `1767–1769`; shorter: padded, `1771–1777`), as `OP_NUM2BIN` pushes it.

`[SRC]` `interpreter.cpp:1767–1769`, `interpreter.cpp:1771–1777`

### `decode_num2binPad` (`lean/BsvScript/Numbers.lean:1139`)

The padding keeps the value (the sign-bit move `1771–1777` and `padRight`).

`[SRC]` `interpreter.cpp:1771–1777`

### `num2bin_decode` (`lean/BsvScript/Numbers.lean:1169`)

**T7, the value**: a result of `num2bin` decodes to the input's value: the minimal
encoding keeps it (T1, `decode_encode`) and the padding keeps it (`decode_num2binPad`,
the sign-bit move `1771–1777`), so `OP_NUM2BIN`, when it succeeds, changes the width
and never the number.

`[SRC]` `interpreter.cpp:1771–1777`

### `deserializeInt64_eq_decode` (`lean/BsvScript/Numbers.lean:1183`)

Up to eight bytes the active reader agrees with sign-magnitude, including
negative zero. [SRC] `6504a3af`, `int_serialization.h:75–107`, `int_serialization.h:117`.

`[SRC]` `int_serialization.h:75–107`, `int_serialization.h:117`

### `readNumInt64_eq_readNum` (`lean/BsvScript/Numbers.lean:1189`)

At most eight bytes also preserve the constructor's width and minimality
errors. [SRC] `6504a3af`, `script_num.cpp:62–87`.

`[SRC]` `script_num.cpp:62–87`

### `deserializeInt64_long` (`lean/BsvScript/Numbers.lean:1196`)

Ten bytes and above always refuse at v1.2.3. [SRC] `6504a3af`, `int_serialization.h:80–81`.

`[SRC]` `int_serialization.h:80–81`

### `deserializeInt64_nine` (`lean/BsvScript/Numbers.lean:1201`)

At nine bytes the lower eight give the magnitude and the last byte supplies
only the sign. [SRC] `6504a3af`, `int_serialization.h:83–117`.

`[SRC]` `int_serialization.h:83–117`

### `deserializeInt64_isSome_iff` (`lean/BsvScript/Numbers.lean:1207`)

Exact acceptance at v1.2.3: short operands, or nine bytes with a pure sign
and a magnitude representable with that sign. [SRC] `6504a3af`,
`int_serialization.h:75–117`. Byte validity is needed for correspondence with
C++ bytes, not for this equality of the model's acceptance conditions.

`[SRC]` `int_serialization.h:75–117`

### `deserializeInt64_nine_magnitude_bits` (`lean/BsvScript/Numbers.lean:1225`)

A ninth byte carrying magnitude bits is refused even when the lower eight
bytes denote zero. [SRC] `6504a3af`, `int_serialization.h:83–84`.

`[SRC]` `int_serialization.h:83–84`

### `leNat_inj_of_length_eq` (`lean/BsvScript/Numbers.lean:1232`)

Fixed-length valid little-endian digits are unique, including zero padding.
This supplies byte uniqueness for the signed minimum without assuming minimal encoding.

### `deserializeInt64_nine_min_iff` (`lean/BsvScript/Numbers.lean:1250`)

At nine bytes the only encoding of the signed minimum is seven zero bytes,
`0x80`, then a negative sign byte `0x80`. [SRC] `6504a3af`,
`int_serialization.h:110–114`. The hypotheses say these are eight actual bytes
and an actual sign byte; no minimality assumption is imposed.

`[SRC]` `int_serialization.h:110–114`

### `decode_natAbs_lt_int64_of_short` (`lean/BsvScript/Numbers.lean:1273`)

A valid sign-magnitude operand of at most eight bytes has magnitude strictly
below 2^63. [SRC] `6504a3af`, `int_serialization.h:94–107`: the top bit is sign.
Thus the signed minimum cannot be encoded without the extra sign byte.

`[SRC]` `int_serialization.h:94–107`

### `deserializeInt64_min_iff` (`lean/BsvScript/Numbers.lean:1301`)

Over actual byte strings the signed minimum has exactly one accepted
encoding at v1.2.3. Short operands cannot reach its magnitude, and the ninth
byte must be the negative sign. [SRC] `6504a3af`, `int_serialization.h:80–117`.

`[SRC]` `int_serialization.h:80–117`

### `readNumInt64_of_none` (`lean/BsvScript/Numbers.lean:1338`)

A conversion failure is an overflow error when minimality does not already
refuse. A width failure has the same error. [SRC] `6504a3af`,
`script_num.cpp:62–87`; this states the constructor's error precedence.

`[SRC]` `script_num.cpp:62–87`

### `beNat_append` (`lean/BsvScript/Numbers.lean:1366`)

`beNat` of two halves is the high half shifted by the low half's width plus the low half (`foldl_beNat_acc`): the split rule the halving implementation of #45 rests on.

### `beNatLimbs_eq` (`lean/BsvScript/Numbers.lean:1383`)

**`beNatLimbs_eq`.** *What it says:* the limb fold from `(acc, cur, cnt)` is `acc * 256 ^ cnt + cur` shifted by
the list's width plus the list's `beNat`, whatever `cnt` (the test on it chooses only when a limb joins the
accumulator). *What it assumes:* nothing. *Why it matters:* from `(0, 0, 0)` it is `beNat` itself, the leaf
`beNatFast` runs (#53); by `beNat_cons` at each byte.

### `beNatFast_eq` (`lean/BsvScript/Numbers.lean:1409`)

The halving `beNatFast` computes the fold `beNat`: its leaves by `beNatLimbs_eq` (#53), its splits by `beNat_append`; the definition stays the semantics, the halving over limbs is its compiled implementation.

### `beNat_eq_fast` (`lean/BsvScript/Numbers.lean:1419`)

`@[csimp]` (#45): the compiler evaluates `beNat` as `beNatFast` in code compiled after this lemma (a csimp lemma does not reach code compiled before it: `decodeRev` is restated below for that reason, and `deserializeInt64`, whose folds read at most eight bytes at a time, has no copy), a linear number of operations at logarithmic depth (leaves of at most 256 bytes by the limb fold `beNatLimbs`, a big-number shift-add per 7 bytes since #53, joined by halves) instead of one multiplication per byte on a growing accumulator (the decode walls of `docs/records/20260926-205320-ladder45-s1.md` and `docs/records/20260929-072759-impl-50-s1.md`); nothing in the semantics moves, every theorem of this file is about `beNat`.

### `fixedLE_length` (`lean/BsvScript/Numbers.lean:1427`)

`fixedLE k m` has exactly `k` bytes, whatever `m`.

### `fixedLE_valid` (`lean/BsvScript/Numbers.lean:1433`)

Every byte of `fixedLE k m` is below 256 (`Bytes.valid`), each being a remainder modulo 256.

### `leNat_fixedLE` (`lean/BsvScript/Numbers.lean:1439`)

`fixedLE` is the fixed-width little-endian encoding of its value: `leNat` reads back `m` when `m < 256^k`.

### `leNat_append` (`lean/BsvScript/Numbers.lean:1448`)

The little-endian value of two halves: the low half's value plus the high half's value shifted by the low half's width.

### `fixedLE_split` (`lean/BsvScript/Numbers.lean:1454`)

The fixed-width bytes split at any width: the low `a` bytes of `m mod 256^a`, then the `b` bytes of the quotient `m / 256^a`.

### `fixedLE_mod` (`lean/BsvScript/Numbers.lean:1466`)

**`fixedLE_mod`.** *What it says:* the `k` low bytes of a number are the `k` bytes of its remainder modulo
`256^k`. *What it assumes:* nothing. *Why it matters:* a limb's bytes are computed on its remainder, a scalar,
never on the whole number (#53).

### `mod56` (`lean/BsvScript/Numbers.lean:1478`)

**`mod56`.** *What it says:* the remainder modulo `1 <<< 56` is the remainder modulo `256^7`. *What it
assumes:* nothing. *Why it matters:* a limb is cut by a remainder whose modulus is one shift, a primitive, with no
literal of `2^32` or more, which would compile to a string conversion at each use (#53).

### `two_pow_le_of_log2` (`lean/BsvScript/Numbers.lean:1485`)

**`two_pow_le_of_log2`.** *What it says:* a number whose `log2` is at least `k`, for `k` positive, is at least
`2^k`. *What it assumes:* `0 < k` and `¬ m.log2 < k`. *Why it matters:* `magBytesFast` tests a size by `Nat.log2`,
a primitive, where a test against `2^k` would build that number at each call (#53).

### `shift56` (`lean/BsvScript/Numbers.lean:1494`)

**`shift56`.** *What it says:* the shift right by 56 bits is the quotient by `256^7`. *What it assumes:*
nothing. *Why it matters:* the next limb is reached by one shift, a primitive, not a division (#53).

### `fixedLELimbs_eq` (`lean/BsvScript/Numbers.lean:1508`)

**`fixedLELimbs_eq`.** *What it says:* the limb form computes `fixedLE`. *What it assumes:* nothing. *Why it
matters:* the leaf `fixedLEFast` runs (#53); by `fixedLE_mod`, `mod56`, `shift56` and `fixedLE_split` at 7.

### `fixedLEFast_eq` (`lean/BsvScript/Numbers.lean:1526`)

The halving `fixedLEFast` computes `fixedLE` (widths of at most 256 bytes by `fixedLELimbs_eq`, longer ones by `fixedLE_split` at the middle).

### `splitWidth_le` (`lean/BsvScript/Numbers.lean:1537`)

For a number of at least 257 bits (the hypothesis `2 ^ 256 ≤ m`) the split point `splitWidth m` (half its byte count, from `Nat.log2`) is at least one byte and `256^(splitWidth m) ≤ m`, so the quotient at the split is non-zero and strictly smaller: the measure of `magBytesFast`'s recursion.

### `magBytes_split` (`lean/BsvScript/Numbers.lean:1547`)

The minimal magnitude bytes split at `256^k` when the quotient is non-zero: the low `k` bytes at fixed width, then the minimal bytes of the quotient (the digits of a magnitude are unique, `magBytes_leNat`).

### `magBytesFast_eq` (`lean/BsvScript/Numbers.lean:1581`)

The limb and halving `magBytesFast` computes `magBytes`: below `2^56` by the direct recursion, below `2^2048` by `magBytes_split` at 7 bytes with `mod56` and `shift56` (#53), larger numbers by `magBytes_split` at `splitWidth`.

### `magBytes_eq_fast` (`lean/BsvScript/Numbers.lean:1594`)

`@[csimp]` (#45, #53): the compiler evaluates `magBytes` as `magBytesFast` in code compiled after this lemma (the encode walls: `magBytesFuel` does one bignum division, one remainder and one predecessor per byte with the number itself as fuel; #45's ladder record's 4.743 GB at 50 KB, `docs/records/20260926-205320-ladder45-s1.md`, is the decode and the encode together, its `number` entry reading and writing one 50 KB number, and #50's record finds the fuel's predecessor alone in 427 of a 2 MB lock's 1,819 samples, `docs/records/20260929-072759-impl-50-s1.md`); since #53 the fuel runs on scalars only; nothing in the semantics moves.

### `decodeRev_eq_fast` (`lean/BsvScript/Numbers.lean:1602`)

`@[csimp]`: `decodeRev` restated after `beNat`'s csimp lemma so its compiled code calls the fast leaf (a csimp lemma applies only to code compiled after it); the same term, `rfl` per case.

### `decode_eq_fast` (`lean/BsvScript/Numbers.lean:1610`)

`@[csimp]`: `decode` restated after the csimp lemmas of what it calls; the same term (`rfl`).

### `encode_eq_fast` (`lean/BsvScript/Numbers.lean:1616`)

`@[csimp]`: `encode` restated after `magBytes`'s csimp lemma; the same term (`rfl`).

### `minimallyEncode_eq_fast` (`lean/BsvScript/Numbers.lean:1621`)

`@[csimp]`: `minimallyEncode` restated after `encode`'s and `decode`'s; the same term (`rfl`).

### `num2bin_eq_fast` (`lean/BsvScript/Numbers.lean:1629`)

`@[csimp]`: `num2bin` restated after `minimallyEncode`'s; the same term (`rfl`), so `OP_NUM2BIN` on a large element runs the fast leaves too.

## `BsvScript.Ops.Arith`

### `unary_eq_fast` (`lean/BsvScript/Ops/Arith.lean:100`)

`@[csimp]` (#48): the compiler runs `unaryFast`, whose depth test walks at most 1 element of the stack (`Machine.atLeast_eq`) where `unary`'s `st.stack.length < 1` measures it whole; nothing in the semantics moves, every theorem about `unary` is about the definition.

### `binary_eq_fast` (`lean/BsvScript/Ops/Arith.lean:177`)

`@[csimp]` (#48): the compiler runs `binaryFast`, whose depth test walks at most 2 elements of the stack (`Machine.atLeast_eq`) where `binary`'s `st.stack.length < 2` measures it whole; nothing in the semantics moves, every theorem about `binary` is about the definition.

### `within_eq_fast` (`lean/BsvScript/Ops/Arith.lean:213`)

`@[csimp]` (#48): the compiler runs `withinFast`, whose depth test walks at most 3 elements of the stack (`Machine.atLeast_eq`) where `within`'s `st.stack.length < 3` measures it whole; nothing in the semantics moves, every theorem about `within` is about the definition.

### `binaryValue_div_zero` (`lean/BsvScript/Ops/Arith.lean:246`)

T-A1: `OP_DIV` by zero is its dedicated error, `SCRIPT_ERR_DIV_BY_ZERO`, whatever the dividend
(`1318–1319`).

`[SRC]` `interpreter.cpp:1318–1319`

### `binaryValue_mod_zero` (`lean/BsvScript/Ops/Arith.lean:250`)

T-A1: `OP_MOD` by zero is its dedicated error, `SCRIPT_ERR_MOD_BY_ZERO`, whatever the dividend
(`1326–1327`).

`[SRC]` `interpreter.cpp:1326–1327`

### `readOperand_length_le` (`lean/BsvScript/Ops/Arith.lean:255`)

T-A2: an operand the read accepts is no longer than the number width in force,
`maxScriptNumLength` (the test `script_num.cpp:62–65`). As `NodeConfig.limitsFor` sets that width, it is
4 bytes for a pre-Genesis UTXO (`consensus.h:62`); post-Genesis the consensus width of the UTXO's era on the
block path (750,000 bytes, 32,000,000 post-Chronicle, `:64`, `:66`), and on the mempool path the node's
policy setting `-maxscriptnumlengthpolicy` (default 10,000, `policy.h:156`; 0 falls back to the consensus
width, `configscriptpolicy.cpp:97–106`).

`[SRC]` `script_num.cpp:62–65`, `consensus.h:62`, `consensus.h:64`, `consensus.h:66`, `policy.h:156`, `configscriptpolicy.cpp:97–106`

## `BsvScript.Ops.Bitwise`

### `bitwise2_eq_fast` (`lean/BsvScript/Ops/Bitwise.lean:71`)

`@[csimp]` (#48): the compiler runs `bitwise2Fast`, whose depth test walks at most 2 elements of the stack (`Machine.atLeast_eq`) where `bitwise2`'s `st.stack.length < 2` measures it whole; nothing in the semantics moves, every theorem about `bitwise2` is about the definition.

### `invert_eq_fast` (`lean/BsvScript/Ops/Bitwise.lean:95`)

`@[csimp]` (#48): the compiler runs `invertFast`, whose depth test walks at most 1 element of the stack (`Machine.atLeast_eq`) where `invert`'s `st.stack.length < 1` measures it whole; nothing in the semantics moves, every theorem about `invert` is about the definition.

### `shift_eq_fast` (`lean/BsvScript/Ops/Bitwise.lean:137`)

`@[csimp]` (#48): the compiler runs `shiftFast`, whose depth test walks at most 2 elements of the stack (`Machine.atLeast_eq`) where `shift`'s `st.stack.length < 2` measures it whole; nothing in the semantics moves, every theorem about `shift` is about the definition.

### `equal_eq_fast` (`lean/BsvScript/Ops/Bitwise.lean:181`)

`@[csimp]` (#48): the compiler runs `equalFast`, whose depth test walks at most 2 elements of the stack (`Machine.atLeast_eq`) where `equal`'s `st.stack.length < 2` measures it whole; nothing in the semantics moves, every theorem about `equal` is about the definition.

### `rshift_length` (`lean/BsvScript/Ops/Bitwise.lean:208`)

T-B1: the right shift preserves the width (`RShift`'s `result(x.size(), 0x00)`, `72`).

`[SRC]` `interpreter.cpp:72`

### `lshift_length` (`lean/BsvScript/Ops/Bitwise.lean:211`)

T-B1: the left shift preserves the width (`LShift`'s `result(x.size(), 0x00)`, `98`).

`[SRC]` `interpreter.cpp:98`

### `shift_zero_of_wide` (`lean/BsvScript/Ops/Bitwise.lean:215`)

T-B2: a shift by at least eight times the width is zeros in both helpers: every source byte then lies
outside the vector, so each bounds test fails (the reference's `RShift`/`LShift` likewise write nothing into
their zeroed result, `72`, `75`, `81`, `98`, `102`). The opcodes test such a count and fill the zeros
themselves (`1137–1138`, `1171–1172`; `shift` has the same test), so this says that shortcut and the shift
it skips agree.

`[SRC]` `interpreter.cpp:72`, `interpreter.cpp:75`, `interpreter.cpp:81`, `interpreter.cpp:98`, `interpreter.cpp:102`, `interpreter.cpp:1137–1138`, `interpreter.cpp:1171–1172`

## `BsvScript.Ops.Crypto`

### `isValidSignatureEncoding_length` (`lean/BsvScript/Ops/Crypto.lean:252`)

T-C1: a strictly encoded signature is 9 to 73 bytes (`193–194`).

`[SRC]` `interpreter.cpp:193–194`

### `checkSignatureEncoding_empty` (`lean/BsvScript/Ops/Crypto.lean:263`)

T-C2: the empty signature passes the encoding check (`272–273`).

`[SRC]` `interpreter.cpp:272–273`

## `BsvScript.Ops.Expansion`

### `readInt64Operand_of_none` (`lean/BsvScript/Ops/Expansion.lean:45`)

A failed fixed-width conversion produces a defined overflow refusal, provided
minimality has not refused earlier. [SRC] `6504a3af`, `script_num.cpp:62–87`,
`interpreter.cpp:1807–1809`.

`[SRC]` `script_num.cpp:62–87`, `interpreter.cpp:1807–1809`

### `substr_eq_fast` (`lean/BsvScript/Ops/Expansion.lean:103`)

`@[csimp]` (#48): the compiler runs `substrFast`, whose depth test walks at most 3 elements of the stack (`Machine.atLeast_eq`) where `substr`'s `st.stack.length < 3` measures it whole; nothing in the semantics moves, every theorem about `substr` is about the definition.

### `left_eq_fast` (`lean/BsvScript/Ops/Expansion.lean:149`)

`@[csimp]` (#48): the compiler runs `leftFast`, whose depth test walks at most 2 elements of the stack (`Machine.atLeast_eq`) where `left`'s `st.stack.length < 2` measures it whole; nothing in the semantics moves, every theorem about `left` is about the definition.

### `right_eq_fast` (`lean/BsvScript/Ops/Expansion.lean:194`)

`@[csimp]` (#48): the compiler runs `rightFast`, whose depth test walks at most 2 elements of the stack (`Machine.atLeast_eq`) where `right`'s `st.stack.length < 2` measures it whole; nothing in the semantics moves, every theorem about `right` is about the definition.

### `lshiftnum_eq_fast` (`lean/BsvScript/Ops/Expansion.lean:265`)

`@[csimp]` (#48): the compiler runs `lshiftnumFast`, whose depth test walks at most 2 elements of the stack (`Machine.atLeast_eq`) where `lshiftnum`'s `st.stack.length < 2` measures it whole; nothing in the semantics moves, every theorem about `lshiftnum` is about the definition.

### `rshiftnum_eq_fast` (`lean/BsvScript/Ops/Expansion.lean:320`)

`@[csimp]` (#48): the compiler runs `rshiftnumFast`, whose depth test walks at most 2 elements of the stack (`Machine.atLeast_eq`) where `rshiftnum`'s `st.stack.length < 2` measures it whole; nothing in the semantics moves, every theorem about `rshiftnum` is about the definition.

## `BsvScript.Ops.Splice`

### `invalidSplitPosition_eq_false` (`lean/BsvScript/Ops/Splice.lean:41`)

The split guard admits exactly the nonnegative positions bounded by both
`INT32_MAX` and the element length. [SRC] `6504a3af`, `interpreter.cpp:1718–1719`.
Testing this predicate needs no allocation of a multi-gigabyte element.

`[SRC]` `interpreter.cpp:1718–1719`

### `split_halves` (`lean/BsvScript/Ops/Splice.lean:126`)

T-SP1: the two halves `OP_SPLIT` builds, `data.take n` and `data.drop n` (`n1` and `n2`, `1726–1727`),
reassemble the element. This is the list fact alone, Lean core's `List.take_append_drop` under the spec's
name: it names no opcode and no state. The statement at the opcode is W4 `split_ok`
(`Properties/Widths.lean`).

`[SRC]` `interpreter.cpp:1726–1727`

## `BsvScript.Ops.Stack`

### `need_eq_fast` (`lean/BsvScript/Ops/Stack.lean:61`)

`@[csimp]` (#48): the compiler runs `needFast`, which walks at most `n` elements of the stack
(`Machine.atLeast_eq`) where `need`'s `st.stack.length < n` measures it whole: every compiled caller of `need`
declared after this lemma (`toAlt`, `execStack`, the splice and crypto families) runs it; nothing in the
semantics moves, every theorem about `need` is about the definition.

### `pickBound_eq` (`lean/BsvScript/Ops/Stack.lean:223`)

**`pickBound_eq`.** *What it says:* `OP_PICK`/`OP_ROLL`'s refusal test, a negative index or an index at or
past the depth, reads the same as "negative, or the stack has no element at that index". *What it assumes:*
nothing. *Why it matters:* it lets `execStackFast` decide the bound and fetch the element in one walk to the
picked depth, where the definition measures the whole stack first (#48).

### `execStack_eq_fast` (`lean/BsvScript/Ops/Stack.lean:239`)

`@[csimp]` (#48): the compiler runs `execStackFast`, whose `OP_PICK`/`OP_ROLL` bound and fetch share one walk
to the picked depth (`pickBound_eq`, with `topAt`'s `getD` read as the same lookup) and whose depth tests run
`needFast`; nothing in the semantics moves, every theorem about `execStack` is about the definition.

### `swapTop_length` (`lean/BsvScript/Ops/Stack.lean:259`)

T-S1: a swap keeps the depth (`swapElements`, `limitedstack.cpp:285–288`).

`[SRC]` `limitedstack.cpp:285–288`

### `eraseTop_length` (`lean/BsvScript/Ops/Stack.lean:263`)

T-S2: an erase below the top removes one element (`erase`, `limitedstack.cpp:260–267`).

`[SRC]` `limitedstack.cpp:260–267`

## `BsvScript.Properties.Basic`

### `verifyScript_congr` (`lean/BsvScript/Properties/Basic.lean:23`)

**P3, the main form.** *What it says:* `verifyScript` reads the flag word only
through six projections: `valid` of the word, and, of the FORKID-adjusted word,
the version-gated word (`Flags.gate`), `strictDer`, `utxoEra`, `p2shCopy` and
`cleanStackDemand`; two parameter records that agree on the limits and on those
six verify every spend identically. *What it assumes:* nothing beyond the six
equalities. *Why it matters:* it is the whole flag-word dependence of the
semantics in one place; the version gate's non-interference below is a
corollary, and #13's derivation of the word has exactly six things to get
right.

### `gate_noninterference` (`lean/BsvScript/Properties/Basic.lean:49`)

**P3 (gate non-interference, the CLAUDE.md gotcha as a theorem).** *What it
says:* when the version gate is off (`SCRIPT_CHRONICLE` set and the version
above 1, `EnforceNonMalleability`, `interpreter.cpp:40–44`), the seven gated
bits may be set to anything and every spend verifies the same. *What it
assumes:* two side conditions found at the reference's ungated reads: DERSIG,
STRICTENC or FORKID is set (LOW_S also selects the strict DER shape, `275–280`;
under FORKID, STRICTENC is forced, `2315–2319`) and P2SH is set (CLEANSTACK
without P2SH is an invalid word, `2432–2435`); the mainnet word satisfies both
(STRICTENC and P2SH are mandatory, `standard.h:62–68`). *Why it matters:* under a
word with `SCRIPT_CHRONICLE` that meets the two side conditions, none of the seven
gated bits reaches the verdict of a version-2 spend, whatever their values: the
policy bits MINIMALDATA, NULLDUMMY and CLEANSTACK (the standard set only,
`policy.h:182–189`), the consensus-by-height bits LOW_S and NULLFAIL
(`verify_script_flags.cpp:65–69`) and SIGPUSHONLY (`:71–75`), and MINIMALIF, which
the node never sets at the pin. The statement compares one word with its gated
variants under one limits record, so it is not the comparison of a relaying node
with a mining node: the relay word also carries DISCOURAGE_UPGRADABLE_NOPS, and the
two paths' limits differ. That comparison is
`Params.verifyScript_relay_block_version2`, which carries the NOPs bit over and
leaves the limits a free parameter.

`[SRC]` `interpreter.cpp:40–44`, `interpreter.cpp:275–280`, `interpreter.cpp:2315–2319`, `interpreter.cpp:2432–2435`, `standard.h:62–68`, `policy.h:182–189`, `verify_script_flags.cpp:65–69`, `verify_script_flags.cpp:71–75`

### `phase2_stack_mem_only` (`lean/BsvScript/Properties/Basic.lean:92`)

**P4 (phase crossing).** *What it says:* of the state the unlocking phase
leaves, the locking phase and everything after it (`Machine.phase2`) reads the
main stack and the memory counter alone: for the same parameters, context, word
and scripts, two states with the same stack and counter give the same verdict
(the alt stack, the conditional tracker, the op count, the separator position are
dropped at the phase boundary). It does not say the verdict depends on the
unlocking script only through that stack: `phase2` also reads the unlocking
script's bytes, since the P2SH branch re-reads `scriptSig.IsPushOnly()` after the
locking phase (`2382–2388`). *What it assumes:* nothing; the scripts `s` and `l`
are held fixed, so the statement is `phase2`'s congruence in its stack and counter
arguments, proven by a rewrite. *Why it matters:* `docs/DESIGN.md` §1.3's
statement of what crosses the phase boundary (`VerifyScript`, `2354–2372`: the
locking script runs on the stack the unlocking script left, the P2SH copy is of
that stack) is the type of `phase2`: beside the parameters, the context, the word
and the scripts, it takes that stack and that counter and nothing else of the
unlocking phase; this theorem is its congruence.

`[SRC]` `interpreter.cpp:2382–2388`, `interpreter.cpp:2354–2372`

### `opreturn_suffix` (`lean/BsvScript/Properties/Basic.lean:115`)

**`opreturn_suffix`.** *What it says:* the loop never reads the bytes after a
top-level `OP_RETURN`: for a post-Genesis UTXO, with no enclosing conditional,
the loop returns at the `OP_RETURN` whatever follows it (`interpreter.cpp:858–861`:
`return SCRIPT_ERR_OK;` from `EvalScript`), so nothing after it is parsed,
counted or executed. *What it assumes:* the UTXO is post-Genesis and the tracker
is empty (so the `OP_RETURN` is top-level and executing). *Why it matters:* it
says what the loop does with the suffix and no more; the suffix still bears on
the verdict. Its bytes count toward the script size, checked on the whole script
before the loop runs (`429–430`, `Machine.evalScript`), and a signature checked
earlier in the same script signs them, its scriptCode running from the last
separator to the script's end (`1473`, `1569`); post-Chronicle, a signature check
in the unlocking script also signs the whole locking script (`1475–1481`). So a
change to the suffix can change the verdict.

`[SRC]` `interpreter.cpp:858–861`, `interpreter.cpp:429–430`, `interpreter.cpp:1473`, `interpreter.cpp:1569`, `interpreter.cpp:1475–1481`

### `checksig_empty_sig` (`lean/BsvScript/Properties/Basic.lean:137`)

**`checksig_empty_sig`.** *What it says:* the transaction checker with an
empty signature is false without touching the curve (`2145–2147`). *What it
assumes:* nothing. *Why it matters:* an empty signature is the canonical "this
check fails" element of multisig scripts; the equation, the digest and the key
decoding are never reached for it, so no property of the curve is involved in
that verdict (and NULLFAIL exempts it: the refusal `1493–1496` is reached only
through the `!vchSig.empty()` conjunct of `1491`, and in `OP_CHECKMULTISIG` the
refusal `1643–1646` only through that of `1641`).

`[SRC]` `interpreter.cpp:2145–2147`, `interpreter.cpp:1493–1496`, `interpreter.cpp:1491`, `interpreter.cpp:1643–1646`, `interpreter.cpp:1641`

## `BsvScript.Properties.Coverage`

### `coverage` (`lean/BsvScript/Properties/Coverage.lean:39`)

**Coverage.** Every byte with a `case` label is in `flowOwns` (an opcode
`execFlow` handles itself, or `OP_CODESEPARATOR`, which `execStep` handles) or in
`hookOwns` (a family's).

### `arith_exec_isSome` (`lean/BsvScript/Properties/Coverage.lean:45`)

The arithmetic family's hook answers exactly on the opcodes it owns: `some` on
the opcodes of `Ops.Arith.isUnary` and `Ops.Arith.isBinary` and on `OP_WITHIN`,
`none` on every other byte, which it leaves to the next hook. One of the six lemmas
`opExec_isSome_of_hookOwns` assembles.

### `bitwise_exec_isSome` (`lean/BsvScript/Properties/Coverage.lean:54`)

The bitwise family's hook answers exactly on `OP_AND`, `OP_OR`, `OP_XOR`,
`OP_INVERT`, `OP_LSHIFT`, `OP_RSHIFT`, `OP_EQUAL` and `OP_EQUALVERIFY`, and on no
other byte. One of the six lemmas `opExec_isSome_of_hookOwns` assembles.

### `stack_exec_isSome` (`lean/BsvScript/Properties/Coverage.lean:64`)

The stack family's hook answers exactly on the opcodes from `OP_TOALTSTACK` to
`OP_TUCK` and on `OP_SIZE`, and on no other byte. One of the six lemmas
`opExec_isSome_of_hookOwns` assembles.

### `splice_exec_isSome` (`lean/BsvScript/Properties/Coverage.lean:72`)

The splice family's hook answers exactly on `OP_CAT`, `OP_SPLIT`, `OP_NUM2BIN`
and `OP_BIN2NUM`, and on no other byte. One of the six lemmas
`opExec_isSome_of_hookOwns` assembles.

### `crypto_exec_isSome` (`lean/BsvScript/Properties/Coverage.lean:80`)

The crypto family's hook answers exactly on the hashes from `OP_RIPEMD160` to
`OP_HASH256` and on the four signature checks, and on no other byte: not on
`OP_CODESEPARATOR` (`0xab`, between `OP_HASH256` and `OP_CHECKSIG`), which
`execStep` handles (`flowOwns`). One of the six lemmas `opExec_isSome_of_hookOwns`
assembles.

### `expansion_exec_isSome` (`lean/BsvScript/Properties/Coverage.lean:92`)

The expansion family's hook answers exactly on the opcodes from `OP_SUBSTR` to
`OP_RSHIFTNUM` (`OP_SUBSTR`, `OP_LEFT`, `OP_RIGHT`, `OP_LSHIFTNUM`,
`OP_RSHIFTNUM`), and on no other byte. One of the six lemmas
`opExec_isSome_of_hookOwns` assembles.

### `isSome_orElse` (`lean/BsvScript/Properties/Coverage.lean:101`)

A fact of `Option`: `Option.orElse a b` answers exactly when `a` or `b ()`
does. It turns the chain of six hooks `Eval.opExec` builds with `<|>` into the
disjunction of the six lemmas above (`opExec_isSome_of_hookOwns`).

### `opExec_isSome_of_hookOwns` (`lean/BsvScript/Properties/Coverage.lean:108`)

**Every byte is defined.** The assembled hook answers on every opcode the
families own.

### `execIf_ne_unimpl` (`lean/BsvScript/Properties/Coverage.lean:128`)

`execIf` (`773–781`, `784–825`) never answers `unimpl`.

`[SRC]` `interpreter.cpp:773–781`, `interpreter.cpp:784–825`

### `execCltv_ne_unimpl` (`lean/BsvScript/Properties/Coverage.lean:135`)

`execCltv` (`519–560`) never answers `unimpl`.

`[SRC]` `interpreter.cpp:519–560`

### `execCsv_ne_unimpl` (`lean/BsvScript/Properties/Coverage.lean:140`)

`execCsv` (`562–597`) never answers `unimpl`.

`[SRC]` `interpreter.cpp:562–597`

### `execFlow_of_not_flowOwns` (`lean/BsvScript/Properties/Coverage.lean:145`)

Off the flow opcodes, `execFlow` is the hook's answer (`872–1795`).

`[SRC]` `interpreter.cpp:872–1795`

### `hasCase_false_of_ge` (`lean/BsvScript/Properties/Coverage.lean:176`)

Above the byte range nothing has a `case` label.

### `execFlow_ne_unimpl` (`lean/BsvScript/Properties/Coverage.lean:185`)

**`execFlow` never answers `unimpl`** on any opcode but `OP_CODESEPARATOR`
(the loop's own, `1445–1448`, never handed to `execFlow`).

`[SRC]` `interpreter.cpp:1445–1448`

### `execStep_ne_unimpl` (`lean/BsvScript/Properties/Coverage.lean:218`)

**`execStep` never answers `unimpl`** (`473–482`, `1445–1448`): the loop hands
`execFlow` a byte only off `OP_CODESEPARATOR`.

`[SRC]` `interpreter.cpp:473–482`, `interpreter.cpp:1445–1448`

### `loop_ne_unimplemented` (`lean/BsvScript/Properties/Coverage.lean:238`)

**The loop never answers `unimplemented`** (`388–1833`): every byte is
defined. Induction on a bound of the script length (the loop consumes at least
one byte per step).

`[SRC]` `interpreter.cpp:388–1833`

### `evalScript_ne_unimplemented` (`lean/BsvScript/Properties/Coverage.lean:263`)

The corollary as `evalScript` states it (`1984–2006`): no script, stack and
memory counter reach `unimplemented`.

`[SRC]` `interpreter.cpp:1984–2006`

## `BsvScript.Properties.Eras`

### `Era.genesisActive_eq_toNat` (`lean/BsvScript/Properties/Eras.lean:57`)

`IsProtocolActive(era, Genesis)` is `era >= PostGenesis` on the ordinal (`protocol_era.cpp:91–94`).

`[SRC]` `protocol_era.cpp:91–94`

### `Era.chronicleActive_eq_toNat` (`lean/BsvScript/Properties/Eras.lean:61`)

`IsProtocolActive(era, Chronicle)` is `era >= PostChronicle` (`protocol_era.cpp:95–98`).

`[SRC]` `protocol_era.cpp:95–98`

### `Era.chronicleActive_imp_genesisActive` (`lean/BsvScript/Properties/Eras.lean:65`)

Chronicle activity implies Genesis activity: the enum is ordered (`protocol_era.h:28–34`).

`[SRC]` `protocol_era.h:28–34`

### `protocolEraOf_total` (`lean/BsvScript/Properties/Eras.lean:69`)

**The era selection's three cases** (`protocol_era.cpp:32–38`). *What it says:* every height takes one of the
three branches, each with its heights: pre-Genesis below the Genesis height, post-Genesis from it and below the
Chronicle height, post-Chronicle from both. *What it assumes:* nothing. *Why it matters:* the three height conditions
are disjoint (`h < g` against `g ≤ h`, `h < c` against `c ≤ h`), so exactly one case holds for each height. That
`Unknown` is never returned is carried by the type (`Era` has the three constructors, `Params.lean`), not by this
theorem; the statement until #32's lens 1 (A12) was the bare three-way disjunction, true of any function into
`Era`.
[LIT] https://protocol.bsvblockchain.org/specification/opcodes#protocol-eras at v1.2.2 (the heights only).

`[SRC]` `protocol_era.cpp:32–38`

### `protocolEraOf_eq_preGenesis_iff` (`lean/BsvScript/Properties/Eras.lean:83`)

**Pre-Genesis below the Genesis height** (`protocol_era.cpp:32–33`).

`[SRC]` `protocol_era.cpp:32–33`

### `protocolEraOf_eq_postGenesis_iff` (`lean/BsvScript/Properties/Eras.lean:87`)

**Post-Genesis from the Genesis height, below the Chronicle height** (`protocol_era.cpp:35–36`).

`[SRC]` `protocol_era.cpp:35–36`

### `protocolEraOf_eq_postChronicle_iff` (`lean/BsvScript/Properties/Eras.lean:91`)

**Post-Chronicle from the Chronicle height** (`protocol_era.cpp:38`), given the Genesis height too.

`[SRC]` `protocol_era.cpp:38`

### `genesisActive_protocolEraOf` (`lean/BsvScript/Properties/Eras.lean:95`)

Genesis is active at a height iff the height is at or past the Genesis height.

### `chronicleActive_protocolEraOf` (`lean/BsvScript/Properties/Eras.lean:103`)

Chronicle is active at a height iff the height is at or past both heights.

### `protocolEraOf_toNat_mono` (`lean/BsvScript/Properties/Eras.lean:115`)

**Monotone in the height**: a later height is never an earlier era.

### `protocolEraOf_genesis_boundary` (`lean/BsvScript/Properties/Eras.lean:120`)

**The activation height is the first height of the new era** ("the height of the block
where the new rules are active. It is not the height of the last block with the old
rules", `consensus/params.h:33–36`; `protocol_era.cpp:32–38`): the Genesis boundary.

`[SRC]` `consensus/params.h:33–36`, `protocol_era.cpp:32–38`

### `protocolEraOf_chronicle_boundary` (`lean/BsvScript/Properties/Eras.lean:129`)

The Chronicle boundary, likewise.

### `protocolEra_preGenesis_iff` (`lean/BsvScript/Properties/Eras.lean:136`)

The node's configured heights (`configscriptpolicy.cpp:156–162`; `init.cpp:2609–2616`:
the chain's unless overridden): the three cases for `NodeConfig.protocolEra`.

`[SRC]` `configscriptpolicy.cpp:156–162`, `init.cpp:2609–2616`

### `protocolEra_postGenesis_iff` (`lean/BsvScript/Properties/Eras.lean:142`)

The node's post-Genesis case: from its Genesis height and below its Chronicle height
(`protocolEraOf_eq_postGenesis_iff` at the configured heights).

### `protocolEra_postChronicle_iff` (`lean/BsvScript/Properties/Eras.lean:148`)

The node's post-Chronicle case: from both configured heights (`protocolEraOf_eq_postChronicle_iff`).

### `protocolEra_genesisActive` (`lean/BsvScript/Properties/Eras.lean:153`)

Genesis is active at a height for the node iff the height is at or past its Genesis height
(`genesisActive_protocolEraOf`; `IsProtocolActive`, `protocol_era.cpp:89–103`).

`[SRC]` `protocol_era.cpp:89–103`

### `protocolEra_chronicleActive` (`lean/BsvScript/Properties/Eras.lean:159`)

Chronicle is active at a height for the node iff the height is at or past both of its heights
(`chronicleActive_protocolEraOf`).

### `inputScriptBlockHeight_mempool` (`lean/BsvScript/Properties/Eras.lean:167`)

**A mempool coin is the next block's**: its era is that of the spend height on the
mempool path (the tip plus one, `validation.cpp:2545–2548`, `validation.cpp:2857`; the substitution at
`validation.cpp:2670`; BDK `core/txvalidator.cpp:267–269` with `core/txvalidator.cpp:677`; the `verifyscript`
RPC, `rpc/misc.cpp:803–809`).

`[SRC]` `validation.cpp:2545–2548`, `validation.cpp:2857`, `validation.cpp:2670`, `core/txvalidator.cpp:267–269`, `core/txvalidator.cpp:677`, `rpc/misc.cpp:803–809`

### `inputScriptBlockHeight_of_ne` (`lean/BsvScript/Properties/Eras.lean:174`)

A confirmed coin keeps its height (`validation.cpp:2673`).

`[SRC]` `validation.cpp:2673`

### `bdkCalculateFlags_consensus` (`lean/BsvScript/Properties/Eras.lean:181`)

**Teranode's block word is the reference's** (`core/txvalidator.cpp:663–668`): in consensus mode
`CalculateFlags(utxoHeight, blockHeight, true)` is `Params.derive`'s block word at the
spend height `blockHeight` for a coin at `utxoHeight` (the corpus convention of
`docs/DESIGN.md` §6: BDK consensus mode takes `spend_height` as is). A mempool coin never
reaches it (`core/txvalidator.cpp:903–904`).

`[SRC]` `core/txvalidator.cpp:663–668`, `core/txvalidator.cpp:903–904`

### `bdkCalculateFlags_policy` (`lean/BsvScript/Properties/Eras.lean:190`)

**Teranode's mempool word is the reference's** (`core/txvalidator.cpp:669–674`, `core/txvalidator.cpp:677`): in policy mode
`CalculateFlags(utxoHeight, tip, false)` is the mempool word at the spend height `tip + 1`
for the coin's resolved height (the corpus convention: BDK policy mode takes
`spend_height − 1` as the tip); Teranode has no promiscuous word.

`[SRC]` `core/txvalidator.cpp:669–674`, `core/txvalidator.cpp:677`

### `flagWord_block_p2sh` (`lean/BsvScript/Properties/Eras.lean:200`)

The block word is built by `GetBlockScriptFlags(config, tip)` (`validation.cpp:2972–2981`: the
tip's height read at `validation.cpp:2977`, the era of `height + 1` at `validation.cpp:2980`) with the
block's parent (`validation.cpp:3472`), so for a spend in block `h ≥ 1` the flags that test `height`
(`verify_script_flags.cpp:39`, `verify_script_flags.cpp:55`, `verify_script_flags.cpp:65`) test `h − 1`:
**P2SH enters the block word of block `p2shHeight + 1`** (mainnet 173,806; the comment at
`verify_script_flags.cpp:38` names 173,805, the code's height is the parent's: recorded on #20). Real history does not
part the two: block 173,805 (106 transactions, 256 inputs) spends and creates no P2SH-shaped output (`docs/records/20260928-115150-replay-173805-s3.md`).

`[SRC]` `validation.cpp:2972–2981`, `validation.cpp:2977`, `validation.cpp:2980`, `validation.cpp:3472`, `verify_script_flags.cpp:39`, `verify_script_flags.cpp:55`, `verify_script_flags.cpp:65`, `verify_script_flags.cpp:38`

### `flagWord_block_derSig` (`lean/BsvScript/Properties/Eras.lean:212`)

**DERSIG enters at `BIP66Height`** (`verify_script_flags.cpp:43` tests `height + 1`).

`[SRC]` `verify_script_flags.cpp:43`

### `flagWord_block_cltv` (`lean/BsvScript/Properties/Eras.lean:218`)

**CLTV enters at `BIP65Height`** (`verify_script_flags.cpp:47` tests `height + 1`).

`[SRC]` `verify_script_flags.cpp:47`

### `flagWord_block_csv` (`lean/BsvScript/Properties/Eras.lean:224`)

**CSV enters at `CSVHeight`** (`verify_script_flags.cpp:51` tests `height + 1`).

`[SRC]` `verify_script_flags.cpp:51`

### `flagWord_block_strictEnc` (`lean/BsvScript/Properties/Eras.lean:230`)

**STRICTENC and FORKID enter one block after `uahfHeight`** (`verify_script_flags.cpp:55–59` test `height`: the
UAHF height is the parent's by design, the fork block being `uahfHeight + 1`).

`[SRC]` `verify_script_flags.cpp:55–59`

### `flagWord_block_forkid` (`lean/BsvScript/Properties/Eras.lean:237`)

**FORKID enters with STRICTENC, one block after `uahfHeight`** (`verify_script_flags.cpp:55–59`: the two
are set in one branch testing `height`).

`[SRC]` `verify_script_flags.cpp:55–59`

### `flagWord_block_lowS` (`lean/BsvScript/Properties/Eras.lean:244`)

**LOW_S and NULLFAIL enter one block after `daaHeight`** (`verify_script_flags.cpp:65–69` test `height`).
[LIT] https://protocol.bsvblockchain.org/specification/upgrade-history#nov-2017 at v1.2.2.

`[SRC]` `verify_script_flags.cpp:65–69`

### `flagWord_block_nullFail` (`lean/BsvScript/Properties/Eras.lean:251`)

**NULLFAIL enters with LOW_S, one block after `daaHeight`** (`verify_script_flags.cpp:65–69`: one branch
testing `height`).
[LIT] https://protocol.bsvblockchain.org/specification/upgrade-history#nov-2017 at v1.2.2.

`[SRC]` `verify_script_flags.cpp:65–69`

### `flagWord_era_bits` (`lean/BsvScript/Properties/Eras.lean:259`)

**The era bits follow the eras, on both paths** (the block word's era is the block's,
`validation.cpp:2980`; the mempool word's the next block's, `validation.cpp:1031`; the per-input word
`policy.h:225–244`): GENESIS and SIGPUSHONLY iff Genesis is active at the spend height
(`verify_script_flags.cpp:71–75`, `policy.h:229–232`, `policy.h:216–220`), CHRONICLE iff
Chronicle is (`verify_script_flags.cpp:77–78`, `policy.h:195–197`), the two UTXO markers by the coin's era
(`policy.h:234–241`). Without promiscuous flags.

`[SRC]` `validation.cpp:2980`, `validation.cpp:1031`, `policy.h:225–244`, `verify_script_flags.cpp:71–75`, `policy.h:229–232`, `policy.h:216–220`, `verify_script_flags.cpp:77–78`, `policy.h:195–197`, `policy.h:234–241`

### `flagWord_genesis` (`lean/BsvScript/Properties/Eras.lean:276`)

**GENESIS is in the word from the Genesis height** (the "+1" convention of the era:
the block word of block 620,538 carries it on mainnet).

### `flagWord_sigPushOnly` (`lean/BsvScript/Properties/Eras.lean:282`)

**SIGPUSHONLY is in the word from the Genesis height**, on both paths (the block word's Genesis branch,
`verify_script_flags.cpp:71–75`; the per-input word, `policy.h:229–232`). Without promiscuous flags.

`[SRC]` `verify_script_flags.cpp:71–75`, `policy.h:229–232`

### `flagWord_chronicle` (`lean/BsvScript/Properties/Eras.lean:288`)

**CHRONICLE is in the word from the Chronicle height.**

### `flagWord_utxoAfterGenesis` (`lean/BsvScript/Properties/Eras.lean:293`)

**The UTXO markers are the coin's** (`policy.h:234–241`).

`[SRC]` `policy.h:234–241`

### `flagWord_utxoAfterChronicle` (`lean/BsvScript/Properties/Eras.lean:298`)

**The coin's Chronicle marker is its own era's** (`policy.h:238–241`): set iff the coin's height is at or
past both configured heights. Without promiscuous flags.

`[SRC]` `policy.h:238–241`

### `flagWord_mempool_of_eras` (`lean/BsvScript/Properties/Eras.lean:304`)

**The mempool word depends on the heights only through the eras** (`GetScriptVerifyFlags(era, …)`,
`verify_script_flags.cpp:11–30`, `policy.h:208–244`): two spends whose spend heights and
coin heights fall in the same eras get the same relay word, whatever the heights. The
block word has no such property (the theorems above).

`[SRC]` `verify_script_flags.cpp:11–30`, `policy.h:208–244`

### `flagWord_block_utxoAfterGenesis` (`lean/BsvScript/Properties/Eras.lean:313`)

The block path never reads the promiscuous word: the coin's Genesis marker is the
coin's era's unconditionally (the twin of `flagWord_utxoAfterGenesis` without its hypothesis).

### `flagWord_block_utxoEra` (`lean/BsvScript/Properties/Eras.lean:321`)

The block path never reads the promiscuous word: the UTXO era it carries is the
coin's unconditionally (the twin of `flagWord_utxoEra` without its hypothesis).

### `normalize_protocolEra` (`lean/BsvScript/Properties/Eras.lean:330`)

The setters leave the era selection alone (`NodeConfig.normalize` touches the five limit settings only,
`configscriptpolicy.cpp:164–308`): the normalized configuration's era of every height is the configuration's.

`[SRC]` `configscriptpolicy.cpp:164–308`

### `normalize_promiscuous` (`lean/BsvScript/Properties/Eras.lean:335`)

The setters leave the promiscuous word alone.

### `normalize_genesisActivationHeight` (`lean/BsvScript/Properties/Eras.lean:339`)

The setters leave the Genesis height alone.

### `normalize_chronicleActivationHeight` (`lean/BsvScript/Properties/Eras.lean:343`)

The setters leave the Chronicle height alone.

### `derive_flags` (`lean/BsvScript/Properties/Eras.lean:347`)

`derive`'s word is the normalized configuration's `flagWord` (the setters leave the heights alone).

### `derive_utxoEra` (`lean/BsvScript/Properties/Eras.lean:350`)

**The interpreter reads the coin's era** (`utxo_era`, `2269–2280`; `411–427`): under
`Params.derive` it is the era of the coin's height, whatever the spend height, on the block path and on the mempool
path of a node with no promiscuous word (`hp`). On a chain whose `RequireStandard()` is false a promiscuous word
replaces the mempool word and gains FORKID (`verify_script_flags.cpp:21–25`), passes the skip mask, which cannot
clear a UTXO marker (`validation.cpp:1328–1330`, `rpc/rawtransaction.cpp:1486`), and is OR-ed with the per-input word
(`validation.cpp:2696–2701`): one carrying `SCRIPT_UTXO_AFTER_GENESIS` makes that node's mempool path read a
pre-Genesis coin as post-Genesis, and one carrying `SCRIPT_UTXO_AFTER_CHRONICLE` alone refuses a pre-Genesis
coin (`SCRIPT_ERR_INVALID_FLAGS`, `interpreter.cpp:2312–2313`) and makes a post-Genesis coin, whose per-input word
carries the Genesis marker, read as post-Chronicle (`interpreter.cpp:2269–2274`).

`[SRC]` `interpreter.cpp:2269–2280`, `interpreter.cpp:411–427`, `verify_script_flags.cpp:21–25`, `validation.cpp:1328–1330`, `rpc/rawtransaction.cpp:1486`, `validation.cpp:2696–2701`, `interpreter.cpp:2312–2313`, `interpreter.cpp:2269–2274`

### `derive_limits_preGenesis` (`lean/BsvScript/Properties/Eras.lean:363`)

**A pre-Genesis coin carries the pre-Genesis limits, whatever the spend era**, on the block path and on the
mempool path of a node with no promiscuous word (`hp`; `derive_utxoEra` names the route it excludes)
(`make_verify_script_params`, `2282–2302`, over the getters' `!utxo_after_genesis` branches,
`configscriptpolicy.cpp:65–154`): 500 ops, 4-byte numbers, 10,000-byte scripts, 20 keys, an
unbounded memory budget.

`[SRC]` `interpreter.cpp:2282–2302`, `configscriptpolicy.cpp:65–154`

### `derive_limits_block_postGenesis` (`lean/BsvScript/Properties/Eras.lean:376`)

**A post-Genesis coin on the block path carries the consensus limits of its era**
(the getters' `consensus` branches): unbounded ops, size and keys, the era's number width
(750,000 or 32,000,000), the node's `maxstackmemoryusageconsensus`.

### `derive_preGenesis_coin` (`lean/BsvScript/Properties/Eras.lean:388`)

**Q3 (`docs/DESIGN.md` §9): a pre-Genesis output spent after Genesis.** *What it says:*
for a coin created below the Genesis height, whatever the spend height, on the block path and on the
mempool path of a node with no promiscuous word (`hp`; the route it excludes is in `derive_utxoEra`), the
interpreter reads the coin's era as pre-Genesis (no UTXO marker, `411–427`), the limits
are the pre-Genesis constants (`2282–2302`, `configscriptpolicy.cpp:65–154`), and the
spending era's bits (GENESIS, SIGPUSHONLY, CHRONICLE) are the spend height's
(`policy.h:225–244`, `verify_script_flags.cpp:71–78`). *Why it matters:* the pre-Genesis
UTXO rules (the 520-byte element, the 1,000-element stack, 4-byte numbers, `OP_RETURN`
invalid, P2SH, CLTV/CSV live, the second `OP_ELSE`) hang on the coin's era, and the version
gate and push-only rule on the spend's: the two are separate parameters of one word.

`[SRC]` `interpreter.cpp:411–427`, `interpreter.cpp:2282–2302`, `configscriptpolicy.cpp:65–154`, `policy.h:225–244`, `verify_script_flags.cpp:71–78`

### `mkEnv_utxoEra` (`lean/BsvScript/Properties/Eras.lean:412`)

The machine reads the coin's era from the original word (`mkEnv`, `411–427`): neither
STRICTENC-from-FORKID (`2315–2319`) nor the version gate (`Flags.gate`) touches the two markers.

`[SRC]` `interpreter.cpp:411–427`, `interpreter.cpp:2315–2319`

### `forkAdjust_utxoEra` (`lean/BsvScript/Properties/Eras.lean:417`)

STRICTENC from FORKID (`2315–2319`, `Flags.forkAdjust`) leaves the two UTXO markers, so the coin's era.

`[SRC]` `interpreter.cpp:2315–2319`

### `gate_utxoEra` (`lean/BsvScript/Properties/Eras.lean:421`)

The version gate (`Flags.gate`, `40–44`) leaves the two UTXO markers, so the coin's era, in both branches: the
word unchanged where `EnforceNonMalleability` holds, the seven restrictions cleared where it does not.

`[SRC]` `interpreter.cpp:40–44`

### `utxoEra_of_not_afterGenesis` (`lean/BsvScript/Properties/Eras.lean:428`)

A pre-Genesis coin is neither post-Genesis nor post-Chronicle in the environment.

### `utxoAfterChronicle_of_not_afterGenesis` (`lean/BsvScript/Properties/Eras.lean:432`)

A coin that is not post-Genesis is not post-Chronicle either (its era is pre-Genesis,
`utxoEra_of_not_afterGenesis`).

### `execFlow_return_preGenesis` (`lean/BsvScript/Properties/Eras.lean:438`)

**`OP_RETURN` on a pre-Genesis coin fails** (`856–871`, `867–869`): executed, it is
`SCRIPT_ERR_OP_RETURN` whatever the spend era.

`[SRC]` `interpreter.cpp:856–871`, `interpreter.cpp:867–869`

### `execFlow_return_postGenesis_top` (`lean/BsvScript/Properties/Eras.lean:447`)

**A top-level `OP_RETURN` on a post-Genesis coin ends the script as success** (`858–861`).

`[SRC]` `interpreter.cpp:858–861`

### `execFlow_return_postGenesis_nested` (`lean/BsvScript/Properties/Eras.lean:455`)

**A nested `OP_RETURN` on a post-Genesis coin marks the rest as unexecuted** (`863–866`).

`[SRC]` `interpreter.cpp:863–866`

### `loop_pushSize_preGenesis` (`lean/BsvScript/Properties/Eras.lean:463`)

**A push above 520 bytes fails on a pre-Genesis coin** (`455–456`, `script.h:29`), executed
or not, before the op count, the disabled check and the push itself.

`[SRC]` `interpreter.cpp:455–456`, `script.h:29`

### `loop_disabled_preGenesis` (`lean/BsvScript/Properties/Eras.lean:471`)

**A disabled opcode fails even unexecuted on a pre-Genesis coin** (`470–471`:
`IsOpcodeDisabled(opcode, utxoEra) && (!utxo_after_genesis || fExec)`; `360–375`:
`OP_2MUL`/`OP_2DIV` unless the coin is post-Chronicle). The op count is charged first (`466`).

`[SRC]` `interpreter.cpp:470–471`, `interpreter.cpp:360–375`, `interpreter.cpp:466`

### `loop_disabled_postGenesis_dead` (`lean/BsvScript/Properties/Eras.lean:485`)

**A disabled opcode in a dead branch is skipped on a post-Genesis, pre-Chronicle coin**
(`470–471`: `fExec` false and the coin after Genesis; `360–375`): the loop moves on with the op
count charged (`466`). Executed, it fails (`execStep` never reaches it: `470` precedes `473`).

`[SRC]` `interpreter.cpp:470–471`, `interpreter.cpp:360–375`, `interpreter.cpp:466`, `interpreter.cpp:470`, `interpreter.cpp:473`

### `execFlow_ver_preChronicle` (`lean/BsvScript/Properties/Eras.lean:499`)

**`OP_VER` fails on a pre-Chronicle coin** (`598–601`): `SCRIPT_ERR_BAD_OPCODE` when
executed; post-Chronicle it pushes the transaction version (`603–606`).

`[SRC]` `interpreter.cpp:598–601`, `interpreter.cpp:603–606`

### `execFlow_verif_preGenesis` (`lean/BsvScript/Properties/Eras.lean:507`)

**`OP_VERIF`/`OP_VERNOTIF` fail on a pre-Genesis coin even unexecuted** (`773–781`: the
skip at `777` needs `utxo_after_genesis`).

`[SRC]` `interpreter.cpp:773–781`, `interpreter.cpp:777`

### `execFlow_verif_postGenesis_preChronicle` (`lean/BsvScript/Properties/Eras.lean:517`)

**`OP_VERIF`/`OP_VERNOTIF` are skipped unexecuted on a post-Genesis, pre-Chronicle coin**
(`777–778`) and fail executed (`780`).

`[SRC]` `interpreter.cpp:777–778`, `interpreter.cpp:780`

### `execCltv_nop_postGenesis` (`lean/BsvScript/Properties/Eras.lean:526`)

**CLTV is a NOP on a post-Genesis coin** (`520`: `|| utxo_after_genesis`), discouraged under
the policy flag (`522–526`).

`[SRC]` `interpreter.cpp:520`, `interpreter.cpp:522–526`

### `execCltv_unsatisfied_preGenesis` (`lean/BsvScript/Properties/Eras.lean:532`)

**CLTV is live on a pre-Genesis coin under the flag** (`520`, `546–556`): an unsatisfied lock
time is `SCRIPT_ERR_UNSATISFIED_LOCKTIME`, whatever the spend era.

`[SRC]` `interpreter.cpp:520`, `interpreter.cpp:546–556`

### `execCltv_satisfied_preGenesis` (`lean/BsvScript/Properties/Eras.lean:542`)

The satisfied case leaves the operand on the stack (`559`: only `break`).

`[SRC]` `interpreter.cpp:559`

### `execCsv_nop_postGenesis` (`lean/BsvScript/Properties/Eras.lean:551`)

**CSV is a NOP on a post-Genesis coin** (`563`), discouraged under the policy flag (`565–569`).

`[SRC]` `interpreter.cpp:563`, `interpreter.cpp:565–569`

### `execCsv_unsatisfied_preGenesis` (`lean/BsvScript/Properties/Eras.lean:556`)

**CSV is live on a pre-Genesis coin under the flag** (`563`, `577–595`): an operand without the
disable bit whose relative lock is unsatisfied is `SCRIPT_ERR_UNSATISFIED_LOCKTIME`.

`[SRC]` `interpreter.cpp:563`, `interpreter.cpp:577–595`

### `execCsv_satisfied_preGenesis` (`lean/BsvScript/Properties/Eras.lean:566`)

The satisfied case leaves the operand on the stack (`593–596`: only `break`), CLTV's twin
(`execCltv_satisfied_preGenesis`); with `execCsv_unsatisfied_preGenesis` and `checkSequence_iff` this is CSV's
verdict on a pre-Genesis coin under the flag once a non-negative operand without the disable flag is read. The
theorems assume that read (`hs`, `hr`, `hn`); CSV's other outcomes there are the empty stack (`571–572`), the
operand over five bytes or not minimal (`577`, caught at `1807–1814`) and the negative operand (`582–583`).

`[SRC]` `interpreter.cpp:593–596`, `interpreter.cpp:571–572`, `interpreter.cpp:577`, `interpreter.cpp:1807–1814`, `interpreter.cpp:582–583`

### `execCsv_disable_flag_operand` (`lean/BsvScript/Properties/Eras.lean:579`)

**An operand with the disable flag makes CSV a NOP** (`585–590`: `nSequence & SEQUENCE_LOCKTIME_DISABLE_FLAG`
non-zero, `break` before the checker; bit 31, `transaction.h:106`): the operand's own bit, whatever the spent input's
sequence, so the checker's test of the input's bit (`checkSequence_disable_flag`, `2220–2222`) is never reached.

`[SRC]` `interpreter.cpp:585–590`, `transaction.h:106`, `interpreter.cpp:2220–2222`

### `execFlow_else_preGenesis` (`lean/BsvScript/Properties/Eras.lean:590`)

**A second `OP_ELSE` toggles again on a pre-Genesis coin** (`829–831` test
`has_op_else() && utxo_after_genesis`; `conditional_tracker.cpp:57–65`).

`[SRC]` `interpreter.cpp:829–831`, `conditional_tracker.cpp:57–65`

### `execFlow_else_postGenesis_second` (`lean/BsvScript/Properties/Eras.lean:599`)

**A second `OP_ELSE` is unbalanced on a post-Genesis coin** (`829–831`; `conditional_tracker.cpp:51–55`).

`[SRC]` `interpreter.cpp:829–831`, `conditional_tracker.cpp:51–55`

### `expansion_exec_preChronicle` (`lean/BsvScript/Properties/Eras.lean:607`)

**The expansion opcodes are NOPs on a pre-Chronicle coin** (`611–618`, `644–650`, `669–675`,
`694–700`, `730–736`): `OP_SUBSTR`, `OP_LEFT`, `OP_RIGHT`, `OP_LSHIFTNUM`, `OP_RSHIFTNUM` do
nothing, or fail under DISCOURAGE_UPGRADABLE_NOPS (a policy flag); they execute only for a
coin created after Chronicle (#18; bsv-rs 0.3.28 gates them the same way, `flags.rs`
`UTXO_AFTER_CHRONICLE`, `spend.rs` `utxo_after_chronicle`).

`[SRC]` `interpreter.cpp:611–618`, `interpreter.cpp:644–650`, `interpreter.cpp:669–675`, `interpreter.cpp:694–700`, `interpreter.cpp:730–736`

### `checkSignatureEncoding_of_not_strictEnc` (`lean/BsvScript/Properties/Eras.lean:631`)

**Without STRICTENC the type is never read** (`291`): the check passes whatever the last byte, as for a
pre-UAHF spend under the derived word (`flagWord_block_strictEnc`).

`[SRC]` `interpreter.cpp:291`

### `checkSignatureEncoding_sigHashtype` (`lean/BsvScript/Properties/Eras.lean:642`)

**The undefined base under STRICTENC** (`293–294`): a non-empty signature whose type is not defined
(`Sighash.SigHashType.isDefined_iff`: base 0 or 4–31; the fork value above the low byte is never read,
`Sighash.SigHashType.isDefined_add_forkValue`) is `SCRIPT_ERR_SIG_HASHTYPE`. The spec's
own SV-node instance says so on gen-00969, gen-00970 and gen-00971 (`corpus/INDEX.md` §4c); bsv-rs 0.3.28 accepts
them (the crate class `sighash.type.undefined-base`, `spend.rs:1739–1766` at 0.3.28).

`[SRC]` `interpreter.cpp:293–294`, `spend.rs:1739–1766 (at 0.3.28)`

### `checkSignatureEncoding_illegalForkid` (`lean/BsvScript/Properties/Eras.lean:656`)

**The FORKID bit without FORKID enabled** (`300–301`): under a word with STRICTENC and without
`SCRIPT_ENABLE_SIGHASH_FORKID`, a defined type carrying the FORKID bit is `SCRIPT_ERR_ILLEGAL_FORKID`. No word the
node derives is such a word: on the block path the two flags enter in one branch (`verify_script_flags.cpp:54–59`),
both are in both mandatory sets (`standard.h:55–68`) so in every standard word (`policy.h:191–197`), a promiscuous
word gains FORKID (`verify_script_flags.cpp:25`), and the skip mask clears neither (`rpc/rawtransaction.cpp:1486`).
The refusal is reached only under an explicit word, the `verifyscript` RPC's integer `flags` (`rpc/misc.cpp:697–702`)
or the reference's test vectors; before UAHF the word has neither flag and the type is never read
(`checkSignatureEncoding_of_not_strictEnc`).

`[SRC]` `interpreter.cpp:300–301`, `verify_script_flags.cpp:54–59`, `standard.h:55–68`, `policy.h:191–197`, `verify_script_flags.cpp:25`, `rpc/rawtransaction.cpp:1486`, `rpc/misc.cpp:697–702`

### `checkSignatureEncoding_illegalChronicle` (`lean/BsvScript/Properties/Eras.lean:675`)

**The CHRONICLE bit before Chronicle** (`302–303`): without `SCRIPT_CHRONICLE` in the word a CHRONICLE-bit
signature is `SCRIPT_ERR_ILLEGAL_CHRONICLE`. Under STRICTENC the bit is legal only with `SCRIPT_CHRONICLE` in the
word, the Chronicle era's (`flagWord_chronicle`), where it selects the original digest (`Sighash.sighash_original_of_chronicle`, Q2). go-sdk v1.5.2 has no image
of the bit and ts-sdk 2.8.0 gates it on the coin's era (the class `sighash.type.chronicle-bit`, `corpus/INDEX.md`
§4b). Without STRICTENC (a pre-UAHF block word) the type is never read, so the bit passes the encoding check
there too (`checkSignatureEncoding_of_not_strictEnc`).

`[SRC]` `interpreter.cpp:302–303`

### `checkSignatureEncoding_mustUseForkid` (`lean/BsvScript/Properties/Eras.lean:693`)

**FORKID enabled demands the bit** (`305–306`): after UAHF a defined type without the FORKID bit is
`SCRIPT_ERR_MUST_USE_FORKID`, so the non-FORKID original digest (`Sighash.sighash_original_of_no_forkid_bit`) is
historical replay on mainnet. go-sdk v1.5.2 never enforces it (the class `sighash.must-use-forkid`,
`corpus/INDEX.md` §4b).

`[SRC]` `interpreter.cpp:305–306`

### `checkSignatureEncoding_ok_strictEnc` (`lean/BsvScript/Properties/Eras.lean:710`)

**The type accepted under STRICTENC** (`309`): defined, and each bit lawful for the word; the four theorems
above and this one are the whole of `291–309`.

`[SRC]` `interpreter.cpp:309`, `interpreter.cpp:291–309`

### `checkLockTime_iff` (`lean/BsvScript/Properties/Eras.lean:727`)

**`CheckLockTime` as one predicate** (`2166–2202`): satisfied iff the operand and `nLockTime` are of one kind
(both below `LOCKTIME_THRESHOLD` or both at least it, `2175–2180`), the operand is at most the lock time
(`2184–2186`) and the spent input is not final (`2196–2198`). With `execCltv_satisfied_preGenesis` and
`execCltv_unsatisfied_preGenesis` this is CLTV's verdict on a pre-Genesis coin under the flag once a non-negative
operand is read. Those theorems assume that read (`hs`, `hr`, `hn`); CLTV's other outcomes there are the empty
stack (`528–529`), the operand over five bytes or not minimal (`546`, caught at `1807–1814`) and the negative operand
(`551–552`).

`[SRC]` `interpreter.cpp:2166–2202`, `interpreter.cpp:2175–2180`, `interpreter.cpp:2184–2186`, `interpreter.cpp:2196–2198`, `interpreter.cpp:528–529`, `interpreter.cpp:546`, `interpreter.cpp:1807–1814`, `interpreter.cpp:551–552`

### `checkLockTime_of_lt` (`lean/BsvScript/Properties/Eras.lean:745`)

An operand above the lock time fails (`2184–2186`): the transaction is not yet spendable by the script's
own reading.

`[SRC]` `interpreter.cpp:2184–2186`

### `checkLockTime_kind_mismatch` (`lean/BsvScript/Properties/Eras.lean:751`)

A height operand against a time lock, or a time operand against a height lock, fails (`2175–2180`).

`[SRC]` `interpreter.cpp:2175–2180`

### `checkLockTime_missing_input` (`lean/BsvScript/Properties/Eras.lean:757`)

An input index past the inputs reads as final in the spec (`getD SEQUENCE_FINAL`; the reference indexes
`vin[nIn]` of the transaction being validated, `2197`, so the case never arises there): never satisfied.

`[SRC]` `interpreter.cpp:2197`

### `checkSequence_disable_flag` (`lean/BsvScript/Properties/Eras.lean:764`)

**The disable flag on the sequence** (`2220–2222`): with bit 31 set on the spent input's `nSequence`, CSV is
never satisfied (relative lock time is off for that input, BIP 68).

`[SRC]` `interpreter.cpp:2220–2222`

### `checkSequence_final` (`lean/BsvScript/Properties/Eras.lean:773`)

`SEQUENCE_FINAL` (`0xffffffff`, `transaction.h:99`) carries the disable flag, so a final input never satisfies
CSV either (`2220–2222`).

`[SRC]` `transaction.h:99`, `interpreter.cpp:2220–2222`

### `checkSequence_missing_input` (`lean/BsvScript/Properties/Eras.lean:780`)

As for CLTV: an input index past the inputs reads as final, never satisfied.

### `checkSequence_iff` (`lean/BsvScript/Properties/Eras.lean:786`)

**`CheckSequence` as one predicate** (`2204–2250`): the version at least 2 as an unsigned word (`2212–2214`),
no disable flag on the sequence (`2220–2222`), the two values masked to the type flag and the low sixteen bits
(`2226–2229`) of one kind (`2237–2242`), and the operand's at most the sequence's (`2246–2248`). With
`execCsv_unsatisfied_preGenesis` and `execCsv_satisfied_preGenesis` this is CSV's verdict on a pre-Genesis coin under
the flag once a non-negative operand without the disable flag is read (the outcomes before that read are named at
`execCsv_satisfied_preGenesis`).

`[SRC]` `interpreter.cpp:2204–2250`, `interpreter.cpp:2212–2214`, `interpreter.cpp:2220–2222`, `interpreter.cpp:2226–2229`, `interpreter.cpp:2237–2242`, `interpreter.cpp:2246–2248`

### `execStep_codeseparator` (`lean/BsvScript/Properties/Eras.lean:809`)

**`OP_CODESEPARATOR` moves the scriptCode's start** (`1445–1448`: `pbegincodehash = pc`, the byte after the
separator; `execStep`, the loop's own case): executed, it changes nothing but `codeSep`, which becomes the bytes after
it (`k`, the parser's count after the opcode, is 0 for every non-push opcode).

`[SRC]` `interpreter.cpp:1445–1448`

### `execStep_codeseparator_unexecuted` (`lean/BsvScript/Properties/Eras.lean:816`)

Unexecuted (an inactive branch) it changes nothing (`482`: the switch runs only under `fExec` or for
`OP_IF`…`OP_ENDIF`, and `0xab` is outside that range).

`[SRC]` `interpreter.cpp:482`

### `loop_codeseparator` (`lean/BsvScript/Properties/Eras.lean:822`)

**At the loop** (`450–451`, `466–471`, `1445–1448`): an executed `OP_CODESEPARATOR` with the op count in bounds
continues on the rest of the script with the count charged and `codeSep` that rest; the hypotheses are the loop's
guards before the switch (an active branch with no non-top-level return, the count) and the pre-Genesis stack limit
the loop checks after the step (`1800–1803`).

`[SRC]` `interpreter.cpp:450–451`, `interpreter.cpp:466–471`, `interpreter.cpp:1445–1448`, `interpreter.cpp:1800–1803`

### `scriptCodeOf_chronicle` (`lean/BsvScript/Properties/Eras.lean:840`)

**The scriptCode of a signature check inside the unlocking script under Chronicle** (`1472–1481`, `1568–1577`:
`scriptCode += *checksigData` when `checksigData && IsChronicle(flags)`; `checksigData` is the locking script while
the unlocking script runs, `2338–2352`): the bytes from the last separator with the locking script appended.

`[SRC]` `interpreter.cpp:1472–1481`, `interpreter.cpp:1568–1577`, `interpreter.cpp:2338–2352`

### `scriptCodeOf_eq_codeSep` (`lean/BsvScript/Properties/Eras.lean:848`)

Otherwise the bytes from the last separator alone (`1473`, `1569`: `CScript scriptCode {pbegincodehash, pend}`):
in the locking script (`checksigData` null) or on a pre-Chronicle spend.

`[SRC]` `interpreter.cpp:1473`, `interpreter.cpp:1569`

### `mkEnv_block_discourage_off` (`lean/BsvScript/Properties/Eras.lean:858`)

**Every environment of the block path has DISCOURAGE_UPGRADABLE_NOPS off** (#32's lens 1, A3 and A10: the
three theorems after this one assume the bit off, and this is where the block path meets them). *What it says:* the
environment `Machine.verifyScript` builds for either phase of a spend on the block path (`mkEnv` over the word
`Params.derive` gives with `consensus = true`, after STRICTENC from FORKID, `2315–2319`; `verifyScript`, `phase2`) has
the bit off. *What it assumes:* nothing: every configuration, every spend height and coin height (so every coin's
era), every version, either phase. *Why it matters:* the block word never carries the bit
(`blockScriptFlags_policy_off`; `policy.h:177–181`; `script_flags.h:56–57`: "will never be a mandatory flag applied to
scripts in a block"), the per-input word adds only SIGPUSHONLY and the two UTXO markers (`policy.h:225–244`), and
neither `Flags.forkAdjust` nor the version gate `Flags.gate` sets it; so on the block path each of the flag's eight
read sites (`522`, `565`, `613`, `646`, `671`, `696`, `732`, `768`) passes.

`[SRC]` `interpreter.cpp:2315–2319`, `policy.h:177–181`, `script_flags.h:56–57`, `policy.h:225–244`, `interpreter.cpp:522`, `interpreter.cpp:565`, `interpreter.cpp:613`, `interpreter.cpp:646`, `interpreter.cpp:671`, `interpreter.cpp:696`, `interpreter.cpp:732`, `interpreter.cpp:768`

### `nopOrDiscourage_block` (`lean/BsvScript/Properties/Eras.lean:877`)

**DISCOURAGE_UPGRADABLE_NOPS never fires in a block**, read at the opcode. *What it assumes:* the bit off in the
environment's word (`hd`), as every environment of the block path has it (`mkEnv_block_discourage_off`, whatever the
coin's era). *What it says:* the expansion opcodes' pre-Chronicle NOP is a NOP (`613–614`, `646–647`, `671–672`,
`696–697`, `732–733`) …

`[SRC]` `interpreter.cpp:613–614`, `interpreter.cpp:646–647`, `interpreter.cpp:671–672`, `interpreter.cpp:696–697`, `interpreter.cpp:732–733`

### `execFlow_nop_block` (`lean/BsvScript/Properties/Eras.lean:885`)

… `OP_NOP1`, `OP_NOP9` and `OP_NOP10` continue (`765–771`), under the same hypothesis …

`[SRC]` `interpreter.cpp:765–771`

### `cltv_csv_block_postGenesis` (`lean/BsvScript/Properties/Eras.lean:894`)

… and CLTV/CSV on a post-Genesis coin continue (`520–526`, `563–569`), under the same hypothesis and a
post-Genesis coin (`hg`). With `mkEnv_block_discourage_off` the three are "policy never decides block validity", read
per opcode; the standard word (`standardOnly`, `policy.h:182–189`) fails each of these sites instead
(`nopOrDiscourage_standard`, `execFlow_nop_standard`, `execCltv_nop_postGenesis`, `execCsv_nop_postGenesis`).

`[SRC]` `interpreter.cpp:520–526`, `interpreter.cpp:563–569`, `policy.h:182–189`

### `nopOrDiscourage_standard` (`lean/BsvScript/Properties/Eras.lean:903`)

The relay side of the same sites: with the flag on (the standard word), the pre-Chronicle expansion NOP is
`SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS` (`613–614`), as `OP_NOP1`/`OP_NOP9`/`OP_NOP10` are (`768–769`,
`execFlow_nop_standard`) and post-Genesis CLTV/CSV are (`522–523`, `565–566`; `execCltv_nop_postGenesis`,
`execCsv_nop_postGenesis`).

`[SRC]` `interpreter.cpp:613–614`, `interpreter.cpp:768–769`, `interpreter.cpp:522–523`, `interpreter.cpp:565–566`

### `execFlow_nop_standard` (`lean/BsvScript/Properties/Eras.lean:911`)

**`OP_NOP1`, `OP_NOP9` and `OP_NOP10` under the flag** (`768–769`): with DISCOURAGE_UPGRADABLE_NOPS on (the
standard word), each is `SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS`; the relay side of `execFlow_nop_block`.

`[SRC]` `interpreter.cpp:768–769`

## `BsvScript.Properties.Hooks`

### `Frame.refl` (`lean/BsvScript/Properties/Hooks.lean:30`)

The empty step is a frame.

### `Frame.trans` (`lean/BsvScript/Properties/Hooks.lean:33`)

Two frames compose.

### `popElem_frame` (`lean/BsvScript/Properties/Hooks.lean:37`)

A pop is a frame (`limitedstack.cpp:211–219`).

`[SRC]` `limitedstack.cpp:211–219`

### `popElem_ok` (`lean/BsvScript/Properties/Hooks.lean:45`)

A pop's result, explicitly: the top removed, the counter shrunk by its weight (`limitedstack.cpp:211–219`).

`[SRC]` `limitedstack.cpp:211–219`

### `pushElem_frame` (`lean/BsvScript/Properties/Hooks.lean:56`)

A push is a frame (`limitedstack.h:163–173`).

`[SRC]` `limitedstack.h:163–173`

### `pushCount_frame` (`lean/BsvScript/Properties/Hooks.lean:60`)

A number push (`pushCount`) is a frame.

### `pushResult_frame` (`lean/BsvScript/Properties/Hooks.lean:70`)

A result push (`pushResult`) is a frame.

### `pushBool_frame` (`lean/BsvScript/Properties/Hooks.lean:80`)

A boolean push is a frame.

### `swapTop_frame` (`lean/BsvScript/Properties/Hooks.lean:85`)

A swap below the top is a frame (`limitedstack.cpp:285–288`).

`[SRC]` `limitedstack.cpp:285–288`

### `eraseTop_frame` (`lean/BsvScript/Properties/Hooks.lean:90`)

An erase below the top is a frame (`limitedstack.cpp:260–267`).

`[SRC]` `limitedstack.cpp:260–267`

### `insertTop_frame` (`lean/BsvScript/Properties/Hooks.lean:94`)

An insert below the top is a frame (`limitedstack.cpp:269–283`).

`[SRC]` `limitedstack.cpp:269–283`

### `toAlt_frame` (`lean/BsvScript/Properties/Hooks.lean:105`)

The two alt-stack moves are frames (`876–888`).

`[SRC]` `interpreter.cpp:876–888`

### `fromAlt_frame` (`lean/BsvScript/Properties/Hooks.lean:115`)

The move back from the alt stack is a frame.

### `cat_frame` (`lean/BsvScript/Properties/Hooks.lean:127`)

`OP_CAT` is a frame.

### `split_frame` (`lean/BsvScript/Properties/Hooks.lean:142`)

`OP_SPLIT` is a frame.

### `num2binOp_frame` (`lean/BsvScript/Properties/Hooks.lean:162`)

`OP_NUM2BIN` is a frame.

### `bin2num_frame` (`lean/BsvScript/Properties/Hooks.lean:182`)

`OP_BIN2NUM` is a frame.

### `unary_frame` (`lean/BsvScript/Properties/Hooks.lean:196`)

A unary arithmetic opcode is a frame.

### `binary_frame` (`lean/BsvScript/Properties/Hooks.lean:210`)

A binary arithmetic opcode is a frame, `OP_NUMEQUALVERIFY`'s pop included.

### `within_frame` (`lean/BsvScript/Properties/Hooks.lean:246`)

`OP_WITHIN` is a frame.

### `bitwise2_frame` (`lean/BsvScript/Properties/Hooks.lean:271`)

`OP_AND`/`OP_OR`/`OP_XOR` are frames.

### `invert_frame` (`lean/BsvScript/Properties/Hooks.lean:288`)

`OP_INVERT` is a frame.

### `shift_frame` (`lean/BsvScript/Properties/Hooks.lean:299`)

`OP_LSHIFT`/`OP_RSHIFT` are frames.

### `equal_frame` (`lean/BsvScript/Properties/Hooks.lean:318`)

`OP_EQUAL`/`OP_EQUALVERIFY` are frames.

### `ite_pos_of` (`lean/BsvScript/Properties/Hooks.lean:350`)

The `then` branch of a decided `if` (the core lemma under a name both toolchains carry: `if_pos` at
v4.33.0, `ite_eq_left` at v4.34.0).

### `ite_neg_of` (`lean/BsvScript/Properties/Hooks.lean:357`)

The `else` branch of a decided `if` (`if_neg` at v4.33.0, `ite_eq_right` at v4.34.0).

### `need_ok_iff` (`lean/BsvScript/Properties/Hooks.lean:363`)

`need st n` succeeds exactly when the stack holds at least `n` elements.

### `execStack_frame` (`lean/BsvScript/Properties/Hooks.lean:368`)

Every stack opcode is a frame (`876–1064`): the moves, the copies, the drops, the swaps and rotations,
`OP_PICK`/`OP_ROLL`, `OP_TUCK`, `OP_DEPTH`, `OP_SIZE`.

`[SRC]` `interpreter.cpp:876–1064`

### `ofExcept_ok` (`lean/BsvScript/Properties/Hooks.lean:564`)

A family's `Except` answer read as a hook answer: `.ok` exactly when the `Except` is.

### `popPopPush_frame` (`lean/BsvScript/Properties/Hooks.lean:570`)

Two pops and a push are a frame (the expansion opcodes' result write).

### `nopOrDiscourage_frame` (`lean/BsvScript/Properties/Hooks.lean:585`)

The pre-Chronicle NOP is a frame (the state untouched).

### `substr_frame` (`lean/BsvScript/Properties/Hooks.lean:593`)

`OP_SUBSTR` is a frame.

### `left_frame` (`lean/BsvScript/Properties/Hooks.lean:618`)

`OP_LEFT` is a frame.

### `right_frame` (`lean/BsvScript/Properties/Hooks.lean:630`)

`OP_RIGHT` is a frame.

### `lshiftnum_frame` (`lean/BsvScript/Properties/Hooks.lean:642`)

`OP_LSHIFTNUM` is a frame.

### `rshiftnum_frame` (`lean/BsvScript/Properties/Hooks.lean:662`)

`OP_RSHIFTNUM` is a frame.

### `hashOp_frame` (`lean/BsvScript/Properties/Hooks.lean:679`)

The hash opcodes are frames (`1402–1443`).

`[SRC]` `interpreter.cpp:1402–1443`

### `checkSigOp_frame` (`lean/BsvScript/Properties/Hooks.lean:691`)

`OP_CHECKSIG`/`OP_CHECKSIGVERIFY` are frames (`1450–1508`).

`[SRC]` `interpreter.cpp:1450–1508`

### `forIn_frame` (`lean/BsvScript/Properties/Hooks.lean:727`)

A loop whose every step is a frame is a frame (the `for` over `List.range` of the multisig's pops,
`1636–1653`).

`[SRC]` `interpreter.cpp:1636–1653`

### `checkMultiSigOp_ok` (`lean/BsvScript/Properties/Hooks.lean:752`)

**H1 (the multisig success case).** *What it says:* an `OP_CHECKMULTISIG`/`OP_CHECKMULTISIGVERIFY` that
succeeds read a key count `n` (`1517–1526`), charged it to the op count, which stays within
`MaxOpsPerScript` (`1534–1536`), and left the op count exactly `n` higher; every pop and push after the
charge keeps the memory invariant. *What it assumes:* the opcode succeeded. *Why it matters:* the key
count is the only charge a family makes to the op count, and the charge is refused before it can pass
the limit, so the op-count invariant holds across the crypto family (`HookOpCount`), and the multisig's
pops of its arguments (`1636–1653`), the dummy and the result keep the counter exact (`HookMem`); and
`codeSep` is as it was (#149).

`[SRC]` `interpreter.cpp:1517–1526`, `interpreter.cpp:1534–1536`, `interpreter.cpp:1636–1653`

### `Frame.good` (`lean/BsvScript/Properties/Hooks.lean:864`)

A frame is good.

### `some_ofExcept_ok` (`lean/BsvScript/Properties/Hooks.lean:868`)

A family answer `some (.ok st')` built from an `Except` step is that step's success.

### `arith_exec_good` (`lean/BsvScript/Properties/Hooks.lean:873`)

The arithmetic family's hook is good.

### `bitwise_exec_good` (`lean/BsvScript/Properties/Hooks.lean:885`)

The bitwise family's hook is good.

### `stack_exec_good` (`lean/BsvScript/Properties/Hooks.lean:899`)

The stack family's hook is good.

### `splice_exec_good` (`lean/BsvScript/Properties/Hooks.lean:907`)

The splice family's hook is good.

### `crypto_exec_good` (`lean/BsvScript/Properties/Hooks.lean:921`)

The crypto family's hook is good: the hashes and the signature checks are frames, the multisig
charges its key count within the limit (H1).

### `expansion_exec_good` (`lean/BsvScript/Properties/Hooks.lean:935`)

The expansion family's hook is good (before Chronicle a NOP, the state untouched).

### `opExec_good` (`lean/BsvScript/Properties/Hooks.lean:954`)

The evaluator's hook is good: the family that answers keeps both invariants.

### `hookOpCount_opExec` (`lean/BsvScript/Properties/Hooks.lean:1001`)

**H2 (`HookOpCount` discharged).** *What it says:* the evaluator's hook `Eval.opExec` answers, from a
state within the op limit, only states within it. *What it assumes:* nothing. *Why it matters:* the
hypothesis of R2a is met by the evaluator itself: no family moves the op count but the multisig, whose
charge is refused above the limit (H1, `1534–1536`).

`[SRC]` `interpreter.cpp:1534–1536`

### `hookMem_opExec` (`lean/BsvScript/Properties/Hooks.lean:1008`)

**H3 (`HookMem` discharged).** *What it says:* the evaluator's hook keeps the memory counter exact.
*What it assumes:* nothing. *Why it matters:* the hypothesis of R3b is met by the evaluator itself: every
family moves the stacks through the counted primitives only (`limitedstack.cpp:194–302`).

`[SRC]` `limitedstack.cpp:194–302`

### `loop_opCount_le_opExec` (`lean/BsvScript/Properties/Hooks.lean:1014`)

**H4 (R2a for the evaluator).** *What it says:* the evaluator's loop, from a state within the op
limit, returns a state at most one over it, whatever the outcome. *What it assumes:* nothing. *Why it
matters:* `loop_opCount_le` with its hook hypothesis discharged (H2): the op-count bound of `466–467` is a
property of the spec's evaluator, not of an assumed hook.

`[SRC]` `interpreter.cpp:466–467`

### `loop_memInv_opExec` (`lean/BsvScript/Properties/Hooks.lean:1023`)

**H5 (R3b for the evaluator).** *What it says:* the evaluator's loop keeps the memory counter equal to
the weights of both stacks. *What it assumes:* the counter exact at the start. *Why it matters:*
`loop_memInv` with its hook hypothesis discharged (H3): the memory the limit compares
(`limitedstack.h:163–173`) is the memory the stacks hold at every step of a phase that starts exact. The
unlocking phase does (`verifyScript` starts it on an empty stack at 0); the locking phase does when the
unlocking script left its alt stack empty, and not otherwise: the counter keeps the weight of elements
left there when a phase ends (`1993–2005`, `Machine.State`), so the locking phase then starts above its
stacks' weight by theirs, where this theorem's hypothesis fails.

`[SRC]` `limitedstack.h:163–173`, `interpreter.cpp:1993–2005`

### `checkSigOp_nullfail` (`lean/BsvScript/Properties/Hooks.lean:1037`)

**H6 (NULLFAIL under the gate, `OP_CHECKSIG`).** *What it says:* when both encodings pass and the
signature check fails on a non-empty signature, `OP_CHECKSIG`/`OP_CHECKSIGVERIFY` refuses
`SCRIPT_ERR_SIG_NULLFAIL` under `SCRIPT_VERIFY_NULLFAIL` and the version gate. *What it assumes:* two
elements, both encodings accepted, the failed check, the flag, the non-empty signature, the gate.
*Why it matters:* a failed signature must be empty for the script to go on (`1491–1497`), so a failing
`OP_CHECKSIG` cannot be turned into a `false` by a non-empty signature where the gate is on (before
Chronicle for every version, after it for a version of at most 1, `34–44`), the malleability NULLFAIL
closes.

`[SRC]` `interpreter.cpp:1491–1497`, `interpreter.cpp:34–44`

### `forIn_drop` (`lean/BsvScript/Properties/Hooks.lean:1063`)

A loop of steps that each pop one element pops as many as the list is long (the multisig's argument
pops, `1636–1653`).

`[SRC]` `interpreter.cpp:1636–1653`

### `checkMultiSigOp_nulldummy` (`lean/BsvScript/Properties/Hooks.lean:1088`)

**H7 (NULLDUMMY under the gate, `OP_CHECKMULTISIG`).** *What it says:* an `OP_CHECKMULTISIG`/
`OP_CHECKMULTISIGVERIFY` that succeeds under `SCRIPT_VERIFY_NULLDUMMY` and the version gate found the
element under its arguments empty: with `n` keys and `m` signatures read, the element `n + 2 + m` below
the top. *What it assumes:* the opcode succeeded, the flag, the gate. *Why it matters:* the extra element
the historical off-by-one pops (`1655–1672`: the comment on the bug, then the pop) is the malleability
NULLDUMMY closes where the flag is set. The flag is policy (the standard word only, `policy.h:182–189`;
never in the block word, `blockScriptFlags_policy_off`), so on the mempool path, where the gate is on, a
third party cannot vary it without the spend failing, while a block accepts a varied dummy (`1664` tests
the flag first).

`[SRC]` `interpreter.cpp:1655–1672`, `policy.h:182–189`, `interpreter.cpp:1664`

### `forIn_rangeFrom_guard` (`lean/BsvScript/Properties/Hooks.lean:1174`)

A loop over `List.range' start n` whose every successful step found its guard false and popped one
element found the guard false at every element, the guard reading the element then on top: the
`k`-th below the initial top.

### `checkMultiSigOp_nullfail` (`lean/BsvScript/Properties/Hooks.lean:1204`)

**H8 (NULLFAIL under the gate, `OP_CHECKMULTISIG`).** *What it says:* an `OP_CHECKMULTISIG` that
succeeds with a false result under `SCRIPT_VERIFY_NULLFAIL` and the version gate found every signature
empty: with `n` keys and `m` signatures read, the elements `n + 2` to `n + 1 + m` below the top.
*What it assumes:* the opcode `OP_CHECKMULTISIG` (its `VERIFY` form fails on a false result), its
success, the false result on top, the flag, the gate. *Why it matters:* the argument pops refuse a
non-empty signature after a failed check (`1641–1647`), so a failing multisig cannot carry a non-empty
signature where the gate is on, the malleability NULLFAIL closes (with H6 for `OP_CHECKSIG`).

`[SRC]` `interpreter.cpp:1641–1647`

## `BsvScript.Properties.KernelSample`

### `isPushOnly_eq_fuel` (`lean/BsvScript/Properties/KernelSample.lean:56`)

**`isPushOnly_eq_fuel`.** *What it says:* at any fuel at least the script's length, the fuel copy
answers what `isPushOnly` answers. *What it assumes:* the bound only. *Why it matters:* the kernel
reduces the copy, a structural recursion, where it does not reduce `isPushOnly`'s well-founded one;
a vector whose unlocking script the SIGPUSHONLY gate reads (`2321–2334`) is decided through it.

`[SRC]` `interpreter.cpp:2321–2334`

### `isPushOnly_eq_fuel_length` (`lean/BsvScript/Properties/KernelSample.lean:73`)

`isPushOnly_eq_fuel` at the script's own length: the form a vector's proof rewrites with.

### `loop_eq_fuel` (`lean/BsvScript/Properties/KernelSample.lean:104`)

**`loop_eq_fuel`.** *What it says:* at any fuel at least the script's length, the fuel copy
returns what the loop returns, the outcome and the final state. *What it assumes:* the bound only,
for every family hook `exec` and environment. *Why it matters:* the kernel reduces the copy, a
structural recursion, where it does not reduce the loop's well-founded one; every vector is decided
through it.

### `loop_eq_fuel_length` (`lean/BsvScript/Properties/KernelSample.lean:126`)

`loop_eq_fuel` at the script's own length: the form a vector's proof rewrites with.

### `vAdd_kernel` (`lean/BsvScript/Properties/KernelSample.lean:273`)

`2 3 OP_ADD 5 OP_NUMEQUAL` is valid (`1304–1306`, `1338–1341`).

`[SRC]` `interpreter.cpp:1304–1306`, `interpreter.cpp:1338–1341`

### `vModSign_kernel` (`lean/BsvScript/Properties/KernelSample.lean:279`)

`-7 2 OP_MOD -1 OP_EQUAL` is valid: the remainder takes the dividend's sign (`1324–1330`; post-Genesis the number is a big integer, `script_num.cpp:246`, `big_int.cpp:250–260`).

`[SRC]` `interpreter.cpp:1324–1330`, `script_num.cpp:246`, `big_int.cpp:250–260`

### `vDivZero_kernel` (`lean/BsvScript/Properties/KernelSample.lean:285`)

`1 0 OP_DIV` fails `SCRIPT_ERR_DIV_BY_ZERO` (`1316–1319`).

`[SRC]` `interpreter.cpp:1316–1319`

### `vNumEqVerify_kernel` (`lean/BsvScript/Properties/KernelSample.lean:291`)

`2 3 OP_NUMEQUALVERIFY` fails `SCRIPT_ERR_NUMEQUALVERIFY` (`1371–1377`).

`[SRC]` `interpreter.cpp:1371–1377`

### `vWithin_kernel` (`lean/BsvScript/Properties/KernelSample.lean:297`)

`5 3 7 OP_WITHIN` is valid: 3 ≤ 5 < 7 (`1380–1397`).

`[SRC]` `interpreter.cpp:1380–1397`

### `vNegZero_kernel` (`lean/BsvScript/Properties/KernelSample.lean:303`)

`<0x80> OP_1ADD 1 OP_NUMEQUAL` is valid: negative zero reads as zero on the block path, where MINIMALDATA is off (`1222–1240`, `script_num.cpp:67`).

`[SRC]` `interpreter.cpp:1222–1240`, `script_num.cpp:67`

### `vPick_kernel` (`lean/BsvScript/Properties/KernelSample.lean:309`)

`7 8 9 2 OP_PICK 7 OP_EQUAL` is valid: with the count popped, the element at depth 2 (the top at depth 0), the 7, is copied to the top (`1006–1027`).

`[SRC]` `interpreter.cpp:1006–1027`

### `vRot_kernel` (`lean/BsvScript/Properties/KernelSample.lean:315`)

`1 2 3 OP_ROT 1 OP_EQUAL` is valid: the third element moves to the top (`1029–1038`).

`[SRC]` `interpreter.cpp:1029–1038`

### `vDropEmpty_kernel` (`lean/BsvScript/Properties/KernelSample.lean:321`)

`OP_DROP` on an empty stack fails `SCRIPT_ERR_INVALID_STACK_OPERATION` (`972–978`).

`[SRC]` `interpreter.cpp:972–978`

### `vAlt_kernel` (`lean/BsvScript/Properties/KernelSample.lean:327`)

`5 OP_TOALTSTACK OP_FROMALTSTACK 5 OP_EQUAL` is valid: the round trip through the alt stack (`876–887`).

`[SRC]` `interpreter.cpp:876–887`

### `vFromAltEmpty_kernel` (`lean/BsvScript/Properties/KernelSample.lean:333`)

`OP_FROMALTSTACK` on an empty alt stack fails `SCRIPT_ERR_INVALID_ALTSTACK_OPERATION` (`883–887`).

`[SRC]` `interpreter.cpp:883–887`

### `vDepth_kernel` (`lean/BsvScript/Properties/KernelSample.lean:339`)

`1 1 OP_DEPTH 2 OP_EQUAL` is valid: the depth is pushed as a number (`966–970`).

`[SRC]` `interpreter.cpp:966–970`

### `vIfElse_kernel` (`lean/BsvScript/Properties/KernelSample.lean:345`)

`0 OP_IF 0 OP_ELSE 1 OP_ENDIF` is valid: the false branch is skipped, the else branch runs (`784–840`).

`[SRC]` `interpreter.cpp:784–840`

### `vNotifNested_kernel` (`lean/BsvScript/Properties/KernelSample.lean:351`)

`0 OP_NOTIF 1 OP_IF 1 OP_ENDIF OP_ELSE 0 OP_ENDIF` is valid: a nested conditional inside a taken `NOTIF` branch (`784–840`).

`[SRC]` `interpreter.cpp:784–840`

### `vUnclosedIf_kernel` (`lean/BsvScript/Properties/KernelSample.lean:357`)

`1 OP_IF 1` fails `SCRIPT_ERR_UNBALANCED_CONDITIONAL`: the script ends with the `IF` open (`1828–1830`).

`[SRC]` `interpreter.cpp:1828–1830`

### `vEndifAlone_kernel` (`lean/BsvScript/Properties/KernelSample.lean:363`)

`1 OP_ENDIF` fails `SCRIPT_ERR_UNBALANCED_CONDITIONAL`: no `IF` is open (`835–840`).

`[SRC]` `interpreter.cpp:835–840`

### `vVerifyFalse_kernel` (`lean/BsvScript/Properties/KernelSample.lean:369`)

`0 OP_VERIFY` fails `SCRIPT_ERR_VERIFY` (`842–854`).

`[SRC]` `interpreter.cpp:842–854`

### `vReturnSuffix_kernel` (`lean/BsvScript/Properties/KernelSample.lean:375`)

`1 OP_RETURN` followed by a truncated push is valid: a top-level `OP_RETURN` post-Genesis ends the script before the rest is parsed (`856–861`).

`[SRC]` `interpreter.cpp:856–861`

### `vFalseTop_kernel` (`lean/BsvScript/Properties/KernelSample.lean:381`)

`0` fails `SCRIPT_ERR_EVAL_FALSE`: the top is false when the locking script ends (`2374–2378`).

`[SRC]` `interpreter.cpp:2374–2378`

### `vCat_kernel` (`lean/BsvScript/Properties/KernelSample.lean:387`)

`<11> <22> OP_CAT <1122> OP_EQUAL` is valid (`1687–1706`).

`[SRC]` `interpreter.cpp:1687–1706`

### `vPushOnlyV1_kernel` (`lean/BsvScript/Properties/KernelSample.lean:393`)

An unlocking script `OP_1 OP_DUP` at version 1 fails `SCRIPT_ERR_SIG_PUSHONLY`: post-Chronicle the gate is on for version 1 (`2321–2334`); decided through `isPushOnly_eq_fuel`.

`[SRC]` `interpreter.cpp:2321–2334`

### `vPushOnlyV2_kernel` (`lean/BsvScript/Properties/KernelSample.lean:399`)

The same spend at version 2 is valid: the gate is off for a version above 1 post-Chronicle (`2321–2334`, `IsMalleableTxnVersion` at `34–38`).

`[SRC]` `interpreter.cpp:2321–2334`, `interpreter.cpp:34–38`

### `vMinimalV1Mempool_kernel` (`lean/BsvScript/Properties/KernelSample.lean:405`)

`<01 00> OP_1ADD 2 OP_NUMEQUAL` at version 1 on the mempool path fails `SCRIPT_ERR_SCRIPTNUM_MINENCODE`: MINIMALDATA under the gate (`433`, `script_num.cpp:67`).

`[SRC]` `interpreter.cpp:433`, `script_num.cpp:67`

### `vMinimalV2Mempool_kernel` (`lean/BsvScript/Properties/KernelSample.lean:411`)

The same at version 2 on the mempool path is valid: the gate clears MINIMALDATA (`433`, `40–44`).

`[SRC]` `interpreter.cpp:433`, `interpreter.cpp:40–44`

### `vMinimalV1Block_kernel` (`lean/BsvScript/Properties/KernelSample.lean:417`)

The same at version 1 on the block path is valid: MINIMALDATA is policy, absent from the block word (`policy.h:182–189`, `433`).

`[SRC]` `policy.h:182–189`, `interpreter.cpp:433`

### `vectors_kernel` (`lean/BsvScript/Properties/KernelSample.lean:423`)

**`vectors_kernel`.** *What it says:* the Boolean the flow leg computes over the sample, every
vector's verdict equal to its expected one, is `true` on the definitions. *What it assumes:*
nothing. *Why it matters:* it ties the list the compiled evaluator runs (`Test/FlowCheck.lean`,
`kernelSamplePart`) to the kernel's verdicts vector by vector: the leg's agreement is a comparison
with these theorems, not with numbers written twice.

## `BsvScript.Properties.P2SH`

### `isP2SH_of_shape` (`lean/BsvScript/Properties/P2SH.lean:52`)

**The P2SH shape** (`IsP2SH`, `script.cpp:168–172`): `OP_HASH160`, a 20-byte push, `OP_EQUAL`.

`[SRC]` `script.cpp:168–172`

### `p2shCopy_iff` (`lean/BsvScript/Properties/P2SH.lean:57`)

The copy for the P2SH evaluation is taken exactly when the flag is set and the coin is
pre-Genesis (`2354–2356`), the two bits read ungated.

`[SRC]` `interpreter.cpp:2354–2356`

### `p2shCopy_of_utxoAfterGenesis` (`lean/BsvScript/Properties/P2SH.lean:62`)

**No copy for a coin created after Genesis**, whatever the flag (`2355`).

`[SRC]` `interpreter.cpp:2355`

### `forkAdjust_p2shCopy` (`lean/BsvScript/Properties/P2SH.lean:66`)

STRICTENC-from-FORKID (`2315–2319`) touches neither bit of the copy test.

`[SRC]` `interpreter.cpp:2315–2319`

### `phase2_of_not_p2shCopy` (`lean/BsvScript/Properties/P2SH.lean:91`)

**P2SH is disabled without the copy** (`2380–2383`): when no stack copy was taken, the
redeem script is never deserialized or evaluated, the P2SH shape of the locking script is
never consulted, and the phase is the plain one.

`[SRC]` `interpreter.cpp:2380–2383`

### `phase2_p2sh_disabled_postGenesis` (`lean/BsvScript/Properties/P2SH.lean:109`)

**A P2SH-shaped output created after Genesis is a hash puzzle** (`2355`, `2383` with the
UTXO marker set): the spend is judged as a plain script, the redeem script never runs.

`[SRC]` `interpreter.cpp:2355`, `interpreter.cpp:2383`

### `verifyScript_p2sh_disabled_postGenesis` (`lean/BsvScript/Properties/P2SH.lean:134`)

**Disabled for new outputs, at the verdict** (`2354–2356`, `2380–2383`): for a coin
created after Genesis, `VerifyScript` never evaluates a redeem script, whatever the locking
script's shape and whatever the P2SH flag and the spend era.

`[SRC]` `interpreter.cpp:2354–2356`, `interpreter.cpp:2380–2383`

### `derive_p2shCopy_grandfathered_block` (`lean/BsvScript/Properties/P2SH.lean:149`)

**A pre-Genesis coin keeps the P2SH copy when spent in any later era, on the block path**,
from block `p2shHeight + 1` on (`flagWord_block_p2sh`; the UTXO marker off, `policy.h:234–237`).

`[SRC]` `policy.h:234–237`

### `flagWord_mempool_p2sh` (`lean/BsvScript/Properties/P2SH.lean:162`)

P2SH is in every mempool word a node derives with no promiscuous word (`hp`): it is mandatory in both eras
(`standard.h:56`, `standard.h:63`, `policy.h:191–197`). A `-promiscuousmempoolflags` word replaces the mempool word
on a chain that does not require standardness (`verify_script_flags.cpp:19–25`) and need not carry P2SH.

`[SRC]` `standard.h:56`, `standard.h:63`, `policy.h:191–197`, `verify_script_flags.cpp:19–25`

### `derive_p2shCopy_grandfathered_mempool` (`lean/BsvScript/Properties/P2SH.lean:172`)

**A pre-Genesis coin keeps the P2SH copy on the mempool path too**, at every spend height, on a node with no
promiscuous word (`hp`). On a chain whose `RequireStandard()` is false a promiscuous word replaces the mempool word
(`verify_script_flags.cpp:21–25`): one carrying `SCRIPT_UTXO_AFTER_GENESIS`, or lacking P2SH, takes the copy away
on that node's mempool path (`interpreter.cpp:2354–2356`).

`[SRC]` `verify_script_flags.cpp:21–25`, `interpreter.cpp:2354–2356`

### `derive_p2shCopy_postGenesis_coin` (`lean/BsvScript/Properties/P2SH.lean:187`)

**A coin created after Genesis never gets the copy, on either path** (`2355`).

`[SRC]` `interpreter.cpp:2355`

### `checkRegularTransaction_p2sh_output` (`lean/BsvScript/Properties/P2SH.lean:198`)

**No regular transaction creates a P2SH-shaped output once Genesis is active**
(`CheckRegularTransaction`, `validation.cpp:609–622`: `bad-txns-vout-p2sh`, `DoS(100)`,
`REJECT_INVALID`; the era is the block's or the next block's, `validation.cpp:1031`): given the checks before it pass.

`[SRC]` `validation.cpp:609–622`, `validation.cpp:1031`

## `BsvScript.Properties.Resources`

### `evalScript_scriptSize` (`lean/BsvScript/Properties/Resources.lean:27`)

**R1 (the script-size gate).** *What it says:* the spec's `evalScript` refuses a script longer than
`MaxScriptSize` before reading a byte (`429–430`), `SCRIPT_ERR_SCRIPT_SIZE`, with the state as it
was handed in. *What it assumes:* nothing. *Why it matters:* the limit is per script (the unlocking
and the locking script separately), read from the era's parameters (`docs/PARAMETERS.md` §1). The
reference's `EvalScript` tests one thing before it, a flag word that marks the UTXO post-Chronicle and
not post-Genesis (`SCRIPT_ERR_INVALID_FLAGS`, `413–414`); the spec tests that once, in `verifyScript`
before any call (`valid_flags`, `2312–2313`), so on every call `VerifyScript` makes the two agree.

`[SRC]` `interpreter.cpp:429–430`, `interpreter.cpp:413–414`, `interpreter.cpp:2312–2313`

### `evalScript_of_size_le` (`lean/BsvScript/Properties/Resources.lean:40`)

**R1a.** Within the limit the spec's `evalScript` is the loop on the fresh state (`1984–2006`, `407`):
in the spec the size gate is the only thing between the call and the first instruction (the reference's
`EvalScript` refuses an invalid pair of UTXO markers first, `413–414`, which `verifyScript` has refused
before any call, `2312–2313`).

`[SRC]` `interpreter.cpp:1984–2006`, `interpreter.cpp:407`, `interpreter.cpp:413–414`, `interpreter.cpp:2312–2313`

### `loop_opCount` (`lean/BsvScript/Properties/Resources.lean:52`)

**R2 (the op count's refusal).** *What it says:* every opcode above `OP_16` is charged to the op
count before the disabled test and the step, executed or not (`466–467`), and the instruction that
takes the count over `MaxOpsPerScript` fails `SCRIPT_ERR_OP_COUNT` with the count already charged
(`377–380`). *What it assumes:* the instruction parses and passes the pre-Genesis push-size test.
*Why it matters:* the limit counts instructions, not executed ones; a dead branch costs the same.

`[SRC]` `interpreter.cpp:466–467`, `interpreter.cpp:377–380`

### `pushElem_ok` (`lean/BsvScript/Properties/Resources.lean:72`)

A push's result, explicitly (`limitedstack.h:163–173`): the element on top, the counter grown by its
weight.

`[SRC]` `limitedstack.h:163–173`

### `pushElem_opCount` (`lean/BsvScript/Properties/Resources.lean:83`)

A push leaves the op count as it was (only the stack and the counter move, `limitedstack.h:163–173`).

`[SRC]` `limitedstack.h:163–173`

### `execIf_opCount` (`lean/BsvScript/Properties/Resources.lean:88`)

`OP_IF` and its three siblings leave the op count as they found it (`784–825`: the tracker and one pop).

`[SRC]` `interpreter.cpp:784–825`

### `execCltv_opCount` (`lean/BsvScript/Properties/Resources.lean:97`)

`OP_CHECKLOCKTIMEVERIFY` leaves the op count as it found it (`519–560`: it only reads the stack).

`[SRC]` `interpreter.cpp:519–560`

### `execCsv_opCount` (`lean/BsvScript/Properties/Resources.lean:105`)

`OP_CHECKSEQUENCEVERIFY` leaves the op count as it found it (`562–597`: it only reads the stack).

`[SRC]` `interpreter.cpp:562–597`

### `execFlow_preserves` (`lean/BsvScript/Properties/Resources.lean:113`)

**The machine's own switch, branch by branch** (`483–871`): a property of states that holds of the
state handed in, of every push's result, of the three checkers' results (`execCltv`, `execCsv`,
`execIf`), of the tracker and `OP_RETURN` updates, of `OP_VERIFY`'s pop and of the hook's answer holds
of every state `execFlow` continues with. Walked `if` by `if` (`split_ifs` on the thirteen-way chain
times out), so each of R2 and R3 discharges the branches once.

`[SRC]` `interpreter.cpp:483–871`

### `execFlow_opCount` (`lean/BsvScript/Properties/Resources.lean:204`)

The machine's own switch keeps the op count within the limit; the hook by `HookOpCount`.

### `execStep_opCount` (`lean/BsvScript/Properties/Resources.lean:215`)

`execStep` keeps the op count within the limit under `HookOpCount` (`473–482`, `1445–1448`).

`[SRC]` `interpreter.cpp:473–482`, `interpreter.cpp:1445–1448`

### `loop_opCount_le` (`lean/BsvScript/Properties/Resources.lean:230`)

**R2a (the op count's invariant).** *What it says:* under `HookOpCount`, from a state within the
limit the loop returns a state at most one over it, whatever the outcome (the one over is the
refusal's own state, R2; every step is handed a state within the limit). *What it assumes:* the hook
hypothesis. *Why it matters:* the count bounds the instructions of a script, so a verifier that must
fit `MaxOpsPerScript` can read its budget off the state at any step. Induction on a bound of the
script length, as `loop_ne_unimplemented`.

### `pushElem_stackSize_iff` (`lean/BsvScript/Properties/Resources.lean:278`)

**R3 (the memory refusal).** *What it says:* a push fails `SCRIPT_ERR_STACK_SIZE` exactly when the
counter plus the element's weight would exceed `MaxStackMemoryUsage` (`limitedstack.h:163–173`,
`limitedstack.cpp:194–207`, `1815–1818`). *What it assumes:* nothing. *Why it matters:* the limit is
on bytes plus 32 per element, not on the element count; with R3b the counter it compares is the
sum over both stacks in a phase that starts exact (not in the locking phase after an unlocking script
that left elements on its alt stack, R3b).

`[SRC]` `limitedstack.h:163–173`, `limitedstack.cpp:194–207`, `interpreter.cpp:1815–1818`

### `pushElem_memInv` (`lean/BsvScript/Properties/Resources.lean:296`)

**R3a.** A push keeps the invariant: the counter grows by the element's weight (`limitedstack.h:171`).

`[SRC]` `limitedstack.h:171`

### `popElem_memInv` (`lean/BsvScript/Properties/Resources.lean:304`)

A pop keeps the invariant: the counter shrinks by the element's weight (`limitedstack.cpp:211–219`).

`[SRC]` `limitedstack.cpp:211–219`

### `toAlt_memInv` (`lean/BsvScript/Properties/Resources.lean:317`)

A move to the alt stack keeps the invariant: nothing is charged (`876–881`; the weight moves from
one sum to the other).

`[SRC]` `interpreter.cpp:876–881`

### `fromAlt_memInv` (`lean/BsvScript/Properties/Resources.lean:331`)

A move back from the alt stack keeps the invariant (`883–888`).

`[SRC]` `interpreter.cpp:883–888`

### `sum_map_set` (`lean/BsvScript/Properties/Resources.lean:344`)

The weight sum after `set`: the old element's weight out, the new one's in.

### `sum_map_eraseIdx` (`lean/BsvScript/Properties/Resources.lean:357`)

The weight sum after `eraseIdx`: the erased element's weight out.

### `sum_map_insertIdx` (`lean/BsvScript/Properties/Resources.lean:370`)

The weight sum after `insertIdx`: the inserted element's weight in.

### `eraseTop_memInv` (`lean/BsvScript/Properties/Resources.lean:385`)

An erase below the top keeps the invariant (`limitedstack.cpp:260–267`): the element's weight is
released.

`[SRC]` `limitedstack.cpp:260–267`

### `insertTop_memInv` (`lean/BsvScript/Properties/Resources.lean:397`)

An insert below the top keeps the invariant (`limitedstack.cpp:269–283`): charged like a push.

`[SRC]` `limitedstack.cpp:269–283`

### `swapTop_memInv` (`lean/BsvScript/Properties/Resources.lean:413`)

A swap keeps the invariant: nothing moves in the sums (`limitedstack.cpp:285–288`).

`[SRC]` `limitedstack.cpp:285–288`

### `execIf_memInv` (`lean/BsvScript/Properties/Resources.lean:428`)

`OP_IF` and its three siblings keep the accounting invariant (`784–825`: one pop, its weight released, or nothing).

`[SRC]` `interpreter.cpp:784–825`

### `execCltv_memInv` (`lean/BsvScript/Properties/Resources.lean:444`)

`OP_CHECKLOCKTIMEVERIFY` keeps the accounting invariant (`519–560`: it leaves the operand where it is).

`[SRC]` `interpreter.cpp:519–560`

### `execCsv_memInv` (`lean/BsvScript/Properties/Resources.lean:452`)

`OP_CHECKSEQUENCEVERIFY` keeps the accounting invariant (`562–597`: it leaves the operand where it is).

`[SRC]` `interpreter.cpp:562–597`

### `execFlow_memInv` (`lean/BsvScript/Properties/Resources.lean:465`)

The machine's own switch keeps the invariant; the hook by `HookMem`.

### `execStep_memInv` (`lean/BsvScript/Properties/Resources.lean:481`)

`execStep` keeps the invariant under `HookMem` (`473–482`: the push; `1445–1448`: the separator
touches no stack).

`[SRC]` `interpreter.cpp:473–482`, `interpreter.cpp:1445–1448`

### `loop_memInv` (`lean/BsvScript/Properties/Resources.lean:497`)

**R3b (the accounting invariant).** *What it says:* under `HookMem`, from an exact counter the loop
returns an exact counter whatever the outcome (an error returns the state of the step that failed,
exact as well). *What it assumes:* the hook hypothesis. *Why it matters:* `MaxStackMemoryUsage` is
compared against `memUsed` (R3); this theorem says that, from an exact start, that number stays the sum
of the elements' weights on both stacks, so within a phase that starts exact the limit is a statement
about the stacks, not about a counter. A phase need not start exact: the counter keeps the weight of
elements left on the alt stack when a phase ends (`1993–2005`, `Machine.State`), in the reference as in
the spec, so after an unlocking script that left some there the locking phase compares a counter above
its stacks' weight (H5).

`[SRC]` `interpreter.cpp:1993–2005`

### `loop_stackSize_preGenesis` (`lean/BsvScript/Properties/Resources.lean:538`)

**R4 (the depth refusal).** *What it says:* on a pre-Genesis coin a step that leaves more than
`MAX_STACK_ELEMENTS_BEFORE_GENESIS` = 1,000 elements on the two stacks fails `SCRIPT_ERR_STACK_SIZE`
(`1800–1803`, `script.h:32`) with the state the step left; stated for an instruction at or below
`OP_16` (a push: no op count, never disabled), the case that adds the 1,001st element by a push.
*What it assumes:* the instruction parses and passes the push-size test, and the step continues.
*Why it matters:* pre-Genesis the element count is the limit (the memory budget is unlimited there,
`docs/PARAMETERS.md` §1).

`[SRC]` `interpreter.cpp:1800–1803`, `script.h:32`

### `loop_depth_preGenesis` (`lean/BsvScript/Properties/Resources.lean:563`)

**R4a (the depth invariant).** *What it says:* on a pre-Genesis coin, from at most 1,000 elements
the loop returns at most 1,000 when it succeeds, for EVERY hook: the loop checks the depth after each
step (`1800–1803`) before continuing. *What it assumes:* nothing about the families. *Why it
matters:* the bound is the loop's, not the opcodes'.

`[SRC]` `interpreter.cpp:1800–1803`

### `checkMultiSigOp_pubkeyCount` (`lean/BsvScript/Properties/Resources.lean:595`)

**R5 (the key count).** *What it says:* `OP_CHECKMULTISIG` refuses a key count above
`MaxPubKeysPerMultiSig` as `SCRIPT_ERR_PUBKEY_COUNT` (`1530–1532`), after the count's read (`1519–1526`) and
its sign test (`1527–1528`), before any key or signature is read.
*What it assumes:* the count reads (`readCount`, width 4 under the minimal rule). *Why it matters:*
pre-Genesis the limit is 20 (`consensus.h:50`); post-Genesis it is the consensus constant `UINT32_MAX` on
the block path (`consensus.h:55`, `configscriptpolicy.cpp:131–134`) and the node's policy setting on the
mempool path (`configscriptpolicy.cpp:136`; default `UINT32_MAX`, `policy.h:150`; `docs/PARAMETERS.md`
§1).

`[SRC]` `interpreter.cpp:1530–1532`, `interpreter.cpp:1519–1526`, `interpreter.cpp:1527–1528`, `consensus.h:50`, `consensus.h:55`, `configscriptpolicy.cpp:131–134`, `configscriptpolicy.cpp:136`, `policy.h:150`

### `checkMultiSigOp_pubkeyCount_neg` (`lean/BsvScript/Properties/Resources.lean:612`)

**R5a (a negative key count).** *What it says:* a negative key count is `SCRIPT_ERR_PUBKEY_COUNT`
(`1527–1528`).

`[SRC]` `interpreter.cpp:1527–1528`

### `checkMultiSigOp_opCount` (`lean/BsvScript/Properties/Resources.lean:621`)

**R5b (the op count).** *What it says:* the key count is charged to the op count and the
instruction fails `SCRIPT_ERR_OP_COUNT` when the charged count exceeds `MaxOpsPerScript`
(`1534–1536`), after the key-count test and before any key is read. *What it assumes:* the count
reads and is within `MaxPubKeysPerMultiSig`. *Why it matters:* this is the one opcode that charges
more than one to the count; it is why `HookOpCount` is a hypothesis of R2a and this theorem its
discharge for the refusal side.

`[SRC]` `interpreter.cpp:1534–1536`

### `pushElem_ne_scriptnumOverflow` (`lean/BsvScript/Properties/Resources.lean:639`)

A push never answers `SCRIPT_ERR_SCRIPTNUM_OVERFLOW`: its only error is the memory budget's.

### `pushResult_overflow_iff` (`lean/BsvScript/Properties/Resources.lean:646`)

**R6 (the result-width bound).** *What it says:* post-Genesis a bounded arithmetic result
(`+=`, `-=`, `*=`) whose minimal encoding exceeds `MaxScriptNumLength` is `SCRIPT_ERR_SCRIPTNUM_OVERFLOW`
(`script_num.cpp:144–222`, the checks at `script_num.cpp:166–167`, `script_num.cpp:196–197`, `script_num.cpp:216–217`, reached through the by-value
copies at `script_num.h:114–130` in the binary family, `interpreter.cpp:1305`, `1309`, `1313`, and directly in
the unary one, `1238–1245`, `1249`; thrown at the arithmetic, before the pops and the push, `1273–1274` in the unary
family and `1367–1369` in the binary one), and that is the only way `pushResult` answers that error.
*What it assumes:* nothing. *Why it matters:* the width in force (on the block path the consensus width,
750,000 bytes post-Genesis and 32,000,000 post-Chronicle, `configscriptpolicy.cpp:88–95`; on the mempool
path the node's policy setting, default 10,000, `policy.h:156`, `configscriptpolicy.cpp:97–109`;
`docs/PARAMETERS.md` §1) bounds every arithmetic result the machine will hold; pre-Genesis the `int64`
branch cannot overflow.

`[SRC]` `script_num.cpp:144–222`, `script_num.cpp:166–167`, `script_num.cpp:196–197`, `script_num.cpp:216–217`, `script_num.h:114–130`, `interpreter.cpp:1305`, `interpreter.cpp:1309`, `interpreter.cpp:1313`, `interpreter.cpp:1238–1245`, `interpreter.cpp:1249`, `interpreter.cpp:1273–1274`, `interpreter.cpp:1367–1369`, `configscriptpolicy.cpp:88–95`, `policy.h:156`, `configscriptpolicy.cpp:97–109`

### `pushResult_ok` (`lean/BsvScript/Properties/Resources.lean:674`)

**R6a.** A result the push accepts is on the stack at its minimal encoding, within the width in force
when bounded post-Genesis.

### `pushBool_shape` (`lean/BsvScript/Properties/Resources.lean:692`)

**R6b (the boolean shape).** *What it says:* `pushBool` leaves `[0x01]` for true and `[]` for false on
top: `OP_WITHIN`'s push, `vchTrue` or `vchFalse` (`interpreter.cpp:402–403`, `1396`); `within` and its
compiled copy are `pushBool`'s only callers. The comparisons and the unary family's booleans leave the same
two byte strings by another road, an `int64` `1` or `0` (`script_num.h:65–69`) pushed through
`pushResult`, which this theorem does not carry.

`[SRC]` `interpreter.cpp:402–403`, `interpreter.cpp:1396`, `script_num.h:65–69`

## `BsvScript.Properties.Sighash`

### `scriptCode_unlock_site` (`lean/BsvScript/Properties/Sighash.lean:41`)

**`scriptCode_unlock_site`.** *The rule:* the scriptCode a signature check builds is `codeSep` (the reference's
`{pbegincodehash, pend}`; what writes `codeSep` is `codeSep_sites`, and the whole run is `scriptCode_last`),
with the locking script appended when the check executes inside the unlocking script under `SCRIPT_CHRONICLE`.
*What it says:* in the environments `verifyScript` builds from the word `params.flags` (after STRICTENC from
FORKID, `Flags.forkAdjust`), the unlocking phase's, whose `checksigData` is the locking script, and the locking
and P2SH-redeem phases', whose `checksigData` is none (`Machine.lean`'s `phase2` builds that one twice),
`scriptCodeOf` is `codeSep ++ scriptPubKey` in the unlocking phase with the CHRONICLE bit set, `codeSep` in the
unlocking phase without it, and `codeSep` in the locking phase. *What it assumes:* nothing beyond the word: every
parameter record, context, locking script and state. [SRC] `1471–1481` (`CScript scriptCode {pbegincodehash,
pend}`; `if(checksigData && IsChronicle(flags)) scriptCode += *checksigData`) and of `OP_CHECKMULTISIG`
(`1567–1577`); `2338–2342` (the unlocking script evaluated with `&scriptPubKey` as `checksigData`); `2358–2362`
and `2402–2406` (the locking script and the P2SH redeem script evaluated with `nullptr` as `checksigData`);
`1445–1448` (`pbegincodehash`). *Measured contradiction:* go-sdk v1.7.2 hashes the source output's locking
script as the scriptCode on its default path (`transaction/signaturehash.go:277-299`), class
`sighash.scriptcode.in-unlock.lock-only`; at @bsv/sdk 3.0.0 the caller supplies the subscript
(`primitives/TransactionSignature.ts:262,394-396`), the class ruled `caller-scriptcode-required`
(`docs/records/20261016-203024-s3-145d-signer-column-s3.md`); bsv-rs 0.5.0 selects the source locking script
(`src/script/template.rs:85-99`), the same lock-only class (`docs/records/20261016-234915-s3-147-signer-column-s3.md`).

`[SRC]` `interpreter.cpp:1471–1481`, `interpreter.cpp:1567–1577`, `interpreter.cpp:2338–2342`, `interpreter.cpp:2358–2362`, `interpreter.cpp:2402–2406`, `interpreter.cpp:1445–1448`, `transaction/signaturehash.go:277-299`, `src/script/template.rs:85-99`

### `codeSep_sites` (`lean/BsvScript/Properties/Sighash.lean:74`)

**`codeSep_sites`.** *The rule:* `codeSep` is the script from the last executed `OP_CODESEPARATOR`, the whole
script before any. *What it says:* the two sites that write it: `evalScript` starts the loop with `codeSep` the
whole script (within the size limit), an executed separator sets it to the bytes after itself, and an unexecuted
one (an inactive branch) leaves the state as it was. *What it assumes:* the script within `maxScriptSize` for the
opening clause; nothing for the other two. [SRC] `407` (`pbegincodehash = script.begin()`), `1445–1448`
(`pbegincodehash = pc`), `482` (the switch runs only under `fExec` or for `OP_IF`…`OP_ENDIF`). The opcodes other
than the separator do not write `codeSep` (`execStep_codeSep`); the whole run is `codeSep_last`.

`[SRC]` `interpreter.cpp:407`, `interpreter.cpp:1445–1448`, `interpreter.cpp:482`

### `scriptCode_unlock_site_forkid` (`lean/BsvScript/Properties/Sighash.lean:91`)

**`scriptCode_unlock_site_forkid`.** *The rule:* under FORKID a signature carrying the FORKID bit digests the
scriptCode uncleaned. *What it says:* with `SCRIPT_ENABLE_SIGHASH_FORKID` and `SCRIPT_CHRONICLE` in the word and a
signature whose hash type has the FORKID bit, the bytes `checkSigOp` hands its checker in the unlocking phase,
`cleanupScriptCode (scriptCodeOf env st) sig forkid`, are `codeSep ++ scriptPubKey`. *What it assumes:* the two
bits and the signature's FORKID bit. [SRC] `1471–1481`, `1484`, `255–263` (`CleanupScriptCode` deletes the
signature only when FORKID is off or the type lacks it), `2338–2342`.

`[SRC]` `interpreter.cpp:1471–1481`, `interpreter.cpp:1484`, `interpreter.cpp:255–263`, `interpreter.cpp:2338–2342`

### `opExec_codeSep` (`lean/BsvScript/Properties/Sighash.lean:111`)

**`opExec_codeSep`.** *The rule:* no opcode family writes the scriptCode's start; only the loop's own
separator does (`1445–1448`). *What it says:* every state the evaluator's hook `Eval.opExec` continues with has
the `codeSep` it was handed. *What it assumes:* nothing. [SRC] `1445–1448` (the one `pbegincodehash = pc` of
the switch); the families' frames (`Properties.Hooks`, `Frame`, `checkMultiSigOp_ok`).

`[SRC]` `interpreter.cpp:1445–1448`

### `execIf_codeSep` (`lean/BsvScript/Properties/Sighash.lean:119`)

`OP_IF` and its three siblings leave `codeSep` as they found it (`784–854`: the tracker and one pop).

`[SRC]` `interpreter.cpp:784–854`

### `execCltv_codeSep` (`lean/BsvScript/Properties/Sighash.lean:128`)

`OP_CHECKLOCKTIMEVERIFY` leaves `codeSep` as it found it (`519–560`).

`[SRC]` `interpreter.cpp:519–560`

### `execCsv_codeSep` (`lean/BsvScript/Properties/Sighash.lean:137`)

`OP_CHECKSEQUENCEVERIFY` leaves `codeSep` as it found it (`562–597`).

`[SRC]` `interpreter.cpp:562–597`

### `execFlow_codeSep` (`lean/BsvScript/Properties/Sighash.lean:146`)

The machine's own switch leaves `codeSep` as it found it, the hook under its frame hypothesis
(`483–871`).

`[SRC]` `interpreter.cpp:483–871`

### `execStep_codeSep` (`lean/BsvScript/Properties/Sighash.lean:159`)

**`execStep_codeSep`.** *The rule:* an instruction other than an executed `OP_CODESEPARATOR` leaves the
scriptCode's start where it was. *What it says:* when `execStep` continues, the state's `codeSep` is the one it
was handed unless the opcode is `OP_CODESEPARATOR` and `fExec` holds (that site is `codeSep_sites`): the push
branch, the switch and the hook, the latter under the frame hypothesis `opExec_codeSep` discharges for the
evaluator. *What it assumes:* the hook's frame. [SRC] `473–481` (the push), `1445–1448` (the separator, the one
writer), `482` (the switch under `fExec` or for `OP_IF`…`OP_ENDIF`).

`[SRC]` `interpreter.cpp:473–481`, `interpreter.cpp:1445–1448`, `interpreter.cpp:482`

### `LoopReach.loop_eq` (`lean/BsvScript/Properties/Sighash.lean:203`)

**`LoopReach.loop_eq`.** *What it says:* every configuration `LoopReach` names is one the loop passes
through: the loop from the start returns what it returns from there. *What it assumes:* nothing.

### `afterLastSep_snoc` (`lean/BsvScript/Properties/Sighash.lean:232`)

**`afterLastSep_snoc`.** *What it says:* `afterLastSep` of a trace with one more instruction is that
instruction's offset plus one if it is an executed separator, else the trace's. *What it assumes:* nothing.

### `LoopTrace.reach` (`lean/BsvScript/Properties/Sighash.lean:264`)

**`LoopTrace.reach`.** *What it says:* a traced configuration is a reached one (`LoopReach`), so
`LoopReach.loop_eq` applies to it. *What it assumes:* nothing.

### `LoopReach.trace` (`lean/BsvScript/Properties/Sighash.lean:272`)

**`LoopReach.trace`.** *What it says:* every reached configuration has its trace. *What it assumes:* nothing.

### `drop_of_suffix` (`lean/BsvScript/Properties/Sighash.lean:281`)

**`drop_of_suffix`.** *What it says:* a suffix `s` of `s₀` is `s₀` from the offset `s₀.length - s.length`, the
offset of the current instruction. *What it assumes:* nothing.

### `codeSep_last` (`lean/BsvScript/Properties/Sighash.lean:288`)

**`codeSep_last`.** *The rule:* the scriptCode a signature check digests begins after the last executed
`OP_CODESEPARATOR` before the check, or at the script's start when none executed: `pbegincodehash` is set to
`script.begin()` and moved only by an executed `OP_CODESEPARATOR`, to the byte after it. *What it says:* for every
hook `exec` whose continuations leave `codeSep` as they found it (the frame `opExec_codeSep` proves for the
evaluator's own table, `Eval.opExec`), every run of `loop exec env` from a state whose `codeSep` is the script `s₀`
(as `evalScript` starts it, `codeSep_sites`) and every configuration `(s, st)` it reaches through the trace `tr`:
`st.codeSep` is `s₀` from the offset `afterLastSep tr`, the offset after the trace's last executed separator or `0`;
that offset is at or before the current instruction's, `s₀.length - s.length`; and `s` is `s₀` from that
instruction's offset. *What it assumes:* the hook's frame and the start. [SRC] `405–407` (`pc` and
`pbegincodehash` both `script.begin()`), `450` (`GetOp(pc, …)` advances `pc` past the instruction), `459`
(`fExec`), `482` (the switch runs only under `fExec` or for `OP_IF`…`OP_ENDIF`), `1445–1448` (`case
OP_CODESEPARATOR: pbegincodehash = pc;`), `1471–1473` and `1567–1569` ("Subset of script starting at the most
recent codeseparator to the end of the current script", `CScript scriptCode {pbegincodehash, pend}`). *Measured
contradiction:* none of the three signers measured under #145 and #147 is classed on the separator; their class,
`sighash.scriptcode.in-unlock.lock-only` (at @bsv/sdk 3.0.0 ruled `caller-scriptcode-required`, the class id
unchanged), is which script the scriptCode is drawn from (`scriptCode_run`, `scriptCode_last`)
(`docs/records/20261016-203024-s3-145d-signer-column-s3.md`, `docs/records/20261016-234915-s3-147-signer-column-s3.md`),
and @bsv/sdk's appended-lock behaviour (2.1.5 to 3.2.1)
(`docs/records/20261016-234806-s4b-147-tssdk-releases-s4b.md`) is that same scriptCode question, not a separator
one.

`[SRC]` `interpreter.cpp:405–407`, `interpreter.cpp:450`, `interpreter.cpp:459`, `interpreter.cpp:482`, `interpreter.cpp:1445–1448`, `interpreter.cpp:1471–1473`, `interpreter.cpp:1567–1569`

### `codeSep_run_suffix` (`lean/BsvScript/Properties/Sighash.lean:358`)

**`codeSep_run_suffix`.** *The rule:* along a run, the scriptCode's start is a suffix of the script and the
instruction being run lies inside it (`407`, `1445–1448`). *What it says:* for every configuration the
evaluator's loop reaches from a state whose `codeSep` is the script `s₀` (as `evalScript` starts it,
`codeSep_sites`), `codeSep` is a suffix of `s₀` and the remaining bytes are a suffix of `codeSep`; a corollary of
`codeSep_last`, which names the suffix: `s₀` from the offset after the last executed separator. *What it
assumes:* the start. [SRC] `407` (`pbegincodehash = script.begin()`), `1445–1448` (`pbegincodehash = pc`, the
byte after the separator), `482`.

`[SRC]` `interpreter.cpp:407`, `interpreter.cpp:1445–1448`, `interpreter.cpp:482`

### `scriptCode_last` (`lean/BsvScript/Properties/Sighash.lean:377`)

**`scriptCode_last`.** *The rule:* the scriptCode a signature check digests is the script being run from the
byte after its last executed `OP_CODESEPARATOR` before the check (from its start when none executed), with the
locking script appended when the check runs inside the unlocking script under `SCRIPT_CHRONICLE`. *What it says:*
`codeSep_last` composed with `scriptCode_unlock_site` at the state the check reads: in the environments
`verifyScript` builds from the word, for a run of the evaluator's loop over `script` from `evalScript`'s start state
(any stack and memory counter) that reaches the instruction `op` (an `OP_CHECKSIG`, `OP_CHECKSIGVERIFY`,
`OP_CHECKMULTISIG`, `OP_CHECKMULTISIGVERIFY` or any other) through the trace `tr`, the scriptCode of the state
handed to `op`'s step (the reached state with the op count's charge, `466–467`) is `script.drop (afterLastSep tr)
++ scriptPubKey` in the unlocking phase under CHRONICLE, `script.drop (afterLastSep tr)` in it without the bit, and
`script.drop (afterLastSep tr)` in the locking and P2SH-redeem phases (`checksigData` none). The bytes are those
before `CleanupScriptCode` (`1484`; the FORKID form is `scriptCode_unlock_site_forkid`). *What it assumes:* the
run from the start state. [SRC] `405–407`, `450`, `1445–1448`, `1471–1481` and `1567–1577` (the scriptCode and the
CHRONICLE append), `2338–2342` (the unlocking script with `&scriptPubKey`), `2358–2362` and `2402–2406` (`nullptr`).
*Measured contradiction:* `sighash.scriptcode.in-unlock.lock-only` (go-sdk v1.7.2, bsv-rs 0.5.0; at @bsv/sdk 3.0.0
`caller-scriptcode-required`), which is the which-script half of this statement, not the separator half
(`docs/records/20261016-203024-s3-145d-signer-column-s3.md`, `docs/records/20261016-234915-s3-147-signer-column-s3.md`).

`[SRC]` `interpreter.cpp:466–467`, `interpreter.cpp:1484`, `interpreter.cpp:405–407`, `interpreter.cpp:450`, `interpreter.cpp:1445–1448`, `interpreter.cpp:1471–1481`, `interpreter.cpp:1567–1577`, `interpreter.cpp:2338–2342`, `interpreter.cpp:2358–2362`, `interpreter.cpp:2402–2406`

### `scriptCode_run` (`lean/BsvScript/Properties/Sighash.lean:426`)

**`scriptCode_run`.** *The rule:* a signature check that executes while the unlocking script runs under
`SCRIPT_CHRONICLE` digests the unlocking script from its scriptCode's start, which lies at or before the check
itself, followed by the locking script; so its scriptCode is never the locking script alone. *What it says:* in
the unlocking phase `verifyScript` builds (`mkEnv … (some scriptPubKey)`, its loop started by `evalScript` with
`codeSep` the unlocking script, `codeSep_sites`), at every configuration the evaluator's loop reaches, with the
instruction `op` next (an `OP_CHECKSIG`, `OP_CHECKSIGVERIFY`, `OP_CHECKMULTISIG` or any other), `codeSep` is a
suffix of the unlocking script that contains `op :: rest`; under the CHRONICLE bit `scriptCodeOf` is
`codeSep ++ scriptPubKey`, strictly longer than `scriptPubKey`, at the scriptCode before its cleanup (`1484`), so it differs from it. The state the check reads
differs from the reached one by the op count's charge only (`loop`, `466–467`), which leaves `codeSep` as it
was. *What it assumes:* the configuration reached from the unlocking phase's start state (`LoopReach`); the CHRONICLE bit for the third conjunct. [SRC] `407`, `1445–1448`, `1471–1481` and `1567–1577`
(the scriptCode and the CHRONICLE append), `2338–2342` (the unlocking script with `&scriptPubKey` as
`checksigData`). *Measured contradiction:* `sighash.scriptcode.in-unlock.lock-only`, a signer hashing
`scriptPubKey` alone where this scriptCode is longer (go-sdk v1.7.2 and bsv-rs 0.5.0; at @bsv/sdk 3.0.0 the
caller's obligation, `caller-scriptcode-required`; `docs/records/20261016-203024-s3-145d-signer-column-s3.md`,
`docs/records/20261016-234915-s3-147-signer-column-s3.md`). The bytes run from the scriptCode's start, which
the run fixes at the script's start or after an executed separator before `op` (`codeSep_sites`,
`execStep_codeSep`); which separator is the last, and the bytes from it, is `codeSep_last` and, at the check,
`scriptCode_last`.

`[SRC]` `interpreter.cpp:1484`, `interpreter.cpp:466–467`, `interpreter.cpp:407`, `interpreter.cpp:1445–1448`, `interpreter.cpp:1471–1481`, `interpreter.cpp:1567–1577`, `interpreter.cpp:2338–2342`

### `digest_dispatch_chronicle` (`lean/BsvScript/Properties/Sighash.lean:469`)

**`digest_dispatch_chronicle`.** *The rule:* a hash type carrying the CHRONICLE bit is signed over the
original digest whatever its FORKID bit; FORKID without CHRONICLE, under FORKID enabled, over the BIP143 digest.
*What it says:* `sighash` is `sighashOriginal` for every type with `hasChronicle` and every value of the FORKID
switch, and `sighashBIP143` for a type with `hasForkId` and not `hasChronicle` when FORKID is enabled. *What it
assumes:* the bits named. [SRC] `2112–2124` (`if(enabledSighashForkid && sigHashType.hasForkId() &&
!sigHashType.hasChronicle())`); `sighashtype.h:86–87` (the two bits). *Measured contradiction:* bsv-rs 0.5.0's
default path computes the BIP143 digest for a type with the CHRONICLE bit (`src/primitives/bsv/sighash.rs:941-944`),
class `sighash.chronicle.bip143` (`docs/records/20261016-234915-s3-147-signer-column-s3.md`).

`[SRC]` `interpreter.cpp:2112–2124`, `sighashtype.h:86–87`, `src/primitives/bsv/sighash.rs:941-944`

### `single_past_outputs` (`lean/BsvScript/Properties/Sighash.lean:486`)

**`single_past_outputs`.** *The rule:* under SIGHASH_SINGLE with no output at the signed input's index, the
original digest is the constant `one`, never a hash, and the BIP143 digest hashes a preimage whose `hashOutputs`
is thirty-two zero bytes. *What it says:* for a type of base SINGLE and `nIn ≥ tx.outputs.length`,
`sighashOriginal` is `one256`; so is `sighash` for a type carrying the CHRONICLE bit, whatever the FORKID switch;
`bip143Outputs` is `zero32`; and `sighashBIP143` is SHA-256d of the preimage with `zero32` in the `hashOutputs`
field. *What it assumes:* the base type and the index. [SRC] `2086–2100` (`return one` when `nIn >=
txTo.vout.size()` under SINGLE); `2053–2061` (`hashOutputs` left zero when the SINGLE guard fails); `2063–2083`
(the preimage); `2112–2124` (the dispatch). *Measured contradiction:* bsv-rs 0.5.0's default path builds the BIP143
preimage with `hashOutputs` zero for this scope whatever the CHRONICLE bit (`src/primitives/bsv/sighash.rs:534-536`),
class `sighash.single.out-of-range.one` (`docs/records/20261016-234915-s3-147-signer-column-s3.md`); @bsv/sdk 3.0.0
hashes the full original serialization for the same scope (`primitives/TransactionSignature.ts:254-365`,
`:425-440`), the same class (`docs/records/20261016-203024-s3-145d-signer-column-s3.md`).

`[SRC]` `interpreter.cpp:2086–2100`, `interpreter.cpp:2053–2061`, `interpreter.cpp:2063–2083`, `interpreter.cpp:2112–2124`, `src/primitives/bsv/sighash.rs:534-536`, `src/primitives/bsv/sighash.rs:425-440`

## `BsvScript.Properties.TxValue`

### `checkTransactionCommon_total_le_maxMoney` (`lean/BsvScript/Properties/TxValue.lean:18`)

**The total output value is bounded.** *What it says:* the sum of an accepted
transaction's output values is at most `MAX_MONEY`. *What it assumes:*
`checkTransactionCommon` accepts, with arbitrary size and sigop limits and era.
*Why it matters:* the running total is tested by `moneyRange` after every
addition, including the final one ([SRC] `validation.cpp:553–557`,
`amount.h:130`). This is an output-side bound; the input-side UTXO set and fees
are the transaction state machine's (S6, #58; `docs/DESIGN-S6.md`) and are outside
this statement.

`[SRC]` `validation.cpp:553–557`, `amount.h:130`

### `checkTransactionCommon_outputs_in_range` (`lean/BsvScript/Properties/TxValue.lean:32`)

**Every output value is in range.** *What it says:* every output of an
accepted transaction has value below `2^63` and at most `MAX_MONEY`.
*What it assumes:* `checkTransactionCommon` accepts, with arbitrary size and
sigop limits and era. *Why it matters:* the output checks exclude negative
serialized `int64` values and values above the money bound ([SRC]
`validation.cpp:543–546`, `validation.cpp:548–551`, `amount.h:130`); each
natural-valued output is bounded by the accepted total, and `MAX_MONEY < 2^63`.
This is an output-side bound; the input-side UTXO set and fees are the transaction
state machine's (S6, #58; `docs/DESIGN-S6.md`) and are outside this statement.

`[SRC]` `validation.cpp:543–546`, `validation.cpp:548–551`, `amount.h:130`

### `checkTransactionCommon_output_total_eq_sum` (`lean/BsvScript/Properties/TxValue.lean:64`)

**The output loop returns the sum.** *What it says:* for an accepted
transaction, `checkOutputs tx.outputs 0` returns exactly the sum of the output
values. *What it assumes:* `checkTransactionCommon` accepts, with arbitrary size
and sigop limits and era. *Why it matters:* `checkOutputs` is the executable
loop's denotation (`checkTransactionCommon_eq`, `forIn_eq_checkOutputs`); its
initial total is zero and each step adds the output value ([SRC]
`validation.cpp:542–558`, `validation.cpp:553`). This is an output-side
accounting identity; the input-side UTXO set and fees are the transaction state
machine's (S6, #58; `docs/DESIGN-S6.md`) and are outside this statement.

`[SRC]` `validation.cpp:542–558`, `validation.cpp:553`

## `BsvScript.Properties.VersionGate`

### `enforceNonMalleability_iff` (`lean/BsvScript/Properties/VersionGate.lean:93`)

**The branch, as an equivalence.** *What it says:* the gate is on exactly when the
word lacks `SCRIPT_CHRONICLE` or the version is at most 1 (`40–44` with `34–38`).
*What it assumes:* nothing. *Why it matters:* it is the whole content of the
branch-selection parameter: a pre-Chronicle spend era, or any version-1 spend (the
negative versions included), runs the restrictions; only a version above 1 under
Chronicle lifts them.

`[SRC]` `interpreter.cpp:40–44`, `interpreter.cpp:34–38`

### `Flags.gate_of_on` (`lean/BsvScript/Properties/VersionGate.lean:105`)

**The gate on: the word is read as given.** *What it says:* when the gate is on,
`Flags.gate` is the identity, so every gated site reads the bit the word carries
(`433`, `285`, `2327`, `2441`, and the three of #11/#8). *Why it matters:* the
version-1 branch is the word itself; the theorems below then speak about the bits.

`[SRC]` `interpreter.cpp:433`, `interpreter.cpp:285`, `interpreter.cpp:2327`, `interpreter.cpp:2441`

### `enforceNonMalleability_gate` (`lean/BsvScript/Properties/VersionGate.lean:112`)

The gate does not touch `SCRIPT_CHRONICLE`, so re-reading it on the gated word
gives the same answer: the crypto sites (`285`, `1493`, `1643`, `1666`) read
`bit && gate` on the gated word and get exactly the reference's `bit && gate`.

`[SRC]` `interpreter.cpp:285`, `interpreter.cpp:1493`, `interpreter.cpp:1643`, `interpreter.cpp:1666`

### `Flags.gate_gate` (`lean/BsvScript/Properties/VersionGate.lean:120`)

Gating twice is gating once.

### `mkEnv_requireMinimal` (`lean/BsvScript/Properties/VersionGate.lean:130`)

**`requireMinimal` as an equation** (`433–434`). *What it says:* the environment's
`requireMinimal` is the word's MINIMALDATA bit and the gate, on the word before
gating. *Why it matters:* it is the one place the flag enters the loop; every push
and every number read consults this value and nothing else about MINIMALDATA.

`[SRC]` `interpreter.cpp:433–434`

### `execStep_minimaldata` (`lean/BsvScript/Properties/VersionGate.lean:142`)

**An executed non-minimal push fails** (`473–479`, `331–358`). *What it says:*
under `requireMinimal`, an executed push whose opcode is not the smallest form for
its data is `SCRIPT_ERR_MINIMALDATA`, before the element reaches the stack. *What it
assumes:* the push is executed (`fExec`). *Why it matters:* it is the MINIMALDATA
rule on pushes, in both scripts and the redeem script, and only there: a push in a
dead branch is not executed and `execStep` never reaches this test for it.

`[SRC]` `interpreter.cpp:473–479`, `interpreter.cpp:331–358`

### `execStep_push_of_not_requireMinimal` (`lean/BsvScript/Properties/VersionGate.lean:153`)

**Without `requireMinimal` the push form is never consulted** (`475`): the push
succeeds when the budget allows (`pushElem`).

`[SRC]` `interpreter.cpp:475`

### `execStep_push_err_of_not_requireMinimal` (`lean/BsvScript/Properties/VersionGate.lean:161`)

The same, the budget refused (`stack_overflow_error` → `SCRIPT_ERR_STACK_SIZE`).

### `readNum_minencode` (`lean/BsvScript/Properties/VersionGate.lean:168`)

**A non-minimal number read under `requireMinimal` fails** (`script_num.cpp:67–70`,
`SCRIPT_ERR_SCRIPTNUM_MINENCODE` at `1811–1814`): the width passed
(`script_num.cpp:62–65`), the encoding is not minimal (`int_serialization.h:120–152`).
This is the constructor every site of the table above calls.

`[SRC]` `script_num.cpp:67–70`, `interpreter.cpp:1811–1814`, `script_num.cpp:62–65`, `int_serialization.h:120–152`

### `readNum_of_not_requireMinimal` (`lean/BsvScript/Properties/VersionGate.lean:178`)

**Without `requireMinimal` every encoding within the width decodes** (`script_num.cpp:53–91`
with `min_encoding_check::no`): the padded and negative-zero forms read as their value
(`Numbers.decode`).

`[SRC]` `script_num.cpp:53–91`

### `readOperand_minencode` (`lean/BsvScript/Properties/VersionGate.lean:186`)

The operand read of the arithmetic, bitwise, stack and splice families
(`Ops.Arith.readOperand`, the sites `1015`, `1129`, `1163`, `1235`, `1300–1301`,
`1386–1390`, `1717`, `1747` and the shifts `709–753`): under `requireMinimal` a
non-minimal encoding within the width is `SCRIPT_ERR_SCRIPTNUM_MINENCODE`.

`[SRC]` `interpreter.cpp:1015`, `interpreter.cpp:1129`, `interpreter.cpp:1163`, `interpreter.cpp:1235`, `interpreter.cpp:1300–1301`, `interpreter.cpp:1386–1390`, `interpreter.cpp:1717`, `interpreter.cpp:1747`, `interpreter.cpp:709–753`

### `readOperand_of_not_requireMinimal` (`lean/BsvScript/Properties/VersionGate.lean:197`)

The same read without `requireMinimal`: the value, whatever the encoding.

### `checkSignatureEncoding_highS` (`lean/BsvScript/Properties/VersionGate.lean:206`)

**A high-S signature fails under LOW_S and the gate** (`282–287`). *What it says:*
a non-empty signature of the strict DER shape whose `s` is not low
(`CPubKey::CheckLowS` false: `s > (n − 1)/2`, or the lax parse fails) is
`SCRIPT_ERR_SIG_HIGH_S` when LOW_S is set and the gate is on, before the hash-type
rules and before any curve computation. *What it assumes:* the strict shape, so
that `275–280` does not fire first. *Why it matters:* LOW_S is a consensus flag
(`verify_script_flags.cpp:65–67`), so on the version-1 branch a high-S signature
is refused by every node. On the version-2 branch the gate is off and LOW_S
refuses nothing: the signature goes on to the hash-type rules and the curve check,
where the high-S twin of a valid signature verifies, because `CPubKey::Verify`
normalizes `s` (`pubkey.cpp:207–213`), and a high-S signature that is not a valid
signature fails as any invalid signature does (`lean/Test/VersionGateCheck.lean`'s
LOW_S rows: `s = (n + 1)/2` and `s = n − 1` answer `SCRIPT_ERR_EVAL_FALSE` on the
version-2 branch). The gate's being off decides the encoding check only, never the
signature's validity.

`[SRC]` `interpreter.cpp:282–287`, `interpreter.cpp:275–280`, `verify_script_flags.cpp:65–67`, `pubkey.cpp:207–213`

### `checkSignatureEncoding_ne_highS` (`lean/BsvScript/Properties/VersionGate.lean:229`)

**With the gated LOW_S bit clear, `SCRIPT_ERR_SIG_HIGH_S` is unreachable**
(`282–287`): the encoding check can still refuse the shape (`SIG_DER`) or the hash
type (`291–307`), never the height of `s`.

`[SRC]` `interpreter.cpp:282–287`, `interpreter.cpp:291–307`

### `verifyScript_sigpushonly` (`lean/BsvScript/Properties/VersionGate.lean:241`)

**A non-push unlocking script fails under SIGPUSHONLY and the era gate** (`2321–2334`).
*What it says:* with a valid word carrying SIGPUSHONLY, in a spend era that is
Genesis-without-Chronicle, or Chronicle with a version at most 1 (`2325–2327`), an
unlocking script that is not push-only (`IsPushOnly`, `script.cpp:209–220`) is
`SCRIPT_ERR_SIG_PUSHONLY`, before any script runs. *What it assumes:* the two
disjuncts of `2325–2327`. *Why it matters:* SIGPUSHONLY is a consensus flag from
Genesis (`verify_script_flags.cpp:71–75`, `policy.h:229–232`): a version-1 spend
post-Chronicle, and every spend between Genesis and Chronicle, may carry only pushes
in its unlocking script, on the block path as on the mempool path.

`[SRC]` `interpreter.cpp:2321–2334`, `interpreter.cpp:2325–2327`, `script.cpp:209–220`, `verify_script_flags.cpp:71–75`, `policy.h:229–232`

### `phase2_ne_valid_of_cleanStackDemand` (`lean/BsvScript/Properties/VersionGate.lean:275`)

**CLEANSTACK without P2SH never validates** (`2432–2435`): whatever the version and
the scripts, a word with CLEANSTACK and without P2SH cannot reach `SCRIPT_ERR_OK`
through `phase2`: the demand is tested, ungated, on the way to every `valid`.

`[SRC]` `interpreter.cpp:2432–2435`

### `verifyScript_cleanstack_without_p2sh` (`lean/BsvScript/Properties/VersionGate.lean:287`)

**CLEANSTACK without P2SH is an invalid word** (`2432–2435`), for every version.
*What it says:* a parameter record whose word carries CLEANSTACK and not P2SH never
returns `valid`, and says no more: the verdict it returns instead may be
`SCRIPT_ERR_INVALID_FLAGS` (the test's own error), an earlier error, or one of the
two outcomes that are not errors, `unimplemented` and `undefinedInReference`
(`Machine.Verdict`). *Why it matters:* the reference's own vector runner adds P2SH
whenever it sets CLEANSTACK (`script_tests.cpp:281–282`), so its vectors never
reach this line; the spec states it.

`[SRC]` `interpreter.cpp:2432–2435`, `script_tests.cpp:281–282`

### `phase2_cleanstack` (`lean/BsvScript/Properties/VersionGate.lean:313`)

**The clean-stack rule with the gate on** (`2441–2445`). *What it says:* for a
post-Genesis UTXO (no P2SH copy), when the locking script leaves a true top element
over at least one more element, CLEANSTACK with P2SH set and the gate on makes the
spend `SCRIPT_ERR_CLEANSTACK`. *What it assumes:* the locking phase's outcome and its
stack (the hypotheses name them). *Why it matters:* it is the version-1 branch's
clean-stack rule at its site; with the gate off the same stack is valid
(`verifyScript_cleanstack_off`), and on the block path the word never carries the bit
(`blockScriptFlags_policy_off`).

`[SRC]` `interpreter.cpp:2441–2445`

### `verifyScript_minimaldata_off` (`lean/BsvScript/Properties/VersionGate.lean:339`)

**MINIMALDATA is never consulted with the gate off.** *What it says:* with
`SCRIPT_CHRONICLE` and a version above 1, the MINIMALDATA bit may be set or cleared
without changing any verdict. *What it assumes:* nothing else (MINIMALDATA has no
ungated read). *Why it matters:* it is the version-2 half of the MINIMALDATA rule,
and it needs `SCRIPT_CHRONICLE` (`hc`): under a word carrying it the relay-only bit
never reaches a version-2 verdict, and `blockScriptFlags_policy_off` keeps the bit
out of every block word. A word without CHRONICLE that carries MINIMALDATA binds a
version-2 spend to it, the gate being on for every version (`40–44`, read at `433`):
the standard relay word of every spend era before Chronicle (`policy.h:191–193`) is
such a word, and so is any explicit word of that shape.

`[SRC]` `interpreter.cpp:40–44`, `interpreter.cpp:433`, `policy.h:191–193`

### `verifyScript_sigpushonly_off` (`lean/BsvScript/Properties/VersionGate.lean:363`)

**SIGPUSHONLY is never consulted with the gate off** (`2325–2327`: neither disjunct
holds for a version above 1 under Chronicle).

`[SRC]` `interpreter.cpp:2325–2327`

### `verifyScript_cleanstack_off` (`lean/BsvScript/Properties/VersionGate.lean:379`)

**CLEANSTACK is never consulted with the gate off**, given P2SH (the ungated demand
`2432–2435` is then satisfied either way): the size test `2441–2445` is skipped.

`[SRC]` `interpreter.cpp:2432–2435`, `interpreter.cpp:2441–2445`

### `verifyScript_lowS_off` (`lean/BsvScript/Properties/VersionGate.lean:396`)

**LOW_S is never consulted with the gate off**, given DERSIG, STRICTENC or FORKID
(the ungated read `275–280` then selects the strict DER shape either way): the high-S
test `282–287` is skipped and `CPubKey::Verify` normalizes `s` (`pubkey.cpp:207–213`).

`[SRC]` `interpreter.cpp:275–280`, `interpreter.cpp:282–287`, `pubkey.cpp:207–213`

## `BsvScript.Properties.Widths`

### `readNum_overflow_iff` (`lean/BsvScript/Properties/Widths.lean:17`)

**W1 (the number reader's overflow).** *What it says:* reading a number refuses
`SCRIPT_ERR_SCRIPTNUM_OVERFLOW` exactly when the element is longer than the width, whatever the minimal
rule. *What it assumes:* nothing. *Why it matters:* the length bound is tested first
(`script_num.cpp:62–65`, before the minimality check at `script_num.cpp:67–70`), so an over-long element
is an overflow even when it is also non-minimal.

`[SRC]` `script_num.cpp:62–65`, `script_num.cpp:67–70`

### `hashOp_ok` (`lean/BsvScript/Properties/Widths.lean:38`)

**W2 (the digest widths).** *What it says:* a hash opcode that succeeds replaces the top element by its
digest, 20 bytes for `OP_RIPEMD160`, `OP_SHA1` and `OP_HASH160`, 32 for `OP_SHA256` and `OP_HASH256`.
*What it assumes:* the opcode succeeded. *Why it matters:* the widths are the digests' own
(`CRIPEMD160::OUTPUT_SIZE`, `CSHA1::OUTPUT_SIZE`, `CHash160`, `CSHA256`, `CHash256`, `1412–1440`), so the
memory a hash adds is known before it runs.

`[SRC]` `interpreter.cpp:1412–1440`

### `cat_ok` (`lean/BsvScript/Properties/Widths.lean:68`)

**W3 (`OP_CAT`'s result).** *What it says:* an `OP_CAT` that succeeds replaces the top two elements
`x2` (the second) and `x1` (the top) by `x2 ++ x1`, whose length is the sum. *What it assumes:* the opcode
succeeded. *Why it matters:* the concatenation is the second element followed by the top
(`1704–1705`: the top popped, then appended to the second in place), and by the length conjunct the
result weighs one element's overhead less than the two it replaces. The counter and the alt stack are not in this
statement: that the counter drops by that overhead, where it is exact, needs the alt stack unchanged too,
which the primitives' shapes give (`popElem_ok`, `pushElem_ok`), with `cat_frame`
(`BsvScript.Properties.Hooks`).

`[SRC]` `interpreter.cpp:1704–1705`

### `split_ok` (`lean/BsvScript/Properties/Widths.lean:100`)

**W4 (`OP_SPLIT` is `OP_CAT`'s inverse).** *What it says:* an `OP_SPLIT` that succeeds read the
position `n` from the top element `p` (the number read, `1716–1717`), at most
`INT32_MAX` ([SRC] `6504a3af`, `interpreter.cpp:1718`) and the length of the element
`x` under it, and replaced the two by the halves `x.take n` (below) and `x.drop n` (on top), which
concatenate back to `x`. *What it assumes:* the opcode succeeded. *Why it matters:* `OP_SPLIT` then
`OP_CAT` restores the element (the halves cut at the position, `1726–1727`, both popped and the halves
pushed, `1730–1735`; T-SP1), so a split never loses or reorders a byte.

`[SRC]` `interpreter.cpp:1716–1717`, `interpreter.cpp:1718`, `interpreter.cpp:1726–1727`, `interpreter.cpp:1730–1735`

### `encode_length_mono` (`lean/BsvScript/Properties/Widths.lean:150`)

An integer of smaller magnitude never encodes longer (`serialize`, `int_serialization.h:23–59`: the
minimal encoding's length is a function of the magnitude, T6).

`[SRC]` `int_serialization.h:23–59`

### `num2binOp_stackSize_iff` (`lean/BsvScript/Properties/Widths.lean:167`)

**W5 (`OP_NUM2BIN`'s memory at the opcode; the flagged rule `splice.num2bin.memory`).** *What it says:*
when the width `w` and the number pass their checks (the width read as a number in `0 … INT32_MAX`, at
most 520 before Genesis, the number fitting it), `OP_NUM2BIN` refuses `SCRIPT_ERR_STACK_SIZE` exactly when
the counter after the two pops plus `w` and the element overhead exceeds `MaxStackMemoryUsage`. *What it
assumes:* the stack `wb :: raw :: rest`, the width's read and the fit. *Why it matters:* the padding is
charged against the memory budget before the result exists (`padRight`, `limitedstack.cpp:60–71`, at
`1771–1777`; the spec refuses before `num2bin` builds it, #142): a small number padded to a width of up to
2³¹ − 1 bytes is refused by the memory limit, not by a width limit, the corner the corpus flags.

`[SRC]` `limitedstack.cpp:60–71`, `interpreter.cpp:1771–1777`

### `readOperand_error` (`lean/BsvScript/Properties/Widths.lean:204`)

The number reader refuses only by the width or the minimal rule (`script_num.cpp:62–70`).

`[SRC]` `script_num.cpp:62–70`

### `popElem_error` (`lean/BsvScript/Properties/Widths.lean:210`)

A pop refuses only an empty stack (`limitedstack.cpp:211–219`).

`[SRC]` `limitedstack.cpp:211–219`

### `pushElem_error` (`lean/BsvScript/Properties/Widths.lean:215`)

A push refuses only the memory limit (`limitedstack.h:163–173`).

`[SRC]` `limitedstack.h:163–173`

### `lshiftnum_ne_bigInt` (`lean/BsvScript/Properties/Widths.lean:223`)

**W6 (the left shift's count bound is reached only by overflow).** *What it says:* when the number
width is below 2²⁸, `OP_LSHIFTNUM` never refuses `SCRIPT_ERR_BIG_INT`. *What it assumes:* the width below
268,435,456. It holds on the block path (the consensus widths: 750,000 after Genesis, `consensus.h:64`;
32,000,000 after Chronicle, `consensus.h:66`) and at the policy default (10,000, `policy.h:156`), not at
every policy setting: `-maxscriptnumlengthpolicy` has no upper bound (`configscriptpolicy.cpp:192–215`
refuses only a negative value and 1 to 3; the mempool path uses it as set, `:108–109`). *Why it
matters:* the size test (`script_num.cpp:311–314`: the value's size plus `n / 8` bytes within the width)
runs before `bint::operator<<=` refuses a count above `INT_MAX` (`big_int.cpp:359–366`), and a count
above `INT_MAX` already asks for at least 2²⁸ bytes, so below that width the big-number refusal is dead
and `SCRIPT_ERR_SCRIPTNUM_OVERFLOW` is what such a count gets; on the mempool path of a node set to at
least 2²⁸ bytes plus the value's size (at exactly 2²⁸ only the zero value; `-maxscriptnumlengthpolicy=1GB`,
say, for every value) a count just above `INT_MAX` passes the size test (`script_num.cpp:311–314`) and is
refused as `SCRIPT_ERR_BIG_INT` (`1819–1822`).

`[SRC]` `consensus.h:64`, `consensus.h:66`, `policy.h:156`, `configscriptpolicy.cpp:192–215`, `configscriptpolicy.cpp:108–109`, `script_num.cpp:311–314`, `big_int.cpp:359–366`, `interpreter.cpp:1819–1822`

### `rshiftnum_ok` (`lean/BsvScript/Properties/Widths.lean:291`)

**W7 (the right shift's result width).** *What it says:* an `OP_RSHIFTNUM` that succeeds read its
count `n` from the top element, `0 ≤ n ≤ INT_MAX`, and its value `v` from the second, and replaced the
two by `r`: zero when `n` is at least `v`'s encoded width in bits, else `v` divided by `2ⁿ` toward zero;
`r` encodes in no more bytes than `v`. *What it assumes:* the opcode succeeded. *Why it matters:* the
quotient toward zero never grows the magnitude (`BN_rshift` on the magnitude, `big_int.cpp:376`, from the
`bint` branch of `operator>>=`, `script_num.cpp:367–372`), so the right shift needs no width test on its
result, as the reference has none. Its count is refused at its read (`744–747`: over the width
`SCRIPT_ERR_SCRIPTNUM_OVERFLOW`, non-minimal under the minimal rule `SCRIPT_ERR_SCRIPTNUM_MINENCODE`),
when negative (`SCRIPT_ERR_INVALID_NUMBER_RANGE`, `748–749`) and above `INT_MAX` (`SCRIPT_ERR_BIG_INT`,
`big_int.cpp:383–390`).

`[SRC]` `big_int.cpp:376`, `script_num.cpp:367–372`, `interpreter.cpp:744–747`, `interpreter.cpp:748–749`, `big_int.cpp:383–390`

## `BsvScript.SigOps`

### `getOpTail_above_pushdata4` (`lean/BsvScript/SigOps.lean:140`)

An opcode above `OP_PUSHDATA4` parses as itself with no operand (`instruction_iterator.h:26–27`).

`[SRC]` `instruction_iterator.h:26–27`

### `getOpTail_mem` (`lean/BsvScript/SigOps.lean:145`)

A push's operand is taken from the bytes after its opcode (`instruction_iterator.h:34–74`): every
byte of it is a byte of the script.

`[SRC]` `instruction_iterator.h:34–74`

### `decode_le_of_length_le_four` (`lean/BsvScript/SigOps.lean:164`)

A valid byte string of at most four bytes decodes to at most 2,147,483,647 (the magnitude below
`2^31`: the top byte's low seven bits and three bytes, `int_serialization.h:86–117`).

`[SRC]` `int_serialization.h:86–117`

### `multisigSigOps_le` (`lean/BsvScript/SigOps.lean:193`)

The count a multisig adds is at most 2,147,483,647 when its operand is a valid byte string: 16 after
`OP_16`, 20 before Genesis, else a script number of at most four bytes (`multisigSigOps`).

### `opSigOps_le` (`lean/BsvScript/SigOps.lean:219`)

An instruction adds at most 2,147,483,647 (`opSigOps`).

### `sigOpWalk_le` (`lean/BsvScript/SigOps.lean:228`)

The walk's bound, generalized over the state (the induction behind T-SO1): from a count `n` on valid
bytes, every instruction adds at most 2,147,483,647 and consumes at least one byte.

### `sigOpCount_le` (`lean/BsvScript/SigOps.lean:268`)

**T-SO1 (the bound).** *What it says:* on a script of valid bytes every count the node can take
(`fAccurate` or not, either era) is at most 2,147,483,647 per byte of the script. *What it assumes:*
the bytes are bytes. *Why it matters:* the count is linear in the script: an instruction adds at most
2,147,483,647 (a multisig after a four-byte push, `script.cpp:110–116`) and takes a byte; within the
after-Genesis consensus size of a transaction (1,000,000,000 bytes, `consensus.h:29`) the node's `uint64_t`
accumulator (`script.cpp:33`) never wraps, so the count modelled as a `Nat` is the node's.

`[SRC]` `script.cpp:110–116`, `consensus.h:29`, `script.cpp:33`

### `multisigSigOps_legacy` (`lean/BsvScript/SigOps.lean:279`)

Before Genesis without `fAccurate` a multisig counts 20, whatever precedes it (`script.cpp:119–122`).

`[SRC]` `script.cpp:119–122`

### `sigOpWalk_legacy_isSome` (`lean/BsvScript/SigOps.lean:284`)

The legacy walk never fails, generalized over the state (the induction behind T-SO2): with neither
`fAccurate` nor Genesis no scope is tracked and a multisig counts 20.

### `sigOpCount_legacy_isSome` (`lean/BsvScript/SigOps.lean:314`)

**T-SO2 (the legacy path never fails).** *What it says:* before Genesis without `fAccurate` the count
is always a number. *What it assumes:* nothing. *Why it matters:* the error branches (`55–63`, `85–111`)
are guarded by `fAccurate || Genesis` (`43`, `74`, `79`): the consensus gate's pre-Genesis count
(`validation.cpp:559–566`) has no error to refuse on, and the mempool's before Genesis only the P2SH
part's (a redeem script's accurate count).

`[SRC]` `script.cpp:55–63`, `script.cpp:85–111`, `script.cpp:43`, `script.cpp:74`, `script.cpp:79`, `validation.cpp:559–566`

### `sigOpCount_endif` (`lean/BsvScript/SigOps.lean:322`)

**T-SO3 (an unbalanced `OP_ENDIF`).** *What it says:* under `fAccurate` or Genesis a script that
begins with `OP_ENDIF` has no count, whatever follows. *What it assumes:* `accurate || genesis`. *Why it
matters:* this is `sigOpCountError` (`script.cpp:59–67`), which the mempool refuses at any cap
(`validation.cpp:1242`): an output script opening with `OP_ENDIF` makes its transaction non-relayable
after Genesis, though no script ever runs it.

`[SRC]` `script.cpp:59–67`, `validation.cpp:1242`

### `sigOpCount_ff` (`lean/BsvScript/SigOps.lean:334`)

**T-SO4 (a literal `0xff` ends the walk).** *What it says:* a script that begins with the byte `0xff`
counts nothing, whatever follows, on every path. *What it assumes:* nothing. *Why it matters:*
`decode_instruction` returns `0xff` as a valid instruction whose opcode is `OP_INVALIDOPCODE`
(`instruction_iterator.h:26–27`), and the walk stops at that opcode (`script.cpp:44–45`), as it stops at
a push that fails to decode.

`[SRC]` `instruction_iterator.h:26–27`, `script.cpp:44–45`

### `sigOpCount_return` (`lean/BsvScript/SigOps.lean:345`)

**T-SO5 (a top-level `OP_RETURN` ends the walk).** *What it says:* under `fAccurate` or Genesis a script
that begins with `OP_RETURN` counts nothing, whatever follows. *What it assumes:* `accurate || genesis`.
*Why it matters:* "everything after `OP_RETURN` at top level scope is unexecutable" (`script.cpp:49–53`);
a data carrier's bytes never count after Genesis.

`[SRC]` `script.cpp:49–53`

### `sigOpCount_multisig_max` (`lean/BsvScript/SigOps.lean:355`)

**T-SO6 (the multisig count after Genesis reaches 2,147,483,647).** *What it says:* after Genesis
the output script `04 ffffff7f OP_CHECKMULTISIG` (six bytes) counts 2,147,483,647. *What it assumes:*
nothing. *Why it matters:* the preceding four-byte push is the largest non-negative minimal script number
(`script.cpp:102–116`); three such outputs count 6,442,450,941, past `UINT32_MAX`, the largest cap
`-maxtxsigopscountspolicy` admits (`config.cpp:2391–2415`), so the mempool refuses them at every setting
(`TxPolicy.mempoolTxPolicy_multisig_witness`).

`[SRC]` `script.cpp:102–116`, `config.cpp:2391–2415`

### `sigOpCount_multisig_errors` (`lean/BsvScript/SigOps.lean:365`)

**T-SO7 (the multisig's three errors after Genesis).** *What it says:* after Genesis a multisig after a
five-byte push, after a non-minimal push (`05 00`) or after a negative number (`0x81`) has no count. *What it
assumes:* nothing. *Why it matters:* these are the three `sigOpCountError` cases of the operand
(`script.cpp:89–95`, `98–104`, `106–111`: a script that would fail at the opcode, "the coin unspendable"),
refused by the mempool at any cap (`validation.cpp:1242`).

`[SRC]` `script.cpp:89–95`, `script.cpp:98–104`, `script.cpp:106–111`, `validation.cpp:1242`

### `sigOpCount_opN_paths` (`lean/BsvScript/SigOps.lean:376`)

**T-SO8 (the three multisig paths).** *What it says:* `OP_2 OP_CHECKMULTISIG` counts 20 before Genesis
without `fAccurate`, 2 with it, and 2 after Genesis. *What it assumes:* nothing. *Why it matters:* the
consensus gate's pre-Genesis count charges every multisig the key limit (`script.cpp:119–122`); a P2SH
redeem script (`fAccurate`, `155–161`) and every count after Genesis read the key count from the preceding
`OP_1`–`OP_16` (`74–77`).

`[SRC]` `script.cpp:119–122`, `script.cpp:155–161`, `script.cpp:74–77`

### `p2shRedeemSigOps_examples` (`lean/BsvScript/SigOps.lean:387`)

**T-SO9 (the P2SH redeem count).** *What it says:* an unlocking script whose last push is the redeem
script `OP_2 OP_CHECKMULTISIG` gives the P2SH part 2; an unlocking script that is not push-only gives it 0.
*What it assumes:* nothing. *Why it matters:* the P2SH part of the mempool's count reads the redeem script
accurately (`script.cpp:159–165`) and gives up without an error on a non-push unlocking script
(`137–148`), which the script check refuses on its own (`SCRIPT_ERR_SIG_PUSHONLY`).

`[SRC]` `script.cpp:159–165`, `script.cpp:137–148`

### `sumOpt_eq_none_iff` (`lean/BsvScript/SigOps.lean:397`)

`sumOpt` fails exactly when one of its counts does.

### `sumOpt_append` (`lean/BsvScript/SigOps.lean:406`)

`sumOpt` of an appended list.

### `sumOpt_zeros` (`lean/BsvScript/SigOps.lean:418`)

`sumOpt` of counts that are all zero.

## `BsvScript.Sighash`

### `le32_length` (`lean/BsvScript/Sighash.lean:352`)

A 32-bit little-endian word is four bytes (`ser_writedata32`, `serialize.h`).

### `le64_length` (`lean/BsvScript/Sighash.lean:354`)

A 64-bit little-endian word is eight bytes (the amount's field).

### `zero32_length` (`lean/BsvScript/Sighash.lean:356`)

The null hash BIP143 substitutes for a field the type leaves out is 32 bytes.

### `serVersion_length` (`lean/BsvScript/Sighash.lean:358`)

The serialized version is four bytes (the `int32_t` `nVersion`, little-endian).

### `SigHashType.serialize_length` (`lean/BsvScript/Sighash.lean:360`)

The serialized type is four bytes: the raw 32-bit word (`sighashtype.h:92–94`).

`[SRC]` `sighashtype.h:92–94`

### `serOutPoint_length` (`lean/BsvScript/Sighash.lean:362`)

An outpoint serializes as its txid as stored and a four-byte index (`COutPoint`,
`src/primitives/transaction.h`).

### `bip143Prevouts_length` (`lean/BsvScript/Sighash.lean:366`)

BIP143's `hashPrevouts` field is 32 bytes: a SHA-256d, or the null hash under ANYONECANPAY.

### `bip143Sequence_length` (`lean/BsvScript/Sighash.lean:369`)

BIP143's `hashSequence` field is 32 bytes: a SHA-256d, or the null hash under ANYONECANPAY, SINGLE or NONE.

### `bip143Outputs_length` (`lean/BsvScript/Sighash.lean:372`)

BIP143's `hashOutputs` field is 32 bytes: the SHA-256d of every output, of the one output at `nIn` under SINGLE,
or the null hash.

### `preimageBIP143_length` (`lean/BsvScript/Sighash.lean:382`)

T-SH1: the BIP143 preimage has the fixed layout width: 124 bytes of fixed
fields, the outpoint's hash, and the length-prefixed scriptCode. With a 32-byte
txid, `156 + (serScript scriptCode).length`.

### `sighashBIP143_length` (`lean/BsvScript/Sighash.lean:393`)

The BIP143 digest is 32 bytes: a SHA-256d (`CHashWriter::GetHash`, `src/hash.h:199–204`).

`[SRC]` `src/hash.h:199–204`

### `one256_length` (`lean/BsvScript/Sighash.lean:396`)

The constant `one` the original digest returns in its two failure cases (`2090–2100`) is 32 bytes.

`[SRC]` `interpreter.cpp:2090–2100`

### `sighashOriginal_length` (`lean/BsvScript/Sighash.lean:398`)

The original digest is 32 bytes: the constant `one` (T-SH3, T-SH4) or a SHA-256d.

### `sighash_length` (`lean/BsvScript/Sighash.lean:406`)

T-SH2: every digest `SignatureHash` returns is 32 bytes (`2112–2124`: the BIP143 digest or the original, each
32 bytes by the two theorems above).

`[SRC]` `interpreter.cpp:2112–2124`

### `sighashOriginal_nIn_out_of_range` (`lean/BsvScript/Sighash.lean:414`)

T-SH3: the original digest of an input index past the inputs is `one`
(`2090–2093`), whatever the type.

`[SRC]` `interpreter.cpp:2090–2093`

### `sighashOriginal_single_no_output` (`lean/BsvScript/Sighash.lean:420`)

T-SH4: the original digest under SINGLE with no output at `nIn` is `one`
(`2095–2100`): the known "SIGHASH_SINGLE bug", a signature over the constant.

`[SRC]` `interpreter.cpp:2095–2100`

### `findAndDelete_nil` (`lean/BsvScript/Sighash.lean:429`)

T-SH5: an empty pattern deletes nothing (`script.h:204`).

`[SRC]` `script.h:204`

### `sighash_dispatch` (`lean/BsvScript/Sighash.lean:435`)

T-SH6: `SignatureHash`'s dispatch as the reference writes it (`2118–2123`): the BIP143 digest
iff `SCRIPT_ENABLE_SIGHASH_FORKID` is on, the type carries the FORKID bit and not the CHRONICLE
bit; the original digest otherwise. Its four corners are the next four theorems. bsv-rs 0.3.28
computes the BIP143 digest for every type (`spend.rs:1953–1962` at 0.3.28; the crate class
`sighash.dispatch.chronicle-bip143`, `corpus/INDEX.md` §4).

`[SRC]` `interpreter.cpp:2118–2123`, `spend.rs:1953–1962 (at 0.3.28)`

### `sighash_eq_bip143` (`lean/BsvScript/Sighash.lean:445`)

T-SH6a: the live mainnet path (`2118–2120`): FORKID enabled, the FORKID bit, no CHRONICLE bit.

`[SRC]` `interpreter.cpp:2118–2120`

### `sighash_original_of_not_enabled` (`lean/BsvScript/Sighash.lean:451`)

T-SH6b: with FORKID not enabled every type takes the original digest (`2118`, `2123`): the
pre-UAHF path, replayed by the mainnet vectors of `corpus/sighash/mainnet.jsonl` (block 400,000).

`[SRC]` `interpreter.cpp:2118`, `interpreter.cpp:2123`

### `sighash_original_of_chronicle` (`lean/BsvScript/Sighash.lean:457`)

T-SH6c (Q2): a type with the CHRONICLE bit takes the original digest whatever else is set
(`2118`, `2123`); the bit is legal under `SCRIPT_CHRONICLE` (`302–303`;
`Properties.checkSignatureEncoding_illegalChronicle`), so the original digest is live on mainnet
today: CONFIRMED BY EXECUTION on the spec's own SV-node instance, both instances (`corpus/gen`
`sighash/original/*` and `sighash/dispatch/*`; `docs/records/20260924-150154-sighash-family-s3.md`;
DESIGN §4.3).

`[SRC]` `interpreter.cpp:2118`, `interpreter.cpp:2123`, `interpreter.cpp:302–303`

### `sighash_original_of_no_forkid_bit` (`lean/BsvScript/Sighash.lean:468`)

T-SH6d: a type without the FORKID bit takes the original digest (`2118`, `2123`); under
STRICTENC with FORKID enabled such a signature is refused before hashing
(`SCRIPT_ERR_MUST_USE_FORKID`, `305–306`; `Properties.checkSignatureEncoding_mustUseForkid`), so on
mainnet since UAHF this corner is historical replay.

`[SRC]` `interpreter.cpp:2118`, `interpreter.cpp:2123`, `interpreter.cpp:305–306`

### `SigHashType.baseType_lt` (`lean/BsvScript/Sighash.lean:477`)

The base type is five bits (`sighashtype.h:73–75`; `BASE_SIGHASH_MASK = 0x1F`, `:43`).

`[SRC]` `sighashtype.h:73–75`, `sighashtype.h:43`

### `SigHashType.isDefined_iff` (`lean/BsvScript/Sighash.lean:480`)

T-SH7: `isDefined` (`sighashtype.h:79–84`) as a predicate on the base: defined iff the base
(`:73–75`) is `ALL`, `NONE` or `SINGLE`, whatever the three flag bits and the fork value above the
low byte (`isDefined_add_forkValue`). The undefined types are the bases 0 and 4–31
(`not_isDefined_of_base`); under STRICTENC the reference refuses them before hashing
(`293–294`, `SCRIPT_ERR_SIG_HASHTYPE`; `Properties.checkSignatureEncoding_sigHashtype`), where
bsv-rs 0.3.28 verifies over the BIP143 digest of the undefined type (the crate class
`sighash.type.undefined-base`, `spend.rs:1739–1766` at 0.3.28; `corpus/gen` `sighash/type/undefined/*`, the
spec's own SV-node instance agreeing with the spec on all three, `corpus/INDEX.md` §4c).

`[SRC]` `sighashtype.h:79–84`, `sighashtype.h:73–75`, `interpreter.cpp:293–294`, `spend.rs:1739–1766 (at 0.3.28)`

### `SigHashType.not_isDefined_of_base` (`lean/BsvScript/Sighash.lean:493`)

T-SH7a: the undefined bases (`sighashtype.h:82–83`): 0, and 4 to 31.

`[SRC]` `sighashtype.h:82–83`

### `SigHashType.isDefined_add_forkValue` (`lean/BsvScript/Sighash.lean:498`)

T-SH7b: the fork value above the low byte (`sighashtype.h:77`) never reaches `isDefined`: a word
and the same word with any multiple of 256 added are defined together (the conversion to the `uint8_t`
enumeration, `:31`, `:80–81`; the reference's unit test over five fork values,
`src/test/sighashtype_tests.cpp:94`, `:104–114`).

`[SRC]` `sighashtype.h:77`, `sighashtype.h:31`, `sighashtype.h:80–81`, `src/test/sighashtype_tests.cpp:94`, `src/test/sighashtype_tests.cpp:104–114`

### `SigHashType.ofSig_raw` (`lean/BsvScript/Sighash.lean:509`)

`GetHashType` reads the signature's last byte (`252`).

`[SRC]` `interpreter.cpp:252`

### `SigHashType.ofSig_nil` (`lean/BsvScript/Sighash.lean:512`)

An empty signature reads as type 0 (`248–250`), which is undefined (`isDefined_zero`); the
encoding check passes an empty signature before reading its type (`272–273`, T-C2) and `CheckSig`
fails it without hashing (`2145–2147`, `Properties.checksig_empty_sig`).

`[SRC]` `interpreter.cpp:248–250`, `interpreter.cpp:272–273`, `interpreter.cpp:2145–2147`

### `SigHashType.isDefined_zero` (`lean/BsvScript/Sighash.lean:517`)

Type 0 is undefined (`sighashtype.h:82–83`: the stripped word is below `ALL`).

`[SRC]` `sighashtype.h:82–83`

### `SigHashType.ofSig_raw_lt` (`lean/BsvScript/Sighash.lean:520`)

The type read from a byte-valued signature is one byte (`252`: a `uint8_t`).

`[SRC]` `interpreter.cpp:252`

### `SigHashType.isDefined_ofSig_iff` (`lean/BsvScript/Sighash.lean:527`)

T-SH7c: a signature's type is defined iff the low five bits of its last byte (`GetHashType`,
`252`; an empty signature reads 0) are 1, 2 or 3.

`[SRC]` `interpreter.cpp:252`

### `cleanupScriptCode_forkid` (`lean/BsvScript/Sighash.lean:534`)

T-SH8: `CleanupScriptCode` (`255–263`): with FORKID enabled and the FORKID bit set the scriptCode
is hashed as it is (`260`: neither disjunct holds, nothing deleted).

`[SRC]` `interpreter.cpp:255–263`, `interpreter.cpp:260`

### `cleanupScriptCode_of_not_enabled` (`lean/BsvScript/Sighash.lean:540`)

T-SH8a: with FORKID not enabled the push of the signature is deleted first (`260–261`;
`FindAndDelete`, `script.h:201–224`): the pre-UAHF path.

`[SRC]` `interpreter.cpp:260–261`, `script.h:201–224`

### `cleanupScriptCode_of_no_forkid_bit` (`lean/BsvScript/Sighash.lean:546`)

T-SH8b: a signature without the FORKID bit is deleted from the scriptCode whatever the flags
(`260–261`). bsv-rs 0.3.24 deleted every signature (`spend.rs:1356–1361`, `:1509–1512` at 0.3.24; the class
`sighash.scriptcode.findanddelete`, `corpus/INDEX.md` §2); from 0.3.27 it deletes only a signature without the
FORKID bit, the reference's rule, and the pinned 0.3.32 keeps that guard (`spend.rs:1814–1820`, `:2031–2035`).

`[SRC]` `interpreter.cpp:260–261`, `spend.rs:1356–1361 (at 0.3.24)`, `spend.rs:1509–1512 (at 0.3.24)`, `spend.rs:1814–1820`, `spend.rs:2031–2035`

### `pushData_ne_nil` (`lean/BsvScript/Sighash.lean:555`)

`CScript(vchSig)` (`script.h:71`, `script.h:104–133`), the pattern `FindAndDelete` looks for, is never
empty: a push opcode always precedes the bytes (written at `script.h:131`).

`[SRC]` `script.h:71`, `script.h:104–133`, `script.h:131`

### `pushData_length` (`lean/BsvScript/Sighash.lean:560`)

Its length is the signature's plus the push opcode's: 1, 2, 3 or 5 bytes by the size class
(`script.h:106–130`: a direct push below `OP_PUSHDATA1`, then `OP_PUSHDATA1`, `OP_PUSHDATA2`,
`OP_PUSHDATA4` with their 1-, 2- and 4-byte prefixes).

`[SRC]` `script.h:106–130`

### `truncatedHead_length_le` (`lean/BsvScript/Sighash.lean:569`)

T-SH11: the bytes `GetOp2` consumes before failing on a truncated push (`script.h:171–193`: the length prefix
at `script.h:180–191`, the data-length test at `script.h:192–193`) are
the opcode and, for `OP_PUSHDATA1/2/4`, the length prefix when wholly present: one to five bytes.

`[SRC]` `script.h:171–193`, `script.h:180–191`, `script.h:192–193`

### `truncatedHead_length_pos` (`lean/BsvScript/Sighash.lean:575`)

The opcode itself is always consumed (`script.h:173`).

`[SRC]` `script.h:173`

### `truncatedHead_of_not_pushdata` (`lean/BsvScript/Sighash.lean:579`)

A truncated direct push (`0x01`–`0x4b`) leaves the opcode alone (`script.h:178–179`, `script.h:192–193`).

`[SRC]` `script.h:178–179`, `script.h:192–193`

### `scriptCodeWalk_nil` (`lean/BsvScript/Sighash.lean:584`)

T-SH11a: `SerializeScriptCode`'s walk (`1862–1892`) by cases: nothing for an empty scriptCode.

`[SRC]` `interpreter.cpp:1862–1892`

### `scriptCodeWalk_truncated` (`lean/BsvScript/Sighash.lean:587`)

T-SH11b: a parse failure ends the bytes after `truncatedHead` (`1870`, `1887–1891`: the tail
from the last boundary to where `GetOp` stopped), no separator counted after it. MEASURED
2026-09-24 (the module docstring above).

`[SRC]` `interpreter.cpp:1870`, `interpreter.cpp:1887–1891`

### `getOpTail_codesep` (`lean/BsvScript/Sighash.lean:594`)

`OP_CODESEPARATOR` parses as a bare opcode (`script.h:176`: no immediate operand above
`OP_PUSHDATA4`).

`[SRC]` `script.h:176`

### `scriptCodeWalk_codesep` (`lean/BsvScript/Sighash.lean:599`)

T-SH11c: an `OP_CODESEPARATOR` at an opcode boundary is counted (`1871–1873`) and dropped
(`1879–1883`: the bytes before it written, the boundary moved past it).

`[SRC]` `interpreter.cpp:1871–1873`, `interpreter.cpp:1879–1883`

### `scriptCodeWalk_op` (`lean/BsvScript/Sighash.lean:605`)

T-SH11d: every other parsed instruction is copied with its data (`1877–1891`: it lies between
two boundaries, or before the end).

`[SRC]` `interpreter.cpp:1877–1891`

### `serScriptCodeOriginal_truncated` (`lean/BsvScript/Sighash.lean:612`)

T-SH11e: the size prefix of a truncated scriptCode counts the whole script (`1875`: the
script's size minus the separators parsed, none before the failure).

`[SRC]` `interpreter.cpp:1875`

### `bip143Prevouts_anyonecanpay` (`lean/BsvScript/Sighash.lean:618`)

T-SH9: the three hashes of the BIP143 preimage under the type (`2043–2060`): `hashPrevouts` is
zero under ANYONECANPAY (`2043–2045`) …

`[SRC]` `interpreter.cpp:2043–2060`, `interpreter.cpp:2043–2045`

### `bip143Prevouts_all` (`lean/BsvScript/Sighash.lean:624`)

… and the digest of every outpoint otherwise (`2043–2045`, `GetPrevoutHash` `1960–1966`).

`[SRC]` `interpreter.cpp:2043–2045`, `interpreter.cpp:1960–1966`

### `bip143Sequence_zero` (`lean/BsvScript/Sighash.lean:629`)

T-SH9a: `hashSequence` is zero under ANYONECANPAY, SINGLE or NONE (`2047–2051`).

`[SRC]` `interpreter.cpp:2047–2051`

### `bip143Sequence_all` (`lean/BsvScript/Sighash.lean:635`)

… and the digest of every sequence otherwise (`2047–2051`, `GetSequenceHash` `1968–1974`).

`[SRC]` `interpreter.cpp:2047–2051`, `interpreter.cpp:1968–1974`

### `bip143Outputs_none` (`lean/BsvScript/Sighash.lean:640`)

T-SH9b: `hashOutputs` is zero under NONE (`2053–2060`: neither branch assigns it).

`[SRC]` `interpreter.cpp:2053–2060`

### `bip143Outputs_single` (`lean/BsvScript/Sighash.lean:645`)

T-SH9c: under SINGLE it is the digest of the matching output when it exists (`2056–2060`).

`[SRC]` `interpreter.cpp:2056–2060`

### `bip143Outputs_single_past` (`lean/BsvScript/Sighash.lean:650`)

T-SH9d: under SINGLE past the outputs it is zero (`2056–2057`: the guard `nIn < vout.size()`
fails and nothing assigns it): no `one` return on the BIP143 path, unlike the original digest's
T-SH4.

`[SRC]` `interpreter.cpp:2056–2057`

### `bip143Outputs_all` (`lean/BsvScript/Sighash.lean:658`)

T-SH9e: every output otherwise (`2053–2055`, `GetOutputsHash` `1976–1982`).

`[SRC]` `interpreter.cpp:2053–2055`, `interpreter.cpp:1976–1982`

### `serInputOriginal_other` (`lean/BsvScript/Sighash.lean:663`)

T-SH10: the original serializer's blanking (`SerializeInput`, `1895–1919`): every input other
than the signed one carries an empty script (`1904–1906`) and, under SINGLE or NONE, a zero
sequence (`1911–1916`).

`[SRC]` `interpreter.cpp:1895–1919`, `interpreter.cpp:1904–1906`, `interpreter.cpp:1911–1916`

### `serInputOriginal_signed` (`lean/BsvScript/Sighash.lean:673`)

T-SH10a: the signed input carries the scriptCode (`1907–1908`) and its own sequence (`1917`).

`[SRC]` `interpreter.cpp:1907–1908`, `interpreter.cpp:1917`

### `serInputOriginal_anyonecanpay` (`lean/BsvScript/Sighash.lean:680`)

T-SH10b: under ANYONECANPAY only the signed input is serialized, whatever `nInput` (`1898–1900`).

`[SRC]` `interpreter.cpp:1898–1900`

### `serOutputOriginal_single_other` (`lean/BsvScript/Sighash.lean:687`)

T-SH10c: under SINGLE every output other than `nIn` is the null `CTxOut` (`1924–1927`,
`transaction.h:196–199`).

`[SRC]` `interpreter.cpp:1924–1927`, `transaction.h:196–199`

### `sighashOriginal_hashed` (`lean/BsvScript/Sighash.lean:693`)

T-SH10d: with the index in range and, under SINGLE, an output at `nIn`, the original digest is
SHA-256d of the serialization followed by the 4-byte type (`2104–2109`): T-SH3's and T-SH4's `one`
returns are the only other cases.

`[SRC]` `interpreter.cpp:2104–2109`

### `stripPrefixes_length_le` (`lean/BsvScript/Sighash.lean:717`)

Stripping never lengthens (`script.h:210–214`: the inner `while` only advances `pc`).

`[SRC]` `script.h:210–214`

### `stripPrefixes_fuel` (`lean/BsvScript/Sighash.lean:727`)

The strip is fuel-insensitive once the fuel exceeds the script's length: with a non-empty pattern every copy
removed is at least one byte, so the `while` of `script.h:210–214` ends by the bytes, never by a bound.

`[SRC]` `script.h:210–214`

### `findAndDeleteLoop_fuel` (`lean/BsvScript/Sighash.lean:745`)

The walk is fuel-insensitive once the fuel exceeds the script's length: every iteration of the `do … while
(GetOp(pc, opcode))` (`script.h:208–216`) consumes at least the opcode byte; `findAndDelete` calls it at `length + 1`.

`[SRC]` `script.h:208–216`

### `findAndDelete_prefix` (`lean/BsvScript/Sighash.lean:770`)

T-SH12: **a copy at an instruction start is deleted** (`script.h:210–214`: `pc` advances past every copy of `b` that begins
at the boundary, `nFound` counting each): with a non-empty pattern at the head of the script, the result is the result
on what follows the copy.

`[SRC]` `script.h:210–214`

### `findAndDelete_op` (`lean/BsvScript/Sighash.lean:800`)

T-SH12a: **an instruction that begins no copy is kept whole** (`script.h:215–216`: `pc2 = pc`, `GetOp` advances
one instruction, and `:207` copies it at the next iteration): the opcode and its push data are copied and the walk
goes on after them. The pattern is compared only where the walk stands: at the start of each instruction `GetOp` reads,
and again right after each copy it deletes, the parser not run in between (`script.h:210–214`). So a copy inside an
instruction the walk read whole never matches (inside a push's data: the unit cases `script_tests.cpp:3858–3868` and
`:3878–3885`, the latter a copy running on into the next instructions), while one that begins where a deleted copy
ended matches even there (the script `0x03 0x03 0x02 0xff` with the pattern `0x03`: both copies deleted,
`0x02 0xff` left, decided as an example beside the reference's unit cases). A copy that begins at an instruction start is deleted even when it runs across several instructions
(`script_tests.cpp:3887–3892`: the push and `OP_1`; `:3906–3918`: `OP_0 OP_1`; T-SH12, T-SH12f).

`[SRC]` `script.h:215–216`, `script.h:207`, `script.h:210–214`, `script_tests.cpp:3858–3868`, `script_tests.cpp:3878–3885`, `script_tests.cpp:3887–3892`, `script_tests.cpp:3906–3918`

### `findAndDelete_truncated` (`lean/BsvScript/Sighash.lean:824`)

T-SH12b: **a tail the parser cannot read is kept as it stands** (`script.h:216`: `GetOp` fails and the loop ends; `script.h:219`:
the bytes from `pc2` are appended): the invalid push of `script_tests.cpp:3920–3933` is deleted when a copy starts at
its boundary and is never parsed past.

`[SRC]` `script.h:216`, `script.h:219`, `script_tests.cpp:3920–3933`

### `findAndDelete_nil_script` (`lean/BsvScript/Sighash.lean:840`)

T-SH12c: an empty script deletes nothing (`script.h:216`: `GetOp` fails at once).

`[SRC]` `script.h:216`

### `findAndDelete_sublist` (`lean/BsvScript/Sighash.lean:849`)

T-SH12d: **nothing moves**: the result is a sublist of the script, every byte kept in its order and nothing added
or rearranged. That the bytes removed are whole copies of the pattern at the walk's positions (instruction starts,
and the ends of the copies it deleted) is T-SH12, T-SH12a and T-SH12b together (`script.h:209–214`, `script.h:219`), not this
statement. *Why it matters:* `CleanupScriptCode`
(`255–263`) feeds it the signature's push (T-SH8), so the scriptCode a pre-FORKID digest hashes is the executed script
with that push cut out and nothing rearranged.

`[SRC]` `script.h:209–214`, `script.h:219`, `interpreter.cpp:255–263`

### `findAndDelete_length_le` (`lean/BsvScript/Sighash.lean:884`)

T-SH12e: the result is never longer than the script (from T-SH12d).

### `findAndDelete_single_pass` (`lean/BsvScript/Sighash.lean:888`)

T-SH12f: **the pass is single** (the reference's own two cases, `script_tests.cpp:3906–3918`): `OP_0 OP_0 OP_1 OP_1`
with the pattern `OP_0 OP_1` leaves `OP_0 OP_1`, a fresh copy that a second pass would delete. The deletion is not a
fixpoint, and the digest of a pre-FORKID signature check depends on that: a `FindAndDelete` iterated to a fixpoint
would hash a different scriptCode on such a script.

`[SRC]` `script_tests.cpp:3906–3918`

## `BsvScript.Standard`

### `solver_p2sh` (`lean/BsvScript/Standard.lean:326`)

**T-ST1.** *What it says:* the P2SH shape is its own type before Genesis and no type after it, whatever
its hash. *What it assumes:* the shape (`isP2SH`). *Why it matters:* a coin is solved in its own era
(`388–390`), so a P2SH coin created before Genesis keeps its type when it is spent after it. An output of the
shape never meets the post-Genesis half (`72–75`) as a `scriptpubkey` reason: after Genesis consensus refuses
it at every node configuration (`validation.cpp:609–622`, `bad-txns-vout-p2sh`; the spec's `.p2shOutput` in
`TxRules.checkRegularTransaction`), and the mempool checks that (`validation.cpp:1035`) before `IsStandardTx` (`validation.cpp:1073`).

`[SRC]` `standard.cpp:388–390`, `standard.cpp:72–75`, `validation.cpp:609–622`, `validation.cpp:1035`, `validation.cpp:1073`

### `solver_opTrue` (`lean/BsvScript/Standard.lean:336`)

**T-ST2.** *What it says:* the locking script `OP_TRUE` (`OP_1`) has no type in either era. *What it
assumes:* nothing. *Why it matters:* it is the corpus's usual output and coin (`corpus/tx`: `tx-00032`,
`tx-00037`), and with no type it makes every transaction that creates it non-standard and every input spending
it non-standard (`388–390`). `IsStandardTx` reports its first reason, so `scriptpubkey` (`493–497`) only
when no earlier one is met (the version, the size, the unlocking scripts, an output's `bare-multisig` or
`dust`, the data carrier's total, `431–491`): a zero-value `OP_TRUE` output is reported `dust`
(`TxPolicy.standardnessRefusal_preGenesis_witnesses`, T-STD7).

`[SRC]` `standard.cpp:388–390`, `standard.cpp:493–497`, `standard.cpp:431–491`

### `isDust_iff` (`lean/BsvScript/Standard.lean:346`)

**T-ST3.** *What it says:* an output is dust exactly when its value is 0 and its script is not provably
unspendable in the era. *What it assumes:* nothing. *Why it matters:* the threshold is hard-coded to one
satoshi (`primitives/transaction.h:204`), so no setting moves it; a zero-value `OP_FALSE OP_RETURN` carrier is
never dust, and before Genesis neither is a leading `OP_RETURN`.

`[SRC]` `primitives/transaction.h:204`

### `inputsReason_postChronicle` (`lean/BsvScript/Standard.lean:355`)

**T-ST4.** *What it says:* after Chronicle the unlocking scripts give no reason: neither their size nor
their form is tested. *What it assumes:* both markers on (a post-Chronicle era is post-Genesis). *Why it
matters:* after Chronicle `IsStandardTx` reads only the version-free size, the outputs and the data carrier
(`431`, `458`, `462`), so the script corpora's post-Chronicle entries meet little of it.

`[SRC]` `standard.cpp:431`, `standard.cpp:458`, `standard.cpp:462`

### `inputsReason_empty` (`lean/BsvScript/Standard.lean:364`)

**T-ST5.** *What it says:* inputs whose unlocking scripts are all empty give no reason in any era.
*What it assumes:* every unlocking script empty. *Why it matters:* an empty script is push-only
(`script.cpp:209–220`, `isPushOnly []`) and short, so a witness with empty unlocking scripts is decided by its
version, size and outputs alone.

`[SRC]` `script.cpp:209–220`

## `BsvScript.Tx`

### `hexDecodeCharsLoop_eq` (`lean/BsvScript/Tx.lean:135`)

**`hexDecodeCharsLoop_eq`.** *What it says:* the loop from an accumulator `acc` is the decoder's answer with
`acc` reversed in front. *What it assumes:* nothing. *Why it matters:* it is the fact the decoder's compiled form
rests on: with `acc = []` the loop is `hexDecodeChars` itself.

### `hexDecodeChars_eq_viaLoop` (`lean/BsvScript/Tx.lean:156`)

`@[csimp]` (lean #48; S1's ask 7): every call of `hexDecodeChars` compiled after this lemma runs the loop, so
`hexDecode` below and every caller of either (the reader, the CLI, the Test harnesses' direct calls) does; by
`hexDecodeCharsLoop_eq`. Nothing in the semantics moves: every theorem about the decoder is about the definition.

### `readLE_eq_fast` (`lean/BsvScript/Tx.lean:187`)

`@[csimp]` (S1's ask 4 (a)): the compiler reads a fixed-width field with `readLEFast`, which walks the field's own `n` bytes (`Machine.takeExact`) instead of measuring the rest of the transaction (the decoder's wall of `docs/records/20260927-031436-diff-s1.md`, quadratic in fields × size); by `Machine.takeExact_eq`; nothing in the semantics moves, every theorem about the decoder is about `readLE`.

### `readBytes_eq_fast` (`lean/BsvScript/Tx.lean:199`)

`@[csimp]` (S1's ask 4 (a)): the compiler reads a script or an outpoint's hash with `readBytesFast`, the field's own `n` bytes walked (`Machine.takeExact`, then `drop n`: linear in the field, never in the rest of the transaction); by `Machine.takeExact_eq`; nothing in the semantics moves.

### `readVarInt_eq_fast` (`lean/BsvScript/Tx.lean:215`)

`@[csimp]`: `readVarInt` restated after `readLE`'s csimp lemma so its compiled code calls the fast leaf; the same term (`rfl`).

### `readTxIn_eq_fast` (`lean/BsvScript/Tx.lean:226`)

`@[csimp]`: `readTxIn` restated after the csimp lemmas of `readBytes`, `readLE` and `readVarInt`; the same term (`rfl`).

### `readTxOut_eq_fast` (`lean/BsvScript/Tx.lean:235`)

`@[csimp]`: `readTxOut` restated after the csimp lemmas of `readLE`, `readVarInt` and `readBytes`; the same term (`rfl`).

### `decodeTxPrefix_eq_fast` (`lean/BsvScript/Tx.lean:247`)

`@[csimp]`: `decodeTxPrefix` restated after the readers' csimp lemmas (its `readMany` receives `readTxInFast` and `readTxOutFast` in compiled code); the same term (`rfl`).

### `decodeTx_eq_fast` (`lean/BsvScript/Tx.lean:254`)

`@[csimp]`: `decodeTx` restated after `decodeTxPrefix`'s csimp lemma; the same term (`rfl`): the compiled evaluator decodes with the fast readers at every call site, and every theorem about `decodeTx` is about the definition.

## `BsvScript.TxContext`

### `checkLockTime_final` (`lean/BsvScript/TxContext.lean:83`)

T-TX1: a spend whose input is final never satisfies `CHECKLOCKTIMEVERIFY`
(`2196–2198`): the lock-time feature is off for it.

`[SRC]` `interpreter.cpp:2196–2198`

### `checkSequence_version_lt_two` (`lean/BsvScript/TxContext.lean:92`)

T-TX2: a transaction of version below 2 never satisfies `CHECKSEQUENCEVERIFY`
(`2212–2214`, BIP 68): relative lock times need version 2.

`[SRC]` `interpreter.cpp:2212–2214`

## `BsvScript.TxPolicy`

### `txPolicyGate_ok_iff` (`lean/BsvScript/TxPolicy.lean:168`)

**T-TP1.** *What it says:* the policy gate accepts exactly when the serialized size is within
the size cap and the sigop count within the sigop cap. *What it assumes:* nothing. *Why it matters:*
the gate is the two comparisons the node makes (`standard.cpp:446`, `1243`) and nothing else.

`[SRC]` `standard.cpp:446`, `validation.cpp:1243`

### `txPolicyGate_txSize` (`lean/BsvScript/TxPolicy.lean:181`)

**T-TP1a.** The size refusal comes first (`1074` before `1243`): a transaction over the size cap
is `tx-size` whatever its sigop count.

`[SRC]` `validation.cpp:1074`, `validation.cpp:1243`

### `txPolicyGate_tooManySigOps` (`lean/BsvScript/TxPolicy.lean:188`)

**T-TP1b.** Within the size cap, a sigop count over its cap is `bad-txns-too-many-sigops` (`1243–1246`).

`[SRC]` `validation.cpp:1243–1246`

### `checkTransactionCommon_ok_size` (`lean/BsvScript/TxPolicy.lean:194`)

The consensus gate's acceptance bounds the size: `CheckTransactionCommon` refuses `bad-txns-oversize`
above `maxSize` (`536–537`, the comment at `535`; T-TX6's `checkTransactionCommon_oversize` with the two
checks before it).

`[SRC]` `validation.cpp:536–537`, `validation.cpp:535`

### `checkTransactionCommon_ok_sigops` (`lean/BsvScript/TxPolicy.lean:208`)

The consensus gate's acceptance bounds the pre-Genesis sigop count: `CheckTransactionCommon` refuses
`bad-txn-sigops` above `maxSigOps` before Genesis (`560–567`), after the value loop.

`[SRC]` `validation.cpp:560–567`

### `txPolicyGate_consensus_preGenesis` (`lean/BsvScript/TxPolicy.lean:220`)

**T-TP2 (the identity on the consensus configuration, before Genesis).** *What it says:* with the
policy caps at the consensus values the consensus gate applies before Genesis (`MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS`
= 20,000 and `MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS` = 1,000,000, `consensus.h:47`, `:27`), the policy gate
on the same count refuses nothing the consensus gate accepts. *What it assumes:* the consensus gate's
`.ok ()`. *Why it matters:* the policy gate adds nothing to consensus except where its caps are lower;
at the node's actual pre-Genesis caps (4,000 and 99,999, the constants of `sigOpsCap`/`sizeCap`) they
are lower, and `tx-00035` (20,000 sigops) is the witness of the difference where the standardness gate lets
it through: at a node that does not require standardness (`acceptnonstdtxn=1`) the sigop constant refuses it
`bad-txns-too-many-sigops`, while at SV-node's default it is refused `dust` first, for its zero-value outputs
(T-STD7).

`[SRC]` `consensus.h:47`, `consensus.h:27`

### `txPolicyGate_consensus_postGenesis` (`lean/BsvScript/TxPolicy.lean:236`)

**T-TP3 (the identity on the consensus configuration, after Genesis).** *What it says:* after Genesis
the consensus gate has no sigop cap (`560`: "sigops are unlimited") and the size cap
`MAX_TX_SIZE_CONSENSUS_AFTER_GENESIS`; at that size cap the policy gate refuses only a sigop count over
its own cap, which is not a consensus rule: on the node's consensus configuration (`txPolicyAtConsensus`,
the zero rules) it accepts every transaction the consensus gate accepts whose count is at most
`UINT32_MAX`, the largest value the setter admits. *What it assumes:* the consensus gate's `.ok ()` at the
after-Genesis size cap and the count bound. *Why it matters:* at the zero-rule configuration what the caps
add to the block column is a count above `UINT32_MAX` (reachable after Genesis by the multisig count,
`multisigWitnessTx`, T-TP7; `txPolicyGateCounted` adds the count's error, T-TP6) and nothing of the size,
whatever the standardness settings. That is all the mempool's transaction gate adds to the block's
(`Bsvs.Run.txGate`) on a transaction the standardness gate passes (T-STD5), the scripts aside (they run under
the relay word and the policy limits, `Params.derive` with `consensus` false; for a version-2 spend after Chronicle
on mainnet, `Params.verifyScript_relay_block_version2`): the gate runs first (`1081–1089` before `1243`) and, the zero rules
changing only the caps, still refuses every reason but `scriptpubkey` after Genesis at SV-node's default
(T-TP9a, T-STD2; `dust` in T-STD8).

`[SRC]` `validation.cpp:560`, `validation.cpp:1081–1089`, `validation.cpp:1243`

### `txPolicyGateFor_preGenesis_iff` (`lean/BsvScript/TxPolicy.lean:262`)

**T-TP4.** *What it says:* before Genesis the node's caps are the two constants whatever the
configuration (`config.cpp:2424–2427`, `configscriptpolicy.cpp:399–406`): the gate accepts exactly a
transaction with at most 4,000 sigops and, under `requireStandard`, at most 99,999 bytes. *Why it
matters:* the cap settings do not reach the pre-Genesis mempool; the sigop constant refuses the witness
`tx-00035` (20,000 sigops) at every configuration, and decides the node's verdict where the standardness
gate lets it through (`acceptnonstdtxn=1`); at SV-node's default that gate refuses it first, `dust` (T-STD7).

`[SRC]` `config.cpp:2424–2427`, `configscriptpolicy.cpp:399–406`

### `standardnessEnforced_eras` (`lean/BsvScript/TxPolicy.lean:278`)

**T-TP9a (the enforcement condition by era).** *What it says:* before Genesis a failed standardness
test refuses exactly under `requireStandard`; after Genesis exactly when the node does not accept
non-standard outputs or under `requireStandard`. *What it assumes:* nothing. *Why it matters:* this is
`validation.cpp:1080–1088` over `configscriptpolicy.cpp:468–471`, read once, so the size cap's reach is a
function of the two settings with their defaults and sources (`NodeConfig.requireStandard`,
`NodeConfig.acceptNonStandardOutput`).

`[SRC]` `validation.cpp:1080–1088`, `configscriptpolicy.cpp:468–471`

### `txPolicyGateFor_svMainnetDefault_size` (`lean/BsvScript/TxPolicy.lean:290`)

**T-TP9 (the size cap is live at the node default; D123).** *What it says:* at SV-node's mainnet
default the standardness failures refuse in both eras, so after Genesis a transaction longer than
10,000,000 bytes is refused `tx-size` whatever its sigop count; at Teranode's default they refuse in
neither era. *What it assumes:* nothing. *Why it matters:* the maintainers' ruling D123
(2026-09-27) makes the evaluator's mempool column stand for the node default, `requireStandard`
true on mainnet (`chainparams.h:86`, `init.cpp:3158–3160`) with `acceptnonstdoutputs` true
(`configscriptpolicy.cpp:60`): the size cap `DEFAULT_MAX_TX_SIZE_POLICY_AFTER_GENESIS` (`policy.h:70`) is
live there, and the oracle's `acceptnonstdtxn=1` instance is the consensus instrument, not this column.

`[SRC]` `chainparams.h:86`, `init.cpp:3158–3160`, `configscriptpolicy.cpp:60`, `policy.h:70`

### `sigOpWalk_legacy_eq` (`lean/BsvScript/TxPolicy.lean:432`)

The legacy walk is `TxRules.sigOpCountPreGenesis` on a script without a literal `0xff`, generalized over
the state (the induction behind T-SO10).

### `sigOpCount_legacy_eq` (`lean/BsvScript/TxPolicy.lean:480`)

**T-SO10 (the pre-Genesis count is `TxRules`'s).** *What it says:* before Genesis without `fAccurate`,
the count of a script without a literal `0xff` is `TxRules.sigOpCountPreGenesis`, the consensus gate's
count. *What it assumes:* no instruction of the script is `0xff`. *Why it matters:* the mempool's count and
the consensus gate's agree on the pre-Genesis path wherever the spec's `TxRules` walk agrees with the
reference. Since S2's `616008e` both stop at a literal `0xff` (`script.cpp:44–45`; `SigOps.sigOpCount_ff`,
`TxRules.sigOpCountPreGenesis_invalidop`), and `TxRules.sigOpCountPreGenesis_eq_sigOpCount` (T-TX11) states the
equality on every script: this theorem's hypothesis is stronger than it needs to be.

`[SRC]` `script.cpp:44–45`

### `sumOpt_map_some` (`lean/BsvScript/TxPolicy.lean:492`)

A sum of counts none of which fails is the sum of the numbers.

### `sigOpCountWithoutP2SHAt_legacy_eq` (`lean/BsvScript/TxPolicy.lean:499`)

**T-SO11 (the transaction's pre-Genesis count).** *What it says:* before Genesis the count without P2SH
of a transaction none of whose scripts has a literal `0xff` is `TxRules.sigOpCountWithoutP2SH`. *What it
assumes:* no `0xff` instruction in any unlocking or locking script. *Why it matters:* `mempoolTxPolicy`
extends the count the policy gate was handed (`Bsvs.Run.txGate`'s `TxRules.sigOpCountWithoutP2SH`) by the
P2SH part and the post-Genesis path, and leaves the pre-Genesis part as it was.

### `p2shSigOpCount_genesis_coins` (`lean/BsvScript/TxPolicy.lean:518`)

**T-SO12 (the P2SH part vanishes on post-Genesis coins).** *What it says:* when every coin is
post-Genesis the P2SH part is 0. *What it assumes:* every coin's era Genesis-active. *Why it matters:* after
Genesis a P2SH output is refused (`validation.cpp:610–621`) and its redeem script never runs, so its sigops
never count (`482–484`); only a pre-Genesis coin spent after Genesis still brings its redeem script's count.

`[SRC]` `validation.cpp:610–621`, `validation.cpp:482–484`

### `txSigOpCount_genesis_coins` (`lean/BsvScript/TxPolicy.lean:533`)

**T-SO13 (the count on post-Genesis coins).** *What it says:* when every coin is post-Genesis the
mempool's count is the count without P2SH. *What it assumes:* every coin's era Genesis-active. *Why it
matters:* the whole count of a post-Genesis spend of post-Genesis coins is the scripts' own, on the
post-Genesis path of `SigOps.sigOpCount` (its multisig count reaching 2,147,483,647 per instruction).

### `txSigOpCount_output_error` (`lean/BsvScript/TxPolicy.lean:548`)

**T-SO14 (an output's error is the transaction's).** *What it says:* when an output script's count is
`sigOpCountError`, the transaction's count is too. *What it assumes:* the output is the transaction's.
*Why it matters:* one output opening with an unbalanced `OP_ENDIF` (after Genesis), or a multisig after
a bad count push, makes the whole transaction's count an error (`validation.cpp:453–457`), refused by the
mempool at any cap (`txPolicyGateCounted_error`).

`[SRC]` `validation.cpp:453–457`

### `txPolicyGateCounted_error` (`lean/BsvScript/TxPolicy.lean:563`)

**T-TP5 (`sigOpCountError` refuses at any cap).** *What it says:* on a count that is `sigOpCountError`
the gate refuses, whatever the node's configuration and era. *What it assumes:* nothing. *Why it matters:*
`sigOpCountError || nSigOpsCount > cap` (`validation.cpp:1242`): no cap setting admits the error.

`[SRC]` `validation.cpp:1242`

### `txPolicyGateCounted_postGenesis_iff` (`lean/BsvScript/TxPolicy.lean:571`)

**T-TP6 (what the counted gate adds after Genesis, at the consensus configuration).** *What it says:*
after Genesis, on the node's zero-rule caps (`txPolicyAtConsensus`), a transaction the consensus gate
accepts passes the counted gate exactly when its count is a number of at most `UINT32_MAX`. *What it
assumes:* the consensus gate's `.ok ()` at the after-Genesis size cap. *Why it matters:* on a transaction the
standardness gate passes (T-STD5), this is the whole difference between the block's transaction gate and the
mempool's (`Bsvs.Run.txGate`) after Genesis at those caps, the scripts aside (they run under the relay word and
the policy limits, `Params.derive` with `consensus` false; for a version-2 spend after Chronicle on mainnet,
`Params.verifyScript_relay_block_version2`): a `sigOpCountError` (an unbalanced `OP_ENDIF`, a bad multisig count
push) or a count past `UINT32_MAX` (`multisigWitnessTx`), never the size (T-TP3); the standardness gate,
which runs first, adds its own reasons (`dust` in T-STD8).

### `mempoolTxPolicy_multisig_witness` (`lean/BsvScript/TxPolicy.lean:609`)

**T-TP7 (the witness of the count past `UINT32_MAX`).** *What it says:* after Genesis the transaction
`multisigWitnessTx` counts 6,442,450,941 on post-Genesis coins, the consensus gate accepts it, and the
mempool refuses it `bad-txns-too-many-sigops` at SV-node's mainnet default (the cap `UINT32_MAX`, also the
largest the setter admits, `config.cpp:2391–2415`), past the standardness gate (its outputs have no type, the
reason `scriptpubkey`, which that default relays after Genesis, T-STD3). *What it assumes:* nothing. *Why it matters:* the
post-Genesis count path decides a real verdict: a consensus-valid transaction of 18 bytes of locking
script no SV-node mempool relays whatever its setting; the corpus entry that exercises it is the
harness's (#26).

`[SRC]` `config.cpp:2391–2415`

### `mempoolTxPolicy_endif_witness` (`lean/BsvScript/TxPolicy.lean:625`)

**T-TP8 (the witness of the unbalanced `OP_ENDIF`).** *What it says:* after Genesis the transaction
`endifWitnessTx` has no count, and the mempool refuses it at every node configuration. *What it assumes:*
a spend after Genesis. *Why it matters:* `sigOpCountError` (`script.cpp:59–67`) on an output script that
no script ever executes still keeps the transaction out of every SV-node mempool (`validation.cpp:1242`),
whether or not the standardness gate refuses it first (its zero-value output is dust, refused where the
gate's condition holds); the corpus entry that exercises it is the harness's (#26).

`[SRC]` `script.cpp:59–67`, `validation.cpp:1242`

### `acceptsNonStandardOutput_defaults` (`lean/BsvScript/TxPolicy.lean:663`)

**T-STD1 (the gate's condition at the two defaults).** *What it says:* SV-node's mainnet default does not
accept non-standard outputs before Genesis and does after it; Teranode's default accepts them in both eras.
*What it assumes:* nothing. *Why it matters:* it fixes where each refusal applies at each default
(`configscriptpolicy.cpp:468–471` over `requireStandard` and `acceptnonstdoutputs`).

`[SRC]` `configscriptpolicy.cpp:468–471`

### `refusesNonStandard_of_ne` (`lean/BsvScript/TxPolicy.lean:674`)

**T-STD2 (every reason but one refuses as the size cap does).** *What it says:* a reason other than
`scriptpubkey` refuses exactly when `standardnessEnforced` holds. *What it assumes:* the reason is not
`scriptpubkey`. *Why it matters:* the size reason (`tx-size`) is one of them, so the gate's size refusal and the
caps' (`txPolicyGateFor` under `standardnessEnforced`, T-TP9) are one rule and the caps' theorems still hold.

### `refusesNonStandard_scriptPubKey` (`lean/BsvScript/TxPolicy.lean:684`)

**T-STD3 (the `scriptpubkey` reason).** *What it says:* a transaction whose only reason is an output with no
standard type is refused exactly when the node does not accept non-standard outputs for the era. *What it
assumes:* nothing. *Why it matters:* after Genesis SV-node's default passes such a transaction
(`1085`: `reason != "scriptpubkey"`), and before Genesis it refuses it (`1084`). A P2SH output never reaches
the test after Genesis: consensus refuses it first (`610–623`, `bad-txns-vout-p2sh`, checked at `1036`, before
`IsStandardTx` at `1074`).

`[SRC]` `validation.cpp:1085`, `validation.cpp:1084`, `validation.cpp:610–623`, `validation.cpp:1036`, `validation.cpp:1074`

### `standardnessRefusal_off` (`lean/BsvScript/TxPolicy.lean:695`)

**T-STD4 (the gate is off where non-standard transactions are accepted).** *What it says:* a node that
neither requires standardness nor refuses non-standard outputs after Genesis refuses nothing at the
standardness gate, in any era. *What it assumes:* `requireStandard` false and `acceptNonStandardOutput` true.
*Why it matters:* Teranode's default is such a node (T-STD1), and there the mempool gate is the caps'
counted gate (T-STD5, T-STD6), which refuses only a sigop count over the cap or the count's error: its size
cap applies only under `standardnessEnforced`, false there (T-TP9).

### `mempoolTxPolicy_of_standard` (`lean/BsvScript/TxPolicy.lean:708`)

**T-STD5 (the gate passed, the caps decide).** *What it says:* when the standardness gate refuses nothing,
the mempool gate is the two caps on the node's count. *What it assumes:* no standardness refusal. *Why it
matters:* the caps' theorems (T-TP1 to T-TP9) describe the mempool gate on every standard transaction and at
every node that accepts non-standard ones; the caps' size test is never the one that refuses after the gate,
which runs the same test first (T-STD2).

### `mempoolTxPolicy_teranodeDefault` (`lean/BsvScript/TxPolicy.lean:722`)

**T-STD6 (Teranode's default).** *What it says:* at Teranode's default (v0.15.9's and v0.16.0's: they differ only in `maxScriptSizePolicy`, which this gate does not read) the mempool gate is the caps'
counted gate (`txPolicyGateCounted`), in every era and for every transaction. *What it assumes:* nothing. *Why
it matters:* modeling the standardness moves no verdict of the Teranode columns; it moves SV-node's. At Teranode's default the
counted gate refuses only a sigop count over the cap or the count's error: its size cap applies only under
`standardnessEnforced`, false at that default in both eras (T-TP9).

### `stdWitnessTx_inputs` (`lean/BsvScript/TxPolicy.lean:747`)

Every unlocking script of a standardness witness is empty.

### `standardnessRefusal_preGenesis_witnesses` (`lean/BsvScript/TxPolicy.lean:751`)

**T-STD7 (the road's pre-Genesis rows, by shape).** *What it says:* at SV-node's mainnet default, for a
spend at 610,000 (before Genesis) of a coin of 600,000: a transaction creating a one-satoshi `OP_TRUE` output
is refused `scriptpubkey`; one creating a zero-value `OP_TRUE` output is refused `dust`, before its type is
reported (`standard.cpp:476–485`, then `:493–497`); one creating a standard output (pay to a key hash) from an
`OP_TRUE` coin is refused `bad-txns-nonstandard-inputs`. *What it assumes:* the witnesses' shapes. *Why it
matters:* these are the node's mempool verdicts on `tx-00032`, `tx-00037` and `tx-00038`, `tx-00035` and
`tx-00036` (`docs/records/20260927-231608-d123-road-s3.md` for `tx-00032`, `tx-00035`, `tx-00036` and `tx-00037`,
`docs/records/20260928-113333-road-a3-s3.md` for all five), which the spec's gate did not give before it modeled the standardness.

`[SRC]` `standard.cpp:476–485`, `standard.cpp:493–497`

### `standardnessRefusal_postGenesis_witnesses` (`lean/BsvScript/TxPolicy.lean:772`)

**T-STD8 (the same shapes after Genesis).** *What it says:* at SV-node's mainnet default, for a spend at
967,896 (after Chronicle) of a coin of the same height, the one-satoshi `OP_TRUE` output and the `OP_TRUE` coin
are not refused, and the zero-value output is refused `dust`. *What it assumes:* the witnesses' shapes. *Why it
matters:* after Genesis that default's gate refuses no output for having no standard type, and no coin (`1085`,
`1208`), and still refuses dust, a reason other than `scriptpubkey`; a P2SH output never reaches the gate after
Genesis, refused first by consensus (`610–623`, `bad-txns-vout-p2sh`, at `1036`).

`[SRC]` `validation.cpp:1085`, `validation.cpp:1208`, `validation.cpp:610–623`, `validation.cpp:1036`

## `BsvScript.TxRules`

### `isCoinBase_length` (`lean/BsvScript/TxRules.lean:129`)

T-TX3: a coinbase has exactly one input (`transaction.h:323–325`).

`[SRC]` `transaction.h:323–325`

### `getOpTail_nonpush` (`lean/BsvScript/TxRules.lean:136`)

A non-push opcode parses as itself with no operand (`script.h:176`: no immediate operand above
`OP_PUSHDATA4`; `script.h:198–199`: the opcode returned): the walk's step for every opcode above `OP_PUSHDATA4`.

`[SRC]` `script.h:176`, `script.h:198–199`

### `sigOpCountPreGenesis_nil` (`lean/BsvScript/TxRules.lean:141`)

T-TX4: the pre-Genesis sigop count by cases (`script.cpp:30–128`, the `fAccurate = false`, pre-Genesis
branch the vector runner takes): nothing for an empty script …

`[SRC]` `script.cpp:30–128`

### `sigOpCountPreGenesis_checksig` (`lean/BsvScript/TxRules.lean:146`)

… `OP_CHECKSIG` counts one (`script.cpp:71–74`) …

`[SRC]` `script.cpp:71–74`

### `sigOpCountPreGenesis_checksigverify` (`lean/BsvScript/TxRules.lean:153`)

… as does `OP_CHECKSIGVERIFY` (`script.cpp:71–74`) …

`[SRC]` `script.cpp:71–74`

### `sigOpCountPreGenesis_checkmultisig` (`lean/BsvScript/TxRules.lean:160`)

… `OP_CHECKMULTISIG` counts `MAX_PUBKEYS_PER_MULTISIG_BEFORE_GENESIS` = 20 (`script.cpp:119–122`, `consensus.h:50`;
the inaccurate count, whatever the key count pushed) …

`[SRC]` `script.cpp:119–122`, `consensus.h:50`

### `sigOpCountPreGenesis_checkmultisigverify` (`lean/BsvScript/TxRules.lean:169`)

… as does `OP_CHECKMULTISIGVERIFY` (`script.cpp:119–122`) …

`[SRC]` `script.cpp:119–122`

### `sigOpCountPreGenesis_truncated` (`lean/BsvScript/TxRules.lean:178`)

… the walk stops at a push that fails to decode with the count so far (`script.cpp:44–45`: it decodes as
`OP_INVALIDOPCODE`, `instruction_iterator.h:31–72`) …

`[SRC]` `script.cpp:44–45`, `instruction_iterator.h:31–72`

### `sigOpCountPreGenesis_invalidop` (`lean/BsvScript/TxRules.lean:184`)

… and at a literal `0xff`, whatever follows (`script.cpp:44–45`: `decode_instruction` returns the byte as a valid
instruction whose opcode is `OP_INVALIDOPCODE`, `instruction_iterator.h:26–27`) …

`[SRC]` `script.cpp:44–45`, `instruction_iterator.h:26–27`

### `sigOpCountPreGenesis_other` (`lean/BsvScript/TxRules.lean:190`)

… and every other instruction counts nothing (`script.cpp:30–128`: no other case in the pre-Genesis branch).
The per-transaction limit against the total is `MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS` = 20,000 ("Allowed number of
signature check operations per transaction before Genesis", `consensus.h:46–47`) at `checkTransactionCommon`'s
`validation.cpp:559–566`; the block's own limit is `MAX_BLOCK_SIGOPS_PER_MB_BEFORE_GENESIS` (`consensus.h:33–37`,
applied at `validation.cpp:3362–3366` and `validation.cpp:5841–5864`, block-level rules outside this module).

`[SRC]` `script.cpp:30–128`, `consensus.h:46–47`, `validation.cpp:559–566`, `consensus.h:33–37`, `validation.cpp:3362–3366`, `validation.cpp:5841–5864`

### `checkRegularTransaction_coinbase` (`lean/BsvScript/TxRules.lean:201`)

T-TX5: the coinbase rule is exclusive (`validation.cpp:600–602`): a coinbase fails `CheckRegularTransaction`
before any other check …

`[SRC]` `validation.cpp:600–602`

### `checkCoinbase_not_coinbase` (`lean/BsvScript/TxRules.lean:209`)

… and a non-coinbase fails `CheckCoinbase` (`validation.cpp:571–592`, its first test) before any other;
with `isCoinBase_length` (T-TX3) a coinbase is the one-input transaction whose outpoint is null
(`transaction.h:68`, `:323–325`).

`[SRC]` `validation.cpp:571–592`, `transaction.h:68`, `transaction.h:323–325`

### `checkTransactionCommon_vinEmpty` (`lean/BsvScript/TxRules.lean:218`)

T-TX6: the first three checks of `CheckTransactionCommon` in their order (`validation.cpp:526–535`):
`bad-txns-vin-empty` …

`[SRC]` `validation.cpp:526–535`

### `checkTransactionCommon_voutEmpty` (`lean/BsvScript/TxRules.lean:226`)

… `bad-txns-vout-empty` (`529–532`) …

`[SRC]` `validation.cpp:529–532`

### `checkTransactionCommon_oversize` (`lean/BsvScript/TxRules.lean:233`)

… and `bad-txns-oversize` against the serialized size (`534–536`; `Sighash.serTx`, the size the reference
measures).

`[SRC]` `validation.cpp:534–536`

### `checkCoinbase_length` (`lean/BsvScript/TxRules.lean:241`)

T-TX7: the coinbase script's length (`validation.cpp:587–589`): 2 to 100 bytes (`MAX_COINBASE_SCRIPTSIG_SIZE`,
`consensus.h:69`), given the common checks pass.

`[SRC]` `validation.cpp:587–589`, `consensus.h:69`

### `forIn_eq_checkOutputs` (`lean/BsvScript/TxRules.lean:273`)

The do-block's loop is the recursion, for any body that decides as the three tests do: the bridge from
`checkTransactionCommon`'s syntax to its theorems.

### `checkTransactionCommon_eq` (`lean/BsvScript/TxRules.lean:289`)

**`CheckTransactionCommon` as a case analysis** (`527–569`): the do-block equals the nested conditional with the
loop as `checkOutputs`; the theorems below read off it.

`[SRC]` `validation.cpp:527–569`

### `checkOutputs_ok_iff` (`lean/BsvScript/TxRules.lean:318`)

The loop accepts iff the sum of the values stays within `MAX_MONEY` (the total is monotone, so `554` at the last
output is the binding test, and every single value is then in range too), and it returns that sum.

`[SRC]` `validation.cpp:554`

### `checkOutputs_append` (`lean/BsvScript/TxRules.lean:349`)

A prefix that passes carries its sum into the rest (`542`: the outputs in order; `553`: the total accumulates).

`[SRC]` `validation.cpp:542`, `validation.cpp:553`

### `checkOutputs_voutNegative` (`lean/BsvScript/TxRules.lean:364`)

The first output failing a test names the rejection, in the tests' order: a negative value (`543–546`) …

`[SRC]` `validation.cpp:543–546`

### `checkOutputs_voutTooLarge` (`lean/BsvScript/TxRules.lean:372`)

… a value above `MAX_MONEY` (`548–551`) …

`[SRC]` `validation.cpp:548–551`

### `checkOutputs_txoutTotalTooLarge` (`lean/BsvScript/TxRules.lean:380`)

… a total above `MAX_MONEY` (`553–557`).

`[SRC]` `validation.cpp:553–557`

### `checkTransactionCommon_voutNegative` (`lean/BsvScript/TxRules.lean:393`)

T-TX8: **the value checks through the loop** (`540–558`): with T-TX6's three checks passing, the first output
that fails a test names the rejection: `bad-txns-vout-negative` for a serialized value at or above `2⁶³`
(`543–546`) …

`[SRC]` `validation.cpp:540–558`, `validation.cpp:543–546`

### `checkTransactionCommon_voutTooLarge` (`lean/BsvScript/TxRules.lean:404`)

… `bad-txns-vout-toolarge` above `MAX_MONEY` (`548–551`; `amount.h:130`) …

`[SRC]` `validation.cpp:548–551`, `amount.h:130`

### `checkTransactionCommon_txoutTotalTooLarge` (`lean/BsvScript/TxRules.lean:414`)

… `bad-txns-txouttotal-toolarge` when the running total leaves `MoneyRange` (`553–557`).

`[SRC]` `validation.cpp:553–557`

### `checkTransactionCommon_sigops` (`lean/BsvScript/TxRules.lean:424`)

T-TX9: **the pre-Genesis sigop count at the transaction level** (`560–567`; `consensus.h:47`): with every check
before passing, a pre-Genesis transaction whose count (`sigOpCountWithoutP2SH`, T-TX4) exceeds the limit is
`bad-txn-sigops`; after Genesis the count is not taken (`560–561`: "sigops are unlimited").

`[SRC]` `validation.cpp:560–567`, `consensus.h:47`, `validation.cpp:560–561`

### `checkTransactionCommon_ok_iff` (`lean/BsvScript/TxRules.lean:437`)

**The common checks pass iff** the inputs and the outputs are non-empty, the serialized size is within the limit,
the values sum within `MAX_MONEY` and, pre-Genesis, the sigop count is within its limit (`527–569`).

`[SRC]` `validation.cpp:527–569`

### `forIn_eq_checkInputs` (`lean/BsvScript/TxRules.lean:477`)

The do-block's loop, then `pure ()`, is the recursion, for any body that decides as the two tests do.

### `checkRegularTransaction_eq` (`lean/BsvScript/TxRules.lean:492`)

**`CheckRegularTransaction` as a case analysis** (`595–640`): not a coinbase (`601–603`), the common checks
(`605–608`), post-Genesis no P2SH output (`611–622`), then the loop as `checkInputs`.

`[SRC]` `validation.cpp:595–640`, `validation.cpp:601–603`, `validation.cpp:605–608`, `validation.cpp:611–622`

### `checkInputs_ok_iff` (`lean/BsvScript/TxRules.lean:520`)

The loop accepts iff no outpoint is null, no outpoint repeats, and none was seen before.

### `checkInputs_append` (`lean/BsvScript/TxRules.lean:551`)

A prefix that passes carries its outpoints into the seen set, in the loop's order (`627`, `633`: the set
`inOutPoints` grows by one outpoint per input).

`[SRC]` `validation.cpp:627`, `validation.cpp:633`

### `checkRegularTransaction_prevoutNull` (`lean/BsvScript/TxRules.lean:575`)

T-TX10: **the outpoint checks through the loop** (`627–637`): with the checks before passing, the first input
whose outpoint is null is `bad-txns-prevout-null` (`628–631`) …

`[SRC]` `validation.cpp:627–637`, `validation.cpp:628–631`

### `checkRegularTransaction_inputsDuplicate` (`lean/BsvScript/TxRules.lean:589`)

… and the first input repeating an earlier outpoint is `bad-txns-inputs-duplicate` (`633–636`).

`[SRC]` `validation.cpp:633–636`

### `checkRegularTransaction_ok_iff` (`lean/BsvScript/TxRules.lean:610`)

**`CheckRegularTransaction` passes iff** not a coinbase, the common checks pass, no P2SH output after Genesis,
no null outpoint and no repeated outpoint (`595–640`).

`[SRC]` `validation.cpp:595–640`

### `sigOpWalk_legacy_eq_all` (`lean/BsvScript/TxRules.lean:642`)

The legacy walk of `SigOps` is `sigOpCountPreGenesis` on every script, generalized over the walk's state
(the induction behind T-TX11): before Genesis without `fAccurate` no scope is tracked and a multisig counts 20
(`script.cpp:47`, `script.cpp:119–122`); a push that fails to decode and a literal `0xff` end both walks (`script.cpp:44–45`).

`[SRC]` `script.cpp:47`, `script.cpp:119–122`, `script.cpp:44–45`

### `sigOpCountPreGenesis_eq_sigOpCount` (`lean/BsvScript/TxRules.lean:689`)

**T-TX11 (the pre-Genesis count is the node's, on every script).** *What it says:* before Genesis without
`fAccurate`, `CScript::GetSigOpCount` as `SigOps.sigOpCount` models it (`script.cpp:30–128`) is
`sigOpCountPreGenesis` on every script, a literal `0xff` included. *What it assumes:* nothing. *Why it
matters:* the consensus gate's count (`validation.cpp:437–459` at `validation.cpp:559–566`) is the node's, so the gate
refuses exactly the transactions `CheckTransactionCommon` refuses for their sigops. The node's other pre-Genesis
sigop refusals are not this gate's: `ConnectBlock`'s count with the P2SH part (`validation.cpp:3351–3360`,
`bad-txn-sigops`), the block totals (`validation.cpp:3362–3366`, `validation.cpp:5849–5864`, `bad-blk-sigops`) and the mempool's policy cap
(`validation.cpp:1235–1247`). `TxPolicy.sigOpCount_legacy_eq` needed the script free of `0xff`.

`[SRC]` `script.cpp:30–128`, `validation.cpp:437–459`, `validation.cpp:559–566`, `validation.cpp:3351–3360`, `validation.cpp:3362–3366`, `validation.cpp:5849–5864`, `validation.cpp:1235–1247`

### `sigOpCountPreGenesis_replicate_checksig` (`lean/BsvScript/TxRules.lean:702`)

`n` `OP_CHECKSIG`s in a row count `n` before Genesis (`script.cpp:71–74`), whatever follows them.

`[SRC]` `script.cpp:71–74`

### `sigOpCountPreGenesis_ff_witness` (`lean/BsvScript/TxRules.lean:718`)

**T-TX12 (the `0xff` witness).** *What it says:* the witness transaction counts 0 sigops before Genesis,
so it passes the consensus gate's test against `MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS` = 20,000
(`validation.cpp:559–566`, `consensus.h:47`), while the same 20,001 `OP_CHECKSIG` without the `0xff` count
20,001, over it. *What it assumes:* nothing. *Why it matters:* the node stops at the `0xff`
(`script.cpp:44–45`), so a count that reads on past it refuses a transaction the node accepts: a pre-Genesis
consensus divergence, which the spec's count had until 2026-09-27.

`[SRC]` `validation.cpp:559–566`, `consensus.h:47`, `script.cpp:44–45`

## `Bsvs.Trace`

### `loop_stepK` (`lean/Bsvs/Trace.lean:63`)

**The loop is `stepK` with itself as the continuation.** *What it says:* on a
non-empty script, `Machine.loop` is one `stepK` whose continuation is the loop on
the bytes after the instruction and whose stop is the identity: the loop's own
recursion equation. *What it assumes:* nothing; it holds by unfolding. *Why it
matters:* it is the only place the trace and the semantics meet.

### `stepK_map` (`lean/Bsvs/Trace.lean:73`)

`stepK` commutes with any function applied to its result: the exits are the
only places a value leaves it.

### `traceLoop_fst` (`lean/Bsvs/Trace.lean:130`)

**The traced run is the loop.** *What it says:* for every script, state,
offset and accumulator, the first component of `traceLoop` is `Machine.loop`.
*What it assumes:* nothing. *Why it matters:* the trace's outcome per phase is
the list machine's `Machine.loop` outcome, not a third reading of the script. It
is a second run beside the CLI's verdict, which comes from `verifyScriptI` (the
array machine, `verifyScript_eq_I`), not from the trace. The steps are the states
the run records inside `stepK`'s continuation (`loop_stepK` at every instruction),
by construction: no theorem states the list of steps (B-10; #32's final lens on
Lean B, NEW-7).

### `traceEvalScript_fst` (`lean/Bsvs/Trace.lean:158`)

**The traced phase is `evalScript`.** *What it says:* for every script, stack and
memory counter, the first component of `traceEvalScript` is `Machine.evalScript`.
*What it assumes:* nothing. *Why it matters:* the script-size check (`429–430`) and
the loop are the semantics' own, so each phase `traceVerifyScript` prints has the
list machine's outcome and final state for that phase (`traceLoop_fst` below the
size check).

`[SRC]` `interpreter.cpp:429–430`

