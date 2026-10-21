# DESIGN S6: the transaction state machine (#58; written 2026-10-12)

Issue numbers on this page are the archived tracker's ([docs/GLOSSARY.md](GLOSSARY.md), "archived #n").

**What this page is.** The design note #36 asked for and the maintainers chartered on 2026-10-07 (#58): the
transaction state machine as bitcoin-sv runs it, written down so that S6 (#59 to #77) can implement it in the
discipline the script layer already has (executable, cited at the pin, judged by a corpus; `CLAUDE.md` rules 1
to 4). It states the state (§1), the transitions (§2), the derived status of a transaction (§3), the module map
(§4), the oracle plan (§5), the plan for S6 against the script layer's measured velocity (§6), the amendments of
the constitution's pages (§7) and the maintainers' card (§8). `docs/BLOCK-CONSENSUS.md` stays the record of where the
script verdict ended as of 2026-10-05; this page is where the machine around it begins.

**The reference and the citation form.** The reference is bitcoin-sv **v1.2.3** at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`
(`docs/PROVENANCE.md` §1). **A bare line number is a line of `src/validation.cpp` at that pin `[SRC]`**; every
other file is named by its path under `src/` in the form `docs/PROVENANCE.md` §2 uses (`txmempool.cpp`,
`consensus/merkle.cpp`, `block_index.h`; `validation.h`, a name two directories hold, is written `src/validation.h`,
and `consensus/validation.h` is the other). Teranode is **v0.16.0** at `4edb60a40c6628ff0ef60231c2628efd7103fde5`,
cited by its path under the repository root and read with `git show v0.16.0:<path>`. Every bitcoin-sv line below
was verified by a public read of the file at the pin through the GitHub contents API on 2026-10-12 (the table in
§9: the URL form, the time, the blob's sha); a line this note could not verify is marked `[D]` with the reason.
A verified citation locates the object it names (the blob's hash, the function's line); it does not by itself
validate the sentence around it, which the corpus judges (rule 4).
Where the issues #58 to #77 cite a line this note found elsewhere, §9 says so. The kinds of a rule are the legend
of `docs/BLOCK-CONSENSUS.md` §2: **C** a consensus rule · **C/setting** a consensus rule whose value the operator
sets · **setting** a node's own switch on the block path · **P** policy, the node's · **operator-list mechanism**
the third kind (the maintainers' ruling of 2026-10-05). A policy limit enters only as a named parameter with its
default and its source (rule 1); §4.2 lists them and #59's census carries their rows.

## 0. The answer in one block

> **The persistent state** contains the UTXO view, the accepted and side pools with the policy history needed for
> their next transition, the header/body tree and active chain, operator-list data, pending validation work, and
> the spec's observation journals; a temporary disconnect pool is threaded through reorganization steps (§1).
> **The transitions** are the charter's five, written as eleven signatures (§2): receive a transaction (accept,
> hold, orphan or reject it, or defer it), accept a block's header and body, connect a block to the tip, disconnect
> the tip, select the active chain (with the operator's invalidate and reconsider), and the time-driven
> maintenance. Each is a total function of the state, the chain parameters, the node's configuration, the script
> oracle and the time; none reads a clock or a network (#77). **A transaction's status is a function of the state and its id** (§3):
> unknown, orphan, in mempool, held non-final, mined at height *h* on the active chain, on a stale branch,
> conflicted by a mined spend, or rejected with a code; every value has the reference's observable beside it.
> **The script layer is the per-input oracle** of this machine under the UTXO's era (DESIGN §3 Q3; #76): the
> machine calls `Eval.verifyScript` and never re-reads a script rule. **The judge** is SV-node regtest driven
> through scenarios (chains, branches, double spends; #66); Teranode is the second oracle whose defaults are
> never the rule (§5). A disagreement is a scenario, never a sentence (rule 4).

## 1. The state

### 1.1 The UTXO set

The reference's coin is `Coin` (`coins.h:204–239`): the amount, the creation height and the coinbase flag packed
in one word (`nHeightAndIsCoinBase`, `:213`, `GetHeight` `:229–232`, `IsCoinBase` `:233`), the confiscation flag
(`:234`) and spentness as the sentinel amount −1 (`:235`); `CoinWithScript` (`:263–342`) carries the output's
script with it `[SRC]`. The set is a map from `COutPoint` to a cache entry (`CCoinsMap`, `coins.h:399`) behind
the view interfaces `ICoinsView` (`:408`), `CoinsStore` (`:453`), `ICoinsViewCache` (`:510`) and `CCoinsViewCache`
(`:538`); the tip's database is `pcoinsTip` (`src/validation.h:1135`) and the view remembers which block it is the
set of (`SetBestBlock`, `processing_block_index.cpp:74`; asserted against the parent on connection, `3034–3036`)
`[SRC]`. Spending removes an entry and creating adds one; undo restores (§2.3).

The spec: `Coin := {value : Nat, script : Bytes, height : Nat, isCoinbase : Bool, isConfiscation : Bool}` and
`UtxoSet := Map OutPoint Coin` with the best block's hash beside it *(design)*. The executable map and the map the
theorems speak about are tied by a refinement, the pattern #50 set for the machine (`BsvScript.Impl`): the proofs
name the definition, the evaluator runs the copy.

### 1.2 The mempool, with its orphan and non-final pools

The reference's pool is `CTxMemPool` (`txmempool.h:421`): the entries `mapTx` (`:483`, a `CTxMemPoolEntry` `:136`:
the transaction, its fee, its entry time, the height at entry and whether it spends a coinbase or a confiscation
output, as `TxnValidation` constructs it at `1301–1309`), the spent-outpoint index `mapNextTx` (`:562`; `IsSpentNL`
`txmempool.cpp:297–298`), the non-final pool `mTimeLockedPool : CTimeLockedMempool` (`:457`, `getNonFinalPool`
`:805`; the class `time_locked_mempool.h:34`: `addOrUpdateTransaction` `:49`, `finalisesExistingTransaction` `:57`,
`checkForDoubleSpend` `:61`, `checkUpdateWithinRate` `:64`, `exists` `:67`), and the mining journal (`:454`, the
assembler's view of the pool, outside this machine: #72 observes the block it yields) `[SRC]`. Two structures that
decide a transaction's fate live beside the pool, in the validator: the orphan pool `COrphanTxns`
(`orphan_txns.h:26`; `addTxn` `:72`, `eraseTxn` `:76`, `checkTxnExists` `:82–84`, `limitTxnsSize` `:94`,
`collectDependentTxnsForRetry` `:96`; reached by `CTxnValidator::getOrphanTxnsPtr` `txn_validator.cpp:91`) and the
recent-rejects filter `CTxnRecentRejects` (`txn_recent_rejects.h:20`: a rolling bloom filter, `insert` `:32`,
`isRejected` `:34`, `reset` `:36`; membership only, no code is kept; reset by the next inventory test that
observes a tip hash other than the one it recorded, `net/net_processing.cpp:930–942` with the comment at
`txn_recent_rejects.h:41–44` and `net/net.cpp:3563–3564`) `[SRC]`. The double-spend detector `CTxnDoubleSpendDetector`
(`txn_double_spend_detector.h:23`; `insertTxnInputs` `:42`, `removeTxnInputs` `:53`) is the final conflict check,
run while its own lock is held after validation (`txmempool.h:1380–1389`, the comment that names the two call
sites) `[SRC]`.

The spec *(design)*:

```
Mempool := {accepted : Map TxId Entry, spent : Map OutPoint TxId, nonFinal : Map TxId Entry,
            orphans : Map TxId OrphanEntry, recentRejects : Set TxId, recentRejectsTip : Option BlockHash,
            rollingFee : {rateBits : BitVec 64, lastUpdate : Time, blockSinceBump : Bool},
            orphanControl : {nextSweep : Time, untrimmedBytes : Nat},
            feeDeltas : Map TxId Int, nonFinalRate : RateHistory, pending : List PendingWork}
Entry        := {tx, fee, time, height, spendsCoinbaseOrConfiscation, primary : Bool, cpfpGroup : Option GroupId}
OrphanEntry  := {request : TxRequest, expiresAt : Time, size : Nat}
PendingWork  := {request : TxRequest, enqueued : Time}
```

`rateBits` encodes the reference's retained binary64 rolling rate, not its truncated fee. #62 defines executable
decay and rounding with a stated correspondence to `txmempool.cpp:2624–2647`. It also models orphan sweep and
hysteresis state, the accounting used by `DynamicMemoryUsageNL`, and the ordering choices that affect eviction and
retries. Deferred work retains the complete request, including its per-call overrides.

`Mempool` contains the accepted, non-final and orphan maps and the spent-outpoint index, plus the rolling-fee
state (`rateBits`, `lastUpdate`, `blockSinceBump`: `txmempool.h:448–451`, the rate a retained `double` at `:451`, decayed by time and memory usage at
`txmempool.cpp:2624–2647` and raised by `TrimToSize` at `:2779–2790`), the fee deltas (`PrioritiseTransaction`,
applied at `1258`), the pool classification and the accounting used for eviction (primary or secondary, the CPFP
group: `evaluateEvictionCandidateNL` `txmempool.cpp:2650–2666`), the non-final replacement-rate history
(`checkUpdateWithinRate`, `time_locked_mempool.h:64`), the orphan expiration metadata (`orphan_txns.h:27–30`) with
the sweep and trim-accounting state (`mNextSweep`, `mUntrimmedSize`: `orphan_txns.h:146–150`, read at
`orphan_txns.cpp:175–224`) and the salted iteration order that eviction and retry read (`orphan_txns.h:114–118`;
`orphan_txns.cpp:227–241`, `:288–301`), and the pending validation work as the retained request with its source,
priority and per-call configuration (`txn_validator.cpp:567–578`, `:633–640`; `txn_validation_data.h:54–64`,
`:169–177`) `[SRC]`. Two histories with equal
maps and an equal UTXO set can differ in their next admission verdict through the rolling fee after an eviction;
that is why the fee state is a field. #62 gives these fields their executable representations and cites their
initialization and updates; #71 supplies the reject-filter and timeout state. An ideal recent-reject set is a
declared abstraction of a rolling probabilistic filter (`txn_recent_rejects.cpp:9–11`): filter rollover and
false-positive observations are either modeled with explicit inputs or marked non-judging, never silently
classified as disagreements (#71: `RejectFilter.wipeFree`, `InventoryObservation.filterFalsePositive` and
`removedFalsePositive`, `filterJudgment` and `inventoryJudgment` over both rolling filters in `BsvChain/Rejects.lean`). The detector is not a state: it is the atomic form of `spent`'s check, and the
spec's `accept` is one atomic step. The journal is not a state of the machine; the assembler's choice is observed,
never predicted (#72).

### 1.3 The header tree with accumulated work

The reference's node is `CBlockIndex` (`block_index.h:289`): the parent `pprev` (`:330`), the height (`:336`), the
accumulated work `nChainWork` (`:349`), computed as the parent's work plus this block's proof (`:663–664`;
`GetBlockProof` `block_index.cpp:114–127`: `(~target / (target + 1)) + 1`), the status (`:364`), the arrival order
`nSequenceId` (`:375`), the median time past over the last `nMedianTimeSpan` = 11 block times (`:720`, `:722–737`)
`[SRC]`. The status is a validity level and flags (`BlockValidity` `block_index.h:41–79`: HEADER 1, TREE 2,
TRANSACTIONS 3, CHAIN 4, SCRIPTS 5; `BlockStatus` `:83–115`: HAS_DATA, HAS_UNDO, FAILED, FAILED_PARENT, the
soft-rejection, double-spend and soft-consensus-frozen marks `:107–111`; `INVALID_MASK` `:115`) `[SRC]`. The tree
is `mapBlockIndex` (`90`), the candidate set for the tip `setBlockIndexCandidates` ordered by `CBlockIndexWorkComparator`
(`170`), the active chain `chainActive : CChain` (`src/validation.h:1131`; `chain.h:17`: `Tip` `:34`, `Contains` `:54`,
`Height` `:73`, `SetTip` `:80`, `FindFork` `:91`), the best header `mapBlockIndex.GetBestHeader()` (`3493`), and
per connected block its `CBlockUndo` (`undo.h:109–112`), containing `CTxUndo` records of the spent coins with their
scripts (`undo.h:80–83`; written by `writeUndoToDisk` at `3209–3215`; the forward declaration #64 cites is
`block_file_access.h:17`) `[SRC]`.

The spec: `Node := {header : BlockHeader, height : Nat, chainWork : Nat, validity : Validity, failed : Bool,
failedParent : Bool, txs : Option (List Tx), undo : Option Undo, seq : Nat, validationCompletion : Option Nat,
tieRank : Nat}` and
`HeaderTree := {nodes : Map BlockHash Node, active : Array BlockHash, candidates : Set BlockHash, bestHeader : BlockHash}`
*(design)*. `validationCompletion` is the reference's tie breaker among equal-work candidates, the moment a block's
validity reached SCRIPTS (`block_index.h:823–827` the getter, `:954` the member, set at `:1073–1077`); `seq` is
the arrival order (`:375`, set at `5702–5704`); the comparator reads work, then completion time, then sequence id,
then the pointer address (`CBlockIndexWorkComparator`, `block_index.h:1225–1274`), and `tieRank` is the explicit
stand-in for that last, unreproducible step (§2.4) `[SRC]`. The soft-rejection, soft-freeze and safe-mode marks
are settings' marks and enter as fields only when #64 and #73 model the switches that set them.

### 1.4 The spec's own bookkeeping (design)

Two of the eight statuses of §3 are not readable from any structure of the node after the fact: a rejection
(the node keeps a bloom filter and sends the code once, `1934–1941`) and a conflict by a mined spend (the node
removes the loser from the pool, `txmempool.cpp:1091–1117`, and keeps nothing of it). So that `status` is total
over the spec's state, the machine keeps two journals *(design)*. `seen : Map TxId Tx` stores the transaction
bodies observed in submissions and in block bodies. `rejected : Map TxId Reject` stores the latest completed
rejection for an id, including its submission channel and its code and reason namespace (`RejectCode`, §3); a
later completed accepted, held or orphan verdict clears that rejection. Deferred work fabricates no completed
rejection. Updating either journal is specified alongside every transition that observes a body or completes a
validation. These are spec and harness journals; the reference exposes no persistent rejection-code database, and
§3 names the observable that witnesses each value through them; #67 states which client vocabularies rest on the
same bookkeeping.

### 1.5 The state record

`State := {utxo : UtxoSet, mempool : Mempool, headers : HeaderTree, seen, rejected, frozen : FrozenLists}`, with
`frozen` the operator's lists of #70 (`CFrozenTXOCheck`, `frozentxo.h:21`), the third kind, a parameter never a rule
*(design)*. The chain parameters (`ChainParams`, per network: #69) and the node's configuration (`NodeConfig`,
extended by #59) are arguments of every transition, as is the time `now`; none is a field (#77). A temporary
disconnect pool (`DisconnectedBlockTransactions`, `txmempool.h:1455–1500`) is threaded through `disconnectBlock`
and the activation steps until re-admission, never a field (§2.3, §2.4).

**What remains to establish.** This is a proposed state representation, not a proved account of every next
observation. #62 completes the rolling-fee representation and rounding, memory accounting, orphan sweep/hysteresis
state, retained request data, and eviction/retry ordering. #66 records explicit completion and ordering inputs
where observable, or restricts judging scenarios so those choices cannot affect the result; an unresolved choice
is non-judging. #71 specifies the reject filter's rollover and false-positive abstraction. The pointer-address
fallback (`block_index.h:1263–1270`) and filter behavior (`txn_recent_rejects.cpp:9–11`) remain observation limits,
but they are not the only obligations. A claim that the state determines the reference's next observation waits
for these representations and their scenario evidence.

## 2. The transitions

Each transition is a signature over the state, then the reference's function with its checks in order, then the
consensus-versus-policy line (rule 1). `oracle : ScriptOracle` is the per-input script verdict (#76; §4.3);
`params : ChainParams`; `cfg : NodeConfig`; `now : Time`. The signatures, one contract (the types are schematic,
defined by the issues each subsection names) *(design)*:

```text
receiveTx         params cfg oracle now        : State → TxRequest → State × TxOutcome
receiveHeader     params cfg now               : State → BlockHeader → State × HeaderVerdict
acceptBlock       params cfg now               : State → BlockRequest → State × BlockVerdict
receiveBlock      params cfg oracle now        : State → BlockRequest → State × BlockVerdict
applyTx           params cfg oracle now height : UtxoSet → Tx → Except Reject (UtxoSet × TxUndo)
connectBlock      params cfg oracle now depth  : State → Block → State × ConnectOutcome
disconnectBlock   params cfg now               : State → DisconnectPool → State × DisconnectPool × DisconnectOutcome
activateBestChain params cfg oracle now        : State → State × ActivationOutcome
invalidateBlock   params cfg oracle now        : State → BlockHash → State × ActivationOutcome
reconsiderBlock   params cfg oracle now        : State → BlockHash → State × ActivationOutcome
advanceTime       params cfg oracle now        : State → MaintenanceEvent → State × MaintenanceOutcome
```

`TxRequest` carries the transaction, its source (`TxSource`: RPC, P2P, reorg; `rpc/rawtransaction.cpp:1590`,
`txmempool.cpp:2385`), its priority and the per-call fee and validation overrides (`allowhighfees`,
`rpc/rawtransaction.cpp:1571–1573`); `BlockRequest` carries the body and its requested-or-forced-processing metadata
(`fRequested`, `6238–6243`). `TxOutcome` distinguishes a completed accepted, held, orphan or rejected verdict from
a deferred or suppressed submission; #71's priority downgrade is not a rejection. `DisconnectOutcome` keeps OK,
UNCLEAN and FAILED (`processing_block_index.cpp:79–96`). Activation threads the disconnect pool until re-admission
and returns the resulting state even on failure (`5250–5255`: a failed disconnect still empties the pool of the
disconnected transactions). Every transition accepts `now` and `params` as #77 requires; an input a transition does
not need is ignored. Maintenance events make expiry, retry and the periodic non-final checks explicit. A budget
expiration is an explicit non-judging event, never inferred from a single timestamp.

### 2.1 Receive a transaction: accept, hold, orphan or reject

`receiveTx` (the contract above) with `TxOutcome := completed (v : TxVerdict) | deferred | suppressed` and
`TxVerdict := accepted | heldNonFinal | orphan | rejected (code : RejectCode) (reason : String)`, `RejectCode`
as §3 defines it *(design)*.

The reference: `TxnValidation` (`1009–1538`) returns a `CTxnValResult` (`txn_validation_result.h:14–20`: the
state, the input data, the coins to uncache, the pool entry); `ProcessValidatedTxn` (`1759–1865`) routes it;
`CommitTxToMempool` (`895–946`) stores it `[SRC]`. The checks, in the reference's order:

| # | check | `[SRC]` | verdict when it fails | kind |
|---|---|---|---|---|
| 1 | `CheckRegularTransaction` at the era of the tip's successor, with the consensus size and the pre-Genesis sigop limit | `1031–1035`; the Genesis grace re-check `1040–1052` (`flexible-` prefixed, no ban) | the gate's reason, `REJECT_INVALID` | C (the spec's `TxRules`) |
| 2 | `IsStandardTx` at the tip's successor | `1070–1074`, refused at `1080–1088` under `-acceptnonstdoutputs` and `requirestandard` | `REJECT_NONSTANDARD`, the standardness reason | P (`BsvScript.Standard`) |
| 3 | finality at the tip: `ContextualCheckTransactionForCurrentBlock` (`5998–6037`) → `IsFinalTx` (`227–247`) at height tip + 1 against the signed 32-bit narrowed median time past under `LOCKTIME_MEDIAN_TIME_PAST` (the `int` parameter at `6002`, caller and suppression at `1101–1106`), else full-width adjusted time (`6026–6028`); off the block path after Genesis a non-final transaction is not refused (`5984–5989`) | `1093–1138` | held: `SetNonFinal` (`1118`); refused when the non-final pool's memory is 0 (`1119–1123` `non-final-pool-full`, `REJECT_MEMPOOL_FULL`), over the replacement rate (`1127–1130`) or spending another non-final transaction (`1133–1137` `too-long-non-final-chain`) | P for this tip judge, hold and pool caps; the C block path retains its full-width median and cutoff (`6042–6056`, `6067–6074`) |
| 4 | already in the pool | `1141–1145` | `txn-already-in-mempool`, `REJECT_ALREADY_KNOWN` | a node fact |
| 5 | `CheckTxConflicts`: accepted `mapNextTx` locks refuse the competing spend and retain the accepted spender; non-final locks conflict only when `isFinal` is true and `finalisesExistingTransaction` is false. A valid non-final update removes the old held transaction and replaces it, or queues full revalidation if finalised | `1147–1152`; `txmempool.cpp:2257–2280`; `time_locked_mempool.cpp:67–85,114–156` [SRC] | `txn-mempool-conflict`, `REJECT_CONFLICT` for a conflict; held updates follow their separate commit checks | P |
| 6 | the inputs: `HaveInputsLimited` under `-maxcoinsviewcachesize` (`1168–1175` `bad-txns-inputs-too-large`); missing inputs with the outputs already known is `txn-already-known` (`1180–1183`), else `SetMissingInputs` (`1184–1185`) | `1156–1192` | the ORPHAN road: a p2p transaction goes to the orphan pool unless a parent is in recent rejects (`1790–1794` → `2018`, `HandleOrphanAndRejectedP2PTxns` `1888–1932`; the pool capped by `-maxorphantxsize`, `1904–1912`); any other source with an orphan handler goes there too (`1795–1796`) | P (a structure of the node) |
| 7 | BIP68 at the tip, `CheckSequenceLocks` (`362–436`, true after Genesis before computing anything, the return at `371–375`) | `1199–1207` | `non-BIP68-final`, `REJECT_NONSTANDARD` | C before Genesis; a no-op after |
| 8 | the inputs' standardness, `AreInputsStandard`, under the validation budget | `1210–1240` | `bad-txns-nonstandard-inputs`; a timeout `too-long-validation-time` with `SetValidationTimeoutExceeded` | P; time (#71) |
| 9 | the sigop policy cap | `1241–1252` | `bad-txns-too-many-sigops` | P (`BsvScript.TxPolicy`) |
| 10 | the fee: `nFees = valueIn − valueOut` (`1249`); the absurd-fee ceiling (`1250–1254` `absurdly-high-fee`, `REJECT_HIGHFEE`); the consolidation handling (`1267–1277`); the pool's minimum fee `GetMempoolRejectFee` (`1285–1294`; `GetMempoolRejectFee` `763–769` over the rolling minimum `GetMinFee` `txmempool.cpp:2624–2647`) | `1249–1294` | `mempool min fee not met`, `REJECT_INSUFFICIENTFEE` | P |
| 11 | the entry (`1301–1309`) and the ancestor limits (`1313–1318`) | `1313–1318` | `too-long-mempool-chain`, `REJECT_NONSTANDARD` | P |
| 12 | the scripts under the relay word: `CheckInputs(…, consensus = false, …)` (`1328–1348`), inside it `Consensus::CheckTxInputs` (`2552–2665`: inputs exist and are unspent `2557–2559`; the frozen row `2595–2609`; coinbase maturity `COINBASE_MATURITY` = 100 `2617–2625`, `consensus/consensus.h:75`; confiscation maturity `2628–2636`; values and the fee `2639–2662`) then per input `CheckInputScripts` (`2676–2720`: the UTXO's era from the coin's height, a mempool coin at the tip's successor `2668–2675`, the per-input contribution `InputScriptVerifyFlags(era, utxoEra)` at `2696`, combined with the caller's word at `2701` and `2707`, and the limits from `make_verify_script_params` at `2701`): **the oracle's call site on the relay path**; the Chronicle grace re-check `1357–1392`; then the re-check under the block word `1411–1431` (`CheckInputsFromMempoolAndCache` `657`, called at `1414`) and the mandatory flags `1444–1457` (`MandatoryScriptVerifyFlags(era)` `1453`) | `1320–1482` | the script error as `blk-bad-inputs`-style reasons through `CScriptCheck`; the gate's reasons | C for `CheckTxInputs` and the block word (P5, `docs/DESIGN.md` §9); P for the relay word's extra flags; operator-list mechanism for the frozen row |
| 13 | the detector's final insertion | `1484–1494` | `txn-mempool-conflict` or `txn-double-spend-detected` (`REJECT_DUPLICATE`) | P |
| 14 | commit: a non-final transaction, or one that finalises a held one, goes to the non-final pool (`912–926`); else `AddUnchecked` (`928–936`) then `LimitMempoolSize` (`938–945`; `TrimToSize` `txmempool.cpp:2704–2800` evicts the least worthy with descendants until under `-maxmempool`, and raises the rolling minimum fee `2779–2790`) | `895–946` | `mempool full`, `REJECT_INSUFFICIENTFEE` when trimmed out | P |

After the verdict: an accepted transaction leaves the orphan pool and its dependents are re-queued for validation
(`1855–1858`; `scheduleOrphanP2PTxnsForReprocessing` `txn_validator.cpp:695–724`): **an orphan whose parent
arrives is re-evaluated, never accepted on arrival** (#62). A rejection that validation itself returns for a
peer's fully processed request, and that is not a possible corruption, enters the recent-rejects filter
(`1786–1797`, `1988–1995`, `2043–2048`); a refusal by the commit (row 14) is reached on the validated branch and
is not remembered (`1808–1836`, `2097–2136`; #71). Either is answered once with a reject message (`CreateTxRejectMsgForP2PTxn` `1934`, sent only for a code below `REJECT_INTERNAL`, `1941`;
the internal codes `REJECT_HIGHFEE` 0x100, `REJECT_ALREADY_KNOWN` 0x101, `REJECT_CONFLICT` 0x102,
`REJECT_MEMPOOL_FULL` 0x103, `src/validation.h:1157–1163`, never cross the wire; the wire codes are
`consensus/validation.h:14–24`). A validation timeout on a high-priority transaction lowers its priority instead
of answering (`txn_validator.cpp:634–641`; #71). Expiry removes entries older than `-mempoolexpiry` with their
descendants (`Expire`, `txmempool.cpp:2201–2221`); time is an argument of the transition (#77) `[SRC]`.

**Consensus and policy on this transition.** On receipt, distinguish the predicates block validation reuses from
admission policy. The transaction gate, the input availability, maturity and value rules, absolute finality, the
applicable sequence locks and the script verdict under the block word are consensus predicates at the configured era
(rows 1, 3, 7 and 12). Holding a non-final transaction, the relay-only flags, conflict admission, the fee floors and
ceilings, the resource budgets and the pool limits are policy, each a parameter of §4.2 with its row in #59's census.
The operator-list checks keep their separate kind. A mempool refusal by itself establishes no block-invalidity claim.

### 2.2 Receive a block: the header, the body, the connection

`receiveHeader`, `acceptBlock` and `receiveBlock` (the contract above): `receiveBlock` is `acceptBlock` followed
by `activateBestChain` (§2.4), as `ProcessNewBlock` (`6509–6525`) is `AcceptBlock` then `ActivateBestChain`;
`acceptBlock` begins with header acceptance (`AcceptBlockHeader` called at `6254`), so it reads `now` through
`receiveHeader`, and its request carries the requested-or-forced metadata the unrequested-block gates read
(`fRequested`, `6238–6243`) *(design)*. The inner step on the UTXO set is `connectBlock` (the contract above;
`depth` is #73's validation depth), the reference's `ConnectBlock` (`3775–3805`, a wrapper over
`BlockConnector::Connect`, `2994–3730`), which requires the block's parent to be the tip (`3034–3036`) `[SRC]`.

**The header** (`AcceptBlockHeader` `6134–6197`): the operator's invalidation list (`6144–6149`, setting);
duplicate (`6152–6164`); proof of work `CheckBlockHeader` (`6167`; `5736–5747` → `CheckProofOfWork`
`pow.cpp:150–171`: the target in range and at most `powLimit`, the hash at most the target); the parent known and
not invalid (`6172–6177`, `FindPreviousBlockIndex` `6109`); checkpoints (`6179–6184`, setting); the contextual
checks (`ContextualCheckBlockHeader` `5933–5975`): `nBits` equals `GetNextWorkRequired` (`5942–5947` `bad-diffbits`;
`pow.cpp:95–117`: the genesis case, `fPowNoRetargeting` returns the parent's bits `107–109`, the DAA from
`daaHeight` `111–113` → `GetNextCashWorkRequired` `256`, the EDA before it `116` → `GetNextEDAWorkRequired` `22`),
the time above the parent's median time past (`5950–5953` `time-too-old`) and at most adjusted time plus
`MAX_FUTURE_BLOCK_TIME` = 2 h (`5956–5959` `time-too-new`; `block_index.h:31`; the one place wall time enters a
rule, `6187` `GetAdjustedTime()`), the version floors from the BIP34, BIP66 and BIP65 heights (`5964–5972`);
then `AddToBlockIndex` (`6193`; `5564–5575`): the node with its chain work `[SRC]`. All C except the two settings.

**The body** (`AcceptBlock` `6238–6416`): the unrequested-block gates (`6309–6332`: less work than the tip `6281–6283`, `6316`; too
far ahead by `-minblockstokeep` `6289–6290`, `6321`; below `nMinimumChainWork` `6329`; settings, #73); `CheckBlock` (`5749–5901`):
the merkle root and the duplicate-transaction flag (`5770–5781` `bad-txnmrklroot`, `bad-txns-duplicate`;
`BlockMerkleRoot` `consensus/merkle.cpp:312–319` over `ComputeMerkleRoot` `247–282`, the `mutated` flag from the
sibling rule `210–213` and `278–279`, and the duplicate-subtree explanation at `consensus/merkle.cpp:18–50`),
the empty-body gate (`src/validation.cpp:5788–5791` `bad-cb-missing`), the early transaction-count bound
(`5801–5805`) and serialized size against `GetMaxBlockSize()` (`5795`, `5809–5815` `bad-blk-length`;
`-excessiveblocksize`, C/setting), then `CheckCoinbase` (`5823–5827`). The transaction loop adds the current
transaction's pre-Genesis sigops to the running sum (`5853–5866` `bad-blk-sigops`), advances (`5867–5871`),
and calls `CheckRegularTransaction` on the next transaction (`5877–5889`) before counting that transaction's
sigops on the next iteration; these checks are interleaved [SRC] at `6504a3af`.
`ContextualCheckBlock` (`6039–6107`): the size again (`6058–6065`), every transaction final against the block's
cutoff, the previous median time past from `CSVHeight` else the block's own time (`6046–6050`, `6067–6074`;
`ContextualCheckTransaction` `5977–5991`, `bad-txns-nonfinal`), the coinbase's height push from `BIP34Height`
(`6085–6099` `bad-cb-height`); then `ReceivedBlockTransactions` (`5662–5733`): the TTOR check for a block at least
`MIN_TTOR_VALIDATION_DISTANCE` = 100 below the tip (`5671–5682`; `CheckBlockTTOROrder` `5634–5655`;
`src/validation.h:350`, "a local policy and not a consensus rule" in the source's words), the chain-transaction
count and the sequence id (`5701–5705`), the candidate set (`5706–5710`) or the unlinked map when a parent's
body is missing (`5719–5723`) `[SRC]`.

**The connection** (`BlockConnector::Connect` `3021–3719`): `CheckBlock` again (`3025–3032`); the genesis block's
transactions never connected (`3041–3051`); BIP30 (`3061–3117`: the two historic heights and hashes `3070–3078`,
the BIP34 shortcut `3092–3094`, `-disablebip30checks` `3097–3100` on a chain that allows it, `config.cpp:2051–2068`,
`bad-txns-BIP30` `3108–3109`); the flags of the block: `nLockTimeFlags` from `StandardNonFinalVerifyFlags(era)`
(`3467`) and the script word `GetBlockScriptFlags(config_, pindex_->GetPrev())` (`3472`; `2972–2981`: the era of
the tip's successor); assumevalid (`3482–3518`: `fScriptChecks` false only under the configured hash, the best
header's work at least `nMinimumChainWork` and two weeks of proof-equivalent time; setting, #73); then per
transaction, sharded by input set (`3290–3416`): every input present and unspent (`3327–3331`
`bad-txns-inputs-missingorspent`), BIP68 `SequenceLocks` against the coins' heights (`3337–3349`
`bad-txns-nonfinal`), the pre-Genesis sigop counts with P2SH (`3352–3368`), the fee tally (`3371–3373`),
`CheckInputs(…, consensus = true, …)` (`3376–3392`): `CheckTxInputs` again and the per-input `CScriptCheck`s
queued (**the oracle's call site on the block path**), a soft consensus freeze when the frozen row answers
(`3402–3407`; `softConsensusFreeze` `3720–3741`; `-softconsensusfreezeduration` default 3,
`src/validation.h:219`), the queued checks added or run (`3413–3434`, `blk-bad-inputs` `3429–3430`); the coinbase at most the fees plus
`GetBlockSubsidy` (`3655–3668` `bad-cb-amount`; `2252–2263`); the undo written (`3203–3222`); the parallel
checks' outcome (`3681–3718`) `[SRC]`. Then `ConnectTip` (`4249–4412`) flushes the view, removes the block's
transactions and every pool transaction that spends what the block spent, with descendants
(`mempool.RemoveForBlock` `4345–4357`; `txmempool.cpp:1025–1173`, the conflict branch `1091–1117`), moves the tip
(`UpdateTip` `4013–4034`); at a Genesis or Chronicle successor-era crossing,
`FinalizeEraCrossing` (`4036–4053`, called at `4404`, and before undo at `4073` on disconnect)
clears accepted entries, links and rolling-fee state while retaining held/orphan stores and fee deltas
(`src/txmempool.cpp:1345–1363`) [SRC] at `6504a3af`.

**Consensus and policy.** Consensus predicates; the two C/setting resource bounds (the block size, the stack memory
through the oracle); the BIP30 test switch (`-disablebip30checks`, §4.2; policy node setting, default false; the resolved value gates the check at `src/validation.cpp:3097–3100` [SRC] at `6504a3af`); the operator-list
mechanism on the frozen row (#70); and the listed local policies and switches the source itself names so (TTOR, the
unrequested-block gates, assumevalid, checkpoints, the invalidation list; #73). On the block path wall time enters
once, at `time-too-new` (`6187`), and only through `now` (#72, #77; the other adjusted-time read is the receive
path's, §4.5).

### 2.3 Disconnect a block

`disconnectBlock` (the contract above: it reads `cfg` for the disconnect pool's cap and threads that pool) undoes
the tip: `DisconnectTip` (`4065–4133`) →
`ProcessingBlockIndex::DisconnectBlock` (`processing_block_index.cpp:79–96`: the undo must exist, else
`DISCONNECT_FAILED`) → `ApplyBlockUndo` (`:9–77`: the counts must agree `:14–18`, `:55–59`; the block's outputs
are removed and every spent coin restored by `UndoCoinSpend` in reverse order `:65`, `2937–2953`, an existing coin
making the result `DISCONNECT_UNCLEAN` `2941–2944`, `2952`; the best block pointer moved to the parent `:74`) `[SRC]`. The
disconnected transactions, the coinbase filtered, go to a disconnect pool capped at `-maxmempool`
(`4110–4113`; `AddToDisconnectPoolUpToLimit` `txmempool.cpp:2487`; `DisconnectedBlockTransactions`
`txmempool.h:1455–1500`) and the tip moves to the parent (`UpdateTip` `4117`) `[SRC]`. No policy inside the step; the pool's
cap is a parameter.

### 2.4 Select the active chain

`activateBestChain`, `invalidateBlock` and `reconsiderBlock` (the contract above), the reference's `ActivateBestChain`
(`4913–5130`): find the most-work candidate (`FindMostWorkChain` `4413–4494`: the last of `setBlockIndexCandidates`
under `CBlockIndexWorkComparator`, skipping the soft-rejected and the soft-consensus-frozen `4426–4431`; a
candidate whose path to the active chain crosses an invalid or body-less block is dropped with its chain
(`4441–4489`) and the search repeats); then `ActivateBestChainStep` (`4561–4800`): disconnect to the fork point
(`FindFork` `4573`; the loop `4603–4612`), connect forward in runs of at most 32 (`4675–4694`), on an invalid
block `InvalidChainFound` and retry (`4738–4746`), `PruneBlockIndexCandidates` (`4498–4523`) `[SRC]`. Equal-work
ordering uses validation completion time, then sequence id, then pointer order (`block_index.h:1239–1274`). The
model records an explicit completion event and tie rank (§1.3); #66 serializes judging scenarios or records an
unresolved tie as non-judging. These are local selection observations, not additional consensus rules. **The mempool's reorg path:**
the disconnected transactions are re-validated through the validator as `TxSource::reorg`
(`AddToMempoolForReorg` `txmempool.cpp:2330–2443`: oldest block's transactions back in order `2351–2372`, the
validation `2385`, the ones that do not make it removed with descendants `2393–2400`), then every entry that is
no longer final, or spends a coinbase or confiscation output that is no longer mature, is removed
(`RemoveForReorgNL` `947–1023`), then the frozen re-checks (`2413–2435`). Automatic failed disconnection
still re-admits earlier successful disconnections through the activation scope
(`src/validation.cpp:4608–4616,4644–4668`); explicit invalidate/freeze failure uses remove-only cleanup
(`5250–5255`, `4536–4539`; `RemoveFromMempoolForReorg`, `src/txmempool.cpp:2446–2485`) [SRC] at `6504a3af`. The operator's hands on this transition:
`InvalidateBlock` (`5230–5330`: mark failed, disconnect while the block is on the active chain, re-admit, re-add
candidates, re-activate) and `reconsiderblock` (`rpc/blockchain.cpp:2770–2818`), which calls `ResetBlockFailureFlags`
(`5528–5562` of `validation.cpp`, the call at `rpc/blockchain.cpp:2798`) and then `ActivateBestChain`
(`rpc/blockchain.cpp:2811`) `[SRC]`; `softrejectblock` (`rpc/blockchain.cpp:2820`), `preciousblock`
(`rpc/blockchain.cpp:2695`); and safe mode (`src/safe_mode.cpp:324`, `:572`; called at `2457`, `5122`, `5573` and `6405` among others), a client
behaviour with no effect on validity `[SRC]`.

**Consensus and policy.** The most-work rule over valid candidates is consensus; everything that removes a candidate from
consideration without a consensus failure is a setting with its row in #59 (the invalidation list, soft
rejection, the soft consensus freeze's duration, `-minimumchainwork`, checkpoints); the mempool's re-admission is
policy throughout.

### 2.5 The transitions at a glance

| transition | the reference `[SRC]` | consensus | the node's (parameters, §4.2) | reads `now`? |
|---|---|---|---|---|
| `receiveTx` | `TxnValidation` `1009`, `ProcessValidatedTxn` `1759`, `CommitTxToMempool` `895` | `CheckRegularTransaction`, `CheckTxInputs` `2552`, the script verdict under the block word | standardness, finality's hold, the conflict rule, the orphan pool, the fee floors and ceiling, the ancestor limits, the sigop cap, the validation budget, the pool's size and expiry, the reject filter | yes: entry time, expiry, the budget |
| `receiveHeader` | `AcceptBlockHeader` `6134` | PoW `pow.cpp:150`, the difficulty `pow.cpp:95`, the time window, the version floors, the parent | the invalidation list, checkpoints | yes: `time-too-new` |
| `acceptBlock` | `AcceptBlock` `6238`, `CheckBlock` `5749`, `ContextualCheckBlock` `6039`, `ReceivedBlockTransactions` `5662` | the merkle root, the coinbase, the size (C/setting), the sigop sums before Genesis, finality at the block, BIP34 | the unrequested-block gates, TTOR, `-minimumchainwork`, `-minblockstokeep` | yes, through `receiveHeader` |
| `connectBlock` | `ConnectBlock` `3775` = `BlockConnector` `2994` | BIP30, inputs unspent, BIP68, sigops before Genesis, the scripts under the block word, the coinbase bound | assumevalid, `-disablebip30checks`, the frozen lists (third kind), the freeze duration, the depth waiver | no (an input it ignores) |
| `disconnectBlock` | `DisconnectTip` `4065`, `processing_block_index.cpp:79` | the undo | the disconnect pool's cap | no (an input it ignores) |
| `activateBestChain` | `ActivateBestChain` `4913`, `FindMostWorkChain` `4413`, `ActivateBestChainStep` `4561` | most work among valid candidates | soft reject, precious, safe mode; the pool's re-admission rules | through `receiveTx` on re-admission |
| `invalidateBlock`, `reconsiderBlock` | `InvalidateBlock` `5230`; `reconsiderblock` `rpc/blockchain.cpp:2770` → `ResetBlockFailureFlags` `5528` | none: the operator's hands on the candidate set | the marks they set and clear | through the activation they end in |
| `advanceTime` | `Expire` `txmempool.cpp:2201`, the non-final pool's periodic check `time_locked_mempool.cpp:611`, the orphan expiry (`orphan_txns.h:27–30`), the scheduled retries | none | every expiry, every budget | yes: the event's time |

## 3. The derived status function

```
inductive RejectCode
  | node (code : Nat)      -- a validation code of the node, `consensus/validation.h:14–24`
  | rpc  (code : Int)      -- an RPC error code, `rpc/rawtransaction.cpp:1636–1650`

inductive Status
  | unknown | orphan | inMempool | heldNonFinal
  | minedActive (h : Nat) | onStaleBranch | conflictedByMinedSpend
  | rejected (code : RejectCode) (reason : String)

def status (s : State) (id : TxId) : Status
```

A total function *(design)*, defined by the earliest clause that holds, in this order. The clauses are evaluated
in table order using finite lookups. For `minedActive` choose the greatest array index `h` of `s.headers.active`
whose block body contains `id`; a missing node or a missing body contributes no match. This tie rule is part of
the spec's view (the reference accommodates a repeated id across heights in its historical coinbase handling,
`coins.cpp:560–565`, so "some block" would not choose `h`). A failed journal lookup makes the conflict and
rejection predicates false. The final clause returns `unknown`, so the function is total even on structurally
inconsistent records; the transition invariants separately establish a coherent chain state. An RPC error is
stored as `RejectCode.rpc`, never silently as a nonnegative node code; the harness's mapping recovers the node
code when the receipt carries it.

| # | value | holds when | the reference's observable `[SRC]` | the structure |
|---|---|---|---|---|
| 1 | `minedActive h` | `h` is the greatest index of `s.headers.active` whose block body contains `id` (the tie rule above) | `getblock hash` for the specifically selected active block (`rpc/blockchain.cpp:1108`; `:79–90`: `confirmations` ≥ 1 on the active chain, −1 off it), its tx list checked for `id`; `getrawtransaction id 1` (`rpc/rawtransaction.cpp:53`, `:159`; under `-txindex`, `DEFAULT_TXINDEX` false `src/validation.h:190`) is supplementary evidence, never the disambiguator of a repeated id | the chain |
| 2 | `inMempool` | `id ∈ s.mempool.accepted` | `getrawmempool` (`rpc/blockchain.cpp:440`), `getmempoolentry` (`:740`) | `mapTx` |
| 3 | `heldNonFinal` | `id ∈ s.mempool.nonFinal` | `getrawnonfinalmempool` (`:502`) | the non-final pool |
| 4 | `orphan` | `id ∈ s.mempool.orphans` | `getorphaninfo` (`:2675–2693`) returns the pool's **count only**; no RPC at the pin lists orphan ids, and an RPC submission never retains an orphan (§5.1). The witness is confined to §5.1's isolated loopback P2P scenario: an empty pool established, exactly one child submitted with its parent absent, the missing-parent request (`AskForMissingParents` `1868–1880`) and the count's increase recorded, then the parent submitted and the child observed retried and admitted without resubmission. **Finding** for #66, #71 and S7's #85/#78: no per-id orphan claim is inferred from a count in an unconstrained pool | `COrphanTxns` |
| 5 | `onStaleBranch` | some node with a body, not on `active`, contains `id` | `getchaintips` (`:2497`; the statuses `active`, `invalid`, `headers-only`, `valid-fork`, `valid-headers`, `unknown` at `:2585–2608`) and `getblock hash` with `confirmations` −1 | the tree |
| 6 | `conflictedByMinedSpend` | some input of `s.seen id` is absent from `s.utxo` and spent by a transaction other than `id` in a block on `active` | the recorded body of a distinct active-chain spender of that exact outpoint (its block by `getblock`, the body by `getrawtransaction` under `-txindex`), checked against the journaled transaction's inputs; `gettxout prevout` null (`:1923–2029`) alone is insufficient; the node's own words for it are the pool's removal with reason CONFLICT (`txmempool.cpp:1091–1117`) and the double-spend notification (S7's #80) | the chain plus the journal (§1.4) |
| 7 | `rejected code reason` | `s.rejected id = some ⟨code, reason⟩` | the synchronous answer of `sendrawtransaction` (`rpc/rawtransaction.cpp:1636–1650`: `RPC_TRANSACTION_REJECTED` with `code: reason`, `Missing inputs` as `RPC_TRANSACTION_ERROR`, `RPC_TRANSACTION_ALREADY_IN_CHAIN`) or `sendrawtransactions`' per-id `reject_code` and `reject_reason` (`:1798`; the fields written at `:1716–1724`); afterwards only the filter's membership, which no RPC exposes, and the reject message once (`1934–1941`) | the journal (§1.4) |
| 8 | `unknown` | none of the above | no positive match in the harness's complete recorded observation history; no single RPC proves global absence | |

**Why this order** *(design)*. A chain fact beats a pool fact, because the chain is what every wallet should
believe (`NORTH-STAR.md` §6). The pool before the non-final pool before the orphan pool follows the direction the
reference moves a transaction: an orphan becomes a pool entry when its parent arrives (§2.1), a held transaction
becomes a pool entry when it finalises (`finalisesExistingTransaction`). A stale-branch inclusion stands above a
conflict, because a reorg can bring the branch back (#64, theorem 4), while a conflict is read off the active
chain of the moment. A rejection stands last, because it is one node's answer at one time, policy almost
entirely, and any chain fact overrides it. Two transactions with the same id are one transaction.

**What #67 states on it.** `status` is a function (determinism, by construction). Connecting a block that
extends the active tip preserves prior active inclusion; the selected height can change if the same id occurs
again. Disconnect, operator invalidation and a completed reorganization can remove inclusion; each transition
states its own preservation law (#68's theorem 4 as §4.4 re-states it). `onStaleBranch` and `minedActive` are
exclusive. Every input of an accepted transaction refers to an unspent chain coin or to an output of an accepted
ancestor, and no two distinct accepted transactions spend the same outpoint. The client vocabularies (Arcade's, the
wallet-toolbox's, the node's reject codes) are functions from this type or recorded as having none, each with a
witness scenario (#67); nothing here is a rule.

[D] 2026-10-13 (#67): `BsvChain.StatusState` retains the landed
`ChainState` with `TxJournal` as the observation envelope. `BsvChain.status`
executes the ordered clauses above; active height is the greatest active array
index. The [generated vocabulary table](../spec/status-views.md) records producer
inputs and per-row predicate-checked obstruction witnesses. Active inclusion has a
partial Arcade MINED view, as does actual off-active body inclusion on a stale
branch. Exact mined conflict has a partial request doubleSpend view. The exact
input-empty completed node receipt has partial Arcade REJECTED and request invalid
views; other rejection codes, reasons and RPC namespaces are undefined in these
narrow rejection views. Stored lifecycle history, reorg delivery and transition
restrictions are separately qualified ([SRC] Arcade models/transaction.go:104-105,
110-111,227-237,326-331 at 1ae1208e). Its node rejection Option view preserves
code namespace and reason; `none` is not a literal RPC word. The synchronized
mining, client depth and remote-SEEN projections are explicitly qualified views,
never rules or measurements of external producers.

## 4. The module map

### 4.1 `lean/BsvChain/`: a second library in the same Lake package (the packaging decision, recorded in §8)

`lean/lakefile.toml` gains `[[lean_lib]] name = "BsvChain"` beside `BsvScript`: one toolchain, one Mathlib, one
tripwire, one pin, and the layer-4 interface of `docs/DESIGN.md` §12 untouched (a consumer that imports
`BsvScript` pulls nothing of `BsvChain`; Lake builds only what the imports reach, §12.1). The import direction is
a law: `BsvChain` imports `BsvScript`, never the reverse (a lint leg beside #77's). The files, each with the issue
that writes it:

| file | what it holds | issue |
|---|---|---|
| `BsvChain/Params.lean` | `ChainParams` per network (mainnet, testnet, stn, regtest: the chain-layer heights and flags of `chainparams.cpp:1033–1559`; §4.2) and `BsvChain.NodeConfig` extending `BsvScript.Params.NodeConfig` with the chain-layer fields; born with the library skeleton (the paragraph below the table) | #59, #69 |
| `BsvChain/Oracle.lean` | `ScriptOracle` and its two instances (§4.3) | #76 |
| `BsvChain/Coin.lean`, `BsvChain/Utxo.lean` | `Coin`, `UtxoSet`, `applyTx`, the undo record, `checkTxInputs` as `2552–2665` | #61 |
| `BsvChain/Finality.lean` | `isFinalTx` (`227–247`), the median time past over a header chain (`block_index.h:722–737`), the sequence locks (`256–342`), the fee rule | #60 |
| `BsvChain/Header.lean`, `BsvChain/Pow.lean`, `BsvChain/Merkle.lean` | the header frame and its hash, `nBits` to target and `blockProof` (`block_index.cpp:114–127`), `checkProofOfWork` and `getNextWorkRequired` (EDA, DAA, no-retargeting), `computeMerkleRoot` with `mutated`, `computeMerkleRootFromBranch` (`consensus/merkle.cpp:291–310`), `verifyPath` | #63, #65, #69 |
| `BsvChain/Block.lean` | `Block`, `checkBlock`, `contextualCheckBlockHeader`, `contextualCheckBlock`, `connectBlock`, `disconnectBlock` (§2.2, §2.3) | #63, #64 |
| `BsvChain/Mempool.lean` | `Mempool`, `TxVerdict`, `accept` (§2.1), `expire`, `trimToSize`, the orphan and non-final pools, the reject filter; the frozen lists' check on both paths | #62, #70, #71 |
| `BsvChain/Chain.lean` | `HeaderTree`, `acceptHeader`, `acceptBlock`, `findMostWorkChain`, `activateBestChain`, `invalidateBlock`, `reconsiderBlock`, the pool's reorg path (§2.4); the validation-depth parameters | #64, #73 |
| `BsvChain/Status.lean` | `Status` and `status` (§3) | #58's §3, #67 |
| `BsvChain/Views/Status.lean` | the client vocabularies as functions from `Status`, or the recorded no-function witnesses with the witness's id | #67 |
| `BsvChain/Views/TscProof.lean` | the TSC proof codec, its round-trip theorem, and its projection to the merkle-path input; #65 defines the underlying path operation | #75 |
| `BsvChain/Properties/*.lean` | the theorems, one explainer each (rule 7): the five of #68 and each layer's own | #60, #61, #63, #64, #65, #68, #69, #70, #73 |
| `lean/BsvChain.lean` | the library root | #59 (the skeleton's day); #61 updates it with `Coin` and `Utxo` |

#59 creates the `BsvChain` library skeleton and `BsvChain/Params.lean`. Its `NodeConfig` extends
`BsvScript.Params.NodeConfig` with the chain-layer fields; the script configuration's activation heights are the
projection of the same explicit `ChainParams` passed to the transition. The census and this record change together
(the #6 rule). #59's body names `lean/BsvScript/Params.lean` as its output path; the maintainers update it to this
design before implementation (§9). #61 adds `Coin` and `Utxo` and updates the existing library root.

Teranode's machine (#74) is a page, `docs/TERANODE-MACHINE.md`, not Lean, until S8 states the refinement.
[D] **Ownership accepted for #59 on 2026-10-12 (lens-59 finding 5):** the Lean side holds the `BsvChain` library
(`lean/BsvChain` and `lean/BsvChain.lean`), the harness side holds `lean/Bsvs` and the lakefile trio, and
`lean/lakefile.toml` is shared by the Lean side and the harness side for the libraries' declarations, accepted at the landing.

### 4.2 The parameter record: `BsvChain.NodeConfig`

[M] The #59 census, extended by #62 and corrected by fix-62, has 81 added fields
(9 consensus / 72 policy, including 23 node settings), plus 17 inherited fields
(4 consensus / 13 policy): 98 flattened fields (13 consensus / 85 policy).
The ordered declarations and PARAMETERS §8 rows re-derive these counts through
`tools/check_parameters.py`; the [#62 record](records/20261012-172834-s6-62-mempool.md)
records the three regular-gate consensus getter fields and the promotion policy field.

This is the minimum inventory for the checks named in this note. #59 must complete the census, including each
setting's units, optional or mandatory status, initialization and source, before a transition reads it. A getter
citation is not a default. The existing script-layer fields keep their individually cited rows in
`docs/PARAMETERS.md`. Operator lists are explicit scenario inputs; their contents are never promoted to consensus
constants. Teranode's defaults stand beside these rows in the census as the second oracle's, never as the rule
(§5.2). Kinds as in the legend above; SV-node paths are at `6504a3af`.

| field | default `[SRC]` | read at | kind |
|---|---|---|---|
| `maxTxSigOpsCountConsensusBeforeGenesis` | 20,000; definition and initialization `consensus/consensus.h:46–47`, fixed getter `config.cpp:2417–2420`, no CLI | `1032–1035,1046` | C |
| `maxTxSizeConsensusBeforeGenesis`, `maxTxSizeConsensusAfterGenesis` | 1,000,000 and 1,000,000,000 serialized bytes; definitions and initialization `consensus/consensus.h:12–17,26–29`, fixed getter `configscriptpolicy.cpp:397–412`, no CLI | `1033–1035,1043–1046` | C |
| `maxPrimaryPromotionVisits` | 1,000; definition and initialization `txmempool.h:423`, no CLI | `txmempool.cpp:481–565` | P |
| `limitAncestorCount` | `DEFAULT_ANCESTOR_LIMIT` 10,000 `src/validation.h:86`; `config.cpp:49` | `1313–1318` | P |
| `maxMempool` | `DEFAULT_MAX_MEMPOOL_SIZE` 1,000 MB `policy/policy.h:87`; `config.cpp:83` | `938–945`, `4111` | P |
| `maxMempoolNonFinal` | 50 MiB = 52,428,800 bytes (`policy/policy.h:89`; the conversion at `time_locked_mempool.cpp:400`) | `1119–1123` | P |
| `mempoolExpiry` | `DEFAULT_MEMPOOL_EXPIRY` 336 h `src/validation.h:91`; `config.cpp:87` | `txmempool.cpp:2201` | P |
| `mempoolNonFinalExpiry` | `DEFAULT_NONFINAL_MEMPOOL_EXPIRY` 672 h `src/validation.h:93` | expiry loaded at `time_locked_mempool.cpp:404` and applied at `:627–628`, `:655–660` | P |
| `maxOrphanTxSize` | `DEFAULT_MAX_ORPHAN_TRANSACTIONS_SIZE` 1 GB `orphan_txns.h:49`; `config.cpp:88` | `1904–1912` | P |
| `orphanTrimHysteresisDivisor` | 10; the hysteresis bytes are `maxOrphanTxSize` divided by this value using integer division (`1911–1915`) | `orphan_txns.cpp:175–192` | P |
| `blockMinTxFee` | a mandatory launch input, `-minminingtxfee`; no implicit launch default (`bitcoind.cpp:158–164`; `init.cpp:3115–3121`). The constructor initializes 500 sat/kB before launch configuration (`DEFAULT_BLOCK_MIN_TX_FEE`, `policy/policy.h:64–66`; `txmempool.h:437–438`) | `1269–1273` | P |
| `minRelayTxFee` | 0 sat/kB (`config.cpp:32`; `init.cpp:3093–3099`: the option removed and the value set to zero); `DEFAULT_MIN_RELAY_TX_FEE` 250 at `src/validation.h:77` is not the initialized value (#59 census) | at the pin only `estimateFee` reads it (`txmempool.cpp:1883–1888`); the receive path's floor is the rolling pool minimum, `GetMempoolRejectFee` `763–769` over `GetMinFee` `txmempool.cpp:2624–2647`, never the static relay or mining default | P |
| `minDebugRejectionFee` | 0 sat/kB (`txmempool.h:439`); `-mindebugrejectionfee` is permitted only off mainnet, with loading and the mainnet refusal at `init.cpp:3135–3146` | `txmempool.cpp:2644–2647`; the receive path's floor is the maximum of this value and the truncated rolling fee | P |
| `maxTxFee` (the absurd-fee ceiling, per call) | 0.1 BSV = 10,000,000 sat (`src/validation.h:79`); the RPC applies it per call and `allowhighfees` sets that call's ceiling to 0 (`rpc/rawtransaction.cpp:1571–1573`) | `1250–1254` | P |
| `maxStdTxnValidationDuration`, `maxNonStdTxnValidationDuration` | 3 ms, 1 s `txn_validation_config.h:39–43`; `config.cpp:64` | `1077`, `1210–1240`, `1328–1355` | P; time (#71) |
| `acceptNonStdOutputs`, `requireStandard`, `maxTxSizePolicy`, `maxTxSigOpsCountPolicy`, `dataCarrier*` | already `BsvScript.Params.NodeConfig` (`docs/PARAMETERS.md` §4) | `1070–1088`, `1241–1252` | P |
| `excessiveBlockSize` | a mandatory operator input, no implicit launch default (`bitcoind.cpp:140–149`); read through `GetMaxBlockSize` `config.cpp:248`; `docs/BLOCK-CONSENSUS.md` §2.4 | `5811–5823`, `6056–6061` | C/setting |
| `maxStackMemoryUsageConsensus` | a mandatory operator input, no implicit launch default (`bitcoind.cpp:140–149`); `docs/PARAMETERS.md` §1 | through the oracle | C/setting |
| `disableBip30Checks` | false on mainnet, STN, testnet and regtest (`chainparams.cpp:1186`, `:1300`, `:1447`, `:1555`); declared permission is false on mainnet (`:1187`) and true on the other three networks (`:1301`, `:1448`, `:1556`); the getter resolves an unset value to the network default (`config.cpp:2065–2067`), and the resolved value gates the check | `3097–3100` | setting |
| `softConsensusFreezeDuration` | `DEFAULT_SOFT_CONSENSUS_FREEZE_DURATION` 3 `src/validation.h:219` | `3402–3407` | setting (the third kind's companion) |
| `minimumChainWork`, `assumeValid` | mainnet `chainparams.cpp:1056`, `:1061`; regtest 0 at `:1480`, `:1484`; testnet `:1352`, `:1357` | `3482–3518`, `6329` | setting (#73) |
| `checkpointsEnabled` | `DEFAULT_CHECKPOINTS_ENABLED` true `src/validation.h:189`; the tables `chainparams.cpp:1124`, `:1419`, `:1530`; `checkpoints.cpp:14–24` | `6179–6184` | setting |
| `minBlocksToKeep` | `DEFAULT_MIN_BLOCKS_TO_KEEP` 288 `src/validation.h:272` | `6289–6290` | setting |
| `minTtorValidationDistance` | 100 blocks (`MIN_TTOR_VALIDATION_DISTANCE`, `src/validation.h:345–350`); a model parameter for the reference's local policy constant, not an operator CLI option | `5671–5682` | P |
| `txIndex` | `DEFAULT_TXINDEX` false `src/validation.h:190` | observation only (§3) | setting |
| the frozen and confiscation lists, the whitelist, the depth waiver | `docs/BLOCK-CONSENSUS.md` §2.1 | `2595–2612`, `3402–3407` | operator-list mechanism (#70) |
| the invalidation list | `config.cpp:992` | `6144–6149` | setting |
| `limitSecondaryMempoolAncestorCount` | 25 `src/validation.h:88`; `config.cpp:50` | `783–792` | P |
| `maxCoinsViewCacheSize` | 0 `config.cpp:70`; the setter `:872–879` | `1168–1175` | P |
| `maxMempoolSizeDisk` | 0 × `maxMempool` (`policy/policy.h:94–95`; `config.cpp:84`) | the eviction accounting (#62) | P |
| `mempoolMaxPercentCPFP` | 10 % (`policy/policy.h:96–97`; `config.cpp:85`) | the eviction accounting (#62) | P |
| `nonFinalMaxReplacementRate`, `nonFinalReplacementPeriodMinutes` | 7,200 updates per 60 minutes (`src/validation.h:94–97`; `time_locked_mempool.cpp:406`, `:408`) | `1127–1130` | P |
| `nonFinalCheckFrequencyMs` | 600,000 (`time_locked_mempool.h:78–79`; `time_locked_mempool.cpp:402`) | the periodic check (`time_locked_mempool.cpp:611`) | P; time (#71) |
| `orphanExpirySeconds`, `orphanExpiryCheckIntervalSeconds` | 1,200, 300 (`orphan_txns.h:27–30`) | the orphan pool's expiry (#62) | P; time (#71) |
| `maxPercentageOfOrphansInBatch`, `maxInputsOutputsPerSecondaryOrphan` | 60 %, 5 (`orphan_txns.h:53–56`; `config.cpp:89–90`) | the orphan retry batches (#62) | P |
| `minConsolidationFactor`, `maxConsolidationInputScriptSize`, `minConfConsolidationInput`, `acceptNonStdConsolidationInput` | 20, 150 bytes, 6, false (`policy/policy.h:71–78`; `config.cpp:45–48`) | `1267` (`IsFreeConsolidationTxn`) | P |
| `rollingFeeHalfLifeSeconds` | 43,200, configurable 1,800 to 43,200 (`txmempool.h:485`, `:626–627`; `txmempool.cpp:2615–2621`) | `txmempool.cpp:2624–2647` | P; time (#71) |
| `mempoolFullFeeIncrement` | 1,000 sat/kB (`policy/policy.h:90–91`) | `txmempool.cpp:2783` | P |
| `recentRejectCapacity`, `recentRejectFalsePositiveRate` | 120,000, 0.000001 (`txn_recent_rejects.cpp:9–11`) | the filter (#71) | P |
| `maxTxnChainValidationBudget` | 50 ms (`txn_validation_config.h:44–46`) | the budget (#71) | P; time (#71) |
| `validationClockCpu` | true (`txn_validation_config.h:36–37`) | the budget's clock (#71) | P; time (#71) |
| `safeModeMaxForkDistance`, `safeModeMinForkLength`, `safeModeMinPowDifference` | 1,000, 6, −72 (`src/validation.h:315`, `:320`, `:326`; `config.cpp:185–187`) | `src/safe_mode.cpp` (#73) | client settings |
| `enableAssumeWhitelistedBlockDepth`, `assumeWhitelistedBlockDepth` | false, 6 (`policy/policy.h:98–101`) | `3530–3542` | the operator-list mechanism's companion settings (#70) |

`ChainParams` (#59 data and census in PARAMETERS §8.3; #69 transition use and proofs) carries per network: `nSubsidyHalvingInterval` (mainnet `chainparams.cpp:1037`, regtest 150
`:1460`), `BIP34Height` (`:1038`; regtest 100,000,000 `:1463`), `BIP65Height` (`:1042`), `BIP66Height` (`:1044`),
`CSVHeight` (`:1046`), `powLimit` (`:1047`), `nPowTargetTimespan`, `nPowTargetSpacing` (`:1050–1051`),
`fPowAllowMinDifficultyBlocks`, `fPowNoRetargeting` (`:1052–1053`; regtest true, true `:1476–1477`),
`uahfHeight` (`:1065`; regtest 0 `:1487`), `daaHeight` (`:1068`; regtest 0 `:1490`), and the Genesis and Chronicle
heights already in `BsvScript.Params` (`:1071`, `:1074`) `[SRC]`. On regtest `daaHeight` is 0 and
`fPowNoRetargeting` is true (`chainparams.cpp:1477`, `:1490`). `GetNextWorkRequired` returns the parent's bits at
`pow.cpp:107–109` before testing `daaHeight` at `:111–113`, after the genesis case at `:101–104`; so ordinary
regtest never executes the DAA algorithm. #69 must test the DAA separately under parameters that enable
retargeting, and #66's regtest oracle uses the compiled regtest parameters: a scenario judged under mainnet
parameters would diverge for the wrong reason, which is why #69 precedes #66's done-bar (§6).

### 4.3 The script oracle (#76; DESIGN §3 Q3)

```
abbrev ScriptOracle :=
  (tx : Tx) → (prevouts : List Prevout) → (input : Nat) →
  (coinHeight spendHeight : Nat) → (evalParams : EvalParams) → Verdict
```

`receiveTx`, `applyTx` and `connectBlock` pass the exact `EvalParams` of each required script call. The wrapper
computes the caller's word, including any per-request exclusions or re-check word, combines it with the per-input
era contribution, and derives the resource limits with the independent consensus selector (`1328–1347`, `1411–1423`,
`705–717`, `2693–2707`, `2738–2749`). Use the existing script-layer flag and limit functions; do not duplicate the
script rules. `Params.derive` (`lean/BsvScript/Flags.lean`; `docs/PARAMETERS.md` §6) is a convenience for the
ordinary block and relay combinations, not the representation of every call. The evaluator instance invokes
`Eval.verifyScript` with these explicit parameters and the transaction context. A second instance answers from a corpus column of recorded verdicts,
so that #68's theorems are stated for every oracle and never depend on secp256k1, and a check leg has the two
instances agree on the corpus rows. The recorded-oracle key includes the effective `EvalParams` as well as the
transaction/input context. The agreement corpus covers the block-word re-check with policy limits, modified
mandatory-word checks, and per-request flag exclusions. The wrapper owns node-code/reason mapping and never infers
an unexecuted re-check from one ordinary relay verdict. The `Eval` adapter closes over the transition's configuration after projecting
the same `ChainParams`, constructs the existing transaction context and the spent amount, and invokes
`Eval.verifyScript` with the spent locking script and the current unlocking script. It is called only where the
reference requires script evaluation: the assumevalid behaviour (`3482–3518`) and the explicit confiscation bypass
(`2864–2868`) are preserved, and the oracle is not consulted where the reference consults none.

### 4.4 The theorems the milestone names (#68)

| # | statement | layer |
|---|---|---|
| 1 | for a well-formed tip state, a successful connection that overwrites no live outpoint, followed by a clean disconnection with the retained undo, restores the original UTXO set (undo correctness). The condition is the reference's: `AddCoins` lets a coinbase overwrite an existing coin (`coins.cpp:560–565`) and `CBlockUndo` keeps no record of the overwritten outputs (`undo.h:109–112`; the coinbase is skipped at `processing_block_index.cpp:50–57`), so the historical BIP30 exceptions and a chain that disables the check need separate statements | #64 over #61 |
| 2 | no inflation: a block's coinbase pays at most the subsidy at its height plus its transactions' fees, and every non-coinbase transaction conserves value (inputs = outputs + fee) | #61, #63 |
| 3 | every non-coinbase transaction in a successfully connected block has every input unspent in the UTXO view immediately before that transaction's application, including eligible outputs created by earlier transactions in the same block. Coinbase follows its structural and subsidy checks; it is not an input-spending case (`2483–2494`, `3326–3331`) | #64 |
| 4 | after a successful automatic activation, the tip has maximal accumulated work among the eligible candidates with available, valid ancestry; if the previous tip remains eligible and the eligibility settings are unchanged, the selected work does not decrease. Explicit disconnect, invalidate (`5234–5256`: the block is marked failed and disconnected at once, no higher-work replacement required), soft rejection and freeze changes have their own removal laws; strict growth needs the further premise that excludes equal-work selection. The unconditional form of the charter ("only when a chain of more work is connected") is false in the machine being specified | #64 |
| 5 | For an in-range transaction of a known body, with the stated literal-null compatibility restriction, its generated branch recomputes the body root; the present theorem uses non-null branch literals as a sufficient restriction. ([SRC] `consensus/merkle.cpp:284–289`, `:291–310` at `6504a3af`, [D] 2026-10-13); membership in that body and membership of its header in the active chain establish inclusion at its active height. Verification of an externally supplied path establishes root equality only: `ComputeMerkleRootFromBranch` returns the supplied leaf for an empty branch whatever the index, and equal hash outputs do not establish injectivity. Reading that equality as inclusion requires an explicitly stated commitment hypothesis (HashCommits on the inputs touched by the supplied and canonical paths, a hypothesis of the theorem, never an axiom: rule 7) and the path-shape conditions. The body hypothesis binds active-height and tree lookups, matching height, retained body and headers, header/body-root equality and mutation false; path shape requires an in-range index, equal depths and 32-byte words. This compatibility restriction is not a block-acceptance rule ([SRC] `src/validation.cpp:5770–5781` at `6504a3af`). Unrestricted literal-branch completeness over raw hash lists is false in general. #65's raw-state theorem for exact Lean Tx membership assumes local txid injectivity, excluding distinct identifier aliases in the supplied transaction/body domain. A stale header supplies no evidence of active-chain membership; the universal implication is refuted over raw #64 states, while the accepted-block/invalidate witness runs executably on the assumed intake prefix. [M] 2026-10-13 (#68): the reachable-state existential is kernel-proved (`s6_stale_path_reachable`, a run of the transitions from the regtest genesis): T is block 1a's coinbase, its body holds one transaction, its body-derived path is `[]`, and verification is root equals txid. Near genesis no spendable output has reached the pinned maturity ([SRC] `src/validation.cpp:2620-2626` at `6504a3af`). The path carries no positional information by itself ([SRC] `src/consensus/merkle.cpp:291-310` at `6504a3af`) and is not a node-emitted proof: #75 measured RPC -5 for this body form ([SRC] `src/rpc/rawtransaction.cpp:2302-2306` at `6504a3af`). The non-degenerate class with a multi-transaction body and a non-empty path is distinct and owed; the header/body/root binding is an invariant of reachable states (`reachable_bodiesBound`), so for reachable states inclusion needs no per-use AuthenticatedBody (`reachable_path_inclusion_or_collision`, `reachable_path_inclusion`), and the reachable-state G4 theorem `reachable_path_transaction` instead assumes well-formedness of the supplied transaction and every body transaction, plus HashCommits over their serializations, the supplied and canonical path inputs and both header encodings, using `decodeTxPrefix_serTx` | #65 The maintainers' ruling S6-1 (2026-10-12, road b): #65 states inclusion as a theorem in the disjunction form (root equality implies membership in the body or a collision pair for the hash), proved over the hash as a definition, no axiom, the scenario replaying the path check. |

[M] 2026-10-13, #68: the five rows are proved in `lean/BsvChain/Properties/Theorems.lean`, `Reachable.lean`, `StaleRun.lean` and `TxCodec.lean`, each with its explainer: row 1 `s6_undo_identity` (BIP30 enforced; the coinbase premise discharged by the connection's own BIP30 loop) and `s6_undo_identity_coinbase` (the coinbase case stated separately), both prove `CoinsView.coins` equality for `connectBlock` followed by a clean `disconnectBlock` at the height derived from `previous`. The `connectTip`/`disconnectTip` lift to `ChainState` is owed: `connectTip` takes its height through `headerContext`, while `disconnectTip` reads the stored index height, requiring index-height and ancestry invariants. `WellFormedCoins` is a normalized live-view representation condition motivated by AddCoin, not an extra block-validity test: a raw map may contain spent sentinels or entries AddCoin would prune ([SRC] `src/coins.h:235`, `src/coins.cpp:45-64,386-401,560-565`, `src/validation.cpp:3034-3050,4065-4117`, `src/processing_block_index.cpp:30-69` at `6504a3af`); row 2 `s6_no_inflation` (the fees derived from the executed transactions); row 3 `s6_inputs_unspent` (the sequential views, same-block outputs included); row 4 `s6_activation_maximal_work` and `s6_activation_work_nondecreasing`, with the charter's unconditional removal sentence refuted by the kernel-checked `s6_charter_removal_false` (an invalidation removes a transaction and lowers the selected work); row 5 as above. To let the kernel reduce chain runs, `medianTimePast` sorts by insertion, proven the same list as the merge sort (`insertionSort_eq_mergeSort`) [SRC] `src/block_index.h:722–737` at `6504a3af`. [M] 2026-10-14, #120: `StaleRun.lean` is the Lake library `StaleRunCheck`, outside `lake build BsvChain` (the root no longer imports it); the axioms leg of `tools/check.sh` builds it before the walk and `AxiomCheck.lean` imports it, so the tripwire checks the witness on every run and its eight theorems stay on the list. On the box with the one Lean slot held, the cold `lake build BsvChain chaincheck` went from 536 s and 29.9 GB peak to 61 s and 2.7 GB; the module from 481 s inside the cold build (515 s alone, profiled) to 229 s alone (214 s profiled) (two re-reductions of the run removed: the run states are definitions, the reachability proof goes through one step, the charter equation closes by the pair's eta), its peak still 28.1 GB; record `docs/records/20261014-061809-stale-cost-s1.md`.

[M] 2026-10-13, #69: the era rules are functions of height and `ChainParams` in `lean/BsvChain/Eras.lean`, wired at the hooks #63 and #64 left: `bip30Enforced` (the two height-and-hash exceptions, the BIP34 ancestor shortcut, the resolved setting) fills `ConnectionChecks.bip30Required` through `eraConnectionChecks`, the default of `ChainContext.connectionChecks` (`src/validation.cpp:3070–3117`); `checkBlockVersion`/`versionObsolete` name the floors inside `contextualCheckBlockHeader` (`5962–5972`); `nextWorkPath` names `getNextWorkRequired`'s branch (`pow.cpp:95–117`, verified line by line with `GetNextEDAWorkRequired` `22–93`, `CalculateNextWorkRequired` `119–148`, `ComputeTarget` `177–208`, `GetSuitableBlock` `214–245` and `GetNextCashWorkRequired` `256–297`); the CSV cutoff is #60's `blockFinalityCutoff`, read by `contextualCheckBlock` (`6046–6050`, `6067–6074`); `NetworkData` carries each network's checkpoint table, BIP30 permission, standardness and the two setting defaults (`chainparams.cpp:1033–1559`), applied by `NodeConfig.withNetwork` [SRC] at `6504a3af`. `lean/BsvChain/Properties/Eras.lean` proves [M] 23 theorems, sorry-free and in the axiom walk: (a) `s6_regtest_next_work_parent_bits` (on regtest every next-work computation returns the parent's bits: `fPowNoRetargeting` at `pow.cpp:107–109` precedes the `daaHeight` test at `:111–113`, so the issue's "post-DAA path from height 0" is never taken there) with `s6_daa_zero_cash_path` (for any parameters with `daaHeight = 0` and no-retargeting off, the cash algorithm at every parent height), `getNextWorkRequired_path`, `s6_mainnet_daa_switch` (the switch reads the parent's height) and `s6_regtest_accepted_header_bits`; (b) `s6_bip30_two_exceptions`, `s6_bip30_connection_gate`, `s6_bip30_regtest` and `s6_bip30_mainnet` (enforced outside (91842, its hash) and (91880, its hash) when the shortcut is absent and the setting off; the exceptions carry no network test, so regtest and testnet have no exceptions of their own and a regtest block is exempt only with the mainnet hash) with `s6_bip30_bip34_shortcut` (the issue's unconditional sentence is false above mainnet's BIP34 height on the known chain); (c) `versionObsolete_iff_floor`, `s6_contextual_header_version`, `s6_mainnet_version_floors` and `s6_regtest_version_floors` (regtest's BIP34 height 100,000,000 never binds alone: BIP66's floor 3 binds from 1251, so version 1 passes only below 1251); (d) `s6_checkBlock_uahf_irrelevant`, `s6_contextualCheckBlock_uahf_irrelevant`, `s6_contextualCheckBlockHeader_uahf_irrelevant` and `s6_uahf_script_word`: at the pin no block check reads `uahfHeight`, so the issue's "UAHF fork-block minimum size" is absent; `LEGACY_MAX_BLOCK_SIZE` (`consensus/consensus.h:30–31`) survives only in the `excessiveBlockSize` setter's floor (`config.cpp:232–246`, `excessiveBlockSizeAdmissible`), and `uahfHeight`'s one reader is the script word's STRICTENC and FORKID from a parent at `uahfHeight` (`verify_script_flags.cpp:54–59`; regtest's 0 enables them above genesis); (e) `s6_lock_cutoff_switch`, `s6_mainnet_lock_cutoff` and `s6_block_finality_cutoff`. The policy node setting `disableBip30Checks` defaults to false on all four networks (`chainparams.cpp:1186,1300,1447,1555`); declared permission is false on mainnet and true on STN, testnet and regtest (`:1187,1301,1448,1556`). Its getter resolves the unset value (`config.cpp:2065–2067`), and the resolved value gates the BIP30 check (`validation.cpp:3097–3100`) [SRC] at `6504a3af`. The [record](records/20261014-002257-s6-69-regtest-s3.md) holds the era corpus and its regtest column.

[M] 2026-10-14, #71: the reject cache, the priority lattice and the time budgets are `lean/BsvChain/Rejects.lean`, their laws `lean/BsvChain/Properties/Rejects.lean`, each with its explainer; all policy, none a block-validity rule. The filter is #62's ideal set with an insertion count and, beside it in the pool, the tip hash recorded by the last inventory test (`recentRejectsTip`); `observeTip` is the pin's lazy reset ([SRC] `src/net/net_processing.cpp:82,930–942` at `6504a3af`): the filter is emptied by the next inventory test that observes another tip hash, so a tip that moved and came back between two tests leaves it standing. `receiveInv` and `receiveP2PTx` are the inventory envelope (`IsTxnKnown`, [SRC] `:930–961`, `:3351–3408`), with the tip hash, the coins-cache lookup and a declared false positive as explicit inputs; the RPC path neither reads nor writes the filter ([SRC] `src/rpc/rawtransaction.cpp:1586–1594`; `src/validation.cpp:1786–1797`). Row 4's theorems, over the machine: silence, `remembered_inv_silent` and `remembered_tx_suppressed` (a txid in the filter, under the recorded tip, draws no request and no validation, and the pool is returned unchanged, so the premises hold again); the insert rule, `validation_rejection_remembered`, `commit_refusal_not_remembered`, `other_sources_never_remember`, `other_sources_bypass_filter`; the reset, `no_reset_without_tip_change`, `tip_change_resets`, `reset_follows_tip_change`; the timeout, `timeout_high_requeues_low` and `timeout_keeps_pool` (the same request queued again at low priority, the accepted and held sets, the orphans, the filter and the rejection journal untouched: no rejection, no acceptance), `timeout_low_rejects` (a low-priority timeout is the rejection `too-long-validation-time`); the budget, `budget_changes_timing_only` and `elapsed_changes_timing_only`: for every state, request and budget observation the acceptance equals the acceptance with an available budget, or it ends in a timeout answer; the unconditional form "the budget never changes a verdict" is false for a low-priority request, whose timeout is a completed rejection, and the theorem states the true form. The elapsed validation time is an explicit input (`ElapsedObservation`, microseconds of the node's validation clock; `budgetObservation` is strict, as [SRC] `src/taskcancellation.h:155–164`); the machine reads no clock and `chain lint` stays GREEN. A cell is judged by its clock dependence, not by its budget's value (fix-71, [M] 2026-10-14): a limited validation whose outcome the firing of some poll would change is clock-dependent and non-judging on an available budget as on an expired one; an unlimited validation, or one whose outcome no poll changes, is clock-free and judged (`ClockDependence`, `acceptClockDependence`, `budgetJudgment`; `budget_judgment_judging_iff`, `unlimited_clock_free`, `clock_free_budget_invariant`; [SRC] `src/validation.cpp:990–1006,1077–1078`, `src/taskcancellation.h:155–164`, `src/init.cpp:2890–2895`). A refusal by the commit is answered and not remembered (§2.1 row 14; `finishCommit`). [M] 2026-10-14, measured on fresh instances with the loopback peer at `4e041be7`: 6 trace rows, 34 steps, 3 rows agree and 3 rows with clock-dependent steps are `measured non-judging` with matching projections ([record](records/20261014-013947-s6-71-regtest-s3.md), the evidence for every row of this paragraph); the spec's side is `mempoolcheck` GREEN on 115 rows. Owed, named: the composition at the acceptance level of the insert rule with the silence (the frame lemmas that each stage returns the request it was given and leaves the recorded tip alone); a `ChainState`-level receive that supplies the active tip to the envelope (`lean/BsvChain/Chain.lean`); an inventory reading consults two rolling filters, the reject filter and the separate filter of recently removed held transactions (`Mempool.nonFinalRecentlyRemoved`), and is judged only when both are inside their wipe-free regimes (180,000 insertions between two resets at the defaults, `default_wipe_free_bound`; 15,000 insertions for the separate filter, `default_removed_wipe_free_bound`) with no declared false positive on either (`inventoryJudgment`, `inventory_judging_exact`, `removed_wipe_non_judging`, `inventory_judging_ideal`); other readings are recorded non-judging, never modeled bit for bit; the pin's third priority `normal` is the RPC's and is projected to `high` without limits ([SRC] `src/txn_validation_data.h:28–33`).

[M] 2026-10-14, #70: the frozen outputs and the confiscation whitelist are operator data, the explicit `OperatorLists` input of `lean/BsvChain/Frozen.lean` (the policy-only, ranged and confiscation records with their intervals and `policyExpiresWithConsensus`, `frozentxo_db.h:179–377`; the whitelist with its enforce heights, `:589–616`), installed by the RPCs' database effects (`freezePolicyOnly`, `freezeConsensus`, `unfreezePolicyOnly`, `whitelistTx`, `clearWhitelist`; `frozentxo_db.cpp:299–396,720–800,838–888`) and labeled policy throughout (rule 13): the reference's list named "consensus" is an operator list the node also applies at block connection. `OperatorLists.check` and `checkWhitelisted` are `CFrozenTXOCheck::Check` and `CheckConfiscationTxWhitelisted` (`frozentxo.cpp:37–83,133–171`); `OperatorLists.project` is the projection `checkTxInputs` reads, and the hook of #64 is filled: `ChainContext.connectionLists` defaults to `connectionFrozenLists`, which applies the connecting index's explicit soft consensus freeze (read from the current tree) and the depth waiver (`assumeWhitelisted`, the most-work target or an explicit best header; `validation.cpp:3529–3555`). `lean/BsvChain/Properties/Frozen.lean` proves, sorry-free and in the axiom walk: the derivation (`s6_frozen_projection_check`, `s6_whitelist_projection_check`); (a) `s6_policy_frozen_admission_refused` (`accept` completes with `bad-txns-inputs-frozen`, code 0x10, when every earlier stage passes, the relay word resolves and the head input's record is frozen on the policy predicate at the tip's successor; `s6_policy_only_frozen_on_policy` for a policy-only record) and `s6_policy_list_not_consulted_at_connection` (records all policy-only connect every block exactly as no records do); (b) `s6_ranged_frozen_refused_in_range` and `s6_ranged_frozen_block_step` (inside an interval the application and the block's transaction step refuse with code 0x13, the code `connectRun` turns into the soft consensus freeze) and `s6_ranged_frozen_connect_rejected` (`connectBlock` itself rejects with that verdict), `s6_ranged_frozen_outside_not_consulted` and `s6_ranged_outside_intervals` (outside every interval connection is connection with no records); (c) `s6_whitelisted_confiscation_lists_inert` and `s6_whitelisted_confiscation_applies` (a listed confiscation transaction at or beyond its enforce height is judged on either path as with nothing frozen), `s6_unlisted_confiscation_refused` (`bad-ctx-not-whitelisted` on either path), `s6_waiver_block_path_only` and `s6_confiscated_frozen_everywhere`; (d) `s6_explicit_freeze_check_noop`, `s6_explicit_freeze_connection_lists` and `s6_explicit_freeze_connects_unfrozen`. The connection laws rest on `connectBlock_lists_congr` (connection reads the lists only on the block path at the block's height). [M] 2026-10-14: (b)'s inside case reaches block connection: `s6_ranged_frozen_connect_rejected` concludes that `connectBlock` returns the frozen verdict, code 0x13 with `corruptionPossible` false, for the records' projection outside an explicit soft consensus freeze (`atBlock false w`, any whitelist waiver). Its premises: the connection's preparation succeeds for a non-genesis block; the body is a prefix, the offending transaction, then any suffix; the prefix of transactions (the coinbase among them) runs successfully from the coins view, ending in the view and sigop total the offending transaction is checked against; that transaction is ordinary (not coinbase, not a confiscation transaction), passes the structural loops, has its inputs available and passes the block's own input checks there; its head input's ranged record holds an interval containing the block's height (`validation.cpp:3290–3411`, `frozentxo.cpp:39–62`, `frozentxo_db.h:353–377`). The prefix's success and those earlier checks are premises, not conclusions. `connectRun`'s mapping of code 0x13 to `freezeBlockIndex` (`validation.cpp:3402–3407`) is executed by the corpus rows and is not restated as a theorem. The corpus `corpus/chain/frozen` (20 rows, every row policy) and its regtest column are in the [record](records/20261014-032207-s6-70-regtest-s3.md).

Each layer's issue adds its own (finality: `nLockTime = 0` is final, all-`SEQUENCE_FINAL` is final, the fee is
non-negative on every accepted transaction, #60; `applyTx` removes exactly the spent outpoints and adds exactly the
eligible spendable outputs under the creation era (`AddCoin` omits an unspendable output, `coins.cpp:45–64`,
`:548–565`), #61; the merkle roots of `[a, b, c]` and `[a, b, c, c]` are equal under the reference's padding rule (`consensus/merkle.cpp:18–50`;
a generalization needs a padding-equivalent suffix: duplicating an arbitrary suffix does not preserve every
root), the subsidy schedule's total is below `MAX_MONEY` (`amount.h:130`) for each pinned network's `ChainParams`, and over arbitrary `params` exactly when the halving interval is at most 210,000 (`subsidy_total_bound_iff`, #77; `2252–2262`; `chainparams.cpp:1037`, `:1211`, `:1333`, `:1460`), #63; regtest's no-retargeting precedence over its zero DAA activation height, and BIP30 enforcement under its height-and-hash exceptions, BIP34 ancestry shortcut and network-permitted disable switch (`3070–3105`), #69; the policy-frozen spend refused by the pool
and accepted at connection, #70; no ordinary required script check is omitted because of assumevalid, #73: the coinbase and genesis cases, the
cache's reuse and the confiscation bypass at `2864–2868` keep the stronger "every connected block ran every script
check" outside the statement).
Every theorem takes `params`, `cfg`, the oracle and `now` as arguments wherever its statement reads them, under
the hypotheses its statement names; one that fixes a network's record, the census defaults, the evaluator or a
literal time is an instance of a named general form or a statement about a concrete run (#77, §4.5).
Each is sorry-free and axiom-clean (rule 7), with an explainer, regenerated into `spec/` (#17's pattern).

[D] 2026-10-14 02:04:12 UTC, #73: `lean/BsvChain/Depth.lean`
defines the model depth decision and safe-mode projections; its model theorems
are in `lean/BsvChain/Properties/Depth.lean`. `s6_no_assumed_valid_checks_scripts`
requires `DepthWired` and a zero assumed-valid hash or absence of that hash from
the supplied tree, and concludes `checkScripts = true` for the supplied connection.
`withValidationDepth_wired` supplies the wiring premise for an explicitly
transformed context. `connectBlock_scripts_judged` describes serial applications
and queued oracle verdicts under successful non-genesis connection and
`checkScripts = true` premises. Explicit wired calls satisfy the depth-argument
deliverable; automatic internal coupling in the unchanged `connectTip` is deferred.
The context-indexed `Reachable` lift/history, stored best-header pointer, cached
fork-table update history and auxiliary client-field integration remain deferred.
The dropped `onChainOf_ancestry` lemma's reported kernel-recursion cause is unverified.
Reference interpretations, corpus observations and the complete scope list are in
the [#73 record](records/20261014-013925-s6-73-regtest-s3.md).


### 4.5 No clock, no network (#77)

Every transition takes `now : Time` and `params : ChainParams`; no `IO` appears under `lean/BsvChain/` outside
the evaluator's CLI; a lint leg fails on a clock read. The consensus adjusted-time predicates are at `6028` and
`6187` (both `GetAdjustedTime()`); the third call of `GetAdjustedTime()` in the file, `6554`, is the assembler's
template test (`TestBlockValidity` `6533`), outside this machine (#72). Policy also reads time for entry, expiry, the rolling fee's decay and the
scheduled retries (for example `txmempool.cpp:2628` and `time_locked_mempool.cpp:614`). All such reads consume
explicit inputs; validation elapsed time and scheduling observations are separately supplied and marked
non-judging when not reproducible. The reference's adjusted time is `GetTime()` plus `GetTimeOffset()` (`timedata.cpp:28–35`). `setmocktime` fixes
the `GetTime` input (`rpc/misc.cpp:1004–1005`; `utiltime.cpp:23–33`), not the offset. #66/#72 use a fresh private
instance, keep test peers' advertised times synchronized to the scenario, and record a zero offset for judging
scenarios; otherwise the offset must be an explicit input or the time-sensitive observation is non-judging.

[M] 2026-10-13: the lint is tools/chain_lint.py inside the pins leg; chain lint: GREEN [X] (21 files, 0 clock, IO or network reads under lean/BsvChain).

[M] 2026-10-14, the quantification half of #77: `tools/specgen.py` reads each chain-layer
theorem's statement and prints its quantification line on `spec/theorems.md` (for each of `params`, `cfg`, the
oracle and `now`: quantified by a binder, a context structure (`ChainContext`, `AdmissionContext`, `UtxoContext`)
or a predicate whose steps bind it (`Reachable`); fixed to a constant; or not an argument), and the count on
`spec/README.md`. Of 393 theorems under `lean/BsvChain/` [M], 190 quantify every parameter they take (90 all four),
182 take none of the four (codecs, merkle paths, filters, views), and 21 fix one: 13 are instances of a named
quantified general form, 2 of a named general form free of the four inputs (`versionObsolete_iff_floor`, over
every triple of activation heights), and 6 are statements about #68's concrete regtest run (`Properties/StaleRun.lean`), so
network-specific by design; none is flagged. Ten theorems are new, nine of them general forms an instance names and
`subsidyScheduleTotal_eq` the money bound's helper: `nextWorkPath_no_retargeting`,
`s6_no_retargeting_parent_bits`, `s6_no_retargeting_accepted_header_bits` and `nextWorkPath_retargeting` (the
difficulty path for every network, by `powNoRetargeting`), `subsidyScheduleTotal_eq` and `subsidy_total_bound_iff`
(the money bound holds exactly when the halving interval is at most 210,000: above it the general statement is
false), `rejectFilter_wipe_free_iff`, `removedNonFinalFilter_wipe_free_iff` and `validationAllowance_bounds` (every
configuration), and `recorded_oracle_agree` (every oracle); the network and default forms stay as their instances.
`s6_mainnet_version_floors` now reads its three heights from `ChainParams.mainnet`. The lint gains the parameter
check: a definition, instance or structure outside `Params.lean` that names a network's record or
`NodeConfig.defaults` is a hit unless allowlisted with a reason (4 allowlisted: the empty pool's two filter
defaults, `medianTimePast`'s default argument, #68's run context). The audit table is the
[#77 record](records/20261014-061017-s6-77-quantification-s1.md).

## 5. The oracle plan

### 5.1 SV-node regtest, driven through scenarios (#66; rule 10)

[M] 2026-10-14, #121: a corpus row may carry `"binary":"wallet"`; the runner then starts the second binary of the pin (`docs/PROVENANCE.md` 1a `reference.binary_wallet`, configured with the wallet; not the node of record) on the same `scenarios.conf`, and the row's token names it (`measured agree (wallet build): ...`); a row without the field runs on the node of record (`harness/src/scenarios/core.rs`, `Build`); `tools/node_scenarios.sh --wallet-only` replays those rows alone. Four rows carry it: `tip/flags--1` (its recipe reads the wallet's default-flag caller, `getreceivedbyaddress` at minconf 0, over a transaction admission holds non-final) and the three fee-ceiling rows `absurd-fee-above`, `absurd-fee-equality`, `absurd-fee-default-rpc` (the setting `maxtxfee`, policy, default 0.1 BSV, `src/validation.h:79`). On fresh wallet-enabled instances they measured [M] 4 agree, 0 diverge ([record](records/20261014-050737-s6-wallet-rows-regtest-s3.md); [the earlier record](records/20261014-045723-s6-wallet-rows-s3.md) is superseded). The four were unrealizable on the node of record, so the six families' column across the two binaries reads [D] 322 agree and 140 unrealizable of 472 (arithmetic on the s6-72 and wallet-rows-b records).

[M] 2026-10-14, #69: the chain leg now adds `chaincheck --eras corpus/chain/eras/eras.jsonl` to every chain replay (`tools/chain_leg.sh:51`). It replays [M] 38 [D] derived era rows node-free in [the era corpus](../corpus/chain/eras/eras.jsonl); their separate regtest column has [M] 11 agreements and 27 unrealizable rows, recorded in [the receipt](records/20261014-002257-s6-69-regtest-s3.md) [X]. The tripwire remains [M] 22 legs.

[M] 2026-10-14, #70: the chain leg adds `chaincheck --frozen corpus/chain/frozen/frozen.jsonl` to every chain replay (`tools/chain_leg.sh:54–55`). It replays [M] 20 [D] operator-list rows, every row policy (operator data), node-free in [the frozen corpus](../corpus/chain/frozen/frozen.jsonl). The replay judges the UTXO stage: `checkTxInputs` with the derived projection, and the explicit-freeze row through `atBlock`. The separate regtest column runs full admission (`sendrawtransaction`) and full block connection (`submitblock`) on fresh instances and has [M] 20 agreements, recorded in [the receipt](records/20261014-032207-s6-70-regtest-s3.md) [X]; the agreement is between those two boundaries. The chain replay with the frozen line in it measured a wall of [M] 41.269828 s (`tools/chain_leg.sh --built` at `6ab5cb90`, the same record). The tripwire remains [M] 22 legs.

The reference is the spec's own instance of the pinned build, the pattern of `harness/oracle/` (private regtest;
`listen=0`; RPC bound to the loopback; discovery and outbound public peers disabled, as `harness/oracle/bitcoin.conf`
sets `dnsseed=0`, `discover=0` and `upnp=0` and no outbound connection is configured; any test peer explicitly
restricted to the loopback; nothing broadcast outside the private scenario, rule 10), with `-txindex=1` for §3's
observables and the
chain parameters a scenario names (#69: regtest's compiled heights by default, the two an operator may set as
D97's instances do). A **scenario** under `corpus/scenarios/` is an initial chain and a list of steps, each with
its expected observations:

| step | the RPC (the handler `[SRC]`) | the machine's transition |
|---|---|---|
| submit a transaction | `sendrawtransaction` (`rpc/rawtransaction.cpp:1530`), `sendrawtransactions` (`:1798`) | `receiveTx` |
| mine a block on a named branch | `generatetoaddress` (`rpc/mining.cpp:227`), then `getblock` to read the block the node assembled (`JournalingBlockAssembler::CreateNewBlock`, `mining/journaling_block_assembler.cpp:80`; #72: observed, never predicted); `submitblock` (`rpc/mining.cpp:916`) for a block the harness assembles, as D97's road does | `receiveBlock` |
| invalidate, reconsider | `invalidateblock` (`rpc/blockchain.cpp:2732`), `reconsiderblock` (`:2770`) | `invalidateBlock`, `reconsiderBlock` |
| advance time | `setmocktime` (`rpc/misc.cpp:980`) | `now` |
| observe | `getrawmempool` (`rpc/blockchain.cpp:440`), `getrawnonfinalmempool` (`:502`), `getorphaninfo` (`:2675`), `getchaintips` (`:2497`), `getbestblockhash` (`:220`), `getblock` (`:1108`), `gettxout` (`:1923`), `getrawtransaction` (`rpc/rawtransaction.cpp:53`), `getmerkleproof` (`:2242`; [M] 2026-10-14, #75: with `getmerkleproof2` (`:2342`, JSON only at the pin, `format` `binary` refused with `-32602`) and the node's own `verifymerkleproof` (`:2527`), every served proof is decoded into the TSC view `BsvChain.Views.TscProof`, verified by `verifyTsc`, round-tripped through the binary codec and compared with the model of the node's branch generator; a one-transaction block gets no proof from either RPC (`-5`), the offset-0 reading is body-derived: the [proof-surface record](records/20261014-015319-s6-75-regtest-s3.md), scenario [2026-10-13-tsc-proof-surface](../corpus/scenarios/2026-10-13-tsc-proof-surface.md)) | `status` of every seen id, the tip, the pool sets |

The runner drives the node and the evaluator over the same steps and compares every observation; a divergence is
written as a scenario file with the step, both observations and the status the machine derives, classified as
data (D83: spec-wrong, implementation-wrong, open) and filed as a **Finding** on the issue it came from: a chain,
never a sentence (rule 4). The seed generator covers forks of depth one to three, double spends across branches,
orphans by a withheld parent, non-final transactions crossing the median time past, expiry and eviction under a
small `-maxmempool`. Observations taken under a validation budget are marked non-judging (#71). The record of a
run lives in `docs/records/`, and a `make check` leg replays the seed scenarios.

[M] 2026-10-12, under the maintainers' 16:27Z `intake go`: the
[scenario format and status-view table](../corpus/scenarios/README.md) seed
#66/#67 with [M] 2 scenarios and 20 declared [D] steps; the node column records per-row metadata independently of the spec projection ([record](records/20261012-163524-intake-22-s6.md)).

| seed scenario | [M] steps | observations owed to #66 |
|---|---:|---|
| [mempool-presence-terminal](../corpus/scenarios/2026-10-12-mempool-presence-terminal.md) | 10 | Admission, active mined conflict, policy expiry and invalidation/reconsideration beside the door's latched words. |
| [bumpless-beef-stored-proof](../corpus/scenarios/2026-10-12-bumpless-beef-stored-proof.md) | 10 | Node inclusion versus absent client proof, wallet storage/refusal, checked header/path delivery and the reorg variant; #65 path checks are measured in the [intake replay](records/20261013-141521-s6-65-intake-regtest-s3.md); #75's TSC codec remains owed ([M] 2026-10-13). |

[D] 2026-10-14, #119: the one-day incident intake route is written in the [scenario README](../corpus/scenarios/README.md) ("Incident intake, the one-day route"); met once on 2026-10-12 (two incidents filed on a program this spec serves, in the tree the day they were filed).

**The orphan and reject-cache scenarios need a peer, not an RPC.** A single RPC submission is `TxSource::rpc`
(`rpc/rawtransaction.cpp:1590`) and reaches the synchronous validator (`rawtxvalidator.cpp:38–42`), which supplies
an orphan handler only for P2P (`txn_validator.cpp:163–167`); missing inputs come back as an RPC error
(`rpc/rawtransaction.cpp:1636–1638`), not as a retained orphan; the synchronous batch path uses a temporary orphan
queue (`txn_validator.cpp:244–248`), which is not the persistent pool `getorphaninfo` reports `[SRC]`. Submitting a
parent later and resubmitting the child cannot establish that the node retained the child, and recent-reject
silence is likewise a P2P observation. So the persistent orphan and recent-reject scenarios use an isolated loopback
P2P peer in the private regtest harness: establish an empty orphan pool, submit exactly one child with an absent
parent, record the missing-parent request and the orphan count's increase, then submit the parent and observe the
child retried and admitted without resubmitting it; record RPC missing-input responses separately; for the reject
cache, record the relevant inventory and request traffic before and after the tip-change reset. No per-id orphan
claim is inferred from a count in an unconstrained pool. These observations belong to #66 and #71; they cannot wait
for S7 while S6's done-bars close. After `advanceTime` the runner observes the completion of the node's scheduled
maintenance before comparing an expiry or a non-final transition: `setmocktime` changes the time input, not the
scheduler's position. CPU-budget outcomes stay non-judging (#71).

[M] 2026-10-13, the fix-66b re-cut after mem3, chn3 and the leg change: chain/oracle [M] rows 472, realized 281, agree 281, diverge 0, rpc-precheck 7, unrealizable 147, needs-peer 20, pending 17; intake [M] rows 20, realized 20, agree 20, diverge 0, rpc-precheck 0, unrealizable 0, needs-peer 0, pending 0 ([record](records/20261013-061601-s6-66-agg-regtest-s3.md)). [X] R6 compares block rejection status and reason code with detail unobservable; R7 is a scope limit because the full admission machine rejects with code 259; R8 classifies literal-height rows individually unrealizable. RPC prechecks remain separate. The chain seed-scenario replay is the twenty-second leg in `all`, measured [M] 14.7 s on the box ([leg record](records/20261013-073532-s6-66-leg-s1.md)); the full replay `make chain-check` includes `--rows`. Remaining boundary observations, peer work, client replay and #65/#75 remain owed. [M] 2026-10-13, fix-pend2, one full fresh-instance run at `352d089c` answering the 15:3xZ lens on pend-66 under the maintainers' re-framing of the [M] 17 pending rows: chain/oracle [M] rows 472, realized 294, agree 294, diverge 0, rpc-precheck 7, unrealizable 151, needs-peer 20, pending 0; intake (three traces, main's runner) [M] 16 steps realized and agree, the 9 it does not reach keeping their s6-65 tokens; of the 17, [M] 13 realized and agree (the partial-disconnect rows with A's undo absent and `undo-count`, `output-metadata` by the instance's own undo records; the detector row's stage from the pin's scriptsChecked flag) and [M] 4 are individually unrealizable with cited reasons ([record](records/20261013-162245-s6-fix-pend2-regtest-s3.md); pend-66's run of `e7d28cff`, whose four measured-condition claims the lens did not hold, stays as [its record](records/20261013-144556-s6-pend-66-regtest-s3.md)). [M] 2026-10-13, the fix-peer re-cut: chain/oracle rows 472, measured 298, agree 298, diverge 0, rpc-precheck 7, unrealizable 150, needs-peer 0, pending 17; intake remains its separate inherited measured 20 agree rows ([fix record](records/20261013-181932-s6-fix-peer-regtest-s3.md)). The aggregate survivor projection is corrected as spec-wrong; all four era rows judge automatic child admission, and the no-growth hysteresis trigger agrees. Equality and literal 60/61-byte caps remain the three scoped walls. [M] 2026-10-13, the landing of peer-66/fix-peer with pend-66/fix-pend2/trim-66/fix-pend3 on main `e25002f8`: chain/oracle rows 472, measured/agree 311, diverge 0, rpc-precheck 7, unrealizable 154, needs-peer 0, pending 0; intake steps 25, measured/agree 25, diverge 0, rpc-precheck 0, unrealizable 0, needs-peer 0, pending 0; combined rows/steps 497, measured/agree 336, diverge 0, rpc-precheck 7, unrealizable 154, needs-peer 0, pending 0 ([landing record](records/20261013-184430-s6-66-column-s3.md)).

[M] 2026-10-13: the harness carries one peer, the reference test peer at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`; HeaderPeer is removed and `chain-receipt-order` and `chain-precious` were re-recorded through it, both agreeing in their recorded projections without instrument qualifiers (O-1 closed; [record](records/20261013-192835-s6-one-peer-regtest-s3.md)).

[M] 2026-10-13, reclass-66b under the maintainers' H6 road (c): the [M] 11 rows the RPC path's fixed validation mode left unrealizable were delivered by the loopback peer into the asynchronous validator on fresh instances: [M] 7 agree, 3 are `measured non-judging` (time-budget expiry under the default CPU validation clock ([SRC] src/txn_validation_config.h:36-37; src/init.cpp:2890-2895; src/validation.cpp:990-1006), #71) and 1 stays unrealizable with the P2P surface tried; chain/oracle rows 472, measured/agree 318, diverge 0, rpc-precheck 7, unrealizable 144, non-judging 3, needs-peer 0, pending 0; with intake's 25 steps, 497, measured/agree 343 ([record](records/20261013-200620-s6-reclass-66b-regtest-s3.md)).

[M] 2026-10-14 (#71): the reject-cache traffic this section asks for is recorded: six `p2pTrace` rows through the loopback peer, each inventory test under a named tip, before and after the reset; mempool rows 115, measured/agree 83, diverge 0, rpc-precheck 2, unrealizable 24, non-judging 6, needs-peer 0, pending 0; chain/oracle rows 478, measured/agree 321, diverge 0, rpc-precheck 7, unrealizable 144, non-judging 6, needs-peer 0, pending 0 ([record](records/20261014-013947-s6-71-regtest-s3.md)). The budget cells are listed there, every one `measured non-judging`, judged on a clock-free path, or unrealizable.

[D] 2026-10-14 02:04:12 UTC, #73: the chain leg now includes
`chaincheck --depth corpus/chain/depth/depth.jsonl`, with the scaled model replay
(shape scaled by 2,015 blocks). The [final-tree #73 record](records/20261014-013925-s6-73-regtest-s3.md)
measures [M] 64.451771 seconds for the total chain leg. About 37 seconds added is
[EST] the launch REPORT's estimate, not an independently measured delta. The earlier
[M] 14.7-second sentence above describes the earlier seed-scenario leg definition.

[M] 2026-10-14, #72: the runner reads every block the node assembles (`getblock` after `generatetoaddress`) and judges a row or step only on the observed body, never a predicted one; every instance runs on the scenario's mock time from start and relaunch, and the loopback peer advertises that time, so the recorded offset is zero ([M] 387 `clock` and 49 `peer-clock` receipts, all 0); the contract is in `harness/README.md`. A full fresh-instance run at `2fbacd5a`: chain/oracle rows 472, agree 318, diverge 0, rpc-precheck 7, unrealizable 144, non-judging 3, needs-peer 0, pending 0, equal to reclass-66b; intake 29 steps, of which 20 replayed and agree, including [assembly excludes a low-fee transaction](../corpus/scenarios/2026-10-13-assembly-excludes-low-fee.md) 4 of 4 by observation, and 9 keep their s6-65 tokens ([record](records/20261014-024631-s6-72-regtest-s3.md)).

[M] 2026-10-14, #72: the runner reads every block the node assembles (`getblock` after `generatetoaddress`) and judges a row or step only on the observed body, never a predicted one; every instance runs on the scenario's mock time from start and relaunch, and the loopback peer advertises that time, so the recorded offset is zero ([M] 372 `clock` and 49 `peer-clock` receipts, all 0); the contract is in `harness/README.md`. A full fresh-instance run at `450e9b09`: chain/oracle rows 472, agree 318, diverge 0, rpc-precheck 7, unrealizable 144, non-judging 3, needs-peer 0, pending 0, equal to reclass-66b; intake 29 steps, 29 agree, including [assembly excludes a low-fee transaction](../corpus/scenarios/2026-10-13-assembly-excludes-low-fee.md) 4 of 4 by observation; status views 16 of 16 ([record](records/20261014-032012-s6-72-regtest-s3.md)).

### 5.2 Teranode v0.16.0, the second oracle

Teranode has no `TxnValidation`, no mempool in the reference's sense and no orphan pool outside its legacy bridge
(its own comment: `services/validator/Validator.go:683–685`, the propagation surfaces keep nothing and the legacy
relay parks a transaction in netsync's orphan pool) `[SRC]`. Its machine, by service at the tag:

| service | what moves the state `[SRC]` | the reference's counterpart |
|---|---|---|
| `services/propagation` | `ProcessTransaction` `services/propagation/Server.go:1155`, `processTransactionInternal` `:1369` | the receive road |
| `services/validator` | `Validate` `services/validator/Validator.go:608`, `ValidateWithOptions` `:637` (the retry on a parent still committing, `:664–700`), `validateInternal` `:868`, `extendTransaction` `:2713`, `sendToBlockAssembler` `:2200`; the checks `services/validator/TxValidator.go:132` (`ValidateTransaction`), `:239`, `:272` (values, inflation), `:297` (BIP68), `:429` (inputs); the script verdict through GoBDK (`docs/PROVENANCE.md` §1) | `TxnValidation` with `CheckTxInputs` and the scripts |
| the UTXO store (`stores/utxo`) | `Store` `stores/utxo/Interface.go:368`: `Get` `:408`, `Unspend` `:458`, `SetMinedMulti` `:469`, `GetUnminedTxIterator` `:475`, `SetConflicting` `:541`, `SetLocked` `:567`, `MarkTransactionsOnLongestChain` `:594`, `SetBlockHeight` `:604`; the marks `stores/utxo/fields/fields.go:40` (`conflicting`), `:44` (`locked`), `:58` (`spentUtxos`), `:64` (`blockIDs`), `:72` (`deleteAtHeight`), `:79` (`unminedSince`), `:83` (`preserveUntil`) | the UTXO set, the pool's spent index and the status in one store: a mempool entry is an unmined record with `unminedSince` set |
| `services/subtreevalidation` | `ValidateSubtreeInternal` `services/subtreevalidation/SubtreeValidation.go:627`, `blessMissingTransaction` `:415`, `processMissingTransactions` `:1142`, `CheckBlockSubtrees` `services/subtreevalidation/check_block_subtrees.go:389` | the body's per-transaction checks, staged by subtree |
| `services/blockvalidation` | `ValidateBlock` `services/blockvalidation/BlockValidation.go:1668`, `ValidateBlockWithOptions` `:1688`, `validateBlockSubtrees` `:3516`, `checkOldBlockIDs` `:3621`, `setTxMinedStatus` `:1410` | `AcceptBlock` and `ConnectBlock`; `RemoveForBlock` |
| `services/blockassembly` | `GetMiningCandidate` `services/blockassembly/BlockAssembler.go:1969`, `AddTxBatchIfRoom` `:1818`, `RemoveTx` `:1830`, `handleReorg` `:2211`, `getReorgBlocks` `:2333`, `loadUnminedTransactions` `:3199`, `setBestBlockHeader` `:1226` | the journal and the assembler; the pool's reorg path |
| `services/blockchain` | `AddBlock` `services/blockchain/Server.go:1104`, `GetBestBlockHeader` `:1679`, `CheckBlockIsInCurrentChain` `:1705`, `GetChainTips` `:1747`, `InvalidateBlock` `:2380`, `RevalidateBlock` `:2497`, `GetBlockIsMined` `:2599`, `SetBlockMinedSet` `:2620`, `SetBlockSubtreesSet` `:2724`, `GetNextWorkRequired` `:1522` over `services/blockchain/Difficulty.go:74`, `GetMedianTimePastForHeights` `services/blockchain/median_time_past.go:63`, the chain-work order `services/blockchain/work/work.go:73`; the FSM `services/blockchain/fsm.go:17–43` (IDLE, RUNNING, CATCHINGBLOCKS under RUN, CATCHUPBLOCKS, STOP); the store's marks `stores/blockchain/Interface.go:377`, `:386`, `:400` | the header tree, `ActivateBestChain`, `InvalidateBlock`, the difficulty and the median time past |
| `services/legacy` | the bridge (`netsync`, `peer`, `blockchain` under it) | the P2P side (S7, S8's #98) |

Its verdict vocabulary is its error set (`errors/Error_types.go:59–64`: `ErrTxCoinbaseImmature`, `ErrTxConflicting`,
`ErrTxExists`, `ErrTxInvalid`, `ErrTxInvalidDoubleSpend`; `ErrSpent` `:42`; `ErrBlockInvalid` `:22`,
`ErrBlockParentNotMined` `:25`, `ErrBlockCoinbaseMissingHeight` `:15`, `ErrBlockPolicyDeclined` `:17`) `[SRC]`; #74
maps each state and error onto §3's `Status` or records that no function exists, and #67 fills the Teranode
column. Its defaults (`settings/settings.go:104` `excessiveblocksize` 4,294,967,296, `:108` `maxtxsizepolicy`
10,485,760, `:109` `minminingtxfee` 0.00000500 BSV/kB, `Teranode.Policy.MinMiningTxFee`) stand beside the reference's in #59's census as the second oracle's: **the
second oracle's defaults are never the rule.** The runner observes Teranode where its services expose an
equivalent observation (the gRPC of `services/blockchain`, the asset HTTP; S8's #97 writes the contract) on the
instance of #41 on the box, and a disagreement between the two oracles is a scenario witness filed against the
reference's reading, with the maintainers ruling which is consensus (rule 15), never a sentence.

## 6. The plan for S6, measured against the script layer's velocity

**The measure `[M]`.** From the birth commit (2026-09-21) to the close of 2026-10-07 the script layer closed 55
issues (#1 to #33, #35, #36, #38 to #57; the tracker by REST on 2026-10-12), proved 770 theorems (the axiom check
of `docs/records/20261007-023053-make-check-box.txt`) and recorded 26 corpora with 276,063 entries
(`HANDOFF.md` §0), on 11 landing days (the dates that carry commits: 2026-09-21 to 2026-09-29 and 2026-10-05 to
2026-10-06, by `git log --date=short`), at a fan-out of up to five parallel workers. One **landing day** of
that fan-out is the unit below: 5 issues, 70 theorems, 2.4 corpora. Every estimate is `[EST]` in landing days,
with the script-layer issue it is measured against; none is a date, and the calendar is re-dated on the measured
rate as `docs/PLAN.md` §2's velocity rule says.

| order | issue | depends on | track | `[EST]` landing days | measured against |
|---|---|---|---|---|---|
| 1 | #59 the census, and the library's skeleton (§4.1) | #58 | lean | 1 | #6 (a day; the chain layer has about three times the values); the package's birth has no precedent |
| 1 | #77 the lint half (no `IO`, `now` everywhere) | #58 | lean | 0.25 | the pins leg's pattern |
| 2 | #60 finality and the fee | #59 | lean | 1 | #22 (a day) |
| 2 | #66's runner half (the scenario format, the regtest driver, the observation set) | #58 | harness | 1.5 of 3 | #27 (two days with the instances) |
| 3 | #61 the UTXO set and `applyTx` | #60 | lean | 2 | #16 + #22 (three theorems, a corpus family) |
| 4 | #76 the oracle parameter | #61 | lean | 0.5 | #50's refinement pattern |
| 5 | #62 the mempool | #59, #61; #76 (this note: `accept` calls the oracle's interface, §2.1 row 12) | lean | 3 | the standardness gate and `TxPolicy` (a day for a tenth of this surface) |
| 4 | #63 block validity | #59, #61 | lean | 2 | #7 + #12 (a day each) |
| 6 | #64 the chain | #61, #62, #63; #76 (this note: `connectBlock` calls the oracle's interface, §4.3) | lean | 3 | #50 + #53 (a day each) plus four theorems |
| 7 | #69 chain-layer eras and parameters | #59, #63, #64 | lean | 1 | #20 + #23 (a day) |
| 7 | #65 merkle inclusion | #63, #64 | lean | 0.5 | #12's vectors |
| 7 | #70 frozen TXOs as parameters | #59, #61, #62, #64 | lean | 1 | #21 |
| 7 | #73 validation depth | #59, #64 | lean | 0.5 | #21 |
| 8 | #66's done-bar (the seed corpus run, the leg) | #64; #69 (this note: the regtest parameters, §4.2) | harness | 1.5 of 3 | D97's block road (a day) |
| 8 | #68 the five theorems | #61, #63, #64, #65 | lean | 1 | #25 (two work periods for 109 theorems) |
| 8 | #77 the rest (quantification over `params`) | #69 | lean | 0.25 | |
| 9 | #67 the status vocabularies | #64, #66 | lean | 1 | #30's report pattern |
| 9 | #71 the reject cache and budgets | #62, #66 | lean | 0.5 | #42's ruling |
| 9 | #72 harness realism | #66 | harness | 0.5 | D97 |
| 9 | #75 the proof surface | #65, #66 | lean | 0.5 | #12 |
| 10 | #74 Teranode's machine | #66, #67 | harness | 2 | #28 + #41 (two days) |
| | **total** | | | **24.5** | the script layer spent 11 landing days over 17 calendar days |

**Effort, not elapsed time.** The estimates total 24.5 issue allocations expressed in historical landing-day
units; this is aggregate effort, not an elapsed milestone duration, and a day of the whole historical fan-out is
not an additive per-worker elapsed day. The dependency graph follows the issues plus the three additions marked in the table: #59 → #60 → #61;
#76 follows #61; #62 follows #59, #61 and #76; #63 follows #59 and #61 and may proceed alongside #76; #64 follows
#61, #62, #63 and #76. After #64, #69 completes the parameter work needed by #66's seed-run done-bar; the runner's
preparation starts after #58. #65
follows #63 and #64; #68 follows #61, #63, #64 and #65; #67 follows #64 and #66; #74 follows #66 and #67.
Prototype implementations may land before the scenario runner exists, but their issues stay open until the
required regtest evidence is available. The maintainers derive an elapsed estimate from this graph and the actual
worker capacity after the corrected contracts (§9) are accepted. No calendar date is claimed. **The gates** are the
script layer's: every landing behind a box tripwire GREEN (rule 6, rule 17), a scenario leg joining the tripwire
at #66's done-bar, every theorem sorry-free and axiom-clean (rule 7), every page cited (rule 2), and the spec
pages regenerated with every theorem (rule 12). What would move the estimate: the Lake package's birth (#59's
day) and the regtest driver's reliability (#66), the two places the script layer had no precedent.

## 7. The amendment list (rule 9: the original sentence is gone)

Each sentence that said block-level consensus is outside was replaced in place by its new sentence citing #58
(rule 9: the old sentence is gone from its page and is not reproduced here); the lines are the files' on
2026-10-12 before the edit:

| file:line (on 2026-10-12, before the edit) | the sentence now there |
|---|---|
| `NORTH-STAR.md:17–18` (§2, constitution 01: the sentence `docs/PLAN.md:62` cited) | "The line between them is written down with citations, at the script layer and, since #58 (2026-10-07), through the transaction state machine the script verdict lives in (`docs/DESIGN-S6.md`), where the mempool is parameters almost entirely." The §7 rulings gain the charter's line and the header is re-stamped (the page's update rule). |
| `docs/PLAN.md:62` (§4, the risk row) | "scope creep into policy, or into the chain layers without the discipline \| the constitution: policy is a parameter at every layer; the transaction state machine is chartered as S6 (#58, 2026-10-07; `docs/DESIGN-S6.md`), executable, cited, judged by scenario witnesses \| NORTH-STAR §2; #58". §2's table and §7's tracker map gain the S6 row (the funnel rule). |
| `docs/DESIGN.md:465–466` (§5.5) | "The block-level rules (fees, the UTXO set, ordering, maturity, the block flags by height) are the transaction state machine's, chartered as S6 by #58 (2026-10-07; `docs/DESIGN-S6.md`), which consumes this semantics as its per-input script oracle under the UTXO's era (Q3); `docs/BLOCK-CONSENSUS.md` is the boundary's record as of 2026-10-05." |
| `docs/DESIGN.md:684–685` (§9 Q6's parenthesis on what differs outside `CScriptCheck`) | "(the mempool's standardness gate, modeled since 2026-09-28 by `BsvScript.Standard` and `TxPolicy` (§5.5), and the block-connection wrapper in `validation.cpp`, now assigned to the transaction state machine, S6 (#58; `docs/DESIGN-S6.md`)); D97 runs the `tx.*` family through both (#27)." (the lens's item 16) |
| `lean/BsvScript/TxRules.lean:14–15` (the module docstring) | "the block-level rules (fees, the UTXO set, ordering, maturity) are the transaction state machine's, S6 (#58; `docs/DESIGN-S6.md`), which calls this module's gate from `lean/BsvChain`." |
| `lean/BsvScript/Properties/TxValue.lean:10–11`, `:22–23`, `:37–38`, `:69–70` (the module docstring and the three theorems' explainers) | "The input-side UTXO set and fees belong to the transaction state machine (S6, #58; `docs/DESIGN-S6.md`: `applyTx`, #61) and are outside these statements." and the same in each explainer. `spec/` regenerated with them (the specgen leg). |
| `docs/BLOCK-CONSENSUS.md:3–9` (the opening), `:58` (§2's heading), `:63–64` and `:78–81` (the third kind's rows) | "**What this page records.** The script-layer boundary documented for #36 as of 2026-10-05 … Its rule inventory remains historical context. The transaction state machine chartered by #58 on 2026-10-07 now owns these chain-layer rules (`docs/DESIGN-S6.md`); this page does not define that machine." (main's pin-provenance sentences kept); §2's heading names the rules outside the script layer as of 2026-10-05, the state machine's since #58; the third kind's rows say "outside the script layer and a parameter of the state machine (#70)"; "the script layer never reads the UTXO set". |

Indexed with the note (rule 12): the state page `docs/STATE-OF-THE-WORLD.md` §3 gains the row; `docs/PROVENANCE.md`
§6 gains the entry for the public reads of §9; `docs/OWNERS` gains this page's glob. `NORTH-STAR.md` §5's "Not in
the output: … a policy specification" stands: the machine records the reference's policy as parameters with
their defaults and prescribes none (rule 1, rule 13).

## 8. The maintainers' ruling S6-1 (2026-10-12): the guarantee S6 makes to its consumers

**Context.** #36 closed block-level consensus as outside the script spec by constitution; on 2026-10-07 the maintainers
chartered it as S6, the transaction state machine (#58), because every production incident on the stack (a
wallet's coins drifting from the chain, a status nobody can define, a proof from an orphaned block, one key in two
wallets) is a question about one state and a transaction's place in it. This note writes that state, its
transitions and the status function down from bitcoin-sv v1.2.3 at the pin with Teranode v0.16.0 as the second
oracle, and two lenses of the other model family found the charter's promised theorems in need of re-statement (the
undo identity, inputs unspent, removal only by more work, inclusion from a path, the subsidy bound, BIP30's
enforcement, regtest's difficulty path), which this note re-states as the conditionals that hold (§4.4, §9). The maintainers implement the library
and import layout, routes OWNERS, reconciles the issue contracts and keeps SV-node as the reference with Teranode
as a witness column under the standing rules; one question is the maintainers', because it narrows what #58, #63, #64, #65, #68
and #69 promised in their charter.

**The ruling: what guarantee does S6 make to its consumers?**
Roads: (a) accept a pin- and corpus-scoped executable transaction-state model, with explicitly qualified
chain-level theorems (§4.4 rows 1, 3 and 4, the subsidy and BIP30 statements), stated observation limits (§3, §5.1) and the distinction between
path-root equality and authenticated inclusion (§4.4 row 5); (b) require header-and-path inclusion as an
additional proof obligation, its hash-commitment hypothesis stated as a hypothesis of the theorem (never an axiom,
rule 7), and re-estimate that scope; (c) leave #58 open pending a narrower charter.
**The ruling: (b).** The maintainers ruled road (b) on 2026-10-12 at 02:2xZ (their words: "yes I like your recommendation there... perfect"), after this note re-derived the options from the four public pages' own standard and withdrew its earlier recommendation of (a): T2 ("can the reader check every chain fact we serve with headers and a proof") and T6 make the consumer's one central chain fact, inclusion of a transaction by a header and a merkle path, a theorem rather than a stated distinction; the one move the method names, the machine as the only hand-written artifact, forbids leaving it in prose. The objection to (b), a hypothesis no scenario can discharge, dissolves in the form this specification already uses for ECDSA (DESIGN §3, Q9 A): the theorem is stated as a disjunction, the path's root equals the header's root implies either the transaction is in the block's list or a collision pair for the hash exists, proved in Lean over the hash as a definition with no axiom (rule 7), and the scenario replays the path check. The qualified chain-selection theorems (§4.4 rows 1 and 4) and the stated observation limits (§3, §5.1) stay as the honest list. The guarantee S6 makes to its consumers is therefore the pin- and corpus-scoped executable transaction-state model with header-and-path inclusion as a theorem over it; #65's deliverable is widened to that theorem and its scenario, and S6's allocation re-estimated at #65's start.

**Dropped from the card, each settled elsewhere.** *Where the machine lives* (a second `lean_lib` in the same
Lake package, the import direction a lint): the packaging decision under DESIGN §12's layer-4 interface,
recorded in §4.1. *Whose vocabulary the status speaks* (the spec's eight values, every client vocabulary a view
or a recorded no-function): settled by #58's deliverable and #67's charter, §3. *The second oracle's weight*
(SV-node the judge, Teranode a witness column, its defaults never the rule): settled by `NORTH-STAR.md` §6, rule 15,
tuple property 2 and #59's done-bar, §5.2. *Who owns the new trees* (`lean/BsvChain` to the Lean side, `corpus/scenarios` to
the harness side, the Teranode map to the second harness, this page on the harness side's line): the routing in `docs/OWNERS`, confirmed
at the landing, §4.1.

## 9. The record of the reads (2026-10-12, the note and its two lenses' fixes)

[M] 2026-10-12: the dated s6-62 note qualified the held-lock reading, but left the operative sentence in §2.1 row 5. Fix-62 now replaces that sentence in place with the accepted-lock rule and the held-update exception ([SRC] `src/txmempool.cpp:2257–2280`, `src/time_locked_mempool.cpp:67–85,114–156` at `6504a3af`). Expiry includes younger descendants, and the trim-size law permits an empty pool with residual fee-delta allocations ([SRC] `src/txmempool.cpp:2097–2110,2201–2220,2736–2792`). The [#62 record](records/20261012-172834-s6-62-mempool.md) records these qualifications and the unsigned target underflow at `src/validation.cpp:866–873`.

[M] 2026-10-12: §2.1 row 3 assumed the full-width median on the tip path; corrected to the pin's signed 32-bit narrowing at the caller and `int` parameter, while the block path retains `int64_t` ([SRC] `src/validation.cpp:1101–1106,5998–6004,6042–6056,6067–6074` at `6504a3af`); the [#60 record](records/20261012-130619-s6-60-finality.md) gives the witness and checks.

Every bitcoin-sv file cited above was read by `gh api repos/bitcoin-sv/bitcoin-sv/contents/<path>?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b`
(the `content` field, base64-decoded; a public read, rule 10) and its line numbers taken from the decoded file;
the blob sha is `git hash-object` of the decoded bytes. Teranode's lines were read with `git show v0.16.0:<path>`
in the Studio's clone at `4edb60a4` (the form `docs/PROVENANCE.md` §1 prescribes).

| UTC read time | path | lines | blob sha |
|---|---|---|---|
| 2026-10-12T00:01:43Z | `src/validation.cpp` | 7,746 | `f2f5fa101028f0f73955b06b339c37570c57251a` |
| 2026-10-12T00:01:44Z | `src/processing_block_index.cpp` | 96 | `87071187334e701a6de67fdd17e69ab6a221d846` |
| 2026-10-12T00:01:44Z | `src/txmempool.cpp` | 3,361 | `a2021721d358c49fd0692d25fb8dd5c52fa36130` |
| 2026-10-12T00:01:45Z | `src/consensus/merkle.cpp` | 328 | `ab89e2f1b6f2bc1a4afd18c2e6cb7319b4cae4a9` |
| 2026-10-12T00:01:45Z | `src/pow.cpp` | 297 | `989f483079930d539677ef30695f194ccc76310b` |
| 2026-10-12T00:01:45Z | `src/block_index.h` | 1,277 | `543097e796ad0fcc9f9b104f96030129e28dc569` |
| 2026-10-12T00:01:46Z | `src/block_index.cpp` | 466 | `25fb1bde9384a6b3ebe5ddc7a59ef35b70478dd0` |
| 2026-10-12T00:01:47Z | `src/coins.h` | 915 | `0aaa625f72dc9cf574439daa54e52a9895eb4917` |
| 2026-10-12T00:01:47Z | `src/txmempool.h` | 1,548 | `929141d8eae6e9f7c410022a0a21af8a07dce428` |
| 2026-10-12T00:01:47Z | `src/time_locked_mempool.h` | 226 | `6c28689dd966a4a46fc86d421828b84726010f45` |
| 2026-10-12T00:01:48Z | `src/orphan_txns.h` | 151 | `a8a81026723871aaf668cd6d801491426cf7fc99` |
| 2026-10-12T00:01:48Z | `src/consensus/validation.h` | 142 | `b158eef0b97f0e39a5bea16d55ed3b58095d615e` |
| 2026-10-12T00:01:49Z | `src/consensus/consensus.h` | 94 | `dd1614388a060ec674e7aea13d001cf9171e66ed` |
| 2026-10-12T00:01:49Z | `src/block_file_access.h` | 97 | `21bb222a1a7b3408c1ba6fe7186edfa124b1e637` |
| 2026-10-12T00:01:49Z | `src/txn_validator.cpp` | 801 | `c05c72729a24b9276136a8b00bc6c45abc6cc032` |
| 2026-10-12T00:01:50Z | `src/txn_double_spend_detector.h` | 90 | `39fd9aec4f5f2e7a78d1f7efd5ea4fbc8d640d0c` |
| 2026-10-12T00:01:50Z | `src/validation.h` | 1,190 | `32c4acd90ece216a23b8b201ced0d1a983f2d3f4` |
| 2026-10-12T00:01:51Z | `src/config.cpp` | 2,710 | `c81ff74c06b3430e8a01b5af381508a06f476811` |
| 2026-10-12T00:01:51Z | `src/chainparams.cpp` | 1,619 | `4dcea2b5b3f1c77b9b16157dc850f68d5e88d5b3` |
| 2026-10-12T00:01:52Z | `src/primitives/block.h` | 182 | `11c3b7c5ae39953c65a0329901c41b73dd4b0344` |
| 2026-10-12T00:01:52Z | `src/processing_block_index.h` | 33 | `4dde8c090684573a2b6886d66ab426ec00803f98` |
| 2026-10-12T00:01:53Z | `src/txn_validation_data.h` | 184 | `0fa48c8029f037526c698e9789baa184db221b4b` |
| 2026-10-12T00:01:53Z | `src/txn_validation_result.h` | 20 | `d0b2fa044c4249bda0c2ac1356a33061818cfb20` |
| 2026-10-12T00:05:23Z | `src/rpc/blockchain.cpp` | 3,839 | `c8eafc6f5bfd05029247d750a67f8de68b266baa` |
| 2026-10-12T00:05:24Z | `src/rpc/mining.cpp` | 974 | `634344e06e6fa1ed1ae6482c2c679c650367bb75` |
| 2026-10-12T00:05:24Z | `src/rpc/rawtransaction.cpp` | 2,637 | `c1c713dbd71fcc741473f0395209e9e98d119478` |
| 2026-10-12T00:05:25Z | `src/rpc/misc.cpp` | 1,346 | `48afb1091b622330f49cd03a31c978de8b1d8763` |
| 2026-10-12T00:05:25Z | `src/txn_recent_rejects.h` | 59 | `f2cbb5cfef0b357f96b07cf66979056d80351e51` |
| 2026-10-12T00:05:26Z | `src/net/net.cpp` | 3,658 | `aa52706836fc7fe1a61c21e622cb1dda71abe277` |
| 2026-10-12T00:05:27Z | `src/mining/journaling_block_assembler.cpp` | 439 | `cc44aefd1052e52be80438a7e80c2f1ed468c658` |
| 2026-10-12T00:05:27Z | `src/safe_mode.cpp` | 588 | `1aa6b7a37d498e50b4f3698df388c95dbe2d93fd` |
| 2026-10-12T00:05:28Z | `src/checkpoints.cpp` | 38 | `a493d4ce0880266067894e276052859cc7e4b346` |
| 2026-10-12T00:05:28Z | `src/frozentxo.h` | 141 | `366599ba4e123a32eb4c4b152e330ee1da0f009e` |
| 2026-10-12T00:05:29Z | `src/undo.h` | 143 | `cca2d4beb38046c05a097eceb85435498ab29cf4` |
| 2026-10-12T00:05:29Z | `src/chain.h` | 99 | `1fe2cb7f773e89f18c81d16467539cd08dd3be77` |
| 2026-10-12T00:05:29Z | `src/txn_validation_config.h` | 48 | `7f1563677308223aadcc55d10ccc8767ebc78f86` |
| 2026-10-12T00:05:30Z | `src/policy/policy.h` | 293 | `284ff428efc916d36424564ea86c484781782eab` |
| 2026-10-12T00:05:30Z | `src/txn_recent_rejects.cpp` | 27 | `68313f77a9c1ee29537d496541ff90127b12db22` |
| 2026-10-12T00:49:12Z | `src/coins.cpp` (the lens's fixes) | 568 | `e348fafb311cb7dc3e0bc94789e981363d509362` |
| 2026-10-12T00:49:14Z | `src/time_locked_mempool.cpp` (the lens's fixes) | 664 | `2984a35270a270859fe330cef5ad7b10eb6219e5` |
| 2026-10-12T00:49:15Z | `src/bitcoind.cpp` (the lens's fixes) | 254 | `97d94d4267fa7a41abdcdae131f846d9ddf2863f` |
| 2026-10-12T00:49:16Z | `src/rawtxvalidator.cpp` (the lens's fixes) | 139 | `933e98647fa732323338daeeda65db4e09710905` |
| 2026-10-12T00:49:17Z | Teranode `settings/settings.go` at `4edb60a4`, by `gh api repos/bsv-blockchain/teranode/contents/<path>?ref=4edb60a40c6628ff0ef60231c2628efd7103fde5` (the lens's fixes) | 858 | `2baec9f11f12d2e1305d1285f7c20af07e903d8e` |
| 2026-10-12T01:32:00Z | `src/init.cpp` (the second lens's fixes) | 4,177 | `9847ebd55b62f959e2b28d664120472c896c6125` |
| 2026-10-12T01:32:02Z | `src/orphan_txns.cpp` (the second lens's fixes) | 440 | `0632b1c9e7fc7cbbad87f108973634aefe697423` |
| 2026-10-12T01:32:06Z | `src/utiltime.cpp` (the second lens's fixes) | 104 | `8c72ea0c97fb7ec621c17025ab16d2fe46962673` |
| 2026-10-12T01:32:06Z | `src/timedata.cpp` (the second lens's fixes) | 119 | `6690ec2a2fde5a84671b60fdd1ef51da0cf1947e` |
| 2026-10-12T01:32:07Z | `src/amount.h` (the second lens's fixes) | 178 | `b6865905ee31a390dd719e05dc391e4b1b278cae` |

The lens's fixes (2026-10-12 00:49 UTC) re-read 25 of the files above by the same API with the blob
shas unchanged, read the five rows marked with its name, and verified every line citation the lens proposed before
it entered this note; the lens's own sample is in its report. The second lens's fixes (2026-10-12
01:31 to 01:32 UTC) re-read 14 of the files above by the same API with the blob shas unchanged, read the five rows
marked with its name, and verified every line the second lens proposed before it entered this note; the subsidy
arithmetic re-done: the schedule's sum at a halving interval of 300,000 is 2,999,999,996,700,000 satoshis, above
`MAX_MONEY`, and at 210,000 it is 2,099,999,997,690,000, below.

**Verified as the issues cite them.** `1009` `TxnValidation`, `2552` `CheckTxInputs`, `3775` `ConnectBlock`,
`4413` `FindMostWorkChain`, `4913` `ActivateBestChain`, `5749` `CheckBlock`, `processing_block_index.cpp:79`
`DisconnectBlock`; `227` `IsFinalTx`, `2252` `GetBlockSubsidy`, `4561` `ActivateBestChainStep`, `5230`
`InvalidateBlock`, `5736` `CheckBlockHeader`, `5933` `ContextualCheckBlockHeader`, `6039` `ContextualCheckBlock`,
`6028` and `6187` `GetAdjustedTime`, `3330` `bad-txns-inputs-missingorspent`, `2621` the coinbase maturity,
`2647` and `2660` the two fee reasons, `1151` and `1488` `txn-mempool-conflict`, `block_index.h:31`, `:722`,
`block_index.cpp:114`, `consensus/consensus.h:75`, `time_locked_mempool.h:34`, `orphan_txns.h:26`,
`txn_double_spend_detector.h:23`, `txmempool.cpp:298–304`, `consensus/merkle.cpp:284`, `:291`, `:312`,
`pow.cpp:22`, `:95`, `:150`, `net/net.cpp:3558`, `:3563`, `mining/journaling_block_assembler.cpp:80`,
`src/safe_mode.cpp:324`, `:572`, `checkpoints.cpp:14`, `frozentxo.h:21`, `config.cpp:49`, `:64`, `:83–84`, `:87`,
`:88–90`, `txn_validator.cpp:634`, the chain parameters of `chainparams.cpp` at the mainnet and regtest lines
#69 names, `consensus/validation.h:15–21`, `txmempool.h:1389` (the comment's last line) `[SRC]`.

**Where this note differs from an issue's citation.** #73 cites `chainparams.cpp:1222` as regtest's zero
`nMinimumChainWork`; at the pin `:1222` is STN's (`class CStnParams` at `:1195`) and regtest's is `:1480`.
#64's `block_file_access.h:17` is a forward declaration. `CBlockUndo` is defined at `undo.h:109–112`; it contains
`CTxUndo` records, whose spent-coin vector is at `undo.h:80–83` `[SRC]`. #70's `696` constructs `CFrozenTXOCheck` in `CheckInputsFromMempoolAndCache` (`657`), the mempool re-check
under the block word. Block connection constructs it at `3529`, with the depth waiver following at `3530–3542`
`[SRC]`. #62 cites `txn_validator.cpp:552` as the batch path; at the pin `:542–562` is
`executeTxnValidationNL`, the single-transaction call, and the batch path is `processNewTransactionsNL` at
`:567–605`. #69 cites `pow.cpp:113` for `GetNextCashWorkRequired`; at the pin `:113` is the call and the
definition is `:256`. The issues' implementers re-cut these lines when they land (rule 9).

**Where this note differs from an issue's contract** (each carried to the tracker by the maintainers before the issue
is implemented; the issue's implementer re-cuts its lines when it lands, rule 9). #64 and #68: theorem 1 (the undo
identity) holds under the no-overwrite condition and theorem 4 (removal only by more work) is false as written; §4.4
rows 1 and 4 state the conditionals that hold; theorem 3 (inputs unspent) quantifies over non-coinbase transactions
and the sequential UTXO view immediately before application (§4.4 row 3). #65, #68 and #75: theorem 5 (inclusion from a path and a header)
proves root equality; inclusion needs the stated commitment hypothesis and path-shape conditions (§4.4 row 5). #61:
"adds exactly the new ones" is "adds exactly the eligible spendable outputs" (§4.4). #73: "every connected block
ran every script check" is "no ordinary required script check is omitted because of assumevalid" (§4.4). #69: "on
regtest the post-DAA path is taken from height 0" reverses the control flow at `pow.cpp:107–113`; the theorem is
regtest's no-retargeting precedence (§4.2); its BIP30 theorem is conditional on the two height-and-hash exceptions, the
BIP34 ancestry shortcut and the permitted configuration switch, not an unconditional check at every other height
(§4.4). #63: "the same merkle root with duplicated trailing transactions" holds
for a padding-equivalent suffix only (§4.4); the subsidy-total theorem is stated for the pinned network parameters,
or with the explicit halving-interval bound, and #77 states that bound as an iff over every `params` (`subsidy_total_bound_iff`, §4.4). #70: its done-bar says "every row labeled policy"; the frozen lists are
the third kind, the operator-list mechanism, by the maintainers' ruling of 2026-10-05 (the legend above; §2.2), and the
companion settings are settings. #66: its done-bar needs #69's parameters (§4.2) and, with #71, the isolated P2P
scenarios for the orphan and reject-cache witnesses (§5.1), neither in its "Depends on" line. #59: its output path
is `lean/BsvScript/Params.lean`; this note's is `lean/BsvChain/Params.lean` (§4.1).

[M] 2026-10-12, #61 (`s6-61`): §1's coin value is represented as `Int` to retain the pin's spent sentinel and negative-value checks, its map as executable `Finmap`, and its frozen lists as effective height/path projections pending #70; §2.1's input stage keeps the pin's empty unavailable-input reason, while `applyTx` uses the block caller's `bad-txns-inputs-missingorspent`; §4.4's creation-era pruning uses the raw stored height, including the mempool sentinel, independently of the tip-successor substitution used for script judgment ([SRC] `src/coins.h:204–239`, `src/coins.cpp:45–64`, `src/validation.cpp:2557–2559,2667–2674,3326–3331` at `6504a3af`; [record](records/20261012-151100-s6-61-utxo.md)).

[M] 2026-10-12, #63 (`s6-63`): §2.2's coinbase-in-place shorthand separates at the pin into an empty-body check before size and `CheckCoinbase` after size; the contextual coinbase-height comparison is at [SRC] `src/validation.cpp:6085–6099`, and the source's version-majority comment describes height-gated code, while merkle mutation tests every actual sibling pair, not only a terminal pair ([SRC] `src/validation.cpp:5788–5827,5962–5967`, `src/consensus/merkle.cpp:46–50,210–213,263–279` at `6504a3af`; [record](records/20261012-164656-s6-63-block.md)).

*Update rule: a transition this page describes that a layer's issue finds different at the pin is corrected
here in the same landing, the old sentence gone (rule 9); a rule added to the reference at a later pin enters
the week after the recon reports it (rule 18).*

[M] 2026-10-12, #64/fix-64: reorg cleanup tests the finality boolean and removes a post-Genesis non-final entry ([SRC] `src/validation.cpp:5983–5986,6030–6036`, `src/txmempool.cpp:969–986` at `6504a3af`). Era-crossing clearing retains held/orphan stores and fee deltas ([SRC] `src/validation.cpp:4045`, `src/txmempool.cpp:1345–1363`); §2.2 now states this in place. Automatic failed undo re-admits earlier successful disconnections through the activation scope, whereas explicit invalidate/freeze failure uses remove-only cleanup ([SRC] `src/validation.cpp:4608–4616,4644–4668,5250–5255,4536–4539`). Successive connection batches retain that scope and its original work threshold ([SRC] `src/validation.cpp:4674–4705,4755–4767`). Maximal-work completion excludes successful early scheduling returns; the [chain record](records/20261012-190104-s6-64-chain.md) records the corrected witnesses and pending node observations.
