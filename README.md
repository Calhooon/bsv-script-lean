# bsv-script-lean

The consensus rules of the bitcoin-sv node at release v1.2.3, for script, the transaction checks and the transaction state machine, written as a Lean 4 definition that runs.
Every rule cites the node's source at that release, by file and line.
A harness runs the same transactions through the definition and through SV-node, Teranode, bsv-rs, go-sdk, @bsv/sdk and GoBDK.
It reports each disagreement as a witness transaction, with the rule the transaction exercises.
This is not a node, a wallet or an application, and it does not prove the node correct.

![The bitcoin-sv source at v1.2.3, cited at its pin, is written as the Lean definition (lean/BsvScript, lean/BsvChain); the definition compiles to the evaluator eval/bsvs and carries the theorems; the harness runs the corpus through the evaluator and through SV-node, Teranode, bsv-rs, go-sdk, @bsv/sdk and GoBDK, and reports GREEN, or RED with a witness transaction.](docs/img/overview.svg)

## Try it

```sh
git clone https://github.com/Calhooon/bsv-script-lean && cd bsv-script-lean
VERIFY_LIGHT=1 make verify
```

The light run builds the libraries and the evaluator, runs the self-test and the smoke run, and prints the kernel witness and the axiom check as SKIPPED BY NAME; the full `make verify` is in "Verify the base" below.
A cold build fetches Mathlib's cache and compiles the project, so it takes longer than the warm wall that section quotes; the light build took 497 s on the maintainers' machine with Mathlib's cache already present (`docs/records/20261026-151123-readme-flip-s3.md` §3).
Its last line reads `verify: LIGHT, not GREEN`: that is the light run's own closing line, not a failure.
Then decide one spend from `corpus/flow` (entry `flow-01077`, a second `OP_ELSE` for one `OP_IF`) with the evaluator you built:

```sh
eval/bsvs eval --pretty \
  --tx 0200000001286516dd743c5f4f1c51f5c4e77346aee511095918f3564dc64c8ba07a5fa408000000000151ffffffff010100000000000000015100000000 \
  --prevouts '[{"txid":"08a45f7aa08b4cc64d56f318590911e5ae4673e7c4f5511c4f5f3c74dd166528","vout":0,"script":"63516751675168","satoshis":1000,"height":967896}]'
```

```text
{"verdict": "invalid",
 "spec": "spec@34139ebe",
 "reference": "bitcoin-sv v1.2.3 6504a3af (docs/PROVENANCE.md)",
 "message": "Invalid OP_IF construction",
 "gate": {"verdict": "valid"},
 "config": "sv-mainnet-default",
 "code": "SCRIPT_ERR_UNBALANCED_CONDITIONAL"}
```

Output trimmed to its verdict lines, quoted from the run in `docs/records/20261026-151123-readme-flip-s3.md` §3; your own output stamps `spec@<the commit of your clone>` in place of `spec@34139ebe` (the evaluator's header). `inputs[]` echoes the flag word and the limits the input ran under (`eval/README.md`, "eval: one spend"). The same spend is the finding shown in "A finding, shown" below.

## Start here

- **You build an implementation:** run the harness against it. Open [`harness/README.md`](harness/README.md).
- **You read formal definitions:** read the definition and what is proven about it. Open [`lean/README.md`](lean/README.md).
- **You work in the BSV ecosystem or the BSV Association:** read the claims, the findings and the obligation after release. Open [`docs/WRITE-UP.md`](docs/WRITE-UP.md).
- **You audit:** trace a claim to the run behind it. Open [`docs/HYPOTHESES.md`](docs/HYPOTHESES.md), [`docs/PROVENANCE.md`](docs/PROVENANCE.md) and [`docs/records/`](docs/records/).

[`docs/README.md`](docs/README.md) gives the full reading order.
[`docs/GLOSSARY.md`](docs/GLOSSARY.md) defines the words these pages use.

## What this is

This repository writes the machine down once, so that it can be executed, proven about, and used to check every implementation.
Consensus rules are the spec; policy limits are parameters; every rule cites the source it was read from at a pinned commit.
A policy limit enters as a named parameter with its default and its source.
The evaluator is the oracle, compiled from those definitions.
The corpus is the judge.

The searches recorded in `docs/WRITE-UP.md` §9 on 2026-10-06 found no public, executable, machine-checked semantics of BSV's post-Genesis script consensus run against the node as a conformance harness; that section lists the work it was checked against.

The harness calls @bsv/sdk by its engine name, `ts-sdk`.
`docs/HYPOTHESES.md` names the trust boundary, including the compiler and the harness.

## Verify the base

The toolchains are pinned in `docs/PROVENANCE.md` §1a: Lean `leanprover/lean4:v4.34.0` with Mathlib `5ed2965256430c3649e86755f9576b54eca72435`, Rust 1.95.0, Go 1.27 and Node 22.
Set up the implementations as [the harness prerequisites](harness/README.md#prerequisites) say.
`make help` (or `make` alone) lists every target of the Makefile by group.
Run this from the repository root:

```sh
make verify
```

`make verify` runs the Lean build, the axiom check, the evaluator self-test and the smoke run, in order (wall 30.30 s and peak 1.71 GB with a warm Lean build, `docs/records/20261021-150738-verify-pub-lean.md`; a cold build adds Mathlib's fetch and the whole project's compile).
On a cold build the heaviest step is the kernel witness the axiom check imports, the kernel-checked chain run (the `StaleRunCheck` library, built by step 1's `lake build` and by step 2): alone it took 229 s and 28.1 GB on the build host (`docs/records/20261014-061809-stale-cost-s1.md`).
On a machine with less memory, `VERIFY_LIGHT=1 make verify` builds the libraries without it (a cold `lake build BsvChain chaincheck` peaked at 2.68 GB, the same record) and prints the kernel witness and the axiom check as SKIPPED BY NAME, never as a pass.
The smoke step builds into `harness/target/`, so its executable is `harness/target/release/run_bsvrs`.

`make check`, the maintainers' full gate, runs the twenty-nine legs of `tools/check.sh` and writes a record under `docs/records/`.
The full check needs the TypeScript adapter installed in the checkout where it runs; `make tssdk-install` installs the pinned package with `npm ci`.
`make check` runs locally below a one-minute load of 20 (or on the build host itself) and on the build host above it; `MAKE_CHECK=modal` explicitly requests Modal (`tools/check_route.sh`).
The build-host route requires a clean, pushed commit and the host and lock setup in `tools/check_box.sh`.
A remote run returns its record and leaves its executables on that runner.

## Run the conformance harness

`harness/run --impl bsv-rs --corpus seed` runs one implementation against one corpus and writes the report.
The run writes new witnesses to its output directory, by default `harness/target/run/<UTC stamp>/`; `--out` selects another.
`harness/README.md` ("Run it", then "Prerequisites") is the manual: it says what each implementation needs and how to get it.

`bsv-rs`, `go-sdk` and `ts-sdk` need this repository, the common tools and the public package registries.
`gobdk` needs a clone of GoBDK.
`sv-node` needs a running regtest node of the pinned release.

The default run uses the specification's recorded verdicts.
`--spec live` runs the evaluator from your checkout.

A GREEN report means every divergence is explained.
An unexplained divergence makes the run RED.

## What you can build with it

- **Conformance CI for a node, an SDK or a wallet.** Give your implementation an adapter that speaks the line protocol of `harness/README.md` ("Bringing another implementation"), then run `harness/run --impl <yours> --corpus seed` in a pull request. A divergence arrives as a witness transaction, not as a bug report. `--impl` names the five implementations wired in today; a new one is a code change, not a list entry: an `EngineKind` variant in `harness/src/engines.rs`, its code table and `harness/rules/<name>.json` (`harness/README.md`, "Bringing another implementation").
- **Transactions tested under any policy configuration.** Every policy limit is a named parameter of the definition (`docs/PARAMETERS.md`); the evaluator judges a spend under a named configuration (`--config sv|teranode|sv-regtest`) and, with `--consensus true`, under the consensus word alone (`eval/README.md`), which is what a miner that relaxes its policy accepts; another set of limits is a change to the parameters, not a flag. The parameters say what the chain accepts and what a default node relays, never what a given miner will mine.
- **Script compilers and contract languages with a defined target.** Compile, then run the output through `eval/bsvs` and the node together before anything reaches mainnet.
- **Contract designs explored by a program.** A program proposes a script, `eval/bsvs` decides it with no node, the harness's mutators (`harness/src/gen.rs`) vary it, and every refusal comes back with the reference's `SCRIPT_ERR_*` code and message; `spec/errors.md` maps each code to the rule and its citation.
- **A contract's property proven as a theorem.** The semantics is a Lean definition, so "this output unlocks only under condition X" can be stated and proven over `verifyScript`, the same definition the harness checks against the node. The proof is about the specification, which earns its authority by agreeing with the node on the corpus; it does not prove the node.
- **Teranode and SV-node divergence tracking per release.** `spec/teranode-map.md` says per transaction-state-machine and node rule `same`, `different` or `absent`, with the citation at both pins; the column is a reading of the source, not a measurement.
- **Fuzzers and test generators derived from the definition.** The corpus generators (`harness/src/bin/*_cases.rs`) and the mutators (`harness/src/gen.rs`) are the starting point.
- **A parameters page for risk teams.** `docs/PARAMETERS.md` lists every value the interpreter reads, consensus or policy, with its default in the node, in Teranode and in bsv-rs, each cell cited at the version it was read at.

## Read a divergence

A divergence is read as a **finding** with a witness, never as a sentence.
The witness names the transaction, its previous outputs and their heights, the parameters, both verdicts, the rule and the citations at the pins.
`tools/witness.sh <witness-id>` replays a supported committed witness under `corpus/witnesses/`.
The command's header in `tools/witness.sh` says what to prepare: the built evaluator, the matching harness driver, the SDK adapters or the regtest instances.
An SV-node transaction witness needs `tools/witness.sh <witness-id> --restore-block` and the block instance's base snapshot.
`make witnesscheck` replays the policy-default witnesses.

A disagreement with SV-node is a spec bug until a human proves otherwise from source.
When the reference disagrees with itself, the spec records both readings with citations, and the maintainer rules which reading is consensus.

## A finding, shown

One committed witness, read from `corpus/witnesses/ts-sdk/flow.jsonl` and its row in `docs/CONFORMANCE-2026-09-27.md` §2:

| field | value |
|---|---|
| witness | `witness-ts-sdk-flow-default-spec-flow.else-flow-01077` (`tools/witness.sh <id>` replays it) |
| implementation | `ts-sdk-default@3.0.0`: @bsv/sdk 3.0.0 in its default mode (no `verifyFlags`) |
| rule | `flow.else`: "a second ELSE for one IF (post-Genesis: unbalanced)"; the locking script `63516751675168` is `OP_IF 1 OP_ELSE 1 OP_ELSE 1 OP_ENDIF` |
| verdicts | `spec@cb7e46e` and `sv-node@v1.2.3`: `invalid`, `SCRIPT_ERR_UNBALANCED_CONDITIONAL`; `ts-sdk-default@3.0.0`: `valid` |
| class | IMPLEMENTATION-WRONG, ruling `impl-wrong` |
| decided by | [SRC] bitcoin-sv v1.2.2 interpreter.cpp:829–831; conditional_tracker.cpp:51–55; @bsv/sdk 3.0.0 Spend.ts:1191–1202 (the single-ELSE test requires explicit flags and a post-Genesis coin; the default mode toggles again). The citation is the witness line's own, read at v1.2.2; those lines are unchanged at v1.2.3. |

## Evidence and claims

Records, claim tables and the provenance pages carry an evidence label on every number; a prose sentence names its record instead.
An issue written "archived #n", and a link to the issue tracker of the repository before 2026-10-23, names the private history and does not resolve for a reader of the public edition; `docs/GLOSSARY.md` defines the form.

| label | meaning |
|---|---|
| `[M]` | measured |
| `[X]` | executed |
| `[D]` | derived |
| `[EST]` | an estimate |
| `[LIT]` | cited |
| `[SRC]` | read from the reference source at its pin |

Claims about agreement are scoped to the pin and the corpus the harness has run.
A conformance claim names the implementation and build, the corpus, the mode, the pins and the run record.
These pages never use "consensus" and "policy" interchangeably.
`tools/wording_gate.sh README.md` checks this page's wording.

## Implementations under measurement

The pins in `docs/PROVENANCE.md` §1a identify the builds under measurement.
The records say which corpora and modes each run exercised.

| implementation | role | pin | label |
|---|---|---|---|
| bitcoin-sv (SV-node) | node of record | v1.2.3 · `6504a3aff65ba97c0f6c80962b033e35ecbfed4b` | [SRC] |
| bsv-rs | engine column | 0.7.0 · `5841f98c839859658c0661dd034722f63d545e2f` | [LIT] |
| go-sdk | SDK engine | v1.7.2 · `2ca481c5931b987a0c8f48bb341c70b7477b6b07` | [LIT] |
| ts-sdk | SDK engine, source in `bsv-blockchain/ts-stack` | @bsv/sdk 3.0.0 · `4d0ea63c85a836e3509291babb0d8e0c784b70a0` | [LIT] |
| GoBDK | Teranode's script library | `4eab3acdbbb971724f37e886e836daa1ed444a7f` | [LIT] |
| Teranode | node witness column | v0.16.0 · `4edb60a40c6628ff0ef60231c2628efd7103fde5` | [LIT] |

## Repository map

| dir | holds |
|---|---|
| `lean/` | the Lake project: the semantics, the properties, the evaluator's Lean side |
| `eval/` | the compiled evaluator CLI `bsvs` (from `lean/Bsvs/`) and its self-test; `eval/README.md` |
| `harness/` | generators, mutators, the runners, the divergence report |
| `corpus/` | synthetic corpora, recorded verdicts beside the spec's, and committed witness transactions (`corpus/witnesses/`) |
| `spec/` | the specification document generated from the Lean sources by `tools/specgen.py` (`make spec`; one page per opcode, the rules with their corpus counts, the theorems) |
| `docs/` | the design, the state, the provenance, the records, the history, audits |

These pages go deeper, in this order:

1. `NORTH-STAR.md`: the WHY, the constitution, the tuple, what DONE is.
2. `CLAUDE.md`: the working rules for a coding agent; a human reads `CONTRIBUTING.md`.
3. `docs/DESIGN.md`: the machine model, the parameters model, the trust boundary, the CLI and corpus formats.
   `docs/DESIGN-S6.md` holds the transaction state machine, the `lean/BsvChain` module map and the oracle plan; `docs/BLOCK-CONSENSUS.md` holds the block-consensus boundary.
4. `docs/STATE-OF-THE-WORLD.md`: what stands per milestone, each count with its record.
5. `docs/PROVENANCE.md`: the reference pins, what crosses from the predecessors, what never enters.
6. `docs/history/`: the specification's historical pages, collected here on 2026-10-12 with every cut marked in place; its index records the inventory.
7. `docs/WRITE-UP.md`: the write-up for a stranger (archived #33): what is proven, what is assumed, what is not claimed, the errata of the reference, the prior art, the license ruling, how to report a divergence.
8. [`docs/LINT.md`](docs/LINT.md): the twenty-nine gate legs, the hooks, the measured static-analysis bar, the dated gaps and the recorded walls.

## The standard

The standard this repository and `bsv-stack-lean` share, the six tests in the table below, sets the method's goal: the machine is the only hand-written artifact, and tests, coverage, fuzzers, documentation and incident scenarios are to be derived from it (`docs/DESIGN-S6.md` §8 applies it).

This repository answers T2, T4, T5 and T6 through its proof and replay requirements; T1 and T3 bind `bsv-stack-lean`'s application services, whose costs follow their own use and whose read model keeps headers and checks transactions with merkle paths.

| test [LIT] | question [LIT] |
|---|---|
| T1 · scale | "Does the cost grow with our use and never with the chain?" |
| T2 · verify | "Can the reader check every chain fact we serve with headers and a proof?" |
| T3 · fast and cheap | "Push over poll, edge over origin, one hop over two, no scan ever?" |
| T4 · law | "Is the rule in script or in math, not in an operator's or an indexer's discretion?" |
| T5 · trust | "Does it reduce the words we take on trust?" |
| T6 · executable | "Is it a Lean statement and a replayed scenario, not a paragraph?" |

The standard holds that headers and proofs are the only evidence for chain facts, and that status words are hints.

## Two repositories, one door

The sibling `bsv-stack-lean` refines its application machines against this specification at a pin.
This repository is the node's half.
The agreed public door is one conformance board with one reading order; on this side its pages are the conformance reports that [`docs/README.md`](docs/README.md) indexes.
The board reads this specification's records by path at a pin.

## The public edition

This is the public edition, cut by `make export-public` and judged by `make export-gate` (archived #46): the withheld list, then the private-vocabulary check, the pointer check and the wording check over the export; it is not a tripwire leg (`docs/PROVENANCE.md` §4).
The announcement, a sentence and a five-line forum post, is `docs/ANNOUNCEMENT.md` (archived #34).
An issue number written "archived #n" is the issue tracker's before 2026-10-23, archived with the private repository (`docs/GLOSSARY.md`).

## What stands

| item | state | label | record |
|---|---|---|---|
| the tag of record | `v1.1.1` (`a478bf56`, 2026-10-18; its `lean/` tree `baa6cddada31fe27f959efe7b50e9ef1d70dfb6e`; commits of the private history, the record names them), until the public edition | [M] | `docs/records/20261018-133547-make-check-box.txt` |
| the tag's tripwire | the tag's commit adds only the record of its parent `049274d2` (also of the private history): the box tripwire GREEN on the twenty-nine legs of `tools/check.sh` at that commit, the Lean build sorry-free, the axiom check OK over 1896 listed theorems (the walk: 8634 theorems in 115 modules, 0 axioms outside the three of `lean/AXIOMS-ALLOWED`) | [X] | `docs/records/20261018-133547-make-check-box.txt` |
| the edition `bsv-stack-lean` pins | `v1.1.0` (`0b94c027`, 2026-10-06); `v1.1.1` carries the transaction state machine for its move (bsv-stack-lean #127) | [LIT] | the tags |
| the pin | bitcoin-sv v1.2.3 · `6504a3aff65ba97c0f6c80962b033e35ecbfed4b` | [SRC] | `docs/PROVENANCE.md` §1 |
| the executable base | script, the transaction checks around it and, since S6 (closed on the archived tracker 2026-10-17), the transaction state machine: the UTXO set, the mempool as policy parameters, block validity, the chain with undo and most-work selection, merkle inclusion and the derived status function, judged by the pinned node per scenario row (`chaincheck scenarios`: 29 declared steps agree) | [X] | `docs/records/20261018-133547-make-check-box.txt` |
| the milestones beyond S6 | the node beyond the chain (S7, archived #78 to #86) and the producers (S10, archived #145 to #152) closed on the archived tracker; Teranode as a refinement (S8), the year held (S9) and the public reader (P) carry their open issues to the public tracker | [X] | `docs/records/20261021-150853-public-tracker-dryrun-pub-tracker.md` |
| the public tracker | opens with 3 milestones (S8, S9 and P) and 24 issues, numbered from 1 (6 in S8, 9 in S9, 9 in P), as the dry run of 2026-10-21 staged them; the earlier tracker is archived with the private repository | [X] | `docs/records/20261021-150853-public-tracker-dryrun-pub-tracker.md` |

| milestone [LIT] | deliverable [LIT] |
|---|---|
| S0 · Birth | Memory, reference pins, Lake project, tripwire, design and the consensus-versus-policy census |
| S1 · The core semantics | Numbers, encodings, the script machine, opcode families, signatures, sighash, flags, evaluator, opening properties and generated spec |
| S2 · The full consensus | Remaining opcodes and their history, the version-1 branch, activation parameters, transaction checks, P2SH and full-corpus properties |
| S3 · The conformance harness | Generators, mutators, implementation runners, a cited witness report and one-command use |
| S4 · Review and release | The three-lens review, hypotheses, write-up and the maintainer's publication ruling |
| S5 · Beyond the script verdict | The block-consensus boundary and candidates for a second formalization |
| S6 · The transaction state machine | The UTXO set, mempool and header tree, with inclusion as a theorem over the machine under the maintainer's S6-1 ruling of 2026-10-12 |
| S7 · The node beyond the chain | P2P and relay, persistence, pruning, event and RPC observations, and client wire formats |
| S8 · Teranode as a refinement of the reference | The module map, refinement obligations, absence ledger and per-release divergence report |
| S9 · The year held: columns per release, the loop, the board | Columns per release, the intake loop and the conformance board for the year after the public edition opens |
| S10 · The producers | Every library that builds BSV transactions measured against the pinned node as a signer, per release, with fixtures in its own format and the signer properties as theorems |
| P · The public reader | The public edition read by a stranger: the four doors, the entry pages re-cut, the process vocabulary defined or removed, the contributor pages and the public tracker |
| Someday | Compiler verification hooks and further confidence work |

Each issue must name the why, the deliverable, the done-bar with its evidence label, the dependencies and the source.
Work goes in milestone order; an issue without a done-bar is a draft.

## License

This repository carries two licenses by path, and `NOTICE` names which path is under which.
The Lean semantics, the generated spec, the corpus and the pages that transcribe the bitcoin-sv reference at the pinned commit (`6504a3a`, v1.2.3; `879fc8b` before 2026-10-06) are under the Open BSV License Version 5 (`LICENSE`), as material derived from that reference, with its condition of use on the BSV blockchains.
The separable tooling (`tools/`, `harness/`, the `Makefile`) is under the Apache License 2.0 (`LICENSE-APACHE`), except the parts `NOTICE` part 3 names as copied from a third party, which keep their source's license.

Contact: John Calhoun · [github.com/Calhooon](https://github.com/Calhooon)

Reports: a divergence goes to the public repository's issue tracker; a security concern goes privately through its private vulnerability reporting form (the "Report a vulnerability" button under the Security tab), never the tracker (`docs/WRITE-UP.md` §11).
