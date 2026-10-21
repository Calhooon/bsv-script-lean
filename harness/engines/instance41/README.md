# Issue 41 instance

Teranode v0.16.0 at `4edb60a40c6628ff0ef60231c2628efd7103fde5` (the owner's
pin of 2026-10-05), built on `box` with Go 1.27.0 and cgo by the recipe in
tracker comment 5851887160; binary SHA-256
`dedd0003386ac5ee7969ab1beaab9db91b0291baf70e066717a3c8e85b3f9ee8`. Sitting 1
built v0.15.9 by the same recipe (its receipt below). The source
(`src-v0.16.0`), binary, logs and chain data live under
`~/bsv/targets/spec-teranode`, outside this repository.

| Artifact | Purpose |
|---|---|
| [instance.py](instance.py) | Start, inspect, call local RPC and stop the recorded binary |
| [settings_local.conf](settings_local.conf) | Test context overrides for local execution |
| [road.py](road.py) | JSON-lines worker of the recipe: the running instance's attestation and the disk headroom; since #97 it reads nothing of the node (2026-10-15) |
| [native/](native/) | The gRPC transport of the observation contract (`../teranode/contract.rs`, #97): the validator's `ValidateTransaction` and the blockchain service's reads (`build.py`, `main.go`; `INSTANCE41_NATIVE_DIR` puts the build elsewhere) |
| [Build receipt, v0.15.9](../../../docs/records/20261005-212527-instance41-build.md) | Sitting 1: commands, hashes, observations |
| [Build record, v0.16.0](../../../docs/records/20261006-000348-instance41-build-v0160.md) | Sitting 3's build of the judged binary: tag, Go, module downloads, hashes, wall |
| [recount.py](recount.py) | Re-derives a run's counts from its unchanged answers journals under the adapter's error mapping; re-cuts the manifests |
| [seed_chunk.zsh](seed_chunk.zsh) | One foreground chunk of a corpus run: both locks, start, adapter, stop, releases in the EXIT trap |
| [runs/](runs/) | The run manifests (answers, funding and RPC journals stay under `~/bsv/targets/spec-teranode/runs`) |
| [Seed record, v0.16.0](../../../docs/records/20261005-234745-instance41-seed.md) | Sitting 4: the seed run at v0.16.0, its counts |
| [Corpora record, v0.16.0](../../../docs/records/20261006-013805-instance41-corpora.md) | Sitting 6: flow, arith, stack, crypto, bytes, eras, gen, tx and road by era; the conformance column's source |

Use Python 3.11 or later. The script requires the recipe build at
`~/bsv/targets/spec-teranode/src-v0.16.0/teranode.run`. It checks the source
HEAD and the binary SHA-256 above. Run the sitting under the box's
leg lock and Lean slot when it will use many cores for over a minute.

```sh
python3 harness/engines/instance41/instance.py start
python3 harness/engines/instance41/instance.py rpc getblockchaininfo
python3 harness/engines/instance41/instance.py status
python3 harness/engines/instance41/instance.py stop
```

The alert recipe (lane hz-94s, #94's store half) adds `--alert` (it
combines with `--legacy`): the alert service runs, with its own libp2p
listener on `0.0.0.0:9908` (`[SRC]` at the pin: `services/alert/server.go`
loadConfig binds the wildcard; `settings.go:209` the `ALERT_P2P_PORT`
default 9908). It requires `alert_genesis_keys` in the data directory's
`overlay.conf` (the server answers `ErrNoGenesisKeys` without it) and
`alert_p2p_allow_private_ips = true` when a loopback peer dials it; the
listener check allows exactly that one wildcard bind (lsof prints it as
`*:9908`, normalized to the canonical form before the check).

An RPC parameter array is an optional argument after the method. The script
uses `http://127.0.0.1:9292` and the tag's `bitcoin` / `bitcoin` test credentials
(`[SRC] settings.conf:1273-1280` at the pin). Stop the instance before ending
the sitting. `status` reports whether its saved process is still running;
`stop` checks the PID's executable and start time before sending SIGTERM,
and never signals a PID whose saved state it has just found gone. `start`
puts its cleanup guard in place before it launches the node: SIGINT and
SIGTERM are noted until the child and its saved state exist, then raised
inside the guard. Data persists between runs.

The script copies the recorded binary and tagged defaults beside the local
settings in `data/runtime`. That placement matters: the pinned config loader
searches beside the executable before the working directory (`[SRC]`
Teranode `go.mod:41`, gocore v1.1.0 `config.go:140-175,223-312`). A clean
environment prevents inherited configuration and HTTP proxies overriding the
run. The services follow `daemon/test_daemon.go:518-529` at the Teranode pin;
`-all=0`, `-p2p=0`, `-alert=0` and `-legacy=0` keep other services off
(`[SRC] daemon/daemon.go:577-600`). Startup checks load below 20, disk free
space at least 12 GiB, a regtest RPC answer and all eleven active listeners
on `127.0.0.1`. Go has four runtime workers and a 6 GiB GC memory target
(`[EST]` execution budget).

The recipe omits two execution settings used by the tagged test daemon:
`LocalTestStartFromState = "RUNNING"` (`[SRC] daemon/test_daemon.go:428`;
`services/blockchain/Server.go:402-410`) and `Asset.CentrifugeDisable = true`
(`daemon/test_daemon.go:426`). The companion settings supply both.
Without the RUNNING setting, RPC answers while subtree validation and propagation wait in
`IDLE` (`[SRC] services/subtreevalidation/Server.go:554-559`). No upstream
source is changed. The asset subscription server needs the disabled p2p
websocket; the data HTTP service stays enabled.

Sitting 1's seed submission was an RPC rejection while decorating an unfunded
parent (at v0.15.9); it established no script verdict. The road below funds
the parents beforehand. The conformance column (#30) is not written here.

## Funding and instance adapter

`harness/src/bin/run_teranode.rs` reads a corpus directory and verifies its
manifest's count and SHA-256. Cargo discovers this binary without a new
`Cargo.toml` entry. It writes a separate run directory; the corpus and its
recorded reference verdicts stay unchanged.

Run these commands under the box leg lock and a Lean slot, with
`CARGO_BUILD_JOBS=4` and the lane's `CARGO_TARGET_DIR`:

```sh
python3 harness/engines/instance41/native/build.py
cargo build --release --locked --offline --manifest-path harness/Cargo.toml --bin run_teranode
python3 harness/engines/instance41/instance.py start --validator
"$CARGO_TARGET_DIR/release/run_teranode" --corpus corpus/seed \
  --out ~/bsv/targets/spec-teranode/runs/<UTC-stamp>-seed
python3 harness/engines/instance41/instance.py stop
```

`--plan-only` checks the input and lists excluded entry ids without contacting
the node. `--limit N` makes a smaller run in a new output directory, and
`--from N` skips N corpus lines from the start. `INSTANCE41_DATA=<directory>` puts `instance.py` and the adapter on another chain (a fresh one for the Genesis-to-Chronicle era); the chunk script takes `CORPUS` and `MANIFEST` for a corpus other than the seed. A run longer than one foreground
command goes in chunks, each under both locks with the instance started and
stopped around it:

```sh
zsh -f harness/engines/instance41/seed_chunk.zsh <FROM> <COUNT> ~/bsv/targets/spec-teranode/runs/<UTC-stamp>-seed
```

The chunk script waits for a 1-minute load under 20 and for the instance's
ports to be free (a stopped node's loopback ports stay bound for some seconds).
Since #97 (lane trait-97, 2026-10-15) the adapter and the scenario client read the
node only through the observation contract, `harness/engines/teranode/contract.rs`
(docs/CONFORMANCE-TERANODE-OBSERVATION.md section 6; the chunk script's console tip line and
`instance.py`'s readiness poll call the RPC directly and judge nothing): its one implementation owns
the RPC, the asset HTTP and the native client, and journals every call with its
surface and handler. The native
client builds outside this repository against the existing tagged source and
module cache, with `GOPROXY=off`; it does not execute a script engine. [M] At
the default path (`~/bsv/targets/spec-teranode/native-client/client`) the box's
build of 2026-10-15 (Go 1.27.0) has sha256
`6bd3536ca88028aa4c2338d558b6c5cf714054d609367ba2f5f7d3fd1ae7c251`; the sum
depends on the build directory, so a build under `INSTANCE41_NATIVE_DIR` differs
(`docs/records/20261015-233751-s8-97-contract-check4-s4b.md`). The Teranode
column script (`../teranode/column.zsh`) checks this file and this sum before
it takes a lock, and stops with exit 2 otherwise. The
instance's own validator service runs on `127.0.0.1:8081` (gRPC) and
`127.0.0.1:8834` (HTTP) when `--validator` is selected (`[SRC]` at the instance
pin: `daemon/daemon_services.go:967-975,1048-1057`, `services/validator/Server.go:478-487`).
The usual listeners stay local. The blockchain service's gRPC listener is
`127.0.0.1:8087` (`settings.conf:91,428-434` at the pin), always on.

The funding road mines 101 blocks to a deterministic public test key and
spends a mature coinbase into a reservoir of P2PKH outputs. Each entry gets
an isolated funding transaction with two copies of its prevouts, preserving
their locking scripts and values. The copies give the two paths distinct
inputs because an accepted submission spends its inputs (`[SRC]`
`services/validator/Validator.go:1105`). Funding rejections are `unfundable`,
with the node's complete answer; they are never compared as verdicts.
Confirmed funding is checked through the contract's `tx_record` (the asset
route `/txmeta/:hash/json`) for the block height, scripts and values (`[SRC]`
`services/asset/httpimpl/http.go:340`, `GetTransactionMeta.go:94-238`).
Block assembly takes submissions into subtrees asynchronously, and a block
generated before it has them is empty: the road waits until
`getminingcandidate` counts the pending transactions before it mines
(`handlers.go:1104-1172`). The tip is the contract's `tip`, gRPC
`GetBestBlockHeader` with `GetBestHeightAndTime` (`services/blockchain/Server.go:1679,3210`);
the candidate's parent median time is the latter's `time`, the median of the tip's
last 11 timestamps with the tip included, the value the RPC's `mediantime` gives
(`handlers.go:1590-1622`). The header's own `median_time_past` is the median of the
11 blocks before it (`stores/blockchain/sql/StoreBlock.go:739-740,1148-1160`), one
block behind; the adapter never passes it as the parent's.
The reservoir's change is saved outside the repository in
`data/instance41-well.json` so a later run can reuse it after regtest's subsidy
has ended. These funds and submissions live only on this private chain.

| Corpus era | Instance funding height | Instance spend height |
|---|---|---|
| pre-Genesis | none: `undecided` | none |
| Genesis to Chronicle | next available height, 100 through 198 | Funding height + 1, at most 199 |
| post-Chronicle | 200 or a later height | Funding height + 1 |

The regtest heights come from go-chaincfg v1.6.2, which the pin's `go.mod:15`
requires: `params.go:463` (coinbase maturity 100), `475-476` (Genesis 100,
Chronicle 200). No coinbase output matures below height 101, so no
pre-Genesis output can be funded on this chain and pre-Genesis rows are
`undecided` by name. The adapter bakes forward using `generatetoaddress` in
batches of at most 100 blocks (`[SRC]`
`services/rpc/handlers.go:1031-1071,2983-3026`). An existing
chain past an earlier era cannot serve that era; use a separately prepared
fresh chain for it. The seed needs only post-Chronicle funding and spending.
Mixed prevout/spend eras need a broader funding plan and are currently
`undecided`. Absolute locktime, sequence, CLTV and CSV rows are named
`undecided` as required by tracker comment 5853443740. Signature-dependent
rows are also `undecided` because rebinding synthetic outpoints can change
their signature digests. No witness signature is rewritten.

The mempool answer comes from `sendrawtransaction`. The block-context answer
comes from the node's `ValidatorAPI.ValidateTransaction`, with
`SkipPolicyChecks=true`, `InBlock=true`, the actual next block height and its
parent's MTP. This is the validator path used by subtree block validation
(`[SRC]` `services/subtreevalidation/check_block_subtrees.go:1278-1291`),
with `UnconfirmedParentsAtCandidateHeight=true` as that path sets it;
`SkipScriptValidation` and `OutpointOnlySpend` are explicitly false
(`validator_api.proto:62-82`). It reads the funded parents, all mined, from
the node's store. Accepted submissions go to block assembly
and are mined at the end of the group. Full block-wrapper validation of a
rejected spend is not inferred: `submitblock` is unimplemented at the pin
(`[SRC]` `services/rpc/Server.go:211`). The manifest states this boundary.

Each output directory contains `answers.jsonl` (one row per entry and path),
`funding.jsonl`, the request/answer journal `rpc.jsonl`, `witnesses.jsonl`
(every disagreement, with the entry id, both verdicts and submitted bytes),
and `manifest.json`. The header includes the instance tag, source commit,
binary SHA-256, settings hash and its definition, host, client hash, actual
chain tips, era mapping and counts per path. The manifest names every
`unfundable` and `undecided` row. Witnesses remain unclassified; the parent's
classifier data is not changed. Disk headroom is checked throughout the
road, with a stop below 12 GiB free. A funding or transport wall stops further
submissions and leaves all unfinished rows `undecided` with the wall recorded.
