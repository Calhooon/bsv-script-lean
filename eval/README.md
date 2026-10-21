# eval: the evaluator CLI (`bsvs`, #14)

**The semantics is executable or it is not a semantics** (constitution 03).
`eval/bsvs` is the spec's evaluator: the Lean definitions of `lean/BsvScript`
compiled by Lake into one binary (`lean/Bsvs/Main.lean`, the lake exe `bsvs`)
behind a thin shell wrapper that builds it on first use, only where
`lean/.lake/packages` exists (else it refuses with the reason and exits 3: A23, 2026-09-27).
Where the maintainers' Lean lock helper exists (`LEAN_LOCK_SH`), the build runs only inside a held
slot of that lock, else it refuses the same way; where no helper exists, as in the public edition, it
builds without a lock and says so in one line (2026-10-21). `make verify` builds the binary itself. The wrapper runs a
present binary only when Lake finds it up to date with the tree's Lean sources, and
stamps every run with the commit of those sources (`spec@<commit>`, `docs/DESIGN.md` §6;
`spec@<commit>+dirty` when `lean/` has uncommitted changes, `spec@unknown` without a HEAD at the root (git itself is required by the wrapper's guard)): a
stale binary is refused with exit 3 (rebuild with `BSVS_REBUILD=1`, inside a held slot where the lock helper exists), so is
a binary whose up-to-date check fails for another reason (Lake's exit code and last line
reported) or whose sources move while it is checked, and `--commit` and `--root` are the
wrapper's own, refused from a caller (lean #32's second lens, finding B-4, and its re-lens,
BN-1, BN-3). Before any Lake run the wrapper unsets every `GIT_*` variable by name and refuses
with exit 3 when one cannot be unset or remains, or when `lean/.lake/package-overrides.json` exists
(Lake overlays the manifest with it); then it checks, in the environment Lake inherits, that every
package of `lean/lake-manifest.json` sits at its revision, refusing with exit 3 otherwise: Lake's
workspace load would fetch, check out and clean such a package, delete and clone it again, or
clone an absent one, in the package cache every checkout of the key shares (Lake v4.34.0 `Load/Materialize.lean:255–264`;
its re-lens 2, B2N-2). A `+dirty` or `unknown` stamp marks a local run: a record carries only
`spec@<commit>` (the recorders' refusal, `harness/src/stamp.rs`'s `stamp_refusal`: a spec column whose stamp is not
one commit is refused under `--record` or when the witness directory lies under `corpus/`; `run_diff.rs` reads the same
forms, and `run_engine.rs`, `run_svnode.rs` and the tx road, `txroad.rs`, call `refuse_unnamed_stamp` before any engine
or node is run; lean #32's applied lens, S3's `355b44a`, `3205aea`, `d1576d7`).
It never reads a chain: the spend height is a parameter with a recorded default, and every
prevout carries its own height (required). Its up-to-date check, with the packages at their
revisions, never touches a network, and a rebuild may fetch a dependency's build archive when
that package has no `.lake/build`, unless `LAKE_NO_CACHE=1` (Lake v4.34.0 `Build/Package.lean:59–70`).

```
eval/bsvs eval --tx <hex|@file> --prevouts '<json array>|@file'
               [--spend-height N] [--consensus true|false] [--flags <u32|json array>]
               [--config sv|teranode|sv-regtest] [--genesis-height N] [--chronicle-height N]
               [--input I] [--trace] [--pretty]
eval/bsvs corpus <file.jsonl> [--out <file.jsonl>] [--config sv|teranode|sv-regtest]
               [--genesis-height N] [--chronicle-height N]
eval/bsvs sighash --tx <hex|@file> --scriptcode <hex> --type <u32>
                  [--input I] [--amount <satoshis>] [--forkid true|false]
eval/bsvs --self-test
eval/bsvs --version
```

## `eval`: one spend

`--tx` is the spending transaction (hex); `--prevouts` the outputs it spends,
aligned with its inputs, each `{"txid", "vout", "script", "satoshis", "height"}`
(the corpus format; `height` is the height of the block that created the
output and selects the UTXO's era). The parameters of input `i` are
`Params.derive cfg spend_height prevouts[i].height consensus`
(`lean/BsvScript/Flags.lean`, `docs/PARAMETERS.md` §6): the block path
(`--consensus true`, the default: the word `GetBlockScriptFlags` builds and the
consensus limits) or the mempool path (`--consensus false`: the relay word and
the node's policy limits). `--spend-height` defaults to `DEFAULT_SPEND_HEIGHT`
= 967,896 (`docs/PARAMETERS.md` §3). `--config sv-regtest` with `--genesis-height N` and `--chronicle-height N` judges at a regtest chain's own activation heights (the node oracle's era chains of #49: `tools/cpp_era_run.sh`); without them `--config` picks the node's configuration
(SV-node's mainnet defaults, or Teranode's). `--flags` gives the `uint32_t` word
directly (one for every input, or a JSON array per input): the word's own UTXO bits
then decide the era and the limits are those of that era under the path (`--consensus`,
default true). The `verifyscript` RPC takes such a word too, but re-derives the two UTXO
bits from `txo.height` whenever one is given (`rpc/misc.cpp:806–826`) and builds its limits
with `consensus` false (`858–859`): the CLI's `--flags` is the RPC's word without
`txo.height`, and matches the RPC's limits only under `--consensus false`.
`--input I` runs one input only. The transaction's context per input is
`TransactionSignatureChecker` (`interpreter.cpp:2126–2256`): the version, the
lock time, the sequences, the amount, the real signature check.

The output is one JSON object:

| field | what |
|---|---|
| `verdict` | `valid` · `invalid` · `undefined-in-reference` (a reserved verdict kind; the `OP_SUBSTR`/`OP_LEFT`/`OP_RIGHT` reader at v1.2.3 `6504a3af` returns a defined `SCRIPT_ERR_SCRIPTNUM_OVERFLOW` on a failed fixed-width conversion, [SRC] `int_serialization.h:61–118`, `script_num.cpp:80–91`, `interpreter.cpp:1807–1809`; the previous pin's reading is retained in a history module withheld from the public edition at the maintainers' request, group `d8-node-team-discretion`) · `unimplemented` (the build-time state of an opcode no family has written; unreachable since #18 by `Properties.evalScript_ne_unimplemented`, kept in the vocabulary) |
| `code`, `message` | the reference's `SCRIPT_ERR_*` name at the pin and `ScriptErrorString` |
| `input` | the first non-valid input, advisory (Q5, `docs/DESIGN.md` §6: the transaction verdict is the comparable object) |
| `inputs[]` | every input's verdict and, **echoed**, the parameters it ran under: the flag word as a number and by name, the five limits, the heights, the eras, the path |
| `inputs[].trace` | with `--trace`: per phase (`scriptSig`, `scriptPubKey`, `p2sh`) the instructions executed: offset, opcode, push length, `fExec`, the outcome, and after it the stack depth, the alt-stack depth, the top element, the memory counter and the op count |
| `coinbase` | true when the transaction is a coinbase (its input script is never evaluated, `docs/DESIGN.md` §5.5) |
| `gate` | the transaction-level verdict beside the script verdict, never folded into it (`lean/Bsvs/Run.lean`, `txGate`): `{"verdict": "valid"}` or `{"verdict": "invalid", "code": <the node's reject string>}`, from the consensus gate (`TxRules`: `CheckCoinbase` or `CheckRegularTransaction`) and, on the mempool path, the node's standardness and policy caps (`TxPolicy.mempoolTxPolicy`, under node settings the output does not echo) |
| `config`, `spec`, `reference` | the node configuration, `spec@<commit>`, the pin |

**The trace is the semantics' own execution.** `lean/Bsvs/Trace.lean` restates
the loop's recursion equation through one instruction (`stepK`, `loop_stepK`:
by unfolding) and proves that each traced phase returns exactly the loop's result
(`traceLoop_fst`, through `stepK_map`; `traceEvalScript_fst`). The steps it prints, and
the choice of phases (run with the same environments and inputs `Machine.verifyScript`
gives them), are the same computation by construction: no theorem states them. The
verdict itself is `Eval.verifyScript`, compiled since #50 as `verifyScriptI`, the array
machine (`Eval.verifyScript_eq_I`); the trace runs the list machine (`Machine.execStep`
with `Eval.opExec`). Both are proven equal to the definition, but the binary runs two
machines, so a compiler fault in one would not show in the other.

Example (the `-7 2 OP_MOD = -1` corner; a synthetic outpoint):

```
eval/bsvs eval --pretty \
  --tx 020000000111111111111111111111111111111111111111111111111111111111111111110000000000ffffffff010100000000000000015100000000 \
  --prevouts '[{"txid":"1111111111111111111111111111111111111111111111111111111111111111","vout":0,"script":"018752974f87","satoshis":1000,"height":967896}]'
```

## `corpus`: every entry of a corpus file

Runs each entry of a `.jsonl` corpus (`docs/DESIGN.md` §6) and writes one JSON
object per entry: `spec` (the verdict under the entry's own `params`, an
explicit `flags` word honoured) and `spec-mempool` (under the mempool word of
the same configuration), each with `code`, the advisory `input` and the `gate`, and the
line's `id`, `config` and `commit`. This is the
spec's column of #15's differential (`harness/src/bin/run_diff.rs` joins it
with bsv-rs's live verdicts and files the witnesses).

## `--self-test`: the tripwire's leg

`make check` runs it (`tools/check.sh`, `eval`): the fixed vectors, each a corner
with its citation (`lean/Bsvs/SelfTest.lean`: the number corners, both flag
branches under both words, `OP_RETURN` in both eras, P2SH for a pre-Genesis and
a post-Genesis UTXO, an invalid explicit word, the pre-Genesis op limit, a
truncated push; the 28 fixed vectors each run twice), then a two-input spend with the
failing second input and a coinbase, once each; then `corpus/flow` and `corpus/seed` through the CLI's own
runner, the mempool verdict against bsv-rs's recorded one (a mismatch allowed
only for bsv-rs's known divergences and the recorded flow families). Exit 1 on
any failure.

## `sighash`: the spec's digest

The digest `BsvScript.Sighash.sighash` computes for one input over a scriptCode, printed as
hex: `--type` is the raw hash type, `--amount` the spent output's satoshis (default 0),
`--input` the input (default 0), `--forkid` whether `SCRIPT_ENABLE_SIGHASH_FORKID` is on
(`true` or `false`, default true; any other value is refused, exit 1: `lean/Bsvs/Main.lean`, `sighashCmd`). The generator's sighash family
signs against it (`harness/src/bin/gen.rs`).

## Exit codes, and what the reader refuses

0 for any verdict (a valid and an invalid spend alike); 1 for every malformed input, with
the reason on stderr (bad hex, a transaction frame that does not parse, bad JSON, a missing
field or a wrong type, a prevout count or a flag-word count that does not match the inputs,
an `eval --input` past the last input of a transaction that is not a coinbase, and in a
prevout or a corpus entry: an unknown key, satoshis above `int64`'s maximum, a height at
`MEMPOOL_HEIGHT` or above; in a corpus entry also a number that is not a plain decimal
integer, a spend height of 0, a prevout created after the spend's block, a flag word of 32
bits or more: `lean/Bsvs/Corpus.lean`, each refusal naming its line, and after the JSON parse
the entry and the field or object); 2 for a usage error; 3 for the wrapper's refusals (the
build guard, a `GIT_*` variable that cannot be unset or remains, a `lean/.lake/package-overrides.json`,
a package not at the manifest's revision, git or python3 unable to run, a stale
binary, a failed up-to-date check, sources that moved during it, a caller's `--commit` or
`--root`). The CLI's own options are checked as the corpus reader checks its fields (exit 1):
`eval --input` past the last input, a coinbase's included (`Run.runSpend`), and `sighash --input`
past the last input (`sighashCmd`); `eval`'s `--spend-height` at 0 or at `MEMPOOL_HEIGHT` or above, or below a prevout's
height (`Corpus.checkHeights`); a `--flags` word of 32 bits or more (`parseFlagsArg`,
`rpc/misc.cpp:705`); a number in `eval --prevouts` or a `--flags` array that is not a plain decimal
integer (`Corpus.plainIntegers`). Exit 2 for an unknown option, a `--key=value` spelling, an option
with no value or a stray positional beside no mode (`checkArgs`, `allowed`).

## What the CLI is not

It is not a node: no mempool, no chain. It reports two verdicts per spend, never folded
together: the script verdict (`BsvScript.Eval.verifyScript`) and the `gate`, the
transaction-level rules (`lean/BsvScript/TxRules.lean`, and on the mempool path
`lean/BsvScript/TxPolicy.lean`'s standardness and caps). It is not a second interpreter:
the script verdict is the definition's (compiled as `verifyScriptI`, proven equal to it),
and each traced phase's result is proven to be the loop's.

## Reader checks

The public `numcheck` executable checks the reader of record at v1.2.3. The previous pin's reading and measurements are retained in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`).
