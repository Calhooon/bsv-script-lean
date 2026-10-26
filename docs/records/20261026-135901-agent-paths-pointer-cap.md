[export: 4 lines withheld by tools/export_public.py, the sibling trees' lines; the original is in the private history]
# The agent-paths pointer group: the owner's account name out of three records before the public flip

[M] 2026-10-26T13:59:01Z, on the Studio, by CAP the captain (Claude Fable 5.1), worktree
`~/bsv/worktrees/spec-cap-flip` on `cap/flip-3` from `origin/main` at `8840488c`.

## 1. What the flip review found

[M] A scan of the second edition (the private repository's `60717f17`, 2,073 files) for the owner's names, handles,
addresses, home paths and host names found the macOS account name in three records, carried inside a coding agent's
[withheld at export: a sibling tree's line]
`20260927-125018-decoder-wall-s2-run.sh.txt` (1 line) and `20260927-125018-decoder-wall-s2-timings.txt` (22 lines),
and `~/.claude/projects/-Users-<account>-…/memory/` in `20260929-142257-memory-s4b-runs-s3.md` (1 line). The
[withheld at export: a sibling tree's line]
[withheld at export: a sibling tree's line]

## 2. The change

[X] `tools/export_pointers.txt` gains the group `agent-paths` with two patterns: the flattened component
[withheld at export: a sibling tree's line]
gate group, not a substitution group: in `docs/records/` and `docs/audit/` the records transform withholds the
line by the marker; on any other exported page a hit stops the export gate. `tools/test_export_pointers.py` gains
`test_agent_paths_withhold_record_lines_and_stay_out_of_substitution` (both shapes withheld and counted, neither
substituted, the gate group named; "the Users table", "Users-of-the-harness" and "/private/tmp/other" untouched).

[X] `python3 -m unittest test_export_pointers test_export_gate test_export_rules`: 31 tests OK.

[M] In this tree the patterns match 24 lines in those three records, 62 more lines in 25 other records and audit
pages (already withheld by other patterns at the second edition, as the scan of the edition found only the three),
and lines of `HANDOFF.md` and `PROMPT.md`, which the export withholds whole.

## 3. What follows

The box tripwire on this commit, the landing, the export of the landed tree, the export gate, the third edition
pushed to the private repository's `main`, and the scan of the edition repeated for the account name.

## 4. The tripwire's RED on the way, and its entry (#178)

[X] `tools/check_box.sh` on `0844d4ae` (the box, 13:59 to 14:00 UTC; record `20261026-135945-make-check-box.txt`,
committed beside this one): RED on one leg, `cargo-deny` (`advisories FAILED, bans ok, licenses ok, sources ok`;
the RustSec database at `a78282a1414d`, fetched): RUSTSEC-2026-0387 (issued 2026-10-23) on `crypto-bigint 0.5.5`,
reached only through bsv-rs 0.7.0's `k256 0.13.4` and `p256 0.13.2` (`elliptic-curve 0.13.8`, `ecdsa 0.16.9`,
`primeorder 0.13.6`). Nothing in the tree changed since the GREEN record of 2026-10-21 (`20261021-230022`); the
database did. The fix, `crypto-bigint >= 0.7.6`, exists only under `elliptic-curve 0.14` (`k256 0.14.0` and
`p256 0.14.0` of 2026-07 depend on `ecdsa ^0.17` and `elliptic-curve ^0.14.1`; crates.io read 2026-10-26 14:0x UTC),
which bsv-rs does not take (`k256 = "0.13"`, `p256 = "0.13"` in its `Cargo.toml` at `efe12e6`); `cargo update -p
crypto-bigint` changes nothing.

[X] Filed: Calhooon/bsv-rs#265 (the Finding to the engine: the bump to k256 0.14, p256 0.14, ecdsa 0.17) and #178 on
this tracker (milestone S9), staged for the public tracker on `docs/PLAN-2026-10-21-PUBLIC-TRACKER.md` (the filer's
dry run names it public #25). `harness/deny.toml` gains the one dated `ignore` entry with its reason: the harness is a
conformance harness that signs with deterministic test keys and holds no secret worth a timing channel; the entry
leaves in the landing that re-pins a bsv-rs release on the 0.14 line. `tools/cargo_deny.sh` on the Studio after the
entry: GREEN (advisories ok, bans ok, licenses ok, sources ok; cargo-deny 0.19.0; the same database).

## 5. The light hosted gate (the owner's word on the flip review, 2026-10-26 14:2x UTC)

[M] The lean job of `.github/workflows/gate.yml` added a swap file up to 40 GB on GitHub's 16 GB runner so that the
axioms leg could build the kernel-checked stale run (near 29 GB, `docs/records/20261014-061809-stale-cost-s1.md`),
under a 330-minute timeout. The owner read it on the review page ("40 GB of swap on a CI? That's insane") and took
the recommendation: the hosted gate runs the way `VERIFY_LIGHT=1 make verify` runs.

[X] `tools/check.sh`: the axioms leg under `VERIFY_LIGHT=1` prints its two SKIPPED BY NAME lines and returns (the
header names it); the verdict row `axioms` accepts that line beside `axiom check: OK (`. `tools/withheld_legs.txt`
gains the row `axiom-check` (evidence `^  axiom check: OK \(`, refused on `SKIPPED BY NAME`), so the box's commit
status `box/withheld-legs` carries the axiom check as it carries the node and Teranode legs. `gate.yml`: the swap
step removed, `VERIFY_LIGHT: "1"` on the lean job, the timeout 240 minutes, the header and the cache comment re-cut.
`docs/LINT.md`'s Memory paragraph re-cut (the wording gate CLEAN on it).

[X] Run here: `VERIFY_LIGHT=1 tools/check.sh axioms` prints the two lines and exits 0 with no Lean;
`tools/withheld_legs.py --declare` DECLARED 7 rows, 0 unmatched; `--judge` on the GREEN box record
`20261021-230022-make-check-box.txt` says `withheld leg axiom-check: ran` and `withheld legs: GREEN (ran 5)`; the
verdict row matches both forms; the workflow parses as YAML (14 steps on the lean job, env VERIFY_LIGHT=1).

The witness's cost itself (29 GB for one kernel-reduced scenario) is the Lean seat's and goes on the public tracker
as its own issue after the flip; the light switch stays until it comes down.
