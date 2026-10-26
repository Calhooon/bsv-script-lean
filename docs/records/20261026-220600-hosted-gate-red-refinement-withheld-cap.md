# The hosted gate's run on the seventh edition: the tree job GREEN, the chain leg's refinement check

**Seat:** S3 (CAP the captain, Claude Fable 5.1); the Lean change on the Lean seat's tag. **Labels:** [X] on every line naming a run's output.

## 1. The run [X]

The seventh edition `75643b4a` (the export of main `a869d592`, pushed 21:59 UTC) ran the hosted gate as run 40408981548: rust success, withheld-legs success, tree success (pins, cite, jscpd, secrets, spec, tslint: the spec leg's node contract printed its 18 `SKIPPED BY NAME` lines and passed), lean FAILED at the chain leg (the harness leg before it printed `rules_check: GREEN (...; 8 BOUNDED by withheld entries (the public edition), not reproduced)`), record FAILED downstream.

| job | leg | what it printed |
|---|---|---|
| lean | chain (`chaincheck --refinement`) | 16 lines `refinement: RED <row>: leg <lane>'s record docs/records/20261017-...-s4b.md absent` (six records: the #92, #93, #94 and #152 Teranode records), then `refinement: RED [X] (...)`; `gate: leg chain exit 1, wall 35 s` |

## 2. The cause

The same six withheld records the node contract met in the spec leg (the record of 20:55 UTC), met again by the Lean refinement check in `lean/Test/ChainCheck.lean`, which tested every landed leg's record for existence and counted an absence as a failure.

## 3. The fix (commits 6506590c and 300f3f91 on cap/flip-3, the Lean seat's tag)

`withheldAtExport` reads `tools/export_withheld.txt` and answers true for a path an exact line of the list names (the list's globs name directories, never a record). A landed leg's record that is absent and withheld is printed as `refinement: SKIPPED BY NAME <row>: leg <lane>'s record <path> withheld at export (the private history holds it)` and counted apart from the failures; an absent record not on the list stays RED. The private tree carries every record, so nothing changes there. No Lean build ran on the Studio (no build cache near, the load above the line); the box compiled and ran it in its tripwire.

## 4. The verification [X]

- 6506590c placed the new definition between the file's `open BsvChain.Teranode.Refinement in` line and the report, so the open applied to the definition and the report lost its names: the box tripwire RED (`lean: lake build FAILED`, record 20261026-220927). The file was compiled alone on the box (the module rebuilt in seconds, 0 errors) with the definition above the open line and a plain string compare, then committed as 300f3f91.
- The box tripwire GREEN on 300f3f91 (record 20261026-221405): `lean: build OK, sorry-free`; `refinement: GREEN [X] ([M] 54 rows of corpus/teranode/map.json, ...)`; `chain: GREEN [X] (spec projection; replay wall [M] 11.770533s, ...)`. In the private tree no `SKIPPED BY NAME` line is printed (every record is present); the public edition's run prints 16 of them and no RED, which the eighth edition's hosted run shows.

## 5. What follows

The eighth edition from the landed main; its hosted run is the one that reaches the bench leg on a public tree. The three rounds of 2026-10-26 share one shape: the export withholds material by the owner's word, and every reader of the public edition must meet that material by name, say so, and never count it as a pass or a failure. The readers now doing so: the records index, the Teranode dry run, the node contract, the classifier checker (bounded), the refinement check.
