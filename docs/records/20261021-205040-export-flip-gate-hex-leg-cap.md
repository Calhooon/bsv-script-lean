# The flip gate's hex leg on 2026-10-21: the pin commit in eleven corpus files, and the leg re-cut to one pass

[M] 2026-10-21, on the Studio, by CAP the captain (Claude Fable 5.1), on the export `flip-20261021-175544`
of main `78ffed2d` (`make export-public`, `~/bsv/targets/spec-export/`, outside the tree). The full gate
(`tools/export_gate.py <export> --build`) started at 18:00:52 UTC from the clone of `main` with the 1-minute
load at 5.35. Its mechanism leg 2 (`tools/mechanism_hex.py`, the corpus's long hex strings against the three
sibling trees) was still running at 20:31 UTC, 2 h 31 min in, the child at 98.8 % of one core at nice 5, with
the gate's log empty (the gate writes it at the end). The rehearsal of 2026-10-18 (record
`20261018-034524-s3-107-export-gate-rehearsal-s3.md`) ran the same 198 corpus files in about 46 min; the
walls below say why tonight's run was slower and what it would have said.

## 1. The measurement

[M] One pass of the leg's inner loop over the three sibling trees' tracked files (the same regular
expression, every 40-character window of every hex run looked up in a dictionary), timed at nice 0 with the
load under 3:

| tree | tracked files | bytes | hex runs (≥ 40 chars) | windows | wall |
|---|---|---|---|---|---|
| sibling A | 3,687 | 103 MB | 29,310 | 1,193,432 | 2.0 s |
| sibling B | 10,595 | 292 MB | 343,046 | 18,921,309 | 8.7 s |
| sibling C | 1,738 | 91 MB | 14,262 | 830,217 | 1.6 s |
| one pass | | | | | 12.4 s |

[M] The script as landed re-read all three trees once per corpus file; the real leg on four sample corpus
files took 14, 14, 14 and 16 s each one by one (61 s for the four in one run), so the 198 files cost about 46 min at full
speed, and sibling B had grown by 2,676 commits since the rehearsal. For the opening hour the
Studio's load stood near 14 on 10 cores with the child niced, which stretched the wall past 2.5 hours. The
child was stopped at 20:38:08 UTC without a verdict; the sentinel never fired.

## 2. What the leg would have said: RED, one public constant

[X] The sample run on `corpus/witnesses/sv-node/tx.jsonl` printed two `(2) FAIL` lines: two record files of the
sibling tree B, both dated 2026-10-20, contain a hex string of that corpus file. The string is
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, the reference pin: bitcoin-sv tag `v1.2.3`'s commit
(`docs/PROVENANCE.md` §1a, `reference.commit`), the `[SRC]` locator every chain, oracle and sv-node witness row
carries. It is exactly 40 characters, so the leg counts it. Eleven exported corpus `.jsonl` files carry it
(`corpus/chain/{block,chain,depth,eras,finality,frozen,mempool,oracle,utxo}`, `corpus/witnesses/sv-node/tx.jsonl`,
`corpus/witnesses/sv-node-v1.2.2/tx.jsonl`; the private tree has four more, which carry it only in a field
`tools/export_withheld_entries.txt` withholds); the sibling program's records cite the same public release commit
when they read the reference's source. Nothing of that program is in this tree: the shared string is the
upstream's commit hash, which the rehearsal did not meet only because those records landed there on 10-20.

## 3. The fix

- `tools/mechanism_allow.txt`: two named public constants added, the v1.2.3 pin commit and the v1.2.2
  commit (`879fc8b42168dd0e608dafd51b39c6dabad37d4d`: `gobdk.reference_commit` and
  `association-docs.reference_commit`, the reference tag of GoBDK and of the Association's documentation), each with its
  PROVENANCE line and its GitHub release URL. The v1.2.2 commit sits in no corpus `.jsonl` file today (the
  receipts and manifests that carry it are not in the leg's set); it is listed so the next witness family that
  cites it does not stop a gate.
- `tools/mechanism_hex.py` re-cut to one pass: every corpus file's patterns are indexed before any sibling is read (one prefix
  dictionary over all files), each sibling's tracked files are read once, and a prefix hit is confirmed by a
  prefix test on the hex run at that position (every character of a pattern is hex, so an occurrence lies inside
  one maximal run, and the window loop visits every start) instead of a search of the whole file per candidate.
  The verdict per (corpus file, sibling file), the hit counts and the exit code are the same as before; the output
  is per corpus file in argument order with the siblings in their order; the pattern a `FAIL` line quotes can differ
  when one sibling file holds two patterns of one corpus file (the old scan quoted whichever candidate it found anywhere
  in the file, and the lens found that quote varied with the hash seed: 2 outputs over 12 seeds).

[X] The differential: the old and the new script on the four sample files, same arguments, same allow list
(before the entries): byte-identical output, exit 1 both, 61 s against 13 s. The lens lens-hex (Claude Opus 5.5,
2026-10-21) ran both on 14 planted cases in a throwaway sibling repository: every verdict, exit code and hit count
equal; its first round found the absent-sibling line printed out of sibling order (re-cut) and the quoted-pattern
difference above (documented). The new script over all 198 files
before the entries: exit 1 in 27 s, 22 `FAIL` lines over the eleven files of §2 and no other, 197 summary
lines plus the one path-allowlisted header family. After the entries: exit 0 in 29 s, 0 hits, the eleven files
each naming the pin as an allowlisted constant. `tools/test_mechanism_hex.py`: 4 tests OK. `tools/tools_index.py
--check`: current.

## 4. Owed

The full gate re-run from the clone of `main` on a fresh export after this lands (the exported `tools/` must
carry the re-cut leg and the entries); the birth of the public repository waits on its `export gate: CLEAN`.
