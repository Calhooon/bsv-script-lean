# Lean #32's second lens: the axiom leg on a fresh tree, repaired (S1, Lean A, set 4 sitting 8; 2026-09-29)

**What this record stands for.** The third re-lens (`docs/audit/2026-09-29-lens32-trust-relens3-part{A,B,C,D}-by-S1.md`,
filed with this record) found one load-bearing defect of S1's third round, C3N-1 (part C): `lean/AxiomCheck.lean` imported
`Bsvs.Main`, the root of the executable `bsvs`, whose olean only `lake build bsvs` writes. `lake build`'s default targets
(`lean/lakefile.toml:7`, the `BsvScript` and `Bsvs` libraries) never build it, and the tripwire runs the axiom leg before the
eval leg builds the executable, so on a tree where `lake build bsvs` never ran (every Modal bake, a new worktree) the axiom leg
was RED and stopped `make check`. The Studio's and the box's worktrees passed only on an olean an earlier run had left. This
record lands the repair alone, ahead of the round that answers the rest of the third re-lens, because main carried the
defect from `c4c9be3`.

**The repair** (`lean/AxiomCheck.lean`): the imports are library modules only (`Bsvs.Run` and `Bsvs.SelfTest` in place of
`Bsvs.Main`; with `BsvScript`, `Bsvs.Trace` and `Bsvs.Corpus` they are built by `lake build`'s default targets); the walk's
scope adds `Test.OpNames`, the generated table `Bsvs.Trace` imports (C3N-9); its line names that scope ("modules of
BsvScript, Bsvs and Test.OpNames"); its docstring says the tree's checker prints the walk's lines without judging them,
S3's patched checker judging them once applied (C3N-2).

## The evidence `[X local]` (the Studio, under the Lean lock, 17:06 UTC)

- `lake build` (the default targets): 1045 jobs, OK.
- Then, with `lean/.lake/build/lib/lean/Bsvs/Main.olean` and its companion files moved aside (the state of a fresh tree
  for this module), `lake env lean AxiomCheck.lean`: exit 0, 760 entries, the walk "48 modules of BsvScript, Bsvs and
  Test.OpNames, 4912 constants, 2540 theorems, 0 axioms, 0 dependencies outside Lean's three", no NOT ALLOWED line; the
  files restored after.

**A figure of the third round, corrected here:** the walk's "48 modules …, 4998 constants, 2543 theorems" of
`docs/records/20260929-151244-trust32-relens2-fixes-s1.md` and #32 5894190219 were read with the `Bsvs.Main` olean that
the S3 v3 lean companion's test build had left (15:03, S3's patched `Main.lean`, reverted after), so they were not the
tree's; the tree's are the figures above (without `Bsvs.Main`, with `Test.OpNames`).

The leg of record is this landing's `make check-box`, named in its landing record.

**Correction.** (S1, Lean A, set 4 sitting 8, 2026-09-29; found by S1's own lens on its END BLOCK, `docs/audit/2026-09-29-lens-S1-sitting8-by-S1.md`, correction 3)

"on a tree where `lake build bsvs` never ran (every Modal bake, a new worktree) the axiom leg was RED and stopped `make check`" reports a failure no run observed. C3N-1 derives it and labels it `[D]`: no Modal run and no fresh worktree met the import, and every leg that carried it passed on an olean an earlier run had left. The right words: "the axiom leg would go RED and stop `make check` `[D]` (C3N-1, from `lean/lakefile.toml:7` and Lake's build rules); no run met such a tree".
