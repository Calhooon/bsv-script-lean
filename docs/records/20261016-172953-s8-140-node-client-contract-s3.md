# #140: the node's client contract, generated from the ledger (lane ns-140)

[M] 2026-10-16, S3 (with S2's `tools/specgen.py` under the tie and S4b's `harness/engines/teranode/contract.rs` in its own
commit), lane ns-140, Claude Opus 5.5 on the box. Base: `origin/main` at `6402f9ae` (the lane branch re-cut from it at
17:11:56Z). Nothing of a node's reply text is quoted here beyond the reference's own reject reasons in the receipt's
projection; nothing of the Teranode instance's text was read (its run is read by `jq` fields of the steps file and the
projection only).

## 1. The owner's word and the charter

The owner's re-cut of #140 (comment 6220697174, 2026-10-16T17:08:38Z), verbatim: **"140 north star"**, on his framing: "in
BSV the rules never change, as its a stabel protocol... but teranode was made to massively sclae the chain.. and that is
why you see differneces like this.. as desigin deciosns were made". The page is the one the epoch's north-star index
lists as owed from this captain: what the node machine demands of a node that replaces SV-node, and which of its
behaviours the spec treats as consensus versus policy.

## 2. The two north stars, as read

- **BSV's protocol is set in stone** [LIT]: Teranode's `docs/references/networkConsensusRules.md:4` at `4edb60a4` ("These
  rules are **protocol level rules** that are **set in stone**"), read by `git -C ~/bsv/teranode show 4edb60a4:<path>`.
  The box has the full clone at `~/bsv/teranode` (the tag `v0.16.0` resolves to the pin); `~/bsv/targets/spec-54/teranode`
  named in the charter is absent on the box, so every Teranode read here is that clone at the commit, never a working tree.
- **The chain's north star page** [LIT]: `~/bsv/bsv-stack-lean/docs/BSV-NORTH-STAR.md`, read 2026-10-16T17:23:35Z, sha256
  `e64800b53e71d6661f3fa17fc6fba7e35bd8343bb8fe0daa731c2b0cb4481d96`, its last commit `f212d02`; read only.
- **Teranode's north star is scale** [LIT]: `docs/topics/teranodeIntro.md:7` (horizontal scaling) and `:9` (over a million
  transactions a second); `docs/topics/architecture/teranode-overall-system-design.md:82` (subtrees broadcast every
  second) and `:174`, the comparison table's mempool row: "No traditional mempool. Transactions are immediately processed
  and organized into subtrees. Continuous validation and subtree creation replaces mempool functionality." Where the
  design reason is in Teranode's source, it is cited `[SRC]` at `4edb60a4` (the validator's no-pool comment
  `services/validator/Validator.go:681-683`, the conflicting mark `stores/utxo/Interface.go:541`, the frozen spend
  `stores/utxo/aerospike/spend.go:1103-1107` and `stores/utxo/sql/sql.go:2434-2435`).

## 3. What landed, by commit (on `lane/ns-140`, for the captain to land)

| commit | seat | what |
|---|---|---|
| `e3841671` | S3 | the marks (section 6); `tools/scenario_metadata_check.py` skips a fenceless scenario page by name; INDEX hashes |
| `b36b452c` | S3 | the ledger's `section`, `design`, `measured`, `sections`, `contract`; `tools/teranode_absences.py` validates, prints and `--verify`s them; `tools/node_contract.py`; the state page's row; this record's skeleton |
| `c6ba3957` | S2 | `tools/specgen.py` renders `spec/node-client-contract.md` and indexes it in `spec/README.md` |
| `378b0816` | S3 | `tools/soft_freeze_probe.py`, its receipt, `tl.soft-freeze`'s reference answer |
| `cbd5ddb2` | S4b | the contract's `freeze` at three parameters |
| `15393e67` | S3 | the Teranode answer of `tl.soft-freeze`, its projection |
| `2b49a6f2` | S3 | the red team pass (section 8) |

**The generator.** A sibling tool, `tools/node_contract.py`, not a mode of `tools/teranode_absences.py`: that tool renders one
card per row, and the contract page also reads the column projections and records of cut 2, the rules file
`harness/rules/second-oracle-scenarios.json`, `corpus/rpc/contract.json`, `corpus/merkle/subtree-vectors.jsonl`,
`corpus/wire/` and `spec/theorems.md`. It imports the absences tool's loader, validator and cite formatter. It is wired
into `make spec` through `tools/specgen.py` (the Makefile's `spec` target runs specgen, so no Makefile line changed) and
into `specgen --check`'s file list. Before rendering it checks: a whole run's figures equal its projection's totals; a
chunked run's figures and the reference column's sentence occur in their records; every whole-run diverge has a class
in the rules file and a reading in the ledger, or a timing mark in the corpus, or is a withheld row; every theorem has
its entry in `spec/theorems.md`; every RPC method is in the RPC contract; every row the machines' table names is a
section-3 row.

**The withheld rows.** The block-validity report filed with the Teranode maintainers on 2026-10-15 withholds its two
witness rows by name until its publication date (`docs/records/20261015-213309-security-reports-filed-66-t1-s3.md`).
The page therefore names no median-boundary row: a diverge whose row id's sha256 is in the ledger's
`contract.consensus.withheld` prints "(a class under a still-private advisory: withheld, D135)", WRITE-UP's form, and
neither the ledger nor the page carries the name. The page withholds the name; the tree's projections carry it, as before
this lane (the in-tree projections of checks 4 and 5 list the row with its verdict). So section 1 does not claim the two nodes identical: it gives the
figures, names every whole-run diverge with its class (rulings open, rule 15) and states the equalities the theorems
prove.

## 4. What each row gained

| row | section | the owner's word | design | measured |
|---|---|---|---|---|
| `tl.dsdetected` | 3 | gap | 4 cites | reference [X], teranode [M] |
| `tl.ds-attempt-callback` | 3 | gap | 3 cites | reference [X], teranode [M] |
| `tl.zmq-announce` | 3 | dropped | 3 cites | none |
| `tl.zmq-removal` | 3 | gap | 4 cites | none |
| `tl.invalidtx-sinks` | 3 | dropped | 2 cites | none |
| `tl.miner-id` | 3 | dropped | 1 cite | none |
| `tl.nonfinal-pool` | 3 | gap | 3 cites | reference [X], teranode [M] |
| `tl.orphan-pool` | 3 | dropped | 2 cites | none |
| `tl.safe-mode` | 3 | dropped | 1 cite | none |
| `tl.pool-size` | 3 | gap | 4 cites | none |
| `tl.soft-freeze` | 3 | gap | 5 cites | reference [M], teranode [M] |
| `tl.compact-blocks` | 3 | dropped | 2 cites | none |
| the seven `rl.` rows | 2b | new | none | none |

The four mempool rows (`tl.zmq-removal`, `tl.pool-size`, `tl.nonfinal-pool`, `tl.ds-attempt-callback`) share the no-mempool
reason with their own cites each. The six dropped rows carry a design too, so every section-3 line has a design line and a
client sentence; `tl.safe-mode`'s design line says what its cite shows (the state machine) and that no Teranode document
or source line at the tag gives a reason for a fork warning, so it states none (fix lane fix-ns-140, #140's lens). `rulings`, `ruling_rule` and every existing field of every row are unchanged (checked: every key of the
old file equal in the new; the rows gained only `section`, `design`, `measured`); the `_header` gained one dated sentence.
`tools/teranode_absences.py --verify`: 91 citations anchored on main, 146 on this branch (the 34 design cites and 21
contract cites; 135, 33 and 11 before the fix lane's ten cites of the verdict surface and its one of `tl.pool-size`).

**`tl.dsdetected`, a correction to the charter.** The charter says #80's run measured both halves. It did not: #80's record
(`docs/records/20261015-165715-s7-80-double-spend-s1.md`, its "Teranode, reading only" paragraph, and
`docs/CONFORMANCE-DOUBLE-SPEND.md` section 5) measured the reference's message and webhook [X] and READ Teranode's 409
and rejected-transaction gossip at the pin, the measured leg waiting on cut 2. The row's Teranode answer is therefore what
a run has: cut 2's check 5 row `mempool/accepted-spend-conflict` (the second spend refused, RPC code -25, agree) [M], with
the 409 and the gossip named as a reading, not yet a run.

## 5. The two chain-level measurements

**`tl.soft-freeze`, the reference** [M]: `tools/soft_freeze_probe.py` (a tools/ script, not a scenario row: the frozen
family's runner, `harness/src/scenarios/frozen.rs`'s RELEASE recipe, measures the release's end state against a Lean-judged
row; this records per-block states and judges nothing). Two fresh regtest instances of the node of record (the version
string checked; RPC/P2P the lowest free pair in 18571..18590 by `tools/rpc_probe.py`'s `Node`; Genesis 10, Chronicle 20 as
the frozen family's recipe), blocks built with the pinned functional-test framework (the clone at the pin, its framework
and `src/policy/policy.h` clean). `addToConsensusBlacklist` (`src/rpc/frozentxo_rpc.cpp:346-378`) lists F:0 from height 0
with no stop; block A at 103 spends it.

| phase | submitted | `submitblock` | best | A's confirmations | A's freeze flag | A's branch in `getchaintips` |
|---|---|---|---|---|---|---|
| default (3) | A (103) | `bad-txns-inputs-frozen` | 102 | -1 | true | `valid-headers` |
| default (3) | A+1 to A+3 (104 to 106) | `inconclusive` each | 102 | -1 | true | `valid-headers` |
| default (3) | A+4 (107) | accepted | A+4 (107) | 5 | true | `active` |
| `softconsensusfreezeduration=0` | A, A+1 to A+5 | as above | 102 throughout | -1 | true | `valid-headers` |

At the end F:0 is spent in the default phase and unspent in the zero phase. Receipt:
`docs/records/20261016-173411-s8-140-soft-freeze-reference-s3.json` (271 calls, the projection). A run three minutes
earlier gave the same answers but its projection overwrote each step's height with the block count (a key collision in
the probe); it was discarded uncommitted and its run directory removed. Both instances were stopped by `stop` (exit 0)
and the run directory `~/bsv/targets/spec-oracle-scenarios/ns-140-20261016-173411Z` removed at the end.

**`tl.soft-freeze`, Teranode** [M]: the recipe exposes the UTXO store's frozen flag through the RPC `freeze`
(`services/rpc/Server.go:223`, `handleFreeze` `services/rpc/handlers.go:2708-2730`; the alert service is off in the
recipe, `-alert=0`, harness/engines/instance41/README.md:53). Cut 2's road already freezes for the frozen rows, but its
call sent two parameters where `FreezeCmd` has three required fields (`services/rpc/bsvjson/chainsvrcmds.go:703-707`;
`checkNumParams`, `services/rpc/bsvjson/cmdparse.go:91-105`), which answered -32602 and left `frozen/block` no-verdict in
both whole runs. Teranode's docs at the tag list two parameters (`docs/references/services/rpc_reference.md:1468-1469`):
the docs and the code differ, recorded here under rule 15's spirit for the second implementation. `cbd5ddb2` sends the
txid as the third (the handler sets the store's `UTXOHash` to the txid, `handlers.go:2725`). The release build at
`cbd5ddb2` (`CARGO_BUILD_JOBS=4`, the worktree's own `harness/target`, cloned from the lanes' shared target, 21 s), then
`column.zsh` with `ORACLE_QUARANTINE=~/bsv/targets/spec-oracle-quarantine/teranode-ns-140-20261016-173953Z` (the runner
requires the `teranode-` prefix, `harness/src/scenarios/mod.rs`, so the lane's name follows it), `INSTANCE41_RECIPE=legacy`,
`ORACLE_ROWS=frozen/block,availability/precedes-frozen`, `client_check` exit 0, under the box leg lock and a Lean slot
for 64.4 s (the column's convention; no Lean build). The projection
`docs/records/20261016-173953-s6-66-cut2-second-oracle-s3.json`: 2 measured, 2 agree [M]; each row's `frozen` true and its
block refused on the bridge's wire, reject code 16 (`REJECT_INVALID`, 0x10 at bitcoin-sv `6504a3af` `src/consensus/validation.h:15`, the value Teranode sends being go-wire's `RejectInvalid RejectCode = 0x10`, `msg_reject.go:21` in go-wire v1.2.11, the version Teranode's `go.mod` requires at `4edb60a4`, the bridge's code, with the text "block rejected", for any block it refuses outside a transient local error, [SRC] `services/legacy/netsync/manager.go:2099-2100` at Teranode `4edb60a4`; the code does not name the freeze, whose refusal is the reading of the store's spend, `stores/utxo/aerospike/spend.go:1103-1107`), status rejected; full receipt sha256 `c2fc896e…` (in the quarantine
directory, 38 files, listing sha256 `6c368984…`, 200 MB). The error-code string (the `ERR_UTXO_FROZEN` class) is in the
instance's text and was not read; the projection's field is the wire reject code. Blocks on the refused block were not
driven (the road delivers one block per row): the half after the reference's hold lapses is owed to #94's measured leg.
A start one minute earlier (`teranode-ns-140-20261016-173859Z`) was refused by the runner's record-name check before any
instance started (its steps file: `run_scenarios` exit 1, no `instance_start`).

**For the road (not adjudicated here).** On this two-row run `frozen/block` and `availability/precedes-frozen` read agree,
where both whole runs read no-verdict: the figures of record (checks 4 and 5) stand with their run shape; a later whole
run at `cbd5ddb2` or after would move two no-verdict rows to measured.

## 6. The marks (item 4)

In the scenarios' metadata, where `tools/scenario_metadata_check.py` reads it (`corpus/chain/<family>/<family>.jsonl` and
the JSON fence of `corpus/scenarios/*.md`): `chain-disconnected-now-nonfinal`, `chain-invalid-retry` and
`chain-reorg-depth-2` in `corpus/chain/chain/chain.jsonl`, and #90's step `s1` in
`corpus/scenarios/2026-10-14-conflicting-spends-order.md`, gain `timing_sensitive: true`, `timing_note` and
`timing_readings` (each the run, the verdict, the projection and the record; each verdict checked against its projection
when written):

| row | cut 2's c7 | the repeat of c7 | check 4 | check 5 |
|---|---|---|---|---|
| `chain-disconnected-now-nonfinal` | diverge | no-verdict | no-verdict | diverge |
| `chain-invalid-retry` | no-verdict | no-verdict | no-verdict | agree |
| `chain-reorg-depth-2` | no-verdict | no-verdict | no-verdict | agree |
| #90 step `s1` (cut 2's c1) | agree | | diverge | agree |

`mempool/absurd-fee-zero-disables` (`corpus/chain/mempool/mempool.jsonl`) gains `run_shape`: agree in the chunked record
(c8, `20261015-174520`), non-judging in both whole runs; no whole column was run. The two jsonl files are rewritten on
those four lines only (compact separators, as the files are); `corpus/INDEX.md`'s two hashes refreshed by
`scenario_metadata_check.py --write-index`. The check stopped on main since `b0379b9f` at `2026-10-15-double-spend-notify.md`
(a prose scenario page with no JSON fence; no leg runs the check); it now skips a fenceless page by name and prints it.

## 7. What #95 needs (item 5)

No #95 report code exists in the tree (`grep` of tools/ and harness/ for #95: only `tools/teranode_map.py`'s mentions).
`tools/teranode_absences.py` prints the new fields on each card. #95's per-release report reads, from
`corpus/teranode/absences.json`, per row: `id`; `section` (a key of the table's `sections`: `"1"`, `"2"`, `"2b"`, `"3"`);
`ruling.owner.word` (one of the table's `rulings`); `design` (object or absent: `reason` string, `cites` a list of
`{repo, path, lines: [a, b], anchor, label: "[LIT]"|"[SRC]"}`, `client` string); `measured` (object or absent: keys
`reference` and `teranode`, each `{label: "[M]"|"[X]", answer: string, record: path, receipts: [path]}` or `{owed:
string}`). A later Teranode release that adds a surface flips the row by data: its `present` side gains the Teranode cite,
its `measured.teranode` gains the run, and the ruling rule decides the word; the report diffs those fields release to
release.

## 8. The red team pass (item 7)

**As a Teranode engineer reading a page about their design written by outsiders**, the sentences that would make one wince,
each fixed at its source (`2b49a6f2`), before and after:

1. Section 3's rows read "Ruled `gap` (… a gap a client will feel)" with no gloss, a defect label to a reader who did not
   write the rule. After: section 3's header says the ruling words are the ledger's, `gap` a difference a client feels when
   it moves between nodes and `dropped` a surface whose information reaches a client otherwise or that only an operator or a
   peer uses, "neither word says that either node is wrong" (the generator's header text).
2. Section 2's merkle line: "not an RPC on Teranode (the contract's class `absent`)". After: "on Teranode served by its Asset
   Service over HTTP rather than by RPC" (the generator).
3. `tl.ds-attempt-callback`'s reason joined the no-mempool sentence and the double-spend sentence with nothing between them.
   After: "With no pool to hold a contested transaction, a double spend is settled where the outputs live, at the UTXO
   store" (the ledger's `design.reason`).
4. `tl.safe-mode`'s reason: "an operator's fork warning is not among them at the tag", a guess at what Teranode chose not to
   do. After: "its states (IDLE, RUNNING, CATCHINGBLOCKS) name the service's sync state" (the ledger).
5. Earlier, before the page's commit: `tl.zmq-removal`'s "the fact a removal event used to carry" (as if Teranode had removed
   something) became "the fact SV-node publishes as a removal event"; section 1's "the evidence that the two
   implementations apply the rules alike" became "the evidence for the two implementations", every diverge named; and
   section 2b stopped printing the rows' old ruling reasons (one reads "what the reference lacks").

Five sentences changed in the pass and three before it. The section-3 text carries none of "missing", "lacks", "fails to"
(grep: 0).

**As a wallet engineer who shipped on SV-node and must move**, what the page did not tell them: (a) Teranode's broadcast
answers over HTTP; added from data: the verdict surface now names the propagation service's 409 (double spend), 422
(parent not seen) and 400 (non-final) with three cites at the pin; the fix lane added 403 (a spend of a frozen output,
`ErrFrozen`, `services/propagation/Server.go:766-767`) and 200 (a resubmission of an accepted transaction, `ErrTxExists`,
`Server.go:761-765`), each a reading at the pin. Named owed, not added: (b) the minimum fee and the other
policy defaults of each node (docs/PARAMETERS.md carries the reference's; a Teranode column of them is not on the page);
(c) what each node answers to a resubmission of an accepted transaction (cut 2's `mempool/already-accepted` is an
rpc-precheck row, not a verdict; Teranode's propagation half is a reading at the pin, 200 for `ErrTxExists`,
`services/propagation/Server.go:761-765`, beside 403 for a spend of a frozen output, `ErrFrozen`, `:766-767`, both now on
the verdict surface; the RPC half and the reference's answer are not measured); (d) the format Teranode's `/merkle_proof/:hash` returns beside the reference's TSC proof
(`util/merkleproof` at the pin, not read here); (e) the chained-unconfirmed spend on both nodes beyond #91's flag-word
theorems.

## 9. The stack Finding and the epoch's line (item 6)

The `**Finding.**` for bsv-stack-lean: #140 comment **6221322152** (2026-10-16T17:44:51Z): the page's path and `2b49a6f2`,
section 4's lines for the stack's machines, and the sentence a stack machine obeys, **build on section 2, never on
section 3**.

The one-line row for the epoch's `NORTH-STARS.md` section 3, for the owner to hand to the epoch captain (this lane writes
nothing in `~/bsv/epoch`): `spec/node-client-contract.md` (bsv-script-lean #140): what a node that replaces SV-node gives a
client, generated from the absence ledger at Teranode v0.16.0 and bitcoin-sv v1.2.3: consensus set in stone, the protocol's
client contract, what one implementation adds, and what is beyond the protocol by Teranode's design, each with its cited
reason and what a client does instead; build on section 2, never on section 3.

## 10. Checks

Run on the box at the branch's tip, 2026-10-16 17:4x UTC:

```
python3 tools/specgen.py --check            specgen --check: OK (123 files up to date; 1 rules flagged)
python3 tools/node_contract.py --check      node_contract --check: OK
python3 tools/teranode_absences.py --check  teranode_absences --check: OK (19 absences)
python3 tools/teranode_absences.py --verify teranode_absences --verify: GREEN [X]: 135 citations anchored, 2 listings and 27 searches equal at the pins; 12 absent map.json rows each have a row; 0 failures
python3 tools/cite_check.py                 cite_check: GREEN (every checked active anchor holds at the pin; closed history is not checked); anchored and holding 5620, MOVED 0
make check-pins                             check-pins: GREEN (94 sites agree with docs/PROVENANCE.md §1a; 7 skipped by name)
python3 tools/scenario_metadata_check.py    node metadata: GREEN [X] ([M] 1002 exact-shaped tokens; eight INDEX hashes); witness schema/index: GREEN [X] ([M] 11 files); receipt expectation labels: GREEN [X] ([M] 1429 expectations)
cargo build --release --locked              Finished `release` profile (21.11 s, incremental), exit 0
cargo fmt --check                           exit 0, no output
cargo clippy --release --locked --bin run_scenarios -- -D warnings   exit 0
git diff --check                            no output
the dash grep on every touched file         no output
tools/wording_gate.sh <the page, the absences page, spec/README.md, the state page>   CLEAN (4 pages); main's three of them CLEAN: no new hit
```

The fix lane fix-ns-140 (#140's lens: 1 WRONG, 1 MISSING, 3 UNCITED, 1 WORDING, 11 NIT, each applied), on the box,
2026-10-16, before 18:01 UTC (the commit's stamp):

```
python3 tools/specgen.py --check              specgen --check: OK (123 files up to date; 1 rules flagged)
python3 tools/node_contract.py --check        node_contract --check: OK
python3 tools/teranode_absences.py --check    teranode_absences --check: OK (19 absences)
python3 tools/teranode_absences.py --verify   teranode_absences --verify: GREEN [X]: 146 citations anchored, 2 listings and 27 searches equal at the pins; 12 absent map.json rows each have a row; 0 failures
python3 tools/rpc_contract.py --verify        rpc_contract verify: GREEN [X]: 690 citations read at the pins, 0 that do not hold
python3 tools/scenario_metadata_check.py --write-index   node metadata: GREEN [X] ([M] 1002 exact-shaped tokens; eight INDEX hashes)
python3 tools/cite_check.py                   cite_check: GREEN (every checked active anchor holds at the pin; closed history is not checked); anchored and holding 5620, MOVED 0
tools/wording_gate.sh <the two spec pages>    CLEAN (2 pages)
```

No cargo or Lean build: the fix lane touches no Rust and no Lean; the box tripwire verifies the tree.

`cite_check` scans `lean/` and `docs/` only, so the page's and the ledger's Teranode cites are held by the ledger's own
`--verify`, which the cite leg of `make check` runs. No `make check` tripwire ran in this lane (the box is shared; the
captain's landing names it).

## 11. Not done, and why

- One commit subject exceeds the lane's 150-character cap: `15393e67` (154 characters), pushed before the count was gated;
  the branch is never force-pushed, so it stands; every later commit was gated on the count.
- The hook's stamp check skipped six subjects: `e3841671`, `b36b452c`, `378b0816`, `15393e67`, `2b49a6f2` and `3803d213`
  begin with `#140`, and `tools/hooks/git/commit-msg:27` and `:44` drop every `#` line and read the body's opening line as
  the subject, so neither the stamp check nor the 200-character cap read them. No rewrite (never a force-push); the fix
  lane's subject does not begin with `#`.
- The Teranode half of `tl.dsdetected` stays a reading for the 409 and the gossip (section 4); the measured part is the
  refusal of the second spend.
- The Teranode half of the soft freeze after the reference's hold lapses is not driven (section 5), owed to #94.
- No whole column re-run (the charter's word; the box is shared).
