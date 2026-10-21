// bsv-script-lean #28: the GoBDK shim of the conformance harness (harness/engines/gobdk; the ruling D14).
// github.com/bitcoin-sv/bdk/module/gobdk is pinned EXACTLY at the pseudo-version Teranode v0.16.0 requires
// (`git show v0.16.0:go.mod`, line 12; re-pinned by #54 on 2026-10-06 from v0.15.9's `cdfa7814`; docs/PROVENANCE.md §1a `gobdk.commit`), and go.sum carries Teranode
// v0.16.0's two sums for it (`git show v0.16.0:go.sum`, lines 108–109). build.sh builds the shim from the local
// clone at that commit through a go.work replace (GOPROXY=off: no network) after checking that the clone's
// module/gobdk hashes to those two sums. Never `latest`.
module bsv-script-lean/harness/engines/gobdk

go 1.26.0

require github.com/bitcoin-sv/bdk/module/gobdk v1.2.5-0.20260918043653-4eab3acdbbb9
