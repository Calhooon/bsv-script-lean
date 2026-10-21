// bsv-script-lean #29: the go-sdk adapter of the conformance harness (harness/engines/go).
// github.com/bsv-blockchain/go-sdk is pinned EXACTLY (docs/PROVENANCE.md §1a `go-sdk.version`, `go-sdk.sum`);
// `make check-pins` refuses a drift between this file, go.sum and PROVENANCE. Never `latest`.
module bsv-script-lean/harness/engines/go

go 1.26.0

require github.com/bsv-blockchain/go-sdk v1.7.2

require (
	github.com/mrz1836/go-whatsonchain v1.3.0 // indirect
	github.com/pkg/errors v0.9.1 // indirect
	golang.org/x/crypto v0.57.0 // indirect
)
