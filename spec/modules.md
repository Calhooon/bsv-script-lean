# The modules

The module docstrings of `lean/BsvScript/**`, `lean/BsvChain/**` and `lean/Bsvs/Trace.lean`, in module order.

## `BsvChain.Block` (`lean/BsvChain/Block.lean`)

# Block validity (#63)

[SRC] bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.
These are fresh checks of immutable bodies. The source's memory-only
`fChecked` hint (src/validation.cpp:5754–5760,5892–5897) belongs to #64's
cache discipline; it is not an unchecked caller assertion in this API.
`Bsvs.Run.rejectCode` is the existing pure transaction-reason rendering;
importing it avoids a second mapping. Every transaction check and hash is
the existing interpreter definition. No definition here performs IO.

## `BsvChain.Chain` (`lean/BsvChain/Chain.lean`)

# Chain transitions (#64)

[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
The active chain is ordered from genesis to tip. Header-only branches are
retained separately from the candidates. C denotes consensus, P policy;
operator lists, validation depth and scheduling are explicit settings/data.
The transition runs to quiescence or reports a non-completed outcome. The
source's early successful returns on cancellation/contention are not a proof
of maximal work (src/validation.cpp:4913–5130).

## `BsvChain.Coin` (`lean/BsvChain/Coin.lean`)

# Coins and outpoints (#61)

The representation of the pinned coins view, bitcoin-sv v1.2.3 at
6504a3aff65ba97c0f6c80962b033e35ecbfed4b. Script rules and era derivation
are the existing interpreter's definitions. Amounts are signed so the
source's spent sentinel and negative-value refusals remain representable.

## `BsvChain.Depth` (`lean/BsvChain/Depth.lean`)

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

## `BsvChain.Depth` (`lean/BsvChain/Depth.lean`)

## The network data of the depth settings

## `BsvChain.Depth` (`lean/BsvChain/Depth.lean`)

## The script-check decision

## `BsvChain.Depth` (`lean/BsvChain/Depth.lean`)

## Safe mode: a client behavior

## `BsvChain.Eras` (`lean/BsvChain/Eras.lean`)

# Chain-layer eras (#69)

The era-gated block rules as functions of height and `ChainParams`, at
[SRC] bitcoin-sv v1.2.3, `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.
Each function names the transition that reads it. The existing definitions
already carry four of the rules; this module adds the missing gate (BIP30),
the named predicates the proofs read (the version floor, the difficulty path),
and the setting residue of the UAHF size rule. No definition performs IO.

* BIP30: `bip30Enforced`, read by `eraConnectionChecks` (Chain.lean), the
  default of `ChainContext.connectionChecks`, which fills the
  `ConnectionChecks.bip30Required` hook of `prepareBlockConnection`
  [SRC] src/validation.cpp:3070–3117.
* Version floors: `versionObsolete`, the predicate inside
  `contextualCheckBlockHeader` [SRC] src/validation.cpp:5962–5972.
* Median-time-past cutoff: `blockFinalityCutoff` (#60, Finality.lean), read by
  `contextualCheckBlock` [SRC] src/validation.cpp:6046–6050,6067–6074.
* Difficulty: `nextWorkPath` names the branch `getNextWorkRequired` (Pow.lean)
  takes [SRC] src/pow.cpp:95–117.
* Pre-Genesis block sigops: `checkBlock` and `checkBlockInputs` (Block.lean)
  gate the count by the block's own era [SRC] src/validation.cpp:5818,5853–5866,3461,3352–3368.
* UAHF: no block check reads `uahfHeight` at the pin; see `LEGACY_MAX_BLOCK_SIZE`.

## `BsvChain.Eras` (`lean/BsvChain/Eras.lean`)

## BIP30

## `BsvChain.Eras` (`lean/BsvChain/Eras.lean`)

## Version floors

## `BsvChain.Eras` (`lean/BsvChain/Eras.lean`)

## Difficulty

## `BsvChain.Eras` (`lean/BsvChain/Eras.lean`)

## UAHF

## `BsvChain.Eras` (`lean/BsvChain/Eras.lean`)

## The selected network's data outside `Consensus::Params`

## `BsvChain.Finality` (`lean/BsvChain/Finality.lean`)

# Transaction finality and the fee (#60)

The predicates below transcribe bitcoin-sv v1.2.3 at
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b`. The tip judge, holding and expiry
are policy; the block finality path is consensus.
Ancestor times are a list in newest-to-oldest order, including the named tip;
#63 can project its header chain to this input. Effective `ChainParams` include
any scenario's activation overrides. Time is supplied, never read here.
The fee is the arithmetic stage of [SRC] src/validation.cpp:2646–2663 at
6504a3af; #61 owns the preceding per-coin and aggregate input bounds.

## `BsvChain.Frozen` (`lean/BsvChain/Frozen.lean`)

# Frozen outputs and the confiscation whitelist as operator data (#70)

The operator's records, as the reference's frozen-output database stores them,
and the effective projection `FrozenLists` derived from them exactly as
`CFrozenTXOCheck::Check` and `CheckConfiscationTxWhitelisted` decide. Every
record here is operator data: a node setting supplied through the freeze RPCs,
an explicit input of each scenario, never a constant of the chain. The
reference names one list "consensus" (`Blacklist::Consensus`); that is the
reference's label for an operator list whose entries the node also applies at
block connection, not a consensus rule of the chain. The spec's kind for every
record and every derived check is the operator-list mechanism, a policy
parameter (DESIGN-S6 §1.5, PARAMETERS §8.2).

Heights in the records are the reference's signed 32-bit values, held as `Int`.
The source is bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.

## `BsvChain.Frozen` (`lean/BsvChain/Frozen.lean`)

## The operator calls (the freeze RPCs' database effects)

## `BsvChain.Header` (`lean/BsvChain/Header.lean`)

# Block headers (#63)

The fixed frame and unsigned arithmetic of [SRC] bitcoin-sv v1.2.3,
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b`. Hash words use the integer
whose little-endian bytes are the internal hash, not the displayed hex order.
The version stores its wire bits; `signedVersion` supplies the signed reading.

## `BsvChain.Mempool` (`lean/BsvChain/Mempool.lean`)

# Mempool admission and maintenance (#62)

Executable policy at bitcoin-sv v1.2.3,
6504a3aff65ba97c0f6c80962b033e35ecbfed4b. Bare line numbers are
`src/validation.cpp`. The fourteen named stages retain source order.
The accepted/non-final/orphan associations have unique transaction ids after
normal insertion; their list order records explicit iteration choices.
`mapNextTx` is the accepted pool's spent-outpoint index. The combined coins
view deliberately does not spend parent outputs: conflict checks own that job.
[SRC] src/txmempool.h:1380–1389 at 6504a3af.

All admission and maintenance limits read the existing NodeConfig census.
Allocator sizes and scheduling order are explicit observations, not limits.
Unmeasured ABI data, equal-score eviction order, filter false positives and
budget outcomes are non-judging for #66/#71. No clock or network is read.
`accept` returns TxOutcome because silence, priority downgrade and resubmission
are not completed TxVerdicts (DESIGN-S6 §2). The four completed verdicts stay
separate from those scheduling observations. The inventory envelope, the
filter's reset rule and the elapsed-time budget are `BsvChain.Rejects` (#71).

## `BsvChain.Merkle` (`lean/BsvChain/Merkle.lean`)

# Block merkle roots (#63)

[SRC] bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`,
src/consensus/merkle.cpp:18–50,190–282. Each level pairs adjacent hashes;
an odd final hash is padded with itself without setting `mutated`. Equality
of actual siblings at any level sets the flag. This level-wise presentation
has the same pair/lift operations as the source's binary-counter traversal.
Hash inputs are internal-order 32-byte words.
[M] 2026-10-13, #65 adds the pinned branch operations, including the null marker.

## `BsvChain.Oracle` (`lean/BsvChain/Oracle.lean`)

# Script calls and recorded verdicts (#76)

The oracle receives the complete spend and the exact parameters of a call.
Caller flags and resource selection are independent; ordinary derivation is
only one case. No oracle runs where a caller bypasses scripts.
[SRC] src/validation.cpp:1328–1347,1411–1423,705–717,2693–2707,2738–2749,
2864–2868,2885–2897 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.

## `BsvChain.Params` (`lean/BsvChain/Params.lean`)

# Chain-layer configuration (#59)

The census is `docs/PARAMETERS.md` §8. This library imports the script library;
the script library does not import this one (checked by `tools/check_parameters.py`).
Every source below is [SRC] bitcoin-sv v1.2.3 at
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b` (paths relative to that repository).

`NodeConfig.defaults` is a library template, not a daemon launch configuration.
Three values require explicit operator input at launch: `excessiveBlockSize`,
inherited `maxStackMemoryUsageConsensus`, and `blockMinTxFee`. Their template
values are the reference's library initializers, never implicit launch defaults.
All sizes, times and zero sentinels below are resolved as each field documents.
Per-network data are `ChainParams` below and the census in §8.3; since #69
(2026-10-13) the transitions read them through `lean/BsvChain/Eras.lean`
(`bip30Enforced`, `checkBlockVersion`, `nextWorkPath`, `NetworkData`), with the
proofs in `Properties/Eras.lean`. Operator lists,
request overrides, scheduling choices and `now` are explicit transition inputs
or state, as DESIGN-S6 §§1–2 specifies; they are not invented global constants.
The node settings retain their qualified kind; the frozen lists remain the
operator-list mechanism of #70. No setting substitutes for #65's inclusion proof.

## `BsvChain.Persist` (`lean/BsvChain/Persist.lean`)

# Mempool persistence across a restart (#81)

The dump at shutdown and the load at start as transitions of the pool state of
#62, at bitcoin-sv v1.2.3, 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.

Policy throughout: nothing here is consensus. `-persistmempool` is a node
setting (default on), read at four sites: the transaction database's
cross-check at launch (src/init.cpp:3548, src/txmempool.cpp:3030-3038), the
sanity check's resume (src/init.cpp:3549-3551), the load after the best chain is
activated (src/init.cpp:1901-1905) and the dump at shutdown
(src/init.cpp:237-240). The dump writes two files in the data
directory: `mempool.dat` for the accepted pool (src/txmempool.cpp:3279-3344) and
`non-final-mempool.dat` for the held pool (src/time_locked_mempool.cpp:247-284).
The load re-validates every unexpired record through the same admission machine
(`accept`, #62) with the file source, the record's own entry time as its
acceptance time and the pool's size limit on; nothing is restored without
re-validation (src/txmempool.cpp:3154-3273, src/time_locked_mempool.cpp:287-378).

What a load drops, by `DropReason`: a record whose entry time plus the expiry is
not after the load's clock (`expired`; src/txmempool.cpp:3209,3235-3240 and
src/time_locked_mempool.cpp:325,356-359); a record whose inputs are gone, as
when a block mined while the node was down spent one (`missingInputs`, the
orphan verdict, src/validation.cpp:1178-1188, with no orphan handler on the file
source, src/txn_validator.cpp:163-167); a record admission refuses
(`rejected`); a record whose admission did not complete (`notCompleted`). After
Genesis a record that is non-final at the load's tip is not dropped: admission
holds it, so it moves from the accepted pool to the held pool
(src/validation.cpp:1107-1119,5981-5987); before Genesis admission refuses it
`bad-txns-nonfinal` (src/validation.cpp:5989-5992), a `rejected` drop.

The ordering: the load runs after the block index is loaded and the best chain
activated (src/init.cpp:1884,1901), on a pool the fresh process starts empty;
the reference's own comment states the assumption that the block index's
unload, which clears the pool, never runs after the restore
(src/validation.cpp:7150-7156). Records are read in the dump's order, the
accepted pool's insertion order (src/txmempool.cpp:1851-1858, the sequenced
index src/txmempool.h:475-477); [D] the reference keeps that order topological
across a reorg (src/txmempool.cpp:2386), an assumption of this model, not a
theorem: `PoolTopological` names it and `dump_topological` carries it to the
file (`DumpTopological`); the held file is read in txid order
(src/time_locked_mempool.h:146-152,181-185), after the accepted file
(src/txmempool.cpp:3271-3272).

The clock is an explicit input: `ctx.now` is the one GetTime sample of the load
(src/txmempool.cpp:3172, src/time_locked_mempool.cpp:301), which a launch's
`-mocktime` sets (src/init.cpp:3198-3199). A shutdown during the load
(src/txmempool.cpp:3241-3243, src/init.cpp:1904) and a failure to open the dump
file for writing (src/txmempool.cpp:3289-3292) are not modelled; their absence
is declared in the record of #81.

## `BsvChain.Pow` (`lean/BsvChain/Pow.lean`)

# Proof of work and the difficulty rule (#63)

[SRC] bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.
`HeaderChain` is the ancestor projection for #64's HeaderTree to refine.
`none` means missing ancestry or a violated arithmetic/assertion precondition,
never a node rejection or permission to substitute the observed candidate bits.
The explicit configuration supplies the existing census median span.

## `BsvChain.Properties.Block` (`lean/BsvChain/Properties/Block.lean`)

# Block properties (#63)

The header codec, padding-equivalent merkle suffix, finite subsidy schedule,
and accepted timestamp window. All statements name the executable definitions.
[SRC] src/primitives/block.h:38–45, src/consensus/merkle.cpp:18–50,247–282,
src/validation.cpp:2252–2262,5933–5975 at
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.

## `BsvChain.Properties.Chain` (`lean/BsvChain/Properties/Chain.lean`)

# Qualified chain laws (#64)

All maps, settings and oracles remain quantified. The retained undo is the
spent-coin vector, with an explicit no-overwrite premise. Automatic selection
is distinguished from interruptions and explicit removals.
[SRC] src/validation.cpp:3021–3719,4065–4133,4413–5130 and
src/processing_block_index.cpp:9–77 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.

## `BsvChain.Properties.CompactBlocks` (`lean/BsvChain/Properties/CompactBlocks.lean`)

# Compact blocks' laws (#79), 2026-10-15 [D]

Views of the relay layer, never block-validity rules. The SipHash of the
short id at the reference's own test vectors; the round trips of
`cmpctblock`, `getblocktxn`, `blocktxn` and `sendcmpct`; and THE
RECONSTRUCTION THEOREM: for the message a sender builds from a block, when no
two of the receiver's candidate transactions share a short id with
different transactions, `InitData` yields exactly the block's transactions it
holds, the positions it asks for with `getblocktxn` are exactly the block's
transactions it lacks and nothing else, and `FillBlock` with them yields
exactly the announced block, or the reference's `CheckBlock` verdict when the
block is invalid. The collision cases as the source handles them: two equal
short ids in the message fail it (the whole block is requested, no score);
two pool transactions on one short id leave the position to be requested;
the scan's early exit can place a wrong transaction, which only a
`CheckBlock` that accepts the filled block lets through.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b, as cited
in `lean/BsvChain/Wire/CompactBlocks.lean`.

## `BsvChain.Properties.CompactBlocks` (`lean/BsvChain/Properties/CompactBlocks.lean`)

## 1. SipHash at the reference's test vectors

## `BsvChain.Properties.CompactBlocks` (`lean/BsvChain/Properties/CompactBlocks.lean`)

## 2. The round trips

## `BsvChain.Properties.CompactBlocks` (`lean/BsvChain/Properties/CompactBlocks.lean`)

## 3. The reconstruction

## `BsvChain.Properties.CompactBlocks` (`lean/BsvChain/Properties/CompactBlocks.lean`)

## 4. The collision cases, as the source handles them

## `BsvChain.Properties.Depth` (`lean/BsvChain/Properties/Depth.lean`)

# Validation depth: what a connection checked (#73)

[M] 2026-10-14 (#73). These theorems describe the model decision,
its wiring premise, and successful model connections under named premises.
`blockScriptCalls` defines the ordinary input calls used by the statements.
Reference-run interpretations and observation scope are in
`docs/records/20261014-013925-s6-73-regtest-s3.md`.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/validation.cpp:2864-2889,3379-3430,3482-3518,3678-3714,
src/block_index.cpp:75-150, src/init.cpp:324-333, src/warnings.cpp:36-96.

## `BsvChain.Properties.Depth` (`lean/BsvChain/Properties/Depth.lean`)

## The decision

## `BsvChain.Properties.Depth` (`lean/BsvChain/Properties/Depth.lean`)

## The wiring

## `BsvChain.Properties.Depth` (`lean/BsvChain/Properties/Depth.lean`)

[D] 2026-10-14, #73 scope: `DepthWired` is a premise discharged by an
explicit `withValidationDepth` call. These explicit wired calls satisfy the
depth-argument deliverable; automatic internal coupling is deferred.
`connectTip` is unchanged and does not compute the depth decision internally.
There is no context-indexed `Reachable` lift or history of past check decisions.
`bestHeader` is recomputed from insertion order; a stored best-header pointer
is deferred. Safe-mode forks are recomputed, without the cached fork-table
update history. Client switches use auxiliary `SafeModeClient` fields; the
webhook field is omitted, and integration into `NodeConfig` is deferred.
The proposed `onChainOf_ancestry` lemma was dropped; the reported kernel-recursion
cause is unverified. These are limitations of the model theorem scope.

## `BsvChain.Properties.Depth` (`lean/BsvChain/Properties/Depth.lean`)

## What a connection with the scripts on judged

## `BsvChain.Properties.Depth` (`lean/BsvChain/Properties/Depth.lean`)

## Safe mode changes no validity

## `BsvChain.Properties.DoubleSpend` (`lean/BsvChain/Properties/DoubleSpend.lean`)

# The double-spend notifications' laws (#80), 2026-10-15 [D]

Views of node behavior, never rules of validity; **a notification is never a
verdict**. The codecs read back their writers' bytes: the reference's VARINT
(both widths the callback message uses), the callback message, the
notification output that carries it, the merkle proof, the block details and
the `dsdetected` message. The blacklist holds an endpoint added now until its
hour is out and lets it go after. THE THEOREM (`notification_only_after_detection`):
every query and every proof the handler sends names a notice whose attempt is
a detection of #62's admission (a completed refusal at the pool's conflict
check or at the double-spend detector), whose notification-enabled transaction
and conflicting transaction are the two sides of that conflict on one
outpoint, and whose double-spend input passed a script check: the admission's
own (a refusal at the detector, after every script check) or the handler's
(a refusal at the conflict check, before any script ran). [SRC] bitcoin-sv
v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b, as cited in
`lean/BsvChain/Wire/DoubleSpend.lean`.
`Detected` is existential: some state of #62's machine (pool, UTXO view,
settings, script oracle, detector observation) refuses the double spend with
that detection, and `Reach` queues any such detection, so the theorem binds a
notice to a refusal #62's machine makes, not to this node's own admission; the
handler's own script check is an input (`Env.scriptCheck`), not #62's oracle;
the composed machine is owed.

## `BsvChain.Properties.DoubleSpend` (`lean/BsvChain/Properties/DoubleSpend.lean`)

## 1. The VARINT

## `BsvChain.Properties.DoubleSpend` (`lean/BsvChain/Properties/DoubleSpend.lean`)

## 2. The callback message and the notification output

## `BsvChain.Properties.DoubleSpend` (`lean/BsvChain/Properties/DoubleSpend.lean`)

## 3. The `dsdetected` message

## `BsvChain.Properties.DoubleSpend` (`lean/BsvChain/Properties/DoubleSpend.lean`)

## 4. The detector's events over #62's admission

## `BsvChain.Properties.DoubleSpend` (`lean/BsvChain/Properties/DoubleSpend.lean`)

## 5. The handler: every request belongs to a checked notice of a detection

## `BsvChain.Properties.DoubleSpend` (`lean/BsvChain/Properties/DoubleSpend.lean`)

## 6. The blacklist and the delivery's skips

## `BsvChain.Properties.DoubleSpend` (`lean/BsvChain/Properties/DoubleSpend.lean`)

## 7. The `dsdetected` handling

## `BsvChain.Properties.Eras` (`lean/BsvChain/Properties/Eras.lean`)

# Chain-layer era theorems (#69)

The issue's two theorems in the form the machine proves, and the three era
switches the brief adds (version floors, the UAHF reader, the CSV cutoff).
Each statement names the executable definitions; each premise is stated.
[SRC] bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`:
src/pow.cpp:95–117, src/validation.cpp:3070–3117,5962–5972,6039–6104,
src/verify_script_flags.cpp:32–81, src/chainparams.cpp:1038–1068,1463–1490.

## `BsvChain.Properties.Eras` (`lean/BsvChain/Properties/Eras.lean`)

## (a) The difficulty path

## `BsvChain.Properties.Eras` (`lean/BsvChain/Properties/Eras.lean`)

## (b) BIP30

## `BsvChain.Properties.Eras` (`lean/BsvChain/Properties/Eras.lean`)

## (c) The version floors

## `BsvChain.Properties.Eras` (`lean/BsvChain/Properties/Eras.lean`)

## (d) The UAHF height

## `BsvChain.Properties.Eras` (`lean/BsvChain/Properties/Eras.lean`)

## (e) The lock-time cutoff

## `BsvChain.Properties.Finality` (`lean/BsvChain/Properties/Finality.lean`)

# Finality and fee properties (#60)

The statements concern the consensus predicates and fee stage, with arbitrary
height, time and values. [SRC] src/validation.cpp:227–247,2646–2663 at 6504a3af.

## `BsvChain.Properties.Frozen` (`lean/BsvChain/Properties/Frozen.lean`)

# Frozen outputs and the confiscation whitelist (#70)

The issue's theorems in the form the machine proves. Every list here is
operator data (the operator-list mechanism, a policy parameter); the reference's
"consensus" list is an operator list the node also applies at block connection.
Each statement names the executable definitions and states every premise.
[SRC] bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`:
src/frozentxo.cpp:27–171, src/frozentxo_db.h:179–377, src/validation.cpp:1320–1482,
2552–2665,3290–3447,3529–3555.

## `BsvChain.Properties.Frozen` (`lean/BsvChain/Properties/Frozen.lean`)

## The derivation is the reference's check

## `BsvChain.Properties.Frozen` (`lean/BsvChain/Properties/Frozen.lean`)

## Congruence: what the UTXO stage reads of the lists

## `BsvChain.Properties.Frozen` (`lean/BsvChain/Properties/Frozen.lean`)

## The records and the projection

## `BsvChain.Properties.Frozen` (`lean/BsvChain/Properties/Frozen.lean`)

## (a) The policy list: refused at admission, not consulted at connection

## `BsvChain.Properties.Frozen` (`lean/BsvChain/Properties/Frozen.lean`)

## (b) The ranged list: refused inside its intervals, not consulted outside

## `BsvChain.Properties.Frozen` (`lean/BsvChain/Properties/Frozen.lean`)

## (c) The confiscation whitelist

## `BsvChain.Properties.Frozen` (`lean/BsvChain/Properties/Frozen.lean`)

## (d) The explicit soft consensus freeze

## `BsvChain.Properties.Mempool` (`lean/BsvChain/Properties/Mempool.lean`)

# Policy-machine laws (#62)

These statements expose the qualifications in the pinned program: earlier
checks may refuse a conflicting transaction before the conflict stage; held
updates have a deliberate exception; expiry also removes young descendants;
and residual fee-delta allocations can exceed a cap after the pool is empty.
[SRC] src/validation.cpp:1031–1152, src/txmempool.cpp:2097–2110,2201–2220,
2257–2280,2736–2792 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.

## `BsvChain.Properties.Merkle` (`lean/BsvChain/Properties/Merkle.lean`)

# Header and path inclusion (#65)

[M] 2026-10-13. [SRC] bitcoin-sv v1.2.3 at
6504a3aff65ba97c0f6c80962b033e35ecbfed4b, src/consensus/merkle.cpp:57-178,284-327.
The empty path has no positional information. Inclusion additionally needs
body/header binding, an in-range position, equal branch depths and commitment
on the hashes touched by the paths. AuthenticatedBody names active/tree
lookups, height, retained body, matching headers, root binding and mutation
false. Both paths have 32-byte words; canonical literals are non-null; the
supplied path verifies against the header root. Exact Tx membership also
assumes local txid injectivity. These are premises, never domain axioms.

[LIT] 2026-10-13: BRC-74 BUMP at BRCs commit
793f18685803924e3c6433fa226ee0b5bac0dad0 (transactions/0074.md) and the TSC
merkle proof are client encodings of the leaf, path and index with a header
supplied directly or resolved by height. BUMP can carry multiple paths and
omits the header itself. After projection their root verification is
verifyPath; active header membership is a separate premise. #75 owns the TSC
codec. A one-leaf empty path here is body-derived: the pinned getmerkleproof
returns RPC -5 rather than a proof for that block (src/rpc/rawtransaction.cpp:2302-2306).

## `BsvChain.Properties.MerkleProof` (`lean/BsvChain/Properties/MerkleProof.lean`)

# The TSC proof codec and its projection to the merkle path (#75)

[M] 2026-10-13 (#75). The binary TSC codec of `BsvChain.Views.MerkleProof`
round-trips every well-formed proof (the shape of #68's `decodeTxPrefix_serTx`);
the duplicate marker read as the null word (the node's `verifymerkleproof`) and
the marker resolved by recomputation (`tscPath`) compute the same root; proof
verification is `verifyPath` of #65 over the resolved path whenever the target
supplies a root, and is false for a bare block-hash target with no header; the
model of the node's own branch generator verifies against the body root for
every in-range position whose generated hash nodes are non-null, and yields
the empty vector for a one-transaction body, the vector the RPC refuses with `-5`. Views, never rules: every theorem
is about an encoding of `(leaf, path, index, root)`; inclusion keeps #65's
premises (`active_path_inclusion`, `reachable_path_inclusion`).
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/rpc/rawtransaction.cpp:2242-2339,2342-2525,2527-2612, src/merkletree.cpp:275-346,
src/consensus/merkle.cpp:291-310. [LIT] the TSC merkle proof standard, cited in the view module.

## `BsvChain.Properties.MinerId` (`lean/BsvChain/Properties/MinerId.lean`)

# Miner ID: the frames round-trip, and what the database's transitions keep (#83)

[M] 2026-10-15 (#83). Views, never rules: nothing of Miner ID is consensus (cited in
`lean/BsvChain/Views/MinerId.lean`'s header).
The output frames of `BsvChain.Views.MinerId` read back what a miner writes (the 0.1/0.2
coinbase output, the 0.3 reference, the miner-info output, the dataref output and the
`revokemid` message); on the database: the reputation test is false for a voided miner
and after an invalid block from a CURRENT id, and it does not read the id's state; a
`revokemid` that the node accepts leaves the compromised id REVOKED; a full revocation
leaves every id of the miner REVOKED; a block that reuses a REVOKED id leaves every id
entry as it was; the recent-blocks table never holds more than N rows.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/script/instruction_iterator.h:19-128, src/script/script.h:104-133,309-320,
src/script/script.cpp:198-207, src/miner_id/miner_id.cpp:454-555,
src/miner_id/miner_info_ref.cpp:60-114, src/miner_id/miner_info_doc.cpp:445-491,
src/miner_id/miner_info.cpp:231-262, src/miner_id/revokemid.h:49-97,
src/miner_id/miner_id_db.cpp:205-329,1010-1128,1153-1166,1361-1374.

## `BsvChain.Properties.MinerId` (`lean/BsvChain/Properties/MinerId.lean`)

## The database

## `BsvChain.Properties.Oracle` (`lean/BsvChain/Properties/Oracle.lean`)

# Oracle substitution and recorded agreement (#76)

Statements quantify over every script oracle. Recording is a finite map
construction, not a cryptographic hypothesis or a claim about a node run.
The inherited UTXO laws already quantify over the oracle without restriction.
[SRC] src/validation.cpp:2503–2542,2693–2709,3326–3434 at 6504a3af.

## `BsvChain.Properties.P2P` (`lean/BsvChain/Properties/P2P.lean`)

# The P2P wire formats' laws (#78), 2026-10-15 [D]

Views of the relay layer, never block-validity rules. The framing round trip:
every command the vocabulary frames, under any payload up to 2^64 - 1 bytes,
reads back from its frame with the following stream untouched, through the
basic header (with its checksum) below 2^32 bytes and the extended header
above. The payload codecs of `inv`/`getdata`/`notfound`, `reject`,
`ping`/`pong`, `protoconf` and `version` read back their writers' bytes.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b, as cited
in `lean/BsvChain/Wire/P2P.lean`.

## `BsvChain.Properties.P2P` (`lean/BsvChain/Properties/P2P.lean`)

## 1. The vocabulary

## `BsvChain.Properties.P2P` (`lean/BsvChain/Properties/P2P.lean`)

## 2. The framing round trip

## `BsvChain.Properties.P2P` (`lean/BsvChain/Properties/P2P.lean`)

## 3. The payload codecs

## `BsvChain.Properties.P2P` (`lean/BsvChain/Properties/P2P.lean`)

## 4. The payload caps and the extended header at their boundaries

## `BsvChain.Properties.Persist` (`lean/BsvChain/Properties/Persist.lean`)

# Persistence laws (#81)

What a restart keeps and why. The load re-validates every record through the
admission machine of #62, so a transaction in the pool after a start was
accepted by `accept` at its own load step, against the load's tip and clock;
a record the load dropped carries its reason; and a run with the setting off
neither reads nor writes the files. The growth law of admission
(`accept_ids`) is the step that carries the load's survivors back to
admission's verdicts. [SRC] src/txmempool.cpp:3154-3344,
src/time_locked_mempool.cpp:247-378, src/init.cpp:237-240,1901-1905 and
src/validation.cpp:895-946,1009-1505 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.

[D] Owed on #81, none claimed here: the load law over `DumpTopological`
(a load of a `DumpTopological` dump drops no child as `missingInputs` when
its parent's step was kept), the held survivors' law `held_survivor_at_load`
(every held-pool survivor of a start has its own `kept .heldNonFinal` step),
and the restart's round trip (with the setting on, the same tip and coins and
unexpired records, a start keeps every record of the dump).

## `BsvChain.Properties.Prune` (`lean/BsvChain/Properties/Prune.lean`)

# Pruning: what the selections keep, and what a pruned block can and cannot serve (#82)

[M] 2026-10-15 (#82). Views, never rules: pruning is a node's storage setting
(cited in `lean/BsvChain/Views/Prune.lean`'s header). On the store: a block stays while
its file stays, its undo never outlives its data, and neither selection removes a file
holding a block within `minBlocksToKeep` of the tip or the file being written; the
automatic selection takes nothing at or below `nPruneAfterHeight` while `pruneblockchain`
already acts there; the RPC never prunes past the tip less `minBlocksToKeep`, and when that
is negative it answers the negative height's `uint64_t` cast and removes nothing;
`pruneheight` bounds a run of blocks that all have their data. On the answers: a block's
header, its index reads and the UTXO set survive pruning; its body and its transactions
through the index do not; a merkle proof is served exactly when the block's data or its
merkle tree is held, so "a proof the node can serve names a block it retains" is FALSE at
the pin (`merkleproof_pruned_tree_served`), and true for a node that holds no tree
(`merkleproof_served_no_tree`). On #64's undo data: pruning removes body and undo together,
so an undo the node lacks for a connected block is a block it pruned, and the spec's tip
disconnection fails at a pruned tip without moving the chain or the coins.
[D] The weakening: the store (Views §2-3) and the header tree (§6) are not bridged; `pruneTree`'s
`gone` is any predicate, so the composition "a disconnect within `minBlocksToKeep` of the tip
finds its undo" is owed, and `header_served` is a statement about the answer table, not about
#65's `verifyTsc`.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/blockfileinfostore.cpp:21-39,74-103,177-300, src/block_file_info.cpp:19-44,
src/validation.cpp:3826-3860,4065-4080,6584-6635, src/block_index.h:669-690,
src/rpc/blockchain.cpp:1810-1875,2467-2480, src/rpc/rawtransaction.cpp:2286-2300,2404-2444,
src/merkletreestore.cpp:540-570.

## `BsvChain.Properties.Reachable` (`lean/BsvChain/Properties/Reachable.lean`)

# Reachable states and the body binding (#68, G3)

[M] 2026-10-13 (#68). The states the machine's own transitions reach
from the empty state, and the invariant they keep: every retained body is
bound to its index by the header hash, and its own header commits to its
transactions with no mutation, as the block check established when the body
was stored. #65's inclusion theorem then holds for reachable states without
the per-use root-binding hypothesis: what remains is the identification of
the block (which index, at which active height) and the stated collision
disjuncts, never an axiom.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/validation.cpp:5770-5781,6134-6197,6238-6395,4913-5330,
src/consensus/merkle.cpp:284-327.

## `BsvChain.Properties.Rejects` (`lean/BsvChain/Properties/Rejects.lean`)

# Laws of the reject cache and the time budgets (#71)

Every statement here is about node policy at bitcoin-sv v1.2.3,
6504a3aff65ba97c0f6c80962b033e35ecbfed4b; none is a block-validity claim.
The four the issue names: a remembered rejection draws silence on the P2P
path until the reset (`remembered_inv_silent`, `remembered_tx_suppressed`,
`validation_rejection_remembered`); the reset follows an observed tip change
and nothing else (`reset_follows_tip_change`, `no_reset_without_tip_change`);
a timed-out high-priority request keeps its state and lowers its priority
(`timeout_high_requeues_low`, `timeout_keeps_pool`); and the budget preserves
the available-budget result or stops with a timeout answer, a high-priority
timeout deferring and a low-priority timeout completing with
`too-long-validation-time` (`budget_changes_timing_only`,
`elapsed_changes_timing_only`). A cell is judged by its clock dependence, not
by its budget's value (`budget_judgment_judging_iff`), and an inventory
reading only when both rolling filters it consults are exact
(`inventory_judging_exact`).
[SRC] src/net/net_processing.cpp:930–961,3351–3408,
src/validation.cpp:1210–1233,1349–1355,1786–1836,2037–2048 and
src/txn_validator.cpp:633–641 at 6504a3af.

These insert and silence laws are proved at the routing and inventory-envelope
levels. Their composition through acceptance is owed: stage frame lemmas must
establish preservation of the request and recentRejectsTip. No theorem here
proves that acceptance-level composition.

## `BsvChain.Properties.Rejects` (`lean/BsvChain/Properties/Rejects.lean`)

## The filter

## `BsvChain.Properties.Rejects` (`lean/BsvChain/Properties/Rejects.lean`)

## The reset follows an observed tip change

## `BsvChain.Properties.Rejects` (`lean/BsvChain/Properties/Rejects.lean`)

## A remembered rejection draws silence on the P2P path

## `BsvChain.Properties.Rejects` (`lean/BsvChain/Properties/Rejects.lean`)

## Which rejections are remembered

## `BsvChain.Properties.Rejects` (`lean/BsvChain/Properties/Rejects.lean`)

## The timeout transition

## `BsvChain.Properties.Rejects` (`lean/BsvChain/Properties/Rejects.lean`)

## The budget preserves the available-budget result or stops with a timeout answer

## `BsvChain.Properties.Relay` (`lean/BsvChain/Properties/Relay.lean`)

# The relay machine's laws (#78), 2026-10-15 [D]

Views of the relay layer, never rules of validity. The three theorems the
issue names, each in the form that holds at the pin:

* announcement: a transaction the node accepts is queued by the next
  propagator's pass for every peer that relays transactions, passes its fee
  filter and loaded filter, and is not known to have it, through each of the
  three acceptances the machine has: a peer's `tx` (`accepted_queued_for_unseen`,
  every peer but the sender), the RPC's (`rpcAccepted_queued_for_unseen`) and
  an orphan's on retry (`retryOrphan_accepted_queued_for_unseen`); a queued id
  is in the `inv` of one of that peer's flushes, the flushes following one
  another (`pending_announced_within`: index `i` in the `(i / broadcastMax + 1)`-th),
  so under any load it is announced (`accepted_announced_within`,
  `rpcAccepted_announced_within`, `retryOrphan_announced_within`); on an idle
  node the next flush is exactly one `inv` naming it
  (`accepted_announced_when_idle`); it is never announced back to a peer known
  to have it (`known_never_queued`), the sender included. The qualifiers are
  the pin's (src/net/net.cpp:852-876), and "unseen" is the machine's `known`,
  the ideal set the rolling filter approximates;
* the ban (`ban_sound_run`): a ban for misbehavior is reached only through
  recorded increments, every such entry naming a peer whose recorded
  increments sum to the threshold or more. The sentence as the issue words it,
  "a ban is reached only through recorded misbehavior increments", is false
  of the ban list at the pin: a bad message start, an oversized or malformed
  header and a stream moved across addresses ban with no increment, as does
  the operator (`ban_without_increment`, a witness by evaluation);
* the framing round trip is `unframe_frame` (`lean/BsvChain/Properties/P2P.lean`).

Beside them: the initial block download requests nothing
(`ibd_inv_requests_nothing`); a peer that asked for no transactions is
offered none (`relay_off_offered_nothing`); a miner-info data transaction is
never queued (`dataref_never_queued`); no internal reject code reaches the
wire (`step_rejects_on_wire`); a local peer is never banned for misbehavior
(`local_never_banned_by_score`).
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b, as cited
in `lean/BsvChain/Wire/Relay.lean`.

## `BsvChain.Properties.Relay` (`lean/BsvChain/Properties/Relay.lean`)

## 1. Announcement

## `BsvChain.Properties.Relay` (`lean/BsvChain/Properties/Relay.lean`)

## 2. The ban

## `BsvChain.Properties.Relay` (`lean/BsvChain/Properties/Relay.lean`)

## 3. The initial block download and the wire's reject codes

## `BsvChain.Properties.StaleRun` (`lean/BsvChain/Properties/StaleRun.lean`)

# The orphaned branch reached by the machine's own transitions (#68, G2)

[M] 2026-10-13 (#68). A concrete run of the executable transitions on
the regtest network from its actual genesis block: accept and activate
genesis; mine and activate block 1a, whose body holds the transaction T; mine
the competitor 1b on genesis; extend it with 2b; activate. The kernel checks
the run (`decide +kernel` on the definitions, no compiled code, no
`native_decide`): the active chain is genesis, 1b, 2b, and T's path verifies
against 1a's retained header while T is in no active block. Near genesis no
output is mature (coinbase maturity 100), so T is 1a's coinbase and its path
is the one-leaf empty branch. A second run invalidates 1a after its
activation: T leaves the active chain and the selected work decreases, so the
charter's "only when a chain of more work is connected" is false in the
machine. The script oracle is never called (no block spends an input).
Every height, time and nonce below is [D] synthetic input; the nonces were
found by compiled search and are checked by the kernel's proof-of-work test.
[M] 2026-10-14, #120: the kernel reduces the run only in the
two `decide +kernel` checks (and the genesis block's hash in
`staleRunGenesis_hash`). The three run states are plain definitions and the
reachability proof goes through one step stated on `staleRunActivate`; [D]
read from the measurements, not the kernel's source: the kernel then matches
each state by unfolding its name; [M] the landed form (abbreviations, the constructors' own indices) took 95 to
203 s of kernel time on the box and this one under 0.1 s. The charter
refutation closes its equation by the pair's eta (34 s by `rfl`, under 0.2 s
now). The module is its own Lake library, `StaleRunCheck`, outside
`lake build BsvChain`; the axioms leg of `tools/check.sh` builds it.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/chainparams.cpp:33-90,1511-1514, src/validation.cpp:4913-5330,6134-6395,
src/consensus/merkle.cpp:291-310.

## `BsvChain.Properties.Theorems` (`lean/BsvChain/Properties/Theorems.lean`)

# The five theorems of S6 (#68)

[M] 2026-10-13 (#68). DESIGN-S6 §4.4 names five statements; each is
proved here in its true form over the executable transitions, quantified over
the chain parameters, the node configuration, the script oracle and the
explicit time. Where the charter's sentence is false in the machine, the
explainer says what it said and why the machine says otherwise.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/coins.cpp:560-565, src/undo.h:109-112, src/processing_block_index.cpp:50-96,
src/validation.cpp:2483-2494,3326-3373,3436-3443,3655-3668,4413-4494,5234-5256,
src/consensus/merkle.cpp:291-310.

## `BsvChain.Properties.Theorems` (`lean/BsvChain/Properties/Theorems.lean`)

## Loop and preparation lemmas

## `BsvChain.Properties.Theorems` (`lean/BsvChain/Properties/Theorems.lean`)

## Well-formed coin views

## `BsvChain.Properties.Theorems` (`lean/BsvChain/Properties/Theorems.lean`)

## Fees

## `BsvChain.Properties.Theorems` (`lean/BsvChain/Properties/Theorems.lean`)

## The shape of a connected block

## `BsvChain.Properties.Theorems` (`lean/BsvChain/Properties/Theorems.lean`)

## Theorem 2: no inflation

## `BsvChain.Properties.Theorems` (`lean/BsvChain/Properties/Theorems.lean`)

## Theorem 3: inputs unspent immediately before

## `BsvChain.Properties.Theorems` (`lean/BsvChain/Properties/Theorems.lean`)

## Theorem 1: undo restores the coin set

## `BsvChain.Properties.Theorems` (`lean/BsvChain/Properties/Theorems.lean`)

## Theorem 4: maximal work after automatic activation

## `BsvChain.Properties.TxCodec` (`lean/BsvChain/Properties/TxCodec.lean`)

# The transaction serialization round trip (#68, G4)

[M] 2026-10-13 (#68). For a well-formed transaction (every field in its
wire width, every byte below 256), the interpreter's prefix decoder reads the
serializer's bytes back exactly, with any following stream left untouched.
Hence equal serializations are equal transactions, and exact transaction
identity rests on the hash hypothesis alone: equal identifiers of two
well-formed transactions are equal transactions or a SHA256d collision.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/primitives/transaction.h:51-66,89-157,175-194,233-252,
src/primitives/transaction.cpp:79-81 and src/serialize.h:71-116,211-250,296-340,786-840.

## `BsvChain.Properties.Utxo` (`lean/BsvChain/Properties/Utxo.lean`)

# One-transaction UTXO laws (#61)

All oracles, configurations, times and network parameters remain quantified.
The map is executable Finmap, with no representation-equality assumption.
[SRC] src/validation.cpp:2480–2495,2552–2665 and
src/processing_block_index.cpp:30–69 at 6504a3af.

## `BsvChain.Rejects` (`lean/BsvChain/Rejects.lean`)

# The reject cache and the validation time budgets (#71; amends #62)

Policy at bitcoin-sv v1.2.3, 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
Nothing in this module is a block-validity rule: the filter, its reset, the
two validation priorities and the time budgets are node policy, each a field
of the #59 census (`recentRejectCapacity`, `recentRejectFalsePositiveRate`,
`maxStdTxnValidationDuration`, `maxNonStdTxnValidationDuration`,
`maxTxnChainValidationBudget`, `validationClockCpu`; docs/PARAMETERS.md §8.2).

The reject cache. `CTxnRecentRejects` is a rolling bloom filter of txids,
membership only. It is written by the invalid-state handlers of a P2P request
and read by the inventory test `IsTxnKnown`; it is emptied lazily, by the
next inventory test that observes a tip hash different from the one recorded
at the previous test. A synchronous RPC submission neither reads nor writes it.
[SRC] src/txn_recent_rejects.h:20–58, src/txn_recent_rejects.cpp:9–27,
src/net/net_processing.cpp:82,930–961, src/net/net.cpp:3558–3564,
src/validation.cpp:1786–1797,1888–1932,1988–1995,2043–2048 and
src/rpc/rawtransaction.cpp:1586–1594,1625–1626 at 6504a3af.

The time budgets. A limited request is validated under a cancellation source
whose allowance is its priority's duration plus the unused time carried from
the previous transaction of its chain. When the source fires, a high-priority
request is moved to the low-priority queue with no answer, and a low-priority
request is refused with `too-long-validation-time`. The clock is the node's
(thread CPU time by default), so the elapsed time is an explicit input here
and every observation whose outcome depends on it is non-judging, whether its
budget expired or not (`ClockDependence`, `budgetJudgment`; DESIGN-S6 §4.5).
[SRC] src/validation.cpp:990–1006,1077–1078,1210–1233,1349–1355,1424–1430,
1458–1464, src/taskcancellation.h:106–179, src/txn_validator.cpp:633–641 and
src/txn_validation_config.h:36–46 at 6504a3af.

## `BsvChain.Rejects` (`lean/BsvChain/Rejects.lean`)

## The filter: reset and the wipe-free regime

## `BsvChain.Rejects` (`lean/BsvChain/Rejects.lean`)

## Which rejections are remembered

## `BsvChain.Rejects` (`lean/BsvChain/Rejects.lean`)

## The inventory envelope

## `BsvChain.Rejects` (`lean/BsvChain/Rejects.lean`)

## The priority lattice

## `BsvChain.Rejects` (`lean/BsvChain/Rejects.lean`)

## The time budget, with elapsed time as an explicit input

## `BsvChain.Rejects` (`lean/BsvChain/Rejects.lean`)

## Nondeterminism recorded as such

## `BsvChain.Status` (`lean/BsvChain/Status.lean`)

# Derived transaction status, 2026-10-13 [D] (#58, #67)

These are views, never rules. DESIGN-S6 sections 1.4 and 3 specify the
observation journals and ordered clauses. The machine's ChainState and
TxJournal are retained intact in the observation envelope.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/rpc/blockchain.cpp:79-90,440-550,2675-2693;
src/rpc/rawtransaction.cpp:1636-1650,1716-1724.

## `BsvChain.Teranode.Alert` (`lean/BsvChain/Teranode/Alert.lean`)

# BsvChain.Teranode.Alert: the alert service against the reference's frozen-TXO path (#94)

[M] 2026-10-15 (#94). Teranode takes the operator's frozen-output, confiscation, block and
peer actions from an in-process alert service whose authority is a signed alert message; the reference takes
the same actions from its RPC server, whose authority is the RPC credential. This module writes the alert
service's actions as transitions on Teranode's UTXO store, ban lists and chain, beside the transitions #70
wrote for the reference (`BsvChain.OperatorLists`, `lean/BsvChain/Frozen.lean`), and proves where the two
agree and where they do not.

The Teranode side is v0.16.0 at `4edb60a40c6628ff0ef60231c2628efd7103fde5` (`docs/PROVENANCE.md` §1a): the
node interface `services/alert/node.go` (`InvalidateBlock` :160, `BanPeer` :189, `UnbanPeer` :229,
`AddToConsensusBlacklist` :274, `AddToConfiscationTransactionWhitelist` :397, the key read at :459 by
`extractPublicKey` :538), the store calls `stores/utxo/aerospike/alert_system.go` (`FreezeUTXOs` :88,
`UnFreezeUTXOs` :165, `ReAssignUTXO` :233) and the Lua functions they call
(`stores/utxo/aerospike/teranode.lua`: `freeze` :713, `unfreeze` :795, `reassign` :870, the output read
`getUTXOAndSpendingData` :194, the spend's gates :346-411) [SRC]. The store modelled is the Aerospike backend; the instance of
record runs the SQL backend (`settings.conf:1592`), whose alert calls reach the same marks without reading the
UTXO hash (`stores/utxo/sql/alert_system.go:54-193`) and whose reassignment delay is the node setting
`utxostore_reassignedUtxoSpendableAfterBlocks` (default 1000, `settings/settings.go:528`) [SRC] 4edb60a4. The alert messages that reach the node
interface are read in `github.com/bsv-blockchain/go-alert-system` v0.1.17, the version Teranode's `go.mod:197`
requires (module sum `h1:qWh/nnN3DiP2OahWbb0hdLBNKkKHXDToSDDnxEzjJ08=`, Teranode's `go.sum`) [SRC]. The
reference side is bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: the RPC table
`src/rpc/frozentxo_rpc.cpp:897-915`, `addToConsensusBlacklist` :346-378 through `ImportFundsToDB` :188-206,
and #70's transitions [SRC].

**Kinds (rule 1).** Every list here is operator data, the operator-list mechanism of #70, never a consensus
constant; the authority that may change it (§6) is a node setting, policy. Neither node's alert or RPC path
is a rule of validity: two nodes with the same lists decide the same spends whoever wrote the lists.

What closes:
* `freeze_agrees`, `unfreeze_agrees`: an alert fund whose single interval contains the height (or whose stop
  is behind the store's height and whose policy freeze expires with it) leaves the output frozen (not frozen)
  in Teranode's store exactly as #70's `freezeConsensus` leaves it frozen (not frozen) on both of the
  reference's paths at that height, stated in `FrozenLists`, the input every reference transition reads.
* The witnesses where they differ, each a theorem over every store and every record:
  `unfreeze_keeps_policy_freeze` (a policy freeze that does not expire), `future_start_frozen_early` (an
  interval that has not begun), `stop_passed_still_frozen` (an interval that has ended under a standing
  freeze), `freeze_spent_refused` (an output an unmined transaction already spends),
  `whitelist_ignores_enforce`, `reassign_gate` and `reassign_strands` (confiscation by reassignment, not by
  a transaction whitelist), and `whitelist_not_confiscation` (no confiscation-shape check on the alert path).
* `ban_agrees`, `unban_agrees`, `ban_until_differs`: the ban lists.
* `alert_invalidate_is_operator_invalidate` and `alert_invalidate_refines`: the alert's invalidation is the
  blockchain service's own call; equality with `BsvChain.invalidateBlock` is #88's `invalidation` row,
  stated and NOT asserted.
* `trust_root_changes_who_not_what`: under any two authorities that both admit a request, the action applied
  is the same.

## `BsvChain.Teranode.Alert` (`lean/BsvChain/Teranode/Alert.lean`)

## 1. The store's output, as the alert touches it

## `BsvChain.Teranode.Alert` (`lean/BsvChain/Teranode/Alert.lean`)

## 2. The store calls

## `BsvChain.Teranode.Alert` (`lean/BsvChain/Teranode/Alert.lean`)

## 3. The node interface's actions (`services/alert/node.go`)

## `BsvChain.Teranode.Alert` (`lean/BsvChain/Teranode/Alert.lean`)

## 4. The equivalence where it holds

## `BsvChain.Teranode.Alert` (`lean/BsvChain/Teranode/Alert.lean`)

## 5. The witnesses where they differ

## `BsvChain.Teranode.Alert` (`lean/BsvChain/Teranode/Alert.lean`)

## 6. The peers and the chain

## `BsvChain.Teranode.Alert` (`lean/BsvChain/Teranode/Alert.lean`)

## 7. The authority path: a node setting, policy

## `BsvChain.Teranode.Bridge` (`lean/BsvChain/Teranode/Bridge.lean`)

# Teranode's legacy bridge as a refinement of the protocol machine (#98, the theorem half)

[M] 2026-10-18 (#98). The reading half (`docs/CONFORMANCE-TERANODE-BRIDGE.md`,
2026-10-14) classed every wire message type of the reference, 39 rows: SAME 13, TRANSLATED 7, DROPPED 19. This
module states that table as a function (`bridge`, one constructor per row) and proves what Teranode accepts through
the bridge is what #78's protocol machine (`BsvChain.Wire.Node`, `lean/BsvChain/Wire/Relay.lean`) would have
relayed, under named correspondences, with every place the two part named as a `BridgeDivergence`.

**The north star it is read under** (the maintainers' framing rule of 2026-10-18 01:4xZ, the rule of card Z8 carried to
the bridge). Teranode reaches BSV's scale without a protocol change by an architecture of services: no
traditional mempool (`docs/topics/architecture/teranode-overall-system-design.md:174` at `4edb60a4` [LIT]), the
UTXO store as the one memory of a transaction, subtrees as the unit of block work, Kafka between the services, and
the legacy service (`services/legacy/`) as the compatibility edge that speaks the reference's wire protocol to the
existing network. A message the bridge translates or drops is an architecture decision for scale, written with
Teranode's reason; only a transaction or block the two nodes decide differently would be a finding. No
`BridgeDivergence` below is such a finding: each changes what is heard, when or by whom, never whether a
transaction or a block is valid (`BridgeDivergence.cls`, all `design`, labeled policy).

**The theorems.** The transaction road (`OnTx` `services/legacy/peer_server.go:1077`, `QueueTx`
`services/legacy/netsync/manager.go:3096`, `handleTxMsg` `manager.go:1271`, the validator's `Validate`
`manager.go:1320`) is `handleTx`; the machine's relay predicate is `Relays`: the transaction joins the machine's
pool and the propagator's queue (`Node.recvTx`'s accepted branch, `RelayTransaction`
`src/net/net_processing.cpp:975-997` at `6504a3af`). `bridge_accept_relayed`: a transaction the bridge accepts from
a peer, the validator's answer agreeing with the mempool machine's verdict (`VerdictAgrees`), new to the machine,
the peer present and not under blocks-only, not a miner-info data transaction, is one the machine relays; and
`bridge_accept_reaches_peers`: the propagator's next pass queues it for every other peer that relays transactions,
passes its filters and is not known to have it (from #78's `accepted_queued_for_unseen`). The orphan road
(`processOrphanTransactions` `manager.go:1390`) is `bridge_orphan_relayed`; the inventory road (`processInvMsg`
`manager.go:2809`) `bridge_inv_requests`. `bridge_tx_refines` is the total form: every acceptance by the bridge is
a relay of the machine, or the machine already knows the transaction (its pool, its recent rejects or its orphans,
`Node.knows`) and its queue stands; the pool case is the named divergence `resubmitReannounced`, the other two are
states the two memories reach apart, measured by #98's bridge rows. The block road (`handleBlockMsg` `manager.go:1726`,
`HandleBlockDirect` `services/legacy/netsync/handle_block.go:52`, the block validation service's `ProcessBlock`
`handle_block.go:348`) is `bridgeBlockAccepts`: `bridge_block_accepted` proves the bridge adds no block acceptance
of its own (a block it accepts is one Teranode's block validation accepts, within the read bound), and with the
block verdict's agreement (`BlockVerdictAgrees`, #88's owed `block-check` and `block-connect` rows, a hypothesis
here, never asserted) one the reference processes and accepts, or the named divergence `checksumSkipped`.

**What stays to the harness.** The theorems take the correspondences as hypotheses: the validator's answer
against the mempool machine's verdict (#88's `utxo-spend`, `script-word`), the bridge's "have it" against the
machine's inventory test, the FSM's RUNNING against the machine's download latch, the block verdict against the
reference's. The mixed two-node scenario (`docs/CONFORMANCE-TERANODE-BRIDGE.md` section 4) measures
them; each divergence's reachable cell is a scenario row there.

The reference is bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`; the bridge is Teranode v0.16.0
at `4edb60a40c6628ff0ef60231c2628efd7103fde5` (`docs/PROVENANCE.md` §1a) [SRC]. Every citation below is at those
pins; the go-wire codec's are `go-wire@v1.2.11/<file>:<line>`, the version Teranode's `go.mod:205` requires, read in
the Go module cache (2026-10-18).
A view of the bridge, never a rule of validity.

## `BsvChain.Teranode.Bridge` (`lean/BsvChain/Teranode/Bridge.lean`)

## 1. The message types: the reference's 38 commands and the extended header

## `BsvChain.Teranode.Bridge` (`lean/BsvChain/Teranode/Bridge.lean`)

## 2. The bridge's handling, one constructor per row

## `BsvChain.Teranode.Bridge` (`lean/BsvChain/Teranode/Bridge.lean`)

## 3. The transaction road: `handleTxMsg`

## `BsvChain.Teranode.Bridge` (`lean/BsvChain/Teranode/Bridge.lean`)

## 4. The orphan road: `processOrphanTransactions`

## `BsvChain.Teranode.Bridge` (`lean/BsvChain/Teranode/Bridge.lean`)

## 5. The inventory road: `processInvMsg`

## `BsvChain.Teranode.Bridge` (`lean/BsvChain/Teranode/Bridge.lean`)

## 6. The block road: `handleBlockMsg`

## `BsvChain.Teranode.Bridge` (`lean/BsvChain/Teranode/Bridge.lean`)

## 7. The divergences

## `BsvChain.Teranode.Chain` (`lean/BsvChain/Teranode/Chain.lean`)

# Teranode's chain selection, longest-chain marking and invalidation (#93)

[M] 2026-10-15 (#93). Which chain a node calls the longest decides which
transactions it calls mined. This module states the second oracle's chain
selection as transitions and compares them with the reference's
`ActivateBestChain` as #64 models it (`BsvChain.activateBestChain`,
`BsvChain.invalidateBlock`, `BsvChain.reconsiderBlock`).

The second oracle is Teranode v0.16.0 at
`4edb60a40c6628ff0ef60231c2628efd7103fde5` (`docs/PROVENANCE.md` §1a), read
at the tag [SRC]:
* the blockchain service's FSM (`services/blockchain/fsm.go:17-42,70-122`)
  over looplab/fsm v1.0.2 (`go.mod:37`; its `Event`, `fsm.go:316-341` in the
  module cache at that version);
* the best header (`services/blockchain/Server.go:1679`, the store's query
  `stores/blockchain/sql/GetBestBlockHeader.go:114-137` and
  `GetBestBlockID.go:38-39`: `WHERE invalid = false ORDER BY chain_work DESC,
  peer_id ASC, id ASC LIMIT 1`); the main chain is the best row's ancestry
  (`services/blockchain/Server.go:1705`, `CheckBlockIsInCurrentChain`);
  the chain tips (`Server.go:1747`);
* the block insert (`stores/blockchain/sql/StoreBlock.go:100-437`: the parent's
  invalid flag inherited `:554-560`, the cumulative work `:1038-1052` over
  `services/blockchain/work/work.go:51-64,90`, the difficulty
  `services/blockchain/Difficulty.go:74`; the difficulty is not modeled:
  `storeBlock` takes the block's work as an argument);
* the longest-chain mark (`stores/utxo/aerospike/longest_chain.go:49-196`, the
  SQL backend's `stores/utxo/sql/sql.go:4892-4941`, the stamp
  `stores/utxo/pruner_unmined.go:29-35`) and its callers in the assembler's
  reorg (`services/blockassembly/BlockAssembler.go:1108-1175,2211-2240`,
  `services/blockassembly/subtreeprocessor/SubtreeProcessor.go:4374-4452,4573-4598`);
* optimistic mining (`services/blockvalidation/BlockValidation.go:1668,2166-2401`;
  the settings `settings/settings.go:375-376`,
  `settings/blockvalidation_settings.go:56-57`);
* invalidate and reconsider (`services/blockchain/Server.go:2380-2454,2497-2547`,
  `stores/blockchain/sql/InvalidateBlock.go:62-182`, `RevalidateBlock.go:11-72`,
  the RPC `services/rpc/handlers.go:1862-2028`, the full revalidation
  `services/blockvalidation/Server.go:1401-1450` and
  `BlockValidation.go:2001-2042,2547-2561`); the alert service's
  `services/alert/node.go:160-176` reaches the same `InvalidateBlock`, and
  the authority behind it is #94's.

The reference is bitcoin-sv v1.2.3 at
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b` [SRC]: `FindMostWorkChain`
(`src/validation.cpp:4413`), `ActivateBestChainStep` (`:4561`),
`ActivateBestChain` (`:4913`), `InvalidateBlock` (`:5230`),
`ResetBlockFailureFlags` (`:5528`), `DisconnectBlock`
(`src/processing_block_index.cpp:79`), the RPCs `invalidateblock` and
`reconsiderblock` (`src/rpc/blockchain.cpp:2732,2770`).

What closes, the issue's three theorems:
* Marking off then on is the identity on every record mined on the longest
  chain (`mark_off_on_identity`), as connect then disconnect is for the
  reference's coins (`BsvChain.Properties.s6_undo_identity`). The other order
  re-stamps the clock (`mark_on_off_restamps`): no undo, a backdated mark.
* The best header has maximal work among the rows not marked invalid
  (`best_maximal_work`); against the reference's completed activation the
  selected work agrees under a work-preserving correspondence of the two
  candidate sets (`active_work_agrees`), and the tip itself can differ only at
  equal work, where the tie rules differ (`tie_rules_differ`).
* A transaction leaves the longest chain at a block's arrival only when the
  arriving block becomes the best with more work, or with equal work and a
  smaller peer rank (`tx_leaves_only_on_more_work`); with one peer rank, more
  work strictly (`tx_leaves_strict_one_peer`). The equal-work case is real
  (`equal_work_tie_moves_tip`), and an invalidation removes without more work
  in both machines (`invalidate_lowers_work`;
  `BsvChain.Properties.s6_charter_removal_false` for the reference).
Optimistic mining is a parameter, off at the defaults
(`optimistic_off_at_defaults`); its obligation is `Validated`, which the
non-optimistic insert keeps (`storeBlock_validated`) and the optimistic one
breaks (`optimistic_best_pending`). Invalidate and reconsider map onto the
reference's: the reference clears a reconsidered block's ancestors
(`reference_reconsider_clears_ancestors`), Teranode refuses a block under an
invalid parent (`reconsider_refuses_under_invalid_parent`,
`reconsider_descendant_differs`).

Nothing here is a measurement: the witnesses are model witnesses read from
source [D]; their scenario is
`corpus/scenarios/2026-10-15-competing-branch-selection.md`, its columns owed
to #66's cut 2.

## `BsvChain.Teranode.Chain` (`lean/BsvChain/Teranode/Chain.lean`)

## 1. The blockchain service's FSM

## `BsvChain.Teranode.Chain` (`lean/BsvChain/Teranode/Chain.lean`)

## 2. The settings and the optimistic-mining option

## `BsvChain.Teranode.Chain` (`lean/BsvChain/Teranode/Chain.lean`)

## 3. The blocks table and the best header

## `BsvChain.Teranode.Chain` (`lean/BsvChain/Teranode/Chain.lean`)

## 4. The longest chain and the block insert

## `BsvChain.Teranode.Chain` (`lean/BsvChain/Teranode/Chain.lean`)

## 5. The longest-chain mark on the UTXO store

## `BsvChain.Teranode.Chain` (`lean/BsvChain/Teranode/Chain.lean`)

## 6. The optimistic-mining obligation

## `BsvChain.Teranode.Chain` (`lean/BsvChain/Teranode/Chain.lean`)

## 7. Invalidate and reconsider

## `BsvChain.Teranode.Lifetimes` (`lean/BsvChain/Teranode/Lifetimes.lean`)

# Teranode's record lifetimes against the reference's expiry and maturity (#92)

[M] 2026-10-15 (#92). How long a node keeps an unconfirmed transaction,
and when a coinbase output becomes spendable, decide what a wallet can rely
on. This module states the lifetime marks of Teranode's UTXO store as
transitions on one record and compares them with the reference's expiry and
coinbase maturity as the chain layer already has them; the size eviction
(`TrimToSize`, #62's `BsvChain.trimToSize`) is owed.

The store side is Teranode v0.16.0 at
`4edb60a40c6628ff0ef60231c2628efd7103fde5` (`docs/PROVENANCE.md` §1a), read
at the tag: the marks `stores/utxo/fields/fields.go:44` (`locked`), `:50`
(`spendingHeight`), `:72` (`deleteAtHeight`), `:79` (`unminedSince`), `:83`
(`preserveUntil`); the record's reading `stores/utxo/meta/data.go:61-64`
(`UnminedSince`, set means unmined on the longest chain); the interface
`stores/utxo/Interface.go:493-501` (`PreserveTransactions`,
`ProcessExpiredPreservations`), `:567` (`SetLocked`), `:590-594`
(`MarkTransactionsOnLongestChain`); the Lua functions of
`stores/utxo/aerospike/teranode.lua` (`spendMulti` `:284-466`, `unspend`
`:484-555`, `setMined` `:558-703`, `setDeleteAtHeight` `:974-1055`,
`setConflicting` `:1072-1098`, `preserveUntil` `:1114-1142`, `setLocked`
`:1196-1222`); the create path `stores/utxo/aerospike/create.go:892-945`; the
pruner `services/pruner/worker.go:210-262` with its phases in
`stores/utxo/pruner_unmined.go:16-151`,
`stores/utxo/aerospike/aerospike.go:1108-1402` and the delete query
`stores/utxo/aerospike/pruner/pruner_service.go:577-580` [SRC].

The store is Teranode's Aerospike backend, the one #90's module models. The SQL
backend (`stores/utxo/sql/sql.go`), which the instance of record runs under
`SETTINGS_CONTEXT=test`, writes the same marks by its own statements and is
not read line by line here: its `UnsetMined` path clears `delete_at_height`
unconditionally (`stores/utxo/sql/sql.go:3597-3615`) where the Lua function
re-evaluates it. That reading is owed with the measured leg.

The reference side is bitcoin-sv v1.2.3 at
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: the expiry
`CTxMemPool::Expire` (`src/txmempool.cpp:2201-2220`) under `-mempoolexpiry`
(`DEFAULT_MEMPOOL_EXPIRY` 336 hours, `src/validation.h:91`, resolved to
seconds at `src/config.cpp:87`), as #62's `BsvChain.expire` models it; and
the coinbase maturity of `Consensus::CheckTxInputs`
(`src/validation.cpp:2617-2625`, `COINBASE_MATURITY` = 100 at
`src/consensus/consensus.h:75`), #61's `BsvChain.checkInputCoins` [SRC].

What closes:
* Removal. `prune_only_mined_or_conflicting`: in every record the store's
  transitions reach, the pruner deletes only a record that is conflicting or
  carries a block ID. So `never_mined_kept`: a record that was never mined
  and is not conflicting survives every pruner cycle at every height, however
  old its `unminedSince`. The reference removes the same transaction once its
  entry time is older than `-mempoolexpiry` (`reference_expires_old`).
  Removal iff the reference's expiry is therefore NOT a theorem: the rules
  differ, and `expiry_rules_differ` is the witness, with the scenario
  `corpus/scenarios/2026-10-15-record-lifetimes.md` for #66's cut 2. Teranode
  counts an unmined record's age in blocks from `unminedSince` and uses it
  only to preserve the record's parents (`backdated_prunable`); the reference
  counts seconds from entry and removes. A record mined, fully spent and then
  reorganized off the longest chain keeps its deletion height while unmined
  (`reorged_spent_keeps_dah`): its survival then rests on the pruner's
  parent-preservation phase.
* Maturity. `coinbase_maturity_agrees`: for a coinbase output, at every
  record the store reaches from the coinbase's creation, Teranode's coinbase
  gate refuses it as immature exactly when the reference's `checkInputCoins`
  refuses it as `bad-txns-premature-spend-of-coinbase`, given the same
  maturity (100 on every network of both pins: `defaults_maturity_agree`),
  the same coinbase height and the same spend height. This is a theorem.
* Locked. No reference transition corresponds. `locked` is the store's
  two-phase commit between the record's creation and its hand-off to block
  assembly: a spend of its outputs is refused (`locked_refuses`) and the child
  is retried (`services/validator/Validator.go:663-690`); mining clears it
  (`setMined_unlocks`). The reference commits an accepted transaction to its
  pool in one step under the pool's lock (`CommitTxToMempool`,
  `src/validation.cpp:895`), so no accepted transaction's outputs are refused
  to a child for this reason; the nearest observable is the orphan path a
  child takes while its parent is still being validated. #96's ledger has no
  row for the mark (spec/teranode-absences.md: 19 rows, none on `locked`).
* Owed. The reference's size eviction `TrimToSize` (`src/txmempool.cpp:2704`,
  #62's `BsvChain.trimToSize`) is cited and not compared here: no theorem, no
  witness, no scenario step states it.
* Out of scope: the reorg's deletion of a coinbase's descendants
  (`services/blockassembly/subtreeprocessor/SubtreeProcessor.go:4927-4964`)
  and the validator's shed unwind (`services/validator/Validator.go:2539-2540`);
  neither reads a lifetime mark.

Every retention below is a node setting (policy), never a rule of validity;
the coinbase maturity is a chain parameter on both sides (consensus).

## `BsvChain.Teranode.Lifetimes` (`lean/BsvChain/Teranode/Lifetimes.lean`)

## The settings and the record

## `BsvChain.Teranode.Lifetimes` (`lean/BsvChain/Teranode/Lifetimes.lean`)

## The transitions

## `BsvChain.Teranode.Lifetimes` (`lean/BsvChain/Teranode/Lifetimes.lean`)

## The invariant: a deletion height marks a mined or conflicting record

## `BsvChain.Teranode.Lifetimes` (`lean/BsvChain/Teranode/Lifetimes.lean`)

## Removal: the pruner against the reference's expiry

## `BsvChain.Teranode.Lifetimes` (`lean/BsvChain/Teranode/Lifetimes.lean`)

## Maturity: the coinbase gate against the reference's

## `BsvChain.Teranode.Lifetimes` (`lean/BsvChain/Teranode/Lifetimes.lean`)

## Locked: the two-phase commit mark

## `BsvChain.Teranode.Refinement` (`lean/BsvChain/Teranode/Refinement.lean`)

# The refinement relation: Teranode's state as the components model it onto the reference machine (#88)

[M] 2026-10-15 (#88). S8's keystone: one relation from Teranode's state as the
components model it (the fields #97's contract reads marked) to the reference machine's state and #58's derived
status, the statement of each Teranode transition as a stutter, a named divergence or an owed simulation, and one
obligation per row of #87's module map (`corpus/teranode/map.json`, rendered as `spec/teranode-map.md`).
[M] 2026-10-17 (#88's close): the three measured legs (#92, #93, #94) and #140's soft freeze read in as the
`Divergence`s and the legs' witnesses, the transitions accounted per family, the list re-cut to six kinds
and emitted as `corpus/teranode/obligations.json`, rendered as section 5 of `spec/node-client-contract.md`.

The second oracle is Teranode v0.16.0 at `4edb60a40c6628ff0ef60231c2628efd7103fde5`; the reference is
bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b` (`docs/PROVENANCE.md` §1a) [SRC]. Every field of
`Obs` below cites the Teranode source that fills it, says whether #97's contract
(`docs/CONFORMANCE-TERANODE-OBSERVATION.md`) reads it, and names the reference observation it answers, at the two
pins.

**The relation.** `Obs` assembles the components' states: the UTXO store's master records with their marks
(#92's `Lifetimes.Record`), the blocks table and its best header (#93's `Chain.Row`, `Chain.bestRow`), the
blocks the blockchain service calls current, block assembly's transactions, the spenders the asset route
names, the runner's journals, the FSM state (#93), the alert-written output store and ban list (#94), and the
Kafka messages. Of these, #97's contract reads `rows`, `current`, `assembly`, the records' blocks, the spenders
and `fsm`; the records' marks, `alert`, `bans` and `events` are internal, read by no surface (#97 §0, §4, F6);
`journal` and `refused` are the runner's. `observe` is #74's derive (`docs/CONFORMANCE-TERANODE-MACHINE.md`
section 5) as a function onto #74's `Views.TeranodeState`, and it reads the contract's fields and the runner's two journals (`journal`, `refused`), never the internal ones;
`abstractStatus` reads it back onto #58's `Status` through `Views.teranodeRead`. `Refines o m` is the
conjunction of `StatusRefines` (per transaction, #74's column `Views.teranodeState` of the reference's status is
the observed state, except on `orphan`, the recorded no-function cell) and `ChainRefines` (the correspondence of
the two candidate sets that #93's bridge theorems take as hypotheses, `Chain.Validated`, the current-chain read
agreeing with the rows' ancestry, and the FSM in RUNNING, the precondition of every observation: #93's
`floater_invalidated_only_running`, #96 row `rl.fsm`, #97 §6 `fsm()`). `cover`, `back` and `validated` are
assumed by the relation; #93's hand-off ("#88 constructs it") stays owed, S1. The base case holds:
`refines_empty` relates the empty states (no block on either side); the genesis row's form is owed (S1), since
the spec defines no genesis `StatusState`. The frozen lists relate through `FrozenRefinesAt` (#94's projection),
outside `Refines`.

**The transitions** (section 9's `accounts`, one per family of `Family`; `accounts_families`). Every store
transition of one record but the block-mined one keeps `observe` (`record_step_stutters`): it maps to the
reference's identity, a stutter. The FSM's events that keep RUNNING, the ban list, the alert's store and a Kafka
publication are stutters of the status (`fsm_stutters`, `ban_stutters`, `alert_stutters`, `event_stutters`), and
so is the pruner's delete under the runner's journal of blocks (`prune_stutters`). A stutter keeps `Refines` with
the reference unchanged (`refines_of_stutter`); simulations compose (`Simulates.comp`), so any run of alert
writes, bans and Kafka publications keeps the relation (`stutter_run_simulates`) and #93's work agreement
survives it (`stutter_run_best_work`); an alert fund that freezes keeps `Refines` and leaves the frozen
projection agreeing (`alert_freeze_keeps_relation`, from #94's `freeze_agrees`). An FSM event out of RUNNING
suspends observation (`fsm_exit_suspends`: no reference state is related after it); the relation's return at the
re-entry to RUNNING is owed (S1). No transition that moves the status is proven to simulate a reference
transition at this commit: the connection (`connectSimulates`), the reorg's moveBack, moveForward and reset
(`reorgSimulates`), the assembler's drop of a conflicting transaction (`conflictDropSimulates`) and the
alert-driven invalidate (`Alert.InvalidationRefines`) are owed with S1, each naming the reference's step
(`refActivate`, `BsvChain.activateBestChain` with its context, lists, oracle and fuel) and taking Teranode's
step as a parameter: named, NOT stated. Five families leave the relation by a divergence
(`departs_carry_divergence`): the reconsider of a descendant (`Divergence.reconsiderDescendant`), the block
spending a frozen output (`Divergence.softFreezeHoldLapse`, the one chain split), the reference's expiry and its
eviction (`Divergence.unminedExpiry`, `Divergence.poolEviction`), and the alert store's reassign
(`Divergence.alertReassign`: the reassign write is the divergence itself, so no theorem says its frozen projection
agrees); the ban and the invalidate carry the authority path's design rows (`Divergence.alertBan`,
`Divergence.alertInvalidate`); the block connection, owed, carries #92's premature-block design row
(`Divergence.prematureBlockParked`). The admission (`AcceptIsEarliestSeen`) is owed.

**The divergences** (section 8, [M] 2026-10-17; [M] 2026-10-18 for #92's premature-block row). `Divergence` has the ruled rows
(`softFreezeHoldLapse` #153; `alertInvalidate`, `alertBan` #154; `reconsiderDescendant`, `tipsListing` #155;
`poolEviction` on the ledger's `tl.pool-size`, ruled `gap`) and two rows classified as design under the
maintainers' framing rule of card Z8 (`alertReassign`, the store half's reassign row; `unminedExpiry`, #92's row b), their
class the maintainers' to confirm at the close; #92's premature-block row is a design row by the maintainers' ruling of
2026-10-17 23:5xZ (card Z10, `92: design`: `prematureBlockParked`, carried by the block connection's account): one
chain split (`softFreezeHoldLapse`, #140 and #153, consensus) and eight design rows, policy. Each carries its legs and their public counts (`Divergence.witnesses`), its model objects
(`Divergence.model`) and Teranode's reason cited before the difference (`Divergence.reason`). A witnessed
divergence's obligation is the stated `Divergence.WitnessedAt`, discharged by its legs (rule 4), never asserted.

**The obligation list** (section 10, `obligations`; `obligations_rows` proves its rows are `mapRows`, the map's
54 ids in its order; `chaincheck --refinement` checks `mapRows`, each row's issue and each row's kind against
the map's `mechanism` in `corpus/teranode/map.json`, every ledger row of `corpus/teranode/absences.json` against
the obligation of its `map_id`, every landed leg's record by its path, and `corpus/teranode/obligations.json`
against the list it emits). Each row points at exactly one obligation of one kind: `theorem` (the
agreement theorems, every name resolved by the elaborator, with their premises, the legs that measured the row agreeing,
the model witnesses of a divergence on the same row, and any half still owed), `witness` (a measured leg
agreeing, the harness the judge), `design` (an architecture decision of Teranode's, its divergence policy, the row keeping its rule's label: the
divergences of the legs and the ledger rows ruled by the maintainers' rule of 2026-10-15, with their reasons),
`chain-split` (the two nodes decide the same blocks differently, consensus), `report` (a `same` row, judged by
#95's per-release gate) and `open` (stated, the Lean objects it names, its owner, the legs that measured part of
it). Every obligation carries its rule-1 label and names the ledger rows keyed to its row, whatever its kind.

Counts [M] (read from `obligations`; `kind_counts`): 54 rows; 11 theorem (5 of them also carrying model
witnesses), 1 witness, 18 design, 1 chain-split, 10 report (#95), 13 open; 6 owed halves on theorem and design rows; 19 ledger rows, 17 on design rows, 1 on the
chain-split row, 1 on a theorem row, all 19 ruled by the maintainers. [M] 2026-10-18: #98's theorem half
(`lean/BsvChain/Teranode/Bridge.lean`) discharged `tx-relay` and `reject-filter` as theorem rows and gave the
`orphans` design row its supporting theorems; each keeps the bridge's measured half owed to #98's bridge leg. The
bridge's 16 design divergences are `Bridge.BridgeDivergence`, outside the list's `Divergence`, three of them
(`resubmitReannounced`, `feeFilterBypassed`, `rejectFlattened`) named by the rows' model witnesses; the block road
(`Bridge.bridge_block_accepted`) is named on the `wire-block` design row, its horizon measured (the tips re-agree
unaided, `docs/records/20261018-145427-s8-98-teranode-bridge-horizon2-s4b.md`).

Kinds (rule 1): every relation here is a view onto the reference's status, never a rule of validity; the
settings the components read (retentions, optimistic mining, the alert's authority) are policy, at their
defaults in the components' docstrings: #93's in `docs/PARAMETERS.md` §8.9, #94's in §8.10. #92's retention and
pruner switches are in `Lifetimes.lean`'s docstring, with no PARAMETERS section yet (S3's). The two witnesses
this module adds read the reference's `excessiveBlockSize` (consensus, node-configurable) and `assumeValid`
(policy) as parameters, both in `docs/PARAMETERS.md` §8.2 with their defaults; Teranode's `excessiveblocksize`
is a parameter at its default 4294967296 (`settings/settings.go:104`), and its checkpoint skip reads no setting.

## `BsvChain.Teranode.Refinement` (`lean/BsvChain/Teranode/Refinement.lean`)

## 1. Teranode's state as the components model it

## `BsvChain.Teranode.Refinement` (`lean/BsvChain/Teranode/Refinement.lean`)

## 2. The abstraction: #74's derive, then #58's status

## `BsvChain.Teranode.Refinement` (`lean/BsvChain/Teranode/Refinement.lean`)

## 3. The relation

## `BsvChain.Teranode.Refinement` (`lean/BsvChain/Teranode/Refinement.lean`)

## 4. The transitions: stutters, the FSM's exit and the owed simulations

## `BsvChain.Teranode.Refinement` (`lean/BsvChain/Teranode/Refinement.lean`)

## 5. The frozen lists

## `BsvChain.Teranode.Refinement` (`lean/BsvChain/Teranode/Refinement.lean`)

## 6. The block's structure

## `BsvChain.Teranode.Refinement` (`lean/BsvChain/Teranode/Refinement.lean`)

## 7. The two witnesses the map gives #88

## `BsvChain.Teranode.Refinement` (`lean/BsvChain/Teranode/Refinement.lean`)

## 8. The measured legs and the divergences

[M] 2026-10-17 (#88's close, on the maintainers' plan of 2026-10-17 and their framing rule of
19:1xZ on card Z8: every difference read against Teranode's north star, scale without a protocol change; an
architecture decision is a DESIGN row with Teranode's reason cited, labeled policy; only a chain decision that
differs on the same blocks is a chain-split row). The legs' records are withheld from the public edition by name
and were not opened for this section: every count below is the public one, from the machine page
(`docs/CONFORMANCE-TERANODE-MACHINE.md` section 1) and the issues' closing comments.

## `BsvChain.Teranode.Refinement` (`lean/BsvChain/Teranode/Refinement.lean`)

## 9. The transitions by family: a stutter, a simulation, or a divergence

## `BsvChain.Teranode.Refinement` (`lean/BsvChain/Teranode/Refinement.lean`)

## 10. The obligation list

## `BsvChain.Teranode.Sentinel` (`lean/BsvChain/Teranode/Sentinel.lean`)

# BsvChain.Teranode.Sentinel: the unconfirmed-parent sentinel against the reference's word (#91)

[M] 2026-10-14 (#91). Teranode stamps a parent the UTXO store holds without a
recorded block height with its own sentinel and translates the sentinel at the GoBDK boundary; GoBDK then
computes each input's flag word with the reference's functions compiled in (`NodeConfig.bdkCalculateFlags`).
This module transcribes the translation from Teranode v0.16.0 at `4edb60a4` and GoBDK at `4eab3acd`
(`docs/PROVENANCE.md` §1) and proves the word GoBDK verifies an input under equal to the reference's at
bitcoin-sv v1.2.3 (`6504a3af`):

* on the mempool path, for every parent height up to `int32Max` or unconfirmed parent and every tip below
  `int32Max`, the reference's mempool word (`teranode_word_eq_mempool_word`);
* at block connection, on the validator paths that set `Options.UnconfirmedParentsAtCandidateHeight`
  (CheckBlockSubtrees and CheckSubtree's legacy branch; CheckSubtree's peer-facing branch runs without it,
  `services/subtreevalidation/Server.go:954–963`), the reference's block word, a same-block parent's coin standing
  at the block's own height (`teranode_word_eq_block_word`);
* the two pairs where they differ, each kernel-checked: a consensus-mode call WITHOUT that option refuses an
  unconfirmed parent before any word is computed (`teranode_unconfirmed_refused_without_option`), where the
  reference connects a same-block parent under the block word, and a confirmed parent's word there is the
  reference's block word (`teranode_word_without_option`); and the reference's
  `-promiscuousmempoolflags` word on a chain that does not require standardness, for which neither Teranode
  nor GoBDK has a setting (`teranode_word_ne_promiscuous`; policy, a node's setting, never block validity).

Both words read one configuration's chain heights and era heights (`SameEras`), nothing of the policy
limits. Whether the refusal of the bullet above (`teranode_unconfirmed_refused_without_option`) reaches a verdict on a block the reference accepts depends
on which Teranode caller runs consensus mode without the option and on the block-level backstops behind it
(the module map of #87, the driven instance of #74); this module proves the word, not the verdict.

## `BsvChain.Teranode.Sentinel` (`lean/BsvChain/Teranode/Sentinel.lean`)

## The heights as Teranode writes them

## `BsvChain.Teranode.Sentinel` (`lean/BsvChain/Teranode/Sentinel.lean`)

## The substitution (`services/validator/ScriptVerifierGoBDK.go:40–93`)

## `BsvChain.Teranode.Sentinel` (`lean/BsvChain/Teranode/Sentinel.lean`)

## The call into GoBDK (`services/validator/ScriptVerifierGoBDK.go:261–313`)

## `BsvChain.Teranode.Sentinel` (`lean/BsvChain/Teranode/Sentinel.lean`)

## The parent as each node records it, and the reference's words

## `BsvChain.Teranode.Sentinel` (`lean/BsvChain/Teranode/Sentinel.lean`)

## The theorems

## `BsvChain.Teranode.Spend` (`lean/BsvChain/Teranode/Spend.lean`)

# Teranode's UTXO-store spend against the reference's conflict rule (#90)

[M] 2026-10-14 (#90). Which of two conflicting spends a node keeps
decides what a wallet sees. This module states the second oracle's store
spend as a transition and compares it with the reference's earliest-seen rule.

The store side is Teranode v0.16.0 at
`4edb60a40c6628ff0ef60231c2628efd7103fde5` (`docs/PROVENANCE.md` §1a), read
at the tag: the per-output spend of the Lua UDF `spendMulti`
(`stores/utxo/aerospike/teranode.lua:284-466`), the store's `Spend` with its
rollback (`stores/utxo/aerospike/spend.go:387-548`), the validator's
mempool path (`services/validator/Validator.go:1105-1257`), the conflicting
mark (`stores/utxo/aerospike/conflicting.go:42`, `SetConflicting`), the
reorg swap (`stores/utxo/process_conflicting.go:135,458`), its caller
(`services/blockassembly/subtreeprocessor/SubtreeProcessor.go:4159-4264`)
and the unmined mark (`stores/utxo/aerospike/longest_chain.go:49`) [SRC].

The store is Teranode's Aerospike backend; the SQL backend
(`stores/utxo/sql/sql.go`), which the `test` settings context selects
(`settings.conf:1592`, `utxostore.test = sqlite:///utxostore`), reaches the
same per-output outcomes by a per-input enqueue into one serialized batch
(`sql.go:223,2104-2128,2206-2207,2275`) [SRC] 4edb60a4. The instance of
record runs `SETTINGS_CONTEXT=test` (`docs/lanes/harness.md`, A3), so it
drives SQLite. The witnesses are about the model, which is the Aerospike
store; `concurrent_outcome_iff` states the per-record condition the empty
outcome needs, and its docstring says what meets it on each backend.

The reference side is bitcoin-sv v1.2.3 at
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: the conflict stage
(`src/validation.cpp:1147-1152`), the detector insertion
(`src/validation.cpp:1484-1494`) and the spent index
(`src/txmempool.cpp:298-304`) [SRC], as `BsvChain.stageConflict`,
`BsvChain.stageDetector` and `BsvChain.hasPoolConflict` model them.

What closes:
* `accepted_eq_mempool`: under sequential arrival (each submission's store
  calls finish before the next begins) and no reorg, for every arrival order
  the store keeps exactly the transactions the reference's earliest-seen rule
  keeps, in the same order, given one oracle for every other check.
* `conflict_bridge` and `accept_conflict_refuses`: the reference model's
  conflict test is BsvChain's stage-5 predicate, and BsvChain's complete
  `accept` refuses on it.
* `accepted_eq_accept_of_earliestSeen`: the same equality against BsvChain's
  complete `accept` for one arrival order `txs`, under
  `AcceptIsEarliestSeen … txs`, which is stated and NOT asserted (the
  remaining obligation). It is restricted to the run: each submission of
  `txs`, on the pool `accept` built from the ones before it, moves the
  accepted pool as `refSubmit` does with `valid`.
* Two witnesses, each `decide`-checked: a concurrent interleaving of the
  per-output spends in which the store keeps neither of two conflicting
  transactions while the reference keeps one (`concurrent_both_refused`, with
  the exact condition over every schedule in `concurrent_outcome_iff`), and
  a reorg in which the store restores the earlier mempool spender while the
  reference re-admits the disconnected block's spender (`reorg_keeps_differ`).

## `BsvChain.Teranode.Spend` (`lean/BsvChain/Teranode/Spend.lean`)

## The abstract transaction and the two states

## `BsvChain.Teranode.Spend` (`lean/BsvChain/Teranode/Spend.lean`)

## The store's spend, per output

## `BsvChain.Teranode.Spend` (`lean/BsvChain/Teranode/Spend.lean`)

## The reference's earliest-seen rule

## `BsvChain.Teranode.Spend` (`lean/BsvChain/Teranode/Spend.lean`)

## The per-output lemmas

## `BsvChain.Teranode.Spend` (`lean/BsvChain/Teranode/Spend.lean`)

## The sequential theorem

## `BsvChain.Teranode.Spend` (`lean/BsvChain/Teranode/Spend.lean`)

## The bridge to BsvChain's mempool

## `BsvChain.Teranode.Spend` (`lean/BsvChain/Teranode/Spend.lean`)

## The witness of concurrent arrival

## `BsvChain.Teranode.Spend` (`lean/BsvChain/Teranode/Spend.lean`)

## The reorg witness

## `BsvChain.Teranode.Subtree` (`lean/BsvChain/Teranode/Subtree.lean`)

# Teranode's subtree merkle root against the reference's flat root (#89)

[M] 2026-10-14 (#89). The two pins: Teranode `v0.16.0` =
`4edb60a40c6628ff0ef60231c2628efd7103fde5` and its go-subtree module `v1.5.1`
(go.mod:17, go.sum:142 `h1:l/Qui+HT+yQKXIoCW4zAyBlD2St9iLjC9ydvzcr9YSM=`);
bitcoin-sv `v1.2.3` = `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.

[SRC] Teranode validates a body's merkle root in model/Block.go:2709-2771
(`CheckMerkleRoot`): the leading subtree's root with the coinbase txid put in
place of its placeholder (:2737, via `RootHashWithReplaceRootNode`,
subtree.go:544-562 (v1.5.1), which recomputes from the nodes (it never reads
the cache)), every other subtree's `RootHash` (:2744), and for more than one
subtree `blockMerkleRoot` (:2793-2879): the shape rules of
model/subtree_body_shape.go:37-60 (the leading subtree's leaf count a power
of two, the middle ones equal to it, the last one no longer), the last root
lifted to the leading subtree's height when short (the power-of-two note
Block.go:2820-2833; the lift :2852-2876), and `ComposeSubtreeRootsToMerkleRoot`
(subtree_body_shape.go:75-103): a duplicate-root scan, then one more go-subtree
tree over the roots. The leading root, the top tree and the root of a subtree
built in memory are go-subtree's `BuildMerkleTreeStoreFromBytes`
(merkle_tree.go:45-94 at v1.5.1), which pads the level to a power of two with
the zero word and treats the zero word as "no node" (merkle_tree.go:127-161).
For a subtree read from storage `RootHash` is the header's cached claim
(subtree.go:481-483,837-839): the model takes it as `claim`, and the theorem
takes `RootsAnchored`, the binding of claim = recomputed = key that quick
validation runs (services/blockvalidation/quick_validate.go:1292-1304,
model/subtree_meta_reader.go:57-111); the stored-load path of Block.Valid
checks the claim against the key only (model/Block.go:2423-2433).

[SRC] The reference hashes the flat list of transaction ids
(src/consensus/merkle.cpp:312-319 `BlockMerkleRoot`) with the duplicate-last
rule (stated at merkle.cpp:21-24; done at :215-222,239-244,269-270) and the mutation flag (merkle.cpp:210-213); #63's
`computeMerkleRoot` is that computation.

[D] What is proven here, for every list of transaction ids and every subtree
size that is a power of two (the dynamic-size flag of settings.go:313 only
chooses the size, so it is a parameter):

* `compose_eq_flat`: the root over the subtree roots, the last one lifted,
  equals the flat root, and the flat `mutated` flag is the OR of every
  subtree's flag and the top tree's flag. No premise beyond the shape.
* `storeRoot_eq_computeMerkleRoot`: go-subtree's zero-sentinel builder equals
  the reference's root when no paired word is the zero word.
* `subtreeRoot_eq_blockMerkleRoot`: every root Teranode's check accepts is the
  flat `BlockMerkleRoot` root, for every body shape a peer can send, under
  `BodyNonzero` (no word Teranode's builder pairs in this body is the zero
  word: go-subtree reads it as "no node", merkle_tree.go:138-140; neither
  source checks it; a body that breaks it carries a SHA256d preimage of the
  zero word) and `RootsAnchored` (every stored subtree's header root equals
  its nodes' root). `ZeroFree` is a sufficient condition for `BodyNonzero`
  (`bodyNonzero_of_zeroFree`), not the premise of record.
* `zero_leaf_counterexample`: the zero-word premise is needed by the model:
  at a zero transaction id the builder and the reference disagree.
  Infeasible: a zero txid needs a SHA256d preimage of the zero word.

The mutation flag has no counterpart in Teranode's root: it rejects a repeated
subtree root (any two, not only siblings) and a repeated transaction id
(model/Block.go:912-940); the flag's decomposition is `compose_eq_flat`'s
second half, and the vectors of `corpus/merkle/subtree-vectors.jsonl` carry
both behaviors per case.

## `BsvChain.Teranode.Subtree` (`lean/BsvChain/Teranode/Subtree.lean`)

## The reference's merkle root, fuel-free

## `BsvChain.Teranode.Subtree` (`lean/BsvChain/Teranode/Subtree.lean`)

## The structural theorem: the composed root is the flat root

## `BsvChain.Teranode.Subtree` (`lean/BsvChain/Teranode/Subtree.lean`)

## The builder: zero-sentinel levels equal the reference's levels

## `BsvChain.Teranode.Subtree` (`lean/BsvChain/Teranode/Subtree.lean`)

## Teranode's check against the flat root

## `BsvChain.Teranode.Subtree` (`lean/BsvChain/Teranode/Subtree.lean`)

## The premise is needed: a zero transaction id

## `BsvChain.Utxo` (`lean/BsvChain/Utxo.lean`)

# The UTXO transition (#61)

Executable finite maps implement DESIGN-S6 §1's `Map OutPoint Coin`.
Finmap uses association lists modulo permutation, with unique keys and
lookup extensionality; its executable operations are the definitions proved
about here, so no unproved map implementation stands between model and run.
The source is bitcoin-sv v1.2.3 at
6504a3aff65ba97c0f6c80962b033e35ecbfed4b.

`checkTxInputs` is the non-coinbase input stage in source order.
`applyTx` supplies the block caller's unavailable-input reason, performs the
required script judgments, and updates coins. It is not a complete block or
admission validator: finality, sequence locks, size, sigops, coinbase structure
and subsidy belong to their callers (#60, #62, #63, #64). The existing output
and distinct-input loops guard the mutation's structural preconditions.

## `BsvChain.Views.Events` (`lean/BsvChain/Views/Events.lean`)

# Event vocabularies, 2026-10-15 [D] (#84)

Every definition and theorem here is a view, never a rule. The reference's
outward events are its ZMQ topics and its invalid-transaction sinks; this
module names each topic and payload at the pin and maps the machine's
transitions onto the events the node publishes. An event with no machine
transition and a transition with no event are recorded as such, by name.
[M] 2026-10-15 (#84): the node of record and the wallet build are
configured with `BUILD_BITCOIN_ZMQ=OFF` (their CMakeCache.txt), so no topic
exists on them; the measurement runs a third binary of the same pin with the
option ON (record docs/records/20261015-035435-s7-84-events-s1.md).

[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/zmq/zmqnotificationinterface.cpp:33-47 (the nine signal slots),:59-80
(the eleven notifier factories),:176-352 (the slot bodies);
src/zmq/zmqpublishnotifier.cpp:22-36 (the message names),:104-158 (the
frames),:160-292 (each notifier's payload); src/txmempool.h:284-303,326-340;
src/txmempool.cpp:865-872 (the removal topic split); src/invalid_txn_publisher.cpp:76-181,254-303;
src/invalid_txn_sinks/zmq_sink.cpp:11-20; src/invalid_txn_sinks/file_sink.cpp:12-40,146-183;
doc/zmq.md:57-143. Teranode has no ZMQ (corpus/teranode/absences.json rows
tl.zmq-announce and tl.zmq-removal); its Kafka topics map onto these by
docs/CONFORMANCE-TERANODE-OBSERVATION.md section 5.

## `BsvChain.Views.MerkleProof` (`lean/BsvChain/Views/MerkleProof.lean`)

# The proof surface: getmerkleproof, getmerkleproof2 and the TSC proof format (#75)

[M] 2026-10-13 (#75). Every definition here is a view of #65's
`(leaf, path, index, root)`, never a rule: a proof object is a client
encoding of a merkle branch, and its verification is `verifyPath`. Hash words
are internal-order 32-byte words; the RPC's hex strings are the reversed
display order, which the views below render with `hexEncode` of the reversed word.

**`getmerkleproof` [SRC] src/rpc/rawtransaction.cpp:2242-2339 at
6504a3aff65ba97c0f6c80962b033e35ecbfed4b.** Parameters: `txid` (required) and
`blockhash` (optional, :2259-2261; without it the block is found only through
an unspent output or `-txindex`, :2253-2256, `GetBlockIndex` at :2286).
The help text marks it DEPRECATED in favour of `getmerkleproof2` (:2250). The
result (:2322-2338): `flags` always 2, meaning `txOrId` is a transaction id
and `target` is a block header (:2264, :2324); `index`, the transaction's
position in the block (:2265, :2325); `txOrId`, the txid hex (:2266, :2326);
`target`, the verbose header object as `getblockheader true` renders it
(:2267, :2336); `nodes`, one hash per level with the string `*` for a null
word, "a copy of the calculated node" (:2268-2269, :2309-2319, :2337).
Errors: "Block for this transaction not found" (:2288-2291), "Can't read
block from disk" (:2297-2300), and RPC `-5` (`RPC_INVALID_ADDRESS_OR_KEY`) with the text
`Transaction(s) not found in provided block` when the proof vector is empty
(:2302-2306). The pinned regtest node answers exactly that `-5` for a block
containing only its coinbase (a finding on #75 of 2026-10-13, measured again by
the record below): `GetMerkleProof` reaches the root at once for a one-leaf
tree and returns an empty vector (src/merkletree.cpp:335-339), so the node
supplies NO proof for a lone transaction; the offset-0 reading (index 0, an
empty branch, the lone leaf) is body-derived, never a node output.

**`getmerkleproof2` [SRC] src/rpc/rawtransaction.cpp:2342-2525 at 6504a3af;
the issue's `src/rpc/client_utils.cpp:137` is the CLI's conversion row for
its third parameter, the server handler is the function above.** Parameters
(:2362-2366, read at :2404-2418): `blockhash` (required, the empty string
meaning "find the block", :2362, :2407-2409), `txid` (required), `includeFullTx`
(default false, :2416), `targetType` (default `hash`; `header` or `merkleroot`,
refused otherwise with `RPC_INVALID_PARAMS`, :2421-2427) and `format` (default
`json`; `binary` is refused at the pin with `RPC_INVALID_PARAMS`, the JSON-RPC
code `-32602` (src/rpc/protocol.h:28), and the text `format is 'binary',  must be 'json'`,
:2429-2436; the source comment says "enable binary in next version"; [M] measured
on the pinned regtest node by the record docs/records/20261014-015319-s6-75-regtest-s3.md). So the node of record serves the JSON form
only; the binary TSC form below is the standard's, measured here by decoding
the node's JSON into the structure and re-encoding. The result (:2465-2524):
`index` (:2468); `txOrId`, the txid hex or, with `includeFullTx`, the whole
transaction hex (:2471-2499); `targetType`, present only when it is not
`hash` (:2503-2504); `target`, the 80-byte header hex (:2505-2510), the block
hash hex (:2512-2514) or the merkle root hex (:2516-2518); `nodes` as above
(:2454-2460, :2522). The same `-5` for an empty vector (:2447-2450). The
command table at :2631 lists the positional names as `txid, blockhash` while
the handler reads `params[0]` as the block hash and `params[1]` as the txid
(:2404-2409); the names only serve named-argument conversion.

**`verifymerkleproof` [SRC] src/rpc/rawtransaction.cpp:2527-2613 at
6504a3af.** Accepts the `getmerkleproof` object with `flags` 2 only
(:2565-2572), reads `target.merkleroot` (:2588), maps `*` to the null word
(:2601-2607) and compares `ComputeMerkleRootFromBranch` with the root
(:2610-2611): the node's own verification is `verifyPath` over the marker
reading, which the theorems of `BsvChain.Properties.MerkleProof` relate to
the recomputed-duplicate reading.

**The marker [SRC] src/merkletree.cpp:294-346 and src/consensus/merkle.cpp:291-310
at 6504a3af.** `GetMerkleProof(index, skipDuplicates)` walks the stored levels:
a sibling in range is emitted (:304-308); when the sibling is the level's
virtual duplicated parent, the actual hash is emitted unless the previous
level already emitted a marker (:309-321); the last node of a level with an
odd count emits the marker (:322-334); a level of one node is the root
(:335-339). `ComputeMerkleRootFromBranch` reads a null word as "hash the
running value with itself" (src/consensus/merkle.cpp:297-301), so a `*` stands for the running hash
at that level; `tscPath` below resolves it by recomputation.

**The TSC format [LIT].** The "Merkle Proof Standardised Format" at
https://tsc.bsvblockchain.org/standards/merkle-proof-standardised-format/
(retrieved 2026-10-13T23:44:03Z, 190341 bytes, sha256
`438f2ffb08a225769761934c40479ea7aa0e893e74eae780d7619b5c58c916e7`; the URL the
source comments at :2345, tsc.bitcoinassociation.net, answered 403 at
2026-10-13T23:44:04Z). Binary form: `flags` (one byte), `index` (varint),
`txLength` (varint, only when flag bit 0 is set), `txOrId` (32 bytes or the
transaction), `target` (32 or 80 bytes by flag bits 1 and 2), `nodeCount`
(varint), then nodes, each a type byte: 0 a 32-byte hash, 1 a duplicate with
no value, 2 an index varint "reserved for use in an extension format". Flag
bit 0: txid (0) or full transaction (1); bits 1 and 2, `(flags & 6) >> 1`:
0 a block hash, 1 a block header, 2 a merkle root; bit 3 the proof type
(tree, an extension); bit 4 composite (an extension). Binary words are the
reverse of the hex display order ("Endianness"). The JSON form omits the flags
byte: `index`, `txOrId` (64 hex characters for an id, longer for a
transaction), `target`, `nodes` of hex strings with `*` for "a copy of the
calculated node", optional `targetType` (`hash` default, `header`,
`merkleRoot` in the document's spelling; the node writes `merkleroot`),
`proofType` and `composite`. This module covers the simple standard: the
decoder refuses the extension bits and the index node type.

## `BsvChain.Views.MerkleProof` (`lean/BsvChain/Views/MerkleProof.lean`)

## The binary codec [LIT]

## `BsvChain.Views.MerkleProof` (`lean/BsvChain/Views/MerkleProof.lean`)

## The projection to #65's `(leaf, path, index, root)`

## `BsvChain.Views.MinerId` (`lean/BsvChain/Views/MinerId.lean`)

# Miner ID: the document formats, what the node validates and indexes, revocation, the RPC surface (#83)

[M] 2026-10-15 (#83). NOTHING HERE IS CONSENSUS. Miner ID is a voluntary
service of the miners ("in no way mandatory", [SRC] src/miner_id/miner_id.h:23-24 at
6504a3aff65ba97c0f6c80962b033e35ecbfed4b); the node's Miner ID database and dataref
index exist only when switched on (`-minerid`, default off,
src/miner_id/miner_id_db_defaults.h:18 and src/init.cpp:4095-4109); whatever the setting,
`FindMinerId` runs on every disconnected block. That block's miner-info transaction (and,
with the dataref index, its dataref transactions) is left out of the mempool's
re-admission after a reorg (src/validation.cpp:4110-4113,
src/txmempool.cpp:2494-2545,2359; the `filtered` input of
`BsvChain.Chain.addToDisconnectPool`, which `findMinerId` here can now supply). The node's
own miner-info and dataref transactions leave its mempool when another miner's block
connects (src/validation.cpp:4769-4810, src/init.cpp:3535-3536). These are mempool
effects, never a block's validity; every definition below is a view of a node's own
index, never a rule.

A block is never refused for its Miner ID [SRC]: the database hears of a block only
after `ConnectBlock` has accepted it (`BlockAdded`, src/validation.cpp:4331-4339), after
its disconnection (`BlockRemoved`, :4119-4122), or after its failure is decided
(`InvalidBlock` from `InvalidBlockFound`, :2462-2476). It returns nothing to any of them
and catches its own exceptions (src/miner_id/miner_id_db.cpp:162-202,205-239). In
src/validation.cpp no other line names a Miner ID function or global (`git grep -n
'FindMinerId\|IsMinerId\|IsMinerInfo\|g_minerIDs' 6504a3af -- src/validation.cpp` reads
2474-2475, 4120-4121, 4332-4334 only). The reputation has one reader, a peer's `authresp`
authentication (src/net/net_processing.cpp:2245-2249), never a block. Every parameter
below is a node setting (policy in the spec's sense), named with its default and
its source.

**Sources.** The reference is bitcoin-sv v1.2.3 at
6504a3aff65ba97c0f6c80962b033e35ecbfed4b; every `[SRC]` below is a file and lines
there. The protocol document [LIT] is the BRFC "minerId" README of
`bitcoin-sv-specs/brfc-minerid` at commit e28671bee520c45ce8bcfaf3a608e5099bb5aa42
(https://raw.githubusercontent.com/bitcoin-sv-specs/brfc-minerid/master/README.md,
read 2026-10-15T03:27:34Z, 29904 bytes, sha256
`457e7725ae3b1032efbf9747f6bd83e45caf232e2ed7c5aa10c2a65dec939b80`), its block-binding
page `docs/block_binding_technique.md` at the same commit (read 2026-10-15T03:27:51Z,
3173 bytes, sha256 `da289aa51c8846a60eebb8f89e2544410631af88c47f57672b39e9663fc7c592`)
and the P2P page `p2p/miner_id.md` of `bitcoin-sv-specs/protocol` at master
67d7de07c75d03598fb059d59c61c29ae3dbf87b (read 2026-10-15T03:27:51Z, 7211 bytes, sha256
`7272bf75d5e6ee4d5fe8536ee251e726e0b54a7719aa3736cd6e3d317f947a5d`). Where the node and
the document differ, both are recorded with their citations (rule 15); the node's
reading is the one these views execute.

**The two output formats.** Version 0.1/0.2 (the document's changelog, README.md lines 484-486)
carries the coinbase document in the coinbase itself: `OP_0 OP_RETURN 0x04 ac1eed88`
then pushes of the static document, its signature, and optionally a dynamic document
and its signature (src/script/script.cpp:198-207, src/miner_id/miner_id.cpp:454-555).
Version 0.3 (the document's 1.0) puts a reference in the coinbase,
`OP_0 OP_RETURN 0x04 601dface 0x00 txid blockBind sig(blockBind)`
(src/script/script.h:309-320, src/miner_id/miner_info_ref.cpp:60-114), and the miner-info
document in another transaction of the same block,
`OP_0 OP_RETURN 0x04 601dface 0x00 doc sig(doc)` (src/miner_id/miner_info_doc.cpp:445-491);
dataref transactions carry `OP_0 OP_RETURN 0x04 601dface 0x00 json`
(src/miner_id/miner_info.cpp:231-262).

**Node and document, where they differ [SRC] / [LIT].** (1) Hashes: the node signs and
verifies over ONE SHA-256 of the message bytes (src/miner_id/miner_id.cpp:87-100,
src/miner_id/miner_info_doc.cpp:145-182, src/miner_id/miner_info.cpp:109-125,
src/miner_id/revokemid.cpp:63-74); the document writes `HASH256` for `prevMinerIdSig`,
`prevRevocationKeySig` (README.md lines 121,124), `Hash256` for the revocation message
(README.md lines 145) and the block bind (block_binding_technique.md lines 32); its P2P page writes
SHA256 for `revokemid` (miner_id.md lines 108-119). (2) The miner-info signature
`sig(miner-info)`, "the main signature" of the document (README.md lines 175), is checked by the
node for its LENGTH only (64 to 72 bytes, src/miner_id/miner_info_doc.cpp:485-486 with
src/miner_id/miner_info.cpp:188-191); the document is bound through its txid inside the
modified coinbase that the block-bind signature covers (src/miner_id/miner_info.cpp:66-98).
(3) The document says the miner-info output is at index 0 (README.md lines 73); the node takes
the lowest-index output of the transaction that carries the prefix, wherever it is
(src/miner_id/miner_info.cpp:42-48). (4) The node never compares the version 0.3
document's `height` with the block's height (ParseMinerInfoDoc checks `height > 0`
only, src/miner_id/miner_info_doc.cpp:364-368; `FindMinerId` passes no height to it,
src/miner_id/miner_id.cpp:589); only `createminerinfotx` requires the next height
(src/rpc/miner_info.cpp:450-451). The static 0.1/0.2 document's height must equal the
block's (src/miner_id/miner_id.cpp:133-148). (5) The DER check on signature strings is the
regular expression `304[0-8]02([0-9a-fA-F]{2}){61,69}` (src/miner_id/miner_info.cpp:172-181);
the document says 70-72 bytes (README.md lines 121,154). (6) A static document of version
`0.3` in the 0xac1eed88 format is always refused: `0.3` is in `SUPPORTED_VERSIONS`
(src/miner_id/coinbase_doc.h:23) but the previous-id signature has no branch for it
(src/miner_id/miner_id.cpp:206-228). (7) The reference's text for
`doc_parse_error_invalid_prev_revocation_key_sig` reads "invalid revocationMessageSig"
(src/miner_id/miner_info_error.cpp:58-60).

**What the node indexes.** The miner ID database (src/miner_id/miner_id_db.h:100-268)
keeps, under LevelDB at `miner_id/MinerIdDB` (miner_id_db.cpp:1412-1421), one entry per
miner ID (prefix 'I', keyed by the key's hash: the miner's UUID, the key, the previous
key, the state CURRENT/ROTATED/REVOKED, the next key, the creation block and the coinbase
document), one entry per miner (prefix 'U': reputation M, void flag and voiding key, last
M decrease, earliest and latest block, latest id), the recent blocks (prefix 'B': hash,
height, miner, miner id) and the state (prefix 'S': version 1, best block, synced). The
dataref index (src/miner_id/dataref_index_detail.h:38-117) keeps, at `miner_id/dataRefTxDB`,
the miner-info ('I') and dataref ('T') transactions with their block and merkle proof.
`Db` and `DataRefIndex` below are those contents as views; `blockAdded`,
`processRevokemid`, `invalidBlock`, `prune` and the index's add and delete are the
transitions.

**Revocation.** A version 0.3 document carrying `revocationMessage` revokes, partially
(the key rolls: `minerId ≠ prevMinerId`; every id from the current back to the
compromised one is REVOKED and a new id is created) or fully (no roll: every id of the
miner is REVOKED), src/miner_id/miner_id_db.cpp:1009-1128,1219-1253; the P2P `revokemid`
message revokes without a block (miner_id_db.cpp:241-296, src/net/net_processing.cpp:4523-4568;
its wire format src/miner_id/revokemid.h:49-97). Only version 0.3 carries revocation keys
(src/miner_id/coinbase_doc.cpp:16-30), so no 0.1/0.2 document can revoke.

## `BsvChain.Views.MinerId` (`lean/BsvChain/Views/MinerId.lean`)

## 1. The output frames

## `BsvChain.Views.MinerId` (`lean/BsvChain/Views/MinerId.lean`)

## 2. The JSON values as UniValue reads and writes them

## `BsvChain.Views.MinerId` (`lean/BsvChain/Views/MinerId.lean`)

## 3. Text helpers the parsers call

## `BsvChain.Views.MinerId` (`lean/BsvChain/Views/MinerId.lean`)

## 4. The documents

## `BsvChain.Views.MinerId` (`lean/BsvChain/Views/MinerId.lean`)

## 5. The block: the block bind and `FindMinerId`

## `BsvChain.Views.MinerId` (`lean/BsvChain/Views/MinerId.lean`)

## 6. The node's settings (policy: node settings, never consensus)

## `BsvChain.Views.MinerId` (`lean/BsvChain/Views/MinerId.lean`)

## 7. The database as a view, and its transitions

## `BsvChain.Views.MinerId` (`lean/BsvChain/Views/MinerId.lean`)

## 8. Revocation by P2P message and RPC

## `BsvChain.Views.MinerId` (`lean/BsvChain/Views/MinerId.lean`)

## 9. The dataref index as a view

## `BsvChain.Views.MinerId` (`lean/BsvChain/Views/MinerId.lean`)

## 10. The RPC surface

## `BsvChain.Views.Prune` (`lean/BsvChain/Views/Prune.lean`)

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

## `BsvChain.Views.Prune` (`lean/BsvChain/Views/Prune.lean`)

## 1. The settings and the network data (policy; never consensus)

## `BsvChain.Views.Prune` (`lean/BsvChain/Views/Prune.lean`)

## 2. The block files

## `BsvChain.Views.Prune` (`lean/BsvChain/Views/Prune.lean`)

## 3. The two selections

## `BsvChain.Views.Prune` (`lean/BsvChain/Views/Prune.lean`)

## 4. `pruneblockchain`

## `BsvChain.Views.Prune` (`lean/BsvChain/Views/Prune.lean`)

## 5. What the node answers for a block

## `BsvChain.Views.Prune` (`lean/BsvChain/Views/Prune.lean`)

## 6. The undo data of #64: a pruned index has neither body nor undo

## `BsvChain.Views.Prune` (`lean/BsvChain/Views/Prune.lean`)

## 7. The checks that run when the module builds

## `BsvChain.Views.Status` (`lean/BsvChain/Views/Status.lean`)

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

## `BsvChain.Views.Wire.AtomicBEEF` (`lean/BsvChain/Views/Wire/AtomicBEEF.lean`)

# Atomic BEEF (BRC-95) as a view (#86)

[M] 2026-10-15 (#86). [LIT] BRC-95 "Atomic BEEF Transactions",
bsv-blockchain/BRCs at 5333fd449c70fd5982029876376dcf1ed9c64ffe,
`transactions/0095.md` (read 2026-10-15T03:25:55Z from
https://raw.githubusercontent.com/bsv-blockchain/BRCs/5333fd449c70fd5982029876376dcf1ed9c64ffe/transactions/0095.md,
6801 bytes, sha256 `e5ceb51ecbfd9b3715227e65891503908e485eb09d1a0bfd8060d99b2e13026e`).
Views, never rules.

The layout (0095.md:27-38, :73-79): the prefix `0x01010101` (4 bytes, :31),
the subject's txid (32 bytes, :32), then a BEEF of BRC-62 (`0100beef ...`, :78;
this codec also takes BRC-96's version 2, as the three engines do). The two
error conditions (:65-71), a missing subject and an unrelated transaction, are
validation, not grammar: the codec reads every prefix, word and BEEF, and the
view `AtomicBeef.scoped` decides the two conditions. A second prefix inside is
refused by the grammar: the inner bytes must begin with a BEEF version word.

## `BsvChain.Views.Wire.AtomicBEEF` (`lean/BsvChain/Views/Wire/AtomicBEEF.lean`)

## The function to the machine's objects

## `BsvChain.Views.Wire.BEEF` (`lean/BsvChain/Views/Wire/BEEF.lean`)

# The Background Evaluation Extended Format (BEEF, BRC-62 and BRC-96) as a view (#86)

[M] 2026-10-15 (#86). [LIT] BRC-62 "Background Evaluation Extended
Format (BEEF) Transactions", bsv-blockchain/BRCs at
5333fd449c70fd5982029876376dcf1ed9c64ffe, `transactions/0062.md` (read
2026-10-15T03:25:54Z from
https://raw.githubusercontent.com/bsv-blockchain/BRCs/5333fd449c70fd5982029876376dcf1ed9c64ffe/transactions/0062.md,
15674 bytes, sha256 `7fdee54fa863a3787143ba86a076e1b790d9d9d0584059aa156214fea828a313`),
and BRC-96 "BEEF V2, Txid Only Extension", `transactions/0096.md` at the same
commit (read 2026-10-15T03:27:47Z from
https://raw.githubusercontent.com/bsv-blockchain/BRCs/5333fd449c70fd5982029876376dcf1ed9c64ffe/transactions/0096.md,
4635 bytes, sha256 `9b4b11fdb28c5ec66332cb3260716f82d61318e9dc376aba730fef903a577283`).
Views, never rules: a BEEF carries transactions with their ancestry and the
merkle paths (BUMPs) of the mined ones; its validation process (0062.md:172-191)
is a client's, and nothing here changes a verdict of the machine.

**Version 1** (0062.md:59-69): the version 4022206465 as 4 little-endian bytes
(`0100BEEF`), the BUMP count (VarInt) and the BUMPs (BRC-74), the transaction
count (VarInt), then per transaction the raw transaction (BRC-12), the
"Has BUMP" byte (`01` or `00`, :68) and, after `01`, the BUMP index (VarInt, :69).
**Version 2** (0096.md:46-61): the version 4022206466 (`0200BEEF`), the same
BUMP section, then per transaction the "Tx Data Format" byte, ahead of the body
(:48-50): `00` a raw transaction without a BUMP index, `01` the BUMP index
(VarInt) then the raw transaction, `02` a 32-byte txid only (:58-61).
This codec reads exactly the byte values the two tables name and refuses
every other; it does not check that a BUMP index is in range (the grammar has
no such field); the view `Beef.objects` does, and returns `none` when a
mined transaction's BUMP is missing or does not list its txid.

## `BsvChain.Views.Wire.BEEF` (`lean/BsvChain/Views/Wire/BEEF.lean`)

## Well-formedness and the round trips

## `BsvChain.Views.Wire.BEEF` (`lean/BsvChain/Views/Wire/BEEF.lean`)

## The function to the machine's objects: a transaction with its ancestry

## `BsvChain.Views.Wire.BUMP` (`lean/BsvChain/Views/Wire/BUMP.lean`)

# The BSV Unified Merkle Path (BUMP, BRC-74) as a view (#86)

[M] 2026-10-15 (#86). [LIT] BRC-74 "BSV Unified Merkle Path (BUMP)
Format", bsv-blockchain/BRCs at 5333fd449c70fd5982029876376dcf1ed9c64ffe,
`transactions/0074.md` (read 2026-10-15T03:25:54Z from
https://raw.githubusercontent.com/bsv-blockchain/BRCs/5333fd449c70fd5982029876376dcf1ed9c64ffe/transactions/0074.md,
18597 bytes, sha256 `0cd56c0f9e6b31a2500899b1791abcf15b216cb4aeb7576608b3cc19942d6aad`).
Views, never rules: a BUMP is a client encoding of one or more merkle paths
of #65 in one block; its verification is `verifyPath` of #65 through the
node list of #75 (`markerPath`, `tscPath`).

The layout (0074.md:45-77): the block height (VarInt, :50), the tree height
(1 byte, "max 64", :51), then per level the leaf count (VarInt, :58) and the
leaves; a leaf is the offset (VarInt, :66), the flags byte (:67) and a
32-byte hash unless the flags say duplicate (:68). The flags table (:73-77):
`00` data follows, not a client txid; `01` nothing follows, duplicate the
working hash; `02` data follows, a client txid. This codec reads exactly the
three values of the table and refuses every other flags byte; the reference
JavaScript of the BRC (:289-296) and the three engines read the flags as bits
(`flags & 1` duplicate, else `flags & 2` client), so `04` and above are read
by them and refused here (the conformance record's `bump-028`); `03`, the
duplicate bit with the client bit, they read as a duplicate (`bump-027`).
A tree height above 64 is refused (:51). Hashes are internal-order words; the
JSON form (:158-261) and the hex display order are the reversed words.

**The projection.** A path for the leaf at offset `index` takes, at each level
`h` below the tree height, the leaf at the sibling offset of `index / 2^h`
(:326-345, `calculateMerkleRootFromBUMP`); a duplicate is the marker of #75.
A leaf the BUMP omits is computed from the level below when both children are
present (the engines' reading: @bsv/sdk 3.0.0 `MerklePath.ts:421` (`findOrComputeLeaf`),
the text "only include branches of the tree which are required", :15); the
BRC's reference function throws instead (:335). A one-level BUMP of one leaf is
the lone transaction of its block, whose root is the leaf itself (@bsv/sdk
3.0.0 `MerklePath.ts:390` ("special case for blocks with only one
transaction"); ts-stack 4d0ea63c, identical at edf6e03d); #75 records that the
node serves no proof for that case.

## `BsvChain.Views.Wire.BUMP` (`lean/BsvChain/Views/Wire/BUMP.lean`)

## Well-formedness and the round trips

## `BsvChain.Views.Wire.BUMP` (`lean/BsvChain/Views/Wire/BUMP.lean`)

## The function to #65's merkle paths

## `BsvChain.Views.Wire.BUMP` (`lean/BsvChain/Views/Wire/BUMP.lean`)

## A #75 proof as a BUMP

## `BsvChain.Views.Wire.Bytes` (`lean/BsvChain/Views/Wire/Bytes.lean`)

# Client wire formats as views: the shared byte layer (#86)

[M] 2026-10-15 (#86). The five wire views (`EF`, `BUMP`, `BEEF`,
`AtomicBEEF`, `TSC`) are client encodings. They are views, never rules: no
consensus or policy rule of the node reads any of them, and nothing here
changes a verdict of the machine. Each view has a codec, two round trips and a
function to the machine's objects (a transaction, its spent outputs, its
ancestry, a merkle path of #65).

This module holds the reverse direction of the readers the views share:
"serialize after parse is the identity on byte-valued input". #68 G4
(`decodeTxPrefix_serTx`) proved the forward direction (parse after
serialize); the lemmas below prove the other one for `readBytes`, `readLE`,
`readVarInt`, `readMany`, the input and output readers and the transaction
prefix decoder. The CompactSize reader refuses non-canonical encodings
([SRC] src/serialize.h:315-335 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b),
which is what makes this direction an identity: one value has one encoding.
Every BRC of the views says "VarInt" for its counts and lengths; this spec
reads that as the node's CompactSize, canonical form included [D], and records
an engine that accepts a non-canonical form as a divergence with its witness.

## `BsvChain.Views.Wire.Bytes` (`lean/BsvChain/Views/Wire/Bytes.lean`)

## Fixed tags

## `BsvChain.Views.Wire.EF` (`lean/BsvChain/Views/Wire/EF.lean`)

# The Extended Format (EF, BRC-30) as a view (#86)

[M] 2026-10-15 (#86). [LIT] BRC-30 "Transaction Extended Format (EF)",
bsv-blockchain/BRCs at 5333fd449c70fd5982029876376dcf1ed9c64ffe,
`transactions/0030.md` (read 2026-10-15T03:25:54Z from
https://raw.githubusercontent.com/bsv-blockchain/BRCs/5333fd449c70fd5982029876376dcf1ed9c64ffe/transactions/0030.md,
9663 bytes, sha256 `395fa0566fcae8e2c5478a03b8a500034553fbce634f48c6df114c8c828dab44`).
Views, never rules: EF is a client encoding of a transaction with the outputs
its inputs spend; no node rule reads it.

The layout (0030.md:36-44, :60-69): the version (4 bytes), the marker
`0000000000EF` (6 bytes, :39), the input count (VarInt), the extended inputs,
the output count (VarInt), the outputs, the lock time (4 bytes). An extended
input (:60-69) is the plain input (previous hash 32 bytes, previous index 4,
script length VarInt, script, sequence 4) followed by the spent output's value
and its locking script (length VarInt, then the script).

**The value width: the text and the engines disagree.** The table at
0030.md:67 gives "Previous TX satoshi output ... 4 bytes". Every engine read
for this view writes and reads 8 bytes, the width of `CTxOut::nValue`
([SRC] src/primitives/transaction.h:175-194 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b):
bsv-rs 0.5.0 `src/transaction/transaction.rs:261` (`read_u64_le`), go-sdk
v1.7.2 `transaction/input.go:125-131`, @bsv/sdk 3.0.0
`packages/sdk/src/transaction/Transaction.ts:388`. The codec below
reads 8 bytes, the named parameter `efValueWidth`, and the record carries the
text's 4 as a documentation divergence; the mainnet-derived corpus is
written by the engines' width. [D]

The marker is chosen so that a reader of the plain format sees a transaction
with no inputs, no outputs and a lock time, and stops before the rest
(0030.md:46, :73); `ef_legacy_reading` below states what the machine's own
decoder reads from an EF stream.

## `BsvChain.Views.Wire.EF` (`lean/BsvChain/Views/Wire/EF.lean`)

## The function to the machine's objects

## `BsvChain.Views.Wire.EF` (`lean/BsvChain/Views/Wire/EF.lean`)

## Well-formedness and the round trips

## `BsvChain.Views.Wire.TSC` (`lean/BsvChain/Views/Wire/TSC.lean`)

# The TSC merkle proof as a wire view (#86)

[M] 2026-10-15 (#86). The binary codec of the TSC "Merkle Proof
Standardised Format" is #75's (`BsvChain.Views.MerkleProof`, the [LIT]
citation of the standard there: retrieved 2026-10-13T23:44:03Z, sha256
`438f2ffb08a225769761934c40479ea7aa0e893e74eae780d7619b5c58c916e7`), and #75
proved parse after serialize (`tsc_decodePrefix_encode`). This module adds
the other direction, serialize after parse on byte-valued input, and the
function to a BUMP of BRC-74, so the five wire views share one projection to
#65's `(leaf, path, index, root)`. Views, never rules.

## `BsvChain.Views.Wire.TSC` (`lean/BsvChain/Views/Wire/TSC.lean`)

## The function to a BUMP and to #65's path

## `BsvChain.Wire.CompactBlocks` (`lean/BsvChain/Wire/CompactBlocks.lean`)

# Compact blocks (#79), 2026-10-15 [D]

Nothing in this module is a block-validity rule. A compact block is a relay
encoding: it decides how a node receives a block it may already partly hold,
never whether the block is valid. The reconstruction ends in the reference's
`CheckBlock` (#63's `checkBlock`), which is the validity judge here as
everywhere; the settings the procedure reads are the auxiliary
`CompactConfig` below (docs/PARAMETERS.md section 8.11), each policy with its
default and source (rule 1).

The short id: SipHash-2-4 of the transaction id, keyed by the leading two
little-endian 64-bit words of the single SHA-256 of the header followed by
the message's 64-bit nonce, cut to its low 48 bits. The message
(`cmpctblock`): the header, the nonce, the short ids (six bytes each) and the
prefilled transactions (a differentially encoded index and the transaction).
The receiver places the prefilled transactions, maps each short id to the
next empty position, fills what its pool and its extra transactions match,
and asks with `getblocktxn` for the positions still empty; `blocktxn` carries
them back and the block is filled and checked.

[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/blockencodings.h:36-141 (`BlockTransactionsRequest`, `BlockTransactions`,
`PrefilledTransaction`),:143-153 (`ReadStatus`),:155-225
(`CBlockHeaderAndShortTxIDs`),:227-248 (`PartiallyDownloadedBlock`);
src/blockencodings.cpp:18-32 (the sender's message),:65-82 (the keys and the
short id),:84-242 (`InitData`),:244-252 (`IsTxAvailable`),:254-316
(`FillBlock`); src/hash.cpp:104-121 (`SIPROUND`),:123-200 (`CSipHasher`),
:202-236 (`SipHashUint256`); src/uint256.h:118-125 (`GetUint64`);
src/net/net_processing.cpp:2428-2449 (`sendcmpct`),:3623-3700 (`blocktxn`),
:2734-2843 (`getblocktxn`),:3744-4030 (`cmpctblock`). BIP152
(the raw form, https://raw.githubusercontent.com/bitcoin/bips/master/bip-0152.mediawiki,
read 2026-10-15T16:01:41Z; `master` is mutable, the pin is the sha256
b710fa0a...cd85): lines 42 (the differential
encoding), 100-104 (the short id), 141-142 (the reconstruction and the
collisions).

## `BsvChain.Wire.CompactBlocks` (`lean/BsvChain/Wire/CompactBlocks.lean`)

## 1. SipHash-2-4

## `BsvChain.Wire.CompactBlocks` (`lean/BsvChain/Wire/CompactBlocks.lean`)

## 2. The short id

## `BsvChain.Wire.CompactBlocks` (`lean/BsvChain/Wire/CompactBlocks.lean`)

## 3. The messages

## `BsvChain.Wire.CompactBlocks` (`lean/BsvChain/Wire/CompactBlocks.lean`)

## 4. The settings

## `BsvChain.Wire.CompactBlocks` (`lean/BsvChain/Wire/CompactBlocks.lean`)

## 5. The reconstruction

## `BsvChain.Wire.DoubleSpend` (`lean/BsvChain/Wire/DoubleSpend.lean`)

# Double-spend notifications (#80), 2026-10-15 [D]

**A notification is never a verdict.** Nothing in this module decides whether
a transaction or a block is valid. The reference's double-spend notifications
are node behavior with operator settings: a node that refuses a conflicting
transaction may tell the endpoint the original transaction declared in its
notification output (the attempt handler), and a node that receives a peer's
`dsdetected` message about blocks carrying a double spend checks it, relays it
and posts it to its own webhook. Every delay, size and count here is a policy
setting with its default and source (`DSConfig`; docs/PARAMETERS.md section
8.12), or a constant of the handler, named as such (rule 1). The refusal of
the double spend itself is #62's mempool machine (`BsvChain.Mempool`); this
module reads that machine's outcomes, it never re-decides them.

The parts: the reference's VARINT (the callback message's integer encoding,
not CompactSize); the notification output and the callback message it carries;
the detector's events as a view of #62's admission (`acceptDetect`, which is
`acceptWithTrace` with the detection read off the stopping stage); the attempt
handler (`DSAttemptHandler`): its queue, its notification choice, its script
check, its delivery to each endpoint (the query, the proof, the retries, the
fast and slow queues) and its time-limited blacklist; the `dsdetected` message
(its codec, its checks) and the node's handling of it (the duplicate cache, the
relay, the webhook post). #84's event vocabulary (`BsvChain.Views.Events`)
already names the publication the handler hangs on: the invalid-transaction
record of a completed refusal (`invalidEvent`, `acceptEvents`) whose
`collidedWith` field (`invalidFieldsOutsideMachine`) is the detector's set read
here; that vocabulary is cited, never repeated.

[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/double_spend/dsattempt_handler.h:34-204, src/double_spend/dsattempt_handler.cpp:18-777,
src/double_spend/dscallback_msg.h:20-163, src/double_spend/dscallback_msg.cpp:94-130,
src/double_spend/dsdetected_message.h:20-142, src/double_spend/dsdetected_message.cpp:79-380,
src/double_spend/dsdetected_defaults.h:12-17, src/double_spend/time_limited_blacklist.h:20-114,
src/double_spend/dstxn_serialiser.cpp:86-106, src/limitedmap.h:14-50, src/limited_cache.h:9-40,
src/merkleproof.h:22-185, src/merkleproof.cpp:30-72, src/script/script.cpp:174-179,
src/script/script.h:104-133, src/primitives/transaction.cpp:134-147, src/serialize.h:342-427,
src/txmempool.cpp:2257-2281, src/txn_double_spend_detector.cpp:11-58,111-138,
src/validation.cpp:1142-1153,1478-1494,1733-1757,1786-1806, src/net/net.cpp:2653-2659,
src/net/net_processing.cpp:4452-4518,4570-4684,4826-4827, src/rpc/client_config.h:24-26,
src/rpc/client_config.cpp:87-159, src/rpc/http_request.cpp:28-53, src/rpc/http_request.h:76-103,
src/rpc/client.cpp:184-200, src/rpc/webhook_client.cpp:13,28-73, src/config.cpp:1702-1931,1985-2049,
src/init.cpp:1575-1645,2956-3027.

## `BsvChain.Wire.DoubleSpend` (`lean/BsvChain/Wire/DoubleSpend.lean`)

## 1. The reference's VARINT

## `BsvChain.Wire.DoubleSpend` (`lean/BsvChain/Wire/DoubleSpend.lean`)

## 2. The notification output and the callback message

## `BsvChain.Wire.DoubleSpend` (`lean/BsvChain/Wire/DoubleSpend.lean`)

## 3. The detector's events, a view of #62's admission

## `BsvChain.Wire.DoubleSpend` (`lean/BsvChain/Wire/DoubleSpend.lean`)

## 4. The handler's settings

## `BsvChain.Wire.DoubleSpend` (`lean/BsvChain/Wire/DoubleSpend.lean`)

## 5. The time-limited blacklist

## `BsvChain.Wire.DoubleSpend` (`lean/BsvChain/Wire/DoubleSpend.lean`)

## 6. The attempt handler

## `BsvChain.Wire.DoubleSpend` (`lean/BsvChain/Wire/DoubleSpend.lean`)

## 7. The `dsdetected` message

## `BsvChain.Wire.DoubleSpend` (`lean/BsvChain/Wire/DoubleSpend.lean`)

## 8. The `dsdetected` checks

## `BsvChain.Wire.DoubleSpend` (`lean/BsvChain/Wire/DoubleSpend.lean`)

## 9. The node's handling of `dsdetected`

## `BsvChain.Wire.DoubleSpend` (`lean/BsvChain/Wire/DoubleSpend.lean`)

### The webhook's JSON

## `BsvChain.Wire.P2P` (`lean/BsvChain/Wire/P2P.lean`)

# The P2P wire formats (#78), 2026-10-15 [D]

Nothing in this module is a block-validity rule. The P2P layer decides what a
node hears and when, never whether a transaction or a block is valid: every
payload cap here is a node setting or a constant of the message reader, and
the reject codes are a vocabulary the node answers with, never a verdict of
its own. The settings are the fields of the auxiliary `RelayConfig`
(`lean/BsvChain/Wire/Relay.lean`; docs/PARAMETERS.md section 8.6), each
labeled policy with its default and source (rule 1).

The frame: a 24-byte header (four bytes of network magic, a twelve-byte
NUL-padded command, a 32-bit little-endian payload length, the leading four
bytes of the payload's double SHA-256), or for a payload above 2^32 - 1 bytes
the 44-byte extended header: the command `extmsg`, the length field
0xffffffff, a zero checksum, then the real command (twelve bytes) and a 64-bit
length; the payload follows. The reader recognizes the extended form by the
basic command's six-byte prefix `extmsg` and skips the checksum for it.

[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/protocol.h:28-63 (the caps),:68-86 (the field sizes),:93-119 (the extended
header),:131-191 (the header),:525-593 (`CInv`),:596-626 (`CProtoconf`);
src/protocol.cpp:15-53 (the command names),:55-99 (`IsBlockLike`,
`GetMaxMessageLength`),:107-121 (the registered list),:128-152
(`CheckCommandFormat`),:154-365 (the header's constructor, reader, accessors
and validity); src/net/net_message.cpp:12-53 (the frame reader);
src/net/net_processing.cpp:5029-5090 (magic and checksum at processing);
src/consensus/validation.h:13-24, src/validation.h:1150-1163 and
src/net/net_types.h:26, src/net/authconn.h:25 (the reject codes);
src/serialize.h:296-340,429,497-520,698-726 (the integer, CompactSize and
string encodings); src/chainparams.cpp:1087-1090,1504-1507 (the magics).

## `BsvChain.Wire.P2P` (`lean/BsvChain/Wire/P2P.lean`)

## 1. The header's fields

## `BsvChain.Wire.P2P` (`lean/BsvChain/Wire/P2P.lean`)

## 2. The message vocabulary

## `BsvChain.Wire.P2P` (`lean/BsvChain/Wire/P2P.lean`)

## 3. The command field

## `BsvChain.Wire.P2P` (`lean/BsvChain/Wire/P2P.lean`)

## 4. The header

## `BsvChain.Wire.P2P` (`lean/BsvChain/Wire/P2P.lean`)

## 5. The frame

## `BsvChain.Wire.P2P` (`lean/BsvChain/Wire/P2P.lean`)

## 6. The payload caps

## `BsvChain.Wire.P2P` (`lean/BsvChain/Wire/P2P.lean`)

## 7. The payloads

## `BsvChain.Wire.Relay` (`lean/BsvChain/Wire/Relay.lean`)

# The relay machine (#78), 2026-10-15 [D]

The per-peer state and the transitions of the reference's P2P layer for
transactions: what is announced, to whom and when, what is requested and
held in flight, what is answered with `reject`, how a missing parent is
fetched, how misbehavior is scored and a ban reached, and how the initial
block download gates requests. Nothing here is a block-validity rule: the
validity of a transaction is the mempool machine's answer (#62,
`lean/BsvChain/Mempool.lean`), an explicit input (`Verdict`) of the receive
transition; this layer decides what a node hears and when. Every setting is
a field of `RelayConfig`, labeled policy with its default and source
(docs/PARAMETERS.md section 8.6; rule 1).

Time is abstracted. The node announces on a timer (the propagator's period,
`-txnpropagationfreq`; the trickle delay, `-broadcastdelay`) and requests on
a timer (`TXN_REREQUEST_INTERVAL`); here the propagator's pass (`propagate`),
a peer's inventory flush (`flush`) and a peer's request pass (`request`) are
explicit transitions, taken by a run in the order its observation fixes
(the harness waits past each delay before it observes, docs/records of the
run). Block announcements and the header sync are #79's (compact blocks) and
the chain layer's; a block item in an `inv` is read here only for its type.

A view of the relay layer, never a rule of validity.

[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/net/net_processing.cpp:610-634 (`Misbehaving`),:930-961 (`IsTxnKnown`),
:975-997 (`RelayTransaction`),:1392-1430,1468-1479 (`getdata` for a
transaction, `notfound`),:2454-2532 (`inv`),:3351-3408 (`tx`),:4890-4921 (the
ban's consumption),:5029-5041 (the bad magic),:5536-5570,5572-5674 (the
inventory flush),:5782-5843 (the request pass); src/net/net.cpp:535-580
(`Ban`),:836-878 (`AddTxnsToInventory`),:907-928 (`FetchNInventory`),
:3269-3318 (`AskFor`),:3401-3406 (the stream moved across addresses),
:3574-3582 (`EnqueueTransaction`); src/net/net_message.cpp:22-26 and
src/net/association.cpp:396-401 (the oversized header);
src/validation.cpp:1873-1932 (the orphan's parents),:1934-1952 (the reject
message),:2030-2095 (an invalid transaction),:2097-2137 (an accepted one);
src/txn_propagator.cpp:56-61,136-175; src/rpc/net.cpp:745-746 (`setban`);
src/rpc/rawtransaction.cpp:1682 (`sendrawtransaction`'s enqueue).

## `BsvChain.Wire.Relay` (`lean/BsvChain/Wire/Relay.lean`)

## 1. The settings

## `BsvChain.Wire.Relay` (`lean/BsvChain/Wire/Relay.lean`)

## 2. The per-peer state

## `BsvChain.Wire.Relay` (`lean/BsvChain/Wire/Relay.lean`)

## 3. The transitions

## `BsvScript.Crypto.Secp256k1` (`lean/BsvScript/Crypto/Secp256k1.lean`)

# BsvScript.Crypto.Secp256k1

The curve and the ECDSA equation, executable (#11; `docs/DESIGN.md` §4.1). The
reference verifies through libsecp256k1 (`src/secp256k1`, vendored at the pin):
point decoding `secp256k1_eckey_pubkey_parse` (`eckey_impl.h:17–35`; the
cofactor is 1, `secp256k1_ge_is_in_correct_subgroup` is the identity outside
exhaustive tests, `group_impl.h:893–915`, its non-exhaustive branch `908–914`), the compact parse with its overflow
rule (`secp256k1.c:397–416`: `r` or `s` at or above `n` is an overflow), the
normalization of `s` (`secp256k1.c:443–460`: a high `s` is replaced by `n − s`),
and the equation `secp256k1_ecdsa_sig_verify` (`ecdsa_impl.h:195–262`):
`r ≠ 0 ∧ s ≠ 0`; `u₁ = z·s⁻¹`, `u₂ = r·s⁻¹` mod `n`; `R = u₁·G + u₂·Q ≠ O`; then
`R.x = r` or (`r + n < p` and `R.x = r + n`), that is `R.x mod n = r` since
`2n > p` (`228–261`). `secp256k1_ecdsa_verify` (`secp256k1.c:462–476`) also
requires a low `s`, which holds after the normalization the reference applies
first (`pubkey.cpp:207–213`).

The field is `F_p` on `Nat` with `p = 2²⁵⁶ − 2³² − 977`; the points are
Jacobian triples with the point at infinity as `none`; the scalar
multiplication is double-and-add over the 256 bits. Every function is a
definition: the spec carries no axiom for the curve (Q9, ruled (A) by the maintainers
on archived #38, 2026-09-22; `docs/HYPOTHESES.md` keeps both readings).

What is transcribed with its lines, and what is not: the point decoding, the lax
DER parser, the normalization of `s` and the equation follow the reference's code
with its lines. The field and group arithmetic computes the same values by other
means and is NOT a line-by-line transcription: the inverses by Fermat (`invN`, the
scalar inverse, for the reference's `secp256k1_scalar_inverse_var`, `ecdsa_impl.h:208`;
`invP`, the field inverse in `toAffine`, has no counterpart on the reference's
verification path, which compares `R.x` in Jacobian coordinates to avoid the inversion,
`ecdsa_impl.h:233–248`, the equivalence above), the square
root by `powMod` to `(p + 1) / 4` (the reference reaches the same exponent by an
addition chain, `field_impl.h:33–142`), the doubling by the textbook formula for
`a = 0` (a different Jacobian representative of the same point than
`secp256k1_gej_double`'s, `group_impl.h:429–462`), the scalar multiplication by
double-and-add (the reference's `secp256k1_ecmult`, `ecdsa_impl.h:212`). The
addition follows `secp256k1_gej_add_var` (`group_impl.h:495–557`). The evidence
that the values agree is the tests (`lean/Test/CryptoCheck.lean`).

## `BsvScript.Eval` (`lean/BsvScript/Eval.lean`)

# BsvScript.Eval

The evaluator: the machine with every family hook assembled (`docs/DESIGN.md`
§5.4, `eval : EvalParams → Context → ScriptSig → ScriptPubKey → Verdict`). At #8
no family was written yet, the hook empty and every non-flow opcode
`unimplemented`; #9, #10, #11 and #18 added theirs here, and `opExec` now
assembles all six (`Properties.Coverage`).

**The compiled evaluator (#50).** `verifyScript` below is the semantics and does not move. The compiler runs
`verifyScriptI` in its place (`@[csimp] verifyScript_eq_I`, at the end of this file): the same machine over an
array-backed stack (`BsvScript.Impl`), where the element `k` below the top is one index and the depth one read,
proven to give `verifyScript`'s verdict on every spend (`Impl.verifyScriptA_eq`, with `opExecI_refines`).

## `BsvScript.Eval` (`lean/BsvScript/Eval.lean`)

## The compiled evaluator (#50)

## `BsvScript.Flags` (`lean/BsvScript/Flags.lean`)

# BsvScript.Flags

The flags model (#13; `docs/DESIGN.md` §5.2–§5.4, `docs/PARAMETERS.md` §2–§3):
how the reference builds the flag word and the limits one input is verified
under, transcribed from the pin, and what the derivation proves.

* the protocol eras: `GetProtocolEra` (`src/protocol_era.cpp:21–39`) and
  `IsProtocolActive` (`89–103`);
* the flag sets: the mandatory sets (`src/script/standard.h:55–68`,
  `standard.cpp:330–337`), the standard set (`src/policy/policy.h:175–222`), the
  per-input set (`policy.h:225–244`);
* the block word by height (`src/verify_script_flags.cpp:32–81`) and the mempool
  word (`11–30`);
* where the reference calls them: `CheckInputScripts` (`src/validation.cpp:2676–2710`:
  the era of the spend height, the UTXO's era from the coin's height, the union of
  the caller's word and the per-input word at `2697–2702`); the block path
  (`3473` → `GetBlockScriptFlags(config, tip)` `2973–2982`: the height is the tip's
  = the block's height − 1, the era is that of `tip + 1` = the block's height);
  the mempool path (`1032`: the era of `tip + 1`; `1329` → `GetScriptVerifyFlags(config, era)`
  `796–802`; the spend height is `tip + 1`, `2858` with `2545–2549`); Teranode's engine
  does the same in BDK `core/txvalidator.cpp:659–681` (`CalculateFlags`: consensus mode
  = the block flags at `blockHeight − 1` with the era of `blockHeight`; policy mode =
  the mempool flags with the era of `blockHeight + 1`, `blockHeight` being the tip);
* the limits: `make_verify_script_params` (`src/script/interpreter.cpp:2282–2302`) over
  the getters (`src/configscriptpolicy.cpp:65–154`) and the setters' zero rules
  (`164–308`);
* `Params.derive` = all of the above (DESIGN §5.4, its signature frozen there); the
  version gate `enforceNonMalleability` (`Params.lean`, `interpreter.cpp:40–44`) is
  applied by the machine at its eight READ sites (seven `EnforceNonMalleability` calls
  plus the inlined `IsMalleableTxnVersion` read of SIGPUSHONLY at `2321–2334`; #19's
  Correction on #2) and is not part of the word;
* every flag as a `FlagBit` with its kind (`docs/PARAMETERS.md` §2), its gate site
  and its bit; the 32-bit word of `script_flags.h:13–115` both ways;
* the theorems: **P5** (parameter separation: block validation reads only the
  consensus fields of a node's configuration), the block word never carries a policy
  flag, the derived word is `valid_flags` on a node with no `-promiscuousmempoolflags`
  word (`flagWord_valid`'s hypothesis `hp`: such a word REPLACES the mempool word,
  `verify_script_flags.cpp:19–25`, and is read only where the chain's `RequireStandard()`
  is false, `validation.cpp:795–801`: stn, testnet and regtest, `chainparams.cpp:1271`,
  `:1416`, `:1527`, never mainnet, `:1121`; a promiscuous word can fail it), and the relay-versus-block
  difference for a version-2 spend post-Chronicle on mainnet is exactly
  `SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_NOPS` (the CLAUDE.md gotcha, for derived words).

Every `[SRC]` that names no other source is bitcoin-sv v1.2.3 at `6504a3af`
(`docs/PROVENANCE.md`); GoBDK's lines are its pin's (`4eab3acd`); a bare number is a
line of `src/script/interpreter.cpp`.

## `BsvScript.Flags` (`lean/BsvScript/Flags.lean`)

## The eras (`src/protocol_era.cpp`)

## `BsvScript.Flags` (`lean/BsvScript/Flags.lean`)

## The flag sets

## `BsvScript.Flags` (`lean/BsvScript/Flags.lean`)

## The limits (`make_verify_script_params`, `2282–2302`; `configscriptpolicy.cpp`)

## `BsvScript.Flags` (`lean/BsvScript/Flags.lean`)

## The derivation (`docs/DESIGN.md` §5.4)

## `BsvScript.Flags` (`lean/BsvScript/Flags.lean`)

## The named limit sets (`docs/PARAMETERS.md` §1, the columns)

## `BsvScript.Flags` (`lean/BsvScript/Flags.lean`)

## The mempool coin and Teranode's height convention (#20)

## `BsvScript.Flags` (`lean/BsvScript/Flags.lean`)

## Every flag: its bit, its kind, its gate (`docs/PARAMETERS.md` §2)

## `BsvScript.Flags` (`lean/BsvScript/Flags.lean`)

## The 32-bit word (`script_flags.h:13–115`)

## `BsvScript.Flags` (`lean/BsvScript/Flags.lean`)

## The theorems

## `BsvScript.Gadget` (`lean/BsvScript/Gadget.lean`)

# BsvScript.Gadget: the gadget-level API, "this script computes this spec" (#35, 35a)

`docs/DESIGN.md` §12.4. A layer-4 consumer (a sibling's emitted verifier) is a long script built
from gadgets; this module states one gadget's effect on the machine state and composes gadgets by
concatenation, over the spec's own loop (`Machine.loop`, `interpreter.cpp:388–1833`):

* `run exec env g tail st`: the loop over the fragment `g` followed by `tail`, without the
  end-of-script test (`1828–1830`); only `OP_CODESEPARATOR` reads `tail` (`1445–1448`);
* `loop_eq_run`: `Machine.loop` is `run` with an empty tail followed by the end test;
* `framed g`: every instruction of `g` parses inside `g`; `run_append`: a framed fragment followed
  by another runs as the first, then, at its end, the second;
* `Triple exec env P g Q` with `Triple.seq` and `Triple.conseq`: the statement a consumer proves
  per gadget, and its composition.

Written on 2026-09-29 as the companion of
`docs/records/20260929-014620-gadget-api-35-s2.md`, compiled against `main` there; applied to the
tree by S1 under its own tag (the file is S1's glob by `docs/OWNERS`; RULES-TREE (32)), unchanged but
for this paragraph and the `#print axioms` lines, which stand on `lean/AxiomCheck.lean`.

## `BsvScript.Gadget.HashLock` (`lean/BsvScript/Gadget/HashLock.lean`)

# A worked example of the gadget API: BIP 199's hash-lock (#35, 35a; `docs/DESIGN.md` §12.4)

BIP 199, the hashed time-locked contract (bitcoin/bips `bip-0199.mediawiki`, blob `74bf6d6b`, lines 26–27 and 34,
read 2026-09-29), locks the seller's branch with `[HASHOP] <digest> OP_EQUALVERIFY`, `[HASHOP]` being `OP_SHA256`
or `OP_HASH160`: the hash puzzle a contract compiler produces for a preimage. With `OP_SHA256` and a 32-byte digest
`h` the gadget is the 35 bytes `a8 20 <h> 88`. This module states and proves what it computes, at the gadget
level (`BsvScript.Gadget`), over the spec's evaluator `Eval.opExec`:

* `run_sha256`, `run_push32` and `run_equalverify_same`: each instruction's effect on the machine state, through
  `Gadget.run` over the loop's own step (`Machine.loop`);
* `sha256_triple`, `push32_triple` and `equalverify_triple`: the same three as `Gadget.Triple`s;
* `hashLock_triple`: the gadget's own triple, composed from the three by `Triple.seq` (the digest's equality
  carried across by `Triple.conseq`): on a stack whose top `x` hashes to `h` it runs to its end and leaves the
  stack below `x`, two opcodes charged, `x`'s memory given back.

The hypotheses are the gadget's preconditions at the reference: an executing branch with no non-top-level
`OP_RETURN` (`459`), the op count two under `maxOpsPerScript` (`466–467`), the memory counter 128 under
`maxStackMemoryUsage` (`limitedstack.h:163–173`), and a post-Genesis UTXO (the pre-Genesis limits, `455–456`
and `1800–1803`, stay out of the statement).

## `BsvScript.Hash.Ripemd160` (`lean/BsvScript/Hash/Ripemd160.lean`)

# BsvScript.Hash.Ripemd160

RIPEMD-160, executable, for `OP_RIPEMD160` and `OP_HASH160`
(`interpreter.cpp:1402–1443`; `CHash160` = RIPEMD-160 of SHA-256, `src/hash.h:59–84`).
Transcribed from the reference's `src/crypto/ripemd160.cpp`: the five functions
(`src/crypto/ripemd160.cpp:17–29`), the initial state (`Initialize`, `src/crypto/ripemd160.cpp:32–40`), the round `a = rol(a + f + x + k, r) + e;
c = rol(c, 10)` (`Round`, `src/crypto/ripemd160.cpp:46–50`), the constants of the ten round groups (`R11`…`R52`,
`src/crypto/ripemd160.cpp:52–92`), the message-word order and rotation amounts of the two lines (the 160 `R` calls of
`Transform`, `src/crypto/ripemd160.cpp:110–273`, extracted by `tools/ripemd_tables.py`), the final
combination (`src/crypto/ripemd160.cpp:276–281`), and the padding with a little-endian length
(`Finalize`, `src/crypto/ripemd160.cpp:335–350`).

## `BsvScript.Hash.Sha1` (`lean/BsvScript/Hash/Sha1.lean`)

# BsvScript.Hash.Sha1

SHA-1 (FIPS 180-4 §6.1), executable, for `OP_SHA1` (`interpreter.cpp:1402–1443`;
the reference's `src/crypto/sha1.cpp`: the round `:18–22`, the functions
`:24–31`, the constants `:45–48`, the transform `:51–150`, the padding as
SHA-256's with a big-endian length).

## `BsvScript.Hash.Sha256` (`lean/BsvScript/Hash/Sha256.lean`)

# BsvScript.Hash.Sha256

SHA-256 (FIPS 180-4 §6.2) as an executable Lean function on byte lists, the digest
of `OP_SHA256` (`CSHA256`, `interpreter.cpp:1426–1429`), and SHA-256d (`Hash`,
`src/hash.h:24` `CHash256`: SHA-256 applied twice), the digest of every signature
hash (`CHashWriter::GetHash`, `interpreter.cpp:2083`, `2109`) and of `OP_HASH256`
(`1435–1439`) (#11). The reference computes it with
`src/crypto/sha256.cpp`; this is the specification's own implementation,
cross-checked against bsv-rs on vectors (`Test/SighashCheck.lean`) and against
the FIPS examples, never trusted from a library (`docs/DESIGN.md` §4.1).

The arithmetic is on `UInt32` (wrapping addition, rotations, the bitwise
functions of §4.1.2); bytes are the `Bytes` of `Numbers` (naturals below 256).

## `BsvScript.Hash.Sha256` (`lean/BsvScript/Hash/Sha256.lean`)

## Widths

## `BsvScript.Impl.Arith` (`lean/BsvScript/Impl/Arith.lean`)

# BsvScript.Impl.Arith: the arithmetic family over the implementation state (lean #50, slice (c))

`Ops.Arith`'s unary family (`interpreter.cpp:1222–1275`), binary family (`1277–1378`) and `OP_WITHIN`
(`1380–1399`) restated over `Impl.IState`: the operand read, the values and the result write are the spec's own
functions (`readOperand`, `unaryValue`, `binaryValue`, `encode`) read through `Impl.Elem`'s (#143: an operand too
long to be a number is refused from its size), and only the stack is reached through `State.lean`'s helpers, so
the depth test is one read. Each `…I_abs` theorem proves the restated function
computes what the spec's computes on every state it stands for (#50's design, its comment 5884618665).

## `BsvScript.Impl.Bitwise` (`lean/BsvScript/Impl/Bitwise.lean`)

# BsvScript.Impl.Bitwise: the bitwise family over the implementation state (lean #50, slice (c))

`Ops.Bitwise`'s `OP_AND`/`OP_OR`/`OP_XOR` (`interpreter.cpp:1069–1106`), `OP_INVERT` (`1108–1119`),
`OP_LSHIFT`/`OP_RSHIFT` (`1121–1187`) and `OP_EQUAL`/`OP_EQUALVERIFY` (`1189–1217`) restated over
`Impl.IState`: the byte logic is the spec's own (`List.zipWith`, `rshift`, `lshift`) read through `Impl.Elem`'s
operations (#143: `OP_EQUAL` compares the packed arrays), and only the stack is reached through `State.lean`'s
helpers. Each `…I_abs` theorem proves the restated function computes what the
spec's computes on every state it stands for (#50's design, its comment 5884618665).

## `BsvScript.Impl.Crypto` (`lean/BsvScript/Impl/Crypto.lean`)

# BsvScript.Impl.Crypto: the crypto family over the implementation state (lean #50, slice (d))

`Ops.Crypto`'s hash opcodes (`interpreter.cpp:1402–1443`), `OP_CHECKSIG`/`OP_CHECKSIGVERIFY` (`1450–1508`) and
`OP_CHECKMULTISIG`/`OP_CHECKMULTISIGVERIFY` (`1510–1682`) restated over `Impl.IState`: the digests, the encoding
checks, the scriptCode's cleanup and the transaction checker are the spec's own functions, on the elements' bytes
(`Impl.Elem`, #143), and only the stack is reached through `State.lean`'s helpers, so the signature loop reads each
signature and key in one index and the arguments' pops are at the array's end. Each `…I_abs` theorem proves the
restated function computes what the spec's computes on every state it stands for (#50's design, its comment
5884618665).

## `BsvScript.Impl.Elem` (`lean/BsvScript/Impl/Elem.lean`)

# BsvScript.Impl.Elem: the implementation's stack element, a packed byte array (lean #143)

The implementation state (`Impl.IState`, #50) holds every stack element as an `Elem`, Lean's packed `ByteArray`:
one byte per byte, as the reference's `std::vector<uint8_t>` (`limitedstack.h:14`, `:30`), where the spec's `Bytes`
(`List Nat`) is a cons cell per byte (#142's record: a 2147483647-byte element some 30 GB resident on the 36 GB
box). `Elem.toBytes` reads an element as the spec's `Bytes`; every operation the implementation does to an element
is named here with its lemma to the list operation through `toBytes`, so nothing outside this file knows
`ByteArray`'s API and no op touches the representation twice. The spec's own `Bytes` stays `List Nat`, and every
theorem about the semantics stays about it.

## `BsvScript.Impl.Elem` (`lean/BsvScript/Impl/Elem.lean`)

## The two conversions

## `BsvScript.Impl.Elem` (`lean/BsvScript/Impl/Elem.lean`)

## The two conversions' compiled forms

`toBytes` and `ofBytes` are stated through `ByteArray.data` and `List.toByteArray`, the forms the lemmas read; at
run time `data` builds a boxed `Array UInt8` on the way to the list. The machine converts once per phase (the stack
handed from the unlocking phase to the locking phase, `Impl.evalScriptA`), a million times on #48's large lock, so
the compiler runs two loops instead (`@[csimp]`, proven equal; nothing in the semantics moves).

## `BsvScript.Impl.Elem` (`lean/BsvScript/Impl/Elem.lean`)

## Size, emptiness, equality

## `BsvScript.Impl.Elem` (`lean/BsvScript/Impl/Elem.lean`)

## Append, take, drop

## `BsvScript.Impl.Elem` (`lean/BsvScript/Impl/Elem.lean`)

## Elements built from short lists

## `BsvScript.Impl.Elem` (`lean/BsvScript/Impl/Elem.lean`)

## The number readers: the length bound read from the size, before any list is built

## `BsvScript.Impl.Elem` (`lean/BsvScript/Impl/Elem.lean`)

## `OP_NUM2BIN` and `OP_BIN2NUM`: the minimal encoding and the pad, built in place

## `BsvScript.Impl.Elem` (`lean/BsvScript/Impl/Elem.lean`)

## The bitwise family

## `BsvScript.Impl.Elem` (`lean/BsvScript/Impl/Elem.lean`)

## The hash inputs

## `BsvScript.Impl.Expansion` (`lean/BsvScript/Impl/Expansion.lean`)

# BsvScript.Impl.Expansion: the expansion family over the implementation state (lean #50, slice (c))

`Ops.Expansion`'s `OP_SUBSTR`, `OP_LEFT`, `OP_RIGHT`, `OP_LSHIFTNUM` and `OP_RSHIFTNUM` (`interpreter.cpp:609–764`)
restated over `Impl.IState`: the operand reads and the byte and number logic are the spec's own
(`readInt64Operand`, `Ops.Arith.readOperand`, `encode`) read through `Impl.Elem`'s operations (#143: the substrings
copied as packed bytes), and only the stack is reached through `State.lean`'s helpers. Each `…I_abs` theorem proves
the restated function answers what the spec's answers on every state it stands for (#50's design, its comment
5884618665).

## `BsvScript.Impl.Machine` (`lean/BsvScript/Impl/Machine.lean`)

# BsvScript.Impl.Machine: the loop and the two phases over the implementation state (lean #50, slice (e))

`Machine`'s flow opcodes (`interpreter.cpp:483–871`), its step (`473–482`, `1445–1448`), its loop (`EvalScript`,
`388–1833`) and its two-phase spend (`VerifyScript`, `2304–2451`) over `Impl.IState`, generic in the family hook as
`Machine` is. Each step says what the spec's step says (`execFlowI_eq`, `execStepI_eq`; read through `StepRI.view`
since #143, the elements packed), so the loop agrees with `Machine.loop` on the outcome always and on the state
when the outcome is `.ok` (`loopI_rel`): an in-place machine no longer holds a step's input once the step has run,
and `Machine.loop` returns that input with a failure (`(.err e, st)`), which no consumer reads (`evalScript`,
`phase2`, `verifyScript`). The two phases are written once, generic in the evaluator (`phase2Gen`,
`verifyScriptGen`), equal to `Machine.phase2` and `Machine.verifyScript` on `Machine.evalScript` by `rfl`, and
equal to each other on any two evaluators that agree on the outcome and on the state at `.ok`
(`verifyScriptGen_congr`) (#50's design, its comment 5884618665). Since #143 `verifyScriptA` runs them over a
`PhaseView` (`verifyScriptP`), the unlocking phase's packed array handed to the locking phase as it is.

## `BsvScript.Impl.Machine` (`lean/BsvScript/Impl/Machine.lean`)

## A step's result

## `BsvScript.Impl.Machine` (`lean/BsvScript/Impl/Machine.lean`)

## The leaves the step proofs close by `exact` against each definition's own `match`

## `BsvScript.Impl.Machine` (`lean/BsvScript/Impl/Machine.lean`)

## The flow opcodes (`483–871`)

## `BsvScript.Impl.Machine` (`lean/BsvScript/Impl/Machine.lean`)

## The step and the loop (`EvalScript`, `388–1833`)

## `BsvScript.Impl.Machine` (`lean/BsvScript/Impl/Machine.lean`)

## The two phases (`VerifyScript`, `2304–2451`), written once over the evaluator

## `BsvScript.Impl.Machine` (`lean/BsvScript/Impl/Machine.lean`)

## The two phases over a packed hand-off (#143)

`phase2Gen` and `verifyScriptGen` hand the unlocking phase's stack to the locking phase as the spec's `List Bytes`;
on the implementation that reads every element into a list and packs every list again (`evalScriptA`), the seed
corpus's extra 9 % [M] (#143's record). `phase2P` and `verifyScriptP` are the same text over a stack type `σ` and a
state type `S`, read through a `PhaseView`. On the spec's view they are `phase2Gen` and `verifyScriptGen`
(`phase2P_spec`, `verifyScriptP_spec`); on two views whose stacks agree element by element they give the same verdict
(`phase2P_congr`, `verifyScriptP_congr`); so the implementation hands its packed array on as it is (`verifyScriptA`).

## `BsvScript.Impl.Splice` (`lean/BsvScript/Impl/Splice.lean`)

# BsvScript.Impl.Splice: the splice family over the implementation state (lean #50, slice (c))

`Ops.Splice`'s `OP_CAT` (`interpreter.cpp:1687–1706`), `OP_SPLIT` (`1708–1736`), `OP_NUM2BIN` (`1741–1778`) and
`OP_BIN2NUM` (`1780–1792`) restated over `Impl.IState`: the byte and number logic is the spec's own (`num2bin`,
`minimallyEncode`, `isMinimallyEncoded`) read through `Impl.Elem`'s operations (#143: the concatenation and the
split copy packed bytes, `OP_NUM2BIN`'s pad is written in place, `Elem.num2binM`), and only the stack is reached
through `State.lean`'s helpers. Each `…I_abs` theorem proves the restated function computes what the spec's
computes on every state it stands for (#50's design, its comment 5884618665).

## `BsvScript.Impl.Stack` (`lean/BsvScript/Impl/Stack.lean`)

# BsvScript.Impl.Stack: the stack family over the implementation state (lean #50, slice (b))

`Ops.Stack.execStack` (`interpreter.cpp:876–1064`) restated over `Impl.IState`, instruction for instruction, the
element logic shared and the stack reached through `State.lean`'s helpers, so the element `k` below the top is
one index and the depth one read: `OP_PICK`/`OP_ROLL` no longer walk the stack (#50's design, its comment
5884618665). `execStackI_abs` proves it computes what `execStack` computes on every state it stands for.

## `BsvScript.Impl.Stack` (`lean/BsvScript/Impl/Stack.lean`)

## The family

## `BsvScript.Impl.State` (`lean/BsvScript/Impl/State.lean`)

# BsvScript.Impl.State: the implementation state of lean #50, slice (a)

The machine's state for the compiled evaluator, with the main stack as an array held bottom-first (the top at
`back`), as SV-node's `LimitedStack` holds its `std::vector` (`limitedstack.h:88`): the element `k` below the
top is one index (`stacktop(-(k+1))`, `limitedstack.cpp:226–233`), the depth is `size` (`307–310`), a push
and a pop are at the end. `IState.abs` reads an implementation state as the spec's `Machine.State` (the list
top-first); every helper below is proven to commute with `abs`, so a family written over them computes what
the spec's family computes (#50's design, its comment 5884618665). Nothing here is the semantics: the
definitions stay `Machine.State` and its functions, and every theorem about them stays about them. Since #143 every
element is an `Impl.Elem` (a packed `ByteArray`, `Impl/Elem.lean`), read as the spec's `Bytes` by `Elem.toBytes`.

## `BsvScript.Impl.State` (`lean/BsvScript/Impl/State.lean`)

## Three facts about a reversed list

## `BsvScript.Impl.State` (`lean/BsvScript/Impl/State.lean`)

## The implementation state and its abstraction

## `BsvScript.Impl.State` (`lean/BsvScript/Impl/State.lean`)

## The array's top, read as the top-first list

## `BsvScript.Impl.State` (`lean/BsvScript/Impl/State.lean`)

## The array helpers, each proven to commute with `abs`

## `BsvScript.Impl.State` (`lean/BsvScript/Impl/State.lean`)

## The state's helpers, each proven to commute with `abs` (the spec's `Machine` and `Ops.Stack` helpers)

## `BsvScript.Impl.State` (`lean/BsvScript/Impl/State.lean`)

## The helpers' lemmas in the form the family proofs rewrite with (the spec's call on the left)

## `BsvScript.Impl.State` (`lean/BsvScript/Impl/State.lean`)

## A family's result over the implementation state, and what a family refinement is

## `BsvScript.Machine` (`lean/BsvScript/Machine.lean`)

# BsvScript.Machine

The stack machine (#8; `docs/DESIGN.md` §1.3, §2): the instruction parser, the
state, the execution loop of `EvalScript` (`interpreter.cpp:388–1833`), the flow
opcodes and the pushes, and the two-phase spend of `VerifyScript`
(`2304–2451`). Every other opcode family reaches the loop through the hook
`OpExec` (#9 arithmetic and bitwise, #10 stack and splice, #11 crypto, #18 the
rest); an opcode no family has written yet is the `unimplemented` verdict, a
build-time state that #18 makes unreachable.

Bare line numbers are `src/script/interpreter.cpp` at the pin
(`docs/PROVENANCE.md`).

## `BsvScript.Machine` (`lean/BsvScript/Machine.lean`)

## The instruction parser (`CScript::GetOp2`, `script.h:165–200`)

## `BsvScript.Machine` (`lean/BsvScript/Machine.lean`)

## The conditional tracker (`conditional_tracker.h:12–26`, `.cpp:32–71`)

## `BsvScript.Machine` (`lean/BsvScript/Machine.lean`)

## The state, the context, the environment

## `BsvScript.Machine` (`lean/BsvScript/Machine.lean`)

## The flow opcodes

## `BsvScript.Machine` (`lean/BsvScript/Machine.lean`)

## The loop (`EvalScript`, `388–1833`)

## `BsvScript.Machine` (`lean/BsvScript/Machine.lean`)

## The two-phase spend (`VerifyScript`, `2304–2451`)

## `BsvScript.Machine` (`lean/BsvScript/Machine.lean`)

## The two phases (`VerifyScript`, `2304–2451`): the P2SH stack copy for a
pre-Genesis UTXO (`2354–2356`), the locking script on the resulting stack
(`2358–2372`), the final-stack rule (`2374–2378`), P2SH for a pre-Genesis UTXO
(`2380–2424`), CLEANSTACK (`2430–2448`).

## `BsvScript.Numbers` (`lean/BsvScript/Numbers.lean`)

# BsvScript.Numbers

Script numbers (#7): the little-endian sign-magnitude encoding, minimal encoding,
the acceptance rule, `OP_BIN2NUM` and `OP_NUM2BIN`, truthiness. Every definition
is transcribed from bitcoin-sv v1.2.3 at `6504a3af` (`docs/PROVENANCE.md`); the
theorems are the canonicality properties `docs/DESIGN.md` §1.2 names.

**The byte model.** A byte is a natural number below 256 (`Byte := Nat`, with
`Bytes.valid` where a lemma needs the bound). The reference's bit operations on
a byte reduce to arithmetic: "bit 7 set" is `128 ≤ b`, `b & 0x7f` is `b % 128`,
and `b | 0x80` on a byte below 128 is `b + 128`. The evaluator's boundary
converts `UInt8` to and from this model (a bijection on 0..255, #14).

**The number model.** The integers `ℤ`. The reference holds an `int64` or a
`bsv::bint` (`script_num.h:104`), the alternative chosen at construction by the
`big_int` argument (`script_num.cpp:72–90`), never by the magnitude, and never
promoted afterwards: the arithmetic operators assert that both operands hold the
same alternative (`+=`, `-=`, `*=` at `script_num.cpp:147`, `script_num.cpp:177`, `script_num.cpp:207`). Every arithmetic
opcode constructs with `big_int = utxo_after_genesis` (`interpreter.cpp:1235`,
`1300–1301`, `1386–1390`), so post-Genesis its values are unbounded integers and
the only bound is the encoded length (`MaxScriptNumLength`, `docs/PARAMETERS.md`
§1). The `int64` path (`big_int` false, the default, `script_num.h:60–63`) is
every number read of a pre-Genesis coin (length ≤ 4, or 5 for CLTV/CSV,
`interpreter.cpp:546`, `577`), `OP_CHECKMULTISIG`'s two counts in every era
(`1523–1526`, `1550–1553`, length ≤ 4) and, post-Chronicle, the
`OP_SUBSTR`/`OP_LEFT`/`OP_RIGHT` operands (`622`, `624`, `655`, `680`, at
`MaxScriptNumLength`). Its fixed-width overflow check
([SRC] `6504a3af`, `int_serialization.h:80–114`) is unreachable at a length
bound of at most 8 and reachable at the `OP_SUBSTR` family's reads (below).

## `BsvScript.Numbers` (`lean/BsvScript/Numbers.lean`)

## Encoding (`int_serialization.h:23–59`, `serialize`)

The top byte is where the sign lives, so the definitions work on the reversed
list (top byte first) and reverse back; a byte list `bs` and its reverse carry
the same information, and the property check runs the executable on the
forward lists.

## `BsvScript.Numbers` (`lean/BsvScript/Numbers.lean`)

## Decoding (`int_serialization.h:61–118`, `deserialize`)

## `BsvScript.Numbers` (`lean/BsvScript/Numbers.lean`)

## Minimality (`int_serialization.h:120–152`, `IsMinimallyEncoded`)

## `BsvScript.Numbers` (`lean/BsvScript/Numbers.lean`)

## `MinimallyEncode` (`int_serialization.h:154–208`)

## `BsvScript.Numbers` (`lean/BsvScript/Numbers.lean`)

## The acceptance rule (`script_num.cpp:53–91`, the byte constructor)

## `BsvScript.Numbers` (`lean/BsvScript/Numbers.lean`)

## Truthiness (`interpreter.cpp:119–130`, `CastToBool`)

## `BsvScript.Numbers` (`lean/BsvScript/Numbers.lean`)

## `OP_NUM2BIN` (`interpreter.cpp:1741–1779`)

## `BsvScript.Numbers` (`lean/BsvScript/Numbers.lean`)

## The fixed-width reader at v1.2.3

[SRC] bitcoin-sv v1.2.3, commit `6504a3af`, `int_serialization.h:61–118`:
empty reads zero; up to eight bytes use sign-magnitude; nine bytes require a
pure sign byte and a magnitude below 2^63, or exactly 2^63 with a negative sign;
longer operands return no value. `script_num.cpp:80–91` turns no value into
`scriptnum_overflow_error`, mapped by `interpreter.cpp:1807–1809` to
`SCRIPT_ERR_SCRIPTNUM_OVERFLOW`. This is a defined refusal.

The previous pin's reading is retained in a history module withheld from the
public edition at the maintainers' request (group `d8-node-team-discretion`).

## `BsvScript.Numbers` (`lean/BsvScript/Numbers.lean`)

## The theorems

## `BsvScript.Numbers` (`lean/BsvScript/Numbers.lean`)

## The owed theorems (T3, T4, T6, T7, T8)

## `BsvScript.Numbers` (`lean/BsvScript/Numbers.lean`)

### T7, `OP_NUM2BIN`

## `BsvScript.Numbers` (`lean/BsvScript/Numbers.lean`)

### T8, the `int64` reader

## `BsvScript.Opcodes` (`lean/BsvScript/Opcodes.lean`)

# BsvScript.Opcodes

The opcode table (`src/script/opcodes.h:13–160` at the pin, `docs/PROVENANCE.md`)
and the error vocabulary (`src/script/script_error.h:12–87`). The families'
semantics land in `BsvScript.Ops.*` (#9 arithmetic and bitwise, #10 stack and
splice, #11 crypto, #18 the rest) and are assembled in `BsvScript.Eval`; the
flow opcodes and the pushes are the machine's own (`BsvScript.Machine`, #8).
[LIT] https://protocol.bsvblockchain.org/specification/opcodes#how-to-read-this-page at v1.2.2 (the byte values only).

## `BsvScript.Ops.Arith` (`lean/BsvScript/Ops/Arith.lean`)

# BsvScript.Ops.Arith

The numeric opcodes (#9; `docs/DESIGN.md` §3): the unary family `OP_1ADD` …
`OP_0NOTEQUAL` (`interpreter.cpp:1222–1275`), the binary family `OP_ADD` …
`OP_MAX` (`1277–1378`) and `OP_WITHIN` (`1380–1399`), on the number type of
`BsvScript.Numbers` with the operand read and the result write of `CScriptNum`
(`src/script/script_num.cpp`, `src/big_int.cpp`). Bare line numbers are
`interpreter.cpp` at the pin (`docs/PROVENANCE.md`).

The arithmetic is exact integer arithmetic: post-Genesis the reference computes
on `bsv::bint` (OpenSSL `BIGNUM`; `big_int.cpp`), pre-Genesis on `int64_t`
with 4-byte operands, and both agree with `Int` where they are defined. Division
and modulus truncate toward zero with the remainder taking the dividend's sign
(`BN_div`/`BN_mod`, `big_int.cpp:238–262`; C++ `/`/`%` on `int64_t`): `Int.tdiv`
and `Int.tmod`.

## `BsvScript.Ops.Arith` (`lean/BsvScript/Ops/Arith.lean`)

## The error paths, pinned

## `BsvScript.Ops.Bitwise` (`lean/BsvScript/Ops/Bitwise.lean`)

# BsvScript.Ops.Bitwise

The bitwise opcodes on byte vectors (#9; `docs/DESIGN.md` §3): `OP_AND`/`OP_OR`/
`OP_XOR` (`interpreter.cpp:1069–1106`), `OP_INVERT` (`1108–1119`),
`OP_LSHIFT`/`OP_RSHIFT` (`1121–1187`, the helpers `52–117`), and the byte-vector
equality `OP_EQUAL`/`OP_EQUALVERIFY` (`1189–1217`). Bare line numbers are
`interpreter.cpp` at the pin (`docs/PROVENANCE.md`).

## `BsvScript.Ops.Bitwise` (`lean/BsvScript/Ops/Bitwise.lean`)

## Widths

## `BsvScript.Ops.Crypto` (`lean/BsvScript/Ops/Crypto.lean`)

# BsvScript.Ops.Crypto

The crypto family (#11; `docs/DESIGN.md` §4): the hash opcodes
(`interpreter.cpp:1402–1443`), `OP_CODESEPARATOR` (`1445–1448`, tracked by the
loop), `OP_CHECKSIG`/`OP_CHECKSIGVERIFY` (`1450–1508`) and
`OP_CHECKMULTISIG`/`OP_CHECKMULTISIGVERIFY` (`1510–1682`), with the encoding
checks `IsValidSignatureEncoding` (`177–245`), `CheckSignatureEncoding`
(`265–310`), `IsCompressedOrUncompressedPubKey` (`132–152`),
`IsCompressedPubKey` (`154–164`), `CheckPubKeyEncoding` (`312–329`), and the
transaction checker `TransactionSignatureChecker::CheckSig` (`2133–2164`) over
the sighash (`BsvScript.Sighash`) and the curve (`BsvScript.Crypto.Secp256k1`).
Bare line numbers are `interpreter.cpp` at the pin (`docs/PROVENANCE.md`).

The machine hands the transaction context in as `Context.checkSig`
(`docs/DESIGN.md` §5.4); `txCheckSig` below builds that function for a
transaction, an input and its amount.

## `BsvScript.Ops.Crypto` (`lean/BsvScript/Ops/Crypto.lean`)

## The encoding checks

## `BsvScript.Ops.Crypto` (`lean/BsvScript/Ops/Crypto.lean`)

## The transaction checker

## `BsvScript.Ops.Crypto` (`lean/BsvScript/Ops/Crypto.lean`)

## The opcodes

## `BsvScript.Ops.Expansion` (`lean/BsvScript/Ops/Expansion.lean`)

# BsvScript.Ops.Expansion

The expansion opcodes `OP_SUBSTR` `0xb3`, `OP_LEFT` `0xb4`, `OP_RIGHT` `0xb5`,
`OP_LSHIFTNUM` `0xb6`, `OP_RSHIFTNUM` `0xb7` (#18; `docs/DESIGN.md` §3,
`interpreter.cpp:609–764`). For a pre-Chronicle UTXO each is a NOP, or
`SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS` under the policy flag
(`IsDiscourageUpgradableNops`, `script_flags.h:137–140`); post-Chronicle they
execute. Bare line numbers are `interpreter.cpp` at the pin (`docs/PROVENANCE.md`).

[SRC] At v1.2.3 `6504a3af`, the `OP_SUBSTR` family selects the fixed-width
constructor (`interpreter.cpp:622–625`, `655–656`, `680–681`;
`script_num.h:60–63`). `Numbers.readNumInt64` checks width and minimality,
then the conversion (`int_serialization.h:61–118`, `script_num.cpp:53–91`).
No value is a defined `SCRIPT_ERR_SCRIPTNUM_OVERFLOW`
(`interpreter.cpp:1807–1809`). The previous pin's reading is retained in a history module withheld from the
public edition at the maintainers' request (group `d8-node-team-discretion`).
`OP_LSHIFTNUM`/`OP_RSHIFTNUM` read with `big_int = true` (`708–711`, `716–719`,
`744–747`, `752–755`): the ordinary number read.

## `BsvScript.Ops.Splice` (`lean/BsvScript/Ops/Splice.lean`)

# BsvScript.Ops.Splice

The splice and conversion opcodes (#10; `docs/DESIGN.md` §3): `OP_CAT`
(`interpreter.cpp:1687–1706`), `OP_SPLIT` (`1708–1736`), `OP_NUM2BIN`
(`1741–1778`), `OP_BIN2NUM` (`1780–1792`). Bare line numbers are
`interpreter.cpp` at the pin (`docs/PROVENANCE.md`).

[SRC] v1.2.3 `6504a3af`, `interpreter.cpp:1718–1721`: `OP_SPLIT`
refuses a position above `INT32_MAX` before `to_size_t_limited`.
The previous pin's reading is retained in a history module withheld from the
public edition at the maintainers' request (group `d8-node-team-discretion`).
The `OP_PICK`/`OP_ROLL` Q8 reading is separate and unchanged.

## `BsvScript.Ops.Stack` (`lean/BsvScript/Ops/Stack.lean`)

# BsvScript.Ops.Stack

The stack opcodes (#10; `docs/DESIGN.md` §3): `OP_TOALTSTACK` … `OP_TUCK`
(`interpreter.cpp:876–1055`) and `OP_SIZE` (`1057–1064`), on the `LimitedStack`
(`src/script/limitedstack.cpp`): a copy pushed costs its size plus the overhead
against the budget (`push_back`, `limitedstack.h:163–173`), an erased element
releases it (`erase`, `limitedstack.cpp:260–267`), a swap costs nothing
(`:285–288`), an insert costs like a push (`:269–283`), and a move between the
main stack and its child alt stack costs nothing (`moveTopToStack`, `:290–302`).
Bare line numbers are `interpreter.cpp` at the pin (`docs/PROVENANCE.md`).
The stack is held top-first (`State.stack`), so the element `k` below the top
is index `k`.

## `BsvScript.Ops.Stack` (`lean/BsvScript/Ops/Stack.lean`)

## Widths

## `BsvScript.Params` (`lean/BsvScript/Params.lean`)

# BsvScript.Params

The parameters record: every value the interpreter reads, by kind, with its
default and its `[SRC]` (`docs/PARAMETERS.md`, #6; the census is the source of
this file and the two are changed together).

Design (`docs/DESIGN.md` §5.4): the semantics takes `EvalParams` (the flag word,
the five limits); a second, cited function derives an `EvalParams` from a node's
configuration, the heights and the consensus switch (`Params.derive`,
`BsvScript.Flags`, #13),
mirroring the reference's split between `make_verify_script_params`
(`interpreter.cpp:2282–2302`) and the flag derivation
(`verify_script_flags.cpp:11–81`, `policy.h:208–244`).

Every `[SRC]` below is bitcoin-sv v1.2.3 at `6504a3af` (`docs/PROVENANCE.md`).

## `BsvScript.Properties.Basic` (`lean/BsvScript/Properties/Basic.lean`)

# BsvScript.Properties.Basic

The opening properties (#16; `docs/DESIGN.md` §9). Each theorem carries an
explainer (what it says, what it assumes, why it matters) and is listed in
`lean/AxiomCheck.lean`, so the tripwire's axiom check covers it.

**P1** canonicality and **P2** `castToBool` with the width lemma are T1–T6 of
`BsvScript.Numbers` (#7). **P5** parameter separation is `Flags.derive_consensus_separation`
(#13: on the block path `Params.derive` reads only a node's consensus fields) with its verdict-level
corollary `Flags.verifyScript_consensus_separation`. Determinism and termination are by construction (a total function;
`termination_by` on the remaining bytes, `Machine.loop`); `Eval.verifyScript_deterministic`
states the former.

## `BsvScript.Properties.Basic` (`lean/BsvScript/Properties/Basic.lean`)

## P3: gate non-interference

## `BsvScript.Properties.Basic` (`lean/BsvScript/Properties/Basic.lean`)

## P4: phase crossing

## `BsvScript.Properties.Basic` (`lean/BsvScript/Properties/Basic.lean`)

## The cheap and real ones

## `BsvScript.Properties.Coverage` (`lean/BsvScript/Properties/Coverage.lean`)

# BsvScript.Properties.Coverage

Every byte is defined (#18): for every opcode with a `case` label in the
reference's switch (`Op.hasCase`, `interpreter.cpp:483–1795`), some family hook
owns it or the flow dispatch handles it, so the loop never returns
`unimplemented` on a byte. The proof is a decision over the 256 bytes for the
ownership predicates, plus one lemma per family that its hook answers exactly
on the opcodes it owns.

## `BsvScript.Properties.Coverage` (`lean/BsvScript/Properties/Coverage.lean`)

## The capstone: the machine never answers `unimplemented` on a byte

`execFlow` (`483–1795`) handles the flow opcodes itself and hands every other
opcode to the hook; with the six families assembled the hook answers on every one
of those with a `case` label but `OP_CODESEPARATOR`, which no family owns, so
`execFlow` never answers `unimpl` off the separator (`execFlow_ne_unimpl`). The
loop (`388–1833`) hands `execFlow` a byte only off `OP_CODESEPARATOR` (`1445–1448`
is the loop's own, in `execStep`), so the loop never returns `unimplemented`.

## `BsvScript.Properties.Eras` (`lean/BsvScript/Properties/Eras.lean`)

# BsvScript.Properties.Eras

The activation rules as parameters (#20; `docs/DESIGN.md` §3, §5.2, §9 Q3;
`docs/PARAMETERS.md` §3, §6). The heights are parameters of `Params.derive`
(`ChainParams`, `NodeConfig.genesisActivationHeight`, `chronicleActivationHeight`,
`lean/BsvScript/Flags.lean`); this module states what the derivation and the
machine do with them, each theorem at its site of the reference:

* **the era selection** (`src/protocol_era.cpp:21–39`, `89–103`): the three cases as
  inequalities on the height, monotone in the height, the activation height being
  the first height of the new era (`consensus/params.h:33–36`);
* **the height conventions**: the block word is built at the tip's height with the
  era of the block being connected (`validation.cpp:2972–2981`, `validation.cpp:3472`), so the flags
  that test `height` (P2SH, UAHF, DAA) enter one block after their chain height and
  the flags that test `height + 1` (DERSIG, CLTV, CSV) enter at theirs
  (`verify_script_flags.cpp:39–69`); the era bits follow the spend height's era on
  both paths; the mempool word depends on the heights only through the eras; a
  mempool coin is the next block's (`validation.cpp:2667–2674`); Teranode's engine
  computes the same words (BDK `core/txvalidator.cpp:659–681`);
* **the UTXO's era** (Q3): the markers and the limits are the coin's, whatever the
  spend era: a pre-Genesis output spent post-Genesis or post-Chronicle runs under the
  pre-Genesis limits with the spending era's word (`411–427`, `2282–2302`);
* **the era rules per opcode**, as theorems on the machine: `OP_RETURN` (`856–871`),
  the 520-byte push (`455–456`), the disabled opcodes executed or not (`470–471`,
  `360–375`), `OP_VER` and `OP_VERIF`/`OP_VERNOTIF` (`598–608`, `773–781`), CLTV/CSV
  (`520`, `563`), the second `OP_ELSE` (`829–831`), the expansion opcodes
  (`611–618` … `730–736`);
* **the signature's hash type under the era flags** (#25, S2, 2026-09-26): the four
  refusals of `CheckSignatureEncoding` under STRICTENC (`291–306`) as theorems, each a
  rule on the signature's last byte under the word's bits; and **the checkers' reads of `nLockTime` and
  `nSequence`** (`2166–2250`, #22) as one predicate each, the verdicts CLTV and CSV
  give on a pre-Genesis coin.

Every `[SRC]` that names no other source is bitcoin-sv v1.2.2 at `879fc8b`
(`docs/PROVENANCE.md`); GoBDK's lines are its pin's (`4eab3acd`) and bsv-rs's carry
their release; a bare number is a line of `src/script/interpreter.cpp`.

## `BsvScript.Properties.Eras` (`lean/BsvScript/Properties/Eras.lean`)

## The era selection (`src/protocol_era.cpp`)

## `BsvScript.Properties.Eras` (`lean/BsvScript/Properties/Eras.lean`)

## The mempool coin (`validation.cpp:2667–2674`)

## `BsvScript.Properties.Eras` (`lean/BsvScript/Properties/Eras.lean`)

## Teranode's height convention (BDK `core/txvalidator.cpp:659–681`)

## `BsvScript.Properties.Eras` (`lean/BsvScript/Properties/Eras.lean`)

## The word by height: the tip's-height convention, flag by flag

## `BsvScript.Properties.Eras` (`lean/BsvScript/Properties/Eras.lean`)

## The derivation and the coin's era (Q3)

## `BsvScript.Properties.Eras` (`lean/BsvScript/Properties/Eras.lean`)

## The era rules per opcode (the machine)

## `BsvScript.Properties.Eras` (`lean/BsvScript/Properties/Eras.lean`)

## The signature's hash type under the era flags (`CheckSignatureEncoding`, `265–310`; #25)

STRICTENC is consensus by height (`uahfHeight`, `verify_script_flags.cpp:54–59`; `flagWord_block_strictEnc`),
FORKID enters with it (`flagWord_block_forkid`) and CHRONICLE is an era marker of the spend (`flagWord_chronicle`):
the four refusals of `291–306` are rules on the signature's last byte (`GetHashType`, `247–253`) under the word's
bits, each theorem conditional on those bits. No word the node derives has STRICTENC without FORKID, so the FORKID
refusal is reached only under an explicit word (`checkSignatureEncoding_illegalForkid`). Each theorem assumes
the two checks before the type's pass, as Bool equations in the code's own terms: the strict DER shape (`275–280`,
`Env.strictDer`) and the low-S rule under the version gate (`282–288`); an empty signature passes them all
(`272–273`, `Ops.Crypto.checkSignatureEncoding_empty`).

## `BsvScript.Properties.Eras` (`lean/BsvScript/Properties/Eras.lean`)

## `nLockTime` and `nSequence` as the checkers read them (`CheckLockTime` `2166–2202`,
`CheckSequence` `2204–2250`; #22, #25)

## `BsvScript.Properties.Eras` (`lean/BsvScript/Properties/Eras.lean`)

## `OP_CODESEPARATOR`'s slice, and the block word at the upgradable NOPs (#25, S2, 2026-09-27)

## `BsvScript.Properties.Hooks` (`lean/BsvScript/Properties/Hooks.lean`)

# BsvScript.Properties.Hooks

The discharge of the two hook hypotheses of `BsvScript.Properties.Resources` for every family's `exec`
(#25, 2026-09-27): `HookOpCount` (a family's answer from a state within
the op limit is within it) and `HookMem` (a family's answer keeps the memory counter exact) hold for
`Eval.opExec`, so the op-count invariant R2a and the accounting invariant R3b hold for the evaluator's
own loop with no hook hypothesis left (`loop_opCount_le_opExec`, `loop_memInv_opExec`). Each keeps its
start condition, the op count within the limit and the counter exact; the locking phase after an
unlocking script that left elements on its alt stack does not start exact (H5).

Every family moves only the two stacks and the counter, through the machine's primitives (`pushElem`,
`popElem`, `Ops.Stack.swapTop`, `eraseTop`, `insertTop`, `toAlt`, `fromAlt`), each of which leaves the op
count as it was and keeps the invariant (`Resources`, R3a): a family step is a `Frame`. The one family
step that charges the op count is the multisig's key count (`1534–1536`), refused above the limit
before anything else moves (`checkMultiSigOp_opCount`).

Bare line numbers are `src/script/interpreter.cpp` at the pin (`docs/PROVENANCE.md`).

## `BsvScript.Properties.Hooks` (`lean/BsvScript/Properties/Hooks.lean`)

## The splice family

## `BsvScript.Properties.Hooks` (`lean/BsvScript/Properties/Hooks.lean`)

## The arithmetic family

## `BsvScript.Properties.Hooks` (`lean/BsvScript/Properties/Hooks.lean`)

## The bitwise family

## `BsvScript.Properties.Hooks` (`lean/BsvScript/Properties/Hooks.lean`)

## The stack family

## `BsvScript.Properties.Hooks` (`lean/BsvScript/Properties/Hooks.lean`)

## The expansion family

## `BsvScript.Properties.Hooks` (`lean/BsvScript/Properties/Hooks.lean`)

## The crypto family

## `BsvScript.Properties.Hooks` (`lean/BsvScript/Properties/Hooks.lean`)

## The families' hooks and the evaluator's

## `BsvScript.Properties.Hooks` (`lean/BsvScript/Properties/Hooks.lean`)

## NULLFAIL and NULLDUMMY under the gate

## `BsvScript.Properties.KernelSample` (`lean/BsvScript/Properties/KernelSample.lean`)

# BsvScript.Properties.KernelSample

The kernel-evaluated sample (the direction audit's item (b), of
2026-09-27 17:15 UTC; `docs/HYPOTHESES.md` §3). The kernel checks the
definitions, the theorems and each `@[csimp]` lemma's statement; the corpus judges the COMPILED
evaluator (`eval/bsvs`), whose code the Lean compiler emits with the `@[csimp]` substitutions applied.
This module is a bridge between the two at fixed points. Each vector below is a short arithmetic,
stack, flow, splice or version-gate script with its expected verdict and error code. Its theorem is
decided by `decide +kernel` on the definitions: the kernel reduces `Eval.verifyScript` as written, and
neither compiled code nor `Lean.ofReduceBool` enters the proof. The SAME list `vectors` is run by the
compiled evaluator in the flow leg (`Test/FlowCheck.lean`), which exits 1 on any disagreement. Since #50
the compiled `Eval.verifyScript` is `Eval.verifyScriptI`, the array machine (`@[csimp] Eval.verifyScript_eq_I`),
so the bridge has two links: the kernel-checked theorem `verifyScript_eq_I` ties that machine to the
definition, and these vectors check the compiler's translation of it. The list machine the compiled code
still runs elsewhere (the mempool gate's P2SH standardness run and `--trace`) is outside this sample.
Agreement on both sides is the sample's claim. It is evidence at these points, not a proof about the
compiler.

Two definitions the vectors reach are well-founded recursions, which the kernel does not reduce: the
loop (`Machine.loop`) and the push-only test (`Machine.isPushOnly`). Each has a copy here with a fuel
argument, structural on the fuel and otherwise the same body (`loopFuel`, `isPushOnlyFuel`), proven
equal to it at any fuel at least the script's length (`loop_eq_fuel`, `isPushOnly_eq_fuel`). A
vector's proof unfolds `Eval.verifyScript` down to the loop, rewrites the two recursions into their
copies, and hands the rest to the kernel. Every other definition is reduced as written, the families'
included.

The vectors take the parameters `Params.derive` gives SV-node's mainnet defaults at the default spend
height for an output of that height (`NodeConfig.svMainnetDefault`, `defaultSpendHeight`: a
post-Chronicle spend of a post-Chronicle output), on the block path unless the vector says the
mempool path, and a context whose three checkers answer `false` (no vector reaches a signature, a
lock time or a sequence). No vector has a hash, a signature or a large number, so the kernel finishes
each in seconds.

Bare line numbers are `src/script/interpreter.cpp` at the pin (`docs/PROVENANCE.md`).

## `BsvScript.Properties.KernelSample` (`lean/BsvScript/Properties/KernelSample.lean`)

## The two recursions with fuel

## `BsvScript.Properties.KernelSample` (`lean/BsvScript/Properties/KernelSample.lean`)

## The vectors

## `BsvScript.Properties.KernelSample` (`lean/BsvScript/Properties/KernelSample.lean`)

## The kernel's verdicts

Each theorem below is one vector decided by the kernel: the unfolding to the loop and the rewrite
into the fuel copies, then `decide +kernel`.

## `BsvScript.Properties.P2SH` (`lean/BsvScript/Properties/P2SH.lean`)

# BsvScript.Properties.P2SH

The P2SH history (#23; `docs/DESIGN.md` §2.2 step 9, §3; `docs/PARAMETERS.md` §2):
disabled for new outputs after Genesis, grandfathered for the outputs that
existed, each rule at its site of the reference:

* **the shape**: `IsP2SH` (`script.cpp:168–172`): 23 bytes, `OP_HASH160 <20 bytes> OP_EQUAL`;
* **the flag**: `SCRIPT_VERIFY_P2SH`, consensus by height (`verify_script_flags.cpp:38–40`,
  `p2shHeight` 173,805 on mainnet, `chainparams.cpp:28`, `chainparams.cpp:1076`; in the block word from
  block 173,806 by the tip's-height convention, `flagWord_block_p2sh`), mandatory in every
  era (`standard.h:56`, `standard.h:63`), so in every mempool word a node derives with no
  `-promiscuousmempoolflags` word (`flagWord_mempool_p2sh`, its hypothesis `hp`); a promiscuous
  word REPLACES the mempool word (`verify_script_flags.cpp:19–25`) on a chain whose
  `RequireStandard()` is false (`validation.cpp:795–801`: stn, testnet and regtest,
  `chainparams.cpp:1271`, `:1416`, `:1527`; never mainnet, `:1121`), and one lacking P2SH or
  carrying `SCRIPT_UTXO_AFTER_GENESIS` takes the grandfathered evaluation below away on that
  node's mempool path (`derive_p2shCopy_grandfathered_mempool`); the block path never reads it;
* **the evaluation, pre-Genesis coins only** (`VerifyScript`, `2354–2356` the stack copy,
  `2380–2424` the block): the P2SH flag and the shape select the redeem script only when
  the UTXO was created before Genesis (`!(flags & SCRIPT_UTXO_AFTER_GENESIS)` at `2355`
  and `2383`); for a coin created after Genesis the same bytes are a plain script, a
  hash puzzle (`2358–2378`: `OP_HASH160 <h> OP_EQUAL` on whatever the unlocking script
  pushed), whatever the spend era: **disabled for new outputs**; a coin created before
  Genesis keeps the P2SH evaluation when spent after Genesis and after Chronicle:
  **grandfathered**;
* **the outputs, a consensus rule**: `CheckRegularTransaction` (`validation.cpp:609–622`)
  rejects a transaction with a P2SH-shaped output once Genesis is active in the era
  (`bad-txns-vout-p2sh`, `DoS(100)`, `REJECT_INVALID`), so no regular transaction can
  create one after Genesis; `CheckCoinbase` (`validation.cpp:571–592`) has no such test, so a coinbase
  can (recorded on #23), and its output is then the hash puzzle above;
* **standardness (policy, outside the semantics)**: `Solver` classes a P2SH-shaped output
  `TX_NONSTANDARD` once Genesis is active (`script/standard.cpp:72–76`), so it is never
  relayed as standard; the pre-Genesis input check evaluates the redeem script for its
  sigops (`IsInputStandard`, `standard.cpp:376–425`, `MAX_P2SH_SIGOPS`);
* **the block-level sigop count** (`GetP2SHSigOpCount`, `validation.cpp:462–493`): the
  redeem script's sigops are counted for a pre-Genesis coin with the P2SH shape and
  skipped for a coin created after Genesis (`validation.cpp:481–483`); a block rule (#36), named here.

Every `[SRC]` is bitcoin-sv v1.2.2 at `879fc8b` (`docs/PROVENANCE.md`); a bare
number is a line of `src/script/interpreter.cpp`.

## `BsvScript.Properties.P2SH` (`lean/BsvScript/Properties/P2SH.lean`)

## The shape and the copy

## `BsvScript.Properties.P2SH` (`lean/BsvScript/Properties/P2SH.lean`)

## Disabled for new outputs: the locking phase without the P2SH block

## `BsvScript.Properties.P2SH` (`lean/BsvScript/Properties/P2SH.lean`)

## Grandfathered: the copy under the derived words

## `BsvScript.Properties.P2SH` (`lean/BsvScript/Properties/P2SH.lean`)

## The outputs: a consensus rule of the transaction level

## `BsvScript.Properties.Resources` (`lean/BsvScript/Properties/Resources.lean`)

# BsvScript.Properties.Resources

The resource bounds (#25, S1's half; `docs/DESIGN.md` §9): what the machine enforces, at the site
the reference enforces it, as theorems on the machine. `Machine.loop` is parametrized by the
family hook `OpExec`; a bound the loop enforces after every step (the pre-Genesis stack depth,
`1800–1803`) is a theorem for every hook; a bound a family may touch (the op count through
`OP_CHECKMULTISIG`, `1534–1536`; the memory counter through every push and pop) is a theorem
under a named hypothesis on the hook (`HookOpCount`, `HookMem`) that each family discharges for
its own `exec`: the crypto family's two multisig bounds are below (R5); the two hypotheses are
discharged for every family's `exec` and for `Eval.opExec` in `BsvScript.Properties.Hooks` (H2, H3;
2026-09-27), so R2a and R3b hold for the evaluator's loop with no hook hypothesis left (H4, H5), each
from its start condition (the op count within the limit; the counter exact, which the locking phase
lacks after an unlocking script that left elements on its alt stack, R3b). The machine's own steps (the
pushes, the flow opcodes, the separator) are discharged here.

Bare line numbers are `src/script/interpreter.cpp` at the pin (`docs/PROVENANCE.md`).

## `BsvScript.Properties.Resources` (`lean/BsvScript/Properties/Resources.lean`)

## R1: the script-size gate (`429–430`)

## `BsvScript.Properties.Resources` (`lean/BsvScript/Properties/Resources.lean`)

## R2: the op count (`466–467`, `377–380`)

## `BsvScript.Properties.Resources` (`lean/BsvScript/Properties/Resources.lean`)

## R3: the stack memory (`limitedstack.cpp:194–207`, `1815–1818`)

## `BsvScript.Properties.Resources` (`lean/BsvScript/Properties/Resources.lean`)

## R4: the pre-Genesis stack depth (`1800–1803`, `script.h:32`)

## `BsvScript.Properties.Resources` (`lean/BsvScript/Properties/Resources.lean`)

## R5: the multisig bounds (`1517–1536`)

## `BsvScript.Properties.Resources` (`lean/BsvScript/Properties/Resources.lean`)

## R6: the result width (`script_num.cpp:144–222`, `1273–1274`, `1367–1369`)

## `BsvScript.Properties.Sighash` (`lean/BsvScript/Properties/Sighash.lean`)

# BsvScript.Properties.Sighash

The three signer properties as theorems (#149; `docs/DESIGN.md` §4.3): what a signer must hash for the node to
accept its signature, each a sentence about the executable semantics at its site of the reference:

* **the scriptCode of a signature check** (`1471–1481`, `2338–2342`): inside the unlocking script under
  `SCRIPT_CHRONICLE` the bytes from the last executed `OP_CODESEPARATOR` with the locking script appended; the
  tail alone without the flag; in the locking script the bytes from its last executed separator
  (`scriptCode_unlock_site`, with the separator's two sites in `codeSep_sites` and the cleaned form a FORKID
  signature digests in `scriptCode_unlock_site_forkid`); over a whole run, `codeSep` is the script from the byte
  after the last executed separator, the script's start when none executed (`codeSep_last`, from the frames
  `opExec_codeSep` and `execStep_codeSep`; at the check, `scriptCode_last`), so in the unlocking script it is a
  suffix containing the check (`codeSep_run_suffix`) and under `SCRIPT_CHRONICLE` the scriptCode is never the
  locking script alone (`scriptCode_run`);
* **the dispatch** (`2112–2124`): the CHRONICLE bit selects the original digest whatever the FORKID bit; FORKID
  without CHRONICLE, under FORKID enabled, selects the BIP143 digest (`digest_dispatch_chronicle`);
* **SIGHASH_SINGLE past the outputs** (`2086–2100`; `2034–2083`): the original digest is the constant `one`,
  unhashed; the BIP143 digest hashes a preimage whose `hashOutputs` is thirty-two zero bytes
  (`single_past_outputs`).

The definitions are `BsvScript.Sighash` and `BsvScript.Machine` as they stand; this module adds the run
statements' vocabulary and no definition of the semantics: two inductive propositions, `LoopReach` (the loop's
iterations; `LoopReach.loop_eq` ties it to `loop`) and `LoopTrace` (the same iterations with the instructions
they ran, `LoopTrace.reach` and `LoopReach.trace`), the record `TraceEntry` and the function `afterLastSep` (the
offset after a trace's last executed separator).
Every `[SRC]` that names no other source is bitcoin-sv v1.2.3 at `6504a3af` (`docs/PROVENANCE.md`); a bare
number is a line of `src/script/interpreter.cpp`. The measured lines of the signers are each record's own
reading at its release.

## `BsvScript.Properties.Sighash` (`lean/BsvScript/Properties/Sighash.lean`)

## The scriptCode of a signature check (`1471–1481`, `2338–2342`)

## `BsvScript.Properties.Sighash` (`lean/BsvScript/Properties/Sighash.lean`)

## The scriptCode over a whole run (`407`, `1445–1448`, `482`, `1471–1481`)

## `BsvScript.Properties.Sighash` (`lean/BsvScript/Properties/Sighash.lean`)

## The last executed separator over a whole run (`405–407`, `450`, `459`, `482`, `1445–1448`, `1471–1481`)

## `BsvScript.Properties.Sighash` (`lean/BsvScript/Properties/Sighash.lean`)

## The dispatch (`2112–2124`)

## `BsvScript.Properties.Sighash` (`lean/BsvScript/Properties/Sighash.lean`)

## SIGHASH_SINGLE past the outputs (`2086–2100`; `2034–2083`)

## `BsvScript.Properties.TxValue` (`lean/BsvScript/Properties/TxValue.lean`)

# BsvScript.Properties.TxValue

The output-side value bounds of `checkTransactionCommon` at the bitcoin-sv pin
in `docs/PROVENANCE.md`. The proofs use `checkTransactionCommon_ok_iff` and
`checkOutputs_ok_iff`, whose bridge to the executable loop is
`checkTransactionCommon_eq` and `forIn_eq_checkOutputs`.

These statements concern the transaction's outputs. The input-side UTXO set
and fees belong to the transaction state machine (S6, #58; `docs/DESIGN-S6.md`:
`applyTx`, #61) and are outside these statements.

## `BsvScript.Properties.VersionGate` (`lean/BsvScript/Properties/VersionGate.lean`)

# BsvScript.Properties.VersionGate

The version-1 branch (#19; `docs/DESIGN.md` §5.3): the four restrictions the
issue names, MINIMALDATA, CLEANSTACK, SIGPUSHONLY and LOW_S, at every site the
reference reads them, the branch-selection parameter they hang on, and the
theorems of both branches (the gate ON: the restriction binds as the word says;
the gate OFF: the bit is never consulted). Every `[SRC]` is bitcoin-sv v1.2.3 at
`6504a3af` (`docs/PROVENANCE.md`); a bare number is a line of
`src/script/interpreter.cpp`.

## The branch-selection parameter, verified at the pin

`checker.Version()` is `txTo_->nVersion` (`2254–2257`), the spending
transaction's `nVersion`, an `int32_t` (`src/primitives/transaction.h:273`;
read as `Tx.version` through `Tx.toInt32`, so a negative version is a negative
`Int`). `IsMalleableTxnVersion(v) = v > 1` (`34–38`);
`EnforceNonMalleability(flags, v) = !(IsChronicle(flags) && v > 1)` (`40–44`;
the four `static_assert`s of `46–49` are decided in `Params.lean`). So the
branch is: **the gate is ON** (the seven restrictions bind exactly as the flag
word says) when the word lacks `SCRIPT_CHRONICLE` (a pre-Chronicle spend era:
`verify_script_flags.cpp:77–78` on the block path, `policy.h:195–197, 212–215`
on the mempool path) or the version is at most 1, a negative version included;
**OFF** for a version above 1 in a word with `SCRIPT_CHRONICLE`. The UTXO's era
never selects the branch (`411–427` read the UTXO markers for the era rules
only). The sites that read the gate at the pin: seven `EnforceNonMalleability`
reads, `285` (LOW_S), `433` (MINIMALDATA), `801` (MINIMALIF), `1493` and `1643`
(NULLFAIL), `1666` (NULLDUMMY), `2441` (CLEANSTACK), plus one inlined read of
`IsMalleableTxnVersion` under `IsChronicle` at `2327` (SIGPUSHONLY): an
exhaustive grep of the file for `EnforceNonMalleability` returns exactly the seven,
and a grep for `IsMalleableTxnVersion` and `checker.Version()` adds `2327` and the
two version pushes of `OP_VER`/`OP_VERIF` (`603`, `810–811`), which are not gates. In the Lean the gate is
`Params.enforceNonMalleability`, applied once to the word (`Flags.gate`, in
`Machine.mkEnv` and `Machine.verifyScript`) and re-read at the crypto sites as
the reference does (`enforceNonMalleability_gate`: the second read is the
first).

## The audit: every read of the four flags at the pin, and its Lean

| flag (bit) | where the word gets it (its kind) | read at | the Lean |
|---|---|---|---|
| `SCRIPT_VERIFY_LOW_S` (3) | the block word from `daaHeight` (`verify_script_flags.cpp:65–67`); mandatory (`standard.h:60, 67`): **consensus by height** | `275–280`: with DERSIG and STRICTENC, the strict DER shape (`IsValidSignatureEncoding`, `177–245`), ungated | `Env.strictDer` (`Flags.strictDer` of the FORKID-adjusted word), `Ops.Crypto.checkSignatureEncoding` |
| | | `282–287`: `CPubKey::CheckLowS` on the signature without its hash-type byte; the error `SCRIPT_ERR_SIG_HIGH_S` only when the gate is on | `checkSignatureEncoding`: `f.lowS && !checkLowS (sig.dropLast) && enforceNonMalleability f version` on the gated word |
| | | `pubkey.cpp:353–363` `CheckLowS`: the lax parse (`32–175`), then `!secp256k1_ecdsa_signature_normalize`; a signature that does not lax-parse fails the check; an `r` or `s` above 32 bytes or at or above `n` is the zero signature (`146–173`), which is low, so the check passes and the signature then fails verification (`docs/DESIGN.md` §4.1) | `Crypto.Secp256k1.checkLowS`, `parseDerLax`, `isHighS` |
| | | the callers: `1459` (`OP_CHECKSIG`/`OP_CHECKSIGVERIFY`, every signature), `1605` (`OP_CHECKMULTISIG`/`VERIFY`, every signature tried) | `Ops.Crypto.checkSigOp`, `multisigLoop` |
| `SCRIPT_VERIFY_MINIMALDATA` (6) | the standard set only (`policy.h:189`): **policy**, in no block word (`blockScriptFlags_policy_off`) | `433–434`: `requireMinimal` = the flag under the gate, computed once per `EvalScript` call (so once per script: the unlocking script, the locking script, the P2SH redeem script) | `Machine.mkEnv` (`Env.requireMinimal`), `mkEnv_requireMinimal` |
| | | `475`: `CheckMinimalPush` (`331–358`) on every EXECUTED push (`473`: under `fExec`; a push in a dead branch, or after a non-top-level `OP_RETURN`, is never checked; the bytes after a top-level `OP_RETURN` are never parsed, `858–861`) | `Machine.execStep`, `checkMinimalPush`, `execStep_minimaldata` |
| | | every `CScriptNum` constructed with `requireMinimal` (`script_num.cpp:53–91`: the width first, `:62–65`, then `IsMinimallyEncoded`, `:67–70`, `int_serialization.h:120–152`): `546` CLTV and `577` CSV (width 5, pre-Genesis UTXOs); `622`, `624`, `655`, `680` `OP_SUBSTR`/`OP_LEFT`/`OP_RIGHT`; `709`, `717`, `745`, `753` `OP_LSHIFTNUM`/`OP_RSHIFTNUM`; `1015` `OP_PICK`/`OP_ROLL`; `1129`, `1163` `OP_LSHIFT`/`OP_RSHIFT`; `1235` the unary family; `1300–1301` the binary family; `1386–1390` `OP_WITHIN`; `1524`, `1551` the `OP_CHECKMULTISIG` counts (width 4); `1717` `OP_SPLIT`; `1747` `OP_NUM2BIN` | `Numbers.isMinimallyEncoded`, `readNum`; `Machine.execCltv`/`execCsv`, `Ops.Expansion.readInt64Operand`, `lshiftnum`, `rshiftnum`, `Ops.Stack.execStack`, `Ops.Bitwise.shift`, `Ops.Arith.readOperand` (`unary`, `binary`, `within`), `Ops.Crypto.readCount`, `Ops.Splice.split`, `num2binOp`; `readOperand_minencode`, `readNum_minencode` |
| | | NOT read by: `OP_BIN2NUM` (`1786–1790`: the result's `IsMinimallyEncoded` against the width, always, `SCRIPT_ERR_INVALID_NUMBER_RANGE`), `OP_IF`/`OP_NOTIF` (`CastToBool`, `815`; MINIMALIF is its own flag, never set at the pin), `OP_EQUAL`, the hashes, `OP_SIZE`, `OP_DEPTH`, `OP_CAT`, the stack moves | `Ops.Splice.bin2num`, `Machine.execIf` |
| `SCRIPT_VERIFY_CLEANSTACK` (8) | the standard set only (`policy.h:188`): **policy** | `2430–2448`, after the final-stack rule (`2374–2378`) and the P2SH evaluation (`2380–2424`): without P2SH the word is invalid (`2432–2435`, ungated); under the gate the MAIN stack must hold exactly one element (`2441–2445`; the alt stack died with `EvalScript`, `1993–2005`; after P2SH it is the restored stack the redeem script ran on, `2405–2416`) | `Machine.phase2` (`Flags.cleanStackDemand`, then `flags.cleanStack && stF.stack.length != 1`); `verifyScript_cleanstack_without_p2sh`, `phase2_cleanstack` |
| `SCRIPT_VERIFY_SIGPUSHONLY` (5) | the block word when Genesis is active (`verify_script_flags.cpp:71–75`); the per-input word (`policy.h:229–232`): **consensus by height** (Genesis) | `2321–2334`: under the flag, with Genesis-without-Chronicle, or Chronicle with a non-malleable version (`IsMalleableTxnVersion` at `2327`), `CScript::IsPushOnly` (`script.cpp:209–220`: every instruction parses and no opcode is above `OP_16`; `OP_RESERVED` counts as a push, `209–213`; a truncated push fails the parse) | `Machine.verifyScript` (`pushOnlyRequired`), `isPushOnly`; `verifyScript_sigpushonly` |
| | | `2385–2387`: the P2SH path demands a push-only unlocking script whatever the flag and the version (a pre-Genesis UTXO with the P2SH shape) | `Machine.phase2` |

The other three gated restrictions are #11's (NULLFAIL `1491–1497`, `1641–1647`;
NULLDUMMY `1664–1670`) and #8's (MINIMALIF `796–804`);
`Properties.Basic.gate_noninterference` covers all seven when the gate is off.

## What the theorems below say

* the gate: `enforceNonMalleability_iff` (ON iff no CHRONICLE or version ≤ 1),
  `Flags.gate_of_on` (the word is read as given), `enforceNonMalleability_gate`
  and `Flags.gate_gate` (gating twice is gating once);
* MINIMALDATA: `mkEnv_requireMinimal` (`433` as an equation),
  `execStep_minimaldata` and `execStep_push_of_not_requireMinimal` (`475`),
  `readNum_minencode`/`readOperand_minencode` and their relaxed twins (every
  number read);
* LOW_S: `checkSignatureEncoding_highS` (`282–287` with the gate on),
  `checkSignatureEncoding_ne_highS` (the error is unreachable when the gated
  bit is clear);
* SIGPUSHONLY: `verifyScript_sigpushonly` (`2321–2334` with the gate on);
* CLEANSTACK: `verifyScript_cleanstack_without_p2sh` (`2432–2435`, every
  version), `phase2_cleanstack` (`2441–2445` with the gate on);
* the version-2 halves: `verifyScript_minimaldata_off`, `verifyScript_lowS_off`,
  `verifyScript_sigpushonly_off`, `verifyScript_cleanstack_off`: with
  `SCRIPT_CHRONICLE` and a version above 1, each bit may be set or cleared
  without changing any verdict (P3 restricted to one bit, with that bit's own
  side condition).

The executable evidence is `lean/Test/VersionGateCheck.lean` (`make versiongatecheck`):
every corner above under the four parameter sets a mainnet node derives, verdict
and error code; the reference's own `script_tests.json` rows carrying the four
flags (`make scripttests`); the corpora with their version-1 twins against bsv-rs.

## `BsvScript.Properties.VersionGate` (`lean/BsvScript/Properties/VersionGate.lean`)

## The gate (`34–44`)

## `BsvScript.Properties.VersionGate` (`lean/BsvScript/Properties/VersionGate.lean`)

## MINIMALDATA (`433–434`, `475`, every number read)

## `BsvScript.Properties.VersionGate` (`lean/BsvScript/Properties/VersionGate.lean`)

## LOW_S (`282–287`, `pubkey.cpp:353–363`)

## `BsvScript.Properties.VersionGate` (`lean/BsvScript/Properties/VersionGate.lean`)

## SIGPUSHONLY (`2321–2334`)

## `BsvScript.Properties.VersionGate` (`lean/BsvScript/Properties/VersionGate.lean`)

## CLEANSTACK (`2430–2448`)

## `BsvScript.Properties.VersionGate` (`lean/BsvScript/Properties/VersionGate.lean`)

## The version-2 halves: each bit alone, with the gate off

## `BsvScript.Properties.Widths` (`lean/BsvScript/Properties/Widths.lean`)

# BsvScript.Properties.Widths

#25's remaining rows at the opcode (2026-09-27; the list on #25, 5852538695): the
number reader's overflow refusal, the digest widths of the hash opcodes, `OP_CAT`'s length and
`OP_SPLIT` as its inverse, `OP_NUM2BIN`'s memory refusal at the opcode (the flagged rule
`splice.num2bin.memory`), and the count bounds and result widths of the two expansion shifts, each
stated on the opcode's own definition and cited at the pin.

Bare line numbers are `src/script/interpreter.cpp` at the pin (`docs/PROVENANCE.md`).

## `BsvScript.SigOps` (`lean/BsvScript/SigOps.lean`)

# BsvScript.SigOps

The node's count of signature operations, `CScript::GetSigOpCount` (`src/script/script.cpp:30–166`
at the pin, `docs/PROVENANCE.md`), on every path (2026-09-27, S1: the spec gap
`tx.gate.policy-caps.unmodelled`'s remainder, CLAUDE.md rule 1; the transaction-level counts and the
mempool's test over them are `BsvScript.TxPolicy`'s).

The count walks the instructions once, carrying the last instruction (`30`, `37`, `120`;
default-constructed as `OP_INVALIDOPCODE` with an empty operand, `instruction.h:23–29`), the scope level
(`33`) and the count (`29`). An instruction whose opcode is `OP_INVALIDOPCODE` ends the walk (`40–41`):
a push that fails to decode, and a literal `0xff`, which `decode_instruction` returns as a valid
instruction (`instruction_iterator.h:26–27`). Under `fAccurate` or Genesis (`43–65`) a top-level
`OP_RETURN` ends it (`45–49`), `OP_IF`/`OP_NOTIF`/`OP_VERIF`/`OP_VERNOTIF` open a scope (`50–54`) and
`OP_ENDIF` closes one, an unbalanced `OP_ENDIF` setting `sigOpCountError` (`55–63`).
`OP_CHECKSIG`/`OP_CHECKSIGVERIFY` count one (`67–70`); a multisig counts `multisigSigOps` (`71–119`).
`sigOpCountError` is `none` here; every caller refuses on it before it reads a count
(`validation.cpp:1242`).

The paths: before Genesis without `fAccurate` (the consensus gate's count, `validation.cpp:437–459`
at `validation.cpp:559–566`) no scope is tracked, a multisig counts 20 and nothing fails (`sigOpCount_legacy_isSome`);
with `fAccurate` before Genesis (a P2SH redeem script, `script.cpp:159–165`) the scopes are tracked and a
multisig after `OP_1`–`OP_16` counts its number; after Genesis (every count the mempool takes then,
`validation.cpp:1235–1238`) a multisig counts the preceding push's number, up to 2,147,483,647 from a
four-byte push (`sigOpCount_multisig_max`), so three output scripts of six bytes each (`04 ffffff7f ae`)
count past `UINT32_MAX`, the default and largest policy cap (`BsvScript.TxPolicy`). Every count is at
most 2,147,483,647 per byte of its script (`sigOpCount_le`).

Bare line numbers are `src/script/script.cpp` at the pin (`docs/PROVENANCE.md`).

## `BsvScript.SigOps` (`lean/BsvScript/SigOps.lean`)

The theorems (T-SO1 to T-SO9; the transaction-level ones are `BsvScript.TxPolicy`'s).

## `BsvScript.Sighash` (`lean/BsvScript/Sighash.lean`)

# BsvScript.Sighash

The signature hash (#12; `docs/DESIGN.md` §4.3): the hash type
(`src/script/sighashtype.h:14–96`), the BIP143-style digest
`SignatureHashBIP143` (`interpreter.cpp:2034–2084`), the original digest
`SignatureHashOriginal` (`2086–2110`) with its serializer
`CTransactionSignatureSerializer` (`1841–1958`), the dispatch `SignatureHash`
(`2112–2124`), and the scriptCode preparation the signature opcodes perform
before hashing: `GetHashType` (`247–253`) and `CleanupScriptCode` (`255–263`,
`CScript::FindAndDelete`, `script.h:201–224`). The digest is SHA-256d
(`CHashWriter::GetHash`, `src/hash.h:199–204`). The serialization formats are
`src/primitives/transaction.h` (`COutPoint`: the txid as stored then the index;
`CTxOut`: the value then the script; the null `CTxOut()` has `nValue = -1`,
`src/primitives/transaction.h:196–199`) and `src/serialize.h` (`CompactSize`; every integer little-endian).
Bare line numbers are `interpreter.cpp` at the pin (`docs/PROVENANCE.md`).

**Q2 closed** (DESIGN §4.3, `[SRC]`): the original digest is reachable on
mainnet today. `SignatureHash` takes it whenever the type lacks the FORKID bit
or carries the CHRONICLE bit (`2118–2123`); under the mainnet flags since UAHF
(`SCRIPT_ENABLE_SIGHASH_FORKID` from height 478,558, `chainparams.cpp:1065`,
`verify_script_flags.cpp:54–58`) a signature without FORKID is refused by
`CheckSignatureEncoding` (`SCRIPT_ERR_MUST_USE_FORKID`, `305–306`), so the
non-FORKID path is historical replay; the CHRONICLE bit (`0x20`, accepted only
with `SCRIPT_CHRONICLE`, `302–303`) selects the original digest for a live
signature. Both paths are executable here.

**The truncated-push corner, MEASURED 2026-09-24** (S3; `corpus/gen`,
`sighash/original/truncated-push/*`: six shapes of a truncated push after a
post-Genesis top-level `OP_RETURN`, each signed over the spec's serialization of
the unparseable scriptCode; the spec's own SV-node instance agrees with the spec
on all six, both instances; `docs/records/20260924-150154-sighash-family-s3.md`,
`corpus/INDEX.md` §2 and §4c; the `[EST]` that stood here until 2026-09-26 is
gone): `SerializeScriptCode` (`1862–1892`) on a scriptCode whose parse fails (a
truncated push after the signature opcode) writes a size prefix of the whole
script minus the separators it parsed (`1875`), then the bytes up to the
parser's failure point (`1887–1891`; `GetOp2`, `script.h:165–198`: the opcode
and, when present, the length prefix are consumed before the failure). The
definition below follows the code as written; T-SH11 states the walk case by
case.

## `BsvScript.Sighash` (`lean/BsvScript/Sighash.lean`)

## The hash type (`sighashtype.h:14–96`)

## `BsvScript.Sighash` (`lean/BsvScript/Sighash.lean`)

## Serialization (`src/serialize.h`, `src/primitives/transaction.h`)

## `BsvScript.Sighash` (`lean/BsvScript/Sighash.lean`)

## The BIP143-style digest (`SignatureHashBIP143`, `2034–2084`)

## `BsvScript.Sighash` (`lean/BsvScript/Sighash.lean`)

## The original digest (`SignatureHashOriginal`, `2086–2110`; the serializer `1841–1958`)

## `BsvScript.Sighash` (`lean/BsvScript/Sighash.lean`)

## The dispatch (`SignatureHash`, `2112–2124`)

## `BsvScript.Sighash` (`lean/BsvScript/Sighash.lean`)

## The scriptCode preparation (`CleanupScriptCode`, `255–263`)

## `BsvScript.Sighash` (`lean/BsvScript/Sighash.lean`)

## The reference's `FindAndDelete` unit cases (`src/test/script_tests.cpp:3819–3934`),
checked by the kernel.

## `BsvScript.Sighash` (`lean/BsvScript/Sighash.lean`)

## Widths (the layout pinned by theorem)

## `BsvScript.Sighash` (`lean/BsvScript/Sighash.lean`)

## The dispatch, the type, the scriptCode and the shapes as theorems (#25, S2, 2026-09-26)

## `BsvScript.Sighash` (`lean/BsvScript/Sighash.lean`)

## `FindAndDelete`'s single pass (#25, S2, 2026-09-27)

`CScript::FindAndDelete` (`script.h:202–224`) walks the script once: at every instruction start it strips every copy
of the pattern that begins there (`script.h:210–214`), then copies the next instruction whole (`script.h:209`, `script.h:215–216`: `GetOp`),
and a tail `GetOp` cannot read is appended as it stands (`script.h:219`). `findAndDelete` mirrors it with a fuel. The theorems
below are the walk case by case (T-SH12 to T-SH12c), what the walk preserves (T-SH12d, T-SH12e) and what a single
pass means (T-SH12f); the sixteen unit cases of the reference (`script_tests.cpp:3819–3934`) are the `decide`
examples above.

## `BsvScript.Standard` (`lean/BsvScript/Standard.lean`)

# BsvScript.Standard

The node's standardness tests: the policy half of the mempool gate that D123's road found missing
(`tx.gate.standardness.unmodelled`, the parent's `**Finding.**` on #27, 5860811662, and its class in
`harness/rules/sv-node.json`, 2026-09-28). Each definition is one function of
bitcoin-sv at the pin (`docs/PROVENANCE.md`), read line by line:

* `solver`: `Solver` (`script/standard.cpp:40–199`), the output types. P2SH is a type before Genesis only
  (`72–83`). A data carrier is `OP_RETURN` before Genesis or `OP_FALSE OP_RETURN` in both eras, followed by
  pushes only (`85–105`). Otherwise the three templates are tried in the order the map holds them (`47–65`;
  `txnouttype`'s order, `script/standard.h:73–82`), each walked by `matchTemplate` (`108–194`), and a
  multisig must carry minimal counts that agree with its keys (`124–139`).
* `isStandardOutput`: `IsStandardOutput` (`353–374`): multisig up to x-of-3 (`360–366`); a data carrier
  only when `-datacarrier` is on (`367–371`).
* `isDust`: `CTxOut::IsDust` (`primitives/transaction.h:203–213`): a threshold of 1 satoshi per output, none
  for a provably unspendable script (`CScript::IsUnspendable`, `script/script.h:260–277`).
* `isStandardTx`: `IsStandardTx` (`standard.cpp:427–500`) with its first reason. Before Chronicle the
  version (`431–439`); the size (`445–449`); before Genesis the size of each unlocking script (`458–461`);
  before Chronicle its push-only form (`462–465`); then the outputs (`468–485`: bare multisig and dust
  refuse at once, a non-standard type is noted and reported last), the data carrier's total (`487–491`),
  and the noted type (`493–497`).
* `isInputStandard`, `areInputsStandard`: `IsInputStandard` (`standard.cpp:376–425`) over every input
  (`AreInputsStandard`, `policy/policy.cpp:166–198`). The coin's locking script must solve in the coin's era
  (`coins.h:318–325`). For a P2SH coin the redeem script, read by running the unlocking script with no flags
  (`policy.cpp:178–180`) and the base checker (`interpreter.h:52–72`), must count at most `MAX_P2SH_SIGOPS`
  = 15 accurately (`standard.h:27`).

Where these refuse is the mempool gate's (`BsvScript.TxPolicy.standardnessRefusal`, `validation.cpp:1072–1088`
and `validation.cpp:1206–1223`), under `NodeConfig`'s `requireStandard` and `acceptNonStandardOutput`. The three settings the
tests read are `NodeConfig` fields with their defaults and sources (`dataCarrier`, `dataCarrierSize`,
`permitBareMultisig`; CLAUDE.md rule 1).

Bare line numbers are `src/script/standard.cpp` at the pin.

## `BsvScript.Standard` (`lean/BsvScript/Standard.lean`)

## The output types (`Solver`, `40–199`)

## `BsvScript.Standard` (`lean/BsvScript/Standard.lean`)

## Outputs (`IsStandardOutput`, `353–374`; `CTxOut::IsDust`)

## `BsvScript.Standard` (`lean/BsvScript/Standard.lean`)

## The transaction (`IsStandardTx`, `427–500`)

## `BsvScript.Standard` (`lean/BsvScript/Standard.lean`)

## The inputs (`IsInputStandard`, `376–425`; `AreInputsStandard`, `policy.cpp:166–198`)

## `BsvScript.Standard` (`lean/BsvScript/Standard.lean`)

## Properties

## `BsvScript.Tx` (`lean/BsvScript/Tx.lean`)

# BsvScript.Tx

The transaction frame (`src/primitives/transaction.h` at the pin): the fields
the machine and the sighash read, and the decoder from the serialized bytes
(`docs/DESIGN.md` §6: the corpus carries the spending transaction as hex). The
serialization for the sighash is #12's.

## `BsvScript.Tx` (`lean/BsvScript/Tx.lean`)

## Hex

## `BsvScript.TxContext` (`lean/BsvScript/TxContext.lean`)

# BsvScript.TxContext

The transaction context of a spend (#22; `docs/DESIGN.md` §5.4 `Context`): what
the interpreter reads from the transaction. `TransactionSignatureChecker`
(`interpreter.cpp:2126–2256`) holds the transaction, the input index and the
amount; it answers `CheckSig` (`2133–2164`, `Ops.Crypto.txCheckSig`),
`CheckLockTime` (`2166–2202`), `CheckSequence` (`2204–2250`) and `Version`
(`2254–2257`). The lock-time constants: `LOCKTIME_THRESHOLD` (`script.h:36`),
`SEQUENCE_FINAL`, `SEQUENCE_LOCKTIME_DISABLE_FLAG`, `SEQUENCE_LOCKTIME_TYPE_FLAG`,
`SEQUENCE_LOCKTIME_MASK` (`transaction.h:99–119`).
[LIT] https://protocol.bsvblockchain.org/specification/transactions#bip68-relative-locktime-pre-genesis-only at v1.2.2 (the four sequence constants only).

**The scope boundary** (#22, #36): script reads the transaction's version, lock
time, the spent input's sequence and outpoint, every input's outpoint and
sequence and every output through the sighash (§4.3), and the amount of the
spent output through the sighash and `CheckSig`. The transaction's own validity
(`CheckRegularTransaction`, `validation.cpp:519–639`) and every block-level
rule are outside script (`BsvScript.TxRules` carries the transaction-level
checks the reference's vector runner applies; block-level consensus is #36).

## `BsvScript.TxPolicy` (`lean/BsvScript/TxPolicy.lean`)

# BsvScript.TxPolicy

The two transaction-level POLICY caps the node's mempool applies beside the
consensus checks of `BsvScript.TxRules` (the spec gap `tx.gate.policy-caps.unmodelled`
the block road found, `docs/records/20260926-231004-txroad-s3.md`: `tx-00035`,
20,000 sigops, consensus-valid, refused `bad-txns-too-many-sigops` by that road's policy
instance, which then did not require standardness (`acceptnonstdtxn=1`); at the node's
default, which the mempool column stands for since D123, it is refused `dust` first, for
its zero-value outputs (T-STD7); CLAUDE.md rule 1: a policy limit enters the
semantics only as a named parameter with its default and its source). Both are
`NodeConfig` fields (`lean/BsvScript/Params.lean`), read here by era exactly as
the node's getters read them:

* the sigop count against `-maxtxsigopscountspolicy`: `validation.cpp:1235–1247`
  (`GetTransactionSigOpCount(config, tx, view, true, era, err)` over
  `GetMaxTxSigOpsCountPolicy(era)`; `REJECT_NONSTANDARD`, `"bad-txns-too-many-sigops"`,
  a DoS score of 0); the getter `config.cpp:2422–2430`: the constant
  `MAX_TX_SIGOPS_COUNT_POLICY_BEFORE_GENESIS` = 20,000 / 5 = 4,000 before Genesis
  (`policy.h:81`), the setting after it (default `UINT32_MAX`, `policy.h:83–85`,
  `config.cpp:61`; the setter `config.cpp:2391–2415`: 0 → `UINT32_MAX`, above it refused);
* the serialized size against `-maxtxsizepolicy`: `IsStandardTx`,
  `script/standard.cpp:445–449` (`tx.GetTotalSize() > GetMaxTxSize(era, false)`,
  the reason `"tx-size"`; the standardness gate `validation.cpp:1073`); the getter
  `configscriptpolicy.cpp:397–413`: the constant `MAX_TX_SIZE_POLICY_BEFORE_GENESIS`
  = 99,999 before Genesis (`policy.h:68`), the setting after it (default
  `DEFAULT_MAX_TX_SIZE_POLICY_AFTER_GENESIS` = 10,000,000, `policy.h:70`,
  `configscriptpolicy.cpp:57`; the setter `:415–446`: 0 → the consensus size
  `MAX_TX_SIZE_CONSENSUS_AFTER_GENESIS`, above it or below 99,999 refused). A failed
  standardness test is enforced only when the node does not accept non-standard outputs
  for the era, or after Genesis under `requireStandard` for a reason other than
  `scriptpubkey` (`validation.cpp:1080–1088`; `GetAcceptNonStandardOutput(era)` is
  `!requireStandard` before Genesis and the setting `acceptnonstdoutputs` after it,
  `configscriptpolicy.cpp:468–471`, default true at `:60`): at that default the size
  refusal applies exactly under `requireStandard`, in both eras; `NodeConfig.acceptNonStandardOutput`
  carries the setting and `standardnessEnforced` reads the node's condition whatever it is (a node
  set to `-acceptnonstdoutputs=0` refuses after Genesis without `requireStandard`). The mempool
  column stands for the node default (D123, the maintainers' ruling of
  2026-09-27: `requireStandard` true on mainnet, the size cap live; T-TP9). The size test is one of
  `IsStandardTx`'s (`standard.cpp:427–500`), and since 2026-09-28 the mempool gate takes the whole test
  and `AreInputsStandard` (`BsvScript.Standard`; the last section, `standardnessRefusal`): the
  first reason refused where `validation.cpp:1081–1088` refuses it, a non-standard input where the node does
  not accept non-standard outputs (`1207–1224`), both before the sigop cap.

The count the node compares (`GetTransactionSigOpCount`, `validation.cpp:495–517`)
is `GetSigOpCountWithoutP2SH` (`438–460`) plus, for a non-coinbase, the P2SH count of
every pre-Genesis P2SH coin it spends (`463–494`: the redeem script's accurate count),
each over `CScript::GetSigOpCount` on its path (`BsvScript.SigOps`). The gate
`txPolicyGateFor` takes a count as an argument; `txPolicyGateCounted` takes the count
the node computes, `txSigOpCount` (the last section: both parts, on every path, with
`sigOpCountError` as `none`, refused at any cap, `validation.cpp:1242`), and
`mempoolTxPolicy` computes it from the spend's and the coins' heights. After Genesis a
multisig counts the preceding push's number, up to 2,147,483,647 from a four-byte push,
so the default cap `UINT32_MAX` is reachable: `multisigWitnessTx` (three outputs of
`04 ffffff7f OP_CHECKMULTISIG`, 18 bytes of locking script) counts 6,442,450,941 and
the mempool refuses it at SV-node's default (T-TP7); an unbalanced `OP_ENDIF`, or a
count push longer than four bytes, not minimal or negative, is `sigOpCountError`
(`script.cpp:59–67`, `script.cpp:89–95`, `script.cpp:102–115`; T-SO3, T-SO7, T-TP8). The corpus entries that
exercise them are the harness's (#26).

Pre-Genesis the two caps are constants below the consensus limits (4,000 < 20,000
sigops; 99,999 < 1,000,000 bytes), so the caps refuse transactions the consensus gate
accepts: `tx-00035` is the witness where the standardness gate lets it through (above).
Post-Genesis the consensus gate has no sigop cap and a size cap of 1,000,000,000
(`consensus.h:29`); the theorems below say exactly what the caps add at the values the
setters' zero rules select (the "consensus configuration": `-maxtxsizepolicy=0`,
`-maxtxsigopscountspolicy=0`), which is all the mempool's transaction gate adds to the block's
(`Bsvs.Run.txGate`, `consensus` false against true) on a transaction the standardness gate passes
(T-STD5). The mempool column differs from the block column in the scripts too: they run under the relay
word and the policy limits (`Params.derive` with `consensus` false; `Params.verifyScript_relay_block_version2`).

Bare line numbers are `src/validation.cpp` at the pin (`docs/PROVENANCE.md`).

## `BsvScript.TxPolicy` (`lean/BsvScript/TxPolicy.lean`)

## The mempool's sigop count on every path (2026-09-27: the spec gap's remainder)

`GetTransactionSigOpCount(config, tx, view, true, era, …)` (`validation.cpp:495–517`) is what the
mempool compares (`1236–1248`) under the spend's era (`1032`): `GetSigOpCountWithoutP2SH` (`438–460`:
every unlocking and every locking script at `fAccurate = false`, `SigOps.sigOpCount false genesis`) and,
for a non-coinbase, `GetP2SHSigOpCount` (`463–494`): for every input whose coin is pre-Genesis by its own
height (`478–484`; a coin still in the mempool counts as post-Genesis, `478–479`, as its height
`MEMPOOL_HEIGHT` = `0x7FFFFFFF`, `protocol_era.h:14`, lies above both activation heights) and P2SH
(`486`), the accurate count of its redeem script (`SigOps.p2shRedeemSigOps`). `sigOpCountError` refuses
at any cap (`1243`): `txPolicyGateCounted` on `none`. `mempoolTxPolicy` is the gate over the spend's and
the coins' heights for the evaluator's mempool column; the count `TxRules.sigOpCountWithoutP2SH` that
`txPolicyGateFor` was handed until now is its pre-Genesis part on every script without a literal `0xff`
(`sigOpCountWithoutP2SHAt_legacy_eq`).

## `BsvScript.TxPolicy` (`lean/BsvScript/TxPolicy.lean`)

## The standardness gate's properties (2026-09-28: `tx.gate.standardness.unmodelled`)

The gate (`standardnessRefusal`, above `mempoolTxPolicy`) is `IsStandardTx` and `AreInputsStandard`
(`BsvScript.Standard`) where `validation.cpp:1080–1088` and `1207–1224` refuse them. Its condition is the node's
two settings by era (`acceptsNonStandardOutput`), so at SV-node's mainnet default (`requireStandard` true) every
reason refuses before Genesis, every reason but `scriptpubkey` after it, and a non-standard input only before it;
at Teranode's default (`requireStandard` false, `acceptnonstdoutputs` true) the gate refuses nothing and the
mempool gate is the caps' counted gate, as it was: there the sigop cap and the count's error, the size cap
applying only under `standardnessEnforced`, false at that default (T-TP9). The witnesses are the shapes of the
road's five pre-Genesis rows the standardness decides (`corpus/tx`: the class's four, `tx-00032`, `tx-00037`,
`tx-00038` `scriptpubkey` and `tx-00036` `bad-txns-nonstandard-inputs`, and `tx-00035`'s code note, `dust`; the
parent's `**Finding.**` on #27, 5860811662).

## `BsvScript.TxRules` (`lean/BsvScript/TxRules.lean`)

# BsvScript.TxRules

The transaction-level checks the reference applies before any script runs
(#22, the scope boundary of `BsvScript.TxContext`): `CheckTransactionCommon`
(`validation.cpp:519–569`), `CheckRegularTransaction` (`595–640`),
`CheckCoinbase` (`572–593`), with the sigop count `GetSigOpCountWithoutP2SH`
(`438–460`) over `CScript::GetSigOpCount` (`script.cpp:30–128`). They are
written for the reference's vector runner (`src/test/transaction_tests.cpp`
`RunTests`, which calls them with the pre-Genesis limits `MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS`
= 20,000 and `MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS` = 1 MB, `consensus.h:27, 47`,
and `ProtocolEra::PreGenesis`) and for the spec's transaction verdict; the
block-level rules (fees, the UTXO set, ordering, maturity) are the transaction state
machine's, S6 (#58; `docs/DESIGN-S6.md`), which calls this module's gate from `lean/BsvChain`.

Bare line numbers are `src/validation.cpp` at the pin (`docs/PROVENANCE.md`); the
sigop walk's lines are cited with their file, `script.cpp`, and a `:NNN` continues
the file last named.

## `BsvScript.TxRules` (`lean/BsvScript/TxRules.lean`)

## The loops of `CheckTransactionCommon` and `CheckRegularTransaction` (#25, S2, 2026-09-27)

The definitions above write the reference's two `for` loops as do-blocks. A theorem about a do-block's `forIn` is
stated over a recursion that decides as the loop's body does (`forIn_eq_checkOutputs`, `forIn_eq_checkInputs`, each
quantified over the body with its tests as the hypothesis), and each definition is proven equal to the nested
conditional it denotes (`checkTransactionCommon_eq`, `checkRegularTransaction_eq`); the value checks (T-TX8), the
sigop count (T-TX9) and the outpoint checks (T-TX10) read off those.

## `BsvScript.TxRules` (`lean/BsvScript/TxRules.lean`)

## The pre-Genesis count is the node's on every script (2026-09-27; S1's ask 5)

`SigOps.sigOpCount` (S1's) models `CScript::GetSigOpCount` on every path; `TxPolicy.sigOpCount_legacy_eq`
tied it to `sigOpCountPreGenesis` on the scripts without a literal `0xff`, where the two parted until the walk
above stopped at that byte. T-TX11 drops the hypothesis.

## `Bsvs.Trace` (`lean/Bsvs/Trace.lean`)

# Bsvs.Trace: the evaluator's trace, proven to be the loop's own execution (#14)

The CLI reports what the machine did instruction by instruction. The machine's
loop (`BsvScript.Machine.loop`, `EvalScript` `interpreter.cpp:388–1833`) is
the semantics and is not duplicated here: `stepK` is one instruction of the
loop with its two exits abstracted, `loop_stepK` proves that the loop is
`stepK` with the loop as its continuation (the loop's own recursion equation,
by unfolding), and `traceLoop` is the loop written with `stepK` plus an
accumulator of steps. `traceLoop_fst` proves that the traced run returns
exactly `loop`'s result (through `stepK_map`, the exits being the only places a
value leaves `stepK`): the outcome the trace prints for a phase is the list
machine's `Machine.loop` outcome of that phase. The CLI's verdict is NOT taken from
the trace: it is `Eval.verifyScript`, compiled as `verifyScriptI` (the array machine,
`verifyScript_eq_I`), and `--trace` runs the same spend a second time on the list
machine (`traceVerifyScript`; lean #32's second lens, A-10, and its final lens on
Lean B, NEW-7). The steps it prints are recorded inside the same `stepK`
continuation, so each is a state of the list machine's run by construction; no
statement of the list of steps is proven (lean #32's second lens, B-10).

The trace records, per instruction: the byte offset, the opcode and its push
length, whether it executed (`fExec`, `459`), the outcome (`cont`, `done`,
`fail <code>`, `unimplemented`), and after it the stack depth, the alt-stack
depth, the top element, the memory counter and the op count.

