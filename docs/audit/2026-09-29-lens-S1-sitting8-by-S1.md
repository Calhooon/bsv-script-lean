[export: 2 lines withheld by tools/export_public.py, the sibling trees' lines; the original is in the private history]
<!-- S1's own lens (the paste's rule (6), D127) on `### S1 END BLOCK (2026-09-29T18:25:51Z)` (landed `9c6d344`): a fresh-context, read-only subagent on Opus 5.5 (the live glass `true` at its spawn, 18:26 UTC 2026-09-29), launched by S1 (set 4 sitting 8); 1,517,513 ms and 101 tool uses by the tool's usage line. Its report below, verbatim (its final message, read from the transcript). -->

LENS ON S1's END BLOCK 2026-09-29T18:25:51Z, model opus: HELD IN SUBSTANCE, 13 corrections (4 load-bearing, 9 cosmetic)

**How it was read.**
- The block is unchanged from `9c6d344` to `origin/main` `9a43a89`. Round 4 was read at `origin/lean-a-s8-r7` `3084bb4`. Everything went through git; the working tree was not read.
- Tracker by REST only: #32 (30 comments) and #38 (6).
- The run log `e9453b81…jsonl`, read-only with python.
- The pin `879fc8b42168`, and bsv-rs `c7ff2c3`, by `git show`.
- One tool was executed: `tools/cite_check.py --propose`, without `--write`, on a scratch `git clone --shared` checked out at `7a94db9` in the session scratchpad. The clone was removed after.
- No build, no Lean, no Lake, no make.
- Nothing of F1 was read or re-derived.

| claim (quoted short) | verdict | evidence |
|---|---|---|
| Answering: "the parent's paste of 2026-09-29 18:12 UTC (continue 53), in the turn it came in" | HELD | `c54ee08` adds it at `docs/lanes/harness.md:827`. Run log: queued 18:14:39Z, delivered 18:19:59Z inside the running turn. `c54ee08..9c6d344` pushed 18:26:02Z, with no user turn between. |
| (1) "F1 is closed to model turns …"; (b) "F1: … the owner decides it under rule 15" | HELD (judged only on F1 left alone) | The block prints no F1 row, witness or record. Its words follow the paste. Nothing of F1 was read here. |
| (2) "my last one (2026-09-29T11:18:07Z)" | HELD | Heading at `docs/lanes/lean.md:531` (`f83deec`). |
| (2) "the rest of sitting 8 (the parent's paste of 11:21 UTC, #32's SECOND lens, THE TRUST BOUNDARY)" | PARTIAL (correction 5) | The paste is `harness.md:656`, with that title. The 11:18:07Z block was sitting 7's, so this block covers all of sitting 8. |
| (2) "the continued Opus 5.5 session `e9453b81` … branch `lean-a`" | HELD | Run log from line 11830 (11:18Z) on: 1,884 assistant messages, all `claude-opus-5-5`. `block.sh` at 18:23:24 reads "HEAD 3084bb4 (lean-a)". |
| (a) "Sitting 7's lens: HELD IN SUBSTANCE; its 3 load-bearing corrections landed at `8572171`" | HELD | `docs/audit/2026-09-29-lens-S1-sitting7-by-S1.md:3`; `8572171`'s subject. |
| (a) "scope posted before it ran (#32 5889297005)" | HELD | Posted 11:26:05Z. The four parts spawned 11:27 UTC (their headers). |
| (a) "Four fresh-context, read-only parts on Opus 5.5 (the live glass `true`), read at `20aeaf0`" | HELD | Every header: "model opus, at 20aeaf0", glass `true` at spawn. |
| (a) "tally 5889910566" | HELD | Exists, 12:05:18Z: A 14/5, B 19/8, C 14/7, D 14/5. |
| (a) "61 findings, 25 load-bearing" | HELD | Re-derived from the finding headings: A-1…A-14 (A-1…A-5 load-bearing), B-1…B-19 (B-1…B-8), C-1…C-14 (C-1…C-7), D-1…D-14 (D-1…D-5). |
| (a) "four of them verdicts": D-1 S1's, fixed; B-2 S1's in `Corpus.lean`, CLI half S3's; B-1 S2's; B-3 S3's | HELD | 5891805687 item 1 corrects three to four. Owners per 5889297005. D-1's fix is `laxSeqLength` in `c68b3b2`, which matches `pubkey.cpp:48–60` at the pin `[SRC]`. |
| (a) Round 1: "`c68b3b2`, LANDED at `e5f4a80`"; leg `…123029…` "GREEN in 164 s"; landing `…123740…`; "first patches are at `e1be89e`"; #32 5890486699, 5890616150; #38 5890482287 | HELD | Record: commit `c68b3b2`, 164s, box, GREEN, the 21 legs of `tools/check.sh`'s header. `git diff --quiet c68b3b2 e5f4a80` over the legs' paths exits 0. The comments exist and say this. |
| (a) Re-lens 1: "29 CLOSED, 24 PATCH-CORRECT, 8 not closed, 26 NEW, one load-bearing (CN-1, S3's `docs/PROVENANCE.md:141`)" | HELD | By part: A 11/3/0/5, B 2/12/5/8, C 4/8/2/6, D 12/1/1/7; each header equals its counted rows. NEW: AN-1…5, BN-1…8, CN-1…6, DN-1…7. CN-1 is the one LOAD-BEARING, with that site and owner. |
| (a) Round 2 "LANDED at `121d4d4` (14:22:58 UTC)"; leg `…141538…` "GREEN in 136 s at `52f2c7f`"; landing `…141907…`; v2 patches; #32 5892226655; Correction 5891805687 | HELD | Run log: "pushed 14:22:58Z: 121d4d4". Record: `52f2c7f`, 136s, GREEN. Byte-identity exits 0. The `…140334…-v2` records exist. |
| (a) Re-lens 2: "15 CLOSED, 31 PATCH-CORRECT, 5 not closed, 27 NEW, none load-bearing" | HELD | A 3/4/1/7, B 5/10/2/4, C 1/15/1/10, D 6/2/1/6. D's two "(not counted)" rows are excluded, as its header says. Every NEW finding is PRECISION or OBSERVATION. |
| (a) Round 3 "LANDED at `c4c9be3` (16:19:00 UTC; `917bf79` …, `4b5c0c1` …)"; leg `…155509…` "twenty-one legs GREEN in 140 s at `7186987`"; landing `…155839…` | HELD | Run log: "pushed 16:19:00Z: c4c9be3". Record: `7186987`, 140s, GREEN, 21 legs. Byte-identity exits 0. |
| (a) "What it added: the wrapper's guard …; AxiomCheck's walk …; version-3 patches" | HELD | `4b5c0c1` (28 files); 5894190219. |
| (a) "Tracker: #32 5894190219; Corrections 5892869106, 5893037758; #38 5893037466" | HELD | All four exist, are S1's, and say what the block says. |
| (a) Re-lens 3: "14 CLOSED, 37 PATCH-CORRECT, 2 not closed, 26 NEW, one load-bearing: C3N-1, my own" | HELD | A 6/6/0/5, B 3/2/1/6, C 2/23/1/9, D 3/6/0/6. C3N-1 is the one LOAD-BEARING. The import is S1's (`4b5c0c1`); the report names "S3 …, with S1" as owners of the two remedies. |
| (a) "…so a fresh tree's axiom leg went RED" | PARTIAL (correction 3) | The mechanism holds (C3N-1 `[SRC]`). The RED is `[D]`, and no run observed it. |
| (a) "C3N-1's repair LANDED at `af702ab` (17:37:08 UTC; `9be090f` …)" | HELD | Run log: "pushed 17:37:08Z: af702ab". `9be090f`'s AxiomCheck imports `BsvScript`, `Bsvs.Trace`, `Bsvs.Corpus`, `Bsvs.Run`, `Bsvs.SelfTest`. |
| (a) leg `…171526…` "twenty-one legs GREEN in 95 s at `9594fa6`"; landing `…171939…` "(pins, cite and spec re-run locally …)" | HELD | Record: `9594fa6`, 95s, GREEN. The landing record has the three local lines at `9be090f`. Byte-identity of `9594fa6` and `af702ab` exits 0. |
| (a) "#32 5895430437 … (48 modules, 4,912 constants, 2,540 theorems, 0 axioms [X]) …, the S4b table's landed counts, … the `prevouts` refusal … corrects 5893037758's attribution"; "#38 5895432873" | HELD | The comment's items 1 to 3 and its second Correction. The figures are the repair record's 17:06 run, `[X local]`. |
| (b) "ON MAIN at `af702ab`: every S1 site of the lens and of re-lenses 1 and 2, and C3N-1's repair" | PARTIAL (correction 2) | B2N-3 is PARTIAL on main. |
| (b) "IN FLIGHT, pushed as `origin/lean-a-s8-r7` at `3084bb4` (18:09 UTC)" | HELD | The ref is `3084bb4`, committed 18:09:06Z; the push printed at 18:09:51Z (run log). Base `7e341ee`. |
| (b) "record `…174125-trust32-relens3-fixes-s1.md`, every disposition" | HELD | It has rows for B2N-3, C-13, and all 26 NEW findings. |
| (b) "`48ea7e0` holds S1's sites: …" (four items; "a probe named all five routes") | HELD; list incomplete (correction 11) | The diff. The record's probe row `[X local]` names an axiom, `run_cmd`, the attribute, the term `unsafe`, and `extern`. |
| (b) "`d922aac` holds the records and the Corrections appended to eleven earlier records" | HELD | Eleven earlier records, each `+N −0`, each gaining exactly one `**Correction.**`. |
| (b) "`3084bb4`: S2's patch for S1 applied (`VersionGateCheck.lean:310`: `script.cpp:215`); the rust and S4b companions re-cut" | HELD | The diff changes `214` to `215` at line 310. At the pin, 215 is `if (opcode > OP_16) return false;` `[SRC]`. Both `…-on-s2.patch.txt` files exist. |
| (b) "`make check-box` at `3084bb4`, started 18:10:01Z … my box shell pid 88971" | HELD (run log) | Leg log at 18:10:01Z: "the box shell's pid is 88971". The queue ticket's epoch is 18:10:01.65Z. |
| (b) "is waiting in the box leg lock's FIFO behind T5b's hold (taken 18:13:30Z)"; (d) "Round 4 waits only on the box leg lock's queue" | UNVERIFIABLE by git/REST | S1's ssh read at 18:28:31Z (run log, after the stamp) agrees: the holder is `tag=T5b … taken=2026-09-29T18:13:30Z`, and S1's ticket heads the queue. |
| (b) "Main has moved since the push: … (`41f9f67`, 18:12 UTC …) and … (`c54ee08`)" | HELD | `7e341ee..c54ee08` is exactly those two commits. |
| (b) "THE DONE-BAR … IS NOT MET" (unlanded, re-lens owed, patches open) | HELD | The branch is not on main; re-lens 3's PATCH-CORRECT rows. |
| (i) "`GIT_DIR=/nonexistent eval/bsvs` … deleted and re-cloned `…/c30ba59fba28/packages/mathlib`", 13:29–13:45 | HELD | `docs/records/20260929-140334-trust32-relens-fixes-s1.md:83–92`. |
| (i) "restored from the peer key under the lock, after S2's build had recompiled 723 modules" | HELD IN SUBSTANCE (correction 8) | Same record: 723 holds; the record names the key and the act differently. |
| (i) "the wrapper's guard (rounds 3 and 4) refuses one" | PARTIAL (correction 9) | The guard clears the variables rather than refusing them. |
| (ii) "`run_diff` of 09-23 wrote `+dirty` keys into my working copy of `corpus/crypto`. Restored; … `$CARGO_TARGET_DIR`" | HELD IN SUBSTANCE (correction 10) | Same record, `:95–101`. |
| (iii) "EXIT trap named relative paths after a `cd` … Reverted by hand at once" | HELD | `docs/records/20260929-140334-trust32-patch-s3-v2.md:45–46`. |
| (iv) "C3N-1 was on main from `c4c9be3` (16:19) to `af702ab` (17:37). No box leg saw it … old `Main.olean`. Round 3's walk figures (4,998, 2,543) came from a stale olean" | HELD | `import Bsvs.Main` is in `c4c9be3` and gone in `9be090f`. The window's only other box leg (`…162646…` at `ecd9f1d`) predates the import. The box leg at `7186987` read an old olean (C3N-1 `[X]`). The repair record's paragraph on the figures. |
| (v) "version-3 companions … carried no regenerated `spec/` pages … version 4 carries them … Corrections … appended to both v3 records" | HELD | `+++ b/spec/` files: v3 lean 0, v3 docs 0, S2 v3 0; v4 lean 7, v4 docs 7, S2 v4 4. "7 files differ" `[X local]`. `d922aac` appends to both v3 records. |
| (vi) "Two context compactions: 13:19:50Z, 969,329 to 12,225 …, and 17:11:15Z, 967,770 to 16,888 `[M]`" | HELD | `compact_boundary` at run-log lines 13289 and 16032, both `auto`; no other after 11:18Z. |
| (vi) "One account move by the wrapper at 17:42 UTC" | HELD | Line 16629, 17:42:07.677Z; the only move after 11:18Z. |
| (vi) "with no tool call in flight" | NOT HELD (correction 1) | A Bash call was in flight when the move happened. |
| (b)/(c) 1, 2: land round 4, the fourth re-lens, "re-checked … at the landing" | OWED (not a past claim) | Nothing to verify. |
| (c) 3: "`eval/README.md`'s 'at this tree … S3's pending patch' clauses" | HELD | `3084bb4:eval/README.md:122–123` and `:142`. |
| (c) 4: "printed by `tools/cite_check.py --propose` at `7a94db9`: 24 of its 56", and the 24 sites | HELD | Re-run here: 56 `near-miss:` lines. The 24 listed sites are exactly those under S1's `docs/OWNERS` globs (lean.md is a tie with S2). `7a94db9` is `48ea7e0`'s pre-rebase twin (patch-id `d1e79cb5…`), pushed on `origin/lean-a-s8-r6`. S1's own split in the run log (18:25:05Z): "S1: 24 … others: 32". |
| (c) 4: "They are outside #32's surface" | PARTIAL (correction 6) | Two of the 24 are A-11's re-cut sites. |
| (c) 4: "the other 32 are S2's and S3's pages" | PARTIAL (correction 7) | Two are on the shared state page. |
| (e) 1: the S3 v4 companions carry B-3 (`bad-tx-coinbase`), B-2's CLI half, CN-1, checker v4 (`WALK_SHA256`, char literals and interpolated strings, `tomllib`, refused words), the stamp gate (B-4, B3N-5), A3N-1, A3N-3, D3N-1; main-based rust or `…-rust-on-s2`; the cost | HELD | The v4 record and companions: lean (`plainIntegers`, `checkHeights`, the coinbase gate), docs (`PROVENANCE.md:141`), tools, rust (`stamp.rs`). `validation.cpp:601–602` and `1035–1036` at the pin `[SRC]`. |
| (e) 1: "main's latest is version 3 …, which lacks the spec pages (its **Correction.**)" | PARTIAL (correction 12) | That Correction is not on main. |
| (e) 2: S2 v4 carries B-1, B-4 and B3N-5, DESIGN §4.1 and §6, the eras row … "at `corpus/INDEX.md:12`" | HELD but the line (correction 13) | The s2-v4 record. |
| (e) 3: S4b v3 "(three rows)", the one-row cut, or `--propose --write`; the anchor "at `tests/ec_tests.rs:332`"; the D3N-4 Correction "carries here" | HELD | The s4b-v3 record and both companions. bsv-rs v0.3.30 `c7ff2c3` `tests/ec_tests.rs:332` is `fn test_rfc6979_vector_2_satoshi_nakamoto() {`. The round-3 record's appended item 5. |
| (e) 4: row 1 of `corpus/crypto/ecdsa-bsv-rs-0.3.30.jsonl`, "`88 01×8` and `87 01×7` (… valid, valid) and an overlong claim (… invalid)" | HELD | `lean/Test/CryptoCheck.lean:37–38` and `213–240`; `pubkey.cpp:48–60` `[SRC]`. |
[withheld at export: a sibling tree's line]
| (e) 6: "The cite, pins and spec legs read them (re-lens 3, A3N-5)" | PARTIAL (correction 4) | Only the cite leg reads them. |
| (f) "None … (never `make check-modal`). `tools/block.sh S1` at 2026-09-29 18:23:24 UTC lists 13 apps, none S1's" | HELD (run log) | No Modal invocation among S1's Bash calls after 11:18Z. The `block.sh` output at 18:23:24 (line 17360) lists 13 apps, none a spec app. |
| THE MACHINE: `uptime`, `git status -sb`, `df -h /`, "the stamp 2026-09-29T18:25:51Z" | HELD (run log) | One command at 18:25:50Z built the line from `date -u`, `uptime`, `git status -sb` and `df -h /`, and printed "appended … at 2026-09-29T18:25:51Z". 12/(12+32) = 27 %. |

## Corrections

1. **LOAD-BEARING (a claim).**
   - As it stands: "**One account move** by the wrapper at 17:42 UTC, with no tool call in flight."
   - Site: Named, not hidden, (vi).
   - What is wrong: the run log shows a Bash call in flight.
     - At line 16621, 17:41:59.819Z, tool_use `toolu_01R4Kg4fzgrxXeKRa6mRujXh` ("Run the v4 checker's parts over the real sources") was issued. No tool_result for that id exists anywhere in the log.
     - The move follows at 17:42:07Z: the `SessionStart:resume` hook (line 16627), then the wrapper's message (line 16629), which says "if a tool call was in flight, run it again".
     - The step ran again at 17:42:31Z (line 16642, "Run the v4 checker in memory over the tree's sources") and returned at 17:42:35Z.
     - S1's line at 17:42:23Z, "nothing was running at the time", was the slip.
   - Right value: "One account move by the wrapper at 17:42:07 UTC, with one tool call in flight: an in-memory run of the v4 checker over the tree's sources (17:41:59Z), lost with the old process and run again at 17:42:31Z" `[M]` (the run log, lines 16621, 16629, 16642). No record depends on it.

2. **LOAD-BEARING (a state claim).**
   - As it stands: "**ON MAIN at `af702ab`:** every S1 site of the lens and of re-lenses 1 and 2, and C3N-1's repair."
   - Site: (b), bullet 1.
   - What is wrong: re-lens 3 part B judged B2N-3 PARTIAL at `c4c9be3`. B2N-3 is a re-lens-2 finding at S1's `lean/Bsvs/Corpus.lean`, and two parts of it were still open:
     - `readEntries`'s docstring still read "a refusal names the line, and the entry's `id`";
     - a `prevouts` that is not an array was refused as a bare "array expected".
   - `lean/Bsvs/Corpus.lean` is identical at `c4c9be3` and `af702ab` (`git diff` is empty). Both remainders are fixed only in round 4's `48ea7e0` (`.mapError ("prevouts: " ++ ·)` and the re-cut docstring), which is in flight.
   - Right value: "ON MAIN at `af702ab`: every S1 site of the lens and of re-lens 1; those of re-lens 2 except B2N-3's two remainders, which round 4 carries (`48ea7e0`); and C3N-1's repair" `[M]` (`docs/audit/2026-09-29-lens32-trust-relens3-partB-by-S1.md`, B2N-3's row).

3. **LOAD-BEARING (a label).**
   - As it stands: "The round-3 `import Bsvs.Main` read an olean only `lake build bsvs` writes, so a fresh tree's axiom leg went RED."
   - Site: (a), the Re-lens 3 bullet.
   - What is wrong: "went RED" reports a failure that was observed. C3N-1 derives it and labels it `[D]` ("stays RED [D]"; "No Modal run has yet checked a tree with the import").
     - No record or run shows the pre-repair `AxiomCheck.lean` failing. The repair's test at 17:06Z ran only the repaired imports (exit 0).
     - Every leg that carried the import passed on an olean an earlier run had left: the box leg `…155509…` at `7186987`, and the Studio leg `…170743…` at `c81b822`.
   - Right value: "…so on a fresh tree (every Modal bake, a new worktree) the axiom leg would go RED `[D]` (C3N-1, from `lean/lakefile.toml:7` and Lake's build rules `[SRC]`); no run met such a tree."
   - The same past tense stands at `lean/AxiomCheck.lean:837` (at `af702ab`, and carried into `48ea7e0`), `docs/records/20260929-170732-trust32-axiomcheck-unbreak-s1.md:8`, `docs/records/20260929-171939-landing-trust32-unbreak-s1.txt:7`, and #32 5895430437.

4. **LOAD-BEARING (a claim; the premise of the ruling asked).**
   - As it stands: "The cite, pins and spec legs read them (re-lens 3, A3N-5); my landings re-run those three locally when a rebase brings docs."
   - Site: (e), ask 6.
   - What is wrong: A3N-5 names only the cite leg (`tools/cite_check.py:58–59`, `:62`). At `af702ab`:
     - `tools/specgen.py` (the spec leg) opens only `lean/` sources, `corpus/INDEX.md`, the corpus `.jsonl` files and `corpus/witnesses/manifest.json`. It reads no `docs/` page.
     - `tools/check_pins.py` (the pins leg) reads only `docs/PROVENANCE.md` from `docs/`, and that page is already on the byte-identity list.
   - Right value: "The cite leg reads every `.md` under `docs/` outside the history prefixes (`tools/cite_check.py:58–62`; re-lens 3, A3N-5). The pins leg reads `docs/PROVENANCE.md` alone, already on the list, and the spec leg reads no `docs/` page" `[X]` (both tools read at `af702ab`).
   - The same premise stands at `docs/records/20260929-171939-landing-trust32-unbreak-s1.txt:15` and `:24`. Re-running all three legs does no harm; the ruling is only about the cite leg's inputs.

5. **COSMETIC.**
   - As it stands: "It covers everything since my last one (2026-09-29T11:18:07Z): the rest of sitting 8 (…)."
   - Site: Answering, item (2).
   - What is wrong: the 11:18:07Z block (`f83deec`) is sitting 7's END BLOCK. Sitting 8's paste (`harness.md:656`, 11:21 UTC) came after it.
   - Right value: "all of sitting 8" `[M]` (`docs/lanes/lean.md:531`; `f83deec`'s subject).

6. **COSMETIC.**
   - As it stands: "They are outside #32's surface."
   - Site: (c), item 4.
   - What is wrong: `lean/BsvScript/Machine.lean:24` and `:25` are A-11's sites. This lens's round 1 re-cut them (`c68b3b2`; the fix record's A-11 row names "`getOpTail`'s `script.h:171`, `174`, …"). Both hold at the pin: `script.h:171` is `unsigned int opcode = *pc++;` and `:174` is `if (opcode <= OP_PUSHDATA4) {` `[SRC]`. The proposer flags them only because `OP_PUSHDATA4` and `OP_PUSHDATA1` sit a few lines away.
   - Right value: "22 of them are outside #32's surface; `Machine.lean:24` and `:25` are A-11's re-cut sites and hold at the pin `[SRC]` (the proposer's neighbour heuristic)."

7. **COSMETIC.**
   - As it stands: "the other 32 are S2's and S3's pages."
   - Site: (c), item 4.
   - What is wrong, by `docs/OWNERS` at `7a94db9` (the longest glob wins):
     - 15 are on S2's pages: `Properties/Eras.lean` 3, `Sighash.lean` 4, `TxRules.lean` 3, `Test/ErasCheck.lean` 3, and `docs/DESIGN.md` 2 (a tie with S3 and S4b).
     - 15 are on S3's: `docs/PARAMETERS.md` 11, `docs/CONFORMANCE-2026-09-27.md` 3 (a tie with S4b), and `lean/Bsvs/Run.lean` 1.
     - 2 are on the shared state page: `docs/STATE-OF-THE-WORLD.md:42` and `:59` (OWNERS `shared`).
     - Among S1's 24, `docs/lanes/lean.md:177` is text inside S2's END BLOCK of 2026-09-27T03:14:57Z, on the page S1 and S2 tie.
   - Right value: "the other 32: 15 on S2's pages, 15 on S3's, 2 on the shared state page" `[X]` (the proposer at `7a94db9`; `docs/OWNERS`).

8. **COSMETIC.**
   - As it stands: "The repair: restored from the peer key under the lock, after S2's build had recompiled 723 modules."
   - Site: Named, not hidden, (i).
[withheld at export: a sibling tree's line]
   - Right value: "completed from the key `f27aa7e05ec9` (the same Mathlib `5ed2965`) by APFS clones under the Lean lock, 13:44:28–13:45:18, after S2's build had recompiled 723 modules" `[M]` (that record).

9. **COSMETIC.**
   - As it stands: "the wrapper's guard (rounds 3 and 4) refuses one."
   - Site: Named, not hidden, (i).
   - What is wrong: round 3's guard clears every `GIT_*` variable before Lake runs (5894190219). Round 4 unsets them by name (`"${!GIT_@}"`) and exits 3 only if one remains (`48ea7e0`). Neither refuses a caller's git override; both remove it.
   - Right value: "the wrapper's guard clears every `GIT_*` variable before any Lake run (round 3; by name in round 4, which exits 3 if one survives)" `[M]` (5894190219; `48ea7e0`).

10. **COSMETIC.**
    - As it stands: "`harness/target/release/run_diff` of 09-23 wrote `+dirty` keys into my working copy of `corpus/crypto`."
    - Site: Named, not hidden, (ii).
    - What is wrong: it also re-stamped `corpus/witnesses/manifest.json`, which is outside `corpus/crypto` (`…-140334-trust32-relens-fixes-s1.md:95–101`).
    - Right value: "…wrote `spec@abc1234+dirty` keys into the 84 entries of `corpus/crypto/cases.jsonl` and re-stamped `corpus/crypto/cases-manifest.json` and `corpus/witnesses/manifest.json` in my working copy; restored at 14:01:57" `[M]` (that record).

11. **COSMETIC.**
    - As it stands: "`48ea7e0` holds S1's sites:", followed by four items.
    - Site: (b), IN FLIGHT.
    - What is wrong: `48ea7e0` also carries three more S1 sites that the list leaves out:
      - `lean/Test/OpNames.lean:6` (`core_read.cpp:20–35`, A3N-1);
      - `eval/README.md` (B3N-2, B3N-4, B3N-6);
      - the state page's row 78 (A3N-4).
    - Right value: the four items plus those three `[M]` (`git show --stat 48ea7e0`; the round-4 record's rows).

12. **COSMETIC.**
    - As it stands: "Until round 4 lands, main's latest is version 3 (`docs/records/20260929-151244-trust32-patch-s3-v3.md`), which lacks the spec pages (its **Correction.**)."
    - Site: (e), ask 1.
    - What is wrong: `d922aac` appends that record's Correction on the missing pages (its item 4), so the Correction exists only on `origin/lean-a-s8-r7`. Main's copy carries none.
    - Right value: "(its **Correction.**, item 4, on `origin/lean-a-s8-r7` at `d922aac` until round 4 lands)" `[M]`.

13. **COSMETIC.**
    - As it stands: "the eras row, whose INDEX hunk S2 re-cuts at `corpus/INDEX.md:12` after its own code companion for S3."
    - Site: (e), ask 2.
    - What is wrong: `corpus/INDEX.md:12` is the stack row, at `7a94db9` and on main. The eras row is line 15. Line 12 is where the `…-s2-v4.patch.txt` hunk `@@ -12,7 +12,7 @@` starts, with three context lines. The s2-v4 record carries the same ":12".
    - Right value: "at `corpus/INDEX.md:15` (the eras row; the hunk `@@ -12,7`)" `[X]` (`git show 7a94db9:corpus/INDEX.md`).
