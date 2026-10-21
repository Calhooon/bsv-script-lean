# The landing of S3r2's redesign of `corpus/gen` on `main`: the tip re-evaluated, and three sentences of its record superseded (S3, set 4 sitting 2, 2026-09-27 08:36 UTC)

**What this record stands for.** The parent's landing of the Opus run S3r2's four commits (`6061e03`, `9864cc9`,
`309c60d`, `b7cfed3` on `origin/harness-r2`, rebased onto `main` at `bf25201` as `d39ffdb`, `26b95e7`, `2e86f30`,
`4d8bbea`, with `spec/README.md` regenerated at `fe3e3a5`) after the parent's fresh-context lens on them
(`docs/audit/2026-09-27-lens-S3r2-by-S3.md`: HELD IN SUBSTANCE, 6 corrections). Two things a page may cite from here:
§1, the evaluator at the tip re-deciding every entry of `corpus/gen` (the lens's must-know 7, made `[X]`); §2, the three
sentences of S3r2's record `20260927-044619-gen-redesign-s3r2.md` this record SUPERSEDES (that record is never edited,
by this directory's rule; its README row names this one).

## 1. `corpus/gen` through the evaluator at the landing tip: the recorded `spec@8389375` columns reproduced

S3r2 recorded the spec's two columns of `corpus/gen` under the key `spec@8389375`; the rebase put its commits on top of
`main` at `bf25201`, where `lean/` had moved since `8389375` (10 files: doc comments, theorems, `TxPolicy`'s two
`NodeConfig` fields, and `Bsvs.Run.txGate`'s mempool path meeting the policy caps at `4d3a833`; `eval/` unchanged). The
landing tripwire (`20260927-071724-make-check.txt`) replays gen's RECORDED spec verdicts and so never re-evaluated gen at
the tip; the lens argued `[D]` that the move cannot change them. This run makes it `[X]`.

- **the commit:** `fe3e3a5` (the rebased chain's tip; `lean/` and `eval/` identical to the landing commit's, which
  touches neither), the evaluator built by the landing tripwire's Lean leg at this tip (build OK, sorry-free).
- **the command:** `/usr/bin/time -l eval/bsvs corpus corpus/gen/gen.jsonl --out <scratch>/spec-gen-fe3e3a5.jsonl`
  (the output outside the tree; nothing in the tree written).
- **the host:** the Studio, LOCAL (a small run: one process, under a minute); the 1-minute load 13.66 at the start
  (08:36:27 UTC), 12.21 at the end (08:36:54 UTC) `[M]` (`uptime` at each end).
- **the run:** `bsvs corpus: 1011 entries of corpus/gen/gen.jsonl under sv-mainnet-default, keyed spec@fe3e3a5`;
  **26.39 s real** (23.52 user), **peak 4,010,065,920 B** `[M]` (S3r2's run of the same corpus at `8389375`: 53.27 s,
  4,001,693,696 B, at another load).
- **the comparison** (`python3` over the two files: for each of the 1,011 entries and each column, the tip's
  `(verdict, code, input)` against the recorded `spec@8389375` / `spec-mempool@8389375` cell in `corpus/gen/gen.jsonl`):
  **2,022 cells, 2,022 identical, 0 differ** `[X]`; the transaction gate beside the script verdict reads `valid` on all
  1,011 entries in both columns `[X]` (the policy caps the tip's mempool gate adds cannot fire on gen: its largest
  transaction is 1,066 bytes, and its three pre-UAHF spends, gen-00994 to gen-00996 at height 478,558, are the only
  spends below the Genesis height, where the constant sigop cap applies, at 369 and 370 bytes `[X]`, with 3 inputs each
  as the lens read them).

So the key `spec@8389375` stands for the tip's evaluator on `corpus/gen` by execution, not only by argument. The key is
kept: re-keying 1,011 entries to a commit whose verdicts are identical would move every line of the corpus and its
witness files for no change of fact.

## 2. Three sentences of `20260927-044619-gen-redesign-s3r2.md`, superseded here

Each re-derived by the parent from the files S3r2 left in `~/bsv/targets/spec-harness-r2/scratch/` and from the
manifests at `9864cc9` and `309c60d` (the lens's corrections 2, 3 and 4):

1. **The host line's "every step gated on the 1-minute load under 20 (each start's value on its line below)"** is
   overstated. Right: every step but one was gated; the ts-sdk `--dump` run of ≈ 05:51:22 UTC (the dump §4 compares
   with the run of record) has no load reading and no gate file (`scratch/r2/` holds `run_diff.gate` 4.71 at 04:46:38,
   `gosdk.gate` 4.35 at 04:47:08 and `tssdk.gate` 4.89 at 05:49:52 UTC, nothing at 05:51) `[M]`; the go-sdk run's polls
   "3.40 to 12.16" are kept by no file.
2. **The host line's "7.29 at the last differential's start (06:50:32 UTC)".** Right: 7.29 at `rules_check`'s start
   (06:50:32 UTC, `scratch/r3/rules_check.gate`); the last differential, `run_svnode`, started at 06:49:49 UTC at 9.19
   (`scratch/r3/svnode.gate`) `[M]`.
3. **§5's "Every other class of the four manifests on `gen` is unchanged"** needs its missing clause: the ts-sdk
   manifest's gen walls moved, `adapter_timeout_s` 120 → 60 and `adapter_timeout_rerun_s` 1,200 → 600, with no effect
   (`timeouts` 0 and `timeouts_decided_on_the_10x_rerun` 0 on both sides) `[X]` (`git show 9864cc9:` and
   `309c60d:corpus/witnesses/ts-sdk/manifest.json`).

## 3. What else the landing carries (the lens's other corrections and must-knows, for the pages that cite them)

- **The applicable count** (correction 1): `corpus/INDEX.md` §1 and §4 read 1,006 applicable to bsv-rs (1,011 − 5
  undecided: the two pre-Genesis coins and the three pre-UAHF spends; per column 1,006 = 6 resource aborts + 26 other
  divergent + 974 agree) `[X]` from the manifest. S3r2's row wrote 1,003: the row's 1,000 plus the three appended
  entries, and that 1,000 was itself a slip, written at `e74a503` for 1,008 − 5 = 1,003 (`0cbee92`'s row had kept the
  first cut's 954) `[X]` (`git show <c>:corpus/INDEX.md`; the lens placed the 1,000 at `0cbee92`, where the row read 954).
- **The vocabulary row** (correction 6): `limits.maxscriptnumlength`'s source cell in `corpus/INDEX.md` §2 (rendered into
  `spec/rules.md`) now cites the two sites its 17 gen entries reach since the redesign, `interpreter.cpp:1786–1790`
  (`OP_BIN2NUM`'s result, minimally encoded, tested at the width) and `script_num.cpp:161–165` (the sum's size tested at
  the width), both read at the pin `879fc8b42` `[SRC]`.
- **`2e86f30`'s message** (correction 5): its `spec/` bullet is true of `309c60d`, not of the twin. The twin carries
  `spec/rules.md` alone (the eight docstring pages were already on `main`); `spec/README.md` reads "13765 generated
  corpus entries" at `2e86f30` and "13768" at `fe3e3a5` `[X]`, so `specgen --check` would read it STALE at `2e86f30` and
  `4d8bbea` (not run there, `[D]`), fixed at `fe3e3a5` by the regeneration. The chain is pushed whole, never a prefix (`d39ffdb` and `26b95e7` are RED on the ts-sdk gen replay by
  their own pre-flight messages; the tip is GREEN).
- **The pre-rebase run:** `20260927-065907-make-check.txt` is the tripwire at `309c60d`, a pre-rebase twin: history, never
  the stamp. The stamp on `main` is the tripwire at the landing commit (its record row names the commit).
