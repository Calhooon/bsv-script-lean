# Manual pruning on regtest: the refusals, the clamp and every read of a pruned block (#85)

[D] 2026-10-15, lane rpc-85 (#85, docs/CONFORMANCE-RPC-CONTRACT.md §2.2 and Finding R2). A fresh regtest
instance of the node of record launched with `-prune=1` (manual pruning, `src/init.cpp:2821-2826`) and
`-preferredblockfilesize=4096` (small block files, `src/validation.h:99` the default), both node settings, policy
never consensus; base configuration `harness/oracle/scenarios.conf` (with `txindex=1`), mock clock 1700000000. Regtest's
`PruneAfterHeight` is 1000 (`src/chainparams.cpp:1509`), `GetMinBlocksToKeep` 288 (`src/validation.h:272`). [SRC] at
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b`. Step s7's expectation is the
probe's observation, not a single JSON reply (Finding R2, record docs/records/20261015-035438-s7-85-rpc-contract-s4b.md):
the runner must read the socket's bytes. Every node marker `pending #66`.

```json
{
  "id": "2026-10-15-rpc-pruning",
  "class": "Manual pruning on regtest: the refusals, the clamp and every read of a pruned block (#85)",
  "witness": "#85: docs/CONFORMANCE-RPC-CONTRACT.md and corpus/rpc/contract.json",
  "input_label": "[D]",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "initial_chain": {
    "profile": "rpc-85",
    "input_label": "[D]",
    "base_config": "harness/oracle/scenarios.conf",
    "launch": [
      "prune=1",
      "preferredblockfilesize=4096"
    ],
    "mock_time": 1700000000,
    "setup": [
      {
        "method": "setmocktime",
        "params": [
          1700000000
        ]
      },
      {
        "method": "generatetoaddress",
        "params": [
          10,
          "<addr>"
        ]
      }
    ],
    "active_tip": {
      "block": "b10",
      "height": 10
    },
    "key": "a fresh regtest key; its address is <addr> below"
  },
  "steps": [
    {
      "id": "s1",
      "action": {
        "type": "rpc",
        "method": "pruneblockchain",
        "params": [
          5
        ]
      },
      "kind": "observe",
      "rules": [
        "src/rpc/blockchain.cpp:1860-1862"
      ],
      "expected_observations": {
        "reply": {
          "error": {
            "code": -1,
            "message": "Blockchain is too short for pruning."
          }
        }
      },
      "label": "[D]",
      "node": "pending #66"
    },
    {
      "id": "s2",
      "action": {
        "type": "rpc",
        "method": "pruneblockchain",
        "params": [
          -1
        ]
      },
      "kind": "observe",
      "rules": [
        "src/rpc/blockchain.cpp:1833-1835"
      ],
      "expected_observations": {
        "reply": {
          "error": {
            "code": -8,
            "message": "Negative block height."
          }
        }
      },
      "label": "[D]",
      "node": "pending #66"
    },
    {
      "id": "s3",
      "action": {
        "type": "rpc",
        "method": "generatetoaddress",
        "params": [
          1290,
          "<addr>"
        ]
      },
      "kind": "observe",
      "rules": [
        "src/rpc/mining.cpp:227-268"
      ],
      "expected_observations": {
        "reply": {
          "result_length": 1290
        }
      },
      "label": "[D]",
      "node": "pending #66",
      "note": "the tip at 1300"
    },
    {
      "id": "s4",
      "action": {
        "type": "rpc",
        "method": "pruneblockchain",
        "params": [
          5000
        ]
      },
      "kind": "observe",
      "rules": [
        "src/rpc/blockchain.cpp:1863-1866"
      ],
      "expected_observations": {
        "reply": {
          "error": {
            "code": -8,
            "message": "Blockchain is shorter than the attempted prune height."
          }
        }
      },
      "label": "[D]",
      "node": "pending #66"
    },
    {
      "id": "s5",
      "action": {
        "type": "rpc",
        "method": "pruneblockchain",
        "params": [
          1100
        ]
      },
      "kind": "observe",
      "rules": [
        "src/rpc/blockchain.cpp:1867-1874"
      ],
      "expected_observations": {
        "reply": {
          "result": 1012
        }
      },
      "label": "[D]",
      "node": "pending #66",
      "note": "clamped to the tip minus 288"
    },
    {
      "id": "s6",
      "action": {
        "type": "rpc",
        "method": "getblockheader",
        "params": [
          "<hash of block 5>",
          1
        ]
      },
      "kind": "observe",
      "rules": [
        "src/rpc/blockchain.cpp:93-138",
        "src/rpc/blockchain.cpp:140-158"
      ],
      "expected_observations": {
        "reply": {
          "result_absent": [
            "size"
          ],
          "result_status": {
            "data": false,
            "undo": false,
            "disk meta": false
          }
        }
      },
      "label": "[D]",
      "node": "pending #66"
    },
    {
      "id": "s7",
      "action": {
        "type": "rpc",
        "method": "getblock",
        "params": [
          "<hash of block 5>",
          0
        ]
      },
      "kind": "observe",
      "rules": [
        "src/rpc/blockchain.cpp:1591-1620",
        "src/rpc/blockchain.cpp:1472-1475"
      ],
      "expected_observations": {
        "socket": {
          "pieces": [
            "HTTP/1.1 200 OK",
            "c\r\n{\"result\": \"",
            "HTTP/1.1 500 Internal Server Error",
            "{\"result\":null,\"error\":{\"code\":-1,\"message\":\"<hash of block 5> not found on disk\"}"
          ],
          "order": "not fixed"
        }
      },
      "label": "[D]",
      "node": "pending #66",
      "note": "Finding R2: a 200 head, a partial chunk and a second status line, 500, on one connection"
    },
    {
      "id": "s8",
      "action": {
        "type": "rpc",
        "method": "getblock",
        "params": [
          "<hash of block 5>",
          1
        ]
      },
      "kind": "observe",
      "rules": [
        "src/rpc/blockchain.cpp:1673-1678"
      ],
      "expected_observations": {
        "reply": {
          "error": {
            "code": -1,
            "message": "Block file <hash of block 5> not available."
          }
        }
      },
      "label": "[D]",
      "node": "pending #66"
    },
    {
      "id": "s9",
      "action": {
        "type": "rpc",
        "method": "getrawtransaction",
        "params": [
          "<coinbase of block 5>",
          1
        ]
      },
      "kind": "observe",
      "rules": [
        "src/rpc/rawtransaction.cpp:196-205"
      ],
      "expected_observations": {
        "reply": {
          "error": {
            "code": -5
          }
        }
      },
      "label": "[D]",
      "node": "pending #66"
    },
    {
      "id": "s10",
      "action": {
        "type": "rpc",
        "method": "gettxout",
        "params": [
          "<coinbase of block 5>",
          0
        ]
      },
      "kind": "observe",
      "rules": [
        "src/rpc/blockchain.cpp:1923-2028"
      ],
      "expected_observations": {
        "reply": {
          "result_present": true
        }
      },
      "label": "[D]",
      "node": "pending #66",
      "note": "the UTXO set is not pruned"
    },
    {
      "id": "s11",
      "action": {
        "type": "rpc",
        "method": "getmerkleproof",
        "params": [
          "<coinbase of block 5>",
          "<hash of block 5>"
        ]
      },
      "kind": "observe",
      "rules": [
        "src/rpc/rawtransaction.cpp:2297-2300"
      ],
      "expected_observations": {
        "reply": {
          "error": {
            "code": -32603,
            "message": "Can't read block from disk"
          }
        }
      },
      "label": "[D]",
      "node": "pending #66"
    }
  ],
  "replay": {
    "runner": "#66, through the interface of #85 (harness/src/scenarios/rpc_contract.rs) once wired",
    "probe_record": "docs/records/20261015-035438-s7-85-rpc-contract-s4b.md"
  }
}
```
