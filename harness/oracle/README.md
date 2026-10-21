# harness/oracle: the spec's own SV-node instance and the `verifyscript` runner (#27)

**The judge that outranks every engine.** The reference is bitcoin-sv v1.2.3 at `6504a3aff`
(`docs/PROVENANCE.md` §1a). Its `verifyscript` RPC (`src/rpc/misc.cpp:506–914`) evaluates one input of a
transaction under an explicit flag word with the prevout given inline (`txo{lock, value, height}`), touching
no chain state, so for the script corpora a private regtest instance with an EMPTY chain is the whole oracle
(the `local` and `mini` instances: nothing is mined there); the `block` instance of the `tx.*` road (D97) holds a
chain the harness bakes (`oracle_chain bake`) and the road extends, and `spec-node.sh block adopt-into-policy`
copies it into the `policy` instance's datadir. Nothing is relayed and no peer exists (CLAUDE.md rule 10). The runner is `harness/src/bin/run_svnode.rs`; the
instance's configuration is `bitcoin.conf` here, every line cited; `spec-node.sh` starts it in two homes.

## The instance

| | `local` (the CONSENSUS instance, the harness's CONSENSUS INSTRUMENT, D123; with the policy instance below, the instance the recorded runs used: `verifyscript` never runs the standardness gate, so its consensus-level verdict comes from the zeroed caps and the explicit flag word, and `acceptnonstdtxn=1` plays no part in it) | `mini` (the always-on host; the consensus instance only, no policy instance) |
|---|---|---|
| binary | `$BSV_SPEC_REFERENCE_BINARY`, the maintainers' build of the pin (`-version` = `v1.2.3.0-g6504a3aff-dev`, checked by `make check-pins`) | historical v1.2.2 bundle at `~/bsv/oracle/bin`; not moved or used by #57, whose recordings use the box at an explicit v1.2.3 path |
| datadir | `~/bsv/targets/spec-oracle-data` | `~/bsv/spec-oracle/data` on the host |
| RPC / P2P | `127.0.0.1:18563` / 18564 (`listen=0`) | `127.0.0.1:18563` / 18564 on the host; the Studio reaches it through `spec-node.sh mini tunnel` on `127.0.0.1:18663` and fetches the cookie with `spec-node.sh mini cookie` |
| lifetime | `spec-node.sh local start|stop|status|cli|reset` | the spec's own LaunchAgent `com.bsvspec.oracle` (`spec-node.sh mini install|start|stop|status|uninstall`) |

**The second instance, `policy` (2026-09-24, #27's record run).** The same binary on `bitcoin-policy.conf` (the policy
caps at the node's DEFAULTS instead of zeroed), datadir `~/bsv/targets/spec-oracle-policy-data`, RPC `127.0.0.1:18565`,
P2P 18566 (`spec-node.sh policy start|stop|status|cli|reset`). Why two: `verifyscript` evaluates on the policy path
(consensus = false, Q6 below), so ONE instance can apply either the consensus limits (zeroed caps: the spec's `spec`
column) or the node's default mempool limits (the spec's `spec-mempool` column, `Params.derive` with consensus = false),
never both. D123 (the owner's ruling of 2026-09-27, through the plan): this instance runs at the node's DEFAULT, `requireStandard` true as on mainnet, so the `spec-mempool` column is what a default node's mempool accepts. `bitcoin-policy.conf` reads `acceptnonstdtxn=0` since D123's harness half (the parent, 2026-09-27, `docs/records/20260927-231608-d123-road-s3.md`): the tx road's mempool column re-run at the default, where four pre-Genesis rows meet the node's standardness (the class `tx.gate.standardness.unmodelled`). Every size-bound `tx.*` row names the instance that produced it. The first entry that told them apart was eras-00042 (a 1,048,577-byte number on a post-Chronicle coin: within
32,000,000 at consensus, over the 10,000 policy width): on the zeroed instance the mempool column said valid, the spec
SCRIPT_ERR_SCRIPTNUM_OVERFLOW, a difference of configuration and not of semantics. `run_svnode --rpc-mempool
http://127.0.0.1:18565` sends the mempool column to this instance; the runner checks its version string, probes its
activation heights and its number width (a minimal 10,000-byte number accepted, a 10,001-byte one refused with `Script
number overflow`; both accepted on the consensus instance) and records its caps beside the verdicts. A read worth knowing:
`getsettings` evaluates `maxscriptnumlengthpolicy` at the era of the instance's chain tip, not the configured post-Genesis
value (4 at a pre-Genesis tip; the adopted policy instance prints 10,000), which is why the width is probed and never read back. The mini holds the consensus instance only; a policy instance there
is the record run's next step when the mini is used for it.

**The log (2026-09-28, the owner's plan's continue 25: the Studio's disk).** Every conf sets `debug=0`, `printtoconsole=1` and `shrinkdebugfile=1`, and `spec-node.sh` sends the node's console to `/dev/null` (stderr kept in `<datadir>/bitcoind.err`): no `regtest/bitcoind.log` grows (at the pin the file's name is fixed, `logging.cpp:13`, and there is no `-debuglogfile`). Package B's road had written 740 MB of it on the block and policy instances in 40 minutes. The verdicts come from the RPC replies; a start that fails says why in `bitcoind.err`. An instance whose leg has ended is stopped (`spec-node.sh <mode> stop`); on the mini the LaunchAgent's own `StandardOutPath` receives the console instead.

**Two ideas in `bitcoin.conf`.** (1) The activation heights are MAINNET's (`genesisactivationheight=620538`,
`chronicleactivationheight=943816`; `chainparams.cpp:18, 23`), so a corpus prevout's `txo.height` selects the
UTXO era the spec assigns to that height (`misc.cpp:813–822` re-derives the two era bits from the height under
the node's own heights and overrides them in the given word); the runner passes `reportflags: true` and refuses
a run where the node's applied word differs from the spec's. (2) Every policy setting is zeroed: `verifyscript`
hard-codes `consensus = false` (`:855–856`), so the interpreter's limits come from the policy getters
(`interpreter.cpp:2282–2302` → `configscriptpolicy.cpp:65–154`), and each setter maps 0 to the era's consensus
maximum (`configscriptpolicy.cpp:164–308`).

## Q6, answered from source (`docs/DESIGN.md` §9)

*Is "the consensus limits via zeroed policy settings" the same object as the reference's consensus path?*
At the pin, `consensus` is read by the interpreter in exactly two functions, `make_eval_script_params` and
`make_verify_script_params` (`interpreter.cpp:2282–2302`; the grep of `interpreter.cpp` for `consensus` finds
no other read), which pass it to the five getters of `ConfigScriptPolicy` (`configscriptpolicy.cpp:65–154`):
when `consensus` is true four of them return the compiled consensus constant and `GetMaxStackMemoryUsage`
returns the CONFIGURED consensus value (`:150`: an operator setting, `maxstackmemoryusageconsensus=0` here, which
its setter stores as `INT64_MAX`, `:280–282`, `consensus.h:82`); when it is false each returns the configured
policy value. A policy value configured 0 is stored as the consensus maximum by the ops, script-size,
multisig-key and stack-memory setters (`:182`, `:232`, `:259`, `:291`), while the number-length setter stores
the 0 itself (`:211`) and its getter resolves it per era (`:97–106`). So here both branches return the same
number for every limit. Nothing
else in `EvalScript`/`VerifyScript` depends on the switch. **So the RPC evaluates under the consensus LIMITS on
the policy PATH, and the two paths differ in nothing the interpreter reads**: for the script semantics this
instance is the consensus path. What it is NOT: the mempool's standardness gate and the block-connection wrapper
(`validation.cpp`, outside `CScriptCheck`), which the spec scopes out (DESIGN §5.5). The pinned wall: a script
is cancelled after `maxstdtxvalidationduration` (`:867–873`; five minutes here) and the call after the runner's
`totalTimeout` (60,000 ms by default; the argument parsed at `:614–626`, 100 ms when the call omits it): a `timeout` or `skipped` result is `undecided`, never a verdict.

## The runner

```sh
harness/oracle/spec-node.sh local start
eval/bsvs corpus corpus/flow/flow.jsonl --out lean/.lake/spec-flow-flow.jsonl
cd harness && cargo run --release --locked --bin run_svnode -- --corpus ../corpus/flow/flow.jsonl \
    --spec ../lean/.lake/spec-flow-flow.jsonl [--record | --limit N]
# --limit N writes its witnesses to a scratch directory; with --witnesses ../corpus/witnesses it is refused (#32 P13)
# the mini: spec-node.sh mini install (once), mini tunnel, mini cookie, then
#   --rpc http://127.0.0.1:18663 --cookie ~/bsv/targets/spec-oracle-mini/regtest/.cookie
```

One `verifyscript` call per entry and column, one element per input, the word per input the spec's own
(`harness/src/flags_oracle.rs`), `stopOnFirstInvalid` explicit (its help says the default is true, `:565`;
the code makes it false, `:606–612`: rule 15, recorded here), `totalTimeout` pinned. Two columns as for the SDK
engines: `spec` (the block word of the entry's own params) and `spec-mempool` (the relay word). The node's
`description` is mapped back to `SCRIPT_ERR_*` by `harness/src/svnode_codes.rs` (the reversed
`ScriptErrorString`, `script_error.cpp:9–116`). **The verifyscript mode has no rule table** (the tx mode, `--mode tx`,
loads `harness/rules/sv-node.json` and files divergences under its named classes): a divergence between the spec and
the reference is unexplained and RED, a witness under `corpus/witnesses/sv-node/` with `ruling: open` and
the instruction to read the source (CLAUDE.md rule 4); an entry the spec marks `undefined-in-reference` would be
reported with the node's verdict beside the spec's and never counted. The reading of record at v1.2.3 is a defined refusal ([SRC] `int_serialization.h:61–118`, `script_num.cpp:80–91` at `6504a3af`); the previous pin's reading and its measurements are recorded in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`). The verdicts are recorded (`--record`) as `sv-node@v1.2.3` and `sv-node-mempool@v1.2.3`.
The version the node reports and its settings are checked before the first entry.
