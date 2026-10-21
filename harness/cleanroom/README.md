# harness/cleanroom: a script evaluator written from the published spec alone (#37)

[M] 2026-10-15, lane cleanroom-37 (S3), under the owner's words of 2026-10-15 on card N1
(the clean-room check). This directory is a second, independent reading of the
specification: an evaluator written in Python from the generated specification
document and nothing else, run over the corpus, its verdicts compared with the
node's recorded verdicts. It is a check on the DOCUMENT: where the pages
determine a behavior, the clean room should agree with the node; where they do
not, the clean room says so instead of guessing.

## The one rule

The evaluator is written from the published pages alone. The lane never opens,
greps, reads or lists `lean/`, `eval/`, `harness/src/`, `harness/engines/`,
`harness/rules/`, `tools/specgen.py`, `tools/cite_check.py`, any record under
`docs/records/`, any `.lean`, `.rs`, `.go`, `.ts` or `.mjs` file of this tree,
bsv-rs, the bitcoin-sv source, or any other implementation. A breach, if one
happens, is written in the lane's record, never hidden.

## The sources (the complete list)

- `spec/*.md` and `spec/opcodes/*.md`: the generated specification (the module
  docstrings, the opcode pages, the rules, the theorems with their explainers,
  the flags, the errors);
- `docs/PARAMETERS.md` and `docs/DESIGN.md`;
- `README.md` and `docs/STATE-OF-THE-WORLD.md`, section headings only;
- `corpus/README.md`, `corpus/INDEX.md`, `corpus/cpp/INVENTORY.md` and the corpus
  files themselves (their entries carry the node's recorded verdicts);
- public standards for the primitives the pages name by reference: FIPS 180-4
  (SHA-1, SHA-256), the RIPEMD-160 specification (Dobbertin, Bosselaers and
  Preneel, 1996), SEC 1 and SEC 2 (secp256k1's constants, point encodings, the
  ECDSA digest-to-integer rule), and the BIPs the pages name: BIP 66 (the
  strict DER shape behind `SCRIPT_VERIFY_DERSIG`), BIP 65 and BIP 68 (the
  assumed column only: the pages name the lock constants by `script.h`/
  `transaction.h`, not by BIP), BIP 143 (the digest the pages call BIP143-style).

## The language and the shape

Python 3, standard library only (`hashlib` for SHA-1 and SHA-256; RIPEMD-160
and the curve are written here from their public definitions, slow and plain).

- `cleanroom.py`: the evaluator. Every function names, in a comment, the
  sentence of the pages it implements (`spec/<page>.md:<line>` or
  `docs/<page>.md:<line>`). A behavior the pages do not determine is written
  as `raise DocumentGap(...)` naming what is missing; it is never guessed.
- `run.py`: the runner. `python3 harness/cleanroom/run.py --all` reads every
  corpus the clean room handles, evaluates each entry under its documented
  parameters, compares with the node's recorded verdict, and writes
  `harness/cleanroom/out/<corpus>.json` with `agree`, `diverge` or `gap` per
  entry and the counts.

## The reading rule

An operation is implemented when the pages state its effect in words or in a
formula (a docstring, a sentence of DESIGN, a theorem's "what it says", a
rule's "what it exercises"). An operation the pages only NAME (an opcode whose
effect appears nowhere but in its name, a constant named without its value) is
a `DocumentGap`. A constant or a shape the pages name by a public standard
they cite (BIP 66, BIP 65, BIP 68, BIP 143, SEC 1) is taken from that
standard and marked `[LIT]` in the comment.

Two columns are reported for every corpus:

- **strict** (the deliverable): every gap raises; an entry whose evaluation
  reaches a gap is `gap`, never `agree` or `diverge`;
- **assumed** (labelled, outside the one rule's guarantee): the assumed column
  fills every gap `cleanroom.GAPS` gives a reading (the opcode names, five
  constants, and the readings of the multisig loop, the shift's bit order, the
  vector files' limits, the finality comparison, the empty `OP_VERIFY`'s
  reason, the hybrid key's parity and the shift-number operand order), each
  fill named per entry (`cleanroom.py`'s `GAPS` table gives the reading and
  `ASSUMPTIONS` the set). This column measures the REST of the document: given
  those fills, does what the pages do say agree with the node.

The strict column's `gap` rows, grouped by gap, are the lane's Findings for S2
(the generator's seat): each is a sentence the pages would need.
