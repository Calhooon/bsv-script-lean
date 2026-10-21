# Contributing

This repository is an executable Lean specification of the bitcoin-sv node's consensus rules at a pinned release, with a harness that runs implementations against it.
A change lands when it keeps every rule below and the gate stays green.
Terms of art are defined in `docs/GLOSSARY.md`.

## A rule cites its source

- Write a rule only from the reference source at its pin. `docs/PROVENANCE.md` §1a names the pins.
- Cite the file and line at the pin and label the citation `[SRC]`. A rule written from memory is a draft, not a rule.
- `tools/cite_check.py` resolves every anchored `file:line` citation at the pin. A citation that no longer holds fails the gate.
- A correction replaces the old sentence. It is not landed while the old sentence still stands.

## Consensus and policy stay apart

- A consensus rule decides validity for every node. A policy limit is one node's setting.
- A policy limit enters the semantics only as a named parameter, with its default and its source. `docs/PARAMETERS.md` lists them.
- Never call a policy limit "consensus".
- When two releases of the reference disagree, or the reference disagrees with its own documentation, record both readings with their citations. The maintainers rule which reading is consensus.

## Wording

Run `tools/wording_gate.sh` after every page edit. It must exit 0.
It refuses these forms on the public pages:

- the ordinal word that ranks this work against the world;
- never "conformant" without a named run (a conformance claim names the implementation and build, the corpus, the mode, the pins and the run record);
- "consensus" for a policy limit;
- the long dash and the novelty adjectives.

Scope every claim to the pin and the corpus the harness has run.

## Evidence labels

Every count, wall or verdict a page quotes names the record under `docs/records/` it came from.
The labels are `[M]` measured, `[X]` executed, `[D]` derived, `[EST]` an estimate, `[LIT]` cited, and `[SRC]` read from the reference source at its pin.
They stand in records, claim tables and the provenance pages.
On an entry page (`README.md` and its like) a label appears only inside a table; a prose sentence cites its record path instead.

## The gate

`make check` runs the twenty-nine legs that `tools/check.sh` lists in its header:

```
pins fmt clippy cite jscpd deny secrets lean axioms numbers flow sighash arith stack
crypto seed scripttests txtests flags spec bytes versiongate eras witnesses eval
tslint harness chain bench
```

Every run writes its record under `docs/records/`.
The most recent full run on `main` was GREEN on all twenty-nine (`docs/records/20261019-224915-make-check-box.txt`).
`tools/check.sh <leg>` runs one leg.

The hosted gate, `.github/workflows/gate.yml`, runs on every pull request and every push to `main`.
Its jobs call the same steps of `tools/check.sh`:

| job | runs |
|---|---|
| `rust` | fmt, clippy, deny |
| `tree` | pins, cite, jscpd, secrets, spec, tslint |
| `lean` | lean, axioms, the fifteen column legs, harness, chain and bench |
| `withheld-legs` | prints the reads a hosted runner cannot make (`tools/withheld_legs.txt`) |
| `record` | writes the run's record from the three jobs' logs with the writer of `make check` |

A hosted runner has no pinned upstream clone, no built reference and no regtest node.
The legs that need them say SKIPPED BY NAME, never a pass, and a required commit status reports their run elsewhere.
To read a red job, find the last `gate: leg <name> exit <rc>` line; the lines above it are that leg's output.

## Lean discipline

- Write the statement before the proof.
- No `sorry` on `main`.
- A main theorem depends only on Lean's three axioms: `propext`, `Classical.choice` and `Quot.sound` (`lean/AXIOMS-ALLOWED`). `make axioms` checks it. The ECDSA equation is a definition, not an axiom.
- Every theorem carries an explainer in its docstring: what it says, what it assumes, why it matters. `spec/theorems.md` lists them.
- The evaluator is compiled from the definitions. A definition that does not execute is not part of the semantics.
- Never edit the semantics to make a harness run pass.

## Report a divergence

Report a divergence as a witness, never a sentence.
Use the divergence template on the issue tracker. The witness carries:

- the transaction hex;
- its previous outputs and their heights;
- the parameters: the era and the flags;
- both verdicts, with the implementation and its version;
- the rule it exercises;
- the citations at the pins;
- how you ran it: the harness command and its record.

The entry format is `docs/DESIGN.md` §6. `tools/witness.sh <witness-id>` replays a committed witness under `corpus/witnesses/`.
A disagreement between the spec and the reference is a spec bug until someone proves otherwise from the reference source.

A divergence that one implementation accepts and another refuses can split the chain.
Report that kind privately, as `SECURITY.md` describes, never on the issue tracker.

## What never enters

- Nothing from a non-public project enters this repository: no transaction, txid, block, design or issue text of one (`NORTH-STAR.md` §2, rule 05).
- No network from the harness. The node oracle is a private regtest; public mainnet transactions may be read as corpus material, and nothing is ever broadcast.

## License

The repository carries two licenses by path; `NOTICE` names which path is under which.
The Lean semantics, the generated spec, the corpus and the pages that transcribe the reference are under the Open BSV License Version 5 (`LICENSE`).
The tooling (`tools/`, `harness/`, the `Makefile`) is under the Apache License 2.0 (`LICENSE-APACHE`).
A contribution is made under the license of the path it changes.
