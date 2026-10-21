# The spec pages' remaining seat tags re-cut at their sources (#177, item a, third part)

[M] 2026-10-21, on the build host, cut from `cap/pub-reader` `97b4b5b5`, by Claude Opus 5.5. The Lean commit `5f2cad2e`
(S1), `a0b21ff3` (S2), `c1874bc8` (S3, `corpus/INDEX.md` and `spec/`). Comment text and one prose string only: no
theorem statement, def, proof, lemma name or [SRC] citation moved; no Lean build (a docstring edit needs none).

## 1. The 35 lines classified [M]

`grep -nE "\bS[1-4]b?\b|\bT3\b|\bW0\b" spec/*.md` at `97b4b5b5`: 35 lines. 28 are seat tags, 7 are not.

Not seat tags (7): `node-client-contract.md:12` (the test label "T3 fast and cheap"); `modules.md:3160` ("The owed
theorems (T3, T4, ...)", theorem labels); `theorems.md:10185`, `10523` (the proof step "T3"), `10528` ("**T3,
canonicality**", the theorem's label); `theorems.md:10994` "T-S1", `11000` "T-S2" (lemma labels).

Seat tags (28), from 24 source lines: `rules.md:3` (from `tools/specgen.py:708`), `rules.md:30` to `34` (five rows, one
source: `corpus/INDEX.md:74`), and 22 docstring lines, below.

## 2. Each source line, before and after [M]

| source | page line(s) at 97b4b5b5 | before | after |
|---|---|---|---|
| `lean/BsvChain/Teranode/Refinement.lean:44` | modules.md:1380 | stays owed, S1. | stays owed on the Lean side. |
| `Refinement.lean:45` | modules.md:1381 | is owed (S1), since | is owed (the Lean semantics), since |
| `Refinement.lean:59` | modules.md:1395 | is owed (S1). | is owed (the Lean semantics). |
| `Refinement.lean:62` | modules.md:1398 | are owed with S1, | are owed to the Lean semantics, |
| `Refinement.lean:109` | modules.md:1445 | yet (S3's). | yet (the harness's). |
| `Refinement.lean:296` | theorems.md:6990 | is owed, S1: | is owed on the Lean side: |
| `Refinement.lean:361` | theorems.md:7036 | RUNNING is owed, S1. | RUNNING is owed on the Lean side. |
| `lean/BsvScript/Gadget.lean:19` | modules.md:2751 | tree by S1 under its own tag (the file is S1's glob by `docs/OWNERS`; | tree on the Lean semantics' side (the file is in that area by `docs/OWNERS`; |
| `lean/BsvScript/Properties/Resources.lean:6` | modules.md:3622 | (#25, S1's half; | (archived #25, the Lean semantics' half; |
| `lean/BsvScript/SigOps.lean:6` | modules.md:3850 | (2026-09-27, S1: the spec gap | (2026-09-27, the Lean semantics: the spec gap |
| `lean/BsvScript/TxPolicy.lean:484` | theorems.md:14242 | Since S2's `616008e` | Since the Lean families' `616008e` |
| `lean/BsvScript/Properties/Eras.lean:33` | modules.md:3399 | (#25, S2, 2026-09-26) | (archived #25, the Lean families, 2026-09-26) |
| `Eras.lean:807` | modules.md:3453 | (#25, S2, 2026-09-27) | (archived #25, the Lean families, 2026-09-27) |
| `lean/BsvScript/Sighash.lean:31` | modules.md:3908 | (S3; `corpus/gen`, | (the harness; `corpus/gen`, |
| `Sighash.lean:433` | modules.md:3957 | (#25, S2, 2026-09-26) | (archived #25, the Lean families, 2026-09-26) |
| `Sighash.lean:708` | modules.md:3961 | (#25, S2, 2026-09-27) | (archived #25, the Lean families, 2026-09-27) |
| `lean/BsvScript/TxRules.lean:253` | modules.md:4188 | (#25, S2, 2026-09-27) | (archived #25, the Lean families, 2026-09-27) |
| `TxRules.lean:636` | modules.md:4198 | (2026-09-27; S1's ask 5) | (2026-09-27; the Lean semantics' ask 5) |
| `TxRules.lean:638` | modules.md:4200 | `SigOps.sigOpCount` (S1's) | `SigOps.sigOpCount` (the Lean semantics') |
| `lean/BsvScript/Tx.lean:156` | theorems.md:14075 | (lean #48; S1's ask 7) | (archived #48; the Lean semantics' ask 7) |
| `Tx.lean:187` | theorems.md:14081 | `@[csimp]` (S1's ask 4 (a)) | `@[csimp]` (the Lean semantics' ask 4 (a)) |
| `Tx.lean:199` | theorems.md:14085 | `@[csimp]` (S1's ask 4 (a)) | `@[csimp]` (the Lean semantics' ask 4 (a)) |
| `corpus/INDEX.md:74` | rules.md:30 to 34 (and the five `spec/opcodes/OP_{SUBSTR,LEFT,RIGHT,LSHIFTNUM,RSHIFTNUM}.md` rows) | on the parent's lens of S1's section | on the harness's lens of the Lean semantics' section |
| `tools/specgen.py:708` | rules.md:3 | the S3 witness families | the harness's witness families |

The words are the AREA map of `tools/node_contract.py`. An issue number inside a re-cut tag is written "archived #n"
(`docs/GLOSSARY.md`); other `#n` on the same lines, outside the tags, are unchanged. The seats by `docs/OWNERS`:
Refinement, Gadget, Resources, SigOps, TxPolicy are S1's; Eras, Sighash, TxRules, Tx and `tools/specgen.py` are S2's;
`corpus/INDEX.md` (a tie) and `spec/` committed under S3.

## 3. The checks [X]

- `make -n spec` prints `tools/specgen.py` only (no Lean build); `make spec` exit 0: "123 files written ... 1 rules flagged";
  `python3 tools/specgen.py --check`: "specgen --check: OK (123 files up to date; 1 rules flagged)".
- `git diff --stat -- spec`: 8 files, 33 insertions, 33 deletions (modules.md 16 lines, rules.md 6, theorems.md 6, five
  opcode pages 1 each).
- `bash tools/wording_gate.sh <file>`: CLEAN on each of the 11 source files and the 8 spec pages.

## 4. The grep after [M]

`grep -nE "\bS[1-4]b?\b|\bT3\b|\bW0\b" spec/*.md` at `c1874bc8`, 7 lines, exactly the 7 classified as not seat tags:

```
spec/modules.md:3160:## The owed theorems (T3, T4, T6, T7, T8)
spec/node-client-contract.md:12:- section 4: the six tests, T1 scale, T2 verify, T3 fast and cheap, T4 law, T5 trust, T6 executable
spec/theorems.md:10185:and sign (the definition's `if` on the sign, as a match on the pair; the shape T3 and
spec/theorems.md:10523:`signTopRev (t :: rest) true`, reversed back. With `encode_beNat_pos`, the step T3 and
spec/theorems.md:10528:**T3, canonicality**: a minimal encoding is the encoding of its value
spec/theorems.md:10994:T-S1: a swap keeps the depth (`swapElements`, `limitedstack.cpp:285–288`).
spec/theorems.md:11000:T-S2: an erase below the top removes one element (`erase`, `limitedstack.cpp:260–267`).
```

Outside the item's pattern scope: `grep -rnE` over `spec/opcodes` prints one line, `OP_CHECKSEQUENCEVERIFY.md:64`, the
[LIT] citation's "THEIRS T3" (from `lean/BsvScript/Params.lean:188`), a label of the cited page, not a seat tag; left
as cited. Seat tags in Lean comments that no page renders (for example `Refinement.lean:276`, `483`, `493`, `502`,
`Machine.lean:211`, `BsvScript.lean:89`) are not on a page and were not touched.
