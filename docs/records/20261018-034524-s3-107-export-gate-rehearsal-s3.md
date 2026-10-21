[export: 1 line withheld by tools/export_public.py, the sibling trees' lines; the original is in the private history]
# The FULL export gate rehearsed on main `3d3f4f32`, CLEAN, with all three sibling trees (lane rehearse-107)

[withheld at export: a sibling tree's line]

## The verdict: CLEAN, in one run

[M] `export gate: CLEAN`. Mechanism leg 2 ran over the export's 198 corpus files against **3 present sibling trees**, exit 0. Every leg's verdict line reads 0 hits: withheld-rule, mechanism, pointer, wording. The build leg is GREEN: both cargo steps exit 0, 26 and 31 executables, `gen` absent from both lists. The gate ran once on this export; no row needed a fix, and nothing was added to an allow list or to `tools/export_withheld_entries.txt`.

## The load (rule 17)

[M] The 1-minute load was 20.89 at 02:34:54 UTC and 19.35 at 02:35:11, when the export began (a wait under 1 minute). It rose to 35.55 by the export's end from other programs' lanes, so the gate waited: sampled every 15 to 30 s from 02:42:51 (peak 86.71 at 02:46:51) until 18.74 at 02:56:25 (a wait of about 14 minutes); the gate started at 02:56:30 with the load at 19.56. The load after the gate was 31.24 (03:45:31). Every sample is `uptime`'s, stamped by `date -u`. The load above 20 during the run came from other lanes; the gate started under it.

## The export: `make export-public COMMIT=3d3f4f326ce0d71e2e08fde5debb4313f623b370`

[M] `git status --short` printed nothing before the export (0 lines). Exit 0, wall 444 s (02:35:16 to 02:42:40 UTC by `date -u`). Target `~/bsv/targets/spec-export/20261018-023516` (413 MB, kept with its log `~/bsv/targets/spec-export/20261018-023516.gate.log`). 1904 paths exported, 264 withheld, 0 not blobs; the records transform: 531 files, 5888 lines replaced by the marker. The manifest lines for #107, verbatim:

```
source-commit 3d3f4f326ce0d71e2e08fde5debb4313f623b370
withheld-list tools/export_withheld.txt @ 3d3f4f326ce0
cargo-transformed 1 files, 1 target tables dropped (the Cargo transform)
cargo-source-check 81 .rs files, 66 mod/#[path]/include lines, 3 naming a withheld basename, 0 resolving to a withheld path
makefile-transformed 1 of 1 Makefiles, 1 targets dropped (the Makefile transform)
lists-read-at 3d3f4f326ce0 (7 lists; working tree differs: none)
## cargo-transformed: targets-dropped path (kind name, ...) (the Cargo transform)
1  harness/Cargo.toml  bin gen
## makefile-transformed: targets-dropped path (target, ...) (the Makefile transform)
1  Makefile  gencases
```

## The gate: `make export-gate BUILD=1 EXPORT=~/bsv/targets/spec-export/20261018-023516`

[M] Started detached at 02:56:30 UTC (`date -u`); the log's last write, the `export gate:` line, at 03:45:24 UTC (the log's modification time): wall 2934 s, about 48.9 minutes, against 1908 s for the last CLEAN run under a load near 4 (the gate's output is buffered, so the log names no per-leg stamp; the cargo walls below are the gate's own). The log (19 lines; home paths abbreviated with ~ and the two cargo lines cut after the executable count):

```
== the gate on ~/bsv/targets/spec-export/20261018-023516
(withheld entries) 60 in 4 files, group d7-node-team-split
(withheld entries) 154 in 6 files, group d8-node-team-discretion
(withheld entries) 2 in 2 files, group d9-gosdk-172-splice
(withheld rules) 1 classes, 1 rows, group d9-gosdk-172-splice
(withheld history) 69 lines in 10 files, group d9-gosdk-172-splice
(withheld report rows) 4 docs/CONFORMANCE-2026-09-27.md
(withheld-rule) 0 hit(s)
(a) mechanism leg 2: 198 corpus files against 3 present sibling tree(s), exit 0
(mechanism) 0 hit(s)
(pointer) 0 hit(s); addresses 0; d9-gosdk-172-splice 0; local-paths 0; machine-hosts 0; modal-names 0; plan-repository 0; predecessors 0; private-programs 0; sibling-paths 0
(wording) 0 hit(s)
== history, counted, not gated (the wording leg over docs/records/ and docs/audit/)
(wording, history) 248 hit(s) in 95 file(s); conformance-claim 12; long-dash 53; priority-word 183
(build) cold target ~/bsv/targets/spec-export/.cargo/20261018-023516
(build) cargo build --release --locked --offline: exit 0, wall 103.3 s, 26 executable(s)
(build) cargo test --release --locked --offline --no-run: exit 0, wall 35.6 s, 31 executable(s)
(build) cold target removed, 0.4 GiB freed
export gate: CLEAN
```

[M] **The cold cargo target.** The build leg removed `~/bsv/targets/spec-export/.cargo/20261018-023516` itself, freeing 0.4 GiB; `~/bsv/targets/spec-export/.cargo/` holds 0 entries after the run. The export directory (413 MB) and its log stay.

[D] from the two logs: the withheld counts, the corpus file count and the history count are the same as on `af052ace`; the export grew by 27 paths exported and 12 withheld.

## The stacks landed since the last CLEAN record

[M] `git log --oneline af052ace..3d3f4f32 -- tools/progress_state.json` (126 commits on main in the range) names these stack lines, newest last: `d3abbd78` stack HH (107, the CLEAN record itself), `d9bee5c9` stack II (149), `db46b570` stack JJ (94, the alert path), `025a750e` stack KK (93, the reorg leg), `9ca1bb1a` stack LL (92, record lifetimes), `960616ce` stack MM (94, the store half), `4bc00f2a` stack NN (88), `3cc99e36` stack OO (95, the tooling half), `830bb1a0` stack PP (34, 92, 146). The range's other progress commits are cards and plan lines (`bc35ec84`, `586990ef`, `66b72505`, `30b258f8`, `9f27399b`). The brief counted eleven stacks; the progress log names nine stack lines, eight after the CLEAN record's own.

## What remains for #107

[M] This tree is a rehearsal. #107 closes on the flip day: the FULL gate (`make export-gate BUILD=1`) on an export of the frozen tree, run on the Studio where the three sibling trees are, printing CLEAN, with no landing between the export's start and the birth's push.

## The checks

[M] Run on the tree that lands this record:

```
python3 tools/cite_check.py            cite_check: GREEN (its verdict word; the rest of the line is not quoted here)
make check-pins                        check-pins: GREEN (100 sites agree with docs/PROVENANCE.md §1a; 3 skipped by name: the built gobdk-runner, the predecessor-lean clone, the zmq build); exit 0
git diff --check                       clean (exit 0)
grep -c (the long dash) on this record and the README   0, 0
priority-word grep on record and README: 0 and 56 matching lines; negative grep on both pages: exit 1; all README matches predate this branch, added-line matches: 0.
the wording gate on this record                         wording gate: CLEAN (1 pages; the forms: priority-word, claim, conformance-claim, licence-adjective, dash, private)
```

[M] **Correction (2026-10-18 03:54:22 UTC, S3, lane fix-rehearse-107).** The log introduction now discloses the home-path abbreviation, and the priority-word check now covers both the record and `docs/records/README.md`, including the pre-existing README matches. The recorded export and gate measurements are unchanged.
