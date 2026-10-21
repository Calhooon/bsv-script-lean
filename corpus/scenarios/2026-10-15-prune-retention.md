# Pruning on regtest: which block files a node keeps, and what a pruned node still answers (#82)

[D] 2026-10-15, lane s7-82. Fresh isolated regtest instances of the node of record (bitcoin-sv v1.2.3), RPC on
the lowest free pair in 18571 to 18590, never a standing instance; nothing is broadcast (rule 10). Pruning is a
node setting (`-prune`), policy and never consensus: a pruned node validates as an unpruned one and keeps its
whole block index and UTXO set; what it loses are the bytes of old block files. The expectations are the Lean
function's (`lean/BsvChain/Views/Prune.lean`), computed at run time from the node's own block sizes in arrival
order (`chaincheck --prune`), and the reference's messages and codes, cited at
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b`. The [format](README.md) is the scenario corpus's; the record of the run is named in every node marker.

The manual instance (`-prune=1`, `-preferredblockfilesize=4096`, so a file holds a handful of regtest blocks)
mines to 999, 1000 and 1300 and asks `pruneblockchain` below `nPruneAfterHeight` (1000 on regtest,
`src/chainparams.cpp:1509`), at it, past the clamp (the tip less `minBlocksToKeep`, 288 by default,
`src/validation.h:272`), at zero, above the tip and below zero; after every acting call it reads every block's
`data` and `undo` bits (`getblockheader`) and lists the instance's own `blk`/`rev` files, both compared with the Lean
store. Three probe blocks then meet every request the harness reads: P (height 140, pruned, no merkle tree ever
asked), T (height 141, pruned, its merkle tree asked for before pruning) and R (height 1250, retained). Each
holds its coinbase and one spend `<tx>` (of the coinbase of block 1, 2 and 1000), built and submitted by the
runner: the node serves no proof for a block holding only its coinbase (`src/merkletree.cpp:335-339`, #75's
Finding), and that refusal is not pruning's. The transaction requests name `<tx>`. A restart
empties the merkle trees' memory cache and keeps their store. Invalidating block 900 walks the disconnect down to
the highest block without data; what the node does there is held in the record under the discretion group until routed.
Three more instances read the negative clamp (`-pruneminblockstokeep=2000` at a tip of 1000), the unpruned
refusal and the launch refusals with an automatic target that usage never reaches.

```json
{
  "id": "2026-10-15-prune-retention",
  "class": "Pruning on regtest: the retention function, every read of a pruned and a retained block, the proof surface and the undo (#82)",
  "witness": "#82: lean/BsvChain/Views/Prune.lean and lean/BsvChain/Properties/Prune.lean",
  "input_label": "[D]",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "initial_chain": {
    "profile": "s7-82",
    "input_label": "[D]",
    "base_config": "harness/oracle/scenarios.conf",
    "instances": {
      "manual": [
        "prune=1",
        "preferredblockfilesize=4096"
      ],
      "keep2000": [
        "prune=1",
        "preferredblockfilesize=4096",
        "pruneminblockstokeep=2000"
      ],
      "unpruned": [],
      "launch": [
        "prune=549",
        "prune=-1"
      ],
      "auto": [
        "prune=550",
        "preferredblockfilesize=4096"
      ]
    },
    "mining": "generatetoaddress in batches of 100 to the runner's regtest key; every block's size read by getblock <hash> 0 before any pruning"
  },
  "steps": [
    {
      "id": "s1",
      "action": {
        "type": "rpc",
        "method": "pruneblockchain",
        "params": [
          500
        ],
        "tip": 999
      },
      "kind": "observe",
      "rules": [
        "src/rpc/blockchain.cpp:1859-1862",
        "src/chainparams.cpp:1509"
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
      "node": "measured agree [X] docs/records/20261015-130232-s7-82-prune-s1.md",
      "note": "the tip below nPruneAfterHeight (1000)"
    },
    {
      "id": "s2",
      "action": {
        "type": "rpc",
        "method": "pruneblockchain",
        "params": [
          500
        ],
        "tip": 1000
      },
      "kind": "observe",
      "rules": [
        "src/rpc/blockchain.cpp:1859-1874",
        "src/blockfileinfostore.cpp:177-208",
        "src/validation.cpp:6584-6628"
      ],
      "expected_observations": {
        "reply": {
          "result": 500
        },
        "bits": "chaincheck --prune (lean/BsvChain/Views/Prune.lean) over the node's own block sizes in arrival order",
        "files": "the Lean store's files less the removed ones, blk and rev alike"
      },
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261015-130232-s7-82-prune-s1.md",
      "note": "at the bound nPruneAfterHeight; held in the record under the discretion group until routed"
    },
    {
      "id": "s3",
      "action": {
        "type": "rpc",
        "method": "pruneblockchain",
        "params": [
          1100
        ],
        "tip": 1300
      },
      "kind": "observe",
      "rules": [
        "src/rpc/blockchain.cpp:1867-1874",
        "src/blockfileinfostore.cpp:189-203"
      ],
      "expected_observations": {
        "reply": {
          "result": 1012
        },
        "bits": "chaincheck --prune (lean/BsvChain/Views/Prune.lean) over the node's own block sizes in arrival order",
        "files": "as s2"
      },
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261015-130232-s7-82-prune-s1.md",
      "note": "clamped to the tip less minBlocksToKeep (288)"
    },
    {
      "id": "s4",
      "action": {
        "type": "rpc",
        "method": "pruneblockchain",
        "params": [
          0
        ],
        "tip": 1300
      },
      "kind": "observe",
      "rules": [
        "src/rpc/blockchain.cpp:1873-1874",
        "src/validation.cpp:3840-3842"
      ],
      "expected_observations": {
        "reply": {
          "result": 0
        },
        "removed": [],
        "bits": "chaincheck --prune (lean/BsvChain/Views/Prune.lean) over the node's own block sizes in arrival order"
      },
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261015-130232-s7-82-prune-s1.md",
      "note": "the manual selection runs only above zero"
    },
    {
      "id": "s5",
      "action": {
        "type": "rpc",
        "method": "pruneblockchain",
        "params": [
          5000
        ],
        "tip": 1300
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
      "node": "measured agree [X] docs/records/20261015-130232-s7-82-prune-s1.md"
    },
    {
      "id": "s6",
      "action": {
        "type": "rpc",
        "method": "pruneblockchain",
        "params": [
          -1
        ],
        "tip": 1300
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
      "node": "measured agree [X] docs/records/20261015-130232-s7-82-prune-s1.md"
    },
    {
      "id": "s7",
      "action": {
        "type": "rpc",
        "method": "getblockchaininfo",
        "params": []
      },
      "kind": "observe",
      "rules": [
        "src/rpc/blockchain.cpp:2454,2467-2480"
      ],
      "expected_observations": {
        "pruned": true,
        "pruneheight": "pruneHeightFrom over the Lean data bits after s3"
      },
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261015-130232-s7-82-prune-s1.md"
    },
    {
      "id": "s8",
      "action": {
        "type": "probes",
        "blocks": {
          "P": 140,
          "T": 141,
          "R": 1250
        },
        "tree_asked_before_pruning": "T (getmerkleproof and getmerkleproof2)",
        "requests": [
          "getblock 0",
          "getblock 1",
          "getblockheader true",
          "getblockheader 2",
          "getrawtransaction <tx> 1",
          "getmerkleproof <tx> <block>",
          "getmerkleproof2 <block> <tx>",
          "gettxout <tx> 0",
          "getblockhash <height>",
          "getchaintxstats 0 <block>"
        ]
      },
      "kind": "observe",
      "rules": [
        "src/rpc/blockchain.cpp:93-158,1009-1040,1446-1474,1591-1620,1665-1678",
        "src/rpc/rawtransaction.cpp:196-205,2286-2300,2404-2444",
        "src/merkletreestore.cpp:540-570",
        "src/validation.cpp:2178-2185"
      ],
      "expected_observations": {
        "answers": "Views.Prune.answer per block: P pruned without a tree, T pruned with its tree held, R retained"
      },
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261015-130232-s7-82-prune-s1.md",
      "note": "getblock 0 on a pruned block is read off the socket (#85 Finding R2)"
    },
    {
      "id": "s9",
      "action": {
        "type": "restart",
        "then": [
          "getmerkleproof T",
          "getmerkleproof P"
        ]
      },
      "kind": "observe",
      "rules": [
        "src/merkletreestore.cpp:202-272,274-302,540-570"
      ],
      "expected_observations": {
        "T": "served from the merkle tree store",
        "P": {
          "error": {
            "code": -32603,
            "message": "Can't read block from disk"
          }
        }
      },
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261015-130232-s7-82-prune-s1.md",
      "note": "the memory cache is gone after a restart; the on-disk store keeps T's tree"
    },
    {
      "id": "s10",
      "action": {
        "type": "rpc",
        "method": "invalidateblock",
        "params": [
          "<hash of block 900>"
        ]
      },
      "kind": "observe",
      "rules": [
        "src/validation.cpp:5230-5258"
      ],
      "expected_observations": {
        "tip_stops_at": "the highest height without data (the Lean bits after s4)",
        "held": "held in the record under the discretion group until routed"
      },
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261015-130232-s7-82-prune-s1.md",
      "note": "the disconnect reaches a block whose data and undo were pruned"
    },
    {
      "id": "s11",
      "action": {
        "type": "rpc",
        "method": "pruneblockchain",
        "params": [
          10
        ],
        "tip": 1000,
        "instance": "pruneminblockstokeep=2000"
      },
      "kind": "observe",
      "rules": [
        "src/rpc/blockchain.cpp:1867-1874",
        "src/validation.cpp:3840-3842"
      ],
      "expected_observations": {
        "reply": {
          "result": 18446744073709550616
        },
        "removed": []
      },
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261015-130232-s7-82-prune-s1.md",
      "note": "minBlocksToKeep above the tip; held in the record under the discretion group until routed"
    },
    {
      "id": "s12",
      "action": {
        "type": "rpc",
        "method": "pruneblockchain",
        "params": [
          10
        ],
        "instance": "unpruned"
      },
      "kind": "observe",
      "rules": [
        "src/rpc/blockchain.cpp:1826-1830,2454,2467"
      ],
      "expected_observations": {
        "reply": {
          "error": {
            "code": -1,
            "message": "Cannot prune blocks because node is not in prune mode."
          }
        },
        "pruned": false,
        "pruneheight_present": false
      },
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261015-130232-s7-82-prune-s1.md"
    },
    {
      "id": "s13",
      "action": {
        "type": "launch",
        "args": [
          "prune=549",
          "prune=-1"
        ]
      },
      "kind": "observe",
      "rules": [
        "src/init.cpp:2815-2838"
      ],
      "expected_observations": {
        "refusals": [
          "Prune configured below the minimum of 550 MiB.  Please use a higher number.",
          "Prune cannot be configured with a negative value."
        ]
      },
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261015-130232-s7-82-prune-s1.md"
    },
    {
      "id": "s14",
      "action": {
        "type": "mine",
        "blocks": 1100,
        "instance": "prune=550"
      },
      "kind": "observe",
      "rules": [
        "src/blockfileinfostore.cpp:230-300",
        "src/init.cpp:2827-2838"
      ],
      "expected_observations": {
        "removed": [],
        "pruneheight": 0,
        "bits": "every block keeps its data: usage plus 17 MiB is below the 550 MiB target"
      },
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261015-130232-s7-82-prune-s1.md"
    }
  ],
  "replay": {
    "runner": "harness/src/scenarios/prune.rs (run_scenarios --prune --record docs/records/<stamp>-s7-82-prune-s1.md)",
    "projection": "chaincheck --prune (lean/BsvChain/Views/Prune.lean) over the node's own block sizes in arrival order"
  }
}
```
