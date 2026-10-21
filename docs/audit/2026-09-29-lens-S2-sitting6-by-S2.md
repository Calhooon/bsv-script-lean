[export: 3 lines withheld by tools/export_public.py, the sibling trees' lines; the original is in the private history]
<!-- S2'S OWN LENS ON ITS SITTING-6 END BLOCK (LANE F, set 4 sitting 6; S2 the Lean B sub-agent; 2026-09-29). A fresh-context, READ-ONLY lens: a Claude Code subagent of S2's session (the Agent tool, general-purpose, model opus: the live glass `~/.claude-usage/relay-glass.json` read "glass": true at 02:18:10 UTC, D118), launched 02:18 UTC, its wall 1,358 s [M] (the tool's usage line: 1,357,621 ms, 105 tool uses). Its brief: the paste's rule (6) with the read-only rules (no lake, no eval, no make, no writes), the sites and the named checks, read against origin/main c930ff2. The report below is verbatim as the lens returned it (the one character-level change: its "<paths>" and "=>" arrived HTML-escaped). Its six LOAD-BEARING corrections are all S2's and landed in the commit that files this report: 1 and 2 in the block, DESIGN 12.6, the box record's README row and a **Correction.** comment on #35 (the tag's tripwire now the box run at b3406bf itself, the parent's Finding 5882258722 named, ask 4 re-cut to landing 1560b0a); 3 in the block, DESIGN 12.5, the fixture record (appended), its README row and the same #35 comment; 4 in the block's asks 2 and 3; 5 and 6 as appended corrections to the gadget, fixture and narrowing records. Its eleven COSMETIC corrections (7 to 17) are listed here and not fixed (D128). -->

I'm on Opus 5.5 (`claude-opus-5-5`), a fresh-context, read-only lens. I read `origin/main` at 2026-09-29T02:18:46Z at `c930ff262a5a93b3a42fd370d18b878a9ea0826a`, and it was unchanged when re-fetched at 02:36:42Z.

# Lens on `### S2 END BLOCK (2026-09-29T02:14:54Z)` (`docs/lanes/lean.md:328-359`, landed at `c930ff2`)

**Verdict: HELD IN SUBSTANCE.** 17 corrections: 6 load-bearing, 11 cosmetic.

Every figure the block quotes re-derives from its records and from git: the Mathlib surface sums, the closures, the sha256 values, the byte-identity, the corpus's largest transaction, the tag, the commits, the comments, the compaction.

The main problem is a tracker entry the block does not name. The parent filed a **Finding.** on #35 (5882258722, 02:05:16Z), nine minutes before the block.
- It reads the same box record as a leg at `994d280`, not at S2's commit.
- It sets an interim rule: "Until then, a `make check-box` record counts only if its `commit:` line names the caller's own commit."
- It announces S3's fix, which exists as `1560b0a` on `origin/s3-c35` and is not on `main`.

The block still asserts the GREEN as `b3406bf`'s by the landing rule, and files the same race as a new ask.

The other problems:
- One superlative is false as worded ("the corpus's largest locking script").
- Two asks understate their cost: `spec/` has to be regenerated.
- Two records carry exit codes their scripts could not measure.
- One record overstates an identity between two outputs.

**What I ran.**
- Git reads in the worktree after `git fetch origin` and `git fetch --tags origin`.
- REST reads (`gh api`) of #35's comments and of issues #24, #32, #35 and #44.
- python3 over the tracked corpus, the records, S2's scratch logs and the session log.
- One `git apply --check --cached` against a throwaway index file in my scratchpad, deleted afterwards.
- No `lake`, no `eval/bsvs`, no `make`, no writes to any repository or tracker. The worktree stayed clean (`git status --porcelain`: 0).

In the table, "log L*n*" is line *n* of `17d39f23-bfbe-4be0-ae40-b7b6f16a68fd.jsonl`, and "scratch" is S2's `…/scratchpad/s35/`.

## Claims checked

| # | Claim | Verdict | Evidence |
|---|---|---|---|
| 1 | The paste of 00:50 UTC is on `docs/lanes/harness.md`; it was printed at 00:53:38 and at 00:59:04 UTC | HELD | `harness.md:458` heading. Tool results at 00:53:38.421Z (log L2951) and 00:59:04.569Z (log L3001); the second one was piped through `head -80`, but the paste is 17 lines, so it printed in full |
| 2 | "three items" | HELD | The paste numbers (1) to (3); its own text says "Two items." |
[withheld at export: a sibling tree's line]
| 4 | Fast-forwarded to `3dd1f8f`, then after a fetch to `04a97e5` (continue 33's landing, D158) | HELD | log L2960 at 00:55:06 (`merge --ff-only` to `3dd1f8f`); log L3287 at 01:12:37 (to `04a97e5`, which descends from `f7ad524`, the symlink lock) |
| 5 | Package key `c30ba59fba28` by `lean_cache.py status` | HELD | log L2960 output |
| 6 | Same live session `17d39f23`; compacted at 00:58:56 UTC from 967,004 to 15,187 tokens `[M]` | HELD | log L2972: `compact_boundary`, trigger auto, `preTokens` 967004, `postTokens` 15187 |
| 7 | Near 97 % of the window before the compaction, over D126's 80 % `[D on M]` | HELD | 967,004 / 1,000,000 = 96.7 % |
| 8 | Every commit by pathspec; each subject stamp a `date -u` read | HELD | `git commit -q -F … -- <paths>` with STAMP from `date -u` (log L3354, L3875 area, L4231 area, L4383). The stamps 01:15, 01:44, 02:08 and 02:17 equal the commit times |
| 9 | Every Lean run under the Lean lock (one slot, `LEAN_NUM_THREADS=2`) after the load gate | HELD | Every `lake` call runs inside `leanbatch.sh`, `consumerbatch.sh` or `narrowbatch.sh`. Each does `lean_lock_take S2`, then waits for load1 under 18. The holder lines show `LEAN_NUM_THREADS=2` |
| 10 | `b3406bf`: §12, §5.5 (S1's ask 5), and the Q6 re-cut in §9 | HELD | `git show --stat b3406bf` shows `docs/DESIGN.md` only; the diff |
| 11 | §5.5 carries S1's ask 5 verbatim (S1's END BLOCK (e)5, `lean.md:324`) | HELD | Identical after whitespace normalization; only the sentence's initial capital differs |
| 12 | Q6's "the mempool's standardness gate ... scoped out by §5.5" now reads "modeled since 2026-09-28" | HELD | `docs/DESIGN.md:620-621`; the original clause is gone |
| 13 | `1d436d7`: two records; §12.3 and §12.5 filled | HELD | stat and diff |
| 14 | `ae1551f`: four records; §12.1, §12.3, §12.4 and §12.6 filled | HELD | stat and diff |
| 15 | `c930ff2` carries the legs record, the Next line and the page stamp | HELD | Diff hunks at `lean.md:1`, `:39` and the block |
| 16 | `v0.1.0` is annotated `6c1c9a5` and points at `b3406bf` | HELD | `git ls-remote --tags origin`; `git cat-file -p v0.1.0` |
| 17 | The tag was pushed at 02:13 UTC | HELD | Tagger time 02:13:02Z; log L4278 (02:13:01 to 02:13:41) shows `[new tag] v0.1.0` |
| 18 | The tag message names the consumer's and the tripwire's records | HELD | `git cat-file -p v0.1.0` |
| 19 | Each record is indexed in its own commit | HELD | README +2 rows in `1d436d7`, +4 in `ae1551f`, +1 in `c930ff2` |
| 20 | One module imports Mathlib, `Numbers.lean:1` | HELD | `git grep`; the output's `direct` column is 1 for Numbers only |
| 21 | 216 of 1,806 named declarations use a Mathlib-side constant; 167 of them outside `Numbers`, in 25 modules | HELD | Re-summed from `…-013409-…-output.txt`: 216, 49 + 167, 25 modules. S2's six files 77, S1's 90 |
| 22 | Outside `Numbers`: 63 Mathlib-side tactic nodes in 13 modules, `split_ifs` 51 | HELD | Re-summed: 63 nodes in 13 modules; kinds `splitIfs` 51, `show` 4, `byContra` 4, `tauto` 2, `normNum` 1, `convLHS` 1 |
| 23 | Seven modules use no Mathlib | HELD | `useAll` is 0 in the root, Eval, Opcodes, Ops.Arith, Ops.Splice, Ops.Stack and Params |
| 24 | `import BsvScript` loads 10,777 modules, 8,908 Mathlib-side | HELD | The CLOSURE line; its components sum to 8,908 |
| 25 | The library built first, 216.24 s | HELD `[M]` | scratch `build.time` shows 216.24 real; `build.log` shows 17903 jobs |
| 26 | Instrument and output sha256 | HELD | `fe21fff6…` and `3c7b2283…` (`shasum -a 256`); the record's table equals the output rows for all 33 modules |
| 27 | Fixture walls and resident sets: `eras-00012` 1.50 s at 62,832,640 bytes; `tx-00040` 1.91 s at 2,147,041,280 bytes | HELD `[M]` (a re-run is UNVERIFIABLE here) | scratch `fixtures/*.time` |
| 28 | `eras-00012` is the corpus's largest locking script, 10,005 bytes, tied with `eras-00011` | PARTIAL | True for prevout (spent) scripts only. `tx-00040`'s output script is 10,000,036 bytes; see correction 3 |
| 29 | `tx-00040` is the largest transaction, 10,000,100 bytes | HELD | My scan: every `tx` parsed, the next largest is `tx-00033` at 1,020,053 |
| 30 | The scan covered 27,911 entries with a `tx` in the 65 tracked `*.jsonl` files | HELD | My scan (33 of the 65 files carry a `tx`) |
| 31 | The fixture copies: 21,264 bytes (`0ffacb51…`) and 20,001,417 bytes (`9cef6b9d…`) | HELD | `sed -n '12p'` and `sed -n '40p'` of `origin/main`'s files, then `wc -c` and `shasum` |
| 32 | Verdicts and codes as the corpus records them; the gate refuses `tx-00040` with `tx-size` | HELD `[X local]` | Outputs companion (sha `ffc70280…` equals scratch) against the corpus's `spec@…` and `sv-node-mempool@v1.2.2` columns |
| 33 | Gadget names: `run`, `loop_eq_run`, `framed`, `getOpTail_append`, `run_append`, `Triple`, `seq`, `conseq` | HELD | Companion lines 45, 81, 96, 107, 170, 191, 196, 207 |
| 34 | Compiled at `1d436d7` with no error and no `sorry`; every theorem within the three axioms | HELD by output (the compile itself is UNVERIFIABLE here) | scratch `gadget.out`: no `error:` line; five `#print axioms` lines, no `sorryAx` (`getOpTail_append` uses `[propext, Quot.sound]`); `HEAD 1d436d7` |
| 35 | The fourth compile; three failed before it | HELD | log: 01:28:27 type mismatch, 01:35:24 unsolved goals, 01:37:34 `omega`, 01:46:20 clean |
| 36 | Consumer requires `bsvscript` by the git URL at `b3406bf` with `subDir = "lean"`; Lake's own clone over GitHub | HELD | lakefile companion; scratch `consumer.log`: "cloning https://github.com/Calgooon/bsv-script-lean", "checking out revision 'b3406bf9…'" |
| 37 | Cold build, `8959 jobs`, 213.28 s; kernel vector valid within three axioms; shared cache untouched `[M]` | HELD (a re-run is UNVERIFIABLE here) | scratch `consumer.time`; `consumer.log:121-123`; "files under the shared cache newer than the marker: 0" |
| 38 | Consumer companions' sha256 | HELD | `8733782d…` equals the bytes `leanprover/lean4:v4.34.0\n`; `d812bde8…`, `7593e24d…`, `afe1d2bb…` |
| 39 | 74 imports = the 73 NEEDED + `Mathlib.Tactic.Positivity.Basic`; the first try without it failed on `positivity` | HELD | Patch has 74 `+import` and 1 `-import`; set difference against the NEEDED list; `narrow.try1.log`: `Numbers.lean:916:40`, `:946:52` |
| 40 | Every target builds (library 48.22 s, `1029 jobs`); axiom check 545 | HELD `[X local]` `[M]` | `narrow.b1` (1029 jobs, 48.22 s); `narrow.b2` covers `Bsvs`, `TestSupport` and the 15 exes (2092 jobs); `narrow.ax.log:546` reads 545 |
| 41 | The terms name the same Mathlib constants module for module | HELD | The kernel-term columns and every DETAIL constants line are identical between the two outputs (diff) |
| 42 | 980 Mathlib-side modules instead of 8,908 | HELD | Narrowing output CLOSURE: 2500 modules, 980 Mathlib-side; the companion `b351be21…` equals scratch |
| 43 | Ask 3: `git apply --check` clean on `main` | HELD | `git apply --check --cached` against `origin/main`'s tree (throwaway index): exit 0 |
| 44 | The legs record has one cite run per landing | HELD | log: 01:23:41, 01:44:13, 02:12:00, 02:16:13, 02:17:01 (plus the ungated 01:14:54) |
| 45 | `make check-box` launched at 01:25:22 UTC for `b3406bf`, pushed, tree clean | HELD | log L3543: porcelain 0, `origin/main` contains HEAD, `01:25:22Z` |
| 46 | Twenty-one legs GREEN in 218 s; axiom check 545; `specgen --check` OK with 0 rules flagged | HELD | Box record lines 3 to 5, 13, 38; `tools/check.sh`'s header lists 21 legs |
| 47 | The `commit:` line reads `994d280` | HELD | Box record line 2 |
| 48 | Checked out `b3406bf` at 01:25:24; waited for the leg lock and a Lean slot until 01:53:44 | HELD | scratch `checkbox.log:2`, `:9-23`; `make check-box exit 0 at 01:57:23Z` |
| 49 | `994d280` is `origin/s3-c35`, a child of `b3406bf`; the diff is `tools/check_box.sh` alone, a file no leg reads | HELD | Parent is `b3406bf`; `git diff --stat`. The remote body runs from the caller's copy over ssh stdin (`check_box.sh:29`). `origin/s3-c35` is now at `1560b0a` |
| 50 | "the GREEN is `b3406bf`'s by the landing rule" | PARTIAL | Byte-identity holds `[X]`, but the parent's Finding 5882258722 sets a stricter rule the block does not name; see correction 1 |
| 51 | `1d436d7`, `ae1551f` and `c930ff2` are byte-identical to `b3406bf` on the fourteen paths (exit 0 at each push) | HELD | My `git diff --quiet` exits 0 for each; log L3882, L4272, L4383 |
| 52 | The cite leg was re-run GREEN on each landed tree | HELD in substance | Legs record (v): the last run excluded two paths; see correction 15 |
| 53 | Comments 5881853816 (step 1), 5882062478 (step 2), 5882062592 (step 4), 5882342198 (step 3); #35 open | HELD | REST: created 01:24:47Z, 01:45:50Z, 01:45:51Z, 02:13:47Z; #35 `open` |
| 54 | #24 CLOSED by the parent on 2026-09-28; #44 at S4; #32 is the three-lens review | HELD | REST: #24 `closed_at` 2026-09-28T12:43:58Z; #44 and #32 are in milestone "S4 · Review and release" |
| 55 | T-SO10 corrected by S1 at `eb4cddf`, `TxPolicy.lean:469` | HELD | Line 469 at `eb4cddf` (and at `main`) reads "Since S2's `616008e` both stop at a literal `0xff` …" |
[withheld at export: a sibling tree's line]
| 57 | Ask 2: five theorems; `Gadget.lean` falls under S1's `lean/BsvScript` glob | HELD | Companion; `docs/OWNERS:8` |
| 58 | Asks 2 and 3: the costs as stated | PARTIAL | Correction 4 |
| 59 | Ask 4's facts: checkout before the lock, `tag=check-box:S3`, rc 0 without a commit comparison, a 28-minute wait | HELD | `check_box.sh` at `b3406bf`: `:42` (checkout) before `:83`/`:96` (lock takes); `:70` (tag); `:131-136` (rc) |
| 60 | Ask 4 as a new finding with a one-hunk cost | PARTIAL | Correction 2 |
[withheld at export: a sibling tree's line]
| 62 | `uptime`, `git status -sb`, `df -h /`, stamp 02:14:54Z | HELD | log L4317 |
| 63 | The block is within 20,000 characters, with no em dash | HELD | 9,923 characters; 0 em dashes |
| 64 | The Next line's content (the tag, `6c1c9a5`, the six records, 5882342198, the owed items, the struck items) | HELD | `lean.md:39` |
| 65 | "the sitting-5 line it replaces is history in that sitting's END BLOCK below" | HELD in substance | The sitting-5 block's (a) to (c) carry its facts; the old line is in `c930ff2`'s diff |
| 66 | §12.1 closures 4/5/9/14/17/19/23/33; fifteen `lean_exe`s | HELD | Computed from the import lines of the 33 modules; `lean/lakefile.toml` |
| 67 | §12.4's names are where it says | HELD | `Eras.lean:764` `loop_codeseparator`; `Basic.lean:108` `opreturn_suffix`; `KernelSample.lean:105` `loop_eq_fuel`; `Numbers.lean:64` `encode` |
| 68 | §12.4 items 1 to 4 describe the prototype | HELD | `run` mirrors `Machine.loop` (`Machine.lean:379`) step for step, with `rest ++ tail` passed to `execStep` and `.done` mapped to `stop`. `loop_eq_run` uses the empty tail; `run_append` requires `framed g`; `Triple` is ∀ st tail, P st → ∃ st', run … = .next st' ∧ Q st'. The one naming slip is correction 8 |
| 69 | §12.4 item 5 (the kernel route) | PARTIAL | Correction 9 |
| 70 | §12 status: R6, Lean v4.34.0, Mathlib `5ed2965` | HELD (the siblings' pins are UNVERIFIABLE under rule 5) | `lean/lake-manifest.json`; `docs/PROVENANCE.md:21` |

## Corrections

### LOAD-BEARING

**1. The GREEN's attribution to `b3406bf` ignores the parent's Finding.**
- **As written:** "`git diff --stat b3406bf 994d280` is `tools/check_box.sh` alone, a file no leg reads, so the legs read `b3406bf`'s tree, docs included, and the GREEN is `b3406bf`'s by the landing rule".
- **Sites:**
  - The block, THE LEG OF RECORD, `docs/lanes/lean.md:343`.
  - The same claim in `docs/DESIGN.md` §12.6 (`:873-876`).
  - The README row of `20260929-015344-make-check-box.txt`.
  - Comment 5882342198.
- **Right value:** The byte-identity is `[X]`: `git diff --quiet b3406bf 994d280` exits 0 on the fourteen paths and on `docs/`.
  - The parent's **Finding.** on #35, 5882258722 (created 2026-09-29T02:05:16Z, edited 02:07:56Z), rules otherwise: "Until then, a `make check-box` record counts only if its `commit:` line names the caller's own commit."
  - The block must name that Finding and ask the parent's word on whether the landing rule's byte-identity carries `994d280`'s GREEN to `b3406bf`. The alternative is a box leg whose `commit:` line is S2's own, after S3's per-caller fix lands.
  - Until that word, §12.6's "its tripwire GREEN" is `[D]`, pending. The tag cannot move, so the qualification belongs in §12.6 and the block.

**2. Ask 4 files as new a finding the parent already filed and fixed.**
- **As written:** "FOR THE PARENT (a finding in S3's file): "`tools/check_box.sh` checks out the caller's HEAD in the shared box worktree before it takes the box leg lock … would close it." Cost: one hunk in `tools/check_box.sh`."
- **Site:** The block (e)4, `docs/lanes/lean.md:355`.
- **Right value:** The facts hold `[X]` (row 59). The finding is the parent's own:
  - **Finding.** 5882258722 (02:05:16Z) reads the box reflog: S2's checkout of `b3406bf` at 01:25:24Z, S3's run checking out `994d280` at 01:35:07Z, S2's `make check-local` at 01:53:44Z.
  - The fix is written: S3's `1560b0a` on `origin/s3-c35` (stamped 02:07 UTC: "a box worktree per caller, the caller's tag on both locks, HEAD re-checked; a record of another commit is RED"). It is not on `main` at `c930ff2` `[X]`.
  - Cite both, and reduce the ask to "land `1560b0a`" or strike it; its stated cost is already spent.

**3. "The corpus's largest locking script" is false as worded.**
- **As written:** "`eras-00012` (the corpus's largest locking script, 10,005 bytes)".
- **Sites:**
  - The block, `docs/lanes/lean.md:336`.
  - `docs/records/20260929-013700-foreign-fixture-35-s2.md:9` ("the largest locking script in the corpus, 10,005 bytes, tied with its pre-Genesis twin `eras-00011`").
  - `docs/DESIGN.md:857` (§12.5).
  - That record's README row.
  - Comment 5882062592's table.
- **Right value:** 10,005 bytes is the largest spent (prevout) locking script, `eras-00011` and `eras-00012` `[X]`.
  - The corpus's largest locking script is `tx-00040`'s output script at 10,000,036 bytes. Next come `tx-00038`'s and `tx-00039`'s output scripts at 20,002 and 20,001 bytes `[X]`.
  - Source: my scan of the 65 tracked `corpus/**/*.jsonl` at `c930ff2`, 27,911 entries with a `tx`, every transaction parsed to its end with no trailing byte.
  - Say "the largest locking script a spend executes (a prevout's)".

**4. Asks 2 and 3 omit the `spec/` regeneration from their cost.**
- **As written:** ask 2's "Cost: one OWNERS line, two one-line hunks, one Lean build under the lock." and ask 3's "Cost: one hunk and the tripwire at its landing."
- **Sites:** The block, `docs/lanes/lean.md:353` and `:354`.
- **Right value:** Both landings change `spec/`.
  - `tools/specgen.py:122` reads every docstring of `lean/BsvScript/**/*.lean` and cites it by file and line. The lane's own rule (`lean.md:3`) is "never a docstring on a new declaration without regenerating `spec/`".
  - Ask 2: `Gadget.lean` brings new docstrings.
  - Ask 3: the hunk turns line 1 of `Numbers.lean` into 74 lines. Every docstring below it shifts by 73, which moves the 63 `Numbers.lean:NNN` citations in six `spec/` pages `[X]`: `theorems.md` 53, `OP_NUM2BIN.md` 5, `OP_BIN2NUM.md` 2, and one each in `OP_CHECKLOCKTIMEVERIFY.md`, `OP_CHECKSEQUENCEVERIFY.md` and `OP_SUBSTR.md`.
  - Each cost therefore adds `make spec` and a `spec/` commit (S2/S3's). Otherwise the spec leg reads STALE at the landing, as happened after S1's `eb4cddf` on 2026-09-28 (15:13 to 15:25 UTC).
  - Ask 3 also adds rule 9 on `docs/DESIGN.md:758` (§12.2) and `:774` (§12.3). Their "`Numbers.lean:1`" `import Mathlib` sentences become false when the hunk lands.

**5. Two records report exit codes the scripts could not capture.**
- **As written:** "exit 0, **no error, no `sorry`**" in `docs/records/20260929-014620-gadget-api-35-s2.md:20`, and the "exit" column (0, 0) in the runs table of `docs/records/20260929-013700-foreign-fixture-35-s2.md:14-16`.
- **Right value:** Neither exit status was captured.
  - The scripts (`leanbatch.sh`'s gadget step, `evalrun.sh`) print `echo "[$(ts)] … exit $?"`. There `$?` is the status of the `$(ts)` substitution, 0 by construction: under bash, `false; echo "[$(ts)] exit $?"` prints `exit 0` `[X]`.
  - The three failing compiles also logged "gadget exit 0" (01:28:37, 01:35:34 and 01:38:16 UTC).
  - What stands instead: the final compile's output (no `error:` line; five `#print axioms` lines without `sorryAx`) and the fixture runs' written outputs (sha `ffc70280…`).
  - Write "exit status not captured" and cite those.

**6. The narrowing record overstates the identity of the two outputs.**
- **As written:** "(every module's row and its top-twelve constants identical in the two outputs, compared by script `[X]`)".
- **Site:** `docs/records/20260929-020414-narrowing-35-s2.md:24`.
- **Right value:** The rows are not identical.
  - Identical `[X]`: the kernel-term columns (`decls`, `named`, `useAll`, `useNamed`, `consts`), the syntax columns (`stxNodes`, `stxKinds`, `parseErr`) and every DETAIL constants line.
  - Moved: the identifier proxy, in seven modules (Machine, Properties.Eras, Sighash, Tx, TxContext, TxPolicy, TxRules). `idents` went from 124 to 88, `identConsts` from 39 to 28, and "named in the source by identifier" from 20 to 18. Numbers' `direct` went from 1 to 74, as the hunk intends.
  - The block's own sentence ("the terms name the same Mathlib constants module for module") holds.

### COSMETIC (listed, not a fix cycle; D128)

7. **"74 named Mathlib modules"** (the narrowing record's title at line 1, its README row, and `ae1551f`'s message): two of the 74 are Batteries modules. Say "74 named Mathlib-side modules (72 Mathlib, 2 Batteries)", as the block and §12.3 do `[X]`.
8. **`docs/DESIGN.md:817`** (§12.4 item 3) names "`Gadget.Framed g`". The prototype defines `Gadget.framed : Bytes → Bool` (companion line 96), which is what the record and the block say.
9. **`docs/DESIGN.md:831-835`** (§12.4 item 5): "`run` evaluates … by `decide` or `rfl` in the kernel through the structural copy of the loop (`loop_eq_fuel`)".
   - `Gadget.run` is well-founded recursion (`termination_by g => g.length`, companion line 67) with no fuel copy, and `loop_eq_fuel` is `Machine.loop`'s.
   - The kernel reaches a gadget only with an empty tail, through `loop_eq_run` then `loop_eq_fuel`, where `toLoop` merges `next` and `stop`.
   - A `runFuel` with its lemma is unbuilt `[D]`.
10. **`docs/records/20260929-013409-mathlib-surface-35-s2.md:5`**: "the seven columns both runs have". Run 1's and run 2's headers share nine (`decls`, `named`, `useAll`, `useNamed`, `consts`, `stxNodes`, `stxKinds`, `parseErr`, `direct`). All nine, and the closure lines, are identical `[X]` (scratch `surface.run1.out` against `surface.out`).
11. **The block, `lean.md:343`**: "ran its legs on what the worktree held then, `994d280`".
    - `tools/check.sh`'s `record_run` reads the `commit:` line at the run's end, not at 01:53:44.
    - The checkout time comes from the parent's reflog reading in 5882258722 (S3's run at 01:35:07Z). Cite that here, and in the README row in place of "S3's by the branch `[D]`".
12. **The block, `lean.md:332`**: "rule 9 on my own Q6 answer". Q6's answer is S3's, from source (2026-09-24, `harness/oracle/README.md`); S2 wrote it into §9 on 2026-09-26 (`docs/DESIGN.md:609-623`).
13. **The block, `lean.md:338`**: "(with the four files)". Three companion files are committed. The fourth, `lean-toolchain`, is quoted in the record with its sha256 (`8733782d…`).
14. **A lapse the block does not name.** The cite leg's first run at 01:14:54 UTC started at a 1-minute load of 105.43, over rule 17's 20. The legs record's (i) and comment 5881853816 both name it.
15. **The block, `lean.md:343`**: "the cite leg re-run GREEN on each landed tree". The last run (02:17:01 to 02:17:05 UTC) read `c930ff2`'s tree without the legs record and its README row. Neither file carries a `file:line` shape, so this holds in substance, as the legs record says.
16. **Ask 1 (`lean.md:352`) and §12.1** give `rev = "v0.1.0"` but not how a sibling resolves the require without `lake update`'s road. That road runs Mathlib's post-update `cache get`, which is refused on this machine; the consumer wrote its manifest instead (the consumer record).
17. **Ask 3's "about a quarter of its wall `[D on M]`"** compares two different builds: the consumer's cold build (a GitHub clone, 8,959 jobs, 213.28 s) and the narrowed library alone (1,029 jobs, 48.22 s). The narrowing record says "not one build twice"; the ask could say so too.
