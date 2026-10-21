# corpus/witnesses/go-sdk: the go-sdk engine's divergences from the spec, as transactions with their rule

Written by `harness/src/bin/run_engine.rs --engine gosdk` (#29; `make enginesdiff`): for each generated
corpus the spec's evaluator (`eval/bsvs corpus`) and go-sdk at its pin (`docs/PROVENANCE.md` §1a; the
adapter `harness/engines/go/main.go`, out of process over JSON lines) are run on every entry under the
SAME flag word per input, the word asked of the spec's own executable (`harness/src/flags_oracle.rs`:
`Params.derive` echoed by `eval/bsvs eval`). Two columns, both like-for-like on the parameters:

- **`spec`**: the engine under the block word of the entry's own params against the spec under the same
  (what a mining node decides);
- **`spec-mempool`**: both under the relay word of the same configuration.

One witness per corpus × column × rule is filed here in the format of `corpus/witnesses/` (the smallest
divergent entry, its `expect` carrying the spec's key and the engine's, the `divergence` record with
the citation that decides and the ruling); `manifest.json` carries, per corpus, the counts per column,
the words used, the undecided runs, the reference bits go-sdk has no flag for, the tier-2 code notes.
The engine's code (`errs.ErrorCode`) is mapped to the reference's `SCRIPT_ERR_*` through the cited
table `harness/src/gosdk_codes.rs`; a code outside it makes the run RED. The rules and counts are
indexed in `corpus/INDEX.md` §4b (the funnel rule). The verdicts themselves are recorded into every
corpus entry as `go-sdk@<version>` (the `spec` column's word) and `go-sdk-mempool@<version>`.
