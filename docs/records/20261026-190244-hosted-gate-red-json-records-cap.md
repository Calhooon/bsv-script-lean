# The hosted gate's run on the fifth edition: RED, the export's JSON records, the fix

**Seat:** S3 (CAP the captain, Claude Fable 5.1). **Labels:** [X] on every line naming a run's output.

## 1. The run [X]

The fifth edition `1014b648` (the export of main `753df92a`, pushed 18:32 UTC) was the one push since the flip, so its run 40378649762 of `.github/workflows/gate.yml` was the gate's one run on a public repository (every earlier run skipped by its `if`, the flip record of 18:09 UTC). Its jobs: withheld-legs success, rust success, tree FAILED, lean FAILED, record FAILED (downstream of the two).

| job | leg | what it printed |
|---|---|---|
| tree | pins (tools/test_teranode_gate.py) | `teranode gate: STOP (2): no reference scenario column for the families block, chain, finality, mempool, utxo`; `ERROR: setUpClass (DryRun) AssertionError: 2` |
| lean | seed (the records index) | `seedcheck records index: RED: docs/records/INDEX.md is stale` |

## 2. The cause: a defect of the export, present since the birth edition [X]

The records transform of `tools/export_public.py` replaced every LINE a pointer matched by the marker line. A JSON record written on one line, whose text held a local path, became two marker lines and stopped being JSON. In the public tree at `1014b648`: 63 of the 186 JSON records under `docs/records/` did not parse (the gate95 regtest columns among them, which the Teranode dry run reads; and the index tool read no commit from them, so 21 rows of the index lost their commit column). The export gate never parsed a JSON file, so the four editions before passed it with the defect in place. The birth edition `92287f18` carries the same two-line files.

## 3. The fix (commits d495c63b and 38d85265 on cap/flip-3)

- `tools/export_public.py`: `transform_json` withholds the matched STRINGS and KEYS of a JSON record (the marker; keys numbered) and keeps the document JSON and its shape (one line or indented); a file that is not JSON takes the line transform as before. The export renders `docs/records/INDEX.md` over the exported records with the exported tool (the private tree's index is not the index of the export), and the manifest's digest follows.
- `tools/export_gate.py`: leg (e) every exported `.json` parses; leg (f) the export's records index is current (`records_index.py --check`), SKIPPED BY NAME when the tool is not in the tree under test.
- `tools/records_index.py`: outside a repository (the export under the gate) the prefixes are walked on disk, sorted as `git ls-files` sorts.
- `tools/test_export_pointers.py`: the JSON transform's unit test (a one-line record with a local path in a value and in two keys stays one line of JSON with four markers; an indented record keeps its shape; a clean record is returned unchanged).

## 4. The verification [X]

The export of 38d85265 under `~/bsv/targets/spec-export/cap-json-check`, the gate without the build (the build leg ran CLEAN on the fifth edition and the harness did not move):

- `export gate: CLEAN`; `(pointer) 0 hit(s)`; `(json) 0 hit(s)`; `(records-index) 0 hit(s)`; the records transform 620 files, 6422 lines replaced by the marker; the export rendered its index: 1005 records.
- In the export: 0 of 186 JSON records fail to parse (63 before); `seedcheck records index: GREEN [X]: docs/records/INDEX.md is current, 1005 records`; `tools/test_teranode_gate.py`: 17 tests OK (the dry run finds every family column).
- The unit tests of the export in the private tree: test_export_pointers 14 OK, test_export_gate 7 OK, test_export_rules 11 OK, test_export_cargo 14 OK.
- The box tripwire GREEN on d495c63b (record 20261026-195049) and on 38d85265 (the record landed with this one).

## 5. What follows

The sixth edition goes up from the landed main (the full gate with the build in `flip-gate5.sh`'s chain); its push runs the hosted gate again, and that run's verdict lands in its own record. The dead `Calgooon` links in the records stay (the owner's call of 2026-10-26; the README's sentence covers them).
