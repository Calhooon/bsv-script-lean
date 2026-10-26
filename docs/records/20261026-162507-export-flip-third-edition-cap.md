# The third edition before the flip: the pre-items and the README, exported, the full gate CLEAN, pushed as the private repository's third commit

[M] 2026-10-26, on the Studio, by CAP the captain (Claude Fable 5.1), from the clone of `main` at `642f3ea0`
(pulled, no tracked change), by the session's chain script (pull, export, gate with the build road, the account-name
scan, rsync over the born working copy, one commit, push), under the chain of the birth record
`20261021-211821-export-flip-birth-cap.md` and the second edition's `20261021-225915-export-flip-second-edition-cap.md`.

## 1. What `642f3ea0` carries over `c881a90f` (the second edition's source)

Landed behind GREEN box tripwires `20261026-144745` (41723312, 93 s) and `20261026-155633` (af395213, 79 s):
the pointer gate's group `agent-paths` (the flattened account component, the agent scratch prefix, and the bare
account name; record `20261026-135901`); the dated ignore of RUSTSEC-2026-0387 in `harness/deny.toml` with #178
staged for the public tracker (`20261026-135945` RED on the deny leg; Calhooon/bsv-rs#265); the light hosted gate
(no swap file; the axioms leg SKIPPED BY NAME under VERIFY_LIGHT=1; the withheld row `axiom-check`); the public
tracker filed on the private repository (`20261026-145126`: 3 milestones, 25 issues); the README's four new
sections by lane readme-flip (`20261026-151123`) with the cold lens's eight findings fixed (the lens
lens-readme-flip of 15:4x UTC, NOT HELD, its REPORT in the lane's record); the records index's archived-#n sentence.

Before this edition, by the owner's pick on the flip review page: the two commits of the private repository were
rewritten to the GitHub noreply address (the author and the committer; `ed7480c4` became `92287f18`, `60717f17`
became `f71b07c3`, the tag `v1.2.0` moved to `92287f18`), the objects pushed under temporary refs and the refs moved
by the API (the shared-checkout guard refuses a force-push by name).

## 2. The export and the gate

[M] `tools/export_public.sh HEAD` from 15:58:22 to 16:09:04 UTC (642 s): directory `flip-20261026-155822`;
manifest line `source-commit 642f3ea031bbef395e03f8683b7c72796c31556f`.

[X] `tools/export_gate.sh <export> --build` from 16:09:04 to 16:23:24 UTC (860 s): every gated leg 0 hits, the build
road exit 0 (`cargo test --release --locked --offline --no-run` 42.3 s, 31 executables; the cold target removed),
`export gate: CLEAN`.

[X] The account-name scan of the export (the chain's own grep for the flattened component, the agent scratch prefix
and the bare name): clean. The captain's wider scan of the same export (35 patterns: names, handles, addresses,
home paths, hosts, the private programs, the vault, secret shapes): the matches are the copyright and contact lines
("John Calhoun", 3 files), the GitHub login in the records' read logs ("Calgooon"), and the records' host-role words,
as at the second edition; nothing new.

## 3. The push

[X] The export's tree copied over the born working copy (`rsync --delete`, `.git` kept), one commit
`P3 = 3af8824615d9a47364ee5a9cfd6a1447e9336a4d` by the noreply author (31 files changed, 4,357 insertions, 110
deletions against P2), pushed to `main` of https://github.com/Calhooon/bsv-script-lean (still PRIVATE). The tag
`v1.2.0` stays on `92287f18` until the flip's own step moves it to the tip with the release.

## 4. What waits on the owner

`flip: public`: the visibility switch; private vulnerability reporting on; the topics; the tag moved and the release
cut from `CHANGELOG.md`; the consumers told; the private issues closed; the branch protection; the post.
