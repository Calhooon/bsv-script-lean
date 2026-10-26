[export: 3 lines withheld by tools/export_public.py, the sibling trees' lines; the original is in the private history]
<!-- S2'S OWN LENS ON ITS SITTING-3 END BLOCK (LANE F, set 4 sitting 3; S2 the Lean B sub-agent; 2026-09-27). A fresh-context, READ-ONLY lens: a Claude Code subagent of S2's session on Opus 5.5 (the Agent tool, general-purpose, model opus: the paste's rule (6) names fable, and D118 runs the lanes on Opus 5.5 until Fable returns), launched 13:45 UTC, its wall 1,613 s [M] (the tool's usage line: 1,613,367 ms, 178 tool uses). Its brief: the paste's rule (6) verbatim ("verify every claim against origin/main and the tracker by REST; HELD / NOT HELD / PARTIAL / UNVERIFIABLE per claim with the evidence; re-derive every number; the corrections as a numbered list with the sentence, the site and the right value with its label") with the read-only rules and the sites, read against origin/main e40d3c4 and origin/lean-b-repin 7f77b9a. The report below is verbatim as the lens returned it (the one character-level change: its "<the 14 paths>" arrived HTML-escaped). Its corrections are all S2's and landed as the block's lens paragraph lists them: 1 to 3 and 6 to 8 on docs/lanes/lean.md, 1 and 8 in the decoder record's appended Correction, 4 on the branch (the re-pin record's appended Correction at d651009) and on #35, 5 on #35, 1 on #24; the must-knows: the cited twins on fallback/s2-set4-sitting3-* branches, "once" re-cut in Tx.lean at fe2223e, the rule-17 and lock disclosures in the block. Its own slip (a Lean process started by "tools/axiom_check.py --help" in its scratch archive, failed at once, nothing written outside its scratch directory) is disclosed in its last must-know. -->

**HELD IN SUBSTANCE.** Every sha, comment id, count, wall, byte size, tree hash, warning tally, instrument count and meter figure checks out against the repo, the pin, the tracker and the meter. The corrections are all about precision: one line of `Tx.lean` does move, the cite `:130–131` writes the fields rather than reads them, the ≈ 13 min / $0.29 pairing is off, run 2's unsettled dollar figure is still on the branch and #35, one tracker sentence is imprecise, and some numbers lack labels.

Lens: Opus 5.5 (`claude-opus-5-5`), read-only. I read the block at `e40d3c4`. `origin/main` moved to `de61f95` during the lens, but none of S2's paths changed (`git diff --quiet e40d3c4 origin/main` on them exits 0). The branch is at `7f77b9a`.

## Per claim

- **(1) The commits exist and sit where the block says.** HELD. All named commits pass `cat-file -e`.
  - `4974440`, `bd592a9`, `ad3e569`, `6687c74`, `83123d5` and `e40d3c4` are ancestors of `origin/main`.
  - `b87b7f3`, `391e4a2` and `7f77b9a` are ancestors of `origin/lean-b-repin` and not of main.
  - The pre-rebase commits `313c7f7`, `d32a004`, `9f783b9`, `77e452d`, `ba88550`, `6ecb51b` and `d9dac35` are reachable from no ref.
  - Rebase chain: `77e452d` (parent `4974440`), then `ba88550` (on `2436523`), then `6ecb51b` (on `74a7807`), then `bd592a9` (on `fb9d438`). That is three rebases.
  - Subject stamps match commit times: 12:40:54, 12:54:21, 12:57:11, 13:20:52, 13:25:44 and 13:44:36 UTC.
- **(2) S2 touched only its own and shared paths.** HELD. The paths were `docs/DESIGN.md`, `docs/lanes/lean.md`, `lean/BsvScript/Tx.lean`, `lean/AxiomCheck.lean`, `spec/`, `tools/specgen.py`, `docs/HYPOTHESES.md`, `docs/records` and the lakefile trio (branch only). All are on S2's `docs/OWNERS` line or are shared. `HANDOFF.md` was not touched. `AxiomCheck.lean` gained exactly 2 comment lines and 7 `#print axioms` lines. The list is 387 at `4974440`/`313c7f7` and 394 from `bd592a9` on, main and branch alike.
- **(3) `Tx.lean` at main has no `sorry`, `native_decide` or `bv_decide`.** HELD (`grep` exit 1). `Tx.lean` at main equals `bd592a9`'s.
  - All seven `@[csimp]` theorems have docstrings and are on the list.
  - `readLE` (42–43), `readVarInt`, `readBytes` (55–56), `readTxIn`, `readTxOut`, `readMany`, `decodeTxPrefix` and `decodeTx` are textually unchanged.
  - "Every existing line keeps its number" is **PARTIAL**. 118 of 120 lines keep their text and number. Line 1 changed in place (the import). The closing `end BsvScript.Tx` moved from 120 to 208. Nothing cites `Tx.lean:120`.
  - `Machine` imports `Numbers`, as claimed.
- **4974440, the carried items, and rule 9.** HELD. The word-diff against the parent's lens report:
  - Correction 1: `interpreter.cpp` 520–526 and 563–569 were added. I read both at `879fc8b42`: the CLTV and CSV "not enabled or post-Genesis" branches with the DISCOURAGE read. Both are cited at `Eras.lean:818`.
  - Correction 2: `dbe941a` changes exactly 15 lines of `TxRules.lean` (`:74` plus 14 others) and 17 cite tokens.
  - Correction 3: the record lines check out. Record `…-024941-…` has start load 3.88. Record `…-034013-…` has 4.95 at the start and 9.08 at the end.
  - Corrections 4, 5 and 8: landed. `validation.cpp:463–494` is `GetP2SHSigOpCount` at the pin. `specgen.py:360` and `366–370` are unchanged at main (the only later edit, `ad3e569`, is at line 454 and below).
  - Old phrases now grep 0 on the page: "machine row only", "at the fold is done", "family lands its", "occurrences in this sitting". "fifteen occurrences" survives once, inside this block, as a quotation of the corrected phrase.
  - The paste's carried item 3 holds: HYPOTHESES read 387 at that commit.
- **The DESIGN §5.5 sentence.** HELD. It is present at `DESIGN.md:450–453`, and `PARAMETERS.md` §4 names both caps.
  - "Read only at `TxPolicy.lean:89`, `94`, `130–131`" is **PARTIAL**. Lines 89 and 94 read the fields (`sigOpsCap`, `sizeCap`). Lines 130–131 write them (`NodeConfig.txPolicyAtConsensus`, a `{ cfg with … }` update). The fields are also declared, with defaults, in `Params.lean` at 213, 220, 277–278 and 307–308 at main.
- **The tripwire record `20260927-130904-make-check.txt`.** HELD.
  - `commit: d9dac35`, 0 uncommitted paths at both ends, 558 s, GREEN, load 17.23 at the start and 12.31 at the end. The sampler's peak is 60.94 over 56 samples.
  - `check-pins` 71 sites, 1 skipped (`gobdk-runner`). No such binary exists in this worktree; only `gosdk-runner` does.
  - `cite_check` 1061 anchored, MOVED 0. Axiom check 394. `specgen` OK with 2 flagged. `rules_check` 35 manifests.
  - The Lean-lock slot `slot1 13:04:24–13:18:22` is confirmed by the window's transcript lock lines. There is no record line for it, as the block says.
- **(5) The landing rule.** HELD. `git diff --quiet d9dac35 ad3e569 -- <the 14 paths>` exits 0.
  - The five commits crossed are `d2f58c1`, `f3f2d4c`, `74a7807`, `e25780a` and `fb9d438`. They touched `docs/`, `HANDOFF.md` and `tools/conformance.py`, and no leg of `check.sh` runs `conformance.py`.
  - I re-ran the cite and spec legs myself. On `6687c74`'s tree: `cite_check` GREEN with 1061 anchored and MOVED 0, and `specgen --check` OK with 2 flagged. Both hold at `e40d3c4` too.
  - The two shas and the exit code are stated in README row 88 and in the decoder record.
- **The ladder `[M]`/`[X]`.** HELD.
  - The timings file matches the raw summaries byte for byte, and the outputs file matches all 25 raw sections.
  - Walls: 4.46 → 0.17 s, 15.10 → 0.23 s, 50.75 → 0.28 s, 2.70 s after at 300,000 outputs, and `corpus/tx` 62.80 → 0.30 s.
  - The committed generator reproduces all 8 rungs byte for byte. Sizes run from 34,053 to 10,200,055 bytes. The 30,000 rung's `tx` equals `tx-00033` (1,020,053 bytes). The sha256 prefixes match the record.
  - Outputs: the 6 shared rungs and the 37 `corpus/tx` lines are identical apart from `commit`. Of 74 cells against `spec@714fbd6`/`spec-mempool@714fbd6`, 0 moved, in the before, after and landed runs alike.
  - The landed run used the same binary as the after run (mtime 08:56:14, sha `2881c575465f3bae`). Between `77e452d` and `d9dac35`, `lean/` differs only in `Params.lean` docstrings (S1's `3eb9885`).
- **The grep instrument.** HELD.
  - I re-implemented both patterns: old 433 and new 453 at main (+20 = Machine 6, Numbers 7, Tx 7). The old pattern gives 347 at `58f05a3` and 387 at `f9444ce`, matching the published figures. The new pattern gives 360 and 400. Before `94e6013` there were 0 attributed theorems.
  - `spec/README.md:12` at main reads 369/394/453. `specgen --check` is OK on main's tree.
  - `83123d5` re-cut lines 84 and 177 in place: the old counts are kept as instrument history beside 360 and 400. HELD in substance under rule 9.
- **HYPOTHESES.** HELD. It now says 394 at `…-130904-…`, the old "387 at `…-041539-…`" is gone, and the history is kept.
- **The dry run's appended Correction.** HELD. At `f9444ce`, `lakefile.toml:6` is `defaultTargets = ["BsvScript","Bsvs"]`, `:20` holds the roots, and there are 15 `lean_exe` targets. `Bsvs.Trace` imports `Test.OpNames`. The dry-run log has no `:exe` lines; the re-pin log has them.
- **(4) Toolchain.** HELD. `e40d3c4` and `de61f95` have `leanprover/lean4:v4.33.0`. The branch has v4.34.0.
- **The re-pin.** HELD.
[withheld at export: a sibling tree's line]
  - Tree hashes, recomputed with the runner's own function: `313c7f7` gives `4571db1f…` over 56 files and `b87b7f3` gives `a9f40b40…` over 56. The branch tip's `lean/` equals `b87b7f3`'s.
  - Build steps: 766.8 s and 766.9 s, "Build completed successfully (17946 jobs)" in both logs. Each log has 9,346 lines, 0 error lines and 0 lines containing lowercase `sorry`.
  - Warnings: 176 lines start with `warning: `, 158 of them deprecations over nine names (47/35/31/17/14/6/3/3/2). S2 has 62 (TxRules 43, Eras 11, Sighash 5, Tx 1, Flags 1, `Test/ErasCheck` 1) and S1 has 96 (76 library plus 20 test). There are 18 linter warnings (7 simp, 6 dupNamespace, 3 variables, 2 seqFocus).
  - Run 2's warnings equal run 1's, even with positions.
  - Axiom tool: 387 in run 1, 394 in run 2. The committed JSONs and logs equal the full container JSONs.
  - `check_pins` companion: 69 OK, 2 DRIFT (exactly `lean.toolchain` and `lean.mathlib` against `PROVENANCE.md:86–87`), 1 skip.
  - The runner builds all 3 libraries and 15 executables.
- **The comments.** HELD. 5856248896 (#24, 13:24:05Z), 5856247435 (#25, 13:23:52Z) and 5856381613 (#35, 13:43:24Z) match the block. 5852250155 is S1's Finding. 5850367387 says 347 by grep and 5852144858 says 387.
[withheld at export: a sibling tree's line]
- **(e) Asks.** Verbatim, each with cost and purpose. HELD, except ask (4) is PARTIAL (see corrections 3 and 7).
  - `HOSTS.md:27` says ≈ 25 GB.
  - The Studio's `~/.elan/toolchains` holds only v4.33.0 and v4.33.1.
- **(f) Money.** HELD. My meter read at 13:57:27Z: `ap-92jVLRzzqgJwM7ZBDglayK` $0.29254872 and `ap-MDcNDllaArfQrjfOMsA3iK` $0.29080004, sum $0.58334876. No other S2 app ran this sitting.
- **Machine line.** HELD. The transcript shows the same uptime and df output, and git status was clean at `e40d3c4`.
- **(7) Rule 13.** HELD. "first" appears only as an ordinal (4 times). No "conformant", no "consensus", no em dashes.
- **(8) Labels.** PARTIAL (correction 6).
- **(9) Six parts plus the machine line, and (10) the asks.** HELD.
- **First line and Next line.** HELD, apart from the missing labels.

## Corrections

1. **`lean.md` S2 block, THE DECODER WALL** (the same wording is in `20260927-125018-decoder-wall-s2.md` and #24 5856248896): "so every existing line keeps its number". Right: lines 2–119 keep their text and number, line 1's import changed in place, and the closing `end BsvScript.Tx` moved from 120 to 208 `[X]` (`4974440` vs `bd592a9`).
2. **Block (a), the `4974440` clause:** "the fields read only at `TxPolicy.lean:89`, `94`, `130–131`". Right: read only at `:89` (`sigOpsCap`) and `:94` (`sizeCap`); set at `:130–131` (`NodeConfig.txPolicyAtConsensus`); declared with their defaults at `Params.lean:213`, `:220`, `:277–278`, `:307–308` `[X]`.
3. **Block (e)(4):** "a container builds the whole tree in ≈ 13 min for ≈ $0.29 `[M]` twice this sitting". Right: a container run takes ≈ 17 min (1,030.8 s and 1,024.5 s: `lake update` 214.6 / 210.7 s, cache get 32.1 / 30.5 s, the build of every target 766.8 / 766.9 s ≈ 12.8 min, the axiom tool 16.7 / 16.1 s) for $0.29254872 and $0.29080004 `[M]`.
4. **Branch record `20260927-130311-repin-35-s2.md`, its money line and README row 89, and #35 5856381613's table:** "$0.27785863". Right: the settled meter for `ap-MDcNDllaArfQrjfOMsA3iK` is $0.29080004 `[M]` (the block's read at 13:43:36; this lens's read at 13:57:27Z is equal), and the two runs total $0.58334876 `[M]`. Land it as an appended Correction on the branch plus a `**Correction.**` comment on #35. The record itself says "the lens re-reads it".
5. **#35 5856381613:** "`String.mk` and `List.asString` → `String.ofList`, `String.trim` → `String.trimAscii`; the last three are the test executables', which the sitting-2 dry run did not build". Right: `String.trim` (14) and `List.asString` (2) occur only in the test executables. `String.mk` has 6 sites: `Tx.lean:118` (S2's library, which the dry run built and which already warned at v4.33.0) plus five in the tests (`ErasCheck` 1, `NumbersCheck` 1, `SighashCheck` 3) `[X]`.
6. **Block (a), THE RECORDS' tripwire clause:** "TWENTY-ONE legs in 558 s, … 71 sites, … 1,061 …, the axiom check 394, … 2 rules flagged, … 35 manifests" has no labels. Right: 558 s `[M]`; the leg counts `[X]` (the record's lines). **The Next line:** "50.75 s → 0.28 s", "62.80 s → 0.30 s" → `[M]`; "the axiom list 394" and "the flagged count (2)" → `[X]`.
7. **Block (e)(4):** "21Gi free at 12:4x UTC". Right: 17Gi free at 13:43 UTC (the block's own `df -h /` line; 17Gi again at 13:57Z) against ≈ 25 GB `[M]`.
8. **Optional precision.**
   - Block (a) says "rebased three times over other windows' page and docstring commits", and the decoder record says "pages and one docstring change", listing only `d2f58c1`/`f3f2d4c`/`74a7807` of S3's. Right: the rebases crossed page, record, docstring and report-tool commits: S1's `3eb9885`, `2436523`, `fb9d438` and S3's `d2f58c1` (which includes `tools/conformance.py`), `f3f2d4c`, `74a7807`, `e25780a` `[X]`.
   - The Next line's "moves when S3 lands …'s family" reintroduces the wording the parent's correction 8 replaced. Right: "when a generated corpus carries entries with the rule id (the family's landing)".

## Must-knows

- **Main moved after the block.** S1's `11280f6` (#47's Lean half) changed 10 files under `lean/Test` after the branch's base `6687c74`. The READY tree (`b87b7f3`'s `lean/`) is therefore no longer main's `lean/` plus the trio, so the landing's rebase brings those files in and the Lean leg must re-run, as (c)(1) already says. The 176-warning census was taken before `11280f6` and must be re-read at the landed commit. `11280f6`'s hunks add none of the nine deprecated names.
- **Orphaned twins.** `d9dac35` (the tripwire's `commit:` line), `77e452d` (the ladder's after-binary), `d32a004` (run 1's shipped archive), `ba88550`, `6ecb51b` and `40b4b5f` exist only in the Studio's local object store. No ref contains them, and GitHub REST answers 422 for each; `313c7f7` and `9f783b9` are on GitHub. Under the orphan rule, a `fallback/*` branch or tags would keep the cited twins from being lost to gc.
- **Rule 17.** The landed-ladder re-run started at 13:18:52 UTC at a 1-minute load of 41.50 (39.06 for the 300,000 rung), against "nothing starts above load 20". The record discloses the load, and the run took ≈ 5 s.
- **Lean lock.** The 12:52:44 UTC `lake env lean` elaboration of a scratch file (9.4 s) ran without a slot. The three `lake build` runs did hold slots, per the transcript: slot2 12:47:54–12:49:14 (the record says 12:49:13, the build's end), slot1 12:54:35–12:56:15, and slot1 13:04:24–13:18:22.
- **Precision nit on "once".** `readLEFast` and `readBytesFast` walk the field's `n` bytes twice (`takeExact`, then `bs.drop n`), not once. Cost is still linear per field, so the substance of the claim stands.
- **The "sorry" hit.** Both build logs contain `Mathlib.Util.AssertNoSorry` at line 8880. It matches only a case-insensitive grep; `check.sh`'s case-sensitive grep ignores it.
[withheld at export: a sibling tree's line]
