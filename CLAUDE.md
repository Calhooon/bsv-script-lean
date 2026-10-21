# CLAUDE.md: working in bsv-script-lean

This page is for a coding agent working in this repository. A human contributor reads `CONTRIBUTING.md`.

## The project in five lines

1. An executable, machine-checked specification of the bitcoin-sv node's consensus rules at a pinned release, written in Lean 4.
2. The evaluator `eval/bsvs` is compiled from the Lean definitions; it is the oracle the harness runs.
3. The harness (`harness/`) runs transactions against SV-node, Teranode, bsv-rs, go-sdk, ts-sdk and GoBDK and reports each disagreement as a witness transaction.
4. The corpus (`corpus/`) is the judge: the spec is wrong until the corpus agrees with SV-node.
5. Policy limits are parameters with their defaults and sources (`docs/PARAMETERS.md`); the pins are `docs/PROVENANCE.md` §1a.

## Read in this order

1. `docs/README.md`
2. `docs/WRITE-UP.md`
3. `docs/DESIGN.md`
4. `docs/PROVENANCE.md`
5. `docs/HYPOTHESES.md`

Terms of art are defined in `docs/GLOSSARY.md`.

## The constitution (`NORTH-STAR.md` §2)

- **01** Consensus rules are the spec; policy limits are parameters. The line between them is written down with citations, at the script layer and, since archived #58 (2026-10-07), through the transaction state machine the script verdict lives in (`docs/DESIGN-S6.md`), where the mempool is parameters almost entirely.
- **02** Every rule cites the reference source at a pin. Memory is not a source.
- **03** The semantics is executable, and the evaluator is the oracle.
- **04** A disagreement is a witness transaction, never a sentence.
- **05** Nothing from a non-public project enters this repository.

## Verify the base

Use the pinned toolchains of `docs/PROVENANCE.md` §1a and the setup in `harness/README.md`. From the repository root:

```sh
make verify
```

`make verify` runs the Lean build, the axiom check, the evaluator self-test and the smoke run, in order (wall 30.30 s and peak 1.71 GB with a warm Lean build, `docs/records/20261021-150738-verify-pub-lean.md`; a cold build adds Mathlib's fetch and the whole project's compile, and the kernel-checked chain run alone took 229 s and 28.1 GB, `docs/records/20261014-061809-stale-cost-s1.md`).
`make check` runs the twenty-nine legs of `tools/check.sh` and writes its record under `docs/records/` (it needs the TypeScript adapter, which `make tssdk-install` installs); `tools/check.sh <leg>` runs one leg.

## The rules

- **Cite.** A rule cites the reference source at its pin: file and line, labeled `[SRC]`. `tools/cite_check.py` checks every anchored citation.
- **Consensus versus policy.** A policy limit enters only as a named parameter with its default and its source. When two reference releases disagree, record both readings with citations; the maintainers rule.
- **Wording.** Run `tools/wording_gate.sh` after every page edit; it must exit 0. Never the ordinal that ranks this work, never "conformant" without a named run, never "consensus" for a policy limit, no long dashes.
- **Labels.** `[M]` measured, `[X]` executed, `[D]` derived, `[EST]` an estimate, `[LIT]` cited, `[SRC]` read from the source at its pin. They stand in records, claim tables and the provenance pages. On an entry page a label appears only inside a table; a prose sentence cites its record path under `docs/records/`.
- **Records.** Every count, wall or verdict a page quotes names the record it came from.
- **Corrections.** A correction is not landed until the original sentence is gone.
- **Lean.** Write the statement before the proof. No `sorry`. A main theorem depends only on `propext`, `Classical.choice` and `Quot.sound` (`lean/AXIOMS-ALLOWED`; `make axioms`). Every theorem has an explainer in its docstring.
- **License.** Two licenses by path; `NOTICE` names which path is under which (`LICENSE`, `LICENSE-APACHE`).

## Do not

- write a rule without its `[SRC]` citation;
- commit a `sorry`;
- reach the network from the harness: the node oracle is a private regtest, and nothing is ever broadcast;
- call a policy limit consensus;
- edit the semantics to make a harness run pass;
- quote a number without its record.

Report a divergence with the issue template (`.github/ISSUE_TEMPLATE/divergence.md`); report a security concern privately (`SECURITY.md`).
