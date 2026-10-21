# harness/engines/gobdk: the GoBDK shim (#28, the ruling D14)

Teranode v0.16.0 validates scripts only through GoBDK, the module
`github.com/bitcoin-sv/bdk/module/gobdk` at `4eab3acd` (`git show v0.16.0:go.mod`, line 12; re-pinned by #54 on
2026-10-06 from v0.15.9's `cdfa7814`), whose prebuilt
`libGoBDK_<os>_<arch>.a` is bitcoin-sv v1.2.2 at `879fc8b42` compiled in (`docs/PROVENANCE.md` §1). This shim is
the script verdict's road for the Teranode column (D14): a Go program that links that library through cgo and calls
GoBDK's own `TxValidator.VerifyScriptWithCustomFlags(extendedTX, utxoHeights, blockHeight, consensus, flags)`
(`module/gobdk/script/txvalidator.go:120` at `4eab3acd`) once per run, under the flag word the spec judged each input
under. No Teranode instance is involved (that is #41, a dated second leg); nothing of Teranode's wrapper is called.

| file | what |
|---|---|
| `main.go` | the adapter (an error of GoBDK's ABI domain, new at `4eab3acd`, is `undecided` as `gobdk-unknown-error`, never a verdict): JSON lines on stdin and stdout, the protocol of `harness/engines/go/main.go` plus the heights and the `consensus` boolean per run; the extended transaction (`core/extendedTx.hpp:99–108`); the verdict; `--version`, `--describe`, `--selftest`; two DERIVED modes the driver never sends, under GoBDK's own words (`CalculateFlags`, echoed): `gobdk-verify` (`VerifyScript`) and `gobdk-validate` (`ValidateTransaction`, the call Teranode makes, `ScriptVerifierGoBDK.go:297`) |
| `codes.go` | the cited code table: GoBDK's own codes (the script domain is the reference's `ScriptError_t` ordinal; the DoS domain; the exception domain) to the reference's `SCRIPT_ERR_*` names; `--selftest` checks every row against the linked library's own text |
| `go.mod`, `go.sum` | the module pinned at Teranode v0.16.0's pseudo-version, with Teranode's two sums (`git show v0.16.0:go.sum`, lines 108–109) |
| `build.sh` | the build from the local clone at the pin, never the network (below) |
| `modal_teranode.py` | a ROW, never a leg: the shim built and run inside the official Teranode x86-64 image (`ghcr.io/bsv-blockchain/teranode`, v0.15.9's amd64 manifest pinned by digest: a row at the old pin, not re-run at v0.16.0 by #54) on Modal; the binary's build info and the module's h1 sum compared; the machine code of the archive's `script_num.cpp.o` and `interpreter.cpp.o` compared with the image's `teranode.run` byte for byte, relocations masked; the requests' responses (#32's F1, 2026-09-29) |

## Build

    harness/engines/gobdk/build.sh        # -> harness/target/engines/gobdk-runner
    GOBDK_CLONE=~/bsv/targets/spec-54/bdk harness/engines/gobdk/build.sh   # a clone elsewhere (the box, #54)

The script checks, in order: the clone `gobdk.clone` of `docs/PROVENANCE.md` §1a is at `gobdk.commit` with
`module/gobdk` clean; the prebuilt archives (three at `4eab3acd`: darwin_arm64, linux_aarch64, linux_x86_64; four at `cdfa7814`) are the commit's blobs; the clone's `module/gobdk` hashes to the two
`go.sum` sums (the Go module zip's dirhash, computed from the commit's blobs), so the directory built is byte for byte
the module Teranode links; then `go build` through a temporary `go.work` that replaces the module by the clone, with
`GOPROXY=off GOSUMDB=off` (no network); then the binary's `--version` must name the pin's prefix `4eab3acd` and the
reference commit's 9-hex prefix `879fc8b42` (the linked library's `CGO_BSV_GIT_COMMIT_HASH` carries 9 hex, never 40),
and `--selftest` must pass. Rebuild before every record (the stale-binary trap). Since 2026-10-17 (#151) step (5) reads
that prefix from `gobdk.reference_commit` of §1a, the SV-node commit GoBDK embeds (v1.2.2), never `reference.commit`, which
moved to the spec's v1.2.3 pin.

## The two columns

As the node runner's two instances: the block column passes the entry's own `consensus` (true on every entry of the
eight corpora) with the block word, the mempool column `false` with the mempool word; both words are the spec's own
(`harness/src/flags_oracle.rs` asks `eval/bsvs eval`); `blockHeight` is the spend height on the consensus path and one
below it on the policy path (`docs/DESIGN.md` §6; Teranode's `bdkBlockHeight`, `ScriptVerifierGoBDK.go:261–271`).
Every response echoes the words, the boolean and the heights it passed. The validator is `NewTxValidator("main")`
with GoBDK's default policy settings (`--describe` prints every limit the linked library reports).

## Driving it

The shim is an out-of-process adapter for `harness/src/bin/run_engine.rs` (`--engine gobdk`, the keys
`gobdk@4eab3acd` and `gobdk-mempool@4eab3acd`), so it inherits the per-entry wall, the ten-times re-run, the message
cap and D15. The driver's side is S3's (`harness/src/engines.rs`, `run_engine.rs`); its hunk and the run it made are
in `docs/records/` (the S4b record named in `docs/records/README.md`). Every divergence is a witness under
`corpus/witnesses/gobdk/`, UNCLASSIFIED: the classifier is S3's data (D83).

No leg of the tripwire builds or runs the shim, and it never enters the tripwire's container (`tools/modal_check.py`): a
pins check of its `go.mod`/`go.sum` reads files only; the built binary and the clone are skipped BY NAME where they are
absent, as `tools/check_pins.py` does for the clones and the built node. It is built and run on the Studio and the box,
and for a row inside the official Teranode x86-64 image on Modal (`modal_teranode.py`: #32's F1, 2026-09-29; the record
is named in `docs/records/README.md`).
