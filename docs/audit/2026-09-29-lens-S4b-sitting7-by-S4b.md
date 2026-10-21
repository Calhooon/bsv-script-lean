# The lens on S4b's END BLOCK of 2026-09-29T20:54:36Z (sitting 7), filed by S4b

S4b's own lens (D127, one per block): a fresh-context, read-only general-purpose agent on Opus 5.5, the model the live glass
named at its spawn (`~/.claude-usage/relay-glass.json`: `"glass": true`, read 2026-09-29T21:40:27Z). A first spawn at 20:57Z
died at its start on the account's session limit (the run was parked 38 minutes and resumed on another account at 21:40Z, the
wrapper's move); this one was spawned after the move and reported after about 32 minutes. Its brief is the paste's words
("verify every claim against origin/main and the tracker by REST; HELD / NOT HELD / PARTIAL / UNVERIFIABLE per claim with the
evidence; re-derive every number; the corrections as a numbered list with the sentence, the site and the right value with its
label"), with the sites of the branch, the scratch copy and the tracker, and D135's rule for its own report. The report follows
verbatim. How each correction landed is in the block's lens line and the notes at the end of this file.

---

# Lens on S4b's END BLOCK of 2026-09-29T20:54:36Z (read-only)

**The lens:** Opus 5.5 (`claude-opus-5-5`), fresh context, read-only. I wrote no files, made no commits, pushes or tracker writes, and ran nothing on the box, on Modal, or as a build. What I did do:
- Read `git show` output from the clone.
- Made `gh api` GETs on #43, #51 and #52.
- Read the upstream clones: go-sdk (v1.5.2, v1.7.0), ts-stack (`b3155fa2e`, `5a4053223`) and bitcoin-sv (`879fc8b42`).
- Read the scratch copy `/tmp/s4b-s7/box` (all 76 files match its `SHA256SUMS`, sha `2b38af82845d5658…`), the Studio logs, the saved public reads, and the run's own transcript.
- Ran the record's `…-compare.py.txt` read-only on this worktree (with `PYTHONDONTWRITEBYTECODE=1`, output to stdout only). Its `corpus/`, `tools/conformance.py` and `harness/rules/` are byte-equal to main's and to the landing branch's.

Two substitutions:
- **`git apply --check`** (it needs a tree) is replaced by an in-memory check that every hunk's preimage matches, and an in-memory replay.
- **Registry and proxy reads** are not repeated live. I used the saved bodies in `/tmp/s4b-s7/reads` and the Go module cache instead.

**The tree:** `origin/main` moved four times while I read: `c4191cc` → `4b68458` → `88b328a` → `5acefcb`. The block's text has not changed since `b73fc49`. At `5acefcb` it sits at `docs/lanes/harness.md:1331–1405`, and the line numbers below are those.

**Verdict: HELD IN SUBSTANCE.**
- Every figure, sha, time and tracker id in the block was re-derived from the files and holds.
- Four of the block's claims are PARTIAL: the go-sdk range count, ask 1's command, ask 2's scope, and the "withheld" sentence for the six undecided entries.
- D135 holds in the block. In the branch's record it holds only at the level of class labels.
- 12 corrections: 8 LOAD-BEARING, 4 COSMETIC.

This report names no entry ids at all. Entries of private classes, and the six withheld go-sdk entries, are given by count only.

## Claims

| # | Claim (site) | Verdict | Evidence |
|---|---|---|---|
| C1 | Run `e98395d7`, Opus 5.5 at effort max, begun 18:02:05Z (1333) | HELD | `~/.claude-usage/session-index.jsonl`: run e98395d7…, `"model": "claude-opus-5-5"`, t=1790704925.87, and `date -u -r` gives 18:02:05Z. `7e341ee`'s HANDOFF note: "Opus 5.5 at effort max, opened at 18:02:05 UTC" |
| C2 | The parent's paste of 18:01 UTC (1333) | HELD | `2f6b9c6` was committed at 18:01:06Z; the paste's own heading stamps 17:59 UTC |
| C3 | `harness-b-repin` was cut at `7e341ee` and `harness-b-cite` at `9a43a89` (1333) | HELD | `git log --format='%h %p'`: `a849e99`'s parent is `7e341ee`; `d23246d`'s parent is `9a43a89` |
| C4 | Nothing classified, nothing under `harness/rules/` or `corpus/`, no `--record`, gobdk column untouched (1334) | HELD | `git diff --name-only` over `7e341ee..harness-b-repin`, `9a43a89..harness-b-sdk-repin` and `ffe0a75..b889a2c` on `corpus harness/rules harness/engines/gobdk`: 0 paths each. `…-rerun.zsh.txt:62–79` has no `--record` and loops `tssdk gosdk` only. `identify.py` writes to stdout only |
| C5 | No compaction, no memory file (1335) | HELD | The transcript (1,948 lines, to 21:40:50Z) has 0 `"type":"system"` records; its two `compact_boundary` strings are other windows' text inside tool results. No memory file newer than 18:16Z in any profile |
| C6 | Network list, no Modal (1336) | HELD, list incomplete | Transcript: proxy.golang.org, sum.golang.org and registry.npmjs.org; one `gh api repos/bsv-blockchain/go-sdk/releases/latest` (18:25:22Z); tracker POSTs; ssh to the box; 0 `modal` commands. Also 12 `git fetch` and 8 `git push` to our own origin, which the list leaves out (correction 12) |
| C7 | Item (1) is on `harness-b-sdk-repin` at `8c545ca`, not landed (1339, 1342) | HELD | `git merge-base --is-ancestor 8c545ca origin/main` is false; main's `harness/src/engines.rs:19–20` still reads v1.5.2 / 2.8.0 |
| C8 | ts-sdk agrees on 13,766 and 13,756 of 13,769 (was 13,662 and 12,221); closes 13 classes; 0 unexplained; 29 runs outside the table, 5 new messages (1339) | HELD | Summed independently from main's `corpus/witnesses/ts-sdk/manifest.json` and the scratch manifest. `unknown_messages` total 29 (6+5+10+8) over 5 distinct messages; `unexplained` rows 0 |
| C9 | go-sdk changes no verdict on eight corpora; on gen, 13 per column go to the spec's verdict and 6 go undecided (1339, 1366) | HELD | Per entry, old side from the corpus's `go-sdk@v1.5.2` keys, new side from dumps + spec files + `identify.jsonl`: 0 moves on 8 corpora. On gen, each column: invalid→valid 13, invalid→undecided 6 |
| C10 | Five commits; the first three are patch-identical twins of `a849e99`, `e4a7bcd`, `f5e3c13` (1343–1344) | HELD | `git patch-id --stable`: `3101a5a0…`, `28cac425…` and `5fbc04b9…` each appear on both sides |
| C11 | The record and its seven companions (1345) | HELD | `git show --stat 8c545ca` lists all 8 files |
| C12 | Patch sha `6dc52e9a…`, 3 files, +13 −9; `apply --check` clean at `7e341ee` and at `38cae0d` (1346) | HELD | `shasum -a 256` = `6dc52e9a3f3b925e…cf9a`. `git apply --numstat`: 3/3, 5/5, 5/1. All 4 hunk preimages match exactly at `7e341ee` and `38cae0d`, and still at `5acefcb` |
| C13 | The public reads: v1.7.0 = `338b6a6d…` with its two sums; npm 2.8.10 published 2026-09-27T14:23:16Z with integrity `0KJxu772…`, `latest`; source `5a4053223692…` by the first-commit method; go-sdk releases/latest (1347) | HELD | Module cache `v1.7.0.info`: Time 16:12:38Z, Hash `338b6a6d…`; ziphash equals go.sum's `h1:rdViau4…`. Saved npm body (`eedcf7c3bbd66404…`): 2.8.10 at 14:23:16.561Z, `dist-tags.latest` 2.8.10, integrity and shasum as quoted. ts-stack `5a4053223` says 2.8.10 and its parent says 2.8.9, committed 14:03:16Z |
| C14 | "Two go-sdk ranges are re-cut to the functions' own lines" (1348) | PARTIAL | `34ba583` re-cuts **three**: `thread.go` `apply` 250–330 → 250–386, and `operations.go`'s 2336–2400 and 2429–2560 (correction 3) |
| C15 | go-sdk's signature hash and v1.7.0's two additions are described; ts-sdk ranges re-cited (1348) | HELD | At v1.7.0: thread.go 250/386, 285–291, 523–535, 541–547; signaturehash.go is 451 lines (362 at v1.5.2), usesBip143Preimage 26–30, the choice at 69, calcInputPreimageLegacy 300–432; `sighash/flag.go:33` `Chronicle Flag = 0x20`; operations.go 1994–1997, 2008, 2285. At `5a4053223`: Spend.ts is 2,321 lines, constructor 261–317, `#isRelaxed` 319–321, `validate` 2026–2052, `validateJavaScript` 2058–2109 `[SRC]` |
| C16 | Two ts-sdk sentences were falsified and re-cut, the old ones gone (1348) | HELD | `b3155fa2e` reads 16 names (15 literals plus P2SH, GENESIS among them); MINIMALIF (1091) and NULLFAIL (1613, 1737) by name only. `5a4053223` reads 17 names; `#enforceNonMalleability` is at 343–345 and gates 349–372, 1175, 1711 and 1845. PROVENANCE at `8c545ca` keeps neither present-tense sentence; 2.8.0 appears only as a dated clause `[SRC]` |
| C17 | Re-run: one ssh session 18:22:03Z–19:37:12Z; Lean slot 2 18:22:04Z–18:22:48Z; leg lock taken 18:38:48Z after 960 s (`BOX_LEG_WAIT` 7200), released 19:37:12Z; nine corpora, `spec@a849e99`, gen at 60 s; patch reverted; ssh rc 0 (1349–1352) | HELD | `/tmp/s4b-s7/rerun.log` has every quoted line. `rerun.zsh.txt:25` sets `BOX_LEG_WAIT=7200` and `:74` sets `T=60` on gen only. Committed gen `adapter_timeout_s` is 60 in both SDK manifests. The log ends "git status --porcelain now 0 lines", "ssh rc 0" |
| C18 | Identification pass: lock 20:05:47Z after 1,380 s, released 20:08:34Z, rc 0; names 29 + 12 runs (1353) | HELD | `identify.log`. `identify.jsonl` has 48 lines = 2 banners + 5 corpus markers + 29 ts-sdk runs + 12 go-sdk runs (6 ids × 2 columns); sha `ff44ebe5…` as recorded |
| C19 | The slip: first launch stopped by `kill -TERM 124` before it ran anything (1353) | HELD | Transcript: TaskStop at 19:42:08Z; the ssh `kill -TERM 124` at 19:42:38Z returns "124 gone" at 19:42:40Z. `identify.log.first-launch` holds only its two start lines |
| C20 | Flag words equal the committed record's; the spec's verdicts equal the recorded spec columns (1354) | HELD | Words equal on 9/9 corpora for both engines. Verdict and code equal on 13,257 entries × 2 columns (bytes, 512 entries, has no spec key). The compare script reproduces 472 of 477 lines of the record's §6; the other 5 are its headings at another level |
| C21 | Legs at `515c9c1` with the patch: pins 75/0; cite 7,679 / 1,936 / MOVED 0 / unanchored 23; `cargo test` rc 0, 21 passed; cite GREEN without the patch (1355) | HELD | `…-legs.txt:232`, `:239–240`, `:243–244`; `:246–268` sums to 16+2+3 = 21 passed in 22 suites |
| C22 | Tracker comment ids #51 `5897916282`, #52 `5897916561`, #43 `5898680507` | HELD | `gh api …/issues/{51,52,43}/comments`: created 20:14:12Z, 20:14:13Z and 20:54:19Z |
| C23 | Item (2): `c870006` (was `d23246d`), 4 rows written, 1 orphan dropped, 1 held, 1,385 rows (1357) | HELD | The two are patch-id twins (`0a39aca2…`). The diff adds 4 rows, removes 1 and adds 1 HELD key; rows go 1,382 → 1,385 |
| C24 | "The leg GREEN: 2,073 … unanchored 3 (the held), orphan rows 0" (1357) | HELD at `d23246d`; PARTIAL as a statement of the landed tree | `/tmp/s4b-s7/cite-item2.txt` gives 2,073 / 0 / 3 / 0. At `c870006` the landing record reads unanchored 4 (correction 9) |
| C25 | check-box at `d23246d` GREEN in 124 s; lock 20:49:36Z after 1,629 s, released 20:51:41Z; landing rule; pins/cite/spec GREEN at `c870006` (1357) | HELD | `20260929-204937-make-check-box.txt:2–5`; `checkbox-cite.log`. I re-ran `git diff --quiet d23246d c870006 -- . ':!HANDOFF.md' ':!docs/lanes' ':!docs/records' ':!docs/audit'`: rc 0. `20260929-205320-cite-landing-s4b.txt` |
| C26 | ts-sdk state figures (1361) | HELD | default/spec-mempool 13,609 → 13,653; default/spec 13,006 → 13,047; witnesses 84 → 34; aborts 104 (90+6+8) → 2 |
| C27 | 13 classes empty; every move goes to the spec's verdict except five, all in `limits.maxscriptnumlength.policy`, because 2.8.10 enforces consensus widths (1362) | HELD | Non-empty classes go 23 → 10. The five AWAY moves (1 on eras, 4 on gen, all in the mempool run) are each dumped in spec-mempool under that class, where the spec says `SCRIPT_ERR_SCRIPTNUM_OVERFLOW`. Spend.ts:395–403 and 27–28 at `5a4053223` (750,000 / 32,000,000); policy.h:156 is 10 × 1,000 at the pin `[SRC]` |
| C28 | 29 runs carry 5 messages outside `tssdk_codes.rs`, each read at the pin (1363) | HELD | main's `tssdk_codes.rs` has no row for any of the five (its locktime row, :70, is CSV's). Spend.ts 896, 904, 1059, 1085, 1942; interpreter.cpp 552, 557, 1749, 1807–1810, 1819–1822; script_num.cpp 311–312 `[SRC]` |
| C29 | go-sdk figures: 13,710 → 13,723 and 12,259 → 12,272, all on gen; witnesses 30 = 30; aborts 10 = 10; the same 5 timeouts; 3 decided at v1.5.2 (1365) | HELD | Manifests. The 5 undecided ids at v1.5.2 equal `identify.jsonl`'s go-sdk `skip` list. Timeouts go 8 (3 decided) → 5 (0) |
| C30 | 13 + 6 per column; private sums 27 → 8 and 34 → 15 (1366) | HELD | On gen exactly one withheld class goes 20 → 1 in each column; every other row is unchanged |
| C31 | Six entries (12 runs) end with `non-engine-error`; main counts them as undecided, never witnesses; S2's A-B4 reads them as aborts (1367) | HELD | `harness/engines/go/main.go:178`; `gosdk_codes.rs:103–107`; `run_engine.rs:451–455`; S2's v2 patch at `:10–22` |
| C32 | The six's entries and mechanism "stay withheld, named only in the box's scratch results" (1368) | PARTIAL | No page labels the six as go-sdk's undecided entries. But the ids are not withheld as ids (correction 4), and the gen dump and log that the record points to name none of them (correction 6) |
| C33 | The landing branch holds the report's 20 citations (1369) | HELD | `515c9c1`'s HELD has 4 keys; the 20 MOVED citations are at `…-legs.txt:84–103` |
| C34 | node_modules state at 18:58:17Z–18:58:18Z; box worktree back to 2.8.0 at 20:13Z (1370) | HELD for the Studio; UNVERIFIABLE for the box at 18:58Z | Today on the Studio: six worktrees hold 2.8.0 (installed 2026-09-23); `spec-harness-b` holds 2.8.10 (installed 18:10:49Z). Transcript at 20:13:12Z: `ssh box … make tssdk-install` at `d23246d`; the leg's banner then reads `@bsv/sdk 2.8.0` |
| C35 | (c) owed and (d) blocked (1372–1377) | HELD | The record §7; the paste `2f6b9c6` parks A16 on the run of `35fc7bc`, and #41/#28 on A2 |
| C36 | Ask 1: the rebase drops `d23246d`; the patch; five rows; 57 min (1381–1387) | HELD | Patch-id twin. The branch's 5 commits replay onto `5acefcb` in memory with every hunk found. gosdk gen wall is 3,444.7 s |
| C37 | Ask 1's re-record command (1384) | PARTIAL | `Makefile:152–159` loops `gosdk tssdk gobdk` (correction 2) |
| C38 | Ask 1's purpose "done-bars 2 to 4" (1388) | PARTIAL | #51/#52 done-bar 1 ends "and the pins leg is GREEN", which main reaches only with the patch (correction 11) |
| C39 | Ask 2: v2 no longer applies to package.json, its lock and runner.mjs on this branch (1390–1391) | PARTIAL | Of the patch's 68 hunks, on `harness-b-sdk-repin`: package.json 0/1, lock 0/1, runner.mjs 2/3, **and `tools/cite_check.py` 47/53**. On main since `c870006`: cite_check.py 50/53 (correction 1) |
| C40 | Ask 3 (1395–1396) | HELD (a consistent judgment) | All six left the one withheld class that fell 20 → 1 |
| C41 | $0, no Modal (1400) | HELD | No `modal` command in the transcript |
| C42 | `uptime`, `git status`, `df` lines (1402–1404) | HELD / UNVERIFIABLE | Boot time 2026-09-22T20:58:42Z plus 6 d 23:56 gives 20:54Z; the same load triple appears in `20260929-205547-endblock-landing-s4b.txt`. `git status` and `df` are point-in-time |
| C43 | D135 in the block | HELD | The block names five entry ids. None is an entry or witness of a private class at either pin (checked against the dumps' private-class entries and v1.5.2's go-sdk divergences). No private class is named |
| C44 | D135 in the branch's record: "its entries are never listed" | PARTIAL | Correction 5 |
| C45 | Rule 12: this sitting's records indexed | NOT HELD | Correction 8 |

## CORRECTIONS

1. **LOAD-BEARING.** *"S2's lens-3 patch v2 for S4b (…, against `585e43e`) no longer applies to `harness/engines/ts/package.json`, its lock and `runner.mjs` on this branch. … Or land it first, and S4b rebases this branch."* (1390–1391)
   - **The right value:** on this branch it also fails on `tools/cite_check.py` (6 of 53 hunks).
   - It no longer applies on `main` either, since S4b's own `c870006`: `tools/cite_check.py` fails 3 of 53 hunks, at old lines 1079, 1096 and 1183, the rows next to the four it wrote.
   - So either order needs its `cite_check.py` hunks re-cut. `[X]` (in-memory preimage check)
   - #43's comment `5898680507` says the same three files on `harness-b-repin`, which is correct for that branch only.

2. **LOAD-BEARING.** *"Re-record both SDK columns at the new pins (`make enginesdiff ENGINE_RECORD=--record`, gen at `ENGINE_ADAPTER_TIMEOUT_S=60`, the committed wall)."* (1384)
   - `make enginesdiff` runs `gosdk tssdk gobdk` on every corpus (`Makefile:152–159`), so `--record` would re-record the gobdk column too.
   - `ENGINE_ADAPTER_TIMEOUT_S` is run_engine's environment variable. A make command-line variable is exported to every recipe, so it would take one value for the whole loop.
   - The committed walls are 60 s on gen for the two SDKs, 120 s on arith, stack and tx, and 120 s everywhere for gobdk.
   - **The right value:** run `run_engine --engine gosdk|tssdk … --record` per corpus, with 60 s on gen only, as `…-rerun.zsh.txt:66–79` did. `[X]`

3. **LOAD-BEARING.** *"Two go-sdk ranges are re-cut to the functions' own lines."* (1348)
   - **The right value: three.** `thread.go` `apply` 250–330 → 250–386; `operations.go` 2336–2400 → 2331–2393 (four functions); and 2429–2560 → 2426–2577. `[SRC]` go-sdk v1.7.0

4. **LOAD-BEARING (D135).** *"the entries and the mechanism stay withheld, named only in the box's scratch results."* (1368)
   - **The right value:** the six are identified as these runs only in the scratch `identify.jsonl` (on the box, and in the Studio's copy under `/tmp/s4b-s7/box`).
   - Their ids are not withheld as ids: 5 of the 6 appear in the landing branch's record under ts-sdk labels; 4 appear on main's non-record pages and all 6 in main's records, all under other labels. `[X]`
   - Either qualify the sentence, or take those ids out of the record before the landing. That is the parent's or the owner's call.

5. **LOAD-BEARING (D135).** In the branch's `docs/records/20260929-181617-repin-sdk-s4b.md`, the §6 preamble *"… is summed per corpus and column as `withheld (D135)`, and its entries are never listed"* and the C′ heading's "never listed".
   - **The right value:** the class rows are never named, but the id lists in §6 C′, §6 E and §7.4 name 96 distinct entries that belong to one of the nine private classes at one pin or the other. Each is listed under a ts-sdk public label.
   - Among them are 17 of the private classes' 24 witnesses. All 17 are already named on main's non-record pages under public labels.
   - So redaction happens per (engine, class) label, as `tools/conformance.py` applies it, not per id. `[X]`
   - The split per engine and per section is reproducible by intersecting the record's ids with the scratch dumps' private-class entries. I leave it out of this report under D135.

6. **LOAD-BEARING.** Record §7.9: *"(`~/bsv/scratch-s4b-s7/identify.jsonl`, and the gen dump and log)"*.
   - **The right value:** only `identify.jsonl` names the six. The go-sdk gen dump (37 lines) and its log name none of them; the log only counts the runs by code. `[X]`

7. **LOAD-BEARING.** The branch's `docs/records/20260929-181617-repin-sdk-patch-s4b.md:5`: *"the parent lands S4b's branch `harness-b-repin` with this patch"*.
   - **The right value:** `harness-b-sdk-repin` at `8c545ca`, as the record's head and the block say. `harness-b-repin` lacks `515c9c1` and the record. `[X]`

8. **LOAD-BEARING (rule 12, an omission).** None of this sitting's records has a row in `docs/records/README.md`.
   - On main at `5acefcb`, 0 rows each for `20260929-204937-make-check-box.txt`, `20260929-205320-cite-landing-s4b.txt` and `20260929-205547-endblock-landing-s4b.txt`.
   - On the branch, 0 rows for the ten `20260929-181617-repin-sdk-*` files.
   - S2 and S3 index theirs in the same commit (for example `1d9b578`, `88b328a`). **The right value:** one row each. `[X]`

9. **COSMETIC.** *"The leg GREEN: 2,073 anchored and holding, MOVED 0, unanchored 3 (the held), orphan rows 0."* (1357)
   - **The right value:** at `d23246d`, with "the held" meaning the table's three HELD entries.
   - At the landed `c870006` the leg reads unanchored 4. The fourth is `docs/lanes/lean.md:613`'s citation, which landed after the write. `[X]`

10. **COSMETIC.** *"meets 29 codes outside `tssdk_codes.rs` (5 new messages)"* (1339).
    - **The right value:** "meets 29 runs whose 2.8.10 messages (5 new) match no row of `tssdk_codes.rs`". `[X]`

11. **COSMETIC.** *"#51 and #52's done-bars 2 to 4"* (1388).
    - **The right value:** "done-bars 1 to 4". Bar 1's GREEN pins leg reaches main only with the patch. `[X]` (issue bodies)

12. **COSMETIC.** The network bullet (1336) leaves out `git fetch` and `git push` to our own origin.
    - **The right value:** add them (12 fetches and 8 pushes in the run's transcript). `[X]`

## Notes (no correction)

- **S4b's own Studio worktree** (`spec-harness-b`) still holds @bsv/sdk 2.8.10 while on a 2.8.0 tree. A `make check-local` there would stop at the adapter's banner until `make tssdk-install` is run.
- **The adapter's error text for the six** is quoted by the record (§5, §7.9) and by the #51 comment, though the block withholds it. That is for S4b's own D135 judgment of whether it counts as "the mechanism".
- **Replay onto the current main:** the patch and the branch's five commits apply cleanly onto `5acefcb` (in memory).

---

## How S4b landed the corrections (D128: the load-bearing at their sites, the original sentences gone; the cosmetic listed here)

- **1:** the block's ask 2 re-cut at its site, naming `tools/cite_check.py` on the branch (6 of 53 hunks) and on `main` since
  `c870006` (3 of 53); a **Correction.** on #43 for comment `5898680507`.
- **2:** the block's ask 1 re-cut to the per-corpus `run_engine … --record` for the two SDK columns, 60 s on gen only.
- **3:** the block's "Two go-sdk ranges" re-cut to three, each named.
- **4:** the block's (b) sentence re-cut: the six are identified as these runs only in `identify.jsonl`; their ids appear on
  other pages under other engines' labels. The branch's record §7.9 re-cut the same way. Taking ids out of the record is not
  done: D135 as `tools/conformance.py` applies it redacts per (engine, class) label (correction 5), and the call beyond that
  is the parent's or the owner's.
- **5:** the branch's record §6 preamble and C′ heading re-cut to the per-label rule.
- **6:** the branch's record §7.9 names `identify.jsonl` alone.
- **7:** the branch's patch record names `harness-b-sdk-repin`.
- **8:** `docs/records/README.md` gains a row for each of main's three records; the branch's README gains rows for its records
  (the record with its companions, the patch record with its companion).
- **9 to 12, COSMETIC:** listed here, not fixed (D128).
- **The notes:** S4b's Studio worktree was re-installed at `main`'s lock after the lens (the block's (b) names the time). On
  "the error text": S4b's D135 judgment is that the SDK's generic error string is not the mechanism (the code path, the source
  lines and the shape of the input), which stays withheld.
