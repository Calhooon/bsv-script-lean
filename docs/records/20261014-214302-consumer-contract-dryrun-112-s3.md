[export: 1 line withheld by tools/export_public.py, the sibling trees' lines; the original is in the private history]
# The consumer contract's dry-run reads and the cargo verdict (#112)

[withheld at export: a sibling tree's line]

## 1. The dry run's manifest and tree (read 2026-10-14T21:42Z by this lane) `[X]`

- `EXPORT-MANIFEST.txt` line 2: `source-commit 2dfe3354fb2d4885e28160e07fef6400e8b95c8f`; line 3: `exported-at 2026-10-13 14:49:15 UTC`; line 6: `paths-exported 1256`; line 7: `paths-withheld 228`.
- Lines 14 to 16: `withheld-entry-group d7-node-team-split 60 entries`, `d8-node-team-discretion 154 entries`, `d9-gosdk-172-splice 2 entries` (216 in all).
- Line 37: `rewritten 10 (tools/export_rewrite.txt)`; the section `## rewritten` lists `CLAUDE.md`, `corpus/cpp/replay/cpp-txvalidationcache/ledger.json`, `harness/src/bin/rules_check.rs`, `harness/src/bin/run_diff.rs`, `lean/lakefile.toml`, `tools/cite_check.py`, `tools/conformance.py`, `tools/cpp_era_chain.py`, `tools/cpp_era_run.sh`, `tools/cpp_replay.py`.
- `lean/lakefile.toml` line 6: `name = "bsvscript"`; `grep -c historycheck lean/lakefile.toml`: `0`.
- `lean/lean-toolchain`: `leanprover/lean4:v4.34.0`.
- `ls` of `lean/BsvScript/Numbers/History.lean`, `lean/Test/HistoryCheck.lean`, `harness/src/bin/gen.rs`: `No such file or directory` for all three.
- `harness/Cargo.toml` lines 84 to 86: `[[bin]]`, `name = "gen"`, `path = "src/bin/gen.rs"`.

## 2. This repository at `4ee84d18` (tree of `0447efb6` for these paths) `[X]`

- `grep -rl "import BsvScript.Numbers.History" lean`: `lean/Test/HistoryCheck.lean` only (the withheld pair).
- `tools/export_public.py` at `0447efb6`, `d33a003a` and `2dfe3354` alike: line 50 `WITHHELD = os.path.join(ROOT, 'tools', 'export_withheld.txt')`, line 775 the `source-commit` write, line 777 the `withheld-list` write, line 790 the `## exported: sha256 path` header (791 to 792 the loop), line 793 the withheld header.

## 3. The cargo verdict on the exported harness

- **The lane's run** (lane contract-112, as its page records it): a copy of the dry run's `harness/`, 2026-10-14T21:26:45Z to 21:26:47Z (a wall of about 2 s), cargo 1.95.0, `CARGO_BUILD_JOBS=1`, offline, `cargo build --release --locked` (the command of `harness/README.md:191`): exit 101 at target resolution, "error: can't find bin `gen` at path `.../harness/src/bin/gen.rs`", zero crates compiled `[X]`. Its minimal crate: `cargo build --bin present` exit 0, a bare `cargo build` exit 101 on the missing explicit bin path `[X]`. The lane kept no log file of these runs; this record is their record from the page's quotation.
- **The lens's re-run** (lane lens-contract-112, 2026-10-14T21:4xZ, on the Studio): a scratch copy of the dry run's `harness/` outside the tree, cargo 1.95.0, `CARGO_BUILD_JOBS=1`, `--offline`, `cargo build --release --locked`: exit 101, "error: can't find bin `gen` at path .../harness/src/bin/gen.rs ... could not compile due to 1 previous target resolution error" `[X]`. The lens did not re-run the minimal crate.
- **This lane** did not re-run cargo: the Studio's 1-minute load read 30.67 at 21:42:50Z and 42.47 at 21:43:02Z, above the rule-17 line of 20. `cargo --version` here reads `cargo 1.95.0 (f2d3ce0bd 2026-03-21)`. A third run is the box tripwire's to make, not this record's.
- **Why `make check` stays GREEN:** `tools/check.sh` lines 251, 324, 330, 338 and 343 build named bins with `--bin` `[SRC]`, so the missing `gen` path is never resolved by the gate.
