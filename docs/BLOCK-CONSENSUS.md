# BLOCK CONSENSUS: where the script verdict ends (#36; 2026-10-05)

**What this page records.** The script-layer boundary documented for #36 as of 2026-10-05, each rule named with
its citation at the pin, so that "complete" (the tuple's property 1, `NORTH-STAR.md` §3) is a claim against a
stated boundary. Its rule inventory remains historical context. The transaction state machine chartered by #58 on
2026-10-07 now owns these chain-layer rules (`docs/DESIGN-S6.md`); this page does not define that machine. This page was written against bitcoin-sv v1.2.2 at `879fc8b42168dd0e608dafd51b39c6dabad37d4d`,
and its line numbers are at that commit; the pin of record is v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`
since 2026-10-06 (`docs/PROVENANCE.md` §1, issue #57), and this page's citations are not yet re-anchored there. Bare line numbers are `src/validation.cpp` at that pin `[SRC]`; every other file is
named by its path under `src/`, in the form `docs/PROVENANCE.md` §2 uses (`script/interpreter.cpp`,
`policy/policy.h`, `primitives/transaction.h`; `validation.h`, a name two directories hold, is written
`src/validation.h`). Where a rule's value is a node setting, the page says so
(`CLAUDE.md` rule 1).

## 1. What the spec decides

**The script verdict.** The node runs one script verdict per input through `CScriptCheck::operator()`
(2524–2544): `VerifyScript` at 2528 over the input's unlocking script, the spent output's locking script, the
flag word and a `CachingTransactionSignatureChecker` built from the transaction, the input index and the spent
amount (2529–2538) `[SRC]`. That call is the spec's `Eval.verifyScript` (`lean/BsvScript/Eval.lean`; the
machine `docs/DESIGN.md` §2), decided from the same inputs (`docs/DESIGN.md` §6: the entry carries the
transaction, its prevouts with their heights, and the parameters).

**The parameters, from the heights.** The word is the block word of the tip's successor's era (`GetBlockScriptFlags`
2973–2982, the era at `height + 1` on 2981; `verify_script_flags.cpp:32–81`) united with the per-input flags of
the spend's era and the coin's era (`CheckInputScripts` 2693–2697: `InputScriptVerifyFlags(era, utxoEra)`,
`policy/policy.h:226–245`); a coin created in the mempool counts as created at the tip's successor
(`GetInputScriptBlockHeight` 2668–2675, `MEMPOOL_HEIGHT` `protocol_era.h:14`) `[SRC]`. The limits come from
`make_verify_script_params(config.GetConfigScriptPolicy(), flags, consensus)` (2702) `[SRC]`. The spec derives
the same word and limits from the two heights and the node's configuration in `Params.derive`
(`lean/BsvScript/Flags.lean`; `docs/PARAMETERS.md` §6; the theorem `P5` separates the policy fields).

**The transaction-level gate.** `CheckRegularTransaction` (595–640) and `CheckCoinbase` (572–593) over
`CheckTransactionCommon` (520–570): inputs and outputs non-empty, the serialized size against
`GetMaxTxSize(era, true)` (`configscriptpolicy.cpp:397–412`: `MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS` 1 MB,
`_AFTER_GENESIS` 1 GB, `consensus/consensus.h:27/29`), every output amount and their sum in `MoneyRange`, the
sigop count before Genesis; for a regular transaction only, no null and no duplicate outpoint (627–636) and after
Genesis no P2SH output (610–622 `bad-txns-vout-p2sh`, a consensus rule; `CheckCoinbase` 572–593 runs the common
checks and the script-length check and no P2SH check); the coinbase script between 2 and
`MAX_COINBASE_SCRIPTSIG_SIZE` 100 bytes (588–590, `consensus/consensus.h:69`) `[SRC]`.
These are `lean/BsvScript/TxRules.lean`
(`checkRegularTransaction_ok_iff`, `checkTransactionCommon_ok_iff`, `checkCoinbase_length`; the P2SH-output
rule is its `.p2shOutput` verdict), written as the reference's vector runner calls them (`docs/DESIGN.md` §5.5).

**The mempool's policy gate.** Standardness (`IsStandardTx`, `AreInputsStandard`) and the two transaction-level
caps `maxtxsizepolicy` and `maxtxsigopscountspolicy` are `BsvScript.Standard` and `BsvScript.TxPolicy`, as policy
parameters with their defaults (`docs/DESIGN.md` §5.5; `docs/PARAMETERS.md` §4, §5) `[SRC]`.

**What of the block reaches the interpreter: the heights, nothing else.** The checker reads the transaction's
version, its `nLockTime` and the input's `nSequence` (`script/interpreter.cpp:2166–2202`, `2204–2252`;
`docs/DESIGN.md` §5.5) `[SRC]`. `OP_CHECKLOCKTIMEVERIFY` compares its operand with `nLockTime` and
`OP_CHECKSEQUENCEVERIFY` with `nSequence`; whether the lock has matured against the chain is decided outside
the script (§2.2). `CheckInputs` obtains the median time past and discards it before any script runs
(2858–2859, `(void)mtp`) `[SRC]`. The median time past never reaches `VerifyScript`.

## 2. The rules outside the script layer as of 2026-10-05, with their citations (the state machine's since #58)

Kind: **C** a consensus rule with a fixed value · **C/setting** a consensus rule whose value the operator sets
(the shape of `-maxstackmemoryusageconsensus`, `docs/PARAMETERS.md` §1) · **setting** a node's own switch
acting on the block path · **P** policy: the mempool's, or a check the source itself names a local policy ·
**operator-list mechanism** a third kind, neither a consensus rule nor policy: a block-validity mechanism driven
by an operator's list, named and cited, outside the script layer and a parameter of the state machine (#70; the
owner's ruling of 2026-10-05 on the frozen-output and confiscation rows).

### 2.1 The transaction against the UTXO set (`Consensus::CheckTxInputs` 2553–2665, before any script, 2860)

| rule | `[SRC]` | kind |
|---|---|---|
| every input exists and is unspent | `HaveInputs` 2559–2561 ("Inputs unavailable"); in `ConnectBlock` 3327–3332 `bad-txns-inputs-missingorspent` | C |
| a coinbase output matures `COINBASE_MATURITY` = 100 blocks before it is spent | 2617–2625 `bad-txns-premature-spend-of-coinbase`; `consensus/consensus.h:75` | C |
| an output of a confiscation transaction matures `CONFISCATION_MATURITY` = 1,000 blocks before it is spent; the check has no configuration branch | 2628–2636 `bad-txns-premature-spend-of-confiscation`, `REJECT_INVALID`; `consensus/consensus.h:79` | operator-list mechanism (such an output enters the chain through the whitelist, or under the depth waiver, below, with no whitelist entry or with an entry whose `enforceAtHeight` the block has not reached: `frozentxo.cpp:137–164`, the waiver's return at 161–164 reads neither) |
| every input amount and their sum in `MoneyRange`; value in at least value out; the fee non-negative and in range | 2639–2643 `bad-txns-inputvalues-outofrange`; 2647–2652 `bad-txns-in-belowout`; 2654–2662 `bad-txns-fee-negative`, `bad-txns-fee-outofrange` | C |
| no input of a regular transaction is on the consensus blacklist at the block's height | 2595–2609 `bad-txns-inputs-frozen`: on the block path `REJECT_SOFT_CONSENSUS_FREEZE` (`consensus/validation.h:18`), off it `REJECT_INVALID` (2603–2605); `CFrozenTXOCheck` `frozentxo.h:21`, `Check` `:51`/`:60`, `IsCheckOnBlock` `:72`; `Check` `frozentxo.cpp:37–83`: a block consults only the consensus blacklist's entries active at its height (52–62, `IsFrozenOnConsensus(mHeight)`), the mempool the policy blacklist, which includes them (63–75); a block already in an explicit soft consensus freeze is not checked (39–42). The lists are the operator's, by RPC: `addToConsensusBlacklist` with its `enforceAtHeight` intervals (`rpc/frozentxo_rpc.cpp:346–377`), `addToPolicyBlacklist` the policy-only list (320); the rows `rpc/client_utils.cpp:133–134`. A frozen spend stops the connection and soft-freezes the block for `-softconsensusfreezeduration` blocks (3403–3408; `softConsensusFreeze` 3721–3741; `init.cpp:1180`, default `DEFAULT_SOFT_CONSENSUS_FREEZE_DURATION` = 3, `src/validation.h:219`; a duration of 0 disables the auto-unfreeze and the block is frozen indefinitely, `init.cpp:1184–1185`, the index's unfrozen value being -1, `block_index.h:398`, `block_index.h:569–574`); `InvalidBlockFound` does not mark such a block failed (2461–2471, the test at 2466) | operator-list mechanism |
| a confiscation transaction: valid contents and whitelisted at the block's height, else `REJECT_INVALID`; a permitted one bypasses the frozen-input check and the script loop | 2563–2588 `bad-ctx-invalid`, `bad-ctx-not-whitelisted` (`IsConfiscationTx` `frozentxo_db.h:572`, `ValidateConfiscationTxContents` `:584`; `CheckConfiscationTxWhitelisted` `frozentxo.h:100`, `frozentxo.cpp:133–171`: whitelisted and `mHeight >= enforceAtHeight` at 137–141); 2595 and 2610–2612 (the frozen-input check skipped for it); 2865–2870 (the script loop skipped); the whitelist by RPC `addToConfiscationTxidWhitelist` (`rpc/client_utils.cpp:137`). The depth-based waiver: under `-enableassumewhitelistedblockdepth` (default off, `policy/policy.h:99`) a block at least `-assumewhitelistedblockdepth` blocks (default 6, `policy/policy.h:101`) under the most-work block, or under the best header on its ancestor line, passes an unwhitelisted confiscation transaction with a logged warning (3530–3563; `frozentxo.cpp:161–164`; `init.cpp:1189–1197`) | operator-list mechanism |

The script layer never reads the UTXO set: an entry carries its prevouts (`docs/DESIGN.md` §6), and no theorem of
it speaks about existence, spentness, maturity, fees or the frozen lists (the state machine's `applyTx` does, #61).
The frozen-output and confiscation rows are the legend's third kind, by the maintainers' ruling of 2026-10-05: a
block-validity mechanism driven by an operator's list, named and cited, outside the script layer and a parameter
of the state machine (#70); neither a consensus rule nor policy.

### 2.2 Finality and locks: the block's height and median time past

| rule | `[SRC]` | kind |
|---|---|---|
| `IsFinalTx`: a non-zero `nLockTime` below `LOCKTIME_THRESHOLD` is a height, else a time; the transaction is final when the lock is below the limit or every input's `nSequence` is `SEQUENCE_FINAL` | 228–248; `script/script.h:36`; `primitives/transaction.h:99` | C |
| on the block path the limit is the block's height and, since `CSVHeight`, the previous block's median time past (BIP113), else the block's own time | `ContextualCheckBlock` 5999–6003, 6020–6022, 6025–6035 through `ContextualCheckTransaction` 5930–5949 `bad-txns-nonfinal`; `consensus/params.h:28`, mainnet 419,328 `chainparams.cpp:1046` | C |
| `ContextualCheckTransactionForCurrentBlock`: the next-block finality judge uses tip height + 1 and the tip's median time past under `LOCKTIME_MEDIAN_TIME_PAST`, else adjusted time; its non-final result routes through admission policy | [SRC] `src/validation.cpp:5998–6037` at `6504a3af` | C for the finality predicate; P for the hold |
| off the block path, after Genesis, a non-final transaction is not refused: it is routed to the non-final pool | 5936–5940; `CommitTxToMempool` 913–926; before Genesis the mempool refuses it, 5944 | P |
| BIP68 relative locks on the block path: `CalculateSequenceLocks`, `EvaluateSequenceLocks`, `SequenceLocks` under `nLockTimeFlags` | 256–325, 327–336, 338–342; in `ConnectBlock` 3337–3349 `bad-txns-nonfinal`; the flags 3465–3469 from `StandardNonFinalVerifyFlags(era)` (`policy/policy.h:248–256`: `LOCKTIME_VERIFY_SEQUENCE` only before Genesis) | C, before Genesis |
| BIP68 on the mempool path returns true after Genesis before computing anything | `CheckSequenceLocks` 363–436, the return at 371–375 | P |
| the median time past: the median of the times of the last `nMedianTimeSpan` = 11 blocks, fewer where the chain is shorter | `block_index.h:720` (the span), `722–737` (`GetMedianTimePast`) | C |

The spec's one SPEC-SIDE class, `tx.finality.out-of-scope` (`docs/CONFORMANCE-2026-09-27.md` §2, the sv-node
section), is this family: two entries of `corpus/tx` the reference refuses on the block road for finality while
the spec, which has no block, accepts their scripts.

### 2.3 Order, duplicates and the coinbase

| rule | `[SRC]` | kind |
|---|---|---|
| the leading transaction is the coinbase and no other transaction is one | `CheckBlock` 5743–5747 `bad-cb-missing`; `CheckCoinbase` 578–581; `CheckRegularTransaction` 601–603 `bad-tx-coinbase`; `IsCoinBase` `primitives/transaction.h:323–325` | C (the predicates are in `TxRules`; the position is the block's) |
| the coinbase script opens with the serialized height since `BIP34Height` | 6038–6054 `bad-cb-height`; `consensus/params.h:21`, mainnet 227,931 `chainparams.cpp:1038` | C |
| the coinbase pays at most the fees plus the subsidy | 3656–3662 `bad-cb-amount`; `GetBlockSubsidy` 2253–2264, 50 coins halving every `nSubsidyHalvingInterval` = 210,000 blocks (`chainparams.cpp:1037`) | C |
| no transaction overwrites an unspent one with the same id (BIP30), except the two historic blocks, matched by height and hash (91,842 and 91,880), and skipped once BIP34's block is an ancestor | 3071–3117 `bad-txns-BIP30`: the two exemptions 3071–3078 (height and hash both), the BIP34 shortcut 3089–3096, the switch `-disablebip30checks` 3098–3101 (`config.cpp:1988`), the check 3103–3117 | C, with a setting |
| the merkle root matches and the transaction list is not a mutated duplicate (CVE-2012-2459) | 5723–5737 `bad-txnmrklroot`, `bad-txns-duplicate`; `BlockMerkleRoot` `consensus/merkle.cpp:184–191` | C |
| topological order (a transaction before any spend of it) is checked only for a block at least `MIN_TTOR_VALIDATION_DISTANCE` = 100 blocks below the tip | `CheckBlockTTOROrder` 5593–5615; `ReceivedBlockTransactions` 5630–5642 `bad-blk-ttor`; `src/validation.h:345`, whose comment at 343 reads "This is a local policy and not a consensus rule" | P (a local policy, in the source's words) |

### 2.4 Size and sigops at the block level

| rule | `[SRC]` | kind |
|---|---|---|
| the serialized block is at most `GetMaxBlockSize()` | `CheckBlock` 5750–5771, `ContextualCheckBlock` 6011–6018 `bad-blk-length`; `config.cpp:242–246`; `-excessiveblocksize` (`SetMaxBlockSize` 226–240, never at or under `LEGACY_MAX_BLOCK_SIZE` 1 MB, `consensus/consensus.h:31`); the default `MAIN_DEFAULT_MAX_BLOCK_SIZE` = `INT64_MAX` (`policy/policy.h:39`; the comment at `policy/policy.h:28–31` names it a consensus rule) | C/setting |
| before Genesis, the block's sigops at most 20,000 per MB rounded up; per transaction at most 20,000 | `CheckBlock` 5793–5820 (the branch at 5805) `bad-blk-sigops` over `GetSigOpCountWithoutP2SH` 438–461; `GetMaxBlockSigOpsConsensusBeforeGenesis` `config.cpp:825–829`, `MAX_BLOCK_SIGOPS_PER_MB_BEFORE_GENESIS` `consensus/consensus.h:37`; in `ConnectBlock` 3352–3368 (the branch at 3353) with P2SH: `GetTransactionSigOpCount` 496–518, `GetP2SHSigOpCount` 463–494 (needs the UTXO set), `bad-txn-sigops`, `MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS` `consensus/consensus.h:47` (`config.cpp:2340–2343`) | C, before Genesis |
| after Genesis no sigops are counted on the block path | the branches `!IsProtocolActive(era, ProtocolName::Genesis)` at 3353 and 5805; the comments at 3352, 3480, 5795 and 5804 | C |

The spec counts sigops per script and per transaction (`lean/BsvScript/SigOps.lean`;
`TxRules.sigOpCountWithoutP2SH`, equal to the reference's walk by `sigOpCountPreGenesis_eq_sigOpCount`); the
block's sum and the P2SH count against spent outputs are outside it. The mempool's sigop cap is policy and in
`TxPolicy` (1238–1246 `bad-txns-too-many-sigops`; `docs/PARAMETERS.md` §4).

### 2.5 The header and the chain

| rule | `[SRC]` | kind |
|---|---|---|
| proof of work: the hash at or under the target, the target in range | `CheckBlockHeader` 5695–5706 `high-hash`; `pow.cpp:150–171`; `powLimit` `consensus/params.h:42`, mainnet `chainparams.cpp:1047` | C |
| the difficulty: `nBits` equals the required work: the DAA when the previous block's height is at least `daaHeight`, the EDA before; on mainnet the DAA governs from the block at height 504,032 | `ContextualCheckBlockHeader` 5897–5901 `bad-diffbits`; `GetNextWorkRequired` `pow.cpp:95–117`, the parent's height tested at 111, `GetNextCashWorkRequired` `256` (the DAA), `GetNextEDAWorkRequired` `22` (the EDA); `consensus/params.h:32`, mainnet `daaHeight` = 504,031 `chainparams.cpp:1068` | C |
| the timestamp above the previous median time past and at most `MAX_FUTURE_BLOCK_TIME` = 2 hours ahead | 5904–5906 `time-too-old`; 5909–5912 `time-too-new`; `block_index.h:31` | C |
| the block version at least 2, 3, 4 from the BIP34, BIP66, BIP65 heights | 5917–5925 `bad-version`; `consensus/params.h:21–26`; mainnet `chainparams.cpp:1038/1044/1042` | C |
| checkpoints: the chain matches the hard-coded hashes and forks before the last one are refused | `CheckIndexAgainstCheckpoint` 5859–5884 | setting (compiled in) |
| assumevalid: a block's script checks are skipped only when the block is an ancestor of both the configured block and the best header, the best header's chain work is at least `nMinimumChainWork`, and the block lies more than two weeks of proof-equivalent time below the best header | 3483–3518: the two ancestry tests 3495–3496, the chain-work test 3497, `fScriptChecks` = (`GetBlockProofEquivalentTime` ≤ 14 days) at 3512–3515; `defaultAssumeValid`, `nMinimumChainWork` `consensus/params.h:50–51` | setting |
| a header's parent is known and not invalid | `FindPreviousBlockIndex` 6062–6080 `prev-blk-not-found`, `bad-prevblk`; called from `AcceptBlockHeader` at 6125–6130 | C |
| a header the operator has invalidated is refused, and a header already known to be invalid is refused again | 6097–6102 `block is marked as invalid` (`IsBlockInvalidated` `config.cpp:934–937`; `-invalidateblock=<hash>` `init.cpp:1236`, loaded at `3108–3116`); 6106–6116 `duplicate` | setting (the operator's list); the node's record of its own earlier verdict |
| the genesis block's header is checked against the operator's invalidation list, then exempt from the remaining checks of `AcceptBlockHeader` | `IsBlockInvalidated` 6097–6102 runs on every hash, the genesis hash included, before the exemption; 6105 (`hash != hashGenesisBlock`) then exempts the block 6106–6143 (the duplicate, header, parent, checkpoint and contextual checks), closing at 6144 | C (the exemption); setting (the invalidation list, the row above) |
| the genesis block's transactions are never connected | 3041–3051 | C |

The activation heights are parameters of the spec's semantics (`docs/PARAMETERS.md` §3; `consensus/params.h:17–52`,
`chainparams.cpp:18/23` for Genesis and Chronicle); which chain is the tip, and so which height a spend has, is
the node's.

### 2.6 The mempool beyond the spec's policy gate (`TxnValidation` 1010 onward; all policy)

The fee floor (1292 `REJECT_INSUFFICIENTFEE`), the absurd-fee ceiling (1252), the non-final pool's caps (1124,
1136), the duplicate and conflict refusals (1145, 1152), the input-size cap (1175), the validation-time wall
(1216, 1232), the grace-period re-check across an activation (`flexible-` 1044–1054), the standardness of inputs
(1221) `[SRC]`. None is in the spec; the standardness tests and the two caps are (§1). The policy defaults that
differ between the two node implementations are findings in `docs/PARAMETERS.md` §5.

## 3. What a node team checks for itself before relying on the spec

1. That its block path calls the script verdict with exactly §1's inputs: the block word at the tip's
   successor's era, the per-input flags from the spend's and the coin's eras, a mempool coin at the tip's
   successor, the limits from its configuration (2693–2703, 2973–2982) `[SRC]`. The spec decides nothing it
   is not handed.
2. That every rule of §2 is its own reading of its reference at its own pin, with its own chain parameters. The
   spec says nothing about the UTXO set, fees, maturity, finality, order, size, sigop sums, headers or chain
   selection, and a conformance claim here names the corpus and the run (`docs/CONFORMANCE-2026-09-27.md`),
   at the script verdict and the transaction-level gate, in the columns `spec` and `spec-mempool`.
3. That finality is applied outside the script: the opcodes compare operands with `nLockTime` and `nSequence`
   (§1); `IsFinalTx` and the sequence locks (§2.2) decide against the chain.
4. That the consensus values it sets are set: the block size and the stack memory budget are consensus rules
   whose values are the operator's (§2.4; `docs/PARAMETERS.md` §1). A node with a lower block size than its
   peers rejects their blocks (`policy/policy.h:28–31`).
5. That the frozen and confiscation lists, if it runs them, are its own: an operator-list mechanism off the
   spec's path (§2.1).
6. That the heights it passes are the heights of its chain (§2.5): the spec's eras are functions of them.

*Update rule: a rule added to the reference at a later pin is added here with its citation the week after the
recon reports it (`CLAUDE.md` rule 18); a rule the spec later models moves from §2 to §1 in the same commit.*
