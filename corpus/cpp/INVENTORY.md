# corpus/cpp: the reference's own C++ unit tables, as a corpus family (#49)

*S3, lane harness-49, 2026-10-05. Sittings 1 to 7 of #49: the inventory (re-read whole in sitting 2, its OUT calls re-scanned in sitting 3, the third lens's two calls and the owner's ruling on mempool-state policy answered in sitting 4, the scoped lens's parser-layer call answered in sitting 5), the extraction contract, the instrumented build, and the extracted files (two by sitting 5; sittings 6 and 7 extract suite by suite, each suite's run in §5). No replay has run: no entry here has been compared with any engine, and nothing on this page claims a conformance result.*

The pin is bitcoin-sv **v1.2.2**, commit `879fc8b42168dd0e608dafd51b39c6dabad37d4d` (`docs/PROVENANCE.md` §1a). Every line number on this page is a line of a file at that commit. The reader's design is comment 5858114786 on #49.

## 0. What is here

| file | what |
|---|---|
| `corpus/cpp/INVENTORY.md` | this page: the inventory (§2), the extraction contract (§3), the instrumentation (§4), the run (§5) |
| `corpus/cpp/instrument.patch` | the instrumentation, applied to a copy of the pinned source; its sha256 is the manifest's `instrument_patch_sha256` and §5's newest run |
| `tools/cpp_extract.sh` | copies the pinned source, applies the patch, configures, builds `test_bitcoin`, runs the suites, writes the run's receipt, and only with a receipt writes the entries, the manifest and each suite's receipt; `--verify` reads the committed family only and checks every file against the manifest and its receipt (§5, the fix round) |
| `corpus/cpp/big_int_tests.jsonl` | 46 entries from `src/test/big_int_tests.cpp` (sitting 6), `predicate` entries of the number layer (`bint`) |
| `corpus/cpp/bn_op_tests.jsonl` | 249 entries from `src/test/bn_op_tests.cpp` (sitting 6) |
| `corpus/cpp/cscript_tests.jsonl` | 67 entries from `src/test/cscript_tests.cpp` (sitting 6): `GetOp2`'s failures and the sigop-count tables |
| `corpus/cpp/instruction_iterator_tests.jsonl` | 21 entries from `src/test/instruction_iterator_tests.cpp` (sitting 6): the decoder's failures on malformed bytes |
| `corpus/cpp/int_serialization_tests.jsonl` | 129 entries from `src/test/int_serialization_tests.cpp` (sitting 6), `predicate` entries of the number layer (the script-number encoding) |
| `corpus/cpp/limitedstack_tests.jsonl` | 2 entries from `src/test/limitedstack_tests.cpp` (sitting 6): the stack's byte limit |
| `corpus/cpp/lrshiftnum_tests.jsonl` | 36 entries from `src/test/lrshiftnum_tests.cpp` |
| `corpus/cpp/scriptnum_tests.jsonl` | 11,017 entries from `src/test/scriptnum_tests.cpp` (sitting 6), all `predicate` entries of the number layer |
| `corpus/cpp/sighash_tests.jsonl` | 1,000 entries from `src/test/sighash_tests.cpp` (sitting 6): the signature digest of 1,000 transactions drawn under the run's fixed seed |
| `corpus/cpp/sighashtype_tests.jsonl` | 5,121 entries from `src/test/sighashtype_tests.cpp` (sitting 6): the hash-type byte's fields |
| `corpus/cpp/sigopcount_tests.jsonl` | 61 entries from `src/test/sigopcount_tests.cpp` (sitting 6): sigop counts, `CheckRegularTransaction` at the sigop limit, and `VerifyScript` calls |
| `corpus/cpp/script_tests.jsonl.gz` | 135,669 entries from `src/test/script_tests.cpp` (sitting 6), gzipped (its JSONL is above 50 MB) |
| `corpus/cpp/multisig_tests.jsonl` | 56 entries from `src/test/multisig_tests.cpp` (sitting 6): `VerifyScript` calls, `IsStandardOutput`, `Solver` and `SignSignature`, every one with keys drawn at run time |
| `corpus/cpp/opcode_tests.jsonl.gz` | 144,381 entries from `src/test/opcode_tests.cpp`, gzipped (303 MB as JSONL; GitHub refuses a file above 100 MB) |
| `corpus/cpp/transaction_tests.jsonl` | 273 entries from `src/test/transaction_tests.cpp` (sitting 7) |
| `corpus/cpp/script_P2SH_tests.jsonl` | 150 entries from `src/test/script_P2SH_tests.cpp` (sitting 7) |
| `corpus/cpp/test_txnvalidator.jsonl` | 36 entries from `src/test/test_txnvalidator.cpp` (sitting 7) |
| `corpus/cpp/txvalidationcache_tests.jsonl.gz` | 286,727 entries from `src/test/txvalidationcache_tests.cpp` (sitting 7) |
| `corpus/cpp/blockcheck_tests.jsonl` | 3 entries from `src/test/blockcheck_tests.cpp` (sitting 7) |
| `corpus/cpp/miner_tests.jsonl` | 9 entries from `src/test/miner_tests.cpp` (sitting 7) |
| `corpus/cpp/rpc_tests.jsonl` | 2 entries from `src/test/rpc_tests.cpp` (sitting 7) |
| `corpus/cpp/manifest.json` | each file's source, its sha256 at the pin and its license header, its count, its sha256 (of the JSONL), the sha256 of the file as committed, the key-masked digest (§3), its verdict counts and its families |
| `corpus/cpp/receipts/<suite>.txt` | one receipt per file, written by the script from the run of record: the suite, the pin, Boost's counts of the suite's own process, the entries, the two digests, the seed, the run's date and the digests of the patch, the binary and the dump (§3, §5) |
| `corpus/cpp/LICENSE` | the reference's license, byte for byte from the pin (sha256 `d869a62568556cc7f61304b768074b40d7511ddb414f4e546101f860ee0ea853`) |

A stranger holding the pin regenerates the family with `SV_SRC=<the pinned tree> tools/cpp_extract.sh`: the script checks the pinned files it reads by sha256 before it copies anything (its list `PINNED`), and the manifest says what the output must hash to.

## 1. The license, stated and not decided

The entries derive from the reference's test sources, and each source's header names its license, recorded in the manifest as the file's `license_header`. Two licenses occur: the **Open BSV License Version 5** ("Distributed under the Open BSV software license, see the accompanying file LICENSE": `lrshiftnum_tests.cpp:1–2`, "Copyright (c) 2025 BSV Blockchain Association"; `opcode_tests.cpp:1–3`, "Copyright (c) 2018 The Bitcoin developers" with "Copyright (c) 2018-2019 Bitcoin Association") and the **MIT License** ("Distributed under the MIT software license, see the accompanying file COPYING": `bn_op_tests.cpp:1–3`, "Copyright (c) 2012-2015 The Bitcoin Core developers"). At the pin `COPYING` is one line, "The contents of this file have moved. Please see the file LICENSE.", and `LICENSE` carries the MIT License from its line 60, after the Open BSV License. The reference's license notice is kept beside the entries as `corpus/cpp/LICENSE`, copied byte for byte from the pin. Whether the public edition may ship these entries, and under which notice, is a question the owner has with counsel (the captain's plan, §6 item 6). This page states it and does not decide it.

## 2. The inventory

**The scope.** The pin has 167 `.cpp` files under `src/test`. 160 of them define test cases (1,074 cases); 7 are helpers with none (`dummy_config.cpp`, `jsonutil.cpp`, `scriptflags.cpp`, `sigutil.cpp`, `test_bitcoin.cpp`, `test_bitcoin_main.cpp`, `testutil.cpp`). Every case has one of five classes:

**The criterion** (the words of the third lens, 2026-10-05): a case is IN when any of its checks asserts on a script verdict, a transaction's validity, a standardness decision on a transaction, a script or an output, a sigop count or limit, or script-number arithmetic a script can reproduce, and that verdict is a function of the script, or of the transaction and its previous outputs, with policy as named parameters. A check that asserts something else (a decoding, an iteration, a field, a pointer, a container's size) does not make a case IN, however close to a verdict its subject lies. A decoder's failure on a malformed script counts as a verdict, because the interpreter returns `SCRIPT_ERR_BAD_OPCODE` on it (`src/script/interpreter.cpp:450-451`); successful decoding of well-formed bytes does not.

- **IN** when the criterion holds. The verdicts it names, as they occur at the pin: a script verdict (`EvalScript`, `VerifyScript`, a `ScriptError`, or a call whose return includes such a verdict: `SignSignature` returns true only when `VerifyScript` succeeds, `script/sign.cpp:198-208`); a transaction's validity (consensus: `CheckRegularTransaction`, `CheckTxInputs`, `CheckInputs`, finality, the sigops-per-transaction limit); a standardness decision on a transaction, a script or an output (`IsStandardTx`, `AreInputsStandard`, `IsDust`, the dust return, the consolidation rules, the solver's nonstandard template, and the predicates that are themselves such a decision: `IsPushOnly`, which decides `scriptsig-not-pushonly` at `script/standard.cpp:462-464`; `IsUnspendable`; `Solver`'s template recognition; the hash-type predicates); a sigop count or limit; script-number arithmetic a script can reproduce (including the max-length invariants at the widths custom parameters reach, as `opcode_tests.cpp:2391` already admits). The decoder (`GetOp2`, `decode_instruction`, `instruction_iterator`) is among them only through its failure: a failed `GetOp` on a malformed script returns `SCRIPT_ERR_BAD_OPCODE` at once (`src/script/interpreter.cpp:450-451`), so a check that asserts the decoder's failure on malformed bytes asserts on a call whose return includes a script verdict and makes a case IN; a check of the fields decoded from well-formed bytes asserts no verdict and does not. A check a case's fixture or setup helper runs counts: it runs inside the case. A policy decision is recorded as policy, with its parameter and default named, never as consensus (rule 1); where the node's accept is asserted (`CTxnValidator::processValidation`) and satisfies this criterion, the verdict includes consensus and policy and the row says so; an admission dependent on the live pool or chain beyond the transaction and its previous outputs belongs to the mempool-state class below.
- **COVERED** when the case reads one of the four JSON files the harness already replays: those rows are not extracted twice.
- **OUT BY RULING: operator-list mechanism** for the frozen-output and confiscation rules. The owner ruled on 2026-10-05 that they are a third kind: a block-validity mechanism driven by an operator's list, named and cited, outside the spec. Their source: the confiscation checks of `CheckTxInputs` (`validation.cpp:2564-2585`: `CFrozenTXOCheck::IsConfiscationTx`, `ValidateConfiscationTxContents`, the whitelist) and the frozen-output database (`frozentxo_db_tests.cpp`, `frozentxo_tests.cpp`, `frozentxo_mempool_tests.cpp`). These cases are neither IN nor plain OUT and are not extracted.
- **OUT BY RULING: mempool-state policy** when a check's verdict is a node's admission, replacement or eligibility decision that depends on the mempool's or the chain's state beyond the transaction and its previous outputs (a conflict with a pooled transaction, the pool's size limit and its eviction, which pooled transactions are eviction candidates, the pool's rolling minimum fee, a replacement's rate limit, eligibility for the primary mempool by the fee of the transaction's group in the pool). The owner ruled on 2026-10-05: tests of mempool-state policy are their own class, outside the corpus: each case named and cited at the pin, not extracted. Each row cites its decisive lines and the reference's code the verdict comes from. Pool and node bookkeeping that holds or records transactions without deciding one's admission stays OUT: the orphan pool, the recent-rejects cache, snapshots, the dump and its reload, the disk store, the mining journal and the validator's queues.
- **OUT** otherwise, with its reason; a case that tests serialization only is OUT and says so.

| the JSON the harness replays | read at the pin by | vendored as |
|---|---|---|
| `src/test/data/script_tests.json` | `script_tests.cpp` `script_json_test` (`1481–1532`); `script_build` (`713–1480`) asserts its rows are in it | `corpus/reference/bitcoin-sv-v1.2.2-script_tests.json` |
| `src/test/data/tx_valid.json`, `tx_invalid.json` | `transaction_tests.cpp` `tx_valid` (`175–192`), `tx_invalid` (`193–210`) | `corpus/reference/bitcoin-sv-v1.2.2-tx_valid.json`, `-tx_invalid.json` |
| `src/test/data/sighash.json` | `sighash_tests.cpp` `sighash_from_data` (`187–244`) | `corpus/sighash/bitcoin-sv-v1.2.2-sighash.json` |

**How it was read.** The case rows (each case, its line range, its number of check sites) are mechanical: every `BOOST_AUTO_TEST_CASE`, `BOOST_FIXTURE_TEST_CASE` and `BOOST_DATA_TEST_CASE` of the file, its lines up to the next case, and the number of lines in that range carrying `BOOST_CHECK`, `BOOST_REQUIRE`, `BOOST_TEST` or `BOOST_WARN` `[M]`. A check site inside a loop or a helper runs many times, so the run-time count of checks is larger (the two extracted files made 433,392 assertions in the run of §5 `[X]`). In sitting 1 two read-only reader passes of this lane classified 395 cases of 47 files, and 113 files were called OUT from a name scan alone. The lens of sitting 1 (Codex GPT-6.1-Sol) sampled 30 OUT calls against the pinned source and found seven groups wrong, so in sitting 2 **every case then marked OUT was re-read from the source**: 902 cases in 156 files, the 113 scanned files among them, split by file into eight batches, each read by a read-only reader pass of this lane that opened every file, read every case body and followed its helpers, and wrote each case's class, reason and decisive lines `[M]`. The lane then read the borderline calls itself and made them consistent: at that sitting it treated accepts asserted by fixtures or setup helpers as IN (`jba_selfish_mining_tests.cpp:130-132`, `miner_id_db_tests.cpp:282`, `miner_id_db_tests3.cpp:547`, `test_txnvalidator.cpp:227`); sitting 7 reapplies the owner's mempool-state ruling to the three deferred suites (below). The IN and COVERED cases of sitting 1 were not re-read in that pass; their rows say "sitting 1" under decisive lines. The lens of sitting 2 (Codex GPT-6-Astra) read 70 of sitting 2's OUT calls in 60 files and found 7 wrong (one pure predicate, six mempool-state verdicts); in sitting 3 the lane re-scanned all 853 OUT calls for those two kinds (below). The third lens (Codex GPT-6.1-Sol) read 74 of the exclusions after sitting 3 and found one wrong; sitting 4 answers it (below).

**The count.** Of the 1,074 cases: **190 IN**, **5 COVERED**, **805 OUT**, **7 OUT BY RULING: operator-list mechanism**, **67 OUT BY RULING: mempool-state policy** (before sitting 7: 213 IN, 5 COVERED, 805 OUT, 7 by the operator-list ruling, 44 by the mempool-state ruling; sitting 4: 209 IN, 5 COVERED, 809 OUT, 7 by the operator-list ruling, 44 by the mempool-state ruling; sitting 3: 214 IN, 5 COVERED, 805 OUT, 7 by the operator-list ruling, 43 of the mempool-state kind; sitting 2: 209 IN, 5 COVERED, 853 OUT, 7 OUT BY RULING; sitting 1: 167 IN, 5 COVERED, 902 OUT). Extracted so far: **190 IN cases** represented in **22 files**, from the suites named in the manifest and the run tables of §5. The column `entries` gives each case's entries in `corpus/cpp`; "not yet" marks an IN case a later sitting extracts.

**What sitting 2 changed.** The lens's seven groups, 13 cases, each re-called from the source: `script_P2SH_tests.cpp` `set` to IN (transaction standardness, `252-254, 285-292`); `sigopcount_tests.cpp` `test_max_sigops_per_tx` to IN (`424-446, 455`); `script_tests.cpp` `caching_invalid_signatures` to IN (`4310, 4324`); `multisig_tests.cpp` `multisig_Sign` to IN (`429-438`; `script/sign.cpp:198-208`); `frozentxo_db_tests.cpp` `db_tests`, `IsConfiscationTx_test`, `ValidateConfiscationTxContents_test` to OUT BY RULING; `scriptnum_tests.cpp` `lshift_max_length_invariant`, `add_max_length_invariant`, `sub_max_length_invariant`, `mul_max_length_invariant` to IN; `script_tests.cpp` `txout_IsDust` and `txout_IsDustReturnScript` to IN as policy on an output, with the parameter named (the dust threshold is fixed at 1 satoshi per spendable output and 0 for an unspendable one, `primitives/transaction.h:203-209`, not a setting at the pin: `-dustlimitfactor` and `-dustrelayfee` are removed, `init.cpp:2943-2947, 2995-2999`; the dust return feeds the free-consolidation policy, `-minconsolidationfactor`, default 20, `policy/policy.h:72`). **Beyond the seven, 36 OUT calls changed**: 34 to IN (`big_int_tests.cpp` `is_negative_`, `blockcheck_tests.cpp` `blockfail`, `jba_selfish_mining_tests.cpp` `NoSelfishNoThrottling`, `jba_selfish_mining_tests.cpp` `NoSelfishJustThrottling`, `jba_selfish_mining_tests.cpp` `SelfishAndThrottling`, `limitedstack_tests.cpp` `limitedstack_push_test`, `limitedstack_tests.cpp` `limitedstack_insert_test`, `miner_id_db_tests.cpp` `InitialiseFromExistingChain`, `miner_id_db_tests.cpp` `UpdatesToBlockchain`, `miner_id_db_tests.cpp` `KeyRotation`, `miner_id_db_tests.cpp` `RecentBlocksTracking`, `miner_id_db_tests.cpp` `InvalidBlock`, `miner_id_db_tests3.cpp` `InitialiseFromExistingChain`, `miner_id_db_tests3.cpp` `UpdatesToBlockchain`, `miner_id_db_tests3.cpp` `KeyRotation`, `miner_id_db_tests3.cpp` `KeyRotationFork`, `miner_id_db_tests3.cpp` `RecentBlocksTracking`, `miner_id_db_tests3.cpp` `InvalidBlock`, `miner_id_db_tests3.cpp` `SwitchVersion`, `miner_id_db_tests3.cpp` `RotateVersion`, `miner_id_db_tests3.cpp` `PartialRevocation`, `miner_id_db_tests3.cpp` `PartialRevocationFork`, `miner_id_db_tests3.cpp` `PartialRevocationPruned`, `miner_id_db_tests3.cpp` `RevokemidRevocation`, `miner_id_db_tests3.cpp` `RecoverReputation`, `miner_id_db_tests3.cpp` `FullRevocation`, `miner_id_db_tests3.cpp` `FullRevocationFork`, `opcode_tests.cpp` `negative_valtype_test`, `rpc_tests.cpp` `rpc_rawsign`, `script_tests.cpp` `script_Solver`, `script_tests.cpp` `solver_MultiSig_Decode_Check`, `test_txnvalidator.cpp` `txnvalidator_doublespend_synch_api`, `transaction_tests.cpp` `tst_tx_toJson_OP_RETURN`, `txvalidationcache_tests.cpp` `tx_mempool_block_doublespend`) and 2 to OUT BY RULING (`frozentxo_db_tests.cpp` `db_thread_safety_tests`, `frozentxo_mempool_tests.cpp` `mempool_RemoveFrozen`). Two sitting-1 IN calls also moved, to OUT BY RULING under the ruling: `frozentxo_tests.cpp` `negative_Consensus_CheckTxInputs`, `frozentxo_tests.cpp` `confiscationTransaction_CheckTxInputs`.

**What sitting 3 changed.** All 853 OUT calls were re-scanned for the two kinds the lens of sitting 2 found, and every case that fits moved, its decisive lines read at the pin. *A pure predicate wrongly OUT*, 5 cases to IN: `script_tests.cpp` `script_IsPushOnly_on_invalid_scripts` (the lens's, `3688`), and beyond it `script_tests.cpp` `script_IsUnspendable` (`3938-3943`, the dust threshold), `multisig_tests.cpp` `multisig_Solver1` (`293, 309, 341, 358, 381, 383`, output and input standardness), `sighashtype_tests.cpp` `sighash_construction_test` (`76-81`, `88`, `112-138`, SIG_HASHTYPE) and `instruction_iterator_tests.cpp` `instruction_iterator_happy_case`, which sitting 4 moved OUT again (below). *Mempool-state verdicts*, 43 cases to the mempool-state class (OUT BY RULING since sitting 4): the lens's six (`time_locked_mempool_tests.cpp` `MempoolAddTest`, `UpdateTest`, `RateLimitUpdateTest`; `test_txnvalidator.cpp` `txnvalidator_doublespend_synch_batch_api`; `invalid_txn_publisher_tests.cpp` `callback`; `mempool_tests.cpp` `SecondaryMempoolDecisionTest`) and 37 beyond them: `time_locked_mempool_tests.cpp` `DoubleSpendTest`; `test_txnvalidator.cpp` `double_spend_detector`, `txnvalidator_doublespend_asynch_api`; the five other cases of `invalid_txn_publisher_tests.cpp` (each runs the same setup helper, whose check at `86` asserts the detector's verdict); `mempool_tests.cpp` `SecondaryMempoolStatsTest`, `SecondaryMempoolComplexChainTest`, `InfoAllTest`, `MempoolSizeLimitTest`; all 12 cases of `mempool_limit_tests.cpp`; all 5 cases of `test_double_spend_detector.cpp`; `eviction_candidates_tracker_tests.cpp` `single_long_chain`, `broad_tree`, `secondary_mempool_first`; `cpfp_tests.cpp` `group_forming_and_disbanding`, `group_recalculation_when_removing_for_block`, `mempool_rebuild`, `journal_groups`, `conflicts`. So 41 calls moved beyond the lens's seven (4 to IN, 37 to the mempool-state class). The sentence of sitting 2 that kept the non-final pool and the double-spend conflicts OUT "as pool bookkeeping", and the row reasons that said "no rule on the transaction alone", are gone: the done-bar does not say "transaction alone" and no ruling supports it. `txnvalidator_doublespend_synch_api` stays IN for the accept its helper asserts (`227`); the rejection of its second spend (`231`, `542`, `562`) is of the mempool-state kind and is not extracted. Three flag-selection cases stay OUT as border calls named in their rows (`script_tests.cpp` and `verify_script_flags_tests.cpp` `get_script_verify_flags`, `verify_script_flags_tests.cpp` `get_block_script_flags`): their result is a function of block heights, the activation heights and node settings, not of the script or the transaction. The confiscation case's decisive lines were corrected to `frozentxo_tests.cpp:148-149`.

**What sitting 4 changed.** The third lens (Codex GPT-6.1-Sol) read 74 exclusions in 58 files and returned NOT HELD on two calls; it upheld the four defended kinds, the fifteen mempool-state cases it checked and the totals. The owner ruled on the mempool-state class the same day (§2's class list). Moved: `eviction_candidates_tracker_tests.cpp` `group_test` from OUT to OUT BY RULING: mempool-state policy (its candidate counts at `367, 369, 372` assert eviction eligibility as pooled children and groups change); the rest of that file re-read, `performance` stays OUT (disabled at the pin, asserting no candidate). `instruction_iterator_tests.cpp` `instruction_iterator_happy_case` from IN to OUT (its checks at `139, 144-151` assert iteration, decoded fields and pointers of well-formed bytes, no verdict). Sitting 4 also moved its three siblings and `cscript_tests.cpp` `GetOp2` OUT; sitting 5 restored all four (below). Net of sitting 5, sitting 4 moved two calls: 1 IN to OUT, 1 OUT to OUT BY RULING.

**What sitting 5 changed.** The scoped lens (Codex GPT-6-Astra) read the interpreter for the parser-layer question: at the pin a failed `script.GetOp(...)` returns `SCRIPT_ERR_BAD_OPCODE` at once (`src/script/interpreter.cpp:450-451`), so a check that asserts the decoder's failure on a malformed script asserts on a call whose return includes a script verdict (the criterion above). Restored to IN, each with its decisive line: `instruction_iterator_tests.cpp` `decode_instruction_tests` (the false status asserted at `102`, among its inputs the truncated push `{1}` at `27`); `too_short_single_instruction` (the truncated push's failure sentinel, `OP_INVALIDOPCODE` with an empty operand, expected at `168` and asserted at `169`); `too_short_two_instructions` (the second, truncated push's failure sentinel at `180`, asserted at `192, 194`); `cscript_tests.cpp` `GetOp2` (the false status asserted at `64`, among its inputs the truncated `{1}` at `41`). `instruction_iterator_happy_case` stays OUT (well-formed decoding only, `144`); `eviction_candidates_tracker_tests.cpp` `group_test` stays in the mempool-state class. Then every OUT row was re-scanned once for a check of a decode or parse failure on malformed bytes, with the pinned `src/test` searched for every caller of `GetOp`, `GetOp2`, `decode_instruction`, the instruction iterator, `ScriptToAsmStr` and `SCRIPT_ERR_BAD_OPCODE`; nothing else moved. The border calls read: `core_io_tests.cpp`'s `ParseScript` failures (`58-61, 81-116, 181-206`) are the text notation's parser, whose throw never reaches the interpreter; `script_tests.cpp` `script_GetScriptAsm` prints well-formed scripts only (`3691-3818`); `blockcheck_tests.cpp` `block_bounds_check` asserts the throw of `GetHeightFromCoinbase` (`131`), a block-level reader of its own (`primitives/block.cpp:56-77`), not the script decoder; the miner-info failure cases (`miner_info_doc_tests.cpp:196-233, 1075-1106`) assert miner-info errors on decodable scripts. Four calls moved, OUT to IN. No second reader has re-read sitting 5's calls.

**What sitting 7 re-read.** The 15 cases of `miner_id_db_tests3.cpp`, 5 of `miner_id_db_tests.cpp` and 3 of `jba_selfish_mining_tests.cpp` were re-read case by case through their helpers against the owner's 2026-10-05 mempool-state ruling before extraction. All 23 moved from IN to OUT BY RULING: mempool-state policy. The fixture/helper asserts live admission, and the case bodies check chain-derived database state or pool/package/template eligibility; no independent transaction/prevout validity predicate is asserted. Every reclassified row names its decisive source lines; the scope notes in §5 explain each suite. Sitting 7 therefore addresses its 52 cases as 29 extracted plus 23 excluded by ruling. The total is now 190 IN, all represented by entries after the crypto extraction under owner C1.

### 2a. The files with an IN, COVERED or OUT BY RULING case (35 files)

**`src/test/big_int_tests.cpp`** (34 cases; 17 IN, 17 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `default_construction` | `28–35` | 1 | OUT | bint construction and assignment, no arithmetic | `28-35` | none: OUT |
| `int_construction` | `36–44` | 5 | OUT | bint construction from int, no arithmetic | `36-44` | none: OUT |
| `int64_t_construction` | `45–53` | 5 | OUT | bint construction from int64, no arithmetic | `45-53` | none: OUT |
| `size_t_construction` | `54–59` | 2 | OUT | bint construction from size_t, no arithmetic | `54-59` | none: OUT |
| `is_negative_` | `60–66` | 3 | IN | number layer, as a script (sign test of bint, reproducible as x 0 OP_LESSTHAN) | `62-64` | 3 |
| `equality` | `67–93` | 10 | IN | number layer, as a script | sitting 1 | 3 |
| `inequality` | `94–101` | 2 | IN | number layer, as a script | sitting 1 | 1 |
| `cmp` | `102–116` | 8 | IN | number layer, as a script | sitting 1 | 2 |
| `move_construct` | `117–123` | 1 | OUT | c++ move semantics | `117-123` | none: OUT |
| `move_assign` | `124–131` | 1 | OUT | c++ move semantics | `124-131` | none: OUT |
| `copy_assign` | `132–146` | 3 | OUT | c++ copy semantics | `132-146` | none: OUT |
| `swap` | `147–155` | 2 | OUT | c++ swap | `147-155` | none: OUT |
| `output_streamable` | `156–170` | 2 | OUT | printer | `156-170` | none: OUT |
| `add` | `171–186` | 2 | IN | number layer, as a script | sitting 1 | 2 |
| `sub` | `187–202` | 2 | IN | number layer, as a script | sitting 1 | 2 |
| `mult` | `203–218` | 2 | IN | number layer, as a script | sitting 1 | 2 |
| `div` | `219–234` | 2 | IN | number layer, as a script | sitting 1 | 2 |
| `mod` | `235–250` | 2 | IN | number layer, as a script | sitting 1 | 2 |
| `negate` | `251–261` | 1 | IN | number layer, as a script | sitting 1 | 6 |
| `lsb` | `262–267` | 1 | OUT | c++ low-byte accessor, no opcode reads it as a number | `262-267` | none: OUT |
| `bitwise_and` | `268–321` | 1 | OUT | numeric (sign-magnitude) and; OP_AND is bytewise on equal-length operands (interpreter.cpp:1087), no numeric and opcode | `268-321` | none: OUT |
| `bitwise_or` | `322–367` | 1 | OUT | numeric (sign-magnitude) or; OP_OR is bytewise on equal-length operands, no numeric or opcode | `322-367` | none: OUT |
| `shift_left` | `368–391` | 1 | IN | number layer, as a script | sitting 1 | 8 |
| `shift_left_bint_max_script_len` | `392–402` | 1 | IN | number layer, as a script | sitting 1 | 1 |
| `shift_left_bint_exceeds_int_max` | `403–410` | 1 | IN | number layer, as a script | sitting 1 | 1 |
| `shift_right` | `411–433` | 1 | IN | number layer, as a script | sitting 1 | 8 |
| `shift_right_bint_max_script_len` | `434–444` | 1 | IN | number layer, as a script | sitting 1 | 1 |
| `shift_right_bint_exceeds_int_max` | `445–452` | 1 | IN | number layer, as a script | sitting 1 | 1 |
| `absolute_value` | `453–463` | 2 | IN | number layer, as a script | sitting 1 | 1 |
| `to_string` | `464–476` | 2 | OUT | printer | `464-476` | none: OUT |
| `to_size_t_limited` | `477–487` | 2 | OUT | c++ conversion accessor on in-range values | `477-487` | none: OUT |
| `to_int64_t_test` | `488–502` | 3 | OUT | c++ conversion to int64 and its throw, not on a script path | `488-502` | none: OUT |
| `max_size` | `503–523` | 0 | OUT | bint storage capacity check, no check site asserts a script outcome | `503-523` | none: OUT |
| `serialized_size_test` | `524–571` | 2 | OUT | c++ consistency of serialized_size with serialize().size() | `524-571` | none: OUT |

**`src/test/blockcheck_tests.cpp`** (2 cases; 1 IN, 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `blockfail` | `43–111` | 1 | IN | transaction verdict, consensus (CheckCoinbase via CheckBlock): reject reasons bad-cb-missing and bad-cb-length singled out | `71, 78; src/validation.cpp:578-590` | 3 |
| `block_bounds_check` | `112–134` | 1 | OUT | block-level (GetHeightFromCoinbase throws on a malformed coinbase script read), no transaction verdict | `130` | none: OUT |

**`src/test/bn_op_tests.cpp`** (18 cases; 18 IN)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `bint_unary_ops` | `34–121` | 4 | IN | script verdict | sitting 1 | 33 |
| `bint_binary_ops` | `122–235` | 4 | IN | script verdict | sitting 1 | 44 |
| `bint_ternary_ops` | `236–315` | 4 | IN | script verdict | sitting 1 | 15 |
| `bint_bint_numequalverify` | `316–384` | 5 | IN | script verdict | sitting 1 | 4 |
| `operands_too_large` | `385–493` | 5 | IN | script verdict | sitting 1 | 60 |
| `op_bin2num` | `494–542` | 5 | IN | script verdict | sitting 1 | 12 |
| `op_num2bin` | `543–622` | 4 | IN | script verdict | sitting 1 | 21 |
| `op_depth` | `623–656` | 4 | IN | script verdict | sitting 1 | 3 |
| `op_size` | `657–703` | 4 | IN | script verdict | sitting 1 | 2 |
| `op_pick` | `704–746` | 5 | IN | script verdict | sitting 1 | 3 |
| `op_roll` | `747–805` | 13 | IN | script verdict | sitting 1 | 3 |
| `op_split` | `806–854` | 7 | IN | script verdict | sitting 1 | 3 |
| `op_lshift` | `855–905` | 5 | IN | script verdict | sitting 1 | 13 |
| `op_rshift` | `906–957` | 5 | IN | script verdict | sitting 1 | 14 |
| `op_rshift_far` | `958–983` | 3 | IN | script verdict | sitting 1 | 1 |
| `op_lshift_far` | `984–1029` | 3 | IN | script verdict | sitting 1 | 1 |
| `op_checksig` | `1030–1074` | 4 | IN | script verdict | sitting 1 | 2 |
| `op_checkmultisig` | `1075–1161` | 6 | IN | script verdict | sitting 1 | 15 |

**`src/test/cpfp_tests.cpp`** (6 cases; 1 OUT, 5 OUT BY RULING, mempool-state)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `group_forming_and_disbanding` | `208–393` | 0 | OUT BY RULING: mempool-state policy | eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`), a child paying for its parents in the pool (CPFP groups); the case's BOOST_ASSERT lines are live at the pin (NDEBUG is refused, src/validation.cpp:78) | `257-304, 353-354, 380-387; 202 via 391` | none: by ruling |
| `group_recalculation_when_removing_for_block` | `394–462` | 0 | OUT BY RULING: mempool-state policy | eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`), a child paying for its parents in the pool (CPFP groups); the case's BOOST_ASSERT lines are live at the pin (NDEBUG is refused, src/validation.cpp:78) | `434-456; 202 via 460` | none: by ruling |
| `mempool_rebuild` | `463–518` | 0 | OUT BY RULING: mempool-state policy | eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`), a child paying for its parents in the pool (CPFP groups); the case's BOOST_ASSERT lines are live at the pin (NDEBUG is refused, src/validation.cpp:78) | `500-506; 202 via 515` | none: by ruling |
| `journal_groups` | `519–588` | 9 | OUT BY RULING: mempool-state policy | eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`), a child paying for its parents in the pool (CPFP groups); the case's BOOST_ASSERT lines are live at the pin (NDEBUG is refused, src/validation.cpp:78) | `565; 202 via 532` | none: by ruling |
| `conflicts` | `589–717` | 5 | OUT BY RULING: mempool-state policy | eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`), a child paying for its parents in the pool (CPFP groups); the case's BOOST_ASSERT lines are live at the pin (NDEBUG is refused, src/validation.cpp:78) | `623, 630` | none: by ruling |
| `double_spend_notifications` | `718–780` | 2 | OUT | mempool cpfp groups, journal and block-template bookkeeping (AddUnchecked, RemoveForBlock) | `718-780` | none: OUT |

**`src/test/crypto_tests.cpp`** (11 cases; 3 IN, 8 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `ripemd160_testvectors` | `274–294` | 0 | IN | digest layer, as a script (OP_RIPEMD160) | sitting 1 | 10 |
| `sha1_testvectors` | `295–313` | 0 | IN | digest layer, as a script (OP_SHA1) | sitting 1 | 10 |
| `sha256_testvectors` | `314–349` | 0 | IN | digest layer, as a script (OP_SHA256) | sitting 1 | 11 |
| `sha512_testvectors` | `350–396` | 0 | OUT | hash / cipher primitive with no opcode (sha512, hmac, aes, chacha20) or a bit-count utility | `350-396` | none: OUT |
| `hmac_sha256_testvectors` | `397–437` | 0 | OUT | hash / cipher primitive with no opcode (sha512, hmac, aes, chacha20) or a bit-count utility | `397-437` | none: OUT |
| `hmac_sha512_testvectors` | `438–484` | 0 | OUT | hash / cipher primitive with no opcode (sha512, hmac, aes, chacha20) or a bit-count utility | `438-484` | none: OUT |
| `aes_testvectors` | `485–520` | 0 | OUT | hash / cipher primitive with no opcode (sha512, hmac, aes, chacha20) or a bit-count utility | `485-520` | none: OUT |
| `aes_cbc_testvectors` | `521–599` | 0 | OUT | hash / cipher primitive with no opcode (sha512, hmac, aes, chacha20) or a bit-count utility | `521-599` | none: OUT |
| `chacha20_default_ctor_zeroes_state` | `600–605` | 1 | OUT | hash / cipher primitive with no opcode (sha512, hmac, aes, chacha20) or a bit-count utility | `600-605` | none: OUT |
| `chacha20_testvector` | `606–647` | 0 | OUT | hash / cipher primitive with no opcode (sha512, hmac, aes, chacha20) or a bit-count utility | `606-647` | none: OUT |
| `countbits_tests` | `648–668` | 3 | OUT | hash / cipher primitive with no opcode (sha512, hmac, aes, chacha20) or a bit-count utility | `648-668` | none: OUT |

**`src/test/cscript_tests.cpp`** (4 cases; 3 IN, 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `GetOp2` | `18–70` | 3 | IN | script verdict: the decoder's failure on malformed bytes, which the interpreter returns as `SCRIPT_ERR_BAD_OPCODE` (`src/script/interpreter.cpp:450-451`); the false status asserted for the truncated push `{1}` (`41`) and the other malformed encodings (`40-55`); its well-formed rows assert no verdict (sitting 5, the scoped lens) | `41, 64` | 14 |
| `OpCount_tests` | `71–94` | 12 | OUT | opcode occurrence counting helper (CountOp, src/script/script.cpp:282-289), not a sigop count or verdict | `71-94` | none: OUT |
| `GetSigOpCount` | `95–156` | 2 | IN | sigop count | sitting 1 | 37 |
| `GetSigOpCount_p2sh` | `157–200` | 2 | IN | sigop count | sitting 1 | 16 |

**`src/test/eviction_candidates_tracker_tests.cpp`** (5 cases; 1 OUT, 4 OUT BY RULING, mempool-state)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `single_long_chain` | `196–240` | 0 | OUT BY RULING: mempool-state policy | which pooled transaction the size limit evicts next (GetMostWorthless), by its fee rate against the pool; eviction under the pool's size limit, which rejects a just-admitted transaction as "mempool full" when it is trimmed (`src/validation.cpp:938-947`); asserted by BOOST_ASSERT, live at the pin (NDEBUG is refused, src/validation.cpp:78) | `235` | none: by ruling |
| `broad_tree` | `241–286` | 0 | OUT BY RULING: mempool-state policy | which pooled transaction the size limit evicts next (GetMostWorthless), by its fee rate against the pool; eviction under the pool's size limit, which rejects a just-admitted transaction as "mempool full" when it is trimmed (`src/validation.cpp:938-947`); asserted by BOOST_ASSERT, live at the pin (NDEBUG is refused, src/validation.cpp:78) | `279` | none: by ruling |
| `secondary_mempool_first` | `287–345` | 0 | OUT BY RULING: mempool-state policy | which pooled transaction the size limit evicts next (GetMostWorthless), by its fee rate against the pool; eviction under the pool's size limit, which rejects a just-admitted transaction as "mempool full" when it is trimmed (`src/validation.cpp:938-947`); asserted by BOOST_ASSERT, live at the pin (NDEBUG is refused, src/validation.cpp:78) | `322-323, 331, 336` | none: by ruling |
| `group_test` | `346–376` | 0 | OUT BY RULING: mempool-state policy | which pooled transactions are eviction candidates as pooled children and groups change: the candidate count asserted after a group is pooled, after a child of one member is added, and after two evictions (GetAllCandidates, GetMostWorthless, `src/txmempoolevictioncandidates.h:144-147`); asserted by BOOST_ASSERT, live at the pin (NDEBUG is refused, src/validation.cpp:78) | `367, 369, 372` | none: by ruling |
| `performance` | `377–426` | 0 | OUT | a timing loop, disabled at the pin (`boost::unit_test::disabled()`, `377`), that evicts a million pooled transactions and asserts no candidate and no decision (its only assert, `188`, is that the tracker exists) | `377-426` | none: OUT |

**`src/test/frozentxo_db_tests.cpp`** (4 cases; 4 OUT BY RULING, operator-list)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `db_tests` | `52–680` | 184 | OUT BY RULING: operator-list mechanism | frozen-output / confiscation mechanism: a block-validity mechanism driven by an operator's list, outside the spec (the owner's ruling, 2026-10-05): CFrozenTXODB IsFrozenOnPolicy / IsFrozenOnConsensus and the blacklists | `92-155` | none: by ruling |
| `IsConfiscationTx_test` | `681–716` | 1 | OUT BY RULING: operator-list mechanism | frozen-output / confiscation mechanism: a block-validity mechanism driven by an operator's list, outside the spec (the owner's ruling, 2026-10-05): CFrozenTXODB::IsConfiscationTx | `713` | none: by ruling |
| `ValidateConfiscationTxContents_test` | `717–827` | 3 | OUT BY RULING: operator-list mechanism | frozen-output / confiscation mechanism: a block-validity mechanism driven by an operator's list, outside the spec (the owner's ruling, 2026-10-05): CFrozenTXODB::ValidateConfiscationTxContents | `793-801` | none: by ruling |
| `db_thread_safety_tests` | `828–1019` | 28 | OUT BY RULING: operator-list mechanism | frozen-output / confiscation mechanism: a block-validity mechanism driven by an operator's list, outside the spec (the owner's ruling, 2026-10-05): IsFrozenOnPolicy / IsFrozenOnConsensus counts under concurrent FreezeTXOPolicyOnly / FreezeTXOConsensus | `930-931, 955-956, 980-981, 996-997, 1011-1012` | none: by ruling |

**`src/test/frozentxo_mempool_tests.cpp`** (1 cases; 1 OUT BY RULING, operator-list)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `mempool_RemoveFrozen` | `107–147` | 5 | OUT BY RULING: operator-list mechanism | frozen-output / confiscation mechanism: a block-validity mechanism driven by an operator's list, outside the spec (the owner's ruling, 2026-10-05): CTxMemPool::RemoveFrozen and RemoveInvalidCTXs over the frozen TXO db and confiscation whitelist | `115-145` | none: by ruling |

**`src/test/frozentxo_tests.cpp`** (2 cases; 2 OUT BY RULING, operator-list)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `negative_Consensus_CheckTxInputs` | `59–135` | 0 | OUT BY RULING: operator-list mechanism | frozen-output / confiscation mechanism: a block-validity mechanism driven by an operator's list, outside the spec (the owner's ruling, 2026-10-05): CheckTxInputs against CFrozenTXOCheck, bad-txns-inputs-frozen | `81-134; src/validation.cpp:2564-2585` | none: by ruling |
| `confiscationTransaction_CheckTxInputs` | `136–206` | 2 | OUT BY RULING: operator-list mechanism | frozen-output / confiscation mechanism: a block-validity mechanism driven by an operator's list, outside the spec (the owner's ruling, 2026-10-05): IsConfiscationTx, ValidateConfiscationTxContents, CheckTxInputs on a confiscation transaction | `148-149; src/validation.cpp:2564-2585` | none: by ruling |

**`src/test/instruction_iterator_tests.cpp`** (4 cases; 3 IN, 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `decode_instruction_tests` | `17–108` | 4 | IN | script verdict: the decoder's failure on malformed bytes, which the interpreter returns as `SCRIPT_ERR_BAD_OPCODE` (`src/script/interpreter.cpp:450-451`); the false status asserted at `102` for the truncated push `{1}` (`27`) and the other malformed encodings; its well-formed rows assert no verdict (sitting 5, the scoped lens) | `27, 102` | 19 |
| `instruction_iterator_happy_case` | `109–154` | 5 | OUT | the parser: asserts the iteration count, each decoded instruction, its opcode, its operand's size and its operand's pointer, no verdict (the third lens; sitting 4) | `139, 144-151` | none: OUT |
| `too_short_single_instruction` | `155–171` | 2 | IN | script verdict: the truncated push's failure sentinel (`OP_INVALIDOPCODE`, empty operand), the decoder's failure the interpreter returns as `SCRIPT_ERR_BAD_OPCODE` (`src/script/interpreter.cpp:450-451`); expected at `168`, asserted at `169` (sitting 5, the scoped lens) | `168-169` | 1 |
| `too_short_two_instructions` | `172–202` | 5 | IN | script verdict: the second, truncated push's failure sentinel (`180`), the decoder's failure the interpreter returns as `SCRIPT_ERR_BAD_OPCODE` (`src/script/interpreter.cpp:450-451`), asserted at `192, 194`; the first push decodes well-formed (sitting 5, the scoped lens) | `180, 192, 194` | 1 |

**`src/test/int_serialization_tests.cpp`** (5 cases; 4 IN, 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `serialize_int64_t` | `88–101` | 2 | IN | number layer, as a script | sitting 1 | 33 |
| `serialize_bint` | `102–140` | 6 | IN | number layer, as a script | sitting 1 | 72 |
| `very_big_number` | `141–151` | 1 | OUT | bint serialize/deserialize round trip only, no expected bytes or script-reachable verdict | `141-151` | none: OUT |
| `is_minimal_encoding` | `152–175` | 1 | IN | number layer, as a script | sitting 1 | 12 |
| `minimally_encode` | `176–205` | 4 | IN | number layer, as a script | sitting 1 | 12 |

**`src/test/invalid_txn_publisher_tests.cpp`** (6 cases; 6 OUT BY RULING, mempool-state)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `publish_no_sinks` | `162–175` | 1 | OUT BY RULING: mempool-state policy | the setup helper asserts the double-spend detector's decision, `CTxnDoubleSpendDetector::insertTxnInputs`, which rejects a transaction as txn-mempool-conflict or txn-double-spend-detected by what the pool and the detector already hold (`src/validation.cpp:1486-1492`): the helper's check at 86, run from MakeInvalidTxnInfoWithTxn at 137-141 | `166; 86 via 137-141` | none: by ruling |
| `publish_enough_space_for_info` | `176–201` | 2 | OUT BY RULING: mempool-state policy | the setup helper asserts the double-spend detector's decision, `CTxnDoubleSpendDetector::insertTxnInputs`, which rejects a transaction as txn-mempool-conflict or txn-double-spend-detected by what the pool and the detector already hold (`src/validation.cpp:1486-1492`): the helper's check at 86, run from MakeInvalidTxnInfoWithTxn at 137-141 | `182; 86 via 137-141` | none: by ruling |
| `publish_missing_some_space_for_info` | `202–232` | 3 | OUT BY RULING: mempool-state policy | the setup helper asserts the double-spend detector's decision, `CTxnDoubleSpendDetector::insertTxnInputs`, which rejects a transaction as txn-mempool-conflict or txn-double-spend-detected by what the pool and the detector already hold (`src/validation.cpp:1486-1492`): the helper's check at 86, run from MakeInvalidTxnInfoWithTxn at 137-141 | `208; 86 via 137-141` | none: by ruling |
| `publish_not_enough_space_for_info` | `233–256` | 1 | OUT BY RULING: mempool-state policy | the setup helper asserts the double-spend detector's decision, `CTxnDoubleSpendDetector::insertTxnInputs`, which rejects a transaction as txn-mempool-conflict or txn-double-spend-detected by what the pool and the detector already hold (`src/validation.cpp:1486-1492`): the helper's check at 86, run from MakeInvalidTxnInfoWithTxn at 137-141 | `239; 86 via 137-141` | none: by ruling |
| `callback` | `257–284` | 3 | OUT BY RULING: mempool-state policy | the setup helper asserts the double-spend detector's decision, `CTxnDoubleSpendDetector::insertTxnInputs`, which rejects a transaction as txn-mempool-conflict or txn-double-spend-detected by what the pool and the detector already hold (`src/validation.cpp:1486-1492`): the helper's check at 86, run from MakeInvalidTxnInfoWithTxn at 137-141 | `259; 86 via 137-141` | none: by ruling |
| `callback_throw_exception` | `285–339` | 2 | OUT BY RULING: mempool-state policy | the setup helper asserts the double-spend detector's decision, `CTxnDoubleSpendDetector::insertTxnInputs`, which rejects a transaction as txn-mempool-conflict or txn-double-spend-detected by what the pool and the detector already hold (`src/validation.cpp:1486-1492`): the helper's check at 86, run from MakeInvalidTxnInfoWithTxn at 137-141 | `328; 86 via 137-141` | none: by ruling |

**`src/test/jba_selfish_mining_tests.cpp`** (3 cases; 3 OUT BY RULING: mempool-state policy)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `NoSelfishNoThrottling` | `224–262` | 17 | OUT BY RULING: mempool-state policy | Live pool admission and template eligibility of a standalone spend and CPFP group; chain acceptance resets the template and pool (owner, 2026-10-05) | [SRC] `src/test/jba_selfish_mining_tests.cpp:118-132,158-189,239-258`; `src/mining/journaling_block_assembler.cpp:197-250,318-347` | none: by ruling |
| `NoSelfishJustThrottling` | `263–405` | 48 | OUT BY RULING: mempool-state policy | Template eligibility depends on the live pool packages, accumulated block size and clock-driven throttling state (owner, 2026-10-05) | [SRC] `src/test/jba_selfish_mining_tests.cpp:118-132,278-402`; `src/mining/journaling_block_assembler.cpp:197-250,318-347` | none: by ruling |
| `SelfishAndThrottling` | `406–622` | 70 | OUT BY RULING: mempool-state policy | Template eligibility of the same pooled parents changes with their age and the addition of current children to their packages (owner, 2026-10-05) | [SRC] `src/test/jba_selfish_mining_tests.cpp:118-132,440-609`; `src/mining/journaling_block_assembler.cpp:197-250,318-347` | none: by ruling |

**`src/test/limitedstack_tests.cpp`** (13 cases; 2 IN, 11 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `limitedstack_push_test` | `14–32` | 3 | IN | script verdict (stack memory limit: push past the limit throws stack_overflow_error, mapped to SCRIPT_ERR_STACK_SIZE at src/script/interpreter.cpp:1815-1817; limit is eval param maxStackMemoryUsage, policy default 100 MB at src/policy/policy.h:153, consensus default INT64_MAX at src/consensus/consensus.h:82; 32-byte element overhead at src/script/limitedstack.h:43) | `28-29; src/script/limitedstack.cpp:195-206; src/script/interpreter.cpp:1815-1817` | 1 |
| `limitedstack_insert_test` | `33–55` | 6 | IN | script verdict (stack memory limit: insert past the limit throws stack_overflow_error, mapped to SCRIPT_ERR_STACK_SIZE at src/script/interpreter.cpp:1815-1817; limit is eval param maxStackMemoryUsage, policy default 100 MB at src/policy/policy.h:153, consensus default INT64_MAX at src/consensus/consensus.h:82) | `51-52; src/script/limitedstack.cpp:281; src/script/interpreter.cpp:1815-1817` | 1 |
| `limitedstack_erase_test` | `56–82` | 9 | OUT | container test, stack accounting or element access with no limit verdict asserted | `56-82` | none: OUT |
| `limitedstack_empty_test` | `83–93` | 3 | OUT | container test, stack accounting or element access with no limit verdict asserted | `83-93` | none: OUT |
| `limitedstack_op_sqbr_test` | `94–102` | 2 | OUT | container test, stack accounting or element access with no limit verdict asserted | `94-102` | none: OUT |
| `limitedstack_front_back_test` | `103–116` | 4 | OUT | container test, stack accounting or element access with no limit verdict asserted | `103-116` | none: OUT |
| `limitedstack_swap_test` | `117–137` | 5 | OUT | container test, stack accounting or element access with no limit verdict asserted | `117-137` | none: OUT |
| `limitedstack_child_test` | `138–159` | 4 | OUT | container test, stack accounting or element access with no limit verdict asserted | `138-159` | none: OUT |
| `limitedstack_movetoptostack_test` | `160–187` | 10 | OUT | container test, stack accounting or element access with no limit verdict asserted | `160-187` | none: OUT |
| `limitedstack_movetovaltypes_test` | `188–209` | 5 | OUT | container test, stack accounting or element access with no limit verdict asserted | `188-209` | none: OUT |
| `limitedvector_append_test` | `210–233` | 4 | OUT | container test, stack accounting or element access with no limit verdict asserted | `210-233` | none: OUT |
| `limitedvector_padright_test` | `234–265` | 3 | OUT | container test, stack accounting or element access with no limit verdict asserted | `234-265` | none: OUT |
| `limitedvector_shrink_tests` | `266–309` | 2 | OUT | container test, stack accounting or element access with no limit verdict asserted | `266-309` | none: OUT |

**`src/test/lrshiftnum_tests.cpp`** (6 cases; 6 IN)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `eval_script_op_lshiftnum` | `21–139` | 4 | IN | script verdict | sitting 1 | 16 |
| `eval_script_large_op_lshiftnum_1bit` | `140–189` | 11 | IN | script verdict | sitting 1 | 1 |
| `eval_script_op_lshiftnum_max_script_len` | `190–232` | 11 | IN | script verdict | sitting 1 | 1 |
| `eval_script_op_lshiftnum_gt_max_script_len` | `233–268` | 5 | IN | script verdict | sitting 1 | 1 |
| `eval_script_op_rshiftnum` | `269–387` | 4 | IN | script verdict | sitting 1 | 16 |
| `eval_script_large_op_rshiftnum_1bit` | `388–423` | 11 | IN | script verdict | sitting 1 | 1 |

**`src/test/mempool_limit_tests.cpp`** (12 cases; 12 OUT BY RULING, mempool-state)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `PrimaryBelowLimitAllInRamSecondaryBelowLimit` | `204–225` | 5 | OUT BY RULING: mempool-state policy | eviction under the pool's size limit, which rejects a just-admitted transaction as "mempool full" when it is trimmed (`src/validation.cpp:938-947`) (LimitMempoolSize); the fixture asserts eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`) | `219-223; fixture 187-188` | none: by ruling |
| `PrimaryBelowLimitAllInRamSecondaryAboveLimit` | `226–254` | 10 | OUT BY RULING: mempool-state policy | eviction under the pool's size limit, which rejects a just-admitted transaction as "mempool full" when it is trimmed (`src/validation.cpp:938-947`) (LimitMempoolSize); the fixture asserts eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`) | `241-250; fixture 187-188` | none: by ruling |
| `PrimaryBelowLimitAllOnDiskSecondaryBelowLimit` | `255–278` | 7 | OUT BY RULING: mempool-state policy | eviction under the pool's size limit, which rejects a just-admitted transaction as "mempool full" when it is trimmed (`src/validation.cpp:938-947`) (LimitMempoolSize); the fixture asserts eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`) | `270-276; fixture 187-188` | none: by ruling |
| `PrimaryBelowLimitAllOnDiskSecondaryAboveLimit` | `279–305` | 10 | OUT BY RULING: mempool-state policy | eviction under the pool's size limit, which rejects a just-admitted transaction as "mempool full" when it is trimmed (`src/validation.cpp:938-947`) (LimitMempoolSize); the fixture asserts eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`) | `294-303; fixture 187-188` | none: by ruling |
| `PrimaryBelowLimitHalfOnDiskSecondaryBelowLimit` | `306–330` | 8 | OUT BY RULING: mempool-state policy | eviction under the pool's size limit, which rejects a just-admitted transaction as "mempool full" when it is trimmed (`src/validation.cpp:938-947`) (LimitMempoolSize); the fixture asserts eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`) | `321-328; fixture 187-188` | none: by ruling |
| `PrimaryBelowLimitHalfOnDiskSecondaryAboveLimit` | `331–359` | 10 | OUT BY RULING: mempool-state policy | eviction under the pool's size limit, which rejects a just-admitted transaction as "mempool full" when it is trimmed (`src/validation.cpp:938-947`) (LimitMempoolSize); the fixture asserts eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`) | `347-356; fixture 187-188` | none: by ruling |
| `PrimaryAtLimitAllInRam` | `360–379` | 4 | OUT BY RULING: mempool-state policy | eviction under the pool's size limit, which rejects a just-admitted transaction as "mempool full" when it is trimmed (`src/validation.cpp:938-947`) (LimitMempoolSize); the fixture asserts eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`) | `374-377; fixture 187-188` | none: by ruling |
| `PrimaryAtLimitAllOnDisk` | `380–399` | 4 | OUT BY RULING: mempool-state policy | eviction under the pool's size limit, which rejects a just-admitted transaction as "mempool full" when it is trimmed (`src/validation.cpp:938-947`) (LimitMempoolSize); the fixture asserts eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`) | `394-397; fixture 187-188` | none: by ruling |
| `PrimaryAtLimitThirdOnDiskSecondaryGone` | `400–422` | 7 | OUT BY RULING: mempool-state policy | eviction under the pool's size limit, which rejects a just-admitted transaction as "mempool full" when it is trimmed (`src/validation.cpp:938-947`) (LimitMempoolSize); the fixture asserts eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`) | `414-420; fixture 187-188` | none: by ruling |
| `PrimaryAboveLimitInRamSecondaryGone` | `423–445` | 7 | OUT BY RULING: mempool-state policy | eviction under the pool's size limit, which rejects a just-admitted transaction as "mempool full" when it is trimmed (`src/validation.cpp:938-947`) (LimitMempoolSize); the fixture asserts eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`) | `437-443; fixture 187-188` | none: by ruling |
| `PrimaryAboveLimitAllOnDiskSecondaryGone` | `446–468` | 7 | OUT BY RULING: mempool-state policy | eviction under the pool's size limit, which rejects a just-admitted transaction as "mempool full" when it is trimmed (`src/validation.cpp:938-947`) (LimitMempoolSize); the fixture asserts eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`) | `460-466; fixture 187-188` | none: by ruling |
| `PrimaryAboveLimitThirdOnDiskSecondaryGone` | `469–492` | 7 | OUT BY RULING: mempool-state policy | eviction under the pool's size limit, which rejects a just-admitted transaction as "mempool full" when it is trimmed (`src/validation.cpp:938-947`) (LimitMempoolSize); the fixture asserts eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`) | `483-489; fixture 187-188` | none: by ruling |

**`src/test/mempool_tests.cpp`** (11 cases; 6 OUT, 5 OUT BY RULING, mempool-state)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `MempoolRemoveTest` | `40–125` | 9 | OUT | mempool bookkeeping | `40-125` | none: OUT |
| `MempoolClearTest` | `126–171` | 9 | OUT | mempool bookkeeping | `126-171` | none: OUT |
| `MempoolAncestorSetTest` | `172–266` | 12 | OUT | mempool bookkeeping | `172-266` | none: OUT |
| `MempoolSizeLimitTest` | `267–441` | 22 | OUT BY RULING: mempool-state policy | eviction under the pool's size limit, which rejects a just-admitted transaction as "mempool full" when it is trimmed (`src/validation.cpp:938-947`), and the pool's rolling minimum fee, the admission threshold "mempool min fee not met" (GetMempoolRejectFee, src/validation.cpp:764-770, 1293) | `292-321, 325, 387-403, 413-435` | none: by ruling |
| `CTxPrioritizerTest` | `442–533` | 11 | OUT | mempool bookkeeping | `442-533` | none: OUT |
| `SecondaryMempoolDecisionTest` | `534–563` | 5 | OUT BY RULING: mempool-state policy | eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`) | `560-561` | none: by ruling |
| `SecondaryMempoolStatsTest` | `564–629` | 19 | OUT BY RULING: mempool-state policy | eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`) | `603, 612, 621` | none: by ruling |
| `SecondaryMempoolComplexChainTest` | `630–740` | 25 | OUT BY RULING: mempool-state policy | eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`), over a chain of pooled parents | `656, 673, 690, 711, 734-737` | none: by ruling |
| `ReorgWithTransactionsOnDisk` | `741–791` | 12 | OUT | mempool bookkeeping | `741-791` | none: OUT |
| `rolling_min_tests` | `792–813` | 9 | OUT | mempool bookkeeping | `792-813` | none: OUT |
| `InfoAllTest` | `814–851` | 7 | OUT BY RULING: mempool-state policy | eligibility for the primary mempool, decided by the fee of the transaction's group in the pool against the block minimum fee (`src/txmempool.cpp:411-413`) | `830, 839` | none: by ruling |

**`src/test/miner_id_db_tests.cpp`** (5 cases; 5 OUT BY RULING: mempool-state policy)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `InitialiseFromExistingChain` | `503–602` | 39 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests.cpp:193,271-294`; case `503–602`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |
| `UpdatesToBlockchain` | `603–674` | 18 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests.cpp:193,271-294`; case `603–674`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |
| `KeyRotation` | `675–753` | 9 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests.cpp:193,271-294`; case `675–753`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |
| `RecentBlocksTracking` | `754–830` | 22 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests.cpp:193,271-294`; case `754–830`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |
| `InvalidBlock` | `831–859` | 4 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests.cpp:193,271-294`; case `831–859`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |

**`src/test/miner_id_db_tests3.cpp`** (15 cases; 15 OUT BY RULING: mempool-state policy)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `InitialiseFromExistingChain` | `811–931` | 50 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests3.cpp:412,535-555`; case `811–931`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |
| `UpdatesToBlockchain` | `932–1059` | 23 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests3.cpp:412,535-555`; case `932–1059`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |
| `KeyRotation` | `1060–1238` | 25 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests3.cpp:412,535-555`; case `1060–1238`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |
| `KeyRotationFork` | `1239–1333` | 27 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests3.cpp:412,535-555`; case `1239–1333`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |
| `RecentBlocksTracking` | `1334–1410` | 22 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests3.cpp:412,535-555`; case `1334–1410`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |
| `InvalidBlock` | `1411–1449` | 7 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests3.cpp:412,535-555`; case `1411–1449`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |
| `SwitchVersion` | `1450–1499` | 13 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests3.cpp:412,535-555`; case `1450–1499`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |
| `RotateVersion` | `1500–1543` | 11 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests3.cpp:412,535-555`; case `1500–1543`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |
| `PartialRevocation` | `1544–1729` | 46 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests3.cpp:412,535-555`; case `1544–1729`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |
| `PartialRevocationFork` | `1730–1831` | 34 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests3.cpp:412,535-555`; case `1730–1831`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |
| `PartialRevocationPruned` | `1832–1896` | 8 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests3.cpp:412,535-555`; case `1832–1896`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |
| `RevokemidRevocation` | `1897–2039` | 44 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests3.cpp:412,535-555`; case `1897–2039`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |
| `RecoverReputation` | `2040–2158` | 30 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests3.cpp:412,535-555`; case `2040–2158`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |
| `FullRevocation` | `2159–2320` | 35 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests3.cpp:412,535-555`; case `2159–2320`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |
| `FullRevocationFork` | `2321–2408` | 25 | OUT BY RULING: mempool-state policy | The shared fixture asserts live mempool admission for a two-transaction dataref batch; the case body checks chain-derived miner-ID state, not a separate transaction/prevout verdict (owner, 2026-10-05) | [SRC] `src/test/miner_id_db_tests3.cpp:412,535-555`; case `2321–2408`; `src/validation.cpp:1143-1160,1285-1295` | none: by ruling |

**`src/test/miner_tests.cpp`** (5 cases; 1 IN, 4 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `CreateNewBlock_validity` | `870–873` | 0 | IN | transaction verdict, consensus (absolute finality and direct SequenceLocks with explicit height/time parameters; TestSequenceLocks uses a mempool view and is not extracted under the mempool-state ruling; the rest is template assembly) | `439-593; by ruling: 449, 485, 531, 564, 595-604` | 9 |
| `BlockAssembler_construction` | `874–877` | 0 | OUT | mining template assembly, max generated block size config | `874-877` | none: OUT |
| `BlockAssembler_construction_activate_new_blocksize` | `878–881` | 0 | OUT | mining template assembly, default block size config | `878-881` | none: OUT |
| `JournalingBlockAssembler_Construction` | `882–885` | 0 | OUT | mining template assembly | `882-885` | none: OUT |
| `CreateNewBlock_JBA_Config` | `886–890` | 0 | OUT | mining template assembly; ProcessNewBlock checks are block-level | `886-890` | none: OUT |

**`src/test/multisig_tests.cpp`** (4 cases; 4 IN)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `multisig_verify` | `46–211` | 20 | IN | script verdict | sitting 1 | 30 |
| `multisig_IsStandard` | `212–266` | 5 | IN | transaction verdict, policy (IsStandard on multisig outputs) | sitting 1 | 10 |
| `multisig_Solver1` | `267–388` | 35 | IN | policy: Solver's template recognition is a pure function of the script and decides output standardness (IsStandardOutput, src/script/standard.cpp:356) and input standardness (IsInputStandard, src/script/standard.cpp:388); the ExtractDestination and IsMine checks of the case stay out | `293, 309, 341, 358, 381, 383` | 10 |
| `multisig_Sign` | `389–440` | 2 | IN | script verdict (SignSignature returns true only when VerifyScript returns SCRIPT_ERR_OK) | `429-438; src/script/sign.cpp:198-207, 225-260` | 6 |

**`src/test/opcode_tests.cpp`** (38 cases; 37 IN, 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `self_bitpattern_test` | `218–240` | 16 | OUT | self-test of the test-local to_bitpattern helper | `220-239` | none: OUT |
| `negative_valtype_test` | `241–328` | 15 | IN | number layer, as a script: bsv::MinimallyEncode (the OP_BIN2NUM encoder) on sign-flipped values, incl. negative zero and the 0x00/0x80 pad cases | `243-265; src/script/int_serialization.h:131; src/script/interpreter.cpp:1781-1790` | 15 |
| `bitwise_opcodes_test` | `329–552` | 4 | IN | script verdict | sitting 1 | 75,006 |
| `invert_test` | `553–564` | 0 | IN | script verdict | sitting 1 | 12 |
| `lshift_test` | `565–626` | 0 | IN | script verdict | sitting 1 | 141 |
| `rshift_test` | `627–689` | 0 | IN | script verdict | sitting 1 | 141 |
| `rshift_big_int` | `690–713` | 3 | IN | script verdict | sitting 1 | 1 |
| `lshift_big_int` | `714–776` | 3 | IN | script verdict | sitting 1 | 1 |
| `string_opcodes_test` | `777–904` | 1 | IN | script verdict | sitting 1 | 29,913 |
| `limited_stack_test` | `905–960` | 1 | IN | script verdict | sitting 1 | 12 |
| `type_conversion_test` | `961–1049` | 1 | IN | script verdict | sitting 1 | 37,569 |
| `mul_test` | `1050–1151` | 0 | IN | script verdict | sitting 1 | 504 |
| `div_and_mod_opcode_tests` | `1152–1278` | 5 | IN | script verdict | sitting 1 | 900 |
| `opcode_limit_tests` | `1279–1313` | 1 | IN | script verdict | sitting 1 | 21 |
| `op_ver_pre_chronicle` | `1314–1338` | 4 | IN | script verdict | sitting 1 | 1 |
| `op_ver_post_chronicle` | `1339–1386` | 4 | IN | script verdict | sitting 1 | 7 |
| `op_verif_pre_chronicle` | `1387–1438` | 5 | IN | script verdict | sitting 1 | 4 |
| `op_verif_post_chronicle` | `1439–1628` | 7 | IN | script verdict | sitting 1 | 22 |
| `op_vernotif_pre_chronicle` | `1629–1680` | 5 | IN | script verdict | sitting 1 | 4 |
| `op_vernotif_post_chronicle` | `1681–1867` | 7 | IN | script verdict | sitting 1 | 22 |
| `op_substr_pre_chronicle` | `1868–1907` | 4 | IN | script verdict | sitting 1 | 2 |
| `op_substr_post_chronicle` | `1908–2001` | 7 | IN | script verdict | sitting 1 | 16 |
| `op_left_pre_chronicle` | `2002–2040` | 4 | IN | script verdict | sitting 1 | 2 |
| `op_left_post_chronicle` | `2041–2121` | 7 | IN | script verdict | sitting 1 | 12 |
| `op_right_pre_chronicle` | `2122–2160` | 4 | IN | script verdict | sitting 1 | 2 |
| `op_right_post_chronicle` | `2161–2241` | 7 | IN | script verdict | sitting 1 | 12 |
| `op_2mul_pre_chronicle` | `2242–2287` | 4 | IN | script verdict | sitting 1 | 4 |
| `op_2mul_post_chronicle` | `2288–2379` | 7 | IN | script verdict | sitting 1 | 11 |
| `op_mul_len_invariant` | `2380–2401` | 2 | IN | script verdict | sitting 1 | 1 |
| `op_2mul_len_invariant` | `2402–2423` | 2 | IN | script verdict | sitting 1 | 1 |
| `op_add_len_invariant` | `2424–2445` | 2 | IN | script verdict | sitting 1 | 1 |
| `op_1add_len_invariant` | `2446–2467` | 2 | IN | script verdict | sitting 1 | 1 |
| `op_sub_len_invariant` | `2468–2489` | 2 | IN | script verdict | sitting 1 | 1 |
| `op_1sub_len_invariant` | `2490–2511` | 2 | IN | script verdict | sitting 1 | 1 |
| `op_2div_pre_chronicle` | `2512–2557` | 4 | IN | script verdict | sitting 1 | 4 |
| `op_2div_post_chronicle` | `2558–2649` | 7 | IN | script verdict | sitting 1 | 11 |
| `EvalScript_flag_check_post_chronicle` | `2650–2669` | 3 | IN | script verdict | sitting 1 | 1 |
| `op_2rot` | `2670–2718` | 5 | IN | script verdict | sitting 1 | 2 |

**`src/test/rpc_tests.cpp`** (18 cases; 1 IN, 17 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `rpc_getinfo` | `144–154` | 3 | OUT | rpc getinfo block size config fields | `144-154` | none: OUT |
| `rpc_rawparams` | `155–218` | 28 | OUT | rpc argument parsing; signrawtransaction only checked not to throw, its complete flag unasserted | `155-218` | none: OUT |
| `rpc_togglenetwork` | `219–239` | 6 | OUT | rpc network toggle | `219-239` | none: OUT |
| `rpc_rawsign` | `240–267` | 2 | IN | script verdict (signrawtransaction's complete flag is true only when VerifyScript returns SCRIPT_ERR_OK on every input) | `262, 265; src/rpc/rawtransaction.cpp:1195-1216` | 2 |
| `rpc_rawsign_missing_amount` | `268–306` | 2 | OUT | rpc argument error for a missing prevout amount (thrown before signing or verifying) | `268-306` | none: OUT |
| `rpc_createraw_op_return` | `307–355` | 6 | OUT | rpc createrawtransaction argument handling, no verdict | `307-355` | none: OUT |
| `rpc_format_monetary_values` | `356–402` | 30 | OUT | rpc amount formatting | `356-402` | none: OUT |
| `rpc_parse_monetary_values` | `403–471` | 26 | OUT | rpc amount parsing (AmountFromValue range, not a transaction verdict) | `403-471` | none: OUT |
| `json_parse_errors` | `472–498` | 11 | OUT | rpc json parsing | `472-498` | none: OUT |
| `rpc_ban` | `499–598` | 39 | OUT | rpc ban list | `499-598` | none: OUT |
| `rpc_convert_values_generatetoaddress` | `599–632` | 14 | OUT | rpc argument conversion | `599-632` | none: OUT |
| `getminingcandidate_low_height` | `633–647` | 2 | OUT | rpc mining candidate height | `633-647` | none: OUT |
| `client_config_ds_endpoint` | `648–703` | 14 | OUT | rpc client config getters | `648-703` | none: OUT |
| `client_config_bitcoind` | `704–727` | 9 | OUT | rpc client config getters | `704-727` | none: OUT |
| `client_config_minerid_generator` | `728–743` | 5 | OUT | rpc client config getters | `728-743` | none: OUT |
| `http_requests` | `744–829` | 20 | OUT | http request construction | `744-829` | none: OUT |
| `http_responses` | `830–874` | 10 | OUT | http response parsing | `830-874` | none: OUT |
| `rpc_verifymerkleproofparams` | `875–958` | 15 | OUT | rpc verifymerkleproof argument handling | `875-958` | none: OUT |

**`src/test/script_P2SH_tests.cpp`** (6 cases; 6 IN)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `sign` | `65–187` | 9 | IN | script verdict | sitting 1 | 90 |
| `norecurse` | `188–213` | 4 | IN | script verdict | sitting 1 | 2 |
| `set` | `214–295` | 10 | IN | transaction verdict, policy (IsStandardTx; a p2sh output is nonstandard at and after the genesis height, reason scriptpubkey; the case sets the genesis height to 10); also script verdicts via SignSignature per era pair | `252-254, 269-292; src/script/standard.cpp:427-500; src/script/sign.cpp:201-208` | 26 |
| `is` | `296–368` | 9 | IN | script verdict | sitting 1 | 9 |
| `switchover` | `369–386` | 4 | IN | script verdict | sitting 1 | 2 |
| `AreInputsStandard` | `387–569` | 21 | IN | transaction verdict, policy (AreInputsStandard) | sitting 1 | 21 |

**`src/test/script_tests.cpp`** (44 cases; 38 IN, 2 COVERED, 4 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `script_build` | `713–1480` | 1 | COVERED | builds the rows of script_tests.json and asserts each is in it: covered by the vendored JSON | sitting 1 | none: covered |
| `script_json_test` | `1481–1532` | 2 | COVERED | reads script_tests.json: vendored at corpus/reference and replayed | sitting 1 | none: covered |
| `chronicle_scriptsig_checksig` | `1533–1726` | 0 | IN | script verdict | sitting 1 | 12 |
| `chronicle_misc` | `1727–1792` | 0 | IN | script verdict | sitting 1 | 7 |
| `chronicle_pushdata_only` | `1793–2167` | 0 | IN | script verdict | sitting 1 | 36 |
| `chronicle_clean_stack` | `2168–2466` | 0 | IN | script verdict | sitting 1 | 28 |
| `chronicle_nullfail` | `2467–2953` | 0 | IN | script verdict | sitting 1 | 44 |
| `script_PushData` | `2954–3008` | 11 | IN | script verdict | sitting 1 | 4 |
| `op_pushdata1_op_size` | `3009–3039` | 3 | IN | script verdict | sitting 1 | 1 |
| `op_pushdata2_op_size` | `3040–3070` | 3 | IN | script verdict | sitting 1 | 1 |
| `op_pushdata4_op_size` | `3071–3139` | 4 | IN | script verdict | sitting 1 | 1 |
| `script_CHECKMULTISIG12` | `3140–3207` | 10 | IN | script verdict | sitting 1 | 4 |
| `script_CHECKMULTISIG23` | `3208–3630` | 48 | IN | script verdict | sitting 1 | 9 |
| `script_combineSigs` | `3631–3639` | 0 | OUT | signer api: SignSignature returns are not checked and CombineSignatures returns a merged scriptSig, no verdict | `3367-3630; src/script/sign.cpp:356-425` | none: OUT |
| `script_standard_push` | `3640–3680` | 6 | IN | script verdict | sitting 1 | 135,042 |
| `script_IsPushOnly_on_invalid_scripts` | `3681–3690` | 1 | IN | a pure predicate of the script that feeds a verdict: IsPushOnly on a truncated push decides standardness (scriptsig-not-pushonly before Chronicle, src/script/standard.cpp:462-464) and the consensus SIG_PUSHONLY checks (src/script/interpreter.cpp:2329-2331, 2387-2388) | `3688` | 1 |
| `script_GetScriptAsm` | `3691–3818` | 26 | OUT | asm printer (ScriptToAsmStr) only | `3691-3818` | none: OUT |
| `script_FindAndDelete` | `3819–3935` | 32 | IN | digest layer, as a script (the scriptCode before a CHECKSIG without FORKID) | sitting 1 | 16 |
| `script_IsUnspendable` | `3936–3958` | 6 | IN | policy on an output, never consensus: IsUnspendable sets the dust threshold to 0 for an unspendable output (CTxOut::GetDustThreshold, src/primitives/transaction.h:205-206), which IsDust and IsStandardTx read; the parameter is the dust threshold, fixed at the pin (§2) | `3938-3943` | 4 |
| `script_Solver` | `3959–4030` | 0 | IN | policy decision on an output (Solver false / TX_NONSTANDARD makes IsStandardOutput false; no parameter decides these rows, era-dependent) | `3977, 3984, 3987, 3997, 4021-4022, 4028; src/script/standard.cpp:353-373` | 19 |
| `solver_MultiSig_Decode_Check` | `4031–4083` | 8 | IN | policy decision on an output (Solver false / TX_NONSTANDARD for an 18-key non-opcode multisig pre-genesis makes IsStandardOutput false; decoded m/n feed its 1..3 bound) | `4066-4067; src/script/standard.cpp:353-373` | 4 |
| `txout_IsDust` | `4084–4098` | 4 | IN | policy decision on an output, never consensus (CTxOut::IsDust, which IsStandardTx rejects as "dust", script/standard.cpp:481-482; the parameter is the dust threshold, fixed at 1 satoshi per spendable output and 0 for an unspendable one, primitives/transaction.h:203-209: not a setting at the pin, -dustlimitfactor and -dustrelayfee are removed, init.cpp:2943-2947, 2995-2999) | `4091-4096` | 4 |
| `txout_IsDustReturnScript` | `4099–4136` | 6 | IN | policy decision on an output, never consensus (IsDustReturnScript, behind IsDustReturnTxn, policy/policy.cpp:22-27, the donation branch of the free-consolidation policy, policy/policy.cpp:33-41; parameter -minconsolidationfactor, default 20, policy/policy.h:72, init.cpp:2429-2431; 0 turns the branch off) | `4107-4134` | 6 |
| `IsMinerIdScript` | `4137–4251` | 3 | OUT | miner-id template matcher, no transaction or policy verdict | `4137-4171` | none: OUT |
| `caching_invalid_signatures` | `4252–4339` | 5 | IN | script verdict (VerifyScript on a 1-of-200 multisig asserted SCRIPT_ERR_OK, genesis flags) | `4310, 4324` | 60 |
| `mt_2_plus_2` | `4340–4408` | 0 | IN | script verdict | sitting 1 | 8 |
| `mt_p2pkh` | `4409–4528` | 0 | IN | script verdict | sitting 1 | 8 |
| `get_script_verify_flags` | `4529–4590` | 27 | OUT | flag selection from the node's and the coin's era (StandardScriptVerifyFlags, InputScriptVerifyFlags): a function of block heights and the activation heights, not of the script or the transaction; the era is the spec's named parameter. A border call, named for the lens | `4529-4590` | none: OUT |
| `chronicle_forkid_chronicle_script_validation` | `4591–4707` | 0 | IN | script verdict | sitting 1 | 16 |
| `EvalScript_lows` | `4708–4761` | 2 | IN | script verdict | sitting 1 | 18 |
| `VerifyScript_lows` | `4762–4867` | 2 | IN | script verdict | sitting 1 | 10 |
| `EvalScript_op_checksig_forkid_chronicle` | `4868–4949` | 2 | IN | script verdict | sitting 1 | 46 |
| `EvalScript_op_checkmultisig_forkid_chronicle` | `4950–5032` | 2 | IN | script verdict | sitting 1 | 46 |
| `EvalScript_multiple_op_checksig_forkid_chronicle` | `5033–5080` | 2 | IN | script verdict | sitting 1 | 6 |
| `EvalScript_multiple_op_checkmultisig_forkid_chronicle` | `5081–5129` | 2 | IN | script verdict | sitting 1 | 6 |
| `EvalScript_minimal_encoding` | `5130–5286` | 2 | IN | script verdict | sitting 1 | 22 |
| `VerifyScript_minimal_encoding` | `5287–5379` | 2 | IN | script verdict | sitting 1 | 10 |
| `eval_script_op_checksig_nullfail` | `5380–5537` | 9 | IN | script verdict | sitting 1 | 24 |
| `verify_script_op_checksig_nullfail` | `5538–5615` | 2 | IN | script verdict | sitting 1 | 12 |
| `eval_script_op_checkmultisig_nullfail` | `5616–5856` | 4 | IN | script verdict | sitting 1 | 28 |
| `eval_script_op_checkmultisig_nulldummy` | `5857–6033` | 4 | IN | script verdict | sitting 1 | 16 |
| `verify_script_op_checksig_nulldummy` | `6034–6142` | 2 | IN | script verdict | sitting 1 | 16 |
| `eval_script_op_if_minimal_if` | `6143–6537` | 4 | IN | script verdict | sitting 1 | 64 |
| `verify_script_minimal_if` | `6538–6617` | 2 | IN | script verdict | sitting 1 | 10 |

**`src/test/scriptnum_tests.cpp`** (27 cases; 20 IN, 7 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `default_construction` | `36–42` | 2 | OUT | c++ default constructor and accessors | `36-42` | none: OUT |
| `int64_construction` | `43–98` | 3 | OUT | c++ int64 constructor width check; the interpreter builds int64 script numbers only at the default width (interpreter.cpp:1148, 1182) | `43-98` | none: OUT |
| `bint_construction` | `99–115` | 2 | OUT | c++ bint constructor at width 1; the interpreter builds bint constants only at params.MaxScriptNumLength() (interpreter.cpp:1147, 1239, 1253) | `99-115` | none: OUT |
| `construction` | `116–174` | 1 | IN | number layer, as a script | sitting 1 | 24 |
| `lshift_max_length_invariant` | `175–235` | 4 | IN | number layer, as a script (lshiftnum result length bounded by max length, overflow at widths 2 and 4 reachable by eval_script_params MaxScriptNumLength) | `196, 205, 223, 232` | 10 |
| `lshift_negative_value` | `236–308` | 3 | IN | number layer, as a script | sitting 1 | 31 |
| `lshift_overflow_int64` | `309–324` | 1 | IN | number layer, as a script | sitting 1 | 1 |
| `chronicle_construction` | `325–372` | 3 | IN | number layer, as a script | sitting 1 | 4 |
| `insertion_op` | `373–397` | 2 | OUT | printer | `373-397` | none: OUT |
| `equality` | `398–420` | 6 | IN | number layer, as a script | sitting 1 | 10 |
| `less` | `421–456` | 12 | IN | number layer, as a script | sitting 1 | 15 |
| `addition` | `457–487` | 2 | IN | number layer, as a script | sitting 1 | 16 |
| `subtraction` | `488–518` | 2 | IN | number layer, as a script | sitting 1 | 16 |
| `multiplication` | `519–555` | 2 | IN | number layer, as a script | sitting 1 | 20 |
| `add_max_length_invariant` | `556–598` | 3 | IN | number layer, as a script (add result length and overflow at max length 1 and 2, reachable by eval_script_params MaxScriptNumLength) | `574, 582, 595` | 10 |
| `sub_max_length_invariant` | `599–638` | 3 | IN | number layer, as a script (sub result length and overflow at max length 1 and 2, reachable by eval_script_params MaxScriptNumLength) | `615, 623, 635` | 5 |
| `mul_max_length_invariant` | `639–681` | 3 | IN | number layer, as a script (mul result length and overflow at max length 1 and 2, reachable by eval_script_params MaxScriptNumLength) | `657, 665, 678` | 10 |
| `division` | `682–713` | 2 | IN | number layer, as a script | sitting 1 | 18 |
| `modular` | `714–741` | 2 | IN | number layer, as a script | sitting 1 | 12 |
| `and_` | `742–771` | 2 | OUT | numeric and on CScriptNum; no opcode calls CScriptNum::operator& (OP_AND is bytewise, interpreter.cpp:1087) | `742-771` | none: OUT |
| `negation` | `772–800` | 2 | IN | number layer, as a script | sitting 1 | 8 |
| `getint` | `801–814` | 2 | OUT | c++ saturating accessor; op_substr/op_left/op_right reject an out-of-range length either way (interpreter.cpp:623-633, 656-660, 681-685), so the clamp is not script-observable | `801-814` | none: OUT |
| `to_size_t_limited` | `815–996` | 41 | OUT | c++ conversion accessor on in-range values | `815-996` | none: OUT |
| `creation` | `997–1009` | 0 | IN | number layer, as a script | sitting 1 | 630 |
| `operators` | `1010–1039` | 2 | IN | number layer, as a script | sitting 1 | 7,020 |
| `minimize_encoding_test` | `1040–1081` | 0 | IN | number layer, as a script | sitting 1 | 3,121 |
| `rshift_division_semantics` | `1082–1139` | 2 | IN | number layer, as a script | sitting 1 | 36 |

**`src/test/sighash_tests.cpp`** (2 cases; 1 IN, 1 COVERED)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `sighash_test` | `131–186` | 5 | IN | digest layer, as a script (1,000 random transactions per run) | sitting 1 | 1,000 |
| `sighash_from_data` | `187–244` | 4 | COVERED | reads sighash.json: vendored at corpus/sighash and replayed | sitting 1 | none: covered |

**`src/test/sighashtype_tests.cpp`** (2 cases; 2 IN)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `sighash_construction_test` | `85–154` | 0 | IN | digest layer, as a script: isDefined, hasForkId and hasChronicle are pure functions of the hash-type byte; isDefined decides SIG_HASHTYPE (src/script/interpreter.cpp:293) | `76-81 (CheckSigHashType), 88, 112-138` | 2,561 |
| `sighash_serialization_test` | `155–189` | 2 | IN | digest layer, as a script (the hash-type byte behind SIG_HASHTYPE) | sitting 1 | 2,560 |

**`src/test/sigopcount_tests.cpp`** (5 cases; 4 IN, 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `GetSigOpCount_WithReturn` | `30–76` | 2 | IN | sigop count | sitting 1 | 5 |
| `GetSigOpCount` | `77–248` | 52 | IN | sigop count | sitting 1 | 34 |
| `GetTxSigOpCost` | `249–395` | 16 | IN | sigop count and script verdict | sitting 1 | 16 |
| `test_sigops_limits` | `396–449` | 16 | OUT | config getter for the block-level sigop limit (GetMaxBlockSigOpsConsensusBeforeGenesis), block-level, no transaction verdict | `396-408` | none: OUT |
| `test_max_sigops_per_tx` | `450–491` | 15 | IN | sigop limit, consensus (CheckRegularTransaction rejects bad-txn-sigops above MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS pre-genesis, accepts post-genesis; via TestMaxSigOps) | `424-446, 455` | 6 |

**`src/test/test_double_spend_detector.cpp`** (5 cases; 5 OUT BY RULING, mempool-state)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `test_detector_insert_txn_inputs` | `41–64` | 7 | OUT BY RULING: mempool-state policy | the double-spend detector's decision, `CTxnDoubleSpendDetector::insertTxnInputs`, which rejects a transaction as txn-mempool-conflict or txn-double-spend-detected by what the pool and the detector already hold (`src/validation.cpp:1486-1492`) | `48-59` | none: by ruling |
| `test_detector_conflicts` | `65–99` | 6 | OUT BY RULING: mempool-state policy | the double-spend detector's decision, `CTxnDoubleSpendDetector::insertTxnInputs`, which rejects a transaction as txn-mempool-conflict or txn-double-spend-detected by what the pool and the detector already hold (`src/validation.cpp:1486-1492`) | `75, 86, 97` | none: by ruling |
| `test_detector_remove_txn_inputs` | `100–126` | 6 | OUT BY RULING: mempool-state policy | the double-spend detector's decision, `CTxnDoubleSpendDetector::insertTxnInputs`, which rejects a transaction as txn-mempool-conflict or txn-double-spend-detected by what the pool and the detector already hold (`src/validation.cpp:1486-1492`) | `110, 119` | none: by ruling |
| `test_detector_clear_txn_inputs` | `127–140` | 3 | OUT BY RULING: mempool-state policy | the double-spend detector's decision, `CTxnDoubleSpendDetector::insertTxnInputs`, which rejects a transaction as txn-mempool-conflict or txn-double-spend-detected by what the pool and the detector already hold (`src/validation.cpp:1486-1492`) | `134` | none: by ruling |
| `test_detector_remove_after_clear` | `141–153` | 1 | OUT BY RULING: mempool-state policy | the double-spend detector's decision, `CTxnDoubleSpendDetector::insertTxnInputs`, which rejects a transaction as txn-mempool-conflict or txn-double-spend-detected by what the pool and the detector already hold (`src/validation.cpp:1486-1492`) | `147-148` | none: by ruling |

**`src/test/test_txnvalidator.cpp`** (12 cases; 3 IN, 6 OUT, 3 OUT BY RULING, mempool-state)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `txn_validator_creation` | `298–315` | 3 | OUT | validator construction bookkeeping | `298-315` | none: OUT |
| `txn_validator_set_get_frequency` | `316–331` | 2 | OUT | validator config getter/setter | `316-331` | none: OUT |
| `txn_validator_istxnknown` | `332–349` | 2 | OUT | validator queue bookkeeping (isTxnKnown) | `332-349` | none: OUT |
| `double_spend_detector` | `350–470` | 28 | OUT BY RULING: mempool-state policy | the double-spend detector's decision, `CTxnDoubleSpendDetector::insertTxnInputs`, which rejects a transaction as txn-mempool-conflict or txn-double-spend-detected by what the pool and the detector already hold (`src/validation.cpp:1486-1492`) | `389-395, 402-408, 415-421, 461-467` | none: by ruling |
| `validation_state_collided_with_tx` | `471–537` | 16 | OUT | CValidationState collided-with set bookkeeping | `471-537` | none: OUT |
| `txnvalidator_doublespend_synch_api` | `538–566` | 2 | IN | transaction verdict, consensus and policy together (the validator's accept of the first of two conflicting spends, CTxnValidator::processValidation, asserted at 227 through ProcessTxnsSynchApi); the second spend's rejection (231, 542, 562) is mempool-state policy, OUT BY RULING, and is not extracted | `227; by ruling: 231, 542, 562` | 8 |
| `txnvalidator_doublespend_synch_batch_api` | `567–625` | 10 | OUT BY RULING: mempool-state policy | the batch's conflicting spends rejected as a mempool conflict or a double spend, by what the pool holds (double-spend detector's decision, `CTxnDoubleSpendDetector::insertTxnInputs`, which rejects a transaction as txn-mempool-conflict or txn-double-spend-detected by what the pool and the detector already hold (`src/validation.cpp:1486-1492`)) | `580, 584, 613, 617` | none: by ruling |
| `txnvalidator_doublespend_asynch_api` | `626–645` | 2 | OUT BY RULING: mempool-state policy | one of ten conflicting spends admitted, the rest rejected by what the pool holds (pool size asserted); the double-spend detector's decision, `CTxnDoubleSpendDetector::insertTxnInputs`, which rejects a transaction as txn-mempool-conflict or txn-double-spend-detected by what the pool and the detector already hold (`src/validation.cpp:1486-1492`) | `636, 642` | none: by ruling |
| `txnvalidator_limit_memory_usage` | `646–672` | 3 | OUT | validator queue memory bookkeeping | `646-672` | none: OUT |
| `txnvalidator_nvalueoutofrange_sync_api` | `673–691` | 3 | IN | transaction verdict, consensus (an output above MAX_MONEY) | `679-687` | 8 |
| `txnvalidator_nvalueoutofrange_async_api` | `692–732` | 3 | IN | transaction verdict, consensus (an output above MAX_MONEY) | `713-721; by ruling: 727-729` | 20 |
| `txnvalidator_low_priority_chain_async_api` | `733–807` | 8 | OUT | validator queue priority scheduling bookkeeping | `733-807` | none: OUT |

**`src/test/time_locked_mempool_tests.cpp`** (4 cases; 4 OUT BY RULING, mempool-state)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `MempoolAddTest` | `119–179` | 17 | OUT BY RULING: mempool-state policy | admission to the non-final pool rejected as REJECT_MEMPOOL_FULL by what the pool already holds | `173-174` | none: by ruling |
| `DoubleSpendTest` | `180–210` | 2 | OUT BY RULING: mempool-state policy | conflict with a transaction the non-final pool holds, which the mempool's conflict set reads into the admission decision (CTxMemPool, src/txmempool.cpp:2258-2262) | `202, 208` | none: by ruling |
| `UpdateTest` | `211–324` | 36 | OUT BY RULING: mempool-state policy | replacement of a pooled non-final transaction, accepted or rejected relative to the pooled one | `253, 273, 293` | none: by ruling |
| `RateLimitUpdateTest` | `325–392` | 11 | OUT BY RULING: mempool-state policy | replacement rejected by the pool's replacement rate limit (non-final-txn-replacement-rate) | `381-386` | none: by ruling |

**`src/test/transaction_tests.cpp`** (16 cases; 14 IN, 2 COVERED)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `tx_valid` | `175–192` | 0 | COVERED | reads tx_valid.json: vendored at corpus/reference and replayed | sitting 1 | none: covered |
| `tx_invalid` | `193–210` | 0 | COVERED | reads tx_invalid.json: vendored at corpus/reference and replayed | sitting 1 | none: covered |
| `basic_transaction_tests` | `211–292` | 2 | IN | transaction verdict, consensus (CheckRegularTransaction) | sitting 1 | 2 |
| `test_Get` | `293–398` | 13 | IN | transaction verdict, policy (AreInputsStandard) | sitting 1 | 1 |
| `test_big_transaction` | `399–529` | 3 | IN | transaction verdict, consensus (VerifyScript on 4,500 inputs) | sitting 1 | 2 |
| `test_witness` | `530–813` | 2 | IN | transaction verdict, consensus (VerifyScript across flag words) | sitting 1 | 191 |
| `test_IsStandard` | `814–874` | 11 | IN | transaction verdict, policy | sitting 1 | 11 |
| `test_IsStandard_NonPushOnlyScriptSig_Chronicle` | `875–915` | 6 | IN | transaction verdict, policy | sitting 1 | 5 |
| `test_IsStandard_TxVersion_Chronicle` | `916–973` | 10 | IN | transaction verdict, policy | sitting 1 | 10 |
| `test_IsStandard_MaxTxSizePolicy` | `974–1189` | 31 | IN | transaction verdict, policy | sitting 1 | 4 |
| `test_IsStandard_OP_RETURN` | `1190–1193` | 0 | IN | transaction verdict, policy | sitting 1 | 15 |
| `test_IsStandard_OP_FALSE_OP_RETURN` | `1194–1246` | 0 | IN | transaction verdict, policy | sitting 1 | 15 |
| `test_IsDustReturnTransaction` | `1247–1330` | 7 | IN | transaction verdict, policy | sitting 1 | 5 |
| `test_IsConsolidationTransactionStandard` | `1331–1406` | 12 | IN | transaction verdict, policy | sitting 1 | 6 |
| `test_IsConsolidationTransactionNonStandard` | `1407–1467` | 4 | IN | transaction verdict, policy | sitting 1 | 2 |
| `tst_tx_toJson_OP_RETURN` | `1468–1479` | 4 | IN | policy decision on an output (Solver's template type via TxToJSON/ExtractDestinations: a bare OP_RETURN output post-Genesis is TX_NONSTANDARD, which IsStandardOutput rejects; no parameter decides it, datacarrier default true at script/standard.h:20 only matters for nulldata) | `1473, 1475-1476; src/script/standard.cpp:353-374; src/core_write.cpp:350-360` | 4 |

**`src/test/txvalidationcache_tests.cpp`** (2 cases; 2 IN)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `tx_mempool_block_doublespend` | `209–266` | 9 | IN | transaction verdict, consensus and policy together (the validator's accept through ToMemPool, CTxnValidator::processValidation, asserted on signed P2PK spends of a mature coinbase; its block rejections are block-level) | `35-52, 244, 250, 258` | 3 |
| `checkinputs_test` | `267–632` | 13 | IN | transaction verdict, consensus (CheckInputs under every flag combination) | sitting 1 | 286,724 |

### 2b. The files with every case OUT (125 files, each case read in sitting 2)

**`src/test/DoS_tests.cpp`** (4 cases; 4 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `DoS_banning` | `33–90` | 5 | OUT | peer misbehavior scoring and ban list; no tx verdict asserted | `33-90` | none: OUT |
| `DoS_banscore` | `91–127` | 3 | OUT | peer misbehavior scoring and ban list; no tx verdict asserted | `91-127` | none: OUT |
| `DoS_bantime` | `128–166` | 3 | OUT | peer misbehavior scoring and ban list; no tx verdict asserted | `128-166` | none: OUT |
| `DoS_mapOrphans` | `167–331` | 6 | OUT | orphan pool bookkeeping (COrphanTxns add, size gate, erase by peer); SignSignature results not asserted | `263, 296-309, 324-330; src/orphan_txns.cpp:52-63` | none: OUT |

**`src/test/addrman_tests.cpp`** (11 cases; 11 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `addrman_simple` | `65–103` | 8 | OUT | address manager bookkeeping (networking) | `65-103` | none: OUT |
| `addrman_ports` | `104–133` | 6 | OUT | address manager bookkeeping (networking) | `104-133` | none: OUT |
| `addrman_select` | `134–193` | 8 | OUT | address manager bookkeeping (networking) | `134-193` | none: OUT |
| `addrman_new_collisions` | `194–221` | 4 | OUT | address manager bookkeeping (networking) | `194-221` | none: OUT |
| `addrman_tried_collisions` | `222–250` | 4 | OUT | address manager bookkeeping (networking) | `222-250` | none: OUT |
| `addrman_find` | `251–285` | 7 | OUT | address manager bookkeeping (networking) | `251-285` | none: OUT |
| `addrman_create` | `286–306` | 3 | OUT | address manager bookkeeping (networking) | `286-306` | none: OUT |
| `addrman_delete` | `307–328` | 4 | OUT | address manager bookkeeping (networking) | `307-328` | none: OUT |
| `addrman_getaddr` | `329–402` | 7 | OUT | address manager bookkeeping (networking) | `329-402` | none: OUT |
| `caddrinfo_get_tried_bucket` | `403–457` | 6 | OUT | address manager bookkeeping (networking) | `403-457` | none: OUT |
| `caddrinfo_get_new_bucket` | `458–523` | 7 | OUT | address manager bookkeeping (networking) | `458-523` | none: OUT |

**`src/test/alertnotify_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `alertnotify_test` | `15–33` | 1 | OUT | alert notification shell command output | `15-33` | none: OUT |

**`src/test/allocator_tests.cpp`** (3 cases; 3 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `arena_tests` | `14–166` | 25 | OUT | secure memory allocator and locked pool stats | `14-166` | none: OUT |
| `lockedpool_tests_mock` | `167–214` | 19 | OUT | secure memory allocator and locked pool stats | `167-214` | none: OUT |
| `lockedpool_tests_live` | `215–242` | 5 | OUT | secure memory allocator and locked pool stats | `215-242` | none: OUT |

**`src/test/amount_tests.cpp`** (2 cases; 2 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `AmountTests` | `86–102` | 5 | OUT | amount type arithmetic (Amount add, sub), no transaction verdict | `86-102` | none: OUT |
| `GetFeeTest` | `103–163` | 32 | OUT | fee-rate arithmetic (CFeeRate::GetFee, constructor rounding), no decision on a transaction | `103-163` | none: OUT |

**`src/test/arith_uint256_tests.cpp`** (11 cases; 11 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `basics` | `84–184` | 40 | OUT | 256-bit unsigned arithmetic for proof-of-work targets (arith_uint256), not the script number layer | `84-184` | none: OUT |
| `shifts` | `185–239` | 14 | OUT | 256-bit unsigned arithmetic for proof-of-work targets (arith_uint256), not the script number layer | `185-239` | none: OUT |
| `unaryOperators` | `240–280` | 12 | OUT | 256-bit unsigned arithmetic for proof-of-work targets (arith_uint256), not the script number layer | `240-280` | none: OUT |
| `bitwiseOperators` | `281–327` | 4 | OUT | 256-bit unsigned arithmetic for proof-of-work targets (arith_uint256), not the script number layer | `281-327` | none: OUT |
| `comparison` | `328–348` | 10 | OUT | 256-bit unsigned arithmetic for proof-of-work targets (arith_uint256), not the script number layer | `328-348` | none: OUT |
| `plusMinus` | `349–399` | 24 | OUT | 256-bit unsigned arithmetic for proof-of-work targets (arith_uint256), not the script number layer | `349-399` | none: OUT |
| `multiply` | `400–429` | 15 | OUT | 256-bit unsigned arithmetic for proof-of-work targets (arith_uint256), not the script number layer | `400-429` | none: OUT |
| `divide` | `430–459` | 12 | OUT | 256-bit unsigned arithmetic for proof-of-work targets (arith_uint256), not the script number layer | `430-459` | none: OUT |
| `methods` | `460–500` | 19 | OUT | 256-bit unsigned arithmetic for proof-of-work targets (arith_uint256), not the script number layer | `460-500` | none: OUT |
| `setcompact_test` | `501–539` | 4 | OUT | 256-bit unsigned arithmetic for proof-of-work targets (arith_uint256), not the script number layer | `501-539` | none: OUT |
| `bignum_SetCompact` | `540–733` | 93 | OUT | 256-bit unsigned arithmetic for proof-of-work targets (arith_uint256), not the script number layer | `540-733` | none: OUT |

**`src/test/array_parser_tests.cpp`** (8 cases; 8 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `default_construction` | `20–27` | 3 | OUT | network message array parser byte counts | `20-27` | none: OUT |
| `parse_empty` | `28–41` | 5 | OUT | network message array parser byte counts | `28-41` | none: OUT |
| `parse_1_item` | `42–55` | 5 | OUT | network message array parser byte counts | `42-55` | none: OUT |
| `parse_2_items` | `56–69` | 5 | OUT | network message array parser byte counts | `56-69` | none: OUT |
| `parse_max_items` | `70–84` | 5 | OUT | network message array parser byte counts | `70-84` | none: OUT |
| `parse_many_items` | `85–99` | 5 | OUT | network message array parser byte counts | `85-99` | none: OUT |
| `parse_partial_segment` | `100–113` | 5 | OUT | network message array parser byte counts | `100-113` | none: OUT |
| `seg_offset` | `114–148` | 14 | OUT | network message array parser byte counts | `114-148` | none: OUT |

**`src/test/base32_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `base32_testvectors` | `14–31` | 2 | OUT | base32 encode/decode vectors | `25-27` | none: OUT |

**`src/test/base58_tests.cpp`** (5 cases; 5 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `base58_EncodeBase58` | `25–47` | 1 | OUT | base58 / key encoding only, no script or transaction verdict | `25-47` | none: OUT |
| `base58_DecodeBase58` | `48–117` | 6 | OUT | base58 / key encoding only, no script or transaction verdict | `48-117` | none: OUT |
| `base58_keys_valid_parse` | `118–185` | 9 | OUT | base58 / key encoding only, no script or transaction verdict | `118-185` | none: OUT |
| `base58_keys_valid_gen` | `186–241` | 2 | OUT | base58 / key encoding only, no script or transaction verdict | `186-241` | none: OUT |
| `base58_keys_invalid` | `242–270` | 2 | OUT | base58 / key encoding only, no script or transaction verdict | `242-270` | none: OUT |

**`src/test/base58data_tests.cpp`** (2 cases; 2 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `default_construction` | `27–32` | 1 | OUT | base58 data encoding and comparison, no script or transaction verdict | `27-32` | none: OUT |
| `compare` | `33–167` | 62 | OUT | base58 data encoding and comparison, no script or transaction verdict | `33-167` | none: OUT |

**`src/test/base64_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `base64_testvectors` | `14–31` | 2 | OUT | base64 encode and decode only | `14-31` | none: OUT |

**`src/test/bip32_tests.cpp`** (2 cases; 2 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `bip32_test1` | `164–167` | 0 | OUT | bip32 key derivation and serialization | `164-167` | none: OUT |
| `bip32_test2` | `168–172` | 0 | OUT | bip32 key derivation and serialization | `168-172` | none: OUT |

**`src/test/block_download_tracking_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `TestBlockTracking` | `48–339` | 160 | OUT | block download source tracking (networking) | `48-339` | none: OUT |

**`src/test/block_index_mutex_distribution_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `BlockIndexMutexDistributionTest` | `40–66` | 2 | OUT | block index mutex distribution, internal locking | `40-66` | none: OUT |

**`src/test/block_info_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `mtp` | `20–56` | 14 | OUT | block index median time past computation, chain-level, no transaction verdict | `20-56` | none: OUT |

**`src/test/block_parser_tests.cpp`** (9 cases; 9 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `parse_all` | `57–90` | 9 | OUT | p2p block message byte parser, serialization only | `57-90` | none: OUT |
| `parse_as_reqd` | `91–119` | 3 | OUT | p2p block message byte parser, serialization only | `91-119` | none: OUT |
| `parse_byte_by_byte` | `120–132` | 1 | OUT | p2p block message byte parser, serialization only | `120-132` | none: OUT |
| `read_all` | `133–150` | 6 | OUT | p2p block message byte parser, serialization only | `133-150` | none: OUT |
| `read_byte_by_byte` | `151–169` | 4 | OUT | p2p block message byte parser, serialization only | `151-169` | none: OUT |
| `read_beyond_parser_size` | `170–186` | 6 | OUT | p2p block message byte parser, serialization only | `170-186` | none: OUT |
| `read_partial_tx_count` | `187–202` | 2 | OUT | p2p block message byte parser, serialization only | `187-202` | none: OUT |
| `read_partial_tx_1` | `203–220` | 2 | OUT | p2p block message byte parser, serialization only | `203-220` | none: OUT |
| `read_partial_tx_2` | `221–239` | 2 | OUT | p2p block message byte parser, serialization only | `221-239` | none: OUT |

**`src/test/block_read_cache_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `block_read_cache_test` | `43–100` | 19 | OUT | block read cache bookkeeping | `43-100` | none: OUT |

**`src/test/blockencodings_tests.cpp`** (5 cases; 5 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `SimpleRoundTripTest` | `66–186` | 15 | OUT | compact block encoding round trip and serialization | `66-186` | none: OUT |
| `NonCoinbasePreforwardRTTest` | `187–278` | 16 | OUT | compact block encoding round trip and serialization | `187-278` | none: OUT |
| `SufficientPreforwardRTTest` | `279–345` | 13 | OUT | compact block encoding round trip and serialization | `279-345` | none: OUT |
| `EmptyBlockRoundTripTest` | `346–402` | 7 | OUT | compact block encoding round trip and serialization | `346-402` | none: OUT |
| `TransactionsRequestSerializationTest` | `403–426` | 6 | OUT | compact block encoding round trip and serialization | `403-426` | none: OUT |

**`src/test/blockfile_reading_tests.cpp`** (2 cases; 2 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `read_without_meta_info` | `121–176` | 7 | OUT | block file disk reading | `121-176` | none: OUT |
| `delete_block_file_while_reading` | `177–245` | 2 | OUT | block file disk reading | `177-245` | none: OUT |

**`src/test/blockindex_with_descendants_tests.cpp`** (2 cases; 2 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `basic` | `136–231` | 21 | OUT | block index tree traversal | `136-231` | none: OUT |
| `large` | `232–279` | 8 | OUT | block index tree traversal | `232-279` | none: OUT |

**`src/test/blockmaxsize_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `blockmaxsize_rpc` | `22–41` | 7 | OUT | rpc argument parsing for setblockmaxsize | `22-41` | none: OUT |

**`src/test/blockstatus_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `sighash_construction_test` | `44–133` | 0 | OUT | block status bit flags (case name says sighash; it is not) | `44-133` | none: OUT |

**`src/test/blocktxn_parser_tests.cpp`** (7 cases; 7 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `parse_all` | `43–75` | 9 | OUT | blocktxn network message parser byte counts and reads | `43-75` | none: OUT |
| `parse_as_reqd` | `76–106` | 3 | OUT | blocktxn network message parser byte counts and reads | `76-106` | none: OUT |
| `parse_byte_by_byte` | `107–118` | 1 | OUT | blocktxn network message parser byte counts and reads | `107-118` | none: OUT |
| `read_all` | `119–132` | 3 | OUT | blocktxn network message parser byte counts and reads | `119-132` | none: OUT |
| `read_byte_by_byte` | `133–149` | 2 | OUT | blocktxn network message parser byte counts and reads | `133-149` | none: OUT |
| `read_beyond_parser_size` | `150–163` | 3 | OUT | blocktxn network message parser byte counts and reads | `150-163` | none: OUT |
| `read_partial_msg` | `164–181` | 2 | OUT | blocktxn network message parser byte counts and reads | `164-181` | none: OUT |

**`src/test/blockvalidationstatus_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `blockvalidationstatus_rpc` | `19–58` | 14 | OUT | rpc and block-validation status bookkeeping | `19-58` | none: OUT |

**`src/test/bloom_tests.cpp`** (13 cases; 13 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `bloom_create_insert_serialize` | `37–82` | 9 | OUT | bloom filter matching and merkle block construction (spv filtering, no verdict) | `37-82` | none: OUT |
| `bloom_create_insert_serialize_with_tweak` | `83–118` | 5 | OUT | bloom filter matching and merkle block construction (spv filtering, no verdict) | `83-118` | none: OUT |
| `bloom_create_insert_key` | `119–146` | 2 | OUT | bloom filter matching and merkle block construction (spv filtering, no verdict) | `119-146` | none: OUT |
| `bloom_filter_limits` | `147–171` | 2 | OUT | bloom filter element size limit (filter, not script) | `147-171` | none: OUT |
| `bloom_match` | `172–306` | 13 | OUT | bloom filter matching and merkle block construction (spv filtering, no verdict) | `172-306` | none: OUT |
| `merkle_block_1` | `307–455` | 15 | OUT | bloom filter matching and merkle block construction (spv filtering, no verdict) | `307-455` | none: OUT |
| `merkle_block_2` | `456–569` | 19 | OUT | bloom filter matching and merkle block construction (spv filtering, no verdict) | `456-569` | none: OUT |
| `merkle_block_2_with_update_none` | `570–679` | 17 | OUT | bloom filter matching and merkle block construction (spv filtering, no verdict) | `570-679` | none: OUT |
| `merkle_block_3_and_serialize` | `680–736` | 8 | OUT | bloom filter matching and merkle block construction (spv filtering, no verdict) | `680-736` | none: OUT |
| `merkle_block_4` | `737–870` | 15 | OUT | bloom filter matching and merkle block construction (spv filtering, no verdict) | `737-870` | none: OUT |
| `merkle_block_4_test_p2pubkey_only` | `871–981` | 3 | OUT | bloom filter matching and merkle block construction (spv filtering, no verdict) | `871-981` | none: OUT |
| `merkle_block_4_test_update_none` | `982–1096` | 3 | OUT | bloom filter matching and merkle block construction (spv filtering, no verdict) | `982-1096` | none: OUT |
| `rolling_bloom` | `1097–1172` | 15 | OUT | rolling bloom filter membership | `1097-1172` | none: OUT |

**`src/test/bswap_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `bswap_tests` | `12–24` | 3 | OUT | byte-swap utility only | `12-24` | none: OUT |

**`src/test/check_selfish_mining_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `CheckSelfishMining` | `31–111` | 6 | OUT | mempool selfish-mining detection (CheckSelfishNL), mempool bookkeeping | `31-111` | none: OUT |

**`src/test/checkpoints_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `sanity` | `20–39` | 6 | OUT | chain parameters (checkpoint hash lookup) | `20-39` | none: OUT |

**`src/test/checkqueue_tests.cpp`** (9 cases; 9 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `check_queue_termination` | `76–102` | 1 | OUT | check queue threading with dummy validators, no script run | `76-102` | none: OUT |
| `removal_of_threads_during_processing` | `103–138` | 1 | OUT | check queue threading with dummy validators, no script run | `103-138` | none: OUT |
| `premature_validation_cancellation` | `139–160` | 1 | OUT | check queue threading with dummy validators, no script run | `139-160` | none: OUT |
| `check_queue_pool_termination` | `161–171` | 0 | OUT | check queue threading with dummy validators, no script run | `161-171` | none: OUT |
| `premature_implicit_cancellation_and_reusing_the_worst_checker` | `172–241` | 6 | OUT | check queue threading with dummy validators, no script run | `172-241` | none: OUT |
| `checkqueue_invalid_use_call_wait_before_session` | `242–251` | 1 | OUT | check queue threading with dummy validators, no script run | `242-251` | none: OUT |
| `checkqueue_invalid_use_call_add_before_session` | `252–264` | 1 | OUT | check queue threading with dummy validators, no script run | `252-264` | none: OUT |
| `checkqueue_invalid_use_call_add_after_wait` | `265–278` | 1 | OUT | check queue threading with dummy validators, no script run | `265-278` | none: OUT |
| `checkqueue_invalid_use_call_second_session_before_wait` | `279–294` | 1 | OUT | check queue threading with dummy validators, no script run | `279-294` | none: OUT |

**`src/test/cmpct_size_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `parse_compact_size_test` | `16–53` | 2 | OUT | compact size parsing (serialization only) | `16-53` | none: OUT |

**`src/test/cmpctblock_parser_tests.cpp`** (12 cases; 12 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `parse_all` | `74–107` | 9 | OUT | cmpctblock network message parser byte counts and reads | `74-107` | none: OUT |
| `parse_as_reqd` | `108–136` | 3 | OUT | cmpctblock network message parser byte counts and reads | `108-136` | none: OUT |
| `parse_byte_by_byte` | `137–149` | 1 | OUT | cmpctblock network message parser byte counts and reads | `137-149` | none: OUT |
| `read_all` | `150–166` | 6 | OUT | cmpctblock network message parser byte counts and reads | `150-166` | none: OUT |
| `read_byte_by_byte` | `167–186` | 5 | OUT | cmpctblock network message parser byte counts and reads | `167-186` | none: OUT |
| `read_beyond_parser_size` | `187–201` | 4 | OUT | cmpctblock network message parser byte counts and reads | `187-201` | none: OUT |
| `read_partial_segment_count` | `202–217` | 2 | OUT | cmpctblock network message parser byte counts and reads | `202-217` | none: OUT |
| `read_partial_segment_1` | `218–233` | 2 | OUT | cmpctblock network message parser byte counts and reads | `218-233` | none: OUT |
| `read_partial_segment_2` | `234–249` | 2 | OUT | cmpctblock network message parser byte counts and reads | `234-249` | none: OUT |
| `read_partial_prefilled_tx_count` | `250–268` | 2 | OUT | cmpctblock network message parser byte counts and reads | `250-268` | none: OUT |
| `read_partial_prefilled_tx_1` | `269–288` | 2 | OUT | cmpctblock network message parser byte counts and reads | `269-288` | none: OUT |
| `read_partial_prefilled_tx_2` | `289–310` | 2 | OUT | cmpctblock network message parser byte counts and reads | `289-310` | none: OUT |

**`src/test/coinbase_doc_tests.cpp`** (5 cases; 5 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `default_constructor_equality` | `20–37` | 6 | OUT | miner-id coinbase document equality, no script or transaction verdict | `20-37` | none: OUT |
| `user_defined_constructor_equality` | `38–71` | 6 | OUT | miner-id coinbase document equality, no script or transaction verdict | `38-71` | none: OUT |
| `inequality` | `72–178` | 25 | OUT | miner-id coinbase document equality, no script or transaction verdict | `72-178` | none: OUT |
| `to_and_from_json_static` | `179–205` | 1 | OUT | body commented out at the pin (coinbase document json) | `179-205` | none: OUT |
| `to_and_from_json_dynamic` | `206–232` | 1 | OUT | body commented out at the pin (coinbase document json) | `206-232` | none: OUT |

**`src/test/coins_tests.cpp`** (11 cases; 11 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `coin_serialization` | `172–377` | 36 | OUT | the coins cache and its serialization, no validity check | `172-377` | none: OUT |
| `coin_access` | `378–431` | 2 | OUT | the coins cache and its serialization, no validity check | `378-431` | none: OUT |
| `coin_spend` | `432–512` | 2 | OUT | the coins cache and its serialization, no validity check | `432-512` | none: OUT |
| `coin_add` | `513–586` | 2 | OUT | the coins cache and its serialization, no validity check | `513-586` | none: OUT |
| `coin_write` | `587–665` | 0 | OUT | the coins cache and its serialization, no validity check | `587-665` | none: OUT |
| `coin_get_lazy` | `666–899` | 54 | OUT | the coins cache and its serialization, no validity check | `666-899` | none: OUT |
| `coins_provider_locks` | `900–1025` | 15 | OUT | the coins cache and its serialization, no validity check | `900-1025` | none: OUT |
| `no_coins_caching` | `1026–1197` | 35 | OUT | the coins cache and its serialization, no validity check | `1026-1197` | none: OUT |
| `coins_caching` | `1198–1433` | 50 | OUT | the coins cache and its serialization, no validity check | `1198-1433` | none: OUT |
| `sharding` | `1434–1564` | 22 | OUT | the coins cache and its serialization, no validity check | `1434-1564` | none: OUT |
| `cache_all_inputs` | `1565–1663` | 5 | OUT | the coins cache and its serialization, no validity check | `1565-1663` | none: OUT |

**`src/test/compress_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `compress_amounts` | `42–71` | 11 | OUT | amount compression serialization only | `42-71` | none: OUT |

**`src/test/conditional_tracker_tests.cpp`** (15 cases; 15 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `default_cons` | `10–17` | 3 | OUT | container test of the IF/ELSE tracker state (is_active, empty), no script verdict asserted | `10-17` | none: OUT |
| `op_if_true` | `18–31` | 6 | OUT | container test of the IF/ELSE tracker state (is_active, empty), no script verdict asserted | `18-31` | none: OUT |
| `op_if_false` | `32–45` | 6 | OUT | container test of the IF/ELSE tracker state (is_active, empty), no script verdict asserted | `32-45` | none: OUT |
| `inactive_op_else` | `46–64` | 9 | OUT | container test of the IF/ELSE tracker state (is_active, empty), no script verdict asserted | `46-64` | none: OUT |
| `active_op_else` | `65–83` | 9 | OUT | container test of the IF/ELSE tracker state (is_active, empty), no script verdict asserted | `65-83` | none: OUT |
| `nested_all_true` | `84–100` | 5 | OUT | container test of the IF/ELSE tracker state (is_active, empty), no script verdict asserted | `84-100` | none: OUT |
| `nested_false_blocks_inner` | `101–119` | 7 | OUT | container test of the IF/ELSE tracker state (is_active, empty), no script verdict asserted | `101-119` | none: OUT |
| `toggle_restores_executing_after_nested_false` | `120–134` | 3 | OUT | container test of the IF/ELSE tracker state (is_active, empty), no script verdict asserted | `120-134` | none: OUT |
| `multiple_false_levels` | `135–150` | 4 | OUT | container test of the IF/ELSE tracker state (is_active, empty), no script verdict asserted | `135-150` | none: OUT |
| `if_else_endif_sequence` | `151–166` | 6 | OUT | container test of the IF/ELSE tracker state (is_active, empty), no script verdict asserted | `151-166` | none: OUT |
| `if_else_endif_false_condition` | `167–179` | 3 | OUT | container test of the IF/ELSE tracker state (is_active, empty), no script verdict asserted | `167-179` | none: OUT |
| `pop_false_with_remaining_true` | `180–195` | 5 | OUT | container test of the IF/ELSE tracker state (is_active, empty), no script verdict asserted | `180-195` | none: OUT |
| `pop_false_with_remaining_false` | `196–211` | 5 | OUT | container test of the IF/ELSE tracker state (is_active, empty), no script verdict asserted | `196-211` | none: OUT |
| `pop_true_with_remaining_false` | `212–225` | 3 | OUT | container test of the IF/ELSE tracker state (is_active, empty), no script verdict asserted | `212-225` | none: OUT |
| `toggle_then_pop_with_remaining` | `226–244` | 5 | OUT | container test of the IF/ELSE tracker state (is_active, empty), no script verdict asserted | `226-244` | none: OUT |

**`src/test/config_tests.cpp`** (23 cases; 23 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `max_block_size` | `31–78` | 23 | OUT | config getters and setters | `31-78` | none: OUT |
| `max_block_size_related_defaults` | `79–152` | 17 | OUT | config getters and setters | `79-152` | none: OUT |
| `max_tx_size` | `153–202` | 13 | OUT | config getters and setters | `153-202` | none: OUT |
| `max_bignum_length_policy` | `203–247` | 16 | OUT | config getters and setters | `203-247` | none: OUT |
| `hex_to_array` | `248–257` | 5 | OUT | config getters and setters | `248-257` | none: OUT |
| `chain_params` | `258–271` | 3 | OUT | config getters and setters | `258-271` | none: OUT |
| `max_stack_size` | `272–300` | 17 | OUT | config getters and setters | `272-300` | none: OUT |
| `max_send_queues_size` | `301–314` | 3 | OUT | config getters and setters | `301-314` | none: OUT |
| `block_download_config` | `315–379` | 50 | OUT | config getters and setters | `315-379` | none: OUT |
| `p2p_config` | `380–452` | 55 | OUT | config getters and setters | `380-452` | none: OUT |
| `safe_mode_config` | `453–530` | 54 | OUT | config getters and setters | `453-530` | none: OUT |
| `rpc_config` | `531–564` | 23 | OUT | config getters and setters | `531-564` | none: OUT |
| `dsattempt_config` | `565–655` | 71 | OUT | config getters and setters | `565-655` | none: OUT |
| `minerid_config` | `656–712` | 42 | OUT | config getters and setters | `656-712` | none: OUT |
| `disable_BIP30` | `713–734` | 8 | OUT | config getters and setters | `713-734` | none: OUT |
| `dust_config_test` | `735–752` | 10 | OUT | config getters and setters | `735-752` | none: OUT |
| `banned_clientua_test` | `753–781` | 13 | OUT | config getters and setters | `753-781` | none: OUT |
| `prune_config_test` | `782–791` | 4 | OUT | config getters and setters | `782-791` | none: OUT |
| `tx_validation` | `792–813` | 14 | OUT | config getters and setters | `792-813` | none: OUT |
| `chronicle` | `814–833` | 12 | OUT | config getters and setters | `814-833` | none: OUT |
| `leveldb` | `834–845` | 5 | OUT | config getters and setters | `834-845` | none: OUT |
| `mempool_sync_config` | `846–862` | 9 | OUT | config getters and setters | `846-862` | none: OUT |
| `require_standard` | `863–889` | 3 | OUT | config getters and setters | `863-889` | none: OUT |

**`src/test/configscriptpolicy_tests.cpp`** (8 cases; 8 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `validation_helpers` | `14–34` | 8 | OUT | config setters and getters of ConfigScriptPolicy; no script run | `14-34` | none: OUT |
| `max_ops_per_script_policy_behavior` | `35–47` | 5 | OUT | config setters and getters of ConfigScriptPolicy; no script run | `35-47` | none: OUT |
| `max_script_num_length_behavior` | `48–69` | 9 | OUT | config setters and getters of ConfigScriptPolicy; no script run | `48-69` | none: OUT |
| `max_script_size_policy_behavior` | `70–84` | 5 | OUT | config setters and getters of ConfigScriptPolicy; no script run | `70-84` | none: OUT |
| `pubkeys_per_multisig_policy_behavior` | `85–98` | 5 | OUT | config setters and getters of ConfigScriptPolicy; no script run | `85-98` | none: OUT |
| `stack_memory_usage_behavior` | `99–118` | 10 | OUT | config setters and getters of ConfigScriptPolicy; no script run | `99-118` | none: OUT |
| `protocol_activation_and_graceful_periods` | `119–142` | 14 | OUT | config setters and getters of ConfigScriptPolicy; no script run | `119-142` | none: OUT |
| `reset_default_behavior` | `143–172` | 10 | OUT | config setters and getters of ConfigScriptPolicy; no script run | `143-172` | none: OUT |

**`src/test/core_io_tests.cpp`** (6 cases; 6 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `mt_parse_script_of_opcodes` | `18–51` | 0 | OUT | script assembly text parser (ParseScript), serialization only | `18-51` | none: OUT |
| `test_for_exposition` | `52–106` | 45 | OUT | script assembly text parser (ParseScript), serialization only | `52-106` | none: OUT |
| `parse_hex_test` | `107–158` | 3 | OUT | script assembly text parser (ParseScript), serialization only | `107-158` | none: OUT |
| `printle_tests` | `159–165` | 1 | OUT | script assembly text parser (ParseScript), serialization only | `159-165` | none: OUT |
| `testpushopcode_tests` | `166–171` | 3 | OUT | script assembly text parser (ParseScript), serialization only | `166-171` | none: OUT |
| `parse_push_test` | `172–241` | 38 | OUT | script assembly text parser (ParseScript), serialization only | `172-241` | none: OUT |

**`src/test/cuckoocache_tests.cpp`** (5 cases; 5 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `test_cuckoocache_no_fakes` | `49–118` | 1 | OUT | cuckoo cache container hit rates | `49-118` | none: OUT |
| `cuckoocache_hit_rate_ok` | `119–191` | 3 | OUT | cuckoo cache container hit rates | `119-191` | none: OUT |
| `cuckoocache_erase_ok` | `192–275` | 2 | OUT | cuckoo cache container hit rates | `192-275` | none: OUT |
| `cuckoocache_erase_parallel_ok` | `276–369` | 2 | OUT | cuckoo cache container hit rates | `276-369` | none: OUT |
| `cuckoocache_generations` | `370–374` | 0 | OUT | cuckoo cache container hit rates | `370-374` | none: OUT |

**`src/test/dataref_index_tests.cpp`** (2 cases; 2 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `Creation` | `58–80` | 6 | OUT | miner-id dataref database construction | `58-80` | none: OUT |
| `StorageRetrieval` | `81–143` | 17 | OUT | miner-id dataref database storage and retrieval | `81-143` | none: OUT |

**`src/test/datareftx_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `CreateAndSerialise` | `94–128` | 6 | OUT | serialization and merkle proof of a dataref message, no transaction verdict | `94-128` | none: OUT |

**`src/test/dbwrapper_tests.cpp`** (8 cases; 8 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `dbwrapper` | `46–66` | 4 | OUT | leveldb wrapper read, write and iteration | `46-66` | none: OUT |
| `dbwrapper_batch` | `67–102` | 5 | OUT | leveldb wrapper read, write and iteration | `67-102` | none: OUT |
| `dbwrapper_iterator` | `103–144` | 7 | OUT | leveldb wrapper read, write and iteration | `103-144` | none: OUT |
| `existing_data_no_obfuscate` | `145–187` | 10 | OUT | leveldb wrapper read, write and iteration | `145-187` | none: OUT |
| `existing_data_reindex` | `188–223` | 8 | OUT | leveldb wrapper read, write and iteration | `188-223` | none: OUT |
| `iterator_ordering` | `224–295` | 7 | OUT | leveldb wrapper read, write and iteration | `224-295` | none: OUT |
| `iterator_string_ordering` | `296–355` | 7 | OUT | leveldb wrapper read, write and iteration | `296-355` | none: OUT |
| `bulk_rw` | `356–427` | 5 | OUT | leveldb wrapper read, write and iteration | `356-427` | none: OUT |

**`src/test/disk_backed_parser_tests.cpp`** (8 cases; 8 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `basic_write_read_cycle` | `29–59` | 6 | OUT | disk-backed message parser i/o | `29-59` | none: OUT |
| `large_message` | `60–90` | 6 | OUT | disk-backed message parser i/o | `60-90` | none: OUT |
| `random_access_reads` | `91–120` | 4 | OUT | disk-backed message parser i/o | `91-120` | none: OUT |
| `filename_uniqueness` | `121–142` | 3 | OUT | disk-backed message parser i/o | `121-142` | none: OUT |
| `file_deletion_on_destruction` | `143–179` | 3 | OUT | disk-backed message parser i/o | `143-179` | none: OUT |
| `write_after_complete` | `180–201` | 5 | OUT | disk-backed message parser i/o | `180-201` | none: OUT |
| `move_assignment_transfers_state` | `202–231` | 5 | OUT | disk-backed message parser i/o | `202-231` | none: OUT |
| `test_error_paths` | `232–282` | 5 | OUT | disk-backed message parser i/o | `232-282` | none: OUT |

**`src/test/dsattempt_tests.cpp`** (3 cases; 3 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `CallbackMsg` | `33–91` | 18 | OUT | double-spend callback message serialization and output recognition | `33-91` | none: OUT |
| `CallbackEnabledTransaction` | `92–114` | 4 | OUT | double-spend callback message serialization and output recognition | `92-114` | none: OUT |
| `CallbackMallformed` | `115–179` | 7 | OUT | double-spend callback message serialization and output recognition | `115-179` | none: OUT |

**`src/test/dsdetected_tests.cpp`** (21 cases; 21 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `default_construction` | `123–129` | 2 | OUT | limited_cache container (limited_cache_tests suite) | `910-934` | none: OUT |
| `default_hash` | `130–147` | 2 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `130-147` | none: OUT |
| `sorted_hasher` | `148–179` | 1 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `148-179` | none: OUT |
| `CreationSerialisation` | `180–320` | 5 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `180-320` | none: OUT |
| `MsgMalformed` | `321–330` | 1 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `321-330` | none: OUT |
| `deserialize_happy_case` | `331–389` | 0 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `331-389` | none: OUT |
| `deserialize_invalid_dsdetected_version` | `390–410` | 1 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `390-410` | none: OUT |
| `deserialize_too_few_block_details` | `411–454` | 1 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `411-454` | none: OUT |
| `deserialize_no_block_headers` | `455–479` | 1 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `455-479` | none: OUT |
| `deserialize_invalid_invalid_merkle_proof_flags` | `480–544` | 1 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `480-544` | none: OUT |
| `deserialize_invalid_invalid_merkle_proof_index` | `545–609` | 1 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `545-609` | none: OUT |
| `deserialize_invalid_invalid_merkle_proof_node_type` | `610–677` | 1 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `610-677` | none: OUT |
| `validate_fork_count` | `678–697` | 5 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `678-697` | none: OUT |
| `IsValid_no_headers` | `698–703` | 1 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `698-703` | none: OUT |
| `headers_form_chain` | `704–728` | 5 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `704-728` | none: OUT |
| `contains_duplicate_headers` | `729–746` | 4 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `729-746` | none: OUT |
| `common_ancestor` | `747–775` | 4 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `747-775` | none: OUT |
| `ds_outpoints` | `776–810` | 3 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `776-810` | none: OUT |
| `tx_uniqueness` | `811–837` | 2 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `811-837` | none: OUT |
| `header_hash` | `838–909` | 7 | OUT | double-spend-detected p2p message construction, serialization and structural validation, networking | `838-909` | none: OUT |
| `default_construction` | `910–934` | 14 | OUT | limited_cache container (limited_cache_tests suite) | `910-934` | none: OUT |

**`src/test/dstencode_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `test_addresses` | `15–43` | 7 | OUT | address encoding and decoding | `15-43` | none: OUT |

**`src/test/dstxn_serialiser_tests.cpp`** (2 cases; 2 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `Serialise` | `22–56` | 6 | OUT | double-spend txn file serialiser, file handling only | `22-56` | none: OUT |
| `FileDescriptor` | `57–109` | 11 | OUT | file descriptor wrapper only | `57-109` | none: OUT |

**`src/test/enum_cast_tests.cpp`** (2 cases; 2 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `TestCorrectEnumCast` | `31–45` | 3 | OUT | enum to string utility | `31-45` | none: OUT |
| `TestUnknownEnumCast` | `46–55` | 1 | OUT | enum to string utility | `46-55` | none: OUT |

**`src/test/excessiveblock_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `excessiveblock_rpc` | `21–64` | 17 | OUT | rpc and config (setexcessiveblock) | `21-64` | none: OUT |

**`src/test/fixed_len_multi_parser_tests.cpp`** (30 cases; 30 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `parse_empty_input` | `25–37` | 5 | OUT | p2p message parser (fixed_len_multi_parser), networking | `25-37` | none: OUT |
| `parse_zero_count` | `38–51` | 5 | OUT | p2p message parser (fixed_len_multi_parser), networking | `38-51` | none: OUT |
| `parse_count_only` | `52–65` | 5 | OUT | p2p message parser (fixed_len_multi_parser), networking | `52-65` | none: OUT |
| `parse_max_shortids_count_only` | `66–78` | 4 | OUT | p2p message parser (fixed_len_multi_parser), networking | `66-78` | none: OUT |
| `parse_max_shortids_count_and_partial_fixed_len` | `79–92` | 4 | OUT | p2p message parser (fixed_len_multi_parser), networking | `79-92` | none: OUT |
| `parse_max_shortids_count_and_short_id` | `93–106` | 4 | OUT | p2p message parser (fixed_len_multi_parser), networking | `93-106` | none: OUT |
| `parse_max_shortids_count_short_id_and_partial_short_id` | `107–121` | 4 | OUT | p2p message parser (fixed_len_multi_parser), networking | `107-121` | none: OUT |
| `overflow_with_shortids_and_partial_short_id` | `122–146` | 4 | OUT | p2p message parser (fixed_len_multi_parser), networking | `122-146` | none: OUT |
| `parse_sid_1_seg_1` | `147–160` | 5 | OUT | p2p message parser (fixed_len_multi_parser), networking | `147-160` | none: OUT |
| `parse_sid_2_seg_1` | `161–174` | 5 | OUT | p2p message parser (fixed_len_multi_parser), networking | `161-174` | none: OUT |
| `parse_sid_2_seg_2` | `175–188` | 5 | OUT | p2p message parser (fixed_len_multi_parser), networking | `175-188` | none: OUT |
| `parse_sid_3_seg_2` | `189–202` | 5 | OUT | p2p message parser (fixed_len_multi_parser), networking | `189-202` | none: OUT |
| `parse_sid_200_seg_100` | `203–216` | 5 | OUT | p2p message parser (fixed_len_multi_parser), networking | `203-216` | none: OUT |
| `parse_sid_70117_seg_100_1_pass` | `217–240` | 5 | OUT | p2p message parser (fixed_len_multi_parser), networking | `217-240` | none: OUT |
| `parse_sid_70117_seg_100` | `241–278` | 10 | OUT | p2p message parser (fixed_len_multi_parser), networking | `241-278` | none: OUT |
| `parse_only_counted_bytes` | `279–294` | 5 | OUT | p2p message parser (fixed_len_multi_parser), networking | `279-294` | none: OUT |
| `parse_half_a_sid` | `295–316` | 9 | OUT | p2p message parser (fixed_len_multi_parser), networking | `295-316` | none: OUT |
| `parse_part_msg` | `317–339` | 4 | OUT | p2p message parser (fixed_len_multi_parser), networking | `317-339` | none: OUT |
| `parse_all` | `340–378` | 11 | OUT | p2p message parser (fixed_len_multi_parser), networking | `340-378` | none: OUT |
| `parse_byte_by_byte` | `379–391` | 1 | OUT | p2p message parser (fixed_len_multi_parser), networking | `379-391` | none: OUT |
| `parse_as_reqd` | `392–420` | 3 | OUT | p2p message parser (fixed_len_multi_parser), networking | `392-420` | none: OUT |
| `seg_offset` | `421–453` | 14 | OUT | p2p message parser (fixed_len_multi_parser), networking | `421-453` | none: OUT |
| `read_all` | `454–468` | 4 | OUT | p2p message parser (fixed_len_multi_parser), networking | `454-468` | none: OUT |
| `read_empty_span` | `469–479` | 1 | OUT | p2p message parser (fixed_len_multi_parser), networking | `469-479` | none: OUT |
| `read_empty_parser` | `480–487` | 1 | OUT | p2p message parser (fixed_len_multi_parser), networking | `480-487` | none: OUT |
| `read_byte_by_byte` | `488–504` | 2 | OUT | p2p message parser (fixed_len_multi_parser), networking | `488-504` | none: OUT |
| `read_beyond_parser_size` | `505–517` | 2 | OUT | p2p message parser (fixed_len_multi_parser), networking | `505-517` | none: OUT |
| `read_reset_check` | `518–532` | 3 | OUT | p2p message parser (fixed_len_multi_parser), networking | `518-532` | none: OUT |
| `read_partial_segment_1` | `533–546` | 2 | OUT | p2p message parser (fixed_len_multi_parser), networking | `533-546` | none: OUT |
| `read_partial_segment_2` | `547–561` | 2 | OUT | p2p message parser (fixed_len_multi_parser), networking | `547-561` | none: OUT |

**`src/test/fixed_len_parser_tests.cpp`** (3 cases; 3 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `construction` | `19–26` | 2 | OUT | fixed-length message parser byte counts | `19-26` | none: OUT |
| `fixed` | `27–67` | 12 | OUT | fixed-length message parser byte counts | `27-67` | none: OUT |
| `byte_by_byte` | `68–87` | 4 | OUT | fixed-length message parser byte counts | `68-87` | none: OUT |

**`src/test/getarg_tests.cpp`** (6 cases; 6 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `boolarg` | `36–88` | 24 | OUT | command-line argument parsing | `36-88` | none: OUT |
| `stringarg` | `89–110` | 10 | OUT | command-line argument parsing | `89-110` | none: OUT |
| `intarg` | `111–146` | 22 | OUT | command-line argument parsing | `111-146` | none: OUT |
| `doublearg` | `147–160` | 6 | OUT | command-line argument parsing | `147-160` | none: OUT |
| `doubledash` | `161–169` | 3 | OUT | command-line argument parsing | `161-169` | none: OUT |
| `boolargno` | `170–194` | 10 | OUT | command-line argument parsing | `170-194` | none: OUT |

**`src/test/hash_tests.cpp`** (3 cases; 3 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `murmurhash3` | `16–85` | 1 | OUT | hash function test vectors only | `16-85` | none: OUT |
| `siphash` | `86–180` | 15 | OUT | hash function test vectors only | `86-180` | none: OUT |
| `hashverifier_tests` | `181–201` | 3 | OUT | hash writer/verifier stream only | `181-201` | none: OUT |

**`src/test/inv_tests.cpp`** (2 cases; 2 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `validate_kind` | `19–34` | 1 | OUT | p2p inv message types | `19-34` | none: OUT |
| `validate_cmd` | `35–43` | 0 | OUT | p2p inv message types | `35-43` | none: OUT |

**`src/test/journal_assembler_group_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `TestJournalAddGroup` | `126–194` | 18 | OUT | mining journal and block template assembly bookkeeping (counts) | `126-194` | none: OUT |

**`src/test/journal_tests.cpp`** (3 cases; 3 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `TestJournalAddRemove` | `99–194` | 38 | OUT | mining journal bookkeeping | `99-194` | none: OUT |
| `TestJournalReorg` | `195–251` | 15 | OUT | mining journal bookkeeping on reorg | `195-251` | none: OUT |
| `TestJournalCheckToposort` | `252–414` | 21 | OUT | mining journal change-set topological order bookkeeping | `252-414` | none: OUT |

**`src/test/json_tests.cpp`** (24 cases; 24 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `CJWriter_write_array` | `15–23` | 1 | OUT | json writer output formatting | `15-23` | none: OUT |
| `CJWriter_write_object` | `24–32` | 1 | OUT | json writer output formatting | `24-32` | none: OUT |
| `CJWriter_pushK` | `33–40` | 1 | OUT | json writer output formatting | `33-40` | none: OUT |
| `CJWriter_pushV` | `41–48` | 1 | OUT | json writer output formatting | `41-48` | none: OUT |
| `CJWriter_pushKVMoney` | `49–56` | 1 | OUT | json writer output formatting | `49-56` | none: OUT |
| `CJWriter_pushKVString` | `57–64` | 1 | OUT | json writer output formatting | `57-64` | none: OUT |
| `CJWriter_pushKVChar` | `65–73` | 1 | OUT | json writer output formatting | `65-73` | none: OUT |
| `CJWriter_pushKVInt64` | `74–81` | 1 | OUT | json writer output formatting | `74-81` | none: OUT |
| `CJWriter_pushKVInt` | `82–89` | 1 | OUT | json writer output formatting | `82-89` | none: OUT |
| `CJWriter_pushKVBool` | `90–97` | 1 | OUT | json writer output formatting | `90-97` | none: OUT |
| `CJWriter_pushKVDouble` | `98–105` | 1 | OUT | json writer output formatting | `98-105` | none: OUT |
| `CJWriter_pushKVNullPtr` | `106–113` | 1 | OUT | json writer output formatting | `106-113` | none: OUT |
| `CJWriter_pushQuote` | `114–156` | 1 | OUT | json writer output formatting | `114-156` | none: OUT |
| `CJWriter_write_JSONText` | `157–167` | 1 | OUT | json writer output formatting | `157-167` | none: OUT |
| `CJWriter_write_JSONText_with_indents` | `168–178` | 1 | OUT | json writer output formatting | `168-178` | none: OUT |
| `CJWriter_write_array_of_objects` | `179–197` | 1 | OUT | json writer output formatting | `179-197` | none: OUT |
| `CJWriter_write_array_within_array` | `198–214` | 1 | OUT | json writer output formatting | `198-214` | none: OUT |
| `CJWriter_empty_array` | `215–223` | 1 | OUT | json writer output formatting | `215-223` | none: OUT |
| `CJWriter_array_with_value` | `224–233` | 1 | OUT | json writer output formatting | `224-233` | none: OUT |
| `CJWriter_empty_object` | `234–242` | 1 | OUT | json writer output formatting | `234-242` | none: OUT |
| `CJWriter_object_with_value` | `243–252` | 1 | OUT | json writer output formatting | `243-252` | none: OUT |
| `json_decode_tx_from_mainnet` | `253–287` | 1 | OUT | json well-formedness of TxToJSON output (serialization only) | `253-287` | none: OUT |
| `json_decode_tx_with_2_same_inputs_outputs_addresses` | `288–321` | 1 | OUT | json well-formedness of TxToJSON output (serialization only) | `288-321` | none: OUT |
| `json_decode_block_with_2tx_with_same_inputs_outputs_addresses` | `322–363` | 1 | OUT | json well-formedness of TxToJSON output (serialization only) | `322-363` | none: OUT |

**`src/test/key_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `key_test1` | `61–209` | 77 | OUT | key, address and raw ecdsa sign/verify/recover api, no script verdict | `61-209` | none: OUT |

**`src/test/leaky_bucket_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `FillDrain` | `13–59` | 20 | OUT | leaky bucket rate limiter | `13-59` | none: OUT |

**`src/test/limitedmap_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `limitedmap_test` | `13–105` | 23 | OUT | container only | `13-105` | none: OUT |

**`src/test/locked_ref_tests.cpp`** (2 cases; 2 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `ConstructUnique` | `14–31` | 5 | OUT | locked reference container | `14-31` | none: OUT |
| `ConstructShared` | `32–58` | 8 | OUT | locked reference container | `32-58` | none: OUT |

**`src/test/m_candidates_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `add_remove_candidates` | `12–58` | 11 | OUT | mining candidate manager bookkeeping | `12-58` | none: OUT |

**`src/test/main_tests.cpp`** (3 cases; 3 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `block_subsidy_test` | `41–47` | 0 | OUT | block subsidy schedule (GetBlockSubsidy), block-level | `41-47` | none: OUT |
| `subsidy_limit_test` | `48–66` | 3 | OUT | block subsidy sum (GetBlockSubsidy, MoneyRange on the subsidy total, not a transaction) | `48-66` | none: OUT |
| `test_combiner_all` | `67–79` | 5 | OUT | signal combiner utility | `67-79` | none: OUT |

**`src/test/mempool_dump_load_tests.cpp`** (9 cases; 9 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `DumpLoadFormat1` | `150–159` | 1 | OUT | mempool dump/load persistence with a stub validator returning a default CValidationState | `39-56, 113-139` | none: OUT |
| `DumpLoadFormat1Empty` | `160–169` | 1 | OUT | mempool dump/load persistence with a stub validator returning a default CValidationState | `39-56, 113-139` | none: OUT |
| `DumpLoadFormat1WithOnDiskTxs` | `170–179` | 1 | OUT | mempool dump/load persistence with a stub validator returning a default CValidationState | `39-56, 113-139` | none: OUT |
| `DumpLoadFormat1Expired` | `180–189` | 1 | OUT | mempool dump/load persistence with a stub validator returning a default CValidationState | `39-56, 113-139` | none: OUT |
| `DumpLoadFormat2` | `190–199` | 1 | OUT | mempool dump/load persistence with a stub validator returning a default CValidationState | `39-56, 113-139` | none: OUT |
| `DumpLoadFormat2Empty` | `200–209` | 1 | OUT | mempool dump/load persistence with a stub validator returning a default CValidationState | `39-56, 113-139` | none: OUT |
| `DumpLoadFormat2WithOnDiskTxs` | `210–219` | 1 | OUT | mempool dump/load persistence with a stub validator returning a default CValidationState | `39-56, 113-139` | none: OUT |
| `DumpLoadFormat2Expired` | `220–229` | 1 | OUT | mempool dump/load persistence with a stub validator returning a default CValidationState | `39-56, 113-139` | none: OUT |
| `DumpLoadFormat2WithOnDiskTxsExpired` | `230–239` | 1 | OUT | mempool dump/load persistence with a stub validator returning a default CValidationState | `39-56, 113-139` | none: OUT |

**`src/test/mempool_snapshot_tests.cpp`** (8 cases; 8 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `ValidateTestPool` | `132–136` | 1 | OUT | mempool snapshot bookkeeping (GetSnapshot, GetTxSnapshot) | `132-136` | none: OUT |
| `PoolSnapshotTest` | `137–171` | 15 | OUT | mempool snapshot bookkeeping (GetSnapshot, GetTxSnapshot) | `137-171` | none: OUT |
| `InvalidTxIdTest` | `172–206` | 20 | OUT | mempool snapshot bookkeeping (GetSnapshot, GetTxSnapshot) | `172-206` | none: OUT |
| `SingleTest` | `207–289` | 69 | OUT | mempool snapshot bookkeeping (GetSnapshot, GetTxSnapshot) | `207-289` | none: OUT |
| `TxWithAncestorsTest` | `290–372` | 69 | OUT | mempool snapshot bookkeeping (GetSnapshot, GetTxSnapshot) | `290-372` | none: OUT |
| `OnlyAncestorsTest` | `373–455` | 69 | OUT | mempool snapshot bookkeeping (GetSnapshot, GetTxSnapshot) | `373-455` | none: OUT |
| `TxWithDescendantsTest` | `456–538` | 69 | OUT | mempool snapshot bookkeeping (GetSnapshot, GetTxSnapshot) | `456-538` | none: OUT |
| `OnlyDescendantsTest` | `539–622` | 69 | OUT | mempool snapshot bookkeeping (GetSnapshot, GetTxSnapshot) | `539-622` | none: OUT |

**`src/test/mempooltxdb_tests.cpp`** (20 cases; 20 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `GetSetXrefKey` | `84–97` | 5 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `84-97` | none: OUT |
| `RemoveXrefKey` | `98–111` | 5 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `98-111` | none: OUT |
| `BatchWriteWrite` | `112–135` | 7 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `112-135` | none: OUT |
| `BatchWriteRemove` | `136–159` | 7 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `136-159` | none: OUT |
| `BatchWriteRemoveWrite` | `160–184` | 7 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `160-184` | none: OUT |
| `AsyncWriteToTxDB` | `185–210` | 5 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `185-210` | none: OUT |
| `AsyncDeleteFromTxDB` | `211–242` | 5 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `211-242` | none: OUT |
| `AsyncClearDB` | `243–268` | 5 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `243-268` | none: OUT |
| `AsyncMultiWriteCoalesce` | `269–295` | 6 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `269-295` | none: OUT |
| `AsyncMultiWriteRemoveCoalesce` | `296–342` | 6 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `296-342` | none: OUT |
| `AsyncGetSetXrefKey` | `343–356` | 5 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `343-356` | none: OUT |
| `AsyncRemoveXrefKey` | `357–370` | 5 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `357-370` | none: OUT |
| `AsyncAutoRemoveXrefKey` | `371–392` | 8 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `371-392` | none: OUT |
| `SaveOnFullMempool` | `393–470` | 12 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `393-470` | none: OUT |
| `RemoveFromDiskOnMempoolTrim` | `471–503` | 9 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `471-503` | none: OUT |
| `RemoveFromDiskOnMempoolTrimDoesNotConfuseJBA` | `504–616` | 14 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `504-616` | none: OUT |
| `CheckMempoolTxDB` | `617–737` | 21 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `617-737` | none: OUT |
| `TxWrapper_UniqueOwned` | `738–747` | 1 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `738-747` | none: OUT |
| `TxWrapper_UniqueOwnedWeak` | `748–766` | 5 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `748-766` | none: OUT |
| `TxWrapper_EventuallyUniqueWeak` | `767–799` | 8 | OUT | mempool disk store bookkeeping (AddUnchecked, no validation) | `767-799` | none: OUT |

**`src/test/merkle_tests.cpp`** (12 cases; 12 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `merkle_test` | `90–198` | 13 | OUT | block merkle root and mutation detection, block-level | `90-198` | none: OUT |
| `merkle_tree_test` | `199–239` | 1 | OUT | merkle tree computation only | `199-239` | none: OUT |
| `default_construction` | `240–254` | 8 | OUT | merkle proof construction only | `240-254` | none: OUT |
| `txid_construction` | `255–272` | 8 | OUT | merkle proof construction only | `255-272` | none: OUT |
| `tx_construction` | `273–287` | 5 | OUT | merkle proof construction only | `273-287` | none: OUT |
| `deserialize_txid` | `288–333` | 1 | OUT | merkle proof deserialization only | `288-333` | none: OUT |
| `deserialize_tx` | `334–387` | 1 | OUT | merkle proof deserialization only | `334-387` | none: OUT |
| `deserialize_std_example` | `388–426` | 5 | OUT | merkle proof deserialization only | `388-426` | none: OUT |
| `default_serialisation` | `427–437` | 1 | OUT | merkle proof serialization only | `427-437` | none: OUT |
| `txid_serialisation` | `438–452` | 1 | OUT | merkle proof serialization only | `438-452` | none: OUT |
| `tx_serialization` | `453–468` | 1 | OUT | merkle proof serialization only | `453-468` | none: OUT |
| `merkle_proof` | `469–559` | 9 | OUT | merkle proof verification against a root, not a script or transaction verdict | `469-559` | none: OUT |

**`src/test/merkletreefile_readwrite_tests.cpp`** (2 cases; 2 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `write_read_test` | `109–133` | 2 | OUT | merkle tree disk store | `109-133` | none: OUT |
| `write_prune_load_test` | `134–175` | 5 | OUT | merkle tree disk store and pruning | `134-175` | none: OUT |

**`src/test/miner_info_doc_tests.cpp`** (37 cases; 37 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `parse_miner_info_doc_script_failure_cases` | `196–234` | 2 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `196-234` | none: OUT |
| `parse_miner_info_doc_script_happy_case` | `235–280` | 4 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `235-280` | none: OUT |
| `parse_miner_info_doc_ill_formed_json` | `281–293` | 2 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `281-293` | none: OUT |
| `parse_miner_info_doc_required_fields` | `294–317` | 2 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `294-317` | none: OUT |
| `parse_miner_info_doc_bad_version` | `318–340` | 2 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `318-340` | none: OUT |
| `parse_miner_info_doc_bad_height` | `341–362` | 2 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `341-362` | none: OUT |
| `parse_miner_info_doc_invalid_miner_id` | `363–384` | 2 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `363-384` | none: OUT |
| `parse_miner_info_doc_invalid_prev_miner_id` | `385–406` | 2 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `385-406` | none: OUT |
| `parse_miner_info_doc_invalid_prev_miner_id_sig` | `407–450` | 3 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `407-450` | none: OUT |
| `parse_miner_info_doc_invalid_revocation_key` | `451–472` | 2 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `451-472` | none: OUT |
| `parse_miner_info_doc_invalid_prev_revocation_key` | `473–494` | 2 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `473-494` | none: OUT |
| `parse_miner_info_doc_invalid_prev_revocation_key_sig` | `495–516` | 2 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `495-516` | none: OUT |
| `parse_miner_info_doc_prevRevSig_verification_fail` | `517–537` | 1 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `517-537` | none: OUT |
| `parse_miner_info_doc_rev_msg_is_not_an_object` | `538–561` | 1 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `538-561` | none: OUT |
| `parse_revocation_msg_only` | `562–585` | 1 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `562-585` | none: OUT |
| `parse_revocation_msg_sig_only` | `586–606` | 1 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `586-606` | none: OUT |
| `parse_revocation_msg_no_compromised_minerId_field` | `607–630` | 1 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `607-630` | none: OUT |
| `parse_revocation_msg_invalid_key` | `631–654` | 1 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `631-654` | none: OUT |
| `parse_revocation_msg_invalid_sig1` | `655–681` | 1 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `655-681` | none: OUT |
| `parse_revocation_msg_invalid_sig1_key` | `682–708` | 1 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `682-708` | none: OUT |
| `parse_revocation_msg_invalid_sig2` | `709–736` | 1 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `709-736` | none: OUT |
| `parse_revocation_msg_invalid_sig2_key` | `737–770` | 1 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `737-770` | none: OUT |
| `revocation_message_construction` | `771–779` | 3 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `771-779` | none: OUT |
| `revocation_message_equality` | `780–800` | 6 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `780-800` | none: OUT |
| `parse_revocation_sig_1_verification_fail` | `801–831` | 1 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `801-831` | none: OUT |
| `parse_revocation_sig_2_verification_fail` | `832–862` | 1 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `832-862` | none: OUT |
| `parse_datarefs_invalid_json` | `863–918` | 1 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `863-918` | none: OUT |
| `parse_datarefs_invalid_datarefs_type` | `919–937` | 1 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `919-937` | none: OUT |
| `parse_datarefs_happy_case` | `938–961` | 1 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `938-961` | none: OUT |
| `parse_datarefs_invalid_datarefs_refs_type` | `962–981` | 1 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `962-981` | none: OUT |
| `parse_miner_info_doc_without_rev_msg_happy_case` | `982–999` | 2 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `982-999` | none: OUT |
| `parse_miner_info_doc_with_rev_msg_happy_case` | `1000–1034` | 2 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `1000-1034` | none: OUT |
| `parse_miner_info_doc_with_datarefs_happy_case` | `1035–1074` | 3 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `1035-1074` | none: OUT |
| `verify_data_script_failure_cases` | `1075–1107` | 2 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `1075-1107` | none: OUT |
| `verify_data_script_happy_case` | `1108–1136` | 1 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `1108-1136` | none: OUT |
| `parse_dataref_objects_invalid_json` | `1137–1163` | 1 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `1137-1163` | none: OUT |
| `parse_dataref_objects_happy_case` | `1164–1172` | 2 | OUT | miner-id info document and OP_RETURN data parsing (ParseMinerInfoScript, ParseMinerInfoDoc, VerifyDataScript), no script verdict | `1164-1172` | none: OUT |

**`src/test/miner_info_error_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `miner_info_error_op_insertion` | `18–82` | 1 | OUT | printer of miner info error strings | `18-82` | none: OUT |

**`src/test/miner_info_ref_tests.cpp`** (5 cases; 5 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `miref_construction` | `23–34` | 2 | OUT | miner-id info reference parsing (ParseMinerInfoRef), no script verdict | `23-34` | none: OUT |
| `miref_equality` | `35–65` | 9 | OUT | miner-id info reference parsing (ParseMinerInfoRef), no script verdict | `35-65` | none: OUT |
| `parse_miner_id_ref_happy_case` | `66–115` | 3 | OUT | miner-id info reference parsing (ParseMinerInfoRef), no script verdict | `66-115` | none: OUT |
| `parse_miner_id_ref_failure_cases` | `116–174` | 2 | OUT | miner-id info reference parsing (ParseMinerInfoRef), no script verdict | `116-174` | none: OUT |
| `parse_miner_info_ref_from_string` | `175–194` | 1 | OUT | miner-id info reference parsing (ParseMinerInfoRef), no script verdict | `175-194` | none: OUT |

**`src/test/miner_info_tests.cpp`** (13 cases; 13 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `block_bind_construction` | `28–42` | 2 | OUT | miner info document parsing and block binding, not a script or transaction verdict | `28-42` | none: OUT |
| `block_bind_equality` | `43–66` | 7 | OUT | miner info document parsing and block binding, not a script or transaction verdict | `43-66` | none: OUT |
| `is_hash_256_test` | `67–100` | 28 | OUT | miner info document parsing and block binding, not a script or transaction verdict | `67-100` | none: OUT |
| `is_compressed_key_test` | `101–161` | 50 | OUT | miner info document parsing and block binding, not a script or transaction verdict | `101-161` | none: OUT |
| `is_der_signature_test` | `162–235` | 53 | OUT | miner info document parsing and block binding, not a script or transaction verdict | `162-235` | none: OUT |
| `parse_miner_info_empty_block` | `236–243` | 1 | OUT | miner info document parsing and block binding, not a script or transaction verdict | `236-243` | none: OUT |
| `parse_miner_info_no_miner_info_ref_in_block` | `244–251` | 1 | OUT | miner info document parsing and block binding, not a script or transaction verdict | `244-251` | none: OUT |
| `parse_miner_info_no_miner_info_ref_error` | `252–271` | 1 | OUT | miner info document parsing and block binding, not a script or transaction verdict | `252-271` | none: OUT |
| `parse_miner_info_no_miner_info_in_block` | `272–299` | 1 | OUT | miner info document parsing and block binding, not a script or transaction verdict | `272-299` | none: OUT |
| `parse_miner_info_invalid_miner_info_doc` | `300–353` | 1 | OUT | miner info document parsing and block binding, not a script or transaction verdict | `300-353` | none: OUT |
| `modified_merkle_root_test` | `354–394` | 1 | OUT | miner info document parsing and block binding, not a script or transaction verdict | `354-394` | none: OUT |
| `verify_sig_blockbind_mismatch` | `395–441` | 1 | OUT | miner info document parsing and block binding, not a script or transaction verdict | `395-441` | none: OUT |
| `verify_sig_verification_fail` | `442–506` | 1 | OUT | miner info document parsing and block binding, not a script or transaction verdict | `442-506` | none: OUT |

**`src/test/minerid_tests.cpp`** (7 cases; 7 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `staticMinerId_v1` | `196–370` | 14 | OUT | miner id coinbase document parsing (FindMinerId), not a script or transaction verdict | `196-370` | none: OUT |
| `staticMinerId_v2` | `371–435` | 1 | OUT | miner id coinbase document parsing (FindMinerId), not a script or transaction verdict | `371-435` | none: OUT |
| `dynamicMinerId` | `436–609` | 8 | OUT | miner id coinbase document parsing (FindMinerId), not a script or transaction verdict | `436-609` | none: OUT |
| `v1_mainet_block_624455` | `610–665` | 2 | OUT | miner id coinbase document parsing (FindMinerId), not a script or transaction verdict | `610-665` | none: OUT |
| `v1_mainet_block_697014` | `666–725` | 2 | OUT | miner id coinbase document parsing (FindMinerId), not a script or transaction verdict | `666-725` | none: OUT |
| `v2_stn_block_12170` | `726–793` | 2 | OUT | miner id coinbase document parsing (FindMinerId), not a script or transaction verdict | `726-793` | none: OUT |
| `ri` | `794–850` | 2 | OUT | miner id coinbase document parsing (FindMinerId), not a script or transaction verdict | `794-850` | none: OUT |

**`src/test/mining_group_builder_tests.cpp`** (4 cases; 4 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `TestNewGroupID` | `145–160` | 6 | OUT | mining group builder bookkeeping | `145-160` | none: OUT |
| `TestStandaloneTxn` | `161–208` | 22 | OUT | mining group builder bookkeeping | `161-208` | none: OUT |
| `TestGroupTxn` | `209–263` | 24 | OUT | mining group builder bookkeeping | `209-263` | none: OUT |
| `TestSelfishDetection` | `264–308` | 12 | OUT | mining group selfish-detection (block assembly), not a transaction verdict | `264-308` | none: OUT |

**`src/test/msg_buffer_tests.cpp`** (7 cases; 7 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `write_read_happy_case` | `94–128` | 5 | OUT | p2p message buffer read/write, networking | `94-128` | none: OUT |
| `write_read_past_the_end_of_header` | `129–150` | 2 | OUT | p2p message buffer read/write, networking | `129-150` | none: OUT |
| `write_read_past_the_end_of_payload` | `151–189` | 5 | OUT | p2p message buffer read/write, networking | `151-189` | none: OUT |
| `write_read_std_header` | `190–214` | 2 | OUT | p2p message buffer read/write, networking | `190-214` | none: OUT |
| `write_read_block_msg` | `215–232` | 2 | OUT | p2p message buffer read/write, networking | `215-232` | none: OUT |
| `read_null_payload` | `233–245` | 1 | OUT | p2p message buffer read/write, networking | `233-245` | none: OUT |
| `read_too_much` | `246–281` | 1 | OUT | p2p message buffer read/write, networking | `246-281` | none: OUT |

**`src/test/msg_parser_buffer_tests.cpp`** (17 cases; 17 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `mod_n_byte_parser_tests` | `53–83` | 15 | OUT | network message parser buffer sizes | `53-83` | none: OUT |
| `buffer_empty_input_empty` | `84–95` | 5 | OUT | network message parser buffer sizes | `84-95` | none: OUT |
| `buffer_empty_bytes_read_bytes_reqd` | `96–107` | 5 | OUT | network message parser buffer sizes | `96-107` | none: OUT |
| `buffer_empty_bytes_read_no_bytes_reqd` | `108–119` | 5 | OUT | network message parser buffer sizes | `108-119` | none: OUT |
| `buffer_empty_no_bytes_read_bytes_reqd` | `120–138` | 10 | OUT | network message parser buffer sizes | `120-138` | none: OUT |
| `buffer_empty_no_bytes_read_no_bytes_reqd` | `139–150` | 5 | OUT | network message parser buffer sizes | `139-150` | none: OUT |
| `buffer_not_empty_input_empty` | `151–169` | 10 | OUT | network message parser buffer sizes | `151-169` | none: OUT |
| `buffer_not_empty_bytes_read_bytes_reqd` | `170–188` | 10 | OUT | network message parser buffer sizes | `170-188` | none: OUT |
| `buffer_not_empty_bytes_read_no_bytes_reqd` | `189–237` | 10 | OUT | network message parser buffer sizes | `189-237` | none: OUT |
| `buffer_not_empty_no_bytes_read_bytes_reqd` | `238–256` | 10 | OUT | network message parser buffer sizes | `238-256` | none: OUT |
| `buffer_unread_input` | `257–271` | 2 | OUT | network message parser buffer sizes | `257-271` | none: OUT |
| `buffer_unread_input_and_use_in_next_call` | `272–337` | 17 | OUT | network message parser buffer sizes | `272-337` | none: OUT |
| `parse_byte_by_byte` | `338–357` | 2 | OUT | network message parser buffer sizes | `338-357` | none: OUT |
| `parse_byte_by_n_bytes` | `358–377` | 2 | OUT | network message parser buffer sizes | `358-377` | none: OUT |
| `parse_buffer_size` | `378–410` | 6 | OUT | network message parser buffer sizes | `378-410` | none: OUT |
| `overflow_on_nothing_read_or_reqd` | `411–425` | 4 | OUT | network message parser buffer sizes | `411-425` | none: OUT |
| `handle_parser_not_reading_reqd_bytes` | `426–466` | 6 | OUT | network message parser buffer sizes | `426-466` | none: OUT |

**`src/test/net_association_tests.cpp`** (5 cases; 5 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `TestBasicStream` | `48–77` | 6 | OUT | network association and stream bookkeeping | `48-77` | none: OUT |
| `TestBasicAssociation` | `78–129` | 20 | OUT | network association and stream bookkeeping | `78-129` | none: OUT |
| `TestAssociationID` | `130–171` | 14 | OUT | network association and stream bookkeeping | `130-171` | none: OUT |
| `TestStreamPolicyFactory` | `172–188` | 3 | OUT | network association and stream bookkeeping | `172-188` | none: OUT |
| `TestStreamPolicyConfig` | `189–238` | 8 | OUT | network association and stream bookkeeping | `189-238` | none: OUT |

**`src/test/net_message_disk_tests.cpp`** (5 cases; 5 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `threshold_detection_small_message` | `66–87` | 2 | OUT | network message disk buffering | `66-87` | none: OUT |
| `threshold_detection_large_message` | `88–116` | 2 | OUT | network message disk buffering | `88-116` | none: OUT |
| `data_integrity_disk_vs_memory` | `117–162` | 4 | OUT | network message disk buffering | `117-162` | none: OUT |
| `sequential_messages` | `163–200` | 4 | OUT | network message disk buffering | `163-200` | none: OUT |
| `partial_read_during_reception` | `201–229` | 3 | OUT | network message disk buffering | `201-229` | none: OUT |

**`src/test/net_message_maker_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `Make` | `13–29` | 4 | OUT | network message construction | `13-29` | none: OUT |

**`src/test/net_message_tests.cpp`** (6 cases; 6 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `read_0_bytes` | `27–37` | 2 | OUT | network message header and payload parsing (serialization only) | `27-37` | none: OUT |
| `read_header_only_msg` | `38–75` | 6 | OUT | network message header and payload parsing (serialization only) | `38-75` | none: OUT |
| `read_ping_msg` | `76–120` | 7 | OUT | network message header and payload parsing (serialization only) | `76-120` | none: OUT |
| `read_extmsg_msg` | `121–179` | 9 | OUT | network message header and payload parsing (serialization only) | `121-179` | none: OUT |
| `read_block_msg` | `180–249` | 7 | OUT | network message header and payload parsing (serialization only) | `180-249` | none: OUT |
| `block_msg_with_superflous_data` | `250–294` | 6 | OUT | network message header and payload parsing (serialization only) | `250-294` | none: OUT |

**`src/test/net_tests.cpp`** (4 cases; 4 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `caddrdb_read` | `72–116` | 5 | OUT | address db and node object networking | `72-116` | none: OUT |
| `caddrdb_read_corrupted` | `117–149` | 5 | OUT | address db and node object networking | `117-149` | none: OUT |
| `cnode_simple_test` | `150–196` | 4 | OUT | address db and node object networking | `150-196` | none: OUT |
| `test_userAgentLength` | `197–219` | 3 | OUT | address db and node object networking | `197-219` | none: OUT |

**`src/test/netbase_tests.cpp`** (6 cases; 6 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `netbase_networks` | `27–33` | 4 | OUT | network address parsing | `27-33` | none: OUT |
| `netbase_properties` | `34–64` | 19 | OUT | network address parsing | `34-64` | none: OUT |
| `netbase_splithost` | `65–89` | 15 | OUT | network address parsing | `65-89` | none: OUT |
| `netbase_lookupnumeric` | `90–99` | 7 | OUT | network address parsing | `90-99` | none: OUT |
| `subnet_test` | `100–262` | 86 | OUT | network address parsing | `100-262` | none: OUT |
| `netbase_getgroup` | `263–297` | 11 | OUT | network address parsing | `263-297` | none: OUT |

**`src/test/object_stream_deserialization_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `block_test` | `13–40` | 2 | OUT | serialization only (block stream reader) | `13-40` | none: OUT |

**`src/test/pmt_tests.cpp`** (2 cases; 2 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `pmt_test1` | `32–121` | 7 | OUT | partial merkle tree, block-level proof structure | `32-121` | none: OUT |
| `pmt_malleability` | `122–136` | 1 | OUT | partial merkle tree extraction | `122-136` | none: OUT |

**`src/test/pow_tests.cpp`** (7 cases; 7 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `get_next_work` | `30–45` | 1 | OUT | block-level (proof-of-work difficulty retargeting) | `30-45` | none: OUT |
| `get_next_work_pow_limit` | `46–61` | 1 | OUT | block-level (proof-of-work difficulty retargeting) | `46-61` | none: OUT |
| `get_next_work_lower_limit_actual` | `62–77` | 1 | OUT | block-level (proof-of-work difficulty retargeting) | `62-77` | none: OUT |
| `get_next_work_upper_limit_actual` | `78–92` | 1 | OUT | block-level (proof-of-work difficulty retargeting) | `78-92` | none: OUT |
| `GetBlockProofEquivalentTime_test` | `93–139` | 1 | OUT | block-level (proof-of-work difficulty retargeting) | `93-139` | none: OUT |
| `retargeting_test` | `140–250` | 8 | OUT | block-level (proof-of-work difficulty retargeting) | `140-250` | none: OUT |
| `cash_difficulty_test` | `251–498` | 22 | OUT | block-level (proof-of-work difficulty retargeting) | `251-498` | none: OUT |

**`src/test/prefilled_tx_parser_tests.cpp`** (7 cases; 7 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `parse_empty_input` | `117–127` | 3 | OUT | p2p transaction byte parser only | `117-127` | none: OUT |
| `parse_index_var_int_len_3` | `128–138` | 3 | OUT | p2p transaction byte parser only | `128-138` | none: OUT |
| `parse_index_var_int_len_5` | `139–149` | 3 | OUT | p2p transaction byte parser only | `139-149` | none: OUT |
| `parse_index_var_int_len_9` | `150–160` | 3 | OUT | p2p transaction byte parser only | `150-160` | none: OUT |
| `parse_index_var_int_len_1` | `161–171` | 3 | OUT | p2p transaction byte parser only | `161-171` | none: OUT |
| `parse_in_one_pass` | `172–192` | 5 | OUT | p2p transaction byte parser only | `172-192` | none: OUT |
| `parse_as_reqd` | `193–228` | 3 | OUT | p2p transaction byte parser only | `193-228` | none: OUT |

**`src/test/prefilled_txs_parser_tests.cpp`** (3 cases; 3 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `parse_empty_input` | `111–122` | 3 | OUT | p2p prefilled txs parser, serialization only | `111-122` | none: OUT |
| `parse_count_0` | `123–134` | 3 | OUT | p2p prefilled txs parser, serialization only | `123-134` | none: OUT |
| `parse_count_1` | `135–151` | 3 | OUT | p2p prefilled txs parser, serialization only | `135-151` | none: OUT |

**`src/test/prevector_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `PrevectorTestInt` | `179–254` | 0 | OUT | prevector container | `179-254` | none: OUT |

**`src/test/protocol_era_tests.cpp`** (3 cases; 3 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `status_checks` | `37–130` | 56 | OUT | activation-height helpers (era and grace period lookup, no verdict) | `37-130` | none: OUT |
| `grace_period_tests` | `131–153` | 12 | OUT | activation-height helpers (era and grace period lookup, no verdict) | `131-153` | none: OUT |
| `inverse_protocol_eras` | `154–168` | 6 | OUT | activation-height helpers (era and grace period lookup, no verdict) | `154-168` | none: OUT |

**`src/test/protocol_tests.cpp`** (5 cases; 5 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `protocol_msghdr_length` | `85–164` | 34 | OUT | p2p message header and networking | `85-164` | none: OUT |
| `protocol_estimate_inv_elements` | `165–198` | 3 | OUT | p2p message header and networking | `165-198` | none: OUT |
| `protocol_msghdr_magic` | `199–210` | 2 | OUT | p2p message header and networking | `199-210` | none: OUT |
| `protocol_msghdr_command` | `211–265` | 21 | OUT | p2p message header and networking | `211-265` | none: OUT |
| `net_messages` | `266–340` | 8 | OUT | p2p message header and networking | `266-340` | none: OUT |

**`src/test/raii_event_tests.cpp`** (2 cases; 2 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `raii_event_creation` | `43–70` | 6 | OUT | libevent raii wrappers, memory bookkeeping | `43-70` | none: OUT |
| `raii_event_order` | `71–94` | 2 | OUT | libevent raii wrappers, memory bookkeeping | `71-94` | none: OUT |

**`src/test/random_tests.cpp`** (3 cases; 3 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `osrandom_tests` | `13–16` | 1 | OUT | random number generator | `13-16` | none: OUT |
| `fastrandom_tests` | `17–43` | 15 | OUT | random number generator | `17-43` | none: OUT |
| `fastrandom_randbits` | `44–58` | 2 | OUT | random number generator | `44-58` | none: OUT |

**`src/test/reverselock_tests.cpp`** (2 cases; 2 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `reverselock_basics` | `12–23` | 3 | OUT | lock utility | `12-23` | none: OUT |
| `reverselock_errors` | `24–58` | 7 | OUT | lock utility | `24-58` | none: OUT |

**`src/test/revokemid_tests.cpp`** (3 cases; 3 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `default_construction` | `92–105` | 6 | OUT | revokemid p2p message construction | `92-105` | none: OUT |
| `key_construction` | `106–140` | 10 | OUT | revokemid p2p message signatures, not script | `106-140` | none: OUT |
| `serialisation` | `141–154` | 1 | OUT | revokemid message serialization only | `141-154` | none: OUT |

**`src/test/safe_mode_tests.cpp`** (9 cases; 9 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `get_min_relevant_block_height` | `18–43` | 1 | OUT | safe mode fork tracking, block index level | `18-43` | none: OUT |
| `exclude_ignored_blocks_nullptr` | `44–53` | 2 | OUT | safe mode fork tracking, block index level | `44-53` | none: OUT |
| `exclude_ignored_blocks` | `54–98` | 3 | OUT | safe mode fork tracking, block index level | `54-98` | none: OUT |
| `get_fork_tips_0` | `99–105` | 1 | OUT | safe mode fork tracking, block index level | `99-105` | none: OUT |
| `get_fork_tips_1` | `106–117` | 1 | OUT | safe mode fork tracking, block index level | `106-117` | none: OUT |
| `get_fork_tips_2` | `118–129` | 2 | OUT | safe mode fork tracking, block index level | `118-129` | none: OUT |
| `get_fork_tips_3` | `130–147` | 3 | OUT | safe mode fork tracking, block index level | `130-147` | none: OUT |
| `check_safe_mode_parameters_nullptr` | `148–158` | 1 | OUT | safe mode fork tracking, block index level | `148-158` | none: OUT |
| `check_safe_mode_parameters_safe_mode_max_fork_dist` | `159–222` | 3 | OUT | safe mode fork tracking, block index level | `159-222` | none: OUT |

**`src/test/sanity_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `basic_sanity` | `13–19` | 3 | OUT | library sanity checks | `13-19` | none: OUT |

**`src/test/scheduler_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `manythreads` | `39–127` | 6 | OUT | thread scheduler | `39-127` | none: OUT |

**`src/test/serialize_tests.cpp`** (19 cases; 19 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `sizes` | `91–120` | 24 | OUT | serialization only | `91-120` | none: OUT |
| `floats_conversion` | `121–138` | 12 | OUT | serialization only | `121-138` | none: OUT |
| `doubles_conversion` | `139–170` | 12 | OUT | serialization only | `139-170` | none: OUT |
| `floats` | `171–188` | 2 | OUT | serialization only | `171-188` | none: OUT |
| `doubles` | `189–206` | 2 | OUT | serialization only | `189-206` | none: OUT |
| `varints` | `207–260` | 6 | OUT | serialization only | `207-260` | none: OUT |
| `varints_bitpatterns` | `261–323` | 16 | OUT | serialization only | `261-323` | none: OUT |
| `compactsize` | `324–358` | 6 | OUT | serialization only | `324-358` | none: OUT |
| `noncanonical` | `359–400` | 7 | OUT | serialization only | `359-400` | none: OUT |
| `insert_delete` | `401–447` | 20 | OUT | serialization only | `401-447` | none: OUT |
| `class_methods` | `448–475` | 5 | OUT | serialization only | `448-475` | none: OUT |
| `map_set_serialise` | `476–545` | 8 | OUT | serialization only | `476-545` | none: OUT |
| `optional_serialise` | `546–580` | 4 | OUT | serialization only | `546-580` | none: OUT |
| `no_args_ser_size` | `581–585` | 1 | OUT | serialization only | `581-585` | none: OUT |
| `txin_ser_size` | `586–601` | 4 | OUT | serialization only | `586-601` | none: OUT |
| `txout_ser_size` | `602–617` | 4 | OUT | serialization only | `602-617` | none: OUT |
| `tx_ser_size` | `618–640` | 5 | OUT | serialization only | `618-640` | none: OUT |
| `btx_ser_size` | `641–660` | 5 | OUT | serialization only | `641-660` | none: OUT |
| `cinv_ser_size` | `661–681` | 6 | OUT | serialization only | `661-681` | none: OUT |

**`src/test/single_seg_parser_tests.cpp`** (7 cases; 7 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `default_construction` | `19–24` | 1 | OUT | p2p transaction stream segment parser, serialization only | `19-24` | none: OUT |
| `default_move` | `25–35` | 3 | OUT | p2p transaction stream segment parser, serialization only | `25-35` | none: OUT |
| `single_seg_parser_lvalue` | `36–47` | 2 | OUT | p2p transaction stream segment parser, serialization only | `36-47` | none: OUT |
| `single_seg_parser_xvalue` | `48–59` | 2 | OUT | p2p transaction stream segment parser, serialization only | `48-59` | none: OUT |
| `single_seg_parser_prvalue` | `60–70` | 2 | OUT | p2p transaction stream segment parser, serialization only | `60-70` | none: OUT |
| `single_seg_parser_ptr` | `71–124` | 2 | OUT | p2p transaction stream segment parser, serialization only | `71-124` | none: OUT |
| `parse_large_outputs` | `125–135` | 3 | OUT | p2p transaction stream segment parser, serialization only | `125-135` | none: OUT |

**`src/test/skiplist_tests.cpp`** (3 cases; 3 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `skiplist_test` | `25–70` | 6 | OUT | block index skiplist and locator | `25-70` | none: OUT |
| `getlocator_test` | `71–171` | 12 | OUT | block index skiplist and locator | `71-171` | none: OUT |
| `findearliestatleast_test` | `172–236` | 4 | OUT | block index skiplist and locator | `172-236` | none: OUT |

**`src/test/stream_serialization_tests.cpp`** (6 cases; 6 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `empty_block` | `37–41` | 0 | OUT | serialization only | `37-41` | none: OUT |
| `block` | `42–46` | 0 | OUT | serialization only | `42-46` | none: OUT |
| `read_big_chunks` | `47–51` | 0 | OUT | serialization only | `47-51` | none: OUT |
| `exception` | `52–94` | 4 | OUT | stream reader exception handling | `52-94` | none: OUT |
| `known_size_input` | `95–110` | 1 | OUT | serialization only | `95-110` | none: OUT |
| `known_size_input_async_reader` | `111–165` | 2 | OUT | serialization only (async reader) | `111-163` | none: OUT |

**`src/test/streams_tests.cpp`** (3 cases; 3 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `streams_vector_writer` | `16–74` | 14 | OUT | serialization streams only | `16-74` | none: OUT |
| `streams_serializedata_xor` | `75–119` | 3 | OUT | serialization streams only | `75-119` | none: OUT |
| `streams_empty_vector` | `120–138` | 0 | OUT | serialization streams only | `120-138` | none: OUT |

**`src/test/string_writer_tests.cpp`** (3 cases; 3 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `CStringWriter_writechar` | `12–18` | 1 | OUT | string writer utility | `12-18` | none: OUT |
| `CStringWriter_writestring` | `19–25` | 1 | OUT | string writer utility | `19-25` | none: OUT |
| `CStringWriter_writestring_withNL` | `26–34` | 1 | OUT | string writer utility | `26-34` | none: OUT |

**`src/test/taskcancellation_tests.cpp`** (6 cases; 6 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `cancellation` | `40–46` | 0 | OUT | cancellation token timing, no verdict | `40-46` | none: OUT |
| `token_joining` | `47–90` | 6 | OUT | cancellation token timing, no verdict | `47-90` | none: OUT |
| `cancellation_after_500ms` | `91–103` | 2 | OUT | cancellation token timing, no verdict | `91-103` | none: OUT |
| `cancellation_after_500ms_budget` | `104–152` | 7 | OUT | cancellation token timing, no verdict | `104-152` | none: OUT |
| `thread_cancellation_after_500ms_cpu` | `153–165` | 2 | OUT | cancellation token timing, no verdict | `153-165` | none: OUT |
| `thread_cancellation_after_500ms_cpu_budget` | `166–203` | 7 | OUT | cancellation token timing, no verdict | `166-203` | none: OUT |

**`src/test/test_orphantxns.cpp`** (15 cases; 15 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `test_orphantxns_creation` | `116–127` | 1 | OUT | orphan pool bookkeeping (add, erase, collect, limits) | `116-127` | none: OUT |
| `test_orphantxns_addtxn_erasetxns` | `128–152` | 2 | OUT | orphan pool bookkeeping (add, erase, collect, limits) | `128-152` | none: OUT |
| `test_orphantxns_limit_txns_size` | `153–188` | 7 | OUT | orphan pool bookkeeping (add, erase, collect, limits) | `153-188` | none: OUT |
| `test_orphantxns_checktxnexists` | `189–216` | 4 | OUT | orphan pool bookkeeping (add, erase, collect, limits) | `189-216` | none: OUT |
| `test_orphantxns_erasetxn` | `217–249` | 4 | OUT | orphan pool bookkeeping (add, erase, collect, limits) | `217-249` | none: OUT |
| `test_orphantxns_erasetxnfrompeer` | `250–283` | 4 | OUT | orphan pool bookkeeping (add, erase, collect, limits) | `250-283` | none: OUT |
| `test_gettxids` | `284–313` | 1 | OUT | orphan pool bookkeeping (add, erase, collect, limits) | `284-313` | none: OUT |
| `test_orphantxns_erasecollectedtxdatafromtxns` | `314–369` | 3 | OUT | orphan pool bookkeeping (add, erase, collect, limits) | `314-369` | none: OUT |
| `test_orphantxns_getcollectedtxdata` | `370–410` | 3 | OUT | orphan pool bookkeeping (add, erase, collect, limits) | `370-410` | none: OUT |
| `test_orphantxns_collectdependenttxnsforretry` | `411–470` | 7 | OUT | orphan pool bookkeeping (add, erase, collect, limits) | `411-470` | none: OUT |
| `test_orphantxns_collectdependenttxnsforretry2` | `471–507` | 4 | OUT | orphan pool bookkeeping (add, erase, collect, limits) | `471-507` | none: OUT |
| `test_orphantxns_do_not_collect_tx_with_too_many_inputs` | `508–572` | 6 | OUT | orphan pool bookkeeping (add, erase, collect, limits) | `508-572` | none: OUT |
| `test_orphantxns_do_not_collect_tx_with_too_many_outputs` | `573–628` | 6 | OUT | orphan pool bookkeeping (add, erase, collect, limits) | `573-628` | none: OUT |
| `test_orphantxns_max_percentage_in_batch` | `629–672` | 2 | OUT | orphan pool bookkeeping (add, erase, collect, limits) | `629-672` | none: OUT |
| `test_orphantxns_max_percentage_in_batch_first_layer` | `673–711` | 2 | OUT | orphan pool bookkeeping (add, erase, collect, limits) | `673-711` | none: OUT |

**`src/test/test_recent_rejects.cpp`** (3 cases; 3 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `test_creation` | `14–21` | 1 | OUT | recent-rejects hash set bookkeeping | `14-21` | none: OUT |
| `test_insert_isrejected` | `22–35` | 1 | OUT | recent-rejects hash set bookkeeping | `22-35` | none: OUT |
| `test_reset` | `36–54` | 6 | OUT | recent-rejects hash set bookkeeping | `36-54` | none: OUT |

**`src/test/test_txid_tracker.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `test_api` | `13–41` | 9 | OUT | txid tracker container | `13-41` | none: OUT |

**`src/test/test_txnvalidation_utils.cpp`** (2 cases; 2 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `test_number_of_priority_threads_static` | `26–108` | 50 | OUT | validation thread-count config | `26-108` | none: OUT |
| `test_number_of_priority_threads_dynamic` | `109–128` | 6 | OUT | validation thread-count config | `109-128` | none: OUT |

**`src/test/thread_safe_queue_tests.cpp`** (8 cases; 8 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `multiple_inputs_full_queue` | `88–150` | 10 | OUT | thread-safe queue container | `88-150` | none: OUT |
| `fill_replace` | `151–197` | 17 | OUT | thread-safe queue container | `151-197` | none: OUT |
| `fill_replace_dynamic` | `198–245` | 18 | OUT | thread-safe queue container | `198-245` | none: OUT |
| `multiple_outputs` | `246–406` | 17 | OUT | thread-safe queue container | `246-406` | none: OUT |
| `stress_test_fixed_element_size` | `407–427` | 1 | OUT | thread-safe queue container | `407-427` | none: OUT |
| `stress_test_dynamic_element_size` | `428–454` | 1 | OUT | thread-safe queue container | `428-454` | none: OUT |
| `nowait` | `455–487` | 11 | OUT | thread-safe queue container | `455-487` | none: OUT |
| `dynamic_size` | `488–519` | 7 | OUT | thread-safe queue container | `488-519` | none: OUT |

**`src/test/threadpool_tests.cpp`** (6 cases; 6 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `NonPrioritised` | `47–81` | 3 | OUT | thread pool utility | `47-81` | none: OUT |
| `Prioritised` | `82–139` | 8 | OUT | thread pool utility | `82-139` | none: OUT |
| `DualQueueProcessedByPriotisedThreadsCase1` | `140–176` | 3 | OUT | thread pool utility | `140-176` | none: OUT |
| `DualQueueProcessedByPriotisedThreadsCase2` | `177–213` | 3 | OUT | thread pool utility | `177-213` | none: OUT |
| `DualQueueProcessedByPriotisedThreadsCase3` | `214–240` | 3 | OUT | thread pool utility | `214-240` | none: OUT |
| `DualQueueProcessedByPriotisedThreadsCase4` | `241–268` | 3 | OUT | thread pool utility | `241-268` | none: OUT |

**`src/test/time_limited_blacklist_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `add_remove` | `14–88` | 37 | OUT | double-spend notification server blacklist container (src/double_spend/dsattempt_handler.h:194), not frozen outputs | `14-88` | none: OUT |

**`src/test/timedata_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `util_MedianFilter` | `12–36` | 7 | OUT | median filter utility | `12-36` | none: OUT |

**`src/test/ttor_tests.cpp`** (3 cases; 3 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `invalidate_chain` | `72–139` | 5 | OUT | block-level (InvalidateChain, block index status) | `72-139` | none: OUT |
| `check_ttor` | `140–176` | 2 | OUT | block-level (CheckBlockTTOROrder) | `140-176` | none: OUT |
| `check_ttor_advanced` | `177–242` | 3 | OUT | block-level (CheckBlockTTOROrder) | `177-242` | none: OUT |

**`src/test/tx_parser_tests.cpp`** (6 cases; 6 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `tx_parser_by_parts` | `114–378` | 62 | OUT | p2p transaction byte parser, serialization only | `114-378` | none: OUT |
| `tx_parser_1_pass` | `379–389` | 4 | OUT | p2p transaction byte parser, serialization only | `379-389` | none: OUT |
| `tx_parser_2_pass` | `390–403` | 4 | OUT | p2p transaction byte parser, serialization only | `390-403` | none: OUT |
| `tx_parser_as_reqd` | `404–433` | 4 | OUT | p2p transaction byte parser, serialization only | `404-433` | none: OUT |
| `parse_large_input_count_and_script_len` | `434–448` | 2 | OUT | p2p transaction byte parser, serialization only | `434-448` | none: OUT |
| `parse_large_output_count_and_script_len` | `449–471` | 2 | OUT | p2p transaction byte parser, serialization only | `449-471` | none: OUT |

**`src/test/txn_grouper_tests.cpp`** (5 cases; 5 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `empty` | `70–85` | 5 | OUT | grouping of block transactions by dependency for parallel validation, no verdict | `70-85` | none: OUT |
| `independent_groups` | `86–132` | 13 | OUT | grouping of block transactions by dependency for parallel validation, no verdict | `86-132` | none: OUT |
| `single_dependency` | `133–165` | 3 | OUT | grouping of block transactions by dependency for parallel validation, no verdict | `133-165` | none: OUT |
| `multi_dependency` | `166–262` | 12 | OUT | grouping of block transactions by dependency for parallel validation, no verdict | `166-262` | none: OUT |
| `corner_cases` | `263–315` | 6 | OUT | grouping of block transactions by dependency for parallel validation, no verdict | `263-315` | none: OUT |

**`src/test/txs_parser_tests.cpp`** (9 cases; 9 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `txs_parser_by_parts` | `121–328` | 63 | OUT | p2p transaction byte parser only | `121-328` | none: OUT |
| `txs_parser_1_pass` | `329–341` | 4 | OUT | p2p transaction byte parser only | `329-341` | none: OUT |
| `txs_parser_2_pass` | `342–354` | 2 | OUT | p2p transaction byte parser only | `342-354` | none: OUT |
| `txs_parser_as_reqd` | `355–394` | 9 | OUT | p2p transaction byte parser only | `355-394` | none: OUT |
| `parse_0_tx_count` | `395–407` | 4 | OUT | p2p transaction byte parser only | `395-407` | none: OUT |
| `read_txs` | `408–440` | 11 | OUT | p2p transaction byte parser only | `408-440` | none: OUT |
| `read_all` | `441–455` | 4 | OUT | p2p transaction byte parser only | `441-455` | none: OUT |
| `read_byte_by_byte` | `456–473` | 2 | OUT | p2p transaction byte parser only | `456-473` | none: OUT |
| `read_beyond_parser_size` | `474–488` | 2 | OUT | p2p transaction byte parser only | `474-488` | none: OUT |

**`src/test/uint256_tests.cpp`** (4 cases; 4 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `basics` | `70–121` | 41 | OUT | uint256 / arith_uint256 container arithmetic, not script numbers | `70-121` | none: OUT |
| `comparison` | `122–154` | 14 | OUT | uint256 / arith_uint256 container arithmetic, not script numbers | `122-154` | none: OUT |
| `methods` | `155–251` | 62 | OUT | uint256 / arith_uint256 container arithmetic, not script numbers | `155-251` | none: OUT |
| `conversion` | `252–267` | 12 | OUT | uint256 / arith_uint256 container arithmetic, not script numbers | `252-267` | none: OUT |

**`src/test/undo_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `connect_utxo_extblock` | `90–143` | 8 | OUT | block-level undo of the utxo set (UpdateCoins, ApplyBlockUndo) | `90-143` | none: OUT |

**`src/test/univalue_tests.cpp`** (6 cases; 6 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `univalue_constructor` | `17–63` | 19 | OUT | json value container | `17-63` | none: OUT |
| `univalue_typecheck` | `64–104` | 27 | OUT | json value container | `64-104` | none: OUT |
| `univalue_set` | `105–162` | 41 | OUT | json value container | `105-162` | none: OUT |
| `univalue_array` | `163–199` | 14 | OUT | json value container | `163-199` | none: OUT |
| `univalue_object` | `200–287` | 36 | OUT | json value container | `200-287` | none: OUT |
| `univalue_readwrite` | `288–348` | 27 | OUT | json value container | `288-348` | none: OUT |

**`src/test/util_tests.cpp`** (35 cases; 35 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `util_criticalsection` | `23–47` | 0 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `23-47` | none: OUT |
| `util_ParseHex` | `48–73` | 4 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `48-73` | none: OUT |
| `util_HexStr` | `74–90` | 4 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `74-90` | none: OUT |
| `util_DateTimeStrFormat` | `91–104` | 5 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `91-104` | none: OUT |
| `util_DateTimeFormatISO8601` | `105–117` | 2 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `105-117` | none: OUT |
| `util_ParseParameters` | `118–150` | 7 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `118-150` | none: OUT |
| `util_GetArg` | `151–174` | 9 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `151-174` | none: OUT |
| `util_FormatMoney` | `175–198` | 20 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `175-198` | none: OUT |
| `util_ParseMoney` | `199–250` | 42 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `199-250` | none: OUT |
| `util_IsHex` | `251–264` | 10 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `251-264` | none: OUT |
| `util_IsHexNumber` | `265–287` | 19 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `265-287` | none: OUT |
| `util_seed_insecure_rand` | `288–312` | 2 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `288-312` | none: OUT |
| `util_TimingResistantEqual` | `313–326` | 7 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `313-326` | none: OUT |
| `strprintf_numbers` | `327–353` | 9 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `327-353` | none: OUT |
| `gettime` | `354–357` | 1 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `354-357` | none: OUT |
| `test_ParseInt32` | `358–385` | 19 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `358-385` | none: OUT |
| `test_ParseInt64` | `386–416` | 20 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `386-416` | none: OUT |
| `test_ParseUInt32` | `417–446` | 21 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `417-446` | none: OUT |
| `test_ParseUInt64` | `447–480` | 22 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `447-480` | none: OUT |
| `test_ParseDouble` | `481–507` | 18 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `481-507` | none: OUT |
| `test_FormatParagraph` | `508–582` | 16 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `508-582` | none: OUT |
| `test_FormatSubVersion` | `583–601` | 3 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `583-601` | none: OUT |
| `test_ParseFixedPoint` | `602–704` | 68 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `602-704` | none: OUT |
| `test_ConvertBits` | `705–728` | 0 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `705-728` | none: OUT |
| `transform_hex_happy_case` | `729–740` | 2 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `729-740` | none: OUT |
| `transform_hex_empty` | `741–751` | 2 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `741-751` | none: OUT |
| `transform_hex_uppercase_hex` | `752–760` | 2 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `752-760` | none: OUT |
| `transform_hex_1_element` | `761–772` | 2 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `761-772` | none: OUT |
| `transform_hex_2_elements` | `773–784` | 2 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `773-784` | none: OUT |
| `transform_hex_3_elements` | `785–800` | 2 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `785-800` | none: OUT |
| `transform_pairs_4_elements` | `801–815` | 2 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `801-815` | none: OUT |
| `transform_pairs_3_elements` | `816–830` | 2 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `816-830` | none: OUT |
| `transform_pairs_2_elements` | `831–845` | 2 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `831-845` | none: OUT |
| `transform_pairs_1_element` | `846–858` | 2 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `846-858` | none: OUT |
| `transform_pairs_empty` | `859–872` | 2 | OUT | utility parsing and formatting (hex, money strings, ints, time, args) | `859-872` | none: OUT |

**`src/test/validation_scheduler_tests.cpp`** (9 cases; 9 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `txs_isolated` | `221–242` | 3 | OUT | validation scheduling order with a dummy task, no verdict | `221-242` | none: OUT |
| `txs_chains` | `243–275` | 0 | OUT | validation scheduling order with a dummy task, no verdict | `243-275` | none: OUT |
| `txs_twoParallelChains` | `276–312` | 0 | OUT | validation scheduling order with a dummy task, no verdict | `276-312` | none: OUT |
| `txs_graph` | `313–346` | 0 | OUT | validation scheduling order with a dummy task, no verdict | `313-346` | none: OUT |
| `txs_graphManyLinks` | `347–381` | 0 | OUT | validation scheduling order with a dummy task, no verdict | `347-381` | none: OUT |
| `txs_detectChainInGraph` | `382–410` | 0 | OUT | validation scheduling order with a dummy task, no verdict | `382-410` | none: OUT |
| `txs_graphAndChains` | `411–462` | 0 | OUT | validation scheduling order with a dummy task, no verdict | `411-462` | none: OUT |
| `txs_chainInTwoParts` | `463–495` | 0 | OUT | validation scheduling order with a dummy task, no verdict | `463-495` | none: OUT |
| `txs_validationThrows` | `496–522` | 0 | OUT | validation scheduling order with a dummy task, no verdict | `496-522` | none: OUT |

**`src/test/validation_tests.cpp`** (1 cases; 1 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `validation_load_external_block_file` | `37–80` | 4 | OUT | block file loading (LoadExternalBlockFile), block-level | `37-80` | none: OUT |

**`src/test/verify_script_flags_tests.cpp`** (2 cases; 2 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `get_script_verify_flags` | `15–56` | 1 | OUT | flag selection from the era and node settings (GetScriptVerifyFlags): a function of the activation heights and of -requirestandard, not of the script or the transaction; the era is the spec's named parameter. A border call, named for the lens | `15-56` | none: OUT |
| `get_block_script_flags` | `57–88` | 1 | OUT | flag selection from the block height and the activation heights (GetBlockScriptFlags), not of the script or the transaction. A border call, named for the lens | `57-88` | none: OUT |

**`src/test/webhook_client_tests.cpp`** (2 cases; 2 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `RequestResponse` | `145–167` | 2 | OUT | http webhook client | `145-167` | none: OUT |
| `ErrorResponseRetry` | `168–199` | 1 | OUT | http webhook client | `168-199` | none: OUT |

**`src/test/write_preferring_upgradable_mutex_tests.cpp`** (6 cases; 6 OUT)

| case | lines at the pin | check sites | class | why | decisive lines | entries |
|---|---|---|---|---|---|---|
| `write_lock_request_waits_for_read_locks` | `12–93` | 11 | OUT | mutex locking behaviour | `12-93` | none: OUT |
| `prefering_write_to_read_request_lock` | `94–170` | 16 | OUT | mutex locking behaviour | `94-170` | none: OUT |
| `lock_escalation` | `171–185` | 4 | OUT | mutex locking behaviour | `171-185` | none: OUT |
| `duplicate_read_lock_even_if_write_lock_pending` | `186–237` | 9 | OUT | mutex locking behaviour | `186-237` | none: OUT |
| `multiple_consecutive_exclusive_write_locks` | `238–302` | 11 | OUT | mutex locking behaviour | `238-302` | none: OUT |
| `prefer_exclusive_to_non_exclusive_write_locks` | `303–365` | 10 | OUT | mutex locking behaviour | `303-365` | none: OUT |

## 3. The extraction contract

**The reader.** `tools/cpp_extract.sh` copies the pinned source, applies `corpus/cpp/instrument.patch`, builds `test_bitcoin` and runs the extracted suites with `CPPX_OUT` set; the patch's header `src/test/cpp_extract.h` turns every `EvalScript` call of an instrumented test file into a recorded call (a macro over the pinned `EvalScript`, `interpreter.h:219–225`), and a `CPPX_EXPECT` hook written after the call's checks attaches what those checks assert. With `CPPX_OUT` unset the instrumented tests run as at the pin. The script then shapes the dump into one JSONL file per test file. `[M]`

**One entry per recorded call or asserted predicate.** Each `EvalScript` and `VerifyScript` call an instrumented test makes is an entry, and so is each predicate check a hook transcribes (below). A helper that runs a script under each of the three flag words of `opcode_tests.cpp:31–33` (`flagset`) gives three entries; a helper that runs it again without the upgrade flag gives a fourth. Nothing is deduplicated: two entries with the same input and different citations are two checks the reference's developers wrote.

**The entry's fields.** The corpus's spend families (`corpus/stack`, `corpus/flow`) carry `id`, `family`, `rule`, `tx`, `prevouts`, `params`, `expect` keyed by engine, `note`. An entry here is not a spend: the reference's unit tests call the interpreter on a stack they build, so `kind` is `evalscript` and the input is the interpreter's own arguments. The fields:

| field | what it holds |
|---|---|
| `id` | `cpp-<stem>-NNNNN`, `<stem>` the test file's name without `_tests.cpp`, numbered in the order of the instrumented run |
| `family` | `cpp/<suite>/<case>`: the Boost suite and test case |
| `rule` | `cpp.<suite>.<case>` (§2 of `corpus/INDEX.md` carries the family's row; the replay maps each to the spec's rule when it runs) |
| `kind` | `evalscript` (an interpreter call on a given stack), `verifyscript` (a spend: the unlocking and locking scripts under a checker) or `predicate` (a standardness or script predicate the check asserts, below) |
| `source` | `pin`; `file` (`src/test/<file>.cpp`); `line`: the line of the test body the check is written on (the line of the outermost helper call, or the `EvalScript` call's own line when the body calls it directly); `case`; `call`: the 0-based index of this entry among the case's entries cited at that line; `row_line`: for a `test_data` table, the line its row starts (found by a brace count of the initializer in the pinned source, and the script stops if the row count differs from the calls recorded); `chain`: the lines from the body through each helper to the `EvalScript` call |
| `input` | `flags` (the word passed to `EvalScript`) and `flag_names` (`script_flags.h` at the pin); `params`: the four values of `eval_script_params` (`interpreter.h:136–166`): `max_ops`, `max_num_len`, `max_script_size`, `max_pubkeys_multisig`; `checker`: `base` (`BaseSignatureChecker`, `interpreter.h:52–75`: every signature check false, `Version()` 0), `tx` (a `TransactionSignatureChecker` or its `Mutable` form), or the class name of the checker the test passes, read from the object's type at the call (so a test's own checker is never written as `base`): `equality_checker` (`bn_op_tests.cpp:1015–1027`: a signature check is true exactly when the signature's bytes equal the key's, the lock-time and sequence checks always true), `DummySignatureChecker` (`script/sign.cpp:430–440`: every signature check true; the 21 `opcode_limit_tests` entries, which sitting 2 recorded as `base`, corrected in sitting 6), `versioned_sig_checker` (`script_tests.cpp:703–709`: every signature check false, `Version()` the row's), `always_true_sig_checker` (`script_tests.cpp:4766–4777`: every signature check true, `Version()` the row's), `InstrumentedChecker` (`script_tests.cpp:4195–4249`: the caching transaction checker, timing its calls; it signs over input 1 of a one-input transaction, `4214`, and the script it runs ends in `OP_1`, so its verdict does not depend on the signature); `tx_version`: the checker's `Version()`; for a checker derived from `TransactionSignatureChecker`, `tx` (the transaction it signs over, hex), `n_in` and `amount` (satoshis), read from its private fields as the stack limit is; for `evalscript`, `script`; `stack`: the stack before the call, bottom first; `stack_limit`: the byte limit of the `LimitedStack` the call ran on (`limitedstack.h:87`; a child stack is held to its parent's, `limitedstack.cpp:194-206`), recorded at every call, including the explicit `INT64_MAX` stacks (`lrshiftnum_tests.cpp:151, 203, 246, 399`; `opcode_tests.cpp:700, 726`); for `verifyscript`, `script_sig`, `script_pubkey`, and `params` with a fifth value, `max_stack_memory` (`verify_script_params`, `interpreter.h:176–194`); for `predicate`, the predicate's own arguments (a script, an era by its name in `ProtocolEra`, `protocol_era.h:28–34`, an amount, a script number, a width) |
| `expect["sv-node-unit@v1.2.2"]` | what the C++ check asserts, and only that; for a `predicate`, what the check asserts it returns (`returns`, and where asserted the template's `type`, the decoded `solutions_first_num` and `solutions_last_num`, the `script_after` of `FindAndDelete`; for a number, its `result`, `throws`, a length bound, or the comparisons asserted, keyed by the relation); where a check compares with the test's legacy model `CScriptNum10` (`scriptnum10.h`), the expected value is that model's and `note` says so; for a call: `verdict` (`ok`, `error`, or `unasserted`); `error` (the `ScriptError` name, `script_error.h` at the pin) when the check names it; `stack_size`; `stack` (every element, bottom first); `stack_top`; `top_len`; `bytes_at` (`[index, offset, byte]`: index below 0 is `stacktop(index)`, 0 and above counts from the bottom); `elems_at` (`[index, element]`: the element's exact bytes); `nums_at` (`[index, number]`: the element equals the number as a script number, little-endian magnitude with the sign in the top bit of the last byte, where the check compares values, `bint` or `bsv::deserialize`, and not bytes) |
| `observed["sv-node-unit@v1.2.2"]` | what the instrumented build returned `[X]`: `error` (the status as a name, `SCRIPT_ERR_OK` on success) and, where the check does not assert the whole stack, the whole final `stack` (where it does, the two are equal and the stack is written once, under `expect`). The shaper checks that every entry's observed result satisfies its `expect` and stops if one does not |
| `predicate`, `layer` | for a `predicate` entry: the predicate (`CScript::IsPushOnly`, `CScript::FindAndDelete`, `CScript::IsUnspendable`, `Solver`, `CTxOut::IsDust`, `IsDustReturnScript`, `IsStandardOutput` (policy: an output's standardness at a height under a network's configuration); `SignSignature`, both: it returns true only when `VerifyScript` accepts the input it signed, under the era's standard flags and the policy parameters (`script/sign.cpp:193–208`, `238–239`); `LimitedStack` at its limit, both: the byte limit is the parameter `maxStackMemoryUsage` (policy default 100 MB, `policy/policy.h:153`; consensus default `INT64_MAX`, `consensus/consensus.h:82`), each element charged its size and 32 (`script/limitedstack.h:43`), the throw past it returned as `SCRIPT_ERR_STACK_SIZE` (`interpreter.cpp:1815–1817`); `CScript::GetOp2`, `bsv::decode_instruction` and `bsv::instruction_iterator`, consensus, only on malformed bytes (the decoder's failure, which the interpreter returns as `SCRIPT_ERR_BAD_OPCODE`, `interpreter.cpp:450–451`); `SignatureHashOriginal and SignatureHash`, consensus: the digest a signature check without FORKID signs (`SignatureHashOriginal`, given in internal byte order) and whether `SignatureHash` gives the same; `SigHashType`, consensus: the hash-type byte's fields (`base_type` the value of `BaseSigHashType`, `script/sighashtype.h:31–36`: 0 unsupported, 1 ALL, 2 NONE, 3 SINGLE), whose `isDefined` decides `SCRIPT_ERR_SIG_HASHTYPE` under STRICTENC (`interpreter.cpp:291–294`), a mandatory flag in both eras (`script/standard.h:55–68`); the sigop counts, `CScript::GetSigOpCount` (and its P2SH form, from the unlocking script) and `GetTransactionSigOpCount`, both: before Genesis the count decides consensus (`bad-txn-sigops` in `CheckRegularTransaction`, `validation.cpp:560–566`, and in `ConnectBlock`, `3352–3367`, with `bad-blk-sigops`), and in the mempool it is compared with the policy limit `GetMaxTxSigOpsCountPolicy(era)` (`1236–1247`, `bad-txns-too-many-sigops`, non-standard); `CheckRegularTransaction`, consensus, called with the consensus limits as numbers; in the number layer, a `CScriptNum` construction or operator, or `bsv::MinimallyEncode`, consensus: the script-number arithmetic the interpreter runs, each number given as the script number a script would push, with its representation, `int64` or `bint`, and its width) and its layer, `policy`, `consensus` or `both`, from the inventory's row: `IsPushOnly` both (the consensus SIG_PUSHONLY check and the policy's `scriptsig-not-pushonly`), `FindAndDelete` consensus (the scriptCode of a signature check without FORKID), the other four policy, never consensus |
| `drawn_at_run_time` | where the entry's keys or signatures are drawn at run time (named by its hook; for `opcode_limit_tests`, whose hook does not name it, by the shaper where the script carries the key): some of its fields differ between runs |
| `masked` | on every `drawn_at_run_time` entry and on no other: the list of the entry's own fields a drawn key feeds (`input.script`, `input.script_sig`, `input.script_pubkey`, `input.tx`, `input.tx_from`, `input.tx_to`, `input.coin_tx`, `observed.stack`); the stable digest replaces exactly these fields and nothing else (below) |
| `source.loop_index`, `source.concurrent` | a call made in a loop with no table carries its loop index; a call made at once on several threads is marked `concurrent` and the group is written in call order |
| `replayable` | false when an element is recorded by its digest only (below) |
| `note` | when the check asserts nothing, why |

**Elements and scripts.** Hex up to 4,096 bytes. Above that, `{"len": n, "runs": [[byte, count], …]}` (the runs of equal bytes, at most 4,096 runs), which is exact. Above that, `{"len": n, "sha256": …}`, and the entry is `replayable: false`.

**How the expected verdict is taken from the C++ check.** Each `CPPX_EXPECT` in the patch transcribes the checks above it, site by site: `BOOST_CHECK_EQUAL(expected_error, r.value())` gives `error` and the verdict; `BOOST_CHECK(r.value() != SCRIPT_ERR_OK)` alone gives `verdict: error` with no name (`CheckTestForOpCodeLimit`, `opcode_tests.cpp:1221–1251`); `BOOST_CHECK(stack == expected)` gives `stack`; `stack.size()` and `stacktop(-1)` checks give `stack_size` and `stack_top`; a sampled byte check gives `bytes_at`. Where the check asserts nothing the verdict is `unasserted` and `note` says why: `CheckError` skips its checks for `SCRIPT_ERR_SCRIPTNUM_MINENCODE` under `SCRIPT_CHRONICLE` (`opcode_tests.cpp:129–135`). Where a check branches on its table's expectation (`bn_op_tests.cpp` `operands_too_large`, `op_num2bin`, `op_checkmultisig`) the hook takes the same branch on the same row value. Where a check branches on the observed status (`bn_op_tests.cpp:365–381`, `bint_bint_numequalverify`: on success it asserts only an empty stack, on failure `SCRIPT_ERR_NUMEQUALVERIFY` and the remaining number), the hook transcribes the branch taken, and `note` says so: the 2 success entries carry the verdict `unasserted` with `stack_size: 0`. A recorded call with no hook after it stops the shaper, so a site the patch missed cannot pass silently, and where a hook also names the stack limit the shaper checks it equals the recorded one. A failing Boost check stops the run before any entry is written.

**Predicates and the shared helper.** A predicate's hook is written on the line before the check it transcribes (after the call, where the check reads the call's outputs) and records the arguments and what the check asserts; its citation is the check's line, the next pinned line below the hook. The receipt is the evidence the reference returned what the check asserts. Most hooks transcribe the assertion without another call. Where `test_Get` asserts only that `AreInputsStandard` holds a value, its hook makes an additional call and records that returned value in `observed`, separately from the asserted `has_value` ([SRC] `src/test/transaction_tests.cpp:314-320`; §5). `script_tests.cpp`'s `DoTest` (`271–348`) is shared by the IN cases' builders and by the two COVERED cases (`script_build`, `script_json_test`, whose rows the vendored JSON already carries): the COVERED cases' calls are recorded and dropped by the shaper, and the manifest counts them (`covered_not_extracted`). A `TestBuilder` records the line it is constructed on, so a builder's entry cites its own row, not the loop that runs it.

**One process per suite.** The script runs each suite in its own `test_bitcoin` process, all appending to one dump, and the receipt counts every process. A suite can change the global configuration and leave it changed: `bn_op_tests.cpp` `operands_too_large` sets the policy's maximum script size and stack memory to 0 (unlimited) and its maximum number length to 750,000 (`393–395`) and does not restore them, so a suite run after it in the same process records other parameters (in sitting 6's first run, with all suites in one process, 32 of `lrshiftnum_tests.cpp`'s 36 entries recorded the maximum script size 4,294,967,295 where their own run records 500,000, 30 of them the maximum number length 750,000 for 10,000, and two of its large elements grew from 10,000 to 750,000 bytes `[X]`). With one process per suite each file is a function of its own suite. Inside a suite the order is the reference's, and the change carries: the `bn_op_tests` cases after `operands_too_large` that read the policy record its values, as numbers.

**A file kept, not rewritten.** When a run reproduces the key-masked digest of a file already in `corpus/cpp`, the file on disk is kept byte for byte and the manifest keeps its sha256; where the run drew other keys the manifest's `kept` says so. So a suite's commit carries only the files whose content changed.

**The receipt.** A run that passes writes `$WORK/receipt.json`: `status: passed`, the suites, Boost's own counts of test cases and assertions passed (read from its report, which must say every assertion passed), the sha256 of `instrument.patch`, of the `test_bitcoin` binary and of the dump. The shaper runs only after the receipt gate: it refuses unless the receipt exists, says passed with at least one assertion, names the same suites, and its three digests equal the patch in `corpus/cpp`, the binary in `$WORK/build` and the dump in `$WORK/raw.jsonl`. `--shape-only` (shape an earlier dump without rebuilding) passes the same gate, so no entry can be published from a dump without evidence its assertions passed under this patch and this build. The receipt also carries the seed, the run's date and, per suite, Boost's counts of that suite's own process and the records of the dump it wrote; from it the shaper writes one page per file, `corpus/cpp/receipts/<suite>.txt`, which is committed with the file (the scratch `receipt.json` is not).

**Consensus and policy.** The parameters an entry ran under are recorded as numbers, never as a default. The tests take them from `make_eval_script_params(policy, flags, consensus)` (`interpreter.cpp:2282–2292`): `bn_op_tests.cpp` passes `consensus = true` in `bint_binary_ops`, `bint_ternary_ops`, `bint_bint_numequalverify`, `op_depth`, `op_rshift_far` and `op_lshift_far` and `false` elsewhere, and its `op_checksig` and `op_checkmultisig` run with no flag at all, so their 17 entries carry the pre-Genesis policy values (500 operations, a 4-byte number, a 10,000-byte script, 20 keys); `script_tests.cpp` passes `consensus = true` in `DoTest` (`284`, every builder row), `script_PushData` (`2963`), the two CHECKMULTISIG cases (`3158`, `3238`), `script_standard_push` (`3643`) and `caching_invalid_signatures` (`4256`), and `false` (the policy values) in the `op_pushdata*` cases, the `mt_*` cases and every table case from `4708` on; `op_pushdata4_op_size` first raises the policy's maximum script size to 4,294,967,295 (`3075–3077`) and leaves it raised for the cases after it; `opcode_tests.cpp` passes `consensus = true` at its helpers and big-element cases (lines 47, 85, 120, 702, 722, 1228) and `false` (the policy values) at its table cases; `lrshiftnum_tests.cpp` passes `false` everywhere (113, 145, 198, 241, 361, 393) and two of its cases first raise the policy's `MaxScriptNumLength` to `MAX_SCRIPT_NUM_LENGTH_AFTER_CHRONICLE` (`195–197`, `238–240`); the six `op_*_len_invariant` cases of `opcode_tests.cpp` construct the parameters directly (e.g. `2389–2391`). The replay runs each entry under its recorded `params` and `flags`, and a policy value is never written as consensus.

**The fixed seed.** The script sets `TEST_BITCOIN_RANDOM_SEED` to the pin's commit, `879fc8b42168dd0e608dafd51b39c6dabad37d4d` (the script's `SEED`, written in the receipt as `random_seed`): the test framework reads it as the seed of its own random context (`test_bitcoin.cpp:49–61`) and resets the context from it for every fixture (`65–67`, `76`), so every draw through `InsecureRand*` is the same at every run, as the framework's own message says ("To re-run tests using the same seed, set the following environment variable"). The script enforces it from commit `e2b607f` on (the `sighash_tests` commit). At their own commits, three suites ran under it (`sighash_tests`, `multisig_tests`, `limitedstack_tests`) and eleven did not (`lrshiftnum_tests` and `opcode_tests` of sitting 2; `bn_op_tests`, `script_tests`, `scriptnum_tests`, `big_int_tests`, `int_serialization_tests`, `sigopcount_tests`, `cscript_tests`, `instruction_iterator_tests`, `sighashtype_tests` of sitting 6); the fix round's run of record ran all fourteen under it, and §5 gives what that run showed for each of the eleven. The limit, as it is: keys from `CKey::MakeNewKey` come from the strong generator, which no seed fixes; they stay drawn at run time.

**Run-time randomness.** `opcode_limit_tests` builds its CHECKMULTISIG scripts with three keys from `CKey::MakeNewKey` (`opcode_tests.cpp:1264–1277`), fresh at every run. In `multisig_tests.cpp` keys are drawn at `54–56`, `217–218`, `280–284` and `394–397` (every entry of the file); in `sigopcount_tests.cpp` keys are drawn at `101`, `120` and `261`; in `script_tests.cpp` keys are drawn at `1662` (two builders carry the key), `3143–3145`, `3211–3214` and `4273` (200 keys each iteration); those entries are marked `drawn_at_run_time`. Their keyed fields differ between runs and their verdicts do not (in `opcode_limit_tests` the checker is a dummy, `opcode_tests.cpp:1281–1282`).

**The mask.** The manifest gives each file's sha256 and a second digest, `sha256_keys_masked`: the sha256 of the JSONL in which, for each entry that carries a `masked` list, exactly the fields the list names are replaced by the string `drawn`. An entry without the list is hashed as it is written, so a file with no drawn entry has one digest, and the digest can be recomputed from the committed file alone (`--verify` does). Only a `drawn_at_run_time` entry is masked, and in it only the fields a key from `MakeNewKey` feeds: a transaction (it carries the keyed script or a signature, or spends an outpoint whose id commits to one); a script that holds a push of 20 bytes or more (a key, a signature, or the hash of a keyed script) or is recorded by its digest only; a stack that holds an element of 20 bytes or more (a failed call leaves its keys on the stack). A script of small pushes and opcodes (`00`, `0051`) is left as it is. Two fields hold such a push and are not fed, and the script names them: the locking script of `chronicle_scriptsig_checksig`'s two builders, the file's fixed key (`script_tests.cpp:1667`; the drawn key, `1662`, is in their unlocking script), and the unlocking script of the call at `sigopcount_tests.cpp:363`, a signature written in the source (`338`, `346`). Nothing else is masked: there is no pattern applied across a file (§5, the fix round, gives the mask it replaces and every digest that moved).

## 4. The instrumentation (`corpus/cpp/instrument.patch`)

The patch touches 24 files of the copy and nothing else; the pinned tree and the 2026-09-22 build directory are never modified.

| file | hunk | why |
|---|---|---|
| `src/test/cpp_extract.h` (new) | the recorder: `cppx::eval` (records the flags, the four parameters, the checker, the script, the stack before the call and its byte limit, then the status and the stack after it; the limit is a private member, read through an explicit template instantiation, where access checking does not apply, so no pinned header is touched), `cppx::expect`, `cppx::Frame` (the line of the caller of each helper, through a defaulted `std::source_location` argument), and, from sitting 6, `cppx::verify` (a `VerifyScript` call: the scripts, the five parameters, the checker and its transaction), `cppx::predicate` (an asserted predicate), the expectation fields `elems_at`, `nums_at`, `drawn`, `loop` and `concurrent`, the checker's class name read from its type, and one lock for the output file with the pending call per thread (two cases call on 8 threads at once); the macros `EvalScript`, `VerifyScript`, `CPPX_LOC`, `CPPX_FRAME`, `CPPX_EXPECT`, `CPPX_PREDICATE` | the reader |
| `src/test/bn_op_tests.cpp` | the include; a `CPPX_EXPECT` after the checks of each of the 18 cases (two branches where the check branches) (sitting 6) | the expectations |
| `src/test/crypto_tests.cpp` | the include; `CPPX_LOC` and `CPPX_FRAME` on `TestRIPEMD160`, `TestSHA1` and `TestSHA256`; a `CPPX_PREDICATE` before each helper's `TestVector` call, recording the message and asserted digest ([SRC] `crypto_tests.cpp:60-75` at `879fc8b`) | the citations and expectations of the 3 IN digest cases |
| `src/test/script_tests.cpp` | the include; the `TestBuilder`'s construction line (a member and a defaulted argument) and a frame in its `Test()`; one `CPPX_EXPECT` in `DoTest`; a hook at each check of the 38 IN cases (`CPPX_EXPECT` after a call's checks, `CPPX_PREDICATE` before a predicate's check); the registration of the key drawn at `1662`; `CPPX_LOC` and `CPPX_FRAME` on `CheckSolver` (sitting 6, generated from the pin by a map keyed by pin line) | the citations and the expectations |
| `src/test/big_int_tests.cpp` | the include; a `CPPX_PREDICATE` before each check, or group of checks on one input, of the 17 IN cases (sitting 6, generated from the pin by a map keyed by pin line) | the expectations |
| `src/test/int_serialization_tests.cpp` | the include; a `CPPX_PREDICATE` before the checks of each row of the 4 IN cases (sitting 6, generated from the pin by a map keyed by pin line) | the expectations |
| `src/test/sigopcount_tests.cpp` | the include; a `CPPX_PREDICATE` before each sigop-count check and each `CheckRegularTransaction` check of the 4 IN cases; `CPPX_LOC` and `CPPX_FRAME` on `VerifyWithFlag` and `TestMaxSigOps`; a `CPPX_EXPECT` after each caller's assertion on `VerifyWithFlag`'s verdict (sitting 6, generated from the pin by a map keyed by pin line) | the citations and the expectations |
| `src/test/cscript_tests.cpp` | the include; a `CPPX_PREDICATE` before the checks of each failure row of `GetOp2` on malformed bytes and of each row of the two sigop-count tables (sitting 6) | the expectations |
| `src/test/instruction_iterator_tests.cpp` | the include; a `CPPX_PREDICATE` before the checks of each failure row of `decode_instruction` on malformed bytes and of the two truncated-push cases (sitting 6) | the expectations |
| `src/test/sighash_tests.cpp` | the include; a `CPPX_PREDICATE` before the checks of each of the 1,000 draws (sitting 6) | the expectations |
| `src/test/sighashtype_tests.cpp` | the include; `CPPX_LOC` and `CPPX_FRAME` on `CheckSigHashType` and a `CPPX_PREDICATE` before its checks; a `CPPX_PREDICATE` before the raw-value check (sitting 6) | the citations and the expectations |
| `src/test/multisig_tests.cpp` | the include; a `CPPX_EXPECT` after the checks of each `VerifyScript` call; a `CPPX_PREDICATE` before each `IsStandardOutput`, `Solver` and `SignSignature` check of the IN cases; braces around the one-line loop at `263–264` so its hook sits inside the loop (sitting 6) | the expectations |
| `src/test/limitedstack_tests.cpp` | the include; a `CPPX_PREDICATE` before the checks of each of the 2 IN cases (sitting 6) | the expectations |
| `src/test/scriptnum_tests.cpp` | the include; a `CPPX_PREDICATE` before the checks of each row or helper call of the 20 IN cases; `CPPX_LOC` and `CPPX_FRAME` on the eight helpers of `creation` and `operators` and on `CheckMinimalyEncode`, which also keeps its input before `MinimallyEncode` changes it; braces around `CheckNegate`'s guarded check so the hook sits under the guard (sitting 6, generated from the pin by a map keyed by pin line) | the citations and the expectations |
| `src/test/lrshiftnum_tests.cpp` | the include; one `CPPX_EXPECT` after the checks of each of the 6 cases | the expectations |
| `src/test/opcode_tests.cpp` | the include; `CPPX_LOC` and `CPPX_FRAME` on the 20 helpers that lead to an `EvalScript` call (`CheckStackSize` through `CheckTestForOpCodeLimit`); a `CPPX_EXPECT` after the checks of every call site; fifteen `CPPX_PREDICATE` hooks on `negative_valtype_test` (sitting 7) | the citations and the expectations |
| `src/test/transaction_tests.cpp` | the include and the hooks of the IN cases, keyed by pin line (sitting 7); §5 gives the assertion limits and the excluded checks | the citations and the expectations |
| `src/test/script_P2SH_tests.cpp` | the include and the hooks of the IN cases, keyed by pin line (sitting 7); §5 gives the assertion limits and the excluded checks | the citations and the expectations |
| `src/test/test_txnvalidator.cpp` | the include and the hooks of the IN cases, keyed by pin line (sitting 7); §5 gives the assertion limits and the excluded checks | the citations and the expectations |
| `src/test/txvalidationcache_tests.cpp` | the include and the hooks of the IN cases, keyed by pin line (sitting 7); §5 gives the assertion limits and the excluded checks | the citations and the expectations |
| `src/test/blockcheck_tests.cpp` | the include and the hooks of the IN cases, keyed by pin line (sitting 7); §5 gives the assertion limits and the excluded checks | the citations and the expectations |
| `src/test/miner_tests.cpp` | the include and the hooks of the IN cases, keyed by pin line (sitting 7); §5 gives the assertion limits and the excluded checks | the citations and the expectations |
| `src/test/rpc_tests.cpp` | the include and the hooks of the IN cases, keyed by pin line (sitting 7); §5 gives the assertion limits and the excluded checks | the citations and the expectations |
| `src/test/webhook_client_tests.cpp` | `boost::asio::io_service` to `boost::asio::io_context` (lines 72 and 127) | build compatibility only: Boost 1.92 removed the `io_service` alias, so the pinned test file does not compile against it; the file decides no verdict and is not run by the reader |

The build follows the reference build of 2026-09-22 (its `CMakeCache.txt`: Release, `USE_HARDENING=OFF`, wallet, ZMQ, bench, miner and UPnP off, `CMAKE_CXX_FLAGS=-Wno-error=cast-align -Wno-unknown-warning-option`), with `CMAKE_POLICY_VERSION_MINIMUM=3.5` for cmake 4.2.3 against leveldb's bundled crc32c. On the Studio: AppleClang 17.0.0, Boost 1.92.0 and OpenSSL 3.6.2 from Homebrew, 4 jobs `[M]`. The copy starts from `~/bsv/targets/sv-v1.2.2-src`, the export the oracle's node was built from, which differs from `git archive` of the commit in four files outside `src/test` and `src/script` (`clientversion.cpp`, the archive's version strings filled in; `compat/glibc_sanity.cpp`, `net/fixed_len_multi_parser.cpp`, `net/tx_parser.cpp`, Darwin build fixes) `[M]`; the files the script checks (its list `PINNED`: the extracted test files, `webhook_client_tests.cpp`, and the interpreter, error, flag and stack sources the recorder calls) are byte-identical to the commit.

## 5. The run `[X]`

Sitting 2, on the Studio, 2026-10-05, from the branch `lane/harness-49` with `instrument.patch` `7f215f0427638676d1800ef6c084cd58d0832fcec73bec79bc4af553aa7c9a75`: `tools/cpp_extract.sh` rebuilt `test_bitcoin` at 4 jobs and ran `--run_test=lrshiftnum_tests,opcode_tests`: 44 test cases, 433,392 assertions, all passed, and wrote its receipt. The table follows the current [shift receipt](receipts/lrshiftnum_tests.txt), [opcode receipt](receipts/opcode_tests.txt) and manifest, including sitting 7's 15 `negative_valtype_test` predicates:

| file | entries | `ok` | `error` | `unasserted` | `predicate` | rows cited by table line | sha256 of the JSONL | `sha256_keys_masked` |
|---|---|---|---|---|---|---|---|---|
| `lrshiftnum_tests.jsonl` | 36 | 27 | 9 | 0 | 0 | 2 tables | `27e34949c6c2348f674ba1600f79720834c6d25dbfe7897e31b3d6b79a158075` | the same |
| `opcode_tests.jsonl.gz` | 144,381 | 132,829 | 11,457 | 80 | 15 | 16 tables | `88652c71c6f6d3ff85304edc89b3bce4f9911a2e775923bdc9795332bebd2a1e` | `6437c6eeb1e1b9973854da09bda592428daab47d35695e86378b338fdfad7b22` |

Across the two files above, the current receipts cover 144,417 entries: 144,402 `evalscript` calls and 15 predicates. Every `evalscript` entry carries `input.stack_limit`: 4,294,967,295 on 144,384 entries, 9,223,372,036,854,775,807 (`INT64_MAX`) on 6 (`lrshiftnum_tests.cpp` 4, `opcode_tests.cpp` 2), and the eight small limits of `limited_stack_test` on its 12. These two files have zero `replayable: false` entries; the full family has 63, namely 60 digest-only `caching_invalid_signatures` entries and 3 digest-only crypto messages. The 80 `unasserted` entries are `CheckError`'s skipped MINENCODE checks under `SCRIPT_CHRONICLE` (§3).

**The receipt gate, shown.** With the build and the dump in place, `WORK=<a scratch directory> tools/cpp_extract.sh --shape-only` refused, exit 1, in four cases: no receipt ("REFUSED to shape: no receipt at …"); a receipt saying `failed` ("the receipt does not record a passed run with assertions"); a receipt naming sitting 1's patch `e37a35cf…` ("the receipt's patch sha256 is not corpus/cpp/instrument.patch's"); a dump cut to its first 1,000 bytes ("the receipt's dump sha256 is not raw.jsonl's"). With the run's own receipt, `--shape-only` was accepted and rewrote `manifest.json` byte for byte.

**Two full runs.** The script ran end to end twice in this sitting with this patch. Their `sha256_keys_masked` agree for both files (`lrshiftnum_tests` `27e34949…`, `opcode_tests` `4fd81774…`); the plain sha256 of `opcode_tests` differs between them (`c9071eab…`, then `12d3db39…`) because of the nine `opcode_limit_tests` entries whose keys are drawn at run time (§3). The committed files and the table above are the second run's.

`tools/mechanism_check.sh` over both files (the gzipped one decompressed to a scratch directory): 7,015 distinct hex strings against the three sibling trees (2,007 degenerate runs of one or two byte values excluded), **0 hits, CLEAN** `[X]`.

**Sitting 6, suite by suite** (branch `lane/harness-49-s6`, the Studio, 4 jobs). Each suite was instrumented, built, run and shaped together with every suite before it, so the newest receipt covers every file in `corpus/cpp`; `mechanism_check.sh` ran over each new or changed file. The table gives each suite as it stood at its own commit; a suite's name links its receipt, and the digests of record are those of the fix round's table below.

| suite | patch sha256 (first 8) | receipt: processes, cases, assertions | entries | calls `ok` / `error` / `unasserted`; predicates | rows cited by table line | sha256 of the JSONL; key-masked | mechanism check |
|---|---|---|---|---|---|---|---|
| [`bn_op_tests`](receipts/bn_op_tests.txt) | `965618d8` | 3, 62, 434,355 | 249 | 192 / 55 / 2; 0 | 16 tables | `2771c4b50afc9cbafe899f72d85778f93f5bdf9f259f9aad8db2c95428f5dc1f`; the same | 56 hex strings, 0 hits, CLEAN `[X]` |
| [`script_tests`](receipts/script_tests.txt) | `6c669a6e` | 4, 106, 641,899 | 135,669 (299 `evalscript`, 67,795 `verifyscript`, 67,575 `predicate`) | 67,898 / 196 / 0; 67,575 | 15 tables; 143 builder rows by their construction line | `782937a388fffc22d238a5e6cae530b0972d814245991ad449f1b69d2f568718`; `72d562fe0b136ed85e4a8f589e8ae10d2c292678aef4b3f7d1d6e23aa722445a` | 825 hex strings, 0 hits, CLEAN `[X]` |
| [`scriptnum_tests`](receipts/scriptnum_tests.txt) | `8151ca23` | 5, 133, 690,205 | 11,017 (all `predicate`) | none; 11,017 | none (the rows are cited by their check, and a helper's by its caller) | `b42c202ab68494832d74f77d19e32a9236425365297221c6b95984398fbd93bc`; the same | 501 hex strings, 0 hits, CLEAN `[X]` |
| [`big_int_tests`](receipts/big_int_tests.txt) | `6340f53e` | 6, 167, 690,380 | 46 (all `predicate`) | none; 46 | none | `6381b5480ac0b97b6f057202ed381bb2f3d1a878b456e23054c2d5edbed2612d`; the same | no hex string of 40 characters or more (its numbers are decimal), CLEAN `[X]` |
| [`int_serialization_tests`](receipts/int_serialization_tests.txt) | `0c0e8813` | 7, 172, 690,637 | 129 (all `predicate`) | none; 129 | none | `a53cf4678e2dd27b2e59cf4b585c4d0d22318ed8faf27eec6b54f8acdc35f58f`; the same | no hex string of 40 characters or more, CLEAN `[X]` |
| [`sigopcount_tests`](receipts/sigopcount_tests.txt) | `9797ddff` | 8, 177, 690,758 | 61 (6 `verifyscript`, 55 `predicate`) | 0 / 6 / 0; 55 | none (each check cited by its line, a helper's by its caller) | `06a0a145caa62c7b657d670c977d7a0dc67ac53168a16d784b0cc1f32b0c7e84`; `59d206c20046a20fc13f8e73fca0f605a98b2b48e325370020ed329425eb5478` | 32 hex strings, 0 hits, CLEAN `[X]` |
| [`cscript_tests`](receipts/cscript_tests.txt) | `a7931925` | 9, 181, 690,954 | 67 (all `predicate`) | none; 67 | none | `b8b3ca9eabf9d768288b74bd27ac7c64dac406674906e707f77859071b487c75`; the same | 12 hex strings, 0 hits, CLEAN `[X]` |
| [`instruction_iterator_tests`](receipts/instruction_iterator_tests.txt) | `bb3a0232` | 10, 185, 691,210 | 21 (all `predicate`) | none; 21 | none | `e0bc7f9f26a8fad7a082f722f765e04207982a7b17d7ea993d7566a1335c47b9`; the same | no hex string of 40 characters or more, CLEAN `[X]` |
| [`sighashtype_tests`](receipts/sighashtype_tests.txt) | `4b31f360` | 11, 187, 716,816 | 5,121 (all `predicate`) | none; 5,121 | none | `341325861023424b4a62d28dec70ac34bbfbf97f4a177a500db5976e14693317`; the same | no hex string of 40 characters or more, CLEAN `[X]` |
| [`sighash_tests`](receipts/sighash_tests.txt) | `89c16381` | 12, 189, 723,816 (the seed fixed) | 1,000 (all `predicate`) | none; 1,000 | none | `126c9e8d2c5ec54381f847cd6078a9676fe2a4d91b327d3475d6764343db4bec`; `2f9768a802d994f98f71b90605b00b51a14af84d5e5fdec8757b55a86766d743` | 2,000 hex strings, 0 hits, CLEAN `[X]` |
| [`multisig_tests`](receipts/multisig_tests.txt) | `f007df2a` | 13, 193, 724,019 | 56 (30 `verifyscript`, 26 `predicate`) | 6 / 24 / 0; 26 | none (each call cited by its line, with its loop index) | `37337d7a8fa293600b614f7e8e66c464abf4347ae1ef63df980b6cdfd1f5c1e5`; `c3e47de5f847fd353833c90ac21bfa04d8ad7c89dc1ee13c1ea26ebfac587835` | 57 hex strings, 0 hits, CLEAN `[X]` |
| [`limitedstack_tests`](receipts/limitedstack_tests.txt) | `fb1caaba` | 14, 206, 724,109 | 2 (both `predicate`) | none; 2 | none | `f3890b5bc2965ee060b7dad022429d0a9f3de6a502ea4947ec2e3e985e1e7325`; the same | no hex string of 40 characters or more, CLEAN `[X]` |

`script_tests`: all 38 IN cases have entries (the builder cases checked row for row: every `TestBuilder(` line of the six builder cases has exactly one entry); the two COVERED cases' 100 + 1,483 calls through `DoTest` were dropped and counted; 75 entries are `drawn_at_run_time` (`script_CHECKMULTISIG12` 4, `script_CHECKMULTISIG23` 9, `caching_invalid_signatures` 60, two builders of `chronicle_scriptsig_checksig`); 60 entries are `replayable: false`, those of `caching_invalid_signatures`, whose locking script holds 200 drawn keys (13,206 bytes in more than 4,096 runs, so recorded by its length and digest, §3). The run includes the case's two timing assertions (`script_tests.cpp:4205–4206`, `4336`), which passed; they are the reference's own checks and decide no entry. The first two runs of this suite gave two key-masked digests: the 8-thread cases (`mt_2_plus_2`, `mt_p2pkh`) wrote their entries in the order they finished; the shaper now writes each such group in call order, and the next two full runs gave `72d562fe` both times `[X]`.

`limitedstack_tests`: both IN cases have one entry each, the sequence of pushes or inserts at the limit of 100 bytes with the sizes the checks assert and the throw; the same digest in two runs.

`multisig_tests`: all 4 IN cases have entries, all 56 drawn at run time and masked; two runs gave the same key-masked digest (after the mask learned the `SignSignature` entries' `tx_from` and `tx_to`). Not extracted, by its reason: `multisig_Solver1`'s `ExtractDestination`, `ExtractDestinations` and `IsMine` checks (`296–300`, `312–316`, `324–331`, `344–348`, `363–372`): an address derived from a script and the wallet's ownership, no verdict; its `Solver` checks are the entries. `SignSignature`'s entries carry the transaction before the signing, not the signed input: its keys are the run's.

`sighash_tests`: its IN case has 1,000 entries, one per draw: the transaction, the script code, the input and the hash type, the original digest, and whether `SignatureHash` with amount 0 equals it (721 yes, 279 no). Under the fixed seed two runs gave the same file, `126c9e8d`; no entry is drawn and none is masked, so its key-masked digest is the file's own (at this suite's commit the mask of that time, a pattern over the whole file, changed seven of its entries and gave `2f9768a8`; the fix round below removed that mask). An independent check `[X]`: a transcription in Python of the test's legacy algorithm (`28–89`) gives the same `original_digest` on all 1,000. With the seed fixed, `sigopcount_tests`' six `TestMaxSigOps` entries are no longer drawn (their prevout comes from `InsecureRand256`, `416`, under the seed): the file is now `d35f8397af30994613d24ba7ceefabb5721dd7fac70fb79432d616663ebc4460`, key-masked `50f649106dc630e699c25f7d268728e9c932cfdc170d6c211946edd0869796de`, 22 entries drawn (the keys of `101`, `120`, `261`).

**`crypto_tests`, extracted.** The owner's ruling C1 and follow-up word of 2026-10-06 authorize a named, cited allowlist of public standard example vectors, including the 448-bit SHA-256 example and any further published standard vectors, with the mechanism gate strict for every unlisted value. The 3 IN cases (RIPEMD-160, SHA-1 and SHA-256, the digests `OP_RIPEMD160`, `OP_SHA1` and `OP_SHA256` push, [SRC] `interpreter.cpp:1402-1443` at `879fc8b`) were patched, built at 4 jobs, run in their own process under `TEST_BITCOIN_RANDOM_SEED=879fc8b42168dd0e608dafd51b39c6dabad37d4d`, and shaped: 11 test cases and 74,933 assertions passed, 31 entries (10 RIPEMD-160, 10 SHA-1, 11 SHA-256), digest `90698fb36a19c361694e547adcb1244b8c57f753c1b5a17c237e0d2517609365`, the same key-masked digest with 0 masked entries, recorded in [`receipts/crypto_tests.txt`](receipts/crypto_tests.txt). Python `hashlib` agrees with all 28 replayable digests (9 RIPEMD-160, 9 SHA-1, 10 SHA-256); 3 entries record the 1,000,000-byte `LongTestString` ([SRC] `crypto_tests.cpp:258-272`) by length and SHA-256 only and cannot be replayed from the file alone. The gate skips exactly 4 constants by name: `SHA-256(448-bit FIPS example)`, `SHA-256(abc)`, `SHA-256(million a)` and `SHA-256(empty)`. The 448-bit digest is the NIST SHA-256 Two Block Message Sample, pp. 3-6, and [SRC] `crypto_tests.cpp:329-331`; the further hit was SHA-256 of one million `a` bytes, published in RFC 6234 section 8.5, SHA256 test 3, and [SRC] `crypto_tests.cpp:342-344`, allowed by the follow-up word (each public citation is in `tools/mechanism_allow.txt`, all reference lines at `879fc8b`). All 35 remaining crypto hex strings and every file of the 15-file family, including both decompressed files, have 0 hits, CLEAN `[X]`. The original gate and the updated gate are CLEAN on the 14 existing files with identical checked-pattern and degenerate counts, and the final gate skips 0 values in those files. Synthetic controls confirm that an unrelated digest, a one-character variation of either added digest and a longer value containing either added digest each remain a hit `[X]`. The extraction's preserved run (`2026-10-06T02:08:05Z`, 15 independent suite processes, 217 cases and 799,042 assertions passed) refreshed the 14 existing receipts for the new patch while keeping their corpus files byte for byte; the 4 files whose keys changed reproduced their key-masked digests.

`sighashtype_tests`: both IN cases have entries (`sighash_construction_test` 2,561 calls of `CheckSigHashType`; `sighash_serialization_test` 1,280 calls and 1,280 raw-value and serialization checks). Not extracted, by its reason: the file's `static_assert`s (`13–65`), checked by the compiler, not by the run; the build that ran is their evidence. The same digest in two runs.

`instruction_iterator_tests`: all 3 IN cases have entries (`decode_instruction_tests` 19 failure rows, one entry for each truncated-push case). Not extracted, by its reason: `decode_instruction_tests`' well-formed rows (decoding of well-formed bytes, no verdict) and its empty-script row (`23`, the decoder at the script's end, `interpreter.cpp:441`); the same digest in two runs.

`cscript_tests`: all 3 IN cases have entries (`GetOp2` 14, `GetSigOpCount` 37, `GetSigOpCount_p2sh` 16). Not extracted, by its reason: `GetOp2`'s 11 well-formed rows (`24–38`, decoding of well-formed bytes, no verdict: §2's criterion) and its empty-script row (`40`: the decoder at the script's end, which the interpreter never calls, `interpreter.cpp:441`); the same digest in two runs.

`sigopcount_tests`: all 4 IN cases have entries; 28 are `drawn_at_run_time`, and two runs gave the same key-masked digest. Not extracted, by its reason: in `test_max_sigops_per_tx` only the call of `TestMaxSigOps` with the consensus limits (`455`) decides a transaction; its other checks (`453–454`, `458–490`) read and set the configuration's sigop limits and assert the getters' and setters' returns and messages, no verdict on a transaction. `VerifyWithFlag` asserts inside itself only that the verdict is not `SCRIPT_ERR_OK` (`218`); each caller asserts the exact error, and the entry carries the caller's.

`int_serialization_tests`: all 4 IN cases have entries, one per row (`serialize_int64_t` 33, `serialize_bint` 72, `is_minimal_encoding` 12, `minimally_encode` 12), each with the encoding the check asserts and, for the serializers, the round trip; the same digest in two runs.

`big_int_tests`: all 17 IN cases have entries, one per check or group of checks on one input; numbers in decimal, and the two operands of 32,000,000 bytes (`392–402`, `434–444`) by their serialization. Two runs gave the same digest.

`scriptnum_tests`: all 20 IN cases have entries, one per row or helper call, each grouping the checks made on one input (`creation` 630, `operators` 7,020, `minimize_encoding_test` 3,121). Not extracted, by its reason: `RunCreate`'s `BOOST_CHECK_THROW(CheckCreateVch(num), scriptnum10_error)` (`986`) asserts that the test's own legacy model (`scriptnum10.h`) refuses a number above 4 bytes, which no reference code decides; on those 72 calls `CheckCreateVch` stops at its model's throw (`866`), so its check at `862` is not recorded there (the same check is recorded through `CheckCreateInt`, `880`). Two runs gave the same digest (no key is drawn).

**What the second suite's recorder changed in earlier files.** The checker is now named from its type at the call (§3). `bn_op_tests`: its 17 `equality` entries are now `equality_checker`, so the file's sha256 moved from `2771c4b5` to `72485e5624404d32651137cf24d824f0e13bfea3500e08bb52aa058da5458a4b` (nothing else changed). `opcode_tests`: **a correction of sitting 2**: its 21 `opcode_limit_tests` entries recorded the checker as `base` (every signature check false) where the test passes `DummySignatureChecker` (every signature check true, `script/sign.cpp:430–440`, through `DummySignatureCreator`, `opcode_tests.cpp:1281–1282`); a replay under `base` would have decided their signature checks wrongly. The 51 entries with a transaction checker now also carry its transaction, input and amount. Its sha256 is now `590e41ab513dc48b5c498e291acf07cdf5ece60ac593e9654da938b43343e053`, key-masked `b0a99cc7e9bd323966e84209c686ad15f8d8254b11cda8f466d95328c64c79c1` (the gz as written `350315165132a10db8ff3402707fad212507603d89c15eb88651dd8a7b3b421f`); the structural diff against the committed file shows those two changes and the run-time keys only `[X]`. `lrshiftnum_tests` is unchanged.

**The fix round** (lane `harness-49-fix5`, on this branch, the Studio, 4 jobs, 2026-10-06; it answers a lens whose verdict on sitting 6 was NOT HELD). No entry's verdict, citation or expectation changed; the instrumentation is the same (`instrument.patch` `fb1caabab1920a7fa33b1d8a1c24d9a66f7df9286945ed73b103e1faf2de0710`, the binary `83fe9a197d04c41a54c30ef4ec59562f1ef986799fcc98caea373cf56e0db381`).

*The receipts.* Sitting 6 committed no receipt: its table above carries the cumulative counts of each run, and the run's `receipt.json` stayed in the scratch directory, where each run overwrote the last, so none of its twelve per-suite receipts exists any more. The script now writes one receipt per file, `corpus/cpp/receipts/<suite>.txt` (§3), and the fourteen committed are those of one run, the run of record: `2026-10-06T01:19:19Z`, all fourteen suites, each in its own process under the seed `879fc8b42168dd0e608dafd51b39c6dabad37d4d`, 206 test cases and 724,109 assertions, all passed, the dump `0b1599a8bd6e67b770e874297e9a3dcb5d69789e7ba35a74c1b715002047f68c` `[X]`. The cumulative counts are the same as sitting 6's last receipt (14 processes, 206, 724,109).

| file and its receipt | Boost suite: its test cases, its assertions (all passed) | cases with entries | entries | entries masked | sha256 of the JSONL | key-masked | under the seed at its own commit |
|---|---|---|---|---|---|---|---|
| [`big_int_tests`](receipts/big_int_tests.txt) | `bint_tests`: 34, 175 | 17 | 46 | 0 | `6381b5480ac0b97b6f057202ed381bb2f3d1a878b456e23054c2d5edbed2612d` | the same | no |
| [`bn_op_tests`](receipts/bn_op_tests.txt) | `bn_op_tests`: 18, 963 | 18 | 249 | 0 | `72485e5624404d32651137cf24d824f0e13bfea3500e08bb52aa058da5458a4b` | the same | no |
| [`cscript_tests`](receipts/cscript_tests.txt) | `cscript_tests`: 4, 196 | 3 | 67 | 0 | `b8b3ca9eabf9d768288b74bd27ac7c64dac406674906e707f77859071b487c75` | the same | no |
| [`instruction_iterator_tests`](receipts/instruction_iterator_tests.txt) | `instruction_iterator_tests`: 4, 256 | 3 | 21 | 0 | `e0bc7f9f26a8fad7a082f722f765e04207982a7b17d7ea993d7566a1335c47b9` | the same | no |
| [`int_serialization_tests`](receipts/int_serialization_tests.txt) | `int_serialization_tests`: 5, 257 | 4 | 129 | 0 | `a53cf4678e2dd27b2e59cf4b585c4d0d22318ed8faf27eec6b54f8acdc35f58f` | the same | no |
| [`limitedstack_tests`](receipts/limitedstack_tests.txt) | `limited_stack_vector_tests`: 13, 90 | 2 | 2 | 0 | `f3890b5bc2965ee060b7dad022429d0a9f3de6a502ea4947ec2e3e985e1e7325` | the same | yes |
| [`lrshiftnum_tests`](receipts/lrshiftnum_tests.txt) | `lrshiftnum_tests`: 6, 158 | 6 | 36 | 0 | `27e34949c6c2348f674ba1600f79720834c6d25dbfe7897e31b3d6b79a158075` | the same | no |
| [`multisig_tests`](receipts/multisig_tests.txt) | `multisig_tests`: 4, 203 | 4 | 56 | 56 | `03b82afe6e38da5ff9e5934be13f2e9702518707b12cdb66f87018d264d4e90f` (was `37337d7a8fa293600b614f7e8e66c464abf4347ae1ef63df980b6cdfd1f5c1e5`) | `7c22d7bb1e4b77ae14bd3688772e0f77c1de6670fa730dd21a4c0b4d75f7e31f` (was `c3e47de5f847fd353833c90ac21bfa04d8ad7c89dc1ee13c1ea26ebfac587835`) | yes |
| [`opcode_tests`](receipts/opcode_tests.txt) | `opcode_tests`: 38, 433,234 | 36 | 144,366 | 9 | `ec8b1a1c674bb06384c764be54645fb56973d0bc5ec3947f6812015a15ac0a62` (was `590e41ab513dc48b5c498e291acf07cdf5ece60ac593e9654da938b43343e053`) | `c4a241d5e7cc55830c76d9642f4a38b8502d54ac725db92f329a71906ae53601` (was `b0a99cc7e9bd323966e84209c686ad15f8d8254b11cda8f466d95328c64c79c1`) | no |
| [`script_tests`](receipts/script_tests.txt) | `script_tests`: 44, 207,544 | 38 | 135,669 | 75 | `1992f9dea52a9de7fe9d268563b678fc9406e6b9665afef1b941f1ecf62cf213` (was `782937a388fffc22d238a5e6cae530b0972d814245991ad449f1b69d2f568718`) | `2fd8807ce1d4a2e4e4485629ec6b15225e1045aa7e369c2a091f4a1571055057` (was `72d562fe0b136ed85e4a8f589e8ae10d2c292678aef4b3f7d1d6e23aa722445a`) | no |
| [`scriptnum_tests`](receipts/scriptnum_tests.txt) | `scriptnum_tests`: 27, 48,306 | 20 | 11,017 | 0 | `b42c202ab68494832d74f77d19e32a9236425365297221c6b95984398fbd93bc` | the same | no |
| [`sighash_tests`](receipts/sighash_tests.txt) | `sighash_tests`: 2, 7,000 | 1 | 1,000 | 0 | `126c9e8d2c5ec54381f847cd6078a9676fe2a4d91b327d3475d6764343db4bec` | the same (was `2f9768a802d994f98f71b90605b00b51a14af84d5e5fdec8757b55a86766d743`) | yes |
| [`sighashtype_tests`](receipts/sighashtype_tests.txt) | `sighashtype_tests`: 2, 25,606 | 2 | 5,121 | 0 | `341325861023424b4a62d28dec70ac34bbfbf97f4a177a500db5976e14693317` | the same | no |
| [`sigopcount_tests`](receipts/sigopcount_tests.txt) | `sigopcount_tests`: 5, 121 | 4 | 61 | 22 | `da0a3c85150506d722e9929c3373a5384c5fd0837120d045197ee21eb26fa59c` (was `d35f8397af30994613d24ba7ceefabb5721dd7fac70fb79432d616663ebc4460`) | `4d9b437ad9d465c23f2df9afb3b6f4ea6d9aedff62deb33fefd2defb503cac74` (was `50f649106dc630e699c25f7d268728e9c932cfdc170d6c211946edd0869796de`) | no |

A suite's process runs every case of its Boost suite, the OUT ones too, so its test cases can exceed its cases with entries (`limited_stack_vector_tests` 13 for 2; `bint_tests` 34 for 17; `script_tests` 44 for 38).

*The mask.* The mask of sitting 6 replaced, in every `drawn_at_run_time` entry, its scripts, transactions and stacks whole, whether or not a key fed them, and then zeroed, across the whole file, every string shaped like a compressed key (a 33-byte push opening `02` or `03`, or a quoted 33-byte element). The second step reached entries that carry no mark: seven of `sighash_tests`' 1,000 (random bytes of that shape in a drawn transaction or script), and the nine `opcode_limit_tests` entries that do carry a drawn key and were not marked. The mask is now §3's: per entry, only the fields a drawn key feeds, each named in the entry's own `masked` list, and no pattern across a file. The nine `opcode_limit_tests` entries are now marked `drawn_at_run_time` (so the family has 162 marked entries, 153 before) and every marked entry carries `masked`: 162 entries, 396 fields (`multisig_tests` 56 entries and 121 fields, `opcode_tests` 9 and 12, `script_tests` 75 and 222, `sigopcount_tests` 22 and 41). Five key-masked digests moved, and the plain sha256 of the four files whose entries gained the list (they were re-cut from the run of record, so their keys are that run's draw); the table gives each old value beside the new one. `sighash_tests`' file did not change: its key-masked digest was `2f9768a8…` and is now the file's own, `126c9e8d…`. The other nine files and their digests did not change.

The mask is exact, checked against a second run `[X]`: a second end-to-end run (`2026-10-06T01:20:21Z`, the dump `e394d5437ea8240d942d8054c66fa2cd1e52b2f8409595ebc0fb80c81eb602f9`, other keys) reproduced all fourteen key-masked digests, and entry by entry the fields that differ between the two runs are exactly the fields `masked` names: no masked field that is equal in both runs, no differing field unmasked, in all 297,840 entries. Against the files of sitting 6's last commit (`7987af9`), the four re-cut files differ only in the masked fields and in the two marks, entry by entry `[X]`.

*The seed.* §3 now says which suites ran under the seed at their own commits (the last column). The run of record ran all fourteen under it. Of the eleven that had not: eight gave the committed file byte for byte (`lrshiftnum_tests`, `bn_op_tests`, `scriptnum_tests`, `big_int_tests`, `int_serialization_tests`, `cscript_tests`, `instruction_iterator_tests`, `sighashtype_tests`: the table's sha256 with no earlier value), so those files do not depend on the seed; `opcode_tests` and `script_tests` gave the committed file outside the fields a drawn key feeds; and `sigopcount_tests` does depend on it: its six `TestMaxSigOps` entries take their prevout from `InsecureRand256` (`416`), so its file moved when the seed was first enforced (`e2b607f`, above) and is fixed under it since. What no seed fixes is the keys of `MakeNewKey`: 162 entries, masked as above.

*The checks, with `crypto_tests` added on 2026-10-06.* `tools/cpp_extract.sh --verify`: 15 files, 297,871 entries, 15 receipts, **CLEAN** `[X]` (each file's sha256, count and canonical form; the key-masked digest recomputed from the entries' `masked` lists; `drawn_at_run_time` and `masked` on the same entries; a stack limit on every `evalscript` entry; a layer on every predicate; each receipt against the manifest). `tools/mechanism_check.sh` over the family, the two gzipped files decompressed to a scratch directory: 0 hits in every file, **CLEAN** `[X]`, with `crypto_tests`' 4 public constants skipped by name as above.

**Sitting 7, lane harness-49-s7c** (branch `lane/harness-49-s7`, the Studio, 4 jobs). Each added suite runs in its own process under `TEST_BITCOIN_RANDOM_SEED=879fc8b42168dd0e608dafd51b39c6dabad37d4d`; the seed controls the test framework's random context and leaves `CKey::MakeNewKey` draws marked and masked ([SRC] `src/test/test_bitcoin.cpp:49-67`). Each build also re-runs the earlier suites to refresh their receipts against the same patch. The rows give each suite at its own commit; the current receipts and manifest carry the newest run. `tools/cpp_extract.sh --verify` and `tools/mechanism_check.sh` over each added file are CLEAN `[X]`.

| suite | run UTC | patch sha256 (8) | passed cases / assertions | IN cases with entries | entries | key-masked sha256 | mechanism check |
|---|---|---|---|---|---|---|---|
| [`opcode_tests`](receipts/opcode_tests.txt) | `2026-10-06T02:29:33Z` | `fbdd3514` | 38 / 433234 | 37 | 144,381 | `6437c6eeb1e1b9973854da09bda592428daab47d35695e86378b338fdfad7b22` | 0 hits, CLEAN `[X]` |
| [`rpc_tests`](receipts/rpc_tests.txt) | `2026-10-06T02:23:32Z` | `ab87a701` | 18 / 285 | 1 | 2 | `5cc9389e047695e3be029b3627cd16452d1373e522ab3bdc175bc0d95f41fdad` | 0 hits, CLEAN `[X]` |
| [`miner_tests`](receipts/miner_tests.txt) | `2026-10-06T02:18:56Z` | `5c461191` | 5 / 308 | 1 | 9 | `850d874ea6569f7f55d30d4dba0d3bdba01a8bd9a25181a403b200a83efe4f6a` | 0 hits, CLEAN `[X]` |
| [`blockcheck_tests`](receipts/blockcheck_tests.txt) | `2026-10-06T02:14:30Z` | `385d78bf` | 2 / 22 | 1 | 3 | `eafd346778c003622371f225bc46b63d298c8ad14007656ef16d20cb1c332935` | 0 hits, CLEAN `[X]` |
| [`txvalidationcache_tests`](receipts/txvalidationcache_tests.txt) | `2026-10-06T02:10:55Z` | `97b31c6d` | 2 / 860183 | 2 | 286,727 | `257c85288acc6ca9d4d7104b87b304a248203343127eb2d0d9161a0610378baa` | 0 hits, CLEAN `[X]` |
| [`test_txnvalidator`](receipts/test_txnvalidator.txt) | `2026-10-06T02:06:52Z` | `1473038e` | 12 / 1249 | 3 | 36 | `71de281e2e49b5f2fe4c50192aaaa088debb246bbc4badd971335ea4aee1a090` | 0 hits, CLEAN `[X]` |
| [`script_P2SH_tests`](receipts/script_P2SH_tests.txt) | `2026-10-06T02:02:35Z` | `00b74011` | 6 / 167 | 6 | 150 | `a96e30adc7ee46b11605b33ac665765487473d26e16cea4af716f726ebe3927e` | 0 hits, CLEAN `[X]` |
| [`transaction_tests`](receipts/transaction_tests.txt) | `2026-10-06T01:51:39Z` | `2021b9f0` | 16 / 5147 | 14 | 273 | `02d4d563f8be5c54e5ef09bb65a8cc0d8dd366de5a5cfee2a7dde47d5721d247` | 0 hits, CLEAN `[X]` |

`transaction_tests`: All 14 IN cases have entries. The completed run recovered from the interrupted sitting passed 16 cases and 5,147 assertions; its receipt's patch, binary and raw-dump digests were rechecked before keeping it. `tools/cpp_extract.sh --verify` checked 15 files, 298,113 entries and 15 receipts, CLEAN. The mechanism check scanned 126 distinct hex strings with 0 hits. The seed is fixed; 234 entries carry the strong-generator draw and the fields it feeds. The two COVERED cases' calls are dropped and counted in the manifest. `test_big_transaction` carries two aggregate predicates for the 4,500 sign checks and the 9,000 queued script checks ([SRC] `src/test/transaction_tests.cpp:438-496`). `test_Get` asserts only that `AreInputsStandard` has a value, not that its value is true; `observed` carries the value returned by the recorder's additional call ([SRC] `src/test/transaction_tests.cpp:314-320`; `src/policy/policy.cpp:162-190`). `ReplaceRedeemScript` asserts a non-empty stack, which the expectation shape has no inequality field for; its two calls retain the input, observed stack and that assertion in `note`, with no asserted verdict ([SRC] `src/test/transaction_tests.cpp:381-397`). Signing predicates retain the transaction before signing and cite the checked result; their drawn signing keys are not recorded ([SRC] `src/test/transaction_tests.cpp:352-357`; `src/script/sign.cpp:193-208`).

`script_P2SH_tests`: All 6 IN cases have entries. The suite passed 6 cases and 167 assertions under the fixed seed. The `Verify` helper records its callers' exact success or error assertions ([SRC] `src/test/script_P2SH_tests.cpp:28-61,201-211,380-384`). `sign` carries the 64 `CScriptCheck` combinations, and the signing, standardness, P2SH-shape, input-standardness and sigop-count checks retain their era or height and policy values. The keys drawn at 78, 224 and 394 are marked and masked. The wallet-ownership checks assert no script or transaction verdict and are not extracted ([SRC] `src/test/script_P2SH_tests.cpp:120-123,265-266`); the signing predicates retain the transaction before signing as in the earlier multisig suite.

`test_txnvalidator`: All 3 IN cases have entries. The synchronous helper records only its acceptance into an empty pool, before the conflicting spend is submitted ([SRC] `src/test/test_txnvalidator.cpp:219-231,542,562`). The two amount cases record the `GetValueOut` exceptions and invalid-output rejection, with the transaction, its funding coin and the recorded policy at the coin and tip heights ([SRC] `src/test/test_txnvalidator.cpp:679-687,713-721`). The asynchronous batch contains ten transactions whose outputs each exceed `MAX_MONEY`; the zero pool size after the queue drains asserts that none was accepted. The conflicts and the later batch of valid conflicting spends remain excluded ([SRC] `src/test/test_txnvalidator.cpp:231,567-645,727-729`). The seed is fixed and the funding key drawn by the 100-block fixture is marked and masked ([SRC] `src/test/test_bitcoin.cpp:191-202`). The validator and signing predicates retain consensus and policy as separate layer labels; no engine replay has run.

`txvalidationcache_tests`: Both IN cases have entries. The suite passed 2 cases and 860,183 assertions under the fixed seed. The non-deferred `CheckInputs` checks carry the complete transaction, ordered previous outputs with their amount, height and coinbase status, explicit flags and numerical script parameters; the flag sweep's expected value follows the caller's predicate and the upgraded-NOP adjustment ([SRC] `src/test/txvalidationcache_tests.cpp:83-156,385-388,415-418,444-447,497-500,577`). The three `ToMemPool` accepts are over an empty pool; their funding coin is recorded ([SRC] `src/test/txvalidationcache_tests.cpp:244,250,258`). The deferred-check returns and cache-vector sizes are bookkeeping and are not extracted ([SRC] `src/test/txvalidationcache_tests.cpp:177-200,378-379,625-628`). The chain-tip, best-block and pool-size checks are block or mempool-state checks and are not extracted ([SRC] `src/test/txvalidationcache_tests.cpp:241-263,395-396`). The strong-generator funding key feeds the recorded transactions and previous-output scripts, so those fields are marked and masked. A build failure in this sitting had a concrete hook error: native Boolean and integer literals were passed where the JSON recorder takes strings; the generator was corrected before this passed run. No engine replay has run.

`blockcheck_tests`: The IN case has three `CheckCoinbase` predicates: a valid coinbase and the `bad-cb-missing` and `bad-cb-length` rejections, each asserted by `CheckBlock` through `RunCheckOnBlock` at height 0 ([SRC] `src/test/blockcheck_tests.cpp:19-40,65,71,78`; `src/validation.cpp:573-590,5773-5778`). Each records the complete transaction, era and numerical consensus limits. The suite passed 2 cases and 22 assertions. The non-null prevout is drawn through `InsecureRand256` under the fixed seed, so no strong-generator mask is needed ([SRC] `src/test/blockcheck_tests.cpp:68`). Empty-block, block-size and serialization checks, and the OUT case's block-height reader throw, are not extracted ([SRC] `src/test/blockcheck_tests.cpp:52,84-131`). No engine replay has run.

`miner_tests`: The IN case has nine predicates: seven absolute-finality checks and two direct `SequenceLocks` checks ([SRC] `src/test/miner_tests.cpp:439-593`). Each carries the transaction and the height/time parameters; the sequence-lock checks also carry the previous height, its preceding block's median time and the candidate block's parent median time, which are the values the pure predicates read ([SRC] `src/validation.cpp:257-340,5930-5991`). The suite `miner_tests_journal` passed 5 cases and 308 assertions under the fixed seed; this file has no strong-generator mask. `TestSequenceLocks` reads a mempool view, and those eligibility checks are not extracted under the owner's mempool-state ruling ([SRC] `src/test/miner_tests.cpp:140-145,449,485,531,564,595-604`). Template assembly, block acceptance, cache and template-size assertions do not decide the selected transaction predicates and are not extracted ([SRC] `src/test/miner_tests.cpp:171-397,606-625`). The helper's frame maps each entry to the case's call at 872 and its checking site. No engine replay has run.

`rpc_tests`: The IN case has two predicates for the RPC `complete` flag, with and without the public test's fixed signing keys ([SRC] `src/test/rpc_tests.cpp:243-265`). Each records the unsigned transaction, supplied previous outputs, signing-key list, FORKID hash type, explicit spend and coin heights, standard input flags and numerical consensus parameters; `observed.tx` is the transaction returned by the RPC function. The RPC assigns a supplied P2SH coin a pre-Genesis height when needed and requires each input's `VerifyScript` result to be `SCRIPT_ERR_OK` for `complete` ([SRC] `src/rpc/rawtransaction.cpp:1055-1067,1101,1139-1216`). The suite passed 18 cases and 285 assertions under the fixed seed. No strong-generator input is drawn in this case, and no mask is applied. No engine replay has run.

`opcode_tests`: `negative_valtype_test` now has all 15 asserted byte transformations, including the five zero representations, sign flips and both sign-pad cases ([SRC] `src/test/opcode_tests.cpp:243-265`). `NegativeValtype` flips the top byte's sign bit and invokes the same minimal encoder used by `OP_BIN2NUM` ([SRC] `src/test/opcode_tests.cpp:183-190`; `src/script/int_serialization.h:131`; `src/script/interpreter.cpp:1781-1790`). These number-layer predicates carry literal inputs and expected bytes and need no draw or mask. All 37 IN cases of this file now have entries; its other cases, call expectations and stack limits are retained. The whole `opcode_tests` process runs under the fixed seed, and its existing nine strong-key entries remain marked and masked. No engine replay has run.

`miner_id_db_tests3`, scope reread (owner's 2026-10-05 ruling): All 15 case bodies were read through their helpers before deciding extraction. Their common `SetupMinerIDChain` submits two dataref transactions through the live node validator and asserts its admission status, then mines them from the pool ([SRC] `src/test/miner_id_db_tests3.cpp:409-423,498-555,574-580`). The `CreateDataRefTxns` call ([SRC] `src/test/miner_id_db_tests3.cpp:412`) submits two dataref spends (`:535-547,551-555`) of fixture coinbases returned by `GetFundingTxn` (`:459-463`), fed from the fixture's own blocks (`:613-616`), so admission depends on the chain's state at that height (coinbase maturity, [SRC] `src/validation.cpp:2619`) and the mempool's state and cannot be decided from the transaction and its previous output alone; the accept at [SRC] `src/test/test_txnvalidator.cpp:227` stays IN because its entry carries the coin with an explicit height. The second submission runs with the earlier admitted transaction in the pool; the source asserts no isolated `CheckInputs` or `VerifyScript` result. The returned validator status includes conflict and rolling-minimum-fee decisions over the current pool, and looks up inputs in the combined chain/pool view ([SRC] `src/txn_validator.cpp:135-170,206`; `src/validation.cpp:1143-1160,1285-1295`). The individual bodies check miner-ID database history, rotation, forks, reputation, revocation or version fields; `UpdatesToBlockchain` also checks pool filtering after reorgs ([SRC] `src/test/miner_id_db_tests3.cpp:811-2405,939-957,979-1034`). These are OUT BY RULING: mempool-state policy; all 15 rows give their case range and the shared admission lines. No entry, patch or receipt was added for this suite. Seed/build/run/mechanism checks are not applicable to an excluded suite; the 21 extracted files and their passed receipts are retained. At that suite boundary the two other deferred suites remained to be re-read.

`miner_id_db_tests`, scope reread (owner's 2026-10-05 ruling): All 5 case bodies and their setup/admission helpers were read. `SetupMinerIDDBChain` admits a two-transaction dataref batch into the live pool and mines it into the following block; its funding transactions are read from the active chain's blocks ([SRC] `src/test/miner_id_db_tests.cpp:190-204,232-294,304-309`). The status asserted at 283 is the node validator's combined admission result, with pool conflict, combined chain/pool lookup and rolling-minimum-fee decisions ([SRC] `src/txn_validator.cpp:135-170,206`; `src/validation.cpp:1143-1160,1285-1295`). No separate script or transaction/prevout validity result is asserted. The case bodies check database rebuild/restore, miner IDs, chain updates/reorgs, pruning, recent-block history and reputation ([SRC] `src/test/miner_id_db_tests.cpp:503-856`). All 5 cases are OUT BY RULING: mempool-state policy, each row naming the common admission lines and its case range. No entry, patch or receipt was added for this suite; seed/build/run/mechanism checks are not applicable to an excluded suite. At this suite boundary `jba_selfish_mining_tests` is the remaining scope reread.

`jba_selfish_mining`, scope reread (owner's 2026-10-05 ruling): All 3 case bodies and the fixture, `SubmitTxn`, `AddSingleTransaction`, `AddCPFPTransactions` and block-membership helpers were read. The admission assertions use the live pool, including low-fee parents and paying children whose package membership changes; the block helper asserts chain acceptance and height advancement ([SRC] `src/test/jba_selfish_mining_tests.cpp:74-76,118-132,158-189`). `NoSelfishNoThrottling` checks whether a standalone spend and CPFP group enter the template, followed by pool clearing on block acceptance (`239-258`). `NoSelfishJustThrottling` changes template eligibility by the current template's size, clock and accumulated package state (`278-402`). `SelfishAndThrottling` excludes pooled spends by age and then includes the same parents when current children join their groups (`440-609`). These eligibility decisions read the mining journal, previously accumulated block size, last update time and package membership; they are not a transaction/prevout validity function ([SRC] `src/mining/journaling_block_assembler.cpp:197-250,318-347`). All 3 are OUT BY RULING: mempool-state policy, each row citing its decisive admission and eligibility lines. No entry, patch or receipt was added for this suite; seed/build/run/mechanism checks are not applicable to an excluded suite. This completes the deferred scope rereads; no engine replay has run.

**Sitting 7 completion.** The 29 extracted cases and 23 exclusions account for all 52 cases assigned to this sitting. The passed run of the final patch is `2026-10-06T02:29:33Z`: 21 suite processes, 267 passed cases and 1,591,470 passed assertions. `tools/cpp_extract.sh --verify` checks 21 files, 585,055 entries and 21 receipts, CLEAN `[X]`; each changed file's mechanism check is CLEAN, as the sitting-7 table records. That run's patch, binary and raw-dump sha256 values were checked at sitting 7's boundary. The crypto extraction under owner C1 adds the three crypto cases and 31 entries recorded above. No engine replay has run; the 60 digest-only `caching_invalid_signatures` entries retained from sitting 6 still lack replay inputs (§3).


**Sitting 8 merge, lane harness-49-s8** (branch `lane/harness-49-s8`, base `daf9341`, the Studio, 4 jobs). All eleven sitting-7 commits were cherry-picked individually onto the crypto extraction's main base; none became empty. The artifact of record is `instrument.patch`, sha256 `07a6141996e07cda5665727e20cf8314d098f991f38aabba7bbe4386b2424205`, with 24 patched source files. It was regenerated from pinned source copies using sitting 7's hook generators, the crypto generator `s6/mk_digests.py`, and the same `mkpatch.sh` used in sittings 6 and 7. Every sitting-7 patch component and the crypto patch component were checked byte for byte against their original artifacts before the union was built `[X]`. The 48 files in the extractor's pin list agree with `879fc8b42168dd0e608dafd51b39c6dabad37d4d`; the union applied cleanly to the reference copy.

`WORK=~/bsv/targets/spec-cpp-extract/s8/run JOBS=4 tools/cpp_extract.sh` configured and rebuilt the reference's `test_bitcoin` with §4's options, then ran 22 suites in separate processes under `TEST_BITCOIN_RANDOM_SEED=879fc8b42168dd0e608dafd51b39c6dabad37d4d`: 278 cases and 1,666,403 assertions passed, run UTC `2026-10-06T03:03:57Z`. It re-cut all 22 [suite receipts](receipts), each naming this union patch, binary sha256 `ce68a5cb39b151eb83213fdff3e0ccd62fa836dc149160cee59d3abf1f81d296` and raw-dump sha256 `5a47ff17685bfb60aa733035bba221f3c3a34e86432475d215135b4ebad775a4`. All 22 committed files were kept byte for byte; their plain, compressed and key-masked digests and their counts match the pre-run manifest, with no changed digest. Strong-key draws in the new run are recorded as `sha256_of_the_run` where they differ `[X]`.

`tools/cpp_extract.sh --verify`: **22 files, 585,086 entries, 22 receipts: CLEAN** `[X]`. `tools/mechanism_check.sh corpus/cpp <scratch-with-decompressed-files>`: **22 files, 0 hits, CLEAN** `[X]`, including all three compressed files (`opcode_tests`, `script_tests`, `txvalidationcache_tests`) decompressed to scratch. The gate skips exactly four named public constants in `crypto_tests`: `SHA-256(empty)`, `SHA-256(abc)`, `SHA-256(448-bit FIPS example)` and `SHA-256(million a)`, cited in [the allowlist](../../tools/mechanism_allow.txt); every other file has zero skips. The corpus bytes after extraction are identical to the bytes scanned by the gate. Python `hashlib` also checks all 28 replayable crypto digests, including messages encoded as byte runs; the 3 digest-only crypto messages and 60 digest-only `caching_invalid_signatures` entries remain outside that check. No engine replay has run.

## 6. What is left of #49, and the order

1. **Extraction.** Sitting 7's 52 cases are accounted for: 29 extracted in eight suites and 23 reclassified under the owner's 2026-10-05 mempool-state ruling after the three deferred suite rereads (§2a, §5). With the crypto extraction under owner C1, the corpus has 585,086 entries in 22 files representing all 190 IN cases; no IN case remains marked "not yet". No extraction is owed for the OUT BY RULING cases.
2. **The replay** (done-bar item 2): an `evalscript` entry is not a spend, so the replay reads `input` directly into the spec's evaluator and bsv-rs's interpreter (both run a script on a given stack), and states which entries also have a spend form for the two node instances (a push-only unlocking script that rebuilds `input.stack`, under the entry's `flags` and `params`) and which do not (an entry whose flags or parameters no node configuration produces).
3. **The report and the tripwire** (items 3 and 4).
