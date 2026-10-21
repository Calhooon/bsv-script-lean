# Citation scanner proposal [LIT] 2026-09-30T00:36:18.983775+00:00

Model: Codex GPT-6.1-Sol. This is a patch for the file owner S4b, not an applied change.

The existing scan_sites function opens history before resolve classifies it as non-authoritative. The full scanner is therefore held in the permitted sitting. The proposal skips HISTORY_PREFIX before opening a file. No actual history record was opened by this rehearsal.

Patch: `20260930-003618-cite-history-before-open-proposal-s3.patch`. The owner-held records remain closed. S4b currently gets no paste under Continue [LIT] 55. Ask W0 to route this bounded scanner correction to its owner or provide an owner-executed full tripwire receipt. The change requires S4b's review of history accounting and table orphan handling before it can land.

Synthetic fixture verification [X]: live files opened [D] 1; history files opened [D] 0; returned live citation sites [D] 1. The builtins.open guard would fail on the fixture's history path. The full scanner and tracker were not called.

Transcript:
```text
scan_sites with a synthetic ROOT and SCAN
opened: ["docs/live.md"]
returned sites: ["docs/live.md"]
exit: 0
```
