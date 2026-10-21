# Orphaned-block path (#65)

[M] 2026-10-13. [D] Synthetic isolated regtest-intake profile from README.md.
T spends F and is mined in A with its coinbase, giving at least two transactions.
The runner fetches getmerkleproof(T, A), retains the exact proof, invalidates A,
and replays that stored proof against the same header. It checks every active
block body for absence of T. Re-admission to the pool is compatible with that
absence. This is the public #545 proof class, without private client material.

[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/consensus/merkle.cpp:291-310; src/rpc/rawtransaction.cpp:2242-2320;
src/validation.cpp:5230-5330. A one-transaction proof is not fetched: the pin
returns RPC -5 for that case, measured by #75's intake record.

[D] Recipe: tools/node_scenarios.sh --intake-only --scenario
2026-10-13-orphaned-block-proof --record docs/records/<UTC>-s6-65-regtest-s3.md
--run-id s6-65-<UTC> --write. Every invocation uses a fresh instance directory
under the runner's spec-oracle-scenarios root and loopback-only ports.

```json
{
  "id": "2026-10-13-orphaned-block-proof",
  "class": "orphaned-block merkle path supplies no active inclusion (#65, public #545 class)",
  "witness": "A stored path to A remains root-valid after invalidateblock(A); T is absent from every active block.",
  "input_label": "[D]",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "initial_chain": {
    "profile": "regtest-intake",
    "input_label": "[D]",
    "params": "BsvChain.ChainParams.regtest",
    "config": "README.md initial-chain profile",
    "active_tip": {
      "block": "base",
      "height": 101
    },
    "mock_time": 1700000000,
    "adjusted_time_offset": 0,
    "mempool": [],
    "non_final_pool": [],
    "orphan_pool": [],
    "rejected_journal": {},
    "seen": [
      "F"
    ],
    "watched_transactions": [
      "F",
      "T",
      "U"
    ],
    "transactions": {
      "F": {
        "value": "minedActive",
        "label": "[D]",
        "rules": [
          "mine"
        ],
        "node": "measured agree [X] docs/records/20261013-141426-s6-65-regtest-s3.md",
        "height": 101
      },
      "T": {
        "value": "unknown",
        "label": "[D]",
        "rules": [
          "unchanged"
        ],
        "node": "pending #66"
      },
      "U": {
        "value": "unknown",
        "label": "[D]",
        "rules": [
          "unchanged"
        ],
        "node": "pending #66"
      }
    }
  },
  "steps": [
    {
      "id": "p1",
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
      "action": {
        "type": "submit",
        "transaction": "T",
        "now": 1700000000
      },
      "kind": "policy admission; consensus prerequisites",
      "rules": [
        "receive"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "mempool": [
          "T"
        ],
        "non_final_pool": [],
        "tip": {
          "block": "base",
          "height": 101
        },
        "chain_tips": [
          {
            "block": "base",
            "status": "active"
          }
        ],
        "transactions": {
          "F": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 101
          },
          "T": {
            "value": "inMempool",
            "label": "[D]",
            "rules": [
              "receive"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
          },
          "U": {
            "value": "unknown",
            "label": "[D]",
            "rules": [
              "unchanged"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
          }
        },
        "utxos": {
          "F:fund": "unspent",
          "T:credit": "absent",
          "U:credit": "absent"
        },
        "evidence": [
          "getrawmempool = [T]; getrawnonfinalmempool = []; getbestblockhash = base",
          "U has never been submitted; complete journal has no matching clause"
        ],
        "client_views": {}
      }
    },
    {
      "id": "p2",
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
      "action": {
        "type": "mine",
        "branch": "A",
        "parent": "base",
        "block": "A",
        "transactions": [
          "T"
        ],
        "now": 1700000001,
        "method": "submitblock"
      },
      "kind": "consensus inclusion/finality; no client inclusion evidence",
      "rules": [
        "mine"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "mempool": [],
        "non_final_pool": [],
        "tip": {
          "block": "A",
          "height": 102
        },
        "chain_tips": [
          {
            "block": "A",
            "status": "active"
          }
        ],
        "transactions": {
          "F": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 101
          },
          "T": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 102
          },
          "U": {
            "value": "unknown",
            "label": "[D]",
            "rules": [
              "unchanged"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
          }
        },
        "utxos": {
          "F:fund": "spent",
          "T:credit": "unspent",
          "U:credit": "absent"
        },
        "evidence": [
          "getblock A contains T at height 102 with positive confirmations; getbestblockhash = A",
          "node body evidence is retained by the harness, not delivered to the client",
          "gettxout T:credit is unspent; no U receipt"
        ],
        "client_views": {}
      }
    },
    {
      "id": "p3",
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
      "action": {
        "type": "checkPath",
        "transaction": "T",
        "block": "A",
        "rpc": "getmerkleproof",
        "active": true,
        "reuse": false,
        "checks": [
          "leaf at body index",
          "header root equality in Lean verifyPath",
          "header active membership"
        ]
      },
      "kind": "consensus inclusion evidence; client scheduling policy",
      "rules": [
        "path",
        "unchanged"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "mempool": [],
        "non_final_pool": [],
        "tip": {
          "block": "A",
          "height": 102
        },
        "chain_tips": [
          {
            "block": "A",
            "status": "active"
          }
        ],
        "transactions": {
          "F": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 101
          },
          "T": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine",
              "unchanged"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 102
          },
          "U": {
            "value": "unknown",
            "label": "[D]",
            "rules": [
              "unchanged"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
          }
        },
        "utxos": {
          "F:fund": "spent",
          "T:credit": "unspent",
          "U:credit": "absent"
        },
        "evidence": [
          "getmerkleproof T A returns a path for the at-least-two-transaction body; Lean verifyPath and independent Rust replay equal the header root"
        ],
        "client_views": {}
      }
    },
    {
      "id": "p4",
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
      "action": {
        "type": "invalidateBlock",
        "block": "A",
        "now": 1700000002,
        "completion": "clean undo and policy re-admission completed"
      },
      "kind": "operator invalidation; consensus undo; policy re-admission",
      "rules": [
        "invalidate",
        "path"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "mempool": [
          "T"
        ],
        "non_final_pool": [],
        "tip": {
          "block": "base",
          "height": 101
        },
        "chain_tips": [
          {
            "block": "base",
            "status": "active"
          },
          {
            "block": "A",
            "status": "invalid"
          }
        ],
        "transactions": {
          "F": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 101
          },
          "T": {
            "value": "inMempool",
            "label": "[D]",
            "rules": [
              "invalidate"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
          },
          "U": {
            "value": "unknown",
            "label": "[D]",
            "rules": [
              "unchanged"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
          }
        },
        "utxos": {
          "F:fund": "unspent",
          "T:credit": "absent",
          "U:credit": "absent"
        },
        "evidence": [
          "getbestblockhash = base; getchaintips A invalid; getblock A confirmations = -1",
          "getrawmempool = [T]; old path still recomputes A root but A is not active",
          "U remains unknown to the node; active inclusion must be withdrawn"
        ],
        "client_views": {}
      }
    },
    {
      "id": "p5",
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
      "action": {
        "type": "checkPath",
        "transaction": "T",
        "block": "A",
        "active": false,
        "reuse": true,
        "checks": [
          "reuse the stored p3 proof",
          "Lean verifyPath still true",
          "getblock A confirmations -1",
          "scan every active block: T absent"
        ]
      },
      "kind": "operator invalidation; consensus undo; policy re-admission",
      "rules": [
        "path",
        "invalidate"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "mempool": [
          "T"
        ],
        "non_final_pool": [],
        "tip": {
          "block": "base",
          "height": 101
        },
        "chain_tips": [
          {
            "block": "base",
            "status": "active"
          },
          {
            "block": "A",
            "status": "invalid"
          }
        ],
        "transactions": {
          "F": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 101
          },
          "T": {
            "value": "inMempool",
            "label": "[D]",
            "rules": [
              "invalidate"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
          },
          "U": {
            "value": "unknown",
            "label": "[D]",
            "rules": [
              "unchanged"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
          }
        },
        "utxos": {
          "F:fund": "unspent",
          "T:credit": "absent",
          "U:credit": "absent"
        },
        "evidence": [
          "The identical stored proof verifies against A header in Lean; A is invalid/off-active; every active body excludes T. Re-admitted T may remain in the mempool."
        ],
        "client_views": {}
      }
    }
  ],
  "variants": [],
  "replay": {
    "node": "measured agree [X] docs/records/20261013-141426-s6-65-regtest-s3.md",
    "runner": "tools/node_scenarios.sh --intake-only --scenario 2026-10-13-orphaned-block-proof",
    "verifyPath": "Lean chaincheck --verify-path",
    "proof_codec": "#75 owed",
    "client_columns": "none"
  }
}
```
