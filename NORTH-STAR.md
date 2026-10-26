# NORTH STAR: bsv-script-lean

**Born 2026-09-21; the public edition since 2026-10-26 (re-stamped 2026-10-12, archived #58: constitution 01 extended to the transaction state machine).** The permanent WHY and the standard every decision
here is measured against. Numbers live on the state page; this file carries
pointers and rulings.

## 1. The sentence

**We are writing BSV script consensus down once, as an executable, machine-
checked definition, and building the harness that checks every implementation
against it with witnesses.** Today the rule is whatever SV-node's C++ does.
After this, the rule is a Lean definition that runs, that has theorems, that
every node, wallet and compiler can be tested against, and that reports a
disagreement as a 200-byte transaction and the rule it exercises. The same harness
measures the producers beside the validators: every library that builds
transactions on BSV is asked, per release and over every signing path it
exposes, whether what it signs passes the pinned node (S10, archived #150).
The spec is the referee of the migration off SV-node, not only the conformance
reference: both nodes are judged against the definition at every release, and the
day SV-node leaves, the spec at SV-node's last pin stands frozen as the record (the
maintainers' ruling, 2026-10-18).

## 2. The constitution

> **01** Consensus rules are the spec; policy limits are parameters. The line
> between them is written down with citations, at the script layer and, since archived #58
> (2026-10-07), through the transaction state machine the script verdict lives in
> (`docs/DESIGN-S6.md`), where the mempool is parameters almost entirely.
> **02** Every rule cites the reference source at a pin. Memory is not a source.
> **03** The semantics is executable, and the evaluator is the oracle.
> **04** A disagreement is a witness transaction, never a sentence.
> **05** Nothing of the private programs enters this repository.

**The permanent no-list:** a rule without a citation · a policy limit written
as consensus · a "conformance" claim without a run · a corpus containing a
private program's transaction · a `sorry` on `main` · the word "first".

## 3. The tuple: six properties, together

| # | property | what "met" means |
|---|---|---|
| 1 | **completeness** | every opcode, both flag branches, the activation rules, the sighash variants, defined |
| 2 | **fidelity** | zero unexplained divergences from SV-node on the full corpus; every divergence with any other implementation reported with a witness |
| 3 | **executability** | the evaluator decides any spend from the transaction and its previous outputs, deterministically |
| 4 | **machine-checked properties** | determinism, termination under the parameters, encoding canonicality, the parameter separation, sorry-free |
| 5 | **usability** | one command runs the harness against a named implementation; the spec document is generated from the sources |
| 6 | **maintainability** | every consensus change is mirrored in the spec the week it lands in the nodes, with its citation |

## 4. Why it is big (the argument, kept short)

The chain is entering a multi-implementation world with no shared spec and no
shared conformance suite. Ethereum runs several clients without splitting
because they execute the same executable specification and the same test
vectors; BSV has neither. BSV script is unusually powerful, so the exact
behaviour of the interpreter is the security of every on-chain program, and a
half-megabyte verifier cannot be hand-audited against C++. Once the semantics
exists, compilers can be verified against it and their scripts can be translation-
validated, so a contract ships with a theorem. And it is the one artifact of
this work that discloses nothing and helps everyone.

## 5. What DONE is

v1.0 = S4: the full consensus semantics, the properties proven, the evaluator,
the harness run against SV-node, Teranode and bsv-rs with the divergence
report, the generated spec document, the hypotheses page, the three-lens
review (no external reviewer: the public is the audit after v1.0; the maintainers,
2026-09-23), and the maintainers' publication ruling. Not in the output: a claim of
"first"; a policy specification; any contract of ours; any transaction of ours.

## 6. What is not removable, only stated

The reference is a program, and a program can be wrong or ambiguous; the spec
records both readings when it finds one and the maintainers rule. Signature
verification (secp256k1 ECDSA) is an executable Lean definition transcribed
from the reference's libsecp256k1 at the pin, with no axiom (Q9 ruled (A) on
archived #38, 2026-09-22; `docs/HYPOTHESES.md`); what is trusted is the transcription,
and that boundary is named on every page that touches it. Consensus is what miners run: if this spec and SV-node
disagree, the chain follows SV-node until the humans decide, and the spec's
authority is earned by conformance runs, not declared.

## 7. Rulings

2026-09-21 (birth): private at birth · the calendar re-dated on measured
velocity, never on a claim · public on the maintainers' ruling (the public
edition since 2026-10-26).

2026-10-07 (archived #58): the maintainers chartered S6, the transaction state machine (the UTXO
set, the mempool, the header tree), as the bar after v1.0: `docs/DESIGN-S6.md`,
executable and cited at the pin, judged by scenario witnesses against SV-node
regtest with Teranode the second oracle; the constitution's pages amended in
place (its §7).

*Update rule: delete the sentence you falsify, re-stamp the date, never a banner
over a wrong line.*

## 8. The star in one paragraph (2026-10-14)

Write the node's rules down once as a Lean definition that runs, cite every rule at a pin, and let the corpus judge: a disagreement with the node of record is a spec bug until a human proves otherwise from source, and a disagreement between two implementations is a witness transaction, never a sentence. Then open it, so that every wallet, service and contract on BSV believes what the node believes, by proof and by measurement, and a new implementation is measured as a column the week it ships. The dated goals of 2026-10-14: by 2026-10-15 the publication date given and the go-sdk report filed; by 2026-10-19 the export gate clean on the public edition's tree, the consumer contract told to the downstream users, the intake loop named with the node team; by 2026-11-12 the public edition on its date (born with a fresh history, the private repository archived), S6 closed behind the tripwire, a stranger's PR through the public gate, the next Teranode release measured the week it lands; by 2027-10-12 every implementation a column per release, the witnesses upstream as a loop, the two Leans one workspace, Teranode proven as a refinement, a year of releases mirrored within seven days, an application program of the sibling application half, bsv-stack-lean, proven against the spec, one conformance board with the Association's badge. Every goal is an issue in a dated milestone (2026-10-14); the reader marks it from GitHub.

S8, S9 and P carry their open issues to the public tracker (`docs/STATE-OF-THE-WORLD.md`).
