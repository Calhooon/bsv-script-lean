# corpus/wire: the client wire formats (#86)

[M] 2026-10-15, lane wire-86. Mainnet-derived files of the five client wire formats the spec reads as views
(`lean/BsvChain/Views/Wire/`; the page `spec/wire-views.md`): EF (BRC-30), BUMP (BRC-74), BEEF (BRC-62 and
BRC-96), Atomic BEEF (BRC-95) and the binary TSC merkle proof (#75). Views, never rules: no consensus or policy
rule of the node reads these formats. READ ONLY (CLAUDE.md rule 10): every mainnet byte here was read by a
public GET from WhatsOnChain; nothing was ever broadcast.

| file | rows | what a row is |
|---|---:|---|
| `ef.jsonl` | 24 | 19 EF transactions [D] built from a mainnet transaction and its parents' outputs (value width 8), 5 degenerate shapes |
| `bump.jsonl` | 35 | 22 BUMPs [M] as WhatsOnChain serves them, 4 compound BUMPs [D] (two paths of one block merged), 9 degenerate shapes (8 from one mainnet BUMP, `reversed-level-0` from a compound BUMP's four-leaf level 0) |
| `beef.jsonl` | 33 | 22 BEEFs [M] as WhatsOnChain serves them, a parent-and-child chain in versions 1 and 2 and a txid-only parent [D], 8 degenerate shapes |
| `atomic-beef.jsonl` | 30 | 22 Atomic BEEFs [D] (the prefix, the subject, a BEEF as read), version 2 inside, 7 degenerate shapes |
| `tsc.jsonl` | 28 | 22 binary TSC proofs [D] from the JSON proof as read and the block header (four flag shapes in turn), 6 degenerate shapes |
| `reads.jsonl` | 144 | every read a row cites: URL, UTC time, HTTP status, bytes, sha256 of the body |

A row: `id`, `format`, `shape` (`mainnet` or the degenerate shape's name), `label`, `hex` (the file),
`reads` (the URLs it rests on), `derivation` (the construction or the mutation, in words), `subject` (the
display txid it is about); a TSC row also carries `block_height`, `header_hex` and `bump_hex` (the BUMP
WhatsOnChain serves for the same transaction, the engines' side of the TSC comparison). The degenerate shapes
are derived from a mainnet row (or, for `reversed-level-0`, a compound row) by the mutation the row names; none is
a mainnet file [X] (no degenerate row's `hex` equals a mainnet row's).

**Generate:** `python3 tools/wire_corpus.py fetch` (the public reads, kept in `scratch/wire86-cache/`), then
`python3 tools/wire_corpus.py build` (offline, deterministic; `python3 tools/wire_corpus.py check` compares). **Run** (from the
repo root; the five files in this order, which the columns' sha256 values depend on; sh or bash; under zsh write `${=W}`):

```sh
mkdir -p scratch/bin
W="corpus/wire/ef.jsonl corpus/wire/bump.jsonl corpus/wire/beef.jsonl corpus/wire/atomic-beef.jsonl corpus/wire/tsc.jsonl"
(cd lean && lake build wirecheck) && lean/.lake/build/bin/wirecheck $W > scratch/spec.jsonl
cargo build --manifest-path harness/Cargo.toml --locked --release --bin run_wire && harness/target/release/run_wire $W > scratch/rs.jsonl
(cd harness/engines/go && go build -o ../../../scratch/bin/wire-go ./wire) && scratch/bin/wire-go $W > scratch/go.jsonl
(cd harness/engines/ts && npm ci) && node harness/engines/ts/wire.mjs $W > scratch/ts.jsonl
python3 tools/wire_compare.py --corpus corpus/wire --spec scratch/spec.jsonl --engine bsv-rs=scratch/rs.jsonl \
  --engine go-sdk=scratch/go.jsonl --engine ts-sdk=scratch/ts.jsonl --json OUT.json --columns-out OUT
```

The counts of record, the four columns and every witness with both lines are in the conformance record
`corpus/INDEX.md` names.

[M] 2026-10-17 (#107, lane gate-107): `tsc-001`'s `header_hex` is mainnet block 1's header, a public read (its URL
and time in `reads.jsonl`; its SHA256d is the block hash the read names). A sibling tree holds the same public
header, so `tools/mechanism_allow.txt` names it among the mechanism check's public constants, with that source.
