[export: 1 line withheld by tools/export_public.py, the sibling trees' lines; the original is in the private history]
<!-- S1'S OWN LENS ON ITS SITTING-2 END BLOCK (LANE F, set 4 sitting 2; S1 the Lean A sub-agent; 2026-09-27). A fresh-context, READ-ONLY lens: a Claude Code subagent of S1's sitting-2 session on Fable (the Agent tool, general-purpose, model fable), launched 04:23:36 UTC and returned 04:53:09 UTC, its wall 1,773 s [M] (the tool's usage line: 1,773,220 ms, 147 tool uses). Its brief: the paste's rule (6) verbatim ("verify every claim against origin/main and the tracker by REST; HELD / NOT HELD / PARTIAL / UNVERIFIABLE per claim with the evidence; re-derive every number; the corrections as a numbered list with the sentence, the site and the right value with its label"), on the section `### S1 END BLOCK (2026-09-27T04:20:28Z)` of `docs/lanes/lean.md` with its `**Next**` paragraph and the sitting-1 corrections it landed, read against origin/main `06f7c18`. FILED AT SITTING 3 (S1, 2026-09-27 12:42 UTC; the parent's lens, `docs/audit/2026-09-27-lens-S1-sitting2-by-S3.md`, correction 2): the report below is verbatim, as the lens returned it, extracted from the sitting-2 session's stored subagent transcript (its final message); nothing of it is edited. Its eleven corrections landed at `c5eae24` (the record `docs/records/20260927-054108-make-check.txt`) and as three `**Correction.**` comments (#27 5853116684, #25 5853117172, #45 5853117900); the parent's lens found that the orphan rows its correction 1 names read `ok` again once the block's own sentences cite them, the one real orphan being `lean/BsvScript/Ops/Arith.lean`'s `script_num.h:66–70`, opened by `c5eae24`'s re-cut (landed on the block at sitting 3). -->

**Verdict: HELD IN SUBSTANCE.** I re-derived every commit, record figure, axiom count, comment id, `[SRC]` line and the Modal charge the block names, and all of them match. One claim does not hold: ask 5 names the wrong two orphaned anchor rows. Several attributions are imprecise, and there is one real gap in the modelling: the policy gate's sigop count after Genesis.

## Per claim

**(a) CLOSED WITH EVIDENCE**
- All ten commits are on origin/main, and every path they touch is on S1's OWNERS line (`docs/OWNERS:8`) or the shared `docs/records`: HELD [X]. The root file went onto S1's line at `2ae5386` (W0, 02:00:12 UTC): HELD.
- The account move (parked 15 min, resumed 02:59 UTC): UNVERIFIABLE, but consistent. The first `c6374f5` was authored 02:44:16, and `b29bd7f` (the rebase onto `73418b8`) was committed 03:02:37.
- `aa29bab` contents: HELD [X].
  - It adds 73 lines to `AxiomCheck.lean`: a 4-line header plus 69 `#print axioms` lines. After dropping two prose lines, the 69 names are identical to S2's list.
  - `Crypto.lean:60–61` now cites `293–294`, `300–301`, `302–303`, `305–306` [SRC]; I read `interpreter.cpp:291–307` at v1.2.2.
  - `Expansion.lean:34` now cites 611–616, 644–649, 669–674, 694–699, 730–735, and `765–771` is the OP_NOP1/9/10 case [SRC].
  - All 26 theorems of #45 carry a `/--` docstring (Numbers.lean 1034–1203, Machine.lean 532–703).
  - The C1 hunk sits at `BsvScript.lean:43–47` at `aa29bab` only. At the tip it is at `:52–56` (correction 7).
- `cbeb2c1`'s three new cites: HELD [SRC]. The negative-count test is 1527–1528, the limit test 1530–1532, the count read 1519–1526, the op-count charge 1534–1536. The old ranges are gone.
- The four records: HELD [X] on every figure (header lines 2–5 and 11 of each):

| record | commit | wall | load at start | axiom check | uncommitted paths |
|---|---|---|---|---|---|
| `023121` | `ecee407` | 356 s | 7.08 | 301 | 8 |
| `030242` | `b29bd7f` | 549 s | 5.82 | 349 | 3 |
| `040910` | `461c070` | 212 s | 6.51 | 387 | 12 |
| `041539` | `cbeb2c1` | 163 s | 4.67 | 387 | 12 |

  - All four are GREEN.
  - Twenty-one legs is right: `tools/check.sh:2–26` at `461c070` lists 21.
  - LOCAL is right: the files are `-make-check.txt`, not `-modal`, and the host is the Studio.
  - The README rows are 60, 63, 64, 66 and 67.
- `ecee407` is the pre-rebase twin of `aa29bab`: HELD. `ecee407`→`aa29bab` shows exactly the same 9-file diff as `beb1be1`→`f86445e`, the three commits the rebase crossed.
  - "S3's `f86445e` landing during the run" does not hold as written. The rebase crossed three commits: S2's `878aed5` (02:32:31) and S3's `a570130` (02:32:51), both committed during the run (02:31:21–02:37:17), and `f86445e` (02:37:21), committed 4 s after the run ended (correction 2).
- `b29bd7f` has the same code tree as `c6374f5`: HELD. `git diff b29bd7f c6374f5 -- lean harness corpus tools Makefile eval` is empty.
  - "Main moved during the run" is only partly supported. By commit date, `e7af519` (03:01:19) and `3460f85` (03:02:17) come before the run's start (03:02:42), and `732d670` (03:11:59) comes after its end (03:11:51). Push times are not in git.
- The five comments: HELD [X] by REST.

| comment | issue | posted (UTC) |
|---|---|---|
| 5851951753 | #26 | 02:25:39 |
| 5851951837 | #45 | 02:25:40 |
| 5852219614 | #27 | 03:14:33 |
| 5852250155 | #24 | 03:20:10 |
| 5852538695 | #25 | 04:13:24 |

  Each has the stated content.

**(b) THE STATE**
- "Ten corrections on this page, two Correction comments": PARTIAL. Nine corrections were replaced at their sites on this page (1–6 and 9–11). Correction 7 had no site on this page; it landed as #45's 5851951837 plus a new pointer sentence (correction 3).
- "Its 8 is S2's": HELD (`878aed5`). INDEX:37, README:49 and `harness.md:182` were landed by the parent at `700f876`: HELD.
- The GB unit:
  - Bytes over 10^9 for this sitting's records: HELD [M]. `031436-diff-s1.md:13–14` states the unit and gives 3.547 GB for `corpus/gen`.
  - "3,547,086,848 bytes": UNVERIFIABLE. The figure appears nowhere in `docs/`, `lean/`, `HANDOFF.md` or on #24/#45 (correction 5).
  - "Every peak on this page now in that one unit": HELD for S1's peaks. `:23`'s "4.5 GB peak resident" is W7's and gives no unit basis.
- The spec-gap `[SRC]` list: HELD at v1.2.2.
  - `policy.h:68` = 100000−1; `:70` = 10 MB; `:81` = 20,000/5 = 4,000; `:83–85` = UINT32_MAX and its default.
  - `config.cpp:60` is the default, `:2314–2338` the setter (its zero rule at 2329–2332), `:2345–2353` the getter.
  - `configscriptpolicy.cpp:57` is the default, `:397–413` the getter, `:415–446` the setter (its zero rule at 421–425).
  - The Teranode lines (`settings.go:97`, `:106`; `ScriptVerifierGoBDK.go:171`, `:175` at v0.15.9) and BDK's `txvalidator.cpp:453–467` at `cdfa781` also hold.
- `TxPolicy.lean` has eight theorems and each statement matches the block's T-TP2/3/4: HELD [X]. `tx-00035` is at height 610,000 with `sv-node-mempool` = `bad-txns-too-many-sigops`: HELD.
- #24's leg: HELD.
  - The Makefile loop at `:114` runs eight corpora.
  - `bytes` has no witness file, and specgen's list at `:175–176` counts nine corpora, which explains the paste's "nine".
  - 13,251 = 10,000+1,094+692+262+84+74+1,008+37 [D]; 26,502 = 2×13,251 [D].
  - `tx-00033` is 2,040,106 hex characters = 1,020,053 bytes [X]. Its 53.34 s and the 1,710 of 1,717 samples are the record's figures [M].
  - `Tx.lean:43` and `:56` test `bs.length < n`.
- #25: HELD [X].
  - `Resources.lean` has 38 theorems, all with `/--` docstrings, all on `AxiomCheck.lean`.
  - `#print axioms` lines: 387 = 232 + 69 + 40 + 8 + 38, counted at `94e6013`/`aa29bab`/`f9444ce`/`c6374f5`/`461c070`.
  - The statements match the block: `HookOpCount` and `HookMem` are named hypotheses, and `loop_depth_preGenesis` holds for any hook.
  - The principal cites hold [SRC]: 429–430, 466–467, 377–380, 1800–1803, 1815–1818, `script.h:32`, `limitedstack.cpp:194–207`, `limitedstack.h:43`, `:86`, `:163–173`, 1273–1274.
- Sitting 1's asks: HELD.
  - The 26 explainers are in `spec/theorems.md` from `f9444ce`.
  - `6c949a6` touched Run.lean and SelfTest.lean; `700f876` touched `arith_cases.rs` and the manifest; `58f05a3` touched `Sighash.lean` and `spec/modules.md`.
  - The rule-9 line is `OWNERS:15` (`6fa8f38`). A6 is recorded in HANDOFF.
  - Ask 7 is untouched by S3: no change to `gen.rs`.
- DECIDED, "the spec's count is the non-P2SH part": PARTIAL. It is the node's count on the pre-Genesis path only (correction 8).

**(c) OWED**
- (1) The `### S1 · the siblings' paths` heading is absent at `e6bed89`, `6fbdf60`, `526771b` and `06f7c18`, and also at the newer `45edc30`: HELD [X].
- (2) HELD [X].
  - `python3 tools/specgen.py --check` at `06f7c18` says STALE (12 files differ).
  - I regenerated into scratch; the 12 are `theorems.md` (38 explainers added, none removed), `modules.md`, `README.md` and nine opcode pages.
  - `loop_memInv` is absent from `spec/theorems.md`. S1's line has no `spec`.
  - All four README rows say the regenerated pages were uncommitted.
- (3) `validation.cpp:463–494` is `GetP2SHSigOpCount`: HELD [SRC]. The list leaves out the post-Genesis count path (correction 8).
- (4) and (5): HELD; the list matches 5852538695.
- (6) "Two rows orphaned by this sitting's re-cut cites": HELD literally (see ask 5 below).

**(d) BLOCKED:** HELD.

**(e) THE ASKS**
1. The signature, the reject codes and `TxRules.sigOpCountWithoutP2SH` all exist: HELD. "`txGate`'s mempool path" does not exist: `txGate` (Run.lean:127) takes no block/mempool flag, and it is computed once inside `runSpend` (:164) (correction 9).
2. HELD [X]: the scratch regeneration gives exactly twelve pages.
3. Both quoted sentences appear verbatim: PARAMETERS.md:10–13 and :159. HELD.
4. HELD. HYPOTHESES.md:23–24 reads 349 at `034013`, and DESIGN §5.5 is at :437.
5. NOT HELD. I parsed the anchors table (cite_check.py:519ff) against the sites.
   - The two orphaned rows are `docs/lanes/lean.md`'s `interpreter.cpp:765–771` and `spend.rs:190–192`. Both are present at `aa29bab~1` and gone at `aa29bab`.
   - The Crypto.lean and Expansion.lean cites are bare numbers. The citation pattern (`cite_check.py:48`) never matches bare numbers, so those cites never had rows (correction 1).

**(f) THE MONEY:** HELD [M].
[withheld at export: a sibling tree's line]
- The load of 21.71 is corroborated independently by S2's record `034013`: "sample 03:41:04 UTC: load1 21.71".
- The cost matches ≈ 24.9 min at the header's rate (16×0.00001314 + 32×0.00000222 $/s) [D], against 26 min for 03:41–04:07.
- "25–45 min" is marked `[EST]` in the header.
- The base was `e6bed89` and `dbe941a` (TxRules.lean) landed at 03:40:13: HELD.

**THE MACHINE:** self-reported. The uptime change since sitting 1 (+6:39 gives 4d 7:22) and df (12/(12+22) = 35%) are consistent [D].

**Next paragraph:** HELD. The replaced paragraph named the docstrings and the resource bounds. The #25 list matches 5852538695, and DESIGN §4.1 and HYPOTHESES §4 exist.

**Sitting-1 corrections (the lens's 1–7 and 9–11):** each original sentence is gone (a grep of all sixteen strings returns 0). 1, 2, 3 (brought up to date with `700f876`, verified), 4, 5, 9, 10 and 11 (`013117` is the first make-check record with `rules_check` lines; `700f876` added the prefix): HELD. 6 and 7 are HELD, but their new pointer sentences name the wrong comments (corrections 3 and 4).

## Corrections

1. **`lean.md` (e) ask 5, and records README:60.** Wrong: "two rows orphaned by S1's re-cut cites (`Ops/Crypto.lean:59–61`, `Ops/Expansion.lean:34`)" and "2 orphan rows: the two re-cut cites' old rows". Right: the rows are `docs/lanes/lean.md`'s `interpreter.cpp:765–771` and `spend.rs:190–192`, both removed at `aa29bab`. The Lean re-cuts are bare numbers, which cite_check never scans [X].
2. **(a) THE RECORDS, 023121, and README:63.** Wrong: "S3's `f86445e` landing during the run" and "(S3's `f86445e`, records, pages and two new tools…)". Right: the rebase crossed S2's `878aed5` and S3's `a570130` (02:32:31 and 02:32:51, during the run) and S3's `f86445e` (02:37:21, after it ended). The two new tools are `a570130`'s [X].
3. **Sitting-1 ask 7 (`lean.md:72`).** Wrong: "the cite the parent's lens corrected and 5850288958 carries as a `**Correction.**`". Right: "the cite 5850288958 carried, corrected on #26 by 5851951753" [X]. In the same vein, (b)'s "ten corrections on this page" should read "nine on this page, and correction 7 as 5851951837".
4. **Sitting-1 (a) (`lean.md:57`).** Wrong: "the README row and 5850287528's Correction cite it". Right: "the README row cites it (re-cut at `700f876`); 5850287528 cited it as 'lines 31–32', corrected by 5851951837" [X].
5. **(b) and the #45 LANDED paragraph (`:49`).** Wrong: "re-measured … at 3,547,086,848 bytes … `[M]`". Right: no record carries that byte count (rule 17; the paste's evidence rule). Cite `031436-diff-s1.md:13–14` instead (bytes over 10^9; `corpus/gen` 3.547 GB `[M]`), or land a record that carries the byte count.
6. **(a) THE RECORDS, 030242, and README:63.** "Main moved during the run by three commits" is not supported by the commit dates: two of the three were committed before the run started and `732d670` after it ended [X]. Right: "between the rebase base `73418b8` and the landing".
7. **(a).** Wrong: "`lean/BsvScript.lean:43-47`". Right: "`:43–47` at `aa29bab`" (`:52–56` at `06f7c18`) [X]. This is the same class of slip as the parent's correction 10.
8. **(b) DECIDED and (c)(3); also `TxPolicy.lean:40–42`, `:199` and #27 comment 5852219614.**
   - Wrong: "the spec's count is the non-P2SH part", and the "[D] … `UINT32_MAX` is out of reach … (at most 16 per two bytes…)" / "nothing reachable".
   - Right: after Genesis a multisig counts the preceding push's number, up to 2,147,483,647 from a 4-byte push (`script.cpp:79–113`). An unbalanced `OP_ENDIF`, or a count push that is non-minimal, over 4 bytes or negative, sets `sigOpCountError`, and the mempool refuses that at any cap (`script.cpp:55–63`, `validation.cpp:1243`) [SRC].
   - Three outputs of `04ffffff7f ae` (18 bytes) would count 6,442,450,941, which exceeds UINT32_MAX [D]. Unexecuted.
   - This belongs in OWED beside the P2SH part.
9. **(e) ask 1.** Wrong: "In `txGate`'s mempool path". Right: pass `consensus` from `runSpend` into `txGate` (Run.lean:127, :158, :164) and add the policy match on the `consensus = false` branch [X].
10. **`Resources.lean:672`** (outside the block, but in this sitting's module). Wrong: `script_num.h:66–70`. Right: `script_num.h:65–69` for `operator=(int64_t)`. OP_WITHIN's boolean is `vchTrue`/`vchFalse`, `interpreter.cpp:402–403` and `1396` [SRC].
11. **`TxPolicy.lean:155`** (outside the block, but in this sitting's module). Wrong: `534–536` for the oversize refusal. Right: `536–537`, with the comment at 535 [SRC].

## Must-knows
- **`make check` fails on a clean checkout of main.** At `06f7c18` the spec leg is STALE [X]. Each "GREEN at `<commit>`" record is GREEN for the commit plus 12 uncommitted spec pages. That stays true until the parent runs `make spec`.
- **Rule 1 caveat on the size cap.** `txPolicyGate` refuses `tx-size` unconditionally.
  - The node refuses a non-standard transaction only when `!GetAcceptNonStandardOutput(era)`, or after Genesis with `requireStandard` set and a reason other than "scriptpubkey" (`validation.cpp:1081–1089`, `configscriptpolicy.cpp:468–471`).
  - Before Chronicle, the version test runs before the size test (`standard.cpp:431–439`).
  - The two agree on `svMainnetDefault`. They differ on `requireStandard = false`, which is the model's own `teranodeDefault` [SRC].
- **Striking the row.** The parent should not strike `tx.gate.policy-caps.unmodelled` on the strength of ask 1 alone: after Genesis, the count and error path in correction 8 remain unmodelled.
- **Bare-number cites are unchecked.** They are invisible to cite_check, so "1,062 anchored, 0 moved" says nothing about S1's re-cuts. I re-read them by hand.
- **Stale count on HYPOTHESES.md.** It says 349 while two records say 387. S1 co-owns the page (`OWNERS:8`), so ask 4(c) need not wait for S2.
- **Record `031436:40`.** It says `tx-00033`'s key is "(`bad-txns-oversize`, both columns)". The recorded keys are `valid`; `bad-txns-oversize` is the separate gate field. Records are never edited, so only README:64 can carry this.
- **5850287528, item (2).** It still says "'12–19 GB' was S3's range over the three records" and mixes GiB with GB.
- **The two Correction comments predate the landing.** They were posted at 02:25Z, 13 minutes before `aa29bab` landed with the re-cuts they announce.
- **`58f05a3`'s "21:57 UTC".** That is its author time. It landed at 22:05:40, after `b244b7a`, so the parent's premise that it was already landed when S1 re-cut its block was wrong. "Answered" still stands.
- **origin/main has since moved** to `45edc30` (S3, 04:26 UTC; HANDOFF and a harness.md addendum). The siblings' heading is still absent.
