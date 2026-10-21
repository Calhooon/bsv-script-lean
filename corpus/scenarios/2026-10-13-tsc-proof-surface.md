# The proof surface: getmerkleproof, getmerkleproof2 and the TSC view (#75)

[M] 2026-10-13, lane s6-75. Scenario `2026-10-13-tsc-proof-surface`; [M] six
declared steps. [D] Every proof object here is a view of #65's
`(leaf, path, index, root)`, never a rule: the node's JSON is decoded into
`BsvChain.Views.TscProof`, verified by `verifyTsc` against the block's header,
re-encoded in the binary TSC form and decoded back (the round trip, measured on
the node's output), re-rendered as the node's JSON words and compared field by
field, and compared with the model of the node's branch generator
(`tscBranchReduce`) over the body's identifiers. The theorems are in
`lean/BsvChain/Properties/MerkleProof.lean`; the RPC contract is cited in
`lean/BsvChain/Views/MerkleProof.lean` and rendered on the
[merkle-proof page](../../spec/merkle-proof.md).

[D] Initial chain: the [regtest-intake profile](README.md): the private prefix
to height 100, F in base at height 101. Then five blocks assembled by the
harness and submitted with `submitblock`: at heights 102 to 106, each holding
its coinbase and a chain of spends of the previous transaction, so the bodies
hold 2, 3, 5, 6 and 8 transactions. The one-transaction body is the prefix's
block at height 1 (its coinbase alone). No public peer or standing node is
contacted; nothing is broadcast (rule 10).

[D] Per transaction of each multi-transaction body the runner fetches
`getmerkleproof` (`txid`, `blockhash`), `getmerkleproof2` with `targetType`
`hash`, `header` and `merkleroot` and once with `includeFullTx`, asks
`verifymerkleproof` for the served object (expected true) and for two
mutations (the index with its low bit flipped; the earliest hash node replaced by
the leaf), whose verdicts must agree with Lean's `verifyTsc` on the same object,
[D] 2026-10-14: the mutation label above is an editorial projection of the
retained measured labels in the scenario `.node.json`; those bytes are unchanged.
The runner once per block asks `getmerkleproof2` with `format` `binary`, refused at
the pin with `RPC_INVALID_PARAMS`, the JSON-RPC code `-32602`, and the text
`format is 'binary',  must be 'json'` ([SRC] `src/rpc/rawtransaction.cpp:2429-2436`,
`src/rpc/protocol.h:28`; [M] measured: a run of 2026-10-14 01:40Z expecting
`-8` was judged RED by that expectation alone and is not committed, its
receipt under `~/bsv/targets/spec-oracle-scenarios/s6-75-20261014-014034/`). For the one-transaction
body both RPCs are asked and their answers quoted: the node supplies no proof
(RPC `-5`, `Transaction(s) not found in provided block`; [SRC]
`src/rpc/rawtransaction.cpp:2302-2306,2447-2450`, `src/merkletree.cpp:335-339`);
the offset-0 reading (index 0, the empty branch, the lone leaf) is body-derived
`[D]`, checked by Lean, never a node output.

[D] The expected `*` positions per transaction index follow the generator's
cases ([SRC] `src/merkletree.cpp:294-346`): the last transaction of a 3-body has
a marker at level 0; the last of a 5-body at levels 0 and 1 (two consecutive
markers); the pair 4 and 5 of a 6-body at level 1 (the virtual parent of the
level above is a hash); 2- and 8-bodies have none.

[SRC] `src/rpc/rawtransaction.cpp:2242-2339` (`getmerkleproof`), `:2342-2525`
(`getmerkleproof2`), `:2527-2612` (`verifymerkleproof`), `src/merkletree.cpp:275-346`,
`src/consensus/merkle.cpp:291-310` at bitcoin-sv `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.
[LIT] the TSC merkle proof standard, cited with its retrieval hash in the view module.

| step | transactions [D] | what is measured | node |
|---|---:|---|---|
| one-transaction | 1 | both RPCs answer `-5`; the body-derived empty path verifies in Lean | measured agree [X] docs/records/20261014-015319-s6-75-regtest-s3.md |
| two-transactions | 2 | 10 proofs, no marker | measured agree [X] docs/records/20261014-015319-s6-75-regtest-s3.md |
| three-transactions | 3 | 15 proofs; index 2 has `*` at level 0 | measured agree [X] docs/records/20261014-015319-s6-75-regtest-s3.md |
| five-transactions | 5 | 25 proofs; index 4 has `*` at levels 0 and 1 | measured agree [X] docs/records/20261014-015319-s6-75-regtest-s3.md |
| six-transactions | 6 | 30 proofs; indices 4 and 5 have `*` at level 1 | measured agree [X] docs/records/20261014-015319-s6-75-regtest-s3.md |
| eight-transactions | 8 | 40 proofs, no marker | measured agree [X] docs/records/20261014-015319-s6-75-regtest-s3.md |

```json
{
  "id": "2026-10-13-tsc-proof-surface",
  "class": "proof surface view, never a rule",
  "witness": "the node's getmerkleproof and getmerkleproof2 objects through the Lean TSC codec, round trip and model branch; the one-transaction answer quoted",
  "input_label": "[D]",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "source_date": "2026-10-13",
  "initial_chain": {
    "profile": "regtest-intake",
    "params": "BsvChain.ChainParams.regtest",
    "config": "README regtest-intake; no listener",
    "active_tip": {
      "block": "base",
      "height": 101
    },
    "mock_time": 1700000000,
    "blocks": [
      {"height": 102, "transactions": 2},
      {"height": 103, "transactions": 3},
      {"height": 104, "transactions": 5},
      {"height": 105, "transactions": 6},
      {"height": 106, "transactions": 8}
    ]
  },
  "steps": [
    {
      "id": "one-transaction",
      "action": {
        "type": "proofSurface",
        "transactions": 1,
        "block": "the prefix block at height 1",
        "rpcs": ["getmerkleproof", "getmerkleproof2", "getmerkleproof2 targetType=header"]
      },
      "kind": "the node's answer for a lone transaction, quoted",
      "rules": ["path"],
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-015319-s6-75-regtest-s3.md",
      "expected_observations": {
        "transactions": 1,
        "getmerkleproof": {"code": -5, "message": "Transaction(s) not found in provided block"},
        "getmerkleproof2": {"code": -5, "message": "Transaction(s) not found in provided block"},
        "no_proof_fields": true,
        "body_derived": {"label": "[D]", "index": 0, "nodes": [], "lean_verifyTsc": true}
      }
    },
    {
      "id": "two-transactions",
      "action": {"type": "proofSurface", "transactions": 2, "block": "height 102"},
      "kind": "every proof of a two-transaction body through the TSC view",
      "rules": ["path"],
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-015319-s6-75-regtest-s3.md",
      "expected_observations": {"transactions": 2, "marker_positions": {}, "binary_format_refused": true, "verifymerkleproof_served_true": true}
    },
    {
      "id": "three-transactions",
      "action": {"type": "proofSurface", "transactions": 3, "block": "height 103"},
      "kind": "odd terminal padding at level 0",
      "rules": ["path"],
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-015319-s6-75-regtest-s3.md",
      "expected_observations": {"transactions": 3, "marker_positions": {"2": [0]}, "binary_format_refused": true, "verifymerkleproof_served_true": true}
    },
    {
      "id": "five-transactions",
      "action": {"type": "proofSurface", "transactions": 5, "block": "height 104"},
      "kind": "two consecutive markers",
      "rules": ["path"],
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-015319-s6-75-regtest-s3.md",
      "expected_observations": {"transactions": 5, "marker_positions": {"4": [0, 1]}, "binary_format_refused": true, "verifymerkleproof_served_true": true}
    },
    {
      "id": "six-transactions",
      "action": {"type": "proofSurface", "transactions": 6, "block": "height 105"},
      "kind": "a marker above level 0 with the virtual parent as a hash",
      "rules": ["path"],
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-015319-s6-75-regtest-s3.md",
      "expected_observations": {"transactions": 6, "marker_positions": {"4": [1], "5": [1]}, "binary_format_refused": true, "verifymerkleproof_served_true": true}
    },
    {
      "id": "eight-transactions",
      "action": {"type": "proofSurface", "transactions": 8, "block": "height 106"},
      "kind": "a full tree, no marker",
      "rules": ["path"],
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-015319-s6-75-regtest-s3.md",
      "expected_observations": {"transactions": 8, "marker_positions": {}, "binary_format_refused": true, "verifymerkleproof_served_true": true}
    }
  ],
  "replay": {
    "runner": "tools/node_scenarios.sh --proofs-only --record docs/records/<stamp>-s6-75-regtest-s3.md --run-id s6-75-<stamp> --write",
    "lean": "lean/.lake/build/bin/chaincheck --verify-tsc <json>",
    "boundary": "root equality and the codec; inclusion keeps #65's premises"
  }
}
```
