# The public tracker's dry run (#170)

Run 2026-10-21 15:08:53 UTC at commit `d71324be` by the filing script in its dry-run mode (the script and its staged page are withheld from the export as process material). Exit status 0; nothing was posted. The calls it lists: 3 milestone POSTs, 24 issue POSTs, 0 PATCHes [X]. The public numbers are predicted for an empty tracker; the filed record of the public repository's start carries the real ones.

## The full output

````text
# dry run: 3 milestone POSTs, 24 issue POSTs, then the PATCHes for forward references; nothing is posted
# source: the staged page, sha256 0a00a918bddda9fb157172ac46fb8ad93dd1140c39e0d176a8c461f5ca86bac7
# target: <org/name>; public numbers predicted for an empty tracker

POST repos/<org/name>/milestones   (predicted milestone number 1)
{
  "title": "S8 · Teranode as a refinement of the reference",
  "description": "Teranode is an implementation of the transaction state machine of S6 and the node surfaces of S7. This milestone writes the module map (what replaces what), the refinement relation with one proof obligation per row, the theorems with the highest consensus stakes (subtree merkle equivalence, the spend kept equals the spend seen earliest, the sentinel height equals the flag word), the mechanism-level equivalences (UTXO store marks, the state machine and longest-chain marking, the alert system), the absence ledger in both directions, the Teranode observation contract, the legacy bridge, and the per-release divergence report that both implementations' maintainers can run as a gate. Opened 2026-10-07. Teranode v0.16.0 at the pin; SV-node v1.2.3 the reference (docs/PROVENANCE.md). The due date is an estimate from the measured pace.",
  "state": "open",
  "due_on": "2026-11-21T00:00:00Z"
}

POST repos/<org/name>/milestones   (predicted milestone number 2)
{
  "title": "S9 · The year held: columns per release, the loop, the board",
  "description": "What must hold for a year after the public repository's start: a column per release for every implementation, the witness rows taken upstream as a loop, one conformance board, the pin kept within a week of the reference. 2027-10-12 is the end of that year by definition, not an estimate.",
  "state": "open",
  "due_on": "2027-10-12T00:00:00Z"
}

POST repos/<org/name>/milestones   (predicted milestone number 3)
{
  "title": "P · The public reader",
  "description": "The public edition read by a stranger: four doors (the implementer, the formalist, the ecosystem, the auditor), the entry pages re-cut, the repository's internal process vocabulary defined or removed, the contributor pages, the public tracker. Opened 2026-10-21; runs before and after the public repository's start on 2026-10-23.",
  "state": "open"
}

POST repos/<org/name>/issues   (private #123; predicted public #1)
{
  "title": "The next Teranode release measured the week it lands",
  "body": "**Why.** The spec judges Teranode at a pinned release. A new release can move a consensus rule or a policy default, and a pin left behind turns every Teranode verdict stale.

**Deliverable.** In the week the next Teranode release lands: an entry in `docs/recon.md` with the release, its date, what moved, whether it touches consensus or a policy default, and the pin move owed; the harness re-run on the new pin when the pin moves.

**Done-bar.**
- The closing comment quotes the release date and the measurement record of that week under `docs/records/` (evidence: [X]).

**Due.** 2026-11-12.

**Depends on.** nothing.

**Source.** the maintainers' ruling of 2026-10-14.",
  "milestone": 1
}

POST repos/<org/name>/issues   (private #125; predicted public #2)
{
  "title": "Witness rows taken upstream as a loop: each implementation's intake accepts them",
  "body": "**Why.** A divergence found here helps an implementation only when its maintainers receive it in a form they can replay. A witness row (docs/GLOSSARY.md) is that form: the transaction, its previous outputs, the parameters, both verdicts and the rule at the pins.

**Deliverable.** A standing route by which witness rows reach the maintainers of each implementation the harness runs, and a record of their acknowledgements, repeated as rows are found.

**Done-bar.**
- The closing comment quotes the intake's acknowledgements and the recurring witness rows, each with its record under `docs/records/` (evidence: [X]).

**Due.** 2027-10-12.

**Depends on.** nothing.

**Source.** the maintainers' ruling of 2026-10-14.",
  "milestone": 2
}

POST repos/<org/name>/issues   (private #126; predicted public #3)
{
  "title": "Another implementer runs the harness and sends a column",
  "body": "**Why.** The harness is built to judge any implementation of BSV script and transaction validity, not only the ones its maintainers run. The claim holds only when someone else runs it.

**Deliverable.** An implementer outside this repository runs the harness (`harness/README.md`) against their implementation and submits the column of verdicts (docs/GLOSSARY.md) for the corpus at the pins.

**Done-bar.**
- The closing comment quotes the outside run and the submitted column, with the record that holds it (evidence: [X]).

**Due.** 2027-10-12.

**Depends on.** nothing.

**Source.** the maintainers' ruling of 2026-10-14.",
  "milestone": 2
}

POST repos/<org/name>/issues   (private #127; predicted public #4)
{
  "title": "The two Lean libraries as one: one workspace, zero duplicated definitions",
  "body": "**Why.** `bsv-stack-lean` refines its application machines against this specification. Two copies of one definition can drift apart, and a proof about one copy says nothing about the other.

**Deliverable.** One Lean workspace in which the application machines of `bsv-stack-lean` import this spec's transaction state machine, with no definition duplicated between the two.

**Done-bar.**
- The workspace builds and the imports are in place (evidence: [X]).
- A check over both libraries finds zero duplicated definitions, with its record (evidence: [X]).

**Due.** 2027-10-12.

**Depends on.** nothing.

**Source.** the maintainers' ruling of 2026-10-14.",
  "milestone": 2
}

POST repos/<org/name>/issues   (private #128; predicted public #5)
{
  "title": "Maintainability held: every SV-node release mirrored with its citation within seven days, for a year",
  "body": "**Why.** The spec cites the reference at a pinned release (`docs/PROVENANCE.md`). A spec that falls behind its reference describes a node nobody runs.

**Deliverable.** For a year, every SV-node release is read at its source, recorded in `docs/recon.md`, and the pin moved with its citations within seven days of the release. The pin is never more than a week behind.

**Done-bar.**
- The closing comment quotes the year's timeline: each release, its citation and its pin move, showing the seven-day bound, with the records under `docs/records/` (evidence: [X]).

**Due.** 2027-10-12.

**Depends on.** nothing.

**Source.** the maintainers' ruling of 2026-10-14.",
  "milestone": 2
}

POST repos/<org/name>/issues   (private #129; predicted public #6)
{
  "title": "A program proven against the spec: an on-chain script program checked by the evaluator with a theorem",
  "body": "**Why.** The spec's value to a script author is a proof about a real program, not only about single opcodes.

**Deliverable.** A script program that runs on chain, checked by the spec's evaluator on its spending transactions, and a Lean theorem about its behavior under the spec's semantics.

**Done-bar.**
- The evaluator's check of the program, with its record (evidence: [X]).
- The theorem, sorry-free and with only the three allowed axioms (evidence: [M]).

**Due.** 2027-10-12.

**Depends on.** nothing.

**Source.** the maintainers' ruling of 2026-10-14.",
  "milestone": 2
}

POST repos/<org/name>/issues   (private #130; predicted public #7)
{
  "title": "One conformance board: every implementation's column per release on one page",
  "body": "**Why.** A reader comparing implementations today walks several conformance pages. One page should show every implementation at every release.

**Deliverable.** One board page: every implementation's column per release, the application machines of `bsv-stack-lean` beside the script and transaction rows, and a badge an implementation can cite, issued from the board.

**Done-bar.**
- The board page with its columns per release, each column citing its run's record (evidence: [X]).
- The badge issued from the board for at least one implementation (evidence: [X]).

**Due.** 2027-10-12.

**Depends on.** nothing.

**Source.** the maintainers' ruling of 2026-10-14.",
  "milestone": 2
}

POST repos/<org/name>/issues   (private #131; predicted public #8)
{
  "title": "Speed held: a regression on the replay or the gate turns a leg red, for a year",
  "body": "**Why.** A check that becomes slow stops being run. The replay and the gate must stay fast, and a slowdown must be caught by the tripwire (docs/GLOSSARY.md), not by a reader.

**Deliverable.** For a year, the replay's and the gate's wall times are measured on every tripwire run, and a regression past the stated bound turns its leg (docs/GLOSSARY.md) red.

**Done-bar.**
- The closing comment quotes the year's replay and gate timings, with their records (evidence: [X]).
- A record that shows a regression turning the leg red (evidence: [X]).

**Due.** 2027-10-12.

**Depends on.** nothing.

**Source.** the maintainers' ruling of 2026-10-14.",
  "milestone": 2
}

POST repos/<org/name>/issues   (private #156; predicted public #9)
{
  "title": "A Teranode column for bsv-stack-lean: chain-event envelopes from a Teranode node's headers, in the witness format",
  "body": "**Why.** The header service, tracker and wallet of `bsv-stack-lean` react to chain events: fork, reorg, split and splitResolved. Their behavior against a Teranode node is not yet measured.

**Deliverable.** A column in the witness format: the header service's chain-event envelopes emitted from a Teranode node's headers, and the tracker's and wallet's chain-event scenarios run against its answers, in this repository's scenario format (`corpus/scenarios/`). Every row is classified by the rules under `harness/rules/`, as data. The Teranode framing holds: a design row states its reason with a citation before the difference, and only a different chain decision on the same blocks is a chain-split finding.

**Done-bar.**
- The column's record under `docs/records/` (evidence: [X]).
- Its counts on the conformance page it extends, each citing that record (evidence: [X]).
- Every row classified by `harness/rules/` (evidence: [X]).
- A Finding paragraph on this issue naming the record, for the maintainers of `bsv-stack-lean`.

**Depends on.** the public repository's start (2026-10-23).

**Source.** a request of `bsv-stack-lean`'s maintainers of 2026-10-18.",
  "milestone": 2
}

POST repos/<org/name>/issues   (private #157; predicted public #10)
{
  "title": "The Teranode-only run: the whole corpus and the scenarios with SV node absent, the spec the only judge",
  "body": "**Why.** The day Teranode replaces SV node on the network, the reference column is gone. The spec must then judge Teranode alone, and a migration is safe only if that judgment finds nothing unruled.

**Deliverable.** The whole corpus and every scenario run against a Teranode node alone, SV node absent from the run, the spec's evaluator the only judge. Every divergence becomes a witness transaction and a ruling issue.

**Done-bar.**
- The column reads zero unruled divergences across the corpus and the scenarios, with its record under `docs/records/` (evidence: [X]).
- Its counts on the conformance page, each citing that record (evidence: [X]).

**Date.** the week of 2026-11-02 (estimate: [EST]).

**Depends on.** the public repository's start (2026-10-23).

**Source.** the maintainers' ruling of 2026-10-18.",
  "milestone": 1
}

POST repos/<org/name>/issues   (private #158; predicted public #11)
{
  "title": "Ruling: a divergence class under a maintainer's open disclosure, withheld by name and counted",
  "body": "A divergence class under a maintainer's open disclosure, withheld by name and counted.",
  "milestone": 1
}

POST repos/<org/name>/issues   (private #159; predicted public #12)
{
  "title": "Ruling: chain-invalidate-reconsider (scenario.reconsider.revalidation-refused)",
  "body": "**Why.** The two whole runs of check 5 (`spec/node-client-contract.md`, section 1; the record `docs/records/20261016-001926-s8-97-contract-check5-s4b.md`) diverge on this row. Its class comes from `harness/rules/second-oracle-scenarios.json`. The reading at the pins: the row exercises an operator RPC (`reconsiderblock`), never block validity; the reference revalidates the block on reconsider, and Teranode refuses.

**Deliverable.** A ruling: a design row with Teranode's reason cited at its pin, or a finding with its witness.

**Done-bar.**
- The ruling written with its citations at the pins (evidence: [SRC]).
- The row's class in `harness/rules/` updated to the ruling, and check 5 re-run (evidence: [X]).

**Date.** the week of 2026-10-26 (estimate: [EST]).

**Depends on.** nothing.

**Source.** the maintainers' ruling of 2026-10-18.",
  "milestone": 1
}

POST repos/<org/name>/issues   (private #160; predicted public #13)
{
  "title": "Ruling: chain-disconnected-now-nonfinal (timing-sensitive; the whole runs differ)",
  "body": "**Why.** The row is marked timing-sensitive in the corpus and is the one row check 5 counts as an unexplained divergence: its two whole runs differ (`spec/node-client-contract.md`, section 1; the record `docs/records/20261016-001926-s8-97-contract-check5-s4b.md`). A ruling on a row that flickers rules on nothing.

**Deliverable.** One re-measure with the timing pinned (the same bytes and the same clock on both nodes), then a ruling on the measured row: consensus, policy, or a design row with its reason cited.

**Done-bar.**
- The re-measure's record under `docs/records/` (evidence: [X]).
- The ruling written with its citations at the pins (evidence: [SRC]).

**Date.** the week of 2026-10-26 (estimate: [EST]).

**Depends on.** nothing.

**Source.** the maintainers' ruling of 2026-10-18.",
  "milestone": 1
}

POST repos/<org/name>/issues   (private #161; predicted public #14)
{
  "title": "Ruling: chain-unrequested-equal-work (scenario.unrequested-body.regtest-bridge-admits)",
  "body": "**Why.** The two whole runs of check 5 diverge on this row (`spec/node-client-contract.md`, section 1; the record `docs/records/20261016-001926-s8-97-contract-check5-s4b.md`). The reading at the pins: the regtest bridge admits an unrequested block body of equal work; on mainnet both nodes leave such a body unprocessed. The divergence may be the regtest harness's, not the nodes'.

**Deliverable.** A ruling: a harness row, a design row with its reason cited, or a finding with its witness.

**Done-bar.**
- The ruling written with its citations at the pins (evidence: [SRC]).
- The row's class in `harness/rules/` updated to the ruling, and check 5 re-run (evidence: [X]).

**Date.** the week of 2026-10-26 (estimate: [EST]).

**Depends on.** nothing.

**Source.** the maintainers' ruling of 2026-10-18.",
  "milestone": 1
}

POST repos/<org/name>/issues   (private #162; predicted public #15)
{
  "title": "The decider rule's wording for the day SV node leaves: the spec at SV node's last pin frozen as the record",
  "body": "**Why.** Today a disagreement is decided by SV node at the pin. The day SV node leaves the network, the decider becomes the spec, with SV node's last pin frozen as the record. That move happens on a maintainers' ruling, never on the network's timing, and its words must be written before it is needed.

**Deliverable.** The wording: the sentence in `NORTH-STAR.md` and in the contributor rules of `CLAUDE.md`; the `docs/PROVENANCE.md` row that freezes the last pin (the release, the commit, the tree id, and the column's record at that pin); and the harness flag that reads the frozen record as the reference column. SV node stays runnable as the reference until the Teranode-only column reads zero unruled divergences.

**Done-bar.**
- The sentences and the provenance row landed (evidence: [X], the wording gate clean).
- The harness flag reads the frozen record and its run's record exists (evidence: [X]).

**Date.** the week of 2026-11-09 (estimate: [EST]).

**Depends on.** #10.

**Source.** the maintainers' ruling of 2026-10-18.",
  "milestone": 2
}

POST repos/<org/name>/issues   (private #163; predicted public #16)
{
  "title": "README for four readers: what it is, three commands to a report, the map, the claims with their records, the license",
  "body": "**Why.** The README is the public edition's opening screen. It should say what a reader can do before it shows tracker counts and tag hashes.

**Deliverable.** `README.md` re-cut: five lines of what and why; the four doors (the implementer, the formalist, the ecosystem, the auditor), each with its starting page; the verify block as three commands; the repository map; the claims table with its record paths; the license by path; the contact. The tracker state and the tag of record move below the fold into one short status block that cites its record.

**Done-bar.**
- `tools/wording_gate.sh` clean on the page (evidence: [X]).
- Every path the page names exists in the export's tree, by the export manifest (evidence: [X]).
- An independent review by a model of another family (the lens, docs/GLOSSARY.md) holds (evidence: [M]).

**Depends on.** nothing.

**Source.** the maintainers' ruling of 2026-10-21.",
  "milestone": 3
}

POST repos/<org/name>/issues   (private #164; predicted public #17)
{
  "title": "The reading order: one path per reader, as the front door page",
  "body": "**Why.** Four kinds of reader walk in, and the pages are one flat list.

**Deliverable.** `docs/README.md`, the front door: for each reader (the implementer, the formalist, the ecosystem, the auditor) the ordered pages, with one sentence per page saying what it answers. Every page of `docs/` that the export carries appears exactly once. The front door of `bsv-stack-lean` is named as the other half.

**Done-bar.**
- Every exported `docs/*.md` and `spec/*.md` page is listed (evidence: [X]).
- `tools/wording_gate.sh` clean (evidence: [X]).
- The lens holds (evidence: [M]).

**Depends on.** the published URL of `bsv-stack-lean`'s front door (a slot until it publishes).

**Source.** the maintainers' ruling of 2026-10-21.",
  "milestone": 3
}

POST repos/<org/name>/issues   (private #165; predicted public #18)
{
  "title": "lean/README as the module map: opcode to file and line, what is proven, the axiom list, how to read a theorem",
  "body": "**Why.** `lean/README.md` still says \"Empty at birth\". A formalist asks where OP_CHECKSIG lives and what is proven about it.

**Deliverable.** `lean/README.md`: the library layout (BsvScript, BsvChain, Properties, Test, the evaluator's side); the table from opcode family to module and definition; the theorem families with their explainers' pages; the three allowed axioms and the walk that checks them; how to build; how to read one theorem end to end; the pinned toolchain.

**Done-bar.**
- Every module the page names exists, by a walk of `lean/*.lean` (evidence: [X]).
- Every count the page quotes carries its record path (evidence: [X]).
- `tools/wording_gate.sh` clean (evidence: [X]).
- The lens holds (evidence: [M]).

**Depends on.** nothing.

**Source.** the maintainers' ruling of 2026-10-21.",
  "milestone": 3
}

POST repos/<org/name>/issues   (private #166; predicted public #19)
{
  "title": "The labels policy on public prose: evidence labels in records and claim tables, not in entry-page prose; one legend where they remain",
  "body": "**Why.** The evidence labels [M] [X] [D] [LIT] [EST] [SRC] (docs/GLOSSARY.md) keep every claim tied to how it was established. In running prose a stranger reads them as noise.

**Deliverable.** The rule written in the legend of `docs/README.md`: labels stand in records, claim tables and the provenance pages; the entry pages (`README.md`, `docs/WRITE-UP.md`, `harness/README.md`, `lean/README.md`) carry them only inside tables and cite the record in prose instead; each remaining label site on those pages has the legend within reach. Applied to the four entry pages.

**Done-bar.**
- A count of the labels in the prose lines of the four pages, before and after, in the record (evidence: [X]).
- No claim lost its record path: every sentence whose label was removed still names its record (evidence: [X]).
- The lens holds (evidence: [M]).

**Depends on.** #16 and #17, landed before or in the same stack.

**Source.** the maintainers' ruling of 2026-10-21.",
  "milestone": 3
}

POST repos/<org/name>/issues   (private #167; predicted public #20)
{
  "title": "docs/STATE-OF-THE-WORLD.md rewritten as a plain status page: what stands, at which pin, with which record",
  "body": "**Why.** The page is public, and many of its lines carry the repository's internal process vocabulary. A reader wants what stands, at which pin, proven by which record.

**Deliverable.** The page re-cut: the pin, the tag, the tripwire run of record; per milestone what stands and its record; the open obligations (the release reading of `docs/recon.md`, the withheld classes by count); no internal process vocabulary. The history the page carried moves off it.

**Done-bar.**
- Zero process-vocabulary lines, the count in the record, measured by the same grep before and after (evidence: [X]).
- Every count cites a record path that exists (evidence: [X]).
- `tools/wording_gate.sh` clean (evidence: [X]).
- The lens holds (evidence: [M]).

**Depends on.** nothing.

**Source.** the maintainers' ruling of 2026-10-21.",
  "milestone": 3
}

POST repos/<org/name>/issues   (private #168; predicted public #21)
{
  "title": "The glossary: witness, finding, pin, leg, tripwire, corpus, overlay, record, lens, the labels; rename nothing, define everything",
  "body": "**Why.** The repository's words are precise and undefined for a stranger.

**Deliverable.** `docs/GLOSSARY.md`: every term of art the public pages use, one paragraph each, with the page that introduces it; linked from the README's opening screen and from the front door.

**Done-bar.**
- Every term in the glossary occurs on a public page, and every term a grep of the entry pages finds (the list in the record) is in the glossary (evidence: [X]).
- `tools/wording_gate.sh` clean (evidence: [X]).
- The lens holds (evidence: [M]).

**Depends on.** nothing.

**Source.** the maintainers' ruling of 2026-10-21.",
  "milestone": 3
}

POST repos/<org/name>/issues   (private #169; predicted public #22)
{
  "title": "The contributor pages: CONTRIBUTING.md, SECURITY.md, the divergence-report template with the witness fields, a CLAUDE.md for a contributor's agent",
  "body": "**Why.** A contributor needs to know how a change lands and how to report a security issue, and there is no CONTRIBUTING page, no SECURITY page and no issue template.

**Deliverable.** `CONTRIBUTING.md` (how a change lands: the citation rule, the wording gate, the tripwire, the labels, the license by path); `SECURITY.md` (the private reporting route, never the tracker; the rule for withheld classes); `.github/ISSUE_TEMPLATE/divergence.md` (the witness fields: the transaction, its previous outputs and heights, the parameters, both verdicts, the rule, the citations at the pins); and a public `CLAUDE.md` written for a contributor's agent (the constitution, the verify commands, the citation and wording rules, nothing of the internal process), produced by the export from a source file in this tree and gated.

**Done-bar.**
- `make export-public`, then `tools/export_gate.sh` (without `--build`), clean with the new pages in the tree (evidence: [X]).
- Every path the public `CLAUDE.md` names exists in the export (evidence: [X]).
- The lens holds (evidence: [M]).

**Depends on.** the name of the public repository's hosted CI workflow, for the badge.

**Source.** the maintainers' ruling of 2026-10-21.",
  "milestone": 3
}

POST repos/<org/name>/issues   (private #170; predicted public #23)
{
  "title": "The public tracker: the open work re-filed at the public repository's start",
  "body": "**Why.** The repository's earlier tracker was private. The public repository starts with an empty tracker, and the work that is open must be visible here.

**Deliverable.** The open issues of milestones S8, S9 and P re-filed here at the start, with their milestones, each text read against the wording gate; the mapping from the earlier numbers to the public ones written to a record under `docs/records/`.

**Done-bar.**
- The staged texts pass the wording gate (evidence: [X]).
- A dry run listed every call before filing (evidence: [X]).
- The lens holds (evidence: [M]).
- Every issue filed and the mapping in the record (evidence: [X]).

**Depends on.** the public repository's start (2026-10-23).

**Source.** the maintainers' ruling of 2026-10-21.",
  "milestone": 3
}

POST repos/<org/name>/issues   (private #171; predicted public #24)
{
  "title": "make verify: one command for a stranger (the Lean build, the axiom check, the self-test, the smoke run) with a stated time and memory",
  "body": "**Why.** The README's verify block is five commands in two working directories. A stranger wants one command, with its cost named.

**Deliverable.** `make verify` in the `Makefile`: the Lean build, the axiom check, `eval/bsvs --self-test`, and the smoke run of the harness against the seed corpus, each step named as it runs. The README's verify block becomes this one command plus the pinned toolchain line. The wall time and the peak memory are measured once on a named machine and quoted with their record.

**Done-bar.**
- The command green on the export's tree built cold (the gate's `--build` road), with its record (evidence: [X]).
- The README quotes the figures with the record path (evidence: [X]).
- The lens holds (evidence: [M]).

**Depends on.** nothing.

**Source.** the maintainers' ruling of 2026-10-21.",
  "milestone": 3
}

# mapping (predicted): #123->#1, #125->#2, #126->#3, #127->#4, #128->#5, #129->#6, #130->#7, #131->#8, #156->#9, #157->#10, #158->#11, #159->#12, #160->#13, #161->#14, #162->#15, #163->#16, #164->#17, #165->#18, #166->#19, #167->#20, #168->#21, #169->#22, #170->#23, #171->#24
# calls: 3 milestone POST, 24 issue POST, 0 PATCH
````
