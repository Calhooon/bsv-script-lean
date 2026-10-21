# Assembly excludes a low-fee transaction, observed (#72)

[M] 2026-10-13, lane s6-72. [D] Synthetic isolated regtest-intake profile from
README.md; four declared steps. `T` spends `F` with a fee of 1,000 satoshis.
`L` spends the height-2 coinbase with a fee of 50 satoshis, below the profile's
`minminingtxfee=0.00000500` (500 satoshis/kB) for its size. Both are admitted:
the pin's relay fee is zero and the reject fee is the rolling minimum. `L`
stays in the secondary pool, outside the journal the assembler copies.

[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/init.cpp:3093-3098,3115-3122 (relay fee zero; `-minminingtxfee` sets the
block minimum fee); src/validation.cpp:1284-1295 (admission's reject fee);
src/txmempool.cpp:411-414,574-600 (below the block minimum fee an entry stays
secondary); src/mining/journaling_block_assembler.cpp:80-97 (the template is
the journal's transactions); src/rpc/mining.cpp:161-224 (`generatetoaddress`
returns hashes only).

[D] The scenario never predicts the assembler. At `a3` and `a4` the runner
mines with `generatetoaddress`, reads the body the node chose (`getblock`),
names it, and writes it into the step's `transactions` with an `assembly`
line: that list is the observed block, the body the machine is applied to. A
step is judged only when the observed body is the body its expectation was
computed on; otherwise it and every later step are recorded as
`measured non-judging`. The runner also checks that the pool after the block is
the pool before it less the observed body. [X] 2026-10-14 (lane s6-72c): `chaincheck --scenarios`
replays this file on the written-back bodies, with `L` a spend of a mature
coinbase coin whose fee is below `blockMinTxFee` for its size
(`lean/Test/ChainCheck.lean`); [M] 29 declared steps agree across the four files.

[D] Recipe: tools/node_scenarios.sh --intake-only --scenario
2026-10-13-assembly-excludes-low-fee --record docs/records/<UTC>-s6-72-regtest-s3.md
--run-id s6-72-<UTC> --write. Every invocation uses a fresh instance directory
under the runner's spec-oracle-scenarios root and loopback-only ports.

```json
{
  "id": "2026-10-13-assembly-excludes-low-fee",
  "class": "block assembly is the node's choice, observed (#72 done-bar)",
  "witness": "generatetoaddress assembles while the pool holds T above and L below -minminingtxfee; the runner reads the body the node chose and judges the state after it",
  "input_label": "[D]",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "initial_chain": {
    "profile": "regtest-intake",
    "input_label": "[D]",
    "params": "BsvChain.ChainParams.regtest",
    "config": "README.md initial-chain profile (minminingtxfee=0.00000500)",
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
      "L"
    ],
    "transactions": {
      "F": {
        "value": "minedActive",
        "label": "[D]",
        "rules": [
          "mine"
        ],
        "node": "pending #66",
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
      "L": {
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
      "id": "a1",
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
          "L": {
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
          "L:credit": "absent"
        }
      }
    },
    {
      "id": "a2",
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
      "action": {
        "type": "submit",
        "transaction": "L",
        "now": 1700000000
      },
      "kind": "policy admission below the mining fee: accepted, secondary",
      "rules": [
        "receive"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "mempool": [
          "L",
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
          "L": {
            "value": "inMempool",
            "label": "[D]",
            "rules": [
              "receive"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
          }
        },
        "utxos": {
          "F:fund": "unspent",
          "T:credit": "absent",
          "L:credit": "absent"
        }
      }
    },
    {
      "id": "a3",
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
        "assembly": "observed (#72): the node's generatetoaddress body; the machine replays it [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "now": 1700000001
      },
      "kind": "node assembly observed; consensus inclusion of the observed body; policy pool removal",
      "rules": [
        "mine"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "mempool": [
          "L"
        ],
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
          "L": {
            "value": "inMempool",
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
          "L:credit": "absent"
        }
      }
    },
    {
      "id": "a4",
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
      "action": {
        "type": "mine",
        "branch": "A",
        "parent": "A",
        "block": "B",
        "transactions": [],
        "assembly": "observed (#72): the node's generatetoaddress body; the machine replays it [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "now": 1700000002
      },
      "kind": "node assembly observed again; the secondary entry stays outside the body",
      "rules": [
        "mine"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "mempool": [
          "L"
        ],
        "non_final_pool": [],
        "tip": {
          "block": "B",
          "height": 103
        },
        "chain_tips": [
          {
            "block": "B",
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
          "L": {
            "value": "inMempool",
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
          "L:credit": "absent"
        }
      }
    }
  ],
  "variants": []
}
```
