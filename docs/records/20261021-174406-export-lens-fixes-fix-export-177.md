# The export lens's three greps re-run after the fixes of #177

[M] 2026-10-21, on the build host, at `6cdfa944`, by Claude Opus 5.5. Before: the export of `1bd9050b` (`make export-public`, 2,057
paths, `~/bsv/targets/spec-export/20261021-170617`, outside the tree). After: the export of `6cdfa944` (2,057 paths,
`~/bsv/targets/spec-export/20261021-173637`). The three greps are the export lens's of 2026-10-21 (its report on #177),
re-run unchanged over each export: (2a) the constitution-05 pattern with the lens's mempool filter, then its two narrow
program-sense patterns; (2b) the process pattern over the exported entry pages and `spec/*.md`; (2c) the host pattern
over `*.md`, `*.yml`, `*.toml`, `*.py`, `*.sh`, `*.rs` and `*.lean`.

## 2a. The constitution-05 grep

Before 652 lines, after 651: the one breach, `tools/modal_check.py`'s rates comment, is re-cut. The two narrow patterns
return 3 lines on both exports, each harmless (the mempool): `docs/records/20261015-151316-s6-66-cut2-second-oracle-s3.md:83`
(the row's diverging field), `lean/BsvChain/Properties/Reachable.lean:24` and `spec/theorems.md:7625`. The rest fall in the
lens's harmless classes (the mempool senses of the pool, the token lines, the covenant lines, the advisory sibling
lines), not re-judged line by line here. Breaches: before 1, after 0.

## 2b. The process grep

Before 178 lines (142 breaches, 36 harmless), after 40 (4 breaches, 36 harmless), each line classified on its whole text:

| file | before: harmless · breach | after |
|---|---|---|
| `spec/modules.md` | 11 · 54 | 11 · 0 |
| `spec/node-client-contract.md` | 0 · 40 | 0 · 4 |
| `spec/teranode-absences.md` | 0 · 31 | 0 · 0 |
| `spec/theorems.md` | 18 · 4 | 18 · 0 |
| `spec/wire-views.md` | 0 · 6 | 0 · 0 |
| `spec/merkle-proof.md` | 0 · 4 | 0 · 0 |
| `spec/README.md` | 0 · 2 | 0 · 0 |
| `spec/teranode-map.md` | 0 · 1 | 0 · 0 |
| `docs/PARAMETERS.md` | 3 · 0 | 3 · 0 |
| `docs/DESIGN-S6.md` | 1 · 0 | 1 · 0 |
| `docs/DESIGN.md`, `docs/HYPOTHESES.md`, `docs/CONFORMANCE-ASSOCIATION-v122.md` | 1 · 0 each | 1 · 0 each |

The harmless 36: 35 lines whose only hit is "restate" or "restated" (`docs/DESIGN-S6.md:611` among them: its hit sits past
the column the lens printed), and `spec/theorems.md:7438`, "the owner of its earliest index entry" (the spend index).
The 4 left, all on `spec/node-client-contract.md` section 5 (lines 214, 215, 244, 257), plus line 194 (a capitalised
"The owner's word", outside the pattern's case), come from `corpus/teranode/obligations.json`, which `chaincheck
--obligations-json` emits from the string fields of `obligations` and `Divergence` data in
`lean/BsvChain/Teranode/Refinement.lean` (lines 867, 1090, 1091, 1120, 1133 at `6cdfa944`) and which `chaincheck
--refinement` compares with the list: a def's text, outside this lane's docstring-only class; owed to S1 with a Lean
build (the strings re-cut, the file re-emitted, `make spec`).

## 2c. The host grep

Totals: before 854 lines (510 under docs/records/, 344 outside); after 737 lines (510 under docs/records/, 227 outside).

| file | before: home path · tracker · host file · box name | after |
|---|---|---|
| `docs/PROVENANCE.md` | 59 · 67 · 1 · 0 | 11 · 63 · 1 · 0 |
| `spec/teranode-absences.md` | 48 · 0 · 0 · 0 | 0 · 0 · 0 · 0 |
| `harness/README.md` | 12 · 0 · 1 · 1 | 0 · 0 · 2 · 0 |
| `tools/check_box.sh` | 3 · 0 · 4 · 7 | 0 · 0 · 9 · 0 |
| `docs/LINT.md` | 3 · 7 · 1 · 2 | 0 · 0 · 1 · 0 |
| `harness/engines/instance41/README.md` | 6 · 0 · 0 · 0 | 6 · 0 · 0 · 0 |
| `docs/CONFORMANCE-RPC-CONTRACT.md` | 5 · 0 · 0 · 0 | 5 · 0 · 0 · 0 |
| `docs/recon.md` | 0 · 5 · 0 · 0 | 0 · 1 · 0 · 0 |
| `harness/oracle/spec-node.sh` | 5 · 0 · 0 · 0 | 5 · 0 · 0 · 0 |
| `tools/export_gate.py` | 1 · 0 · 4 · 0 | 1 · 0 · 4 · 0 |
| `harness/oracle/README.md` | 4 · 0 · 0 · 0 | 4 · 0 · 0 · 0 |
| `harness/src/scenarios/mod.rs` | 4 · 0 · 0 · 0 | 4 · 0 · 0 · 0 |
| `tools/fuzz_campaign.sh` | 2 · 0 · 0 · 2 | 0 · 0 · 5 · 0 |
| `tools/teranode_gate.sh` | 1 · 0 · 3 · 0 | 1 · 0 · 3 · 0 |
| `docs/CONFORMANCE-TERANODE-OBSERVATION.md` | 3 · 0 · 0 · 0 | 3 · 0 · 0 · 0 |
| `docs/audit/2026-09-27-lens-S3-fold-sitting3-by-S3.md` | 3 · 0 · 0 · 0 | 3 · 0 · 0 · 0 |
| `docs/audit/2026-09-27-lens-S4b-sitting3-block-by-S4b.md` | 2 · 1 · 0 · 0 | 2 · 1 · 0 · 0 |
| `tools/cargo_deny.sh` | 1 · 0 · 0 · 2 | 1 · 0 · 0 · 2 |
| `tools/jscpd_check.sh` | 1 · 0 · 0 · 2 | 1 · 0 · 0 · 2 |
| `tools/mechanism_check.sh` | 0 · 0 · 3 · 0 | 0 · 0 · 3 · 0 |
| `tools/secrets_scan.sh` | 1 · 0 · 0 · 2 | 1 · 0 · 0 · 2 |
| `tools/wording_gate.sh` | 0 · 0 · 3 · 0 | 0 · 0 · 3 · 0 |
| `spec/node-client-contract.md` | 2 · 0 · 0 · 0 | 0 · 0 · 0 · 0 |
| `tools/check_signer.sh` | 0 · 0 · 0 · 2 | 0 · 0 · 5 · 0 |
| `tools/finality_check.sh` | 0 · 0 · 2 · 0 | 0 · 0 · 5 · 0 |
| `tools/node_contract.py` | 2 · 0 · 0 · 0 | 0 · 0 · 0 · 0 |
| `tools/utxo_check.sh` | 0 · 0 · 2 · 0 | 0 · 0 · 5 · 0 |
| `docs/DESIGN.md` | 0 · 1 · 0 · 0 | 0 · 0 · 0 · 0 |
| `tools/ripemd_tables.py` | 1 · 0 · 0 · 0 | 0 · 0 · 3 · 0 |
| `tools/teranode_absences.py` | 1 · 0 · 0 · 0 | 0 · 0 · 0 · 0 |

Unchanged and under three hits each: 47 files (62 hits), every one outside this lane's list except `tools/check_pins.py` (its two host-file mentions are the route itself, unchanged in count).

Breaches the lens named, after: the scripts (`tools/check_signer.sh`, `tools/fuzz_campaign.sh`, `tools/ripemd_tables.py`,
`tools/teranode_absences.py`, `tools/check_box.sh`) carry no home path; each takes its host from the environment or
`tools/host_private.sh` and otherwise prints one line and exits 2 (tested on a copy without the host file: rc 2 per
script, the one line each; with it every value resolves as before, the environment winning; `check_box.sh` under a stub
`ssh` passes the box the same paths as before). `tools/utxo_check.sh` and `tools/finality_check.sh` refuse with the same
one line; `tools/check_pins.py` (a gate the public CI runs) reads a `$NAME` pin from the environment and still skips an
unresolved clone by name, `check-pins: GREEN (97 sites agree with docs/PROVENANCE.md §1a; 5 skipped by name ...)` [X]
on the box with its toolchains on the path. Pages: `spec/teranode-absences.md` 48 hits to 0, `docs/LINT.md` 13 hits to 1 (the
host file named as configuration), `harness/README.md` 14 hits to 2 (the host file named), `docs/PROVENANCE.md`'s home paths
59 to 11.

Harmless after: the 63 tracker hits of `docs/PROVENANCE.md` and the 1 of `docs/recon.md` are reads' records (the REST URL
of a read or the origin fetch, with its time), kept by the brief; the host-file mentions are the route itself.

Owed: the 11 values of `docs/PROVENANCE.md`'s pins block (`reference.clone`, the three `reference.binary*`,
`teranode.clone`, `gobdk.clone`, `go-chaincfg.clone`, `go-safe-conversion.clone`, `bsv-rs.clone`, `go-sdk.clone`,
`ts-sdk.clone`): 14 tools parse them, four in Rust (`harness/src/signer_node.rs`, `harness/src/scenarios/core.rs`,
`harness/src/scenarios/relay.rs`, `harness/src/bin/run_signer_chain.rs`), so a move to `$NAME` values needs a harness
build. Outside this lane's list and unchanged: `harness/oracle/spec-node.sh` and its README, `harness/engines/instance41/README.md`,
`harness/src/scenarios/*.rs`, `docs/CONFORMANCE-*.md`, `tools/opnames.py`, `tools/column.py` and about 20 other `tools/*.sh`.

## 3. The tracker links

18 issue links on the exported pages became "archived #n" text (`docs/LINT.md` 7, `docs/PROVENANCE.md` 6, `docs/recon.md`
5), two of them with their comment number; no pull or commit link was on the pages; `docs/DESIGN.md`'s consumer require
names the public address; `docs/GLOSSARY.md`'s entry says the links were replaced at the public birth.

## The other proofs

- `tools/wording_gate.sh`: `wording gate: CLEAN (41 pages; the forms: priority-word, claim, conformance-claim, licence-adjective, dash, private)` [X]
- `python3 tools/specgen.py --check`: `specgen --check: OK (123 files up to date; 1 rules flagged)` [X] (pure Python, no Lean build)
- `python3 tools/tools_index.py --check`: `tools_index: tools/README.md is current (116 files)` [X]
- `tools/export_gate.sh` on the after export, no `--build`, 3 min 23 s: `(mechanism) 0 hit(s)`; `(pointer) 0 hit(s)`, every
  class 0; `(wording) 0 hit(s)` (the run before it at `f9693698` found 1, a priority word in a comment of this lane,
  fixed at `6cdfa944`); `(wording, history) 239 hit(s) in 90 file(s)`, counted, not gated; `(build) not run`; the verdict
  `export gate: INCOMPLETE (a sibling tree is absent)`: mechanism leg 2 did not run, its sibling tree is absent on this host [X].

Unverified here: the Lean build of the re-cut docstrings (no build in this lane; StaleRun's module docstring moved, so the
box tripwire recompiles it), the 2c harmless judgement of the unchanged files by pattern, not line by line.
