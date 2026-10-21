# corpus/witnesses/ts-sdk: the ts-sdk engine's divergences from the spec, as transactions with their rule

Written by `harness/src/bin/run_engine.rs --engine tssdk` (#29; `make enginesdiff`): for each generated
corpus the spec's evaluator (`eval/bsvs corpus`) and `@bsv/sdk` at its pin (`docs/PROVENANCE.md` §1a; the
adapter `harness/engines/ts/runner.mjs` on node 22, out of process over JSON lines) are run on every
entry. Three runs per entry, four columns:

- **`spec`**: the SDK's `Spend` with `verifyFlags` = the names of the block word of the entry's own
  params, against the spec under the same word; **`spec-mempool`**: both under the relay word (the words
  asked of the spec's own executable, `harness/src/flags_oracle.rs`);
- **`default/spec-mempool`** and **`default/spec`**: the SDK's DEFAULT mode (no `verifyFlags`: its own
  derivation from the transaction version, `Spend.ts` `#isRelaxed`), what an application gets out of the
  box, against the spec under the relay word (the closest node word) and, as a note, under the block word.

One witness per corpus × column × rule is filed here in the format of `corpus/witnesses/`; `manifest.json`
carries, per corpus, the counts per column, the words, the undecided runs (the SDK's own exceptions and
process deaths: only those a row of `harness/rules/ts-sdk.json` names are filed as witnesses; every other
undecided run is RED, never a silent skip), the names passed that `Spend` never
reads, the tier-2 code notes. The SDK's message is mapped to the reference's `SCRIPT_ERR_*` through the
cited table `harness/src/tssdk_codes.rs`; a message outside it makes the run RED. The rules and counts are
indexed in `corpus/INDEX.md` §4b (the funnel rule). The verdicts are recorded into every corpus entry as
`ts-sdk@<version>` (the `spec` column's word), `ts-sdk-mempool@<version>` and `ts-sdk-default@<version>`.
