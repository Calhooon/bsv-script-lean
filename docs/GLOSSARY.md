# Glossary

These pages use a small set of words in a fixed sense.
This page defines each one in a paragraph and names the page where it matters most.
The terms run in alphabetical order; the evidence labels close the page.

**archived #n.** An issue number of the issue tracker before 2026-10-23, written "archived #58", for example.
That tracker is archived with the private repository; its numbers are kept in the records and the history pages.
At the public birth its links on the pages were replaced by this text, since they do not resolve outside the archive.
The public tracker numbers its issues from 1, and a bare `#n` on GitHub links there, not to the archive.
Where it matters: `README.md`, "What stands".

**axiom-clean.** The Lean build carries no `sorry` (an unproven step), and `#print axioms` on every listed theorem shows only Lean's three axioms: `propext`, `Classical.choice` and `Quot.sound` (`lean/AXIOMS-ALLOWED`).
`tools/axiom_check.py` runs the check over the theorems `lean/AxiomCheck.lean` lists, as one leg of the tripwire.
Where it matters: `docs/WRITE-UP.md` §2.

**block word, relay word.** The two flag words the harness judges a spend under.
The block word is the one the node applies when it connects a block (consensus); the relay word is the one its mempool applies (policy).
The node's two columns carry them: `spec` for the block word, `spec-mempool` for the relay word.
Where it matters: `docs/WRITE-UP.md` §5, item 6.

**the box.** The build host that runs the full check when the workstation's load is high; `tools/check_box.sh` drives it, and its records are named `*-make-check-box.txt`.
A run can also go to a Modal cloud container on request (`MAKE_CHECK=modal`, `tools/modal_check.py`); every route writes the same record.
Where it matters: `README.md`, "Verify the base".

**class, classifier.** A class names one explained kind of divergence, with the citation that decides it and its ruling.
The classifier is data, not code: the tables under `harness/rules/` assign each divergence its class.
A divergence that no class explains turns the run RED.
Where it matters: `docs/CONFORMANCE-2026-09-27.md`, its head.

**column.** One implementation's recorded verdicts over the corpora at one release.
`make column IMPL=<implementation> PIN=<release>` re-records a column at a new release, or re-runs it as a dry run at the current pin and compares it with the committed one.
Where it matters: `harness/README.md`, "One implementation's column per release".

**consensus, policy.** A consensus rule decides validity for every node.
A policy limit is one node's setting, such as a mempool cap.
The spec states consensus rules as rules and takes policy values only as named parameters, each with its default and its source; these pages never use one word for the other.
The theorem `derive_consensus_separation` states that the block word depends only on the consensus fields of a node's configuration.
Where it matters: `docs/PARAMETERS.md`.

**conformance board.** One page that shows each implementation's columns against the specification, release by release, read from this repository's records at a pin.
It is a deliverable of the milestone "the year held".
Where it matters: `README.md`, "Two repositories, one door".

**constitution.** The five numbered rules of `NORTH-STAR.md` §2, 01 to 05: consensus rules are the spec and policy limits are parameters; every rule cites the reference at a pin; the semantics is executable; a disagreement is a witness transaction; nothing from a non-public project enters this repository.
`CONTRIBUTING.md` turns them into the rules a change keeps.
Where it matters: `NORTH-STAR.md` §2.

**corpus.** A set of entries, each a spend or a transaction with its previous outputs, its parameters and the verdict every implementation recorded beside the spec's.
Seeded generators write the corpora; `corpus/INDEX.md` §1 lists each generator with its seed.
The corpus is the judge: the spec is wrong until the corpus agrees with the reference.
Where it matters: `corpus/INDEX.md`.

**divergence.** A corpus entry on which two verdicts differ: the spec's and an implementation's, or the reference's and the spec's.
The harness reports each one as a witness and the classifier gives it a class.
Where it matters: `README.md`, "Read a divergence".

**divergence kinds.** The conformance report sorts classes into four kinds.
IMPLEMENTATION-WRONG: the reference and the spec agree and the implementation differs.
SPEC-SIDE: the reference disagrees with the spec, which is a spec bug until a human proves otherwise from source.
OPEN: a class ruled open (a mode or a node's policy setting, never a consensus divergence) or not yet ruled.
MECHANISM: an engine abort, timeout or decode refusal, filed as a witness and never counted as agreement.
Where it matters: `docs/CONFORMANCE-2026-09-27.md`, its head.

**engine, engine column.** An engine is a library's script interpreter that the harness runs as one implementation: bsv-rs, go-sdk, ts-sdk (the harness's name for @bsv/sdk) and GoBDK; `harness/engines/` holds their adapters.
The engine column is bsv-rs's column: the Rust engine the harness links directly, whose verdicts every corpus records beside the spec's.
Where it matters: `harness/README.md`.

**era.** The activation branch a height falls in: before Genesis, Genesis, or Chronicle.
The era of the spending block sets the flag word; the era of the spent coin, read from its creation height, adds the coin's markers.
`docs/PARAMETERS.md` gives each network's activation heights.
Where it matters: `docs/DESIGN.md` §5.

**errata.** The places where the reference disagrees with itself or with its own documentation.
The spec records both readings with their citations, and the maintainer rules which reading is consensus.
Where it matters: `docs/WRITE-UP.md` §8.

**evaluator.** `eval/bsvs`, the Lean definitions compiled into a command-line tool.
It decides a spend from a transaction and its previous outputs, and it stamps each verdict with the commit of its sources.
`eval/bsvs --self-test` checks the build.
Where it matters: `eval/README.md`.

**export, withheld.** `make export-public` copies this repository into the public edition, leaving out a withheld class of files; `make export-gate` then judges the copy.
A public page that refers to withheld material says so and names its group, as `docs/WRITE-UP.md` §4, item 8, does.
Where it matters: `docs/PROVENANCE.md` §4.

**family.** A group of opcodes the semantics treats together, such as the arithmetic, stack, byte, flow and signature opcodes; the corpora `corpus/arith`, `corpus/stack`, `corpus/bytes`, `corpus/flow` and `corpus/crypto` carry their names.
The chain scenarios and the signer fixtures group their rows into families the same way (`corpus/chain/<family>/`).
Where it matters: `docs/DESIGN.md` §3.

**finding.** A divergence written up with its witness transaction, the rule it exercises and the citation that decides it; a finding is never a sentence alone.
A disagreement between SV-node and another implementation becomes a finding with a witness.
Where it matters: `docs/WRITE-UP.md` §7.

**flag word.** The set of verification flags the script interpreter reads.
The node computes it outside the interpreter, from the height, the era and the node's settings, and adds per-input markers from the spent coin's era.
Where it matters: `docs/DESIGN.md` §5.2.

**gate.** A check that refuses.
The wording gate (`tools/wording_gate.sh`) refuses forbidden wording on the public pages; the export gate refuses a public edition that leaks withheld material.
The version gate is a rule of the node itself: after Chronicle, a transaction version above 1 switches seven restrictions off (see version-1, version-2).
The transaction gate is the evaluator's check of the transaction's own validity before its scripts run.
Where it matters: `docs/LINT.md`.

**GREEN, RED.** The two verdicts of a leg, a run or a report.
A report is GREEN when the classifier explains every divergence; one unexplained divergence makes it RED.
The tripwire is GREEN only when every leg is GREEN.
Where it matters: `README.md`, "Run the conformance harness".

**kernel sample.** Twenty-five fixed vectors that the Lean kernel decides on the definitions, with no compiled code involved (`lean/BsvScript/Properties/KernelSample.lean`); the compiled evaluator runs the same list and fails on any disagreement.
It is evidence about the compiler at those points, not a proof of it.
Where it matters: `docs/WRITE-UP.md` §3.

**leg.** One check of the tripwire.
The header of `tools/check.sh` lists the twenty-nine legs, and `docs/LINT.md` describes them.
Where it matters: `docs/LINT.md`.

**lens.** A review that reads the tree through one named concern and reports what it finds.
The review milestone (S4) read the tree through three: the trust boundary, the properties and the harness.
Where it matters: `docs/HYPOTHESES.md`.

**loop.** Witness rows taken upstream: each divergence the harness finds goes, as a witness row, to the maintainers of the implementation it concerns, and their acknowledgement is recorded, repeated as new rows are found.
It is a deliverable of the milestone "the year held".
Where it matters: `docs/STATE-OF-THE-WORLD.md` §2.

**manifest.** A file per corpus and engine that lists each entry's verdicts and its classified divergences.
The harness leg of the tripwire replays every manifest and fails when one no longer matches.
Where it matters: `harness/README.md`.

**milestone (S0 to S10, P).** A milestone on the issue tracker, named S0 to S10, plus P (the public reader) and Someday.
S8, S9 and P carry their open issues to the public tracker; the others are on the archived tracker (see archived #n).
`README.md`, "What stands", lists each with its deliverable.

**oracle.** The word has two uses here.
The evaluator is the spec's oracle: the harness compares every implementation with its verdicts.
The node oracle is the spec's own instance of the pinned node, on a private chain or regtest (`harness/oracle/`); it runs once with every policy cap zeroed (the `spec` column) and once at the node's default policy (the `spec-mempool` column).
Where it matters: `harness/README.md`.

**overlay.** In the BSV ecosystem, a service that tracks an application's transactions and admits them on proof.
`spec/node-client-contract.md` lists the overlay among the clients a node serves and says which node surfaces it may rely on.
Where it matters: `spec/node-client-contract.md`, section 4.

**parameter.** A named input of the semantics: a policy value or a network value, with its default and its source.
`docs/PARAMETERS.md` lists every value the interpreter reads with its kind and its default in the reference and in Teranode.
`Params.derive` builds the evaluation parameters from a node's configuration, the heights and the consensus switch.
Where it matters: `docs/PARAMETERS.md`.

**pin.** The exact release and commit of an upstream that a claim speaks about.
`docs/PROVENANCE.md` §1a records every pin once, and the check-pins leg refuses any site that disagrees with it.
Every claim is scoped to its pin and its corpus.
Where it matters: `docs/PROVENANCE.md`.

**predecessors.** Two earlier, non-public projects of the maintainers, a harness and a Lean research tree, whose code patterns this repository copied at pinned commits.
Each copied file carries a provenance header, and a check confirms that no project-specific material crossed with it.
Where it matters: `docs/PROVENANCE.md` §1 and §4.

**recon.** The monthly read of every pinned upstream's releases at its source.
Each entry in `docs/recon.md` records what moved, whether it touches consensus or a policy default, and whether a pin must move; a consensus change opens an issue the week it lands.
Where it matters: `docs/WRITE-UP.md` §12.

**record.** A file under `docs/records/` that a run writes: the commit it measured, the command, the verdict lines.
Every count a page quotes names its record.
Where it matters: `docs/records/`.

**the reference.** The bitcoin-sv node (SV-node) at release v1.2.3, commit `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: the node of record whose source every rule cites.
The reference can be wrong too (see errata).
Where it matters: `docs/PROVENANCE.md` §1.

**refinement (Teranode's).** The statement that Teranode's machines implement the reference's state machine.
The work maps Teranode's modules to the state machine, states the refinement obligations in `lean/BsvChain/Teranode/Refinement.lean`, keeps a ledger of what Teranode lacks, and reports the divergences per release.
Where it matters: `docs/CONFORMANCE-TERANODE-MACHINE.md`.

**road.** The block road: the harness funds a corpus entry's transaction, submits it in a block on a private chain to the node's block instance, and sends it to the policy instance's mempool, so the node derives the flag word itself.
`corpus/road` and `corpus/tx` run this way.
Where it matters: `docs/STATE-OF-THE-WORLD.md` §3.

**scenario.** A list of declared steps over the transaction state machine, such as blocks, spends, reorganisations and mempool events, stored under `corpus/chain/<family>/`.
`chaincheck scenarios` runs each step in the spec, the harness runs the same steps against the pinned node, and the two are compared row by row.
Where it matters: `harness/README.md`, "Chain-layer node runner".

**script verdict.** The node's per-input call, `VerifyScript`, decided from the unlocking script, the spent output's locking script, the flag word and the transaction with its spent amount.
A script verdict is not the transaction's validity.
Where it matters: `docs/WRITE-UP.md` §1.

**state machine.** The transaction state machine, `lean/BsvChain`: the UTXO set, the mempool as policy parameters, block validity, the chain with undo and most-work selection, merkle inclusion and the derived status function.
Where it matters: `docs/DESIGN-S6.md`.

**tripwire.** `make check`: the full check of the twenty-nine legs.
It writes a record naming the commit, each leg's verdict line, the wall time and the load.
Where it matters: `README.md`, "Verify the base".

**tuple.** The six properties of `NORTH-STAR.md` §3, held together: completeness, fidelity, executability, machine-checked properties, usability and maintainability.
Where it matters: `NORTH-STAR.md` §3.

**version-1, version-2.** After Chronicle, a spend whose transaction version is above 1 (a version-2 spend) runs with seven restrictions off: LOW_S, MINIMALDATA, MINIMALIF, NULLFAIL, NULLDUMMY, CLEANSTACK and SIGPUSHONLY.
A version-1 spend keeps the flag word's own settings; before Chronicle every version keeps them.
The theorem `gate_noninterference` states the version-2 half.
Where it matters: `docs/DESIGN.md` §5.3.

**witness.** The smallest transaction that exhibits a divergence, with its previous outputs and their heights, the parameters, both verdicts, the rule it exercises and the citations at the pins.
Committed witnesses live under `corpus/witnesses/`, and `tools/witness.sh <witness-id>` replays one.
Where it matters: `README.md`, "Read a divergence".

## The evidence labels

Records, claim tables and the provenance pages label every number; a prose sentence names its record instead.

| label | meaning |
|---|---|
| `[M]` | measured by a tool |
| `[X]` | executed, with the run recorded |
| `[D]` | derived from other figures |
| `[EST]` | an estimate |
| `[LIT]` | cited: a name or a quoted word |
| `[SRC]` | read from the reference source at its pin |
