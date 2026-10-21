# The flip's export, the full gate CLEAN, and the birth of the public edition as a private repository

[M] 2026-10-21, on the Studio, by CAP the captain (Claude Fable 5.1), from the clone of `main` at `d7a8ea52`
(pulled, no tracked change). The chain ran unattended under one script: the export, the full gate with the build
road, and on `export gate: CLEAN` the birth script with its push.

## 1. The export

[M] `make export-public COMMIT=HEAD` from 21:05:52 to 21:10:18 UTC (266 s): 2,062 paths exported, 281 withheld;
the records transform replaced 6,339 lines in 603 files by the marker; `CLAUDE.public.md` moved over `CLAUDE.md`
in the exported copy. Manifest line `source-commit d7a8ea52bb209ceadae166c4ebf226718a74ccae`. The export directory
is `flip-20261021-210552` under the exports' home outside the tree, kept with its logs.

## 2. The full gate, CLEAN in 8 minutes

[X] `tools/export_gate.py <export> --build` from 21:10:18 to 21:18:21 UTC (483 s against 2,934 s at the rehearsal of
2026-10-18 and no verdict after 2 h 37 min earlier tonight, record `20261021-205040-export-flip-gate-hex-leg-cap.md`).
Every leg line, verbatim but for the two cargo lines cut after the executable count:

```
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
(wording, history) 239 hit(s) in 90 file(s); conformance-claim 12; long-dash 53; priority-word 174
(build) cargo build --release --locked --offline: exit 0, wall 58.0 s, 26 executable(s)
(build) cargo test --release --locked --offline --no-run: exit 0, wall 21.0 s, 31 executable(s)
(build) cold target removed, 0.4 GiB freed
export gate: CLEAN
```

The history count (the wording leg over `docs/records/` and `docs/audit/`, counted, not gated) is 239 against the
rehearsal's 248: nine fewer lines after #177's fixes, with the night's new records in the set.

## 3. The birth (#113, shape I1; #176 the tag)

[X] `birth.sh <export> <work> --push` at 21:18:21 UTC: the export's tree copied without a `.git`, one root commit
`P0 = ed7480c4c15d1c45ee2030b66619b6b99e4fbeb8` (tree `4760e1fbcd4394200c5b92f92bcf111855458d41`, 2,062 files, the
message naming `source-commit d7a8ea52…`), the annotated tag `v1.2.0` on it, the repository created PRIVATE at
https://github.com/Calhooon/bsv-script-lean (created 2026-10-21T21:18:32Z, default branch `main`, wiki off), `main`
and the tag pushed. Read back by the API after the push: `main` at `ed7480c4c15d`, tag `v1.2.0` at the same commit,
README 17,104 bytes; the local pack 93 MB. The exported `.github/` carries the workflows and the issue templates;
`docs/img/` the cover, the diagram and their provenance page.

## 4. What waits on the owner

The owner reads the private repository. His word `flip: public` runs `gh repo edit Calhooon/bsv-script-lean
--visibility public --accept-visibility-change-consequences`, the release `v1.2.0` from `CHANGELOG.md`, the filer
`tools/flip_issues.py --repo Calhooon/bsv-script-lean --go` with its mapping record, the word to both consumer
programs with T0 and the URL, and the closing of #34, #102, #103, #107, #113, #170 and #176. Owed before that word
(#177): the four spec lines from strings inside `Refinement.lean`, and the eleven clone and binary path values of
the PROVENANCE pins block. The private repository is archived only once the overlay repository exists.
