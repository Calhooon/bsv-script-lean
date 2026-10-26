# The second edition before the flip: #177's two owed items exported, the full gate CLEAN, pushed as the private repository's second commit

[M] 2026-10-21, on the Studio, by CAP the captain (Claude Fable 5.1), from the clone of `main` at `c881a90f`
(pulled, no tracked change), under the chain of the birth record `20261021-211821-export-flip-birth-cap.md`
with the second edition's script in place of the birth script.

## 1. What `c881a90f` carries over `d7a8ea52`

The two items #177 owed before the public flip, landed at content tip `93692d97` behind a GREEN box tripwire
(`20261021-224101-make-check-box.txt`): (a) the process words inside string fields and docstrings behind the
generated spec pages (lanes fix-177a, fix-177a2, fix-177c, fix-177a3; records `20261021-214929`,
`20261021-220735`, the fix-177c record of 22:12 and `20261021-223933`): the five `owner` data values stay `S4b` and
render by area through one map in `tools/node_contract.py`; (b) the eleven host paths of the PROVENANCE pins block
as `$BSV_SPEC_*` names resolved by `tools/host_vars.py` and `harness/src/host.rs` (lanes fix-177b, fix-177b2;
records `20261021-214600`, `20261021-222041`). Four lenses: lens-177b and lens-177a NOT HELD, each fixed by a lane,
relens-177b and relens-177a HELD. Also the gate's hex leg re-cut and the pin commit allowlisted
(`20261021-205040`), landed at `d7a8ea52` and so already in the birth.

## 2. The export and the gate

[M] `make export-public COMMIT=HEAD` from 22:47:23 to 22:51:38 UTC (255 s): 2,073 paths exported (2,062 at the
birth; the new records and the resolvers), the records transform 6,345 lines in 605 files; manifest line
`source-commit c881a90fed991af39ce2dc7b527977c078c8d2c6`; directory `flip-20261021-224723`.

[X] `tools/export_gate.py <export> --build` from 22:51:38 to 22:59:15 UTC (457 s): every gated leg 0 hits
(withheld-rule, mechanism with its leg 2 over 198 corpus files against 3 present sibling trees exit 0, pointer with
every class 0 including local-paths 0, wording), the history count 239 in 90 files as at the birth, the build road
exit 0 both steps (53.9 s and 17.1 s, 26 and 31 executables), `export gate: CLEAN`.

## 3. The push

[X] `birth2.sh <export> <work> --push` at 22:59:15 UTC: the export's tree copied over the born working copy
(`rsync --delete`, the `.git` kept), one commit `P2 = 60717f1773e16e68c6a78b9cbc3ce906f2793251` (tree
`1cd305b51ceb…`, 2,073 files, 72 files changed, 2,651 insertions, 382 deletions against the birth commit, the
message naming `source-commit c881a90f…`), pushed to `main` of https://github.com/Calhooon/bsv-script-lean
(still PRIVATE): `ed7480c..60717f1`. The tag `v1.2.0` stays on the birth commit `ed7480c4` until the flip's own
step moves it to the final tip, with the release.

## 4. What waits on the owner

Unchanged from the birth record's §4: the owner's word `flip: public`. Nothing is owed on #177 after this push;
it closes with this record.
