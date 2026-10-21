# harness

**A short start** (the Rust toolchain of the prerequisites below; no Lean, no node):
1. Build the runner: in `harness/`, `cargo build --release --locked` (`harness/run` also builds what it needs).
2. Run it on the seed corpus: from the repository root, `harness/run --impl bsv-rs --corpus seed`.
3. Read the report: `summary.txt` under `harness/target/run/<UTC stamp>/`, one line per corpus (GREEN, RED or SKIP).

## Run it: one command (archived #31)

```sh
harness/run --impl bsv-rs --corpus seed          # one implementation, one corpus; no Lean build needed
harness/run --impl go-sdk --corpus seed
harness/run --impl ts-sdk --corpus all           # every corpus; recorded mode SKIPS corpus/bytes by name (below)
harness/run --help
```

Install the prerequisites below first. `bsv-rs`, `go-sdk` and `ts-sdk` need nothing beyond this repository, the common
tools and a public package registry; `gobdk` and `sv-node` need a clone or a built node that this repository does not
carry. A missing prerequisite stops the run with exit 2 and a line naming it and the subsection here; it is never a RED.

### Prerequisites

**Every implementation.** `git`; Python 3 with `python3` on `PATH`; the Rust toolchain pinned in `rust-toolchain.toml`
(1.95.0; with rustup, from https://rustup.rs: `rustup toolchain install 1.95.0`). `cargo` fetches the
crates at `Cargo.lock`'s checksums from crates.io. `--spec live` also needs the Lean toolchain and Mathlib of
`lean/README.md`; the default, `--spec recorded`, needs no Lean. The pins are `docs/PROVENANCE.md` §1a.

| `--impl` | what must be present | how a newcomer gets it (public reads) |
|---|---|---|
| `bsv-rs` | nothing more | `cargo` fetches the crate `bsv-rs` at the pin |
| `go-sdk` | Go 1.27 (`go.major`) on `PATH` | https://go.dev/dl/; `make gosdk-build` (run by `harness/run`) fetches go-sdk at `engines/go/go.sum`'s sums from proxy.golang.org |
| `ts-sdk` | Node at the version **Node** below states, and its `npm` | below; `make tssdk-install` (run by `harness/run`) installs `@bsv/sdk` at `engines/ts/package-lock.json`'s integrity from registry.npmjs.org |
| `gobdk` | Go 1.27 with cgo and a C compiler (`cc`: Xcode's command-line tools on macOS, gcc or clang on Linux); a clone of `github.com/bitcoin-sv/bdk` at `gobdk.commit` | below |
| `sv-node` | a running regtest node of bitcoin-sv v1.2.3, its RPC address and its cookie file | below |

**Node.** The ts-sdk adapter runs on Node 22: the pin `node.major`, which `@bsv/sdk` 3.0.0's own `engines` field
(`node >= 22`, read in the installed package at the pin) sets, and which `engines/ts/package.json` states as `>=22 <23`. `harness/run` takes the node
`tools/node_bin.sh` resolves (`$NODE_BIN`, else the newest nvm v22, else `node` on `PATH`), stops with exit 2 when its
major is not 22, and hands that node to the driver, so the run uses the node that was checked. Get it from
https://nodejs.org (the v22 line) or `nvm install 22`; with another default node, set `NODE_BIN` to the v22 binary.

**Signer adapter (archived #145, @bsv/sdk 3.0.0).** `make tssdk-signer-build` checks the installed pin, typechecks and lints the
adapter, and runs its signing tests without installing packages or emitting build files. Run
`"$(tools/node_bin.sh)" harness/engines/ts/signer.mjs --corpus corpus/signer/<family>.jsonl --out "$TMPDIR/ts-signed.jsonl"`
from the repository root. The input is the shared corpus Entry with an unsigned `tx` and its `signing` object; the output
has a `template`, `api-default` and `api-scriptcode` line for each row. The template method calls `P2PKH.unlock(...).sign`
with the real prevout; unavailable templates or scopes produce `tx_hex: null` and a reason. The API methods pass the real
locking script or the row's `scriptcode_hex` to `TransactionSignature.format`, respectively. Tokens `<sigK>`, `<pubK>`
and `<preimageN>` represent complete data pushes. The contract in `corpus/signer/README.md`
requires a `scriptcode_hex` list in execution order, `sig_sites[K]` for each key, and `pubkeys` plus `unlock_template`
on every input. Unknown template names produce a named null for every method. Output `inputs` names both `index` and
`site`, the SDK preimage and hash256 digest, the script handed as `scriptcode_used_hex`, and the separately serialized
form as `scriptcode_serialized_hex`.
Template preimages are recomputed with the SDK formatter. The adapter applies the specified version, locktime and sequences
without choosing fees, change, an era override or a scriptCode; acceptance belongs to the signer column. The
[development check and source reading](../docs/records/20261016-192436-s4b-145-signer-adapter-ts-s4b.md) describe the paths and limits.

**gobdk: the clone.** `engines/gobdk/build.sh` (run by `harness/run` through `make gobdk-build`) builds the shim from a
local clone, never from the network. The clone's path is `GOBDK_CLONE` when set, else the pin `gobdk.clone` (the maintainers' layout,
`docs/PROVENANCE.md` section 1a). Get it:

```sh
export GOBDK_CLONE=/path/to/bdk
git clone https://github.com/bitcoin-sv/bdk "$GOBDK_CLONE"
git -C "$GOBDK_CLONE" checkout --detach 4eab3acdbbb971724f37e886e836daa1ed444a7f     # gobdk.commit (archived #54, 2026-10-06)
```

The prebuilt archives the shim links (`module/gobdk/bdkcgo/libGoBDK_<os>_<arch>.a`, for darwin arm64 and
linux aarch64 and x86-64 at `4eab3acd`; darwin x86-64 too at `cdfa7814`) are files of that commit; `build.sh` checks each against the commit's blob and the module
against Teranode v0.16.0's `go.sum` sums before it links (`engines/gobdk/README.md`).

**sv-node: the node.** The runner asks a regtest instance of the reference, bitcoin-sv tag `v1.2.3` = `6504a3aff`, through
its `verifyscript` RPC. The node is not in this repository. Build it from the public tag
(`git clone https://github.com/bitcoin-sv/bitcoin-sv && git -C bitcoin-sv checkout v1.2.3`, then that repository's own
build instructions; not exercised by this page's records); `make check-pins` compares its `bitcoind -version` first line with
`reference.version_string`. Then:

```sh
export SV_BIN=/path/to/bitcoind SV_CLI=/path/to/bitcoin-cli    # set both: the default is the maintainers' build path
export SPEC_ORACLE_DATADIR=/path/to/a/datadir                   # the same: set it
harness/oracle/spec-node.sh local start
harness/run --impl sv-node --corpus seed --rpc http://127.0.0.1:18563 \
    --cookie "$SPEC_ORACLE_DATADIR/regtest/.cookie"
harness/oracle/spec-node.sh local stop
```

The cookie is `<datadir>/regtest/.cookie` and changes at every start. The `spec-mempool` column wants the second
instance (`spec-node.sh policy start`, RPC `127.0.0.1:18565`, passed as `--rpc-mempool` and `--cookie-mempool`);
`oracle/README.md` describes the instances. `spec-node.sh` says what it lacks and exits 2 when the binaries are absent,
and `local status` does the same when no node answers.

It builds what the run needs (the driver through `cargo`, on the crate's pinned toolchain; the implementation's adapter
through the Makefile), writes the specification's verdicts for the corpus, runs the implementation on every entry under
the SAME flag word the specification judged that entry under, compares the two verdicts entry by entry, files every
divergence under a cited rule or as unexplained, and writes the report. It never writes the committed corpus.
The go-sdk run on `gen` can reach the adapter's timeout and its longer retry. Start with the seed corpus before
running all corpora. The timeout and retry behavior are specified in `src/engines.rs`.

`--no-build`, with `--spec recorded`, reuses existing release executables from `CARGO_TARGET_DIR` (or `harness/target`) and installed adapters.
It performs no build or install. Its report says that the executable sources are unchecked, so it carries no validation
of changes in the current checkout.

| `--impl` | what runs | what it needs |
|---|---|---|
| `go-sdk` | `github.com/bsv-blockchain/go-sdk` at its pin (`docs/PROVENANCE.md` §1a), through `engines/go` | Prerequisites: go-sdk |
| `ts-sdk` | `@bsv/sdk` at its pin, through `engines/ts` | Prerequisites: Node |
| `gobdk` | Teranode's script engine (GoBDK), through `engines/gobdk` | Prerequisites: gobdk |
| `bsv-rs` | the `bsv-rs` crate at its pin, in process (`run_diff`) | nothing more |
| `sv-node` | the reference, bitcoin-sv v1.2.3, through its `verifyscript` RPC (`run_svnode`) | Prerequisites: sv-node; `--rpc <url> --cookie <file>` |

**The specification's verdicts (`--spec`).**
- `recorded`, the default, needs no Lean. The verdicts are the ones recorded in the corpus: each entry's `spec@<commit>`
  and `spec-mempool@<commit>` keys, which the maintainers' `run_diff --record` wrote at that commit (`spec_recorded` writes
  them out; the report names the commit). The SDK and node drivers use the flag words recorded in
  `corpus/witnesses/<impl>/manifest.json` (`--words-from`), each the word the specification's `Params.derive` gave
  for the entry's heights. The `bsv-rs` driver derives its words locally through `engine::word_for`; its report
  identifies that derivation. `corpus/bytes`
  records no spec verdict, so this mode SKIPS it by name. Partial coverage, duplicate entry IDs, inconsistent commit
  stamps and a stamp that names no commit (empty, spaced or in no form `eval/bsvs` emits, `+dirty` or `unknown`) are
  errors; no report can claim GREEN after silently omitting those entries.
- `live` runs the specification's own evaluator, `eval/bsvs`, compiled from `lean/` by Lake (the pinned Lean and
  Mathlib), for the verdicts and the words.

**The stamp's gate (archived #32, B-4; the maintainers' rulings P4 to P6, 2026-10-05).** A spec column is stamped `spec@<commit>`, the
forms `eval/bsvs` emits being a short commit (7 to 40 lowercase hex digits), that with `+dirty` (uncommitted `lean/`
changes) or `unknown`. `run_engine`, `run_svnode` and its block road (`--mode tx`) read the column's stamps right after
the repository root is set and before the corpus is loaded or a node is touched (`harness/src/stamp.rs`). When the run
would write into `corpus/` (`--record`, or `--witnesses` under it) and the stamp names no commit (`+dirty`, `unknown`, a
column missing or unreadable, a form `eval/bsvs` never emits, or lines naming several commits), the run stops with
exit 2 and the gate's report, `refusing to write spec@<stamp> into the corpus (...)`, a stamp in no emitted form named
after it; for a missing or unreadable column that report comes before any file-read error (`tests/stamp_gate.rs`).
`run_diff` makes the same check. The gate's reader is lenient: a line it cannot read names `unknown` state, and off the
corpus every stamp passes it. The comparison's reader (`harness/src/differential.rs`, `read_spec`) is strict: a line
it cannot read is an error. The two stay apart by the maintainers' ruling; unifying them would be a new finding.

**The corpora (`--corpus`).** A directory (`corpus/seed`: its manifest names the file), one `.jsonl` file, or `all`
(seed, flow, arith, stack, crypto, bytes, eras, gen, tx). An entry is a spending transaction, its prevouts and its
parameters (`docs/DESIGN.md` §6); `corpus/INDEX.md` says what each corpus covers.

**The columns.** `spec`: the implementation under the block word of the entry's own parameters (what a mining node
decides) against the specification under the same word. `spec-mempool`: both under the relay word (the node's default
policy). ts-sdk has a third run, `default`: its own derivation from the transaction's version, what an application gets
out of the box, compared with both.

**The report** (`--out <dir>`, by default `harness/target/run/<UTC stamp>/`):

| file | what |
|---|---|
| `summary.txt` | one line per corpus: GREEN, RED or SKIP, and the totals |
| `<corpus>.log` | the driver's report: the agree counts per column, the flag words, the divergences by column and rule, the notes where both reject with different codes |
| `<impl>/<corpus>.jsonl` | one WITNESS per corpus, column and rule: the smallest entry that diverges under that rule, with both verdicts in `expect` and a `divergence` record (the rule; `a` the specification's key and `b` the implementation's, with their verdicts; `decided_by`, the reference's lines and the engine's that decide it at the pins; `ruling`, `impl-wrong`, `spec-wrong` or `open`; a note) |
| `<impl>/manifest.json` | per corpus: the entries, the agree counts, the undecided runs, the aborts filed as witnesses, the words, one row per rule (column, rule, entries, ruling, witness), the code notes |
| `spec/<corpus>.jsonl` | the specification's verdicts the run used |

**GREEN and RED.** A divergence is EXPLAINED when a row of `rules/<impl>.json` names its class (the classifier is data,
D83c: each class cites the reference's lines and the engine's) and UNEXPLAINED otherwise. A corpus is GREEN when every
divergence is explained, and RED on an unexplained one, an engine code outside the cited tables, or an adapter error.
The exit status is 0 when at least one corpus ran and every one that ran is GREEN, 1 on any RED or when nothing ran,
2 on a usage or setup error; a SKIP is never GREEN. A RED
names the entries to look at, never a verdict: whether the implementation or the specification is wrong is decided from
the reference's source (`CONTRIBUTING.md`, "Report a divergence"), and a class is added to the table with its citation.

**Go signer.** The separate [signer adapter](engines/go/signer/README.md) reads the shared signer corpus Entry plus `signing` and writes `template`, `api-default` and `api-scriptcode` results, including SDK preimages and digests; an unavailable path writes `tx_hex: null` with its reason. Build offline with `make gosdk-signer-build` into `harness/target/engines/gosdk-signer` (override `GOSDK_SIGNER_BIN` for a shared target directory), then run `gosdk-signer --corpus <file> --out <file>`. It shares the verifier's pinned Go module, uses the row's version, locktime and sequences, and leaves verdicts to the node column. The [adapter record](../docs/records/20261016-192344-s4b-145-signer-adapter-go-s4b.md) covers go-sdk v1.7.2 and the archived #144 replay.

**bsv-rs signer (archived #147).** The bsv-rs adapter `signer_bsvrs --corpus <file> --out <file>` uses public P2PKH, P2PK and Multisig unlock templates. Templates cannot express Chronicle or no-FORKID scopes and emit named nulls for them and for in-unlock shapes. `api-default` calls `SigningContext::compute_sighash` with the source output; `api-scriptcode` uses the dispatched signing function with each supplied scriptCode; since 0.7.0 (archived #148, 2026-10-17) a fourth method, `api-context-scriptcode`, passes each supplied scriptCode through the library's public override `SigningContext::with_script_code` and signs with the context. Every explicit-scriptCode digest (both `api-scriptcode` and `api-context-scriptcode`) must equal the hand control, otherwise the column is RED; the self-consistency line counts both. Original constant-one digests have empty `preimage_hex`, documented in the adapter note.

**Signer column (archived #145, #147).** `make check-signer` builds the go-sdk v1.7.2, @bsv/sdk 3.0.0 and bsv-rs 0.7.0 (0.5.0 until archived #148's re-pin, 2026-10-17) signer adapters offline, runs their signing tests, and runs `run_signer` over every row of `corpus/signer/`. The runner starts an owned, empty regtest instance of the pinned node on a free port, judges every input of each signed transaction and its hand-signed control through `verifyscript` with the supplied prevouts, and checks the applied block and relay flag words against `FlagsOracle`. Both columns use the oracle's consensus limits; this measures scripts, not mempool admission or transaction finality. An unavailable method is unsigned with its reason. Refusal counts are per transaction and class; different input failures can place one transaction in multiple classes. Source-cited `rules/*-signer.json` tables classify refusals and distinguish intentional control refusals from signer divergences; an unclassified result stops the run RED. `run_signer --check-rules` and `rules_check --signer` validate these tables with the same loader; the ordinary `rules_check` mode replays verifier manifests. Timestamped records go to `SIGNER_RECORD_DIR` when set, otherwise `docs/records/`; the node is stopped and its scratch directory removed before a completed record is written. Set `CARGO_TARGET_DIR` to a run-owned external target, provide a matching prebuilt Lean cache (or set `SIGNER_BSVS` to an external copy of its executable after checking the Lean sources) and copied pinned `node_modules`, and set `TMPDIR` to external scratch. Each record includes the evaluator's resolved path and SHA256 in `source_sha256`. The record header names the run's author and model from `SIGNER_LANE` and `SIGNER_MODEL`, `<unset>` when absent. The target runs once per signer pin move inside the recon, independently of the twenty-nine `make check` legs.

**Signer chain (archived #152 step 1).** `run_signer_chain [--version-1] [--emit <file>]` puts the same rows on a chain: a fresh regtest instance of the wallet build of the pin (`reference.binary_wallet`) with the oracle conf's activation heights replaced by Teranode's regtest ones (Genesis 100, Chronicle 200), both grace periods 0 and `txindex=1`, mined to 300; every post-Chronicle row of `corpus/signer/` (either version: the flag word carries no version, the machine's gate reads the transaction's; `--version-1` asks only the version-1 rows and writes a `-v1` record) and every post-Chronicle row of `corpus/xsig-144/` (converted to its shape's signer row) is funded TEN times, once per slot (the hand-signed control, and each adapter by each method), one wallet funding transaction per row and slot whose outputs 0..n-1 are the row's prevouts; the row is rebound to those coins (outpoints and coin heights only; the ten rebound corpora go to `CHAIN_REBOUND_DIR`, default under `$TMPDIR`, refused inside the checkout), signed, judged by `verifyscript` under the block and relay words (`eval/bsvs --config sv-regtest` at the instance's heights; `SIGNER_BSVS` required), submitted by `sendrawtransaction` and mined. The line `signer chain: GREEN|RED` counts CHAIN AGREES WITH COLUMN (accepted and mined iff the relay word judges every input valid; a rejection's wrapped `SCRIPT_ERR_*` equal to the column's, a rejection wrapping none RED), the finality class apart (a valid script with a non-final lock time, held in the node's non-final pool), and RED for any other difference. Pre-Chronicle rows are listed by id as not on this chain. The JSON record goes to `SIGNER_RECORD_DIR` or `docs/records/`. **The emitted set** (`--emit`): one JSON line per (row, engine, method), engine `control` with method `hand` for the hand signer: `id`, `engine`, `method`, `tx_hex` (null when the method could not sign, its reason in `unsigned`), `prevouts` (`outpoint` as `txid:vout`, `script` the locking script hex, `satoshis`), `funding_tx_hex` (the wallet transaction that created those coins, outputs in prevout order, change last), `reference_verdict` (`accepted`, `rejected`, or null when unsigned), `reject_token` (the reason before its parenthesis, e.g. `mandatory-script-verify-flag-failed`), `reject_code` (the wrapped `SCRIPT_ERR_*`), `mined` (true, false when held non-final, null when rejected or unsigned), `spend_height` (the block it was mined in, else the tip plus one at submission), `funding_height` and `unsigned`. `tx_hex`, `funding_tx_hex` and the outpoints are bound to this run's chain (the signatures commit to the outpoints); a submission run on another chain funds the same scripts and amounts, rebinds the corpus row and re-signs, and compares with `reference_verdict` / `reject_code`. Same environment as `make check-signer` (`GOSDK_SIGNER_BIN`, the pinned `node_modules`, an external `CARGO_TARGET_DIR` and `TMPDIR`).

**Bringing another implementation.** An adapter is a program that answers `--version` with one line naming its version,
then reads one JSON request per line on stdin and writes one JSON response per line on stdout, in order (`src/engines.rs`):

```json
{"id": "seed-000001", "tx": "<hex>", "prevouts": [{"txid": "<hex>", "vout": 0, "script": "<hex>", "satoshis": 1000}],
 "runs": [{"key": "block", "mode": "flags", "flags": [4015663]}, {"key": "mempool", "mode": "flags", "flags": [4016127]}]}
{"id": "seed-000001", "runs": {"block": {"verdict": "invalid", "input": 0, "code": "<your code>", "message": "<your message>"},
                               "mempool": {"verdict": "valid"}}}
```

`flags` carries one reference flag word per input (`SCRIPT_VERIFY_*`, `docs/PARAMETERS.md` §6); `verdict` is `valid`,
`invalid` or `undecided` (no verdict: counted apart, or filed as the engine's abort when the specification decides the
entry, D15). Wiring it in today is a code change:
a variant of `EngineKind` in `src/engines.rs`, a table from its codes to the reference's `SCRIPT_ERR_*` names
(`src/gosdk_codes.rs` is the model), and `rules/<name>.json` with no rows, so every divergence prints as UNEXPLAINED:
that list is where a new implementation's review starts.

**In CI.** `ci/harness-only.yml` is an example job (not enabled here: copy it into `.github/workflows/` of a fork): the
crate's tests and the two SDKs against the recorded specification on the seed, the report uploaded as an artifact. The
repository's own gate is `.github/workflows/gate.yml` (archived #116; docs/LINT.md section 5; a design, not a run, until a pull request on the
public repository runs it): every pull request runs the twenty-nine legs of `make check` on hosted runners, which skip
by name the reads of the pinned clones and the built reference; the maintainers' box makes those reads and posts the
commit status `box/withheld-legs`. The regtest node and the Teranode instance run on demand on the box, in no leg and
under no status (tools/withheld_legs.txt).

### One implementation's column per release (archived #124, 2026-10-14)

```sh
make column IMPL=bsv-rs PIN=0.7.0      # the current pin: a dry run, compared with the committed column
make column IMPL=go-sdk PIN=<release>  # another release: the pin move (a landing of its own)
make column IMPL=ts-sdk PIN=3.0.0 PLAN=1   # every site a move touches, with its value now; writes nothing
```

The maintainers' step beside `harness/run`: `tools/column.sh` (its header is the manual; `tools/column.py` the
mechanism) re-runs every corpus an implementation's column records, the keys of its witness manifest, through the
drivers above with each corpus's recorded spec configuration. At the pin of `docs/PROVENANCE.md` §1a it is a dry run:
the drivers record into scratch copies under `target/column/`, nothing under `corpus/` is written, and the run must
equal the committed column (entries, agreements per column, classified rows by class, the implementation's own verdict
per entry). At another release it moves the sites `make check-pins` reads, builds or installs the implementation as the
Prerequisites above say, and re-records the corpora, keeping every other implementation's rows as committed. `sv-node`
runs on the two instances `SV_RPC`/`SV_COOKIE` and `SV_RPC_MEMPOOL`/`SV_COOKIE_MEMPOOL` name; `teranode` names
`engines/instance41/`'s recipe; neither is ever started by the command. The record is
`docs/records/<stamp>-column-<impl>-<pin>-s3.{md,json,txt}`; the last line printed is the verdict.

### The Teranode gate: one release against the reference, one page (archived #95, 2026-10-17; the live run of record, docs/records/20261017-234627-s8-95-gate-report-s3.md; the dry-run shape, docs/records/20261017-231954-s8-95-gate-report-s3.md)

```sh
make teranode-gate DRY_RUN=1 [OUT_DIR=<dir>]       # the page from the records on disk; starts nothing
make teranode-gate                                 # the plan: every measuring step with this run's SINCE stamp
make teranode-gate STEP=<step> SINCE=<stamp> ...   # one step, in the foreground; then STEP=report
```

What it answers: this Teranode (`teranode.tag` and `teranode.commit` of `docs/PROVENANCE.md` §1a) against this
bitcoin-sv (`reference.tag`, `reference.commit`), on the scenario corpus (`corpus/chain/<family>/`, archived #66) and the script
corpus, every difference a witness row with its class, its citation and where its ruling stands, and what moved since
the previous gate record. The page is `docs/records/<stamp>-s8-95-gate-report-s3.md` with its data beside it
(`<stamp>-s8-95-gate-report-s3.json`, which the next run's delta reads; the delta's head says whether that previous
record was a dry run or a live one, and a live run prefers the newest live record). `DRY_RUN=1` writes the pair under
`docs/records` (OUT_DIR=<dir> elsewhere, so a shape check neither dirties the tree nor becomes the next previous record).
`tools/teranode_gate.py`'s header names every input and `tools/teranode_gate.sh`'s every step.

**The page and the log (the maintainers' ruling, 2026-10-17).** The page is public by archived #95's charter, a page either team
reads: it carries verdict words and codes, the obligation list's classes, row ids, hashes and counts, never a node's
message text (an observed value's string field is printed only when it is a code). Every step's raw output, the nodes'
own text, is appended to `docs/records/<SINCE>-s8-95-gate-teranode-log-s4b.txt`, and the step names that file in
`tools/export_withheld.txt` under the group `hz-95-teranode-gate-logs`, so the public edition never carries it and an
ordinary run never opens it; the terminal gets each step's exit code and the log's name.

**Before the steps.** (1) The builds, `CARGO_BUILD_JOBS=4`: `cd harness && CARGO_TARGET_DIR=$PWD/target cargo build --release --locked --bin
run_scenarios` (the scenario steps run `harness/target/release/run_scenarios`, the worktree's own target); `cargo build
--release --locked --manifest-path harness/Cargo.toml --bin run_teranode` with
`CARGO_TARGET_DIR` set to the target directory `engines/instance41/seed_chunk.zsh` runs it from
(`BIN`, line 17). (2) The reference node: the pinned build of `oracle/README.md` (`-version` checked by `make
check-pins`); the script-reference step needs the two instances `SV_RPC`/`SV_COOKIE` and `SV_RPC_MEMPOOL`/`SV_COOKIE_MEMPOOL`
running. (3) The Teranode instance by its recipes: `engines/instance41/README.md` (the build at the tag, its binary's
sha256 checked at every start; `instance.py`; the `legacy` recipe of `engines/instance41/legacy.conf` for the scenario
column; the native client of `engines/instance41/native/build.py` for the observation contract of archived #97). (4) The host
file `tools/host_private.sh` (the maintainers', withheld from the public edition): the steps that start a node source it
for `BOX_LEG_LOCK_SH`, the shared box leg lock helper (its lock file `<the maintainers' build host>:box-leg.lock`, the helper's `BOX_LEG_LOCK`,
its queue `<the maintainers' build host>:box-leg.lock.q`), and `LEAN_LOCK_SH`, the plan's `lean_lock.sh`; a host without the box locks writes
its own two-line host file naming two scripts that define `box_leg_take`/`box_leg_release` and
`lean_lock_take`/`lean_lock_release` as functions returning 0, and says so in what it sends back.

**The two nodes, on regtest, at the pins.** Every step that starts a node takes the box leg lock and a Lean slot and
waits for a 1-minute load under 20: scenario-teranode and script-teranode take them in their sub-scripts
(`engines/teranode/column.zsh`, `engines/instance41/seed_chunk.zsh`), scenario-reference takes them in
`tools/teranode_gate.sh` (run_scenarios takes none); script-reference starts no node. Nothing is broadcast and no step
reaches the network (`CONTRIBUTING.md`, "What never enters"). At a new Teranode release: build it by the recipe at the new tag, move
the pins (`make column IMPL=teranode PIN=<tag>`), then run the plan.

**The steps, in order** (`make teranode-gate` prints every line with the stamp): `STEP=scenario-teranode
ORACLE_ROWS=<chunk>` per chunk, the chunks generated by `tools/teranode_gate.py --chunks`: the whole column's wall,
2,017.7 s (`docs/records/20261016-001926-s6-66-cut2-second-oracle-s3.json`'s `wall_seconds`, 137 realizable rows of
478), gives six chunks of at most about 400 s, an estimate (2,017.7 s over 137 realizable rows, 23 a chunk, about 14.7 s
a row; 400 s is the chunk's target, `CHUNK_SECONDS`; the land-w3w fold, 2026-10-17), the realizable rows dealt evenly
in corpus order and the unrealizable
rows (no node call) likewise, every row once; the lock is taken per chunk, since each chunk is one foreground call and
the lock's holder is the calling process (holding it across calls needs a background holder, which the run rule
forbids), and the FIFO queue may interleave a tripwire leg between chunks. Then `STEP=scenario-reference FAMILY=<f>`
for each of the six families; `STEP=script-teranode CORPUS=<c> MANIFEST=<m> FROM=<n> COUNT=<n>` per corpus chunk (the
corpus's own manifest: `cases-manifest.json` for arith, bytes, crypto and stack, `manifest.json` for the rest);
`STEP=script-reference CORPUS=<c>` per corpus (the 20261017-234627 run re-measured 18 corpora, every one REPRODUCED:
cpp-opcode's 144,324 entries in 36 s and cpp-script's 67,991 in 15 s, both under the 600 s a call may take; `road` and
`tx` refuse at startup, no words row for them in the committed words table); `STEP=report`.
The report reads only the records written since `SINCE` and refuses a column missing a family or holding a row twice.
The rows a measured leg owns (archived #92, #93, #94, #140, #152) are re-run by the leg's own runner, which its record names; the
gate carries their public counts from `corpus/teranode/obligations.json`.

**What each class means.** The classes are archived #88's obligation list's six kinds and no other word: `theorem` (agreement
proved in Lean, the names resolved by the elaborator; cited, not re-run), `witness` (a measured leg agreeing on both
nodes), `report` (a row the two implement the same way, judged here by the scenario rows on it), `design`, `chain-split`
and `open`. The framing rule (the maintainers', 2026-10-17): Teranode reached for BSV's scale with architecture decisions that
leave the protocol's rules unchanged, and every difference is read against that north star. A `design` row is such a
decision (no mempool, a UTXO store with marks, subtrees, Kafka, a signed alert channel), Teranode's reason cited at its
source before the difference, labeled policy; it names a different mechanism serving the same protocol, never a fault. A
`chain-split` row is the chain itself deciding the same blocks differently on the two nodes, consensus. A difference no
ruling names is `open`, and the page says where its ruling would come from (the errata rule of `docs/WRITE-UP.md` §8: the maintainers rule; the report only
cites the decisions log, the card or the class file); an open difference on a theorem row says its premises or the
index row are owed a reading. The page names the `rerun` rows it did not re-measure (no judged scenario row, no leg).

**Sending a record back.** Run the plan on your regtest, then send us the pair
`docs/records/<stamp>-s8-95-gate-report-s3.md` and `.json` with the commit your tree was at and the host it ran on; the maintainers
land them under `docs/records/` as received, the sender named, and the next gate's delta reads them. The log stays
with you unless we ask for it. The dry run's shape record: `docs/records/20261017-231954-s8-95-gate-report-s3.md`.

### The standing fuzz campaign on the box (property 2, 2026-10-15)

```sh
nohup tools/fuzz_campaign.sh >/dev/null 2>&1 &     # the standing loop, from the campaign's worktree on the box
touch "$FUZZ_STATE/STOP"                          # ends it at the next batch boundary; both nodes stopped
tools/fuzz_daily.sh                                # the day's one line, into $FUZZ_STATE/DAILY.txt
```

The bench leg's fuzz smoke (archived #137) checks bsv-rs and `seed_gen` inside the tripwire; `tools/fuzz_campaign.sh` (its
header is the manual) runs the SPEC against the PINNED NODE on fresh cases outside it, with no model in the loop:
batch n is the smoke's leading 1,000 cases, the replay and 50,000 fresh cases (the paragraph below), then `eval/bsvs corpus`,
then `run_svnode --dump` on two fresh regtest instances of its own (the oracle's two confs, `oracle/README.md`; ports
18601 to 18604, outside the standing instances' and the runner's 18571 to 18590), whenever the box's 1-minute load is under 12 (under the tripwire's 20: the
campaign yields). Every new divergent node cell (a spend and column holding no row yet) becomes a witness row of
`corpus/fuzz/<date>.jsonl`, and every new SDK class one of `corpus/fuzz/<date>-<engine>.jsonl`, in the harness's witness shape (the format:
`corpus/fuzz/README.md`) with its batch's record line, `ruling: open`; the loop writes them in the dedicated worktree
`$FUZZ_TREE` on the maintainers' build host (`FUZZ_STATE` and `FUZZ_TREE` come from the environment or
`tools/host_private.sh`; on its own branch, named in the design record below), commits nothing and never builds (no Lean, no cargo:
its binaries are that worktree's own, built once by hand). The design and the dry run:
`docs/records/20261015-132239-fuzz-campaign-s3.md`.

Since 2026-10-15 (the record at the paragraph's end) a batch is the bench smoke's leading 1,000 cases at the campaign tree's commit, the
replay of every row of `corpus/fuzz`, and 50,000 fresh cases in one `seed_gen --family F` stream per family under a salted
seed (`tools/fuzz_compose.py`); after `run_svnode` the loop runs `run_engine --engine go-sdk|ts-sdk --dump` on the same
corpus and spec file with the runners as this page's Prerequisites build them (`make gosdk-build`, `make tssdk-install`
and node 22 in the campaign's worktree), its outputs in its own layout under the batch's directory; an engine whose runner,
adapter or node 22 is absent is SKIPPED BY NAME on the batch line, never a pass. The batch line carries per-engine counts,
per-family counts, every part's seed, the replay's tally and per-stage walls; the record:
`docs/records/20261015-150411-fuzz-cut2-s3.md`.

Since 2026-10-16 (the record at the paragraph's end) the spec stage runs in chunks of 10,000, the loop also waits for 8 GB of
unused memory and while $FUZZ_STATE/PAUSE exists, stops itself after 20 batches without a new signature at one tuple
(SATURATED), runs at most 200 batches a UTC day and restarts a node after 24 hours or 4,096 MB; the record
docs/records/20261016-135453-fuzz-cut3-s3.md.

## The files

The conformance harness (seeded 2026-09-22, archived #4). A Rust crate:

| file | what |
|---|---|
| `run`, `src/bin/spec_recorded.rs`, `ci/harness-only.yml` | the command, recorded evaluator output and CI example ([LIT] archived #31) |
| `src/engine.rs` | the bsv-rs runner: one input of a transaction against its prevout through the pinned `Spend` engine; VENDORED pattern from a predecessor harness of the maintainers' (`run_lock`, `verify_tx`, the verdict type), header inside |
| `src/gen.rs` | the seed generator's families: the PRNG, the independent minimal number encoder, the i128 reference model, the mutation operators; VENDORED pattern from the same predecessor harness's fuzz binary, header inside; the contract corpora of that file did not cross |
| `src/txraw.rs` | a raw transaction codec that never parses scripts (this repo's) |
| `src/corpus.rs` | the entry and manifest format of `docs/DESIGN.md` §6 (this repo's) |
| `src/differential.rs` | shared corpus hash checks, evaluator JSON readers and verdict conversion for `run_engine` and `run_svnode` ([LIT] archived #31); `run_diff` adoption is S2's next patch |
| `tests/recorded_inputs.rs` | recorded-mode coverage, provenance and raw-byte checksum checks ([LIT] archived #31) |
| `src/bin/seed_gen.rs` | `make seed`: the deterministic seed corpus into `corpus/seed/` |
| `src/bin/run_bsvrs.rs` | the bsv-rs runner over a corpus; `--smoke` is the tripwire's harness leg |
| `src/bin/flow_cases.rs` | `make flowcases`: the hand-written flow corpus with bsv-rs's verdicts, for the Lean machine check (archived #8) |
| `src/bin/num_vectors.rs` | `make numvectors`: bsv-rs's number type on 1,000 byte strings, for the Lean `Numbers` check (archived #7) |
| `src/bsvrs_codes.rs`, `src/bin/run_diff.rs` | the bsv-rs message → `SCRIPT_ERR_*` table and the differential of the spec against bsv-rs (archived #15) |
| `src/engines.rs`, `src/flags_oracle.rs` | the out-of-process SDK adapters over JSON lines and the flag word per input asked of the spec's own executable (archived #29) |
| `src/gosdk_codes.rs`, `src/tssdk_codes.rs`, `src/bin/run_engine.rs` | the go-sdk and ts-sdk code tables and the differential against each SDK (`make enginesdiff`; archived #29) |
| `engines/go/`, `engines/ts/` | the go-sdk adapter (a Go module pinned by `go.mod`/`go.sum`; the Go build cache is shared) and the ts-sdk adapter (`@bsv/sdk` pinned by `package.json`/`package-lock.json`; its Node is "Prerequisites" above). **The ts adapter's `node_modules` is a per-worktree install**, never committed: `make tssdk-install` (`npm ci` at the pin) in every worktree that runs the harness leg (or an APFS clone of a sibling's, as S2 did) |
| `src/svnode_codes.rs`, `src/bin/run_svnode.rs`, `oracle/` | the reversed `ScriptErrorString` table, the `verifyscript` runner against the reference, and the spec's own node instance (archived #27) |
| `rust-toolchain.toml` | the crate's Rust toolchain, pinned; `make check-pins` checks it with every other pin (archived #40) |

The SV-node runner (archived #27, `oracle/README.md`), the SDK runners (archived #29) and the GoBDK shim (archived #28, `engines/gobdk/`: Teranode's script engine, no Teranode instance) are here.

**The clean-room column** (`cleanroom/`, archived #37, 2026-10-15) stands beside the engines and is not one:
a Python evaluator written from the published specification alone (`spec/*.md`, `docs/DESIGN.md`,
`docs/PARAMETERS.md`; no implementation, no Lean, no source opened, `cleanroom/README.md`), so its
verdicts measure the DOCUMENT, never an implementation. `python3 cleanroom/run.py --all` (from the
repository root: `python3 harness/cleanroom/run.py --all`) writes `cleanroom/out/<corpus>.json` with two
columns per entry: strict (a behavior the pages do not determine is a `gap`) and assumed (every gap
`cleanroom.GAPS` gives a reading filled: the opcode names, five constants, and the readings of the
multisig loop, the shift's bit order, the vector files' limits, the finality comparison, the empty
`OP_VERIFY`'s reason, the hybrid key's parity and the shift-number operand order, each fill named per
entry). Its counts and its Findings are
`docs/records/20261015-133842-s5-37-cleanroom-s3.md`; it reads the corpus files, never this crate.

Patterns cross with a provenance header and a mechanism check (`tools/mechanism_check.sh`); no transaction of any
private program. Every engine's release is pinned once in `docs/PROVENANCE.md` §1a and checked by `make check-pins` (archived #40).

```sh
cargo build --release --locked
./target/release/seed_gen --out ../corpus/seed            # regenerate (byte-deterministic)
./target/release/run_bsvrs --corpus ../corpus/seed --smoke  # the smoke run
cargo test --release --locked
```

## Chain-layer node runner (archived #66)

`make node-scenarios ARGS="--record docs/records/20261013-041541-s6-66c-regtest-s3.md --run-id <new-id> --write"` starts only fresh owned regtest instances on loopback, records exact RPC receipts and requests stop, waits, then attempts owned-child kill/wait on failure. Drop retries kill/wait if stop fails. Normal replay and injected control failures are checked; persistent OS failures and external process termination remain outside that guarantee. The current scope is partial; [record](../docs/records/20261013-041541-s6-66c-regtest-s3.md). Run again at a pin move. Use a unique run id; existing datadirs are refused. Set `CARGO_TARGET_DIR` to a target directory dedicated to this worktree; the wrapper defaults to its `harness/target` and sets `CARGO_BUILD_JOBS=4`. `--write` changes only measured/rpc-precheck/unrealizable/needs-peer row node tokens and writes witness/observation sidecars. Datadirs remain under the run id until their recorded receipts are archived and the operator removes them.


The runner's modules under `src/scenarios/` are `core` (owned instances, RPC,
receipts, ordered status and comparison), `finality`, `utxo`, `block`, `mempool`,
`chain`, `oracle` (each family's recipes and materialization), `intake` (the
independent scenario traces), and `mod.rs` (dispatch and record writing).
`src/bin/run_scenarios.rs` only invokes the driver. Family additions belong in
the corresponding family module. The split and byte-identical verdict replay
are recorded in [s6-66c](../docs/records/20261013-041541-s6-66c-regtest-s3.md).

## 2026-10-13: S6 loopback peer contract

The row runner starts `python3 -u harness/peer/peer.py --receipt <owned-datadir>/peer.jsonl`
for each peer row, after launching a fresh node with `listen=1` and
`bind=127.0.0.1:<reserved-P2P-port>`. RPC/P2P pairs remain in 18571 to 18590.
`whitelist` stays unset; discovery, DNS seeds and UPnP stay disabled.

The driver imports the reference test framework from `BSV_PEER_FRAMEWORK`
or `--framework`, default the reference clone's `test/functional` in the maintainers' layout. It checks clone
HEAD against `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, requires the canonical
`test/functional` root, and requires clean `git status --porcelain` for the
framework tree with untracked files included. Since 2026-10-13, every imported
framework module's resolved `__file__` must lie under that clone's
`test/functional/test_framework`, with bytes equal to its pinned Git blob;
certification precedes receipt creation and connection. Nothing is vendored. The reference's
`test/functional/test_framework/mininode.py:48,2118-2690` at that pin supplies
version 70016, the message classes, callback and regtest transport.

Stdin/stdout use one JSON object per line: `connect` (host fixed to
127.0.0.1, `port`), `send_tx`/`send_block` (`hex`), `send_headers` (`hex` array),
`send_inv` (`kind`: tx/block, `hash`), `withhold`/`release` (`hash`),
`expect` (`kind`: getdata/inv/reject/none, `hash`, `since` event index,
`timeout` seconds up to 20), and `close`. Each command uses an `op` key.
Replies carry `ok`, `result` or `error`, `source_pin`, new `events` and
`next_index`. A failed expectation is an observation with `matched=false`;
a process/protocol failure stops the runner. Every step and P2P message is
logged with UTC and pin, and copied into the durable row receipt. `none`
means no matching inv/getdata/reject within the bounded window. Withholding
suppresses automatic getdata responses; release permits stored responses.
The runner sends an absent parent explicitly once when releasing it. The
reference ping/pong fence orders prior messages; the node activity count
then observes validation completion. `waitforptvcompletion` is used only
after the isolated orphan has left the pool. The named invalid-transaction
probes use `banscore=100000`, following the reference orphan test
(`test/functional/bsv-accept_max_sized_orphan.py:49-51` and
`src/init.cpp:2703-2705` at the pin); this is a policy setting, with no whitelist.

Replay the 20 peer rows and retain all other column receipts:
`tools/node_scenarios.sh --record docs/records/<UTC-stamp>-s6-peer-66-regtest-s3.md --run-id s6-peer-66-<UTC-stamp> --peer-only --write`.
`--peer-row <id>` restricts diagnostic replay. The ordinary full runner also
executes these recipes. Each completed row is checkpointed even if a later
row fails. The runner reaps peers and owned nodes on completion/error;
this instrument does not define S7's wire machine.


2026-10-13: the [20-row peer receipt](../docs/records/20261013-152446-s6-peer-66-regtest-s3.md) records the pinned executable framework, per-row steps, tokens and walls. Its run uses a fresh instance per row; no framework code is copied.

2026-10-13 (the [fix-peer receipt](../docs/records/20261013-181932-s6-fix-peer-regtest-s3.md)): the driver certifies the canonical imported framework sources before receipt creation or connection, including each module origin and pinned blob bytes, and refuses tracked or untracked changes in the framework directory. The peer tests cover wrong pin, noncanonical root, untracked source, imported origin and unsafe endpoint refusals. Era crossing receipts now judge the automatic child admission with declared fees, and aggregate retention judges bytes/count/set size independently of salted survivor identity.

2026-10-13: the [fix-peer receipt](../docs/records/20261013-181932-s6-fix-peer-regtest-s3.md) composes 20 fresh peer rows, 17 agree and three scoped walls, with source hashes, the corrected Finding, explicit eviction invariants, judged era child admission and all verification verdicts.

2026-10-13 (the [one-peer receipt](../docs/records/20261013-192835-s6-one-peer-regtest-s3.md)): `--one-peer-only` replays `chain-receipt-order`
and `chain-precious`, including receipt-order's reversed-body control, through
`peer.py` and the existing `send_headers` step. Use
`tools/node_scenarios.sh --record docs/records/<UTC-stamp>-s6-one-peer-regtest-s3.md --run-id s6-one-peer-<UTC-stamp> --one-peer-only --write`.
The full receipt stays in the fresh run directory; `receipt_trim.py` writes the
projection below 10 MB to `docs/records`, recording the full receipt's SHA256
and size. Other row tokens keep their recorded measurements.

2026-10-13 (the [reclass receipt](../docs/records/20261013-200620-s6-reclass-66b-regtest-s3.md)): `--reclass-only` replays the eleven mempool
rows whose limited request (fUseLimits, priority, pending queue) exists only in
the asynchronous validator, each on a fresh instance through `peer.py`'s
`send_tx` step. Use
`tools/node_scenarios.sh --record docs/records/<UTC-stamp>-s6-reclass-66b-regtest-s3.md --run-id s6-reclass-66b-<UTC-stamp> --reclass-only --write`.
Intermediate queue states are read between validator cycles
(`txnvalidationasynchrunfreq=5000`) after the pin's own log markers. A row
whose outcome is a budget expiry carries `measured non-judging: ...` (archived #71):
the observation is recorded, never judged. Full and trimmed receipts follow
the one-peer rule above.

2026-10-14 (archived #71): `--rejects-only` replays the rows of
`corpus/chain/mempool/mempool.jsonl` whose `action` is `p2pTrace`, each on a
fresh instance through `peer.py`; the recipes are `src/scenarios/rejects.rs`.
A row lists ordered steps: `inv` (one inventory announcement), `tx` (one
delivery), `rpc` (`sendrawtransaction`), `mine` (an empty block) and
`invalidate` (back to a named tip). Every frame is withheld, so the peer
answers no getdata by itself and each delivery is a declared step. The runner
reads one answer word per step, the words the spec's trace prints (`traceRow`
in `lean/Test/MempoolCheck.lean`): `request` or `silence` for an inventory (a
getdata for the txid inside the window, or none; silence means no matching
getdata in the measured 2 s window, a bounded absence observation, not a
measured guarantee of indefinite suppression, and late delivery remains outside
this observation; the agreement of a `silence` step is with this projection), and for a delivery the
reject message's code and reason, else the pool that holds it, else
`suppressed` when the node logged no validation of it. Each inventory step
names the tip label it observes; the runner checks the label against
`getbestblockhash`. Use
`tools/node_scenarios.sh --record docs/records/<UTC-stamp>-s6-71-regtest-s3.md --run-id s6-71-<UTC-stamp> --rejects-only --write`.
The ordinary full runner also executes these rows. Full and trimmed receipts
follow the one-peer rule above.

2026-10-14 (archived #71), the rule for time-budget cells, stated once: an
observation whose outcome depends on the node's validation clock is recorded
and never judged. Its token is `measured non-judging: <observation> [<reason>]`;
the reason names the clock (`src/txn_validation_config.h:36-37`,
`src/init.cpp:2890-2895`, `src/validation.cpp:990-1006` at the pin), the launch
options that set the budget, and whether an expiry was observed in the run.
It counts as neither agreement nor divergence (`non-judging` in the family
counts). The spec's side stays deterministic: the elapsed time is an explicit
input of the row (`elapsedHigh`, `elapsedLow`, microseconds), and a step's
judgment is its clock dependence, not its budget's value (fix-71,
2026-10-14): `BsvChain.budgetJudgment` of `ClockDependence` marks a limited
validation whose outcome the firing of some poll would change non-judging,
on an available budget as on an expired one, and `traceRow` lists those steps
in `nonJudging` (the ample trace's step 0 among them); an unlimited
validation, or one whose outcome no poll changes, is judged. A row whose budget
observation is ignored (no limits), or whose outcome the pin reaches without a
clock, is judged, with a qualifier that says so. The spec's `nonJudging` of
`rejects-commit-refusal-not-remembered` lists step 1 (the update is a limited
validation that reaches the script polls before the commit refuses it); its
whole-row node token is `measured non-judging`, with the full trace match
retained as `projection_verdict`. Nonempty step classifications exclude the row
from agreement/divergence totals; step reasons survive recipe regeneration. As measured on 2026-10-14, the budget cells of the
mempool corpus: `script-budget-high-relay`, `script-budget-high-block`,
`script-budget-low-invalid`, `rejects-budget-low-timeout-remembered` and
`rejects-budget-ample-accepted` and `rejects-commit-refusal-not-remembered` are non-judging; `inputs-budget-downgrade` and
`inputs-budget-observation-ignored-without-limits` are judged on a clock-free
path; `outer-mandatory-budget-low-invalid` is unrealizable (the record of that run is withheld from the public
edition under the node team's discretion, group `o2-attribution` of `tools/export_withheld.txt`).

## 2026-10-13: S6 harness realism contract (archived #72)

Under the maintainers' ruling on card H1 (`S6 go on`); the receipt of record is
[20261014-032012-s6-72-regtest-s3](../docs/records/20261014-032012-s6-72-regtest-s3.md). The node's
choices and the node's clock are observed, never predicted. Sources are
bitcoin-sv `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.

**Observed blocks.** Block assembly is the node's choice:
`generatetoaddress` returns hashes only (`src/rpc/mining.cpp:161-224`), and the
template is the transactions of the assembler's journal
(`src/mining/journaling_block_assembler.cpp:80-97`). The fee test uses grouped
fees plus fee deltas; a paying descendant group can promote low-fee ancestors
and add every group member to the journal
(`src/txmempool.cpp:369-407,411-438,574-600`). In the isolated scenario,
independent L has no paying descendant and no fee delta, so it stays secondary.
The runner records assembly as follows:

- every node-assembled block goes through `Node::mine` (`src/scenarios/core.rs`):
  it reads the chain's transaction count before and after
  (`getchaintxstats` `txcount`, `src/rpc/blockchain.cpp:3054-3155`), reads every
  new body (`getblock`) when the blocks hold more than their coinbases, and
  writes an `assembly` event (blocks, transactions, `coinbase_only`, the
  observed bodies) into the receipt. No recipe calls `generatetoaddress` itself.
- a recipe that needs a body reads it with `Node::body`. A row whose expected
  projection was computed on a named body is judged only when the node's
  observed body is that body (`assembly_differs`); otherwise the row is
  `measured non-judging` with both bodies in its token. Converted from a
  prediction: chain's `readmit` and `invalidate-reconsider` recipe, mempool's
  rolling-fee block gate and empty-trim history block, and the status views'
  `minedActive` and `onStaleBranch` rows (before, the chain and mempool
  recipes stopped the run when the assembler chose another body, and the
  status views judged the body they predicted).
- an intake `mine` step without `"method": "submitblock"` names the observed
  body; under `--write` the runner writes it into the step's `transactions`
  with an `assembly` line, so `transactions` is the observed block and the
  machine's replay (`chaincheck --scenarios`) is applied to exactly that body.
  The step is judged when the observed body equals the body its expectation was
  computed on and the pool after the block is the pool before it less that
  body; from a differing body on, the trace's steps are recorded, never judged.
  A block the harness builds is submitted with `submitblock` and stays the
  harness's declared body.

**The one clock.** `GetTime` returns the mock time once `setmocktime` sets it
(`src/utiltime.cpp:23-33`; `src/rpc/misc.cpp:980-1007`). Every fresh instance
is set to `START_CLOCK` (1699990000) before any step, a relaunch sets the
instance's last mock time again (a restart clears it), and `mine`, `submit`
and the recipes' `setmocktime` steps are the only clock moves. Before this
contract the node read the host clock from launch to a recipe's initial mining call and
from every restart to the next clock step; the peer advertised the host clock
(`time.time()`, `test_framework/mininode.py:1183`), and the status views' peer
a constant. The runner's own clock reads are receipt metadata only: the
default run id, measured wall seconds, timeouts and UTC stamps.

**The zero offset.** Adjusted time is `GetTime` plus `nTimeOffset`
(`src/timedata.cpp:28-35`); a peer's version time minus `GetTime` is its sample
(`src/net/net_processing.cpp:1896-1898`), and the offset moves only after five
samples (`src/timedata.cpp:74-82`). `peer.py`'s `connect` requires `time`, the
scenario's mock time, and writes it into the version message; the runner then
reads each peer's sample (`getpeerinfo` `timeoffset`, `src/rpc/net.cpp:229`)
and the node's offset (`getnetworkinfo` `timeoffset`, `src/rpc/net.cpp:626`)
into a `peer-clock` event; every instance start and relaunch writes a `clock`
event with the offset.

**Non-judging.** A row or intake step whose receipt names an offset or peer
sample other than zero is `measured non-judging` (`offset_uncontrolled`, applied
in `mod.rs` and the intake runner); so is an intake step at or after a body
that differs from its expectation's body, and, as before, an outcome under the
validation time budget (archived #71). Clock reads the RPC cannot set (the leaky bucket's
`system_clock`) keep their unrealizable tokens.
