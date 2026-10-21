[export: 8 lines withheld by tools/export_public.py, the sibling trees' lines; the original is in the private history]
<!-- S1's own fresh-context lens on its sitting-6 END BLOCK (`### S1 END BLOCK (2026-09-29T07:47:12Z)`, landed `d8ea572`), the paste's rule (6); a read-only subagent on Opus 5.5 (the live glass `true` at its spawn, `~/.claude-usage/relay-glass.json`), launched 07:49 UTC, 1,441,591 ms and 106 tool uses by the tool's usage line; its report below, verbatim. The load-bearing corrections landed with this file: the block in place, the two records by appended Corrections, the DESIGN sentences by a Correction comment on #35 for the page's owners. -->

Opus 5.5 (claude-opus-5-5), read-only lens on S1's END BLOCK of 2026-09-29T07:47:12Z at d8ea572.

**Overall verdict: HELD IN SUBSTANCE.** Every sha, comment id, measured figure, ratio and code claim I checked matches its record, the session log or the tree. There are 19 corrections: 7 load-bearing, 12 cosmetic. Most of the load-bearing ones are about completeness: owed work left out, one breach time, one record sentence, and one derived module count.

origin/main moved while I was reading. S3's fold landed at ba7dfc4 (07:52 UTC): it put ask 1 on PARAMETERS, re-cut DESIGN §12, filed #53, and closed #50 at 07:53:49Z. I judged the block's claims at d8ea572 and note where ba7dfc4 changed things.

## Per-claim table

| # | Claim | Verdict | Evidence |
|---|---|---|---|
| 1 | Paste of 05:09 UTC on harness.md, three items | HELD | ad0bb58's S1 paste: (1) the narrowing, (2) the Gadget, (3) #50 |
| 2 | Ran in the continued session e9453b81, not a fresh window (D126) | HELD | The paste asks for a fresh window; the JSONL is this session's |
| 3 | One compaction at 06:33:41Z, 967,046 → 15,560 tokens `[M]` | HELD | compact_boundary at 06:33:41.634Z, preTokens 967046, postTokens 15560. The sitting began 05:11:54Z; the previous compaction was 01:13:48Z |
| 4 | Every commit by pathspec under the hooks, each stamp a `date -u` read | HELD | Every commit follows `git add <paths>`. No `-a`, no `--no-verify`. The hook refused two 203-character subjects (07:32:35, 07:43:29) and both were re-cut |
| 5 | Every Lean build under the Lean lock after the load gate, one slot, `LEAN_NUM_THREADS=2` | HELD | lbuild.sh, lb.sh and axcheck.sh gate on load under 20, then call `lean_lock_take`; the logs print `LEAN_NUM_THREADS=2` |
| 6 | a210516 has 74 imports; `git apply --check` OK; NEEDED list 73 = the 74 minus `Positivity.Basic` | HELD `[X]` | S2's patch applied to ad0bb58's Numbers.lean reproduces a210516 byte for byte. `comm` of the companion's NEEDED list against lines 1–74 leaves that one line. 72 Mathlib + 2 Batteries |
| 7 | d3a73e0 is the Gadget unchanged but for its provenance paragraph and 5 `#print axioms` lines | HELD `[X]` | The diff against S2's companion shows only lines 17–18 and the five trailing lines |
| 8 | Each patch carries its own spec pages; records at 1630e42 and 8e2e6ba | HELD | a210516 carries 6 pages, d3a73e0 carries 5; all four commits are ancestors of main |
| 9 | 2,501 modules, 980 Mathlib-side | HELD `[M]` | The companion's CLOSURE line. S2's figure was 2500/980. The Mathlib-side parts sum to 980 |
| 10 | Cold build 53.61 s vs 190.35 s; 3.55× wall, 3.29× resident set | HELD (ratios); PARTIAL (wording) | 190.35/53.61 = 3.551; 6,304,235,520/1,915,043,840 = 3.292. "Three minutes apart" is wrong: the two builds started 62 s apart (C14) |
| 11 | Axiom check 569 | HELD | 569 `#print` lines at 8e2e6ba; the box record's line |
| 12 | Leg of record at f3ded51, 21 legs GREEN in 172 s | HELD | Record lines 2–5. f3ded51 is 1630e42's pre-rebase twin, not on main; the byte-identity holds (C15) |
| 13 | Answered on #35 by comment 5884771006 | HELD | Posted on #35 at 06:15:48Z; its content matches the block |
| 14 | Design posted on #50 before the code, comment 5884618665, 06:02 | HELD | Posted 06:02:06Z. The first Impl file was written at 06:17:31Z |
| 15 | Landed 028bb1c (from 68580c4), 5900e66 (from db30924), 6370ab3 | HELD | All three on main. Impl/, Eval.lean and the root are identical to 68580c4 |
| 16 | Pushed c59a484..6370ab3 at 07:43:47; lock taken 07:34:02, released 07:43:49; leg inside the hold | HELD | Session log: "TAKEN by S1 at 07:34:02 UTC after 0s", the push output, "07:43:47", "released by S1 at 07:43:49 UTC". The leg ran 07:39:19–07:42:25 |
| 17 | Answered on #50 by comment 5885942011 | HELD | Posted on #50 at 07:46:39Z |
| 18 | Impl/ is eight modules, 2,258 lines | HELD `[X]` | 153+148+244+273+603+143+139+555 = 2,258 |
| 19 | Stack held as an `Array Bytes`, bottom-first; element k is one index; depth is `size` | HELD | `IState.stack : Array Bytes`; `topArr` reads `a[a.size-1-k]` |
| 20 | `execStepI_eq`; `loopI_rel` (same outcome always, same state at `.ok`) | HELD | Machine.lean:290; `LoopRel` at :332 |
| 21 | `phase2Gen`/`verifyScriptGen` equal by `rfl`, the `_congr` lemmas, `verifyScriptA_eq` | HELD | `phase2_eq_gen` and `verifyScript_eq_gen` are `rfl`; `verifyScriptA_eq` at :597 |
| 22 | `opExecI_refines` and `@[csimp] verifyScript_eq_I` | HELD | In the Eval.lean diff |
| 23 | Dispatcher change (`owns`, `dispatch_abs`) | HELD | State.lean:542; six `owns` definitions |
| 24 | No definition of the semantics moves | HELD `[X]` | 028bb1c's lean numstat has 0 deletions; Machine.lean and Ops/* are untouched |
| 25 | Axiom check 688 at the landed tree, #50's 115 | HELD | `#print` lines: 573 at c59a484, 688 at 028bb1c. 113 Impl theorems + 2 in Eval, all listed, no duplicates |
| 26 | spec/ committed with the code; `specgen --check` OK (117 files) | HELD | 028bb1c's stat; box record line 36. `spec` on S1's OWNERS line since 5a34fc1 |
| 27 | Siblings' figures: 21.84→4.37, 23.13→3.17, 8.63→4.48, 3.02→1.35, 10.44→3.73; all valid | HELD `[M]` | The raw session-log lines, 07:21:10–07:22:39 |
| 28 | Peaks 4 % to 8 % lower | HELD | 4.35, 5.86, 5.15, 8.10, 5.51 % |
| 29 | Stack 3.1 % of samples; codec 89 % | PARTIAL | `execStackI` 57/1,819 = 3.13 %. 89 % is `binaryI` inclusive; the codec's two calls are 87.7 % (C11) |
| 30 | Ladder 250 kB to 256 MB, both evaluators the same hour, all valid | HELD `[M]` | 22 raw lines, 07:25:35–07:30:37 |
| 31 | 12.6 % to 13.1 % fewer instructions from 500 kB up | HELD `[D on M]` | 12.65 % (2 MB) to 13.15 % (64 MB) from the raw counts |
| 32 | Reach: 255,999,976 B valid in 39.26 s at 17.20 GB (old binary 44.33 s at 14.51 GB) | HELD `[M]` | Raw lines; K = ⌊256e6/55⌋ = 4,654,545; lock = 55K+1 |
| 33 | PARAMETERS §1 is S3's page | HELD | OWNERS S3 line; landed by S3 at ba7dfc4 |
| 34 | Box leg: 102 ms, 186 s, axiom check 688 | HELD | Box record lines 3, 12, 16 |
| 35 | 176 ms on the Studio (182 ms before #50) | HELD `[M]` | Measured at 68580c4: legs-new2 176 ms, legs-old 182 ms |
| 36 | Fourteen verdict legs byte-identical to the pre-#50 binaries | HELD `[M]` at 68580c4 | "14 same" at 07:27:45 (the 07:27:38 diff failed on `uniq -w` and was re-run) |
| 37 | Cite leg 1,733 anchored, MOVED 0, at 5900e66 | HELD | Session log 07:42:50 |
| 38 | (i) The lock file sets no exit trap since abafd910 | HELD | abafd910 (04:00 UTC): "the helper's own exit trap retired" |
| 39 | (i) Slot held idle 05:17:05 to about 05:36:50; S2 broke it at 05:37:32 | PARTIAL | S1's TaskStop was at 05:37:32.227Z. At 05:36:52 the process group (92584, axcheck.sh 99680) was still alive. The holder "S2 … 05:37:32Z" was read at 05:37:40 (C1) |
| 40 | (i) Every script since sets the three traps | HELD | lbuild, lcheck and axcheck patched at 05:38:04; lb.sh, ladder50.zsh and box_leg3.zsh carry them |
| 41 | (ii) Force-with-lease moved lean-a-50 db30924 → 6370ab3; lean-a-50-pre = db30924, pushed after the landing | HELD | ls-remote; db30924 is not an ancestor of 6370ab3; commands at 07:43:44 and 07:45:28. The landing record still says "never force-pushed" (C2) |
[withheld at export: a sibling tree's line]
| 43 | Compiled evaluator is array-backed at every compiled call of `Eval.verifyScript` | HELD | Callers: Bsvs/Run.lean:173 and Test/{Flow,Crypto,TxTests,Witness}Check; the csimp sits at Eval.lean's end |
| 44 | (c)(1) #50 stays open until the sentence lands | HELD at writing | Now superseded: S3 closed #50 at 07:53:49Z |
[withheld at export: a sibling tree's line]
| 46 | (c)(3) The five DESIGN sentences made false | PARTIAL | All five read at d8ea572. (i), (ii) and (v) hold; (iii) and (iv) are incomplete or imprecise. Two sets of false sentences are missing: three more §12.1 rows and §12.4's "(design)"/"prototype" wording (C4–C6, C8, C9) |
| 47 | (c)(4) "S2's two patches" | PARTIAL | There are three: 7baa0b3 carries both the lens32 and the hexloop patch (C7) |
| 48 | Ask 1's sentence | HELD (figures) | 57–85 bytes per lock byte and 57–85 GB re-derived; consensus.h:15,17,29 at 879fc8b42 gives 1,000,000,000 B `[SRC]` (C13) |
| 49 | Ask 5: leg lock taken 5 minutes into the hold; sitting 5's ask 6 still stands | HELD | 07:34:02 → 07:39:19 = 5 min 17 s; no ruling found in the plan docs |
| 50 | (f) No Modal app of S1's; block.sh at 07:39:38 lists three apps | HELD | block.sh output in the session log; my `modal app list` at 07:59:29Z shows the same three; no Modal command in the sitting |
| 51 | THE MACHINE line (uptime, df, git status, stamp) | HELD | Session log 07:47:06 and 07:47:12 |

## THE CORRECTIONS

**Load-bearing**

1. **"stood held and idle from 05:17:05 to about 05:36:50 UTC (S2's take broke it by the dead-pid rule at 05:37:32)"** (Named, not hidden (i)).
   - Right value: held and idle from 05:17:05 to 05:37:32 UTC, 20 min 27 s. S1 stopped the command at 05:37:32.227Z and S2's waiting take broke the slot the same second (holder stamped 05:37:32Z) `[M]`, session log e9453b81.
   - The #35 record's "at about 05:36:50" needs an appended Correction.

2. **The landing record's "pushed first at origin/lean-a-50, never force-pushed"** (docs/records/20260929-074303-landing50-s1.txt, cited in (a) item (3); contradicted by the block's own (ii)).
   - Right value: after the record's commit, origin/lean-a-50 moved db30924 → 6370ab3 with `--force-with-lease` `[X]` (ls-remote; not a fast-forward).
   - The record needs an appended Correction; records are never edited.

3. **"EXECUTED: … #50's four items, but item (3)'s page sentence."** ((b)).
[withheld at export: a sibling tree's line]
   - S3 closed #50 at 07:53:49Z saying "the four done-bar items stand", so this sentence mattered.

4. **"§12.1's table row "`BsvScript` … 33 (with the root)" (now 42…)"** ((c)(3), ask 3). The list is incomplete.
   - Because Eval.lean imports the Impl modules since 028bb1c, three more rows are false: `BsvScript.Eval` 17 → 25, `BsvScript.Flags` 19 → 27, `BsvScript.TxPolicy` 23 → 31 `[X]`.
   - Method: closures from the modules' import lines, which reproduces b3406bf's column exactly (4/5/9/14/17/19/23/33).
   - All three rows still read 17/19/23 at ba7dfc4.

5. **(c)(3)'s list omits §12.4's "*(design)*" and "Items 1 to 4 are compiled against `main` as a prototype … (the module its companion)".**
   - Both are false since d3a73e0: the module is on main and its five theorems are on the axiom list `[X]`.
   - S1's own comment 5884771006 named both; the block dropped them. Both still stand at ba7dfc4.

6. **"now 2,501 and 980 at S1's tree with both hunks"** ((c)(3) §12.3).
   - Right value at main since 028bb1c: 2,509 modules, 980 of them Mathlib-side `[D on M]`. That is 2,501 at #35's tree (the companion's CLOSURE line) plus the eight Impl modules, which import only BsvScript modules.
   - The fold wrote this into DESIGN §12.3 at ba7dfc4 as "since then `import BsvScript` loads 2,501 modules", which is false since 028bb1c.

7. **"S2's two patches for S1's files … the HashLock worked example … and #32 lens 1's patch (7baa0b3 …)"** ((c)(4), ask 4).
   - Right value: three patches `[X]`. They are the HashLock module (27d93f7's companion), `…-lens32.patch.txt`, and `…-hexloop.patch.txt` (item (3)'s S1 half, S1's own sitting-5 ask 7). 7baa0b3's record says "The two patches".
   - The fold's sitting-7 paste already carries three.

**Cosmetic**

8. **"§12.2 (2)'s list of the compiled copies (now also BsvScript.Impl …)"** ((c)(3)). At d8ea572 the list also lacked #48's 14 depth-test copies over `Machine.atLeast` `[X]`. The fold added them.

9. **"§12.3's surface at b3406bf (10,777 modules, 8,908 Mathlib-side; …)"** ((c)(3)). Those figures are scoped "at b3406bf" in §12.3's header, so they are dated, not false. What the landing made false there was "`Numbers.lean:1`" and "S1's file, sent up" (both named in 5884771006; the fold re-cut them).

10. **"(S2's and S3's page …)"** ((c)(3), ask 3). docs/DESIGN.md sits on the S2, S3 and S4b lines of docs/OWNERS `[X]`.

11. **"`Arith.binaryI`'s number codec 89 %"** (item (2); also (b) and ask 2). `binaryI` is 89.1 % inclusive (1,620/1,819). The codec's two calls are 87.7 % (encodeFast 844 + readOperand 752 = 1,596/1,819) `[M]`, impl-50 record, sampler paragraph.

[withheld at export: a sibling tree's line]

13. **"the time is linear in the size"** (ask 1, now on PARAMETERS §1).
    - It holds only to 128 MB (0.110–0.127 s per MB). The 256-MB step took 2.75× the 128-MB one (39.26/14.30) `[D on M]`.
    - "57 to 85 bytes per lock byte" spans three 256-MB runs of two binaries; #50's own is 67.2 `[D on M]`.

14. **"one tree, one machine, three minutes apart"** ((a)). Two scratch copies differing in Numbers.lean alone, run back to back, started 62 s apart (05:41:35 and 05:42:37 UTC), at loads 8.23 and 12.04 `[M]`, #35 record.

15. **"`make check-box` at `f3ded51`"** ((a)). Should say that f3ded51 is 1630e42's pre-rebase twin (on origin/lean-a-s6-l2, not main). The trees differ only in S2's six docs paths, and the legs' paths diff to exit 0 `[X]`.

16. **Items (2), (3), (4): the Studio figures and the ladder's "new" column** are 68580c4's binary. 028bb1c adds S2's 17db102 in six lean files (Flags, Sighash, Tx, TxRules, Eras, P2SH) `[X]`. Only the leg of record (5900e66) ran the landed tree.

17. **"(#50's 115 lines)"** ((1)). 115 `#print axioms` lines out of 124 lines added (nine are section comments) `[X]`.

18. **"this landing did not need it"** (ask 5). True of #50's landing. #35's landing did use a byte-identity over a main that moved inside the hold (892eaff, docs only) `[X]`.

19. **The #50 landing record names the take (07:34:02) but defers the release time to the block** (RULES-TREE (25)). The block's 07:43:49 is confirmed by the session log `[X]`.

Key files:
[withheld at export: a sibling tree's line]
[withheld at export: a sibling tree's line]
[withheld at export: a sibling tree's line]
[withheld at export: a sibling tree's line]
