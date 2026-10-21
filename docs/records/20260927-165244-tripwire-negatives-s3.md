[export: 2 lines withheld by tools/export_public.py, the sibling trees' lines; the original is in the private history]
# The tripwire's negative tests at the tip, and the axiom leg's blind spot they found (S3, set 4 sitting 3, on Opus 5.5; 2026-09-27 16:52 to 17:11 UTC)

[withheld at export: a sibling tree's line]

The planted theorem is `BsvScript.Properties.coverage` (`lean/BsvScript/Properties/Coverage.lean:37`). It is listed in `lean/AxiomCheck.lean:104`, and its module is a leaf of the library. No planted change was committed anywhere.

## 1. The runs

| run | the tree | the plant | the verdict `[X]` | wall `[M]` | app |
|---|---|---|---|---|---|
| 1 | `ccd6e41` (main) + 1 uncommitted path | `sorry` for `decide` in `coverage` | **RED at the lean leg** (`warning: BsvScript/Properties/Coverage.lean:37:8: declaration uses 'sorry'`, then `lean: a sorry is in the build log; main must be sorry-free`), rc 2 | 111 s | `ap-fctFH0Ne2BsPjuKk3AvcWR` |
| 2 | `ccd6e41` + 1 uncommitted path | `axiom planted_negative_test : False`, `coverage` proved by `planted_negative_test.elim` | lean GREEN (`build OK, sorry-free`); **RED at the axiom leg**, `axiom check: FAILED, 1 theorem(s) depend on axioms outside AXIOMS-ALLOWED`, rc 2 | 123 s | `ap-IfvyZGeg8actCLZ5SwxHVY` |
| 3 | `66a4ad7` (the fix below), committed tree | none | **GREEN**, twenty-one legs; `axiom check --self-test: OK`, `axiom check: OK (394 theorem(s); …)` | 513 s | `ap-q1PHJTxlAWmjg1YPr0EpsJ` |
| 4 | `66a4ad7` + the plant of run 2 | the same axiom | lean GREEN; **RED at the axiom leg**, `axiom check: FAILED, 5 theorem(s) depend on axioms outside AXIOMS-ALLOWED`, rc 2 | 123 s | `ap-1DL3ccCCZKLMnXOIelJKdN` |

Each run's record, written by `tools/check.sh` in the container and brought home unchanged:
- `20260927-165244-make-check-modal.txt` (run 1)
- `20260927-165519-make-check-modal.txt` (run 2)
- `20260927-170019-make-check-modal.txt` (run 3)
- `20260927-170915-make-check-modal.txt` (run 4)

[withheld at export: a sibling tree's line]

Run 4's record counts 9 uncommitted paths, not 1. The other 8 were tracked records that the parent's script moved out of the scratch worktree's `docs/records/` between runs 3 and 4, so they were shipped as deleted. They were restored after. No leg that decides run 4's verdict reads them: the axiom leg reads `lean/`, and the cite leg is skipped by name in the container.

The price is ≈ $0.032 + $0.035 + $0.145 + $0.035 = **$0.247** `[D]`, at the route's rates.

## 2. The blind spot (run 2) and its fix

In run 2, a domain axiom was planted in one listed theorem and reached FIVE listed theorems. The tool flagged ONE. The full log reads:
- `BsvScript.Properties.coverage: ['BsvScript.Properties.planted_negative_test']  <-- NOT ALLOWED`
- four more listed theorems that also depend on the planted axiom: `execFlow_ne_unimpl`, `execStep_ne_unimpl`, `loop_ne_unimplemented`, `evalScript_ne_unimplemented`. Their `#print axioms` output WRAPS across lines (`'…' depends on axioms: [propext,` and the rest below). The tool read one line at a time, so it printed those lines but never judged them `[X]`.

The leg went RED on the one it did judge. Had the axiom reached only theorems whose lists wrap, the leg would have been GREEN. Nothing compared the number of entries judged with the number of theorems listed.

**The fix, `66a4ad7`** (`tools/axiom_check.py`, the parent's):
- The output is parsed whole: an entry is judged whatever its lines.
- The leg is RED unless the entries judged equal `lean/AxiomCheck.lean`'s `#print axioms` lines, one each, in order.
- `--self-test` runs the parser on a fixed sample (a wrapped list with a planted axiom among single-line ones) without Lean. `tools/check.sh`'s axiom leg runs it before the check.

Run 3 is the fix's tripwire, GREEN at 394. Run 4 flags all FIVE `[X]`.

**THE LANDING RULE.** `66a4ad7` (kept on `origin/s3-axiom-parser`, A19) landed as `b38a85e`, rebased over S1's A23 guard (`1f040de`, `eval/` only) and two record commits. `git diff --quiet 66a4ad7 b38a85e -- ':!eval' ':!docs'` exits 0, so every leg reading neither stands by run 3. `git diff --quiet fb7c711 b38a85e -- eval` exits 0, so the legs that read `eval/` stand by S1's record `20260927-165451-make-check-modal.txt` at `fb7c711`. The cite leg, which reads `docs/`, was re-run on the Studio at the landed tree: GREEN, 1,778 anchored and holding at the pin, MOVED 0 `[X]`. Its anchored count fell from 1,992 with D135's redaction of the conformance report (`ccd6e41`): the withheld rows' citations left the page, 638 citation shapes to 435 `[X]`, leaving 11 orphan rows, which are reported and never RED. The four wrapped entries recovered from run 2's own log are all flagged by the new parser `[X]`.

## 3. The planted diffs (never committed)

Run 1:

```
 theorem coverage : ∀ op, op < 256 → Op.hasCase op = true → (flowOwns op || hookOwns op) = true := by
-  decide
+  sorry
```

Runs 2 and 4:

```
+/-- THE TRIPWIRE'S NEGATIVE TEST (a planted domain axiom; never on any branch). -/
+axiom planted_negative_test : False
+
 set_option maxRecDepth 16384 in
 /-- **Coverage.** Every byte with a `case` label is a flow opcode or a family's. -/
 theorem coverage : ∀ op, op < 256 → Op.hasCase op = true → (flowOwns op || hookOwns op) = true := by
-  decide
+  exact planted_negative_test.elim
```
