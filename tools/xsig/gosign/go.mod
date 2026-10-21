// bsv-script-lean #144 (lane xsig-144): the go-sdk signer side of the checksig-in-unlock witness (tools/xsig_witness.py).
// github.com/bsv-blockchain/go-sdk pinned EXACTLY as harness/engines/go/go.mod pins it (docs/PROVENANCE.md §1a); built
// offline from the module cache (GOPROXY=off GOTOOLCHAIN=local GOFLAGS=-mod=mod).
module bsv-script-lean/tools/xsig/gosign

go 1.26.0

require github.com/bsv-blockchain/go-sdk v1.7.2

require (
	github.com/mrz1836/go-whatsonchain v1.3.0 // indirect
	github.com/pkg/errors v0.9.1 // indirect
	golang.org/x/crypto v0.57.0 // indirect
)
