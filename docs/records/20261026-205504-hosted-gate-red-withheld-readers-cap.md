# The hosted gate's run on the sixth edition: RED on two more legs, the readers of the public edition

**Seat:** S3 (CAP the captain, Claude Fable 5.1). **Labels:** [X] on every line naming a run's output.

## 1. The run [X]

The sixth edition `d6025024` (the export of main `04c9e47b`, pushed 20:49 UTC) ran the hosted gate as run 40399060008. The two legs RED on the fifth edition (pins, seed) passed: `gate: leg pins exit 0, wall 65 s`; `seedcheck records index: GREEN [X]: docs/records/INDEX.md is current, 1008 records`. Two further legs stopped their jobs (each job stops at its one RED leg, `tools/gate_leg.sh`):

| job | leg | what it printed |
|---|---|---|
| tree | spec (`tools/node_contract.py` under `specgen.py --check`) | `node_contract: obligation script-verdict: the leg's record docs/records/20261017-031159-s4b-152-teranode-signer-chain-s4b.md is absent`; `spec: RED (a step above printed RED or STALE)` |
| lean | harness (`rules_check`) | `thread 'main' panicked at src/bin/rules_check.rs:111:52: entry: Error("invalid type: string \"WITHHELD: d8-node-team-discretion (see corpus/INDEX.md)\", expected a sequence", line: 1, column: 227)`; `harness: the classifier tables do not reproduce the recorded classifications (D83c): RED` |

## 2. The cause: the public edition's readers met the export's withheld material

- The node contract's obligation list names the record of each measured leg; six of those records are on the withheld list (`tools/export_withheld.txt`: the #92, #93, #94 and #152 Teranode records, disclosure material). The tool treated the absence as an error.
- The export's entry list (`tools/export_withheld_entries.txt`) replaces named fields of a witness entry by the marker string. `tx`, `note`, `decided_by`, `from`, `witness` and `rule` are strings in the private tree, so the marker keeps their type; `prevouts` is a list, and its marker is a string, which `corpus::Entry` refused. Every replayer that types the entry (`rules_check` in the harness leg) stops at the earliest such entry (150 in `corpus/gen/gen.jsonl`, 4 in `corpus/road/road.jsonl`, 2 to 4 per witness file).
- Skipping the withheld entries is not enough: the exported manifests count the private corpus (`agree`, the rule rows' `entries`, `entries`), so the public replay falls short of every count by the withheld entries in that class.

## 3. The fix (commits f0cfd155 and 94bbf52c on cap/flip-3)

- `harness/src/corpus.rs`: `Entry.prevouts` reads the export's marker as an empty list; `Entry::withheld` names an entry whose `tx` is the marker. The private tree carries no marker, so nothing there changes.
- `harness/src/bin/rules_check.rs`: withheld entries are skipped BY NAME and counted per file. Under withheld entries the comparison is BOUNDED, never EQUAL: each public count may fall short of its manifest row by at most the withheld count, a row's smallest witness may be a withheld id, a row the public replay never reaches holds at most the withheld count, the rulings are compared as ever, and the entry total (public + withheld) is exact. The corpus verdict says `BOUNDED (...; not EQUAL)`; the final line counts the bounded pairs.
- `tools/node_contract.py`: a leg record that the withheld list names is `SKIPPED BY NAME (the private history holds it)`, printed per obligation, never a stop.

## 4. The verification [X]

A fresh export of 94bbf52c under `~/bsv/targets/spec-export/cap-json-check`:

- `export gate: CLEAN` (pointer 0, json 0, records-index 0; the records transform 623 files, 6431 lines replaced by the marker).
- `rules_check` built and run in the export: `rules_check: GREEN (...) (100 corpus × engine manifests, 855321 entries replayed, 154505 divergent runs classified; 8 BOUNDED by withheld entries (the public edition), not reproduced)`; the bounded pairs: go-sdk, ts-sdk, gobdk, sv-node and bsv-rs on gen, go-sdk, sv-node and bsv-rs on road; 150 entries withheld in gen.jsonl, 4 in road.jsonl, said per file. In the private tree the same binary prints no BOUNDED line and `GREEN` as before.
- `tools/check.sh spec` in the export: exit 0; 18 obligation lines `withheld at export: SKIPPED BY NAME` (six withheld records).
- `tools/check.sh tslint` in the export after `npm ci` there: `tslint: GREEN [X] (harness/engines/ts: tsc --noEmit strict checkJs, 0 errors; eslint --max-warnings 0, 0 problems; ...)`.
- The box tripwire GREEN on f0cfd155 (record 20261026-210157) and on 94bbf52c (record 20261026-212233); this record's own run follows.

## 5. What follows

The seventh edition goes up from the landed main; its hosted run reaches the legs after `harness` in the lean job (`chain`, `bench`) for the one run on a public tree that reaches them. A RED there is read the same way: a finding to name, never a reason to touch the public repository by hand. The public edition says BOUNDED where it cannot say EQUAL; the private tree's claims stand as before.
