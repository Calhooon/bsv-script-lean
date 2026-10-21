# State of the world: what stands, and the record that proves it

This page says where the specification stands today, one milestone at a time.
Each count on it names the record under `docs/records/` that holds it.
A term this page does not define is in the [glossary](GLOSSARY.md).
The page was re-cut on 2026-10-21.

## 1. The pin, the tag and the tripwire

| item | value | read from |
|---|---|---|
| the reference | bitcoin-sv (SV-node) v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b` (`6504a3a`); `879fc8b` (v1.2.2) before 2026-10-06 | [`NOTICE`](../NOTICE), [`README.md`](../README.md), [`docs/PROVENANCE.md`](PROVENANCE.md) §1a |
| the tag of record | `v1.1.1` at `a478bf56` (2026-10-18; a commit of the private history), until the public edition opens | [`README.md`](../README.md) |
| the tripwire of record | the full check GREEN on all twenty-nine legs at the tag's parent `049274d2` (also of the private history): the Lean build sorry-free, the axiom check OK over 1896 listed theorems (8634 theorems in 115 modules, no axiom beyond the three of `lean/AXIOMS-ALLOWED`) | [`docs/records/20261018-133547-make-check-box.txt`](records/20261018-133547-make-check-box.txt) |

The tripwire is `make check`: the Lean build, the axiom check, and every replay and harness leg that `tools/check.sh` lists.
Each run writes its record under `docs/records/`.

## 2. The milestones

Each milestone below carries its tracker title and what stands in it; an issue number of the tracker before 2026-10-23 is written "archived #n" ([glossary](GLOSSARY.md)).
Four milestones are open: review and release, Teranode as a refinement, the year held, and the public reader.
The last three carry their open issues to the public tracker, which opens with 3 milestones and 24 issues ([`docs/records/20261021-150853-public-tracker-dryrun-pub-tracker.md`](records/20261021-150853-public-tracker-dryrun-pub-tracker.md)); every other milestone is closed on the archived tracker.

### S0 · Birth

The reference is pinned, the Lake project builds, and the census of every parameter the semantics reads stands with its kind (consensus or policy) and its default ([`docs/PARAMETERS.md`](PARAMETERS.md)).
The tripwire's parameter and pin legs check both at every run ([`docs/records/20261018-133547-make-check-box.txt`](records/20261018-133547-make-check-box.txt)).

### S1 · The core semantics

The script machine, the opcode families, the number and byte encodings, signatures, sighash, the flag model and the evaluator `eval/bsvs` are Lean definitions, and the generated specification under `spec/` is built from them.
On the seed corpus the evaluator agrees with bsv-rs's recorded verdicts on 10,000 of 10,000 entries ([`docs/records/20261018-133547-make-check-box.txt`](records/20261018-133547-make-check-box.txt)).

### S2 · The full consensus

The remaining opcodes, the version-1 branch, the activation heights as parameters, the transaction checks and the history of P2SH are defined and proved.
Against bsv-rs on the full corpus, the specification agrees on 13,184 of 13,257 entries in both flag words; the other 73 are not applicable to it, and no divergence is unexplained ([`docs/records/20260928-121537-diff24-full-corpus-s3.md`](records/20260928-121537-diff24-full-corpus-s3.md)).

### S3 · The conformance harness

Generators, mutators and one runner per implementation measure each corpus against the pinned node.
The conformance report's 124 cited witnesses replayed GREEN at its cut ([`docs/records/20260927-023153-witness-replay-s3.md`](records/20260927-023153-witness-replay-s3.md)), and the tripwire replays every recorded manifest at each run ([`docs/records/20261018-133547-make-check-box.txt`](records/20261018-133547-make-check-box.txt)).

### S4 · Review and release (open)

The write-up stands at [`docs/WRITE-UP.md`](WRITE-UP.md), and the tag of record is `v1.1.1` ([`README.md`](../README.md)).
The milestone stays open until the public edition opens.

### S5 · Beyond the script verdict

[`docs/BLOCK-CONSENSUS.md`](BLOCK-CONSENSUS.md) draws the line where the script verdict ends and block-level consensus begins, and [`docs/SECOND-FORMALIZATION.md`](SECOND-FORMALIZATION.md) names the trusted items and the candidates for a second check.
A clean-room evaluator, written from the generated pages alone, made 45,059 comparisons with the recorded verdicts ([`docs/records/20261015-133842-s5-37-cleanroom-s3.md`](records/20261015-133842-s5-37-cleanroom-s3.md)).

### S6 · The transaction state machine

The UTXO set, the mempool with its policy parameters, block validity, the chain with undo and most-work selection, merkle inclusion and the derived status function are Lean definitions.
The pinned node judges them per scenario row: the 29 declared scenario steps agree, as do 80 UTXO rows, 115 mempool rows, 114 finality rows and 95 block-boundary rows ([`docs/records/20261018-133547-make-check-box.txt`](records/20261018-133547-make-check-box.txt)).

### S7 · The node beyond the chain

P2P framing and relay, compact blocks, double-spend notifications, mempool persistence, pruning, the RPC observation contract and the client wire formats are modeled, each with its own page or record.
The client wire formats (EF, BUMP, BEEF, Atomic BEEF and the TSC proof) carry 62 theorems ([`docs/records/20261015-110609-s7-86-wire-views-s1.md`](records/20261015-110609-s7-86-wire-views-s1.md)); the RPC contract's 51 handlers are checked at every tripwire run ([`docs/records/20261018-133547-make-check-box.txt`](records/20261018-133547-make-check-box.txt)).

### S8 · Teranode as a refinement of the reference (open)

A module map of 54 rows ties Teranode v0.16.0 to the reference function by function, one refinement obligation each ([`docs/records/20261018-133547-make-check-box.txt`](records/20261018-133547-make-check-box.txt), the refinement leg; [`docs/records/20261017-215012-s8-88-close-s1.md`](records/20261017-215012-s8-88-close-s1.md)).
Teranode's scenario column has 478 rows: 126 measured (102 agree, 4 diverge, and 20 observed but counted as neither agreement nor divergence, because the outcome depends on the node's validation clock), 10 where the runner reached no verdict, 1 that the node's RPC call refused before validation, and 341 that this Teranode instance cannot set up, each with its reason in the record ([`docs/records/20261015-170946-s6-66-cut2q5-column-s3.md`](records/20261015-170946-s6-66-cut2q5-column-s3.md)).
The per-release divergence gate's newest report is [`docs/records/20261017-231954-s8-95-gate-report-s3.md`](records/20261017-231954-s8-95-gate-report-s3.md).

### S9 · The year held: columns per release, the loop, the board (open)

One command re-records an implementation's column at a new release (`make column IMPL=<impl> PIN=<release>`).
At bsv-rs 0.7.0 it re-recorded 27 corpora, 276,079 entries, with no row moved ([`docs/records/20261017-015602-column-bsv-rs-0.7.0-s3.md`](records/20261017-015602-column-bsv-rs-0.7.0-s3.md)).
The loop (witness rows taken upstream to each implementation's maintainers) and the conformance board are the milestone's open deliverables ([glossary](GLOSSARY.md)).

### S10 · The producers

A signable corpus of 241 unsigned spends is signed by each SDK and judged by a fresh pinned regtest node.
The signer column judged 241 rows per engine for go-sdk v1.7.2 and @bsv/sdk 3.0.0, with every disagreement under a cited class ([`docs/records/20261016-203024-s3-145d-signer-column-s3.md`](records/20261016-203024-s3-145d-signer-column-s3.md); [`docs/records/20261017-020326-s3-147-signer-column-s3.md`](records/20261017-020326-s3-147-signer-column-s3.md)).

### P · The public reader (open)

The public edition is read by a stranger through four doors: the implementer, the formalist, the ecosystem and the auditor ([`docs/README.md`](README.md)).
The entry pages are re-cut, the contributor pages stand (`CONTRIBUTING.md`, `SECURITY.md`, the divergence template), and the public tracker's filing is staged ([`docs/records/20261021-150853-public-tracker-dryrun-pub-tracker.md`](records/20261021-150853-public-tracker-dryrun-pub-tracker.md)).
The process-vocabulary and prose-label counts of the entry pages, before and after the re-cut, are in [`docs/records/20261021-153647-public-reader-counts-fix-lens-pub.md`](records/20261021-153647-public-reader-counts-fix-lens-pub.md).
`make verify` ran GREEN with a warm Lean build ([`docs/records/20261021-150738-verify-pub-lean.md`](records/20261021-150738-verify-pub-lean.md)); a cold build of the public tree is not yet recorded.

## 3. The implementations measured

The pins are those of [`docs/PROVENANCE.md`](PROVENANCE.md) §1a, as [`README.md`](../README.md) lists them.

| implementation | pin | newest report page |
|---|---|---|
| bitcoin-sv (SV-node), the node of record | v1.2.3 · `6504a3a` | [`docs/CONFORMANCE-RPC-CONTRACT.md`](CONFORMANCE-RPC-CONTRACT.md) (its script rows: [`docs/CONFORMANCE-2026-09-27.md`](CONFORMANCE-2026-09-27.md)) |
| Teranode | v0.16.0 · `4edb60a4` | [`docs/CONFORMANCE-TERANODE-MACHINE.md`](CONFORMANCE-TERANODE-MACHINE.md) and [`docs/CONFORMANCE-TERANODE-BRIDGE.md`](CONFORMANCE-TERANODE-BRIDGE.md) |
| GoBDK, Teranode's script library | `4eab3acd` | [`docs/CONFORMANCE-2026-09-27.md`](CONFORMANCE-2026-09-27.md) |
| bsv-rs | 0.7.0 · `5841f98c` | [`docs/CONFORMANCE-2026-09-27.md`](CONFORMANCE-2026-09-27.md) |
| go-sdk | v1.7.2 · `2ca481c5` | [`docs/CONFORMANCE-2026-09-27.md`](CONFORMANCE-2026-09-27.md) |
| @bsv/sdk (ts-sdk) | 3.0.0 · `4d0ea63c` | [`docs/CONFORMANCE-2026-09-27.md`](CONFORMANCE-2026-09-27.md) |

The other report pages cover one surface each: [`docs/CONFORMANCE-P2P-RELAY.md`](CONFORMANCE-P2P-RELAY.md), [`docs/CONFORMANCE-DOUBLE-SPEND.md`](CONFORMANCE-DOUBLE-SPEND.md), [`docs/CONFORMANCE-TERANODE-OBSERVATION.md`](CONFORMANCE-TERANODE-OBSERVATION.md), and [`docs/CONFORMANCE-ASSOCIATION-v122.md`](CONFORMANCE-ASSOCIATION-v122.md), which reads the BSV Association's protocol documentation against the specification.
A column is a run of one build at one pin on the named corpora; it says nothing about another version.

## 4. The open obligations

**The monthly recon.** Every pinned upstream is read at its source once a month and in the week it releases, one dated entry each in [`docs/recon.md`](recon.md).
The newest entry is dated 2026-10-17, the release week of bsv-rs 0.7.0 ([`docs/records/20261017-020538-recon-5-s3.md`](records/20261017-020538-recon-5-s3.md)).
The next monthly entry is due by 2026-11-17.

**The withheld classes.** A divergence class under a still-private security report keeps its kind, its corpus, its column and its count on the report page; its name, its witness and its citation are withheld until the report publishes.
[`docs/WRITE-UP.md`](WRITE-UP.md) §7 counts eight such classes, seven in go-sdk v1.7.1 (counted at v1.7.1, before the pin moved to v1.7.2) and one in @bsv/sdk 3.0.0, each with its one smallest witness withheld.

## 5. What is not claimed

The specification claims the script verdict and the transaction state machine at the pin, judged against the node on the named corpora, and nothing past that.
It does not claim the transaction gate the CLI applies before the scripts (that gate is code no theorem covers), and the script verdict does not judge finality, sequence locks or block-level rules, which the state machine models instead.
The pre-Genesis rows carry the node's verdicts alone.
Termination is definitional, never a theorem.
A Teranode or SDK column is a run at a named pin, not an endorsement.
The harness, the engines, the node oracle and the evaluator's compiler sit outside Lean.
The specification does not claim that the reference is correct; where they disagree, the chain follows the reference.
Nothing here is a priority claim.
[`docs/WRITE-UP.md`](WRITE-UP.md) §5 gives each item in full.
