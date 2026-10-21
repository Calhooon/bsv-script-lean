# The front door: which pages to read, in which order

This repository writes the consensus rules of the bitcoin-sv node at a pinned release as a Lean 4 definition that runs,
and runs a harness that compares that definition with the node and with other implementations. The top-level
[`README.md`](../README.md) says what the project is; [`NORTH-STAR.md`](../NORTH-STAR.md) says why. This page says
where to go next. Find your reader below and read the pages in the order given; each line says what question the page
answers. A term of art is defined in [`docs/GLOSSARY.md`](GLOSSARY.md).

The application half, bsv-stack-lean, builds on this specification at a pin; its own front door lists its pages.

## The implementer: you write or test a node, an SDK or a wallet

1. [`harness/README.md`](../harness/README.md): how do I run my implementation against the specification, and how do
   I read the report it writes?
2. [`corpus/README.md`](../corpus/README.md): what are the corpora, where do they come from, and how is each one
   regenerated?
3. [`corpus/INDEX.md`](../corpus/INDEX.md): which corpus and which witness exercise which rule, and what are their
   hashes?
4. [`spec/README.md`](../spec/README.md): where is each part of the specification generated from the Lean sources?
5. [`spec/rules.md`](../spec/rules.md): what is the rule vocabulary, and how many corpus entries exercise each rule?
6. [`spec/flags.md`](../spec/flags.md): what does each bit of the flag word mean, is it consensus or policy, and how
   is the word derived?
7. [`spec/errors.md`](../spec/errors.md): which error does the specification name for each of the node's
   `SCRIPT_ERR_*` codes?
8. [`docs/PARAMETERS.md`](PARAMETERS.md): which values are consensus and which are policy, with each default in the
   node, in Teranode and in bsv-rs?
9. [`eval/README.md`](../eval/README.md): how do I ask the specification's own evaluator, `eval/bsvs`, to decide one
   spend?
10. [`docs/CONFORMANCE-2026-09-27.md`](CONFORMANCE-2026-09-27.md): what disagreements did the harness find between
    the specification and the implementations it ran, with the rule and the smallest witness of each?
11. [`spec/wire-views.md`](../spec/wire-views.md): how are the client encodings EF, BUMP, BEEF, Atomic BEEF and the
    TSC proof parsed and written, as views that decide nothing?
12. [`spec/merkle-proof.md`](../spec/merkle-proof.md): how do `getmerkleproof`, `getmerkleproof2` and the TSC proof
    map to one merkle path and its verification?

## The formalist: you read or extend the Lean

1. [`lean/README.md`](../lean/README.md): what does the Lake project hold, and what state must its sources be in?
2. [`docs/DESIGN.md`](DESIGN.md): what is the machine model (the objects, the step, the trust boundary), with every
   rule cited to the node's source?
3. [`spec/modules.md`](../spec/modules.md): what does each Lean module define, in its own words?
4. [`spec/theorems.md`](../spec/theorems.md): which theorems are proven, and what does each say and assume?
5. [`docs/HYPOTHESES.md`](HYPOTHESES.md): what does the specification trust beyond Lean's kernel and its three
   standard axioms?
6. [`docs/DESIGN-S6.md`](DESIGN-S6.md): how is the transaction state machine around the script verdict built: the
   state, the transitions, the derived status?
7. [`docs/SECOND-FORMALIZATION.md`](SECOND-FORMALIZATION.md): what trust rests on one reading of the C++ into Lean,
   and which second formalization would remove the most of it?

## The ecosystem and the BSV Association: you want to know what the node decides and where others differ

1. [`docs/WRITE-UP.md`](WRITE-UP.md): what is this, how is it judged, and what does it not claim?
2. [`docs/ANNOUNCEMENT.md`](ANNOUNCEMENT.md): what is the project in one sentence and in five lines?
3. [`docs/CONFORMANCE-ASSOCIATION-v122.md`](CONFORMANCE-ASSOCIATION-v122.md): where does the Association's protocol
   documentation state the same rule as the specification, and where does it differ?
4. [`spec/teranode-map.md`](../spec/teranode-map.md): for each rule of the state machine and the layers beyond it, does
   Teranode implement it the same way, another way, or not at all?
5. [`docs/CONFORMANCE-TERANODE-MACHINE.md`](CONFORMANCE-TERANODE-MACHINE.md): how does Teranode's transaction machine
   differ from the reference node's mempool and chain?
6. [`spec/teranode-absences.md`](../spec/teranode-absences.md): what does each implementation not carry, and is each
   absence a gap a client depends on?
7. [`spec/node-client-contract.md`](../spec/node-client-contract.md): what must a node that replaces the reference give
   a client?
8. [`spec/status-views.md`](../spec/status-views.md): how do the status words of the broadcasters, the SDKs and the
   nodes map to one derived status of a transaction?

## The auditor: you check that a claim here is true

1. [`docs/PROVENANCE.md`](PROVENANCE.md): which release of each upstream is pinned, how was it read, and what never
   enters this repository?
2. [`docs/STATE-OF-THE-WORLD.md`](STATE-OF-THE-WORLD.md): where does each milestone stand, and which record holds
   each count? It gathers every current number with its record.
3. [`docs/LINT.md`](LINT.md): what does each leg of `make check` run and catch, and where does it write its record?
4. [`docs/BLOCK-CONSENSUS.md`](BLOCK-CONSENSUS.md): where does the script verdict end, so that "complete" is a claim
   against a stated boundary?
5. [`docs/recon.md`](recon.md): what did each pinned upstream release each month, and does it move consensus or a
   policy default?

## Reports and reference

- [`docs/CONFORMANCE-RPC-CONTRACT.md`](CONFORMANCE-RPC-CONTRACT.md): which JSON-RPC handlers does the node runner call,
  with their arguments, fields and error codes, cited at the pin?
- [`docs/CONFORMANCE-TERANODE-OBSERVATION.md`](CONFORMANCE-TERANODE-OBSERVATION.md): which gRPC calls, HTTP routes and
  Kafka topics of Teranode observe which transition of the machine?
- [`docs/CONFORMANCE-TERANODE-BRIDGE.md`](CONFORMANCE-TERANODE-BRIDGE.md): how does Teranode's legacy bridge read the
  reference's wire protocol, and what does the Lean prove about the mapping?
- [`docs/CONFORMANCE-P2P-RELAY.md`](CONFORMANCE-P2P-RELAY.md): what does the P2P layer announce, request and refuse,
  as a machine whose every setting is policy?
- [`docs/CONFORMANCE-DOUBLE-SPEND.md`](CONFORMANCE-DOUBLE-SPEND.md): how are double-spend notifications formed and
  relayed, and why is a notification never a verdict?

## The evidence: `docs/records/`

Every count, wall or verdict a page quotes names a file under `docs/records/`, the evidence directory. A record's name
starts with the UTC stamp of the run (`YYYYMMDD-HHMMSS`), then names the run or the check it records, for example
[`docs/records/20261018-004634-make-check-box.txt`](records/20261018-004634-make-check-box.txt) (a run of
`make check`) or [`docs/records/20261015-133842-s5-37-cleanroom-s3.md`](records/20261015-133842-s5-37-cleanroom-s3.md)
(the clean-room column). A trailing tag such as `-s3` or `-s4b` names the record's author at the time and is historical.

## The labels

`[M]` measured · `[X]` executed, with the record that names the measured commit · `[D]` derived or designed ·
`[EST]` an estimate · `[LIT]` a public source · `[SRC]` read from the reference's source at its pin.
The labels stand in records, in claim tables and on the provenance pages. On an entry page they appear only inside
tables, and a sentence cites its record's path instead.
