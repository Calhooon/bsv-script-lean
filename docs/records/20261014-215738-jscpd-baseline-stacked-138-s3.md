# The jscpd baseline re-cut at wave 1's second stacked landing (S3, lane land-w1b2, Claude Opus 5.5, [X] 2026-10-14 21:57 UTC)

Cited by docs/LINT.md §1 (the jscpd row), §1a (the baseline and the threshold paragraphs) and §3 (the jscpd row). Lane land-w1b stopped on this leg: `jscpd: RED: 5.215% duplicated lines (2749 of 52714) in 141 files ..., 259 clones; the threshold 4.25%`. The captain's decision (2026-10-14 21:5xZ): re-cut the baseline to the stacked tree's reading, the threshold just above it by the page's margin rule, and record what raised it; cutting the duplication is owed as a follow-up. Host: the Studio (Apple M1 Max), node from tools/node_bin.sh, jscpd 5.4.1 installed by the leg itself from tools/jscpd/package-lock.json (`npm ci`) into harness/target/toolchains/jscpd-5.4.1. The Studio's one-minute load was 13 to 20 during these sub-second runs.

## The commit scanned

`a78d6002` (cap/land-w1b rebased on origin/main 270bd6cc: the fifteen commits of lane land-w1b, gate-137, gate-136, contract-112, gate-138 and gate-133 with their lenses' fixes, and the leg count re-cut). The re-cut's own commit touches tools/jscpd/.jscpd.json (a JSON file, not a scanned format) and docs/ only, so its scanned tree is a78d6002's. Before the rebase the same stack at f49c9d75 read the same figures (lane land-w1b's stop line above).

## The leg's verdict lines at a78d6002 (its own script, in the worktree)

At the old threshold (exit 1):

    jscpd: RED: 5.215% duplicated lines (2749 of 52714) in 141 files of harness/ and tools/ (bash, go, javascript, python, rust), 259 clones; the threshold 4.25% (tools/jscpd/.jscpd.json); jscpd 5.4.1; 1 s (jscpd exit 1); the largest clones:
      95 lines: harness/src/bin/arith_cases.rs:590-684 = harness/src/bin/stack_cases.rs:784-878
      57 lines: harness/src/bin/arith_cases.rs:628-684 = harness/src/bin/crypto_cases.rs:718-774
      47 lines: harness/src/bin/arith_cases.rs:624-670 = harness/src/bin/flow_cases.rs:991-1037
      31 lines: harness/src/bin/run_diff.rs:224-254 = harness/src/stamp.rs:79-109
      30 lines: harness/src/bin/gen.rs:1778-1807 = harness/src/bin/gen.rs:1881-1910
      27 lines: harness/src/scenarios/chain.rs:721-747 = harness/src/scenarios/eras.rs:88-114
      25 lines: harness/src/bin/crypto_cases.rs:171-195 = harness/src/bin/gen.rs:992-1016
      25 lines: harness/src/bin/gen.rs:704-728 = harness/src/bin/gen.rs:806-832
      24 lines: harness/src/bin/arith_cases.rs:590-613 = harness/src/bin/flow_cases.rs:967-990
      24 lines: harness/src/bin/arith_cases.rs:661-684 = harness/src/bin/bytes_cases.rs:149-172

At the re-cut threshold (exit 0):

    jscpd: GREEN [X] 5.215% duplicated lines (2749 of 52714) in 141 files of harness/ and tools/ (bash, go, javascript, python, rust), 259 clones; the threshold 5.34% (tools/jscpd/.jscpd.json); jscpd 5.4.1; 0 s

## The raw report (jscpd-report.json, statistics) at a78d6002

| format | lines | duplicated lines | percentage | clones |
|---|---|---|---|---|
| bash | 3,664 | 0 | 0.00 % | 0 |
| go | 1,061 | 15 | 1.41 % | 1 |
| javascript | 238 | 0 | 0.00 % | 0 |
| python | 13,941 | 131 | 0.94 % | 12 |
| rust | 33,810 | 2,603 | 7.70 % | 246 |
| total (141 files) | 52,714 | 2,749 | 5.215 % (tokens 5.076 %) | 259 |

The clones ranked 11 to 25 by lines:

      21 lines: harness/src/bin/gen.rs:682-702 = harness/src/bin/gen.rs:785-805
      21 lines: harness/src/bin/gen.rs:921-941 = harness/src/block.rs:188-208
      20 lines: harness/src/bin/arith_cases.rs:62-81 = harness/src/bin/stack_cases.rs:64-83
      20 lines: harness/src/bin/crypto_cases.rs:66-85 = harness/src/bin/gen.rs:922-941
      20 lines: harness/src/bin/crypto_cases.rs:68-87 = harness/src/bin/ecdsa_vectors.rs:24-43
      20 lines: tools/modal_check.py:115-134 = tools/modal_probe_56.py:58-77
      19 lines: harness/src/bin/run_engine.rs:279-297 = harness/src/bin/run_svnode.rs:551-569
      18 lines: harness/src/bin/arith_cases.rs:84-101 = harness/src/bin/stack_cases.rs:91-108
      18 lines: harness/src/bin/arith_cases.rs:591-608 = harness/src/bin/seed_gen.rs:43-60
      18 lines: harness/src/scenarios/chain.rs:923-940 = harness/src/scenarios/chain.rs:973-990
      17 lines: harness/src/scenarios/chain.rs:2595-2611 = harness/src/scenarios/mempool.rs:2425-2441
      17 lines: harness/src/scenarios/mempool.rs:1486-1502 = harness/src/scenarios/mempool.rs:2340-2356
      16 lines: harness/src/bin/arith_cases.rs:630-645 = harness/src/bin/bytes_cases.rs:127-142
      16 lines: harness/src/bin/run_engine.rs:299-314 = harness/src/bin/run_svnode.rs:570-585
      16 lines: harness/src/scenarios/mod.rs:217-232 = harness/src/scenarios/mod.rs:396-411

The files that are a side of the most clone lines (summed over the clones they are in): harness/src/bin/arith_cases.rs 698, harness/src/bin/gen.rs 469, harness/src/scenarios/mempool.rs 426, harness/src/scenarios/chain.rs 381, harness/src/bin/run_diff.rs 304, harness/src/bin/run_engine.rs 302, harness/src/bin/crypto_cases.rs 247, harness/src/bin/run_svnode.rs 236. The five VENDORED files of docs/LINT.md §1a are in none of the 259 clones (each clone's two file names checked against the five paths: 0 hits).

## What raised it: the same scan at six commits

Each commit exported with `git archive <c> harness tools .gitignore` into a scratch directory (a `git init` there so .gitignore is read as in a checkout), the current tools/jscpd/.jscpd.json copied in, and jscpd 5.4.1 run with it. The method reproduces both known readings (b004d7c0's 4.082 % of record docs/records/20261014-214417-jscpd-tip-138-s3.md, and the stack's 5.215 %).

| commit | what it is | reading | duplicated / lines | files | clones | rust duplicated / lines |
|---|---|---|---|---|---|---|
| b004d7c0 | lane/gate-138's scanned tree, the earlier baseline | 4.082 % | 1,829 / 44,808 | 138 | 197 | 1,683 / 26,348 |
| f203fb0c^ | main before #134's formatting | 4.106 % (tokens 4.201 %) | 1,836 / 44,716 | 137 | 197 | 1,683 / 26,348 |
| f203fb0c | #134, cargo fmt over S3's 50 files | 5.057 % | 2,626 / 51,929 | 137 | 248 | 2,473 / 33,561 |
| 344514a6 | #134, cargo fmt over S2's run_diff.rs | 5.284 % | 2,756 / 52,153 | 137 | 259 | 2,603 / 33,785 |
| aaed8ec0 | #134, cargo fmt over S4b's run_teranode.rs | 5.282 % (tokens 5.125 %) | 2,756 / 52,178 | 137 | 259 | 2,603 / 33,810 |
| 270bd6cc | origin/main, the stack's base | 5.275 % | 2,756 / 52,250 | 137 | 259 | 2,603 / 33,810 |
| a78d6002 | the stack | 5.215 % | 2,749 / 52,714 | 141 | 259 | 2,603 / 33,810 |

The rise is #134's three formatting-only commits on main (4.106 % to 5.282 %: +920 duplicated lines, +7,462 Rust lines, +62 clones), which landed on main before the jscpd leg did, so the leg never read a formatted tree until this stack. Duplicated tokens rose with them (4.201 % to 5.125 %), so the rise is not the line count alone. The five gate lanes' own code lowered the reading (5.275 % at 270bd6cc to 5.215 %: +464 lines, 7 fewer duplicated Python lines, no Rust change). The brief's premise, that the gate lanes' code raised it, does not hold on this measurement; the re-cut it decided is made as decided.

## The threshold and its turn (injections at a78d6002)

Threshold 5.34 % (two decimals, as before), set in a scratch export of a78d6002 (`git archive HEAD harness tools .gitignore`), the leg run there with `JSCPD_HOME` set to the install above, and a copy of tools/specgen.py's lines written as tools/zz_inject.py:

| copied lines | count | verdict line, head | exit |
|---|---|---|---|
| none | 0 | jscpd: GREEN [X] 5.215% duplicated lines (2749 of 52714) | 0 |
| 100-168 | 69 | jscpd: GREEN [X] 5.339% duplicated lines (2818 of 52783) | 0 |
| 100-169 | 70 | jscpd: RED: 5.341% duplicated lines (2819 of 52784) | 1 |
| 100-170 | 71 | jscpd: RED: 5.342% duplicated lines (2820 of 52785) | 1 |
| 100-171 | 72 | jscpd: RED: 5.344% duplicated lines (2821 of 52786) | 1 |

Each RED printed the injected copy as a clone, for example `70 lines: .../tools/specgen.py:100-169 = .../tools/zz_inject.py:1-70`. The turn agrees with (2,749 + x) / (52,714 + x) > 5.34 % at x = 70 (69.65 rounded up); 5.35 % would turn at 76 lines, 5.33 % at 65. The brief asked for about 72 lines, the turn the leg had at abc19545; 5.34 % is the nearer two-decimal figure.

## The commands

    git archive <c> harness tools .gitignore | tar -x -C "$S"; mkdir -p "$S/tools/jscpd"; cp tools/jscpd/.jscpd.json "$S/tools/jscpd/"
    (cd "$S" && git init -q . && node <install>/node_modules/jscpd/run-jscpd.js -c tools/jscpd/.jscpd.json -r json -o "$S/out" --no-tips --no-colors)
    JSCPD_HOME=<install> bash "$S/tools/jscpd_check.sh"
    sed -n "100,<end>p" tools/specgen.py > "$S/tools/zz_inject.py"; JSCPD_HOME=<install> bash "$S/tools/jscpd_check.sh"
    bash tools/jscpd_check.sh    # in the worktree, before and after the threshold's change
