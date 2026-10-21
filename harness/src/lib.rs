//! bsv-script-lean's conformance harness (this repo's; seeded 2026-09-22, #4).
//!
//! * `txraw`   a raw transaction codec that never parses scripts (mutated corpus
//!   entries must round-trip even when no implementation can parse them)
//! * `engine`  the bsv-rs runner: one input of a transaction against its prevout,
//!   through the pinned `Spend` engine (VENDORED pattern, see its header)
//! * `gen`     the seed generator: the predecessor's differential fuzz families,
//!   mechanism-free (VENDORED pattern, see its header)
//! * `corpus`  the corpus entry and manifest format of `docs/DESIGN.md` §6
//! * `differential` shared corpus and specification readers for the conformance drivers ([LIT] #31)
//! * `bsvrs_codes` the bsv-rs message → `SCRIPT_ERR_*` table, a cited table (#15; at 0.4.4 since 2026-10-12, 0.3.33 from 2026-10-07, 0.3.32 from 2026-10-06, 0.3.30 from 2026-09-27, 0.3.28 from 2026-09-24)
//! * `engines` the out-of-process SDK adapters (go-sdk, ts-sdk) over JSON lines (#29)
//! * `flags_oracle` the flag word per input, asked of the spec's own executable and cached (#29)
//! * `gosdk_codes`, `tssdk_codes` the engines' codes and messages → `SCRIPT_ERR_*`, cited tables (#29)
//! * `svnode_codes` the reference's `ScriptErrorString` text → `SCRIPT_ERR_*`, the reversed table for the verifyscript runner (#27)
//! * `block`   the block road's assembler: the coinbase, the merkle root, the header and its nonce, the well's P2PKH spends (#27, D97; 2026-09-26)
//! * `rpc`     the node's JSON-RPC over loopback with cookie auth (moved out of run_svnode.rs on 2026-09-26; the block road's tools share it)
//! * `txroad`  THE BLOCK ROAD: `run_svnode --mode tx`, the tx.* families' two columns by a block the harness assembles and by the policy instance's mempool (#27, D97; 2026-09-26)
//! * `fail`    the error road of the node drivers and the record writers: `or_err` where an unwrap, expect or panic stood (#132)
//! * `teranode_contract` the observation contract of #97 (S4b's file, harness/engines/teranode/contract.rs): the trait the Teranode runner and the scenario client read through, its one implementation over the RPC, asset HTTP and gRPC surfaces (2026-10-15)
//! * `signer`  THE SIGNABLE CORPUS's row (#145): the entry plus its `signing` object, the scriptCode walker and the hand signer the self-check uses
//! * `signer_node` the signer column's owned regtest node, its verdict fields, the adapters' line and runner (#145, #147; shared with #152's chain leg)
//! * `rules`   THE CLASSIFIER AS DATA (D83c, #31; 2026-09-26): the divergence classes and the rows that name them, one JSON per engine under `harness/rules/`, read by `run_diff` and `run_engine` through one call each; `rules_check` replays the corpora of the go-sdk, ts-sdk and gobdk manifests from their recorded verdicts and bsv-rs's live (the sv-node and policy-defaults manifests are replayed by no leg)
//!
//! Every implementation's verdict in the corpus is keyed by name@version; the
//! spec's own verdict is `spec@<commit>` (from #14 on).

pub mod block;
pub mod bsvrs_codes;
pub mod cases;
pub mod corpus;
pub mod differential;
pub mod engine;
pub mod engines;
pub mod fail;
pub mod flags_oracle;
pub mod gen;
pub mod gosdk_codes;
pub mod rpc;
pub mod rules;
pub mod signer;
pub mod signer_node;
/// the spec stamp's gate, with its lenient reader of a column's commits (`unknown` for a line it cannot read; P6)
pub mod stamp;
pub mod svnode_codes;
#[path = "../engines/teranode/contract.rs"]
pub mod teranode_contract;
pub mod tssdk_codes;
pub mod txraw;
pub mod txroad;

/// The pinned bsv-rs (docs/PROVENANCE.md §1). `cargo` pins it exactly in Cargo.toml;
/// the test below refuses a drift between this string and Cargo.lock.
pub const BSV_RS_VERSION: &str = "0.7.0";
/// The key under which bsv-rs's verdict is recorded in a corpus entry.
pub const BSV_RS_KEY: &str = "bsv-rs@0.7.0";
/// The pinned bitcoin-sv tag (docs/PROVENANCE.md §1a `reference.tag`): the node adapters' subversion gates, their
/// manifest rows and the scenario binaries read it, so `make column IMPL=sv-node` moves one site (#124; check_pins reads it).
pub const SV_NODE_TAG: &str = "v1.2.3";

#[cfg(test)]
mod pin_tests {
    #[test]
    fn cargo_lock_pins_the_recorded_bsv_rs_version() {
        let lock = include_str!("../Cargo.lock");
        let needle = format!("name = \"bsv-rs\"\nversion = \"{}\"", super::BSV_RS_VERSION);
        assert!(
            lock.contains(&needle),
            "Cargo.lock does not pin bsv-rs {}",
            super::BSV_RS_VERSION
        );
    }
}
